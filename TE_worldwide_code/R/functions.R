# =====================================================================
# functions.R
# DEA and second-stage estimators used by the pipeline. Sourced by 00_setup.R.
#
#   dea_input()        radial input-oriented DEA (CRS or VRS) solved as linear programmes with lpSolve
#   fit_tobit()        Tobit regression censored at 0 and 1 (AER::tobit, maximum likelihood)
#   tobit_boot()       Tobit with case-resampling bootstrap: percentile 95% intervals, p values from the normal
#                      approximation to the bootstrap standard error
#   ols_hc1()          OLS with heteroskedasticity-robust (HC1) standard errors
#   fit_truncreg()     truncated normal regression (left or right truncation), maximum likelihood
#   sw_algorithm1()    Simar and Wilson (2007) Algorithm 1, on the Shephard input distance 1 / score
#   sw_algorithm2()    Simar and Wilson (2007) Algorithm 2, on the Shephard input distance (annual frontiers
#                      bias-corrected, pooled regression)
#   vif()              variance inflation factors
# =====================================================================

# ---------------------------------------------------------------------
# DEA
# ---------------------------------------------------------------------
# Input-oriented radial efficiency of each row of (X, Y) against the reference technology spanned by (XREF, YREF).
#   theta_o = min theta  s.t.  sum_j lambda_j x_j <= theta x_o,  sum_j lambda_j y_j >= y_o,  lambda_j >= 0
#   (VRS adds sum_j lambda_j = 1)
# When the evaluated units are part of the reference set (the default), theta lies in (0, 1] and frontier units have
# theta = 1 exactly; the solver returns them as 1 +/- 1e-10, so scores within TOL_FRONTIER of 1 are set to 1. This
# matters for rank correlations: frontier units are tied at 1 and must receive tied ranks. When the reference set is a
# different sample (the pseudo-samples of the Simar-Wilson bootstrap), a unit can lie outside the reference frontier and
# theta > 1 is a valid result, so the scores are returned as solved.
dea_input <- function(X, Y, rts = c("crs", "vrs"), XREF = NULL, YREF = NULL) {
  rts <- match.arg(rts)
  X <- as.matrix(X); Y <- as.matrix(Y)
  own_reference <- is.null(XREF)
  if (own_reference) { XREF <- X; YREF <- Y }
  XREF <- as.matrix(XREF); YREF <- as.matrix(YREF)
  n <- nrow(X); m <- ncol(X); s <- ncol(Y); k <- nrow(XREF)
  stopifnot(ncol(XREF) == m, ncol(YREF) == s, nrow(YREF) == k, !anyNA(X), !anyNA(Y), !anyNA(XREF), !anyNA(YREF))
  obj <- c(1, rep(0, k))                        # variables: theta, lambda_1..lambda_k
  A <- rbind(cbind(0, t(XREF)), cbind(0, t(YREF)))
  dir <- c(rep("<=", m), rep(">=", s))
  if (rts == "vrs") {
    A <- rbind(A, c(0, rep(1, k)))
    dir <- c(dir, "=")
  }
  theta <- numeric(n)
  for (o in seq_len(n)) {
    A[1:m, 1] <- -X[o, ]
    rhs <- c(rep(0, m), Y[o, ], if (rts == "vrs") 1)
    sol <- lpSolve::lp("min", obj, A, dir, rhs)
    if (sol$status != 0) stop("DEA linear programme failed for unit ", o, " (lpSolve status ", sol$status, ")")
    theta[o] <- sol$solution[1]
  }
  if (own_reference) theta[theta >= 1 - TOL_FRONTIER] <- 1
  theta
}

