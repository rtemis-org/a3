import { describe, expect, it } from "vitest"
import { isJsonCompatible, normalizeRanges, sortDedup } from "../src/normalize"

describe("sortDedup", () => {
  it("sorts ascending", () => {
    expect(sortDedup([5, 1, 3])).toEqual([1, 3, 5])
  })
  it("removes duplicates", () => {
    expect(sortDedup([3, 1, 3, 5, 1])).toEqual([1, 3, 5])
  })
  it("handles empty array", () => {
    expect(sortDedup([])).toEqual([])
  })
  it("handles single element", () => {
    expect(sortDedup([7])).toEqual([7])
  })
  it("handles already sorted input", () => {
    expect(sortDedup([1, 2, 3])).toEqual([1, 2, 3])
  })
})

describe("normalizeRanges", () => {
  it("returns empty for empty input", () => {
    expect(normalizeRanges([])).toEqual([])
  })
  it("returns single range unchanged", () => {
    expect(normalizeRanges([[1, 5]])).toEqual([[1, 5]])
  })
  it("sorts by start position", () => {
    expect(normalizeRanges([[10, 20], [1, 5]])).toEqual([[1, 5], [10, 20]])
  })
  it("merges overlapping ranges", () => {
    expect(normalizeRanges([[1, 10], [5, 15]])).toEqual([[1, 15]])
  })
  it("merges adjacent ranges (c = b+1)", () => {
    expect(normalizeRanges([[1, 5], [6, 10]])).toEqual([[1, 10]])
  })
  it("does not merge non-adjacent ranges", () => {
    expect(normalizeRanges([[1, 5], [7, 10]])).toEqual([[1, 5], [7, 10]])
  })
  it("merges multiple overlapping into one", () => {
    expect(normalizeRanges([[1, 5], [3, 8], [6, 12]])).toEqual([[1, 12]])
  })
  it("keeps non-overlapping ranges separate", () => {
    expect(normalizeRanges([[1, 3], [5, 8], [10, 15]])).toEqual([[1, 3], [5, 8], [10, 15]])
  })
  it("handles contained ranges", () => {
    expect(normalizeRanges([[1, 20], [5, 10]])).toEqual([[1, 20]])
  })
  it("sorts and merges mixed input", () => {
    // KXGS repeats from the mapt example — non-overlapping, should stay separate
    expect(
      normalizeRanges([[259, 262], [290, 293], [321, 324], [353, 356]]),
    ).toEqual([[259, 262], [290, 293], [321, 324], [353, 356]])
  })
})

describe("isJsonCompatible", () => {
  it("accepts null", () => expect(isJsonCompatible(null)).toBe(true))
  it("accepts boolean", () => expect(isJsonCompatible(true)).toBe(true))
  it("accepts number", () => expect(isJsonCompatible(42)).toBe(true))
  it("accepts string", () => expect(isJsonCompatible("hello")).toBe(true))
  it("accepts array of primitives", () => expect(isJsonCompatible([1, "a", null])).toBe(true))
  it("accepts plain object", () => expect(isJsonCompatible({ a: 1, b: "x" })).toBe(true))
  it("accepts nested object", () => expect(isJsonCompatible({ a: { b: [1, 2] } })).toBe(true))
  it("rejects undefined", () => expect(isJsonCompatible(undefined)).toBe(false))
  it("rejects function", () => expect(isJsonCompatible(() => {})).toBe(false))
  it("rejects symbol", () => expect(isJsonCompatible(Symbol())).toBe(false))
  it("rejects class instance", () => {
    class Foo {}
    expect(isJsonCompatible(new Foo())).toBe(false)
  })
  it("rejects array containing undefined", () => {
    expect(isJsonCompatible([1, undefined, 3])).toBe(false)
  })
  it("rejects nested non-compatible value", () => {
    expect(isJsonCompatible({ a: { b: () => {} } })).toBe(false)
  })
})
