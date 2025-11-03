using Documenter
using Philote

makedocs(;
    modules=[Philote],
    authors="Christopher Lupp",
    repo="https://github.com/chrislupp/Philote-Julia/blob/{commit}{path}#{line}",
    sitename="Philote.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chrislupp.github.io/Philote-Julia",
        assets=String[],
        edit_link="main",
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => [
            "MDO Concepts" => "concepts.md",
            "Tutorial" => "tutorial.md",
        ],
        "User Guide" => [
            "Explicit Disciplines" => "explicit_disciplines.md",
            "Implicit Disciplines" => "implicit_disciplines.md",
            "Integration with Philote-Python" => "integration.md",
        ],
        "API Reference" => "api.md",
    ],
    checkdocs=:none,  # Don't check for missing docstrings
)

deploydocs(;
    repo="github.com/chrislupp/Philote-Julia",
    devbranch="main",
)
