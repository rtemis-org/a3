//! Four-stage A3 validation over the raw parsed JSON.
//!
//! Validation runs against `serde_json::Value`, not against a deserialized
//! [`A3`]. That is the whole point: serde's `Deserialize` fails on the *first*
//! shape problem and reports it as a parse error, so a document with three
//! wrong types would surface one of them. Validating the raw value lets every
//! shape problem become a collectable issue with a code and a path.
//!
//! **Within a stage, collect everything. Across stages, short-circuit.**
//!
//! ```text
//! JSON text
//!    │
//!    ├─ parse ─────────────► A3Error::Parse (single, fatal, not collectable)
//!    ▼
//! serde_json::Value
//!    ├─ STAGE 1  envelope     document is an object, declares itself A3 1.0.0
//!    ├─ STAGE 2  structural   types, shapes, required members, charset, names
//!    ├─ STAGE 3  intra-field  positions ≥1/deduped, ranges ordered/disjoint
//!    ├─ STAGE 4  contextual   bounds vs sequence length, variant `from` residue
//!    ▼  (only if no stage produced an issue)
//! A3
//! ```
//!
//! Short-circuiting is a correctness requirement, not an optimization. A
//! document whose `sequence` fails Stage 2 has no known length, so Stage 4
//! would emit one spurious out-of-bounds issue per annotated position.
//!
//! The full contract lives in [`spec/error-codes.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) and
//! [`spec/error-paths.md`](https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md).

use indexmap::IndexMap;
use serde_json::{Map, Value};

use crate::issue::{A3Issue, A3IssueCode as C, pointer, pointer_index};
use crate::normalization::{normalize_sequence, sort_positions, sort_ranges};
use crate::types::{
    A3, A3_SCHEMA_URI, A3_VERSION, A3Index, Annotations, FlexEntry, Metadata, RegionEntry,
    SiteEntry, VariantRecord,
};

const TOP_LEVEL_KEYS: &[&str] = &[
    "$schema",
    "a3_version",
    "sequence",
    "annotations",
    "metadata",
];
const FAMILIES: &[&str] = &["site", "region", "ptm", "processing", "variant"];
const NAMED_FAMILIES: &[&str] = &["site", "region", "ptm", "processing"];
const ENTRY_KEYS: &[&str] = &["index", "type"];
const METADATA_KEYS: &[&str] = &["uniprot_id", "description", "reference", "organism"];

/// Validate a raw parsed JSON value as an A3 document.
///
/// Returns the normalized [`A3`] on success, or every issue found in the
/// earliest stage that produced one.
pub fn validate(root: &Value) -> Result<A3, Vec<A3Issue>> {
    let mut issues: Vec<A3Issue> = Vec::new();

    // ── Stage 1 ──────────────────────────────────────────────────────────
    let Some(obj) = stage1_envelope(root, &mut issues) else {
        return Err(issues);
    };
    if !issues.is_empty() {
        return Err(issues);
    }

    // ── Stage 2 ──────────────────────────────────────────────────────────
    let draft = stage2_structural(obj, &mut issues);
    if !issues.is_empty() {
        return Err(issues);
    }
    // Stage 2 produced no issues, so every optional field it needed is present.
    let mut draft = draft.expect("stage 2 reported no issues, so the draft is complete");

    // ── Stage 3 ──────────────────────────────────────────────────────────
    stage3_intra_field(&mut draft, &mut issues);
    if !issues.is_empty() {
        return Err(issues);
    }

    // ── Stage 4 ──────────────────────────────────────────────────────────
    stage4_contextual(&draft, &mut issues);
    if !issues.is_empty() {
        return Err(issues);
    }

    Ok(build(draft))
}

// ===========================================================================
// Draft — the raw document after Stage 2, before it is known to be an A3
// ===========================================================================

/// An index whose geometry is settled but whose values are not yet checked.
///
/// Values are `i64`, not `u32`, so that a negative position survives Stage 2
/// intact and can be reported by Stage 3 as `A3E_POS_NOT_POSITIVE` rather than
/// silently failing to convert.
enum DraftIndex {
    Positions(Vec<i64>),
    Ranges(Vec<[i64; 2]>),
}

struct DraftEntry {
    /// JSON Pointer to this entry's `index`.
    index_path: String,
    index: DraftIndex,
    kind: String,
}

struct DraftVariant {
    /// JSON Pointer to this variant record.
    path: String,
    position: i64,
    extra: IndexMap<String, Value>,
}

struct Draft {
    sequence: String,
    site: IndexMap<String, DraftEntry>,
    region: IndexMap<String, DraftEntry>,
    ptm: IndexMap<String, DraftEntry>,
    processing: IndexMap<String, DraftEntry>,
    variant: Vec<DraftVariant>,
    metadata: Metadata,
}

