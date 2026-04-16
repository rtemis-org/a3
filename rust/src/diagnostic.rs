//! Diagnostic mode — full step-by-step A3 validation.
//!
//! Implements the 6-step plan from `specs/diagnostic.md`:
//!
//! 1. Valid JSON                                              \[fatal\]
//! 2. Envelope: `$schema` and `a3_version`
//! 3. Top-level field presence, types, no unknown keys       \[fatal per field\]
//! 4. Sequence value
//! 5. Annotation families: site, region, ptm, processing, variant
//! 6. Metadata fields
//!
//! Every non-fatal error is accumulated before returning, so the caller sees
//! all violations at once. Fatal errors halt only the steps that depend on
//! their output — unrelated checks still run.

use rtemis_a3::normalization::{normalize_positions, normalize_ranges, normalize_sequence};
use rtemis_a3::{A3, A3_SCHEMA_URI, A3_VERSION, a3_from_json};
use serde_json::{Map, Value};

const TOP_LEVEL_KEYS: &[&str] = &[
    "$schema",
    "a3_version",
    "sequence",
    "annotations",
    "metadata",
];
const ANN_FAMILIES: &[&str] = &["site", "region", "ptm", "processing", "variant"];
const METADATA_KEYS: &[&str] = &["uniprot_id", "description", "reference", "organism"];

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Typed diagnostic failure — distinguishes a fatal parse error (exit 2)
/// from A3 validation errors (exit 1).
pub enum DiagnoseError {
    /// Step 1 failed: the input is not valid JSON or not a JSON object.
    /// Callers should exit with code 2 (system/parse error).
    Fatal(Vec<String>),
    /// One or more A3 validation errors. Callers should exit with code 1.
    Invalid(Vec<String>),
}

/// Full diagnostic validation of an A3 JSON string.
///
/// Follows the 6-step plan in `specs/diagnostic.md`. Returns `Ok(A3)` when
/// every check passes, or `Err(DiagnoseError)` with every violation collected.
/// `DiagnoseError::Fatal` signals a JSON parse failure (exit 2);
/// `DiagnoseError::Invalid` signals A3 validation errors (exit 1).
///
/// On success the standard `a3_from_json` path is used to construct the `A3`,
/// so the returned value is identical to what the fast path would produce.
pub fn a3_diagnose(text: &str) -> Result<A3, DiagnoseError> {
    let mut errors: Vec<String> = Vec::new();

    // -----------------------------------------------------------------------
    // Step 1: Valid JSON  [fatal]
    // -----------------------------------------------------------------------

    let value: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => return Err(DiagnoseError::Fatal(vec![format!("Invalid JSON: {e}")])),
    };

    let obj = match value.as_object() {
        Some(o) => o,
        None => {
            return Err(DiagnoseError::Fatal(vec![
                "Expected a JSON object at the top level".to_string(),
            ]));
        }
    };

    // -----------------------------------------------------------------------
    // Step 2: Envelope
    // -----------------------------------------------------------------------

    check_envelope(obj, &mut errors);

    // -----------------------------------------------------------------------
    // Step 3: Top-level field presence, types, unknown keys
    //
    // Each extraction returns `None` when the field is absent or has the wrong
    // type — that `None` propagates to disable the steps that depend on it.
    // -----------------------------------------------------------------------

    let seq_raw = require_string_field(obj, "sequence", &mut errors);

    // `annotations` and `metadata` are required even when empty (`{}`).
    let ann_obj = required_object_field(obj, "annotations", &mut errors);
    let meta_obj = required_object_field(obj, "metadata", &mut errors);

    for key in obj.keys() {
        if !TOP_LEVEL_KEYS.contains(&key.as_str()) {
            errors.push(format!("unknown top-level key '{key}'"));
        }
    }

    // -----------------------------------------------------------------------
    // Step 4: Sequence value
    //
    // Normalize the raw string (uppercase, character set, min length).
    // `seq_len` is `Some` only when this step fully passes — Step 5 needs it
    // for bounds checking.
    // -----------------------------------------------------------------------

    let seq_len: Option<u32> = seq_raw.and_then(|s| match normalize_sequence(s) {
        Ok(normalized) => Some(normalized.len() as u32),
        Err(e) => {
            errors.push(e);
            None
        }
    });

    // -----------------------------------------------------------------------
    // Step 5: Annotation families
    // -----------------------------------------------------------------------

    if let Some(ann) = ann_obj {
        check_annotations(ann, seq_len, &mut errors);
    }

    // -----------------------------------------------------------------------
    // Step 6: Metadata fields
    // -----------------------------------------------------------------------

    if let Some(meta) = meta_obj {
        check_metadata(meta, &mut errors);
    }

    // -----------------------------------------------------------------------
    // Return
    // -----------------------------------------------------------------------

    if errors.is_empty() {
        // All diagnostic checks passed — use the standard fast path to build
        // a validated A3. This should never fail: if it does, the diagnostic
        // checks have a gap that needs fixing.
        Ok(a3_from_json(text).expect("diagnostic passed but standard parse failed"))
    } else {
        Err(DiagnoseError::Invalid(errors))
    }
}

