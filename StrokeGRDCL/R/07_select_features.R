# =============================================================================
# R/07_select_features.R
#
# STEP 7 - Balanced resampling and multimodel feature selection.
#
# Input : data/processed/model_matrix.parquet       (step 6)
#         results/tables/model_matrix_columns.csv   (step 6)
# Output: results/selection/metrics_<scenario>.csv      500 rows per model
#         results/selection/frequency_<scenario>.csv    selection frequencies
#         results/tables/knn_k_by_scenario.csv          chosen k per scenario
#
# Usage
#   Rscript R/07_select_features.R                    all scenarios
#   Rscript R/07_select_features.R D1_ACV_GENERAL     one scenario
#
# For every scenario, and inside the development subset only:
#
#   1. 500 balanced resamples are drawn, each with n_per_class cases and the same
#      number of controls, without replacement inside a resample.
#   2. Columns that are constant or near-constant in the resample are dropped
#      (caret::nearZeroVar), as in the original.
#   3. The three models are fitted on that same resample, with the same
#      stratified 10-fold assignment, and evaluated with the same metric code.
#   4. Metrics come from pooled out-of-fold predictions; the selected feature set
#      comes from a model fitted on the whole resample.
#
# Design decisions worth knowing
#
#   Paired resamples. The three models see exactly the same 500 resamples and the
#   same folds. In the original each model ran its own independent sampling, so
#   part of the difference between models was sampling noise. Pairing removes it.
#
#   Reproducible sampling. The original drew samples with ORDER BY random()
#   inside DuckDB, which set.seed() in R does not control, so the resamples could
#   not be regenerated. Here every draw comes from R's RNG with an explicit
#   per-replicate seed, and the same seed gives the same 500 resamples.
#
#   One database read per scenario. All 500 resamples are drawn first, then the
#   union of the rows they need is fetched in a single query and kept in memory.
#   The original re-queried a 5.8-million-row table for every replicate, which is
#   most of the 26 seconds per iteration visible in the published output files.
#
#   Two selection frequencies are reported. A feature that the near-zero-variance
#   filter removed from a resample was never offered to the models in that
#   resample, so dividing by the number of resamples and dividing by the number
#   of resamples in which the feature was actually present are different
#   quantities. Both are written out; the consensus in step 8 uses the first,
#   which is the definition the manuscript describes.
# =============================================================================

source("R/utils.R")
source("R/lib_learners.R")

cfg <- load_config()
require_pkgs("caret", attach = FALSE)

log_start(cfg, "07_select_features")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

matrix_path <- cfg_path(cfg, "processed", "model_matrix.parquet")
inventory_path <- cfg_path(cfg, "tables", "model_matrix_columns.csv")
for (p in c(matrix_path, inventory_path)) {
  if (!file.exists(p)) fail("Missing step 6 output: ", p,
                            "\nRun: Rscript R/06_build_model_matrix.R")
}

db_exec(con, sprintf("CREATE OR REPLACE VIEW model_matrix AS SELECT * FROM read_parquet('%s')",
                     sql_path(matrix_path)))

inventory <- read_csv_utf8(inventory_path)
feature_cols <- inventory$column[inventory$type %in%
                                   c("derived", "code_indicator", "comuna_dummy")]
log_info("Candidate features: ", length(feature_cols))

# Optional scenario filter from the command line.
args <- commandArgs(trailingOnly = TRUE)
scen <- scenario_table(cfg)
if (length(args) > 0L) {
  keep <- scen$name %in% args
  if (!any(keep)) {
    fail("Unknown scenario(s): ", paste(args, collapse = ", "),
         "\nAvailable: ", paste(scen$name, collapse = ", "))
  }
  scen <- scen[keep, , drop = FALSE]
}
log_info("Scenarios to run: ", nrow(scen))

n_reps <- as.integer(cfg$resampling$n_replicates)
n_per_class <- as.integer(cfg$resampling$n_per_class)
n_folds <- as.integer(cfg$resampling$cv_folds)
base_seed <- as.integer(cfg$resampling$seed)
drop_nzv <- isTRUE(cfg$resampling$drop_near_zero_variance)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

