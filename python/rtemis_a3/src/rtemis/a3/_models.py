"""Internal Pydantic models for A3 validation.

These models are not part of the public API. Users should construct A3
objects through the functional API in ``api.py``.
"""

from __future__ import annotations

import re
from typing import Annotated, Any, Union

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)
from pydantic.functional_validators import BeforeValidator

from ._normalize import (
    check_no_overlap,
    is_json_compatible,
    sort_dedup,
    sort_ranges,
)


class _BoundsErrors(Exception):
    """Internal: carries individual bounds-check messages out of the model validator."""

    def __init__(self, messages: list[str]) -> None:
        self.messages = messages


# ---------------------------------------------------------------------------
# Constrained types
# ---------------------------------------------------------------------------


def _reject_bool(v: Any) -> Any:
    if isinstance(v, bool):
        raise ValueError("boolean values are not valid positions")
    return v


Position = Annotated[int, BeforeValidator(_reject_bool), Field(gt=0)]

# ---------------------------------------------------------------------------
# Annotation entry models
# ---------------------------------------------------------------------------

_SEQUENCE_RE = re.compile(r"^[A-Za-z*]+$")


class SiteEntry(BaseModel):
    """A site annotation entry: positions + type label."""

    model_config = ConfigDict(frozen=True)

    index: list[Position]
    type: str = ""

    @field_validator("index", mode="before")
    @classmethod
    def _normalize_positions(cls, v: Any) -> list[int]:
        if not isinstance(v, list):
            raise ValueError("index must be a list of positive integers")
        return sort_dedup(v)


class RegionEntry(BaseModel):
    """A region annotation entry: ranges + type label."""

    model_config = ConfigDict(frozen=True)

    index: list[tuple[Position, Position]]
    type: str = ""

    @field_validator("index", mode="before")
    @classmethod
    def _normalize_ranges(cls, v: Any) -> list[tuple[int, int]]:
        if not isinstance(v, list):
            raise ValueError("index must be a list of [start, end] ranges")
        # Coerce inner lists to tuples (from JSON parsing)
        coerced: list[tuple[int, int]] = []
        for item in v:
            if isinstance(item, (list, tuple)) and len(item) == 2:
                s, e = item
                if isinstance(s, bool) or isinstance(e, bool):
                    raise ValueError("boolean values are not valid positions")
                if not (isinstance(s, int) and isinstance(e, int)):
                    raise ValueError(
                        f"range elements must be integers, got [{type(s).__name__}, "
                        f"{type(e).__name__}]"
                    )
                if s >= e:
                    raise ValueError(
                        f"range start must be less than end, got [{s}, {e}]"
                    )
                coerced.append((s, e))
            else:
                raise ValueError(
                    f"each range must be a 2-element [start, end] pair, "
                    f"got {item!r}"
                )
        sorted_ranges = sort_ranges(coerced)
        check_no_overlap(sorted_ranges)
        return sorted_ranges


class FlexEntry(BaseModel):
    """A PTM or Processing annotation entry: positions or ranges + type label."""

    model_config = ConfigDict(frozen=True)

    index: Union[list[Position], list[tuple[Position, Position]]]
    type: str = ""

    @field_validator("index", mode="before")
    @classmethod
    def _normalize_flex_index(cls, v: Any) -> list[int] | list[tuple[int, int]]:
        if not isinstance(v, list):
            raise ValueError("index must be a list")
        if len(v) == 0:
            return []
        # Determine geometry from first element
        first = v[0]
        if isinstance(first, bool):
            raise ValueError("boolean values are not valid positions")
        if isinstance(first, (list, tuple)):
            # Ranges path
            coerced: list[tuple[int, int]] = []
            for item in v:
                if isinstance(item, (list, tuple)) and len(item) == 2:
                    s, e = item
                    if isinstance(s, bool) or isinstance(e, bool):
                        raise ValueError("boolean values are not valid positions")
                    if not (isinstance(s, int) and isinstance(e, int)):
                        raise ValueError(
                            f"range elements must be integers, got "
                            f"[{type(s).__name__}, {type(e).__name__}]"
                        )
                    if s >= e:
                        raise ValueError(
                            f"range start must be less than end, got [{s}, {e}]"
                        )
                    coerced.append((s, e))
                else:
                    raise ValueError(
                        f"each range must be a 2-element [start, end] pair, "
                        f"got {item!r}"
                    )
            sorted_ranges = sort_ranges(coerced)
            check_no_overlap(sorted_ranges)
            return sorted_ranges
        elif isinstance(first, int) and not isinstance(first, bool):
            # Positions path
            for item in v:
                if isinstance(item, bool) or not isinstance(item, int):
                    raise ValueError(
                        "cannot mix integers and non-integers in index"
                    )
            return sort_dedup(v)
        else:
            raise ValueError(
                f"index elements must be integers or [start, end] pairs, "
                f"got {type(first).__name__}"
            )


