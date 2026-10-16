# =====================================================================
# 04_check_screening_batches.R
# Checks that every screening file holds exactly the records of its
# batch, in the same order, with no invented or repeated identifiers,
# a valid decision and a code consistent with the decision.
#
# Inputs : data/screening/batch_ids.csv, data/screening/title_abstract/batch_NNN.tsv
# Usage: Rscript scripts/04_check_screening_batches.R
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
ids <- fread("data/screening/batch_ids.csv")
dir_tsv <- "data/screening/title_abstract"
res <- rbindlist(lapply(sort(unique(ids$batch)), function(k) {
  f <- file.path(dir_tsv, sprintf("batch_%03d.tsv", k))
  if (!file.exists(f)) return(data.table(batch = k, status = "missing", n = 0L, problems = ""))
  d <- fread(f, sep = "\t", header = FALSE, quote = "", fill = TRUE,
             col.names = c("record_id", "decision", "code", "hardware", "note"))
  expected <- ids[batch == k, record_id]
  p <- character(0)
  if (nrow(d) != length(expected)) p <- c(p, sprintf("%d rows of %d", nrow(d), length(expected)))
  if (!setequal(d$record_id, expected))
    p <- c(p, sprintf("different ids (%d foreign, %d missing)",
                      length(setdiff(d$record_id, expected)), length(setdiff(expected, d$record_id))))
  if (anyDuplicated(d$record_id)) p <- c(p, "repeated ids")
  if (!all(d$decision %in% c("INCLUDE", "EXCLUDE", "UNSURE"))) p <- c(p, "invalid decision")
  if (any(d$decision == "EXCLUDE" & !grepl("^E[1-7]$", d$code))) p <- c(p, "invalid E code")
  if (any(d$decision == "INCLUDE" & !grepl("^C[1-6](\\+C[1-6])*$", d$code))) p <- c(p, "invalid C code")
  data.table(batch = k, status = if (length(p)) "check" else "ok", n = nrow(d), problems = paste(p, collapse = "; "))
}))
print(res[status != "ok"])
cat("ok:", sum(res$status == "ok"), " check:", sum(res$status == "check"), " missing:", sum(res$status == "missing"), "\n")
