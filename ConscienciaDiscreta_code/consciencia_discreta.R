## ============================================================================
## consciencia_discreta.R
## ----------------------------------------------------------------------------
## Acceso consciente discreto o continuo: por qué un cerebro muestrearía.
##
## Cuatro arquitecturas de lectura consciente (continua, continua con umbral
## modulado, periódica y por eventos) compiten en una tarea psicofísica
## simulada (fusión de dos pulsos en ruido).
## NSGA-III (paquete rmoo) explora los parámetros de cada arquitectura bajo
## cuatro objetivos a minimizar: error, umbral de fusión, latencia de acceso y
## costo (lecturas por segundo). Después los frentes se validan en ensayos
## nuevos, se comparan (hipervolumen, cobertura, frente combinado) y se mira
## dónde cae el periodo óptimo del lector periódico.
##
## Además:
##   Pregunta 1b: análisis de sensibilidad: la misma pregunta de diseño
##               cambiando de a uno la duración del pulso, el ruido y el rango
##               de ISI, para ver si el ordenamiento de las arquitecturas se
##               mantiene.
##   Pregunta 2: ajuste de las arquitecturas a datos conductuales por
##               participante (verosimilitud binomial, AIC) con prueba de
##               dependencia de fase. Corre sobre datos sintéticos que genera
##               el mismo script (recuperación de modelos) y acepta un CSV real
##               con el formato que se describe en la sección 7.
##   Pregunta 3: demostración de ausencias: ningún agente ve sus propios huecos
##               desde adentro; solo los delata una discontinuidad sensorial.
##   Datos reales (carpeta datos_reales, va en el zip; sección 9): ajusta las
##               tres arquitecturas a los 38 participantes de Deodato y Melcher
##               (2024) y contrasta la predicción del lector periódico con los
##               umbrales y la frecuencia alfa de los 31 de Haarlem (2024).
##
## Uso en el servidor (Linux, R >= 4.1):
##   Rscript consciencia_discreta.R            corrida completa (horas, ver CFG)
##   Rscript consciencia_discreta.R rapido     prueba de humo (pocos minutos)
##   Rscript consciencia_discreta.R datos.csv  corrida completa y además ajusta
##                                             el CSV real indicado
##   Rscript consciencia_discreta.R rapido datos_ejemplo/sintetico_periodica.csv
##                                             prueba de humo que además pasa
##                                             por la ruta de datos reales
##   N_CORES=8 Rscript consciencia_discreta.R  fija el número de núcleos
## Desde RStudio, como trabajo en segundo plano:
##   rstudioapi::jobRunScript("consciencia_discreta.R", workingDir = getwd())
##   (corrida completa; para la prueba de humo, Sys.setenv(MODO = "rapido")
##   en un script envoltorio que haga source() de este, ver el mensaje de
##   entrega)
## El modo rápido solo prueba que todo corre: sus frentes y ajustes no sirven
## para sacar conclusiones. Las corridas se reparten enteras entre los núcleos
## (cada una secuencial por dentro), y cada corrida terminada deja una línea
## con la hora en salida/progreso.log. Con unos 60 núcleos, la corrida
## completa debería tomar entre 7 y 8 horas, según el corte que fije la prueba
## de convergencia. Todo queda en la carpeta ./salida (tablas CSV, objetos RDS
## y figuras PNG).
##
## Manuel Villalobos Cid, DIINF USACH, octubre 2026.
## Financiamiento a reportar: ANID FONDECYT 1261239 y Anillo ACT250038.
## ============================================================================

## ============================================================================
## 0. Paquetes
## ============================================================================
## Con Rscript en un servidor sin locale, los acentos de las figuras salen
## como puntos; esto lo arregla sin tocar nada más.
if (!isTRUE(l10n_info()$`UTF-8`)) invisible(try(Sys.setlocale("LC_CTYPE", "C.UTF-8"), silent = TRUE))
## rmoo trae NSGA-III; ecr lo usa rmoo para el ordenamiento no dominado y acá
## se usa para el hipervolumen exacto; GA sirve para el ajuste a datos
## (un solo objetivo); doParallel y doRNG dan paralelismo reproducible.
paquetes <- c("rmoo", "ecr", "GA", "ggplot2", "doParallel", "doRNG", "readxl")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan) > 0) {
  message("Instalando: ", paste(faltan, collapse = ", "))
  install.packages(faltan, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(rmoo)
  library(GA)
  library(ggplot2)
})

## ----------------------------------------------------------------------------
## Hipervolumen exacto. ecr cambió el nombre de la función entre versiones: la
## de CRAN (2.x) la llama computeHV y la antigua de GitHub (1.x)
## computeDominatedHypervolume; emoa trae otra implementación exacta. Se usa la
## primera que exista y se comprueba con dos casos de valor conocido. Si no hay
## ninguna, el script se detiene acá: nunca aproxima por Monte Carlo, que era
## lento (unos 12 s por cálculo) y además reiniciaba el generador aleatorio.
## ----------------------------------------------------------------------------
HV_EXACTO <- local({
  exportadas <- if (requireNamespace("ecr", quietly = TRUE)) getNamespaceExports("ecr") else character(0)
  if ("computeHV" %in% exportadas) {
    list(nombre = "ecr::computeHV", f = function(P, ref) ecr::computeHV(P, ref.point = ref))
  } else if ("computeDominatedHypervolume" %in% exportadas) {
    list(nombre = "ecr::computeDominatedHypervolume", f = function(P, ref) ecr::computeDominatedHypervolume(P, ref.point = ref))
  } else if (requireNamespace("emoa", quietly = TRUE)) {
    list(nombre = "emoa::dominated_hypervolume", f = function(P, ref) emoa::dominated_hypervolume(P, ref = ref))
  } else stop("No hay una función de hipervolumen exacto disponible: instala ecr (CRAN) o emoa.")
})
## Z: una fila por punto, objetivos ya escalados a [0, 1]; referencia 1.1
hv_exacto <- function(Z) HV_EXACTO$f(t(Z), rep(1.1, ncol(Z)))
local({
  ## un punto: (1.1 - 0.5)^4; dos puntos: unión por inclusión y exclusión
  c1 <- HV_EXACTO$f(matrix(0.5, 4, 1), rep(1.1, 4))
  c2 <- HV_EXACTO$f(cbind(c(0.5, 0.5, 0.5, 0.5), c(0.25, 0.75, 0.5, 0.5)), rep(1, 4))
  if (!isTRUE(abs(c1 - 0.6^4) < 1e-9) || !isTRUE(abs(c2 - 0.078125) < 1e-9))
    stop(sprintf("La función de hipervolumen %s no pasa la prueba (%s y %s).", HV_EXACTO$nombre, c1, c2))
})
cat(sprintf("Hipervolumen exacto: %s (verificado con dos casos conocidos)\n", HV_EXACTO$nombre))

## ----------------------------------------------------------------------------
## Figuras: todo lo que va a la revista (ejes, títulos, leyendas, nombres de
## columna de las tablas de salida) va en inglés; la consola y los comentarios
## quedan en castellano. Paleta pastel fija por arquitectura y por condición,
## para que una arquitectura tenga el mismo color en todas las figuras.
## ----------------------------------------------------------------------------
ARQ_EN <- c(continua = "continuous", continua_modulada = "modulated continuous",
            periodica = "periodic", eventos = "event-driven", random = "random search")
PALETA_ARQ <- c("continuous" = "#F4A6A6", "modulated continuous" = "#B5D99C",
                "periodic" = "#A7C7E7", "event-driven" = "#C9A7E7", "random search" = "#BDBDBD")
PALETA_2 <- c("#A7C7E7", "#F4A6A6")        # pares (régimen, condición)
PALETA_4 <- c("#A7C7E7", "#F4A6A6", "#B5D99C", "#F7D8A8")
arq_en <- function(x) factor(unname(ARQ_EN[as.character(x)]), levels = ARQ_EN)
tema_fig <- function(base = 11) {
  theme_bw(base_size = base) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "#EDEDED"), panel.border = element_rect(colour = "#BBBBBB"),
          strip.background = element_rect(fill = "#F2F2F2", colour = NA),
          strip.text = element_text(face = "bold"), plot.title = element_text(face = "bold"),
          plot.background = element_rect(fill = "white", colour = NA))
}
escala_arq <- function(tipo = c("colour", "fill")) {
  tipo <- match.arg(tipo)
  if (tipo == "colour") scale_colour_manual(values = PALETA_ARQ, name = "architecture", drop = TRUE)
  else scale_fill_manual(values = PALETA_ARQ, name = "architecture", drop = TRUE)
}

## ============================================================================
## 1. Configuración
## ============================================================================
## El modo se elige por argumento de línea de comandos o, para correrlo desde
## RStudio (source o un trabajo en segundo plano), por variables de entorno:
## MODO=rapido y CSV_REAL=ruta.csv.
argumentos <- commandArgs(trailingOnly = TRUE)
MODO_RAPIDO <- "rapido" %in% argumentos || tolower(Sys.getenv("MODO", "")) == "rapido"
csvs <- c(argumentos[grepl("\\.csv$", argumentos)], Sys.getenv("CSV_REAL", ""))
csvs <- csvs[nzchar(csvs)]
CSV_REAL <- if (length(csvs) > 0) csvs[1] else NA

CFG <- list(
  ## Base temporal y estímulo. Todo está en milisegundos.
  dt = 1,                       # paso de integración (ms)
  T_ensayo = 600,               # duración de cada ensayo (ms)
  pulso_dur = 10,               # duración de cada pulso (ms)
  pulso_amp = 1,                # amplitud del pulso (unidad de referencia)
  onset_min = 100,              # el primer pulso cae uniforme en [onset_min, onset_max]
  onset_max = 250,
  isis = c(15, 20, 30, 45, 60, 80, 100, 130, 160, 200),  # ISI onset a onset (ms)
  sigma = 0.6,                  # desviación del ruido blanco de entrada (por ms)
  ## Regímenes de entrada. "rafagas" agrega distractores breves de media
  ## amplitud a tasa de Poisson; es el régimen donde esperamos que la lectura
  ## discreta pueda ganar en algo más que costo.
  regimenes = list(
    limpio  = list(tasa_distractor = 0,  amp_distractor = 0,   dur_distractor = 5),
    rafagas = list(tasa_distractor = 8,  amp_distractor = 0.5, dur_distractor = 5)
  ),
  ## Bancos de ensayos (números aleatorios comunes). El banco de entrenamiento
  ## es el mismo para todos los individuos de una corrida; el de validación es
  ## independiente y más grande.
  n_un_pulso_train = 48, n_por_isi_train = 8,
  n_un_pulso_val = 160,  n_por_isi_val = 24,
  ## Arquitecturas y cotas de sus parámetros (vector real que NSGA-III explora)
  arquitecturas = c("continua", "continua_modulada", "periodica", "eventos"),
  cotas = list(
    tau     = c(3, 150),      # constante de tiempo del integrador (ms)
    theta_p = c(0.02, 0.9),   # umbral perceptual sobre la lectura
    m       = c(1, 250),      # ventana de fusión entre lecturas registradas (ms)
    w       = c(1, 250),      # ventana de cada lectura (máximo del integrador, ms)
    T       = c(2, 250),      # periodo del lector periódico (ms)
    theta_g = c(0.02, 0.9),   # umbral de la compuerta del lector por eventos
    r       = c(1, 250),      # periodo refractario del lector por eventos (ms)
    A_mod   = c(0, 0.9),      # amplitud relativa de la modulación del umbral (continua modulada)
    T_mod   = c(20, 250)      # periodo de esa modulación (ms)
  ),
  ## NSGA-III. Con 4 objetivos y n_partitions = 6 hay 84 puntos de referencia
  ## (Das y Dennis); Deb y Jain recomiendan una población múltiplo de 4
  ## apenas mayor, por eso 88.
  nObj = 4,
  n_partitions = 6,
  popSize = 88,
  pcrossover = 0.8,
  pmutation = 0.1,
  ## Generaciones por defecto de las corridas principales. Si la prueba de
  ## convergencia (pregunta 0b) muestra que el hipervolumen sigue subiendo,
  ## la ejecución reemplaza este valor por la generación del 99 % más un
  ## margen de seguridad (ver validacion$convergencia$margen).
  maxiter = 300,
  semillas = c(11, 22, 33),
  ## Validación del optimizador (pregunta 0), sobre el régimen limpio:
  ##   parametrizacion: rejilla de tamaño de población (con sus particiones
  ##     de Das y Dennis), cruce y mutación, con 3 semillas cada una, elegida
  ##     por hipervolumen de validación mediano; se corre antes que todo y la
  ##     configuración ganadora reemplaza a popSize, pcrossover y pmutation.
  ##   convergencia: una corrida larga por arquitectura con el hipervolumen
  ##     del primer frente por generación; el corte recomendado es la
  ##     generación en que llega al 99 % del valor final.
  ##   consistencia: 11 semillas por arquitectura (banco y optimizador
  ##     distintos en cada una), con media, desviación y rango del
  ##     hipervolumen y Wilcoxon por pares entre arquitecturas.
  ##   random: búsqueda aleatoria con el mismo presupuesto, comparada por
  ##     hipervolumen y cobertura.
  validacion = list(
    parametrizacion = list(
      popSize = c(52, 88, 132), n_partitions = c(5, 6, 7),   # emparejados: 56, 84, 120 puntos de referencia
      pcrossover = c(0.7, 0.8, 0.9), pmutation = c(0.05, 0.1, 0.2),
      maxiter = 120, semillas = c(101, 102, 103)),
    ## 11 semillas por arquitectura, 1500 generaciones; el corte se fija en
    ## la mediana entre semillas de la generación del 99 %, multiplicada por
    ## el margen, y nunca por debajo de maxiter_minimo. Las 44 corridas van en
    ## paralelo, así que con 44 núcleos o más cuestan lo mismo que una.
    convergencia = list(maxiter = 1500, semillas = 501:511, margen = 1.5, maxiter_minimo = 1000),
    consistencia = list(semillas = c(11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 122)),
    random = list(semillas = c(11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 122))),
  ## Núcleos entre los que se reparten corridas completas (y ajustes por
  ## participante). Se puede fijar desde fuera con la variable de entorno
  ## N_CORES.
  n_cores = as.integer(Sys.getenv("N_CORES", max(1, parallel::detectCores() - 1))),
  ## Ajuste a datos (pregunta 2)
  ajuste = list(n_participantes_sint = 12, n_un_pulso = 120, n_por_isi = 20,
                n_val_un_pulso = 400, n_val_por_isi = 60,
                ga_popSize = 40, ga_maxiter = 60, ga_run = 20,
                generadores = c("periodica", "continua", "eventos", "continua_modulada")),
  ## Sensibilidad (pregunta 1b): cambios de a uno sobre la condición base
  sensibilidad = list(
    condiciones = list(
      pulso_5   = list(pulso_dur = 5),
      pulso_20  = list(pulso_dur = 20),
      ruido_0.4 = list(sigma = 0.4),
      ruido_0.9 = list(sigma = 0.9),
      isi_corto = list(isis = seq(5, 70, by = 5))     # el rango de Deodato y Melcher
    ),
    maxiter = NA, semilla = 11),        # NA: usa el mismo corte que las corridas principales
  ## Demostración de ausencias (pregunta 3)
  ausencias = list(n_ensayos = 200, T_ensayo = 1500, hueco = 300,
                   hueco_min = 400, hueco_max = 900, amp_escalon = 0.6),
  carpeta = "salida"
)

