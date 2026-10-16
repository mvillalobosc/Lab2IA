# =====================================================================
# 07_consolidate_screening.R
# Consolidates the title/abstract screening:
#  - first pass (64 batches, abstract shown up to 1,400 characters);
#  - re-screening with the complete abstract of the set defined by
#    06_rescreen_set.R (its decision replaces the first one);
#  - removal of the late duplicates listed by 06_rescreen_set.R;
#  - agreement between the final decision and the second independent
#    screening of the random sample (complete abstract).
# Writes the final decision for every record and the screening counts.
#
# Inputs : data/records/records.csv, data/records/counts_identification.json,
#          data/records/late_duplicates.csv, data/screening/**
# Outputs: data/results/screening_decisions.csv
#          data/results/screening_disagreements.csv
#          data/results/counts_screening.json
# Usage: Rscript scripts/07_consolidate_screening.R
# =====================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
read_tsv <- function(files) rbindlist(lapply(files, function(f)
  fread(f, sep = "\t", header = FALSE, quote = "", fill = TRUE,
        col.names = c("record_id", "decision", "code", "hardware", "note"))))

records <- fread("data/records/records.csv", encoding = "UTF-8")
ident   <- fromJSON("data/records/counts_identification.json")

late_dup <- fread("data/records/late_duplicates.csv")
setorder(records, record_id)

first_pass <- read_tsv(sprintf("data/screening/title_abstract/batch_%03d.tsv", 1:64))
first_pass <- first_pass[!(record_id %in% late_dup$record_id)]
rule_ids   <- fread("data/screening/rescreen/rescreen_rule_ids.csv")[[1]]
rescreen_a <- read_tsv(sprintf("data/screening/rescreen/rescreen_a_%s.tsv", c("1", "2a", "2b", "3")))
rescreen_b <- read_tsv(sprintf("data/screening/rescreen/rescreen_b_%02d.tsv", 1:9))
rescreen   <- rbind(rescreen_a[record_id %in% rule_ids], rescreen_b)
stopifnot(setequal(rescreen$record_id, rule_ids), !anyDuplicated(rescreen$record_id),
          all(rescreen$decision %in% c("INCLUDE", "EXCLUDE", "UNSURE")))

final <- copy(first_pass)
final[, stage := "first_pass"]
final[rescreen, on = "record_id", `:=`(decision = i.decision, code = i.code, hardware = i.hardware,
                                       note = i.note, stage = "rescreened")]
cat("re-screened:", nrow(rescreen), "records;", sum(rescreen$decision != "EXCLUDE"), "pass (",
    sum(rescreen$decision == "INCLUDE"), "INCLUDE,", sum(rescreen$decision == "UNSURE"), "UNSURE )\n")

batches <- fread("data/screening/batch_ids.csv")
final <- merge(final, batches, by = "record_id")

# Agreement with the second independent screening of the random sample
kappa_files <- sprintf("data/screening/kappa_sample/kappa_%d_reviewer2.tsv", 1:5)
second <- read_tsv(kappa_files)[!(record_id %in% late_dup$record_id)]
kappa <- function(a, b) {
  lev <- union(unique(a), unique(b)); tab <- table(factor(a, lev), factor(b, lev))
  po <- sum(diag(tab)) / sum(tab); pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  c(n = sum(tab), agreement = po, kappa = (po - pe) / (1 - pe))
}
m  <- merge(final[, .(record_id, d1 = decision)], second[, .(record_id, d2 = decision)], by = "record_id")
m0 <- merge(first_pass[, .(record_id, d0 = decision)], m, by = "record_id")
pass1 <- m$d1 != "EXCLUDE"; pass2 <- m$d2 != "EXCLUDE"
cat("\nAgreement sample:", nrow(m), "records\n"); print(table(final = m$d1, reviewer2 = m$d2))
k3 <- kappa(m$d1, m$d2); kb <- kappa(pass1, pass2); kb0 <- kappa(m0$d0 != "EXCLUDE", m0$d2 != "EXCLUDE")
cat("three-level: agreement", round(k3[2], 3), "kappa", round(k3[3], 3), "\n")
cat("binary, final decision: agreement", round(kb[2], 3), "kappa", round(kb[3], 3), "\n")
cat("binary, before re-screening: agreement", round(kb0[2], 3), "kappa", round(kb0[3], 3), "\n")
fwrite(m[pass1 != pass2], "data/results/screening_disagreements.csv")

# Final counts
excluded <- final[decision == "EXCLUDE"]; included <- final[decision == "INCLUDE"]
cats <- unlist(strsplit(included$code, "\\+"))
cat("\nFinal decision:\n"); print(table(final$decision))
cat("Exclusions by reason:\n"); print(table(excluded$code))
setorder(final, record_id)
fwrite(final[, .(record_id, batch, stage, decision, code, hardware_mentioned = hardware, note)],
       "data/results/screening_decisions.csv")
counts <- list(
  identified_scopus = ident$identified_scopus, identified_wos = ident$identified_wos,
  identified_total = ident$identified_total,
  duplicates_removed = ident$duplicates_total + nrow(late_dup),
  records_screened = nrow(final),
  rescreened = nrow(rescreen), rescreened_passing = sum(rescreen$decision != "EXCLUDE"),
  agreement_sample = nrow(m),
  kappa_binary_final = unname(round(kb[3], 3)), agreement_binary_final = unname(round(kb[2], 3)),
  kappa_binary_first_pass = unname(round(kb0[3], 3)),
  kappa_three_level = unname(round(k3[3], 3)), agreement_three_level = unname(round(k3[2], 3)),
  excluded = nrow(excluded), excluded_by_reason = as.list(table(excluded$code)),
  passing = sum(final$decision != "EXCLUDE"),
  include = nrow(included), unsure = sum(final$decision == "UNSURE"),
  include_categories = as.list(table(cats))
)
write_json(counts, "data/results/counts_screening.json", pretty = TRUE, auto_unbox = TRUE)
