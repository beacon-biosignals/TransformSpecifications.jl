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
    DocMeta.setdocmeta!(TransformSpecifications, :DocTestSetup, :(using TransformSpecifications);
                        recursive=true)
end
