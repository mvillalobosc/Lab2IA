# =============================================================================
# 09_sensitivity.R
# -----------------------------------------------------------------------------
# EN: Sensitivity analyses for the three structural confounds in the corpus.
#
#     THE PROBLEM THIS SCRIPT EXISTS TO ADDRESS
#     No amount of careful statistics on the full corpus can fix a comparison
#     group that differs from the focus group in more ways than the one being
#     studied. Three such differences are present:
#
#       (a) AUDIENCE. Most comparison books are adult fiction. Papelucho is
#           written for children. A difference in vocabulary or readability
#           between a children's book and an adult novel is expected and tells
#           us nothing specific about Papelucho.
#
#       (b) TRANSLATION. Sixty of the sixty-three comparison books are
#           translations into Spanish. Papelucho is original Chilean Spanish.
#           Translated prose is known to differ systematically from original
#           prose in the target language: it is typically more explicit, more
#           standardised and lexically flatter, a set of tendencies documented in
#           translation studies as translation universals. Any lexical or
#           stylistic difference found on the full corpus may be a translation
#           effect rather than a Papelucho effect.
#
#       (c) AUTHORSHIP CONCENTRATION. A single author contributes sixteen of the
#           sixty-three comparison books, and the five most represented authors
#           contribute thirty-eight between them. The Mann-Whitney test assumes
#           independent observations. Sixteen novels by one author sharing a
#           setting and a narrative voice are not sixteen independent draws from
#           the population of Spanish-language fiction, so the effective sample
#           size is much smaller than sixty-three and the p-values on the full
#           corpus are anticonservative.
#
#     WHAT THIS SCRIPT DOES
#     Each headline finding is re-tested under three restricted designs:
#
#       1. AUDIENCE-MATCHED: only comparison books written for children or young
#          adults.
#       2. ORIGINAL SPANISH ONLY: only comparison books written in Spanish, with
#          no translation step.
#       3. ONE BOOK PER AUTHOR: one randomly chosen book per comparison author,
#          repeated many times, so that no author is over-represented. Results
#          are summarised across the repetitions.
#
#     A finding that survives all three is robust to the corpus composition. A
#     finding that appears only on the full corpus is a statement about how the
#     comparison group was assembled, not about Papelucho.
#
#     WHAT THIS SCRIPT CANNOT DO
#     Design 2 leaves very few comparison books. Its results are reported with
#     that sample size attached and should be read as indicative only. No
#     restriction can rescue a comparison that was never appropriate; if the
#     findings do not survive, the corpus needs rebuilding, and that is a
#     decision for the analyst, not for this script.
#
# ES: Analisis de sensibilidad para los tres confundidos estructurales del corpus.
#
#     EL PROBLEMA QUE ESTE SCRIPT ATIENDE
#     Ninguna cantidad de estadistica cuidadosa sobre el corpus completo puede
#     arreglar un grupo de comparacion que difiere del grupo foco en mas aspectos
#     que el estudiado. Hay tres diferencias de ese tipo:
#
#       (a) PUBLICO. La mayoria de los libros de comparacion son ficcion adulta.
#           Papelucho esta escrito para ninos. Una diferencia de vocabulario o
#           legibilidad entre un libro infantil y una novela adulta es esperable y
#           no dice nada especifico sobre Papelucho.
#
#       (b) TRADUCCION. Sesenta de los sesenta y tres libros de comparacion son
#           traducciones al espanol. Papelucho es espanol chileno original. Se
#           sabe que la prosa traducida difiere sistematicamente de la prosa
#           original en la lengua meta: suele ser mas explicita, mas estandarizada
#           y lexicamente mas plana, un conjunto de tendencias documentado en los
#           estudios de traduccion como universales de traduccion. Cualquier
#           diferencia lexica o estilistica hallada en el corpus completo puede
#           ser un efecto de traduccion y no un efecto Papelucho.
#
#       (c) CONCENTRACION DE AUTORIA. Un solo autor aporta dieciseis de los
#           sesenta y tres libros de comparacion, y los cinco autores mas
#           representados aportan treinta y ocho entre todos. La prueba de
#           Mann-Whitney asume observaciones independientes. Dieciseis novelas de
#           un mismo autor que comparten ambientacion y voz narrativa no son
#           dieciseis extracciones independientes de la poblacion de ficcion en
#           espanol, asi que el tamano muestral efectivo es mucho menor que
#           sesenta y tres y los valores p del corpus completo son
#           anticonservadores.
#
#     QUE HACE ESTE SCRIPT
#     Cada hallazgo principal se vuelve a probar bajo tres disenos restringidos:
#
#       1. PUBLICO EMPAREJADO: solo libros de comparacion escritos para ninos o
#          jovenes.
#       2. SOLO ESPANOL ORIGINAL: solo libros de comparacion escritos en espanol,
#          sin paso de traduccion.
#       3. UN LIBRO POR AUTOR: un libro elegido al azar por cada autor de
#          comparacion, repetido muchas veces, de modo que ningun autor quede
#          sobrerrepresentado. Los resultados se resumen entre las repeticiones.
#
#     Un hallazgo que sobrevive a los tres es robusto a la composicion del corpus.
#     Un hallazgo que aparece solo en el corpus completo es una afirmacion sobre
#     como se armo el grupo de comparacion, no sobre Papelucho.
#
#     QUE ESTE SCRIPT NO PUEDE HACER
#     El diseno 2 deja muy pocos libros de comparacion. Sus resultados se reportan
#     con ese tamano muestral adjunto y deben leerse solo como indicativos.
#     Ninguna restriccion puede rescatar una comparacion que nunca fue apropiada;
#     si los hallazgos no sobreviven, hay que reconstruir el corpus, y esa es una
#     decision del analista, no de este script.
#
# OUTPUT / SALIDA
#   outputs/tables/09_sensitivity_*.csv|.tex
#   outputs/figures/09_sensitivity_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("09_sensitivity: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})

