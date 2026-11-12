# build_mapt.R
# ::a3::
# 2026- EDG rtemis.org
#
# Builds `examples/mapt.a3.json`: human microtubule-associated protein tau
# (MAPT), isoform 2N4R (UniProtKB P10636-8, isoform Tau-F; RefSeq NP_005901.2;
# 441 residues), annotated from UniProtKB, ClinVar, and the curated literature
# table `literature.tsv`, then validated and normalized with rtemis.a3.
#
# Writes `mapt.provenance.json` beside it: source releases and retrieval dates,
# counts of included and excluded records with the reason for each exclusion,
# and the validation result of a ClinVar import that reads the first entry of
# ClinVar's `protein_change` summary field instead of the isoform-specific HGVS
# expression. That import is written to `first-entry-import.a3.json`, an
# invalid document for demonstrating validation.
#
# Usage, from the repository root:
#   Rscript examples/mapt/build_mapt.R            # uses cached downloads
#   Rscript examples/mapt/build_mapt.R --refresh  # downloads again
#
# Requires: rtemis.a3 (>= 0.6.2), httr2, jsonlite, xml2.
#
# Coordinates. UniProtKB annotates the canonical isoform of P10636 (PNS-tau,
# 758 residues). Every UniProtKB position is mapped to isoform Tau-F through
# the entry's own alternative-sequence features; a feature whose residues are
# absent from Tau-F is excluded and counted. ClinVar positions come from the
# HGVS protein expression on NP_005901.2, which is identical in sequence to
# P10636-8 (checked below). The variant literature on tau numbers residues on
# 2N4R, so the document uses the coordinates in which P301L is written.

suppressPackageStartupMessages({
  library(rtemis.a3)
  library(httr2)
  library(jsonlite)
  library(xml2)
})

# %% Configuration ----
args <- commandArgs(trailingOnly = TRUE)
refresh <- "--refresh" %in% args

script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 1L) {
    dirname(normalizePath(sub("^--file=", "", file_arg)))
  } else {
    normalizePath("examples/mapt")
  }
})
cache_dir <- file.path(script_dir, "cache")
dir.create(cache_dir, showWarnings = FALSE)

cfg <- list(
  uniprot_accession = "P10636",
  isoform_accession = "P10636-8",
  isoform_name = "Tau-F",
  refseq_protein = "NP_005901.2",
  gene = "MAPT",
  clinvar_classes = c(
    "Pathogenic",
    "Likely pathogenic",
    "Pathogenic/Likely pathogenic"
  ),
  out_document = file.path(dirname(script_dir), "mapt.a3.json"),
  out_provenance = file.path(script_dir, "mapt.provenance.json"),
  out_first_entry = file.path(script_dir, "first-entry-import.a3.json"),
  literature = file.path(script_dir, "literature.tsv"),
  user_agent = "a3-mapt-example (https://github.com/rtemis-org/a3)",
  eutils = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
)

# %% Download with a file cache ----
# Each response body is stored in `cache/<name>`, with the response headers
# that identify the data release in `cache/<name>.headers.json`. A cached file
# is read unless `--refresh` is given, so a rebuild reproduces the same
# document from the same downloads.
fetch <- function(name, url, body = NULL) {
  path <- file.path(cache_dir, name)
  meta_path <- paste0(path, ".headers.json")
  if (!refresh && file.exists(path)) {
    return(list(
      text = paste(readLines(path, warn = FALSE), collapse = "\n"),
      headers = if (file.exists(meta_path)) read_json(meta_path) else list()
    ))
  }
  req <- request(url) |>
    req_user_agent(cfg$user_agent) |>
    req_retry(max_tries = 4L, backoff = function(i) 2^i) |>
    req_throttle(capacity = 3L, fill_time_s = 1)
  if (!is.null(body)) {
    req <- req_body_form(req, !!!body)
  }
  resp <- req_perform(req)
  text <- resp_body_string(resp)
  writeLines(text, path)
  keep <- c(
    "x-uniprot-release",
    "x-uniprot-release-date",
    "date"
  )
  headers <- as.list(unclass(resp_headers(resp)))
  headers <- headers[tolower(names(headers)) %in% keep]
  names(headers) <- tolower(names(headers))
  write_json(headers, meta_path, auto_unbox = TRUE, pretty = TRUE)
  list(text = text, headers = headers)
}

