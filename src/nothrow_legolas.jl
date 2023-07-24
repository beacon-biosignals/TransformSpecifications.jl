#####
##### `NoThrowLegolasTransform`
#####

"""
    NoThrowLegolasTransform <: AbstractTransformSpecification

Basic processing component that converts input record with [Legolas](https://github.com/beacon-biosignals/Legolas.jl)-schema
`input_specification` to a [`NoThrowResult`](@ref) with record type `output_specification`, via `apply_fn`.

## Fields

- `input_specification::Type{<:Legolas.AbstractRecord}`
- `output_specification::Type{<:Legolas.AbstractRecord}`
- `apply_fn::Function` Function with signature `apply_fn(::input_specification) -> NoThrowResult{output_specification}`

## Example

```jldoctest
julia> @schema "example-in" ExampleInSchema
julia> @version ExampleInSchemaV1 begin
    in_name::String
end

julia> @schema "example-out" ExampleOutSchema
julia> @version ExampleOutSchemaV1 begin
    out_name::String
end

julia> function apply_example(in_record)
    out_name = in_record.in_name * "_earthling"
    return NoThrowResult(ExampleOutSchemaV1(; out_name))
end
julia> p = NoThrowLegolasTransform(ExampleInSchemaV1, ExampleOutSchemaV1, apply_example)
NoThrowLegolasTransform (input: ExampleInSchemaV1; output: ExampleOutSchemaV1; process: apply_example)

julia> transform!(p, ExampleInSchemaV1(; in_name="greetings"))
NoThrowResult: Process succeeded
  ✅ record: ExampleOutSchemaV1:
 :out_name  "greetings_earthling"

julia> force_failure_example(in_record) = NoThrowResult(; violations=["womp", "womp"])

julia> p = NoThrowLegolasTransform(ExampleInSchemaV1, ExampleOutSchemaV1, force_failure_example)
NoThrowLegolasTransform (input: ExampleInSchemaV1; output: ExampleOutSchemaV1; process: force_failure_example)

julia> transform!(p, ExampleInSchemaV1(; in_name="greetings"))
NoThrowResult: Process failed
  ❗ womp
  ❗ womp
  ❌ record: missing
```
"""
Base.@kwdef struct NoThrowLegolasTransform <: AbstractTransformSpecification
    input_specification::Type{<:Legolas.AbstractRecord}
    output_specification::Type{<:Legolas.AbstractRecord}
    apply_fn::Function  # TODO-help: how to validate the function signature (in type or on construction), to ensure takes in input schema as specified, spits out output schema?
end
#= TODO-decide: should we make this parametric on input and output schema?? could be kinda cool...
# e.g.
Base.@kwdef struct NoThrowLegolasTransform{T,U} where {T<:Type{<:Legolas.AbstractRecord}, U<:Type{<:Legolas.AbstractRecord}} <: AbstractTransformSpecification
    input_specification::T
    output_specification::U
    apply_fn::Function
end
=#

#TODO-decide: do we want to enforce `input_record` type? how, if we wanted to?
"""
    transform!(process::NoThrowLegolasTransform, input_record)

Return [`NoThrowResult`](@ref) of applying `process.apply_fn` to `input_record`.
"""
function transform!(process::NoThrowLegolasTransform, input_record)
    try
        # Check that input conforms to input schema (doesn't matter if it _actually_
        # is of the same schema type, or a child, or whatever. if it conforms? it's valid.)
        # TODO-help: is there a better way to do this? e.g. to use Legolas.find_violations instead of this?
        process.input_specification(input_record)
    catch e
        return NoThrowResult(;
                             violations="Record doesn't conform to input schema $(process.input_specification). Details: " *
                                        string(e))
    end
    return process.apply_fn(input_record)
end

input_specification(process::NoThrowLegolasTransform) = process.input_specification
output_specification(process::NoThrowLegolasTransform) = process.output_specification

function Base.show(io::IO, p::NoThrowLegolasTransform)
    return print(io,
                 "NoThrowLegolasTransform (input: $(p.input_specification); output: $(p.output_specification); process: $(p.apply_fn))")
end

"""
    identity_legolas_process(io_schema::Type{<:Legolas.AbstractRecord}) -> NoThrowLegolasTransform{io_schema}

Create [`NoThrowLegolasTransform`](@ref) where `input_specification==output_specification` and `apply_fn`
result is a `NoThrowResult{io_schema}`.

Required to be the first element in a [`TransformSpecificationChain`](@ref).

See also: [`is_identity_process`](@ref)
"""
function identity_legolas_process(io_schema::Type{<:Legolas.AbstractRecord})
    return NoThrowLegolasTransform(io_schema, io_schema, identity_process_result_transform)