# ---------------------------------------------------------------------
# Tobit (two-sided censoring at 0 and 1)
# ---------------------------------------------------------------------
# Returns the coefficients and log(sigma), or NULL when the optimiser does not converge.
# AER::tobit evaluates its call in the environment of the formula, so the formula is re-attached to this function's
# environment; otherwise `data` would resolve to the caller's data set and every bootstrap replicate would refit the
# original sample.
fit_tobit <- function(formula, data) {
  environment(formula) <- environment()
  fit <- withCallingHandlers(
    tryCatch(AER::tobit(formula, left = 0, right = 1, data = data,
                        control = survival::survreg.control(maxiter = 100)),
             error = function(e) NULL),
    warning = function(w) invokeRestart("muffleWarning"))
  if (is.null(fit) || fit$iter >= 100 || any(!is.finite(coef(fit)))) return(NULL)
  c(coef(fit), log_sigma = log(fit$scale))
}

# Tobit with case-resampling bootstrap. A replicate whose optimiser fails is redrawn, so that every model keeps B
# replicates; the number of redraws is reported (it is zero for every model of the paper).
tobit_boot <- function(data, pred, B, seed, response = "te_io_crs") {
  f <- reformulate(pred, response = response)
  est <- fit_tobit(f, data)
  if (is.null(est)) stop("Tobit did not converge on the full sample")
  set.seed(seed)
  n <- nrow(data)
  boot <- matrix(NA_real_, B, length(est), dimnames = list(NULL, names(est)))
  redraws <- 0L
  b <- 0L
  while (b < B) {
    idx <- sample.int(n, n, replace = TRUE)
    eb <- fit_tobit(f, data[idx, , drop = FALSE])
    if (is.null(eb)) { redraws <- redraws + 1L; next }
    b <- b + 1L
    boot[b, ] <- eb
  }
  se <- apply(boot, 2, sd)
  ci <- apply(boot, 2, quantile, probs = c(0.025, 0.975), type = 7)
  out <- data.frame(term = names(est), coef = unname(est), se = unname(se), p = 2 * pnorm(-abs(est / se)),
                    ci_lo = ci[1, ], ci_hi = ci[2, ], row.names = NULL)
  attr(out, "n") <- n
  attr(out, "n_censored_at_1") <- sum(data[[response]] >= 1)
  attr(out, "redraws") <- redraws
  out
}

# ---------------------------------------------------------------------
# OLS with HC1 standard errors (normal-approximation intervals and p values)
# ---------------------------------------------------------------------
ols_hc1 <- function(data, pred, response = "te_io_crs") {
  fit <- lm(reformulate(pred, response = response), data = data)
  b <- coef(fit)
  se <- sqrt(diag(sandwich::vcovHC(fit, type = "HC1")))
  data.frame(term = names(b), coef = unname(b), se = unname(se), p = 2 * pnorm(-abs(b / se)),
             ci_lo = unname(b - 1.96 * se), ci_hi = unname(b + 1.96 * se), row.names = NULL)
}

# ---------------------------------------------------------------------
# Truncated normal regression
# ---------------------------------------------------------------------
# Model y_i = z_i b + e_i, e_i ~ N(0, sigma^2), observed only above (side = "lower") or below (side = "upper") `bound`.
# Right truncation: log-likelihood of observation i is log phi(e_i) - log sigma - log Phi(a_i), with
# e_i = (y_i - z_i b) / sigma and a_i = (bound - z_i b) / sigma (analytic gradient, BFGS). Left truncation is fitted as
# the right-truncated model of -y at -bound, whose coefficients are -b. Returns c(b, log_sigma).
fit_truncreg <- function(y, Z, bound = 1, side = c("lower", "upper"), start = NULL) {
  side <- match.arg(side)
  k <- ncol(Z)
  if (side == "lower") {
    flip <- function(par) c(-par[1:k], par[k + 1])
    est <- fit_truncreg(-y, Z, bound = -bound, side = "upper", start = if (!is.null(start)) flip(start))
    return(setNames(flip(est), names(est)))
  }
  nll <- function(par) {
    mu <- drop(Z %*% par[1:k]); s <- exp(par[k + 1])
    -sum(dnorm(y, mu, s, log = TRUE) - pnorm((bound - mu) / s, log.p = TRUE))
  }
  grad <- function(par) {
    mu <- drop(Z %*% par[1:k]); s <- exp(par[k + 1])
    e <- (y - mu) / s
    a <- (bound - mu) / s
    lam <- exp(dnorm(a, log = TRUE) - pnorm(a, log.p = TRUE))   # inverse Mills ratio phi(a) / Phi(a)
    -c(drop(crossprod(Z, e + lam)) / s, sum(e^2 - 1 + a * lam))
  }
  if (is.null(start)) {
    b0 <- qr.coef(qr(Z), y)
    start <- c(b0, log(sd(y - drop(Z %*% b0))))
  }
  ctrl <- list(maxit = 5000, reltol = 1e-12)
  opt <- optim(start, nll, grad, method = "BFGS", control = ctrl)
  if (opt$convergence != 0) {
    opt <- optim(opt$par, nll, method = "Nelder-Mead", control = list(maxit = 20000, reltol = 1e-12))
    opt <- optim(opt$par, nll, grad, method = "BFGS", control = ctrl)
  }
  if (opt$convergence != 0) warning("truncated regression did not converge")
  setNames(opt$par, c(colnames(Z), "log_sigma"))
}

