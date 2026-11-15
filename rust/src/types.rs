//! Data model for the A3 format.
//!
//! All struct fields are `pub(crate)` — visible within this crate for
//! construction and validation, but invisible to external callers. Public
//! getter methods on each type provide read-only access. This enforces the
//! invariant that every `A3` value has passed through [`crate::validate()`]
//! (defined in [`crate::validation`]).
//!
//! These types deliberately derive `Serialize` but **not** `Deserialize`. A
//! `Deserialize` impl would let a caller construct an `A3` straight from JSON,
//! bypassing validation, which the `pub(crate)` fields prevent. The only way in is [`crate::validate()`].
//!
//! Named maps use [`IndexMap`] rather than `HashMap` because annotation names
//! are author-supplied and their order is part of the document.
//! `HashMap` iteration order is nondeterministic, so serializing the same
//! parsed document twice would produce two different files.
//!
//! The hierarchy mirrors the JSON wire format exactly:
//!
//! ```text
//! A3
//!  ├── sequence:    String
//!  ├── annotations: Annotations
//!  │    ├── site:       IndexMap<String, SiteEntry>
//!  │    ├── region:     IndexMap<String, RegionEntry>
//!  │    ├── ptm:        IndexMap<String, FlexEntry>
//!  │    ├── processing: IndexMap<String, FlexEntry>
//!  │    └── variant:    Vec<VariantRecord>
//!  └── metadata:    Metadata
//! ```

use indexmap::IndexMap;
use serde::Serialize;

// ---------------------------------------------------------------------------
// Site — positions only
// ---------------------------------------------------------------------------

/// A named annotation marking individual residue positions.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SiteEntry {
    /// 1-based residue positions, sorted ascending, no duplicates.
    pub(crate) index: Vec<u32>,

    /// Optional label (e.g. `"activeSite"`). Empty string when absent.
    ///
    /// `#[serde(rename = "type")]` maps this field to the JSON key `"type"`.
    /// `type` is a reserved keyword in Rust, so the field is named `kind`.
    #[serde(rename = "type")]
    pub(crate) kind: String,
}

impl SiteEntry {
    /// 1-based residue positions, sorted ascending, no duplicates.
    pub fn index(&self) -> &[u32] {
        &self.index
    }

    /// Annotation type label. Empty string when unset.
    pub fn kind(&self) -> &str {
        &self.kind
    }
}

// ---------------------------------------------------------------------------
// Region — ranges only
// ---------------------------------------------------------------------------

/// A named annotation marking contiguous sequence spans.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct RegionEntry {
    /// Inclusive `[start, end]` range pairs, sorted by start position.
    /// Each pair satisfies `start < end`; ranges do not overlap.
    pub(crate) index: Vec<[u32; 2]>,

    #[serde(rename = "type")]
    pub(crate) kind: String,
}

impl RegionEntry {
    /// Inclusive `[start, end]` range pairs, sorted by start, non-overlapping.
    pub fn index(&self) -> &[[u32; 2]] {
        &self.index
    }

    /// Annotation type label. Empty string when unset.
    pub fn kind(&self) -> &str {
        &self.kind
    }
}

// ---------------------------------------------------------------------------
// A3Index — positions OR ranges (used by PTM and Processing)
// ---------------------------------------------------------------------------

/// The index for PTM and Processing entries: either positions or ranges, never
/// a mix of both within a single entry.
///
/// `enum` in Rust is a *sum type* — a value is exactly one of the listed
/// variants. This is the idiomatic way to represent "either A or B".
///
/// `#[serde(untagged)]` serializes the payload directly, with no discriminator
/// key, so a `Positions` index is written as `[1, 2]` and a `Ranges` index as
/// `[[1, 2]]` — exactly the wire format the schema declares.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(untagged)]
pub enum A3Index {
    /// Individual residue positions.
    Positions(Vec<u32>),
    /// Contiguous span pairs — the inner array always has exactly two elements.
    Ranges(Vec<[u32; 2]>),
}

impl A3Index {
    /// Returns the positions slice if this is a `Positions` variant, else `None`.
    pub fn as_positions(&self) -> Option<&[u32]> {
        match self {
            A3Index::Positions(p) => Some(p),
            A3Index::Ranges(_) => None,
        }
    }

    /// Returns the ranges slice if this is a `Ranges` variant, else `None`.
    pub fn as_ranges(&self) -> Option<&[[u32; 2]]> {
        match self {
            A3Index::Ranges(r) => Some(r),
            A3Index::Positions(_) => None,
        }
    }
}

/// A named PTM or Processing annotation with a flexible index type.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct FlexEntry {
    pub(crate) index: A3Index,

    #[serde(rename = "type")]
    pub(crate) kind: String,
}

impl FlexEntry {
    /// The index — either positions or ranges.
    pub fn index(&self) -> &A3Index {
        &self.index
    }

    /// Annotation type label. Empty string when unset.
    pub fn kind(&self) -> &str {
        &self.kind
    }
}

// ---------------------------------------------------------------------------
// Variant
// ---------------------------------------------------------------------------

