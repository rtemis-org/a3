# A3 CLI tool

Rust binary that validates an `a3.json` file and outputs info.

## Usage

```
a3 [OPTIONS] <FILE>
```

Pass `-` as `<FILE>` to read from stdin.

## Human-readable output (default)

Output mirrors the schema structure: sequence → annotations → metadata.

```
  ✓ valid  A3 1.0.0  https://schema.rtemis.org/a3/v1/schema.json

  Sequence  MAEPRQEFEVMEDHAGTYGL… (length = 441)

  Annotations
  ├── site        2
  ├── region      1
  ├── ptm         3
  ├── processing  0
  └── variant     5

  Metadata
  ├── UniProt ID     P10636
  ├── Description    Microtubule-associated protein tau
  ├── Reference      
  └── Organism       Homo sapiens
```

On failure, errors are listed first (with tree connectors), followed by
whatever metadata and stats are available from the partial parse:

```
✗ invalid

  ├── annotations.site.foo: position 999 is out of bounds for sequence of length 6 (must be 1–6)
  └── annotations.region: annotation name must not be empty

  Sequence  MAEPRQ (length = 6)
  ...
```

- Sequence preview shows the first `min(l, sequence_length)` residues.
- All errors are collected and listed before returning (not just the first).

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
- `-l, --limit <NUMBER>`: Limit the number of sequence residues displayed (default: 20)
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

## Styling

- `✓ valid` — bold green; `✗ invalid` — bold red; status line indented like all other output
- Schema name and version (`A3 1.0.0`) — cyan; URL — dimmed
- Errors — red
- `Sequence`, `Annotations`, `Metadata` section headers — bold
- Annotation and metadata field names — dimmed
- All values (sequence, counts, metadata) — rgb(220, 150, 86)
- Empty metadata values rendered as dimmed `—`
- Colors disabled automatically when stdout is not a terminal (`NO_COLOR` respected)