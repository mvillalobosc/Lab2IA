# =============================================================================
# opt_operators.R
# -----------------------------------------------------------------------------
# EN: Solution representation, alignment cache and the genetic operators used by
#     both NSGA-II and MOSA.
#
#     SOLUTIONS ARE GENE NAMES, NOT POSITIONS
#     The original code represented a candidate as integer indices into
#     `list.files(directory)`. list.files sorts with the current locale's
#     collation, so index 500 is a different gene on a Spanish Windows machine
#     than on a C-locale Linux server. Every stored solution was therefore only
#     decodable on the machine that produced it, and re-running elsewhere would
#     silently optimise over a permuted gene space. Solutions here are vectors of
#     ORF names, which mean the same thing everywhere.
#
# ES: Representacion de soluciones, cache de alineamientos y operadores geneticos
#     que usan tanto NSGA-II como MOSA.
#
#     LAS SOLUCIONES SON NOMBRES DE GENES, NO POSICIONES
#     El codigo original representaba un candidato como indices enteros dentro de
#     `list.files(directory)`. list.files ordena segun la intercalacion del
#     locale actual, asi que el indice 500 es un gen distinto en un Windows en
#     espanol que en un servidor Linux con locale C. Cada solucion guardada solo
#     se podia decodificar en la maquina que la produjo, y volver a correrla en
#     otra optimizaria en silencio sobre un espacio de genes permutado. Aca las
#     soluciones son vectores de nombres de ORF, que significan lo mismo en todas
#     partes.
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(phangorn)
})

# -----------------------------------------------------------------------------
# 1. Gene pool
# -----------------------------------------------------------------------------

#' Build the pool of ORF names available to the search
#' EN: Read from the manifest rather than from a directory listing, so the pool
#'     is identical on every machine and does not depend on which alignments
#'     happen to be unpacked at the time. Sorted explicitly with method = "radix",
#'     which is locale-independent.
#' ES: Se lee del manifiesto y no de un listado de directorio, asi el conjunto es
#'     identico en toda maquina y no depende de que alineamientos esten
#'     descomprimidos en ese momento. Ordenado con method = "radix", que es
#'     independiente del locale.
gene_pool <- function(manifest = FILES$manifest, only_available = FALSE,
                      dir = PATHS$alignments) {
  m <- utils::read.csv(manifest, stringsAsFactors = FALSE)
  pool <- sort(m$orf, method = "radix")
  if (only_available) {
    have <- sub("\\.fasta\\.phylip$", "", list.files(dir, pattern = "\\.phylip$"))
    pool <- intersect(pool, sort(have, method = "radix"))
  }
  pool
}

# -----------------------------------------------------------------------------
# 2. Distance cache
# -----------------------------------------------------------------------------
# EN: Reading one alignment of 1011 taxa and computing its Hamming distances
#     takes roughly two seconds. A single NSGA-II run evaluates thousands of
#     candidate subsets and re-reads the same genes constantly, which is what
#     made the original runs take days. Per-gene distance matrices are therefore
#     cached in memory.
#
#     Each cached entry is a dist object of 1011 taxa, about 4 MB. The cache is
#     bounded and evicts the least recently used entry when full, so memory stays
#     predictable on a shared server.
# ES: Leer un alineamiento de 1011 taxones y calcular sus distancias de Hamming
#     toma unos dos segundos. Una sola corrida de NSGA-II evalua miles de
#     subconjuntos candidatos y relee los mismos genes constantemente, que es lo
#     que hacia que las corridas originales tomaran dias. Por eso las matrices de
#     distancia por gen se guardan en memoria.
#
#     Cada entrada es un objeto dist de 1011 taxones, unos 4 MB. La cache esta
#     acotada y descarta la entrada menos usada recientemente cuando se llena,
#     asi la memoria queda predecible en un servidor compartido.

.dist_cache <- new.env(parent = emptyenv())
.dist_cache$store <- list()
.dist_cache$used  <- character(0)
.dist_cache$max   <- 150L
.dist_cache$hits  <- 0L
.dist_cache$miss  <- 0L

cache_configure <- function(max_entries = 150L) {
  .dist_cache$max <- as.integer(max_entries)
  invisible(.dist_cache$max)
}

cache_stats <- function() {
  list(entries = length(.dist_cache$store),
       max = .dist_cache$max,
       hits = .dist_cache$hits,
       misses = .dist_cache$miss)
}

cache_reset <- function() {
  .dist_cache$store <- list()
  .dist_cache$used  <- character(0)
  .dist_cache$hits  <- 0L
  .dist_cache$miss  <- 0L
  invisible(TRUE)
}

