# =============================================================================
# 07_synthesis.R
# Síntesis descriptiva de los estudios incluidos: conteos del diagrama PRISMA,
# evolución anual por bloque, perfil de caracteres por bloque (criterios,
# familias algorítmicas, estructuras y operadores), tipos de aporte, revistas y
# disponibilidad de software. Genera las figuras (PDF y PNG, etiquetas en inglés,
# paleta pastel validada para daltonismo), las tablas en CSV, la matriz completa
# de métodos (un estudio por fila) y los resúmenes por bloque usados en la
# redacción. Las variables nominales se ordenan de mayor a menor frecuencia.
#
# Entradas (entre paréntesis, el script que produce cada archivo)
#   data/processed/db_final_all.csv       todos los registros con su etapa PRISMA (05)
#   data/processed/db_included_coded.csv  incluidos codificados y verificados (05)
#   data/processed/agreement.rds          acuerdo entre el diccionario y el cribado (03)
#   data/processed/verify.rds             confiabilidad del cribado asistido (04)
#   data/processed/counts_raw.csv         registros por bloque de búsqueda y base (01)
#   verification/                         mo_matrix.csv, so_matrix.csv y duplicates_manual.csv
# Salidas
#   results/figures/                      studies_per_year y character_profile (PDF y PNG)
#   results/tables/                       prisma_counts, studies_per_year, character_profile,
#                                         type_by_block, software_by_block, venues y
#                                         methods_matrix_all_studies (CSV)
#   results/digests/                      un resumen de texto por bloque y reviews.txt
# =============================================================================
# Fija la configuración regional en C.UTF-8 para que los ordenamientos y el manejo de textos
# con acentos den el mismo resultado en cualquier equipo.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr, dplyr, stringr y tidyr preparan los datos, y ggplot2 dibuja las figuras.
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(stringr); library(tidyr); library(ggplot2)
})
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/07_synthesis.R
# Crea las carpetas de salida si no existen.
dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("results/digests", recursive = TRUE, showWarnings = FALSE)

# ---- Datos de entrada ----------------------------------------------------------------
# allr e inc son las bases que deja 05_verification.R, agr y ver tienen los indicadores de
# acuerdo de 03_merge_coding.R y 04_verify_sample.R, raw cuenta los registros de cada bloque
# de búsqueda antes de eliminar duplicados, y las dos matrices y los duplicados manuales
# sirven para contar el núcleo verificado.
allr <- read_csv("data/processed/db_final_all.csv", show_col_types = FALSE, guess_max = 10000)
inc  <- read_csv("data/processed/db_included_coded.csv", show_col_types = FALSE, guess_max = 10000)
agr  <- readRDS("data/processed/agreement.rds"); ver <- readRDS("data/processed/verify.rds")
raw  <- read_csv("data/processed/counts_raw.csv", show_col_types = FALSE)
mo_m <- read_csv("verification/mo_matrix.csv", show_col_types = FALSE)
so_m <- read_csv("verification/so_matrix.csv", show_col_types = FALSE)
dupm <- read_csv("verification/duplicates_manual.csv", show_col_types = FALSE)

# ---- Paleta y orden de los bloques ---------------------------------------------------
# Bloques de mayor a menor número de estudios; la paleta pastel validada se asigna
# en ese orden y se mantiene en todas las figuras (el color sigue al bloque).
# block_nice da el nombre en inglés de cada bloque principal. parallel no aparece porque
# 05_verification.R lo pasó a tree_other.
block_nice <- c(network = "Phylogenetic networks", supertree = "Supertrees and species trees",
                tree_other = "Other tree inference", forest_analysis = "Forest analysis and consensus",
                so_meta = "Single-objective heuristic search", morpho = "Morphological data",
                distance = "Tree and network distances", mo = "Multi-objective optimisation")
