# =============================================================================
# 08_tables.R
# Tablas del manuscrito en LaTeX a partir de los datos: (1) matriz de métodos
# multiobjetivo, (2) matriz de metaheurísticas monoobjetivo, (3) heurísticas de
# búsqueda local (apéndice), (4) bloques de búsqueda (apéndice), (4b) cadenas de
# búsqueda (apéndice) y (5) clados destacados del árbol de la literatura. Las matrices condensadas de
# tables_curated/ resumen las filas de verification/ (verificación del núcleo de
# optimización) con la redacción breve que usa el artículo. Los grupos se
# ordenan de mayor a menor número de filas (empates en orden alfabético) y, dentro
# de cada grupo, por el año del primer estudio.
#
# Entradas
#   data/processed/db_included_coded.csv  estudios incluidos y sus caracteres codificados
#   data/processed/db_final_all.csv       registros únicos con etapa PRISMA y bloques
#   data/processed/counts_raw.csv         registros recuperados por bloque en cada base
#   data/raw/search_strings.csv           cadenas de búsqueda textuales, por bloque y base
#   tables_curated/{mo,so,ls}_table.csv   matrices condensadas, una fila por estrategia
#   results/tree/tree.rds                 árbol de la literatura (06_literature_tree.R)
# Salidas
#   results/latex/tab_{mo,so,ls}.tex      matrices de métodos en páginas apaisadas
#   results/latex/tab_blocks.tex          bloques de búsqueda
#   results/latex/tab_queries.tex         cadenas de búsqueda de Scopus y WoS
#   results/latex/tab_clades.tex          clados destacados del árbol de la literatura
#   results/tables/highlighted_clades_table.csv
#                                         la misma tabla de clados, en CSV
# El manuscrito debe cargar booktabs (filetes y \addlinespace), array (columnas
# >{...}p{...}), longtable y lscape o pdflscape (entorno landscape).
# =============================================================================
# El locale C.UTF-8 hace que R escriba el texto en UTF-8 y que ordene las cadenas por código
# de carácter, igual en cualquier sistema. Así el desempate alfabético de los grupos no
# cambia de una máquina a otra.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee y escribe los CSV, dplyr filtra, ordena y resume las tablas, tidyr separa
# listas en filas con unnest(), stringr trabaja el texto y ape entrega prop.part() y Ntip()
# para la tabla de clados.
# suppressPackageStartupMessages() oculta los mensajes que imprimen los paquetes al cargarse.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr); library(tidyr); library(ape) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/08_tables.R
# Crea results/latex/ si no existe; recursive = TRUE crea también results/ si hace falta.
dir.create("results/latex", recursive = TRUE, showWarnings = FALSE)
# inc tiene un estudio incluido por fila, con su identificador R#####, el año, las citas
# (cited), el rótulo de hoja del árbol (label) y los caracteres binarios (cat_, crit_,
# alg_, rep_, ops_, ...). guess_max = 10000 hace que readr revise todas las filas antes de
# decidir el tipo de cada columna, para que una columna con valores vacíos al comienzo no
# quede con un tipo equivocado.
inc <- read_csv("data/processed/db_included_coded.csv", show_col_types = FALSE, guess_max = 10000)
# allr tiene todos los registros únicos de la búsqueda, con su etapa PRISMA (stage) y los
# bloques que los recuperaron (blocks). Solo lo usa la tabla de bloques.
allr <- read_csv("data/processed/db_final_all.csv", show_col_types = FALSE, guess_max = 10000)

