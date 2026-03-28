/**
 * Sort and deduplicate a position array.
 * Input positions are assumed valid (positive integers) — validated by Zod before calling.
 */
export function sortDedup(arr: readonly number[]): number[] {
  return [...new Set(arr)].sort((a, b) => a - b)
}

/**
 * Sort ranges by start position and merge overlapping or adjacent ranges.
 * [a, b] and [c, d] merge when c <= b + 1 (overlap or direct adjacency).
 * Input ranges are assumed valid (start <= end) — validated by Zod before calling.
 */
export function normalizeRanges(arr: readonly [number, number][]): [number, number][] {
  if (arr.length === 0) return []
  const sorted = [...arr].sort((a, b) => a[0] - b[0] || a[1] - b[1])
  const result: [number, number][] = [[sorted[0]![0], sorted[0]![1]]]
  for (let i = 1; i < sorted.length; i++) {
    const last = result[result.length - 1]!
    const curr = sorted[i]!
    if (curr[0] <= last[1] + 1) {
      last[1] = Math.max(last[1], curr[1])
    } else {
      result.push([curr[0], curr[1]])
    }
  }
  return result
}

/**
 * Recursively check that a value is JSON-compatible.
 * Rejects undefined, functions, symbols, and class instances.
 */
export function isJsonCompatible(v: unknown): boolean {
  if (v === null) return true
  if (typeof v === "boolean" || typeof v === "number" || typeof v === "string") return true
  if (Array.isArray(v)) return v.every(isJsonCompatible)
  if (typeof v === "object") {
    const proto = Object.getPrototypeOf(v) as unknown
    if (proto !== Object.prototype && proto !== null) return false
    return Object.values(v as Record<string, unknown>).every(isJsonCompatible)
  }
  return false
}
