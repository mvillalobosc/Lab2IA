# =============================================================================
# R/lib_shap.R
#
# Exact SHAP values for the final Lasso-penalised logistic model, and the figures
# built from them (Figure 2 and Supplementary Figures S4 to S11).
#
# Why the values are exact and why no shap package is involved
#   For a model that is linear in its features, the Shapley value of feature j for
#   record i has a closed form:
#
#       phi_ij = beta_j * (x_ij - E[x_j])
#
#   and the contributions add up exactly to the difference between the record's
#   linear predictor and the average linear predictor:
#
#       base + sum_j phi_ij = intercept + sum_j beta_j * x_ij
#
#   where base = intercept + sum_j beta_j * E[x_j]. This is the same quantity a
#   linear explainer returns with an independent-feature background, computed
#   directly from the coefficients and the background means. linear_shap() checks
#   the additivity identity and refuses to return values if it does not hold, so a
#   mistake in the coefficient bookkeeping cannot pass silently.
#
# Scale
#   Everything is on the log-odds scale, which is the scale on which the model is
#   linear. A positive value pushes the record towards the analysed category, a
#   negative value away from it, which is the convention the manuscript uses.
#
# Reading the figures
#   A binary indicator in a linear model can take only two SHAP values,
#   beta*(0 - mean) and beta*(1 - mean), so its row collapses into two thin
#   markers, while a continuous feature such as age spreads into a box and
#   whiskers. The width of a row therefore reflects the value range of the
#   feature, not its importance. The ordering does that.
# =============================================================================

SHAP_TOLERANCE <- 1e-8
SHAP_COLOUR_HIGH <- "#2CA089"   # high feature value
SHAP_COLOUR_LOW <- "#E8B93D"    # low feature value


#' Exact SHAP values of a linear model.
#'
#' @param X numeric matrix of feature values, one row per record.
#' @param beta named numeric vector of coefficients, without the intercept. Only
#'   the names present in X are used.
#' @param background named numeric vector of background means, same names as beta.
#' @param intercept model intercept.
#' @return list(phi = matrix of SHAP values, base = numeric, linear_predictor =
#'   numeric vector, max_error = numeric)
linear_shap <- function(X, beta, background, intercept) {
  features <- intersect(names(beta), colnames(X))
  if (length(features) == 0L) fail("linear_shap(): no coefficient matches a column of X")

  b <- beta[features]
  mu <- background[features]
  if (any(is.na(mu))) {
    fail("linear_shap(): missing background mean for ",
         paste(features[is.na(mu)], collapse = ", "))
  }

  Xf <- X[, features, drop = FALSE]
  storage.mode(Xf) <- "double"

  # phi_ij = beta_j * (x_ij - mean_j)
  phi <- sweep(Xf, 2, mu, FUN = "-")
  phi <- sweep(phi, 2, b, FUN = "*")

  base <- intercept + sum(b * mu)
  linear_predictor <- as.numeric(intercept + Xf %*% b)
  max_error <- max(abs(base + rowSums(phi) - linear_predictor))

  if (!is.finite(max_error) || max_error > SHAP_TOLERANCE) {
    fail("linear_shap(): additivity check failed, maximum error ",
         format(max_error, scientific = TRUE))
  }

  list(phi = phi, base = base, linear_predictor = linear_predictor,
       max_error = max_error, features = features)
}


#' Ranking of features by mean absolute contribution.
#'
#' @param phi matrix of SHAP values.
#' @param X matrix of the feature values they were computed from.
#' @param beta named coefficient vector.
#' @param background named vector of background means.
#' @return data frame ordered by mean_abs_shap, with a rank column and a flag for
#'   features that take only two values.
shap_summary <- function(phi, X, beta, background) {
  features <- colnames(phi)
  Xf <- X[, features, drop = FALSE]

  out <- data.frame(
    feature = features,
    coefficient = as.numeric(beta[features]),
    background_mean = as.numeric(background[features]),
    mean_abs_shap = apply(abs(phi), 2, mean),
    mean_shap = colMeans(phi),
    shap_min = apply(phi, 2, min),
    shap_max = apply(phi, 2, max),
    n_distinct_values = apply(Xf, 2, function(v) length(unique(v))),
    stringsAsFactors = FALSE
  )
  out$is_binary <- out$n_distinct_values <= 2L
  out <- out[order(-out$mean_abs_shap, out$feature), ]
  out$rank <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}


