# tools

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el script que genera las dos bases de datos del dashboard. El dashboard no lo necesita para funcionar: solo hace falta cuando cambia la encuesta. Para el contexto general, revisa el [README del proyecto](../README.md).

| Archivo | Qué es |
|---|---|
| `preparar_datos.R` | Lee la encuesta y los límites regionales y escribe `data/bd_encuesta.js` y `data/bd_regiones.js`. |
| `regiones.json` | Límites de las 16 regiones de Chile en GeoJSON, los mismos que usaba el dashboard Shiny. |
| `data_encuesta_filtrado.xlsx` | La encuesta, con una fila por persona. No viene en el repositorio: hay que copiarla aquí. El `.gitignore` de la raíz la ignora para que no se suba por error. |

### Uso

El script necesita R con los paquetes `readxl` y `jsonlite`, y se corre desde la carpeta del dashboard, la que tiene `index.html`:

```bash
Rscript tools/preparar_datos.R
Rscript tools/preparar_datos.R ruta/a/otra_encuesta.xlsx
```

Al terminar muestra un informe con el número de encuestados, de enfermedades y de regiones, y el tamaño de los dos archivos.

### Qué hace

1. **Catálogo.** El comienzo del script define qué columna de la encuesta alimenta cada cifra y qué código lleva cada respuesta. Esos códigos son las claves con que `js/textos.js` traduce las respuestas.
2. **Controles.** Si la encuesta trae una columna que falta, una respuesta que no está en el catálogo o una región desconocida, el script se detiene y dice cuál es. Ninguna respuesta se pierde ni se agrupa sin aviso.
3. **Conteos.** Para cada enfermedad y cada región cuenta las respuestas de cada pregunta y calcula el porcentaje sobre quienes respondieron. Las personas sin respuesta se cuentan aparte.
4. **Red.** Cuenta cuántas personas declaran cada par de enfermedades.
5. **Mapa.** Proyecta y simplifica los límites regionales para que el archivo pese 88 KB en vez de casi 900 KB.

Las fórmulas son las del dashboard Shiny original, con la corrección de la pregunta V114 que explica el README del proyecto.

## English

This folder holds the script that builds the two databases of the dashboard. The dashboard does not need it to work: it is only required when the survey changes. For the general context, see the [project README](../README.md).

| File | What it is |
|---|---|
| `preparar_datos.R` | Reads the survey and the regional boundaries and writes `data/bd_encuesta.js` and `data/bd_regiones.js`. |
| `regiones.json` | Boundaries of the 16 regions of Chile as GeoJSON, the same ones the Shiny dashboard used. |
| `data_encuesta_filtrado.xlsx` | The survey, with one row per person. It is not in the repository: copy it here. The root `.gitignore` ignores it so it is not committed by mistake. |

### Usage

The script needs R with the `readxl` and `jsonlite` packages, and runs from the dashboard folder, the one with `index.html`:

```bash
Rscript tools/preparar_datos.R
Rscript tools/preparar_datos.R path/to/another_survey.xlsx
```

When it finishes it prints a report with the number of respondents, diseases and regions, and the size of the two files.

### What it does

1. **Catalogue.** The start of the script defines which survey column feeds each figure and which code each answer gets. Those codes are the keys that `js/textos.js` uses to translate the answers.
2. **Checks.** If the survey has a missing column, an answer that is not in the catalogue or an unknown region, the script stops and says which one. No answer is lost or grouped without notice.
3. **Counts.** For each disease and each region it counts the answers to every question and computes the percentage over the people who answered. People without an answer are counted separately.
4. **Network.** It counts how many people report each pair of diseases.
5. **Map.** It projects and simplifies the regional boundaries so the file weighs 88 KB instead of almost 900 KB.

The formulas are those of the original Shiny dashboard, with the correction of question V114 explained in the project README.
