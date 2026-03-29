"""Tests for normalization helpers."""

import pytest

from rtemis.a3._normalize import (
    check_no_overlap,
    is_json_compatible,
    sort_dedup,
    sort_ranges,
)


# ---------------------------------------------------------------------------
# sort_dedup
# ---------------------------------------------------------------------------


class TestSortDedup:
    def test_empty(self):
        assert sort_dedup([]) == []

    def test_already_sorted_unique(self):
        assert sort_dedup([1, 3, 5]) == [1, 3, 5]

    def test_unsorted(self):
        assert sort_dedup([5, 1, 3]) == [1, 3, 5]

    def test_duplicates(self):
        assert sort_dedup([3, 1, 3, 5, 1]) == [1, 3, 5]

    def test_single(self):
        assert sort_dedup([42]) == [42]


# ---------------------------------------------------------------------------
# sort_ranges
# ---------------------------------------------------------------------------


class TestSortRanges:
    def test_empty(self):
        assert sort_ranges([]) == []

    def test_already_sorted(self):
        assert sort_ranges([(1, 5), (6, 10)]) == [(1, 5), (6, 10)]

    def test_unsorted(self):
        assert sort_ranges([(6, 10), (1, 5)]) == [(1, 5), (6, 10)]

    def test_tie_on_start(self):
        assert sort_ranges([(1, 10), (1, 5)]) == [(1, 5), (1, 10)]

    def test_single(self):
        assert sort_ranges([(3, 7)]) == [(3, 7)]


# ---------------------------------------------------------------------------
# check_no_overlap
# ---------------------------------------------------------------------------


class TestCheckNoOverlap:
    def test_empty(self):
        check_no_overlap([])

    def test_no_overlap(self):
        check_no_overlap([(1, 5), (6, 10)])

    def test_adjacent_permitted(self):
        check_no_overlap([(1, 5), (6, 10)])

    def test_gap(self):
        check_no_overlap([(1, 3), (7, 10)])

    def test_overlap_raises(self):
        with pytest.raises(ValueError, match="overlapping ranges"):
            check_no_overlap([(1, 5), (3, 8)])

    def test_identical_ranges_overlap(self):
        with pytest.raises(ValueError, match="overlapping ranges"):
            check_no_overlap([(1, 5), (1, 5)])

    def test_touching_at_boundary(self):
        # [1, 5] and [5, 10] overlap because 5 <= 5
        with pytest.raises(ValueError, match="overlapping ranges"):
            check_no_overlap([(1, 5), (5, 10)])


# ---------------------------------------------------------------------------
# is_json_compatible
# ---------------------------------------------------------------------------


class TestIsJsonCompatible:
    def test_none(self):
        assert is_json_compatible(None) is True

    def test_bool(self):
        assert is_json_compatible(True) is True
        assert is_json_compatible(False) is True

    def test_int(self):
        assert is_json_compatible(42) is True

    def test_float(self):
        assert is_json_compatible(3.14) is True

    def test_str(self):
        assert is_json_compatible("hello") is True

    def test_list(self):
        assert is_json_compatible([1, "two", None]) is True

    def test_dict(self):
        assert is_json_compatible({"a": 1, "b": "two"}) is True

    def test_nested(self):
        assert is_json_compatible({"a": [1, {"b": True}]}) is True

    def test_function_rejected(self):
        assert is_json_compatible(lambda: None) is False

    def test_set_rejected(self):
        assert is_json_compatible({1, 2, 3}) is False

    def test_bytes_rejected(self):
        assert is_json_compatible(b"hello") is False

    def test_class_instance_rejected(self):
        class Foo:
            pass

        assert is_json_compatible(Foo()) is False

    def test_dict_non_string_key_rejected(self):
        assert is_json_compatible({1: "value"}) is False

    def test_nested_invalid(self):
        assert is_json_compatible({"a": [1, {2, 3}]}) is False
