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

@testset "`NoThrowResult`" begin
    # At least one of "violations" or "record" must be present
    @test_throws ArgumentError NoThrowResult()
    @test_throws ArgumentError NoThrowResult(; warnings="Foo")
    @test_throws ArgumentError NoThrowResult(; result=missing)

    # Construction of basic result does not include or require warnings/violations
    record = SchemaAV1(; foo="huzzah")
    result = NoThrowResult(record)
    @test isequal(result, NoThrowResult(; result=record))
    @test isempty(result.violations)
    @test isempty(result.warnings)
    @test nothrow_succeeded(result)
    @test typeof(result) == NoThrowResult{SchemaAV1}

    # ...when warnings present, ntt can still be "successful"
    result_with_warnings = NoThrowResult(record; warnings=["look out",
                                                           "LOOK OUT!"])
    @test result_with_warnings.result == result.result
    @test length(result_with_warnings.warnings) == 2
    @test nothrow_succeeded(result)
    @test typeof(result_with_warnings) == NoThrowResult{SchemaAV1}

    # ...when violations present, ntt is deemed to not have succeeded
    result_with_violations = NoThrowResult(;
                                           violations=["look out",
                                                       "LOOK OUT!"])
    @test ismissing(result_with_violations.result)
    @test length(result_with_violations.violations) == 2
    @test !nothrow_succeeded(result_with_violations)
    @test typeof(result_with_violations) == NoThrowResult{Missing}

    # Passing in a single warning or violation auto-generates a vector of warnings/violations
    @test isequal(NoThrowResult(; warnings="Foo", result),
                  NoThrowResult(; warnings=["Foo"], result))
    @test isequal(NoThrowResult(; violations="Bar"),
                  NoThrowResult(; violations=["Bar"]))
    o = NoThrowResult(; warnings="Foo", violations="Bar")
    @test o.warnings == ["Foo"]
    @test o.violations == ["Bar"]

    @test NoThrowResult(; violations="Foo") isa NoThrowResult{Missing}
    @test_throws ArgumentError NoThrowResult(; violations="Foo", result)

    # Struct is non-copying:
    record = SchemaAV1(; foo="whee")
    result = NoThrowResult(record)
    @test length(record.list) == 1
    push!(record.list, 12, 2, 1)
    @test length(record.list) == 4
    @test isequal(result.result, record)

    # Test Base extensions
    @test NoThrowResult(record) == NoThrowResult(record)
    @test isequal(NoThrowResult(record), NoThrowResult(record))
end

@testset "`NoThrowTransform`" begin
    ntt = NoThrowTransform(SchemaAV1, SchemaBV1,
                               _ -> NoThrowResult(SchemaBV1(;
                                                            name="yay")))
    @test input_specification(ntt) == SchemaAV1
    @test NoThrowResult{SchemaBV1} <: output_specification(ntt)
    input_record = SchemaAV1(; foo="rabbit")
    result = transform!(ntt, input_record)
    @test nothrow_succeeded(result)
    @test result isa NoThrowResult{SchemaBV1}

    nonconforming_input_record = SchemaBV1(; name="rad")
    result = transform!(ntt, nonconforming_input_record)
    @test !nothrow_succeeded(result)
    @test isequal(only(result.violations),
                  """Record doesn't conform to input schema SchemaAV1. Details: ArgumentError("Invalid value set for field `foo`, expected String, got a value of type Missing (missing)")""")

    conforming_input_record = SchemaCV1(; foo="rad")
    @test !(conforming_input_record isa input_specification(ntt))
    result = transform!(ntt, conforming_input_record)
    @test nothrow_succeeded(result)

    # Test Base extensions
    fn = _ -> NoThrowResult(SchemaBV1(; name="yay"))
    @test NoThrowTransform(SchemaAV1, SchemaBV1, fn) ==
          NoThrowTransform(SchemaAV1, SchemaBV1,
                           fn)
    @test isequal(NoThrowTransform(SchemaAV1, SchemaBV1, fn),
                  NoThrowTransform(SchemaAV1, SchemaBV1, fn))
end

@testset "`identity_no_throw_transform`" begin
    test_transform_fn(_) = NoThrowResult(SchemaBV1(; name="yay"))
    ntt_a = NoThrowTransform(SchemaAV1, SchemaBV1, test_transform_fn)
    @test !is_identity_no_throw_transform(ntt_a)
    @test_logs (:debug,
                "Input and output schemas are not identical: NoThrowTransform (input: SchemaAV1; output: SchemaBV1; ntt: test_transform_fn)") min_level = Logging.Debug !is_identity_no_throw_transform(ntt_a)

    ntt_b = NoThrowTransform(SchemaBV1, SchemaBV1, test_transform_fn)
    @test !is_identity_no_throw_transform(ntt_b)
    @test @test_logs (:debug, "`transform_fn` is not `identity_ntt_result_transform`") min_level = Logging.Debug match_mode = :any !is_identity_no_throw_transform(ntt_b)

    ntt_c = identity_no_throw_transform(SchemaAV1)
    @test is_identity_no_throw_transform(ntt_c)

    ntt_d = NoThrowTransform(SchemaAV1, SchemaAV1,
                                 TransformSpecifications.identity_ntt_result_transform)
    @test is_identity_no_throw_transform(ntt_d)
end

@testset "`NoThrowTransformChain`" begin
    ntt = identity_no_throw_transform(SchemaAV1)
    steps = OrderedDict("a" => ntt, "b" => ntt)
    constructors = Dict("a" => identity, "c" => identity)

    err_str = """ArgumentError: Mismatch in chain steps:
                 - Keys present in `ntt_steps` are missing in `input_constructors`: ["b"]
                 - Keys present in `input_constructors` are missing in `input_constructors`: ["c"]"""
    @test_throws err_str NoThrowTransformChain(steps, constructors)

    # Input constructor for first step is optional---but must be `nothing` if present
    @test NoThrowTransformChain(OrderedDict(:a => ntt, :b => ntt),
                                      Dict(:b => identity)) isa NoThrowTransformChain
    @test NoThrowTransformChain(OrderedDict(:a => ntt, :b => ntt),
                                      Dict(:a => nothing, :b => identity)) isa
          NoThrowTransformChain
    @test_throws "ArgumentError: First step's input constructor must be `nothing`" NoThrowTransformChain(OrderedDict(:a => ntt,
                                                                                                                           :b => ntt),
                                                                                                               Dict(:a => identity,
                                                                                                                    :b => identity)) isa
                                                                                   NoThrowTransformChain

    # TODO: test chain
    # TODO: test append! functionality
    # Test Base extensions

    # TODO: implement a helper function for a debug element, test it
end