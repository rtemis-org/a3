"""Validation issues: stable codes, RFC 6901 paths, and human messages.

The contract is defined in ``spec/error-codes.md``
(https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) and
``spec/error-paths.md``
(https://github.com/rtemis-org/a3/blob/main/spec/error-paths.md), and is shared by
all five A3 implementations. An
issue's ``code`` and ``path`` are contractual; its ``message`` is not and may
be reworded freely.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class A3IssueCode(StrEnum):
    """A stable, machine-readable validation issue code.

    Codes are never renumbered and never reused. Subclassing :class:`~enum.StrEnum`
    means a member compares equal to its wire string, so
    ``issue.code == "A3E_SEQ_TOO_SHORT"`` works without an explicit conversion.

    See ``spec/error-codes.md``
    (https://github.com/rtemis-org/a3/blob/main/spec/error-codes.md) for the full
    registry, including each code's trigger condition and the path it reports.
    """

    # ── Stage 1 — Envelope ────────────────────────────────────────────────
    DOC_NOT_OBJECT = "A3E_DOC_NOT_OBJECT"
    ENVELOPE_SCHEMA_MISSING = "A3E_ENVELOPE_SCHEMA_MISSING"
    ENVELOPE_SCHEMA_MISMATCH = "A3E_ENVELOPE_SCHEMA_MISMATCH"
    ENVELOPE_VERSION_MISSING = "A3E_ENVELOPE_VERSION_MISSING"
    ENVELOPE_VERSION_MISMATCH = "A3E_ENVELOPE_VERSION_MISMATCH"

    # ── Stage 2 — Structural ──────────────────────────────────────────────
    UNKNOWN_FIELD = "A3E_UNKNOWN_FIELD"
    SEQ_MISSING = "A3E_SEQ_MISSING"
    SEQ_NOT_STRING = "A3E_SEQ_NOT_STRING"
    SEQ_TOO_SHORT = "A3E_SEQ_TOO_SHORT"
    SEQ_CHARSET = "A3E_SEQ_CHARSET"
    ANNOTATIONS_NOT_OBJECT = "A3E_ANNOTATIONS_NOT_OBJECT"
    METADATA_NOT_OBJECT = "A3E_METADATA_NOT_OBJECT"
    METADATA_FIELD_NOT_STRING = "A3E_METADATA_FIELD_NOT_STRING"
    FAMILY_NOT_OBJECT = "A3E_FAMILY_NOT_OBJECT"
    VARIANT_LIST_NOT_ARRAY = "A3E_VARIANT_LIST_NOT_ARRAY"
    NAME_EMPTY = "A3E_NAME_EMPTY"
    ENTRY_NOT_OBJECT = "A3E_ENTRY_NOT_OBJECT"
    ENTRY_TYPE_NOT_STRING = "A3E_ENTRY_TYPE_NOT_STRING"
    INDEX_MISSING = "A3E_INDEX_MISSING"
    INDEX_NOT_ARRAY = "A3E_INDEX_NOT_ARRAY"
    INDEX_ELEMENT_TYPE = "A3E_INDEX_ELEMENT_TYPE"
    INDEX_MIXED = "A3E_INDEX_MIXED"
    RANGE_ARITY = "A3E_RANGE_ARITY"
    RANGE_ENDPOINT_NOT_INTEGER = "A3E_RANGE_ENDPOINT_NOT_INTEGER"
    VARIANT_NOT_OBJECT = "A3E_VARIANT_NOT_OBJECT"
    VARIANT_POSITION_MISSING = "A3E_VARIANT_POSITION_MISSING"
    VARIANT_POSITION_NOT_INTEGER = "A3E_VARIANT_POSITION_NOT_INTEGER"

    # ── Stage 3 — Intra-field ─────────────────────────────────────────────
    POS_NOT_POSITIVE = "A3E_POS_NOT_POSITIVE"
    POS_DUPLICATE = "A3E_POS_DUPLICATE"
    RANGE_ENDPOINT_NOT_POSITIVE = "A3E_RANGE_ENDPOINT_NOT_POSITIVE"
    RANGE_ORDER = "A3E_RANGE_ORDER"
    RANGE_OVERLAP = "A3E_RANGE_OVERLAP"
    VARIANT_POSITION_NOT_POSITIVE = "A3E_VARIANT_POSITION_NOT_POSITIVE"

    # ── Stage 4 — Contextual ──────────────────────────────────────────────
    POS_OUT_OF_BOUNDS = "A3E_POS_OUT_OF_BOUNDS"
    RANGE_OUT_OF_BOUNDS = "A3E_RANGE_OUT_OF_BOUNDS"
    VARIANT_OUT_OF_BOUNDS = "A3E_VARIANT_OUT_OF_BOUNDS"
    VARIANT_RESIDUE_MISMATCH = "A3E_VARIANT_RESIDUE_MISMATCH"

    @property
    def stage(self) -> int:
        """The validation stage this code belongs to (1-4)."""
        return _STAGES[self]


_STAGES: dict[A3IssueCode, int] = {
    A3IssueCode.DOC_NOT_OBJECT: 1,
    A3IssueCode.ENVELOPE_SCHEMA_MISSING: 1,
    A3IssueCode.ENVELOPE_SCHEMA_MISMATCH: 1,
    A3IssueCode.ENVELOPE_VERSION_MISSING: 1,
    A3IssueCode.ENVELOPE_VERSION_MISMATCH: 1,
    A3IssueCode.UNKNOWN_FIELD: 2,
    A3IssueCode.SEQ_MISSING: 2,
    A3IssueCode.SEQ_NOT_STRING: 2,
    A3IssueCode.SEQ_TOO_SHORT: 2,
    A3IssueCode.SEQ_CHARSET: 2,
    A3IssueCode.ANNOTATIONS_NOT_OBJECT: 2,
    A3IssueCode.METADATA_NOT_OBJECT: 2,
    A3IssueCode.METADATA_FIELD_NOT_STRING: 2,
    A3IssueCode.FAMILY_NOT_OBJECT: 2,
    A3IssueCode.VARIANT_LIST_NOT_ARRAY: 2,
    A3IssueCode.NAME_EMPTY: 2,
    A3IssueCode.ENTRY_NOT_OBJECT: 2,
    A3IssueCode.ENTRY_TYPE_NOT_STRING: 2,
    A3IssueCode.INDEX_MISSING: 2,
    A3IssueCode.INDEX_NOT_ARRAY: 2,
    A3IssueCode.INDEX_ELEMENT_TYPE: 2,
    A3IssueCode.INDEX_MIXED: 2,
    A3IssueCode.RANGE_ARITY: 2,
    A3IssueCode.RANGE_ENDPOINT_NOT_INTEGER: 2,
    A3IssueCode.VARIANT_NOT_OBJECT: 2,
    A3IssueCode.VARIANT_POSITION_MISSING: 2,
    A3IssueCode.VARIANT_POSITION_NOT_INTEGER: 2,
    A3IssueCode.POS_NOT_POSITIVE: 3,
    A3IssueCode.POS_DUPLICATE: 3,
    A3IssueCode.RANGE_ENDPOINT_NOT_POSITIVE: 3,
    A3IssueCode.RANGE_ORDER: 3,
    A3IssueCode.RANGE_OVERLAP: 3,
    A3IssueCode.VARIANT_POSITION_NOT_POSITIVE: 3,
    A3IssueCode.POS_OUT_OF_BOUNDS: 4,
    A3IssueCode.RANGE_OUT_OF_BOUNDS: 4,
    A3IssueCode.VARIANT_OUT_OF_BOUNDS: 4,
    A3IssueCode.VARIANT_RESIDUE_MISMATCH: 4,
}


@dataclass(frozen=True, slots=True)
class A3Issue:
    """A single validation issue.

    Attributes
    ----------
    code : A3IssueCode
        Stable machine-readable code. Contractual.
    path : str
        RFC 6901 JSON Pointer to the offending value. Contractual.
    message : str
        Human-readable explanation. Not contractual; may be reworded freely.
    """

    code: A3IssueCode
    path: str
    message: str

    @property
    def stage(self) -> int:
        """The validation stage this issue belongs to (1-4)."""
        return self.code.stage

    def __str__(self) -> str:
        # The empty pointer denotes the whole document; writing it as "/" would
        # be wrong, since that is the member named "".
        where = self.path or "<document>"
        return f"[{self.code}] {where}: {self.message}"


def escape_token(token: str) -> str:
    """Escape one reference token for inclusion in a JSON Pointer.

    RFC 6901 escapes exactly two characters. ``~`` must be replaced before
    ``/``, or a key containing ``/`` would come out as ``~01`` instead of
    ``~1``.

    Parameters
    ----------
    token : str
        A raw object member name.

    Returns
    -------
    str
        The escaped reference token.
    """
    return token.replace("~", "~0").replace("/", "~1")


def pointer(base: str, token: str | int) -> str:
    """Append one reference token or array subscript to a JSON Pointer.

    Parameters
    ----------
    base : str
        The pointer to extend. The empty string denotes the document root.
    token : str or int
        A **raw** object member name, which this function escapes, or a 0-based
        array subscript, which needs no escaping. Do not pre-escape a name:
        ``pointer(b, "a~1b")`` yields ``a~01b``, because the ``~`` is escaped a
        second time.

    Returns
    -------
    str
        The extended pointer.

    Examples
    --------
    >>> pointer("/annotations/site", "a/b")     # escaped
    '/annotations/site/a~1b'
    >>> pointer("", "$schema")                  # nothing to escape
    '/$schema'
    >>> pointer("/annotations/variant", 3)      # subscript, not escaped
    '/annotations/variant/3'
    """
    if isinstance(token, int):
        return f"{base}/{token}"
    return f"{base}/{escape_token(token)}"
