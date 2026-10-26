## ============================================================================
## experimento_discriminante.R
## ----------------------------------------------------------------------------
## Experimento simulado que sí distingue las arquitecturas de lectura, para
## completar la historia del paper: las curvas psicométricas de fusión no
## identifican el mecanismo (recuperación del 41.7%), pero estos dos
## paradigmas producen firmas cualitativas distintas por arquitectura.
##
## AUTOCONTENIDO: no necesita ningún otro archivo. Trae embebidos el agente
## del paper (integrador con fuga, cuatro compuertas de lectura) y las
## soluciones rodilla del régimen limpio (post_hoc/resultados/
## rodillas_corregidas.csv del repo, las del artículo). Si quieres usar otras
## rodillas, pásale un CSV con las mismas columnas como argumento.
##
##   Paradigma A (historia del estímulo): un inductor fuerte y una sonda igual
##   de fuerte con SOA fino (12 a 90 ms). La pregunta no es la respuesta del
##   agente sino si la sonda fue ACCEDIDA: cada ensayo se simula dos veces con
##   el mismo ruido (con y sin sonda) y la sonda cuenta como accedida cuando
##   cambia las lecturas registradas en su ventana. El lector por eventos
##   queda ciego en los SOA cortos (refractario y recruce del umbral de la
##   compuerta) y su curva no depende del onset del inductor; el periódico
##   depende de dónde cae su grilla (patrón de alineación con onset fijo,
##   curva lisa con onset aleatorio); los continuos quedan planos.
##
##   Paradigma B (fase): sondas únicas casi umbrales con onset aleatorio denso
##   y prueba logística de fase sobre el acceso (seno y coseno del onset),
##   evaluada en el periodo propio de cada arquitectura y en 100 ms. Solo el
##   periódico (fase profunda) y el modulado (fase suave) salen significativos.
##
##   Parte 2 (opcional, argumento "recovery"): repite la recuperación de
##   modelos sobre el paradigma A (SOA fino más fase exportada) para medir
##   cuánto sube la identificabilidad respecto del 41.7% de la tarea clásica.
##   Usa GA si está instalado y, si no, una búsqueda aleatoria con el mismo
##   presupuesto. Es la parte lenta: el ajuste es secuencial, así que la
##   corrida completa toma varias horas en un núcleo.
##
## Self-contained simulated experiment that distinguishes the reading
## architectures of the paper. Paradigm A manipulates the input history
## (inducer plus probe at fine SOAs) and measures whether the probe was
## ACCESSED, comparing registered readings with and without the probe under
## common random numbers. Paradigm B applies a logistic phase test to dense
## near-threshold probes. The optional part 2 ("recovery") repeats the model
## recovery study on paradigm A. The paper's clean-regime knee solutions are
## embedded; another knee CSV can be passed as argument.
##
## Uso / usage:
##   Rscript experimento_discriminante.R                  completo (minutos)
##   Rscript experimento_discriminante.R rapido           prueba de humo
##   Rscript experimento_discriminante.R recovery         completo + parte 2
##   Rscript experimento_discriminante.R otras_rodillas.csv
## Salidas / outputs: salida_discriminante/discriminante_soa.csv,
##   discriminante_fase.csv, discriminante_respuesta.csv, fig_discriminante.png
##   y, con recovery, discriminante_recuperacion.csv.
##
## Manuel Villalobos Cid, DIINF USACH, octubre 2026.
## ============================================================================
if (!isTRUE(l10n_info()$`UTF-8`)) invisible(try(Sys.setlocale("LC_CTYPE", "C.UTF-8"), silent = TRUE))
args <- commandArgs(trailingOnly = TRUE)
MODO_RAPIDO <- "rapido" %in% args
CON_RECOVERY <- "recovery" %in% args
CSV_RODILLAS <- { c <- args[grepl("\\.csv$", args)]; if (length(c) > 0) c[1] else NA }
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2", repos = "https://cloud.r-project.org")
suppressPackageStartupMessages(library(ggplot2))
CARPETA <- "salida_discriminante"
dir.create(CARPETA, showWarnings = FALSE)

