# =============================================================================
# 08_umap.R
# -----------------------------------------------------------------------------
# EN: UMAP projection of the stylometric feature space.
#
#     WHY THE STABILITY CHECK IS THE POINT OF THIS SCRIPT
#     UMAP is stochastic. Its output depends on the random seed, on the number
#     of neighbours and on the minimum-distance parameter, and with only 75
#     points a single run can produce a visually convincing separation that
#     disappears under a different seed. Publishing one UMAP plot from one seed,
#     as the original script did, is not evidence of structure. It is one draw
#     from a distribution of possible pictures.
#
#     This script therefore runs UMAP under every seed in PARAMS$umap_seeds and
#     across a grid of neighbour and distance settings, and quantifies how much
#     the result changes. Two measures are reported.
#
#       * Neighbourhood preservation: the proportion of each point's k nearest
#         neighbours in the original high-dimensional space that remain among
#         its k nearest neighbours in the projection. This measures whether the
#         projection is faithful at all, independently of what it looks like.
#       * Group separation: silhouette width of the corpus labels in the
#         projection, computed for every run. A separation that is real will
#         hold across seeds; one that is an artefact will vary wildly.
#
#     UMAP is used here for display only. Every statistical claim in this project
#     rests on the distance matrix from 07_stylometry.R, never on coordinates
#     read off a projection.
#
# ES: Proyeccion UMAP del espacio de rasgos estilometricos.
#
#     POR QUE EL CHEQUEO DE ESTABILIDAD ES EL PUNTO DE ESTE SCRIPT
#     UMAP es estocastico. Su salida depende de la semilla aleatoria, del numero
#     de vecinos y del parametro de distancia minima, y con solo 75 puntos una
#     sola corrida puede producir una separacion visualmente convincente que
#     desaparece con otra semilla. Publicar un grafico UMAP de una semilla, como
#     hacia el script original, no es evidencia de estructura. Es un sorteo de una
#     distribucion de imagenes posibles.
#
#     Por eso este script corre UMAP con cada semilla de PARAMS$umap_seeds y
#     sobre una grilla de configuraciones de vecinos y distancia, y cuantifica
#     cuanto cambia el resultado. Se reportan dos medidas.
#
#       * Preservacion de vecindario: la proporcion de los k vecinos mas
#         cercanos de cada punto en el espacio original de alta dimension que
#         siguen entre sus k vecinos mas cercanos en la proyeccion. Mide si la
#         proyeccion es fiel del todo, con independencia de como se vea.
#       * Separacion de grupos: ancho de silueta de las etiquetas de corpus en la
#         proyeccion, calculado para cada corrida. Una separacion real se sostiene
#         entre semillas; una que es artefacto varia mucho.
#
#     UMAP se usa aca solo para visualizar. Toda afirmacion estadistica de este
#     proyecto se apoya en la matriz de distancias de 07_stylometry.R, nunca en
#     coordenadas leidas de una proyeccion.
#
# OUTPUT / SALIDA
#   outputs/tables/08_umap_*.csv|.tex
#   outputs/figures/08_umap_*.pdf|.png
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies(quiet = TRUE)
log_msg("08_umap: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(ggrepel)
  library(uwot)
  library(cluster)
})

sty <- readRDS(file.path(PATHS$derived, "stylometry.rds"))
freq_matrix <- sty$freq_matrix
labels_tbl  <- sty$labels
delta_dist  <- sty$delta_dist

# EN: The same z-scored most-frequent-word matrix that Delta was computed on, so
#     the projection and the statistics describe the same space.
# ES: La misma matriz de palabras mas frecuentes estandarizada sobre la que se
#     calculo Delta, para que la proyeccion y los estadisticos describan el
#     mismo espacio.
keep <- apply(freq_matrix, 2, stats::sd) > 0
z_matrix <- scale(freq_matrix[, keep, drop = FALSE])

log_msg("  feature space: ", nrow(z_matrix), " books x ", ncol(z_matrix), " words")

group_vec <- labels_tbl$group[match(rownames(z_matrix), labels_tbl$display)]
stopifnot(!anyNA(group_vec))

# =============================================================================
# 1. Quality measures
# =============================================================================

#' Neighbourhood preservation
#' EN: Mean over points of the overlap between the k nearest neighbours in the
#'     original space and in the projection. Ranges from 0 to 1; values below
#'     about 0.3 mean the projection is not representing local structure and
#'     should not be read as a map of similarity.
#' ES: Media sobre los puntos del solapamiento entre los k vecinos mas cercanos
#'     en el espacio original y en la proyeccion. Va de 0 a 1; valores bajo 0,3
#'     aproximado significan que la proyeccion no representa la estructura local
#'     y no debe leerse como un mapa de similitud.
neighbourhood_preservation <- function(dist_high, coords, k = 10L) {

  dh <- as.matrix(dist_high)
  dl <- as.matrix(stats::dist(coords))
  n  <- nrow(dh)
  k  <- min(k, n - 1L)

  knn_of <- function(m) {
    apply(m, 1, function(row) order(row)[2:(k + 1)])
  }

  hi <- knn_of(dh)
  lo <- knn_of(dl)

  mean(vapply(seq_len(n), function(i) {
    length(intersect(hi[, i], lo[, i])) / k
  }, numeric(1)))
}

