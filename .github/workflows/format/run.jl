using JuliaFormatter

function main()
    paths = readdir(joinpath(@__DIR__, ".."))
    # a lot of these are pluto notebooks which should not be formatted
    filter!(!=("experiments"), paths)
    filter!(isdir, paths)

    perfect = format(paths; verbose=true)
    if perfect
        @info "Linting complete - no files altered"
    else
        @info "Linting complete - files altered"
        run(`git status`)
    end
    return nothing
end

main()
