# =============================================================================
# 11_collect_runs.R
# -----------------------------------------------------------------------------
# EN: Turns the saved optimiser runs into the tidy data files the analysis steps
#     consume: solutions.csv, pareto_fronts.csv and hypervolume.csv.
#
#     This is the step that was missing from the original project. The published
#     CSVs were produced by hand from .RData workspaces, so nothing recorded
#     which run each Pareto point came from, and the objective normalisation
#     applied at plotting time could not be inverted. Here the raw objective
#     values are written alongside the normalised ones and the normalisation
#     constants are written to their own file, so every published coordinate can
#     be traced back to a run and a formula.
#
#         Rscript R/11_collect_runs.R
#
#     Existing data files are backed up rather than overwritten, because
#     regenerating them from a fresh set of runs will not reproduce the exact
#     solutions in the published paper and the two should not be silently mixed.
#
# ES: Convierte las corridas guardadas del optimizador en los archivos ordenados
#     que consumen los pasos de analisis: solutions.csv, pareto_fronts.csv y
#     hypervolume.csv.
#
#     Este es el paso que faltaba en el proyecto original. Los CSV publicados se
#     produjeron a mano desde workspaces .RData, asi que nada registraba de que
#     corrida venia cada punto del Pareto, y la normalizacion de objetivos que se
#     aplicaba al graficar no se podia invertir. Aca los valores objetivo crudos
#     se escriben junto a los normalizados y las constantes de normalizacion van
#     a su propio archivo, asi cada coordenada publicada se puede rastrear hasta
#     una corrida y una formula.
#
#     Los archivos de datos existentes se respaldan en vez de sobrescribirse,
#     porque regenerarlos desde un conjunto nuevo de corridas no reproducira las
#     soluciones exactas del paper publicado y las dos cosas no deben mezclarse en
#     silencio.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")
source("R/opt_operators.R")

check_dependencies(quiet = TRUE)
log_msg("11_collect_runs: start")

suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })

files <- list.files(PATHS$runs, pattern = "\\.rds$", full.names = TRUE)
if (length(files) == 0) {
  stop("No runs found in ", PATHS$runs,
       "\nRun the optimisation first:\n  Rscript R/10_run_optimisation.R", call. = FALSE)
}

runs <- lapply(files, readRDS)
log_msg("  ", length(runs), " runs loaded")

# EN: Runs that searched different gene pools are not comparable. Checked here
#     rather than assumed, because the pool depends on how many alignments were
#     unpacked when the run started.
# ES: Las corridas que buscaron sobre conjuntos de genes distintos no son
#     comparables. Se verifica aca en vez de asumirse, porque el conjunto depende
#     de cuantos alineamientos estaban descomprimidos al arrancar la corrida.
`%||%` <- function(a, b) if (is.null(a)) b else a
pools <- unique(vapply(runs, function(r) r$pool_hash %||% NA_character_, character(1)))
if (length(pools) > 1) {
  warning("Runs searched ", length(pools), " different gene pools; ",
          "hypervolume comparisons across them are not meaningful.", call. = FALSE)
}

# -----------------------------------------------------------------------------
# 1. Front solutions, raw objectives
# -----------------------------------------------------------------------------

front_long <- dplyr::bind_rows(lapply(runs, function(r) {
  dplyr::bind_rows(lapply(seq_along(r$front), function(i) {
    s <- r$front[[i]]
    tibble::tibble(
      algorithm = r$algorithm, run = r$run, seed = r$seed,
      solution_in_run = i,
      k = s$k, rf_raw = s$score,
      genes = paste(sort(s$genes), collapse = " ")
    )
  }))
}))

readr::write_csv(front_long, file.path(PATHS$tables, "11_all_front_solutions.csv"))
log_msg("  ", nrow(front_long), " front solutions across all runs")

# -----------------------------------------------------------------------------
# 2. Normalisation, stated explicitly
# -----------------------------------------------------------------------------
# EN: Objective 1 is scaled by the configured size bounds, which are fixed and
#     known, not inferred from the data. Objective 2 is left raw and additionally
#     min-max scaled over the pooled runs, with both columns kept and the
#     constants written out. Rescaling against a moving population, as the
#     original did, is what made the published values impossible to recompute.
# ES: El objetivo 1 se escala con los limites de tamano configurados, que son
#     fijos y conocidos, no inferidos de los datos. El objetivo 2 se deja crudo y
#     ademas se escala min-max sobre el conjunto de corridas, conservando las dos
#     columnas y escribiendo las constantes. Reescalar contra una poblacion movil,
#     como hacia el original, es lo que volvio imposible recalcular los valores
#     publicados.

k_min <- OPT$min_genes; k_max <- OPT$max_genes
rf_min <- min(front_long$rf_raw); rf_max <- max(front_long$rf_raw)

norm_const <- tibble::tibble(
  objective = c("f1_panel_size", "f2_nrf"),
  formula   = c("(k - k_min) / (k_max - k_min)", "(rf - rf_min) / (rf_max - rf_min)"),
  lower     = c(k_min, rf_min),
  upper     = c(k_max, rf_max),
  source    = c("configured bounds (OPT$min_genes, OPT$max_genes)",
                "observed range across all pooled runs")
)
readr::write_csv(norm_const, file.path(PATHS$tables, "11_normalisation_constants.csv"))

