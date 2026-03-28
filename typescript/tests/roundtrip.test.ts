import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { A3 } from "../src/a3";

const EXAMPLES_DIR = join(import.meta.dirname, "../../examples");

async function readExample(filename: string): Promise<string> {
  return readFile(join(EXAMPLES_DIR, filename), "utf-8");
}

describe("mapt_annot_a3.json (canonical format)", () => {
  it("parses without error", async () => {
    const text = await readExample("mapt_annot_a3.json");
    expect(() => A3.fromJSONText(text)).not.toThrow();
  });

  it("has correct sequence length (441 residues)", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.length).toBe(441);
  });

  it("first residue is M", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.residueAt(1)).toBe("M");
  });

  it("last residue is L", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.residueAt(441)).toBe("L");
  });

  it("contains expected site annotations", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.site).toHaveProperty("Disease_associated_variant");
    expect(data.annotations.site).toHaveProperty("N-terminal Repeat");
  });

  it("contains expected region annotations", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.region).toHaveProperty("KXGS");
    expect(data.annotations.region.KXGS?.index).toEqual([
      [259, 262],
      [290, 293],
      [321, 324],
      [353, 356],
    ]);
  });

  it("contains expected PTM annotations", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.ptm).toHaveProperty("Phosphorylation");
    expect(data.annotations.ptm).toHaveProperty("Acetylation");
  });

  it("metadata is correct", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const meta = a3.toData().metadata;
    expect(meta.uniprot_id).toBe("P10636");
    expect(meta.description).toContain("Tau");
  });

  it("round-trips: parse → serialize → parse gives identical data", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const json2 = a3.toJSONString();
    const a3b = A3.fromJSONText(json2);

    expect(a3b.length).toBe(a3.length);
    expect(a3b.toData().sequence).toBe(a3.toData().sequence);
    expect(a3b.toData().metadata).toEqual(a3.toData().metadata);
    expect(a3b.toData().annotations.site).toEqual(a3.toData().annotations.site);
    expect(a3b.toData().annotations.region).toEqual(a3.toData().annotations.region);
    expect(a3b.toData().annotations.ptm).toEqual(a3.toData().annotations.ptm);
  });

  it("serialized output always has all five annotation families", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const parsed = JSON.parse(a3.toJSONString()) as {
      annotations: Record<string, unknown>;
    };
    for (const family of ["site", "region", "ptm", "processing", "variant"]) {
      expect(parsed.annotations).toHaveProperty(family);
    }
  });

  it("serialized output preserves type field on all entries", async () => {
    const text = await readExample("mapt_annot_a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    for (const entry of Object.values(data.annotations.site)) {
      expect(entry).toHaveProperty("type");
    }
    for (const entry of Object.values(data.annotations.ptm)) {
      expect(entry).toHaveProperty("type");
    }
  });
});