set.seed(PARAMS$seed)

# =============================================================================
# 1. Assemble the headline metrics from earlier steps
# =============================================================================

metadata <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, series, audience,
                original_language, translated, n_tokens_running)
invisible(gc(verbose = FALSE))

load_if_present <- function(file, cols) {
  path <- file.path(PATHS$derived, file)
  if (!file.exists(path)) {
    log_msg("  NOTE: ", file, " not found; its metrics are skipped")
    return(NULL)
  }
  d <- readRDS(path)
  present <- intersect(cols, names(d))
  if (length(present) == 0) return(NULL)
  d %>% dplyr::select(book_id, dplyr::all_of(present))
}

lexical <- load_if_present("lexical_controlled.rds",
                           c("TTR", "MTLD", "MATTR", "Hapax_ratio", "Shannon_H"))

readability <- load_if_present("readability.rds",
                               c("words_per_sentence", "letters_per_word",
                                 "syllables_per_word", "Fernandez_Huerta",
                                 "Szigriszt_Pazos", "Gutierrez_Polini", "Mu_index"))

# EN: Every part-of-speech category that separated the corpora in step 04 must
#     be carried into the sensitivity analysis, including the coordinating and
#     subordinating conjunctions. An earlier version of this list omitted CCONJ,
#     which is the single strongest finding in the project (perfect separation),
#     so the one result most in need of a robustness check was the one not
#     getting it.
# ES: Toda categoria morfosintactica que haya separado los corpus en el paso 04
#     debe pasar al analisis de sensibilidad, incluidas las conjunciones
#     coordinantes y subordinantes. Una version anterior de esta lista omitia
#     CCONJ, que es el hallazgo mas fuerte del proyecto (separacion perfecta), asi
#     que el resultado que mas necesitaba chequeo de robustez era justamente el
#     que no lo recibia.
pos <- load_if_present("pos_profiles.rds",
                       c("CCONJ", "SCONJ", "PRON", "VERB", "NOUN", "ADJ", "ADV",
                         "DET", "ADP", "PROPN", "lexical_density"))

sentiment <- load_if_present("sentiment.rds",
                             c("mean_sentiment", "sd_sentiment",
                               "sentiment_range", "pct_negative_chunks"))

emotions <- load_if_present("emotions.rds",
                            c("joy", "fear", "sadness", "trust", "anger",
                              "emotion_density", "valence_ratio"))

combined <- metadata
for (blk in list(lexical, readability, pos, sentiment, emotions)) {
  if (!is.null(blk)) combined <- dplyr::left_join(combined, blk, by = "book_id")
}

