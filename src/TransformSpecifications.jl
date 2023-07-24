"""
    TransformSpecifications

This package enables structured transform elements via defined I/O specifications.
"""
module TransformSpecifications

using Legolas
using Legolas: @schema, @version
using OrderedCollections

include("abstract.jl")
export AbstractTransformSpecification, transform!, input_specification,
       output_specification

include("nothrow_transforms.jl")
export NoThrowResult, nothrow_succeeded, NoThrowTransform, TransformSpecificationChain,
       identity_no_throw_transform, is_identity_no_throw_transform,
       AbstractProcessChainStep

end