#' Record identifiers and labels of one scenario, restricted to the development
#' subset. Records whose outcome is NULL are excluded: for the
#' haemorrhagic-versus-ischaemic contrast they are the discharges that are
#' neither, and they are not comparable.
scenario_ids <- function(con, outcome) {
  db_get(con, sprintf("
    SELECT RECORD_ID, CAST(%s AS INTEGER) AS Y
    FROM model_matrix
    WHERE SPLIT = 'development' AND %s IS NOT NULL
  ", sql_id(outcome), sql_id(outcome)))
}


#' Draw the identifiers of all replicates up front.
#'
#' @return list of length n_reps, each element an integer vector of
#'   2 * n_per_class record identifiers.
draw_replicates <- function(case_ids, control_ids, n_reps, n_per_class, base_seed) {
  lapply(seq_len(n_reps), function(rep) {
    set.seed(base_seed + rep)
    c(sample(case_ids, min(n_per_class, length(case_ids))),
      sample(control_ids, min(n_per_class, length(control_ids))))
  })
}


#' Fetch a set of records from the model matrix in one query.
#'
#' @return list(X = numeric matrix of feature columns, ids = record identifiers)
fetch_rows <- function(con, ids, feature_cols) {
  # Dropping first is more portable than combining temporary and overwrite in a
  # single dbWriteTable call.
  db_exec(con, "DROP TABLE IF EXISTS sample_ids")
  DBI::dbWriteTable(
    con, "sample_ids",
    data.frame(RECORD_ID = as.integer(ids)),
    temporary = TRUE
  )
  cols <- paste(c("m.RECORD_ID", sprintf("m.%s", sql_id(feature_cols))), collapse = ", ")
  df <- db_get(con, sprintf("
    SELECT %s
    FROM model_matrix AS m
    JOIN sample_ids AS s ON s.RECORD_ID = m.RECORD_ID
  ", cols))

  ids_out <- as.integer(df$RECORD_ID)
  X <- as.matrix(df[, feature_cols, drop = FALSE])
  storage.mode(X) <- "double"
  rownames(X) <- as.character(ids_out)
  rm(df)
  invisible(gc(verbose = FALSE))
  list(X = X, ids = ids_out)
}


#' Prepare the design of one resample: drop unusable columns.
#'
#' Columns with any missing value are dropped, then near-zero-variance columns,
#' both inside the resample. This mirrors the original preparar_datos().
prepare_design <- function(X_rows, drop_nzv) {
  keep <- colSums(is.na(X_rows)) == 0
  X_rows <- X_rows[, keep, drop = FALSE]
  if (ncol(X_rows) < 2L) return(NULL)

  if (drop_nzv) {
    nzv <- caret::nearZeroVar(X_rows)
    if (length(nzv) > 0L) X_rows <- X_rows[, -nzv, drop = FALSE]
  }
  if (ncol(X_rows) < 2L) return(NULL)
  X_rows
}


#' Choose k once per scenario, on a larger balanced sample.
#'
#' The k with the highest pooled out-of-fold AUC wins. Holding k fixed across the
#' 500 replicates keeps the selection frequencies comparable; retuning inside
#' every replicate would mean the reported frequencies mix different models.
tune_knn_k <- function(con, cfg, case_ids, control_ids, feature_cols, base_seed) {
  k_grid <- as.integer(unlist(cfg$models$knn$k_grid))
  n_tune <- as.integer(cfg$models$knn$tuning_n_per_class %||% 1000L)

  # Cases first, then controls, so the labels are known by position and no
  # lookup table is needed.
  n_case <- min(n_tune, length(case_ids))
  n_ctrl <- min(n_tune, length(control_ids))
  set.seed(base_seed - 1L)
  ids <- c(sample(case_ids, n_case), sample(control_ids, n_ctrl))
  y <- factor(rep(c("case", "control"), c(n_case, n_ctrl)),
              levels = c("control", "case"))

  rows <- fetch_rows(con, ids, feature_cols)
  ord <- match(ids, rows$ids)
  X <- prepare_design(rows$X[ord, , drop = FALSE], isTRUE(cfg$resampling$drop_near_zero_variance))
  if (is.null(X)) {
    log_warn("  k tuning impossible (no usable columns); falling back to k = ", k_grid[1])
    return(list(k = k_grid[1], auc = NA_real_, n = length(ids)))
  }

  folds <- stratified_folds(y, as.integer(cfg$resampling$cv_folds), base_seed - 1L)

  aucs <- vapply(k_grid, function(k) {
    prob <- cv_out_of_fold(learner_knn(cfg, k), X, y, folds, base_seed - 1L)
    if (is.null(prob)) NA_real_ else auc_roc(y, prob)
  }, numeric(1))

  best <- if (all(is.na(aucs))) 1L else which.max(aucs)
  log_info("  k tuning on ", length(ids), " rows: ",
           paste(sprintf("k=%d AUC=%.3f", k_grid, aucs), collapse = ", "))
  log_info("  k fixed at ", k_grid[best])
  list(k = k_grid[best], auc = aucs[best], n = length(ids))
}


# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------

k_records <- data.frame()

for (s in seq_len(nrow(scen))) {
  outcome <- scen$name[s]
  label <- scen$label[s]

  log_info(strrep("-", 78))
  log_info("Scenario ", s, "/", nrow(scen), ": ", outcome, "  (", label, ")")

  ids_df <- scenario_ids(con, outcome)
  case_ids <- ids_df$RECORD_ID[ids_df$Y == 1L]
  control_ids <- ids_df$RECORD_ID[ids_df$Y == 0L]
  log_info("  development pool: ", format(length(case_ids), big.mark = " "),
           " cases / ", format(length(control_ids), big.mark = " "), " controls")

  if (length(case_ids) < 2L || length(control_ids) < 2L) {
    log_warn("  not enough records in one of the classes; scenario skipped")
    next
  }
  if (length(case_ids) < n_per_class) {
    log_warn("  fewer than ", n_per_class, " cases available; resamples will use ",
             length(case_ids), " cases and stay balanced at that size")
  }

  # --- k for KNN -------------------------------------------------------------
  if (identical(cfg$models$knn$tuning, "tuned_once")) {
    tuned <- tune_knn_k(con, cfg, case_ids, control_ids, feature_cols, base_seed)
  } else {
    tuned <- list(k = as.integer(unlist(cfg$models$knn$k_grid))[1], auc = NA_real_, n = NA)
    log_info("  k tuning disabled; using k = ", tuned$k)
  }
  k_records <- rbind(k_records, data.frame(
    scenario = outcome, label = label, k = tuned$k,
    tuning_auc = tuned$auc, tuning_n = tuned$n, stringsAsFactors = FALSE
  ))

  learners <- list(learner_lasso(cfg), learner_rf(cfg), learner_knn(cfg, tuned$k))
  model_names <- vapply(learners, function(l) l$name, character(1))

  # --- resamples -------------------------------------------------------------
  reps <- draw_replicates(case_ids, control_ids, n_reps, n_per_class, base_seed)
  needed <- sort(unique(unlist(reps)))
  log_info("  distinct records needed across ", n_reps, " resamples: ",
           format(length(needed), big.mark = " "),
           " (~", round(length(needed) * length(feature_cols) * 8 / 1024^2), " MB in memory)")

  rows <- fetch_rows(con, needed, feature_cols)
  row_index <- stats::setNames(seq_along(rows$ids), as.character(rows$ids))

  # draw_replicates() always puts the sampled cases first, so the label vector is
  # the same for every replicate and can be built once.
  n_case_draw <- min(n_per_class, length(case_ids))
  n_ctrl_draw <- min(n_per_class, length(control_ids))
  y_rep_template <- factor(
    rep(c("case", "control"), c(n_case_draw, n_ctrl_draw)),
    levels = c("control", "case")
  )

  # --- accumulators ----------------------------------------------------------
  metrics_list <- vector("list", n_reps * length(learners))
  m <- 0L
  sel_count <- lapply(model_names, function(x) stats::setNames(integer(length(feature_cols)), feature_cols))
  names(sel_count) <- model_names
  present_count <- sel_count

  t0 <- Sys.time()

  for (rep in seq_len(n_reps)) {
    ids <- reps[[rep]]
    idx <- row_index[as.character(ids)]
    X_rep <- rows$X[idx, , drop = FALSE]
    y_rep <- y_rep_template

    X_rep <- prepare_design(X_rep, drop_nzv)
    if (is.null(X_rep) || length(unique(y_rep)) < 2L) {
      log_warn("  replicate ", rep, " unusable; skipped")
      next
    }

    folds <- stratified_folds(y_rep, n_folds, base_seed + rep)
    seed_rep <- base_seed + rep * 1000L

    for (l in learners) {
      t_start <- Sys.time()
      res <- evaluate_learner(l, X_rep, y_rep, folds, seed_rep)
      secs <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

      m <- m + 1L
      metrics_list[[m]] <- data.frame(
        scenario = outcome,
        label = label,
        model = l$name,
        replicate = rep,
        k = if (identical(l$name, "knn")) tuned$k else NA_integer_,
        n_features_available = ncol(X_rep),
        n_features_selected = length(res$selected),
        precision = res$metrics[["precision"]],
        sensitivity = res$metrics[["sensitivity"]],
        f1 = res$metrics[["f1"]],
        accuracy = res$metrics[["accuracy"]],
        auc = res$metrics[["auc"]],
        seconds = secs,
        stringsAsFactors = FALSE
      )

      present_count[[l$name]][colnames(X_rep)] <-
        present_count[[l$name]][colnames(X_rep)] + 1L
      hit <- intersect(res$selected, feature_cols)
      if (length(hit) > 0L) {
        sel_count[[l$name]][hit] <- sel_count[[l$name]][hit] + 1L
      }
    }

    if (rep %% 25L == 0L) {
      elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      log_info("  replicate ", rep, "/", n_reps, " - ", round(elapsed, 1),
               " min elapsed, ", round(elapsed / rep * (n_reps - rep), 1), " min left")
    }
  }

  # --- write metrics ---------------------------------------------------------
  metrics <- do.call(rbind, metrics_list[seq_len(m)])
  metrics_path <- cfg_path(cfg, "selection", paste0("metrics_", outcome, ".csv"))
  write_csv_utf8(metrics, metrics_path)

  for (mn in model_names) {
    sub <- metrics[metrics$model == mn, ]
    log_info("  ", mn, ": precision ", round(mean(sub$precision, na.rm = TRUE), 4),
             " | sensitivity ", round(mean(sub$sensitivity, na.rm = TRUE), 4),
             " | F1 ", round(mean(sub$f1, na.rm = TRUE), 4),
             " | accuracy ", round(mean(sub$accuracy, na.rm = TRUE), 4),
             " | AUC ", round(mean(sub$auc, na.rm = TRUE), 4))
  }

  # --- write selection frequencies ------------------------------------------
  freq <- do.call(rbind, lapply(model_names, function(mn) {
    n_rep_model <- sum(metrics$model == mn)
    data.frame(
      scenario = outcome,
      model = mn,
      feature = feature_cols,
      n_selected = as.integer(sel_count[[mn]][feature_cols]),
      n_present = as.integer(present_count[[mn]][feature_cols]),
      n_replicates = n_rep_model,
      selection_frequency = as.numeric(sel_count[[mn]][feature_cols]) / max(n_rep_model, 1L),
      frequency_when_present = ifelse(
        present_count[[mn]][feature_cols] > 0L,
        as.numeric(sel_count[[mn]][feature_cols]) / as.numeric(present_count[[mn]][feature_cols]),
        NA_real_
      ),
      stringsAsFactors = FALSE
    )
  }))
  freq <- freq[freq$n_present > 0L | freq$n_selected > 0L, ]
  write_csv_utf8(freq, cfg_path(cfg, "selection", paste0("frequency_", outcome, ".csv")))

  log_info("  wrote ", nrow(metrics), " metric rows and ", nrow(freq),
           " frequency rows in ",
           round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " minutes")

  rm(rows, reps, X_rep)
  invisible(gc(verbose = FALSE))
}

if (nrow(k_records) > 0L) {
  k_path <- cfg_path(cfg, "tables", "knn_k_by_scenario.csv")
  if (file.exists(k_path)) {
    prev <- read_csv_utf8(k_path)
    k_records <- rbind(prev[!prev$scenario %in% k_records$scenario, ], k_records)
  }
  write_csv_utf8(k_records, k_path)
}

save_run_metadata(cfg, "07_select_features", c("glmnet", "ranger", "caret"))
log_end()