fasta_sequence <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  paste(lines[!startsWith(lines, ">")], collapse = "")
}

# %% UniProtKB entry and isoform ----
uniprot_resp <- fetch(
  "uniprot_P10636.json",
  paste0("https://rest.uniprot.org/uniprotkb/", cfg$uniprot_accession, ".json")
)
uniprot <- fromJSON(uniprot_resp$text, simplifyVector = FALSE)
canonical <- uniprot$sequence$value

isoform_seq <- fasta_sequence(
  fetch(
    "uniprot_P10636-8.fasta",
    paste0(
      "https://rest.uniprot.org/uniprotkb/",
      cfg$isoform_accession,
      ".fasta"
    )
  )$text
)
refseq_seq <- fasta_sequence(
  fetch(
    "refseq_NP_005901.2.fasta",
    paste0(
      cfg$eutils,
      "/efetch.fcgi?db=protein&rettype=fasta&id=",
      cfg$refseq_protein
    )
  )$text
)
stopifnot(
  "P10636-8 and NP_005901.2 differ" = identical(isoform_seq, refseq_seq)
)

features <- uniprot$features
ftype <- vapply(features, `[[`, character(1L), "type")
fstart <- vapply(features, function(f) f$location$start$value, numeric(1L))
fend <- vapply(features, function(f) f$location$end$value, numeric(1L))
fdesc <- vapply(
  features,
  function(f) if (is.null(f$description)) "" else f$description,
  character(1L)
)
fid <- vapply(
  features,
  function(f) if (is.null(f$featureId)) "" else f$featureId,
  character(1L)
)

# %% Canonical-to-isoform coordinate map ----
# An alternative-sequence feature applies to the isoform when its description,
# "in isoform A, isoform B and isoform C", names the isoform. A feature with
# no alternative sequence deletes its span; one with an alternative sequence
# replaces it. `pos_map[i]` is the isoform position of canonical residue `i`,
# or NA when that residue is deleted or replaced.
applies_to_isoform <- function(desc, isoform) {
  names <- strsplit(sub("^in ", "", desc), ",\\s*|\\s+and\\s+")[[1L]]
  isoform %in% trimws(sub("^isoform\\s+", "", names))
}

vsp <- which(
  ftype == "Alternative sequence" &
    vapply(fdesc, applies_to_isoform, logical(1L), cfg$isoform_name)
)
vsp <- vsp[order(fstart[vsp])]

pos_map <- rep(NA_integer_, nchar(canonical))
pieces <- character(0L)
cursor <- 1L
next_pos <- 1L
for (i in vsp) {
  s <- as.integer(fstart[i])
  e <- as.integer(fend[i])
  if (s > cursor) {
    keep <- cursor:(s - 1L)
    pos_map[keep] <- next_pos + seq_along(keep) - 1L
    next_pos <- next_pos + length(keep)
    pieces <- c(pieces, substr(canonical, cursor, s - 1L))
  }
  alt <- features[[i]]$alternativeSequence$alternativeSequences
  if (length(alt) > 0L) {
    pieces <- c(pieces, alt[[1L]])
    next_pos <- next_pos + nchar(alt[[1L]])
  }
  cursor <- e + 1L
}
if (cursor <= nchar(canonical)) {
  keep <- cursor:nchar(canonical)
  pos_map[keep] <- next_pos + seq_along(keep) - 1L
  pieces <- c(pieces, substr(canonical, cursor, nchar(canonical)))
}
stopifnot(
  "Applying the alternative-sequence features to the canonical sequence does not reproduce P10636-8" = identical(
    paste(pieces, collapse = ""),
    isoform_seq
  )
)

residue <- function(pos) substr(isoform_seq, pos, pos)

map_position <- function(p) pos_map[p]

# A range maps to the span of its retained residues. A range whose residues
# are all absent from the isoform maps to NA.
map_range <- function(s, e) {
  kept <- pos_map[s:e]
  kept <- kept[!is.na(kept)]
  if (length(kept) == 0L) {
    return(c(NA_integer_, NA_integer_))
  }
  c(min(kept), max(kept))
}

