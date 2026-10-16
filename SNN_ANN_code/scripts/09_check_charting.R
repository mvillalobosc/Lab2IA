# =====================================================================
# 09_check_charting.R
# (1) Validates the charting files (18 fields, the records of each
#     batch in the same order, vocabulary allowed for every item).
# (2) Compares the primary charting with the second independent
#     charting of the verification sample: agreement and Cohen's kappa
#     per item. For multi-valued items ("+" separated) the kappa is the
#     frequency-weighted mean of the binary kappa of each value.
#
# Inputs : data/charting/charting_ids.csv, data/charting/primary/charting_NN_x.tsv,
#          data/charting/verification_ids.csv, data/charting/verification/verification_N_x.tsv
# Outputs: data/results/charting_primary.csv
#          data/results/field_agreement.csv
#          data/results/eligibility_disagreements.csv
# Usage: Rscript scripts/09_check_charting.R
# =====================================================================
suppressPackageStartupMessages(library(data.table))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
FIELDS <- c("record_id", "eligible", "reason", "categories", "paradigm", "architecture", "task",
            "platform_snn", "platform_ann", "evidence", "metrics", "comparison", "sparsity_method",
            "lth_variant", "granularity", "cost_in_objective", "hardware_measured", "note")
VOCAB <- list(
  eligible = c("Y", "N"), reason = c("-", paste0("E", 1:7)),
  paradigm = c("ANN", "SNN", "ANN+SNN", "HYBRID", "-"),
  architecture = c("MLP", "CNN", "RNN", "TRANSFORMER", "GNN", "OTHER", "NS", "-"),
  task = c("STATIC_IMG", "DET", "EVENT", "AUDIO", "BIOSIG", "CONTROL", "NLP", "TS", "OTHER", "NS", "-"),
  platform_snn = c("LOIHI", "LOIHI2", "TRUENORTH", "SPINNAKER", "SPINNAKER2", "BRAINSCALES", "TIANJIC",
                   "AKIDA", "DYNAP", "SPECK", "XYLO", "DARWIN", "OTHER_NEURO", "FPGA", "ASIC", "GPU",
                   "CPU", "MCU", "MEMRISTOR", "SIM", "NS", "NA", "-"),
  platform_ann = c("GPU", "EDGE_GPU", "CPU", "MCU", "FPGA", "ASIC", "TPU", "NPU", "MEMRISTOR", "SIM", "NS", "NA", "-"),
  evidence = c("MEASURED", "ESTIMATED", "BOTH", "CLAIM", "NONE", "NS", "-"),
  metrics = c("ENERGY", "POWER", "LATENCY", "THROUGHPUT", "OPS", "EDP", "MEMORY", "SPIKES", "NONE", "NS", "ACC", "-"),
  comparison = c("PAIRED", "DIFFERENT", "LITERATURE", "NS", "NA", "-"),
  sparsity_method = c("MAG", "ACT", "SCORE", "REG", "EVO", "DST", "RANDOM", "THEORY", "OTHER", "NS", "NA", "-"),
  lth_variant = c("WEAK", "STRONG", "BOTH", "OTHER", "NS", "NA", "-"),
  granularity = c("UNSTRUCT", "STRUCT", "TEMPORAL", "MIXED", "NS", "NA", "-"),
  cost_in_objective = c("Y", "N", "NS", "NA", "-"),
  hardware_measured = c("Y", "U", "N", "-"))
MULTI <- c("categories", "architecture", "task", "platform_snn", "platform_ann", "metrics", "sparsity_method")

read_charting <- function(files) rbindlist(lapply(files, function(f) {
  d <- fread(f, sep = "\t", header = FALSE, quote = "", fill = TRUE, colClasses = "character", na.strings = "")
  if (ncol(d) < 18) for (k in (ncol(d) + 1):18) d[[paste0("V", k)]] <- NA_character_
  d <- d[, 1:18]; setnames(d, FIELDS); d }))

