# examples/

[Español](#español) · [English](#english)

## Español

Esta carpeta de [BACP-Planner](../README.md) guarda los dos libros Excel que enlaza la sección "Formato Excel" del README. Los dos siguen el formato de tres hojas (`Asignaturas`, `Prerrequisitos` y `Parametros`) y se cargan desde el panel de datos de cualquiera de los tres módulos. La app no lee esta carpeta: el panel trae botones que generan libros equivalentes desde el código de `index.html`.

| Archivo | Contenido |
|---|---|
| `plantilla_plan_estudios.xlsx` | Plantilla mínima para empezar un plan propio: tres asignaturas (`MAT101` Cálculo I, `MAT102` Cálculo II e `INF101` Programación, 17 SCT en total), un prerrequisito (`MAT101` antes de `MAT102`) y los parámetros `plan` = "Mi plan de estudios" y `periodos` = 10. `MAT101` tiene el semestre fijo en 1 y las tres traen una tasa de reprobación. |
| `ejemplo_ing_civil_informatica.xlsx` | Plan completo de Ingeniería Civil en Informática: 58 asignaturas, 330 SCT, 86 prerrequisitos y 11 semestres, con la columna `periodo` vacía para que el optimizador ubique todas las asignaturas y sin tasas de reprobación. Usa los valores de `tipo` 1 a 5. Coincide asignatura por asignatura y prerrequisito por prerrequisito con el ejemplo incorporado en la app (`CIVINF2022` en `index.html`). |

El botón "↓ Ejemplo (.xlsx)" del panel de datos descarga un libro con el mismo contenido que `ejemplo_ing_civil_informatica.xlsx`, y el botón "↓ Plantilla vacía" descarga una plantilla con el mismo contenido que `plantilla_plan_estudios.xlsx`. Si se cambia el ejemplo incorporado o la plantilla en `index.html`, estos archivos no se actualizan solos.

[mallas_ejemplo/](../mallas_ejemplo/) guarda otros 17 libros con mallas de distintas carreras; su README explica cuáles están completos.

## English

This folder of [BACP-Planner](../README.md) holds the two Excel workbooks linked from the "Excel format" section of the README. Both follow the three-worksheet format (`Asignaturas`, `Prerrequisitos` and `Parametros`) and can be loaded from the data panel of any of the three modules. The application does not read this folder: the panel has buttons that generate equivalent workbooks from the code in `index.html`.

| File | Contents |
|---|---|
| `plantilla_plan_estudios.xlsx` | Minimal template to start a curriculum of your own: three courses (`MAT101` Cálculo I, `MAT102` Cálculo II and `INF101` Programación, 17 SCT in total), one prerequisite (`MAT101` before `MAT102`) and the parameters `plan` = "Mi plan de estudios" and `periodos` = 10. `MAT101` has its term fixed at 1, and all three carry a failure rate. |
| `ejemplo_ing_civil_informatica.xlsx` | Complete Ingeniería Civil en Informática curriculum: 58 courses, 330 SCT, 86 prerequisites and 11 terms, with an empty `periodo` column so that the optimiser places every course, and no failure rates. It uses `tipo` values 1 to 5. It matches the example built into the app (`CIVINF2022` in `index.html`) course by course and prerequisite by prerequisite. |

The "↓ Ejemplo (.xlsx)" button in the data panel downloads a workbook with the same content as `ejemplo_ing_civil_informatica.xlsx`, and the "↓ Plantilla vacía" (empty template) button downloads a template with the same content as `plantilla_plan_estudios.xlsx`. When the built-in example or the template in `index.html` changes, these files are not updated automatically.

[mallas_ejemplo/](../mallas_ejemplo/) holds 17 more workbooks with curricula of several programmes; its README explains which ones are complete.
