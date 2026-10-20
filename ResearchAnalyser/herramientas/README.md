# herramientas/

[Español](#español) · [English](#english)

## Español

Estas herramientas de [ResearchAnalyser](../README.md) arman y corrigen las bases que leen los módulos. Cada HTML es autónomo: trae su propio CSS y JavaScript, no carga nada de `lib/` ni de `shared/`, se abre con doble clic y lee los Excel por su cuenta, sin librerías. Las dos páginas escriben en una carpeta del disco con la File System Access API (Chrome o Edge); en otros navegadores entregan los resultados como descargas.

| Archivo | Qué hace |
|---|---|
| `procesador.html` | Arma `BD_papers.csv` y su `data.js` para el módulo Publicaciones a partir de una carpeta `BD/` con exportaciones de Scopus y Web of Science, la lista de académicos y la base SJR de Scimago. Versión que declara: 2026-07-26 23:14. |
| `gestor_tesis.html` | Abre el `data.js` de `tesis/data/`, el Excel o un CSV, y permite editar como planilla los enlaces y las áreas de los trabajos de título. Versión que declara: 2026-07-27 00:20. |
| `configurar_ollama.bat` | Script de Windows que deja a Ollama aceptar peticiones de estas páginas. |

### procesador.html

La herramienta espera una carpeta `BD/` con esta forma; los nombres de ejemplo son los que muestra la propia página:

```text
BD/
├── BASE/
│   ├── lista_academicos.xlsx (o .csv)
│   └── SJR_revistas_1999_2025.xlsx
├── DIINF/
│   ├── SCOPUS/   Scopus - Villalobos - 55114462200.csv
│   └── WOS/      WOS - 55114462200 - AFK-0866-2022.xlsx
├── CBIOT/
└── BIOMEDICA/
```

El número al final de cada nombre es el identificador de Scopus del académico, y la herramienta lo usa para asignar cada archivo a su persona; el botón "Arreglar nombres de Web of Science" agrega ese número a los archivos de Web of Science que no lo traen. Los pasos de la página son estos:

1. Carpeta BD: se elige la carpeta, con o sin permisos de escritura.
2. Diagnóstico: revisa lo que hay en el disco y lo que le falta a cada académico.
3. Base SJR: si no está en `BD/BASE`, intenta descargarla de Scimago o recibe los archivos anuales que se bajen a mano, y los une en `SJR_revistas_<desde>_<hasta>.csv` dentro de `BD/BASE`.
4. Académicos: se marcan los que se procesan; los que no tienen CSV de Scopus no se pueden procesar.
5. Proceso: lee los CSV de Scopus, los cruza con Web of Science y con la base SJR, calcula la marca WoS, deduce los países, reutiliza las áreas de un `BD_papers.csv` anterior si se le entrega y deduplica.
6. Resultado: descarga `BD_papers.csv` y `data.js`, o los escribe en `BD/SALIDA`.

Para las publicaciones que no venían en la base anterior, la sección "Clasificación de áreas" pide a un modelo local de Ollama (por defecto `llama3.1:8b` en `http://localhost:11434`, con `/api/generate`) las áreas de computación, OCDE y ODS, y "Revisar si la clasificación está bien" toma una muestra al azar para medir la tasa de error a mano. Los archivos que salen se copian luego a `../publicaciones/data/`.

### gestor_tesis.html

La página carga el `data.js` de `tesis/data/`, el Excel `MEMORIAS_ALUMNOS_2015_2025.xlsx` o un CSV, y muestra los trabajos como planilla con filtros para los que no tienen enlace o área. Solo edita la columna `ENLACE` y las tres de área (`AREA_APLICACION`, `AREA_CONOCIMIENTO`, `AREA_SWEBOK`). Acepta enlaces pegados en bloque desde Excel (dos columnas separadas por tabulación: nombre del estudiante o título, y enlace o número del repositorio) y puede clasificar con Ollama las tesis sin área usando los catálogos que ya están en los datos. Al final descarga `data.js` y el CSV, o los escribe en la carpeta `tesis/data` elegida.

### configurar_ollama.bat

Las dos páginas se abren desde el disco, y Ollama rechaza esas peticiones mientras no acepte su origen. En Windows, `configurar_ollama.bat` guarda la variable de usuario `OLLAMA_ORIGINS="*"` con `setx`, cierra y vuelve a abrir Ollama, espera a que responda en `http://localhost:11434/api/tags` y comprueba que la respuesta traiga la cabecera de autorización. No necesita permisos de administrador. El propio script advierte que con ese valor cualquier página web puede hablarle al Ollama local y explica cómo volver atrás con `setx OLLAMA_ORIGINS "null"`. En Linux o macOS basta con iniciar Ollama con `OLLAMA_ORIGINS="*" ollama serve`, como indica `procesador.html`.

## English

These [ResearchAnalyser](../README.md) tools build and correct the databases that the modules read. Each HTML file is self-contained: it carries its own CSS and JavaScript, loads nothing from `lib/` or `shared/`, opens with a double click and reads Excel files on its own, without libraries. Both pages write into a folder on disk through the File System Access API (Chrome or Edge); in other browsers they deliver the results as downloads.

| File | What it does |
|---|---|
| `procesador.html` | Builds `BD_papers.csv` and its `data.js` for the Publications module from a `BD/` folder with Scopus and Web of Science exports, the list of academics and the Scimago SJR database. Declared version: 2026-07-26 23:14. |
| `gestor_tesis.html` | Opens the `data.js` from `tesis/data/`, the Excel file or a CSV, and lets the user edit the links and areas of the degree projects as a spreadsheet. Declared version: 2026-07-27 00:20. |
| `configurar_ollama.bat` | Windows script that lets Ollama accept requests from these pages. |

### procesador.html

The tool expects a `BD/` folder with this layout; the example names are the ones the page itself shows:

```text
BD/
├── BASE/
│   ├── lista_academicos.xlsx (or .csv)
│   └── SJR_revistas_1999_2025.xlsx
├── DIINF/
│   ├── SCOPUS/   Scopus - Villalobos - 55114462200.csv
│   └── WOS/      WOS - 55114462200 - AFK-0866-2022.xlsx
├── CBIOT/
└── BIOMEDICA/
```

The number at the end of each name is the academic's Scopus identifier, and the tool uses it to assign each file to its owner; the "Arreglar nombres de Web of Science" (fix Web of Science names) button adds that number to Web of Science files that lack it. The page goes through these steps:

1. BD folder: the user picks the folder, with or without write permission.
2. Diagnosis: it checks what is on disk and what each academic is missing.
3. SJR database: when it is not in `BD/BASE`, the page tries to download it from Scimago or takes the yearly files downloaded by hand, and merges them into `SJR_revistas_<from>_<to>.csv` inside `BD/BASE`.
4. Academics: the user ticks the ones to process; those without a Scopus CSV cannot be processed.
5. Processing: it reads the Scopus CSV files, matches them with Web of Science and the SJR database, computes the WoS flag, infers countries, reuses the areas from a previous `BD_papers.csv` when one is given, and removes duplicates.
6. Result: it downloads `BD_papers.csv` and `data.js`, or writes them to `BD/SALIDA`.

For publications that were not in the previous database, the "Clasificación de áreas" (area classification) section asks a local Ollama model (by default `llama3.1:8b` at `http://localhost:11434`, through `/api/generate`) for the computing, OECD and SDG areas, and "Revisar si la clasificación está bien" (check the classification) takes a random sample so the error rate can be measured by hand. The output files are then copied to `../publicaciones/data/`.

### gestor_tesis.html

The page loads the `data.js` from `tesis/data/`, the Excel file `MEMORIAS_ALUMNOS_2015_2025.xlsx` or a CSV, and shows the projects as a spreadsheet with filters for those without a link or an area. It only edits the `ENLACE` column and the three area columns (`AREA_APLICACION`, `AREA_CONOCIMIENTO`, `AREA_SWEBOK`). It accepts links pasted in bulk from Excel (two tab-separated columns: student name or title, and link or repository number) and can classify theses without an area through Ollama, using the catalogues already present in the data. It then downloads `data.js` and the CSV, or writes them into the chosen `tesis/data` folder.

### configurar_ollama.bat

Both pages open from disk, and Ollama rejects their requests until it accepts that origin. On Windows, `configurar_ollama.bat` stores the user variable `OLLAMA_ORIGINS="*"` with `setx`, closes and reopens Ollama, waits until it answers at `http://localhost:11434/api/tags` and checks that the reply carries the authorisation header. It does not need administrator rights. The script itself warns that with this value any web page can talk to the local Ollama, and it explains how to undo it with `setx OLLAMA_ORIGINS "null"`. On Linux or macOS, start Ollama with `OLLAMA_ORIGINS="*" ollama serve`, as `procesador.html` says.
