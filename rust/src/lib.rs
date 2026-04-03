//! # rtemis-a3
//!
//! Rust implementation of the [A3 (Amino Acid Annotation) format](https://a3.rtemis.org).
//!
//! A3 is a structured format for annotating amino acid sequences with site,
//! region, post-translational modification, processing, and variant information.
//!
//! ## Quick start
//!
//! ```rust
//! use rtemis_a3::{a3_from_json, a3_to_json};
//!
//! let json = r#"{
//!   "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
//!   "a3_version": "1.0.0",
//!   "sequence": "MAEPRQ",
//!   "annotations": { "site": {}, "region": {}, "ptm": {}, "processing": {}, "variant": [] },
//!   "metadata": { "uniprot_id": "", "description": "", "reference": "", "organism": "" }
//! }"#;
//!
//! let a3 = a3_from_json(json).unwrap();
//! assert_eq!(a3.sequence(), "MAEPRQ");
//! ```
//!
//! ## Module layout
//!
//! - [`error`]     — `A3Error` enum
//! - [`types`]     — data model structs and enums
//! - [`normalization`] — pure helpers: sort, deduplicate, overlap check
//! - [`validation`]  — two-stage validation (structural then contextual)

pub mod error;
pub mod normalization;
pub mod types;
pub mod validation;

// Re-export the most commonly used items so users can write
// `use rtemis_a3::A3` instead of `use rtemis_a3::types::A3`.
pub use error::A3Error;
pub use types::{
    A3, A3_SCHEMA_URI, A3_VERSION, A3Index, Annotations, FlexEntry, Metadata, RegionEntry,
    SiteEntry, VariantRecord,
};
pub use validation::validate;

use serde::Serialize as _;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse and validate an A3 JSON string.
///
/// This function composes two steps:
/// 1. `serde_json::from_str` — deserialize the JSON into a raw [`A3`] struct.
/// 2. [`validate()`] — normalize fields and enforce all A3 rules (from [`validation`]).
///
/// Both steps return `Result<_, A3Error>`. The `?` operator is Rust's concise
/// way to propagate errors: if the expression on its left is `Err(e)`, the
/// function immediately returns `Err(e.into())` (converting the error type if
/// needed). If it is `Ok(value)`, execution continues with `value`.
///
/// Without `?` the first line would be:
/// ```ignore
/// let raw: A3 = match serde_json::from_str(text) {
///     Ok(v)  => v,
///     Err(e) => return Err(A3Error::from(e)),
/// };
/// ```
///
/// `?` makes chains of fallible operations read almost like non-fallible code.
pub fn a3_from_json(text: &str) -> Result<A3, A3Error> {
    // `serde_json::from_str` returns `Result<A3, serde_json::Error>`.
    // The `?` converts `serde_json::Error` → `A3Error::Parse` automatically
    // because we wrote `#[from] serde_json::Error` in the error definition.
    let raw: A3 = serde_json::from_str(text)?;

    // `validate` returns `Result<A3, A3Error>` — same error type, so `?`
    // needs no conversion here.
    validate(raw)
}

/// Serialize a validated [`A3`] to a JSON string.
///
/// `indent` controls formatting:
/// - `None`    — compact, no whitespace (good for storage / wire transfer)
/// - `Some(n)` — pretty-printed with `n` spaces per level (good for display)
///
/// Returns `Err(`[`A3Error::Serialize`]`)` if serde_json fails while
/// serializing. In practice this is unreachable for well-typed A3 values.
///
/// `a3` is passed as `&A3` (an immutable reference) because we only need to
/// read it, not own or modify it. The caller keeps ownership.
pub fn a3_to_json(a3: &A3, indent: Option<usize>) -> Result<String, A3Error> {
    match indent {
        // Compact output — single line, no extra whitespace.
        // `.map_err(A3Error::Serialize)` is required before `?` because
        // `#[from]` is only on A3Error::Parse, so serde_json::Error does not
        // auto-convert into A3Error::Serialize.
        None => Ok(serde_json::to_string(a3).map_err(A3Error::Serialize)?),

        // Pretty output with a custom indent width.
        //
        // `serde_json::to_string_pretty` hard-codes 2 spaces, so we use the
        // lower-level `Serializer` + `PrettyFormatter` API to get any width.
        Some(n) => {
            let indent_str = " ".repeat(n);

            // `PrettyFormatter::with_indent` takes a byte slice (`&[u8]`).
            // `.as_bytes()` converts `&str` → `&[u8]` (safe for ASCII spaces).
            let formatter = serde_json::ser::PrettyFormatter::with_indent(indent_str.as_bytes());

            // Collect serialized bytes into a `Vec<u8>` (a growable byte buffer).
            let mut buf = Vec::new();
            let mut ser = serde_json::Serializer::with_formatter(&mut buf, formatter);

            // `Serialize::serialize` is the trait method — we call it explicitly
            // because `a3` already has `#[derive(Serialize)]` from types.rs.
            a3.serialize(&mut ser).map_err(A3Error::Serialize)?;

            // serde_json always produces valid UTF-8, so `unwrap` is safe here.
            // `expect` is like `unwrap` but with a custom panic message if it
            // ever fires — useful as documentation of why we believe it is safe.
            Ok(String::from_utf8(buf).expect("serde_json always produces valid UTF-8"))
        }
    }
}