#' Silhouette width of the corpus labels in a projection
#' EN: Positive values mean the two corpora occupy distinct regions; values near
#'     zero mean they overlap. Note this measures separation in the projection,
#'     which is not the same as separation in the original space.
#' ES: Valores positivos significan que los dos corpus ocupan regiones distintas;
#'     valores cerca de cero significan que se solapan. Notar que esto mide
#'     separacion en la proyeccion, que no es lo mismo que separacion en el
#'     espacio original.
group_silhouette <- function(coords, groups) {
  g <- as.integer(factor(groups))
  if (dplyr::n_distinct(g) < 2) return(NA_real_)
  sil <- cluster::silhouette(g, stats::dist(coords))
  mean(sil[, "sil_width"])
}

# EN: Baseline silhouette in the original high-dimensional space. Any claim of
#     separation must be checked against this, since the projection can both
#     create and destroy apparent structure.
# ES: Silueta de referencia en el espacio original de alta dimension. Toda
#     afirmacion de separacion debe contrastarse contra esta, ya que la
#     proyeccion puede tanto crear como destruir estructura aparente.
baseline_silhouette <- {
  g <- as.integer(factor(group_vec))
  mean(cluster::silhouette(g, delta_dist)[, "sil_width"])
}
log_msg("  silhouette in the original Delta space: ",
        round(baseline_silhouette, 3))

# =============================================================================
# 2. Stability across seeds and parameters
# =============================================================================

param_grid <- tidyr::expand_grid(
  seed        = PARAMS$umap_seeds,
  n_neighbors = c(5L, 15L, 30L),
  min_dist    = c(0.05, 0.15, 0.35)
) %>%
  dplyr::mutate(n_neighbors = pmin(n_neighbors, nrow(z_matrix) - 1L))

log_msg("  running UMAP over ", nrow(param_grid),
        " seed and parameter combinations")

run_umap <- function(seed, n_neighbors, min_dist) {
  set.seed(seed)
  emb <- uwot::umap(
    X            = z_matrix,
    n_neighbors  = n_neighbors,
    min_dist     = min_dist,
    n_components = 2,
    metric       = "euclidean",
    scale        = FALSE,        # already z-scored
    verbose      = FALSE
  )
  colnames(emb) <- c("UMAP1", "UMAP2")
  emb
}

stability <- purrr::pmap_dfr(
  list(param_grid$seed, param_grid$n_neighbors, param_grid$min_dist),
  function(sd, nn, md) {
    emb <- run_umap(sd, nn, md)
    tibble::tibble(
      seed = sd, n_neighbors = nn, min_dist = md,
      neighbourhood_preservation = neighbourhood_preservation(delta_dist, emb, k = 10L),
      silhouette = group_silhouette(emb, group_vec)
    )
  }
)

log_msg("  stability across all runs:")
print(as.data.frame(
  stability %>%
    dplyr::summarise(
      runs = dplyr::n(),
      np_median = round(stats::median(neighbourhood_preservation), 3),
      np_min    = round(min(neighbourhood_preservation), 3),
      np_max    = round(max(neighbourhood_preservation), 3),
      sil_median = round(stats::median(silhouette), 3),
      sil_min    = round(min(silhouette), 3),
      sil_max    = round(max(silhouette), 3)
    )
), row.names = FALSE)

# EN: Explicit verdict rather than leaving the reader to judge from a range.
# ES: Veredicto explicito en vez de dejar al lector juzgar desde un rango.
sil_range <- diff(range(stability$silhouette))
sil_sign_stable <- all(stability$silhouette > 0) || all(stability$silhouette < 0)

verdict <- dplyr::case_when(
  !sil_sign_stable ~
    "Unstable: the sign of group separation changes across seeds. Do not interpret the projection as showing separation.",
  sil_range > 0.15 ~
    "Weakly stable: separation holds in sign but varies substantially in magnitude across seeds.",
  TRUE ~
    "Stable: group separation is consistent in sign and magnitude across seeds and parameter settings."
)
log_msg("  verdict: ", verdict)

# =============================================================================
# 3. Reference projection
# =============================================================================
# EN: One run is chosen for display, using the first seed and the configured
#     defaults. It is labelled in the caption as one draw among many, and the
#     stability table travels with it.
# ES: Se elige una corrida para mostrar, con la primera semilla y los valores por
#     defecto configurados. Se etiqueta en el pie como un sorteo entre muchos, y
#     la tabla de estabilidad viaja con ella.

