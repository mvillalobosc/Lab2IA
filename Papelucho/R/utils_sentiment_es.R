# =============================================================================
# utils_sentiment_es.R
# -----------------------------------------------------------------------------
# EN: Spanish sentiment resources for sentimentr.
#
#     THE PROBLEM THIS SOLVES
#     Calling sentimentr::sentiment() without arguments uses the Jockers-Rinker
#     polarity table, which is English. Applied to Spanish it scores almost
#     everything at zero, with occasional spurious hits on words that happen to
#     be spelled the same in both languages. The failure is silent: the function
#     returns numbers, they are just all wrong. Scoring "me siento muy feliz y
#     contento hoy" with the default table returns exactly 0.00.
#
#     WHAT IS BUILT HERE
#       * A polarity table derived from the Spanish NRC emotion lexicon bundled
#         with syuzhet, so no download is needed and the pipeline runs offline.
#         Words marked positive score +1, negative -1, words marked both are
#         dropped as unusable.
#       * A valence shifter table, which sentimentr needs to handle negation and
#         intensification. Without it, "no me gusta" scores as positive. The
#         four shifter classes sentimentr expects are:
#             1 negator        (no, nunca, jamas, tampoco)
#             2 amplifier      (muy, mucho, demasiado, totalmente)
#             3 de-amplifier   (apenas, casi, poco, ligeramente)
#             4 adversative    (pero, aunque, sin embargo)
#         There is no published Spanish shifter list for sentimentr, so this one
#         is assembled from the standard Spanish grammar of negation and degree
#         modification. It is a limitation and is stated as such in the README.
#
#     A NOTE ON SCOPE
#     The NRC Spanish lexicon is itself a machine translation of the English
#     original. It therefore inherits translation errors and misses Chilean
#     usage entirely, which matters for a corpus built on Chilean children's
#     literature. Results from this module should be read as a coarse signal,
#     not as a precise measurement, and the README says so.
#
# ES: Recursos de sentimiento en espanol para sentimentr.
#
#     EL PROBLEMA QUE RESUELVE
#     Llamar a sentimentr::sentiment() sin argumentos usa la tabla de polaridad
#     de Jockers-Rinker, que es inglesa. Aplicada al espanol puntua casi todo en
#     cero, con aciertos espurios ocasionales en palabras que se escriben igual
#     en los dos idiomas. La falla es silenciosa: la funcion devuelve numeros,
#     solo que todos estan mal. Puntuar "me siento muy feliz y contento hoy" con
#     la tabla por defecto devuelve exactamente 0,00.
#
#     QUE SE CONSTRUYE ACA
#       * Una tabla de polaridad derivada del lexico de emociones NRC en espanol
#         que viene con syuzhet, asi no hace falta descargar nada y el pipeline
#         corre sin conexion. Las palabras marcadas positivas puntuan +1, las
#         negativas -1, y las marcadas en ambas se descartan por inutilizables.
#       * Una tabla de valence shifters, que sentimentr necesita para manejar
#         negacion e intensificacion. Sin ella, "no me gusta" puntua positivo.
#         Las cuatro clases que sentimentr espera son:
#             1 negador        (no, nunca, jamas, tampoco)
#             2 amplificador   (muy, mucho, demasiado, totalmente)
#             3 desamplificador(apenas, casi, poco, ligeramente)
#             4 adversativo    (pero, aunque, sin embargo)
#         No existe una lista publicada de shifters en espanol para sentimentr,
#         asi que esta se armo desde la gramatica estandar de la negacion y la
#         modificacion de grado del espanol. Es una limitacion y se declara como
#         tal en el README.
#
#     NOTA SOBRE EL ALCANCE
#     El lexico NRC en espanol es a su vez una traduccion automatica del original
#     ingles. Por lo tanto hereda errores de traduccion y no cubre el uso chileno,
#     lo que importa en un corpus construido sobre literatura infantil chilena.
#     Los resultados de este modulo deben leerse como una senal gruesa, no como
#     una medicion precisa, y el README lo dice.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})

