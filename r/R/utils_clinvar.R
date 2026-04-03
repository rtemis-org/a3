# %% clinvar_variants ----
#' Fetch ClinVar variants for a gene and parse them into A3Variant objects
#'
#' Queries the NCBI ClinVar database via E-utilities for all variants
#' associated with a gene, and returns those with protein-level amino acid
#' changes as a named list of `A3Variant` objects.
#'
#' Variants without a parseable protein change (intronic, regulatory, etc.)
#' are silently skipped.
#'
#' @param gene Character scalar: HGNC gene symbol, e.g. `"MAPT"`.
#' @param significance Character vector: Clinical significance filter. Any
#'   combination of `"pathogenic"`, `"likely_pathogenic"`,
#'   `"uncertain_significance"`, `"likely_benign"`, `"benign"`. Pass `NULL`
#'   to fetch all records regardless of significance.
#' @param max_variants Integer scalar: Maximum number of ClinVar records to
#'   fetch after filtering. Defaults to `500L`.
#' @param esearch_url Character scalar: NCBI E-utilities esearch endpoint.
#' @param esummary_url Character scalar: NCBI E-utilities esummary endpoint.
#' @param batch_size Integer scalar: Number of UIDs per esummary request.
#'   NCBI recommends no more than 500 per request.
#' @param verbosity Integer scalar: Verbosity level.
#'
#' @return Named list of `A3Variant` objects. Names use `{from}{position}{to}`
#'   notation (e.g. `"R406W"`), with a numeric suffix to disambiguate
#'   duplicates.
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#' # Pathogenic and likely pathogenic variants (default)
#' mapt_variants <- clinvar_variants("MAPT")
#' # All variants regardless of significance
#' mapt_all <- clinvar_variants("MAPT", significance = NULL)
#' }
clinvar_variants <- function(
  gene,
  significance = c("pathogenic", "likely_pathogenic"),
  max_variants = 500L,
  esearch_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi",
  esummary_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi",
  batch_size = 500L,
  verbosity = 1L
) {
  check_inherits(gene, "character")
  check_dependencies(c("httr", "jsonlite"))

  # -- Build search term ----
  valid_sig <- c(
    "pathogenic",
    "likely_pathogenic",
    "uncertain_significance",
    "likely_benign",
    "benign"
  )
  if (!is.null(significance)) {
    significance <- match.arg(significance, valid_sig, several.ok = TRUE)
    sig_filter <- paste(
      paste0('"', significance, '"', "[clinsig]"),
      collapse = " OR "
    )
    term <- paste0(gene, "[gene_name] AND (", sig_filter, ")")
  } else {
    term <- paste0(gene, "[gene_name]")
  }

  # -- Search: get ClinVar UIDs for this gene ----
  search_resp <- httr::GET(
    esearch_url,
    query = list(
      db = "clinvar",
      term = term,
      retmax = as.character(max_variants),
      retmode = "json"
    )
  )
  httr::stop_for_status(search_resp)
  search_dat <- jsonlite::fromJSON(
    httr::content(search_resp, as = "text", encoding = "UTF-8"),
    simplifyVector = TRUE
  )

  uids <- search_dat[["esearchresult"]][["idlist"]]
  if (length(uids) == 0L) {
    msg(
      "No ClinVar records found for gene:",
      highlight(gene),
      verbosity = verbosity
    )
    return(list())
  }
  msg(
    "Found",
    highlight(length(uids)),
    "ClinVar records for gene:",
    highlight(gene),
    verbosity = verbosity
  )

  # -- Summarize: fetch variant details in batches ----
  batches <- split(uids, ceiling(seq_along(uids) / batch_size))
  summaries <- lapply(batches, function(batch) {
    # POST avoids HTTP 414 (URI Too Long) when batches contain many UIDs
    resp <- httr::POST(
      esummary_url,
      body = list(
        db = "clinvar",
        id = paste(batch, collapse = ","),
        retmode = "json"
      ),
      encode = "form"
    )
    httr::stop_for_status(resp)
    dat <- jsonlite::fromJSON(
      httr::content(resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
    # Remove the "uids" index entry; keep only variant records
    result <- dat[["result"]]
    result[names(result) != "uids"]
  })
  # Flatten batches into a single named list keyed by UID
  all_summaries <- do.call(c, summaries)

  # -- Parse protein change: "{from}{position}{to}" e.g. "R406W" ----
  # Returns list(from, position, to) or NULL if unparseable.
  parse_protein_change <- function(pc) {
    m <- regmatches(pc, regexpr("^([A-Z])([0-9]+)([A-Z*])$", pc))
    if (length(m) == 0L) {
      return(NULL)
    }
    list(
      from = substr(m, 1L, 1L),
      position = as.integer(substr(m, 2L, nchar(m) - 1L)),
      to = substr(m, nchar(m), nchar(m))
    )
  }

  # -- Build A3Variant objects ----
  variant_list <- list()

  for (v in all_summaries) {
    pc_raw <- v[["protein_change"]]
    if (is.null(pc_raw) || !nzchar(pc_raw)) {
      next
    }

    # protein_change may contain multiple isoform changes separated by "/"
    pc_entries <- strsplit(pc_raw, "/", fixed = TRUE)[[1L]]
    # Use the first parseable entry
    parsed <- NULL
    for (entry in pc_entries) {
      parsed <- parse_protein_change(trimws(entry))
      if (!is.null(parsed)) break
    }
    if (is.null(parsed)) {
      next
    }

    # Clinical significance
    cs <- v[["clinical_significance"]]
    sig <- if (!is.null(cs[["description"]])) cs[["description"]] else ""
    rev <- if (!is.null(cs[["review_status"]])) cs[["review_status"]] else ""

    # Condition names
    traits <- v[["trait_set"]]
    conditions <- if (!is.null(traits) && length(traits) > 0L) {
      cnames <- vapply(
        traits,
        function(t) {
          nm <- t[["trait_name"]]
          if (!is.null(nm) && nzchar(nm)) nm else ""
        },
        character(1L)
      )
      paste(cnames[nzchar(cnames)], collapse = "; ")
    } else {
      ""
    }

    info <- list(
      from = parsed[["from"]],
      to = parsed[["to"]],
      clinicalSignificance = sig,
      reviewStatus = rev,
      conditions = conditions,
      accession = if (!is.null(v[["accession"]])) v[["accession"]] else "",
      clinvarId = if (!is.null(v[["uid"]])) v[["uid"]] else ""
    )

    variant_list <- c(
      variant_list,
      list(A3Variant(
        position = A3Position(data = parsed[["position"]]),
        info = info
      ))
    )
  }

  if (length(variant_list) == 0L) {
    msg("No protein-level variants parsed.", verbosity = verbosity)
    return(list())
  }

  # -- Name variants: "{from}{position}{to}", disambiguate duplicates ----
  raw_names <- vapply(
    variant_list,
    function(v) {
      paste0(v@info[["from"]], v@position@data, v@info[["to"]])
    },
    character(1L)
  )
  counts <- table(raw_names)
  running <- integer(length(counts))
  names(running) <- names(counts)
  final_names <- vapply(
    raw_names,
    function(nm) {
      if (counts[[nm]] == 1L) {
        nm
      } else {
        running[[nm]] <<- running[[nm]] + 1L
        paste0(nm, ".", running[[nm]])
      }
    },
    character(1L)
  )
  names(variant_list) <- final_names

  msg(
    "Parsed",
    highlight(length(variant_list)),
    "protein-level variants.",
    verbosity = verbosity
  )

  variant_list
}