## ============================================================================
## 1. Configuración y rodillas del artículo (régimen limpio)
## ============================================================================
CFG <- list(dt = 1, T_ensayo = 600, pulso_dur = 10, pulso_amp = 1,
            onset_min = 100, onset_max = 250, sigma = 0.6,
            arquitecturas = c("continua", "continua_modulada", "periodica", "eventos"))
RODILLAS <- data.frame(
  arquitectura = c("continua", "continua_modulada", "periodica", "eventos"),
  tau     = c(6.48506, 6.85579, 6.09598, 6.11532),
  theta_p = c(0.589177, 0.576683, 0.624649, 0.0955907),
  m       = c(1.97371, 1.78132, 40.9704, 9.80227),
  w       = c(4.28618, 5.12652, 46.6538, 2.71776),
  T       = c(NA, NA, 46.5028, NA),
  theta_g = c(NA, NA, NA, 0.664613),
  r       = c(NA, NA, NA, 9.09809),
  A_mod   = c(NA, 0.0888602, NA, NA),
  T_mod   = c(NA, 187.405, NA, NA))
if (!is.na(CSV_RODILLAS)) {
  rc <- read.csv(CSV_RODILLAS, stringsAsFactors = FALSE)
  if ("regimen" %in% names(rc)) rc <- rc[rc$regimen == "limpio", ]
  RODILLAS <- rc[, names(RODILLAS)]
  cat("Rodillas tomadas de", CSV_RODILLAS, "\n")
}
nombres_theta <- function(arq) {
  switch(arq,
         continua          = c("tau", "theta_p", "m", "w"),
         periodica         = c("tau", "theta_p", "m", "w", "T"),
         eventos           = c("tau", "theta_p", "m", "w", "theta_g", "r"),
         continua_modulada = c("tau", "theta_p", "m", "w", "A_mod", "T_mod"))
}
theta_rodilla <- function(arq) {
  f <- RODILLAS[RODILLAS$arquitectura == arq, ]
  setNames(as.numeric(f[1, nombres_theta(arq)]), nombres_theta(arq))
}

## Etiquetas y paleta pastel del resto de las figuras del paper.
ARQ_EN <- c(continua = "continuous", continua_modulada = "modulated continuous",
            periodica = "periodic", eventos = "event")
## Estilo de las figuras del artículo (post_hoc/figuras.R): relleno pastel con
## borde oscuro, una forma por arquitectura, tema de 8 pt con TeX Gyre Heros
## (si el servidor no tiene la fuente, cairo la sustituye solo).
FAM_FIG <- "TeX Gyre Heros"
ARQ_LEV <- c("continuous", "event", "modulated continuous", "periodic")
FILL_ARQ <- c(continuous = "#F4A6A6", event = "#C9A7E7", "modulated continuous" = "#B5D99C", periodic = "#A7C7E7")
LINE_ARQ <- c(continuous = "#C0605F", event = "#8E68BD", "modulated continuous" = "#6F9F55", periodic = "#5F8DBF")
SHAPE_ARQ <- c(continuous = 21, event = 23, "modulated continuous" = 22, periodic = 24)
esc_fill <- scale_fill_manual(values = FILL_ARQ, name = NULL, drop = FALSE, limits = ARQ_LEV)
esc_col <- scale_colour_manual(values = LINE_ARQ, name = NULL, drop = FALSE, limits = ARQ_LEV)
esc_shape <- scale_shape_manual(values = SHAPE_ARQ, name = NULL, drop = FALSE, limits = ARQ_LEV)
tema_fig <- function() theme_bw(base_size = 8, base_family = FAM_FIG) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#EBEBEB", linewidth = 0.25),
  panel.border = element_rect(colour = "#A0A0A0", linewidth = 0.3, fill = NA), axis.ticks = element_line(colour = "#A0A0A0", linewidth = 0.3),
  axis.text = element_text(size = 8, colour = "#303030"), axis.title = element_text(size = 8, colour = "#202020"),
  legend.text = element_text(size = 8), legend.position = "bottom",
  legend.key.size = unit(3.2, "mm"), legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(1.5, "mm"),
  strip.background = element_rect(fill = "#F1F1F1", colour = NA), strip.text = element_text(size = 8, face = "bold", colour = "#202020"),
  plot.margin = margin(1.5, 2.5, 1, 1.5, "mm"), plot.background = element_rect(fill = "white", colour = NA))

