"""
    NoThrowResult{T}(; warnings::Union{String,Vector{String}}=String[],
                     violations::Union{String,Vector{String}}=String[],
                     result::T)
    NoThrowResult(result::T; kwargs...)

Type that specifies the result of a transformation that indicates success of a
transform through presence (or lack thereof) of `violations`.

Consists of either a non-`missing` `result` or a non-empty `violations`.

See also: [`nothrow_succeeded`](@ref)

## Fields

- `warnings::Vector{String}`: List of generated warnings that are not critical
    enough to be `violations`.
- `violations::Vector{String}` List of reason(s) `result` was not able to be generated.
- `result::`: Generated `result`; `missing` if any `violations` encountered.

## Example

```jldoctest
julia> @schema "example" ExampleSchema
julia> @version ExampleSchemaV1 begin
    name::String
end

julia> NoThrowResult(ExampleSchemaV1(; name="yeehaw"))
NoThrowResult{ExampleSchemaV1}: Transform succeeded
  ✅ result: ExampleSchemaV1:
 :name  "yeehaw"

julia> NoThrowResult(ExampleSchemaV1(; name="huzzah");
                     warnings="Hark, watch your step...")
NoThrowResult{ExampleSchemaV1}: Transform succeeded
  ⚠️  Hark, watch your step...
  ☑️  result: ExampleSchemaV1:
 :name  "huzzah"

julia> NoThrowResult(; violations=["Epic fail!", "Slightly less epic fail!"],
                     warnings=["Uh oh..."])
NoThrowResult{Missing}: Transform failed
  ❌ Epic fail!
  ❌ Slightly less epic fail!
  ⚠️  Uh oh...
  ❌ result: missing
```
"""
struct NoThrowResult{T}
    warnings::Vector{String}
    violations::Vector{String}
    result::T

    function NoThrowResult(; warnings::Union{String,Vector{String}}=String[],
                           violations::Union{String,Vector{String}}=String[],
                           result=missing)
        if ismissing(result) && isempty(violations)
            throw(ArgumentError("Invalid construction: either `result` must be non-missing \
                                 OR `violations` must be non-empty."))
        end
        if !ismissing(result) && !isempty(violations)
            throw(ArgumentError("Invalid construction: if `violations` are non-empty, \
                                `result` must be `missing`."))
        end
        warnings isa Vector{String} || (warnings = [warnings])
        violations isa Vector{String} || (violations = [violations])
        return new{typeof(result)}(warnings, violations, result)
    end
end

function NoThrowResult(result; warnings=String[], violations=String[])
    return NoThrowResult(; result, warnings, violations)
end

function Base.show(io::IO, r::NoThrowResult)
    succeeded = nothrow_succeeded(r)
    str = "$(typeof(r)): Transform $(succeeded ? "succeeded" : "failed")\n"
    for v in r.violations
        str *= "  ❌ $v\n"
    end
    for w in r.warnings
        str *= "  ⚠️  $w\n"
    end
    if ismissing(r.result)
        str = chomp(str)
    else
        str *= "  ✅ result: $(r.result)"
    end
    return print(io, str)
end

"""
    nothrow_succeeded(result::NoThrowResult) -> Bool

Return `true` if `result` indicates successful completion, i.e. if `result.violations`
is empty.

See also: [`NoThrowResult`](@ref)
"""
nothrow_succeeded(::NoThrowResult{Missing}) = false
nothrow_succeeded(::NoThrowResult) = true

#####
##### `NoThrowTransform`
#####

