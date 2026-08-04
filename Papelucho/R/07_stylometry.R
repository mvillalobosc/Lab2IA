# =============================================================================
# 07_stylometry.R
# -----------------------------------------------------------------------------
# EN: Stylometric clustering with Burrows's Delta.
#
#     WHY DELTA REPLACES THE TF-IDF DENDROGRAM
#     The original dendrogram was built on correlation distance over the 500
#     highest TF-IDF terms of the stopword-filtered text. Two problems follow
#     from that choice.
#
#     First, TF-IDF by construction rewards terms that appear in few documents.
#     In a corpus of novels the terms that best satisfy that criterion are
#     character and place names. A clustering built on them recovers which books
#     share a cast, which is why the original dendrogram grouped the Salvatore
#     novels and the Harry Potter novels so cleanly. That is a fact about series
#     membership, not about style, and it would appear identically if every book
#     had been written by the same person.
#
#     Second, removing function words before clustering discards the signal that
#     computational stylistics actually relies on. Authorial style lives in the
#     unconscious, high-frequency choices a writer makes among determiners,
#     prepositions, pronouns and conjunctions, precisely the words a stopword
#     list removes.
#
#     Burrows's Delta is the standard method for this problem. It works on the n
#     most frequent words of the whole corpus, function words included,
#     standardises each word's frequency across documents into a z-score, and
#     measures the mean absolute difference between two documents' z-score
#     vectors. Standardisation means a common word cannot dominate merely by
#     being common, and the restriction to frequent words means topic-specific
#     vocabulary never enters.
#
#     CLUSTER SUPPORT
#     A dendrogram drawn once shows a structure but says nothing about whether
#     that structure is stable. Here every branch is annotated with bootstrap
#     support: the feature set is resampled with replacement PARAMS$n_bootstrap
#     times, the tree is rebuilt each time, and support is the proportion of
#     replicates in which a given group of books stays together. A branch with
#     support below about 70 percent should not be interpreted.
#
#     The TF-IDF analysis is retained as a clearly labelled sensitivity check,
#     since it answers a different and still legitimate question about shared
#     content.
#
# ES: Agrupamiento estilometrico con Burrows's Delta.
#
#     POR QUE DELTA REEMPLAZA AL DENDROGRAMA TF-IDF
#     El dendrograma original se construia sobre distancia de correlacion entre
#     los 500 terminos de mayor TF-IDF del texto filtrado por stopwords. De esa
#     eleccion se siguen dos problemas.
#
#     Primero, TF-IDF por construccion premia terminos que aparecen en pocos
#     documentos. En un corpus de novelas los terminos que mejor cumplen ese
#     criterio son nombres de personajes y lugares. Un agrupamiento construido
#     sobre ellos recupera que libros comparten elenco, que es por que el
#     dendrograma original agrupaba tan limpio las novelas de Salvatore y las de
#     Harry Potter. Eso es un hecho sobre pertenencia a una serie, no sobre
#     estilo, y apareceria identico si todos los libros los hubiera escrito la
#     misma persona.
#
#     Segundo, quitar las palabras funcionales antes de agrupar descarta la senal
#     en la que la estilistica computacional efectivamente se apoya. El estilo
#     autoral vive en las elecciones inconscientes y de alta frecuencia que un
#     escritor hace entre determinantes, preposiciones, pronombres y
#     conjunciones, justamente las palabras que una lista de stopwords elimina.
#
#     Burrows's Delta es el metodo estandar para este problema. Trabaja sobre las
#     n palabras mas frecuentes de todo el corpus, incluidas las funcionales,
#     estandariza la frecuencia de cada palabra entre documentos como puntaje z, y
#     mide la diferencia absoluta media entre los vectores z de dos documentos.
#     La estandarizacion implica que una palabra comun no puede dominar por el
#     solo hecho de ser comun, y la restriccion a palabras frecuentes implica que
#     el vocabulario tematico nunca entra.
#
#     SOPORTE DE LOS CLUSTERS
#     Un dendrograma dibujado una vez muestra una estructura pero no dice nada
#     sobre si esa estructura es estable. Aca cada rama se anota con soporte
#     bootstrap: el conjunto de rasgos se remuestrea con reemplazo
#     PARAMS$n_bootstrap veces, el arbol se reconstruye cada vez, y el soporte es
#     la proporcion de replicas en que un grupo dado de libros permanece unido.
#     Una rama con soporte bajo el 70 por ciento aproximado no deberia
#     interpretarse.
#
#     El analisis TF-IDF se conserva como chequeo de sensibilidad claramente
#     etiquetado, ya que responde una pregunta distinta y de todos modos legitima
#     sobre contenido compartido.
#
# OUTPUT / SALIDA
#   outputs/tables/07_stylometry_*.csv|.tex
#   outputs/figures/07_stylometry_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("07_stylometry: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(ggdendro)
  library(tidytext)
  library(stringi)
})

