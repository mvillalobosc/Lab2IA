# =============================================================================
# 06_emotions.R
# -----------------------------------------------------------------------------
# EN: NRC emotion profiles, normalised by text length.
#
#     WHAT WAS BROKEN BEFORE
#     syuzhet::get_nrc_sentiment() returns absolute counts: the number of tokens
#     in the text matching each of the eight Plutchik emotions. The original
#     script fed those raw counts straight into a Mann-Whitney test. Since the
#     median comparison novel has about 102,000 running tokens against about
#     19,000 for the median Papelucho book, the comparison group wins every
#     emotion by construction. The test was a test of book length wearing the
#     label of an emotion analysis, and it would have returned the same eight
#     "significant" results for any two groups of long and short texts
#     whatsoever.
#
#     The second problem was that no multiple-testing correction was applied
#     across the eight emotions.
#
#     WHAT THIS SCRIPT DOES
#     Counts are divided by the number of running tokens in the same text and
#     reported per thousand tokens, which makes books of any length directly
#     comparable. Holm correction is applied once across the whole family of ten
#     tests (eight emotions plus positive and negative valence).
#
#     Two further quantities are reported because raw intensity is not the only
#     thing that distinguishes emotional writing. The relative emotion profile
#     rescales each book's eight emotions to sum to one, describing the shape of
#     its emotional palette independently of how emotionally charged the
#     vocabulary is overall. The positive-to-negative ratio summarises valence
#     balance in a single number.
#
#     A LIMITATION WORTH STATING
#     The NRC lexicon assigns emotions to word types out of context. Irony,
#     negation and figurative language are invisible to it. In a first-person
#     child narrator whose humour depends heavily on saying the opposite of what
#     is meant, this is a real constraint, and the README repeats it.
#
# ES: Perfiles emocionales NRC, normalizados por largo del texto.
#
#     QUE ESTABA ROTO ANTES
#     syuzhet::get_nrc_sentiment() devuelve conteos absolutos: el numero de
#     tokens del texto que calzan con cada una de las ocho emociones de Plutchik.
#     El script original metia esos conteos crudos directo a una prueba de
#     Mann-Whitney. Como la novela mediana de comparacion tiene unos 102.000
#     tokens corrientes contra unos 19.000 del libro mediano de Papelucho, el
#     grupo de comparacion gana todas las emociones por construccion. La prueba
#     era una prueba de largo de libro con la etiqueta de analisis emocional, y
#     habria devuelto los mismos ocho resultados "significativos" para cualquier
#     par de grupos de textos largos y cortos.
#
#     El segundo problema era que no se aplicaba correccion por pruebas
#     multiples sobre las ocho emociones.
#
#     QUE HACE ESTE SCRIPT
#     Los conteos se dividen por el numero de tokens corrientes del mismo texto y
#     se reportan por mil tokens, lo que vuelve directamente comparables libros
#     de cualquier largo. La correccion de Holm se aplica una vez sobre toda la
#     familia de diez pruebas (ocho emociones mas valencia positiva y negativa).
#
#     Se reportan dos cantidades adicionales porque la intensidad cruda no es lo
#     unico que distingue la escritura emocional. El perfil emocional relativo
#     reescala las ocho emociones de cada libro para que sumen uno, describiendo
#     la forma de su paleta emocional con independencia de que tan cargado este
#     el vocabulario en general. La razon positivo sobre negativo resume el
#     balance de valencia en un solo numero.
#
#     UNA LIMITACION QUE CONVIENE DECLARAR
#     El lexico NRC asigna emociones a tipos de palabra fuera de contexto. La
#     ironia, la negacion y el lenguaje figurado le son invisibles. En un
#     narrador infantil en primera persona cuyo humor depende mucho de decir lo
#     contrario de lo que quiere decir, esto es una restriccion real, y el README
#     la repite.
#
# OUTPUT / SALIDA
#   outputs/tables/06_emotions_*.csv|.tex
#   outputs/figures/06_emotions_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("06_emotions: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(syuzhet)
})

set.seed(PARAMS$seed)

corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, audience, translated,
                tokens_running, n_tokens_running)
invisible(gc(verbose = FALSE))

EMOTIONS <- c("anger", "anticipation", "disgust", "fear",
              "joy", "sadness", "surprise", "trust")
VALENCE  <- c("positive", "negative")