## ============================================================================
## 2. Agente del paper (mismas ecuaciones y reglas que el script principal)
## ============================================================================
max_movil <- function(X, w) {
  w <- max(1L, as.integer(round(w))); Tt <- ncol(X)
  if (w == 1L) return(X)
  w <- min(w, Tt)
  desplazar <- function(M, s) {
    S <- matrix(-Inf, nrow(M), Tt)
    S[, (s + 1):Tt] <- M[, 1:(Tt - s), drop = FALSE]
    S
  }
  M <- X; len <- 1L
  while (2L * len <= w) { M <- pmax(M, desplazar(M, len)); len <- 2L * len }
  if (len < w) M <- pmax(M, desplazar(M, w - len))
  M
}
integrar <- function(tau, banco, cfg) {
  S <- banco$estim + cfg$sigma * banco$ruido
  n <- nrow(S); Tt <- ncol(S)
  a <- cfg$dt / tau
  X <- matrix(0, n, Tt); x <- numeric(n)
  for (t in seq_len(Tt)) { x <- x + a * (-x + S[, t]); X[, t] <- x }
  X
}
tiempos_lectura <- function(theta, arq, X) {
  n <- nrow(X); Tt <- ncol(X)
  if (arq %in% c("continua", "continua_modulada")) return(replicate(n, seq_len(Tt), simplify = FALSE))
  if (arq == "periodica") {
    Tp <- max(1, round(theta[["T"]]))
    return(replicate(n, seq(Tp, Tt, by = Tp), simplify = FALSE))
  }
  th <- theta[["theta_g"]]; r <- max(1, round(theta[["r"]]))
  cruza <- (X >= th) & cbind(TRUE, X[, -Tt, drop = FALSE] < th)
  out <- vector("list", n)
  for (i in seq_len(n)) {
    tc <- which(cruza[i, ])
    if (length(tc) == 0) { out[[i]] <- integer(0); next }
    keep <- integer(0); ultimo <- -Inf
    for (t in tc) if (t - ultimo > r) { keep <- c(keep, t); ultimo <- t }
    out[[i]] <- keep
  }
  out
}
## Devuelve por ensayo los tiempos de lectura REGISTRADA (sobre theta_p, con
## el umbral oscilante del modulado evaluado en el tiempo de cada lectura).
lecturas_registradas <- function(theta, arq, banco, cfg) {
  X <- integrar(theta[["tau"]], banco, cfg)
  tl <- tiempos_lectura(theta, arq, X)
  V <- max_movil(X, theta[["w"]])
  thp <- theta[["theta_p"]]
  lapply(seq_len(nrow(X)), function(i) {
    t_i <- tl[[i]]
    if (length(t_i) == 0) return(integer(0))
    u <- if (arq == "continua_modulada") thp * (1 + theta[["A_mod"]] * sin(2 * pi * t_i / theta[["T_mod"]])) else thp
    t_i[V[i, t_i] >= u]
  })
}
## Respuesta conductual del paper: lecturas registradas separadas por más de m
## ms forman eventos distintos; "dos" si hay dos o más eventos.
respuesta_agente <- function(theta, arq, banco, cfg) {
  lr <- lecturas_registradas(theta, arq, banco, cfg)
  m <- theta[["m"]]
  vapply(lr, function(tr) {
    if (length(tr) == 0) return(1L)
    if (1L + sum(diff(tr) > m) >= 2) 2L else 1L
  }, integer(1))
}

