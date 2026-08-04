# =============================================================================
# 00_config.R
# -----------------------------------------------------------------------------
# EN: Global configuration for the Papelucho text-mining pipeline. Defines
#     paths, analysis parameters, dependency checks and bilingual labels.
#     Every other script starts by sourcing this file.
# ES: Configuracion global del pipeline de text mining de Papelucho. Define
#     rutas, parametros de analisis, verificacion de dependencias y etiquetas
#     bilingues. Todos los demas scripts parten cargando este archivo.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Locale / encoding
#    EN: The corpus is Spanish UTF-8. Forcing a UTF-8 collation avoids silent
#        mangling of accented characters on servers whose default locale is C.
#    ES: El corpus es espanol UTF-8. Forzar una intercalacion UTF-8 evita que
#        los acentos se corrompan en servidores cuyo locale por defecto es C.
# -----------------------------------------------------------------------------

.set_utf8_locale <- function() {
  candidates <- c("es_CL.UTF-8", "es_ES.UTF-8", "en_US.UTF-8", "C.UTF-8", "C.utf8")
  for (loc in candidates) {
    ok <- suppressWarnings(try(Sys.setlocale("LC_CTYPE", loc), silent = TRUE))
    if (!inherits(ok, "try-error") && nzchar(ok)) {
      # LC_COLLATE = C keeps file ordering byte-stable and therefore reproducible
      # across machines; LC_CTYPE = UTF-8 is what actually matters for accents.
      suppressWarnings(Sys.setlocale("LC_COLLATE", "C"))
      return(invisible(loc))
    }
  }
  warning("No UTF-8 locale available. Accented characters may be mishandled.")
  invisible(NA_character_)
}

.set_utf8_locale()
options(stringsAsFactors = FALSE, encoding = "UTF-8")

# -----------------------------------------------------------------------------
# 2. Project paths
#    EN: All paths are relative to the repository root. Run scripts with the
#        repository root as the working directory (or open the .Rproj).
#    ES: Todas las rutas son relativas a la raiz del repositorio. Ejecuta los
#        scripts con la raiz del repositorio como directorio de trabajo.
# -----------------------------------------------------------------------------

PATHS <- list(
  raw_papelucho  = file.path("data", "raw", "papelucho"),
  raw_comparison = file.path("data", "raw", "comparison"),
  metadata       = file.path("data", "metadata"),
  derived        = file.path("data", "derived"),
  models         = file.path("models"),
  tables         = file.path("outputs", "tables"),
  figures        = file.path("outputs", "figures"),
  logs           = file.path("outputs", "logs")
)

for (p in PATHS) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

# Universal Dependencies model for Spanish POS tagging.
# EN: Not versioned in git (28 MB). Run scripts/download_udpipe_model.R once.
# ES: No versionado en git (28 MB). Ejecuta scripts/download_udpipe_model.R una vez.
UDPIPE_MODEL <- file.path(PATHS$models, "spanish-gsd-ud-2.5-191206.udpipe")

# -----------------------------------------------------------------------------
# 3. Analysis parameters
#    EN: Every number that changes a result lives here, never buried in code.
#    ES: Todo numero que cambie un resultado vive aca, nunca escondido en el codigo.
# -----------------------------------------------------------------------------

