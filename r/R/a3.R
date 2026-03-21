# %% A3 ----
#' @title A3 Annotated Amino Acid Class
#'
#' @description
#' The annotated amino acid (A3) class is designed to store and manage
#' amino acid sequences and associated annotations.
#'
#' @field sequence Character: Amino acid sequence using single-letter codes.
#' @field annotations List: Named list including site, region, PTM, cleavage_site, and variant
#' information.
#' @field uniprotid Character: Uniprot ID associated with the sequence, if available.
#' @field description Character: Description of the data / experiment.
#' @field reference Character: Link to reference (journal publication, preprint, etc.)
#'
#' @author EDG
#' @noRd
A3 <- new_class(
  "A3",
  properties = list(
    sequence = class_character,
    annotations = class_list | NULL,
    uniprotid = class_character | NULL,
    description = class_character | NULL,
    reference = class_character | NULL
  ),
  constructor = function(
    sequence,
    site = NULL,
    region = NULL,
    ptm = NULL,
    cleavage_site = NULL,
    variant = NULL,
    uniprotid = NULL,
    description = NULL,
    reference = NULL
  ) {
    # Check sequence: If length is 1, check nchar and split if needed.
    sequence <- toupper(sequence)
    if (length(sequence) == 0) {
      cli::cli_abort("Sequence cannot be empty.")
    }
    if (length(sequence) == 1) {
      if (nchar(sequence) > 1) {
        sequence <- strsplit(sequence, split = "")[[1]]
      }
    }
    # Check no element is length 0
    if (any(nchar(sequence) == 0)) {
      cli::cli_abort("Sequence cannot contain empty elements.")
    }
    check_inherits(site, "list")
    check_inherits(region, "list")
    check_inherits(ptm, "list")
    check_inherits(cleavage_site, "list")
    check_inherits(variant, "list")
    annotations <- list(
      site = site,
      region = region,
      ptm = ptm,
      cleavage_site = cleavage_site,
      variant = variant
    )
    new_object(
      S7_object(),
      sequence = sequence,
      annotations = annotations,
      uniprotid = uniprotid,
      description = description,
      reference = reference
    )
  }
) # /rtemis.a3::A3


# %% `[`.A3 ----
method(`[`, A3) <- function(x, elements) {
  sapply(
    elements,
    function(name) prop(x, name),
    simplify = FALSE,
    USE.NAMES = TRUE
  )
} # `[`.A3


# `[[`.A3 ----
method(`[[`, A3) <- function(x, name) {
  prop(x, name)
} # `[[`.A3


# %% create_A3 ----
#' Create an `A3` object
#'
#' Creates an `A3` object given amino acid sequence and annotations.
#'
#' @details
#' We choose to keep NULL elements as empty lists in JSON, since we want users to be
#' able to easily add annotations, whether programmaticaly, using a web app, or
#' manually.
#'
#' @param sequence Character: Amino acid sequence.
#' @param site Named list of vectors of integer indices of sites, e.g.
#' `list("N-terminal repeat" = c(46, 47, 52), "Microtubule binding domain" = c(244, 245, 246))`
#' @param region Named list of integer indices,
#' e.g. `list("Phosphodegron" = c(46, 47, 48, 49, 50, 51), "KXGS" = c(259, 260, 261, 262))`
#' or character vectors with index range of regions in format
#' `start:end`, e.g. `list(Phosphodegron = c("46:51", "149:154"), KXGS = c("259:262", "290:293"))`
#' @param ptm Named list of vectors with indices of post-translational modifications, e.g.
#' `list("Phosphorylation" = c(17, 18, 29, 30), "Acetylation" = c(148, 150, 163))`
#' @param cleavage_site Named list of cleavage sites, e.g.
#' `list(CTSL = c(54, 244, 319), CTSD = c(340, 391, 426))`
#' @param variant List of lists with variant information. Each list must contain a
#' `position` element.
#' @param uniprotid Character: Uniprot ID.
#' @param description Character: Description of the data / experiment.
#' @param reference Character: Link to reference (journal publication, preprint, etc.)
#'
#' @return `A3` object
#'
#' @author EDG
#' @export
create_A3 <- function(
  sequence,
  site = NULL,
  region = NULL,
  ptm = NULL,
  cleavage_site = NULL,
  variant = NULL,
  uniprotid = NULL,
  description = NULL,
  reference = NULL
) {
  # Check types
  check_inherits(sequence, "character")
  check_inherits(site, "list")
  check_inherits(region, "list")
  check_inherits(ptm, "list")
  check_inherits(cleavage_site, "list")
  check_inherits(variant, "list")
  check_inherits(uniprotid, "character")
  check_inherits(description, "character")
  check_inherits(reference, "character")

  A3(
    sequence = sequence,
    site = site,
    region = region,
    ptm = ptm,
    cleavage_site = cleavage_site,
    variant = variant,
    uniprotid = uniprotid,
    description = description,
    reference = reference
  )
} # /rtemis.a3::create_A3


