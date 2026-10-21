# =============================================================================
# 05_verification.R
# Verificación del núcleo de optimización (estudios multiobjetivo y de búsqueda
# heurística monoobjetivo). Las matrices verification/mo_matrix.csv y
# verification/so_matrix.csv agrupan esos estudios por estrategia y registran el
# criterio, la estructura de la solución, los operadores y si la selección usa
# diversidad en el espacio de decisión, verificados con el texto completo, la
# página del editor o los artículos del autor cuando el resumen no lo informa
# (columna "source"). Este script (1) aplica las correcciones manuales de
# verification_corrections.csv (exclusiones y recodificaciones), (2) incorpora a
# la codificación de primer nivel los criterios, algoritmos, operadores, número
# de objetivos y diversidad verificados en las filas no marcadas, (3) construye
# las columnas binarias que alimentan el árbol de la literatura, el bloque
# principal y la etiqueta de cada estudio.
#
# Entradas (las dos primeras salen de 03_merge_coding.R)
#   data/processed/db_included_screened.csv   incluidos, con la codificación del cribado
#   data/processed/db_final_all.csv           todos los registros, con su etapa PRISMA
#   verification/verification_corrections.csv correcciones manuales (id, action, value, reason)
#   verification/duplicates_manual.csv        duplicados confirmados (id_drop, id_keep)
#   verification/mo_matrix.csv                verificación de los estudios multiobjetivo
#   verification/so_matrix.csv                verificación de la búsqueda monoobjetivo
# Salidas
#   data/processed/db_final_all.csv           la misma base, con la etapa de los excluidos en
#                                             la verificación (se sobrescribe)
#   data/processed/db_included_coded.csv      incluidos con códigos verificados, columnas
#                                             binarias, bloque principal y etiqueta
#   data/processed/verification_log.csv       códigos antes y después de la verificación
# =============================================================================
# Fija la configuración regional en C.UTF-8 para que los ordenamientos y el manejo de textos
# con acentos den el mismo resultado en cualquier equipo.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee y escribe los CSV, dplyr y tidyr manejan las tablas, y stringr aplica las
# expresiones regulares que traducen los textos de las matrices a códigos.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr); library(tidyr) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/05_verification.R

# ---- Datos de entrada -----------------------------------------------------------
# inc tiene un estudio incluido en el cribado por fila, con sus códigos separados por ";" en
# las columnas cat, type, crit, alg, rep, ops, nobj, dsd, data y soft (los códigos están
# definidos en screening/protocol/llm_prompt.txt). allr tiene todos los registros únicos con
# su etapa PRISMA, y corr, dupm, mo_m y so_m son las tablas de verification/ descritas arriba.
# guess_max = 10000 hace que read_csv() revise 10.000 filas antes de decidir el tipo de cada
# columna, y así no se equivoca con columnas que empiezan vacías.
inc  <- read_csv("data/processed/db_included_screened.csv", show_col_types = FALSE, guess_max = 10000)
allr <- read_csv("data/processed/db_final_all.csv", show_col_types = FALSE, guess_max = 10000)
corr <- read_csv("verification/verification_corrections.csv", show_col_types = FALSE)
dupm <- read_csv("verification/duplicates_manual.csv", show_col_types = FALSE)
mo_m <- read_csv("verification/mo_matrix.csv", show_col_types = FALSE)
so_m <- read_csv("verification/so_matrix.csv", show_col_types = FALSE)

