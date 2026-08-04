# =============================================================================
# utils_text.R
# -----------------------------------------------------------------------------
# EN: Spanish-specific text utilities: reading, normalisation, sentence
#     segmentation, tokenisation and syllable counting.
# ES: Utilidades de texto especificas del espanol: lectura, normalizacion,
#     segmentacion en oraciones, tokenizacion y conteo de silabas.
#
# DESIGN RULE / REGLA DE DISENO
# EN: The pipeline keeps TWO representations of every book and never mixes them.
#       * raw     : the original text, punctuation and function words intact.
#                   Used for anything that depends on syntax or sentence
#                   structure: readability, POS tagging, sentiment.
#       * content : lowercased content words with stopwords removed.
#                   Used only for lexical diversity and stylometry.
#     Mixing the two is what invalidated the original analysis: sentence counts
#     were taken from the raw text while token counts came from the stripped
#     text, which halved every words-per-sentence figure.
# ES: El pipeline mantiene DOS representaciones de cada libro y nunca las mezcla.
#       * raw     : el texto original, con puntuacion y palabras funcionales.
#                   Se usa para todo lo que depende de sintaxis o estructura de
#                   oracion: legibilidad, etiquetado POS, sentimiento.
#       * content : palabras de contenido en minuscula, sin stopwords.
#                   Se usa solo para diversidad lexica y estilometria.
#     Mezclarlas fue lo que invalido el analisis original: las oraciones se
#     contaban sobre el texto crudo y los tokens sobre el texto filtrado, lo que
#     dividia por dos toda cifra de palabras por oracion.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(stringi)
  library(readr)
  library(purrr)
})

# -----------------------------------------------------------------------------
# 1. Reading
# -----------------------------------------------------------------------------

#' Read a plain-text file as UTF-8 with normalised line endings
#' EN: Files produced on Windows carry CRLF endings; leaving them in breaks
#'     regular expressions that anchor on \n and inflates character counts.
#' ES: Los archivos hechos en Windows traen finales CRLF; dejarlos rompe las
#'     expresiones regulares ancladas en \n e infla el conteo de caracteres.
read_text_utf8 <- function(path) {
  txt <- readr::read_file(path, locale = readr::locale(encoding = "UTF-8"))
  txt <- stringi::stri_trans_nfc(txt)          # canonical Unicode composition
  txt <- stringr::str_replace_all(txt, "\r\n", "\n")
  txt <- stringr::str_replace_all(txt, "\r", "\n")
  txt
}

# -----------------------------------------------------------------------------
# 2. Normalisation
# -----------------------------------------------------------------------------

# EN: Spanish alphabet including accented vowels, diaeresis and enye.
# ES: Alfabeto espanol con vocales acentuadas, dieresis y enye.
SPANISH_LETTERS <- "a-zA-Z\u00e1\u00e9\u00ed\u00f3\u00fa\u00c1\u00c9\u00cd\u00d3\u00da\u00fc\u00dc\u00f1\u00d1"

#' Collapse whitespace and normalise typographic characters
#' EN: Curly quotes, ellipses and various dashes are mapped to ASCII
#'     equivalents so that sentence splitting behaves consistently across
#'     books digitised by different sources.
#' ES: Comillas tipograficas, puntos suspensivos y distintos guiones se mapean a
#'     equivalentes ASCII para que la segmentacion en oraciones se comporte
#'     igual en libros digitalizados por fuentes distintas.
normalise_typography <- function(x) {
  x %>%
    stringr::str_replace_all("[\u2018\u2019\u201b\u2032]", "'") %>%
    stringr::str_replace_all("[\u201c\u201d\u201f\u2033]", '"') %>%
    stringr::str_replace_all("\u2026", "...") %>%
    stringr::str_replace_all("[\u2010\u2011\u2012\u2013\u2014\u2015]", "-") %>%
    stringr::str_replace_all("\u00a0", " ") %>%
    stringr::str_replace_all("[ \t]+", " ")
}

