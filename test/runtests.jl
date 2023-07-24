include("set_up_tests.jl")

@testset "TransformSpecifications.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(TransformSpecifications; ambiguities=false)
    end

    @testset "Processes" include("processes.jl")
end
