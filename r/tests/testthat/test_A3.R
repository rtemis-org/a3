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
  expect_error(
    A3Sequence(data = "MK123"),
    "Sequence must only contain uppercase letters"
  )
})


# %% A3Index ----
test_that("A3Index is abstract and cannot be instantiated", {
  expect_error(A3Index(data = c(3L, 5L, 7L)))
})


# %% A3Position ----
test_that("A3Position succeeds with valid data", {
  x <- A3Position(data = c(3L, 5L, 7L))
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
})


# %% A3Range ----
test_that("A3Range succeeds with valid data", {
  # Single range
  x <- A3Range(data = matrix(c(1L, 5L), ncol = 2))
  expect_s7_class(x, A3Range)
  # Two non-overlapping ranges: [1,5] and [10,15]
  x <- A3Range(data = matrix(c(1L, 10L, 5L, 15L), ncol = 2))
  expect_s7_class(x, A3Range)
  # Adjacent ranges are permitted: [1,5] and [6,10]
  x <- A3Range(data = matrix(c(1L, 6L, 5L, 10L), ncol = 2))
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
  # Overlapping ranges: [1,5] and [3,8]
  expect_error(
    A3Range(data = matrix(c(1L, 3L, 5L, 8L), ncol = 2)),
    "must not overlap"
  )
})