# %% repr A3 ----
method(repr, A3) <- function(x, output_type = NULL, head_n = 10) {
  out <- repr_S7name("A3", output_type = output_type)

  # Description
  if (!is.null(x[["description"]])) {
    out <- paste0(
      out,
      "  Description: ",
      bold(x[["description"]], output_type = output_type),
      "\n"
    )
  }

  # Uniprot ID
  if (!is.null(x[["uniprotid"]])) {
    out <- paste0(
      out,
      "   Uniprot ID: ",
      bold(x[["uniprotid"]], output_type = output_type),
      "\n"
    )
  }

  # Get annotation info
  site_annotations <- names(x[["annotations"]][["site"]])
  region_annotations <- names(x[["annotations"]][["region"]])
  ptm_annotations <- names(x[["annotations"]][["ptm"]])
  n_cleavage_site_annotations <- length(x[["annotations"]][["cleavage_site"]])
  n_variant_annotations <- length(x[["annotations"]][["variant"]])

  # Sequence
  out <- paste0(
    out,
    "     Sequence: ",
    bold(
      paste0(utils::head(x[["sequence"]], head_n), collapse = ""),
      output_type = output_type
    ),
    "...",
    " (length = ",
    length(x[["sequence"]]),
    ")\n"
  )

  # Annotations header
  out <- paste0(out, "  Annotations:\n")

  # Check if no annotations
  if (
    is.null(site_annotations) &&
      is.null(region_annotations) &&
      is.null(ptm_annotations) &&
      n_cleavage_site_annotations == 0 &&
      n_variant_annotations == 0
  ) {
    out <- paste0(out, gray("             None\n", output_type = output_type))
  }

  # Site annotations
  if (length(site_annotations) > 0) {
    out <- paste0(
      out,
      "          ",
      gray("Site:", output_type = output_type),
      " ",
      paste(bold(site_annotations, output_type = output_type), collapse = ", "),
      "\n"
    )
  }

  # Region annotations
  if (length(region_annotations) > 0) {
    out <- paste0(
      out,
      "        ",
      gray("Region:", output_type = output_type),
      " ",
      paste(
        bold(region_annotations, output_type = output_type),
        collapse = ", "
      ),
      "\n"
    )
  }

  # PTM annotations
  if (length(ptm_annotations) > 0) {
    out <- paste0(
      out,
      "           ",
      gray("PTM:", output_type = output_type),
      " ",
      paste(bold(ptm_annotations, output_type = output_type), collapse = ", "),
      "\n"
    )
  }

  # Cleavage site annotations
  if (n_cleavage_site_annotations > 0) {
    out <- paste0(
      out,
      " ",
      gray("Cleavage site:", output_type = output_type),
      " ",
      bold(n_cleavage_site_annotations, output_type = output_type),
      " annotations.\n"
    )
  }

  # Variant annotations
  if (n_variant_annotations > 0) {
    out <- paste0(
      out,
      "      ",
      gray("Variants:", output_type = output_type),
      " ",
      bold(n_variant_annotations, output_type = output_type),
      " variant annotations.\n"
    )
  }

  # Reference
  if (!is.null(x[["reference"]])) {
    out <- paste0(
      out,
      "     Reference: ",
      bold(x[["reference"]], output_type = output_type),
      "\n"
    )
  }

  out
} # /rtemis.a3::repr.A3


# %% print.A3 ----
#' Print method for `A3` object
#'
#' @method print A3
#' @param x `A3` object.
#' @param head_n Integer: Number of characters to show from the sequence.
#' @param ... Not used.
#'
#' @return Called for side effects, prints object to console
#'
#' @author EDG
#'
#' @noRd
method(print, A3) <- function(x, head_n = 10, ...) {
  cat(repr(x, head_n = head_n))
} # /rtemis.a3::print.A3


