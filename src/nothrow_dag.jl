#####
##### `DAGStep`
#####

"""
    DAGStep

Helper struct, used to construct [`NoThrowDAG`](@ref)s. Requires fields
* `name::String`: Name of step, must be unique across a constructed DAG
* `input_assembler::TransformSpecification`: Transform used to construct step's input;
    see [`input_assembler`](@ref) for details.
* `transform_spec::AbstractTransformSpecification`: Transform applied by step
"""
struct DAGStep
    name::String
    input_assembler::Union{TransformSpecification,Nothing}
    transform_spec::AbstractTransformSpecification

    function DAGStep(name, input_assembler, transform_spec)
        if !(isnothing(input_assembler) || is_input_assembler(input_assembler))
            throw(ArgumentError("Invalid `input_assembler`"))
        end
        return new(name, input_assembler, transform_spec)
    end
end

"""
    input_assembler(conversion_fn) -> TransformSpecification{Dict{String,Any}, NamedTuple}

Special transform used to convert the outputs of upstream steps in a
[`NoThrowDAG`](@ref) into a `NamedTuple` that can be converted into
that type's input specification.

`conversion_fn` must be a function that
* takes as input a Dictionary with keys that are the names of upstream steps, where
    the value of each of these keys is the output of that upstream_step, as
    specified by `output_specification(upstream_step)`.
* returns a `NamedTuple` that can be converted, via [convert_spec`](@ref), to the
    specification of an `AbstractTransformSpecification` that it is paired with
    in a [`DAGStep`](@ref).

Note that the current implementation is a stopgap for a better-defined implementation
defined in https://github.com/beacon-biosignals/TransformSpecifications.jl/issues/8
"""
function input_assembler(conversion_fn)
    return TransformSpecification(Dict{String,Any}, NamedTuple, conversion_fn)
end

"""
    is_input_assembler(ts::AbstractTransformSpecification) -> Bool

Confirm that `ts` is an [`input_assembler`](@ref).
"""
function is_input_assembler(ts::AbstractTransformSpecification)
    return input_specification(ts) == Dict{String,Any} &&
           output_specification(ts) == NamedTuple
end
is_input_assembler(::Any) = false

#####
##### `NoThrowDAG`
#####

