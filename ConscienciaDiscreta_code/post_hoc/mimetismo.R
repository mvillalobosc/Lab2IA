## ============================================================================
## mimetismo.R
## ----------------------------------------------------------------------------
## Verosimilitud de cada participante sintético bajo su generador con los
## parámetros verdaderos, evaluada con el mismo banco de validación que usa
## ajustar_participante (semilla 1 + 777). Separa el mimetismo (otra
## arquitectura explica los datos mejor que el generador verdadero) de la
## falla de optimización (el ajuste del generador queda por debajo de sus
## propios parámetros verdaderos).
##
## Log-likelihood of each synthetic observer under its true generator and true
## parameters, evaluated with the same validation bank used by
## ajustar_participante. It separates mimicry (another architecture explains
## the data better than the true generator) from optimisation failures (the
## fitted generator stays below its own true parameters).
##
## Uso / usage (desde post_hoc/): Rscript mimetismo.R [../salida]
## Salida / output: resultados/mimetismo.csv
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
D <- if (length(args) > 0) args[1] else "../salida"
source("cargar_funciones.R", encoding = "UTF-8")
ap <- leer_csv(file.path(D, "ajuste_participantes.csv"))
filas <- list()
for (gen in CFG$arquitecturas) {
  datos <- normalizar_datos(read.csv(file.path(D, "datos", sprintf("sintetico_%s.csv", gen))))
  verd <- read.csv(file.path(D, "datos", sprintf("sintetico_%s_parametros.csv", gen)))
  for (i in seq_len(nrow(verd))) {
    p <- verd$participante[i]
    dp <- datos[datos$participante == p, ]
    dp$clave <- paste(dp$n_pulsos, dp$isi)
    conteos <- aggregate(cbind(k_dos = respuesta == 2, n = 1) ~ clave, data = dp, FUN = sum)
    isis_p <- sort(unique(dp$isi[dp$n_pulsos == 2]))
    cfg_val <- CFG; cfg_val$ajuste$n_un_pulso <- CFG$ajuste$n_val_un_pulso; cfg_val$ajuste$n_por_isi <- CFG$ajuste$n_val_por_isi
    banco_v <- banco_ajuste(isis_p, cfg_val, 1 + 777)
    th <- unlist(verd[i, nombres_theta(gen)])
    ll <- loglik_participante(th, gen, conteos, banco_v, CFG, CFG$ajuste$n_val_por_isi)
    k <- length(th)
    a <- ap[ap$dataset == paste0("sintetico_", gen) & ap$participante == p, ]
    filas[[length(filas) + 1]] <- data.frame(generador = gen, participante = p, ll_verdadero = ll, aic_verdadero = 2 * k - 2 * ll,
      ll_ajuste_generador = a$loglik[a$arquitectura == gen], aic_ajuste_generador = a$aic[a$arquitectura == gen],
      mejor_ajustado = a$arquitectura[a$mejor][1], aic_mejor = min(a$aic),
      aic_mejor_alternativa = min(a$aic[a$arquitectura != gen]),
      arq_mejor_alternativa = a$arquitectura[a$arquitectura != gen][which.min(a$aic[a$arquitectura != gen])])
  }
}
r <- do.call(rbind, filas)
r$falla_optimizacion <- r$ll_ajuste_generador < r$ll_verdadero - 2
r$mimetismo <- r$aic_mejor_alternativa < r$aic_verdadero
write.csv(r, file.path(CFG$carpeta, "mimetismo.csv"), row.names = FALSE)
print(aggregate(cbind(falla_optimizacion, mimetismo) ~ generador, data = r, FUN = sum))
cat("\nAIC verdadero - AIC del ajuste del generador (mediana por generador):\n")
print(aggregate(I(aic_verdadero - aic_ajuste_generador) ~ generador, data = r, FUN = median))
cat("\nmejor alternativa cuando hay mimetismo:\n"); print(table(r$generador[r$mimetismo], r$arq_mejor_alternativa[r$mimetismo]))
