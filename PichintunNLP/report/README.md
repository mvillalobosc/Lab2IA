# report/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda `pichintun_report.Rmd`, el informe HTML del proyecto, que lleva como autores a Ekaterina Cornejo Contreras y Manuel Villalobos Cid. El informe no recalcula nada: lee las tablas y figuras que `Rscript run_all.R` deja en `outputs/`, así que se genera en segundos y depende de que el pipeline haya corrido antes. Vuelve al [README del proyecto](../README.md) o al [README en inglés](../README.en.md).

### Cómo generarlo

Después de correr el pipeline completo, desde la carpeta del proyecto:

```bash
Rscript -e 'rmarkdown::render("report/pichintun_report.Rmd")'
```

El resultado es `report/pichintun_report.html`, un solo archivo que trae las figuras incluidas. Hacen falta knitr y rmarkdown, que no están en `PKGS_CRAN`, pandoc, que rmarkdown usa para armar el HTML, y readr, que el pipeline ya instala. El `.gitignore` no ignora el HTML, de modo que después de generarlo aparece como archivo nuevo en `git status`.

### Qué lee

| Origen | Archivos |
|---|---|
| `outputs/tables/` | `08_maestro_capitulos`, `08_maestro_temporadas`, `08_verificacion`, `07_resumen_modelos`, `04_temas_por_temporada` y `06_complejidad_temporada` |
| `outputs/figures/` | `03_composicion_lexica`, `03_nube_temporada_cultural`, `03_keyness_temporada_generico`, `03_dendro_capitulos_euclidiana`, `04_radar_temas_temporada`, `04_keyness_temas_temporada`, `05_sentimiento_temporada`, `05_tendencia_sentimiento`, `05_emociones_temporada`, `06_complejidad_temporada_p01`, `06_tendencia_lexica`, `07_importancia_rf_likes` y `07_importancia_rf_visualizaciones` |

Si falta una tabla, la generación se detiene con un error de readr. Si falta una figura, el informe la omite sin avisar.

### Secciones

El informe tiene siete secciones: Corpus, con los chequeos de integridad de la corrida; Composición léxica; Temas; Sentimiento y emociones; Complejidad y diversidad léxica; Factores asociados a la recepción, y Tabla maestra. Cuando `07_resumen_modelos.csv` marca algún modelo como sobreparametrizado, la sección sobre la recepción agrega una advertencia.

### Lo que no se actualiza solo

La cobertura temática de 94,1 % está escrita en el texto del Rmd y no se lee de las tablas, así que hay que corregirla a mano si cambian el léxico o los diálogos. Lo mismo pasa con los 16 temas, la ventana de MATTR de 200 palabras y las 34 observaciones que menciona la advertencia. De `06_complejidad_temporada` el informe incluye solo la primera página, que corresponde a la temporada 1, aunque el pie de la figura habla de cada temporada.

## English

This folder holds `pichintun_report.Rmd`, the HTML report of the project, which lists Ekaterina Cornejo Contreras and Manuel Villalobos Cid as authors. The report recomputes nothing: it reads the tables and figures that `Rscript run_all.R` leaves in `outputs/`, so it builds in seconds and depends on the pipeline having run first. Back to the [project README](../README.en.md).

### How to build it

After running the full pipeline, from the project folder:

```bash
Rscript -e 'rmarkdown::render("report/pichintun_report.Rmd")'
```

The result is `report/pichintun_report.html`, a single file with the figures embedded. It needs knitr and rmarkdown, which are not in `PKGS_CRAN`, pandoc, which rmarkdown uses to build the HTML, and readr, which the pipeline already installs. The `.gitignore` does not ignore the HTML, so after the build it shows up as a new file in `git status`.

### What it reads

| Source | Files |
|---|---|
| `outputs/tables/` | `08_maestro_capitulos`, `08_maestro_temporadas`, `08_verificacion`, `07_resumen_modelos`, `04_temas_por_temporada` and `06_complejidad_temporada` |
| `outputs/figures/` | `03_composicion_lexica`, `03_nube_temporada_cultural`, `03_keyness_temporada_generico`, `03_dendro_capitulos_euclidiana`, `04_radar_temas_temporada`, `04_keyness_temas_temporada`, `05_sentimiento_temporada`, `05_tendencia_sentimiento`, `05_emociones_temporada`, `06_complejidad_temporada_p01`, `06_tendencia_lexica`, `07_importancia_rf_likes` and `07_importancia_rf_visualizaciones` |

When a table is missing, the build stops with a readr error. When a figure is missing, the report leaves it out without a warning.

### Sections

The report has seven sections: Corpus, with the integrity checks of the run; Lexical composition; Topics; Sentiment and emotions; Complexity and lexical diversity; Factors associated with reception; and Master table. The headings are in Spanish in the report itself. When `07_resumen_modelos.csv` flags a model as overparameterised, the section on reception adds a warning.

### What does not update by itself

The 94.1 % topic coverage is written into the text of the Rmd and is not read from the tables, so it has to be corrected by hand if the lexicon or the dialogues change. The same goes for the 16 topics, the MATTR window of 200 words and the 34 observations that the warning mentions. From `06_complejidad_temporada` the report includes only the first page, which covers season 1, although the figure caption speaks of every season.