batch_ids <- fread("data/charting/charting_ids.csv")
primary <- list(); report <- list()
for (k in sort(unique(batch_ids$batch))) {
  files <- sort(list.files("data/charting/primary", pattern = sprintf("^charting_%02d_[a-d]\\.tsv$", k), full.names = TRUE))
  if (!length(files)) next
  d <- read_charting(files)
  expected <- batch_ids[batch == k, record_id]
  p <- character(0)
  if (nrow(d) != length(expected)) p <- c(p, sprintf("%d rows of %d", nrow(d), length(expected)))
  if (!identical(d$record_id, expected))
    p <- c(p, sprintf("ids or order differ (%d missing, %d foreign)",
                      length(setdiff(expected, d$record_id)), length(setdiff(d$record_id, expected))))
  for (item in names(VOCAB)) {
    vals <- if (item %in% MULTI) unlist(strsplit(d[[item]], "\\+")) else d[[item]]
    bad <- setdiff(unique(vals), VOCAB[[item]])
    if (item == "categories") bad <- setdiff(bad, paste0("C", 1:6))
    if (length(bad)) p <- c(p, sprintf("%s outside vocabulary: %s", item, paste(head(bad, 5), collapse = ",")))
  }
  if (any(d$eligible == "N" & d$reason == "-")) p <- c(p, "N without reason")
  if (any(d$eligible == "Y" & !grepl("^C[1-6](\\+C[1-6])*$", d$categories))) p <- c(p, "Y without valid categories")
  report[[as.character(k)]] <- data.table(batch = k, n = nrow(d), eligible = sum(d$eligible == "Y"),
                                          problems = paste(p, collapse = "; "))
  primary[[as.character(k)]] <- d
}
print(rbindlist(report))
primary <- rbindlist(primary)
dir.create("data/results", showWarnings = FALSE)
fwrite(primary, "data/results/charting_primary.csv")

# ---------------- Agreement with the second charting ----------------
ver_files <- sort(list.files("data/charting/verification", pattern = "^verification_[0-9]_[a-c]\\.tsv$", full.names = TRUE))
second <- read_charting(ver_files)
ver_ids <- fread("data/charting/verification_ids.csv")$record_id
cat("\nverification: rows", nrow(second), "of", length(ver_ids), "; same ids:", setequal(second$record_id, ver_ids), "\n")
m <- merge(primary, second, by = "record_id", suffixes = c("_1", "_2"))

kappa <- function(a, b) {
  lev <- union(unique(a), unique(b)); tab <- table(factor(a, lev), factor(b, lev))
  po <- sum(diag(tab)) / sum(tab); pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  c(agreement = po, kappa = if (pe < 1) (po - pe) / (1 - pe) else NA)
}
kappa_multi <- function(a, b) {
  la <- strsplit(a, "\\+"); lb <- strsplit(b, "\\+")
  vals <- setdiff(unique(c(unlist(la), unlist(lb))), c("-", "NA"))
  r <- rbindlist(lapply(vals, function(v) {
    xa <- sapply(la, function(s) v %in% s); xb <- sapply(lb, function(s) v %in% s)
    k <- kappa(xa, xb); data.table(value = v, n = sum(xa | xb), agreement = k[1], kappa = k[2]) }))
  r <- r[n >= 5]
  c(agreement = weighted.mean(r$agreement, r$n), kappa = weighted.mean(r$kappa, r$n, na.rm = TRUE))
}
rows <- list()
k <- kappa(m$eligible_1, m$eligible_2)
rows[["eligible"]] <- data.table(item = "eligible", n = nrow(m), agreement = k[1], kappa = k[2])
both <- m[eligible_1 == "Y" & eligible_2 == "Y"]
for (item in setdiff(FIELDS, c("record_id", "eligible", "reason", "note"))) {
  a <- both[[paste0(item, "_1")]]; b <- both[[paste0(item, "_2")]]
  kk <- if (item %in% MULTI) kappa_multi(a, b) else kappa(a, b)
  rows[[item]] <- data.table(item = item, n = nrow(both), agreement = kk[1], kappa = kk[2])
}
agreement <- rbindlist(rows); agreement[, `:=`(agreement = round(agreement, 3), kappa = round(kappa, 3))]
print(agreement)
fwrite(agreement, "data/results/field_agreement.csv")
dis <- m[eligible_1 != eligible_2, .(record_id, eligible_1, reason_1, categories_1, eligible_2, reason_2,
                                     categories_2, note_1, note_2)]
cat("\nEligibility disagreements:", nrow(dis), "\n")
fwrite(dis, "data/results/eligibility_disagreements.csv")
