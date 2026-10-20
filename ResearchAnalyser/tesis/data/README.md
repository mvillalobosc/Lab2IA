# tesis/data/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la base del módulo Tesis y memorias de [ResearchAnalyser](../../README.md). La página lee `data.js`; los CSV son la fuente que se edita, y los Excel son el origen desde el que el conversor en R arma esos CSV.

| Archivo | Qué es |
|---|---|
| `memorias.csv` | Los trabajos de título: 898 filas y 20 columnas separadas por coma, en UTF-8 sin BOM. |
| `academicos.csv` | Los académicos: 59 filas con `ACADEMICO`, `CORREO` e `IMAGEN` (URL de la foto en `informatica.usach.cl`). |
| `data.js` | Empaqueta los dos CSV en `window.MEMORIAS_CSV` y `window.ACADEMICOS_CSV` para que la app funcione con doble clic. Hoy su contenido es idéntico a los dos CSV. |
| `MEMORIAS_ALUMNOS_2015_2025.xlsx` | Excel de origen de los trabajos. La hoja `DATOS` tiene las mismas 898 filas y 20 columnas que `memorias.csv`; trae además las hojas `INFO_ACADEMICOS` y `EXTRA`, que el conversor no lee. |
| `academicos.xlsx` | Excel de origen de los académicos (hoja `academicos`, 59 filas). |
| `Conversor_tesis_v2.R` | Lee los dos Excel, escribe `memorias.csv` y `academicos.csv` con coma como separador y luego `data.js`. Se ejecuta con `Rscript Conversor_tesis_v2.R` dentro de esta carpeta y requiere el paquete `readxl`. |

Hay dos formas de regenerar `data.js`, y las dos lo sobrescriben:

- después de editar los CSV, `python regenerar_datos.py` dentro de `tesis/`;
- después de editar los Excel, `Rscript Conversor_tesis_v2.R` dentro de esta carpeta, que además reescribe los dos CSV.

El separador tiene que ser la coma porque el lector de la app (`parseCSV` en `../app_init.js`) solo corta por coma; el conversor lo fuerza por esa razón y avisa si encuentra celdas con punto y coma. Para corregir enlaces y áreas sin editar el CSV a mano está `gestor_tesis.html`, en [../../herramientas/](../../herramientas/).

### Columnas de `memorias.csv`

| Columna | Contenido |
|---|---|
| `ESTUDIANTE` | Nombre del o la estudiante. |
| `PREGRADO`, `MODALIDAD`, `POSGRADO` | Programa de pregrado, jornada (`DIURNA` o `VESPERTINA`, a veces vacía) y programa de posgrado si corresponde. |
| `PROFESOR GUIA`, `PROFESOR COGUIA` | Guía y co-guía del trabajo. |
| `TITULO`, `ANIO PUBLICACION` | Título y año. Los años van de 2015 a 2025 y 56 filas no tienen año. |
| `LICENCIA`, `AUTORIZACION`, `¿EXISTE RESUMEN?`, `CHECKLIST` | Campos administrativos del registro. |
| `RESUMEN`, `KEYWORDS` | Resumen y palabras clave. |
| `ENLACE` | Enlace al repositorio; 790 filas tienen una URL. |
| `UNIVERSIDAD`, `DEPARTAMENTO` | Unidad a la que pertenece el trabajo. |
| `AREA_APLICACION`, `AREA_CONOCIMIENTO`, `AREA_SWEBOK` | Las tres clasificaciones de área que usa la app. |

Las dos bases traen datos personales (nombres de estudiantes, correos y fotos de académicos); el [README del proyecto](../../README.md) resume lo que dice la licencia al respecto.

## English

This folder holds the database of the Theses and projects module of [ResearchAnalyser](../../README.md). The page reads `data.js`; the CSV files are the source that gets edited, and the Excel files are the origin from which the R converter builds those CSV files.

| File | What it is |
|---|---|
| `memorias.csv` | The degree projects: 898 rows and 20 comma-separated columns, in UTF-8 without BOM. |
| `academicos.csv` | The academics: 59 rows with `ACADEMICO`, `CORREO` and `IMAGEN` (photo URL on `informatica.usach.cl`). |
| `data.js` | Packs both CSV files into `window.MEMORIAS_CSV` and `window.ACADEMICOS_CSV` so that the app works with a double click. Its content is currently identical to both CSV files. |
| `MEMORIAS_ALUMNOS_2015_2025.xlsx` | Source Excel file for the projects. Its `DATOS` sheet has the same 898 rows and 20 columns as `memorias.csv`; it also holds the `INFO_ACADEMICOS` and `EXTRA` sheets, which the converter does not read. |
| `academicos.xlsx` | Source Excel file for the academics (sheet `academicos`, 59 rows). |
| `Conversor_tesis_v2.R` | Reads both Excel files, writes `memorias.csv` and `academicos.csv` with a comma separator and then `data.js`. Run it with `Rscript Conversor_tesis_v2.R` inside this folder; it needs the `readxl` package. |

There are two ways to regenerate `data.js`, and both overwrite it:

- after editing the CSV files, `python regenerar_datos.py` inside `tesis/`;
- after editing the Excel files, `Rscript Conversor_tesis_v2.R` inside this folder, which also rewrites both CSV files.

The separator has to be a comma because the app's reader (`parseCSV` in `../app_init.js`) only splits on commas; the converter enforces it for that reason and warns when it finds cells with semicolons. To correct links and areas without editing the CSV by hand, use `gestor_tesis.html` in [../../herramientas/](../../herramientas/).

### Columns of `memorias.csv`

| Column | Contents |
|---|---|
| `ESTUDIANTE` | Student name. |
| `PREGRADO`, `MODALIDAD`, `POSGRADO` | Undergraduate programme, schedule (`DIURNA` or `VESPERTINA`, sometimes empty) and graduate programme when there is one. |
| `PROFESOR GUIA`, `PROFESOR COGUIA` | Supervisor and co-supervisor of the project. |
| `TITULO`, `ANIO PUBLICACION` | Title and year. Years range from 2015 to 2025, and 56 rows have no year. |
| `LICENCIA`, `AUTORIZACION`, `¿EXISTE RESUMEN?`, `CHECKLIST` | Administrative fields of the record. |
| `RESUMEN`, `KEYWORDS` | Abstract and keywords. |
| `ENLACE` | Repository link; 790 rows hold a URL. |
| `UNIVERSIDAD`, `DEPARTAMENTO` | Unit the project belongs to. |
| `AREA_APLICACION`, `AREA_CONOCIMIENTO`, `AREA_SWEBOK` | The three area classifications used by the app. |

Both databases contain personal data (student names, academics' email addresses and photos); the [project README](../../README.md) summarises what the licence says about it.
