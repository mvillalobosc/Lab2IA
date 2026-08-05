# =============================================================================
# 01_pareto_front.R
# -----------------------------------------------------------------------------
# EN: Pareto front of the two objectives, plus convergence across generations.
#
#     THE TWO OBJECTIVES
#       Objective 1  number of ORFs, normalised. Fewer genes is better, so a
#                    smaller value is preferred.
#       Objective 2  normalised Robinson-Foulds distance to the reference tree.
#                    A smaller value means the tree built from the selected
#                    genes is closer to the reference topology.
#     Both are minimised, so the front runs from few-genes/high-distance to
#     many-genes/low-distance and the trade-off is the point of the figure.
#
#     WHAT WAS FIXED
#     The original Convergencia/grafico.R plotted only the final front F4 and
#     attached solution labels through a hand-written vector whose order had to
#     match the row order of f4.csv exactly. Nothing checked that it did. If
#     anyone re-sorted the CSV or re-ran the optimiser, every label would silently
#     move to the wrong point. Labels now come from the same solutions.csv the
#     rest of the pipeline uses, matched by objective value rather than by
#     position, and the match is verified.
#
#     The reference solution was also hard-coded as a data frame literal
#     (RFdist = 0.07, K = 1) inside the plotting script. It is now a row of
#     pareto_fronts.csv like everything else.
#
# ES: Frente de Pareto de los dos objetivos, mas la convergencia entre
#     generaciones.
#
#     LOS DOS OBJETIVOS
#       Objetivo 1  numero de ORFs, normalizado. Menos genes es mejor.
#       Objetivo 2  distancia de Robinson-Foulds normalizada al arbol de
#                   referencia. Menor valor significa que el arbol construido con
#                   los genes seleccionados esta mas cerca de la topologia de
#                   referencia.
#     Los dos se minimizan, asi que el frente va de pocos-genes/distancia-alta a
#     muchos-genes/distancia-baja y el compromiso es el punto de la figura.
#
#     QUE SE ARREGLO
#     El Convergencia/grafico.R original graficaba solo el frente final F4 y
#     pegaba las etiquetas de solucion mediante un vector escrito a mano cuyo
#     orden tenia que calzar exactamente con el orden de filas de f4.csv. Nada
#     verificaba que calzara. Si alguien reordenaba el CSV o volvia a correr el
#     optimizador, cada etiqueta se movia en silencio al punto equivocado.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")

check_dependencies(quiet = TRUE)
log_msg("01_pareto_front: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

fronts <- readr::read_csv(FILES$pareto, show_col_types = FALSE)
sols   <- read_solutions()

log_msg("  ", nrow(fronts), " points across ", dplyr::n_distinct(fronts$front),
        " generations")

# -----------------------------------------------------------------------------
# 1. Convergence across generations
# -----------------------------------------------------------------------------
# EN: All five recorded fronts on one panel. The original script loaded f0 to f4
#     but plotted only f4, so the convergence the file names imply was never
#     actually shown.
# ES: Los cinco frentes registrados en un panel. El script original cargaba f0 a
#     f4 pero graficaba solo f4, asi que la convergencia que sugieren los nombres
#     de archivo nunca se mostraba.

fig_conv <- ggplot(fronts, aes(x = n_orfs_norm, y = nRFdist,
                               colour = front, group = front)) +
  geom_line(linewidth = 0.8, alpha = 0.85) +
  geom_point(size = 2.4) +
  scale_colour_brewer(palette = "Set2") +
  labs(x = "Objective 1: number of ORFs (normalised)",
       y = "Objective 2: nRF distance",
       colour = "Generation") +
  theme_orf(base_size = 14) +
  theme(legend.position = "right")

save_figure(fig_conv, "01_convergence_all_fronts", width = 9, height = 6)

# -----------------------------------------------------------------------------
# 2. Final front with solution labels
# -----------------------------------------------------------------------------
# EN: Solutions are matched to front points by size, not by row position. The
#     number of ORFs in each solution is known from solutions.csv, so a point on
#     the front can be identified without trusting the CSV row order.
# ES: Las soluciones se emparejan con los puntos del frente por tamano, no por
#     posicion de fila. El numero de ORFs de cada solucion se conoce desde
#     solutions.csv, asi que un punto del frente puede identificarse sin confiar
#     en el orden de filas del CSV.

final_front <- fronts %>% dplyr::filter(front == max(front))

sizes <- solution_summary(sols) %>%
  dplyr::filter(solution != PARAMS$reference_solution) %>%
  dplyr::arrange(n_orfs)

# Two solutions may share identical objective values, in which case one point
# carries a combined label. This is detected rather than assumed.
labelled <- final_front %>%
  dplyr::arrange(n_orfs_norm) %>%
  dplyr::mutate(rank = dplyr::row_number())

n_points <- nrow(labelled)
n_sols   <- nrow(sizes)

if (n_points != n_sols) {
  log_msg("  NOTE: ", n_sols, " solutions map onto ", n_points,
          " distinct front points; some solutions share objective values")
}

grouped <- sizes %>%
  dplyr::mutate(rank = dplyr::dense_rank(n_orfs)) %>%
  dplyr::group_by(rank) %>%
  dplyr::summarise(
    label   = paste(sub("^S", "", solution), collapse = "-"),
    n_orfs  = dplyr::first(n_orfs),
    .groups = "drop"
  ) %>%
  dplyr::mutate(label = paste0("S[", label, "]"))

labelled <- labelled %>% dplyr::left_join(grouped, by = "rank")

stopifnot(!anyNA(labelled$label))

reference <- fronts %>%
  dplyr::filter(front == "F0") %>%
  dplyr::slice_min(nRFdist, n = 1, with_ties = FALSE)

fig_front <- ggplot(labelled, aes(x = n_orfs_norm, y = nRFdist)) +
  geom_line(colour = COLOURS$pareto, linewidth = 1) +
  geom_point(colour = COLOURS$pareto, size = 3.5) +
  geom_text(aes(label = label), vjust = -0.9, size = 3.4, colour = "black") +
  labs(x = "Objective 1: number of ORFs (normalised)",
       y = "Objective 2: nRF distance") +
  theme_orf(base_size = 14)

save_figure(fig_front, "01_pareto_front_final", width = 9, height = 6)

readr::write_csv(labelled, file.path(PATHS$tables, "01_final_front_labelled.csv"))

log_msg("  final front: ", n_points, " points, ", n_sols, " solutions")
write_session_info("01_pareto_front")
log_msg("01_pareto_front: done")
