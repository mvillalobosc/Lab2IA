# =============================================================================
# 06_literature_tree.R
# Árbol de la literatura. Cada estudio incluido es una hoja y sus caracteres son
# los códigos binarios del cribado, corregidos en la verificación del núcleo de
# optimización (05_verification.R): bloque temático, tipo de aporte, criterios,
# familias algorítmicas, estructuras de solución, operadores, tipo de dato,
# número de objetivos, uso del espacio de decisión y disponibilidad de software.
# La distancia entre estudios es la de Jaccard, adecuada para caracteres binarios
# asimétricos (la ausencia compartida de un carácter no suma similitud), y el
# árbol se infiere con Neighbour Joining (ape::nj) y se enraíza en el punto medio. El árbol
# ordena la literatura y no estima una filogenia, así que no lleva valores de soporte. Cada
# nodo interno se rotula con hasta tres caracteres que distinguen al clado del resto del
# árbol. Salidas: Newick (.nwk), JSON con el formato phyli versión 2, la tabla de clados
# destacados, la tabla de nodos internos y tree.rds, que usan 06_literature_tree_figure.R para
# dibujar la figura y 08_tables.R para armar la tabla de clados del artículo. La entrada es
# data/processed/db_included_coded.csv, que escribe 05_verification.R, y todas las salidas
# quedan en results/tree/.
# =============================================================================
# La configuración regional C.UTF-8 fija el orden alfabético (por código de carácter) y la
# lectura de los acentos, para que el resultado no dependa del idioma del sistema.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr, dplyr y stringr leen y manipulan la base; ape y phangorn construyen y recorren el árbol
# (nj, midpoint, ladderize, prop.part), y jsonlite escribe el JSON.
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(stringr); library(ape); library(phangorn)
  library(jsonlite)
})
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/06_literature_tree.R
# Crea la carpeta de salidas si no existe.
dir.create("results/tree", recursive = TRUE, showWarnings = FALSE)

# inc tiene una fila por estudio incluido, con sus códigos binarios (0/1), el bloque principal
# (main_block) y la etiqueta autor_año (label) que construye 05_verification.R.
inc <- read_csv("data/processed/db_included_coded.csv", show_col_types = FALSE, guess_max = 10000)

# ---- Matriz de caracteres -------------------------------------------------------
# Se excluyen los códigos "other": compartir "otro" no implica compartir lo mismo.
# char_cols reúne las columnas binarias de categoría temática (cat_), tipo de aporte (type_),
# criterio (crit_), familia algorítmica (alg_), estructura de solución (rep_), operador (ops_) y
# tipo de dato (data_). El patrón "_other$" también deja fuera cat_tree_other ("otra inferencia
# de árboles"), la categoría que reúne la inferencia de árboles que no es multiobjetivo ni de
# búsqueda heurística (algoritmos exactos, estimadores de verosimilitud o bayesianos, métodos de
# distancia, aprendizaje automático); por eso su nombre en `nice` no se usa en este script.
char_cols <- names(inc)[str_detect(names(inc), "^(cat|type|crit|alg|rep|ops|data)_") &
                          !str_detect(names(inc), "_other$")]
# Se suman tres caracteres que construye 05_verification.R: dos o más objetivos (obj_mo), tres
# o más objetivos (obj_many) y software disponible (soft_yes). La diversidad en el espacio de
# decisión (dsd_yes) no entra, porque la revisión no analiza ese aspecto. El número de objetivos queda en forma acumulativa, de modo que un estudio con tres
# objetivos tiene obj_mo y obj_many y comparte obj_mo con los estudios de dos objetivos.
char_cols <- c(char_cols, "obj_mo", "obj_many", "soft_yes")
# X es la matriz estudios x caracteres (0/1), con la etiqueta de cada estudio como nombre de fila.
# Un código faltante (NA) cuenta como ausencia, y los caracteres que ningún estudio tiene se
# eliminan porque no cambian ninguna distancia.
X <- as.matrix(inc[, char_cols]); X[is.na(X)] <- 0
rownames(X) <- inc$label
X <- X[, colSums(X) > 0]
cat("Estudios:", nrow(X), " caracteres:", ncol(X), "\n")