#' Hamming distance matrix for one ORF, cached
gene_distance <- function(orf, dir = PATHS$alignments) {

  if (!is.null(.dist_cache$store[[orf]])) {
    .dist_cache$hits <- .dist_cache$hits + 1L
    .dist_cache$used <- c(setdiff(.dist_cache$used, orf), orf)
    return(.dist_cache$store[[orf]])
  }

  f <- file.path(dir, paste0(orf, ".fasta.phylip"))
  if (!file.exists(f)) {
    stop("Alignment not found for ", orf, " in ", dir, call. = FALSE)
  }

  d <- phangorn::dist.hamming(phangorn::read.phyDat(f, format = "phylip"))
  .dist_cache$miss <- .dist_cache$miss + 1L

  if (length(.dist_cache$store) >= .dist_cache$max) {
    evict <- .dist_cache$used[1]
    .dist_cache$store[[evict]] <- NULL
    .dist_cache$used <- .dist_cache$used[-1]
  }

  .dist_cache$store[[orf]] <- d
  .dist_cache$used <- c(.dist_cache$used, orf)
  d
}

# -----------------------------------------------------------------------------
# 3. Individuals
# -----------------------------------------------------------------------------

#' Evaluate a candidate ORF set into an individual
#'
#' EN: An individual carries its gene set, the two objective values, and nothing
#'     else. Both objectives are stored raw: `score` is the normalised
#'     Robinson-Foulds distance to the reference tree and `k` is the number of
#'     genes. Rescaling to [0, 1] happens only at reporting time, never inside
#'     the search, because normalising against a moving population makes stored
#'     objective values incomparable between generations and is what made the
#'     published front impossible to recompute.
#'
#' ES: Un individuo lleva su conjunto de genes, los dos valores objetivo, y nada
#'     mas. Los dos objetivos se guardan crudos: `score` es la distancia de
#'     Robinson-Foulds normalizada al arbol de referencia y `k` es el numero de
#'     genes. El reescalado a [0, 1] ocurre solo al reportar, nunca dentro de la
#'     busqueda, porque normalizar contra una poblacion movil vuelve
#'     incomparables los valores objetivo guardados entre generaciones y es lo
#'     que hizo imposible recalcular el frente publicado.
build_individual <- function(genes, reference, dir = PATHS$alignments) {

  genes <- unique(genes)
  if (length(genes) == 0) stop("Empty gene set.", call. = FALSE)

  mat <- NULL
  for (g in genes) {
    d <- gene_distance(g, dir = dir)
    mat <- if (is.null(mat)) d else mat + d
  }

  # Neighbour-joining is invariant to a uniform scaling of the distance matrix,
  # so summing and averaging give the same topology. Summing is kept because it
  # is what the original implementation did.
  tree <- ape::nj(mat)

  list(
    genes = genes,
    k     = length(genes),
    score = as.numeric(phangorn::RF.dist(tree, reference, normalize = TRUE))
  )
}

# -----------------------------------------------------------------------------
# 4. Operators
# -----------------------------------------------------------------------------

random_genes <- function(n, pool) sample(pool, min(n, length(pool)))

#' Replace a fraction of the genes in a set
mutate_genes <- function(genes, rate, pool) {
  n_replace <- max(1L, floor(length(genes) * rate))
  pos       <- sample(seq_along(genes), min(n_replace, length(genes)))
  # Draw replacements from genes not already present, so a mutation always
  # changes the set rather than silently duplicating a gene that unique() then
  # removes, which shrank solutions unintentionally in the original operator.
  candidates <- setdiff(pool, genes)
  if (length(candidates) == 0) return(genes)
  genes[pos] <- sample(candidates, length(pos), replace = FALSE)
  unique(genes)
}

#' Change the size of a gene set, staying within bounds
mutate_length <- function(genes, min_genes, max_genes, pool) {
  delta <- sample(c(-1L, 1L), 1)
  target <- length(genes) + delta
  target <- max(min_genes, min(max_genes, target))
  if (target == length(genes)) return(genes)
  if (target < length(genes)) {
    return(sample(genes, target))
  }
  candidates <- setdiff(pool, genes)
  if (length(candidates) == 0) return(genes)
  unique(c(genes, sample(candidates, target - length(genes))))
}

#' Mutation applied to one individual
mutate_individual <- function(ind, rate, pool, reference,
                              min_genes, max_genes, mutate_size = TRUE,
                              dir = PATHS$alignments) {
  g <- ind$genes
  if (mutate_size) g <- mutate_length(g, min_genes, max_genes, pool)
  g <- mutate_genes(g, rate, pool)
  g <- unique(g)
  if (length(g) > max_genes) g <- sample(g, max_genes)
  if (length(g) < min_genes) {
    g <- unique(c(g, sample(setdiff(pool, g), min_genes - length(g))))
  }
  build_individual(g, reference, dir = dir)
}

