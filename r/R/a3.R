# A3 S7 implementation
#  A3
#  ├── sequence:        character(1)
#  ├── annotations:     A3Annotations
#  │   ├── site:        named list of A3Site
#  │   ├── region:      named list of A3Region
#  │   ├── ptm:         named list of A3PTM
#  │   ├── processing:  named list of A3Processing
#  │   └── variant:     list of variant records (named lists)
#  └── metadata:        A3Metadata
#      ├── uniprot_id:  character(1)
#      ├── description: character(1)
#      ├── reference:   character(1)
#      └── organism:    character(1)
# The property declarations are the document shape: `a3_schema()` emits
# `schema/a3.schema.json` from these classes.
# 2026- EDG rtemis.org

.A3_SCHEMA_URI <- "https://schema.rtemis.org/a3/v1/schema.json"
.A3_VERSION <- "1.0.0"

# %% Declarations ----
.A3_POSITIONS <- prop_array(
  prop_integer(min = 1L),
  min_items = 0L,
  unique_items = TRUE,
  def_name = "positionIndex",
  description = "1-based residue positions, without repeats; any order."
)

.A3_RANGES <- prop_matrix(
  prop_integer(min = 1L),
  ncol = 2L,
  min_items = 0L,
  def_name = "rangeIndex",
  description = "Inclusive [start, end] residue ranges, 1-based; any order."
)

.A3_MIXED <- prop_union(
  list(.A3_POSITIONS, .A3_RANGES),
  def_name = "mixedIndex",
  description = "Residue positions or residue ranges; one kind per index."
)

.A3_TYPE <- prop_string(
  "",
  min_length = 0L,
  description = "Label of the annotation set."
)

.A3_VARIANT <- prop_struct(
  list(
    position = prop_integer(
      min = 1L,
      description = "1-based residue position of the variant."
    )
  ),
  additional_members = prop_any(),
  def_name = "variantRecord",
  description = "Sequence variant record. Members other than position are kept as written. The position is at most the sequence length, and a from member of one letter names the residue at that position, in either case."
)

.a3_metadata_field <- function(description) {
  prop_string("", min_length = 0L, description = description)
}


# %% .a3_range_problem ----
#' Describe the first range-order or range-overlap problem in an index
#'
#' @param index Integer vector or two-column integer matrix.
#'
#' @return Character scalar, or `NULL` when the index has no such problem or is
#' a position index.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_range_problem <- function(index) {
  if (!is.matrix(index) || nrow(index) == 0L) {
    return(NULL)
  }
  bad <- which(index[, 1L] >= index[, 2L])
  if (length(bad) > 0L) {
    i <- bad[[1L]]
    return(sprintf(
      "@index range [%d, %d] must have start < end.",
      index[i, 1L],
      index[i, 2L]
    ))
  }
  if (nrow(index) > 1L) {
    sorted <- index[order(index[, 1L], index[, 2L]), , drop = FALSE]
    overlap <- which(sorted[-1L, 1L] <= sorted[-nrow(sorted), 2L])
    if (length(overlap) > 0L) {
      i <- overlap[[1L]]
      return(sprintf(
        "@index ranges [%d, %d] and [%d, %d] must not overlap.",
        sorted[i, 1L],
        sorted[i, 2L],
        sorted[i + 1L, 1L],
        sorted[i + 1L, 2L]
      ))
    }
  }
  NULL
}


# %% A3Site ----
A3Site <- schema_class(
  "A3Site",
  package = "rtemis.a3",
  description = "A named set of single residues, given by position, with an optional type label. Every position is at most the sequence length.",
  properties = list(
    index = .A3_POSITIONS,
    type = .A3_TYPE
  )
)


# %% A3Region ----
A3Region <- schema_class(
  "A3Region",
  package = "rtemis.a3",
  description = "A named set of contiguous residue ranges, with an optional type label. In each range, start is less than end and end is at most the sequence length; no two ranges share a residue.",
  properties = list(
    index = .A3_RANGES,
    type = .A3_TYPE
  ),
  validator = function(self) .a3_range_problem(self@index)
)


# %% A3PTM ----
A3PTM <- schema_class(
  "A3PTM",
  package = "rtemis.a3",
  description = "A named set of post-translational modifications, given as residue positions or residue ranges, with an optional type label. Positions follow the rules of a site entry and ranges those of a region entry.",
  properties = list(
    index = .A3_MIXED,
    type = .A3_TYPE
  ),
  validator = function(self) .a3_range_problem(self@index)
)


