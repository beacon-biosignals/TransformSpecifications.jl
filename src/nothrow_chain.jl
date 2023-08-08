#####
##### `ChainStep`
#####

"""
    ChainStep

Helper struct, used to construct [`NoThrowTransformChain`](@ref)s. Requires fields
* `name::String`: Name of step, must be unique across a constructed chain
* `transform_spec::AbstractTransformSpecification`: Transform applied by step
* `input_assembler::UpstreamOutputsTransform`: Transform that takes in a Dictionary with keys that are the
    names of upstream steps; the value of each of these keys is the output of that
    upstream_step, as specified by `output_specification(upstream_step)`. The constructor
    should return a `NamedTuple` that can be converted to specification
    `input_specification(transform_spec)` via [convert_spec`](@ref).
"""
struct ChainStep
    name::String
    input_assembler::Union{TransformSpecification,Nothing}
    transform_spec::AbstractTransformSpecification

    function ChainStep(name, input_assembler, transform_spec)
        if !(isnothing(input_assembler) || is_input_assembler(input_assembler))
            throw(ArgumentError("Invalid `input_assembler`"))
        end
        return new(name, input_assembler, transform_spec)
    end
end

# TODO-help: I _think_ I want to make this a type, but it's kinda annoying to have
# to specify ANOTHER concrete type, when it really is just an instance of a
# TransformSpecification with pre-defined types. Thoughts?!
"""
    input_assembler(conversion_fn) -> TransformSpecification{Dict{String,Any}, NamedTuple}

Special transform used to convert the outputs of upstream steps in a
[`NoThrowTransformChain`](@ref) chain into a `NamedTuple` that can be converted into
that type's input specification.
"""
function input_assembler(conversion_fn)
    return TransformSpecification(Dict{String,Any}, NamedTuple, conversion_fn)
end

"""
    input_assembler(ts::AbstractTransformSpecification) -> Bool

Confirm that `ts` is an [`input_assembler`](@ref).
"""
function is_input_assembler(ts::AbstractTransformSpecification)
    return input_specification(ts) == Dict{String,Any} &&
           output_specification(ts) == NamedTuple
end
is_input_assembler(::Any) = false

#####
##### `NoThrowTransformChain`
#####

#TODO: make const
DOCTEST_nothrowchain_ex1_OUTPUT = """
flowchart LR

%% Add steps (nodes)
subgraph STEP_A[Step a]
  direction TB
  subgraph STEP_A_InputSchema[Input: ExampleOneVarSchemaV1]
    direction RL
    STEP_A_InputSchemavar[var]
  end
  subgraph STEP_A_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_A_OutputSchemavar[var]
  end
  STEP_A_InputSchema == fn_a ==> STEP_A_OutputSchema
end
subgraph STEP_B[Step b]
  direction TB
  subgraph STEP_B_InputSchema[Input: ExampleOneVarSchemaV1]
    direction RL
    STEP_B_InputSchemavar[var]
  end
  subgraph STEP_B_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_B_OutputSchemavar[var]
  end
  STEP_B_InputSchema == fn_b ==> STEP_B_OutputSchema
end
subgraph STEP_C[Step c]
  direction TB
  subgraph STEP_C_InputSchema[Input: ExampleTwoVarSchemaV1]
    direction RL
    STEP_C_InputSchemavar1[var1]
    STEP_C_InputSchemavar2[var2]
  end
  subgraph STEP_C_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_C_OutputSchemavar[var]
  end
  STEP_C_InputSchema == fn_c ==> STEP_C_OutputSchema
end

%% Link steps (nodes)
STEP_A -.-> STEP_B
STEP_B -.-> STEP_C

%% Link step i/o fields
"""

