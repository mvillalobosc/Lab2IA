# =============================================================================
# R/01_ingest_grd.R
#
# STEP 1 - Ingestion of the raw FONASA DRG files.
#
# Input : data/raw/grd/GRD_PUBLICO_YYYY.txt  (pipe-delimited, one file per year)
# Output: data/interim/grd_<year>.parquet     (one parquet per year, zstd)
#
# What this step does
#   1. Reads each year with encoding auto-detection. The published files are not
#      consistent: some years are UTF-8, some Latin-1, some UTF-16.
#   2. Harmonises column names.
#   3. Parses dates and the few genuinely numeric columns; every other column is
#      kept as trimmed upper-case text. This guarantees an identical schema
#      across years, which is what allows step 2 to concatenate them.
#   4. Adds SOURCE_YEAR and ROW_IN_FILE, which together give every discharge a
#      deterministic identity. Step 2 turns them into a compact RECORD_ID.
#
# Why one file per year instead of a single in-memory table
#   The six files total roughly 4 GB of text. Reading them all into a single
#   data.table before writing (as the original script did) needs far more RAM
#   than most machines have. Converting year by year keeps peak memory at the
#   size of the largest single year.
#
# IMPORTANT - fixed bug
#   The original script coerced PROCEDIMIENTO1..11 to numeric. ICD-9-CM
#   procedure codes are not numbers: 99.10 (injection of thrombolytic agent)
#   becomes 99.1 and 89.50 becomes 89.5 after a round trip through double
#   precision, while the same codes stay intact in PROCEDIMIENTO12..30, which
#   were left as text. The result is that a code with a trailing zero is split
#   into two different strings depending on which column it landed in. Procedure
#   codes are therefore kept as character here, everywhere. See README.
# =============================================================================

source("R/utils.R")

cfg <- load_config()
# data.table is attached because the script uses := and .N; arrow is only needed
# through its namespace.
require_pkgs(c("data.table", "lubridate"), attach = TRUE)
require_pkgs("arrow", attach = FALSE)

log_start(cfg, "01_ingest_grd")


# -----------------------------------------------------------------------------
# Reader with encoding detection
# -----------------------------------------------------------------------------

#' Fraction of sampled character cells that are not valid UTF-8.
#'
#' A wrong encoding does not make fread fail, it makes it return mojibake. This
#' is the signal used to reject a candidate encoding.
invalid_utf8_share <- function(dt, n_sample = 2000L) {
  char_cols <- names(dt)[vapply(dt, is.character, logical(1))]
  if (length(char_cols) == 0L) return(0)
  rows <- seq_len(min(nrow(dt), n_sample))
  vals <- unlist(lapply(char_cols, function(cl) dt[[cl]][rows]), use.names = FALSE)
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0L) return(0)
  bad <- !validUTF8(vals)
  bad[is.na(bad)] <- TRUE
  mean(bad)
}


#' Read one GRD text file, trying the configured encodings in order.
#'
#' A candidate is accepted when it yields a plausible number of columns and no
#' invalid UTF-8. If no candidate is clean, the least bad one is used and a
#' warning is logged instead of failing silently.
read_grd_file <- function(path, cfg) {
  delim <- cfg$ingest$delimiter
  encodings <- unlist(cfg$ingest$encodings)

  best <- NULL
  best_score <- Inf

  for (enc in encodings) {
    dt <- tryCatch({
      if (toupper(enc) == "UTF-16") {
        # fread cannot read UTF-16; readr can.
        require_pkgs("readr", attach = FALSE)
        data.table::as.data.table(readr::read_delim(
          path,
          delim = delim,
          locale = readr::locale(encoding = "UTF-16"),
          col_types = readr::cols(.default = "c"),
          progress = FALSE,
          show_col_types = FALSE
        ))
      } else {
        fread_enc <- if (tolower(enc) %in% c("latin1", "latin-1", "iso-8859-1")) {
          "Latin-1"
        } else {
          "UTF-8"
        }
        data.table::fread(
          path,
          sep = delim,
          header = TRUE,
          colClasses = "character",
          encoding = fread_enc,
          showProgress = FALSE,
          na.strings = c("", "NA", "NULL")
        )
      }
    }, error = function(e) NULL)

    if (is.null(dt) || ncol(dt) < 5L) next

    score <- invalid_utf8_share(dt)
    log_info("  encoding ", enc, ": ", ncol(dt), " columns, ",
             format(nrow(dt), big.mark = " "), " rows, ",
             round(100 * score, 3), "% invalid UTF-8")

    if (score < best_score) {
      best <- dt
      best_score <- score
    }
    if (score == 0) break   # clean read, no need to try the remaining encodings
  }

  if (is.null(best)) fail("Could not read ", path, " with any configured encoding")
  if (best_score > 0) {
    log_warn("No encoding produced clean text for ", basename(path),
             "; kept the best candidate (", round(100 * best_score, 3),
             "% invalid cells, repaired below)")
  }
  best
}


