# ClinVar Variants

This document defines how ClinVar variant data maps to A3 variant annotations
and records implementation decisions specific to the A3 schema.

For full API documentation see:
- NCBI E-utilities: https://www.ncbi.nlm.nih.gov/books/NBK25501/
- ClinVar: https://www.ncbi.nlm.nih.gov/clinvar/

---

## APIs Used

| Purpose | Endpoint |
| --- | --- |
| Find ClinVar UIDs for a gene | `GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi` |
| Fetch variant summaries | `POST https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi` |

Use POST (not GET) for esummary when fetching many UIDs to avoid HTTP 414
(URI Too Long). Send IDs as form-encoded body, not query parameters.

---

## Search Term Construction

Query ClinVar by gene symbol with an optional clinical significance filter:

```
{gene}[gene_name] AND ("{sig1}"[clinsig] OR "{sig2}"[clinsig])
```

Supported significance values: `pathogenic`, `likely_pathogenic`,
`uncertain_significance`, `likely_benign`, `benign`.

Default: fetch only `pathogenic` and `likely_pathogenic` variants. Fetching
all variants for a gene (e.g. BRCA1, CFTR) can return tens of thousands of
records.

---

## Mapping to A3

### `variant` — `A3Variant`

Each ClinVar record with a parseable protein-level amino acid change maps to
one `A3Variant` object.

#### Position and allele

The `protein_change` field in the esummary response encodes the amino acid
change in standard single-letter notation, e.g. `"R406W"`. Parse as:

```
from     = first character     ("R")
position = middle digits       (406)
to       = last character      ("W")
```

When `protein_change` contains multiple isoform entries separated by `/`
(e.g. `"R406W/R406Q"`), use the first parseable entry.

#### `A3Variant.info` fields

| Field | Source | Notes |
| --- | --- | --- |
| `from` | `protein_change` first char | Reference amino acid (single-letter) |
| `to` | `protein_change` last char | Alternate amino acid or `*` for stop |
| `clinicalSignificance` | `clinical_significance.description` | e.g. `"Pathogenic"` |
| `reviewStatus` | `clinical_significance.review_status` | e.g. `"criteria provided, multiple submitters, no conflicts"` |
| `conditions` | `trait_set[*].trait_name` | Semicolon-separated condition names |
| `accession` | `accession` | VCV accession, e.g. `"VCV000000417"` |
| `clinvarId` | `uid` | Integer ClinVar UID |

#### Naming

Variants are named using `{from}{position}{to}` notation (e.g. `"R406W"`).
When the same name appears more than once (multiple alleles at the same
position), disambiguate with a numeric suffix: `"R406W.1"`, `"R406W.2"`.

### Not mapped

Variants without a parseable `protein_change` (intronic, splice-site,
regulatory, large insertions/deletions, copy number variants) are silently
skipped. These cannot be represented in A3's residue-based schema.
