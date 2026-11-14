[![CRAN status](https://www.r-pkg.org/badges/version/rtemis.a3)](https://CRAN.R-project.org/package=rtemis.a3) [![rtemis.a3 status badge](https://rtemis-org.r-universe.dev/rtemis.a3/badges/version)](https://rtemis-org.r-universe.dev/rtemis.a3) [![r-ci](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/r-ci.yml)

# rtemis.a3

R implementation of the **Amino Acid Annotation (A3)** format — a structured JSON format for amino acid sequences with site, region, PTM, processing, and variant annotations.

Part of the [rtemis-org/a3](https://github.com/rtemis-org/a3) monorepo, which provides A3 implementations in R, Python, Julia, TypeScript, and Rust.

## Installation

### CRAN

```r
install.packages("rtemis.a3")
```

### R-universe

```r
pak::repo_add(myuniverse = "https://rtemis-org.r-universe.dev")
pak::pak("rtemis.a3")
```

### GitHub

```r
pak::pak("rtemis-org/a3/r")
```

## Usage

```r
library(rtemis.a3)

a3 <- create_A3(
  sequence = "MKTAYIAKQR",
  site = list(
    "Active site" = annotation_position(c(3L, 5L), type = "active site")
  ),
  region = list(
    "Repeat 1" = annotation_range(rbind(c(1L, 4L)))
  ),
  ptm = list(
    Phosphorylation = annotation_position(c(7L))
  ),
  uniprot_id  = "P12345",
  description = "Example protein",
  organism    = "Homo sapiens"
)
```

## Read / Write JSON

```r
write_A3json(a3, "path/to/protein.json")
a3 <- read_A3json("path/to/protein.json")
```

## API

### Construction

|                                      Function | Description                                |
|-----------------------------------------------|--------------------------------------------|
| `create_A3(sequence, site, region, ptm, ...)` | Create an A3 object                        |
|                `annotation_position(x, type)` | Create a position-indexed annotation entry |
|                   `annotation_range(x, type)` | Create a range-indexed annotation entry    |
|                 `annotation_variant(x, info)` | Create a variant record                    |

### I/O

|                Function | Description                        |
|-------------------------|------------------------------------|
| `write_A3json(x, path)` | Write an A3 object to a JSON file  |
|     `read_A3json(path)` | Read an A3 object from a JSON file |

### S7 Class Hierarchy

```
A3
 ├── sequence:     character(1)
 ├── annotations:  A3Annotations
 │   ├── site:        named list of A3Site       (index: integer vector)
 │   ├── region:      named list of A3Region     (index: two-column integer matrix)
 │   ├── ptm:         named list of A3PTM        (index: either)
 │   ├── processing:  named list of A3Processing (index: either)
 │   └── variant:     list of variant records    (named lists, `position` first)
 └── metadata:     A3Metadata
     ├── uniprot_id
     ├── description
     ├── reference
     └── organism
```

Every property is declared with an rtemis.core `prop_*` factory, and `a3_schema()` generates the A3 JSON Schema from these declarations.

## Validation

Validation is **collect-all**. A document is checked in four stages — envelope, structural, intra-field, contextual — and every issue in the earliest failing stage is reported at once. Each issue carries a stable `code` and an [RFC 6901](https://www.rfc-editor.org/info/rfc6901/) JSON Pointer `path`, both of which are identical across the R, Python, Julia, TypeScript, and Rust implementations of A3. Messages are for humans and are not contractual.

Three entry points:

| Entry point | Behavior |
|---|---|
| `read_A3json(path)` | **collect-all** — aborts once with every issue in the failing stage |
| `validate_A3json(path)` | **collect-all, non-throwing** — returns the issues as a data frame |
| `create_A3(...)` | aborts with the messages of the S7 validators, without codes or paths |

```r
validate_A3json("mapt.a3.json")
#>                    code stage                              path                     message
#> 1 A3E_POS_OUT_OF_BOUNDS     4 /annotations/site/Active/index/2  Position 999 is out of ...
```

`read_A3json()` attaches the issue list to the condition object, so it is reachable without parsing the message:

```r
issues <- tryCatch(
  read_A3json("broken.a3.json"),
  a3_validation_error = function(e) e[["issues"]]
)
```

See [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) for the full rule registry and [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md) for the path grammar.
