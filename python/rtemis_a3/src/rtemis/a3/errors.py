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
        Structured error list. Each entry has at minimum ``loc`` (tuple of
        field path components), ``msg`` (human-readable message), and
        ``type`` (error kind string). Pydantic structural errors follow
        Pydantic's native format; bounds and envelope errors follow the same
        shape for consistency.
    """

    def __init__(self, message: str, errors: list[dict[str, Any]] | None = None):
        super().__init__(message)
        self.errors: list[dict[str, Any]] = errors or []

    @property
    def messages(self) -> list[str]:
        """Individual error messages, one per violation."""
        return [e["msg"] for e in self.errors]


class A3ParseError(Exception):
    """Raised when JSON parsing or file I/O fails."""
