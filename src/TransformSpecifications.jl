"""
    TransformSpecifications

This package enables structured transform elements via defined I/O specifications.
"""
module TransformSpecifications

using Legolas
using Legolas: @schema, @version
using OrderedCollections

include("abstract.jl")
export AbstractTransformSpecification, input_specification, output_specification, transform!

include("nothrow_transforms.jl")
export NoThrowResult, NoThrowTransform, nothrow_succeeded, NoThrowTransformChain,
ChainStepType, identity_no_throw_transform, is_identity_no_throw_transform

end
