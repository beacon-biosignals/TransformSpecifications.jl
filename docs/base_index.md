# TransformSpecifications.jl

Enabling structured transformations via defined I/O specifications.

## Introduction & Overview

This package provides tools to help define pipelines that are composed of individual explicitly-defined components.
These pipelines are in the form of [directed acyclic graphs (DAGs)](https://en.wikipedia.org/wiki/Directed_acyclic_graph),
where each node of the graph is a component, and the edges correspond to data transfers between the components.
The graph is "directed" since data flows in one direction (from the outputs of a component to the inputs of another),
and "acyclic" since cycles are not allowed; one component cannot supply data to another which then supplies data back
to the original component.

Later in the documentation, we will get into a lot more details about the tools that this package provides. But first,
let us look at the high-level steps one follows to define such a pipeline using this package.

1. Define the inputs and outputs of each step. While this is commonly implemented via [Legolas.jl](https://github.com/beacon-biosignals/Legolas.jl) schemas, TransformSpecifications itself does not require this. This generally does not use any code from TransformSpecifications and is a pre-requisite to using TransformSpecifications.
2. Define functions that takes each set inputs to the corresponding outputs. For the purposes of setting up the pipeline, these can be placeholder functions that don't actually do anything, but once you want to run the pipeline, these will need to do whatever work is required in order to generate the outputs from the inputs. Again, this step is independent of any code in TransformSpecifications.jl itself.
3. Package up steps (1) and (2) into [`AbstractTransformSpecification`](@ref)s, like [`TransformSpecification`](@ref) and [`NoThrowTransform`](@ref). These are the "components", the nodes of the graph.
4. Create [`input_assembler`](@ref)'s for each component take route necessary outputs of previous components into the inputs of the component. This creates the edges of the graph.
5. Create a DAG using [`DAGStep`](@ref) or [`NoThrowDAG`](@ref) to assemble all of the components and assemblers into a DAG.
6. Use it! Apply the DAG to inputs using [`transform!`](@ref) or [`transform`](@ref), and create a mermaid diagram using [`mermaidify`](@ref).

With these general steps in mind, it can help to see some examples.

- For example of all of these steps together, see [`NoThrowDAG`](@ref).
- For a basic concrete transform, see [`TransformSpecification`](@ref)
- For transforms that catch exceptions and return them as formatted violations, see [`NoThrowTransform`](@ref) (and [`NoThrowResult`](@ref)).
- For the abstract interface, see [TransformSpecifications interface](@ref)
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