# ---- Funciones auxiliares -----------------------------------------------------------
# tex() prepara para LaTeX los textos libres de las matrices curadas. Antepone una barra
# invertida a &, % y _, que en LaTeX separan columnas, abren comentarios y marcan
# subíndices. También escribe el operador de cruce BLX-alpha con la letra griega en modo
# matemático y cambia el separador "; " de los CSV por ", ", que se lee mejor en la tabla.
# En el código fuente, cada barra de la salida necesita cuatro ("\\\\&"), porque R convierte
# cada par en una barra y stringr vuelve a leer esa barra como escape.
tex <- function(x) {
  x <- str_replace_all(x, "&", "\\\\&"); x <- str_replace_all(x, "%", "\\\\%"); x <- str_replace_all(x, "_", "\\\\_")
  # stringr toma el signo $ del reemplazo como texto literal (sus referencias a grupos usan
  # \\1, no $1), así que la salida queda BLX-$\alpha$.
  x <- str_replace_all(x, "BLX-alpha", "BLX-$\\\\alpha$")
  str_replace_all(x, "; ", ", ")
}
# cites() convierte los identificadores de una fila, separados por ";" (por ejemplo
# "R00694;R04033"), en un solo \cite{...}. Ordena las claves por año de publicación y, si
# el año coincide, por identificador, de modo que la lista parte por el estudio más
# antiguo de la estrategia.
cites <- function(ids) {
  v <- str_split(ids, ";")[[1]]
  # El script se detiene si alguna clave no está entre los estudios incluidos, para que la
  # tabla no cite por error un registro excluido.
  stopifnot(all(v %in% inc$id))
  # match() busca el año de cada estudio en inc, en el mismo orden de v.
  y <- inc$year[match(v, inc$id)]
  # order(y, v) ordena por año y desempata por identificador; las claves van separadas por
  # comas, sin espacios.
  sprintf("\\cite{%s}", paste(v[order(y, v)], collapse = ","))
}
# first_year() devuelve, para cada fila, el año del estudio más antiguo de su lista de
# identificadores. Sirve para ordenar las estrategias dentro de cada grupo.
first_year <- function(ids) sapply(str_split(ids, ";"), function(v) min(inc$year[match(v, inc$id)]))
# order_groups() fija el orden de las filas de una matriz. Los grupos van de más a menos
# filas y, si empatan, en orden alfabético; dentro de cada grupo, las estrategias van por
# el año de su primer estudio (fy) y, si el año coincide, por nombre.
order_groups <- function(d) {
  # table() cuenta las filas de cada grupo, y order(-n, names(n)) ordena por conteo
  # descendente y desempata por nombre.
  n <- table(d$group)
  lev <- names(n)[order(-n, names(n))]
  # El factor g guarda ese orden de grupos, y arrange() ordena las filas por g, fy y
  # strategy. landscape_table() usa después los niveles de g para escribir los subtítulos.
  d %>% mutate(fy = first_year(ids), g = factor(group, levels = lev)) %>% arrange(g, fy, strategy)
}
# landscape_table() escribe una matriz como tabla larga en página apaisada. El entorno
# longtable reparte la tabla en varias páginas y repite el encabezado en cada una, y el
# entorno landscape gira la página para ganar ancho, porque las matrices tienen hasta ocho
# columnas de texto. La función recibe los datos ya ordenados (d, con el factor g), las
# columnas que se imprimen (cols), sus encabezados en inglés (header), el ancho de cada
# columna (widths), la leyenda, la etiqueta para \ref, el archivo de salida y el tamaño de
# letra, que por defecto es \scriptsize.
landscape_table <- function(d, cols, header, widths, caption, label, file, size = "\\scriptsize") {
  # nc es el número de columnas, que necesitan los \multicolumn que cruzan toda la tabla.
  nc <- length(cols)
  # Cada columna es un párrafo de ancho fijo p{...} alineado a la izquierda. \raggedright
  # evita los espacios grandes entre palabras que deja el texto justificado en columnas
  # angostas, y \arraybackslash restaura \\ como fin de fila, porque \raggedright cambia su
  # significado. El prefijo >{...} viene del paquete array.
  spec <- paste0(">{\\raggedright\\arraybackslash}p{", widths, "}", collapse = "")
  # out empieza abriendo landscape y un grupo con el tamaño de letra, cuya llave cierra al
  # final. \tabcolsep baja a 4 pt (LaTeX usa 6 pt) para que quepan todas las columnas, y
  # \LTcapwidth deja la leyenda tan ancha como la línea, porque longtable la limita a 4
  # pulgadas si no se indica otra cosa.
  out <- c("\\begin{landscape}", paste0("{", size), "\\setlength{\\tabcolsep}{4pt}", "\\setlength{\\LTcapwidth}{\\linewidth}",
           sprintf("\\begin{longtable}{%s}", spec),
           # En longtable la leyenda va como una fila más, por eso termina en \\.
           sprintf("\\caption{%s}\\label{%s}\\\\", caption, label),
           # La primera página lleva el filete superior, los encabezados y el filete medio
           # (\endfirsthead).
           "\\toprule", paste(header, collapse = " & "), "\\\\", "\\midrule", "\\endfirsthead",
           # Las páginas siguientes avisan que la tabla continúa y repiten los encabezados
           # (\endhead).
           sprintf("\\multicolumn{%d}{l}{\\emph{Table \\ref{%s} (continued)}}\\\\", nc, label),
           "\\toprule", paste(header, collapse = " & "), "\\\\", "\\midrule", "\\endhead",
           # Cada página termina con el filete inferior (\endfoot), también la última.
           "\\bottomrule", "\\endfoot")
  # El ciclo recorre los grupos en el orden del factor g. Cada grupo abre con un subtítulo
  # en cursiva que cruza todas las columnas y sigue con sus filas en el orden que dejó
  # order_groups().
  for (g in levels(d$g)) {
    out <- c(out, sprintf("\\multicolumn{%d}{l}{\\textit{%s}}\\\\", nc, g))
    # Dentro de filter(), g sería la columna del mismo nombre; !!g inyecta el valor del
    # ciclo, de modo que la comparación es entre la columna y el grupo actual.
    s <- d %>% filter(g == !!g)
    # El ciclo interno une con " & " los valores de cols de cada fila, en ese orden, y
    # cierra la fila con \\.
    for (i in seq_len(nrow(s))) out <- c(out, paste0(paste(sapply(cols, function(cl) s[[cl]][i]), collapse = " & "), "\\\\"))
    # \addlinespace (booktabs) deja un pequeño espacio antes del grupo siguiente; después
    # del último grupo no hace falta.
    if (g != tail(levels(d$g), 1)) out <- c(out, "\\addlinespace")
  }
  # Cierra longtable, la llave del tamaño de letra y landscape, en ese orden, y escribe una
  # línea del archivo por cada elemento de out.
  out <- c(out, "\\end{longtable}", "}", "\\end{landscape}")
  writeLines(out, file)
}

