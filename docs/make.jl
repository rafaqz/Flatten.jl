using Documenter, Flatten

makedocs(
    sitename = "Flatten.jl",
)

deploydocs(
    repo = "github.com/rafaqz/Flatten.jl.git",

    devbranch = "master",
    devurl = "dev",
    versions = ["stable" => "v^", "v#.#", devurl => devurl]
)