# -----------------------------------------------------------------------------
# 1. Valence shifters
# -----------------------------------------------------------------------------
# EN: sentimentr expects the codes 1 negator, 2 amplifier, 3 de-amplifier,
#     4 adversative conjunction, supplied as character.
# ES: sentimentr espera los codigos 1 negador, 2 amplificador, 3
#     desamplificador, 4 conjuncion adversativa, entregados como caracter.

spanish_valence_shifters <- function() {

  negators <- c(
    "no", "ni", "nunca", "jamas", "jam\u00e1s", "tampoco", "nada", "nadie",
    "ninguno", "ninguna", "ning\u00fan", "sin", "apenas si", "para nada"
  )

  amplifiers <- c(
    "muy", "mucho", "mucha", "muchos", "muchas", "demasiado", "demasiada",
    "bastante", "tan", "tanto", "tanta", "sumamente", "extremadamente",
    "realmente", "verdaderamente", "totalmente", "completamente",
    "absolutamente", "profundamente", "enormemente", "terriblemente",
    "increiblemente", "incre\u00edblemente", "super", "s\u00faper", "recontra",
    "harto", "harta", "requete", "purito", "purita"
  )

  de_amplifiers <- c(
    "apenas", "casi", "poco", "poca", "algo", "ligeramente", "levemente",
    "medio", "media", "escasamente", "minimamente", "m\u00ednimamente",
    "relativamente", "parcialmente", "un poco", "medio que"
  )

  adversatives <- c(
    "pero", "aunque", "sin embargo", "no obstante", "salvo", "excepto",
    "a pesar de", "pese a", "en cambio"
  )

  data.frame(
    x = enc2utf8(c(negators, amplifiers, de_amplifiers, adversatives)),
    y = as.character(c(
      rep(1L, length(negators)),
      rep(2L, length(amplifiers)),
      rep(3L, length(de_amplifiers)),
      rep(4L, length(adversatives))
    )),
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------------------------
# 2. Polarity table
# -----------------------------------------------------------------------------

#' Build a Spanish polarity table for sentimentr
#'
#' EN: Derived from the Spanish rows of the NRC lexicon shipped inside syuzhet.
#'     Words tagged both positive and negative carry no usable signal and are
#'     removed. Words that also appear in the valence shifter table are removed
#'     from the polarity table, because sentimentr requires the two tables to be
#'     disjoint and will refuse to run otherwise. The overlap is small and
#'     consists of degree words such as "nada" and "bastante" whose shifter role
#'     is the more important of the two.
#' ES: Derivada de las filas en espanol del lexico NRC incluido en syuzhet. Las
#'     palabras etiquetadas como positivas y negativas a la vez no aportan senal
#'     utilizable y se eliminan. Las palabras que ademas aparecen en la tabla de
#'     valence shifters se eliminan de la tabla de polaridad, porque sentimentr
#'     exige que las dos tablas sean disjuntas y se niega a correr si no lo son.
#'     El solapamiento es pequeno y consiste en palabras de grado como "nada" y
#'     "bastante", cuyo rol de shifter es el mas importante de los dos.
build_spanish_polarity <- function(verbose = TRUE) {

  if (!requireNamespace("syuzhet", quietly = TRUE)) {
    stop("Package 'syuzhet' is required to build the Spanish polarity table.",
         call. = FALSE)
  }

  nrc <- syuzhet:::nrc

  es <- nrc %>%
    dplyr::filter(
      lang == "spanish",
      value == 1,
      sentiment %in% c("positive", "negative")
    ) %>%
    dplyr::mutate(score = ifelse(sentiment == "positive", 1, -1)) %>%
    dplyr::group_by(word) %>%
    dplyr::summarise(y = mean(score), .groups = "drop")

  n_raw <- nrow(es)

  # Ambiguous entries: tagged both positive and negative, mean exactly zero.
  n_ambiguous <- sum(es$y == 0)
  es <- es %>% dplyr::filter(y != 0)

  polarity <- data.frame(
    x = enc2utf8(stringr::str_to_lower(es$word)),
    y = es$y,
    stringsAsFactors = FALSE
  )
  polarity <- polarity[!duplicated(polarity$x), ]

  shifters <- spanish_valence_shifters()
  overlap  <- intersect(polarity$x, shifters$x)
  polarity <- polarity[!polarity$x %in% shifters$x, ]

  if (verbose) {
    message(sprintf(
      "[sentiment-es] polarity terms: %d (from %d NRC entries; %d ambiguous and %d shifter-overlapping removed)",
      nrow(polarity), n_raw, n_ambiguous, length(overlap)
    ))
    if (length(overlap) > 0) {
      message("[sentiment-es] removed from polarity because they act as valence shifters: ",
              paste(overlap, collapse = ", "))
    }
  }

  polarity
}

#' Return both tables in the hashed form sentimentr expects
#' EN: as_key builds the data.table with the key set. sentiment = FALSE tells it
#'     the table holds shifter codes rather than polarity scores.
#' ES: as_key construye el data.table con la clave puesta. sentiment = FALSE le
#'     indica que la tabla tiene codigos de shifter y no puntajes de polaridad.
spanish_sentiment_keys <- function(verbose = TRUE) {

  if (!requireNamespace("sentimentr", quietly = TRUE)) {
    stop("Package 'sentimentr' is required.", call. = FALSE)
  }

  polarity <- build_spanish_polarity(verbose = verbose)
  shifters <- spanish_valence_shifters()

  list(
    polarity_dt         = sentimentr::as_key(polarity, comparison = NULL),
    valence_shifters_dt = sentimentr::as_key(shifters, comparison = NULL,
                                             sentiment = FALSE)
  )
}

# -----------------------------------------------------------------------------
# 3. Self-test
# -----------------------------------------------------------------------------

#' Verify the Spanish tables behave correctly on known cases
#'
#' EN: Run before any analysis. It checks that a plainly positive sentence
#'     scores positive, a plainly negative one negative, a negated positive one
#'     is pulled down, and a neutral one scores zero. If the English default
#'     table were being used by mistake, the first assertion would fail
#'     immediately, which is exactly the failure the original pipeline missed.
#' ES: Se corre antes de cualquier analisis. Verifica que una frase claramente
#'     positiva puntue positivo, una claramente negativa puntue negativo, una
#'     positiva negada baje, y una neutra puntue cero. Si por error se estuviera
#'     usando la tabla inglesa por defecto, la primera afirmacion fallaria de
#'     inmediato, que es justamente la falla que el pipeline original no detecto.
test_spanish_sentiment <- function(keys, verbose = TRUE) {

  cases <- data.frame(
    text = enc2utf8(c(
      "me siento muy feliz y contento hoy",
      "fue un dia terrible y triste",
      "no me siento feliz para nada",
      "el perro corrio por el parque"
    )),
    expectation = c("positive", "negative", "below the positive case", "neutral"),
    stringsAsFactors = FALSE
  )

  scored <- sentimentr::sentiment(
    sentimentr::get_sentences(cases$text),
    polarity_dt         = keys$polarity_dt,
    valence_shifters_dt = keys$valence_shifters_dt
  )

  vals <- as.data.frame(scored)$sentiment
  cases$score <- vals

  if (verbose) {
    message("[sentiment-es] self-test:")
    for (i in seq_len(nrow(cases))) {
      message(sprintf("    %-38s %+.4f   (expected %s)",
                      cases$text[i], cases$score[i], cases$expectation[i]))
    }
  }

  ok <- vals[1] > 0 && vals[2] < 0 && vals[3] < vals[1] && abs(vals[4]) < 1e-8

  if (!ok) {
    stop(
      "Spanish sentiment self-test failed. The lexicon is not scoring Spanish correctly; ",
      "do not interpret any sentiment results until this is fixed.",
      call. = FALSE
    )
  }

  invisible(cases)
}
