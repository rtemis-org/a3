# rtemis.a3 0.5.1

## New features

* Initial CRAN release.
* Defines the Amino Acid Annotation (A3) format using S7 classes.
* Core classes: `A3`, `A3Sequence`, `A3Annotation`, `A3Metadata`, `A3Site`,
  `A3Region`, `A3PTM`, `A3Processing`, `A3Variant`.
* `create_A3()`: create A3 objects with full validation.
* `annotation_position()`, `annotation_range()`, `annotation_variant()`:
  helpers to build annotation entries.
* `write_A3json()` / `read_A3json()`: serialize and deserialize A3 objects to
  and from JSON files.
* `concat()`: concatenate a character vector into a single sequence string.
* Database utilities: `uniprot_to_A3()`, `uniprot_sequence()`,
  `gene2sequence()`, `get_alphafold()`, `pdb_annotations()`,
  `clinvar_variants()`.
