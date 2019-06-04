using Documenter, Flatten

makedocs(
    checkdocs = :all,
    modules = [Flatten],
    sitename = "Flatten.jl",
    format = Documenter.HTML(),
    highlightsig = true,
    pages = Any[
        "Flatten" => "index.md",
    ]
)

deploydocs(
    repo = "github.com/rafaqz/Flaten.jl.git",
    osname = "linux",
    julia = "1.0",
    target = "build",
    deps = nothing,
    make = nothing
)
