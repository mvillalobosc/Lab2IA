# =============================================================================
# 04_verify_sample.R
# Confiabilidad del cribado asistido. Extrae dos muestras aleatorias
# estratificadas por lote (semilla fija): 300 registros de la primera ronda y
# 100 de la segunda. Cada muestra se cribó por segunda vez de forma independiente
# con el mismo protocolo y sin acceso a las decisiones de la primera pasada. Si
# existen los archivos de la segunda pasada, calcula el acuerdo observado y el
# kappa de Cohen para la inclusión (por ronda y en conjunto), y el acuerdo en el
# bloque temático principal de los registros incluidos en ambas pasadas.
#
# Este script no hace la segunda pasada. Un agente independiente cribó sample_300.txt y
# sample_r2_100.txt fuera de R, siguiendo la instrucción C de
# screening/protocol/agent_instructions.txt y sin abrir las decisiones de la primera pasada,
# y dejó las suyas en los archivos .jsonl de screening/reliability/. Si esos archivos no
# existen, el script solo escribe las muestras, pero en este repositorio ya están, así que
# una sola corrida extrae las muestras y calcula el acuerdo.
#
# Entradas
#   data/processed/candidates_for_llm.csv     candidatos de la primera ronda (02_screen.R)
#   data/processed/candidates_round2.csv      candidatos de la segunda ronda (02_screen.R)
#   screening/output/batch_XX.jsonl           decisiones de la primera pasada (lotes 01 a 30)
#   screening/reliability/sample_300.jsonl    decisiones de la segunda pasada, primera ronda
#   screening/reliability/sample_r2_100.jsonl decisiones de la segunda pasada, segunda ronda
# Salidas
#   screening/reliability/sample_300.txt      muestra de la primera ronda, en formato de lote
#   screening/reliability/sample_r2_100.txt   muestra de la segunda ronda, en formato de lote
#   data/processed/verify.rds                 tablas, acuerdo y kappa (los lee 07_synthesis.R)
# =============================================================================
# Fija la configuración regional en C.UTF-8 para que los ordenamientos y el manejo de textos
# con acentos den el mismo resultado en cualquier equipo.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee los CSV, dplyr y stringr manejan tablas y textos, y jsonlite interpreta las
# decisiones del cribado, que están en formato JSON.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr); library(jsonlite) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/04_verify_sample.R
# Crea la carpeta de las muestras si falta (showWarnings = FALSE evita el aviso si ya existe).
dir.create("screening/reliability", recursive = TRUE, showWarnings = FALSE)