#' Build the "raw" analysis representation
#' EN: Keeps punctuation, capitalisation and function words. Only joins
#'     hyphenated line breaks and collapses blank lines, so sentence-level
#'     statistics stay faithful to the printed text.
#' ES: Conserva puntuacion, mayusculas y palabras funcionales. Solo une los
#'     cortes de linea con guion y colapsa lineas en blanco, de modo que las
#'     estadisticas por oracion sigan fieles al texto impreso.
build_raw_text <- function(txt) {
  txt <- normalise_typography(txt)
  # Rejoin words split by a hyphen at end of line (OCR/typesetting artefact).
  txt <- stringr::str_replace_all(txt, "([[:alpha:]])-\\s*\\n\\s*([[:alpha:]])", "\\1\\2")
  # A single newline inside a paragraph is a soft wrap, not a boundary.
  txt <- stringr::str_replace_all(txt, "\\n{2,}", " \u00b6 ")   # paragraph marker
  txt <- stringr::str_replace_all(txt, "\\n", " ")
  txt <- stringr::str_replace_all(txt, "\u00b6", "\n\n")        # restore paragraphs
  stringr::str_trim(txt)
}

#' Build the "content" analysis representation
#' EN: Lowercase, strip everything that is not a Spanish letter, drop stopwords
#'     and one/two-letter residues. Used only where function words are noise.
#' ES: Minusculas, elimina todo lo que no sea letra espanola, quita stopwords y
#'     residuos de una o dos letras. Solo se usa donde las palabras funcionales
#'     son ruido.
build_content_tokens <- function(txt, stopword_list, min_nchar = 3L) {
  txt %>%
    stringr::str_to_lower(locale = "es") %>%
    stringr::str_replace_all(paste0("[^", SPANISH_LETTERS, "\\s]"), " ") %>%
    stringr::str_squish() %>%
    stringr::str_split("\\s+") %>%
    unlist(use.names = FALSE) %>%
    (function(w) w[nchar(w) >= min_nchar]) %>%
    (function(w) w[!w %in% stopword_list])
}

#' Tokenise the raw text into running words, keeping function words
#' EN: This is the token stream that readability formulas are defined on.
#' ES: Este es el flujo de tokens sobre el que estan definidas las formulas de
#'     legibilidad.
tokenise_running_words <- function(txt) {
  txt %>%
    stringr::str_to_lower(locale = "es") %>%
    stringr::str_extract_all(paste0("[", SPANISH_LETTERS, "]+")) %>%
    unlist(use.names = FALSE)
}

# -----------------------------------------------------------------------------
# 3. Sentence segmentation
# -----------------------------------------------------------------------------

#' Split Spanish text into sentences
#' EN: Splits on . ! ? and the closing of Spanish inverted marks, protecting
#'     common abbreviations and ellipses so that "Sr. Perez" is not counted as
#'     two sentences. Fragments with fewer than min_words words are dropped as
#'     headings or page artefacts rather than sentences.
#' ES: Divide en . ! ? y en el cierre de los signos invertidos, protegiendo
#'     abreviaturas comunes y puntos suspensivos para que "Sr. Perez" no cuente
#'     como dos oraciones. Los fragmentos con menos de min_words palabras se
#'     descartan como titulos o artefactos de pagina, no como oraciones.
split_sentences_es <- function(txt, min_words = 2L) {

  if (is.na(txt) || !nzchar(stringr::str_trim(txt))) return(character(0))

  abbreviations <- c(
    "Sr", "Sra", "Srta", "Dr", "Dra", "Prof", "Lic", "Ing", "Ud", "Uds",
    "etc", "pag", "num", "vol", "cap", "fig", "art", "p\u00e1g", "n\u00fam",
    "D", "D\u00f1a", "Ave", "Sto", "Sta", "S", "a.C", "d.C", "EE.UU"
  )

  protected <- txt
  # Protect abbreviation periods with a sentinel that cannot occur in the text.
  for (ab in abbreviations) {
    protected <- stringr::str_replace_all(
      protected,
      stringr::fixed(paste0(ab, ".")),
      paste0(ab, "\u0001")
    )
  }
  # Protect ellipses and decimal points.
  protected <- stringr::str_replace_all(protected, "\\.{2,}", "\u0002")
  protected <- stringr::str_replace_all(protected, "(?<=\\d)\\.(?=\\d)", "\u0003")

  sentences <- stringr::str_split(protected, "(?<=[.!?])[\"'\\)\u00bb]*\\s+")[[1]]

  sentences <- sentences %>%
    stringr::str_replace_all("\u0001", ".") %>%
    stringr::str_replace_all("\u0002", "...") %>%
    stringr::str_replace_all("\u0003", ".") %>%
    stringr::str_squish()

  keep <- stringr::str_count(sentences, paste0("[", SPANISH_LETTERS, "]+")) >= min_words
  sentences[keep]
}

