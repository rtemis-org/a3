# rtemis.a3 0.7.0

- New `a3_schema()` returns the A3 JSON Schema, generated from the S7 classes.
- Every class carries a description, and `A3` a registry publication (`kind: data`); `a3_schema()` writes both.
- Breaking: the classes declare their properties with the rtemis.core `prop_*` factories. `A3@sequence` is a string; an annotation entry's `@index` is an integer vector or a two-column integer matrix; `A3Annotation` is `A3Annotations`; `A3Sequence`, `A3Position`, `A3Range`, `A3Index`, `A3Feature`, and `A3Variant` are removed.
- Breaking: a variant record is a named list with `position` first; `annotation_variant()` returns one.
- `annotation_position()` and `annotation_range()` return an integer vector or matrix as `index`.
- Constructing an `A3` object checks range order and overlap, bounds against the sequence length, and the variant residue rule.
- Requires rtemis.core 0.5.0.

# rtemis.a3 0.6.2

- License: BSD 3-Clause.
- `clinvar_variants(gene, protein, classification)` positions each variant on one RefSeq protein from its HGVS protein expression, and records its accession, classification, review status, and conditions. Requires xml2.
- `write_A3json()` writes a named variant list, and a member wrapped in `I()`, as a JSON array.

# rtemis.a3 0.6.1

- Compatible with S7 releases after 0.2.2.

# rtemis.a3 0.6.0

- Validation reports every issue in the earliest failing stage, each with a code from the A3 rule registry and an RFC 6901 JSON Pointer path.
- New `validate_A3json()` returns the issues as a data frame; `read_A3json()` aborts with class `a3_validation_error` and the issues attached.
- New rule: a single-character `from` in a variant must match the residue at `position`.
- `annotations` and `metadata` are optional.
- Breaking: `A3Variant@position` is an integer; `A3from_json()` takes JSON text only.
- Variant records round-trip `null` and nested values.
- jsonlite is in Imports.

# rtemis.a3 0.5.3

- Initial CRAN release: the A3 format as S7 classes, `create_A3()`, the `annotation_*()` helpers, `read_A3json()` and `write_A3json()`, and the database utilities `uniprot_to_A3()`, `uniprot_sequence()`, `gene2sequence()`, `get_alphafold()`, `pdb_annotations()`, and `clinvar_variants()`.
