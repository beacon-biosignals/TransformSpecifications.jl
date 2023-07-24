"""
    NoThrowResult{T}(; warnings::Union{String,Vector{String}}=String[],
                     violations::Union{String,Vector{String}}=String[],
                     result::T)
    NoThrowResult(result::T; kwargs...)

Type that specifies the result of a transformation that indicates success of a
process through presence (or lack thereof) of `violations`.

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
NoThrowResult{ExampleSchemaV1}: succeeded
  ✅ result: ExampleSchemaV1:
 :name  "yeehaw"

julia> NoThrowResult(ExampleSchemaV1(; name="huzzah");
                     warnings="Hark, watch your step...")
NoThrowResult{ExampleSchemaV1}: Process succeeded
  ⚠️  Hark, watch your step...
  ☑️  result: ExampleSchemaV1:
 :name  "huzzah"

julia> NoThrowResult(; violations=["Epic fail!", "Slightly less epic fail!"],
                     warnings=["Uh oh..."])
NoThrowResult{Missing}: failed
  ❗ Epic fail!
  ❗ Slightly less epic fail!
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

"""
    nothrow_succeeded(result::NoThrowResult) -> Bool

Return `true` if `result` indicates successful completion, i.e. if `result.violations`
is empty.

See also: [`NoThrowResult`](@ref)
"""
nothrow_succeeded(::NoThrowResult{Missing}) = false
nothrow_succeeded(::NoThrowResult) = true

function Base.show(io::IO, r::NoThrowResult)
    succeeded = nothrow_succeeded(r)
    str = "$(typeof(r)): Process $(succeeded ? "succeeded" : "failed")\n"
    for v in r.violations
        str *= "  ❗ $v\n"
    end
    for w in r.warnings
        str *= "  ⚠️  $w\n"
    end
    bullet = ismissing(r.result) ? "❌" : "✅"
    str *= "  $bullet result: $(r.result)"
    return print(io, str)
end
