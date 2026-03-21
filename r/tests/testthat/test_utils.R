# ::rtemis.a3::
# rtemis.org

# %% gene2sequence ----
test_that("gene2sequence works", {
  skip("gene2sequence queries ensembl.org. Avoid running repeatedly.")
  expect_s3_class(
    gene2sequence("MAPT"),
    "data.frame"
  )
})

# %% aa_sub ----
test_that("aa_sub works", {
  expect_equal(
    aa_sub("ACDEFG", c("C2A")),
    c("A", "A", "D", "E", "F", "G")
  )
})
