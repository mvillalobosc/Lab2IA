# =============================================================================
# R/lib_learners.R
#
# The three feature selection models behind a single interface, plus the
# cross-validation harness that evaluates them.
#
# A learner is a list with four elements:
#
#   name                     short identifier used in the output files
#   fit(X, y, seed)          returns a fitted model, or NULL on failure
#   predict(model, Xnew)     returns P(y = "case") for each row of Xnew
#   selected(model, X, y)    returns the names of the columns the model selected
#
# Keeping the interface identical for the three models is what makes the
# comparison fair: the same resample, the same folds, the same metric code. In
# the original scripts each model was trained through its own caret call with its
# own internal resampling, so a difference between models could come from the
# model or from the harness, and there was no way to tell which.
#
# The label convention is fixed everywhere: y is a factor with levels
# c("control", "case") and "case" is the positive class. glmnet and ranger both
# treat the last factor level as the event of interest, which is why the order
# matters and is not alphabetical by accident.
# =============================================================================


# -----------------------------------------------------------------------------
# Selection rules
#
# The consensus index of step 8 averages the per-model selection frequency of
# each feature, so a model whose rule marks almost every column as selected
# contributes a frequency near 1 for everything and adds no information.
#
# That is not hypothetical. With a Random Forest of 500 trees on 200 rows, the
# impurity importance of essentially every column is strictly positive, so
# "importance > 0" selects all of them. caret's univariate ROC filter, which is
# what varImp() falls back to for KNN, returns the larger of AUC and 1 - AUC and
# is therefore never below 0.5, so "AUC > 0.5" also selects almost everything.
#
# A non-zero Lasso coefficient is a genuine subset, so the Lasso needs no rule.
# For the other two the default is a rank rule: a feature counts as selected in a
# resample when it is among that model's top k by importance. The frequency then
# measures how often a feature reaches the top of the ranking, which is
# comparable across models and is the usual stability-selection reading.
# -----------------------------------------------------------------------------

#' Names of the k highest scores, ties broken by name for determinism.
top_k_names <- function(score, k) {
  score <- score[is.finite(score)]
  if (length(score) == 0L) return(character(0))
  k <- min(as.integer(k), length(score))
  ord <- order(-score, names(score))
  names(score)[ord[seq_len(k)]]
}


#' Resolve the number of features a rank rule should keep.
resolve_top_k <- function(cfg, model_cfg) {
  as.integer(model_cfg$top_k %||% cfg$consensus$top_n_features %||% 30L)
}


# -----------------------------------------------------------------------------
# Lasso-penalised logistic regression (glmnet)
# -----------------------------------------------------------------------------

#' @param cfg configuration list; uses models$lasso.
learner_lasso <- function(cfg) {
  require_pkgs("glmnet", attach = FALSE)
  criterion <- cfg$models$lasso$lambda_criterion %||% "lambda.1se"
  nlambda <- as.integer(cfg$models$lasso$n_lambda %||% 100L)
  nfolds <- as.integer(cfg$resampling$cv_folds %||% 10L)
  rule <- cfg$models$lasso$selection_rule %||% "nonzero"
  top_k <- resolve_top_k(cfg, cfg$models$lasso)

  list(
    name = "lasso",

    fit = function(X, y, seed) {
      # cv.glmnet runs its own internal cross-validation to choose lambda. That
      # inner loop only selects the penalty; the outer folds handled by
      # cv_out_of_fold() are what produce the reported metrics.
      set.seed(seed)
      tryCatch(
        glmnet::cv.glmnet(
          x = as.matrix(X),
          y = y,
          family = "binomial",
          alpha = 1,                     # 1 = pure Lasso
          nlambda = nlambda,
          nfolds = min(nfolds, floor(length(y) / 2)),
          type.measure = "deviance"
        ),
        error = function(e) NULL
      )
    },

    predict = function(model, Xnew) {
      if (is.null(model)) return(rep(NA_real_, nrow(Xnew)))
      as.numeric(stats::predict(model, newx = as.matrix(Xnew),
                                s = criterion, type = "response"))
    },

    selected = function(model, X, y) {
      if (is.null(model)) return(character(0))
      cf <- as.matrix(stats::coef(model, s = criterion))
      nm <- rownames(cf)
      beta <- stats::setNames(as.numeric(cf[, 1]), nm)
      beta <- beta[nm != "(Intercept)"]

      if (identical(rule, "top_k")) {
        # Ranked by standardised effect, |beta| times the standard deviation of
        # the predictor. Ranking raw |beta| would put a coefficient on age, a
        # variable measured in years, on the same scale as a 0/1 indicator.
        sds <- apply(X[, names(beta), drop = FALSE], 2, stats::sd)
        return(top_k_names(abs(beta) * sds, top_k))
      }
      names(beta)[abs(beta) > 0]
    }
  )
}


