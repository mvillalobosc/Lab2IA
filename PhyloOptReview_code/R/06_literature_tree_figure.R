# =============================================================================
# 06_literature_tree_figure.R
# Figura del árbol de la literatura (PDF y PNG) a partir de results/tree/tree.rds,
# que guarda 06_literature_tree.R. Va en un script aparte para poder ajustar la
# figura sin volver a construir el árbol.
# El árbol se dibuja como cladograma circular, con todas las hojas en el mismo
# círculo (igual que la vista "circular-step" en modo "clado" de phyli). Las ramas
# van en gris claro y las etiquetas de los estudios (apellido y año) forman todo el
# perímetro, coloreadas según el clado destacado al que pertenecen: los clados de un
# mismo bloque principal comparten la familia de color y se distinguen por la
# luminosidad, y los estudios que no pertenecen a ningún clado destacado van en gris
# oscuro. El número de cada clado de la tabla de clados del artículo va en su raíz, y la
# leyenda da su nombre corto.
# Con 2.109 hojas en un círculo, las etiquetas son muy pequeñas: en el PDF, que es
# vectorial, se leen al ampliar.
# Las salidas son results/tree/literature_tree_nj.pdf y results/tree/literature_tree_nj.png. El
# script también lee data/processed/db_included_coded.csv, solo para comprobar que el árbol
# corresponde a la base actual.
# =============================================================================
# La configuración regional C.UTF-8 fija el orden alfabético (por código de carácter) y la
# lectura de los acentos, para que el resultado no dependa del idioma del sistema.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee la base de estudios y ape dibuja el árbol con plot.phylo; dplyr no se usa
# directamente en este script.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ape) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/06_literature_tree_figure.R

# ---- Datos -------------------------------------------------------------------------
z <- readRDS("results/tree/tree.rds")  # lee el archivo que escribe 06_literature_tree.R
tr <- z$tree; hl <- z$hl                      # árbol con nodos rotulados y clados destacados
ntip <- Ntip(tr)  # cuenta las hojas, una por estudio
desc <- prop.part(tr)                          # hojas bajo cada nodo interno (nodo ntip + k)
# La base de estudios se lee solo para comprobar que tree.rds corresponde a ella; si alguna hoja
# no es un estudio incluido, el script se detiene.
inc <- read_csv("data/processed/db_included_coded.csv", show_col_types = FALSE, guess_max = 10000)
stopifnot(all(tr$tip.label %in% inc$label))

# Nombre corto de cada clado destacado, en el orden de la tabla de clados. Resume sus
# caracteres distintivos y la descripción del texto; si el árbol cambia, hay que
# revisar estos nombres.
clade_names <- c("Distance and alignment-free methods", "Methods for genomic data",
                 "Evaluations with genomic data", "Bayesian methods", "Likelihood and Bayesian evaluations",
                 "Distance theory", "Genome rearrangement theory", "Network methods", "Network theory",
                 "Network distances", "Species tree methods from gene trees", "Supertree and species tree evaluations",
                 "Supertree and species tree theory", "Quartet methods", "Supertree methods for DNA data",
                 "Evaluations under the coalescent", "Forest methods from gene trees", "Forest metrics",
                 "Metaheuristics and heuristic search", "Hill climbing for supertrees", "Morphological data",
                 "Tree distances", "Multi-objective optimisation")
stopifnot(length(clade_names) == nrow(hl), identical(as.integer(hl$clade), seq_len(nrow(hl))))

# ---- Colores por clado ---------------------------------------------------------------
# Paleta pastel de los bloques, la misma de las demás figuras. Cada clado toma el tono de su
# bloque con una luminosidad propia (L* de CIELab entre 30 y 55) y un croma algo mayor que el
# del pastel: las etiquetas son letras muy finas y, con tonos claros, el anillo de etiquetas se
# ve incompleto al reducir la figura. Entre clados del mismo bloque se alternan tonos oscuros y
# claros (1.º el más oscuro, 2.º el más claro, etc.), de modo que los clados vecinos del mismo
# bloque queden bien separados.
pal <- c(network = "#7CB6F1", supertree = "#E3A072", tree_other = "#B59BE6", forest_analysis = "#94C07C",
         so_meta = "#C7756E", morpho = "#CBAE5E", distance = "#40A47E", mo = "#E495BA")
