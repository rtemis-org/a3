import { z } from "zod";
import { isJsonCompatible, sortRanges } from "./normalize";

// ── Envelope constants ────────────────────────────────────────────────────────

const A3_SCHEMA_URI = "https://schema.rtemis.org/a3/v1/schema.json";
const A3_VERSION = "1.0.0";

export { A3_SCHEMA_URI, A3_VERSION };

// ── Exported TypeScript interfaces ────────────────────────────────────────────

/** Metadata fields for an A3 object. All fields default to `""` when absent. */
export interface MetadataData {
  uniprot_id: string;
  description: string;
  reference: string;
  organism: string;
}

/**
 * A single variant record. `position` is required; all other fields are
 * open and must be JSON-compatible.
 */
export interface VariantData {
  position: number;
  [key: string]: unknown;
}

/** Annotation entry with a position-based index (site family). */
export interface A3PositionData {
  index: number[];
  type: string;
}

/** Annotation entry with a range-based index (region family). */
export interface A3RangeData {
  index: [number, number][];
  type: string;
}

/** Annotation entry with either a position or range index (ptm / processing families). */
export interface A3FlexData {
  index: number[] | [number, number][];
  type: string;
}

/** Fully validated and normalized A3 data object, as returned by {@link A3.toData}. */
export interface A3Data {
  $schema: typeof A3_SCHEMA_URI;
  a3_version: typeof A3_VERSION;
  sequence: string;
  annotations: {
    site: Record<string, A3PositionData>;
    region: Record<string, A3RangeData>;
    ptm: Record<string, A3FlexData>;
    processing: Record<string, A3FlexData>;
    variant: VariantData[];
  };
  metadata: MetadataData;
}

// ── Primitives ────────────────────────────────────────────────────────────────

// 1-based positive integer position
const PositionSchema = z.number().int().min(1);

// Sorted array of positions; duplicate positions are rejected
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

// Inclusive [start, end] range tuple, start < end
const RangeTupleSchema = z
  .tuple([PositionSchema, PositionSchema])
  .refine(([s, e]) => s < e, { message: "start must be < end" });

// Sorted array of ranges; overlapping ranges are rejected
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

// ── Annotation entry schemas ──────────────────────────────────────────────────
//
// Canonical form only: { index, type }.
// Site: always positions. Region: always ranges.
// PTM / Processing: either positions or ranges (never mixed within one entry).
// Union order matters — ranges branch is tried first (more specific).

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

// ── Variant ───────────────────────────────────────────────────────────────────

// Every variant requires `position`; additional JSON-compatible fields are allowed.
const VariantSchema = z
  .object({ position: PositionSchema })
  .catchall(z.unknown())
  .refine((v) => isJsonCompatible(v), { message: "variant fields must be JSON-compatible" });

// ── Annotation families ───────────────────────────────────────────────────────

const AnnotationsSchema = z
  .object({
    site: z.record(z.string().min(1), A3PositionSchema).default({}),
    region: z.record(z.string().min(1), A3RangeSchema).default({}),
    ptm: z.record(z.string().min(1), A3FlexSchema).default({}),
    processing: z.record(z.string().min(1), A3FlexSchema).default({}),
    variant: z.array(VariantSchema).default([]),
  })
  .strict();

// ── Metadata ──────────────────────────────────────────────────────────────────

const MetadataSchema = z
  .object({
    uniprot_id: z.string().default(""),
    description: z.string().default(""),
    reference: z.string().default(""),
    organism: z.string().default(""),
  })
  .strict();

// ── Root schema ───────────────────────────────────────────────────────────────

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
