# test_schema.R

# %% a3_schema ----
test_that("a3_schema() emits a draft 2020-12 schema with the A3 envelope", {
  s <- a3_schema()
  expect_identical(s[["$id"]], "https://schema.rtemis.org/a3/v1/schema.json")
  expect_identical(
    s[["$schema"]],
    "https://json-schema.org/draft/2020-12/schema"
  )
  expect_identical(
    as.vector(s[["required"]]),
    c("$schema", "a3_version", "sequence")
  )
  expect_setequal(
    names(s[["$defs"]]),
    c(
      "A3Annotations", "A3Metadata", "A3Site", "A3Region", "A3PTM",
      "A3Processing", "positionIndex", "rangeIndex", "mixedIndex",
      "variantRecord"
    )
  )
  expect_true(s[["$defs"]][["positionIndex"]][["uniqueItems"]])
  expect_no_error(assert_description_language(s))
})

test_that("every A3 class is described and A3 is published as shared data", {
  s <- a3_schema()
  classes <- c(
    "A3Annotations", "A3Metadata", "A3Site", "A3Region", "A3PTM",
    "A3Processing"
  )
  for (nm in classes) {
    expect_true(nzchar(s[["$defs"]][[nm]][["description"]]), info = nm)
  }
  expect_identical(s[["description"]], class_description(A3))
  expect_identical(
    s[["x-rtemis"]][["publication"]],
    list(
      producer = "rtemis.a3",
      language = "r",
      scope = "shared",
      domain = "domain",
      class = "rtemis.a3::A3",
      role = "document",
      kind = "data",
      order = 1L
    )
  )
})

test_that("schema/a3.schema.json equals a3_schema()", {
  committed <- testthat::test_path("..", "..", "..", "schema", "a3.schema.json")
  skip_if_not(file.exists(committed), "Runs in the A3 repository only.")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_JSONSchema(a3_schema(), tmp, verbosity = 0L)
  expect_identical(readLines(tmp), readLines(committed))
})
