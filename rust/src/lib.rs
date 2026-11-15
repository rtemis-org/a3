//! # rtemis-a3
//!
//! Rust implementation of the [A3 (Amino Acid Annotation) format](https://a3.rtemis.org).
//!
//! A3 is a structured format for annotating amino acid sequences with site,
//! region, post-translational modification, processing, and variant information.
//!
//! ## Usage
//!
//! ```rust
//! use rtemis_a3::{a3_from_json, a3_to_json};
//!
//! // `annotations` and `metadata` are optional; both default to empty.
//! let json = r#"{
//!   "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
//!   "a3_version": "1.0.0",
//!   "sequence": "MAEPRQ"
//! }"#;
//!
//! let a3 = a3_from_json(json).unwrap();
//! assert_eq!(a3.sequence(), "MAEPRQ");
//! ```
//!
//! ## Error handling
//!
//! Validation is **collect-all**: a document is checked in four stages, every
//! issue in the earliest failing stage is reported at once, and each issue
//! carries a stable code and an RFC 6901 JSON Pointer.
//!
//! ```rust
//! use rtemis_a3::a3_from_json;
//!
//! let json = r#"{
//!   "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
//!   "a3_version": "1.0.0",
//!   "sequence": "MAEPRQ",
//!   "annotations": { "site": { "active": { "index": [3, 99] } } }
//! }"#;
//!
//! let err = a3_from_json(json).unwrap_err();
//! let issues = err.issues();
//! assert_eq!(issues.len(), 1);
//! assert_eq!(issues[0].code.code(), "A3E_POS_OUT_OF_BOUNDS");
//! assert_eq!(issues[0].path, "/annotations/site/active/index/1");
//! assert_eq!(err.stage(), Some(4));
//! ```
//!
//! Codes and paths are contractual and identical across the R, Python, Julia,
//! TypeScript, and Rust implementations. Messages are not — they may be
//! reworded freely. See [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) and
//! [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md).
//!
//! ## Module layout
//!
//! - [`error`]         — `A3Error` enum
//! - [`issue`]         — `A3Issue`, `A3IssueCode`, JSON Pointer construction
//! - [`types`]         — data model structs and enums
//! - [`normalization`] — the three normalization rules
//! - [`validation`]    — four-stage validation over the raw parsed JSON

pub mod error;
pub mod issue;
pub mod normalization;
pub mod types;
pub mod validation;

// Re-export the most commonly used items so users can write
// `use rtemis_a3::A3` instead of `use rtemis_a3::types::A3`.
pub use error::A3Error;
pub use issue::{A3Issue, A3IssueCode};
pub use types::{
    A3, A3_SCHEMA_URI, A3_VERSION, A3Index, Annotations, FlexEntry, Metadata, RegionEntry,
    SiteEntry, VariantRecord,
};
pub use validation::validate;

use serde::Serialize as _;
use serde_json::Value;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse and validate an A3 JSON string.
///
/// Two steps, in order:
/// 1. `serde_json::from_str` into a generic [`Value`] — this can only fail if
///    the input is not JSON at all.
/// 2. [`validate()`] — four staged passes producing a normalized [`A3`], or
///    every issue found in the earliest failing stage.
///
/// Step 1 does *not* deserialize into [`A3`]. Serde
/// would reject the first shape problem and report it as a parse error, so a
/// document with three wrong types would surface one of them, without a code
/// or a path.
pub fn a3_from_json(text: &str) -> Result<A3, A3Error> {
    // `?` converts `serde_json::Error` → `A3Error::Parse` automatically,
    // because `error.rs` declares `#[from] serde_json::Error` on that variant.
    let raw: Value = serde_json::from_str(text)?;
    validate(&raw).map_err(A3Error::Validate)
}

