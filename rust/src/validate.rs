//! Two-stage A3 validation.
//!
//! **Stage 1 — Structural**: normalize each field (uppercase sequence, sort
//! and deduplicate positions, sort and overlap-check ranges). Collects all
//! errors before returning, so the caller sees every problem at once.
//!
//! **Stage 2 — Contextual**: verify that every position and range endpoint
//! falls within the bounds of the (now-known) sequence length.

use std::collections::HashMap;

use crate::error::A3Error;
use crate::normalize::{normalize_positions, normalize_ranges, normalize_sequence};
use crate::types::{A3, A3Index, Annotations, FlexEntry, Metadata, RegionEntry, SiteEntry, VariantRecord};

/// Validate and normalize a raw-deserialized [`A3`] value.
///
/// Accepts an `A3` produced by `serde_json::from_str` (which enforces shape
/// but not A3-specific rules) and returns a fully normalized `A3`, or an
/// [`A3Error::Validate`] containing every violation found.
///
/// We take `raw` by value (`A3`, not `&A3`) because we return a new,
/// normalized `A3`. Rust moves the value in — no copy needed.
pub fn validate(raw: A3) -> Result<A3, A3Error> {
    // Accumulate every error before returning. This lets callers fix all
    // problems at once instead of playing whack-a-mole with one error at a time.
    //
    // `Vec::new()` creates an empty growable list.
    // `mut` is required because we will call `.push()` on it.
    let mut errors: Vec<String> = Vec::new();

    // -----------------------------------------------------------------------
    // Stage 1 — Structural validation and normalization
    // -----------------------------------------------------------------------

    // --- Sequence ---
    //
    // `match` destructures a `Result` into its two possible states.
    // `Ok(s)` — normalization succeeded; bind the clean value to `s`.
    // `Err(e)` — normalization failed; record the error and carry a placeholder
    //            so the rest of validation can still run (bounds checks need a
    //            sequence length, even a wrong one is better than stopping).
    let sequence = match normalize_sequence(&raw.sequence) {
        Ok(s) => s,
        Err(e) => {
            errors.push(e);
            // Use the raw value as a stand-in so Stage 2 has *something* to
            // work with. Any bounds errors here will be secondary anyway.
            raw.sequence.to_uppercase()
        }
    };

    // --- Site ---
    //
    // `HashMap::new()` creates an empty hash map that we fill as we go.
    let mut site: HashMap<String, SiteEntry> = HashMap::new();

    for (name, entry) in raw.annotations.site {
        // Annotation names must be non-empty strings.
        if name.is_empty() {
            errors.push("annotations.site: annotation name must not be empty".to_string());
            continue; // `continue` skips to the next loop iteration.
        }

        // Build the field path used in error messages: "annotations.site.myName"
        // `format!` works like Python's f-strings but uses `{}` placeholders.
        let field = format!("annotations.site.{name}");

        match normalize_positions(entry.index, &field) {
            Ok(index) => {
                // `SiteEntry { index, kind: entry.kind }` is struct literal syntax.
                // When the field name and variable name match, Rust allows the
                // shorthand `{ index }` instead of `{ index: index }`.
                site.insert(name, SiteEntry { index, kind: entry.kind });
            }
            Err(e) => errors.push(e),
        }
    }

    // --- Region ---
    let mut region: HashMap<String, RegionEntry> = HashMap::new();

    for (name, entry) in raw.annotations.region {
        if name.is_empty() {
            errors.push("annotations.region: annotation name must not be empty".to_string());
            continue;
        }

        let field = format!("annotations.region.{name}");

        match normalize_ranges(entry.index, &field) {
            Ok(index) => {
                region.insert(name, RegionEntry { index, kind: entry.kind });
            }
            Err(e) => errors.push(e),
        }
    }

    // --- PTM and Processing (shared logic via a helper) ---
    //
    // Both families use `FlexEntry` with `A3Index` (positions or ranges).
    // Rather than duplicating the loop twice, we call a shared helper function
    // defined below this one. We pass `&mut errors` so the helper can append
    // to the same error list.
    let ptm = normalize_flex_family(raw.annotations.ptm, "ptm", &mut errors);
    let processing = normalize_flex_family(raw.annotations.processing, "processing", &mut errors);

    // --- Variant ---
    let mut variant: Vec<VariantRecord> = Vec::new();

    for (i, record) in raw.annotations.variant.into_iter().enumerate() {
        // `u32` can hold 0, but positions are 1-based. Check explicitly.
        if record.position == 0 {
            errors.push(format!(
                "annotations.variant[{i}].position: must be ≥ 1 (1-based); got 0"
            ));
        }
        // We keep the record even if the position is 0 so that Stage 2
        // bounds-checks can run (they will also catch 0 as out-of-bounds).
        variant.push(record);
    }

    // -----------------------------------------------------------------------
    // Stage 2 — Contextual (bounds) validation
    //
    // Now that normalization is done we know the final sequence length.
    // Every position and range endpoint must satisfy 1 ≤ value ≤ seq_len.
    // -----------------------------------------------------------------------

    // `len()` returns `usize` (pointer-sized unsigned int). Cast to `u32` so
    // comparisons with positions (also `u32`) work without type mismatches.
    let seq_len = sequence.len() as u32;

    // Pass `&mut errors` and `seq_len` explicitly to standalone helper functions
    // defined below. This avoids the borrow checker error that would occur if we
    // used two closures that both capture `&mut errors`: Rust permits only one
    // mutable borrow of a value at a time, and two live closures would each hold
    // one, violating that rule. Plain functions do not capture anything, so there
    // is no borrow conflict.

    for (name, entry) in &site {
        check_positions_bounds(&entry.index, seq_len, &format!("annotations.site.{name}"), &mut errors);
    }

    for (name, entry) in &region {
        check_ranges_bounds(&entry.index, seq_len, &format!("annotations.region.{name}"), &mut errors);
    }

    for (name, entry) in &ptm {
        let field = format!("annotations.ptm.{name}");
        match &entry.index {
            A3Index::Positions(positions) => check_positions_bounds(positions, seq_len, &field, &mut errors),
            A3Index::Ranges(ranges) => check_ranges_bounds(ranges, seq_len, &field, &mut errors),
        }
    }

    for (name, entry) in &processing {
        let field = format!("annotations.processing.{name}");
        match &entry.index {
            A3Index::Positions(positions) => check_positions_bounds(positions, seq_len, &field, &mut errors),
            A3Index::Ranges(ranges) => check_ranges_bounds(ranges, seq_len, &field, &mut errors),
        }
    }

    for (i, record) in variant.iter().enumerate() {
        if record.position > seq_len {
            errors.push(format!(
                "annotations.variant[{i}].position: position {} is out of bounds \
                 for sequence of length {seq_len} (must be 1–{seq_len})",
                record.position
            ));
        }
    }

    // -----------------------------------------------------------------------
    // Return
    // -----------------------------------------------------------------------

    if !errors.is_empty() {
        return Err(A3Error::Validate(errors));
    }

    Ok(A3 {
        sequence,
        annotations: Annotations { site, region, ptm, processing, variant },
        // Metadata fields are plain strings — no normalization needed. We keep
        // whatever serde produced (the `default` attribute already filled in
        // empty strings for absent keys and `deny_unknown_fields` rejected extras).
        metadata: Metadata {
            uniprot_id: raw.metadata.uniprot_id,
            description: raw.metadata.description,
            reference: raw.metadata.reference,
            organism: raw.metadata.organism,
        },
    })
}

