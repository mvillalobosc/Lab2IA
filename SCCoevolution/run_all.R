# =============================================================================
# run_all.R
# -----------------------------------------------------------------------------
# EN: Runs the whole pipeline in order.
#         Rscript run_all.R           # everything
#         Rscript run_all.R 01 03     # only these steps
#     Step 04 is the slow one: it reads 106 alignments of 1011 taxa each.
# ES: Corre todo el pipeline en orden.
#         Rscript run_all.R           # todo
#         Rscript run_all.R 01 03     # solo estos pasos
#     El paso 04 es el lento: lee 106 alineamientos de 1011 taxones cada uno.
# =============================================================================

source("R/00_config.R")

# EN: Steps 10 and 11 re-run the optimisation and rebuild the data files from
#     scratch. They are excluded from the default sequence because a full run is
#     31 repetitions of each algorithm over 6015 alignments and takes many hours,
#     and because rebuilding the data files replaces the published solutions with
#     new ones. Ask for them explicitly:
#         Rscript run_all.R 10 11
# ES: Los pasos 10 y 11 vuelven a correr la optimizacion y reconstruyen los
#     archivos de datos desde cero. Quedan fuera de la secuencia por defecto
#     porque una corrida completa son 31 repeticiones de cada algoritmo sobre
#     6015 alineamientos y toma muchas horas, y porque reconstruir los datos
#     reemplaza las soluciones publicadas por otras nuevas. Hay que pedirlos:
#         Rscript run_all.R 10 11
STEPS <- c(
  "10" = "R/10_run_optimisation.R",
  "11" = "R/11_collect_runs.R",
  "01" = "R/01_pareto_front.R",
  "02" = "R/02_hypervolume.R",
  "03" = "R/03_solution_overlap.R",
  "04" = "R/04_build_trees.R",
  "06" = "R/06_verify_front.R"
  # 05_colour_trees.R takes a tree file as an argument and is run on demand:
  #   Rscript R/05_colour_trees.R trees/sol2_tree.json
)

DEFAULT_STEPS <- c("01", "02", "03", "04", "06")

args     <- commandArgs(trailingOnly = TRUE)
selected <- if (length(args) == 0) DEFAULT_STEPS else args

unknown <- setdiff(selected, names(STEPS))
if (length(unknown) > 0) {
  stop("Unknown step(s): ", paste(unknown, collapse = ", "),
       "\nAvailable: ", paste(names(STEPS), collapse = ", "), call. = FALSE)
}

check_dependencies()

started <- Sys.time()
timings <- list()

for (s in selected) {
  script <- STEPS[[s]]
  message("\n", strrep("=", 78))
  message("STEP ", s, ": ", script)
  message(strrep("=", 78))

  t0 <- Sys.time()
  # A fresh environment per step so no object leaks between analyses.
  res <- try(source(script, local = new.env(), echo = FALSE), silent = FALSE)
  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  timings[[s]] <- data.frame(
    step = s, script = basename(script), minutes = round(mins, 2),
    status = if (inherits(res, "try-error")) "FAILED" else "ok"
  )

  if (inherits(res, "try-error")) {
    message("\nSTEP ", s, " FAILED after ", round(mins, 1), " min. Stopping.")
    break
  }
  invisible(gc(verbose = FALSE))
}

summary_df <- do.call(rbind, timings)
message("\n", strrep("=", 78))
message("PIPELINE SUMMARY")
message(strrep("=", 78))
print(summary_df, row.names = FALSE)
message("Total: ", round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), " min")

utils::write.csv(summary_df, file.path(PATHS$logs, "pipeline_timings.csv"), row.names = FALSE)
if (any(summary_df$status == "FAILED")) quit(status = 1)
