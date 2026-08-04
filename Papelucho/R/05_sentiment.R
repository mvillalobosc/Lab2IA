# =============================================================================
# 05_sentiment.R
# -----------------------------------------------------------------------------
# EN: Sentence-level sentiment and narrative arc.
#
#     WHAT WAS BROKEN BEFORE
#     Two independent failures compounded in the original script.
#
#     First, sentiment was computed on the stopword-filtered text, from which
#     all punctuation had already been stripped. sentimentr::get_sentences()
#     segments on sentence-final punctuation, so with none present it returned
#     one single "sentence" per book. The subsequent ntile(sentence_id, 20)
#     therefore produced one chunk, not twenty. Every book's narrative arc
#     collapsed to a single point before the arc was ever plotted.
#
#     Second, sentiment() was called without a polarity table, which silently
#     defaults to the English Jockers-Rinker lexicon. On Spanish input it scores
#     almost everything at zero. The two failures together mean the original
#     sentiment analysis measured nothing at all.
#
#     WHAT THIS SCRIPT DOES
#     Sentiment is computed on the raw text, sentence by sentence, using the
#     Spanish polarity table and valence shifters built in utils_sentiment_es.R.
#     A self-test runs first and stops the script if the lexicon is not scoring
#     Spanish correctly, so the silent-failure mode cannot recur.
#
#     Each book is divided into PARAMS$n_chunks equal segments by sentence
#     position, giving a narrative arc that is comparable across books of very
#     different lengths: segment 7 of 20 is the same relative point in a short
#     book and a long one.
#
#     WHAT IS COMPARED
#     Mean sentiment is reported, but the more informative quantities for
#     children's literature are the variability of sentiment across the arc and
#     the proportion of segments that fall below zero. A book can have a neutral
#     mean either because it is emotionally flat or because it swings hard in
#     both directions, and those are different books.
#
# ES: Sentimiento a nivel de oracion y arco narrativo.
#
#     QUE ESTABA ROTO ANTES
#     En el script original se acumulaban dos fallas independientes.
#
#     Primero, el sentimiento se calculaba sobre el texto filtrado por stopwords,
#     al que ya se le habia quitado toda la puntuacion.
#     sentimentr::get_sentences() segmenta por puntuacion final de oracion, asi
#     que sin ninguna presente devolvia una sola "oracion" por libro. El
#     ntile(sentence_id, 20) posterior producia entonces un chunk, no veinte. El
#     arco narrativo de cada libro colapsaba a un punto antes de graficarse.
#
#     Segundo, sentiment() se llamaba sin tabla de polaridad, lo que en silencio
#     usa el lexico ingles de Jockers-Rinker por defecto. Sobre entrada en
#     espanol puntua casi todo en cero. Las dos fallas juntas significan que el
#     analisis de sentimiento original no midio absolutamente nada.
#
#     QUE HACE ESTE SCRIPT
#     El sentimiento se calcula sobre el texto crudo, oracion por oracion, con la
#     tabla de polaridad y los valence shifters en espanol construidos en
#     utils_sentiment_es.R. Un autotest corre primero y detiene el script si el
#     lexico no esta puntuando bien el espanol, de modo que el modo de falla
#     silenciosa no puede repetirse.
#
#     Cada libro se divide en PARAMS$n_chunks segmentos iguales por posicion de
#     oracion, lo que da un arco narrativo comparable entre libros de largos muy
#     distintos: el segmento 7 de 20 es el mismo punto relativo en un libro corto
#     y en uno largo.
#
#     QUE SE COMPARA
#     Se reporta el sentimiento medio, pero las cantidades mas informativas para
#     literatura infantil son la variabilidad del sentimiento a lo largo del arco
#     y la proporcion de segmentos bajo cero. Un libro puede tener media neutra
#     por ser emocionalmente plano o por oscilar fuerte en ambas direcciones, y
#     esos son libros distintos.
#
# OUTPUT / SALIDA
#   outputs/tables/05_sentiment_*.csv|.tex
#   outputs/figures/05_sentiment_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")
source("R/utils_sentiment_es.R")

check_dependencies(quiet = TRUE)
log_msg("05_sentiment: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(sentimentr)
})

set.seed(PARAMS$seed)

# =============================================================================
# 1. Build and verify the Spanish lexicon
# =============================================================================

log_msg("  building Spanish polarity and valence shifter tables")
keys <- spanish_sentiment_keys(verbose = TRUE)

log_msg("  running lexicon self-test")
selftest <- test_spanish_sentiment(keys, verbose = TRUE)
write_table_csv(selftest, "05_sentiment_lexicon_selftest")

# =============================================================================
# 2. Score every sentence
# =============================================================================

corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, audience, translated, sentences)
invisible(gc(verbose = FALSE))

# EN: Sentences are scored per book rather than as one pooled vector, so a
#     failure on one book cannot silently shift the element indices of another.
#     The original script joined scores back by a row identifier computed across
#     the whole corpus, which is fragile for exactly that reason.
# ES: Las oraciones se puntuan por libro y no como un vector unico, para que una
#     falla en un libro no pueda desplazar en silencio los indices de otro. El
#     script original unia los puntajes por un identificador de fila calculado
#     sobre todo el corpus, que es fragil justamente por eso.
score_book <- function(sentences, n_chunks) {

  if (length(sentences) < n_chunks) {
    # A book with fewer sentences than chunks would produce empty segments.
    # It is kept, but the number of chunks is reduced to the sentence count so
    # every chunk contains at least one sentence.
    n_chunks <- max(1L, length(sentences))
  }

  scored <- sentimentr::sentiment(
    sentimentr::get_sentences(enc2utf8(sentences)),
    polarity_dt         = keys$polarity_dt,
    valence_shifters_dt = keys$valence_shifters_dt,
    n.before            = PARAMS$sentiment_n_before,
    n.after             = PARAMS$sentiment_n_after
  )

  per_sentence <- as.data.frame(scored) %>%
    dplyr::group_by(element_id) %>%
    dplyr::summarise(
      sentiment  = mean(sentiment, na.rm = TRUE),
      word_count = sum(word_count, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(element_id) %>%
    dplyr::mutate(
      sentence_id = dplyr::row_number(),
      chunk       = dplyr::ntile(sentence_id, n_chunks)
    )

  per_sentence
}

log_msg("  scoring sentences in ", nrow(corpus), " books")

scored <- corpus %>%
  dplyr::mutate(
    sent = purrr::imap(sentences, function(s, i) {
      if (i %% 15 == 0) log_msg("    ", i, "/", nrow(corpus))
      score_book(s, PARAMS$n_chunks)
    })
  ) %>%
  dplyr::select(-sentences)

sentence_level <- scored %>%
  dplyr::select(book_id, group, title_es, author, sent) %>%
  tidyr::unnest(sent)

log_msg("  scored ", format(nrow(sentence_level), big.mark = ","), " sentences")

# EN: Verify the segmentation actually produced the requested number of chunks.
#     This is the specific check that would have caught the original bug: a
#     collapsed arc shows up here as a chunk count of one.
# ES: Se verifica que la segmentacion haya producido de verdad el numero pedido
#     de chunks. Este es el chequeo concreto que habria detectado el error
#     original: un arco colapsado aparece aca como un conteo de chunks igual a
#     uno.
chunk_check <- sentence_level %>%
  dplyr::group_by(book_id, group) %>%
  dplyr::summarise(
    n_sentences = dplyr::n(),
    n_chunks    = dplyr::n_distinct(chunk),
    .groups = "drop"
  )

if (any(chunk_check$n_chunks < PARAMS$n_chunks)) {
  bad <- chunk_check %>% dplyr::filter(n_chunks < PARAMS$n_chunks)
  log_msg("  WARNING: ", nrow(bad), " book(s) produced fewer than ",
          PARAMS$n_chunks, " narrative segments")
  print(as.data.frame(bad), row.names = FALSE)
} else {
  log_msg("  all books segmented into ", PARAMS$n_chunks, " narrative segments")
}

stopifnot(dplyr::n_distinct(sentence_level$book_id) == nrow(corpus))

# =============================================================================
# 3. Narrative arc: sentiment per segment
# =============================================================================

# EN: The per-segment column is named chunk_sentiment rather than
#     mean_sentiment. Inside dplyr::summarise() a new column shadows the source
#     column of the same name for every expression that follows it, so writing
#     mean_sentiment = mean(mean_sentiment) and then sd(mean_sentiment) computes
#     the standard deviation of a single scalar and silently returns NA. Keeping
#     the names distinct makes that class of error impossible.
# ES: La columna por segmento se llama chunk_sentiment y no mean_sentiment.
#     Dentro de dplyr::summarise() una columna nueva ensombrece a la columna
#     fuente del mismo nombre para toda expresion posterior, asi que escribir
#     mean_sentiment = mean(mean_sentiment) y despues sd(mean_sentiment) calcula
#     la desviacion estandar de un solo escalar y devuelve NA en silencio.
#     Mantener los nombres distintos vuelve imposible esa clase de error.
arc <- sentence_level %>%
  dplyr::group_by(book_id, group, title_es, author, chunk) %>%
  dplyr::summarise(
    chunk_sentiment = mean(sentiment, na.rm = TRUE),
    n_sentences     = dplyr::n(),
    .groups = "drop"
  )

# =============================================================================
# 4. Book-level summaries
# =============================================================================
# EN: Every summary is computed across the twenty narrative segments rather than
#     across raw sentences, so a long book does not dominate through sheer
#     sentence count. This is the same length-control logic used elsewhere in
#     the pipeline.
# ES: Todo resumen se calcula sobre los veinte segmentos narrativos y no sobre
#     las oraciones crudas, para que un libro largo no domine por puro conteo de
#     oraciones. Es la misma logica de control de largo usada en el resto del
#     pipeline.

book_sentiment <- arc %>%
  dplyr::group_by(book_id, group, title_es, author) %>%
  dplyr::summarise(
    mean_sentiment      = mean(chunk_sentiment, na.rm = TRUE),
    median_sentiment    = stats::median(chunk_sentiment, na.rm = TRUE),
    sd_sentiment        = stats::sd(chunk_sentiment, na.rm = TRUE),
    min_sentiment       = min(chunk_sentiment, na.rm = TRUE),
    max_sentiment       = max(chunk_sentiment, na.rm = TRUE),
    sentiment_range     = max(chunk_sentiment, na.rm = TRUE) -
      min(chunk_sentiment, na.rm = TRUE),
    pct_negative_chunks = 100 * mean(chunk_sentiment < 0, na.rm = TRUE),
    n_chunks            = dplyr::n(),
    .groups = "drop"
  ) %>%
  dplyr::left_join(
    sentence_level %>%
      dplyr::group_by(book_id) %>%
      dplyr::summarise(
        n_sentences        = dplyr::n(),
        pct_negative_sentences = 100 * mean(sentiment < 0, na.rm = TRUE),
        pct_neutral_sentences  = 100 * mean(abs(sentiment) < 1e-8, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "book_id"
  )

stopifnot(nrow(book_sentiment) == nrow(corpus))

# EN: Guard against the summarise-shadowing failure mode described above. If the
#     per-book variability collapses to NA or to exactly zero for every book, the
#     summary was computed on a scalar rather than on the twenty segments.
# ES: Guarda contra el modo de falla por shadowing descrito arriba. Si la
#     variabilidad por libro colapsa a NA o a exactamente cero en todos los
#     libros, el resumen se calculo sobre un escalar y no sobre los veinte
#     segmentos.
if (all(is.na(book_sentiment$sd_sentiment)) ||
    all(book_sentiment$sentiment_range == 0, na.rm = TRUE)) {
  stop("Per-book sentiment variability collapsed. The narrative segments were not aggregated correctly.",
       call. = FALSE)
}

# EN: If the lexicon were failing on Spanish, nearly every sentence would score
#     exactly zero. This check makes that visible instead of leaving it to be
#     inferred from a suspiciously flat plot.
# ES: Si el lexico estuviera fallando con el espanol, casi toda oracion puntuaria
#     exactamente cero. Este chequeo lo hace visible en vez de dejarlo a deducir
#     desde un grafico sospechosamente plano.
overall_neutral <- 100 * mean(abs(sentence_level$sentiment) < 1e-8)
log_msg("  sentences scoring exactly zero: ", round(overall_neutral, 1), "%")
if (overall_neutral > 80) {
  warning("Over 80 percent of sentences score exactly zero. The lexicon may not be matching the corpus vocabulary.",
          call. = FALSE)
}

# =============================================================================
# 5. Group comparison
# =============================================================================

SENTIMENT_METRICS <- c("mean_sentiment", "median_sentiment", "sd_sentiment",
                       "sentiment_range", "pct_negative_chunks",
                       "pct_negative_sentences")

log_msg("  comparing groups")

results <- compare_many(
  book_sentiment, SENTIMENT_METRICS,
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    label_en = label_for(metric, "en"),
    label_es = label_for(metric, "es")
  )

# =============================================================================
# 6. Figures
# =============================================================================

# EN: Mean narrative arc per group with a ribbon showing the interquartile
#     range. The ribbon matters: with 63 comparison books against 12 Papelucho
#     books, a mean line alone would hide how much more spread the larger group
#     has.
# ES: Arco narrativo medio por grupo con una banda que muestra el rango
#     intercuartil. La banda importa: con 63 libros de comparacion contra 12 de
#     Papelucho, una linea de medias sola ocultaria cuanta mas dispersion tiene
#     el grupo grande.
arc_summary <- arc %>%
  dplyr::group_by(group, chunk) %>%
  dplyr::summarise(
    median_sentiment = stats::median(chunk_sentiment, na.rm = TRUE),
    q1 = stats::quantile(chunk_sentiment, 0.25, na.rm = TRUE),
    q3 = stats::quantile(chunk_sentiment, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

fig_arc <- ggplot(arc_summary, aes(x = chunk, colour = group, fill = group)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = q1, ymax = q3), alpha = 0.18, colour = NA) +
  geom_line(aes(y = median_sentiment), linewidth = 0.9) +
  geom_point(aes(y = median_sentiment), size = 1.8) +
  scale_colour_manual(values = GROUP_COLOURS) +
  scale_fill_manual(values = GROUP_COLOURS) +
  scale_x_continuous(breaks = seq(1, PARAMS$n_chunks, by = 2)) +
  labs(x = paste0("Narrative position (segment of ", PARAMS$n_chunks, ")"),
       y = "Sentiment", colour = "Corpus", fill = "Corpus") +
  theme_papelucho()

save_figure(fig_arc, "05_narrative_arc", width = 9, height = 5.5)

# Individual arcs for the Papelucho books, which is the series-level view the
# study is actually about.
fig_arc_pap <- arc %>%
  dplyr::filter(group == GROUPS$focus) %>%
  ggplot(aes(x = chunk, y = chunk_sentiment)) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.35) +
  geom_line(colour = GROUP_COLOURS[[GROUPS$focus]], linewidth = 0.7) +
  facet_wrap(~ title_es, ncol = 4) +
  scale_x_continuous(breaks = c(1, 10, 20)) +
  labs(x = paste0("Narrative position (segment of ", PARAMS$n_chunks, ")"),
       y = "Sentiment") +
  theme_papelucho(base_size = 10)

save_figure(fig_arc_pap, "05_narrative_arc_papelucho", width = 12, height = 7)

fig_metrics <- book_sentiment %>%
  tidyr::pivot_longer(dplyr::all_of(SENTIMENT_METRICS),
                      names_to = "metric", values_to = "value") %>%
  dplyr::mutate(
    metric_label = label_for(metric, "en"),
    group = factor(group, levels = c(GROUPS$focus, GROUPS$comparison))
  ) %>%
  ggplot(aes(x = group, y = value, colour = group)) +
  geom_boxplot(outlier.shape = NA, width = 0.55, linewidth = 0.45) +
  geom_jitter(width = 0.16, alpha = 0.55, size = 1.5) +
  facet_wrap(~ metric_label, scales = "free_y", ncol = 3) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = NULL, y = "Value", colour = "Corpus") +
  theme_papelucho(base_size = 11)

save_figure(fig_metrics, "05_sentiment_metrics", width = 11, height = 6)

# =============================================================================
# 7. Export
# =============================================================================

export_table(
  book_sentiment %>% dplyr::arrange(group, book_id),
  "05_sentiment_by_book",
  caption_en = sprintf("Sentiment by book, computed on the raw text with a Spanish polarity lexicon and valence shifters. Summaries are taken across %d equal narrative segments.",
                       PARAMS$n_chunks),
  caption_es = sprintf("Sentimiento por libro, calculado sobre el texto crudo con un lexico de polaridad en espanol y valence shifters. Los resumenes se toman sobre %d segmentos narrativos iguales.",
                       PARAMS$n_chunks),
  label = "sentiment-by-book",
  note_en = "The polarity lexicon derives from the Spanish NRC list, itself a machine translation of the English original. Absolute values should be read as a coarse signal.",
  note_es = "El lexico de polaridad deriva de la lista NRC en espanol, que a su vez es una traduccion automatica del original ingles. Los valores absolutos deben leerse como una senal gruesa."
)

export_results(
  results, "05_sentiment_results",
  caption_en = "Group comparison of sentiment measures.",
  caption_es = "Comparacion entre grupos de las medidas de sentimiento.",
  label = "sentiment-results"
)

write_table_csv(arc, "05_narrative_arc_by_book")
write_table_csv(chunk_check, "05_sentiment_chunk_check")
saveRDS(book_sentiment, file.path(PATHS$derived, "sentiment.rds"))
saveRDS(arc, file.path(PATHS$derived, "narrative_arc.rds"))

# =============================================================================
# 8. Console summary
# =============================================================================

log_msg("  results:")
print(as.data.frame(
  results %>%
    dplyr::transmute(
      metric,
      median_pap  = round(median_focus, 4),
      median_comp = round(median_comparison, 4),
      delta       = round(cliffs_delta, 3),
      magnitude   = delta_magnitude,
      p_adj       = format_p(p_adjusted),
      significant,
      higher_in
    )
), row.names = FALSE)

write_session_info("05_sentiment")
log_msg("05_sentiment: done")
