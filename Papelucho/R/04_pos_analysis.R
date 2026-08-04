# =============================================================================
# 04_pos_analysis.R
# -----------------------------------------------------------------------------
# EN: Part-of-speech profiles from the raw text.
#
#     WHY THIS SCRIPT EXISTS IN THIS FORM
#     The original analysis ran the tagger over the stopword-filtered text. In
#     Spanish the stopword list is made almost entirely of function words:
#     determiners, prepositions, pronouns, conjunctions and auxiliaries. Tagging
#     a text from which those have been removed does not measure the text's
#     grammatical profile, it measures what the stopword list happens to contain.
#     Tagging the same book both ways gives, for adpositions, 10.8 percent on
#     the raw text against 0.5 percent on the filtered text, a factor of about
#     twenty; for coordinating conjunctions the factor is over seventy. The
#     categories that survive are correspondingly inflated: nouns and verbs
#     roughly double.
#
#     This matters beyond the arithmetic. Pronoun frequency is one of the few
#     measures that speaks directly to a first-person child narrator, which is
#     the defining formal feature of the Papelucho series. Filtering pronouns out
#     before tagging discards precisely the evidence the study needs.
#
#     LENGTH AND RUNTIME
#     Tagging the full corpus would mean 6.8 million tokens at roughly 870
#     tokens per second, close to two hours. It would also leave the comparison
#     group contributing five times more text per book. Both problems are solved
#     the same way: each book contributes a random sample of whole sentences up
#     to a fixed token budget. Sampling whole sentences rather than loose tokens
#     preserves the syntactic context the tagger needs to disambiguate.
#
# ES: Perfiles morfosintacticos a partir del texto crudo.
#
#     POR QUE ESTE SCRIPT ES ASI
#     El analisis original corria el etiquetador sobre el texto filtrado por
#     stopwords. En espanol la lista de stopwords esta compuesta casi por
#     completo de palabras funcionales: determinantes, preposiciones, pronombres,
#     conjunciones y auxiliares. Etiquetar un texto del que se quitaron esas no
#     mide el perfil gramatical del texto, mide lo que la lista de stopwords
#     contenga. Etiquetar el mismo libro de las dos formas da, para adposiciones,
#     10,8 por ciento sobre el texto crudo contra 0,5 por ciento sobre el
#     filtrado, un factor cercano a veinte; para conjunciones coordinantes el
#     factor supera setenta. Las categorias que sobreviven quedan infladas en
#     consecuencia: sustantivos y verbos casi se duplican.
#
#     Esto importa mas alla de la aritmetica. La frecuencia de pronombres es una
#     de las pocas medidas que habla directamente de un narrador infantil en
#     primera persona, que es el rasgo formal definitorio de la serie Papelucho.
#     Filtrar los pronombres antes de etiquetar descarta justamente la evidencia
#     que el estudio necesita.
#
#     LARGO Y TIEMPO DE EJECUCION
#     Etiquetar el corpus completo implicaria 6,8 millones de tokens a unos 870
#     tokens por segundo, cerca de dos horas. Ademas dejaria al grupo de
#     comparacion aportando cinco veces mas texto por libro. Los dos problemas se
#     resuelven igual: cada libro aporta una muestra aleatoria de oraciones
#     completas hasta un presupuesto fijo de tokens. Muestrear oraciones enteras
#     en vez de tokens sueltos preserva el contexto sintactico que el etiquetador
#     necesita para desambiguar.
#
# OUTPUT / SALIDA
#   outputs/tables/04_pos_*.csv|.tex
#   outputs/figures/04_pos_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("04_pos_analysis: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(udpipe)
})

if (!file.exists(UDPIPE_MODEL)) {
  stop("UDPipe model not found at ", UDPIPE_MODEL,
       "\nRun: Rscript scripts/download_udpipe_model.R", call. = FALSE)
}

corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, audience, translated, sentences)
invisible(gc(verbose = FALSE))

set.seed(PARAMS$seed)

# EN: Token budget per book. Twenty thousand tokens is well above the point at
#     which part-of-speech proportions stabilise (they are stable from a few
#     thousand tokens onwards) and keeps total runtime near half an hour on one
#     core.
# ES: Presupuesto de tokens por libro. Veinte mil tokens esta muy por encima del
#     punto donde las proporciones morfosintacticas se estabilizan (son estables
#     desde unos pocos miles de tokens) y mantiene el tiempo total cerca de media
#     hora en un solo nucleo.
POS_TOKEN_BUDGET <- 20000L