excluded <- list()
exclude <- function(source, reason, n = 1L) {
  if (n == 0L) {
    return(invisible())
  }
  key <- paste(source, reason, sep = ": ")
  excluded[[key]] <<- (if (is.null(excluded[[key]])) 0L else excluded[[key]]) +
    as.integer(n)
}

# %% Residue lint ----
# A3 validation checks shape, bounds, and a variant's `from` residue. It does
# not check that a modification sits on a residue that can carry it. The
# builder checks each position against the residues its annotation allows and
# stops on any mismatch, so a coordinate error in a source cannot enter the
# document.
check_residues <- function(label, positions, allowed) {
  allowed <- rep_len(allowed, length(positions))
  got <- vapply(positions, residue, character(1L))
  bad <- !mapply(grepl, got, allowed, MoreArgs = list(fixed = TRUE))
  if (any(bad)) {
    stop(
      label,
      ": residue mismatch at ",
      paste0(
        got[bad],
        positions[bad],
        " (expected ",
        allowed[bad],
        ")",
        collapse = ", "
      ),
      call. = FALSE
    )
  }
}

# %% UniProtKB: regions ----
region <- list()

repeats <- which(ftype == "Repeat")
for (i in repeats) {
  r <- map_range(fstart[i], fend[i])
  if (anyNA(r)) {
    exclude("UniProtKB Repeat", "absent from the isoform")
    next
  }
  # "Tau/MAP 1" is repeat R1.
  name <- sub("^Tau/MAP\\s+", "R", fdesc[i])
  region[[name]] <- list(index = list(r), type = "repeat")
}

regions <- which(ftype == "Region")
region_ranges <- split(
  lapply(regions, function(i) map_range(fstart[i], fend[i])),
  fdesc[regions]
)
for (name in names(region_ranges)) {
  rr <- Filter(function(r) !anyNA(r), region_ranges[[name]])
  exclude(
    "UniProtKB Region",
    "absent from the isoform",
    length(region_ranges[[name]]) - length(rr)
  )
  if (length(rr) > 0L) {
    region[[name]] <- list(index = rr, type = "region")
  }
}

# The two N-terminal inserts are the alternatively spliced segments that Tau-F
# retains and the 0N and 1N isoforms delete. They are UniProtKB features
# VSP_003176 and VSP_003177, read from the entry rather than typed here.
inserts <- which(fid %in% c("VSP_003176", "VSP_003177"))
stopifnot(length(inserts) == 2L)
region[["N-terminal inserts"]] <- list(
  index = lapply(inserts[order(fstart[inserts])], function(i) {
    map_range(fstart[i], fend[i])
  }),
  type = "alternatively spliced segment"
)

for (t in c(
  "Compositional bias",
  "Helix",
  "Beta strand",
  "Turn",
  "Mutagenesis",
  "Sequence conflict",
  "Site"
)) {
  exclude(paste("UniProtKB", t), "feature type not included", sum(ftype == t))
}
exclude(
  "UniProtKB Alternative sequence",
  "used for the coordinate map and the N-terminal inserts, not annotated",
  sum(ftype == "Alternative sequence")
)

# %% UniProtKB: post-translational modifications ----
# One named set per modification class. `allowed` is the residue each
# UniProtKB description permits; a description absent from this table stops
# the build so that the table is extended deliberately.
ptm_classes <- data.frame(
  description = c(
    "Phosphoserine",
    "Phosphothreonine",
    "Phosphotyrosine",
    "N6-acetyllysine",
    "N-acetylalanine",
    "N6-methyllysine",
    "N6,N6-dimethyllysine",
    "Omega-N-methylarginine",
    "Deamidated asparagine",
    "N-linked (Glc) (glycation) lysine",
    "O-linked (GlcNAc) serine",
    "Glycyl lysine isopeptide (Lys-Gly) (interchain with G-Cter in ubiquitin)"
  ),
  set = c(
    "Phosphorylation",
    "Phosphorylation",
    "Phosphorylation",
    "Acetylation",
    "Acetylation",
    "Methylation",
    "Methylation",
    "Methylation",
    "Deamidation",
    "Glycation",
    "O-GlcNAcylation",
    "Ubiquitination"
  ),
  type = c(
    "phosphorylation",
    "phosphorylation",
    "phosphorylation",
    "acetylation",
    "acetylation",
    "methylation",
    "methylation",
    "methylation",
    "deamidation",
    "glycation",
    "O-GlcNAcylation",
    "ubiquitination"
  ),
  allowed = c("S", "T", "Y", "K", "A", "K", "K", "R", "N", "K", "S", "K")
)

