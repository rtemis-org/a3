#' Get AlphaFold info for a given UniProt ID
#'
#' @param uniprotid Character: UniProt ID.
#'
#' @return data frame with AlphaFold info.
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#' get_alphafold("P10636")
#' }
get_alphafold <- function(uniprotid) {
  url <- paste0("https://www.alphafold.ebi.ac.uk/api/prediction/", uniprotid)
  headers <- c(
    "accept" = "application/json"
  )
  response <- httr::GET(url, httr::add_headers(.headers = headers))
  httr::stop_for_status(response)
  content <- httr::content(response, as = "text", encoding = "UTF-8")
  jsonlite::fromJSON(content)
}


# %% get_alphafold_pdb ----
get_alphafold_pdb <- function(uniprotid) {
  get_alphafold(uniprotid)[["pdb"]]
}


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
#'
#' @examples
#' aa_sub(c("A", "R", "N", "D"), c("R2K", "N3S"))
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
    msg(
      "Substituting",
      highlight(from),
      "at position",
      highlight(pos),
      "with",
      highlight(to),
      versbosity = verbosity
    )
    x[pos] <- to
  }
  msg("All done.", versbosity = verbosity)
  x
}
