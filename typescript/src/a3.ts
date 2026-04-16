import { z } from "zod";
import { isJsonCompatible, sortRanges } from "./normalize";
import { A3_SCHEMA_URI, A3_VERSION, type A3Data, type VariantData } from "./schemas";

// ── Internal Zod schemas ──────────────────────────────────────────────────────
// These are implementation details and are intentionally not exported.

const PositionSchema = z.number().int().min(1);

const PositionsSchema = z
  .array(PositionSchema)
  .transform((arr) => [...arr].sort((a, b) => a - b))
  .superRefine((sorted, ctx) => {
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i] === sorted[i - 1]) {
        ctx.addIssue({
          code: "custom",
          message: `duplicate position: ${sorted[i]}`,
        });
      }
    }
  });

const RangeTupleSchema = z
  .tuple([PositionSchema, PositionSchema])
  .refine(([s, e]) => s < e, { message: "start must be < end" });

const RangesSchema = z
  .array(RangeTupleSchema)
  .transform(sortRanges)
  .superRefine((ranges, ctx) => {
    let prev: [number, number] | undefined;
    for (const curr of ranges) {
      if (prev !== undefined && curr[0] <= prev[1]) {
        ctx.addIssue({
          code: "custom",
          message: `ranges [${prev[0]},${prev[1]}] and [${curr[0]},${curr[1]}] overlap`,
        });
      }
      prev = curr;
    }
  });

const A3PositionSchema = z.object({
  index: PositionsSchema,
  type: z.string().default(""),
});

const A3RangeSchema = z.object({
  index: RangesSchema,
  type: z.string().default(""),
});

const A3FlexSchema = z.object({
  index: z.union([RangesSchema, PositionsSchema]),
  type: z.string().default(""),
});

const VariantSchema = z
  .object({ position: PositionSchema })
  .catchall(z.unknown())
  .refine((v) => isJsonCompatible(v), { message: "variant fields must be JSON-compatible" });

const AnnotationsSchema = z
  .object({
    site: z.record(z.string().min(1), A3PositionSchema).default({}),
    region: z.record(z.string().min(1), A3RangeSchema).default({}),
    ptm: z.record(z.string().min(1), A3FlexSchema).default({}),
    processing: z.record(z.string().min(1), A3FlexSchema).default({}),
    variant: z.array(VariantSchema).default([]),
  })
  .strict();

const MetadataSchema = z
  .object({
    uniprot_id: z.string().default(""),
    description: z.string().default(""),
    reference: z.string().default(""),
    organism: z.string().default(""),
  })
  .strict();

export const A3InputSchema: z.ZodType<A3Data> = z
  .object({
    $schema: z.literal(A3_SCHEMA_URI, {
      error: () => ({ message: `'$schema' must be '${A3_SCHEMA_URI}'` }),
    }),
    a3_version: z.literal(A3_VERSION, {
      error: () => ({ message: `'a3_version' must be '${A3_VERSION}'` }),
    }),
    sequence: z
      .string()
      .min(2, "sequence must be at least 2 characters")
      .regex(/^[A-Za-z*]+$/, "sequence must contain only amino acid letters [A-Za-z] or '*'")
      .transform((s) => s.toUpperCase()),
    annotations: AnnotationsSchema,
    metadata: MetadataSchema,
  })
  .strict()
  .superRefine((data, ctx) => {
    const len = data.sequence.length;

    const boundsMsg = (pos: number) =>
      `position ${pos} is out of bounds for sequence of length ${len} (must be 1–${len})`;

    const checkPos = (pos: number, path: (string | number)[]) => {
      if (pos < 1 || pos > len) ctx.addIssue({ code: "custom", message: boundsMsg(pos), path });
    };

    const checkIndex = (index: number[] | [number, number][], basePath: (string | number)[]) => {
      if (index.length === 0) return;
      if (Array.isArray(index[0])) {
        let i = 0;
        for (const [s, e] of index as [number, number][]) {
          checkPos(s, [...basePath, i, 0]);
          checkPos(e, [...basePath, i, 1]);
          i++;
        }
      } else {
        let i = 0;
        for (const pos of index as number[]) {
          checkPos(pos, [...basePath, i]);
          i++;
        }
      }
    };

    for (const [name, entry] of Object.entries(data.annotations.site)) {
      checkIndex(entry.index, ["annotations", "site", name, "index"]);
    }
    for (const [name, entry] of Object.entries(data.annotations.region)) {
      checkIndex(entry.index, ["annotations", "region", name, "index"]);
    }
    for (const [name, entry] of Object.entries(data.annotations.ptm)) {
      checkIndex(entry.index, ["annotations", "ptm", name, "index"]);
    }
    for (const [name, entry] of Object.entries(data.annotations.processing)) {
      checkIndex(entry.index, ["annotations", "processing", name, "index"]);
    }
    data.annotations.variant.forEach((v, i) => {
      checkPos(v.position, ["annotations", "variant", i, "position"]);
    });
  }) as z.ZodType<A3Data>;

// ── Error classes ─────────────────────────────────────────────────────────────

/** A single validation issue reported for an invalid A3 document. */
export interface A3ValidationIssue {
  /** Machine-readable validation issue code. */
  readonly code: string;
  /** Human-readable validation message. */
  readonly message: string;
  /** Path to the invalid field within the input value. */
  readonly path: readonly PropertyKey[];
}

/**
 * Thrown when an A3 object fails schema validation.
 *
 * The `issues` array contains the full Zod issue list and can be inspected
 * programmatically to determine exactly which fields failed and why.
 */
export class A3ValidationError extends Error {
  /** Full list of Zod validation issues for programmatic inspection. */
  readonly issues: readonly A3ValidationIssue[];

  /**
   * Create an error from a failed schema validation result.
   * @param zodError - The Zod error produced by a failed `safeParse` call.
   */
  constructor(zodError: {
    readonly message: string;
    readonly issues: readonly A3ValidationIssue[];
  }) {
    super(zodError.message);
    this.name = "A3ValidationError";
    this.issues = zodError.issues;
  }
}

/**
 * Thrown when raw input cannot be parsed before validation begins.
 *
 * Wraps `JSON.parse` failures and file I/O errors. For schema violations
 * on otherwise-valid JSON, see {@link A3ValidationError}.
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
 * {@link A3.fromJSONText}. For file I/O use {@link readJSON} / {@link writeJSON}.
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
   * Parse and validate raw input as an A3 object.
   * @param input - Any value; typically a plain object parsed from JSON.
   * @throws {@link A3ValidationError} if the input fails schema validation.
   */
  constructor(input: unknown) {
    const result = A3InputSchema.safeParse(input);
    if (!result.success) throw new A3ValidationError(result.error);
    this.#data = Object.freeze(result.data);
  }

  // ── Static constructors ───────────────────────────────────────────────────

  /**
   * Parse and validate a plain data object as an A3 instance.
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
   * @throws {@link A3ValidationError} if the parsed object fails validation.
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

  // readJSON is provided in io.ts and re-exported from index.ts

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

  /** Return a human-readable summary, e.g. `A3 [P12345] { length: 42, sequence: "MKTAYIAKQR…" }`. */
  toString(): string {
    const seq = this.#data.sequence;
    const preview = seq.length > 12 ? `${seq.slice(0, 12)}…` : seq;
    const id = this.#data.metadata.uniprot_id;
    const label = id ? ` [${id}]` : "";
    return `A3${label} { length: ${this.length}, sequence: "${preview}" }`;
  }
}
