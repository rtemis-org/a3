/**
 * A3 (Amino Acid Annotation) format — browser entry point.
 *
 * Identical to the main entry point except that file I/O (`readJSON`,
 * `writeJSON`) is excluded, as those depend on `node:fs/promises`.
 * Safe to use in browsers, Deno, and edge runtimes.
 *
 * @module
 */
export { A3, A3ParseError, A3ValidationError } from "./a3";
export type {
  A3Data,
  A3FlexData,
  A3PositionData,
  A3RangeData,
  MetadataData,
  VariantData,
} from "./schemas";