set.seed(PARAMS$seed)

corpus <- readRDS(file.path(PATHS$derived, "corpus.rds")) %>%
  dplyr::select(book_id, group, title_es, author, series, audience, translated,
                tokens_running, tokens_content, n_tokens_running)
invisible(gc(verbose = FALSE))

# EN: Short display labels. Papelucho volumes are numbered by publication order
#     so the dendrogram can be read against the series chronology.
# ES: Etiquetas cortas para graficar. Los volumenes de Papelucho se numeran por
#     orden de publicacion para que el dendrograma pueda leerse contra la
#     cronologia de la serie.
labels_tbl <- corpus %>%
  dplyr::mutate(
    display = ifelse(
      group == GROUPS$focus,
      paste0("Papelucho_", sub("^PAP", "", book_id)),
      stringr::str_trunc(title_es, 34)
    )
  ) %>%
  dplyr::select(book_id, group, author, series, display)

# Guard against duplicate display labels, which would silently merge rows in the
# distance matrix.
if (anyDuplicated(labels_tbl$display) > 0) {
  dup <- labels_tbl$display[duplicated(labels_tbl$display)]
  labels_tbl <- labels_tbl %>%
    dplyr::group_by(display) %>%
    dplyr::mutate(display = ifelse(dplyr::n() > 1,
                                   paste0(display, " [", book_id, "]"), display)) %>%
    dplyr::ungroup()
  log_msg("  disambiguated ", length(unique(dup)), " duplicate display label(s)")
}

# =============================================================================
# 1. Length-controlled token samples
# =============================================================================
# EN: Word frequencies estimated from 20,000 tokens are noisier than those from
#     250,000, and Delta has no built-in correction for that. Every book
#     therefore contributes the same number of tokens.
# ES: Las frecuencias de palabra estimadas con 20.000 tokens son mas ruidosas que
#     las estimadas con 250.000, y Delta no trae correccion para eso. Por lo
#     tanto cada libro aporta el mismo numero de tokens.

sample_size <- min(PARAMS$sample_size * 2L, min(corpus$n_tokens_running))
log_msg("  sampling ", format(sample_size, big.mark = ","),
        " running tokens per book")
stopifnot(all(corpus$n_tokens_running >= sample_size))

sampled_tokens <- purrr::map(corpus$tokens_running, function(tk) {
  idx <- sample.int(length(tk), size = sample_size, replace = FALSE)
  tk[sort(idx)]
})
names(sampled_tokens) <- labels_tbl$display

# =============================================================================
# 2. Burrows's Delta
# =============================================================================

log_msg("  building most-frequent-word matrix (", PARAMS$mfw_n, " words)")

freq_long <- purrr::imap_dfr(sampled_tokens, function(tk, nm) {
  tibble::tibble(document = nm, word = tk) %>%
    dplyr::count(document, word, name = "n")
})

# EN: The MFW list is chosen on total corpus frequency, not on any per-group
#     criterion, so the feature set cannot favour either corpus.
# ES: La lista de MFW se elige por frecuencia total en el corpus, no por ningun
#     criterio por grupo, asi que el conjunto de rasgos no puede favorecer a
#     ninguno de los dos.
mfw <- freq_long %>%
  dplyr::group_by(word) %>%
  dplyr::summarise(total = sum(n), n_docs = dplyr::n_distinct(document),
                   .groups = "drop") %>%
  # A word absent from most books cannot support a stable z-score.
  dplyr::filter(n_docs >= 0.8 * nrow(corpus)) %>%
  dplyr::slice_max(total, n = PARAMS$mfw_n, with_ties = FALSE) %>%
  dplyr::pull(word)

