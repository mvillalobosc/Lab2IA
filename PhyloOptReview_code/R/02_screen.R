# =============================================================================
# 02_screen.R
# Filtros automáticos y preparación del cribado asistido. (1) Excluye los registros
# sin resumen, sin términos filogenéticos en título, resumen o palabras clave, y los
# tipos de documento no válidos. (2) Calcula la decisión de un diccionario de
# descriptores computacionales, que no excluye registros: solo se usa como referencia
# de concordancia con el cribado asistido (03_merge_coding.R) y para ordenar el
# trabajo en dos rondas. (3) Escribe los lotes de 250 registros del cribado asistido:
# primera ronda, registros con descriptores computacionales (batch_01 a batch_17);
# segunda ronda, todos los demás registros en el alcance (batch_18 en adelante).
#
# Entrada: el script lee data/processed/db_unique.csv, que escribe 01_merge.R.
# Salidas: escribe data/processed/db_screened.csv, con todas las marcas, puntajes y rasgos que
# calcula; data/processed/candidates_for_llm.csv y data/processed/candidates_round2.csv, con los
# registros de cada ronda, que leen 03_merge_coding.R y 04_verify_sample.R; y los lotes de texto
# screening/input/batch_XX.txt que recibió el cribado asistido.
# Las búsquedas de términos usan expresiones regulares sobre el texto en minúsculas: "|" separa
# alternativas, "\\b" marca el borde de una palabra y una raíz incompleta toma todas sus
# terminaciones ("phylogen" toma phylogeny, phylogenetic y phylogenomics).
# =============================================================================
# El script fija la configuración regional C.UTF-8 para manejar el texto como UTF-8 y para que el
# orden alfabético sea el mismo en cualquier equipo.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# Carga los paquetes sin mensajes de inicio: readr lee y escribe CSV, dplyr y tidyr transforman
# las tablas y stringr busca los patrones en el texto.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr); library(tidyr) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/02_screen.R
# ---- Lectura y funciones de búsqueda -----------------------------------------
# Lee la base unificada. guess_max = 10000 hace que readr revise 10000 filas, casi toda la base,
# antes de decidir el tipo de cada columna.
db <- read_csv("data/processed/db_unique.csv", show_col_types = FALSE, guess_max = 10000)

# txt() junta en un solo texto en minúsculas el título, el resumen y las palabras clave de autor y
# de indexación de cada registro. coalesce() cambia los campos ausentes por "", porque paste()
# escribiría la palabra "NA" en el texto.
txt <- function(d) str_to_lower(paste(coalesce(d$title, ""), coalesce(d$abstract, ""),
                                      coalesce(d$kw_author, ""), coalesce(d$kw_index, "")))
db$text <- txt(db)  # texto de búsqueda de cada registro
db$title_l <- str_to_lower(coalesce(db$title, ""))  # solo el título, para los filtros del título

# has() devuelve TRUE en los registros cuyo texto contiene el patrón, sin distinguir mayúsculas
# (eso importa al buscar en doctype, que no está en minúsculas).
has <- function(x, pat) str_detect(x, regex(pat, ignore_case = TRUE))
# cnt() cuenta cuántos patrones de una lista aparecen en cada registro. Un patrón suma a lo
# más 1 aunque aparezca varias veces: sapply() arma una matriz lógica de registros por
# patrones y rowSums() suma cada fila.
cnt <- function(x, pats) rowSums(sapply(pats, function(p) has(x, p)))

# ---- 1. Alcance filogenético -------------------------------------------------
# Un registro está en el alcance si menciona al menos uno de estos términos en el título, el
# resumen o las palabras clave. El filtro es amplio a propósito, porque solo debe descartar los
# registros que no nombran ningún concepto filogenético; el cribado asistido decide el resto. Las
# raíces cubren variantes: "supermatri" toma supermatrix y supermatrices, "reticulat" toma
# reticulate y reticulation, y "cladistic" toma cladistics.
scope_pat <- "phylogen|gene tree|species tree|supertree|super-tree|supermatri|evolutionary tree|tree of life|cladogram|cladistic|phylogram|phylogeny|reticulat|coalescent"
db$f_scope <- has(db$text, scope_pat)  # TRUE si el registro está en el alcance