# block_n cuenta los estudios de cada bloque. El factor con todos los niveles hace que un
# bloque sin estudios aparezca con 0 en vez de desaparecer.
block_n <- table(factor(inc$main_block, levels = names(block_nice)))
# Reordena block_nice de mayor a menor número de estudios (en un empate, order() respeta el
# orden de la lista). Este orden manda en las leyendas, los ejes y los resúmenes por bloque.
block_nice <- block_nice[order(-block_n[names(block_nice)])]
# pal fija el color de cada bloque por su nombre, con la paleta pastel que usan todas las
# figuras, incluido el árbol de 06_literature_tree_figure.R. Los colores siguen el orden de
# los bloques con los datos actuales, de modo que el primero va al bloque más grande. Si los
# conteos cambian, cada bloque conserva su color y solo cambia el orden de la leyenda.
pal <- setNames(c("#7CB6F1", "#E3A072", "#B59BE6", "#94C07C", "#C7756E", "#CBAE5E", "#40A47E", "#E495BA"),
                c("network", "supertree", "tree_other", "forest_analysis", "so_meta", "morpho", "distance", "mo"))
# pal[names(block_nice)] solo reordena el vector para que siga el orden de los bloques.
pal <- pal[names(block_nice)]
# ink e ink2 son los grises del texto, los mismos de los esquemas de 09_schemes.R, y grid_col
# es el gris claro de las líneas de referencia. ink pinta los títulos, las leyendas y los
# nombres de panel, e ink2 las marcas de los ejes.
ink <- "#2C3138"; ink2 <- "#52514e"; grid_col <- "#ECECEC"

