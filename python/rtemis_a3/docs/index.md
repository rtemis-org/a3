[![PyPI version](https://img.shields.io/pypi/v/rtemis-a3.svg)](https://pypi.org/project/rtemis-a3/) [![python-ci](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/python-ci.yml)

# rtemis-a3

Python implementation of the **Amino Acid Annotation (A3)** format, a JSON format for an amino acid sequence with site, region, PTM, processing, and variant annotations.

- Canonical JSON Schema: [`https://schema.rtemis.org/a3/v1/schema.json`](https://schema.rtemis.org/a3/v1/schema.json) (source: [`schema/a3.schema.json`](https://github.com/rtemis-org/a3/blob/main/schema/a3.schema.json))
- Conformance contract: [`spec/`](https://github.com/rtemis-org/a3/tree/main/spec)
- Monorepo, with the R, Julia, TypeScript, and Rust implementations: [rtemis-org/a3](https://github.com/rtemis-org/a3)

## Installation

```bash
pip install rtemis-a3
# or with uv
uv add rtemis-a3
```

The distribution is `rtemis-a3`; the import package is `rtemis.a3`.

## Usage

```python
from rtemis.a3 import create_a3, residue_at, variants_at

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
    variant=[{"position": 3, "from": "T", "to": "A"}],
    metadata={
        "uniprot_id": "P12345",
        "description": "Example protein",
        "organism": "Homo sapiens",
    },
)

len(a3.sequence)     # 10
residue_at(a3, 1)    # 'M'
variants_at(a3, 3)   # [VariantRecord(position=3, from='T', to='A')]
```

`create_a3` adds `$schema` and `a3_version` to the document it builds.

## Reading a document

```python
from rtemis.a3 import a3_from_json, A3ParseError, A3ValidationError

try:
    a3 = a3_from_json(json_string)
except A3ParseError as e:
    print(e)          # the text is not JSON
except A3ValidationError as e:
    print(e.issues)   # list[A3Issue]: code, path, message
```

## File I/O

```python
from rtemis.a3 import read_a3json, write_a3json

a3 = read_a3json("protein.a3.json")
write_a3json(a3, "output.a3.json", indent=2)
```

## Serialization

```python
from rtemis.a3 import a3_to_json

json_string = a3_to_json(a3)            # compact
json_string = a3_to_json(a3, indent=2)  # pretty-printed
```

## Document format

```json
{
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
}
```

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

Validation is **collect-all**. A document is checked in four stages (envelope, structural, intra-field, contextual), and every issue in the earliest failing stage is reported at once. A later stage runs only when every earlier stage produced no issue. Each issue carries a stable `code` and an [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer `path`; both are identical across the R, Python, Julia, TypeScript, and Rust implementations of A3. The `message` is human-readable text and is not part of the contract. The rule registry is [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md).

`a3_from_json`, `read_a3json`, and `create_a3` raise an `A3ValidationError` that carries every issue of the failing stage:

```python
from rtemis.a3 import a3_from_json, A3ValidationError

try:
    a3 = a3_from_json(text)
except A3ValidationError as exc:
    print(exc.stage)  # 4
    for issue in exc.issues:
        print(issue.code, issue.path)
        # A3E_POS_OUT_OF_BOUNDS /annotations/site/Active site/index/2
```

`validate_a3` is the non-throwing entry point, for a form or a live-validation panel:

```python
import json
from rtemis.a3 import validate_a3

issues = validate_a3(json.loads(text))  # [] when the document is valid
```

## API

### Functions

| Function | Description |
|---|---|
| `create_a3(sequence, *, site, region, ptm, processing, variant, metadata)` | Builds and validates an `A3` object from its parts. Raises `A3ValidationError`. |
| `a3_from_json(text)` | Parses and validates a JSON string. Raises `A3ParseError` or `A3ValidationError`. |
| `validate_a3(raw)` | Validates a parsed value; returns `list[A3Issue]`, empty when the document is valid. |
| `a3_to_json(a3, *, indent=None)` | Serializes to a JSON string; `indent=None` gives compact output. |
| `read_a3json(path)` | Reads and validates a file. Raises `A3ParseError` when the file cannot be read or is not JSON. |
| `write_a3json(a3, path, *, indent=None)` | Writes `a3_to_json(a3, indent=indent)` to a file. |
| `residue_at(a3, position)` | Residue at a 1-based position. Raises `ValueError` when the position is out of bounds. |
| `variants_at(a3, position)` | Every variant record at a 1-based position. |

### Errors and issues

| Name | Description |
|---|---|
| `A3ValidationError` | `issues`: every issue in the earliest failing stage. `stage`: that stage, `1` to `4`. `messages`: one message per issue. |
| `A3ParseError` | The input could not be parsed or read before validation. |
| `A3Issue` | One issue: `code`, `path`, `message`, and `stage`. |
| `A3IssueCode` | A `StrEnum` of every code in the rule registry. |

### Pydantic model hierarchy

```
A3
 ├── sequence:    str
 ├── annotations: A3Annotations
 │   ├── site:        dict[str, A3Position]  (position index)
 │   ├── region:      dict[str, A3Range]     (range index)
 │   ├── ptm:         dict[str, A3Flex]      (position or range index)
 │   ├── processing:  dict[str, A3Flex]      (position or range index)
 │   └── variant:     list[VariantRecord]
 └── metadata:    A3Metadata
     └── uniprot_id, description, reference, organism
```

Every model is immutable (`frozen=True`) and rejects unknown fields. `create_a3` and `a3_from_json` construct them.

## License

[BSD 3-Clause](https://github.com/rtemis-org/a3/blob/main/python/rtemis_a3/LICENSE)