# -----------------------------------------------------------------------------
# Column-level cleaning
# -----------------------------------------------------------------------------

#' Normalise header names: strip a UTF-8 BOM, trim, upper case.
clean_column_names <- function(dt) {
  nm <- names(dt)
  nm[1] <- sub("^\ufeff", "", nm[1])
  nm <- toupper(trimws(nm))
  data.table::setnames(dt, nm)
  dt
}


#' Parse the configured date columns as Date (ymd), leaving unparseable values
#' as NA. Warnings from lubridate are expected for empty cells and suppressed.
clean_dates <- function(dt, cfg) {
  cols <- intersect(unlist(cfg$ingest$date_columns), names(dt))
  for (cl in cols) {
    dt[[cl]] <- suppressWarnings(lubridate::ymd(dt[[cl]]))
  }
  dt
}


#' Parse the configured numeric columns, tolerating thousands separators and
#' comma decimal marks.
#'
#' Note that no diagnosis or procedure column is ever passed through here.
clean_numerics <- function(dt, cfg) {
  cols <- intersect(unlist(cfg$ingest$numeric_columns), names(dt))
  for (cl in cols) {
    x <- dt[[cl]]
    x[x %in% c("", " ")] <- NA_character_
    x <- gsub("[^0-9,.-]", "", x)
    x <- gsub(",", ".", x, fixed = TRUE)
    dt[[cl]] <- suppressWarnings(as.numeric(x))
  }
  dt
}


#' Repair invalid UTF-8, trim and upper-case every remaining character column.
clean_text <- function(dt) {
  char_cols <- names(dt)[vapply(dt, is.character, logical(1))]
  for (cl in char_cols) {
    x <- dt[[cl]]
    bad <- !validUTF8(x)
    bad[is.na(bad)] <- FALSE
    if (any(bad)) {
      x[bad] <- iconv(x[bad], from = "latin1", to = "UTF-8", sub = "byte")
    }
    dt[[cl]] <- toupper(trimws(x))
  }
  dt
}


# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------

years <- unlist(cfg$ingest$years)
flow <- data.frame(year = integer(0), n_rows = numeric(0), n_cols = integer(0))

for (year in years) {
  fname <- gsub("{year}", year, cfg$ingest$file_pattern, fixed = TRUE)
  path <- cfg_path(cfg, "raw_grd", fname)

  if (!file.exists(path)) {
    fail("Missing raw file: ", path, "\n",
         "Download the yearly DRG files from https://datosabiertos.fonasa.cl ",
         "and place them in ", cfg$paths$raw_grd)
  }

  log_info("Reading ", fname, " (",
           round(file.info(path)$size / 1024^3, 2), " GB)")

  dt <- read_grd_file(path, cfg)
  dt <- clean_column_names(dt)
  dt <- clean_dates(dt, cfg)
  dt <- clean_numerics(dt, cfg)
  dt <- clean_text(dt)

  # Deterministic identity of every discharge: the year plus its position in the
  # source file. Step 2 collapses this into a single integer RECORD_ID.
  dt[, SOURCE_YEAR := as.integer(year)]
  dt[, ROW_IN_FILE := seq_len(.N)]

  out_path <- cfg_path(cfg, "interim", sprintf("grd_%d.parquet", year))
  arrow::write_parquet(dt, out_path, compression = "zstd")

  log_info("  wrote ", basename(out_path), ": ",
           format(nrow(dt), big.mark = " "), " rows x ", ncol(dt), " columns")

  flow <- rbind(flow, data.frame(
    year = as.integer(year), n_rows = nrow(dt), n_cols = ncol(dt)
  ))

  rm(dt)
  invisible(gc())
}

write_csv_utf8(flow, cfg_path(cfg, "tables", "ingest_summary.csv"))

record_flow_append(
  cfg, "01_raw_ingested", sum(flow$n_rows),
  paste0("union of ", nrow(flow), " yearly files, before cleaning")
)

log_info("Total rows ingested: ", format(sum(flow$n_rows), big.mark = " "))
save_run_metadata(cfg, "01_ingest_grd", c("data.table", "lubridate", "arrow"))
log_end()
