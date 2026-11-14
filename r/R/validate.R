# Four-stage A3 validation over the raw parsed JSON.
#
# Validation runs against the plain nested list `jsonlite::fromJSON()` produces
# with all simplification switched off, not against the S7 classes. That is what
# makes collect-all reporting possible: an S7 validator returns one string and
# `cli::cli_abort()` stops at the first problem, while validating the raw list
# lets every problem in a stage be recorded with a code and a path.
#
#   Within a stage, collect everything. Across stages, short-circuit.
#
#     JSON text
#        |
#        +- fromJSON ----------> parse error (single, fatal, not collectable)
#        v
#     nested list
#        +- STAGE 1  envelope     document is an object, declares itself A3 1.0.0
#        +- STAGE 2  structural   types, shapes, required members, charset, names
#        +- STAGE 3  intra-field  positions >=1/deduped, ranges ordered/disjoint
#        +- STAGE 4  contextual   bounds vs sequence length, variant `from` residue
#        v  (only if no stage produced an issue)
#     A3
#
# Short-circuiting is a correctness requirement, not an optimization. A document
# whose `sequence` fails Stage 2 has no known length, so Stage 4 would emit one
# spurious out-of-bounds issue per annotated position.
#
# The S7 validators are deliberately left alone: they are the backstop for
# programmatic construction via `create_A3()`, where an immediate corrective
# message is the right behavior and there is no document to collect across.
#
# The full contract lives in spec/error-codes.md and spec/error-paths.md.
# 2026- EDG rtemis.org

# %% Registry ----
# Every A3 validation issue code, mapped to the stage it belongs to. Codes are
# never renumbered and never reused. See spec/error-codes.md for the full
# registry, including each code's trigger condition and the path it reports.
.A3_ISSUE_STAGES <- c(
  # Stage 1 - Envelope
  A3E_DOC_NOT_OBJECT = 1L,
  A3E_ENVELOPE_SCHEMA_MISSING = 1L,
  A3E_ENVELOPE_SCHEMA_MISMATCH = 1L,
  A3E_ENVELOPE_VERSION_MISSING = 1L,
  A3E_ENVELOPE_VERSION_MISMATCH = 1L,
  # Stage 2 - Structural
  A3E_UNKNOWN_FIELD = 2L,
  A3E_SEQ_MISSING = 2L,
  A3E_SEQ_NOT_STRING = 2L,
  A3E_SEQ_TOO_SHORT = 2L,
  A3E_SEQ_CHARSET = 2L,
  A3E_ANNOTATIONS_NOT_OBJECT = 2L,
  A3E_METADATA_NOT_OBJECT = 2L,
  A3E_METADATA_FIELD_NOT_STRING = 2L,
  A3E_FAMILY_NOT_OBJECT = 2L,
  A3E_VARIANT_LIST_NOT_ARRAY = 2L,
  A3E_NAME_EMPTY = 2L,
  A3E_ENTRY_NOT_OBJECT = 2L,
  A3E_ENTRY_TYPE_NOT_STRING = 2L,
  A3E_INDEX_MISSING = 2L,
  A3E_INDEX_NOT_ARRAY = 2L,
  A3E_INDEX_ELEMENT_TYPE = 2L,
  A3E_INDEX_MIXED = 2L,
  A3E_RANGE_ARITY = 2L,
  A3E_RANGE_ENDPOINT_NOT_INTEGER = 2L,
  A3E_VARIANT_NOT_OBJECT = 2L,
  A3E_VARIANT_POSITION_MISSING = 2L,
  A3E_VARIANT_POSITION_NOT_INTEGER = 2L,
  # Stage 3 - Intra-field
  A3E_POS_NOT_POSITIVE = 3L,
  A3E_POS_DUPLICATE = 3L,
  A3E_RANGE_ENDPOINT_NOT_POSITIVE = 3L,
  A3E_RANGE_ORDER = 3L,
  A3E_RANGE_OVERLAP = 3L,
  A3E_VARIANT_POSITION_NOT_POSITIVE = 3L,
  # Stage 4 - Contextual
  A3E_POS_OUT_OF_BOUNDS = 4L,
  A3E_RANGE_OUT_OF_BOUNDS = 4L,
  A3E_VARIANT_OUT_OF_BOUNDS = 4L,
  A3E_VARIANT_RESIDUE_MISMATCH = 4L
)