"""
    NoThrowDAG <: AbstractTransformSpecification
    NoThrowDAG(steps::AbstractVector{DAGStep})

Transform specification constructed from a DAG of transform specification nodes (`steps`),
such that calling [`transform!`](@ref) on the DAG iterates through the steps,
first constructing that step's input from all preceding upstream step outputs and
then appling that step's own transform to the constructed input.

The DAG's `input_specification` is that of the first step in the DAG; its `output_specification`
is that of the last step. As the first step's input is by definition the same as
the overall input to the DAG, its `step.input_assembler` must be `nothing`.

!!! tip "DAG construction tip"
    As the input to the DAG at is by definition the input to the first step in that DAG,
    only the first step will have access to the input directly passed in by the caller.
    To grant access to this top-level input to downstream tasks, construct the DAG with
    an initial step that is an identity transform, i.e., `is_identity_no_throw_transform(first(steps))`
    returns true. Downstream steps can then depend on the output of specific fields from
    this initial step. The single argument [`TransformSpecification`](@ref) constructor
    creates such an identity transform.

!!! warning "DAG construction warning"
    It is the caller's responsibility to implement a DAG, and to not introduce
    any recursion or cycles. What will happen if you do? To quote Tom Lehrer,
    "[well, you ask a silly question, you get a silly answer](https://youtu.be/zWPn3esuDgU?t=189)!"

!!! warning "Storage of intermediate values"
    The output of each step in the DAG is stored locally in memory for the entire lifetime
    of the `transform` operation, whether or not it is actually accessed by any later
    steps.  Large intermediate outputs may result in unexpected memory pressure
    relative to function composition or even local evaluation (since they are not
    visible to the garbage collector).
## Fields

The following fields are constructed automatically when constructing a `NoThrowDAG`
from a vector of `DAGSteps`:

- `step_transforms::OrderedDict{String,AbstractTransformSpecification}`: Ordered dictionary of processing steps
- `step_input_assemblers::Dict{String,TransformSpecification}`: Dictionary with functions for constructing the input
    for each key in `step_transforms` as a function that takes in a Dict{String,NoThrowResult}
    of all upstream `step_transforms` results.
- `_step_output_fields::Dict{String,Dict{Symbol,Any}}`: Internal mapping of upstream step
    outputs to downstream inputs, used to e.g. valdiate that the input to each step
    can be constructed from the outputs of the upstream steps.

## Example

```jldoctest nothrowdag_ex1
using Legolas: @schema, @version
using TransformSpecifications: input_assembler

@schema "example-one-var" ExampleOneVarSchema
@version ExampleOneVarSchemaV1 begin
    var::String
end

@schema "example-two-var" ExampleTwoVarSchema
@version ExampleTwoVarSchemaV1 begin
    var1::String
    var2::String
end

# Say we have three functions we want to chain together:
fn_a(x) = ExampleOneVarSchemaV1(; var=x.var * "_a")
fn_b(x) = ExampleOneVarSchemaV1(; var=x.var * "_b")
fn_c(x) = ExampleOneVarSchemaV1(; var=x.var1 * x.var2 * "_c")

# First, specify these functions as transforms: what is the specification of the
# function's input and output?
step_a_transform = NoThrowTransform(ExampleOneVarSchemaV1, ExampleOneVarSchemaV1, fn_a)
step_b_transform = NoThrowTransform(ExampleOneVarSchemaV1, ExampleOneVarSchemaV1, fn_b)
step_c_transform = NoThrowTransform(ExampleTwoVarSchemaV1, ExampleOneVarSchemaV1, fn_c)

# Next, set up the DAG between the upstream outputs into each step's input:
step_b_assembler = input_assembler(upstream -> (; var=upstream["step_a"][:var]))
step_c_assembler = input_assembler(upstream -> (; var1=upstream["step_a"][:var],
                                                var2=upstream["step_b"][:var]))
# ...note that step_a is skipped, as there are no steps upstream from it.

steps = [DAGStep("step_a", nothing, step_a_transform),
         DAGStep("step_b", step_b_assembler, step_b_transform),
         DAGStep("step_c", step_c_assembler, step_c_transform)]
dag = NoThrowDAG(steps)

# output
NoThrowDAG (ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1):
  🌱  step_a: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_a`
   ·  step_b: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_b`
  🌷  step_c: ExampleTwoVarSchemaV1 => ExampleOneVarSchemaV1: `fn_c`
```
This DAG can then be applied to an input, just like a regular `TransformSpecification`
can:
```jldoctest nothrowdag_ex1
input = ExampleOneVarSchemaV1(; var="initial_str")
transform!(dag, input)

# output
NoThrowResult{ExampleOneVarSchemaV1}: Transform succeeded
  ✅ result: ExampleOneVarSchemaV1:
 :var  "initial_str_ainitial_str_a_b_c"
```
Similarly, this transform will fail if the input specification is violated---but
because it returns a [`NoThrowResult`](@ref), it will fail gracefully:
```jldoctest nothrowdag_ex1
# What is the input specification?
input_specification(dag)

# output
ExampleOneVarSchemaV1
```
```jldoctest nothrowdag_ex1
transform!(dag, ExampleTwoVarSchemaV1(; var1="wrong", var2="input schema"))

# output
NoThrowResult{Missing}: Transform failed
  ❌ Input to step `step_a` doesn't conform to specification `ExampleOneVarSchemaV1`. Details: ArgumentError("Invalid value set for field `var`, expected String, got a value of type Missing (missing)")
```
"""
struct NoThrowDAG <: AbstractTransformSpecification
    step_transforms::OrderedDict{String,NoThrowTransform}
    step_input_assemblers::Dict{String,Any}
    _step_output_fields::Dict{String,Any}

    function NoThrowDAG(init_step::DAGStep)
        if !isnothing(init_step.input_assembler)
            throw(ArgumentError("Initial step's input constructor must be `nothing` ($(init_step.input_assembler))"))
        end
        step_transforms = OrderedDict(init_step.name => NoThrowTransform(init_step.transform_spec))
        step_input_assemblers = Dict(init_step.name => nothing)
        _step_output_fields = Dict{String,Dict{Symbol,Any}}(init_step.name => field_dict(output_specification(init_step.transform_spec)))
        return new(step_transforms, step_input_assemblers, _step_output_fields)
    end
end

function NoThrowDAG(steps::AbstractVector{<:DAGStep})
    length(steps) == 0 &&
        throw(ArgumentError("At least one step required to construct a DAG"))
    dag = NoThrowDAG(first(steps))
    for step in steps[2:end]
        push!(dag, step)
    end
    return dag
end

function Base.push!(dag::NoThrowDAG, step::DAGStep)
    # Safety first!
    haskey(dag.step_transforms, step.name) &&
        throw(ArgumentError("Step with name `$(step.name)` already exists in DAG!"))
    _validate_input_assembler(dag, step.input_assembler)

    # Forge it!
    push!(dag.step_transforms, step.name => NoThrowTransform(step.transform_spec))
    push!(dag.step_input_assemblers, step.name => step.input_assembler)
    push!(dag._step_output_fields,
          step.name => field_dict(output_specification(step.transform_spec)))
    return dag
end

"""
    _validate_input_assembler(dag::NoThrowDAG, input_assembler::TransformSpecification)
    _validate_input_assembler(dag::NoThrowDAG, ::Nothing)

Confirm that an input_assembler, when called on all upstream outputs generated by
`dag`, has access to all fields it needs to construct its input.

This validation assumes that the `dag` being validated against contains **only**
outputs from upstream steps, an assumption that will be true on DAG construction
(where this validation is called from). If called at other times, validation may
succeed even though the `input_assembler` will fail when called in situ.
"""
_validate_input_assembler(::NoThrowDAG, ::Nothing) = nothing

