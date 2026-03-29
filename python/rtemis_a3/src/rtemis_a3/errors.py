"""A3 error classes.

Custom exceptions that wrap Pydantic validation errors with clear,
corrective messages including full field paths.
"""

from __future__ import annotations

from typing import Any


class A3ValidationError(Exception):
    """Raised when input fails A3 structural or contextual validation.

    Parameters
    ----------
    message : str
        Human-readable summary.
    errors : list[dict[str, Any]]
        Structured error list (from Pydantic's ``ValidationError.errors()``).
    """

    def __init__(self, message: str, errors: list[dict[str, Any]] | None = None):
        super().__init__(message)
        self.errors: list[dict[str, Any]] = errors or []


class A3ParseError(Exception):
    """Raised when JSON parsing or file I/O fails.

    Parameters
    ----------
    message : str
        Human-readable description of the failure.
    """