.A3_TOP_LEVEL_KEYS <- c(
  "$schema",
  "a3_version",
  "sequence",
  "annotations",
  "metadata"
)
.A3_FAMILIES <- c("site", "region", "ptm", "processing", "variant")
.A3_NAMED_FAMILIES <- c("site", "region", "ptm", "processing")
.A3_ENTRY_KEYS <- c("index", "type")
.A3_METADATA_KEYS <- c("uniprot_id", "description", "reference", "organism")


# %% .a3_issue ----
#' Build one validation issue
#'
#' @param code Character scalar: Registered A3 issue code.
#' @param path Character scalar: RFC 6901 JSON Pointer to the offending value.
#' @param message Character scalar: Human-readable explanation. Not contractual.
#'
#' @return Named list with `code`, `path`, and `message`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_issue <- function(code, path, message) {
  # A mistyped code would silently produce an issue no consumer can match on,
  # so reject it here rather than at the far end of a conformance run.
  if (!code %in% names(.A3_ISSUE_STAGES)) {
    cli::cli_abort(
      "{.val {code}} is not a registered A3 issue code. See {.file spec/error-codes.md}."
    )
  }
  list(code = code, path = path, message = message)
}


# %% .a3_escape_token ----
#' Escape one reference token for a JSON Pointer
#'
#' RFC 6901 escapes exactly two characters. `~` must be replaced before `/`, or
#' a key containing `/` would come out as `~01` instead of `~1`.
#'
#' @param token Character: Raw object member name.
#'
#' @return Character: Escaped reference token.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_escape_token <- function(token) {
  gsub("/", "~1", gsub("~", "~0", token, fixed = TRUE), fixed = TRUE)
}


# %% .a3_pointer ----
#' Append a reference token or array subscript to a JSON Pointer
#'
#' @param base Character scalar: Pointer to extend. `""` denotes the document root.
#' @param token Character or integer: A raw member name, which is escaped here,
#' or a 0-based subscript, which is not. Do not pre-escape a name: passing
#' `a~1b` yields `a~01b`, because the `~` is escaped a second time.
#'
#' @return Character scalar: The extended pointer.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_pointer <- function(base, token) {
  if (is.numeric(token)) {
    paste0(base, "/", as.integer(token))
  } else {
    paste0(base, "/", .a3_escape_token(token))
  }
}


# %% validate_a3_raw ----
#' Validate a raw parsed A3 document
#'
#' Runs the four validation stages over the nested list produced by
#' `jsonlite::fromJSON(simplifyVector = FALSE)` and returns every issue found in
#' the earliest stage that produced one.
#'
#' @param x List: Raw parsed JSON, with no simplification applied.
#'
#' @return Named list with `a3` (an `A3` object, or `NULL` when any issue was
#' found) and `issues` (a list of `code`/`path`/`message` lists).
#'
#' @author EDG
#' @keywords internal
#' @noRd
validate_a3_raw <- function(x) {
  issues <- list()

  # -- Stage 1 --
  issues <- c(issues, .a3_stage1_envelope(x))
  if (length(issues) > 0L) {
    return(list(a3 = NULL, issues = issues))
  }

  # -- Stage 2 --
  stage2 <- .a3_stage2_structural(x)
  if (length(stage2[["issues"]]) > 0L) {
    return(list(a3 = NULL, issues = stage2[["issues"]]))
  }
  draft <- stage2[["draft"]]

  # -- Stage 3 --
  draft <- .a3_sort_draft(draft)
  issues <- .a3_stage3_intra_field(draft)
  if (length(issues) > 0L) {
    return(list(a3 = NULL, issues = issues))
  }

  # -- Stage 4 --
  issues <- .a3_stage4_contextual(draft)
  if (length(issues) > 0L) {
    return(list(a3 = NULL, issues = issues))
  }

  list(a3 = .a3_build(draft), issues = list())
}


# %% Stage 1 ----
#' Stage 1: envelope
#'
#' When the root is not an object, `A3E_DOC_NOT_OBJECT` is the only issue
#' reported: nothing below it can be located.
#'
#' @param x List: Raw parsed JSON.
#'
#' @return List of issues.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage1_envelope <- function(x) {
  if (!.a3_is_object(x)) {
    return(list(.a3_issue(
      "A3E_DOC_NOT_OBJECT",
      "",
      "An A3 document must be a JSON object."
    )))
  }
  c(
    .a3_check_const(
      x,
      "$schema",
      .A3_SCHEMA_URI,
      "A3E_ENVELOPE_SCHEMA_MISSING",
      "A3E_ENVELOPE_SCHEMA_MISMATCH"
    ),
    .a3_check_const(
      x,
      "a3_version",
      .A3_VERSION,
      "A3E_ENVELOPE_VERSION_MISSING",
      "A3E_ENVELOPE_VERSION_MISMATCH"
    )
  )
}