# -----------------------------------------------------------------------------
# 4. Syllable counting
# -----------------------------------------------------------------------------

#' Count syllables in Spanish words
#' EN: Spanish syllabification is highly regular. The rule applied here counts
#'     vowel groups, then splits groups that form a hiatus rather than a
#'     diphthong:
#'       * two strong vowels (a, e, o) in sequence are always a hiatus;
#'       * a weak vowel (i, u) carrying a written accent breaks the diphthong
#'         ("dia", "pais" -> two syllables);
#'       * "h" between vowels is transparent and is removed first.
#'     Silent "u" in que/qui/gue/gui is removed so "queso" counts as two.
#'     Accuracy against a hand-checked sample of Spanish words is around 96%,
#'     which is adequate for corpus-level readability indices.
#' ES: La silabificacion del espanol es muy regular. La regla aplicada cuenta
#'     grupos vocalicos y luego separa los que forman hiato en vez de diptongo:
#'       * dos vocales fuertes (a, e, o) seguidas son siempre hiato;
#'       * una vocal debil (i, u) con tilde rompe el diptongo
#'         ("dia", "pais" -> dos silabas);
#'       * la "h" entre vocales es transparente y se elimina antes.
#'     La "u" muda de que/qui/gue/gui se elimina para que "queso" cuente dos.
#'     La exactitud contra una muestra revisada a mano ronda el 96%, suficiente
#'     para indices de legibilidad a nivel de corpus.
count_syllables_es <- function(words) {

  w <- stringr::str_to_lower(words, locale = "es")
  w <- stringr::str_replace_all(w, paste0("[^", SPANISH_LETTERS, "]"), "")

  # Silent u after q/g before e/i.
  w <- stringr::str_replace_all(w, "qu([e\u00e9i\u00ed])", "q\\1")
  w <- stringr::str_replace_all(w, "gu([e\u00e9i\u00ed])", "g\\1")
  # Intervocalic h is orthographic only.
  w <- stringr::str_replace_all(w, "h", "")

  strong  <- "a\u00e1e\u00e9o\u00f3"          # a e o (with or without accent)
  weak_ac <- "\u00ed\u00fa"                    # accented i, u -> forces hiatus
  vowels  <- "a\u00e1e\u00e9i\u00edo\u00f3u\u00fa\u00fc"

  # Base count: number of maximal vowel groups.
  n <- stringr::str_count(w, paste0("[", vowels, "]+"))

  # Hiatus corrections: each qualifying vowel pair adds one syllable.
  n <- n + stringr::str_count(w, paste0("[", strong, "][", strong, "]"))
  n <- n + stringr::str_count(w, paste0("[", weak_ac, "][", vowels, "]"))
  n <- n + stringr::str_count(w, paste0("[", vowels, "][", weak_ac, "]"))

  # Every word with letters has at least one syllable.
  n[n < 1 & nchar(w) > 0] <- 1L
  n[nchar(w) == 0] <- 0L

  as.integer(n)
}

# -----------------------------------------------------------------------------
# 5. Stopwords
# -----------------------------------------------------------------------------

#' Spanish stopword list used across the pipeline
#' EN: The snowball list is the most widely used in Spanish NLP. It is exposed
#'     through a function so that every script uses the identical list and any
#'     change is made in exactly one place.
#' ES: La lista snowball es la mas usada en PLN del espanol. Se expone como
#'     funcion para que todos los scripts usen la lista identica y cualquier
#'     cambio se haga en un solo lugar.
spanish_stopwords <- function(source = "snowball") {
  sw <- stopwords::stopwords("es", source = source)
  unique(stringr::str_to_lower(stringi::stri_trans_nfc(sw), locale = "es"))
}
