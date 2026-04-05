import type { ZodError } from "zod";
import { A3_SCHEMA_URI, A3_VERSION, type A3Data, A3InputSchema, type VariantData } from "./schemas";

// ── Error classes ─────────────────────────────────────────────────────────────

export class A3ValidationError extends Error {
  readonly issues: ZodError["issues"];

  constructor(zodError: ZodError) {
    super(zodError.message);
    this.name = "A3ValidationError";
    this.issues = zodError.issues;
  }
}

export class A3ParseError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "A3ParseError";
  }
}

// ── A3 class ──────────────────────────────────────────────────────────────────

export class A3 {
  readonly #data: A3Data;

  constructor(input: unknown) {
    const result = A3InputSchema.safeParse(input);
    if (!result.success) throw new A3ValidationError(result.error);
    this.#data = Object.freeze(result.data);
  }

  // ── Static constructors ───────────────────────────────────────────────────

  static fromData(data: unknown): A3 {
    return new A3(data);
  }

  static fromJSONText(text: string): A3 {
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch (e) {
      throw new A3ParseError("Invalid JSON", { cause: e });
    }
    return new A3(parsed);
  }

  // readJSON is provided in io.ts and re-exported from index.ts

  // ── Accessors ─────────────────────────────────────────────────────────────

  /** Number of residues in the sequence. */
  get length(): number {
    return this.#data.sequence.length;
  }

  /**
   * Return the residue at a 1-based position.
   * Throws RangeError if position is out of bounds.
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
   * Return all variants at a given 1-based position.
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
   * Envelope fields ($schema, a3_version) are always emitted first.
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

  toString(): string {
    const seq = this.#data.sequence;
    const preview = seq.length > 12 ? `${seq.slice(0, 12)}…` : seq;
    const id = this.#data.metadata.uniprot_id;
    const label = id ? ` [${id}]` : "";
    return `A3${label} { length: ${this.length}, sequence: "${preview}" }`;
  }
}
