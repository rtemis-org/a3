# A3 Julia Specification

Amino Acid Annotation (A3) format — Julia implementation design.

## Requirements

- Strict canonical format only — no legacy input accommodation
- Runtime validation via hand-written validators (no external schema library)
- Immutable value objects (`struct`, not `mutable struct`)
- Serialize to JSON via `JSON.jl`; TOML deferred
- User-facing API is functional — users never call struct constructors directly
- 100% wire-format compatible with R, TypeScript, and Python implementations

## Tooling

- Package manager: `Pkg.jl`
- Test runner: `Test` (stdlib)
- JSON: `JSON.jl ^0.21`

## Type Hierarchy

```julia
struct A3Metadata
    uniprot_id::String   # default ""
    description::String  # default ""
    reference::String    # default ""
    organism::String     # default ""
end

struct SiteEntry
    index::Vector{Int}               # sorted positions; duplicates rejected
    type::String                     # default ""
end

struct RegionEntry
    index::Vector{Tuple{Int,Int}}    # sorted, overlap-checked ranges
    type::String                     # default ""
end

struct FlexEntry
    index::Union{Vector{Int}, Vector{Tuple{Int,Int}}}  # geometry inferred from first element
    type::String                     # default ""
end

struct VariantRecord
    position::Int
    extra::Dict{String,Any}          # open extra fields, JSON-compatible values only
end

struct A3Annotations
    site::Dict{String,SiteEntry}
    region::Dict{String,RegionEntry}
    ptm::Dict{String,FlexEntry}
    processing::Dict{String,FlexEntry}
    variant::Vector{VariantRecord}
end

struct A3
    sequence::String
    annotations::A3Annotations
    metadata::A3Metadata
end
```

All structs are immutable (Julia default). `Base.:(==)` is explicitly defined for
all entry types because Julia's default `==` for structs with mutable fields
(`Vector`, `Dict`) falls back to identity (`===`).

## Struct Details

### `SiteEntry`

- `index`: validated by `validate_positions` — checks all elements are positive integers,
  sorts ascending, then rejects any duplicate (throws `A3ValidationError`).
- `type`: string, defaults to `""`.

### `RegionEntry`

- `index`: validated by `validate_ranges` — checks each element is a 2-element
  vector of positive integers with `start < end`, sorts via `sort_ranges()`, then
  calls `check_no_overlap()`.
- `type`: string, defaults to `""`.

### `FlexEntry`

- `index`: validated by `validate_flex_index` — infers geometry from the first
  element:
  - First element is `AbstractVector` → ranges path (same checks as `RegionEntry`)
  - First element is an integer → positions path (same checks as `SiteEntry`)
  - Empty array → returned as `Vector{Int}()`
  - Mixed geometry is rejected by the type system.

### `VariantRecord`

- `position`: required positive integer.
- `extra`: all keys from the raw dict except `"position"`, validated by
  `is_json_compatible()`. Functions, closures, and other non-JSON types are rejected.

### `A3Annotations`

- Unknown annotation families are rejected at parse time.
- Empty families default to empty `Dict` / `Vector` when absent from input.
- All annotation names (dict keys) must be non-empty strings.

### `A3Metadata`

- Unknown metadata fields are rejected at parse time.
- All four fields default to `""`.

### `A3`

- Unknown top-level keys are rejected at parse time.
- `sequence` is validated by `validate_sequence`:
  - Must be a string, ≥ 2 characters
  - Characters must match `[A-Za-z*]` — normalized to uppercase
- Stage 2 bounds check (`validate_bounds`) runs after structural validation.

## Normalization Helpers (`normalize.jl`)

Pure functions used inside validators:

```julia
sort_dedup(v::Vector{Int}) -> Vector{Int}
# Deduplicate and sort ascending: sort(unique(v)).
# Utility for a future lenient/clean API — not called by validators.

sort_ranges(v::Vector{Tuple{Int,Int}}) -> Vector{Tuple{Int,Int}}
# Sort by start, then end for ties. No merging.

check_no_overlap(ranges::Vector{Tuple{Int,Int}}, path::String) -> nothing
# Throws A3ValidationError if any consecutive pair overlaps (curr_start <= prev_end).
# Adjacent ranges (curr_start = prev_end + 1) are permitted.

is_json_compatible(v) -> Bool
# Accepts: nothing (null), Bool, Number, AbstractString, AbstractVector, AbstractDict
#          (with AbstractString keys).
# Rejects: functions, closures, other Julia objects.
```

## Validation (`validate.jl`)

All parsing and validation is performed by hand-written functions. Two stages:

