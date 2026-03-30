[![julia-ci](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml)

# RtemisA3 — Julia

Julia implementation of the [A3 (Amino Acid Annotation) format](../specs/a3.md).

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/rtemis-org/a3", subdir="julia/RtemisA3")
```

Or from a local clone:

```julia
Pkg.develop(path="julia/RtemisA3")
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

All inputs are validated in two stages:

1. **Structural** — types, non-empty names, `start < end` for ranges, no overlapping ranges, sequence characters
2. **Contextual** — all positions/ranges within `1..length(sequence)`

Errors raise `A3ValidationError` with a message that includes the field path and a concrete description of the violation.

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

## Canonical Schema

See [specs/a3.md](../specs/a3.md) for the full language-agnostic specification.
