#####
##### `NoThrowTransformChain`
#####

"""
    ChainStep

Helper struct, used to construct [`NoThrowTransformChain`](@ref)s. Requires fields
* `name::String`: Name of step, must be unique across a constructed chain
* `transform_spec::AbstractTransformSpecification`: Transform applied by step
* `input_constructor`: Function that takes in a Dictionary with keys that are the
    names of upstream steps; the value of each of these keys is the output of that
    upstream_step, as specified by `output_specification(upstream_step)`. The constructor
    should return a `NamedTuple` that can be converted to specification
    `input_specification(transform_spec)` via [interpret_input`](@ref).
"""
struct ChainStep
    name::String
    transform_spec::AbstractTransformSpecification
    input_constructor::Any
end

"""
    NoThrowTransformChain <: AbstractTransformSpecification
    NoThrowTransformChain(steps::Vector{ChainStep})

Processing component that runs a sequence of [`AbstractTransformSpecification`](@ref) steps,
by calling [`transform!`](@ref) on each step in order. The chain's `input_specification` is that of the
first element in `step_transforms`; the chain's `output_specification` is that of the last
element in the `step_transforms`.

The steps are stored internally as an `OrderedDict{:String,AbstractTransformSpecification}`
of `<step name> => <step transform>`, along with the instructions (`step_input_constructors`)
for constructing the input to each step as a function of all previous ouput component
results. Each key in `step_transforms` has a corresponding key in `step_input_constructors`.
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

- `step_transforms::OrderedDict{String,AbstractTransformSpecification}` Ordered processing steps
- `step_input_constructors::Dict{String,Function}` Dictionary with functions for constructing the input
    for each key in `step_transforms` as a function that takes in a Dict{String,NoThrowResult}
    of all upstream `step_transforms` results.

## Example

TODO-future
```jldoctest
```
"""
struct NoThrowTransformChain <: AbstractTransformSpecification
    step_transforms::OrderedDict{String,NoThrowTransform}
    step_input_constructors::Dict{String,Any}
    io_mapping::Dict{String,Dict{Symbol,Any}}

    function NoThrowTransformChain(init_step::ChainStep)
        if !isnothing(init_step.input_constructor)
            throw(ArgumentError("Initial step's input constructor must be `nothing` (`$(init_step.input_constructor)`)"))
        end
        transform_spec = init_step.transform_spec isa NoThrowTransform ?
                         init_step.transform_spec : NoThrowTransform(transform_spec)
        step_transforms = OrderedDict(init_step.name => transform_spec)
        step_input_constructors = Dict(init_step.name => nothing)
        io_mapping = Dict(init_step.name => _field_map(output_specification(transform_spec)))
        return new(step_transforms, step_input_constructors, io_mapping)
    end
end

function NoThrowTransformChain(steps::Vector{<:ChainStep})
    length(steps) == 0 &&
        throw(ArgumentError("At least one step required to construct a chain"))
    chain = NoThrowTransformChain(first(steps))
    for step in steps[2:end]
        push!(chain, step)
    end
    return chain
end

function _field_map(specification::Type{<:NoThrowResult}; kwargs...)
    return _field_map(result_type(specification); kwargs...)
end

function _field_map(specification; recurse_into_legolas_schemas::Bool=false)
    m = map(zip(fieldnames(specification), fieldtypes(specification))) do (name, type)
        if recurse_into_legolas_schemas && type <: Legolas.AbstractRecord
            # TODO-future: do this recursively? For now, only one layer deep
            return _field_map(; recurse_into_legolas_schemas=false)
        end
        return name => type
    end
    return Dict(m)
end

Base.length(chain::NoThrowTransformChain) = length(chain.step_transforms)

function getstep(chain::NoThrowTransformChain, name::String)
    return ChainStep(name, chain.step_transforms[name], chain.step_input_constructors[name])
end

function getstep(chain::NoThrowTransformChain, step_index::Int)
    name = keys(chain.step_transforms)[step_index]
    return ChainStep(name, chain.step_transforms[name], chain.step_input_constructors[name])
end

#TODO-Future: consider making a constructor that special-cases when taking in
# a specification that has a single field (e.g., a Samples object or something)
# instead of doing this version that is geared at named tuple creation
function _validate_input_constructor(chain::NoThrowTransformChain, step_constructor)
    # Do all the fields required by the constructor exist in the preceding steps' output?
    mock_input = step_constructor(chain.io_mapping) # Will throw if any field doesn't exist

    # Does the constructor construct something that will probably work for the input schema?
    # No way to _really_ know without constructing it....but if the defined input is
    # a Legolas schema, then we could probably guess if we were going to fail horribly.
    # Going to save that for the future: assuming it will be caught at unit-test time
    # for now.
    # TODO-future: maybe take a stab at this, maybe don't!
    return nothing
end

function Base.push!(chain::NoThrowTransformChain, step::ChainStep)
    # Safety first!
    haskey(chain.step_transforms, step.name) &&
        throw(ArgumentError("Key `$(step.name)` already exists in chain!"))
    _validate_input_constructor(chain, step.input_constructor)

    # Forge it!
    push!(chain.step_transforms, step.name => step.transform_spec)
    push!(chain.step_input_constructors, step.name => step.input_constructor)
    push!(chain.io_mapping,
          step.name => _field_map(output_specification(step.transform_spec)))
    return chain
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
    component_results = OrderedDict{String,Legolas.AbstractRecord}()
    for (i_step, (name, step)) in enumerate(chain.step_transforms)
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
            input_nt = chain.step_input_constructors[name](component_results)

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
    str = "NoThrowTransformChain ($(input_specification(c)) => $(result_type(output_specification(c)))):\n"
    for (i, (k, v)) in enumerate(c.step_transforms)
        bullet = i == 1 ? "🌱" : (i == length(c.step_transforms) ? "🌷" : " ·") #"☀️ ")
        str *= "  $bullet  $k: $(input_specification(v)) => $(output_specification(v.transform_spec)): `$(v.transform_spec.transform_fn)`\n"
    end
    return print(io, chomp(str))
end