// ---------------------------------------------------------------------------
// Step implementations
// ---------------------------------------------------------------------------

fn check_envelope(obj: &Map<String, Value>, errors: &mut Vec<String>) {
    match obj.get("$schema") {
        None => errors.push(format!("'$schema' is required; must be '{A3_SCHEMA_URI}'")),
        Some(v) => match v.as_str() {
            None => errors.push(format!(
                "'$schema' must be a string; expected '{A3_SCHEMA_URI}'"
            )),
            Some(s) if s != A3_SCHEMA_URI => {
                errors.push(format!("'$schema' must be '{A3_SCHEMA_URI}', got '{s}'"))
            }
            _ => {}
        },
    }

    match obj.get("a3_version") {
        None => errors.push(format!("'a3_version' is required; must be '{A3_VERSION}'")),
        Some(v) => match v.as_str() {
            None => errors.push(format!(
                "'a3_version' must be a string; expected '{A3_VERSION}'"
            )),
            Some(s) if s != A3_VERSION => {
                errors.push(format!("'a3_version' must be '{A3_VERSION}', got '{s}'"))
            }
            _ => {}
        },
    }
}

fn check_annotations(ann: &Map<String, Value>, seq_len: Option<u32>, errors: &mut Vec<String>) {
    for key in ann.keys() {
        if !ANN_FAMILIES.contains(&key.as_str()) {
            errors.push(format!("annotations: unknown family '{key}'"));
        }
    }

    if let Some(v) = ann.get("site") {
        match v.as_object() {
            Some(o) => check_site_entries(o, seq_len, errors),
            None => errors.push("'annotations.site' must be an object".to_string()),
        }
    }

    if let Some(v) = ann.get("region") {
        match v.as_object() {
            Some(o) => check_region_entries(o, seq_len, errors),
            None => errors.push("'annotations.region' must be an object".to_string()),
        }
    }

    if let Some(v) = ann.get("ptm") {
        match v.as_object() {
            Some(o) => check_flex_entries(o, "ptm", seq_len, errors),
            None => errors.push("'annotations.ptm' must be an object".to_string()),
        }
    }

    if let Some(v) = ann.get("processing") {
        match v.as_object() {
            Some(o) => check_flex_entries(o, "processing", seq_len, errors),
            None => errors.push("'annotations.processing' must be an object".to_string()),
        }
    }

    if let Some(v) = ann.get("variant") {
        match v.as_array() {
            Some(a) => check_variant_entries(a, seq_len, errors),
            None => errors.push("'annotations.variant' must be an array".to_string()),
        }
    }
}

fn check_site_entries(
    entries: &Map<String, Value>,
    seq_len: Option<u32>,
    errors: &mut Vec<String>,
) {
    for (name, val) in entries {
        if name.is_empty() {
            errors.push("annotations.site: annotation name must not be empty".to_string());
            continue;
        }
        let field = format!("annotations.site.{name}");

        let Some(entry) = require_object(val, &field, errors) else {
            continue;
        };
        let Some(index_val) = require_field(entry, "index", &field, errors) else {
            continue;
        };
        let Some(arr) = require_array(index_val, &format!("{field}.index"), errors) else {
            continue;
        };
        let Some(positions) = parse_positions(arr, &format!("{field}.index"), errors) else {
            continue;
        };

        match normalize_positions(positions, &field) {
            Err(e) => errors.push(e),
            Ok(positions) => check_position_bounds(&positions, seq_len, &field, errors),
        }

        check_kind_field(entry, &field, errors);
    }
}

