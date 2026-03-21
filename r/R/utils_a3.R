#' Get AlphaFold info for a given UniProt ID
#'
#' @param uniprotid Character: UniProt ID.
#'
#' @return data frame with AlphaFold info.
#'
#' @author EDG
#' @export
get_alphafold <- function(uniprotid) {
  url <- paste0("https://www.alphafold.ebi.ac.uk/api/prediction/", uniprotid)
  headers <- c(
    "accept" = "application/json"
  )
  response <- httr::GET(url, httr::add_headers(.headers = headers))
  httr::stop_for_status(response)
  content <- httr::content(response, as = "text", encoding = "UTF-8")
  jsonlite::fromJSON(content)
} # /rtemis.a3::get_alphafold

get_alphafold_pdb <- function(uniprotid) {
  get_alphafold(uniprotid)$pdb
} # /rtemis.a3::get_alphafold_pdb


#' Write `A3` object to JSON file
#'
#' @param x `A3` object, as created by `as_A3()`.
#' @param filepath Character: Path to save JSON file.
#' @param overwrite Logical: If TRUE, overwrite existing file.
#'
#' @return Nothing. Writes JSON file.
#'
#' @author EDG
#' @export
write_A3json <- function(x, filepath, overwrite = FALSE) {
  # Check types ----
  check_is_S7(x, A3)
  check_inherits(filepath, "character")

  # Check dependencies ----
  check_dependencies("jsonlite")

  # Normalize path ----
  filepath <- normalizePath(filepath, mustWork = FALSE)

  # Check file ----
  if (file.exists(filepath) && !overwrite) {
    cli::cli_abort(
      "File ",
      filepath,
      " exists.\033[0m",
      "\n  Set",
      highlight("`overwrite = TRUE`"),
      "if you wish to overwrite."
    )
  }

  # Save to file
  jsonlite::write_json(
    x = as.list(x),
    path = filepath,
    simplifyVector = TRUE,
    simplifyMatrix = FALSE
  )
} # /rtemis.a3::write_A3json


# read_A3json.R
# ::rtemis.a3::
# 2024 EDG rtemis.org

#' Read `A3` object from JSON file
#'
#' @param filepath Character: Path to JSON file.
#' @param verbosity Integer: if greater than 0, print messages.
#'
#' @return `A3` object.
#'
#' @author EDG
#' @export
read_A3json <- function(filepath, verbosity = 0L) {
  # Check types ----
  check_inherits(filepath, "character")

  # Check dependencies ----
  check_dependencies("jsonlite")

  # Normalize path ----
  filepath <- normalizePath(filepath)

  # Check file ----
  if (!file.exists(filepath)) {
    cli::cli_abort("File", filepath, "does not exist.")
  }

  # Read from file
  A3 <- jsonlite::read_json(
    path = filepath,
    simplifyVector = TRUE,
    simplifyMatrix = FALSE
  ) |>
    as_A3()

  if (verbosity > 0) {
    cat("Read", filepath, ":\n", sep = "")
    print(A3)
  }
  A3
} # /rtemis.a3::read_A3json


#' Perform amino acid substitutions
#'
#' @param x Character vector: Amino acid sequence. e.g. `"ARND"` or
#' `c("A", "R", "N", "D")`.
#' @param substitutions Character vector: Substitutions to perform in the format
#' "OriginalPositionNew", e.g. `c("C291A", "C322A")`.
#' @param verbosity Integer: Verbosity level.
#'
#' @return Character vector with substitutions performed.
#'
#' @author EDG
#' @export
aa_sub <- function(x, substitutions, verbosity = 1L) {
  stopifnot(is.character(x), is.character(substitutions))
  # Split x into characters
  if (length(x) == 1) {
    x <- unlist(strsplit(x, ""))
  }
  for (s in substitutions) {
    strngs <- strsplit(s, "")[[1]]
    from <- strngs[1]
    to <- strngs[length(strngs)]
    pos <- as.numeric(strngs[2:(length(strngs) - 1)] |> paste(collapse = ""))
    if (verbosity > 0) {
      msg(
        "Substituting",
        highlight(from),
        "at position",
        highlight(pos),
        "with",
        highlight(to)
      )
    }
    x[pos] <- to
  }
  if (verbosity > 0) {
    msg("All done.")
  }
  x
} # /rtemis.a3::aa_sub
