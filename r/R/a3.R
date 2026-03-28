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
  }
)


# %% A3Index ----
# Superclass for A3Position and A3Range, encoding the location of `A3Feature` objects.
A3Index <- new_class(
  "A3Index",
  properties = list(
    data = class_integer
  ),
  constructor = function(data) {
    new_object(
      S7_object,
      data = data
    )
  }
)


# %% A3Position ----
# A3Index subclass for individual residue annotations
# Used by `A3Site`, `A3PTM`, and `A3Processing`.
A3Position <- new_class(
  "A3Position",
  parent = A3Index,
  constructor = function(data) {
    new_object(
      A3Index,
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
      A3Index,
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
  }
)


# %% A3Feature ----
# A3Feature class to represent a protein feature with an optional type and index
A3Feature <- new_class(
  "A3Feature",
  properties = list(
    type = class_character
  )
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
      A3Feature,
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
      A3Feature,
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
      A3Feature,
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
      A3Feature,
      index = index,
      type = type
    )
  }
)


# %% A3Variant ----
A3Variant <- new_class(
  "A3Variant",
  properties = list(
    position = A3Position,
    info = class_list
  ),
  validator = function(self) {
    if (length(self@position@data) != 1) {
      cli::cli_abort("Variant position must be a single integer.")
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
    if (!all(sapply(self@site, S7_inherits, A3Site))) {
      cli::cli_abort("All site annotations must be A3Site objects.")
    }
    if (!all(sapply(self@region, S7_inherits, A3Region))) {
      cli::cli_abort("All region annotations must be A3Region objects.")
    }
    if (!all(sapply(self@ptm, S7_inherits, A3PTM))) {
      cli::cli_abort("All PTM annotations must be A3PTM objects.")
    }
    if (!all(sapply(self@processing, S7_inherits, A3Processing))) {
      cli::cli_abort("All processing annotations must be A3Processing objects.")
    }
    if (!all(sapply(self@variant, S7_inherits, A3Variant))) {
      cli::cli_abort("All variant annotations must be A3Variant objects.")
    }
  }
)


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
      Metadata,
      uniprot_id = uniprot_id,
      description = description,
      reference = reference,
      organism = organism
    )
  }
)


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
      if (variant@position@data > seq_length) {
        cli::cli_abort(
          "Variant annotation position must be within the sequence length."
        )
      }
    }
  }
)


