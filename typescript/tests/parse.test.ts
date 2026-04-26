import { describe, expect, it } from "vitest";
import {
  formatPositions,
  formatRanges,
  parseIndex,
  parsePositions,
  parseRanges,
} from "../src/parse";

describe("parsePositions", () => {
  it("returns empty array for empty input", () => {
    expect(parsePositions("")).toEqual({ ok: true, value: [] });
    expect(parsePositions("   ")).toEqual({ ok: true, value: [] });
  });

  it("parses comma-separated positions", () => {
    expect(parsePositions("10, 25, 42")).toEqual({ ok: true, value: [10, 25, 42] });
  });

  it("parses whitespace-separated positions", () => {
    expect(parsePositions("10 25 42")).toEqual({ ok: true, value: [10, 25, 42] });
  });

  it("handles newlines and tabs (spreadsheet paste)", () => {
    expect(parsePositions("10\n25\n42")).toEqual({ ok: true, value: [10, 25, 42] });
    expect(parsePositions("10\t25\t42")).toEqual({ ok: true, value: [10, 25, 42] });
  });

  it("sorts and deduplicates", () => {
    expect(parsePositions("42, 10, 25, 10")).toEqual({ ok: true, value: [10, 25, 42] });
  });

  it("rejects non-integer tokens", () => {
    const r = parsePositions("10, x, 42");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain('"x"');
  });

  it("rejects zero or negative tokens", () => {
    const r = parsePositions("0, 5");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain('"0"');
  });
});

describe("parseRanges", () => {
  it("returns empty array for empty input", () => {
    expect(parseRanges("")).toEqual({ ok: true, value: [] });
  });

  it("parses comma-separated ranges", () => {
    expect(parseRanges("1-50, 75-100")).toEqual({
      ok: true,
      value: [
        [1, 50],
        [75, 100],
      ],
    });
  });

  it("handles whitespace around dash", () => {
    expect(parseRanges("1 - 50, 75 - 100")).toEqual({
      ok: true,
      value: [
        [1, 50],
        [75, 100],
      ],
    });
  });

  it("handles newlines (column paste)", () => {
    expect(parseRanges("1-50\n75-100")).toEqual({
      ok: true,
      value: [
        [1, 50],
        [75, 100],
      ],
    });
  });

  it("sorts by start position", () => {
    expect(parseRanges("75-100, 1-50")).toEqual({
      ok: true,
      value: [
        [1, 50],
        [75, 100],
      ],
    });
  });

  it("rejects non-range tokens", () => {
    const r = parseRanges("10, 1-50");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain('"10"');
  });

  it("rejects end < start", () => {
    const r = parseRanges("50-10");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain("end must be ≥ start");
  });
});

describe("parseIndex (auto-detect)", () => {
  it("returns empty positions for empty input", () => {
    expect(parseIndex("")).toEqual({
      ok: true,
      value: { kind: "positions", values: [] },
    });
  });

  it("detects positions when no dash", () => {
    expect(parseIndex("10, 25, 42")).toEqual({
      ok: true,
      value: { kind: "positions", values: [10, 25, 42] },
    });
  });

  it("detects ranges when dash present", () => {
    expect(parseIndex("1-50, 75-100")).toEqual({
      ok: true,
      value: {
        kind: "ranges",
        values: [
          [1, 50],
          [75, 100],
        ],
      },
    });
  });

  it("propagates parse errors", () => {
    const r = parseIndex("10, x");
    expect(r.ok).toBe(false);
  });
});

describe("formatPositions / formatRanges", () => {
  it("formats positions", () => {
    expect(formatPositions([10, 25, 42])).toBe("10, 25, 42");
    expect(formatPositions([])).toBe("");
  });

  it("formats ranges", () => {
    expect(
      formatRanges([
        [1, 50],
        [75, 100],
      ]),
    ).toBe("1-50, 75-100");
    expect(formatRanges([])).toBe("");
  });
});
