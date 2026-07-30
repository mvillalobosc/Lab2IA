# =============================================================================
# R/lib_hypervolume.R
#
# Hypervolume indicator for the model comparison of step 7.
#
# The four objectives are precision, sensitivity, F1 and accuracy, all maximised,
# all bounded in [0, 1]. The indicator is the volume of the region dominated by a
# model's performance and bounded below by the reference point, which defaults to
# the origin. It is monotone with respect to Pareto dominance and needs no
# weights, which is why it is used instead of an arbitrary weighted average of the
# four metrics.
#
# Two modes, selected by hypervolume$mode in config.yml:
#
#   mean   The four metrics are averaged over the replicates, giving one point per
#          model, and the hypervolume of that single point is reported. With the
#          reference point at the origin this is the product of the four means.
#          This is the reading that matches a table reporting mean metrics and one
#          hypervolume per model.
#
#   front  The 500 replicates of a model are treated as a set of solutions, the
#          dominated ones are discarded and the exact hypervolume of the remaining
#          front is computed. This rewards a model that is good and stable rather
#          than good on average, and it is slower.
#
# Note on the published values
#   The hypervolume column of the current manuscript draft reports 0.0625 for four
#   scenarios whose metric vectors differ substantially, and 0.0625 is exactly 0.5
#   to the fourth power. A hypervolume cannot be insensitive to the point it is
#   computed from, so that column needs regenerating. Neither mode here reproduces
#   it, and neither is trying to: both are defined explicitly above so that
#   whatever ends up in the table can be recomputed from the replicate files.
# =============================================================================


#' Non-dominated subset of a set of points, assuming maximisation.
#'
#' A point is dominated when another point is at least as good in every objective
#' and strictly better in at least one. Duplicate rows are collapsed first, which
#' matters here: metrics computed on a 200-row resample are ratios with small
#' denominators, so 500 replicates contain far fewer distinct points than rows,
#' and the exact hypervolume below is sensitive to the size of the front.
#'
#' @param points numeric matrix, one row per point, one column per objective.
non_dominated <- function(points) {
  if (!is.matrix(points)) points <- as.matrix(points)
  if (nrow(points) == 0L) return(points)

  pts <- unique(points)
  if (nrow(pts) == 1L) return(pts)

  keep <- rep(TRUE, nrow(pts))
  for (i in seq_len(nrow(pts))) {
    if (!keep[i]) next
    ref <- pts[i, ]
    weakly_worse <- apply(pts, 1, function(p) all(p <= ref))
    strictly_worse <- apply(pts, 1, function(p) any(p < ref))
    keep[weakly_worse & strictly_worse] <- FALSE
  }
  pts[keep, , drop = FALSE]
}


#' Exact hypervolume of a maximisation front, by slicing objectives.
#'
#' Recursive formulation: sort the points by the last objective in descending
#' order, sweep that objective, and accumulate the hypervolume of the points seen
#' so far in the remaining dimensions, multiplied by the width of the slice. Only
#' points that dominate the reference point in every objective contribute.
#'
#' @param points numeric matrix of points (maximisation).
#' @param ref numeric reference point, one value per objective.
hv_exact <- function(points, ref) {
  if (!is.matrix(points)) points <- matrix(points, nrow = 1L)
  if (nrow(points) == 0L) return(0)

  inside <- apply(points, 1, function(p) all(p > ref))
  pts <- points[inside, , drop = FALSE]
  if (nrow(pts) == 0L) return(0)

  d <- ncol(pts)

  if (d == 1L) return(max(pts[, 1]) - ref[1])

  if (d == 2L) {
    # On a non-dominated front sorted by the first objective descending, the
    # second objective increases, so the union of rectangles decomposes into
    # vertical strips.
    front <- non_dominated(pts)
    front <- front[order(-front[, 1], -front[, 2]), , drop = FALSE]
    x <- c(front[, 1], ref[1])
    widths <- x[-length(x)] - x[-1]
    heights <- front[, 2] - ref[2]
    return(sum(widths * heights))
  }

  front <- non_dominated(pts)
  front <- front[order(-front[, d]), , drop = FALSE]
  z <- c(front[, d], ref[d])

  total <- 0
  for (k in seq_len(nrow(front))) {
    slice_width <- z[k] - z[k + 1L]
    if (slice_width <= 0) next
    total <- total + slice_width * hv_exact(front[seq_len(k), -d, drop = FALSE], ref[-d])
  }
  total
}


#' Hypervolume of a single point: the product of its distances to the reference.
hv_of_mean <- function(mean_point, ref) {
  prod(pmax(mean_point - ref, 0))
}


#' Hypervolume table for every scenario and model in a metrics data frame.
#'
#' @param metrics data frame with the columns scenario, model and one column per
#'   objective, as written by step 7.
#' @param objectives character vector of objective columns, in order.
#' @param ref numeric reference point.
#' @param mode "mean" or "front".
#' @return data frame with one row per scenario and model, ranked inside each
#'   scenario, largest hypervolume first.
hypervolume_table <- function(metrics, objectives, ref, mode = "mean") {
  missing_cols <- setdiff(c("scenario", "model", objectives), names(metrics))
  if (length(missing_cols) > 0L) {
    fail("metrics is missing the columns: ", paste(missing_cols, collapse = ", "))
  }
  if (length(ref) != length(objectives)) {
    fail("reference_point has ", length(ref), " entries but there are ",
         length(objectives), " objectives")
  }

  groups <- split(metrics, list(metrics$scenario, metrics$model), drop = TRUE)

  rows <- lapply(groups, function(d) {
    values <- as.matrix(d[, objectives, drop = FALSE])
    storage.mode(values) <- "double"

    # A replicate in which a metric is undefined (no predicted positive) cannot
    # contribute a point to the front.
    complete <- values[stats::complete.cases(values), , drop = FALSE]
    if (nrow(complete) == 0L) return(NULL)

    means <- colMeans(values, na.rm = TRUE)

    t0 <- Sys.time()
    if (identical(mode, "front")) {
      front <- non_dominated(complete)
      hv <- hv_exact(front, ref)
      n_front <- nrow(front)
    } else {
      hv <- hv_of_mean(means, ref)
      n_front <- 1L
    }
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    out <- data.frame(
      scenario = d$scenario[1],
      model = d$model[1],
      mode = mode,
      hypervolume = hv,
      n_replicates = nrow(values),
      n_replicates_complete = nrow(complete),
      n_nondominated = n_front,
      seconds = round(secs, 3),
      stringsAsFactors = FALSE
    )
    for (i in seq_along(objectives)) out[[paste0("mean_", objectives[i])]] <- means[i]
    out
  })

  out <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  if (is.null(out) || nrow(out) == 0L) return(out)
  rownames(out) <- NULL

  # Rank inside each scenario, largest hypervolume first. This is the column step
  # 9 uses to choose the row of Table 1.
  out$rank_in_scenario <- NA_integer_
  for (s in unique(out$scenario)) {
    idx <- which(out$scenario == s)
    out$rank_in_scenario[idx] <- rank(-out$hypervolume[idx], ties.method = "min")
  }
  out <- out[order(out$scenario, out$rank_in_scenario), ]
  rownames(out) <- NULL
  out
}
