# =============================================================================
# 03_readability.R
# -----------------------------------------------------------------------------
# EN: Readability and structural complexity using formulas validated for
#     Spanish.
#
#     WHY THE ENGLISH FORMULAS WERE REPLACED
#     Flesch-Kincaid and the Automated Readability Index were fitted on English
#     school texts. Spanish words carry roughly 15 to 20 percent more syllables
#     per word than English ones for the same conceptual difficulty, because
#     Spanish morphology is more agglutinative in its inflections and its
#     function words are longer. Applying the English coefficients to Spanish
#     therefore inflates the estimated grade level by several years across the
#     board. The inflation is roughly constant, so the ranking of texts survives,
#     but the absolute values are meaningless and should never be reported as
#     grade levels for Spanish readers.
#
#     The Spanish-validated alternatives implemented here are:
#       * Fernandez Huerta (1959), the direct Spanish adaptation of Flesch;
#       * Szigriszt-Pazos (1993), a recalibration on a larger Spanish corpus;
#       * INFLESZ (Barrio-Cantalejo, 2008), the Szigriszt scale with cut points
#         validated on Spanish health and education texts;
#       * Gutierrez de Polini (1972), developed on Venezuelan school texts and
#         the only one of the four calibrated specifically on material for
#         children;
#       * the Mu index (Munoz & Munoz, 2006), which uses the distribution of
#         word lengths rather than syllable counts.
#     The two English formulas are still computed, clearly labelled, so the
#     values in the earlier draft remain traceable.
#
#     WHAT WAS ALSO WRONG BEFORE
#     The original script divided a token count taken from the stopword-filtered
#     text by a sentence count taken from the original text. Since stopword
#     removal discards roughly 55 percent of running words, every
#     words-per-sentence figure was slightly under half its true value, and both
#     readability indices inherited the error. Here every quantity in every
#     formula comes from the same raw representation.
#
# ES: Legibilidad y complejidad estructural con formulas validadas para el
#     espanol.
#
#     POR QUE SE REEMPLAZARON LAS FORMULAS INGLESAS
#     Flesch-Kincaid y el Automated Readability Index se ajustaron sobre textos
#     escolares en ingles. Las palabras del espanol tienen entre 15 y 20 por
#     ciento mas silabas por palabra que las inglesas para la misma dificultad
#     conceptual, porque la morfologia del espanol es mas aglutinante en sus
#     flexiones y sus palabras funcionales son mas largas. Aplicar los
#     coeficientes ingleses al espanol infla el nivel escolar estimado en varios
#     anios de forma generalizada. La inflacion es aproximadamente constante, asi
#     que el ordenamiento de los textos se mantiene, pero los valores absolutos
#     no significan nada y nunca deben reportarse como niveles escolares para
#     lectores hispanohablantes.
#
#     Las alternativas validadas para el espanol implementadas aca son:
#       * Fernandez Huerta (1959), la adaptacion directa de Flesch al espanol;
#       * Szigriszt-Pazos (1993), una recalibracion sobre un corpus espanol mayor;
#       * INFLESZ (Barrio-Cantalejo, 2008), la escala de Szigriszt con puntos de
#         corte validados en textos espanoles de salud y educacion;
#       * Gutierrez de Polini (1972), desarrollada sobre textos escolares
#         venezolanos y la unica de las cuatro calibrada especificamente sobre
#         material para ninos;
#       * el indice mu (Munoz y Munoz, 2006), que usa la distribucion de largos
#         de palabra en vez de conteos de silabas.
#     Las dos formulas inglesas se siguen calculando, claramente etiquetadas,
#     para que los valores del borrador anterior queden trazables.
#
#     QUE MAS ESTABA MAL ANTES
#     El script original dividia un conteo de tokens tomado del texto filtrado
#     por stopwords entre un conteo de oraciones tomado del texto original. Como
#     el filtrado descarta cerca del 55 por ciento de las palabras corrientes,
#     toda cifra de palabras por oracion quedaba en algo menos de la mitad de su
#     valor real, y los dos indices de legibilidad heredaban el error. Aca cada
#     cantidad de cada formula sale de la misma representacion cruda.
#
# OUTPUT / SALIDA
#   outputs/tables/03_readability_*.csv|.tex
#   outputs/figures/03_readability_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("03_readability: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})

corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, audience, translated,
                tokens_running, sentences,
                n_tokens_running, n_sentences, n_characters, n_syllables,
                words_per_sentence, letters_per_word, syllables_per_word)
invisible(gc(verbose = FALSE))

set.seed(PARAMS$seed)

# =============================================================================
# 1. Sentence-level structural measures
# =============================================================================
# EN: Mean words per sentence hides how variable sentence length is. A text of
#     uniformly medium sentences and a text alternating very short and very long
#     ones have the same mean but read completely differently. The standard
#     deviation and the proportion of short sentences are reported alongside,
#     since a first-person child narrator is expected to favour short clauses.
# ES: La media de palabras por oracion oculta que tan variable es el largo de
#     las oraciones. Un texto de oraciones uniformemente medianas y uno que
#     alterna muy cortas y muy largas tienen la misma media pero se leen de forma
#     completamente distinta. Se reportan ademas la desviacion estandar y la
#     proporcion de oraciones cortas, ya que se espera que un narrador infantil
#     en primera persona prefiera clausulas breves.

sentence_stats <- function(sentences) {

  if (length(sentences) == 0) {
    return(tibble::tibble(
      sd_words_per_sentence = NA_real_,
      median_words_per_sentence = NA_real_,
      pct_short_sentences = NA_real_,
      pct_long_sentences = NA_real_
    ))
  }

  lens <- stringr::str_count(sentences, paste0("[", SPANISH_LETTERS, "]+"))

  tibble::tibble(
    sd_words_per_sentence     = stats::sd(lens),
    median_words_per_sentence = stats::median(lens),
    # Thresholds follow the conventional readability literature: under 10 words
    # is a short sentence, over 25 a long one.
    pct_short_sentences       = 100 * mean(lens < 10),
    pct_long_sentences        = 100 * mean(lens > 25)
  )
}

# =============================================================================
# 2. Readability formulas
# =============================================================================

#' Fernandez Huerta readability score
#' EN: 206.84 - 60 * (syllables per word) - 1.02 * (words per sentence).
#'     Scale runs from 0 to 100; higher means easier. Roughly: over 90 very
#'     easy, 80 to 90 easy, 60 to 80 fairly easy to normal, 30 to 60 difficult,
#'     under 30 very difficult.
#' ES: 206,84 - 60 * (silabas por palabra) - 1,02 * (palabras por oracion).
#'     La escala va de 0 a 100; mas alto significa mas facil. Aproximadamente:
#'     sobre 90 muy facil, 80 a 90 facil, 60 a 80 bastante facil a normal, 30 a
#'     60 dificil, bajo 30 muy dificil.
fernandez_huerta <- function(syllables_per_word, words_per_sentence) {
  206.84 - 60 * syllables_per_word - 1.02 * words_per_sentence
}

#' Szigriszt-Pazos perspicuity index
#' EN: 206.835 - 62.3 * (syllables per word) - (words per sentence).
#'     A recalibration of Flesch on a larger Spanish corpus than Fernandez
#'     Huerta used, and generally considered the more accurate of the two.
#' ES: 206,835 - 62,3 * (silabas por palabra) - (palabras por oracion).
#'     Una recalibracion de Flesch sobre un corpus espanol mayor que el usado por
#'     Fernandez Huerta, y en general considerada la mas exacta de las dos.
szigriszt_pazos <- function(syllables_per_word, words_per_sentence) {
  206.835 - 62.3 * syllables_per_word - words_per_sentence
}