impl Draft {
    /// Every named entry across the four named families, for the stages that
    /// treat them uniformly.
    fn entries(&self) -> impl Iterator<Item = &DraftEntry> {
        self.site
            .values()
            .chain(self.region.values())
            .chain(self.ptm.values())
            .chain(self.processing.values())
    }

    fn entries_mut(&mut self) -> impl Iterator<Item = &mut DraftEntry> {
        self.site
            .values_mut()
            .chain(self.region.values_mut())
            .chain(self.ptm.values_mut())
            .chain(self.processing.values_mut())
    }
}

// ===========================================================================
// Stage 1 — Envelope
// ===========================================================================

/// Check that the document is an object declaring itself to be A3 1.0.0.
///
/// Returns `None` when the root is not an object: nothing below it can be
/// located, so `A3E_DOC_NOT_OBJECT` is the only issue reported.
fn stage1_envelope<'a>(
    root: &'a Value,
    issues: &mut Vec<A3Issue>,
) -> Option<&'a Map<String, Value>> {
    let Some(obj) = root.as_object() else {
        issues.push(A3Issue::new(
            C::DocNotObject,
            "",
            "an A3 document must be a JSON object",
        ));
        return None;
    };

    check_const(
        obj,
        "$schema",
        A3_SCHEMA_URI,
        C::EnvelopeSchemaMissing,
        C::EnvelopeSchemaMismatch,
        issues,
    );
    check_const(
        obj,
        "a3_version",
        A3_VERSION,
        C::EnvelopeVersionMissing,
        C::EnvelopeVersionMismatch,
        issues,
    );

    Some(obj)
}

/// Check one envelope member against its required constant value.
///
/// A wrong type and a wrong value are the same failure: the schema declares
/// both members with `const`, and a `const` failure is one failure.
fn check_const(
    obj: &Map<String, Value>,
    key: &str,
    expected: &str,
    missing: crate::issue::A3IssueCode,
    mismatch: crate::issue::A3IssueCode,
    issues: &mut Vec<A3Issue>,
) {
    let path = pointer("", key);
    match obj.get(key) {
        None => issues.push(A3Issue::new(
            missing,
            path,
            format!("'{key}' is required and must be '{expected}'"),
        )),
        Some(v) if v.as_str() != Some(expected) => issues.push(A3Issue::new(
            mismatch,
            path,
            format!("'{key}' must be '{expected}', got {}", render(v)),
        )),
        Some(_) => {}
    }
}

// ===========================================================================
// Stage 2 — Structural
// ===========================================================================

/// Check that every value has the type and shape the schema declares, and
/// extract a [`Draft`] for the later stages.
///
/// Returns `None` if anything was reported — the caller checks `issues`, so the
/// `None` here only saves the later stages from a half-built draft.
fn stage2_structural(obj: &Map<String, Value>, issues: &mut Vec<A3Issue>) -> Option<Draft> {
    unknown_fields(obj, TOP_LEVEL_KEYS, "", issues);

    let sequence = stage2_sequence(obj, issues);

    let mut draft = Draft {
        sequence: sequence.unwrap_or_default(),
        site: IndexMap::new(),
        region: IndexMap::new(),
        ptm: IndexMap::new(),
        processing: IndexMap::new(),
        variant: Vec::new(),
        metadata: Metadata::default(),
    };

    // `annotations` and `metadata` are optional; both default to empty.
    match obj.get("annotations") {
        None | Some(Value::Null) => {}
        Some(v) => match v.as_object() {
            None => issues.push(A3Issue::new(
                C::AnnotationsNotObject,
                "/annotations",
                format!("'annotations' must be an object, got {}", render(v)),
            )),
            Some(ann) => stage2_annotations(ann, &mut draft, issues),
        },
    }

    match obj.get("metadata") {
        None | Some(Value::Null) => {}
        Some(v) => match v.as_object() {
            None => issues.push(A3Issue::new(
                C::MetadataNotObject,
                "/metadata",
                format!("'metadata' must be an object, got {}", render(v)),
            )),
            Some(meta) => draft.metadata = stage2_metadata(meta, issues),
        },
    }

    issues.is_empty().then_some(draft)
}