# nice da a cada carácter un nombre corto en inglés, que aparece en los rótulos de los nodos
# (Newick y JSON) y en las tablas CSV de este script. 08_tables.R tiene una copia de esta lista y
# la usa para volver de los nombres a los códigos, así que un cambio aquí debe repetirse allá.
nice <- c(
  cat_mo = "MultiObjective", cat_so_meta = "Metaheuristic", cat_tree_other = "TreeInference",
  cat_network = "Network", cat_forest_analysis = "ForestAnalysis", cat_supertree = "Supertree",
  cat_morpho = "Morphology", cat_distance = "TreeDistance", cat_parallel = "Parallel",
  type_method = "Method", type_evaluation = "Evaluation", type_theory = "Theory",
  type_metric = "Metric", type_review = "Review",
  crit_parsimony = "Parsimony", crit_likelihood = "Likelihood", crit_bayesian = "Bayesian",
  crit_distance = "DistanceCriterion", crit_coalescent = "Coalescent", crit_quartet = "Quartet",
  crit_net_parsimony = "NetworkParsimony", crit_pseudolikelihood = "PseudoLikelihood",
  alg_ga_ea = "GA", alg_memetic = "Memetic", alg_sa = "SimulatedAnnealing", alg_tabu = "TabuSearch",
  alg_swarm = "Swarm", alg_immune = "Immune", alg_de = "DifferentialEvolution",
  alg_hill_climb = "HillClimbing", alg_ratchet = "Ratchet", alg_exact = "Exact", alg_mcmc = "MCMC",
  alg_divide_conquer = "DivideConquer", alg_vns_grasp = "VNS_GRASP", alg_ml = "MachineLearning",
  alg_nsga2 = "NSGA-II", alg_spea2 = "SPEA2", alg_ibea = "IBEA", alg_moead = "MOEA-D",
  rep_tree = "TreeStructure", rep_matrix = "MatrixStructure", rep_split = "Splits",
  rep_cluster = "Clusters", rep_network = "NetworkStructure", rep_quartet = "Quartets",
  ops_nni = "NNI", ops_spr = "SPR", ops_tbr = "TBR", ops_pdg = "PDG", ops_crossover = "Crossover",
  ops_mutation = "Mutation", ops_consensus = "Consensus", ops_nj_init = "NJinit",
  data_dna = "DNA", data_protein = "Protein", data_morphological = "MorphologicalData",
  data_genomic = "Genomic", data_gene_trees = "GeneTrees", data_distances = "Distances",
  obj_mo = "TwoOrMoreObjectives", obj_many = "ThreeOrMoreObjectives",
  soft_yes = "SoftwareAvailable")
# nm() traduce un vector de códigos a sus nombres cortos y deja igual los que no están en nice.
nm <- function(v) ifelse(v %in% names(nice), nice[v], v)

# ---- Distancia de Jaccard ------------------------------------------------------
# jaccard() calcula la distancia de Jaccard entre las filas de una matriz binaria (estudios x
# caracteres), d = 1 - (caracteres compartidos) / (caracteres presentes en al menos uno de los
# dos). Solo cuentan las presencias, y eso importa aquí porque cada estudio tiene pocos de los
# caracteres posibles: con un índice que sumara las ausencias compartidas, casi todos los pares
# de estudios parecerían muy similares.
jaccard <- function(M) {
  M <- M * 1  # asegura una matriz numérica
  inter <- tcrossprod(M)  # cuenta los caracteres que comparten i y j (M %*% t(M))
  s <- rowSums(M)  # cuenta los caracteres de cada estudio
  uni <- outer(s, s, "+") - inter  # cuenta los caracteres presentes en i o en j
  D <- 1 - inter / pmax(uni, 1)  # pmax evita dividir por cero
  # Si dos estudios no tienen ningún carácter (uni = 0), quedan a distancia 0 entre sí; un estudio
  # sin caracteres queda a distancia 1 del resto.
  D[uni == 0] <- 0
  diag(D) <- 0  # cada estudio queda a distancia 0 de sí mismo
  D
}
D <- jaccard(X)  # calcula las distancias entre todos los estudios