#' INFLESZ interpretive band
#' EN: The Szigriszt score mapped onto the cut points validated by
#'     Barrio-Cantalejo for Spanish readers.
#' ES: El puntaje de Szigriszt mapeado a los puntos de corte validados por
#'     Barrio-Cantalejo para lectores hispanohablantes.
inflesz_band <- function(score, lang = c("en", "es")) {
  lang <- match.arg(lang)
  if (lang == "en") {
    dplyr::case_when(
      is.na(score)  ~ NA_character_,
      score < 40    ~ "very difficult",
      score < 55    ~ "somewhat difficult",
      score < 65    ~ "normal",
      score < 80    ~ "fairly easy",
      TRUE          ~ "very easy"
    )
  } else {
    dplyr::case_when(
      is.na(score)  ~ NA_character_,
      score < 40    ~ "muy dificil",
      score < 55    ~ "algo dificil",
      score < 65    ~ "normal",
      score < 80    ~ "bastante facil",
      TRUE          ~ "muy facil"
    )
  }
}

#' Gutierrez de Polini comprehensibility index
#' EN: 95.2 - 9.7 * (letters per word) - 0.35 * (words per sentence).
#'     Developed on Venezuelan school texts, which makes it the formula in this
#'     set best matched to children's literature. It uses letters rather than
#'     syllables, so it does not inherit any error from syllable estimation.
#' ES: 95,2 - 9,7 * (letras por palabra) - 0,35 * (palabras por oracion).
#'     Desarrollada sobre textos escolares venezolanos, lo que la vuelve la
#'     formula de este conjunto mejor ajustada a literatura infantil. Usa letras
#'     en vez de silabas, asi que no hereda error alguno de la estimacion de
#'     silabas.
gutierrez_polini <- function(letters_per_word, words_per_sentence) {
  95.2 - 9.7 * letters_per_word - 0.35 * words_per_sentence
}

#' Mu index
#' EN: (n / (n - 1)) * (mean word length / variance of word length) * 100,
#'     where n is the number of words. Based entirely on the distribution of
#'     word lengths in letters, so it is independent of both syllabification and
#'     sentence segmentation, the two steps most exposed to error in a digitised
#'     corpus. Higher values mean easier text.
#' ES: (n / (n - 1)) * (largo medio de palabra / varianza del largo) * 100,
#'     donde n es el numero de palabras. Se basa por completo en la distribucion
#'     de largos de palabra en letras, asi que es independiente tanto de la
#'     silabificacion como de la segmentacion en oraciones, los dos pasos mas
#'     expuestos a error en un corpus digitalizado. Valores mas altos significan
#'     texto mas facil.
mu_index <- function(word_lengths) {
  n <- length(word_lengths)
  if (n < 2) return(NA_real_)
  m <- mean(word_lengths)
  v <- stats::var(word_lengths)
  if (is.na(v) || v == 0) return(NA_real_)
  (n / (n - 1)) * (m / v) * 100
}

#' Flesch-Kincaid grade level, English formula
#' EN: Retained only for traceability with the earlier draft. Not valid for
#'     Spanish; see the header of this file.
#' ES: Se conserva solo por trazabilidad con el borrador anterior. No es valida
#'     para el espanol; ver el encabezado de este archivo.
flesch_kincaid_en <- function(syllables_per_word, words_per_sentence) {
  0.39 * words_per_sentence + 11.8 * syllables_per_word - 15.59
}

#' Automated Readability Index, English formula
#' EN: Retained only for traceability. Not valid for Spanish.
#' ES: Se conserva solo por trazabilidad. No es valida para el espanol.
ari_en <- function(letters_per_word, words_per_sentence) {
  4.71 * letters_per_word + 0.5 * words_per_sentence - 21.43
}

# =============================================================================
# 3. Compute
# =============================================================================

log_msg("  computing structural and readability measures")