fn stage2_sequence(obj: &Map<String, Value>, issues: &mut Vec<A3Issue>) -> Option<String> {
    let Some(v) = obj.get("sequence") else {
        issues.push(A3Issue::new(
            C::SeqMissing,
            "/sequence",
            "'sequence' is required",
        ));
        return None;
    };
    let Some(raw) = v.as_str() else {
        issues.push(A3Issue::new(
            C::SeqNotString,
            "/sequence",
            format!("'sequence' must be a string, got {}", render(v)),
        ));
        return None;
    };

    let upper = normalize_sequence(raw);
    if upper.chars().count() < 2 {
        issues.push(A3Issue::new(
            C::SeqTooShort,
            "/sequence",
            format!(
                "'sequence' must be at least 2 characters, got {} (\"{raw}\")",
                upper.chars().count()
            ),
        ));
    }
    if let Some(bad) = upper.chars().find(|c| !matches!(c, 'A'..='Z' | '*')) {
        issues.push(A3Issue::new(
            C::SeqCharset,
            "/sequence",
            format!(
                "'sequence' contains {bad:?}; only A-Z (IUPAC amino acid codes) \
                 and '*' (stop codon) are permitted"
            ),
        ));
    }
    Some(upper)
}

fn stage2_annotations(ann: &Map<String, Value>, draft: &mut Draft, issues: &mut Vec<A3Issue>) {
    unknown_fields(ann, FAMILIES, "/annotations", issues);

    for &family in NAMED_FAMILIES {
        let family_path = pointer("/annotations", family);
        let Some(v) = ann.get(family) else { continue };
        if v.is_null() {
            continue;
        }
        let Some(entries) = v.as_object() else {
            issues.push(A3Issue::new(
                C::FamilyNotObject,
                family_path,
                format!(
                    "'annotations.{family}' must be an object, got {}",
                    render(v)
                ),
            ));
            continue;
        };
        let parsed = stage2_family(entries, family, &family_path, issues);
        match family {
            "site" => draft.site = parsed,
            "region" => draft.region = parsed,
            "ptm" => draft.ptm = parsed,
            _ => draft.processing = parsed,
        }
    }

    if let Some(v) = ann.get("variant")
        && !v.is_null()
    {
        match v.as_array() {
            None => issues.push(A3Issue::new(
                C::VariantListNotArray,
                "/annotations/variant",
                format!("'annotations.variant' must be an array, got {}", render(v)),
            )),
            Some(records) => draft.variant = stage2_variants(records, issues),
        }
    }
}

/// Parse one named annotation family.
///
/// `family` selects which index geometry is permitted: `site` takes positions,
/// `region` takes ranges, and `ptm` / `processing` take either, homogeneously.
fn stage2_family(
    entries: &Map<String, Value>,
    family: &str,
    family_path: &str,
    issues: &mut Vec<A3Issue>,
) -> IndexMap<String, DraftEntry> {
    let mut out = IndexMap::new();

    for (name, raw) in entries {
        let entry_path = pointer(family_path, name);

        if name.is_empty() {
            issues.push(A3Issue::new(
                C::NameEmpty,
                entry_path,
                format!(
                    "'annotations.{family}' has an annotation named \"\"; names must not be empty"
                ),
            ));
            continue;
        }

        let Some(entry) = raw.as_object() else {
            issues.push(A3Issue::new(
                C::EntryNotObject,
                entry_path,
                format!(
                    "annotation '{name}' must be an object with an 'index' member, got {}",
                    render(raw)
                ),
            ));
            continue;
        };

        unknown_fields(entry, ENTRY_KEYS, &entry_path, issues);

        let type_path = pointer(&entry_path, "type");
        let kind = match entry.get("type") {
            None | Some(Value::Null) => String::new(),
            Some(v) => match v.as_str() {
                Some(s) => s.to_string(),
                None => {
                    issues.push(A3Issue::new(
                        C::EntryTypeNotString,
                        type_path,
                        format!("'type' must be a string, got {}", render(v)),
                    ));
                    String::new()
                }
            },
        };

        let index_path = pointer(&entry_path, "index");
        let Some(index_value) = entry.get("index") else {
            issues.push(A3Issue::new(
                C::IndexMissing,
                index_path,
                format!("annotation '{name}' is missing its required 'index' member"),
            ));
            continue;
        };
        let Some(elements) = index_value.as_array() else {
            issues.push(A3Issue::new(
                C::IndexNotArray,
                index_path,
                format!("'index' must be an array, got {}", render(index_value)),
            ));
            continue;
        };

        let Some(index) = parse_index(elements, family, &index_path, issues) else {
            continue;
        };

        out.insert(
            name.clone(),
            DraftEntry {
                index_path,
                index,
                kind,
            },
        );
    }

    out
}

