# =====================================================================
# 05_full_abstract_batches.R
# Writes batches with the COMPLETE abstract for a given list of record
# identifiers. Used for (1) the re-screening of records excluded in the
# first pass whose truncated abstract hid relevant content and (2) the
# second independent screening of the random agreement sample.
#
# Inputs : data/processed/corpus.csv, a CSV whose first column holds record ids
# Usage: Rscript scripts/05_full_abstract_batches.R <ids.csv> <output_prefix> <batch_size>
# Examples used in the review:
#   Rscript scripts/05_full_abstract_batches.R data/screening/kappa_sample/kappa_ids.csv data/processed/kappa 86
#   Rscript scripts/05_full_abstract_batches.R data/screening/rescreen/rescreen_a_ids.csv data/processed/rescreen_a 80
#   Rscript scripts/05_full_abstract_batches.R data/screening/rescreen/rescreen_b_ids.csv data/processed/rescreen_b 100
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
a <- commandArgs(trailingOnly = TRUE)
corpus <- fread("data/processed/corpus.csv", encoding = "UTF-8")
ids    <- fread(a[1])[[1]]
prefix <- a[2]; batch_size <- as.integer(a[3])
d <- corpus[record_id %in% ids]
setorder(d, record_id)
kw  <- substr(gsub("\\s+", " ", ifelse(is.na(d$author_keywords), "", d$author_keywords)), 1, 200)
abs <- gsub("\\s+", " ", ifelse(is.na(d$abstract), "", d$abstract))
txt <- paste0("[", d$record_id, "] (", d$year, "; ", d$document_type, ") ", d$title,
              "\nKW: ", kw, "\nABS: ", abs, "\n")
group <- ceiling(seq_along(txt) / batch_size)
for (g in unique(group)) writeLines(txt[group == g], sprintf("%s_%02d.txt", prefix, g))
cat(length(txt), "records in", max(group), "files\n")
