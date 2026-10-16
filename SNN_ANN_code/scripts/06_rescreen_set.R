# =====================================================================
# 06_rescreen_set.R
# Defines, in a reproducible way, the set of records re-screened with
# the complete abstract: records excluded in the first pass whose
# abstract exceeded the 1,400 characters shown and whose hidden part
# contains at least one term related to ANN baselines, efficiency
# metrics, hardware platforms or sparsity. The first round of
# re-screening (rescreen_a) covered a subset chosen with a preliminary
# version of the rule; this script fixes the final rule, lists the
# records it covers and the ones left for the second round (rescreen_b).
# It also detects the late duplicates (titles identical once spaces and
# punctuation are removed, missed by the first deduplication because
# some WoS titles lack spaces between words) and leaves them out.
#
# Inputs : data/processed/corpus.csv, data/screening/title_abstract/*.tsv,
#          data/screening/rescreen/rescreen_a_ids.csv
# Outputs: data/records/late_duplicates.csv
#          data/screening/rescreen/rescreen_rule_ids.csv  (final rule)
#          data/screening/rescreen/rescreen_b_ids.csv     (second round)
#          data/processed/rescreen_b_NN.txt               (batches, full abstract)
# Usage: Rscript scripts/06_rescreen_set.R
# =====================================================================
suppressPackageStartupMessages({ library(data.table); library(stringi) })
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
corpus <- fread("data/processed/corpus.csv", encoding = "UTF-8")

# Late duplicates: identical titles once spaces and punctuation are removed;
# the Scopus record (or the lower identifier) is kept
corpus[, tight_title := gsub("[^a-z0-9]", "", tolower(stri_trans_general(title, "Latin-ASCII")))]
corpus[, priority := fifelse(source == "Scopus", 0L, 1L)]
setorder(corpus, tight_title, priority, record_id)
corpus[, late_duplicate := duplicated(tight_title) & tight_title != ""]
late_dup <- corpus[late_duplicate == TRUE, .(record_id, source, title)]
fwrite(late_dup, "data/records/late_duplicates.csv")
setorder(corpus, record_id)
cat("late duplicates:", nrow(late_dup), "\n")

first_pass <- rbindlist(lapply(sprintf("data/screening/title_abstract/batch_%03d.tsv", 1:64), function(f)
  fread(f, sep = "\t", header = FALSE, quote = "", fill = TRUE,
        col.names = c("record_id", "decision", "code", "hardware", "note"))))

TERMS <- paste("\\bann", "\\banns", "artificial neural", "deep neural", "\\bdnn", "\\bcnn",
               "non-spiking", "counterpart", "compared", "energy", "power", "latency",
               "efficien", "prun", "spars", "lottery", "ticket", "\\bsop", "\\bmac", "flop",
               "loihi", "truenorth", "spinnaker", "fpga", "gpu", sep = "|")
SHOWN <- 1400L

x <- merge(first_pass[decision == "EXCLUDE", .(record_id)],
           corpus[, .(record_id, abstract)], by = "record_id")
x <- x[!(record_id %in% late_dup$record_id)]
x[, len := nchar(abstract)]
x[, hidden := fifelse(len > SHOWN, tolower(substr(abstract, SHOWN + 1L, len)), "")]
rule_ids <- x[len > SHOWN & grepl(TERMS, hidden), sort(record_id)]
round_a  <- fread("data/screening/rescreen/rescreen_a_ids.csv")[[1]]
round_b  <- setdiff(rule_ids, round_a)
cat("excluded records with a truncated abstract:", x[len > SHOWN, .N], "\n")
cat("re-screening set (final rule):", length(rule_ids), "\n")
cat("covered by the first round:", length(intersect(rule_ids, round_a)), "\n")
cat("second round:", length(round_b), "\n")
cat("first-round records outside the final rule (first-pass decision kept):",
    length(setdiff(round_a, rule_ids)), "\n")
fwrite(data.table(record_id = rule_ids), "data/screening/rescreen/rescreen_rule_ids.csv")
fwrite(data.table(record_id = round_b), "data/screening/rescreen/rescreen_b_ids.csv")

d <- corpus[record_id %in% round_b]; setorder(d, record_id)
kw  <- substr(gsub("\\s+", " ", ifelse(is.na(d$author_keywords), "", d$author_keywords)), 1, 200)
abs <- gsub("\\s+", " ", ifelse(is.na(d$abstract), "", d$abstract))
txt <- paste0("[", d$record_id, "] (", d$year, "; ", d$document_type, ") ", d$title,
              "\nKW: ", kw, "\nABS: ", abs, "\n")
group <- ceiling(seq_along(txt) / 100)
for (g in unique(group)) writeLines(txt[group == g], sprintf("data/processed/rescreen_b_%02d.txt", g))
cat(length(txt), "records in", max(group), "batch files\n")
