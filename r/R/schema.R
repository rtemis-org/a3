# %% a3_schema ----
#' A3 JSON Schema
#'
#' Returns the JSON Schema (draft 2020-12) of an A3 document, generated from
#' the `A3` S7 class and the classes it contains: their property declarations,
#' their descriptions, and the registry publication of `A3`.
#' `schema/a3.schema.json` in the A3 repository is this schema, written by
#' `rtemis.core::write_JSONSchema()`.
#'
#' The schema expresses every rule that relates a value to its own type,
#' bounds, and pattern. Range order, range overlap, bounds against the sequence
#' length, and the variant residue rule relate two values; [read_A3json()] and
#' [validate_A3json()] check them.
#'
#' @return Named list: the JSON Schema document.
#'
#' @author EDG
#' @export
#'
#' @examples
#' s <- a3_schema()
#' s[["$id"]]
a3_schema <- function() {
  class_to_JSONSchema(
    A3,
    id = .A3_SCHEMA_URI,
    envelope = list(
      `$schema` = prop_string(
        const = .A3_SCHEMA_URI,
        description = "Identifier of the A3 JSON Schema."
      ),
      a3_version = prop_string(
        const = .A3_VERSION,
        description = "A3 format version."
      )
    ),
    required = c("$schema", "a3_version")
  )
}
