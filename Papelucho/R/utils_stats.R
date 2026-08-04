# =============================================================================
# utils_stats.R
# -----------------------------------------------------------------------------
# EN: Group comparison helpers. Every comparison in this project reports an
#     effect size with a confidence interval alongside the p-value, because
#     with n = 12 versus n = 63 a significant p-value says almost nothing about
#     how large a difference is.
# ES: Utilidades de comparacion entre grupos. Toda comparacion de este proyecto
#     reporta un tamano de efecto con intervalo de confianza junto al valor p,
#     porque con n = 12 contra n = 63 un p significativo dice casi nada sobre
#     que tan grande es una diferencia.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(tibble)
})

# -----------------------------------------------------------------------------
# 1. Effect sizes
# -----------------------------------------------------------------------------

#' Cliff's delta
#' EN: Non-parametric effect size for two independent samples. It is the
#'     probability that a randomly drawn value from x exceeds one from y, minus
#'     the reverse probability. Ranges from -1 to +1 and is invariant to
#'     monotone transformations, which matters here because several metrics are
#'     ratios or logarithms.
#'     Conventional thresholds (Romano et al., 2006):
#'       |d| < 0.147 negligible, < 0.33 small, < 0.474 medium, else large.
#' ES: Tamano de efecto no parametrico para dos muestras independientes. Es la
#'     probabilidad de que un valor tomado al azar de x supere a uno de y, menos
#'     la probabilidad inversa. Va de -1 a +1 y es invariante a transformaciones
#'     monotonas, lo que importa aca porque varias metricas son razones o
#'     logaritmos.
#'     Umbrales convencionales (Romano et al., 2006):
#'       |d| < 0.147 nulo, < 0.33 pequeno, < 0.474 medio, si no grande.
cliffs_delta <- function(x, y) {

  x <- x[is.finite(x)]
  y <- y[is.finite(y)]

  if (length(x) < 1 || length(y) < 1) {
    return(list(delta = NA_real_, magnitude = NA_character_,
                n_x = length(x), n_y = length(y)))
  }

  # Pairwise sign comparison. Vectorised via outer for clarity over speed;
  # corpus sizes here are small enough that the memory cost is trivial.
  cmp   <- sign(outer(x, y, "-"))
  delta <- mean(cmp)

  magnitude <- dplyr::case_when(
    is.na(delta)       ~ NA_character_,
    abs(delta) < 0.147 ~ "negligible",
    abs(delta) < 0.330 ~ "small",
    abs(delta) < 0.474 ~ "medium",
    TRUE               ~ "large"
  )

  list(delta = delta, magnitude = magnitude,
       n_x = length(x), n_y = length(y))
}

#' Bootstrap confidence interval for Cliff's delta
#' EN: The analytic variance of delta is unstable for very unequal group sizes,
#'     so a percentile bootstrap is used instead.
#' ES: La varianza analitica de delta es inestable con grupos muy desiguales,
#'     asi que se usa un bootstrap percentil.
cliffs_delta_ci <- function(x, y, n_boot = 2000L, conf = 0.95, seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  x <- x[is.finite(x)]
  y <- y[is.finite(y)]

  if (length(x) < 2 || length(y) < 2) {
    return(c(lower = NA_real_, upper = NA_real_))
  }

  boot <- replicate(n_boot, {
    xb <- sample(x, length(x), replace = TRUE)
    yb <- sample(y, length(y), replace = TRUE)
    mean(sign(outer(xb, yb, "-")))
  })

  alpha <- (1 - conf) / 2
  q <- stats::quantile(boot, probs = c(alpha, 1 - alpha), na.rm = TRUE, names = FALSE)
  c(lower = q[1], upper = q[2])
}

#' Rank-biserial correlation
#' EN: Reported alongside Cliff's delta because it is the effect size that
#'     corresponds directly to the Mann-Whitney U statistic. For two independent
#'     samples the two measures are numerically identical; both are kept so the
#'     table is readable to audiences from different traditions.
#' ES: Se reporta junto a Cliff's delta porque es el tamano de efecto que
#'     corresponde directamente al estadistico U de Mann-Whitney. Para dos
#'     muestras independientes ambas medidas son numericamente identicas; se
#'     mantienen las dos para que la tabla sea legible en distintas tradiciones.
rank_biserial <- function(x, y) {
  x <- x[is.finite(x)]
  y <- y[is.finite(y)]
  if (length(x) < 1 || length(y) < 1) return(NA_real_)
  u <- sum(outer(x, y, ">")) + 0.5 * sum(outer(x, y, "=="))
  2 * u / (length(x) * length(y)) - 1
}

# -----------------------------------------------------------------------------
# 2. Group comparison
# -----------------------------------------------------------------------------