# -----------------------------------------------------------------------------
# Random Forest (ranger)
# -----------------------------------------------------------------------------

#' @param cfg configuration list; uses models$random_forest.
learner_rf <- function(cfg) {
  require_pkgs("ranger", attach = FALSE)
  num_trees <- as.integer(cfg$models$random_forest$num_trees %||% 500L)
  mtry_cfg <- cfg$models$random_forest$mtry
  min_node <- as.integer(cfg$models$random_forest$min_node_size %||% 1L)
  rule <- cfg$models$random_forest$selection_rule %||% "top_k"
  top_k <- resolve_top_k(cfg, cfg$models$random_forest)

  list(
    name = "random_forest",

    fit = function(X, y, seed) {
      # mtry = sqrt(p) is the default reported in the manuscript.
      mtry <- if (is.null(mtry_cfg)) max(1L, floor(sqrt(ncol(X)))) else as.integer(mtry_cfg)
      tryCatch(
        ranger::ranger(
          x = X,
          y = y,
          num.trees = num_trees,
          mtry = min(mtry, ncol(X)),
          min.node.size = min_node,
          importance = "impurity",
          probability = TRUE,            # class probabilities, not votes
          seed = seed,
          num.threads = 1,               # one thread: reproducible given the seed
          verbose = FALSE
        ),
        error = function(e) NULL
      )
    },

    predict = function(model, Xnew) {
      if (is.null(model)) return(rep(NA_real_, nrow(Xnew)))
      pr <- stats::predict(model, data = Xnew, num.threads = 1)$predictions
      if (is.matrix(pr) && "case" %in% colnames(pr)) pr[, "case"] else as.numeric(pr)
    },

    selected = function(model, X, y) {
      if (is.null(model)) return(character(0))
      imp <- model$variable.importance
      if (is.null(imp) || length(imp) == 0L) return(character(0))
      imp <- imp[is.finite(imp)]

      # "positive" is kept only for reference: with 500 trees the impurity
      # importance of almost every column is above zero, so it selects nearly
      # the whole design and makes the selection frequency uninformative.
      if (identical(rule, "positive")) return(names(imp)[imp > 0])
      if (identical(rule, "above_mean")) return(names(imp)[imp > mean(imp)])
      top_k_names(imp, top_k)
    }
  )
}


# -----------------------------------------------------------------------------
# K-nearest neighbours (caret::knn3 on standardised predictors)
# -----------------------------------------------------------------------------