# Las matrices se construyeron antes de la segunda pasada de duplicados: se quitan
# los registros eliminados y se exige que cubran todo el núcleo de optimización.
# drop_ids() quita de la columna ids de una matriz (identificadores separados por ";") los
# registros que duplicates_manual.csv marca como duplicados (id_drop). Con los datos
# actuales, solo R04110 estaba en una matriz.
drop_ids <- function(m) { m$ids <- sapply(str_split(m$ids, ";"), function(v) paste(setdiff(v, dupm$id_drop), collapse = ";")); m }
mo_m <- drop_ids(mo_m); so_m <- drop_ids(so_m)
# El script define el núcleo de optimización con la codificación del cribado. El núcleo MO
# son los estudios con la categoría mo, y el núcleo SO los que tienen so_meta sin mo, porque
# los que tienen ambas van a la matriz MO. La expresión "(^|;)mo(;|$)" exige que mo sea un
# código completo de la lista separada por ";" (precedido por el inicio o por ";" y seguido
# por ";" o por el final), de modo que no coincide con morpho.
core_mo <- inc$id[str_detect(inc$cat, "(^|;)mo(;|$)")]
core_so <- inc$id[str_detect(inc$cat, "(^|;)so_meta(;|$)") & !str_detect(inc$cat, "(^|;)mo(;|$)")]
# ids_mo e ids_so reúnen los identificadores de todas las filas de cada matriz.
ids_mo <- unlist(str_split(mo_m$ids, ";")); ids_so <- unlist(str_split(so_m$ids, ";"))
# Las dos líneas siguientes informan en la consola los estudios del núcleo MO que no tienen
# fila en la matriz y los de la matriz que no están en el núcleo. No detienen el script, así
# que quien lo corre debe revisar que ambas listas salgan vacías, como ocurre con los datos
# actuales. core_so e ids_so sirven para hacer la misma revisión con la matriz SO, que hoy
# también calza con su núcleo.
cat("Núcleo MO sin fila en la matriz:", setdiff(core_mo, ids_mo), "\n")
cat("Estudios de la matriz MO fuera del núcleo MO:", setdiff(ids_mo, core_mo), "\n")

# ---- 1. Correcciones manuales ---------------------------------------------------
# verification_corrections.csv tiene una fila por corrección, con la acción (action), el
# valor (value) y el motivo (reason). La acción "exclude" saca de los incluidos a los
# estudios que, según la verificación, son aplicaciones empíricas y no aportes de método.
excl <- corr %>% filter(action == "exclude")
inc <- inc %>% filter(!id %in% excl$id)
# En la base completa, esos estudios pasan a una etapa PRISMA propia. El texto de la etapa es
# fijo porque las tres exclusiones tienen el motivo application.
allr$stage[allr$id %in% excl$id] <- "excluded at verification: empirical application"
# La acción "drop_cat" quita una categoría temática que el texto completo no sostiene (por
# ejemplo, mo en un estudio sin búsqueda multiobjetivo). Si al estudio no le queda ninguna
# categoría, recibe tree_other, la categoría general de inferencia de árboles.
for (k in which(corr$action == "drop_cat")) {
  i <- which(inc$id == corr$id[k])
  v <- setdiff(str_split(inc$cat[i], ";")[[1]], corr$value[k])
  inc$cat[i] <- paste(if (length(v)) v else "tree_other", collapse = ";")
}
# La acción "set_nobj" reemplaza el número de objetivos por el verificado (1 si el estudio
# optimiza un solo objetivo y na si no es un método de optimización).
for (k in which(corr$action == "set_nobj")) inc$nobj[inc$id == corr$id[k]] <- corr$value[k]