# %% A3Feature ----
test_that("A3Feature is abstract and cannot be instantiated", {
  expect_error(A3Feature(type = "phosphorylation"))
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
    site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L))))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(KXGS = A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    ))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(KXGS = A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(Phosphorylation = A3PTM(index = A3Position(data = c(7L))))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(KXGS = A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(Phosphorylation = A3PTM(index = A3Position(data = c(7L)))),
    processing = list(`Signal peptide` = A3Processing(
      index = A3Range(data = matrix(c(20L, 30L), ncol = 2))
    ))
  )
  expect_s7_class(x, A3Annotation)
  x <- A3Annotation(
    site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L)))),
    region = list(KXGS = A3Region(
      index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
    )),
    ptm = list(Phosphorylation = A3PTM(index = A3Position(data = c(7L)))),
    processing = list(`Signal peptide` = A3Processing(
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
  expect_error(
    A3Annotation(
      site = list(A3Site(index = A3Position(data = c(3L, 5L))))
    ),
    "All site annotation names must be non-empty strings."
  )
  expect_error(
    A3Annotation(
      site = setNames(
        list(A3Site(index = A3Position(data = c(3L, 5L)))),
        ""
      )
    ),
    "All site annotation names must be non-empty strings."
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
  expect_error(
    A3Metadata(uniprot_id = c("P10636", "Q9Y3Q8")),
    "uniprot_id.*character\\(1\\)"
  )
  expect_error(
    A3Metadata(organism = c("Homo sapiens", "Mus musculus")),
    "organism.*character\\(1\\)"
  )
})


# %% A3 ----
test_that("A3 can be instantiated with valid sequence and annotations", {
  x <- A3(
    sequence = A3Sequence(data = "MKTAYIAKQRQISFVK"),
    annotations = A3Annotation(
      site = list(activeSite = A3Site(index = A3Position(data = c(3L, 5L)))),
      region = list(KXGS = A3Region(
        index = A3Range(data = matrix(c(1L, 10L), ncol = 2))
      )),
      ptm = list(Phosphorylation = A3PTM(index = A3Position(data = c(7L)))),
      processing = list(`Signal peptide` = A3Processing(
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


# %% create_A3 ----
test_that("create_A3 succeeds with valid inputs", {
  x <- create_A3(
    sequence = "MKTAYIAKQRQISFVK",
    site = list(
      `N-terminal repeat` = annotation_position(
        c(3, 5)
      )
    ),
    region = list(
      Phosphodegron = annotation_range(
        matrix(c(1, 10), ncol = 2),
        type = "functional region"
      )
    ),
    ptm = list(
      Phosphorylation = annotation_position(
        c(7)
      )
    ),
    processing = list(
      `Signal peptide` = annotation_range(
        matrix(c(8, 12), ncol = 2)
      )
    ),
    variant = list(
      zdorg = annotation_variant(
        15,
        info = list(mutation = "R15H")
      )
    ),
    uniprot_id = "P12345",
    description = "Example protein",
    reference = "PMID:12345678",
    organism = "Homo sapiens"
  )
  expect_s7_class(x, A3)
})


# %% to_json / A3from_json ----
test_that("to_json produces valid JSON with canonical structure", {
  x <- create_A3(
    sequence = "MKTAYIAKQRQISFVK",
    site = list(
      `Active site` = annotation_position(c(3, 5), type = "activeSite")
    ),
    region = list(
      KXGS = annotation_range(matrix(c(1L, 10L), ncol = 2))
    ),
    ptm = list(
      Phosphorylation = annotation_position(c(7))
    ),
    processing = list(
      `Signal peptide` = annotation_range(matrix(c(8L, 12L), ncol = 2))
    ),
    variant = list(
      annotation_variant(15, info = list(from = "R", to = "H"))
    ),
    uniprot_id = "P12345",
    description = "Example protein",
    organism = "Homo sapiens"
  )
  json <- to_json(x)
  expect_type(json, "character")
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(parsed$sequence, "MKTAYIAKQRQISFVK")
  expect_equal(parsed$annotations$site$`Active site`$type, "activeSite")
  expect_equal(parsed$annotations$region$KXGS$index, list(list(1L, 10L)))
  expect_equal(parsed$metadata$uniprot_id, "P12345")
  expect_equal(parsed$metadata$organism, "Homo sapiens")
  expect_equal(parsed$metadata$reference, "")
})

test_that("A3from_json round-trips to_json with zero loss", {
  original <- create_A3(
    sequence = "MKTAYIAKQRQISFVK",
    site = list(
      `Active site` = annotation_position(c(3, 5), type = "activeSite")
    ),
    region = list(
      KXGS = annotation_range(matrix(c(1L, 10L), ncol = 2))
    ),
    ptm = list(
      Phosphorylation = annotation_position(c(7))
    ),
    processing = list(
      `Signal peptide` = annotation_range(matrix(c(8L, 12L), ncol = 2))
    ),
    variant = list(
      annotation_variant(15, info = list(from = "R", to = "H"))
    ),
    uniprot_id = "P12345",
    description = "Example protein",
    reference = "PMID:12345678",
    organism = "Homo sapiens"
  )

  restored <- A3from_json(to_json(original))

  # Sequence
  expect_identical(restored@sequence@data, original@sequence@data)

  # Site annotations
  expect_identical(
    names(restored@annotations@site),
    names(original@annotations@site)
  )
  expect_identical(
    restored@annotations@site[[1]]@index@data,
    original@annotations@site[[1]]@index@data
  )
  expect_identical(
    restored@annotations@site[[1]]@type,
    original@annotations@site[[1]]@type
  )

  # Region annotations
  expect_identical(
    names(restored@annotations@region),
    names(original@annotations@region)
  )
  expect_identical(
    restored@annotations@region[[1]]@index@data,
    original@annotations@region[[1]]@index@data
  )

  # PTM annotations
  expect_identical(
    restored@annotations@ptm[[1]]@index@data,
    original@annotations@ptm[[1]]@index@data
  )

  # Processing annotations
  expect_identical(
    restored@annotations@processing[[1]]@index@data,
    original@annotations@processing[[1]]@index@data
  )

  # Variant annotations
  expect_identical(
    restored@annotations@variant[[1]]@position@data,
    original@annotations@variant[[1]]@position@data
  )
  expect_identical(
    restored@annotations@variant[[1]]@info$from,
    original@annotations@variant[[1]]@info$from
  )

  # Metadata
  expect_identical(restored@metadata@uniprot_id, original@metadata@uniprot_id)
  expect_identical(restored@metadata@description, original@metadata@description)
  expect_identical(restored@metadata@reference, original@metadata@reference)
  expect_identical(restored@metadata@organism, original@metadata@organism)
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
    }
  }'
  expect_error(A3from_json(legacy_json), "index")
})

test_that("A3from_json handles missing metadata gracefully", {
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
  x <- A3from_json(json)
  expect_s7_class(x, A3)
  expect_identical(x@metadata@uniprot_id, "")
  expect_identical(x@metadata@description, "")
})

test_that("A3from_json accepts pre-parsed list", {
  lst <- list(
    `$schema` = "https://schema.rtemis.org/a3/v1/schema.json",
    a3_version = "1.0.0",
    sequence = "MKTAYIAKQRQISFVK",
    annotations = list(
      site = list(
        `Active site` = list(index = c(3L, 5L), type = "activeSite")
      ),
      region = list(),
      ptm = list(),
      processing = list(),
      variant = list()
    ),
    metadata = list(uniprot_id = "P12345")
  )
  x <- A3from_json(lst)
  expect_s7_class(x, A3)
  expect_identical(x@annotations@site$`Active site`@type, "activeSite")
  expect_identical(x@metadata@uniprot_id, "P12345")
})
