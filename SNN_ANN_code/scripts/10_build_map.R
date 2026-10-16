# =====================================================================
# 10_build_map.R
# Consolidates eligibility confirmation and charting into the final
# evidence map:
#  - takes the primary charting of the 2,109 records assessed on the
#    complete abstract;
#  - applies the adjudication of the eligibility disagreements of the
#    verification sample (third reviewer, data/charting/eligibility_adjudication.csv);
#    when the adjudication sides with the second charter and the record
#    is eligible, the second charting is used in full;
#  - applies the publication-year audit (data/charting/year_audit.csv):
#    records whose bibliographic year lies outside 2020-2026 receive the
#    code E0 and leave the mapping;
#  - joins the bibliographic metadata and writes the final map and the
#    counts that feed the PRISMA flow diagram and the mapping tables.
#
# Inputs : data/results/charting_primary.csv, data/charting/verification/*.tsv,
#          data/charting/eligibility_adjudication.csv, data/charting/year_audit.csv,
#          data/records/records.csv
# Outputs: data/results/mapping.csv, data/results/counts_mapping.json
# Usage: Rscript scripts/10_build_map.R
# =====================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
FIELDS <- c("record_id", "eligible", "reason", "categories", "paradigm", "architecture", "task",
            "platform_snn", "platform_ann", "evidence", "metrics", "comparison", "sparsity_method",
            "lth_variant", "granularity", "cost_in_objective", "hardware_measured", "note")
read_charting <- function(files) rbindlist(lapply(files, function(f) {
  d <- fread(f, sep = "\t", header = FALSE, quote = "", colClasses = "character", na.strings = "")
  setnames(d, FIELDS); d }))

primary <- fread("data/results/charting_primary.csv", colClasses = "character", na.strings = "")
second  <- read_charting(sort(list.files("data/charting/verification", pattern = "^verification_[0-9]_[a-c]\\.tsv$", full.names = TRUE)))
adjud   <- fread("data/charting/eligibility_adjudication.csv", colClasses = "character", na.strings = "")
audit   <- fread("data/charting/year_audit.csv", colClasses = "character", na.strings = "")

final <- copy(primary)
for (i in seq_len(nrow(adjud))) {
  a <- adjud[i]
  if (a$source == "second") {
    row <- second[record_id == a$record_id]
    stopifnot(nrow(row) == 1, row$eligible == "Y")
    cols <- FIELDS
    final[record_id == a$record_id, (cols) := row[, cols, with = FALSE]]
  } else if (a$source == "exclude") {
    final[record_id == a$record_id, `:=`(eligible = "N", reason = a$reason)]
    final[record_id == a$record_id, (FIELDS[4:17]) := "-"]
  }
}
final[, adjudicated := record_id %in% adjud$record_id]

# Publication-year audit (code E0): records outside the 2020-2026 window
records <- fread("data/records/records.csv", encoding = "UTF-8")
out_of_window <- records[year < 2020 | year > 2026, record_id]
audit_ids <- union(out_of_window, audit$record_id)
final[record_id %in% audit_ids & eligible == "Y", `:=`(eligible = "N", reason = "E0")]
final[record_id %in% audit_ids & reason == "E0", (FIELDS[4:17]) := "-"]
final[, year_audit := record_id %in% audit_ids]
stopifnot(nrow(final) == 2109, !anyDuplicated(final$record_id))

meta <- records[, .(record_id, source, year, title, authors, venue, document_type, doi, citations, open_access)]
map <- merge(final, meta, by = "record_id")
setorder(map, record_id)
fwrite(map, "data/results/mapping.csv")

excluded <- map[eligible == "N"]; included <- map[eligible == "Y"]
cats <- unlist(strsplit(included$categories, "\\+"))
counts <- list(
  assessed_on_full_abstract = nrow(map),
  excluded = nrow(excluded),
  excluded_by_reason = as.list(table(excluded$reason)),
  included_in_mapping = nrow(included),
  categories = as.list(table(cats)),
  hardware_measured_Y = sum(included$hardware_measured == "Y"),
  hardware_measured_U = sum(included$hardware_measured == "U"),
  fulltext_candidates = sum(included$hardware_measured %in% c("Y", "U") | grepl("C4", included$categories))
)
write_json(counts, "data/results/counts_mapping.json", pretty = TRUE, auto_unbox = TRUE)
cat(toJSON(counts, pretty = TRUE, auto_unbox = TRUE), "\n")
