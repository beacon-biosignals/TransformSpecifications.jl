include("set_up_tests.jl")

@testset "TransformSpecifications.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(TransformSpecifications; ambiguities=false)
    end

    @testset "`TransformSpecification`" begin
        include("transform.jl")
    end

    @testset "NoThrow" begin
        include("nothrow.jl")
    end

    @testset "`NoThrowDAG`" begin
        include("nothrow_dag.jl")
    end

    @testset "`mermaid`" begin
        include("mermaid.jl")
    end

    @testset "Doctests" begin
        doctest(TransformSpecifications)
    end
end
