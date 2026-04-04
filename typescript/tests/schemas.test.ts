import { describe, expect, it } from "vitest";
import { A3_SCHEMA_URI, A3_VERSION, A3InputSchema } from "../src/schemas";

const MINIMAL_VALID = {
  $schema: A3_SCHEMA_URI,
  a3_version: A3_VERSION,
  sequence: "MKTAYIAKQR",
  annotations: { site: {}, region: {}, ptm: {}, processing: {}, variant: [] },
  metadata: { uniprot_id: "", description: "", reference: "", organism: "" },
};

describe("sequence validation", () => {
  it("accepts valid uppercase sequence", () => {
    const result = A3InputSchema.safeParse(MINIMAL_VALID);
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.sequence).toBe("MKTAYIAKQR");
  });

  it("uppercases lowercase input", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, sequence: "mktayiakqr" });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.sequence).toBe("MKTAYIAKQR");
  });

  it("accepts sequence with stop codon *", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, sequence: "MKTAY*" });
    expect(result.success).toBe(true);
  });

  it("rejects sequence shorter than 2 characters", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, sequence: "M" });
    expect(result.success).toBe(false);
  });

  it("rejects sequence with invalid characters", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, sequence: "MKT123" });
    expect(result.success).toBe(false);
  });

  it("rejects legacy character array sequence", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, sequence: ["M", "K", "T"] });
    expect(result.success).toBe(false);
  });
});

describe("annotation validation", () => {
  it("rejects unknown annotation family key", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: { ...MINIMAL_VALID.annotations, unknownFamily: {} },
    });
    expect(result.success).toBe(false);
  });

  it("rejects empty annotation name", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { "": { index: [1], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects missing annotations object", () => {
    const result = A3InputSchema.safeParse({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAYIAKQR",
      metadata: {},
    });
    expect(result.success).toBe(false);
  });

  it("accepts empty annotations object and defaults families to empty", () => {
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { "Active site": [5, 3, 1] },
      },
    });
    expect(result.success).toBe(false);
  });

  it("accepts region entry in canonical {index, type} form", () => {
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { KXGS: [[1, 5]] },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects degenerate range with start == end", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { bad: { index: [[5, 5]], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects region range with start > end", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        region: { bad: { index: [[5, 1]], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("accepts ptm entry with positions", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        ptm: { Phosphorylation: { index: [3, 5], type: "" } },
      },
    });
    expect(result.success).toBe(true);
  });

  it("accepts ptm entry with ranges", () => {
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [0, 3], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects position exceeding sequence length", () => {
    const result = A3InputSchema.safeParse({
      sequence: "MKTAY",
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [6], type: "" } },
      },
    });
    expect(result.success).toBe(false);
  });

  it("deduplicates and sorts positions", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        site: { A: { index: [3, 1, 3, 2], type: "" } },
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.site.A?.index).toEqual([1, 2, 3]);
    }
  });
});

describe("variant validation", () => {
  it("accepts variant with position and extra fields", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        variant: [{ position: 3, from: "R", to: "H" }],
      },
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.annotations.variant[0]?.position).toBe(3);
    }
  });

  it("rejects variant missing position", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        variant: [{ from: "R", to: "H" }],
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects variant with non-JSON-compatible metadata", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: {
        ...MINIMAL_VALID.annotations,
        variant: [{ position: 1, fn: () => {} }],
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects legacy variant: {} (must be an array)", () => {
    const result = A3InputSchema.safeParse({
      ...MINIMAL_VALID,
      annotations: { ...MINIMAL_VALID.annotations, variant: {} },
    });
    expect(result.success).toBe(false);
  });
});

describe("metadata validation", () => {
  it("rejects missing metadata object", () => {
    const result = A3InputSchema.safeParse({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
      annotations: {},
    });
    expect(result.success).toBe(false);
  });

  it("defaults all metadata fields to empty string when metadata is {}", () => {
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
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
    const result = A3InputSchema.safeParse({
      sequence: "MKTAY",
      metadata: { uniprot_id: "P10636", unknown_key: "value" },
    });
    expect(result.success).toBe(false);
  });

  it("rejects legacy top-level metadata fields (must be inside metadata object)", () => {
    const result = A3InputSchema.safeParse({
      sequence: "MKTAY",
      uniprot_id: "P10636",
      description: "Test protein",
    });
    expect(result.success).toBe(false);
  });
});

describe("top-level strictness", () => {
  it("rejects unknown top-level keys", () => {
    const result = A3InputSchema.safeParse({ ...MINIMAL_VALID, extra: "value" });
    expect(result.success).toBe(false);
  });
});