# ---- Neighbour Joining, raíz en el punto medio --------------------------------
# Neighbour Joining (Saitou y Nei, 1987) une en cada paso el par de nodos que minimiza la
# longitud total estimada del árbol. Trabaja directo sobre la matriz de distancias y es lo
# bastante rápido para miles de hojas; nj() devuelve un árbol sin raíz.
t0 <- Sys.time()  # marca el inicio para informar cuánto tarda NJ
tr <- nj(as.dist(D))  # as.dist pasa la matriz al formato dist que pide nj
cat("NJ:", format(Sys.time() - t0), "\n")
tr$edge.length[tr$edge.length < 0] <- 0  # NJ puede estimar ramas negativas, que se llevan a 0
# Los estudios no tienen un grupo externo que sirva para enraizar, así que la raíz va en el punto
# medio del camino más largo entre dos hojas (phangorn::midpoint).
tr <- midpoint(tr)
tr <- ladderize(tr)  # ordena los hijos por tamaño de clado sin cambiar la topología

# ---- Rótulos de nodos internos: caracteres compartidos --------------------------
ntip <- Ntip(tr); nint <- tr$Nnode  # cuenta las hojas y los nodos internos
desc <- prop.part(tr)                      # hojas bajo cada nodo interno (orden ntip+1, ...)
glob_freq <- colMeans(X)  # calcula la frecuencia de cada carácter en todo el corpus
block <- setNames(inc$main_block, inc$label)  # asocia cada estudio con su bloque principal
# Bloques ordenados de mayor a menor número de estudios (orden de leyendas y clados)
# block_nice da el nombre largo en inglés de cada bloque y block_n cuenta sus estudios.
block_nice <- c(network = "Phylogenetic networks", supertree = "Supertrees and species trees",
                tree_other = "Other tree inference", forest_analysis = "Forest analysis and consensus",
                so_meta = "Single-objective heuristic search", morpho = "Morphological data",
                distance = "Tree and network distances", mo = "Multi-objective optimisation")