METRICS <- setdiff(
  names(combined),
  c("book_id", "group", "title_es", "author", "series", "audience",
    "original_language", "translated", "n_tokens_running")
)

log_msg("  ", length(METRICS), " metrics assembled from ",
        sum(!vapply(list(lexical, readability, pos, sentiment, emotions),
                    is.null, logical(1))), " analysis steps")

if (length(METRICS) == 0) {
  stop("No metrics available. Run steps 02 to 06 before this script.", call. = FALSE)
}

saveRDS(combined, file.path(PATHS$derived, "all_metrics.rds"))

# =============================================================================
# 2. Design 0: full corpus (reference)
# =============================================================================

run_design <- function(data, design_name) {
  n_focus <- sum(data$group == GROUPS$focus)
  n_comp  <- sum(data$group == GROUPS$comparison)
  if (n_focus < 3 || n_comp < 3) {
    log_msg("  design '", design_name, "' skipped: ", n_focus, " vs ", n_comp, " books")
    return(NULL)
  }
  compare_many(
    data, METRICS,
    focus = GROUPS$focus, comparison = GROUPS$comparison,
    adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
    seed = PARAMS$seed
  ) %>%
    dplyr::mutate(design = design_name,
                  n_focus = n_focus, n_comparison = n_comp)
}

log_msg("  design 0: full corpus")
design_full <- run_design(combined, "full corpus")

# =============================================================================
# 3. Design 1: audience-matched
# =============================================================================

audience_matched <- combined %>%
  dplyr::filter(
    group == GROUPS$focus |
      (group == GROUPS$comparison & audience %in% c("children", "young_adult"))
  )

log_msg("  design 1: audience-matched (", sum(audience_matched$group == GROUPS$comparison),
        " comparison books)")
design_audience <- run_design(audience_matched, "audience-matched")

# =============================================================================
# 4. Design 2: original Spanish only
# =============================================================================

spanish_only <- combined %>%
  dplyr::filter(
    group == GROUPS$focus |
      (group == GROUPS$comparison & !translated)
  )

log_msg("  design 2: original Spanish only (",
        sum(spanish_only$group == GROUPS$comparison), " comparison books)")
design_spanish <- run_design(spanish_only, "original Spanish only")

# =============================================================================
# 5. Design 3: one book per author, repeated
# =============================================================================
# EN: A single random draw of one book per author would itself be arbitrary, so
#     the draw is repeated and the results summarised. Reported for each metric:
#     the proportion of draws in which it was significant, and the median effect
#     size across draws. A metric significant in, say, 95 percent of draws is
#     robust to which book each author contributed; one significant in 40 percent
#     is not.
# ES: Un solo sorteo de un libro por autor seria en si arbitrario, asi que el
#     sorteo se repite y los resultados se resumen. Se reporta para cada metrica
#     la proporcion de sorteos en que resulto significativa y la mediana del
#     tamano de efecto entre sorteos. Una metrica significativa en, digamos, el
#     95 por ciento de los sorteos es robusta a que libro aporto cada autor; una
#     significativa en el 40 por ciento no lo es.

N_AUTHOR_DRAWS <- 200L

comparison_authors <- combined %>%
  dplyr::filter(group == GROUPS$comparison) %>%
  dplyr::distinct(author) %>%
  dplyr::pull(author)

log_msg("  design 3: one book per author (", length(comparison_authors),
        " distinct authors), ", N_AUTHOR_DRAWS, " draws")

# EN: A lighter bootstrap for the effect-size CI inside each draw, since the CI
#     is not what the summary reports and 200 draws multiply the cost.
# ES: Un bootstrap mas liviano para el IC del tamano de efecto dentro de cada
#     sorteo, ya que el IC no es lo que reporta el resumen y 200 sorteos
#     multiplican el costo.
draws <- purrr::map_dfr(seq_len(N_AUTHOR_DRAWS), function(d) {

  picked <- combined %>%
    dplyr::filter(group == GROUPS$comparison) %>%
    dplyr::group_by(author) %>%
    dplyr::slice_sample(n = 1) %>%
    dplyr::ungroup()

  subset_d <- dplyr::bind_rows(
    combined %>% dplyr::filter(group == GROUPS$focus),
    picked
  )

  if (d %% 50 == 0) log_msg("    draw ", d, "/", N_AUTHOR_DRAWS)

  compare_many(
    subset_d, METRICS,
    focus = GROUPS$focus, comparison = GROUPS$comparison,
    adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
    n_boot = 200L, seed = PARAMS$seed + d
  ) %>%
    dplyr::mutate(draw = d)
})

