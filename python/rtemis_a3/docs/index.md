# rtemis-a3

Python implementation of the **Amino Acid Annotation (A3)** format —
a structured JSON format for amino acid sequences with site, region, PTM,
processing, and variant annotations.

Part of the [rtemis-org/a3](https://github.com/rtemis-org/a3) monorepo,
which provides A3 implementations in Python, TypeScript, R, Julia, and Rust.

## Installation

```bash
pip install rtemis-a3
# or with uv
uv add rtemis-a3
```

## Quick Start

```python
from rtemis.a3 import create_a3

a3 = create_a3(
    "MKTAYIAKQR",
    site={
        "Active site": {"index": [3, 5], "type": "activeSite"},
    },
    region={
        "Repeat 1": {"index": [[1, 4]], "type": ""},
    },
    ptm={
        "Phosphorylation": {"index": [7], "type": ""},
    },
    variant=[{"position": 3, "from": "K", "to": "R"}],
    metadata={
        "uniprot_id":  "P12345",
        "description": "Example protein",
        "organism":    "Homo sapiens",
    },
)

len(a3.sequence)   # 10
```

## Parsing JSON

```python
from rtemis.a3 import a3_from_json, A3ValidationError, A3ParseError

try:
    a3 = a3_from_json(json_string)
except A3ValidationError as e:
    print(e.errors)  # list of Pydantic error dicts with field paths
except A3ParseError as e:
    print(e)         # malformed JSON
```

## File I/O

```python
from rtemis.a3 import read_a3json, write_a3json

a3 = read_a3json("protein.json")
write_a3json(a3, "output.json", indent=2)
```

## Serialization

```python
from rtemis.a3 import a3_to_json

json_string = a3_to_json(a3)           # compact
json_string = a3_to_json(a3, indent=2) # pretty-printed
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

## Canonical Schema

See the [A3 specification](https://github.com/rtemis-org/a3/blob/main/specs/A3.md)
for the language-agnostic schema definition.
