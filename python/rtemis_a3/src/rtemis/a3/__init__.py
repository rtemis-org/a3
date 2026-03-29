"""rtemis.a3 — Python implementation of the Amino Acid Annotation (A3) format."""

# Types (for type annotations and isinstance checks)
from ._models import A3, VariantRecord

# Functional API
from .api import a3_from_json, a3_to_json, create_a3, residue_at, variants_at

# File I/O
from .io import read_a3json, write_a3json

# Errors
from .errors import A3ParseError, A3ValidationError

__all__ = [
    "A3",
    "A3ParseError",
    "A3ValidationError",
    "VariantRecord",
    "a3_from_json",
    "a3_to_json",
    "create_a3",
    "read_a3json",
    "residue_at",
    "variants_at",
    "write_a3json",
]
