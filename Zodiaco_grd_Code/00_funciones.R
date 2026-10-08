# =============================================================================
# 00_funciones.R
# Configuración y funciones comunes del análisis "signo zodiacal vs. registros
# clínicos" sobre los archivos GRD públicos de Fonasa (2019-2024).
#
# Los demás scripts cargan este archivo con source("00_funciones.R").
# Orden de ejecución:
#   01_preparar_datos.R  lee los seis archivos GRD y deja una base compacta
#   02_chi_cuadrado.R    filtro chi-cuadrado (p < 0,01) sobre la base completa
#   03_modelos.R         bootstrap balanceado + validación cruzada, 5 modelos
#   04_resultados.R      tablas, prueba de Wilcoxon y figuras del artículo
#
# Paquetes: data.table, glmnet, rpart, ranger, e1071, ggplot2.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(glmnet)
  library(rpart)
  library(ranger)
  library(e1071)
  library(ggplot2)
})

# -----------------------------------------------------------------------------
# Configuración general
# -----------------------------------------------------------------------------
CFG <- list(
  dir_grd        = "datos_grd",      # carpeta con GRD_PUBLICO_2019.txt ... 2024.txt
  dir_datos      = "datos",          # base preparada y matriz de selección
  dir_resultados = "resultados",     # salidas de 02, 03 y 04
  anios          = 2019:2024,
  semilla        = 42,
  prop_prueba    = 0.20,             # partición 80/20 estratificada por signo
  alfa_chi2      = 0.01,             # umbral del filtro chi-cuadrado (sin corrección)
  n_muestra      = 100,              # tamaño de cada muestra bootstrap (50 + 50)
  n_iter         = 500,              # iteraciones bootstrap por signo
  k_pliegues     = 5,                # validación cruzada estratificada
  n_diag         = 35,
  n_proc         = 30
)

# Hiperparámetros: son los del código que generó los resultados del artículo
# (notebooks de scikit-learn), traducidos a sus equivalentes en R.
# Los notebooks usaban class_weight = "balanced"; con muestras 50/50 y pliegues
# estratificados (40/40 en cada entrenamiento) esos pesos valen 1 y no cambian nada.
PARAMS <- list(
  lr_C       = 1,      # regresión logística L2, C = 1
  rf_arboles = 100,    # random forest: 100 árboles, profundidad libre
  knn_k      = 50,     # k-NN: 50 vecinos con voto uniforme (principal y Ofiuco)
  knn_k_full = 5,      # k-NN con el dataset completo: 5 vecinos...
  knn_pesos_full = "distancia",  # ...con voto ponderado por 1 / distancia
  svm_C      = 1       # SVM con kernel RBF, gamma = "scale"
)

MODELOS <- c("rf", "dt", "knn", "lr", "svm")

campos_diag <- function() paste0("DIAGNOSTICO", seq_len(CFG$n_diag))
campos_proc <- function() paste0("PROCEDIMIENTO", seq_len(CFG$n_proc))
campos_categoricos <- function() c("ESPECIALIDAD_MEDICA", campos_diag(), campos_proc())

dir_crear <- function(...) {
  ruta <- file.path(...)
  dir.create(ruta, recursive = TRUE, showWarnings = FALSE)
  invisible(ruta)
}

# Los archivos traen tildes y eñes: R debe correr con una configuración regional
# UTF-8 (es la opción por defecto en Windows desde R 4.2, en macOS y en Linux).
if (!isTRUE(l10n_info()[["UTF-8"]])) warning("R no está en una configuración regional UTF-8; las tildes pueden leerse mal.")

# -----------------------------------------------------------------------------
# Fechas y signos
# -----------------------------------------------------------------------------