log_msg("  ", length(mfw), " most frequent words retained, present in at least ",
        ceiling(0.8 * nrow(corpus)), " of ", nrow(corpus), " books")

rel_freq <- freq_long %>%
  dplyr::filter(word %in% mfw) %>%
  dplyr::group_by(document) %>%
  dplyr::mutate(rel = n / sample_size) %>%
  dplyr::ungroup() %>%
  dplyr::select(document, word, rel) %>%
  tidyr::complete(document, word = mfw, fill = list(rel = 0)) %>%
  tidyr::pivot_wider(names_from = word, values_from = rel)

freq_matrix <- as.matrix(rel_freq[, -1])
rownames(freq_matrix) <- rel_freq$document

#' Burrows's Delta distance matrix
#' EN: Columns are standardised into z-scores across documents, then the
#'     distance between two documents is the mean absolute difference of their
#'     z-score vectors. Columns with zero variance carry no information and are
#'     dropped rather than producing NaN.
#' ES: Las columnas se estandarizan como puntajes z entre documentos, y luego la
#'     distancia entre dos documentos es la diferencia absoluta media de sus
#'     vectores z. Las columnas con varianza cero no aportan informacion y se
#'     descartan en vez de producir NaN.
burrows_delta <- function(mat) {
  keep <- apply(mat, 2, stats::sd) > 0
  z <- scale(mat[, keep, drop = FALSE])
  stats::dist(z, method = "manhattan") / sum(keep)
}

delta_dist <- burrows_delta(freq_matrix)
delta_tree <- stats::hclust(delta_dist, method = "ward.D2")

# =============================================================================
# 3. Bootstrap cluster support
# =============================================================================
# EN: Features are resampled with replacement and the tree rebuilt. Support for
#     a clade is the proportion of replicate trees that contain exactly that set
#     of books as a cluster. This is the same logic as bootstrap support in
#     phylogenetics.
# ES: Los rasgos se remuestrean con reemplazo y el arbol se reconstruye. El
#     soporte de un clado es la proporcion de arboles replica que contienen
#     exactamente ese conjunto de libros como cluster. Es la misma logica que el
#     soporte bootstrap en filogenetica.

#' Extract every clade of a tree as a sorted membership string
tree_clades <- function(tree) {
  labels_t <- tree$labels
  merges <- tree$merge
  members <- vector("list", nrow(merges))
  out <- character(nrow(merges))
  for (i in seq_len(nrow(merges))) {
    left  <- merges[i, 1]
    right <- merges[i, 2]
    l <- if (left  < 0) labels_t[-left]  else members[[left]]
    r <- if (right < 0) labels_t[-right] else members[[right]]
    members[[i]] <- c(l, r)
    out[i] <- paste(sort(members[[i]]), collapse = "|")
  }
  out
}

log_msg("  bootstrapping cluster support (", PARAMS$n_bootstrap, " replicates)")

observed_clades <- tree_clades(delta_tree)
n_feat <- ncol(freq_matrix)

boot_counts <- new.env(hash = TRUE, parent = emptyenv())
for (cl in observed_clades) assign(cl, 0L, envir = boot_counts)

for (b in seq_len(PARAMS$n_bootstrap)) {
  cols <- sample.int(n_feat, n_feat, replace = TRUE)
  m_b  <- freq_matrix[, cols, drop = FALSE]
  # Duplicated column names break scale(); names are irrelevant here.
  colnames(m_b) <- paste0("f", seq_len(ncol(m_b)))
  t_b  <- stats::hclust(burrows_delta(m_b), method = "ward.D2")
  for (cl in unique(tree_clades(t_b))) {
    if (exists(cl, envir = boot_counts, inherits = FALSE)) {
      assign(cl, get(cl, envir = boot_counts) + 1L, envir = boot_counts)
    }
  }
  if (b %% 250 == 0) log_msg("    ", b, "/", PARAMS$n_bootstrap)
}