# %% as_A3 ----
#' as_A3
#'
#' @param x List: Named list with elements `Sequence`, `Annotations`, `UniprotID`.
#' `Annotations` is a named list with possible elements `Site`, `Region`, `PTM`,
#' `Cleavage_site`, `Variant`, `Description`, `Reference`.
#'
#' @return `A3` object.
#'
#' @author EDG
#' @export
as_A3 <- new_generic("as_A3", "x", function(x) {
  S7_dispatch()
})

method(as_A3, class_list) <- function(x) {
  create_A3(
    sequence = x[["sequence"]],
    site = x[["annotations"]][["site"]],
    region = x[["annotations"]][["region"]],
    ptm = x[["annotations"]][["ptm"]],
    cleavage_site = x[["annotations"]][["cleavage_site"]],
    variant = x[["annotations"]][["variant"]],
    uniprotid = x[["uniprotid"]],
    description = x[["description"]],
    reference = x[["reference"]]
  )
} # /rtemis.a3::as_A3.list


# %% plot.A3 ----
#' Plot method for `A3` object
#'
#' @param x `A3` object.
#' @param ... Additional arguments passed to [rtemis::draw_protein].
#'
#' @return `plotly` object.
#'
#' @author EDG
#' @export
plot.A3 <- method(plot, A3) <- function(x, ...) {
  rtemis::draw_protein(
    x = x[["sequence"]],
    site = x[["annotations"]][["site"]],
    region = x[["annotations"]][["region"]],
    ptm = x[["annotations"]][["ptm"]],
    cleavage_site = x[["annotations"]][["cleavage_site"]],
    variant = x[["annotations"]][["variant"]],
    ...
  )
} # /rtemis.a3::plot.A3


# %% summary.A3 ----
#' Summary method for `A3` object
#'
#' @param object `A3` object.
#' @param ... Not used
#'
#' @return Called for side effects, prints summary to console.
#'
#' @author EDG
#' @export
summary.A3 <- method(summary, A3) <- function(object, ...) {
  cat("Sequence length: ", length(object[["sequence"]]), "\n")
  if (!is.null(object[["uniprotid"]])) {
    cat("Uniprot ID: ", object[["uniprotid"]], "\n")
  }
  if (!is.null(object[["description"]])) {
    cat("Description: ", object[["description"]], "\n")
  }
  if (!is.null(object[["reference"]])) {
    cat("Reference: ", object[["reference"]], "\n")
  }
  cat("Annotations:\n")
  if (length(object[["annotations"]][["site"]]) > 0) {
    cat(length(object[["annotations"]][["site"]]), "site annotations.\n")
  }
  if (length(object[["annotations"]][["region"]]) > 0) {
    cat(length(object[["annotations"]][["region"]]), "region annotations.\n")
  }
  if (length(object[["annotations"]][["ptm"]]) > 0) {
    cat(length(object[["annotations"]][["ptm"]]), "PTM annotations.\n")
  }
  if (length(object[["annotations"]][["cleavage_site"]]) > 0) {
    cat(
      length(object[["annotations"]][["cleavage_site"]]),
      "cleavage site annotations.\n"
    )
  }
  if (length(object[["annotations"]][["variant"]]) > 0) {
    cat(length(object[["annotations"]][["variant"]]), "variant annotations.\n")
  }
} # /rtemis.a3::summary.A3


# %% int2range ----
#' Convert integer range to character with colon separator
#'
#' @param x Integer vector. Must be consecutive integers from lowest to highest.
#'
#' @return Character with colon separator.
#'
#' @author EDG
#' @keywords internal
#' @noRd
#'
#' @examples
#' x <- 34:42
#' int2range(x)
#' int2range(28:34)
#' int2range(c(3, 4, 5, 6))
#' # This will throw an error:
#' # int2range(c(3, 4, 5, 6, 8))
int2range <- function(x) {
  # Check that x consists of consecutive integers from loweest to highest
  isTRUE(all.equal(x, seq(min(x), max(x)))) ||
    cli::cli_abort("x must be consecutive integers from lowest to highest.")

  paste0(x[1], ":", x[length(x)])
} # /rtemis.a3::int2range
