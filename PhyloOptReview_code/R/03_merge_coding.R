# =============================================================================
# 03_merge_coding.R
# Une las decisiones del cribado asistido (archivos JSONL, un objeto por
# registro, rondas 1 y 2) con la base unificada, valida que cada registro
# evaluado tenga exactamente una decisión con códigos del protocolo, calcula la
# concordancia entre el filtro por diccionario (02_screen.R) y el cribado
# asistido (kappa de Cohen), aplica la segunda pasada de duplicados (títulos casi
# idénticos con el mismo primer autor y año, revisados uno a uno en
# duplicates_manual.csv) y asigna la etapa PRISMA de cada registro. La base de
# incluidos queda con la codificación de primer nivel (resumen); la verificación
# del núcleo de optimización se aplica en 05_verification.R.
#
# Entradas: el script lee data/processed/db_screened.csv y las dos listas de candidatos de
# 02_screen.R, las decisiones del cribado asistido en screening/output/batch_XX.jsonl y los
# duplicados confirmados a mano en verification/duplicates_manual.csv.
# Salidas: escribe data/processed/db_final_all.csv, con todos los registros y su etapa PRISMA;
# data/processed/db_included_screened.csv, con los incluidos, que es la entrada de
# 05_verification.R; data/processed/near_duplicate_pairs.csv, con los pares candidatos a
# duplicado; y data/processed/agreement.rds, con la tabla de concordancia, el acuerdo observado y
# el kappa, que lee 07_synthesis.R.
# =============================================================================
# El script fija la configuración regional C.UTF-8 para manejar el texto como UTF-8 y para que el
# orden alfabético sea el mismo en cualquier equipo.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# Carga los paquetes sin mensajes de inicio; jsonlite lee las decisiones en formato JSON.
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(stringr); library(tidyr); library(jsonlite)
})
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/03_merge_coding.R

# ---- Base y candidatos -------------------------------------------------------
# db tiene todos los registros únicos con las marcas de 02_screen.R.
db   <- read_csv("data/processed/db_screened.csv", show_col_types = FALSE, guess_max = 10000)
# cand une los candidatos de las dos rondas y agrega la ronda de cada uno (1L y 2L son enteros).
cand <- bind_rows(read_csv("data/processed/candidates_for_llm.csv", show_col_types = FALSE, guess_max = 10000) %>% mutate(round = 1L),
                  read_csv("data/processed/candidates_round2.csv", show_col_types = FALSE, guess_max = 10000) %>% mutate(round = 2L),
                  read_csv("data/processed/candidates_round3.csv", show_col_types = FALSE, guess_max = 10000) %>% mutate(round = 3L) %>%
                    select(-any_of(c("wave", "batch"))))

# ---- Lectura y validación de las decisiones -----------------------------------
# valid lista los códigos que admite el protocolo (screening/protocol/llm_prompt.txt) en cada
# campo de una decisión. Un registro incluido (inc = 1) lleva todos los campos salvo why, y un
# registro excluido (inc = 0) lleva solo why.
valid <- list(
  # type indica el tipo de aporte: método, evaluación, teoría, métrica o revisión.
  type = c("method", "evaluation", "theory", "metric", "review"),
  # cat indica el bloque temático; so_meta es la búsqueda heurística monoobjetivo y tree_other
  # reúne la demás inferencia de árboles.
  cat  = c("mo", "so_meta", "tree_other", "network", "forest_analysis", "supertree", "morpho", "distance", "parallel"),
  # crit indica el criterio de optimización o de inferencia.
  crit = c("parsimony", "likelihood", "bayesian", "distance", "coalescent", "quartet", "net_parsimony", "pseudolikelihood", "other", "none"),
  # alg indica la familia algorítmica e incluye los algoritmos multiobjetivo con nombre propio
  # (NSGA-II, SPEA2, IBEA y MOEA/D).
  alg  = c("ga_ea", "memetic", "sa", "tabu", "swarm", "immune", "de", "hill_climb", "ratchet", "exact", "mcmc", "divide_conquer",
           "vns_grasp", "ml", "nsga2", "spea2", "ibea", "moead", "other", "none"),
  # rep indica la estructura de la solución.
  rep  = c("tree", "matrix", "split", "cluster", "network", "quartet", "other", "none"),
  # ops indica los operadores o movimientos de búsqueda; nj_init es un árbol
  # inicial de NJ, BIONJ o UPGMA.
  ops  = c("nni", "spr", "tbr", "pdg", "crossover", "mutation", "consensus", "nj_init", "other", "none"),
  # nobj indica el número de objetivos ("na" si no es un método de optimización), y dsd
  # indica si la selección compara soluciones con una distancia o una medida de
  # diversidad en el espacio de decisión.
  nobj = c("1", "2", "3", "many", "na"), dsd = c("yes", "no", "na"),
  # data indica el tipo de dato de entrada.
  data = c("dna", "protein", "morphological", "genomic", "gene_trees", "distances", "other", "unclear"),
  # soft indica si el resumen informa que el software está disponible, y why da el motivo de
  # exclusión: aplicación empírica, otro dominio o ausencia de método.
  soft = c("yes", "unclear"), why = c("application", "other_domain", "no_method"))
