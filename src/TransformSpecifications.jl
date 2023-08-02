"""
    TransformSpecifications

This package enables structured transform elements via defined I/O specifications.
"""
module TransformSpecifications

using Legolas
using Legolas: @schema, @version
using OrderedCollections

include("abstract.jl")
export AbstractTransformSpecification, input_specification, output_specification,
       transform!, transform

include("transform.jl")
export TransformSpecification

include("nothrow.jl")
export NoThrowResult, NoThrowTransform, nothrow_succeeded, is_identity_no_throw_transform,
       transform_unwrapped!, transform_unwrapped

include("nothrow_chain.jl")
export NoThrowTransformChain, ChainStep

#####
##### Base extensions
#####

for pred in (:(==), :(isequal)),
    T in [AbstractTransformSpecification, TransformSpecification, NoThrowResult,
          NoThrowTransform, NoThrowTransformChain, ChainStep]

    @eval function Base.$pred(x::$T, y::$T)
        return all(p -> $pred(getproperty(x, p), getproperty(y, p)), fieldnames($T))
    end
end

function Base.:(==)(x::NoThrowResult{Missing}, y::NoThrowResult{Missing})
    return x.warnings == y.warnings && x.violations == y.violations
end

end
