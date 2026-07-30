# =============================================================================
# R/04_municipal_indicators.R
#
# STEP 4 - Territorial linkage of municipal indicators.
#
# Input : data/external/municipal_indicators.csv   (see data/README.md)
#         data/processed/discharges.parquet        (step 3)
# Output: data/processed/municipal_indicators.parquet
#         results/tables/comuna_match_audit.csv
#         results/tables/municipal_indicators_wide.csv
#
# The manuscript links municipal indicators derived from the CASEN 2022 health
# module and the 2024 Population and Housing Census to each discharge through
# the comuna of residence, resolving coding discrepancies with string
# standardisation and Levenshtein distance.
#
# The scripts that were handed over do not contain that extraction, so this step
# is written as a linkage and validation stage: it consumes an already tabulated
# tidy file of municipal proportions (whatever tool produced them) and does the
# part that has to be reproducible and auditable, namely the name matching.
#
# Matching strategy
#   1. Normalise both sides with the same key: hexadecimal escapes repaired,
#      accents dropped, upper case, punctuation collapsed to single spaces.
#   2. Exact match on the key.
#   3. For the remainder, nearest neighbour by Levenshtein distance, accepted
#      only when the distance is at or below linkage$max_levenshtein and the
#      nearest neighbour is unique at that distance.
#   4. Everything that is still unmatched is written to the audit file. Nothing
#      is matched silently: the audit file lists match_type for every comuna.
#
# The indicators are descriptive: they feed Table 2 and Supplementary Tables
# S2-S4. They are not added to the model matrix, which is what the published run
# did (the only territorial features in the models are comuna dummies).
# =============================================================================

source("R/utils.R")

cfg <- load_config()
log_start(cfg, "04_municipal_indicators")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

discharges_path <- cfg_path(cfg, "processed", "discharges.parquet")
if (!file.exists(discharges_path)) {
  fail("Missing step 3 output: ", discharges_path,
       "\nRun: Rscript R/03_define_outcomes.R")
}

indicator_path <- cfg_path(cfg, "external", cfg$linkage$indicator_file)
if (!file.exists(indicator_path)) {
  fail(
    "Missing external indicator file: ", indicator_path, "\n",
    "Expected a tidy CSV with the columns comuna, indicator, value_pct, source.\n",
    "See data/README.md for the required format and the indicator list."
  )
}


# -----------------------------------------------------------------------------
# 4.1  Read and validate the external file
# -----------------------------------------------------------------------------

ind <- read_csv_utf8(indicator_path)

required <- c("comuna", "indicator", "value_pct")
missing_cols <- setdiff(required, names(ind))
if (length(missing_cols) > 0L) {
  fail("municipal_indicators.csv is missing the columns: ",
       paste(missing_cols, collapse = ", "))
}
if (!"source" %in% names(ind)) ind$source <- NA_character_

ind$value_pct <- suppressWarnings(as.numeric(ind$value_pct))
ind$indicator <- trimws(as.character(ind$indicator))
ind$comuna <- as.character(ind$comuna)

log_info("External file: ", nrow(ind), " rows, ",
         length(unique(ind$comuna)), " comunas, ",
         length(unique(ind$indicator)), " indicators")

# Validation 1: proportions must be expressed as percentages.
bad_range <- which(!is.na(ind$value_pct) & (ind$value_pct < 0 | ind$value_pct > 100))
if (length(bad_range) > 0L) {
  log_warn(length(bad_range), " values outside [0, 100]. ",
           "Indicators must be percentages, not fractions. First offending rows: ",
           paste(utils::head(bad_range, 5), collapse = ", "))
}

# Validation 2: one value per comuna and indicator.
ind$key <- normalise_place(ind$comuna)
dupes <- ind[duplicated(ind[, c("key", "indicator")]), c("comuna", "indicator")]
if (nrow(dupes) > 0L) {
  examples <- utils::head(paste(dupes$comuna, dupes$indicator, sep = " / "), 5)
  fail("Duplicated (comuna, indicator) pairs in the external file, for example: ",
       paste(examples, collapse = "; "))
}

# Validation 3: missing values are reported, never imputed.
n_na <- sum(is.na(ind$value_pct))
if (n_na > 0L) log_warn(n_na, " indicator values are missing and stay missing")


# -----------------------------------------------------------------------------
# 4.2  Comunas present in the discharge data
# -----------------------------------------------------------------------------

