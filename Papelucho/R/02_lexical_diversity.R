# =============================================================================
# 02_lexical_diversity.R
# -----------------------------------------------------------------------------
# EN: Lexical diversity with an explicit control for text length.
#
#     THE PROBLEM / WHY THIS SCRIPT LOOKS THE WAY IT DOES
#     Almost every classical measure of lexical richness falls as a text grows,
#     because an author reuses vocabulary faster than they introduce new words.
#     The type-token ratio of a 20,000-word text is not comparable to that of a
#     100,000-word text in any meaningful sense: the difference is arithmetic,
#     not stylistic. In this corpus the median Papelucho book has about 19,000
#     running tokens and the median comparison novel about 102,000, a ratio of
#     more than five to one. Comparing raw TTR across those groups measures book
#     length and reports it as a finding about style.
#
#     THE SOLUTION
#     Every length-sensitive index is computed on random samples of a fixed
#     number of tokens, drawn without replacement from each book and repeated
#     PARAMS$n_replicates times. Because every book contributes samples of
#     identical size, the length confound is removed by construction rather than
#     adjusted for after the fact. Raw whole-text values are also reported side
#     by side so the size of the artefact is visible.
#
#     Two indices are reported without resampling. MTLD and MATTR are designed
#     to be stable across text lengths, so their whole-text values are already
#     comparable; they are still resampled here as a consistency check, and
#     agreement between the resampled and whole-text versions is evidence that
#     the resampling is behaving as intended.
#
# ES: Diversidad lexica con control explicito del largo del texto.
#
#     EL PROBLEMA / POR QUE ESTE SCRIPT ES ASI
#     Casi toda medida clasica de riqueza lexica baja cuando el texto crece,
#     porque un autor reutiliza vocabulario mas rapido de lo que introduce
#     palabras nuevas. La razon tipo-token de un texto de 20.000 palabras no es
#     comparable con la de uno de 100.000 en ningun sentido util: la diferencia
#     es aritmetica, no estilistica. En este corpus el libro mediano de
#     Papelucho tiene unos 19.000 tokens corrientes y la novela mediana de
#     comparacion unos 102.000, una razon de mas de cinco a uno. Comparar TTR
#     cruda entre esos grupos mide el largo del libro y lo reporta como un
#     hallazgo sobre estilo.
#
#     LA SOLUCION
#     Todo indice sensible al largo se calcula sobre muestras aleatorias de un
#     numero fijo de tokens, extraidas sin reemplazo de cada libro y repetidas
#     PARAMS$n_replicates veces. Como cada libro aporta muestras de tamano
#     identico, el confundido de largo se elimina por construccion en vez de
#     ajustarse despues. Los valores crudos de texto completo tambien se
#     reportan al lado para que el tamano del artefacto quede a la vista.
#
#     Dos indices se reportan sin remuestreo. MTLD y MATTR estan disenados para
#     ser estables ante el largo, asi que sus valores de texto completo ya son
#     comparables; igual se remuestrean como chequeo de consistencia, y la
#     concordancia entre la version remuestreada y la de texto completo es
#     evidencia de que el remuestreo se comporta como corresponde.
#
# OUTPUT / SALIDA
#   outputs/tables/02_lexical_*.csv|.tex
#   outputs/figures/02_lexical_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("02_lexical_diversity: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(zoo)
})

# EN: Only the columns this analysis needs are kept. The full corpus object
#     holds four copies of every book's text plus three token streams, about
#     390 MB in total, and carrying that through the resampling loop wastes
#     memory that the replicates need.
# ES: Solo se conservan las columnas que este analisis necesita. El objeto de
#     corpus completo guarda cuatro copias del texto de cada libro mas tres
#     flujos de tokens, unos 390 MB en total, y arrastrar eso por el bucle de
#     remuestreo desperdicia memoria que necesitan las replicas.
corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author,
                tokens_content, n_tokens_content, n_tokens_running)
