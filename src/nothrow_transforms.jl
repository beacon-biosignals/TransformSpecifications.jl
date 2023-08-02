"""
    NoThrowResult{T}(result::T, violations::Union{String,Vector{String}},
                     warnings::Union{String,Vector{String}}) where {T}
    NoThrowResult(result; violations=String[], warnings=String[])
    NoThrowResult(; result=missing, violations=String[], warnings=String[])

Type that specifies the result of a transformation, indicating successful
application of a transform through presence (or lack thereof) of `violations `.
Consists of either a non-`missing` `result` (success state) or non-empty `violations`
and type `Missing` (failure state).

Note that constructing a `NoThrowTransform` from an input `result` of type `NoThrowTransform`,
e.g., `NoThrowTransform(::NoThrowTransform{T}, ...), collapses down to a single `NoThrowResult{T}`;
any inner and outer warnings and violations fields are concatenated and returned in
the resultant `NoThrowResult{T}`.

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
        return new{T}(result, _to_vec(violations), _to_vec(warnings))
    end
end

_to_vec(x::AbstractString) = [x]
_to_vec(x) = x

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
    transform_fn::Any
end

input_specification(ntt::NoThrowTransform) = ntt.input_specification

function output_specification(ntt::NoThrowTransform)
    return NoThrowResult{ntt.output_specification}
end

"""
    interpret_input(::Type{T}, input::T) where {T}
    interpret_input(::Type{T}, input::T) where {T<:Legolas.AbstractRecord}
    interpret_input(spec::Type{<:Legolas.AbstractRecord}, input)
    interpret_input(spec, input)

Return `input` interpreted as type `T`: is same as `identity` function if `input`
is already of type `T`; otherwise, attempts to construct or `Base.convert`s the
the output type from the input. Will throw if conversion fails or is otherwise
undefined.

See also: [`transform!`](@ref)
"""
interpret_input(::Type{T}, input::T) where {T} = input
# Required due to method ambiguity
interpret_input(::Type{T}, input::T) where {T<:Legolas.AbstractRecord} = input
interpret_input(spec::Type{<:Legolas.AbstractRecord}, input) = (spec)(input)
interpret_input(spec, input) = convert(spec, input)

"""
    transform!(ntt::NoThrowTransform, input)

Return [`NoThrowResult`](@ref) of applying `ntt.transform_fn` to `input`. Transform
will fail (i.e., return a `NoThrowResult{Missing}` if:
* `input` does not conform to `input_specification(ntt)`, i.e.,
    `interpret_input(input_specification(ntt), input)` throws an error
* `ntt.transform_fn` returns a `NoThrowResult{Missing}` when applied to the interpreted input,
* `ntt.transform_fn` errors when applied to the interpreted input, or
* the output generated by `ntt.transform_fn` is not a `Union{NoThrowResult{Missing},output_specification(ntt)}`

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
        violations = "Input doesn't conform to specification `$(InSpec)`. Details: $e"
        return NoThrowResult(; violations)
    end

    # Do transformation
    result = try
        NoThrowResult(ntt.transform_fn(_input))
    catch e
        violations = "Unexpected transform violation for $(input_specification(ntt)). Details: $e"
        return NoThrowResult(; violations)
    end

    # ...wrap it in a nothrow, so that any nested nothrows are correctly collapsed
    # before output specification checking happens.
    ntt_result = NoThrowResult(result)

    # Check that output meets specification
    OutSpec = output_specification(ntt)
    if ntt_result isa Union{OutSpec,NoThrowResult{Missing}}
        return ntt_result::Union{OutSpec,NoThrowResult{Missing}}
    end
    violations = "Output doesn't conform to specification `$(OutSpec)`; is instead a `$(typeof(ntt_result))`"
    return NoThrowResult(; warnings=ntt_result.warnings, violations)::NoThrowResult{Missing}
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
    T in [AbstractTransformSpecification, NoThrowResult, NoThrowTransform]

    @eval function Base.$pred(x::$T, y::$T)
        return all(p -> $pred(getproperty(x, p), getproperty(y, p)), fieldnames($T))
    end
end

function Base.:(==)(x::NoThrowResult{Missing}, y::NoThrowResult{Missing})
    return x.warnings == y.warnings && x.violations == y.violations
end
