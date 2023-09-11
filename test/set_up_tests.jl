using TransformSpecifications
using Aqua
using Documenter
using Legolas: @schema, @version
using TransformSpecifications
using Logging
using OrderedCollections
using Test

# For doctests
if !isdefined(TransformSpecifications, :META) # avoids annoying warning if this has already been run once
    DocMeta.setdocmeta!(TransformSpecifications, :DocTestSetup,
                        :(using TransformSpecifications); recursive=true)
end

# For `test/mermaid.jl`
module A
struct X end
end

function test_equals_reference(test_str::String, ref_path)
    ref_str = read(ref_path, String)
    @test isequal(ref_str, test_str)
    return nothing
end

update_reference!(test_str, ref_path) = write(ref_path, test_str)