# =============================================================================
# 1. Score emotions from the token stream
# =============================================================================
# EN: The lexicon is matched against the running-word token stream rather than
#     against the raw text passed as one long string. Two reasons. First, the
#     denominator is then exactly the set of tokens the numerator was drawn from,
#     which is what makes the normalisation honest. Second, matching a
#     pre-tokenised vector is far faster than letting syuzhet re-tokenise 6.8
#     million tokens of text.
#
#     Matching is on exact word forms, since the NRC Spanish list is a word list
#     rather than a lemma list. Accents are preserved, because "esta" and "está"
#     are different words and stripping accents would create false matches.
# ES: El lexico se compara contra el flujo de tokens corrientes y no contra el
#     texto crudo pasado como una sola cadena larga. Por dos razones. Primero,
#     el denominador es entonces exactamente el conjunto de tokens del que salio
#     el numerador, que es lo que vuelve honesta la normalizacion. Segundo,
#     comparar un vector ya tokenizado es mucho mas rapido que dejar que syuzhet
#     retokenice 6,8 millones de tokens de texto.
#
#     La comparacion es sobre formas exactas, ya que la lista NRC en espanol es
#     una lista de palabras y no de lemas. Se conservan los acentos, porque
#     "esta" y "está" son palabras distintas y quitar los acentos crearia
#     coincidencias falsas.

log_msg("  loading Spanish NRC lexicon")

nrc_es <- syuzhet:::nrc %>%
  dplyr::filter(lang == "spanish", value == 1) %>%
  dplyr::mutate(word = stringr::str_to_lower(stringi::stri_trans_nfc(word))) %>%
  dplyr::distinct(word, sentiment)

log_msg("  lexicon: ", dplyr::n_distinct(nrc_es$word), " word types across ",
        dplyr::n_distinct(nrc_es$sentiment), " categories")

#' Count lexicon matches in a token vector
score_emotions <- function(tokens) {
  tibble::tibble(word = tokens) %>%
    dplyr::inner_join(nrc_es, by = "word", relationship = "many-to-many") %>%
    dplyr::count(sentiment, name = "count")
}

log_msg("  scoring ", nrow(corpus), " books")

raw_counts <- corpus %>%
  dplyr::mutate(
    scores = purrr::imap(tokens_running, function(tk, i) {
      if (i %% 15 == 0) log_msg("    ", i, "/", nrow(corpus))
      score_emotions(tk)
    })
  ) %>%
  dplyr::select(-tokens_running) %>%
  tidyr::unnest(scores)

# EN: Complete the grid so a category with no matches in a book records a zero
#     rather than dropping the book from that category's comparison.
# ES: Se completa la grilla para que una categoria sin coincidencias en un libro
#     registre cero en vez de sacar al libro de la comparacion de esa categoria.
emotions_long <- raw_counts %>%
  tidyr::complete(
    tidyr::nesting(book_id, group, title_es, author, audience, translated,
                   n_tokens_running),
    sentiment = c(EMOTIONS, VALENCE),
    fill = list(count = 0L)
  ) %>%
  dplyr::mutate(
    per_1000 = 1000 * count / n_tokens_running
  )

stopifnot(dplyr::n_distinct(emotions_long$book_id) == nrow(corpus))
stopifnot(nrow(emotions_long) == nrow(corpus) * length(c(EMOTIONS, VALENCE)))

# =============================================================================
# 2. Wide forms
# =============================================================================

emotions_wide <- emotions_long %>%
  dplyr::select(book_id, group, title_es, author, audience, translated,
                n_tokens_running, sentiment, per_1000) %>%
  tidyr::pivot_wider(names_from = sentiment, values_from = per_1000)

counts_wide <- emotions_long %>%
  dplyr::select(book_id, sentiment, count) %>%
  tidyr::pivot_wider(names_from = sentiment, values_from = count,
                     names_prefix = "count_")

# EN: Relative emotion profile: the eight emotions rescaled to sum to one within
#     each book. This separates the shape of the emotional palette from its
#     overall intensity. A book can score low on every emotion because its
#     vocabulary is plain, yet still be proportionally dominated by joy.
# ES: Perfil emocional relativo: las ocho emociones reescaladas para sumar uno
#     dentro de cada libro. Esto separa la forma de la paleta emocional de su
#     intensidad general. Un libro puede puntuar bajo en todas las emociones
#     porque su vocabulario es sencillo, y aun asi estar proporcionalmente
#     dominado por la alegria.
emotion_totals <- emotions_wide %>%
  dplyr::transmute(book_id, total = rowSums(dplyr::across(dplyr::all_of(EMOTIONS))))

relative_profile <- emotions_wide %>%
  dplyr::left_join(emotion_totals, by = "book_id") %>%
  dplyr::mutate(dplyr::across(dplyr::all_of(EMOTIONS),
                              ~ ifelse(total > 0, .x / total, NA_real_))) %>%
  dplyr::select(book_id, group, title_es, dplyr::all_of(EMOTIONS))

