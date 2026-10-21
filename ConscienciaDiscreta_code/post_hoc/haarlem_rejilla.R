## ============================================================================
## haarlem_rejilla.R
## ----------------------------------------------------------------------------
## Comprobación independiente de la cota del lector periódico en el paradigma
## de Haarlem et al.: rejilla sobre tau, theta_p, m/T y w para cada periodo T;
## las tres mejores combinaciones se reevalúan en el banco de validación.
##
## Independent check of the bound of the periodic reader in the paradigm of
## Haarlem et al.: a grid over tau, theta_p, m/T and w for each period T; the
## three best combinations are re-evaluated on the validation bank.
##
## Uso / usage (desde post_hoc/): Rscript haarlem_rejilla.R [T1 T2 ...]   (por defecto 30, 40, 50, 60, 80, 100 y 120 ms)
## Salida / output: resultados/haarlem_rejilla_30_120.csv
## ============================================================================
src <- readLines("haarlem_cota.R")
eval(parse(text = src[1:(grep("^co <- cotas_arq", src) - 1)]))   # funciones y banco, sin el GA
args <- commandArgs(trailingOnly = TRUE)
Ts <- if (length(args) > 0) as.numeric(args) else c(30, 40, 50, 60, 80, 100, 120)
rej <- expand.grid(tau = c(3, 5, 8, 12, 18, 27), theta_p = c(0.25, 0.35, 0.45, 0.55, 0.65, 0.75),
                   mT = c(0.6, 1.05, 1.3, 1.6, 1.9), w = c(1, 3, 8))
res <- list()
for (Tp in Ts) {
  t0 <- Sys.time()
  b <- banco_haarlem(ISIS, 40, cfg_h, semilla = 7000 + Tp)
  u <- apply(rej, 1, function(r) {
    th <- c(tau = r[["tau"]], theta_p = r[["theta_p"]], m = min(250, r[["mT"]] * Tp), w = r[["w"]], T = Tp)
    x <- umbral_75(simular_agente(th, "periodica", b, cfg_h), ISIS); if (is.na(x$umbral)) Inf else x$umbral })
  top <- order(u)[1:3]
  bv <- banco_haarlem(ISIS, 200, cfg_h, semilla = 9000 + Tp)
  val <- sapply(top, function(k) { r <- rej[k, ]
    th <- c(tau = r$tau, theta_p = r$theta_p, m = min(250, r$mT * Tp), w = r$w, T = Tp)
    x <- umbral_75(simular_agente(th, "periodica", bv, cfg_h), ISIS); if (is.na(x$umbral)) Inf else x$umbral })
  k <- top[which.min(val)]
  res[[length(res) + 1]] <- data.frame(T = Tp, umbral_rejilla_entrenamiento = u[k], umbral_rejilla_validado = min(val),
                                        rej[k, ], minutos = as.numeric(difftime(Sys.time(), t0, units = "mins")))
  print(tail(res[[length(res)]], 1), row.names = FALSE, digits = 4)
  write.csv(do.call(rbind, res), file.path(CFG$carpeta, sprintf("haarlem_rejilla_%s.csv", paste(range(Ts), collapse = "_"))), row.names = FALSE)
}
