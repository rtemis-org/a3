# UniProt Feature Types

This document catalogs all UniProt sequence annotation (feature) types, their
geometry (single-residue site vs. residue range), and their mapping to A3
annotation families.

## UniProt JSON Feature Structure

Every feature in the UniProt REST API JSON has this shape:

```json
{
  "type": "Active site",
  "location": {
    "start": {"value": 69, "modifier": "EXACT"},
    "end": {"value": 69, "modifier": "EXACT"}
  },
  "description": "Charge relay system",
  "evidences": [{"evidenceCode": "ECO:0000269", "source": "PubMed", "id": "12819769"}]
}
```

Optional additional fields depending on feature type:

- `featureId` Stable identifier (e.g. `PRO_0000027393`, `VAR_024291`,
  `VSP_038571`).
- `alternativeSequence` Object with `originalSequence` and
  `alternativeSequences` (for variants, mutagenesis, conflicts, alternative
  sequences).
- `featureCrossReferences` Array of `{database, id}` (e.g. dbSNP links on
  natural variants).

The `modifier` field on start/end locations can be `EXACT`, `OUTSIDE`,
`UNSURE`, or `UNKNOWN`.

## Feature Types by UniProt Category

### Molecule Processing

These describe how the precursor polypeptide is processed into its mature
form(s).

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Signal peptide | `ft_signal` | Range | N-terminal signal peptide |
| Transit peptide | `ft_transit` | Range | Mitochondrial/chloroplast transit peptide |
| Propeptide | `ft_propep` | Range | Activation peptide cleaved during maturation |
| Chain | `ft_chain` | Range | Mature polypeptide chain after processing |
| Peptide | `ft_peptide` | Range | Released active peptide |
| Initiator methionine | `ft_init_met` | Site | Removed initiator methionine |

### Regions

These annotate stretches of the sequence with functional or structural
significance.

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Topological domain | `ft_topo_dom` | Range | Location relative to membrane (e.g. extracellular, cytoplasmic) |
| Transmembrane | `ft_transmem` | Range | Transmembrane helical segment |
| Intramembrane | `ft_intramem` | Range | Intramembrane segment (does not cross the membrane) |
| Domain | `ft_domain` | Range | Named protein domain (e.g. "Peptidase S1", "SH3") |
| Repeat | `ft_repeat` | Range | Named repeated structural motif |
| Zinc finger | `ft_zn_fing` | Range | Zinc finger region |
| DNA binding | `ft_dna_bind` | Range | DNA-binding region |
| Region | `ft_region` | Range | Region of interest (e.g. "Disordered", "Microtubule-binding domain") |
| Coiled coil | `ft_coiled` | Range | Coiled-coil region |
| Motif | `ft_motif` | Range | Short linear motif of biological interest |
| Compositional bias | `ft_compbias` | Range | Region of biased amino acid composition |

### Sites

These annotate individual residues with functional roles.

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Active site | `ft_act_site` | Site | Catalytic residue |
| Binding site | `ft_binding` | Site | Residue involved in substrate/ligand binding |
| Site | `ft_site` | Site | Other functionally important residue |

### Amino Acid Modifications (PTMs)

These annotate covalent modifications at specific residues.

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Modified residue | `ft_mod_res` | Site | Phosphorylation, acetylation, methylation, etc. |
| Lipidation | `ft_lipid` | Site | Lipid moiety attachment (myristoylation, palmitoylation, GPI anchor, etc.) |
| Glycosylation | `ft_carbohyd` | Site | N-linked, O-linked, or C-linked glycan attachment |
| Disulfide bond | `ft_disulfid` | Pair | Bond between two cysteine residues (start and end are the two positions) |
| Cross-link | `ft_crosslnk` | Site | Inter- or intra-chain cross-link (e.g. ubiquitin isopeptide bond) |

### Natural Variations and Experimental