# ---- Conteos PRISMA ---------------------------------------------------------------
# cnt() cuenta los registros de la base completa que están en la etapa s.
cnt <- function(s) sum(allr$stage == s)
# ids_core reúne los estudios distintos de las dos matrices de verificación, sin los
# duplicados confirmados (setdiff() también elimina las repeticiones). Es el núcleo de
# optimización verificado con textos completos o registros del editor.
ids_core <- setdiff(unlist(str_split(c(mo_m$ids, so_m$ids), ";")), dupm$id_drop)
# assessed son los registros que pasaron al cribado asistido, es decir, todos menos los
# duplicados y los que excluyeron los filtros automáticos de 02_screen.R (sin resumen, fuera
# de la filogenética o tipo de documento).
assessed <- allr %>% filter(!stage %in% c("duplicate", "excluded: no abstract", "excluded: outside phylogenetics", "excluded: document type"))
# prisma lista cada conteo (item) con su valor (value) en la misma posición:
#   scopus, wos, identified    registros recuperados por base y en total (un registro que
#                              aparece en varios bloques de búsqueda cuenta en cada uno)
#   duplicates_exact           duplicados por DOI o título normalizado (01_merge.R), que son
#                              los recuperados menos los registros únicos
#   duplicates_near            casi duplicados revisados uno a uno (03_merge_coding.R)
#   duplicates                 suma de los dos anteriores
#   screened                   registros únicos que entran al cribado
#   no_abstract, out_scope,    exclusiones de los filtros automáticos (sin resumen, fuera de
#   doc_type                   la filogenética y tipo de documento)
#   assessed, assessed_round1, registros evaluados con el protocolo, en total y por ronda
#   assessed_round2
#   application, other_domain, exclusiones del cribado asistido, por motivo
#   no_method
#   included_screening         incluidos en el cribado, contando los que la verificación
#                              excluyó después
#   included_round1,           incluidos en el cribado, por ronda
#   included_round2
#   verified_core              estudios del núcleo de optimización verificado
#   excluded_verification      excluidos en la verificación (05_verification.R)
#   included                   estudios incluidos en la revisión
#   kappa_dict, po_dict        kappa y acuerdo observado entre el diccionario y el cribado
#                              asistido (03_merge_coding.R)
#   kappa_verify, po_verify,   kappa, acuerdo observado y número de registros de las dos
#   n_verify                   muestras de confiabilidad juntas (04_verify_sample.R)
#   kappa_verify_r1,           kappa y número de registros de la muestra de cada ronda
#   n_verify_r1 (y los _r2)
#   verify_block_agree,        acuerdo de bloque principal y número de registros incluidos
#   n_both_verify              en ambas pasadas
# El script redondea los indicadores de acuerdo a tres decimales, y los n_verify son los
# totales de las tablas de 2 x 2.
prisma <- tibble(
  item = c("scopus", "wos", "identified", "duplicates_exact", "duplicates_near", "duplicates", "screened",
           "no_abstract", "out_scope", "doc_type", "assessed", "assessed_round1", "assessed_round2", "assessed_round3",
           "application", "other_domain", "no_method", "included_screening", "included_round1", "included_round2",
           "included_round3",
           "verified_core", "excluded_verification", "included",
           "kappa_dict", "po_dict", "kappa_verify", "po_verify", "n_verify", "kappa_verify_r1", "n_verify_r1",
           "kappa_verify_r2", "n_verify_r2", "kappa_verify_r3", "n_verify_r3", "verify_block_agree", "n_both_verify"),
  value = c(sum(raw$Scopus), sum(raw$WoS), sum(raw$total), sum(raw$total) - nrow(allr), cnt("duplicate"),
            sum(raw$total) - nrow(allr) + cnt("duplicate"), nrow(allr) - cnt("duplicate"),
            cnt("excluded: no abstract"), cnt("excluded: outside phylogenetics"), cnt("excluded: document type"),
            nrow(assessed), sum(assessed$round == 1), sum(assessed$round == 2), sum(assessed$round == 3),
            cnt("excluded: empirical application"), cnt("excluded: other domain"), cnt("excluded: no method"),
            cnt("included") + cnt("excluded at verification: empirical application"),
            sum(assessed$round == 1 & assessed$inc == 1), sum(assessed$round == 2 & assessed$inc == 1),
            sum(assessed$round == 3 & assessed$inc == 1),
            length(ids_core), cnt("excluded at verification: empirical application"), nrow(inc),
            round(agr$kappa, 3), round(agr$po, 3), round(ver$kappa, 3), round(ver$po, 3), sum(ver$tab),
            round(ver$r1$kappa, 3), sum(ver$r1$tab), round(ver$r2$kappa, 3), sum(ver$r2$tab),
            round(ver$r3$kappa, 3), sum(ver$r3$tab),
            round(ver$agree_block, 3), ver$n_both))
# stopifnot() controla que el diagrama cuadre. Cada registro evaluado debe terminar en una
# sola salida (uno de los tres motivos de exclusión o la inclusión), y los incluidos en la
# revisión deben ser los incluidos en el cribado menos los excluidos en la verificación. Si
# algo no cuadra, el script se detiene.
stopifnot(prisma$value[prisma$item == "assessed"] ==
            sum(prisma$value[prisma$item %in% c("application", "other_domain", "no_method", "included_screening")]),
          prisma$value[prisma$item == "included"] ==
            prisma$value[prisma$item == "included_screening"] - prisma$value[prisma$item == "excluded_verification"])
# Guarda la tabla en results/tables/prisma_counts.csv, que lee 09_schemes.R para dibujar el
# diagrama, y la muestra en la consola.
write_csv(prisma, "results/tables/prisma_counts.csv")
print(prisma, n = 40)

# Los PDF se guardan con cairo_pdf, que incrusta las fuentes y conserva los guiones
# (el dispositivo pdf() los dibuja como signos menos).
# theme_pub() es el tema común de las figuras. Parte de theme_minimal() con Helvetica, quita
# la grilla menor, pinta los textos con los grises ink e ink2, pone en negrita los nombres de
# los paneles y deja un margen derecho algo mayor. base fija el tamaño de letra en puntos.
theme_pub <- function(base = 10) theme_minimal(base_size = base, base_family = "Helvetica") +
  theme(panel.grid.minor = element_blank(), axis.text = element_text(colour = ink2), axis.title = element_text(colour = ink),
        legend.text = element_text(colour = ink), legend.title = element_text(colour = ink),
        strip.text = element_text(face = "bold", colour = ink), plot.margin = margin(6, 10, 6, 6))

