# =============================================================================
# 01_build_corpus.R
# -----------------------------------------------------------------------------
# EN: Builds the canonical corpus object used by every downstream analysis.
#     Steps: validate metadata against the files on disk, strip editorial front
#     matter, build the raw and content representations, compute descriptive
#     counts, and write a quality-control report.
# ES: Construye el objeto canonico de corpus que usan todos los analisis
#     posteriores. Pasos: validar el metadata contra los archivos en disco,
#     quitar el paratexto editorial, construir las representaciones raw y
#     content, calcular conteos descriptivos y escribir un reporte de control
#     de calidad.
#
# OUTPUT / SALIDA
#   data/derived/corpus.rds          canonical corpus object
#   outputs/tables/01_corpus_*.csv   descriptive and QA tables
# =============================================================================

source("R/00_config.R")
source("R/utils_text.R")
source("R/utils_stats.R")
source("R/utils_io.R")

check_dependencies()
log_msg("01_build_corpus: start")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
})

# =============================================================================
# 1. Load and validate metadata
# =============================================================================
# EN: The metadata file is the authority on what belongs in the corpus. If a
#     file exists on disk but is not listed, or is listed but missing from disk,
#     the script stops. Silently analysing a different set of books than the
#     one documented is the failure mode this check exists to prevent.
# ES: El archivo de metadata es la autoridad sobre que pertenece al corpus. Si
#     un archivo existe en disco pero no esta listado, o esta listado pero falta
#     en disco, el script se detiene. Analizar en silencio un conjunto de libros
#     distinto al documentado es justamente la falla que este chequeo evita.

metadata <- readr::read_csv(
  file.path(PATHS$metadata, "corpus_metadata.csv"),
  col_types = readr::cols(
    book_id            = readr::col_character(),
    group              = readr::col_character(),
    filename           = readr::col_character(),
    title_es           = readr::col_character(),
    title_en           = readr::col_character(),
    author             = readr::col_character(),
    series             = readr::col_character(),
    series_position    = readr::col_integer(),
    year_first_edition = readr::col_integer(),
    audience           = readr::col_character(),
    original_language  = readr::col_character(),
    translated         = readr::col_logical(),
    notes              = readr::col_character()
  ),
  progress = FALSE
)

metadata <- metadata %>%
  dplyr::mutate(
    path = dplyr::case_when(
      group == GROUPS$focus      ~ file.path(PATHS$raw_papelucho, filename),
      group == GROUPS$comparison ~ file.path(PATHS$raw_comparison, filename),
      TRUE                       ~ NA_character_
    )
  )

# --- Check 1: every listed file exists ---------------------------------------
missing_files <- metadata$filename[!file.exists(metadata$path)]
if (length(missing_files) > 0) {
  stop("Files listed in metadata but missing from disk:\n  ",
       paste(missing_files, collapse = "\n  "), call. = FALSE)
}

# --- Check 2: every file on disk is listed -----------------------------------
on_disk <- c(
  list.files(PATHS$raw_papelucho,  pattern = "\\.txt$"),
  list.files(PATHS$raw_comparison, pattern = "\\.txt$")
)
unlisted <- setdiff(on_disk, metadata$filename)
if (length(unlisted) > 0) {
  stop("Files on disk but absent from metadata:\n  ",
       paste(unlisted, collapse = "\n  "), call. = FALSE)
}

# --- Check 3: identifiers are unique -----------------------------------------
if (anyDuplicated(metadata$book_id) > 0) {
  stop("Duplicate book_id values in metadata.", call. = FALSE)
}

log_msg("  metadata validated: ", nrow(metadata), " books (",
        sum(metadata$group == GROUPS$focus), " ", GROUPS$focus, ", ",
        sum(metadata$group == GROUPS$comparison), " ", GROUPS$comparison, ")")

# =============================================================================
# 2. Digitisation artefact removal
# =============================================================================

