/**
 * Four-stage A3 validation over the raw parsed JSON.
 *
 * Validation runs against the plain value `JSON.parse` produces and emits the
 * contract's issues directly: exact `{code, path}` pairs, four stages that
 * short-circuit, and guard rules that suppress a subtree without suppressing
 * its siblings.
 *
 * **Within a stage, collect everything. Across stages, short-circuit.**
 *
 * ```text
 * JSON text
 *    │
 *    ├─ JSON.parse ─────────► A3ParseError (single, fatal, not collectable)
 *    ▼
 * unknown
 *    ├─ STAGE 1  envelope     document is an object, declares itself A3 1.0.0
 *    ├─ STAGE 2  structural   types, shapes, required members, charset, names
 *    ├─ STAGE 3  intra-field  positions ≥1/deduped, ranges ordered/disjoint
 *    ├─ STAGE 4  contextual   bounds vs sequence length, variant `from` residue
 *    ▼  (only if no stage produced an issue)
 * A3Data
 * ```
 *
 * Short-circuiting is a correctness requirement, not an optimization. A
 * document whose `sequence` fails Stage 2 has no known length, so Stage 4 would
 * emit one spurious out-of-bounds issue per annotated position.
 *
 * The full contract lives in `spec/error-codes.md` and `spec/error-paths.md`.
 *
 * @module
 */

import type { A3Issue, A3IssueCode } from "./issues.ts";
import { pointer } from "./issues.ts";
import {
  A3_SCHEMA_URI,
  A3_VERSION,
  type A3Data,
  type A3FlexData,
  type A3PositionData,
  type A3RangeData,
  type MetadataData,
  type VariantData,
} from "./schemas.ts";

const TOP_LEVEL_KEYS = ["$schema", "a3_version", "sequence", "annotations", "metadata"] as const;
const FAMILIES = ["site", "region", "ptm", "processing", "variant"] as const;
const NAMED_FAMILIES = ["site", "region", "ptm", "processing"] as const;
const ENTRY_KEYS = ["index", "type"] as const;
const METADATA_KEYS = ["uniprot_id", "description", "reference", "organism"] as const;

const SEQUENCE_CHARSET = /^[A-Z*]+$/;

type NamedFamily = (typeof NAMED_FAMILIES)[number];
type MetadataKey = (typeof METADATA_KEYS)[number];

/** The outcome of validating a raw value. */
export interface ValidationResult {
  /** The normalized document, or `null` when any issue was reported. */
  readonly data: A3Data | null;
  /**
   * Every issue found in the earliest stage that produced one. Empty on
   * success.
   */
  readonly issues: readonly A3Issue[];
}

/** An index whose geometry is settled but whose values are not yet checked. */
interface DraftEntry {
  /** JSON Pointer to this entry's `index`. */
  indexPath: string;
  geometry: "positions" | "ranges";
  /** Positions, or `[start, end]` pairs. Not yet range-checked. */
  index: number[] | [number, number][];
  type: string;
}

interface DraftVariant {
  /** JSON Pointer to this variant record. */
  path: string;
  position: number;
  extra: Record<string, unknown>;
}

interface Draft {
  sequence: string;
  site: Map<string, DraftEntry>;
  region: Map<string, DraftEntry>;
  ptm: Map<string, DraftEntry>;
  processing: Map<string, DraftEntry>;
  variant: DraftVariant[];
  metadata: MetadataData;
}

/**
 * Validate a raw parsed JSON value as an A3 document.
 *
 * @param raw - The output of `JSON.parse`. Any value, not necessarily an object.
 * @returns The normalized document and an empty issue list, or `null` and every
 *   issue found in the earliest stage that produced one.
 *
 * @example
 * ```ts
 * const { data, issues } = validate(JSON.parse(text));
 * if (data === null) for (const i of issues) console.error(i.code, i.path);
 * ```
 */
export function validate(raw: unknown): ValidationResult {
  const issues: A3Issue[] = [];

  // ── Stage 1 ───────────────────────────────────────────────────────────
  stage1Envelope(raw, issues);
  if (issues.length > 0) return { data: null, issues };
  const obj = raw as Record<string, unknown>;

  // ── Stage 2 ───────────────────────────────────────────────────────────
  const draft = stage2Structural(obj, issues);
  if (issues.length > 0) return { data: null, issues };

  // ── Stage 3 ───────────────────────────────────────────────────────────
  stage3IntraField(draft, issues);
  if (issues.length > 0) return { data: null, issues };

  // ── Stage 4 ───────────────────────────────────────────────────────────
  stage4Contextual(draft, issues);
  if (issues.length > 0) return { data: null, issues };

  return { data: build(draft), issues: [] };
}