# ---- (1) Matriz multiobjetivo -----------------------------------------------------
# Lee la matriz multiobjetivo con todas las columnas como texto (cols(.default = "c")),
# para que readr no cambie el tipo de valores como "2" o "n.r.". Después ordena las filas
# con order_groups(), arma la columna de referencias con cites() y pasa por tex() las
# columnas de texto libre. nobj no pasa por tex() porque solo trae números, n.r. o n.a.
mo <- read_csv("tables_curated/mo_table.csv", show_col_types = FALSE, col_types = cols(.default = "c")) %>% order_groups() %>%
  mutate(ref = sapply(ids, cites), across(c(strategy, algorithm, criteria, structure, operators), tex))
# La tabla tiene ocho columnas, con encabezados en inglés como el artículo. Los anchos
# suman 17 cm, y con el \tabcolsep de 4 pt a cada lado de cada columna la tabla mide
# unos 19,3 cm. Main operators recibe el mayor ancho (3,7 cm) porque trae los textos más
# largos, y Obj. el menor (0,6 cm) porque solo lleva un número, n.r. o n.a. Code indica si
# la verificación encontró el código fuente público de la estrategia (Yes) o no (n.f.); la
# fuente de cada Yes está en la columna code_source de tables_curated/mo_table.csv. La leyenda
# define todas las siglas que aparecen en la tabla, y Robinson--Foulds lleva doble guion
# porque LaTeX lo imprime como semirraya.
landscape_table(mo, c("strategy", "ref", "algorithm", "criteria", "nobj", "structure", "operators", "code"),
                c("Strategy", "References", "Algorithm", "Criteria", "Obj.", "Sol. structure", "Main operators", "Code"),
                c("2.6cm", "2.0cm", "2.6cm", "2.6cm", "0.6cm", "2.1cm", "3.7cm", "0.8cm"),
                paste0("Multi-objective strategies for phylogenetic inference. Obj., number of objectives; ",
                       "MP, maximum parsimony; ML, maximum likelihood; ME, minimum evolution; LS, least squares; ",
                       "MO, multi-objective; MOEA, multi-objective evolutionary algorithm; NSGA-II and NSGA-III, non-dominated sorting genetic algorithms II and III; ",
                       "SPEA2, strength Pareto evolutionary algorithm 2; IBEA, indicator-based evolutionary algorithm; MOEA/D, MOEA based on decomposition; ",
                       "MOEA/D-DRA, MOEA/D with dynamical resource allocation; MOPSO/D, multi-objective particle swarm optimisation based on decomposition; ",
                       "SMS-EMOA, S-metric selection evolutionary multi-objective optimisation algorithm; PAES, Pareto archived evolution strategy; ",
                       "MOCHC, multi-objective version of the CHC algorithm (cross-generational elitist selection, heterogeneous recombination and cataclysmic mutation); ",
                       "GAML, genetic algorithm for maximum likelihood; PDG, prune-delete-graft; NNI, nearest neighbour interchange; SPR, subtree pruning and regrafting; ",
                       "TBR, tree bisection and reconnection; NJ, Neighbour Joining; RF, Robinson--Foulds; MSA, multiple sequence alignment; SOP, sum of pairs; ",
                       "TC, total column score; SimG and SimNG, similarity with and without gaps; DTL, duplication, transfer and loss; ",
                       "n.r., not reported in the sources consulted; n.a., not applicable (exact methods); ",
                       "Code, public source code found in the full texts or in repositories; n.f., not found."),
                "tab:mo", "results/latex/tab_mo.tex")

