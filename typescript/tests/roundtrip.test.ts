import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { A3 } from "../src/a3";

const EXAMPLES_DIR = join(import.meta.dirname, "../../examples");

async function readExample(filename: string): Promise<string> {
  return readFile(join(EXAMPLES_DIR, filename), "utf-8");
}

describe("mapt.a3.json (canonical format)", () => {
  it("parses without error", async () => {
    const text = await readExample("mapt.a3.json");
    expect(() => A3.fromJSONText(text)).not.toThrow();
  });

  it("has correct sequence length (441 residues)", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.length).toBe(441);
  });

  it("first residue is M", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.residueAt(1)).toBe("M");
  });

  it("last residue is L", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    expect(a3.residueAt(441)).toBe("L");
  });

  it("contains expected site annotations", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.site).toHaveProperty("AT8 epitope");
    expect(data.annotations.site["AT8 epitope"]?.index).toEqual([202, 205]);
    expect(data.annotations.site).toHaveProperty("PHF-1 epitope");
  });

  it("contains expected region annotations", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.region).toHaveProperty("R1");
    expect(data.annotations.region.R1?.index).toEqual([[244, 274]]);
    expect(data.annotations.region.R4?.index).toEqual([[337, 368]]);
  });

  it("contains expected PTM annotations", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const data = a3.toData();
    expect(data.annotations.ptm).toHaveProperty("Phosphorylation");
    expect(data.annotations.ptm).toHaveProperty("Acetylation");
  });

  it("metadata is correct", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const meta = a3.toData().metadata;
    expect(meta.uniprot_id).toBe("P10636-8");
    expect(meta.description).toContain("tau");
    expect(meta.organism).toBe("Homo sapiens");
  });

  it("round-trips: parse → serialize → parse gives identical data", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const json2 = a3.toJSONString();
    const a3b = A3.fromJSONText(json2);

    expect(a3b.length).toBe(a3.length);
    expect(a3b.toData().sequence).toBe(a3.toData().sequence);
    expect(a3b.toData().metadata).toEqual(a3.toData().metadata);
    expect(a3b.toData().annotations.site).toEqual(a3.toData().annotations.site);
    expect(a3b.toData().annotations.region).toEqual(a3.toData().annotations.region);
    expect(a3b.toData().annotations.ptm).toEqual(a3.toData().annotations.ptm);
    expect(a3b.toData().annotations.processing).toEqual(a3.toData().annotations.processing);
    expect(a3b.toData().annotations.variant).toEqual(a3.toData().annotations.variant);
  });

  it("contains ClinVar variant records on 2N4R coordinates", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const p301l = a3.variantsAt(301).filter((v) => v.source === "ClinVar" && v.to === "L");
    expect(p301l).toHaveLength(1);
    expect(p301l[0]?.from).toBe("P");
  });

  it("serialized output always has all five annotation families", async () => {
    const text = await readExample("mapt.a3.json");
    const a3 = A3.fromJSONText(text);
    const parsed = JSON.parse(a3.toJSONString()) as {
      annotations: Record<string, unknown>;
    };
    for (const family of ["site", "region", "ptm", "processing", "variant"]) {
      expect(parsed.annotations).toHaveProperty(family);
    }
  });

  it("serialized output preserves type field on all entries", async () => {
    const text = await readExample("mapt.a3.json");
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
