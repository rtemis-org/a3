# %% A3Sequence ----
test_that("A3Sequence succeeds with valid data", {
  x <- A3Sequence(data = "MKTAYIAKQRQISFVKSHFSRQDILDLWIYHTQGYFPDWQNYTPG")
  expect_s7_class(x, A3Sequence)
})

test_that("A3Sequence fails with invalid data", {
  expect_error(
    A3Sequence(data = c("SRQ", "MKTA")),
    "Sequence must be a single string"
  )
  expect_error(
    A3Sequence(data = "M"),
    "Sequence must be at least 2 characters long"
  )
})


# %% test A3Index ----
test_that("A3Index succeeds with valid data", {
  x <- A3Index(data = c(3L, 5L, 7L))
  expect_s7_class(x, A3Index)
})

test_that("A3Index fails with invalid data", {
  expect_error(A3Index(data = c(1L, 2.5)))
})


# %% A3Position ----
test_that("A3Position succeeds with valid data +/- type", {
  x <- A3Position(data = c(3L, 5L, 7L))
  expect_s7_class(x, A3Position)
  x <- A3Position(data = c(3L, 5L, 7L), type = "phosphorylation")
  expect_s7_class(x, A3Position)
})

test_that("A3Position fails with invalid data", {
  expect_error(
    A3Position(data = c(0L, 5L, 7L)),
    "Position data must be a positive integer."
  )
  expect_error(
    A3Position(data = c(-1L, 5L, 7L)),
    "Position data must be a positive integer."
  )
  expect_error(
    A3Position(data = c(1.5, 5L, 7L)),
    "object properties are invalid"
  )
  expect_error(
    A3Position(data = c(1.5, 5L, 7L), type = 99L),
    "object properties are invalid"
  )
})


# %% A3Range ----
test_that("A3Range succeeds with valid data", {
  x <- A3Range(data = matrix(c(1L, 5L, 10L, 15L), ncol = 2))
  expect_s7_class(x, A3Range)
  x <- A3Range(
    data = matrix(c(1L, 5L, 10L, 15L), ncol = 2),
    type = "Phosphodegron"
  )
  expect_s7_class(x, A3Range)
  x <- A3Range(data = matrix(c(1L, 5L), ncol = 2))
  expect_s7_class(x, A3Range)
})

test_that("A3Range fails with invalid data", {
  expect_error(
    A3Range(data = matrix(c(0L, 5L, 10L, 15L), ncol = 2)),
    "Range values must be positive integers."
  )
  expect_error(
    A3Range(data = matrix(c(1.5, 5L, 10L, 15L), ncol = 2)),
    "object properties are invalid"
  )
  expect_error(
    A3Range(data = matrix(c(5L, 10L, 1L, 15L), ncol = 2)),
    "Start of range must be less than end of range."
  )
  expect_error(
    A3Range(data = matrix(c(0L, 5L, 10L, 15L), ncol = 2)),
    "Range values must be positive integers."
  )
})

# %% A3Feature ----
test_that("A3Feature succeeds with valid type", {
  x <- A3Feature(type = "phosphorylation")
  expect_s7_class(x, A3Feature)
})

test_that("A3Feature fails with invalid type", {
  expect_error(
    A3Feature(type = 1L),
    "object properties are invalid"
  )
})


# %% A3Site ----
test_that("A3Site succeeds with valid index and optional type", {
  x <- A3Site(index = A3Position(data = c(3L, 5L, 7L)))
  expect_s7_class(x, A3Site)
  x <- A3Site(
    index = A3Position(data = c(3L, 5L, 7L)),
    type = "phosphorylation"
  )
  expect_s7_class(x, A3Site)
})