design_author <- draws %>%
  dplyr::group_by(metric) %>%
  dplyr::summarise(
    n_draws              = dplyr::n(),
    prop_significant     = mean(significant, na.rm = TRUE),
    median_cliffs_delta  = stats::median(cliffs_delta, na.rm = TRUE),
    delta_q1             = stats::quantile(cliffs_delta, 0.25, na.rm = TRUE),
    delta_q3             = stats::quantile(cliffs_delta, 0.75, na.rm = TRUE),
    median_p_adjusted    = stats::median(p_adjusted, na.rm = TRUE),
    prop_higher_in_focus = mean(higher_in == GROUPS$focus, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    design = "one book per author",
    n_focus = sum(combined$group == GROUPS$focus),
    n_comparison = length(comparison_authors),
    robust = prop_significant >= 0.95
  )

# =============================================================================
# 6. Combine and judge
# =============================================================================

designs <- dplyr::bind_rows(
  design_full, design_audience, design_spanish
) %>%
  dplyr::select(design, metric, n_focus, n_comparison,
                median_focus, median_comparison, cliffs_delta,
                delta_lower, delta_upper, delta_magnitude,
                p_adjusted, significant, higher_in)

summary_table <- designs %>%
  dplyr::select(design, metric, cliffs_delta, p_adjusted, significant, higher_in) %>%
  tidyr::pivot_wider(
    names_from = design,
    values_from = c(cliffs_delta, p_adjusted, significant, higher_in)
  ) %>%
  dplyr::left_join(
    design_author %>%
      dplyr::select(metric,
                    author_prop_significant = prop_significant,
                    author_median_delta = median_cliffs_delta,
                    author_robust = robust),
    by = "metric"
  )

# EN: The verdict column is the practical output of this script. A metric is
#     called robust only when it survives every design that had enough books to
#     be tested. Designs skipped for lack of data do not count against it, but
#     they do not count for it either, and the verdict text says which is which.
# ES: La columna de veredicto es la salida practica de este script. Una metrica
#     se declara robusta solo si sobrevive a todos los disenos que tuvieron
#     libros suficientes para probarse. Los disenos omitidos por falta de datos
#     no cuentan en contra, pero tampoco a favor, y el texto del veredicto dice
#     cual es cual.
sig_col <- function(nm) {
  if (nm %in% names(summary_table)) summary_table[[nm]] else rep(NA, nrow(summary_table))
}
dir_col <- function(nm) {
  if (nm %in% names(summary_table)) as.character(summary_table[[nm]])
  else rep(NA_character_, nrow(summary_table))
}
eff_col <- function(nm) {
  if (nm %in% names(summary_table)) as.numeric(summary_table[[nm]])
  else rep(NA_real_, nrow(summary_table))
}

summary_table <- summary_table %>%
  dplyr::mutate(
    sig_full     = sig_col("significant_full corpus"),
    sig_audience = sig_col("significant_audience-matched"),
    sig_spanish  = sig_col("significant_original Spanish only"),
    n_designs_tested = rowSums(!is.na(cbind(sig_full, sig_audience, sig_spanish))) +
      as.integer(!is.na(author_prop_significant)),
    n_designs_significant = rowSums(cbind(sig_full, sig_audience, sig_spanish),
                                    na.rm = TRUE) +
      as.integer(!is.na(author_robust) & author_robust),
    # EN: Significance and effect size have to be judged separately here. The
    #     original-Spanish design has only three comparison books, so with
    #     n = 12 against n = 3 the smallest attainable p-value cannot clear a
    #     Holm-corrected threshold across a family of this size, no matter how
    #     large the true difference is. A metric that keeps a large effect in the
    #     same direction under that design has not failed; it has simply run out
    #     of statistical power. Calling that "fragile" would be wrong, and would
    #     invite exactly the mistake this whole script exists to prevent.
    # ES: La significancia y el tamano de efecto hay que juzgarlos por separado
    #     aca. El diseno de espanol original tiene solo tres libros de
    #     comparacion, asi que con n = 12 contra n = 3 el menor p alcanzable no
    #     puede superar un umbral corregido por Holm en una familia de este
    #     tamano, por grande que sea la diferencia real. Una metrica que conserva
    #     un efecto grande en la misma direccion bajo ese diseno no fracaso;
    #     simplemente se quedo sin potencia estadistica. Llamar a eso "fragil"
    #     seria incorrecto e invitaria justo al error que este script existe para
    #     evitar.
    dir_full     = dir_col("higher_in_full corpus"),
    dir_audience = dir_col("higher_in_audience-matched"),
    dir_spanish  = dir_col("higher_in_original Spanish only"),
    eff_audience = eff_col("cliffs_delta_audience-matched"),
    eff_spanish  = eff_col("cliffs_delta_original Spanish only"),
    eff_full     = eff_col("cliffs_delta_full corpus"),

    direction_stable = !is.na(dir_full) &
      (is.na(dir_audience) | dir_audience == dir_full) &
      (is.na(dir_spanish)  | dir_spanish  == dir_full),

    # "At least small" on Cliff's delta is |d| >= 0.147.
    effect_holds = !is.na(eff_full) &
      (is.na(eff_audience) | abs(eff_audience) >= 0.147) &
      (is.na(eff_spanish)  | abs(eff_spanish)  >= 0.147),

    verdict = dplyr::case_when(
      is.na(sig_full) ~ "not tested",
      !sig_full ~ "not significant on the full corpus",
      n_designs_significant == n_designs_tested ~
        "robust: significant under every design tested",
      direction_stable & effect_holds &
        !is.na(sig_audience) & sig_audience &
        !is.na(author_robust) & author_robust ~
        "robust: direction and effect size stable; the Spanish-only design is underpowered, not contradictory",
      direction_stable & effect_holds ~
        "supported: direction and effect size stable across designs, significance limited by sample size",
      !direction_stable ~
        "fragile: direction reverses under a restricted design; likely a corpus-composition effect",
      n_designs_significant <= 1 ~
        "fragile: significant only on the full corpus, likely a corpus-composition effect",
      TRUE ~ "partial: survives some restricted designs but not all"
    )
  )

# =============================================================================
# 7. Figures
# =============================================================================

fig_data <- designs %>%
  dplyr::filter(!is.na(cliffs_delta)) %>%
  dplyr::mutate(
    design = factor(design, levels = c("full corpus", "audience-matched",
                                       "original Spanish only"))
  )

fig_sens <- ggplot(fig_data,
                   aes(x = cliffs_delta, y = stats::reorder(metric, cliffs_delta),
                       colour = design)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = delta_lower, xmax = delta_upper),
                 height = 0, linewidth = 0.4,
                 position = position_dodge(width = 0.65), alpha = 0.6) +
  geom_point(aes(shape = significant), size = 2.2,
             position = position_dodge(width = 0.65)) +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 1),
                     labels = c("TRUE" = "Significant", "FALSE" = "Not significant")) +
  scale_colour_manual(values = c("full corpus" = "grey35",
                                 "audience-matched" = "#00A499",
                                 "original Spanish only" = "#C4622D")) +
  scale_x_continuous(limits = c(-1, 1)) +
  labs(x = "Cliff's delta (positive: higher in Papelucho)", y = NULL,
       colour = "Design", shape = NULL) +
  theme_papelucho(base_size = 10)