# -----------------------------------------------------------------------------
# 2a. Scraper boilerplate
# -----------------------------------------------------------------------------
# EN: Several files were downloaded from ebook aggregator sites that stamp a
#     footer on every page: "www.lectulandia.com - Pagina 5". Two Papelucho
#     files carry more than forty of these each. Left in, they contribute a
#     repeated non-narrative n-gram to the token stream, add a spurious sentence
#     boundary in the middle of a paragraph, and inflate the count of proper
#     nouns and numerals in the part-of-speech profile.
#
#     These lines are removed throughout the file, not just at the start, since
#     they recur at every page break. The pattern is anchored to whole lines so
#     a URL mentioned inside the narrative is left untouched.
#
# ES: Varios archivos se bajaron de sitios agregadores de ebooks que estampan un
#     pie en cada pagina: "www.lectulandia.com - Pagina 5". Dos archivos de
#     Papelucho traen mas de cuarenta cada uno. Si se dejan, aportan un n-grama
#     no narrativo repetido al flujo de tokens, agregan un limite de oracion
#     falso en medio de un parrafo e inflan el conteo de nombres propios y
#     numerales en el perfil morfosintactico.
#
#     Estas lineas se eliminan en todo el archivo, no solo al inicio, porque se
#     repiten en cada salto de pagina. El patron esta anclado a lineas completas
#     para que una URL mencionada dentro de la narracion quede intacta.

SCRAPER_PATTERNS <- paste(
  "^\\s*www\\.[a-z0-9-]+\\.[a-z]{2,4}\\s*[-\u2013]?\\s*p\u00e1gina\\s*\\d+\\s*$",
  "^\\s*www\\.[a-z0-9-]+\\.[a-z]{2,4}\\s*[-\u2013]?\\s*pagina\\s*\\d+\\s*$",
  "^\\s*www\\.[a-z0-9-]+\\.[a-z]{2,4}\\s*$",
  "^\\s*https?://\\S+\\s*$",
  "^\\s*p\u00e1gina\\s*\\d+\\s*$",
  "^\\s*pagina\\s*\\d+\\s*$",
  "^\\s*-?\\s*\\d{1,4}\\s*-?\\s*$",
  "lectulandia", "epublibre", "epubgratis", "librosgratis", "elejandria",
  sep = "|"
)

#' Remove page footers and site stamps injected by ebook scrapers
strip_scraper_boilerplate <- function(txt) {

  lines <- stringr::str_split(txt, "\n")[[1]]
  hit   <- stringr::str_detect(stringr::str_to_lower(lines), SCRAPER_PATTERNS)

  list(
    text            = paste(lines[!hit], collapse = "\n"),
    n_lines_removed = sum(hit),
    removed_preview = stringr::str_trunc(
      paste(unique(stringr::str_squish(lines[hit])), collapse = " | "), 200
    )
  )
}

# -----------------------------------------------------------------------------
# 2b. Editorial front matter
# -----------------------------------------------------------------------------
# EN: The comparison files were digitised from printed editions and open with
#     editorial paratext: author line, title, original title, translator,
#     publisher, copyright, ISBN and edition dates. The Papelucho files do not.
#     Leaving this in gives the comparison group a block of non-narrative text
#     in a different register, containing English or German source titles and
#     publisher proper nouns, which inflates its type count and distorts its
#     part-of-speech profile. Since the asymmetry affects only one group, it
#     biases every between-group comparison in the same direction.
#
# ES: Los archivos de comparacion fueron digitalizados desde ediciones impresas
#     y parten con paratexto editorial: linea de autor, titulo, titulo original,
#     traductor, editorial, copyright, ISBN y fechas de edicion. Los archivos de
#     Papelucho no. Dejarlo le da al grupo de comparacion un bloque de texto no
#     narrativo en otro registro, con titulos fuente en ingles o aleman y
#     nombres propios de editoriales, lo que infla su conteo de tipos y
#     distorsiona su perfil morfosintactico. Como la asimetria afecta a un solo
#     grupo, sesga toda comparacion entre grupos en la misma direccion.

