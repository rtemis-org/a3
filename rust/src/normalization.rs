//! Pure normalization helpers.
//!
//! Each function takes raw input and returns a normalized, validated form —
//! or an error string describing exactly what is wrong. No side effects.
//!
//! Normalization rules (from the A3 spec):
//! - Positions: sorted ascending, duplicates removed, all values ≥ 1
//! - Ranges: sorted by start position, all values ≥ 1, each start < end,
//!   no overlapping pairs

/// Normalize a list of positions.
///
/// Steps, in order:
/// 1. Reject any position that is zero (positions are 1-based).
/// 2. Sort ascending.
/// 3. Reject duplicate positions.
///
/// Returns `Ok(Vec<u32>)` on success, or `Err(String)` describing the problem.
///
/// The `field` parameter is the dot-separated JSON path (e.g.
/// `"annotations.site.catalytic"`) used in error messages so the caller
/// knows exactly where the problem is.
pub fn normalize_positions(positions: Vec<u32>, field: &str) -> Result<Vec<u32>, String> {
    if positions.contains(&0) {
        return Err(format!(
            "{field}: positions must be ≥ 1 (1-based); found zero"
        ));
    }

    let mut sorted = positions;
    sorted.sort_unstable();

    // Reject duplicates — adjacent after sorting.
    if let Some(dup) = sorted.windows(2).find(|w| w[0] == w[1]) {
        return Err(format!("{field}: duplicate position: {}", dup[0]));
    }

    Ok(sorted)
}

/// Normalize a list of `[start, end]` range pairs.
///
/// Steps, in order:
/// 1. Reject any endpoint that is zero (positions are 1-based).
/// 2. Reject any range where `start >= end` (degenerate ranges are not allowed).
/// 3. Sort by start position (then by end position for ties).
/// 4. Reject overlapping ranges (two ranges overlap when the second start ≤
///    the first end, after sorting).
///
/// Returns `Ok(Vec<[u32; 2]>)` on success, or `Err(String)` on failure.
pub fn normalize_ranges(ranges: Vec<[u32; 2]>, field: &str) -> Result<Vec<[u32; 2]>, String> {
    // Check for zero endpoints.
    // `.any()` short-circuits: returns true as soon as one element matches.
    if ranges.iter().any(|[s, e]| *s == 0 || *e == 0) {
        return Err(format!(
            "{field}: range endpoints must be ≥ 1 (1-based); found zero"
        ));
    }

    // Check that every range satisfies start < end.
    // We collect violations so the error message can list them all at once.
    let bad: Vec<[u32; 2]> = ranges.iter().filter(|[s, e]| s >= e).copied().collect();

    if !bad.is_empty() {
        return Err(format!(
            "{field}: each range must satisfy start < end; invalid ranges: {bad:?}"
        ));
    }

    // Sort by start, then by end for ties.
    // `mut` because sort works in-place.
    let mut sorted = ranges;

    // `.sort_unstable_by()` accepts a comparator closure.
    // `|a, b| ...` is a closure (anonymous function) — like a lambda in Python.
    // `.cmp()` returns `Ordering::{Less, Equal, Greater}`.
    // `.then_with()` breaks ties using a second comparator.
    sorted.sort_unstable_by(|[a_s, a_e], [b_s, b_e]| a_s.cmp(b_s).then_with(|| a_e.cmp(b_e)));

    // Check for overlapping ranges.
    // `.windows(2)` yields every consecutive pair: [r0, r1], [r1, r2], ...
    // This is an efficient way to compare each range with the next.
    //
    // Two ranges [a_s, a_e] and [b_s, b_e] overlap when b_s <= a_e
    // (after sorting so b_s >= a_s is guaranteed).
    let overlapping: Vec<[[u32; 2]; 2]> = sorted
        .windows(2)
        .filter(|pair| pair[1][0] <= pair[0][1])
        .map(|pair| [pair[0], pair[1]])
        .collect();

    if !overlapping.is_empty() {
        return Err(format!(
            "{field}: ranges must not overlap; overlapping pairs: {overlapping:?}"
        ));
    }

    Ok(sorted)
}

/// Normalize a sequence string.
///
/// Steps, in order:
/// 1. Uppercase the input (spec: lowercase is accepted and normalized).
/// 2. Reject if empty or shorter than 2 characters.
/// 3. Reject any character not in `[A-Z*]`.
///
/// Returns `Ok(String)` on success or `Err(String)` on failure.
pub fn normalize_sequence(sequence: &str) -> Result<String, String> {
    // `.to_ascii_uppercase()` is correct here: the A3 spec restricts input to
    // `[A-Za-z*]`, which is pure ASCII. The Unicode-aware `.to_uppercase()`
    // can change string length for non-ASCII code points and may accept
    // characters that map to valid ASCII letters — both undesirable.
    let upper = sequence.to_ascii_uppercase();

    if upper.len() < 2 {
        return Err(format!(
            "sequence: must be at least 2 characters; got {} (\"{}\")",
            upper.len(),
            upper
        ));
    }

    // Find any character that is not A-Z or *.
    // `.chars()` iterates over Unicode scalar values (safe for UTF-8 strings).
    // `.find()` returns `Option<char>` — `Some(c)` if found, `None` if not.
    if let Some(bad_char) = upper.chars().find(|c| !matches!(c, 'A'..='Z' | '*')) {
        return Err(format!(
            "sequence: invalid character {bad_char:?}; \
             only A-Z (standard IUPAC amino acid codes) and * (stop codon) are permitted"
        ));
    }

    Ok(upper)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    // `super::*` imports everything from the parent module (normalize).
    // This is the standard pattern for unit tests in Rust — tests live in
    // the same file as the code they test, inside a `#[cfg(test)]` module.
    use super::*;

    #[test]
    fn positions_sorted() {
        let result = normalize_positions(vec![3, 1, 2], "test").unwrap();
        assert_eq!(result, vec![1, 2, 3]);
    }

    #[test]
    fn positions_rejects_duplicates() {
        assert!(normalize_positions(vec![3, 1, 2, 1], "test").is_err());
    }

    #[test]
    fn positions_rejects_zero() {
        assert!(normalize_positions(vec![0, 1, 2], "test").is_err());
    }

    #[test]
    fn ranges_sorted_and_valid() {
        let result = normalize_ranges(vec![[5, 10], [1, 3]], "test").unwrap();
        assert_eq!(result, vec![[1, 3], [5, 10]]);
    }

    #[test]
    fn ranges_rejects_degenerate() {
        // start == end is not permitted
        assert!(normalize_ranges(vec![[3, 3]], "test").is_err());
    }

    #[test]
    fn ranges_rejects_overlap() {
        assert!(normalize_ranges(vec![[1, 5], [4, 8]], "test").is_err());
    }

    #[test]
    fn ranges_allows_adjacent() {
        // [1,3] and [4,8] are adjacent (not overlapping) — must be accepted
        let result = normalize_ranges(vec![[1, 3], [4, 8]], "test").unwrap();
        assert_eq!(result, vec![[1, 3], [4, 8]]);
    }

    #[test]
    fn sequence_uppercased() {
        let result = normalize_sequence("maeprq").unwrap();
        assert_eq!(result, "MAEPRQ");
    }

    #[test]
    fn sequence_rejects_short() {
        assert!(normalize_sequence("M").is_err());
    }

    #[test]
    fn sequence_rejects_invalid_chars() {
        assert!(normalize_sequence("MAEP1Q").is_err());
    }
}
