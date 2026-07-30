# =============================================================================
# R/utils.R
#
# Shared helpers for every step of the pipeline: configuration loading, logging,
# DuckDB session management, ICD-10 pattern handling, classification metrics and
# small file utilities.
#
# This file only defines objects. It never runs analysis and never writes to
# data/ or results/, so it is safe to source from anywhere.
#
# Usage from a pipeline script:
#   source("R/utils.R")
#   cfg <- load_config()
# =============================================================================


# -----------------------------------------------------------------------------
# Small language helpers
# -----------------------------------------------------------------------------

#' Null-coalescing operator: returns `b` when `a` is NULL or empty.
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0L) b else a
}


#' Stop with a message that does not print the call stack twice.
fail <- function(...) {
  stop(paste0(...), call. = FALSE)
}


# -----------------------------------------------------------------------------
# Package management
#
# The pipeline deliberately depends on a small, stable set of CRAN packages.
# Nothing is installed automatically: the function reports every missing
# package at once, with a ready-to-paste install call.
# -----------------------------------------------------------------------------

#' Ensure that a set of packages is installed and attached.
#'
#' @param pkgs character vector of package names.
#' @param attach if TRUE the packages are attached with library(); if FALSE they
#'   are only checked (use `pkg::fun()` in that case).
require_pkgs <- function(pkgs, attach = TRUE) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    fail(
      "Missing packages: ", paste(missing, collapse = ", "), "\n",
      'Install them with:  install.packages(c("',
      paste(missing, collapse = '", "'), '"))'
    )
  }
  if (attach) {
    for (p in pkgs) {
      suppressPackageStartupMessages(
        library(p, character.only = TRUE, quietly = TRUE)
      )
    }
  }
  invisible(TRUE)
}


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

#' Load config.yml and normalise the few fields that YAML parsers get wrong.
#'
#' Scientific notation such as 5.0e-100 is coerced to numeric explicitly,
#' because some YAML readers return it as a character string.
#'
#' @param path path to the YAML file. Defaults to the STROKE_DRG_CONFIG
#'   environment variable, or "config.yml" in the current working directory.
load_config <- function(path = NULL) {
  require_pkgs("yaml", attach = FALSE)
  path <- path %||% Sys.getenv("STROKE_DRG_CONFIG", "config.yml")

  if (!file.exists(path)) {
    fail(
      "Cannot find '", path, "'.\n",
      "Run every script from the repository root, for example:\n",
      "  Rscript R/01_ingest_grd.R"
    )
  }

  cfg <- yaml::read_yaml(path)

  cfg$screening$p_threshold <- as.numeric(cfg$screening$p_threshold)
  cfg$split$development_fraction <- as.numeric(cfg$split$development_fraction)
  cfg$hypervolume$reference_point <- as.numeric(
    unlist(cfg$hypervolume$reference_point)
  )

  # Create every output directory up front so no step fails halfway through
  # because a folder is missing.
  for (key in c("interim", "processed", "results", "tables", "figures",
                "selection", "final_model", "logs")) {
    ensure_dir(cfg$paths[[key]])
  }
  ensure_dir(cfg$duckdb$temp_directory)

  cfg
}


#' Build a path inside one of the configured directories.
#'
#' @examples
#'   cfg_path(cfg, "processed", "model_matrix.parquet")
cfg_path <- function(cfg, key, ...) {
  base <- cfg$paths[[key]]
  if (is.null(base)) fail("Unknown path key in config.yml: '", key, "'")
  file.path(base, ...)
}


#' Data frame of analytical scenarios: column name plus manuscript label.
scenario_table <- function(cfg) {
  data.frame(
    name  = vapply(cfg$scenarios, function(s) s$name, character(1)),
    label = vapply(cfg$scenarios, function(s) s$label, character(1)),
    stringsAsFactors = FALSE
  )
}


# -----------------------------------------------------------------------------
# Logging
#
# Every message goes to the console and, once log_start() has been called, to
# results/logs/<step>.log as well. Timestamps make it possible to see which
# step of a multi-hour run is slow.
# -----------------------------------------------------------------------------

