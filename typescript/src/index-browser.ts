// Browser-safe entry point — re-exports everything except readJSON/writeJSON
// which depend on node:fs/promises.
export { A3, A3ParseError, A3ValidationError } from "./a3";
export type {
  A3Data,
  A3FlexData,
  A3PositionData,
  A3RangeData,
  MetadataData,
  VariantData,
} from "./schemas";