save_figure(fig_sens, "09_sensitivity_designs", width = 11,
            height = max(6, 0.28 * length(METRICS) + 2))

fig_author <- design_author %>%
  ggplot(aes(x = prop_significant,
             y = stats::reorder(metric, prop_significant))) +
  geom_vline(xintercept = 0.95, colour = "#00A499", linetype = "dashed",
             linewidth = 0.5) +
  geom_segment(aes(x = 0, xend = prop_significant,
                   yend = stats::reorder(metric, prop_significant)),
               colour = "grey70", linewidth = 0.4) +
  geom_point(aes(colour = robust), size = 2.6) +
  scale_colour_manual(values = c("TRUE" = "#00A499", "FALSE" = "grey55"),
                      labels = c("TRUE" = "Robust", "FALSE" = "Not robust")) +
  scale_x_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(x = paste0("Proportion of ", N_AUTHOR_DRAWS,
                  " one-book-per-author draws in which the metric is significant"),
       y = NULL, colour = NULL) +
  theme_papelucho(base_size = 10)

save_figure(fig_author, "09_sensitivity_author_draws", width = 10,
            height = max(5, 0.26 * length(METRICS) + 2))

# =============================================================================
# 8. Export
# =============================================================================

export_results(
  designs, "09_sensitivity_by_design",
  caption_en = "Group comparisons under three corpus designs: the full corpus, comparison books matched on target audience, and comparison books originally written in Spanish.",
  caption_es = "Comparaciones entre grupos bajo tres disenos de corpus: el corpus completo, libros de comparacion emparejados por publico objetivo, y libros de comparacion escritos originalmente en espanol.",
  label = "sensitivity-designs",
  note_en = "Each design applies Holm correction across its own family of tests.",
  note_es = "Cada diseno aplica correccion de Holm sobre su propia familia de pruebas."
)