.log_state <- new.env(parent = emptyenv())
.log_state$file <- NULL
.log_state$step <- NULL
.log_state$t0 <- NULL


#' Open a log file for the current step and print a run header.
log_start <- function(cfg, step) {
  ensure_dir(cfg$paths$logs)
  .log_state$file <- cfg_path(cfg, "logs", paste0(step, ".log"))
  .log_state$step <- step
  .log_state$t0 <- Sys.time()

  # Truncate any log from a previous run of the same step.
  cat("", file = .log_state$file, append = FALSE)

  log_info(strrep("=", 78))
  log_info("Step: ", step)
  log_info("Project: ", cfg$project$label)
  log_info("Case definition mode: ", cfg$case_definition$mode)
  log_info("Started: ", format(.log_state$t0, "%Y-%m-%d %H:%M:%S"))
  log_info(strrep("=", 78))
  invisible(.log_state$file)
}


#' Timestamped log line.
log_info <- function(...) {
  line <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(..., collapse = ""))
  message(line)
  if (!is.null(.log_state$file)) {
    cat(line, "\n", sep = "", file = .log_state$file, append = TRUE)
  }
  invisible(line)
}


#' Log line prefixed as a warning. Does not raise an R condition.
log_warn <- function(...) {
  log_info("WARNING: ", paste0(..., collapse = ""))
}


#' Close the current step, reporting elapsed time.
log_end <- function() {
  if (!is.null(.log_state$t0)) {
    mins <- as.numeric(difftime(Sys.time(), .log_state$t0, units = "mins"))
    log_info("Finished '", .log_state$step, "' in ", round(mins, 2), " minutes")
  }
  .log_state$file <- NULL
  invisible(TRUE)
}


# -----------------------------------------------------------------------------
# Files and directories
# -----------------------------------------------------------------------------

#' Create a directory (and its parents) if it does not exist.
ensure_dir <- function(path) {
  if (!is.null(path) && !dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(path)
}


#' Write a data frame as UTF-8 CSV without row names.
write_csv_utf8 <- function(x, path) {
  ensure_dir(dirname(path))
  utils::write.csv(x, path, row.names = FALSE, fileEncoding = "UTF-8", na = "")
  invisible(path)
}


#' Read a UTF-8 CSV keeping character columns as character.
read_csv_utf8 <- function(path) {
  if (!file.exists(path)) fail("Missing input file: ", path)
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}


#' Absolute path with forward slashes, safe to embed in a SQL string literal.
#'
#' DuckDB accepts forward slashes on every platform; Windows backslashes would
#' be interpreted as escapes inside the SQL literal.
sql_path <- function(path) {
  gsub("\\\\", "/", normalizePath(path, winslash = "/", mustWork = FALSE))
}


#' Quote a value as a SQL string literal, doubling embedded single quotes.
sql_str <- function(x) {
  paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
}


#' Quote an identifier for DuckDB.
sql_id <- function(x) {
  paste0('"', gsub('"', '""', x, fixed = TRUE), '"')
}


# -----------------------------------------------------------------------------
# DuckDB session
# -----------------------------------------------------------------------------

#' Open a DuckDB connection with the configured memory and thread limits.
#'
#' @param cfg configuration list.
#' @param in_memory if TRUE use an in-memory database; otherwise use the file
#'   configured in paths$duckdb_tmp (survives across steps, useful for debugging).
db_connect <- function(cfg, in_memory = TRUE) {
  require_pkgs(c("DBI", "duckdb"), attach = FALSE)

  dbdir <- if (in_memory) ":memory:" else cfg$paths$duckdb_tmp
  if (!in_memory) ensure_dir(dirname(dbdir))

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbdir)

  DBI::dbExecute(con, sprintf("PRAGMA memory_limit='%s'", cfg$duckdb$memory_limit))
  DBI::dbExecute(con, sprintf("PRAGMA threads=%d", as.integer(cfg$duckdb$threads)))
  if (!is.null(cfg$duckdb$temp_directory)) {
    ensure_dir(cfg$duckdb$temp_directory)
    DBI::dbExecute(con, sprintf(
      "PRAGMA temp_directory='%s'", sql_path(cfg$duckdb$temp_directory)
    ))
  }
  con
}