# %% A3Processing ----
A3Processing <- schema_class(
  "A3Processing",
  package = "rtemis.a3",
  description = "A named set of processing events, such as signal peptides, cleavage sites, and maturation events, given as residue positions or residue ranges, with an optional type label. Positions follow the rules of a site entry and ranges those of a region entry.",
  properties = list(
    index = .A3_MIXED,
    type = .A3_TYPE
  ),
  validator = function(self) .a3_range_problem(self@index)
)


# %% A3Annotations ----
A3Annotations <- schema_class(
  "A3Annotations",
  package = "rtemis.a3",
  description = "Residue-level annotations, grouped into five families: site, region, ptm, processing, and variant.",
  properties = list(
    site = prop_map(
      prop_instance(A3Site),
      default = list(),
      min_members = 0L,
      description = "Named sets of single residues."
    ),
    region = prop_map(
      prop_instance(A3Region),
      default = list(),
      min_members = 0L,
      description = "Named sets of contiguous residue ranges."
    ),
    ptm = prop_map(
      prop_instance(A3PTM),
      default = list(),
      min_members = 0L,
      description = "Post-translational modifications, as positions or ranges."
    ),
    processing = prop_map(
      prop_instance(A3Processing),
      default = list(),
      min_members = 0L,
      description = "Signal peptides, cleavage sites, and maturation events, as positions or ranges."
    ),
    variant = prop_array(
      .A3_VARIANT,
      default = list(),
      min_items = 0L,
      description = "Sequence variant records, in order."
    )
  )
)


# %% A3Metadata ----
A3Metadata <- schema_class(
  "A3Metadata",
  package = "rtemis.a3",
  description = "Free-text metadata about the protein. The empty string records an absent value.",
  properties = list(
    uniprot_id = .a3_metadata_field("UniProt accession."),
    description = .a3_metadata_field("Protein description."),
    reference = .a3_metadata_field("Citation or URL."),
    organism = .a3_metadata_field("Species name.")
  )
)


# %% A3 ----
A3 <- schema_class(
  "A3",
  package = "rtemis.a3",
  description = "Amino Acid Annotation (A3): an amino acid sequence with named sets of residue-level annotations.",
  publication = SchemaPublication(
    scope = "shared",
    domain = "domain",
    kind = "data"
  ),
  properties = list(
    sequence = prop_string(
      pattern = "^[A-Za-z*]+$",
      min_length = 2L,
      description = "Amino acid sequence in IUPAC one-letter codes, with '*' for a stop codon. Lower case is accepted and converted to upper case when read."
    ),
    annotations = prop_instance(
      A3Annotations,
      default = quote(A3Annotations()),
      description = "Annotation sets by family."
    ),
    metadata = prop_instance(
      A3Metadata,
      default = quote(A3Metadata()),
      description = "Protein metadata."
    )
  ),
  constructor = function(
    sequence,
    annotations = A3Annotations(),
    metadata = A3Metadata()
  ) {
    new_object(
      S7_object(),
      sequence = toupper(sequence),
      annotations = annotations,
      metadata = metadata
    )
  },
  validator = function(self) .a3_context_problems(self)
)


