"""Tests for the functional API."""

import pytest

from rtemis.a3 import (
    A3ParseError,
    A3ValidationError,
    a3_from_json,
    a3_to_json,
    create_a3,
    residue_at,
    variants_at,
)


# ---------------------------------------------------------------------------
# create_a3
# ---------------------------------------------------------------------------


class TestCreateA3:
    def test_minimal(self):
        a3 = create_a3("MAEPRQ")
        assert a3.sequence == "MAEPRQ"

    def test_with_all_annotations(self):
        a3 = create_a3(
            "MAEPRQFV",
            site={"catalytic": {"index": [1, 3], "type": "activeSite"}},
            region={"domain": {"index": [[1, 4]], "type": ""}},
            ptm={"phospho": {"index": [2], "type": ""}},
            processing={"signal": {"index": [[1, 3]], "type": "signalPeptide"}},
            variant=[{"position": 5, "from": "R", "to": "Q"}],
            metadata={"uniprot_id": "P12345", "organism": "Homo sapiens"},
        )
        assert a3.annotations.site["catalytic"].type == "activeSite"
        assert a3.metadata.uniprot_id == "P12345"

    def test_validation_error(self):
        with pytest.raises(A3ValidationError):
            create_a3("M")  # too short

    def test_lowercase_uppercased(self):
        a3 = create_a3("maeprq")
        assert a3.sequence == "MAEPRQ"

    def test_bounds_error(self):
        with pytest.raises(A3ValidationError, match="out of bounds"):
            create_a3(
                "MAEPRQ",
                site={"bad": {"index": [100], "type": ""}},
            )


# ---------------------------------------------------------------------------
# a3_from_json / a3_to_json
# ---------------------------------------------------------------------------

MINIMAL_JSON = '{"sequence": "MAEPRQ"}'

FULL_JSON = """{
  "sequence": "MAEPRQFV",
  "annotations": {
    "site": {
      "catalytic": { "index": [1, 3, 5], "type": "activeSite" }
    },
    "region": {
      "domain": { "index": [[1, 4], [6, 8]], "type": "" }
    },
    "ptm": {
      "phospho": { "index": [2, 4], "type": "" }
    },
    "processing": {},
    "variant": [
      { "position": 3, "from": "E", "to": "D" }
    ]
  },
  "metadata": {
    "uniprot_id": "P10636",
    "description": "Test protein",
    "reference": "",
    "organism": "Homo sapiens"
  }
}"""


class TestA3FromJson:
    def test_minimal(self):
        a3 = a3_from_json(MINIMAL_JSON)
        assert a3.sequence == "MAEPRQ"

    def test_full(self):
        a3 = a3_from_json(FULL_JSON)
        assert a3.sequence == "MAEPRQFV"
        assert a3.annotations.site["catalytic"].index == [1, 3, 5]
        assert a3.annotations.variant[0].position == 3

    def test_invalid_json(self):
        with pytest.raises(A3ParseError, match="invalid JSON"):
            a3_from_json("not json {")

    def test_valid_json_invalid_a3(self):
        with pytest.raises(A3ValidationError):
            a3_from_json('{"sequence": "M"}')  # too short


class TestA3ToJson:
    def test_roundtrip_minimal(self):
        a3 = create_a3("MAEPRQ")
        text = a3_to_json(a3)
        a3_back = a3_from_json(text)
        assert a3_back.sequence == a3.sequence

    def test_roundtrip_full(self):
        a3 = a3_from_json(FULL_JSON)
        text = a3_to_json(a3, indent=2)
        a3_back = a3_from_json(text)
        assert a3_back.sequence == a3.sequence
        assert a3_back.annotations.site["catalytic"].index == [1, 3, 5]
        assert a3_back.annotations.variant[0].position == 3
        assert a3_back.metadata.organism == "Homo sapiens"

    def test_indent(self):
        a3 = create_a3("MAEPRQ")
        compact = a3_to_json(a3)
        indented = a3_to_json(a3, indent=2)
        assert "\n" not in compact
        assert "\n" in indented

    def test_all_families_present_in_output(self):
        """Even when empty, all five annotation families must be in output."""
        a3 = create_a3("MAEPRQ")
        text = a3_to_json(a3)
        import json

        data = json.loads(text)
        assert "site" in data["annotations"]
        assert "region" in data["annotations"]
        assert "ptm" in data["annotations"]
        assert "processing" in data["annotations"]
        assert "variant" in data["annotations"]

    def test_type_always_present(self):
        """type field must be present even when empty string."""
        a3 = create_a3(
            "MAEPRQ",
            site={"test": {"index": [1, 2], "type": ""}},
        )
        import json

        data = json.loads(a3_to_json(a3))
        assert data["annotations"]["site"]["test"]["type"] == ""


# ---------------------------------------------------------------------------
# residue_at
# ---------------------------------------------------------------------------


class TestResidueAt:
    def test_first(self):
        a3 = create_a3("MAEPRQ")
        assert residue_at(a3, 1) == "M"

    def test_last(self):
        a3 = create_a3("MAEPRQ")
        assert residue_at(a3, 6) == "Q"

    def test_middle(self):
        a3 = create_a3("MAEPRQ")
        assert residue_at(a3, 3) == "E"

    def test_out_of_bounds_high(self):
        a3 = create_a3("MAEPRQ")
        with pytest.raises(ValueError, match="out of bounds"):
            residue_at(a3, 7)

    def test_out_of_bounds_zero(self):
        a3 = create_a3("MAEPRQ")
        with pytest.raises(ValueError, match="out of bounds"):
            residue_at(a3, 0)

    def test_out_of_bounds_negative(self):
        a3 = create_a3("MAEPRQ")
        with pytest.raises(ValueError, match="out of bounds"):
            residue_at(a3, -1)


# ---------------------------------------------------------------------------
# variants_at
# ---------------------------------------------------------------------------


class TestVariantsAt:
    def test_found(self):
        a3 = create_a3(
            "MAEPRQ",
            variant=[
                {"position": 3, "from": "E", "to": "D"},
                {"position": 5, "from": "R", "to": "Q"},
            ],
        )
        result = variants_at(a3, 3)
        assert len(result) == 1
        assert result[0].position == 3

    def test_not_found(self):
        a3 = create_a3(
            "MAEPRQ",
            variant=[{"position": 3, "from": "E", "to": "D"}],
        )
        result = variants_at(a3, 1)
        assert result == []

    def test_multiple_at_same_position(self):
        a3 = create_a3(
            "MAEPRQ",
            variant=[
                {"position": 3, "from": "E", "to": "D"},
                {"position": 3, "from": "E", "to": "K"},
            ],
        )
        result = variants_at(a3, 3)
        assert len(result) == 2
