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
    @testset "`violations` OR `result` required" begin
        @test_throws ArgumentError NoThrowResult()
        @test_throws ArgumentError NoThrowResult(; warnings="Foo")
        @test_throws ArgumentError NoThrowResult(; result=missing)
        @test_throws MethodError NoThrowResult(; violations=[3, 2])
        @test_throws ArgumentError NoThrowResult(; violations="Foo",
                                                 result=SchemaAV1(; foo="huzzah"))
    end

    @testset "Success result" begin
        record = SchemaAV1(; foo="huzzah")
        result = NoThrowResult(record)
        @test isequal(result, NoThrowResult(; result=record))
        @test isempty(result.violations)
        @test isempty(result.warnings)
        @test nothrow_succeeded(result)
        @test typeof(result) == NoThrowResult{SchemaAV1}
    end

    @testset "Success result with warnings" begin
        record = SchemaAV1(; foo="huzzah")
        result = NoThrowResult(record)
        result_with_warnings = NoThrowResult(record; warnings=["look out",
                                                               "LOOK OUT!"])
        @test result_with_warnings.result == result.result
        @test length(result_with_warnings.warnings) == 2
        @test nothrow_succeeded(result)
        @test typeof(result_with_warnings) == NoThrowResult{SchemaAV1}
    end

    @testset "Failure result" begin
        result_with_violations = NoThrowResult(;
                                               violations=["look out",
                                                           "LOOK OUT!"])
        @test ismissing(result_with_violations.result)
        @test length(result_with_violations.violations) == 2
        @test !nothrow_succeeded(result_with_violations)
        @test typeof(result_with_violations) == NoThrowResult{Missing}
    end

    @testset "Single warning/violation helper" begin
        record = SchemaAV1(; foo="huzzah")
        @test isequal(NoThrowResult(; warnings="Foo", result=record),
                      NoThrowResult(; warnings=["Foo"], result=record))
        @test isequal(NoThrowResult(; violations="Bar"),
                      NoThrowResult(; violations=["Bar"]))
        o = NoThrowResult(; warnings="Foo", violations="Bar")
        @test o.warnings == ["Foo"]
        @test o.violations == ["Bar"]
    end

    @testset "Result is non-copying" begin
        record = SchemaAV1(; foo="whee")
        result = NoThrowResult(record)
        @test length(record.list) == 1
        push!(record.list, 12, 2, 1)
        @test length(record.list) == 4
        @test isequal(result.result, record)
    end

    @testset "Base extensions" begin
        record = SchemaAV1(; foo="whee")
        @test NoThrowResult(record) == NoThrowResult(record)
        @test isequal(NoThrowResult(record), NoThrowResult(record))
        @test NoThrowResult(; violations="Foo") == NoThrowResult(; violations="Foo")
        @test isequal(NoThrowResult(; violations="Foo"), NoThrowResult(; violations="Foo"))
    end

    @testset "Nested `NoThrowResult{T}`" begin
        record = NoThrowResult(SchemaAV1(; foo="whee"); warnings="avast")
        @test record isa NoThrowResult{SchemaAV1}

        result = NoThrowResult(record)
        @test result isa NoThrowResult{SchemaAV1}
        @test result.warnings == ["avast"]

        result_with_warnings = NoThrowResult(record; warnings=["ahoy"])
        @test result_with_warnings isa NoThrowResult{SchemaAV1}
        @test result_with_warnings.warnings == ["avast", "ahoy"]

        # All constructor options are equivalent
        @test NoThrowResult(; warnings=["Foo"], result) ==
              NoThrowResult(result; warnings=["Foo"]) ==
              NoThrowResult(; warnings="Foo", result)

        nested_result = NoThrowResult(33; warnings="0")
        for i in 1:10
            nested_result = NoThrowResult(nested_result; warnings="$i")
        end
        @test nested_result isa NoThrowResult{Int}
        @test nested_result.warnings == ["$i" for i in 0:10]
    end

    @testset "Nested `NoThrowResult{Missing}`" begin
        record = NoThrowResult(missing; violations="violation a", warnings="warnings a")
        @test record isa NoThrowResult{Missing}
        result_with_missing = NoThrowResult(record)
        @test result_with_missing isa NoThrowResult{Missing}

        result_from_kwargs = NoThrowResult(; result=record)
        @test isequal(result_with_missing, result_from_kwargs)

        result_all_the_fixings = NoThrowResult(NoThrowResult(;
                                                             violations="why not take a crazy chance",
                                                             warnings="(why not)");
                                               violations="why not do a crazy dance",
                                               warnings="(why not)")
        @test result_all_the_fixings isa NoThrowResult{Missing}
        @test result_all_the_fixings.violations ==
              ["why not take a crazy chance", "why not do a crazy dance"]
        @test result_all_the_fixings.warnings == ["(why not)", "(why not)"]

        # All constructor options are equivalent
        @test isequal(NoThrowResult(; violations=["Foo"]),
                      NoThrowResult(missing; violations=["Foo"]))
        @test isequal(NoThrowResult(; violations=["Foo"]),
                      NoThrowResult(; violations="Foo"))

        nested_result = NoThrowResult(; violations="0")
        for i in 1:10
            nested_result = NoThrowResult(nested_result; violations="$i")
        end
        @test nested_result isa NoThrowResult{Missing}
        @test nested_result.violations == ["$i" for i in 0:10]
    end