// ===========================================================================
// Stage 1 — Envelope
// ===========================================================================

/**
 * Check that the document is an object declaring itself to be A3 1.0.0.
 *
 * When the root is not an object, `A3E_DOC_NOT_OBJECT` is the only issue
 * reported: nothing below it can be located.
 */
function stage1Envelope(raw: unknown, issues: A3Issue[]): void {
  if (!isPlainObject(raw)) {
    issues.push(
      issue("A3E_DOC_NOT_OBJECT", "", `an A3 document must be a JSON object, got ${render(raw)}`),
    );
    return;
  }
  checkConst(
    raw,
    "$schema",
    A3_SCHEMA_URI,
    "A3E_ENVELOPE_SCHEMA_MISSING",
    "A3E_ENVELOPE_SCHEMA_MISMATCH",
    issues,
  );
  checkConst(
    raw,
    "a3_version",
    A3_VERSION,
    "A3E_ENVELOPE_VERSION_MISSING",
    "A3E_ENVELOPE_VERSION_MISMATCH",
    issues,
  );
}

/**
 * Check one envelope member against its required constant value.
 *
 * A wrong type and a wrong value are the same failure: the schema declares both
 * members with `const`, and a `const` failure is one failure.
 */
function checkConst(
  obj: Record<string, unknown>,
  key: string,
  expected: string,
  missing: A3IssueCode,
  mismatch: A3IssueCode,
  issues: A3Issue[],
): void {
  const path = pointer("", key);
  if (!(key in obj)) {
    issues.push(issue(missing, path, `'${key}' is required and must be '${expected}'`));
  } else if (obj[key] !== expected) {
    issues.push(issue(mismatch, path, `'${key}' must be '${expected}', got ${render(obj[key])}`));
  }
}

// ===========================================================================
// Stage 2 — Structural
// ===========================================================================

/** Check every value's type and shape, and extract a draft document. */
function stage2Structural(obj: Record<string, unknown>, issues: A3Issue[]): Draft {
  unknownFields(obj, TOP_LEVEL_KEYS, "", issues);

  const draft: Draft = {
    sequence: stage2Sequence(obj, issues) ?? "",
    site: new Map(),
    region: new Map(),
    ptm: new Map(),
    processing: new Map(),
    variant: [],
    metadata: { uniprot_id: "", description: "", reference: "", organism: "" },
  };

  // `annotations` and `metadata` are optional; both default to empty.
  const annotations = obj.annotations;
  if (annotations !== undefined && annotations !== null) {
    if (!isPlainObject(annotations)) {
      issues.push(
        issue(
          "A3E_ANNOTATIONS_NOT_OBJECT",
          "/annotations",
          `'annotations' must be an object, got ${render(annotations)}`,
        ),
      );
    } else {
      stage2Annotations(annotations, draft, issues);
    }
  }

  const metadata = obj.metadata;
  if (metadata !== undefined && metadata !== null) {
    if (!isPlainObject(metadata)) {
      issues.push(
        issue(
          "A3E_METADATA_NOT_OBJECT",
          "/metadata",
          `'metadata' must be an object, got ${render(metadata)}`,
        ),
      );
    } else {
      draft.metadata = stage2Metadata(metadata, issues);
    }
  }

  return draft;
}

/** Extract and case-fold the sequence, checking its type, length, and charset. */
function stage2Sequence(obj: Record<string, unknown>, issues: A3Issue[]): string | null {
  if (!("sequence" in obj)) {
    issues.push(issue("A3E_SEQ_MISSING", "/sequence", "'sequence' is required"));
    return null;
  }
  const raw = obj.sequence;
  if (typeof raw !== "string") {
    issues.push(
      issue("A3E_SEQ_NOT_STRING", "/sequence", `'sequence' must be a string, got ${render(raw)}`),
    );
    return null;
  }

  const upper = raw.toUpperCase();
  if (upper.length < 2) {
    issues.push(
      issue(
        "A3E_SEQ_TOO_SHORT",
        "/sequence",
        `'sequence' must be at least 2 characters, got ${upper.length} ("${raw}")`,
      ),
    );
  }
  if (upper.length > 0 && !SEQUENCE_CHARSET.test(upper)) {
    const bad = [...upper].find((c) => !/[A-Z*]/.test(c));
    issues.push(
      issue(
        "A3E_SEQ_CHARSET",
        "/sequence",
        `'sequence' contains '${bad}'; only A-Z (IUPAC amino acid codes) and '*' (stop codon) are permitted`,
      ),
    );
  }
  return upper;
}

