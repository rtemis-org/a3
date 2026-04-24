# %% repr ----
repr <- new_generic("repr", "x")


# %% to_base ----
to_base <- new_generic("to_base", "x")


# %% to_json ----
to_json <- new_generic("to_json", "x")

# %% rtemis.core 0.0.4 ----

# %% clean_int ----
#' Clean integer input
#'
#' @details
#' The goal is to return an integer vector.
#' If the input is integer, it is returned as is.
#' If the input is numeric, it is coerced to integer only if the numeric values are integers,
#' otherwise an error is thrown.
#'
#' @param x Double or integer vector to check.
#'
#' @return Integer vector
#' @author EDG
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' clean_int(6L)
#' clean_int(3)
#' # clean_int(12.1) # Error
#' clean_int(c(3, 5, 7))
#' # clean_int(c(3, 5, 7.01)) # Error
clean_int <- function(x, xname = deparse(substitute(x))) {
  if (is.integer(x)) {
    return(x)
  } else if (is.numeric(x)) {
    if (all(x %% 1 == 0)) {
      storage.mode(x) <- "integer"
      return(x)
    } else {
      cli::cli_abort("{.var {xname}} must be integer.")
    }
  } else if (is.null(x)) {
    return(NULL)
  }
  cli::cli_abort("{.var {xname}} must be integer.")
}