#' Close a DuckDB connection and shut the engine down.
db_close <- function(con) {
  try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
  invisible(TRUE)
}


#' Execute a statement, returning the number of affected rows.
db_exec <- function(con, sql) {
  DBI::dbExecute(con, sql)
}


#' Run a query and return a data frame.
db_get <- function(con, sql) {
  DBI::dbGetQuery(con, sql)
}


#' Scalar result of a query (first column of the first row).
db_scalar <- function(con, sql) {
  out <- DBI::dbGetQuery(con, sql)
  if (nrow(out) == 0L) return(NA)
  out[[1]][1]
}


#' Column names of a parquet file, without reading any data.
parquet_columns <- function(con, path) {
  names(db_get(con, sprintf(
    "SELECT * FROM read_parquet('%s') LIMIT 0", sql_path(path)
  )))
}


#' Number of rows in a parquet file.
parquet_nrow <- function(con, path) {
  as.numeric(db_scalar(con, sprintf(
    "SELECT COUNT(*) FROM read_parquet('%s')", sql_path(path)
  )))
}


# -----------------------------------------------------------------------------
# Text normalisation
#
# The FONASA files mix encodings, so the same comuna can appear as "CONCEPCION",
# "CONCEPCIÓN" and "CONCEPCI<D3>N" (a Latin-1 byte that survived as its hex
# escape). These helpers collapse all three into one key.
# -----------------------------------------------------------------------------

#' Repair hexadecimal escapes left behind by a failed Latin-1 conversion.
repair_hex_escapes <- function(x) {
  map <- c(
    "<C1>" = "\u00C1", "<C9>" = "\u00C9", "<CD>" = "\u00CD",
    "<D1>" = "\u00D1", "<D3>" = "\u00D3", "<DA>" = "\u00DA",
    "<DC>" = "\u00DC"
  )
  for (pattern in names(map)) {
    x <- gsub(pattern, map[[pattern]], x, fixed = TRUE)
  }
  x
}


#' Replace accented characters by their unaccented base letter.
strip_accents <- function(x) {
  chartr(
    "\u00C1\u00C9\u00CD\u00D3\u00DA\u00D1\u00DC\u00E1\u00E9\u00ED\u00F3\u00FA\u00F1\u00FC",
    "AEIOUNUaeiounu",
    x
  )
}


#' Canonical key for a place name: repaired, unaccented, upper case, single
#' spaces, no punctuation.
normalise_place <- function(x) {
  # Accents are removed before upper-casing: toupper() does not map accented
  # characters in a C locale, which would leave them to be swallowed by the
  # [^A-Z0-9] substitution below.
  x <- repair_hex_escapes(as.character(x))
  x <- toupper(strip_accents(trimws(x)))
  x <- gsub("[^A-Z0-9 ]", " ", x)
  gsub(" +", " ", trimws(x))
}


#' SQL expression that applies normalise_place() inside DuckDB.
#'
#' Same three steps as the R version: repair hexadecimal escapes, drop accents,
#' collapse everything that is not a letter or digit into single spaces. Keeping
#' the logic in SQL avoids pulling 5.8 million comuna strings into R.
#'
#' @param col unquoted column name.
sql_normalise_place <- function(col) {
  expr <- sql_id(col)

  # 1. Hexadecimal escapes left behind by a failed Latin-1 conversion.
  hex_map <- c(
    "<C1>" = "\u00C1", "<C9>" = "\u00C9", "<CD>" = "\u00CD",
    "<D1>" = "\u00D1", "<D3>" = "\u00D3", "<DA>" = "\u00DA",
    "<DC>" = "\u00DC"
  )
  for (pattern in names(hex_map)) {
    expr <- sprintf("REPLACE(%s, %s, %s)", expr, sql_str(pattern), sql_str(hex_map[[pattern]]))
  }

  # 2. Accented characters. Written out explicitly instead of relying on
  #    strip_accents(), which is not available in older DuckDB builds.
  accent_map <- c(
    "\u00C1" = "A", "\u00C9" = "E", "\u00CD" = "I", "\u00D3" = "O",
    "\u00DA" = "U", "\u00D1" = "N", "\u00DC" = "U",
    "\u00E1" = "A", "\u00E9" = "E", "\u00ED" = "I", "\u00F3" = "O",
    "\u00FA" = "U", "\u00F1" = "N", "\u00FC" = "U"
  )
  for (pattern in names(accent_map)) {
    expr <- sprintf("REPLACE(%s, %s, %s)", expr, sql_str(pattern), sql_str(accent_map[[pattern]]))
  }

  # 3. Upper case, collapse anything that is not a letter or digit into a single
  #    space, trim.
  sprintf(
    "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(UPPER(%s), '[^A-Z0-9]', ' ', 'g'), ' +', ' ', 'g'))",
    expr
  )
}


