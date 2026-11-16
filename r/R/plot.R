# plot.R
# ::rtemis.a3::
# 2026- EDG rtemis.org

# %% plot.A3 ----
#' Plot an A3 Object
#'
#' Draws the sequence and its annotations as an interactive diagram with
#' [rtemis.draw::draw_a3()]. Requires the \pkg{rtemis.draw} package.
#'
#' @param x `A3` object.
#' @param ... Named settings passed to [rtemis.draw::draw_a3()].
#'
#' @return An ECharts htmlwidget.
#'
#' @author EDG
#' @export
#'
#' @examples
#' x <- create_A3("MAEPRQEFEVMEDHAGTYGL")
#' if (requireNamespace("rtemis.draw", quietly = TRUE)) {
#'   plot(x)
#' }
plot.A3 <- function(x, ...) {
  check_dependencies("rtemis.draw")
  rtemis.draw::draw_a3(x, ...)
}

method(plot, A3) <- plot.A3
