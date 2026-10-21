## ============================================================================
## correr_post_hoc.R
## ----------------------------------------------------------------------------
## Corre, en orden, los análisis post hoc del artículo sobre ../salida (las
## salidas de correr_todo.R) y deja resultados/, estadistica/ y figuras/.
## Los tres pasos lentos (reajuste de Deodato y Melcher y cota del lector
## periódico en el paradigma de Haarlem et al., unas tres horas con un núcleo)
## se saltan con SALTAR_LENTOS=1, y entonces se usan los resultados que ya
## están en resultados/.
##
## Runs, in order, the post hoc analyses of the paper on ../salida (the
## outputs of correr_todo.R) and writes resultados/, estadistica/ and
## figuras/. The three slow steps (refit of Deodato and Melcher and bound of
## the periodic reader in the paradigm of Haarlem et al., about three hours on
## one core) are skipped with SALTAR_LENTOS=1, and then the results already
## stored in resultados/ are used.
##
## Uso / usage (desde post_hoc/):
##   Rscript correr_post_hoc.R                  todo / everything
##   SALTAR_LENTOS=1 Rscript correr_post_hoc.R  sin los pasos lentos / without the slow steps
##   N_CORES=8 Rscript correr_post_hoc.R        núcleos para el reajuste / cores for the refit
## ============================================================================
if (!file.exists("cargar_funciones.R")) stop("Corre este script desde la carpeta post_hoc / run it from the post_hoc folder")
dir.create("resultados", showWarnings = FALSE)
dir.create("estadistica", showWarnings = FALSE)
dir.create("figuras", showWarnings = FALSE)
saltar <- Sys.getenv("SALTAR_LENTOS", "") == "1"
rscript <- file.path(R.home("bin"), "Rscript")
paso <- function(script, ...) {
  cat(sprintf("\n==== %s  %s ====\n", format(Sys.time(), "%H:%M:%S"), script))
  estado <- system2(rscript, c(script, ...))
  if (!identical(as.integer(estado), 0L)) stop(script, " terminó con error / ended with an error")
}
paso("rodillas_ausencias.R")                     # rodillas con costo en log10 y ausencias
paso("mimetismo.R")                              # mimetismo y fallas de optimización
if (!saltar) paso("reajuste_deodato.R")          # lento: 152 ajustes
paso("resumen_deodato.R")
if (!saltar) paso("haarlem_cota.R")              # lento: GA para T de 10 a 120 ms
if (!saltar) paso("haarlem_rejilla.R")           # lento: rejilla de 540 combinaciones
paso("cota_final.R")
paso("analisis.R")                               # estadística (menos de un minuto)
paso("analisis_complementario.R")
paso("figuras.R")                                # Fig. 2 a 10 y A1 a A6
## Fig. 1 es un diagrama TikZ / Fig. 1 is a TikZ diagram
estado <- system2("pdflatex", c("-interaction=nonstopmode", "-output-directory=figuras", "Fig1.tex"), stdout = FALSE)
if (!identical(as.integer(estado), 0L)) warning("pdflatex no pudo compilar Fig1.tex / could not compile Fig1.tex")
unlink(file.path("figuras", c("Fig1.aux", "Fig1.log")))
cat("\nListo / done.\n")
