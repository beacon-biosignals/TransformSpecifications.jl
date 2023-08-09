# TransformSpecifications.jl

This package enables structured transform elements via defined I/O specifications.
- For the abstract interface, see [`AbstractTransformSpecification`](@ref)
- For a basic concrete transform, see [`TransformSpecification`](@ref)
- For transforms that catch exceptions and return them as formatted violations, see [`NoThrowTransform`](@ref) (and [`NoThrowResult`](@ref)).
- For a compound transform that is itself a concrete `AbstractTransformSpecification` and also is constructed from a chain of `AbstractTransformSpecification`s, see [`NoThrowTransformChain`](@ref)
    - For a plotted graph visualization of such a transform chain, see [Plotting `NoThrowTransformChain`s](@ref).


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

## `NoThrowTransformChain`
```@autodocs
Modules = [TransformSpecifications]
Pages = ["nothrow_chain.jl"]
Private = false
```
Here is the mermaid plot generated for the example chain in [`NoThrowTransformChain`](@ref):

## Plotting `NoThrowTransformChain`s

MERMAID_RAW__TO_BE_REPLACED_VIA_MAKE_JL

```@autodocs
Modules = [TransformSpecifications]
Pages = ["mermaid.jl"]
Private = false
```




