# PhyloGEOYeast

[Español](#español) · [English](#english)

## Español

PhyloGEOYeast es un explorador interactivo de los análisis filogeográficos de *Saccharomyces eubayanus* y *S. cerevisiae*. La app reúne el muestreo geográfico, la diversidad y la estructura genética, la mezcla, los árboles y las comprobaciones que se usan para evaluar la inferencia del origen.

La interfaz está en castellano, inglés y portugués. La carpeta guarda dos cosas: la app web estática, que es un solo `index.html` con la interfaz, los resultados de los análisis y sus librerías de JavaScript, y el pipeline en R que produce esos resultados, con una carpeta por especie.

### Ejecutar la app localmente

No hay que instalar paquetes ni compilar nada.

1. Clona o descarga este repositorio.
2. Desde la carpeta `PhyloGEOYeast/`, levanta un servidor web local:

   ```bash
   python3 -m http.server 8000
   ```

3. Abre <http://localhost:8000> en un navegador actual.

También puedes abrir `index.html` directamente con doble clic, aunque el servidor local da un comportamiento más parejo entre navegadores. Solo el mapa base de OpenStreetMap necesita internet: la app, sus librerías (Leaflet 1.9.4 y D3 7.9.0) y los resultados van dentro del HTML. El archivo pesa 16 MB, así que tarda unos segundos en abrir.

La app guarda en el navegador (`localStorage`) el idioma, la especie, la escala, el tema claro u oscuro y el modo de diversidad (claves `eub_lang`, `eub_especie`, `eub_escala`, `eub_tema` y `eub_corr`).

### Publicar con GitHub Pages

1. Sube los cambios a la rama por defecto del repositorio.
2. En la configuración del repositorio, abre **Pages**.
3. Elige publicar desde una rama, selecciona la rama por defecto y la raíz del repositorio, y guarda.
4. Abre la URL que muestra GitHub y agrégale `PhyloGEOYeast/` al final, porque la app vive en esta carpeta del repositorio.

El punto de entrada debe seguir llamándose `index.html` dentro de la carpeta publicada.

### Recorrer la app

- Elige una especie y una escala de análisis: Localidad, Localidad × linaje o Linaje. Las dos especies traen las tres escalas.
- Busca una cepa, un lugar o un gen para ubicarlo en el mapa y en las vistas vinculadas.
- Revisa el muestreo geográfico, la diversidad, la estructura poblacional, la mezcla, las distancias genéticas, los árboles y las comprobaciones de método.
- Usa la ayuda de cada vista para ver definiciones y cómo interpretarlas.
- Descarga en JSON los datos del conjunto activo, o el árbol de poblaciones en Newick, cuando necesites revisar lo que muestra la app.

### Leer los resultados con cuidado

El mapa combina observaciones y estimaciones con distinta resolución geográfica. La app informa un origen solo cuando las comprobaciones de validación lo respaldan; si la evidencia no identifica un origen, la app lo dice, y el lugar con mayor diversidad observada puede aparecer como referencia descriptiva, que no se debe leer como una ubicación ancestral inferida. En los resultados que trae esta versión, la validación declara válido el origen solo en el conjunto de *S. eubayanus* a escala Localidad × linaje; en los otros cinco conjuntos lo declara no válido, y la app lo muestra así.

Un punto puede representar una localidad, una región o un país, y algunas asignaciones geográficas son aproximadas. Los orígenes faltantes que se infieren desde el lugar más frecuente de un linaje se marcan aparte y quedan fuera de los cálculos. El enraizamiento de los árboles y las vistas temporales también tienen supuestos declarados: una raíz dibujada no establece por sí sola la dirección ni fechas de calendario. Antes de interpretar o reutilizar un resultado, revisa la pestaña **Método y reproducibilidad** de la app y sus notas explicativas.

### Pipeline en R

Las carpetas [EvolutiveEubayanus_CODE/](EvolutiveEubayanus_CODE/) y [EvolutiveSCerevisiae_CODE/](EvolutiveSCerevisiae_CODE/) tienen el mismo pipeline de 20 scripts. Diecinueve son idénticos byte a byte entre las dos carpetas; solo cambia `00_config.R`, en 11 líneas que fijan los archivos de entrada, la especie y algunos parámetros. El pipeline responde dónde estuvo el ancestro común de las cepas muestreadas y en qué orden se colonizó el rango actual, y por eso su unidad de análisis es el grupo geográfico.

El código usa solo R base. El paquete `rstudioapi` es opcional y sirve para ubicar la carpeta del script o lanzar la corrida como Job desde RStudio. El manifiesto de los resultados que trae la app registra R 4.3.3.

**Entradas.** Cada script espera una carpeta `DATA/` dentro de la carpeta de la especie con el VCF, la metadata de las cepas y las coordenadas de los sitios. Esos archivos no están en el repositorio. El README de cada carpeta indica los nombres exactos y las columnas que se leen.

**Cómo se corre.** Hay que lanzarlo desde la carpeta de la especie:

```bash
cd PhyloGEOYeast/EvolutiveEubayanus_CODE
Rscript 99_correr_todo.R 01 12    # pipeline completo, en los tres escenarios
Rscript 99_correr_todo.R 06 09    # solo un tramo de pasos
```

`00_config.R` quedó con `PASO_DESDE <- "16"` y `PASO_HASTA <- "16"`. Con esos valores, `Rscript 99_correr_todo.R` sin argumentos corre solo el paso 16 en cada escenario, y ese paso necesita los intermedios de una corrida anterior. Para la corrida completa pasa `01 12` como arriba, o cambia los dos valores a `"01"` y `"12"`.

**Escenarios y salidas.** `99_correr_todo.R` recorre tres escenarios definidos en `00_config.R` y deja cada uno en `resultados/<escenario>/`:

| Escenario | Grupo de análisis | Qué se usa de esta corrida | Escala en la app |
|---|---|---|---|
| `sitio` | `Site`, fusionando grupos que comparten coordenada | Mapa y superficie de origen | Localidad |
| `sitio_linaje` | `Site` + `Population`, sin las cepas `Admix` | Diversidad dentro de linaje con geografía | Localidad × linaje |
| `linaje` | `Population` | Árbol de linajes, f3 y tiempos de divergencia | Linaje |

**Relación con la app.** `index.html` trae embebidos los resultados de seis corridas (dos especies por tres escenarios) y el texto de los 20 scripts, que muestra en la pestaña de método. El repositorio no incluye un paso que convierta `resultados/` en esos datos embebidos, así que una corrida nueva no actualiza la app por sí sola. Además, el código que muestra la app difiere del de las carpetas en tres scripts: en `00_config.R` la app trae el tramo `01` a `12`; en `15_asignacion.R` cambia la comparación que marca una asignación como correcta; y en `16_marcadores.R` la app trae una versión más larga, que normaliza los nombres de cromosoma entre la anotación y el VCF y busca las columnas de inicio y fin de cada gen.

### Datos y atribución

El equipo del proyecto generó y curó los datos y análisis de *S. eubayanus*. El mismo equipo preparó y analizó el conjunto de comparación de *S. cerevisiae* con sus datos asociados al estudio de 1.011 aislados de Peter et al. (2018). La publicación se mantiene citada como fuente de ese estudio y de su recurso:

> Peter, J. et al. (2018). Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature*, 556(7701), 339-344. <https://doi.org/10.1038/s41586-018-0030-5>

Al reutilizar análisis o figuras, cita el manuscrito asociado y las referencias originales de su bibliografía. La pestaña **Método y reproducibilidad** de la app documenta el procesamiento de datos, los procedimientos de análisis, los supuestos y el código que representa la interfaz.

### Contenido de la carpeta

```text
PhyloGEOYeast/
├── index.html                    App completa: interfaz, resultados embebidos y código del cliente
├── README.md                     Este archivo
├── EvolutiveEubayanus_CODE/      Pipeline en R configurado para S. eubayanus (20 scripts)
└── EvolutiveSCerevisiae_CODE/    El mismo pipeline configurado para S. cerevisiae (20 scripts)
```

### Licencia

Aquí no se declara una licencia de software. Antes de distribuir o reutilizar el código bajo términos de licencia, los responsables del proyecto deben agregar la licencia que elijan como un archivo `LICENSE` aparte.

## English

PhyloGEOYeast is an interactive explorer of the phylogeographic analyses of *Saccharomyces eubayanus* and *S. cerevisiae*. The app brings together geographic sampling, genetic diversity and structure, admixture, trees, and checks used to evaluate origin inference.

The interface is available in Spanish, English, and Portuguese. The folder holds two things: the static web app, a single self-contained `index.html` with the interface, bundled analysis results, and its JavaScript libraries, and the R pipeline that produces those results, with one folder per species.

### Run locally

No package installation or build step is required.

1. Clone or download this repository.
2. From the `PhyloGEOYeast/` folder, start a local web server:

   ```bash
   python3 -m http.server 8000
   ```

3. Open <http://localhost:8000> in a modern browser.

You can also open `index.html` directly in a browser, although a local server gives more consistent behavior across browsers. Only the OpenStreetMap basemap needs internet access: the app, its libraries (Leaflet 1.9.4 and D3 7.9.0), and the results are bundled in the HTML file. The file is 16 MB, so it takes a few seconds to open.

The app stores the language, species, scale, light or dark theme, and diversity mode in the browser (`localStorage` keys `eub_lang`, `eub_especie`, `eub_escala`, `eub_tema`, and `eub_corr`).

### Publish with GitHub Pages

1. Push the changes to the repository's default branch.
2. In the repository settings, open **Pages**.
3. Select deployment from a branch, choose the default branch and the repository root, and save.
4. Open the Pages URL shown by GitHub and add `PhyloGEOYeast/` at the end, because the app lives in this folder of the repository.

The entry point must remain named `index.html` in the published folder.

### Explore the app

- Choose a species and analysis scale: Locality, Locality × lineage, or Lineage. Both species include the three scales.
- Search for a strain, place, or gene to locate it on the map and in the linked views.
- Explore geographic sampling, diversity, population structure, admixture, genetic distances, trees, and methodological checks.
- Use the help controls in each view for definitions and interpretation.
- Download the data of the active set as JSON, or the population tree as Newick, when you need to inspect the displayed data.

### Reading results carefully

The map combines observations and estimates at different geographic resolutions. The app reports an origin only when the validation checks support it; if the evidence does not identify an origin, the app says so, and the location of highest observed diversity may appear as a descriptive reference that must not be read as an inferred ancestral location. In the results bundled with this version, the validation accepts the origin only for the *S. eubayanus* set at the Locality × lineage scale; it rejects it in the other five sets, and the app shows it that way.

A point may represent a locality, region, or country, and some geographic assignments are approximate. Missing origins inferred from a lineage's most frequent location are marked separately and are excluded from calculations. Tree rooting and temporal displays also have stated assumptions; a visual root does not by itself establish direction or calendar dates. Consult the in-app **Method & reproducibility** tab and the explanatory notes before interpreting or reusing a result.

### R pipeline

The [EvolutiveEubayanus_CODE/](EvolutiveEubayanus_CODE/) and [EvolutiveSCerevisiae_CODE/](EvolutiveSCerevisiae_CODE/) folders hold the same 20-script pipeline. Nineteen scripts are byte-identical between the two folders; only `00_config.R` changes, in 11 lines that set the input files, the species, and a few parameters. The pipeline asks where the common ancestor of the sampled strains lived and in what order the current range was colonised, so its unit of analysis is the geographic group.

The code uses base R only. The `rstudioapi` package is optional: it helps locate the script folder or launch the run as an RStudio Job. The manifest of the results bundled in the app records R 4.3.3.

**Inputs.** Every script expects a `DATA/` folder inside the species folder with the VCF, the strain metadata, and the site coordinates. These files are not in the repository. The README of each folder gives the exact file names and the columns that are read.

**How to run it.** Launch it from the species folder:

```bash
cd PhyloGEOYeast/EvolutiveEubayanus_CODE
Rscript 99_correr_todo.R 01 12    # full pipeline, in the three scenarios
Rscript 99_correr_todo.R 06 09    # only a range of steps
```

`00_config.R` was left with `PASO_DESDE <- "16"` and `PASO_HASTA <- "16"`. With those values, `Rscript 99_correr_todo.R` without arguments runs only step 16 in each scenario, and that step needs the intermediate files of an earlier run. For the full run, pass `01 12` as above, or change both values to `"01"` and `"12"`.

**Scenarios and outputs.** `99_correr_todo.R` loops over three scenarios defined in `00_config.R` and writes each one to `resultados/<scenario>/`:

| Scenario | Analysis group | What this run is used for | Scale in the app |
|---|---|---|---|
| `sitio` | `Site`, merging groups that share a coordinate | Map and origin surface | Locality |
| `sitio_linaje` | `Site` + `Population`, without the `Admix` strains | Within-lineage diversity with geography | Locality × lineage |
| `linaje` | `Population` | Lineage tree, f3, and divergence times | Lineage |

**Relation to the app.** `index.html` bundles the results of six runs (two species by three scenarios) and the text of the 20 scripts, which it shows in the method tab. The repository does not include a step that turns `resultados/` into that bundled data, so a new run does not update the app by itself. The code shown in the app also differs from the code in the folders in three scripts: in `00_config.R` the app has the `01` to `12` step range; in `15_asignacion.R` the comparison that marks an assignment as correct changes; and in `16_marcadores.R` the app has a longer version that harmonises chromosome names between the annotation and the VCF and searches for the start and end columns of each gene.

### Data and attribution

The *S. eubayanus* data and analyses in this project were generated and curated by the project team. The *S. cerevisiae* comparison dataset was prepared and analysed by the same team using the team's data associated with the 1,011-isolate study by Peter et al. (2018). The publication remains cited as the source of that study and its underlying resource:

> Peter, J. et al. (2018). Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature*, 556(7701), 339-344. <https://doi.org/10.1038/s41586-018-0030-5>

Please cite the associated manuscript and the original references listed in its bibliography when reusing analyses or figures. The app's **Method & reproducibility** tab documents the data processing, analytical procedures, assumptions, and code represented in the interface.

### Folder contents

```text
PhyloGEOYeast/
├── index.html                    Self-contained app, bundled data, and client-side code
├── README.md                     This file
├── EvolutiveEubayanus_CODE/      R pipeline configured for S. eubayanus (20 scripts)
└── EvolutiveSCerevisiae_CODE/    The same pipeline configured for S. cerevisiae (20 scripts)
```

### License

No software license is declared here. Add the license selected by the project owners as a separate `LICENSE` file before distributing or reusing the code under license terms.
