# =====================================================================
# 08_charting_batches.R
# Builds the batches for eligibility confirmation and data charting
# with the COMPLETE abstract: every record whose final screening
# decision is INCLUDE or UNSURE. Also draws the random 10 % sample for
# the second independent charting (three files of up to 75 records).
#
# Inputs : data/processed/corpus.csv, data/results/screening_decisions.csv
# Outputs: data/processed/charting_batches/charting_NN.txt
#          data/screening/../charting/charting_ids.csv      record -> batch
#          data/processed/charting_batches/verification_N.txt
#          data/charting/verification_ids.csv
# Usage: Rscript scripts/08_charting_batches.R <seed>     (review value: 20261015)
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
seed <- as.integer(commandArgs(trailingOnly = TRUE)[1])
corpus    <- fread("data/processed/corpus.csv", encoding = "UTF-8")
decisions <- fread("data/results/screening_decisions.csv")
ids <- decisions[decision != "EXCLUDE", sort(record_id)]
d <- corpus[record_id %in% ids]; setorder(d, record_id)
kw  <- substr(gsub("\\s+", " ", ifelse(is.na(d$author_keywords), "", d$author_keywords)), 1, 200)
abs <- gsub("\\s+", " ", ifelse(is.na(d$abstract), "", d$abstract))
txt <- paste0("[", d$record_id, "] (", d$year, "; ", d$document_type, ") ", d$title,
              "\nKW: ", kw, "\nABS: ", abs, "\n")
out_dir <- "data/processed/charting_batches"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
group <- ceiling(seq_along(txt) / 100)
for (g in unique(group)) writeLines(txt[group == g], file.path(out_dir, sprintf("charting_%02d.txt", g)))
fwrite(data.table(record_id = d$record_id, batch = group), "data/charting/charting_ids.csv")
cat(length(txt), "records in", max(group), "files\n")

# 10 % verification sample for the second independent charting
set.seed(seed)
m <- sort(sample(d$record_id, round(0.10 * nrow(d))))
txm <- txt[d$record_id %in% m]
gm <- ceiling(seq_along(txm) / 75)
for (g in unique(gm)) writeLines(txm[gm == g], file.path(out_dir, sprintf("verification_%d.txt", g)))
fwrite(data.table(record_id = m), "data/charting/verification_ids.csv")
cat("verification sample:", length(m), "records in", max(gm), "files\n")
