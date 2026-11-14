# %% Annotation entries ----
test_that("A3Site holds a position index and a type", {
  x <- A3Site(index = c(5L, 3L), type = "activeSite")
  expect_s7_class(x, A3Site)
  expect_identical(x@index, c(5L, 3L))
  expect_identical(A3Site(index = integer())@type, "")
  expect_error(A3Site(index = c(0L, 5L)), ">= 1")
  expect_error(A3Site(index = c(3L, 3L)), "distinct")
  expect_error(A3Site(index = c(1.5, 5)))
  expect_error(A3Site(index = 3L, type = 99L))
})

test_that("A3Region holds a range index with ordered, disjoint ranges", {
  x <- A3Region(index = rbind(c(10L, 12L), c(1L, 5L)))
  expect_identical(nrow(x@index), 2L)
  expect_s7_class(A3Region(index = rbind(c(1L, 5L), c(6L, 10L))), A3Region)
  expect_s7_class(A3Region(index = matrix(integer(), ncol = 2L)), A3Region)
  expect_error(A3Region(index = rbind(c(5L, 1L))), "start < end")
  expect_error(A3Region(index = rbind(c(1L, 5L), c(3L, 8L))), "overlap")
  expect_error(A3Region(index = rbind(c(0L, 5L))))
  expect_error(A3Region(index = c(1L, 5L)))
})

test_that("A3PTM and A3Processing hold positions or ranges", {
  expect_s7_class(A3PTM(index = c(3L, 7L)), A3PTM)
  expect_s7_class(A3PTM(index = rbind(c(3L, 7L), c(10L, 12L))), A3PTM)
  expect_s7_class(A3Processing(index = 1L), A3Processing)
  expect_s7_class(A3Processing(index = rbind(c(1L, 20L))), A3Processing)
  expect_error(A3PTM(index = c(0L, 5L)))
  expect_error(A3Processing(index = rbind(c(9L, 3L))), "start < end")
  expect_error(A3PTM(index = "a"))
})


# %% A3Annotations ----
test_that("A3Annotations holds named entries and variant records", {
  x <- A3Annotations(
    site = list(activeSite = A3Site(index = c(3L, 5L))),
    region = list(KXGS = A3Region(index = rbind(c(1L, 10L)))),
    ptm = list(Phosphorylation = A3PTM(index = 7L)),
    processing = list(`Signal peptide` = A3Processing(index = rbind(c(8L, 12L)))),
    variant = list(list(position = 15L, mutation = "R15H"))
  )
  expect_s7_class(x, A3Annotations)
  expect_identical(x@variant[[1L]][["mutation"]], "R15H")
  expect_identical(A3Annotations()@site, list())
})

test_that("A3Annotations rejects entries of the wrong class or without names", {
  expect_error(
    A3Annotations(site = list(a = A3Region(index = rbind(c(1L, 3L)))))
  )
  expect_error(A3Annotations(site = list(A3Site(index = 3L))), "named")
  expect_error(A3Annotations(variant = list(list(from = "R"))), "position")
  expect_error(A3Annotations(variant = list(list(position = 0L))), ">= 1")
})


# %% A3Metadata ----
test_that("A3Metadata defaults every member to the empty string", {
  x <- A3Metadata()
  expect_s7_class(x, A3Metadata)
  expect_identical(x@uniprot_id, "")
  expect_identical(x@description, "")
  expect_identical(x@reference, "")
  expect_identical(x@organism, "")
  expect_error(A3Metadata(uniprot_id = 123L))
  expect_error(A3Metadata(organism = c("Homo sapiens", "Mus musculus")))
})


# %% A3 ----
test_that("A3 holds a sequence, annotations, and metadata", {
  x <- A3(
    sequence = "mktayiakqrqisfvk",
    annotations = A3Annotations(
      site = list(activeSite = A3Site(index = c(3L, 5L))),
      variant = list(list(position = 15L, from = "V"))
    )
  )
  expect_s7_class(x, A3)
  expect_identical(x@sequence, "MKTAYIAKQRQISFVK")
  expect_identical(x[["sequence"]], "MKTAYIAKQRQISFVK")
  expect_identical(x$metadata[["uniprot_id"]], "")
})

test_that("A3 rejects an invalid sequence or annotations", {
  expect_error(A3(sequence = "M"))
  expect_error(A3(sequence = "MK1"), "pattern")
  expect_error(A3(sequence = "MKTAY", annotations = "not_annotations"))
})

test_that("A3 compares indices and variants with the sequence", {
  ann <- function(...) A3Annotations(...)
  expect_error(
    A3("MKTAY", ann(site = list(s = A3Site(index = 6L)))),
    "sequence length"
  )
  expect_error(
    A3("MKTAY", ann(region = list(r = A3Region(index = rbind(c(2L, 9L)))))),
    "sequence length"
  )
  expect_error(
    A3("MKTAY", ann(variant = list(list(position = 9L)))),
    "sequence length"
  )
  expect_error(
    A3("MKTAY", ann(variant = list(list(position = 2L, from = "R")))),
    "differs from residue 2"
  )
  expect_s7_class(
    A3("MKTAY", ann(variant = list(list(position = 2L, from = "k")))),
    A3
  )
  expect_s7_class(
    A3("MKTAY", ann(variant = list(list(position = 2L, from = "Lys")))),
    A3
  )
})


