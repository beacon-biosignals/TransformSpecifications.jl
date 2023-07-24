using TransformSpecifications
using Documenter

makedocs(; modules=[TransformSpecifications],
         sitename="TransformSpecifications.jl",
         authors="Beacon Biosignals",
         pages=["API Documentation" => "index.md"],
         strict=true)

deploydocs(; repo="github.com/beacon-biosignals/TransformSpecifications.jl.git",
           push_preview=true,
           devbranch="main")