## ============================================================================
## 3. Bancos del paradigma A y medida de acceso por diferencia
## ============================================================================
N_POR_SOA <- if (MODO_RAPIDO) 20 else 150
N_FASE <- if (MODO_RAPIDO) 400 else 3000
SOAS <- c(12, 15, 18, 21, 25, 30, 40, 60, 90)
VENTANA_SONDA <- 30            # ms después del onset de la sonda
AMP_SONDA_FASE <- 0.85         # sonda casi umbral del paradigma B (x amp del pulso)

banco_sonda <- function(soas, n_por_soa, cfg, semilla, t1_fijo = NULL) {
  set.seed(semilla)
  cond <- data.frame(n_pulsos = 2, isi = rep(soas, each = n_por_soa))
  n <- nrow(cond)
  cond$t1 <- if (is.null(t1_fijo)) round(runif(n, cfg$onset_min, cfg$onset_max)) else rep(t1_fijo, n)
  cond$t2 <- cond$t1 + cond$isi
  estim <- matrix(0, n, cfg$T_ensayo)
  for (i in seq_len(n)) {
    estim[i, cond$t1[i]:(cond$t1[i] + cfg$pulso_dur - 1)] <- cfg$pulso_amp
    idx2 <- cond$t2[i]:(cond$t2[i] + cfg$pulso_dur - 1)
    estim[i, idx2[idx2 <= cfg$T_ensayo]] <- cfg$pulso_amp
  }
  ruido <- matrix(rnorm(n * cfg$T_ensayo), n, cfg$T_ensayo)
  estim_sin <- matrix(0, n, cfg$T_ensayo)
  for (i in seq_len(n)) estim_sin[i, cond$t1[i]:(cond$t1[i] + cfg$pulso_dur - 1)] <- cfg$pulso_amp
  list(con = list(estim = estim, ruido = ruido, cond = cond),
       sin = list(estim = estim_sin, ruido = ruido, cond = cond))
}
## La sonda cuenta como accedida cuando las lecturas registradas dentro de su
## ventana difieren entre la simulación con sonda y la simulación sin sonda
## (mismo ruido: números aleatorios comunes).
acceso_sonda <- function(theta, arq, par, cfg, t_sonda, ventana = VENTANA_SONDA) {
  lc <- lecturas_registradas(theta, arq, par$con, cfg)
  ls <- lecturas_registradas(theta, arq, par$sin, cfg)
  vapply(seq_along(lc), function(i) {
    v0 <- t_sonda[i]; v1 <- v0 + ventana
    !identical(lc[[i]][lc[[i]] >= v0 & lc[[i]] < v1], ls[[i]][ls[[i]] >= v0 & ls[[i]] < v1])
  }, logical(1))
}

## ============================================================================
## 4. Paradigma A: acceso contra el SOA, con onset aleatorio y fijo
## ============================================================================
cat("Paradigma A: inductor y sonda con SOA fino\n")
pares <- list(aleatorio = banco_sonda(SOAS, N_POR_SOA, CFG, semilla = 7),
              fijo = banco_sonda(SOAS, N_POR_SOA, CFG, semilla = 7, t1_fijo = 200))
tab_soa <- do.call(rbind, lapply(CFG$arquitecturas, function(a) {
  th <- theta_rodilla(a)
  do.call(rbind, lapply(names(pares), function(cnd) {
    p <- pares[[cnd]]
    acc <- acceso_sonda(th, a, p, CFG, p$con$cond$t2)
    agg <- aggregate(acc, by = list(soa = p$con$cond$isi), FUN = mean)
    data.frame(architecture = unname(ARQ_EN[a]), onset = ifelse(cnd == "aleatorio", "jittered onset", "fixed onset"),
               soa = agg$soa, p_access = agg$x)
  }))
}))
write.csv(tab_soa, file.path(CARPETA, "discriminante_soa.csv"), row.names = FALSE)

tab_resp <- do.call(rbind, lapply(CFG$arquitecturas, function(a) {
  rsp <- respuesta_agente(theta_rodilla(a), a, pares$aleatorio$con, CFG)
  agg <- aggregate((rsp == 2), by = list(soa = pares$aleatorio$con$cond$isi), FUN = mean)
  data.frame(architecture = unname(ARQ_EN[a]), soa = agg$soa, p_two = agg$x)
}))
write.csv(tab_resp, file.path(CARPETA, "discriminante_respuesta.csv"), row.names = FALSE)

