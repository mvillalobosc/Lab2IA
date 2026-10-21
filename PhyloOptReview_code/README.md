# PhyloOptReview_code

[Español](#español) · [English](#english)

## Español

Código, datos codificados y resultados de la revisión sistemática *Phylogenetic inference as an optimisation problem: a systematic review* (Manuel Villalobos-Cid, Márcio Dorn y Mario Inostroza-Ponta; manuscrito para *Applied Soft Computing*, 2026).

La revisión sigue PRISMA 2020. Buscó en Scopus y en la Web of Science Core Collection, el 20 y el 21 de octubre de 2026, artículos y ponencias en inglés publicados entre 2005 y 2026 sobre la inferencia filogenética como problema de optimización, organizados en ocho bloques temáticos (Q1 a Q7, con Q4A y Q4B). Cada registro se cribó y codificó desde su título, palabras clave y resumen con un protocolo escrito, y el núcleo de optimización (196 estudios multiobjetivo o de búsqueda heurística monoobjetivo) se verificó con los textos completos. Con los estudios incluidos, el código construye los perfiles de cada bloque, las matrices de métodos y un árbol de la literatura inferido con Neighbour Joining sobre distancias de Jaccard.

### Cifras principales

| Etapa | Registros |
| --- | --- |
| Identificados (Scopus 7.482; Web of Science 8.021) | 15.503 |
| Duplicados eliminados | 6.666 |
| Excluidos por filtros automáticos | 258 |
| Evaluados con el protocolo (rondas 1, 2 y 3: 4.147, 3.184 y 1.248) | 8.579 |
| Incluidos en el cribado | 2.560 |
| Excluidos en la verificación del núcleo de optimización | 3 |
| Estudios incluidos | 2.557 |

La segunda lectura de 528 registros reprodujo el 98,7 % de las decisiones (kappa 0,971), y la verificación con texto completo confirmó 193 de las 196 inclusiones del núcleo.

### Estructura

```
R/                 scripts del análisis, numerados en el orden en que corren
data/raw/          cadenas de búsqueda de cada bloque y base
data/processed/    bases intermedias y finales, sin resúmenes ni palabras clave indexadas
screening/         protocolo, decisiones del cribado y segunda lectura
verification/      matrices de verificación del núcleo de optimización y correcciones
tables_curated/    matrices de métodos que publica el artículo
references/        referencias de contexto del manuscrito (BibTeX)
results/           tablas, figuras, árbol de la literatura, tablas en LaTeX y resúmenes por bloque
schemes/           diagrama PRISMA y esquema del problema en TikZ
```

Cada carpeta tiene su README con la descripción de sus archivos.

### Scripts

| Script | Qué hace |
| --- | --- |
| `00_run_all.R` | Corre los pasos 01 a 09 en orden; sin las exportaciones omite 01 y 02 |
| `01_merge.R` | Une las exportaciones, elimina duplicados por DOI y título normalizado y asigna los bloques |
| `02_screen.R` | Aplica los filtros automáticos, calcula el diccionario de descriptores y arma los lotes de las tres rondas |
| `03_merge_coding.R` | Une las decisiones del cribado, revisa los casi duplicados y asigna la etapa PRISMA de cada registro |
| `04_verify_sample.R` | Saca las muestras de la segunda lectura y mide la concordancia y el kappa |
| `05_verification.R` | Aplica la verificación del núcleo de optimización y crea los caracteres binarios de cada estudio |
| `06_literature_tree.R` | Infiere el árbol de la literatura y elige los clados destacados |
| `06_literature_tree_figure.R` | Dibuja la figura del árbol |
| `07_synthesis.R` | Hace los conteos PRISMA, las figuras de años y perfiles y las tablas de síntesis |
| `08_tables.R` | Escribe en LaTeX las tablas del artículo |
| `09_schemes.R` | Genera y compila el diagrama PRISMA y el esquema del problema |
| `10_bib.R` | Arma el `references.bib` del manuscrito (se corre aparte, con la ruta del `.tex`) |

### Cómo reproducir los resultados

Requisitos: R 4.x con `readr`, `readxl`, `dplyr`, `stringr`, `tidyr`, `jsonlite`, `ggplot2`, `scales`, `ape` y `phangorn`, y `pdflatex` (TikZ, standalone, helvet) con `pdftoppm` para los esquemas. Desde esta carpeta:

```
Rscript R/00_run_all.R
```

Las exportaciones de Scopus y Web of Science no se distribuyen, porque traen los resúmenes y las palabras clave indexadas bajo las licencias de esas bases. Sin ellas, el script parte de `data/processed/` y corre los pasos 03 a 09, que reproducen byte a byte las tablas, el árbol en Newick y JSON, las tablas en LaTeX y los resúmenes de `results/` (comprobado con R 4.3 en Linux). Con las exportaciones en `data/raw/scopus/` y `data/raw/wos/` (los nombres de archivo y las cadenas de búsqueda están en `data/raw/`), el script corre la revisión desde el principio.

El cribado, la codificación y la verificación del núcleo de optimización se hicieron con un modelo de lenguaje (Claude Opus 5.5, Anthropic, octubre de 2026) que aplicó el protocolo de `screening/protocol/`, bajo la supervisión de los autores. Las decisiones de cada registro, las segundas lecturas y la fuente de cada valor verificado están en el repositorio, así que cada etapa se puede auditar y recalcular.

### Licencia y cita

El código se distribuye con licencia MIT (`LICENSE`), y los datos codificados, los protocolos y los resultados con licencia CC BY 4.0. Si usa estos datos, cite el artículo; la referencia completa se agregará cuando se publique.

## English

Code, coded data and results of the systematic review *Phylogenetic inference as an optimisation problem: a systematic review* (Manuel Villalobos-Cid, Márcio Dorn and Mario Inostroza-Ponta; manuscript for *Applied Soft Computing*, 2026).

The review follows PRISMA 2020. It searched Scopus and the Web of Science Core Collection on 20 and 21 October 2026 for articles and conference papers in English published between 2005 and 2026 on phylogenetic inference as an optimisation problem, organised in eight thematic blocks (Q1 to Q7, with Q4A and Q4B). Each record was screened and coded from its title, keywords and abstract with a written protocol, and the optimisation core (196 multi-objective or single-objective heuristic search studies) was verified with the full texts. With the included studies, the code builds the profile of each block, the methods matrices and a literature tree inferred with Neighbour Joining on Jaccard distances.

### Headline numbers

| Stage | Records |
| --- | --- |
| Identified (Scopus 7,482; Web of Science 8,021) | 15,503 |
| Duplicates removed | 6,666 |
| Excluded by automated filters | 258 |
| Assessed with the protocol (rounds 1, 2 and 3: 4,147, 3,184 and 1,248) | 8,579 |
| Included at screening | 2,560 |
| Excluded by the verification of the optimisation core | 3 |
| Included studies | 2,557 |

The second screening of 528 records reproduced 98.7% of the decisions (kappa 0.971), and the full-text verification confirmed 193 of the 196 inclusions of the optimisation core.

### Layout

```
R/                 analysis scripts, numbered in execution order
data/raw/          search strings of each block and database
data/processed/    intermediate and final databases, without abstracts or indexed keywords
screening/         protocol, screening decisions and second screening
verification/      verification matrices of the optimisation core and corrections
tables_curated/    methods matrices published in the paper
references/        background references of the manuscript (BibTeX)
results/           tables, figures, literature tree, LaTeX tables and digests per block
schemes/           PRISMA diagram and problem scheme in TikZ
```

Each folder has a README that describes its files.

### Scripts

| Script | Purpose |
| --- | --- |
| `00_run_all.R` | Runs steps 01 to 09 in order; without the exports it skips 01 and 02 |
| `01_merge.R` | Merges the exports, removes duplicates by DOI and normalised title and assigns the blocks |
| `02_screen.R` | Applies the automated filters, computes the descriptor dictionary and builds the batches of the three rounds |
| `03_merge_coding.R` | Merges the screening decisions, reviews near-duplicates and assigns the PRISMA stage of each record |
| `04_verify_sample.R` | Draws the second-screening samples and computes the agreement and kappa |
| `05_verification.R` | Applies the verification of the optimisation core and builds the binary characters of each study |
| `06_literature_tree.R` | Infers the literature tree and selects the highlighted clades |
| `06_literature_tree_figure.R` | Draws the tree figure |
| `07_synthesis.R` | Computes the PRISMA counts, the year and profile figures and the synthesis tables |
| `08_tables.R` | Writes the tables of the paper in LaTeX |
| `09_schemes.R` | Generates and compiles the PRISMA diagram and the problem scheme |
| `10_bib.R` | Builds the `references.bib` of the manuscript (run separately, with the path of the `.tex`) |

### Reproducing the results

Requirements: R 4.x with `readr`, `readxl`, `dplyr`, `stringr`, `tidyr`, `jsonlite`, `ggplot2`, `scales`, `ape` and `phangorn`, and `pdflatex` (TikZ, standalone, helvet) with `pdftoppm` for the schemes. From this folder:

```
Rscript R/00_run_all.R
```

The Scopus and Web of Science exports are not distributed, since they contain abstracts and indexed keywords under the licences of those databases. Without them, the script starts from `data/processed/` and runs steps 03 to 09, which reproduce byte for byte the tables, the tree in Newick and JSON, the LaTeX tables and the digests in `results/` (checked with R 4.3 on Linux). With the exports in `data/raw/scopus/` and `data/raw/wos/` (file names and search strings are described in `data/raw/`), the script runs the review from the beginning.

Screening, coding and the verification of the optimisation core were carried out with a large language model (Claude Opus 5.5, Anthropic, October 2026) applying the protocol in `screening/protocol/`, under the supervision of the authors. The decision for each record, the second screenings and the source of each verified value are included, so every stage can be audited and recomputed.

### Licence and citation

The code is released under the MIT licence (`LICENSE`), and the coded data, protocols and results under CC BY 4.0. Please cite the paper when using these data; the full reference will be added once it is published.
