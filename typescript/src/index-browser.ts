/**
 * A3 (Amino Acid Annotation) format — browser entry point.
 *
 * Identical to the main entry point except that file I/O (`readJSON`,
 * `writeJSON`) is excluded, as those depend on `node:fs/promises`.
 * Safe to use in browsers, Deno, and edge runtimes.
 *
 * @module
 */

export type { A3ValidationIssue } from "./a3";
export { A3, A3InputSchema, A3ParseError, A3ValidationError } from "./a3";
export type { ParsedIndex, ParseResult } from "./parse";
export {
  formatPositions,
  formatRanges,
  parseIndex,
  parsePositions,
  parseRanges,
} from "./parse";
export type {
  A3Data,
  A3FlexData,
  A3PositionData,
  A3RangeData,
  MetadataData,
  VariantData,
} from "./schemas";
export { A3_SCHEMA_URI, A3_VERSION } from "./schemas";
