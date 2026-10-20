# mallas_ejemplo/

[Español](#español) · [English](#english)

## Español

Esta carpeta de [BACP-Planner](../README.md) guarda 17 libros Excel con mallas de carreras de Ingeniería Civil (`Civil/`, 9 libros) y de Ingeniería de Ejecución (`Ejecucion/`, 8 libros). Todos tienen las hojas `Asignaturas`, `Prerrequisitos` y `Parametros` con las columnas del formato de la app (`codigo`, `nombre`, `creditos`, `periodo`, `tel`, `tipo`, `tasa`), y sus metadatos dicen que se generaron con openpyxl 3.1.5; el script que los produjo no está en el repositorio. La app no lee esta carpeta: cada libro se carga a mano desde el panel de datos.

Solo dos libros traen los créditos y prerrequisitos que necesitan la optimización y la simulación. Otros 14 traen la lista de asignaturas con su semestre, pero sin créditos (la app los toma como 0 SCT), sin ninguna relación de prerrequisito y con códigos correlativos con el prefijo de la carrera (`IND1`, `QUI1`, `MIN1`...) en lugar de los códigos numéricos de las asignaturas; el libro restante es la plantilla de Biomédica que se describe más abajo. Además, la columna `tipo` de esos 14 libros trae números de 2 a 12 que no siguen la tabla de categorías del README, y en cada libro la mayoría de las asignaturas comparte un mismo valor. Los valores 6 a 12 se pintan como "Otro / Electivo", y los valores 2 a 5 toman la categoría que la tabla asigna a ese número aunque no describa la asignatura: por ejemplo, las 50 asignaturas de Ingeniería de Ejecución en Minas llevan `tipo` 4 y aparecen como "Ciencias Sociales y Humanidades". Incluso en los dos libros completos, la mayoría de las asignaturas lleva `tipo` 7, que también se pinta como "Otro / Electivo".

### Civil/

| Libro | Plan (hoja `Parametros`) | Asignaturas | SCT | Prerrequisitos | Semestres con asignaturas / `periodos` | Valores de `tipo` |
|---|---|---:|---:|---:|---|---|
| `Ing_Civil_en_Informatica.xlsx` | Ingeniería Civil en Informática | 58 | 330 | 87 | 1 a 11 / 11 | 1, 2 y 7 |
| `Ing_Civil_Industrial.xlsx` | Ingeniería Civil Industrial | 55 | 0 | 0 | 1 a 11 / 11 | 2 y 8 |
| `Ing_Civil_Quimica.xlsx` | Ingeniería Civil Química | 55 | 0 | 0 | 1 a 7 / 11 | 2 y 11 |
| `Ing_Civil_en_Geografia.xlsx` | Ingeniería Civil en Geografía | 55 | 0 | 0 | 1 a 11 / 11 | 2 y 9 |
| `Ing_Civil_en_Mecatronica.xlsx` | Ingeniería Civil en Mecatrónica | 59 | 0 | 0 | 1 a 11 / 11 | 2 y 12 |
| `Ing_Civil_en_Minas.xlsx` | Ingeniería Civil en Minas | 60 | 0 | 0 | 1 a 10 / 11 | 2 y 4 |
| `Ing_Civil_en_Obras_Civiles.xlsx` | Ingeniería Civil en Obras Civiles | 58 | 0 | 0 | 1 a 11 / 11 | 2 y 3 |
| `Ing_Civil_en_Telematica.xlsx` | Ingeniería Civil en Telemática | 60 | 0 | 0 | 1 a 11 / 11 | 2 y 10 |
| `PLANTILLA_Ing_Civil_Biomedica_2019.xlsx` | ver abajo | 55 | 78 | 0 | sin semestres / sin `periodos` | 1, 2 y 4 en 15 asignaturas; 40 vacías |

`PLANTILLA_Ing_Civil_Biomedica_2019.xlsx` es una plantilla a medio llenar de Ingeniería Civil Biomédica 2019. Su hoja extra `LEER_ESTO` explica que el plan venía en un PDF escaneado que no se pudo leer por OCR: los 55 códigos son reales, las 15 asignaturas de plan común ya tienen nombre, créditos, TEL y tipo, y las 40 de especialidad (códigos que empiezan con 94) solo tienen el código y un texto pendiente en el nombre. Su hoja `Parametros` usa las columnas `plan` y `periodos` en vez de `parametro` y `valor`, y en lugar del número de semestres trae un texto por llenar. Como la app no encuentra `parametro` ni `valor`, cargarla da un plan llamado "Plan de estudios", sin `periodos`, y el panel muestra el error de parámetro faltante.

### Ejecucion/

| Libro | Plan (hoja `Parametros`) | Asignaturas | SCT | Prerrequisitos | Semestres con asignaturas / `periodos` | Valores de `tipo` |
|---|---|---:|---:|---:|---|---|
| `Ing_Ejecucion_en_Computacion_e_Informatica.xlsx` | Ingeniería de Ejecución en Computación e Informática | 42 | 240 | 40 | 1 a 8 / 8 | 1 y 7 |
| `Ing_Ejecucion_Electrica.xlsx` | Ingeniería de Ejecución Eléctrica | 48 | 0 | 0 | 1 a 8 / 8 | 10 |
| `Ing_Ejecucion_Industrial.xlsx` | Ingeniería de Ejecución Industrial | 40 | 0 | 0 | 1 a 8 / 8 | 8 |
| `Ing_Ejecucion_Mecanica.xlsx` | Ingeniería de Ejecución Mecánica | 41 | 0 | 0 | 1 a 8 / 8 | 6 |
| `Ing_Ejecucion_Metalurgica.xlsx` | Ingeniería de Ejecución Metalúrgica | 47 | 0 | 0 | 1 a 8 / 8 | 5 |
| `Ing_Ejecucion_Quimica.xlsx` | Ingeniería de Ejecución Química | 42 | 0 | 0 | 1 a 8 / 8 | 11 |
| `Ing_Ejecucion_en_Climatizacion.xlsx` | Ingeniería de Ejecución en Climatización | 41 | 0 | 0 | 1 a 8 / 8 | 9 |
| `Ing_Ejecucion_en_Minas.xlsx` | Ingeniería de Ejecución en Minas | 50 | 0 | 0 | 1 a 8 / 8 | 4 |

Los dos libros completos (`Civil/Ing_Civil_en_Informatica.xlsx` y `Ejecucion/Ing_Ejecucion_en_Computacion_e_Informatica.xlsx`) fijan el semestre de todas las asignaturas, así que el optimizador no puede moverlas. Para que las reubique hay que vaciar la columna `periodo`, como en [../examples/ejemplo_ing_civil_informatica.xlsx](../examples/). Ese ejemplo y `Civil/Ing_Civil_en_Informatica.xlsx` son versiones distintas del mismo plan: difieren en dos códigos de cada lado, en algunas relaciones de prerrequisito, en las tildes de los nombres y en los valores de `tipo`.

## English

This folder of [BACP-Planner](../README.md) holds 17 Excel workbooks with curricula of Ingeniería Civil programmes (`Civil/`, 9 workbooks) and Ingeniería de Ejecución programmes (`Ejecucion/`, 8 workbooks). All of them have the `Asignaturas`, `Prerrequisitos` and `Parametros` worksheets with the app's columns (`codigo`, `nombre`, `creditos`, `periodo`, `tel`, `tipo`, `tasa`), and their metadata say they were generated with openpyxl 3.1.5; the script that produced them is not in the repository. The application does not read this folder: each workbook is loaded by hand from the data panel.

Only two workbooks include the credits and prerequisites that optimisation and simulation need. Another 14 list the courses with their term, but without credits (the app reads them as 0 SCT), without any prerequisite relationship and with sequential codes carrying the programme prefix (`IND1`, `QUI1`, `MIN1`...) instead of the numeric course codes; the remaining workbook is the Biomédica template described below. The `tipo` column of those 14 workbooks also holds numbers from 2 to 12 that do not follow the category table in the README, and in each workbook most courses share the same value. Values 6 to 12 are drawn as "Otro / Electivo" (Other / Elective), and values 2 to 5 take the category that the table assigns to that number even when it does not describe the course: for example, the 50 courses of Ingeniería de Ejecución en Minas carry `tipo` 4 and appear as "Ciencias Sociales y Humanidades" (Social Sciences and Humanities). Even in the two complete workbooks, most courses carry `tipo` 7, which is also drawn as "Otro / Electivo".

### Civil/

| Workbook | Curriculum (`Parametros` worksheet) | Courses | SCT | Prerequisites | Terms with courses / `periodos` | `tipo` values |
|---|---|---:|---:|---:|---|---|
| `Ing_Civil_en_Informatica.xlsx` | Ingeniería Civil en Informática | 58 | 330 | 87 | 1 to 11 / 11 | 1, 2 and 7 |
| `Ing_Civil_Industrial.xlsx` | Ingeniería Civil Industrial | 55 | 0 | 0 | 1 to 11 / 11 | 2 and 8 |
| `Ing_Civil_Quimica.xlsx` | Ingeniería Civil Química | 55 | 0 | 0 | 1 to 7 / 11 | 2 and 11 |
| `Ing_Civil_en_Geografia.xlsx` | Ingeniería Civil en Geografía | 55 | 0 | 0 | 1 to 11 / 11 | 2 and 9 |
| `Ing_Civil_en_Mecatronica.xlsx` | Ingeniería Civil en Mecatrónica | 59 | 0 | 0 | 1 to 11 / 11 | 2 and 12 |
| `Ing_Civil_en_Minas.xlsx` | Ingeniería Civil en Minas | 60 | 0 | 0 | 1 to 10 / 11 | 2 and 4 |
| `Ing_Civil_en_Obras_Civiles.xlsx` | Ingeniería Civil en Obras Civiles | 58 | 0 | 0 | 1 to 11 / 11 | 2 and 3 |
| `Ing_Civil_en_Telematica.xlsx` | Ingeniería Civil en Telemática | 60 | 0 | 0 | 1 to 11 / 11 | 2 and 10 |
| `PLANTILLA_Ing_Civil_Biomedica_2019.xlsx` | see below | 55 | 78 | 0 | no terms / no `periodos` | 1, 2 and 4 in 15 courses; 40 empty |

`PLANTILLA_Ing_Civil_Biomedica_2019.xlsx` is a half-filled template for Ingeniería Civil Biomédica 2019. Its extra `LEER_ESTO` worksheet explains that the curriculum came as a scanned PDF that OCR could not read: the 55 codes are real, the 15 common-core courses already have name, credits, TEL and type, and the 40 specialisation courses (codes starting with 94) only have the code and a pending text in the name. Its `Parametros` worksheet uses the columns `plan` and `periodos` instead of `parametro` and `valor`, and holds a text to be filled in where the number of terms should be. Since the app finds neither `parametro` nor `valor`, loading it yields a curriculum named "Plan de estudios" without `periodos`, and the data panel shows the missing-parameter error.

### Ejecucion/

| Workbook | Curriculum (`Parametros` worksheet) | Courses | SCT | Prerequisites | Terms with courses / `periodos` | `tipo` values |
|---|---|---:|---:|---:|---|---|
| `Ing_Ejecucion_en_Computacion_e_Informatica.xlsx` | Ingeniería de Ejecución en Computación e Informática | 42 | 240 | 40 | 1 to 8 / 8 | 1 and 7 |
| `Ing_Ejecucion_Electrica.xlsx` | Ingeniería de Ejecución Eléctrica | 48 | 0 | 0 | 1 to 8 / 8 | 10 |
| `Ing_Ejecucion_Industrial.xlsx` | Ingeniería de Ejecución Industrial | 40 | 0 | 0 | 1 to 8 / 8 | 8 |
| `Ing_Ejecucion_Mecanica.xlsx` | Ingeniería de Ejecución Mecánica | 41 | 0 | 0 | 1 to 8 / 8 | 6 |
| `Ing_Ejecucion_Metalurgica.xlsx` | Ingeniería de Ejecución Metalúrgica | 47 | 0 | 0 | 1 to 8 / 8 | 5 |
| `Ing_Ejecucion_Quimica.xlsx` | Ingeniería de Ejecución Química | 42 | 0 | 0 | 1 to 8 / 8 | 11 |
| `Ing_Ejecucion_en_Climatizacion.xlsx` | Ingeniería de Ejecución en Climatización | 41 | 0 | 0 | 1 to 8 / 8 | 9 |
| `Ing_Ejecucion_en_Minas.xlsx` | Ingeniería de Ejecución en Minas | 50 | 0 | 0 | 1 to 8 / 8 | 4 |

The two complete workbooks (`Civil/Ing_Civil_en_Informatica.xlsx` and `Ejecucion/Ing_Ejecucion_en_Computacion_e_Informatica.xlsx`) fix the term of every course, so the optimiser cannot move them. To let it reassign the courses, empty the `periodo` column, as in [../examples/ejemplo_ing_civil_informatica.xlsx](../examples/). That example and `Civil/Ing_Civil_en_Informatica.xlsx` are different versions of the same curriculum: they differ in two codes on each side, in some prerequisite relationships, in the accents of the names and in the `tipo` values.
