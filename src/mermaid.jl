# The below is exceptionally experimental and likely to change!

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

function _mermaid_subgraph_from_chain_step(step::ChainStep)
    key = step.name
    process = step.transform_spec
    node_key = _mermaid_key(key)

    _schema_subgraph = (fieldmap::Dict, prefix) -> begin
        content = map(collect(keys(fieldmap))) do fieldname
            type = fieldmap[fieldname]
            node_name = _field_node_name(fieldname, prefix, node_key)
            return ["$(node_name){{\"$fieldname::$type\"}}",
                    "class $(node_name) classSpecField"]
        end
        return collect(Iterators.flatten(content))
    end

    inputs_subgraph = let
        prefix = "_InputSchema"
        contents = _schema_subgraph(construct_field_map(input_specification(process)),
                                    prefix)
        label = string("Input: ", input_specification(process))
        _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
    end
    outputs_subgraph = let
        prefix = "_OutputSchema"
        type = result_type(output_specification(process))
        label = string("Output: ", type)
        contents = _schema_subgraph(construct_field_map(type), prefix)
        _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
    end

    node_contents = reduce(vcat,
                           [inputs_subgraph, outputs_subgraph,
                            "$(node_key)_InputSchema:::classSpec -- $(process.transform_spec.transform_fn) --> $(node_key)_OutputSchema:::classSpec"])
    return _mermaid_subgraph(node_key, uppercasefirst(replace(string(key), "_" => " "));
                             contents=node_contents, direction="TB")
end

const DEFAULT_OUTER_STYLE = "fill:#cbd7e2,stroke:#000,stroke-width:0px;"
const DEFAULT_STEP_STYLE = "fill:#eeedff,stroke:#000,stroke-width:2px;"
const DEFAULT_SPEC_STYLE = "fill:#f8f7ff,stroke:#000,stroke-width:1px;"
const DEFAULT_SPEC_FIELD_STYLE = "fill:#fff,stroke:#000,stroke-width:1px;"

"""
    mermaidify(chain::NoThrowTransformChain; direction="TB")

Generate [mermaid plot](https://mermaid.js.org/) of `chain`, suitable for inclusion
in markdown documentation. For example usage, see [`NoThrowTransformChain`](@ref).
"""
function mermaidify(chain::NoThrowTransformChain; direction="LR",
                    style_step=DEFAULT_STEP_STYLE,
                    style_spec=DEFAULT_SPEC_STYLE, style_outer=DEFAULT_OUTER_STYLE,
                    style_spec_field=DEFAULT_SPEC_FIELD_STYLE)
    mermaid_lines = ["flowchart"]

    push!(mermaid_lines, "", "%% Define steps (nodes)")
    push!(mermaid_lines, """subgraph OUTERLEVEL["` `"]""", "direction $direction")
    for step in chain
        Base.append!(mermaid_lines, _mermaid_subgraph_from_chain_step(step))
    end

    push!(mermaid_lines, "", "%% Link steps (edges)")
    keys_upper = map(_mermaid_key, collect(keys(chain)))
    for i_key in 2:length(keys_upper)
        arrow = "-..->"
        push!(mermaid_lines,
              "$(keys_upper[i_key - 1]):::classStep $arrow $(keys_upper[i_key]):::classStep")
    end
    push!(mermaid_lines, "", "end", "OUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter")

    push!(mermaid_lines, "", "%% Styling definitions")
    for (name, style) in
        [("classOuter", style_outer), ("classStep", style_step), ("classSpec", style_spec),
         ("classSpecField", style_spec_field)]
        push!(mermaid_lines, "classDef $name $style")
    end
    return join(mermaid_lines, "\n")
end

#= Future features:
- link schemas to code implementation
- ditto transform functions
- add types to schema fields
- update formatting of different node types
- link specific i/o fields across steps (use https://mermaid.js.org/syntax/flowchart.html#styling-line-curves)
- highlight style of overall input/output schema
- support nested chains in chains in plotting
- add option to show docstrings for schemas and/or functions
- clean up themeing: https://mermaid.js.org/config/theming.html
=#
