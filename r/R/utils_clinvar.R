# %% clinvar_variants ----
#' Fetch ClinVar variants for a gene, positioned on one RefSeq protein
#'
#' Lists every ClinVar record for `gene` through NCBI E-utilities, keeps the
#' records whose only gene is `gene` and whose aggregate germline
#' classification is in `classification`, and returns one `A3Variant` per
#' record with a single-residue change on `protein`.
#'
#' The position, reference residue, and alternate residue come from the
#' record's HGVS protein expression on `protein` (for example
#' `NP_005901.2:p.Pro301Leu`). ClinVar's summary field `protein_change` lists
#' the change on every RefSeq isoform without naming the isoform, so it does
#' not determine a position. A record with no single-residue change on
#' `protein` (noncoding, splice-site, frameshift, or multi-residue changes, and
#' changes in exons the isoform lacks) is skipped and counted in a message.
#'
#' Supported changes are missense (`P301L`), nonsense (`R5*`), and deletion of
#' one residue (`N279del`). A deletion record has no `to` member.
#'
#' Each variant's `info` holds `from`, `to`, `type` (`"missense"`,
#' `"nonsense"`, or `"deletion"`), `source` (`"ClinVar"`), `id` (the VCV
#' accession with its version), `hgvs_p`, `clinical_significance`,
#' `review_status`, and `conditions` (a character vector of condition names).
#'
#' @param gene Character scalar: HGNC gene symbol, e.g. `"MAPT"`.
#' @param protein Character scalar: RefSeq protein accession with version
#'   whose coordinates the variants use, e.g. `"NP_005901.2"` for tau isoform
#'   2N4R. The A3 document's sequence must be this protein's sequence.
#' @param classification Character vector: Aggregate germline classifications
#'   to keep, compared exactly with ClinVar's
#'   `germline_classification.description`. `NULL` keeps every record.
#' @param eutils_url Character scalar: Base URL of NCBI E-utilities.
#' @param verbosity Integer scalar: Verbosity level.
#'
#' @return Named list of `A3Variant` objects, ordered by position. Names use
#'   `{from}{position}{to}` notation (e.g. `"P301L"`, `"N279del"`), with a
#'   numeric suffix to disambiguate duplicates.
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Requires internet connection and fetches data from ClinVar.
#' \dontrun{
#' # Pathogenic and likely pathogenic MAPT variants on tau isoform 2N4R
#' mapt_variants <- clinvar_variants("MAPT", protein = "NP_005901.2")
#' mapt_seq <- uniprot_sequence("P10636-8")
#' a3 <- create_A3(mapt_seq, variant = mapt_variants, uniprot_id = "P10636-8")
#' }
clinvar_variants <- function(
  gene,
  protein,
  classification = c(
    "Pathogenic",
    "Likely pathogenic",
    "Pathogenic/Likely pathogenic"
  ),
  eutils_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils",
  verbosity = 1L
) {
  check_dependencies("httr", "xml2")
  check_scalar_character(gene, arg_name = "gene")
  check_scalar_character(protein, arg_name = "protein")
  check_character(
    classification,
    allow_null = TRUE,
    arg_name = "classification"
  )
  check_scalar_character(eutils_url, arg_name = "eutils_url")

  # NCBI allows three requests per second without an API key.
  eutils_get <- function(endpoint, query) {
    Sys.sleep(0.34)
    resp <- httr::GET(paste0(eutils_url, "/", endpoint), query = query)
    httr::stop_for_status(resp)
    httr::content(resp, as = "text", encoding = "UTF-8")
  }
  eutils_post <- function(endpoint, body) {
    Sys.sleep(0.34)
    resp <- httr::POST(
      paste0(eutils_url, "/", endpoint),
      body = body,
      encode = "form"
    )
    httr::stop_for_status(resp)
    httr::content(resp, as = "text", encoding = "UTF-8")
  }

  # -- List every record for the gene ----
  search <- jsonlite::fromJSON(
    eutils_get(
      "esearch.fcgi",
      list(
        db = "clinvar",
        term = paste0(gene, "[gene]"),
        retmax = "10000",
        retmode = "json"
      )
    ),
    simplifyVector = TRUE
  )
  uids <- search[["esearchresult"]][["idlist"]]
  if (length(uids) == 0L) {
    msg(
      "No ClinVar records found for gene:",
      highlight(gene),
      verbosity = verbosity
    )
    return(list())
  }

  # -- Summaries: classification, genes, conditions ----
  # POST avoids HTTP 414 (URI Too Long) for long ID lists.
  batches <- split(uids, ceiling(seq_along(uids) / 300L))
  summaries <- list()
  for (batch in batches) {
    res <- jsonlite::fromJSON(
      eutils_post(
        "esummary.fcgi",
        list(
          db = "clinvar",
          id = paste(batch, collapse = ","),
          retmode = "json"
        )
      ),
      simplifyVector = FALSE
    )[["result"]]
    summaries <- c(summaries, res[setdiff(names(res), "uids")])
  }

  keep <- vapply(
    summaries,
    function(s) .clinvar_keep(s, gene, classification),
    logical(1L)
  )
  summaries <- summaries[keep]
  msg(
    "Found",
    highlight(length(uids)),
    "ClinVar records for",
    highlight(gene),
    "and kept",
    highlight(length(summaries)),
    "by gene and classification.",
    verbosity = verbosity
  )
  if (length(summaries) == 0L) {
    return(list())
  }

  # -- Full records: HGVS protein expressions ----
  vcv_ids <- vapply(summaries, function(s) s[["uid"]], character(1L))
  archives <- list()
  for (batch in split(vcv_ids, ceiling(seq_along(vcv_ids) / 20L))) {
    xml <- xml2::read_xml(eutils_get(
      "efetch.fcgi",
      list(
        db = "clinvar",
        rettype = "vcv",
        is_variationid = "",
        id = paste(batch, collapse = ",")
      )
    ))
    for (node in xml2::xml_find_all(xml, "//VariationArchive")) {
      archives[[xml2::xml_attr(node, "VariationID")]] <- node
    }
  }

  # -- Build variants ----
  records <- lapply(summaries, function(s) {
    node <- archives[[s[["uid"]]]]
    if (is.null(node)) {
      return(NULL)
    }
    .clinvar_record(s, node, protein)
  })
  records <- Filter(Negate(is.null), records)
  n_skipped <- length(summaries) - length(records)
  if (n_skipped > 0L) {
    msg(
      "Skipped",
      highlight(n_skipped),
      "records with no single-residue change on",
      highlight(protein),
      verbosity = verbosity
    )
  }
  if (length(records) == 0L) {
    return(list())
  }

  positions <- vapply(records, function(r) r[["position"]], integer(1L))
  records <- records[order(positions)]
  variant_list <- lapply(records, function(r) {
    A3Variant(
      position = r[["position"]],
      info = r[setdiff(names(r), "position")]
    )
  })
  names(variant_list) <- .clinvar_unique_names(vapply(
    records,
    function(r) {
      paste0(
        r[["from"]],
        r[["position"]],
        if (r[["type"]] == "deletion") "del" else r[["to"]]
      )
    },
    character(1L)
  ))

  msg(
    "Parsed",
    highlight(length(variant_list)),
    "protein-level variants on",
    highlight(protein),
    verbosity = verbosity
  )
  variant_list
}