#' @param cfg configuration list; uses models$knn.
#' @param k number of neighbours. Fixed per scenario by step 7.
learner_knn <- function(cfg, k) {
  require_pkgs("caret", attach = FALSE)
  rule <- cfg$models$knn$selection_rule %||% "top_k"
  auc_threshold <- as.numeric(cfg$models$knn$auc_threshold %||% 0.55)
  top_k <- resolve_top_k(cfg, cfg$models$knn)

  list(
    name = "knn",
    k = k,

    fit = function(X, y, seed) {
      # Centre and scale using the training rows only. Columns with zero
      # variance would divide by zero, so their scale is forced to 1, which
      # leaves them at a constant zero and makes them irrelevant to the
      # Euclidean distance.
      centre <- colMeans(X)
      scale_ <- apply(X, 2, stats::sd)
      scale_[!is.finite(scale_) | scale_ == 0] <- 1

      Xs <- scale(as.matrix(X), center = centre, scale = scale_)
      k_eff <- max(1L, min(as.integer(k), floor(length(y) / 2)))

      fit <- tryCatch(caret::knn3(x = Xs, y = y, k = k_eff), error = function(e) NULL)
      if (is.null(fit)) return(NULL)
      list(fit = fit, centre = centre, scale = scale_, k = k_eff)
    },

    predict = function(model, Xnew) {
      if (is.null(model)) return(rep(NA_real_, nrow(Xnew)))
      Xs <- scale(as.matrix(Xnew), center = model$centre, scale = model$scale)
      pr <- stats::predict(model$fit, Xs, type = "prob")
      if (is.matrix(pr) && "case" %in% colnames(pr)) pr[, "case"] else as.numeric(pr)
    },

    selected = function(model, X, y) {
      if (is.null(model)) return(character(0))

      if (identical(rule, "all_retained")) {
        # Reproduces the published run: every column that survived the
        # near-zero-variance filter counts as selected, because the original
        # script recorded rownames(varImp(...)$importance) without looking at the
        # values. In the delivered frequency files this puts dozens of features
        # at exactly 500 out of 500. See README.
        return(colnames(X))
      }

      # KNN has no intrinsic variable importance, so caret derives one from a
      # univariate ROC filter: the AUC of each predictor taken alone. Note that
      # caret reports the larger of AUC and 1 - AUC, so the score never falls
      # below 0.5 and a 0.5 cut-off would select almost everything.
      imp <- tryCatch(caret::filterVarImp(x = as.data.frame(X), y = y),
                      error = function(e) NULL)
      if (is.null(imp)) return(character(0))
      score <- suppressWarnings(apply(as.matrix(imp), 1, max, na.rm = TRUE))
      names(score) <- rownames(imp)

      if (identical(rule, "auc_above")) {
        return(names(score)[is.finite(score) & score > auc_threshold])
      }
      top_k_names(score, top_k)
    }
  )
}


# -----------------------------------------------------------------------------
# Cross-validation harness
# -----------------------------------------------------------------------------

#' Pooled out-of-fold probabilities for one learner on one resample.
#'
#' Every observation is predicted exactly once, by a model that never saw it.
#' Pooling the predictions before computing the metrics is more stable than
#' averaging per-fold metrics, and it makes precision and F1 well defined even
#' when a single fold happens to contain no predicted positive.
#'
#' @return numeric vector of probabilities, one per row of X, or NULL if the
#'   learner failed on every fold.
cv_out_of_fold <- function(learner, X, y, folds, seed) {
  prob <- rep(NA_real_, nrow(X))
  n_ok <- 0L

  for (f in sort(unique(folds))) {
    test <- which(folds == f)
    train <- which(folds != f)

    # A fold with a single class in the training part cannot be fitted.
    if (length(unique(y[train])) < 2L) next

    model <- learner$fit(X[train, , drop = FALSE], y[train], seed + f)
    if (is.null(model)) next

    prob[test] <- learner$predict(model, X[test, , drop = FALSE])
    n_ok <- n_ok + 1L
  }

  if (n_ok == 0L) return(NULL)
  prob
}


#' Evaluate one learner on one resample: metrics plus selected features.
#'
#' @return list(metrics = named numeric vector, selected = character vector,
#'   n_folds_used = integer)
evaluate_learner <- function(learner, X, y, folds, seed) {
  prob <- cv_out_of_fold(learner, X, y, folds, seed)

  metrics <- if (is.null(prob)) {
    c(precision = NA_real_, sensitivity = NA_real_, f1 = NA_real_,
      accuracy = NA_real_, auc = NA_real_)
  } else {
    classification_metrics(y, prob)
  }

  # Selection uses a model fitted on the whole resample, which is the same
  # convention caret follows for its final model.
  full <- learner$fit(X, y, seed)
  selected <- if (is.null(full)) character(0) else learner$selected(full, X, y)

  list(metrics = metrics, selected = selected)
}