# Lista en orden alfabético los archivos de decisiones (batch_01.jsonl, batch_02.jsonl, ...).
files <- sort(list.files("screening/output", pattern = "\\.jsonl$", full.names = TRUE))
# Lee cada archivo línea por línea. Cada línea no vacía es un objeto JSON con la decisión de un
# registro, y el resultado es una tabla con una fila por decisión.
dec <- bind_rows(lapply(files, function(f) {
  # warn = FALSE calla el aviso cuando el archivo no termina en un salto de línea.
  lines <- readLines(f, encoding = "UTF-8", warn = FALSE)
  # Descarta las líneas vacías o que solo tienen espacios.
  lines <- lines[nchar(trimws(lines)) > 0]
  bind_rows(lapply(lines, function(l) {
    # simplifyVector = FALSE deja los arreglos JSON como listas de R, de modo que lst()
    # trata igual todos los campos.
    o <- fromJSON(l, simplifyVector = FALSE)
    # lst() pasa un campo a texto: un campo ausente queda como "" y una lista se une con ";" (por
    # ejemplo, ["parsimony","likelihood"] da "parsimony;likelihood").
    lst <- function(x) if (is.null(x)) "" else paste(unlist(x), collapse = ";")
    # Arma la fila de la decisión; batch guarda el archivo de origen.
    tibble(id = o$id, inc = as.integer(o$inc), why = lst(o$why), type = lst(o$type),
           cat = lst(o$cat), crit = lst(o$crit), alg = lst(o$alg), rep = lst(o$rep),
           ops = lst(o$ops), nobj = lst(o$nobj), dsd = lst(o$dsd), data = lst(o$data),
           soft = lst(o$soft), name = lst(o$name), note = lst(o$note),
           batch = basename(f))
  }))
}))
# Comprueba que haya exactamente una decisión por candidato: tantas decisiones como candidatos, el
# mismo conjunto de identificadores y ningún identificador repetido. Si falta o sobra una
# decisión, el script se detiene.
stopifnot(nrow(dec) == nrow(cand), setequal(dec$id, cand$id), !any(duplicated(dec$id)))
# Revisa que cada código esté en la lista permitida. En why mira solo los excluidos y en los
# demás campos solo los incluidos. Un campo vacío en un registro que debía tenerlo queda como "",
# que no está permitido, así que también se detecta. Cada campo con códigos inválidos suma 1 a
# bad e imprime esos códigos, y al final el script se detiene si hubo alguno. name y note son
# texto libre y no se validan.
bad <- 0
for (f in names(valid)) {
  v <- if (f == "why") dec[[f]][dec$inc == 0] else dec[[f]][dec$inc == 1]
  codes <- unlist(str_split(v, ";"))  # separa los campos con varios códigos
  if (any(!codes %in% valid[[f]])) { bad <- bad + 1; print(unique(codes[!codes %in% valid[[f]]])) }
}
stopifnot(bad == 0)
# Informa cuántas decisiones hay, cuántos registros se incluyeron y cuántos
# incluidos aportó cada ronda.
cat("Decisiones:", nrow(dec), " incluidos:", sum(dec$inc), " (ronda 1:", sum(dec$inc[dec$id %in% cand$id[cand$round == 1]]),
    "; ronda 2:", sum(dec$inc[dec$id %in% cand$id[cand$round == 2]]),
    "; ronda 3:", sum(dec$inc[dec$id %in% cand$id[cand$round == 3]]), ")\n")