# =============================================================================
# 1. Sample sentences up to the token budget
# =============================================================================

#' Draw whole sentences at random until a token budget is reached
#' EN: Sentences are drawn in random order and then restored to their original
#'     sequence, so the sample is a random subset of the book that still reads
#'     in narrative order. If a book has fewer tokens than the budget, all of it
#'     is used; no book is excluded for being short.
#' ES: Las oraciones se extraen en orden aleatorio y luego se restauran a su
#'     secuencia original, de modo que la muestra es un subconjunto aleatorio del
#'     libro que igual se lee en orden narrativo. Si un libro tiene menos tokens
#'     que el presupuesto, se usa completo; ningun libro se excluye por corto.
sample_sentences <- function(sentences, budget) {

  if (length(sentences) == 0) return(list(text = "", n_tokens = 0L, n_sentences = 0L))

  lens <- stringr::str_count(sentences, paste0("[", SPANISH_LETTERS, "]+"))
  ord  <- sample.int(length(sentences))

  cum  <- cumsum(lens[ord])
  take <- ord[cum <= budget]

  # Guarantee at least one sentence even if the first drawn already exceeds the
  # budget, which can happen with an unusually long sentence.
  if (length(take) == 0) take <- ord[1]

  take <- sort(take)

  list(
    text        = paste(sentences[take], collapse = " "),
    n_tokens    = sum(lens[take]),
    n_sentences = length(take)
  )
}

log_msg("  sampling up to ", format(POS_TOKEN_BUDGET, big.mark = ","),
        " tokens per book")

samples <- corpus %>%
  dplyr::mutate(smp = purrr::map(sentences, ~ sample_sentences(.x, POS_TOKEN_BUDGET))) %>%
  dplyr::select(-sentences) %>%
  dplyr::mutate(
    sample_text        = purrr::map_chr(smp, "text"),
    sample_tokens      = purrr::map_int(smp, "n_tokens"),
    sample_n_sentences = purrr::map_int(smp, "n_sentences")
  ) %>%
  dplyr::select(-smp)

log_msg("  sample sizes: median ",
        format(stats::median(samples$sample_tokens), big.mark = ","),
        " tokens, min ", format(min(samples$sample_tokens), big.mark = ","),
        ", max ", format(max(samples$sample_tokens), big.mark = ","))

# EN: Books shorter than the budget contribute everything they have. Recorded
#     explicitly because it is the only respect in which the sample is not
#     perfectly balanced, and a reader is entitled to know which books those are.
# ES: Los libros mas cortos que el presupuesto aportan todo lo que tienen. Se
#     registra de forma explicita porque es el unico aspecto en que la muestra no
#     queda perfectamente balanceada, y un lector tiene derecho a saber cuales
#     libros son.
under_budget <- samples %>%
  dplyr::filter(sample_tokens < POS_TOKEN_BUDGET * 0.95) %>%
  dplyr::select(book_id, group, title_es, sample_tokens)

if (nrow(under_budget) > 0) {
  log_msg("  ", nrow(under_budget), " book(s) shorter than the budget, used in full:")
  print(as.data.frame(under_budget), row.names = FALSE)
}

# =============================================================================
# 2. Annotate
# =============================================================================

log_msg("  loading UDPipe model")
model <- udpipe::udpipe_load_model(UDPIPE_MODEL)

log_msg("  tagging ", nrow(samples), " samples (this takes roughly half an hour)")

annotate_one <- function(txt, doc_id) {
  if (!nzchar(txt)) return(tibble::tibble())
  udpipe::udpipe_annotate(model, x = txt, doc_id = doc_id) %>%
    as.data.frame() %>%
    tibble::as_tibble() %>%
    dplyr::select(doc_id, token, lemma, upos)
}

annotations <- purrr::pmap_dfr(
  list(samples$sample_text, samples$book_id, seq_len(nrow(samples))),
  function(txt, id, i) {
    if (i %% 10 == 0) log_msg("    ", i, "/", nrow(samples))
    annotate_one(txt, id)
  }
)

log_msg("  tagged ", format(nrow(annotations), big.mark = ","), " tokens")

# EN: Punctuation is excluded from the denominator so proportions describe the
#     grammatical composition of the running words, not the density of commas.
# ES: La puntuacion se excluye del denominador para que las proporciones
#     describan la composicion gramatical de las palabras corrientes, no la
#     densidad de comas.
tokens_tagged <- annotations %>%
  dplyr::filter(!is.na(upos), upos != "PUNCT", !is.na(token), token != "") %>%
  dplyr::mutate(upos = toupper(as.character(upos)))