invisible(gc(verbose = FALSE))

set.seed(PARAMS$seed)

# =============================================================================
# 1. Index definitions
# =============================================================================

#' Type-token ratio
#' EN: types / tokens. The most direct measure and the most length-dependent.
#' ES: tipos / tokens. La medida mas directa y la mas dependiente del largo.
ttr <- function(x) dplyr::n_distinct(x) / length(x)

#' Guiraud's root type-token ratio
#' EN: types / sqrt(tokens). Divides by the square root to slow the decay with
#'     length, but does not remove it.
#' ES: tipos / sqrt(tokens). Divide por la raiz para frenar la caida con el
#'     largo, pero no la elimina.
rttr <- function(x) dplyr::n_distinct(x) / sqrt(length(x))

#' Carroll's corrected type-token ratio
cttr <- function(x) dplyr::n_distinct(x) / sqrt(2 * length(x))

#' Herdan's C
#' EN: log(types) / log(tokens). Bounded roughly in [0, 1] and mildly
#'     length-dependent.
#' ES: log(tipos) / log(tokens). Acotado aproximadamente en [0, 1] y levemente
#'     dependiente del largo.
herdan_c <- function(x) {
  n <- length(x); v <- dplyr::n_distinct(x)
  if (n <= 1 || v <= 1) return(NA_real_)
  log(v) / log(n)
}

#' Maas's a2
#' EN: (log N - log V) / (log N)^2. Lower values mean richer vocabulary, the
#'     opposite direction to every other index here, which is why the sign is
#'     flipped when the results table reports which group scores higher.
#' ES: (log N - log V) / (log N)^2. Valores mas bajos indican vocabulario mas
#'     rico, direccion opuesta a todos los demas indices, por lo que el signo se
#'     invierte cuando la tabla de resultados reporta que grupo puntua mas alto.
maas_a2 <- function(x) {
  n <- length(x); v <- dplyr::n_distinct(x)
  if (n <= 1 || v <= 1) return(NA_real_)
  (log(n) - log(v)) / (log(n)^2)
}

#' Moving-average type-token ratio
#' EN: Mean TTR over every window of `window` consecutive tokens. Because each
#'     window has identical size, MATTR is close to length-invariant.
#'
#'     Implemented in linear time rather than by evaluating each window
#'     separately. A token at position i is a new type inside the window
#'     starting at s exactly when its previous occurrence lies before s. Each
#'     token therefore contributes to a contiguous range of window positions,
#'     which a difference array accumulates in one pass. The result is identical
#'     to the naive rolling computation, verified against it on samples from
#'     this corpus, and about 250 times faster, which is what makes 30
#'     replicates per book feasible.
#' ES: TTR media sobre cada ventana de `window` tokens consecutivos. Como todas
#'     las ventanas tienen el mismo tamano, MATTR es casi invariante al largo.
#'
#'     Implementada en tiempo lineal en vez de evaluar cada ventana por
#'     separado. Un token en la posicion i es un tipo nuevo dentro de la ventana
#'     que empieza en s exactamente cuando su ocurrencia anterior queda antes de
#'     s. Por lo tanto cada token contribuye a un rango contiguo de posiciones
#'     de ventana, que un arreglo de diferencias acumula en una sola pasada. El
#'     resultado es identico al calculo rodante ingenuo, verificado contra el en
#'     muestras de este corpus, y unas 250 veces mas rapido, que es lo que
#'     vuelve factibles 30 replicas por libro.
mattr <- function(x, window = 50L) {

  n <- length(x)
  if (n < window) return(NA_real_)

  code <- match(x, unique(x))

  # prev[i]: index of the previous occurrence of the same type, 0 if first.
  last <- integer(max(code))
  prev <- integer(n)
  for (i in seq_len(n)) {
    prev[i] <- last[code[i]]
    last[code[i]] <- i
  }

  n_win <- n - window + 1L

  # Token i counts as new for every window start s with
  #   max(prev[i] + 1, i - window + 1) <= s <= min(i, n_win)
  lo <- pmax(prev + 1L, seq_len(n) - window + 1L, 1L)
  hi <- pmin(seq_len(n), n_win)
  keep <- lo <= hi
  lo <- lo[keep]
  hi <- hi[keep]

  d <- numeric(n_win + 2L)
  for (k in seq_along(lo)) {
    d[lo[k]]      <- d[lo[k]] + 1
    d[hi[k] + 1L] <- d[hi[k] + 1L] - 1
  }

  mean(cumsum(d)[seq_len(n_win)] / window)
}

