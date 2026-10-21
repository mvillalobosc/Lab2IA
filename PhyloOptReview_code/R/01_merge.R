# =============================================================================
# 01_merge.R
# Une las exportaciones de Scopus (CSV) y WoS (XLS) de los ocho bloques de
# búsqueda (Q1, Q2, Q3, Q4A, Q4B, Q5, Q6 y Q7), homologa los campos, elimina duplicados por DOI y por título
# normalizado, y guarda la base unificada con la marca de los bloques en que
# apareció cada registro. Los conteos por etapa alimentan el diagrama de flujo.
# Las referencias citadas de las exportaciones no se usan en el análisis, así que
# no se copian a la base unificada (siguen disponibles en data/raw).
#
# Entradas: el script lee las exportaciones de Scopus en data/raw/scopus (un CSV por bloque) y las
# de WoS en data/raw/wos (XLS). WoS exporta a lo más 1000 registros por descarga, por eso los
# bloques más grandes vienen en dos archivos (por ejemplo, Q3_WoS1.xls y Q3_WoS2.xls).
# Salidas: escribe data/processed/db_unique.csv, con un registro por publicación y su
# identificador (R00001, R00002, ...), que es la entrada de 02_screen.R, y
# data/processed/counts_raw.csv, con los registros por bloque y base antes de deduplicar, que leen
# 07_synthesis.R y 08_tables.R para el diagrama PRISMA y la tabla de bloques.
# =============================================================================
# El script fija la configuración regional C.UTF-8 para manejar el texto como UTF-8 y para que el
# orden alfabético sea el mismo en cualquier equipo. De ese orden dependen la lista de bloques de
# cada registro y los identificadores que se asignan al final. invisible() evita que se imprima la
# respuesta de Sys.setlocale().
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# Carga los paquetes sin mostrar sus mensajes de inicio: readr lee y escribe los CSV, readxl lee
# los XLS de WoS, dplyr y tidyr transforman las tablas y stringr trabaja el texto.
suppressPackageStartupMessages({
  library(readr); library(readxl); library(dplyr); library(stringr); library(tidyr)
})

# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/01_merge.R
# Crea la carpeta de las bases intermedias si no existe, por ejemplo en una copia del
# repositorio sin data/processed.
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
# Todas las rutas son relativas a esa carpeta. write_csv() no crea carpetas, así que
# data/processed debe existir; el repositorio ya la trae.

# ---- Scopus ------------------------------------------------------------------
# Lista los CSV de Scopus, uno por bloque de búsqueda, con su ruta completa.
sc_files <- list.files("data/raw/scopus", pattern = "\\.csv$", full.names = TRUE)
# Lee cada archivo, lleva sus columnas a un esquema común (el mismo que se usa después para WoS) y
# apila todos los archivos en una sola tabla con bind_rows().
scopus <- bind_rows(lapply(sc_files, function(f) {
  # guess_max = 5000 hace que readr revise 5000 filas antes de decidir el tipo de cada columna.
  # Con pocas filas, una columna vacía al comienzo del archivo se leería con un tipo equivocado.
  d <- read_csv(f, show_col_types = FALSE, guess_max = 5000)
  # Scopus exporta el CSV con una marca de orden de bytes (BOM, U+FEFF) al comienzo. Si
  # la marca queda pegada al nombre de la primera columna, d$Authors no encuentra la
  # columna. Por eso el patrón tiene, justo después de "^", el carácter BOM, que es
  # invisible en la mayoría de los editores.
  names(d) <- str_replace_all(names(d), "^﻿", "")
  # Cada columna del esquema común toma el campo equivalente de Scopus.
  tibble(
    # El bloque sale del nombre del archivo: la expresión regular toma, desde el comienzo, "Q", un
    # dígito y, si existe, la letra A o B (Q4A_SCOPUS.csv da Q4A).
    block     = str_extract(basename(f), "^Q[0-9][AB]?"),
    source_db = "Scopus",
    authors   = d$Authors,
    title     = d$Title,
    # suppressWarnings() calla el aviso de as.integer() cuando un valor no es numérico (aquí y en
    # cited); ese valor queda como NA.
    year      = suppressWarnings(as.integer(d$Year)),
    journal   = d$`Source title`,
    # El DOI queda en minúsculas y sin espacios en los extremos. Los DOI no distinguen mayúsculas
    # y cada base los escribe a su manera, así que esta forma permite compararlos entre bases.
    doi       = str_to_lower(str_trim(d$DOI)),
    abstract  = d$Abstract,
    # kw_author guarda las palabras clave de los autores y kw_index las Index Keywords, que Scopus
    # asigna con vocabularios controlados.
    kw_author = d$`Author Keywords`,
    kw_index  = d$`Index Keywords`,
    doctype   = d$`Document Type`,
    # cited guarda las citas que informa Scopus.
    cited     = suppressWarnings(as.integer(d$`Cited by`)),
    # Volumen y número se guardan como texto, porque un archivo puede leerlos como número y otro
    # como texto, y bind_rows() no junta columnas de tipos distintos.
    volume    = as.character(d$Volume), issue = as.character(d$Issue),
    # Las páginas quedan como "inicio-fin". Si faltan ambas, paste0() deja el texto "NA-NA";
    # 10_bib.R lo limpia al armar las referencias.
    pages     = paste0(d$`Page start`, "-", d$`Page end`),
    # artno es el número de artículo, que usan las revistas sin paginación.
    artno     = as.character(d$`Art. No.`),
    # uid es el identificador del registro en la base; en Scopus es el EID.
    uid       = d$EID
  )
}))

