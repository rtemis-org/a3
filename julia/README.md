[![Julia](https://img.shields.io/badge/dynamic/toml?url=https://raw.githubusercontent.com/rtemis-org/a3/main/julia/RtemisA3/Project.toml&query=$.version&label=Julia&logo=julia&color=9558B2)](https://juliahub.com/ui/Packages/General/RtemisA3) [![julia-ci](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/julia-ci.yml)

# RtemisA3

Julia implementation of the **Amino Acid Annotation (A3)** format, a JSON format for an amino acid sequence with site, region, PTM, processing, and variant annotations.

- Canonical JSON Schema: [`https://schema.rtemis.org/a3/v1/schema.json`](https://schema.rtemis.org/a3/v1/schema.json) (source: [`schema/a3.schema.json`](https://github.com/rtemis-org/a3/blob/main/schema/a3.schema.json))
- Conformance contract: [`spec/`](https://github.com/rtemis-org/a3/tree/main/spec)
- Monorepo, with the R, Python, TypeScript, and Rust implementations: [rtemis-org/a3](https://github.com/rtemis-org/a3)

## Installation

### From the General registry

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
        Dict("position" => 6, "from" => "Q", "to" => "K"),
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
variants_at(a, 6)         # Vector{VariantRecord}
```

`create_a3` adds `$schema` and `a3_version` to the document it builds.

## Data model

| Field | Type | Description |
|---|---|---|
| `sequence` | `String` | Amino acid sequence, uppercase, at least 2 characters from `[A-Z*]` |
| `annotations.site` | `OrderedDict{String,A3Position}` | Named sets of residue positions |
| `annotations.region` | `OrderedDict{String,A3Range}` | Named sets of `(start, end)` ranges |
| `annotations.ptm` | `OrderedDict{String,A3Index}` | PTMs: an `A3Position` or an `A3Range` |
| `annotations.processing` | `OrderedDict{String,A3Index}` | Processing events: an `A3Position` or an `A3Range` |
| `annotations.variant` | `Vector{VariantRecord}` | Variant records: `position` and the record's other members, in `extra` |
| `metadata` | `A3Metadata` | `uniprot_id`, `description`, `reference`, `organism` |

Named maps preserve the document's order of annotation names.

## Document format

- `$schema`, `a3_version`, and `sequence` are required in a document. `a3_version` is `"1.0.0"`.
- `sequence` is a string of at least two characters from `[A-Za-z*]`, stored in uppercase.
- `annotations` and `metadata` are optional. Every annotation family and every metadata member defaults to empty, and serialized output contains all of them.
- Each `site`, `region`, `ptm`, and `processing` entry is an object with an `index` and an optional `type` string, which defaults to `""`. A `site` index is a list of positions, a `region` index is a list of ranges, and a `ptm` or `processing` index is either, never both.
- Positions are 1-based integers. They are sorted ascending on read; a duplicate position is an error.
- A range is an inclusive `[start, end]` pair with `start < end`. Ranges are sorted by start on read; overlapping ranges are an error.
- A variant record requires `position`. Its other members are free-form JSON values and are preserved verbatim. A single-character `from` must equal the residue at `position`.
- Metadata members are free-text strings.

Package versions and `a3_version` are independent. This package reads and writes A3 format version 1.0.0.

## Validation

Validation is **collect-all**. A document is checked in four stages, and every issue in the earliest failing stage is reported at once:

1. **Envelope**: the document is an object and declares itself A3 1.0.0.
2. **Structural**: types, shapes, required members, charset, and annotation names.
3. **Intra-field**: positions are at least 1 and unique; ranges are ordered and disjoint.
4. **Contextual**: bounds against `length(sequence)`, and the variant `from` residue.

A stage runs only if every earlier stage produced no issue. A document whose `sequence` fails Stage 2 has no known length, so Stage 4 does not run on it.

Each issue carries a stable `code` and an [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer `path`; both are identical across the R, Python, Julia, TypeScript, and Rust implementations of A3. The `message` is human-readable text and is not part of the contract. The rule registry is [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md).

`a3_from_json`, `read_a3json`, `A3(raw::AbstractDict)`, and `create_a3` throw an `A3ValidationError` that carries every issue of the failing stage:

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

`validate(raw)` is the non-throwing entry point. It returns `(a3, issues)`: the `A3` object and an empty vector, or `nothing` and every issue of the failing stage.

## API reference

| Function | Description |
|---|---|
| `create_a3(sequence; site, region, ptm, processing, variant, metadata)` | Builds and validates an `A3` object from its parts |
| `A3(raw::AbstractDict)` | Validates a parsed JSON object |
| `validate(raw)` | Validates a parsed JSON value without throwing; returns `(a3_or_nothing, issues)` |
| `a3_from_json(text)` | Parses and validates a JSON string |
| `a3_to_json(a3; indent=nothing)` | Serializes to a JSON string; `indent=nothing` gives compact output |
| `read_a3json(path)` | Reads and validates a file |
| `write_a3json(a3, path; indent=2)` | Writes `a3_to_json(a3; indent)` to a file |
| `residue_at(a3, position)` | Residue at a 1-based position, as a `Char`; throws `BoundsError` when out of bounds |
| `variants_at(a3, position)` | Every variant record at a 1-based position |
| `stage(issue)`, `stage(err)` | The validation stage of an `A3Issue`, or of the issues in an `A3ValidationError` |

| Name | Description |
|---|---|
| `A3ValidationError` | `issues`: every issue in the earliest failing stage |
| `A3ParseError` | The input could not be parsed or read before validation |
| `A3Issue` | One issue: `code`, `path`, `message` |
| `A3_ISSUE_CODES`, `A3_ISSUE_STAGES` | The codes of the rule registry, and the stage of each |

## Running tests

```julia
using Pkg
Pkg.test("RtemisA3")
```

## License

[BSD 3-Clause](https://github.com/rtemis-org/a3/blob/main/julia/RtemisA3/LICENSE)