test_that("A3Site fails with invalid index or type", {
  expect_error(
    A3Site(index = A3Position(data = c(0L, 5L, 7L))),
    "Position data must be a positive integer."
  )
  expect_error(
    A3Site(index = A3Position(data = c(1.5, 5L, 7L))),
    "object properties are invalid"
  )
  expect_error(
    A3Site(index = A3Position(data = c(1.5, 5L, 7L)), type = 99L),
    "object properties are invalid"
  )
})


# %% A3Region ----
test_that("A3Region succeeds with valid index and optional type", {
  x <- A3Region(index = A3Range(data = matrix(c(1L, 10L, 5L, 12L), ncol = 2)))
  expect_s7_class(x, A3Region)
  x <- A3Region(
    index = A3Range(data = matrix(c(1L, 10L, 5L, 12L), ncol = 2)),
    type = "Phosphodegron"
  )
  expect_s7_class(x, A3Region)
})

test_that("A3Region fails with invalid index or type", {
  expect_error(
    A3Region(index = A3Range(data = matrix(c(0L, 10L, 5L, 12L), ncol = 2))),
    "Range values must be positive integers"
  )
  expect_error(
    A3Region(index = A3Range(data = matrix(c(1.5, 10L, 5L, 12L), ncol = 2))),
    "object properties are invalid"
  )
  expect_error(
    A3Region(index = A3Range(data = matrix(c(5L, 10L, 1L, 12L), ncol = 2))),
    "Start of range must be less than end of range"
  )
  expect_error(
    A3Region(
      index = A3Range(data = matrix(c(1L, 10L, 5L, 12L), ncol = 2)),
      type = 99L
    ),
    "object properties are invalid"
  )
})


# %% A3PTM ----
test_that("A3PTM succeeds with valid index and optional type", {
  x <- A3PTM(index = A3Position(data = c(3L, 5L, 7L)))
  expect_s7_class(x, A3PTM)
  x <- A3PTM(
    index = A3Range(data = matrix(c(3L, 10L, 7L, 12L), ncol = 2)),
    type = "phosphorylation"
  )
  expect_s7_class(x, A3PTM)
})

test_that("A3PTM fails with invalid index or type", {
  expect_error(
    A3PTM(index = A3Position(data = c(0L, 5L, 7L))),
    "Position data must be a positive integer."
  )
  expect_error(
    A3PTM(index = A3Position(data = c(1.5, 5L, 7L))),
    "object properties are invalid"
  )
  expect_error(
    A3PTM(index = A3Position(data = c(1.5, 5L, 7L)), type = 99L),
    "object properties are invalid"
  )
})

# %% A3Processing ----
test_that("A3Processing succeeds with valid index and optional type", {
  x <- A3Processing(index = A3Position(data = c(3L, 5L, 7L)))
  expect_s7_class(x, A3Processing)
  x <- A3Processing(
    index = A3Range(data = matrix(c(3L, 10L, 7L, 12L), ncol = 2)),
    type = "signal peptide"
  )
  expect_s7_class(x, A3Processing)
})

test_that("A3Processing fails with invalid index or type", {
  expect_error(
    A3Processing(index = A3Position(data = c(0L, 5L, 7L))),
    "Position data must be a positive integer."
  )
  expect_error(
    A3Processing(index = A3Position(data = c(1.5, 5L, 7L))),
    "object properties are invalid"
  )
  expect_error(
    A3Processing(index = A3Position(data = c(1.5, 5L, 7L)), type = 99L),
    "object properties are invalid"
  )
})


# %% A3Variant ----
test_that("A3Variant succeeds with valid position and info", {
  x <- A3Variant(
    position = A3Position(data = c(3L)),
    info = list(field_a = "alpha", field_b = 123L)
  )
  expect_s7_class(x, A3Variant)
})

test_that("A3Variant fails with invalid position or info", {
  expect_error(
    A3Variant(
      position = A3Position(data = c(1L, 3L)),
      info = list(field_a = "alpha")
    ),
    "Variant position must be a single integer."
  )
})

