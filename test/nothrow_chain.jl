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

@testset "`NoThrowTransformChain`" begin
    ntt = identity_no_throw_transform(SchemaAV1)
    steps = [ChainStep("a", ntt, nothing), ChainStep("b", ntt, identity), ChainStep("c", ntt, identity), ]
    chain = NoThrowTransformChain(steps)
    @test chain isa NoThrowTransformChain


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

    #     @testset "Conforming input succeeds" begin
    #         ntt = NoThrowTransform(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
    #         @test input_specification(ntt) == SchemaAV1
    #         @test output_specification(ntt) == NoThrowResult{SchemaBV1}

    #         input_record = SchemaAV1(; foo="rabbit")
    #         result = transform!(ntt, input_record)
    #         @test nothrow_succeeded(result)
    #         @test result isa NoThrowResult{SchemaBV1}

    #         conforming_input_record = SchemaCV1(; foo="rad")
    #         @test !(conforming_input_record isa input_specification(ntt))
    #         result = transform!(ntt, conforming_input_record)
    #         @test nothrow_succeeded(result)

    #         result_unwrapped = transform_unwrapped!(ntt, conforming_input_record)
    #         @test isequal(result.result, result_unwrapped)
    #     end

    #     @testset "Nested `NoThrowResult` outputs collapse" begin
    #         ntt = NoThrowTransform(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
    #         ntt_nested = NoThrowTransform(SchemaAV1, NoThrowResult{SchemaBV1}, _ -> NoThrowResult(SchemaBV1(; name="yay"); warnings="woohoo"))
    #         @test input_specification(ntt) == input_specification(ntt_nested)
    #         @test output_specification(ntt) == output_specification(ntt_nested) == NoThrowResult{SchemaBV1}
    #         @test output_specification(ntt.transform_spec) == SchemaBV1
    #         @test output_specification(ntt_nested.transform_spec) ==  NoThrowResult{SchemaBV1}

    #         input_record = SchemaAV1(; foo="rabbit")
    #         result = transform!(ntt, input_record)
    #         result_nested = transform!(ntt_nested, input_record)
    #         @test isequal(result.result, result_nested.result)
    #         @test result_nested.warnings == ["woohoo"]

    #         result_unwrapped = transform_unwrapped!(ntt, input_record)
    #         @test result_unwrapped isa SchemaBV1
    #         result_nested_unwrapped = transform_unwrapped!(ntt_nested, input_record)
    #         @test result_nested_unwrapped isa NoThrowResult{SchemaBV1}
    #     end

    #     @testset "Nonconforming input fails" begin
    #         ntt = NoThrowTransform(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
    #         nonconforming_input_record = SchemaBV1(; name="rad")
    #         result = transform!(ntt, nonconforming_input_record)
    #         @test !nothrow_succeeded(result)
    #         @test isequal(only(result.violations),
    #                       "Input doesn't conform to specification `SchemaAV1`. Details: ArgumentError(\"Invalid value set for field `foo`, expected String, got a value of type Missing (missing)\")")
    #         @test_throws ArgumentError transform_unwrapped!(ntt, nonconforming_input_record)
    #     end

    #     @testset "Nonconforming transform fails" begin
    #         input_record = SchemaAV1(; foo="rabbit")
    #         ntt_unexpected_throw = NoThrowTransform(SchemaAV1, SchemaBV1,
    #                                                 _ -> throw(ErrorException("Oh no, an unexpected exception---if only we'd checked for it and returned a NoThrowResult{Missing} instead!")))
    #         result = transform!(ntt_unexpected_throw, input_record)
    #         @test !nothrow_succeeded(result)
    #         @test isequal(only(result.violations),
    #         "Unexpected violation: ErrorException(\"Oh no, an unexpected exception---if only we'd checked for it and returned a NoThrowResult{Missing} instead!\")")
    #         @test_throws ErrorException transform_unwrapped!(ntt_unexpected_throw, input_record)
    #     end

    #     @testset "Nonconforming ouptut fails" begin
    #         input_record = SchemaAV1(; foo="rabbit")
    #         ntt_expected_throw = NoThrowTransform(SchemaAV1, SchemaAV1,
    #                                               _ -> SchemaBV1(; name="rad"))
    #         result = transform!(ntt_expected_throw, input_record)
    #         @test !nothrow_succeeded(result)
    #         @test isequal(only(result.violations),
    #                       "Output doesn't conform to specification `NoThrowResult{SchemaAV1}`; is instead a `NoThrowResult{SchemaBV1}`")
    #         @test_throws ErrorException transform_unwrapped!(ntt_expected_throw, input_record)

    #         ntt_nonconforming_out = NoThrowTransform(SchemaAV1, SchemaBV1,
    #                                                  input -> NoThrowResult(input))
    #         result = transform!(ntt_nonconforming_out, input_record)
    #         @test !nothrow_succeeded(result)
    #         @test isequal(only(result.violations),
    #                       "Output doesn't conform to specification `NoThrowResult{SchemaBV1}`; is instead a `NoThrowResult{SchemaAV1}`")
    #         @test_throws ErrorException transform_unwrapped!(ntt_nonconforming_out, input_record)
    #     end

    #     @testset "Warnings forwarded" begin
    #         ntt_warn = NoThrowTransform(SchemaAV1, NoThrowResult{SchemaBV1},
    #                                     _ -> NoThrowResult(SchemaBV1(; name="yay");
    #                                                        warnings="Okay now..."))
    #         result = transform!(ntt_warn, SchemaAV1(; foo="rabbit"))
    #         @test nothrow_succeeded(result)
    #         @test result isa NoThrowResult{SchemaBV1}
    #         @test result.warnings == ["Okay now..."]

    #         result_unwrapped = transform_unwrapped!(ntt_warn, SchemaAV1(; foo="rabbit"))

    #         # For non-NoThrowResult output specs, we'd expect
    #         # isequal(result.result, result_unwrapped)---
    #         # but nested NoThrowResults are a special case, and since our transform's output
    #         # type here _is_ a NoThrowResult, we can test direct equality:
    #         @test isequal(result, result_unwrapped)
    #         @test result_unwrapped isa output_specification(ntt_warn.transform_spec)
    #     end

    #     @testset "Base extensions" begin
    #         # Test Base extensions
    #         fn = _ -> NoThrowResult(SchemaBV1(; name="yay"))
    #         @test NoThrowTransform(SchemaAV1, SchemaBV1, fn) ==
    #               NoThrowTransform(SchemaAV1, SchemaBV1,
    #                                fn)
    #         @test isequal(NoThrowTransform(SchemaAV1, SchemaBV1, fn),
    #                       NoThrowTransform(SchemaAV1, SchemaBV1, fn))
    #     end
    # end

    # @testset "`transform` vs `transform!`" begin
    #     ntt = NoThrowTransform(SchemaAV1, SchemaAV1,
    #                            r -> begin
    #                                push!(r.list, 122)
    #                                return NoThrowResult(SchemaAV1(; foo="b"))
    #                            end)
    #     input_a = SchemaAV1(; foo="a")

    #     # Mutating
    #     input = SchemaAV1(; foo="rabbit")
    #     @test isequal(input.list, [33])
    #     result = transform!(ntt, input)
    #     @test isequal(input.list, [33, 122])

    #     # Non-mutating
    #     input = SchemaAV1(; foo="rabbit")
    #     @test isequal(input.list, [33])
    #     result = transform(ntt, input)
    #     @test isequal(input.list, [33])
    # end

    # @testset "`identity_no_throw_transform`" begin
    #     test_transform_fn(_) = NoThrowResult(SchemaBV1(; name="yay"))
    #     ntt_a = NoThrowTransform(SchemaAV1, SchemaBV1, test_transform_fn)
    #     @test !is_identity_no_throw_transform(ntt_a)
    #     @test_logs (:debug,
    #                 "Input and output schemas are not identical: NoThrowTransform{SchemaAV1,SchemaBV1}: `test_transform_fn`") min_level = Logging.Debug !is_identity_no_throw_transform(ntt_a)

    #     ntt_b = NoThrowTransform(SchemaBV1, SchemaBV1, test_transform_fn)
    #     @test !is_identity_no_throw_transform(ntt_b)
    #     @test @test_logs (:debug,
    #                       "`transform_fn` (`test_transform_fn`) is not `identity_no_throw_result`") min_level = Logging.Debug match_mode = :any !is_identity_no_throw_transform(ntt_b)

    #     ntt_c = identity_no_throw_transform(SchemaAV1)
    #     @test is_identity_no_throw_transform(ntt_c)

    #     ntt_d = NoThrowTransform(SchemaAV1, SchemaAV1,
    #                              TransformSpecifications.identity_no_throw_result)
    #     @test is_identity_no_throw_transform(ntt_d)
    # end

end
