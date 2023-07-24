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

include("nothrow.jl")
export NoThrowResult, nothrow_succeeded

include("nothrow_legolas.jl")
export NoThrowLegolasTransform, TransformSpecificationChain,
       identity_legolas_process, is_identity_process,
       AbstractProcessChainStep

end
