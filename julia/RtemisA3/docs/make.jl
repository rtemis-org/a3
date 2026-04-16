using Documenter, DocumenterVitepress

using RtemisA3

makedocs(;
    modules = [RtemisA3],
    authors = "E.D. Gennatas",
    repo = "https://github.com/rtemis-org/a3/julia/RtemisA3",
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

# DocumenterVitepress.deploydocs(;
#     repo="github.com/YourGithubUsername/RtemisA3.jl",
#     push_preview=true,
# )