/// Settle an index's geometry and extract its values.
///
/// Returns `None` when the index could not be interpreted; issues have already
/// been recorded in that case.
fn parse_index(
    elements: &[Value],
    family: &str,
    index_path: &str,
    issues: &mut Vec<A3Issue>,
) -> Option<DraftIndex> {
    let flexible = family == "ptm" || family == "processing";

    // Classify every element first. Doing this up front is what makes the
    // mixed-geometry rule expressible: it is a property of the whole index.
    let mut n_int = 0usize;
    let mut n_arr = 0usize;
    let mut bad = false;
    for (i, v) in elements.iter().enumerate() {
        match classify(v) {
            Elem::Integer(_) => n_int += 1,
            Elem::Array => n_arr += 1,
            Elem::Other => {
                bad = true;
                issues.push(A3Issue::new(
                    C::IndexElementType,
                    pointer_index(index_path, i),
                    format!(
                        "index element must be {}, got {}",
                        expected_shape(family),
                        render(v)
                    ),
                ));
            }
        }
    }
    if bad {
        return None;
    }

    // For ptm / processing, a homogeneity failure is its own rule. For site and
    // region the schema fixes the geometry, so `classify` has already reported a
    // wrong element above, except a correctly shaped element of the *other*
    // geometry, which this check catches.
    let geometry = if flexible {
        if n_int > 0 && n_arr > 0 {
            issues.push(A3Issue::new(
                C::IndexMixed,
                index_path.to_string(),
                format!(
                    "index mixes {n_int} position(s) and {n_arr} range(s); \
                     a ptm or processing index must be all positions or all ranges"
                ),
            ));
            return None;
        }
        if n_arr > 0 {
            Geometry::Ranges
        } else {
            Geometry::Positions
        }
    } else if family == "region" {
        Geometry::Ranges
    } else {
        Geometry::Positions
    };

    // Report elements that are well-formed but of the wrong geometry for a
    // family whose geometry is fixed by the schema.
    if !flexible {
        let mut wrong = false;
        for (i, v) in elements.iter().enumerate() {
            let ok = match geometry {
                Geometry::Positions => matches!(classify(v), Elem::Integer(_)),
                Geometry::Ranges => matches!(classify(v), Elem::Array),
            };
            if !ok {
                wrong = true;
                issues.push(A3Issue::new(
                    C::IndexElementType,
                    pointer_index(index_path, i),
                    format!(
                        "index element must be {}, got {}",
                        expected_shape(family),
                        render(v)
                    ),
                ));
            }
        }
        if wrong {
            return None;
        }
    }

    match geometry {
        Geometry::Positions => {
            let positions = elements
                .iter()
                .map(|v| match classify(v) {
                    Elem::Integer(n) => n,
                    _ => unreachable!("geometry settled as positions"),
                })
                .collect();
            Some(DraftIndex::Positions(positions))
        }
        Geometry::Ranges => {
            let mut ranges = Vec::with_capacity(elements.len());
            let mut ok = true;
            for (i, v) in elements.iter().enumerate() {
                let pair = v.as_array().expect("geometry settled as ranges");
                let elem_path = pointer_index(index_path, i);
                if pair.len() != 2 {
                    issues.push(A3Issue::new(
                        C::RangeArity,
                        elem_path,
                        format!(
                            "a range must be a 2-element [start, end] array, got {} element(s)",
                            pair.len()
                        ),
                    ));
                    ok = false;
                    continue;
                }
                match (classify(&pair[0]), classify(&pair[1])) {
                    (Elem::Integer(s), Elem::Integer(e)) => ranges.push([s, e]),
                    _ => {
                        issues.push(A3Issue::new(
                            C::RangeEndpointNotInteger,
                            elem_path,
                            format!(
                                "range endpoints must be integers, got [{}, {}]",
                                render(&pair[0]),
                                render(&pair[1])
                            ),
                        ));
                        ok = false;
                    }
                }
            }
            ok.then_some(DraftIndex::Ranges(ranges))
        }
    }
}

fn stage2_variants(records: &[Value], issues: &mut Vec<A3Issue>) -> Vec<DraftVariant> {
    let mut out = Vec::with_capacity(records.len());

    for (i, raw) in records.iter().enumerate() {
        let path = pointer_index("/annotations/variant", i);

        let Some(record) = raw.as_object() else {
            issues.push(A3Issue::new(
                C::VariantNotObject,
                path,
                format!("a variant record must be an object, got {}", render(raw)),
            ));
            continue;
        };

        let position_path = pointer(&path, "position");
        let Some(position_value) = record.get("position") else {
            issues.push(A3Issue::new(
                C::VariantPositionMissing,
                position_path,
                "a variant record is missing its required 'position' member",
            ));
            continue;
        };
        let Elem::Integer(position) = classify(position_value) else {
            issues.push(A3Issue::new(
                C::VariantPositionNotInteger,
                position_path,
                format!(
                    "'position' must be an integer, got {}",
                    render(position_value)
                ),
            ));
            continue;
        };

        // A variant record is open: every other member is preserved verbatim,
        // in document order, and is not type-checked.
        let extra = record
            .iter()
            .filter(|(k, _)| k.as_str() != "position")
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect();

        out.push(DraftVariant {
            path,
            position,
            extra,
        });
    }

    out
}