# ---- (2) Metaheurísticas monoobjetivo ---------------------------------------------
# El script prepara la matriz monoobjetivo igual que la multiobjetivo, pero esta no tiene
# la columna de número de objetivos (nobj).
so <- read_csv("tables_curated/so_table.csv", show_col_types = FALSE, col_types = cols(.default = "c")) %>% order_groups() %>%
  mutate(ref = sapply(ids, cites), across(c(strategy, algorithm, criteria, structure, operators), tex))
# Esta tabla tiene seis columnas. Para compensar la columna Obj. que no tiene, las demás
# columnas ganan ancho respecto de la tabla multiobjetivo, y el ancho total queda
# prácticamente igual, unos 18,4 cm. Así las dos matrices se ven con el mismo ancho en el
# artículo. La leyenda define todas las siglas que aparecen en la tabla.
landscape_table(so, c("strategy", "ref", "algorithm", "criteria", "structure", "operators"),
                c("Strategy", "References", "Algorithm", "Criteria", "Sol. structure", "Main operators"),
                c("2.7cm", "2.1cm", "2.8cm", "2.7cm", "2.3cm", "4.0cm"),
                paste0("Single-objective metaheuristics for phylogenetic inference. MP, maximum parsimony; ",
                       "ML, maximum likelihood; ME, minimum evolution; GA, genetic algorithm; EA, evolutionary algorithm; ",
                       "ICA, imperialist competitive algorithm; SA, simulated annealing; CRO, chemical reaction optimisation; RL, reinforcement learning; ",
                       "ACO, ant colony optimisation; PSO, particle swarm optimisation; VNS, variable neighbourhood search; ",
                       "GRASP, greedy randomised adaptive search procedure; ",
                       "Rec-I-DCM3, recursive and iterative disk-covering method 3; NJ, Neighbour Joining; NNI, nearest neighbour interchange; ",
                       "SPR, subtree pruning and regrafting; TBR, tree bisection and reconnection; BNNI and BSPR, balanced NNI and SPR; ",
                       "BLX-$\\alpha$, blend crossover; DCJ, double cut and join; n.r., not reported in the sources consulted."),
                "tab:so", "results/latex/tab_so.tex")

# ---- (3) Heurísticas de búsqueda local (apéndice) -----------------------------------
# La matriz de búsqueda local va en el apéndice. Su CSV no trae la columna algorithm, así
# que la tabla tiene cinco columnas.
ls <- read_csv("tables_curated/ls_table.csv", show_col_types = FALSE, col_types = cols(.default = "c")) %>% order_groups() %>%
  mutate(ref = sapply(ids, cites), across(c(strategy, criteria, structure, operators), tex))
# Con cinco columnas sobra ancho. El espacio extra va sobre todo a References (4,0 cm),
# porque algunas estrategias reúnen hasta diez estudios, y a Main operators (4,5 cm). La
# tabla mide unos 19,1 cm.
landscape_table(ls, c("strategy", "ref", "criteria", "structure", "operators"),
                c("Strategy", "References", "Criteria", "Sol. structure", "Main operators"),
                c("3.4cm", "4.0cm", "3.6cm", "2.2cm", "4.5cm"),
                paste0("Local search heuristics and other single-objective search proposals in the optimisation core. ",
                       "MP, maximum parsimony; ML, maximum likelihood; ME, minimum evolution; BI, Bayesian inference; ",
                       "RF, Robinson--Foulds; rSPR, rooted subtree prune and regraft; rTBR, rooted tree bisection and reconnection; ",
                       "ECR, edge contract and refine; MDC, minimise deep coalescence; MRP, matrix representation with parsimony; ",
                       "ILS, incomplete lineage sorting; NNI, nearest neighbour interchange; SPR, subtree pruning and regrafting; ",
                       "TBR, tree bisection and reconnection; BNNI and BSPR, balanced NNI and SPR; NJ, Neighbour Joining; ",
                       "Rec-I-DCM3, recursive and iterative disk-covering method 3; FPGA, field-programmable gate array; MAP, maximum a posteriori; ",
                       "MGR, multiple genome rearrangement; NCD, normalised compression distance; n.r., not reported in the sources consulted."),
                "tab:ls", "results/latex/tab_ls.tex")

