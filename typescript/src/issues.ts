/**
 * Validation issues: stable codes, RFC 6901 paths, and human messages.
 *
 * The contract is defined in [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) and
 * [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md), and is shared by all five A3 implementations. An issue's
 * `code` and `path` are contractual; its `message` is not and may be reworded
 * freely.
 *
 * @module
 */

/**
 * The validation stage a rule belongs to.
 *
 * Written out rather than derived from {@link A3_ISSUE_STAGES} because JSR
 * requires every exported symbol to carry an explicit type — an inferred one
 * makes the package "slow types" and blocks publishing.
 */
export type A3Stage = 1 | 2 | 3 | 4;

/**
 * A stable, machine-readable validation issue code.
 *
 * Codes are never renumbered and never reused. See
 * [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) for the full registry, including each code's trigger condition and the path it
 * reports.
 */
export type A3IssueCode =
  // ── Stage 1 — Envelope ──────────────────────────────────────────────────
  | "A3E_DOC_NOT_OBJECT"
  | "A3E_ENVELOPE_SCHEMA_MISSING"
  | "A3E_ENVELOPE_SCHEMA_MISMATCH"
  | "A3E_ENVELOPE_VERSION_MISSING"
  | "A3E_ENVELOPE_VERSION_MISMATCH"

  // ── Stage 2 — Structural ────────────────────────────────────────────────
  | "A3E_UNKNOWN_FIELD"
  | "A3E_SEQ_MISSING"
  | "A3E_SEQ_NOT_STRING"
  | "A3E_SEQ_TOO_SHORT"
  | "A3E_SEQ_CHARSET"
  | "A3E_ANNOTATIONS_NOT_OBJECT"
  | "A3E_METADATA_NOT_OBJECT"
  | "A3E_METADATA_FIELD_NOT_STRING"
  | "A3E_FAMILY_NOT_OBJECT"
  | "A3E_VARIANT_LIST_NOT_ARRAY"
  | "A3E_NAME_EMPTY"
  | "A3E_ENTRY_NOT_OBJECT"
  | "A3E_ENTRY_TYPE_NOT_STRING"
  | "A3E_INDEX_MISSING"
  | "A3E_INDEX_NOT_ARRAY"
  | "A3E_INDEX_ELEMENT_TYPE"
  | "A3E_INDEX_MIXED"
  | "A3E_RANGE_ARITY"
  | "A3E_RANGE_ENDPOINT_NOT_INTEGER"
  | "A3E_VARIANT_NOT_OBJECT"
  | "A3E_VARIANT_POSITION_MISSING"
  | "A3E_VARIANT_POSITION_NOT_INTEGER"

  // ── Stage 3 — Intra-field ───────────────────────────────────────────────
  | "A3E_POS_NOT_POSITIVE"
  | "A3E_POS_DUPLICATE"
  | "A3E_RANGE_ENDPOINT_NOT_POSITIVE"
  | "A3E_RANGE_ORDER"
  | "A3E_RANGE_OVERLAP"
  | "A3E_VARIANT_POSITION_NOT_POSITIVE"

  // ── Stage 4 — Contextual ────────────────────────────────────────────────
  | "A3E_POS_OUT_OF_BOUNDS"
  | "A3E_RANGE_OUT_OF_BOUNDS"
  | "A3E_VARIANT_OUT_OF_BOUNDS"
  | "A3E_VARIANT_RESIDUE_MISMATCH";

/**
 * Every A3 validation issue code, mapped to the stage it belongs to.
 *
 * Typing this as a total `Record` over {@link A3IssueCode} makes the two
 * declarations check each other: a code in the union with no stage here, or a
 * stage here for a code not in the union, is a compile error.
 */