class VariantRecord(BaseModel):
    """A variant record with required position and open extra fields."""

    model_config = ConfigDict(frozen=True, extra="allow")

    position: Position

    @model_validator(mode="after")
    def _check_extras_json_compatible(self) -> VariantRecord:
        extras = self.__pydantic_extra__ or {}
        for key, value in extras.items():
            if not is_json_compatible(value):
                raise ValueError(
                    f"variant field '{key}' is not JSON-compatible: {value!r}"
                )
        return self


# ---------------------------------------------------------------------------
# Container models
# ---------------------------------------------------------------------------


class A3Annotations(BaseModel):
    """Container for the five annotation families."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    site: dict[str, SiteEntry] = Field(default_factory=dict)
    region: dict[str, RegionEntry] = Field(default_factory=dict)
    ptm: dict[str, FlexEntry] = Field(default_factory=dict)
    processing: dict[str, FlexEntry] = Field(default_factory=dict)
    variant: list[VariantRecord] = Field(default_factory=list)

    @model_validator(mode="after")
    def _check_annotation_names(self) -> A3Annotations:
        for family_name in ("site", "region", "ptm", "processing"):
            family: dict[str, Any] = getattr(self, family_name)
            for key in family:
                if not key:
                    raise ValueError(
                        f"annotations.{family_name}: annotation names must be "
                        f"non-empty strings"
                    )
        return self


class A3Metadata(BaseModel):
    """Metadata for an amino acid annotation."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    uniprot_id: str = ""
    description: str = ""
    reference: str = ""
    organism: str = ""


class A3(BaseModel):
    """Root A3 model: sequence + annotations + metadata."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    sequence: str
    annotations: A3Annotations = Field(default_factory=A3Annotations)
    metadata: A3Metadata = Field(default_factory=A3Metadata)

    @field_validator("sequence", mode="before")
    @classmethod
    def _normalize_sequence(cls, v: Any) -> str:
        if not isinstance(v, str):
            raise ValueError("sequence must be a string")
        if len(v) < 2:
            raise ValueError(
                f"sequence must be at least 2 characters, got {len(v)}"
            )
        if not _SEQUENCE_RE.match(v):
            invalid = set(re.findall(r"[^A-Za-z*]", v))
            raise ValueError(
                f"sequence contains invalid characters: {invalid}"
            )
        return v.upper()

    @model_validator(mode="after")
    def _bounds_check(self) -> A3:
        """Stage 2 contextual validation: check all positions/ranges against
        sequence length."""
        seq_len = len(self.sequence)
        errors: list[str] = []

        # Site positions
        for name, entry in self.annotations.site.items():
            for pos in entry.index:
                if pos < 1 or pos > seq_len:
                    errors.append(
                        f"annotations.site.{name}.index: position {pos} is out "
                        f"of bounds for sequence of length {seq_len} "
                        f"(must be 1-{seq_len})"
                    )

        # Region ranges
        for name, entry in self.annotations.region.items():
            for start, end in entry.index:
                if start < 1 or start > seq_len:
                    errors.append(
                        f"annotations.region.{name}.index: start position "
                        f"{start} is out of bounds for sequence of length "
                        f"{seq_len} (must be 1-{seq_len})"
                    )
                if end < 1 or end > seq_len:
                    errors.append(
                        f"annotations.region.{name}.index: end position "
                        f"{end} is out of bounds for sequence of length "
                        f"{seq_len} (must be 1-{seq_len})"
                    )

        # PTM (positions or ranges)
        for name, entry in self.annotations.ptm.items():
            _check_flex_bounds(errors, f"annotations.ptm.{name}", entry, seq_len)

        # Processing (positions or ranges)
        for name, entry in self.annotations.processing.items():
            _check_flex_bounds(
                errors, f"annotations.processing.{name}", entry, seq_len
            )

        # Variant positions
        for i, variant in enumerate(self.annotations.variant):
            if variant.position < 1 or variant.position > seq_len:
                errors.append(
                    f"annotations.variant[{i}].position: position "
                    f"{variant.position} is out of bounds for sequence of "
                    f"length {seq_len} (must be 1-{seq_len})"
                )

        if errors:
            raise _BoundsErrors(errors)

        return self


def _check_flex_bounds(
    errors: list[str], path: str, entry: FlexEntry, seq_len: int
) -> None:
    """Check bounds for a FlexEntry (positions or ranges)."""
    for item in entry.index:
        if isinstance(item, tuple):
            start, end = item
            if start < 1 or start > seq_len:
                errors.append(
                    f"{path}.index: start position {start} is out of bounds "
                    f"for sequence of length {seq_len} (must be 1-{seq_len})"
                )
            if end < 1 or end > seq_len:
                errors.append(
                    f"{path}.index: end position {end} is out of bounds "
                    f"for sequence of length {seq_len} (must be 1-{seq_len})"
                )
        else:
            if item < 1 or item > seq_len:
                errors.append(
                    f"{path}.index: position {item} is out of bounds "
                    f"for sequence of length {seq_len} (must be 1-{seq_len})"
                )
