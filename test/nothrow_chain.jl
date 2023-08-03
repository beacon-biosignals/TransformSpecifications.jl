@schema "schema-a" SchemaA
@version SchemaAV1 begin
    foo::String
    list::Vector{Int} = [33]
end

@schema "schema-c" SchemaC
@version SchemaCV1 begin
    var1::String
    var2::String
end

@testset "`NoThrowTransformChain`" begin
    steps = [ChainStep("init", nothing,
                       NoThrowTransform(SchemaAV1, SchemaCV1,
                                        x -> SchemaCV1(; var1=x.foo * "_a",
                                                       var2=x.foo * "_a2"))),
             ChainStep("middle",
                       make_input_assembler(upstream_outputs -> (;
                                                                 foo=upstream_outputs["init"][:var1])),
                       NoThrowTransform(SchemaAV1, SchemaAV1,
                                        x -> SchemaAV1(; foo=x.foo * "_b"))),
             ChainStep("final",
                       make_input_assembler(upstream_outputs -> (;
                                                                 var1=upstream_outputs["a"][:foo],
                                                                 var2=upstream_outputs["b"][:foo]),
                                            NoThrowTransform(SchemaCV1, SchemaAV1,
                                                             x -> SchemaAV1(;
                                                                            foo=x.var1 *
                                                                                x.var2))))]
    chain = NoThrowTransformChain(steps)
    @test chain isa NoThrowTransformChain

    @testset "Internals" begin
        @test issetequal(keys(chain.step_input_constructors), keys(chain.step_transforms))
        @test issetequal(keys(chain.io_mapping), keys(chain.step_transforms))
        @test length(steps) == length(chain) == 3
    end

    @testset "Externals" begin
        @test chain isa AbstractTransformSpecification
        @test input_specification(chain) == SchemaAV1
        @test output_specification(chain) == NoThrowResult{SchemaAV1}
    end

    @testset "First step constructor must be `nothing`" begin
        ntt = NoThrowTransform(SchemaCV1)
        @test NoThrowTransformChain([ChainStep("a", ntt, nothing)]) isa
              NoThrowTransformChain
        err = ArgumentError("Initial step's input constructor must be `nothing` (`identity`)")
        @test_throws err NoThrowTransformChain([ChainStep("a",
                                                          ntt,
                                                          identity)])
    end

    @testset "Conforming input succeeds" begin
        input_record = SchemaAV1(; foo="rabbit")
        result = transform!(chain, input_record)
        @test nothrow_succeeded(result)
        @test result isa NoThrowResult{SchemaAV1}
        @test result.result.var1 == "rabbit_a"
        @test result.result.var2 == "rabbit_b"

        conforming_input_record = SchemaCV1(; foo="rad")
        @test !(conforming_input_record isa input_specification(ntt))
        result = transform!(ntt, conforming_input_record)
        @test nothrow_succeeded(result)

        result_unwrapped = transform_unwrapped!(ntt, conforming_input_record)
        @test isequal(result.result, result_unwrapped)
    end
end