#' Split the records of one feature into a high and a low group.
#'
#' Binary features split at their two observed values. Continuous features split at
#' the median, so both groups always hold roughly half the records.
#'
#' @return character vector of "High feature value" / "Low feature value" / NA.
shap_value_group <- function(values) {
  uniq <- sort(unique(values[!is.na(values)]))
  out <- rep(NA_character_, length(values))
  if (length(uniq) < 2L) return(out)

  if (length(uniq) == 2L) {
    out[values == uniq[2]] <- "High feature value"
    out[values == uniq[1]] <- "Low feature value"
    return(out)
  }
  med <- stats::median(values, na.rm = TRUE)
  out[values >= med] <- "High feature value"
  out[values < med] <- "Low feature value"
  out
}


#' Printable label for a feature column.
#'
#' The optional label table may be keyed either by the exact model-matrix column
#' name (PROC_87_03) or by the bare code (87.03), which is usually easier because
#' the prefix of a column depends on where the code was found during screening.
#' Exact names take precedence. Anything unlisted keeps its raw name, so an
#' incomplete table is harmless.
shap_labels <- function(features, label_table = NULL) {
  out <- features
  if (is.null(label_table) || nrow(label_table) == 0L) return(out)

  exact <- stats::setNames(label_table$label, label_table$feature)
  by_code <- stats::setNames(label_table$label, sanitise_code(strip_feature_prefix(label_table$feature)))

  hit_exact <- features %in% names(exact)
  out[hit_exact] <- exact[features[hit_exact]]

  codes <- sanitise_code(strip_feature_prefix(features))
  hit_code <- !hit_exact & codes %in% names(by_code)
  out[hit_code] <- by_code[codes[hit_code]]
  out
}


#' Drop the provenance prefix of a feature column name.
strip_feature_prefix <- function(x) {
  sub("^(DIAG2_35|DIAG1|PROC|COMUNA|DERIVED)_", "", as.character(x))
}


#' SHAP figure for one scenario, in the manuscript layout.
#'
#' One row per feature, most important at the top, with two box-and-whisker
#' summaries per row: the records where the feature takes a high value and those
#' where it takes a low one.
#'
#' @param phi matrix of SHAP values.
#' @param X matrix of feature values, same rows and columns as phi.
#' @param summary output of shap_summary().
#' @param title figure title.
#' @param top_n features to display.
#' @param label_table optional data frame with the columns feature and label.
#' @return a ggplot object.
shap_plot <- function(phi, X, summary, title, top_n = 10L, label_table = NULL) {
  require_pkgs("ggplot2", attach = TRUE)

  features <- utils::head(summary$feature, top_n)
  features <- features[features %in% colnames(phi)]
  if (length(features) == 0L) return(NULL)

  long <- do.call(rbind, lapply(features, function(f) {
    data.frame(
      feature = f,
      shap = as.numeric(phi[, f]),
      group = shap_value_group(as.numeric(X[, f])),
      stringsAsFactors = FALSE
    )
  }))
  long <- long[!is.na(long$group), ]

  # Reversed so that coord_flip() puts the most important feature at the top.
  labels <- shap_labels(features, label_table)
  long$feature <- factor(long$feature, levels = rev(features), labels = rev(labels))
  long$group <- factor(long$group,
                       levels = c("High feature value", "Low feature value"))

  ggplot(long, aes(x = feature, y = shap, fill = group)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_boxplot(outlier.shape = NA, width = 0.7, position = position_dodge(width = 0.75),
                 colour = "black") +
    coord_flip() +
    scale_fill_manual(values = c("High feature value" = SHAP_COLOUR_HIGH,
                                 "Low feature value" = SHAP_COLOUR_LOW),
                      name = NULL) +
    labs(title = title, x = NULL,
         y = "SHAP value (contribution to the analysed category)") +
    theme_minimal(base_size = 9) +
    theme(
      legend.position = "top",
      legend.justification = "right",
      legend.key.size = grid::unit(0.35, "cm"),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = 10, hjust = 0.5)
    )
}
