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

@schema "schema-rad" SchemaRad
@version SchemaRadV1 begin
    foo::String
    list::Vector{Int}
end

@schema "schema-yay" SchemaYay
@version SchemaYayV1 begin
    rad::SchemaRadV1
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
        test_equals_reference(test_str, ref_test_file)

        # If this test fails because the generated output is intentionally different,
        # update the reference by doing
        # update_reference!(test_str, ref_test_file)
    end

    @testset "Custom display" begin
        function TransformSpecifications.field_dict_value(t::Type{SchemaRadV1})
            return TransformSpecifications.field_dict(t)
        end
        test_str = ("```mermaid\n$(mermaidify(dag))\n```\n")
        ref_test_file = joinpath(pkgdir(TransformSpecifications), "test",
                                 "reference_tests",
                                 "mermaid_custom.md")
        test_equals_reference(test_str, ref_test_file)
        # If this test fails because the generated output is intentionally different,
        # update the reference by doing
        # update_reference!(test_str, ref_test_file)
    end
end