# EN: STRONG markers are bibliographic fields that cannot plausibly occur in
#     the opening narrative of a novel. Their presence is what authorises any
#     deletion at all.
# ES: Los marcadores FUERTES son campos bibliograficos que no pueden aparecer de
#     forma plausible en la narracion inicial de una novela. Su presencia es lo
#     que autoriza cualquier eliminacion.
PARATEXT_STRONG <- paste(
  "t\u00edtulo\\s+original", "titulo\\s+original",
  "traducci\u00f3n\\s*:", "traduccion\\s*:", "traducido\\s+por", "traductor",
  "copyright", "\u00a9", "isbn",
  "dep\u00f3sito\\s+legal", "deposito\\s+legal",
  "printed\\s+in", "impreso\\s+en",
  "reservados\\s+todos\\s+los\\s+derechos", "all\\s+rights\\s+reserved",
  "dise\u00f1o\\s+de\\s+(la\\s+)?cubierta", "ilustraci\u00f3n\\s+de\\s+cubierta",
  "direcci\u00f3n\\s+editorial", "publicada\\s+mediante", "por\\s+convenio\\s+con",
  "\\d+\\s*(a|\u00aa|ra|da|ta|va)\\s+edici\u00f3n", "primera\\s+edici\u00f3n",
  sep = "|"
)

# EN: WEAK markers are publisher names and collection labels. They extend a cut
#     that a strong marker or an identity match has already authorised, but they
#     never authorise one on their own.
# ES: Los marcadores DEBILES son nombres de editorial y etiquetas de coleccion.
#     Extienden un corte que un marcador fuerte o una coincidencia de identidad
#     ya autorizo, pero nunca lo autorizan por si solos.
PARATEXT_WEAK <- paste(
  "editorial", "ediciones", "editores", "editor\\s*:",
  "colecci\u00f3n", "premio\\s+", "serie\\s+\\w+\\s+n\u00ba", "timun\\s+mas",
  "emec\u00e9", "planeta", "salamandra", "alfaguara", "debolsillo", "minotauro",
  "martinez\\s+roca", "mart\u00ednez\\s+roca", "s\\.a\\.", "s\\.l\\.",
  "^\\s*por\\s+[A-Z]", "ilustraciones\\s*:", "cubierta\\s*:",
  sep = "|"
)