# ---- Muestras estratificadas por lote -------------------------------------------
# draw_sample() recibe la tabla de candidatos de una ronda (cand), extrae una muestra aleatoria
# de n registros estratificada por lote y la escribe en el archivo file con el formato de los
# lotes del cribado (screening/input/batch_XX.txt), para que la segunda pasada lea exactamente
# la misma información que la primera. Devuelve la muestra como tabla.
draw_sample <- function(cand, n, file) {
  # Ordena por identificador, que es el orden en que 02_screen.R cortó los lotes.
  cand <- cand %>% arrange(id)
  # Reconstruye el lote de cada registro: las filas 1 a 250 forman el lote 1, las 251 a 500
  # el lote 2, y así sucesivamente (en la segunda ronda, el lote 1 de esta numeración es
  # batch_18). La función estratifica por lote porque cada lote lo cribó un agente distinto,
  # y así todos los lotes quedan representados en proporción a su tamaño.
  cand$batch <- ceiling(seq_len(nrow(cand)) / 250)
  # La semilla fija hace que la muestra salga siempre igual, y eso es necesario para que los
  # .jsonl de la segunda pasada sigan correspondiendo a la muestra. Cada llamada a
  # draw_sample() vuelve a fijarla.
  set.seed(2026)
  # La asignación es proporcional: de cada lote sale la fracción n / total de sus registros.
  # Como slice_sample() redondea hacia abajo el tamaño de cada estrato, la suma queda bajo n
  # (en la primera ronda salen 17 registros por lote completo y 284 en total).
  smp <- cand %>% group_by(batch) %>% slice_sample(prop = n / nrow(cand)) %>% ungroup()
  # Los registros que faltan para llegar a n salen de un muestreo aleatorio simple entre los
  # candidatos no elegidos (con estos datos, 16 en la primera ronda y 11 en la segunda).
  if (nrow(smp) < n) smp <- bind_rows(smp, cand %>% filter(!id %in% smp$id) %>% slice_sample(n = n - nrow(smp)))
  # La función escribe la muestra en el orden de los identificadores, igual que los lotes.
  smp <- smp %>% arrange(id)
  # Cada registro ocupa un bloque de texto con la cabecera "### id | blocks=... | year=..." y
  # las líneas TITLE, KEYWORDS y ABSTRACT. En la cabecera, blocks son los bloques de búsqueda
  # (Q1 a Q6) que recuperaron el registro, no los bloques temáticos. 02_screen.R ya recortó el
  # resumen a 1.500 caracteres. El texto termina en un salto de línea y writeLines() agrega
  # otro, así que queda una línea en blanco entre registros. La conexión abre el archivo en
  # UTF-8 para conservar los acentos.
  # El repositorio público no distribuye los resúmenes, porque son parte de las exportaciones
  # de Scopus y Web of Science. Sin la columna abstract, la función no escribe el archivo de
  # la muestra y solo devuelve la tabla, que basta para medir la concordancia con las
  # decisiones de screening/reliability/*.jsonl.
  if ("abstract" %in% names(smp)) {
    con <- file(file, open = "w", encoding = "UTF-8")
    for (j in seq_len(nrow(smp))) {
      writeLines(sprintf("### %s | blocks=%s | year=%s\nTITLE: %s\nKEYWORDS: %s\nABSTRACT: %s\n",
                         smp$id[j], smp$blocks[j], smp$year[j], smp$title[j], smp$kw[j], smp$abstract[j]), con)
    }
    close(con)
  }
  smp
}
# La muestra de la primera ronda tiene 300 de los 4.171 candidatos con descriptores
# computacionales (lotes 01 a 17, cerca del 7 %), y la de la segunda, 100 de los 3.189
# registros restantes con resumen, en el alcance y de un tipo válido (lotes 18 a 30, cerca del
# 3 %). guess_max = 10000 hace que read_csv() revise 10.000 filas antes de decidir el tipo de
# cada columna, y así no se equivoca con columnas que empiezan vacías.
smp1 <- draw_sample(read_csv("data/processed/candidates_for_llm.csv", show_col_types = FALSE, guess_max = 10000), 300, "screening/reliability/sample_300.txt")
smp2 <- draw_sample(read_csv("data/processed/candidates_round2.csv", show_col_types = FALSE, guess_max = 10000), 100, "screening/reliability/sample_r2_100.txt")
# Informa en la consola el tamaño de las dos muestras.
# La tercera ronda (bloque Q7) se cribó en dos olas de descarga (ver 01_merge.R), y cada ola tiene
# su propia muestra, sacada de la misma forma y con la misma proporción (cerca del 10 %): 100
# registros de los 976 de la ola 2 y 28 de los 273 de la ola 3.
cand3 <- read_csv("data/processed/candidates_round3.csv", show_col_types = FALSE, guess_max = 10000)
smp3 <- bind_rows(draw_sample(cand3 %>% filter(wave == 2), 100, "screening/reliability/sample_r3_100.txt"),
                  draw_sample(cand3 %>% filter(wave == 3), 28, "screening/reliability/sample_r3b_28.txt"))
cat("Muestras:", nrow(smp1), ",", nrow(smp2), "y", nrow(smp3), "registros\n")