# Convierte texto a fecha probando los formatos que aparecen en los archivos.
leer_fecha <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  salida <- as.IDate(rep(NA_integer_))[rep(1L, length(x))]
  for (f in c("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%Y/%m/%d", "%Y-%m-%d %H:%M:%S")) {
    faltan <- is.na(salida) & !is.na(x)
    if (!any(faltan)) break
    salida[faltan] <- as.IDate(x[faltan], format = f)
  }
  salida
}

# Signo occidental de 12 signos (rangos de Encyclopaedia Britannica, los mismos
# del notebook original). Se trabaja con mes*100 + día.
signo_12 <- function(fecha) {
  md <- month(fecha) * 100L + mday(fecha)
  inicio <- c(101, 120, 219, 321, 420, 521, 622, 723, 823, 923, 1024, 1122, 1222)
  nombre <- c("capricornio", "acuario", "piscis", "aries", "tauro", "geminis",
              "cancer", "leo", "virgo", "libra", "escorpio", "sagitario", "capricornio")
  nombre[findInterval(md, inicio)]
}

# Calendario alternativo de 13 signos con Ofiuco (fechas del notebook original).
signo_13 <- function(fecha) {
  md <- month(fecha) * 100L + mday(fecha)
  inicio <- c(101, 120, 217, 312, 419, 514, 622, 721, 811, 917, 1101, 1124, 1130, 1218)
  nombre <- c("sagitario", "capricornio", "acuario", "piscis", "aries", "tauro",
              "geminis", "cancer", "leo", "virgo", "libra", "escorpio", "ofiuco", "sagitario")
  nombre[findInterval(md, inicio)]
}

# -----------------------------------------------------------------------------
# Agrupación de códigos
# -----------------------------------------------------------------------------

# Diagnóstico CIE-10: primera letra A-Z del código; vacío -> "NA"; sin letra -> "OTROS".
agrupar_diagnostico <- function(x) {
  s <- toupper(trimws(as.character(x)))
  s[is.na(s) | s %in% c("", "NAN", "NONE")] <- "NA"
  letra <- regmatches(s, regexpr("[A-Z]", s))
  salida <- rep("OTROS", length(s))
  tiene <- grepl("[A-Z]", s)
  salida[tiene] <- letra
  salida[s == "NA"] <- "NA"
  salida
}

# Procedimiento CIE-9-CM: número inicial agrupado en 00-99; vacío -> "NA";
# sin número inicial o mayor que 99 -> "OTROS".
agrupar_procedimiento <- function(x) {
  s <- trimws(as.character(x))
  vacio <- is.na(s) | s %in% c("", "NAN", "NONE", "nan")
  num <- suppressWarnings(as.integer(sub("^([0-9]+).*$", "\\1", s)))
  num[!grepl("^[0-9]", s)] <- NA_integer_
  salida <- ifelse(!is.na(num) & num >= 0 & num <= 99, sprintf("%02d", num), "OTROS")
  salida[vacio] <- "NA"
  salida
}

# -----------------------------------------------------------------------------
# Chi-cuadrado igual al de scikit-learn (sklearn.feature_selection.chi2):
# compara la frecuencia observada de cada variable binaria en cada signo con la
# esperada bajo independencia; gl = número de signos - 1.
# conteos: matriz niveles x signos (cuántas filas de cada signo tienen el nivel)
# n_signo: número de filas de cada signo (mismo orden de columnas)
# -----------------------------------------------------------------------------
chi2_sklearn <- function(conteos, n_signo) {
  prop <- n_signo / sum(n_signo)
  total <- rowSums(conteos)
  esperado <- outer(total, prop)
  chi2 <- rowSums((conteos - esperado)^2 / esperado)
  p <- pchisq(chi2, df = ncol(conteos) - 1, lower.tail = FALSE)
  list(chi2 = chi2, p = p)
}