ptm_features <- which(
  ftype %in% c("Modified residue", "Glycosylation", "Cross-link")
)
ptm_head <- sub(";.*$", "", fdesc[ptm_features])
unknown <- setdiff(ptm_head, ptm_classes$description)
if (length(unknown) > 0L) {
  stop(
    "Add these UniProtKB descriptions to `ptm_classes`: ",
    paste(unique(unknown), collapse = "; "),
    call. = FALSE
  )
}

ptm_rows <- data.frame(
  canonical = as.integer(fstart[ptm_features]),
  head = ptm_head
)
ptm_rows$position <- map_position(ptm_rows$canonical)
exclude(
  "UniProtKB modification",
  "absent from the isoform",
  sum(is.na(ptm_rows$position))
)
ptm_rows <- ptm_rows[!is.na(ptm_rows$position), ]
ptm_rows <- merge(ptm_rows, ptm_classes, by.x = "head", by.y = "description")
check_residues("UniProtKB modifications", ptm_rows$position, ptm_rows$allowed)

ptm <- list()
for (s in unique(ptm_classes$set)) {
  rows <- ptm_rows[ptm_rows$set == s, ]
  if (nrow(rows) == 0L) {
    next
  }
  # Two UniProtKB features can assign one residue to one class (for example,
  # mono- and dimethyl-lysine); the set holds the residue once.
  ptm[[s]] <- list(
    index = sort(unique(rows$position)),
    type = rows$type[[1L]]
  )
}

disulfide <- which(ftype == "Disulfide bond")
for (i in disulfide) {
  pair <- map_position(c(fstart[i], fend[i]))
  if (anyNA(pair)) {
    exclude("UniProtKB Disulfide bond", "absent from the isoform")
    next
  }
  check_residues("UniProtKB disulfide bond", pair, "C")
  ptm[["Disulfide bond"]] <- list(index = pair, type = "disulfide bond")
}

# %% UniProtKB: processing ----
processing <- list()
for (i in which(ftype == "Initiator methionine")) {
  p <- map_position(fstart[i])
  check_residues("UniProtKB initiator methionine", p, "M")
  processing[["Initiator methionine"]] <- list(
    index = p,
    type = "initiator methionine removed"
  )
}
for (i in which(ftype == "Chain")) {
  processing[["Chain"]] <- list(
    index = list(map_range(fstart[i], fend[i])),
    type = "chain"
  )
}

# %% Literature: epitopes and cleavage sites ----
# `literature.tsv` holds residue-level annotations that UniProtKB does not
# carry, each with its reference. Positions are on 2N4R; `residues` lists the
# expected residue at each position, checked against the sequence.
lit <- utils::read.delim(cfg$literature, comment.char = "#", quote = "")
site <- list()
for (k in seq_len(nrow(lit))) {
  positions <- as.integer(strsplit(lit$positions[[k]], " ", fixed = TRUE)[[1L]])
  allowed <- strsplit(lit$residues[[k]], "", fixed = TRUE)[[1L]]
  check_residues(lit$name[[k]], positions, allowed)
  entry <- list(index = positions, type = lit$type[[k]])
  if (lit$family[[k]] == "site") {
    site[[lit$name[[k]]]] <- entry
  } else if (lit$family[[k]] == "processing") {
    processing[[lit$name[[k]]]] <- entry
  } else {
    stop("literature.tsv: unsupported family ", lit$family[[k]], call. = FALSE)
  }
}

# %% UniProtKB: natural variants ----
uniprot_variants <- list()
for (i in which(ftype == "Natural variant")) {
  p <- map_position(fstart[i])
  if (is.na(p)) {
    exclude("UniProtKB Natural variant", "absent from the isoform")
    next
  }
  f <- features[[i]]
  alt <- f$alternativeSequence
  record <- list(position = p)
  if (length(alt$alternativeSequences) > 0L) {
    record$from <- alt$originalSequence
    record$to <- alt$alternativeSequences[[1L]]
    record$type <- "missense"
  } else {
    # UniProtKB writes a deleted residue as a feature with no alternative
    # sequence.
    record$type <- "deletion"
  }
  dbsnp <- Filter(
    function(x) identical(x$database, "dbSNP"),
    f$featureCrossReferences
  )
  record$source <- "UniProtKB"
  record$id <- f$featureId
  record$description <- sub(";\\s*dbSNP:rs[0-9]+$", "", f$description)
  if (length(dbsnp) > 0L) {
    record$dbsnp <- dbsnp[[1L]]$id
  }
  uniprot_variants[[length(uniprot_variants) + 1L]] <- record
}