block_n <- table(factor(inc$main_block, levels = names(block_nice)))
block_nice <- block_nice[order(-block_n[names(block_nice)])]
# Rótulo de cada nodo: caracteres que distinguen al clado del resto del árbol,
# es decir, presentes en al menos el 60 % de sus estudios y al menos 1,5 veces
# más frecuentes dentro que fuera, ordenados por la diferencia de frecuencias.
# Si ninguno cumple, se usan los compartidos por el 90 % (del más raro al más común).
# node_info guarda, para cada nodo interno k (el nodo ntip + k), su tamaño, su rótulo, hasta
# cinco caracteres elegidos con el mismo criterio del rótulo (shared, que 08_tables.R usa en la
# tabla de clados), el bloque dominante y la pureza, que es la proporción de estudios del clado
# que pertenecen a ese bloque.
node_info <- lapply(seq_len(nint), function(k) {
  tips <- tr$tip.label[desc[[k]]]  # toma los estudios del clado
  inside <- rownames(X) %in% tips  # marca las filas de X que están en el clado
  fr_in <- colMeans(X[inside, , drop = FALSE])  # mide la frecuencia de cada carácter en el clado
  # fr_out es la frecuencia fuera del clado; la raíz no tiene estudios fuera y usa ceros.
  fr_out <- if (any(!inside)) colMeans(X[!inside, , drop = FALSE]) else rep(0, ncol(X))
  # Un carácter ausente fuera del clado cumple la segunda condición con solo estar en el 60 % de
  # los estudios del clado.
  enr <- names(fr_in)[fr_in >= 0.6 & fr_in >= 1.5 * fr_out]
  enr <- enr[order(-(fr_in[enr] - fr_out[enr]))]  # ordena de mayor a menor diferencia
  shared <- names(fr_in)[fr_in >= 0.9]
  shared <- shared[order(glob_freq[shared])]
  pick <- if (length(enr)) head(enr, 3) else head(shared, 3)  # elige hasta tres para el rótulo
  lab <- if (length(pick)) paste(nm(pick), collapse = "+") else ""  # une los nombres con "+"
  # El bloque dominante es el más frecuente entre los estudios del clado; en un empate gana el
  # primero en orden alfabético, porque table() ordena los nombres y which.max toma el primero.
  tb <- table(block[tips]); top <- names(tb)[which.max(tb)]
  purity <- max(tb) / length(tips)  # calcula la proporción del bloque dominante
  list(size = length(tips), label = lab,
       shared = paste(nm(if (length(enr)) head(enr, 5) else head(shared, 5)), collapse = ", "),
       block = top, purity = purity)
})
# node_df tiene una fila por nodo interno, en el orden ntip + 1, ntip + 2, ..., con los datos de
# node_info.
node_df <- tibble(node = ntip + seq_len(nint),
                  size = sapply(node_info, `[[`, "size"),
                  label = sapply(node_info, `[[`, "label"),
                  shared = sapply(node_info, `[[`, "shared"),
                  block = sapply(node_info, `[[`, "block"),
                  purity = sapply(node_info, `[[`, "purity"))
tr$node.label <- node_df$label  # el Newick escribe cada rótulo después del paréntesis del nodo

# ---- Escritura Newick (formato phyli) ---------------------------------------------
# write_newick_phyli() arma el texto de forma recursiva desde la raíz, con las longitudes de rama
# con cinco decimales y el rótulo de cada nodo interno después de su paréntesis, por ejemplo
# (A:0.10000,B:0.20000)Rotulo:0.05000.
write_newick_phyli <- function(phy) {
  n <- Ntip(phy); el <- phy$edge.length  # toma el número de hojas y las longitudes de rama
  kids <- split(phy$edge[, 2], phy$edge[, 1])  # agrupa los hijos de cada nodo según phy$edge
  elen <- setNames(el, phy$edge[, 2])  # asocia a cada nodo la longitud de la rama que llega a él
  rec <- function(v) {  # devuelve el Newick del subárbol que cuelga del nodo v
    if (v <= n) {  # una hoja se escribe con su etiqueta
      s <- phy$tip.label[v]
    } else {  # un nodo interno lleva sus hijos entre paréntesis y luego su rótulo
      ch <- kids[[as.character(v)]]
      s <- paste0("(", paste(sapply(ch, rec), collapse = ","), ")", phy$node.label[v - n])
    }
    if (as.character(v) %in% names(elen)) {  # todos los nodos salvo la raíz tienen rama
      s <- paste0(s, ":", formatC(elen[as.character(v)], format = "f", digits = 5))
    }
    s
  }
  paste0(rec(n + 1), ";")  # la raíz es el nodo n + 1 y el Newick termina en punto y coma
}
nwk <- write_newick_phyli(tr)
writeLines(nwk, "results/tree/literature_tree_nj.nwk")

