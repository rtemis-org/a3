# rtemis.a3

R implementation of the **Amino Acid Annotation (A3)** format —
a structured JSON format for amino acid sequences with site, region, PTM,
processing, and variant annotations.

Part of the [rtemis-org/a3](https://github.com/rtemis-org/a3) monorepo,
which provides A3 implementations in R, TypeScript, Python, Julia, and Rust.

## Installation

```r
# From r-universe
install.packages("rtemis.a3", repos = "https://rtemis-org.r-universe.dev")
```

## Quick Start

```r
library(rtemis.a3)

a3 <- create_A3(
  sequence = "MKTAYIAKQR",
  site = list(
    "Active site" = annotation_position(c(3, 5), type = "activeSite")
  ),
  region = list(
    "Repeat 1" = annotation_range(matrix(c(1L, 4L), ncol = 2))
  ),
  ptm = list(
    Phosphorylation = annotation_position(c(7))
  ),
  variant = list(
    annotation_variant(3, info = list(from = "K", to = "R"))
  ),
  uniprot_id  = "P12345",
  description = "Example protein",
  organism    = "Homo sapiens"
)

print(a3)
```

## Parsing JSON

```r
a3 <- A3from_json("path/to/protein.json")
# or from a JSON string
a3 <- A3from_json(json_string)
```

## Serialization

```r
json_string <- to_json(a3)
write_A3json(a3, "path/to/output.json")
a3 <- read_A3json("path/to/protein.json")
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
| `create_A3(sequence, site, region, ptm, processing, variant, ...)` | Create an A3 object |
| `annotation_position(x, type)` | Create a position-indexed annotation entry |
| `annotation_range(x, type)` | Create a range-indexed annotation entry |
| `annotation_variant(x, info)` | Create a variant annotation |
| `concat(x)` | Concatenate a character vector to a single sequence string |

### I/O

| Function | Description |
|---|---|
| `to_json(x)` | Serialize an A3 object to a JSON string |
| `A3from_json(x)` | Parse a JSON string or pre-parsed list into an A3 object |
| `write_A3json(x, path)` | Write an A3 object to a JSON file |
| `read_A3json(path)` | Read an A3 object from a JSON file |

### S7 Class Hierarchy

```
A3
 ├── sequence:    A3Sequence
 ├── annotations: A3Annotation
 │   ├── site:        named list of A3Site       (A3Position index)
 │   ├── region:      named list of A3Region     (A3Range index)
 │   ├── ptm:         named list of A3PTM        (A3Index — position or range)
 │   ├── processing:  named list of A3Processing (A3Index — position or range)
 │   └── variant:     list of A3Variant
 └── metadata:    A3Metadata
     ├── uniprot_id, description, reference, organism
```

## License

[GPL (>= 3)](https://www.gnu.org/licenses/gpl-3.0.html)
