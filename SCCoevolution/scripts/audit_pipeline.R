# =============================================================================
# audit_pipeline.R
# -----------------------------------------------------------------------------
# EN: Static checks that run in seconds without executing any analysis. They
#     catch the classes of error that cost the most time in this project:
#       1  a call to a function that does not exist, which otherwise surfaces
#          only after a long run has already finished its expensive part;
#       2  shadowing inside dplyr::summarise(), where `x = f(x)` collapses the
#          source column to a scalar and every later expression silently returns
#          NA;
#       3  a module that executes an experiment when sourced, which is how the
#          original nsga2.r and simAnnMO.r launched unwanted runs.
#
#     Usage:  Rscript scripts/audit_pipeline.R
#     Exit code 1 on any problem, so it can gate a commit.
#
# ES: Chequeos estaticos que corren en segundos sin ejecutar ningun analisis.
#     Detectan las clases de error que mas tiempo costaron en este proyecto:
#       1  una llamada a una funcion que no existe, que si no aparece recien
#          despues de que una corrida larga ya hizo su parte cara;
#       2  shadowing dentro de dplyr::summarise(), donde `x = f(x)` colapsa la
#          columna fuente a un escalar y toda expresion posterior devuelve NA en
#          silencio;
#       3  un modulo que ejecuta un experimento al ser cargado, que es como el
#          nsga2.r y el simAnnMO.r originales lanzaban corridas no deseadas.
# =============================================================================

UTILS <- c("R/00_config.R", "R/utils_solutions.R", "R/utils_objectives.R",
           "R/opt_operators.R", "R/opt_nsga2.R", "R/opt_mosa.R")
STEPS <- list.files("R", pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE)

problems <- 0L

env <- new.env()
for (f in UTILS) {
  if (!file.exists(f)) { message("MISSING: ", f); problems <- problems + 1L; next }
  ok <- try(sys.source(f, envir = env), silent = TRUE)
  if (inherits(ok, "try-error")) {
    message("FAILED to source ", f, ": ", attr(ok, "condition")$message)
    problems <- problems + 1L
  }
}
utils_defined <- ls(env)

for (p in c("readr","dplyr","tidyr","stringr","ggplot2","ape","phangorn",
            "RColorBrewer","UpSetR","plotly","tibble")) {
  suppressMessages(try(library(p, character.only = TRUE), silent = TRUE))
}

collect <- function(exprs, what = c("calls","defs")) {
  what <- match.arg(what); out <- character()
  rec <- function(x) {
    if (is.call(x)) {
      if (what == "calls" && is.name(x[[1]])) out <<- c(out, as.character(x[[1]]))
      if (what == "defs" && length(x) >= 3 && is.name(x[[1]]) &&
          as.character(x[[1]]) %in% c("<-","=","<<-") && is.name(x[[2]]) &&
          is.call(x[[3]]) && identical(as.character(x[[3]][[1]]), "function")) {
        out <<- c(out, as.character(x[[2]]))
      }
      for (i in seq_along(x)) if (!is.null(x[[i]])) try(rec(x[[i]]), silent = TRUE)
    } else if (is.list(x) || is.pairlist(x)) {
      for (i in seq_along(x)) try(rec(x[[i]]), silent = TRUE)
    }
  }
  for (e in exprs) try(rec(e), silent = TRUE)
  unique(out)
}

message("\nCHECK 1: unresolved function calls")
for (f in c(UTILS, STEPS, "run_all.R")) {
  if (!file.exists(f)) next
  ex <- try(parse(f), silent = TRUE)
  if (inherits(ex, "try-error")) {
    message("  PARSE ERROR in ", f); problems <- problems + 1L; next
  }
  miss <- Filter(function(fn) !exists(fn, mode = "function") &&
                   !fn %in% utils_defined && !fn %in% collect(ex, "defs"),
                 collect(ex, "calls"))
  if (length(miss)) { message("  ", basename(f), " -> ", paste(miss, collapse = ", "))
    problems <- problems + length(miss) }
}
if (problems == 0L) message("  all calls resolve")

message("\nCHECK 2: shadowing inside dplyr::summarise()")
shadow <- 0L
for (f in c(UTILS, STEPS)) {
  if (!file.exists(f)) next
  ex <- try(parse(f), silent = TRUE); if (inherits(ex, "try-error")) next
  walk <- function(x) {
    if (is.call(x)) {
      fn <- x[[1]]
      nm <- if (is.name(fn)) as.character(fn)
            else if (is.call(fn) && length(fn) == 3) as.character(fn[[3]]) else ""
      if (nm %in% c("summarise","summarize")) {
        a <- as.list(x)[-1]; nms <- names(a); if (is.null(nms)) nms <- rep("", length(a))
        self <- character()
        for (i in seq_along(a)) {
          if (!nzchar(nms[i]) || nms[i] == ".groups") next
          v <- all.vars(a[[i]])
          if (nms[i] %in% v) self <- c(self, nms[i])
          later <- setdiff(intersect(v, self), nms[i])
          if (length(later)) {
            message("  ", basename(f), ": \"", nms[i], "\" reads \"",
                    paste(later, collapse = ", "), "\", already collapsed to a scalar")
            shadow <<- shadow + 1L
          }
        }
      }
      for (i in seq_along(x)) if (!is.null(x[[i]])) try(walk(x[[i]]), silent = TRUE)
    } else if (is.list(x) || is.pairlist(x)) {
      for (i in seq_along(x)) try(walk(x[[i]]), silent = TRUE)
    }
  }
  for (e in ex) try(walk(e), silent = TRUE)
}
problems <- problems + shadow
if (shadow == 0L) message("  no dangerous shadowing found")

message("\nCHECK 3: algorithm modules must not execute on source")
side <- 0L
for (f in c("R/opt_operators.R", "R/opt_nsga2.R", "R/opt_mosa.R",
            "R/utils_solutions.R", "R/utils_objectives.R")) {
  if (!file.exists(f)) next
  ex <- try(parse(f), silent = TRUE); if (inherits(ex, "try-error")) next
  for (e in ex) {
    is_assign <- is.call(e) && is.name(e[[1]]) &&
      as.character(e[[1]]) %in% c("<-", "=", "<<-")
    is_lib <- is.call(e) && is.name(e[[1]]) &&
      as.character(e[[1]]) %in% c("library","require","suppressPackageStartupMessages",
                                  "source","if","for","setClass","invisible")
    if (!is_assign && !is_lib) {
      message("  ", basename(f), ": top-level call ",
              if (is.call(e)) paste0(deparse(e[[1]]), "()") else "expression",
              " runs when the file is sourced")
      side <- side + 1L
    }
  }
}
problems <- problems + side
if (side == 0L) message("  modules only define; nothing executes on source")

message("\n", strrep("-", 60))
if (problems == 0L) message("AUDIT PASSED") else {
  message("AUDIT FAILED: ", problems, " problem(s)"); quit(status = 1)
}