/// Normalize a PTM or Processing annotation family.
///
/// This is a private helper (no `pub`) — only visible inside this module.
/// It handles the `A3Index` enum by matching on which variant is present and
/// calling the appropriate normalizer.
///
/// `family` is `"ptm"` or `"processing"` — used to build field paths.
/// `errors` is passed as a mutable reference (`&mut`) so we append directly
/// into the caller's error list without allocating a new one.
fn normalize_flex_family(
    entries: HashMap<String, FlexEntry>,
    family: &str,
    errors: &mut Vec<String>,
) -> HashMap<String, FlexEntry> {
    let mut out: HashMap<String, FlexEntry> = HashMap::new();

    for (name, entry) in entries {
        if name.is_empty() {
            errors.push(format!(
                "annotations.{family}: annotation name must not be empty"
            ));
            continue;
        }

        let field = format!("annotations.{family}.{name}");

        // Match on which `A3Index` variant we have, normalize accordingly.
        let index = match entry.index {
            A3Index::Positions(positions) => match normalize_positions(positions, &field) {
                Ok(p) => A3Index::Positions(p),
                Err(e) => {
                    errors.push(e);
                    continue;
                }
            },
            A3Index::Ranges(ranges) => match normalize_ranges(ranges, &field) {
                Ok(r) => A3Index::Ranges(r),
                Err(e) => {
                    errors.push(e);
                    continue;
                }
            },
        };

        out.insert(name, FlexEntry { index, kind: entry.kind });
    }

    out
}