PARAMS <- list(

  # --- Reproducibility / Reproducibilidad ---
  seed = 20250803L,

  # --- Length control / Control de largo ---------------------------------
  # EN: The Papelucho books (14k-25k words) are roughly five times shorter than
  #     the median comparison novel (99k words). Type-token statistics fall
  #     mechanically as text length grows, so any raw comparison measures
  #     length, not style. Every length-sensitive metric is therefore computed
  #     on random samples of a FIXED number of tokens, repeated n_replicates
  #     times and averaged.
  # ES: Los libros de Papelucho (14k-25k palabras) son unas cinco veces mas
  #     cortos que la novela mediana de comparacion (99k palabras). Los
  #     estadisticos tipo-token bajan mecanicamente al crecer el largo del
  #     texto, asi que cualquier comparacion cruda mide largo, no estilo. Por
  #     eso toda metrica sensible al largo se calcula sobre muestras aleatorias
  #     de un numero FIJO de tokens, repetidas n_replicates veces y promediadas.
  sample_size    = 5000L,   # tokens per replicate / tokens por replica
  n_replicates   = 30L,     # replicates per book / replicas por libro
  mattr_window   = 50L,     # MATTR moving window / ventana movil de MATTR
  mtld_threshold = 0.72,    # canonical MTLD TTR cut-off / umbral canonico de MTLD

  # --- Sentiment / Sentimiento -------------------------------------------
  n_chunks       = 20L,     # narrative-arc segments per book / segmentos de arco narrativo
  sentiment_n_before = 4L,  # valence-shifter window before polarised word
  sentiment_n_after  = 2L,  # valence-shifter window after polarised word

  # --- Stylometry / Estilometria -----------------------------------------
  # EN: Burrows's Delta on the n most frequent words is the standard baseline
  #     in computational stylistics. TF-IDF on content words is kept as a
  #     sensitivity analysis because it is dominated by proper nouns.
  # ES: Burrows's Delta sobre las n palabras mas frecuentes es la linea base
  #     estandar en estilistica computacional. TF-IDF sobre palabras de
  #     contenido se mantiene como analisis de sensibilidad porque queda
  #     dominado por nombres propios.
  mfw_n          = 300L,    # most frequent words for Delta / palabras mas frecuentes para Delta
  tfidf_n        = 500L,    # features for the TF-IDF sensitivity analysis
  tfidf_min_freq = 5L,      # minimum corpus frequency for a TF-IDF feature
  n_bootstrap    = 1000L,   # bootstrap replicates for cluster support

  # --- UMAP ---------------------------------------------------------------
  umap_neighbors = 15L,
  umap_min_dist  = 0.15,
  umap_seeds     = c(1L, 42L, 123L, 2024L, 20250803L),  # stability check / chequeo de estabilidad

  # --- Statistics / Estadistica ------------------------------------------
  p_adjust_method = "holm",
  alpha           = 0.05
)

set.seed(PARAMS$seed)

# -----------------------------------------------------------------------------
# 4. Group labels
# -----------------------------------------------------------------------------

GROUPS <- list(
  focus      = "Papelucho",
  comparison = "Comparison"
)

# EN: Colour-blind-safe palette. Teal for Papelucho, dark grey for comparison.
# ES: Paleta segura para daltonismo. Verde azulado para Papelucho, gris oscuro
#     para el corpus de comparacion.
GROUP_COLOURS <- c(
  "Papelucho"  = "#00A499",
  "Comparison" = "#2B2B2B"
)

# -----------------------------------------------------------------------------
# 5. Bilingual labels
#    EN: Tables and figures are exported twice, in English and Spanish. This
#        lookup is the single source of truth for every metric name and gloss.
#    ES: Tablas y figuras se exportan dos veces, en ingles y espanol. Esta
#        tabla es la unica fuente de verdad para cada nombre y glosa de metrica.
# -----------------------------------------------------------------------------

