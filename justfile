# justfile
# ::a3::
# 2026- EDG rtemis.org

r := env("R", "R")
rscript := env("RSCRIPT", "Rscript")
julia := env("JULIA", "julia")
cargo := env("CARGO", "cargo")
uv := env("UV", "uv")
pnpm := env("PNPM", "pnpm")

generator := "spec/conformance/generator/Cargo.toml"
r_tarball := "rtemis.a3_*.tar.gz"

# List available recipes
default:
    @just --list

_msg msg:
    @printf '\033[38;2;108;163;160m[%s] %s\033[0m\n' "$(date '+%Y-%m-%d %H:%M:%S')" "{{ msg }}"

# Print a per-language summary line
_report label code verb:
    @if [ "{{ code }}" = "0" ]; then \
        printf '  %-12s %s\n' "{{ label }}" "{{ verb }}"; \
    else \
        printf '  %-12s \033[31m%s\033[0m\n' "{{ label }}" "FAILED"; \
    fi

# ── Format ───────────────────────────────────────────────────────────────────

# Format every implementation
format: format-r format-python format-julia format-typescript format-rust

format-r:
    @just _msg "─── R: formatting rtemis.a3 ───"
    cd r && air format .

format-python:
    @just _msg "─── Python: formatting rtemis_a3 ───"
    cd python/rtemis_a3 && {{ uv }} run ruff format .

format-julia:
    @just _msg "─── Julia: formatting RtemisA3 ───"
    {{ julia }} --project=julia/__dev -m JuliaFormatter --inplace julia/RtemisA3

format-typescript:
    @just _msg "─── TypeScript: formatting @rtemis/a3 ───"
    cd typescript && {{ pnpm }} format:write

# Covers the crate and the corpus generator
format-rust:
    @just _msg "─── Rust: formatting rtemis-a3 ───"
    cd rust && {{ cargo }} fmt
    {{ cargo }} fmt --manifest-path {{ generator }}

# ── Lint ─────────────────────────────────────────────────────────────────────

# Lint every implementation
lint: lint-python lint-typescript lint-rust

lint-python:
    @just _msg "─── Python: linting and type-checking ───"
    cd python/rtemis_a3 && {{ uv }} run ruff check . && {{ uv }} run ty check

lint-typescript:
    @just _msg "─── TypeScript: biome check ───"
    cd typescript && {{ pnpm }} check

lint-rust:
    @just _msg "─── Rust: clippy ───"
    cd rust && {{ cargo }} clippy --all-targets -- -D warnings
    {{ cargo }} clippy --manifest-path {{ generator }} -- -D warnings

# ── Document ─────────────────────────────────────────────────────────────────

# Regenerate roxygen2 documentation
document:
    @just _msg "─── R: documenting rtemis.a3 ───"
    cd r && {{ rscript }} -e "devtools::document()"

# ── Docs sites ───────────────────────────────────────────────────────────────

docs-r:
    @just _msg "─── R: building pkgdown site ───"
    cd r && {{ rscript }} -e "pkgdown::build_site()"

docs-python:
    @just _msg "─── Python: building docs ───"
    cd python && bash build-docs.sh

docs-julia:
    @just _msg "─── Julia: building docs ───"
    cd julia && bash build-docs.sh

docs-typescript:
    @just _msg "─── TypeScript: building ───"
    cd typescript && {{ pnpm }} build

docs-rust:
    @just _msg "─── Rust: building docs ───"
    cd rust && bash build-docs.sh

# Build every docs site; reports all five even when one fails
docs:
    #!/usr/bin/env sh
    r=0; p=0; jl=0; ts=0; rs=0
    just docs-r          || r=1
    just docs-python     || p=1
    just docs-julia      || jl=1
    just docs-typescript || ts=1
    just docs-rust       || rs=1
    echo ""
    echo "── Docs ──────────────────────────────────────────────"
    just _report R          "$r"  built
    just _report Python     "$p"  built
    just _report Julia      "$jl" built
    just _report TypeScript "$ts" built
    just _report Rust       "$rs" built
    echo "─────────────────────────────────────────────────────"
    [ $((r + p + jl + ts + rs)) -eq 0 ]

# ── Install ──────────────────────────────────────────────────────────────────

install-r: document
    @just _msg "─── R: installing rtemis.a3 ───"
    cd r && {{ rscript }} -e "pak::local_install()"

# Install the `a3` CLI
install-rust:
    @just _msg "─── Rust: installing the a3 CLI ───"
    cd rust && {{ cargo }} install --path .

# ── Conformance corpus ───────────────────────────────────────────────────────
# One corpus, five readers. It is generated from a single program so that a case
# file and its manifest entry cannot disagree.

# Regenerate spec/conformance/ from the generator
corpus:
    @just _msg "─── Regenerating the conformance corpus ───"
    {{ cargo }} run --quiet --manifest-path {{ generator }}

# Fail if the committed corpus differs from what the generator produces
corpus-check: corpus
    @just _msg "─── Checking the committed corpus matches the generator ───"
    @git diff --exit-code --stat spec/conformance || { \
        echo "   Error: spec/conformance is out of date. Run 'just corpus' and commit."; \
        exit 1; \
    }

