include("set_up_tests.jl")

@testset "LegolasProcesses.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(LegolasProcesses; ambiguities=false)
    end

    @testset "Processes" include("processes.jl")
end