LABELS <- data.frame(
  key = c(
    "tokens", "types", "sentences", "characters", "syllables",
    "TTR", "RTTR", "CTTR", "Herdan_C", "Maas", "MATTR", "MTLD",
    "Yule_K", "Simpson_D", "Shannon_H", "Hapax_ratio",
    "words_per_sentence", "sd_words_per_sentence", "median_words_per_sentence",
    "pct_short_sentences", "pct_long_sentences",
    "letters_per_word", "syllables_per_word",
    "Fernandez_Huerta", "Szigriszt_Pazos", "Inflesz", "Gutierrez_Polini",
    "Mu_index", "Flesch_Kincaid_EN", "ARI_EN",
    "ADJ", "ADP", "ADV", "AUX", "CCONJ", "DET", "INTJ", "NOUN", "NUM",
    "PART", "PRON", "PROPN", "SCONJ", "SYM", "VERB", "X",
    "anger", "anticipation", "disgust", "fear",
    "joy", "sadness", "surprise", "trust", "positive", "negative",
    "mean_sentiment", "sd_sentiment", "sentiment_range",
    "median_sentiment", "pct_negative_chunks", "pct_negative_sentences",
    "lexical_density", "emotion_density", "valence_ratio", "valence_balance"
  ),
  label_en = c(
    "Tokens", "Types", "Sentences", "Characters", "Syllables",
    "Type-token ratio", "Root TTR (Guiraud)", "Corrected TTR",
    "Herdan's C", "Maas's a2", "MATTR", "MTLD",
    "Yule's K", "Simpson's D", "Shannon's H", "Hapax legomena ratio",
    "Words per sentence", "SD of words per sentence",
    "Median words per sentence", "Short sentences (%)", "Long sentences (%)",
    "Letters per word", "Syllables per word",
    "Fernandez Huerta readability", "Szigriszt-Pazos perspicuity",
    "INFLESZ scale", "Gutierrez de Polini comprehensibility",
    "Mu index", "Flesch-Kincaid (English formula)",
    "Automated Readability Index (English formula)",
    "Adjective", "Adposition", "Adverb", "Auxiliary",
    "Coordinating conjunction", "Determiner", "Interjection", "Noun",
    "Numeral", "Particle", "Pronoun", "Proper noun",
    "Subordinating conjunction", "Symbol", "Verb", "Other",
    "Anger", "Anticipation", "Disgust", "Fear",
    "Joy", "Sadness", "Surprise", "Trust", "Positive", "Negative",
    "Mean sentiment", "Sentiment variability", "Sentiment range",
    "Median sentiment", "Negative segments (%)", "Negative sentences (%)",
    "Lexical density", "Emotion word density", "Positive/negative ratio",
    "Valence balance"
  ),
  label_es = c(
    "Tokens", "Tipos", "Oraciones", "Caracteres", "Silabas",
    "Razon tipo-token", "TTR raiz (Guiraud)", "TTR corregida",
    "C de Herdan", "a2 de Maas", "MATTR", "MTLD",
    "K de Yule", "D de Simpson", "H de Shannon", "Proporcion de hapax legomena",
    "Palabras por oracion", "DE de palabras por oracion",
    "Mediana de palabras por oracion", "Oraciones cortas (%)",
    "Oraciones largas (%)", "Letras por palabra", "Silabas por palabra",
    "Lecturabilidad de Fernandez Huerta", "Perspicuidad de Szigriszt-Pazos",
    "Escala INFLESZ", "Comprensibilidad de Gutierrez de Polini",
    "Indice mu", "Flesch-Kincaid (formula inglesa)",
    "Indice ARI (formula inglesa)",
    "Adjetivo", "Adposicion", "Adverbio", "Auxiliar",
    "Conjuncion coordinante", "Determinante", "Interjeccion", "Sustantivo",
    "Numeral", "Particula", "Pronombre", "Nombre propio",
    "Conjuncion subordinante", "Simbolo", "Verbo", "Otro",
    "Ira", "Anticipacion", "Asco", "Miedo",
    "Alegria", "Tristeza", "Sorpresa", "Confianza", "Positivo", "Negativo",
    "Sentimiento medio", "Variabilidad del sentimiento", "Rango del sentimiento",
    "Sentimiento mediano", "Segmentos negativos (%)", "Oraciones negativas (%)",
    "Densidad lexica", "Densidad de palabras emocionales", "Razon positivo/negativo",
    "Balance de valencia"
  ),
  stringsAsFactors = FALSE
)

# EN: Column-header translations. Exported tables must be readable in both
#     languages, which means the header row has to be translated too, not only
#     the caption.
# ES: Traducciones de encabezados de columna. Las tablas exportadas deben ser
#     legibles en los dos idiomas, lo que implica traducir tambien la fila de
#     encabezados, no solo el pie.
COLUMN_LABELS <- data.frame(
  key = c(
    "metric", "label", "n_focus", "n_comparison",
    "median_focus", "median_comparison", "mean_focus", "mean_comparison",
    "difference", "p_value", "p_adjusted", "cliffs_delta",
    "delta_ci", "delta_lower", "delta_upper", "delta_magnitude",
    "rank_biserial", "higher_in", "significant", "note", "family",
    "book_id", "group", "title_es", "title_en", "author", "series",
    "audience", "translated", "design", "verdict", "support", "clade",
    "n_books", "analysis", "prop_significant", "robust"
  ),
  label_en = c(
    "Measure", "Measure", "n (Papelucho)", "n (Comparison)",
    "Median (Papelucho)", "Median (Comparison)", "Mean (Papelucho)", "Mean (Comparison)",
    "Difference", "p", "p (adjusted)", "Cliff's delta",
    "Cliff's delta [95% CI]", "CI lower", "CI upper", "Effect size",
    "Rank-biserial", "Higher in", "Significant", "Note", "Family",
    "ID", "Corpus", "Title (ES)", "Title (EN)", "Author", "Series",
    "Audience", "Translated", "Design", "Verdict", "Support", "Cluster",
    "Books", "Analysis", "Draws significant", "Robust"
  ),
  label_es = c(
    "Medida", "Medida", "n (Papelucho)", "n (Comparacion)",
    "Mediana (Papelucho)", "Mediana (Comparacion)", "Media (Papelucho)", "Media (Comparacion)",
    "Diferencia", "p", "p (ajustado)", "Delta de Cliff",
    "Delta de Cliff [IC 95%]", "IC inferior", "IC superior", "Tamano de efecto",
    "Rango-biserial", "Mayor en", "Significativo", "Nota", "Familia",
    "ID", "Corpus", "Titulo (ES)", "Titulo (EN)", "Autor", "Serie",
    "Publico", "Traducido", "Diseno", "Veredicto", "Soporte", "Cluster",
    "Libros", "Analisis", "Sorteos significativos", "Robusto"
  ),
  stringsAsFactors = FALSE
)