front_long <- front_long %>%
  dplyr::mutate(
    f1 = (k - k_min) / (k_max - k_min),
    f2_raw = rf_raw,
    f2_scaled = if (rf_max > rf_min) (rf_raw - rf_min) / (rf_max - rf_min) else 0
  )

# -----------------------------------------------------------------------------
# 3. Hypervolume per run
# -----------------------------------------------------------------------------
# EN: Computed on the normalised objectives against a fixed reference point, so
#     every run is measured on the same scale. Implemented directly for the
#     two-objective case: sort by f1 and sum the rectangles under the front.
# ES: Se calcula sobre los objetivos normalizados contra un punto de referencia
#     fijo, asi toda corrida se mide en la misma escala. Implementado directo para
#     el caso de dos objetivos: ordenar por f1 y sumar los rectangulos bajo el
#     frente.
hypervolume_2d <- function(f1, f2, ref = OPT$hv_reference) {
  keep <- f1 <= ref[1] & f2 <= ref[2]
  if (!any(keep)) return(0)
  d <- data.frame(f1 = f1[keep], f2 = f2[keep])
  d <- d[order(d$f1, d$f2), ]
  # Keep only non-dominated points.
  best <- Inf; sel <- logical(nrow(d))
  for (i in seq_len(nrow(d))) { if (d$f2[i] < best) { sel[i] <- TRUE; best <- d$f2[i] } }
  d <- d[sel, ]
  hv <- 0; prev_f1 <- ref[1]
  for (i in rev(seq_len(nrow(d)))) {
    hv <- hv + (prev_f1 - d$f1[i]) * (ref[2] - d$f2[i])
    prev_f1 <- d$f1[i]
  }
  hv
}

hv <- front_long %>%
  dplyr::group_by(algorithm, run, seed) %>%
  dplyr::summarise(
    front_size  = dplyr::n(),
    best_rf     = min(rf_raw),
    smallest_k  = min(k),
    hypervolume = hypervolume_2d(f1, f2_scaled),
    .groups = "drop"
  ) %>%
  dplyr::arrange(algorithm, run)

# EN: Backed up before overwriting, for the same reason as the other two data
#     files: a fresh set of runs is a new experiment and must not silently
#     replace the numbers the paper reports.
# ES: Se respalda antes de sobrescribir, por la misma razon que los otros dos
#     archivos de datos: un conjunto nuevo de corridas es un experimento nuevo y
#     no debe reemplazar en silencio los numeros que reporta el paper.
hv_path <- file.path(PATHS$data, "hypervolume.csv")
if (file.exists(hv_path)) {
  bak <- sub("\\.csv$", paste0("_published_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"), hv_path)
  file.copy(hv_path, bak, overwrite = FALSE)
  log_msg("    previous hypervolume.csv kept as ", basename(bak))
}
readr::write_csv(hv, hv_path)
log_msg("  hypervolume by algorithm:")
print(as.data.frame(hv %>% dplyr::group_by(algorithm) %>%
  dplyr::summarise(runs = dplyr::n(), median_hv = round(stats::median(hypervolume), 4),
                   min_hv = round(min(hypervolume), 4), max_hv = round(max(hypervolume), 4),
                   .groups = "drop")), row.names = FALSE)

# -----------------------------------------------------------------------------
# 4. Pooled Pareto front and solutions.csv
# -----------------------------------------------------------------------------

pooled <- front_long %>%
  dplyr::filter(algorithm == "NSGA-II") %>%
  dplyr::distinct(genes, .keep_all = TRUE)

keep <- rep(TRUE, nrow(pooled))
for (i in seq_len(nrow(pooled))) {
  for (j in seq_len(nrow(pooled))) {
    if (i == j) next
    if (pooled$k[j] <= pooled$k[i] && pooled$rf_raw[j] <= pooled$rf_raw[i] &&
        (pooled$k[j] < pooled$k[i] || pooled$rf_raw[j] < pooled$rf_raw[i])) {
      keep[i] <- FALSE; break
    }
  }
}
pooled <- pooled[keep, ] %>% dplyr::arrange(k)

log_msg("  pooled NSGA-II Pareto front: ", nrow(pooled), " non-dominated solutions")

pareto_out <- pooled %>%
  dplyr::transmute(front = "pooled", n_orfs_norm = f1, nRFdist = f2_scaled,
                   nRFdist_raw = rf_raw, k, run, seed)

solutions_out <- dplyr::bind_rows(lapply(seq_len(nrow(pooled)), function(i) {
  tibble::tibble(solution = paste0("S", i),
                 orf = strsplit(pooled$genes[i], " ")[[1]],
                 source = "pareto_front")
}))

# EN: Back up rather than overwrite. A fresh set of runs is a new experiment.
# ES: Respaldar en vez de sobrescribir. Un conjunto nuevo de corridas es un
#     experimento nuevo.
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
for (f in c(FILES$pareto, FILES$solutions)) {
  if (file.exists(f)) {
    bak <- sub("\\.csv$", paste0("_published_", stamp, ".csv"), f)
    file.copy(f, bak, overwrite = FALSE)
    log_msg("    previous ", basename(f), " kept as ", basename(bak))
  }
}

readr::write_csv(pareto_out,    FILES$pareto)
readr::write_csv(solutions_out, FILES$solutions)

log_msg("  wrote ", basename(FILES$pareto), " and ", basename(FILES$solutions))
write_session_info("11_collect_runs")
log_msg("11_collect_runs: done")
