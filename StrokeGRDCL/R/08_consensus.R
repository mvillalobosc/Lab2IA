# =============================================================================
# R/08_consensus.R
#
# STEP 8 - Consensus index, final class-weighted Lasso and SHAP values.
#
# Input : results/selection/frequency_<scenario>.csv   (step 7)
#         data/processed/model_matrix.parquet          (step 6)
# Output: results/tables/consensus_<scenario>.csv
#         results/tables/consensus_all_scenarios.csv
#         results/tables/shap_summary_<scenario>.csv
#         results/final_model/<scenario>_coefficients.csv
#         results/final_model/<scenario>_shap_values.csv
#
# Usage
#   Rscript R/08_consensus.R                    all scenarios
#   Rscript R/08_consensus.R D1_ACV_GENERAL     one scenario
#
# Three products:
#
#   Consensus. For every scenario the selection frequency of each feature is
#   averaged across the three models. The mean of the three frequencies is the
#   consensus index, and the top consensus$top_n_features are retained.
#
#   Final model. A Lasso-penalised logistic regression is fitted on the whole
#   development subset, restricted to the consensus features, with class weights
#   that compensate the natural imbalance.
#
#   SHAP. Because the final model is linear, its SHAP values are exact and closed
#   form: the contribution of feature j to record i is beta_j * (x_ij - E[x_j]),
#   on the log-odds scale. R/lib_shap.R computes them and verifies that the
#   contributions add up to the linear predictor before anything is written. Step
#   9 draws the figures from the same values.
#
# Note on the class weights
#   Inside the 500 balanced resamples of step 7 the classes have equal size, so
#   weighting there would do nothing. It matters only here, where the fit uses the
#   development subset as it is: a few tens of thousands of stroke records against
#   several million others.
# =============================================================================

source("R/utils.R")
source("R/lib_shap.R")

cfg <- load_config()
require_pkgs("glmnet", attach = FALSE)

log_start(cfg, "08_consensus")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

matrix_path <- cfg_path(cfg, "processed", "model_matrix.parquet")
if (!file.exists(matrix_path)) {
  fail("Missing step 6 output: ", matrix_path)
}
db_exec(con, sprintf("CREATE OR REPLACE VIEW model_matrix AS SELECT * FROM read_parquet('%s')",
                     sql_path(matrix_path)))

scen <- scenario_table(cfg)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0L) {
  keep <- scen$name %in% args
  if (!any(keep)) fail("Unknown scenario(s): ", paste(args, collapse = ", "))
  scen <- scen[keep, , drop = FALSE]
}

top_n <- as.integer(cfg$consensus$top_n_features)
max_rows <- as.numeric(cfg$consensus$final_fit_max_rows)
shap_rows <- as.integer(cfg$consensus$shap_sample_rows)
lambda_criterion <- cfg$models$lasso$lambda_criterion %||% "lambda.1se"

consensus_all <- list()


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

#' Consensus table for one scenario.
#'
#' The consensus index is the plain mean of the per-model selection frequencies.
#' A feature that a model never saw (because the near-zero-variance filter
#' removed it from every resample) contributes a frequency of zero, not a missing
#' value: it was available to the workflow and was not selected.
build_consensus <- function(freq, models_expected) {
  wide <- stats::reshape(
    freq[, c("feature", "model", "selection_frequency")],
    idvar = "feature", timevar = "model", direction = "wide"
  )
  names(wide) <- sub("^selection_frequency\\.", "freq_", names(wide))

  for (m in models_expected) {
    cl <- paste0("freq_", m)
    if (!cl %in% names(wide)) wide[[cl]] <- 0
    wide[[cl]][is.na(wide[[cl]])] <- 0
  }

  freq_cols <- paste0("freq_", models_expected)
  wide$consensus_index <- rowMeans(wide[, freq_cols, drop = FALSE])
  wide$n_models_selecting <- rowSums(wide[, freq_cols, drop = FALSE] > 0)

  wide <- wide[order(-wide$consensus_index, wide$feature), ]
  wide$rank <- seq_len(nrow(wide))
  rownames(wide) <- NULL
  wide
}


