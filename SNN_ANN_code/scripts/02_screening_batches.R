# =====================================================================
# 02_screening_batches.R
# Splits the corpus into text batches for title/abstract screening and
# draws the stratified pilot sample. Each record is written with its
# identifier, year, document type, title, author keywords (up to 200
# characters) and abstract (up to 1,400 characters), which is all the
# screener sees at this stage. Index keywords are omitted because they
# are long and repeat the abstract.
#
# Inputs : data/processed/corpus.csv
# Outputs: data/processed/screening_batches/batch_NNN.txt
#          data/screening/batch_ids.csv      record -> batch
#          data/processed/pilot_1.txt, pilot_2.txt, data/screening/pilot_ids.csv
#          data/screening/kappa_sample/kappa_ids.csv   random agreement sample
#                                          (430 records outside the pilot, seed 7)
# Usage: Rscript scripts/02_screening_batches.R <batch_size> <pilot_size> <seed>
#        Values used in the review: 100 200 20261014
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
args       <- commandArgs(trailingOnly = TRUE)
batch_size <- as.integer(args[1]); pilot_size <- as.integer(args[2]); seed <- as.integer(args[3])
corpus <- fread("data/processed/corpus.csv", encoding = "UTF-8")
out_dir <- "data/processed/screening_batches"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

format_records <- function(d, abstract_limit = 1400L) {
  kw  <- substr(gsub("\\s+", " ", ifelse(is.na(d$author_keywords), "", d$author_keywords)), 1, 200)
  abs <- substr(gsub("\\s+", " ", ifelse(is.na(d$abstract), "", d$abstract)), 1, abstract_limit)
  paste0("[", d$record_id, "] (", d$year, "; ", d$document_type, ") ", d$title,
         "\nKW: ", kw, "\nABS: ", abs, "\n")
}

# Pilot sample, stratified by search block (proportional allocation)
set.seed(seed)
pilot <- corpus[, .SD[sample(.N, max(1, round(pilot_size * .N / nrow(corpus))))], by = block]
pilot_txt <- format_records(pilot)
half <- ceiling(length(pilot_txt) / 2)
writeLines(pilot_txt[seq_len(half)], file.path("data/processed", "pilot_1.txt"))
writeLines(pilot_txt[(half + 1):length(pilot_txt)], file.path("data/processed", "pilot_2.txt"))
fwrite(pilot[, .(record_id, block)], "data/screening/pilot_ids.csv")

# Screening batches in record order
setorder(corpus, record_id)
corpus[, batch := ceiling(.I / batch_size)]
for (k in unique(corpus$batch))
  writeLines(format_records(corpus[batch == k]), file.path(out_dir, sprintf("batch_%03d.txt", k)))
fwrite(corpus[, .(record_id, batch)], "data/screening/batch_ids.csv")

# Random sample for the second independent screening (agreement), drawn
# among the records outside the pilot, in record order, with seed 7
set.seed(7)
candidates <- corpus[!(record_id %in% pilot$record_id), .(record_id, batch)]
kappa_sample <- candidates[sample(.N, 430)]
dir.create("data/screening/kappa_sample", showWarnings = FALSE, recursive = TRUE)
fwrite(kappa_sample, "data/screening/kappa_sample/kappa_ids.csv")
cat("pilot:", nrow(pilot), "records; batches:", max(corpus$batch), "of up to", batch_size,
    "; agreement sample:", nrow(kappa_sample), "\n")
