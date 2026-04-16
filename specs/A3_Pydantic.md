# A3 Pydantic Specification

Amino Acid Annotation (A3) format — Python/Pydantic implementation design.

## Requirements

- Strict canonical format only — no legacy input accommodation
- Runtime validation via Pydantic v2
- Immutable value objects (`frozen=True` on all models)
- Serialize to JSON (top priority); TOML deferred
- User-facing API is functional — users never call model constructors directly
- 100% wire-format compatible with R and TypeScript implementations

## Tooling

- Package manager: `uv`
- Formatter / linter: `ruff`
- Type checker: `ty`
- Test runner: `pytest`
- Validation: `pydantic >=2`

## Model Hierarchy

```
# Constrained type
Position = Annotated[int, Field(gt=0)]   # positive integer, 1-based

# Annotation entry models (internal)
SiteEntry(BaseModel, frozen=True)
  index: list[Position]       # sorted; duplicates rejected via field_validator
  type:  str = ""

RegionEntry(BaseModel, frozen=True)
  index: list[tuple[Position, Position]]  # sorted, overlap-checked via field_validator
  type:  str = ""

FlexEntry(BaseModel, frozen=True)
  index: list[Position] | list[tuple[Position, Position]]  # geometry inferred from first element
  type:  str = ""

VariantRecord(BaseModel, frozen=True, extra="allow")
  position: Position
  # extra fields: any JSON-compatible values (checked via model_validator)

# Container models
A3Annotations(BaseModel, frozen=True, extra="forbid")
  site:       dict[str, SiteEntry]   = {}
  region:     dict[str, RegionEntry] = {}
  ptm:        dict[str, FlexEntry]   = {}
  processing: dict[str, FlexEntry]   = {}
  variant:    list[VariantRecord]    = []

A3Metadata(BaseModel, frozen=True, extra="forbid")
  uniprot_id:  str = ""
  description: str = ""
  reference:   str = ""
  organism:    str = ""

A3(BaseModel, frozen=True, extra="forbid")
  sequence:    str
  annotations: A3Annotations = A3Annotations()
  metadata:    A3Metadata    = A3Metadata()
```

## Model Details

### `SiteEntry`

- `index`: `field_validator(mode="before")` sorts ascending then rejects any duplicate
  positions. All elements must be positive integers (enforced by `Position` constraint).
- `type`: plain string, defaults to `""`.

### `RegionEntry`

- `index`: `field_validator(mode="before")` coerces inner lists/tuples to `tuple[int, int]`,
  validates `start < end` for each pair, sorts via `sort_ranges()`, then calls
  `check_no_overlap()`. All elements must be positive integers.
- `type`: plain string, defaults to `""`.

### `FlexEntry`

- `index`: `field_validator(mode="before")` infers geometry from the first element:
  - If the first element is a list/tuple → ranges path (same coercion and checks as
    `RegionEntry`)
  - If the first element is an integer → positions path (same normalization as
    `SiteEntry`)
  - Empty list → returned as-is
  - Mixed geometry is rejected.

### `VariantRecord`

- `extra="allow"` — open extra fields accepted.
- `model_validator(mode="after")` checks every extra field with `is_json_compatible()`.
  Functions, class instances, sets, bytes, etc. are rejected.

### `A3Annotations`

- `extra="forbid"` rejects unknown annotation families.
- `model_validator(mode="after")` checks that all annotation names (dict keys) in
  `site`, `region`, `ptm`, `processing` are non-empty strings.

### `A3Metadata`

- `extra="forbid"` rejects unknown metadata fields.
- All four fields default to `""`.

### `A3`

- `extra="forbid"` rejects unknown top-level keys.
- `field_validator("sequence", mode="before")`:
  - Must be a string
  - Must be ≥ 2 characters
  - Characters must match `[A-Za-z*]` — invalid characters reported explicitly
  - Normalized to uppercase
- `model_validator(mode="after")` — stage 2 contextual bounds check (see Validation).

## Normalization Helpers (`_normalize.py`)

Pure functions used inside Pydantic validators:

```python
check_no_duplicate_positions(values: list[int]) -> list[int]
# Sort ascending; raises ValueError if any position appears more than once.

sort_dedup(values: list[int]) -> list[int]
# Deduplicate and sort ascending (sorted(set(values))).
# Utility for a future lenient/clean API — not called by validators.

sort_ranges(ranges: list[tuple[int, int]]) -> list[tuple[int, int]]
# Sort by start, then end for ties. No merging.

check_no_overlap(ranges: list[tuple[int, int]]) -> None
# Raises ValueError if any consecutive pair overlaps (curr_start <= prev_end).
# Adjacent ranges (curr_start = prev_end + 1) are permitted.

is_json_compatible(value: object) -> bool
# Accepts: None, bool, int, float, str, list, dict (string keys).
# Rejects: functions, class instances, sets, bytes, etc.
```

