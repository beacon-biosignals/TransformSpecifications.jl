
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

@testset "`LegolasProcessResult`" begin
    # At least one of "violations" or "record" must be present
    @test_throws ArgumentError LegolasProcessResult()
    @test_throws ArgumentError LegolasProcessResult(; warnings="Foo")
    @test_throws ArgumentError LegolasProcessResult(; record=missing)

    # Construction of basic result does not include or require warnings/violations
    record = SchemaAV1(; foo="huzzah")
    result = LegolasProcessResult(record)
    @test isequal(result, LegolasProcessResult(; record))
    @test isempty(result.violations)
    @test isempty(result.warnings)
    @test process_succeeded(result)

    # ...when warnings present, process can still be "successful"
    result_with_warnings = LegolasProcessResult(record;
                                                warnings=["look out",
                                                          "LOOK OUT!"])
    @test result_with_warnings.record == result.record
    @test length(result_with_warnings.warnings) == 2
    @test process_succeeded(result)

    # ...when violations present, process is deemed to not have succeeded
    result_with_violations = LegolasProcessResult(;
                                                  violations=["look out",
                                                              "LOOK OUT!"])
    @test ismissing(result_with_violations.record)
    @test length(result_with_violations.violations) == 2
    @test !process_succeeded(result_with_violations)

    # Passing in a single warning or violation auto-generates a vector of warnings/violations
    @test isequal(LegolasProcessResult(; warnings="Foo", record),
                  LegolasProcessResult(; warnings=["Foo"], record))
    @test isequal(LegolasProcessResult(; violations="Bar"),
                  LegolasProcessResult(; violations=["Bar"]))
    o = LegolasProcessResult(; warnings="Foo", violations="Bar")
    @test o.warnings == ["Foo"]
    @test o.violations == ["Bar"]

    # When violations are present, record state is undefined: can be missing or present despite violations
    @test LegolasProcessResult(; violations="Foo") isa LegolasProcessResult
    @test LegolasProcessResult(; violations="Foo", record) isa LegolasProcessResult

    # Struct is non-copying:
    record = SchemaAV1(; foo="whee")
    result = LegolasProcessResult(record)
    @test length(record.list) == 1
    push!(record.list, 12, 2, 1)
    @test length(record.list) == 4
    @test isequal(result.record, record)

    # Test Base extensions
    @test LegolasProcessResult(record) == LegolasProcessResult(record)
    @test isequal(LegolasProcessResult(record), LegolasProcessResult(record))
end

@testset "`LegolasProcess`" begin
    process = LegolasProcess(SchemaAV1, SchemaBV1,
                             _ -> LegolasProcessResult(SchemaBV1(; name="yay")))
    @test input_schema(process) == SchemaAV1
    @test output_schema(process) == SchemaBV1
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
    @test !(conforming_input_record isa input_schema(process))
    result = apply!(process, conforming_input_record)
    @test process_succeeded(result)

    # Test Base extensions
    fn = _ -> LegolasProcessResult(SchemaBV1(; name="yay"))
    @test LegolasProcess(SchemaAV1, SchemaBV1, fn) ==
          LegolasProcess(SchemaAV1, SchemaBV1,
                         fn)
    @test isequal(LegolasProcess(SchemaAV1, SchemaBV1, fn),
                  LegolasProcess(SchemaAV1, SchemaBV1, fn))
end

@testset "`identity_legolas_process`" begin
    test_apply_fn(_) = LegolasProcessResult(SchemaBV1(; name="yay"))
    process_a = LegolasProcess(SchemaAV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_a)
    @test_logs (:debug,
                "Input and output schemas are not identical: LegolasProcess (input: SchemaAV1; output: SchemaBV1; process: test_apply_fn)") min_level = Logging.Debug !is_identity_process(process_a)

    process_b = LegolasProcess(SchemaBV1, SchemaBV1, test_apply_fn)
    @test !is_identity_process(process_b)
    @test @test_logs (:debug, "`apply_fn` is not identity") min_level = Logging.Debug match_mode = :any !is_identity_process(process_b)

    process_c = identity_legolas_process(SchemaAV1)
    @test is_identity_process(process_c)
end

@testset "`LegolasProcessChain`" begin
    process = identity_legolas_process(SchemaAV1)
    steps = OrderedDict("a" => process, "b" => process)
    constructors = Dict("a" => identity, "c" => identity)

    err_str = """ArgumentError: Mismatch in chain steps:
                 - Keys present in `process_steps` are missing in `input_constructors`: ["b"]
                 - Keys present in `input_constructors` are missing in `input_constructors`: ["c"]"""
    @test_throws err_str LegolasProcessChain(steps, constructors)

    # Input constructor for first step is optional---but must be `nothing` if present
    @test LegolasProcessChain(OrderedDict(:a => process, :b => process),
                              Dict(:b => identity)) isa LegolasProcessChain
    @test LegolasProcessChain(OrderedDict(:a => process, :b => process),
                              Dict(:a => nothing, :b => identity)) isa LegolasProcessChain
    @test_throws "ArgumentError: First step's input constructor must be `nothing`" LegolasProcessChain(OrderedDict(:a => process,
                                                                                                                   :b => process),
                                                                                                       Dict(:a => identity,
                                                                                                            :b => identity)) isa
                                                                                   LegolasProcessChain

    # TODO: test chain
    # TODO: test append! functionality
    # Test Base extensions

    # TODO: implement a helper function for a debug element, test it
end