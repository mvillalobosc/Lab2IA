# =============================================================================
# 03_modelos.R
# Para cada signo se entrena un clasificador uno contra el resto. En cada
# iteración se toma una muestra bootstrap balanceada (50 episodios del signo y
# 50 del resto, con reemplazo) y se evalúa con validación cruzada estratificada
# de 5 pliegues. Se guardan las métricas promedio de cada iteración.
#
# Experimentos (elegir en EJECUTAR):
#   principal     5 modelos, reservorio = 80 % de entrenamiento, 12 signos
#   completo      5 modelos, reservorio = todos los episodios, 12 signos
#                 (k-NN con 5 vecinos ponderados por distancia, como el original)
#   ofiuco        5 modelos, reservorio = 80 % de entrenamiento, 13 signos
#   sensibilidad  árbol de decisión, n = 10 ... 1000, 100 iteraciones por signo
#
# Entrada: CFG$dir_datos/base_grd.rds, CFG$dir_datos/seleccion_<12|13>.rds
# Salida:  CSV por modelo en CFG$dir_resultados, con la misma estructura de
#          carpetas del repositorio original (modelo_rf/rf_detalle.csv, etc.)
#          y CFG$dir_resultados/tiempos.csv
#
# Tiempo aproximado en un computador de escritorio (un núcleo): menos de una
# hora por experimento y unas cuatro horas los cuatro. En R el más lento es el
# árbol de decisión (rpart), con cerca de media hora por experimento.
# =============================================================================

source("00_funciones.R")

EJECUTAR <- c("principal", "completo", "ofiuco", "sensibilidad")

base <- readRDS(file.path(CFG$dir_datos, "base_grd.rds"))

# Partición 80/20 estratificada por signo; devuelve las filas de entrenamiento.
filas_entrenamiento <- function(signo) {
  set.seed(CFG$semilla)
  prueba <- logical(length(signo))
  for (s in unique(signo)) {
    idx <- which(signo == s)
    prueba[idx[sample.int(length(idx), round(CFG$prop_prueba * length(idx)))]] <- TRUE
  }
  which(!prueba)
}

# Un experimento completo para un modelo: devuelve una fila por signo e iteración.
experimento <- function(modelo, calendario = "12", reservorio = "entrenamiento",
                        n_muestra = CFG$n_muestra, n_iter = CFG$n_iter,
                        k_vecinos = PARAMS$knn_k, pesos_knn = "uniforme") {
  col_signo <- if (calendario == "12") "SIGNO" else "SIGNO13"
  seleccion <- readRDS(file.path(CFG$dir_datos, sprintf("seleccion_%s.rds", calendario)))
  signo <- base[[col_signo]]
  filas <- if (reservorio == "entrenamiento") filas_entrenamiento(signo) else seq_along(signo)
  signos <- sort(unique(signo))
  n_pos <- n_muestra %/% 2
  n_neg <- n_muestra - n_pos

  rbindlist(lapply(seq_along(signos), function(s) {
    es_signo <- signo[filas] == signos[s]
    pos <- filas[es_signo]
    neg <- filas[!es_signo]
    message(sprintf("  %s | %s | n = %d", modelo, signos[s], n_muestra))
    rbindlist(lapply(seq_len(n_iter), function(it) {
      semilla <- CFG$semilla + 10000L * s + it
      set.seed(semilla)
      # Muestra bootstrap balanceada.
      muestra <- c(pos[sample.int(length(pos), n_pos, replace = TRUE)],
                   neg[sample.int(length(neg), n_neg, replace = TRUE)])
      muestra <- muestra[sample.int(length(muestra))]
      y <- as.integer(signo[muestra] == signos[s])
      X <- matriz_entrada(base, muestra, seleccion)
      # Validación cruzada estratificada dentro de la muestra.
      pliegue <- pliegues_estratificados(y, CFG$k_pliegues)
      m <- sapply(seq_len(CFG$k_pliegues), function(f) {
        en <- pliegue != f
        fit <- ajustar_predecir(modelo, X[en, , drop = FALSE], y[en],
                                X[!en, , drop = FALSE], semilla, k_vecinos, pesos_knn)
        metricas(y[!en], fit$pred, fit$score)
      })
      data.table(modelo = modelo, signo = paste0("signo_zodiacal_", signos[s]),
                 iter = it, n_sample = n_muestra,
                 cv_accuracy = mean(m["accuracy", ]), cv_precision = mean(m["precision", ]),
                 cv_recall = mean(m["recall", ]), cv_f1 = mean(m["f1", ]),
                 cv_roc_auc = mean(m["roc_auc", ], na.rm = TRUE))
    }))
  }))
}

# Ejecuta, mide el tiempo y guarda en la ruta indicada.
correr <- function(nombre, ruta, ...) {
  t0 <- proc.time()[["elapsed"]]
  res <- experimento(...)
  seg <- proc.time()[["elapsed"]] - t0
  dir_crear(dirname(ruta))
  fwrite(res, ruta)
  fwrite(data.table(experimento = nombre, archivo = basename(ruta), segundos = round(seg, 2)),
         file.path(CFG$dir_resultados, "tiempos.csv"), append = TRUE)
  message(sprintf("%s -> %s (%.1f s)", nombre, ruta, seg))
  invisible(res)
}

R <- CFG$dir_resultados

if ("principal" %in% EJECUTAR) for (m in MODELOS)
  correr("principal", file.path(R, paste0("modelo_", m), paste0(m, "_detalle.csv")),
         modelo = m, calendario = "12", reservorio = "entrenamiento")

if ("completo" %in% EJECUTAR) for (m in MODELOS)
  correr("completo", file.path(R, paste0("modelo_", m, "_full_dataset"), paste0(m, "_full_detalle.csv")),
         modelo = m, calendario = "12", reservorio = "completo",
         k_vecinos = PARAMS$knn_k_full, pesos_knn = PARAMS$knn_pesos_full)

if ("ofiuco" %in% EJECUTAR) for (m in MODELOS)
  correr("ofiuco", file.path(R, "Ofiuco", paste0("modelo_", m), paste0(m, "_detalle.csv")),
         modelo = m, calendario = "13", reservorio = "entrenamiento")

if ("sensibilidad" %in% EJECUTAR) for (n in c(10, 50, 100, 150, 200, 500, 1000))
  correr("sensibilidad", file.path(R, "modelo_dt_sensibilidad_n", sprintf("dt_detalle_n%d.csv", n)),
         modelo = "dt", calendario = "12", reservorio = "entrenamiento",
         n_muestra = n, n_iter = 100)
