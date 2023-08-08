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

    _schema_subgraph = (fields, prefix) -> begin
        return collect(map(collect(fields)) do field
                           return "$(_field_node_name(field, prefix, node_key))[$field]"
                       end)
    end

    inputs_subgraph = let
        prefix = "_InputSchema"
        contents = _schema_subgraph(keys(construct_field_map(input_specification(process))),
                                    prefix)
        label = string("Input: ", input_specification(process))
        _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
    end
    outputs_subgraph = let
        prefix = "_OutputSchema"
        type = result_type(output_specification(process))
        label = string("Output: ", type)
        contents = _schema_subgraph(fieldnames(type), prefix)
        _mermaid_subgraph(node_key * prefix, label; contents, direction="RL")
    end

    node_contents = reduce(vcat,
                           [inputs_subgraph, outputs_subgraph,
                            "$(node_key)_InputSchema == $(process.transform_spec.transform_fn) ==> $(node_key)_OutputSchema"])
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

"""
    mermaidify(chain::NoThrowTransformChain; direction="TB")

Generate [mermaid plot](https://mermaid.js.org/) of `chain`, suitable for inclusion
in markdown documentation. For example usage, see [`NoThrowTransformChain`](@ref).
"""
function mermaidify(chain::NoThrowTransformChain; direction="LR")
    mermaid_lines = ["flowchart $direction"]

    push!(mermaid_lines, "", "%% Add steps (nodes)")
    for step in chain
        Base.append!(mermaid_lines, _mermaid_subgraph_from_chain_step(step))
    end

    push!(mermaid_lines, "", "%% Link steps (nodes)")
    # Add (hidden) links between steps to fix chain order
    keys_upper = map(_mermaid_key, collect(keys(chain)))
    for i_key in 2:length(keys_upper)
        arrow = "-.->" #TODO: once fields are linked, replace this with "~~~"
        push!(mermaid_lines, "$(keys_upper[i_key - 1]) $arrow $(keys_upper[i_key])")
    end

    # Create links between the various schema i/o fields
    push!(mermaid_lines, "", "%% Link step i/o fields")
    # Base.append!(mermaid_lines, _mermaid_links_from_chain(chain))
    return join(mermaid_lines, "\n")
end