## ============================================================================
## 5. Paradigma B: fase del onset con sondas casi umbrales
## ============================================================================
cat("Paradigma B: fase del onset con sondas casi umbrales\n")
banco_fase <- local({
  set.seed(11)
  n <- N_FASE
  cond <- data.frame(n_pulsos = 1, isi = 0, t1 = round(runif(n, 150, 450)))
  estim <- matrix(0, n, CFG$T_ensayo)
  for (i in seq_len(n)) estim[i, cond$t1[i]:(cond$t1[i] + CFG$pulso_dur - 1)] <- CFG$pulso_amp * AMP_SONDA_FASE
  ruido <- matrix(rnorm(n * CFG$T_ensayo), n, CFG$T_ensayo)
  list(con = list(estim = estim, ruido = ruido, cond = cond),
       sin = list(estim = estim * 0, ruido = ruido, cond = cond))
})
periodo_propio <- function(arq, theta) {
  if (arq == "periodica") theta[["T"]] else if (arq == "continua_modulada") theta[["T_mod"]] else NA_real_
}
prueba_fase_acceso <- function(acc, t1, Tper) {
  fase <- 2 * pi * (t1 %% Tper) / Tper
  m0 <- glm(acc ~ 1, family = binomial)
  m1 <- glm(acc ~ sin(fase) + cos(fase), family = binomial)
  pchisq(deviance(m0) - deviance(m1), df = 2, lower.tail = FALSE)
}
tab_fase <- do.call(rbind, lapply(CFG$arquitecturas, function(a) {
  th <- theta_rodilla(a)
  acc <- acceso_sonda(th, a, banco_fase, CFG, banco_fase$con$cond$t1)
  t1 <- banco_fase$con$cond$t1
  per <- c(own = periodo_propio(a, th), control = 100)
  do.call(rbind, lapply(names(per), function(k) {
    if (is.na(per[[k]])) return(data.frame(architecture = unname(ARQ_EN[a]), period = k, T_ms = NA, p_access = mean(acc), p_value = NA))
    data.frame(architecture = unname(ARQ_EN[a]), period = k, T_ms = round(per[[k]], 1),
               p_access = mean(acc), p_value = prueba_fase_acceso(acc, t1, per[[k]]))
  }))
}))
write.csv(tab_fase, file.path(CARPETA, "discriminante_fase.csv"), row.names = FALSE)
cat("\nPrueba de fase sobre el acceso (p de la razón de verosimilitud):\n")
print(tab_fase, row.names = FALSE, digits = 3)

## ============================================================================
## 6. Figura (estilo del artículo: dos bloques, SOA con facetas de onset y fase)
## ============================================================================
fa <- tab_soa
fa$architecture <- factor(fa$architecture, levels = ARQ_LEV)
fa$panel <- factor(ifelse(fa$onset == "jittered onset", "jittered inducer onset", "fixed inducer onset"),
                   levels = c("jittered inducer onset", "fixed inducer onset"))
fa <- fa[fa$onset == "jittered onset" | fa$architecture %in% c("periodic", "event"), ]
pa <- ggplot(fa, aes(soa, p_access)) +
  geom_line(aes(colour = architecture), linewidth = 0.55) +
  geom_point(aes(fill = architecture, shape = architecture), size = 1.5, colour = "#404040", stroke = 0.25) +
  esc_col + esc_fill + esc_shape +
  scale_x_log10(breaks = c(12, 15, 21, 30, 40, 60, 90)) + scale_y_continuous(limits = c(0, 1)) +
  facet_wrap(~ panel, nrow = 1) +
  labs(x = "Inducer-probe onset asynchrony (ms)", y = "P(probe accessed)") + tema_fig()
