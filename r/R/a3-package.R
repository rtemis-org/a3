# %% pkglogo ----
pkglogo <- function(
  pkg,
  filename = paste0(pkg, ".utf8"),
  fmt_fn = color_txt_columns,
  args = list(
    color_left = rtemis_colors[["blue"]],
    color_right = rtemis_colors[["green"]],
    output_type = "ansi"
  ),
  pad = 0L
) {
  logo_file <- system.file(
    package = .packageName,
    "resources",
    filename
  )
  logo_txt <- readLines(logo_file)
  paste0(
    strrep(" ", pad),
    do.call(fmt_fn, c(list(x = logo_txt), args)),
    collapse = "\n"
  )
}

#' @name rtemis.a3-package
#'
#' @title rtemis.a3: Amino Acid Annotation format
#'
#' @description
#' Amino Acid Annotation format utilities
#'
#' @import data.table S7
#' @importFrom stats ave
"_PACKAGE"

NULL
