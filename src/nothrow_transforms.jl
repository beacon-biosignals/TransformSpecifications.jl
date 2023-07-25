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
    _input = try
        # TODO-future: pull this out into a `interpret_input` function
        input_specification(ntt)(input)
    catch e
        # rethrow(e)
        return NoThrowResult(;
                             violations="Input doesn't conform to expected specification for $(input_specification(ntt)). Details: " *
                                        string(e))
    end
    try
        return ntt.transform_fn(_input)
    catch e
        # rethrow(e)
        return NoThrowResult(;
                             violations="Unexpected transform violation for $(input_specification(ntt)). Details: " *
                                        string(e))
    end
end

function Base.show(io::IO, p::NoThrowTransform)
    return print(io,
                 "NoThrowTransform{$(p.input_specification),$(p.output_specification)}: `$(p.transform_fn)`")
end

"""
    identity_no_throw_transform(specification) -> NoThrowTransform{specification}

Create [`NoThrowTransform`](@ref) where `input_specification==output_specification==specification` and `transform_fn`
result is a `NoThrowResult{specification}`.

See also: [`is_identity_no_throw_transform`](@ref)
"""
function identity_no_throw_transform(specification)
    return NoThrowTransform(specification, specification, identity_no_throw_result)
end

"""
    identity_no_throw_result(result) -> NoThrowResult

Return `NoThrowResult{T}` where `T=typeof(result)`
"""
identity_no_throw_result(result) = NoThrowResult(result)

"""
    is_identity_no_throw_transform(ntt::NoThrowTransform) -> Bool

Check if `ntt` meets the definition of an [`identity_no_throw_transform`](@ref).
"""
function is_identity_no_throw_transform(ntt::NoThrowTransform)
    if ntt.input_specification != ntt.output_specification
        @debug "Input and output schemas are not identical: $ntt"
        return false
    end
    is_identity = isequal(ntt.transform_fn, identity_no_throw_result)
    if !is_identity
        @debug "`transform_fn` (`$(ntt.transform_fn)`) is not `identity_no_throw_result`"
    end
    return is_identity
end

#####
##### Shared utilities
#####

for pred in (:(==), :(isequal)),
    T in
    [AbstractTransformSpecification, NoThrowResult, NoThrowTransform]

    @eval function Base.$pred(x::$T, y::$T)
        return all(p -> $pred(getproperty(x, p), getproperty(y, p)), fieldnames($T))
    end
end
# TODO-help: do we need a hash function for these as well?