#' Compare one metric between two groups
#' EN: Runs a two-sided Mann-Whitney U test and attaches medians, means,
#'     Cliff's delta with a bootstrap CI, and the rank-biserial correlation.
#'     Medians are reported first because the distributions are skewed and the
#'     test is on ranks; means are kept for continuity with the earlier draft.
#'     Cases with fewer than three observations per group return NA rather than
#'     a fragile p-value.
#' ES: Corre una prueba U de Mann-Whitney bilateral y agrega medianas, medias,
#'     Cliff's delta con IC bootstrap y la correlacion rango-biserial. Las
#'     medianas van primero porque las distribuciones son asimetricas y la
#'     prueba es sobre rangos; las medias se conservan por continuidad con el
#'     borrador anterior. Los casos con menos de tres observaciones por grupo
#'     devuelven NA en vez de un valor p fragil.
compare_groups <- function(data,
                           metric_col,
                           group_col   = "group",
                           focus       = "Papelucho",
                           comparison  = "Comparison",
                           n_boot      = 2000L,
                           seed        = NULL) {

  x <- data[[metric_col]][data[[group_col]] == focus]
  y <- data[[metric_col]][data[[group_col]] == comparison]

  x <- x[is.finite(x)]
  y <- y[is.finite(y)]

  n_x <- length(x)
  n_y <- length(y)

  if (n_x < 3 || n_y < 3) {
    return(tibble::tibble(
      metric = metric_col, n_focus = n_x, n_comparison = n_y,
      median_focus = if (n_x) stats::median(x) else NA_real_,
      median_comparison = if (n_y) stats::median(y) else NA_real_,
      mean_focus = if (n_x) mean(x) else NA_real_,
      mean_comparison = if (n_y) mean(y) else NA_real_,
      difference = NA_real_, p_value = NA_real_,
      cliffs_delta = NA_real_, delta_lower = NA_real_, delta_upper = NA_real_,
      delta_magnitude = NA_character_, rank_biserial = NA_real_,
      higher_in = NA_character_
    ))
  }

  # exact = FALSE because ties are common in bounded ratio metrics; the normal
  # approximation with continuity correction is the appropriate choice there.
  test <- suppressWarnings(
    stats::wilcox.test(x, y, alternative = "two.sided", exact = FALSE, correct = TRUE)
  )

  cd  <- cliffs_delta(x, y)
  ci  <- cliffs_delta_ci(x, y, n_boot = n_boot, seed = seed)
  rbc <- rank_biserial(x, y)

  med_x <- stats::median(x)
  med_y <- stats::median(y)

  tibble::tibble(
    metric            = metric_col,
    n_focus           = n_x,
    n_comparison      = n_y,
    median_focus      = med_x,
    median_comparison = med_y,
    mean_focus        = mean(x),
    mean_comparison   = mean(y),
    difference        = med_x - med_y,
    p_value           = test$p.value,
    cliffs_delta      = cd$delta,
    delta_lower       = unname(ci["lower"]),
    delta_upper       = unname(ci["upper"]),
    delta_magnitude   = cd$magnitude,
    rank_biserial     = rbc,
    higher_in         = dplyr::case_when(
      med_x > med_y ~ focus,
      med_x < med_y ~ comparison,
      TRUE          ~ "tie"
    )
  )
}

#' Compare many metrics and correct for multiple testing
#' EN: The correction is applied once, over the full family of tests reported
#'     in a table. Applying it per-metric or forgetting it entirely, as in the
#'     original POS and emotion scripts, inflates the false-positive rate.
#'     A result is called significant only when the adjusted p-value is below
#'     alpha AND the effect size is at least small, because with unequal group
#'     sizes a tiny difference can still clear a p-value threshold.
#' ES: La correccion se aplica una vez, sobre toda la familia de pruebas
#'     reportadas en una tabla. Aplicarla por metrica u olvidarla del todo, como
#'     en los scripts originales de POS y emociones, infla la tasa de falsos
#'     positivos. Un resultado se declara significativo solo si el p ajustado
#'     esta bajo alpha Y el tamano de efecto es al menos pequeno, porque con
#'     grupos desiguales una diferencia minima igual puede pasar el umbral de p.
compare_many <- function(data,
                         metrics,
                         group_col  = "group",
                         focus      = "Papelucho",
                         comparison = "Comparison",
                         adjust     = "holm",
                         alpha      = 0.05,
                         n_boot     = 2000L,
                         seed       = 20250803L) {

  purrr::map_dfr(metrics, function(m) {
    compare_groups(
      data       = data,
      metric_col = m,
      group_col  = group_col,
      focus      = focus,
      comparison = comparison,
      n_boot     = n_boot,
      seed       = seed
    )
  }) %>%
    dplyr::mutate(
      p_adjusted = stats::p.adjust(p_value, method = adjust),
      significant = !is.na(p_adjusted) &
        p_adjusted < alpha &
        !is.na(delta_magnitude) &
        delta_magnitude != "negligible",
      # A significant p-value paired with a negligible effect is flagged rather
      # than silently reported, since that pattern is the usual signature of a
      # sample-size artefact.
      note = dplyr::case_when(
        is.na(p_adjusted) ~ "insufficient data",
        p_adjusted < alpha & delta_magnitude == "negligible" ~
          "significant but negligible effect",
        p_adjusted >= alpha & delta_magnitude %in% c("medium", "large") ~
          "notable effect, not significant after correction",
        TRUE ~ ""
      )
    )
}

# -----------------------------------------------------------------------------
# 3. Formatting
# -----------------------------------------------------------------------------

#' Format a p-value for publication
format_p <- function(p, digits = 3) {
  ifelse(
    is.na(p), "NA",
    ifelse(p < 0.001, "<0.001", formatC(p, format = "f", digits = digits))
  )
}

#' Format an effect size with its confidence interval
format_delta <- function(delta, lower, upper, digits = 2) {
  ifelse(
    is.na(delta), "NA",
    sprintf(
      "%.*f [%.*f, %.*f]",
      digits, delta, digits, lower, digits, upper
    )
  )
}
