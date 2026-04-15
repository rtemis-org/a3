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
    check_names <- function(lst, category) {
      nms <- names(lst)
      if (length(lst) > 0 && (is.null(nms) || any(!nzchar(nms)))) {
        cli::cli_abort(
          "All {category} annotation names must be non-empty strings."
        )
      }
    }
    if (!all(sapply(self@site, S7_inherits, A3Site))) {
      cli::cli_abort("All site annotations must be A3Site objects.")
    }
    check_names(self@site, "site")
    if (!all(sapply(self@region, S7_inherits, A3Region))) {
      cli::cli_abort("All region annotations must be A3Region objects.")
    }
    check_names(self@region, "region")
    if (!all(sapply(self@ptm, S7_inherits, A3PTM))) {
      cli::cli_abort("All PTM annotations must be A3PTM objects.")
    }
    check_names(self@ptm, "ptm")
    if (!all(sapply(self@processing, S7_inherits, A3Processing))) {
      cli::cli_abort("All processing annotations must be A3Processing objects.")
    }
    check_names(self@processing, "processing")
    if (!all(sapply(self@variant, S7_inherits, A3Variant))) {
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
      out <- list(position = v@position@data)
      for (nm in names(v@info)) {
        out[[nm]] <- v@info[[nm]]
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
      Metadata,
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
      if (variant@position@data > seq_length) {
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
#'
#' @examples
#' # Create a site annotation for positions 5 and 17, of type "active site"
#' annotation_position(c(5L, 17L), type = "active site")
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
#'
#' @examples
#' # Create a region annotation for ranges 3-10 and 15-22, of type "repeat"
#' annotation_range(matrix(c(3L, 10L, 15L, 22L), ncol = 2, byrow = TRUE), type = "repeat")
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
#'
#' @examples
#' # Create a variant annotation for position 10 with info about the variant
#' annotation_variant(10L, info = list(ref = "A", alt = "T", type = "missense"))
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
#'     Domain = annotation_range(matrix(c(3L, 10L, 15L, 22L), ncol = 2, byrow = TRUE),
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
  uniprot_id = "",
  description = "",
  reference = "",
  organism = ""
) {
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

  # Validate required envelope fields
  schema_field <- x[["$schema"]]
  if (is.null(schema_field)) {
    cli::cli_abort("JSON input missing required field {.field $schema}.")
  }
  if (schema_field != .A3_SCHEMA_URI) {
    cli::cli_abort(
      "Field {.field $schema} must be {.val {.A3_SCHEMA_URI}}, got {.val {schema_field}}."
    )
  }
  version_field <- x[["a3_version"]]
  if (is.null(version_field)) {
    cli::cli_abort("JSON input missing required field {.field a3_version}.")
  }
  if (version_field != .A3_VERSION) {
    cli::cli_abort(
      "Field {.field a3_version} must be {.val {.A3_VERSION}}, got {.val {version_field}}."
    )
  }
  if (is.null(x[["sequence"]])) {
    cli::cli_abort("JSON input missing required field {.field sequence}.")
  }
  if (is.null(x[["annotations"]])) {
    cli::cli_abort("JSON input missing required field {.field annotations}.")
  }
  if (is.null(x[["metadata"]])) {
    cli::cli_abort("JSON input missing required field {.field metadata}.")
  }

  sequence <- x[["sequence"]]
  annotations <- x[["annotations"]]

  parse_position_index <- function(idx_data, path) {
    idx <- as.integer(idx_data)
    dup <- unique(idx[duplicated(idx)])
    if (length(dup) > 0L) {
      cli::cli_abort(
        "Field {.field {path}} has duplicate positions: {.val {dup}}. Remove duplicates."
      )
    }

    tryCatch(
      A3Position(data = idx),
      error = function(err) {
        cli::cli_abort(
          "Invalid position index in {.field {path}}: {conditionMessage(err)}"
        )
      }
    )
  }

  parse_range_index <- function(idx_data, path) {
    mat <- do.call(rbind, lapply(idx_data, as.integer))

    tryCatch(
      A3Range(data = mat),
      error = function(err) {
        cli::cli_abort(
          "Invalid range index in {.field {path}}: {conditionMessage(err)}"
        )
      }
    )
  }

  # Parse a single annotation entry (canonical {index, type} form only)
  parse_feature <- function(
    entry,
    feature_class,
    annotation_group,
    annotation_name
  ) {
    if (!is.list(entry) || is.null(entry[["index"]])) {
      cli::cli_abort(
        "Each annotation entry must be an object with 'index' and 'type' fields."
      )
    }
    idx_data <- entry[["index"]]
    type <- if (is.null(entry[["type"]])) "" else entry[["type"]]
    index_path <- paste0(
      "annotations.",
      annotation_group,
      ".",
      annotation_name,
      ".index"
    )

    # List of 2-element vectors → range pairs; plain vector → positions
    if (is.list(idx_data)) {
      index <- parse_range_index(idx_data, index_path)
    } else {
      index <- parse_position_index(idx_data, index_path)
    }

    feature_class(index = index, type = type)
  }

  site <- if (!is.null(annotations[["site"]])) {
    Map(
      parse_feature,
      entry = annotations[["site"]],
      annotation_name = names(annotations[["site"]]),
      MoreArgs = list(
        feature_class = A3Site,
        annotation_group = "site"
      )
    )
  } else {
    list()
  }

  region <- if (!is.null(annotations[["region"]])) {
    Map(
      parse_feature,
      entry = annotations[["region"]],
      annotation_name = names(annotations[["region"]]),
      MoreArgs = list(
        feature_class = A3Region,
        annotation_group = "region"
      )
    )
  } else {
    list()
  }

  ptm <- if (!is.null(annotations[["ptm"]])) {
    Map(
      parse_feature,
      entry = annotations[["ptm"]],
      annotation_name = names(annotations[["ptm"]]),
      MoreArgs = list(
        feature_class = A3PTM,
        annotation_group = "ptm"
      )
    )
  } else {
    list()
  }

  processing <- if (!is.null(annotations[["processing"]])) {
    Map(
      parse_feature,
      entry = annotations[["processing"]],
      annotation_name = names(annotations[["processing"]]),
      MoreArgs = list(
        feature_class = A3Processing,
        annotation_group = "processing"
      )
    )
  } else {
    list()
  }

  # Parse variants
  variants_data <- annotations[["variant"]]
  variant <- if (is.null(variants_data) || length(variants_data) == 0) {
    list()
  } else if (is.data.frame(variants_data)) {
    lapply(seq_len(nrow(variants_data)), function(i) {
      row <- as.list(variants_data[i, ])
      pos <- as.integer(row[["position"]])
      info <- row[setdiff(names(row), "position")]
      A3Variant(position = A3Position(data = pos), info = info)
    })
  } else {
    lapply(variants_data, function(v) {
      v <- as.list(v)
      pos <- as.integer(v[["position"]])
      info <- v[setdiff(names(v), "position")]
      A3Variant(position = A3Position(data = pos), info = info)
    })
  }

  # Parse metadata (all fields default to "")
  meta <- x[["metadata"]]
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
      uniprot_id = null_to_empty(meta[["uniprot_id"]]),
      description = null_to_empty(meta[["description"]]),
      reference = null_to_empty(meta[["reference"]]),
      organism = null_to_empty(meta[["organism"]])
    )
  )
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
#' \dontrun{
#' mapt <- uniprot_to_A3("P10636")
#' write_A3json(mapt, "P10636_A3.json")
#' }
write_A3json <- function(x, filepath, overwrite = FALSE) {
  check_is_S7(x, A3)
  check_inherits(filepath, "character")
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
#' @param filepath Character: Path to JSON file.
#' @param verbosity Integer: if greater than 0, print messages.
#'
#' @return `A3` object.
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#' mapt <- uniprot_to_A3("P10636")
#' write_A3json(mapt, "P10636_A3.json")
#' mapt2 <- read_A3json("P10636_A3.json")
#' }
read_A3json <- function(filepath, verbosity = 1L) {
  check_inherits(filepath, "character")
  filepath <- normalizePath(filepath)
  if (!file.exists(filepath)) {
    cli::cli_abort("File {.file {filepath}} does not exist.")
  }
  json_str <- paste(readLines(filepath, warn = FALSE), collapse = "\n")
  obj <- A3from_json(json_str)
  if (verbosity > 0L) {
    msg(
      "Read ",
      basename(filepath),
      ": ",
      green("\u2714 "),
      "valid A3 ",
      .A3_VERSION,
      sep = ""
    )
  }
  obj
}
