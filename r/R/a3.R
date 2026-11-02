# A3 S7 implementation
#  A3
#  ├── sequence:        A3Sequence
#  ├── annotations:     A3Annotation
#  │   ├── site:        list of A3Site
#  │   ├── region:      list of A3Region
#  │   ├── ptm:         list of A3PTM
#  │   ├── processing:  list of A3Processing
#  │   └── variant:     list of A3Variant
#  └── metadata:        A3Metadata
#      ├── uniprot_id:  character(1)
#      ├── description: character(1)
#      ├── reference:   character(1)
#      └── organism:    character(1)
# 2026- EDG rtemis.org

.A3_SCHEMA_URI <- "https://schema.rtemis.org/a3/v1/schema.json"
.A3_VERSION <- "1.0.0"

# %% Level 1: A3Sequence ----
A3Sequence <- new_class(
  "A3Sequence",
  properties = list(
    data = class_character
  ),
  constructor = function(data) {
    new_object(
      S7_object,
      data = toupper(data)
    )
  },
  validator = function(self) {
    if (length(self@data) > 1) {
      cli::cli_abort("Sequence must be a single string.")
    }
    if (nchar(self@data) < 2) {
      cli::cli_abort("Sequence must be at least 2 characters long.")
    }
    if (!grepl("^[A-Z*]+$", self@data)) {
      cli::cli_abort(
        "Sequence must only contain uppercase letters [A-Z] and '*'."
      )
    }
  }
)


# %% to_base.A3Sequence ----
#' Convert A3Sequence to base character string
#'
#' @param x A3Sequence object
#' @return Character string of the sequence
#' @author EDG
#' @keywords internal
#' @noRd
method(to_base, A3Sequence) <- function(x) {
  x@data
}


# %% A3Index ----
# Abstract superclass for A3Position and A3Range, encoding the location of `A3Feature` objects.
A3Index <- new_class(
  "A3Index",
  properties = list(
    data = class_integer
  ),
  abstract = TRUE
)


# %% A3Position ----
# A3Index subclass for individual residue annotations
# Used by `A3Site`, `A3PTM`, and `A3Processing`.
A3Position <- new_class(
  "A3Position",
  parent = A3Index,
  constructor = function(data) {
    new_object(
      S7_object(),
      data = sort(data)
    )
  },
  validator = function(self) {
    if (any(self@data < 1)) {
      cli::cli_abort("Position data must be a positive integer.")
    }
    if (any(duplicated(self@data))) {
      cli::cli_abort("Position data must be unique.")
    }
  }
)


# %% A3Range ----
# A3Index subclass for range annotations
A3Range <- new_class(
  "A3Range",
  parent = A3Index,
  constructor = function(data) {
    # Sort by start position
    idx <- order(data[, 1])
    colnames(data) <- c("start", "end")
    new_object(
      S7_object(),
      data = data[idx, , drop = FALSE]
    )
  },
  validator = function(self) {
    if (ncol(self@data) != 2L) {
      cli::cli_abort("Range must be a matrix with 2 columns.")
    }
    if (any(self@data[, 1] >= self@data[, 2])) {
      cli::cli_abort("Start of range must be less than end of range.")
    }
    if (any(self@data < 1L)) {
      cli::cli_abort("Range values must be positive integers.")
    }
    if (nrow(self@data) > 1L) {
      starts <- self@data[-1L, 1L]
      ends <- self@data[-nrow(self@data), 2L]
      overlap_idx <- which(starts <= ends)
      if (length(overlap_idx) > 0L) {
        i <- overlap_idx[[1L]]
        cli::cli_abort(
          "Range entries must not overlap. \\
          Found: [{self@data[i, 1]}, {self@data[i, 2]}] and \\
          [{self@data[i + 1L, 1]}, {self@data[i + 1L, 2]}]."
        )
      }
    }
  }
)


# %% A3Feature ----
# Abstract base class for annotation feature types.
A3Feature <- new_class(
  "A3Feature",
  properties = list(
    type = class_character
  ),
  abstract = TRUE
)


# %% A3Site ----
A3Site <- new_class(
  "A3Site",
  parent = A3Feature,
  properties = list(
    index = A3Position
  ),
  constructor = function(index, type = "") {
    new_object(
      S7_object(),
      index = index,
      type = type
    )
  }
)


# %% A3Region ----
A3Region <- new_class(
  "A3Region",
  parent = A3Feature,
  properties = list(
    index = A3Range
  ),
  constructor = function(index, type = "") {
    new_object(
      S7_object(),
      index = index,
      type = type
    )
  }
)


