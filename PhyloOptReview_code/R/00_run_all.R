# =============================================================================
# 00_run_all.R
# Ejecuta la revisión completa, en orden, desde la carpeta raíz del repositorio:
#   Rscript R/00_run_all.R
#
# Estructura del repositorio
#   R/                 scripts del análisis; este archivo ejecuta los pasos 01 a 09 en orden
#                      01_merge.R                  une las exportaciones y elimina duplicados
#                      02_screen.R                 aplica los filtros automáticos y arma los lotes
#                      03_merge_coding.R           une las decisiones y asigna las etapas PRISMA
#                      04_verify_sample.R          mide la confiabilidad del cribado asistido
#                      05_verification.R           aplica la verificación y crea los caracteres
#                      06_literature_tree.R        infiere el árbol y elige los clados destacados
#                      06_literature_tree_figure.R dibuja la figura del árbol (PDF y PNG)
#                      07_synthesis.R              hace los conteos PRISMA y la síntesis descriptiva
#                      08_tables.R                 escribe las tablas del manuscrito en LaTeX
#                      09_schemes.R                genera y compila los esquemas en TikZ
#                      10_bib.R                    arma references.bib y se ejecuta aparte
#   data/raw/          cadenas de búsqueda textuales de cada bloque y base (search_strings.csv);
#                      las exportaciones de Scopus (CSV) y Web of Science (XLS) de los ocho
#                      bloques, descargadas el 20 de octubre de 2026 (Q1 a Q6) y el 21 de
#                      octubre de 2026 (Q7), no se distribuyen y van en data/raw/scopus y
#                      data/raw/wos para correr la revisión desde el principio
#   data/processed/    bases intermedias y finales, sin la columna abstract: unificada
#                      (db_unique), filtrada (db_screened), con etapa PRISMA de cada registro
#                      (db_final_all) e incluidos codificados (db_included_coded)
#   screening/         cribado asistido: protocolo e instrucciones (protocol/), decisiones en
#                      JSONL (output/) y segunda lectura independiente para medir la
#                      confiabilidad (reliability/); los lotes de entrada (input/) traen los
#                      resúmenes y 02_screen.R los vuelve a crear desde las exportaciones
#   verification/      matrices de verificación del núcleo de optimización (fuentes en las
#                      columnas source y evidence), duplicados revisados y correcciones
#   tables_curated/    matrices condensadas que se publican en el artículo
#   references/        referencias de contexto verificadas (BibTeX)
#   results/           figuras, tablas, árbol de la literatura (Newick, JSON, PDF, PNG),
#                      tablas en LaTeX y resúmenes por bloque
#   schemes/           esquemas en TikZ: diagrama PRISMA y esquema del problema
#
# El cribado asistido y la verificación del núcleo de optimización se hicieron con un
# modelo de lenguaje (Claude Opus 5.5, Anthropic) siguiendo screening/protocol/. Sus
# salidas están en el repositorio, de modo que este script reproduce el resto de la
# revisión sin repetir esos pasos.
#
# Requisitos: R (4.x) con readr, readxl, dplyr, stringr, tidyr, jsonlite, ggplot2,
# scales, ape y phangorn; pdflatex (TikZ, standalone, helvet) y pdftoppm para los
# esquemas. La revisión completa corre en pocos minutos.
# =============================================================================
# steps enumera los scripts en el orden en que se ejecutan; 10_bib.R no está en la lista porque
# necesita la ruta del manuscrito como argumento.
steps <- c("01_merge.R", "02_screen.R", "03_merge_coding.R", "04_verify_sample.R", "05_verification.R",
           "06_literature_tree.R", "06_literature_tree_figure.R", "07_synthesis.R", "08_tables.R", "09_schemes.R")
# Cada script corre en su propio proceso de R (Rscript), con un entorno limpio, igual que si se
# ejecutara por separado. system2 devuelve el código de salida del proceso, y si un paso falla el
# ciclo se detiene para no seguir con resultados incompletos.
# Las exportaciones de Scopus y Web of Science no se distribuyen, porque traen los resúmenes y
# los metadatos bajo las licencias de esas bases. Sin ellas, el script omite 01_merge.R y
# 02_screen.R, que las leen, y parte de las bases de data/processed/, que ya traen todo lo que
# usan los pasos siguientes salvo la columna abstract. Con las exportaciones en data/raw/scopus
# y data/raw/wos, el script corre la revisión completa desde el principio.
if (!dir.exists("data/raw/scopus") || !dir.exists("data/raw/wos")) {
  cat("Sin las exportaciones en data/raw/: se omiten 01_merge.R y 02_screen.R\n")
  steps <- setdiff(steps, c("01_merge.R", "02_screen.R"))
}
for (s in steps) {
  cat("==>", s, "\n")  # muestra el paso en curso
  status <- system2("Rscript", file.path("R", s))
  if (status != 0) stop("Falló ", s)
}
# Al terminar, el script recuerda cómo regenerar references.bib, que depende del manuscrito.
cat("Para regenerar references.bib: Rscript R/10_bib.R <ruta del manuscrito .tex>\n")
