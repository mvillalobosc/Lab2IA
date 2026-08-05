# =============================================================================
# opt_nsga2.R
# -----------------------------------------------------------------------------
# EN: NSGA-II for ORF subset selection. Sourcing this file defines the function
#     and runs nothing. The original nsga2.r launched a full nineteen-generation
#     experiment on its last line, with hard-coded Windows paths, so simply
#     sourcing it from main.r started an unwanted run before main.r had done
#     anything.
#
#     The full search history is returned, not just the final front. Without it
#     the objective normalisation applied at plotting time cannot be inverted,
#     which is why the published front coordinates could not be recomputed from
#     the released data.
#
# ES: NSGA-II para seleccion de subconjuntos de ORFs. Cargar este archivo define
#     la funcion y no ejecuta nada. El nsga2.r original lanzaba un experimento
#     completo de diecinueve generaciones en su ultima linea, con rutas de
#     Windows escritas a mano, asi que solo cargarlo desde main.r arrancaba una
#     corrida no deseada antes de que main.r hiciera nada.
#
#     Se devuelve el historial completo de busqueda, no solo el frente final. Sin
#     el, la normalizacion de objetivos que se aplica al graficar no se puede
#     invertir, que es por lo que las coordenadas del frente publicado no se
#     pudieron recalcular desde los datos liberados.
# =============================================================================

#' Run NSGA-II
#'
#' @param generations number of generations
#' @param pop_size population size
#' @param mutation_rate fraction of genes replaced by a mutation
#' @param min_genes,max_genes bounds on solution size
#' @param pool character vector of ORF names to search over
#' @param reference reference tree
#' @param seed integer seed; set explicitly so a run is reproducible
#' @param seed_solution optional character vector of ORF names to seed the
#'   population with
nsga2_orf <- function(generations,
                      pop_size,
                      mutation_rate,
                      min_genes = 1L,
                      max_genes = 22L,
                      pool,
                      reference,
                      seed,
                      seed_solution = NULL,
                      dir = PATHS$alignments,
                      verbose = TRUE) {

  # EN: The seed is a required argument rather than an optional convenience.
  #     The original set no seed anywhere and ran under foreach %dopar% without
  #     doRNG, so no run could be repeated even on the same machine.
  # ES: La semilla es un argumento obligatorio y no una conveniencia opcional. El
  #     original no fijaba semilla en ninguna parte y corria bajo foreach %dopar%
  #     sin doRNG, asi que ninguna corrida se podia repetir ni en la misma
  #     maquina.
  set.seed(seed)

  make_random <- function() {
    k <- sample(seq.int(min_genes, max_genes), 1)
    build_individual(random_genes(k, pool), reference, dir = dir)
  }

  # --- Initial population ---------------------------------------------------
  parents <- vector("list", pop_size)
  if (is.null(seed_solution)) {
    for (i in seq_len(pop_size)) parents[[i]] <- make_random()
  } else {
    parents[[1]] <- build_individual(seed_solution, reference, dir = dir)
    for (i in seq.int(2, pop_size)) {
      parents[[i]] <- mutate_individual(parents[[1]], mutation_rate, pool,
                                        reference, min_genes, max_genes,
                                        dir = dir)
    }
  }

  history <- list()

  for (g in seq_len(generations)) {

    # --- Offspring ----------------------------------------------------------
    offspring <- list()
    while (length(offspring) < pop_size) {
      pick <- sample(seq_len(pop_size), 2)
      kids <- crossover_pair(parents[[pick[1]]]$genes, parents[[pick[2]]]$genes,
                             min_genes, max_genes, pool, reference, dir = dir)
      kids <- lapply(kids, function(k)
        if (stats::runif(1) < mutation_rate) {
          mutate_individual(k, mutation_rate, pool, reference,
                            min_genes, max_genes, dir = dir)
        } else k)
      offspring <- c(offspring, kids)
    }
    offspring <- offspring[seq_len(pop_size)]

    # --- Environmental selection -------------------------------------------
    population <- c(parents, offspring)
    rank <- non_dominated_sort(population)

    crowd <- rep(0, length(population))
    for (r in sort(unique(rank))) {
      idx <- which(rank == r)
      crowd[idx] <- crowding_distance(population, idx)
    }

    history[[g]] <- data.frame(
      generation = g,
      individual = seq_along(population),
      score      = vapply(population, function(x) x$score, numeric(1)),
      k          = vapply(population, function(x) x$k, integer(1)),
      rank       = rank,
      crowding   = crowd,
      genes      = vapply(population, function(x) paste(sort(x$genes), collapse = " "),
                          character(1)),
      stringsAsFactors = FALSE
    )

    if (g < generations) {
      ord <- order(rank, -crowd)
      parents <- population[ord[seq_len(pop_size)]]
    } else {
      final <- population[rank == 1]
    }

    if (verbose && (g %% 5 == 0 || g == generations)) {
      f1 <- which(rank == 1)
      message(sprintf("    gen %2d/%d | front size %2d | best RF %.4f | k range %d-%d",
                      g, generations, length(f1),
                      min(vapply(population[f1], function(x) x$score, numeric(1))),
                      min(vapply(population[f1], function(x) x$k, integer(1))),
                      max(vapply(population[f1], function(x) x$k, integer(1)))))
    }
  }

  # EN: Duplicate gene sets on the final front are collapsed. Crossover and
  #     mutation can converge two lineages onto the same subset, and reporting it
  #     twice inflates the apparent size of the front.
  # ES: Los conjuntos de genes duplicados del frente final se colapsan. El cruce
  #     y la mutacion pueden hacer converger dos linajes al mismo subconjunto, y
  #     reportarlo dos veces infla el tamano aparente del frente.
  keys  <- vapply(final, function(x) paste(sort(x$genes), collapse = " "), character(1))
  final <- final[!duplicated(keys)]

  list(
    front     = final,
    history   = do.call(rbind, history),
    algorithm = "NSGA-II",
    seed      = seed,
    params    = list(generations = generations, pop_size = pop_size,
                     mutation_rate = mutation_rate,
                     min_genes = min_genes, max_genes = max_genes,
                     pool_size = length(pool))
  )
}