#' Detect and remove editorial front matter
#'
#' EN: The detector is deliberately conservative, because deleting narrative
#'     text is a far worse error than leaving a title line in place. Deletion
#'     happens only when the opening of the file gives positive evidence of
#'     paratext:
#'       (a) a strong bibliographic marker appears within the prefix window, or
#'       (b) an opening line reproduces the book title or the author name as
#'           recorded in the metadata.
#'     When neither condition holds, nothing is removed. The cut then runs to
#'     the last authorising line and is extended over adjacent blank, weak-marker
#'     and heading lines. A cap at max_share of the file guarantees that a
#'     malformed file cannot lose its narrative.
#'
#'     An earlier version classified any short line without final punctuation as
#'     paratext. That rule silently deleted the opening paragraphs of four
#'     Papelucho books, whose source files are hard-wrapped at about fifty
#'     characters and therefore consist entirely of short lines. Scraper footers
#'     are now removed in step 2a, before this function runs, so a page stamp
#'     appearing after the narrative has begun can no longer drag the cut point
#'     forward into the text.
#'
#' ES: El detector es deliberadamente conservador, porque borrar texto narrativo
#'     es un error mucho peor que dejar una linea de titulo. La eliminacion solo
#'     ocurre cuando el inicio del archivo da evidencia positiva de paratexto:
#'       (a) aparece un marcador bibliografico fuerte dentro de la ventana de
#'           prefijo, o
#'       (b) una linea inicial reproduce el titulo del libro o el nombre del
#'           autor registrados en el metadata.
#'     Si no se cumple ninguna condicion, no se elimina nada. El corte llega
#'     hasta la ultima linea autorizante y se extiende sobre lineas adyacentes
#'     en blanco, con marcadores debiles o de encabezado. Un tope de max_share
#'     del archivo garantiza que un archivo mal formado no pueda perder su
#'     narracion.
#'
#'     Una version anterior clasificaba como paratexto cualquier linea corta sin
#'     puntuacion final. Esa regla borro en silencio los parrafos iniciales de
#'     cuatro libros de Papelucho, cuyos archivos fuente estan cortados a unos
#'     cincuenta caracteres y por lo tanto son todos lineas cortas. Los pies del
#'     scraper ahora se eliminan en el paso 2a, antes de esta funcion, asi que un
#'     sello de pagina posterior al inicio de la narracion ya no puede arrastrar
#'     el punto de corte hacia dentro del texto.
strip_front_matter <- function(txt,
                               title     = NA_character_,
                               author    = NA_character_,
                               max_lines = 60L,
                               max_share = 0.03) {

  lines <- stringr::str_split(txt, "\n")[[1]]
  n     <- length(lines)
  limit <- min(max_lines, n)
  prefix <- lines[seq_len(limit)]
  prefix_lower <- stringr::str_to_lower(stringr::str_squish(prefix))

  no_change <- list(
    text = txt, n_lines_removed = 0L, n_chars_removed = 0L,
    removed_preview = "", trigger = "none"
  )

  norm <- function(s) {
    s %>%
      stringi::stri_trans_general("Latin-ASCII") %>%
      stringr::str_to_lower() %>%
      stringr::str_replace_all("[^a-z0-9 ]", " ") %>%
      stringr::str_squish()
  }

  # --- Evidence (a): strong bibliographic markers ----------------------------
  strong_hits <- which(stringr::str_detect(prefix_lower, PARATEXT_STRONG))

  # --- Evidence (b): title or author reproduced in the opening lines ---------
  # EN: Matched on a normalised line that is essentially the title or author on
  #     its own, allowing a short lead-in such as "Por" or "de". A line that
  #     merely mentions the word somewhere inside running prose never matches.
  # ES: Se compara sobre una linea normalizada que es esencialmente el titulo o
  #     el autor por si solos, admitiendo una entrada corta como "Por" o "de".
  #     Una linea que solo menciona la palabra dentro de prosa corrida nunca
  #     coincide.
  prefix_norm <- norm(prefix)
  id_hits <- integer(0)
  for (target in c(title, author)) {
    if (!is.na(target) && nzchar(target)) {
      t_norm <- norm(target)
      if (nzchar(t_norm)) {
        exact    <- prefix_norm == t_norm
        lead_in  <- stringr::str_detect(
          prefix_norm,
          paste0("^(por|de|autor|by)\\s+", stringr::fixed(t_norm), "$")
        )
        # Line contains the target and almost nothing else.
        contained <- stringr::str_detect(prefix_norm, stringr::fixed(t_norm)) &
          nchar(prefix_norm) <= nchar(t_norm) + 25
        id_hits <- c(id_hits, which(exact | lead_in | contained))
      }
    }
  }

  trigger <- dplyr::case_when(
    length(strong_hits) > 0 && length(id_hits) > 0 ~ "marker+identity",
    length(strong_hits) > 0                        ~ "marker",
    length(id_hits)     > 0                        ~ "identity",
    TRUE                                           ~ "none"
  )

  if (trigger == "none") return(no_change)

  # --- Determine the cut point ------------------------------------------------
  cut_at <- max(c(strong_hits, id_hits))

  # Extend over adjacent blank, weak-marker, all-caps and numeral lines that
  # belong to the same block, but never past a line that reads as narrative.
  i <- cut_at + 1L
  while (i <= limit) {
    l <- stringr::str_squish(prefix[i])
    letters_only <- stringr::str_replace_all(l, "[^[:alpha:]]", "")
    is_blank   <- !nzchar(l)
    is_weak    <- stringr::str_detect(stringr::str_to_lower(l), PARATEXT_WEAK)
    is_allcaps <- nchar(letters_only) > 3 && letters_only == toupper(letters_only)
    is_numeral <- stringr::str_detect(l, "^[IVXLC0-9]{1,6}[.)]?$")
    if (is_blank || is_weak || is_allcaps || is_numeral) {
      cut_at <- i
      i <- i + 1L
    } else {
      break
    }
  }

  # --- Safety cap -------------------------------------------------------------
  removed_lines <- lines[seq_len(cut_at)]
  chars_removed <- sum(nchar(removed_lines))
  total_chars   <- sum(nchar(lines))

  if (total_chars > 0 && chars_removed / total_chars > max_share) {
    warning(
      sprintf(
        "Front matter detection would remove %.1f%% of a file, above the %.1f%% cap. Nothing removed; inspect the file manually.",
        100 * chars_removed / total_chars, 100 * max_share
      ),
      call. = FALSE
    )
    return(no_change)
  }

  list(
    text            = paste(lines[seq.int(cut_at + 1L, n)], collapse = "\n"),
    n_lines_removed = cut_at,
    n_chars_removed = chars_removed,
    removed_preview = stringr::str_trunc(
      paste(stringr::str_squish(removed_lines), collapse = " | "), 300
    ),
    trigger         = trigger
  )
}