if (MODO_RAPIDO) {
  CFG$regimenes <- CFG$regimenes["limpio"]
  CFG$n_partitions <- 4          # 35 puntos de referencia
  CFG$popSize <- 36
  CFG$maxiter <- 12
  CFG$semillas <- 11
  CFG$n_un_pulso_val <- 60; CFG$n_por_isi_val <- 9
  CFG$ajuste$n_participantes_sint <- 3
  CFG$ajuste$ga_popSize <- 20; CFG$ajuste$ga_maxiter <- 15; CFG$ajuste$ga_run <- 15
  CFG$ajuste$generadores <- "periodica"
  CFG$ausencias$n_ensayos <- 60
  CFG$sensibilidad$condiciones <- CFG$sensibilidad$condiciones[c("pulso_20", "isi_corto")]
  CFG$sensibilidad$maxiter <- 10
  CFG$validacion$parametrizacion <- list(popSize = c(36, 52), n_partitions = c(4, 5),
                                         pcrossover = c(0.8), pmutation = c(0.1, 0.2),
                                         maxiter = 6, semillas = 101)
  CFG$validacion$convergencia <- list(maxiter = 25, semillas = c(7, 8), margen = 1.5, maxiter_minimo = 12)
  CFG$validacion$consistencia$semillas <- c(11, 22, 33)
  CFG$validacion$random$semillas <- c(11, 22, 33)
}
## El paralelismo usa procesos bifurcados (multicore), que no existen en
## Windows; ahí se corre en un solo núcleo.
if (.Platform$OS.type == "windows" && CFG$n_cores > 1) {
  message("Windows no soporta el paralelismo multicore de este script; se usa un núcleo.")
  CFG$n_cores <- 1L
}
dir.create(CFG$carpeta, showWarnings = FALSE)
RNGkind("L'Ecuyer-CMRG")

## ============================================================================
## 2. Banco de ensayos
## ============================================================================
## Devuelve una lista con la matriz de estímulo (ensayos x ms), la matriz de
## ruido estandarizado (misma forma) y una tabla de condiciones por ensayo.
## Fijar la semilla hace que todos los individuos de una corrida vean
## exactamente los mismos ensayos (números aleatorios comunes), lo que
## convierte el fitness en determinista y deja la comparación limpia.
crear_banco <- function(n_un_pulso, n_por_isi, cfg, regimen, semilla,
                        T_ensayo = cfg$T_ensayo) {
  set.seed(semilla)
  reg <- cfg$regimenes[[regimen]]
  cond <- rbind(
    data.frame(n_pulsos = 1, isi = 0),
    data.frame(n_pulsos = 2, isi = rep(cfg$isis, each = n_por_isi))
  )
  cond <- cond[c(rep(1, n_un_pulso), 2:nrow(cond)), ]
  n <- nrow(cond)
  cond$t1 <- round(runif(n, cfg$onset_min, cfg$onset_max))
  cond$t2 <- ifelse(cond$n_pulsos == 2, cond$t1 + cond$isi, NA)
  cond$t_ultimo <- ifelse(cond$n_pulsos == 2, cond$t2, cond$t1)
  estim <- matrix(0, n, T_ensayo)
  for (i in seq_len(n)) {
    idx <- cond$t1[i]:(cond$t1[i] + cfg$pulso_dur - 1)
    estim[i, idx] <- cfg$pulso_amp
    if (cond$n_pulsos[i] == 2) {
      idx2 <- cond$t2[i]:(cond$t2[i] + cfg$pulso_dur - 1)
      idx2 <- idx2[idx2 <= T_ensayo]
      estim[i, idx2] <- cfg$pulso_amp
    }
    if (reg$tasa_distractor > 0) {
      k <- rpois(1, reg$tasa_distractor * T_ensayo / 1000)
      if (k > 0) {
        t_d <- sample.int(T_ensayo - reg$dur_distractor, k)
        for (td in t_d) {
          idx_d <- td:(td + reg$dur_distractor - 1)
          estim[i, idx_d] <- pmax(estim[i, idx_d], reg$amp_distractor)
        }
      }
    }
  }
  ruido <- matrix(rnorm(n * T_ensayo), n, T_ensayo)
  rownames(cond) <- NULL
  list(estim = estim, ruido = ruido, cond = cond, regimen = regimen)
}

## ============================================================================
## 3. Agente
## ============================================================================
## Un integrador con fuga acumula la entrada ruidosa de forma continua. Sobre
## él hay una compuerta de lectura que produce los episodios de acceso:
##   continua : lee cada ms.
##   periodica: lee cada T ms.
##   eventos  : lee cuando el integrador cruza theta_g hacia arriba y pasó el
##              refractario r desde la última lectura (ignición).
##   continua_modulada : lee cada ms, como la continua, pero su umbral
##              perceptual oscila en el tiempo, theta_p (1 + A sin(2 pi t / T_mod)),
##              sin ninguna compuerta discreta. Es el competidor de "modulación
##              continua de la excitabilidad" (Iemi et al. 2017; Samaha et al.
##              2020): un lector continuo que también puede producir efectos de
##              fase y de frecuencia individual, y que evita que la arquitectura
##              continua sea un muñeco de paja frente a las discretas.
## Cada lectura toma el máximo del integrador en la ventana de w ms que
## termina en el instante de lectura (w = 1 es una lectura instantánea; en un
## lector periódico w cercano a T es un "fotograma" que registra lo que pasó
## dentro de su ciclo). Una lectura queda registrada si ese valor supera
## theta_p. Las lecturas registradas separadas por menos de m ms forman un
## mismo evento percibido. El agente responde "dos" si percibe dos o más
## eventos.
nombres_theta <- function(arq) {
  switch(arq,
         continua          = c("tau", "theta_p", "m", "w"),
         periodica         = c("tau", "theta_p", "m", "w", "T"),
         eventos           = c("tau", "theta_p", "m", "w", "theta_g", "r"),
         continua_modulada = c("tau", "theta_p", "m", "w", "A_mod", "T_mod"))
}

## Máximo móvil por filas sobre una ventana de w columnas que termina en cada
## columna (relleno -Inf al inicio). Usa duplicación de ventanas, así cuesta
## O(log w) operaciones vectoriales en vez de O(w).
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
## Los parámetros temporales (tau, m, w, T, r) se buscan en escala log10 para
## que los valores chicos (periodos de pocos ms) estén tan representados como
## los grandes; los umbrales se buscan en escala lineal. Las tablas de salida
## siempre llevan los parámetros en escala natural.
PARAMS_LOG <- c("tau", "m", "w", "T", "r", "T_mod")
cotas_arq <- function(arq, cfg) {
  nm <- nombres_theta(arq)
  lo <- vapply(nm, function(p) cfg$cotas[[p]][1], numeric(1))
  up <- vapply(nm, function(p) cfg$cotas[[p]][2], numeric(1))
  es_log <- nm %in% PARAMS_LOG
  lo[es_log] <- log10(lo[es_log]); up[es_log] <- log10(up[es_log])
  list(lower = lo, upper = up)
}
a_natural <- function(x, arq) {
  nm <- nombres_theta(arq); x <- as.numeric(x)
  es_log <- nm %in% PARAMS_LOG
  x[es_log] <- 10^x[es_log]
  setNames(x, nm)
}
a_busqueda <- function(theta, arq) {
  nm <- nombres_theta(arq); x <- as.numeric(theta[nm])
  es_log <- nm %in% PARAMS_LOG
  x[es_log] <- log10(x[es_log])
  x
}

## Integra todas las filas del banco a la vez (bucle sobre el tiempo, vectores
## sobre los ensayos). Devuelve la matriz de estados X (ensayos x ms).
integrar <- function(tau, banco, cfg) {
  S <- banco$estim + cfg$sigma * banco$ruido
  n <- nrow(S); Tt <- ncol(S)
  a <- cfg$dt / tau
  X <- matrix(0, n, Tt)
  x <- numeric(n)
  for (t in seq_len(Tt)) {
    x <- x + a * (-x + S[, t])
    X[, t] <- x
  }
  X
}

## Tiempos de lectura por ensayo según la arquitectura. Devuelve una lista de
## vectores de tiempos (ms). Un hueco forzado (ausencia) borra las lecturas
## dentro de [hueco_ini, hueco_fin).
tiempos_lectura <- function(theta, arq, X, hueco = NULL) {
  n <- nrow(X); Tt <- ncol(X)
  if (arq %in% c("continua", "continua_modulada")) {
    out <- replicate(n, seq_len(Tt), simplify = FALSE)
  } else if (arq == "periodica") {
    Tp <- max(1, round(theta[["T"]]))
    out <- replicate(n, seq(Tp, Tt, by = Tp), simplify = FALSE)
  } else {
    th <- theta[["theta_g"]]; r <- max(1, round(theta[["r"]]))
    cruza <- (X >= th) & cbind(TRUE, X[, -Tt, drop = FALSE] < th)
    out <- vector("list", n)
    for (i in seq_len(n)) {
      tc <- which(cruza[i, ])
      if (length(tc) == 0) { out[[i]] <- integer(0); next }
      keep <- integer(0); ultimo <- -Inf
      for (t in tc) {
        if (t - ultimo > r) { keep <- c(keep, t); ultimo <- t }
      }
      out[[i]] <- keep
    }
  }
  if (!is.null(hueco)) {
    out <- lapply(out, function(tl) tl[tl < hueco[1] | tl >= hueco[2]])
  }
  out
}

## Simula el agente sobre un banco y devuelve una tabla por ensayo:
## n_eventos, respuesta (1 o 2), latencia de acceso al último pulso (ms, NA si
## no lo registró) y número de lecturas. Con detalle = TRUE devuelve además las
## secuencias de lecturas (tiempos y valores) para la demostración de ausencias.
simular_agente <- function(theta, arq, banco, cfg, detalle = FALSE, hueco = NULL) {
  if (!is.null(names(theta))) theta <- theta[nombres_theta(arq)]
  theta <- setNames(as.numeric(theta), nombres_theta(arq))
  X <- integrar(theta[["tau"]], banco, cfg)
  n <- nrow(X)
  tl <- tiempos_lectura(theta, arq, X, hueco)
  V <- max_movil(X, theta[["w"]])
  thp <- theta[["theta_p"]]; m <- theta[["m"]]
  n_eventos <- integer(n); latencia <- rep(NA_real_, n); n_lect <- integer(n)
  lecturas <- if (detalle) vector("list", n) else NULL
  for (i in seq_len(n)) {
    t_i <- tl[[i]]
    n_lect[i] <- length(t_i)
    if (length(t_i) == 0) next
    v_i <- V[i, t_i]
    umbral_t <- if (arq == "continua_modulada") {
      thp * (1 + theta[["A_mod"]] * sin(2 * pi * t_i / theta[["T_mod"]]))
    } else thp
    reg <- v_i >= umbral_t
    tr <- t_i[reg]
    if (length(tr) > 0) {
      n_eventos[i] <- 1L + sum(diff(tr) > m)
      tu <- banco$cond$t_ultimo[i]
      if (!is.null(tu) && !is.na(tu)) {
        despues <- tr[tr >= tu]
        if (length(despues) > 0) latencia[i] <- despues[1] - tu
      }
    }
    if (detalle) lecturas[[i]] <- list(t = t_i, v = v_i)
  }
  res <- data.frame(n_eventos = n_eventos,
                    respuesta = ifelse(n_eventos >= 2, 2L, 1L),
                    latencia = latencia, n_lecturas = n_lect)
  if (!is.null(banco$cond)) res <- cbind(banco$cond, res)
  if (detalle) attr(res, "lecturas") <- lecturas
  res
}