# %% .a3_check_const ----
#' Check one envelope member against its required constant value
#'
#' A wrong type and a wrong value are the same failure: the schema declares both
#' envelope members with `const`, and a `const` failure is one failure.
#'
#' @param x List: Raw document.
#' @param key Character scalar: Member name.
#' @param expected Character scalar: Required value.
#' @param missing_code Character scalar: Code to emit when the member is absent.
#' @param mismatch_code Character scalar: Code to emit when it has another value.
#'
#' @return List of issues.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_check_const <- function(x, key, expected, missing_code, mismatch_code) {
  path <- .a3_pointer("", key)
  if (!key %in% names(x)) {
    return(list(.a3_issue(
      missing_code,
      path,
      paste0("'", key, "' is required and must be '", expected, "'.")
    )))
  }
  value <- x[[key]]
  if (!(is.character(value) && length(value) == 1L && value == expected)) {
    return(list(.a3_issue(
      mismatch_code,
      path,
      paste0(
        "'",
        key,
        "' must be '",
        expected,
        "', got ",
        .a3_render(value),
        "."
      )
    )))
  }
  list()
}


# %% Stage 2 ----
#' Stage 2: structural
#'
#' Checks every value's type and shape, and extracts a draft document carrying
#' the JSON Pointer each value will be reported at.
#'
#' @param x List: Raw document, known to be an object.
#'
#' @return Named list with `draft` and `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_structural <- function(x) {
  issues <- .a3_unknown_fields(x, .A3_TOP_LEVEL_KEYS, "")

  seq_result <- .a3_stage2_sequence(x)
  issues <- c(issues, seq_result[["issues"]])

  draft <- list(
    sequence = if (is.null(seq_result[["sequence"]])) {
      ""
    } else {
      seq_result[["sequence"]]
    },
    site = list(),
    region = list(),
    ptm = list(),
    processing = list(),
    variant = list(),
    metadata = stats::setNames(
      as.list(rep("", length(.A3_METADATA_KEYS))),
      .A3_METADATA_KEYS
    )
  )

  # `annotations` and `metadata` are optional; both default to empty.
  annotations <- x[["annotations"]]
  if (!is.null(annotations)) {
    if (!.a3_is_object(annotations)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_ANNOTATIONS_NOT_OBJECT",
          "/annotations",
          "'annotations' must be an object."
        ))
      )
    } else {
      parsed <- .a3_stage2_annotations(annotations)
      issues <- c(issues, parsed[["issues"]])
      for (family in .A3_FAMILIES) {
        draft[[family]] <- parsed[[family]]
      }
    }
  }

  metadata <- x[["metadata"]]
  if (!is.null(metadata)) {
    if (!.a3_is_object(metadata)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_METADATA_NOT_OBJECT",
          "/metadata",
          "'metadata' must be an object."
        ))
      )
    } else {
      parsed <- .a3_stage2_metadata(metadata)
      issues <- c(issues, parsed[["issues"]])
      draft[["metadata"]] <- parsed[["metadata"]]
    }
  }

  list(draft = draft, issues = issues)
}


# %% .a3_stage2_sequence ----
#' Extract and case-fold the sequence, checking type, length, and charset
#'
#' @param x List: Raw document.
#'
#' @return Named list with `sequence` (or `NULL`) and `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_sequence <- function(x) {
  if (!"sequence" %in% names(x)) {
    return(list(
      sequence = NULL,
      issues = list(.a3_issue(
        "A3E_SEQ_MISSING",
        "/sequence",
        "'sequence' is required."
      ))
    ))
  }
  raw <- x[["sequence"]]
  if (!(is.character(raw) && length(raw) == 1L)) {
    return(list(
      sequence = NULL,
      issues = list(.a3_issue(
        "A3E_SEQ_NOT_STRING",
        "/sequence",
        paste0("'sequence' must be a string, got ", .a3_render(raw), ".")
      ))
    ))
  }

  upper <- toupper(raw)
  issues <- list()
  if (nchar(upper) < 2L) {
    issues <- c(
      issues,
      list(.a3_issue(
        "A3E_SEQ_TOO_SHORT",
        "/sequence",
        paste0(
          "'sequence' must be at least 2 characters, got ",
          nchar(upper),
          " (\"",
          raw,
          "\")."
        )
      ))
    )
  }
  chars <- strsplit(upper, "", fixed = TRUE)[[1L]]
  bad <- chars[!grepl("^[A-Z*]$", chars)]
  if (length(bad) > 0L) {
    issues <- c(
      issues,
      list(.a3_issue(
        "A3E_SEQ_CHARSET",
        "/sequence",
        paste0(
          "'sequence' contains '",
          bad[[1L]],
          "'; only A-Z (IUPAC amino acid codes) and '*' (stop codon) are permitted."
        )
      ))
    )
  }
  list(sequence = upper, issues = issues)
}