/// Serialize a validated [`A3`] to a JSON string.
///
/// `indent` controls formatting:
/// - `None`    — compact, no whitespace (good for storage / wire transfer)
/// - `Some(n)` — pretty-printed with `n` spaces per level (good for display)
///
/// Output is in canonical form: all five top-level members, all five annotation
/// families, and all four metadata members are present even when empty, and
/// author-supplied key order is preserved.
pub fn a3_to_json(a3: &A3, indent: Option<usize>) -> Result<String, A3Error> {
    match indent {
        None => serde_json::to_string(a3).map_err(A3Error::Serialize),

        // `serde_json::to_string_pretty` hard-codes 2 spaces; the lower-level
        // `Serializer` + `PrettyFormatter` API writes any width.
        Some(n) => {
            let indent_str = " ".repeat(n);
            let formatter = serde_json::ser::PrettyFormatter::with_indent(indent_str.as_bytes());
            let mut buf = Vec::new();
            let mut ser = serde_json::Serializer::with_formatter(&mut buf, formatter);
            a3.serialize(&mut ser).map_err(A3Error::Serialize)?;
            Ok(String::from_utf8(buf).expect("serde_json always produces valid UTF-8"))
        }
    }
}

/// Return the amino acid character at a 1-based `position`.
///
/// Returns `None` if `position` is 0 or beyond the sequence length.
pub fn residue_at(a3: &A3, position: u32) -> Option<char> {
    if position == 0 || position > a3.sequence().len() as u32 {
        return None;
    }
    // The sequence is validated to be ASCII-only ([A-Z*]), so each character is
    // exactly one byte and `as_bytes().get(i)` is O(1) — unlike `chars().nth(i)`,
    // which walks the string.
    a3.sequence()
        .as_bytes()
        .get((position - 1) as usize)
        .map(|&b| b as char)
}

/// Return all variant records at a 1-based `position`.
///
/// Returns references into `a3`'s data without copying anything.
pub fn variants_at(a3: &A3, position: u32) -> Vec<&VariantRecord> {
    a3.annotations()
        .variant()
        .iter()
        .filter(|v| v.position() == position)
        .collect()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    const MINIMAL_JSON: &str = r#"{
        "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
        "a3_version": "1.0.0",
        "sequence": "MAEPRQ"
    }"#;

    #[test]
    fn round_trip_is_stable() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        let json = a3_to_json(&a3, None).unwrap();
        let again = a3_from_json(&json).unwrap();
        assert_eq!(a3, again);
    }

    #[test]
    fn canonical_form_materializes_every_default() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        let v: Value = serde_json::from_str(&a3_to_json(&a3, None).unwrap()).unwrap();
        assert!(v["annotations"]["site"].is_object());
        assert!(v["annotations"]["variant"].is_array());
        assert_eq!(v["metadata"]["organism"], "");
    }

    #[test]
    fn residue_at_valid_position() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
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
    fn non_json_input_is_a_parse_error_not_a_validation_error() {
        let err = a3_from_json("not json at all").unwrap_err();
        assert!(matches!(err, A3Error::Parse(_)));
        assert!(err.issues().is_empty());
        assert_eq!(err.stage(), None);
    }

    #[test]
    fn every_shape_problem_is_collectable() {
        // Serde would have rejected this at the first wrong type. Validating the
        // raw Value reports all three, each with a code and a path.
        let json = r#"{
            "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
            "a3_version": "1.0.0",
            "sequence": 42,
            "annotations": {"site": {"s": {"index": "nope"}}},
            "metadata": {"uniprot_id": 7}
        }"#;
        let err = a3_from_json(json).unwrap_err();
        let codes: Vec<&str> = err.issues().iter().map(|i| i.code.code()).collect();
        assert_eq!(
            codes,
            vec![
                "A3E_SEQ_NOT_STRING",
                "A3E_INDEX_NOT_ARRAY",
                "A3E_METADATA_FIELD_NOT_STRING"
            ]
        );
    }

    #[test]
    fn variants_at_position() {
        let json = r#"{
            "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
            "a3_version": "1.0.0",
            "sequence": "MAEPRQ",
            "annotations": {"variant": [{"position": 5, "to": "W"}, {"position": 5, "to": "C"}]}
        }"#;
        let a3 = a3_from_json(json).unwrap();
        assert_eq!(variants_at(&a3, 5).len(), 2);
        assert_eq!(variants_at(&a3, 1).len(), 0);
    }

    #[test]
    fn pretty_print_contains_newlines() {
        let a3 = a3_from_json(MINIMAL_JSON).unwrap();
        assert!(a3_to_json(&a3, Some(2)).unwrap().contains('\n'));
    }
}
