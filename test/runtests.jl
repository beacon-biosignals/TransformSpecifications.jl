include("set_up_tests.jl")

@testset "TransformSpecifications.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(TransformSpecifications; ambiguities=false)
    end

    # @testset "Abstract" include("abstract.jl") #TODO: implement!
    @testset "No-throw type" include("nothrow.jl")
    @testset "No-throw Legolas transforms" include("nothrow_legolas.jl")
end
