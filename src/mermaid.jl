#=
This file is exceptionally experimental and likely to change!

Future features:
- link schemas to code implementation
- ditto transform functions
- add types to schema fields
- update formatting of different node types
- link specific i/o fields across steps (use https://mermaid.js.org/syntax/flowchart.html#styling-line-curves)
- highlight style of overall input/output schema
- support nested dags in dags in plotting
- add option to show docstrings for schemas and/or functions
- clean up themeing: https://mermaid.js.org/config/theming.html
=#

"""
    mermaidify(dag::NoThrowDAG; direction="LR",
               style_step="fill:#eeedff,stroke:#000,stroke-width:2px;",
               style_spec="fill:#f8f7ff,stroke:#000,stroke-width:1px;",
               style_outer="fill:#cbd7e2,stroke:#000,stroke-width:0px;",
               style_spec_field="fill:#fff,stroke:#000,stroke-width:1px;")

Generate [mermaid plot](https://mermaid.js.org/) of `dag`, suitable for inclusion
in markdown documentation.

Args:
* `direction`: option that specifies the orientation/flow of the dag's steps;
    most useful options for dag plotting are `LR` (left to right) or `TB` (top to bottom);
    see the mermaid documentation for full list of options.
* `style_step`: styling of the box containing an individual dag step (node)
* `style_spec`: styling of the boxes containing the input and output specifications for each step
* `style_outer`: styling of the box bounding the entire DAG
* `style_spec_field`: styling of the boxes bounding each specification's individual field(s)

For each style kwarg, see the mermaid documentation for style string options.

To include in markdown, do
````markdown
```mermaid
{{mermaidify output}}
```
````
or for html (i.e., for Documenter.jl), do
````markdown
<div class=\"mermaid\">
{{mermaidify output}}
</div>
````
For an example of the raw output, see [`NoThrowDAG`](@ref); for an example
of the rendered output, see [the built documentation](https://beacon-biosignals.github.io/TransformSpecifications.jl/dev).
"""
function mermaidify(dag::NoThrowDAG; direction="LR",
                    style_step="fill:#eeedff,stroke:#000,stroke-width:2px;",
                    style_spec="fill:#f8f7ff,stroke:#000,stroke-width:1px;",
                    style_outer="fill:#cbd7e2,stroke:#000,stroke-width:0px;",
                    style_spec_field="fill:#fff,stroke:#000,stroke-width:1px;")
    mermaid_lines = ["flowchart"]

    # Add a box for each node (step) in the dag; the box contains descriptions of the input specification,
    # output specification, and applied transformation function
    push!(mermaid_lines, "", "%% Define steps (nodes)")
    push!(mermaid_lines, """subgraph OUTERLEVEL["` `"]""", "direction $direction")
    for step in dag
        Base.append!(mermaid_lines, _mermaid_subgraph_from_dag_step(step))
    end

    # Draw a connecting edge between each step in the dag
    push!(mermaid_lines, "", "%% Link steps (edges)")
    keys_upper = map(_mermaid_key, collect(keys(dag)))
    for i_key in 2:length(keys_upper)
        arrow = "-..->"
        push!(mermaid_lines,
              "$(keys_upper[i_key - 1]):::classStep $arrow $(keys_upper[i_key]):::classStep")
    end

    # This additional edge is hidden ("~~~") but requried for the outer level to
    # be drawn in the desired orientation (it could potentially be dropped in the future,
    # as long as the plot shows up okay without it! Was added via trial and error...)
    push!(mermaid_lines, "", "end", "OUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter")

    # Define the styles applied to the assorted node boxes
    push!(mermaid_lines, "", "%% Styling definitions")
    for (name, style) in
        [("classOuter", style_outer), ("classStep", style_step), ("classSpec", style_spec),
         ("classSpecField", style_spec_field)]
        push!(mermaid_lines, "classDef $name $style")
    end
    return join(mermaid_lines, "\n")
end

_ltab_spaces(str; n::Int=2) = repeat(" ", n) * str
_mermaid_key(key) = uppercase(string(key))
_field_node_name(field, prefix, step_key) = string(_mermaid_key(step_key), prefix, field)

function _mermaid_subgraph(node_key::String, display_name::String=node_key;
                           contents::Vector{String}=String[], direction="RL")
    return ["subgraph $(node_key)[$(display_name)]",
            "  direction $direction",
            map(_ltab_spaces, contents)...,
            "end"]
end

function _mermaid_subgraph_from_dag_step(step::DAGStep)
    key = step.name
    process = step.transform_spec
    node_key = _mermaid_key(key)

    # Helper function that adds a "specification" box (graph node), which lists the internal
    # fields of the specification
    _schema_subgraph = (fieldmap::Dict, prefix) -> begin
        # @info "okay"
        content = map(collect(keys(fieldmap))) do fieldname
            type = fieldmap[fieldname]
            node_name = _field_node_name(fieldname, prefix, node_key)
            node_contents = if type isa Dict{Symbol,Type}
                # Special-case where we're replacing a dict that has been generated
                # from a different type:
                fieldstr = replace(string(type), "Dict{Symbol, Type}(:" => "", ")" => "",
                                   " => " => "::",
                                   ", :" => ",\n  ")
                "$(node_name){{\"$fieldname:\n  $fieldstr\"}}"
            else
                "$(node_name){{\"$fieldname::$type\"}}"
            end
            return [node_contents,
                    "class $(node_name) classSpecField"]
        end
        # @info content
        return collect(Iterators.flatten(content))
    end

    # Add a specification box for input spec...
    inputs_subgraph = let
        prefix = "_InputSchema"
        contents = _schema_subgraph(field_dict(input_specification(process)), prefix)
        label = string("Input: ", input_specification(process))
        _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
    end

    if is_identity_no_throw_transform(step.transform_spec)
        contents = reduce(vcat,
                          [inputs_subgraph, "class $(node_key)_InputSchema classSpec"])
    else
        # ...and output spec...
        outputs_subgraph = let
            prefix = "_OutputSchema"
            type = result_type(output_specification(process))
            label = string("Output: ", type)
            contents = _schema_subgraph(field_dict(type), prefix)
            _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
        end

        # ...and add an arrow (edge) between them, that is labeled with the dag step's transform function
        contents = reduce(vcat,
                          [inputs_subgraph, outputs_subgraph,
                           "$(node_key)_InputSchema:::classSpec -- $(process.transform_spec.transform_fn) --> $(node_key)_OutputSchema:::classSpec"])
    end
    return _mermaid_subgraph(node_key, uppercasefirst(replace(string(key), "_" => " "));
                             contents, direction="TB")
end