"""
    NoThrowTransform{T<:Type,U<:Type} <: AbstractTransformSpecification

Basic component that transforms input of type `T` to output of type `U`, returning
a [`NoThrowResult`](@ref) of type `NoThrowResult{U}` if the transform succeeds and
`NoThrowResult{Missing}` if an expected exception is encountered.

## Fields

- `input_specification::T`
- `output_specification::U`
- `transform_fn::Function` Function with signature `transform_fn(::input_specification) -> NoThrowResult{output_specification}`

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
    out_name = in_record.in_name * " earthling"
    return NoThrowResult(ExampleOutSchemaV1(; out_name))
end
julia> p = NoThrowTransform(ExampleInSchemaV1, ExampleOutSchemaV1, apply_example)
NoThrowTransform{ExampleInSchemaV1,ExampleOutSchemaV1}: `apply_example`

julia> transform!(p, ExampleInSchemaV1(; in_name="greetings"))
NoThrowResult{ExampleOutSchemaV1}: Transform succeeded
  ✅ result: ExampleOutSchemaV1:
 :out_name  "greetings earthling"

julia> force_failure_example(in_record) = NoThrowResult(; violations=["womp", "womp"])

julia> p = NoThrowTransform(ExampleInSchemaV1, ExampleOutSchemaV1, force_failure_example)
NoThrowTransform{ExampleInSchemaV1,ExampleOutSchemaV1}: `force_failure_example`

julia> transform!(p, ExampleInSchemaV1(; in_name="greetings"))
NoThrowResult{Mising}: Transform failed
  ❌ womp
  ❌ womp
```
"""
Base.@kwdef struct NoThrowTransform{T<:Type,U<:Type} <: AbstractTransformSpecification
    input_specification::T
    output_specification::U
    transform_fn::Function  # TODO-help: any way to validate the function signature (in type or on construction), to ensure takes in input schema as specified, spits out output schema?
end

input_specification(ntt::NoThrowTransform) = ntt.input_specification

function output_specification(ntt::NoThrowTransform)
    return Union{NoThrowResult{Missing},NoThrowResult{ntt.output_specification}}
end

"""
    transform!(ntt::NoThrowTransform, input)

Return [`NoThrowResult`](@ref) of applying `ntt.transform_fn` to `input`. If `input`
does not conform to `input_specification(ntt)` or `ntt.transform_fn` fails, will
return `NoThrowResult{Missing}` with the cause of failure noted in the `violations`.
"""
function transform!(ntt::NoThrowTransform, input)
    try
        # Check that input conforms to input schema (doesn't matter if it _actually_
        # is of the same schema type, or a child, or whatever. if it conforms? it's valid.)
        # TODO-help: is there a better way to do this? e.g. to use Legolas.find_violations instead of this?
        input_specification(ntt)(input)
    catch e
        return NoThrowResult(;
                             violations="Input doesn't conform to expected specification $(input_specification(ntt)). Details: " *
                                        string(e))
    end
    return ntt.transform_fn(input)
end

function Base.show(io::IO, p::NoThrowTransform)
    return print(io,
                 "NoThrowTransform{$(p.input_specification),$(p.output_specification)}: `$(p.transform_fn)`")
end

"""
    identity_no_throw_transform(io_schema::Type{<:Legolas.AbstractRecord}) -> NoThrowTransform{io_schema}

Create [`NoThrowTransform`](@ref) where `input_specification==output_specification` and `transform_fn`
result is a `NoThrowResult{io_schema}`.

Required to be the first element in a [`NoThrowTransformChain`](@ref).

See also: [`is_identity_no_throw_transform`](@ref)
"""
function identity_no_throw_transform(io_schema::Type{<:Legolas.AbstractRecord})
    return NoThrowTransform(io_schema, io_schema, identity_process_result_transform)
end

#TODO-help: i don't really want to have to define a function for this, I want to
# `just` use `NoThrowResult` instead of a defined function from w/in `identity_no_throw_transform`, but the construtor for
# NoThrowResult is not recognized as conforming to the `::Function` type on contruction :(
# TODO: ALSO the name for this is terrible. hold off on bikeshedding until overall package rename is complete
function identity_process_result_transform(io_schema::Type{<:Legolas.AbstractRecord})
    return NoThrowResult(r)
end