# ---- Archivo JSON para phyli ----------------------------------------------------
# El JSON reúne el Newick y los datos que muestra phyli (versión 2 del formato): nombre del
# archivo, título, descripción en inglés y las listas view, style y show. sprintf completa la
# descripción con el número de estudios y de caracteres, y %% escribe un signo %.
json <- list(
  format = "phyli", version = 2, name = "literature_tree_nj.nwk",
  title = "Literature tree of computational phylogenetic inference",
  desc = sprintf(paste0("%d studies included in the systematic review (2005-2026). Neighbour Joining on Jaccard ",
                        "distances between %d binary characters coded from title, abstract and keywords and verified with the full ",
                        "texts for the optimisation core; midpoint root. Internal ",
                        "nodes are named after up to three characters present in at least 60%% of their studies and at least ",
                        "1.5 times more frequent than outside. Leaves: first author and year (letters distinguish studies with the ",
                        "same first author and year)."), nrow(X), ncol(X)),
  # Vista y estilo de phyli según el ejemplo de los autores: cladograma circular con
  # conectores en escalón y etiquetas de tamaño 7.
  view = list(shape = "circular-step", mode = "clado", aligned = FALSE, ladder = TRUE, angle = 360, leafGap = 8),
  style = list(pathW = 1.2, pathC = "#394049", nodeR = 0, nodeC = "#498BCA", labelS = 7, labelC = "#2C3138"),
  # show activa las guías y los rótulos internos y apaga los soportes, que este árbol no tiene;
  # retic y gamma se refieren a reticulaciones, que tampoco tiene.
  show = list(guides = TRUE, support = FALSE, internal = TRUE, retic = TRUE, gamma = TRUE),
  newick = nwk)
# auto_unbox escribe los valores de largo 1 como escalares y no como arreglos de un elemento, y
# pretty = 2 sangra el JSON con dos espacios.
writeLines(toJSON(json, auto_unbox = TRUE, pretty = 2), "results/tree/literature_tree_nj.json")

# ---- Clados destacados: maximales, con al menos 25 estudios y pureza >= 0.75 -----
# Son candidatos los nodos con al menos 25 estudios cuyo bloque dominante reúne al menos el 75 %
# de ellos.
cand_nodes <- node_df %>% filter(size >= 25, purity >= 0.75)
# anc_of() sube por la matriz de ramas desde un nodo hasta la raíz y devuelve sus ancestros.
anc_of <- function(v) { a <- c(); p <- tr$edge[tr$edge[, 2] == v, 1]; while (length(p)) { a <- c(a, p); p <- tr$edge[tr$edge[, 2] == p, 1] }; a }
# Un candidato se conserva si ninguno de sus ancestros es candidato del mismo bloque, de modo que
# de cada grupo de clados anidados del mismo bloque queda solo el más externo. Un clado anidado
# en un clado destacado de otro bloque sí se conserva.
keep <- sapply(seq_len(nrow(cand_nodes)), function(i) {
  a <- anc_of(cand_nodes$node[i])
  !any(cand_nodes$node %in% a & cand_nodes$block == cand_nodes$block[i])
})
# Los clados destacados se ordenan por bloque, de mayor a menor número de estudios (como en
# block_nice), y dentro de cada bloque de mayor a menor tamaño. clade es el número que llevan en
# la tabla del artículo y en la figura, y block_name es el nombre largo del bloque.
hl <- cand_nodes[keep, ] %>% arrange(match(block, names(block_nice)), desc(size)) %>%
  mutate(clade = seq_len(n()), block_name = block_nice[block])
# highlighted_clades.csv guarda los clados destacados e internal_nodes.csv todos los nodos
# internos, con sus rótulos, caracteres, bloque dominante y pureza.
write_csv(hl, "results/tree/highlighted_clades.csv")
write_csv(node_df, "results/tree/internal_nodes.csv")
# Muestra en la consola un resumen de los clados destacados.
print(hl %>% select(clade, block, size, purity, shared), width = 200)

# tree.rds guarda el árbol con sus rótulos, la tabla de nodos, los clados destacados y el número
# de caracteres; 06_literature_tree_figure.R y 08_tables.R lo leen.
saveRDS(list(tree = tr, node_df = node_df, hl = hl, nchar = ncol(X)), "results/tree/tree.rds")
cat("Listo\n")