end

@testset "`NoThrowTransform`" begin
    @testset "Conforming input succeeds" begin
        transform_fn = _ -> SchemaBV1(; name="yay")
        ntt = NoThrowTransform(SchemaAV1, SchemaBV1, transform_fn)
        @test input_specification(ntt) == SchemaAV1
        @test output_specification(ntt) == NoThrowResult{SchemaBV1}

        ntt_kwargs = NoThrowTransform(; input_specification=SchemaAV1,
                                      output_specification=SchemaBV1,
                                      transform_fn)
        @test ntt == ntt_kwargs

        input_record = SchemaAV1(; foo="rabbit")
        result = transform!(ntt, input_record)
        @test nothrow_succeeded(result)
        @test result isa NoThrowResult{SchemaBV1}

        conforming_input_record = SchemaCV1(; foo="rad")
        @test !(conforming_input_record isa input_specification(ntt))
        result = transform!(ntt, conforming_input_record)
        @test nothrow_succeeded(result)

        result_unwrapped = transform_unwrapped!(ntt, conforming_input_record)
        @test isequal(result.result, result_unwrapped)

        result_unwrapped2 = transform_unwrapped(ntt, conforming_input_record)
        @test isequal(result.result, result_unwrapped)
        @test isequal(result_unwrapped, result_unwrapped2)
    end

    @testset "Nested `NoThrowResult` outputs collapse" begin
        ntt = NoThrowTransform(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
        ntt_nested = NoThrowTransform(SchemaAV1, NoThrowResult{SchemaBV1},
                                      _ -> NoThrowResult(SchemaBV1(; name="yay");
                                                         warnings="woohoo"))
        @test input_specification(ntt) == input_specification(ntt_nested)
        @test output_specification(ntt) == output_specification(ntt_nested) ==
              NoThrowResult{SchemaBV1}
        @test output_specification(ntt.transform_spec) == SchemaBV1
        @test output_specification(ntt_nested.transform_spec) == NoThrowResult{SchemaBV1}

        input_record = SchemaAV1(; foo="rabbit")
        result = transform!(ntt, input_record)
        result_nested = transform!(ntt_nested, input_record)
        @test isequal(result.result, result_nested.result)
        @test result_nested.warnings == ["woohoo"]

        result_unwrapped = transform_unwrapped!(ntt, input_record)
        @test result_unwrapped isa SchemaBV1
        result_nested_unwrapped = transform_unwrapped!(ntt_nested, input_record)
        @test result_nested_unwrapped isa NoThrowResult{SchemaBV1}
    end

    @testset "Nonconforming input fails" begin
        ntt = NoThrowTransform(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
        nonconforming_input_record = SchemaBV1(; name="rad")
        result = transform!(ntt, nonconforming_input_record)
        @test !nothrow_succeeded(result)
        @test startswith(only(result.violations),
                         "Input doesn't conform to specification `SchemaAV1`. Details: ")
        @test_throws ArgumentError transform_unwrapped!(ntt, nonconforming_input_record)
    end

    @testset "Nonconforming transform fails" begin
        input_record = SchemaAV1(; foo="rabbit")
        err = ErrorException("Oh no, an unexpected exception---if only we'd checked for it and returned a NoThrowResult{Missing} instead!")
        ntt_unexpected_throw = NoThrowTransform(SchemaAV1, SchemaBV1,
                                                _ -> throw(err))
        result = transform!(ntt_unexpected_throw, input_record)
        @test !nothrow_succeeded(result)
        @test isequal(only(result.violations),
                      "Unexpected violation. Details: $err")
        @test_throws ErrorException transform_unwrapped!(ntt_unexpected_throw, input_record)
    end

    @testset "Nonconforming output fails" begin
        input_record = SchemaAV1(; foo="rabbit")
        ntt_expected_throw = NoThrowTransform(SchemaAV1, SchemaAV1,
                                              _ -> SchemaBV1(; name="rad"))
        result = transform!(ntt_expected_throw, input_record)
        @test !nothrow_succeeded(result)
        @test isequal(only(result.violations),
                      "Output doesn't conform to specification `NoThrowResult{SchemaAV1}`; is instead a `NoThrowResult{SchemaBV1}`")
        @test_throws ErrorException transform_unwrapped!(ntt_expected_throw, input_record)

        ntt_nonconforming_out = NoThrowTransform(SchemaAV1, SchemaBV1,
                                                 input -> NoThrowResult(input))
        result = transform!(ntt_nonconforming_out, input_record)
        @test !nothrow_succeeded(result)
        @test isequal(only(result.violations),
                      "Output doesn't conform to specification `NoThrowResult{SchemaBV1}`; is instead a `NoThrowResult{SchemaAV1}`")
        @test_throws ErrorException transform_unwrapped!(ntt_nonconforming_out,
                                                         input_record)
    end

    @testset "Warnings forwarded" begin
        ntt_warn = NoThrowTransform(SchemaAV1, NoThrowResult{SchemaBV1},
                                    _ -> NoThrowResult(SchemaBV1(; name="yay");
                                                       warnings="Okay now..."))
        result = transform!(ntt_warn, SchemaAV1(; foo="rabbit"))
        @test nothrow_succeeded(result)
        @test result isa NoThrowResult{SchemaBV1}
        @test result.warnings == ["Okay now..."]

        result_unwrapped = transform_unwrapped!(ntt_warn, SchemaAV1(; foo="rabbit"))

        # For non-NoThrowResult output specs, we'd expect
        # isequal(result.result, result_unwrapped)---
        # but nested NoThrowResults are a special case, and since our transform's output
        # type here _is_ a NoThrowResult, we can test direct equality:
        @test isequal(result, result_unwrapped)
        @test result_unwrapped isa output_specification(ntt_warn.transform_spec)
    end

    @testset "Base extensions" begin
        # Test Base extensions
        fn = _ -> NoThrowResult(SchemaBV1(; name="yay"))
        @test NoThrowTransform(SchemaAV1, SchemaBV1, fn) ==
              NoThrowTransform(SchemaAV1, SchemaBV1,
                               fn)
        @test isequal(NoThrowTransform(SchemaAV1, SchemaBV1, fn),
                      NoThrowTransform(SchemaAV1, SchemaBV1, fn))
    end

    @testset "`transform` vs `transform!`" begin
        ntt = NoThrowTransform(SchemaAV1, SchemaAV1,
                               r -> begin
                                   push!(r.list, 122)
                                   return NoThrowResult(SchemaAV1(; foo="b"))
                               end)
        input_a = SchemaAV1(; foo="a")

        # Mutating
        input = SchemaAV1(; foo="rabbit")
        @test isequal(input.list, [33])
        result = transform!(ntt, input)
        @test isequal(input.list, [33, 122])

        # Non-mutating
        input = SchemaAV1(; foo="rabbit")
        @test isequal(input.list, [33])
        result = transform(ntt, input)
        @test isequal(input.list, [33])
    end

    @testset "Identity `NoThrowTransform`" begin
        using TransformSpecifications: identity_no_throw_result
        test_transform_fn(_) = NoThrowResult(SchemaBV1(; name="yay"))
        ntt_a = NoThrowTransform(SchemaAV1, SchemaBV1, test_transform_fn)
        @test !is_identity_no_throw_transform(ntt_a)
        @test_logs (:debug,
                    "Input and output schemas are not identical: NoThrowTransform{SchemaAV1,SchemaBV1}: `test_transform_fn`") min_level = Logging.Debug !is_identity_no_throw_transform(ntt_a)

        ntt_b = NoThrowTransform(SchemaBV1, SchemaBV1, test_transform_fn)
        @test !is_identity_no_throw_transform(ntt_b)
        @test @test_logs (:debug,
                          "`transform_fn` (`test_transform_fn`) is not `identity_no_throw_result`") min_level = Logging.Debug match_mode = :any !is_identity_no_throw_transform(ntt_b)

        ntt_c = NoThrowTransform(SchemaAV1)
        @test is_identity_no_throw_transform(ntt_c)

        ntt_d = NoThrowTransform(SchemaAV1, SchemaAV1, identity_no_throw_result)
        @test is_identity_no_throw_transform(ntt_d)
        @test isequal(ntt_c, ntt_d)

        @test isequal(NoThrowResult(SchemaAV1(; foo="yes")),
                      transform!(NoThrowTransform(SchemaAV1), SchemaAV1(; foo="yes")))
    end
end
