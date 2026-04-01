# A3 CLI tool

Rust binary that validates an `a3.json` file and outputs info.

## Usage

```
a3 [OPTIONS] <FILE>
```

Pass `-` as `<FILE>` to read from stdin.

## Human-readable output (default)

```
✓ valid A3 schema version 1.0.0 (https://schema.rtemis.org/a3/v1/schema.json)
UniProt ID:   P10636
Description:  Microtubule-associated protein tau
Reference:
Organism:     Homo sapiens
Sequence:     MAEPRQEFEV... (758)
Annotations:  site: 2  region: 1  ptm: 3  processing: 0  variant: 5
```

Or on failure:

```
✗ invalid:
  - annotations.site.foo: position 999 is out of bounds for sequence of length 6 (must be 1–6)
  - annotations.region: annotation name must not be empty
```

- Sequence preview shows the first `min(l, sequence_length)` residues, with total length in parentheses.
- All errors are listed (not just the first).

## JSON output (`-j, --json`)

```json
{
  "valid": true,
  "errors": [],
  "metadata": {
    "uniprot_id": "P10636",
    "description": "Microtubule-associated protein tau",
    "reference": "",
    "organism": "Homo sapiens"
  },
  "sequence_length": 758,
  "sequence_preview": "MAEPRQEFEV",
  "annotations": {
    "site": 2,
    "region": 1,
    "ptm": 3,
    "processing": 0,
    "variant": 5
  }
}
```

When `valid` is `false`, `errors` contains one string per violation. All other
fields are populated from whatever was parseable. If the file cannot be read or
is not valid JSON, `errors` contains the I/O or parse error and the remaining
fields are absent.

## Options

- `<FILE>`: Path to the `.json` file to validate. Use `-` for stdin.
- `-l, --limit <NUMBER>`: Limit the number of sequence residues displayed (default: 10)
- `-q, --quiet`: Suppress all output; use exit code only
- `-j, --json`: Output results in JSON format
- `-h, --help`: Print help information
- `-V, --version`: Print version information

## Exit codes

| Code | Meaning                                              |
|------|------------------------------------------------------|
| 0    | File is valid                                        |
| 1    | File is invalid (one or more A3 validation errors)   |
| 2    | Error (bad arguments, file not found, I/O, JSON parse failure) |

`clap` emits exit code 2 for argument errors automatically. I/O and parse
failures also exit 2 so callers can distinguish "invalid A3" from "tool could
not run."
