```@raw html
<!-- Support mermaid, ref https://github.com/JuliaDocs/Documenter.jl/issues/1943-->
<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
<script>mermaid.initialize({startOnLoad:true});</script>
```

# TransformSpecifications.jl

```@docs
TransformSpecifications.TransformSpecifications
```

## Table of contents

```@contents
Pages = ["index.md", "api.md"]
Depth = 3
```

## AbstractTransformSpecification
```@autodocs
Modules = [TransformSpecifications]
Pages = ["abstract.jl"]
```

## TransformSpecification
```@autodocs
Modules = [TransformSpecifications]
Pages = ["transform.jl"]
```
## NoThrowTransform
```@autodocs
Modules = [TransformSpecifications]
Pages = ["nothrow.jl"]
```

## NoThrowTransformChain
```@autodocs
Modules = [TransformSpecifications]
Pages = ["nothrow_chain.jl"]
```

## Mermaid
```@autodocs
Modules = [TransformSpecifications]
Pages = ["mermaid.jl"]
```

Here is the mermaid plot of the chain generated in [`NoThrowTransformChain`](@ref):
<!-- ```@eval
using TransformSpecifications

md = """<div class="mermaid">
$(TransformSpecifications.DOCTEST_OUTPUT_nothrowchain_ex1)
</div>"""
Markdown.parse(join(md, "\n\n"))
``` -->