## ============================================================================
## 4. Objetivos
## ============================================================================
## Los cuatro objetivos se minimizan:
##   error    : proporción de respuestas incorrectas en todos los ensayos.
##   umbral   : umbral de fusión (ms): ISI más corto con d' >= 1.35, donde
##              d' = qnorm(aciertos en ese ISI) - qnorm(falsas alarmas),
##              con corrección 1/(2n). El criterio 1.35 equivale a 75% de
##              aciertos con criterio de decisión neutro. Si nunca llega,
##              ISI máximo x 1.5. Un agente que siempre dice "dos" tiene
##              d' = 0 y se lleva la penalización, así que el umbral no se
##              puede trampear diciendo siempre "dos".
##   latencia : tiempo medio (ms) desde el último pulso hasta la primera
##              lectura registrada que lo capta; los ensayos donde nunca lo
##              capta cuentan como la duración completa del ensayo.
##   costo    : lecturas por segundo.
dprima <- function(h, n_h, fa, n_fa) {
  H <- (h + 0.5) / (n_h + 1); FA <- (fa + 0.5) / (n_fa + 1)
  qnorm(H) - qnorm(FA)
}
umbral_fusion <- function(sim, cfg, criterio = 1.35) {
  uno <- sim[sim$n_pulsos == 1, ]
  fa <- sum(uno$respuesta == 2); n_fa <- nrow(uno)
  dos <- sim[sim$n_pulsos == 2, ]
  dp <- sapply(cfg$isis, function(isi) {
    s <- dos[dos$isi == isi, ]
    dprima(sum(s$respuesta == 2), nrow(s), fa, n_fa)
  })
  if (dp[1] >= criterio) return(cfg$isis[1])
  cruce <- which(dp >= criterio)[1]
  if (is.na(cruce)) return(max(cfg$isis) * 1.5)
  x0 <- cfg$isis[cruce - 1]; x1 <- cfg$isis[cruce]
  y0 <- dp[cruce - 1]; y1 <- dp[cruce]
  x0 + (criterio - y0) / (y1 - y0) * (x1 - x0)
}
objetivos <- function(sim, cfg) {
  error <- mean(sim$respuesta != sim$n_pulsos)
  umbral <- umbral_fusion(sim, cfg)
  lat <- sim$latencia; lat[is.na(lat)] <- cfg$T_ensayo
  latencia <- mean(lat)
  costo <- mean(sim$n_lecturas) / (cfg$T_ensayo / 1000)
  c(error = error, umbral = umbral, latencia = latencia, costo = costo)
}
evaluar <- function(theta, arq, banco, cfg) {
  objetivos(simular_agente(theta, arq, banco, cfg), cfg)
}
## Fitness para rmoo::nsga3. rmoo reenvía sus argumentos extra al fitness, por
## eso el ... es obligatorio.
fitness_nsga <- function(x, arq, banco, cfg, ...) {
  unname(evaluar(a_natural(x, arq), arq, banco, cfg))
}

## ============================================================================
## 5. Corridas NSGA-III, validación y métricas
## ============================================================================
## Filtro de no dominados (minimización). Recorre los puntos en orden
## lexicográfico: así todo punto que domina a otro aparece antes que él, y
## basta comparar cada punto con el archivo de no dominados encontrados hasta
## ese momento (la dominancia es transitiva). Los puntos repetidos no se
## dominan entre sí y quedan todos. Da lo mismo que comparar todos contra
## todos, pero escala bien con las decenas de miles de puntos de la búsqueda
## aleatoria.
no_dominados <- function(F) {
  F <- as.matrix(F); n <- nrow(F); d <- ncol(F)
  keep <- logical(n)
  if (n == 0) return(keep)
  orden <- do.call(order, unname(lapply(seq_len(d), function(j) F[, j])))
  A <- matrix(0, n, d); m <- 0L
  for (k in orden) {
    p <- F[k, ]
    if (m > 0L) {
      Am <- A[seq_len(m), , drop = FALSE]
      pp <- rep(p, each = m)
      if (any(rowSums(Am <= pp) == d & rowSums(Am < pp) > 0)) next
    }
    m <- m + 1L; A[m, ] <- p; keep[k] <- TRUE
  }
  keep
}

## Una corrida de NSGA-III. La semilla fija tanto el optimizador como el banco
## de entrenamiento (la instancia del problema), así que corridas con semillas
## distintas difieren en las dos cosas: eso es lo que se quiere al medir
## consistencia, porque la pregunta es si el ordenamiento de arquitecturas
## depende del azar del algoritmo o del azar de los ensayos. Con
## banco_fijo = TRUE todas las semillas comparten la instancia y solo cambia
## el optimizador (sirve para separar las dos fuentes de variación).
## Con registrar = TRUE se guarda, en cada generación, el hipervolumen exacto
## del primer frente (punto de referencia fijo) usando el gancho "monitor" de
## rmoo. El monitor no toca el generador aleatorio.
correr_nsga <- function(arq, regimen, semilla, cfg, banco_fijo = FALSE, registrar = FALSE) {
  banco_train <- crear_banco(cfg$n_un_pulso_train, cfg$n_por_isi_train, cfg, regimen,
                             semilla = if (banco_fijo) 1000 + cfg$semillas[1] else 1000 + semilla)
  co <- cotas_arq(arq, cfg)
  traza <- new.env(); traza$hv <- numeric(0)
  monitor <- if (registrar) {
    function(object, ...) {
      Fg <- object@fitness[object@f[[1]], , drop = FALSE]
      colnames(Fg) <- c("error", "umbral", "latencia", "costo")
      traza$hv <- c(traza$hv, hv_fijo(Fg, cfg))
    }
  } else FALSE
  t0 <- Sys.time()
  res <- nsga3(type = "real-valued", fitness = fitness_nsga,
               arq = arq, banco = banco_train, cfg = cfg,
               lower = co$lower, upper = co$upper,
               popSize = cfg$popSize, nObj = cfg$nObj, n_partitions = cfg$n_partitions,
               pcrossover = cfg$pcrossover, pmutation = cfg$pmutation,
               maxiter = cfg$maxiter, monitor = monitor, seed = semilla,
               parallel = if (cfg$n_cores > 1) cfg$n_cores else FALSE)
  dur <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  list(res = res, arq = arq, regimen = regimen, semilla = semilla, minutos = dur, hv_por_generacion = traza$hv)
}

## Búsqueda aleatoria con el mismo presupuesto de evaluaciones que una corrida
## de NSGA-III (popSize x (maxiter + 1)): muestreo uniforme en el espacio de
## búsqueda (escala log para los parámetros temporales, como NSGA-III), se
## evalúa todo y se devuelve el frente no dominado. Es la línea base que
## responde si NSGA-III aporta algo sobre muestrear al azar.
correr_random <- function(arq, regimen, semilla, cfg, n_eval = cfg$popSize * (cfg$maxiter + 1)) {
  banco_train <- crear_banco(cfg$n_un_pulso_train, cfg$n_por_isi_train, cfg, regimen, semilla = 1000 + semilla)
  co <- cotas_arq(arq, cfg)
  set.seed(semilla)
  P <- sapply(seq_along(co$lower), function(j) runif(n_eval, co$lower[j], co$upper[j]))
  P <- matrix(P, ncol = length(co$lower))
  t0 <- Sys.time()
  evaluar_fila <- function(i) fitness_nsga(P[i, ], arq, banco_train, cfg)
  Fm <- if (cfg$n_cores > 1 && .Platform$OS.type != "windows") {
    do.call(rbind, parallel::mclapply(seq_len(n_eval), evaluar_fila, mc.cores = cfg$n_cores))
  } else t(sapply(seq_len(n_eval), evaluar_fila))
  nd <- no_dominados(Fm)
  dur <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  ## objeto mínimo con la misma forma que usa validar_corrida
  res <- list(population = P[nd, , drop = FALSE], f = list(seq_len(sum(nd))))
  list(res = res, arq = arq, regimen = regimen, semilla = semilla, minutos = dur, random = TRUE)
}

## Reevalúa el frente 1 de una corrida en el banco de validación y devuelve
## una tabla con parámetros y objetivos validados (solo no dominados).
validar_corrida <- function(corrida, banco_val, cfg) {
  res <- corrida$res; arq <- corrida$arq
  es_random <- isTRUE(corrida$random)
  idx <- if (es_random) res$f[[1]] else res@f[[1]]
  pop <- if (es_random) res$population else res@population
  P <- t(apply(pop[idx, , drop = FALSE], 1, a_natural, arq = arq))
  Fv <- t(apply(P, 1, function(x) evaluar(x, arq, banco_val, cfg)))
  colnames(P) <- nombres_theta(arq)
  colnames(Fv) <- c("error", "umbral", "latencia", "costo")
  ## Todas las arquitecturas comparten las mismas columnas de parámetros
  ## (NA donde el parámetro no existe) para poder apilar las tablas.
  todos <- names(cfg$cotas)
  Pfull <- matrix(NA_real_, nrow(P), length(todos), dimnames = list(NULL, todos))
  Pfull[, colnames(P)] <- P
  tab <- data.frame(arquitectura = arq, regimen = corrida$regimen,
                    semilla = corrida$semilla, metodo = if (es_random) "random" else "NSGA-III",
                    Pfull, Fv, check.names = FALSE)
  tab[no_dominados(Fv), ]
}

## Hipervolumen de un frente en el espacio de objetivos crudo, con un punto de
## referencia fijo (el peor valor posible de cada objetivo), normalizado por el
## volumen total. Sirve para comparar corridas, semillas y generaciones entre
## sí sin que la normalización dependa de la muestra.
## El costo entra en log10 (de 0 a 3), porque en escala lineal el lector
## continuo, que siempre cuesta 1000 lecturas/s, ocupa un volumen nulo y
## quedaría con hipervolumen cero por construcción. El punto de referencia es
## 1.1 veces el peor valor en cada eje, como recomiendan para el hipervolumen.
REF_FIJO <- function(cfg) c(error = 1, umbral = max(cfg$isis) * 1.5, latencia = cfg$T_ensayo, costo = 3)
OBJ <- c("error", "umbral", "latencia", "costo")
hv_fijo <- function(F, cfg) {
  ref <- REF_FIJO(cfg)
  M <- as.matrix(F)[, names(ref), drop = FALSE]
  if (nrow(M) == 0) return(0)
  M[, "costo"] <- log10(pmax(M[, "costo"], 1))
  hv_exacto(pmin(pmax(sweep(M, 2, ref, "/"), 0), 1))
}

## Hipervolumen sobre objetivos normalizados a [0, 1] con los mínimos y
## máximos dados, punto de referencia 1.1 en cada eje.
hipervolumen <- function(F, minimos, maximos) {
  if (nrow(F) == 0) return(0)
  Z <- sweep(sweep(as.matrix(F), 2, minimos, "-"), 2, maximos - minimos, "/")
  hv_exacto(pmin(pmax(Z, 0), 1))
}
## Cobertura C(A, B): fracción de soluciones de B dominadas o igualadas por
## alguna de A (Zitzler y Thiele, 1999).
cobertura <- function(A, B) {
  A <- as.matrix(A); B <- as.matrix(B)
  if (nrow(B) == 0) return(NA_real_)
  if (nrow(A) == 0) return(0)
  tA <- t(A); d <- ncol(A)
  mean(apply(B, 1, function(b) any(colSums(tA <= b) == d)))
}

