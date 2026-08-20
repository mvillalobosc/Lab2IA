# =============================================================================
# 01_ingest.R  Carga de dialogos, traducciones, metadatos y lexicos
# =============================================================================
# El codigo original abria los 34 capitulos con 34 llamadas read_lines()
# escritas a mano, con el prefijo del nombre de archivo ("C-", "A-", ninguno)
# distinto por temporada. Aqui la unica fuente de verdad es episodes.csv, y los
# dialogos viven en dos CSV (uno por idioma) unidos por episode_id.
# =============================================================================

log_step("01  Ingesta de datos")

episodios <- readr::read_csv(CFG$f_episodes, show_col_types = FALSE)
stopifnot(!anyDuplicated(episodios$episode_id), !anyDuplicated(episodios$title_es))

# Orden canonico de la serie: fecha de publicacion, desempate por titulo.
# El original ordenaba solo por fecha, con el desempate dependiendo del orden
# alfabetico que dejaba merge(), lo que no es estable entre versiones de R.
episodios <- episodios[order(episodios$publish_date, episodios$title_es), ]
episodios$publish_date <- as.Date(episodios$publish_date)
rownames(episodios) <- NULL

leer_dialogos <- function(ruta, columna) {
  d <- readr::read_csv(ruta, show_col_types = FALSE)
  if (!all(c("episode_id", "text") %in% names(d))) {
    stop("El archivo ", basename(ruta), " debe tener las columnas episode_id y text.")
  }
  faltan <- setdiff(episodios$episode_id, d$episode_id)
  if (length(faltan)) {
    stop("Faltan dialogos en ", basename(ruta), " para: ", paste(faltan, collapse = ", "))
  }
  vacios <- d$episode_id[!nzchar(trimws(d$text))]
  if (length(vacios)) {
    stop("Dialogos vacios en ", basename(ruta), " para: ", paste(vacios, collapse = ", "))
  }
  d$text[match(episodios$episode_id, d$episode_id)]
}

episodios$texto_es <- leer_dialogos(CFG$f_dialogos_es, "es")
episodios$texto_en <- leer_dialogos(CFG$f_dialogos_en, "en")

# --- estadisticas de YouTube -------------------------------------------------
yt <- readr::read_csv(CFG$f_youtube, show_col_types = FALSE)
faltan <- setdiff(episodios$episode_id, yt$episode_id)
if (length(faltan)) stop("Capitulos sin estadisticas de YouTube: ",
                         paste(faltan, collapse = ", "))
serie <- dplyr::left_join(episodios, yt, by = "episode_id")

# --- lexicos -----------------------------------------------------------------
sw_extra <- readr::read_csv(CFG$f_stopwords, show_col_types = FALSE)
stopwords_es <- sort(unique(c(tm::stopwords("spanish"), sw_extra$word)))

temas_palabra <- readr::read_csv(CFG$f_topics, show_col_types = FALSE)
dup <- temas_palabra$word[duplicated(temas_palabra$word)]
if (length(dup)) stop("Palabras duplicadas en word_topics.csv: ",
                      paste(utils::head(dup, 10), collapse = ", "))

# Vector nombrado palabra -> tema. Reemplaza la busqueda
# temas_palabra$tema[temas_palabra$palabra == p] dentro de un bucle anidado,
# que en el original hacia del orden de 1.2e5 subconjuntos de data.frame.
mapa_tema <- stats::setNames(temas_palabra$topic, temas_palabra$word)

temas <- sort(setdiff(unique(temas_palabra$topic), CFG$tema_sin_definir))

log_msg("capitulos: ", nrow(serie),
        " | temporadas: ", paste(sort(unique(serie$season)), collapse = ","),
        " | rango: ", format(min(serie$publish_date)), " a ", format(max(serie$publish_date)))
log_msg("stopwords: ", length(stopwords_es),
        " | lexico tematico: ", nrow(temas_palabra), " palabras, ",
        length(temas), " temas")

save_step(list(serie = serie, stopwords = stopwords_es,
               mapa_tema = mapa_tema, temas = temas,
               temas_palabra = temas_palabra), "01_ingest")

write_table_out(
  dplyr::select(serie, episode_id, season, episode_in_season, title_es,
                publish_date, youtube_id, animation_team, views, likes,
                subscribers_current),
  "01_episodios"
)