support <- tibble::tibble(
  clade = observed_clades,
  support = vapply(observed_clades,
                   function(cl) get(cl, envir = boot_counts), integer(1)) /
    PARAMS$n_bootstrap,
  n_books = vapply(observed_clades,
                   function(cl) length(strsplit(cl, "|", fixed = TRUE)[[1]]),
                   integer(1)),
  height = delta_tree$height
)

# =============================================================================
# 4. Is the Papelucho series a single cluster?
# =============================================================================
# EN: The concrete question the dendrogram is meant to answer. Recorded as a
#     single number with its bootstrap support rather than left to visual
#     impression.
# ES: La pregunta concreta que el dendrograma pretende responder. Se registra
#     como un solo numero con su soporte bootstrap en vez de dejarla a la
#     impresion visual.
papelucho_labels <- labels_tbl$display[labels_tbl$group == GROUPS$focus]
papelucho_clade  <- paste(sort(papelucho_labels), collapse = "|")

papelucho_support <- support$support[support$clade == papelucho_clade]
if (length(papelucho_support) == 0) papelucho_support <- 0

log_msg("  Papelucho forms an exclusive cluster in the observed tree: ",
        papelucho_clade %in% observed_clades)
log_msg("  bootstrap support for that cluster: ",
        round(100 * papelucho_support, 1), "%")

# EN: Purity of the cluster a given book falls in, at the k-group cut. A general
#     measure of whether the corpora separate, independent of whether one exact
#     clade happens to be recovered.
# ES: Pureza del cluster en que cae cada libro, en el corte de k grupos. Una
#     medida general de si los corpus se separan, con independencia de que se
#     recupere exactamente un clado.
cut_purity <- purrr::map_dfr(2:8, function(k) {
  cl <- stats::cutree(delta_tree, k = k)
  tbl <- tibble::tibble(display = names(cl), cluster = cl) %>%
    dplyr::left_join(labels_tbl, by = "display")
  tibble::tibble(
    k = k,
    papelucho_clusters = dplyr::n_distinct(tbl$cluster[tbl$group == GROUPS$focus]),
    largest_papelucho_cluster_purity = tbl %>%
      dplyr::filter(group == GROUPS$focus) %>%
      dplyr::count(cluster) %>%
      dplyr::slice_max(n, n = 1, with_ties = FALSE) %>%
      dplyr::pull(cluster) %>%
      (function(cc) mean(tbl$group[tbl$cluster == cc] == GROUPS$focus))
  )
})

# =============================================================================
# 5. Dendrogram figure
# =============================================================================

dd <- ggdendro::dendro_data(delta_tree, type = "rectangle")

label_data <- dd$labels %>%
  dplyr::rename(display = label) %>%
  dplyr::left_join(labels_tbl, by = "display")

fig_dendro <- ggplot() +
  geom_segment(data = dd$segments,
               aes(x = x, y = y, xend = xend, yend = yend),
               colour = "grey35", linewidth = 0.32) +
  geom_point(data = label_data, aes(x = x, y = 0, colour = group), size = 2.4) +
  scale_colour_manual(values = GROUP_COLOURS) +
  scale_x_continuous(breaks = label_data$x, labels = label_data$display,
                     expand = expansion(mult = c(0.006, 0.006))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03))) +
  labs(x = NULL, y = "Burrows's Delta", colour = "Corpus") +
  theme_papelucho(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7.5),
    axis.ticks.x = element_blank(),
    axis.line.x = element_blank()
  )

save_figure(fig_dendro, "07_dendrogram_delta", width = 14, height = 7)

# Support-annotated version: only well-supported nodes are labelled, so the
# figure communicates uncertainty rather than hiding it.
support_nodes <- support %>%
  dplyr::mutate(node = dplyr::row_number()) %>%
  dplyr::filter(n_books >= 3, support >= 0.5)

