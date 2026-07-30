# =============================================================================
# R/05_split_and_screen.R
#
# STEP 5 - Development / reserved partition and chi-square screening.
#
# Input : data/processed/discharges.parquet   (step 3)
#         data/interim/code_long.parquet      (step 3)
# Output: data/processed/split_assignment.parquet
#         results/tables/imputation_medians.csv
#         results/tables/screening_all_codes.csv
#         results/tables/selected_features.csv
#
# Two things happen here, in this order, and the order matters:
#
#   1. The records are split 70 / 30, stratified by stroke presence. The 30 %
#      reserved subset takes no part in screening or in selection.
#   2. Every candidate code is screened against stroke presence, using the
#      development subset only. Codes above the significance threshold become
#      the candidate feature set for step 6.
#
# Why the split is done with a hash instead of random()
#   ORDER BY random() is not reproducible: DuckDB evaluates it across several
#   threads, so the same seed can produce a different partition on a machine
#   with a different thread count. Ranking records by HASH(RECORD_ID, seed) is
#   deterministic everywhere, and still a random partition with respect to the
#   data.
#
# Why the screening is one aggregation instead of a loop
#   The original script ran one SQL query per candidate code and per outcome,
#   which is roughly twenty thousand full scans of a 5.8-million-row table, and
#   then called chisq.test() on each 2x2 table. Unpivoting the codes once
#   (step 3) reduces the whole screening to a single grouped join, and the
#   chi-square statistic for a 2x2 table is a closed-form expression that is
#   computed here in vectorised form. Same numbers, minutes instead of days.
#
# Why log10(p) instead of p
#   The threshold used by the study is 5e-100. Squared statistics of this size
#   produce p-values far below the smallest positive double, so p and the
#   Bonferroni-adjusted p both underflow to exactly 0 and become impossible to
#   rank. Everything is therefore computed and compared on the log10 scale.
# =============================================================================

source("R/utils.R")

cfg <- load_config()
log_start(cfg, "05_split_and_screen")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

discharges_path <- cfg_path(cfg, "processed", "discharges.parquet")
code_long_path <- cfg_path(cfg, "interim", "code_long.parquet")
for (p in c(discharges_path, code_long_path)) {
  if (!file.exists(p)) fail("Missing step 3 output: ", p,
                            "\nRun: Rscript R/03_define_outcomes.R")
}

db_exec(con, sprintf("CREATE OR REPLACE VIEW discharges AS SELECT * FROM read_parquet('%s')",
                     sql_path(discharges_path)))
db_exec(con, sprintf("CREATE OR REPLACE VIEW code_long AS SELECT * FROM read_parquet('%s')",
                     sql_path(code_long_path)))


# -----------------------------------------------------------------------------
# 5.1  Stratified 70 / 30 partition
# -----------------------------------------------------------------------------

strat_cols <- unlist(cfg$split$stratify_by)
frac <- as.numeric(cfg$split$development_fraction)
seed <- as.integer(cfg$split$seed)

stratum_sql <- paste(sprintf("CAST(COALESCE(%s, -1) AS VARCHAR)", sql_id(strat_cols)),
                     collapse = " || '-' || ")

split_path <- cfg_path(cfg, "processed", "split_assignment.parquet")

log_info("Partitioning ", round(100 * frac), "% / ", round(100 * (1 - frac)),
         "% stratified by ", paste(strat_cols, collapse = " x "), " (seed ", seed, ")")