fn stage2_metadata(meta: &Map<String, Value>, issues: &mut Vec<A3Issue>) -> Metadata {
    unknown_fields(meta, METADATA_KEYS, "/metadata", issues);

    let mut get = |key: &str| -> String {
        match meta.get(key) {
            None | Some(Value::Null) => String::new(),
            Some(v) => match v.as_str() {
                Some(s) => s.to_string(),
                None => {
                    issues.push(A3Issue::new(
                        C::MetadataFieldNotString,
                        pointer("/metadata", key),
                        format!("'metadata.{key}' must be a string, got {}", render(v)),
                    ));
                    String::new()
                }
            },
        }
    };

    Metadata {
        uniprot_id: get("uniprot_id"),
        description: get("description"),
        reference: get("reference"),
        organism: get("organism"),
    }
}

// ===========================================================================
// Stage 3 — Intra-field
// ===========================================================================

/// Sort every index, then check that each is internally consistent.
///
/// Sorting happens here rather than in Stage 2 because an index cannot be
/// sorted until its elements are known to be sortable, and it must be sorted
/// before duplication and overlap can be checked. Every subscript reported by
/// this stage and by Stage 4 therefore names the *sorted* array.
fn stage3_intra_field(draft: &mut Draft, issues: &mut Vec<A3Issue>) {
    for entry in draft.entries_mut() {
        match std::mem::replace(&mut entry.index, DraftIndex::Positions(Vec::new())) {
            DraftIndex::Positions(p) => entry.index = DraftIndex::Positions(sort_positions(p)),
            DraftIndex::Ranges(r) => entry.index = DraftIndex::Ranges(sort_ranges(r)),
        }
    }

    for entry in draft.entries() {
        match &entry.index {
            DraftIndex::Positions(positions) => {
                for (i, &p) in positions.iter().enumerate() {
                    if p < 1 {
                        issues.push(A3Issue::new(
                            C::PosNotPositive,
                            pointer_index(&entry.index_path, i),
                            format!("position {p} must be >= 1; positions are 1-based"),
                        ));
                    }
                }
                // One issue per distinct repeated value, not per excess
                // occurrence: `[7, 7, 7]` is one mistake, not two.
                let mut prev: Option<i64> = None;
                for w in positions.windows(2) {
                    if w[0] == w[1] && prev != Some(w[0]) {
                        prev = Some(w[0]);
                        issues.push(A3Issue::new(
                            C::PosDuplicate,
                            entry.index_path.clone(),
                            format!(
                                "position {} appears more than once; duplicates are rejected, \
                                 not merged",
                                w[0]
                            ),
                        ));
                    }
                }
            }
            DraftIndex::Ranges(ranges) => {
                for (i, &[s, e]) in ranges.iter().enumerate() {
                    let elem_path = pointer_index(&entry.index_path, i);
                    if s < 1 || e < 1 {
                        issues.push(A3Issue::new(
                            C::RangeEndpointNotPositive,
                            elem_path.clone(),
                            format!(
                                "range [{s}, {e}] has an endpoint below 1; positions are 1-based"
                            ),
                        ));
                    }
                    if s >= e {
                        issues.push(A3Issue::new(
                            C::RangeOrder,
                            elem_path,
                            format!(
                                "range [{s}, {e}] must satisfy start < end; a single residue \
                                 belongs in a position-indexed family"
                            ),
                        ));
                    }
                }
                for w in ranges.windows(2) {
                    // Sorted by start, so `w[1][0] >= w[0][0]`; they overlap
                    // exactly when the second starts at or before the first ends.
                    if w[1][0] <= w[0][1] {
                        issues.push(A3Issue::new(
                            C::RangeOverlap,
                            entry.index_path.clone(),
                            format!(
                                "ranges [{}, {}] and [{}, {}] overlap; adjacent ranges are \
                                 permitted but overlapping ones are not",
                                w[0][0], w[0][1], w[1][0], w[1][1]
                            ),
                        ));
                    }
                }
            }
        }
    }

    for v in &draft.variant {
        if v.position < 1 {
            issues.push(A3Issue::new(
                C::VariantPositionNotPositive,
                pointer(&v.path, "position"),
                format!(
                    "position {} must be >= 1; positions are 1-based",
                    v.position
                ),
            ));
        }
    }
}

