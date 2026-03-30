# A3 Serde Specification

Amino Acid Annotation (A3) format — Rust/Serde implementation design.

## Requirements

- Strict canonical format only — no legacy input accommodation
- Runtime validation via hand-written two-stage validator
- Immutable value objects (all fields are private after construction; clone to modify)
- Serialize to JSON (top priority); TOML deferred
- 100% wire-format compatible with R, Python, and TypeScript implementations

## Tooling

- Package manager: Cargo
- Formatter / linter: `cargo fmt` / `cargo clippy`
- Test runner: `cargo test`
- Serialization: `serde = { version = "1", features = ["derive"] }` + `serde_json`
- Error types: `thiserror`

## Type Hierarchy

```
// Position type: u32 (1-based; 0 is rejected by validation)

// Annotation entry types
SiteEntry
  index: Vec<u32>           // sorted ascending, deduplicated
  kind:  String             // JSON key: "type" (reserved in Rust); default ""

RegionEntry
  index: Vec<[u32; 2]>     // [start, end] pairs, sorted by start, non-overlapping
  kind:  String

A3Index  (enum, #[serde(untagged)])
  Ranges(Vec<[u32; 2]>)    // tried first — more specific
  Positions(Vec<u32>)      // fallback

FlexEntry
  index: A3Index
  kind:  String

VariantRecord
  position: u32
  extra:    HashMap<String, serde_json::Value>   // #[serde(flatten)]

Annotations  (#[serde(default, deny_unknown_fields)])
  site:       HashMap<String, SiteEntry>
  region:     HashMap<String, RegionEntry>
  ptm:        HashMap<String, FlexEntry>
  processing: HashMap<String, FlexEntry>
  variant:    Vec<VariantRecord>

Metadata  (#[serde(default, deny_unknown_fields)])
  uniprot_id:  String   // default ""
  description: String   // default ""
  reference:   String   // default ""
  organism:    String   // default ""

A3  (#[serde(deny_unknown_fields)])
  sequence:    String
  annotations: Annotations   // #[serde(default)]
  metadata:    Metadata      // #[serde(default)]
```

## Type Details

### `SiteEntry`

- `index`: normalized by `normalize_positions` — sorted ascending, deduplicated, all values ≥ 1.
- `kind`: field name for the JSON `"type"` key (`#[serde(rename = "type", default)]`).
  `String::default()` is `""`, so absent `"type"` keys deserialize to `""`.

### `RegionEntry`

- `index`: normalized by `normalize_ranges` — each pair satisfies `start < end`, sorted by
  start (then end for ties), no overlapping pairs.

### `A3Index`

- `#[serde(untagged)]`: serde tries `Ranges` first (requires array-of-arrays), then
  `Positions` (array of integers). Union order is significant.
- Named `A3Index` (not `FlexIndex`) to match cross-language naming convention.
- Matched with `match entry.index { A3Index::Positions(p) => ..., A3Index::Ranges(r) => ... }`.

### `VariantRecord`

- `position` is a named field; all other JSON keys are absorbed by
  `#[serde(flatten)] extra: HashMap<String, serde_json::Value>`.
- `serde_json::Value` can represent any valid JSON value — functions, symbols, and
  class instances cannot appear in JSON and are therefore structurally excluded.

### `Annotations`

- `#[serde(deny_unknown_fields)]` rejects any key other than the five families.
- `#[serde(default)]` + `#[derive(Default)]` fills all fields with empty collections
  when `annotations` is absent from the top-level JSON.

### `Metadata`

- `#[serde(deny_unknown_fields)]` rejects unknown metadata keys.
- All four fields default to `""` via `#[serde(default)]` + `String::default()`.

### `A3`

- `#[serde(deny_unknown_fields)]` rejects unknown top-level keys.
- `annotations` and `metadata` use `#[serde(default)]` so they may be omitted from input.

## Normalization Helpers (`normalize.rs`)

Pure functions returning `Result<T, String>`. The `field` parameter carries the
dot-separated JSON path used in error messages (e.g. `"annotations.site.catalytic"`).