#' Measure of textual lexical diversity
#'
#' EN: MTLD is the mean number of tokens a text sustains before its running TTR
#'     drops below a threshold. The canonical definition (McCarthy & Jarvis,
#'     2010) requires the mean of a forward and a backward pass; running only
#'     one direction, as the original script did, biases the estimate because
#'     the trailing partial factor is counted asymmetrically.
#'
#'     The partial factor at the end of a pass is weighted by how far the
#'     running TTR had travelled towards the threshold, which is what makes the
#'     index continuous rather than a step function of text length.
#'
#' ES: MTLD es el numero medio de tokens que un texto sostiene antes de que su
#'     TTR corriente caiga bajo un umbral. La definicion canonica (McCarthy y
#'     Jarvis, 2010) exige la media de una pasada hacia adelante y una hacia
#'     atras; correr una sola direccion, como hacia el script original, sesga la
#'     estimacion porque el factor parcial final se cuenta de forma asimetrica.
#'
#'     El factor parcial al final de cada pasada se pondera por cuanto habia
#'     avanzado la TTR corriente hacia el umbral, que es lo que vuelve al indice
#'     continuo en vez de una funcion escalonada del largo del texto.
mtld_pass <- function(x, threshold = 0.72) {

  n <- length(x)
  if (n == 0) return(NA_real_)

  # Types are tracked with a generation stamp rather than by clearing a set at
  # every factor boundary, so resetting is constant time. Verified to give
  # values identical to the direct implementation.
  code  <- match(x, unique(x))
  stamp <- integer(max(code))
  gen   <- 0L

  factors     <- 0
  n_types     <- 0L
  count       <- 0L
  current_ttr <- 1

  for (i in seq_len(n)) {
    ci    <- code[i]
    count <- count + 1L
    if (stamp[ci] != gen + 1L) {
      stamp[ci] <- gen + 1L
      n_types   <- n_types + 1L
    }
    current_ttr <- n_types / count
    if (current_ttr <= threshold) {
      factors     <- factors + 1
      gen         <- gen + 1L
      n_types     <- 0L
      count       <- 0L
      current_ttr <- 1
    }
  }

  # Partial factor: proportion of the way the final incomplete segment
  # travelled from a TTR of 1 down to the threshold.
  if (count > 0) {
    factors <- factors + (1 - current_ttr) / (1 - threshold)
  }

  if (factors <= 0) return(NA_real_)
  n / factors
}

mtld <- function(x, threshold = 0.72) {
  fwd <- mtld_pass(x, threshold)
  bwd <- mtld_pass(rev(x), threshold)
  mean(c(fwd, bwd), na.rm = TRUE)
}

#' Yule's K
#' EN: A characteristic constant of vocabulary repetition. Higher values mean
#'     more repetition. Yule designed it to be independent of text length, and
#'     it is the only classical index for which that claim broadly holds.
#' ES: Una constante caracteristica de la repeticion de vocabulario. Valores mas
#'     altos indican mas repeticion. Yule lo diseno para ser independiente del
#'     largo, y es el unico indice clasico para el que esa afirmacion se
#'     sostiene en general.
yule_k <- function(x) {
  f <- table(x)
  n <- sum(f)
  if (n <= 1) return(NA_real_)
  10000 * (sum(f^2) - n) / (n^2)
}