# ---- 2. Códigos verificados en las matrices -------------------------------------
# Las matrices describen cada estrategia con texto libre (por ejemplo, "MP; ML" o "NSGA-II;
# SPEA2"). Las funciones map_*() traducen ese texto a los códigos del protocolo de cribado
# con expresiones regulares, y devuelven un vector vacío cuando la celda está vacía o empieza
# con "n.a." (no aplica) o "n.r." (no informado). La expresión "^n\\.[ar]\\." reconoce esos
# dos prefijos, porque \\. es un punto literal y [ar] acepta una a o una r.
#
# map_crit() traduce la columna criteria a códigos de criterio (crit). Salvo la regla de
# distancia, sus búsquedas no distinguen mayúsculas (ignore_case = TRUE).
map_crit <- function(x) {
  if (is.na(x) || str_detect(x, "^n\\.[ar]\\.")) return(character(0))
  out <- character(0)
  # Esta regla detecta la parsimonia de redes (hardwired, softwired o número de reticulaciones).
  if (str_detect(x, regex("hardwired|softwired|reticulation", ignore_case = TRUE))) out <- c(out, "net_parsimony")
  # Para la parsimonia de árboles, la regla borra primero las frases de parsimonia de redes,
  # para no contarlas dos veces, y después busca MP como palabra completa (\\b marca el
  # límite de palabra) o la palabra parsimony.
  if (str_detect(str_remove_all(x, regex("hardwired parsimony|softwired parsimony|network parsimony", ignore_case = TRUE)), regex("\\bMP\\b|parsimony", ignore_case = TRUE))) out <- c(out, "parsimony")
  # Esta regla detecta la pseudoverosimilitud, incluida la verosimilitud compuesta.
  if (str_detect(x, regex("pseudo-likelihood|pseudolikelihood|composite likelihood", ignore_case = TRUE))) out <- c(out, "pseudolikelihood")
  # Para la verosimilitud, la regla borra antes las frases de pseudoverosimilitud, igual que
  # con la parsimonia, y después busca ML como palabra completa o la palabra likelihood.
  if (str_detect(str_remove_all(x, regex("pseudo-likelihood|pseudolikelihood|composite likelihood", ignore_case = TRUE)), regex("\\bML\\b|likelihood", ignore_case = TRUE))) out <- c(out, "likelihood")
  # La regla de distancia detecta la evolución mínima (ME, BME), los mínimos cuadrados (LS) y
  # la condición de cuatro puntos. Distingue mayúsculas para tomar ME, LS y BME solo como
  # siglas, y usa el plural "distances" (como en "fit to distances") porque el singular
  # aparece sobre todo en distancias entre árboles o genomas (RF, rSPR, DCJ), que no son este
  # criterio.
  if (str_detect(x, regex("\\bME\\b|\\bLS\\b|\\bBME\\b|minimum evolution|least squares|four-point|distances", ignore_case = FALSE))) out <- c(out, "distance")
  # Esta regla detecta la inferencia bayesiana por BI como palabra completa o por bayesian.
  if (str_detect(x, regex("\\bBI\\b|bayesian", ignore_case = TRUE))) out <- c(out, "bayesian")
  # Esta regla detecta los criterios basados en cuartetos.
  if (str_detect(x, regex("quartet", ignore_case = TRUE))) out <- c(out, "quartet")
  # Los criterios de eventos o de reordenamientos (duplicaciones, transferencias, pérdidas,
  # migraciones, coalescencias profundas, DCJ) caen en el código other del protocolo.
  if (str_detect(x, regex("duplication|transfer|loss|event|migration|coalescence|DCJ", ignore_case = TRUE))) out <- c(out, "other")
  unique(out)  # deja cada código una sola vez
}
# map_ops() traduce la columna main_operators a códigos de operadores (ops), con una regla
# por operador. Salvo \\bNJ\\b, los patrones no llevan límites de palabra, así que una sigla
# también cuenta dentro de otra más larga.
map_ops <- function(x) {
  if (is.na(x) || str_detect(x, "^n\\.[ar]\\.")) return(character(0))
  out <- character(0)
  # Esta regla detecta prune-delete-graft (PDG) sin distinguir mayúsculas.
  if (str_detect(x, regex("PDG|prune-delete-graft", ignore_case = TRUE))) out <- c(out, "pdg")
  # Busca NNI solo en mayúscula, y también cuenta variantes como BNNI o k-NNI.
  if (str_detect(x, "NNI")) out <- c(out, "nni")
  # Esta regla detecta SPR y sus nombres largos (subtree prune and regraft y variantes) y LPR
  # (leaf pruning and regrafting). Distingue mayúsculas y también cuenta rSPR o BSPR.
  if (str_detect(x, regex("SPR|subtree prune|prune and regraft|prune-and-graft|prune and reattach|LPR", ignore_case = FALSE))) out <- c(out, "spr")
  # Busca TBR solo en mayúscula.
  if (str_detect(x, "TBR")) out <- c(out, "tbr")
  # Para el cruzamiento, la regla toma recombination como sinónimo, como se usa en los
  # algoritmos evolutivos.
  if (str_detect(x, regex("crossover|recombination", ignore_case = TRUE))) out <- c(out, "crossover")
  # Para la mutación, la regla busca la palabra mutation. "no mutation" o "without mutation"
  # describen la ausencia del operador, así que se borran antes de buscar la palabra.
  if (str_detect(str_remove_all(x, regex("\\bno mutations?\\b|without mutations?", ignore_case = TRUE)),
                 regex("mutation", ignore_case = TRUE))) out <- c(out, "mutation")
  # Esta regla detecta el uso de árboles o redes de consenso dentro del método.
  if (str_detect(x, regex("consensus", ignore_case = TRUE))) out <- c(out, "consensus")
  # Esta regla detecta un árbol inicial construido con NJ, BIONJ o UPGMA. Distingue
  # mayúsculas para tomar NJ solo como sigla, y "neighbou?r" acepta neighbor y neighbour
  # (la u es opcional).
  if (str_detect(x, regex("\\bNJ\\b|BIONJ|UPGMA|neighbou?r-joining", ignore_case = FALSE))) out <- c(out, "nj_init")
  # Los demás movimientos y mecanismos de búsqueda (búsqueda local, feromonas, velocidad,
  # perturbación, ratchet, recocido, saltos, luciérnagas, abejas, intercambios, inserciones,
  # repesado de caracteres y cualquier "move") van al código other.
  if (str_detect(x, regex("local search|pheromone|velocity|perturbation|ratchet|annealing|leaping|firefly|bee|swap|insertion|reweighting|move", ignore_case = TRUE))) out <- c(out, "other")
  unique(out)  # deja cada código una sola vez
}
# map_alg() traduce la columna algorithm a familias algorítmicas (alg). Usa dos listas de
# expresiones regulares por código: las siglas (acr), que se buscan con sus mayúsculas exactas
# (NSGA, SPEA2, IBEA, MOEA/D, VNS, GRASP, ABC, SFLA, PSO, MILP, MOEA, GA), y los nombres de los
# algoritmos (wrd), que se buscan sin distinguir mayúsculas. La función devuelve los códigos de
# todos los patrones que aparecen en el texto.
map_alg <- function(x) {
  if (is.na(x) || str_detect(x, "^n\\.[ar]\\.")) return(character(0))
  # Cada patrón reúne lo siguiente (spea2, tabu y ratchet buscan su propio nombre, y sa
  # busca annealing):
  #   nsga2      NSGA-II y también NSGA-III, que no tiene código propio en el protocolo
  #   ibea       IBEA y las variantes basadas en indicadores ("indicator-based")
  #   moead      MOEA/D y sus variantes
  #   memetic    algoritmos meméticos, entre ellos Hydra
  #   immune     sistemas inmunes artificiales, entre ellos aiNet
  #   vns_grasp  VNS, GRASP, búsqueda local iterada y búsqueda por vecindarios
  #   swarm      abejas (ABC, bee), luciérnagas, murciélagos (bat), ranas (frog, SFLA),
  #              partículas (PSO, MOPSO) y hormigas (ant colony)
  #   hill_climb ascenso de colinas, descenso y búsqueda local
  #   exact      programación dinámica, MILP, métodos exactos y de parámetro fijo
  #   ga_ea      algoritmos genéticos y evolutivos, MOEA, estrategias evolutivas, imperialist
  #              competitive, chemical reaction optimisation y differential evolution (el
  #              protocolo tiene además el código de, que esta función no usa)
  #   ml         aprendizaje por refuerzo y redes neuronales
  # Las siglas se buscan con sus mayúsculas exactas (acr) y los nombres de los algoritmos sin
  # distinguir mayúsculas (wrd), para que "Genetic algorithm", "Iterated local search" o
  # "Tabu search" se reconozcan igual que en minúscula. Los nombres cortos que pueden aparecer
  # dentro de otras palabras llevan límites de palabra (\\bbat\\b no coincide con
  # "perturbation", y \\bexact no coincide con "inexact").
  acr <- c(nsga2 = "NSGA", spea2 = "SPEA2", ibea = "IBEA", moead = "MOEA/D", vns_grasp = "VNS|GRASP",
           swarm = "ABC|SFLA|PSO", exact = "MILP", ga_ea = "MOEA\\b|\\bGA\\b")
  wrd <- c(ibea = "indicator-based", memetic = "memetic|hydra", sa = "annealing", tabu = "tabu",
           immune = "immune|ainet", vns_grasp = "iterated local search|neighbou?rhood search",
           swarm = "\\bbees?\\b|firefly|\\bbats?\\b|\\bfrogs?\\b|swarm|ant colony", ratchet = "ratchet",
           hill_climb = "hill climbing|descent|local search", exact = "dynamic programming|\\bexact|fixed-parameter",
           ga_ea = "genetic|evolutionary|evolution strategy|imperialist|chemical reaction|differential",
           ml = "reinforcement|neural")
  # Devuelve los códigos de todos los patrones que aparecen en el texto, sin repetir.
  unique(c(names(acr)[sapply(acr, function(p) str_detect(x, regex(p, ignore_case = FALSE)))],
           names(wrd)[sapply(wrd, function(p) str_detect(x, regex(p, ignore_case = TRUE)))]))
}
# upd reúne las filas sin marca (flag vacío) de las dos matrices, con las columnas que el
# script incorpora. La columna flag marca las filas que los verificadores juzgaron ajenas a la
# categoría (duplicados, revisiones, trabajos teóricos o de evaluación, estudios que no son
# multiobjetivo y búsquedas deterministas que no son metaheurísticas). upd omite esas filas
# completas, aunque la marca nombre a uno solo de sus estudios, y sus estudios conservan la
# codificación del cribado. La matriz SO no tiene número de objetivos, así que n_obj queda NA.
# Como cada fila agrupa los estudios de una estrategia, str_split() y unnest() dejan una fila
# por estudio, y el último filtro descarta los estudios excluidos en el paso 1.
# Una marca que solo nombra duplicados ya eliminados por drop_ids() no invalida la fila: sus
# demás estudios reciben los códigos verificados (caso de la fila de omni-aiNet, marcada por
# el duplicado R04110).
solo_dup <- function(flag) sapply(str_extract_all(flag, "R[0-9]{5}(?=:)"), function(v) length(v) > 0 && all(v %in% dupm$id_drop))
mo_m$flag[!is.na(mo_m$flag) & solo_dup(mo_m$flag)] <- NA
so_m$flag[!is.na(so_m$flag) & solo_dup(so_m$flag)] <- NA
upd <- bind_rows(
  mo_m %>% filter(is.na(flag)) %>% transmute(ids, algorithm, criteria, main_operators, ds_diversity, n_obj = as.character(n_obj)),
  so_m %>% filter(is.na(flag)) %>% transmute(ids, algorithm, criteria, main_operators, ds_diversity, n_obj = NA_character_)) %>%
  mutate(id = str_split(ids, ";")) %>% unnest(id) %>% filter(id %in% inc$id)
