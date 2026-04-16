"""Tests for Pydantic models."""

import pytest
from pydantic import ValidationError

from rtemis.a3._models import (
    A3,
    A3Annotations,
    A3Flex,
    A3Metadata,
    A3Position,
    A3Range,
    VariantRecord,
)
from rtemis.a3 import create_a3
from rtemis.a3.errors import A3ValidationError


# ---------------------------------------------------------------------------
# A3Position (site)
# ---------------------------------------------------------------------------


class TestA3Position:
    def test_basic(self):
        entry = A3Position(index=[3, 1, 5], type="activeSite")
        assert entry.index == [1, 3, 5]  # sorted
        assert entry.type == "activeSite"

    def test_duplicate_positions_rejected(self):
        with pytest.raises(ValidationError, match="duplicate position"):
            A3Position(index=[3, 3, 1])

    def test_default_type(self):
        entry = A3Position(index=[1, 2])
        assert entry.type == ""

    def test_empty_index(self):
        entry = A3Position(index=[])
        assert entry.index == []

    def test_non_positive_rejected(self):
        with pytest.raises(ValidationError):
            A3Position(index=[0, 1, 2])

    def test_negative_rejected(self):
        with pytest.raises(ValidationError):
            A3Position(index=[-1, 2])

    def test_bool_rejected(self):
        with pytest.raises(ValidationError, match="boolean"):
            A3Position(index=[True, 2])

    def test_frozen(self):
        entry = A3Position(index=[1, 2])
        with pytest.raises(ValidationError):
            entry.index = [3, 4]


# ---------------------------------------------------------------------------
# A3Range (region)
# ---------------------------------------------------------------------------


class TestA3Range:
    def test_basic(self):
        entry = A3Range(index=[(6, 10), (1, 5)], type="domain")
        assert entry.index == [(1, 5), (6, 10)]  # sorted
        assert entry.type == "domain"

    def test_default_type(self):
        entry = A3Range(index=[(1, 5)])
        assert entry.type == ""

    def test_empty_index(self):
        entry = A3Range(index=[])
        assert entry.index == []

    def test_start_equals_end_rejected(self):
        with pytest.raises(ValidationError, match="start must be less than end"):
            A3Range(index=[(5, 5)])

    def test_start_greater_than_end_rejected(self):
        with pytest.raises(ValidationError, match="start must be less than end"):
            A3Range(index=[(10, 5)])

    def test_overlapping_rejected(self):
        with pytest.raises(ValidationError, match="overlapping"):
            A3Range(index=[(1, 5), (3, 8)])

    def test_adjacent_permitted(self):
        entry = A3Range(index=[(1, 5), (6, 10)])
        assert entry.index == [(1, 5), (6, 10)]

    def test_non_positive_rejected(self):
        with pytest.raises(ValidationError):
            A3Range(index=[(0, 5)])

    def test_bool_rejected(self):
        with pytest.raises(ValidationError, match="boolean"):
            A3Range(index=[(True, 5)])


# ---------------------------------------------------------------------------
# A3Flex (ptm / processing)
# ---------------------------------------------------------------------------


class TestA3Flex:
    def test_positions(self):
        entry = A3Flex(index=[5, 1, 3])
        assert entry.index == [1, 3, 5]

    def test_ranges(self):
        entry = A3Flex(index=[(6, 10), (1, 5)])
        assert entry.index == [(1, 5), (6, 10)]

    def test_empty(self):
        entry = A3Flex(index=[])
        assert entry.index == []

    def test_range_overlap_rejected(self):
        with pytest.raises(ValidationError, match="overlapping"):
            A3Flex(index=[(1, 5), (3, 8)])

    def test_bool_position_rejected(self):
        with pytest.raises(ValidationError, match="boolean"):
            A3Flex(index=[True, 2])

    def test_bool_range_rejected(self):
        with pytest.raises(ValidationError, match="boolean"):
            A3Flex(index=[(True, 5)])


# ---------------------------------------------------------------------------
# VariantRecord
# ---------------------------------------------------------------------------


class TestVariantRecord:
    def test_basic(self):
        v = VariantRecord(position=42, **{"from": "A", "to": "V"})
        assert v.position == 42

    def test_extra_fields(self):
        v = VariantRecord(position=1, **{"from": "M", "to": "L", "source": "ClinVar"})
        extras = v.__pydantic_extra__
        assert extras is not None
        assert extras["from"] == "M"
        assert extras["to"] == "L"
        assert extras["source"] == "ClinVar"

    def test_position_required(self):
        with pytest.raises(ValidationError):
            VariantRecord.model_validate({})

    def test_non_positive_position_rejected(self):
        with pytest.raises(ValidationError):
            VariantRecord(position=0)

    def test_bool_position_rejected(self):
        with pytest.raises(ValidationError, match="boolean"):
            VariantRecord(position=True)

    def test_non_json_extra_rejected(self):
        with pytest.raises(ValidationError, match="not JSON-compatible"):
            VariantRecord(position=1, **{"callback": lambda: None})