# ---- (4) Bloques de búsqueda --------------------------------------------------------
# counts_raw.csv trae, para cada bloque, los registros que devolvió cada base (Scopus y
# WoS) y su suma (total), antes de quitar duplicados.
raw <- read_csv("data/processed/counts_raw.csv", show_col_types = FALSE)
# scope describe en inglés el alcance de cada uno de los ocho bloques de búsqueda (Q1 a
# Q7, con el cuarto separado en Q4A y Q4B). Los nombres del vector son los códigos de
# bloque, así que scope[bl] entrega la descripción de cada fila.
scope <- c(Q1 = "Optimisation algorithms for phylogenetic tree inference (heuristics, metaheuristics, search strategies)",
           Q2 = "Multi-objective phylogenetic inference",
           Q3 = "Phylogenetic networks and reticulate evolution",
           Q4A = "Sets of gene trees, discordance and species tree estimation",
           Q4B = "Supertrees, supermatrices and total evidence",
           Q5 = "Phylogenetic inference from morphological data",
           Q6 = "Comparison of trees and networks: distances and metrics",
           Q7 = "Alignment-free and gene order methods")
# bl cuenta, para cada bloque, los registros únicos y los incluidos. Primero descarta los
# casi duplicados revisados a mano (stage == "duplicate"), porque los duplicados exactos
# ya no están en db_final_all.csv. Después str_split() y unnest() separan la columna
# blocks ("Q3;Q4A") en una fila por bloque, de modo que un registro que recuperaron
# varios bloques cuenta en cada uno, como dice la leyenda.
bl <- allr %>% filter(stage != "duplicate") %>% mutate(bl = str_split(blocks, ";")) %>% unnest(bl) %>%
  group_by(bl) %>% summarise(unique = n(), included = sum(stage == "included"))
# tb une los conteos por base con los de bl a través del código de bloque y agrega la
# descripción del alcance.
tb <- raw %>% rename(bl = block) %>% left_join(bl, by = "bl") %>% mutate(scope = scope[bl])
# Esta tabla cabe en una página vertical, así que usa un table flotante con tabular. Scope
# es un párrafo de 5 cm alineado a la izquierda porque trae descripciones largas, y las
# cinco columnas de conteos van alineadas a la derecha (r) para que las cifras queden en
# columna. \tabcolsep baja a 3 pt para que la tabla quepa en el ancho del texto.
out <- c("\\begin{table}[!htbp]", "\\centering", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
         "\\caption{Search blocks, records retrieved by database, unique records after removing duplicates and included studies. WoS, Web of Science. A record retrieved by several blocks is counted in each of them.}",
         "\\label{tab:blocks}", "\\begin{tabular}{l>{\\raggedright\\arraybackslash}p{5.0cm}rrrrr}", "\\toprule",
         "Block & Scope & Scopus & WoS & Total & Unique & Included\\\\", "\\midrule")
# El ciclo escribe una fila por bloque, con coma de miles en los conteos (big.mark = ","),
# que es la convención del inglés en que está escrito el artículo.
for (i in seq_len(nrow(tb))) out <- c(out, sprintf("%s & %s & %s & %s & %s & %s & %s\\\\", tb$bl[i], tb$scope[i],
                                                   format(tb$Scopus[i], big.mark = ","), format(tb$WoS[i], big.mark = ","),
                                                   format(tb$total[i], big.mark = ","), format(tb$unique[i], big.mark = ","),
                                                   format(tb$included[i], big.mark = ",")))