# %% .a3_stage2_annotations ----
#' Parse the five annotation families
#'
#' @param annotations List: The `annotations` object.
#'
#' @return Named list with one element per family plus `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_annotations <- function(annotations) {
  out <- list(
    site = list(),
    region = list(),
    ptm = list(),
    processing = list(),
    variant = list(),
    issues = .a3_unknown_fields(annotations, .A3_FAMILIES, "/annotations")
  )

  for (family in .A3_NAMED_FAMILIES) {
    entries <- annotations[[family]]
    if (is.null(entries)) {
      next
    }
    family_path <- .a3_pointer("/annotations", family)
    if (!.a3_is_object(entries)) {
      out[["issues"]] <- c(
        out[["issues"]],
        list(.a3_issue(
          "A3E_FAMILY_NOT_OBJECT",
          family_path,
          paste0("'annotations.", family, "' must be an object.")
        ))
      )
      next
    }
    parsed <- .a3_stage2_family(entries, family, family_path)
    out[[family]] <- parsed[["entries"]]
    out[["issues"]] <- c(out[["issues"]], parsed[["issues"]])
  }

  records <- annotations[["variant"]]
  if (!is.null(records)) {
    if (!.a3_is_array(records)) {
      out[["issues"]] <- c(
        out[["issues"]],
        list(.a3_issue(
          "A3E_VARIANT_LIST_NOT_ARRAY",
          "/annotations/variant",
          "'annotations.variant' must be an array."
        ))
      )
    } else {
      parsed <- .a3_stage2_variants(records)
      out[["variant"]] <- parsed[["variants"]]
      out[["issues"]] <- c(out[["issues"]], parsed[["issues"]])
    }
  }

  out
}


# %% .a3_stage2_family ----
#' Parse one named annotation family
#'
#' `family` selects the permitted index geometry: `site` takes positions,
#' `region` takes ranges, `ptm` and `processing` take either, homogeneously.
#'
#' @param entries List: The family object.
#' @param family Character scalar: Family name.
#' @param family_path Character scalar: JSON Pointer to the family.
#'
#' @return Named list with `entries` and `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_family <- function(entries, family, family_path) {
  out <- list()
  issues <- list()
  names_vec <- names(entries)
  if (is.null(names_vec)) {
    names_vec <- rep("", length(entries))
  }

  for (i in seq_along(entries)) {
    name <- names_vec[[i]]
    raw <- entries[[i]]
    entry_path <- .a3_pointer(family_path, name)

    if (!nzchar(name)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_NAME_EMPTY",
          entry_path,
          paste0(
            "'annotations.",
            family,
            "' has an annotation named \"\"; names must not be empty."
          )
        ))
      )
      next
    }

    if (!.a3_is_object(raw)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_ENTRY_NOT_OBJECT",
          entry_path,
          paste0(
            "Annotation '",
            name,
            "' must be an object with an 'index' member."
          )
        ))
      )
      next
    }

    issues <- c(issues, .a3_unknown_fields(raw, .A3_ENTRY_KEYS, entry_path))

    label <- raw[["type"]]
    type_str <- ""
    if (!is.null(label)) {
      if (is.character(label) && length(label) == 1L) {
        type_str <- label
      } else {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_ENTRY_TYPE_NOT_STRING",
            .a3_pointer(entry_path, "type"),
            paste0("'type' must be a string, got ", .a3_render(label), ".")
          ))
        )
      }
    }

    index_path <- .a3_pointer(entry_path, "index")
    if (!"index" %in% names(raw)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_INDEX_MISSING",
          index_path,
          paste0(
            "Annotation '",
            name,
            "' is missing its required 'index' member."
          )
        ))
      )
      next
    }
    elements <- raw[["index"]]
    if (!.a3_is_array(elements)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_INDEX_NOT_ARRAY",
          index_path,
          paste0("'index' must be an array, got ", .a3_render(elements), ".")
        ))
      )
      next
    }

    parsed <- .a3_parse_index(elements, family, index_path)
    issues <- c(issues, parsed[["issues"]])
    if (is.null(parsed[["geometry"]])) {
      next
    }

    out[[name]] <- list(
      index_path = index_path,
      geometry = parsed[["geometry"]],
      values = parsed[["values"]],
      type = type_str
    )
  }

  list(entries = out, issues = issues)
}