// ===========================================================================
// Stage 4 — Contextual
// ===========================================================================

/// Check every value against the sequence, whose length is known only because
/// Stages 1–3 all passed.
fn stage4_contextual(draft: &Draft, issues: &mut Vec<A3Issue>) {
    let residues: Vec<char> = draft.sequence.chars().collect();
    let n = residues.len() as i64;

    for entry in draft.entries() {
        match &entry.index {
            DraftIndex::Positions(positions) => {
                for (i, &p) in positions.iter().enumerate() {
                    if p > n {
                        issues.push(A3Issue::new(
                            C::PosOutOfBounds,
                            pointer_index(&entry.index_path, i),
                            format!(
                                "position {p} is out of bounds for a sequence of length {n} \
                                 (must be 1-{n})"
                            ),
                        ));
                    }
                }
            }
            DraftIndex::Ranges(ranges) => {
                // Stage 3 established start < end, so only `end` can exceed `n`.
                for (i, &[s, e]) in ranges.iter().enumerate() {
                    if e > n {
                        issues.push(A3Issue::new(
                            C::RangeOutOfBounds,
                            pointer_index(&entry.index_path, i),
                            format!(
                                "range [{s}, {e}] is out of bounds for a sequence of length {n} \
                                 (must be within 1-{n})"
                            ),
                        ));
                    }
                }
            }
        }
    }

    for v in &draft.variant {
        if v.position > n {
            issues.push(A3Issue::new(
                C::VariantOutOfBounds,
                pointer(&v.path, "position"),
                format!(
                    "position {} is out of bounds for a sequence of length {n} (must be 1-{n})",
                    v.position
                ),
            ));
            continue;
        }
        // The residue rule is deliberately narrow: it fires only when `from` is
        // present *and* is a single character. `from` is an optional member of
        // an open record, so any other shape is not this rule's problem.
        let Some(from) = single_char(v.extra.get("from")) else {
            continue;
        };
        let actual = residues[(v.position - 1) as usize];
        // Case-insensitive because `sequence` is case-folded during
        // normalization and `from` is not.
        if !from.eq_ignore_ascii_case(&actual) {
            issues.push(A3Issue::new(
                C::VariantResidueMismatch,
                pointer(&v.path, "from"),
                format!(
                    "'from' is '{from}' but residue {} of the sequence is '{actual}'; \
                     the variant list may be annotated against a different isoform",
                    v.position
                ),
            ));
        }
    }
}

// ===========================================================================
// Construction
// ===========================================================================

/// Build the validated [`A3`]. Every invariant it relies on was established by
/// the four stages, so no check here can fail.
fn build(draft: Draft) -> A3 {
    let positions = |index: &DraftIndex| -> Vec<u32> {
        match index {
            DraftIndex::Positions(p) => p.iter().map(|&v| v as u32).collect(),
            DraftIndex::Ranges(_) => unreachable!("family geometry is fixed by the schema"),
        }
    };
    let ranges = |index: &DraftIndex| -> Vec<[u32; 2]> {
        match index {
            DraftIndex::Ranges(r) => r.iter().map(|&[s, e]| [s as u32, e as u32]).collect(),
            DraftIndex::Positions(_) => unreachable!("family geometry is fixed by the schema"),
        }
    };
    let flex = |index: &DraftIndex| -> A3Index {
        match index {
            DraftIndex::Positions(_) => A3Index::Positions(positions(index)),
            DraftIndex::Ranges(_) => A3Index::Ranges(ranges(index)),
        }
    };

    A3 {
        schema: A3_SCHEMA_URI.to_string(),
        a3_version: A3_VERSION.to_string(),
        sequence: draft.sequence,
        annotations: Annotations {
            site: draft
                .site
                .iter()
                .map(|(k, e)| {
                    (
                        k.clone(),
                        SiteEntry {
                            index: positions(&e.index),
                            kind: e.kind.clone(),
                        },
                    )
                })
                .collect(),
            region: draft
                .region
                .iter()
                .map(|(k, e)| {
                    (
                        k.clone(),
                        RegionEntry {
                            index: ranges(&e.index),
                            kind: e.kind.clone(),
                        },
                    )
                })
                .collect(),
            ptm: draft
                .ptm
                .iter()
                .map(|(k, e)| {
                    (
                        k.clone(),
                        FlexEntry {
                            index: flex(&e.index),
                            kind: e.kind.clone(),
                        },
                    )
                })
                .collect(),
            processing: draft
                .processing
                .iter()
                .map(|(k, e)| {
                    (
                        k.clone(),
                        FlexEntry {
                            index: flex(&e.index),
                            kind: e.kind.clone(),
                        },
                    )
                })
                .collect(),
            variant: draft
                .variant
                .into_iter()
                .map(|v| VariantRecord {
                    position: v.position as u32,
                    extra: v.extra,
                })
                .collect(),
        },
        metadata: draft.metadata,
    }
}