# %% as.list.A3 ----
method(as.list, A3) <- function(x, ...) {
  list(
    sequence = x@sequence@data,
    annotations = list(
      site = lapply(x@annotations@site, function(site) {
        list(
          type = site@type,
          index = site@index@data
        )
      }),
      region = lapply(x@annotations@region, function(region) {
        list(
          type = region@type,
          index = region@index@data
        )
      }),
      ptm = lapply(x@annotations@ptm, function(ptm) {
        list(
          type = ptm@type,
          index = ptm@index@data
        )
      }),
      processing = lapply(x@annotations@processing, function(proc) {
        list(
          type = proc@type,
          index = proc@index@data
        )
      }),
      variant = lapply(x@annotations@variant, function(variant) {
        list(
          position = variant@position@data,
          info = variant@info
        )
      })
    ),
    metadata = list(
      uniprot_id = x@metadata@uniprot_id,
      description = x@metadata@description,
      reference = x@metadata@reference,
      organism = x@metadata@organism
    )
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
  out <- paste0(
    out,
    "     Sequence: ",
    bold(
      paste0(utils::head(x@sequence@data, head_n), collapse = ""),
      output_type = output_type
    ),
    "...",
    " (length = ",
    nchar(x@sequence@data),
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
# - create_A3(sequence, annotations, metadata)
#   - sequence is character(1); can be character(n) that will be concatenated using `concat()`
#   - site: named list created using `annotation_position()`
#   - region: named list created using `annotation_range()`
#   - ptm: named list created using `annotation_position()` OR `annotation_range()`
#   - processing: named list created using `annotation_position()` OR `annotation_range()`
#   - variant: named list created using `annotation_variant()`
#   - uniprot_id: character(1)
#   - description: character(1)
#   - reference: character(1)
#   - organism: character(1)

# %% concat ----
#' Concatenate character vector to single string for sequence input
#'
#' @param x Character vector to concatenate
#'
#' @return Single character string
#'
#' @author EDG
#' @export
concat <- function(x) {
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
#' @param type Optional character scalar: Annotation type
#'
#' @return Named list with `index` (A3Position) and `type` (character)
#'
#' @author EDG
#' @export
annotation_position <- function(x, type = "") {
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
#' @param type Optional character scalar: Annotation type
#'
#' @return Named list with `index` (A3Range) and `type` (character)
#'
#' @author EDG
#' @export
annotation_range <- function(x, type = "") {
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
annotation_variant <- function(x, info = list()) {
  A3Variant(
    position = A3Position(clean_int(x)),
    info = info
  )
}


# %% create_A3 ----
#' Create an A3 object from sequence, annotations, and metadata
#'
#' @param sequence Character: Amino acid sequence string.
#' @param site Named list of site annotations
#' @param region Named list of region annotations
#' @param ptm Named list of PTM annotations
#' @param processing Named list of processing annotations
#' @param variant Named list of variant annotations
#' @param uniprot_id Character: UniProt ID for metadata
#' @param description Character: Protein description for metadata
#' @param reference Character: Reference for metadata
#' @param organism Character: Organism name for metadata
#'
#' @return A3 object
#'
#' @author EDG
#'
#' @export
create_A3 <- function(
  sequence,
  site = list(),
  region = list(),
  ptm = list(),
  processing = list(),
  variant = list(),
  uniprot_id = "",
  description = "",
  reference = "",
  organism = ""
) {
  site <- lapply(site, function(a) A3Site(index = a$index, type = a$type))
  region <- lapply(region, function(a) A3Region(index = a$index, type = a$type))
  ptm <- lapply(ptm, function(a) A3PTM(index = a$index, type = a$type))
  processing <- lapply(processing, function(a) {
    A3Processing(index = a$index, type = a$type)
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
  check_dependencies("jsonlite")

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

  variant_to_list <- function(v) {
    out <- list(position = jsonlite::unbox(as.integer(v@position@data)))
    for (nm in names(v@info)) {
      val <- v@info[[nm]]
      out[[nm]] <- if (length(val) == 1) jsonlite::unbox(val) else val
    }
    out
  }

  force_named <- function(x) {
    if (length(x) == 0) structure(list(), names = character(0)) else x
  }

  lst <- list(
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
  jsonlite::toJSON(lst, pretty = pretty)
}


# %% A3from_json ----
#' Create an A3 object from a JSON string or parsed list
#'
#' Accepts canonical A3 JSON (with `index`/`type` fields per annotation) and
#' legacy bare-array format (positions as flat arrays, ranges as arrays of arrays).
#'
#' @param x Character scalar (JSON string) or named list (pre-parsed JSON).
#' @param ... Additional arguments (currently unused)
#'
#' @return A3 object
#'
#' @author EDG
#' @keywords internal
#' @noRd
A3from_json <- function(x, ...) {
  check_dependencies("jsonlite")
  if (is.character(x)) {
    x <- jsonlite::fromJSON(
      x,
      simplifyVector = TRUE,
      simplifyDataFrame = FALSE,
      simplifyMatrix = FALSE
    )
  }

  # Sequence: accept character(1) or character(n) (legacy per-residue arrays)
  sequence <- if (length(x$sequence) > 1) concat(x$sequence) else x$sequence

  annotations <- x$annotations

  # Parse a single annotation entry into a feature object
  parse_feature <- function(entry, feature_class) {
    # Canonical form: list with $index and $type
    if (is.list(entry) && !is.null(entry$index)) {
      idx_data <- entry$index
      type <- if (is.null(entry$type)) "" else entry$type
    } else {
      # Legacy bare array
      idx_data <- entry
      type <- ""
    }

    # Detect position vs range from structure
    if (is.list(idx_data)) {
      # List of vectors: range pairs (or legacy expanded positions)
      if (any(vapply(idx_data, length, integer(1)) != 2L)) {
        # Legacy expanded positions: convert each group to [min, max]
        mat <- do.call(
          rbind,
          lapply(idx_data, function(v) {
            v <- as.integer(v)
            c(min(v), max(v))
          })
        )
      } else {
        mat <- do.call(rbind, lapply(idx_data, as.integer))
      }
      index <- A3Range(data = mat)
    } else {
      index <- A3Position(data = as.integer(idx_data))
    }

    feature_class(index = index, type = type)
  }

  site <- if (!is.null(annotations$site)) {
    lapply(annotations$site, parse_feature, feature_class = A3Site)
  } else {
    list()
  }

  region <- if (!is.null(annotations$region)) {
    lapply(annotations$region, parse_feature, feature_class = A3Region)
  } else {
    list()
  }

  ptm <- if (!is.null(annotations$ptm)) {
    lapply(annotations$ptm, parse_feature, feature_class = A3PTM)
  } else {
    list()
  }

  processing <- if (!is.null(annotations$processing)) {
    lapply(annotations$processing, parse_feature, feature_class = A3Processing)
  } else {
    list()
  }

  # Parse variants
  variants_data <- annotations$variant
  variant <- if (is.null(variants_data) || length(variants_data) == 0) {
    list()
  } else if (is.data.frame(variants_data)) {
    lapply(seq_len(nrow(variants_data)), function(i) {
      row <- as.list(variants_data[i, ])
      pos <- as.integer(row$position)
      info <- row[setdiff(names(row), "position")]
      A3Variant(position = A3Position(data = pos), info = info)
    })
  } else {
    lapply(variants_data, function(v) {
      v <- as.list(v)
      pos <- as.integer(v$position)
      info <- v[setdiff(names(v), "position")]
      A3Variant(position = A3Position(data = pos), info = info)
    })
  }

  # Parse metadata (all fields default to "")
  meta <- x$metadata
  null_to_empty <- function(val) if (is.null(val)) "" else val

  A3(
    sequence = A3Sequence(data = sequence),
    annotations = A3Annotation(
      site = site,
      region = region,
      ptm = ptm,
      processing = processing,
      variant = variant
    ),
    metadata = A3Metadata(
      uniprot_id = null_to_empty(meta$uniprot_id),
      description = null_to_empty(meta$description),
      reference = null_to_empty(meta$reference),
      organism = null_to_empty(meta$organism)
    )
  )
}