# union_codes() suma los códigos verificados (new) a los del cribado (old) sin borrar
# ninguno. La verificación solo agrega información, porque un código que el cribado tomó del
# resumen sigue valiendo y el texto completo puede sumar otros. Si después de unirlos queda
# más de un código, la función quita "none" y "unclear", que solo tienen sentido cuando no
# hay otro.
union_codes <- function(old, new) {
  v <- setdiff(unique(c(str_split(old, ";")[[1]], new)), "")
  if (length(v) > 1) v <- setdiff(v, c("none", "unclear"))
  paste(v, collapse = ";")
}
# log_upd guarda, para cada estudio actualizado, sus códigos antes y después del cambio.
log_upd <- list()
# El bucle recorre los estudios de upd y actualiza su fila en inc. Suma los criterios, los
# algoritmos y los operadores con union_codes(), y en cambio reemplaza la diversidad en el
# espacio de decisión (dsd) y el número de objetivos (nobj), porque son un solo valor y el
# verificado prima sobre el que salió del resumen.
for (k in seq_len(nrow(upd))) {
  i <- which(inc$id == upd$id[k]); before <- inc[i, c("crit", "alg", "ops", "dsd", "nobj")]
  inc$crit[i] <- union_codes(inc$crit[i], map_crit(upd$criteria[k]))
  inc$alg[i]  <- union_codes(inc$alg[i], map_alg(upd$algorithm[k]))
  inc$ops[i]  <- union_codes(inc$ops[i], map_ops(upd$main_operators[k]))
  # dsd solo cambia si la matriz dice YES o NO; con "n.r." o "n.a." queda el valor del cribado.
  if (upd$ds_diversity[k] %in% c("YES", "NO")) inc$dsd[i] <- tolower(upd$ds_diversity[k])
  # nobj solo cambia si la matriz da un entero ("^[0-9]+$" exige que la celda tenga solo
  # dígitos, así que "2 (up to 6 explored)" o "n.r." no cuentan). Como en el protocolo, el
  # código "many" representa más de tres objetivos.
  if (!is.na(upd$n_obj[k]) && str_detect(upd$n_obj[k], "^[0-9]+$"))
    inc$nobj[i] <- ifelse(as.integer(upd$n_obj[k]) > 3, "many", upd$n_obj[k])
  # Cada estudio deja una fila en el registro, con el valor anterior y el nuevo de cada campo.
  log_upd[[k]] <- tibble(id = inc$id[i], crit_before = before$crit, crit_after = inc$crit[i], alg_before = before$alg,
                         alg_after = inc$alg[i], ops_before = before$ops, ops_after = inc$ops[i], dsd_before = before$dsd,
                         dsd_after = inc$dsd[i], nobj_before = before$nobj, nobj_after = inc$nobj[i])
}
log_upd <- bind_rows(log_upd)
# El registro queda en data/processed/verification_log.csv para revisar cada cambio.
write_csv(log_upd, "data/processed/verification_log.csv")
# Informa cuántos estudios recibieron códigos verificados y en cuántas filas del registro
# cambió algo. Las columnas 2, 4, 6, 8 y 10 son los valores anteriores y las 3, 5, 7, 9 y 11
# los nuevos, y apply() marca las filas con alguna diferencia.
cat("Estudios con códigos verificados:", n_distinct(log_upd$id), " con algún cambio:",
    sum(apply(log_upd[, c(2, 4, 6, 8, 10)] != log_upd[, c(3, 5, 7, 9, 11)], 1, any)), "\n")