ref_seed <- PARAMS$umap_seeds[1]
ref_nn   <- min(PARAMS$umap_neighbors, nrow(z_matrix) - 1L)
ref_md   <- PARAMS$umap_min_dist

ref_emb <- run_umap(ref_seed, ref_nn, ref_md)

umap_df <- tibble::as_tibble(ref_emb) %>%
  dplyr::mutate(display = rownames(z_matrix)) %>%
  dplyr::left_join(labels_tbl, by = "display")

fig_umap <- ggplot(umap_df, aes(x = UMAP1, y = UMAP2, colour = group)) +
  geom_point(size = 3.4, alpha = 0.9) +
  ggrepel::geom_text_repel(
    aes(label = display), size = 2.5, max.overlaps = Inf,
    box.padding = 0.5, point.padding = 0.3, segment.alpha = 0.5,
    segment.linewidth = 0.25, min.segment.length = 0, show.legend = FALSE
  ) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = "UMAP 1", y = "UMAP 2", colour = "Corpus") +
  theme_papelucho()

save_figure(fig_umap, "08_umap_reference", width = 11, height = 8)

# EN: Small-multiple panel of one projection per seed. This is the figure that
#     communicates honestly how much the picture depends on the seed, and it
#     belongs in the supplementary material of any paper using UMAP.
# ES: Panel de multiplos pequenos con una proyeccion por semilla. Esta es la
#     figura que comunica con honestidad cuanto depende la imagen de la semilla,
#     y corresponde al material suplementario de cualquier paper que use UMAP.
multi_seed <- purrr::map_dfr(PARAMS$umap_seeds, function(sd) {
  emb <- run_umap(sd, ref_nn, ref_md)
  tibble::as_tibble(emb) %>%
    dplyr::mutate(display = rownames(z_matrix), seed = sd)
}) %>%
  dplyr::left_join(labels_tbl, by = "display")

fig_seeds <- ggplot(multi_seed, aes(x = UMAP1, y = UMAP2, colour = group)) +
  geom_point(size = 2, alpha = 0.85) +
  facet_wrap(~ paste("seed", seed), scales = "free", ncol = 3) +
  scale_colour_manual(values = GROUP_COLOURS) +
  labs(x = "UMAP 1", y = "UMAP 2", colour = "Corpus") +
  theme_papelucho(base_size = 10)

save_figure(fig_seeds, "08_umap_seed_stability", width = 12, height = 8)

fig_stability <- ggplot(stability,
                        aes(x = factor(n_neighbors), y = silhouette,
                            colour = factor(min_dist))) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_hline(yintercept = baseline_silhouette, colour = "#00A499",
             linetype = "dashed", linewidth = 0.5) +
  geom_point(position = position_jitterdodge(jitter.width = 0.12,
                                             dodge.width = 0.6),
             size = 2, alpha = 0.85) +
  labs(x = "Number of neighbours", y = "Group silhouette width",
       colour = "min_dist",
       subtitle = "Dashed line: silhouette in the original Delta space") +
  theme_papelucho(base_size = 11)

save_figure(fig_stability, "08_umap_parameter_stability", width = 9, height = 5.5)

# =============================================================================
# 4. Export
# =============================================================================

export_table(
  stability, "08_umap_stability",
  caption_en = "UMAP stability across random seeds and parameter settings.",
  caption_es = "Estabilidad de UMAP entre semillas aleatorias y configuraciones de parametros.",
  label = "umap-stability",
  note_en = sprintf("Silhouette width in the original Burrows's Delta space is %.3f. Neighbourhood preservation is computed on the 10 nearest neighbours.",
                    baseline_silhouette),
  note_es = sprintf("El ancho de silueta en el espacio original de Burrows's Delta es %.3f. La preservacion de vecindario se calcula sobre los 10 vecinos mas cercanos.",
                    baseline_silhouette)
)

write_table_csv(umap_df, "08_umap_reference_coordinates")
write_table_csv(
  tibble::tibble(
    baseline_silhouette_delta_space = baseline_silhouette,
    silhouette_median = stats::median(stability$silhouette),
    silhouette_min = min(stability$silhouette),
    silhouette_max = max(stability$silhouette),
    silhouette_range = sil_range,
    sign_stable_across_runs = sil_sign_stable,
    neighbourhood_preservation_median = stats::median(stability$neighbourhood_preservation),
    n_runs = nrow(stability),
    verdict = verdict
  ),
  "08_umap_verdict"
)

saveRDS(list(stability = stability, reference = umap_df),
        file.path(PATHS$derived, "umap.rds"))

write_session_info("08_umap")
log_msg("08_umap: done")
