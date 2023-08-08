"""
    TransformSpecification{T<:Type,U<:Type} <: AbstractTransformSpecification

Basic component that specifies a transform that, when applied to input of type `T`,
will return output of type `U`.

See also: [`TransformSpecification`](@ref)

## Fields

- `input_specification::T`
- `output_specification::U`
- `transform_fn::Function` Function with signature `transform_fn(::input_specification) -> output_specification`

## Example

```jldoctest transform_ex1
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
    return ExampleOutSchemaV1(; out_name)
end
p = TransformSpecification(ExampleInSchemaV1, ExampleOutSchemaV1, apply_example)

# output
TransformSpecification{ExampleInSchemaV1,ExampleOutSchemaV1}: `apply_example`
```
```jldoctest transform_ex1
transform!(p, ExampleInSchemaV1(; in_name="greetings"))

# output
ExampleOutSchemaV1: (out_name = "greetings earthling",)
```
"""
Base.@kwdef struct TransformSpecification{T<:Type,U<:Type} <: AbstractTransformSpecification
    input_specification::T
    output_specification::U
    transform_fn::Any
end

input_specification(ts::TransformSpecification) = ts.input_specification

output_specification(ts::TransformSpecification) = ts.output_specification

"""
    convert_spec(::Type{T}, input::T) where {T}
    convert_spec(::Type{T}, input::T) where {T<:Legolas.AbstractRecord}
    convert_spec(spec::Type{<:Legolas.AbstractRecord}, input)
    convert_spec(spec, input)

Return `input` interpreted as type `T`: is same as `identity` function if `input`
is already of type `T`; otherwise, attempts to construct or `Base.convert`s the
the output type from the input. Will throw if conversion fails or is otherwise
undefined.

See also: [`transform!`](@ref)
"""
convert_spec(::Type{T}, input::T) where {T} = input
# Required due to method ambiguity
convert_spec(::Type{T}, input::T) where {T<:Legolas.AbstractRecord} = input
convert_spec(spec::Type{<:Legolas.AbstractRecord}, input) = (spec)(input)
convert_spec(spec, input) = convert(spec, input)

"""
    transform!(ts::TransformSpecification, input)

Return `output_specification(ts)` by applying `ts.transform_fn` to `input`.
May error if:
* `input` does not conform to `input_specification(ts)`, i.e.,
    `convert_spec(input_specification(ts), input)` errors
* `ts.transform_fn` errors when applied to the interpreted input, or
* the output generated by `ts.transform_fn` is not a `output_specification(ts)`

For a non-erroring alternative, see [`NoThrowTransform`](@ref).

See also: [`convert_spec`](@ref)
"""
function transform!(ts::TransformSpecification, input)
    # Check that input meets specification
    InSpec = input_specification(ts)
    input = try
        convert_spec(InSpec, input)
    catch e
        rethrow(ArgumentError("Input doesn't conform to specification `$(InSpec)`"))
    end

    # Do transformation
    result = ts.transform_fn(input)

    # Check that output meets specification
    OutSpec = output_specification(ts)
    if !(result isa OutSpec)
        throw(ErrorException("Output doesn't conform to specification `$(OutSpec)`; is instead a `$(typeof(result))`"))
    end
    return result::OutSpec
end

function Base.show(io::IO, p::TransformSpecification)
    return print(io,
                 "TransformSpecification{$(p.input_specification),$(p.output_specification)}: `$(p.transform_fn)`")
end