# ---- 3. Columnas binarias, bloque principal y etiqueta ---------------------------
# expand_codes() convierte una columna de códigos separados por ";" en una columna 0/1 por
# código, con el nombre prefijo + código (por ejemplo, crit_parsimony vale 1 si el estudio
# usa parsimonia). "", "none", "unclear" y "na" no generan columna porque indican ausencia o
# falta de información, no un rasgo.
expand_codes <- function(d, field, prefix, drop = c("", "none", "unclear", "na")) {
  # codes reúne los códigos presentes en la columna, ordenados y sin los de drop.
  codes <- setdiff(sort(unique(unlist(str_split(d[[field]], ";")))), drop)
  # El bucle crea una columna 0/1 por código, con 1 cuando el código está en la lista del
  # estudio.
  for (cd in codes) d[[paste0(prefix, cd)]] <- as.integer(sapply(str_split(d[[field]], ";"), function(v) cd %in% v))
  d
}
# Las columnas binarias son los caracteres del árbol de la literatura (06_literature_tree.R)
# y la base del perfil de caracteres de 07_synthesis.R. Además, el script crea cuatro
# indicadores: obj_mo (dos o más objetivos), obj_many (tres o más), dsd_yes (la selección usa
# diversidad en el espacio de decisión) y soft_yes (el resumen informa software disponible).
inc <- inc %>%
  expand_codes("cat", "cat_") %>% expand_codes("crit", "crit_") %>% expand_codes("alg", "alg_") %>%
  expand_codes("rep", "rep_") %>% expand_codes("ops", "ops_") %>% expand_codes("data", "data_") %>%
  expand_codes("type", "type_") %>%
  mutate(obj_mo = as.integer(nobj %in% c("2", "3", "many")), obj_many = as.integer(nobj %in% c("3", "many")),
         dsd_yes = as.integer(dsd == "yes"), soft_yes = as.integer(soft == "yes"))