# ---------------------------------------------------------------------------
# A3Annotations
# ---------------------------------------------------------------------------


class TestA3Annotations:
    def test_defaults(self):
        ann = A3Annotations()
        assert ann.site == {}
        assert ann.region == {}
        assert ann.ptm == {}
        assert ann.processing == {}
        assert ann.variant == []

    def test_unknown_family_rejected(self):
        with pytest.raises(ValidationError):
            A3Annotations.model_validate({"site": {}, "unknown_family": {}})

    def test_empty_annotation_name_rejected(self):
        with pytest.raises(ValidationError, match="non-empty"):
            A3Annotations.model_validate({"site": {"": {"index": [1, 2], "type": ""}}})


# ---------------------------------------------------------------------------
# A3Metadata
# ---------------------------------------------------------------------------


class TestA3Metadata:
    def test_defaults(self):
        meta = A3Metadata()
        assert meta.uniprot_id == ""
        assert meta.description == ""
        assert meta.reference == ""
        assert meta.organism == ""

    def test_custom(self):
        meta = A3Metadata(uniprot_id="P12345", organism="Homo sapiens")
        assert meta.uniprot_id == "P12345"
        assert meta.organism == "Homo sapiens"

    def test_unknown_field_rejected(self):
        with pytest.raises(ValidationError):
            A3Metadata.model_validate({"gene_name": "MAPT"})


# ---------------------------------------------------------------------------
# A3 (root model)
# ---------------------------------------------------------------------------


class TestA3:
    def test_minimal(self):
        a3 = A3(sequence="MA")
        assert a3.sequence == "MA"
        assert a3.annotations.site == {}
        assert a3.metadata.uniprot_id == ""

    def test_sequence_uppercased(self):
        a3 = A3(sequence="maeprq")
        assert a3.sequence == "MAEPRQ"

    def test_sequence_too_short(self):
        with pytest.raises(ValidationError, match="at least 2"):
            A3(sequence="M")

    def test_sequence_empty(self):
        with pytest.raises(ValidationError, match="at least 2"):
            A3(sequence="")

    def test_sequence_invalid_chars(self):
        with pytest.raises(ValidationError, match="invalid characters"):
            A3(sequence="MA1PT")

    def test_stop_codon_accepted(self):
        a3 = A3(sequence="MA*")
        assert a3.sequence == "MA*"

    def test_unknown_top_level_key_rejected(self):
        with pytest.raises(ValidationError):
            A3.model_validate({"sequence": "MA", "extra_field": "nope"})

    def test_bounds_check_site_out_of_range(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3("MAEPRQ", site={"bad": {"index": [100], "type": ""}})

    def test_bounds_check_region_out_of_range(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3("MAEPRQ", region={"bad": {"index": [[1, 100]], "type": ""}})

    def test_bounds_check_variant_out_of_range(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3("MAEPRQ", variant=[{"position": 100}])

    def test_bounds_check_ptm_positions(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3("MAEPRQ", ptm={"bad": {"index": [100], "type": ""}})

    def test_bounds_check_ptm_ranges(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3("MAEPRQ", ptm={"bad": {"index": [[1, 100]], "type": ""}})

    def test_bounds_check_multi_error(self):
        with pytest.raises(A3ValidationError) as exc_info:
            create_a3(
                "MAEPRQ",
                site={
                    "s1": {"index": [99], "type": ""},
                    "s2": {"index": [100], "type": ""},
                },
                variant=[{"position": 88}],
            )
        err = exc_info.value
        assert len(err.errors) == 3
        assert len(err.messages) == 3
        assert all("out of bounds" in m for m in err.messages)

    def test_full_valid(self):
        a3 = A3.model_validate(
            {
                "sequence": "MAEPRQFV",
                "annotations": {
                    "site": {"catalytic": {"index": [1, 3, 5], "type": "activeSite"}},
                    "region": {"domain": {"index": [[1, 4], [6, 8]], "type": ""}},
                    "ptm": {"phospho": {"index": [2, 4], "type": ""}},
                    "processing": {},
                    "variant": [{"position": 3, "from": "E", "to": "D"}],
                },
                "metadata": {
                    "uniprot_id": "P10636",
                    "description": "Test protein",
                    "reference": "",
                    "organism": "Homo sapiens",
                },
            }
        )
        assert len(a3.sequence) == 8
        assert a3.annotations.site["catalytic"].index == [1, 3, 5]
        assert a3.annotations.region["domain"].index == [(1, 4), (6, 8)]
        assert a3.metadata.organism == "Homo sapiens"