fn check_region_entries(
    entries: &Map<String, Value>,
    seq_len: Option<u32>,
    errors: &mut Vec<String>,
) {
    for (name, val) in entries {
        if name.is_empty() {
            errors.push("annotations.region: annotation name must not be empty".to_string());
            continue;
        }
        let field = format!("annotations.region.{name}");

        let Some(entry) = require_object(val, &field, errors) else {
            continue;
        };
        let Some(index_val) = require_field(entry, "index", &field, errors) else {
            continue;
        };
        let Some(arr) = require_array(index_val, &format!("{field}.index"), errors) else {
            continue;
        };
        let Some(ranges) = parse_ranges(arr, &format!("{field}.index"), errors) else {
            continue;
        };

        match normalize_ranges(ranges, &field) {
            Err(e) => errors.push(e),
            Ok(ranges) => check_range_bounds(&ranges, seq_len, &field, errors),
        }

        check_kind_field(entry, &field, errors);
    }
}

fn check_flex_entries(
    entries: &Map<String, Value>,
    family: &str,
    seq_len: Option<u32>,
    errors: &mut Vec<String>,
) {
    for (name, val) in entries {
        if name.is_empty() {
            errors.push(format!(
                "annotations.{family}: annotation name must not be empty"
            ));
            continue;
        }
        let field = format!("annotations.{family}.{name}");

        let Some(entry) = require_object(val, &field, errors) else {
            continue;
        };
        let Some(index_val) = require_field(entry, "index", &field, errors) else {
            continue;
        };
        let Some(arr) = require_array(index_val, &format!("{field}.index"), errors) else {
            continue;
        };

        // Detect positions vs ranges by the type of the first element.
        // Empty arrays are valid for either — treat as positions (no-op).
        let is_ranges = arr.first().map(|v| v.is_array()).unwrap_or(false);

        if is_ranges {
            let Some(ranges) = parse_ranges(arr, &format!("{field}.index"), errors) else {
                continue;
            };
            match normalize_ranges(ranges, &field) {
                Err(e) => errors.push(e),
                Ok(ranges) => check_range_bounds(&ranges, seq_len, &field, errors),
            }
        } else {
            let Some(positions) = parse_positions(arr, &format!("{field}.index"), errors) else {
                continue;
            };
            match normalize_positions(positions, &field) {
                Err(e) => errors.push(e),
                Ok(positions) => check_position_bounds(&positions, seq_len, &field, errors),
            }
        }

        check_kind_field(entry, &field, errors);
    }
}

fn check_variant_entries(entries: &[Value], seq_len: Option<u32>, errors: &mut Vec<String>) {
    for (i, val) in entries.iter().enumerate() {
        let field = format!("annotations.variant[{i}]");

        let Some(entry) = require_object(val, &field, errors) else {
            continue;
        };

        match entry.get("position") {
            None => errors.push(format!("{field}: missing required field 'position'")),
            Some(v) => match v.as_u64().and_then(|n| u32::try_from(n).ok()) {
                None => errors.push(format!("{field}.position: must be a positive integer")),
                Some(0) => errors.push(format!("{field}.position: must be ≥ 1 (1-based); got 0")),
                Some(pos) => {
                    if let Some(len) = seq_len
                        && pos > len
                    {
                        errors.push(format!(
                            "{field}.position: {pos} is out of bounds \
                             for sequence of length {len} (must be 1–{len})"
                        ));
                    }
                }
            },
        }
    }
}

fn check_metadata(meta: &Map<String, Value>, errors: &mut Vec<String>) {
    for key in meta.keys() {
        if !METADATA_KEYS.contains(&key.as_str()) {
            errors.push(format!("metadata: unknown field '{key}'"));
        }
    }
    for &key in METADATA_KEYS {
        if let Some(v) = meta.get(key)
            && !v.is_string()
        {
            errors.push(format!("metadata.{key}: must be a string"));
        }
    }
}

// ---------------------------------------------------------------------------
// Bounds helpers
// ---------------------------------------------------------------------------

fn check_position_bounds(
    positions: &[u32],
    seq_len: Option<u32>,
    field: &str,
    errors: &mut Vec<String>,
) {
    let Some(len) = seq_len else { return };
    for &pos in positions {
        if pos > len {
            errors.push(format!(
                "{field}.index: position {pos} is out of bounds \
                 for sequence of length {len} (must be 1–{len})"
            ));
        }
    }
}

fn check_range_bounds(
    ranges: &[[u32; 2]],
    seq_len: Option<u32>,
    field: &str,
    errors: &mut Vec<String>,
) {
    let Some(len) = seq_len else { return };
    for [_start, end] in ranges {
        if *end > len {
            errors.push(format!(
                "{field}.index: range endpoint {end} is out of bounds \
                 for sequence of length {len} (must be 1–{len})"
            ));
        }
    }
}

