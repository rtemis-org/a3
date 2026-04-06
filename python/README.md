[![python-ci](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml)

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

## API

### Construction

| Function | Description |
|---|---|
| `create_a3(sequence, *, site, region, ptm, processing, variant, metadata)` | Build and validate an A3 object |

### Queries

| Function | Description |
|---|---|
| `residue_at(a3, position)` | Residue at a 1-based position; raises `ValueError` if out of bounds |
| `variants_at(a3, position)` | All variant records at a 1-based position |

### Serialization / I/O

| Function | Description |
|---|---|
| `a3_from_json(text)` | Parse a JSON string into an A3 object |
| `a3_to_json(a3, *, indent)` | Serialize an A3 object to a JSON string |
| `read_a3json(path)` | Read an A3 JSON file from disk |
| `write_a3json(a3, path, *, indent)` | Write an A3 object to a JSON file |

### Pydantic Model Hierarchy

```
A3
 ├── sequence:    str
 ├── annotations: A3Annotations
 │   ├── site:        dict[str, SiteEntry]    (position index)
 │   ├── region:      dict[str, RegionEntry]  (range index)
 │   ├── ptm:         dict[str, FlexEntry]    (position or range index)
 │   ├── processing:  dict[str, FlexEntry]    (position or range index)
 │   └── variant:     list[VariantRecord]
 └── metadata:    A3Metadata
     ├── uniprot_id, description, reference, organism
```

All models are immutable (`frozen=True`). Users never construct them directly —
use `create_a3` or `a3_from_json` instead.

## License

[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/)