db_exec(con, sprintf("
COPY (
  WITH keyed AS (
    SELECT
      RECORD_ID,
      %s AS STRATUM,
      HASH(CAST(RECORD_ID AS VARCHAR) || '_' || CAST(%d AS VARCHAR)) AS H
    FROM discharges
  ),
  ranked AS (
    SELECT
      RECORD_ID,
      STRATUM,
      ROW_NUMBER() OVER (PARTITION BY STRATUM ORDER BY H, RECORD_ID) AS RN,
      COUNT(*)     OVER (PARTITION BY STRATUM)                       AS N_STRATUM
    FROM keyed
  )
  SELECT
    RECORD_ID,
    STRATUM,
    CASE WHEN RN <= CAST(FLOOR(N_STRATUM * %.10f) AS BIGINT)
         THEN 'development' ELSE 'reserved' END AS SPLIT
  FROM ranked
)
TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD);
", stratum_sql, seed, frac, sql_path(split_path)))

db_exec(con, sprintf("CREATE OR REPLACE VIEW split_assignment AS SELECT * FROM read_parquet('%s')",
                     sql_path(split_path)))

split_summary <- db_get(con, "
  SELECT STRATUM, SPLIT, COUNT(*) AS n
  FROM split_assignment
  GROUP BY STRATUM, SPLIT
  ORDER BY STRATUM, SPLIT
")
write_csv_utf8(split_summary, cfg_path(cfg, "tables", "split_summary.csv"))

n_dev <- sum(split_summary$n[split_summary$SPLIT == "development"])
n_res <- sum(split_summary$n[split_summary$SPLIT == "reserved"])
log_info("  development: ", format(n_dev, big.mark = " "),
         " | reserved: ", format(n_res, big.mark = " "))

record_flow_append(cfg, "05_development_subset", n_dev, "used for screening and selection")
record_flow_append(cfg, "05_reserved_subset", n_res, "held out, untouched")

# Development view, reused below and by step 6 and 7.
db_exec(con, "
  CREATE OR REPLACE VIEW dev AS
  SELECT d.*
  FROM discharges AS d
  JOIN split_assignment AS s ON s.RECORD_ID = d.RECORD_ID
  WHERE s.SPLIT = 'development'
")


# -----------------------------------------------------------------------------
# 5.2  Imputation medians, computed once on the development subset
#
# The original imputed the median of EDAD and DURACION_HOSPITAL inside every one
# of the 500 resamples, which makes the imputed value depend on the resample and
# lets information from the resampled controls leak into the imputation. One
# median per variable, taken from the development subset, is both simpler and
# cleaner. Step 7 reads these values.
# -----------------------------------------------------------------------------

medians <- db_get(con, "
  SELECT
    MEDIAN(EDAD)              AS EDAD,
    MEDIAN(DURACION_HOSPITAL) AS DURACION_HOSPITAL
  FROM dev
")
medians_long <- data.frame(
  variable = names(medians),
  median_development = as.numeric(unlist(medians[1, ])),
  stringsAsFactors = FALSE
)
write_csv_utf8(medians_long, cfg_path(cfg, "tables", "imputation_medians.csv"))
log_info("Imputation medians (development subset): ",
         paste(sprintf("%s = %s", medians_long$variable,
                       round(medians_long$median_development, 2)), collapse = ", "))


# -----------------------------------------------------------------------------
# 5.3  Contingency counts for every candidate code
# -----------------------------------------------------------------------------

screen_outcomes <- unlist(cfg$screening$outcomes)
guard_pattern <- outcome_guard_pattern(cfg)
exclude_guard <- isTRUE(cfg$case_definition$exclude_outcome_codes_from_predictors)

log_info("Screening against: ", paste(screen_outcomes, collapse = ", "))
if (exclude_guard) {
  log_info("Outcome-defining codes excluded from the candidate set: ", guard_pattern)
} else {
  log_warn("exclude_outcome_codes_from_predictors is FALSE: codes that define ",
           "the outcome remain candidate predictors. This reproduces the ",
           "published run but makes the subtype contrasts partly circular.")
}

#' Grouped counts for one outcome: how often each code co-occurs with it.
#'
#' n_code is the number of development records carrying the code with that
#' provenance; n11 is how many of those are cases. Everything else in the 2x2
#' table follows from the marginals, so a single aggregation is enough.
screen_counts <- function(outcome) {
  db_get(con, sprintf("
    WITH dev_outcome AS (
      SELECT RECORD_ID, CAST(%s AS INTEGER) AS Y
      FROM dev
      WHERE %s IS NOT NULL
    )
    SELECT
      cl.ORIGIN,
      cl.CODE,
      COUNT(*)      AS n_code,
      SUM(o.Y)      AS n11
    FROM code_long AS cl
    JOIN dev_outcome AS o ON o.RECORD_ID = cl.RECORD_ID
    GROUP BY cl.ORIGIN, cl.CODE
  ", sql_id(outcome), sql_id(outcome)))
}

#' Marginals of one outcome inside the development subset.
screen_marginals <- function(outcome) {
  db_get(con, sprintf("
    SELECT COUNT(*) AS n_total, SUM(CAST(%s AS INTEGER)) AS n_outcome_1
    FROM dev WHERE %s IS NOT NULL
  ", sql_id(outcome), sql_id(outcome)))
}

#' Chi-square statistic and log10 p-value for a vectorised set of 2x2 tables.
#'
#' Pearson statistic without continuity correction, matching chisq.test(correct
#' = FALSE). Tables with any expected count below min_expected are flagged
#' instead of tested, because the chi-square approximation does not hold there.
chi2_2x2 <- function(a, b, c, d, min_expected = 5) {
  # Coerced to double before anything else: with integer inputs the product of
  # the four marginals overflows well within the range of table sizes this study
  # produces, and R would silently return NA.
  a <- as.numeric(a); b <- as.numeric(b)
  c <- as.numeric(c); d <- as.numeric(d)

  n <- a + b + c + d
  r1 <- a + b; r2 <- c + d
  c1 <- a + c; c2 <- b + d

  e11 <- r1 * c1 / n; e12 <- r1 * c2 / n
  e21 <- r2 * c1 / n; e22 <- r2 * c2 / n
  min_exp <- pmin(e11, e12, e21, e22)

  degenerate <- (r1 == 0 | r2 == 0 | c1 == 0 | c2 == 0)
  stat <- n * (a * d - b * c)^2 / (r1 * r2 * c1 * c2)
  stat[degenerate] <- NA_real_

  # log10 of the upper tail of a chi-square with 1 degree of freedom, kept on the
  # log scale so that values far below 1e-308 remain comparable.
  log10_p <- stats::pchisq(stat, df = 1, lower.tail = FALSE, log.p = TRUE) / log(10)

  data.frame(
    chi2 = stat,
    log10_p = log10_p,
    min_expected = min_exp,
    expected_ok = !is.na(min_exp) & min_exp >= min_expected & !degenerate,
    stringsAsFactors = FALSE
  )
}

min_expected <- as.numeric(cfg$screening$min_expected_count)
all_screen <- list()

for (outcome in screen_outcomes) {
  marg <- screen_marginals(outcome)
  cnt <- screen_counts(outcome)

  log_info("  ", outcome, ": ", nrow(cnt), " candidate (code, provenance) pairs, ",
           format(marg$n_outcome_1, big.mark = " "), " cases in ",
           format(marg$n_total, big.mark = " "), " development records")

  a <- as.numeric(cnt$n11)                              # code present, case
  b <- as.numeric(cnt$n_code) - a                       # code present, control
  cc <- as.numeric(marg$n_outcome_1) - a                # code absent, case
  d <- as.numeric(marg$n_total) - a - b - cc            # code absent, control

  stats_df <- chi2_2x2(a, b, cc, d, min_expected)

  # Bonferroni over the number of pairs tested for this outcome, on the log10
  # scale: log10(p * m) = log10(p) + log10(m), capped at 0 (p_adj <= 1).
  m <- nrow(cnt)
  log10_p_adj <- pmin(stats_df$log10_p + log10(m), 0)

  all_screen[[outcome]] <- data.frame(
    outcome = outcome,
    origin = cnt$ORIGIN,
    code = cnt$CODE,
    n_records_with_code = as.numeric(cnt$n_code),
    n_cases_with_code = a,
    chi2 = stats_df$chi2,
    log10_p = stats_df$log10_p,
    log10_p_adj = log10_p_adj,
    min_expected = stats_df$min_expected,
    expected_ok = stats_df$expected_ok,
    n_tests = m,
    stringsAsFactors = FALSE
  )
}

screen <- do.call(rbind, all_screen)
rownames(screen) <- NULL


# -----------------------------------------------------------------------------
# 5.4  Filtering and feature selection
# -----------------------------------------------------------------------------

screen$is_outcome_code <- grepl(guard_pattern, screen$code)

threshold <- as.numeric(cfg$screening$p_threshold)
log10_threshold <- log10(threshold)
log_info("Significance threshold: p_adj < ", format(threshold, scientific = TRUE),
         "  (log10 p_adj < ", round(log10_threshold, 3), ")")

screen$retained <- screen$expected_ok &
  !is.na(screen$log10_p_adj) &
  screen$log10_p_adj < log10_threshold &
  !(exclude_guard & screen$is_outcome_code)

write_csv_utf8(screen, cfg_path(cfg, "tables", "screening_all_codes.csv"))

log_info("  candidates tested       : ", nrow(screen))
log_info("  discarded, expected < ", min_expected, "  : ", sum(!screen$expected_ok))
log_info("  discarded, outcome code : ",
         if (exclude_guard) sum(screen$is_outcome_code) else 0L)
log_info("  above threshold         : ", sum(screen$retained))

# One row per code: keep the provenance and the outcome that gave the strongest
# association. This is what turns the screening table into a feature list, and
# it guarantees that no code produces two identical indicator columns.
retained <- screen[screen$retained, ]
retained <- retained[order(retained$code, retained$log10_p_adj), ]
selected <- retained[!duplicated(retained$code), ]
selected <- selected[order(selected$log10_p_adj), ]

selected$feature <- feature_name(selected$code, selected$origin)

# The three derived variables are always part of the model matrix, exactly as in
# the published run. They are reported here for completeness.
derived <- data.frame(
  outcome = NA_character_,
  origin = "DERIVED",
  code = unlist(cfg$model_matrix$numeric_features),
  n_records_with_code = NA_real_,
  n_cases_with_code = NA_real_,
  chi2 = NA_real_,
  log10_p = NA_real_,
  log10_p_adj = NA_real_,
  min_expected = NA_real_,
  expected_ok = TRUE,
  n_tests = NA_real_,
  is_outcome_code = FALSE,
  retained = TRUE,
  stringsAsFactors = FALSE
)
derived$feature <- derived$code

selected_out <- rbind(selected, derived)
write_csv_utf8(selected_out, cfg_path(cfg, "tables", "selected_features.csv"))

log_info("Selected features: ", nrow(selected), " codes + ", nrow(derived),
         " derived variables")
log_info("  by provenance: ",
         paste(sprintf("%s = %d", names(table(selected$origin)),
                       as.integer(table(selected$origin))), collapse = ", "))

save_run_metadata(cfg, "05_split_and_screen")
log_end()
