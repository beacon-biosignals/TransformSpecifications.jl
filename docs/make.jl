using TransformSpecifications
using Documenter

DocMeta.setdocmeta!(TransformSpecifications, :DocTestSetup,
                    :(using TransformSpecifications, Legolas); recursive=true)

makedocs(; modules=[TransformSpecifications],
         sitename="TransformSpecifications.jl",
         authors="Beacon Biosignals",
         pages=["API Documentation" => "index.md"],
         strict=true)

deploydocs(; repo="github.com/beacon-biosignals/TransformSpecifications.jl.git",
           push_preview=true, devbranch="main")
