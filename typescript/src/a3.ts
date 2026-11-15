/**
 * The {@link A3} class and the two error types.
 *
 * @module
 */

import type { A3Issue } from "./issues.ts";
import { stageOf } from "./issues.ts";
import { isJsonCompatible } from "./normalize.ts";
import { A3_SCHEMA_URI, A3_VERSION, type A3Data, type VariantData } from "./schemas.ts";
import { validate } from "./validate.ts";

// ── Error classes ─────────────────────────────────────────────────────────────

/**
 * Thrown when an A3 document fails validation.
 *
 * The {@link A3ValidationError.issues} array carries every issue found in the
 * earliest failing validation stage. Each issue's `code` and `path` are
 * contractual and identical across the R, Python, Julia, TypeScript, and Rust
 * implementations; its `message` is not.
 *
 * @example
 * ```ts
 * try {
 *   A3.fromJSONText(text);
 * } catch (e) {
 *   if (e instanceof A3ValidationError) {
 *     for (const issue of e.issues) console.error(issue.code, issue.path);
 *   }
 * }
 * ```
 */
export class A3ValidationError extends Error {
  /** Every issue found in the earliest failing validation stage. */
  readonly issues: readonly A3Issue[];

  /**
   * Create an error from a non-empty issue list.
   * @param issues - The issues produced by {@link validate}.
   */
  constructor(issues: readonly A3Issue[]) {
    const detail = issues
      .map((i) => `  [${i.code}] ${i.path || "<document>"}: ${i.message}`)
      .join("\n");
    super(`A3 validation failed with ${issues.length} issue(s):\n${detail}`);
    this.name = "A3ValidationError";
    this.issues = issues;
  }

  /**
   * The validation stage the reported issues belong to, or `undefined` when the
   * issue list is empty.
   *
   * Every issue in one error comes from the same stage, because validation
   * short-circuits at a stage boundary.
   */
  get stage(): number | undefined {
    const first = this.issues[0];
    return first === undefined ? undefined : stageOf(first);
  }
}

/**
 * Thrown when raw input cannot be parsed before validation begins.
 *
 * Wraps `JSON.parse` failures and file I/O errors. A file that is not JSON has
 * no path to report and nothing further to collect, which is why it is a
 * distinct type rather than an issue. For rule violations on otherwise-valid
 * JSON, see {@link A3ValidationError}.
 */
export class A3ParseError extends Error {
  /**
   * Create an error for input that could not be parsed before validation.
   * @param message - Human-readable description of the parse failure.
   * @param options - Optional `cause` to chain the original error.
   */
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "A3ParseError";
  }
}

// ── A3 class ──────────────────────────────────────────────────────────────────

/**
 * An immutable, validated A3 (Amino Acid Annotation) object.
 *
 * Construct via the constructor or the static helpers {@link A3.fromData} /
 * {@link A3.fromJSONText}. For file I/O use `readJSON` / `writeJSON`. To
 * validate without throwing — for a form or a live-validation panel — call
 * {@link validate} directly and read its issue list.
 *
 * @example
 * ```ts
 * const a3 = A3.fromJSONText(jsonString);
 * console.log(a3.length);          // sequence length
 * console.log(a3.residueAt(1));    // first residue
 * console.log(a3.toJSONString());  // canonical JSON
 * ```
 */
export class A3 {
  readonly #data: A3Data;

  /**
   * Validate raw input as an A3 document.
   * @param input - Any value; typically a plain object parsed from JSON.
   * @throws {@link A3ValidationError} carrying every issue in the failing stage.
   */
  constructor(input: unknown) {
    const { data, issues } = validate(input);
    if (data === null) throw new A3ValidationError(issues);
    assertVariantsAreJsonCompatible(data);
    this.#data = Object.freeze(data);
  }

  // ── Static constructors ───────────────────────────────────────────────────

  /**
   * Validate a plain data object as an A3 instance.
   * @param data - Typically the result of `JSON.parse` or a hand-built object.
   * @throws {@link A3ValidationError} if validation fails.
   */
  static fromData(data: unknown): A3 {
    return new A3(data);
  }

  /**
   * Parse a JSON string and validate it as an A3 instance.
   * @param text - Raw JSON string.
   * @throws {@link A3ParseError} if the string is not valid JSON.
   * @throws {@link A3ValidationError} if the parsed value fails validation.
   */
  static fromJSONText(text: string): A3 {
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch (e) {
      throw new A3ParseError("Invalid JSON", { cause: e });
    }
    return new A3(parsed);
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  /** Number of residues in the sequence. */
  get length(): number {
    return this.#data.sequence.length;
  }

  /**
   * Return the residue at a 1-based position.
   * @param position - 1-based residue position.
   * @throws `RangeError` if position is out of bounds.
   */
  residueAt(position: number): string {
    if (!Number.isInteger(position) || position < 1 || position > this.length) {
      throw new RangeError(
        `position ${position} is out of bounds for sequence of length ${this.length} (must be 1–${this.length})`,
      );
    }
    return this.#data.sequence.charAt(position - 1);
  }

  /**
   * Return all variant records at a given 1-based position.
   * @param position - 1-based residue position.
   */
  variantsAt(position: number): VariantData[] {
    return this.#data.annotations.variant.filter((v) => v.position === position);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  /**
   * Return the canonical validated data object.
   * The returned reference is frozen — spread to get a mutable copy.
   */
  toData(): A3Data {
    return this.#data;
  }

  /**
   * Return the canonical data object for JSON serialization.
   * Called automatically by JSON.stringify — do not return a string here.
   */
  toJSON(): A3Data {
    return { ...this.#data, $schema: A3_SCHEMA_URI, a3_version: A3_VERSION };
  }

  /**
   * Serialize to a JSON string.
   * @param indent Number of spaces for indentation (default 2). Pass 0 for compact output.
   */
  toJSONString(indent = 2): string {
    return JSON.stringify(this, null, indent);
  }

  // ── Introspection ─────────────────────────────────────────────────────────

  /** Return a human-readable summary, e.g. `A3 [P12345] { length: 42, sequence: "MKTAYIAKQR…" }`. */
  toString(): string {
    const seq = this.#data.sequence;
    const preview = seq.length > 12 ? `${seq.slice(0, 12)}…` : seq;
    const id = this.#data.metadata.uniprot_id;
    const label = id ? ` [${id}]` : "";
    return `A3${label} { length: ${this.length}, sequence: "${preview}" }`;
  }
}

/**
 * Reject variant members that cannot survive serialization.
 *
 * A variant record is open, so its members are preserved verbatim — but a
 * function, a symbol, or a class instance would be silently dropped or mangled
 * by `JSON.stringify`, producing a document that does not round-trip.
 *
 * This is a constructor-path guard, not a validation rule: no such value can
 * come out of `JSON.parse`, so it has no A3 issue code and cannot appear in the
 * conformance corpus. It exists because TypeScript, unlike the other four
 * implementations, lets a caller hand a live JavaScript object straight to the
 * constructor. A `TypeError` is the idiomatic response to a value of the wrong
 * kind.
 */
function assertVariantsAreJsonCompatible(data: A3Data): void {
  data.annotations.variant.forEach((record, i) => {
    for (const [key, value] of Object.entries(record)) {
      if (!isJsonCompatible(value)) {
        throw new TypeError(
          `annotations.variant[${i}].${key} is not JSON-compatible: ${String(value)}. ` +
            `A variant record's members must be JSON values.`,
        );
      }
    }
  });
}