end

#TODO-help: i don't really want to have to define a function for this, I want to
# `just` use `NoThrowResult` instead of a defined function from w/in `identity_legolas_process`, but the construtor for
# NoThrowResult is not recognized as conforming to the `::Function` type on contruction :(
# TODO: ALSO the name for this is terrible. hold off on bikeshedding until overall package rename is complete
function identity_process_result_transform(io_schema::Type{<:Legolas.AbstractRecord})
    return NoThrowResult(r)
end

"""
    is_identity_process(process::NoThrowLegolasTransform) -> Bool

Check if `process` meets the definition of an [`identity_legolas_process`](@ref).
"""
function is_identity_process(process::NoThrowLegolasTransform)
    if input_specification(process) != output_specification(process)
        @debug "Input and output schemas are not identical: $process"
        return false
    end
    is_identity = isequal(process.apply_fn, identity_process_result_transform)
    if !is_identity
        @debug "`apply_fn` is not `identity_process_result_transform`"
    end
    return is_identity
end

#####
##### `TransformSpecificationChain`
#####

"""
    TransformSpecificationChain <: AbstractTransformSpecification
    TransformSpecificationChain(steps::Vector{<:Tuple{Symbol,AbstractTransformSpecification, Function}})

Processing component that runs a sequence of [`AbstractTransformSpecification`](@ref) `process_steps`,
by [`transform!`](@ref)ing each step in order. The chain's `input_specification` is that of the
first element in `process_steps`; the chain's `output_specification` is that of the last
element in the `process_steps`.

The `process_steps` are stored internally as an `OrderedDict{:Symbol,AbstractTransformSpecification}`
of `<step name> => <step process>`, along with the instructions (`input_constructors`)
for constructing the input to each step as a function of all previous ouput component
results. Each key in `process_steps` has a corresponding key in `input_constructors`.
(This input construction approach/type may change in an upcoming release.)

The constructor that takes in series of `steps` expects steps to take the format
`(name, process, input_constructor)`.

To grant downstream access to all fields passed into the first step, the first step should
be an identity process, i.e., `is_identity_process(step)` should return true. Additionally,
the first step receives input directly from the overall process chain input, so
does not construct its own input; its input construction function must therefore by `nothing`.

!!! warn
    It is the caller's responsibility to only implement a DAG, and to not introduce
    recursion by constructing a chain that includes that same chain as a processing
    step! To quote Tom Lehrer, "[you ask a silly question, you get a silly answer](https://youtu.be/zWPn3esuDgU?t=189)."

## Fields

- `process_steps::OrderedDict{Symbol,AbstractTransformSpecification}` Ordered processing steps
- `input_constructors::Dict{Symbol,Function}` Dictionary with functions for constructing the input
    for each key in `process_steps` as a function that takes in a Dict{Symbol,NoThrowResult}
    of all upstream `process_steps` results.

## Example

TODO-future
```jldoctest
```
"""
struct TransformSpecificationChain <: AbstractTransformSpecification
    process_steps::OrderedDict{Symbol,AbstractTransformSpecification}
    input_constructors::Dict{Symbol,Union{Nothing,Function}}

    function TransformSpecificationChain(process_steps::OrderedDict,
                                         input_constructors::Dict)
        first_key = first(keys(process_steps))
        constructor_keys = push!(Set(collect(keys(input_constructors))), first_key)
        if !issetequal(keys(process_steps), constructor_keys)
            a = collect(setdiff(keys(process_steps), keys(input_constructors)))
            b = collect(setdiff(keys(input_constructors), keys(process_steps)))
            str = "Mismatch in chain steps:"
            isempty(a) ||
                (str *= "\n- Keys present in `process_steps` are missing in `input_constructors`: $a")
            isempty(b) ||
                (str *= "\n- Keys present in `input_constructors` are missing in `input_constructors`: $b")
            throw(ArgumentError(str))
        end
        if haskey(input_constructors, first_key) &&
           !isnothing(input_constructors[first_key])
            throw(ArgumentError("First step's input constructor must be `nothing`"))
        end
        # TODO: validate input_constructors dag!
        # TODO: other validation!
        return new(process_steps, input_constructors)
    end