# %% .a3_parse_index ----
#' Settle an index's geometry and extract its values
#'
#' @param elements List: The index array.
#' @param family Character scalar: Family name.
#' @param index_path Character scalar: JSON Pointer to the index.
#'
#' @return Named list with `geometry` (`NULL` when undetermined), `values`, `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_parse_index <- function(elements, family, index_path) {
  flexible <- family %in% c("ptm", "processing")
  none <- function(issues) list(geometry = NULL, values = NULL, issues = issues)

  # Classify every element first. Doing this up front is what makes the
  # mixed-geometry rule expressible: it is a property of the whole index.
  kinds <- vapply(elements, .a3_classify, character(1L))
  issues <- list()

  bad <- which(kinds == "other")
  if (length(bad) > 0L) {
    for (i in bad) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_INDEX_ELEMENT_TYPE",
          .a3_pointer(index_path, i - 1L),
          paste0("Index element must be ", .a3_expected_shape(family), ".")
        ))
      )
    }
    return(none(issues))
  }

  n_int <- sum(kinds == "integer")
  n_arr <- sum(kinds == "array")

  if (flexible) {
    if (n_int > 0L && n_arr > 0L) {
      return(none(list(.a3_issue(
        "A3E_INDEX_MIXED",
        index_path,
        paste0(
          "Index mixes ",
          n_int,
          " position(s) and ",
          n_arr,
          " range(s); a ptm or processing index must be all positions or all ranges."
        )
      ))))
    }
    geometry <- if (n_arr > 0L) "ranges" else "positions"
  } else {
    geometry <- if (family == "region") "ranges" else "positions"
    # A well-formed element of the *other* geometry is still wrong for a family
    # whose geometry the schema fixes.
    want <- if (geometry == "ranges") "array" else "integer"
    wrong <- which(kinds != want)
    if (length(wrong) > 0L) {
      for (i in wrong) {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_INDEX_ELEMENT_TYPE",
            .a3_pointer(index_path, i - 1L),
            paste0("Index element must be ", .a3_expected_shape(family), ".")
          ))
        )
      }
      return(none(issues))
    }
  }

  if (geometry == "positions") {
    values <- if (length(elements) == 0L) {
      integer(0)
    } else {
      vapply(elements, .a3_as_integer, integer(1L))
    }
    return(list(geometry = "positions", values = values, issues = issues))
  }

  # Ranges: a 0-row, 2-column matrix is the empty case, and keeps every
  # downstream `nrow()` / `[, 1]` valid without a special branch.
  ranges <- matrix(integer(0), nrow = 0L, ncol = 2L)
  ok <- TRUE
  for (i in seq_along(elements)) {
    pair <- elements[[i]]
    elem_path <- .a3_pointer(index_path, i - 1L)
    if (length(pair) != 2L) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_RANGE_ARITY",
          elem_path,
          paste0(
            "A range must be a 2-element [start, end] array, got ",
            length(pair),
            " element(s)."
          )
        ))
      )
      ok <- FALSE
      next
    }
    start <- .a3_as_integer(pair[[1L]])
    end <- .a3_as_integer(pair[[2L]])
    if (is.na(start) || is.na(end)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_RANGE_ENDPOINT_NOT_INTEGER",
          elem_path,
          "Range endpoints must be integers."
        ))
      )
      ok <- FALSE
      next
    }
    ranges <- rbind(ranges, c(start, end))
  }
  if (!ok) {
    return(none(issues))
  }
  list(geometry = "ranges", values = ranges, issues = issues)
}


