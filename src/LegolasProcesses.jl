"""
    LegolasProcesses

This package enables structured processing elements via [Legolas](https://github.com/beacon-biosignals/Legolas.jl)-defined
I/O schemas.
"""
module LegolasProcesses

using Legolas
using Legolas: @schema, @version
using OrderedCollections

include("processes.jl")
export AbstractLegolasProcess, apply!, input_schema, output_schema, LegolasProcessResult,
       LegolasProcess, LegolasProcessChain, process_succeeded, identity_legolas_process,
       is_identity_process, AbstractProcessChainStep

end