"""
    NoThrowTransformChain <: AbstractTransformSpecification
    NoThrowTransformChain(steps::AbstractVector{ChainStep})

Processing component that runs a sequence of [`AbstractTransformSpecification`](@ref) steps,
by calling [`transform!`](@ref) on each step in order. The chain's `input_specification` is that of the
first element in `step_transforms`; the chain's `output_specification` is that of the last
element in the `step_transforms`.

The steps are stored internally as an `OrderedDict{:String,AbstractTransformSpecification}`
of `<step name> => <step transform>`, along with the instructions (`step_input_assemblers`)
for constructing the input to each step as a function of all previous ouput component
results. Each key in `step_transforms` has a corresponding key in `step_input_assemblers`.
(This input construction approach/type may change in an upcoming release.)

To grant downstream access to all fields passed into the first step, the first step should
be an identity transform, i.e., `is_identity_no_throw_transform(first(steps))` should return true. Additionally,
as the input to the first step is the input to the chain at large, the chain does not construct
the first step's input before calling the first step, and therefore the first step'same
input construction function must be `nothing`.

!!! warn
    It is the caller's responsibility to implement a DAG, and to not introduce
    any recursion or cycles. What will happen if you do? To quote Tom Lehrer,
    "[well, you ask a silly question, you get a silly answer](https://youtu.be/zWPn3esuDgU?t=189)!"

## Fields

- `step_transforms::OrderedDict{String,AbstractTransformSpecification}`: Ordered dictionary of processing steps
- `step_input_assemblers::Dict{String,TransformSpecification}`: Dictionary with functions for constructing the input
    for each key in `step_transforms` as a function that takes in a Dict{String,NoThrowResult}
    of all upstream `step_transforms` results.
- `_step_output_fields::Dict{String,Dict{Symbol,Any}}`: Internal mapping of upstream step
    outputs to downstream inputs, used to e.g. valdiate that the input to each step
    in a chain can be constructed from the outputs of the upstream steps.

## Example

```jldoctest nothrowchain_ex1
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

steps = [ChainStep("step_a", nothing, step_a_transform),
         ChainStep("step_b", step_b_assembler, step_b_transform),
         ChainStep("step_c", step_c_assembler, step_c_transform)]
chain = NoThrowTransformChain(steps)

# output
NoThrowTransformChain (ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1):
  🌱  step_a: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_a`
   ·  step_b: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_b`
  🌷  step_c: ExampleTwoVarSchemaV1 => ExampleOneVarSchemaV1: `fn_c`
```
This chain can then be applied to an input, just like a regular `TransformSpecification`
can:
```jldoctest nothrowchain_ex1
input = ExampleOneVarSchemaV1(; var="initial_str")
transform!(chain, input)

# output
NoThrowResult{ExampleOneVarSchemaV1}: Transform succeeded
  ✅ result: ExampleOneVarSchemaV1:
 :var  "initial_str_ainitial_str_a_b_c"
```
Similarly, this transform will fail if the input specification is violated---but
because it returns a [`NoThrowResult`](@ref), it will fail gracefully:
```jldoctest nothrowchain_ex1
# What is the input specification?
input_specification(chain)

# output
ExampleOneVarSchemaV1
```
```jldoctest nothrowchain_ex1
transform!(chain, ExampleTwoVarSchemaV1(; var1="wrong", var2="input schema"))

# output
NoThrowResult{Missing}: Transform failed
  ❌ Input to step `step_a` doesn't conform to specification `ExampleOneVarSchemaV1`. Details: ArgumentError("Invalid value set for field `var`, expected String, got a value of type Missing (missing)")
```

To visualize this chain, you may want to generate a [mermaid plot](https://mermaid.js.org/).
To do this, use [`mermaidify`](@ref):

```jldoctest nothrowchain_ex1
mermaid_str = mermaidify(chain)
print(mermaid_str)

# output
$DOCTEST_nothrowchain_ex1_OUTPUT
```

By wrapping this string in a "mermaid" code block in a markdown document,
it can be rendered graphically. If in GitHub, this will happen automatically;
if in e.g. Documenter.jl, [additional setup will be required](https://github.com/JuliaDocs/Documenter.jl/issues/1943).

For markdown, do
````markdown
```mermaid
{{mermaidify output}}
```
````
and for html (i.e., for Documenter.jl), do
````markdown
<div class=\"mermaid\">
{{mermaidify output}}
</div>
````
This will then be displayed graphically as
```@raw html
<svg style="display: block; margin: 0 auto;" width="5em" heigth="5em">
	<circle cx="2.5em" cy="2.5em" r="2em" stroke="black" stroke-width=".1em" fill="red" />
</svg>
```

```@raw html
<div class="mermaid">
$(DOCTEST_nothrowchain_ex1_OUTPUT)
</div>
```
"""
struct NoThrowTransformChain <: AbstractTransformSpecification
    step_transforms::OrderedDict{String,NoThrowTransform}
    step_input_assemblers::Dict{String,Any}
    _step_output_fields::Dict{String,Any}

    function NoThrowTransformChain(init_step::ChainStep)
        if !isnothing(init_step.input_assembler)
            throw(ArgumentError("Initial step's input constructor must be `nothing` ($(init_step.input_assembler))"))
        end
        step_transforms = OrderedDict(init_step.name => NoThrowTransform(init_step.transform_spec))
        step_input_assemblers = Dict(init_step.name => nothing)
        _step_output_fields = Dict{String,Dict{Symbol,Any}}(init_step.name => construct_field_map(output_specification(init_step.transform_spec)))
        return new(step_transforms, step_input_assemblers, _step_output_fields)
    end
