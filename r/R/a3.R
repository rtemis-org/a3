# A3 S7 implementation
#  A3
#  ├── sequence:    A3Sequence
#  ├── annotations: A3Annotation
#  └── metadata:    A3Metadata

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
    data = class_integer,
    type = class_character
  ),
  constructor = function(data, type = "") {
    new_object(
      S7_object,
      data = data,
      type = type
    )
  }
)


# %% A3Position ----
# A3Index subclass for individual residue annotations
# Used by `A3Site`, `A3PTM`, and `A3Processing`.
A3Position <- new_class(
  "A3Position",
  parent = A3Index,
  constructor = function(data, type = "") {
    new_object(
      A3Index,
      data = sort(data), # Force unique and sorted data values
      type = type
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
  constructor = function(data, type = "") {
    # Sort by start position
    idx <- order(data[, 1])
    new_object(
      A3Index,
      data = data[idx, , drop = FALSE],
      type = type
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
  )
)


# %% A3Region ----
A3Region <- new_class(
  "A3Region",
  parent = A3Feature,
  properties = list(
    index = A3Range
  )
)


# %% A3PTM ----
A3PTM <- new_class(
  "A3PTM",
  parent = A3Feature,
  properties = list(
    index = A3Index
  )
)


# %% A3Processing ----
A3Processing <- new_class(
  "A3Processing",
  parent = A3Feature,
  properties = list(
    index = A3Index
  )
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
      A3Metadata,
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

#' Create Site Annotation
#'
#' @param index `A3Position` or `A3Range` object indicating the position(s) of the site.

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
#' Creates an `A3Position` object for site, PTM, or processing annotations with
#' optional types.
#'
#' @param x Integer vector: Positions of the annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type
#'
#' @return A3Position object
#'
#' @author EDG
#' @export
annotation_position <- function(x, type = "") {
  A3Position(
    data = x,
    type = type
  )
}

# %% annotation_range ----
#' Create range-based annotations for A3
#'
#' Creates an `A3Range` object for region, PTM, or processing annotations with
#' optional types.
#'
#' @param x Integer matrix with 2 columns corresponding to start and end positions of the annotation (1-based indexing).
#' @param type Optional character scalar: Annotation type
#'
#' @return A3Range object
#'
#' @author EDG
#' @export
annotation_range <- function(x, type = "") {
  A3Range(
    data = x,
    type = type
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