## ----------------------------------------------------------------------------
## Paralelismo por corridas. Cada corrida (una arquitectura, una semilla, un
## método) es independiente: se reparten corridas completas entre los núcleos y
## cada una corre secuencial por dentro, con su propia semilla. Así el
## resultado no depende de cuántos núcleos tenga la máquina, y no se pierde
## tiempo abriendo y cerrando procesos en cada generación, que era lo que más
## costaba al repartir las evaluaciones de una sola generación entre 60
## núcleos. Cada corrida terminada deja una línea con la hora en
## salida/progreso.log, que se puede mirar mientras el script corre.
## ----------------------------------------------------------------------------
registrar_progreso <- function(cfg, texto) {
  linea <- sprintf("%s  %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), texto)
  cat(linea)
  cat(linea, file = file.path(cfg$carpeta, "progreso.log"), append = TRUE)
}

correr_tareas <- function(tareas, FUN, cfg, bloque) {
  n <- length(tareas)
  nucleos <- max(1L, min(as.integer(cfg$n_cores), n))
  t0 <- Sys.time()
  registrar_progreso(cfg, sprintf("[%s] inicio: %d corridas en %d núcleos", bloque, n, nucleos))
  res <- if (nucleos > 1 && .Platform$OS.type != "windows") {
    parallel::mclapply(tareas, function(t) tryCatch(FUN(t), error = function(e) structure(conditionMessage(e), class = "error_tarea")),
                       mc.cores = nucleos, mc.preschedule = FALSE)
  } else lapply(tareas, FUN)
  ## Una corrida que falló en paralelo (error o proceso caído) se repite de a
  ## una; si vuelve a fallar, el error detiene el script con su mensaje.
  malas <- which(vapply(res, function(r) is.null(r) || inherits(r, c("error_tarea", "try-error")), logical(1)))
  if (length(malas) > 0) {
    motivos <- unique(unlist(lapply(res[malas], function(r) if (is.null(r)) "proceso caído" else as.character(r))))
    registrar_progreso(cfg, sprintf("[%s] %d corridas fallaron en paralelo (%s); se repiten de a una",
                                    bloque, length(malas), paste(motivos, collapse = " | ")))
    for (k in malas) res[[k]] <- FUN(tareas[[k]])
  }
  registrar_progreso(cfg, sprintf("[%s] fin: %d corridas en %.1f min", bloque, n,
                                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  res
}

## Especificaciones de corridas como producto de arquitecturas por semillas,
## para un régimen, un método y una configuración.
especificar <- function(cfg, arqs, semillas, regimen, metodo = "NSGA-III", etiqueta = "base", ...) {
  extra <- list(...)
  unlist(lapply(arqs, function(a) lapply(semillas, function(s)
    c(list(cfg = cfg, arq = a, semilla = s, regimen = regimen, metodo = metodo, etiqueta = etiqueta), extra))),
    recursive = FALSE)
}

## Una corrida completa: optimización (o búsqueda aleatoria), validación en un
## banco de ensayos nuevo e hipervolumen del frente validado.
una_corrida <- function(e, cfg_base) {
  cfg_e <- e$cfg; cfg_e$n_cores <- 1L
  banco_val <- crear_banco(cfg_e$n_un_pulso_val, cfg_e$n_por_isi_val, cfg_e, e$regimen, semilla = 999)
  es_random <- identical(e$metodo, "random")
  cr <- if (es_random) correr_random(e$arq, e$regimen, e$semilla, cfg_e)
        else correr_nsga(e$arq, e$regimen, e$semilla, cfg_e, registrar = isTRUE(e$registrar))
  fr <- validar_corrida(cr, banco_val, cfg_e)
  fr$condicion <- e$etiqueta
  hv <- hv_fijo(fr[, OBJ], cfg_e)
  registrar_progreso(cfg_base, sprintf("[%s] %-8s %-18s %-8s semilla %3d: %6.1f min, frente %3d, HV %.4f",
                                       e$bloque, e$metodo, e$arq, e$regimen, e$semilla, cr$minutos, nrow(fr), hv))
  list(frente = fr, hv = hv, minutos = cr$minutos, hv_por_generacion = cr$hv_por_generacion,
       objeto = if (isTRUE(e$guardar_objeto)) cr else NULL)
}
correr_corridas <- function(especs, cfg, bloque) {
  especs <- lapply(especs, function(e) { e$bloque <- bloque; e })
  correr_tareas(especs, function(e) una_corrida(e, cfg), cfg, bloque)
}

## Rodilla: solución más cercana al punto ideal en objetivos normalizados.
rodilla <- function(F, minimos, maximos) {
  Z <- sweep(sweep(F, 2, minimos, "-"), 2, maximos - minimos, "/")
  which.min(sqrt(rowSums(Z^2)))
}

## ============================================================================
## 5b. Pregunta 0: validación del optimizador
## ============================================================================
## Todo sobre el régimen limpio. Devuelve la configuración elegida (que la
## ejecución aplica a las preguntas siguientes), la curva de convergencia, las
## estadísticas de consistencia sobre 11 semillas y la comparación con la
## búsqueda aleatoria. Nada de esto decide la hipótesis; decide si se puede
## confiar en el optimizador que la pone a prueba.
validacion_optimizador <- function(cfg) {
  cat("\n== Pregunta 0: validación del optimizador ==\n")
  reg <- names(cfg$regimenes)[1]
  v <- cfg$validacion

  ## --- 0a. Parametrización ---------------------------------------------------
  cat("\n-- 0a. Parametrización (rejilla de población, cruce y mutación) --\n")
  pz <- v$parametrizacion
  rejilla <- expand.grid(i_pop = seq_along(pz$popSize), pcrossover = pz$pcrossover, pmutation = pz$pmutation)
  especs <- list()
  for (k in seq_len(nrow(rejilla))) {
    cfg_k <- cfg
    cfg_k$popSize <- pz$popSize[rejilla$i_pop[k]]; cfg_k$n_partitions <- pz$n_partitions[rejilla$i_pop[k]]
    cfg_k$pcrossover <- rejilla$pcrossover[k]; cfg_k$pmutation <- rejilla$pmutation[k]
    ## presupuesto igual para todas las configuraciones: mismas evaluaciones
    cfg_k$maxiter <- round(pz$maxiter * cfg$popSize / cfg_k$popSize)
    especs <- c(especs, especificar(cfg_k, cfg$arquitecturas, pz$semillas, reg))
  }
  res <- correr_corridas(especs, cfg, "0a parametrizacion")
  param <- do.call(rbind, lapply(seq_along(especs), function(i) {
    e <- especs[[i]]
    data.frame(popSize = e$cfg$popSize, n_partitions = e$cfg$n_partitions, pcrossover = e$cfg$pcrossover,
               pmutation = e$cfg$pmutation, maxiter = e$cfg$maxiter, arquitectura = e$arq, semilla = e$semilla,
               hv_validacion = res[[i]]$hv, n_frente = nrow(res[[i]]$frente), minutos = res[[i]]$minutos)
  }))
  write.csv(param, file.path(cfg$carpeta, "validation_parametrisation_runs.csv"), row.names = FALSE)
  ## resumen: mediana del hipervolumen por configuración (sobre arquitecturas y semillas)
  resumen <- aggregate(hv_validacion ~ popSize + n_partitions + pcrossover + pmutation + maxiter, data = param, FUN = median)
  names(resumen)[6] <- "median_hv"
  resumen$mean_hv <- aggregate(hv_validacion ~ popSize + n_partitions + pcrossover + pmutation + maxiter, data = param, FUN = mean)$hv_validacion
  resumen <- resumen[order(-resumen$median_hv), ]
  write.csv(resumen, file.path(cfg$carpeta, "validation_parametrisation_summary.csv"), row.names = FALSE)
  cat("\nConfiguraciones ordenadas por hipervolumen mediano de validación:\n"); print(head(resumen, 10), row.names = FALSE, digits = 4)
  elegida <- resumen[1, ]
  cfg_sel <- cfg
  cfg_sel$popSize <- elegida$popSize; cfg_sel$n_partitions <- elegida$n_partitions
  cfg_sel$pcrossover <- elegida$pcrossover; cfg_sel$pmutation <- elegida$pmutation
  cat(sprintf("\nElegida: popSize %d (n_partitions %d), pcrossover %.2f, pmutation %.2f\n",
              cfg_sel$popSize, cfg_sel$n_partitions, cfg_sel$pcrossover, cfg_sel$pmutation))

  ## --- 0b. Convergencia ------------------------------------------------------
  cat("\n-- 0b. Convergencia (hipervolumen del primer frente por generación) --\n")
  cfg_c <- cfg_sel; cfg_c$maxiter <- v$convergencia$maxiter
  especs <- especificar(cfg_c, cfg$arquitecturas, v$convergencia$semillas, reg, registrar = TRUE)
  res <- correr_corridas(especs, cfg, "0b convergencia")
  conv <- list(); corte <- list()
  for (i in seq_along(especs)) {
    arq <- especs[[i]]$arq; sem <- especs[[i]]$semilla
    hv_gen <- res[[i]]$hv_por_generacion
    ## el hipervolumen por generación puede bajar un poco entre generaciones
    ## (el frente de entrenamiento se reordena); se usa el máximo acumulado
    hv_acum <- cummax(hv_gen)
    conv[[length(conv) + 1]] <- data.frame(arquitectura = arq, semilla = sem, generation = seq_along(hv_gen),
                                           hv_training = hv_gen, hv_running_max = hv_acum)
    final <- max(hv_acum)
    corte[[length(corte) + 1]] <- data.frame(
      arquitectura = arq, semilla = sem, hv_final = final,
      generation_95pct = which(hv_acum >= 0.95 * final)[1],
      generation_99pct = which(hv_acum >= 0.99 * final)[1],
      generation_999pct = which(hv_acum >= 0.999 * final)[1],
      generations_run = length(hv_gen))
  }
  conv <- do.call(rbind, conv); corte <- do.call(rbind, corte)
  write.csv(conv, file.path(cfg$carpeta, "validation_convergence_curve.csv"), row.names = FALSE)
  write.csv(corte, file.path(cfg$carpeta, "validation_convergence_cutoff.csv"), row.names = FALSE)
  cat("\nGeneración en que el hipervolumen alcanza el 95 %, 99 % y 99.9 % de su valor final:\n"); print(corte, row.names = FALSE, digits = 4)
  ## Corte para las corridas principales: mediana entre arquitecturas y
  ## semillas de la generación del 99 %, por el margen, con un mínimo.
  g99_med <- median(corte$generation_99pct)
  corte_elegido <- max(v$convergencia$maxiter_minimo, ceiling(g99_med * v$convergencia$margen))
  corte_elegido <- min(corte_elegido, v$convergencia$maxiter)
  cat(sprintf("\nMediana de la generación del 99 %%: %d; corte elegido para las corridas principales: %d generaciones (margen %.1f, mínimo %d)\n",
              as.integer(g99_med), corte_elegido, v$convergencia$margen, v$convergencia$maxiter_minimo))
  cfg_sel$maxiter <- corte_elegido
  write.csv(data.frame(median_generation_99pct = g99_med, safety_margin = v$convergencia$margen,
                       minimum = v$convergencia$maxiter_minimo, generations_main_runs = corte_elegido),
            file.path(cfg$carpeta, "validation_convergence_chosen_cutoff.csv"), row.names = FALSE)
  conv$architecture <- arq_en(conv$arquitectura)
  g10 <- ggplot(conv, aes(generation, hv_running_max, colour = architecture, group = interaction(architecture, semilla))) +
    geom_line(linewidth = 0.8, alpha = 0.85) +
    geom_vline(xintercept = corte_elegido, linetype = 2, colour = "grey50") +
    escala_arq("colour") +
    labs(x = "generation", y = "hypervolume of the first front",
         title = sprintf("Convergence of NSGA-III per architecture (%d seeds each)", length(v$convergencia$semillas)),
         subtitle = sprintf("Running maximum on the training bank, fixed reference point. Dashed line: cutoff for the main runs (%d generations)", corte_elegido)) +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig10_convergence.png"), g10, width = 9, height = 5, dpi = 150, bg = "white")

  ## --- 0c. Consistencia sobre semillas y 0d. búsqueda aleatoria ---------------
  cat("\n-- 0c. Consistencia (11 semillas) y 0d. búsqueda aleatoria con el mismo presupuesto --\n")
  especs <- c(especificar(cfg_sel, cfg$arquitecturas, v$consistencia$semillas, reg, metodo = "NSGA-III"),
              especificar(cfg_sel, cfg$arquitecturas, v$random$semillas, reg, metodo = "random"))
  res <- correr_corridas(especs, cfg, "0c-0d semillas y random search")
  runs <- do.call(rbind, lapply(seq_along(especs), function(i) data.frame(
    method = especs[[i]]$metodo, arquitectura = especs[[i]]$arq, semilla = especs[[i]]$semilla,
    hv_validation = res[[i]]$hv, n_front = nrow(res[[i]]$frente), minutes = res[[i]]$minutos)))
  frentes <- do.call(rbind, lapply(res, `[[`, "frente"))
  write.csv(runs, file.path(cfg$carpeta, "validation_seed_runs.csv"), row.names = FALSE)
  write.csv(frentes, file.path(cfg$carpeta, "validation_seed_fronts.csv"), row.names = FALSE)

  ## estadísticas por método y arquitectura
  est <- do.call(rbind, lapply(split(runs, list(runs$method, runs$arquitectura), drop = TRUE), function(d) data.frame(
    method = d$method[1], arquitectura = d$arquitectura[1], n_runs = nrow(d),
    hv_mean = mean(d$hv_validation), hv_sd = sd(d$hv_validation), hv_min = min(d$hv_validation),
    hv_median = median(d$hv_validation), hv_max = max(d$hv_validation),
    front_size_mean = mean(d$n_front), minutes_mean = mean(d$minutes))))
  rownames(est) <- NULL
  write.csv(est, file.path(cfg$carpeta, "validation_seed_summary.csv"), row.names = FALSE)
  cat("\nHipervolumen de validación por método y arquitectura (sobre semillas):\n"); print(est, row.names = FALSE, digits = 4)

  ## Wilcoxon pareado por semilla: NSGA-III vs random (misma arquitectura) y
  ## entre arquitecturas (NSGA-III), más cobertura NSGA-III sobre random
  nsga <- runs[runs$method == "NSGA-III", ]; rnd <- runs[runs$method == "random", ]
  pruebas <- list()
  for (arq in cfg$arquitecturas) {
    a <- nsga[nsga$arquitectura == arq, ]; b <- rnd[rnd$arquitectura == arq, ]
    comun <- intersect(a$semilla, b$semilla)
    if (length(comun) >= 3) {
      w <- wilcox.test(a$hv_validation[match(comun, a$semilla)], b$hv_validation[match(comun, b$semilla)], paired = TRUE, exact = FALSE)
      fa <- frentes[frentes$arquitectura == arq & frentes$metodo == "NSGA-III", c("error", "umbral", "latencia", "costo")]
      fb <- frentes[frentes$arquitectura == arq & frentes$metodo == "random", c("error", "umbral", "latencia", "costo")]
      pruebas[[length(pruebas) + 1]] <- data.frame(
        comparison = "NSGA-III vs random search", arquitectura = arq, n_pairs = length(comun),
        hv_gain_mean = mean(a$hv_validation[match(comun, a$semilla)] - b$hv_validation[match(comun, b$semilla)]),
        p_wilcoxon = w$p.value, coverage_nsga_over_random = cobertura(as.matrix(fa), as.matrix(fb)),
        coverage_random_over_nsga = cobertura(as.matrix(fb), as.matrix(fa)))
    }
  }
  pares <- combn(cfg$arquitecturas, 2)
  for (k in seq_len(ncol(pares))) {
    a <- nsga[nsga$arquitectura == pares[1, k], ]; b <- nsga[nsga$arquitectura == pares[2, k], ]
    comun <- intersect(a$semilla, b$semilla)
    if (length(comun) >= 3) {
      w <- wilcox.test(a$hv_validation[match(comun, a$semilla)], b$hv_validation[match(comun, b$semilla)], paired = TRUE, exact = FALSE)
      pruebas[[length(pruebas) + 1]] <- data.frame(
        comparison = sprintf("%s vs %s (NSGA-III)", ARQ_EN[pares[1, k]], ARQ_EN[pares[2, k]]), arquitectura = NA, n_pairs = length(comun),
        hv_gain_mean = mean(a$hv_validation[match(comun, a$semilla)] - b$hv_validation[match(comun, b$semilla)]),
        p_wilcoxon = w$p.value, coverage_nsga_over_random = NA, coverage_random_over_nsga = NA)
    }
  }
  pruebas <- do.call(rbind, pruebas)
  write.csv(pruebas, file.path(cfg$carpeta, "validation_tests.csv"), row.names = FALSE)
  cat("\nPruebas pareadas por semilla (Wilcoxon) y cobertura:\n"); print(pruebas, row.names = FALSE, digits = 3)

  ## fracción del frente combinado por semilla (NSGA-III): ¿el orden de las
  ## arquitecturas se repite en cada semilla?
  obj <- c("error", "umbral", "latencia", "costo")
  fn <- frentes[frentes$metodo == "NSGA-III", ]
  comb_sem <- do.call(rbind, lapply(split(fn, fn$semilla), function(d) {
    nd <- no_dominados(as.matrix(d[, obj]))
    tb <- table(factor(d$arquitectura[nd], levels = cfg$arquitecturas))
    data.frame(semilla = d$semilla[1], arquitectura = names(tb), share_combined_front = as.numeric(tb) / sum(tb))
  }))
  write.csv(comb_sem, file.path(cfg$carpeta, "validation_seed_combined_front.csv"), row.names = FALSE)
  rango <- aggregate(share_combined_front ~ arquitectura, data = comb_sem, FUN = function(v) c(mean = mean(v), min = min(v), max = max(v)))
  cat("\nFracción del frente combinado por arquitectura a través de las semillas (media, mín, máx):\n"); print(rango, digits = 3)
  ganadora <- aggregate(share_combined_front ~ semilla, data = comb_sem, FUN = max)
  ganadora$winner <- sapply(ganadora$semilla, function(s) { d <- comb_sem[comb_sem$semilla == s, ]; d$arquitectura[which.max(d$share_combined_front)] })
  cat("Arquitectura con mayor fracción del frente combinado, por semilla:\n"); print(table(ganadora$winner))

  runs$architecture <- arq_en(runs$arquitectura)
  g11 <- ggplot(runs, aes(architecture, hv_validation, fill = method)) +
    geom_boxplot(outlier.shape = 21, alpha = 0.9, width = 0.6, position = position_dodge(width = 0.75)) +
    geom_point(position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.75), size = 1.2, colour = "grey30", alpha = 0.7) +
    scale_fill_manual(values = c("NSGA-III" = "#A7C7E7", "random" = "#D9D9D9"), name = NULL) +
    labs(x = NULL, y = "validation hypervolume (fixed reference)",
         title = sprintf("Consistency across %d seeds and comparison with random search at equal budget", length(v$consistencia$semillas))) +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig11_seeds_vs_random.png"), g11, width = 9, height = 5, dpi = 150, bg = "white")
  comb_sem$architecture <- arq_en(comb_sem$arquitectura)
  g12 <- ggplot(comb_sem, aes(factor(semilla), share_combined_front, fill = architecture)) +
    geom_col(width = 0.8) + escala_arq("fill") +
    labs(x = "seed", y = "share of the combined front", title = "Share of the combined front per seed (NSGA-III, clean input)") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig12_seeds_combined_front.png"), g12, width = 9, height = 5, dpi = 150, bg = "white")

  list(cfg = cfg_sel, parametrisation = resumen, convergence = conv, cutoff = corte,
       seed_runs = runs, seed_summary = est, tests = pruebas, combined_by_seed = comb_sem)
}

## ============================================================================
## 6. Pregunta 1: diseño
## ============================================================================
## Frente validado por arquitectura y grupo (unión de semillas, filtrado),
## con la marca de agente funcional: alcanza el criterio de sensibilidad en
## algún ISI (umbral distinto de la penalización). Los no funcionales son
## agentes que casi no leen: baratos, pero inútiles. Se conservan en las
## tablas porque son parte honesta del frente, y las métricas se calculan
## sobre el frente completo y sobre el subconjunto funcional.
consolidar_frentes <- function(frentes, cfg, grupo = "regimen") {
  obj <- c("error", "umbral", "latencia", "costo")
  frente_arq <- do.call(rbind, lapply(split(frentes, list(frentes$arquitectura, frentes[[grupo]]), drop = TRUE),
                                      function(d) d[no_dominados(as.matrix(d[, obj])), ]))
  rownames(frente_arq) <- NULL
  frente_arq$funcional <- frente_arq$umbral < max(cfg$isis) * 1.5
  frente_arq
}

## Métricas por grupo: hipervolumen, cobertura C(A, B), participación en el
## frente combinado y rodillas (estas últimas solo entre funcionales).
metricas_frentes <- function(frente_arq, cfg, grupo = "regimen") {
  obj <- c("error", "umbral", "latencia", "costo")
  met <- list(); cob <- list(); rod <- list()
  for (g in unique(frente_arq[[grupo]])) {
    for (subconjunto in c("completo", "funcional")) {
      d <- frente_arq[frente_arq[[grupo]] == g, ]
      if (subconjunto == "funcional") d <- d[d$funcional, ]
      if (nrow(d) == 0) next
      Fall <- as.matrix(d[, obj])
      ## El hipervolumen relativo se calcula con el costo en log10, por la
      ## misma razón que en hv_fijo; la dominancia se evalúa en escala cruda
      ## (es invariante a transformaciones monótonas).
      Flog <- Fall; Flog[, "costo"] <- log10(pmax(Flog[, "costo"], 1))
      minimos <- apply(Flog, 2, min); maximos <- apply(Flog, 2, max)
      maximos[maximos == minimos] <- minimos[maximos == minimos] + 1e-9
      comb <- no_dominados(Fall)
      for (arq in cfg$arquitecturas) {
        sel <- d$arquitectura == arq
        if (!any(sel)) next
        Fa <- Fall[sel, , drop = FALSE]
        fila <- data.frame(grupo = g, subconjunto = subconjunto, arquitectura = arq, n_frente = nrow(Fa),
                           hipervolumen = hipervolumen(Flog[sel, , drop = FALSE], minimos, maximos),
                           en_frente_combinado = sum(comb & sel),
                           fraccion_frente_combinado = sum(comb & sel) / sum(comb))
        names(fila)[1] <- grupo
        met[[length(met) + 1]] <- fila
        if (subconjunto == "funcional") {
          k <- rodilla(Fa, minimos, maximos)
          rod[[length(rod) + 1]] <- d[which(sel)[k], ]
        }
        for (arq2 in cfg$arquitecturas) if (arq2 != arq && any(d$arquitectura == arq2)) {
          fila <- data.frame(grupo = g, subconjunto = subconjunto, A = arq, B = arq2,
                             cobertura_A_sobre_B = cobertura(Fa, Fall[d$arquitectura == arq2, , drop = FALSE]))
          names(fila)[1] <- grupo
          cob[[length(cob) + 1]] <- fila
        }
      }
    }
  }
  met <- do.call(rbind, met); cob <- do.call(rbind, cob); rod <- do.call(rbind, rod)
  rownames(rod) <- NULL
  list(met = met, cob = cob, rod = rod)
}

pregunta_1 <- function(cfg) {
  cat("\n== Pregunta 1: NSGA-III por arquitectura, régimen y semilla ==\n")
  especs <- unlist(lapply(names(cfg$regimenes), function(rg)
    especificar(cfg, cfg$arquitecturas, cfg$semillas, rg, guardar_objeto = TRUE)), recursive = FALSE)
  res <- correr_corridas(especs, cfg, "1 diseño")
  saveRDS(lapply(res, `[[`, "objeto"), file.path(cfg$carpeta, "corridas_nsga3.rds"))
  frentes <- do.call(rbind, lapply(res, `[[`, "frente"))
  frente_arq <- consolidar_frentes(frentes, cfg, grupo = "regimen")
  write.csv(frente_arq, file.path(cfg$carpeta, "frentes_validados.csv"), row.names = FALSE)
  m <- metricas_frentes(frente_arq, cfg, grupo = "regimen")
  met <- m$met; cob <- m$cob; rod <- m$rod
  write.csv(met, file.path(cfg$carpeta, "metricas_frentes.csv"), row.names = FALSE)
  write.csv(cob, file.path(cfg$carpeta, "cobertura_frentes.csv"), row.names = FALSE)
  write.csv(rod, file.path(cfg$carpeta, "rodillas.csv"), row.names = FALSE)
  cat("\nMétricas por arquitectura y régimen:\n"); print(met, row.names = FALSE, digits = 3)
  cat("\nCobertura C(A, B):\n"); print(cob, row.names = FALSE, digits = 3)

  ## Figura 1: proyecciones 2D de los frentes validados
  pares <- list(c("costo", "error"), c("costo", "umbral"), c("costo", "latencia"),
                c("umbral", "error"), c("latencia", "error"), c("umbral", "latencia"))
  ## El costo va en log10 porque abarca de 1 a 1000 lecturas/s; los demás
  ## objetivos van en escala lineal.
  OBJ_EN <- c(error = "error rate", umbral = "fusion threshold (ms)", latencia = "access latency (ms)", costo = "log10 cost (reads/s)")
  REG_EN <- c(limpio = "clean input", rafagas = "bursty input")
  largo <- do.call(rbind, lapply(pares, function(p) {
    x <- frente_arq[[p[1]]]
    if (p[1] == "costo") x <- log10(x)
    data.frame(regime = REG_EN[frente_arq$regimen], architecture = arq_en(frente_arq$arquitectura),
               pair = paste(OBJ_EN[p[1]], "vs", OBJ_EN[p[2]]),
               x = x, y = frente_arq[[p[2]]])
  }))
  largo$pair <- factor(largo$pair, levels = unique(largo$pair))
  g1 <- ggplot(largo, aes(x, y, colour = architecture, shape = architecture)) +
    geom_point(alpha = 0.8, size = 2) +
    facet_wrap(~ regime + pair, scales = "free", ncol = length(pares)) +
    escala_arq("colour") + scale_shape_manual(values = c(16, 15, 17, 18, 4), name = "architecture") +
    labs(x = "objective on the horizontal axis", y = "objective on the vertical axis",
         title = "Validated Pareto fronts by architecture",
         subtitle = "Objectives (all minimised): error rate, fusion threshold, access latency, cost") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig1_fronts.png"), g1, width = 14, height = 4 + 3 * length(cfg$regimenes), dpi = 150, bg = "white")

  ## Figura 2: intervalo entre lecturas (o periodo de la modulación) en el frente
  dper <- data.frame(regime = REG_EN[frente_arq$regimen], architecture = arq_en(frente_arq$arquitectura),
                     interval = ifelse(frente_arq$arquitectura == "periodica", frente_arq$T,
                                ifelse(frente_arq$arquitectura == "eventos", frente_arq$r, frente_arq$T_mod)),
                     error = frente_arq$error)
  dper <- dper[frente_arq$arquitectura != "continua", ]
  g2 <- ggplot(dper, aes(interval, error, colour = regime)) +
    geom_vline(xintercept = 100, linetype = 2, colour = "grey50") +
    geom_point(size = 2, alpha = 0.85) +
    facet_wrap(~ architecture, scales = "free_x") +
    scale_colour_manual(values = PALETA_2, name = NULL) +
    labs(x = "period T (periodic), refractory r (event-driven) or modulation period (modulated continuous), ms",
         y = "validated error rate",
         title = "Inter-read intervals on the front (dashed line: 100 ms, one alpha cycle)") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig2_intervals.png"), g2, width = 12, height = 4.5, dpi = 150, bg = "white")

  list(frentes = frente_arq, metricas = met, cobertura = cob, rodillas = rod)
}

## ============================================================================
## 6b. Pregunta 1, análisis de sensibilidad
## ============================================================================
## Repite la pregunta de diseño (régimen limpio, una semilla, menos
## generaciones) cambiando de a uno los supuestos del estímulo que un revisor
## va a cuestionar: duración del pulso, ruido y rango de ISI. Lo que importa
## no son los números sino si el ordenamiento de las arquitecturas se mantiene:
## fracción del frente combinado, hipervolumen, cobertura de eventos sobre
## periódica, y dónde queda el periodo del lector periódico (mediana del
## frente funcional y fracción dentro de la banda alfa, 80 a 125 ms).
## La condición "base" se toma de la pregunta 1 sin volver a correrla.
sensibilidad <- function(cfg, frentes_base) {
  cat("\n== Pregunta 1b: sensibilidad a los supuestos del estímulo ==\n")
  conds <- cfg$sensibilidad$condiciones
  reg <- names(cfg$regimenes)[1]
  base <- frentes_base[frentes_base$regimen == reg, ]
  base$condicion <- "base"
  maxiter_s <- if (is.na(cfg$sensibilidad$maxiter)) cfg$maxiter else cfg$sensibilidad$maxiter
  especs <- list()
  for (nm in names(conds)) {
    cat(sprintf(" condición %s: %s\n", nm, paste(names(conds[[nm]]), sapply(conds[[nm]], function(v) paste(range(v), collapse = " a ")), sep = " = ", collapse = ", ")))
    cfg_c <- modifyList(cfg, conds[[nm]]); cfg_c$maxiter <- maxiter_s
    especs <- c(especs, especificar(cfg_c, cfg$arquitecturas, cfg$sensibilidad$semilla, reg, etiqueta = nm))
  }
  res <- correr_corridas(especs, cfg, "1b sensibilidad")
  etiquetas <- vapply(especs, `[[`, character(1), "etiqueta")
  todos <- list(base)
  for (nm in names(conds)) {
    fr <- do.call(rbind, lapply(res[etiquetas == nm], `[[`, "frente"))
    todos[[nm]] <- consolidar_frentes(fr, modifyList(cfg, conds[[nm]]), grupo = "condicion")
  }
  frentes <- do.call(rbind, todos)
  frentes$condicion <- factor(frentes$condicion, levels = c("base", names(conds)))
  write.csv(frentes, file.path(cfg$carpeta, "sensibilidad_frentes.csv"), row.names = FALSE)
  m <- metricas_frentes(frentes, cfg, grupo = "condicion")
  per <- frentes[frentes$arquitectura == "periodica" & frentes$funcional, ]
  alfa <- do.call(rbind, lapply(split(per, per$condicion, drop = TRUE), function(d) data.frame(
    condicion = d$condicion[1], n_periodicas_funcionales = nrow(d), mediana_T_ms = median(d$T),
    fraccion_T_en_banda_alfa = mean(d$T >= 80 & d$T <= 125))))
  write.csv(m$met, file.path(cfg$carpeta, "sensibilidad_metricas.csv"), row.names = FALSE)
  write.csv(m$cob, file.path(cfg$carpeta, "sensibilidad_cobertura.csv"), row.names = FALSE)
  write.csv(alfa, file.path(cfg$carpeta, "sensibilidad_periodo_periodico.csv"), row.names = FALSE)
  cat("\nFracción del frente combinado (subconjunto funcional) por condición:\n")
  print(reshape(m$met[m$met$subconjunto == "funcional", c("condicion", "arquitectura", "fraccion_frente_combinado")],
                idvar = "condicion", timevar = "arquitectura", direction = "wide"), row.names = FALSE, digits = 3)
  cat("\nCobertura de eventos sobre periódica (funcional) por condición:\n")
  print(m$cob[m$cob$subconjunto == "funcional" & m$cob$A == "eventos" & m$cob$B == "periodica", ], row.names = FALSE, digits = 3)
  cat("\nPeriodo del lector periódico por condición:\n"); print(alfa, row.names = FALSE, digits = 3)

  mf <- m$met[m$met$subconjunto == "funcional", ]
  COND_EN <- c(base = "baseline", pulso_5 = "pulse 5 ms", pulso_20 = "pulse 20 ms",
               ruido_0.4 = "noise 0.4", ruido_0.9 = "noise 0.9", isi_corto = "ISI 5 to 70 ms")
  mf$condition <- factor(COND_EN[as.character(mf$condicion)], levels = COND_EN[c("base", names(conds))])
  mf$architecture <- arq_en(mf$arquitectura)
  g9 <- ggplot(mf, aes(condition, fraccion_frente_combinado, fill = architecture)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    escala_arq("fill") +
    labs(x = NULL, y = "share of the combined front (functional agents)",
         title = "Sensitivity: share of each architecture in the combined front under changes of the stimulus") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig9_sensitivity.png"), g9, width = 10, height = 5, dpi = 150, bg = "white")
  list(frentes = frentes, metricas = m$met, cobertura = m$cob, periodo_periodico = alfa)
}

## ============================================================================
## 7. Pregunta 2: ajuste a datos conductuales
## ============================================================================
## Formato del CSV (una fila por ensayo):
##   participante : identificador (texto)
##   isi          : intervalo onset a onset en ms (0 en ensayos de un pulso)
##   n_pulsos     : 1 o 2 (lo que se presentó)
##   respuesta    : 1 o 2 (lo que reportó el participante)
##   iaf          : frecuencia alfa individual en Hz (repetida por fila; NA si no hay)
##   fase_prestim : opcional, fase alfa prestímulo en radianes [0, 2pi)
## Los ISI del CSV deben estar dentro del rango de CFG$isis; el ajuste simula
## exactamente los ISI que aparecen en los datos de cada participante.

## Banco de simulación para el ajuste (un banco por participante, con sus ISI)
banco_ajuste <- function(isis_p, cfg, semilla) {
  cfg2 <- cfg; cfg2$isis <- isis_p
  crear_banco(cfg$ajuste$n_un_pulso, cfg$ajuste$n_por_isi, cfg2, "limpio", semilla)
}

## Log-verosimilitud binomial de un vector de parámetros (escala natural) para
## un participante: el agente se simula sobre el banco, se estima P("dos")
## por condición y se evalúan los conteos observados.
loglik_participante <- function(theta, arq, conteos, banco, cfg, n_por_cond) {
  sim <- simular_agente(theta, arq, banco, cfg)
  sim$clave <- paste(sim$n_pulsos, sim$isi)
  p_sim <- tapply(sim$respuesta == 2, sim$clave, mean)
  p <- p_sim[conteos$clave]
  p <- pmin(pmax(p, 0.5 / (n_por_cond + 1)), 1 - 0.5 / (n_por_cond + 1))
  sum(dbinom(conteos$k_dos, conteos$n, p, log = TRUE))
}

## Puntos de partida plausibles para el GA de ajuste (en escala de búsqueda).
## El paisaje tiene una meseta enorme de agentes que nunca dicen "dos", y sin
## estos puntos el GA puede quedarse en ella.
sugerencias_ajuste <- function(arq) {
  g <- expand.grid(tau = c(8, 15), theta_p = c(0.3, 0.45), m = 25, w = 10,
                   T = c(25, 50, 100, 150), theta_g = 0.35, r = 60, A_mod = 0.5, T_mod = c(50, 100))
  if (arq == "periodica") {
    ## lector de fotogramas: ventana igual al periodo y fusión de medio periodo,
    ## más la variante de lectura instantánea con periodo corto
    g <- rbind(transform(g, w = T, m = T / 2), g[g$T == 25, ])
  }
  g <- unique(g[, nombres_theta(arq), drop = FALSE])
  t(apply(g, 1, a_busqueda, arq = arq))
}

## Ajusta una arquitectura a un participante con GA (un objetivo). La
## verosimilitud final se reevalúa en un banco independiente y más grande
## (n_val_un_pulso, n_val_por_isi), porque el máximo de una verosimilitud
## simulada sobre un banco fijo está sesgado hacia arriba y el sesgo crece con
## el número de parámetros; el AIC se calcula con esa reevaluación.
## Deja un CSV real en el formato interno: columnas numéricas, isi = 0 en los
## ensayos de un pulso (venga como NA o vacío) y sin filas sin respuesta.
normalizar_datos <- function(datos) {
  datos$n_pulsos <- as.integer(datos$n_pulsos)
  datos$respuesta <- as.integer(datos$respuesta)
  datos$isi <- suppressWarnings(as.numeric(datos$isi))
  datos$isi[datos$n_pulsos == 1 | is.na(datos$isi)] <- 0
  datos <- datos[!is.na(datos$respuesta) & !is.na(datos$n_pulsos), ]
  if (!"iaf" %in% names(datos)) datos$iaf <- NA_real_
  datos$iaf <- suppressWarnings(as.numeric(datos$iaf))
  datos
}

ajustar_participante <- function(datos_p, arq, cfg, semilla = 1) {
  datos_p <- normalizar_datos(datos_p)
  datos_p$clave <- paste(datos_p$n_pulsos, datos_p$isi)
  conteos <- aggregate(cbind(k_dos = respuesta == 2, n = 1) ~ clave, data = datos_p, FUN = sum)
  isis_p <- sort(unique(datos_p$isi[datos_p$n_pulsos == 2]))
  banco <- banco_ajuste(isis_p, cfg, semilla)
  co <- cotas_arq(arq, cfg)
  ga_res <- ga(type = "real-valued",
               fitness = function(x) loglik_participante(a_natural(x, arq), arq, conteos, banco, cfg,
                                                         cfg$ajuste$n_por_isi),
               lower = co$lower, upper = co$upper,
               suggestions = head(sugerencias_ajuste(arq), cfg$ajuste$ga_popSize - 4),
               popSize = cfg$ajuste$ga_popSize, maxiter = cfg$ajuste$ga_maxiter,
               run = cfg$ajuste$ga_run, monitor = FALSE, seed = semilla)
  theta <- a_natural(ga_res@solution[1, ], arq)
  ll_train <- as.numeric(ga_res@fitnessValue)
  cfg_val <- cfg; cfg_val$ajuste$n_un_pulso <- cfg$ajuste$n_val_un_pulso
  cfg_val$ajuste$n_por_isi <- cfg$ajuste$n_val_por_isi
  banco_v <- banco_ajuste(isis_p, cfg_val, semilla + 777)
  ll <- loglik_participante(theta, arq, conteos, banco_v, cfg, cfg$ajuste$n_val_por_isi)
  k <- length(theta)
  list(theta = theta, loglik = ll, loglik_entrenamiento = ll_train, aic = 2 * k - 2 * ll, k = k)
}

## Prueba de dependencia de fase: regresión logística de la respuesta "dos" en
## los ensayos de dos pulsos sobre sin y cos de la fase prestímulo, con el ISI
## como covariable, contra el modelo sin fase (prueba de razón de verosimilitud).
prueba_fase <- function(datos_p) {
  if (!"fase_prestim" %in% names(datos_p)) return(NA_real_)
  d <- datos_p[datos_p$n_pulsos == 2 & !is.na(datos_p$fase_prestim), ]
  if (nrow(d) < 30) return(NA_real_)
  d$dos <- as.integer(d$respuesta == 2)
  m0 <- glm(dos ~ isi, data = d, family = binomial)
  m1 <- glm(dos ~ isi + sin(fase_prestim) + cos(fase_prestim), data = d, family = binomial)
  anova(m0, m1, test = "Chisq")$`Pr(>Chi)`[2]
}

## Genera un dataset sintético con un generador conocido. En el generador
## periódico el periodo de cada participante es 1000 / iaf, y la fase
## prestímulo que se exporta es la fase del lector en el onset del primer
## pulso (lo que en datos reales sería la fase alfa en el EEG).
simular_dataset_sintetico <- function(generador, cfg, semilla = 7) {
  set.seed(semilla)
  np <- cfg$ajuste$n_participantes_sint
  filas <- list(); verdaderos <- list()
  for (p in seq_len(np)) {
    iaf <- round(rnorm(1, 10, 1), 2)
    ## Parámetros de generación elegidos para que el participante sintético
    ## rinda como uno real (error cercano a 0.25 o 0.3, umbral del orden de T
    ## en el generador periódico), con variación individual moderada.
    theta <- switch(generador,
      periodica = c(tau = runif(1, 6, 14), theta_p = runif(1, 0.4, 0.55), m = runif(1, 0.3, 0.8) * 1000 / iaf,
                    w = 1000 / iaf, T = 1000 / iaf),
      continua  = c(tau = runif(1, 8, 14), theta_p = runif(1, 0.4, 0.5), m = runif(1, 10, 30), w = runif(1, 1, 20)),
      eventos   = c(tau = runif(1, 8, 14), theta_p = runif(1, 0.1, 0.2), m = runif(1, 20, 60), w = runif(1, 1, 10),
                    theta_g = runif(1, 0.3, 0.45), r = runif(1, 30, 120)),
      continua_modulada = c(tau = runif(1, 8, 14), theta_p = runif(1, 0.4, 0.5), m = runif(1, 10, 30), w = runif(1, 1, 20),
                            A_mod = runif(1, 0.4, 0.7), T_mod = 1000 / iaf))
    banco <- crear_banco(cfg$ajuste$n_un_pulso, cfg$ajuste$n_por_isi, cfg, "limpio", semilla = 5000 + p)
    sim <- simular_agente(theta, generador, banco, cfg)
    ## la fase exportada es la del lector (o de la modulación) en el onset del
    ## primer pulso; en los generadores sin ritmo es ruido uniforme
    fase <- if (generador == "periodica") {
      2 * pi * ((banco$cond$t1 %% round(theta[["T"]])) / round(theta[["T"]]))
    } else if (generador == "continua_modulada") {
      (2 * pi * banco$cond$t1 / theta[["T_mod"]]) %% (2 * pi)
    } else runif(nrow(sim), 0, 2 * pi)
    filas[[p]] <- data.frame(participante = sprintf("S%02d", p), isi = sim$isi, n_pulsos = sim$n_pulsos,
                             respuesta = sim$respuesta, iaf = iaf, fase_prestim = round(fase, 4))
    verdaderos[[p]] <- data.frame(participante = sprintf("S%02d", p), generador = generador, iaf = iaf,
                                  t(theta))
  }
  datos <- do.call(rbind, filas)
  attr(datos, "verdaderos") <- do.call(rbind, verdaderos)
  datos
}

ajustar_dataset <- function(datos, etiqueta, cfg) {
  participantes <- unique(datos$participante)
  cat(sprintf("  Ajustando %d participantes de '%s' a %d arquitecturas\n",
              length(participantes), etiqueta, length(cfg$arquitecturas)))
  ## una tarea por participante y arquitectura, repartidas entre los núcleos
  tareas <- unlist(lapply(participantes, function(p) lapply(cfg$arquitecturas, function(a) list(p = p, arq = a))),
                   recursive = FALSE)
  ajustar_una <- function(t) {
    p <- t$p; arq <- t$arq
    dp <- datos[datos$participante == p, ]
    t0 <- Sys.time()
    aj <- ajustar_participante(dp, arq, cfg, semilla = 1)
    fila <- data.frame(dataset = etiqueta, participante = p, arquitectura = arq,
                 loglik = aj$loglik, loglik_entrenamiento = aj$loglik_entrenamiento, aic = aj$aic, k = aj$k,
                 iaf = if ("iaf" %in% names(dp)) dp$iaf[1] else NA,
                 T_ajustado = if ("T" %in% names(aj$theta)) aj$theta[["T"]] else NA,
                 r_ajustado = if ("r" %in% names(aj$theta)) aj$theta[["r"]] else NA,
                 theta_g_ajustado = if ("theta_g" %in% names(aj$theta)) aj$theta[["theta_g"]] else NA,
                 A_mod_ajustado = if ("A_mod" %in% names(aj$theta)) aj$theta[["A_mod"]] else NA,
                 T_mod_ajustado = if ("T_mod" %in% names(aj$theta)) aj$theta[["T_mod"]] else NA,
                 tau = aj$theta[["tau"]], theta_p = aj$theta[["theta_p"]], m = aj$theta[["m"]], w = aj$theta[["w"]],
                 p_fase = prueba_fase(dp))
    registrar_progreso(cfg, sprintf("[2 ajuste %s] %-18s participante %s: %5.1f min, AIC %.1f", etiqueta, arq, p,
                                    as.numeric(difftime(Sys.time(), t0, units = "mins")), fila$aic))
    fila
  }
  res <- do.call(rbind, correr_tareas(tareas, ajustar_una, cfg, sprintf("2 ajuste %s", etiqueta)))
  res$delta_aic <- ave(res$aic, res$participante, FUN = function(a) a - min(a))
  res$mejor <- res$delta_aic == 0
  ## Margen entre el mejor modelo y el segundo. La log-verosimilitud simulada
  ## tiene un ruido de 1 a 2 unidades, así que un margen menor que 4 no
  ## distingue nada: ahí la decisión entre arquitecturas no puede salir de la
  ## curva psicométrica sola y hay que mirar la fase y la correlación con IAF.
  res$margen_aic <- ave(res$aic, res$participante, FUN = function(a) sort(a)[2] - min(a))
  res$distinguible <- res$margen_aic >= 4
  res
}

## Curvas psicométricas de un dataset humano: P("dos") observada por ISI
## (media y error estándar entre participantes) junto a la que produce cada
## arquitectura con sus parámetros ajustados, simulada en un banco nuevo y
## promediada entre participantes. Es la comparación visual del ajuste.
curvas_psicometricas <- function(res_ds, datos, etiqueta, cfg) {
  datos <- normalizar_datos(datos)
  dos <- datos[datos$n_pulsos == 2, ]
  isis <- sort(unique(dos$isi))
  obs <- aggregate(respuesta == 2 ~ participante + isi, data = dos, FUN = mean)
  names(obs)[3] <- "p_dos"
  cfg2 <- cfg; cfg2$isis <- isis
  banco <- crear_banco(60, 60, cfg2, "limpio", semilla = 4242)
  sim <- do.call(rbind, lapply(seq_len(nrow(res_ds)), function(i) {
    r <- res_ds[i, ]; arq <- r$arquitectura
    theta <- c(tau = r$tau, theta_p = r$theta_p, m = r$m, w = r$w, T = r$T_ajustado,
               theta_g = r$theta_g_ajustado, r = r$r_ajustado,
               A_mod = r$A_mod_ajustado, T_mod = r$T_mod_ajustado)[nombres_theta(arq)]
    s <- simular_agente(theta, arq, banco, cfg2)
    s <- s[s$n_pulsos == 2, ]
    p <- tapply(s$respuesta == 2, s$isi, mean)
    data.frame(participante = r$participante, arquitectura = arq, isi = as.numeric(names(p)), p_dos = as.numeric(p))
  }))
  ee <- function(v) sd(v) / sqrt(length(v))
  obs_m <- aggregate(p_dos ~ isi, data = obs, FUN = mean); obs_m$ee <- aggregate(p_dos ~ isi, data = obs, FUN = ee)$p_dos
  sim_m <- aggregate(p_dos ~ isi + arquitectura, data = sim, FUN = mean)
  sim_m$architecture <- arq_en(sim_m$arquitectura)
  g <- ggplot() +
    geom_ribbon(data = obs_m, aes(isi, ymin = p_dos - ee, ymax = p_dos + ee), fill = "grey75", alpha = 0.5) +
    geom_line(data = obs_m, aes(isi, p_dos), colour = "grey20", linewidth = 1) +
    geom_point(data = obs_m, aes(isi, p_dos), colour = "grey20", size = 2) +
    geom_line(data = sim_m, aes(isi, p_dos, colour = architecture), linewidth = 1) +
    geom_point(data = sim_m, aes(isi, p_dos, colour = architecture), size = 1.8) +
    scale_y_continuous(limits = c(0, 1)) + escala_arq("colour") +
    labs(x = "ISI (ms)", y = "P(\"two\" response)",
         title = sprintf("%s: observed and fitted psychometric curves", etiqueta),
         subtitle = sprintf("Grey: mean and 1 SE across %d participants; colours: each architecture at its fitted parameters",
                            length(unique(obs$participante)))) +
    tema_fig()
  ggsave(file.path(cfg$carpeta, sprintf("fig8_psychometric_%s.png", etiqueta)), g, width = 9, height = 5, dpi = 150, bg = "white")
  ## error cuadrático medio por arquitectura entre curva observada y simulada, por participante
  comp <- merge(obs, sim, by = c("participante", "isi"), suffixes = c("_obs", "_sim"))
  ecm <- aggregate((p_dos_obs - p_dos_sim)^2 ~ arquitectura, data = comp, FUN = mean)
  names(ecm)[2] <- "ecm_curva"; ecm$dataset <- etiqueta
  write.csv(ecm, file.path(cfg$carpeta, sprintf("ajuste_ecm_curva_%s.csv", etiqueta)), row.names = FALSE)
  cat(sprintf("\nError cuadrático medio de la curva psicométrica (%s):\n", etiqueta)); print(ecm, row.names = FALSE, digits = 3)
  ecm
}

pregunta_2 <- function(cfg, csv_real = NA) {
  cat("\n== Pregunta 2: ajuste a datos conductuales ==\n")
  dir.create(file.path(cfg$carpeta, "datos"), showWarnings = FALSE)
  todo <- list(); reales <- list()
  for (gen in cfg$ajuste$generadores) {
    datos <- simular_dataset_sintetico(gen, cfg)
    write.csv(datos, file.path(cfg$carpeta, "datos", sprintf("sintetico_%s.csv", gen)), row.names = FALSE)
    write.csv(attr(datos, "verdaderos"), file.path(cfg$carpeta, "datos", sprintf("sintetico_%s_parametros.csv", gen)), row.names = FALSE)
    todo[[gen]] <- ajustar_dataset(datos, paste0("sintetico_", gen), cfg)
  }
  ## Datos humanos de Deodato y Melcher (2024), si están en el zip (ver la
  ## sección 9 para el origen y el formato). Se ajustan solo los 38
  ## participantes que los autores incluyeron; en modo rápido, los primeros 4.
  f_dm <- file.path("datos_reales", "deodato_melcher_2024", "deodato_melcher_2024_ensayos.csv")
  if (file.exists(f_dm)) {
    dm <- normalizar_datos(read.csv(f_dm))
    dm <- dm[dm$incluido == 1, ]
    if (MODO_RAPIDO) dm <- dm[dm$participante %in% head(unique(dm$participante), 4), ]
    todo[["deodato_melcher_2024"]] <- ajustar_dataset(dm, "deodato_melcher_2024", cfg)
    reales[["deodato_melcher_2024"]] <- dm
  }
  if (!is.na(csv_real)) {
    datos_r <- normalizar_datos(read.csv(csv_real))
    todo[["real"]] <- ajustar_dataset(datos_r, "real", cfg)
    reales[["real"]] <- datos_r
  }
  for (nm in names(reales)) curvas_psicometricas(todo[[nm]], reales[[nm]], nm, cfg)
  res <- do.call(rbind, todo); rownames(res) <- NULL
  write.csv(res, file.path(cfg$carpeta, "ajuste_participantes.csv"), row.names = FALSE)

  ## Recuperación de modelos: cuántos participantes de cada dataset sintético
  ## quedan mejor explicados por cada arquitectura
  tabla_recup <- function(sel) {
    tb <- table(factor(res$dataset[sel], levels = unique(res$dataset)),
                factor(res$arquitectura[sel], levels = cfg$arquitecturas))
    tb <- as.data.frame.matrix(tb)
    cbind(dataset = rownames(tb), tb, row.names = NULL)
  }
  recup <- tabla_recup(res$mejor)
  recup_dist <- tabla_recup(res$mejor & res$distinguible)
  write.csv(recup, file.path(cfg$carpeta, "recuperacion_modelos.csv"), row.names = FALSE)
  write.csv(recup_dist, file.path(cfg$carpeta, "recuperacion_modelos_margen4.csv"), row.names = FALSE)
  cat("\nParticipantes mejor explicados por cada arquitectura (AIC):\n"); print(recup, row.names = FALSE)
  cat("\nLo mismo contando solo los participantes con margen de AIC >= 4 sobre el segundo modelo:\n")
  print(recup_dist, row.names = FALSE)

  ## Correlación entre el periodo ajustado y la frecuencia alfa individual,
  ## para los dos lectores que tienen un periodo (T en el periódico, T_mod en
  ## el continuo modulado)
  per <- res[res$arquitectura %in% c("periodica", "continua_modulada") & !is.na(res$iaf), ]
  per$periodo_ajustado <- ifelse(per$arquitectura == "periodica", per$T_ajustado, per$T_mod_ajustado)
  cors <- do.call(rbind, lapply(split(per, list(per$dataset, per$arquitectura), drop = TRUE), function(d) {
    ct <- if (nrow(d) >= 4) cor.test(d$periodo_ajustado, 1000 / d$iaf) else NULL
    data.frame(dataset = d$dataset[1], arquitectura = d$arquitectura[1], n = nrow(d),
               r_periodo_vs_1000_sobre_iaf = if (is.null(ct)) NA else ct$estimate,
               p = if (is.null(ct)) NA else ct$p.value,
               fraccion_fase_significativa = mean(d$p_fase < 0.05, na.rm = TRUE))
  }))
  if (is.null(cors)) cors <- data.frame(dataset = character(0))
  rownames(cors) <- NULL
  write.csv(cors, file.path(cfg$carpeta, "ajuste_T_vs_iaf.csv"), row.names = FALSE)
  cat("\nPeriodo ajustado vs 1000/IAF y dependencia de fase:\n"); print(cors, row.names = FALSE, digits = 3)

  per$architecture <- arq_en(per$arquitectura)
  g3 <- ggplot(per, aes(1000 / iaf, periodo_ajustado, colour = dataset)) +
    geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
    geom_point(size = 2.5, alpha = 0.9) +
    facet_wrap(~ architecture) +
    scale_colour_manual(values = rep(PALETA_4, 3)[seq_along(unique(per$dataset))], name = NULL) +
    labs(x = "1000 / IAF (ms)", y = "fitted period (ms)",
         title = "Fitted period per participant against the alpha cycle (periodic and modulated continuous readers)") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig3_period_vs_iaf.png"), g3, width = 8, height = 5, dpi = 150, bg = "white")

  res$architecture <- arq_en(res$arquitectura)
  g4 <- ggplot(res, aes(participante, delta_aic, fill = architecture)) +
    geom_col(position = position_dodge()) +
    facet_wrap(~ dataset, scales = "free_x", ncol = 1) + escala_arq("fill") +
    labs(y = "AIC relative to the participant's best model", x = NULL,
         title = "Architecture comparison per participant") +
    tema_fig() + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 7))
  ggsave(file.path(cfg$carpeta, "fig4_fit_aic.png"), g4, width = 10, height = 3.5 * length(todo), dpi = 150, bg = "white")

  list(ajuste = res, recuperacion = recup, correlaciones = cors)
}

## ============================================================================
## 8. Pregunta 3: demostración de ausencias
## ============================================================================
## Se toma la solución rodilla de cada arquitectura (régimen limpio) y se la
## somete a ensayos largos con un hueco forzado de lectura (ausencia). En la
## mitad de los ensayos el fondo sensorial da un escalón durante el hueco; en
## la otra mitad no cambia nada. El agente solo tiene su buffer de lecturas y
## dos maneras de notar el hueco:
##   reloj interno : cuenta sus lecturas y las multiplica por su intervalo
##                   nominal. Sin referencia externa, el error de reloj que
##                   produce el hueco es invisible para él.
##   discontinuidad: un salto entre dos lecturas consecutivas mayor que el que
##                   el integrador podría producir en su intervalo nominal con
##                   entrada acotada (más un margen de ruido de 3 desviaciones).
## El resultado esperado, y el punto del argumento, es que sin cambio sensorial
## ninguna arquitectura detecta el hueco, y que el lector por eventos no lo
## detecta nunca porque sus lecturas valen siempre lo mismo (el umbral).
pregunta_3 <- function(rodillas, cfg) {
  cat("\n== Pregunta 3: ausencias ==\n")
  au <- cfg$ausencias
  filas <- list()
  for (arq in cfg$arquitecturas) {
    rd <- rodillas[rodillas$arquitectura == arq & rodillas$regimen == names(cfg$regimenes)[1], ]
    if (nrow(rd) == 0) { cat("  sin solución funcional para", arq, "; se omite\n"); next }
    rd <- rd[1, ]
    theta <- setNames(as.numeric(rd[nombres_theta(arq)]), nombres_theta(arq))
    tau <- theta[["tau"]]
    for (cambio in c(FALSE, TRUE)) {
      set.seed(if (cambio) 31 else 32)
      n <- au$n_ensayos
      h0 <- round(runif(n, au$hueco_min, au$hueco_max))
      estim <- matrix(0, n, au$T_ensayo)
      if (cambio) for (i in seq_len(n)) estim[i, (h0[i] + au$hueco / 2):au$T_ensayo] <- au$amp_escalon
      banco <- list(estim = estim, ruido = matrix(rnorm(n * au$T_ensayo), n, au$T_ensayo), cond = NULL)
      X <- integrar(tau, banco, cfg)
      detect <- logical(n); err_reloj <- rep(NA_real_, n)
      sd_x <- cfg$sigma * sqrt(cfg$dt / (2 * tau))
      for (i in seq_len(n)) {
        hueco <- c(h0[i], h0[i] + au$hueco)
        tl <- tiempos_lectura(theta, arq, X[i, , drop = FALSE], hueco)[[1]]
        pre <- tl[tl < hueco[1]]
        intervalo_nominal <- switch(arq, continua = 1, continua_modulada = 1, periodica = round(theta[["T"]]),
                                    eventos = if (length(pre) > 1) median(diff(pre)) else NA)
        ## Solo los lectores con intervalo fijo tienen un reloj de lecturas; el
        ## lector por eventos no lo tiene y su error de reloj queda en NA.
        if (arq != "eventos" && !is.na(intervalo_nominal)) err_reloj[i] <- length(tl) * intervalo_nominal - au$T_ensayo
        if (length(tl) < 2) next
        v <- max_movil(X[i, , drop = FALSE], theta[["w"]])[1, tl]
        salto_max <- (1 - exp(-intervalo_nominal / tau)) * cfg$pulso_amp + 3 * sd_x
        if (is.na(salto_max)) next
        detect[i] <- any(abs(diff(v)) > salto_max)
      }
      filas[[length(filas) + 1]] <- data.frame(
        arquitectura = arq, cambio_sensorial = cambio,
        fraccion_huecos_detectados = mean(detect),
        error_reloj_medio_ms = mean(err_reloj, na.rm = TRUE),
        lecturas_medias = mean(sapply(seq_len(n), function(i)
          length(tiempos_lectura(theta, arq, X[i, , drop = FALSE], c(h0[i], h0[i] + au$hueco))[[1]]))))
    }
  }
  res <- do.call(rbind, filas)
  write.csv(res, file.path(cfg$carpeta, "ausencias.csv"), row.names = FALSE)
  cat("\nDetección del propio hueco de lectura:\n"); print(res, row.names = FALSE, digits = 3)
  res$architecture <- arq_en(res$arquitectura)
  g5 <- ggplot(res, aes(architecture, fraccion_huecos_detectados, fill = cambio_sensorial)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6) +
    scale_y_continuous(limits = c(0, 1)) +
    scale_fill_manual(values = c("FALSE" = "#CFCFCF", "TRUE" = "#A7C7E7"),
                      labels = c("FALSE" = "no sensory change", "TRUE" = "sensory change during the gap"), name = NULL) +
    labs(y = "fraction of gaps detected", x = NULL,
         title = sprintf("Absences: a %d ms gap in reading", au$hueco),
         subtitle = "Knee solution of each architecture; the agent only has its own buffer of reads") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig5_absences.png"), g5, width = 8, height = 5, dpi = 150, bg = "white")
  res
}

## ============================================================================
## 9. Datos humanos reales
## ============================================================================
## Dos conjuntos van dentro del zip, en datos_reales/:
##
## deodato_melcher_2024/ (OSF https://osf.io/acb9n, carpeta FF del proyecto;
##   Deodato y Melcher, 2024, J. Neurosci., "Aperiodic EEG predicts variability
##   of visual temporal processing"). FF.mat es el archivo original: la matriz
##   FF (50 x 6) trae por participante el umbral de fusión ajustado por los
##   autores (ms), la pendiente, la tasa de adivinación, la tasa de lapsos, la
##   bondad de ajuste y una bandera de exclusión (12 excluidos, quedan 38);
##   Pcorr (50 x 7) es la proporción de respuestas "dos" en cada ISI (10, 20,
##   30, 40, 50, 60 y 70 ms; destellos de 10 ms, 50 ensayos por ISI); spread es
##   el ancho de la psicométrica. De ahí salen dos CSV: el de participantes
##   (una fila por persona, con esas columnas en castellano) y el de ensayos,
##   que expande Pcorr x 50 a una fila por ensayo en el formato que lee este
##   script (respuesta 2 en k = Pcorr x 50 filas y 1 en el resto). No hay
##   ensayos de un solo destello, así que las falsas alarmas no se observan, y
##   no hay frecuencia alfa en este archivo (está en el EEG de reposo, carpetas
##   CE y OE del mismo proyecto, que no se incluyen por tamaño). Con esto se
##   ajustan las tres arquitecturas a 38 personas (pregunta 2).
##
## haarlem_2024/ (Zenodo 10.5281/zenodo.10844750, CC BY 4.0; Haarlem, C. S.,
##   2024, "Alpha-band oscillations and visual temporal resolution: an
##   expansion and replication"):
##   Alpha_Full_Dataset_final.xlsx : una fila por participante (31) con el
##       umbral de fusión de dos destellos (FF_threshold), la proporción de
##       aciertos, la fusión crítica de parpadeo (CFF_MOC, Hz) y varias
##       estimaciones de la frecuencia alfa individual: en reposo con ojos
##       cerrados antes y después de la tarea (EC_*_freq) y prestímulo durante
##       la tarea (Prestim_*_freq).
##   iaf_longformat.xlsx : curso temporal grupal (-500 a 0 ms) de la frecuencia
##       alfa instantánea prestímulo en ensayos correctos e incorrectos, para
##       dos sensores (C16 y B7), con su dispersión entre participantes.
## Son datos a nivel de participante, así que acá no hay ajuste por ensayo:
## lo que se contrasta es la predicción central del lector periódico, que el
## umbral de fusión crece con el periodo alfa (1000 / IAF). El script compara
## la pendiente observada con la que produce un lector de fotogramas canónico
## (w = T, m = T / 2, tau = 10, theta_p = 0.45, los mismos valores del
## generador sintético) y calcula, para cada participante, el periodo de
## muestreo que ese lector necesitaría para producir su umbral.
## FF_threshold viene en segundos (valores entre 0.017 y 0.038); se pasa a ms.
## El umbral de d' es un estimador grueso (rejilla de ISI de 5 ms y conteos
## binomiales), así que la curva se promedia sobre varios bancos de ensayos y
## después se le ajusta una regresión isotónica (no decreciente en T), que es
## la forma que el modelo predice; la columna umbral_modelo_bruto conserva el
## promedio sin suavizar para que se vea el ruido de la simulación.
curva_umbral_periodico <- function(cfg, Ts = seq(20, 140, by = 10), n_bancos = 5) {
  cfg2 <- cfg; cfg2$isis <- seq(5, 150, by = 5)
  M <- sapply(seq_len(n_bancos), function(s) {
    banco <- crear_banco(120, 50, cfg2, "limpio", semilla = 2024 + s)
    sapply(Ts, function(Tp) evaluar(c(tau = 10, theta_p = 0.45, m = Tp / 2, w = Tp, T = Tp),
                                    "periodica", banco, cfg2)[["umbral"]])
  })
  bruto <- rowMeans(M)
  data.frame(T = Ts, umbral_modelo_bruto = bruto, umbral_modelo = isoreg(Ts, bruto)$yf)
}

datos_reales_haarlem <- function(cfg, carpeta_datos = file.path("datos_reales", "haarlem_2024")) {
  f1 <- file.path(carpeta_datos, "Alpha_Full_Dataset_final.xlsx")
  f2 <- file.path(carpeta_datos, "iaf_longformat.xlsx")
  if (!file.exists(f1)) { cat("\n(sin datos de Haarlem en", carpeta_datos, "; se omite)\n"); return(NULL) }
  if (!requireNamespace("readxl", quietly = TRUE)) install.packages("readxl", repos = "https://cloud.r-project.org")
  cat("\n== Datos reales: Haarlem (2024), 31 participantes ==\n")
  a <- as.data.frame(readxl::read_excel(f1))
  a <- a[, !is.na(names(a)) & !grepl("^\\.\\.\\.", names(a))]
  d <- data.frame(participante = a$Participant,
                  umbral_ms = a$FF_threshold * 1000,
                  prop_correcta = a$Proportion_correct,
                  cff_hz = a$CFF_MOC,
                  iaf_reposo = a$EC_Average_freq,
                  iaf_prestim = a$Prestim_alpha_freq)
  d$periodo_reposo_ms <- 1000 / d$iaf_reposo
  d$periodo_prestim_ms <- 1000 / d$iaf_prestim

  ## Correlaciones umbral vs periodo alfa (rasgo y estado) y vs CFF
  prueba <- function(x, y, etiqueta) {
    ok <- complete.cases(x, y)
    p <- cor.test(x[ok], y[ok]); s <- cor.test(x[ok], y[ok], method = "spearman", exact = FALSE)
    data.frame(comparacion = etiqueta, n = sum(ok), r_pearson = unname(p$estimate), p_pearson = p$p.value,
               ic95_inf = p$conf.int[1], ic95_sup = p$conf.int[2],
               rho_spearman = unname(s$estimate), p_spearman = s$p.value)
  }
  cors <- rbind(prueba(d$umbral_ms, d$periodo_reposo_ms, "umbral vs periodo alfa en reposo (1000/IAF ojos cerrados)"),
                prueba(d$umbral_ms, d$periodo_prestim_ms, "umbral vs periodo alfa prestímulo"),
                prueba(d$umbral_ms, d$cff_hz, "umbral vs fusión crítica de parpadeo (Hz)"),
                prueba(d$iaf_reposo, d$cff_hz, "IAF reposo vs fusión crítica de parpadeo (Hz)"))
  write.csv(cors, file.path(cfg$carpeta, "haarlem_correlaciones.csv"), row.names = FALSE)
  cat("\nCorrelaciones:\n"); print(cors, row.names = FALSE, digits = 3)

  ## Predicción del lector periódico canónico y periodo implícito por participante
  curva <- curva_umbral_periodico(cfg)
  write.csv(curva, file.path(cfg$carpeta, "haarlem_prediccion_periodica.csv"), row.names = FALSE)
  pend_modelo <- coef(lm(umbral_modelo ~ T, data = curva))[["T"]]
  pend_obs <- coef(lm(umbral_ms ~ periodo_reposo_ms, data = d))[["periodo_reposo_ms"]]
  ## El periodo implícito es el T cuyo umbral predicho iguala al observado
  ## (interpolación sobre la curva; NA si el umbral queda fuera de la curva).
  d$T_implicito_ms <- approx(curva$umbral_modelo, curva$T, xout = d$umbral_ms, ties = mean)$y
  d$frecuencia_implicita_hz <- 1000 / d$T_implicito_ms
  write.csv(d, file.path(cfg$carpeta, "haarlem_participantes.csv"), row.names = FALSE)
  resumen <- data.frame(
    pendiente_modelo_ms_por_ms = pend_modelo, pendiente_observada_ms_por_ms = pend_obs,
    umbral_medio_ms = mean(d$umbral_ms), periodo_alfa_medio_ms = mean(d$periodo_reposo_ms),
    umbral_modelo_en_periodo_alfa_medio = approx(curva$T, curva$umbral_modelo, xout = mean(d$periodo_reposo_ms))$y,
    T_implicito_medio_ms = mean(d$T_implicito_ms, na.rm = TRUE),
    frecuencia_implicita_media_hz = mean(d$frecuencia_implicita_hz, na.rm = TRUE),
    n_sin_periodo_implicito = sum(is.na(d$T_implicito_ms)))
  write.csv(resumen, file.path(cfg$carpeta, "haarlem_resumen.csv"), row.names = FALSE)
  cat("\nModelo periódico canónico contra los datos:\n"); print(t(resumen), digits = 3)

  ## Figura 6: umbral observado contra periodo alfa, con la curva del modelo
  largo <- rbind(data.frame(participante = d$participante, measure = "resting IAF (eyes closed)",
                            periodo = d$periodo_reposo_ms, umbral = d$umbral_ms),
                 data.frame(participante = d$participante, measure = "pre-stimulus IAF",
                            periodo = d$periodo_prestim_ms, umbral = d$umbral_ms))
  g6 <- ggplot(largo, aes(periodo, umbral)) +
    geom_point(data = curva, aes(T, umbral_modelo_bruto), colour = "#E39A9A", shape = 4, inherit.aes = FALSE) +
    geom_line(data = curva, aes(T, umbral_modelo), colour = "#E39A9A", linetype = 2, linewidth = 0.9, inherit.aes = FALSE) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "#6FA8DC", fill = "#A7C7E7", alpha = 0.3) +
    geom_point(size = 2.2, colour = "grey25") +
    facet_wrap(~ measure) +
    labs(x = "alpha period, 1000 / IAF (ms)", y = "two-flash fusion threshold (ms)",
         title = "Haarlem (2024): observed thresholds and the periodic-reader prediction",
         subtitle = "Grey points and blue line: data and linear fit; pink: threshold of a frame reader with period T (crosses simulated, line isotonic)") +
    tema_fig()
  ggsave(file.path(cfg$carpeta, "fig6_haarlem_threshold_vs_alpha.png"), g6, width = 10, height = 5, dpi = 150, bg = "white")

  ## Figura 7: curso temporal grupal de la IAF prestímulo, correctos vs incorrectos
  res_long <- NULL
  if (file.exists(f2)) {
    b <- as.data.frame(readxl::read_excel(f2))
    res_long <- rbind(data.frame(sensor = "C16", condicion = b$Condition, tiempo = b$Time, iaf = b$C16, se = b$C16_SE),
                      data.frame(sensor = "B7", condicion = b$Condition, tiempo = b$Time, iaf = b$B7, se = b$B7_SE))
    dif <- do.call(rbind, lapply(split(res_long, res_long$sensor), function(s) {
      w <- reshape(s[, c("tiempo", "condicion", "iaf")], idvar = "tiempo", timevar = "condicion", direction = "wide")
      data.frame(sensor = s$sensor[1], diferencia_media_hz = mean(w$iaf.Correct - w$iaf.Incorrect),
                 diferencia_maxima_hz = max(w$iaf.Correct - w$iaf.Incorrect))
    }))
    write.csv(dif, file.path(cfg$carpeta, "haarlem_iaf_prestimulo_correctos_vs_incorrectos.csv"), row.names = FALSE)
    cat("\nIAF prestímulo, correctos menos incorrectos (Hz):\n"); print(dif, row.names = FALSE, digits = 3)
    res_long$condition <- ifelse(res_long$condicion == "Correct", "correct trials", "incorrect trials")
    g7 <- ggplot(res_long, aes(tiempo, iaf, colour = condition, fill = condition)) +
      geom_ribbon(aes(ymin = iaf - se, ymax = iaf + se), alpha = 0.25, colour = NA) +
      geom_line(linewidth = 0.9) + facet_wrap(~ sensor) +
      scale_colour_manual(values = PALETA_2, name = NULL) + scale_fill_manual(values = PALETA_2, name = NULL) +
      labs(x = "time relative to stimulus onset (ms)", y = "instantaneous alpha frequency (Hz)",
           title = "Haarlem (2024): pre-stimulus alpha frequency on correct and incorrect trials (group mean, band = 1 SE)") +
      tema_fig()
    ggsave(file.path(cfg$carpeta, "fig7_haarlem_prestimulus_iaf.png"), g7, width = 10, height = 4.5, dpi = 150, bg = "white")
  }
  list(participantes = d, correlaciones = cors, curva_modelo = curva, resumen = resumen, iaf_prestimulo = res_long)
}

