/**
 * Conformance runner: checks this implementation against the shared corpus.
 *
 * The corpus lives at `spec/conformance/` in the repository root and is read by
 * all five A3 implementations. It is never vendored into a language directory —
 * one corpus, five readers, or it drifts.
 *
 * See `spec/conformance/README.md` for the assertion semantics implemented here.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { A3_ISSUE_CODES, type A3Issue, type A3IssueCode, stageOf } from "../src/issues.ts";
import { validate } from "../src/validate.ts";

// tests/ -> typescript/ -> <repo>
const CORPUS = join(import.meta.dirname, "..", "..", "spec", "conformance");

interface ExpectedIssue {
  code: A3IssueCode;
  path: string;
}

interface Case {
  file: string;
  description: string;
  valid: boolean;
  stage?: number;
  issues?: ExpectedIssue[];
  normalized?: string;
}

function load<T>(rel: string): T {
  return JSON.parse(readFileSync(join(CORPUS, rel), "utf-8")) as T;
}

const manifest = load<{ cases: Case[] }>("manifest.json");

/**
 * Count each `code path` pair.
 *
 * Issues are compared as a **multiset**: a rule can legitimately fire more than
 * once at the same path (two repeated positions in one index produce two
 * `A3E_POS_DUPLICATE` issues), and an implementation that reports one of them
 * has not conformed. Order is not compared.
 */
function tally(pairs: Iterable<readonly [string, string]>): Map<string, number> {
  const counts = new Map<string, number>();
  for (const [code, path] of pairs) {
    const key = `${code} ${path}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

/** Describe the difference between two issue multisets, or `""` if equal. */
function diff(expected: Map<string, number>, actual: Map<string, number>): string {
  const lines: string[] = [];
  for (const [key, want] of [...expected].sort()) {
    const got = actual.get(key) ?? 0;
    if (got < want) lines.push(`  missing:    ${key}  (expected ${want}, got ${got})`);
  }
  for (const [key, got] of [...actual].sort()) {
    const want = expected.get(key) ?? 0;
    if (got > want) lines.push(`  unexpected: ${key}  (expected ${want}, got ${got})`);
  }
  return lines.join("\n");
}

/**
 * Project a JSON value so that `toEqual` treats object key order as significant.
 *
 * `JSON.parse` preserves member order, but a plain object comparison ignores it.
 * Comparing an array of entries instead makes order part of the comparison,
 * which is what turns these cases into a normalization test rather than merely
 * a parsing test.
 */
function ordered(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(ordered);
  if (value !== null && typeof value === "object") {
    return Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, ordered(v)]);
  }
  return value;
}

describe("conformance corpus", () => {
  for (const testCase of manifest.cases) {
    it(testCase.file, () => {
      const text = readFileSync(join(CORPUS, testCase.file), "utf-8");
      const { data, issues } = validate(JSON.parse(text));

      if (testCase.valid) {
        expect(
          data,
          `${testCase.description}\n  expected valid, got:\n${format(issues)}`,
        ).not.toBeNull();
        if (testCase.normalized === undefined) return;

        const produced = JSON.parse(JSON.stringify(data));
        const expected = load<unknown>(testCase.normalized);
        expect(
          ordered(produced),
          `${testCase.description}\n  round-trip differs from ${testCase.normalized}`,
        ).toEqual(ordered(expected));
        return;
      }

      const expectedIssues = testCase.issues ?? [];
      const want = tally(expectedIssues.map((i) => [i.code, i.path] as const));
      const got = tally(issues.map((i) => [i.code, i.path] as const));
      expect(diff(want, got), `${testCase.description}`).toBe("");

      // Every issue in one result comes from a single stage, and the manifest
      // records which. A mismatch means the staging is wrong even though the
      // issue set happens to agree.
      if (testCase.stage !== undefined) {
        const first = issues[0];
        expect(first === undefined ? undefined : stageOf(first)).toBe(testCase.stage);
      }
    });
  }
});

describe("registry coverage", () => {
  it("every code has a corpus case", () => {
    // Without this, the registry and the corpus drift within two months: a code
    // is added, no case is written, and nothing notices.
    const covered = new Set(
      manifest.cases.filter((c) => !c.valid).flatMap((c) => (c.issues ?? []).map((i) => i.code)),
    );
    const missing = A3_ISSUE_CODES.filter((code) => !covered.has(code));
    expect(missing, "codes with no corpus case").toEqual([]);

    const known = new Set<string>(A3_ISSUE_CODES);
    const unknown = [...covered].filter((code) => !known.has(code));
    expect(unknown, "corpus expects codes not in the registry").toEqual([]);
  });
});

function format(issues: readonly A3Issue[]): string {
  return issues.map((i) => `    [${i.code}] ${i.path || "<document>"}: ${i.message}`).join("\n");
}