/** Parse the five annotation families. */
function stage2Annotations(
  annotations: Record<string, unknown>,
  draft: Draft,
  issues: A3Issue[],
): void {
  unknownFields(annotations, FAMILIES, "/annotations", issues);

  for (const family of NAMED_FAMILIES) {
    const entries = annotations[family];
    if (entries === undefined || entries === null) continue;
    const familyPath = pointer("/annotations", family);
    if (!isPlainObject(entries)) {
      issues.push(
        issue(
          "A3E_FAMILY_NOT_OBJECT",
          familyPath,
          `'annotations.${family}' must be an object, got ${render(entries)}`,
        ),
      );
      continue;
    }
    draft[family] = stage2Family(entries, family, familyPath, issues);
  }

  const records = annotations.variant;
  if (records !== undefined && records !== null) {
    if (!Array.isArray(records)) {
      issues.push(
        issue(
          "A3E_VARIANT_LIST_NOT_ARRAY",
          "/annotations/variant",
          `'annotations.variant' must be an array, got ${render(records)}`,
        ),
      );
    } else {
      draft.variant = stage2Variants(records, issues);
    }
  }
}

/**
 * Parse one named annotation family.
 *
 * `family` selects the permitted index geometry: `site` takes positions,
 * `region` takes ranges, and `ptm` / `processing` take either, homogeneously.
 */
function stage2Family(
  entries: Record<string, unknown>,
  family: NamedFamily,
  familyPath: string,
  issues: A3Issue[],
): Map<string, DraftEntry> {
  const out = new Map<string, DraftEntry>();

  for (const [name, raw] of Object.entries(entries)) {
    const entryPath = pointer(familyPath, name);

    if (name === "") {
      issues.push(
        issue(
          "A3E_NAME_EMPTY",
          entryPath,
          `'annotations.${family}' has an annotation named ""; names must not be empty`,
        ),
      );
      continue;
    }

    if (!isPlainObject(raw)) {
      issues.push(
        issue(
          "A3E_ENTRY_NOT_OBJECT",
          entryPath,
          `annotation "${name}" must be an object with an 'index' member, got ${render(raw)}`,
        ),
      );
      continue;
    }

    unknownFields(raw, ENTRY_KEYS, entryPath, issues);

    let type = "";
    const label = raw.type;
    if (label !== undefined && label !== null) {
      if (typeof label === "string") {
        type = label;
      } else {
        issues.push(
          issue(
            "A3E_ENTRY_TYPE_NOT_STRING",
            pointer(entryPath, "type"),
            `'type' must be a string, got ${render(label)}`,
          ),
        );
      }
    }

    const indexPath = pointer(entryPath, "index");
    if (!("index" in raw)) {
      issues.push(
        issue(
          "A3E_INDEX_MISSING",
          indexPath,
          `annotation "${name}" is missing its required 'index' member`,
        ),
      );
      continue;
    }
    const elements = raw.index;
    if (!Array.isArray(elements)) {
      issues.push(
        issue(
          "A3E_INDEX_NOT_ARRAY",
          indexPath,
          `'index' must be an array, got ${render(elements)}`,
        ),
      );
      continue;
    }

    const parsed = parseIndexElements(elements, family, indexPath, issues);
    if (parsed === null) continue;

    out.set(name, { indexPath, geometry: parsed.geometry, index: parsed.values, type });
  }

  return out;
}

/**
 * Settle an index's geometry and extract its values.
 *
 * Returns `null` when the index could not be interpreted; issues have already
 * been recorded in that case.
 */
