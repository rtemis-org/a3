# A3 conformance corpus

Every implementation reads this directory by relative path from the repository
root. A copy vendored into a language directory stops testing the same corpus as
the other four.

```
spec/conformance/
  README.md          this file
  generator/         the single source of truth for every case below
  manifest.json      the index: one entry per case, with its expectation
  valid/             documents that must validate
  invalid/           documents that must not, with the exact issues expected
```

Current size: **72 cases** — 22 valid (14 with a round-trip expectation) and 50
invalid, of which 10 expect more than one issue and 6 are `multi-*`
cases. Every one of the 37 codes in
[`../error-codes.md`](../error-codes.md) has a case that exercises it in
isolation.

## The manifest

```json
{
  "cases": [
    {
      "file": "invalid/multi-contextual.a3.json",
      "description": "Five Stage 4 issues, including the biological one.",
      "valid": false,
      "stage": 4,
      "issues": [
        { "code": "A3E_POS_OUT_OF_BOUNDS",        "path": "/annotations/site/s/index/1" },
        { "code": "A3E_VARIANT_RESIDUE_MISMATCH", "path": "/annotations/variant/0/from" }
      ]
    },
    {
      "file": "valid/unsorted-positions.a3.json",
      "description": "Positions out of order are valid; normalization sorts them ascending.",
      "valid": true,
      "normalized": "valid/unsorted-positions.normalized.json"
    }
  ]
}
```

| Key | Meaning |
|---|---|
| `file` | path to the case document, relative to this directory |
| `description` | one line, for legible failure output |
| `valid` | whether the document must validate |
| `stage` | invalid cases only: the stage the reported issues belong to |
| `issues` | invalid cases only: the exact set of `{code, path}` pairs expected |
| `normalized` | valid cases only, optional: the expected normalized document |

## Assertion semantics

**For `valid: false`** — the set of `{code, path}` pairs produced must **equal**
the expected set. Not a subset, not a superset. Human messages are ignored
entirely.

The comparison is over **multisets**, not sets, because a rule can legitimately
fire more than once at the same path: `pos-duplicate` expects two
`A3E_POS_DUPLICATE` issues at `/annotations/site/s/index`, one per repeated
value. An implementation that reports one has not conformed.

Order is **not** compared. Two implementations that emit the same pairs in
different orders both conform.

**For `valid: true`** — validation must succeed. If the case has a `normalized`
key, then parsing the case document and re-serializing it must produce a
document **structurally equal** to the `normalized` file, where structural
equality means:

- the same values throughout;
- arrays in the same order;
- **object members in the same order.**

Indentation, line endings, and number formatting are not compared.

## The canonical form

Re-serializing a parsed document must produce all defaults, materialized:

- all five top-level members, in schema order: `$schema`, `a3_version`,
  `sequence`, `annotations`, `metadata`
- all five annotation families, in schema order: `site`, `region`, `ptm`,
  `processing`, `variant` — present even when empty
- all four metadata members, in schema order — present even when empty, as `""`
- every annotation entry's `index` then `type`, with `type` present as `""` when
  it was absent

Normalization is exactly three transformations and nothing else:

1. `sequence` is case-folded to uppercase
2. positions are sorted ascending
3. ranges are sorted by start, then by end

**Author-supplied key order is preserved.** Annotation names appear in the order
they appear in the document, and a variant record's extra members appear in the
order they appear in the record. `valid/annotation-name-order-preserved.a3.json`
pins this. Rust's `HashMap` and Julia's `Dict` do not preserve insertion order;
an implementation built on either fails the case.

Variant records are open: every member beyond `position` round-trips verbatim,
including `null`, nested objects, and arrays. `valid/variant-open-fields.a3.json`
covers all three.

## Adding a case

Edit [`generator/src/main.rs`](generator/src/main.rs) and re-run it:

```sh
just corpus     # cargo run --manifest-path spec/conformance/generator/Cargo.toml
```

The case files and `manifest.json` are generated; edits to them are
overwritten. CI runs the generator and fails if it produces a diff.

### Where each expectation comes from

- **Expected issues** are declared by hand in the generator. No implementation
  produces them.
- **`normalized` companions** are produced by the Rust implementation and
  checked against the canonical form above (member order, materialized
  defaults, sequence differing only by case, indices sorted and in bounds,
  authored key order intact) before they are written. A companion that fails
  the check fails generation.

### What a good case looks like

- **One rule per case**, so that a failure names the rule. The `multi-*` cases
  are the exception.
- **A `description` that says what is being asserted**, not what the file
  contains. "Duplicate positions are rejected, not deduplicated" is useful in a
  failure report; "site index with duplicates" is not.
- **The smallest document that triggers it.** Every case shares the same
  24-residue sequence `MAEPRQEFEVMEDHAGTYGLGDRK` so that bounds arithmetic is
  checkable by eye. Residue 5 is `R`, residue 18 is `Y`.

## Writing a runner

Each implementation ships one runner. It reads `manifest.json`, validates every
case, and compares issue multisets.

**Failure output must name the diff.** For every failing case, print which
`{code, path}` pairs were expected and absent, and which were produced and
unexpected.

```
FAIL invalid/multi-contextual.a3.json
  Five Stage 4 issues, including the biological one.
  missing:    A3E_VARIANT_RESIDUE_MISMATCH  /annotations/variant/0/from
  unexpected: A3E_VARIANT_RESIDUE_MISMATCH  /annotations/variant/0
```

The runners:

| Implementation | Runner |
|---|---|
| Rust | `rust/tests/conformance.rs` |
| Python | `python/rtemis_a3/tests/test_conformance.py` |
| TypeScript | `typescript/tests/conformance.test.ts` |
| Julia | `julia/RtemisA3/test/conformance.jl`, included from `runtests.jl` |
| R | `r/tests/testthat/test_conformance.R` |

The R runner skips when the corpus path does not exist, so the package's tests
pass outside the repository, where the corpus is not installed. CI runs it
inside the repository.