# %% A3PTM ----
A3PTM <- new_class(
  "A3PTM",
  parent = A3Feature,
  properties = list(
    index = A3Index
  ),
  constructor = function(index, type = "") {
    new_object(
      S7_object(),
      index = index,
      type = type
    )
  }
)


# %% A3Processing ----
A3Processing <- new_class(
  "A3Processing",
  parent = A3Feature,
  properties = list(
    index = A3Index
  ),
  constructor = function(index, type = "") {
    new_object(
      S7_object(),
      index = index,
      type = type
    )
  }
)


# %% A3Variant ----
# `position` is a plain integer, not an `A3Position`: an A3Position is a whole
# index object, and wrapping one integer in it bought a length-1 assertion at the
# cost of surprising every reader and every accessor.
A3Variant <- new_class(
  "A3Variant",
  properties = list(
    position = class_integer,
    info = class_list
  ),
  validator = function(self) {
    if (length(self@position) != 1L) {
      cli::cli_abort("Variant position must be a single integer.")
    }
    if (self@position < 1L) {
      cli::cli_abort("Variant position must be >= 1; positions are 1-based.")
    }
  }
)


# %% Level 1: A3Annotation ----
A3Annotation <- new_class(
  "A3Annotation",
  properties = list(
    site = class_list,
    region = class_list,
    ptm = class_list,
    processing = class_list,
    variant = class_list
  ),
  validator = function(self) {
    # `vapply(..., logical(1L))` guarantees a logical vector; `sapply()` returns
    # a list for a zero-length input, and `all(list())` is TRUE only by accident.
    all_inherit <- function(lst, cls) {
      length(lst) == 0L ||
        all(vapply(lst, S7_inherits, logical(1L), class = cls))
    }
    check_names <- function(lst, category) {
      nms <- names(lst)
      if (length(lst) > 0L && (is.null(nms) || any(!nzchar(nms)))) {
        cli::cli_abort(
          "All {category} annotation names must be non-empty strings."
        )
      }
    }
    if (!all_inherit(self@site, A3Site)) {
      cli::cli_abort("All site annotations must be A3Site objects.")
    }
    check_names(self@site, "site")
    if (!all_inherit(self@region, A3Region)) {
      cli::cli_abort("All region annotations must be A3Region objects.")
    }
    check_names(self@region, "region")
    if (!all_inherit(self@ptm, A3PTM)) {
      cli::cli_abort("All PTM annotations must be A3PTM objects.")
    }
    check_names(self@ptm, "ptm")
    if (!all_inherit(self@processing, A3Processing)) {
      cli::cli_abort("All processing annotations must be A3Processing objects.")
    }
    check_names(self@processing, "processing")
    if (!all_inherit(self@variant, A3Variant)) {
      cli::cli_abort("All variant annotations must be A3Variant objects.")
    }
  }
)


# %% to_base.A3Annotation ----
#' Convert A3Annotation to base R list format
#'
#' @param x A3Annotation object
#' @return Named list with site, region, ptm, processing, and variant annotations
#' @author EDG
#' @keywords internal
#' @noRd
method(to_base, A3Annotation) <- function(x) {
  list(
    site = lapply(x@site, function(site) {
      list(
        type = site@type,
        index = site@index@data
      )
    }),
    region = lapply(x@region, function(region) {
      list(
        type = region@type,
        index = region@index@data
      )
    }),
    ptm = lapply(x@ptm, function(ptm) {
      list(
        type = ptm@type,
        index = ptm@index@data
      )
    }),
    processing = lapply(x@processing, function(proc) {
      list(
        type = proc@type,
        index = proc@index@data
      )
    }),
    variant = lapply(x@variant, function(v) {
      out <- list(position = v@position)
      # Single-bracket assignment, not double: `out[[nm]] <- NULL` would delete
      # the element rather than store a JSON null, dropping it from the output.
      for (nm in names(v@info)) {
        out[nm] <- list(v@info[[nm]])
      }
      out
    })
  )
}


# %% Metadata ----
Metadata <- new_class(
  "Metadata"
)


# %% Level 1: A3Metadata ----
A3Metadata <- new_class(
  "A3Metadata",
  parent = Metadata,
  properties = list(
    uniprot_id = class_character,
    description = class_character,
    reference = class_character,
    organism = class_character
  ),
  constructor = function(
    uniprot_id = "",
    description = "",
    reference = "",
    organism = ""
  ) {
    new_object(
      Metadata(),
      uniprot_id = uniprot_id,
      description = description,
      reference = reference,
      organism = organism
    )
  },
  validator = function(self) {
    if (length(self@uniprot_id) != 1L) {
      cli::cli_abort(
        "{.arg uniprot_id} must be a single string (character(1))."
      )
    }
    if (length(self@description) != 1L) {
      cli::cli_abort(
        "{.arg description} must be a single string (character(1))."
      )
    }
    if (length(self@reference) != 1L) {
      cli::cli_abort("{.arg reference} must be a single string (character(1)).")
    }
    if (length(self@organism) != 1L) {
      cli::cli_abort("{.arg organism} must be a single string (character(1)).")
    }
  }
)


