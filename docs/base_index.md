# TransformSpecifications.jl

This package enables structured transform elements via defined I/O specifications.
- For the abstract interface, see [`AbstractTransformSpecification`](@ref)
- For a basic concrete transform, see [`TransformSpecification`](@ref)
- For transforms that catch exceptions and return them as formatted violations, see [`NoThrowTransform`](@ref) (and [`NoThrowResult`](@ref)).
- For a compound transform that is itself a concrete `AbstractTransformSpecification` and is constructed from a DAG of `AbstractTransformSpecification`s, see [`NoThrowDAG`](@ref)
    - For a plotted graph visualization of such a DAG, see [Plotting `NoThrowDAG`s](@ref).


## Table of contents

```@contents
Pages = ["index.md", "api.md"]
Depth = 3
```

## `AbstractTransformSpecification`
```@autodocs
Modules = [TransformSpecifications]
Pages = ["abstract.jl"]
Private = false
```

## `TransformSpecification`
```@autodocs
Modules = [TransformSpecifications]
Pages = ["transform.jl"]
Private = false
```

## `NoThrowTransform`
```@autodocs
Modules = [TransformSpecifications]
Pages = ["nothrow.jl"]
Private = false
```

## `NoThrowDAG`
```@autodocs
Modules = [TransformSpecifications]
Pages = ["nothrow_dag.jl"]
Private = false
```
Here is the mermaid plot generated for the example DAG in [`NoThrowDAG`](@ref):

## Plotting `NoThrowDAG`s

MERMAID_RAW__TO_BE_REPLACED_VIA_MAKE_JL

```@autodocs
Modules = [TransformSpecifications]
Pages = ["mermaid.jl"]
Private = false
```




