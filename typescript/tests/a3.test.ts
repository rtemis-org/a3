import { describe, expect, it } from "vitest";
import { A3, A3ParseError, A3ValidationError } from "../src/a3";
import { A3_SCHEMA_URI, A3_VERSION } from "../src/schemas";

const MINI_SEQ = "MKTAYIAKQR";

const SIMPLE_INPUT = {
  $schema: A3_SCHEMA_URI,
  a3_version: A3_VERSION,
  sequence: MINI_SEQ,
  annotations: {
    site: { "Active site": { index: [3, 5], type: "activeSite" } },
    region: { KXGS: { index: [[1, 5]], type: "" } },
    ptm: { Phosphorylation: { index: [7], type: "" } },
    processing: { "Signal peptide": { index: [[8, 10]], type: "" } },
    variant: [{ position: 2, from: "K", to: "R" }],
  },
  metadata: {
    uniprot_id: "P12345",
    description: "Example protein",
    reference: "PMID:12345678",
    organism: "Homo sapiens",
  },
};

describe("A3 constructor", () => {
  it("constructs from valid input", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(a3.length).toBe(10);
  });

  it("throws A3ValidationError for invalid input", () => {
    expect(() => new A3({ $schema: A3_SCHEMA_URI, a3_version: A3_VERSION, sequence: "M" })).toThrow(
      A3ValidationError,
    );
  });

  it("throws A3ValidationError with issues array", () => {
    try {
      new A3({ $schema: A3_SCHEMA_URI, a3_version: A3_VERSION, sequence: "M" });
    } catch (e) {
      expect(e).toBeInstanceOf(A3ValidationError);
      expect((e as A3ValidationError).issues.length).toBeGreaterThan(0);
    }
  });

  it("throws A3ValidationError for out-of-bounds position", () => {
    expect(
      () =>
        new A3({
          $schema: A3_SCHEMA_URI,
          a3_version: A3_VERSION,
          sequence: "MKTAY",
          annotations: { site: { A: { index: [99], type: "" } } },
        }),
    ).toThrow(A3ValidationError);
  });
});

describe("A3.fromData", () => {
  it("constructs from plain data object", () => {
    const a3 = A3.fromData(SIMPLE_INPUT);
    expect(a3.length).toBe(10);
  });
});

describe("A3.fromJSONText", () => {
  it("parses valid JSON string", () => {
    const json = JSON.stringify(SIMPLE_INPUT);
    const a3 = A3.fromJSONText(json);
    expect(a3.length).toBe(10);
  });

  it("throws A3ParseError for malformed JSON", () => {
    expect(() => A3.fromJSONText("{not valid json")).toThrow(A3ParseError);
  });

  it("throws A3ValidationError for invalid A3 data in valid JSON", () => {
    expect(() => A3.fromJSONText('{"sequence":"M"}')).toThrow(A3ValidationError);
  });
});

describe("A3.length", () => {
  it("returns correct sequence length", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(a3.length).toBe(MINI_SEQ.length);
  });
});

describe("A3.residueAt", () => {
  it("returns first residue at position 1", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(a3.residueAt(1)).toBe("M");
  });

  it("returns last residue at position length", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(a3.residueAt(MINI_SEQ.length)).toBe("R");
  });

  it("throws RangeError for position 0", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(() => a3.residueAt(0)).toThrow(RangeError);
  });

  it("throws RangeError for position > length", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(() => a3.residueAt(MINI_SEQ.length + 1)).toThrow(RangeError);
  });

  it("throws RangeError for non-integer position", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(() => a3.residueAt(1.5)).toThrow(RangeError);
  });
});

describe("A3.variantsAt", () => {
  it("returns variants matching the given position", () => {
    const a3 = new A3(SIMPLE_INPUT);
    const variants = a3.variantsAt(2);
    expect(variants.length).toBe(1);
    expect(variants[0]?.position).toBe(2);
  });

  it("returns empty array when no variants at position", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(a3.variantsAt(9)).toEqual([]);
  });
});

describe("A3.toData", () => {
  it("returns the canonical data object", () => {
    const a3 = new A3(SIMPLE_INPUT);
    const data = a3.toData();
    expect(data.sequence).toBe(MINI_SEQ);
    expect(data.metadata.uniprot_id).toBe("P12345");
  });

  it("returns a frozen object", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(Object.isFrozen(a3.toData())).toBe(true);
  });
});

describe("A3.toJSON and JSON.stringify", () => {
  it("toJSON returns a plain object, not a string", () => {
    const a3 = new A3(SIMPLE_INPUT);
    expect(typeof a3.toJSON()).toBe("object");
    expect(a3.toJSON()).not.toBeNull();
  });

  it("JSON.stringify(a3) produces valid JSON", () => {
    const a3 = new A3(SIMPLE_INPUT);
    const json = JSON.stringify(a3);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  it("JSON.stringify(a3) matches toJSONString()", () => {
    const a3 = new A3(SIMPLE_INPUT);
    // JSON.stringify with no indent vs toJSONString(0)
    expect(JSON.stringify(a3)).toBe(a3.toJSONString(0));
  });

  it("serialized JSON contains all annotation families", () => {
    const a3 = new A3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
    });
    const parsed = JSON.parse(a3.toJSONString()) as { annotations: Record<string, unknown> };
    expect(parsed.annotations).toHaveProperty("site");
    expect(parsed.annotations).toHaveProperty("region");
    expect(parsed.annotations).toHaveProperty("ptm");
    expect(parsed.annotations).toHaveProperty("processing");
    expect(parsed.annotations).toHaveProperty("variant");
  });

  it("type field is always present on annotation entries", () => {
    const a3 = new A3({
      $schema: A3_SCHEMA_URI,
      a3_version: A3_VERSION,
      sequence: "MKTAY",
      annotations: {
        site: { A: { index: [1, 2] } }, // type omitted — defaults to ""
      },
    });
    const parsed = JSON.parse(a3.toJSONString()) as {
      annotations: { site: { A: { type: string } } };
    };
    expect(parsed.annotations.site.A.type).toBe("");
  });
});

describe("A3 round-trip", () => {
  it("parses its own JSON output back to identical data", () => {
    const original = new A3(SIMPLE_INPUT);
    const restored = A3.fromJSONText(original.toJSONString());

    expect(restored.length).toBe(original.length);
    expect(restored.toData().sequence).toBe(original.toData().sequence);
    expect(restored.toData().metadata).toEqual(original.toData().metadata);

    const origAnnotations = original.toData().annotations;
    const restAnnotations = restored.toData().annotations;
    expect(restAnnotations.site).toEqual(origAnnotations.site);
    expect(restAnnotations.region).toEqual(origAnnotations.region);
    expect(restAnnotations.ptm).toEqual(origAnnotations.ptm);
    expect(restAnnotations.processing).toEqual(origAnnotations.processing);
    expect(restAnnotations.variant).toEqual(origAnnotations.variant);
  });
});