# ---- WoS ---------------------------------------------------------------------
# Lista los XLS de WoS. Un bloque puede tener dos archivos (WoS1 y WoS2) por el límite de 1000
# registros por descarga, y ambos reciben el mismo bloque, porque la expresión regular solo
# mira el comienzo del nombre.
wos_files <- list.files("data/raw/wos", pattern = "\\.xls$", full.names = TRUE)
# Lee cada archivo de WoS y lo lleva al mismo esquema común que Scopus.
wos <- bind_rows(lapply(wos_files, function(f) {
  # guess_max cumple aquí la misma función que en read_csv().
  d <- read_excel(f, guess_max = 5000)
  # WoS nombra distinto los mismos campos: Article Title es el título, Publication Year el
  # año y Source Title la revista.
  tibble(
    block     = str_extract(basename(f), "^Q[0-9][AB]?"),
    source_db = "WoS",
    # file guarda el nombre del archivo, que define la descarga del bloque Q7 (ver más abajo).
    file      = basename(f),
    authors   = d$Authors,
    title     = d$`Article Title`,
    year      = suppressWarnings(as.integer(d$`Publication Year`)),
    journal   = d$`Source Title`,
    doi       = str_to_lower(str_trim(d$DOI)),
    abstract  = d$Abstract,
    kw_author = d$`Author Keywords`,
    # En WoS, kw_index guarda las Keywords Plus, términos que WoS genera a partir de los títulos
    # de las referencias que cita el artículo.
    kw_index  = d$`Keywords Plus`,
    doctype   = d$`Document Type`,
    # cited guarda las citas en la colección principal de WoS (Times Cited, WoS Core).
    cited     = suppressWarnings(as.integer(d$`Times Cited, WoS Core`)),
    volume    = as.character(d$Volume), issue = as.character(d$Issue),
    pages     = paste0(d$`Start Page`, "-", d$`End Page`),
    artno     = as.character(d$`Article Number`),
    # uid es el identificador único de WoS (UT, de la forma WOS:...).
    uid       = d$`UT (Unique WOS ID)`,
    # wos_index solo existe en WoS e indica en qué índices de la colección principal está el
    # registro (por ejemplo, SCI-EXPANDED o CPCI-S). En las filas de Scopus queda como NA.
    wos_index = d$`Web of Science Index`
  )
}))

# ---- Unión de Scopus y WoS ---------------------------------------------------
# Apila Scopus y WoS en una sola tabla. bind_rows() alinea las columnas por nombre y deja
# wos_index como NA en las filas de Scopus.
all_rec <- bind_rows(scopus, wos) %>%
  mutate(
    # Un DOI vacío pasa a NA, para que la deduplicación trate igual un DOI vacío y uno ausente.
    doi = ifelse(doi == "" | is.na(doi), NA, doi),
    # title_norm es el título en minúsculas, con cada carácter distinto de a-z, 0-9 o espacio
    # cambiado por un espacio y con los espacios repetidos reducidos a uno (str_squish). Así
    # coinciden dos versiones del mismo título que solo difieren en puntuación, mayúsculas o
    # espacios. Las letras con tilde también pasan a espacio, porque no están en a-z.
    title_norm = title %>% str_to_lower() %>% str_replace_all("[^a-z0-9 ]", " ") %>%
      str_squish()
  )