#' One-point crossover producing two children
#'
#' EN: The original returned only the child with the lower RF distance,
#'     discarding the other. In a two-objective search that silently biases every
#'     generation toward one objective and against small gene sets, which is the
#'     opposite of what a Pareto search is for. Both children are returned and
#'     survival is decided later by non-dominated sorting, where it belongs.
#' ES: El original devolvia solo el hijo con menor distancia RF y descartaba el
#'     otro. En una busqueda de dos objetivos eso sesga en silencio cada
#'     generacion hacia un objetivo y en contra de los conjuntos chicos, que es lo
#'     contrario de para lo que sirve una busqueda de Pareto. Se devuelven los dos
#'     hijos y la supervivencia la decide despues el ordenamiento no dominado,
#'     que es donde corresponde.
crossover_pair <- function(g1, g2, min_genes, max_genes, pool, reference,
                           dir = PATHS$alignments) {

  if (length(g1) < 2) g1 <- unique(c(g1, sample(setdiff(pool, g1), 1)))
  if (length(g2) < 2) g2 <- unique(c(g2, sample(setdiff(pool, g2), 1)))

  cut1 <- sample(seq_len(length(g1) - 1), 1)
  cut2 <- sample(seq_len(length(g2) - 1), 1)

  clip <- function(g) {
    g <- unique(g)
    if (length(g) > max_genes) g <- sample(g, max_genes)
    if (length(g) < min_genes) {
      g <- unique(c(g, sample(setdiff(pool, g), min_genes - length(g))))
    }
    g
  }

  c1 <- clip(c(g1[seq_len(cut1)], g2[seq.int(cut2 + 1L, length(g2))]))
  c2 <- clip(c(g2[seq_len(cut2)], g1[seq.int(cut1 + 1L, length(g1))]))

  list(build_individual(c1, reference, dir = dir),
       build_individual(c2, reference, dir = dir))
}

# -----------------------------------------------------------------------------
# 5. Dominance
# -----------------------------------------------------------------------------

#' Does a dominate b? Both objectives are minimised.
#'
#' EN: Strict Pareto dominance: at least as good on both objectives and strictly
#'     better on at least one. The original used <= on both and treated the
#'     result as domination, so two identical solutions were reported as one
#'     dominating the other. That is not a rounding detail: in the annealing
#'     acceptance rule it decided which branch was taken.
#' ES: Dominancia de Pareto estricta: al menos igual de buena en los dos
#'     objetivos y estrictamente mejor en al menos uno. El original usaba <= en
#'     ambos y trataba el resultado como dominancia, asi que dos soluciones
#'     identicas se reportaban como una dominando a la otra. No es un detalle de
#'     redondeo: en la regla de aceptacion del recocido decidia que rama se tomaba.
dominates <- function(a, b) {
  (a$score <= b$score && a$k <= b$k) && (a$score < b$score || a$k < b$k)
}

#' Fast non-dominated sorting on a list of individuals
#' EN: Implemented here rather than taken from nsga2R so the pipeline has one
#'     fewer dependency and the dominance rule above is the one actually applied.
#' ES: Implementado aca en vez de tomarlo de nsga2R para que el pipeline tenga
#'     una dependencia menos y para que la regla de dominancia de arriba sea la
#'     que efectivamente se aplica.
non_dominated_sort <- function(pop) {
  n <- length(pop)
  rank <- integer(n)
  dominated_by <- vector("list", n)
  n_dominating <- integer(n)

  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) next
      if (dominates(pop[[i]], pop[[j]])) {
        dominated_by[[i]] <- c(dominated_by[[i]], j)
      } else if (dominates(pop[[j]], pop[[i]])) {
        n_dominating[i] <- n_dominating[i] + 1L
      }
    }
  }

  front <- which(n_dominating == 0L)
  r <- 1L
  while (length(front) > 0) {
    rank[front] <- r
    nxt <- integer(0)
    for (i in front) {
      for (j in dominated_by[[i]]) {
        n_dominating[j] <- n_dominating[j] - 1L
        if (n_dominating[j] == 0L) nxt <- c(nxt, j)
      }
    }
    front <- nxt
    r <- r + 1L
  }
  rank
}

#' Crowding distance within one front
crowding_distance <- function(pop, idx) {
  m <- length(idx)
  if (m <= 2) return(stats::setNames(rep(Inf, m), idx))
  d <- stats::setNames(rep(0, m), idx)
  for (obj in c("score", "k")) {
    v <- vapply(pop[idx], function(x) as.numeric(x[[obj]]), numeric(1))
    o <- order(v)
    d[o[1]] <- Inf
    d[o[m]] <- Inf
    rng <- v[o[m]] - v[o[1]]
    if (rng == 0) next
    for (t in 2:(m - 1)) {
      d[o[t]] <- d[o[t]] + (v[o[t + 1]] - v[o[t - 1]]) / rng
    }
  }
  d
}