if (nrow(support_nodes) > 0) {
  node_coords <- tibble::tibble(
    node = seq_len(nrow(delta_tree$merge)),
    y = delta_tree$height,
    x = vapply(seq_len(nrow(delta_tree$merge)), function(i) {
      cl <- strsplit(observed_clades[i], "|", fixed = TRUE)[[1]]
      mean(label_data$x[label_data$display %in% cl])
    }, numeric(1))
  )

  support_plot <- support_nodes %>% dplyr::left_join(node_coords, by = "node")

  fig_dendro_support <- fig_dendro +
    geom_label(data = support_plot,
               aes(x = x, y = y, label = sprintf("%.0f", 100 * support)),
               size = 2.4, label.padding = unit(0.1, "lines"),
               label.size = 0.2, fill = "white", colour = "grey20")

  save_figure(fig_dendro_support, "07_dendrogram_delta_support",
              width = 14, height = 7)
}

# =============================================================================
# 6. TF-IDF sensitivity analysis
# =============================================================================
# EN: Reproduces the original approach on content words, kept explicitly as a
#     contrast. Its clusters are expected to track series and authorship rather
#     than style, and the table below quantifies exactly that.
# ES: Reproduce el enfoque original sobre palabras de contenido, conservado de
#     forma explicita como contraste. Se espera que sus clusters sigan la serie y
#     la autoria mas que el estilo, y la tabla siguiente cuantifica justamente
#     eso.

log_msg("  TF-IDF sensitivity analysis")

content_freq <- purrr::imap_dfr(
  stats::setNames(corpus$tokens_content, labels_tbl$display),
  function(tk, nm) tibble::tibble(document = nm, word = tk) %>%
    dplyr::count(document, word, name = "n")
)

tfidf <- content_freq %>%
  tidytext::bind_tf_idf(term = word, document = document, n = n)

top_tfidf <- tfidf %>%
  dplyr::group_by(word) %>%
  dplyr::summarise(total_tfidf = sum(tf_idf), total_n = sum(n), .groups = "drop") %>%
  dplyr::filter(total_n >= PARAMS$tfidf_min_freq) %>%
  dplyr::slice_max(total_tfidf, n = PARAMS$tfidf_n, with_ties = FALSE) %>%
  dplyr::pull(word)

tfidf_matrix <- tfidf %>%
  dplyr::filter(word %in% top_tfidf) %>%
  dplyr::select(document, word, tf_idf) %>%
  tidyr::complete(document, word = top_tfidf, fill = list(tf_idf = 0)) %>%
  tidyr::pivot_wider(names_from = word, values_from = tf_idf)

tfidf_mat <- as.matrix(tfidf_matrix[, -1])
rownames(tfidf_mat) <- tfidf_matrix$document

cor_mat <- stats::cor(t(tfidf_mat), method = "pearson")
cor_mat[is.na(cor_mat)] <- 0
diag(cor_mat) <- 1
tfidf_tree <- stats::hclust(stats::as.dist(1 - cor_mat), method = "average")

# EN: What each feature set actually recovers. If TF-IDF clusters align with
#     series membership far better than Delta clusters do, that is direct
#     evidence that the original dendrogram was reading content, not style.
# ES: Que recupera de verdad cada conjunto de rasgos. Si los clusters de TF-IDF
#     se alinean con la pertenencia a la serie mucho mejor que los de Delta, eso
#     es evidencia directa de que el dendrograma original leia contenido, no
#     estilo.
recovery <- function(tree, k, key) {
  cl <- stats::cutree(tree, k = k)
  tbl <- tibble::tibble(display = names(cl), cluster = cl) %>%
    dplyr::left_join(labels_tbl, by = "display") %>%
    dplyr::filter(!is.na(.data[[key]]), .data[[key]] != "")
  if (nrow(tbl) == 0) return(NA_real_)
  # Proportion of same-key pairs that land in the same cluster.
  same_key <- outer(tbl[[key]], tbl[[key]], "==")
  same_cl  <- outer(tbl$cluster, tbl$cluster, "==")
  idx <- upper.tri(same_key)
  sum(same_key[idx] & same_cl[idx]) / sum(same_key[idx])
}