# Draws from N(0, sigma^2) truncated at a (elementwise): e >= a (side = "lower") or e <= a (side = "upper"),
# by inversion on the log scale
rtnorm0 <- function(a, sigma, side = c("lower", "upper")) {
  side <- match.arg(side)
  if (side == "lower") return(-rtnorm0(-a, sigma, "upper"))
  logp <- pnorm(a / sigma, log.p = TRUE) + log(runif(length(a)))
  sigma * qnorm(logp, log.p = TRUE)
}

design <- function(data, pred) {
  Z <- cbind(1, as.matrix(data[, pred, drop = FALSE]))
  colnames(Z) <- c("(Intercept)", pred)
  Z
}

ci_table <- function(est, boot) {
  ci <- apply(boot, 2, quantile, probs = c(0.025, 0.975), type = 7)
  data.frame(term = names(est), coef = unname(est), ci_lo = ci[1, ], ci_hi = ci[2, ],
             sig = ci[1, ] > 0 | ci[2, ] < 0, row.names = NULL)
}

# ---------------------------------------------------------------------
# Simar and Wilson (2007), Algorithms 1 and 2
# ---------------------------------------------------------------------
# Both algorithms work, as in Simar and Wilson (2007), with a distance that is bounded below by one: here the Shephard
# input distance delta = 1 / theta >= 1 of the input-oriented score theta. The second-stage model is
#   delta_i = z_i b + e_i >= 1,  e_i ~ N(0, sigma^2) left-truncated at 1 - z_i b,
# so a NEGATIVE coefficient means a HIGHER efficiency score (the sign is the opposite of the Tobit and OLS models, which
# use theta). Working with delta keeps every bias-corrected score inside the admissible range (delta >= 1, i.e.
# 0 < theta <= 1); a bias correction applied additively to theta can push frontier units below zero.

# Algorithm 1: truncated regression of the published scores (delta = 1 / score) over the observations off the frontier,
# parametric bootstrap with L replicates, percentile 95% intervals.
sw_algorithm1 <- function(data, pred, L, seed, response = "te_io_crs") {
  delta <- 1 / data[[response]]
  keep <- delta > 1
  Z <- design(data, pred)[keep, , drop = FALSE]
  y <- delta[keep]
  k <- ncol(Z)
  est <- fit_truncreg(y, Z, side = "lower")
  mu <- drop(Z %*% est[1:k]); s <- exp(est[k + 1])
  set.seed(seed)
  boot <- matrix(NA_real_, L, k + 1, dimnames = list(NULL, names(est)))
  for (l in seq_len(L)) {
    boot[l, ] <- fit_truncreg(mu + rtnorm0(1 - mu, s, "lower"), Z, side = "lower", start = est)
  }
  out <- ci_table(est, boot)
  attr(out, "n") <- length(y)
  out
}