#' Turn an ICD-10 or ICD-9 code into a syntactically valid column name suffix.
#' "I63.9" becomes "I63_9", "87.03" becomes "87_03".
sanitise_code <- function(x) {
  gsub("[^A-Za-z0-9]", "_", toupper(trimws(as.character(x))))
}


#' Feature column name from a code and its provenance.
#'
#' The prefix records where the code was found during screening, not where it is
#' evaluated: a DIAG1_* column is 1 whenever the code appears in any diagnosis
#' or procedure field of the record. This matches the published run.
feature_name <- function(code, origin) {
  paste0(origin, "_", sanitise_code(code))
}


# -----------------------------------------------------------------------------
# ICD-10 case definition
# -----------------------------------------------------------------------------

#' Active regular expressions for the three stroke subtypes.
#'
#' @return named list with elements ischaemic, haemorrhagic, unspecified, each a
#'   single regular expression.
outcome_patterns <- function(cfg) {
  mode <- cfg$case_definition$mode
  spec <- cfg$case_definition$patterns[[mode]]
  if (is.null(spec)) {
    fail("Unknown case_definition$mode: '", mode,
         "'. Valid values: ", paste(names(cfg$case_definition$patterns), collapse = ", "))
  }
  lapply(spec, function(p) paste(unlist(p), collapse = "|"))
}


#' Single regular expression matching any code that defines an outcome.
#'
#' Used as the leakage guard in step 05: a code that defines the outcome cannot
#' also be a candidate predictor of that outcome.
outcome_guard_pattern <- function(cfg) {
  paste(unlist(outcome_patterns(cfg)), collapse = "|")
}


#' Names of the diagnosis and procedure columns of the raw table.
diagnosis_columns <- function(cfg) {
  rng <- unlist(cfg$case_definition$secondary_columns_range)
  c(cfg$case_definition$principal_column,
    paste0("DIAGNOSTICO", seq(rng[1], rng[2])))
}

secondary_diagnosis_columns <- function(cfg) {
  rng <- unlist(cfg$case_definition$secondary_columns_range)
  paste0("DIAGNOSTICO", seq(rng[1], rng[2]))
}

procedure_columns <- function(cfg) {
  rng <- unlist(cfg$case_definition$procedure_columns_range)
  paste0("PROCEDIMIENTO", seq(rng[1], rng[2]))
}


# -----------------------------------------------------------------------------
# Classification metrics
#
# One implementation, shared by the three models, so that a difference between
# models can never be an artefact of a different metric definition. The positive
# class is always "case".
# -----------------------------------------------------------------------------