// ===========================================================================
// Helpers
// ===========================================================================

enum Geometry {
    Positions,
    Ranges,
}

/// How an index element classifies: a whole number, a nested array, or neither.
enum Elem {
    Integer(i64),
    Array,
    Other,
}

fn classify(v: &Value) -> Elem {
    match v {
        Value::Array(_) => Elem::Array,
        Value::Number(n) => match as_integer(n) {
            Some(i) => Elem::Integer(i),
            None => Elem::Other,
        },
        // A JSON boolean is not a number, so `true` is never a position.
        _ => Elem::Other,
    }
}

/// Interpret a JSON number as an integer.
///
/// JSON has no integer type distinct from number, and JSON Schema's
/// `type: "integer"` accepts any number with a zero fractional part. `3.0` is
/// therefore the position 3, while `2.5` is not a position at all.
fn as_integer(n: &serde_json::Number) -> Option<i64> {
    if let Some(i) = n.as_i64() {
        return Some(i);
    }
    let f = n.as_f64()?;
    (f.fract() == 0.0 && f >= i64::MIN as f64 && f <= i64::MAX as f64).then_some(f as i64)
}

fn expected_shape(family: &str) -> &'static str {
    match family {
        "site" => "an integer position",
        "region" => "a [start, end] range",
        _ => "an integer position or a [start, end] range",
    }
}

/// Extract a single character from a JSON value, if it is a one-character string.
fn single_char(v: Option<&Value>) -> Option<char> {
    let s = v?.as_str()?;
    let mut chars = s.chars();
    let first = chars.next()?;
    chars.next().is_none().then_some(first)
}

/// Report one `A3E_UNKNOWN_FIELD` per property outside `allowed`.
fn unknown_fields(
    obj: &Map<String, Value>,
    allowed: &[&str],
    base: &str,
    issues: &mut Vec<A3Issue>,
) {
    for key in obj.keys() {
        if !allowed.contains(&key.as_str()) {
            issues.push(A3Issue::new(
                C::UnknownField,
                pointer(base, key),
                format!(
                    "'{key}' is not a permitted member here; expected one of: {}",
                    allowed.join(", ")
                ),
            ));
        }
    }
}

/// Render a JSON value compactly for a human message, truncating long ones.
fn render(v: &Value) -> String {
    let s = match v {
        Value::Null => "null".to_string(),
        Value::String(s) => format!("\"{s}\""),
        other => other.to_string(),
    };
    if s.chars().count() > 40 {
        format!("{}…", s.chars().take(39).collect::<String>())
    } else {
        s
    }
}

