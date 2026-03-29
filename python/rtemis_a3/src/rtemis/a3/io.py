"""File I/O for A3 JSON files."""

from __future__ import annotations

from pathlib import Path

from ._models import A3
from .api import a3_from_json, a3_to_json
from .errors import A3ParseError


def read_a3json(path: str | Path) -> A3:
    """Read an A3 JSON file from disk.

    Parameters
    ----------
    path : str or Path
        Path to the JSON file.

    Returns
    -------
    A3
        Validated, immutable A3 object.

    Raises
    ------
    A3ParseError
        If file reading or JSON parsing fails.
    A3ValidationError
        If parsed data fails validation.
    """
    filepath = Path(path)
    try:
        text = filepath.read_text(encoding="utf-8")
    except OSError as exc:
        raise A3ParseError(f"cannot read file '{filepath}': {exc}") from exc
    return a3_from_json(text)


def write_a3json(a3: A3, path: str | Path, *, indent: int | None = None) -> None:
    """Write an A3 object to a JSON file.

    Parameters
    ----------
    a3 : A3
        A3 object to write.
    path : str or Path
        Output file path.
    indent : int, optional
        JSON indentation level. ``None`` for compact output.
    """
    filepath = Path(path)
    text = a3_to_json(a3, indent=indent)
    filepath.write_text(text + "\n", encoding="utf-8")
