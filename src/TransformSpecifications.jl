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
       transform_force_throw!, transform_force_throw

include("nothrow_dag.jl")
export NoThrowDAG, DAGStep, get_step, input_assembler

include("mermaid.jl")
export mermaidify

#####
##### Base extensions
#####

for pred in (:(==), :(isequal)),
    T in [AbstractTransformSpecification, TransformSpecification, NoThrowResult,
          NoThrowTransform, NoThrowDAG, DAGStep]

    @eval function Base.$pred(x::$T, y::$T)
        return all(f -> $pred(getproperty(x, f), getproperty(y, f)), fieldnames($T))
    end
end

function Base.:(==)(x::NoThrowResult{Missing}, y::NoThrowResult{Missing})
    return x.warnings == y.warnings && x.violations == y.violations
end

end