# %% ClinVar ----
# All ClinVar records for the gene are listed and summarized, then filtered
# here: the record names MAPT as its only gene, and its aggregate germline
# classification is pathogenic or likely pathogenic. The protein change is
# read from the record's HGVS expression on NP_005901.2.
search_resp <- fetch(
  "clinvar_esearch.json",
  paste0(
    cfg$eutils,
    "/esearch.fcgi?db=clinvar&retmode=json&retmax=5000&term=",
    cfg$gene,
    "%5Bgene%5D"
  )
)
uids <- fromJSON(search_resp$text)$esearchresult$idlist
clinvar_retrieved <- search_resp$headers[["date"]]

batches <- split(uids, ceiling(seq_along(uids) / 300L))
summaries <- list()
for (b in seq_along(batches)) {
  res <- fromJSON(
    fetch(
      sprintf("clinvar_esummary_%02d.json", b),
      paste0(cfg$eutils, "/esummary.fcgi"),
      body = list(
        db = "clinvar",
        retmode = "json",
        id = paste(batches[[b]], collapse = ",")
      )
    )$text,
    simplifyVector = FALSE
  )$result
  summaries <- c(summaries, res[setdiff(names(res), "uids")])
}

classification <- vapply(
  summaries,
  function(s) {
    d <- s$germline_classification$description
    if (is.null(d)) "" else d
  },
  character(1L)
)
only_gene <- vapply(
  summaries,
  function(s) {
    symbols <- vapply(s$genes, `[[`, character(1L), "symbol")
    identical(unique(symbols), cfg$gene)
  },
  logical(1L)
)
exclude(
  "ClinVar",
  "classification not pathogenic or likely pathogenic",
  sum(!classification %in% cfg$clinvar_classes)
)
exclude(
  "ClinVar",
  "pathogenic or likely pathogenic, not MAPT alone",
  sum(classification %in% cfg$clinvar_classes & !only_gene)
)
selected <- summaries[classification %in% cfg$clinvar_classes & only_gene]

conditions <- function(s) {
  names <- vapply(
    s$germline_classification$trait_set,
    function(t) if (is.null(t$trait_name)) "" else t$trait_name,
    character(1L)
  )
  unique(names[nzchar(names) & names != "not provided"])
}

vcv_ids <- vapply(selected, `[[`, character(1L), "uid")
vcv_batches <- split(vcv_ids, ceiling(seq_along(vcv_ids) / 20L))
archives <- list()
for (b in seq_along(vcv_batches)) {
  xml <- read_xml(
    fetch(
      sprintf("clinvar_vcv_%02d.xml", b),
      paste0(
        cfg$eutils,
        "/efetch.fcgi?db=clinvar&rettype=vcv&is_variationid&id=",
        paste(vcv_batches[[b]], collapse = ",")
      )
    )$text
  )
  for (node in xml_find_all(xml, "//VariationArchive")) {
    archives[[xml_attr(node, "VariationID")]] <- node
  }
}

parse_change <- function(x) {
  m <- regmatches(x, regexec("^([A-Z])([0-9]+)([A-Z*]|del)$", x))[[1L]]
  if (length(m) == 0L) {
    return(NULL)
  }
  list(
    from = m[[2L]],
    position = as.integer(m[[3L]]),
    to = m[[4L]],
    type = switch(
      m[[4L]],
      "*" = "nonsense",
      "del" = "deletion",
      "missense"
    )
  )
}