function parseIndexElements(
  elements: unknown[],
  family: NamedFamily,
  indexPath: string,
  issues: A3Issue[],
): { geometry: "positions" | "ranges"; values: number[] | [number, number][] } | null {
  const flexible = family === "ptm" || family === "processing";

  // Classify every element first. Doing this up front is what makes the
  // mixed-geometry rule expressible: it is a property of the whole index.
  const kinds = elements.map(classify);

  let bad = false;
  kinds.forEach((kind, i) => {
    if (kind === "other") {
      bad = true;
      issues.push(
        issue(
          "A3E_INDEX_ELEMENT_TYPE",
          pointer(indexPath, i),
          `index element must be ${expectedShape(family)}, got ${render(elements[i])}`,
        ),
      );
    }
  });
  if (bad) return null;

  const nInt = kinds.filter((k) => k === "integer").length;
  const nArr = kinds.filter((k) => k === "array").length;

  let geometry: "positions" | "ranges";
  if (flexible) {
    if (nInt > 0 && nArr > 0) {
      issues.push(
        issue(
          "A3E_INDEX_MIXED",
          indexPath,
          `index mixes ${nInt} position(s) and ${nArr} range(s); a ptm or processing index must be ` +
            `all positions or all ranges`,
        ),
      );
      return null;
    }
    geometry = nArr > 0 ? "ranges" : "positions";
  } else {
    geometry = family === "region" ? "ranges" : "positions";
    // A well-formed element of the *other* geometry is still wrong for a family
    // whose geometry the schema fixes.
    const want = geometry === "ranges" ? "array" : "integer";
    let wrong = false;
    kinds.forEach((kind, i) => {
      if (kind !== want) {
        wrong = true;
        issues.push(
          issue(
            "A3E_INDEX_ELEMENT_TYPE",
            pointer(indexPath, i),
            `index element must be ${expectedShape(family)}, got ${render(elements[i])}`,
          ),
        );
      }
    });
    if (wrong) return null;
  }

  if (geometry === "positions") {
    return { geometry, values: elements.map((v) => v as number) };
  }

  const ranges: [number, number][] = [];
  let ok = true;
  elements.forEach((element, i) => {
    const pair = element as unknown[];
    const elemPath = pointer(indexPath, i);
    if (pair.length !== 2) {
      issues.push(
        issue(
          "A3E_RANGE_ARITY",
          elemPath,
          `a range must be a 2-element [start, end] array, got ${pair.length} element(s)`,
        ),
      );
      ok = false;
      return;
    }
    if (classify(pair[0]) !== "integer" || classify(pair[1]) !== "integer") {
      issues.push(
        issue(
          "A3E_RANGE_ENDPOINT_NOT_INTEGER",
          elemPath,
          `range endpoints must be integers, got [${render(pair[0])}, ${render(pair[1])}]`,
        ),
      );
      ok = false;
      return;
    }
    ranges.push([pair[0] as number, pair[1] as number]);
  });
  return ok ? { geometry, values: ranges } : null;
}

/** Parse the variant list. Every member beyond `position` is open. */
function stage2Variants(records: unknown[], issues: A3Issue[]): DraftVariant[] {
  const out: DraftVariant[] = [];

  records.forEach((raw, i) => {
    const path = pointer("/annotations/variant", i);

    if (!isPlainObject(raw)) {
      issues.push(
        issue(
          "A3E_VARIANT_NOT_OBJECT",
          path,
          `a variant record must be an object, got ${render(raw)}`,
        ),
      );
      return;
    }

    const positionPath = pointer(path, "position");
    if (!("position" in raw)) {
      issues.push(
        issue(
          "A3E_VARIANT_POSITION_MISSING",
          positionPath,
          "a variant record is missing its required 'position' member",
        ),
      );
      return;
    }
    if (classify(raw.position) !== "integer") {
      issues.push(
        issue(
          "A3E_VARIANT_POSITION_NOT_INTEGER",
          positionPath,
          `'position' must be an integer, got ${render(raw.position)}`,
        ),
      );
      return;
    }

    // A variant record is open: every other member is preserved verbatim, in
    // document order, and is not type-checked.
    const extra: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(raw)) {
      if (key !== "position") extra[key] = value;
    }
    out.push({ path, position: raw.position as number, extra });
  });

  return out;
}

/** Extract the four metadata members, checking only that each is a string. */
function stage2Metadata(metadata: Record<string, unknown>, issues: A3Issue[]): MetadataData {
  unknownFields(metadata, METADATA_KEYS, "/metadata", issues);

  const out = { uniprot_id: "", description: "", reference: "", organism: "" };
  for (const key of METADATA_KEYS) {
    const value = metadata[key];
    if (value === undefined || value === null) continue;
    if (typeof value === "string") {
      out[key satisfies MetadataKey] = value;
    } else {
      issues.push(
        issue(
          "A3E_METADATA_FIELD_NOT_STRING",
          pointer("/metadata", key),
          `'metadata.${key}' must be a string, got ${render(value)}`,
        ),
      );
    }
  }
  return out;
}

// ===========================================================================
// Stage 3 — Intra-field
// ===========================================================================