# %% .a3_stage2_variants ----
#' Parse the variant list
#'
#' Every member beyond `position` is open and preserved verbatim, in document
#' order, without type checking.
#'
#' @param records List: The variant array.
#'
#' @return Named list with `variants` and `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_variants <- function(records) {
  out <- list()
  issues <- list()

  for (i in seq_along(records)) {
    raw <- records[[i]]
    path <- .a3_pointer("/annotations/variant", i - 1L)

    if (!.a3_is_object(raw)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_NOT_OBJECT",
          path,
          "A variant record must be an object."
        ))
      )
      next
    }

    position_path <- .a3_pointer(path, "position")
    if (!"position" %in% names(raw)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_POSITION_MISSING",
          position_path,
          "A variant record is missing its required 'position' member."
        ))
      )
      next
    }
    position <- .a3_as_integer(raw[["position"]])
    if (is.na(position)) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_POSITION_NOT_INTEGER",
          position_path,
          paste0(
            "'position' must be an integer, got ",
            .a3_render(raw[["position"]]),
            "."
          )
        ))
      )
      next
    }

    # Single-bracket assignment, not double: `extra[[nm]] <- NULL` would delete
    # the element rather than store a JSON null, silently dropping it from the
    # round-trip.
    extra <- list()
    for (nm in setdiff(names(raw), "position")) {
      extra[nm] <- list(raw[[nm]])
    }

    out[[length(out) + 1L]] <- list(
      path = path,
      position = position,
      extra = extra
    )
  }

  list(variants = out, issues = issues)
}


# %% .a3_stage2_metadata ----
#' Extract the four metadata members, checking only that each is a string
#'
#' @param metadata List: The `metadata` object.
#'
#' @return Named list with `metadata` and `issues`.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage2_metadata <- function(metadata) {
  issues <- .a3_unknown_fields(metadata, .A3_METADATA_KEYS, "/metadata")
  out <- list()

  for (key in .A3_METADATA_KEYS) {
    value <- metadata[[key]]
    if (is.null(value)) {
      out[[key]] <- ""
    } else if (is.character(value) && length(value) == 1L) {
      out[[key]] <- value
    } else {
      out[[key]] <- ""
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_METADATA_FIELD_NOT_STRING",
          .a3_pointer("/metadata", key),
          paste0(
            "'metadata.",
            key,
            "' must be a string, got ",
            .a3_render(value),
            "."
          )
        ))
      )
    }
  }

  list(metadata = out, issues = issues)
}


# %% .a3_sort_draft ----
#' Sort every index in the draft
#'
#' Sorting happens between Stage 2 and Stage 3 because an index cannot be sorted
#' until its elements are known to be sortable, and it must be sorted before
#' duplication and overlap can be checked. Every subscript reported by Stage 3
#' and Stage 4 therefore names the sorted array.
#'
#' @param draft List: Draft document.
#'
#' @return The draft with every index sorted.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_sort_draft <- function(draft) {
  for (family in .A3_NAMED_FAMILIES) {
    for (name in names(draft[[family]])) {
      entry <- draft[[family]][[name]]
      if (entry[["geometry"]] == "positions") {
        entry[["values"]] <- sort(entry[["values"]])
      } else if (nrow(entry[["values"]]) > 1L) {
        mat <- entry[["values"]]
        entry[["values"]] <- mat[order(mat[, 1L], mat[, 2L]), , drop = FALSE]
      }
      draft[[family]][[name]] <- entry
    }
  }
  draft
}


# %% Stage 3 ----
#' Stage 3: intra-field
#'
#' @param draft List: Draft document, with every index sorted.
#'
#' @return List of issues.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage3_intra_field <- function(draft) {
  issues <- list()

  for (entry in .a3_draft_entries(draft)) {
    index_path <- entry[["index_path"]]
    if (entry[["geometry"]] == "positions") {
      positions <- entry[["values"]]
      for (i in which(positions < 1L)) {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_POS_NOT_POSITIVE",
            .a3_pointer(index_path, i - 1L),
            paste0(
              "Position ",
              positions[[i]],
              " must be >= 1; positions are 1-based."
            )
          ))
        )
      }
      # One issue per distinct repeated value, not per excess occurrence:
      # c(7, 7, 7) is one mistake, not two.
      for (value in unique(positions[duplicated(positions)])) {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_POS_DUPLICATE",
            index_path,
            paste0(
              "Position ",
              value,
              " appears more than once; duplicates are rejected, not merged."
            )
          ))
        )
      }
    } else {
      mat <- entry[["values"]]
      for (i in seq_len(nrow(mat))) {
        start <- mat[i, 1L]
        end <- mat[i, 2L]
        elem_path <- .a3_pointer(index_path, i - 1L)
        if (start < 1L || end < 1L) {
          issues <- c(
            issues,
            list(.a3_issue(
              "A3E_RANGE_ENDPOINT_NOT_POSITIVE",
              elem_path,
              paste0(
                "Range [",
                start,
                ", ",
                end,
                "] has an endpoint below 1; positions are 1-based."
              )
            ))
          )
        }
        if (start >= end) {
          issues <- c(
            issues,
            list(.a3_issue(
              "A3E_RANGE_ORDER",
              elem_path,
              paste0(
                "Range [",
                start,
                ", ",
                end,
                "] must satisfy start < end; a single residue belongs in a ",
                "position-indexed family."
              )
            ))
          )
        }
      }
      # Sorted by start, so two ranges overlap exactly when the second starts at
      # or before the first ends.
      for (i in seq_len(max(nrow(mat) - 1L, 0L))) {
        if (mat[i + 1L, 1L] <= mat[i, 2L]) {
          issues <- c(
            issues,
            list(.a3_issue(
              "A3E_RANGE_OVERLAP",
              index_path,
              paste0(
                "Ranges [",
                mat[i, 1L],
                ", ",
                mat[i, 2L],
                "] and [",
                mat[i + 1L, 1L],
                ", ",
                mat[i + 1L, 2L],
                "] overlap; adjacent ranges are permitted but overlapping ones are not."
              )
            ))
          )
        }
      }
    }
  }

  for (v in draft[["variant"]]) {
    if (v[["position"]] < 1L) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_POSITION_NOT_POSITIVE",
          .a3_pointer(v[["path"]], "position"),
          paste0(
            "Position ",
            v[["position"]],
            " must be >= 1; positions are 1-based."
          )
        ))
      )
    }
  }

  issues
}