# %% A3Annotation ----
test_that("A3Annotation succeeds with valid annotations", {
  x <- A3Annotation(
    site = list(A3Site(index = A3Position(data = c(3L, 5L))))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    ))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(A3PTM(index = A3Position(data = c(7L))))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(A3PTM(index = A3Position(data = c(7L)))),
    processing = list(A3Processing(
      index = A3Range(data = matrix(c(20L, 30L), ncol = 2))
    ))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(A3PTM(index = A3Position(data = c(7L)))),
    processing = list(A3Processing(
      index = A3Range(data = matrix(c(20L, 30L), ncol = 2))
    )),
    variant = list(A3Variant(
      position = A3Position(data = c(15L)),
      info = list(mutation = "R15H")
    ))
  )
  expect_s7_class(x, A3Annotation)
})

test_that("A3Annotation fails with invalid data", {
  expect_error(
    A3Annotation(
      site = list("not_a_site"),
      region = list(),
      ptm = list(),
      processing = list(),
      variant = list()
    ),
    "All site annotations must be A3Site objects."
  )
  expect_error(
    A3Annotation(
      site = list(),
      region = list("not_a_region"),
      ptm = list(),
      processing = list(),
      variant = list()
    ),
    "All region annotations must be A3Region objects."
  )
  expect_error(
    A3Annotation(
      site = list(),
      region = list(),
      ptm = list("not_a_ptm"),
      processing = list(),
      variant = list()
    ),
    "All PTM annotations must be A3PTM objects."
  )
  expect_error(
    A3Annotation(
      site = list(),
      region = list(),
      ptm = list(),
      processing = list("not_processing"),
      variant = list()
    ),
    "All processing annotations must be A3Processing objects."
  )
  expect_error(
    A3Annotation(
      site = list(),
      region = list(),
      ptm = list(),
      processing = list(),
      variant = list("not_a_variant")
    ),
    "All variant annotations must be A3Variant objects."
  )
})


# %% Metadata ----
test_that("Metadata can be instantiated", {
  x <- Metadata()
  expect_s7_class(x, Metadata)
})


# %% A3Metadata ----
test_that("A3Metadata can be instantiated", {
  x <- A3Metadata()
  expect_s7_class(x, A3Metadata)
  expect_identical(x@uniprot_id, "")
  expect_identical(x@description, "")
  expect_identical(x@reference, "")
  expect_identical(x@organism, "")
})

test_that("A3Metadata fails with invalid data", {
  expect_error(
    A3Metadata(uniprot_id = 123L),
    "object properties are invalid"
  )
  expect_error(
    A3Metadata(description = 123L),
    "object properties are invalid"
  )
  expect_error(
    A3Metadata(reference = 123L),
    "object properties are invalid"
  )
  expect_error(
    A3Metadata(organism = 123L),
    "object properties are invalid"
  )
})


# %% A3 ----
test_that("A3 can be instantiated with valid sequence and annotations", {
  x <- A3(
    sequence = A3Sequence(data = "MKTAYIAKQRQISFVK"),
    annotations = A3Annotation(
      site = list(A3Site(index = A3Position(data = c(3L, 5L)))),
      region = list(A3Region(
        index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
      )),
      ptm = list(A3PTM(index = A3Position(data = c(7L)))),
      processing = list(A3Processing(
        index = A3Range(data = matrix(c(8L, 12L), ncol = 2))
      )),
      variant = list(A3Variant(
        position = A3Position(data = c(15L)),
        info = list(mutation = "R15H")
      ))
    )
  )
  expect_s7_class(x, A3)
})

test_that("A3 fails with invalid sequence or annotations", {
  expect_error(
    A3(
      sequence = "not_a_sequence",
      annotations = A3Annotation()
    ),
    "object properties are invalid"
  )
  expect_error(
    A3(
      sequence = A3Sequence(data = "MKTAYIAKQRQISFVK"),
      annotations = "not_annotations"
    ),
    "object properties are invalid"
  )
})