# ---- Conteos por bloque y base (antes de deduplicar) ------------------------
# Cuenta los registros de cada bloque en cada base y deja una columna por base con pivot_wider();
# values_fill = 0 pone 0 cuando un bloque no tiene registros en una base. Estos conteos brutos
# forman la primera etapa del diagrama PRISMA.
# El archivo Q7_WoS1_partial.xls es una primera descarga incompleta de la búsqueda Q7 en WoS (sus
# 50 registros están también en Q7_WoS1.xls), así que no entra en los conteos.
counts_raw <- all_rec %>% filter(!str_detect(coalesce(file, ""), "_partial")) %>% count(block, source_db) %>%
  pivot_wider(names_from = source_db, values_from = n, values_fill = 0) %>%
  mutate(total = Scopus + WoS)
# Muestra la tabla y el total de registros antes de deduplicar.
print(counts_raw)
cat("Registros totales:", sum(counts_raw$total), "\n")

# ---- Deduplicación -----------------------------------------------------------
# Clave: DOI cuando existe; si no, el título normalizado. Se conserva el registro
# con resumen más largo y se acumulan los bloques y las bases donde apareció.
# La clave lleva el prefijo "D:" o "T:" para que un DOI y un título nunca se confundan.
# dedupe() aplica las dos pasadas de deduplicación a un conjunto de registros y devuelve un
# registro por publicación: primero los registros con DOI, ordenados por DOI, y después los
# registros sin DOI, ordenados por título, porque summarise() devuelve los grupos ordenados por
# clave. El script la usa dos veces, una con los bloques Q1 a Q6 y otra con el bloque Q7.
dedupe <- function(all_rec) {
  all_rec <- all_rec %>%
    mutate(key = ifelse(is.na(doi), paste0("T:", title_norm), paste0("D:", doi)))

  # Agrupa por clave y ordena cada grupo por el largo del resumen, de mayor a menor (un resumen
  # ausente cuenta como vacío). Así la primera fila de cada grupo es la del resumen más largo, que
  # es la que más información le entrega al cribado.
  dedup <- all_rec %>%
    group_by(key) %>%
    arrange(desc(nchar(coalesce(abstract, ""))), .by_group = TRUE) %>%
    summarise(
      # blocks y dbs acumulan, sin repetir y en orden alfabético, los bloques y las bases en
      # que apareció el registro (por ejemplo, "Q3;Q5" y "Scopus;WoS"), y n_dup cuenta cuántas
      # filas se unieron en el grupo.
      blocks   = paste(sort(unique(block)), collapse = ";"),
      dbs      = paste(sort(unique(source_db)), collapse = ";"),
      n_dup    = n(),
      # Los demás campos se toman de la primera fila del grupo, así que todos vienen del mismo
      # registro. Eso vale también para cited: según qué fila tenga el resumen más largo, las citas
      # vienen de Scopus o de WoS, que no cuentan igual.
      across(c(authors, title, year, journal, doi, abstract, kw_author, kw_index,
               doctype, cited, volume, issue, pages, artno, uid, wos_index,
               title_norm), ~ first(.x)),
      .groups = "drop"  # devuelve la tabla sin agrupar
    )

  # Segunda pasada: registros sin DOI cuyo título coincide con uno que sí lo tiene
  # Si una base exporta el artículo con DOI y la otra sin DOI, la primera pasada deja dos registros,
  # porque sus claves son distintas ("D:" y "T:"). Esta pasada los une. Primero separa los registros
  # sin DOI de los que tienen DOI.
  no_doi <- dedup %>% filter(is.na(doi))
  with_doi <- dedup %>% filter(!is.na(doi))
  # dup_title reúne los registros sin DOI cuyo título normalizado coincide con el de algún registro
  # con DOI. El bloque if solo corre cuando hay al menos un caso.
  dup_title <- no_doi %>% filter(title_norm %in% with_doi$title_norm)
  if (nrow(dup_title) > 0) {
    # merge_blocks guarda, por título, los bloques y las bases del registro sin DOI. Cada
    # título aparece una sola vez en no_doi, porque en la primera pasada era la clave, así
    # que left_join() no duplica filas de with_doi. Si dos registros con DOI comparten el
    # título, ambos reciben esos bloques.
    merge_blocks <- dup_title %>% select(title_norm, blocks2 = blocks, dbs2 = dbs)
    # En las filas con coincidencia (blocks2 no es NA), el código une las dos listas: pega ambas
    # cadenas, las separa por ";", quita los repetidos, ordena y vuelve a unir con ";". sapply()
    # calcula la unión en todas las filas, pero ifelse() solo la usa donde hubo coincidencia.
    # dbs se une de la misma forma.
    with_doi <- with_doi %>% left_join(merge_blocks, by = "title_norm") %>%
      mutate(blocks = ifelse(is.na(blocks2), blocks,
                             sapply(strsplit(paste(blocks, blocks2, sep = ";"), ";"),
                                    function(v) paste(sort(unique(v)), collapse = ";"))),
             dbs = ifelse(is.na(dbs2), dbs,
                          sapply(strsplit(paste(dbs, dbs2, sep = ";"), ";"),
                                 function(v) paste(sort(unique(v)), collapse = ";")))) %>%
      select(-blocks2, -dbs2)  # quita las columnas auxiliares
    # Saca de no_doi los registros que ya quedaron unidos a uno con DOI. n_dup no
    # se actualiza en esta pasada.
    no_doi <- no_doi %>% filter(!(title_norm %in% with_doi$title_norm))
  }
  bind_rows(with_doi, no_doi)
}