/**
 * Sort every index, then check that each is internally consistent.
 *
 * Sorting happens here rather than in Stage 2 because an index cannot be sorted
 * until its elements are known to be sortable, and it must be sorted before
 * duplication and overlap can be checked. Every subscript reported by this
 * stage and by Stage 4 therefore names the *sorted* array.
 */
function stage3IntraField(draft: Draft, issues: A3Issue[]): void {
  for (const entry of draftEntries(draft)) {
    if (entry.geometry === "positions") {
      (entry.index as number[]).sort((a, b) => a - b);
    } else {
      (entry.index as [number, number][]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    }
  }

  for (const entry of draftEntries(draft)) {
    const { indexPath } = entry;
    if (entry.geometry === "positions") {
      const positions = entry.index as number[];
      positions.forEach((p, i) => {
        if (p < 1) {
          issues.push(
            issue(
              "A3E_POS_NOT_POSITIVE",
              pointer(indexPath, i),
              `position ${p} must be >= 1; positions are 1-based`,
            ),
          );
        }
      });
      // One issue per distinct repeated value, not per excess occurrence:
      // [7, 7, 7] is one mistake, not two.
      const seen = new Set<number>();
      for (let i = 1; i < positions.length; i++) {
        const value = positions[i] as number;
        if (value === positions[i - 1] && !seen.has(value)) {
          seen.add(value);
          issues.push(
            issue(
              "A3E_POS_DUPLICATE",
              indexPath,
              `position ${value} appears more than once; duplicates are rejected, not merged`,
            ),
          );
        }
      }
    } else {
      const ranges = entry.index as [number, number][];
      ranges.forEach(([start, end], i) => {
        const elemPath = pointer(indexPath, i);
        if (start < 1 || end < 1) {
          issues.push(
            issue(
              "A3E_RANGE_ENDPOINT_NOT_POSITIVE",
              elemPath,
              `range [${start}, ${end}] has an endpoint below 1; positions are 1-based`,
            ),
          );
        }
        if (start >= end) {
          issues.push(
            issue(
              "A3E_RANGE_ORDER",
              elemPath,
              `range [${start}, ${end}] must satisfy start < end; a single residue belongs in a ` +
                `position-indexed family`,
            ),
          );
        }
      });
      for (let i = 1; i < ranges.length; i++) {
        const prev = ranges[i - 1] as [number, number];
        const curr = ranges[i] as [number, number];
        // Sorted by start, so they overlap exactly when the second starts at or
        // before the first ends.
        if (curr[0] <= prev[1]) {
          issues.push(
            issue(
              "A3E_RANGE_OVERLAP",
              indexPath,
              `ranges [${prev[0]}, ${prev[1]}] and [${curr[0]}, ${curr[1]}] overlap; adjacent ranges are ` +
                `permitted but overlapping ones are not`,
            ),
          );
        }
      }
    }
  }

  for (const variant of draft.variant) {
    if (variant.position < 1) {
      issues.push(
        issue(
          "A3E_VARIANT_POSITION_NOT_POSITIVE",
          pointer(variant.path, "position"),
          `position ${variant.position} must be >= 1; positions are 1-based`,
        ),
      );
    }
  }
}

// ===========================================================================
// Stage 4 — Contextual
// ===========================================================================

/**
 * Check every value against the sequence, whose length is known only because
 * Stages 1-3 all passed.
 */
function stage4Contextual(draft: Draft, issues: A3Issue[]): void {
  const n = draft.sequence.length;

  for (const entry of draftEntries(draft)) {
    const { indexPath } = entry;
    if (entry.geometry === "positions") {
      (entry.index as number[]).forEach((p, i) => {
        if (p > n) {
          issues.push(
            issue(
              "A3E_POS_OUT_OF_BOUNDS",
              pointer(indexPath, i),
              `position ${p} is out of bounds for a sequence of length ${n} (must be 1-${n})`,
            ),
          );
        }
      });
    } else {
      // Stage 3 established start < end, so only `end` can exceed `n`.
      (entry.index as [number, number][]).forEach(([start, end], i) => {
        if (end > n) {
          issues.push(
            issue(
              "A3E_RANGE_OUT_OF_BOUNDS",
              pointer(indexPath, i),
              `range [${start}, ${end}] is out of bounds for a sequence of length ${n} (must be within 1-${n})`,
            ),
          );
        }
      });
    }
  }

  for (const variant of draft.variant) {
    const { position } = variant;
    if (position > n) {
      issues.push(
        issue(
          "A3E_VARIANT_OUT_OF_BOUNDS",
          pointer(variant.path, "position"),
          `position ${position} is out of bounds for a sequence of length ${n} (must be 1-${n})`,
        ),
      );
      continue;
    }
    // The residue rule is deliberately narrow: it fires only when `from` is
    // present *and* is a single character. `from` is an optional member of an
    // open record, so any other shape is not this rule's problem.
    const from = variant.extra.from;
    if (typeof from !== "string" || from.length !== 1) continue;
    const actual = draft.sequence.charAt(position - 1);
    // Case-insensitive because `sequence` is case-folded during normalization
    // and `from` is not.
    if (from.toUpperCase() !== actual) {
      issues.push(
        issue(
          "A3E_VARIANT_RESIDUE_MISMATCH",
          pointer(variant.path, "from"),
          `'from' is '${from}' but residue ${position} of the sequence is '${actual}'; the variant list ` +
            `may be annotated against a different isoform`,
        ),
      );
    }
  }
}

// ===========================================================================
// Construction
// ===========================================================================

/**
 * Assemble the normalized document.
 *
 * Every invariant this relies on was established by the four stages. Member
 * order is the canonical one: schema-defined members in schema order, and
 * author-supplied keys in document order.
 */
function build(draft: Draft): A3Data {
  const positionFamily = (entries: Map<string, DraftEntry>): Record<string, A3PositionData> => {
    const out: Record<string, A3PositionData> = {};
    for (const [name, e] of entries) out[name] = { index: e.index as number[], type: e.type };
    return out;
  };
  const rangeFamily = (entries: Map<string, DraftEntry>): Record<string, A3RangeData> => {
    const out: Record<string, A3RangeData> = {};
    for (const [name, e] of entries)
      out[name] = { index: e.index as [number, number][], type: e.type };
    return out;
  };
  const flexFamily = (entries: Map<string, DraftEntry>): Record<string, A3FlexData> => {
    const out: Record<string, A3FlexData> = {};
    for (const [name, e] of entries) out[name] = { index: e.index, type: e.type };
    return out;
  };

  return {
    $schema: A3_SCHEMA_URI,
    a3_version: A3_VERSION,
    sequence: draft.sequence,
    annotations: {
      site: positionFamily(draft.site),
      region: rangeFamily(draft.region),
      ptm: flexFamily(draft.ptm),
      processing: flexFamily(draft.processing),
      variant: draft.variant.map((v) => ({ position: v.position, ...v.extra }) as VariantData),
    },
    metadata: draft.metadata,
  };
}

// ===========================================================================
// Helpers
// ===========================================================================

function issue(code: A3IssueCode, path: string, message: string): A3Issue {
  return { code, path, message };
}

/** Every named entry across the four named families, in family order. */
function* draftEntries(draft: Draft): Generator<DraftEntry> {
  for (const family of NAMED_FAMILIES) yield* draft[family].values();
}

/**
 * A JSON object, as opposed to an array or `null`.
 *
 * `typeof null === "object"` in JavaScript, and arrays are objects, so both
 * have to be excluded explicitly.
 */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Classify an index element as `integer`, `array`, or `other`.
 *
 * JSON has no integer type distinct from number, and JSON Schema's
 * `type: "integer"` accepts any number with a zero fractional part, so `3.0` is
 * the position 3 while `2.5` is not a position at all. `true` is a boolean, not
 * a number, so it is never a position.
 */
function classify(value: unknown): "integer" | "array" | "other" {
  if (Array.isArray(value)) return "array";
  if (typeof value === "number" && Number.isInteger(value)) return "integer";
  return "other";
}

function expectedShape(family: NamedFamily): string {
  if (family === "site") return "an integer position";
  if (family === "region") return "a [start, end] range";
  return "an integer position or a [start, end] range";
}

/** Report one `A3E_UNKNOWN_FIELD` per property outside `allowed`. */
function unknownFields(
  obj: Record<string, unknown>,
  allowed: readonly string[],
  base: string,
  issues: A3Issue[],
): void {
  for (const key of Object.keys(obj)) {
    if (!allowed.includes(key)) {
      issues.push(
        issue(
          "A3E_UNKNOWN_FIELD",
          pointer(base, key),
          `'${key}' is not a permitted member here; expected one of: ${allowed.join(", ")}`,
        ),
      );
    }
  }
}

/** Render a JSON value compactly for a human message, truncating long ones. */
function render(value: unknown): string {
  if (value === undefined) return "undefined";
  const text = JSON.stringify(value) ?? String(value);
  return text.length > 40 ? `${text.slice(0, 39)}…` : text;
}
