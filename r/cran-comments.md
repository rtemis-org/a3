# CRAN Submission Comments

## Test environments

* macOS (local): R 4.4.x, via `devtools::check()`
* R CMD check via GitHub Actions (Ubuntu, macOS, Windows)

## R CMD check results

There were no ERRORs, WARNINGs, or NOTEs.

## First submission

This is the first submission of this package to CRAN.

## Method references

There are no published references describing the methods in this package.
The package implements original functionality for creating and manipulating
the Amino Acid Annotation (A3) format.

## Suggested packages with external dependencies

Several functions in `Suggests` (biomaRt, httr, jsonlite, seqinr) are used
only for optional database-fetching utilities (`uniprot_to_A3()`,
`gene2sequence()`, `get_alphafold()`, `pdb_annotations()`,
`clinvar_variants()`). Examples for these functions are wrapped in
`\dontrun{}` because they require network access and external API availability.
