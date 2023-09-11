@schema "schema-foo" SchemaFoo
@version SchemaFooV1 begin
    foo::String
    list::Vector{Int} = [33]
end

@schema "schema-bar" SchemaBar
@version SchemaBarV1 begin
    var1::String
    var2::String
end

@schema "schema-foo-child" SchemaFooChild
@version SchemaFooChildV1 > SchemaFooV1 begin
    woo::String = "eee"
end

@schema "mytype" TestType
@version TestTypeV1 begin
    schemafoo::SchemaFooV1
    str::String
end

@testset "Basics" begin
    step_a = DAGStep("init", nothing,
                     TransformSpecification(SchemaFooV1, SchemaFooV1, identity))
    step_b = DAGStep("init", nothing,
                     NoThrowTransform(SchemaFooV1, SchemaFooV1, identity))
    dag_a = NoThrowDAG(step_a)
    dag_b = NoThrowDAG(step_b)
    dag_c = NoThrowDAG([step_a])

    @test isequal(dag_a, dag_b)
    @test isequal(dag_a, dag_c)
    @test dag_a == dag_b == dag_c
end

@testset "Construction errors" begin
    @test_throws ArgumentError("At least one step required to construct a DAG") NoThrowDAG(DAGStep[])

    @testset "First step constructor must be `nothing`" begin
        ntt = NoThrowTransform(SchemaBarV1)
        @test NoThrowDAG([DAGStep("a", nothing, ntt)]) isa NoThrowDAG
        err = ArgumentError("Initial step's input constructor must be `nothing` (TransformSpecification{Dict{String, Any},NamedTuple}: `identity`)")
        @test_throws err NoThrowDAG([DAGStep("a", input_assembler(identity), ntt)])
    end

    @testset "Invalid input assembler" begin
        ts = TransformSpecification(SchemaFooV1, SchemaFooV1, identity)
        err = ArgumentError("Invalid `input_assembler`")
        @test_throws err NoThrowDAG([DAGStep("foo", identity, ts)])
    end

    @testset "Invalid step combinations" begin
        ts = TransformSpecification(SchemaFooV1, SchemaFooV1, identity)
        err = ArgumentError("Step with name `foo` already exists in DAG!")
        @test_throws err NoThrowDAG([DAGStep("foo", nothing, ts),
                                     DAGStep("foo", nothing, ts)])

        ch = [DAGStep("step1", nothing, ts),
              DAGStep("step2", input_assembler(d -> (; foo=d["x"])), ts)]
        @test_throws KeyError("x") NoThrowDAG(ch)

        ch = [DAGStep("step1", nothing, ts),
              DAGStep("step2", input_assembler(d -> (; foo=d["step1"][:x])), ts)]
        @test_throws KeyError(:x) NoThrowDAG(ch)

        # Can't wrap a broken test_throws BUT this should throw in the future,
        # when additional validation added!
        ch = [DAGStep("step1", nothing, ts),
              DAGStep("step2", input_assembler(d -> (; foo=d["step1"][:foo])), ts),
              DAGStep("step3", input_assembler(d -> (; foo=d["step1"][:foo])), ts)]
        err = ArgumentError("Input assembler for step `step3` cannot depend on `[step1][foo]`; output already used by step `step2`")
        @test_broken false # (@test_throws err NoThrowDAG(ch))
    end
end