# ---- 2. Aporte computacional -------------------------------------------------
# method_terms tiene 21 grupos de señales de aporte computacional. Cada elemento del vector es un
# grupo, con sus alternativas separadas por "|", y method_score cuenta cuántos grupos aparecen en
# el texto (de 0 a 21). Algunos grupos se solapan: un texto con "metaheuristic" suma en
# "heuristic" y en "metaheuristic", y "genetic algorithm" también suma en "\\balgorithm". Por eso
# el puntaje mide cuántas señales hay y no cuántos temas distintos.
method_terms <- c(
  # Los seis primeros grupos buscan algoritmos, heurísticas, software e implementación.
  # "\\balgorithm" exige que "algorithm" empiece una palabra, y "\\bpackage\\b" pide la palabra
  # "package" completa, así que no toma "packages".
  "\\balgorithm", "heuristic", "metaheuristic", "software", "implement", "\\bpackage\\b",
  # El primero de estos dos grupos busca servidores web y el segundo, complejidad computacional y
  # escalabilidad ("scalab" toma scalable y scalability).
  "web server|webserver|web-based tool", "computational complexity|np-hard|np-complete|np hard|polynomial time|fixed-parameter|running time|run time|runtime|scalab",
  # Este grupo busca problemas de optimización y estrategias de búsqueda; "optimi[sz]ation" acepta
  # la grafía británica y la estadounidense.
  "optimi[sz]ation problem|objective function|search space|local search|tree search|search strateg",
  # El primer grupo busca el espacio de árboles y el segundo, métricas y distancias entre árboles.
  "tree space|treespace", "\\bmetric\\b|distance measure|dissimilarity|tree distance|topological distance",
  # Este grupo busca estudios con datos simulados ("simulation stud" toma study y studies).
  "simulation stud|simulated data|simulated alignments|simulated sequences|simulated trees",
  # "benchmark" busca comparaciones de referencia, y el grupo siguiente busca las frases con que
  # los autores presentan una propuesta.
  "benchmark", "we propose|we present|we introduce|we develop|we describe|we implement|this paper proposes|this paper presents|this paper introduces|this work proposes|this work presents|this study proposes|this study presents|is proposed|are proposed",
  # Este grupo busca métodos, enfoques, algoritmos, medidas, métricas o modelos nuevos.
  "new method|novel method|new approach|novel approach|new algorithm|novel algorithm|new measure|novel measure|new metric|novel metric|new model|novel model|new framework|new tool|new program",
  # Este grupo busca cómputo paralelo o distribuido; "mpi\\b" pide que MPI termine una palabra.
  "parallel|gpu|multi-core|multicore|mpi\\b|cloud computing|distributed computing",
  # Este grupo busca metaheurísticas y algoritmos exactos o de muestreo: ratchet de parsimonia,
  # branch and bound, programación dinámica o lineal entera, MCMC y divide y vencerás. "neighbo"
  # toma la grafía británica y la estadounidense de neighborhood, y "grasp\\b" no toma "grasping".
  "genetic algorithm|evolutionary algorithm|memetic|simulated annealing|tabu search|particle swarm|ant colony|bee colony|artificial immune|firefly|differential evolution|hill climbing|hill-climbing|ratchet|branch and bound|branch-and-bound|dynamic programming|integer linear program|integer programming|mcmc|markov chain monte carlo|variable neighbo|grasp\\b|divide-and-conquer|divide and conquer",
  # Este grupo busca optimización multiobjetivo: Pareto, NSGA, SPEA2, IBEA, MOEA e hipervolumen.
  "multi-objective|multiobjective|multi objective|bi-objective|biobjective|many-objective|pareto|nsga|spea2|ibea|moea|hypervolume",
  # Este grupo busca modelos de evolución. "\\bmodel\\b.*\\bevolution\\b" pide la palabra "model"
  # y, en cualquier punto posterior del texto, la palabra "evolution" (".*" admite cualquier texto
  # entre ambas); el grupo también toma los modelos de sustitución, Mk y de Markov.
  "\\bmodel\\b.*\\bevolution\\b|substitution model|mk model|markov model",
  # Este grupo busca programas, herramientas, flujos de trabajo, marcos y bibliotecas.
  "\\bprogram\\b|\\btool\\b|pipeline|framework|library|toolkit",
  # El último grupo busca evaluaciones de desempeño: "evaluat" toma evaluate y evaluation, y
  # "compar" toma compare, comparison y comparative.
  "accuracy|performance|evaluat|compar"
)
db$method_score <- cnt(db$text, method_terms)  # grupos presentes, de 0 a 21
# f_proposal marca una frase explícita de propuesta ("we propose", "this paper presents", "novel
# algorithm", ...). Repite las frases de dos grupos de method_terms, pero no incluye "new model"
# ni "novel model", frases que también usan los estudios biológicos para un modelo del sistema que
# estudian, y agrega "new software".
db$f_proposal <- has(db$text, "we propose|we present|we introduce|we develop|we describe|we implement|this paper proposes|this paper presents|this paper introduces|this work proposes|this work presents|this study proposes|this study presents|is proposed|are proposed|new method|novel method|new approach|novel approach|new algorithm|novel algorithm|new measure|novel measure|new metric|novel metric|new framework|new tool|new program|new software")