#' Simpson's D
#' EN: Probability that two tokens drawn at random are the same type.
#' ES: Probabilidad de que dos tokens tomados al azar sean del mismo tipo.
simpson_d <- function(x) {
  f <- table(x)
  n <- sum(f)
  if (n <= 1) return(NA_real_)
  sum(f * (f - 1)) / (n * (n - 1))
}

#' Shannon's H
#' EN: Entropy of the type distribution in nats. Grows with vocabulary size and
#'     is therefore strongly length-dependent.
#' ES: Entropia de la distribucion de tipos en nats. Crece con el tamano de
#'     vocabulario y por lo tanto depende fuertemente del largo.
shannon_h <- function(x) {
  p <- table(x) / length(x)
  -sum(p * log(p))
}

#' Hapax legomena ratio
#' EN: Share of types occurring exactly once, relative to total types.
#' ES: Proporcion de tipos que aparecen exactamente una vez, sobre el total de
#'     tipos.
hapax_ratio <- function(x) {
  f <- table(x)
  if (length(f) == 0) return(NA_real_)
  sum(f == 1) / length(f)
}

# =============================================================================
# 2. Compute all indices on one token vector
# =============================================================================

compute_indices <- function(x, mattr_window = PARAMS$mattr_window,
                            mtld_threshold = PARAMS$mtld_threshold) {
  tibble::tibble(
    tokens      = length(x),
    types       = dplyr::n_distinct(x),
    TTR         = ttr(x),
    RTTR        = rttr(x),
    CTTR        = cttr(x),
    Herdan_C    = herdan_c(x),
    Maas        = maas_a2(x),
    MATTR       = mattr(x, window = mattr_window),
    MTLD        = mtld(x, threshold = mtld_threshold),
    Yule_K      = yule_k(x),
    Simpson_D   = simpson_d(x),
    Shannon_H   = shannon_h(x),
    Hapax_ratio = hapax_ratio(x)
  )
}

INDEX_NAMES <- c("TTR", "RTTR", "CTTR", "Herdan_C", "Maas", "MATTR",
                 "MTLD", "Yule_K", "Simpson_D", "Shannon_H", "Hapax_ratio")

# EN: Indices where a lower value means richer vocabulary. Recorded explicitly
#     so the "higher in" column in the results table can be read correctly
#     without the reader needing to remember each index's direction.
# ES: Indices donde un valor mas bajo significa vocabulario mas rico. Se
#     registran de forma explicita para que la columna "higher in" de la tabla
#     de resultados se lea bien sin que el lector deba recordar la direccion de
#     cada indice.
LOWER_IS_RICHER <- c("Maas", "Yule_K", "Simpson_D")

# =============================================================================
# 3. Whole-text values (uncontrolled, reported for contrast)
# =============================================================================

log_msg("  computing whole-text indices (length-confounded, for contrast)")

whole_text <- corpus %>%
  dplyr::select(book_id, group, title_es, author, tokens_content) %>%
  dplyr::mutate(idx = purrr::map(tokens_content, compute_indices)) %>%
  dplyr::select(-tokens_content) %>%
  tidyr::unnest(idx)

# =============================================================================
# 4. Length-controlled values
# =============================================================================
# EN: Books shorter than the sample size cannot contribute a sample of that
#     size, so the sample size is set to the length of the shortest book in the
#     corpus if that is below PARAMS$sample_size. This keeps every book in the
#     analysis. Dropping short books instead would remove exactly the books the
#     study is about, since the Papelucho titles are the shortest in the corpus.
# ES: Los libros mas cortos que el tamano de muestra no pueden aportar una
#     muestra de ese tamano, asi que el tamano de muestra se fija al largo del
#     libro mas corto del corpus si este queda bajo PARAMS$sample_size. Asi
#     ningun libro sale del analisis. Descartar los libros cortos eliminaria
#     justamente los libros que el estudio estudia, ya que los titulos de
#     Papelucho son los mas cortos del corpus.