"""
    is_identity_no_throw_transform(ntt::NoThrowTransform) -> Bool

Check if `ntt` meets the definition of an [`identity_no_throw_transform`](@ref).
"""
function is_identity_no_throw_transform(ntt::NoThrowTransform)
    if input_specification(ntt) != output_specification(ntt)
        @debug "Input and output schemas are not identical: $ntt"
        return false
    end
    is_identity = isequal(ntt.transform_fn, identity_process_result_transform)
    if !is_identity
        @debug "`transform_fn` is not `identity_process_result_transform`"
    end
    return is_identity
end

#####
##### `NoThrowTransformChain`
#####
# TODO-future: implement regular TransformChain that is allowed to throw...or decide to make this one support both
# Note that this chain

"""
    NoThrowTransformChain <: AbstractTransformSpecification
    NoThrowTransformChain(steps::Vector{<:Tuple{Symbol,AbstractTransformSpecification, Function}})

Processing component that runs a sequence of [`AbstractTransformSpecification`](@ref) `transform_steps`,
by [`transform!`](@ref)ing each step in order. The chain's `input_specification` is that of the
first element in `transform_steps`; the chain's `output_specification` is that of the last
element in the `transform_steps`.

The `transform_steps` are stored internally as an `OrderedDict{:Symbol,AbstractTransformSpecification}`
of `<step name> => <step transform>`, along with the instructions (`input_constructors`)
for constructing the input to each step as a function of all previous ouput component
results. Each key in `transform_steps` has a corresponding key in `input_constructors`.
(This input construction approach/type may change in an upcoming release.)

The constructor that takes in series of `steps` expects steps to take the format
`(name, transform, input_constructor)`.

To grant downstream access to all fields passed into the first step, the first step should
be an identity transform, i.e., `is_identity_no_throw_transform(step)` should return true. Additionally,
as the input to the first step is the input to the chain at large, the chain does not construct
the first step's input before calling the first step, and therefore the first step'same
input construction function must be `nothing`.

!!! warn
    It is the caller's responsibility to only implement a DAG, and to not introduce
    recursion by constructing a chain that includes that same chain as a processing
    step! To quote Tom Lehrer, "[you ask a silly question, you get a silly answer](https://youtu.be/zWPn3esuDgU?t=189)."

## Fields

- `transform_steps::OrderedDict{Symbol,AbstractTransformSpecification}` Ordered processing steps
- `input_constructors::Dict{Symbol,Function}` Dictionary with functions for constructing the input
    for each key in `transform_steps` as a function that takes in a Dict{Symbol,NoThrowResult}
    of all upstream `transform_steps` results.

## Example

TODO-future
```jldoctest
```
"""
struct NoThrowTransformChain <: AbstractTransformSpecification
    transform_steps::OrderedDict{Symbol,AbstractTransformSpecification}
    input_constructors::Dict{Symbol,Union{Nothing,Function}}

    function NoThrowTransformChain(transform_steps::OrderedDict,
                                   input_constructors::Dict)
        first_key = first(keys(transform_steps))
        constructor_keys = push!(Set(collect(keys(input_constructors))), first_key)
        if !issetequal(keys(transform_steps), constructor_keys)
            a = collect(setdiff(keys(transform_steps), keys(input_constructors)))
            b = collect(setdiff(keys(input_constructors), keys(transform_steps)))
            str = "Mismatch in chain steps:"
            isempty(a) ||
                (str *= "\n- Keys present in `transform_steps` are missing in `input_constructors`: $a")
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
        return new(transform_steps, input_constructors)
    end
end

const ChainStepType = Tuple{Symbol,AbstractTransformSpecification,
                            Union{Nothing,Function}}

function NoThrowTransformChain(steps::Vector{<:ChainStepType})
    transform_steps = OrderedDict{Symbol,AbstractTransformSpecification}()
    input_constructors = Dict{Symbol,Union{Nothing,Function}}()
    for step in steps
        _add_step_to_chain(transform_steps, input_constructors, step)
    end
    return NoThrowTransformChain(transform_steps, input_constructors)
end

