using Documenter, DocumenterVitepress

using RtemisA3

# Doctests run with the package loaded, so `RtemisA3.escape_token` resolves.
DocMeta.setdocmeta!(RtemisA3, :DocTestSetup, :(using RtemisA3); recursive = true)

makedocs(;
    modules = [RtemisA3],
    authors = "E.D. Gennatas",
    repo = Remotes.GitHub("rtemis-org", "a3"),
    sitename = "RtemisA3.jl",
    format = DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/rtemis-org/a3",
        devurl = "",
        deploy_url = "api/julia",
        deploy_decision = Documenter.DeployDecision(all_ok = true, subfolder = ""),
    ),
    pages = ["Home" => "index.md"],
    warnonly = false,
)
