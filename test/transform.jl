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

@testset "`transform!`" begin
    @testset "Conforming input succeeds" begin
        ts = TransformSpecification(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
        @test input_specification(ts) == SchemaAV1
        @test output_specification(ts) == SchemaBV1

        input_record = SchemaAV1(; foo="rabbit")
        result = transform!(ts, input_record)
        @test result isa SchemaBV1

        conforming_input_record = SchemaCV1(; foo="rad")
        @test !(conforming_input_record isa input_specification(ts))
        result = transform!(ts, conforming_input_record)
        @test result isa SchemaBV1
    end

    @testset "Nonconforming input fails" begin
        ts = TransformSpecification(SchemaAV1, SchemaBV1, _ -> SchemaBV1(; name="yay"))
        nonconforming_input_record = SchemaBV1(; name="rad")
        @test_throws ArgumentError("Input doesn't conform to specification `SchemaAV1`") transform!(ts,
                                                                                                    nonconforming_input_record)
    end

    @testset "Nonconforming transform fails" begin
        input_record = SchemaAV1(; foo="rabbit")
        err_msg = "Oh no, an unexpected exception!"
        ts_unexpected_throw = TransformSpecification(SchemaAV1, SchemaBV1,
                                                     _ -> throw(ErrorException(err_msg)))
        @test_throws ErrorException(err_msg) transform!(ts_unexpected_throw, input_record)
    end

    @testset "Nonconforming output fails" begin
        input_record = SchemaAV1(; foo="rabbit")
        ts_expected_throw = TransformSpecification(SchemaAV1, SchemaAV1,
                                                   _ -> SchemaBV1(; name="rad"))
        @test_throws ErrorException("Output doesn't conform to specification `SchemaAV1`; is instead a `SchemaBV1`") transform!(ts_expected_throw,
                                                                                                                                input_record)
    end

    @testset "Base extensions" begin
        # Test Base extensions
        fn = _ -> NoThrowResult(SchemaBV1(; name="yay"))
        @test TransformSpecification(SchemaAV1, SchemaBV1, fn) ==
              TransformSpecification(SchemaAV1, SchemaBV1,
                                     fn)
        @test isequal(TransformSpecification(SchemaAV1, SchemaBV1, fn),
                      TransformSpecification(SchemaAV1, SchemaBV1, fn))
    end
end

@testset "`interpret_input`" begin
    using TransformSpecifications: interpret_input
    for (type, input, output) in [(Int, 3, 3), (Int, 3.0, 3),
                                  (SchemaCV1, SchemaAV1(; foo="whee"), SchemaCV1(; foo="whee"))]
        x = interpret_input(type, input)
        @test x isa type
        @test isequal(x, output)
    end

    let
        input = SchemaAV1(; foo="yay")
        push!(input.list, 21)
        @test interpret_input(SchemaAV1, input) === input
    end

    let
        input = [3, 4, 5]
        @test interpret_input(Vector{Int}, input) === input
    end

    @test_throws InexactError interpret_input(Int, 2.4)
    @test_throws ArgumentError interpret_input(SchemaAV1, SchemaBV1(; name="rad"))
    @test_throws ArgumentError interpret_input(SchemaAV1, SchemaBV1(; name="rad"))
end

@testset "`transform` vs `transform!`" begin
    ts = TransformSpecification(SchemaAV1, SchemaAV1,
                                r -> begin
                                    push!(r.list, 122)
                                    return SchemaAV1(; foo="b")
                                end)
    input_a = SchemaAV1(; foo="a")

    # Mutating
    input = SchemaAV1(; foo="rabbit")
    @test isequal(input.list, [33])
    result = transform!(ts, input)
    @test isequal(input.list, [33, 122])

    # Non-mutating
    input = SchemaAV1(; foo="rabbit")
    @test isequal(input.list, [33])
    result = transform(ts, input)
    @test isequal(input.list, [33])
end
