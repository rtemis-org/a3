# %% pdb_annotations ----
#' Fetch PDB structural annotations for a UniProt accession
#'
#' Queries the PDBe APIs for secondary structure and ligand binding sites from
#' experimental PDB structures, converts residue numbers to UniProt canonical
#' coordinates via SIFTS, and returns named lists of `A3Region` and `A3Site`
#' objects ready for use with `create_A3()`.
#'
#' Structure ranking and SIFTS residue mappings come from the PDBe Graph API
#' `best_structures` endpoint. Secondary structure and binding sites are fetched
#' from the PDBe REST API.
#'
#' When `pdb_id` is `NULL` the top-ranked structure (by PDBe coverage score) is
#' used automatically.
#'
#' @param accession Character scalar: UniProt accession, e.g. `"P10636"`.
#' @param pdb_id Optional character scalar: Four-character PDB ID (e.g. `"2mz7"`). If
#'   `NULL`, the top-ranked structure from PDBe is used.
#' @param pdbe_graph_url Character scalar: PDBe Graph API base URL.
#' @param pdbe_api_url Character scalar: PDBe REST API base URL.
#' @param verbosity Integer scalar: Verbosity level.
#'
#' @return Named list with two elements:
#'   \describe{
#'     \item{`region`}{Named list of `A3Region` objects for secondary structure
#'       (types: `"helix"`, `"betaStrand"`, `"turn"`).}
#'     \item{`site`}{Named list of `A3Site` objects for ligand binding sites
#'       (type: `"bindingSite"`).}
#'   }
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Requires internet connection and fetches data from PDBe.
#' \dontrun{
#'   ann  <- pdb_annotations("P10636")
#'   mapt <- create_A3(
#'     sequence = uniprot_sequence("P10636"),
#'     region   = ann[["region"]],
#'     site     = ann[["site"]]
#'   )
#' }
pdb_annotations <- function(
  accession,
  pdb_id = NULL,
  pdbe_graph_url = "https://www.ebi.ac.uk/pdbe/graph-api",
  pdbe_api_url = "https://www.ebi.ac.uk/pdbe/api",
  verbosity = 1L
) {
  check_dependencies(c("httr", "jsonlite"))
  check_scalar_character(accession)
  check_optional_scalar_character(pdb_id)
  check_scalar_character(pdbe_graph_url)
  check_scalar_character(pdbe_api_url)

  fetch_json <- function(url) {
    resp <- httr::GET(url)
    httr::stop_for_status(resp)
    jsonlite::fromJSON(
      httr::content(resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
  }

  # -- SIFTS mappings via Graph API `best_structures` ----
  # Returns a flat list of segments, each with:
  #   pdb_id, chain_id, unp_start, unp_end, pdb_start, pdb_end, coverage
  # PDBe ranks them by coverage then resolution, so the first entry is best.
  best_dat <- fetch_json(paste0(
    pdbe_graph_url,
    "/mappings/best_structures/",
    accession
  ))
  all_segs <- best_dat[[accession]]

  if (is.null(all_segs) || length(all_segs) == 0L) {
    cli::cli_abort("No PDB structures found for accession {.val {accession}}.")
  }

  # -- Select structure ----
  if (is.null(pdb_id)) {
    # First entry is PDBe's top-ranked structure
    pdb_id <- tolower(all_segs[[1L]][["pdb_id"]])
    msg(
      "Selected PDB structure:",
      highlight(toupper(pdb_id)),
      "(PDBe top-ranked)",
      verbosity = verbosity
    )
  } else {
    pdb_id <- tolower(pdb_id)
    seg_ids <- vapply(
      all_segs,
      function(s) tolower(s[["pdb_id"]]),
      character(1L)
    )
    if (!pdb_id %in% seg_ids) {
      cli::cli_abort(
        "PDB ID {.val {pdb_id}} not found in best_structures for {.val {accession}}."
      )
    }
  }

  # Collect all segments for the chosen structure (may span multiple chains)
  segments <- Filter(
    function(s) identical(tolower(s[["pdb_id"]]), pdb_id),
    all_segs
  )

  mapped_chains <- unique(vapply(
    segments,
    function(s) s[["chain_id"]],
    character(1L)
  ))
  unp_start_global <- min(vapply(
    segments,
    function(s) s[["unp_start"]],
    integer(1L)
  ))
  unp_end_global <- max(vapply(
    segments,
    function(s) s[["unp_end"]],
    integer(1L)
  ))

  # -- Coordinate converter: PDB author residue number → UniProt ----
  # best_structures uses "start"/"end" for PDB author residue numbers.
  # For each segment: uniprot_pos = pdb_pos - start + unp_start
  convert_pos <- function(pdb_positions, chain) {
    result <- rep(NA_integer_, length(pdb_positions))
    for (seg in segments) {
      if (!identical(seg[["chain_id"]], chain)) {
        next
      }
      ps <- seg[["start"]]
      pe <- seg[["end"]]
      in_seg <- pdb_positions >= ps & pdb_positions <= pe
      result[in_seg] <- pdb_positions[in_seg] - ps + seg[["unp_start"]]
    }
    result
  }

  # -- Secondary structure from PDBe REST API ----
  ss_raw <- fetch_json(paste0(
    pdbe_api_url,
    "/pdb/entry/secondary_structure/",
    pdb_id
  ))
  molecules <- ss_raw[[pdb_id]][["molecules"]]

  region_list <- list()

  for (mol in molecules) {
    for (chain in mol[["chains"]]) {
      chain_id <- chain[["chain_id"]]
      if (!chain_id %in% mapped_chains) {
        next
      }
      ss <- chain[["secondary_structure"]]

      parse_ss_elements <- function(elements, a3_type) {
        lapply(elements, function(el) {
          s <- as.integer(el[["start"]][["author_residue_number"]])
          e <- as.integer(el[["end"]][["author_residue_number"]])
          unp <- convert_pos(c(s, e), chain_id)
          if (
            anyNA(unp) ||
              unp[[1L]] < unp_start_global ||
              unp[[2L]] > unp_end_global ||
              unp[[1L]] >= unp[[2L]]
          ) {
            return(NULL)
          }
          A3Region(
            index = A3Range(data = matrix(unp, nrow = 1L)),
            type = a3_type
          )
        })
      }

      region_list <- c(
        region_list,
        Filter(Negate(is.null), parse_ss_elements(ss[["helices"]], "helix")),
        Filter(
          Negate(is.null),
          parse_ss_elements(ss[["strands"]], "betaStrand")
        ),
        Filter(Negate(is.null), parse_ss_elements(ss[["turns"]], "turn"))
      )
    }
  }

  # -- Binding sites from PDBe REST API ----
  bs_resp <- httr::GET(paste0(
    pdbe_api_url,
    "/pdb/entry/binding_sites/",
    pdb_id
  ))
  site_list <- list()

  # 404 = no binding sites; anything else is an error
  if (httr::status_code(bs_resp) != 404L) {
    httr::stop_for_status(bs_resp)
    binding_sites <- jsonlite::fromJSON(
      httr::content(bs_resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )[[pdb_id]]

    for (bs in binding_sites) {
      residues <- Filter(
        function(r) {
          identical(r[["symmetry_symbol"]], "1_555") &&
            r[["chain_id"]] %in% mapped_chains
        },
        bs[["residues"]]
      )
      if (length(residues) == 0L) {
        next
      }

      chain_id <- residues[[1L]][["chain_id"]]
      unp_positions <- sort(unique(Filter(
        function(p) !is.na(p) & p >= unp_start_global & p <= unp_end_global,
        convert_pos(
          vapply(
            residues,
            function(r) as.integer(r[["author_residue_number"]]),
            integer(1L)
          ),
          chain_id
        )
      )))
      if (length(unp_positions) == 0L) {
        next
      }

      site_list <- c(
        site_list,
        list(
          A3Site(index = A3Position(data = unp_positions), type = "bindingSite")
        )
      )
    }
  }

  # -- Name by type with sequential suffix ----
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

  region_list <- name_by_type(region_list)
  site_list <- name_by_type(site_list)

  msg(
    "Parsed",
    highlight(length(region_list)),
    "secondary structure regions and",
    highlight(length(site_list)),
    "binding sites from",
    highlight(toupper(pdb_id)),
    verbosity = verbosity
  )

  list(region = region_list, site = site_list)
}
