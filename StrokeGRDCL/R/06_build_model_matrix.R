# =============================================================================
# R/06_build_model_matrix.R
#
# STEP 6 - Analysis-ready model matrix.
#
# Input : data/processed/discharges.parquet        (step 3)
#         data/interim/code_long.parquet           (step 3)
#         data/processed/split_assignment.parquet  (step 5)
#         results/tables/selected_features.csv     (step 5)
#         results/tables/imputation_medians.csv    (step 5)
# Output: data/processed/model_matrix.parquet
#         results/tables/model_matrix_columns.csv
#
# Layout of the output, one row per discharge:
#   RECORD_ID, SPLIT
#   EDAD, DURACION_HOSPITAL, SEXO_BINARIO      numeric / binary, imputed
#   <one 0/1 column per screened code>         named <PROVENANCE>_<CODE>
#   COMUNA_<NAME>                              one dummy per comuna
#   D1_*, D2_*                                 the ten outcome columns
#
# Semantics of the code indicators
#   With model_matrix$provenance_aware_indicators = false (the published
#   behaviour) a column named DIAG1_I67_8 is 1 whenever the code I67.8 appears in
#   any diagnosis or procedure field of the record. The prefix records where the
#   code was discovered during screening, not where it is read. Setting the
#   option to true makes each indicator respect its provenance, which is cleaner
#   but produces different numbers.
#
# Missing values
#   EDAD and DURACION_HOSPITAL are filled with the development-subset medians
#   computed in step 5, so the imputed value no longer depends on which resample
#   a record happens to fall into. SEXO_BINARIO keeps its missing values as
#   NULL: it is a categorical field and imputing a sex would be an invention.
#   Step 7 drops columns that still contain missing values inside a resample,
#   exactly as the original did.
# =============================================================================

source("R/utils.R")

cfg <- load_config()
log_start(cfg, "06_build_model_matrix")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

discharges_path <- cfg_path(cfg, "processed", "discharges.parquet")
code_long_path <- cfg_path(cfg, "interim", "code_long.parquet")
split_path <- cfg_path(cfg, "processed", "split_assignment.parquet")
features_path <- cfg_path(cfg, "tables", "selected_features.csv")
medians_path <- cfg_path(cfg, "tables", "imputation_medians.csv")

for (p in c(discharges_path, code_long_path, split_path, features_path, medians_path)) {
  if (!file.exists(p)) fail("Missing input: ", p, "\nRun steps 3 and 5 first.")
}

db_exec(con, sprintf("CREATE OR REPLACE VIEW discharges AS SELECT * FROM read_parquet('%s')",
                     sql_path(discharges_path)))
db_exec(con, sprintf("CREATE OR REPLACE VIEW code_long AS SELECT * FROM read_parquet('%s')",
                     sql_path(code_long_path)))
db_exec(con, sprintf("CREATE OR REPLACE VIEW split_assignment AS SELECT * FROM read_parquet('%s')",
                     sql_path(split_path)))


# -----------------------------------------------------------------------------
# 6.1  Feature list and imputation values
# -----------------------------------------------------------------------------

features <- read_csv_utf8(features_path)
codes <- features[features$origin != "DERIVED", ]
if (nrow(codes) == 0L) fail("selected_features.csv contains no screened codes.")

# Guard against two different codes collapsing onto the same column name.
codes$feature <- make.unique(codes$feature, sep = "_DUP")
if (any(grepl("_DUP", codes$feature, fixed = TRUE))) {
  log_warn("Some codes produced duplicate column names and were suffixed _DUP")
}

medians <- read_csv_utf8(medians_path)
median_of <- function(v) {
  x <- medians$median_development[medians$variable == v]
  if (length(x) == 0L || is.na(x[1])) 0 else as.numeric(x[1])
}

log_info("Code indicators: ", nrow(codes))
log_info("Provenance-aware indicators: ", isTRUE(cfg$model_matrix$provenance_aware_indicators))


# -----------------------------------------------------------------------------
# 6.2  Code indicator block
# -----------------------------------------------------------------------------

provenance_aware <- isTRUE(cfg$model_matrix$provenance_aware_indicators)

indicator_exprs <- vapply(seq_len(nrow(codes)), function(i) {
  code <- codes$code[i]
  cond <- if (provenance_aware) {
    sprintf("CODE = %s AND ORIGIN = %s", sql_str(code), sql_str(codes$origin[i]))
  } else {
    sprintf("CODE = %s", sql_str(code))
  }
  sprintf("MAX(CASE WHEN %s THEN 1 ELSE 0 END) AS %s", cond, sql_id(codes$feature[i]))
}, character(1))

# Restricting the long table to the selected codes before grouping keeps the
# aggregation small: the 5.8-million-record scan touches only the rows that can
# contribute to a column.
codes_in_sql <- paste(sql_str(unique(codes$code)), collapse = ", ")

