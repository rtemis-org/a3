//! Data model for the A3 format.
//!
//! All struct fields are `pub(crate)` — visible within this crate for
//! construction and validation, but invisible to external callers. Public
//! getter methods on each type provide read-only access. This enforces the
//! invariant that every `A3` value has passed through [`crate::validate()`]
//! (defined in [`crate::validation`]).
//!
//! The hierarchy mirrors the JSON wire format exactly:
//!
//! ```text
//! A3
//!  ├── sequence:    String
//!  ├── annotations: Annotations
//!  │    ├── site:       HashMap<String, SiteEntry>
//!  │    ├── region:     HashMap<String, RegionEntry>
//!  │    ├── ptm:        HashMap<String, FlexEntry>
//!  │    ├── processing: HashMap<String, FlexEntry>
//!  │    └── variant:    Vec<VariantRecord>
//!  └── metadata:    Metadata
//! ```

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Site — positions only
// ---------------------------------------------------------------------------

/// A named annotation marking individual residue positions.
///
/// Fields are `pub(crate)` so only code within this crate can construct or
/// mutate a `SiteEntry`. External callers use the getter methods.
///
/// `#[derive(Serialize, Deserialize)]` generates JSON read/write code even for
/// `pub(crate)` fields — the derive macros run inside the crate and have full
/// field access.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SiteEntry {
    /// 1-based residue positions, sorted ascending, no duplicates.
    pub(crate) index: Vec<u32>,

    /// Optional label (e.g. `"activeSite"`). Defaults to `""` when absent.
    ///
    /// `#[serde(rename = "type")]` maps this field to the JSON key `"type"`.
    /// We cannot name the Rust field `type` because that is a reserved keyword.
    /// `#[serde(default)]` fills in `""` when the key is absent from JSON.
    #[serde(rename = "type", default)]
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
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegionEntry {
    /// Inclusive `[start, end]` range pairs, sorted by start position.
    /// Each pair satisfies `start < end`; ranges do not overlap.
    pub(crate) index: Vec<[u32; 2]>,

    #[serde(rename = "type", default)]
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

/// The index for PTM and Processing entries can be either positions or ranges,
/// but never a mix of both within a single entry.
///
/// `enum` in Rust is a *sum type* — a value is exactly one of the listed
/// variants. This is the idiomatic way to represent "either A or B".
///
/// `#[serde(untagged)]` tells serde to detect the variant by trying each one
/// in declaration order, without requiring a discriminator field in the JSON.
/// Serde tries `Ranges` first; if that fails it falls back to `Positions`.
/// This works because `Vec<[u32; 2]>` (array of 2-element arrays) and
/// `Vec<u32>` (array of integers) are structurally unambiguous in JSON.
///
/// Named `A3Index` to match the cross-language naming convention used across
/// the rtemis-a3 implementations (R, Python, TypeScript, Rust).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum A3Index {
    /// Contiguous span pairs — the inner array always has exactly two elements.
    Ranges(Vec<[u32; 2]>),
    /// Individual residue positions.
    Positions(Vec<u32>),
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
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlexEntry {
    pub(crate) index: A3Index,

    #[serde(rename = "type", default)]
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
/// The spec requires a `position` field and permits any additional
/// JSON-compatible fields, captured by `extra`.
///
/// `#[serde(flatten)]` on a `HashMap` field instructs serde to absorb
/// all JSON keys that are not explicitly named fields in this struct.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VariantRecord {
    /// Required. 1-based position of the variant on the sequence.
    pub(crate) position: u32,

    /// All other fields from the variant record, preserved as-is.
    /// `serde_json::Value` can represent any valid JSON value.
    #[serde(flatten)]
    pub(crate) extra: HashMap<String, serde_json::Value>,
}

impl VariantRecord {
    /// 1-based position of the variant on the sequence.
    pub fn position(&self) -> u32 {
        self.position
    }

    /// All extra fields from the variant record beyond `position`.
    pub fn extra(&self) -> &HashMap<String, serde_json::Value> {
        &self.extra
    }
}

// ---------------------------------------------------------------------------
// Annotations
// ---------------------------------------------------------------------------

/// Container for all five annotation families.
///
/// `#[serde(default)]`              — fills all fields with empty collections
///                                    when `annotations` is absent from JSON.
/// `#[serde(deny_unknown_fields)]`  — any key other than the five families
///                                    is a hard error.
/// `#[derive(Default)]`             — generates empty-collection defaults,
///                                    required by `#[serde(default)]`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Annotations {
    pub(crate) site: HashMap<String, SiteEntry>,
    pub(crate) region: HashMap<String, RegionEntry>,
    pub(crate) ptm: HashMap<String, FlexEntry>,
    pub(crate) processing: HashMap<String, FlexEntry>,
    pub(crate) variant: Vec<VariantRecord>,
}

impl Annotations {
    /// Named site annotations (individual residue positions).
    pub fn site(&self) -> &HashMap<String, SiteEntry> {
        &self.site
    }

    /// Named region annotations (contiguous spans).
    pub fn region(&self) -> &HashMap<String, RegionEntry> {
        &self.region
    }

    /// Named PTM annotations (positions or ranges).
    pub fn ptm(&self) -> &HashMap<String, FlexEntry> {
        &self.ptm
    }

    /// Named processing annotations (positions or ranges).
    pub fn processing(&self) -> &HashMap<String, FlexEntry> {
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
/// All four fields default to `""`. Unknown keys are rejected by
/// `deny_unknown_fields`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
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
/// Fields are `pub(crate)` — only [`crate::validate()`] (in [`crate::validation`]) may construct an `A3`,
/// guaranteeing that every value returned to external callers has passed full
/// two-stage validation. Public getter methods provide read-only access.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct A3 {
    /// JSON Schema URI — must equal [`A3_SCHEMA_URI`]. Required on input.
    #[serde(rename = "$schema")]
    pub(crate) schema: String,

    /// A3 spec version — must equal [`A3_VERSION`]. Required on input.
    pub(crate) a3_version: String,

    /// The amino acid sequence. Non-empty, ≥ 2 characters, `[A-Z*]` only.
    /// Lowercase input is normalized to uppercase during validation.
    pub(crate) sequence: String,

    /// All annotation families. Required; use an empty object `{}` if none.
    pub(crate) annotations: Annotations,

    /// Sequence metadata. Required; use an empty object `{}` if none.
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
