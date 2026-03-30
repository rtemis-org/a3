//! Data model for the A3 format.
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

// `HashMap` is Rust's standard hash map — equivalent to a Python dict or
// TypeScript Record. We need it for the named annotation families.
use std::collections::HashMap;

// `Deserialize` and `Serialize` are traits (like interfaces) from serde.
// Deriving them on a struct generates all the JSON read/write code for us.
use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Site — positions only
// ---------------------------------------------------------------------------

/// A named annotation marking individual residue positions.
///
/// In Rust, a `struct` is a named collection of typed fields — like a
/// dataclass in Python or an interface in TypeScript.
///
/// `#[derive(...)]` asks the compiler to auto-generate implementations of
/// listed traits. Here:
/// - `Debug`       — enables `println!("{:?}", entry)` for inspection
/// - `Clone`       — enables `.clone()` to make a deep copy
/// - `Serialize`   — enables `serde_json::to_string(&entry)`
/// - `Deserialize` — enables `serde_json::from_str::<SiteEntry>(json)`
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SiteEntry {
    /// 1-based residue positions, sorted ascending, no duplicates.
    /// After normalization this invariant is always upheld.
    pub index: Vec<u32>,

    /// Optional label (e.g. `"activeSite"`). Defaults to `""` when absent.
    ///
    /// `#[serde(rename = "type")]` maps this field to the JSON key `"type"`.
    /// We cannot name the Rust field `type` because that is a reserved keyword.
    ///
    /// `#[serde(default)]` means: if the key is missing from JSON, use the
    /// type's `Default` value. `String::default()` is `""`, which is correct.
    #[serde(rename = "type", default)]
    pub kind: String,
}

// ---------------------------------------------------------------------------
// Region — ranges only
// ---------------------------------------------------------------------------

/// A named annotation marking contiguous sequence spans.
///
/// `[u32; 2]` is a fixed-length array of exactly two `u32` values — a
/// compact way to represent an `[start, end]` pair without defining a
/// separate struct.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegionEntry {
    /// Inclusive `[start, end]` range pairs, sorted by start position.
    /// Each pair satisfies `start < end`; ranges do not overlap.
    pub index: Vec<[u32; 2]>,

    /// Optional label. Defaults to `""` when absent from JSON.
    #[serde(rename = "type", default)]
    pub kind: String,
}

// ---------------------------------------------------------------------------
// FlexIndex — positions OR ranges (used by PTM and Processing)
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
/// Named `A3Index` to match the cross-language schema convention used across
/// the rtemis-a3 implementations (R, Python, TypeScript, Rust).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum A3Index {
    /// Contiguous span pairs — the inner array always has exactly two elements.
    Ranges(Vec<[u32; 2]>),
    /// Individual residue positions.
    Positions(Vec<u32>),
}

/// A named PTM or Processing annotation with a flexible index type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlexEntry {
    pub index: A3Index,

    #[serde(rename = "type", default)]
    pub kind: String,
}

// ---------------------------------------------------------------------------
// Variant
// ---------------------------------------------------------------------------

/// A single sequence variant record.
///
/// The spec requires a `position` field and permits any additional
/// JSON-compatible fields. We capture the extras with a `HashMap`.
///
/// `#[serde(flatten)]` on a `HashMap` field instructs serde to absorb
/// all JSON keys that are not explicitly named fields in this struct.
/// So given `{ "position": 301, "from": "P", "to": "L" }`, serde puts
/// `301` into `position` and `{"from": "P", "to": "L"}` into `extra`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VariantRecord {
    /// Required. 1-based position of the variant on the sequence.
    pub position: u32,

    /// All other fields from the variant record, preserved as-is.
    /// `serde_json::Value` is an enum that can represent any JSON value
    /// (null, bool, number, string, array, or object).
    #[serde(flatten)]
    pub extra: HashMap<String, serde_json::Value>,
}

// ---------------------------------------------------------------------------
// Annotations
// ---------------------------------------------------------------------------

/// Container for all five annotation families.
///
/// `#[serde(default)]`        — if `annotations` is omitted from the top-level
///                              JSON, the struct is filled with empty defaults.
/// `#[serde(deny_unknown_fields)]` — any key other than the five families
///                              (e.g. `"motif"`) is a hard error, matching the
///                              spec requirement to reject unknown families.
///
/// `#[derive(Default)]` generates a `Default` implementation that sets each
/// `HashMap` to empty and `Vec` to empty — required by `#[serde(default)]`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Annotations {
    pub site: HashMap<String, SiteEntry>,
    pub region: HashMap<String, RegionEntry>,
    pub ptm: HashMap<String, FlexEntry>,
    pub processing: HashMap<String, FlexEntry>,
    pub variant: Vec<VariantRecord>,
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

/// Descriptive metadata attached to the sequence.
///
/// All four fields are optional in JSON (default `""`). Unknown keys are
/// rejected by `deny_unknown_fields`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Metadata {
    pub uniprot_id: String,
    pub description: String,
    pub reference: String,
    pub organism: String,
}

// ---------------------------------------------------------------------------
// A3 — root type
// ---------------------------------------------------------------------------

/// The root A3 object.
///
/// This is the type users interact with directly. `deny_unknown_fields`
/// ensures that stray top-level keys (anything besides `sequence`,
/// `annotations`, and `metadata`) are rejected during deserialization.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct A3 {
    /// The amino acid sequence. Non-empty, ≥ 2 characters, `[A-Z*]` only.
    /// Lowercase input is normalized to uppercase during validation.
    pub sequence: String,

    /// All annotation families. Defaults to all-empty if omitted from JSON.
    #[serde(default)]
    pub annotations: Annotations,

    /// Sequence metadata. Defaults to all-empty strings if omitted from JSON.
    #[serde(default)]
    pub metadata: Metadata,
}