# shade() devuelve el mismo color hexadecimal con otra luminosidad L*. Pasa el color a CIELab,
# cambia L* y multiplica a* y b* por 1,3 (mismo matiz, más croma), y vuelve a sRGB recortando
# al rango [0, 1] los canales que se salen.
shade <- function(hex, L) {
  lab <- convertColor(t(col2rgb(hex) / 255), from = "sRGB", to = "Lab")  # pasa el color a Lab
  lab[, 1] <- L                                               # cambia la luminosidad
  lab[, 2:3] <- lab[, 2:3] * 1.3                              # sube el croma sin cambiar el matiz
  rgb(pmin(pmax(convertColor(lab, from = "Lab", to = "sRGB"), 0), 1))  # vuelve a hexadecimal
}
# lum_seq() reparte k valores de L* entre 30 y 55 y los entrega en orden alterno (el más oscuro,
# el más claro, el siguiente más oscuro, ...); con un solo clado usa 42, un valor intermedio.
lum_seq <- function(k) {
  if (k == 1) return(42)
  s <- seq(30, 55, length.out = k)  # reparte k valores entre 30 y 55
  # idx intercala 1, 2, 3, ... con k, k - 1, ...; por ejemplo, con k = 4 queda 1, 4, 2, 3.
  idx <- as.vector(rbind(seq_len(ceiling(k / 2)), rev(seq_len(k))[seq_len(ceiling(k / 2))]))[seq_len(k)]
  s[idx]                                                      # oscuro, claro, oscuro medio, claro medio...
}
# Los clados de cada bloque, en el orden de hl (de mayor a menor), reciben las luminosidades de
# lum_seq sobre el color del bloque.
clade_col <- character(nrow(hl))
for (b in unique(hl$block)) {
  k <- which(hl$block == b)  # ubica los clados del bloque b
  clade_col[k] <- sapply(lum_seq(length(k)), function(L) shade(pal[[b]], L))
}
none_col <- "#5F656C"                                         # estudios fuera de los clados destacados (gris oscuro)
tip_col <- setNames(rep(none_col, ntip), tr$tip.label)  # todas las etiquetas parten en gris
# Los clados se pintan del más grande al más chico, para que los anidados (17 en 21,
# 19 en 6) conserven su propio color.
# desc[[hl$node[k] - ntip]] entrega las hojas del clado k.
for (k in order(-hl$size)) tip_col[tr$tip.label[desc[[hl$node[k] - ntip]]]] <- clade_col[k]

# ---- Números de los clados -------------------------------------------------------------
# El perímetro queda solo para las etiquetas: el número de cada clado destacado se escribe en
# su raíz (el nodo que reúne a sus estudios), sobre un círculo blanco con el borde del color del
# clado. clade_numbers() recibe las coordenadas del árbol dibujado (lp) y el factor de escala
# k_esc, y dibuja sobre el gráfico abierto sin devolver nada.
clade_numbers <- function(lp, k_esc = 1) {
  x <- lp$xx[hl$node]; y <- lp$yy[hl$node]  # coordenadas de la raíz de cada clado
  points(x, y, pch = 21, cex = 2.6 * k_esc, bg = "white", col = clade_col, lwd = 1.4 * k_esc)
  text(x, y, hl$clade, cex = 0.8 * k_esc, font = 2, col = "#2C3138")
}

