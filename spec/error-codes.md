# A3 error codes

The rule registry. One row per validation rule. Every implementation references
this file; no implementation invents a code.

**Naming.** `A3E_<AREA>_<RULE>`, SCREAMING_SNAKE, stable forever. Codes are
never renumbered and never reused. A retired rule is marked deprecated in place
and its row stays.

**Columns.**

- **Kind** — `field` (a property), `element` (one element of an index array), or
  `set` (a property of a whole collection). This determines whether the path
  carries an element subscript; see [`error-paths.md`](error-paths.md) Rule 2.
- **Path** — the RFC 6901 JSON Pointer the issue must carry, written with
  `foo` standing for an annotation name and `N` for a 0-based subscript.
- **Names value** — whether the human message is required to include the
  offending value. Wording is free; inclusion is not.

---

## Staging

Validation runs in four stages. **Within a stage, collect every issue. Across
stages, short-circuit**: a stage runs only if every earlier stage produced no
issues at all, anywhere in the document.

| Stage | Name | What it establishes |
|---|---|---|
| 1 | Envelope | the document is an object and declares itself to be A3 1.0.0 |
| 2 | Structural | every value has the type and shape the schema declares |
| 3 | Intra-field | every value is internally consistent |
| 4 | Contextual | every value is consistent with the rest of the document |

A document whose `sequence` fails Stage 2 has no length, so Stage 4 does not
run against it.

The stage boundary is the whole document, not the subtree. A Stage 2 issue in
`metadata` suppresses Stage 3 issues in `annotations`.

### The guard rule

Some issues report that a value has the wrong *container* type, which makes
everything below it unreadable. When one of these fires it is the **only** issue
reported for that subtree, even within its own stage — there is nothing beneath
it to inspect.

| Guard code | Suppresses |
|---|---|
| `A3E_DOC_NOT_OBJECT` | every other issue in the document, including the rest of Stage 1 |
| `A3E_ANNOTATIONS_NOT_OBJECT` | every issue under `/annotations` |
| `A3E_METADATA_NOT_OBJECT` | every issue under `/metadata` |
| `A3E_FAMILY_NOT_OBJECT` | every issue under that family |
| `A3E_VARIANT_LIST_NOT_ARRAY` | every issue under `/annotations/variant` |
| `A3E_ENTRY_NOT_OBJECT` | every issue under that entry |
| `A3E_INDEX_MISSING`, `A3E_INDEX_NOT_ARRAY` | every issue under that `index` |
| `A3E_VARIANT_NOT_OBJECT` | every issue under that variant record |

A guard suppresses only its own subtree. Two sibling annotations that are each
not an object produce two `A3E_ENTRY_NOT_OBJECT` issues, one per entry.

## What is not a validation issue

- **Parse failure.** A file that is not JSON has no path to report and no
  further issues to collect. It is a single fatal error of a different type
  (`A3ParseError` or equivalent), never an entry in the issue list.
- **JSON-incompatible variant extras.** A value that cannot exist in JSON —
  a function, a class instance, a set — cannot appear in a parsed document. This
  is checked on the constructor path only and has no code here.
- **Anything about the content of a metadata field.** `uniprot_id`,
  `description`, `reference`, and `organism` are free text. See
  [`README.md`](README.md), "Scope of validation".

---