# ---- Figura: estudios por año y bloque ----------------------------------------------
# yr cuenta los estudios por año y bloque principal. El factor con los niveles de block_nice
# fija el orden de las pilas y de la leyenda, del bloque más grande al más chico.
yr <- inc %>% count(year, main_block) %>% mutate(main_block = factor(main_block, levels = names(block_nice)))
# g1 dibuja barras apiladas por año, con un segmento por bloque y un borde blanco entre
# segmentos. ggplot apila el primer nivel arriba, en el mismo orden de la leyenda.
g1 <- ggplot(yr, aes(x = year, y = n, fill = main_block)) +
  geom_col(width = 0.82, colour = "white", linewidth = 0.3) +
  # Los colores salen de pal según el nombre del bloque. La leyenda muestra el nombre del
  # bloque y su número de estudios; ggplot asigna esas etiquetas por posición, en el orden de
  # los niveles, y calzan con block_nice porque todos los bloques tienen estudios.
  scale_fill_manual(values = pal, labels = sprintf("%s (%d)", block_nice, block_n[names(block_nice)]), name = NULL) +
  # El eje x marca cada tres años desde 2005 y deja 0,6 años de aire a cada lado.
  scale_x_continuous(breaks = seq(2005, 2026, 3), expand = expansion(add = 0.6)) +
  # Las barras parten del eje, sin aire bajo cero, y quedan con un 4 % de aire arriba.
  scale_y_continuous(expand = expansion(mult = c(0, 0.04))) +
  # Los rótulos de los ejes van en inglés.
  labs(x = "Publication year", y = "Included studies") +
  # La figura deja solo las líneas de referencia horizontales, que ayudan a leer los conteos,
  # y pone la leyenda a la derecha con cuadros chicos.
  theme_pub() + theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.3),
                      legend.position = "right", legend.key.size = unit(0.42, "cm"))
# Guarda la figura de 7,4 x 3,4 pulgadas en PDF vectorial (cairo_pdf) y en PNG a 300 dpi con
# fondo blanco, porque theme_minimal() deja el fondo transparente.
ggsave("results/figures/studies_per_year.pdf", g1, width = 7.4, height = 3.4, device = cairo_pdf)
ggsave("results/figures/studies_per_year.png", g1, width = 7.4, height = 3.4, dpi = 300, bg = "white")
# La tabla de la figura tiene una fila por año y una columna por bloque, con 0 donde no hay
# estudios. El script ordena por main_block antes de pivot_wider() para que las columnas
# sigan el orden de block_nice.
write_csv(yr %>% arrange(main_block) %>% pivot_wider(names_from = main_block, values_from = n, values_fill = 0) %>% arrange(year),
          "results/tables/studies_per_year.csv")

