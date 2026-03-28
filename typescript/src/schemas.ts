import { z } from "zod";
import { isJsonCompatible, sortDedup, sortRanges } from "./normalize";

// ── Primitives ────────────────────────────────────────────────────────────────

// 1-based positive integer position
const PositionSchema = z.number().int().min(1);

// Sorted, deduplicated array of positions
const PositionsSchema = z.array(PositionSchema).transform(sortDedup);

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
          code: z.ZodIssueCode.custom,
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

const SiteEntrySchema = z.object({
  index: PositionsSchema,
  type: z.string().default(""),
});

const RegionEntrySchema = z.object({
  index: RangesSchema,
  type: z.string().default(""),
});

const FlexEntrySchema = z.object({
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
    site: z.record(z.string().min(1), SiteEntrySchema).default({}),
    region: z.record(z.string().min(1), RegionEntrySchema).default({}),
    ptm: z.record(z.string().min(1), FlexEntrySchema).default({}),
    processing: z.record(z.string().min(1), FlexEntrySchema).default({}),
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

export const A3InputSchema = z
  .object({
    sequence: z
      .string()
      .min(2, "sequence must be at least 2 characters")
      .regex(/^[A-Za-z*]+$/, "sequence must contain only amino acid letters [A-Za-z] or '*'")
      .transform((s) => s.toUpperCase()),
    annotations: AnnotationsSchema.default({
      site: {},
      region: {},
      ptm: {},
      processing: {},
      variant: [],
    }),
    metadata: MetadataSchema.default({}),
  })
  .strict()
  .superRefine((data, ctx) => {
    const len = data.sequence.length;

    const boundsMsg = (pos: number) =>
      `position ${pos} is out of bounds for sequence of length ${len} (must be 1–${len})`;

    const checkPos = (pos: number, path: (string | number)[]) => {
      if (pos < 1 || pos > len)
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: boundsMsg(pos), path });
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
  });

// ── Exported types (inferred from schemas) ────────────────────────────────────

export type A3Data = z.infer<typeof A3InputSchema>;
export type MetadataData = z.infer<typeof MetadataSchema>;
export type VariantData = z.infer<typeof VariantSchema>;
export type SiteEntryData = z.infer<typeof SiteEntrySchema>;
export type RegionEntryData = z.infer<typeof RegionEntrySchema>;
export type FlexEntryData = z.infer<typeof FlexEntrySchema>;
