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

@testset "`TransformSpecificationResult`" begin
    # At least one of "violations" or "record" must be present
    @test_throws ArgumentError TransformSpecificationResult()
    @test_throws ArgumentError TransformSpecificationResult(; warnings="Foo")
    @test_throws ArgumentError TransformSpecificationResult(; record=missing)

    # Construction of basic result does not include or require warnings/violations
    record = SchemaAV1(; foo="huzzah")
    result = TransformSpecificationResult(record)
    @test isequal(result, TransformSpecificationResult(; record))
    @test isempty(result.violations)
    @test isempty(result.warnings)
    @test process_succeeded(result)
    @test typeof(result) == TransformSpecificationResult{SchemaAV1}

    # ...when warnings present, process can still be "successful"
    result_with_warnings = TransformSpecificationResult(record;
                                                        warnings=["look out",
                                                                  "LOOK OUT!"])
    @test result_with_warnings.record == result.record
    @test length(result_with_warnings.warnings) == 2
    @test process_succeeded(result)
    @test typeof(result_with_warnings) == TransformSpecificationResult{SchemaAV1}

    # ...when violations present, process is deemed to not have succeeded
    result_with_violations = TransformSpecificationResult(;
                                                          violations=["look out",
                                                                      "LOOK OUT!"])
    @test ismissing(result_with_violations.record)
    @test length(result_with_violations.violations) == 2
    @test !process_succeeded(result_with_violations)
    @test typeof(result_with_violations) == TransformSpecificationResult{Missing}

    # Passing in a single warning or violation auto-generates a vector of warnings/violations
    @test isequal(TransformSpecificationResult(; warnings="Foo", record),
                  TransformSpecificationResult(; warnings=["Foo"], record))
    @test isequal(TransformSpecificationResult(; violations="Bar"),
                  TransformSpecificationResult(; violations=["Bar"]))
    o = TransformSpecificationResult(; warnings="Foo", violations="Bar")
    @test o.warnings == ["Foo"]
    @test o.violations == ["Bar"]

    # When violations are present, record state is undefined: can be missing or present despite violations
    #TODO-decide: maybe we don't want to support this?? and they should always be missing??? discuss!
    @test TransformSpecificationResult(; violations="Foo") isa
          TransformSpecificationResult{Missing}
    @test TransformSpecificationResult(; violations="Foo", record) isa
          TransformSpecificationResult{SchemaAV1}

    # Struct is non-copying:
    record = SchemaAV1(; foo="whee")
    result = TransformSpecificationResult(record)
    @test length(record.list) == 1
    push!(record.list, 12, 2, 1)
    @test length(record.list) == 4
    @test isequal(result.record, record)

    # Test Base extensions
    @test TransformSpecificationResult(record) == TransformSpecificationResult(record)
    @test isequal(TransformSpecificationResult(record),
                  TransformSpecificationResult(record))
end

@testset "`TransformSpecification`" begin
    process = TransformSpecification(SchemaAV1, SchemaBV1,
                                     _ -> TransformSpecificationResult(SchemaBV1(;
                                                                                 name="yay")))
    @test input_specification(process) == SchemaAV1
    @test output_specification(process) == SchemaBV1
    input_record = SchemaAV1(; foo="rabbit")
    result = apply!(process, input_record)
    @test process_succeeded(result)
    @test result.record isa SchemaBV1

    nonconforming_input_record = SchemaBV1(; name="rad")
    result = apply!(process, nonconforming_input_record)
    @test !process_succeeded(result)
    @test isequal(only(result.violations),
                  """Record doesn't conform to input schema SchemaAV1. Details: ArgumentError("Invalid value set for field `foo`, expected String, got a value of type Missing (missing)")""")

    conforming_input_record = SchemaCV1(; foo="rad")
    @test !(conforming_input_record isa input_specification(process))
    result = apply!(process, conforming_input_record)
    @test process_succeeded(result)

    # Test Base extensions
    fn = _ -> TransformSpecificationResult(SchemaBV1(; name="yay"))
    @test TransformSpecification(SchemaAV1, SchemaBV1, fn) ==
          TransformSpecification(SchemaAV1, SchemaBV1,
                                 fn)
    @test isequal(TransformSpecification(SchemaAV1, SchemaBV1, fn),
                  TransformSpecification(SchemaAV1, SchemaBV1, fn))
end

@testset "`identity_legolas_process`" begin
    test_apply_fn(_) = TransformSpecificationResult(SchemaBV1(; name="yay"))
    process_a = TransformSpecification(SchemaAV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_a)
    @test_logs (:debug,
                "Input and output schemas are not identical: TransformSpecification (input: SchemaAV1; output: SchemaBV1; process: test_apply_fn)") min_level = Logging.Debug !is_identity_process(process_a)

    process_b = TransformSpecification(SchemaBV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_b)
    @test @test_logs (:debug, "`apply_fn` is not `identity_process_result_transform`") min_level = Logging.Debug match_mode = :any !is_identity_process(process_b)

    process_c = identity_legolas_process(SchemaAV1)
    @test is_identity_process(process_c)

    process_d = TransformSpecification(SchemaAV1, SchemaAV1,
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
