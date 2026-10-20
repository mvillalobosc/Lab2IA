# data/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el único conjunto que viene incluido en las páginas de [PaleoForest](../README.md): *Arackar licanantay*, en `data/arackar/`. Las páginas `inferencia.html` y `pipeline.html` lo cargan con una etiqueta `<script>` que apunta a `data/arackar/dataset.js`, de modo que el ejemplo funciona también al abrir la aplicación con `file://`. El módulo 2 no lo carga solo: se activa con un botón en el paso Datos.

### `arackar/`

| Archivo | Contenido |
|---|---|
| `dataset.js` | Define `window.PF_DATA`, el conjunto listo para la aplicación (405 KB): `key`, `name`, `group`, `desc` (descripción en ES, EN y PT), `taxa` (88 nombres), `newicks` (los 97 árboles en Newick), `ages` (rango de cada taxón con `fad`, `lad`, eón, era, período, época, piso y dieta), `matrix` (88 filas de estados), `ordered` (índices, desde 0, de los 24 caracteres aditivos), `parsRef` (largo de referencia, 1322), `parsRefSrc` (nombre del archivo de árboles del que sale ese largo), `rawCcode` (bloque `ccode` original), `nTrees` y `nTaxa`. Lo escribió `tools/prep.py`. |
| `matrix.tnt` | Matriz morfológica en formato TNT (`xread`) con 405 caracteres y 88 taxones, más su bloque `ccode`. Está codificada en ISO-8859-1. |
| `trees.tre` | Los 97 árboles en formato TNT (`tread`), con los taxones como índices numéricos. Los primeros 96 son los árboles más parsimoniosos y el último es un consenso estricto, que la aplicación detecta y excluye antes de calcular las distancias. |
| `trees.nwk` | Los mismos 97 árboles en Newick, uno por línea y con los nombres de los taxones. Lo generó `tools/prep.py` desde `trees.tre`. |
| `ages.csv` | Rangos fósiles de los 88 taxones: 26 columnas separadas por `;`, en UTF-8 con BOM. Las principales son `TIPS` (taxón), `FIRST` y `LAST` (primera y última aparición, en millones de años), las unidades cronoestratigráficas de inicio y fin (`INI_EON` a `INI_AGE` y `END_EON` a `END_AGE`), datos ecológicos (`ENVIRONMENT`, `LOCOMOTION`, `DIET`), la clasificación de PBDB y `SOURCE`. |
| `meta.json` | Conteos y procedencia del conjunto (`species`, `nTrees`, `nTaxa`, `nAges`, `note`). La aplicación no lo lee. |

`meta.json` y la descripción de `dataset.js` hablan de 97 árboles más parsimoniosos porque cuentan las 97 líneas del archivo; el consenso estricto del final deja 96 árboles para el análisis. Los mismos `matrix.tnt`, `trees.tre`, `trees.nwk` y `ages.csv` están copiados en [`../examples/Arackar_licanantay/`](../examples/README.md). Para reemplazar este ejemplo hay que mantener coordinados los seis archivos; la sección 13.1 del README del proyecto y [`../tools/README.md`](../tools/README.md) explican cómo se generaron.

## English

This folder stores the only dataset bundled into the [PaleoForest](../README.md) pages: *Arackar licanantay*, in `data/arackar/`. The `inferencia.html` and `pipeline.html` pages load it with a `<script>` tag that points to `data/arackar/dataset.js`, so the example also works when the application is opened through `file://`. Module 2 does not load it by itself: a button in the Data step activates it.

### `arackar/`

| File | Contents |
|---|---|
| `dataset.js` | Defines `window.PF_DATA`, the dataset ready for the application (405 KB): `key`, `name`, `group`, `desc` (description in ES, EN and PT), `taxa` (88 names), `newicks` (the 97 trees in Newick), `ages` (range of each taxon with `fad`, `lad`, eon, era, period, epoch, stage and diet), `matrix` (88 rows of states), `ordered` (zero-based indices of the 24 additive characters), `parsRef` (reference length, 1322), `parsRefSrc` (name of the tree file that gives that length), `rawCcode` (original `ccode` block), `nTrees` and `nTaxa`. `tools/prep.py` wrote it. |
| `matrix.tnt` | Morphological matrix in TNT format (`xread`) with 405 characters and 88 taxa, plus its `ccode` block. It is encoded in ISO-8859-1. |
| `trees.tre` | The 97 trees in TNT format (`tread`), with taxa as numeric indices. The first 96 are the most parsimonious trees and the last one is a strict consensus, which the application detects and excludes before computing distances. |
| `trees.nwk` | The same 97 trees in Newick, one per line and with taxon names. `tools/prep.py` generated it from `trees.tre`. |
| `ages.csv` | Fossil ranges of the 88 taxa: 26 columns separated by `;`, in UTF-8 with a BOM. The main ones are `TIPS` (taxon), `FIRST` and `LAST` (first and last appearance, in millions of years), the start and end chronostratigraphic units (`INI_EON` to `INI_AGE` and `END_EON` to `END_AGE`), ecological data (`ENVIRONMENT`, `LOCOMOTION`, `DIET`), the PBDB classification and `SOURCE`. |
| `meta.json` | Counts and provenance of the dataset (`species`, `nTrees`, `nTaxa`, `nAges`, `note`). The application does not read it. |

`meta.json` and the description in `dataset.js` mention 97 most parsimonious trees because they count the 97 lines of the file; the strict consensus at the end leaves 96 trees for the analysis. The same `matrix.tnt`, `trees.tre`, `trees.nwk` and `ages.csv` are copied in [`../examples/Arackar_licanantay/`](../examples/README.md). Replacing this example requires keeping the six files aligned; section 13.1 of the project README and [`../tools/README.md`](../tools/README.md) explain how they were generated.
