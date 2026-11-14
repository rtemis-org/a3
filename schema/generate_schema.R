# Writes schema/a3.schema.json from the property declarations of the rtemis.a3
# S7 classes, through rtemis.a3::a3_schema() and rtemis.core::write_JSONSchema().
#
# Usage, from the repository root:
#
#     Rscript schema/generate_schema.R

pkgload::load_all("r", quiet = TRUE, helpers = FALSE, attach_testthat = FALSE)
rtemis.core::write_JSONSchema(
  a3_schema(),
  "schema/a3.schema.json",
  overwrite = TRUE,
  verbosity = 0L
)
