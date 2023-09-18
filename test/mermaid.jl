# Here we use a separate module to ensure the test is re-runnable
# If this file is re-included, the module will be replaced.
module RobustImportsTest
using Test, TransformSpecifications
module A
struct X end
end
@testset "mermaid is robust to imports" begin
    steps = [DAGStep("step_a", nothing,
                     NoThrowTransform(String, A.X, identity)),
             DAGStep("step_b",
                     nothing,
                     NoThrowTransform(A.X, A.X, identity))]
    dag = NoThrowDAG(steps)
    m1 = mermaidify(dag)

    using .A: X
    m2 = mermaidify(dag)
    @test isequal(m1, m2)
end
end # module

# Used to test that quotes are escaped correctly for mermaid diagram
struct Duckling
    x::Val{Symbol("""\"hi12,32}{{}:y;./[]]""")}
end

@schema "schema-rad" SchemaRad
@version SchemaRadV1 begin
    foo::Union{String,Missing}
    list::Vector{Int}
    d::Val{Symbol("""\"hi1232}{{}:y;./[]]""")}
end

@schema "schema-yay" SchemaYay
@version SchemaYayV1 begin
    rad::SchemaRadV1
    duck::Duckling
end

@testset "`mermaidify` handles Legolas schemas" begin
    make_rad(rad) = SchemaYayV1(; rad)

    steps = [DAGStep("step_a", nothing,
                     NoThrowTransform(SchemaRadV1)),
             DAGStep("step_b", nothing,
                     NoThrowTransform(SchemaRadV1, SchemaYayV1, make_rad))]
    dag = NoThrowDAG(steps)

    @testset "Default display" begin
        test_str = ("```mermaid\n$(mermaidify(dag))\n```\n")
        ref_test_file = joinpath(pkgdir(TransformSpecifications), "test", "reference_tests",
                                 "mermaid_legolas.md")
        ref_str = read(ref_test_file, String)
        @test isequal(ref_str, test_str)

        # If this test fails because the generated output is intentionally different,
        # update the reference by doing
        # write(ref_test_file, test_str)
    end

    @testset "Custom display" begin
        function TransformSpecifications.field_dict_value(t::Type{SchemaRadV1})
            return TransformSpecifications.field_dict(t)
        end
        local ref_test_file, test_str
        try
            test_str = ("```mermaid\n$(mermaidify(dag))\n```\n")
            ref_test_file = joinpath(pkgdir(TransformSpecifications), "test",
                                     "reference_tests",
                                     "mermaid_custom.md")
            ref_str = read(ref_test_file, String)
            @test isequal(ref_str, test_str)
        finally
            # Reset definition back to the default to ensure the tests are re-runnable
            TransformSpecifications.field_dict_value(t::Type{SchemaRadV1}) = t
        end
        # If this test fails because the generated output is intentionally different,
        # update the reference by doing
        # write(ref_test_file, test_str)
    end

    @testset "type_string" begin
        @test type_string(fieldtype(SchemaRadV1, 1)) == "Union{Missing, String}"
        @test type_string(fieldtype(SchemaRadV1, 2)) == "Vector{Int64}"
        @test type_string(Vector{String}) == "Vector{String}"
        @test type_string(RobustImportsTest.A.X) == "X"
    end
end

@testset "`mermaidify` handles escapes" begin
    # Verifies types that are known to require string-escaping in order to render correctly

    # obviously this function doesn't yield a _valid_ dag, but as far as
    # mermaid is concerned, it doesn't have to be valid
    func(x) = x
    steps = [DAGStep("step_a", nothing, NoThrowTransform(NamedTuple{(:rad,)})),
             DAGStep("step_b", nothing, NoThrowTransform(Nothing, Duckling, func))]
    dag = NoThrowDAG(steps)

    test_str = ("```mermaid\n$(mermaidify(dag))\n```\n")
    ref_test_file = joinpath(pkgdir(TransformSpecifications), "test", "reference_tests",
                             "mermaid_escape.md")
    ref_str = read(ref_test_file, String)
    @test isequal(ref_str, test_str)

    # If this test fails because the generated output is intentionally different,
    # update the reference by doing
    # write(ref_test_file, test_str)
end
