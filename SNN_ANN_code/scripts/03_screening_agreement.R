# =====================================================================
# 03_screening_agreement.R
# Compares two independent screenings of the same records and reports
# the observed agreement and Cohen's kappa for the three-level decision
# (INCLUDE / EXCLUDE / UNSURE) and for the binary decision (passes to
# the next stage or not). Lists the disagreements for adjudication.
#
# Usage: Rscript scripts/03_screening_agreement.R <reviewer1 files...> -- <reviewer2 files...>
# Example (pilot):
#   Rscript scripts/03_screening_agreement.R \
#     data/screening/pilot/pilot_1_reviewer1.tsv data/screening/pilot/pilot_2_reviewer1.tsv -- \
#     data/screening/pilot/pilot_1_reviewer2.tsv data/screening/pilot/pilot_2_reviewer2.tsv
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
args <- commandArgs(trailingOnly = TRUE)
sep  <- which(args == "--")
read_tsv <- function(files) rbindlist(lapply(files, function(f)
  fread(f, sep = "\t", header = FALSE, quote = "", fill = TRUE,
        col.names = c("record_id", "decision", "code", "hardware", "note"))))
r1 <- read_tsv(args[seq_len(sep - 1)])
r2 <- read_tsv(args[(sep + 1):length(args)])
m  <- merge(r1, r2, by = "record_id", suffixes = c("_1", "_2"))
cat("records compared:", nrow(m), " (reviewer 1:", nrow(r1), " reviewer 2:", nrow(r2), ")\n")

kappa <- function(a, b) {
  lev <- union(unique(a), unique(b)); tab <- table(factor(a, lev), factor(b, lev))
  po <- sum(diag(tab)) / sum(tab); pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  c(agreement = po, kappa = (po - pe) / (1 - pe))
}
cat("\nThree-level decision:\n"); print(table(m$decision_1, m$decision_2))
print(round(kappa(m$decision_1, m$decision_2), 3))
pass1 <- m$decision_1 != "EXCLUDE"; pass2 <- m$decision_2 != "EXCLUDE"
cat("\nBinary decision (passes to the next stage):\n"); print(table(pass1, pass2))
print(round(kappa(pass1, pass2), 3))
cat("\nExclusion codes, reviewer 1:\n"); print(table(m[decision_1 == "EXCLUDE", code_1]))
cat("Exclusion codes, reviewer 2:\n"); print(table(m[decision_2 == "EXCLUDE", code_2]))
dis <- m[pass1 != pass2 | (decision_1 == "INCLUDE" & decision_2 == "INCLUDE" & code_1 != code_2)]
cat("\nDisagreements (binary or category):", nrow(dis), "\n")
print(dis[, .(record_id, decision_1, code_1, decision_2, code_2, note_1, note_2)])