fb <- do.call(rbind, lapply(CFG$arquitecturas, function(a) {
  th <- theta_rodilla(a)
  acc <- acceso_sonda(th, a, banco_fase, CFG, banco_fase$con$cond$t1)
  Tp <- periodo_propio(a, th); if (is.na(Tp)) Tp <- 100
  fase <- (banco_fase$con$cond$t1 %% Tp) / Tp
  bins <- cut(fase, breaks = seq(0, 1, by = 0.1), include.lowest = TRUE, labels = FALSE)
  agg <- aggregate(acc, by = list(bin = bins), FUN = mean)
  data.frame(architecture = unname(ARQ_EN[a]), phase = (agg$bin - 0.5) / 10, p_access = agg$x,
             panel = "probe onset phase")
}))
fb$architecture <- factor(fb$architecture, levels = ARQ_LEV)
pc <- ggplot(fb, aes(phase, p_access)) +
  geom_line(aes(colour = architecture), linewidth = 0.55) +
  geom_point(aes(fill = architecture, shape = architecture), size = 1.5, colour = "#404040", stroke = 0.25) +
  esc_col + esc_fill + esc_shape + scale_y_continuous(limits = c(0, 1)) +
  facet_wrap(~ panel) +
  labs(x = "Phase of the probe onset (fraction of period)", y = "P(probe accessed)") + tema_fig()
if (requireNamespace("patchwork", quietly = TRUE)) {
  g <- (pa + pc + patchwork::plot_layout(ncol = 2, widths = c(2, 1), guides = "collect")) +
    patchwork::plot_annotation(tag_levels = "a") &
    ggplot2::theme(legend.position = "bottom", plot.tag = element_text(size = 9, face = "bold", family = FAM_FIG))
  ggsave(file.path(CARPETA, "fig_discriminante.png"), g, width = 174/25.4, height = 62/25.4, dpi = 300, bg = "white")
  try(ggsave(file.path(CARPETA, "fig_discriminante.pdf"), g, width = 174/25.4, height = 62/25.4, device = cairo_pdf, bg = "white"), silent = TRUE)
} else {
  ggsave(file.path(CARPETA, "fig_discriminante_a.png"), pa, width = 116/25.4, height = 62/25.4, dpi = 300, bg = "white")
  ggsave(file.path(CARPETA, "fig_discriminante_b.png"), pc, width = 70/25.4, height = 62/25.4, dpi = 300, bg = "white")
}

