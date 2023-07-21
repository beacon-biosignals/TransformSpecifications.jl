using LegolasProcesses
using Documenter

makedocs(; modules=[LegolasProcesses],
         sitename="LegolasProcesses.jl",
         authors="Beacon Biosignals",
         pages=["API Documentation" => "index.md"],
         strict=true)

deploydocs(; repo="github.com/beacon-biosignals/SleepLab.jl.git", push_preview=true,
           devbranch="main", dirname="LegolasProcesses",
           versions=["stable" => "LegolasProcesses-v^", "LegolasProcesses-v#.#",
                     "dev" => "dev"])
