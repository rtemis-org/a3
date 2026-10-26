[![Julia](https://img.shields.io/badge/dynamic/toml?url=https://raw.githubusercontent.com/rtemis-org/a3/main/julia/RtemisA3/Project.toml&query=$.version&label=Julia&logo=julia&color=9558B2)](https://juliahub.com/ui/Packages/General/RtemisA3)
[![julia-ci](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml)

# RtemisA3 — Julia

Julia implementation of the
[A3 (Amino Acid Annotation) format](../schema/a3.schema.json).

## Installation

### From the registry

```julia
using Pkg
Pkg.add("RtemisA3")
```

### From GitHub

```julia
using Pkg
Pkg.add(url="https://github.com/rtemis-org/a3", subdir="julia/RtemisA3")
```

## Usage

```julia
using RtemisA3

# Construct an A3 object
a = create_a3(
    "MAEPRQEFEVMEDHAGTYGL";
    site = Dict(
        "catalyticResidues" => Dict("index" => [7, 14], "type" => "activeSite"),
    ),
    ptm = Dict(
        "Phosphorylation" => Dict("index" => [3, 9, 17], "type" => ""),
    ),
    region = Dict(
        "NtermDomain" => Dict("index" => [[1, 10]], "type" => ""),
    ),
    variant = [
        Dict("position" => 5, "from" => "Q", "to" => "K"),
    ],
    metadata = Dict(
        "uniprot_id"  => "P10636",
        "description" => "Microtubule-associated protein tau",
        "organism"    => "Homo sapiens",
    ),
)

# Serialize to JSON
json_str = a3_to_json(a; indent=2)

# Parse from JSON
b = a3_from_json(json_str)

# File I/O
write_a3json(a, "output.a3.json")
c = read_a3json("output.a3.json")

# Query
residue_at(a, 1)          # 'M'
variants_at(a, 5)         # Vector{VariantRecord}
```

## Data Model

| Field | Type | Description |
|---|---|---|
| `sequence` | `String` | Amino acid sequence (`[A-Z*]`, ≥ 2 chars) |
| `annotations.site` | `Dict{String,SiteEntry}` | Named sets of residue positions |
| `annotations.region` | `Dict{String,RegionEntry}` | Named sets of `[start,end]` ranges |
| `annotations.ptm` | `Dict{String,FlexEntry}` | PTMs (positions or ranges) |
| `annotations.processing` | `Dict{String,FlexEntry}` | Processing events (positions or ranges) |
| `annotations.variant` | `Vector{VariantRecord}` | Sequence variants |
| `metadata` | `A3Metadata` | `uniprot_id`, `description`, `reference`, `organism` |

## Validation

Validation is **collect-all**. A document is checked in four stages and every
issue in the earliest failing stage is reported at once:

1. **Envelope** — the document is an object and declares itself A3 1.0.0
2. **Structural** — types, shapes, required members, charset, annotation names
3. **Intra-field** — positions >= 1 and unique, ranges ordered and disjoint
4. **Contextual** — bounds against `length(sequence)`, variant `from` residue

Stages short-circuit: a stage runs only if every earlier stage produced no
issue. That is correctness, not optimization — a document whose `sequence`
failed Stage 2 has no known length, so Stage 4 would emit one spurious
out-of-bounds issue per annotated position.

Each issue carries a stable `code` and an
[RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer `path`, both of
which are identical across the R, Python, Julia, TypeScript, and Rust
implementations of A3. Messages are for humans and are not contractual.

```julia
using RtemisA3

try
    a3 = a3_from_json(text)
catch e
    e isa A3ValidationError || rethrow()
    println(stage(e))                    # 4
    for issue in e.issues
        println(issue.code, " ", issue.path)
        # A3E_POS_OUT_OF_BOUNDS /annotations/site/Active site/index/2
    end
end
```

`validate(raw)` is the non-throwing counterpart, returning
`(a3_or_nothing, issues)`. Reading a **document** collects every issue;
`create_a3` fails fast with one message. That split is deliberate: see
[`spec/README.md`](../spec/README.md).

## API Reference

| Function | Description |
|---|---|
| `create_a3(seq; ...)` | Construct and validate an A3 object |
| `a3_from_json(text)` | Parse from a JSON string |
| `a3_to_json(a3; indent)` | Serialize to a JSON string |
| `read_a3json(path)` | Read from a `.json` file |
| `write_a3json(a3, path; indent)` | Write to a `.json` file |
| `residue_at(a3, position)` | Return the residue at a 1-based position |
| `variants_at(a3, position)` | Return all variants at a 1-based position |

## Running Tests

```julia
using Pkg
Pkg.test("RtemisA3")
```