These describe sequence variability and experimental observations.

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Alternative sequence | `ft_var_seq` | Range | Splice variant or alternative initiation |
| Natural variant | `ft_variant` | Site | Polymorphism, disease-associated mutation |
| Mutagenesis | `ft_mutagen` | Site | Experimentally introduced mutation and its effect |
| Sequence conflict | `ft_conflict` | Site/Range | Discrepancy between sequence reports |
| Sequence uncertainty | `ft_unsure` | Site/Range | Uncertain residue assignment |
| Non-adjacent residues | `ft_non_cons` | Site | Indicates non-consecutive residues in displayed sequence |
| Non-standard residue | `ft_non_std` | Site | Non-standard amino acid (e.g. selenocysteine) |
| Non-terminal residue | `ft_non_ter` | Site | Partial sequence that does not start/end at the true terminus |

### Secondary Structure

These are derived from experimentally determined 3D structures.

| UniProt Type | API Field | Geometry | Description |
| --- | --- | --- | --- |
| Helix | `ft_helix` | Range | Alpha helix |
| Beta strand | `ft_strand` | Range | Beta strand |
| Turn | `ft_turn` | Range | Turn |

## Mapping to A3 Annotation Families

The table below shows how each UniProt feature type maps to the A3 annotation
schema defined in `specs/a3.md`.

### `site`

Single-residue functional annotations.

| UniProt Type | A3 Type | Notes |
| --- | --- | --- |
| Active site | `activeSite` | |
| Binding site | `bindingSite` | |
| Site | `site` | General-purpose single-residue annotation |
| Non-standard residue | `nonStandardResidue` | |

### `region`

Range-based structural and functional annotations.

| UniProt Type | A3 Type | Notes |
| --- | --- | --- |
| Domain | `domain` | |
| Repeat | `repeat` | |
| Zinc finger | `zincFinger` | |
| DNA binding | `dnaBinding` | |
| Region | `region` | |
| Coiled coil | `coiledCoil` | |
| Motif | `motif` | |
| Compositional bias | `compositionalBias` | |
| Topological domain | `topologicalDomain` | |
| Transmembrane | `transmembrane` | |
| Intramembrane | `intramembrane` | |
| Helix | `helix` | Secondary structure |
| Beta strand | `betaStrand` | Secondary structure |
| Turn | `turn` | Secondary structure |

### `ptm`

Single-residue post-translational modifications.

| UniProt Type | A3 Type | Notes |
| --- | --- | --- |
| Modified residue | `modifiedResidue` | Phosphorylation, acetylation, methylation, etc. |
| Lipidation | `lipidation` | |
| Glycosylation | `glycosylation` | |
| Cross-link | `crossLink` | Isopeptide bonds, ubiquitination |
| Disulfide bond | `disulfideBond` | Pair of positions encoded as a two-element range |

### `processing`

Sequence maturation and processing events.

| UniProt Type | A3 Type | Notes |
| --- | --- | --- |
| Signal peptide | `signalPeptide` | Range |
| Transit peptide | `transitPeptide` | Range |
| Propeptide | `propeptide` | Range |
| Chain | `chain` | Range |
| Peptide | `peptide` | Range |
| Initiator methionine | `initiatorMethionine` | Site |

### `variant`

| UniProt Type | Notes |
| --- | --- |
| Natural variant | Maps directly to A3 variant objects. `position`, `from`, `to` extracted from `alternativeSequence`. Additional fields like `description`, `featureId`, `featureCrossReferences`, and `evidences` preserved as open metadata. |

### Not Mapped to A3

These UniProt features describe sequence-level discrepancies or experimental
artifacts rather than biological annotations on the canonical sequence. They
are not imported into A3 by default.

| UniProt Type | Reason |
| --- | --- |
| Alternative sequence | Describes isoform splicing, not a residue-level annotation on the canonical sequence |
| Mutagenesis | Experimental perturbation, not a natural property of the sequence |
| Sequence conflict | Data quality annotation, not a biological feature |
| Sequence uncertainty | Data quality annotation |
| Non-adjacent residues | Display artifact |
| Non-terminal residue | Sequence completeness annotation |

## UniProt REST API Access

Endpoint: `https://rest.uniprot.org/uniprotkb/{accession}.json`

The `features` array in the response contains all sequence annotations. Each
feature's `type` field uses the human-readable names listed above (e.g.
`"Active site"`, not `ACT_SITE`).

Individual feature types can also be requested as columns via the search API
using the `ft_*` field names listed in the tables above.
