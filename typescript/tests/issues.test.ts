import { describe, expect, it } from "vitest";
import {
  A3_ISSUE_CODES,
  A3_ISSUE_STAGES,
  escapeToken,
  pointer,
  resolvePointer,
  stageOf,
} from "../src/issues.ts";

describe("escapeToken", () => {
  it("escapes exactly the two characters RFC 6901 escapes", () => {
    expect(escapeToken("a/b")).toBe("a~1b");
    expect(escapeToken("a~b")).toBe("a~0b");
  });

  it("replaces ~ before /", () => {
    // Replacing in the other order would turn "a/b" into "a~01b": the "~1" the
    // slash produced would itself be re-escaped.
    expect(escapeToken("a/b")).toBe("a~1b");
    expect(escapeToken("~/")).toBe("~0~1");
  });

  it("leaves every other character alone", () => {
    for (const name of ["a.b", "$schema", "Domain (R1, R3, R4)", "β-sheet", "a[0]", ""]) {
      expect(escapeToken(name)).toBe(name);
    }
  });
});

describe("pointer", () => {
  it("escapes the token it is given", () => {
    expect(pointer("/annotations/site", "a/b")).toBe("/annotations/site/a~1b");
    expect(pointer("/annotations/site", "a~b")).toBe("/annotations/site/a~0b");
    expect(pointer("", "$schema")).toBe("/$schema");
  });

  it("takes a raw member name, not a pre-escaped one", () => {
    // The trap this pins: `pointer` escapes internally, so handing it an
    // already-escaped token escapes it a second time. Callers pass raw names.
    expect(pointer("", "a~1b")).toBe("/a~01b");
    expect(pointer("", "a~0b")).toBe("/a~00b");
  });

  it("does not escape an array subscript", () => {
    expect(pointer("/annotations/variant", 3)).toBe("/annotations/variant/3");
    expect(pointer("/annotations/site/s/index", 0)).toBe("/annotations/site/s/index/0");
  });

  it("renders an empty member name as a trailing empty token", () => {
    // A pointer ending in an empty reference token denotes the member named "",
    // which is exactly what A3E_NAME_EMPTY reports.
    expect(pointer("/annotations/site", "")).toBe("/annotations/site/");
  });
});

describe("resolvePointer", () => {
  const document = {
    $schema: "x",
    annotations: { site: { "a/b": { index: [7, 8] } } },
    variant: [{ position: 5 }],
  };

  it("round-trips a pointer built by pointer()", () => {
    const path = `${pointer(pointer("/annotations", "site"), "a/b")}/index/1`;
    expect(path).toBe("/annotations/site/a~1b/index/1");
    expect(resolvePointer(document, path)).toBe(8);
  });

  it("resolves the empty pointer to the whole document", () => {
    expect(resolvePointer(document, "")).toBe(document);
  });

  it("returns undefined for a pointer that does not resolve", () => {
    // Not a failure: a missing-member issue points at where the member would be,
    // so failing to resolve is the signal. See spec/error-paths.md, Rule 1.
    expect(resolvePointer(document, "/sequence")).toBeUndefined();
    expect(resolvePointer(document, "/annotations/site/nope/index")).toBeUndefined();
  });
});

describe("the registry", () => {
  it("gives every code a stage in 1-4", () => {
    for (const code of A3_ISSUE_CODES) {
      expect(A3_ISSUE_STAGES[code], code).toBeGreaterThanOrEqual(1);
      expect(A3_ISSUE_STAGES[code], code).toBeLessThanOrEqual(4);
    }
  });

  it("has 37 codes", () => {
    expect(A3_ISSUE_CODES).toHaveLength(37);
  });

  it("reports an issue's stage from its code", () => {
    expect(stageOf({ code: "A3E_SEQ_CHARSET", path: "/sequence", message: "" })).toBe(2);
    expect(
      stageOf({ code: "A3E_POS_OUT_OF_BOUNDS", path: "/annotations/site/s/index/0", message: "" }),
    ).toBe(4);
  });
});