# ---- 3. Señales de estudio biológico o taxonómico sin aporte de método ---------
# bio_terms tiene siete grupos de señales de estudios biológicos o taxonómicos, que suelen
# aplicar métodos existentes sin proponer uno nuevo. bio_score cuenta cuántos grupos aparecen
# (de 0 a 7) y compite con method_score en la decisión. Un término amplio como "field" pesa solo
# como uno de los siete grupos.
bio_terms <- c(
  # El primer grupo busca descripciones de especies y nomenclatura; en "sp\\. nov" el punto va
  # escapado para que sea un punto literal.
  "new species|sp\\. nov|gen\\. nov|comb\\. nov|species description|taxonomic revision|revision of the genus|nomenclatur",
  # El segundo busca frases típicas de los estudios que infieren la filogenia de un taxón.
  "phylogenetic position of|phylogenetic relationships of|phylogenetic relationships among|phylogenetic relationships within|molecular phylogeny of|phylogeny of the|systematics of|phylogenetic analysis of the|phylogenetic study of",
  # El tercero busca especímenes, colecciones y muestreo en terreno.
  "specimen|holotype|museum|herbarium|field|collected from|sampled from",
  # El cuarto busca marcadores moleculares y genomas de organelos. "\\b" evita que rbcL, ITS y COI
  # coincidan dentro de otras palabras, y "\\bits\\b region" pide la frase "ITS region".
  "mitochondrial genome|mitogenome|chloroplast genome|plastome|cytochrome|\\brbcl\\b|\\bits\\b region|16s rrna|18s rrna|28s rrna|\\bcoi\\b",
  # El quinto busca términos de clados (monofilia, parafilia, polifilia, grupo hermano);
  # "clade\\b" toma "clade" pero no "clades".
  "monophyl|paraphyl|polyphyl|sister group|sister taxa|clade\\b",
  # El sexto busca datación y biogeografía: tiempos de divergencia, reloj
  # molecular y calibración con fósiles.
  "divergence time|molecular clock|biogeograph|fossil calibration|crown group|stem group",
  # El séptimo busca estudios clínicos y epidemiológicos: pacientes, aislados,
  # cepas, brotes y transmisión.
  "patients|clinical|isolates|strains|outbreak|epidemiolog|transmission"
)
db$bio_score <- cnt(db$text, bio_terms)  # grupos presentes, de 0 a 7

# ---- 4. Tipo de documento: revisiones, editoriales, correcciones ---------------
# f_review marca revisiones, tutoriales y perspectivas por su título o por el tipo de documento.
# El protocolo admite las revisiones de métodos, así que esta marca no excluye ni entra en la
# decisión: queda como descripción en db_screened.csv.
db$f_review  <- has(db$title_l, "review|survey|overview|tutorial|perspective|state of the art|state-of-the-art|primer|introduction to|guide to") |
                has(coalesce(db$doctype, ""), "Review")
# f_exclude_type marca los tipos de documento que no informan un estudio completo: fe de erratas,
# editoriales, cartas, notas, correcciones, retractaciones, reseñas de libros, resúmenes de
# congreso y "Conference Review", que en Scopus resume un congreso completo o sus actas. "Retract"
# toma "Retraction" y "Retracted Publication". WoS combina tipos en un mismo campo ("Article;
# Early Access"), así que basta con que el patrón aparezca en cualquier parte.
db$f_exclude_type <- has(coalesce(db$doctype, ""), "Erratum|Editorial|Letter|Note|Correction|Retract|Book Review|Meeting Abstract|Conference Review")
# f_has_abstract exige un resumen de más de 200 caracteres. El umbral deja fuera los campos
# vacíos, los textos de relleno como "[No abstract available]" de Scopus y los resúmenes
# demasiado breves para decidir.
db$f_has_abstract <- nchar(coalesce(db$abstract, "")) > 200