# ---- Segunda pasada de duplicados ------------------------------------------------
# Pares candidatos: mismo primer autor, años a lo más a un año de distancia y
# similitud de Jaccard entre las palabras del título de al menos 0.8. Cada par se
# revisó a mano: se eliminan los que son la misma publicación (variantes del DOI,
# preprint y artículo, recomendación y artículo); las versiones de congreso y de
# revista de un mismo estudio se conservan como reportes distintos.
# norm() normaliza un título: pasa las letras con tilde a ASCII (é da e), deja todo en minúsculas,
# cambia por un espacio cada carácter distinto de a-z, 0-9 o espacio y reduce los espacios
# repetidos. A diferencia de title_norm en 01_merge.R, conserva las letras con tilde como letras.
norm <- function(x) str_squish(str_replace_all(str_to_lower(iconv(x, to = "ASCII//TRANSLIT")), "[^a-z0-9 ]", " "))
# fa es la clave del primer autor. El código toma el texto hasta el primer ";" o ",", que es el
# primer autor en ambos formatos ("Matasci N.; ..." en Scopus y "Gernandt, DS; ..." en WoS), borra
# las iniciales desde el primer espacio seguido de una mayúscula, pasa a minúsculas, translitera
# las tildes y deja solo letras. Así, "Vázquez-Lobo, A" da "vazquezlobo". En un apellido compuesto
# queda solo la primera palabra ("Da Cunha D.B." da "da"), lo que no hace perder pares, porque una
# clave más corta solo junta más registros en el mismo grupo.
fa <- str_to_lower(str_replace(str_split_fixed(coalesce(db$authors, ""), "[;,]", 2)[, 1], "\\s+[A-Z]\\.?.*$", "")) %>%
  iconv(to = "ASCII//TRANSLIT") %>% str_replace_all("[^a-z]", "")
# tok guarda las palabras de cada título normalizado.
tok <- strsplit(norm(db$title), " ")
# pairs acumula los pares candidatos. El código compara títulos solo dentro de cada grupo con el
# mismo primer autor, lo que evita comparar todos los registros contra todos (decenas de millones
# de pares). El umbral de 0.8 tolera cambios menores en el título, como un subtítulo o una palabra
# distinta, y la diferencia de un año cubre una versión preliminar y su versión publicada, o una
# fecha en línea y otra impresa.
pairs <- list()
for (g in split(seq_len(nrow(db)), fa)) {  # g tiene las filas de un mismo primer autor
  if (length(g) < 2) next  # un grupo de un solo registro no tiene pares
  for (i in 1:(length(g) - 1)) for (j in (i + 1):length(g)) {  # cada par una sola vez
    x <- tok[[g[i]]]; y <- tok[[g[j]]]
    # s es la similitud de Jaccard. intersect() y union() tratan las palabras como conjuntos, y s
    # divide el número de palabras en común por el número de palabras distintas de ambos títulos.
    s <- length(intersect(x, y)) / length(union(x, y))
    # !is.na(s) descarta el caso 0/0 de dos títulos vacíos. La condición supone que todos los
    # registros tienen año, porque con un año ausente da NA e if() se detiene con un error; en las
    # exportaciones actuales ningún registro carece de año.
    if (!is.na(s) && s >= 0.8 && abs(db$year[g[i]] - db$year[g[j]]) <= 1)
      pairs[[length(pairs) + 1]] <- tibble(a = db$id[g[i]], b = db$id[g[j]], sim = s)
  }
}
pairs <- bind_rows(pairs)  # tabla con las columnas a, b y sim
# duplicates_manual.csv tiene un par confirmado por fila: id_drop es el registro que se elimina,
# id_keep el que se conserva y reason el motivo.
dupm <- read_csv("verification/duplicates_manual.csv", show_col_types = FALSE)
# found arma una clave por par que no depende del orden: pmin() y pmax() ponen primero el
# identificador menor. Como los identificadores tienen ceros a la izquierda, el orden
# alfabético coincide con el numérico.
found <- paste(pmin(pairs$a, pairs$b), pmax(pairs$a, pairs$b))
# Comprueba que cada par confirmado a mano esté entre los pares candidatos. Si cambian los
# identificadores o la regla de búsqueda, el archivo manual deja de calzar y el script se detiene.
stopifnot(all(paste(pmin(dupm$id_drop, dupm$id_keep), pmax(dupm$id_drop, dupm$id_keep)) %in% found))
cat("Pares candidatos:", nrow(pairs), " duplicados confirmados:", nrow(dupm), "\n")
# Guarda todos los pares candidatos con su similitud y la columna duplicate, que vale TRUE en los
# pares confirmados. Así queda documentada la revisión manual: qué pares se revisaron y cuáles
# resultaron ser la misma publicación.
write_csv(pairs %>% mutate(duplicate = paste(pmin(a, b), pmax(a, b)) %in%
                             paste(pmin(dupm$id_drop, dupm$id_keep), pmax(dupm$id_drop, dupm$id_keep))),
          "data/processed/near_duplicate_pairs.csv")

