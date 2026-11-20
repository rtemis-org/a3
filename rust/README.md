[![Crates.io Version](https://img.shields.io/crates/v/rtemis-a3)](https://crates.io/crates/rtemis-a3) [![rust-ci](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/rust-ci.yml)

# rtemis-a3

Rust implementation of the **Amino Acid Annotation (A3)** format, a JSON format for an amino acid sequence with site, region, PTM, processing, and variant annotations.

- Canonical JSON Schema: [`https://schema.rtemis.org/a3/v1/schema.json`](https://schema.rtemis.org/a3/v1/schema.json) (source: [`schema/a3.schema.json`](https://github.com/rtemis-org/a3/blob/main/schema/a3.schema.json))
- Conformance contract: [`spec/`](https://github.com/rtemis-org/a3/tree/main/spec)
- Monorepo, with the R, Python, Julia, and TypeScript implementations: [rtemis-org/a3](https://github.com/rtemis-org/a3)

> [!NOTE]
> The Rust source carries extensive comments, written as an introduction to Rust.

## Installation

Add to `Cargo.toml`:

```toml
[dependencies]
rtemis-a3 = "0.3"
```

The crate is `rtemis-a3`, the library is imported as `rtemis_a3`, and the binary is `a3`.

## CLI

The `a3` binary validates an A3 JSON file and prints a summary.

**Install from crates.io:**

```sh
cargo install rtemis-a3
```

**Usage:**

```sh
a3 [OPTIONS] <FILE>
```

Pass `-` as `<FILE>` to read from stdin.

**Options:**

| Flag              | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `-l, --limit <N>` | Maximum sequence residues to display (default: 20)   |
| `-q, --quiet`     | Suppress all output; report through the exit code    |
| `-j, --json`      | Output the result as JSON                            |
| `-h, --help`      | Print help                                           |
| `-V, --version`   | Print version                                        |

**Example: a valid file**

```
$ a3 examples/mapt.a3.json

  ✓ valid A3 1.0.0 https://schema.rtemis.org/a3/v1/schema.json

  Sequence  MAEPRQEFEVMEDHAGTYGL… (length = 441)

  Annotations
  ├── site        6  (AT8 epitope, AT100 epitope, AT180 epitope…)
  ├── region      6  (R1, R2, R3…)
  ├── ptm         8  (Phosphorylation, Acetylation, Methylation…)
  ├── processing  3  (Initiator methionine, Caspase cleavage, AEP cleavage)
  └── variant     34  (pos 5, pos 5, pos 17…)

  Metadata
  ├── UniProt ID   P10636-8
  ├── Description  Microtubule-associated protein tau, isoform 2N4R (UniProtKB isoform
  │                Tau-F; RefSeq NP_005901.2)
  ├── Reference    UniProtKB P10636 release 2026_04; ClinVar, retrieved 2026-11-12;
  │                epitope literature and full provenance:
  │                https://github.com/rtemis-org/a3/blob/main/examples/mapt/mapt.provenance.json
  └── Organism     Homo sapiens
```

**Example: an invalid file**

```
$ a3 bad.a3.json

  ✗ invalid  1 issue(s) at stage 4 (contextual)

  └── A3E_POS_OUT_OF_BOUNDS  /annotations/site/AT8 epitope/index/2
       position 9999 is out of bounds for a sequence of length 441 (must be 1-441)
```

**Exit codes:**

| Code | Meaning                                                    |
| ---- | ---------------------------------------------------------- |
| `0`  | Valid                                                      |
| `1`  | Invalid (A3 validation issues)                             |
| `2`  | Error (bad arguments, file not found, JSON parse failure)  |

`--quiet` serves scripts:

```sh
if a3 -q protein.a3.json; then
  echo "valid"
fi
```

With `--json`, the CLI reports the same `{code, path}` pairs as every other implementation, and serves as a reference when debugging another implementation:

```console
$ a3 --json bad.a3.json
{
  "valid": false,
  "stage": 4,
  "issues": [
    {
      "code": "A3E_POS_OUT_OF_BOUNDS",
      "path": "/annotations/site/AT8 epitope/index/2",
      "message": "position 9999 is out of bounds for a sequence of length 441 (must be 1-441)"
    }
  ]
}
```

## Usage

```rust
use rtemis_a3::{a3_from_json, a3_to_json};

let json = r#"{
  "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
  "a3_version": "1.0.0",
  "sequence": "MKTAYIAKQR",
  "annotations": {
    "site":       { "Active site":     { "index": [3, 5],   "type": "activeSite" } },
    "region":     { "Repeat 1":        { "index": [[1, 4]], "type": "" } },
    "ptm":        { "Phosphorylation": { "index": [7],      "type": "" } },
    "processing": {},
    "variant":    [{ "position": 3, "from": "T", "to": "A" }]
  },
  "metadata": {
    "uniprot_id":  "P12345",
    "description": "Example protein",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}"#;

let a3 = a3_from_json(json).unwrap();

println!("{}", a3.sequence().len());                // 10
println!("{}", a3_to_json(&a3, None).unwrap());     // compact JSON
println!("{}", a3_to_json(&a3, Some(2)).unwrap());  // pretty-printed
```

## Parsing JSON

```rust
use rtemis_a3::{a3_from_json, A3Error};

match a3_from_json(json_string) {
    Ok(a3) => { /* use a3 */ }
    Err(A3Error::Parse(e)) => eprintln!("Malformed JSON: {e}"),
    Err(A3Error::Validate(issues)) => {
        for issue in &issues {
            eprintln!("{issue}");
        }
    }
    Err(e) => eprintln!("{e}"),
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

## Document format

- `$schema`, `a3_version`, and `sequence` are required. `a3_version` is `"1.0.0"`.
- `sequence` is a string of at least two characters from `[A-Za-z*]`, stored in uppercase.
- `annotations` and `metadata` are optional. Every annotation family and every metadata member defaults to empty, and serialized output contains all of them.
- Each `site`, `region`, `ptm`, and `processing` entry is an object with an `index` and an optional `type` string, which defaults to `""`. A `site` index is a list of positions, a `region` index is a list of ranges, and a `ptm` or `processing` index is either, never both.
- Positions are 1-based integers. They are sorted ascending on read; a duplicate position is an error.
- A range is an inclusive `[start, end]` pair with `start < end`. Ranges are sorted by start on read; overlapping ranges are an error.
- A variant record requires `position`. Its other members are free-form JSON values and are preserved verbatim. A single-character `from` must equal the residue at `position`.
- Metadata members are free-text strings.

Package versions and `a3_version` are independent. This crate reads and writes A3 format version 1.0.0.

## Validation

Validation is **collect-all**. A document is checked in four stages (envelope, structural, intra-field, contextual), and every issue in the earliest failing stage is reported at once. A later stage runs only when every earlier stage produced no issue. Each issue carries a stable `code` and an [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer `path`; both are identical across the R, Python, Julia, TypeScript, and Rust implementations of A3. The `message` is human-readable text and is not part of the contract. The rule registry is [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md).

```rust
use rtemis_a3::a3_from_json;

let err = a3_from_json(text).unwrap_err();
assert_eq!(err.stage(), Some(4));
for issue in err.issues() {
    println!("{} {}", issue.code, issue.path);
    // A3E_POS_OUT_OF_BOUNDS /annotations/site/Active site/index/2
}
```

`validate(&serde_json::Value)` validates a parsed value and returns `Result<A3, Vec<A3Issue>>`.

## API

### Functions

| Function                                     | Description                                                       |
| -------------------------------------------- | ----------------------------------------------------------------- |
| `a3_from_json(text: &str)`                   | Parses and validates a JSON string; returns `Result<A3, A3Error>` |
| `validate(root: &Value)`                     | Validates a parsed value; returns `Result<A3, Vec<A3Issue>>`      |
| `a3_to_json(a3: &A3, indent: Option<usize>)` | Serializes to JSON; `None` = compact, `Some(n)` = n-space indent  |
| `residue_at(a3: &A3, position: u32)`         | Residue at a 1-based position; `None` when out of bounds          |
| `variants_at(a3: &A3, position: u32)`        | Every variant record at a 1-based position                        |

### Type hierarchy

```
A3                 sequence(), annotations(), metadata()
 ├── sequence:    String
 ├── annotations: Annotations
 │   ├── site:        IndexMap<String, SiteEntry>   (position index)
 │   ├── region:      IndexMap<String, RegionEntry> (range index)
 │   ├── ptm:         IndexMap<String, FlexEntry>   (position or range index)
 │   ├── processing:  IndexMap<String, FlexEntry>   (position or range index)
 │   └── variant:     Vec<VariantRecord>
 └── metadata:    Metadata
     └── uniprot_id, description, reference, organism: String
```

Named maps preserve the document's order of annotation names. `A3Index` is an enum that holds either `Positions(Vec<u32>)` or `Ranges(Vec<[u32; 2]>)`, the index type of `FlexEntry`. `A3_SCHEMA_URI` and `A3_VERSION` are the envelope constants.

### Errors and issues

```rust
pub enum A3Error {
    Parse(serde_json::Error),      // the text is not JSON
    Serialize(serde_json::Error),  // serialization failure
    Validate(Vec<A3Issue>),        // every issue in the earliest failing stage
}
```

`A3Error::issues()` returns the issues of a `Validate` error, and `A3Error::stage()` their stage. An `A3Issue` has the fields `code` (`A3IssueCode`), `path`, and `message`, and the method `stage()`.

## License

[BSD 3-Clause](https://github.com/rtemis-org/a3/blob/main/rust/LICENSE)