## Stage 1 — Envelope

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_DOC_NOT_OBJECT` | field | `` (empty pointer) | — | the document root is not a JSON object |
| `A3E_ENVELOPE_SCHEMA_MISSING` | field | `/$schema` | — | `$schema` is absent |
| `A3E_ENVELOPE_SCHEMA_MISMATCH` | field | `/$schema` | ✓ | `$schema` is present and is not exactly `"https://schema.rtemis.org/a3/v1/schema.json"` (including when it is not a string) |
| `A3E_ENVELOPE_VERSION_MISSING` | field | `/a3_version` | — | `a3_version` is absent |
| `A3E_ENVELOPE_VERSION_MISMATCH` | field | `/a3_version` | ✓ | `a3_version` is present and is not exactly `"1.0.0"` (including when it is not a string) |

`a3_version` is a constant, not a range. `"1.1.0"` and `"2.0.0"` are both
`A3E_ENVELOPE_VERSION_MISMATCH`.

The `_MISMATCH` codes absorb wrong-type cases. The schema expresses both fields
with `const`, and a `const` failure is one failure regardless of why.

## Stage 2 — Structural

### Document

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_UNKNOWN_FIELD` | field | pointer to the offending property | — | a property not permitted by the schema |
| `A3E_SEQ_MISSING` | field | `/sequence` | — | `sequence` is absent |
| `A3E_SEQ_NOT_STRING` | field | `/sequence` | — | `sequence` is present and is not a string |
| `A3E_SEQ_TOO_SHORT` | field | `/sequence` | ✓ | `sequence` is a string shorter than 2 characters |
| `A3E_SEQ_CHARSET` | field | `/sequence` | ✓ | `sequence` contains a character outside `[A-Za-z*]` |
| `A3E_ANNOTATIONS_NOT_OBJECT` | field | `/annotations` | — | `annotations` is present and is not an object |
| `A3E_METADATA_NOT_OBJECT` | field | `/metadata` | — | `metadata` is present and is not an object |
| `A3E_METADATA_FIELD_NOT_STRING` | field | `/metadata/<name>` | — | a metadata member is present and is not a string |

`annotations` and `metadata` are **optional**. A document consisting of
`$schema`, `a3_version`, and `sequence` is valid, and both default to empty.

`A3E_UNKNOWN_FIELD` applies at four places, each with a closed member list:

| Object | Permitted members |
|---|---|
| document root | `$schema`, `a3_version`, `sequence`, `annotations`, `metadata` |
| `/annotations` | `site`, `region`, `ptm`, `processing`, `variant` |
| an annotation entry | `index`, `type` |
| `/metadata` | `uniprot_id`, `description`, `reference`, `organism` |

A variant record is **open** — it has no unknown-field check. `position` is
required; every other member is preserved verbatim.

One issue is emitted per offending property, at that property's pointer. A
document with three unknown top-level keys produces three issues.

### Annotation families

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_FAMILY_NOT_OBJECT` | field | `/annotations/<family>` | — | `site`, `region`, `ptm`, or `processing` is present and is not an object |
| `A3E_VARIANT_LIST_NOT_ARRAY` | field | `/annotations/variant` | — | `variant` is present and is not an array |
| `A3E_NAME_EMPTY` | field | `/annotations/<family>/` | — | an annotation name is the empty string |

`A3E_NAME_EMPTY`'s path ends in an empty reference token, which is how RFC 6901
denotes a member named `""`. It is not a truncated path.

### Annotation entries

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_ENTRY_NOT_OBJECT` | field | `/annotations/<family>/foo` | — | an annotation entry is not an object (a bare array is not accepted) |
| `A3E_ENTRY_TYPE_NOT_STRING` | field | `/annotations/<family>/foo/type` | — | the entry's `type` member is present and is not a string |
| `A3E_INDEX_MISSING` | field | `/annotations/<family>/foo/index` | — | the entry has no `index` member |
| `A3E_INDEX_NOT_ARRAY` | field | `/annotations/<family>/foo/index` | — | `index` is present and is not an array |
| `A3E_INDEX_ELEMENT_TYPE` | element | `/annotations/<family>/foo/index/N` | — | an index element does not have the shape the family requires |
| `A3E_INDEX_MIXED` | set | `/annotations/<family>/foo/index` | — | a `ptm` or `processing` index mixes positions and ranges |
| `A3E_RANGE_ARITY` | element | `/annotations/<family>/foo/index/N` | ✓ | a range is an array whose length is not exactly 2 |
| `A3E_RANGE_ENDPOINT_NOT_INTEGER` | element | `/annotations/<family>/foo/index/N` | — | a range endpoint is not an integer |

The shape each family requires of an index element:

| Family | Element shape |
|---|---|
| `site` | integer |
| `region` | 2-element array of integers |
| `ptm`, `processing` | integer **or** 2-element array of integers, homogeneous across the whole index |

**Determining the geometry of a `ptm` / `processing` index.** Classify every
element as *integer*, *array*, or *other*, then:

1. an empty index is a position index;
2. if any element is *other*, emit `A3E_INDEX_ELEMENT_TYPE` at each such element
   and stop — the geometry is undetermined;
3. otherwise if both *integer* and *array* are present, emit a single
   `A3E_INDEX_MIXED` at the index and stop;