# %% Stage 4 ----
#' Stage 4: contextual
#'
#' Every rule here compares a value against the sequence, whose length is known
#' only because Stages 1-3 all passed.
#'
#' @param draft List: Draft document.
#'
#' @return List of issues.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_stage4_contextual <- function(draft) {
  issues <- list()
  residues <- strsplit(draft[["sequence"]], "", fixed = TRUE)[[1L]]
  n <- length(residues)

  for (entry in .a3_draft_entries(draft)) {
    index_path <- entry[["index_path"]]
    if (entry[["geometry"]] == "positions") {
      positions <- entry[["values"]]
      for (i in which(positions > n)) {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_POS_OUT_OF_BOUNDS",
            .a3_pointer(index_path, i - 1L),
            paste0(
              "Position ",
              positions[[i]],
              " is out of bounds for a sequence of length ",
              n,
              " (must be 1-",
              n,
              ")."
            )
          ))
        )
      }
    } else {
      mat <- entry[["values"]]
      # Stage 3 established start < end, so only `end` can exceed `n`.
      for (i in which(mat[, 2L] > n)) {
        issues <- c(
          issues,
          list(.a3_issue(
            "A3E_RANGE_OUT_OF_BOUNDS",
            .a3_pointer(index_path, i - 1L),
            paste0(
              "Range [",
              mat[i, 1L],
              ", ",
              mat[i, 2L],
              "] is out of bounds for a sequence of length ",
              n,
              " (must be within 1-",
              n,
              ")."
            )
          ))
        )
      }
    }
  }

  for (v in draft[["variant"]]) {
    position <- v[["position"]]
    if (position > n) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_OUT_OF_BOUNDS",
          .a3_pointer(v[["path"]], "position"),
          paste0(
            "Position ",
            position,
            " is out of bounds for a sequence of length ",
            n,
            " (must be 1-",
            n,
            ")."
          )
        ))
      )
      next
    }
    # The residue rule is deliberately narrow: it fires only when `from` is
    # present *and* is a single character. `from` is an optional member of an
    # open record, so any other shape is not this rule's problem.
    from <- v[["extra"]][["from"]]
    if (!(is.character(from) && length(from) == 1L && nchar(from) == 1L)) {
      next
    }
    actual <- residues[[position]]
    # Case-insensitive because `sequence` is case-folded during normalization
    # and `from` is not.
    if (toupper(from) != actual) {
      issues <- c(
        issues,
        list(.a3_issue(
          "A3E_VARIANT_RESIDUE_MISMATCH",
          .a3_pointer(v[["path"]], "from"),
          paste0(
            "'from' is '",
            from,
            "' but residue ",
            position,
            " of the sequence is '",
            actual,
            "'; the variant list may be annotated against a different isoform."
          )
        ))
      )
    }
  }

  issues
}


