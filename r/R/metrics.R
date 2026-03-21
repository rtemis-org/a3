#' Jaccard index
#'
#' @param x Character vector. Will be coerced to character.
#' @param y Character vector. Will be coerced to character.
#'
#' @return Numeric: Jaccard index.
#'
#' @author EDG
#' @keywords internal
#' @noRd
jaccard_index <- function(x, y) {
  x <- unique(as.character(x))
  y <- unique(as.character(y))
  n_x_and_y <- length(intersect(x, y))
  n_x_or_y <- length(union(x, y))
  n_x_and_y / n_x_or_y
} # /rtemis.a3::jaccard_index


#' Dice Coefficient
#'
#' @param x Character vector. Will be coerced to character.
#' @param y Character vector. Will be coerced to character.
#'
#' @return Numeric: Dice coefficient.
#'
#' @author EDG
#' @keywords internal
#' @noRd
dice_coefficient <- function(x, y) {
  x <- unique(as.character(x))
  y <- unique(as.character(y))
  n_x <- length(x)
  n_y <- length(y)
  n_x_and_y <- length(intersect(x, y))
  2 * n_x_and_y / (n_x + n_y)
} # /rtemis.a3::dice_coefficient


#' Overlap Coefficient
#'
#' Overlap Coefficient a.k.a. Szymkiewicz-Simpson coefficient.
#'
#' @param x Character vector. Will be coerced to character.
#' @param y Character vector. Will be coerced to character.
#'
#' @return Numeric: Overlap coefficient.
#'
#' @author EDG
#' @keywords internal
#' @noRd
overlap_coefficient <- function(x, y) {
  x <- unique(as.character(x))
  y <- unique(as.character(y))
  n_x_and_y <- length(intersect(x, y))
  n_x <- length(x)
  n_y <- length(y)
  n_x_and_y / min(n_x, n_y)
} # /rtemis.a3::overlap_coefficient


#' Cosine similarity
#'
#' @param x Character vector. Will be coerced to character.
#' @param y Character vector. Will be coerced to character.
#'
#' @return Numeric: Cosine similarity.
#'
#' @author EDG
#' @keywords internal
#' @noRd
cosine_similarity <- function(x, y, sequence) {
  xbin <- rep(0, length(sequence))
  xbin[x] <- 1
  ybin <- rep(0, length(sequence))
  ybin[y] <- 1
  sum(xbin * ybin) / sqrt(sum(xbin^2)) / sqrt(sum(ybin^2))
} # /rtemis.a3::cosine_similarity


#' Pointwise Mutual Information
#'
#' @param x Character vector of PTM sites. Will be coerced to character.
#' @param y Character vector of PTM sites. Will be coerced to character.
#' @param sequence Character vector representing the protein sequence, used to determine the total number of possible sites.
#'
#' @return Numeric: Pointwise Mutual Information.
#'
#' @author EDG
#' @keywords internal
#' @noRd
pmi <- function(x, y, sequence) {
  if (is.null(sequence)) {
    cli::cli_abort("The sequence is required for PMI calculation.")
  }
  L <- length(sequence)
  if (L == 0) {
    cli::cli_abort("The sequence cannot be empty.")
  }

  x <- unique(as.character(x))
  y <- unique(as.character(y))
  n_x <- length(x)
  n_y <- length(y)

  if (n_x == 0 || n_y == 0) {
    return(0)
  }

  n_x_and_y <- length(intersect(x, y))

  if (n_x_and_y == 0) {
    return(-Inf)
  }

  log2((n_x_and_y * L) / (n_x * n_y))
} # /rtemis.a3::pmi


#' Pairwise PTM similarity
#'
#' @param x List of PTM annotations
#' @param metric Character: "jaccard", "dice", "overlap", "cosine", "pmi"
#' @param sequence Character vector representing the protein sequence. Required for 'cosine' and 'pmi' metrics.
#'
#' @return Matrix of pairwise similarity scores.
#'
#' @author EDG
#' @keywords internal
#' @noRd
pairwise_similarity <- function(x, metric = "jaccard", sequence = NULL) {
  # Apply similarity metric on all pairs of elements in x
  n <- length(x)
  sim <- matrix(NA, nrow = n, ncol = n)
  for (i in seq_along(x)) {
    for (j in seq_along(x)) {
      sim[i, j] <- switch(
        metric,
        "jaccard" = jaccard_index(x[[i]], x[[j]]),
        "dice" = dice_coefficient(x[[i]], x[[j]]),
        "overlap" = overlap_coefficient(x[[i]], x[[j]]),
        "cosine" = cosine_similarity(x[[i]], x[[j]], sequence),
        "pmi" = pmi(x[[i]], x[[j]], sequence)
      )
    }
  }
  rownames(sim) <- colnames(sim) <- names(x)
  sim
} # /rtemis.a3::pairwise_similarity