# %% Helpers ----
test_that("annotation_position sorts and checks positions", {
  x <- annotation_position(c(7, 3), type = "phospho")
  expect_identical(x, list(index = c(3L, 7L), type = "phospho"))
  expect_identical(annotation_position(2L)[["type"]], "")
  expect_error(annotation_position(c(0, 3)), ">= 1")
  expect_error(annotation_position(c(3, 3)), "unique")
  expect_error(annotation_position(1.5))
})

test_that("annotation_range sorts and checks ranges", {
  x <- annotation_range(rbind(c(15, 22), c(3, 10)), type = "repeat")
  expect_identical(x[["index"]], rbind(c(3L, 10L), c(15L, 22L)))
  expect_error(annotation_range(c(1L, 5L)), "2 columns")
  expect_error(annotation_range(rbind(c(5L, 1L))), "start < end")
  expect_error(annotation_range(rbind(c(1L, 5L), c(3L, 8L))), "overlap")
})

test_that("annotation_variant returns a flat record with position first", {
  x <- annotation_variant(10, info = list(from = "A", to = "T"))
  expect_identical(x, list(position = 10L, from = "A", to = "T"))
  expect_identical(annotation_variant(3L), list(position = 3L))
  expect_error(annotation_variant(0L), ">= 1")
  expect_error(annotation_variant(c(1L, 2L)), "single integer")
  expect_error(annotation_variant(5L, info = list(position = 9L)), "position")
  expect_error(annotation_variant(5L, info = list("x")), "name")
})


# %% create_A3 ----
.example_A3 <- function() {
  create_A3(
    sequence = "MKTAYIAKQRQISFVK",
    site = list(`Active site` = annotation_position(c(3, 5), type = "activeSite")),
    region = list(KXGS = annotation_range(rbind(c(1L, 10L)))),
    ptm = list(Phosphorylation = annotation_position(c(7))),
    processing = list(`Signal peptide` = annotation_range(rbind(c(8L, 12L)))),
    variant = list(
      annotation_variant(15, info = list(from = "V", to = "H", note = NULL))
    ),
    uniprot_id = "P12345",
    description = "Example protein",
    reference = "PMID:12345678",
    organism = "Homo sapiens"
  )
}

test_that("create_A3 builds an A3 object from helper values", {
  x <- .example_A3()
  expect_s7_class(x, A3)
  expect_s7_class(x@annotations@site[["Active site"]], A3Site)
  expect_identical(x@metadata@organism, "Homo sapiens")
  expect_identical(create_A3("MKTAY")@metadata@uniprot_id, "")
})

test_that("create_A3 reports invalid inputs", {
  expect_error(create_A3(123))
  expect_error(create_A3("MKTAY", site = "x"))
  expect_error(
    create_A3("MKTAY", site = list(a = annotation_position(9L))),
    "sequence length"
  )
  expect_error(create_A3("MKTAY", uniprot_id = c("a", "b")), "uniprot_id")
})


# %% to_json / A3from_json ----
test_that("to_json writes the canonical document", {
  parsed <- jsonlite::fromJSON(to_json(.example_A3()), simplifyVector = FALSE)
  expect_identical(
    names(parsed),
    c("$schema", "a3_version", "sequence", "annotations", "metadata")
  )
  expect_identical(
    names(parsed$annotations),
    c("site", "region", "ptm", "processing", "variant")
  )
  expect_identical(names(parsed$annotations$site$`Active site`), c("index", "type"))
  expect_identical(parsed$annotations$region$KXGS$index, list(list(1L, 10L)))
  expect_identical(parsed$annotations$ptm$Phosphorylation$index, list(7L))
  expect_identical(
    parsed$annotations$variant[[1L]],
    list(position = 15L, from = "V", to = "H", note = NULL)
  )
  expect_identical(parsed$metadata$reference, "PMID:12345678")
})

test_that("to_json writes empty families as empty objects and arrays", {
  json <- to_json(create_A3("MKTAY"), pretty = FALSE)
  expect_match(json, '"site":{}', fixed = TRUE)
  expect_match(json, '"variant":[]', fixed = TRUE)
})

test_that("A3from_json round-trips to_json with zero loss", {
  original <- .example_A3()
  expect_identical(A3from_json(to_json(original)), original)
})

test_that("A3from_json rejects legacy bare-array format", {
  legacy_json <- '{
    "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
    "a3_version": "1.0.0",
    "sequence": "MKTAYIAKQRQISFVK",
    "annotations": {
      "site": {
        "Active site": [3, 5]
      },
      "region": {},
      "ptm": {},
      "processing": {},
      "variant": []
    },
    "metadata": {}
  }'
  expect_error(A3from_json(legacy_json), "index")
})

