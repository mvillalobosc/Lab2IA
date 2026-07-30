# =============================================================================
# R/02_clean_and_derive.R
#
# STEP 2 - Record-level cleaning, deduplication and derived variables.
#
# Input : data/interim/grd_<year>.parquet   (step 1)
# Output: data/interim/grd_clean.parquet
#         results/tables/record_flow.csv    (appended)
#
# Rules applied, in this order, each one counted in the record-flow audit:
#   1. Empty rows            - every payload column NULL or empty string.
#   2. Inconsistent dates    - discharge date earlier than admission date.
#   3. Exact duplicates      - identical on every payload column; the copy from
#                              the earliest year and lowest row number is kept.
#
# Derived variables:
#   RECORD_ID          deterministic integer key (order: year, row in file).
#   EDAD               completed years at admission.
#   DURACION_HOSPITAL  length of stay in days.
#   SEXO_BINARIO       1 = female, 0 = male, NULL otherwise.
#
# Everything runs inside DuckDB over the parquet files, so R never materialises
# the 5.8-million-row table.
#
# IMPORTANT - fixed bug
#   The original script computed age as DATE_DIFF('year', birth, admission),
#   which counts calendar-year boundaries rather than completed years and
#   therefore overstates age by one year for every patient whose birthday falls
#   after the admission date. Age is the single most prominent feature in the
#   study, so it is computed exactly here.
# =============================================================================

source("R/utils.R")

cfg <- load_config()
log_start(cfg, "02_clean_and_derive")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)


# -----------------------------------------------------------------------------
# View over every yearly parquet
#
# union_by_name = true tolerates columns that appear in some years and not in
# others, filling the gaps with NULL.
# -----------------------------------------------------------------------------

years <- unlist(cfg$ingest$years)
year_files <- cfg_path(cfg, "interim", sprintf("grd_%d.parquet", years))
missing <- year_files[!file.exists(year_files)]
if (length(missing) > 0L) {
  fail("Missing step 1 output:\n  ", paste(missing, collapse = "\n  "),
       "\nRun: Rscript R/01_ingest_grd.R")
}

file_list_sql <- paste0("[", paste(sql_str(sql_path(year_files)), collapse = ", "), "]")