# %% .a3_context_problems ----
#' Compare every index and variant with the sequence
#'
#' Reports indices and variant positions beyond the sequence length, and
#' variants whose single-character `from` differs from the residue at their
#' position, as `A3E_POS_OUT_OF_BOUNDS`, `A3E_RANGE_OUT_OF_BOUNDS`,
#' `A3E_VARIANT_OUT_OF_BOUNDS`, and `A3E_VARIANT_RESIDUE_MISMATCH` do for a
#' document.
#'
#' @param self `A3` object.
#'
#' @return Character vector of problems, or `NULL`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_context_problems <- function(self) {
  n <- nchar(self@sequence)
  problems <- character(0L)
  for (family in .A3_NAMED_FAMILIES) {
    entries <- prop(self@annotations, family)
    for (name in names(entries)) {
      index <- entries[[name]]@index
      if (length(index) > 0L && max(index) > n) {
        problems <- c(
          problems,
          sprintf(
            "@annotations@%s[[\"%s\"]] has a position greater than the sequence length, %d.",
            family,
            name,
            n
          )
        )
      }
    }
  }
  residues <- strsplit(toupper(self@sequence), "", fixed = TRUE)[[1L]]
  variants <- self@annotations@variant
  for (i in seq_along(variants)) {
    position <- variants[[i]][["position"]]
    from <- variants[[i]][["from"]]
    if (position > n) {
      problems <- c(
        problems,
        sprintf(
          "@annotations@variant[[%d]] position %d is greater than the sequence length, %d.",
          i,
          position,
          n
        )
      )
    } else if (
      is.character(from) &&
        length(from) == 1L &&
        nchar(from) == 1L &&
        toupper(from) != residues[[position]]
    ) {
      problems <- c(
        problems,
        sprintf(
          "@annotations@variant[[%d]] from '%s' differs from residue %d, '%s'.",
          i,
          from,
          position,
          residues[[position]]
        )
      )
    }
  }
  if (length(problems) > 0L) problems
}


# %% .a3_entry_base ----
#' Annotation entry as a named list
#'
#' @param entry `A3Site`, `A3Region`, `A3PTM`, or `A3Processing` object.
#'
#' @return Named list with `type` and `index`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_entry_base <- function(entry) {
  list(type = entry@type, index = entry@index)
}


# %% .a3_base ----
#' Property value of an `A3` object as base R data
#'
#' `A3Annotations` becomes a named list of families, each entry a list with
#' `type` and `index` (an integer vector or a two-column integer matrix), and
#' `variant` a list of variant records; `A3Metadata` becomes a named list of
#' strings; any other value is returned as is.
#'
#' @param value Property value.
#'
#' @return Base R value.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_base <- function(value) {
  if (S7_inherits(value, A3Annotations)) {
    list(
      site = lapply(value@site, .a3_entry_base),
      region = lapply(value@region, .a3_entry_base),
      ptm = lapply(value@ptm, .a3_entry_base),
      processing = lapply(value@processing, .a3_entry_base),
      variant = value@variant
    )
  } else if (S7_inherits(value, A3Metadata)) {
    props(value)
  } else {
    value
  }
}


# %% `.DollarNames.A3` ----
method(`.DollarNames`, A3) <- function(x, pattern = "") {
  grep(pattern, prop_names(x), value = TRUE)
}


# %% `$.A3` ----
method(`$`, A3) <- function(x, name) {
  .a3_base(prop(x, name))
}


# %% `[[.A3` ----
method(`[[`, A3) <- function(x, name) {
  .a3_base(prop(x, name))
}


# %% repr.A3 ----
method(repr, A3) <- function(x, output_type = NULL, head_n = 10L) {
  out <- repr_S7name("A3", output_type = output_type)

  # Metadata
  labels <- c(
    description = "  Description: ",
    uniprot_id = "   Uniprot ID: ",
    organism = "     Organism: ",
    reference = "    Reference: "
  )
  for (field in names(labels)) {
    value <- prop(x@metadata, field)
    if (nzchar(value)) {
      out <- paste0(
        out,
        labels[[field]],
        bold(value, output_type = output_type),
        "\n"
      )
    }
  }

  # Sequence
  seq_length <- nchar(x@sequence)
  display_seq <- if (seq_length > head_n) {
    paste0(substr(x@sequence, 1L, head_n), "...")
  } else {
    x@sequence
  }
  out <- paste0(
    out,
    "     Sequence: ",
    bold(display_seq, output_type = output_type),
    " (length = ",
    seq_length,
    ")\n"
  )

  # Annotations
  ann <- x@annotations
  out <- paste0(out, "  Annotations:\n")
  n_processing <- length(ann@processing)
  n_variant <- length(ann@variant)
  if (
    length(ann@site) +
      length(ann@region) +
      length(ann@ptm) +
      n_processing +
      n_variant ==
      0L
  ) {
    out <- paste0(out, gray("             None\n", output_type = output_type))
  }
  named <- list(
    list("          ", "Site:", names(ann@site)),
    list("        ", "Region:", names(ann@region)),
    list("           ", "PTM:", names(ann@ptm))
  )
  for (row in named) {
    if (length(row[[3L]]) > 0L) {
      out <- paste0(
        out,
        row[[1L]],
        gray(row[[2L]], output_type = output_type),
        " ",
        paste(bold(row[[3L]], output_type = output_type), collapse = ", "),
        "\n"
      )
    }
  }
  counted <- list(
    list("    ", "Processing:", n_processing),
    list("      ", "Variants:", n_variant)
  )
  for (row in counted) {
    if (row[[3L]] > 0L) {
      out <- paste0(
        out,
        row[[1L]],
        gray(row[[2L]], output_type = output_type),
        " ",
        bold(row[[3L]], output_type = output_type),
        ngettext(row[[3L]], " annotation\n", " annotations\n")
      )
    }
  }

  out
}


