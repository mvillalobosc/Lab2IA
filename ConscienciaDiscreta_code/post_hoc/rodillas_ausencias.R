## ============================================================================
## rodillas_ausencias.R
## ----------------------------------------------------------------------------
## Soluciones rodilla de cada arquitectura y régimen (agentes funcionales del
## frente validado), con el costo en escala log10 también en la distancia al
## punto ideal, como describe el artículo (Sect. 3.5). En el script principal,
## rodilla() recibe el costo en lecturas por segundo con mínimos y máximos en
## log10, por eso salida/rodillas.csv y salida/ausencias.csv no son las del
## artículo. Con estas rodillas se repite la demostración de ausencias.
##
## Knee solutions of each architecture and regime (functional agents of the
## validated front), with the cost in log10 scale also in the distance to the
## ideal point, as the paper describes (Sect. 3.5). In the main script,
## rodilla() receives the cost in reads per second with log10 minima and
## maxima, so salida/rodillas.csv and salida/ausencias.csv are not the ones of
## the paper. The demonstration of absences is repeated with these knees.
##
## Uso / usage (desde post_hoc/): Rscript rodillas_ausencias.R [../salida]
## Salidas / outputs: resultados/rodillas_corregidas.csv,
##   resultados/ausencias_corregidas/ausencias.csv y fig5_absences.png
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
D <- if (length(args) > 0) args[1] else "../salida"
source("cargar_funciones.R", encoding = "UTF-8")
fv <- leer_csv(file.path(D, "frentes_validados.csv"))
obj <- c("error", "umbral", "latencia", "costo")
rod <- do.call(rbind, lapply(c("limpio", "rafagas"), function(g) {
  d <- fv[fv$regimen == g & fv$funcional, ]
  Flog <- as.matrix(d[, obj]); Flog[, "costo"] <- log10(pmax(Flog[, "costo"], 1))
  mn <- apply(Flog, 2, min); mx <- apply(Flog, 2, max); mx[mx == mn] <- mn[mx == mn] + 1e-9
  do.call(rbind, lapply(CFG$arquitecturas, function(a) {
    sel <- which(d$arquitectura == a)
    k <- rodilla(Flog[sel, , drop = FALSE], mn, mx)
    d[sel[k], ]
  }))
}))
rownames(rod) <- NULL
write.csv(rod, file.path(CFG$carpeta, "rodillas_corregidas.csv"), row.names = FALSE)
print(rod[, c("arquitectura", "regimen", "tau", "theta_p", "m", "w", "T", "theta_g", "r", "A_mod", "T_mod",
              "error", "umbral", "latencia", "costo")], digits = 4, row.names = FALSE)
CFG$carpeta <- file.path(CFG$carpeta, "ausencias_corregidas"); dir.create(CFG$carpeta, showWarnings = FALSE)
au <- pregunta_3(rod, CFG)
## reloj sin hueco, como referencia para el error de reloj del lector periódico
r <- rod[rod$arquitectura == "periodica" & rod$regimen == "limpio", ]
Tp <- round(r$T)
cat("\nperiodo redondeado:", Tp, " lecturas sin hueco en 1500 ms:", floor(1500 / Tp),
    " error de reloj sin hueco:", floor(1500 / Tp) * Tp - 1500, "\n")