// ---------------------------------------------------------------------------
// Field extraction helpers
// ---------------------------------------------------------------------------

/// Require a string field in `obj`. Pushes an error and returns `None` if
/// absent or not a string.
fn require_string_field<'a>(
    obj: &'a Map<String, Value>,
    key: &str,
    errors: &mut Vec<String>,
) -> Option<&'a str> {
    match obj.get(key) {
        None => {
            errors.push(format!("'{key}' is required"));
            None
        }
        Some(v) => match v.as_str() {
            Some(s) => Some(s),
            None => {
                errors.push(format!("'{key}' must be a string"));
                None
            }
        },
    }
}

/// Require an object field in `obj`. Pushes an error and returns `None` if
/// absent or not an object.
fn required_object_field<'a>(
    obj: &'a Map<String, Value>,
    key: &str,
    errors: &mut Vec<String>,
) -> Option<&'a Map<String, Value>> {
    match obj.get(key) {
        None => {
            errors.push(format!("'{key}' is required"));
            None
        }
        Some(v) => match v.as_object() {
            Some(o) => Some(o),
            None => {
                errors.push(format!("'{key}' must be an object"));
                None
            }
        },
    }
}

fn require_object<'a>(
    val: &'a Value,
    field: &str,
    errors: &mut Vec<String>,
) -> Option<&'a Map<String, Value>> {
    match val.as_object() {
        Some(o) => Some(o),
        None => {
            errors.push(format!("{field}: must be an object"));
            None
        }
    }
}

fn require_field<'a>(
    obj: &'a Map<String, Value>,
    key: &str,
    field: &str,
    errors: &mut Vec<String>,
) -> Option<&'a Value> {
    match obj.get(key) {
        Some(v) => Some(v),
        None => {
            errors.push(format!("{field}: missing required field '{key}'"));
            None
        }
    }
}

fn require_array<'a>(
    val: &'a Value,
    field: &str,
    errors: &mut Vec<String>,
) -> Option<&'a Vec<Value>> {
    match val.as_array() {
        Some(a) => Some(a),
        None => {
            errors.push(format!("{field}: must be an array"));
            None
        }
    }
}

/// Parse an array of JSON values as `Vec<u32>` positions.
///
/// Returns `None` if any element is not a non-negative integer that fits in
/// `u32` — all bad elements are reported before returning.
fn parse_positions(arr: &[Value], field: &str, errors: &mut Vec<String>) -> Option<Vec<u32>> {
    let mut positions = Vec::with_capacity(arr.len());
    let mut ok = true;
    for (i, v) in arr.iter().enumerate() {
        match v.as_u64().and_then(|n| u32::try_from(n).ok()) {
            Some(pos) => positions.push(pos),
            None => {
                errors.push(format!("{field}[{i}]: must be a positive integer"));
                ok = false;
            }
        }
    }
    ok.then_some(positions)
}

/// Parse an array of JSON values as `Vec<[u32; 2]>` ranges.
///
/// Each element must be a 2-element array of non-negative integers that fit in
/// `u32`. All bad elements are reported before returning `None`.
fn parse_ranges(arr: &[Value], field: &str, errors: &mut Vec<String>) -> Option<Vec<[u32; 2]>> {
    let mut ranges = Vec::with_capacity(arr.len());
    let mut ok = true;
    for (i, v) in arr.iter().enumerate() {
        let elem = format!("{field}[{i}]");
        match v.as_array() {
            None => {
                errors.push(format!("{elem}: must be a [start, end] array"));
                ok = false;
            }
            Some(pair) if pair.len() != 2 => {
                errors.push(format!(
                    "{elem}: must be a 2-element [start, end] array, got {} elements",
                    pair.len()
                ));
                ok = false;
            }
            Some(pair) => {
                let s = pair[0].as_u64().and_then(|n| u32::try_from(n).ok());
                let e = pair[1].as_u64().and_then(|n| u32::try_from(n).ok());
                match (s, e) {
                    (Some(s), Some(e)) => ranges.push([s, e]),
                    _ => {
                        errors.push(format!("{elem}: start and end must be positive integers"));
                        ok = false;
                    }
                }
            }
        }
    }
    ok.then_some(ranges)
}

/// Check that the optional `"type"` field in an annotation entry is a string.
fn check_kind_field(entry: &Map<String, Value>, field: &str, errors: &mut Vec<String>) {
    if let Some(v) = entry.get("type")
        && !v.is_string()
    {
        errors.push(format!("{field}.type: must be a string"));
    }
}