test_that("A3from_json rejects missing metadata", {
  json <- '{
    "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
    "a3_version": "1.0.0",
    "sequence": "MKTAYIAKQRQISFVK",
    "annotations": {
      "site": {},
      "region": {},
      "ptm": {},
      "processing": {},
      "variant": []
    }
  }'
  # `metadata` is optional: the schema requires only $schema, a3_version, and
  # sequence, and every member defaults to the empty string.
  x <- A3from_json(json)
  expect_s7_class(x, A3)
  expect_identical(x@metadata@uniprot_id, "")
})

test_that("A3from_json reports duplicate positions with annotation path", {
  json <- '{
    "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
    "a3_version": "1.0.0",
    "sequence": "MKTAYIAKQRQISFVK",
    "annotations": {
      "site": {},
      "region": {},
      "ptm": {
        "Phosphorylation": {
          "index": [7, 9, 7],
          "type": ""
        }
      },
      "processing": {},
      "variant": []
    },
    "metadata": {}
  }'
  issues <- tryCatch(A3from_json(json), a3_validation_error = function(e) {
    e[["issues"]]
  })
  expect_identical(
    lapply(issues, function(i) c(i[["code"]], i[["path"]])),
    list(c("A3E_POS_DUPLICATE", "/annotations/ptm/Phosphorylation/index"))
  )
})

test_that("A3from_json parses JSON text", {
  json <- '{
    "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
    "a3_version": "1.0.0",
    "sequence": "MKTAYIAKQRQISFVK",
    "annotations": {
      "site": { "Active site": { "index": [3, 5], "type": "activeSite" } }
    },
    "metadata": { "uniprot_id": "P12345" }
  }'
  x <- A3from_json(json)
  expect_s7_class(x, A3)
  expect_identical(x@annotations@site[["Active site"]]@type, "activeSite")
  expect_identical(x@metadata@uniprot_id, "P12345")
})

test_that("validate_A3json returns issues instead of throwing", {
  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{
      "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
      "a3_version": "1.0.0",
      "sequence": "MKTAY",
      "annotations": { "site": { "s": { "index": [99] } } }
    }',
    tmp
  )
  on.exit(unlink(tmp))

  issues <- validate_A3json(tmp)
  expect_s3_class(issues, "data.frame")
  expect_identical(nrow(issues), 1L)
  expect_identical(issues[["code"]], "A3E_POS_OUT_OF_BOUNDS")
  expect_identical(issues[["path"]], "/annotations/site/s/index/0")
  expect_identical(issues[["stage"]], 4L)

  # And zero rows for a valid document.
  valid <- tempfile(fileext = ".json")
  on.exit(unlink(valid), add = TRUE)
  write_A3json(create_A3("MKTAY"), valid)
  expect_identical(nrow(validate_A3json(valid)), 0L)
})

test_that("read_A3json aborts once with every issue in the failing stage", {
  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{
      "$schema": "https://schema.rtemis.org/a3/v1/schema.json",
      "a3_version": "1.0.0",
      "sequence": "MKTAY",
      "annotations": { "site": { "a": { "index": [99] }, "b": { "index": [98] } } }
    }',
    tmp
  )
  on.exit(unlink(tmp))

  # Collect-all: both problems are reported at once, and the issue list is
  # reachable from the condition object rather than only from the message.
  issues <- tryCatch(
    read_A3json(tmp, verbosity = 0L),
    a3_validation_error = function(e) e[["issues"]]
  )
  expect_identical(length(issues), 2L)
  expect_identical(
    vapply(issues, function(i) i[["path"]], character(1L)),
    c("/annotations/site/a/index/0", "/annotations/site/b/index/0")
  )
})

test_that("read_A3json reports valid A3 version", {
  x <- create_A3(
    sequence = "MKTAYIAKQRQISFVK",
    site = list(
      `Active site` = annotation_position(c(3, 5), type = "activeSite")
    ),
    uniprot_id = "P12345"
  )
  filepath <- tempfile(fileext = ".json")
  write_A3json(x, filepath, overwrite = TRUE)

  expect_message(
    read_A3json(filepath, verbosity = 1L),
    "valid A3 1\\.0\\.0"
  )
})

test_that("write_A3json() writes a named variant list as a JSON array", {
  a3 <- create_A3(
    "MAEPRQEFEVMEDHAGTYGLGDRK",
    variant = list(
      R5L = annotation_variant(5L, info = list(from = "R", to = "L")),
      E7K = annotation_variant(7L, info = list(from = "E", to = "K"))
    )
  )
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_A3json(a3, tmp)
  expect_identical(nrow(validate_A3json(tmp)), 0L)
  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  expect_null(names(raw[["annotations"]][["variant"]]))
  expect_length(raw[["annotations"]][["variant"]], 2L)
})
