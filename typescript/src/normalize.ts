/**
 * Sort and deduplicate a position array.
 * Input positions are assumed valid (positive integers) — validated by Zod before calling.
 */
export function sortDedup(arr: readonly number[]): number[] {
  return [...new Set(arr)].sort((a, b) => a - b);
}

/**
 * Sort ranges by start position (then end position for ties).
 * Input ranges are assumed valid (start < end) — validated by Zod before calling.
 * Overlap detection is handled separately in the schema layer.
 */
export function sortRanges(arr: readonly [number, number][]): [number, number][] {
  return [...arr].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
}

/**
 * Recursively check that a value is JSON-compatible.
 * Rejects undefined, functions, symbols, and class instances.
 */
export function isJsonCompatible(v: unknown): boolean {
  if (v === null) return true;
  if (typeof v === "boolean" || typeof v === "number" || typeof v === "string") return true;
  if (Array.isArray(v)) return v.every(isJsonCompatible);
  if (typeof v === "object") {
    const proto = Object.getPrototypeOf(v) as unknown;
    if (proto !== Object.prototype && proto !== null) return false;
    return Object.values(v as Record<string, unknown>).every(isJsonCompatible);
  }
  return false;
}