# ---- Decisión de inclusión -----------------------------------------------------
# Incluido si: tiene resumen, está en el alcance, no es un tipo excluido, y el aporte
# computacional domina sobre las señales biológicas o hay una frase explícita de
# propuesta de método con al menos tres señales computacionales.
# f_method aplica esa regla: (a) al menos cuatro grupos computacionales y más señales
# computacionales que biológicas, o (b) una frase de propuesta, al menos tres grupos
# computacionales y no menos señales computacionales que biológicas. La frase de propuesta permite
# bajar de cuatro a tres grupos y aceptar un empate. Los umbrales son heurísticos. f_method no
# excluye registros, porque solo sirve de referencia para medir la concordancia con el cribado
# asistido; los otros tres filtros (resumen, alcance y tipo de documento) sí excluyen.
db <- db %>% mutate(
  f_method = (method_score >= 4 & method_score > bio_score) | (f_proposal & method_score >= 3 & method_score >= bio_score),
  included = f_has_abstract & f_scope & !f_exclude_type & f_method,
  # excl_reason guarda el primer criterio que falla, en este orden. case_when() se queda con
  # la primera condición verdadera, así que un registro sin resumen y fuera del alcance
  # figura solo como "no abstract".
  excl_reason = case_when(
    !f_has_abstract ~ "no abstract",
    !f_scope ~ "out of scope",
    f_exclude_type ~ "document type",
    !f_method ~ "no computational contribution",
    TRUE ~ "included")
)

# ---- Clasificación temática de los incluidos (no excluyente) ------------------
# Estas marcas siguen las categorías temáticas del protocolo (mo, so_meta, network,
# forest_analysis, supertree, morpho, distance y parallel), y un registro puede tener
# varias. Aunque el título de la sección habla de los incluidos, el script las calcula para
# todos los registros. Ningún script posterior las usa para decidir: quedan como
# descripción en db_screened.csv.
db <- db %>% mutate(
  # c_mo marca la optimización multiobjetivo.
  c_mo       = has(text, "multi-objective|multiobjective|multi objective|bi-objective|biobjective|many-objective|pareto|nsga|spea2|ibea|moea|hypervolume"),
  # c_meta marca las metaheurísticas y la búsqueda heurística de topologías.
  c_meta     = has(text, "genetic algorithm|evolutionary algorithm|evolutionary computation|memetic|simulated annealing|tabu search|particle swarm|ant colony|bee colony|artificial immune|firefly|differential evolution|hill climbing|hill-climbing|ratchet|stochastic search|local search|tree search|variable neighbo|grasp\\b|metaheuristic|harmony search|cuckoo|bat algorithm|scatter search"),
  # c_network marca las redes filogenéticas: reticulación, hibridación, recombinación, redes de
  # splits y clases de redes (level-k, tree-child, galled).
  c_network  = has(text, "phylogenetic network|reticulat|hybridi[sz]ation network|recombination network|split network|ancestral recombination graph|network inference|hybridi[sz]ation number|level-k|level-1 network|tree-child|galled"),
  # c_forest marca el análisis de conjuntos de árboles: espacio de árboles, consenso,
  # agrupamiento, muestras posteriores y discordancia entre árboles de genes.
  c_forest   = has(text, "tree space|treespace|set of trees|sets of trees|collection of trees|collections of trees|tree sets|clustering of trees|clustering trees|tree clustering|consensus tree|consensus method|summary tree|bootstrap trees|posterior sample|posterior distribution of trees|tree distribution|multidimensional scaling|medoid|tree islands|discordance|incongruence|gene tree heterogeneity|phylogenetic forest"),
  # c_supertree marca superárboles, supermatrices y árboles de especies a partir de árboles de
  # genes, con nombres de métodos como MRP, ASTRAL, MP-EST, STAR, NJst, STEM y BUCKy. "star\\b"
  # y "stem\\b" son amplios: el primero toma "star tree" y el segundo toma "stem group" y el
  # final de "system" o "ecosystem".
  c_supertree= has(text, "supertree|super-tree|supermatri|super-matri|total evidence|taxonomic congruence|matrix representation with parsimony|\\bmrp\\b|species tree estimation|species-tree estimation|species tree inference|coalescent-based|multispecies coalescent|quartet-based|astral\\b|mp-est|star\\b|njst|stem\\b|bucky|gene tree parsimony|reconciliation"),
  # c_morpho marca los caracteres morfológicos, discretos o continuos, los modelos Mk y Mkv, los
  # fósiles y los pesos implícitos (implied weighting).
  c_morpho   = has(text, "morpholog|discrete character|mk model|mkv|lewis model|paleontolog|palaeontolog|fossil|implied weight|polytom|continuous character|phenotypic"),
  # c_distance marca las distancias entre árboles o redes: Robinson-Foulds, cuartetos, tripletes,
  # SPR, path difference, Kendall-Colijn y la geodésica BHV de Billera, Holmes y Vogtmann.
  c_distance = has(text, "robinson-foulds|robinson foulds|quartet distance|triplet distance|spr distance|path difference|path-difference|kendall-colijn|kendall colijn|nni distance|tree distance|tree metric|tree comparison|comparing trees|compare phylogenetic trees|comparison of phylogenetic trees|comparing phylogenetic trees|topological distance|tree dissimilarity|network distance|network metric|comparing networks|geodesic|bhv|billera"),
  # c_parallel marca el cómputo paralelo o distribuido. "parallel" y "distributed"
  # también aparecen fuera del cómputo ("parallel evolution", "widely
  # distributed"), así que la marca es amplia.
  c_parallel = has(text, "parallel|gpu|multi-core|multicore|mpi\\b|cloud|distributed|high-performance|high performance computing|hpc\\b")
)

