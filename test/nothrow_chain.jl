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

@testset "Basic `NoThrowTransformChain`" begin
    using TransformSpecifications: input_assembler

    steps = [ChainStep("init", nothing,
                       NoThrowTransform(SchemaFooV1, SchemaBarV1,
                                        x -> SchemaBarV1(; var1=x.foo * "_a",
                                                         var2=x.foo * "_a2"))),
             ChainStep("middle",
                       input_assembler(d -> (; foo=d["init"][:var1])),
                       NoThrowTransform(SchemaFooV1, SchemaFooV1,
                                        x -> SchemaFooV1(; foo=x.foo * "_b"))),
             ChainStep("final",
                       input_assembler(d -> (; var1=d["init"][:var2],
                                             var2=d["middle"][:foo])),
                       NoThrowTransform(SchemaBarV1, SchemaFooV1,
                                        x -> SchemaFooV1(;
                                                         foo=string(x.var1, "_WOW_",
                                                                    x.var2))))]
    chain = NoThrowTransformChain(steps)
    @test chain isa NoThrowTransformChain

    @testset "Internals" begin
        @test issetequal(keys(chain.step_input_assemblers), keys(chain.step_transforms))
        @test issetequal(keys(chain._step_output_fields), keys(chain.step_transforms))
        @test length(steps) == length(chain) == 3
        @test isequal(steps, map(i -> get_step(chain, i), 1:length(chain)))
        @test isequal(steps, map(n -> get_step(chain, n), [s.name for s in steps]))

        @test_throws KeyError get_step(chain, "nonexistent_step")
        @test_throws BoundsError get_step(chain, 15)
    end

    @testset "Externals" begin
        @test chain isa AbstractTransformSpecification
        @test input_specification(chain) == SchemaFooV1
        @test output_specification(chain) == NoThrowResult{SchemaFooV1}
    end

    @testset "Conforming input succeeds" begin
        input_record = SchemaFooV1(; foo="rabbit")
        chain_output = transform!(chain, input_record)
        @test nothrow_succeeded(chain_output)
        @test chain_output isa NoThrowResult{SchemaFooV1}
        @test chain_output.result.foo == "rabbit_a2_WOW_rabbit_a_b"

        conforming_input_record = SchemaFooChildV1(; foo="rabbit")
        @test !(conforming_input_record isa input_specification(chain))
        chain_output2 = transform!(chain, conforming_input_record)
        @test isequal(chain_output, chain_output2)
    end
end

@testset "Basics" begin
    step_a = ChainStep("init", nothing,
                       TransformSpecification(SchemaFooV1, SchemaFooV1, identity))
    step_b = ChainStep("init", nothing,
                       NoThrowTransform(SchemaFooV1, SchemaFooV1, identity))
    chain_a = NoThrowTransformChain(step_a)
    chain_b = NoThrowTransformChain(step_b)
    chain_c = NoThrowTransformChain([step_a])

    @test isequal(chain_a, chain_b)
    @test isequal(chain_a, chain_c)
    @test chain_a == chain_b == chain_c
end

@testset "Construction errors" begin
    using TransformSpecifications: input_assembler

    @test_throws ArgumentError("At least one step required to construct a chain") NoThrowTransformChain(ChainStep[])

    @testset "First step constructor must be `nothing`" begin
        ntt = NoThrowTransform(SchemaBarV1)
        @test NoThrowTransformChain([ChainStep("a", nothing, ntt)]) isa
              NoThrowTransformChain
        err = ArgumentError("Initial step's input constructor must be `nothing` (TransformSpecification{Dict{String, Any},NamedTuple}: `identity`)")
        @test_throws err NoThrowTransformChain([ChainStep("a", input_assembler(identity),
                                                          ntt)])
    end

    @testset "Invalid step combinations" begin
        ts = TransformSpecification(SchemaFooV1, SchemaFooV1, identity)
        err = ArgumentError("Key `foo` already exists in chain!")
        @test_throws err NoThrowTransformChain([ChainStep("foo", nothing, ts),
                                                ChainStep("foo", nothing, ts)])

        ch = [ChainStep("step1", nothing, ts),
              ChainStep("step2", input_assembler(d -> (; foo=d["x"])), ts)]
        @test_throws KeyError("x") NoThrowTransformChain(ch)

        ch = [ChainStep("step1", nothing, ts),
              ChainStep("step2", input_assembler(d -> (; foo=d["step1"][:x])), ts)]
        @test_throws KeyError(:x) NoThrowTransformChain(ch)

        # Can't wrap a broken test_throws BUT this should throw in the future,
        # when additional validation added!
        ch = [ChainStep("step1", nothing, ts),
              ChainStep("step2", input_assembler(d -> (; foo=d["step1"][:foo])), ts),
              ChainStep("step3", input_assembler(d -> (; foo=d["step1"][:foo])), ts)]
        err = ArgumentError("Input assembler for step `step3` cannot depend on `[step1][foo]`; output already used by step `step2`")
        @test_broken false # (@test_throws err NoThrowTransformChain(ch))
    end
end

@testset "Field maps" begin
    using TransformSpecifications: _field_map, construct_field_map
    @testset "`_field_map`" begin
        @test _field_map(String) == _field_map(NoThrowResult{String}) ==String
        @test _field_map(Dict) == _field_map(NoThrowResult{Dict}) ==Dict
        @info _field_map(SchemaFooV1) == _field_map(NoThrowResult{SchemaFooV1}) == SchemaFooV1
    end

    @testset "`construct_field_map`" begin
        @test construct_field_map(String) == Dict{Any, Any}()
        @test construct_field_map(Dict) isa Dict{Symbol, Type}
        @info construct_field_map(SchemaFooV1)
        @test construct_field_map(SchemaFooV1) == Dict{Symbol, DataType}(:list => Vector{Int64}, :foo => String))
    end

    @testset "Recurse into specification" begin
        orig = construct_field_map(TestTypeV1)
        @test orig == Dict(:schemafoo => SchemaFooV1, :str => String)

        # If we _want_ to be able to recurse into a specific specification type,
        # define an overloaded `_field_map` implementation of it:
        TransformSpecifications._field_map(t::Type{SchemaFooV1}) = construct_field_map(t)
        recursed = construct_field_map(TestTypeV1)
        @test recursed == Dict(:schemafoo => Dict(:list => Vector{Int64}, :foo => String),
                               :str => String)
    end
end
