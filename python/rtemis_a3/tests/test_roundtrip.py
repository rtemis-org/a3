"""Round-trip fidelity tests for A3 JSON serialization."""

import json

from rtemis.a3 import a3_from_json, a3_to_json, create_a3


class TestRoundTrip:
    """Verify that A3 -> JSON -> A3 produces identical data."""

    def test_minimal(self):
        a3 = create_a3("MAEPRQ")
        text = a3_to_json(a3)
        a3_back = a3_from_json(text)
        assert _dump(a3) == _dump(a3_back)

    def test_full(self):
        a3 = create_a3(
            "MAEPRQFVHILTW",
            site={
                "catalytic": {"index": [1, 5, 10], "type": "activeSite"},
                "binding": {"index": [3, 7], "type": ""},
            },
            region={
                "domain_A": {"index": [[1, 6]], "type": "domain"},
                "domain_B": {"index": [[8, 13]], "type": "domain"},
            },
            ptm={
                "phospho": {"index": [2, 4, 6], "type": "phosphorylation"},
            },
            processing={
                "signal": {"index": [[1, 3]], "type": "signalPeptide"},
            },
            variant=[
                {"position": 5, "from": "R", "to": "Q", "source": "ClinVar"},
                {"position": 10, "from": "L", "to": "P"},
            ],
            metadata={
                "uniprot_id": "P10636",
                "description": "Microtubule-associated protein tau",
                "reference": "PMID:12345",
                "organism": "Homo sapiens",
            },
        )
        text = a3_to_json(a3, indent=2)
        a3_back = a3_from_json(text)
        assert _dump(a3) == _dump(a3_back)

    def test_empty_annotations(self):
        a3 = create_a3("MAEPRQ")
        text = a3_to_json(a3)
        data = json.loads(text)
        # All families present even when empty
        assert data["annotations"]["site"] == {}
        assert data["annotations"]["region"] == {}
        assert data["annotations"]["ptm"] == {}
        assert data["annotations"]["processing"] == {}
        assert data["annotations"]["variant"] == []

    def test_variant_extras_preserved(self):
        a3 = create_a3(
            "MAEPRQ",
            variant=[
                {
                    "position": 3,
                    "from": "E",
                    "to": "D",
                    "clinical_significance": "pathogenic",
                    "rs_id": "rs12345",
                }
            ],
        )
        text = a3_to_json(a3)
        data = json.loads(text)
        variant = data["annotations"]["variant"][0]
        assert variant["position"] == 3
        assert variant["from"] == "E"
        assert variant["to"] == "D"
        assert variant["clinical_significance"] == "pathogenic"
        assert variant["rs_id"] == "rs12345"

    def test_type_empty_string_preserved(self):
        a3 = create_a3(
            "MAEPRQ",
            site={"test": {"index": [1], "type": ""}},
        )
        text = a3_to_json(a3)
        data = json.loads(text)
        assert data["annotations"]["site"]["test"]["type"] == ""

    def test_lowercase_sequence_normalized(self):
        a3 = create_a3("maeprq")
        text = a3_to_json(a3)
        data = json.loads(text)
        assert data["sequence"] == "MAEPRQ"
        a3_back = a3_from_json(text)
        assert a3_back.sequence == "MAEPRQ"

    def test_unsorted_positions_normalized(self):
        a3 = create_a3(
            "MAEPRQ",
            site={"test": {"index": [5, 1, 3], "type": ""}},
        )
        text = a3_to_json(a3)
        data = json.loads(text)
        assert data["annotations"]["site"]["test"]["index"] == [1, 3, 5]

    def test_unsorted_ranges_normalized(self):
        a3 = create_a3(
            "MAEPRQFVHILTW",
            region={"test": {"index": [[8, 13], [1, 6]], "type": ""}},
        )
        text = a3_to_json(a3)
        data = json.loads(text)
        assert data["annotations"]["region"]["test"]["index"] == [[1, 6], [8, 13]]

    def test_ptm_with_ranges_roundtrip(self):
        a3 = create_a3(
            "MAEPRQFVHI",
            ptm={"glyco": {"index": [[1, 3], [5, 8]], "type": "glycosylation"}},
        )
        text = a3_to_json(a3)
        a3_back = a3_from_json(text)
        assert _dump(a3) == _dump(a3_back)

    def test_metadata_defaults_roundtrip(self):
        a3 = create_a3("MAEPRQ")
        text = a3_to_json(a3)
        data = json.loads(text)
        assert data["metadata"]["uniprot_id"] == ""
        assert data["metadata"]["description"] == ""
        assert data["metadata"]["reference"] == ""
        assert data["metadata"]["organism"] == ""


def _dump(a3):
    """Helper to get comparable dict from A3."""
    return a3.model_dump(mode="json")