#' Area under the ROC curve, computed from ranks (Mann-Whitney form).
#'
#' Exact, handles ties, no external dependency.
#'
#' @param y_true factor or 0/1 vector; 1 / "case" is the positive class.
#' @param score numeric predicted score or probability.
auc_roc <- function(y_true, score) {
  pos <- as.integer(as_case_indicator(y_true))
  if (length(unique(pos)) < 2L) return(NA_real_)
  ok <- is.finite(score)
  if (!all(ok)) {
    pos <- pos[ok]
    score <- score[ok]
    if (length(unique(pos)) < 2L) return(NA_real_)
  }
  r <- rank(score, ties.method = "average")
  n1 <- sum(pos == 1L)
  n0 <- sum(pos == 0L)
  (sum(r[pos == 1L]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}


#' Coerce a label vector to a 0/1 indicator of the positive class.
as_case_indicator <- function(y) {
  if (is.factor(y)) return(as.integer(y == "case"))
  if (is.character(y)) return(as.integer(y == "case"))
  as.integer(y == 1L | y == 1)
}


#' Precision, sensitivity, F1, accuracy and AUC at a fixed probability cut-off.
#'
#' Undefined ratios return NA rather than 0, so that replicates in which the
#' model predicted no positive case are excluded from the averages instead of
#' silently pulling them down.
#'
#' @return named numeric vector: precision, sensitivity, f1, accuracy, auc.
classification_metrics <- function(y_true, prob, threshold = 0.5) {
  y <- as_case_indicator(y_true)
  pred <- as.integer(prob >= threshold)

  tp <- sum(pred == 1L & y == 1L)
  fp <- sum(pred == 1L & y == 0L)
  fn <- sum(pred == 0L & y == 1L)
  tn <- sum(pred == 0L & y == 0L)

  precision   <- if ((tp + fp) > 0L) tp / (tp + fp) else NA_real_
  sensitivity <- if ((tp + fn) > 0L) tp / (tp + fn) else NA_real_
  f1 <- if (!is.na(precision) && !is.na(sensitivity) && (precision + sensitivity) > 0) {
    2 * precision * sensitivity / (precision + sensitivity)
  } else {
    NA_real_
  }
  accuracy <- (tp + tn) / length(y)

  c(precision = precision,
    sensitivity = sensitivity,
    f1 = f1,
    accuracy = accuracy,
    auc = auc_roc(y_true, prob))
}


#' Stratified k-fold assignment.
#'
#' @param y label vector.
#' @param k number of folds.
#' @param seed integer seed; the same seed yields the same folds, which is what
#'   makes the three models comparable within a replicate.
#' @return integer vector of fold indices, one per observation.
stratified_folds <- function(y, k, seed) {
  set.seed(seed)
  idx <- as_case_indicator(y)
  folds <- integer(length(idx))
  for (cls in c(0L, 1L)) {
    pos <- which(idx == cls)
    pos <- sample(pos)
    folds[pos] <- rep_len(seq_len(k), length(pos))
  }
  folds
}


# -----------------------------------------------------------------------------
# Record flow audit
#
# Every record dropped during ingestion and cleaning is counted, so the final
# denominator reported in the manuscript can be traced back to a specific rule
# instead of being taken on trust.
# -----------------------------------------------------------------------------

#' Append one line to results/tables/record_flow.csv.
record_flow_append <- function(cfg, stage, n_records, note = "") {
  path <- cfg_path(cfg, "tables", "record_flow.csv")
  row <- data.frame(
    stage = stage,
    n_records = as.numeric(n_records),
    note = note,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )
  if (file.exists(path)) {
    prev <- read_csv_utf8(path)
    row <- rbind(prev, row)
  }
  write_csv_utf8(row, path)
  invisible(path)
}


# -----------------------------------------------------------------------------
# Run metadata
# -----------------------------------------------------------------------------

#' Write R version, platform, package versions and the active configuration to
#' results/run_metadata_<step>.txt. Called at the end of each step so that any
#' result can be traced to the environment that produced it.
save_run_metadata <- function(cfg, step, pkgs = character(0)) {
  path <- cfg_path(cfg, "results", paste0("run_metadata_", step, ".txt"))
  con <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  writeLines(c(
    paste0("step: ", step),
    paste0("timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("R version: ", R.version.string),
    paste0("platform: ", R.version$platform),
    paste0("case_definition_mode: ", cfg$case_definition$mode),
    paste0("exclude_outcome_codes: ",
           cfg$case_definition$exclude_outcome_codes_from_predictors),
    paste0("n_replicates: ", cfg$resampling$n_replicates),
    paste0("n_per_class: ", cfg$resampling$n_per_class),
    paste0("resampling_seed: ", cfg$resampling$seed),
    paste0("split_seed: ", cfg$split$seed),
    "packages:"
  ), con)

  for (p in unique(c("DBI", "duckdb", pkgs))) {
    v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) "not installed")
    writeLines(paste0("  ", p, ": ", v), con)
  }
  invisible(path)
}