# =============================================================================
# 3. Read and process every book
# =============================================================================

stopwords_es <- spanish_stopwords()
log_msg("  stopword list: ", length(stopwords_es), " Spanish terms")

log_msg("  reading and processing ", nrow(metadata), " books")

corpus <- metadata %>%
  dplyr::mutate(
    text_original = purrr::map_chr(path, read_text_utf8)
  )

# --- Step 2a: scraper boilerplate, removed throughout the file ---------------
scraper <- purrr::map(corpus$text_original, strip_scraper_boilerplate)

corpus <- corpus %>%
  dplyr::mutate(
    n_lines_scraper   = purrr::map_int(scraper, "n_lines_removed"),
    scraper_preview   = purrr::map_chr(scraper, "removed_preview"),
    text_descraped    = purrr::map_chr(scraper, "text")
  )

log_msg("  scraper boilerplate removed from ",
        sum(corpus$n_lines_scraper > 0), " file(s), ",
        sum(corpus$n_lines_scraper), " lines total")

# --- Step 2b: editorial front matter, removed from the head of the file ------
front_matter <- purrr::pmap(
  list(corpus$text_descraped, corpus$title_es, corpus$author),
  function(txt, title, author) strip_front_matter(txt, title = title, author = author)
)

corpus <- corpus %>%
  dplyr::mutate(
    n_lines_front_matter = purrr::map_int(front_matter, "n_lines_removed"),
    n_chars_front_matter = purrr::map_int(front_matter, "n_chars_removed"),
    front_matter_preview = purrr::map_chr(front_matter, "removed_preview"),
    front_matter_trigger = purrr::map_chr(front_matter, "trigger"),
    text_body            = purrr::map_chr(front_matter, "text"),

    # --- Representation 1: raw ------------------------------------------------
    # Punctuation, capitalisation and function words intact. Everything that
    # depends on syntax or sentence structure is computed from this.
    text_raw = purrr::map_chr(text_body, build_raw_text),

    # --- Representation 2: content --------------------------------------------
    # Lowercased content words, stopwords removed. Lexical diversity and
    # stylometry only.
    tokens_content = purrr::map(
      text_raw, ~ build_content_tokens(.x, stopword_list = stopwords_es)
    ),

    # --- Running tokens and sentences from the raw representation -------------
    tokens_running = purrr::map(text_raw, tokenise_running_words),
    sentences      = purrr::map(text_raw, split_sentences_es)
  )