readability <- corpus %>%
  dplyr::mutate(
    sent_stats  = purrr::map(sentences, sentence_stats),
    word_len    = purrr::map(tokens_running, nchar),
    Mu_index    = purrr::map_dbl(word_len, mu_index)
  ) %>%
  dplyr::select(-sentences, -tokens_running, -word_len) %>%
  tidyr::unnest(sent_stats) %>%
  dplyr::mutate(
    Fernandez_Huerta  = fernandez_huerta(syllables_per_word, words_per_sentence),
    Szigriszt_Pazos   = szigriszt_pazos(syllables_per_word, words_per_sentence),
    Gutierrez_Polini  = gutierrez_polini(letters_per_word, words_per_sentence),
    Flesch_Kincaid_EN = flesch_kincaid_en(syllables_per_word, words_per_sentence),
    ARI_EN            = ari_en(letters_per_word, words_per_sentence),
    inflesz_band_en   = inflesz_band(Szigriszt_Pazos, "en"),
    inflesz_band_es   = inflesz_band(Szigriszt_Pazos, "es")
  )

# EN: No book is dropped for having implausible structural values. A book whose
#     sentence segmentation failed would produce an extreme words-per-sentence
#     figure; that is recorded as a flag so the analyst can decide, rather than
#     silently removed.
# ES: Ningun libro se descarta por tener valores estructurales inverosimiles. Un
#     libro cuya segmentacion en oraciones fallara produciria una cifra extrema
#     de palabras por oracion; eso queda registrado como bandera para que el
#     analista decida, en vez de eliminarse en silencio.
readability <- readability %>%
  dplyr::mutate(
    flag_segmentation = words_per_sentence < 5 | words_per_sentence > 60 |
      n_sentences < 20
  )

n_flagged <- sum(readability$flag_segmentation)
if (n_flagged > 0) {
  log_msg("  ", n_flagged, " book(s) flagged for implausible sentence segmentation; retained in the analysis")
  print(as.data.frame(
    readability %>%
      dplyr::filter(flag_segmentation) %>%
      dplyr::select(book_id, title_es, n_sentences, words_per_sentence)
  ), row.names = FALSE)
} else {
  log_msg("  sentence segmentation plausible for all ", nrow(readability), " books")
}

stopifnot(nrow(readability) == nrow(corpus))

# =============================================================================
# 4. Group comparison
# =============================================================================

STRUCTURAL <- c("words_per_sentence", "sd_words_per_sentence",
                "median_words_per_sentence", "pct_short_sentences",
                "pct_long_sentences", "letters_per_word", "syllables_per_word")

SPANISH_FORMULAS <- c("Fernandez_Huerta", "Szigriszt_Pazos",
                      "Gutierrez_Polini", "Mu_index")

ENGLISH_FORMULAS <- c("Flesch_Kincaid_EN", "ARI_EN")

log_msg("  comparing groups")

results <- compare_many(
  readability,
  metrics = c(STRUCTURAL, SPANISH_FORMULAS, ENGLISH_FORMULAS),
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    family = dplyr::case_when(
      metric %in% STRUCTURAL       ~ "structural",
      metric %in% SPANISH_FORMULAS ~ "readability (Spanish-validated)",
      TRUE                         ~ "readability (English formula, not valid for Spanish)"
    ),
    label_en = label_for(metric, "en"),
    label_es = label_for(metric, "es")
  )

# =============================================================================
# 5. Figures
# =============================================================================

fig_data <- readability %>%
  tidyr::pivot_longer(
    dplyr::all_of(c(STRUCTURAL, SPANISH_FORMULAS)),
    names_to = "metric", values_to = "value"
  ) %>%
  dplyr::mutate(
    metric_label = label_for(metric, "en"),
    group = factor(group, levels = c(GROUPS$focus, GROUPS$comparison))
  )

fig_read <- ggplot(fig_data, aes(x = group, y = value, colour = group)) +
  geom_boxplot(outlier.shape = NA, width = 0.55, linewidth = 0.45) +
  geom_jitter(width = 0.16, alpha = 0.55, size = 1.5) +
  facet_wrap(~ metric_label, scales = "free_y", ncol = 4) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = NULL, y = "Value", colour = "Corpus") +
  theme_papelucho(base_size = 11)

save_figure(fig_read, "03_readability_by_group", width = 12, height = 7)

