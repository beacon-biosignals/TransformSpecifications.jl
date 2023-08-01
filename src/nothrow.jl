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
    NoThrowTransform{TransformSpecification{T<:Type,U<:Type}} <: AbstractTransformSpecification

Basic component that wraps a [`TransformSpecification`](@ref) `ts`, returning
a [`NoThrowResult`](@ref) of type `NoThrowResult{output_specification(ts)}` if
`transform!(ts, input)` succeeds and `NoThrowResult{Missing}` if `transform!` throws
an error.

## Fields

- `transform_specification::TransformSpecification{T<:Type,U<:Type}`

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
struct NoThrowTransform{T,U} <: AbstractTransformSpecification
    transform_specification::TransformSpecification{T,U}
end

NoThrowTransform(args...) = NoThrowTransform(TransformSpecification(args...))
NoThrowTransform(; kwargs...) = NoThrowTransform(TransformSpecification(; kwargs...))

function input_specification(ntt::NoThrowTransform)
    return input_specification(ntt.transform_specification)
end

function output_specification(ntt::NoThrowTransform)
    return NoThrowResult{output_specification(ntt.transform_specification)}
end

"""
    transform!(ntt::NoThrowTransform, input)

Return [`NoThrowResult`](@ref) of applying `ntt.transform_specification.transform_fn` to `input`. Transform
will fail (i.e., return a `NoThrowResult{Missing}` if:
* `input` does not conform to `input_specification(ntt)`, i.e.,
    `interpret_input(input_specification(ntt), input)` throws an error
* `ntt.transform_specification.transform_fn` returns a `NoThrowResult{Missing}` when applied to the interpreted input,
* `ntt.transform_specification.transform_fn` errors when applied to the interpreted input, or
* the output generated by `ntt.transform_specification.transform_fn` is not a `Union{NoThrowResult{Missing},output_specification(ntt)}`

In any of these failure cases, this function will not throw, but instead will return
the cause of failure in the output `violations` field.

See also: [`interpret_input`](@ref)
"""
function transform!(ntt::NoThrowTransform, input)
    # Check that input meets specification
    InSpec = input_specification(ntt)
    _input = try
        interpret_input(InSpec, input)
    catch e
        return NoThrowResult(;
                             violations="Input doesn't conform to specification `$(InSpec)`. Details: " *
                                        string(e))
    end

    # Do transformation
    result = try
        NoThrowResult(ntt.transform_specification.transform_fn(_input))
    catch e
        return NoThrowResult(; violations="Unexpected violation: " * string(e))
    end

    # ...wrap it in a nothrow, so that any nested nothrows are correctly collapsed
    # before output specification checking happens.
    ntt_result = NoThrowResult(result)

    # Check that output meets specification
    OutSpec = output_specification(ntt)
    if ntt_result isa Union{OutSpec,NoThrowResult{Missing}}
        return ntt_result::Union{OutSpec,NoThrowResult{Missing}}
    end
    return NoThrowResult(;
                         violations="Output doesn't conform to specification `$(OutSpec)`; is instead a `$(typeof(ntt_result))`")::NoThrowResult{Missing}
end

function Base.show(io::IO, p::NoThrowTransform)
    return print(io,
                 "NoThrowTransform{$(input_specification(p)),$(output_specification(p.transform_specification))}: `$(p.transform_specification.transform_fn)`")
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
    if input_specification(ntt) != output_specification(ntt.transform_specification)
        @debug "Input and output schemas are not identical: $ntt"
        return false
    end
    is_identity = isequal(ntt.transform_specification.transform_fn,
                          identity_no_throw_result)
    if !is_identity
        @debug "`transform_fn` (`$(ntt.transform_specification.transform_fn)`) is not `identity_no_throw_result`"
    end
    return is_identity
end