min_content_tokens <- min(corpus$n_tokens_content)
sample_size <- min(PARAMS$sample_size, min_content_tokens)

if (sample_size < PARAMS$sample_size) {
  log_msg("  sample size reduced from ", PARAMS$sample_size, " to ", sample_size,
          " tokens: shortest book has ", min_content_tokens, " content tokens")
} else {
  log_msg("  sample size: ", sample_size, " content tokens per replicate")
}

# EN: Explicit confirmation that no book is excluded by the sampling design.
# ES: Confirmacion explicita de que ningun libro queda excluido por el diseno de
#     muestreo.
stopifnot(all(corpus$n_tokens_content >= sample_size))

log_msg("  drawing ", PARAMS$n_replicates, " replicates per book (",
        nrow(corpus), " books)")

resample_book <- function(tokens, n_rep, size) {
  purrr::map_dfr(seq_len(n_rep), function(r) {
    idx <- sample.int(length(tokens), size = size, replace = FALSE)
    compute_indices(tokens[sort(idx)]) %>%
      dplyr::mutate(replicate = r, .before = 1)
  })
}

replicates <- corpus %>%
  dplyr::select(book_id, group, title_es, author, tokens_content) %>%
  dplyr::mutate(
    reps = purrr::map(tokens_content, ~ resample_book(.x, PARAMS$n_replicates, sample_size))
  ) %>%
  dplyr::select(-tokens_content) %>%
  tidyr::unnest(reps)

# EN: Aggregate replicates to one value per book. The mean across replicates is
#     the length-controlled estimate; the standard deviation quantifies sampling
#     uncertainty and is reported so a reader can judge whether the number of
#     replicates was sufficient.
# ES: Se agregan las replicas a un valor por libro. La media entre replicas es
#     la estimacion controlada por largo; la desviacion estandar cuantifica la
#     incertidumbre de muestreo y se reporta para que el lector pueda juzgar si
#     el numero de replicas fue suficiente.
controlled <- replicates %>%
  dplyr::group_by(book_id, group, title_es, author) %>%
  dplyr::summarise(
    dplyr::across(dplyr::all_of(INDEX_NAMES),
                  list(mean = ~ mean(.x, na.rm = TRUE),
                       sd   = ~ stats::sd(.x, na.rm = TRUE)),
                  .names = "{.col}__{.fn}"),
    .groups = "drop"
  )

controlled_means <- controlled %>%
  dplyr::select(book_id, group, title_es, author, dplyr::ends_with("__mean")) %>%
  dplyr::rename_with(~ sub("__mean$", "", .x), dplyr::ends_with("__mean"))

stopifnot(nrow(controlled_means) == nrow(corpus))

# =============================================================================
# 5. Group comparison
# =============================================================================

log_msg("  comparing groups (length-controlled)")

