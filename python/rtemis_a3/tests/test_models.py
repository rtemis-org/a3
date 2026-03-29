"""Tests for Pydantic models."""

import pytest
from pydantic import ValidationError

from rtemis_a3._models import (
    A3,
    A3Annotations,
    A3Metadata,
    FlexEntry,
    RegionEntry,
    SiteEntry,
    VariantRecord,
)


# ---------------------------------------------------------------------------
# SiteEntry
# ---------------------------------------------------------------------------


class TestSiteEntry:
    def test_basic(self):
        entry = SiteEntry(index=[3, 1, 5], type="activeSite")
        assert entry.index == [1, 3, 5]  # sorted
        assert entry.type == "activeSite"

    def test_dedup(self):
        entry = SiteEntry(index=[3, 3, 1])
        assert entry.index == [1, 3]

    def test_default_type(self):
        entry = SiteEntry(index=[1, 2])
        assert entry.type == ""

    def test_empty_index(self):
        entry = SiteEntry(index=[])
        assert entry.index == []

    def test_non_positive_rejected(self):
        with pytest.raises(ValidationError):
            SiteEntry(index=[0, 1, 2])

    def test_negative_rejected(self):
        with pytest.raises(ValidationError):
            SiteEntry(index=[-1, 2])

    def test_frozen(self):
        entry = SiteEntry(index=[1, 2])
        with pytest.raises(ValidationError):
            entry.index = [3, 4]


# ---------------------------------------------------------------------------
# RegionEntry
# ---------------------------------------------------------------------------


class TestRegionEntry:
    def test_basic(self):
        entry = RegionEntry(index=[[6, 10], [1, 5]], type="domain")
        assert entry.index == [(1, 5), (6, 10)]  # sorted
        assert entry.type == "domain"

    def test_default_type(self):
        entry = RegionEntry(index=[[1, 5]])
        assert entry.type == ""

    def test_empty_index(self):
        entry = RegionEntry(index=[])
        assert entry.index == []

    def test_start_equals_end_rejected(self):
        with pytest.raises(ValidationError, match="start must be less than end"):
            RegionEntry(index=[[5, 5]])

    def test_start_greater_than_end_rejected(self):
        with pytest.raises(ValidationError, match="start must be less than end"):
            RegionEntry(index=[[10, 5]])

    def test_overlapping_rejected(self):
        with pytest.raises(ValidationError, match="overlapping"):
            RegionEntry(index=[[1, 5], [3, 8]])

    def test_adjacent_permitted(self):
        entry = RegionEntry(index=[[1, 5], [6, 10]])
        assert entry.index == [(1, 5), (6, 10)]

    def test_non_positive_rejected(self):
        with pytest.raises(ValidationError):
            RegionEntry(index=[[0, 5]])


# ---------------------------------------------------------------------------
# FlexEntry
# ---------------------------------------------------------------------------


class TestFlexEntry:
    def test_positions(self):
        entry = FlexEntry(index=[5, 1, 3])
        assert entry.index == [1, 3, 5]

    def test_ranges(self):
        entry = FlexEntry(index=[[6, 10], [1, 5]])
        assert entry.index == [(1, 5), (6, 10)]

    def test_empty(self):
        entry = FlexEntry(index=[])
        assert entry.index == []

    def test_range_overlap_rejected(self):
        with pytest.raises(ValidationError, match="overlapping"):
            FlexEntry(index=[[1, 5], [3, 8]])


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
        assert extras["from"] == "M"
        assert extras["to"] == "L"
        assert extras["source"] == "ClinVar"

    def test_position_required(self):
        with pytest.raises(ValidationError):
            VariantRecord()

    def test_non_positive_position_rejected(self):
        with pytest.raises(ValidationError):
            VariantRecord(position=0)

    def test_non_json_extra_rejected(self):
        with pytest.raises(ValidationError, match="not JSON-compatible"):
            VariantRecord(position=1, callback=lambda: None)


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
            A3Annotations(site={}, unknown_family={})

    def test_empty_annotation_name_rejected(self):
        with pytest.raises(ValidationError, match="non-empty"):
            A3Annotations(site={"": {"index": [1, 2], "type": ""}})


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
            A3Metadata(gene_name="MAPT")


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
            A3(sequence="MA", extra_field="nope")

    def test_bounds_check_site_out_of_range(self):
        with pytest.raises(ValidationError, match="out of bounds"):
            A3(
                sequence="MAEPRQ",
                annotations={
                    "site": {"bad": {"index": [100], "type": ""}},
                },
            )

    def test_bounds_check_region_out_of_range(self):
        with pytest.raises(ValidationError, match="out of bounds"):
            A3(
                sequence="MAEPRQ",
                annotations={
                    "region": {"bad": {"index": [[1, 100]], "type": ""}},
                },
            )

    def test_bounds_check_variant_out_of_range(self):
        with pytest.raises(ValidationError, match="out of bounds"):
            A3(
                sequence="MAEPRQ",
                annotations={
                    "variant": [{"position": 100}],
                },
            )

    def test_bounds_check_ptm_positions(self):
        with pytest.raises(ValidationError, match="out of bounds"):
            A3(
                sequence="MAEPRQ",
                annotations={
                    "ptm": {"bad": {"index": [100], "type": ""}},
                },
            )

    def test_bounds_check_ptm_ranges(self):
        with pytest.raises(ValidationError, match="out of bounds"):
            A3(
                sequence="MAEPRQ",
                annotations={
                    "ptm": {"bad": {"index": [[1, 100]], "type": ""}},
                },
            )

    def test_full_valid(self):
        a3 = A3(
            sequence="MAEPRQFV",
            annotations={
                "site": {"catalytic": {"index": [1, 3, 5], "type": "activeSite"}},
                "region": {"domain": {"index": [[1, 4], [6, 8]], "type": ""}},
                "ptm": {"phospho": {"index": [2, 4], "type": ""}},
                "processing": {},
                "variant": [{"position": 3, "from": "E", "to": "D"}],
            },
            metadata={
                "uniprot_id": "P10636",
                "description": "Test protein",
                "reference": "",
                "organism": "Homo sapiens",
            },
        )
        assert len(a3.sequence) == 8
        assert a3.annotations.site["catalytic"].index == [1, 3, 5]
        assert a3.annotations.region["domain"].index == [(1, 4), (6, 8)]
        assert a3.metadata.organism == "Homo sapiens"