function _validate_input_assembler(dag::NoThrowDAG,
                                   input_assembler::TransformSpecification)
    transform(input_assembler, dag._step_output_fields) # Will throw if any field doesn't exist
    return nothing
end

"""
    field_dict(type::Type{<:NoThrowResult})
    field_dict(type)

Return a `Dict` where keys are `fieldnames(type)` and the value of each key is that
field's own type. Constructed by calling `field_dict_value` on each input field's
type.

When `type` is a `NoThrowResult{T}`, generate mapping based on unwrapped type `T`.

To recurse into a specific type `MyType`, implement
```
TransformSpecification.field_dict_value(t::Type{MyType}) = field_dict(t)
```

!!! warning
    Use caution when implementing a `field_dict_value` for any type that isn't explicitly
    impossible to lead to recursion, as otherwise a stack overflow may occur.
"""
field_dict(type::Type{<:NoThrowResult}) = field_dict(result_type(type))

function field_dict(type)
    return Dict(map(fieldnames(type), fieldtypes(type)) do fname, ftype
        return fname => field_dict_value(ftype)
    end)
end

field_dict_value(type::Type{<:NoThrowResult}) = field_dict_value(result_type(type))
field_dict_value(type::Type) = type

Base.length(dag::NoThrowDAG) = length(dag.step_transforms)

"""
    get_step(dag::NoThrowDAG, name::String) -> DAGStep
    get_step(dag::NoThrowDAG, step_index::Int) -> DAGStep

Return `DAGStep` with `name` or `step_index`.
"""
function get_step(dag::NoThrowDAG, name::String)
    return DAGStep(name, dag.step_input_assemblers[name], dag.step_transforms[name])
end

function get_step(dag::NoThrowDAG, step_index::Int)
    return get_step(dag, collect(keys(dag.step_transforms))[step_index])
end

"""
    input_specification(dag::NoThrowDAG)

Return `input_specification` of first step in `dag`, which is the input specification
of the entire DAG.

See also: [`output_specification`](@ref), [`NoThrowDAG`](@ref)
"""
function input_specification(dag::NoThrowDAG)
    return input_specification(first(dag.step_transforms)[2])
end

"""
    output_specification(dag::NoThrowDAG) -> Type{<:Legolas.AbstractRecord}

Return output_specification of last step in `dag`, which is the output specification
of the entire DAG.

See also: [`input_specification`](@ref), [`NoThrowDAG`](@ref)
"""
function output_specification(c::NoThrowDAG)
    return output_specification(last(c.step_transforms)[2])
end

"""
    transform!(dag::NoThrowDAG, input)

Return [`NoThrowResult`](@ref) of sequentially [`transform!`](@ref)ing all
`dag.step_transforms`, after passing `input` to the first step.

Before each step, that step's `input_assembler` is called on the results of all
previous processing steps; this constructor generates input that conforms to the
step's `input_specification`.
"""
function transform!(dag::NoThrowDAG, input)
    warnings = String[]
    component_results = OrderedDict{String,Any}()
    for (i_step, (name, step)) in enumerate(dag.step_transforms)
        @debug "Applying step `$name`..."

        # 1. First, assemble the step's input
        InSpec = input_specification(step)
        input = if i_step == 1
            # The initial input record does not need to be constructed---it is
            # :just: the initial input to the dag at large
            input
        else
            nt_result = transform!(NoThrowTransform(dag.step_input_assemblers[name]),
                                   component_results)
            nothrow_succeeded(nt_result) || return nt_result
            append!(warnings, nt_result.warnings)
            nt_result.result
        end

        # ...and check that it meets the step's input specification.
        # (Even though this would happen for "free" inside the step's transform,
        # we check here first so that we can surface a more informative error message)
        try
            convert_spec(InSpec, input)
        catch e
            return NoThrowResult(; warnings,
                                 violations="Input to step `$name` doesn't conform to specification `$(InSpec)`. Details: $e")
        end

        # 2. Apply the step's transform!
        # Note that output specification checking _is_ performed inside this transform
        result = transform!(step, input)
        # ...and capture any warnings generated by this step
        append!(warnings, result.warnings)

        # 3. Bookkeeping: return early if the step failed, or store the results for downstream steps
        if !isempty(result.violations)
            return NoThrowResult(; warnings, result.violations)
        end
        component_results[name] = result.result
    end
    return NoThrowResult(; warnings, result=last(component_results)[2])
end

function Base.show(io::IO, c::NoThrowDAG)
    str = "NoThrowDAG ($(input_specification(c)) => $(result_type(output_specification(c)))):\n"
    for (i, (k, v)) in enumerate(c.step_transforms)
        bullet = if i == 1
            "🌱"
        elseif i == length(c.step_transforms)
            "🌷"
        else
            " ·"
        end
        str *= "  $bullet  $k: $(input_specification(v)) => $(output_specification(v.transform_spec)): `$(v.transform_spec.transform_fn)`\n"
    end
    return print(io, chomp(str))
end