results_controlled <- compare_many(
  controlled_means, INDEX_NAMES,
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(
    analysis = "length-controlled",
    richer_vocabulary_in = dplyr::case_when(
      is.na(higher_in) | higher_in == "tie" ~ higher_in,
      metric %in% LOWER_IS_RICHER ~ ifelse(higher_in == GROUPS$focus,
                                           GROUPS$comparison, GROUPS$focus),
      TRUE ~ higher_in
    )
  )

log_msg("  comparing groups (whole text, for contrast)")

results_whole <- compare_many(
  whole_text, INDEX_NAMES,
  focus = GROUPS$focus, comparison = GROUPS$comparison,
  adjust = PARAMS$p_adjust_method, alpha = PARAMS$alpha,
  seed = PARAMS$seed
) %>%
  dplyr::mutate(analysis = "whole text (length-confounded)")

# EN: Side-by-side contrast. Any index whose direction or significance flips
#     between the two analyses was measuring text length in the whole-text
#     version. This is the table that shows the reader why the control matters.
# ES: Contraste lado a lado. Todo indice cuya direccion o significancia cambia
#     entre los dos analisis estaba midiendo largo de texto en la version de
#     texto completo. Esta es la tabla que le muestra al lector por que importa
#     el control.
contrast <- results_whole %>%
  dplyr::select(metric,
                whole_delta = cliffs_delta, whole_p = p_adjusted,
                whole_higher = higher_in, whole_sig = significant) %>%
  dplyr::left_join(
    results_controlled %>%
      dplyr::select(metric,
                    ctrl_delta = cliffs_delta, ctrl_p = p_adjusted,
                    ctrl_higher = higher_in, ctrl_sig = significant),
    by = "metric"
  ) %>%
  dplyr::mutate(
    direction_flips  = !is.na(whole_higher) & !is.na(ctrl_higher) &
      whole_higher != ctrl_higher,
    significance_flips = whole_sig != ctrl_sig,
    interpretation = dplyr::case_when(
      direction_flips ~
        "Direction reverses once length is controlled: the whole-text result is a length artefact.",
      significance_flips & whole_sig ~
        "Significant only without length control: likely a length artefact.",
      significance_flips & ctrl_sig ~
        "Significant only with length control: length was masking a real difference.",
      TRUE ~ "Stable across both analyses."
    )
  )

# =============================================================================
# 6. Figures
# =============================================================================

plot_data <- controlled_means %>%
  tidyr::pivot_longer(dplyr::all_of(INDEX_NAMES),
                      names_to = "metric", values_to = "value") %>%
  dplyr::mutate(
    metric_label = label_for(metric, "en"),
    group = factor(group, levels = c(GROUPS$focus, GROUPS$comparison))
  )

fig_indices <- ggplot(plot_data, aes(x = group, y = value, colour = group)) +
  geom_boxplot(outlier.shape = NA, width = 0.55, linewidth = 0.45) +
  geom_jitter(width = 0.16, alpha = 0.55, size = 1.5) +
  facet_wrap(~ metric_label, scales = "free_y", ncol = 4) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = NULL, y = "Index value", colour = "Corpus") +
  theme_papelucho(base_size = 11) +
  theme(legend.position = "bottom")

save_figure(fig_indices, "02_lexical_indices_controlled", width = 12, height = 8)

# EN: Length-dependence diagnostic. Plotting each index against book length
#     under both analyses makes the confound visible: a steep slope in the
#     whole-text panel that flattens in the controlled panel is the signature of
#     a length artefact.
# ES: Diagnostico de dependencia del largo. Graficar cada indice contra el largo
#     del libro bajo los dos analisis hace visible el confundido: una pendiente
#     pronunciada en el panel de texto completo que se aplana en el panel
#     controlado es la firma de un artefacto de largo.
length_diag <- dplyr::bind_rows(
  whole_text %>%
    dplyr::select(book_id, group, dplyr::all_of(INDEX_NAMES)) %>%
    dplyr::mutate(analysis = "Whole text"),
  controlled_means %>%
    dplyr::select(book_id, group, dplyr::all_of(INDEX_NAMES)) %>%
    dplyr::mutate(analysis = "Length-controlled")
) %>%
  dplyr::left_join(
    corpus %>% dplyr::select(book_id, n_tokens_content), by = "book_id"
  ) %>%
  tidyr::pivot_longer(dplyr::all_of(INDEX_NAMES),
                      names_to = "metric", values_to = "value") %>%
  dplyr::filter(metric %in% c("TTR", "MTLD", "Shannon_H", "Hapax_ratio")) %>%
  dplyr::mutate(
    metric_label = label_for(metric, "en"),
    analysis = factor(analysis, levels = c("Whole text", "Length-controlled"))
  )

fig_length <- ggplot(length_diag,
                     aes(x = n_tokens_content, y = value, colour = group)) +
  geom_point(alpha = 0.7, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.5, colour = "grey40",
              aes(group = 1), formula = y ~ x) +
  facet_grid(metric_label ~ analysis, scales = "free_y") +
  scale_x_continuous(labels = function(x) format(x, big.mark = ",")) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = "Content tokens per book", y = "Index value", colour = "Corpus") +
  theme_papelucho(base_size = 11)

