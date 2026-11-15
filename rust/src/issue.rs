//! Validation issues: stable codes, RFC 6901 paths, and human messages.
//!
//! The contract is defined in [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) and
//! [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md), and is shared by all five A3 implementations. The
//! `code` and `path` of every issue are contractual; the `message` is not and
//! may be reworded freely.

use std::fmt;

use serde::Serialize;

// ---------------------------------------------------------------------------
// Codes
// ---------------------------------------------------------------------------

/// Declare every issue code once, deriving the enum, its wire string, its
/// validation stage, and the full list from a single table.
///
/// A `macro_rules!` macro is Rust's pattern-based code generator. Writing the
/// table once means a new code cannot be added to the enum without also giving
/// it a stage and a wire string — the three can never drift apart.
macro_rules! issue_codes {
    ($( $variant:ident => $wire:literal, $stage:literal );* $(;)?) => {
        /// A stable, machine-readable validation issue code.
        ///
        /// Codes are never renumbered and never reused. See
        /// [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) for the full registry.
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
        pub enum A3IssueCode {
            $(
                #[doc = $wire]
                $variant,
            )*
        }

        impl A3IssueCode {
            /// The code's stable wire string, e.g. `"A3E_SEQ_TOO_SHORT"`.
            pub fn code(self) -> &'static str {
                match self {
                    $( A3IssueCode::$variant => $wire, )*
                }
            }

            /// The validation stage this code belongs to (1–4).
            pub fn stage(self) -> u8 {
                match self {
                    $( A3IssueCode::$variant => $stage, )*
                }
            }

            /// Every code in the registry, for coverage checks.
            pub const ALL: &'static [A3IssueCode] = &[ $( A3IssueCode::$variant, )* ];
        }
    };
}

issue_codes! {
    // Stage 1 — Envelope
    DocNotObject               => "A3E_DOC_NOT_OBJECT",                1;
    EnvelopeSchemaMissing      => "A3E_ENVELOPE_SCHEMA_MISSING",       1;
    EnvelopeSchemaMismatch     => "A3E_ENVELOPE_SCHEMA_MISMATCH",      1;
    EnvelopeVersionMissing     => "A3E_ENVELOPE_VERSION_MISSING",      1;
    EnvelopeVersionMismatch    => "A3E_ENVELOPE_VERSION_MISMATCH",     1;

    // Stage 2 — Structural
    UnknownField               => "A3E_UNKNOWN_FIELD",                 2;
    SeqMissing                 => "A3E_SEQ_MISSING",                   2;
    SeqNotString               => "A3E_SEQ_NOT_STRING",                2;
    SeqTooShort                => "A3E_SEQ_TOO_SHORT",                 2;
    SeqCharset                 => "A3E_SEQ_CHARSET",                   2;
    AnnotationsNotObject       => "A3E_ANNOTATIONS_NOT_OBJECT",        2;
    MetadataNotObject          => "A3E_METADATA_NOT_OBJECT",           2;
    MetadataFieldNotString     => "A3E_METADATA_FIELD_NOT_STRING",     2;
    FamilyNotObject            => "A3E_FAMILY_NOT_OBJECT",             2;
    VariantListNotArray        => "A3E_VARIANT_LIST_NOT_ARRAY",        2;
    NameEmpty                  => "A3E_NAME_EMPTY",                    2;
    EntryNotObject             => "A3E_ENTRY_NOT_OBJECT",              2;
    EntryTypeNotString         => "A3E_ENTRY_TYPE_NOT_STRING",         2;
    IndexMissing               => "A3E_INDEX_MISSING",                 2;
    IndexNotArray              => "A3E_INDEX_NOT_ARRAY",               2;
    IndexElementType           => "A3E_INDEX_ELEMENT_TYPE",            2;
    IndexMixed                 => "A3E_INDEX_MIXED",                   2;
    RangeArity                 => "A3E_RANGE_ARITY",                   2;
    RangeEndpointNotInteger    => "A3E_RANGE_ENDPOINT_NOT_INTEGER",    2;
    VariantNotObject           => "A3E_VARIANT_NOT_OBJECT",            2;
    VariantPositionMissing     => "A3E_VARIANT_POSITION_MISSING",      2;
    VariantPositionNotInteger  => "A3E_VARIANT_POSITION_NOT_INTEGER",  2;

    // Stage 3 — Intra-field
    PosNotPositive             => "A3E_POS_NOT_POSITIVE",              3;
    PosDuplicate               => "A3E_POS_DUPLICATE",                 3;
    RangeEndpointNotPositive   => "A3E_RANGE_ENDPOINT_NOT_POSITIVE",   3;
    RangeOrder                 => "A3E_RANGE_ORDER",                   3;
    RangeOverlap               => "A3E_RANGE_OVERLAP",                 3;
    VariantPositionNotPositive => "A3E_VARIANT_POSITION_NOT_POSITIVE", 3;

    // Stage 4 — Contextual
    PosOutOfBounds             => "A3E_POS_OUT_OF_BOUNDS",             4;
    RangeOutOfBounds           => "A3E_RANGE_OUT_OF_BOUNDS",           4;
    VariantOutOfBounds         => "A3E_VARIANT_OUT_OF_BOUNDS",         4;
    VariantResidueMismatch     => "A3E_VARIANT_RESIDUE_MISMATCH",      4;
}

