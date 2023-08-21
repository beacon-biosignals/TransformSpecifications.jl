# TransformSpecifications.jl

This package enables structured transform elements via defined I/O specifications.
- For the abstract interface, see [TransformSpecifications interface](@ref)
- For a basic concrete transform, see [`TransformSpecification`](@ref)
- For transforms that catch exceptions and return them as formatted violations, see [`NoThrowTransform`](@ref) (and [`NoThrowResult`](@ref)).
- For a compound transform that is itself a concrete `AbstractTransformSpecification` and is constructed from a DAG of `AbstractTransformSpecification`s, see [`NoThrowDAG`](@ref)
    - For a plotted graph visualization of such a DAG, see [Plotting `NoThrowDAG`s](@ref).


## Table of contents

```@contents
Pages = ["index.md", "api.md"]
Depth = 3
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

## TransformSpecifications interface

TransformSpecifications provides a general interface which allows the creation of new subtypes of `AbstractTransformSpecification`
that can be used to implement transformation.

New transformation types *must* subtype `AbstractTransformSpecification`, and implement the following required methods.

### Required interface type
```@docs
TransformSpecifications.AbstractTransformSpecification
```

### Required interface methods

```@docs
TransformSpecifications.transform!
TransformSpecifications.input_specification
TransformSpecifications.output_specification
```

### Other interface methods

These methods have reasonable fallback definitions and should only be defined for new types if there is some reason
to prefer a custom implementation over the default fallback.

```@docs
TransformSpecifications.transform
```
