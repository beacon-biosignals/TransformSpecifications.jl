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

```jldoctest test1
using Legolas: @schema, @version
@schema "example" ExampleSchema
@version ExampleSchemaV1 begin
    name::String
end

NoThrowResult(ExampleSchemaV1(; name="yeehaw"))

# output
NoThrowResult{ExampleSchemaV1}: Transform succeeded
  ✅ result: ExampleSchemaV1:
 :name  "yeehaw"
```
```jldoctest test1
NoThrowResult(ExampleSchemaV1(; name="huzzah"); warnings="Hark, watch your step...")

# output
NoThrowResult{ExampleSchemaV1}: Transform succeeded
  ⚠️  Hark, watch your step...
  ✅ result: ExampleSchemaV1:
 :name  "huzzah"
```
```jldoctest test1
NoThrowResult(; violations=["Epic fail!", "Slightly less epic fail!"],
                     warnings=["Uh oh..."])

# output
NoThrowResult{Missing}: Transform failed
  ❌ Epic fail!
  ❌ Slightly less epic fail!
  ⚠️  Uh oh...
```
"""
struct NoThrowResult{T}
    result::T
    violations::Vector{String}
    warnings::Vector{String}

    function NoThrowResult(result::T, violations::Union{String,Vector{String}},
                           warnings::Union{String,Vector{String}}) where {T}
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
        return new{T}(result, violations, warnings)
    end
end

function NoThrowResult(; result=missing, violations=String[], warnings=String[])
    return NoThrowResult(result, violations, warnings)
end

function NoThrowResult(result; violations=String[], warnings=String[])
    return NoThrowResult(result, violations, warnings)
end

function NoThrowResult(result::NoThrowResult, violations::Union{String,Vector{String}},
                       warnings::Union{String,Vector{String}})
    warnings = vcat(result.warnings, warnings)
    violations = vcat(result.violations, violations)
    return NoThrowResult(result.result, violations, warnings)
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

```jldoctest test2
using Legolas: @schema, @version

@schema "example-in" ExampleInSchema
@version ExampleInSchemaV1 begin
    in_name::String
end

@schema "example-out" ExampleOutSchema
@version ExampleOutSchemaV1 begin
    out_name::String
end

function apply_example(in_record)
    out_name = in_record.in_name * " earthling"
    return NoThrowResult(ExampleOutSchemaV1(; out_name))
end
p = NoThrowTransform(ExampleInSchemaV1, ExampleOutSchemaV1, apply_example)

# output
NoThrowTransform{ExampleInSchemaV1,ExampleOutSchemaV1}: `apply_example`
```
```jldoctest test2
transform!(p, ExampleInSchemaV1(; in_name="greetings"))

# output
NoThrowResult{ExampleOutSchemaV1}: Transform succeeded
  ✅ result: ExampleOutSchemaV1:
 :out_name  "greetings earthling"
```
```jldoctest test2
force_failure_example(in_record) = NoThrowResult(; violations=["womp", "womp"])
p = NoThrowTransform(ExampleInSchemaV1, ExampleOutSchemaV1, force_failure_example)

# output
NoThrowTransform{ExampleInSchemaV1,ExampleOutSchemaV1}: `force_failure_example`
```
```jldoctest test2
transform!(p, ExampleInSchemaV1(; in_name="greetings"))

# output
NoThrowResult{Missing}: Transform failed
  ❌ womp
  ❌ womp
```
"""
Base.@kwdef struct NoThrowTransform{T<:Type,U<:Type} <: AbstractTransformSpecification
    input_specification::T
    output_specification::U
    transform_fn
end

input_specification(ntt::NoThrowTransform) = ntt.input_specification

function output_specification(ntt::NoThrowTransform)
    return NoThrowResult{ntt.output_specification}
end

#TODO-future: could upstream a version of `Base.convert(spec::Type{<:Legolas.AbstractRecord}, input)` and use convert in place of this new function
interpret_input(::Type{T}, input::T) where {T} = input
interpret_input(::Type{T}, input::T) where {T<:Legolas.AbstractRecord} = input
interpret_input(spec::Type{<:Legolas.AbstractRecord}, input) = (spec)(input)
interpret_input(spec, input) = convert(spec, input)

"""
    transform!(ntt::NoThrowTransform, input)

Return [`NoThrowResult`](@ref) of applying `ntt.transform_fn` to `input`. If `input`
does not conform to `input_specification(ntt)` or `ntt.transform_fn` fails, will
return `NoThrowResult{Missing}` with the cause of failure noted in the `violations`.
"""
function transform!(ntt::NoThrowTransform, input)
    _input = try
        spec = input_specification(ntt)
        interpret_input(spec, input)
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
