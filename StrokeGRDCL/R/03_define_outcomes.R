# =============================================================================
# R/03_define_outcomes.R
#
# STEP 3 - Case definition and long code table.
#
# Input : data/interim/grd_clean.parquet          (step 2)
# Output: data/interim/code_long.parquet          (RECORD_ID, CODE, ORIGIN)
#         data/processed/discharges.parquet       (one row per discharge)
#         results/tables/outcome_counts.csv
#
# Two products, both reused by later steps:
#
#   code_long   One row per (record, code, provenance). ORIGIN is DIAG1 for the
#               principal diagnosis, DIAG2_35 for the secondary diagnoses and
#               PROC for procedures. Unpivoting once turns the chi-square
#               screening of step 5 from roughly twenty thousand full table
#               scans into a single aggregation, and step 6 reuses it to build
#               the indicator columns.
#
#   discharges  Slim analysis table: identifiers, the three derived variables,
#               comuna (raw and normalised) and the ten outcome flags. The 65
#               raw diagnosis and procedure columns are not carried forward
#               because code_long already holds their content.
#
# Case definition
#   Controlled by case_definition$mode in config.yml:
#     manuscript  ischaemic I63*, haemorrhagic I61*, unspecified I64
#     extended    ischaemic I63*/I65*/I66*, haemorrhagic I60*/I61*/I62*,
#                 unspecified I64   <- what the original scripts ran
#   The two definitions produce different case counts. See README.
#
# Outcome columns
#   D1_*  the code appears in DIAGNOSTICO1 (principal diagnosis)
#   D2_*  the code appears in DIAGNOSTICO2..35 (secondary diagnoses)
#   D1_ACV_GENERAL / D2_ACV_GENERAL  any of the three subtypes
#   D1_HEM_VS_ISQ / D2_HEM_VS_ISQ    1 = ischaemic, 0 = haemorrhagic,
#                                    NULL for records that are neither, which
#                                    are not comparable and must stay out of the
#                                    sampling pool for that scenario
#
# IMPORTANT - fixed bug
#   The original definition returned NULL rather than 0 when the diagnosis field
#   was NULL, because REGEXP_MATCHES(NULL, ...) is NULL. Sampling controls with
#   "WHERE outcome = 0" then silently dropped every record with a missing
#   principal diagnosis from the control pool. Subtype and general flags are
#   COALESCEd to 0 here; only the HEM_VS_ISQ contrast keeps its NULLs, where
#   they are meaningful.
# =============================================================================

source("R/utils.R")

cfg <- load_config()
log_start(cfg, "03_define_outcomes")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

clean_path <- cfg_path(cfg, "interim", "grd_clean.parquet")
if (!file.exists(clean_path)) {
  fail("Missing step 2 output: ", clean_path, "\nRun: Rscript R/02_clean_and_derive.R")
}

