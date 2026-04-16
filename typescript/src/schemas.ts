// ── Envelope constants ────────────────────────────────────────────────────────

/** JSON Schema URI that identifies the A3 format. Used in the `$schema` field of every A3 document. */
export const A3_SCHEMA_URI = "https://schema.rtemis.org/a3/v1/schema.json";

/** A3 format version string. Used in the `a3_version` field of every A3 document. */
export const A3_VERSION = "1.0.0";

// ── Exported TypeScript interfaces ────────────────────────────────────────────

/** Metadata fields for an A3 object. All fields default to `""` when absent. */
export interface MetadataData {
  /** UniProt accession identifier, e.g. `"P12345"`. */
  uniprot_id: string;
  /** Free-text description of the protein. */
  description: string;
  /** Literature or database reference for the annotations. */
  reference: string;
  /** Source organism name. */
  organism: string;
}

/**
 * A single variant record. `position` is required; all other fields are
 * open and must be JSON-compatible.
 */
export interface VariantData {
  /** 1-based residue position of the variant. */
  position: number;
  /** Additional JSON-compatible fields (e.g. `wild_type`, `mutant`, `source`). */
  [key: string]: unknown;
}

/** Annotation entry with a position-based index (site family). */
export interface A3PositionData {
  /** Sorted array of 1-based residue positions. No duplicates allowed. */
  index: number[];
  /** Controlled-vocabulary label for the annotation type. */
  type: string;
}

/** Annotation entry with a range-based index (region family). */
export interface A3RangeData {
  /** Sorted array of inclusive `[start, end]` ranges. No overlaps allowed. */
  index: [number, number][];
  /** Controlled-vocabulary label for the annotation type. */
  type: string;
}

/** Annotation entry with either a position or range index (ptm / processing families). */
export interface A3FlexData {
  /** Sorted positions or sorted `[start, end]` ranges (never mixed within one entry). */
  index: number[] | [number, number][];
  /** Controlled-vocabulary label for the annotation type. */
  type: string;
}

/** Fully validated and normalized A3 data object, as returned by {@link A3.toData}. */
export interface A3Data {
  /** JSON Schema URI identifying the A3 format version. Always `{@link A3_SCHEMA_URI}`. */
  $schema: typeof A3_SCHEMA_URI;
  /** A3 format version string. Always `{@link A3_VERSION}`. */
  a3_version: typeof A3_VERSION;
  /** Uppercase amino-acid sequence using the single-letter code (`[A-Z*]`). */
  sequence: string;
  /** All annotation families for this protein. */
  annotations: {
    /** Per-residue site annotations keyed by annotation name. */
    site: Record<string, A3PositionData>;
    /** Contiguous region annotations keyed by annotation name. */
    region: Record<string, A3RangeData>;
    /** Post-translational modification annotations keyed by annotation name. */
    ptm: Record<string, A3FlexData>;
    /** Proteolytic processing annotations keyed by annotation name. */
    processing: Record<string, A3FlexData>;
    /** List of variant records. */
    variant: VariantData[];
  };
  /** Descriptive metadata for the protein. */
  metadata: MetadataData;
}