# %% print.A3 ----
method(print, A3) <- function(x, output_type = NULL, ...) {
  cat(repr(x, output_type = output_type))
  invisible(x)
}


# %% Public API ----
# `create_A3()` builds an `A3` object from base R values:
# * sequence: character(1), or single letters joined by `concat()`
# * site: named list of `annotation_position()` values
# * region: named list of `annotation_range()` values
# * ptm, processing: named lists of `annotation_position()` or `annotation_range()` values
# * variant: list of `annotation_variant()` values
# * uniprot_id, description, reference, organism: character(1)

# %% concat ----
#' Concatenate character vector to single string for sequence input
#'
#' @param x Character vector to concatenate
#'
#' @return Single character string
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Concatenate a character vector of single-letter amino acids into a sequence string
#' concat(c("M", "A", "E", "P", "R"))
concat <- function(x) {
  check_inherits(x, "character")
  if (length(x) > 1) {
    if (any(nchar(x) != 1)) {
      cli::cli_abort(
        "All elements of sequence vector must be single characters."
      )
    }
    paste(x, collapse = "")
  } else {
    x
  }
}


# %% .a3_type_or_empty ----
#' Annotation type, with `NULL` as the empty string
#'
#' @param type Optional character scalar.
#' @param arg_name Character scalar: Argument name for error messages.
#'
#' @return Character scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_type_or_empty <- function(type, arg_name = "type") {
  check_optional_scalar_character(type, arg_name = arg_name)
  if (is.null(type)) "" else type
}


# %% annotation_position ----
#' Create position-based annotations for A3
#'
#' Creates an annotation entry with a position index, for the `site`, `ptm`,
#' and `processing` arguments of `create_A3()`.
#'
#' @param x Integer vector: Positions of the annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type. `NULL` is treated as
#' the empty string in the canonical A3 representation.
#'
#' @return Named list with `index` (integer vector, sorted) and `type`
#' (character).
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a site annotation for positions 5 and 17, of type "active site"
#' annotation_position(c(5L, 17L), type = "active site")
annotation_position <- function(x, type = NULL) {
  type <- .a3_type_or_empty(type)
  index <- clean_int(x)
  if (anyNA(index) || any(index < 1L)) {
    cli::cli_abort("Positions must be integers >= 1.")
  }
  if (anyDuplicated(index) > 0L) {
    cli::cli_abort("Positions must be unique.")
  }
  list(index = sort(as.vector(index)), type = type)
}


# %% annotation_range ----
#' Create range-based annotations for A3
#'
#' Creates an annotation entry with a range index, for the `region`, `ptm`, and
#' `processing` arguments of `create_A3()`.
#'
#' @param x Integer matrix with 2 columns corresponding to start and end positions of the
#' annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type. `NULL` is treated as
#' the empty string in the canonical A3 representation.
#'
#' @return Named list with `index` (two-column integer matrix, sorted by start)
#' and `type` (character).
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a region annotation for ranges 3-10 and 15-22, of type "repeat"
#' annotation_range(rbind(c(3L, 10L), c(15L, 22L)), type = "repeat")
annotation_range <- function(x, type = NULL) {
  type <- .a3_type_or_empty(type)
  if (!is.matrix(x) || ncol(x) != 2L) {
    cli::cli_abort("Ranges must be a matrix with 2 columns.")
  }
  index <- matrix(clean_int(as.vector(x)), ncol = 2L)
  if (anyNA(index) || any(index < 1L)) {
    cli::cli_abort("Range endpoints must be integers >= 1.")
  }
  problem <- .a3_range_problem(index)
  if (!is.null(problem)) {
    cli::cli_abort(sub("^@index r", "R", problem))
  }
  list(
    index = index[order(index[, 1L], index[, 2L]), , drop = FALSE],
    type = type
  )
}