# =============================================================================
# 4. Descriptive counts
# =============================================================================

corpus <- corpus %>%
  dplyr::mutate(
    n_tokens_running = purrr::map_int(tokens_running, length),
    n_tokens_content = purrr::map_int(tokens_content, length),
    n_types_content  = purrr::map_int(tokens_content, dplyr::n_distinct),
    n_sentences      = purrr::map_int(sentences, length),
    n_characters     = purrr::map_int(tokens_running, ~ sum(nchar(.x))),
    n_syllables      = purrr::map_int(tokens_running, ~ sum(count_syllables_es(.x))),

    # Proportion of running tokens that survive stopword filtering. Reported
    # because it makes explicit how much of the text the content representation
    # discards, which is the quantity the original pipeline conflated with the
    # full text.
    content_ratio = n_tokens_content / n_tokens_running,

    words_per_sentence = n_tokens_running / n_sentences,
    letters_per_word   = n_characters / n_tokens_running,
    syllables_per_word = n_syllables / n_tokens_running
  )

# =============================================================================
# 5. Quality control
# =============================================================================
# EN: Hard failures stop the pipeline. Soft warnings are written to the QA
#     table and printed, but do not remove a book: exclusion decisions belong to
#     the analyst, not to a silent filter inside a script.
# ES: Las fallas duras detienen el pipeline. Las advertencias suaves se escriben
#     en la tabla de control de calidad y se imprimen, pero no eliminan un
#     libro: las decisiones de exclusion son del analista, no de un filtro
#     silencioso dentro de un script.

qa <- corpus %>%
  dplyr::transmute(
    book_id, group, title_es, author,
    n_lines_scraper, n_lines_front_matter, n_chars_front_matter,
    front_matter_trigger,
    n_tokens_running, n_tokens_content, n_types_content,
    n_sentences, content_ratio, words_per_sentence,
    flag_empty          = n_tokens_running == 0,
    flag_no_sentences   = n_sentences < 10,
    flag_short          = n_tokens_running < 5000,
    flag_wps_extreme    = words_per_sentence < 5 | words_per_sentence > 60,
    flag_content_ratio  = content_ratio < 0.30 | content_ratio > 0.75,
    flag_front_matter_large = n_chars_front_matter > 5000,
    front_matter_preview, scraper_preview
  ) %>%
  dplyr::mutate(
    n_flags = rowSums(dplyr::across(dplyr::starts_with("flag_")))
  )

if (any(qa$flag_empty)) {
  stop("Books with zero tokens after processing:\n  ",
       paste(qa$book_id[qa$flag_empty], collapse = ", "), call. = FALSE)
}

flagged <- qa %>% dplyr::filter(n_flags > 0)
if (nrow(flagged) > 0) {
  log_msg("  QA flags raised for ", nrow(flagged), " book(s); see 01_corpus_qa.csv")
  print(as.data.frame(
    flagged %>% dplyr::select(book_id, title_es, n_flags,
                              dplyr::starts_with("flag_"))
  ), row.names = FALSE)
} else {
  log_msg("  QA: no flags raised")
}

# EN: Confirm no book was lost between metadata and the processed corpus.
# ES: Confirma que ningun libro se perdio entre el metadata y el corpus procesado.
stopifnot(nrow(corpus) == nrow(metadata))
stopifnot(all(metadata$book_id %in% corpus$book_id))