#' Translate a column name into a human-readable header
column_label_for <- function(key, lang = c("en", "es")) {
  lang <- match.arg(lang)
  col  <- if (lang == "en") "label_en" else "label_es"
  idx  <- match(key, COLUMN_LABELS$key)
  out  <- COLUMN_LABELS[[col]][idx]
  ifelse(is.na(out), key, out)
}

# EN: Values that appear inside cells and therefore also need translating.
# ES: Valores que aparecen dentro de celdas y por lo tanto tambien hay que traducir.
VALUE_LABELS_ES <- c(
  "Papelucho" = "Papelucho", "Comparison" = "Comparacion", "tie" = "empate",
  "negligible" = "nulo", "small" = "pequeno", "medium" = "medio", "large" = "grande",
  "TRUE" = "Si", "FALSE" = "No",
  "children" = "infantil", "young_adult" = "juvenil", "adult" = "adulto"
)

#' Translate an internal key into a human-readable label
#' EN: Falls back to the key itself when no translation exists, so a missing
#'     entry degrades gracefully instead of producing NA in a published table.
#' ES: Si no hay traduccion devuelve la propia clave, de modo que una entrada
#'     faltante degrada de forma limpia en vez de producir NA en una tabla.
label_for <- function(key, lang = c("en", "es")) {
  lang <- match.arg(lang)
  col  <- if (lang == "en") "label_en" else "label_es"
  idx  <- match(key, LABELS$key)
  out  <- LABELS[[col]][idx]
  ifelse(is.na(out), key, out)
}

# -----------------------------------------------------------------------------
# 6. Dependencies
# -----------------------------------------------------------------------------

REQUIRED_PACKAGES <- c(
  "dplyr", "tidyr", "readr", "purrr", "tibble", "stringr", "stringi",
  "ggplot2", "tidytext", "stopwords", "udpipe", "sentimentr", "syuzhet",
  "zoo", "ggdendro", "ggrepel", "uwot"
)

#' Verify that every required package is installed
#' EN: Stops with an actionable message instead of failing later inside an
#'     analysis with a confusing "could not find function" error.
#' ES: Se detiene con un mensaje accionable en vez de fallar mas adelante
#'     dentro de un analisis con un error confuso de funcion no encontrada.
check_dependencies <- function(quiet = FALSE) {
  installed <- rownames(utils::installed.packages())
  missing   <- setdiff(REQUIRED_PACKAGES, installed)
  if (length(missing) > 0) {
    stop(
      "Missing R packages / Faltan paquetes de R:\n  ",
      paste(missing, collapse = ", "),
      "\n\nInstall with / Instala con:\n  install.packages(c(",
      paste0('"', missing, '"', collapse = ", "), "))",
      call. = FALSE
    )
  }
  if (!quiet) message("[config] All ", length(REQUIRED_PACKAGES), " required packages available.")
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# 7. Logging
# -----------------------------------------------------------------------------

#' Timestamped console message
log_msg <- function(...) {
  message(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

#' Record the exact software environment that produced the results
#' EN: Written next to the outputs so a reviewer can reproduce the numbers.
#' ES: Se escribe junto a los resultados para que un revisor pueda reproducir
#'     los numeros.
write_session_info <- function(step_name) {
  path <- file.path(PATHS$logs, paste0("sessionInfo_", step_name, ".txt"))
  con  <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(c(
    paste("Step:", step_name),
    paste("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("Seed:", PARAMS$seed),
    ""
  ), con)
  utils::capture.output(utils::sessionInfo(), file = con)
  invisible(path)
}