# ---- Perfil de caracteres por bloque (proporción de estudios del bloque) -------------
# prof_cols elige las columnas binarias que muestra el perfil y les da su nombre en inglés, y
# grp dice a qué grupo pertenece cada una, en el mismo orden (8 criterios, 10 familias
# algorítmicas, 6 estructuras de solución, 6 operadores y la disponibilidad de código). La
# lista deja fuera los códigos "other", que no describen un rasgo concreto, y varios códigos
# de pocos estudios, como tabu, ratchet, IBEA o PDG.
prof_cols <- c(crit_parsimony = "Parsimony", crit_likelihood = "Likelihood", crit_bayesian = "Bayesian",
               crit_distance = "Distance", crit_coalescent = "Coalescent", crit_quartet = "Quartets",
               crit_net_parsimony = "Network parsimony", crit_pseudolikelihood = "Pseudo-likelihood",
               alg_hill_climb = "Hill climbing", alg_exact = "Exact", alg_mcmc = "MCMC",
               alg_ga_ea = "Evolutionary", alg_memetic = "Memetic", alg_sa = "Simulated annealing",
               alg_swarm = "Swarm", alg_divide_conquer = "Divide and conquer", alg_ml = "Machine learning",
               alg_nsga2 = "NSGA-II",
               rep_tree = "Trees", rep_matrix = "Matrices", rep_split = "Splits", rep_cluster = "Clusters",
               rep_network = "Networks", rep_quartet = "Quartets/triplets",
               ops_nni = "NNI", ops_spr = "SPR", ops_tbr = "TBR", ops_crossover = "Crossover",
               ops_consensus = "Consensus", ops_nj_init = "NJ start",
               soft_yes = "Available")
grp <- c(rep("Criterion", 8), rep("Algorithm", 10), rep("Solution structure", 6), rep("Operator", 6), "Code")
# La primera instrucción descarta las columnas que no existen en inc (un código que ningún
# estudio usa no genera columna en 05_verification.R). La segunda recorta grp al largo de
# prof_cols; como la condición con "| TRUE" vale siempre, grp queda bien alineado solo si las
# columnas que faltan están al final de la lista. Con la codificación actual existen las 31.
prof_cols <- prof_cols[names(prof_cols) %in% names(inc)]; grp <- grp[names(prof_cols) %in% names(inc) | TRUE][seq_along(prof_cols)]
# grp_of da el grupo de cada columna a partir de su nombre.
grp_of <- setNames(grp, names(prof_cols))
# overall es la proporción de estudios de todo el corpus que tienen cada rasgo, y feat_order
# recorre los grupos en el orden de grp y ordena los rasgos de cada uno por overall.
# Dentro de cada grupo, los rasgos van de mayor a menor frecuencia en todo el corpus
overall <- colMeans(inc[, names(prof_cols)], na.rm = TRUE)
feat_order <- unlist(lapply(unique(grp), function(g) { v <- names(prof_cols)[grp_of == g]; v[order(-overall[v])] }))
# prof tiene una fila por bloque y rasgo, con la proporción de estudios del bloque que tienen
# el rasgo (la media de una columna 0/1). Los factores fijan el orden de la figura: los
# rasgos según feat_order, los grupos en orden fijo y los bloques al revés de block_nice,
# porque el eje y dibuja el primer nivel abajo y así el bloque más grande queda arriba.
prof <- inc %>% group_by(main_block) %>% summarise(n = n(), across(all_of(names(prof_cols)), ~ mean(.x, na.rm = TRUE))) %>%
  pivot_longer(-c(main_block, n), names_to = "code", values_to = "prop") %>%
  mutate(feature = factor(prof_cols[code], levels = prof_cols[feat_order]),
         group = factor(grp_of[code], levels = c("Criterion", "Algorithm", "Solution structure", "Operator", "Code")),
         block = factor(block_nice[main_block], levels = rev(block_nice)))
