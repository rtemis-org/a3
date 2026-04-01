[![rust-ci](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml)

# rtemis-a3

Rust implementation of the **Amino Acid Annotation (A3)** format —
a structured JSON format for amino acid sequences with site, region, PTM,
processing, and variant annotations.

Part of the [rtemis-org/a3](https://github.com/rtemis-org/a3) monorepo,
which provides A3 implementations in Python, TypeScript, R, Julia, and Rust.

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
rtemis-a3 = "0.1"
```

## CLI

The `a3` binary validates an A3 JSON file and prints a summary.

**Install:**

```sh
cargo install --path .
```

**Usage:**

```sh
a3 [OPTIONS] <FILE>
```

Pass `-` as `<FILE>` to read from stdin.

**Options:**

| Flag | Description |
|---|---|
| `-l, --limit <N>` | Max sequence residues to display (default: 10) |
| `-q, --quiet` | Suppress all output; use exit code only |
| `-j, --json` | Output results in JSON format |
| `-h, --help` | Print help |
| `-V, --version` | Print version |

**Example — valid file:**

```
$ a3 tau.json
✓ valid A3 schema version 1.0.0 (https://schema.rtemis.org/a3/v1/schema.json)
UniProt ID:   P10636
Description:  Microtubule-associated protein tau
Reference:
Organism:     Homo sapiens
Sequence:     MAEPRQEFEV... (758)
Annotations:  site: 2  region: 1  ptm: 3  processing: 0  variant: 5
```

**Example — invalid file:**

```
$ a3 bad.json
✗ invalid:
  - annotations.site.foo: position 999 is out of bounds for sequence of length 6 (must be 1–6)
UniProt ID:   P10636
...
```

**Exit codes:**

| Code | Meaning |
|---|---|
| `0` | Valid |
| `1` | Invalid (A3 validation errors) |
| `2` | Error (bad arguments, file not found, JSON parse failure) |

Use `--quiet` for scripting:

```sh
if a3 -q protein.json; then
  echo "valid"
fi
```

## Quick Start

```rust
use rtemis_a3::{a3_from_json, a3_to_json};

let json = r#"{
  "sequence": "MKTAYIAKQR",
  "annotations": {
    "site":       { "Active site": { "index": [3, 5], "type": "activeSite" } },
    "region":     { "Repeat 1":    { "index": [[1, 4]], "type": "" } },
    "ptm":        { "Phospho":     { "index": [7], "type": "" } },
    "processing": {},
    "variant":    [{ "position": 3, "from": "K", "to": "R" }]
  },
  "metadata": {
    "uniprot_id":  "P12345",
    "description": "Example protein",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}"#;

let a3 = a3_from_json(json).unwrap();

println!("{}", a3.sequence.len());        // 10
println!("{}", a3_to_json(&a3, None).unwrap());         // compact JSON
println!("{}", a3_to_json(&a3, Some(2)).unwrap());      // pretty-printed
```

## Parsing JSON

```rust
use rtemis_a3::{a3_from_json, A3Error};

match a3_from_json(json_string) {
    Ok(a3)                      => { /* use a3 */ }
    Err(A3Error::Parse(e))      => eprintln!("Malformed JSON: {e}"),
    Err(A3Error::Validate(errs)) => {
        for msg in errs {
            eprintln!("{msg}");
        }
    }
}
```

## Querying

```rust
use rtemis_a3::{residue_at, variants_at};

// 1-based position; returns Option<char>
if let Some(aa) = residue_at(&a3, 3) {
    println!("Residue at position 3: {aa}");
}

// All variant records at a position
let vars = variants_at(&a3, 3);
```

## Wire Format

```json
{
  "sequence": "MKTAYIAKQR",
  "annotations": {
    "site":       { "Active site": { "index": [3, 5],   "type": "activeSite" } },
    "region":     { "Repeat 1":    { "index": [[1, 4]], "type": "" } },
    "ptm":        { "Phospho":     { "index": [7],      "type": "" } },
    "processing": {},
    "variant":    [{ "position": 3, "from": "K", "to": "R" }]
  },
  "metadata": {
    "uniprot_id":  "P12345",
    "description": "Example protein",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

All five annotation families are always present in output. Each annotation
entry is `{ index, type }` — bare arrays are rejected. Positions are
1-based, sorted, and deduplicated. Ranges are `[start, end]` pairs
(`start < end`), sorted by start; overlapping ranges are rejected.

## API

### Parsing and serialization

| Function | Description |
|---|---|
| `a3_from_json(text: &str)` | Parse a JSON string into a validated `A3` |
| `a3_to_json(a3: &A3, indent: Option<usize>)` | Serialize to JSON; `None` = compact, `Some(n)` = n-space indent |

### Queries

| Function | Description |
|---|---|
| `residue_at(a3: &A3, position: u32)` | Residue at a 1-based position; `None` if out of bounds |
| `variants_at<'a>(a3: &'a A3, position: u32)` | All variant records at a 1-based position |

### Type hierarchy

```
A3
 ├── sequence:    String
 ├── annotations: Annotations
 │   ├── site:        HashMap<String, SiteEntry>   (position index)
 │   ├── region:      HashMap<String, RegionEntry> (range index)
 │   ├── ptm:         HashMap<String, FlexEntry>   (position or range index)
 │   ├── processing:  HashMap<String, FlexEntry>   (position or range index)
 │   └── variant:     Vec<VariantRecord>
 └── metadata:    Metadata
     ├── uniprot_id, description, reference, organism: String
```

`A3Index` is an enum that holds either `Positions(Vec<u32>)` or `Ranges(Vec<[u32; 2]>)`,
used as the index type inside `FlexEntry`.

### Errors

```rust
pub enum A3Error {
    Parse(serde_json::Error),   // malformed JSON
    Validate(Vec<String>),      // all A3 rule violations, collected before returning
}
```

All violations are collected before returning — you see every problem at once,
not just the first one.

## Canonical Schema

See [specs/a3.md](../specs/a3.md) for the language-agnostic specification and
[specs/A3_Rust.md](../specs/A3_Rust.md) for Rust/serde-specific design notes.

## License

[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/)
