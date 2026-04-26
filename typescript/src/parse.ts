/**
 * Free-form text parsers for A3 annotation indices.
 *
 * These accept the kinds of strings users type or paste from spreadsheets and
 * text files (whitespace, commas, newlines, tabs as separators) and return
 * sorted/structured arrays suitable for {@link A3PositionData},
 * {@link A3RangeData}, or {@link A3FlexData} `index` fields.
 *
 * Errors are returned in a result envelope rather than thrown, so callers can
 * surface them in form UIs without a try/catch.
 *
 * @example
 * ```ts
 * const r = parsePositions("10, 25\n42 100");
 * if (r.ok) console.log(r.value); // [10, 25, 42, 100]
 * else console.error(r.error);
 * ```
 *
 * @module
 */

import { sortDedup, sortRanges } from "./normalize";

/** Result of a parse: either successful with a value, or failed with a message. */
export type ParseResult<T> = { ok: true; value: T } | { ok: false; error: string };

/** Tagged result of {@link parseIndex}, distinguishing position vs range shape. */
export type ParsedIndex =
  | { kind: "positions"; values: number[] }
  | { kind: "ranges"; values: [number, number][] };

const TOKEN_SPLIT = /[\s,]+/;
const RANGE_PATTERN = /^(\d+)\s*-\s*(\d+)$/;

/**
 * Parse a free-form list of 1-based positions.
 *
 * Tokens can be separated by any combination of whitespace (spaces, tabs,
 * newlines) and commas. Empty input returns `[]`. The returned array is
 * sorted ascending and deduplicated.
 *
 * @param text - Raw user text, e.g. `"10, 25, 42"` or `"10\t25\n42"`.
 */
export function parsePositions(text: string): ParseResult<number[]> {
  const trimmed = text.trim();
  if (trimmed === "") return { ok: true, value: [] };
  const tokens = trimmed.split(TOKEN_SPLIT).filter(Boolean);
  const out: number[] = [];
  for (const tok of tokens) {
    if (!/^\d+$/.test(tok)) {
      return { ok: false, error: `"${tok}" is not a positive integer` };
    }
    const n = Number(tok);
    if (!Number.isInteger(n) || n < 1) {
      return { ok: false, error: `"${tok}" must be a 1-based residue position` };
    }
    out.push(n);
  }
  return { ok: true, value: sortDedup(out) };
}

/**
 * Parse a free-form list of inclusive ranges.
 *
 * Each range has the shape `start-end` (with optional surrounding whitespace
 * around the dash). Ranges may be separated by commas, newlines, or tabs.
 * Empty input returns `[]`. The returned array is sorted by start position.
 *
 * Note: this parser does not check for overlap — that's enforced by
 * {@link A3InputSchema} at the document level.
 *
 * @param text - Raw user text, e.g. `"1-50, 75-100"` or `"1-50\n75-100"`.
 */
export function parseRanges(text: string): ParseResult<[number, number][]> {
  const trimmed = text.trim();
  if (trimmed === "") return { ok: true, value: [] };
  // Split on commas, newlines, and tabs — but not on spaces, since users may
  // type ranges with whitespace around the dash (e.g. `1 - 50`). Tab/newline
  // covers spreadsheet paste (column or row) without forcing a particular
  // delimiter.
  const parts = trimmed
    .split(/[,\n\r\t]+/)
    .map((s) => s.trim())
    .filter(Boolean);
  const out: [number, number][] = [];
  for (const part of parts) {
    const m = part.match(RANGE_PATTERN);
    if (!m) {
      return { ok: false, error: `"${part}" is not a "start-end" range` };
    }
    const start = Number(m[1]);
    const end = Number(m[2]);
    if (start < 1 || end < 1) {
      return { ok: false, error: `"${part}" — positions must be ≥ 1` };
    }
    if (end < start) {
      return { ok: false, error: `"${part}" — end must be ≥ start` };
    }
    out.push([start, end]);
  }
  return { ok: true, value: sortRanges(out) };
}

/**
 * Auto-detecting index parser for flex annotation families (PTM, processing).
 *
 * If any token contains a `-`, the input is interpreted as a list of ranges;
 * otherwise it's parsed as positions. Empty input is treated as positions.
 *
 * @param text - Raw user text.
 */
export function parseIndex(text: string): ParseResult<ParsedIndex> {
  const trimmed = text.trim();
  if (trimmed === "") return { ok: true, value: { kind: "positions", values: [] } };
  // Detect presence of '-' anywhere in the body (excluding leading/trailing
  // whitespace). Any range-shaped token triggers range mode for the whole
  // input, which keeps the parse result coherent.
  const looksLikeRanges = /\d\s*-\s*\d/.test(trimmed);
  if (looksLikeRanges) {
    const r = parseRanges(text);
    if (!r.ok) return r;
    return { ok: true, value: { kind: "ranges", values: r.value } };
  }
  const r = parsePositions(text);
  if (!r.ok) return r;
  return { ok: true, value: { kind: "positions", values: r.value } };
}

/** Format a position array as a comma-separated string. Empty input → `""`. */
export function formatPositions(arr: readonly number[]): string {
  if (arr.length === 0) return "";
  return arr.join(", ");
}

/** Format a range array as a comma-separated `start-end` string. Empty input → `""`. */
export function formatRanges(arr: readonly [number, number][]): string {
  if (arr.length === 0) return "";
  return arr.map(([s, e]) => `${s}-${e}`).join(", ");
}