# =============================================================================
# 6. Corpus balance
# =============================================================================
# EN: Three structural imbalances are quantified here and carried through to
#     the sensitivity analyses in later scripts.
#       (a) Length: Papelucho books are far shorter than the comparison novels.
#       (b) Authorship: a single author contributes a large share of the
#           comparison group, so its books are not independent observations.
#       (c) Audience and translation status: most comparison books are adult
#           fiction translated into Spanish, whereas Papelucho is original
#           Chilean Spanish written for children.
# ES: Aca se cuantifican tres desbalances estructurales que se arrastran a los
#     analisis de sensibilidad de los scripts posteriores.
#       (a) Largo: los libros de Papelucho son mucho mas cortos que las novelas
#           de comparacion.
#       (b) Autoria: un solo autor aporta una fraccion grande del grupo de
#           comparacion, asi que sus libros no son observaciones independientes.
#       (c) Publico y traduccion: la mayoria de los libros de comparacion son
#           ficcion adulta traducida al espanol, mientras que Papelucho es
#           espanol chileno original escrito para ninos.

balance_length <- corpus %>%
  dplyr::group_by(group) %>%
  dplyr::summarise(
    n_books      = dplyr::n(),
    min_tokens   = min(n_tokens_running),
    q1_tokens    = stats::quantile(n_tokens_running, 0.25),
    median_tokens = stats::median(n_tokens_running),
    q3_tokens    = stats::quantile(n_tokens_running, 0.75),
    max_tokens   = max(n_tokens_running),
    total_tokens = sum(n_tokens_running),
    .groups = "drop"
  )

balance_author <- corpus %>%
  dplyr::filter(group == GROUPS$comparison) %>%
  dplyr::count(author, name = "n_books", sort = TRUE) %>%
  dplyr::mutate(pct_of_comparison = round(100 * n_books / sum(n_books), 1))

balance_audience <- corpus %>%
  dplyr::count(group, audience, name = "n_books") %>%
  tidyr::pivot_wider(names_from = audience, values_from = n_books, values_fill = 0L)

balance_translation <- corpus %>%
  dplyr::count(group, translated, name = "n_books") %>%
  tidyr::pivot_wider(
    names_from = translated, values_from = n_books, values_fill = 0L,
    names_prefix = "translated_"
  )

log_msg("  length balance:")
print(as.data.frame(balance_length), row.names = FALSE)
log_msg("  authorship concentration in the comparison group (top 5):")
print(as.data.frame(utils::head(balance_author, 5)), row.names = FALSE)

# =============================================================================
# 7. Save
# =============================================================================

saveRDS(corpus, file.path(PATHS$derived, "corpus.rds"))

descriptives <- corpus %>%
  dplyr::select(
    book_id, group, title_es, title_en, author, series, series_position,
    year_first_edition, audience, original_language, translated,
    n_tokens_running, n_types_content, n_tokens_content, n_sentences,
    n_characters, n_syllables, content_ratio,
    words_per_sentence, letters_per_word, syllables_per_word
  ) %>%
  dplyr::arrange(group, book_id)

export_table(
  descriptives,
  name       = "01_corpus_descriptives",
  caption_en = "Descriptive statistics of the corpus. Running tokens are counted on the raw text with punctuation and function words intact; content tokens are the subset that survives stopword filtering.",
  caption_es = "Estadisticos descriptivos del corpus. Los tokens corrientes se cuentan sobre el texto crudo con puntuacion y palabras funcionales intactas; los tokens de contenido son el subconjunto que sobrevive al filtrado de stopwords.",
  label      = "corpus-descriptives",
  note_en    = "Editorial front matter was removed before counting. See Table 01\\_corpus\\_qa for the amount removed per book.",
  note_es    = "El paratexto editorial se elimino antes de contar. Ver la tabla 01\\_corpus\\_qa para la cantidad eliminada por libro."
)

write_table_csv(qa, "01_corpus_qa")
write_table_csv(balance_length, "01_balance_length")
write_table_csv(balance_author, "01_balance_author")
write_table_csv(balance_audience, "01_balance_audience")
write_table_csv(balance_translation, "01_balance_translation")

write_session_info("01_build_corpus")

log_msg("01_build_corpus: done (", nrow(corpus), " books, ",
        format(sum(corpus$n_tokens_running), big.mark = ","), " running tokens)")
