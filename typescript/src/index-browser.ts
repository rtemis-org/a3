// Browser-safe entry point — re-exports everything except readJSON/writeJSON
// which depend on node:fs/promises.
export { A3, A3ValidationError, A3ParseError } from "./a3";
export type {
  A3Data,
  MetadataData,
  VariantData,
  SiteEntryData,
  RegionEntryData,
  FlexEntryData,
} from "./schemas";
