# =============================================================================
# 06_verify_front.R
# -----------------------------------------------------------------------------
# EN: Recomputes both objective values for every published solution, from the
#     alignments and the reference tree, and compares them against the published
#     Pareto front.
#
#     WHAT THIS DOES AND DOES NOT ESTABLISH
#     It does not reproduce the search: the MOSA and NSGA-II implementation is
#     not in this repository, so the fifteen solutions are taken as given. What
#     it establishes is that each published solution really sits where the
#     published front places it. If the recomputed points fall on the front, the
#     front is verified. If they do not, either the objective definitions used
#     here differ from the ones the optimiser used, or the reported values are
#     wrong, and the size of the gap tells you which.
#
#     This is the strongest reproducibility check available until the optimiser
#     source is added, and it is worth running for that reason: a Pareto front is
#     a claim about specific coordinates, and coordinates can be checked.
#
# ES: Recalcula los dos valores objetivo de cada solucion publicada, a partir de
#     los alineamientos y el arbol de referencia, y los compara contra el frente
#     de Pareto publicado.
#
#     QUE ESTABLECE Y QUE NO
#     No reproduce la busqueda: la implementacion de MOSA y NSGA-II no esta en
#     este repositorio, asi que las quince soluciones se toman como dadas. Lo que
#     establece es que cada solucion publicada esta realmente donde el frente
#     publicado la ubica. Si los puntos recalculados caen sobre el frente, el
#     frente queda verificado. Si no, o las definiciones de objetivo usadas aca
#     difieren de las que uso el optimizador, o los valores reportados estan mal,
#     y el tamano de la brecha dice cual de las dos.
#
#     Es el chequeo de reproducibilidad mas fuerte disponible hasta que se agregue
#     el codigo del optimizador, y por eso vale la pena correrlo: un frente de
#     Pareto es una afirmacion sobre coordenadas concretas, y las coordenadas se
#     pueden verificar.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")
source("R/utils_objectives.R")

check_dependencies(quiet = TRUE)
log_msg("06_verify_front: start")

suppressPackageStartupMessages({
  library(ape); library(phangorn); library(dplyr); library(readr); library(ggplot2)
})

sols      <- read_solutions()
pareto    <- readr::read_csv(FILES$pareto, show_col_types = FALSE)
reference <- ape::read.tree(file.path(PATHS$trees, "ref_tree.nwk"))

log_msg("  reference tree: ", length(reference$tip.label), " tips")

ensure_alignments(required_orfs = unique(unlist(sols)))

# EN: Normalisation constants for objective 1, inferred from the observed panel
#     sizes across the Pareto solutions and reported so the assumption is
#     explicit. The reference solution is excluded because it is not part of the
#     search space the optimiser normalised over.
# ES: Constantes de normalizacion del objetivo 1, inferidas de los tamanos de
#     panel observados en las soluciones del Pareto y reportadas para que el
#     supuesto quede explicito.
pareto_sols <- sols[names(sols) != PARAMS$reference_solution]
k_sizes <- lengths(pareto_sols)
k_min <- min(k_sizes); k_max <- max(k_sizes)
log_msg("  objective 1 normalised over panel sizes ", k_min, " to ", k_max)

results <- list()
for (s in names(sols)) {
  log_msg("  evaluating ", s, " (", length(sols[[s]]), " ORFs)")
  r <- try(evaluate_subset(sols[[s]], reference, k_min, k_max), silent = TRUE)
  if (inherits(r, "try-error")) {
    log_msg("    FAILED: ", conditionMessage(attr(r, "condition")))
    next
  }
  results[[s]] <- r %>% dplyr::mutate(solution = s, .before = 1)
}

recomputed <- dplyr::bind_rows(results)

# EN: If every evaluation failed, bind_rows returns an empty frame with no
#     columns and the next filter fails with a confusing "object not found".
#     Stopping here says what actually went wrong.
# ES: Si toda evaluacion fallo, bind_rows devuelve un marco vacio sin columnas y
#     el filtro siguiente falla con un confuso "object not found". Detenerse aca
#     dice que paso de verdad.
if (nrow(recomputed) == 0) {
  stop("No solution could be evaluated. Check that the alignments are unpacked ",
       "and that evaluate_subset() runs without error.", call. = FALSE)
}

# -----------------------------------------------------------------------------
# Compare against the published final front
# -----------------------------------------------------------------------------

published <- pareto %>%
  dplyr::filter(front == max(front)) %>%
  dplyr::arrange(n_orfs_norm)

# EN: Solutions are matched to published front points by panel-size rank, not by
#     proximity in objective space and not by row order.
#
#     An earlier version of this script used nearest-neighbour matching. That was
#     wrong in a way that mattered: because the recomputed points do not lie on
#     the published front, several solutions were assigned the same nearest point,
#     which made the per-solution comparison meaningless and produced spurious
#     duplicate published values. Rank matching is well defined here because
#     objective 1 is a strictly increasing function of panel size, so ordering
#     solutions by the number of ORFs they request reproduces the order of the
#     front exactly. Solutions that share a panel size share a front point, which
#     is checked rather than assumed.
# ES: Las soluciones se emparejan con los puntos del frente publicado por rango de
#     tamano de panel, no por cercania en el espacio de objetivos ni por orden de
#     fila.
#
#     Una version anterior de este script usaba emparejamiento por vecino mas
#     cercano. Estaba mal de una forma que importaba: como los puntos recalculados
#     no caen sobre el frente publicado, varias soluciones quedaban asignadas al
#     mismo punto, lo que volvia sin sentido la comparacion por solucion y
#     producia valores publicados duplicados espurios. El emparejamiento por rango
#     esta bien definido aca porque el objetivo 1 es una funcion estrictamente
#     creciente del tamano de panel, asi que ordenar las soluciones por numero de
#     ORFs pedidos reproduce exactamente el orden del frente. Las soluciones que
#     comparten tamano comparten punto, lo que se verifica en vez de asumirse.
ranked <- recomputed %>%
  dplyr::filter(solution != PARAMS$reference_solution) %>%
  dplyr::arrange(n_orfs_requested) %>%
  dplyr::mutate(rank = dplyr::dense_rank(n_orfs_requested))