db_exec(con, sprintf("
  CREATE OR REPLACE VIEW grd_all AS
  SELECT * FROM read_parquet(%s, union_by_name = true)
", file_list_sql))

# Identity columns added in step 1. Everything else is payload: the actual
# content of the discharge record, and the basis for the duplicate rule.
id_cols <- c("SOURCE_YEAR", "ROW_IN_FILE")
all_cols <- names(db_get(con, "SELECT * FROM grd_all LIMIT 0"))
payload_cols <- setdiff(all_cols, id_cols)

log_info("Columns: ", length(payload_cols), " payload + ", length(id_cols), " identity")


# -----------------------------------------------------------------------------
# Cleaning predicates, built once and reused
# -----------------------------------------------------------------------------

# A row is empty when every payload column is NULL or an empty string. Casting
# to VARCHAR makes the test type-independent (dates and numerics included).
is_empty_sql <- paste0(
  "(",
  paste(sprintf("COALESCE(CAST(%s AS VARCHAR), '') = ''", sql_id(payload_cols)),
        collapse = " AND "),
  ")"
)

# Discharge strictly before admission. Rows with a missing date on either side
# are kept: they are incomplete, not inconsistent.
bad_dates_sql <- "(FECHAALTA IS NOT NULL AND FECHA_INGRESO IS NOT NULL AND FECHAALTA < FECHA_INGRESO)"


# -----------------------------------------------------------------------------
# Pass 1 - count what each rule removes
# -----------------------------------------------------------------------------

log_info("Counting records affected by each cleaning rule (single pass)")

counts <- db_get(con, sprintf("
  SELECT
    COUNT(*)                                        AS n_total,
    SUM(CASE WHEN %s THEN 1 ELSE 0 END)             AS n_empty,
    SUM(CASE WHEN %s THEN 1 ELSE 0 END)             AS n_bad_dates
  FROM grd_all
", is_empty_sql, bad_dates_sql))

log_info("  ingested            : ", format(counts$n_total, big.mark = " "))
log_info("  empty rows          : ", format(counts$n_empty, big.mark = " "))
log_info("  discharge < admission: ", format(counts$n_bad_dates, big.mark = " "))


# -----------------------------------------------------------------------------
# Pass 2 - filter, deduplicate, derive, write
# -----------------------------------------------------------------------------

filters <- character(0)
if (isTRUE(cfg$cleaning$drop_empty_rows)) {
  filters <- c(filters, sprintf("NOT %s", is_empty_sql))
}
if (isTRUE(cfg$cleaning$drop_discharge_before_admission)) {
  filters <- c(filters, sprintf("NOT %s", bad_dates_sql))
}
where_sql <- if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else ""

# Deduplication keeps the first copy in (SOURCE_YEAR, ROW_IN_FILE) order, which
# makes the choice deterministic instead of dependent on scan order.
dedup_sql <- if (isTRUE(cfg$cleaning$deduplicate)) {
  sprintf("QUALIFY ROW_NUMBER() OVER (PARTITION BY %s ORDER BY SOURCE_YEAR, ROW_IN_FILE) = 1",
          paste(sql_id(payload_cols), collapse = ", "))
} else {
  ""
}

# Exact completed years: the number of calendar-year boundaries crossed, minus
# one when the birthday has not occurred yet in the admission year.
age_sql <- "
  (DATE_DIFF('year', FECHA_NACIMIENTO, FECHA_INGRESO)
   - CASE
       WHEN CAST(STRFTIME(FECHA_INGRESO, '%m%d') AS INTEGER)
          < CAST(STRFTIME(FECHA_NACIMIENTO, '%m%d') AS INTEGER)
       THEN 1 ELSE 0
     END)"

# Plausibility windows. Out-of-range values become NULL: the record stays, the
# value is treated as missing and imputed later from the development subset.
age_lower_bound <- if (isTRUE(cfg$cleaning$treat_age_zero_as_missing)) 1L else 0L

clean_path <- cfg_path(cfg, "interim", "grd_clean.parquet")

sql_write <- sprintf("
COPY (
  WITH filtered AS (
    SELECT * FROM grd_all
    %s
    %s
  ),
  keyed AS (
    SELECT
      CAST(ROW_NUMBER() OVER (ORDER BY SOURCE_YEAR, ROW_IN_FILE) AS INTEGER) AS RECORD_ID,
      *
    FROM filtered
  )
  SELECT
    *,
    -- Age at admission, in completed years, NULL outside [%d, %d].
    CASE
      WHEN FECHA_NACIMIENTO IS NULL OR FECHA_INGRESO IS NULL THEN NULL
      WHEN %s BETWEEN %d AND %d THEN %s
      ELSE NULL
    END AS EDAD,

    -- Length of stay in days, NULL outside [0, %d].
    CASE
      WHEN FECHAALTA IS NULL OR FECHA_INGRESO IS NULL THEN NULL
      WHEN DATE_DIFF('day', FECHA_INGRESO, FECHAALTA) BETWEEN 0 AND %d
        THEN DATE_DIFF('day', FECHA_INGRESO, FECHAALTA)
      ELSE NULL
    END AS DURACION_HOSPITAL,

    -- 1 = female, 0 = male, NULL for anything else.
    CASE
      WHEN UPPER(TRIM(SEXO)) IN ('MUJER', 'M', 'F', '2') THEN 1
      WHEN UPPER(TRIM(SEXO)) IN ('HOMBRE', 'H', '1')     THEN 0
      ELSE NULL
    END AS SEXO_BINARIO
  FROM keyed
)
TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD);
",
  where_sql, dedup_sql,
  age_lower_bound, as.integer(cfg$cleaning$max_age),
  age_sql, age_lower_bound, as.integer(cfg$cleaning$max_age), age_sql,
  as.integer(cfg$cleaning$max_length_of_stay),
  as.integer(cfg$cleaning$max_length_of_stay),
  sql_path(clean_path)
)

log_info("Writing ", basename(clean_path), " (filter + deduplicate + derive)")
db_exec(con, sql_write)

n_clean <- parquet_nrow(con, clean_path)
n_after_filters <- counts$n_total - counts$n_empty - counts$n_bad_dates
n_duplicates <- n_after_filters - n_clean

log_info("  after filters : ", format(n_after_filters, big.mark = " "))
log_info("  duplicates    : ", format(n_duplicates, big.mark = " "))
log_info("  final records : ", format(n_clean, big.mark = " "))

record_flow_append(cfg, "02_empty_rows_removed", counts$n_empty,
                   "every payload column NULL or empty")
record_flow_append(cfg, "02_inconsistent_dates_removed", counts$n_bad_dates,
                   "discharge date earlier than admission date")
record_flow_append(cfg, "02_duplicates_removed", n_duplicates,
                   "identical on every payload column")
record_flow_append(cfg, "02_analysis_records", n_clean,
                   "denominator reported in the manuscript")


# -----------------------------------------------------------------------------
# Quick sanity summary of the derived variables
# -----------------------------------------------------------------------------

summ <- db_get(con, sprintf("
  SELECT
    COUNT(*)                                            AS n,
    SUM(CASE WHEN EDAD IS NULL THEN 1 ELSE 0 END)       AS edad_missing,
    ROUND(AVG(EDAD), 2)                                 AS edad_mean,
    MEDIAN(EDAD)                                        AS edad_median,
    SUM(CASE WHEN DURACION_HOSPITAL IS NULL THEN 1 ELSE 0 END) AS los_missing,
    ROUND(AVG(DURACION_HOSPITAL), 2)                    AS los_mean,
    MEDIAN(DURACION_HOSPITAL)                           AS los_median,
    SUM(CASE WHEN SEXO_BINARIO IS NULL THEN 1 ELSE 0 END) AS sexo_missing,
    ROUND(AVG(CAST(SEXO_BINARIO AS DOUBLE)), 4)         AS female_share
  FROM read_parquet('%s')
", sql_path(clean_path)))

write_csv_utf8(summ, cfg_path(cfg, "tables", "derived_variable_summary.csv"))
log_info("Derived variables: median age ", summ$edad_median,
         ", median length of stay ", summ$los_median,
         ", female share ", summ$female_share)

save_run_metadata(cfg, "02_clean_and_derive")
log_end()