/// Check that every position in `positions` is within `1..=seq_len`.
///
/// Takes `errors` as `&mut Vec<String>` — a mutable reference to the caller's
/// error list. This lets us append without allocating a new `Vec` or returning
/// anything. The `&mut` makes the borrow explicit and exclusive: while this
/// function runs, no other code can access `errors`.
fn check_positions_bounds(positions: &[u32], seq_len: u32, field: &str, errors: &mut Vec<String>) {
    for &pos in positions {
        if pos > seq_len {
            errors.push(format!(
                "{field}: position {pos} is out of bounds for sequence of \
                 length {seq_len} (must be 1–{seq_len})"
            ));
        }
    }
}

/// Check that every range endpoint in `ranges` is within `1..=seq_len`.
///
/// Only the `end` of each range needs checking: `end >= start >= 1` is already
/// guaranteed by `normalize_ranges`, so `end` is always the larger value.
fn check_ranges_bounds(ranges: &[[u32; 2]], seq_len: u32, field: &str, errors: &mut Vec<String>) {
    for [start, end] in ranges {
        if *end > seq_len {
            errors.push(format!(
                "{field}: range [{start}, {end}] is out of bounds for sequence \
                 of length {seq_len} (must be 1–{seq_len})"
            ));
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a minimal valid raw A3 for use in tests.
    ///
    /// `fn` returning a value (no `-> ()` means it returns the unit type by
    /// default, but here we specify `-> A3`). This is a plain helper — Rust
    /// does not need `self` for functions that are not methods on a type.
    fn minimal_raw() -> A3 {
        A3 {
            sequence: "MAEPRQ".to_string(),
            annotations: Annotations::default(),
            metadata: Metadata::default(),
        }
    }

    #[test]
    fn valid_minimal_a3() {
        let result = validate(minimal_raw());
        assert!(result.is_ok());
    }

    #[test]
    fn sequence_is_uppercased() {
        let mut raw = minimal_raw();
        raw.sequence = "maeprq".to_string();
        let a3 = validate(raw).unwrap();
        assert_eq!(a3.sequence, "MAEPRQ");
    }

    #[test]
    fn rejects_short_sequence() {
        let mut raw = minimal_raw();
        raw.sequence = "M".to_string();
        assert!(validate(raw).is_err());
    }

    #[test]
    fn rejects_out_of_bounds_site_position() {
        let mut raw = minimal_raw();
        // Sequence length is 6; position 10 is out of bounds.
        raw.annotations.site.insert(
            "test".to_string(),
            SiteEntry { index: vec![10], kind: String::new() },
        );
        let err = validate(raw).unwrap_err();
        // Pattern match to confirm it is a Validate error, not a Parse error.
        assert!(matches!(err, A3Error::Validate(_)));
    }

    #[test]
    fn collects_multiple_errors() {
        let mut raw = minimal_raw();
        // Two invalid site entries — both errors should appear.
        raw.annotations.site.insert(
            "a".to_string(),
            SiteEntry { index: vec![99], kind: String::new() },
        );
        raw.annotations.site.insert(
            "b".to_string(),
            SiteEntry { index: vec![88], kind: String::new() },
        );
        match validate(raw) {
            Err(A3Error::Validate(errs)) => assert_eq!(errs.len(), 2),
            _ => panic!("expected Validate error with 2 messages"),
        }
    }
}