db_exec(con, sprintf("
  CREATE OR REPLACE VIEW clean AS SELECT * FROM read_parquet('%s')
", sql_path(clean_path)))

n_records <- parquet_nrow(con, clean_path)
log_info("Discharges available: ", format(n_records, big.mark = " "))


# -----------------------------------------------------------------------------
# 3.1  Long code table
# -----------------------------------------------------------------------------

principal_col <- cfg$case_definition$principal_column
secondary_cols <- secondary_diagnosis_columns(cfg)
proc_cols <- procedure_columns(cfg)

available <- names(db_get(con, "SELECT * FROM clean LIMIT 0"))
secondary_cols <- intersect(secondary_cols, available)
proc_cols <- intersect(proc_cols, available)

log_info("Unpivoting ", 1 + length(secondary_cols) + length(proc_cols),
         " code columns into a long table")

#' One SELECT per source column, all combined with UNION ALL.
#'
#' Codes are trimmed and upper-cased; empty strings and NULLs are dropped.
#' DISTINCT collapses a code repeated across several columns of the same record
#' into a single row, so an indicator built from this table is a presence flag,
#' never a count.
unpivot_select <- function(col, origin) {
  sprintf(
    "SELECT RECORD_ID, UPPER(TRIM(CAST(%s AS VARCHAR))) AS CODE, '%s' AS ORIGIN
       FROM clean
      WHERE %s IS NOT NULL AND TRIM(CAST(%s AS VARCHAR)) <> ''",
    sql_id(col), origin, sql_id(col), sql_id(col)
  )
}

selects <- c(
  unpivot_select(principal_col, "DIAG1"),
  vapply(secondary_cols, unpivot_select, character(1), origin = "DIAG2_35"),
  vapply(proc_cols, unpivot_select, character(1), origin = "PROC")
)

code_long_path <- cfg_path(cfg, "interim", "code_long.parquet")

db_exec(con, sprintf("
COPY (
  SELECT DISTINCT RECORD_ID, CODE, ORIGIN
  FROM (
    %s
  )
)
TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD);
", paste(selects, collapse = "\n    UNION ALL\n    "), sql_path(code_long_path)))

db_exec(con, sprintf("
  CREATE OR REPLACE VIEW code_long AS SELECT * FROM read_parquet('%s')
", sql_path(code_long_path)))

n_code_rows <- parquet_nrow(con, code_long_path)
log_info("code_long.parquet: ", format(n_code_rows, big.mark = " "), " rows")

code_summary <- db_get(con, "
  SELECT ORIGIN, COUNT(*) AS n_rows, COUNT(DISTINCT CODE) AS n_distinct_codes
  FROM code_long GROUP BY ORIGIN ORDER BY ORIGIN
")
write_csv_utf8(code_summary, cfg_path(cfg, "tables", "code_inventory.csv"))
for (i in seq_len(nrow(code_summary))) {
  log_info("  ", code_summary$ORIGIN[i], ": ",
           format(code_summary$n_rows[i], big.mark = " "), " rows, ",
           code_summary$n_distinct_codes[i], " distinct codes")
}


# -----------------------------------------------------------------------------
# 3.2  Outcome flags
# -----------------------------------------------------------------------------

pat <- outcome_patterns(cfg)
log_info("Case definition mode '", cfg$case_definition$mode, "':")
log_info("  ischaemic    : ", pat$ischaemic)
log_info("  haemorrhagic : ", pat$haemorrhagic)
log_info("  unspecified  : ", pat$unspecified)

#' MAX(...) over the long table: 1 when at least one code of the requested
#' provenance matches the pattern, 0 otherwise.
flag_sql <- function(origin, pattern, alias) {
  sprintf(
    "MAX(CASE WHEN ORIGIN = '%s' AND REGEXP_MATCHES(CODE, %s) THEN 1 ELSE 0 END) AS %s",
    origin, sql_str(pattern), alias
  )
}

flags <- c(
  flag_sql("DIAG1", pat$ischaemic,    "D1_ACV_ISQUEMICO"),
  flag_sql("DIAG1", pat$haemorrhagic, "D1_ACV_HEMORRAGICO"),
  flag_sql("DIAG1", pat$unspecified,  "D1_ACV_NOESPECIFICADO"),
  flag_sql("DIAG2_35", pat$ischaemic,    "D2_ACV_ISQUEMICO"),
  flag_sql("DIAG2_35", pat$haemorrhagic, "D2_ACV_HEMORRAGICO"),
  flag_sql("DIAG2_35", pat$unspecified,  "D2_ACV_NOESPECIFICADO")
)

discharges_path <- cfg_path(cfg, "processed", "discharges.parquet")

sql_discharges <- sprintf("
COPY (
  WITH per_record AS (
    SELECT RECORD_ID, %s
    FROM code_long
    GROUP BY RECORD_ID
  ),
  code_counts AS (
    SELECT
      RECORD_ID,
      SUM(CASE WHEN ORIGIN = 'DIAG2_35' THEN 1 ELSE 0 END) AS N_DIAG_SEC,
      SUM(CASE WHEN ORIGIN = 'PROC'     THEN 1 ELSE 0 END) AS N_PROC
    FROM code_long
    GROUP BY RECORD_ID
  ),
  base AS (
    SELECT
      c.RECORD_ID,
      c.SOURCE_YEAR,
      c.COMUNA,
      %s AS COMUNA_KEY,
      c.EDAD,
      c.DURACION_HOSPITAL,
      c.SEXO_BINARIO,
      c.DIAGNOSTICO1,
      COALESCE(cc.N_DIAG_SEC, 0) AS N_DIAG_SEC,
      COALESCE(cc.N_PROC, 0)     AS N_PROC,
      COALESCE(p.D1_ACV_ISQUEMICO, 0)      AS D1_ACV_ISQUEMICO,
      COALESCE(p.D1_ACV_HEMORRAGICO, 0)    AS D1_ACV_HEMORRAGICO,
      COALESCE(p.D1_ACV_NOESPECIFICADO, 0) AS D1_ACV_NOESPECIFICADO,
      COALESCE(p.D2_ACV_ISQUEMICO, 0)      AS D2_ACV_ISQUEMICO,
      COALESCE(p.D2_ACV_HEMORRAGICO, 0)    AS D2_ACV_HEMORRAGICO,
      COALESCE(p.D2_ACV_NOESPECIFICADO, 0) AS D2_ACV_NOESPECIFICADO
    FROM clean AS c
    LEFT JOIN per_record   AS p  ON p.RECORD_ID  = c.RECORD_ID
    LEFT JOIN code_counts  AS cc ON cc.RECORD_ID = c.RECORD_ID
  )
  SELECT
    *,
    -- Any stroke subtype, per hierarchy.
    CASE WHEN D1_ACV_ISQUEMICO + D1_ACV_HEMORRAGICO + D1_ACV_NOESPECIFICADO > 0
         THEN 1 ELSE 0 END AS D1_ACV_GENERAL,
    CASE WHEN D2_ACV_ISQUEMICO + D2_ACV_HEMORRAGICO + D2_ACV_NOESPECIFICADO > 0
         THEN 1 ELSE 0 END AS D2_ACV_GENERAL,
    -- Direct subtype contrast: 1 ischaemic, 0 haemorrhagic, NULL not comparable.
    -- Records coded with both subtypes are also NULL: assigning them to one
    -- side would be arbitrary.
    CASE
      WHEN D1_ACV_ISQUEMICO = 1 AND D1_ACV_HEMORRAGICO = 1 THEN NULL
      WHEN D1_ACV_ISQUEMICO = 1 THEN 1
      WHEN D1_ACV_HEMORRAGICO = 1 THEN 0
      ELSE NULL
    END AS D1_HEM_VS_ISQ,
    CASE
      WHEN D2_ACV_ISQUEMICO = 1 AND D2_ACV_HEMORRAGICO = 1 THEN NULL
      WHEN D2_ACV_ISQUEMICO = 1 THEN 1
      WHEN D2_ACV_HEMORRAGICO = 1 THEN 0
      ELSE NULL
    END AS D2_HEM_VS_ISQ
  FROM base
)
TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD);
",
  paste(flags, collapse = ",\n           "),
  sql_normalise_place("COMUNA"),
  sql_path(discharges_path)
)

log_info("Writing ", basename(discharges_path))
db_exec(con, sql_discharges)


# -----------------------------------------------------------------------------
# 3.3  Case counts, per scenario
# -----------------------------------------------------------------------------

scen <- scenario_table(cfg)
outcome_cols <- unique(c(scen$name, "D2_HEM_VS_ISQ"))

count_sql <- paste(vapply(outcome_cols, function(cl) sprintf(
  "SELECT '%s' AS outcome,
          SUM(CASE WHEN %s = 1 THEN 1 ELSE 0 END) AS n_cases,
          SUM(CASE WHEN %s = 0 THEN 1 ELSE 0 END) AS n_controls,
          SUM(CASE WHEN %s IS NULL THEN 1 ELSE 0 END) AS n_not_comparable
     FROM read_parquet('%s')",
  cl, sql_id(cl), sql_id(cl), sql_id(cl), sql_path(discharges_path)
), character(1)), collapse = "\nUNION ALL\n")

outcome_counts <- db_get(con, count_sql)
outcome_counts$label <- scen$label[match(outcome_counts$outcome, scen$name)]
outcome_counts$case_definition_mode <- cfg$case_definition$mode
write_csv_utf8(outcome_counts, cfg_path(cfg, "tables", "outcome_counts.csv"))

for (i in seq_len(nrow(outcome_counts))) {
  log_info("  ", outcome_counts$outcome[i], ": ",
           format(outcome_counts$n_cases[i], big.mark = " "), " cases / ",
           format(outcome_counts$n_controls[i], big.mark = " "), " controls",
           if (outcome_counts$n_not_comparable[i] > 0) {
             paste0(" / ", format(outcome_counts$n_not_comparable[i], big.mark = " "),
                    " not comparable")
           } else "")
}

record_flow_append(
  cfg, "03_outcomes_defined", parquet_nrow(con, discharges_path),
  paste0("case definition mode: ", cfg$case_definition$mode)
)

save_run_metadata(cfg, "03_define_outcomes")
log_end()