@testset "Basic `NoThrowDAG`" begin
    fn_step_a(x) = SchemaBarV1(; var1=x.foo * "_a", var2=x.foo * "_a2")
    fn_step_b(x) = SchemaFooV1(; foo=x.foo * "_b")
    fn_step_c(x) = SchemaFooV1(; foo=string(x.var1, "_WOW_", x.var2))

    steps = [DAGStep("step_a", nothing,
                     NoThrowTransform(SchemaFooV1, SchemaBarV1, fn_step_a)),
             DAGStep("step_b",
                     input_assembler(d -> (; foo=d["step_a"][:var1])),
                     NoThrowTransform(SchemaFooV1, SchemaFooV1, fn_step_b)),
             DAGStep("step_c",
                     input_assembler(d -> (; var1=d["step_a"][:var2],
                                           var2=d["step_b"][:foo])),
                     NoThrowTransform(SchemaBarV1, SchemaFooV1,
                                      fn_step_c))]
    dag = NoThrowDAG(steps)
    @test dag isa NoThrowDAG

    @testset "Internals" begin
        @test issetequal(keys(dag.step_input_assemblers), keys(dag.step_transforms))
        @test issetequal(keys(dag._step_output_fields), keys(dag.step_transforms))
        @test length(steps) == length(dag) == 3
        @test size(dag) == (3,)
        @test firstindex(dag) == 1
        @test lastindex(dag) == 3
        @test Base.IteratorEltype(dag) == eltype(dag) == DAGStep
        @test isequal(steps, map(i -> get_step(dag, i), 1:length(dag)))
        @test isequal(steps, map(n -> get_step(dag, n), [s.name for s in steps]))

        @test_throws KeyError get_step(dag, "nonexistent_step")
        @test_throws BoundsError get_step(dag, 15)
    end

    @testset "Externals" begin
        @test dag isa AbstractTransformSpecification
        @test input_specification(dag) == SchemaFooV1
        @test output_specification(dag) == NoThrowResult{SchemaFooV1}
    end

    @testset "Conforming input succeeds" begin
        input_record = SchemaFooV1(; foo="rabbit")
        dag_output = transform!(dag, input_record)
        @test nothrow_succeeded(dag_output)
        @test dag_output isa NoThrowResult{SchemaFooV1}
        @test dag_output.result.foo == "rabbit_a2_WOW_rabbit_a_b"

        conforming_input_record = SchemaFooChildV1(; foo="rabbit")
        @test !(conforming_input_record isa input_specification(dag))
        dag_output2 = transform!(dag, conforming_input_record)
        @test isequal(dag_output, dag_output2)

        unwrapped_output = transform_force_throw!(dag, conforming_input_record)
        @test isequal(dag_output.result, unwrapped_output)
    end

    @testset "Nonconforming input fails" begin
        result = transform!(dag, SchemaBarV1(; var1="yay", var2="whee"))
        @test !nothrow_succeeded(result)
        err_str = "Input to step `step_a` doesn't conform to specification `SchemaFooV1`. \
                   Details: ArgumentError(\"Invalid value set for field `foo`, expected String, \
                   got a value of type Missing (missing)\")"
        @test isequal(err_str, only(result.violations))

        err = ArgumentError("Input to step `step_a` doesn't conform to specification `SchemaFooV1`")
        @test_throws err transform_force_throw!(dag, SchemaBarV1(; var1="yay", var2="whee"))
    end

    @testset "`_validate_input_assembler`" begin
        using TransformSpecifications: _validate_input_assembler
        @test isnothing(_validate_input_assembler(dag, nothing))
        @test_throws KeyError _validate_input_assembler(dag,
                                                        input_assembler(d -> d[:invalid_step]["foo"]))
    end

    @testset "`mermaidify`" begin
        ref_test_file = joinpath(pkgdir(TransformSpecifications), "test", "reference_tests",
                                 "mermaid_nothrowdag.md")
        ref_str = read(ref_test_file, String)
        test_str = ("```mermaid\n$(mermaidify(dag))\n```\n")
        @test isequal(ref_str, test_str)

        # If this test fails because the generated output is intentionally different,
        # update the reference by doing
        # write(ref_test_file, test_str)
    end
end

@testset "Helper utilities" begin
    using TransformSpecifications: field_dict_value, field_dict
    @testset "`field_dict_value`" begin
        @test field_dict_value(String) == field_dict_value(NoThrowResult{String}) == String
        @test field_dict_value(Dict) == field_dict_value(NoThrowResult{Dict}) == Dict
        @test field_dict_value(SchemaFooV1) == field_dict_value(NoThrowResult{SchemaFooV1})
    end

    @testset "`field_dict`" begin
        @test field_dict(String) == Dict{Any,Any}()
        @test field_dict(Dict) isa Dict{Symbol,Type}
        @test field_dict(SchemaFooV1) ==
              Dict{Symbol,DataType}(:list => Vector{Int64}, :foo => String)
    end

    @testset "Recurse into specification" begin
        orig = field_dict(TestTypeV1)
        @test orig == Dict(:schemafoo => SchemaFooV1, :str => String)

        # If we _want_ to be able to recurse into a specific specification type,
        # define an overloaded `field_dict_value` implementation of it:
        TransformSpecifications.field_dict_value(t::Type{SchemaFooV1}) = field_dict(t)
        recursed = field_dict(TestTypeV1)
        @test recursed == Dict(:schemafoo => Dict(:list => Vector{Int64}, :foo => String),
                               :str => String)
    end
end
