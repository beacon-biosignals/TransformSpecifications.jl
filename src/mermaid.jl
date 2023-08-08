# The below is exceptionally experimental and likely to change

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
                            "$(node_key)_InputSchema:::classSpec == $(process.transform_spec.transform_fn) ==> $(node_key)_OutputSchema:::classSpec"])
    return _mermaid_subgraph(node_key, uppercasefirst(replace(string(key), "_" => " "));
                             contents=node_contents, direction="TB")
end

# #TODO-future: it seems v likely that anything that shows up in this function
# # will be shared with the validation functions
# function _mermaid_links_from_chain(chain::LegolasProcessChain)

#     # First, let's make a map between i/o fields
#     in_fields = Dict()
#     out_fields = Dict()
#     for (key, process) in chain.process_steps
#         in_fields[key] = NamedTuple([f => _field_node_name(f, "_InputSchema", key)
#                                      for f in fieldnames(input_specification(process))])
#         out_fields[key] = NamedTuple([f => _field_node_name(f, "_OutputSchema", key)
#                                       for f in fieldnames(output_specification(process))])
#     end

#     # Okay, how do we construct each input? Need to map from inputs to outputs
#     # We don't want to instantiate schemas here (for one thing, we don't have
#     # good mock data!) so let's make NamedTuples
#     links = String[]
#     for key in collect(keys(chain.process_steps))[2:end]
#         @info key

#         constructor = chain.input_constructors[key]
#         nt_input = missing
#         try
#             nt_input = constructor(out_fields)
#             @info nt_input
#         catch e
#             # @warn e
#         end
#         ismissing(nt_input) && continue

#         for k in keys(nt_input)
#             @info k
#             a = string(getproperty(nt_input, k))
#             b = string(in_fields[key][k])
#             # @info "..." typeof(a) typeof(b)

#             if contains(a, ".") || contains(b, ".")
#                 @warn "uh oh..." a b
#                 continue
#             end
#             push!(links, "$a --> $b")
#         end
#     end
#     return links
# end

const DEFAULT_STEP_STYLE = "fill:#fff,stroke:#000,stroke-width:1px;"
const DEFAULT_OUTER_STYLE = "fill:#fff,stroke:#000,stroke-width:0px;"
const DEFAULT_SPEC_STYLE = "fill:#fff,stroke:#000,stroke-width:1px;"
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

    push!(mermaid_lines, "", "%% Add steps (nodes)")
    push!(mermaid_lines, """subgraph OUTERLEVEL["` `"]""", "direction $direction")
    for step in chain
        Base.append!(mermaid_lines, _mermaid_subgraph_from_chain_step(step))
    end

    push!(mermaid_lines, "", "%% Link steps (nodes)")
    # Add (hidden) links between steps to fix chain order
    keys_upper = map(_mermaid_key, collect(keys(chain)))
    for i_key in 2:length(keys_upper)
        arrow = "-.->" #TODO: once fields are linked, replace this with "~~~"
        push!(mermaid_lines,
              "$(keys_upper[i_key - 1]):::classStep $arrow $(keys_upper[i_key]):::classStep")
    end
    push!(mermaid_lines, "", "end", "OUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter")

    # Create links between the various schema i/o fields
    push!(mermaid_lines, "", "%% Link step i/o fields", "%% TODO-future")
    # Base.append!(mermaid_lines, _mermaid_links_from_chain(chain))

    push!(mermaid_lines, "", "%% Styling definitions")
    for (name, style) in
        [("classStep", style_step), ("classSpec", style_spec), ("classOuter", style_outer),
         ("classSpecField", style_spec_field)]
        push!(mermaid_lines, "classDef $name $style")
    end

    push!(mermaid_lines, "", "%% Link step i/o fields", "%% TODO-future")
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
