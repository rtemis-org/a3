"""Pure normalization helpers for A3 validation.

These functions are used inside Pydantic validators to normalize
positions, ranges, and check JSON compatibility.
"""

from __future__ import annotations


def sort_dedup(values: list[int]) -> list[int]:
    """Deduplicate and sort ascending.

    Intended for use by a future ``clean``/``normalize`` API.
    Strict parsers should use :func:`check_no_duplicate_positions` instead.

    Parameters
    ----------
    values : list[int]
        List of integers (expected positive).

    Returns
    -------
    list[int]
        Sorted list with duplicates removed.
    """
    return sorted(set(values))


def check_no_duplicate_positions(values: list[int]) -> list[int]:
    """Sort positions ascending and raise if any value appears more than once.

    Parameters
    ----------
    values : list[int]
        List of integers (expected positive).

    Returns
    -------
    list[int]
        Sorted list, guaranteed unique.

    Raises
    ------
    ValueError
        If any position appears more than once.
    """
    sorted_v = sorted(values)
    for i in range(1, len(sorted_v)):
        if sorted_v[i] == sorted_v[i - 1]:
            raise ValueError(f"duplicate position: {sorted_v[i]}")
    return sorted_v


def sort_ranges(ranges: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """Sort ranges by start position, then end position for ties.

    Does not merge overlapping ranges — overlap detection is a separate step.

    Parameters
    ----------
    ranges : list[tuple[int, int]]
        List of (start, end) pairs.

    Returns
    -------
    list[tuple[int, int]]
        Sorted list of ranges.
    """
    return sorted(ranges, key=lambda r: (r[0], r[1]))


def check_no_overlap(ranges: list[tuple[int, int]]) -> None:
    """Validate that no two ranges overlap.

    Two ranges ``[a, b]`` and ``[c, d]`` overlap when ``c <= b`` (after
    sorting). Adjacent ranges (``c = b + 1``) are permitted.

    Parameters
    ----------
    ranges : list[tuple[int, int]]
        Sorted list of (start, end) pairs.

    Raises
    ------
    ValueError
        If any two consecutive ranges overlap.
    """
    for i in range(1, len(ranges)):
        prev_end = ranges[i - 1][1]
        curr_start = ranges[i][0]
        if curr_start <= prev_end:
            raise ValueError(
                f"overlapping ranges: [{ranges[i-1][0]}, {prev_end}] and "
                f"[{curr_start}, {ranges[i][1]}]"
            )


def is_json_compatible(value: object) -> bool:
    """Check whether a value is recursively JSON-compatible.

    Accepts: ``None``, ``bool``, ``int``, ``float``, ``str``,
    ``list``, ``dict`` (with string keys). Rejects everything else
    (functions, class instances, sets, bytes, etc.).

    Parameters
    ----------
    value : object
        Value to check.

    Returns
    -------
    bool
        ``True`` if the value is JSON-compatible.
    """
    if value is None or isinstance(value, (bool, int, float, str)):
        return True
    if isinstance(value, list):
        return all(is_json_compatible(item) for item in value)
    if isinstance(value, dict):
        return all(
            isinstance(k, str) and is_json_compatible(v) for k, v in value.items()
        )
    return False
