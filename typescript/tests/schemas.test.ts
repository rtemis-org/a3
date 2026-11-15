import { describe, expect, it } from "vitest";
import { A3, A3ValidationError } from "../src/a3.ts";
import { A3_SCHEMA_URI, A3_VERSION, type A3Data } from "../src/schemas.ts";

const MINIMAL_VALID = {
  $schema: A3_SCHEMA_URI,
  a3_version: A3_VERSION,
  sequence: "MKTAYIAKQR",
  annotations: { site: {}, region: {}, ptm: {}, processing: {}, variant: [] },
  metadata: { uniprot_id: "", description: "", reference: "", organism: "" },
};

type SafeParseResult =
  | { success: true; data: A3Data }
  | { success: false; error: A3ValidationError };

const safeParseA3 = (input: unknown): SafeParseResult => {
  try {
    return { success: true, data: A3.fromData(input).toData() };
  } catch (error) {
    if (error instanceof A3ValidationError) {
      return { success: false, error };
    }
    throw error;
  }
};

describe("sequence validation", () => {
  it("accepts valid uppercase sequence", () => {
    const result = safeParseA3(MINIMAL_VALID);
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.sequence).toBe("MKTAYIAKQR");
  });

  it("uppercases lowercase input", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, sequence: "mktayiakqr" });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.sequence).toBe("MKTAYIAKQR");
  });

  it("accepts sequence with stop codon *", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, sequence: "MKTAY*" });
    expect(result.success).toBe(true);
  });

  it("rejects sequence shorter than 2 characters", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, sequence: "M" });
    expect(result.success).toBe(false);
  });

  it("rejects sequence with invalid characters", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, sequence: "MKT123" });
    expect(result.success).toBe(false);
  });

  it("rejects legacy character array sequence", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, sequence: ["M", "K", "T"] });
    expect(result.success).toBe(false);
  });
});

describe("annotation validation", () => {
  it("rejects unknown annotation family key", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: { ...MINIMAL_VALID.annotations, unknownFamily: {} },
    });
    expect(result.success).toBe(false);
  });

  it("rejects empty annotation name", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { "": { index: [1], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("accepts a document with no annotations member (it is optional)", () => {
    const result = safeParseA3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAYIAKQR",
      metadata: {},
    });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.annotations.site).toEqual({});
  });

  it("accepts empty annotations object and defaults families to empty", () => {
    const result = safeParseA3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAYIAKQR",
      annotations: {},
      metadata: {},
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.site).toEqual({});
      expect(result.data.annotations.variant).toEqual([]);
    }
  });

  it("accepts site entry in canonical {index, type} form", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { "Active site": { index: [3, 1, 5], type: "activeSite" } },
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      // positions sorted and deduped
      expect(result.data.annotations.site["Active site"]?.index).toEqual([1, 3, 5]);
      expect(result.data.annotations.site["Active site"]?.type).toBe("activeSite");
    }
  });

  it("rejects legacy bare array (not wrapped in {index, type})", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { "Active site": [5, 3, 1] },
      },
    });
    expect(result.success).toBe(false);
  });

  it("accepts region entry in canonical {index, type} form", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: {
          KXGS: {
            index: [
              [1, 5],
              [7, 10],
            ],
            type: "",
          },
        },
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.region.KXGS?.index).toEqual([
        [1, 5],
        [7, 10],
      ]);
    }
  });

  it("rejects overlapping ranges", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: {
          KXGS: {
            index: [
              [1, 5],
              [3, 8],
            ],
            type: "",
          },
        },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects legacy bare range array (not wrapped in {index, type})", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { KXGS: [[1, 5]] },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects degenerate range with start == end", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { bad: { index: [[5, 5]], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects region range with start > end", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { bad: { index: [[5, 1]], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("accepts ptm entry with positions", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        ptm: { Phosphorylation: { index: [3, 5], type: "" } },
      },
    });
    expect(result.success).toBe(true);
  });

  it("accepts ptm entry with ranges", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        ptm: { Domain: { index: [[1, 5]], type: "" } },
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.ptm.Domain?.index).toEqual([[1, 5]]);
    }
  });

  it("rejects position zero", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [0, 3], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects position exceeding sequence length", () => {
    const result = safeParseA3({
      sequence: "MKTAY",
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [6], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("sorts positions", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [3, 1, 2], type: "" } },
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.site.A?.index).toEqual([1, 2, 3]);
    }
  });

  it("rejects duplicate positions", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [3, 1, 3, 2], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });
});

