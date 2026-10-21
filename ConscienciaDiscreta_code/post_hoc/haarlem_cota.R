## ============================================================================
## haarlem_cota.R
## ----------------------------------------------------------------------------
## Cota inferior del umbral de un lector periódico en el paradigma de Haarlem
## et al. (2024): destellos de 40 ms separados por una pausa en blanco (ISI),
## ensayos de un destello con la misma duración total (80 + ISI ms) y umbral
## definido como el ISI con 75 % de aciertos. Para cada periodo T se buscan
## los demás parámetros (tau, theta_p, m, w) que dan el umbral más bajo; el
## mejor se reevalúa en un banco independiente y más grande.
##
## Lower bound of the threshold of a periodic reader in the paradigm of
## Haarlem et al. (2024): 40 ms flashes separated by a blank ISI, single
## flashes of the same total duration (80 + ISI ms), and threshold defined as
## the ISI with 75% correct answers. For each period T, GA searches the other
## parameters (tau, theta_p, m, w) that give the lowest threshold, and the best
## solution is re-evaluated on an independent and larger bank.
##
## Uso / usage (desde post_hoc/): Rscript haarlem_cota.R [T1 T2 ...]   (por defecto 10 a 120 ms)
## Salida / output: resultados/haarlem_cota_periodica_10_120.csv
## ============================================================================
source("cargar_funciones.R", encoding = "UTF-8")
suppressPackageStartupMessages(library(GA))

FLASH <- 40
banco_haarlem <- function(isis, n_por_tipo, cfg, semilla, flash = FLASH) {
  set.seed(semilla)
  cond <- rbind(data.frame(n_pulsos = 2L, isi = rep(isis, each = n_por_tipo)),
                data.frame(n_pulsos = 1L, isi = rep(isis, each = n_por_tipo)))
  n <- nrow(cond)
  cond$t1 <- round(runif(n, cfg$onset_min, cfg$onset_max))
  cond$t_ultimo <- ifelse(cond$n_pulsos == 2, cond$t1 + flash + cond$isi, cond$t1)
  estim <- matrix(0, n, cfg$T_ensayo)
  for (i in seq_len(n)) {
    if (cond$n_pulsos[i] == 2) {
      estim[i, cond$t1[i]:(cond$t1[i] + flash - 1)] <- cfg$pulso_amp
      t2 <- cond$t1[i] + flash + cond$isi[i]
      estim[i, t2:(t2 + flash - 1)] <- cfg$pulso_amp
    } else {
      estim[i, cond$t1[i]:(cond$t1[i] + 2 * flash + cond$isi[i] - 1)] <- cfg$pulso_amp
    }
  }
  list(estim = estim, ruido = matrix(rnorm(n * cfg$T_ensayo), n, cfg$T_ensayo), cond = cond)
}
## Umbral al 75 % de aciertos: curva de aciertos por ISI, suavizada con una
## regresión isotónica (no decreciente) y cruce por interpolación lineal.
umbral_75 <- function(sim, isis) {
  acc <- tapply(sim$respuesta == sim$n_pulsos, sim$isi, mean)[as.character(isis)]
  acc_iso <- isoreg(isis, acc)$yf
  k <- which(acc_iso >= 0.75)[1]
  if (is.na(k)) return(list(umbral = NA_real_, acc_max = max(acc_iso), acc = acc))
  if (k == 1) return(list(umbral = isis[1], acc_max = max(acc_iso), acc = acc))
  x0 <- isis[k - 1]; x1 <- isis[k]; y0 <- acc_iso[k - 1]; y1 <- acc_iso[k]
  u <- if (y1 > y0) x0 + (0.75 - y0) / (y1 - y0) * (x1 - x0) else x1
  list(umbral = u, acc_max = max(acc_iso), acc = acc)
}
ISIS <- seq(5, 150, by = 5)
cfg_h <- CFG
objetivo_T <- function(x, Tp, banco) {
  th <- c(a_natural(c(x, log10(Tp)), "periodica"))
  u <- umbral_75(simular_agente(th, "periodica", banco, cfg_h), ISIS)
  ## menos umbral es mejor; si no llega al 75 %, penalización graduada
  if (is.na(u$umbral)) -(max(ISIS) * 1.5 + 100 * (0.75 - u$acc_max)) else -u$umbral
}
co <- cotas_arq("periodica", cfg_h)
lo <- co$lower[1:4]; up <- co$upper[1:4]   # tau, theta_p, m, w (T queda fijo)
args <- commandArgs(trailingOnly = TRUE)
Ts <- if (length(args) > 0) as.numeric(args) else seq(10, 120, by = 10)
res <- list()
for (Tp in Ts) {
  t0 <- Sys.time()
  banco_tr <- banco_haarlem(ISIS, 40, cfg_h, semilla = 7000 + Tp)
  sug <- expand.grid(tau = c(3, 5, 10), theta_p = c(0.4, 0.55), m = c(1.2, 1.6) * Tp, w = c(1, 5))
  sug$m <- pmin(pmax(sug$m, 1), 250)
  sug <- t(apply(sug, 1, function(r) c(log10(r[["tau"]]), r[["theta_p"]], log10(r[["m"]]), log10(r[["w"]]))))
  g <- ga(type = "real-valued", fitness = objetivo_T, Tp = Tp, banco = banco_tr,
          lower = lo, upper = up, suggestions = sug, popSize = 40, maxiter = 60, run = 20,
          monitor = FALSE, seed = 11)
  x <- g@solution[1, ]
  th <- c(a_natural(c(x, log10(Tp)), "periodica"))
  banco_v <- banco_haarlem(ISIS, 200, cfg_h, semilla = 9000 + Tp)
  uv <- umbral_75(simular_agente(th, "periodica", banco_v, cfg_h), ISIS)
  res[[length(res) + 1]] <- data.frame(T = Tp, umbral_entrenamiento = -g@fitnessValue, umbral_validado = uv$umbral,
                                        acc_max_validada = uv$acc_max, tau = th[["tau"]], theta_p = th[["theta_p"]],
                                        m = th[["m"]], w = th[["w"]],
                                        minutos = as.numeric(difftime(Sys.time(), t0, units = "mins")))
  print(tail(res[[length(res)]], 1), row.names = FALSE, digits = 4)
  write.csv(do.call(rbind, res), file.path(CFG$carpeta, sprintf("haarlem_cota_periodica_%s.csv", paste(range(Ts), collapse = "_"))), row.names = FALSE)
}
