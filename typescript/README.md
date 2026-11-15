[![typescript-ci](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml/badge.svg)](https://github.com/rtemis-org/a3/actions/workflows/typescript-ci.yml) [![npm version](https://img.shields.io/npm/v/@rtemis/a3.svg)](https://www.npmjs.com/package/@rtemis/a3) [![JSR](https://jsr.io/badges/@rtemis/a3)](https://jsr.io/@rtemis/a3)

# @rtemis/a3

TypeScript implementation of the **Amino Acid Annotation (A3)** format, a JSON format for an amino acid sequence with site, region, PTM, processing, and variant annotations.

- Canonical JSON Schema: [`https://schema.rtemis.org/a3/v1/schema.json`](https://schema.rtemis.org/a3/v1/schema.json) (source: [`schema/a3.schema.json`](https://github.com/rtemis-org/a3/blob/main/schema/a3.schema.json))
- Conformance contract: [`spec/`](https://github.com/rtemis-org/a3/tree/main/spec)
- Monorepo, with the R, Python, Julia, and Rust implementations: [rtemis-org/a3](https://github.com/rtemis-org/a3)

The package has no runtime dependencies. It runs in Node.js, Deno, Bun, browsers, and edge runtimes.

## Installation

From npm:

```bash
npm install @rtemis/a3
# or
pnpm add @rtemis/a3
```

From JSR:

```bash
deno add jsr:@rtemis/a3
# or
npx jsr add @rtemis/a3
```

## Usage

```ts
import { A3, A3_SCHEMA_URI, A3_VERSION } from "@rtemis/a3"

const a3 = new A3({
  $schema: A3_SCHEMA_URI,
  a3_version: A3_VERSION,
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
    variant: [{ position: 3, from: "T", to: "A" }],
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
a3.variantsAt(3)  // [{ position: 3, from: "T", to: "A" }]
a3.toJSONString() // normalized JSON string
```

## Reading a document

```ts
import { A3, A3ParseError, A3ValidationError } from "@rtemis/a3"

try {
  const a3 = A3.fromJSONText(jsonString)
} catch (e) {
  if (e instanceof A3ParseError) {
    console.error(e.message) // the text is not JSON
  } else if (e instanceof A3ValidationError) {
    console.error(e.issues) // A3Issue[]: { code, path, message }
  }
}
```

## File I/O (Node.js, Deno, Bun)

```ts
import { readJSON, writeJSON } from "@rtemis/a3"

const a3 = await readJSON("./protein.a3.json")
await writeJSON(a3, "./output.a3.json")
```

## Browsers and edge runtimes

The default entry point includes `readJSON` and `writeJSON`, which import `node:fs/promises`. The `browser` subpath exports everything except these two functions, for browsers, Cloudflare Workers, and other environments without a filesystem:

```ts
import { A3, A3ValidationError, validate } from "@rtemis/a3/browser"
```

On npm, bundlers that resolve the `browser` export condition select this entry point for `@rtemis/a3` automatically.

## Document format

```json
{
  "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
  "a3_version": "1.0.0",
  "sequence": "MKTAYIAKQR",
  "annotations": {
    "site":       { "Active site":     { "index": [3, 5],   "type": "activeSite" } },
    "region":     { "Repeat 1":        { "index": [[1, 4]], "type": "" } },
    "ptm":        { "Phosphorylation": { "index": [7],      "type": "" } },
    "processing": {},
    "variant":    [{ "position": 3, "from": "T", "to": "A" }]
  },
  "metadata": {
    "uniprot_id":  "P12345",
    "description": "Example protein",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

- `$schema`, `a3_version`, and `sequence` are required. `a3_version` is `"1.0.0"`.
- `sequence` is a string of at least two characters from `[A-Za-z*]`, stored in uppercase.
- `annotations` and `metadata` are optional. Every annotation family and every metadata member defaults to empty, and serialized output contains all of them.
- Each `site`, `region`, `ptm`, and `processing` entry is an object with an `index` and an optional `type` string, which defaults to `""`. A `site` index is a list of positions, a `region` index is a list of ranges, and a `ptm` or `processing` index is either, never both.
- Positions are 1-based integers. They are sorted ascending on read; a duplicate position is an error.
- A range is an inclusive `[start, end]` pair with `start < end`. Ranges are sorted by start on read; overlapping ranges are an error.
- A variant record requires `position`. Its other members are free-form JSON values and are preserved verbatim. A single-character `from` must equal the residue at `position`.
- Metadata members are free-text strings.

Package versions and `a3_version` are independent. This package reads and writes A3 format version 1.0.0.

## Validation

Validation is **collect-all**. A document is checked in four stages (envelope, structural, intra-field, contextual), and every issue in the earliest failing stage is reported at once. A later stage runs only when every earlier stage produced no issue. Each issue carries a stable `code` and an [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer `path`; both are identical across the R, Python, Julia, TypeScript, and Rust implementations of A3. The `message` is human-readable text and is not part of the contract. The rule registry is [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md).

`new A3()`, `A3.fromData()`, `A3.fromJSONText()`, and `readJSON()` throw an `A3ValidationError` that carries every issue of the failing stage:

```ts
import { A3, A3ValidationError } from "@rtemis/a3"

try {
  const a3 = A3.fromJSONText(text)
} catch (e) {
  if (e instanceof A3ValidationError) {
    console.log(e.stage) // 4
    for (const issue of e.issues) {
      console.log(issue.code, issue.path)
      // A3E_POS_OUT_OF_BOUNDS /annotations/site/Active site/index/2
    }
  }
}
```

`validate()` is the non-throwing entry point, for a form or a live-validation panel. Each issue attaches to a field by its pointer:

```ts
import { validate, resolvePointer } from "@rtemis/a3"

const input = JSON.parse(text)
const { data, issues } = validate(input)
for (const issue of issues) {
  const offending = resolvePointer(input, issue.path)
  // attach issue.message to the control that renders `offending`
}
```

## API

### `A3`

An immutable, validated A3 document.

| Member | Description |
|---|---|
| `new A3(input)` | Validates `input` and returns an `A3`. Throws `A3ValidationError`. |
| `A3.fromData(input)` | Equivalent to `new A3(input)`. |
| `A3.fromJSONText(text)` | Parses a JSON string and validates it. Throws `A3ParseError` when the text is not JSON and `A3ValidationError` when the document is not valid. |
| `a3.length` | Number of residues in the sequence. |
| `a3.residueAt(position)` | Residue at a 1-based position. Throws `RangeError` when the position is out of bounds. |
| `a3.variantsAt(position)` | Every variant record at a 1-based position. |
| `a3.toData()` | The normalized `A3Data` object. The returned object is frozen at its top level. |
| `a3.toJSON()` | The object `JSON.stringify(a3)` serializes. |
| `a3.toJSONString(indent = 2)` | The normalized JSON string. `indent = 0` gives compact output. |
| `a3.toString()` | A one-line summary, for example `A3 [P12345] { length: 10, sequence: "MKTAYIAKQR" }`. |

A variant member that is not a JSON value, such as a function, makes `new A3()` throw a `TypeError`.

### Errors

| Class | Description |
|---|---|
| `A3ValidationError` | `issues`: every issue in the earliest failing stage. `stage`: that stage, `1` to `4`. |
| `A3ParseError` | The input could not be parsed or read before validation: text that is not JSON, or a file that cannot be read or written. |

### Functions

| Function | Description |
|---|---|
| `validate(input)` | Returns `{ data, issues }`: the normalized `A3Data` and an empty list, or `null` and every issue in the earliest failing stage. |
| `readJSON(path)` | Reads and validates a file; returns `Promise<A3>`. Default entry point only. |
| `writeJSON(a3, path, indent = 2)` | Writes `a3.toJSONString(indent)` to a file. Default entry point only. |

### Issues and JSON Pointers

| Export | Description |
|---|---|
| `A3_ISSUE_CODES` | Every code in the rule registry. |
| `A3_ISSUE_STAGES` | The stage of each code. |
| `stageOf(issue)` | The stage of one issue. |
| `resolvePointer(document, path)` | The value a pointer refers to, or `undefined` when it does not resolve, as for a missing member. |
| `pointer(base, token)` | Appends a member name, escaped, or an array subscript to a pointer. |
| `escapeToken(token)` | Escapes `~` and `/` in a member name per RFC 6901. |

### Index parsers

Parsers for the `index` field of an annotation entry, as typed into a text input or pasted from a spreadsheet. Whitespace, commas, tabs, and newlines separate tokens. Each parser returns `{ ok: true, value }` or `{ ok: false, error }`; none throws.

```ts
import { parsePositions, parseRanges, parseIndex } from "@rtemis/a3"

parsePositions("10, 25\n42") // { ok: true, value: [10, 25, 42] }
parseRanges("1-50, 75-100")  // { ok: true, value: [[1, 50], [75, 100]] }
parseIndex("82, 109")        // { ok: true, value: { kind: "positions", values: [82, 109] } }
parseIndex("30-45")          // { ok: true, value: { kind: "ranges", values: [[30, 45]] } }
```

`parsePositions` sorts and deduplicates; `parseRanges` sorts by start. `formatPositions` and `formatRanges` return the inverse string form (`"1, 2, 3"`, `"1-5, 7-9"`) for a text input.

### Constants

| Constant | Value |
|---|---|
| `A3_SCHEMA_URI` | `"https://schema.rtemis.org/a3/v1/schema.json"` |
| `A3_VERSION` | `"1.0.0"` |

### Types

```ts
import type {
  A3Data,
  A3FlexData,
  A3Issue,
  A3IssueCode,
  A3PositionData,
  A3RangeData,
  A3Stage,
  MetadataData,
  ParsedIndex,
  ParseResult,
  ValidationResult,
  VariantData,
} from "@rtemis/a3"
```

## Known limitation

JavaScript orders integer-like property names ahead of all others. An annotation named `"5"` therefore serializes before the other names in its family, and `@rtemis/a3` does not preserve document order for such a name. The R, Python, Julia, and Rust implementations preserve it.

## License

[BSD 3-Clause](https://github.com/rtemis-org/a3/blob/main/typescript/LICENSE.txt)