# Un estudio puede tener varias categorías, y su bloque principal es la primera que aparece
# en la lista de prioridad prio. El orden pone primero el núcleo de optimización de la
# revisión (mo y so_meta), luego los problemas específicos (redes, superárboles y árboles de
# especies, bosques de árboles, datos morfológicos y distancias) y al final la inferencia de
# árboles general (tree_other) y el cómputo paralelo (parallel). Un estudio sin ninguna
# categoría de la lista queda en tree_other.
prio <- c("mo", "so_meta", "network", "supertree", "forest_analysis", "morpho", "distance", "tree_other", "parallel")
inc$main_block <- sapply(str_split(inc$cat, ";"), function(v) { p <- prio[prio %in% v]; if (length(p)) p[1] else "tree_other" })
# parallel no es un bloque de las figuras, porque el protocolo lo define como un rasgo de
# implementación (HPC, GPU o cómputo distribuido), así que los estudios que solo tienen esa
# categoría pasan a tree_other.
inc$main_block[inc$main_block == "parallel"] <- "tree_other"

# first_author() saca el apellido del primer autor de la columna authors, que viene en dos
# formatos: "Apellido, I; ..." en WoS y "Apellido I.; ..." en Scopus. Sin autores, usa "Anon".
first_author <- function(a) {
  # Corta en el primer ";" o "," y se queda con la primera pieza.
  x <- str_split_fixed(coalesce(a, "Anon"), "[;,]", 2)[, 1]
  # Borra solo las iniciales del final (formato de Scopus: "van Iersel L.", "Richer J.-M.",
  # "Kosakovsky Pond S.L."), con o sin punto, y las que a veces quedan al comienzo ("S. Swenson
  # M."), de modo que el apellido conserva sus partículas y sus dos palabras.
  ini <- "(?:[A-Z]\\.?|[A-Z][a-z]\\.)"
  x <- str_trim(str_replace(x, paste0("(?:\\s+", ini, "(?:\\s*-?\\s*", ini, ")*)+$"), ""))
  x <- str_trim(str_replace(x, "^(?:[A-Z]\\.\\s*)+(?=[A-Z][a-z])", ""))
  # Pasa los acentos a ASCII (iconv con TRANSLIT) y deja solo letras, espacios y guiones.
  # Según el sistema, la transliteración puede dejar signos como ' o ^, y la expresión
  # "[^A-Za-z -]" los borra; str_squish() deja un solo espacio entre palabras.
  str_squish(str_replace_all(iconv(x, to = "ASCII//TRANSLIT"), "[^A-Za-z -]", ""))
}
inc$first_author <- first_author(inc$authors)
# Etiqueta de cada estudio (hoja del árbol): apellido del primer autor y año. Los
# estudios con el mismo primer autor y el mismo año se distinguen con letras (a, b,
# c...) en el orden de su identificador, como en las citas autor-año.
inc$label <- paste0(inc$first_author, "_", inc$year)
# Limpia la etiqueta para el formato Newick: cambia por "_" todo carácter que no sea letra,
# dígito, "_", "+", "." o "-" (los espacios, paréntesis, comas, dos puntos y corchetes tienen
# significado en Newick), junta los "_" repetidos y borra un "_" final.
inc$label <- str_replace_all(inc$label, "[^A-Za-z0-9_+.-]", "_") %>% str_replace_all("_+", "_") %>% str_replace("_$", "")
# Para desempatar, el script ordena por identificador, agrupa por etiqueta sin distinguir
# mayúsculas (las bases escriben "van Iersel" y "Van Iersel" para el mismo autor) y agrega a,
# b, c... cuando la etiqueta se repite; cada estudio conserva la grafía de su registro.
# stopifnot() confirma que todas quedan distintas, porque cada hoja del árbol necesita un
# nombre único.
inc <- inc %>% arrange(id) %>% group_by(grupo = tolower(label)) %>%
  mutate(label = if (n() > 1) paste0(label, letters[seq_len(n())]) else label) %>% ungroup() %>% select(-grupo)
stopifnot(!anyDuplicated(inc$label))

# ---- Salidas --------------------------------------------------------------------
# Sobrescribe db_final_all.csv con las etapas actualizadas. Como el script asigna la etapa
# por identificador, correrlo de nuevo da el mismo resultado. db_included_coded.csv es la
# base que leen 06_literature_tree.R, 06_literature_tree_figure.R, 07_synthesis.R,
# 08_tables.R y 10_bib.R. Al final, el script informa el número de incluidos y cuántos
# estudios tiene cada bloque principal.
write_csv(allr, "data/processed/db_final_all.csv")
write_csv(inc, "data/processed/db_included_coded.csv")
cat("Incluidos tras la verificación:", nrow(inc), "\n")
print(sort(table(inc$main_block), decreasing = TRUE))