# %% to_base.A3Metadata ----
#' Convert A3Metadata to base R list format
#'
#' @param x A3Metadata object
#' @return Named list with uniprot_id, description, reference, and organism
#' @author EDG
#' @keywords internal
#' @noRd
method(to_base, A3Metadata) <- function(x) {
  list(
    uniprot_id = x@uniprot_id,
    description = x@description,
    reference = x@reference,
    organism = x@organism
  )
}


# %% A3 ----
A3 <- new_class(
  "A3",
  properties = list(
    sequence = A3Sequence,
    annotations = A3Annotation,
    metadata = A3Metadata
  ),
  validator = function(self) {
    seq_length <- nchar(self@sequence@data)

    # Validate site annotations
    for (site in self@annotations@site) {
      if (any(site@index@data > seq_length)) {
        cli::cli_abort(
          "Site annotation positions must be within the sequence length."
        )
      }
    }

    # Validate region annotations
    for (region in self@annotations@region) {
      if (any(region@index@data > seq_length)) {
        cli::cli_abort(
          "Region annotation positions must be within the sequence length."
        )
      }
    }

    # Validate PTM annotations
    for (ptm in self@annotations@ptm) {
      if (any(ptm@index@data > seq_length)) {
        cli::cli_abort(
          "PTM annotation positions must be within the sequence length."
        )
      }
    }

    # Validate processing annotations
    for (proc in self@annotations@processing) {
      if (any(proc@index@data > seq_length)) {
        cli::cli_abort(
          "Processing annotation positions must be within the sequence length."
        )
      }
    }

    # Validate variant annotations
    for (variant in self@annotations@variant) {
      if (variant@position > seq_length) {
        cli::cli_abort(
          "Variant annotation position must be within the sequence length."
        )
      }
    }
  }
)


# %% `.DollarNames.A3` ----
method(`.DollarNames`, A3) <- function(x, pattern = "") {
  grep(pattern, prop_names(x), value = TRUE)
}


# %% `$.A3` ----
method(`$`, A3) <- function(x, name) {
  to_base(prop(x, name))
}


# %% `[[.A3` ----
method(`[[`, A3) <- function(x, name) {
  to_base(prop(x, name))
}


# %% to_base.A3 ----
method(to_base, A3) <- function(x) {
  list(
    sequence = to_base(x@sequence),
    annotations = to_base(x@annotations),
    metadata = to_base(x@metadata)
  )
}


