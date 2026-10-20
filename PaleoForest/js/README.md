# js/

[Español](#español) · [English](#english)

## Español

Esta carpeta contiene toda la lógica de [PaleoForest](../README.md), escrita en JavaScript nativo sin dependencias externas ni empaquetador. Los archivos se cargan como scripts clásicos (no como módulos ES) y comparten variables globales, así que el orden de carga en cada página importa:

| Página | Scripts, en el orden en que se cargan |
|---|---|
| `index.html` | `i18n.js`, `i18n-inf.js`, `cite.js`, `hub.js` |
| `inferencia.html` | `i18n.js`, `i18n-inf.js`, `cite.js`, `tour.js`, `pipeline.js`, `search.js`, `search-pool.js`, `mk.js`, `../data/arackar/dataset.js`, `inferencia.js` |
| `pipeline.html` | `geoscale.js`, `i18n.js`, `i18n-inf.js`, `cite.js`, `tour.js`, `pipeline.js`, `paleodb.js`, `macrostrat.js`, `../data/arackar/dataset.js`, `app.js` |

### Archivos

| Archivo | Qué hace |
|---|---|
| `hub.js` | Dibuja la portada, que lleva al módulo 1 (`inferencia.html`) o al módulo 2 (`pipeline.html`), y guarda el idioma en `localStorage` con la clave `pf_lang`. |
| `inferencia.js` | Controla el módulo 1: estado, editor de la matriz, configuración de caracteres, búsqueda, resultados y exportación. Al pulsar el botón para enviar al módulo 2 escribe los árboles en `localStorage` con la clave `pf_handoff` y abre `pipeline.html?from=inferencia`. |
| `search.js` | Implementa el motor de parsimonia: árboles iniciales por adición aleatoria (Wagner), Neighbor Joining o al azar, rearreglos NNI, SPR y TBR con búfer de meseta, ratchet, fusión de árboles, consensos y soporte de biparticiones. No toca el DOM, así que corre dentro de un Web Worker. |
| `search-pool.js` | Reparte las réplicas entre varios Web Workers creados con la ruta `js/search-worker.js`, relativa a la página. Si el navegador no permite crear un Worker (algunos lo impiden bajo `file://`), la búsqueda corre en el hilo principal. |
| `search-worker.js` | Código de cada hilo de búsqueda. Carga `search.js` con `importScripts` (ruta relativa al propio worker) y devuelve los árboles encontrados. |
| `mk.js` | Calcula la verosimilitud Mk/Mkv (Lewis 2001) de los árboles que la parsimonia ya encontró, para ordenar una meseta de árboles empatados. No busca árboles. |
| `pipeline.js` | Núcleo numérico del módulo 2, adaptado del pipeline de medoides en R: lector de Newick, distancias Robinson-Foulds, PCA y MDS, los siete métodos de agrupamiento, índices de evaluación, hipervolumen, medoides y soporte. También trae los lectores TNT que usa el módulo 1. |
| `app.js` | Controla el módulo 2: interfaz, pasos del análisis, visualizaciones (bosque, árboles, temporalidad) y exportaciones. Al abrirse lee y borra `pf_handoff`. Al inicio define el bloque `UX` con textos propios en castellano, inglés y portugués (ayudas, recorrido guiado, glosario y atajos). |
| `paleodb.js` | Cliente de la Paleobiology Database: busca ocurrencias y rangos temporales por taxón y empareja nombres por distancia de edición, como el pipeline original en R. |
| `macrostrat.js` | Cliente de Macrostrat: busca la edad de una formación o unidad estratigráfica cuando PaleoDB no tiene el taxón. |
| `geoscale.js` | Define la escala de tiempo geológico ICS/IUGS v2023 (eón, era, período, época y piso) con sus colores oficiales y rangos en millones de años, más alias para las variantes que aparecen en los CSV de edades. |
| `i18n.js` | Diccionario ES/EN/PT del módulo 2 y de los elementos compartidos, banderas en SVG, logo y la constante `PAPER` con la referencia del artículo. |
| `i18n-inf.js` | Diccionario ES/EN/PT de la portada y del módulo 1, más la constante `ARACKAR` con la procedencia del conjunto de ejemplo. |
| `cite.js` | Arma el pie de referencias que comparten la portada y los módulos, con la cita y el BibTeX del artículo. |
| `tour.js` | Recorrido guiado genérico (`PFTour`) que usan los dos módulos. |

Los textos de la interfaz están repartidos en tres lugares: `i18n.js`, `i18n-inf.js` y el bloque `UX` de `app.js`. Cada clave debe existir en los tres idiomas.

## English

This folder holds all the logic of [PaleoForest](../README.md), written in plain JavaScript with no external dependencies and no bundler. The files load as classic scripts (not ES modules) and share global variables, so the loading order of each page matters:

| Page | Scripts, in loading order |
|---|---|
| `index.html` | `i18n.js`, `i18n-inf.js`, `cite.js`, `hub.js` |
| `inferencia.html` | `i18n.js`, `i18n-inf.js`, `cite.js`, `tour.js`, `pipeline.js`, `search.js`, `search-pool.js`, `mk.js`, `../data/arackar/dataset.js`, `inferencia.js` |
| `pipeline.html` | `geoscale.js`, `i18n.js`, `i18n-inf.js`, `cite.js`, `tour.js`, `pipeline.js`, `paleodb.js`, `macrostrat.js`, `../data/arackar/dataset.js`, `app.js` |

### Files

| File | What it does |
|---|---|
| `hub.js` | Draws the landing page, which leads to module 1 (`inferencia.html`) or module 2 (`pipeline.html`), and stores the language in `localStorage` under the `pf_lang` key. |
| `inferencia.js` | Runs module 1: state, matrix editor, character settings, search, results and export. When the user clicks the button that sends trees to module 2, it writes them to `localStorage` under the `pf_handoff` key and opens `pipeline.html?from=inferencia`. |
| `search.js` | Implements the parsimony engine: random-addition (Wagner), Neighbor Joining or random starting trees, NNI, SPR and TBR rearrangements with a plateau buffer, ratchet, tree fusing, consensus trees and bipartition support. It does not touch the DOM, so it runs inside a Web Worker. |
| `search-pool.js` | Spreads the replicates over several Web Workers created from the path `js/search-worker.js`, relative to the page. When the browser does not allow a Worker (some block it under `file://`), the search runs on the main thread. |
| `search-worker.js` | Code of each search thread. It loads `search.js` through `importScripts` (a path relative to the worker itself) and returns the trees it finds. |
| `mk.js` | Computes the Mk/Mkv likelihood (Lewis 2001) of the trees that parsimony already found, to rank a plateau of tied trees. It does not search for trees. |
| `pipeline.js` | Numerical core of module 2, ported from the R medoid pipeline: Newick reader, Robinson-Foulds distances, PCA and MDS, the seven clustering methods, evaluation indices, hypervolume, medoids and support. It also holds the TNT readers that module 1 uses. |
| `app.js` | Runs module 2: interface, analysis steps, visualisations (forest, trees, time-scaling) and exports. When it opens, it reads and deletes `pf_handoff`. At the top it defines the `UX` block with its own Spanish, English and Portuguese texts (help, guided tour, glossary and shortcuts). |
| `paleodb.js` | Paleobiology Database client: it searches occurrences and temporal ranges by taxon and matches names by edit distance, as the original R pipeline did. |
| `macrostrat.js` | Macrostrat client: it looks up the age of a formation or stratigraphic unit when PaleoDB lacks the taxon. |
| `geoscale.js` | Defines the ICS/IUGS v2023 geological time scale (eon, era, period, epoch and stage) with its official colours and ranges in millions of years, plus aliases for the variants found in age CSV files. |
| `i18n.js` | ES/EN/PT dictionary of module 2 and the shared elements, SVG flags, logo and the `PAPER` constant with the article reference. |
| `i18n-inf.js` | ES/EN/PT dictionary of the landing page and module 1, plus the `ARACKAR` constant with the provenance of the example dataset. |
| `cite.js` | Builds the references footer shared by the landing page and the modules, with the article citation and BibTeX. |
| `tour.js` | Generic guided tour (`PFTour`) used by both modules. |

Interface texts live in three places: `i18n.js`, `i18n-inf.js` and the `UX` block of `app.js`. Every key must exist in all three languages.