# ---- Concordancia entre el diccionario y el cribado asistido ------------------
# Se calcula sobre los registros evaluados que no resultaron duplicados.
# Todos los registros evaluados tienen resumen, están en el alcance y son de un tipo válido, así
# que para ellos la decisión del diccionario (included) se reduce a f_method. agree renombra
# included como dict, le une la decisión del cribado asistido (inc) y pasa dict de lógico a
# entero. La condición !id %in% x se lee !(id %in% x), porque %in% se evalúa antes que !.
agree <- db %>% filter(id %in% cand$id, !id %in% dupm$id_drop) %>% select(id, dict = included) %>%
  left_join(dec %>% select(id, inc), by = "id") %>% mutate(dict = as.integer(dict))
# tab es la tabla de contingencia de 2 x 2, con el diccionario en las filas y el
# cribado asistido en las columnas.
tab <- table(dictionary = agree$dict, assisted = agree$inc)
# po es el acuerdo observado: la proporción de registros en la diagonal, donde
# ambos incluyen o ambos excluyen.
po <- sum(diag(tab)) / sum(tab)
# pe es el acuerdo esperado por azar: la suma de los productos de los totales de fila y de columna
# de cada categoría, dividida por el total al cuadrado.
pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
# El kappa de Cohen mide el acuerdo por sobre el azar como fracción del máximo posible. La fórmula
# supone que ambos evaluadores usan las dos categorías, de modo que la tabla es de 2 x 2 y su
# diagonal reúne los acuerdos.
kappa <- (po - pe) / (1 - pe)
print(tab); cat(sprintf("Acuerdo observado = %.3f; kappa de Cohen = %.3f\n", po, kappa))

# ---- Etapas PRISMA ---------------------------------------------------------------
# final une a cada registro su decisión del cribado, sin la columna batch, y su ronda. Los
# registros que no pasaron por el cribado quedan con NA en esas columnas.
final <- db %>% left_join(dec %>% select(-batch), by = "id") %>%
  left_join(cand %>% select(id, round), by = "id") %>%
  mutate(
    # stage asigna la etapa PRISMA. case_when() usa la primera condición verdadera, así que
    # el orden fija la prioridad: un duplicado confirmado cuenta como duplicado aunque falle
    # otro filtro, después vienen los filtros automáticos de 02_screen.R y al final las
    # decisiones del cribado. Cuando inc es NA, las condiciones que usan inc dan NA y
    # case_when() las trata como falsas.
    stage = case_when(
      id %in% dupm$id_drop ~ "duplicate",
      !f_has_abstract ~ "excluded: no abstract",
      !f_scope ~ "excluded: outside phylogenetics",
      f_exclude_type ~ "excluded: document type",
      inc == 0 & why == "application" ~ "excluded: empirical application",
      inc == 0 & why == "other_domain" ~ "excluded: other domain",
      inc == 0 & why == "no_method" ~ "excluded: no method",
      inc == 1 ~ "included",
      TRUE ~ "check"))
# Ningún registro puede quedar en "check". Eso pasaría si un registro que superó los filtros
# automáticos no tuviera decisión o si why trajera un motivo no previsto.
stopifnot(!any(final$stage == "check"))
print(final %>% count(stage))  # registros por etapa

# ---- Salidas -----------------------------------------------------------------
# Guarda todos los registros con su etapa y, aparte, solo los incluidos, que son la entrada
# de 05_verification.R. Ese script reescribe después db_final_all.csv con las exclusiones
# de la verificación. any_of() quita text y title_l solo si existen; 02_screen.R ya las
# quitó, así que es una protección.
write_csv(final %>% select(-any_of(c("text", "title_l"))), "data/processed/db_final_all.csv")
write_csv(final %>% filter(stage == "included") %>% select(-any_of(c("text", "title_l"))), "data/processed/db_included_screened.csv")
# Guarda la tabla de concordancia, el acuerdo observado y el kappa, que 07_synthesis.R lleva a
# results/tables/prisma_counts.csv.
saveRDS(list(tab = tab, po = po, kappa = kappa), "data/processed/agreement.rds")