impl fmt::Display for A3IssueCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.code())
    }
}

impl Serialize for A3IssueCode {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(self.code())
    }
}

// ---------------------------------------------------------------------------
// Issues
// ---------------------------------------------------------------------------

/// A single validation issue.
///
/// `code` and `path` are contractual and identical across all five A3
/// implementations. `message` is for humans and may differ between them.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct A3Issue {
    /// Stable machine-readable code.
    pub code: A3IssueCode,
    /// RFC 6901 JSON Pointer to the offending value.
    pub path: String,
    /// Human-readable explanation. Not contractual.
    pub message: String,
}

impl A3Issue {
    /// Build an issue. `path` is taken as an already-escaped JSON Pointer.
    pub fn new(code: A3IssueCode, path: impl Into<String>, message: impl Into<String>) -> Self {
        A3Issue {
            code,
            path: path.into(),
            message: message.into(),
        }
    }

    /// The validation stage this issue belongs to (1–4).
    pub fn stage(&self) -> u8 {
        self.code.stage()
    }
}

impl fmt::Display for A3Issue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // The empty pointer denotes the whole document; naming it "/" would be
        // wrong (that is the member named ""), so spell it out instead.
        let where_ = if self.path.is_empty() {
            "<document>"
        } else {
            &self.path
        };
        write!(f, "[{}] {}: {}", self.code.code(), where_, self.message)
    }
}

// ---------------------------------------------------------------------------
// JSON Pointer construction
// ---------------------------------------------------------------------------

/// Escape one reference token for inclusion in a JSON Pointer.
///
/// RFC 6901 escapes exactly two characters. `~` must be replaced before `/`,
/// or a key containing `/` would come out as `~01` instead of `~1`.
pub fn escape_token(token: &str) -> String {
    token.replace('~', "~0").replace('/', "~1")
}

/// Append one reference token to a JSON Pointer, escaping it.
///
/// `pointer("/annotations/site", "a/b")` → `"/annotations/site/a~1b"`.
pub fn pointer(base: &str, token: &str) -> String {
    format!("{base}/{}", escape_token(token))
}

/// Append a 0-based array subscript to a JSON Pointer.
///
/// Subscripts are decimal and need no escaping.
pub fn pointer_index(base: &str, index: usize) -> String {
    format!("{base}/{index}")
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codes_are_unique() {
        let mut seen = std::collections::HashSet::new();
        for c in A3IssueCode::ALL {
            assert!(seen.insert(c.code()), "duplicate code: {}", c.code());
        }
        assert_eq!(
            seen.len(),
            37,
            "registry size changed — update spec/error-codes.md"
        );
    }

    #[test]
    fn every_code_has_a_valid_stage() {
        for c in A3IssueCode::ALL {
            assert!(
                (1..=4).contains(&c.stage()),
                "{} has stage {}",
                c.code(),
                c.stage()
            );
        }
    }

    #[test]
    fn escapes_tilde_before_slash() {
        // "~1" must survive as "~01", not be re-read as an escaped slash.
        assert_eq!(escape_token("a~1b"), "a~01b");
        assert_eq!(escape_token("a/b"), "a~1b");
        assert_eq!(escape_token("a~b"), "a~0b");
        assert_eq!(escape_token("a.b"), "a.b");
        assert_eq!(escape_token("$schema"), "$schema");
    }

    #[test]
    fn builds_pointers() {
        assert_eq!(
            pointer("/annotations/site", "a/b"),
            "/annotations/site/a~1b"
        );
        assert_eq!(pointer("", "$schema"), "/$schema");
        // A name that is the empty string yields a trailing empty token.
        assert_eq!(pointer("/annotations/site", ""), "/annotations/site/");
        assert_eq!(
            pointer_index("/annotations/variant", 3),
            "/annotations/variant/3"
        );
    }
}
