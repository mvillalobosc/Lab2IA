# =============================================================================
# config.R
# Rutas, variables, semillas y parámetros del análisis de caracterización de
# 12 enfermedades reumáticas con regresión logística (RL), Random Forest (RF)
# y XGBoost (XGB).
#
# Ningún otro archivo tiene rutas ni valores fijos: todos leen la lista CFG.
# Los valores de este archivo son los del script original
# (Analisis_Unificado_FINAL.R). Cambiarlos cambia los resultados.
#
# R/00_inicio.R carga este archivo; no hace falta cargarlo a mano.
# =============================================================================

CFG <- list(

  # ---------------------------------------------------------------------------
  # Rutas, relativas a la carpeta del proyecto
  # ---------------------------------------------------------------------------
  archivo_encuesta = file.path("data", "raw", "data_encuesta_filtrado.xlsx"),
  dir_procesados   = file.path("data", "processed"),
  dir_resultados   = "results",

  # ---------------------------------------------------------------------------
  # Variables
  # ---------------------------------------------------------------------------
  # Enfermedades analizadas. El nombre de hoja identifica a cada enfermedad en
  # el Excel de resultados y en su checkpoint (results/checkpoints/<hoja>.rds).
  enfermedades = c("V8", "V9", "V10", "V11", "V12", "V13",
                   "V14", "V15", "V16", "V17", "V18", "V20"),
  nombres_enfermedades = c(
    "V8_ArtritisJuvenil",     "V9_ArtritisPsoriatica",
    "V10_ArtritisReumatoide", "V11_Artrosis",
    "V12_Esclerodermia",      "V13_Espondilitis",
    "V14_Fibromialgia",       "V15_Lupus",
    "V16_Miositis",           "V17_Raynaud",
    "V18_Sjogren",            "V20_Uveitis"
  ),
  # Nombres en inglés, solo para los títulos de las figuras.
  nombres_ingles = c(
    "Juvenile idiopathic arthritis", "Psoriatic arthritis",
    "Rheumatoid arthritis",          "Osteoarthritis",
    "Scleroderma",                   "Spondylitis",
    "Fibromyalgia",                  "Systemic lupus erythematosus",
    "Myositis",                      "Raynaud syndrome",
    "Sjögren syndrome",              "Uveitis"
  ),

  # Variables que salen de la base antes de modelar:
  #   V5  comuna: redundante con la región (V de Cramér = 0,999) y de alta
  #       cardinalidad. Los indicadores censales comunales (V121 a V123) se
  #       conservan.
  #   V19 VKH, V21 vasculitis y V22 otra enfermedad reumática: fuera del
  #       análisis, según la metodología.
  variables_excluidas = c("V5", "V19", "V21", "V22"),

  # ---------------------------------------------------------------------------
  # Selección de características (chi-cuadrado sobre la muestra completa)
  # ---------------------------------------------------------------------------
  alfa_chi2     = 0.05,   # se conservan las variables con p < alfa_chi2
  max_variables = 20,     # y de ellas, las de menor valor p hasta este máximo

  # ---------------------------------------------------------------------------
  # Búsqueda de hiperparámetros (grid search con validación cruzada)
  # ---------------------------------------------------------------------------
  semilla_grid  = 321,
  k_fold_grid   = 5,
  rf_mtry_max   = 20,                   # mtry: rf_mtry_n valores entre 1 y
  rf_mtry_n     = 5,                    #   min(rf_mtry_max, n de predictoras)
  rf_ntree      = c(100, 250, 500),
  xgb_eta       = c(0.01, 0.05, 0.1, 0.3),
  xgb_max_depth = c(2, 4, 6, 8),
  xgb_nrounds   = c(100, 250, 500),

  # ---------------------------------------------------------------------------
  # Validación cruzada repetida
  # ---------------------------------------------------------------------------
  # La repetición i usa set.seed(i), así que los tres modelos ven las mismas
  # particiones. El balanceo (sobremuestreo de la clase SI) se hace solo dentro
  # de cada fold de entrenamiento.
  n_iter       = 1000,
  k_fold       = 5,
  umbral_clase = 0.5,     # probabilidad sobre la cual se predice SI
  alfa_rl      = 0.05,    # RL: un coeficiente cuenta como seleccionado si p < alfa_rl

  # ---------------------------------------------------------------------------
  # Modelos finales y SHAP
  # ---------------------------------------------------------------------------
  semilla_final = 789,    # sobremuestreo de la muestra completa y ajuste final
  semilla_shap  = 123,
  shap_nsim     = 50,     # repeticiones Monte Carlo de fastshap por variable
  shap_top_n    = 20,     # variables que entran a la tabla y a la figura SHAP

  # ---------------------------------------------------------------------------
  # Paralelismo (solo lo usa el grid search)
  # ---------------------------------------------------------------------------
  n_nucleos = NULL,       # NULL = todos los núcleos menos uno

  # ---------------------------------------------------------------------------
  # Modo de prueba
  # ---------------------------------------------------------------------------
  # Rscript run_all.R --prueba corre todo el flujo en minutos para comprobar
  # que la instalación funciona. Reemplaza los valores de arriba por estos y
  # escribe en otra carpeta, de modo que nunca toca los resultados reales.
  # Sus cifras no sirven para el artículo.
  prueba = list(
    n_iter         = 3,
    shap_nsim      = 5,
    rf_ntree       = c(100),
    xgb_eta        = c(0.1, 0.3),
    xgb_max_depth  = c(2, 4),
    xgb_nrounds    = c(100),
    dir_procesados = file.path("data", "processed_prueba"),
    dir_resultados = "results_prueba"
  )
)