pos_counts <- tokens_tagged %>%
  dplyr::count(book_id = doc_id, upos, name = "frequency") %>%
  dplyr::group_by(book_id) %>%
  dplyr::mutate(
    total_tokens = sum(frequency),
    proportion   = frequency / total_tokens
  ) %>%
  dplyr::ungroup()

# EN: Complete the grid so a category absent from a book is recorded as zero
#     rather than dropping out. Without this, a book that happens to contain no
#     interjections would be silently excluded from the interjection test,
#     changing the sample size for that one comparison.
# ES: Se completa la grilla para que una categoria ausente en un libro quede
#     registrada como cero en vez de desaparecer. Sin esto, un libro que no
#     tuviera interjecciones quedaria excluido en silencio de la prueba de
#     interjecciones, cambiando el tamano muestral de esa comparacion.
all_upos <- sort(unique(pos_counts$upos))

pos_wide <- pos_counts %>%
  dplyr::select(book_id, upos, proportion) %>%
  tidyr::complete(book_id, upos = all_upos, fill = list(proportion = 0)) %>%
  tidyr::pivot_wider(names_from = upos, values_from = proportion) %>%
  dplyr::left_join(
    samples %>% dplyr::select(book_id, group, title_es, author, audience,
                              translated, sample_tokens, sample_n_sentences),
    by = "book_id"
  )

stopifnot(nrow(pos_wide) == nrow(corpus))
stopifnot(!anyNA(pos_wide[, all_upos]))

# =============================================================================
# 3. Group comparison
# =============================================================================

log_msg("  comparing groups across ", length(all_upos), " POS categories")

results <- compare_many(
  pos_wide, all_upos,
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    label_en = label_for(metric, "en"),
    label_es = label_for(metric, "es"),
    median_focus_pct      = 100 * median_focus,
    median_comparison_pct = 100 * median_comparison
  )

# =============================================================================
# 4. Lexical density
# =============================================================================
# EN: Lexical density is the share of content words (nouns, verbs, adjectives,
#     adverbs, proper nouns) among all running words. It is the standard summary
#     of how information-dense a text is, and unlike the individual category
#     proportions it has a direct interpretation: lower density means more
#     grammatical scaffolding per unit of content, which is characteristic of
#     spoken and child-directed language.
# ES: La densidad lexica es la proporcion de palabras de contenido (sustantivos,
#     verbos, adjetivos, adverbios, nombres propios) sobre todas las palabras
#     corrientes. Es el resumen estandar de que tan densa en informacion es un
#     texto, y a diferencia de las proporciones por categoria tiene una
#     interpretacion directa: menor densidad significa mas andamiaje gramatical
#     por unidad de contenido, caracteristico del lenguaje oral y del lenguaje
#     dirigido a ninos.
CONTENT_POS <- intersect(c("NOUN", "VERB", "ADJ", "ADV", "PROPN"), all_upos)

pos_wide <- pos_wide %>%
  dplyr::mutate(
    lexical_density = rowSums(dplyr::across(dplyr::all_of(CONTENT_POS)))
  )

density_result <- compare_groups(
  pos_wide, "lexical_density",
  focus = GROUPS$focus, comparison = GROUPS$comparison, seed = PARAMS$seed
) %>%
  dplyr::mutate(p_adjusted = p_value)   # single test, no family correction

# =============================================================================
# 5. Figures
# =============================================================================

fig_data <- pos_wide %>%
  tidyr::pivot_longer(dplyr::all_of(all_upos),
                      names_to = "upos", values_to = "proportion") %>%
  dplyr::mutate(
    upos_label = label_for(upos, "en"),
    group = factor(group, levels = c(GROUPS$focus, GROUPS$comparison))
  )

# Order categories by overall frequency so the eye reads the plot in a useful
# order rather than alphabetically.
upos_order <- fig_data %>%
  dplyr::group_by(upos_label) %>%
  dplyr::summarise(m = mean(proportion), .groups = "drop") %>%
  dplyr::arrange(dplyr::desc(m)) %>%
  dplyr::pull(upos_label)

fig_data <- fig_data %>%
  dplyr::mutate(upos_label = factor(upos_label, levels = upos_order))

