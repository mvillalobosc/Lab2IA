# =====================================================================
# 01_deduplicate.R
# Merges the Scopus (CSV) and Web of Science (XLS, batches of 1,000)
# exports, removes duplicates by DOI and by normalised title, assigns
# each record to the search blocks A (ANN-SNN comparisons with an
# efficiency term) and B (pruning, sparsity and lottery tickets), and
# writes the counts that feed the PRISMA 2020 flow diagram.
#
# Inputs : data/raw/Scopus.csv and data/raw/Wos*.xls (not distributed:
#          run the search strings in data/raw/search_strings.txt and
#          export them with the fields described in the README)
# Outputs: data/processed/corpus.csv       full records with abstracts
#                                          (local use only, git-ignored)
#          data/records/records.csv        public metadata, no abstracts
#          data/records/duplicates.csv     records removed as duplicates
#          data/records/counts_identification.json
#
# Usage: Rscript scripts/01_deduplicate.R   (run from the repository root)
# =====================================================================
suppressPackageStartupMessages({
  library(data.table); library(readxl); library(stringi); library(jsonlite)
})
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
dir.create("data/records", showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------
# 1. Read and harmonise the fields used by screening and charting
# ---------------------------------------------------------------------
sc <- fread("data/raw/Scopus.csv", encoding = "UTF-8", quote = "\"")
setnames(sc, names(sc), stri_trans_general(names(sc), "Latin-ASCII"))
scopus <- data.table(
  source          = "Scopus",
  source_id       = sc$EID,
  title           = sc$Title,
  year            = as.integer(sc$Year),
  doi             = sc$DOI,
  abstract        = sc$Abstract,
  author_keywords = sc[["Author Keywords"]],
  index_keywords  = sc[["Index Keywords"]],
  document_type   = sc[["Document Type"]],
  venue           = sc[["Source title"]],
  authors         = sc$Authors,
  language        = sc[["Language of Original Document"]],
  citations       = suppressWarnings(as.integer(sc[["Cited by"]])),
  open_access     = sc[["Open Access"]]
)

wos_files <- sort(list.files("data/raw", pattern = "^Wos.*\\.xls$", full.names = TRUE))
wo <- rbindlist(lapply(wos_files, function(f) as.data.table(read_excel(f))), use.names = TRUE, fill = TRUE)
wos <- data.table(
  source          = "WoS",
  source_id       = wo[["UT (Unique WOS ID)"]],
  title           = wo[["Article Title"]],
  year            = as.integer(wo[["Publication Year"]]),
  doi             = wo$DOI,
  abstract        = wo$Abstract,
  author_keywords = wo[["Author Keywords"]],
  index_keywords  = wo[["Keywords Plus"]],
  document_type   = wo[["Document Type"]],
  venue           = wo[["Source Title"]],
  authors         = wo$Authors,
  language        = wo$Language,
  citations       = suppressWarnings(as.integer(wo[["Times Cited, All Databases"]])),
  open_access     = wo[["Open Access Designations"]]
)
all_records <- rbindlist(list(scopus, wos), use.names = TRUE)
n_scopus <- nrow(scopus); n_wos <- nrow(wos)

# ---------------------------------------------------------------------
# 2. Normalised keys: DOI in lower case without the resolver prefix;
#    title in lower case, ASCII, without punctuation
# ---------------------------------------------------------------------
norm_doi <- function(x) {
  x <- tolower(trimws(x)); x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x[is.na(x) | x == ""] <- NA_character_; x
}
norm_title <- function(x) {
  x <- stri_trans_general(tolower(x), "Latin-ASCII")
  trimws(gsub("\\s+", " ", gsub("[^a-z0-9]+", " ", x)))
}
all_records[, doi_key := norm_doi(doi)]
all_records[, title_key := norm_title(title)]

# ---------------------------------------------------------------------
# 3. Deduplication in two passes: (a) by DOI when present, (b) by
#    normalised title. The Scopus record is kept when a work appears in
#    both databases because it carries the index keywords; the WoS
#    identifier is preserved in wos_id for traceability.
# ---------------------------------------------------------------------
setorder(all_records, source)                       # "Scopus" sorts before "WoS"
all_records[, dedup_key := ifelse(is.na(doi_key), paste0("T:", title_key), paste0("D:", doi_key))]
all_records[, dup_doi   := duplicated(dedup_key)]
all_records[, dup_title := !dup_doi & duplicated(title_key) & title_key != ""]
all_records[, duplicate := dup_doi | dup_title]

wos_ids <- all_records[source == "WoS", .(title_key, wos_id = source_id)][!duplicated(title_key)]
unique_records <- merge(all_records[duplicate == FALSE], wos_ids, by = "title_key", all.x = TRUE)
unique_records[source == "WoS", wos_id := source_id]

# ---------------------------------------------------------------------
# 4. Search block of each record (same Boolean logic as the strings,
#    applied to title + abstract + keywords)
# ---------------------------------------------------------------------
txt <- tolower(paste(unique_records$title, unique_records$abstract,
                     unique_records$author_keywords, unique_records$index_keywords))
re_ann   <- "artificial neural network|deep neural network|deep learning|convolutional neural network"
re_snn   <- "spiking neural network|neuromorphic"
re_eff   <- "energy|power|efficien|latency"
re_lt    <- "lottery ticket|supermask|edge-popup|edge popup"
re_prune <- "pruning|sparsity|sparse"
unique_records[, block_A := grepl(re_ann, txt) & grepl(re_snn, txt) & grepl(re_eff, txt)]
unique_records[, block_B := grepl(re_lt, txt) | (grepl(re_prune, txt) & grepl(re_snn, txt))]
unique_records[, block := fifelse(block_A & block_B, "A+B",
                          fifelse(block_A, "A", fifelse(block_B, "B", "none")))]

# ---------------------------------------------------------------------
# 5. Record identifiers. Every screening and charting file refers to
#    the identifiers assigned in the original run, which are distributed
#    in data/records/record_ids.csv (record_id, source, source_id). When
#    that file is present the identifiers are taken from it, so that the
#    decision files keep matching; otherwise they are assigned by year
#    and normalised title.
# ---------------------------------------------------------------------
if (file.exists("data/records/record_ids.csv")) {
  id_map <- fread("data/records/record_ids.csv", colClasses = "character")
  unique_records <- merge(unique_records, id_map[, .(source_id, record_id)], by = "source_id", all.x = TRUE)
  stopifnot(!anyNA(unique_records$record_id), !anyDuplicated(unique_records$record_id))
  setorder(unique_records, record_id)
} else {
  setorder(unique_records, year, title_key)
  unique_records[, record_id := sprintf("R%05d", .I)]
}
cols <- c("record_id", "source", "source_id", "wos_id", "block", "title", "year", "doi",
          "document_type", "venue", "authors", "language", "citations", "open_access",
          "author_keywords", "index_keywords", "abstract")
setcolorder(unique_records, cols)
fwrite(unique_records[, ..cols], "data/processed/corpus.csv")
public_cols <- setdiff(cols, c("abstract", "index_keywords"))
fwrite(unique_records[, ..public_cols], "data/records/records.csv")
fwrite(all_records[duplicate == TRUE, .(source, source_id, title, year, doi,
                                        reason = fifelse(dup_doi, "DOI", "title"))],
       "data/records/duplicates.csv")

counts <- list(
  search_date            = "2026-10-14",
  identified_scopus      = n_scopus,
  identified_wos         = n_wos,
  identified_total       = n_scopus + n_wos,
  duplicates_by_doi      = sum(all_records$dup_doi),
  duplicates_by_title    = sum(all_records$dup_title),
  duplicates_total       = sum(all_records$duplicate),
  unique_records         = nrow(unique_records),
  unique_scopus_only     = sum(unique_records$source == "Scopus" & is.na(unique_records$wos_id)),
  unique_in_both         = sum(unique_records$source == "Scopus" & !is.na(unique_records$wos_id)),
  unique_wos_only        = sum(unique_records$source == "WoS"),
  by_block               = as.list(table(unique_records$block)),
  by_year                = as.list(table(unique_records$year)),
  by_document_type       = as.list(table(unique_records$document_type)),
  by_language            = as.list(table(unique_records$language))
)
write_json(counts, "data/records/counts_identification.json", pretty = TRUE, auto_unbox = TRUE)
cat(toJSON(counts, pretty = TRUE, auto_unbox = TRUE), "\n")