# %% .clinvar_keep ----
#' Decide whether a ClinVar summary record is kept
#'
#' @param summary List: One record from the esummary `result` object.
#' @param gene Character scalar: HGNC gene symbol.
#' @param classification Character vector or `NULL`: Classifications to keep.
#'
#' @return Logical scalar: `TRUE` when `gene` is the record's only gene and the
#'   aggregate germline classification is in `classification` (or
#'   `classification` is `NULL`).
#'
#' @author EDG
#' @keywords internal
#' @noRd
.clinvar_keep <- function(summary, gene, classification) {
  symbols <- vapply(
    summary[["genes"]],
    function(g) g[["symbol"]],
    character(1L)
  )
  if (!identical(unique(symbols), gene)) {
    return(FALSE)
  }
  if (is.null(classification)) {
    return(TRUE)
  }
  desc <- summary[["germline_classification"]][["description"]]
  !is.null(desc) && desc %in% classification
}


# %% .clinvar_parse_change ----
#' Parse a single-letter protein change
#'
#' @param x Character scalar: A change in ClinVar's single-letter notation,
#'   e.g. `"P301L"`, `"R5*"`, or `"N279del"`.
#'
#' @return List with `from`, `position` (integer), `to` (`NULL` for a
#'   deletion), and `type`, or `NULL` when `x` is not a single-residue change.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.clinvar_parse_change <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    return(NULL)
  }
  m <- regmatches(x, regexec("^([A-Z])([0-9]+)([A-Z*]|del)$", x))[[1L]]
  if (length(m) == 0L) {
    return(NULL)
  }
  alt <- m[[4L]]
  type <- if (alt == "del") {
    "deletion"
  } else if (alt == "*") {
    "nonsense"
  } else {
    "missense"
  }
  out <- list(from = m[[2L]], position = as.integer(m[[3L]]))
  out["to"] <- list(if (alt == "del") NULL else alt)
  out[["type"]] <- type
  out
}