comunas <- db_get(con, sprintf("
  SELECT
    COMUNA_KEY,
    ANY_VALUE(COMUNA)             AS comuna_raw_example,
    COUNT(*)                      AS n_discharges,
    SUM(D1_ACV_GENERAL)           AS n_stroke_principal
  FROM read_parquet('%s')
  WHERE COMUNA_KEY IS NOT NULL AND COMUNA_KEY <> ''
  GROUP BY COMUNA_KEY
  ORDER BY n_discharges DESC
", sql_path(discharges_path)))

log_info("Comunas in the discharge data: ", nrow(comunas))


# -----------------------------------------------------------------------------
# 4.3  Match
# -----------------------------------------------------------------------------

indicator_keys <- sort(unique(ind$key))

#' Nearest indicator key by Levenshtein distance.
#'
#' Returns NA when the best distance exceeds the tolerance or when two different
#' keys tie at the best distance, because an ambiguous match is worse than none.
nearest_key <- function(key, candidates, max_dist) {
  if (max_dist <= 0L || length(candidates) == 0L) return(c(NA_character_, NA_character_))
  d <- as.integer(utils::adist(key, candidates))
  best <- min(d)
  if (best > max_dist) return(c(NA_character_, NA_character_))
  hits <- candidates[d == best]
  if (length(hits) != 1L) return(c(NA_character_, paste0("ambiguous(", best, ")")))
  c(hits, paste0("levenshtein(", best, ")"))
}

max_dist <- as.integer(cfg$linkage$max_levenshtein)
comunas$matched_key <- NA_character_
comunas$match_type <- NA_character_

exact <- comunas$COMUNA_KEY %in% indicator_keys
comunas$matched_key[exact] <- comunas$COMUNA_KEY[exact]
comunas$match_type[exact] <- "exact"

for (i in which(!exact)) {
  res <- nearest_key(comunas$COMUNA_KEY[i], indicator_keys, max_dist)
  comunas$matched_key[i] <- res[1]
  comunas$match_type[i] <- if (is.na(res[2])) "unmatched" else res[2]
}
comunas$match_type[is.na(comunas$match_type)] <- "unmatched"

n_exact <- sum(comunas$match_type == "exact")
n_fuzzy <- sum(grepl("^levenshtein", comunas$match_type))
n_unmatched <- sum(is.na(comunas$matched_key))

log_info("Matching: ", n_exact, " exact, ", n_fuzzy, " by Levenshtein distance, ",
         n_unmatched, " unmatched")

# Unmatched comunas weighted by how many discharges they carry: a large
# unmatched comuna matters much more than a small one.
if (n_unmatched > 0L) {
  lost <- comunas[is.na(comunas$matched_key), ]
  lost <- lost[order(-lost$n_discharges), ]
  share <- 100 * sum(lost$n_discharges) / sum(comunas$n_discharges)
  log_warn(n_unmatched, " comunas without indicators, covering ",
           round(share, 2), "% of discharges. Largest: ",
           paste(utils::head(lost$COMUNA_KEY, 5), collapse = ", "))
  if (isTRUE(cfg$linkage$fail_on_unmatched)) {
    fail("linkage$fail_on_unmatched is TRUE and ", n_unmatched,
         " comunas could not be matched. See results/tables/comuna_match_audit.csv")
  }
}

write_csv_utf8(comunas, cfg_path(cfg, "tables", "comuna_match_audit.csv"))


# -----------------------------------------------------------------------------
# 4.4  Linked output
# -----------------------------------------------------------------------------

linked <- merge(
  comunas[, c("COMUNA_KEY", "comuna_raw_example", "n_discharges",
              "n_stroke_principal", "matched_key", "match_type")],
  ind[, c("key", "indicator", "value_pct", "source")],
  by.x = "matched_key", by.y = "key",
  all.x = FALSE
)
linked <- linked[order(linked$COMUNA_KEY, linked$indicator), ]

require_pkgs("arrow", attach = FALSE)
out_path <- cfg_path(cfg, "processed", "municipal_indicators.parquet")
arrow::write_parquet(linked, out_path, compression = "zstd")
log_info("Wrote ", basename(out_path), ": ", nrow(linked), " comuna-indicator rows")

# Wide version, convenient for inspection and for the manuscript tables.
wide <- stats::reshape(
  linked[, c("COMUNA_KEY", "indicator", "value_pct")],
  idvar = "COMUNA_KEY", timevar = "indicator", direction = "wide"
)
names(wide) <- sub("^value_pct\\.", "", names(wide))
write_csv_utf8(wide, cfg_path(cfg, "tables", "municipal_indicators_wide.csv"))

save_run_metadata(cfg, "04_municipal_indicators", "arrow")
log_end()