end

const AbstractProcessChainStep = Tuple{Symbol,AbstractTransformSpecification,
                                       Union{Nothing,Function}}

function TransformSpecificationChain(steps::Vector{<:AbstractProcessChainStep})
    process_steps = OrderedDict{Symbol,AbstractTransformSpecification}()
    input_constructors = Dict{Symbol,Union{Nothing,Function}}()
    for step in steps
        _add_step_to_chain(process_steps, input_constructors, step)
    end
    return TransformSpecificationChain(process_steps, input_constructors)
end

function _add_step_to_chain(process_steps::OrderedDict{Symbol,
                                                       AbstractTransformSpecification},
                            input_constructors::Dict{Symbol,Union{Nothing,Function}},
                            step::AbstractProcessChainStep)
    (key, process, input_constructor) = step
    haskey(process_steps, key) &&
        throw(ArgumentError("Key `$key` already exists in chain!"))
    push!(process_steps, key => process)
    push!(input_constructors, key => input_constructor) #TODO: first validate that these are possible...
    return nothing
end

function Base.append!(chain::TransformSpecificationChain, step::AbstractProcessChainStep)
    return _add_step_to_chain(chain.process_steps, chain.input_constructors, step)
end

"""
    input_specification(chain::TransformSpecificationChain) -> Type{<:Legolas.AbstractRecord}

Return Legolas schema of record accepted as input to first process in `chain.process_steps`.
"""
function input_specification(c::TransformSpecificationChain)
    return first(c.process_steps)[2].input_specification
end

"""
    output_specification(chain::TransformSpecificationChain) -> Type{<:Legolas.AbstractRecord}

Return Legolas schema of record returned by last process in `chain.process_steps`,
which is the record returned by successful application of the entire chain.
"""
function output_specification(c::TransformSpecificationChain)
    return last(c.process_steps)[2].output_specification
end

"""
    transform!(chain::TransformSpecificationChain, input_record)

Return [`NoThrowResult`](@ref) of sequentially `transform!`ing all `chain.process_steps`
to `input_record`.

Before each step (`key`), the step's `chain.input_constructors[key]` is called
on the results of all previous processing steps, in order to construct input to
the step that conforms to the step's requisite `input_specification(process)`.

Initial step does not call input construction for itself, as chain input is passed directly
into it.
"""
function transform!(chain::TransformSpecificationChain, input_record)
    warnings = String[]
    component_results = OrderedDict{Symbol,Legolas.AbstractRecord}()
    for (i_process, (name, process)) in enumerate(chain.process_steps)
        @debug "Applying component `$name`..."
        input_record = if i_process == 1
            # The initial input record does not need to be constructed---it already
            # exists. (Is it valid? Who knows---but the `transform!` function will handle
            # that validation below!)
            input_record
        else
            # Construct
            input_nt = chain.input_constructors[name](component_results)

            # prob don't need this try/catch, can pass into the function as a named tuple...
            try
                process.input_specification(; input_nt...)
            catch e
                return NoThrowResult(; warnings,
                                     violations=["Process $name failed: $e"])
            end
        end
        result = transform!(process, input_record)

        # Compile results
        append!(warnings, result.warnings)
        isempty(result.violations) ||
            return NoThrowResult(; warnings, result.violations)
        component_results[name] = result.record
    end
    return NoThrowResult(; warnings, record=last(component_results)[2])
end

function Base.show(io::IO, c::TransformSpecificationChain)
    str = "TransformSpecificationChain:\n"
    for (i, (k, v)) in enumerate(c.process_steps)
        bullet = i == 1 ? "🌱" : (i == length(c.process_steps) ? "🌷" : "☀️")
        str *= "  $bullet  $k ($(v.input_specification) => $(v.output_specification))\n"
    end
    return print(io, str)
end
# TODO-future: support applying subsets of processing chain, with `init` option for passing in "upstream outputs" results
# TODO-future: define where validation happens in this chain, and how

#####
##### Shared utilities
#####

for pred in (:(==), :(isequal)),
    T in
    [AbstractTransformSpecification, NoThrowResult, NoThrowLegolasTransform,
     TransformSpecificationChain]

    @eval function Base.$pred(x::$T, y::$T)
        return all(p -> $pred(getproperty(x, p), getproperty(y, p)), fieldnames($T))
    end
end
# TODO-help: do we need a hash function for these as well?