// ===========================================================================
// Tests
// ===========================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::issue::A3IssueCode;
    use serde_json::json;

    fn minimal() -> Value {
        json!({
            "$schema": A3_SCHEMA_URI,
            "a3_version": A3_VERSION,
            "sequence": "MAEPRQ",
        })
    }

    fn issues_of(v: &Value) -> Vec<(A3IssueCode, String)> {
        validate(v)
            .unwrap_err()
            .into_iter()
            .map(|i| (i.code, i.path))
            .collect()
    }

    #[test]
    fn minimal_document_is_valid() {
        let a3 = validate(&minimal()).unwrap();
        assert_eq!(a3.sequence(), "MAEPRQ");
        assert!(a3.annotations().site().is_empty());
        assert_eq!(a3.metadata().uniprot_id(), "");
    }

    #[test]
    fn sequence_is_case_folded() {
        let mut v = minimal();
        v["sequence"] = json!("maeprq");
        assert_eq!(validate(&v).unwrap().sequence(), "MAEPRQ");
    }

    #[test]
    fn non_object_root_is_the_only_issue() {
        assert_eq!(
            issues_of(&json!([1, 2, 3])),
            vec![(A3IssueCode::DocNotObject, String::new())]
        );
    }

    #[test]
    fn envelope_issues_are_collected_together() {
        let v = json!({"$schema": "urn:a3", "a3_version": "0.9.0", "sequence": "MA"});
        assert_eq!(
            issues_of(&v),
            vec![
                (A3IssueCode::EnvelopeSchemaMismatch, "/$schema".into()),
                (A3IssueCode::EnvelopeVersionMismatch, "/a3_version".into()),
            ]
        );
    }

    #[test]
    fn later_stages_are_suppressed_by_earlier_ones() {
        // A bad sequence (Stage 2) with many would-be out-of-bounds positions
        // (Stage 4) must report only the Stage 2 issue.
        let mut v = minimal();
        v["sequence"] = json!("MAEP1Q");
        v["annotations"] = json!({"site": {"s": {"index": [90, 91, 92, 93]}}});
        assert_eq!(
            issues_of(&v),
            vec![(A3IssueCode::SeqCharset, "/sequence".into())]
        );
    }

    #[test]
    fn pointer_escapes_annotation_names() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"a/b": {"index": [99]}, "a~b": {"index": [98]}}});
        assert_eq!(
            issues_of(&v),
            vec![
                (
                    A3IssueCode::PosOutOfBounds,
                    "/annotations/site/a~1b/index/0".into()
                ),
                (
                    A3IssueCode::PosOutOfBounds,
                    "/annotations/site/a~0b/index/0".into()
                ),
            ]
        );
    }

    #[test]
    fn subscripts_name_the_sorted_index() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"s": {"index": [5, 0, -3]}}});
        // Sorted to [-3, 0, 5], which places the two bad values at subscripts 0 and 1.
        assert_eq!(
            issues_of(&v),
            vec![
                (
                    A3IssueCode::PosNotPositive,
                    "/annotations/site/s/index/0".into()
                ),
                (
                    A3IssueCode::PosNotPositive,
                    "/annotations/site/s/index/1".into()
                ),
            ]
        );
    }

    #[test]
    fn duplicates_report_once_per_repeated_value() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"s": {"index": [3, 3, 3, 5, 5]}}});
        assert_eq!(
            issues_of(&v),
            vec![
                (
                    A3IssueCode::PosDuplicate,
                    "/annotations/site/s/index".into()
                ),
                (
                    A3IssueCode::PosDuplicate,
                    "/annotations/site/s/index".into()
                ),
            ]
        );
    }

    #[test]
    fn integral_floats_are_positions() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"s": {"index": [3.0, 1.0]}}});
        let a3 = validate(&v).unwrap();
        assert_eq!(a3.annotations().site()["s"].index(), &[1, 3]);
    }

    #[test]
    fn non_integral_numbers_are_not_positions() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"s": {"index": [2.5]}}});
        assert_eq!(
            issues_of(&v),
            vec![(
                A3IssueCode::IndexElementType,
                "/annotations/site/s/index/0".into()
            )]
        );
    }

    #[test]
    fn booleans_are_not_positions() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {"s": {"index": [true, 2]}}});
        assert_eq!(
            issues_of(&v),
            vec![(
                A3IssueCode::IndexElementType,
                "/annotations/site/s/index/0".into()
            )]
        );
    }

    #[test]
    fn mixed_ptm_index_is_rejected() {
        let mut v = minimal();
        v["annotations"] = json!({"ptm": {"p": {"index": [1, [3, 5]]}}});
        assert_eq!(
            issues_of(&v),
            vec![(A3IssueCode::IndexMixed, "/annotations/ptm/p/index".into())]
        );
    }

    #[test]
    fn guard_suppresses_only_its_own_subtree() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {
            "s": [1, 2],
            "t": {"index": 5},
            "u": {"index": [99]},
        }});
        // `u`'s out-of-bounds position is Stage 4 and so is suppressed entirely.
        assert_eq!(
            issues_of(&v),
            vec![
                (A3IssueCode::EntryNotObject, "/annotations/site/s".into()),
                (
                    A3IssueCode::IndexNotArray,
                    "/annotations/site/t/index".into()
                ),
            ]
        );
    }

    #[test]
    fn variant_residue_rule_is_narrow() {
        let mut v = minimal();
        v["annotations"] = json!({"variant": [
            {"position": 5, "from": "K"},     // residue 5 is R — mismatch
            {"position": 5, "from": "r"},     // case-insensitive match
            {"position": 5, "from": "Arg"},   // not a single character — ignored
            {"position": 5},                  // absent — ignored
        ]});
        assert_eq!(
            issues_of(&v),
            vec![(
                A3IssueCode::VariantResidueMismatch,
                "/annotations/variant/0/from".into()
            )]
        );
    }

    #[test]
    fn annotation_order_is_preserved() {
        let mut v = minimal();
        v["annotations"] = json!({"site": {
            "zeta": {"index": [1]},
            "alpha": {"index": [2]},
            "Mu": {"index": [3]},
        }});
        let a3 = validate(&v).unwrap();
        let names: Vec<&str> = a3.annotations().site().keys().map(String::as_str).collect();
        assert_eq!(names, vec!["zeta", "alpha", "Mu"]);
    }
}