# %% repr.A3 ----
method(repr, A3) <- function(x, output_type = NULL, head_n = 10L) {
  out <- repr_S7name("A3", output_type = output_type)

  # Metadata
  ## Description
  if (nchar(x@metadata@description) > 0) {
    out <- paste0(
      out,
      "  Description: ",
      bold(x@metadata@description, output_type = output_type),
      "\n"
    )
  }

  ## Uniprot ID
  if (nchar(x@metadata@uniprot_id) > 0) {
    out <- paste0(
      out,
      "   Uniprot ID: ",
      bold(x@metadata@uniprot_id, output_type = output_type),
      "\n"
    )
  }

  ## Organism
  if (nchar(x@metadata@organism) > 0) {
    out <- paste0(
      out,
      "     Organism: ",
      bold(x@metadata@organism, output_type = output_type),
      "\n"
    )
  }

  ## Reference
  if (nchar(x@metadata@reference) > 0) {
    out <- paste0(
      out,
      "    Reference: ",
      bold(x@metadata@reference, output_type = output_type),
      "\n"
    )
  }

  # Sequence
  seq_length <- nchar(x@sequence@data)
  display_seq <- if (seq_length > head_n) {
    paste0(substr(x@sequence@data, 1L, head_n), "...")
  } else {
    x@sequence@data
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
  # Get annotation info
  site_annotations <- names(x@annotations@site)
  region_annotations <- names(x@annotations@region)
  ptm_annotations <- names(x@annotations@ptm)
  n_processing_annotations <- length(x@annotations@processing)
  n_variant_annotations <- length(x@annotations@variant)

  out <- paste0(out, "  Annotations:\n")

  # Check if no annotations
  if (
    is.null(site_annotations) &&
      is.null(region_annotations) &&
      is.null(ptm_annotations) &&
      n_processing_annotations == 0 &&
      n_variant_annotations == 0
  ) {
    out <- paste0(out, gray("             None\n", output_type = output_type))
  }

  ## Site annotations
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

  ## Region annotations
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

  ## PTM annotations
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

  ## Processing annotations
  if (n_processing_annotations > 0) {
    out <- paste0(
      out,
      " ",
      gray("   Processing:", output_type = output_type),
      " ",
      bold(n_processing_annotations, output_type = output_type),
      ngettext(n_processing_annotations, " annotation\n", " annotations\n")
    )
  }

  ## Variant annotations
  if (n_variant_annotations > 0) {
    out <- paste0(
      out,
      "      ",
      gray("Variants:", output_type = output_type),
      " ",
      bold(n_variant_annotations, output_type = output_type),
      ngettext(n_variant_annotations, " annotation\n", " annotations\n")
    )
  }

  out
}


# %% print.A3 ----
method(print, A3) <- function(x, output_type = NULL, ...) {
  cat(repr(x, output_type = output_type))
  invisible(x)
}


# %% Public API ------------------------------------------------------------------------------------
# The public API uses functions to create A3 objects from base R data structures.
# Minimum set of required functions:
# * `create_A3(sequence, annotations, metadata)`
#   * sequence is character(1); can be character(n) that will be concatenated using `concat()`
#   * site: named list created using `annotation_position()`
#   * region: named list created using `annotation_range()`
#   * ptm: named list created using `annotation_position()` OR `annotation_range()`
#   * processing: named list created using `annotation_position()` OR `annotation_range()`
#   * variant: named list created using `annotation_variant()`
#   * uniprot_id: `character(1)`
#   * description: `character(1)`
#   * reference: `character(1)`
#   * organism: `character(1)`

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


# %% annotation_position ----
#' Create position-based annotations for A3
#'
#' Creates an annotation spec (named list) with an `A3Position` index and optional type,
#' for use with `create_A3()`.
#'
#' @param x Integer vector: Positions of the annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type. `NULL` is treated as
#' the empty string in the canonical A3 representation.
#'
#' @return Named list with `index` (A3Position) and `type` (character)
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a site annotation for positions 5 and 17, of type "active site"
#' annotation_position(c(5L, 17L), type = "active site")
annotation_position <- function(x, type = NULL) {
  check_optional_scalar_character(type)
  if (is.null(type)) {
    type <- ""
  }
  list(
    index = A3Position(data = clean_int(x)),
    type = type
  )
}

# %% annotation_range ----
#' Create range-based annotations for A3
#'
#' Creates an annotation spec (named list) with an `A3Range` index and optional type,
#' for use with `create_A3()`.
#'
#' @param x Integer matrix with 2 columns corresponding to start and end positions of the
#' annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type. `NULL` is treated as
#' the empty string in the canonical A3 representation.
#'
#' @return Named list with `index` (A3Range) and `type` (character)
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a region annotation for ranges 3-10 and 15-22, of type "repeat"
#' annotation_range(rbind(c(3L, 10L), c(15L, 22L)), type = "repeat")
annotation_range <- function(x, type = NULL) {
  check_optional_scalar_character(type)
  if (is.null(type)) {
    type <- ""
  }
  list(
    index = A3Range(data = clean_int(x)),
    type = type
  )
}


# %% annotation_variant ----
#' Create variant annotations for A3
#'
#' Creates an `A3Variant` object for variant annotations with position and info.
#'
#' @param x Integer scalar: Position of the variant (1-based indexing).
#' @param info Named list: Additional information about the variant (e.g. reference and alternate
#' amino acids, variant type, etc.)
#'
#' @return A3Variant object
#'
#' @author EDG
#' @export
#'
#' @examples
#' # Create a variant annotation for position 10 with info about the variant
#' annotation_variant(10L, info = list(ref = "A", alt = "T", type = "missense"))
annotation_variant <- function(x, info = list()) {
  check_inherits(info, "list")
  A3Variant(
    position = clean_int(x),
    info = info
  )
}


# %% create_A3 ----
#' Create an A3 object from sequence, annotations, and metadata
#'
#' @param sequence Character scalar: Amino acid sequence string.
#' @param site Named list of site annotations
#' @param region Named list of region annotations
#' @param ptm Named list of PTM annotations
#' @param processing Named list of processing annotations
#' @param variant Named list of variant annotations
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
  check_optional_scalar_character(uniprot_id)
  check_optional_scalar_character(description)
  check_optional_scalar_character(reference)
  check_optional_scalar_character(organism)
  if (is.null(uniprot_id)) {
    uniprot_id <- ""
  }
  if (is.null(description)) {
    description <- ""
  }
  if (is.null(reference)) {
    reference <- ""
  }
  if (is.null(organism)) {
    organism <- ""
  }
  site <- lapply(site, function(a) {
    if (S7_inherits(a, A3Site)) {
      a
    } else {
      A3Site(index = a[["index"]], type = a[["type"]])
    }
  })
  region <- lapply(region, function(a) {
    if (S7_inherits(a, A3Region)) {
      a
    } else {
      A3Region(index = a[["index"]], type = a[["type"]])
    }
  })
  ptm <- lapply(ptm, function(a) {
    if (S7_inherits(a, A3PTM)) {
      a
    } else {
      A3PTM(index = a[["index"]], type = a[["type"]])
    }
  })
  processing <- lapply(processing, function(a) {
    if (S7_inherits(a, A3Processing)) {
      a
    } else {
      A3Processing(index = a[["index"]], type = a[["type"]])
    }
  })
  A3(
    sequence = A3Sequence(concat(sequence)),
    annotations = A3Annotation(
      site = site,
      region = region,
      ptm = ptm,
      processing = processing,
      variant = variant
    ),
    metadata = A3Metadata(
      uniprot_id = uniprot_id,
      description = description,
      reference = reference,
      organism = organism
    )
  )
}