/// Return the amino acid character at a 1-based `position`.
///
/// Returns `None` if `position` is 0 or beyond the sequence length.
///
/// `Option<T>` is Rust's null-safe alternative to nullable values — unlike
/// `null` in other languages, the compiler forces callers to handle both
/// `Some(value)` and `None` before they can use the result.
pub fn residue_at(a3: &A3, position: u32) -> Option<char> {
    if position == 0 || position > a3.sequence.len() as u32 {
        return None;
    }

    // Positions are 1-based; byte index is 0-based — subtract 1.
    // The sequence is validated to be ASCII-only ([A-Z*]), so each character
    // is exactly one byte. `.as_bytes().get(i)` is O(1), whereas
    // `.chars().nth(i)` would be O(N) because it walks the UTF-8 string.
    // Casting `u8 → char` is safe for ASCII values.
    a3.sequence
        .as_bytes()
        .get((position - 1) as usize)
        .map(|&b| b as char)
}

/// Return all variant records at a 1-based `position`.
///
/// Returns references into `a3`'s data without copying anything.
/// The compiler infers that the returned `&VariantRecord` references live as
/// long as the `&A3` reference passed in (lifetime elision — the `'a`
/// annotations are implicit but enforced).
pub fn variants_at(a3: &A3, position: u32) -> Vec<&VariantRecord> {
    a3.annotations
        .variant
        .iter()
        .filter(|v| v.position == position)
        .collect()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // The minimal JSON the spec requires all five families to be present.
    const MINIMAL_JSON: &str = r#"{
        "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
        "a3_version": "1.0.0",
        "sequence": "MAEPRQ",
        "annotations": {
            "site": {},
            "region": {},
            "ptm": {},
            "processing": {},
            "variant": []
        },
        "metadata": {
            "uniprot_id": "",
            "description": "",
            "reference": "",
            "organism": ""
        }
    }"#;

    #[test]
    fn round_trip() {
        // Parse → serialize → parse again; both A3 values must be identical.
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        let json = a3_to_json(&a3, None).unwrap();
        let a3_again = a3_from_json(&json).unwrap();
        // `#[derive(Debug)]` is needed for `assert_eq!` to display the values
        // on failure. We compare the re-serialized form since field order may
        // differ — if both round-trip identically they are semantically equal.
        assert_eq!(
            a3_to_json(&a3, None).unwrap(),
            a3_to_json(&a3_again, None).unwrap()
        );
    }

    #[test]
    fn residue_at_valid_position() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        // "MAEPRQ" — position 1 is 'M', position 6 is 'Q'.
        assert_eq!(residue_at(&a3, 1), Some('M'));
        assert_eq!(residue_at(&a3, 6), Some('Q'));
    }

    #[test]
    fn residue_at_out_of_bounds() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        assert_eq!(residue_at(&a3, 0), None);
        assert_eq!(residue_at(&a3, 99), None);
    }

    #[test]
    fn rejects_missing_schema() {
        let json = r#"{"a3_version":"1.0.0","sequence":"MAEPRQ","annotations":{"site":{},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{}}"#;
        assert!(a3_from_json(json).is_err());
    }

    #[test]
    fn rejects_wrong_schema_uri() {
        let json = r#"{"$schema":"https://example.com/wrong","a3_version":"1.0.0","sequence":"MAEPRQ","annotations":{"site":{},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{}}"#;
        assert!(a3_from_json(json).is_err());
    }

    #[test]
    fn rejects_missing_version() {
        let json = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","sequence":"MAEPRQ","annotations":{"site":{},"region":{},"ptm":{},"processing":{},"variant":[]},"metadata":{}}"#;
        assert!(a3_from_json(json).is_err());
    }

    #[test]
    fn rejects_unknown_top_level_key() {
        let json = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","a3_version":"1.0.0","sequence":"MAEPRQ","foo":"bar"}"#;
        assert!(a3_from_json(json).is_err());
    }

    #[test]
    fn rejects_unknown_metadata_key() {
        let json = r#"{"$schema":"https://schema.rtemis.org/a3/v1/schema.json","a3_version":"1.0.0","sequence":"MAEPRQ","metadata":{"gene":"MAPT"}}"#;
        assert!(a3_from_json(json).is_err());
    }

    #[test]
    fn pretty_print_contains_newlines() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        let pretty = a3_to_json(&a3, Some(2)).unwrap();
        assert!(pretty.contains('\n'));
    }
}
