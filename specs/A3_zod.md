# A3 Zod Specification

Amino Acid Annotation (A3) format — TypeScript/Zod implementation design.

## Requirements

- Strict canonical format only — no legacy input accommodation
- Runtime validation via Zod (TypeScript types are compile-time only)
- Immutable value objects (`Object.freeze` at construction)
- Serialize to JSON (top priority); TOML deferred
- Primary consumer: rtemislive-draw Next.js visualization app
- 100% wire-format compatible with the R implementation

## Tooling

- Package manager: `pnpm`
- Formatter / linter: `biome`
- Test runner: `vitest`
- Validation: `zod ^3`

## Type Hierarchy

Types are inferred from Zod schemas — no separate interface/type declarations.

```
// Primitives (Zod schemas → inferred TypeScript types)
PositionSchema     → number          (positive integer, 1-based)
PositionsSchema    → number[]        (sorted, deduplicated)
RangeTupleSchema   → [number, number] (start <= end)
RangesSchema       → [number, number][] (sorted, overlaps merged)

// Annotation entries
SiteEntryData      → { index: number[];                    type: string }
RegionEntryData    → { index: [number, number][];          type: string }
FlexEntryData      → { index: number[] | [number, number][]; type: string }
VariantData        → { position: number; [key: string]: unknown }

// Top-level
A3Data → {
  sequence:    string
  annotations: {
    site:       Record<string, SiteEntryData>
    region:     Record<string, RegionEntryData>
    ptm:        Record<string, FlexEntryData>
    processing: Record<string, FlexEntryData>
    variant:    VariantData[]
  }
  metadata: {
    uniprot_id:  string   // default ""
    description: string   // default ""
    reference:   string   // default ""
    organism:    string   // default ""
  }
}
```

## Schema Details

### Sequence

- `z.string()` with `.min(2)`, regex `[A-Za-z*]+`, `.transform(s => s.toUpperCase())`
- Lowercase accepted and normalized to uppercase
- Characters outside `[A-Za-z*]` are rejected

### Positions (`PositionsSchema`)

- `z.array(z.number().int().min(1))`
- `.transform(sortDedup)` — sorted ascending, duplicates removed

### Ranges (`RangesSchema`)

- `z.array(z.tuple([PositionSchema, PositionSchema]).refine(([s, e]) => s < e))`
- `.transform(sortRanges)` — sorted by start (then end for ties)
- `.superRefine(checkNoOverlap)` — rejects if any two consecutive ranges overlap (`curr[0] <= prev[1]`); adjacent ranges (`curr[0] = prev[1] + 1`) are permitted

### Annotation entry schemas

**Site** (`SiteEntrySchema`): `{ index: PositionsSchema, type: z.string().default("") }`

**Region** (`RegionEntrySchema`): `{ index: RangesSchema, type: z.string().default("") }`

**PTM / Processing** (`FlexEntrySchema`):
`{ index: z.union([RangesSchema, PositionsSchema]), type: z.string().default("") }`

Union order is significant: `RangesSchema` is tried first (more specific — requires
2-element tuple elements). Input with scalar number elements falls through to
`PositionsSchema`.

### Variant (`VariantSchema`)

- `z.object({ position: PositionSchema }).catchall(z.unknown())`
- `.refine(isJsonCompatible)` — all fields must be recursively JSON-compatible

### Annotation families (`AnnotationsSchema`)

- `z.object({ site, region, ptm, processing, variant }).strict()`
- `.strict()` rejects any key not in `{ site, region, ptm, processing, variant }`
- All families default to `{}` / `[]` when absent

### Metadata (`MetadataSchema`)

- `z.object({ uniprot_id, description, reference, organism }).strict()`
- All fields are `z.string().default("")`

### Root schema (`A3InputSchema`)

- `z.object({ sequence, annotations, metadata }).strict()`
- `.strict()` rejects unknown top-level keys
- `.superRefine(boundsCheck)` — stage 2 contextual validation

## Normalization Helpers (`normalize.ts`)

Pure functions used inside Zod transforms:

```ts
sortDedup(arr: readonly number[]): number[]
// Deduplicate and sort ascending

sortRanges(arr: readonly [number, number][]): [number, number][]
// Sort by start (then end for ties); no merging
// Overlap detection is a separate step in RangesSchema

isJsonCompatible(v: unknown): boolean
// Recursive check: null | boolean | number | string | array | plain object
// Rejects: undefined, functions, symbols, class instances
```

## `A3` Class

```ts
class A3 {
  readonly #data: A3Data   // Object.freeze'd at construction

  constructor(input: unknown)
  static fromData(data: unknown): A3
  static fromJSONText(text: string): A3
  static async readJSON(path: string): Promise<A3>   // via io.ts

  get length(): number                                // sequence length
  residueAt(position: number): string                 // 1-based; throws RangeError
  variantsAt(position: number): VariantData[]

  toData(): A3Data                                    // frozen reference
  toJSON(): A3Data                                    // called by JSON.stringify
  toJSONString(indent?: number): string
  async writeJSON(path: string, indent?: number): Promise<void>
}
```

`toJSON()` returns the plain data object (not a string), so `JSON.stringify(a3)`
works naturally and produces canonical output.

## Error Classes

```ts
class A3ValidationError extends Error
  issues: ZodError["issues"]   // full Zod issue list for programmatic inspection

class A3ParseError extends Error
  // wraps JSON.parse failures and file I/O errors
```

## File Structure

```
typescript/
  src/
    normalize.ts   // pure normalization helpers
    schemas.ts     // Zod schemas + exported inferred types
    a3.ts          // A3 class, A3ValidationError, A3ParseError
    io.ts          // readJSON / writeJSON (node:fs/promises)
    index.ts       // public exports
  tests/
    normalize.test.ts
    schemas.test.ts
    a3.test.ts
    roundtrip.test.ts
```

## Wire Format

Strict canonical format. Unknown keys are rejected at the top level and in
annotation families. The `type` field is always present in output (defaults to `""`).

```json
{
  "sequence": "MAEPRQ...",
  "annotations": {
    "site": {
      "Disease_associated_variant": { "index": [4, 5, 14], "type": "" },
      "catalyticResidues":          { "index": [57, 102],  "type": "activeSite" }
    },
    "region": {
      "KXGS": { "index": [[259, 262], [290, 293]], "type": "" }
    },
    "ptm": {
      "Phosphorylation": { "index": [17, 18, 29], "type": "" }
    },
    "processing": {},
    "variant": [
      { "position": 301, "from": "P", "to": "L" }
    ]
  },
  "metadata": {
    "uniprot_id":  "P10636",
    "description": "Microtubule-associated protein tau",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

## Validation

### Stage 1 — Structural (Zod schemas)

- `sequence`: non-empty, `[A-Za-z*]+`, uppercased
- Positions: positive integers, sorted, deduplicated
- Ranges: `start <= end`, sorted, overlaps merged
- Annotation entries: must be `{ index, type }` objects — bare arrays rejected
- Annotation family keys: non-empty strings
- Unknown annotation families: rejected (`.strict()`)
- Variant fields: JSON-compatible
- Metadata fields: strings; unknown keys rejected (`.strict()`)
- Unknown top-level keys: rejected (`.strict()`)

### Stage 2 — Contextual (`.superRefine`)

Runs on the fully normalized data (after all transforms):

- All site / ptm / processing positions satisfy `1 <= pos <= sequence.length`
- All region / ptm / processing range endpoints satisfy the same
- All variant positions satisfy the same
- Error paths include the full field path for precise error messages
