# Changelog

All five A3 implementations are released together from one commit whenever a
change reaches the format, the validator, or the conformance corpus. Versions
differ per package because each started from a different number. A change
confined to one implementation's own packaging ships on its own, and its entry
says which packages it covers.

## 2026-11-02 — R S7 compatibility

| Package | Version |
|---|---|
| `rtemis.a3` (R) | 0.6.1 |

**R only.** Nothing in the A3 format, the validator, or the conformance corpus
changed, so the other four implementations stay at their current versions.
`a3_version` remains `"1.0.0"`.

### Fixed

- **`A3Metadata()` constructs its parent as an instance**, `Metadata()`, which
  S7 releases after 0.2.2 require of `new_object()`.
- **The namespace imports S7's `:=` and excludes data.table's**, which removes
  the import-replacement warning on load under S7 releases after 0.2.2.
- **Load, unload, and build hooks register and clean up S7 methods** through
  `S7_on_load()`, `S7_on_unload()`, and `S7_on_build()` when S7 provides them,
  and through `methods_register()` with earlier S7 releases. The minimum S7
  version is unchanged.

## 2026-08-07 — TypeScript provenance

| Package | Version |
|---|---|
| `@rtemis/a3` (npm + JSR) | 0.3.1 |

**TypeScript only.** Nothing in the A3 format, the validator, or the conformance
corpus changed, so the other four implementations are untouched and stay at
their 2026-08-06 versions. `a3_version` remains `"1.0.0"`.

### Added

- **JSR publishes from GitHub Actions**, via a workflow dispatched by hand with
  the version as its input. Publishing stays manual — no push and no tag ships
  anything — but JSR mints a SLSA provenance attestation in the Sigstore
  transparency log *only* for packages published from Actions over OIDC, so a
  `deno publish` from a laptop cannot produce one. npm still publishes locally.

### Fixed

- **The `ParseResult` and `ParsedIndex` union members carried no
  documentation** — the `ok` / `value` / `error` and `kind` / `values` arms.
  They were the last undocumented nodes in the public API.
- **A dangling `{@link A3InputSchema}`** in the documentation for
  `parseRanges`. That was the Zod schema removed in 0.3.0, so the reference had
  been rendering as a broken link. It now points at `validate` and
  `A3E_RANGE_OVERLAP`, where range overlap is actually enforced.

### Notes

- **npm skips 0.3.0 entirely.** npm was still on 0.2.1 when JSR reached 0.3.0,
  so the next `pnpm publish` takes npm from 0.2.1 straight to 0.3.1. The two
  registries are back in step afterwards.
- **0.3.0 cannot gain provenance retroactively.** JSR never replaces a published
  version, so the attestation arrives with 0.3.1.
- JSR's "documented symbols" score reads 51% (31/60) even though every exported
  symbol is documented. The denominator counts symbols once per entrypoint — 31
  from `index.ts` plus 29 from `index-browser.ts`, which re-exports the same
  symbols minus the two I/O functions — while the numerator appears to credit
  each unique symbol once. Two entrypoints sharing most of their surface cap the
  figure near 52%. It is not a documentation gap, and adding documentation will
  not move it.

## 2026-08-06 — conformance release

| Package | Version |
|---|---|
| `rtemis.a3` (R) | 0.6.0 |
| `rtemis_a3` (Python) | 0.2.0 |
| `@rtemis/a3` (npm + JSR) | 0.3.1 |
| `RtemisA3` (Julia) | 0.2.0 |
| `rtemis-a3` (Rust) | 0.3.0 |

The A3 **document format is unchanged**. `a3_version` stays `"1.0.0"`. Package
versions and `a3_version` do not track each other and never will: the former
version the implementations, the latter versions the format.

### The headline

All five implementations are now held to one shared conformance corpus
([`spec/conformance/`](spec/conformance/)) with one shared rule registry
([`spec/error-codes.md`](spec/error-codes.md)) and one shared path grammar
([`spec/error-paths.md`](spec/error-paths.md)). 72 cases, 37 codes, every code
exercised in isolation, run by all five in CI from the same commit.

### Breaking

- **Every error path changed.** Paths are now RFC 6901 JSON Pointers. Where an
  implementation previously emitted `annotations.site.foo` or
  `annotations.site.foo.index` or `annotations.site.foo.index[3]`, all five now
  emit `/annotations/site/foo/index/3`. Anything parsing error output must be
  updated. Array subscripts are 0-based; sequence positions remain 1-based.

- **Validation is collect-all in all five.** R and Julia previously stopped at
  the first problem. Every implementation now reports every issue in the
  earliest failing stage, each with a stable code, a path, and a message.
  Validation runs in four stages and short-circuits at a stage boundary, so a
  document with a bad `sequence` no longer emits hundreds of spurious
  out-of-bounds errors.

- **New rule `A3E_VARIANT_RESIDUE_MISMATCH`.** A variant record whose `from`
  member is a single character that disagrees with the residue at `position` is
  now invalid. Documents annotated against a different isoform stop validating.
  This found genuine errors in three of this repository's own test fixtures.