emotions_wide <- emotions_wide %>%
  dplyr::mutate(
    emotion_density   = rowSums(dplyr::across(dplyr::all_of(EMOTIONS))),
    valence_ratio     = ifelse(negative > 0, positive / negative, NA_real_),
    valence_balance   = positive - negative
  )

# =============================================================================
# 3. Group comparison
# =============================================================================

log_msg("  comparing groups (normalised per 1,000 running tokens)")

results_normalised <- compare_many(
  emotions_wide, c(EMOTIONS, VALENCE),
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    analysis = "per 1,000 tokens",
    label_en = label_for(metric, "en"),
    label_es = label_for(metric, "es")
  )

log_msg("  comparing groups (relative profile)")

results_relative <- compare_many(
  relative_profile, EMOTIONS,
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    analysis = "share of total emotion words",
    label_en = label_for(metric, "en"),
    label_es = label_for(metric, "es")
  )

# EN: The raw-count comparison is reproduced solely to document the size of the
#     original artefact. It is never interpreted.
# ES: La comparacion de conteos crudos se reproduce solo para documentar el
#     tamano del artefacto original. Nunca se interpreta.
counts_for_test <- emotions_long %>%
  dplyr::select(book_id, group, sentiment, count) %>%
  tidyr::pivot_wider(names_from = sentiment, values_from = count)

results_rawcount <- compare_many(
  counts_for_test, c(EMOTIONS, VALENCE),
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(analysis = "raw counts (length-confounded, for contrast only)")

contrast <- results_rawcount %>%
  dplyr::select(metric, raw_delta = cliffs_delta, raw_p = p_adjusted,
                raw_higher = higher_in, raw_sig = significant) %>%
  dplyr::left_join(
    results_normalised %>%
      dplyr::select(metric, norm_delta = cliffs_delta, norm_p = p_adjusted,
                    norm_higher = higher_in, norm_sig = significant),
    by = "metric"
  ) %>%
  dplyr::mutate(
    direction_flips    = !is.na(raw_higher) & !is.na(norm_higher) &
      raw_higher != norm_higher,
    significance_flips = raw_sig != norm_sig
  )

extra_results <- compare_many(
  emotions_wide, c("emotion_density", "valence_ratio", "valence_balance"),
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
)

# =============================================================================
# 4. Figures
# =============================================================================

fig_norm <- emotions_wide %>%
  tidyr::pivot_longer(dplyr::all_of(EMOTIONS),
                      names_to = "emotion", values_to = "per_1000") %>%
  dplyr::mutate(
    emotion_label = label_for(emotion, "en"),
    group = factor(group, levels = c(GROUPS$focus, GROUPS$comparison))
  ) %>%
  ggplot(aes(x = stats::reorder(emotion_label, per_1000), y = per_1000,
             colour = group)) +
  geom_boxplot(outlier.shape = NA, width = 0.62, linewidth = 0.42,
               position = position_dodge(width = 0.75)) +
  geom_point(alpha = 0.35, size = 1.1,
             position = position_jitterdodge(jitter.width = 0.14,
                                             dodge.width = 0.75)) +
  scale_colour_manual(values = GROUP_COLOURS) +
  coord_flip() +
  labs(x = NULL, y = "Matches per 1,000 running tokens", colour = "Corpus") +
  theme_papelucho(base_size = 11)

save_figure(fig_norm, "06_emotions_normalised", width = 9, height = 6)

# Radar-style comparison of the relative profile, drawn as a polygon on polar
# coordinates. Shows the shape of each corpus's emotional palette.
radar_data <- relative_profile %>%
  tidyr::pivot_longer(dplyr::all_of(EMOTIONS),
                      names_to = "emotion", values_to = "share") %>%
  dplyr::group_by(group, emotion) %>%
  dplyr::summarise(share = stats::median(share, na.rm = TRUE), .groups = "drop") %>%
  dplyr::mutate(emotion_label = label_for(emotion, "en"))

fig_radar <- ggplot(radar_data,
                    aes(x = emotion_label, y = share,
                        colour = group, group = group)) +
  geom_polygon(aes(fill = group), alpha = 0.14, linewidth = 0.8) +
  geom_point(size = 2.2) +
  coord_polar() +
  scale_colour_manual(values = GROUP_COLOURS) +
  scale_fill_manual(values = GROUP_COLOURS) +
  labs(x = NULL, y = NULL, colour = "Corpus", fill = "Corpus",
       subtitle = "Median share of total emotion-word matches") +
  theme_papelucho(base_size = 11) +
  theme(axis.line = element_blank(), axis.ticks = element_blank())

save_figure(fig_radar, "06_emotions_relative_profile", width = 8, height = 7)

# EN: The contrast figure is the argument for normalisation, made visually.
# ES: La figura de contraste es el argumento a favor de la normalizacion, hecho
#     de forma visual.
contrast_fig_data <- dplyr::bind_rows(
  results_rawcount %>%
    dplyr::select(metric, cliffs_delta, delta_lower, delta_upper) %>%
    dplyr::mutate(analysis = "Raw counts"),
  results_normalised %>%
    dplyr::select(metric, cliffs_delta, delta_lower, delta_upper) %>%
    dplyr::mutate(analysis = "Per 1,000 tokens")
) %>%
  dplyr::mutate(
    label = label_for(metric, "en"),
    analysis = factor(analysis, levels = c("Raw counts", "Per 1,000 tokens"))
  )

fig_contrast <- ggplot(contrast_fig_data,
                       aes(x = cliffs_delta, y = stats::reorder(label, cliffs_delta),
                           colour = analysis)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = delta_lower, xmax = delta_upper),
                 height = 0.2, linewidth = 0.45,
                 position = position_dodge(width = 0.55)) +
  geom_point(size = 2.4, position = position_dodge(width = 0.55)) +
  scale_colour_manual(values = c("Raw counts" = "grey45",
                                 "Per 1,000 tokens" = "#00A499")) +
  scale_x_continuous(limits = c(-1, 1)) +
  labs(x = "Cliff's delta (positive: higher in Papelucho)", y = NULL,
       colour = NULL) +
  theme_papelucho(base_size = 11)

