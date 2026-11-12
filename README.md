[![CRAN status](https://www.r-pkg.org/badges/version/rtemis.a3)](https://CRAN.R-project.org/package=rtemis.a3) [![rtemis.a3 status badge](https://rtemis-org.r-universe.dev/rtemis.a3/badges/version)](https://rtemis-org.r-universe.dev/rtemis.a3) [![PyPI version](https://img.shields.io/pypi/v/rtemis_a3.svg)](https://pypi.org/project/rtemis_a3/) [![Julia](https://img.shields.io/badge/dynamic/toml?url=https://raw.githubusercontent.com/rtemis-org/a3/main/julia/RtemisA3/Project.toml&query=$.version&label=Julia&logo=julia&color=9558B2)](https://juliahub.com/ui/Packages/General/RtemisA3) [![npm version](https://img.shields.io/npm/v/@rtemis/a3.svg)](https://www.npmjs.com/package/@rtemis/a3) [![JSR](https://jsr.io/badges/@rtemis/a3)](https://jsr.io/@rtemis/a3) [![Crates.io Version](https://img.shields.io/crates/v/rtemis_a3)](https://crates.io/crates/rtemis_a3)

[![r-ci](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml) [![python-ci](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml) [![julia-ci](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml) [![typescript-ci](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml) [![rust-ci](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml) [![conformance](https://github.com/rtemis-org/a3/actions/workflows/conformance.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/conformance.yml)

# A3

A3 monorepo: specification and cross-language implementations of the Amino Acid Annotation format

[![rtemis a3 logo](https://www.rtemis.org/rtemis-a3-cover.avif)](https://a3.rtemis.org)

## Schema

[A3 JSON Schema](https://schema.rtemis.org/a3/v1/schema.json)

## Specification

The `spec/` directory holds the language-agnostic conformance contract that all five implementations are held to:

- [`spec/error-codes.md`](spec/error-codes.md): the rule registry — one stable code per validation rule, with its stage and the path it reports
- [`spec/error-paths.md`](spec/error-paths.md): the path grammar — every issue carries an RFC 6901 JSON Pointer to the offending value
- [`spec/conformance/`](spec/conformance/): the shared conformance corpus, read by all five implementations from one copy

Conformance is exact, not approximate. Given the same document, all five implementations report the same set of `{code, path}` pairs from the same validation stage — codes and JSON Pointer paths are contractual, message wording is not. Every implementation is run against the one shared corpus in CI on every change, so a divergence fails the build rather than surfacing later as a cross-language bug.

## Implementation

- `r/`: `rtemis.a3`
- `python/`: `rtemis.a3`
- `julia/`: `RtemisA3`
- `typescript/`: `@rtemis/a3`
- `rust/`: `rtemis_a3`

## Cross-language API

The five APIs are idiomatic per language and structurally identical: the same operations, the same arity, and the same return shapes.

| Operation | R | Python | TypeScript | Julia | Rust |
|---|---|---|---|---|---|
| Build from parts | `create_A3()` | `create_a3()` | `new A3()` | `create_a3()` | — |
| Parse JSON text | `read_A3json()` | `a3_from_json()` | `A3.fromJSONText()` | `a3_from_json()` | `a3_from_json()` |
| Validate, throwing | `read_A3json()` | `a3_from_json()` | `new A3()` | `A3()` | `validate()` |
| Validate, not throwing | `validate_A3json()` | `validate_a3()` | `validate()` | `validate()` | `validate()` |
| Read a file | `read_A3json()` | `read_a3json()` | `readJSON()` | `read_a3json()` | *(`a3` CLI)* |
| Write a file | `write_A3json()` | `write_a3json()` | `writeJSON()` | `write_a3json()` | *(`a3` CLI)* |
| Serialize to JSON | `write_A3json()` | `a3_to_json()` | `toJSONString()` | `a3_to_json()` | `a3_to_json()` |
| Residue at a position | `aa_sub()` helpers | `residue_at()` | `residueAt()` | `residue_at()` | `residue_at()` |
| Variants at a position | `x@annotations@variant` | `variants_at()` | `variantsAt()` | `variants_at()` | `variants_at()` |
| Issue list on failure | condition `issues` | `err.issues` | `err.issues` | `err.issues` | `err.issues()` |
| Issue stage | `issues[["stage"]]` | `err.stage` | `err.stage` | `stage(err)` | `err.stage()` |

Rust has no file helpers; the `a3` CLI covers that use. R's non-throwing entry point takes a path, and applies the `jsonlite` settings that R's parse step requires.

## Validation

Validation is **collect-all**: a document is checked in four stages, every issue in the earliest failing stage is reported at once, and each issue carries a stable code and an [RFC 6901](https://www.rfc-editor.org/info/rfc6901/) JSON Pointer. Codes and paths are identical across all five implementations; messages are not, and may be reworded freely.

```
[A3E_POS_OUT_OF_BOUNDS] /annotations/site/Active site/index/2:
  position 99 is out of bounds for a sequence of length 24 (must be 1-24)
```

Reading a **document** collects every issue; calling a **constructor** stops at the first issue with one corrective message ([`spec/README.md`](spec/README.md)).

## Development

Recipes are in the [`justfile`](justfile); `just --list` shows them all.

| | |
|---|---|
| `just test` | every suite in all five, reporting all five even when one fails |
| `just conformance` | the shared corpus against all five |
| `just corpus` | regenerate `spec/conformance/` from its generator |
| `just check` | everything CI runs |

Changing validation? Read [`spec/README.md`](spec/README.md) first — codes and paths are contractual, and a rule must land in all five at once.

Releases are manual and unautomated; the five packages carry different version numbers but ship from one commit, tagged once for the Zenodo DOI.

## Licensing

The five packages, the specification, the schema, and the conformance corpus are licensed BSD 3-Clause ([`LICENSE`](LICENSE)). The UniProtKB content in `examples/` is distributed by the UniProt Consortium under [CC BY 4.0](https://www.uniprot.org/help/license); the ClinVar records are from [NCBI ClinVar](https://www.ncbi.nlm.nih.gov/clinvar/).

## Visualization

[rtemislive-draw](https://draw.rtemis.org) provides support for interactive visualization of A3 data using the [@rtemis/a3](https://www.npmjs.com/package/@rtemis/a3) TypeScript implementation.

![a3 draw screenshot](https://www.rtemis.org/draw-a3.webp)