- **`annotations` and `metadata` are optional.** Rust, TypeScript, Julia, and R
  previously required both, contradicting the published schema. A document of
  just `$schema`, `a3_version`, and `sequence` is now valid everywhere. This is
  a loosening: nothing that validated before stops validating.

- **TypeScript: `zod` is no longer a dependency**, and `A3InputSchema` is no
  longer exported. Validation is a hand-written staged pass, which is what makes
  exact `{code, path}` agreement with the other four achievable. Use the new
  `validate(input)` for a non-throwing result, or `A3ValidationError.issues`.
  `A3ValidationIssue.path` was an array of keys and is now a pointer string.

- **TypeScript: the `uniprot_id` accession grammar is gone**, along with the
  minimum-length and trimming rules on `description`, `reference`, and
  `organism`. They existed in TypeScript only, were absent from the schema, and
  the accession pattern wrongly rejected isoform accessions such as `P10636-8`.
  Metadata is free text; A3 validates only that each member is a string.

- **R: `A3Variant@position` is a plain integer**, not an `A3Position` wrapping
  one. `v@position@data` becomes `v@position`.

- **R: `A3from_json()` takes JSON text only.** It no longer accepts a
  pre-parsed list.

- **Rust: `--diagnose` is deprecated and ignored.** Every run is now a full
  diagnostic. `--json` output replaces the `errors` string array with an
  `issues` array of `{code, path, message}` objects, plus a `stage` field.

- **Rust: `A3` and its component types no longer derive `Deserialize`.** That
  impl was a hole in the invariant that every `A3` has been validated. Use
  `a3_from_json` or `validate`.

### Added

- `spec/` — the conformance contract: rule registry, path grammar, corpus, and
  a generator (`spec/conformance/generator/`, Rust) that keeps the corpus and
  its manifest in sync. Expected issues are hand-declared, because they are the
  specification; `normalized` companions are produced by the reference
  implementation and then checked against independently-stated invariants, so
  normalization has five implementations rather than six.
- A conformance runner in each implementation, plus a meta-test that fails if a
  registry code has no corpus case.
- **R: `validate_A3json(filepath)`** — a non-throwing entry point returning a
  data frame of issues, for forms and reports. `read_A3json()` still aborts, now
  once with every issue, and attaches the issue list to the condition
  (`class = c("a3_validation_error", "rtemis_error", ...)`).
- **Julia: `validate(raw)`** — the non-throwing counterpart to `A3(raw)`.
- **TypeScript: `validate(input)`**, `A3_ISSUE_CODES`, `A3_ISSUE_STAGES`,
  `pointer`, `escapeToken`, `resolvePointer`, and `stageOf`.
- **Python: `A3Issue` and `A3IssueCode`** are exported;
  `A3ValidationError.issues` and `.stage` replace `.errors`.

### Fixed

- **Author-supplied key order now round-trips.** Rust used `HashMap` and Julia
  used `Dict`, so serializing the same parsed document twice could produce two
  different files. Rust gains `indexmap`, Julia gains `OrderedCollections`, and
  normalization is now exactly three rules — case-fold the sequence, sort
  positions, sort ranges — with nothing a human wrote ever reordered.
- **R dropped `null` and mangled nested values in variant records.**
  `out[[nm]] <- NULL` deletes a list element rather than storing a JSON null,
  and nested scalars were emitted as one-element arrays. A variant record's open
  members now round-trip verbatim at every depth.
- **R: `jsonlite` moved from `Suggests` to `Imports`.** There were 13
  unconditional `jsonlite::` call sites and no `requireNamespace()` guard, so a
  user without `jsonlite` got a runtime failure on the package's primary I/O
  path. CI now also runs `_R_CHECK_DEPENDS_ONLY_=true`, which catches this class
  of bug; a plain `R CMD check` does not.
- **R: `sapply()` over possibly-empty lists** in `A3Annotation`'s validator
  replaced with a length-guarded `vapply()`.
- **Julia `Project.toml` gained its missing `license` field** (`MPL-2.0`).
- **npm and JSR versions had drifted apart** (0.2.1 vs 0.1.8). They publish
  together and now carry one version.
- The root `README.md` and `AGENTS.md` advertised a `specs/` directory that did
  not exist. They now point at `spec/`, which does.

### Notes

- Licensing is deliberately per-package: the R package is `GPL (>= 3)` because
  it imports `rtemis.core`, which is GPL; the other four are `MPL-2.0`.
- `3.0` is the position 3. JSON has no integer type distinct from number, and
  JSON Schema's `type: "integer"` accepts any number with a zero fractional
  part. `2.5` is not a position, and `true` is never a position.
- Known limitation, JavaScript only: an annotation name that is a decimal
  integer string (`"5"`) is reordered ahead of other keys by the JavaScript
  object property-order rules. Every other implementation preserves it.
