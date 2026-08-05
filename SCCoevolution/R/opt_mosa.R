# =============================================================================
# opt_mosa.R
# -----------------------------------------------------------------------------
# EN: Multi-objective simulated annealing, the comparison baseline for NSGA-II.
#     Sourcing this file defines the function and runs nothing.
#
#     THE TEMPERATURE BUG THIS FIXES
#     In the original simAnnMO.r the acceptance test was a separate top-level
#     function:
#
#         checkTemperature <- function(deltaE){ prob = exp((-deltaE/T)); ... }
#         simulatedAnnealingMO <- function(..., T, alpha, ...){ ... T = T * alpha }
#
#     R scopes lexically, so the `T` inside checkTemperature does not resolve to
#     the local `T` of simulatedAnnealingMO. It resolves in the global
#     environment, where `T` is R's built-in alias for TRUE, that is 1. The
#     cooling schedule updated a local variable the acceptance rule never read.
#
#     Measured effect: with T = 1000 and alpha = 0.8 the acceptance function sees
#     1 at every iteration. For an energy gap of 5 the acceptance probability was
#     0.0067 instead of 0.995, roughly 150 times smaller. The annealing therefore
#     behaved as a near-pure hill climber with no mechanism for escaping local
#     optima, which matters because this is the baseline NSGA-II is compared
#     against.
#
#     Here the temperature is an explicit argument to the acceptance function,
#     the cooling schedule is applied to the value actually used, and the
#     temperature trace is returned so the schedule can be inspected rather than
#     assumed.
#
# ES: Recocido simulado multiobjetivo, la linea base de comparacion para NSGA-II.
#     Cargar este archivo define la funcion y no ejecuta nada.
#
#     EL BUG DE TEMPERATURA QUE ESTO CORRIGE
#     En el simAnnMO.r original la prueba de aceptacion era una funcion separada
#     de nivel superior. R usa alcance lexico, asi que la `T` dentro de
#     checkTemperature no resuelve a la `T` local de simulatedAnnealingMO.
#     Resuelve en el entorno global, donde `T` es el alias de R para TRUE, o sea
#     1. El enfriamiento actualizaba una variable local que la regla de
#     aceptacion nunca leia.
#
#     Efecto medido: con T = 1000 y alpha = 0,8 la funcion de aceptacion ve 1 en
#     cada iteracion. Para una brecha de energia de 5 la probabilidad de
#     aceptacion fue 0,0067 en vez de 0,995, unas 150 veces menor. El recocido se
#     comporto entonces como un hill climber casi puro, sin mecanismo de escape de
#     optimos locales, lo que importa porque esta es la linea base contra la que
#     se compara NSGA-II.
#
#     Aca la temperatura es un argumento explicito de la funcion de aceptacion, el
#     enfriamiento se aplica al valor que efectivamente se usa, y la traza de
#     temperatura se devuelve para poder inspeccionar el esquema en vez de
#     asumirlo.
# =============================================================================

#' Metropolis acceptance probability
#' @param delta energy increase; positive means the move is worse
#' @param temperature current temperature, passed explicitly
accept_worse <- function(delta, temperature) {
  if (temperature <= 0) return(FALSE)
  stats::runif(1) < exp(-delta / temperature)
}

#' Run multi-objective simulated annealing
#'
#' @param outer_loops number of temperature reductions
#' @param inner_loops iterations per temperature
#' @param mutation_rate fraction of genes replaced per move
#' @param temperature initial temperature
#' @param alpha cooling factor, temperature <- temperature * alpha
#' @param seed integer seed; required, not optional
mosa_orf <- function(outer_loops,
                     inner_loops,
                     mutation_rate,
                     temperature,
                     alpha,
                     min_genes = 1L,
                     max_genes = 22L,
                     pool,
                     reference,
                     seed,
                     seed_solution = NULL,
                     dir = PATHS$alignments,
                     verbose = TRUE) {

  set.seed(seed)

  current <- if (is.null(seed_solution)) {
    build_individual(random_genes(sample(seq.int(min_genes, max_genes), 1), pool),
                     reference, dir = dir)
  } else {
    build_individual(seed_solution, reference, dir = dir)
  }

  # EN: An archive of non-dominated solutions is kept. The original returned a
  #     single current solution, which is not a Pareto front and cannot be
  #     compared to NSGA-II's front on hypervolume without one.
  # ES: Se mantiene un archivo de soluciones no dominadas. El original devolvia
  #     una sola solucion actual, que no es un frente de Pareto y sin el no se
  #     puede comparar con el frente de NSGA-II por hipervolumen.
  archive <- list(current)

  update_archive <- function(archive, cand) {
    if (any(vapply(archive, function(a) dominates(a, cand), logical(1)))) return(archive)
    archive <- archive[!vapply(archive, function(a) dominates(cand, a), logical(1))]
    keys <- vapply(archive, function(a) paste(sort(a$genes), collapse = " "), character(1))
    ck   <- paste(sort(cand$genes), collapse = " ")
    if (ck %in% keys) return(archive)
    c(archive, list(cand))
  }

  history <- list()
  temp    <- temperature
  step    <- 0L

  for (i in seq_len(outer_loops)) {
    for (j in seq_len(inner_loops)) {

      step <- step + 1L
      candidate <- mutate_individual(current, mutation_rate, pool, reference,
                                     min_genes, max_genes, dir = dir)

      if (dominates(candidate, current)) {
        current <- candidate
        move <- "accept_dominating"
      } else if (dominates(current, candidate)) {
        # Worse move: accept with the Metropolis probability at the current
        # temperature, which is now the temperature the schedule is cooling.
        delta <- (candidate$score - current$score) +
          (candidate$k - current$k) / max_genes
        if (accept_worse(delta, temp)) {
          current <- candidate
          move <- "accept_worse"
        } else {
          move <- "reject"
        }
      } else {
        # Mutually non-dominated: accept, which is what keeps the walk exploring
        # along the front rather than collapsing onto one objective.
        current <- candidate
        move <- "accept_nondominated"
      }

      archive <- update_archive(archive, current)

      history[[step]] <- data.frame(
        step = step, outer = i, inner = j, temperature = temp,
        score = current$score, k = current$k, move = move,
        archive_size = length(archive), stringsAsFactors = FALSE
      )
    }

    temp <- temp * alpha

    if (verbose && (i %% 5 == 0 || i == outer_loops)) {
      message(sprintf("    outer %2d/%d | T %.3g | archive %2d | best RF %.4f",
                      i, outer_loops, temp, length(archive),
                      min(vapply(archive, function(a) a$score, numeric(1)))))
    }
  }

  list(
    front     = archive,
    history   = do.call(rbind, history),
    algorithm = "MOSA",
    seed      = seed,
    params    = list(outer_loops = outer_loops, inner_loops = inner_loops,
                     mutation_rate = mutation_rate,
                     temperature = temperature, alpha = alpha,
                     min_genes = min_genes, max_genes = max_genes,
                     pool_size = length(pool))
  )
}
