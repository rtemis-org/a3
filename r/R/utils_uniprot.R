# %% uniprot_sequence ----
#' Fetch a protein sequence from UniProt
#'
#' Lightweight FASTA-only fetch. Use this when you only need the amino acid
#' sequence. For full annotations and metadata use [uniprot_to_A3()].
#'
#' @param accession Character scalar: UniProt accession, e.g. `"P10636"`.
#' @param base_url Character scalar: UniProt REST API base URL.
#' @param verbosity Integer scalar: Verbosity level.
#'
#' @return Character scalar: amino acid sequence in single-letter code.
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#'   seq <- uniprot_sequence("P10636")
#' }
uniprot_sequence <- function(
  accession,
  base_url = "https://rest.uniprot.org/uniprotkb",
  verbosity = 1L
) {
  check_inherits(accession, "character")
  check_dependencies("seqinr")

  path <- paste0(base_url, "/", accession, ".fasta")
  dat <- seqinr::read.fasta(path, seqtype = "AA")
  msg("Got:", highlight(attr(dat[[1L]], "Annot")), verbosity = verbosity)
  paste(as.character(dat[[1L]]), collapse = "")
}


# %% uniprot_to_A3 ----
#' Fetch a UniProt entry and parse it into an A3 object
#'
#' Fetches the UniProt JSON for the given accession via the UniProt REST API,
#' maps all sequence annotations to the A3 schema (see `specs/uniprot.md`), and
#' returns a fully populated `A3` object.
#'
#' Feature types not mapped to A3 (mutagenesis, alternative sequences, sequence
#' conflicts, etc.) are silently ignored.
#'
#' @param accession Character scalar: UniProt accession, e.g. `"P10636"`.
#' @param base_url Character scalar: UniProt REST API base URL.
#' @param verbosity Integer scalar: Verbosity level.
#'
#' @return `A3` object with sequence, annotations, and UniProt metadata.
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#' mapt <- uniprot_to_A3("P10636")
#' }
uniprot_to_A3 <- function(
  accession,
  base_url = "https://rest.uniprot.org/uniprotkb",
  verbosity = 1L
) {
  check_inherits(accession, "character")
  check_dependencies(c("httr", "jsonlite"))

  # -- Fetch ----
  url <- paste0(base_url, "/", accession, ".json")
  response <- httr::GET(url)
  httr::stop_for_status(response)
  dat <- jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )

  # -- Sequence ----
  sequence <- dat[["sequence"]][["value"]]

  # -- Metadata ----
  null_or <- function(x, default = "") if (is.null(x)) default else x

  uniprot_id <- null_or(dat[["primaryAccession"]])
  reference <- null_or(dat[["uniProtkbId"]])
  organism <- null_or(dat[["organism"]][["scientificName"]])

  pd <- dat[["proteinDescription"]]
  description <- if (!is.null(pd)) {
    rn <- pd[["recommendedName"]]
    if (!is.null(rn)) {
      null_or(rn[["fullName"]][["value"]])
    } else {
      sn <- pd[["submittedNames"]]
      if (!is.null(sn) && length(sn) > 0L) {
        null_or(sn[[1L]][["fullName"]][["value"]])
      } else {
        ""
      }
    }
  } else {
    ""
  }

  # -- Feature type → A3 type lookup tables ----
  site_types <- c(
    "Active site" = "activeSite",
    "Binding site" = "bindingSite",
    "Site" = "site",
    "Non-standard residue" = "nonStandardResidue"
  )
  region_types <- c(
    "Domain" = "domain",
    "Repeat" = "repeat",
    "Zinc finger" = "zincFinger",
    "DNA binding" = "dnaBinding",
    "Region" = "region",
    "Coiled coil" = "coiledCoil",
    "Motif" = "motif",
    "Compositional bias" = "compositionalBias",
    "Topological domain" = "topologicalDomain",
    "Transmembrane" = "transmembrane",
    "Intramembrane" = "intramembrane",
    "Helix" = "helix",
    "Beta strand" = "betaStrand",
    "Turn" = "turn"
  )
  ptm_types <- c(
    "Modified residue" = "modifiedResidue",
    "Lipidation" = "lipidation",
    "Glycosylation" = "glycosylation",
    "Cross-link" = "crossLink",
    "Disulfide bond" = "disulfideBond"
  )
  processing_types <- c(
    "Signal peptide" = "signalPeptide",
    "Transit peptide" = "transitPeptide",
    "Propeptide" = "propeptide",
    "Chain" = "chain",
    "Peptide" = "peptide",
    "Initiator methionine" = "initiatorMethionine"
  )

  # -- Feature parsers ----
  loc_start <- function(f) as.integer(f[["location"]][["start"]][["value"]])
  loc_end <- function(f) as.integer(f[["location"]][["end"]][["value"]])

  parse_site <- function(f) {
    A3Site(
      index = A3Position(data = loc_start(f)),
      type = site_types[[f[["type"]]]]
    )
  }

  parse_region <- function(f) {
    A3Region(
      index = A3Range(data = matrix(c(loc_start(f), loc_end(f)), nrow = 1L)),
      type = region_types[[f[["type"]]]]
    )
  }

  parse_ptm <- function(f) {
    a3_type <- ptm_types[[f[["type"]]]]
    # Disulfide bond encodes a residue pair as a two-position range
    idx <- if (f[["type"]] == "Disulfide bond") {
      A3Range(data = matrix(c(loc_start(f), loc_end(f)), nrow = 1L))
    } else {
      A3Position(data = loc_start(f))
    }
    A3PTM(index = idx, type = a3_type)
  }

  parse_processing <- function(f) {
    a3_type <- processing_types[[f[["type"]]]]
    # Initiator methionine is a single-residue site; all others are ranges
    idx <- if (f[["type"]] == "Initiator methionine") {
      A3Position(data = loc_start(f))
    } else {
      A3Range(data = matrix(c(loc_start(f), loc_end(f)), nrow = 1L))
    }
    A3Processing(index = idx, type = a3_type)
  }

  parse_variant <- function(f) {
    alt <- f[["alternativeSequence"]]
    xrefs <- f[["featureCrossReferences"]]
    info <- list(
      from = null_or(alt[["originalSequence"]]),
      to = if (!is.null(alt[["alternativeSequences"]])) {
        paste(
          vapply(alt[["alternativeSequences"]], as.character, character(1L)),
          collapse = "/"
        )
      } else {
        ""
      },
      description = null_or(f[["description"]])
    )
    if (!is.null(f[["featureId"]])) {
      info[["featureId"]] <- f[["featureId"]]
    }
    if (!is.null(xrefs) && length(xrefs) > 0L) {
      dbsnp_ids <- vapply(
        Filter(function(x) identical(x[["database"]], "dbSNP"), xrefs),
        function(x) x[["id"]],
        character(1L)
      )
      if (length(dbsnp_ids) > 0L) {
        info[["dbSnp"]] <- paste(dbsnp_ids, collapse = ",")
      }
    }
    A3Variant(position = A3Position(data = loc_start(f)), info = info)
  }

  # -- Dispatch features to families ----
  features <- if (is.null(dat[["features"]])) list() else dat[["features"]]
  ftype_vec <- if (length(features) > 0L) {
    vapply(features, function(f) f[["type"]], character(1L))
  } else {
    character(0L)
  }

  site_list <- lapply(features[ftype_vec %in% names(site_types)], parse_site)
  region_list <- lapply(
    features[ftype_vec %in% names(region_types)],
    parse_region
  )
  ptm_list <- lapply(features[ftype_vec %in% names(ptm_types)], parse_ptm)
  processing_list <- lapply(
    features[ftype_vec %in% names(processing_types)],
    parse_processing
  )
  variant_list <- lapply(
    features[ftype_vec == "Natural variant"],
    parse_variant
  )

  # Assign unique names within each family: "{a3_type}_{n}" (sequential per type)
  name_by_type <- function(lst) {
    if (length(lst) == 0L) {
      return(lst)
    }
    types <- vapply(lst, function(x) x@type, character(1L))
    names(lst) <- paste0(
      types,
      "_",
      as.integer(ave(seq_along(types), types, FUN = seq_along))
    )
    lst
  }

  site_list <- name_by_type(site_list)
  region_list <- name_by_type(region_list)
  ptm_list <- name_by_type(ptm_list)
  processing_list <- name_by_type(processing_list)

  if (verbosity > 0L) {
    msg("Got:", highlight(paste0(description, " [", uniprot_id, "]")))
  }

  A3(
    sequence = A3Sequence(data = sequence),
    annotations = A3Annotation(
      site = site_list,
      region = region_list,
      ptm = ptm_list,
      processing = processing_list,
      variant = variant_list
    ),
    metadata = A3Metadata(
      uniprot_id = uniprot_id,
      description = description,
      reference = reference,
      organism = organism
    )
  )
}