# ---- Figura ---------------------------------------------------------------------------
# Radio de las hojas del cladograma (node.depth = 2: niveles equiespaciados), calculado
# en un dispositivo nulo para fijar después los límites de la figura.
pdf(NULL, width = 8, height = 8)  # abre un dispositivo nulo cuadrado, que no escribe archivos
par(mar = c(0, 0, 0, 0), family = "Helvetica")
plot.phylo(tr, type = "fan", use.edge.length = FALSE, node.depth = 2, show.tip.label = FALSE, no.margin = TRUE)
lp0 <- get("last_plot.phylo", envir = .PlotPhyloEnv)  # recupera las coordenadas del dibujo
# Rt es la distancia de las hojas al centro, que en este cladograma es la misma para todas.
Rt <- max(sqrt(lp0$xx[seq_len(ntip)]^2 + lp0$yy[seq_len(ntip)]^2))
# Etiquetas "Apellido año" (también "van Iersel 2017") y su tamaño: 2 * pi * Rt / ntip es el
# arco que separa dos hojas vecinas, y la altura de las mayúsculas queda en el 80 % de esa
# separación; el resto alcanza para los trazos que bajan de la línea (p, g, y), de modo que las
# etiquetas vecinas no se superponen.
labs <- gsub("_", " ", tr$tip.label)
# Para medir el texto, el panel cuadrado se rehace con la misma escala en ambos ejes.
plot.new(); plot.window(xlim = c(-Rt, Rt), ylim = c(-Rt, Rt), xaxs = "i", yaxs = "i")
cex0 <- 0.8 * (2 * pi * Rt / ntip) / strheight("M", cex = 1)
# El largo de cada etiqueta en unidades del árbol no depende del tamaño del lienzo (si el lienzo
# crece, crecen igual las letras y la escala), así que se mide una vez aquí. lim es la mitad del
# ancho del panel del árbol: la mayor coordenada, en x o en y, del extremo exterior de las
# etiquetas, de modo que las etiquetas forman el borde exterior de la figura.
off <- 0.006 * Rt  # separa cada etiqueta de la punta de su rama
th0 <- atan2(lp0$yy[seq_len(ntip)], lp0$xx[seq_len(ntip)])  # ángulo de cada hoja
r_end <- Rt + off + strwidth(labs, cex = cex0, font = 2)     # radio del extremo de cada etiqueta
lim <- max(abs(r_end * cos(th0)), abs(r_end * sin(th0))) + 0.004 * Rt
invisible(dev.off())  # cierra el dispositivo nulo
# k_esc agranda el lienzo y todos los tamaños por igual. El PDF se dibuja con k_esc = 9
# (página de 72 x 86,4 pulgadas, que LaTeX reduce al ancho del texto): así las etiquetas
# quedan de unos 7 puntos al dibujarlas y cairo no colapsa sus letras, algo que ocurre
# con textos de menos de 2 puntos. El PNG se dibuja a tamaño normal (k_esc = 1).
# draw_tree() dibuja la figura completa en el dispositivo abierto, con el árbol, sus etiquetas y
# los números de los clados en el panel superior y la leyenda en el inferior.
draw_tree <- function(k_esc = 1) {
  # El panel superior (alto 8) lleva el árbol y el inferior (alto 1,6), la leyenda.
  layout(matrix(1:2, ncol = 1), heights = c(8, 1.6))
  par(mar = c(0, 0, 0, 0), family = "Helvetica")  # quita los márgenes y usa Helvetica
  # plot.phylo dibuja solo las ramas, en gris; las etiquetas se escriben después, una por una.
  plot.phylo(tr, type = "fan", use.edge.length = FALSE, node.depth = 2, show.tip.label = FALSE,
             edge.color = "#B4B9BF", edge.width = 0.3 * k_esc, no.margin = TRUE, x.lim = c(-lim, lim), y.lim = c(-lim, lim))
  lp <- get("last_plot.phylo", envir = .PlotPhyloEnv)  # recupera las coordenadas del árbol
  # Etiquetas radiales en negrita: el tamaño se ajusta a la separación entre hojas
  # vecinas, y en la mitad izquierda se giran 180 grados para que se lean de izquierda
  # a derecha.
  th <- atan2(lp$yy[seq_len(ntip)], lp$xx[seq_len(ntip)])  # calcula el ángulo de cada hoja
  # Mismo criterio de tamaño que en el cálculo de lim, ahora con la escala de este dispositivo.
  cex_lab <- 0.8 * (2 * pi * Rt / ntip) / strheight("M", cex = 1)
  for (i in seq_len(ntip)) {
    left <- cos(th[i]) < 0  # indica si la hoja está en la mitad izquierda
    # adj = 1 alinea a la derecha las etiquetas giradas, para que crezcan hacia afuera del círculo.
    text((Rt + off) * cos(th[i]), (Rt + off) * sin(th[i]), labs[i], cex = cex_lab, col = tip_col[i], font = 2,
         srt = th[i] * 180 / pi + if (left) 180 else 0, adj = c(if (left) 1 else 0, 0.5))
  }
  clade_numbers(lp, k_esc)
  # Leyenda: número y nombre de cada clado con su color, más los estudios sin clado.
  # plot.new() abre el panel inferior, cuyo ancho va de -0,04 a 1,04 en coordenadas de usuario.
  par(mar = c(0, 0, 0, 0)); plot.new()
  leg <- c(sprintf("%d  %s", hl$clade, clade_names), "Not in a highlighted clade")
  # legend() llena las tres columnas de arriba hacia abajo, con ceiling(n / 3) rótulos por
  # columna. El ancho de texto de cada columna es el de su rótulo más largo, medido con
  # strwidth() en las coordenadas del panel y con el mismo cex de la leyenda, más un margen de
  # 0,02, para que un nombre largo no invada la columna siguiente.
  per <- ceiling(length(leg) / 3)
  tw <- sapply(split(leg, ceiling(seq_along(leg) / per)), function(v) max(strwidth(v, cex = 0.7 * k_esc))) + 0.02
  legend("top", legend = leg, fill = c(clade_col, none_col), border = NA, bty = "n", cex = 0.7 * k_esc, ncol = 3,
         y.intersp = 0.95, title = "Highlighted clades (label colours)", text.col = "#2C3138", x.intersp = 0.5,
         text.width = tw)
}
# El PDF mide 72 x 86,4 pulgadas (8 x 9,6 multiplicado por k_esc = 9) y el PNG mide 8 x 9,6
# pulgadas a 300 puntos por pulgada (2.400 x 2.880 píxeles), con la misma proporción.
# cairo_pdf incrusta las fuentes y conserva los guiones (pdf() los dibuja como signos menos)
cairo_pdf("results/tree/literature_tree_nj.pdf", width = 8 * 9, height = 9.6 * 9); draw_tree(k_esc = 9); invisible(dev.off())
png("results/tree/literature_tree_nj.png", width = 2400, height = 2880, res = 300); draw_tree(); invisible(dev.off())
cat("Listo\n")