## Public API (`api.py`)

Users never construct models directly. All entry points are plain functions:

```python
create_a3(
    sequence: str,
    *,
    site:       dict[str, dict[str, Any]] | None = None,
    region:     dict[str, dict[str, Any]] | None = None,
    ptm:        dict[str, dict[str, Any]] | None = None,
    processing: dict[str, dict[str, Any]] | None = None,
    variant:    list[dict[str, Any]]      | None = None,
    metadata:   dict[str, str]            | None = None,
) -> A3
# Build and validate an A3 from raw components.
# Raises A3ValidationError on invalid input.

a3_from_json(text: str) -> A3
# Parse a JSON string into an A3 object.
# Raises A3ParseError on malformed JSON.
# Raises A3ValidationError on schema violations.

a3_to_json(a3: A3, *, indent: int | None = None) -> str
# Serialize an A3 to a canonical JSON string.
# Uses model_dump(mode="json") for full round-trip fidelity.

residue_at(a3: A3, position: int) -> str
# Return the residue at a 1-based position.
# Raises ValueError if out of bounds.

variants_at(a3: A3, position: int) -> list[VariantRecord]
# Return all variant records at a 1-based position.
```

## Error Classes (`errors.py`)

```python
class A3ValidationError(Exception)
    errors: list[dict[str, Any]]   # Pydantic ValidationError.errors() output

class A3ParseError(Exception)
    # Wraps json.JSONDecodeError and file I/O errors
```

`A3ValidationError.errors` is cast from Pydantic's `list[ErrorDetails]` (a TypedDict)
to `list[dict[str, Any]]` to keep `errors.py` free of pydantic imports.

## File Structure

```
python/rtemis_a3/
  src/rtemis_a3/
    _normalize.py    # pure normalization helpers
    _models.py       # Pydantic models (internal — not exported directly)
    errors.py        # A3ValidationError, A3ParseError
    api.py           # public functional API
    __init__.py      # public exports
  tests/
    test_models.py   # model-level tests (internal API)
    test_api.py      # public API tests
  pyproject.toml
  uv.lock
```

## Wire Format

Strict canonical format. Unknown keys are rejected at all levels. The `type` field
is always present in output (defaults to `""`):

```json
{
  "sequence": "MAEPRQ...",
  "annotations": {
    "site": {
      "Disease_associated_variant": { "index": [4, 5, 14], "type": "" },
      "catalyticResidues":          { "index": [57, 102],  "type": "activeSite" }
    },
    "region": {
      "KXGS": { "index": [[259, 262], [290, 293]], "type": "" }
    },
    "ptm": {
      "Phosphorylation": { "index": [17, 18, 29], "type": "" }
    },
    "processing": {},
    "variant": [
      { "position": 301, "from": "P", "to": "L" }
    ]
  },
  "metadata": {
    "uniprot_id":  "P10636",
    "description": "Microtubule-associated protein tau",
    "reference":   "",
    "organism":    "Homo sapiens"
  }
}
```

`model_dump(mode="json")` produces this format. Tuples in `index` fields are
serialized as JSON arrays, preserving wire-format compatibility.

## Validation

### Stage 1 — Structural (`field_validator(mode="before")` on each model)

- `sequence`: non-empty string, `[A-Za-z*]+`, ≥ 2 characters, uppercased
- Positions: positive integers, sorted ascending; duplicates rejected
- Ranges: inner lists/tuples coerced to `tuple[int, int]`, `start < end`,
  sorted, overlap-checked
- `FlexEntry` index: geometry inferred from first element — ranges or positions,
  never mixed
- Annotation names: non-empty strings (checked via `model_validator(mode="after")`)
- Unknown annotation families: rejected (`extra="forbid"`)
- Variant extra fields: JSON-compatible (checked via `model_validator(mode="after")`)
- Metadata fields: strings; unknown keys rejected (`extra="forbid"`)
- Unknown top-level keys: rejected (`extra="forbid"`)

### Stage 2 — Contextual (`model_validator(mode="after")` on `A3`)

Runs after all structural validation and normalization:

- All `site` positions satisfy `1 ≤ pos ≤ len(sequence)`
- All `region` range endpoints satisfy the same
- All `ptm` and `processing` positions and range endpoints satisfy the same
- All `variant` positions satisfy the same

All errors are collected before raising so the full set of violations is reported
at once. Error messages include the full field path and concrete bounds:
`"annotations.site.bad.index: position 100 is out of bounds for sequence of
length 6 (must be 1-6)"`.