end

function NoThrowTransformChain(steps::AbstractVector{<:ChainStep})
    length(steps) == 0 &&
        throw(ArgumentError("At least one step required to construct a chain"))
    chain = NoThrowTransformChain(first(steps))
    for step in steps[2:end]
        push!(chain, step)
    end
    return chain
end

function Base.push!(chain::NoThrowTransformChain, step::ChainStep)
    # Safety first!
    haskey(chain.step_transforms, step.name) &&
        throw(ArgumentError("Key `$(step.name)` already exists in chain!"))
    _validate_input_assembler(chain, step.input_assembler)

    # Forge it!
    push!(chain.step_transforms, step.name => NoThrowTransform(step.transform_spec))
    push!(chain.step_input_assemblers, step.name => step.input_assembler)
    push!(chain._step_output_fields,
          step.name => construct_field_map(output_specification(step.transform_spec)))
    return chain
end

# Base extensions to support iterator interface: https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-iteration
Base.length(chain::NoThrowTransformChain) = length(chain.step_transforms)
Base.size(chain::NoThrowTransformChain) = (length(chain),)
Base.firstindex(::NoThrowTransformChain) = 1
Base.lastindex(chain::NoThrowTransformChain) = length(chain)
Base.IteratorEltype(chain::NoThrowTransformChain) = eltype(chain)
Base.eltype(chain::NoThrowTransformChain) = ChainStep
function Base.iterate(chain::NoThrowTransformChain, state=1)
    return state > length(chain) ?  nothing : (get_step(chain, state), state + 1)
end

Base.keys(chain::NoThrowTransformChain) = collect(keys(chain.step_transforms))

#TODO-Future: consider making a constructor that special-cases when taking in
# a specification that has a single field (e.g., a Samples object or something)
# instead of doing this version that is geared at named tuple creation
"""
    _validate_input_assembler(chain::NoThrowTransformChain, input_assembler::TransformSpecification)
    _validate_input_assembler(chain::NoThrowTransformChain, ::Nothing)

Confirm that an input_assembler, when called on all upstream outputs generated by
`chain`, has access to all fields it needs to construct its input.
"""
_validate_input_assembler(::NoThrowTransformChain, ::Nothing) = nothing

function _validate_input_assembler(chain::NoThrowTransformChain,
                                   input_assembler::TransformSpecification)
    transform(input_assembler, chain._step_output_fields) # Will throw if any field doesn't exist
    return nothing
end

"""
    construct_field_map(type::Type{<:NoThrowResult})
    construct_field_map(type)

Return a `Dict` where keys are `fieldnames(type)` and the value of each key is that
field's own type. Constructed by calling `_field_map` on each input field's
type.

When `type` is a `NoThrowResult{T}`, generate mapping based on unwrapped type `T`.

To recurse into a specific type `MyType`, implement
```
TransformSpecification._field_map(t::Type{MyType}) = construct_field_map(t)
```
"""
construct_field_map(type::Type{<:NoThrowResult}) = construct_field_map(result_type(type))
function construct_field_map(type)
    return Dict(map(zip(fieldnames(type), fieldtypes(type))) do (fieldname, fieldtype)
                    return fieldname => _field_map(fieldtype)
                end)
