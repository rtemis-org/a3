[![typescript-ci](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml)

# @rtemis/a3

TypeScript implementation of the **Amino Acid Annotation (A3)** format —
a structured JSON format for amino acid sequences with site, region, PTM,
processing, and variant annotations.

Part of the [rtemis-org/a3](https://github.com/rtemis-org/a3) monorepo.

## Installation

```bash
npm install @rtemis/a3
# or
pnpm add @rtemis/a3
```

## Quick Start

```ts
import { A3 } from "@rtemis/a3"

const a3 = new A3({
  sequence: "MKTAYIAKQR",
  annotations: {
    site: {
      "Active site": { index: [3, 5], type: "activeSite" },
    },
    region: {
      "Repeat 1": { index: [[1, 4]], type: "" },
    },
    ptm: {
      Phosphorylation: { index: [7], type: "" },
    },
    processing: {},
    variant: [{ position: 3, from: "K", to: "R" }],
  },
  metadata: {
    uniprot_id: "P12345",
    description: "Example protein",
    reference: "",
    organism: "Homo sapiens",
  },
})

a3.length         // 10
a3.residueAt(1)   // "M"
a3.toJSONString() // canonical JSON string
```

## Parsing JSON

```ts
import { A3, A3ValidationError } from "@rtemis/a3"

try {
  const a3 = A3.fromJSONText(jsonString)
} catch (e) {
  if (e instanceof A3ValidationError) {
    console.error(e.issues) // Zod issue array with field paths
  }
}
```

## File I/O (Node.js)

```ts
import { readJSON, writeJSON } from "@rtemis/a3"

const a3 = await readJSON("./protein.json")
await writeJSON(a3, "./output.json")
```

## Wire Format

```json
{
  "sequence": "MKTAYIAKQR",
  "annotations": {
    "site":       { "Active site": { "index": [3, 5],   "type": "activeSite" } },
    "region":     { "Repeat 1":    { "index": [[1, 4]], "type": "" } },
    "ptm":        { "Phospho":     { "index": [7],      "type": "" } },
    "processing": {},
    "variant":    [{ "position": 3, "from": "K", "to": "R" }]
  },
  "metadata": {
    "uniprot_id":  "P12345",
    "description": "Example protein",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

All five annotation families are always present in output. Each annotation
entry is `{ index, type }` — bare arrays are rejected. Positions are
1-based, sorted, and deduplicated. Ranges are `[start, end]` pairs
(`start < end`), sorted by start; overlapping ranges are rejected.

## API

### `new A3(input)` / `A3.fromData(input)`

Construct and validate. Throws `A3ValidationError` if input is invalid.

### `A3.fromJSONText(text)`

Parse a JSON string and validate. Throws `A3ParseError` on invalid JSON,
`A3ValidationError` on schema violations.

### `a3.length`

Number of residues in the sequence.

### `a3.residueAt(position)`

Return the residue at a 1-based position. Throws `RangeError` if out of bounds.

### `a3.variantsAt(position)`

Return all variant records at a given 1-based position.

### `a3.toData()`

Return the validated data object (frozen).

### `a3.toJSONString(indent?)`

Serialize to a JSON string. Default indent is 2; pass 0 for compact output.

### `JSON.stringify(a3)`

Works directly — `toJSON()` is implemented.

## Exported Types

```ts
import type {
  A3Data,
  MetadataData,
  VariantData,
  SiteEntryData,
  RegionEntryData,
  FlexEntryData,
} from "@rtemis/a3"
```

## License

[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/)