n_ranks <- max(ranked$rank)
if (n_ranks != nrow(published)) {
  stop("Rank matching failed: ", n_ranks, " distinct panel sizes but ",
       nrow(published), " published front points. The published front does not ",
       "correspond one-to-one with the solution set.", call. = FALSE)
}

comparison <- ranked %>%
  dplyr::mutate(
    published_f1 = published$n_orfs_norm[rank],
    published_f2 = published$nRFdist[rank],
    f1_diff      = f1_panel_size - published_f1,
    f2_diff      = f2_nrf - published_f2,
    distance_to_front = sqrt(f1_diff^2 + f2_diff^2)
  ) %>%
  dplyr::arrange(dplyr::desc(distance_to_front))

# EN: Objective 1 is fully specified by the panel-size bounds, so it can be
#     checked exactly. Objective 2 depends on a normalisation applied over the
#     optimiser's full generation history, which the released data does not
#     contain, so only its ordering can be checked.
# ES: El objetivo 1 esta completamente especificado por los limites de tamano de
#     panel, asi que se puede verificar exacto. El objetivo 2 depende de una
#     normalizacion aplicada sobre todo el historial de generaciones del
#     optimizador, que los datos liberados no contienen, asi que solo se puede
#     verificar su ordenamiento.
f1_error <- max(abs(comparison$f1_diff))
f2_rho   <- stats::cor(comparison$f2_nrf, comparison$published_f2, method = "spearman")

verdict <- tibble::tibble(
  objective = c("f1_panel_size", "f2_nrf"),
  check     = c("exact value", "ordering only"),
  statistic = c("max absolute error", "Spearman correlation"),
  value     = c(f1_error, f2_rho),
  verified  = c(f1_error < 0.01, f2_rho > 0.95),
  note = c(
    "f1 = (k - 1) / (k_max - 1); fully determined by the panel-size bounds",
    "published f2 is the raw nRF rescaled over the optimiser's generation history, which is not in the released data, so absolute values cannot be recomputed"
  )
)

readr::write_csv(verdict, file.path(PATHS$tables, "06_verification_verdict.csv"))

log_msg("  objective 1: max absolute error ", signif(f1_error, 3),
        if (f1_error < 0.01) "  VERIFIED" else "  MISMATCH")
log_msg("  objective 2: Spearman ", round(f2_rho, 4),
        "  (ordering ", if (f2_rho > 0.95) "reproduced" else "NOT reproduced",
        "; absolute scale not recomputable from the released data)")

readr::write_csv(recomputed,  file.path(PATHS$tables, "06_recomputed_objectives.csv"))
readr::write_csv(comparison,  file.path(PATHS$tables, "06_front_verification.csv"))

log_msg("  recomputed vs published, worst five:")
print(as.data.frame(comparison %>%
  dplyr::transmute(solution, n_orfs_used,
                   f1 = round(f1_panel_size, 4), f1_pub = round(published_f1, 4),
                   f2 = round(f2_nrf, 4),        f2_pub = round(published_f2, 4),
                   gap = round(distance_to_front, 4)) %>%
  utils::head(5)), row.names = FALSE)

# EN: Re-running the optimiser through steps 10 and 11 stores the raw objective
#     values and the normalisation constants, so a front produced by this
#     pipeline can be verified on both objectives rather than only on ordering.
# ES: Volver a correr el optimizador con los pasos 10 y 11 guarda los valores
#     objetivo crudos y las constantes de normalizacion, asi un frente producido
#     por este pipeline se puede verificar en los dos objetivos y no solo en el
#     ordenamiento.
log_msg("  to verify both objectives exactly, regenerate the front with: Rscript run_all.R 10 11")

fig <- ggplot() +
  geom_line(data = published, aes(x = n_orfs_norm, y = nRFdist),
            colour = COLOURS$pareto, linewidth = 1) +
  geom_point(data = published, aes(x = n_orfs_norm, y = nRFdist),
             colour = COLOURS$pareto, size = 3.5) +
  geom_point(data = comparison, aes(x = f1_panel_size, y = f2_nrf),
             colour = COLOURS$reference, size = 2.6, shape = 4, stroke = 1.1) +
  labs(x = "Objective 1: number of ORFs (normalised)",
       y = "Objective 2: nRF distance",
       subtitle = "Line and circles: published front. Crosses: recomputed from the alignments.") +
  theme_orf(base_size = 13)

save_figure(fig, "06_front_verification", width = 9, height = 6)

write_session_info("06_verify_front")
log_msg("06_verify_front: done")
