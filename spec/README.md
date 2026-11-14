# A3 conformance contract

Normative. Where an implementation and this directory disagree, this directory is correct.

| File | Content |
|---|---|
| [`error-codes.md`](error-codes.md) | one stable code per rule, with its stage, kind, and path |
| [`error-paths.md`](error-paths.md) | the RFC 6901 JSON Pointer every issue carries |
| [`conformance/`](conformance/) | the 72 cases every implementation is tested against |

[`../schema/a3.schema.json`](../schema/a3.schema.json) defines which documents are valid. It is generated from the property declarations of the `rtemis.a3` S7 classes by `schema/generate_schema.R` (`just schema`), so regenerating it requires R; CI fails when the committed file differs from regeneration. This directory defines what an implementation reports when a document is not valid, and what it writes when a document is.

## What implementations agree on

A conforming implementation agrees exactly on:

- the multiset of `{code, path}` pairs a document produces;
- each rule's stage, and therefore which issues an earlier failure suppresses;
- the normalized serialization of a valid document.

Message wording, emission order, the type that carries an issue, and how it is surfaced are implementation-defined.

## Invariants

- **Within a stage, every issue is reported; across stages, validation short-circuits.** A stage runs only if every earlier stage produced no issues.
- **A guard suppresses its own subtree only**, not its siblings.
- **Per-element rules carry a subscript; whole-set rules do not.** A duplicate is a property of the set, not of either position.
- **Sorting is normalization; duplication is a rule.** There is no `A3E_POS_UNSORTED`.
- **Subscripts are 0-based; sequence positions are 1-based.**
- **`3.0` is the position 3.** `2.5` is not a position, and `true` never is.

## Two entry points

| Entry point | On error |
|---|---|
| reading a document: `read_A3json`, `a3_from_json`, `A3.fromJSONText`, `A3(::AbstractDict)` | every issue in the earliest failing stage |
| calling a constructor: `create_A3`, `create_a3`, `new A3(...)` | one corrective message for the first problem |

## Scope of validation

Validation decides whether a document is a legal A3 document, with the schema as its authority. Metadata members are free text and are checked only for being strings. Four groups of rules are cross-field constraints on declared data that JSON Schema does not express: `A3E_RANGE_ORDER`, `A3E_RANGE_OVERLAP`, the Stage 4 bounds rules, and `A3E_VARIANT_RESIDUE_MISMATCH`. A document that breaks only these rules validates against the schema and fails A3 validation.

## Changing a rule

1. Add or amend the code in [`error-codes.md`](error-codes.md), with its stage, kind, and path.
2. Add a case that exercises it in isolation to `conformance/generator/`, then run `just corpus`.
3. Implement it in all five implementations.
4. `just conformance` passes in all five.

The generator and the Rust runner fail if a registry code has no case. A code or a path changes only together with this directory and the corpus, in one commit.

## Known limitations

- **JavaScript reorders integer-like keys.** An annotation named `"5"` moves ahead of other keys under JavaScript's property-order rules, so `@rtemis/a3` does not round-trip it in document order. The other four do. Sorting keys in the other four would break their document-order guarantee.
- **`a3_version` is a constant.** Only `"1.0.0"` is accepted.
