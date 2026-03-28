# PDB Structural Annotations

This document defines how PDB structural data maps to A3 annotation families
and records implementation decisions specific to the A3 schema.

For full API documentation see:
- PDBe Graph API: https://www.ebi.ac.uk/pdbe/graph-api
- PDBe REST API: https://www.ebi.ac.uk/pdbe/api/doc

---

## APIs Used

| Purpose | Endpoint |
| --- | --- |
| Structure selection + SIFTS residue mapping | `GET https://www.ebi.ac.uk/pdbe/graph-api/mappings/best_structures/{UniProtAccession}` |
| Secondary structure | `GET https://www.ebi.ac.uk/pdbe/api/pdb/entry/secondary_structure/{pdb_id}` |
| Ligand binding sites | `GET https://www.ebi.ac.uk/pdbe/api/pdb/entry/binding_sites/{pdb_id}` |

PDB IDs must be **lowercase** for the REST API entry endpoints.

---

## Coordinate Conversion (PDB → UniProt)

The `best_structures` response provides per-segment mappings with fields
`start`, `end` (PDB author residue numbers) and `unp_start`, `unp_end`
(UniProt positions).

```
uniprot_pos = pdb_author_pos - start + unp_start
```

Apply the formula for the segment whose `[start, end]` range contains the
position. Positions outside all segments are unmapped and should be discarded.

**Important:** the coordinate fields in `best_structures` are named `start`
and `end`, not `pdb_start` / `pdb_end`.

---

## Mapping to A3 Annotation Families

### `region` — secondary structure

| PDB SS type | A3 type |
| --- | --- |
| Helix | `helix` |
| Strand | `betaStrand` |
| Turn | `turn` |

Each element maps to one `A3Region` with an `A3Range` index. Use
`author_residue_number` (not `residue_number`) from the SS response for
coordinate conversion. Discard elements where either endpoint is unmapped
or where `uniprot_start >= uniprot_end` after conversion.

### `site` — binding sites

Each ligand binding site maps to one `A3Site` with type `"bindingSite"`.
The `A3Position` index holds all contacting UniProt residue positions for
that site (multiple positions per site are valid).

Keep only residues where `symmetry_symbol == "1_555"` (exclude crystal
contacts) and whose `chain_id` is one of the chains mapped to the target
UniProt accession. Discard sites with no residues surviving these filters.

### Not mapped

- Turns are included when present but are often absent or empty.
- Disulfide bonds and other PTM-level structural features come from UniProt,
  not PDB (see `specs/uniprot.md`).

---

## Deprecated Endpoints (as of 2026)

These return HTTP 404 and must not be used:

| Broken | Replacement |
| --- | --- |
| `…/pdbe/api/mappings/uniprot/{UniProtAccession}` | `…/pdbe/graph-api/mappings/best_structures/{UniProtAccession}` |
| `…/pdbe/graph-api/uniprot/uniprot_segments/{UniProtAccession}` | same as above |
