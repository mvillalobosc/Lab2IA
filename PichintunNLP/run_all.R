#!/usr/bin/env Rscript
# =============================================================================
# run_all.R  Ejecuta el pipeline completo de principio a fin
# =============================================================================
# Uso:
#   Rscript run_all.R              modulos 1 a 8
#   Rscript run_all.R 3 4 5        solo los modulos indicados
# Cada modulo lee sus insumos desde data/processed y guarda ahi sus resultados,
# de modo que un modulo puede reejecutarse sin repetir los anteriores.
# =============================================================================

t0 <- Sys.time()

root <- tryCatch(dirname(normalizePath(sub("^--file=", "", grep("^--file=",
         commandArgs(trailingOnly = FALSE), value = TRUE)[1]))),
       error = function(e) getwd())
if (is.na(root) || !nzchar(root)) root <- getwd()
setwd(root)

source(file.path("R", "lib", "packages.R"))
load_packages()
source(file.path("R", "00_config.R"))
source(file.path("R", "lib", "io.R"))
source(file.path("R", "lib", "text.R"))
source(file.path("R", "lib", "stats_helpers.R"))

MODULOS <- c(
  "1" = "01_ingest.R",
  "2" = "02_clean.R",
  "3" = "03_frequency.R",
  "4" = "04_topics.R",
  "5" = "05_sentiment.R",
  "6" = "06_readability.R",
  "7" = "07_popularity.R",
  "8" = "08_export.R"
)

args <- commandArgs(trailingOnly = TRUE)
sel <- if (length(args) == 0) names(MODULOS) else args
desconocidos <- setdiff(sel, names(MODULOS))
if (length(desconocidos)) {
  stop("Modulo(s) desconocido(s): ", paste(desconocidos, collapse = ", "),
       ". Validos: ", paste(names(MODULOS), collapse = ", "))
}

for (m in sel) source(file.path("R", MODULOS[[m]]))

log_step("Pipeline finalizado en ",
         round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")
log_msg("Figuras: outputs/figures  |  Tablas: outputs/tables")
