# Changelog

The five A3 implementations release together from one commit when a change reaches the format, the validator, or the conformance corpus; a change to one package's packaging releases that package alone. Package versions and `a3_version` are independent. The R package's news is [`r/NEWS.md`](r/NEWS.md).

## Unreleased

- License: all five packages, the specification, the schema, and the conformance corpus are BSD 3-Clause.
- Schema: `schema/a3.schema.json` is generated from the `rtemis.a3` S7 classes (`just schema`); CI fails when it differs from regeneration. It accepts the same documents as before, with `uniqueItems: true` on `positionIndex`, and emits no `default` keyword.
- Schema: every class definition carries a description, and the root carries `x-rtemis.publication` (`scope: shared`, `domain: domain`, `kind: data`).
- Schema: `just schema-check`, a dependency of `just conformance`, and the CI job `schema-matches-corpus` validate the conformance corpus against the schema.
- R: `rtemis.a3` 0.7.0 declares its classes with the rtemis.core `prop_*` factories; variant records are named lists.
- R: `clinvar_variants(gene, protein, classification)` positions each variant on one RefSeq protein from its HGVS protein expression.
- R: `write_A3json()` writes a named variant list, and a member wrapped in `I()`, as a JSON array.
- Example: `examples/mapt.a3.json` is tau isoform 2N4R (UniProtKB P10636-8), built by `examples/mapt/build_mapt.R`; the conformance case `valid/mapt` is generated from it.

## 2026-11-02: R S7 compatibility

| Package | Version |
|---|---|
| `rtemis.a3` (R) | 0.6.1 |

- R: compatible with S7 releases after 0.2.2.

## 2026-08-07: TypeScript provenance

| Package | Version |
|---|---|
| `@rtemis/a3` (npm, JSR) | 0.3.1 |

- TypeScript: JSR publishes from GitHub Actions, with a SLSA provenance attestation.
- TypeScript: every member of `ParseResult` and `ParsedIndex` is documented.
- npm moves from 0.2.1 to 0.3.1, matching JSR.

## 2026-08-06: Conformance release

| Package | Version |
|---|---|
| `rtemis.a3` (R) | 0.6.0 |
| `rtemis_a3` (Python) | 0.2.0 |
| `@rtemis/a3` (npm, JSR) | 0.3.1 |
| `RtemisA3` (Julia) | 0.2.0 |
| `rtemis-a3` (Rust) | 0.3.0 |

`a3_version` is `"1.0.0"`; the document format is unchanged.

- All five implementations conform to one corpus ([`spec/conformance/`](spec/conformance/)): 72 cases over the 37 codes of the rule registry ([`spec/error-codes.md`](spec/error-codes.md)).
- Breaking: issue paths are RFC 6901 JSON Pointers ([`spec/error-paths.md`](spec/error-paths.md)).
- Breaking: validation reports every issue in the earliest failing stage, each with a code, a path, and a message.
- Breaking: new rule `A3E_VARIANT_RESIDUE_MISMATCH`: a single-character `from` must match the residue at `position`.
- `annotations` and `metadata` are optional.
- Author-supplied key order round-trips in every implementation.
- R: new `validate_A3json()`; `A3Variant@position` is an integer; `A3from_json()` takes JSON text only.
- Python: `A3Issue` and `A3IssueCode`; `A3ValidationError.issues` and `.stage`.
- TypeScript: new `validate()`; `zod` and `A3InputSchema` are removed; metadata members are free text.
- Julia: new `validate()`.
- Rust: `--json` reports `issues` and `stage`; `A3` does not implement `Deserialize`.
