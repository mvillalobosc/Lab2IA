# =============================================================================
# text.R  Normalizacion de texto, tokenizacion y particion lexica
# =============================================================================

# La cancion introductoria aparece con y sin tildes segun el archivo. Se
# construye un patron tolerante a acentos para no dejar residuos.
patron_intro <- function(intro = CFG$intro_song) {
  p <- stringr::str_squish(intro)
  p <- stringr::str_replace_all(p, "[aáAÁ]", "[a\u00e1]")
  p <- stringr::str_replace_all(p, "[eéEÉ]", "[e\u00e9]")
  p <- stringr::str_replace_all(p, "[iíIÍ]", "[i\u00ed]")
  p <- stringr::str_replace_all(p, "[oóOÓ]", "[o\u00f3]")
  p <- stringr::str_replace_all(p, "[uúUÚ]", "[u\u00fa]")
  p <- stringr::str_replace_all(p, "[nñNÑ]", "[n\u00f1]")
  stringr::regex(p, ignore_case = TRUE)
}

quitar_intro <- function(x) {
  stringr::str_squish(stringr::str_replace_all(x, patron_intro(), " "))
}

# Limpieza aplicada antes de tokenizar. El texto original (sin limpiar) se
# conserva aparte porque las metricas de legibilidad requieren la puntuacion y
# la segmentacion en oraciones intactas.
limpiar_texto <- function(x, intro = CFG$intro_song) {
  x <- quitar_intro(x)
  x <- tolower(x)
  x <- stringr::str_replace_all(x, "[0-9]", " ")
  x <- stringr::str_replace_all(x, "[\r\n]+", " ")
  x <- stringr::str_squish(x)
  x
}

# Divide los tokens de un capitulo en dos grupos, ambos sin stopwords:
#   - generico:  reconocido por el diccionario hunspell del espanol
#   - cultural:  no reconocido (voces indigenas, chilenismos, nombres propios)
# forzar_culturales mueve al grupo cultural palabras que el diccionario acepta
# pero que en el contexto de la serie son marca cultural.
particion_lexica <- function(texto, diccionario, stopwords,
                             forzar_culturales = character(0)) {
  toks <- tokenizers::tokenize_words(texto)[[1]]
  toks <- toks[nzchar(toks)]
  toks <- toks[!toks %in% stopwords]
  if (length(toks) == 0L) {
    return(list(generico = character(0), cultural = character(0)))
  }
  en_dic <- hunspell::hunspell_check(toks, dict = diccionario)
  forzado <- toks %in% forzar_culturales
  list(
    generico = toks[en_dic & !forzado],
    cultural = toks[!en_dic | forzado]
  )
}

# Segmenta un texto en n tramos de igual numero de oraciones y devuelve el
# texto concatenado de cada tramo. Permite comparar temporadas de distinto
# largo sobre una escala temporal comun.
tramos_oraciones <- function(texto, n) {
  or <- tokenizers::tokenize_sentences(texto)[[1]]
  if (length(or) == 0L) return(rep(NA_character_, n))
  corte <- cut(seq_along(or), breaks = n, labels = FALSE, include.lowest = TRUE)
  vapply(seq_len(n), function(k) paste(or[corte == k], collapse = " "), character(1))
}

n_oraciones <- function(texto) length(tokenizers::tokenize_sentences(texto)[[1]])

# Aplica las abreviaciones de nombres de tema definidas en CFG$tema_abrev.
abreviar_temas <- function(x) {
  for (k in names(CFG$tema_abrev)) {
    x <- stringr::str_replace_all(x, stringr::fixed(k), CFG$tema_abrev[[k]])
  }
  x
}