# ---- Extracción de características para las matrices y el árbol ---------------
# feat define 46 rasgos binarios con los mismos grupos de códigos del protocolo: criterios de
# inferencia, familias algorítmicas, multiobjetivo, operadores, estructura de la solución, tipo de
# dato, disponibilidad del software y escala. Cada rasgo queda como una columna dict_<nombre>, con
# 1 si el texto contiene el patrón y 0 si no, y las columnas pasan a db_screened.csv y a
# db_final_all.csv. En la versión actual del repositorio, el árbol de la literatura
# (06_literature_tree.R) y las tablas no usan estas columnas: usan los códigos del cribado
# asistido, corregidos en 05_verification.R.
feat <- list(
  # criterios de inferencia
  # crit_distance reúne los métodos de distancia (Neighbor Joining en sus dos grafías, UPGMA,
  # mínimos cuadrados, evolución mínima y BIONJ), y crit_net_parsimony reúne la parsimonia en
  # redes (hardwired o softwired) y el número de reticulaciones.
  crit_parsimony  = "parsimon",
  crit_likelihood = "likelihood",
  crit_bayesian   = "bayesian|posterior|mcmc|markov chain monte carlo",
  crit_distance   = "distance-based|distance based|neighbor-joining|neighbour-joining|neighbor joining|neighbour joining|\\bupgma\\b|least squares|least-squares|minimum evolution|bionj",
  crit_coalescent = "coalescen",
  crit_quartet    = "quartet",
  crit_net_parsimony = "hardwired|softwired|hybridi[sz]ation number|minimum number of reticulations|number of reticulations|reticulation number",
  crit_pseudolik  = "pseudo-likelihood|pseudolikelihood",
  # familias algorítmicas
  # alg_hill incluye la búsqueda golosa, la adición paso a paso y la descomposición en estrella.
  # alg_ratchet toma las técnicas de búsqueda que implementa TNT (ratchet, búsqueda sectorial,
  # fusión y deriva de árboles), y alg_exact toma los métodos exactos y de parámetro fijo
  # ("fpt\\b" es fixed-parameter tractable). alg_divide toma divide y vencerás y los métodos de
  # cubrimiento de discos ("dcm\\b" es disk-covering method), y alg_vns toma la búsqueda en
  # vecindarios variables, GRASP y la búsqueda local iterada.
  alg_ga      = "genetic algorithm|evolutionary algorithm|evolutionary computation|genetic programming",
  alg_memetic = "memetic|hybrid evolutionary|hybrid genetic",
  alg_sa      = "simulated annealing",
  alg_tabu    = "tabu search",
  alg_swarm   = "particle swarm|ant colony|bee colony|firefly|cuckoo|bat algorithm|swarm",
  alg_immune  = "artificial immune|immune-inspired|immune algorithm",
  alg_de      = "differential evolution",
  alg_hill    = "hill climbing|hill-climbing|greedy|stepwise addition|star decomposition",
  alg_ratchet = "ratchet|sectorial search|tree fusing|tree drifting",
  alg_exact   = "branch and bound|branch-and-bound|dynamic programming|integer linear program|integer programming|exact algorithm|fixed-parameter|fpt\\b",
  alg_mcmc    = "mcmc|markov chain monte carlo|metropolis|gibbs",
  alg_divide  = "divide-and-conquer|divide and conquer|disk-covering|dcm\\b",
  alg_vns     = "variable neighbo|grasp\\b|iterated local search|large neighbo",
  alg_ml      = "machine learning|deep learning|neural network|reinforcement learning|transformer",
  # multiobjetivo y selección
  # mo_other toma otros algoritmos e indicadores multiobjetivo: SPEA2, IBEA, MOEA/D,
  # hipervolumen y dominancia épsilon.
  mo_pareto   = "multi-objective|multiobjective|multi objective|bi-objective|biobjective|many-objective|pareto",
  mo_nsga     = "nsga",
  mo_other    = "spea2|ibea|moea/d|moead|hypervolume|epsilon-dominance|e-dominance|indicator-based",
  # operadores y movimientos
  # Los movimientos NNI, SPR, TBR y PDG (prune-delete-graft) llevan "\\b" en sus siglas para que
  # no coincidan dentro de otras palabras. op_nj_init marca un árbol inicial, en especial uno
  # construido con NJ, BIONJ o UPGMA.
  op_nni      = "nearest neighbor interchange|nearest neighbour interchange|\\bnni\\b",
  op_spr      = "subtree pruning|subtree prune|\\bspr\\b",
  op_tbr      = "tree bisection|\\btbr\\b",
  op_pdg      = "prune-delete-graft|prune delete graft|\\bpdg\\b",
  op_crossover= "crossover|recombination operator",
  op_mutation = "mutation operator|mutation rate|mutated",
  op_consensus= "consensus",
  op_nj_init  = "neighbor-joining|neighbour-joining|neighbor joining|neighbour joining|bionj|upgma|initial tree|starting tree",
  # estructura de la solución
  # rep_split toma splits, biparticiones y sistemas de clusters. rep_network toma "network" o
  # "graph" en cualquier palabra, de modo que también coincide con "neural network" o
  # "biogeography"; es un rasgo amplio.
  rep_tree    = "tree topolog|topolog|newick|binary tree|rooted tree|unrooted tree",
  rep_matrix  = "distance matrix|distance matrices|dissimilarity matrix",
  rep_split   = "\\bsplit|bipartition|cluster system|clusters of taxa",
  rep_network = "network|graph",
  rep_quartet = "quartet|triplet",
  # datos
  # data_other marca datos que no son secuencias, genomas ni morfología: lenguas, manuscritos,
  # cultura, cáncer y células individuales.
  data_dna    = "dna|nucleotide|sequence alignment|aligned sequences|molecular sequence",
  data_protein= "protein|amino acid|amino-acid",
  data_morpho = "morpholog|discrete character|phenotypic|fossil",
  data_genome = "genome|genomic|whole-genome|phylogenomic|snp",
  data_other  = "language|linguistic|manuscript|cultural|cancer|tumor|tumour|single-cell|single cell",
  # disponibilidad y escala
  # soft_avail toma cualquier mención de disponibilidad, incluida una dirección web ("http"), y
  # large_scale toma las menciones de gran escala o de escalabilidad.
  soft_avail  = "available at|freely available|open source|open-source|github|sourceforge|bitbucket|http|r package|python package|bioconductor|cran|web server|webserver|downloaded",
  parallel    = "parallel|gpu|multi-core|multicore|mpi\\b|cloud|distributed|high-performance|high performance computing|hpc\\b",
  large_scale = "large-scale|large scale|thousands of taxa|hundreds of taxa|large data|big data|scalab"
)
# Agrega una columna dict_<nombre> por rasgo; as.integer() convierte TRUE y FALSE en 1 y 0.
for (nm in names(feat)) db[[paste0("dict_", nm)]] <- as.integer(has(db$text, feat[[nm]]))