# -----------------------------------------------------------------------------
# Matriz de entrada para un grupo de filas: una columna binaria por cada
# variable seleccionada (campo = nivel) y la estancia en días.
# seleccion: data.table con columnas campo, codigo (código entero del nivel).
# -----------------------------------------------------------------------------
matriz_entrada <- function(base, filas, seleccion) {
  X <- matrix(0, nrow = length(filas), ncol = nrow(seleccion) + 1L)
  for (cmp in unique(seleccion$campo)) {
    cols <- which(seleccion$campo == cmp)
    v <- as.integer(base[[cmp]][filas])
    for (j in cols) X[, j] <- as.numeric(!is.na(v) & v == seleccion$codigo[j])
  }
  X[, ncol(X)] <- base$ESTANCIA_DIAS[filas]
  colnames(X) <- paste0("x", seq_len(ncol(X)))
  X
}

# -----------------------------------------------------------------------------
# Partición, pliegues y métricas
# -----------------------------------------------------------------------------

# Pliegues estratificados con barajado (equivalente a StratifiedKFold(shuffle=TRUE)).
pliegues_estratificados <- function(y, k) {
  pliegue <- integer(length(y))
  for (clase in unique(y)) {
    idx <- which(y == clase)
    idx <- idx[sample.int(length(idx))]
    pliegue[idx] <- rep_len(seq_len(k), length(idx))
  }
  pliegue
}

