# =============================================================================
# 09_schemes.R
# Esquemas del manuscrito en TikZ (clase standalone): (1) diagrama de flujo
# PRISMA 2020 con los conteos de results/tables/prisma_counts.csv y (2) esquema
# del problema de inferencia filogenética como problema de optimización (datos,
# estructuras de solución, criterios, estrategias de búsqueda y medidas de
# calidad). Escribe el código en schemes/, lo compila con pdflatex y genera una
# versión PNG con pdftoppm. Colores pasteles y texto en gris oscuro.
#
# Entradas
#   results/tables/prisma_counts.csv      conteos de cada etapa (los escribe 07_synthesis.R)
# Salidas
#   schemes/prisma_flow.tex, .pdf y .png  diagrama de flujo PRISMA 2020
#   schemes/framework.tex, .pdf y .png    esquema del problema de optimización
# Para compilar hacen falta pdflatex, con standalone, tikz y helvet, y pdftoppm (poppler).
# =============================================================================
# El locale C.UTF-8 hace que R trate el texto como UTF-8, igual en cualquier sistema.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee el CSV de conteos. dplyr queda cargado como en los demás scripts, aunque este
# no usa sus funciones.
suppressPackageStartupMessages({ library(readr); library(dplyr) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/09_schemes.R
# Crea la carpeta schemes/ si no existe.
dir.create("schemes", showWarnings = FALSE)
# pc tiene dos columnas, item (el nombre de cada conteo, como scopus o screened) y value.
pc <- read_csv("results/tables/prisma_counts.csv", show_col_types = FALSE)
# v() busca el valor de un conteo por su nombre y lo escribe con coma de miles (13451 queda
# 13,451), que es la convención del inglés del artículo.
v <- function(k) format(pc$value[pc$item == k], big.mark = ",")

# ---- Preámbulo LaTeX común ------------------------------------------------------------
# preamble es el encabezado LaTeX que comparten los dos esquemas. La clase standalone
# recorta la página al tamaño del dibujo, con un margen de 4 pt (border), para que el PDF
# entre al manuscrito sin bordes blancos. helvet define Helvetica como familia sin serifa y
# el cambio de \familydefault la deja como letra de todo el dibujo, la misma familia de las
# figuras de 07_synthesis.R; fontenc con T1 usa la codificación de fuentes que trae los
# acentos como glifos propios. Las bibliotecas de TikZ aportan la posición relativa entre
# nodos (positioning), las puntas de flecha Stealth (arrows.meta), la aritmética de
# coordenadas (calc), los nodos que encierran otros puntos (fit) y la capa de fondo
# (backgrounds).
preamble <- c("\\documentclass[border=4pt]{standalone}", "\\usepackage[T1]{fontenc}", "\\usepackage{helvet}",
              "\\renewcommand{\\familydefault}{\\sfdefault}", "\\usepackage{tikz}",
              "\\usetikzlibrary{positioning,arrows.meta,calc,fit,backgrounds}",
              # ink es el gris oscuro del texto e ink2 el gris de las flechas, los mismos de
              # las figuras de 07_synthesis.R. Cada color pastel de relleno (pblue, prose,
              # pgreen, plav, papri, pgold) tiene su par "line", más intenso, para el borde.
              # Los bordes azul, verde, lavanda, damasco y dorado repiten colores de la paleta
              # de bloques de 07_synthesis.R, y pband es el gris claro de las bandas de fase
              # del diagrama PRISMA.
              "\\definecolor{ink}{HTML}{2C3138}", "\\definecolor{ink2}{HTML}{52514E}",
              "\\definecolor{pblue}{HTML}{EAF3FC}", "\\definecolor{pblueline}{HTML}{7CB6F1}",
              "\\definecolor{prose}{HTML}{FBEDEB}", "\\definecolor{proseline}{HTML}{D99A93}",
              "\\definecolor{pgreen}{HTML}{EEF6E9}", "\\definecolor{pgreenline}{HTML}{94C07C}",
              "\\definecolor{plav}{HTML}{F1ECFB}", "\\definecolor{plavline}{HTML}{B59BE6}",
              "\\definecolor{papri}{HTML}{FCF1E9}", "\\definecolor{papriline}{HTML}{E3A072}",
              "\\definecolor{pgold}{HTML}{F8F3E4}", "\\definecolor{pgoldline}{HTML}{CBAE5E}",
              "\\definecolor{pband}{HTML}{F3F4F6}")

# ---- (1) Diagrama PRISMA ------------------------------------------------------------
# El diagrama sigue el formato PRISMA 2020. La columna izquierda lleva el flujo principal
# (cajas azules) y cada caja tiene a su derecha una caja rosada con los registros que
# salen en esa etapa. Los conteos vienen de prisma_counts.csv a través de v(), así que
# basta volver a correr el script para actualizar el diagrama cuando cambian los datos.
prisma <- c(preamble, "\\begin{document}",
  # La primera cadena abre el tikzpicture con letra \footnotesize y texto en ink. La opción
  # node distance deja 5 mm entre cajas en vertical y 9 mm en horizontal (below=of y
  # right=of).
  "\\begin{tikzpicture}[font=\\footnotesize, text=ink, node distance=5mm and 9mm,",
  # Hay tres estilos de caja. main (azul) lleva el flujo principal con texto centrado; excl
  # (rosada) lleva las exclusiones con texto a la izquierda, porque son listas de motivos;
  # inc (verde) marca los estudios incluidos al final. main y excl tienen la misma altura
  # mínima (21 mm), para que cada caja quede pareja con su caja de exclusión, y excl es
  # 2 mm más ancha porque sus líneas son más largas.
  "  main/.style={draw=pblueline, fill=pblue, rounded corners=2pt, align=center, text width=62mm, inner sep=5pt, line width=0.6pt, minimum height=21mm},",
  "  excl/.style={draw=proseline, fill=prose, rounded corners=2pt, align=left, text width=64mm, inner sep=5pt, line width=0.6pt, minimum height=21mm},",
  "  inc/.style={draw=pgreenline, fill=pgreen, rounded corners=2pt, align=center, text width=62mm, inner sep=5pt, line width=0.6pt, minimum height=10mm},",
  # arr dibuja las flechas en el gris ink2, con punta Stealth de 2,2 mm.
  "  arr/.style={-{Stealth[length=2.2mm]}, draw=ink2, line width=0.6pt}]",
  # Cada \node escribe una caja con sus conteos. En las cadenas de R, "\\\\" produce \\, que
  # corta la línea dentro de la caja, y \textit{n} pone la n en cursiva, como se escriben
  # los símbolos estadísticos. right=of y below=of ubican cada caja respecto de otra. Las
  # cajas se llaman id (identificación), dup (duplicados), scr (cribado), aut (filtros
  # automáticos), ass (evaluación asistida), exc (excluidos en la evaluación), ver
  # (incluidos tras el cribado y la verificación del núcleo), exv (excluidos en la
  # verificación) e inc (incluidos en la revisión).
  sprintf("\\node[main] (id) {Records identified from Scopus (\\textit{n} = %s)\\\\ and Web of Science (\\textit{n} = %s)\\\\ in eight search blocks (\\textit{n} = %s)};", v("scopus"), v("wos"), v("identified")),
  sprintf("\\node[excl, right=of id] (dup) {Records removed before screening:\\\\ duplicates by DOI or normalised title (\\textit{n} = %s)\\\\ near-duplicates reviewed one by one (\\textit{n} = %s)};", v("duplicates_exact"), v("duplicates_near")),
  sprintf("\\node[main, below=of id] (scr) {Records screened (\\textit{n} = %s)};", v("screened")),
  sprintf("\\node[excl, right=of scr] (aut) {Records excluded by automated filters:\\\\ no abstract (\\textit{n} = %s)\\\\ no phylogenetic term (\\textit{n} = %s)\\\\ document type (\\textit{n} = %s)};", v("no_abstract"), v("out_scope"), v("doc_type")),
  sprintf("\\node[main, below=of scr] (ass) {Records assessed with the assisted protocol\\\\ (\\textit{n} = %s), %s in round 1,\\\\ %s in round 2 and %s in round 3};", v("assessed"), v("assessed_round1"), v("assessed_round2"), v("assessed_round3")),
  sprintf("\\node[excl, right=of ass] (exc) {Records excluded:\\\\ empirical application (\\textit{n} = %s)\\\\ other meaning or domain (\\textit{n} = %s)\\\\ no methodological contribution (\\textit{n} = %s)};", v("application"), v("other_domain"), v("no_method")),
  sprintf("\\node[main, below=of ass] (ver) {Studies included after screening (\\textit{n} = %s)\\\\ optimisation core verified with full texts\\\\ or publisher records (\\textit{n} = %s)};", v("included_screening"), v("verified_core")),
  sprintf("\\node[excl, right=of ver] (exv) {Excluded at verification:\\\\ empirical application (\\textit{n} = %s)};", v("excluded_verification")),
  sprintf("\\node[inc, below=of ver] (inc) {Studies included in the review (\\textit{n} = %s)};", v("included")),
  # Las flechas verticales siguen el flujo principal y las horizontales llevan a cada caja
  # de exclusión.
  "\\draw[arr] (id) -- (scr); \\draw[arr] (scr) -- (ass); \\draw[arr] (ass) -- (ver); \\draw[arr] (ver) -- (inc);",
  "\\draw[arr] (id) -- (dup); \\draw[arr] (scr) -- (aut); \\draw[arr] (ass) -- (exc); \\draw[arr] (ver) -- (exv);",
  # Las bandas de fase van en la capa de fondo para quedar detrás de las cajas. Cada banda
  # es un nodo fit sin borde, relleno con pband, que va desde 2 mm sobre la primera caja de
  # la fase hasta 2 mm bajo la última, a 9 mm a la izquierda de la columna principal
  # ($(id.north west)+(-9mm,2mm)$ usa calc para desplazar la esquina). Como los dos puntos
  # del fit tienen la misma coordenada x, el nodo toma el ancho mínimo de TikZ (1 pt) y la
  # banda se ve como una línea vertical gris clara que marca la extensión de la fase.
  # Identification cubre la caja id, Screening va de scr a ver e Included cubre inc.
  "\\begin{scope}[on background layer]",
  "\\node[fill=pband, rounded corners=2pt, fit={($(id.north west)+(-9mm,2mm)$) ($(id.south west)+(-9mm,-2mm)$)}, inner sep=0pt] (b1) {};",
  "\\node[fill=pband, rounded corners=2pt, fit={($(scr.north west)+(-9mm,2mm)$) ($(ver.south west)+(-9mm,-2mm)$)}, inner sep=0pt] (b2) {};",
  "\\node[fill=pband, rounded corners=2pt, fit={($(inc.north west)+(-9mm,2mm)$) ($(inc.south west)+(-9mm,-2mm)$)}, inner sep=0pt] (b3) {};",
  "\\end{scope}",
  # Los rótulos de fase van girados 90 grados, en negrita, 1,6 mm a la derecha de cada
  # banda y centrados en su altura.
  "\\node[rotate=90, font=\\footnotesize\\bfseries] at ($(b1.west)+(1.6mm,0)$) {Identification};",
  "\\node[rotate=90, font=\\footnotesize\\bfseries] at ($(b2.west)+(1.6mm,0)$) {Screening};",
  "\\node[rotate=90, font=\\footnotesize\\bfseries] at ($(b3.west)+(1.6mm,0)$) {Included};",
  "\\end{tikzpicture}", "\\end{document}")
# Escribe el código del diagrama en schemes/prisma_flow.tex.
writeLines(prisma, "schemes/prisma_flow.tex")

# ---- (2) Esquema del problema ---------------------------------------------------------
# col_box() arma una columna del esquema como un solo nodo TikZ, con el título en negrita y
# los elementos debajo. Recibe el nombre del nodo, el título, los elementos, el color de
# relleno, el color del borde y la posición (pos). pos va vacía en la primera columna y
# como ", right=of <columna anterior>" en las demás, y el formato "fill=%s%s" la pega a
# las opciones del nodo. En el .tex, \\[1.5mm] deja más aire bajo el título y \\[0.8mm]
# separa los elementos entre sí.
col_box <- function(name, title, items, fill, line, pos) {
  c(sprintf("\\node[col, draw=%s, fill=%s%s] (%s) {\\textbf{%s}\\\\[1.5mm] %s};", line, fill, pos, name, title,
            paste(items, collapse = "\\\\[0.8mm] ")))
}
# El esquema presenta la inferencia filogenética como problema de optimización en cinco
# columnas que se leen de izquierda a derecha, con los datos de entrada, la estructura de
# la solución, el criterio, la estrategia de búsqueda y las medidas de calidad. Cada
# columna usa uno de los pares de colores pastel del preámbulo.
frame <- c(preamble, "\\begin{document}",
  # Este tikzpicture deja 5 mm entre columnas (node distance).
  "\\begin{tikzpicture}[font=\\footnotesize, text=ink, node distance=5mm,",
  # El estilo col da a todas las columnas el mismo ancho de texto (29 mm) y la misma altura
  # mínima (62 mm), para que se vean como paneles iguales aunque tengan distinto número de
  # elementos.
  "  col/.style={rounded corners=3pt, align=center, text width=29mm, minimum height=62mm, inner sep=5pt, line width=0.6pt},",
  # arr dibuja flechas de 0,8 pt con punta Stealth de 2,4 mm, algo más gruesas que las del
  # diagrama PRISMA.
  "  arr/.style={-{Stealth[length=2.4mm]}, draw=ink2, line width=0.8pt}]",
  # Cada llamada a col_box() agrega una columna a la derecha de la anterior. Los elementos
  # traen sus propios \\ para cortar las líneas dentro del ancho de 29 mm, y level-$k$
  # escribe la k en modo matemático.
  col_box("data", "Input data", c("DNA and protein\\\\sequences", "Morphological\\\\characters", "Distance matrices", "Gene trees, quartets\\\\and triplets", "Genomic data (SNPs,\\\\whole genomes)"), "pblue", "pblueline", ""),
  col_box("sol", "Solution structure", c("Rooted or unrooted\\\\binary trees", "Explicit networks\\\\(tree-child, level-$k$)", "Split networks", "Forests (sets of\\\\gene trees, supertrees)", "Indirect encodings\\\\(matrices, vectors)"), "papri", "papriline", ", right=of data"),
  col_box("crit", "Criterion", c("Maximum parsimony", "Maximum likelihood", "Bayesian posterior", "Minimum evolution\\\\and least squares", "Coalescent, quartet\\\\and pseudo-likelihood", "Network parsimony\\\\and reticulations"), "plav", "plavline", ", right=of sol"),
  col_box("search", "Search strategy", c("Exact: branch and\\\\bound, DP, ILP, FPT", "Constructive: NJ,\\\\stepwise addition", "Local search: NNI,\\\\SPR, TBR, ratchet", "Metaheuristics: GA,\\\\SA, swarm, memetic", "MCMC sampling", "Multi-objective:\\\\NSGA-II, IBEA, MOEA/D"), "pgreen", "pgreenline", ", right=of crit"),
  col_box("qual", "Quality and comparison", c("Score of the\\\\criterion", "Distances: RF,\\\\quartet, SPR, BHV", "Support: bootstrap,\\\\posterior, concordance", "Consensus and\\\\tree space", "Multi-objective\\\\indicators (HV)"), "pgold", "pgoldline", ", right=of search"),
  # Las flechas unen cada columna con la siguiente.
  "\\draw[arr] (data) -- (sol); \\draw[arr] (sol) -- (crit); \\draw[arr] (crit) -- (search); \\draw[arr] (search) -- (qual);",
  # La flecha de retorno baja 5 mm desde la columna de calidad (++(0,-5mm) es un
  # desplazamiento relativo), cruza hacia la izquierda y sube a la estrategia de búsqueda,
  # porque -| traza primero el tramo horizontal y después el vertical. Representa que la
  # medida de calidad guía la selección, aceptación o archivo de soluciones candidatas. En
  # un camino -|, pos=0.5 es la esquina, así que pos=0.25 deja el rótulo en la mitad del
  # tramo horizontal.
  "\\draw[arr, rounded corners=4pt] (qual.south) -- ++(0,-5mm) -| node[pos=0.25, below, font=\\scriptsize, text=ink2] {selection, acceptance or archiving of candidate solutions} (search.south);",
  "\\end{tikzpicture}", "\\end{document}")
# Escribe el código del esquema en schemes/framework.tex.
writeLines(frame, "schemes/framework.tex")

# ---- Compilación a PDF y PNG ----------------------------------------------------------
# Compila cada esquema y genera su PNG. pdflatex corre dentro de schemes/ (cd) para que el
# PDF quede junto al .tex, -interaction=nonstopmode evita que se detenga a pedir
# instrucciones ante un error, y la salida de consola se redirige a un archivo .log.
# pdftoppm convierte el PDF a PNG a 300 dpi, y -singlefile evita el sufijo de página (-1)
# en el nombre. Si pdflatex no genera el PDF, el script se detiene y deja el .log para ver
# el error; si todo sale bien, borra los auxiliares .aux y .log.
for (f in c("prisma_flow", "framework")) {
  unlink(file.path("schemes", paste0(f, ".pdf")))
  system(sprintf("cd schemes && pdflatex -interaction=nonstopmode %s.tex > %s.log 2>&1", f, f))
  if (!file.exists(file.path("schemes", paste0(f, ".pdf")))) stop("pdflatex no generó ", f, ".pdf; revisa schemes/", f, ".log")
  system(sprintf("cd schemes && pdftoppm -png -r 300 -singlefile %s.pdf %s", f, f))
  file.remove(file.path("schemes", paste0(f, c(".aux", ".log"))))
}
# Muestra los archivos de schemes/ para confirmar que están los .tex, .pdf y .png.
print(list.files("schemes"))