```rust
normalize_positions(positions: Vec<u32>, field: &str) -> Result<Vec<u32>, String>
// 1. Reject any position == 0 (positions are 1-based)
// 2. Sort ascending (sort_unstable)
// 3. Remove consecutive duplicates (dedup)

normalize_ranges(ranges: Vec<[u32; 2]>, field: &str) -> Result<Vec<[u32; 2]>, String>
// 1. Reject any endpoint == 0
// 2. Reject any range where start >= end
// 3. Sort by start, then end for ties (sort_unstable_by)
// 4. Reject overlapping pairs: overlap when ranges[i+1][0] <= ranges[i][1]

normalize_sequence(sequence: &str) -> Result<String, String>
// 1. Uppercase the input (to_uppercase)
// 2. Reject if length < 2
// 3. Reject any character not in [A-Z*]
```

## Public API (`lib.rs`)

```rust
// Parse a JSON string into a validated, normalized A3.
// Composes serde_json::from_str (structural) + validate (A3 rules).
// The ? operator propagates serde_json::Error → A3Error::Parse automatically.
a3_from_json(text: &str) -> Result<A3, A3Error>

// Serialize a validated A3 to JSON.
// indent: None  → compact (serde_json::to_string)
//         Some(n) → n-space indented (PrettyFormatter::with_indent)
a3_to_json(a3: &A3, indent: Option<usize>) -> Result<String, A3Error>

// Return the amino acid character at a 1-based position.
// Returns None if position == 0 or > sequence length.
residue_at(a3: &A3, position: u32) -> Option<char>

// Return references to all variant records at a 1-based position.
// Lifetime 'a ties the returned references to the lifetime of the A3 input.
variants_at<'a>(a3: &'a A3, position: u32) -> Vec<&'a VariantRecord>
```

## Error Types (`error.rs`)

```rust
#[derive(Debug, thiserror::Error)]
pub enum A3Error {
    // Wraps serde_json::Error. #[from] enables automatic conversion via ?.
    #[error("Failed to parse JSON: {0}")]
    Parse(#[from] serde_json::Error),

    // Collects all validation violations before returning.
    #[error("A3 validation failed:\n{0:#?}")]
    Validate(Vec<String>),
}
```

## Validation (`validate.rs`)

### Stage 1 — Structural

`validate(raw: A3) -> Result<A3, A3Error>` iterates every field:

- `sequence`: calls `normalize_sequence`; carries a placeholder on failure so Stage 2 can run
- `site` entries: checks non-empty name, calls `normalize_positions`
- `region` entries: checks non-empty name, calls `normalize_ranges`
- `ptm` / `processing` entries: `normalize_flex_family` helper matches on `A3Index` variant
  and dispatches to the appropriate normalizer
- `variant` records: checks `position != 0`

Two mutable closures both capturing `&mut errors` are rejected by the borrow checker
(only one mutable borrow of a binding may be live at a time). Use standalone functions
that take `errors: &mut Vec<String>` as an explicit parameter instead.

### Stage 2 — Contextual

Runs after all normalization, on the fully resolved data:

- `check_positions_bounds(positions, seq_len, field, errors)` — each position ≤ seq_len
- `check_ranges_bounds(ranges, seq_len, field, errors)` — each end endpoint ≤ seq_len
  (start is guaranteed ≤ end by Stage 1, so only end needs checking)
- Variant positions: checked inline

Error messages follow the pattern:
`"annotations.site.bad: position 100 is out of bounds for sequence of length 6 (must be 1–6)"`

## File Structure

```
rust/
  Cargo.toml
  src/
    lib.rs        // module declarations, public API, re-exports
    error.rs      // A3Error enum
    types.rs      // A3, Annotations, Metadata, SiteEntry, RegionEntry,
                  // FlexEntry, A3Index, VariantRecord
    normalize.rs  // normalize_positions, normalize_ranges, normalize_sequence
    validate.rs   // validate, normalize_flex_family,
                  // check_positions_bounds, check_ranges_bounds
```

## Wire Format

Strict canonical format. Unknown keys are rejected at all levels. The `"type"` field
is always present in output (defaults to `""`):

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

`serde_json::to_string` / `serde_json::Serializer` with `PrettyFormatter` produce
this format. `[u32; 2]` arrays serialize as JSON arrays, preserving wire-format
compatibility across all A3 implementations.