# ROC-AUC por rangos (Mann-Whitney), con empates promediados.
auc_roc <- function(y, score) {
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(score)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# Exactitud, precisión, sensibilidad, F1 (0 cuando no hay positivos predichos)
# y ROC-AUC.
metricas <- function(y, pred, score) {
  tp <- sum(pred == 1 & y == 1); fp <- sum(pred == 1 & y == 0)
  fn <- sum(pred == 0 & y == 1)
  prec <- if (tp + fp > 0) tp / (tp + fp) else 0
  rec  <- if (tp + fn > 0) tp / (tp + fn) else 0
  f1   <- if (prec + rec > 0) 2 * prec * rec / (prec + rec) else 0
  c(accuracy = mean(pred == y), precision = prec, recall = rec, f1 = f1,
    roc_auc = auc_roc(y, score))
}

# Estandarización con media y desviación poblacional del entrenamiento
# (como StandardScaler); columnas constantes quedan con escala 1.
estandarizar <- function(Xtr, Xva) {
  m <- colMeans(Xtr)
  s <- sqrt(colMeans(sweep(Xtr, 2, m)^2))
  s[s == 0] <- 1
  list(tr = sweep(sweep(Xtr, 2, m), 2, s, "/"),
       va = sweep(sweep(Xva, 2, m), 2, s, "/"))
}

# -----------------------------------------------------------------------------
# Modelos: cada uno entrena con (Xtr, ytr) y devuelve el puntaje de la clase 1
# y la predicción binaria para Xva.
# -----------------------------------------------------------------------------
ajustar_predecir <- function(modelo, Xtr, ytr, Xva, semilla, k_vecinos = PARAMS$knn_k,
                             pesos_knn = "uniforme") {
  switch(modelo,

    # Regresión logística con penalización L2 sobre variables estandarizadas.
    # En glmnet, C de scikit-learn equivale a lambda = 1 / (C * n).
    lr = {
      z <- estandarizar(Xtr, Xva)
      lam <- 1 / (PARAMS$lr_C * nrow(Xtr))
      fit <- glmnet(z$tr, ytr, family = "binomial", alpha = 0,
                    lambda = lam * c(100, 10, 1), standardize = FALSE)
      score <- as.numeric(predict(fit, z$va, s = lam, type = "response"))
      list(score = score, pred = as.integer(score > 0.5))
    },

    # Árbol de decisión con índice de Gini, crecido sin poda.
    dt = {
      d <- data.frame(y = factor(ytr, levels = c(0, 1)), Xtr)
      fit <- rpart(y ~ ., data = d, method = "class", parms = list(split = "gini"),
                   control = rpart.control(minsplit = 2, minbucket = 1, cp = 0,
                                           maxdepth = 30, xval = 0,
                                           maxcompete = 0, maxsurrogate = 0))
      score <- predict(fit, data.frame(Xva), type = "prob")[, "1"]
      list(score = score, pred = as.integer(score > 0.5))
    },

    # Random forest de probabilidad: 100 árboles, raíz de p variables por corte.
    rf = {
      fit <- ranger(x = Xtr, y = factor(ytr, levels = c(0, 1)),
                    num.trees = PARAMS$rf_arboles, probability = TRUE,
                    mtry = floor(sqrt(ncol(Xtr))), min.node.size = 1,
                    replace = TRUE, sample.fraction = 1,
                    seed = semilla, num.threads = 1)
      score <- predict(fit, Xva)$predictions[, "1"]
      list(score = score, pred = as.integer(score > 0.5))
    },

    # k vecinos más cercanos con distancia euclidiana sobre variables
    # estandarizadas. El puntaje es la proporción de vecinos positivos (voto
    # uniforme) o esa proporción ponderada por 1 / distancia (voto por
    # distancia; si hay vecinos a distancia 0, solo votan ellos, como en
    # scikit-learn). Con un empate se predice la clase 0, igual que
    # scikit-learn. Con variables binarias hay muchas distancias repetidas: si
    # el empate cae justo en el vecino k, R y scikit-learn pueden elegir
    # vecinos distintos.
    knn = {
      z <- estandarizar(Xtr, Xva)
      d2 <- outer(rowSums(z$va^2), rowSums(z$tr^2), "+") - 2 * z$va %*% t(z$tr)
      d2[d2 < 1e-10] <- 0
      k <- min(k_vecinos, nrow(Xtr))
      score <- vapply(seq_len(nrow(d2)), function(i) {
        vecinos <- order(d2[i, ])[seq_len(k)]
        if (pesos_knn == "uniforme") return(mean(ytr[vecinos]))
        d <- sqrt(d2[i, vecinos])
        w <- if (any(d == 0)) as.numeric(d == 0) else 1 / d
        sum(w * ytr[vecinos]) / sum(w)
      }, numeric(1))
      list(score = score, pred = as.integer(score > 0.5))
    },

    # SVM con kernel RBF sobre variables estandarizadas; gamma = 1 / (p * var(X)),
    # que es la opción gamma = "scale" de scikit-learn. El puntaje es el valor
    # de decisión orientado hacia la clase 1.
    svm = {
      z <- estandarizar(Xtr, Xva)
      v <- mean((z$tr - mean(z$tr))^2)
      gam <- if (v > 0) 1 / (ncol(z$tr) * v) else 1 / ncol(z$tr)
      fit <- svm(x = z$tr, y = factor(ytr, levels = c(0, 1)), type = "C-classification",
                 kernel = "radial", cost = PARAMS$svm_C, gamma = gam, scale = FALSE)
      p <- predict(fit, z$va, decision.values = TRUE)
      dv <- attr(p, "decision.values")
      score <- as.numeric(dv[, 1])
      if (startsWith(colnames(dv)[1], "0/")) score <- -score
      list(score = score, pred = as.integer(as.character(p)))
    },

    stop("Modelo desconocido: ", modelo)
  )
}

# Nombres en inglés para tablas y figuras del artículo.
NOMBRE_SIGNO <- c(acuario = "Aquarius", aries = "Aries", cancer = "Cancer",
                  capricornio = "Capricorn", escorpio = "Scorpio", geminis = "Gemini",
                  leo = "Leo", libra = "Libra", ofiuco = "Ophiuchus", piscis = "Pisces",
                  sagitario = "Sagittarius", tauro = "Taurus", virgo = "Virgo")
NOMBRE_MODELO <- c(rf = "Random forest", dt = "Decision tree", knn = "k-nearest neighbours",
                   lr = "Logistic regression", svm = "Support vector machine")
