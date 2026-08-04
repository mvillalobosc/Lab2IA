# =============================================================================
# run_all.R
# -----------------------------------------------------------------------------
# EN: Runs the whole pipeline in order. Each step is independent and reads only
#     from data/derived, so a single step can also be re-run on its own.
#
#     Usage from the repository root:
#         Rscript run_all.R
#         Rscript run_all.R 04 05        # only these steps
#
#     Approximate runtime on a single core: about an hour, dominated by
#     part-of-speech tagging in step 04 and sentence-level sentiment in step 05.
#
# ES: Corre todo el pipeline en orden. Cada paso es independiente y lee solo de
#     data/derived, asi que un paso tambien puede volver a correrse solo.
#
#     Uso desde la raiz del repositorio:
#         Rscript run_all.R
#         Rscript run_all.R 04 05        # solo estos pasos
#
#     Tiempo aproximado en un solo nucleo: cerca de una hora, dominado por el
#     etiquetado morfosintactico del paso 04 y el sentimiento por oracion del
#     paso 05.
# =============================================================================

source("R/00_config.R")

STEPS <- c(
  "01" = "R/01_build_corpus.R",
  "02" = "R/02_lexical_diversity.R",
  "03" = "R/03_readability.R",
  "04" = "R/04_pos_analysis.R",
  "05" = "R/05_sentiment.R",
  "06" = "R/06_emotions.R",
  "07" = "R/07_stylometry.R",
  "08" = "R/08_umap.R",
  "09" = "R/09_sensitivity.R"
)

args <- commandArgs(trailingOnly = TRUE)
selected <- if (length(args) == 0) names(STEPS) else args

unknown <- setdiff(selected, names(STEPS))
if (length(unknown) > 0) {
  stop("Unknown step(s): ", paste(unknown, collapse = ", "),
       "\nAvailable: ", paste(names(STEPS), collapse = ", "), call. = FALSE)
}

check_dependencies()

if (!file.exists(UDPIPE_MODEL) && "04" %in% selected) {
  stop("UDPipe model missing. Run: Rscript scripts/download_udpipe_model.R",
       call. = FALSE)
}

started <- Sys.time()
timings <- list()

for (s in selected) {
  script <- STEPS[[s]]
  message("\n", strrep("=", 78))
  message("STEP ", s, ": ", script)
  message(strrep("=", 78))

  t0 <- Sys.time()
  # EN: A new environment per step so no object leaks between analyses.
  # ES: Un entorno nuevo por paso para que ningun objeto se filtre entre analisis.
  result <- try(source(script, local = new.env(), echo = FALSE), silent = FALSE)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  timings[[s]] <- list(
    step = s, script = script, minutes = elapsed,
    status = if (inherits(result, "try-error")) "FAILED" else "ok"
  )

  if (inherits(result, "try-error")) {
    message("\nSTEP ", s, " FAILED after ", round(elapsed, 1), " min.")
    message("Later steps depend on earlier ones; stopping here.")
    break
  }

  invisible(gc(verbose = FALSE))
  message("STEP ", s, " completed in ", round(elapsed, 1), " min")
}

# EN: Consolidate the outputs so the repository stays under the 100-file limit
#     of the GitHub web uploader. Only when the full pipeline ran, since a
#     partial run would bundle an incomplete set of tables.
# ES: Consolida las salidas para que el repositorio quede bajo el limite de 100
#     archivos del uploader web de GitHub. Solo cuando corrio el pipeline
#     completo, ya que una corrida parcial juntaria un conjunto incompleto de
#     tablas.
if (length(args) == 0 && !any(vapply(timings, function(x) x$status == "FAILED", logical(1)))) {
  message("\n", strrep("=", 78))
  message("BUNDLING OUTPUTS")
  message(strrep("=", 78))
  try(source("scripts/bundle_outputs.R", local = new.env()), silent = FALSE)
}

total <- as.numeric(difftime(Sys.time(), started, units = "mins"))

summary_df <- do.call(rbind, lapply(timings, function(x) {
  data.frame(step = x$step, script = basename(x$script),
             minutes = round(x$minutes, 2), status = x$status)
}))

message("\n", strrep("=", 78))
message("PIPELINE SUMMARY")
message(strrep("=", 78))
print(summary_df, row.names = FALSE)
message("Total: ", round(total, 1), " min")

utils::write.csv(summary_df, file.path(PATHS$logs, "pipeline_timings.csv"),
                 row.names = FALSE)

if (any(summary_df$status == "FAILED")) quit(status = 1)
