# datos/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el catálogo de obras y es donde van los textos. El repositorio solo trae `Principal_guia.xlsx`; los libros no se versionan porque tienen derechos de autor. Vuelve al [README del proyecto](../README.md).

### Principal_guia.xlsx

La planilla reúne las cuatro listas de lecturas sugeridas del currículum de Lenguaje y Comunicación del MINEDUC (1° a 4° básico, 5° a 8° básico, 1° a 2° medio y 3° a 4° medio, actualización de agosto de 2020), extraídas de los PDF originales según explica su hoja "Leyenda y fuentes". Tiene cuatro hojas:

| Hoja | Filas | Contenido |
|---|---|---|
| `Libros` | 1.826 | Una obra única por fila, con las columnas `N°`, `Obra`, `Autor`, `Conseguido`, `Género`, `Cursos`, `Ciclo`, `Ubicación en el currículum`, `Tipo de copyright`, `Criterio de clasificación` y `Dónde buscarlo`. Es la hoja que lee el pipeline. |
| `Detalle completo` | 2.283 | Un registro por línea de los PDF del MINEDUC, con `Ciclo`, `Curso`, `Autor`, `Obra`, `Texto citado`, `Género`, `Ubicación`, `Año`, `Editorial`, `Tipo de copyright` y `Página PDF`. |
| `Resumen` | | El avance de la búsqueda: libros únicos, registros, conteos por tipo de copyright, por estado de `Conseguido` y por ciclo. |
| `Leyenda y fuentes` | | Cómo usar la planilla, qué significa cada clasificación de copyright (según la Ley 17.336 con corte en 2026) y advertencias sobre defectos de los PDF de origen. |

En la hoja `Libros`, `Conseguido` vale `Sí` en 878 obras y `Descartado` en 948, y `Género` viene vacío en 828. `N°` es el número de catálogo (1 a 1.826) que llevan como prefijo los archivos de texto. `Cursos` trae uno o más cursos ("7° básico", "3° o 4° medio") y `parse_niveles_multi()` de `R/utils.R` los convierte en niveles de 1 a 12. El README del proyecto explica qué columnas y filtros poner en `config.R` para usar esta hoja.

### Archivos que el pipeline agrega aquí

- `textos/`: la carpeta de los libros cuando `config.R` apunta al catálogo real (`carpeta_textos = "datos/textos"`). Cada archivo lleva como prefijo el número de catálogo seguido de guion bajo, guion o espacio (los de Drive vienen con cuatro dígitos, como `0639_Chorlitos en la cabeza.pdf`) y puede ser txt, pdf, epub o docx. El emparejador ignora un archivo llamado `COLOCAR_TEXTOS_AQUI.txt`. El `.gitignore` de la raíz del repositorio ignora la carpeta completa.
- `mapeo_confirmado.csv`: lo escribe `R/emparejar_contenido.R` junto al catálogo, con el archivo que asignó a cada obra y el estado de la decisión (`auto` o `revisar`). Se puede editar a mano, cambiando el archivo o poniendo el estado en `confirmado` o `descartar`, y esas decisiones se conservan entre corridas. `R/01_ingesta.R` usa las filas `auto` y `confirmado`. Este archivo no está ignorado, porque guarda decisiones revisadas a mano.

## English

This folder holds the catalogue of works and is where the texts go. The repository only ships `Principal_guia.xlsx`; the books are not versioned because they are under copyright. Back to the [project README](../README.md).

### Principal_guia.xlsx

The workbook gathers the four suggested reading lists of the MINEDUC Language and Communication curriculum (1st to 4th and 5th to 8th grade of primary school, 1st to 2nd and 3rd to 4th year of secondary school, August 2020 update), extracted from the original PDFs as its "Leyenda y fuentes" sheet explains. It has four sheets:

| Sheet | Rows | Contents |
|---|---|---|
| `Libros` | 1,826 | One unique work per row, with the columns `N°`, `Obra`, `Autor`, `Conseguido`, `Género`, `Cursos`, `Ciclo`, `Ubicación en el currículum`, `Tipo de copyright`, `Criterio de clasificación` and `Dónde buscarlo`. This is the sheet the pipeline reads. |
| `Detalle completo` | 2,283 | One record per line of the MINEDUC PDFs, with `Ciclo`, `Curso`, `Autor`, `Obra`, `Texto citado`, `Género`, `Ubicación`, `Año`, `Editorial`, `Tipo de copyright` and `Página PDF`. |
| `Resumen` | | Search progress: unique books, records, and counts by copyright type, by `Conseguido` status and by cycle. |
| `Leyenda y fuentes` | | How to use the workbook, what each copyright class means (under Chilean Law 17,336, with a 2026 cut-off) and warnings about defects in the source PDFs. |

In the `Libros` sheet, `Conseguido` is `Sí` for 878 works and `Descartado` for 948, and `Género` is empty in 828. `N°` is the catalogue number (1 to 1,826) that the text files carry as a prefix. `Cursos` holds one or more grades ("7° básico", "3° o 4° medio"), and `parse_niveles_multi()` in `R/utils.R` turns them into levels 1 to 12. The project README explains which columns and filters to set in `config.R` to use this sheet.

### Files the pipeline adds here

- `textos/`: the book folder when `config.R` points to the real catalogue (`carpeta_textos = "datos/textos"`). Each file carries the catalogue number as a prefix followed by an underscore, hyphen or space (the Drive files use four digits, as in `0639_Chorlitos en la cabeza.pdf`) and can be txt, pdf, epub or docx. The matcher ignores a file called `COLOCAR_TEXTOS_AQUI.txt`. The `.gitignore` at the repository root ignores the whole folder.
- `mapeo_confirmado.csv`: `R/emparejar_contenido.R` writes it next to the catalogue, with the file it assigned to each work and the status of the decision (`auto` or `revisar`). It can be edited by hand, changing the file or setting the status to `confirmado` or `descartar`, and those decisions are kept between runs. `R/01_ingesta.R` uses the `auto` and `confirmado` rows. This file is not ignored, because it stores decisions reviewed by hand.
