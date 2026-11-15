/**
 * A3 (Amino Acid Annotation) format — TypeScript implementation.
 *
 * Entry point for Node.js. Includes file I/O ({@link readJSON}, {@link writeJSON})
 * in addition to the core {@link A3} class and all exported types.
 *
 * For browser or edge environments, import from `@rtemis/a3/browser` instead.
 *
 * @module
 */

export { A3, A3ParseError, A3ValidationError } from "./a3.ts";
export { readJSON, writeJSON } from "./io.ts";
export type { A3Issue, A3IssueCode, A3Stage } from "./issues.ts";
export {
  A3_ISSUE_CODES,
  A3_ISSUE_STAGES,
  escapeToken,
  pointer,
  resolvePointer,
  stageOf,
} from "./issues.ts";
export type { ParsedIndex, ParseResult } from "./parse.ts";
export {
  formatPositions,
  formatRanges,
  parseIndex,
  parsePositions,
  parseRanges,
} from "./parse.ts";
export type {
  A3Data,
  A3FlexData,
  A3PositionData,
  A3RangeData,
  MetadataData,
  VariantData,
} from "./schemas.ts";
export { A3_SCHEMA_URI, A3_VERSION } from "./schemas.ts";
export type { ValidationResult } from "./validate.ts";
export { validate } from "./validate.ts";