# %% .a3_build ----
#' Build the validated A3 object from a draft
#'
#' Every invariant this relies on was established by the four stages, so the S7
#' validators it passes through cannot fire.
#'
#' @param draft List: Draft document.
#'
#' @return `A3` object.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_build <- function(draft) {
  index_value <- function(entry) {
    values <- entry[["values"]]
    if (entry[["geometry"]] == "positions") {
      as.integer(values)
    } else {
      matrix(as.integer(values), ncol = 2L)
    }
  }
  make_family <- function(family, cls) {
    lapply(draft[[family]], function(entry) {
      cls(index = index_value(entry), type = entry[["type"]])
    })
  }

  A3(
    sequence = draft[["sequence"]],
    annotations = A3Annotations(
      site = make_family("site", A3Site),
      region = make_family("region", A3Region),
      ptm = make_family("ptm", A3PTM),
      processing = make_family("processing", A3Processing),
      variant = lapply(draft[["variant"]], function(v) {
        c(list(position = v[["position"]]), v[["extra"]])
      })
    ),
    metadata = A3Metadata(
      uniprot_id = draft[["metadata"]][["uniprot_id"]],
      description = draft[["metadata"]][["description"]],
      reference = draft[["metadata"]][["reference"]],
      organism = draft[["metadata"]][["organism"]]
    )
  )
}


# %% Helpers ----

#' Every named entry across the four named families, in family order
#'
#' @param draft List: Draft document.
#'
#' @return List of draft entries.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_draft_entries <- function(draft) {
  c(
    draft[["site"]],
    draft[["region"]],
    draft[["ptm"]],
    draft[["processing"]]
  )
}


#' Is this parsed value a JSON object?
#'
#' With `simplifyVector = FALSE`, `fromJSON()` returns every object as a named
#' list and every array as an unnamed list. An empty object and an empty array
#' are both `list()`, so they are distinguished by their `names` attribute:
#' `{}` keeps `character(0)` names, `[]` has none.
#'
#' @param x Parsed value.
#'
#' @return Logical scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_is_object <- function(x) {
  is.list(x) && !is.null(names(x))
}


#' Is this parsed value a JSON array?
#'
#' @param x Parsed value.
#'
#' @return Logical scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_is_array <- function(x) {
  is.list(x) && is.null(names(x))
}


#' Classify an index element as "integer", "array", or "other"
#'
#' @param value Parsed value.
#'
#' @return Character scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_classify <- function(value) {
  if (.a3_is_array(value)) {
    return("array")
  }
  if (is.na(.a3_as_integer(value))) "other" else "integer"
}


#' Interpret a parsed JSON value as an integer
#'
#' JSON has no integer type distinct from number, and JSON Schema's
#' `type: "integer"` accepts any number with a zero fractional part, so `3.0` is
#' the position 3 while `2.5` is not a position at all. A JSON boolean is not a
#' number, so `TRUE` is never a position.
#'
#' @param value Parsed value.
#'
#' @return Integer scalar, or `NA_integer_` when the value is not an integer.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_as_integer <- function(value) {
  if (is.logical(value) || !is.numeric(value) || length(value) != 1L) {
    return(NA_integer_)
  }
  if (is.na(value) || value %% 1 != 0) {
    return(NA_integer_)
  }
  as.integer(value)
}


#' The element shape a family requires
#'
#' @param family Character scalar: Family name.
#'
#' @return Character scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_expected_shape <- function(family) {
  switch(
    family,
    site = "an integer position",
    region = "a [start, end] range",
    "an integer position or a [start, end] range"
  )
}


#' Report one A3E_UNKNOWN_FIELD per property outside `allowed`
#'
#' @param x List: Object to check.
#' @param allowed Character: Permitted member names.
#' @param base Character scalar: JSON Pointer to the object.
#'
#' @return List of issues.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_unknown_fields <- function(x, allowed, base) {
  unknown <- setdiff(names(x), allowed)
  lapply(unknown, function(key) {
    .a3_issue(
      "A3E_UNKNOWN_FIELD",
      .a3_pointer(base, key),
      paste0(
        "'",
        key,
        "' is not a permitted member here; expected one of: ",
        paste(allowed, collapse = ", "),
        "."
      )
    )
  })
}


#' Render a parsed value compactly for a human message
#'
#' @param value Parsed value.
#'
#' @return Character scalar.
#'
#' @author EDG
#' @keywords internal
#' @noRd
.a3_render <- function(value) {
  text <- if (is.null(value)) {
    "null"
  } else if (is.character(value) && length(value) == 1L) {
    paste0("\"", value, "\"")
  } else if (is.list(value)) {
    if (.a3_is_object(value)) "an object" else "an array"
  } else {
    paste(format(value), collapse = ", ")
  }
  if (nchar(text) > 40L) paste0(substr(text, 1L, 39L), "\u2026") else text
}