export_table(
  design_author, "09_sensitivity_author_draws",
  caption_en = sprintf("Stability of each finding across %d draws of one randomly chosen book per comparison author.",
                       N_AUTHOR_DRAWS),
  caption_es = sprintf("Estabilidad de cada hallazgo a lo largo de %d sorteos de un libro elegido al azar por cada autor de comparacion.",
                       N_AUTHOR_DRAWS),
  label = "sensitivity-author",
  note_en = "A metric is marked robust when it reaches significance in at least 95 percent of draws.",
  note_es = "Una metrica se marca como robusta cuando alcanza significancia en al menos el 95 por ciento de los sorteos."
)

export_table(
  summary_table %>%
    dplyr::select(metric, dplyr::starts_with("cliffs_delta_"),
                  author_median_delta, author_prop_significant,
                  direction_stable, effect_holds,
                  n_designs_tested, n_designs_significant, verdict),
  "09_sensitivity_summary",
  caption_en = "Robustness of each finding to corpus composition.",
  caption_es = "Robustez de cada hallazgo frente a la composicion del corpus.",
  label = "sensitivity-summary",
  note_en = "A finding marked fragile is a statement about how the comparison corpus was assembled rather than about the Papelucho series.",
  note_es = "Un hallazgo marcado como fragil es una afirmacion sobre como se armo el corpus de comparacion y no sobre la serie Papelucho."
)

composition <- combined %>%
  dplyr::filter(group == GROUPS$comparison) %>%
  dplyr::summarise(
    n_books = dplyr::n(),
    n_authors = dplyr::n_distinct(author),
    largest_author_share = max(table(author)) / dplyr::n(),
    pct_translated = 100 * mean(translated),
    pct_adult = 100 * mean(audience == "adult"),
    pct_children_or_ya = 100 * mean(audience %in% c("children", "young_adult"))
  )

write_table_csv(composition, "09_comparison_corpus_composition")
write_table_csv(draws, "09_author_draws_raw")

# =============================================================================
# 9. Console summary
# =============================================================================

log_msg("  comparison corpus composition:")
print(as.data.frame(composition), row.names = FALSE)

log_msg("  robustness verdicts:")
print(as.data.frame(
  summary_table %>%
    dplyr::select(metric, n_designs_tested, n_designs_significant, verdict) %>%
    dplyr::arrange(verdict, metric)
), row.names = FALSE)

n_robust    <- sum(grepl("^robust",    summary_table$verdict))
n_supported <- sum(grepl("^supported", summary_table$verdict))
n_fragile   <- sum(grepl("^fragile",   summary_table$verdict))
log_msg("  ", n_robust, " robust, ", n_supported, " supported, ",
        n_fragile, " fragile, of ", nrow(summary_table), " metrics")

# EN: Explicit note on the power limitation, printed so it cannot be missed.
# ES: Nota explicita sobre la limitacion de potencia, impresa para que no pase
#     desapercibida.
n_sp <- sum(spanish_only$group == GROUPS$comparison)
log_msg("  NOTE: the original-Spanish design compares ",
        sum(combined$group == GROUPS$focus), " books against ", n_sp,
        ". At that size, direction and effect size are informative but ",
        "significance is not attainable after correction.")

write_session_info("09_sensitivity")
log_msg("09_sensitivity: done")