# ---- Identificadores ---------------------------------------------------------
# Los registros de los bloques Q1 a Q6 reciben los identificadores R00001, R00002, ... según el
# orden que deja dedupe(). El resto del repositorio se apoya en estos identificadores (lotes y
# decisiones del cribado, duplicates_manual.csv y matrices de verificación), así que el bloque Q7,
# que se agregó después para cubrir los métodos libres de alineamiento, no puede cambiarlos.
# El bloque Q7 se descargó en dos momentos, que el script llama olas. La ola 2 reúne la exportación
# de Scopus y la primera descarga de WoS, que trajo solo los registros 1 a 50 (Q7_WoS1_partial.xls)
# y 1001 a 1041 (Q7_WoS2.xls); sus registros nuevos se cribaron en los lotes 31 a 34. La ola 3 es la
# segunda descarga de WoS, con los registros 1 a 1000 completos (Q7_WoS1.xls), y sus registros
# nuevos se cribaron en los lotes siguientes. Procesar las olas en orden mantiene los
# identificadores de cada ola aunque la siguiente traiga registros nuevos.
all_rec <- all_rec %>% mutate(wave = case_when(block != "Q7" ~ 1L,
                                               coalesce(file, "") == "Q7_WoS1.xls" ~ 3L,
                                               TRUE ~ 2L))
dedup <- dedupe(all_rec %>% filter(wave == 1L)) %>% mutate(id = sprintf("R%05d", row_number()), wave = 1L)
# join_sets() une dos listas separadas por ";" sin repetir y en orden alfabético.
join_sets <- function(x, y) sapply(strsplit(paste(x, y, sep = ";"), ";"), function(v) paste(sort(unique(v)), collapse = ";"))
# add_wave() deduplica los registros de una ola y los compara con los ya identificados. Un registro
# es la misma publicación que uno anterior cuando comparte su clave (el mismo DOI o, sin DOI, el
# mismo título normalizado) o su título normalizado. En ese caso el registro anterior conserva sus
# campos y su identificador, y solo suma los bloques y las bases del nuevo. Los registros sin par
# reciben los identificadores que siguen al último, en el orden de dedupe().
add_wave <- function(dedup, recs, w) {
  dq <- dedupe(recs)
  m <- match(dq$key, dedup$key)
  m <- ifelse(is.na(m), match(dq$title_norm, dedup$title_norm), m)
  for (h in which(!is.na(m))) {
    i <- m[h]
    dedup$blocks[i] <- join_sets(dedup$blocks[i], dq$blocks[h])
    dedup$dbs[i] <- join_sets(dedup$dbs[i], dq$dbs[h])
  }
  nw <- dq[is.na(m), ] %>% mutate(id = sprintf("R%05d", nrow(dedup) + row_number()), wave = w)
  cat("Ola", w, ": registros", nrow(dq), " ya presentes", sum(!is.na(m)), " nuevos", nrow(nw), "\n")
  bind_rows(dedup, nw)
}
dedup <- add_wave(dedup, all_rec %>% filter(wave == 2L), 2L)
dedup <- add_wave(dedup, all_rec %>% filter(wave == 3L), 3L)

# Informa cuántos registros únicos quedan y cuántos duplicados se eliminaron en las dos pasadas.
# Después muestra cuántos registros hay por combinación de bases y por bloque; separate_rows()
# abre "Q3;Q5" en dos filas, así que un registro de varios bloques cuenta en cada uno.
cat("Registros únicos:", nrow(dedup), "\n")
cat("Duplicados eliminados:", sum(counts_raw$total) - nrow(dedup), "\n")
print(dedup %>% count(dbs))
print(dedup %>% separate_rows(blocks, sep = ";") %>% count(blocks))

# ---- Salidas -----------------------------------------------------------------
# Guarda la base unificada, que lee 02_screen.R, y los conteos brutos, que leen
# 07_synthesis.R y 08_tables.R.
write_csv(dedup, "data/processed/db_unique.csv")
write_csv(counts_raw, "data/processed/counts_raw.csv")