db_exec(con, sprintf("
  CREATE OR REPLACE VIEW code_indicators AS
  SELECT RECORD_ID,
         %s
  FROM code_long
  WHERE CODE IN (%s)
  GROUP BY RECORD_ID
", paste(indicator_exprs, collapse = ",\n         "), codes_in_sql))

# A record with none of the selected codes has no row in code_indicators, so the
# LEFT JOIN below produces NULL and COALESCE turns it into 0.
indicator_select <- paste(sprintf("COALESCE(i.%s, 0) AS %s",
                                  sql_id(codes$feature), sql_id(codes$feature)),
                          collapse = ",\n    ")


# -----------------------------------------------------------------------------
# 6.3  Comuna dummies
# -----------------------------------------------------------------------------

comuna_select <- ""
comuna_names <- character(0)

if (isTRUE(cfg$model_matrix$include_comuna_dummies)) {
  min_records <- as.integer(cfg$model_matrix$min_comuna_records %||% 0L)

  comunas <- db_get(con, sprintf("
    SELECT COMUNA_KEY, COUNT(*) AS n
    FROM discharges
    WHERE COMUNA_KEY IS NOT NULL AND COMUNA_KEY <> ''
    GROUP BY COMUNA_KEY
    HAVING COUNT(*) >= %d
    ORDER BY COMUNA_KEY
  ", min_records))

  log_info("Comuna dummies: ", nrow(comunas),
           " comunas with at least ", min_records, " discharges")

  dummy_names <- make.unique(paste0("COMUNA_", gsub(" ", "_", comunas$COMUNA_KEY)), sep = "_DUP")

  dummy_exprs <- sprintf(
    "CASE WHEN d.COMUNA_KEY = %s THEN 1 ELSE 0 END AS %s",
    sql_str(comunas$COMUNA_KEY), sql_id(dummy_names)
  )

  # Residual categories: comunas below the threshold, and records without a
  # comuna at all. Keeping them explicit means the dummies always sum to 1.
  other_expr <- sprintf(
    "CASE WHEN d.COMUNA_KEY IS NOT NULL AND d.COMUNA_KEY <> ''
               AND d.COMUNA_KEY NOT IN (%s) THEN 1 ELSE 0 END AS %s",
    paste(sql_str(comunas$COMUNA_KEY), collapse = ", "), sql_id("COMUNA_OTRA")
  )
  na_expr <- "CASE WHEN d.COMUNA_KEY IS NULL OR d.COMUNA_KEY = '' THEN 1 ELSE 0 END AS COMUNA_NA"

  if (min_records > 0L) {
    comuna_select <- paste0(paste(c(dummy_exprs, other_expr, na_expr), collapse = ",\n    "), ",\n    ")
    comuna_names <- c(dummy_names, "COMUNA_OTRA", "COMUNA_NA")
  } else {
    # With no threshold there is no residual comuna group, only the missing one.
    comuna_select <- paste0(paste(c(dummy_exprs, na_expr), collapse = ",\n    "), ",\n    ")
    comuna_names <- c(dummy_names, "COMUNA_NA")
  }
}


# -----------------------------------------------------------------------------
# 6.4  Assemble and write
# -----------------------------------------------------------------------------

scen <- scenario_table(cfg)
outcome_cols <- unique(c(scen$name, "D1_HEM_VS_ISQ", "D2_HEM_VS_ISQ",
                         "D1_ACV_ISQUEMICO", "D2_ACV_ISQUEMICO",
                         "D1_ACV_HEMORRAGICO", "D2_ACV_HEMORRAGICO",
                         "D1_ACV_NOESPECIFICADO", "D2_ACV_NOESPECIFICADO",
                         "D1_ACV_GENERAL", "D2_ACV_GENERAL"))
outcome_select <- paste(sprintf("d.%s", sql_id(outcome_cols)), collapse = ",\n    ")

matrix_path <- cfg_path(cfg, "processed", "model_matrix.parquet")

sql_matrix <- sprintf("
COPY (
  SELECT
    d.RECORD_ID,
    s.SPLIT,
    COALESCE(CAST(d.EDAD AS DOUBLE), %.6f)              AS EDAD,
    COALESCE(CAST(d.DURACION_HOSPITAL AS DOUBLE), %.6f) AS DURACION_HOSPITAL,
    CAST(d.SEXO_BINARIO AS INTEGER)                     AS SEXO_BINARIO,
    %s%s,
    %s
  FROM discharges AS d
  JOIN split_assignment AS s ON s.RECORD_ID = d.RECORD_ID
  LEFT JOIN code_indicators AS i ON i.RECORD_ID = d.RECORD_ID
)
TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD);
",
  median_of("EDAD"), median_of("DURACION_HOSPITAL"),
  comuna_select, indicator_select, outcome_select,
  sql_path(matrix_path)
)

log_info("Writing ", basename(matrix_path))
db_exec(con, sql_matrix)

matrix_cols <- parquet_columns(con, matrix_path)
n_rows <- parquet_nrow(con, matrix_path)

log_info("model_matrix.parquet: ", format(n_rows, big.mark = " "), " rows x ",
         length(matrix_cols), " columns (",
         round(file.info(matrix_path)$size / 1024^2, 1), " MB)")

# Column inventory, so that every feature in a results table can be traced back
# to the code it came from.
col_type <- ifelse(matrix_cols %in% c("RECORD_ID", "SPLIT"), "identifier",
            ifelse(matrix_cols %in% outcome_cols, "outcome",
            ifelse(matrix_cols %in% unlist(cfg$model_matrix$numeric_features), "derived",
            ifelse(matrix_cols %in% comuna_names, "comuna_dummy", "code_indicator"))))

inventory <- data.frame(
  column = matrix_cols,
  type = col_type,
  code = codes$code[match(matrix_cols, codes$feature)],
  origin = codes$origin[match(matrix_cols, codes$feature)],
  stringsAsFactors = FALSE
)
write_csv_utf8(inventory, cfg_path(cfg, "tables", "model_matrix_columns.csv"))

log_info("Columns by type: ",
         paste(sprintf("%s = %d", names(table(col_type)), as.integer(table(col_type))),
               collapse = ", "))

save_run_metadata(cfg, "06_build_model_matrix")
log_end()