## ============================================================================
## 10. Ejecución
## ============================================================================
cat(sprintf("Modo %s. Núcleos: %d. Salida en ./%s\n",
            if (MODO_RAPIDO) "rápido" else "completo", CFG$n_cores, CFG$carpeta))
t_inicio <- Sys.time()
cat(sprintf("%s  corrida iniciada: modo %s, %d núcleos, hipervolumen %s\n",
            format(t_inicio, "%Y-%m-%d %H:%M:%S"), if (MODO_RAPIDO) "rápido" else "completo",
            CFG$n_cores, HV_EXACTO$nombre),
    file = file.path(CFG$carpeta, "progreso.log"))
r0 <- validacion_optimizador(CFG)
CFG <- r0$cfg                       # la parametrización y el corte elegidos gobiernan el resto
cat(sprintf("\nPresupuesto de las corridas principales: popSize %d x %d generaciones = %d evaluaciones por corrida\n",
            CFG$popSize, CFG$maxiter, CFG$popSize * (CFG$maxiter + 1)))
r1 <- pregunta_1(CFG)
r1b <- sensibilidad(CFG, r1$frentes)
r2 <- pregunta_2(CFG, CSV_REAL)
r3 <- pregunta_3(r1$rodillas, CFG)
r4 <- datos_reales_haarlem(CFG)
saveRDS(list(config = CFG, validacion = r0, pregunta_1 = r1, sensibilidad = r1b, pregunta_2 = r2, pregunta_3 = r3, haarlem = r4),
        file.path(CFG$carpeta, "resultados.rds"))
writeLines(c(capture.output(sessionInfo()), "", sprintf("Duración total: %s", format(Sys.time() - t_inicio))),
           file.path(CFG$carpeta, "sesion.txt"))
cat(sprintf("\nListo en %s. Revisar ./%s\n", format(Sys.time() - t_inicio), CFG$carpeta))