export const A3_ISSUE_STAGES: Readonly<Record<A3IssueCode, A3Stage>> = {
  // ── Stage 1 — Envelope ──────────────────────────────────────────────────
  A3E_DOC_NOT_OBJECT: 1,
  A3E_ENVELOPE_SCHEMA_MISSING: 1,
  A3E_ENVELOPE_SCHEMA_MISMATCH: 1,
  A3E_ENVELOPE_VERSION_MISSING: 1,
  A3E_ENVELOPE_VERSION_MISMATCH: 1,

  // ── Stage 2 — Structural ────────────────────────────────────────────────
  A3E_UNKNOWN_FIELD: 2,
  A3E_SEQ_MISSING: 2,
  A3E_SEQ_NOT_STRING: 2,
  A3E_SEQ_TOO_SHORT: 2,
  A3E_SEQ_CHARSET: 2,
  A3E_ANNOTATIONS_NOT_OBJECT: 2,
  A3E_METADATA_NOT_OBJECT: 2,
  A3E_METADATA_FIELD_NOT_STRING: 2,
  A3E_FAMILY_NOT_OBJECT: 2,
  A3E_VARIANT_LIST_NOT_ARRAY: 2,
  A3E_NAME_EMPTY: 2,
  A3E_ENTRY_NOT_OBJECT: 2,
  A3E_ENTRY_TYPE_NOT_STRING: 2,
  A3E_INDEX_MISSING: 2,
  A3E_INDEX_NOT_ARRAY: 2,
  A3E_INDEX_ELEMENT_TYPE: 2,
  A3E_INDEX_MIXED: 2,
  A3E_RANGE_ARITY: 2,
  A3E_RANGE_ENDPOINT_NOT_INTEGER: 2,
  A3E_VARIANT_NOT_OBJECT: 2,
  A3E_VARIANT_POSITION_MISSING: 2,
  A3E_VARIANT_POSITION_NOT_INTEGER: 2,

  // ── Stage 3 — Intra-field ───────────────────────────────────────────────
  A3E_POS_NOT_POSITIVE: 3,
  A3E_POS_DUPLICATE: 3,
  A3E_RANGE_ENDPOINT_NOT_POSITIVE: 3,
  A3E_RANGE_ORDER: 3,
  A3E_RANGE_OVERLAP: 3,
  A3E_VARIANT_POSITION_NOT_POSITIVE: 3,

  // ── Stage 4 — Contextual ────────────────────────────────────────────────
  A3E_POS_OUT_OF_BOUNDS: 4,
  A3E_RANGE_OUT_OF_BOUNDS: 4,
  A3E_VARIANT_OUT_OF_BOUNDS: 4,
  A3E_VARIANT_RESIDUE_MISMATCH: 4,
};

/** Every code in the registry, for coverage checks. */
export const A3_ISSUE_CODES: readonly A3IssueCode[] = Object.keys(A3_ISSUE_STAGES) as A3IssueCode[];

/** A single validation issue. */
export interface A3Issue {
  /** Stable machine-readable code. Contractual. */
  readonly code: A3IssueCode;
  /** RFC 6901 JSON Pointer to the offending value. Contractual. */
  readonly path: string;
  /** Human-readable explanation. Not contractual; may be reworded freely. */
  readonly message: string;
}

/** The validation stage an issue belongs to. */
export function stageOf(issue: A3Issue): A3Stage {
  return A3_ISSUE_STAGES[issue.code];
}

/**
 * Escape one reference token for inclusion in a JSON Pointer.
 *
 * RFC 6901 escapes exactly two characters. `~` must be replaced before `/`, or
 * a key containing `/` would come out as `~01` instead of `~1`.
 */
export function escapeToken(token: string): string {
  return token.replaceAll("~", "~0").replaceAll("/", "~1");
}

/**
 * Append one reference token or array subscript to a JSON Pointer.
 *
 * @param base - The pointer to extend. The empty string denotes the document root.
 * @param token - A **raw** object member name, which this function escapes, or a
 *   0-based array subscript, which needs no escaping. Do not pre-escape a name:
 *   `pointer(b, "a~1b")` yields `a~01b`, because the `~` is escaped a second time.
 *
 * @example
 * ```ts
 * pointer("/annotations/site", "a/b"); // "/annotations/site/a~1b"  (escaped)
 * pointer("", "$schema");              // "/$schema"                (nothing to escape)
 * pointer("/annotations/variant", 3);  // "/annotations/variant/3"  (subscript)
 * ```
 */
export function pointer(base: string, token: string | number): string {
  return typeof token === "number" ? `${base}/${token}` : `${base}/${escapeToken(token)}`;
}

/**
 * Resolve a JSON Pointer against a parsed document.
 *
 * Returns `undefined` when the pointer does not resolve — which for a
 * missing-member issue is the expected outcome, not a failure. See
 * [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md), Rule 1.
 */
export function resolvePointer(document: unknown, path: string): unknown {
  if (path === "") return document;
  let current: unknown = document;
  for (const raw of path.slice(1).split("/")) {
    const token = raw.replaceAll("~1", "/").replaceAll("~0", "~");
    if (Array.isArray(current)) {
      current = current[Number(token)];
    } else if (current !== null && typeof current === "object") {
      current = (current as Record<string, unknown>)[token];
    } else {
      return undefined;
    }
    if (current === undefined) return undefined;
  }
  return current;
}