# Fail unless the JSON Schema accepts every valid case and rejects every
# invalid case except those that break only cross-field rules
schema-check:
    @just _msg "─── Checking the JSON Schema against the corpus ───"
    {{ uv }} run --quiet --no-project --with jsonschema python schema/check_corpus.py

# ── Test ─────────────────────────────────────────────────────────────────────

test-r:
    @just _msg "─── R: testing rtemis.a3 ───"
    cd r && {{ rscript }} -e "devtools::test(stop_on_failure = TRUE)"

test-python:
    @just _msg "─── Python: testing rtemis_a3 ───"
    cd python/rtemis_a3 && {{ uv }} run pytest

test-julia:
    @just _msg "─── Julia: testing RtemisA3 ───"
    cd julia/RtemisA3 && {{ julia }} --project=. -e "using Pkg; Pkg.test()"

test-typescript:
    @just _msg "─── TypeScript: testing @rtemis/a3 ───"
    cd typescript && {{ pnpm }} test

test-rust:
    @just _msg "─── Rust: testing rtemis-a3 ───"
    cd rust && {{ cargo }} test

# Run every test suite; reports all five even when one fails
test: corpus-check
    #!/usr/bin/env sh
    r=0; p=0; jl=0; ts=0; rs=0
    just test-r          || r=1
    just test-python     || p=1
    just test-julia      || jl=1
    just test-typescript || ts=1
    just test-rust       || rs=1
    echo ""
    echo "── Tests ─────────────────────────────────────────────"
    just _report R          "$r"  passed
    just _report Python     "$p"  passed
    just _report Julia      "$jl" passed
    just _report TypeScript "$ts" passed
    just _report Rust       "$rs" passed
    echo "─────────────────────────────────────────────────────"
    [ $((r + p + jl + ts + rs)) -eq 0 ]

# ── Conformance ──────────────────────────────────────────────────────────────
# Each runner resolves spec/conformance/ by relative path from the repo root.

conformance-r:
    @just _msg "─── R: conformance ───"
    cd r && {{ rscript }} -e "devtools::test(filter = 'conformance', stop_on_failure = TRUE)"

conformance-python:
    @just _msg "─── Python: conformance ───"
    cd python/rtemis_a3 && {{ uv }} run pytest tests/test_conformance.py

conformance-julia:
    @just _msg "─── Julia: conformance ───"
    cd julia/RtemisA3 && {{ julia }} --project=. -e "using Pkg; Pkg.test()"

conformance-typescript:
    @just _msg "─── TypeScript: conformance ───"
    cd typescript && npx vitest run tests/conformance.test.ts

conformance-rust:
    @just _msg "─── Rust: conformance ───"
    cd rust && {{ cargo }} test --test conformance

# Run the shared corpus against all five implementations
conformance: corpus-check schema-check
    #!/usr/bin/env sh
    r=0; p=0; jl=0; ts=0; rs=0
    just conformance-r          || r=1
    just conformance-python     || p=1
    just conformance-julia      || jl=1
    just conformance-typescript || ts=1
    just conformance-rust       || rs=1
    echo ""
    echo "── Conformance ───────────────────────────────────────"
    just _report R          "$r"  conforms
    just _report Python     "$p"  conforms
    just _report Julia      "$jl" conforms
    just _report TypeScript "$ts" conforms
    just _report Rust       "$rs" conforms
    echo "─────────────────────────────────────────────────────"
    [ $((r + p + jl + ts + rs)) -eq 0 ]

# ── Check ────────────────────────────────────────────────────────────────────

# Build the R source tarball
build-r: clean-r
    @just _msg "─── R: building rtemis.a3 ───"
    cd r && {{ r }} CMD build .

# Run R CMD check on the built tarball (pass extra flags, e.g. `just check-r --as-cran`)
check-r *flags: build-r
    @just _msg "─── R: R CMD check {{ flags }} ───"
    cd r && {{ r }} CMD check {{ r_tarball }} {{ flags }}
    @just clean-r

# A complete check needs every Suggests package installed, which is what CRAN
# does. If one is missing locally, prefix the call:
#     _R_CHECK_FORCE_SUGGESTS_=false just check-r-cran

# Run R CMD check --as-cran
check-r-cran: (check-r "--as-cran")

# A plain check does not catch a package used unconditionally from Suggests.
# This does, and it is the check that would have caught jsonlite sitting in
# Suggests with 13 unguarded call sites.

# Run R CMD check with Suggests unavailable
check-r-depends-only: build-r
    @just _msg "─── R: R CMD check with dependencies only ───"
    cd r && _R_CHECK_DEPENDS_ONLY_=true _R_CHECK_FORCE_SUGGESTS_=false \
        {{ r }} CMD check {{ r_tarball }}
    @just clean-r

# Everything CI runs, in one command
check: lint test conformance check-r-cran check-r-depends-only

# ── Clean ────────────────────────────────────────────────────────────────────

clean-r:
    @rm -rf r/rtemis.a3.Rcheck
    @rm -f r/{{ r_tarball }}

# Remove build artifacts across all five
clean: clean-r
    @just _msg "─── Cleaning build artifacts ───"
    @rm -rf spec/conformance/generator/target
    @cd rust && {{ cargo }} clean