## ============================================================================
## 7. Parte 2 (opcional): recuperación de modelos sobre el paradigma A
## ============================================================================
## Cada observador sintético responde el banco de SOA fino y se ajustan las
## cuatro arquitecturas por verosimilitud binomial (conteos por SOA contra la
## probabilidad simulada en un banco de evaluación con semilla fija), con GA
## si está instalado o con una búsqueda aleatoria del mismo presupuesto si no.
if (CON_RECOVERY) {
  cat("\nParte 2: recuperación de modelos sobre el paradigma discriminante\n")
  COTAS <- list(tau = c(3, 150), theta_p = c(0.02, 0.9), m = c(1, 250), w = c(1, 250),
                T = c(2, 250), theta_g = c(0.02, 0.9), r = c(1, 250), A_mod = c(0, 0.9), T_mod = c(20, 250))
  PARAMS_LOG <- c("tau", "m", "w", "T", "r", "T_mod")
  cotas_arq <- function(arq) {
    nm <- nombres_theta(arq)
    lo <- vapply(nm, function(p) COTAS[[p]][1], numeric(1))
    up <- vapply(nm, function(p) COTAS[[p]][2], numeric(1))
    es <- nm %in% PARAMS_LOG
    lo[es] <- log10(lo[es]); up[es] <- log10(up[es])
    list(lower = lo, upper = up, nm = nm, es_log = es)
  }
  a_natural <- function(x, co) { x <- as.numeric(x); x[co$es_log] <- 10^x[co$es_log]; setNames(x, co$nm) }
  n_obs <- if (MODO_RAPIDO) 2 else 12
  n_eval_por_soa <- if (MODO_RAPIDO) 5 else 40
  GA_POP <- if (MODO_RAPIDO) 10 else 40; GA_ITER <- if (MODO_RAPIDO) 5 else 60; GA_RUN <- if (MODO_RAPIDO) 3 else 20
  banco_obs <- banco_sonda(SOAS, if (MODO_RAPIDO) 10 else 50, CFG, semilla = 29)$con
  banco_eval <- banco_sonda(SOAS, n_eval_por_soa, CFG, semilla = 999)$con
  p_sim <- function(theta, arq) {
    rsp <- respuesta_agente(theta, arq, banco_eval, CFG)
    agg <- aggregate((rsp == 2), by = list(soa = banco_eval$cond$isi), FUN = mean)
    setNames(pmin(pmax(agg$x, 1 / (2 * n_eval_por_soa)), 1 - 1 / (2 * n_eval_por_soa)), agg$soa)
  }
  loglik <- function(theta, arq, conteos) {
    p <- p_sim(theta, arq)
    sum(conteos$k * log(p[as.character(conteos$soa)]) + (conteos$n - conteos$k) * log(1 - p[as.character(conteos$soa)]))
  }
  ajustar <- function(conteos, arq, semilla) {
    co <- cotas_arq(arq)
    if (requireNamespace("GA", quietly = TRUE)) {
      ga_res <- GA::ga(type = "real-valued",
                       fitness = function(x) loglik(a_natural(x, co), arq, conteos),
                       lower = co$lower, upper = co$upper,
                       suggestions = matrix({x <- theta_rodilla(arq); x[co$es_log] <- log10(x[co$es_log]); x}, nrow = 1),
                       popSize = GA_POP, maxiter = GA_ITER, run = GA_RUN, monitor = FALSE, seed = semilla)
      ll <- as.numeric(ga_res@fitnessValue)
    } else {
      set.seed(semilla)
      n_try <- GA_POP * (GA_ITER + 1)
      ll <- max(vapply(seq_len(n_try), function(k) {
        x <- runif(length(co$lower), co$lower, co$upper)
        loglik(a_natural(x, co), arq, conteos)
      }, numeric(1)))
    }
    2 * length(co$nm) - 2 * ll   # AIC
  }
  set.seed(23)
  rec <- do.call(rbind, lapply(CFG$arquitecturas, function(gen) {
    do.call(rbind, lapply(seq_len(n_obs), function(k) {
      th <- theta_rodilla(gen)
      iaf <- rnorm(1, 10, 1)
      if (gen == "periodica") { th[["T"]] <- 1000 / iaf; th[["w"]] <- 1000 / iaf }
      if (gen == "continua_modulada") th[["T_mod"]] <- 1000 / iaf
      th[["tau"]] <- th[["tau"]] * runif(1, 0.8, 1.2)
      rsp <- respuesta_agente(th, gen, banco_obs, CFG)
      agg <- aggregate(cbind(k = (rsp == 2), n = 1) ~ soa, data = data.frame(soa = banco_obs$cond$isi, rsp), FUN = sum)
      aic <- vapply(CFG$arquitecturas, function(a) ajustar(agg, a, semilla = 100 * k + match(a, CFG$arquitecturas)), numeric(1))
      cat(sprintf("  generador %s, observador %d: mejor %s\n", gen, k, CFG$arquitecturas[which.min(aic)]))
      data.frame(generator = unname(ARQ_EN[gen]), obs = k, best = unname(ARQ_EN[CFG$arquitecturas[which.min(aic)]]))
    }))
  }))
  rec$correcto <- rec$generator == rec$best
  write.csv(rec, file.path(CARPETA, "discriminante_recuperacion.csv"), row.names = FALSE)
  nb <- binom.test(sum(rec$correcto), nrow(rec), p = 0.25)
  cat(sprintf("\nRecuperación en el paradigma discriminante: %d de %d (%.1f%%), binomial exacto p = %.3g (azar 25%%; la tarea clásica dio 41.7%%)\n",
              sum(rec$correcto), nrow(rec), 100 * mean(rec$correcto), nb$p.value))
  print(table(rec$generator, rec$best))
}

cat("\nListo. Salidas en", CARPETA, "\n")