# g2 es un mapa de calor de bloques por rasgos. Cada celda muestra el porcentaje sin
# decimales cuando llega al 5 %, y las celdas con menos quedan sin número para no recargar
# la figura.
g2 <- ggplot(prof, aes(x = feature, y = block, fill = prop)) +
  geom_tile(colour = "white", linewidth = 0.7) +
  geom_text(aes(label = ifelse(prop >= 0.05, sprintf("%.0f", 100 * prop), "")), size = 2.2, colour = ink) +
  # La escala de color es secuencial y de un solo tono, del casi blanco al azul de la paleta,
  # y sus límites fijos entre 0 y 1 hacen que un mismo color signifique lo mismo en todas las
  # celdas.
  scale_fill_gradient(low = "#F5F8FC", high = "#7CB6F1", limits = c(0, 1), labels = scales::percent, name = "Studies") +
  # facet_grid() arma un panel por grupo. Con scales y space libres, cada panel muestra solo
  # sus rasgos y su ancho es proporcional al número de rasgos, así que todas las celdas tienen
  # el mismo ancho.
  facet_grid(. ~ group, scales = "free_x", space = "free_x") +
  labs(x = NULL, y = NULL) +
  # La figura usa letra base de 9 puntos, inclina 50 grados los rótulos del eje x y quita la
  # grilla. legend.key.height ajusta la altura de la barra de colores, y strip.clip = "off"
  # deja que el título de un panel angosto, como "Code", sobresalga sin cortarse.
  theme_pub(9) + theme(axis.text.x = element_text(angle = 50, hjust = 1), panel.grid = element_blank(),
                       legend.key.height = unit(0.45, "cm"), strip.clip = "off")
# Guarda la figura de 10 x 4,1 pulgadas en PDF y PNG, y la tabla larga de proporciones por
# bloque y código.
ggsave("results/figures/character_profile.pdf", g2, width = 10, height = 4.1, device = cairo_pdf)
ggsave("results/figures/character_profile.png", g2, width = 10, height = 4.1, dpi = 300, bg = "white")
write_csv(prof %>% select(main_block, n, code, prop), "results/tables/character_profile.csv")

# ---- Tablas resumen ------------------------------------------------------------------
# type_tab cuenta los tipos de aporte por bloque, con una fila por bloque (en el orden de
# block_nice), una columna por tipo y 0 donde no hay estudios. La segunda instrucción ordena
# las columnas de tipo de mayor a menor total.
type_tab <- inc %>% mutate(main_block = factor(main_block, levels = names(block_nice))) %>% count(main_block, type) %>%
  pivot_wider(names_from = type, values_from = n, values_fill = 0)
type_tab <- type_tab[, c("main_block", names(sort(colSums(type_tab[, -1]), decreasing = TRUE)))]
write_csv(type_tab, "results/tables/type_by_block.csv"); print(type_tab)
# soft_tab da, para cada bloque, el número de estudios y la proporción con software
# disponible y con dos o más objetivos.
soft_tab <- inc %>% mutate(main_block = factor(main_block, levels = names(block_nice))) %>% group_by(main_block) %>%
  summarise(n = n(), software = mean(soft_yes), two_or_more_objectives = mean(obj_mo))
write_csv(soft_tab, "results/tables/software_by_block.csv"); print(soft_tab)
# venues cuenta los estudios por revista o congreso. str_to_title() unifica las mayúsculas,
# porque WoS escribe muchos títulos en mayúscula y Scopus no, y así cada revista cuenta una
# sola vez (a cambio, siglas como IEEE quedan como "Ieee"). El script muestra en la consola
# las 15 más frecuentes.
venues <- inc %>% mutate(journal = str_to_title(journal)) %>% count(journal, sort = TRUE)
write_csv(venues, "results/tables/venues.csv"); print(head(venues, 15))
# El script informa el rango y la mediana de los años de publicación, y el número de estudios
# con DOI.
cat("Años:", range(inc$year), " mediana:", median(inc$year), "\n")
cat("Estudios con DOI:", sum(!is.na(inc$doi)), "\n")

# ---- Matriz completa de métodos (un estudio por fila) -----------------------------
# mat tiene una fila por estudio con los campos que describen su método, con nombres de
# columna explícitos en inglés y el bloque principal con su nombre largo. Como main_block ya
# es texto, arrange() ordena las filas alfabéticamente por bloque y después por año y primer
# autor.
mat <- inc %>% transmute(id, label, first_author, year, title, journal, doi, main_block = block_nice[main_block],
                         type, categories = cat, criteria = crit, algorithm = alg, solution_structure = rep,
                         operators = ops, objectives = nobj, data, software = soft,
                         method_name = name, note, search_blocks = blocks, databases = dbs, screening_round = round, cited) %>%
  arrange(main_block, year, first_author)
