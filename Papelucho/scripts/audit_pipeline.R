# =============================================================================
# audit_pipeline.R
# -----------------------------------------------------------------------------
# EN: Static checks that run without executing the analyses. They catch the two
#     classes of error that actually bit this project during development, both
#     of which fail silently or fail only after a long run:
#
#       CHECK 1  Unresolved function calls.
#                Step 04 once completed thirty minutes of part-of-speech tagging
#                and then died on the final export line because a helper had been
#                renamed in utils_io.R while the job was already running. A call
#                that does not resolve is cheap to detect before starting.
#
#       CHECK 2  Shadowing inside dplyr::summarise().
#                Writing `x = mean(x)` collapses the source column to a scalar
#                for every expression that follows in the same call, so a later
#                `sd(x)` silently returns NA. This is how the sentiment
#                variability results were lost on the first corrected run. The
#                same pattern inside mutate() is harmless and is not flagged.
#
#     Usage:  Rscript scripts/audit_pipeline.R
#     Exit code 1 if any problem is found, so it can gate a commit.
#
# ES: Chequeos estaticos que corren sin ejecutar los analisis. Detectan las dos
#     clases de error que efectivamente golpearon a este proyecto durante el
#     desarrollo, ambas de falla silenciosa o de falla despues de una corrida
#     larga:
#
#       CHEQUEO 1  Llamadas a funciones que no resuelven.
#                  El paso 04 una vez completo treinta minutos de etiquetado
#                  morfosintactico y murio en la linea final de exportacion
#                  porque una funcion auxiliar habia sido renombrada en
#                  utils_io.R mientras el trabajo ya corria. Una llamada que no
#                  resuelve es barata de detectar antes de empezar.
#
#       CHEQUEO 2  Shadowing dentro de dplyr::summarise().
#                  Escribir `x = mean(x)` colapsa la columna fuente a un escalar
#                  para toda expresion posterior de la misma llamada, asi que un
#                  `sd(x)` mas adelante devuelve NA en silencio. Asi se perdieron
#                  los resultados de variabilidad del sentimiento en la primera
#                  corrida corregida. El mismo patron dentro de mutate() es
#                  inofensivo y no se reporta.
#
#     Uso:  Rscript scripts/audit_pipeline.R
#     Codigo de salida 1 si encuentra algun problema, para poder condicionar un
#     commit.
# =============================================================================

UTILS <- c("R/00_config.R", "R/utils_text.R", "R/utils_stats.R",
           "R/utils_io.R", "R/utils_sentiment_es.R")

STEPS <- list.files("R", pattern = "^0[1-9]_.*\\.R$", full.names = TRUE)

problems <- 0L

# -----------------------------------------------------------------------------
# Load the utility environment and every package the pipeline uses
# -----------------------------------------------------------------------------

env <- new.env()
for (f in UTILS) {
  if (!file.exists(f)) {
    message("MISSING utility file: ", f)
    problems <- problems + 1L
    next
  }
  ok <- try(sys.source(f, envir = env), silent = TRUE)
  if (inherits(ok, "try-error")) {
    message("FAILED to source ", f, ": ", attr(ok, "condition")$message)
    problems <- problems + 1L
  }
}
utils_defined <- ls(env)

PKGS <- c("dplyr", "tidyr", "readr", "purrr", "tibble", "stringr", "stringi",
          "ggplot2", "tidytext", "stopwords", "udpipe", "sentimentr", "syuzhet",
          "zoo", "ggdendro", "ggrepel", "uwot", "cluster", "scales")
for (p in PKGS) suppressMessages(try(library(p, character.only = TRUE), silent = TRUE))

# -----------------------------------------------------------------------------
# CHECK 1: every called function resolves
# -----------------------------------------------------------------------------

#' Collect every function name called anywhere in a parsed expression tree
collect_calls <- function(exprs) {
  out <- character()
  rec <- function(x) {
    if (is.call(x)) {
      f <- x[[1]]
      if (is.name(f)) out <<- c(out, as.character(f))
      for (i in seq_along(x)) if (!is.null(x[[i]])) try(rec(x[[i]]), silent = TRUE)
    } else if (is.list(x) || is.pairlist(x)) {
      for (i in seq_along(x)) try(rec(x[[i]]), silent = TRUE)
    }
  }
  for (e in exprs) try(rec(e), silent = TRUE)
  unique(out)
}

