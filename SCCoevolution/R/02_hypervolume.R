# =============================================================================
# 02_hypervolume.R
# -----------------------------------------------------------------------------
# EN: Compares the two multi-objective strategies, MOSA and NSGA-II, by the
#     hypervolume each achieves across independent runs.
#
#     WHAT WAS ADDED
#     The original GraficoVela/grafico.R drew a violin plot and stopped there.
#     A figure showing two distributions that overlap is not an answer to "is one
#     algorithm better", so this script also runs the comparison: a Mann-Whitney
#     test with a rank-biserial effect size and a bootstrap confidence interval.
#     With around thirty runs per algorithm the test has enough power to be
#     worth reporting, and an effect size is what a reviewer will ask for.
#
#     WHAT WAS FIXED
#     The two input files were called "Dataset 0.csv" and "Dataset 1.csv", with
#     spaces in the names, no header row, and the mapping from 0 and 1 to MOSA
#     and NSGA-II recorded only inside the plotting script. They are now one
#     tidy file with an explicit algorithm column.
#
#     The y-axis was also hard-limited to the range 1 to 4. Any run falling
#     outside that window would be dropped from the figure without warning, and
#     ggplot's message about removed rows is easy to miss. The limits are now
#     computed from the data, and the script reports the observed range.
#
# ES: Compara las dos estrategias multiobjetivo, MOSA y NSGA-II, por el
#     hipervolumen que alcanza cada una en corridas independientes.
#
#     QUE SE AGREGO
#     El GraficoVela/grafico.R original dibujaba un violin y ahi terminaba. Una
#     figura que muestra dos distribuciones que se solapan no responde "es mejor
#     un algoritmo", asi que este script ademas corre la comparacion: prueba de
#     Mann-Whitney con tamano de efecto rango-biserial e intervalo de confianza
#     bootstrap.
#
#     QUE SE ARREGLO
#     Los dos archivos de entrada se llamaban "Dataset 0.csv" y "Dataset 1.csv",
#     con espacios en el nombre, sin fila de encabezado, y el mapeo de 0 y 1 a
#     MOSA y NSGA-II quedaba registrado solo dentro del script de graficos.
#
#     El eje y ademas estaba fijado al rango 1 a 4. Cualquier corrida fuera de
#     esa ventana se caia de la figura sin aviso, y el mensaje de ggplot sobre
#     filas eliminadas es facil de pasar por alto. Ahora los limites se calculan
#     de los datos y el script reporta el rango observado.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")

check_dependencies(quiet = TRUE)
log_msg("02_hypervolume: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

hv <- readr::read_csv(FILES$hypervolume, show_col_types = FALSE)

log_msg("  runs per algorithm:")
print(as.data.frame(hv %>% dplyr::count(algorithm, name = "runs")), row.names = FALSE)

rng <- range(hv$hypervolume)
log_msg("  observed hypervolume range: ", round(rng[1], 3), " to ", round(rng[2], 3))

# -----------------------------------------------------------------------------
# 1. Statistical comparison
# -----------------------------------------------------------------------------

x <- hv$hypervolume[hv$algorithm == "MOSA"]
y <- hv$hypervolume[hv$algorithm == "NSGA-II"]

test <- suppressWarnings(stats::wilcox.test(x, y, exact = FALSE, correct = TRUE))

# Rank-biserial correlation: the effect size that corresponds to Mann-Whitney U.
u   <- sum(outer(x, y, ">")) + 0.5 * sum(outer(x, y, "=="))
rbc <- 2 * u / (length(x) * length(y)) - 1

set.seed(PARAMS$seed)
boot <- replicate(2000, {
  xb <- sample(x, length(x), replace = TRUE)
  yb <- sample(y, length(y), replace = TRUE)
  ub <- sum(outer(xb, yb, ">")) + 0.5 * sum(outer(xb, yb, "=="))
  2 * ub / (length(xb) * length(yb)) - 1
})
ci <- stats::quantile(boot, c(0.025, 0.975), names = FALSE)

result <- tibble::tibble(
  n_mosa        = length(x),
  n_nsga2       = length(y),
  median_mosa   = stats::median(x),
  median_nsga2  = stats::median(y),
  mean_mosa     = mean(x),
  mean_nsga2    = mean(y),
  p_value       = test$p.value,
  rank_biserial = rbc,
  ci_lower      = ci[1],
  ci_upper      = ci[2],
  higher_in     = ifelse(stats::median(x) > stats::median(y), "MOSA", "NSGA-II")
)

readr::write_csv(result, file.path(PATHS$tables, "02_hypervolume_comparison.csv"))

log_msg("  MOSA median ", round(result$median_mosa, 3),
        " vs NSGA-II median ", round(result$median_nsga2, 3))
log_msg("  p = ", format.pval(result$p_value, digits = 3),
        ", rank-biserial = ", round(rbc, 3),
        " [", round(ci[1], 3), ", ", round(ci[2], 3), "]")

# -----------------------------------------------------------------------------
# 2. Figure
# -----------------------------------------------------------------------------

pad <- diff(rng) * 0.08

fig <- ggplot(hv, aes(x = algorithm, y = hypervolume, fill = algorithm)) +
  geom_violin(trim = FALSE, alpha = 0.7, colour = COLOURS$neutral) +
  geom_boxplot(width = 0.12, fill = "white", alpha = 0.8, outlier.shape = NA) +
  geom_jitter(width = 0.1, alpha = 0.5, size = 1.8) +
  scale_fill_manual(values = ALGORITHM_COLOURS) +
  scale_y_continuous(limits = c(rng[1] - pad, rng[2] + pad)) +
  labs(x = "Multi-objective strategy", y = "Hypervolume (HV)") +
  theme_orf()

save_figure(fig, "02_hypervolume_violin", width = 8, height = 6)

write_session_info("02_hypervolume")
log_msg("02_hypervolume: done")
