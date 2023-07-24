"""
    TransformSpecifications

This package enables structured processing elements via [Legolas](https://github.com/beacon-biosignals/Legolas.jl)-defined
I/O schemas.
"""
module TransformSpecifications

using Legolas
using Legolas: @schema, @version
using OrderedCollections

include("processes.jl")
export AbstractTransformSpecification, apply!, input_schema, output_schema,
       TransformSpecificationResult, TransformSpecification, TransformSpecificationChain,
       process_succeeded, identity_legolas_process, is_identity_process,
       AbstractProcessChainStep

end
