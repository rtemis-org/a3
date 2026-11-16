# test_plot.R
# ::rtemis.a3::
# 2026- EDG rtemis.org

test_that("plot() on an A3 object draws with rtemis.draw", {
  skip_if_not_installed("rtemis.draw")
  x <- create_A3(
    "MAEPRQEFEVMEDHAGTYGL",
    variant = list(annotation_variant(5L, info = list(from = "R", to = "L")))
  )
  widget <- plot(x)
  expect_s3_class(widget, "htmlwidget")
})