function _add_step_to_chain(transform_steps::OrderedDict{Symbol,
                                                         AbstractTransformSpecification},
                            input_constructors::Dict{Symbol,Union{Nothing,Function}},
                            step::ChainStepType)
    (key, transform, input_constructor) = step
    haskey(transform_steps, key) &&
        throw(ArgumentError("Key `$key` already exists in chain!"))
    push!(transform_steps, key => transform)
    push!(input_constructors, key => input_constructor) #TODO: first validate that these are possible...
    return nothing
end

function Base.append!(chain::NoThrowTransformChain, step::ChainStepType)
    return _add_step_to_chain(chain.transform_steps, chain.input_constructors, step)
end

"""
    input_specification(chain::NoThrowTransformChain) -> Type{<:Legolas.AbstractRecord}

Return Legolas schema of record accepted as input to first step in `chain.transform_steps`.
"""
function input_specification(c::NoThrowTransformChain)
    return first(c.transform_steps)[2].input_specification
end

"""
    output_specification(chain::NoThrowTransformChain) -> Type{<:Legolas.AbstractRecord}

Return Legolas schema of record returned by last step in `chain.transform_steps`,
which is the record returned by successful application of the entire chain.
"""
function output_specification(c::NoThrowTransformChain)
    return last(c.transform_steps)[2].output_specification
end

"""
    transform!(chain::NoThrowTransformChain, input)

Return [`NoThrowResult`](@ref) of sequentially `transform!`ing all `chain.transform_steps`
to `input`.

Before each step (`key`), the step's `chain.input_constructors[key]` is called
on the results of all previous processing steps, in order to construct input to
the step that conforms to the step's requisite `input_specification(step)`.

Initial step does not call input construction for itself, as chain input is passed directly
into it.
"""
function transform!(chain::NoThrowTransformChain, input)
    warnings = String[]
    component_results = OrderedDict{Symbol,Legolas.AbstractRecord}()
    for (i_step, (name, step)) in enumerate(chain.transform_steps)
        @debug "Applying component `$name`..."
        input = if i_step == 1
            try
                # The initial input record does not need to be constructed---it already
                # exists---but it still needs to be validated
                input_specification(step)(input)
            catch e
                return NoThrowResult(; warnings,
                                     violations=["Failed to construct input for initial step (`$name`): $e"])
            end
        else
            # Construct
            input_nt = chain.input_constructors[name](component_results)

            # prob don't need this try/catch, as we can pass into the function as a
            # named tuple...but this way we know that it failed at this specific stage
            try
                input_specification(step)(; input_nt...)
            catch e
                return NoThrowResult(; warnings,
                                     violations=["Failed to construct input for step `$name`: $e"])
            end
        end
        result = transform!(step, input)

        # Compile results
        append!(warnings, result.warnings)
        isempty(result.violations) ||
            return NoThrowResult(; warnings, result.violations)
        component_results[name] = result.record
    end
    return NoThrowResult(; warnings, record=last(component_results)[2])
end

function Base.show(io::IO, c::NoThrowTransformChain)
    str = "NoThrowTransformChain:\n"
    for (i, (k, v)) in enumerate(c.transform_steps)
        bullet = i == 1 ? "🌱" : (i == length(c.transform_steps) ? "🌷" : "☀️")
        str *= "  $bullet  $k ($(v.input_specification) => $(v.output_specification))\n"
    end
    return print(io, str)
end
# TODO-future: support applying subsets of chain, with `init` option for passing in "upstream outputs" results
# TODO-future: define where validation happens in this chain, and how

#####
##### Shared utilities
#####

for pred in (:(==), :(isequal)),
    T in
    [AbstractTransformSpecification, NoThrowResult, NoThrowTransform,
     NoThrowTransformChain]

    @eval function Base.$pred(x::$T, y::$T)
        return all(p -> $pred(getproperty(x, p), getproperty(y, p)), fieldnames($T))
    end
end
# TODO-help: do we need a hash function for these as well?