# %% annotation_variant ----
#' Create variant annotations for A3
#'
#' Creates a variant record: a named list with `position` first, followed by
#' the members of `info` in order.
#'
#' @param x Integer scalar: Position of the variant (1-based indexing).
#' @param info Named list: Additional information about the variant (e.g. reference and alternate
#' amino acids, variant type, etc.)
#'
#' @return Named list: the variant record.
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a variant annotation for position 10 with info about the variant
#' annotation_variant(10L, info = list(from = "A", to = "T", type = "missense"))
annotation_variant <- function(x, info = list()) {
  check_inherits(info, "list")
  position <- clean_int(x)
  if (length(position) != 1L || is.na(position) || position < 1L) {
    cli::cli_abort("Variant position must be a single integer >= 1.")
  }
  if (length(info) > 0L) {
    nms <- names(info)
    if (is.null(nms) || anyNA(nms) || any(!nzchar(nms)) || anyDuplicated(nms)) {
      cli::cli_abort(
        "Every member of {.arg info} must have a distinct, non-empty name."
      )
    }
    if ("position" %in% nms) {
      cli::cli_abort("{.arg info} must not have a member named 'position'.")
    }
  }
  c(list(position = as.vector(position)), info)
}


# %% create_A3 ----
#' Create an A3 object from sequence, annotations, and metadata
#'
#' @param sequence Character scalar: Amino acid sequence string.
#' @param site Named list of site annotations, created with
#' [annotation_position()].
#' @param region Named list of region annotations, created with
#' [annotation_range()].
#' @param ptm Named list of PTM annotations, created with
#' [annotation_position()] or [annotation_range()].
#' @param processing Named list of processing annotations, created with
#' [annotation_position()] or [annotation_range()].
#' @param variant List of variant records, created with
#' [annotation_variant()].
#' @param uniprot_id Optional character scalar: UniProt accession.
#' @param description Optional character scalar: Protein description.
#' @param reference Optional character scalar: Citation or URL.
#' @param organism Optional character scalar: Species name.
#'
#' @return A3 object
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Minimal: sequence only
#' a <- create_A3("MAEPRQEFEVMEDHAGTYGLGDRK")
#'
#' # With site, region, and PTM annotations
#' a <- create_A3(
#'   "MAEPRQEFEVMEDHAGTYGLGDRK",
#'   site = list(
#'     Active_site = annotation_position(c(5L, 17L), type = "active site")
#'   ),
#'   region = list(
#'     Domain = annotation_range(rbind(c(3L, 10L), c(15L, 22L)),
#'       type = "repeat"
#'     )
#'   ),
#'   ptm = list(
#'     Phosphorylation = annotation_position(c(2L, 18L), type = "phosphoserine")
#'   ),
#'   uniprot_id = "P10636",
#'   organism = "Homo sapiens"
#' )
create_A3 <- function(
  sequence,
  site = list(),
  region = list(),
  ptm = list(),
  processing = list(),
  variant = list(),
  uniprot_id = NULL,
  description = NULL,
  reference = NULL,
  organism = NULL
) {
  check_scalar_character(sequence, arg_name = "sequence")
  check_inherits(site, "list")
  check_inherits(region, "list")
  check_inherits(ptm, "list")
  check_inherits(processing, "list")
  check_inherits(variant, "list")
  as_entries <- function(entries, cls) {
    lapply(entries, function(entry) {
      if (S7_inherits(entry, cls)) {
        entry
      } else {
        cls(
          index = entry[["index"]],
          type = .a3_type_or_empty(entry[["type"]])
        )
      }
    })
  }
  A3(
    sequence = concat(sequence),
    annotations = A3Annotations(
      site = as_entries(site, A3Site),
      region = as_entries(region, A3Region),
      ptm = as_entries(ptm, A3PTM),
      processing = as_entries(processing, A3Processing),
      variant = unname(variant)
    ),
    metadata = A3Metadata(
      uniprot_id = .a3_type_or_empty(uniprot_id, "uniprot_id"),
      description = .a3_type_or_empty(description, "description"),
      reference = .a3_type_or_empty(reference, "reference"),
      organism = .a3_type_or_empty(organism, "organism")
    )
  )
}