save_figure(fig_contrast, "06_emotions_normalisation_contrast", width = 9, height = 6)

# =============================================================================
# 5. Export
# =============================================================================

by_book <- emotions_wide %>%
  dplyr::left_join(counts_wide, by = "book_id") %>%
  dplyr::arrange(group, book_id)

export_table(
  by_book, "06_emotions_by_book",
  caption_en = "NRC emotion profiles by book, expressed as lexicon matches per 1,000 running tokens. Absolute counts are included for reference.",
  caption_es = "Perfiles emocionales NRC por libro, expresados como coincidencias del lexico por cada 1.000 tokens corrientes. Se incluyen los conteos absolutos como referencia.",
  label = "emotions-by-book",
  note_en = "The NRC lexicon assigns emotions to word types out of context and cannot detect irony or negation.",
  note_es = "El lexico NRC asigna emociones a tipos de palabra fuera de contexto y no puede detectar ironia ni negacion."
)

export_results(
  results_normalised, "06_emotions_results_normalised",
  caption_en = "Group comparison of emotion frequencies normalised per 1,000 running tokens.",
  caption_es = "Comparacion entre grupos de las frecuencias emocionales normalizadas por cada 1.000 tokens corrientes.",
  label = "emotions-normalised"
)

export_results(
  results_relative, "06_emotions_results_relative",
  caption_en = "Group comparison of the relative emotion profile, each book's eight emotions rescaled to sum to one.",
  caption_es = "Comparacion entre grupos del perfil emocional relativo, con las ocho emociones de cada libro reescaladas para sumar uno.",
  label = "emotions-relative"
)

export_table(
  contrast, "06_emotions_normalisation_contrast",
  caption_en = "Effect of length normalisation on each emotion category.",
  caption_es = "Efecto de la normalizacion por largo sobre cada categoria emocional.",
  label = "emotions-contrast"
)

write_table_csv(results_rawcount, "06_emotions_results_rawcount")
write_table_csv(extra_results, "06_emotions_density_and_valence")
write_table_csv(relative_profile, "06_emotions_relative_by_book")
saveRDS(emotions_wide, file.path(PATHS$derived, "emotions.rds"))

# =============================================================================
# 6. Console summary
# =============================================================================

log_msg("  normalised results (per 1,000 tokens):")
print(as.data.frame(
  results_normalised %>%
    dplyr::transmute(
      emotion = metric,
      pap  = round(median_focus, 2),
      comp = round(median_comparison, 2),
      delta = round(cliffs_delta, 3),
      magnitude = delta_magnitude,
      p_adj = format_p(p_adjusted),
      significant, higher_in
    )
), row.names = FALSE)

n_flip <- sum(contrast$direction_flips, na.rm = TRUE)
log_msg("  ", n_flip, " of ", nrow(contrast),
        " categories reverse direction once normalised by length")
log_msg("  raw-count analysis found ", sum(results_rawcount$significant, na.rm = TRUE),
        " significant of ", nrow(results_rawcount),
        "; normalised analysis finds ", sum(results_normalised$significant, na.rm = TRUE))

write_session_info("06_emotions")
log_msg("06_emotions: done")