clinvar_variants <- list()
first_entry_variants <- list()
first_entry_same_position <- 0L
first_entry_displaced <- character(0L)
for (s in selected) {
  node <- archives[[s$uid]]
  expr <- xml_find_first(
    node,
    sprintf(
      ".//ProteinExpression[@sequenceAccessionVersion='%s']",
      cfg$refseq_protein
    )
  )
  change <- if (inherits(expr, "xml_missing")) {
    NULL
  } else {
    parse_change(xml_attr(expr, "singleLetterProteinChange"))
  }

  # The import that `protein_change` invites: its first single-residue entry,
  # whichever isoform it was written on.
  entries <- trimws(strsplit(s$protein_change, ",", fixed = TRUE)[[1L]])
  first <- NULL
  for (e in entries) {
    first <- parse_change(e)
    if (!is.null(first)) break
  }

  if (is.null(change)) {
    exclude(
      "ClinVar",
      paste(
        "no single-residue change on",
        cfg$refseq_protein,
        "(noncoding, splice, multi-residue, or outside the isoform)"
      )
    )
    next
  }

  gc <- xml_find_first(node, ".//Classifications/GermlineClassification")
  record <- list(
    position = change$position,
    from = change$from,
    to = if (change$to == "del") NULL else change$to,
    type = change$type,
    source = "ClinVar",
    id = paste0(xml_attr(node, "Accession"), ".", xml_attr(node, "Version")),
    hgvs_p = xml_text(xml_find_first(expr, "Expression")),
    clinical_significance = xml_text(xml_find_first(gc, "Description")),
    review_status = xml_text(xml_find_first(gc, "ReviewStatus")),
    conditions = conditions(s)
  )
  clinvar_variants[[length(clinvar_variants) + 1L]] <- Filter(
    Negate(is.null),
    record
  )
  if (!is.null(first)) {
    first_entry_variants[[length(first_entry_variants) + 1L]] <- list(
      position = first$position,
      from = first$from,
      source = "ClinVar",
      id = record$id
    )
    first_entry_same_position <- first_entry_same_position +
      as.integer(first$position == change$position)
    if (first$position != change$position) {
      first_entry_displaced <- c(first_entry_displaced, record$id)
    }
  }
}

# %% Assemble, validate, normalize, write ----
make_document <- function(variant) {
  list(
    `$schema` = "https://schema.rtemis.org/a3/v1/schema.json",
    a3_version = "1.0.0",
    sequence = isoform_seq,
    annotations = list(
      site = site,
      region = region,
      ptm = ptm,
      processing = processing,
      variant = variant
    ),
    metadata = list(
      uniprot_id = cfg$isoform_accession,
      description = paste(
        "Microtubule-associated protein tau, isoform 2N4R",
        "(UniProtKB isoform Tau-F; RefSeq NP_005901.2)"
      ),
      reference = paste(
        "UniProtKB P10636; ClinVar; literature.tsv;",
        "see mapt.provenance.json"
      ),
      organism = "Homo sapiens"
    )
  )
}

