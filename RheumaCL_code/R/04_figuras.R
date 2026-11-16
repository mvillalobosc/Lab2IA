# =============================================================================
# R/04_figuras.R
# Dibuja la figura SHAP del modelo ganador de cada enfermedad a partir de los
# checkpoints. No reentrena ni recalcula SHAP.
#
# Entrada:  results/checkpoints/<hoja>.rds (paso 2)
#           data/etiquetas_variables.csv (opcional): columnas variable y
#           etiqueta, para mostrar un texto legible en vez del código de cada
#           variable one-hot (ver data/README.md)
# Salida:   results/figures/SHAP_<hoja>_<ganador>.png (300 ppp) y .pdf
#
# Las figuras son para publicación: etiquetas en inglés y colores pastel.
#
#   Rscript R/04_figuras.R
# =============================================================================

source(file.path("R", "00_inicio.R"))
registrar_sesion("04_figuras")

NOMBRE_MODELO <- c(RL = "logistic regression", RF = "random forest", XGB = "XGBoost")

# Etiquetas opcionales de las variables
ruta_etiquetas <- file.path("data", "etiquetas_variables.csv")
etiquetas <- NULL
if (file.exists(ruta_etiquetas)) {
  tabla_etiquetas <- read.csv(ruta_etiquetas, stringsAsFactors = FALSE, encoding = "UTF-8")
  if (!all(c("variable", "etiqueta") %in% names(tabla_etiquetas))) {
    stop(ruta_etiquetas, " debe tener las columnas variable y etiqueta.", call. = FALSE)
  }
  etiquetas <- setNames(tabla_etiquetas$etiqueta, tabla_etiquetas$variable)
  cat("Etiquetas leídas de ", ruta_etiquetas, ": ", length(etiquetas), "\n", sep = "")
}

dispositivo_pdf <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else "pdf"
sin_resultado   <- character(0)
sin_etiqueta    <- character(0)

for (i in seq_along(CFG$enfermedades)) {
  nombre_hoja <- CFG$nombres_enfermedades[i]
  ruta_ckpt   <- file.path(RUTAS$checkpoints, paste0(nombre_hoja, ".rds"))

  if (!file.exists(ruta_ckpt)) {
    sin_resultado <- c(sin_resultado, nombre_hoja)
    next
  }
  resultado <- readRDS(ruta_ckpt)
  tabla     <- as.data.frame(resultado$shap_tabla)

  figura <- grafico_shap(
    tabla,
    titulo    = paste0(CFG$nombres_ingles[i], " (", NOMBRE_MODELO[[resultado$ganador]], ")"),
    etiquetas = etiquetas
  )

  n_barras <- sum(!is.na(tabla$SHAP_si_presente))
  alto     <- 1.9 + 0.27 * n_barras
  base     <- file.path(RUTAS$figuras, paste0("SHAP_", nombre_hoja, "_", resultado$ganador))
  ggsave(paste0(base, ".png"), plot = figura, width = 7.5, height = alto, dpi = 300, bg = "white")
  ggsave(paste0(base, ".pdf"), plot = figura, width = 7.5, height = alto, device = dispositivo_pdf)

  if (!is.null(etiquetas)) {
    sin_etiqueta <- union(sin_etiqueta, setdiff(tabla$Variable, names(etiquetas)))
  }
  cat("  [", CFG$enfermedades[i], "] ", basename(base), ".png y .pdf (", n_barras,
      " variables)\n", sep = "")
}

if (length(sin_etiqueta) > 0) {
  cat("\nVariables sin etiqueta en ", ruta_etiquetas, " (salen con su código): ",
      paste(sin_etiqueta, collapse = ", "), "\n", sep = "")
}

# Ninguna enfermedad queda fuera en silencio
if (length(sin_resultado) > 0) {
  cat("\n!! Sin checkpoint, no tienen figura:", paste(sin_resultado, collapse = ", "), "\n")
} else {
  cat("\nEnfermedades con figura en ", RUTAS$figuras, ": ", length(CFG$enfermedades), " de ",
      length(CFG$enfermedades), "\n", sep = "")
}
