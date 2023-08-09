using TransformSpecifications
using Documenter

DocMeta.setdocmeta!(TransformSpecifications, :DocTestSetup,
                    :(using TransformSpecifications, Legolas); recursive=true)

## Hack to use mermaid in docs
# Based on https://github.com/MilesCranmer/SymbolicRegression.jl/blob/098c986167702d3606be12b26bffff31446170ea/docs/make.jl#L53

visualization_md = read(joinpath(dirname(@__FILE__), "src", "visualization_raw.md"), String)

# Then, we create our mermaid plot, surrounded by ```mermaid\n...\n``` snippets
# with ```@raw html\n<div class="mermaid">\n...\n</div>```:
mermaid_demo = "```@raw html\n<div class=\"mermaid\">\n$(TransformSpecifications.DOCTEST_OUTPUT_nothrowchain_ex1)\n</div>\n```"

visualization_md = replace(visualization_md,
                           "MERMAID_RAW__TO_BE_REPLACED_VIA_MAKE_JL" => mermaid_demo)

# Then, we init mermaid.js:
init_mermaid = """
```@raw html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```
"""
# ...and create "/src/visualization.md":
visualization_md = init_mermaid * visualization_md
open(dirname(@__FILE__) * "/src/visualization.md", "w") do io
    return write(io, visualization_md)
end

# ...now back to normally scheduled programming!
makedocs(; modules=[TransformSpecifications],
         sitename="TransformSpecifications.jl",
         authors="Beacon Biosignals",
         pages=["Home" => "index.md",
                "Visualization" => "visualization.md",
                "API Documentation" => "api.md"],
         strict=true)

deploydocs(; repo="github.com/beacon-biosignals/TransformSpecifications.jl.git",
           push_preview=true, devbranch="main")