# ---- Decisión del filtro por diccionario (primer evaluador) --------------------
# "included" es la decisión del diccionario. No es la decisión final: se usa para
# medir la concordancia con el cribado asistido (03_merge_coding.R).
# Muestra cuántos registros caen en cada motivo de exclusión y cuántos incluiría el diccionario.
print(db %>% count(excl_reason))

# ---- Selección de candidatos para el cribado asistido --------------------------
# Pasan al cribado asistido los registros con resumen, en el alcance, de un tipo
# válido y con al menos dos descriptores computacionales, o con uno solo y un
# término metodológico en el título. El resto se excluye como "sin descriptores
# computacionales". Los candidatos se escriben en lotes de 250 registros.
# tpat reúne términos metodológicos que se buscan solo en el título (title_l): algoritmos,
# métricas y distancias entre árboles, complejidad ("np-" toma NP-hard y NP-complete), consenso,
# superárboles, espacio de árboles, heurísticas, optimización, software, invariantes,
# aproximaciones, cotas ("\\bbound" toma bound, bounds y boundary), consistencia,
# identificabilidad, simulación, desempeño, redes, búsqueda y criterios de inferencia. Un título
# metodológico basta para que pase un registro con un solo descriptor en el texto.
tpat <- "algorithm|metric|distance between|distances between|complexit|np-|np hard|supertree method|consensus|tree space|treespace|reconstruction method|heuristic|optimi|computing|computation|software|program|package|\\btool\\b|framework|invariant|fixed-parameter|approximat|\\bbound|consisten|identifiab|simulat|benchmark|performance of|accuracy of|inference method|estimation method|phylogenetic network|hybridization network|hybridisation network|reticulat|tree search|search strateg|local search|evolutionary algorithm|genetic algorithm|parsimony|likelihood|bayesian|coalescent|quartet|triplet"
db$t_hit <- has(db$title_l, tpat)  # TRUE si el título contiene un término de tpat
# cand reúne los candidatos de la primera ronda, y el script informa cuántos son. arrange(id) los
# ordena por identificador para que cada lote tenga siempre los mismos registros.
# old marca los registros de los bloques Q1 a Q6, que se cribaron en las dos primeras rondas. El
# bloque Q7 se agregó después, y sus registros nuevos forman la tercera ronda (más abajo).
db$old <- str_detect(db$blocks, "Q[1-6]")
cand <- db %>% filter(old, f_has_abstract, f_scope, !f_exclude_type,
                      method_score >= 2 | (method_score == 1 & t_hit)) %>% arrange(id)