fig_pos <- ggplot(fig_data, aes(x = upos_label, y = 100 * proportion, colour = group)) +
  geom_boxplot(outlier.shape = NA, width = 0.65, linewidth = 0.42,
               position = position_dodge(width = 0.75)) +
  geom_point(alpha = 0.35, size = 1.1,
             position = position_jitterdodge(jitter.width = 0.14, dodge.width = 0.75)) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = NULL, y = "Percentage of running words", colour = "Corpus") +
  theme_papelucho(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_figure(fig_pos, "04_pos_profile", width = 11, height = 6)

# Effect size plot: the clearest single summary of which categories separate the
# two corpora and by how much.
fig_effect <- results %>%
  dplyr::filter(!is.na(cliffs_delta)) %>%
  dplyr::mutate(label_en = stats::reorder(label_en, cliffs_delta)) %>%
  ggplot(aes(x = cliffs_delta, y = label_en)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = delta_lower, xmax = delta_upper),
                 height = 0.22, linewidth = 0.45, colour = "grey40") +
  geom_point(aes(colour = significant), size = 2.8) +
  scale_colour_manual(values = c("TRUE" = "#00A499", "FALSE" = "grey55"),
                      labels = c("TRUE" = "Significant", "FALSE" = "Not significant")) +
  scale_x_continuous(limits = c(-1, 1)) +
  labs(x = "Cliff's delta (positive: higher in Papelucho)", y = NULL,
       colour = NULL) +
  theme_papelucho(base_size = 11)

save_figure(fig_effect, "04_pos_effect_sizes", width = 9, height = 6)

# =============================================================================
# 6. Export
# =============================================================================

by_book <- pos_wide %>%
  dplyr::select(book_id, group, title_es, author, audience, translated,
                sample_tokens, sample_n_sentences, lexical_density,
                dplyr::all_of(all_upos)) %>%
  dplyr::arrange(group, book_id)

export_table(
  by_book, "04_pos_by_book",
  caption_en = sprintf("Part-of-speech proportions by book, computed on the raw text. Each book contributes a random sample of whole sentences up to %s tokens.",
                       format(POS_TOKEN_BUDGET, big.mark = ",")),
  caption_es = sprintf("Proporciones morfosintacticas por libro, calculadas sobre el texto crudo. Cada libro aporta una muestra aleatoria de oraciones completas hasta %s tokens.",
                       format(POS_TOKEN_BUDGET, big.mark = ",")),
  label = "pos-by-book",
  note_en = "Proportions are of running words excluding punctuation. Tagging used the Spanish GSD UD 2.5 model.",
  note_es = "Las proporciones son sobre palabras corrientes excluyendo puntuacion. El etiquetado uso el modelo GSD UD 2.5 del espanol.",
  digits = 4
)

export_results(
  results, "04_pos_results",
  caption_en = "Group comparison of part-of-speech proportions.",
  caption_es = "Comparacion entre grupos de las proporciones morfosintacticas.",
  label = "pos-results",
  note_en = "Mann-Whitney U tests with Holm correction across all categories; Cliff's delta with a bootstrap 95 percent confidence interval. Positive delta means the category is more frequent in Papelucho.",
  note_es = "Pruebas U de Mann-Whitney con correccion de Holm sobre todas las categorias; Cliff's delta con intervalo de confianza bootstrap del 95 por ciento. Un delta positivo significa que la categoria es mas frecuente en Papelucho."
)

write_table_csv(density_result, "04_lexical_density_result")
write_table_csv(pos_counts, "04_pos_counts_long")
saveRDS(pos_wide, file.path(PATHS$derived, "pos_profiles.rds"))

# =============================================================================
# 7. Console summary
# =============================================================================

log_msg("  results (percentage of running words):")
print(as.data.frame(
  results %>%
    dplyr::arrange(dplyr::desc(abs(cliffs_delta))) %>%
    dplyr::transmute(
      upos = metric,
      pap  = round(median_focus_pct, 2),
      comp = round(median_comparison_pct, 2),
      delta = round(cliffs_delta, 3),
      magnitude = delta_magnitude,
      p_adj = format_p(p_adjusted),
      significant,
      higher_in
    )
), row.names = FALSE)

log_msg("  lexical density: Papelucho ",
        round(100 * density_result$median_focus, 1), "%, Comparison ",
        round(100 * density_result$median_comparison, 1), "%, delta ",
        round(density_result$cliffs_delta, 3), " (", density_result$delta_magnitude, ")")

write_session_info("04_pos_analysis")
log_msg("04_pos_analysis: done")
