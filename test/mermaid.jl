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
