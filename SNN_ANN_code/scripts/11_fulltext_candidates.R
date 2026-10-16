# =====================================================================
# 11_fulltext_candidates.R
# Lists the candidates for the full-text stage: studies included in the
# map whose hardware-measurement indicator is Y or U, plus every study
# in category C4 (lottery tickets in SNNs). Writes the public candidate
# list and, when the local corpus is available, the batch files with
# the bibliographic data that the full-text protocol expects.
#
# Inputs : data/results/mapping.csv (and data/processed/corpus.csv if present)
# Outputs: data/fulltext/candidates.csv
#          data/processed/fulltext_batches/fulltext_NN.txt
# Usage: Rscript scripts/11_fulltext_candidates.R <batch_size>   (review value: 5)
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
batch_size <- as.integer(commandArgs(trailingOnly = TRUE)[1])
map <- fread("data/results/mapping.csv", colClasses = "character", na.strings = "")
cand <- map[eligible == "Y" & (hardware_measured %in% c("Y", "U") | grepl("C4", categories))]
cand[, priority := fifelse(hardware_measured == "Y" | grepl("C4", categories), 1L, 2L)]
setorder(cand, priority, record_id)
cand[, batch := ceiling(.I / batch_size)]
fwrite(cand[, .(record_id, batch, priority, year, title, authors, venue, doi, open_access, categories,
                platform_snn, platform_ann, evidence, hardware_measured, note)],
       "data/fulltext/candidates.csv")
cat(nrow(cand), "candidates in", max(cand$batch), "batches;", sum(cand$priority == 1),
    "of priority 1 (Y or C4),", sum(cand$priority == 2), "of priority 2 (U)\n")

short_authors <- function(a) {
  v <- trimws(strsplit(ifelse(is.na(a), "", a), ";")[[1]])
  if (length(v) > 3) paste0(paste(v[1:3], collapse = "; "), " et al.") else paste(v, collapse = "; ")
}
out_dir <- "data/processed/fulltext_batches"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
for (k in unique(cand$batch)) {
  d <- cand[batch == k]
  txt <- sprintf("[%s] %s (%s). %s. %s. DOI: %s. Open access flag: %s.\n  Abstract-level codes: cats=%s; plat_snn=%s; plat_ann=%s; evidence=%s. Note: %s\n",
                 d$record_id, d$title, d$year, sapply(d$authors, short_authors),
                 ifelse(is.na(d$venue), "NR", d$venue), ifelse(is.na(d$doi) | d$doi == "", "none", d$doi),
                 ifelse(is.na(d$open_access) | d$open_access == "", "no", "yes"),
                 d$categories, d$platform_snn, d$platform_ann, d$evidence, d$note)
  writeLines(txt, file.path(out_dir, sprintf("fulltext_%02d.txt", k)))
}