/// A single sequence variant record.
///
/// The spec requires a `position` member and permits any additional
/// JSON-compatible members, captured by `extra` and preserved verbatim in
/// document order.
///
/// `#[serde(flatten)]` writes `extra`'s entries as siblings of `position`
/// rather than nesting them under an `extra` key.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct VariantRecord {
    /// Required. 1-based position of the variant on the sequence.
    pub(crate) position: u32,

    /// All other members of the variant record, preserved as-is and in order.
    #[serde(flatten)]
    pub(crate) extra: IndexMap<String, serde_json::Value>,
}

impl VariantRecord {
    /// 1-based position of the variant on the sequence.
    pub fn position(&self) -> u32 {
        self.position
    }

    /// All members of the variant record beyond `position`, in document order.
    pub fn extra(&self) -> &IndexMap<String, serde_json::Value> {
        &self.extra
    }

    /// The `from` residue, when the record carries one as a single character.
    ///
    /// Returns `None` when `from` is absent or has any other shape — A3 does
    /// not own the meaning of an open record's members beyond this one use.
    pub fn from_residue(&self) -> Option<char> {
        let s = self.extra.get("from")?.as_str()?;
        let mut chars = s.chars();
        let first = chars.next()?;
        chars.next().is_none().then_some(first)
    }
}

// ---------------------------------------------------------------------------
// Annotations
// ---------------------------------------------------------------------------

/// Container for all five annotation families.
#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct Annotations {
    pub(crate) site: IndexMap<String, SiteEntry>,
    pub(crate) region: IndexMap<String, RegionEntry>,
    pub(crate) ptm: IndexMap<String, FlexEntry>,
    pub(crate) processing: IndexMap<String, FlexEntry>,
    pub(crate) variant: Vec<VariantRecord>,
}

impl Annotations {
    /// Named site annotations (individual residue positions).
    pub fn site(&self) -> &IndexMap<String, SiteEntry> {
        &self.site
    }

    /// Named region annotations (contiguous spans).
    pub fn region(&self) -> &IndexMap<String, RegionEntry> {
        &self.region
    }

    /// Named PTM annotations (positions or ranges).
    pub fn ptm(&self) -> &IndexMap<String, FlexEntry> {
        &self.ptm
    }

    /// Named processing annotations (positions or ranges).
    pub fn processing(&self) -> &IndexMap<String, FlexEntry> {
        &self.processing
    }

    /// Ordered list of variant records.
    pub fn variant(&self) -> &[VariantRecord] {
        &self.variant
    }
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

/// Descriptive metadata attached to the sequence.
///
/// All four members are free text and default to `""`. A3 validates their type
/// and nothing else; see [`spec/README.md`](https://github.com/rtemis-org/a3/blob/main/spec/README.md#scope-of-validation),
/// "Scope of validation".
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct Metadata {
    pub(crate) uniprot_id: String,
    pub(crate) description: String,
    pub(crate) reference: String,
    pub(crate) organism: String,
}

impl Metadata {
    /// UniProt accession (e.g. `"P10636"`). Empty string when unset.
    pub fn uniprot_id(&self) -> &str {
        &self.uniprot_id
    }

    /// Human-readable protein description. Empty string when unset.
    pub fn description(&self) -> &str {
        &self.description
    }

    /// Citation or URL. Empty string when unset.
    pub fn reference(&self) -> &str {
        &self.reference
    }

    /// Species name. Empty string when unset.
    pub fn organism(&self) -> &str {
        &self.organism
    }
}

// ---------------------------------------------------------------------------
// A3 — root type
// ---------------------------------------------------------------------------

/// Expected value for the `$schema` envelope field.
pub const A3_SCHEMA_URI: &str = "https://schema.rtemis.org/a3/v1/schema.json";
/// Expected value for the `a3_version` envelope field.
pub const A3_VERSION: &str = "1.0.0";

/// The root A3 object.
///
/// Fields are `pub(crate)` — only [`crate::validate()`] may construct an `A3`,
/// guaranteeing that every value returned to external callers has passed all
/// four validation stages. Public getter methods provide read-only access.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct A3 {
    /// JSON Schema URI — always [`A3_SCHEMA_URI`].
    #[serde(rename = "$schema")]
    pub(crate) schema: String,

    /// A3 spec version — always [`A3_VERSION`].
    pub(crate) a3_version: String,

    /// The amino acid sequence, normalized to uppercase. At least 2 characters,
    /// `[A-Z*]` only.
    pub(crate) sequence: String,

    /// All annotation families. Always present in the serialized form, even
    /// when the source document omitted the key.
    pub(crate) annotations: Annotations,

    /// Sequence metadata. Always present in the serialized form, even when the
    /// source document omitted the key.
    pub(crate) metadata: Metadata,
}

impl A3 {
    /// JSON Schema URI.
    pub fn schema(&self) -> &str {
        &self.schema
    }

    /// A3 spec version string.
    pub fn a3_version(&self) -> &str {
        &self.a3_version
    }

    /// The amino acid sequence, normalized to uppercase.
    pub fn sequence(&self) -> &str {
        &self.sequence
    }

    /// All five annotation families.
    pub fn annotations(&self) -> &Annotations {
        &self.annotations
    }

    /// Sequence metadata.
    pub fn metadata(&self) -> &Metadata {
        &self.metadata
    }
}