write_csv(mat, "results/tables/methods_matrix_all_studies.csv")

# ---- Resúmenes por bloque para la redacción ------------------------------------------
# El bucle escribe un archivo de texto por bloque en results/digests/ (por ejemplo, mo.txt)
# con lo que los autores usaron al redactar: la frecuencia de cada código, los 45 estudios
# más citados y los 20 más citados entre los publicados desde 2023. Los cortes solo acotan
# el largo de cada resumen y no afectan ningún resultado.
for (b in names(block_nice)) {
  # d reúne los estudios del bloque, que son los que lo tienen como bloque principal o entre
  # sus categorías. La expresión "(^|;)b(;|$)" busca el código completo en la lista separada
  # por ";", para que mo no coincida con morpho.
  d <- inc %>% filter(main_block == b | str_detect(cat, paste0("(^|;)", b, "(;|$)")))
  # Abre el archivo del bloque en UTF-8.
  con <- file(sprintf("results/digests/%s.txt", b), open = "w", encoding = "UTF-8")
  # La primera línea dice cuántos estudios tienen la categoría y cuántos la tienen como
  # bloque principal.
  writeLines(sprintf("BLOCK %s: %d studies with the category, %d as main block", b, nrow(d), sum(inc$main_block == b)), con)
  # El bucle interno escribe una línea por campo con la frecuencia de cada código, de mayor a
  # menor (código=n).
  for (f in c("type", "crit", "alg", "rep", "ops", "nobj", "dsd", "data", "soft")) {
    v <- sort(table(unlist(str_split(d[[f]], ";"))), decreasing = TRUE)
    writeLines(sprintf("%s: %s", f, paste(sprintf("%s=%d", names(v), v), collapse = ", ")), con)
  }
  # La sección TOP CITED lista los 45 estudios más citados, con el título recortado a 90
  # caracteres y sus códigos.
  writeLines("\nTOP CITED:", con)
  top <- d %>% arrange(desc(cited)) %>% head(45)
  for (i in seq_len(nrow(top))) writeLines(sprintf("%s %s %d c=%s [%s] %s | name=%s | %s | crit=%s alg=%s rep=%s ops=%s", top$id[i], top$first_author[i], top$year[i], top$cited[i], top$type[i], substr(top$title[i], 1, 90), top$name[i], top$note[i], top$crit[i], top$alg[i], top$rep[i], top$ops[i]), con)
  # La sección RECENT lista los 20 estudios más citados entre los publicados desde 2023.
  writeLines("\nRECENT (2023-2026):", con)
  rec <- d %>% filter(year >= 2023) %>% arrange(desc(cited)) %>% head(20)
  for (i in seq_len(nrow(rec))) writeLines(sprintf("%s %s %d c=%s [%s] %s | name=%s | %s", rec$id[i], rec$first_author[i], rec$year[i], rec$cited[i], rec$type[i], substr(rec$title[i], 1, 90), rec$name[i], rec$note[i]), con)
  close(con)
}
# reviews.txt lista los estudios de tipo review, ordenados por año, con su revista y sus
# categorías. La variable rev tapa el nombre de la función base::rev, pero no causa
# problemas: R busca solo funciones cuando el código llama a rev(), y el script ya no la
# llama después de esta línea.
rev <- inc %>% filter(type == "review") %>% arrange(year)
con <- file("results/digests/reviews.txt", open = "w", encoding = "UTF-8")
for (i in seq_len(nrow(rev))) writeLines(sprintf("%s %s %d c=%s | %s | %s | %s", rev$id[i], rev$first_author[i], rev$year[i], rev$cited[i], rev$title[i], rev$journal[i], rev$cat[i]), con)
close(con)
cat("Listo\n")  # avisa que el script terminó