#' Fetch the development subset restricted to a set of feature columns.
#'
#' Large scenarios are subsampled in a stratified way so the fit stays within
#' final_fit_max_rows. The subsample is deterministic: records are ranked by
#' HASH(RECORD_ID, seed) inside each class, exactly like the 70/30 partition.
fetch_development <- function(con, outcome, features, max_rows, seed) {
  n_avail <- as.numeric(db_scalar(con, sprintf("
    SELECT COUNT(*) FROM model_matrix
    WHERE SPLIT = 'development' AND %s IS NOT NULL
  ", sql_id(outcome))))

  cols <- paste(c("RECORD_ID", sprintf("CAST(%s AS INTEGER) AS Y", sql_id(outcome)),
                  sql_id(features)), collapse = ", ")

  if (n_avail <= max_rows) {
    return(db_get(con, sprintf("
      SELECT %s FROM model_matrix
      WHERE SPLIT = 'development' AND %s IS NOT NULL
    ", cols, sql_id(outcome))))
  }

  # Keep every case and take a deterministic share of the controls, so that the
  # rare class is never thinned.
  db_get(con, sprintf("
    WITH pool AS (
      SELECT %s,
             HASH(CAST(RECORD_ID AS VARCHAR) || '_' || CAST(%d AS VARCHAR)) AS H
      FROM model_matrix
      WHERE SPLIT = 'development' AND %s IS NOT NULL
    ),
    ranked AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY Y ORDER BY H, RECORD_ID) AS RN,
                COUNT(*)     OVER (PARTITION BY Y)                       AS N_CLASS
      FROM pool
    )
    SELECT * EXCLUDE (H, RN, N_CLASS)
    FROM ranked
    WHERE Y = 1 OR RN <= CAST(FLOOR(N_CLASS * %.10f) AS BIGINT)
  ", cols, seed, sql_id(outcome), min(1, max_rows / n_avail)))
}


# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------

for (s in seq_len(nrow(scen))) {
  outcome <- scen$name[s]
  label <- scen$label[s]

  log_info(strrep("-", 78))
  log_info("Scenario ", s, "/", nrow(scen), ": ", outcome)

  freq_path <- cfg_path(cfg, "selection", paste0("frequency_", outcome, ".csv"))
  if (!file.exists(freq_path)) {
    log_warn("  no step 7 output for this scenario; skipped (", basename(freq_path), ")")
    next
  }

  freq <- read_csv_utf8(freq_path)
  models_present <- sort(unique(freq$model))
  log_info("  models with selection output: ", paste(models_present, collapse = ", "))

  # --- consensus -------------------------------------------------------------
  cons <- build_consensus(freq, models_present)
  cons$scenario <- outcome
  cons$label <- label

  write_csv_utf8(cons, cfg_path(cfg, "tables", paste0("consensus_", outcome, ".csv")))
  consensus_all[[outcome]] <- cons[cons$rank <= top_n, ]

  top_features <- cons$feature[cons$rank <= top_n]
  log_info("  top ", length(top_features), " consensus features, index from ",
           round(max(cons$consensus_index), 3), " down to ",
           round(cons$consensus_index[min(top_n, nrow(cons))], 3))
  log_info("  first five: ", paste(utils::head(top_features, 5), collapse = ", "))

  # --- final class-weighted Lasso -------------------------------------------
  dev <- fetch_development(con, outcome, top_features,
                           max_rows, as.integer(cfg$split$seed))
  y_int <- as.integer(dev$Y)
  X <- as.matrix(dev[, top_features, drop = FALSE])
  storage.mode(X) <- "double"

  # Columns that are constant in the development subset carry no information and
  # break the standardisation inside glmnet.
  sds <- apply(X, 2, stats::sd)
  keep <- is.finite(sds) & sds > 0
  if (any(!keep)) {
    log_warn("  dropping ", sum(!keep), " constant column(s) from the final fit: ",
             paste(colnames(X)[!keep], collapse = ", "))
    X <- X[, keep, drop = FALSE]
  }

  n_case <- sum(y_int == 1L)
  n_ctrl <- sum(y_int == 0L)
  log_info("  final fit on ", format(nrow(X), big.mark = " "), " records (",
           format(n_case, big.mark = " "), " cases / ",
           format(n_ctrl, big.mark = " "), " controls), ",
           ncol(X), " features")

  if (n_case < 2L || n_ctrl < 2L) {
    log_warn("  not enough records in one class; final fit skipped")
    next
  }

  # Class weights: each class receives half of the total weight, so neither side
  # dominates the likelihood.
  w <- ifelse(y_int == 1L, nrow(X) / (2 * n_case), nrow(X) / (2 * n_ctrl))
  y_fac <- factor(ifelse(y_int == 1L, "case", "control"), levels = c("control", "case"))

  set.seed(as.integer(cfg$resampling$seed))
  fit <- glmnet::cv.glmnet(
    x = X, y = y_fac, family = "binomial", alpha = 1,
    weights = w,
    nfolds = as.integer(cfg$resampling$cv_folds),
    type.measure = "deviance"
  )

  cf <- as.matrix(stats::coef(fit, s = lambda_criterion))
  lambda_used <- if (identical(lambda_criterion, "lambda.min")) fit$lambda.min else fit$lambda.1se

  # Background means: the expectation used by the SHAP decomposition. They come
  # from the same rows the model was fitted on, which is what makes the
  # contributions add up to the predicted log-odds.
  feature_means <- colMeans(X)

  coefs <- data.frame(
    scenario = outcome,
    feature = rownames(cf),
    coefficient = as.numeric(cf[, 1]),
    stringsAsFactors = FALSE
  )
  coefs$background_mean <- feature_means[coefs$feature]
  coefs$background_mean[coefs$feature == "(Intercept)"] <- NA_real_
  coefs$consensus_index <- cons$consensus_index[match(coefs$feature, cons$feature)]
  coefs$consensus_rank <- cons$rank[match(coefs$feature, cons$feature)]
  coefs$lambda <- lambda_used
  coefs$lambda_criterion <- lambda_criterion
  coefs$n_records_fit <- nrow(X)
  coefs$n_cases_fit <- n_case

  write_csv_utf8(coefs, cfg_path(cfg, "final_model",
                                 paste0(outcome, "_coefficients.csv")))

  n_nonzero <- sum(coefs$coefficient != 0 & coefs$feature != "(Intercept)")
  log_info("  lambda (", lambda_criterion, ") = ", signif(lambda_used, 4),
           ", non-zero coefficients: ", n_nonzero, "/", ncol(X))

  # --- SHAP values -----------------------------------------------------------
  # Features with a zero coefficient contribute nothing by construction, so only
  # the ones the model actually uses are carried forward.
  intercept <- coefs$coefficient[coefs$feature == "(Intercept)"][1]
  used <- coefs[coefs$feature != "(Intercept)" & coefs$coefficient != 0, ]

  if (nrow(used) == 0L) {
    log_warn("  every coefficient is zero; no SHAP values to compute")
    rm(dev, X)
    invisible(gc(verbose = FALSE))
    next
  }

  beta <- stats::setNames(used$coefficient, used$feature)
  background <- stats::setNames(used$background_mean, used$feature)

  # A balanced sample keeps both classes visible in the SHAP distributions
  # without making the output file large.
  set.seed(as.integer(cfg$resampling$seed) + 7L)
  half <- max(1L, floor(shap_rows / 2))
  n_case_take <- min(half, n_case)
  idx <- c(sample(which(y_int == 1L), n_case_take),
           sample(which(y_int == 0L), min(shap_rows - n_case_take, n_ctrl)))

  X_shap <- X[idx, , drop = FALSE]
  sh <- linear_shap(X_shap, beta, background, intercept)

  shap_out <- data.frame(
    RECORD_ID = dev$RECORD_ID[idx],
    Y = y_int[idx],
    base_value = sh$base,
    linear_predictor = sh$linear_predictor,
    stringsAsFactors = FALSE
  )
  shap_out <- cbind(shap_out, as.data.frame(sh$phi))
  write_csv_utf8(shap_out, cfg_path(cfg, "final_model",
                                    paste0(outcome, "_shap_values.csv")))

  # The feature values themselves are kept alongside, because the figures need to
  # know whether a record sits high or low on each feature.
  values_out <- data.frame(RECORD_ID = dev$RECORD_ID[idx], Y = y_int[idx])
  values_out <- cbind(values_out, as.data.frame(X_shap[, sh$features, drop = FALSE]))
  write_csv_utf8(values_out, cfg_path(cfg, "final_model",
                                      paste0(outcome, "_shap_features.csv")))

  summ <- shap_summary(sh$phi, X_shap, beta, background)
  summ$scenario <- outcome
  summ <- summ[, c("scenario", setdiff(names(summ), "scenario"))]
  write_csv_utf8(summ, cfg_path(cfg, "tables", paste0("shap_summary_", outcome, ".csv")))

  log_info("  SHAP on ", nrow(X_shap), " records, base value ", round(sh$base, 4),
           ", additivity error ", format(sh$max_error, scientific = TRUE, digits = 2))
  log_info("  top five by mean |SHAP|: ",
           paste(utils::head(summ$feature, 5), collapse = ", "))

  rm(dev, X)
  invisible(gc(verbose = FALSE))
}


# -----------------------------------------------------------------------------
# Combined consensus table
# -----------------------------------------------------------------------------

if (length(consensus_all) > 0L) {
  combined <- do.call(rbind, lapply(consensus_all, function(d) {
    d[, c("scenario", "label", "rank", "feature", "consensus_index",
          "n_models_selecting", grep("^freq_", names(d), value = TRUE))]
  }))
  rownames(combined) <- NULL

  out_path <- cfg_path(cfg, "tables", "consensus_all_scenarios.csv")
  if (file.exists(out_path)) {
    prev <- read_csv_utf8(out_path)
    prev <- prev[!prev$scenario %in% unique(combined$scenario), ]
    if (nrow(prev) > 0L && identical(sort(names(prev)), sort(names(combined)))) {
      combined <- rbind(prev[, names(combined)], combined)
    }
  }
  write_csv_utf8(combined, out_path)
  log_info("Combined consensus table: ", nrow(combined), " rows across ",
           length(unique(combined$scenario)), " scenarios")
}

save_run_metadata(cfg, "08_consensus", "glmnet")
log_end()
