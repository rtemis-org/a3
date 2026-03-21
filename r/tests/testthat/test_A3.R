# rtemis.org

# devtools::load_all("~/Code/rtemis-org/a3/r")
# library(testthat)

# %% A3() ----
sequence <- "ARNDCEQGHILKMFPSTWYV"
sequence <- strsplit(sequence, "")[[1]]
variant <- list(
  list(
    id = "CA399900571rs371983180",
    position = 5,
    change = "G>A",
    # `Disease Association` = "No",
    consequence = "missense",
    accession = "NC_000017.11:g.45983208G>C",
    codon = "GGC / GCC",
    `consequence type` = "missense",
    `cytogenetic band` = "17q21.31",
    `genomic location` = "NC_000017.11:g.45983208G>C"
  )
)

x <- A3(
  sequence = sequence,
  site = list(
    Phosphorylation = c(2, 5),
    Glycosylation = c(3, 6)
  ),
  region = list(
    Transmembrane = c(3:6)
  ),
  ptm = list(
    Methylation = c(4, 8)
  ),
  cleavage_site = list(
    Signal_peptide = c(1, 20)
  ),
  variant = variant,
  uniprotid = "P12345",
  description = "Test protein",
  reference = "Test reference"
)

test_that("A3() creates A3 object", {
  expect_s7_class(x, A3)
})

# %% `[` method for A3 ----
test_that("`[` method for A3 works", {
  expect_equal(
    x[c("sequence", "uniprotid")],
    list(sequence = sequence, uniprotid = "P12345")
  )
})

# %% `[[` method for A3 ----
test_that("`[[` method for A3 works", {
  expect_equal(x[["sequence"]], sequence)
})

# %% create_A3() ----
x <- create_A3(
  sequence = sequence,
  site = list(
    Phosphorylation = c(2, 5),
    Glycosylation = c(3, 6)
  ),
  region = list(
    Transmembrane = c(3:6)
  ),
  ptm = list(
    Methylation = c(4, 8)
  ),
  cleavage_site = list(
    Signal_peptide = c(1, 20)
  ),
  variant = variant,
  uniprotid = "P12345",
  description = "Test protein",
  reference = "Test reference"
)

test_that("create_A3() creates A3 object", {
  expect_s7_class(x, A3)
})


# %% print A3 ----
test_that("Print A3 works", {
  expect_no_error(print(x))
})


# %% as_A3 ----
x <- list(
  sequence = sequence,
  annotations = list(
    site = list(
      Phosphorylation = c(2, 5),
      Glycosylation = c(3, 6)
    ),
    region = list(
      Transmembrane = c(5:10)
    ),
    ptm = list(
      Methylation = c(4, 8)
    ),
    cleavage_site = list(
      Signal_peptide = c(1, 20)
    ),
    variant = variant
  ),
  uniprotid = "P12345",
  description = "Test protein",
  reference = "Test reference"
) |>
  as_A3()

test_that("as_A3() creates A3 object", {
  expect_s7_class(x, A3)
})

# %% plot A3 ----
plt <- plot(x)
test_that("plot.A3 creates plotly object", {
  expect_s3_class(plt, "plotly")
})

# %% summary A3 ----
test_that("summary.A3 works", {
  expect_no_error(summary(x))
})

# %% int2range() ----
test_that("int2range works for consecutive integers", {
  expect_equal(rtemis.a3:::int2range(34:42), "34:42")
})

test_that("int2range fails for non-consecutive integers", {
  expect_error(int2range(c(34:38, 40:42)))
})
