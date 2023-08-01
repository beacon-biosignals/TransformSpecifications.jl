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