# EN: Distribution of sentence lengths, pooled by group. This makes visible what
#     a mean cannot: whether Papelucho's shorter mean reflects uniformly short
#     sentences or a different shape of distribution.
# ES: Distribucion de largos de oracion, agrupada por corpus. Esto muestra lo
#     que una media no puede: si la media mas baja de Papelucho refleja oraciones
#     uniformemente cortas o una forma distinta de distribucion.
sentence_lengths <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, sentences) %>%
  dplyr::mutate(
    lens = purrr::map(sentences, ~ stringr::str_count(.x, paste0("[", SPANISH_LETTERS, "]+")))
  ) %>%
  dplyr::select(-sentences) %>%
  tidyr::unnest(lens) %>%
  dplyr::filter(lens > 0, lens <= 80)
invisible(gc(verbose = FALSE))

fig_sentlen <- ggplot(sentence_lengths, aes(x = lens, fill = group, colour = group)) +
  geom_density(alpha = 0.25, linewidth = 0.6, adjust = 1.2) +
  scale_fill_manual(values = GROUP_COLOURS) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = "Words per sentence", y = "Density", fill = "Corpus", colour = "Corpus") +
  theme_papelucho()

save_figure(fig_sentlen, "03_sentence_length_distribution", width = 9, height = 5)

# =============================================================================
# 6. Export
# =============================================================================

by_book <- readability %>%
  dplyr::select(
    book_id, group, title_es, author, audience, translated,
    n_tokens_running, n_sentences,
    dplyr::all_of(STRUCTURAL),
    dplyr::all_of(SPANISH_FORMULAS),
    inflesz_band_en, inflesz_band_es,
    dplyr::all_of(ENGLISH_FORMULAS),
    flag_segmentation
  ) %>%
  dplyr::arrange(group, book_id)

export_table(
  by_book, "03_readability_by_book",
  caption_en = "Structural complexity and readability by book. All quantities are computed on the raw text with punctuation and function words intact.",
  caption_es = "Complejidad estructural y legibilidad por libro. Todas las cantidades se calculan sobre el texto crudo con puntuacion y palabras funcionales intactas.",
  label = "readability-by-book",
  note_en = "Fernandez Huerta, Szigriszt-Pazos, Gutierrez de Polini and the Mu index are validated for Spanish; higher values mean easier text. The Flesch-Kincaid and ARI columns use English coefficients and are reported only for traceability with earlier work.",
  note_es = "Fernandez Huerta, Szigriszt-Pazos, Gutierrez de Polini y el indice mu estan validados para el espanol; valores mas altos indican texto mas facil. Las columnas de Flesch-Kincaid y ARI usan coeficientes ingleses y se reportan solo por trazabilidad con trabajo anterior."
)

export_results(
  results, "03_readability_results",
  caption_en = "Group comparison of structural complexity and readability.",
  caption_es = "Comparacion entre grupos de la complejidad estructural y la legibilidad.",
  label = "readability-results",
  note_en = "Mann-Whitney U tests with Holm correction across the whole family; Cliff's delta with a bootstrap 95 percent confidence interval.",
  note_es = "Pruebas U de Mann-Whitney con correccion de Holm sobre toda la familia; Cliff's delta con intervalo de confianza bootstrap del 95 por ciento."
)

band_summary <- readability %>%
  dplyr::count(group, inflesz_band_en, name = "n_books") %>%
  tidyr::pivot_wider(names_from = inflesz_band_en, values_from = n_books,
                     values_fill = 0L)

write_table_csv(band_summary, "03_inflesz_bands")
saveRDS(readability, file.path(PATHS$derived, "readability.rds"))

# =============================================================================
# 7. Console summary
# =============================================================================

log_msg("  results:")
print(as.data.frame(
  results %>%
    dplyr::transmute(
      metric,
      median_pap  = round(median_focus, 2),
      median_comp = round(median_comparison, 2),
      delta       = round(cliffs_delta, 3),
      magnitude   = delta_magnitude,
      p_adj       = format_p(p_adjusted),
      significant,
      higher_in
    )
), row.names = FALSE)

log_msg("  INFLESZ bands:")
print(as.data.frame(band_summary), row.names = FALSE)

write_session_info("03_readability")
log_msg("03_readability: done")