describe("variant validation", () => {
  it("accepts variant with position and extra fields", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        variant: [{ position: 3, from: "T", to: "H" }],
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.variant[0]?.position).toBe(3);
    }
  });

  it("rejects variant missing position", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        variant: [{ from: "R", to: "H" }],
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects variant with a non-JSON-compatible member", () => {
    // Not a validation issue: no such value can come out of JSON.parse, so it
    // has no A3 code. It is a constructor-path guard, and a TypeError is the
    // idiomatic response to a value of the wrong kind.
    expect(() =>
      A3.fromData({
        ...MINIMAL_VALID,
        annotations: {
          ...MINIMAL_VALID.annotations,
          variant: [{ position: 1, fn: () => {} }],
        },
      }),
    ).toThrow(TypeError);
  });

  it("rejects legacy variant: {} (must be an array)", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      annotations: { ...MINIMAL_VALID.annotations, variant: {} },
    });
    expect(result.success).toBe(false);
  });
});

describe("metadata validation", () => {
  it("accepts a document with no metadata member (it is optional)", () => {
    const result = safeParseA3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
      annotations: {},
    });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.metadata.uniprot_id).toBe("");
  });

  it("defaults all metadata fields to empty string when metadata is {}", () => {
    const result = safeParseA3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
      annotations: {},
      metadata: {},
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.metadata).toEqual({
        uniprot_id: "",
        description: "",
        reference: "",
        organism: "",
      });
    }
  });

  it("accepts partial metadata", () => {
    const result = safeParseA3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
      annotations: {},
      metadata: { uniprot_id: "P10636" },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.metadata.uniprot_id).toBe("P10636");
      expect(result.data.metadata.organism).toBe("");
    }
  });

  it("rejects unknown metadata keys", () => {
    const result = safeParseA3({
      sequence: "MKTAY",
      metadata: { uniprot_id: "P10636", unknown_key: "value" },
    });
    expect(result.success).toBe(false);
  });

  it("rejects legacy top-level metadata fields (must be inside metadata object)", () => {
    const result = safeParseA3({
      sequence: "MKTAY",
      uniprot_id: "P10636",
      description: "Test protein",
    });
    expect(result.success).toBe(false);
  });

  it("accepts any string as metadata — metadata is free text", () => {
    // A3 validates that these members are strings and nothing else. Checks on
    // their *content* (is this a well-formed UniProt accession?) belong in a
    // separate lint layer, so that "valid" keeps meaning "conforms to the
    // published schema". See spec/README.md, "Scope of validation".
    for (const uniprot_id of ["P12345", "A0A0A0AAA1", "P10636-8", "MAPT", ""]) {
      const result = safeParseA3({
        ...MINIMAL_VALID,
        metadata: { ...MINIMAL_VALID.metadata, uniprot_id },
      });
      expect(result.success, uniprot_id).toBe(true);
      if (result.success) expect(result.data.metadata.uniprot_id).toBe(uniprot_id);
    }
  });

  it("rejects a non-string metadata member", () => {
    const result = safeParseA3({
      ...MINIMAL_VALID,
      metadata: { ...MINIMAL_VALID.metadata, uniprot_id: 10636 },
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0]?.code).toBe("A3E_METADATA_FIELD_NOT_STRING");
      expect(result.error.issues[0]?.path).toBe("/metadata/uniprot_id");
    }
  });

  it("does not trim metadata values", () => {
    // Trimming would be a normalization, and normalization is exactly three
    // rules: case-fold the sequence, sort positions, sort ranges.
    const result = safeParseA3({
      ...MINIMAL_VALID,
      metadata: { ...MINIMAL_VALID.metadata, description: "  spaced  " },
    });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.metadata.description).toBe("  spaced  ");
  });
});

describe("top-level strictness", () => {
  it("rejects unknown top-level keys", () => {
    const result = safeParseA3({ ...MINIMAL_VALID, extra: "value" });
    expect(result.success).toBe(false);
  });
});
