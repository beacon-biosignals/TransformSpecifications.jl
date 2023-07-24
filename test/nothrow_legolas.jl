@schema "schema-a" SchemaA
@version SchemaAV1 begin
    foo::String
    list::Vector{Int} = [33]
end

@schema "schema-b" SchemaB
@version SchemaBV1 begin
    name::String
end

@schema "schema-c" SchemaC
@version SchemaCV1 begin
    foo::String
end

@testset "`NoThrowLegolasTransform`" begin
    process = NoThrowLegolasTransform(SchemaAV1, SchemaBV1,
                                      _ -> NoThrowResult(SchemaBV1(;
                                                                   name="yay")))
    @test input_specification(process) == SchemaAV1
    @test output_specification(process) == SchemaBV1
    input_record = SchemaAV1(; foo="rabbit")
    result = transform!(process, input_record)
    @test nothrow_succeeded(result)
    @test result.record isa SchemaBV1

    nonconforming_input_record = SchemaBV1(; name="rad")
    result = transform!(process, nonconforming_input_record)
    @test !nothrow_succeeded(result)
    @test isequal(only(result.violations),
                  """Record doesn't conform to input schema SchemaAV1. Details: ArgumentError("Invalid value set for field `foo`, expected String, got a value of type Missing (missing)")""")

    conforming_input_record = SchemaCV1(; foo="rad")
    @test !(conforming_input_record isa input_specification(process))
    result = transform!(process, conforming_input_record)
    @test nothrow_succeeded(result)

    # Test Base extensions
    fn = _ -> NoThrowResult(SchemaBV1(; name="yay"))
    @test NoThrowLegolasTransform(SchemaAV1, SchemaBV1, fn) ==
          NoThrowLegolasTransform(SchemaAV1, SchemaBV1,
                                  fn)
    @test isequal(NoThrowLegolasTransform(SchemaAV1, SchemaBV1, fn),
                  NoThrowLegolasTransform(SchemaAV1, SchemaBV1, fn))
end

@testset "`identity_legolas_process`" begin
    test_apply_fn(_) = NoThrowResult(SchemaBV1(; name="yay"))
    process_a = NoThrowLegolasTransform(SchemaAV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_a)
    @test_logs (:debug,
                "Input and output schemas are not identical: NoThrowLegolasTransform (input: SchemaAV1; output: SchemaBV1; process: test_apply_fn)") min_level = Logging.Debug !is_identity_process(process_a)

    process_b = NoThrowLegolasTransform(SchemaBV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_b)
    @test @test_logs (:debug, "`apply_fn` is not `identity_process_result_transform`") min_level = Logging.Debug match_mode = :any !is_identity_process(process_b)

    process_c = identity_legolas_process(SchemaAV1)
    @test is_identity_process(process_c)

    process_d = NoThrowLegolasTransform(SchemaAV1, SchemaAV1,
                                        TransformSpecifications.identity_process_result_transform)
    @test is_identity_process(process_d)
end

@testset "`TransformSpecificationChain`" begin
    process = identity_legolas_process(SchemaAV1)
    steps = OrderedDict("a" => process, "b" => process)
    constructors = Dict("a" => identity, "c" => identity)

    err_str = """ArgumentError: Mismatch in chain steps:
                 - Keys present in `process_steps` are missing in `input_constructors`: ["b"]
                 - Keys present in `input_constructors` are missing in `input_constructors`: ["c"]"""
    @test_throws err_str TransformSpecificationChain(steps, constructors)

    # Input constructor for first step is optional---but must be `nothing` if present
    @test TransformSpecificationChain(OrderedDict(:a => process, :b => process),
                                      Dict(:b => identity)) isa TransformSpecificationChain
    @test TransformSpecificationChain(OrderedDict(:a => process, :b => process),
                                      Dict(:a => nothing, :b => identity)) isa
          TransformSpecificationChain
    @test_throws "ArgumentError: First step's input constructor must be `nothing`" TransformSpecificationChain(OrderedDict(:a => process,
                                                                                                                           :b => process),
                                                                                                               Dict(:a => identity,
                                                                                                                    :b => identity)) isa
                                                                                   TransformSpecificationChain

    # TODO: test chain
    # TODO: test append! functionality
    # Test Base extensions

    # TODO: implement a helper function for a debug element, test it
end