# ---- Funciones para comparar las dos pasadas ------------------------------------
# read_jsonl() lee un archivo JSON Lines (un objeto JSON por línea), descarta las líneas en
# blanco y devuelve una tabla con el identificador, la decisión de inclusión (inc, 0 o 1) y
# las categorías temáticas unidas con ";". Los registros excluidos no traen "cat", y en ese
# caso la categoría queda vacía.
read_jsonl <- function(f) {
  lines <- readLines(f, encoding = "UTF-8", warn = FALSE); lines <- lines[nchar(trimws(lines)) > 0]
  bind_rows(lapply(lines, function(l) {
    # simplifyVector = FALSE deja los arreglos JSON como listas, y unlist() los convierte en
    # vector antes de unir los códigos.
    o <- fromJSON(l, simplifyVector = FALSE)
    tibble(id = o$id, inc = as.integer(o$inc), cat = if (is.null(o$cat)) "" else paste(unlist(o$cat), collapse = ";"))
  }))
}
# kappa_fun() compara dos vectores de decisiones 0/1 sobre los mismos registros. Arma la tabla
# de 2 x 2 con los niveles 0 y 1 fijos, para que tenga siempre dos filas y dos columnas aunque
# una decisión no aparezca, y calcula el acuerdo observado po (proporción de la diagonal), el
# acuerdo esperado por azar pe (suma de los productos de los totales marginales, dividida por
# el total al cuadrado) y el kappa de Cohen, (po - pe) / (1 - pe). El kappa descuenta el
# acuerdo que se daría por azar, que es alto cuando una decisión domina, como la exclusión en
# la segunda ronda.
kappa_fun <- function(a, b) {
  tab <- table(factor(a, levels = 0:1), factor(b, levels = 0:1))
  po <- sum(diag(tab)) / sum(tab); pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  list(tab = tab, po = po, kappa = (po - pe) / (1 - pe))
}
# prio fija la prioridad de los bloques temáticos, la misma de 05_verification.R. Un registro
# puede tener varias categorías, y su bloque principal es la primera de esta lista que aparece
# entre ellas. El orden pone primero el núcleo de optimización de la revisión (mo y so_meta),
# luego los problemas específicos y al final la inferencia de árboles general (tree_other) y
# el cómputo paralelo (parallel).
prio <- c("mo", "so_meta", "network", "supertree", "forest_analysis", "morpho", "distance", "tree_other", "parallel")
# mainb() aplica esa prioridad a cada texto de categorías separadas por ";" y devuelve NA si
# ninguna está en la lista. Aquí el bloque sale de los códigos tal como quedaron en el
# cribado, sin las correcciones ni el paso de parallel a tree_other de 05_verification.R.
mainb <- function(x) sapply(str_split(x, ";"), function(v) { p <- prio[prio %in% v]; if (length(p)) p[1] else NA })
# compare() junta la segunda pasada de una muestra (archivo f2) con las decisiones de la
# primera pasada y calcula el acuerdo en la inclusión y en el bloque principal.
compare <- function(smp, f2) {
  # Lee todas las decisiones de la primera pasada, que están en screening/output/ (un archivo
  # por lote). La expresión regular "\\.jsonl$" elige los archivos que terminan en .jsonl.
  first <- bind_rows(lapply(sort(list.files("screening/output", "\\.jsonl$", full.names = TRUE)), read_jsonl))
  second <- bind_rows(lapply(f2, read_jsonl))  # f2 puede traer varios archivos de una misma ronda
  # stopifnot() exige que la segunda pasada traiga exactamente los registros de la muestra,
  # ni más ni menos.
  stopifnot(setequal(second$id, smp$id))
  # Une cada decisión de la segunda pasada (renombrada inc2 y cat2) con la de la primera por
  # identificador. El stopifnot siguiente exige que todos los registros tengan decisión en la
  # primera pasada.
  j <- second %>% rename(inc2 = inc, cat2 = cat) %>% left_join(first, by = "id")
  stopifnot(!any(is.na(j$inc)))
  # Calcula el kappa de Cohen entre las dos pasadas para la decisión de inclusión.
  k <- kappa_fun(j$inc, j$inc2)
  # La función mide el acuerdo de bloque solo en los registros que ambas pasadas incluyeron,
  # porque solo ellos tienen categorías en las dos. agree_block es la proporción de esos
  # registros con el mismo bloque principal (na.rm = TRUE descarta los que no tienen bloque, y
  # el valor queda NA si ningún registro quedó incluido en ambas pasadas).
  both <- j %>% filter(inc == 1, inc2 == 1)
  list(j = j, tab = k$tab, po = k$po, kappa = k$kappa, n_both = nrow(both),
       agree_block = if (nrow(both)) mean(mainb(both$cat) == mainb(both$cat2), na.rm = TRUE) else NA)
}
# ---- Acuerdo entre las dos pasadas ----------------------------------------------
# f1 y f2 son los archivos con las decisiones de la segunda pasada, y el cálculo corre solo si
# existen los dos.
f1 <- "screening/reliability/sample_300.jsonl"; f2 <- "screening/reliability/sample_r2_100.jsonl"; f3 <- c("screening/reliability/sample_r3_100.jsonl", "screening/reliability/sample_r3b_28.jsonl")
if (file.exists(f1) && file.exists(f2) && all(file.exists(f3))) {
  # v1, v2 y v3 guardan el acuerdo de la primera, la segunda y la tercera ronda.
  v1 <- compare(smp1, f1); v2 <- compare(smp2, f2); v3 <- compare(smp3, f3)
  # Para el acuerdo en conjunto, el script junta los pares de decisiones de las tres muestras
  # (528 registros) y calcula el kappa sobre la tabla conjunta, no como promedio de las tres.
  jj <- bind_rows(v1$j, v2$j, v3$j); k <- kappa_fun(jj$inc, jj$inc2)
  # agree_block mide el acuerdo de bloque en conjunto, sobre los registros que ambas pasadas
  # incluyeron.
  both <- jj %>% filter(inc == 1, inc2 == 1)
  agree_block <- mean(mainb(both$cat) == mainb(both$cat2), na.rm = TRUE)
  # Imprime la tabla de 2 x 2 y los indicadores de cada ronda, y después los del conjunto.
  for (v in list(v1, v2, v3)) { print(v$tab); cat(sprintf("acuerdo = %.3f; kappa = %.3f; incluidos en ambas = %d; bloque = %.3f\n", v$po, v$kappa, v$n_both, v$agree_block)) }
  print(k$tab); cat(sprintf("Conjunto: acuerdo = %.3f; kappa = %.3f; incluidos en ambas = %d; acuerdo de bloque = %.3f\n", k$po, k$kappa, nrow(both), agree_block))
  # Guarda en data/processed/verify.rds los resultados del conjunto (tab, po, kappa, n_both,
  # agree_block) y los de cada ronda en r1, r2 y r3. 07_synthesis.R los copia a
  # results/tables/prisma_counts.csv.
  saveRDS(list(tab = k$tab, po = k$po, kappa = k$kappa, n_both = nrow(both), agree_block = agree_block,
               r1 = v1[c("tab", "po", "kappa", "n_both", "agree_block")],
               r2 = v2[c("tab", "po", "kappa", "n_both", "agree_block")],
               r3 = v3[c("tab", "po", "kappa", "n_both", "agree_block")]), "data/processed/verify.rds")
}