# %% to_json ----
#' Write an `A3` object as A3 JSON text
#'
#' Each property is written by its declaration through `prop_encode()`, after
#' the `$schema` and `a3_version` members.
#'
#' @param x `A3` object.
#' @param pretty Logical: if TRUE, pretty-print JSON output.
#'
#' @return Character scalar: JSON text.
#'
#' @author EDG
#' @keywords internal
#' @noRd
to_json <- function(x, pretty = TRUE) {
  document <- c(
    list(`$schema` = .A3_SCHEMA_URI, a3_version = .A3_VERSION),
    prop_encode(prop_instance(A3), x)
  )
  to_JSON(document, pretty = pretty)
}


# %% .a3_parse_json ----
#' Parse A3 JSON text into a raw nested list
#'
#' All simplification is switched off so that the raw validator sees the
#' document exactly as written: objects stay named lists, arrays stay unnamed
#' lists, and a one-element array does not collapse into a scalar.
#'
#' @param text Character scalar: JSON text.
#'
#' @return List: Raw parsed JSON.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_parse_json <- function(text) {
  tryCatch(
    jsonlite::fromJSON(
      text,
      simplifyVector = FALSE,
      simplifyDataFrame = FALSE,
      simplifyMatrix = FALSE
    ),
    error = function(err) {
      # A file that is not JSON has no path to report and nothing further to
      # collect, so it is a single fatal error rather than a validation issue.
      cli::cli_abort(
        c(
          "Input is not valid JSON.",
          "x" = conditionMessage(err),
          "i" = "Check the file with a JSON linter before validating it as A3."
        ),
        class = c("a3_parse_error", "rtemis_error")
      )
    }
  )
}


# %% .a3_abort_issues ----
#' Abort once, listing every issue
#'
#' The issue list is attached to the condition object so that a caller can reach
#' it programmatically instead of parsing the message.
#'
#' @param issues List: Issues from `validate_a3_raw()`.
#' @param what Character scalar: What was being validated, for the headline.
#'
#' @return Called for its side effect.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_abort_issues <- function(issues, what) {
  stage <- .A3_ISSUE_STAGES[[issues[[1L]][["code"]]]]
  bullets <- vapply(
    issues,
    function(issue) {
      where <- if (nzchar(issue[["path"]])) issue[["path"]] else "<document>"
      paste0(
        "{.strong ",
        issue[["code"]],
        "} ",
        where,
        ": ",
        issue[["message"]]
      )
    },
    character(1L)
  )
  names(bullets) <- rep("x", length(bullets))
  cli::cli_abort(
    c(
      "{what} is not a valid A3 document: {length(issues)} issue{?s} at stage {stage}.",
      bullets
    ),
    class = c("a3_validation_error", "rtemis_error"),
    issues = issues
  )
}


# %% validate_A3json ----
#' Validate an A3 JSON file without throwing
#'
#' Returns every validation issue found in the earliest failing stage, as a data
#' frame. An empty data frame means the document is valid. It suits forms and
#' reports; [read_A3json()] returns the object, or an error if the object cannot
#' be built.
#'
#' Each issue carries a stable `code` and an RFC 6901 JSON Pointer `path`, both
#' of which are identical across the R, Python, Julia, TypeScript, and Rust
#' implementations of A3. The `message` is for humans and is not contractual.
#'
#' @param filepath Character scalar: Path to a JSON file.
#'
#' @return Data frame with columns `code`, `stage`, `path`, and `message`, with
#' zero rows when the document is valid.
#'
#' @author EDG
#' @export
#'
#' @examples
#' a3 <- create_A3("MAEPRQEFEVMEDHAGTYGLGDRK", uniprot_id = "P10636")
#' tmp <- tempfile(fileext = ".json")
#' write_A3json(a3, tmp)
#' validate_A3json(tmp) # zero rows: the document is valid
#' unlink(tmp)
validate_A3json <- function(filepath) {
  check_scalar_character(filepath, arg_name = "filepath")
  if (!file.exists(filepath)) {
    cli::cli_abort("File {.file {filepath}} does not exist.")
  }
  text <- paste(readLines(filepath, warn = FALSE), collapse = "\n")
  issues <- validate_a3_raw(.a3_parse_json(text))[["issues"]]
  .a3_issues_to_df(issues)
}