end

_field_map(type::Type{<:NoThrowResult}) = _field_map(result_type(type))
_field_map(type::Type) = type

"""
    get_step(chain::NoThrowTransformChain, name::String) -> ChainStep
    get_step(chain::NoThrowTransformChain, step_index::Int) -> ChainStep

Return `ChainStep` with `name` or `step_index`.
"""
function get_step(chain::NoThrowTransformChain, name::String)
    return ChainStep(name, chain.step_input_assemblers[name], chain.step_transforms[name])
end

function get_step(chain::NoThrowTransformChain, step_index::Int)
    return get_step(chain, keys(chain)[step_index])
end

"""
    input_specification(chain::NoThrowTransformChain)

Return `input_specification` of first step in `chain`, which is the input specification
of the entire chain.

See also: [`output_specification`](@ref), [`NoThrowTransformChain`](@ref)
"""
function input_specification(chain::NoThrowTransformChain)
    return input_specification(first(chain.step_transforms)[2])
end

"""
    output_specification(chain::NoThrowTransformChain) -> Type{<:Legolas.AbstractRecord}

Return output_specification of last step in `chain`, which is the output specification
of the entire chain.

See also: [`input_specification`](@ref), [`NoThrowTransformChain`](@ref)
"""
function output_specification(c::NoThrowTransformChain)
    return output_specification(last(c.step_transforms)[2])
end

"""
    transform!(chain::NoThrowTransformChain, input)

Return [`NoThrowResult`](@ref) of sequentially [`transform!`](@ref)ing all
`chain.step_transforms`, after passing `input` to the first step.

Before each step, that step's input constructor is called on the results of all
previous processing steps; this constructor generates input that conforms to the
step's `input_specification`.

The initial step does not call an input constructor; instead, input to the chain
is forward to it directly.
"""
function transform!(chain::NoThrowTransformChain, input)
    warnings = String[]
    component_results = OrderedDict{String,Any}()
    for (i_step, (name, step)) in enumerate(chain.step_transforms)
        @debug "Applying step `$name`..."
        InSpec = input_specification(step)
        input = if i_step == 1
            # The initial input record does not need to be constructed---it already
            # exists---but it still needs to be validated
            input
        else
            nt_result = transform!(NoThrowTransform(chain.step_input_assemblers[name]),
                                   component_results)
            nothrow_succeeded(nt_result) || return nt_result
            append!(warnings, nt_result.warnings)
            nt_result.result
        end

        # Check that input meets specification. Do it here rather than relying on
        # transform!(::NoThrowTransform, ...) so that any error warnings are more
        # informative
        try
            convert_spec(InSpec, input) #(; input_nt...))
        catch e
            return NoThrowResult(; warnings,
                                 violations="Input to step `$name` doesn't conform to specification `$(InSpec)`. Details: $e")
        end

        # Do transformation
        result = transform!(step, input)

        # Compile results
        append!(warnings, result.warnings)
        isempty(result.violations) ||
            return NoThrowResult(; warnings, result.violations)
        component_results[name] = result.result
    end
    return NoThrowResult(; warnings, result=last(component_results)[2])
end

function Base.show(io::IO, c::NoThrowTransformChain)
    str = "NoThrowTransformChain ($(input_specification(c)) => $(result_type(output_specification(c)))):\n"
    for (i, (k, v)) in enumerate(c.step_transforms)
        bullet = i == 1 ? "🌱" : (i == length(c.step_transforms) ? "🌷" : " ·") #"☀️ ")
        str *= "  $bullet  $k: $(input_specification(v)) => $(output_specification(v.transform_spec)): `$(v.transform_spec.transform_fn)`\n"
    end
    return print(io, chomp(str))
end