### Stage 1 — Structural

Entry point is `A3(raw::AbstractDict)` (outer constructor):

- Rejects unknown top-level keys
- Calls `validate_sequence`, `parse_annotations`, `parse_metadata`
- `parse_annotations` / `parse_metadata` reject unknown keys and delegate to
  entry-level parsers (`parse_site_entry`, `parse_region_entry`,
  `parse_flex_entry`, `parse_variant`)
- Entry parsers call `_parse_entry_base` which rejects bare arrays and unknown
  entry-level keys (only `"index"` and `"type"` are allowed)

### Stage 2 — Contextual

`validate_bounds(seq, annotations)` runs after all structural validation:

- All `site` positions satisfy `1 <= pos <= length(seq)`
- All `region` range endpoints satisfy the same
- All `ptm` and `processing` positions and range endpoints satisfy the same
- All `variant` positions satisfy the same

Error messages include the full field path and concrete bounds, e.g.:
`"annotations.site.bad.index[1]: position 100 is out of bounds for sequence of length 6 (must be 1-6)"`.

## Public API (`api.jl`)

Users never construct structs directly. All entry points are plain functions:

```julia
create_a3(
    sequence;
    site       = nothing,
    region     = nothing,
    ptm        = nothing,
    processing = nothing,
    variant    = nothing,
    metadata   = nothing,
) -> A3
# Build and validate an A3 from raw Dict/Array components (wire format).
# Throws A3ValidationError on invalid input.

residue_at(a3::A3, position::Int) -> Char
# Return the residue at a 1-based position.
# Throws BoundsError if out of bounds.

variants_at(a3::A3, position::Int) -> Vector{VariantRecord}
# Return all variant records at a 1-based position.
```

## Serialization and I/O (`io.jl`)

```julia
to_dict(a3::A3) -> Dict{String,Any}
# Convert to a plain nested Dict matching the wire format.
# Tuple{Int,Int} ranges are converted to Vector{Int} for JSON serialization.

a3_from_json(text::AbstractString) -> A3
# Parse a JSON string into an A3 object.
# Throws A3ParseError on malformed JSON.
# Throws A3ValidationError on schema violations.

a3_to_json(a3::A3; indent::Union{Int,Nothing}=nothing) -> String
# Serialize an A3 to a canonical JSON string.

read_a3json(path::AbstractString) -> A3
# Read and parse an A3 JSON file from disk.
# Throws A3ParseError on I/O or parse failure.

write_a3json(a3::A3, path::AbstractString; indent::Int=2)
# Write an A3 object to a JSON file on disk.
```

## Error Types (`errors.jl`)

```julia
struct A3ValidationError <: Exception
    msg::String
end

struct A3ParseError <: Exception
    msg::String
end
```

`A3ValidationError` is thrown for schema violations (invalid structure, out-of-bounds
positions, unknown fields). `A3ParseError` is thrown for malformed JSON and file I/O
errors. Both implement `Base.showerror` for readable output.

## File Structure

```
julia/RtemisA3/
  src/
    RtemisA3.jl    # module entry: using, include, export
    errors.jl      # A3ValidationError, A3ParseError
    types.jl       # struct definitions + Base.:(==) methods
    normalize.jl   # sort_dedup, sort_ranges, check_no_overlap, is_json_compatible
    validate.jl    # parsing, validation, A3(::AbstractDict) outer constructor
    io.jl          # to_dict, a3_to_json, a3_from_json, read/write_a3json
    api.jl         # create_a3, residue_at, variants_at
  test/
    runtests.jl
  Project.toml
```

## Wire Format

Strict canonical format. Unknown keys are rejected at all levels. All five annotation
families are always present in serialized output, even when empty. The `type` field
is always present (defaults to `""`):

```json
{
  "sequence": "MAEPRQ...",
  "annotations": {
    "site": {
      "Disease_associated_variant": { "index": [4, 5, 14], "type": "" },
      "catalyticResidues":          { "index": [57, 102],  "type": "activeSite" }
    },
    "region": {
      "KXGS": { "index": [[259, 262], [290, 293]], "type": "" }
    },
    "ptm": {
      "Phosphorylation": { "index": [17, 18, 29], "type": "" }
    },
    "processing": {},
    "variant": [
      { "position": 301, "from": "P", "to": "L" }
    ]
  },
  "metadata": {
    "uniprot_id":  "P10636",
    "description": "Microtubule-associated protein tau",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

`to_dict` produces this structure. `Vector{Tuple{Int,Int}}` ranges are converted
to `Vector{Vector{Int}}` so `JSON.json` serializes them as arrays of arrays.