method_comparison <- purrr::map_dfr(c(5, 10, 15), function(k) {
  tibble::tibble(
    k = k,
    delta_series_recovery = recovery(delta_tree, k, "series"),
    tfidf_series_recovery = recovery(tfidf_tree, k, "series"),
    delta_author_recovery = recovery(delta_tree, k, "author"),
    tfidf_author_recovery = recovery(tfidf_tree, k, "author")
  )
})

dd_t <- ggdendro::dendro_data(tfidf_tree, type = "rectangle")
label_t <- dd_t$labels %>%
  dplyr::rename(display = label) %>%
  dplyr::left_join(labels_tbl, by = "display")

fig_tfidf <- ggplot() +
  geom_segment(data = dd_t$segments,
               aes(x = x, y = y, xend = xend, yend = yend),
               colour = "grey35", linewidth = 0.32) +
  geom_point(data = label_t, aes(x = x, y = 0, colour = group), size = 2.4) +
  scale_colour_manual(values = GROUP_COLOURS) +
  scale_x_continuous(breaks = label_t$x, labels = label_t$display,
                     expand = expansion(mult = c(0.006, 0.006))) +
  labs(x = NULL, y = "Correlation distance (TF-IDF, content words)",
       colour = "Corpus") +
  theme_papelucho(base_size = 10) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7.5),
        axis.ticks.x = element_blank(), axis.line.x = element_blank())

save_figure(fig_tfidf, "07_dendrogram_tfidf_sensitivity", width = 14, height = 7)

# =============================================================================
# 7. Export
# =============================================================================

order_tbl <- tibble::tibble(
  order = seq_along(delta_tree$order),
  display = delta_tree$labels[delta_tree$order]
) %>%
  dplyr::left_join(labels_tbl, by = "display")

export_table(
  support %>%
    dplyr::filter(n_books >= 2) %>%
    dplyr::arrange(dplyr::desc(support)) %>%
    dplyr::mutate(clade = stringr::str_trunc(clade, 90)),
  "07_cluster_support",
  caption_en = sprintf("Bootstrap support for clusters in the Burrows's Delta tree, over %d feature resamples.",
                       PARAMS$n_bootstrap),
  caption_es = sprintf("Soporte bootstrap de los clusters del arbol de Burrows's Delta, sobre %d remuestreos de rasgos.",
                       PARAMS$n_bootstrap),
  label = "cluster-support",
  note_en = "Clusters with support below roughly 70 percent should not be interpreted as stable groupings.",
  note_es = "Los clusters con soporte bajo el 70 por ciento aproximado no deben interpretarse como agrupaciones estables."
)

export_table(
  method_comparison, "07_method_comparison",
  caption_en = "Proportion of book pairs from the same series or the same author that fall in the same cluster, under each feature set.",
  caption_es = "Proporcion de pares de libros de la misma serie o del mismo autor que caen en el mismo cluster, bajo cada conjunto de rasgos.",
  label = "method-comparison",
  note_en = "Higher TF-IDF recovery indicates that the TF-IDF clustering is driven by shared content rather than by style.",
  note_es = "Una recuperacion mayor con TF-IDF indica que el agrupamiento TF-IDF esta guiado por contenido compartido y no por estilo."
)

write_table_csv(order_tbl, "07_dendrogram_order")
write_table_csv(cut_purity, "07_cut_purity")
write_table_csv(
  tibble::tibble(
    question = "Do the 12 Papelucho books form one exclusive cluster?",
    recovered_in_observed_tree = papelucho_clade %in% observed_clades,
    bootstrap_support = papelucho_support,
    n_bootstrap = PARAMS$n_bootstrap,
    mfw_used = length(mfw),
    tokens_per_book = sample_size
  ),
  "07_papelucho_cluster_support"
)

saveRDS(list(delta_dist = delta_dist, delta_tree = delta_tree,
             freq_matrix = freq_matrix, labels = labels_tbl),
        file.path(PATHS$derived, "stylometry.rds"))

log_msg("  cluster purity by cut:")
print(as.data.frame(cut_purity), row.names = FALSE)
log_msg("  series recovery, Delta vs TF-IDF:")
print(as.data.frame(method_comparison), row.names = FALSE)

write_session_info("07_stylometry")
log_msg("07_stylometry: done")