# Cierra la tabla y la escribe en results/latex/tab_blocks.tex.
out <- c(out, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(out, "results/latex/tab_blocks.tex")

# ---- (4b) Cadenas de búsqueda -------------------------------------------------------
# data/raw/search_strings.csv guarda, textuales, las cadenas que se corrieron en la búsqueda
# avanzada de Scopus y de la Web of Science Core Collection, con una fila por bloque y base
# (columnas block, database y query). La tabla las pone lado a lado, una fila por bloque,
# para que se pueda comparar la sintaxis de las dos bases.
qs <- read_csv("data/raw/search_strings.csv", show_col_types = FALSE, col_types = cols(.default = "c"))
# pivot_wider() (tidyr) deja una columna por base, con el nombre de la base como nombre de
# columna, y conserva los bloques en el orden del archivo (Q1 a Q6, con Q4A y Q4B).
qw <- qs %>% pivot_wider(names_from = database, values_from = query)
# texq() prepara una cadena para LaTeX. Primero cambia cada barra invertida por un marcador
# que no aparece en las cadenas, después antepone una barra a los caracteres que LaTeX
# reserva (& % $ # _ { }), y al final cambia el marcador por \textbackslash{}, para que
# esas llaves no reciban también una barra. ~ y ^ pasan a \textasciitilde{} y
# \textasciicircum{}. Las comillas rectas, el asterisco y los paréntesis quedan tal cual,
# porque la fuente de máquina de escribir (\ttfamily) los imprime sin cambios con la
# codificación T1 que carga el manuscrito.
texq <- function(x) {
  x <- str_replace_all(x, fixed("\\"), "@@BS@@")
  x <- str_replace_all(x, "([&%$#_{}])", "\\\\\\1")
  x <- str_replace_all(x, fixed("~"), "\\textasciitilde{}")
  x <- str_replace_all(x, fixed("^"), "\\textasciicircum{}")
  str_replace_all(x, fixed("@@BS@@"), "\\textbackslash{}")
}
# La tabla es larga (ocho cadenas de hasta 655 caracteres por base), así que va en un
# longtable vertical que puede seguir en la página siguiente. Block tiene 0,9 cm y las dos
# columnas de cadenas se reparten el resto del ancho de línea: \dimexpr resta a \linewidth
# la columna Block y los dos espacios entre columnas (4\tabcolsep, porque @{} quita los de
# los bordes) y divide por dos. Las cadenas van en \ttfamily, alineadas a la izquierda.
wq <- "\\dimexpr(\\linewidth-0.9cm-4\\tabcolsep)/2\\relax"
spec <- sprintf("@{}>{\\raggedright\\arraybackslash}p{0.9cm}>{\\raggedright\\arraybackslash\\ttfamily}p{%s}>{\\raggedright\\arraybackslash\\ttfamily}p{%s}@{}", wq, wq)
out <- c("{\\scriptsize", "\\setlength{\\LTcapwidth}{\\linewidth}", sprintf("\\begin{longtable}{%s}", spec),
         paste0("\\caption{Search strings of each block, as run in the advanced search of Scopus and of the Web of Science ",
                "Core Collection, on 20 October 2026 for blocks Q1 to Q6 and on 21 October 2026 for block Q7.}\\label{tab:queries}\\\\"),
         # La primera página lleva el filete superior y los encabezados (\endfirsthead); las
         # siguientes avisan que la tabla continúa y repiten los encabezados (\endhead), y
         # todas cierran con el filete inferior (\endfoot).
         "\\toprule", "Block & \\normalfont Scopus & \\normalfont Web of Science\\\\", "\\midrule", "\\endfirsthead",
         "\\multicolumn{3}{l}{\\emph{Table \\ref{tab:queries} (continued)}}\\\\",
         "\\toprule", "Block & \\normalfont Scopus & \\normalfont Web of Science\\\\", "\\midrule", "\\endhead",
         "\\bottomrule", "\\endfoot")
# Cada fila lleva el bloque y sus dos cadenas; \addlinespace separa los bloques, salvo
# después del último.
for (i in seq_len(nrow(qw))) {
  out <- c(out, sprintf("%s & %s & %s\\\\", qw$block[i], texq(qw$Scopus[i]), texq(qw$`Web of Science`[i])))
  if (i < nrow(qw)) out <- c(out, "\\addlinespace")
}
# Cierra el longtable y la llave del tamaño de letra, y escribe el archivo.
out <- c(out, "\\end{longtable}", "}")
writeLines(out, "results/latex/tab_queries.tex")

# ---- (5) Clados destacados del árbol de la literatura -------------------------------
# Rasgos distintivos con nombres legibles y estudios representativos: los tres más
# citados entre los que reúnen más rasgos distintivos del clado, sin contar los
# estudios de clados destacados anidados (que tienen su propia fila).
# nice traduce cada columna de caracteres de inc al nombre corto que 06_literature_tree.R
# usa en los rótulos del árbol y en la columna shared de los clados destacados. Debe
# coincidir con el vector nice de ese script, porque este script lo usa al revés, para
# volver de los nombres de shared a las columnas de inc.
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
# show da la descripción en inglés de cada carácter, tal como aparece en la columna
# Distinctive characters de la tabla.
show <- c(
  cat_mo = "multi-objective topic", cat_so_meta = "heuristic search topic", cat_tree_other = "tree inference topic",
  cat_network = "network topic", cat_forest_analysis = "forest analysis topic", cat_supertree = "supertree topic",
  cat_morpho = "morphology topic", cat_distance = "distance topic", cat_parallel = "parallel computing topic",
  type_method = "method", type_evaluation = "evaluation", type_theory = "theory", type_metric = "metric", type_review = "review",
  crit_parsimony = "parsimony", crit_likelihood = "likelihood", crit_bayesian = "Bayesian", crit_distance = "distance criterion",
  crit_coalescent = "coalescent", crit_quartet = "quartet criterion", crit_net_parsimony = "network parsimony",
  crit_pseudolikelihood = "pseudo-likelihood", alg_ga_ea = "evolutionary algorithm", alg_memetic = "memetic", alg_sa = "simulated annealing",
  alg_tabu = "tabu search", alg_swarm = "swarm", alg_immune = "immune", alg_de = "differential evolution", alg_hill_climb = "hill climbing",
  alg_ratchet = "ratchet", alg_exact = "exact algorithm", alg_mcmc = "MCMC", alg_divide_conquer = "divide and conquer",
  alg_vns_grasp = "VNS or GRASP", alg_ml = "machine learning", alg_nsga2 = "NSGA-II", alg_spea2 = "SPEA2", alg_ibea = "IBEA",
  alg_moead = "MOEA/D", rep_tree = "tree solutions", rep_matrix = "matrix solutions", rep_split = "splits", rep_cluster = "clusters",
  rep_network = "network solutions", rep_quartet = "quartet solutions", ops_nni = "NNI", ops_spr = "SPR", ops_tbr = "TBR",
  ops_pdg = "PDG", ops_crossover = "crossover", ops_mutation = "mutation", ops_consensus = "consensus", ops_nj_init = "NJ initial tree",
  data_dna = "DNA data", data_protein = "protein data", data_morphological = "morphological data", data_genomic = "genomic data",
  data_gene_trees = "gene-tree input", data_distances = "distance input", obj_mo = "two or more objectives",
  obj_many = "three or more objectives", soft_yes = "software available")
# La tabla de clados necesita el árbol que guarda 06_literature_tree.R en tree.rds. Si ese
# archivo no existe, el script omite esta tabla y termina sin error.
if (file.exists("results/tree/tree.rds")) {
  # tree.rds guarda el árbol (tree, de clase phylo) y la tabla de clados destacados (hl),
  # con el nodo, el bloque, el tamaño, la pureza y los caracteres compartidos (shared) de
  # cada clado.
  tt <- readRDS("results/tree/tree.rds"); tr <- tt$tree; hl <- tt$hl
  # prop.part() lista las hojas que cuelgan de cada nodo interno. ape numera primero las
  # hojas (1 a ntip) y después los nodos internos, así que el nodo v está en pp[[v - ntip]].
  pp <- prop.part(tr); ntip <- Ntip(tr)
  # block_nice da el nombre en inglés de cada bloque principal para los subtítulos. Este
  # script no lo reordena, porque los clados de hl ya vienen agrupados por bloque, de mayor
  # a menor número de estudios.
  block_nice <- c(network = "Phylogenetic networks", supertree = "Supertrees and species trees",
                  tree_other = "Other tree inference", forest_analysis = "Forest analysis and consensus",
                  so_meta = "Single-objective heuristic search", morpho = "Morphological data",
                  distance = "Tree and network distances", mo = "Multi-objective optimisation")
  # tips_of guarda los rótulos de los estudios de cada clado destacado.
  tips_of <- lapply(hl$node, function(v) tr$tip.label[pp[[v - ntip]]])
  # rows arma una fila de la tabla por cada clado destacado k.
  rows <- lapply(seq_len(nrow(hl)), function(k) {
    # nested identifica los otros clados destacados cuyas hojas están todas dentro de k.
    # 06_literature_tree.R solo descarta los clados anidados del mismo bloque, así que un
    # clado destacado de otro bloque puede quedar dentro de k.
    nested <- setdiff(which(sapply(tips_of, function(t) all(t %in% tips_of[[k]]))), k)
    # tips deja los estudios de k que no pertenecen a esos clados anidados, que ya tienen
    # su propia fila.
    tips <- setdiff(tips_of[[k]], unlist(tips_of[nested]))
    # hl$shared trae hasta cinco nombres cortos separados por ", "; match() con nice los
    # vuelve a los nombres de columna de inc.
    cols <- names(nice)[match(str_split(hl$shared[k], ", ")[[1]], nice)]
    # Si un nombre no aparece en nice, el script se detiene en vez de perder un carácter
    # sin aviso.
    stopifnot(!any(is.na(cols)))
    # filter() busca en inc los estudios de tips por su rótulo de hoja (label).
    d <- inc %>% filter(label %in% tips)
    # score cuenta cuántos de los caracteres distintivos del clado tiene cada estudio.
    d$score <- rowSums(as.matrix(d[, cols]))
    # Los estudios con más caracteres distintivos van primero y, entre ellos, los más
    # citados. Los tres primeros son los estudios representativos.
    d <- d %>% arrange(desc(score), desc(cited))
    # La fila guarda el número de clado, el nombre del bloque, el tamaño completo del clado
    # (con los anidados), la pureza con dos decimales, los caracteres distintivos en inglés
    # y un \cite con los tres estudios representativos.
    tibble(clade = hl$clade[k], block = block_nice[hl$block[k]], size = hl$size[k], purity = sprintf("%.2f", hl$purity[k]),
           chars = paste(show[cols], collapse = ", "),
           ref = sprintf("\\cite{%s}", paste(head(d$id, 3), collapse = ",")))
  })
  # bind_rows() junta las filas en una sola tabla, en el orden de hl.
  rows <- bind_rows(rows)
  # La tabla de clados va en una página vertical. Las tres primeras columnas son números
  # alineados a la derecha; los caracteres distintivos ocupan un párrafo de 6,4 cm porque
  # son listas largas, y los estudios representativos uno de 2,6 cm, que alcanza para tres
  # citas numéricas. En la leyenda, \% evita que % abra un comentario de LaTeX, y la ~ de
  # Fig.~\ref impide que la abreviatura quede separada del número al cortar la línea.
  out <- c("\\begin{table}[!htbp]", "\\centering", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
           paste0("\\caption{Highlighted clades of the literature tree (Fig.~\\ref{fig:tree}), grouped by main block. The purity corresponds ",
                  "to the proportion of studies of the main block, and the representative studies to the three most cited studies ",
                  "among those with the most distinctive characters, excluding the studies of nested highlighted clades.}"),
           "\\label{tab:clades}", "\\begin{tabular}{rrr>{\\raggedright\\arraybackslash}p{6.4cm}>{\\raggedright\\arraybackslash}p{2.6cm}}",
           "\\toprule", "Clade & Studies & Purity & Distinctive characters & Representative studies\\\\", "\\midrule")
  # Una fila de grupo por bloque principal, en el orden de los clados
  for (i in seq_len(nrow(rows))) {
    # Cuando cambia el bloque, y también en la primera fila, el ciclo escribe el subtítulo
    # del bloque; desde el segundo bloque, \addlinespace lo separa del anterior.
    if (i == 1 || rows$block[i] != rows$block[i - 1]) {
      if (i > 1) out <- c(out, "\\addlinespace")
      out <- c(out, sprintf("\\multicolumn{5}{l}{\\textit{%s}}\\\\", rows$block[i]))
    }
    # %d escribe los enteros (clado y estudios) y %s el texto.
    out <- c(out, sprintf("%d & %d & %s & %s & %s\\\\", rows$clade[i], rows$size[i], rows$purity[i],
                          rows$chars[i], rows$ref[i]))
  }
  # Cierra la tabla y la escribe en results/latex/tab_clades.tex.
  out <- c(out, "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(out, "results/latex/tab_clades.tex")
  # También guarda la tabla en CSV para revisarla sin compilar LaTeX. La carpeta
  # results/tables/ la crea 07_synthesis.R, que corre antes que este script.
  write_csv(rows, "results/tables/highlighted_clades_table.csv")
}
# El script avisa por consola que terminó.
cat("Listo\n")
