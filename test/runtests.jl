include("set_up_tests.jl")

@testset "TransformSpecifications.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(TransformSpecifications; ambiguities=false)
    end

    @testset "Doctests" begin
        doctest(TransformSpecifications)
    end

    @testset "`TransformSpecification`" begin
        include("transform.jl")
    end

    @testset "NoThrow" begin
        include("nothrow.jl")
    end

    @testset "`NoThrowTransformChain`" begin
        include("nothrow_chain.jl")
    end
end
