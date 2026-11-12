"""Checks the A3 JSON Schema against the conformance corpus.

Validates every case in `spec/conformance/manifest.json` against
`schema/a3.schema.json` with a JSON Schema draft 2020-12 validator and exits
non-zero unless:

- the schema is a valid draft 2020-12 schema;
- every valid case conforms to the schema;
- an invalid case conforms to the schema exactly when every issue it expects
  has a code in `CROSS_FIELD_CODES`, the rules that relate one value to
  another and that JSON Schema does not express.

Usage, from the repository root:

    uv run --no-project --with jsonschema python schema/check_corpus.py
"""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "schema" / "a3.schema.json"
CORPUS = ROOT / "spec" / "conformance"

# Rules that compare two values in one document: a range's endpoints, two
# ranges in one index, an index against the sequence length, and a variant's
# `from` residue against the sequence. `spec/README.md`, "Scope of validation".
CROSS_FIELD_CODES = frozenset(
    {
        "A3E_RANGE_ORDER",
        "A3E_RANGE_OVERLAP",
        "A3E_POS_OUT_OF_BOUNDS",
        "A3E_RANGE_OUT_OF_BOUNDS",
        "A3E_VARIANT_OUT_OF_BOUNDS",
        "A3E_VARIANT_RESIDUE_MISMATCH",
    }
)


def main() -> int:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    manifest = json.loads((CORPUS / "manifest.json").read_text(encoding="utf-8"))

    failures = []
    accepted_invalid = []
    for case in manifest["cases"]:
        document = json.loads((CORPUS / case["file"]).read_text(encoding="utf-8"))
        errors = list(validator.iter_errors(document))
        if case["valid"]:
            if errors:
                failures.append(
                    f"{case['file']}: valid case rejected by the schema: "
                    f"{errors[0].message}"
                )
            continue
        codes = {issue["code"] for issue in case["issues"]}
        cross_field_only = codes <= CROSS_FIELD_CODES
        if cross_field_only and errors:
            failures.append(
                f"{case['file']}: expects only cross-field issues "
                f"({', '.join(sorted(codes))}) but the schema rejects it: "
                f"{errors[0].message}"
            )
        elif not cross_field_only and not errors:
            failures.append(
                f"{case['file']}: the schema accepts a case that breaks "
                f"{', '.join(sorted(codes - CROSS_FIELD_CODES))}"
            )
        if not errors:
            accepted_invalid.append(case["file"])

    n_valid = sum(case["valid"] for case in manifest["cases"])
    n_invalid = len(manifest["cases"]) - n_valid
    print(
        f"{n_valid} valid cases, {n_invalid} invalid cases; the schema accepts "
        f"{len(accepted_invalid)} invalid cases, each breaking only "
        "cross-field rules:"
    )
    for name in accepted_invalid:
        print(f"  {name}")
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
