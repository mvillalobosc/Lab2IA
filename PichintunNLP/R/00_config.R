# =============================================================================
# 00_config.R  Configuracion global del pipeline
# =============================================================================
# No contiene rutas absolutas. Todas las rutas se resuelven desde la raiz del
# repositorio, detectada a partir de la presencia de run_all.R.
# =============================================================================

find_project_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(d, "run_all.R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) stop("No se encontro la raiz del proyecto (run_all.R).")
    d <- parent
  }
}

PROJ <- find_project_root()

# El corpus contiene acentos y enye. Bajo locale C, los dispositivos graficos
# de R no logran traducir esos caracteres y emiten cientos de avisos
# "unable to translate ... to native encoding", ademas de degradar las
# etiquetas de los graficos. Se fuerza un locale UTF-8 si esta disponible.
asegurar_locale_utf8 <- function() {
  if (grepl("UTF-8", Sys.getlocale("LC_CTYPE"), ignore.case = TRUE)) return(invisible(TRUE))
  for (loc in c("C.UTF-8", "en_US.UTF-8", "es_CL.UTF-8", "es_ES.UTF-8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) return(invisible(TRUE))
  }
  warning("No se pudo fijar un locale UTF-8. Las etiquetas con tildes pueden ",
          "renderizarse mal. Instale locales UTF-8 en el sistema.", call. = FALSE)
  invisible(FALSE)
}
asegurar_locale_utf8()

CFG <- list(
  # --- rutas ---------------------------------------------------------------
  dir_raw        = file.path(PROJ, "data", "raw"),
  dir_processed  = file.path(PROJ, "data", "processed"),
  dir_figures    = file.path(PROJ, "outputs", "figures"),
  dir_tables     = file.path(PROJ, "outputs", "tables"),

  f_episodes     = file.path(PROJ, "data", "raw", "metadata", "episodes.csv"),
  f_dialogos_es  = file.path(PROJ, "data", "raw", "dialogues_es.csv"),
  f_dialogos_en  = file.path(PROJ, "data", "raw", "dialogues_en.csv"),
  f_youtube      = file.path(PROJ, "data", "raw", "metadata", "youtube_stats.csv"),
  f_stopwords    = file.path(PROJ, "data", "raw", "lexicons", "stopwords_extra.csv"),
  f_topics       = file.path(PROJ, "data", "raw", "lexicons", "word_topics.csv"),
  f_dic          = file.path(PROJ, "data", "raw", "dictionaries", "es_ES.dic"),

  # --- parametros de analisis ---------------------------------------------
  # Cancion introductoria comun a todos los capitulos, se elimina del texto.
  intro_song = paste0(
    " Pichintun, pichintun, que bonito pichintun. En el bosque y en el mar, ",
    "en la pampa y el salar. En los cerros y en las islas, van los ninos a jugar. ",
    "Pichintun, pichintun, que bonito pichintun."
  ),

  # Palabras que el diccionario hunspell reconoce como espanol pero que en el
  # contexto de la serie funcionan como marca cultural. Se reclasifican una sola
  # vez, en 02_clean.R, para que todos los modulos posteriores usen la misma
  # particion lexica. Ver seccion "Cambios respecto al codigo original" del README.
  forzar_culturales = c("chile"),

  # Etiqueta del lexico tematico que agrupa palabras sin tema asignado.
  tema_sin_definir = "sin definir",

  # Abreviaciones de temas para los graficos de keyness (nombres largos no caben).
  tema_abrev = c(
    "expresion artistica"    = "creatividad",
    "expresión artística"    = "creatividad",
    "cultura/tradiciones"    = "cultura",
    "salud/bienestar"        = "bienestar",
    "infraestructura urbana" = "urbanizacion"
  ),

  # Fecha de corte de la extraccion de estadisticas de YouTube. Se usa para
  # normalizar likes / suscriptores / visualizaciones por tiempo de exposicion.
  fecha_corte = as.Date("2023-04-13"),

  # Ventana de MATTR (Moving-Average Type-Token Ratio) por capitulo.
  mattr_window = 200L,

  # Numero de tramos en que se divide cada temporada para las curvas de
  # tendencia. NULL = usar el minimo de oraciones entre capitulos (criterio
  # original). Un entero fija el valor.
  n_tramos_sentimiento = NULL,
  n_tramos_lexico      = 10L,

  # Umbral de importancia (%) de Random Forest para pasar a la regresion lineal.
  umbral_importancia_rf = 20,

  # Semillas por modelo. Fijas para reproducibilidad.
  seed_likes           = 2L,
  seed_subscribers     = 1L,
  seed_views           = 1L,

  # --- estilo --------------------------------------------------------------
  colores_temporada = c("#9933FF", "#FF8000", "#0080FF", "#80FF00"),
  colores_dendro    = c("violetred3", "#CD3700", "#00688B", "#008B00"),
  paleta_nube       = c("#1B9E77", "#00CDCD", "#9A32CD", "#E7298A",
                        "#66A61E", "#CD2626", "#FF7F00"),

  fig_width  = 11,
  fig_height = 8,
  fig_dpi    = 150,

  verbose = TRUE
)

for (d in c(CFG$dir_processed, CFG$dir_figures, CFG$dir_tables)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

log_msg <- function(...) {
  if (isTRUE(CFG$verbose)) {
    cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")
  }
  invisible(NULL)
}

log_step <- function(...) {
  if (isTRUE(CFG$verbose)) {
    cat("\n", strrep("-", 70), "\n", ..., "\n", strrep("-", 70), "\n", sep = "")
  }
  invisible(NULL)
}