save_figure(fig_length, "02_lexical_length_dependence", width = 10, height = 9)

# =============================================================================
# 7. Export
# =============================================================================

by_book <- controlled_means %>%
  dplyr::left_join(
    corpus %>% dplyr::select(book_id, n_tokens_content, n_tokens_running),
    by = "book_id"
  ) %>%
  dplyr::arrange(group, book_id)

export_table(
  by_book, "02_lexical_by_book",
  caption_en = sprintf("Length-controlled lexical diversity by book. Each value is the mean over %d random samples of %s content tokens.",
                       PARAMS$n_replicates, format(sample_size, big.mark = ",")),
  caption_es = sprintf("Diversidad lexica controlada por largo, por libro. Cada valor es la media de %d muestras aleatorias de %s tokens de contenido.",
                       PARAMS$n_replicates, format(sample_size, big.mark = ",")),
  label = "lexical-by-book",
  note_en = "Maas, Yule's K and Simpson's D decrease as vocabulary richness increases; all other indices increase.",
  note_es = "Maas, K de Yule y D de Simpson disminuyen cuando aumenta la riqueza de vocabulario; todos los demas indices aumentan."
)

export_results(
  results_controlled, "02_lexical_results_controlled",
  caption_en = "Group comparison of lexical diversity after controlling for text length. Mann-Whitney U tests with Holm correction; Cliff's delta with a bootstrap 95 percent confidence interval.",
  caption_es = "Comparacion entre grupos de la diversidad lexica tras controlar el largo del texto. Pruebas U de Mann-Whitney con correccion de Holm; Cliff's delta con intervalo de confianza bootstrap del 95 por ciento.",
  label = "lexical-controlled",
  note_en = "A result is marked significant only when the adjusted p-value is below 0.05 and the effect size is at least small.",
  note_es = "Un resultado se marca como significativo solo cuando el p ajustado es menor a 0,05 y el tamano de efecto es al menos pequeno."
)

export_results(
  results_whole, "02_lexical_results_wholetext",
  caption_en = "Group comparison of lexical diversity on whole texts, without controlling for length. Reported for contrast only.",
  caption_es = "Comparacion entre grupos de la diversidad lexica sobre textos completos, sin controlar el largo. Se reporta solo para contraste.",
  label = "lexical-wholetext",
  note_en = "These values are confounded with book length and should not be interpreted as stylistic differences.",
  note_es = "Estos valores estan confundidos con el largo del libro y no deben interpretarse como diferencias estilisticas."
)

export_table(
  contrast, "02_lexical_contrast",
  caption_en = "Effect of length control on each lexical diversity index.",
  caption_es = "Efecto del control de largo sobre cada indice de diversidad lexica.",
  label = "lexical-contrast"
)

write_table_csv(whole_text, "02_lexical_wholetext_by_book")
write_table_csv(controlled, "02_lexical_replicate_summary")
saveRDS(controlled_means, file.path(PATHS$derived, "lexical_controlled.rds"))

# =============================================================================
# 8. Console summary
# =============================================================================

log_msg("  length-controlled results:")
print(as.data.frame(
  results_controlled %>%
    dplyr::transmute(
      metric,
      median_pap  = round(median_focus, 4),
      median_comp = round(median_comparison, 4),
      delta       = round(cliffs_delta, 3),
      magnitude   = delta_magnitude,
      p_adj       = format_p(p_adjusted),
      significant,
      richer_in   = richer_vocabulary_in
    )
), row.names = FALSE)

n_flip <- sum(contrast$direction_flips | contrast$significance_flips)
log_msg("  ", n_flip, " of ", nrow(contrast),
        " indices change conclusion once length is controlled")

write_session_info("02_lexical_diversity")
log_msg("02_lexical_diversity: done")
