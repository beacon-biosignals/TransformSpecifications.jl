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

## Design philosophy

This package was constructed to codify some implementation patterns we used when generating similar pipelines "manually". These initial rules were as follows:
- Single entrypoint function (e.g. `run_<algname>`) simply calls the component entrypoints in order
- Each "component" has it's own file; that component's entrypoint function is the first function in the file
- If a component's main function has more than 1 item returned, return it as a NamedTuple
- Do not unpack a component's return value it into the namespace; simply do `nt.key` to extract values for input into downstream components as needed.

For one specific use-case, we also did the following, although this is a very case-specific decision:
- No component is allowed to  modifies another's output (no mutating OR rebinding the variable name)


## Types

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




