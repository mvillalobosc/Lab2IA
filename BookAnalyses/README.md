# Pipeline de progresión textual (BookAnalyses)

[Español](#español) · [English](#english)

## Español

### Qué es esto

Este pipeline en R analiza las obras narrativas de las listas de lecturas sugeridas del currículum chileno de Lenguaje y Comunicación, de 1° básico a 4° medio (niveles 1 a 12). Construye el corpus desde `datos/Principal_guia.xlsx`, empareja cada obra con su PDF por el número de catálogo (el prefijo del archivo, tipo `0639_Chorlitos en la cabeza.pdf`), anota los textos con udpipe y calcula legibilidad, diversidad léxica, sintaxis de dependencias, sentimiento y emociones, keyness léxico, agrupamiento semántico con LSA y tópicos con STM. Después corre la estadística por nivel (Kruskal-Wallis, Dunn, Jonckheere-Terpstra y GAM) y un modelo ordinal que marca los libros cuyo perfil no calza con el nivel que tienen asignado. Cada obra que se excluye queda registrada con su motivo en un log.

La versión `2026-08-19-b` (`config$version_pipeline`) es la que produjo los números del manuscrito: 577 observaciones obra-nivel, 527 obras únicas y 26,6 millones de palabras (la suma de `n_palabras` en `resultados/tablas/metricas_maestras_por_libro.csv`).

### Qué hay en cada carpeta

| Ruta | Contenido |
|---|---|
| [config.R](config.R) | Los parámetros del pipeline (rutas, columnas del catálogo, filtros, umbrales y semilla). Es el único archivo que hay que editar. |
| [run_all.R](run_all.R) | Corre los tests unitarios y después los módulos 01 a 12, de punta a cabo. |
| [R/](R/) | Los módulos 00 a 12, las funciones de apoyo y los scripts de adquisición y diagnóstico. |
| [tests/](tests/) | Los tests unitarios de las métricas, que `run_all.R` corre antes de tocar el corpus. |
| [demo/](demo/) | El generador de un corpus sintético para probar el pipeline sin los libros. |
| [datos/](datos/) | El catálogo xlsx. Los textos van en `datos/textos/`, que no se versiona. |
| [resultados/](resultados/) | Tablas y figuras de la corrida del manuscrito, copiadas a mano desde `output/`. |

Los PDF de los libros no van en el repositorio porque tienen derechos de autor. El modelo udpipe tampoco: `R/00_setup.R` lo descarga en la primera corrida a la carpeta `models/`.

### Requisitos

- R con los paquetes que instala y carga `R/00_setup.R`: readxl, writexl, dplyr, tidyr, stringr, stringi, ggplot2, data.table, Matrix, irlba, uwot, pvclust, vegan, udpipe, syuzhet, stm, stopwords, xml2, MASS, mgcv, cluster y parallel. El script instala desde CRAN los que falten.
- Para leer PDF hace falta el paquete pdftools o, si no compila, el binario `pdftotext` de poppler (`sudo apt install poppler-utils`). Si el binario vive fuera del PATH, `config$ruta_pdftotext` lo indica.
- Hay dependencias que solo se usan en algunos casos: epubr si hay libros en EPUB, digest para los hash de duplicados (sin él se usa rlang), googledrive para `R/descarga_drive.R` y `R/paso1_listar_drive.R`, rstudioapi para lanzar la corrida como job de RStudio, y el binario `tesseract` con el idioma español (`tesseract-ocr-spa`) para que `R/emparejar_contenido.R` lea portadas escaneadas.
- La primera corrida necesita internet para instalar paquetes y bajar el modelo `spanish-gsd` de udpipe.

### Configurar el catálogo real

El `config.R` versionado apunta al demo: `ruta_xlsx = "demo/catalogo_demo.xlsx"`, `carpeta_textos = "demo/textos"` y las columnas `Titulo`, `Archivo` y `Curso`. Para analizar el catálogo real hay que cambiar estos valores en `config.R`:

```r
ruta_xlsx      = "datos/Principal_guia.xlsx",
hoja_xlsx      = "Libros",
carpeta_textos = "datos/textos",
col_titulo  = "Obra",
col_archivo = NA,
col_nivel   = "Cursos",
col_autor   = "Autor",
col_numero  = "N°",
filtros_mantener = list(Conseguido = "Sí"),
filtros_excluir_regex = list(`Género` = "Poemas|Textos no literarios|Lírica|Drama|Ensayo"),
pvclust_nboot  = 1000,
```

La hoja `Libros` tiene 1.826 obras. Los dos filtros dejan las 689 obras conseguidas que no son poesía, drama, ensayo ni textos no literarios (las celdas vacías de `Género` se conservan, como explica el comentario de `config.R`), y la expansión de las obras que aparecen en más de un curso las convierte en 721 filas obra-nivel. Son las mismas 721 filas de `resultados/tablas/mapeo_archivos.csv`, de modo que esta configuración reproduce el catálogo de la corrida archivada. El repositorio no guarda el `config.R` de esa corrida; el valor 1000 de `pvclust_nboot` sale del propio comentario de `config.R`, que lo pide para la versión final.

### Qué hacer, en orden

1. Textos: con `config.R` apuntando al catálogo real, dejar los PDF en `datos/textos`. Si no están, cualquiera de estos dos scripts los trae a `config$carpeta_textos` (por eso conviene cambiar la configuración antes):

    ```r
    source("R/paso0_traer_textos.R")   # desde el zip bajado de la web de Drive
    source("R/descarga_drive.R")       # directo desde la carpeta de Drive (config$drive_url)
    ```

    `R/paso1_listar_drive.R` solo lista la carpeta de Drive, sin bajar nada. El enlace de la carpeta no está en el repositorio: `config.R` lo lee de la variable de entorno `BOOKANALYSES_DRIVE_URL`, que se define una vez, por ejemplo con una línea en `~/.Renviron`, antes de abrir R. Sin ella, los dos scripts de Drive se detienen con un mensaje que lo explica.

2. Prevuelo de un minuto, que confirma el emparejamiento antes de quemar horas:

    ```r
    source("R/prevuelo.R")
    ```

    Con el catálogo real debe decir unas 700 obras con archivo y veredicto OK. Si el emparejamiento falla, `source("R/diagnostico.R")` muestra por qué, y `Rscript R/emparejar_contenido.R` empareja por el contenido de cada archivo (metadatos del PDF y primeras páginas) y guarda sus decisiones en `mapeo_confirmado.csv`, junto al catálogo.

3. La corrida completa, como job de RStudio para no secuestrar la consola:

    ```r
    rstudioapi::jobRunScript("run_all.R", name = "pipeline_lecturas",
                             workingDir = getwd())
    ```

    Desde una terminal, en la carpeta del proyecto, sirve `Rscript run_all.R`. Antes de lanzar conviene subir `ncores` en `config.R` a los núcleos del servidor. La primera corrida instala paquetes, baja el modelo udpipe y anota los 577 libros (horas con un núcleo, mucho menos con 8); las siguientes retoman del caché en minutos.

4. Resultados: quedan en `output/` (`config$carpeta_salida`). Las tablas van a `output/tablas`, las figuras en PDF y PNG a `output/figuras`, y los logs a `output/logs`: cada libro excluido con su motivo en `log_exclusiones.csv`, más `log_advertencias.csv`, `pipeline.log` y `sessionInfo.txt`. El módulo 12 consolida las tablas en `output/resultados_maestros.xlsx` y escribe un resumen en `output/resumen.md`. `run_all.R` no escribe en `resultados/`.

### Para probar sin los libros

```bash
Rscript demo/genera_corpus_demo.R
Rscript run_all.R
```

El primer comando crea 36 libros sintéticos en `demo/textos/` y el catálogo `demo/catalogo_demo.xlsx`. Como el `config.R` versionado ya apunta al demo, el segundo corre el pipeline completo sobre ese corpus en unos 5 minutos.

### Control de versiones

El `.gitignore` de la raíz del repositorio Lab2IA ignora `datos/textos/`, `output/`, `models/`, `demo/textos/`, `demo/catalogo_demo.xlsx` y los zip de Drive (`drive-download*.zip` y `Libros*.zip`) que queden en la carpeta del proyecto, así que los libros, las salidas, el modelo y el corpus de demo no se suben aunque estén en la carpeta. `mapeo_confirmado.csv` no está ignorado, porque guarda decisiones de emparejamiento revisadas a mano.

### Los números del paper

Las tablas de `resultados/tablas` son las del manuscrito: `estadistica_kw_jt_completo.csv` (Kruskal-Wallis, Jonckheere-Terpstra con 2000 permutaciones, epsilon cuadrado y Cliff), `estadistica_gam_por_metrica.csv` y `gam_predicciones.csv` (trayectorias), `libros_desajustados.csv` (predicción de nivel y screening) y `metricas_maestras_por_libro.csv` (las métricas de cada obra, el listado que promete el apéndice). Correr `run_all.R` sobre los textos regenera estas tablas en `output/tablas` con la misma semilla (`config$semilla`). Ningún script del repositorio produce las ocho figuras de `resultados/figuras_paper/`. [resultados/README.md](resultados/README.md) da el detalle.

### Autoría y licencia

El código se distribuye con licencia MIT ([LICENSE](LICENSE)), que no cubre los textos de los libros. El proyecto no trae archivo de cita y ningún archivo nombra el manuscrito asociado.

## English

### What this is

This R pipeline analyses the narrative works in the suggested reading lists of the Chilean Language and Communication curriculum, from 1st grade of primary to the last year of secondary school (grades 1 to 12). It builds the corpus from `datos/Principal_guia.xlsx`, matches each work with its PDF through the catalogue number (the file name prefix, as in `0639_Chorlitos en la cabeza.pdf`), annotates the texts with udpipe and computes readability, lexical diversity, dependency syntax, sentiment and emotions, lexical keyness, semantic clustering with LSA and topics with STM. It then runs the per-grade statistics (Kruskal-Wallis, Dunn, Jonckheere-Terpstra and GAM) and an ordinal model that flags the books whose profile does not match their assigned grade. Every work that gets excluded is recorded with its reason in a log.

Version `2026-08-19-b` (`config$version_pipeline`) is the one that produced the numbers in the manuscript: 577 work-grade observations, 527 unique works and 26.6 million words (the sum of `n_palabras` in `resultados/tablas/metricas_maestras_por_libro.csv`).

### What each folder holds

| Path | Contents |
|---|---|
| [config.R](config.R) | The pipeline parameters (paths, catalogue columns, filters, thresholds and seed). It is the only file you need to edit. |
| [run_all.R](run_all.R) | Runs the unit tests and then modules 01 to 12, end to end. |
| [R/](R/) | Modules 00 to 12, the helper functions and the acquisition and diagnostic scripts. |
| [tests/](tests/) | Unit tests for the metrics, which `run_all.R` runs before touching the corpus. |
| [demo/](demo/) | Generator of a synthetic corpus to test the pipeline without the books. |
| [datos/](datos/) | The catalogue workbook. The texts go in `datos/textos/`, which is not versioned. |
| [resultados/](resultados/) | Tables and figures from the manuscript run, copied by hand from `output/`. |

The book PDFs are not in the repository because they are under copyright. Neither is the udpipe model: `R/00_setup.R` downloads it to `models/` on the first run.

### Requirements

- R with the packages that `R/00_setup.R` installs and loads: readxl, writexl, dplyr, tidyr, stringr, stringi, ggplot2, data.table, Matrix, irlba, uwot, pvclust, vegan, udpipe, syuzhet, stm, stopwords, xml2, MASS, mgcv, cluster and parallel. The script installs any missing ones from CRAN.
- Reading PDFs needs the pdftools package or, if it does not compile, the poppler `pdftotext` binary (`sudo apt install poppler-utils`). If the binary lives outside the PATH, `config$ruta_pdftotext` points to it.
- Some dependencies are only used in specific cases: epubr if there are EPUB books, digest for the duplicate hashes (rlang is used without it), googledrive for `R/descarga_drive.R` and `R/paso1_listar_drive.R`, rstudioapi to launch the run as an RStudio job, and the `tesseract` binary with the Spanish language pack (`tesseract-ocr-spa`) so that `R/emparejar_contenido.R` can read scanned covers.
- The first run needs internet access to install packages and download the udpipe `spanish-gsd` model.

### Configuring the real catalogue

The versioned `config.R` points to the demo: `ruta_xlsx = "demo/catalogo_demo.xlsx"`, `carpeta_textos = "demo/textos"` and the columns `Titulo`, `Archivo` and `Curso`. To analyse the real catalogue, change these values in `config.R`:

```r
ruta_xlsx      = "datos/Principal_guia.xlsx",
hoja_xlsx      = "Libros",
carpeta_textos = "datos/textos",
col_titulo  = "Obra",
col_archivo = NA,
col_nivel   = "Cursos",
col_autor   = "Autor",
col_numero  = "N°",
filtros_mantener = list(Conseguido = "Sí"),
filtros_excluir_regex = list(`Género` = "Poemas|Textos no literarios|Lírica|Drama|Ensayo"),
pvclust_nboot  = 1000,
```

The `Libros` sheet holds 1,826 works. The two filters keep the 689 obtained works that are not poetry, drama, essays or non-literary texts (empty `Género` cells are kept, as the comment in `config.R` explains), and expanding the works listed for more than one grade turns them into 721 work-grade rows. These are the same 721 rows found in `resultados/tablas/mapeo_archivos.csv`, so this configuration reproduces the catalogue of the archived run. The repository does not keep the `config.R` used for that run; the value 1000 for `pvclust_nboot` comes from the comment in `config.R`, which asks for it in the final version.

### What to do, in order

1. Texts: with `config.R` pointing to the real catalogue, put the PDFs in `datos/textos`. If they are not there, either of these scripts brings them into `config$carpeta_textos` (which is why the configuration should be changed first):

    ```r
    source("R/paso0_traer_textos.R")   # from the zip downloaded from the Drive web page
    source("R/descarga_drive.R")       # straight from the Drive folder (config$drive_url)
    ```

    `R/paso1_listar_drive.R` only lists the Drive folder, without downloading anything. The folder link is not in the repository: `config.R` reads it from the `BOOKANALYSES_DRIVE_URL` environment variable, which is set once, for example with a line in `~/.Renviron`, before starting R. Without it, both Drive scripts stop with a message that explains this.

2. One-minute preflight, which confirms the matching before burning hours:

    ```r
    source("R/prevuelo.R")
    ```

    With the real catalogue it should report about 700 works with a file and an OK verdict. If matching fails, `source("R/diagnostico.R")` shows why, and `Rscript R/emparejar_contenido.R` matches by the content of each file (PDF metadata and first pages) and stores its decisions in `mapeo_confirmado.csv`, next to the catalogue.

3. The full run, as an RStudio job so it does not take over the console:

    ```r
    rstudioapi::jobRunScript("run_all.R", name = "pipeline_lecturas",
                             workingDir = getwd())
    ```

    From a terminal, inside the project folder, `Rscript run_all.R` does the same. Before launching, raise `ncores` in `config.R` to the number of server cores. The first run installs packages, downloads the udpipe model and annotates the 577 books (hours on one core, much less on 8); later runs resume from the cache in minutes.

4. Results: they end up in `output/` (`config$carpeta_salida`). Tables go to `output/tablas`, PDF and PNG figures to `output/figuras`, and logs to `output/logs`: every excluded book with its reason in `log_exclusiones.csv`, plus `log_advertencias.csv`, `pipeline.log` and `sessionInfo.txt`. Module 12 gathers the tables into `output/resultados_maestros.xlsx` and writes a summary to `output/resumen.md`. `run_all.R` does not write to `resultados/`.

### Testing without the books

```bash
Rscript demo/genera_corpus_demo.R
Rscript run_all.R
```

The first command creates 36 synthetic books in `demo/textos/` and the catalogue `demo/catalogo_demo.xlsx`. Since the versioned `config.R` already points to the demo, the second one runs the full pipeline on that corpus in about 5 minutes.

### Version control

The `.gitignore` at the root of the Lab2IA repository ignores `datos/textos/`, `output/`, `models/`, `demo/textos/`, `demo/catalogo_demo.xlsx` and the Drive zips (`drive-download*.zip` and `Libros*.zip`) left in the project folder, so the books, the outputs, the model and the demo corpus are not uploaded even if they sit in the folder. `mapeo_confirmado.csv` is not ignored, because it stores matching decisions reviewed by hand.

### The numbers in the paper

The tables in `resultados/tablas` are the ones in the manuscript: `estadistica_kw_jt_completo.csv` (Kruskal-Wallis, Jonckheere-Terpstra with 2000 permutations, epsilon squared and Cliff), `estadistica_gam_por_metrica.csv` and `gam_predicciones.csv` (trajectories), `libros_desajustados.csv` (grade prediction and screening) and `metricas_maestras_por_libro.csv` (the metrics of each work, the listing promised in the appendix). Running `run_all.R` on the texts regenerates these tables in `output/tablas` with the same seed (`config$semilla`). No script in the repository produces the eight figures in `resultados/figuras_paper/`. [resultados/README.md](resultados/README.md) has the details.

### Authorship and licence

The code is distributed under the MIT licence ([LICENSE](LICENSE)), which does not cover the book texts. The project has no citation file and no file names the associated manuscript.