# %% .a3_issues_to_df ----
#' Convert an issue list to a data frame
#'
#' @param issues List: Issues from `validate_a3_raw()`.
#'
#' @return Data frame with columns `code`, `stage`, `path`, and `message`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_issues_to_df <- function(issues) {
  data.frame(
    code = vapply(issues, function(i) i[["code"]], character(1L)),
    stage = vapply(
      issues,
      function(i) .A3_ISSUE_STAGES[[i[["code"]]]],
      integer(1L)
    ),
    path = vapply(issues, function(i) i[["path"]], character(1L)),
    message = vapply(issues, function(i) i[["message"]], character(1L)),
    stringsAsFactors = FALSE
  )
}


# %% A3from_json ----
#' Create an A3 object from a JSON string
#'
#' Runs the four validation stages and aborts once with every issue found in the
#' earliest failing stage.
#'
#' @param x Character scalar: JSON string.
#' @param ... Additional arguments (currently unused).
#'
#' @return `A3` object.
#'
#' @author EDG
#' @keywords internal
#' @noRd
A3from_json <- function(x, ...) {
  check_scalar_character(x, arg_name = "x")
  result <- validate_a3_raw(.a3_parse_json(x))
  if (length(result[["issues"]]) > 0L) {
    .a3_abort_issues(result[["issues"]], "Input")
  }
  result[["a3"]]
}


#' Write `A3` object to JSON file
#'
#' @param x `A3` object.
#' @param filepath Character: Path to save JSON file.
#' @param overwrite Logical: If TRUE, overwrite existing file.
#'
#' @return Invisible `x`. Writes JSON file as side effect.
#'
#' @author EDG
#' @export
#'
#' @examples
#' a3 <- create_A3("MAEPRQEFEVMEDHAGTYGLGDRK", uniprot_id = "P10636")
#' tmp <- tempfile(fileext = ".json")
#' write_A3json(a3, tmp)
#' a3_read <- read_A3json(tmp)
#' unlink(tmp)
write_A3json <- function(x, filepath, overwrite = FALSE) {
  check_is_S7(x, A3)
  check_scalar_character(filepath, arg_name = "filepath")
  check_scalar_logical(overwrite, arg_name = "overwrite")
  filepath <- normalizePath(filepath, mustWork = FALSE)
  if (file.exists(filepath) && !overwrite) {
    cli::cli_abort(
      "File {.file {filepath}} exists. Set {.arg overwrite = TRUE} to overwrite."
    )
  }
  writeLines(to_json(x), filepath)
  invisible(x)
}

#' Read `A3` object from JSON file
#'
#' Validation is **collect-all**: the document is checked in four stages and
#' every issue in the earliest failing stage is reported at once, each with a
#' stable code and an RFC 6901 JSON Pointer. Use [validate_A3json()] for a
#' non-throwing entry point that returns the issues instead.
#'
#' @param filepath Character: Path to JSON file.
#' @param verbosity Integer: if greater than 0, print messages.
#'
#' @return `A3` object.
#'
#' @author EDG
#' @export
#'
#' @examples
#' a3 <- create_A3("MAEPRQEFEVMEDHAGTYGLGDRK", uniprot_id = "P10636")
#' tmp <- tempfile(fileext = ".json")
#' write_A3json(a3, tmp)
#' a3_read <- read_A3json(tmp, verbosity = 0L)
#' unlink(tmp)
read_A3json <- function(filepath, verbosity = 1L) {
  check_scalar_character(filepath, arg_name = "filepath")
  filepath <- normalizePath(filepath)
  if (!file.exists(filepath)) {
    cli::cli_abort("File {.file {filepath}} does not exist.")
  }
  json_str <- paste(readLines(filepath, warn = FALSE), collapse = "\n")
  result <- validate_a3_raw(.a3_parse_json(json_str))
  if (length(result[["issues"]]) > 0L) {
    .a3_abort_issues(result[["issues"]], basename(filepath))
  }
  obj <- result[["a3"]]
  if (verbosity > 0L) {
    msg(
      "Read ",
      basename(filepath),
      ": ",
      fmt("\u2714 ", col = rtemis_colors[["green"]]),
      "valid A3 ",
      .A3_VERSION,
      sep = ""
    )
  }
  obj
}