4. otherwise the index is a position index (all *integer*) or a range index
   (all *array*), and is validated as that.

A boolean is not an integer. `[true, 2]` is `A3E_INDEX_ELEMENT_TYPE` at element
0, not a position index. JSON has no integer type distinct from number: a
non-integral number such as `2.5` is *other*.

### Variant records

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_VARIANT_NOT_OBJECT` | field | `/annotations/variant/N` | — | a variant record is not an object |
| `A3E_VARIANT_POSITION_MISSING` | field | `/annotations/variant/N/position` | — | a variant record has no `position` |
| `A3E_VARIANT_POSITION_NOT_INTEGER` | field | `/annotations/variant/N/position` | — | `position` is present and is not an integer |

## Stage 3 — Intra-field

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_POS_NOT_POSITIVE` | element | `/annotations/<family>/foo/index/N` | ✓ | a position is < 1 |
| `A3E_POS_DUPLICATE` | set | `/annotations/<family>/foo/index` | ✓ | a position occurs more than once in one index |
| `A3E_RANGE_ENDPOINT_NOT_POSITIVE` | element | `/annotations/<family>/foo/index/N` | ✓ | a range endpoint is < 1 |
| `A3E_RANGE_ORDER` | element | `/annotations/<family>/foo/index/N` | ✓ | a range has `start >= end` |
| `A3E_RANGE_OVERLAP` | set | `/annotations/<family>/foo/index` | ✓ | two ranges in one index overlap |
| `A3E_VARIANT_POSITION_NOT_POSITIVE` | field | `/annotations/variant/N/position` | ✓ | a variant position is < 1 |

**Sorting is normalization, not a rule.** Positions are sorted ascending and
ranges are sorted by start (then by end) as part of parsing. An unsorted index is
valid and is sorted. There is no `A3E_POS_UNSORTED` or `A3E_RANGE_UNSORTED`.

**Duplication is a rule, not normalization.** Duplicate positions are rejected,
not deduplicated.

`A3E_POS_DUPLICATE` is emitted **once per distinct repeated value**, not once
per excess occurrence. An index of `[7, 7, 7]` produces one issue naming `7`.

Adjacent ranges do not overlap. `[1, 3]` and `[4, 8]` are fine; `[1, 3]` and
`[3, 8]` overlap. `A3E_RANGE_OVERLAP` is emitted **once per overlapping
consecutive pair** in the sorted index.

## Stage 4 — Contextual

All Stage 4 rules compare a value against the sequence, whose length is known
only because Stages 1–3 passed.

| Code | Kind | Path | Names value | Trigger |
|---|---|---|---|---|
| `A3E_POS_OUT_OF_BOUNDS` | element | `/annotations/<family>/foo/index/N` | ✓ | a position is greater than `length(sequence)` |
| `A3E_RANGE_OUT_OF_BOUNDS` | element | `/annotations/<family>/foo/index/N` | ✓ | a range endpoint is greater than `length(sequence)` |
| `A3E_VARIANT_OUT_OF_BOUNDS` | field | `/annotations/variant/N/position` | ✓ | a variant position is greater than `length(sequence)` |
| `A3E_VARIANT_RESIDUE_MISMATCH` | field | `/annotations/variant/N/from` | ✓ | a variant's `from` residue is not the residue at `position` |

`A3E_RANGE_OUT_OF_BOUNDS` points at the **range element**, not at the endpoint
inside it. Stage 3 has established `start < end`, so only `end` can exceed the
sequence length.

### `A3E_VARIANT_RESIDUE_MISMATCH`

`from` is an optional member of an open record. The rule fires only when:

- the record has a `from` member, **and**
- it is a string of exactly one character, **and**
- that character, compared case-insensitively, is not the residue at `position`

Absence of `from` is not an error. A `from` of any other shape — a number, a
three-letter code, an empty string, `"Arg"` — does not trigger the rule and is
preserved verbatim. The comparison is case-insensitive because `sequence` is
case-folded during normalization and `from` is not.

The rule detects a variant list whose coordinates refer to a different isoform
of the sequence.

---

## Coverage

Every code above is exercised by at least one case in
[`conformance/`](conformance/), in isolation. The corpus generator and the Rust
runner fail if a code has no case.