# %% .clinvar_record ----
#' Build one variant record from a ClinVar summary and its VCV archive
#'
#' @param summary List: One record from the esummary `result` object.
#' @param archive `xml_node`: The record's `VariationArchive` element.
#' @param protein Character scalar: RefSeq protein accession with version.
#'
#' @return Named list with `position` and the members described in
#'   [clinvar_variants()], or `NULL` when the record has no single-residue
#'   change on `protein`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.clinvar_record <- function(summary, archive, protein) {
  expr <- xml2::xml_find_first(
    archive,
    sprintf(".//ProteinExpression[@sequenceAccessionVersion='%s']", protein)
  )
  if (inherits(expr, "xml_missing")) {
    return(NULL)
  }
  change <- .clinvar_parse_change(
    xml2::xml_attr(expr, "singleLetterProteinChange")
  )
  if (is.null(change)) {
    return(NULL)
  }

  gc <- xml2::xml_find_first(
    archive,
    ".//Classifications/GermlineClassification"
  )
  text_or_empty <- function(node, xpath) {
    found <- xml2::xml_find_first(node, xpath)
    if (inherits(found, "xml_missing")) "" else xml2::xml_text(found)
  }
  traits <- summary[["germline_classification"]][["trait_set"]]
  conditions <- vapply(
    traits,
    function(t) {
      nm <- t[["trait_name"]]
      if (is.null(nm)) "" else nm
    },
    character(1L)
  )
  conditions <- unique(conditions[
    nzchar(conditions) & conditions != "not provided"
  ])

  record <- list(
    position = change[["position"]],
    from = change[["from"]]
  )
  if (!is.null(change[["to"]])) {
    record[["to"]] <- change[["to"]]
  }
  record[["type"]] <- change[["type"]]
  record[["source"]] <- "ClinVar"
  record[["id"]] <- paste0(
    xml2::xml_attr(archive, "Accession"),
    ".",
    xml2::xml_attr(archive, "Version")
  )
  record[["hgvs_p"]] <- text_or_empty(expr, "Expression")
  record[["clinical_significance"]] <- text_or_empty(gc, "Description")
  record[["review_status"]] <- text_or_empty(gc, "ReviewStatus")
  # AsIs keeps a single condition a JSON array when the record is serialized.
  record[["conditions"]] <- I(conditions)
  record
}


# %% .clinvar_unique_names ----
#' Disambiguate repeated variant names
#'
#' @param x Character vector: Variant names.
#'
#' @return Character vector: `x` with `.1`, `.2`, ... appended to every
#'   occurrence of a repeated name.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.clinvar_unique_names <- function(x) {
  counts <- table(x)
  seen <- integer(0L)
  vapply(
    x,
    function(nm) {
      if (counts[[nm]] == 1L) {
        return(nm)
      }
      seen[nm] <<- if (is.na(seen[nm])) 1L else seen[nm] + 1L
      paste0(nm, ".", seen[[nm]])
    },
    character(1L),
    USE.NAMES = FALSE
  )
}