# Algorithm 2. Steps 1-4 run separately for each annual frontier (country-years with complete covariates):
#   1. DEA scores theta_i of the year, delta_i = 1 / theta_i;
#   2. truncated regression of delta_i on z_i over the units off the frontier (delta_i > 1) -> (b, sigma);
#   3. L1 times: for every unit draw e_i ~ N(0, sigma^2) left-truncated at 1 - z_i b, delta*_i = z_i b + e_i, build the
#      pseudo-inputs x*_i = x_i delta*_i / delta_i (outputs unchanged), and re-score every ORIGINAL unit (x_i, y_i)
#      against the pseudo-sample; an original unit can lie outside the pseudo-frontier, so its bootstrap score
#      theta* may exceed 1 (delta* < 1) and is kept as solved;
#   4. bias_i = mean(delta*_i scores) - delta_i, bias-corrected distance = delta_i - bias_i (>= delta_i >= 1).
# Steps 5-7 pool the bias-corrected distances of all years: truncated regression (left truncation at 1), parametric
# bootstrap with L2 replicates, percentile 95% intervals.
sw_algorithm2 <- function(data, pred, L1, L2, seed) {
  set.seed(seed)
  by_year <- list()
  for (yr in sort(unique(data$year))) {
    d <- data[data$year == yr, , drop = FALSE]
    X <- as.matrix(d[, INPUTS]); Y <- as.matrix(d[, OUTPUTS])
    th <- dea_input(X, Y, "crs")
    delta <- 1 / th
    Z <- design(d, pred)
    k <- ncol(Z)
    off <- th < 1
    est <- fit_truncreg(delta[off], Z[off, , drop = FALSE], side = "lower")
    mu <- drop(Z %*% est[1:k]); s <- exp(est[k + 1])
    boots <- matrix(NA_real_, L1, nrow(d))
    for (l in seq_len(L1)) {
      delta_star <- mu + rtnorm0(1 - mu, s, "lower")
      boots[l, ] <- 1 / dea_input(X, Y, "crs", XREF = X * (delta_star / delta), YREF = Y)
    }
    bias <- colMeans(boots) - delta
    by_year[[as.character(yr)]] <- data.frame(code = d$code, year = d$year, theta = th, delta = delta, bias = bias,
                                              delta_bc = delta - bias, theta_bc = 1 / (delta - bias),
                                              d[, pred, drop = FALSE])
    message(sprintf("  SW2 %d: n = %d, mean score = %.3f, mean bias-corrected score = %.3f",
                    yr, nrow(d), mean(th), mean(1 / (delta - bias))))
  }
  bc <- do.call(rbind, by_year)
  rownames(bc) <- NULL
  keep <- bc$delta_bc > 1
  Z <- design(bc, pred)[keep, , drop = FALSE]
  y <- bc$delta_bc[keep]
  k <- ncol(Z)
  est <- fit_truncreg(y, Z, side = "lower")
  mu <- drop(Z %*% est[1:k]); s <- exp(est[k + 1])
  boot <- matrix(NA_real_, L2, k + 1, dimnames = list(NULL, names(est)))
  for (l in seq_len(L2)) {
    boot[l, ] <- fit_truncreg(mu + rtnorm0(1 - mu, s, "lower"), Z, side = "lower", start = est)
  }
  out <- ci_table(est, boot)
  attr(out, "n") <- sum(keep)
  attr(out, "scores") <- bc[, c("code", "year", "theta", "delta", "bias", "delta_bc", "theta_bc")]
  out
}

# ---------------------------------------------------------------------
# Variance inflation factors
# ---------------------------------------------------------------------
vif <- function(data, pred) {
  sapply(pred, function(p) 1 / (1 - summary(lm(reformulate(setdiff(pred, p), response = p), data = data))$r.squared))
}

# ---------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------
spearman <- function(x, y) cor(x, y, method = "spearman")
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
# LaTeX number with a typographic minus sign
fmt_tex <- function(x, d = 4) ifelse(round(x, d) < 0, paste0("$-$", formatC(abs(x), format = "f", digits = d)),
                                     formatC(abs(x), format = "f", digits = d))
fmt_p <- function(p) ifelse(p < 0.001, "$<$0.001", ifelse(p < 0.1, formatC(p, format = "f", digits = 3),
                                                          formatC(p, format = "f", digits = 2)))
