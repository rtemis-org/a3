#' Get the sequence of a gene
#'
#' @param gene Character: Gene name.
#' @param organism Character: Organism name.
#' @param biomart Character: Biomart name.
#' @param host Character: Host address.
#' @param seq_type Character: Sequence type to retrieve. See [biomaRt::getSequence].
#' @param verbosity Integer: Verbosity level.
#'
#' @return data.frame with columns "gene", "ensembl_transcript_id" and "sequence".
#'
#' @author EDG
#' @export
#'
#' @examples
#' \dontrun{
#'   mapt_seq <- gene2sequence("MAPT")
#' }
gene2sequence <- function(
  gene,
  organism = "hsapiens",
  biomart = "ensembl",
  host = "https://www.ensembl.org",
  seq_type = "coding",
  verbosity = 1L
) {
  # Check dependencies ----
  check_dependencies("biomaRt")

  # Arguments ----
  stopifnot(is.character(gene))

  if (verbosity > 0) {
    msg0("Getting sequence for gene ", highlight(gene), "...")
  }

  # Mart ----
  mart <- biomaRt::useMart(
    biomart = biomart,
    dataset = paste(organism, "_gene_ensembl", sep = ""),
    host = host
  )

  # Get transcript ID ----
  # Use gene name as filter and get transcript ID (ensembl_transcript_id)
  transcripts <- biomaRt::getBM(
    attributes = c("ensembl_gene_id", "ensembl_transcript_id"),
    filters = "hgnc_symbol",
    values = gene,
    mart = mart
  )

  msg0(
    "Found ",
    bold(nrow(transcripts)),
    " transcripts for gene ",
    highlight(gene),
    ".",
    verbosity = verbosity
  )

  # Get sequence ----
  # Retrieve sequence(s) using transcript ID
  sequence <- biomaRt::getSequence(
    id = transcripts[["ensembl_transcript_id"]],
    type = "ensembl_transcript_id",
    seqType = seq_type,
    mart = mart,
    verbose = verbosity > 1
  )

  if (verbosity > 0) {
    # Count number of sequences returned that are not "Sequence unavailable"
    nretrieved <- sum(sequence[["coding"]] != "Sequence unavailable")
    msg0(
      "Database returned sequences for ",
      bold(nretrieved),
      "/",
      nrow(sequence),
      " transcripts."
    )
  }

  seq <- data.frame(
    gene = gene,
    ensembl_transcript_id = sequence[["ensembl_transcript_id"]],
    sequence = sequence[["coding"]]
  )
  seq
}