#' Collect function names defined anywhere in the file, at any nesting depth
#' EN: Nested helpers defined inside another function are legitimate and must
#'     not be reported as missing.
#' ES: Las funciones auxiliares definidas dentro de otra funcion son legitimas y
#'     no deben reportarse como faltantes.
collect_defs <- function(exprs) {
  out <- character()
  rec <- function(x) {
    if (is.call(x)) {
      if (length(x) >= 3 && is.name(x[[1]]) &&
          as.character(x[[1]]) %in% c("<-", "=", "<<-") &&
          is.name(x[[2]]) && is.call(x[[3]]) &&
          identical(as.character(x[[3]][[1]]), "function")) {
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
  exprs <- try(parse(f), silent = TRUE)
  if (inherits(exprs, "try-error")) {
    message("  PARSE ERROR in ", f, ": ", attr(exprs, "condition")$message)
    problems <- problems + 1L
    next
  }
  local_defs <- collect_defs(exprs)
  missing <- Filter(function(fn) {
    !exists(fn, mode = "function") &&
      !fn %in% utils_defined &&
      !fn %in% local_defs
  }, collect_calls(exprs))

  if (length(missing) > 0) {
    message("  ", basename(f), " -> ", paste(missing, collapse = ", "))
    problems <- problems + length(missing)
  }
}
if (problems == 0L) message("  all calls resolve")

# -----------------------------------------------------------------------------
# CHECK 2: shadowing inside summarise()
# -----------------------------------------------------------------------------

message("\nCHECK 2: shadowing inside dplyr::summarise()")

scan_shadowing <- function(file) {
  hits <- list()
  walk <- function(x) {
    if (is.call(x)) {
      fn <- x[[1]]
      nm <- if (is.name(fn)) as.character(fn)
            else if (is.call(fn) && length(fn) == 3) as.character(fn[[3]])
            else ""
      if (nm %in% c("summarise", "summarize")) {
        args <- as.list(x)[-1]
        nms  <- names(args)
        if (is.null(nms)) nms <- rep("", length(args))
        selfref <- character()
        for (i in seq_along(args)) {
          if (!nzchar(nms[i]) || nms[i] == ".groups") next
          vars <- all.vars(args[[i]])
          # col = f(col) collapses the source column to a scalar
          if (nms[i] %in% vars) selfref <- c(selfref, nms[i])
          later <- setdiff(intersect(vars, selfref), nms[i])
          if (length(later) > 0) {
            hits[[length(hits) + 1]] <- list(col = nms[i], reads = later)
          }
        }
      }
      for (i in seq_along(x)) if (!is.null(x[[i]])) try(walk(x[[i]]), silent = TRUE)
    } else if (is.list(x) || is.pairlist(x)) {
      for (i in seq_along(x)) try(walk(x[[i]]), silent = TRUE)
    }
  }
  exprs <- try(parse(file), silent = TRUE)
  if (inherits(exprs, "try-error")) return(list())
  for (e in exprs) try(walk(e), silent = TRUE)
  hits
}

shadow_count <- 0L
for (f in c(UTILS, STEPS)) {
  if (!file.exists(f)) next
  for (h in scan_shadowing(f)) {
    message("  ", basename(f), ": column \"", h$col,
            "\" reads \"", paste(h$reads, collapse = ", "),
            "\", already collapsed to a scalar in this summarise()")
    shadow_count <- shadow_count + 1L
  }
}
problems <- problems + shadow_count
if (shadow_count == 0L) message("  no dangerous shadowing found")

# -----------------------------------------------------------------------------
# CHECK 3: metric keys used in tables have bilingual labels
# -----------------------------------------------------------------------------
# EN: A metric with no entry in LABELS falls back to its raw key, which produces
#     a column such as "pct_long_sentences" in a printed Spanish table. Not a
#     crash, but it is the difference between a table that is genuinely
#     bilingual and one that only has a translated caption.
# ES: Una metrica sin entrada en LABELS cae de vuelta a su clave cruda, lo que
#     produce una columna como "pct_long_sentences" en una tabla impresa en
#     espanol. No es una caida, pero es la diferencia entre una tabla de verdad
#     bilingue y una que solo tiene el pie traducido.

message("\nCHECK 3: metric labels present in both languages")

results_csv <- list.files(file.path("outputs", "tables"),
                          pattern = "_results.*\\.csv$", full.names = TRUE)

if (length(results_csv) == 0) {
  message("  no result tables yet; run the pipeline first")
} else {
  untranslated <- character()
  for (f in results_csv) {
    d <- try(utils::read.csv(f, stringsAsFactors = FALSE), silent = TRUE)
    if (inherits(d, "try-error") || !"metric" %in% names(d)) next
    untranslated <- c(untranslated, setdiff(d$metric, env$LABELS$key))
  }
  untranslated <- unique(untranslated)
  if (length(untranslated) > 0) {
    message("  metrics with no bilingual label: ",
            paste(untranslated, collapse = ", "))
    problems <- problems + length(untranslated)
  } else {
    message("  every reported metric has an English and a Spanish label")
  }
}

# -----------------------------------------------------------------------------

message("\n", strrep("-", 60))
if (problems == 0L) {
  message("AUDIT PASSED")
} else {
  message("AUDIT FAILED: ", problems, " problem(s)")
  quit(status = 1)
}