# Index arrays are written as JSON arrays even when they hold one element, and
# ranges as two-element arrays.
to_json_text <- function(doc) {
  as_index <- function(entry) {
    idx <- entry$index
    entry$index <- if (is.list(idx)) {
      lapply(idx, function(r) I(as.integer(r)))
    } else {
      I(as.integer(idx))
    }
    entry
  }
  for (fam in c("site", "region", "ptm", "processing")) {
    doc$annotations[[fam]] <- lapply(doc$annotations[[fam]], as_index)
    if (length(doc$annotations[[fam]]) == 0L) {
      doc$annotations[[fam]] <- structure(list(), names = character(0L))
    }
  }
  doc$annotations$variant <- lapply(doc$annotations$variant, function(v) {
    if (!is.null(v$conditions)) {
      v$conditions <- I(v$conditions)
    }
    v
  })
  toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

validate_text <- function(text) {
  tmp <- tempfile(fileext = ".a3.json")
  on.exit(unlink(tmp))
  writeLines(text, tmp)
  validate_A3json(tmp)
}

variants <- c(uniprot_variants, clinvar_variants)
variants <- variants[order(
  vapply(variants, `[[`, numeric(1L), "position"),
  vapply(variants, `[[`, character(1L), "source")
)]
document_text <- to_json_text(make_document(variants))
issues <- validate_text(document_text)
if (nrow(issues) > 0L) {
  print(issues)
  stop("The assembled document is not valid A3.", call. = FALSE)
}

# Reading through rtemis.a3 normalizes the document; writing it back gives the
# canonical serialization that all five implementations agree on.
tmp <- tempfile(fileext = ".a3.json")
writeLines(document_text, tmp)
a3 <- read_A3json(tmp, verbosity = 0L)
unlink(tmp)
write_A3json(a3, cfg$out_document, overwrite = TRUE)

# The first-entry import, validated against the same sequence and written
# beside the document as an invalid example. An issue path
# `/annotations/variant/N/...` names the record at 0-based subscript N.
first_entry_text <- to_json_text(make_document(first_entry_variants))
writeLines(first_entry_text, cfg$out_first_entry)
first_entry_issues <- validate_text(first_entry_text)
flagged_subscripts <- unique(as.integer(sub(
  "^/annotations/variant/([0-9]+).*$",
  "\\1",
  first_entry_issues$path
)))
first_entry_flagged <- vapply(
  first_entry_variants[flagged_subscripts + 1L],
  `[[`,
  character(1L),
  "id"
)

# %% Provenance ----
# Positions in a position index, ranges in a range index.
count_index <- function(entries) {
  vapply(entries, function(e) length(e$index), integer(1L))
}

provenance <- list(
  document = "examples/mapt.a3.json",
  built = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  sequence = list(
    uniprot = cfg$isoform_accession,
    isoform = cfg$isoform_name,
    refseq = cfg$refseq_protein,
    length = nchar(isoform_seq),
    identical_to_refseq = identical(isoform_seq, refseq_seq),
    reconstructed_from_canonical = TRUE
  ),
  sources = list(
    uniprotkb = list(
      accession = cfg$uniprot_accession,
      release = uniprot_resp$headers[["x-uniprot-release"]],
      release_date = uniprot_resp$headers[["x-uniprot-release-date"]],
      entry_version = uniprot$entryAudit$entryVersion,
      sequence_version = uniprot$entryAudit$sequenceVersion,
      canonical_length = nchar(canonical),
      license = "CC BY 4.0"
    ),
    clinvar = list(
      query = paste0(cfg$gene, "[gene]"),
      retrieved = clinvar_retrieved,
      records_listed = length(uids),
      classifications_included = cfg$clinvar_classes,
      records_included = length(clinvar_variants),
      protein_reference = cfg$refseq_protein
    ),
    literature = lapply(seq_len(nrow(lit)), function(k) {
      list(
        name = lit$name[[k]],
        reference = lit$reference[[k]],
        doi = lit$doi[[k]],
        pmid = as.character(lit$pmid[[k]])
      )
    })
  ),
  counts = list(
    site = as.list(count_index(site)),
    region = as.list(count_index(region)),
    ptm = as.list(count_index(ptm)),
    processing = as.list(count_index(processing)),
    variant = list(
      UniProtKB = length(uniprot_variants),
      ClinVar = length(clinvar_variants)
    )
  ),
  excluded = excluded,
  first_entry_import = list(
    description = paste(
      "ClinVar records above, positioned by the first single-residue entry of",
      "the esummary `protein_change` field instead of the HGVS expression on",
      cfg$refseq_protein,
      "and validated against the same sequence."
    ),
    document = basename(cfg$out_first_entry),
    records = length(first_entry_variants),
    records_at_refseq_position = first_entry_same_position,
    records_displaced = I(first_entry_displaced),
    records_flagged = I(first_entry_flagged),
    displaced_not_flagged = I(setdiff(
      first_entry_displaced,
      first_entry_flagged
    )),
    flagged_not_displaced = I(setdiff(
      first_entry_flagged,
      first_entry_displaced
    )),
    issues = as.list(table(first_entry_issues$code))
  ),
  r = list(
    version = R.version.string,
    rtemis.a3 = as.character(utils::packageVersion("rtemis.a3"))
  )
)
write_json(
  provenance,
  cfg$out_provenance,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

message(
  "Wrote ",
  cfg$out_document,
  "\n  site: ",
  length(site),
  " sets; region: ",
  length(region),
  " sets; ptm: ",
  length(ptm),
  " sets; processing: ",
  length(processing),
  " sets; variant: ",
  length(variants),
  " records",
  "\nFirst-entry ClinVar import: ",
  nrow(first_entry_issues),
  " validation issues"
)