cat("Candidatos para el cribado asistido:", nrow(cand), "\n")
# out tiene lo que ve el cribado asistido: identificador, bloques, año, título, palabras clave
# de los autores y resumen recortado a 1500 caracteres. El recorte acota el largo de cada
# lote, y un resumen más largo pierde su parte final. Solo van las palabras clave de los
# autores; las de indexación las asigna la base (en WoS, las Keywords Plus salen de los
# títulos de las referencias citadas).
# Los lotes de las dos primeras rondas muestran los bloques sin Q7, tal como los vio el cribado
# asistido antes de agregar ese bloque; str_remove() quita el ";Q7" final cuando un registro
# también apareció en Q7.
out <- cand %>% transmute(id, blocks = str_remove(blocks, ";Q7$"), year, title, kw = coalesce(kw_author, ""),
                          abstract = substr(coalesce(abstract, ""), 1, 1500))
# Guarda los candidatos de la primera ronda. Los lee 03_merge_coding.R, para comprobar que cada
# candidato tenga una decisión, y 04_verify_sample.R, para sacar la muestra de confiabilidad.
write_csv(out, "data/processed/candidates_for_llm.csv")
# Crea la carpeta de los lotes si no existe; showWarnings = FALSE calla el aviso cuando ya existe.
dir.create("screening/input", recursive = TRUE, showWarnings = FALSE)
k <- ceiling(nrow(out) / 250)  # número de lotes; el último lleva el resto
# Escribe cada lote en screening/input/batch_XX.txt, con el número en dos dígitos. Cada agente del
# cribado leyó un lote completo de 250 registros y escribió todas sus decisiones de una vez
# (screening/protocol/agent_instructions.txt).
for (i in seq_len(k)) {
  # sub toma las filas del lote i, desde (i - 1) * 250 + 1 hasta i * 250, o
  # hasta el final en el último lote.
  sub <- out[((i - 1) * 250 + 1):min(i * 250, nrow(out)), ]
  # Abre el archivo en UTF-8 para conservar los caracteres no ASCII de títulos y resúmenes.
  con <- file(sprintf("screening/input/batch_%02d.txt", i), open = "w", encoding = "UTF-8")
  for (j in seq_len(nrow(sub))) {
    # Cada registro lleva un encabezado "### id | blocks=... | year=..." y las líneas TITLE,
    # KEYWORDS y ABSTRACT, que es el formato que describe screening/protocol/llm_prompt.txt. El
    # "\n" final y el salto que agrega writeLines() dejan una línea en blanco entre registros.
    writeLines(sprintf("### %s | blocks=%s | year=%s\nTITLE: %s\nKEYWORDS: %s\nABSTRACT: %s\n",
                       sub$id[j], sub$blocks[j], sub$year[j], sub$title[j], sub$kw[j], sub$abstract[j]), con)
  }
  close(con)  # cierra el archivo y deja el lote escrito en disco
}

