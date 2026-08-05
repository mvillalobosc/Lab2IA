# =============================================================================
# 03_solution_overlap.R
# -----------------------------------------------------------------------------
# EN: How much the fifteen ORF sets share with each other.
#
#     This script replaces Upset/main.R and Upset/interseccion.R, which between
#     them duplicated the same 130 lines of hard-coded gene vectors. Both read
#     the sets from data/solutions.csv now.
#
#     WHAT IT REPORTS
#       * the pairwise intersection matrix, as counts and as Jaccard index;
#       * which ORFs recur across solutions, since a gene selected by many
#         independent Pareto solutions is the interesting result here;
#       * how much of the reference solution the Pareto front recovers;
#       * the UpSet plot, when UpSetR is installed.
#
#     WHY JACCARD IS ADDED
#     The original script reported raw intersection counts and picked the pair
#     with the largest one. Solution sizes range from 1 to 22 ORFs, so the raw
#     count is dominated by whichever pair happens to be largest: two 22-gene
#     sets sharing 6 genes score higher than two 5-gene sets sharing 4, although
#     the second pair is far more similar. Jaccard normalises by union size and
#     is reported alongside.
#
# ES: Cuanto comparten entre si los quince conjuntos de ORFs.
#
#     Este script reemplaza a Upset/main.R y Upset/interseccion.R, que entre los
#     dos duplicaban las mismas 130 lineas de vectores de genes escritos a mano.
#     Ahora los dos leen los conjuntos de data/solutions.csv.
#
#     POR QUE SE AGREGA JACCARD
#     El script original reportaba conteos crudos de interseccion y elegia el par
#     con el mayor. Los tamanos de solucion van de 1 a 22 ORFs, asi que el conteo
#     crudo queda dominado por el par que resulte ser mas grande: dos conjuntos de
#     22 genes que comparten 6 puntuan mas alto que dos de 5 que comparten 4,
#     aunque el segundo par es mucho mas parecido. Jaccard normaliza por el
#     tamano de la union y se reporta al lado.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")

check_dependencies(quiet = TRUE)
log_msg("03_solution_overlap: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

sols <- read_solutions()
log_msg("  ", length(sols), " solutions, ",
        length(unique(unlist(sols))), " distinct ORFs")

# -----------------------------------------------------------------------------
# 1. Pairwise overlap
# -----------------------------------------------------------------------------

n     <- length(sols)
nm    <- names(sols)
inter <- matrix(0L, n, n, dimnames = list(nm, nm))
jacc  <- matrix(NA_real_, n, n, dimnames = list(nm, nm))

for (i in seq_len(n)) {
  for (j in seq_len(n)) {
    a <- sols[[i]]; b <- sols[[j]]
    inter[i, j] <- length(intersect(a, b))
    jacc[i, j]  <- length(intersect(a, b)) / length(union(a, b))
  }
}

readr::write_csv(as.data.frame(inter) %>% tibble::rownames_to_column("solution"),
                 file.path(PATHS$tables, "03_intersection_counts.csv"))
readr::write_csv(as.data.frame(round(jacc, 4)) %>% tibble::rownames_to_column("solution"),
                 file.path(PATHS$tables, "03_jaccard.csv"))

# Long form, upper triangle only, so each pair appears once.
pairs <- expand.grid(a = nm, b = nm, stringsAsFactors = FALSE) %>%
  dplyr::filter(match(a, nm) < match(b, nm)) %>%
  dplyr::mutate(
    shared  = mapply(function(x, y) length(intersect(sols[[x]], sols[[y]])), a, b),
    union   = mapply(function(x, y) length(union(sols[[x]], sols[[y]])), a, b),
    jaccard = shared / union
  ) %>%
  dplyr::arrange(dplyr::desc(jaccard), dplyr::desc(shared))

readr::write_csv(pairs, file.path(PATHS$tables, "03_pairwise_overlap.csv"))

log_msg("  most similar pairs by Jaccard:")
print(as.data.frame(utils::head(pairs, 5)), row.names = FALSE)
log_msg("  largest raw intersection:")
print(as.data.frame(utils::head(pairs %>% dplyr::arrange(dplyr::desc(shared)), 3)),
      row.names = FALSE)

# -----------------------------------------------------------------------------
# 2. ORF recurrence
# -----------------------------------------------------------------------------
# EN: An ORF chosen by many independent Pareto solutions is a candidate
#     phylogenetically informative marker, which is the biological point of the
#     whole optimisation. Counted over the Pareto solutions only, since the
#     reference set is not an independent draw.
# ES: Un ORF elegido por muchas soluciones independientes del Pareto es un
#     candidato a marcador filogeneticamente informativo, que es el punto
#     biologico de toda la optimizacion. Se cuenta solo sobre las soluciones del
#     Pareto, ya que el conjunto de referencia no es una extraccion independiente.

pareto_sols <- sols[names(sols) != PARAMS$reference_solution]

recurrence <- tibble::tibble(orf = unlist(pareto_sols)) %>%
  dplyr::count(orf, name = "n_solutions", sort = TRUE) %>%
  dplyr::mutate(
    pct_of_solutions = round(100 * n_solutions / length(pareto_sols), 1),
    in_reference     = orf %in% sols[[PARAMS$reference_solution]]
  )

readr::write_csv(recurrence, file.path(PATHS$tables, "03_orf_recurrence.csv"))

log_msg("  ORFs selected by the most Pareto solutions:")
print(as.data.frame(utils::head(recurrence, 8)), row.names = FALSE)

# -----------------------------------------------------------------------------
# 3. Recovery of the reference set
# -----------------------------------------------------------------------------

ref <- sols[[PARAMS$reference_solution]]
recovery <- tibble::tibble(
  solution   = names(pareto_sols),
  n_orfs     = lengths(pareto_sols),
  shared_ref = vapply(pareto_sols, function(s) length(intersect(s, ref)), integer(1)),
  pct_of_ref = round(100 * vapply(pareto_sols,
                                  function(s) length(intersect(s, ref)), integer(1)) /
                       length(ref), 1)
) %>%
  dplyr::arrange(dplyr::desc(shared_ref))

readr::write_csv(recovery, file.path(PATHS$tables, "03_reference_recovery.csv"))

union_pareto <- unique(unlist(pareto_sols))
log_msg("  reference set has ", length(ref), " ORFs; the Pareto front recovers ",
        length(intersect(union_pareto, ref)), " of them across all solutions")

# -----------------------------------------------------------------------------
# 4. UpSet plot
# -----------------------------------------------------------------------------

if (has_package("UpSetR")) {
  pdf(file.path(PATHS$figures, "03_upset.pdf"), width = 12, height = 7)
  print(UpSetR::upset(
    UpSetR::fromList(sols),
    nsets          = length(sols),
    nintersects    = PARAMS$upset_n_intersections,
    sets.bar.color = COLOURS$bars_sets,
    main.bar.color = COLOURS$bars_inter,
    order.by       = "freq",
    decreasing     = TRUE,
    mb.ratio       = c(0.6, 0.4),
    text.scale     = 1.4,
    keep.order     = TRUE,
    sets           = rev(names(sols))
  ))
  dev.off()
  log_msg("  UpSet plot written")
} else {
  log_msg("  UpSetR not installed; overlap tables written, UpSet plot skipped")
}

write_session_info("03_solution_overlap")
log_msg("03_solution_overlap: done")