# %% to_json.A3 ----
#' Convert an S7 object to a JSON string
#'
#' @param x S7 object
#' @param pretty Logical: if TRUE, pretty-print JSON output.
#' @param ... Additional arguments (currently unused)
#'
#' @return JSON string
#'
#' @author EDG
#' @keywords internal
#' @noRd
method(to_json, A3) <- function(x, pretty = TRUE, ...) {
  feature_to_list <- function(feature) {
    idx <- feature@index
    if (S7_inherits(idx, A3Range)) {
      mat <- idx@data
      index_data <- lapply(
        seq_len(nrow(mat)),
        function(i) as.integer(mat[i, ])
      )
    } else {
      index_data <- as.integer(idx@data)
    }
    list(
      index = index_data,
      type = jsonlite::unbox(feature@type)
    )
  }

  # A variant record is open, so its members round-trip verbatim — including
  # nested objects, arrays, and nulls. R has no scalar type, so every length-1
  # atomic has to be unboxed explicitly at every depth, or `{"pmid": 12345}`
  # would come back out as `{"pmid": [12345]}`.
  unbox_deep <- function(val) {
    if (is.null(val)) {
      return(NULL)
    }
    if (is.list(val)) {
      out <- lapply(val, unbox_deep)
      names(out) <- names(val)
      return(out)
    }
    if (is.atomic(val) && length(val) == 1L) jsonlite::unbox(val) else val
  }

  variant_to_list <- function(v) {
    out <- list(position = jsonlite::unbox(as.integer(v@position)))
    # Single-bracket assignment, not double: `out[[nm]] <- NULL` would delete
    # the element rather than emit a JSON null, dropping it from the round-trip.
    for (nm in names(v@info)) {
      out[nm] <- list(unbox_deep(v@info[[nm]]))
    }
    out
  }

  force_named <- function(x) {
    if (length(x) == 0) structure(list(), names = character(0)) else x
  }

  lst <- list(
    `$schema` = jsonlite::unbox(.A3_SCHEMA_URI),
    a3_version = jsonlite::unbox(.A3_VERSION),
    sequence = jsonlite::unbox(x@sequence@data),
    annotations = list(
      site = force_named(lapply(x@annotations@site, feature_to_list)),
      region = force_named(lapply(x@annotations@region, feature_to_list)),
      ptm = force_named(lapply(x@annotations@ptm, feature_to_list)),
      processing = force_named(lapply(
        x@annotations@processing,
        feature_to_list
      )),
      variant = lapply(x@annotations@variant, variant_to_list)
    ),
    metadata = list(
      uniprot_id = jsonlite::unbox(x@metadata@uniprot_id),
      description = jsonlite::unbox(x@metadata@description),
      reference = jsonlite::unbox(x@metadata@reference),
      organism = jsonlite::unbox(x@metadata@organism)
    )
  )
  jsonlite::toJSON(lst, pretty = pretty, null = "null")
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
#' frame. An empty data frame means the document is valid. Use this when you
#' want to present issues in a form or a report; use [read_A3json()] when you
#' want the object and an error if it cannot be built.
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