# ---- Segunda ronda del cribado asistido -----------------------------------------
# El filtro por diccionario solo ordena el trabajo: los registros en el alcance, con
# resumen y de un tipo válido que no pasaron a la primera ronda también se criban con
# el mismo protocolo, en lotes de 250 que siguen la numeración (batch_18 en adelante).
# Así ningún registro queda excluido solo por la falta de descriptores computacionales.
# cand2 toma los registros en el alcance, con resumen y de un tipo válido que no están en cand.
cand2 <- db %>% filter(old, f_has_abstract, f_scope, !f_exclude_type, !(id %in% cand$id)) %>% arrange(id)
cat("Candidatos de la segunda ronda:", nrow(cand2), "\n")
# La segunda ronda usa el mismo formato y el mismo recorte que la primera.
out2 <- cand2 %>% transmute(id, blocks = str_remove(blocks, ";Q7$"), year, title, kw = coalesce(kw_author, ""),
                            abstract = substr(coalesce(abstract, ""), 1, 1500))
# Guarda los candidatos de la segunda ronda, que leen 03_merge_coding.R y 04_verify_sample.R.
write_csv(out2, "data/processed/candidates_round2.csv")
# k2 es el número de lotes de la segunda ronda. El bucle siguiente repite el de la primera ronda y
# solo cambia la numeración de los archivos.
k2 <- ceiling(nrow(out2) / 250)
for (i in seq_len(k2)) {
  sub <- out2[((i - 1) * 250 + 1):min(i * 250, nrow(out2)), ]
  # k + i sigue la numeración de los lotes de la primera ronda (batch_18 en adelante).
  con <- file(sprintf("screening/input/batch_%02d.txt", k + i), open = "w", encoding = "UTF-8")
  for (j in seq_len(nrow(sub))) {
    writeLines(sprintf("### %s | blocks=%s | year=%s\nTITLE: %s\nKEYWORDS: %s\nABSTRACT: %s\n",
                       sub$id[j], sub$blocks[j], sub$year[j], sub$title[j], sub$kw[j], sub$abstract[j]), con)
  }
  close(con)
}
# ---- Tercera ronda: bloque Q7 ----------------------------------------------------
# Los registros que solo aparecieron en el bloque Q7 (métodos libres de alineamiento y de orden
# génico) se criban con el mismo protocolo. Como la segunda ronda ya mostró que el filtro por
# diccionario deja fuera estudios pertinentes, esta ronda toma todos los registros en el alcance,
# con resumen y de un tipo válido, sin separarlos por descriptores. Sus lotes siguen la numeración
# (batch_31 en adelante) y no cambian los lotes de las dos primeras rondas.
cand3 <- db %>% filter(!old, f_has_abstract, f_scope, !f_exclude_type) %>% arrange(wave, id)
cat("Candidatos de la tercera ronda:", nrow(cand3), "\n")
out3 <- cand3 %>% transmute(id, blocks, year, title, kw = coalesce(kw_author, ""),
                            abstract = substr(coalesce(abstract, ""), 1, 1500))
write_csv(out3 %>% mutate(wave = cand3$wave), "data/processed/candidates_round3.csv")
# Los lotes se arman por ola de descarga (ver 01_merge.R): los registros de la ola 2 llenan los
# lotes 31 a 34 y los de la ola 3, que llegaron después, los lotes siguientes. Así los lotes ya
# cribados no cambian. bnum guarda el número de lote de cada registro de la tercera ronda.
bnum <- integer(0); nxt <- k + k2
for (w in sort(unique(cand3$wave))) {
  n_w <- sum(cand3$wave == w)
  bnum <- c(bnum, nxt + ceiling(seq_len(n_w) / 250))
  nxt <- max(bnum)
}
out3$batch <- bnum
for (bb in unique(out3$batch)) {
  sub <- out3[out3$batch == bb, ]
  con <- file(sprintf("screening/input/batch_%02d.txt", bb), open = "w", encoding = "UTF-8")
  for (j in seq_len(nrow(sub))) {
    writeLines(sprintf("### %s | blocks=%s | year=%s\nTITLE: %s\nKEYWORDS: %s\nABSTRACT: %s\n",
                       sub$id[j], sub$blocks[j], sub$year[j], sub$title[j], sub$kw[j], sub$abstract[j]), con)
  }
  close(con)
}

# ---- Base filtrada -----------------------------------------------------------
# Guarda la base completa con todas las marcas, puntajes y rasgos de este script, sin las columnas
# auxiliares de texto (text y title_l). Es la entrada de 03_merge_coding.R.
write_csv(db %>% select(-text, -title_l, -old), "data/processed/db_screened.csv")
