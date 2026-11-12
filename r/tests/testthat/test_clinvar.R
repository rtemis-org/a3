# test_clinvar.R
# ::rtemis.a3::
# 2026- EDG rtemis.org

# Offline tests of the ClinVar record parsing. The fixtures follow the shapes
# of the E-utilities esummary JSON and efetch VCV XML responses.

# %% Fixtures ----
clinvar_summary <- function(
  uid = "14245",
  genes = "MAPT",
  classification = "Pathogenic",
  traits = c("Frontotemporal dementia", "not provided")
) {
  list(
    uid = uid,
    genes = lapply(genes, function(g) list(symbol = g)),
    germline_classification = list(
      description = classification,
      trait_set = lapply(traits, function(t) list(trait_name = t))
    ),
    protein_change = "P301L, P243L, P272L, P618L, P636L, P693L"
  )
}

clinvar_archive <- function(change = "P301L", protein = "NP_005901.2") {
  xml <- sprintf(
    paste0(
      "<ClinVarResult-Set>",
      "<VariationArchive VariationID=\"14245\" Accession=\"VCV000014245\" ",
      "Version=\"60\">",
      "<ClassifiedRecord><SimpleAllele><HGVSlist><HGVS>",
      "<ProteinExpression sequenceAccessionVersion=\"NP_001364194.1\" ",
      "singleLetterProteinChange=\"P693L\">",
      "<Expression>NP_001364194.1:p.Pro693Leu</Expression>",
      "</ProteinExpression>",
      "<ProteinExpression sequenceAccessionVersion=\"%s\" ",
      "singleLetterProteinChange=\"%s\">",
      "<Expression>%s:p.Pro301Leu</Expression>",
      "</ProteinExpression>",
      "</HGVS></HGVSlist></SimpleAllele>",
      "<Classifications><GermlineClassification>",
      "<ReviewStatus>criteria provided, multiple submitters, no conflicts",
      "</ReviewStatus>",
      "<Description>Pathogenic</Description>",
      "</GermlineClassification></Classifications>",
      "</ClassifiedRecord></VariationArchive></ClinVarResult-Set>"
    ),
    protein,
    change,
    protein
  )
  xml2::xml_find_first(xml2::read_xml(xml), "//VariationArchive")
}

# %% .clinvar_parse_change ----
test_that(".clinvar_parse_change() parses missense, nonsense, and deletion", {
  expect_identical(
    .clinvar_parse_change("P301L"),
    list(from = "P", position = 301L, to = "L", type = "missense")
  )
  expect_identical(.clinvar_parse_change("R5*")[["type"]], "nonsense")
  del <- .clinvar_parse_change("N279del")
  expect_identical(del[["type"]], "deletion")
  expect_true("to" %in% names(del))
  expect_null(del[["to"]])
})

test_that(".clinvar_parse_change() returns NULL for other changes", {
  expect_null(.clinvar_parse_change("Q168fs"))
  expect_null(.clinvar_parse_change("L158V, L233V"))
  expect_null(.clinvar_parse_change(""))
  expect_null(.clinvar_parse_change(NA_character_))
  expect_null(.clinvar_parse_change(NULL))
})

# %% .clinvar_keep ----
test_that(".clinvar_keep() requires the gene alone and a listed class", {
  classes <- c("Pathogenic", "Likely pathogenic")
  expect_true(.clinvar_keep(clinvar_summary(), "MAPT", classes))
  expect_false(.clinvar_keep(
    clinvar_summary(genes = c("MAPT", "KANSL1")),
    "MAPT",
    classes
  ))
  expect_false(.clinvar_keep(
    clinvar_summary(classification = "Uncertain significance"),
    "MAPT",
    classes
  ))
  expect_true(.clinvar_keep(
    clinvar_summary(classification = "Uncertain significance"),
    "MAPT",
    NULL
  ))
})

# %% .clinvar_record ----
test_that(".clinvar_record() positions the variant on the named protein", {
  skip_if_not_installed("xml2")
  rec <- .clinvar_record(clinvar_summary(), clinvar_archive(), "NP_005901.2")
  expect_identical(rec[["position"]], 301L)
  expect_identical(rec[["from"]], "P")
  expect_identical(rec[["to"]], "L")
  expect_identical(rec[["type"]], "missense")
  expect_identical(rec[["source"]], "ClinVar")
  expect_identical(rec[["id"]], "VCV000014245.60")
  expect_identical(rec[["hgvs_p"]], "NP_005901.2:p.Pro301Leu")
  expect_identical(rec[["clinical_significance"]], "Pathogenic")
  expect_identical(
    rec[["review_status"]],
    "criteria provided, multiple submitters, no conflicts"
  )
  expect_identical(
    as.vector(unclass(rec[["conditions"]])),
    "Frontotemporal dementia"
  )
})

test_that(".clinvar_record() returns NULL without a change on the protein", {
  skip_if_not_installed("xml2")
  expect_null(.clinvar_record(
    clinvar_summary(),
    clinvar_archive(),
    "NP_001123066.3"
  ))
  expect_null(.clinvar_record(
    clinvar_summary(),
    clinvar_archive(change = "Q168fs"),
    "NP_005901.2"
  ))
})

test_that("a ClinVar record round-trips through write_A3json()", {
  skip_if_not_installed("xml2")
  rec <- .clinvar_record(clinvar_summary(), clinvar_archive(), "NP_005901.2")
  seq <- paste0(strrep("A", 300L), "P", strrep("A", 140L))
  a3 <- create_A3(
    seq,
    variant = list(
      P301L = annotation_variant(
        rec[["position"]],
        info = rec[setdiff(names(rec), "position")]
      )
    )
  )
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_A3json(a3, tmp)
  expect_identical(nrow(validate_A3json(tmp)), 0L)
  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  # A single condition is written as a one-element array.
  expect_identical(
    raw[["annotations"]][["variant"]][[1L]][["conditions"]],
    list("Frontotemporal dementia")
  )
})

# %% .clinvar_unique_names ----
test_that(".clinvar_unique_names() suffixes only repeated names", {
  expect_identical(
    .clinvar_unique_names(c("P301L", "P301S", "P301L")),
    c("P301L.1", "P301S", "P301L.2")
  )
})
