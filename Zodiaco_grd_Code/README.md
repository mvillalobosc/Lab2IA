# Zodiaco_grd_Code

**Español** | [English](#english)

## Español

Código en R que reproduce el análisis del signo zodiacal frente a los registros clínicos de los archivos GRD públicos de Fonasa (2019-2024).

El análisis tiene dos partes. La primera repite un análisis ingenuo: un filtro chi-cuadrado sin corrección sobre 3.744 variables clínicas binarias (especialidad, diagnósticos y procedimientos), aplicado a los 5,8 millones de registros. La segunda evalúa si las variables retenidas permiten predecir el signo en datos que no se usaron para seleccionarlas, con cinco clasificadores, muestras bootstrap balanceadas y validación cruzada.

El análisis original se hizo con notebooks de scikit-learn. Este código lo traduce a R con los mismos hiperparámetros, y su chi-cuadrado replica el de `sklearn.feature_selection.chi2`.

---

### Contenido

```
Zodiaco_grd_Code/
├── LICENSE
├── README.md
├── 00_funciones.R       configuración (rutas, semilla, parámetros) y funciones comunes
├── 01_preparar_datos.R  lectura de los seis archivos GRD, signo y variables clínicas
├── 02_chi_cuadrado.R    filtro chi-cuadrado con el calendario de 12 y de 13 signos
├── 03_modelos.R         bootstrap balanceado, validación cruzada y cinco modelos
└── 04_resultados.R      medias, prueba de Wilcoxon, resúmenes y figuras
```

Los cinco modelos son regresión logística, árbol de decisión, random forest, k vecinos más cercanos y máquina de soporte vectorial. Sus parámetros están en `PARAMS`, dentro de `00_funciones.R`.

Cada diagnóstico se agrupa por la letra inicial de su código CIE-10 y cada procedimiento por su grupo CIE-9-CM de 00 a 99; los valores vacíos quedan como `NA` y los que no calzan con ese formato, como `OTROS`. Cada nivel de especialidad, de cada posición de diagnóstico y de cada posición de procedimiento es una variable binaria. El signo se calcula con los rangos de 12 signos de la Encyclopaedia Britannica y, como alternativa, con un calendario de 13 signos que agrega Ofiuco.

---

### Requisitos

R 4.2 o superior y seis paquetes de CRAN:

```r
install.packages(c("data.table", "glmnet", "rpart", "ranger", "e1071", "ggplot2"))
```

R debe correr con una configuración regional UTF-8, que es la opción por defecto en Windows desde R 4.2, en macOS y en Linux, porque los archivos traen tildes y eñes; si no es así, `00_funciones.R` lo advierte al cargarse. El código se probó con R 4.3.3 en Linux.

`04_resultados.R` guarda las figuras con `cairo_pdf`, así que R tiene que tener soporte para Cairo (`capabilities("cairo")` debe devolver `TRUE`); sin él, los resúmenes en CSV se escriben, pero las figuras fallan.

`01_preparar_datos.R` lee cada archivo completo en memoria como texto (el de 2024, además, como bytes) antes de convertirlo en tabla, y después une los seis años en una sola tabla, así que necesita un computador con bastante memoria libre.

---

### Datos

Los seis archivos `GRD_PUBLICO_2019.txt` a `GRD_PUBLICO_2024.txt` se descargan del [catálogo de datos GRD de Fonasa](https://public.tableau.com/views/PropuestaTableroGRD/PropuestaTableroGRD) y se dejan, sin cambiarles el nombre, en una carpeta `datos_grd/` junto a los scripts. Ese tablero está enlazado desde la página [Financiamiento y Gastos de salud](https://datosabiertos.fonasa.cl/dimensiones-financiamientos/) del portal de datos abiertos de Fonasa. El proyecto [StrokeGRDCL](../StrokeGRDCL/data/README.md), en este mismo repositorio, usa los mismos seis archivos y los descarga de ese portal.

Los archivos de 2022 y 2023 vienen en UTF-16 y el de 2024 trae bytes dañados. `01_preparar_datos.R` resuelve los tres casos sin intervención: decodifica el de 2024 como latin-1 y reemplaza los bytes inválidos, quita la marca BOM si viene, descarta las líneas con más campos que el encabezado y completa las que traen menos. Los archivos anteriores a 2024 llaman `CIP_ENCRIPTADO` al identificador del beneficiario y el de 2024 lo llama `ID_BENEFICIARIO`; el script los unifica con este último nombre.

Los datos y los resultados no se suben al repositorio por su tamaño: el `.gitignore` de la raíz del repositorio deja fuera `datos_grd/`, `datos/` y `resultados/`.

---

### Ejecución

Desde la carpeta del código, en este orden:

```bash
Rscript 01_preparar_datos.R
Rscript 02_chi_cuadrado.R
Rscript 03_modelos.R
Rscript 04_resultados.R
```

`00_funciones.R` no se ejecuta por sí solo, porque los otros scripts lo cargan. Ahí se cambian las rutas, la semilla y los parámetros.

`02_chi_cuadrado.R` aplica el filtro sobre todos los episodios, antes de la partición 80/20, a propósito: así lo hacía el análisis original que este código reproduce. La partición 80/20 estratificada por signo la hace después `03_modelos.R`.

`03_modelos.R` corre cuatro experimentos, que se eligen en la variable `EJECUTAR` al comienzo del script: el principal, el muestreo desde todos los registros, el calendario de 13 signos con Ofiuco y la sensibilidad del árbol de decisión al tamaño de la muestra. Los cuatro toman unas cuatro horas en un computador de escritorio con un núcleo. Cada iteración usa una semilla fija, de modo que dos corridas dan los mismos resultados. Para una prueba corta conviene bajar `n_iter` en `CFG` (`00_funciones.R`) y el `n_iter = 100` de la sensibilidad al final de `03_modelos.R`, o dejar un solo experimento en `EJECUTAR`.

Cada vez que `03_modelos.R` escribe un archivo de detalle agrega una fila con su tiempo a `resultados/tiempos.csv`, y nada vacía ese archivo, así que las corridas repetidas se acumulan ahí.

`04_resultados.R` acepta como argumento otra carpeta de resultados, por ejemplo la carpeta `4_results` del repositorio original `Tesis_ML_Zodiac`, que tiene la misma estructura:

```bash
Rscript 04_resultados.R Tesis_ML_Zodiac/4_results
```

En esa carpeta usa `chi2_12.csv` o, si no está, el archivo `v2_chi2_resultados.csv` del repositorio original. Necesita al menos el experimento principal y uno de esos dos archivos del filtro; los otros experimentos que falten se omiten con el aviso `No está:` seguido de la ruta del archivo que falta.

---

### Qué produce cada script

| Script | Salida principal |
|---|---|
| `01_preparar_datos.R` | `datos/base_grd.rds` y, en `resultados/`, los registros excluidos y los conteos por beneficiario y por signo |
| `02_chi_cuadrado.R` | `resultados/chi2_12.csv` y `chi2_13.csv`, con sus resúmenes por familia, y las variables retenidas en `datos/seleccion_12.rds` y `datos/seleccion_13.rds` |
| `03_modelos.R` | métricas por iteración, signo y modelo en una carpeta por modelo (`resultados/modelo_rf/`, `modelo_dt/`, `modelo_knn/`, `modelo_lr/` y `modelo_svm/`), en las mismas carpetas terminadas en `_full_dataset` (por ejemplo `modelo_rf_full_dataset/`), en `Ofiuco/` y en `modelo_dt_sensibilidad_n/`, más `resultados/tiempos.csv` |
| `04_resultados.R` | en `resultados/resumen/`: medias por signo y modelo, prueba de Wilcoxon, sensibilidad, conteo del filtro por familia y las figuras `fig_chi2.pdf`, `fig_auc.pdf` y `fig_sensibilidad.pdf` |

#### Formato de las salidas principales

| Archivo | Columnas |
|---|---|
| `datos/base_grd.rds` | `ID_BENEFICIARIO`, `ESPECIALIDAD_MEDICA`, `DIAGNOSTICO1` a `DIAGNOSTICO35`, `PROCEDIMIENTO1` a `PROCEDIMIENTO30` (agrupados y guardados como factores), `ANIO_ARCHIVO`, `SIGNO`, `SIGNO13` y `ESTANCIA_DIAS` (días entre ingreso y alta; vacía o negativa queda en 0) |
| `resultados/filas_excluidas.csv` | los episodios sin fecha de nacimiento válida, con las columnas leídas del archivo original |
| `resultados/episodios_por_beneficiario.csv` | `indicador`, `valor`: episodios, beneficiarios únicos, episodios por beneficiario y cuántos beneficiarios y episodios corresponden a beneficiarios con más de un episodio |
| `resultados/episodios_por_signo.csv` | `signo`, `doce_signos`, `trece_signos` |
| `resultados/chi2_12.csv` y `chi2_13.csv` | `variable`, `familia`, `chi2`, `p_value`, `significativa` (p < 0,01), `bonferroni_01` (pasa también la corrección de Bonferroni, solo para informar) |
| `resultados/chi2_12_familias.csv` y `chi2_13_familias.csv` | `familia`, `total_variables`, `significativas`, `bonferroni_01` |
| `datos/seleccion_12.rds` y `seleccion_13.rds` | `campo`, `nivel`, `codigo`, `variable` de cada variable retenida |
| `resultados/modelo_rf/rf_detalle.csv` y los demás archivos de detalle, uno por modelo y experimento (por ejemplo `modelo_rf_full_dataset/rf_full_detalle.csv` o `modelo_dt_sensibilidad_n/dt_detalle_n100.csv`) | una fila por signo e iteración: `modelo`, `signo`, `iter`, `n_sample`, `cv_accuracy`, `cv_precision`, `cv_recall`, `cv_f1`, `cv_roc_auc` (promedio de los cinco pliegues) |
| `resultados/tiempos.csv` | `experimento`, `archivo`, `segundos` |
| `resultados/resumen/medias_principal.csv`, `medias_completo.csv` y `medias_ofiuco.csv` | `modelo`, `signo`, `accuracy`, `precision`, `recall`, `f1`, `roc_auc` |
| `resultados/resumen/wilcoxon.csv` | por modelo: `n`, `n_sin_empates_en_05`, `media`, `mediana`, `de`, `sobre_05`, `estadistico_V`, `p_value` y `p_bonferroni` de la prueba de una cola del ROC-AUC contra 0,5 |
| `resultados/resumen/sensibilidad.csv` | `n_sample`, `media_auc`, `de_auc` |
| `resultados/resumen/chi2_familias.csv` | `familia`, `total`, `p_001`, `bonferroni` |

#### Figuras

Según los comentarios de `04_resultados.R`, las tres figuras son las del artículo y se guardan a su tamaño final (una columna mide 3,1 pulgadas y el ancho completo 6,5):

| Archivo | Figura | Contenido | Tamaño (pulgadas) |
|---|---|---|---|
| `fig_chi2.pdf` | Figura 1 | -log10(p) del filtro chi-cuadrado por familia de variables, con los umbrales p = 0,01 y Bonferroni | 3,1 x 2,6 |
| `fig_auc.pdf` | Figura 2 | distribución del ROC-AUC por iteración, por signo y modelo, en el experimento principal | 6,5 x 2,6 |
| `fig_sensibilidad.pdf` | Figura 3 | media y desviación estándar del ROC-AUC del árbol de decisión según el tamaño de la muestra bootstrap | 6,5 x 1,85 |

---

### Licencia y cita

El código se distribuye con licencia MIT ([LICENSE](LICENSE)) y la carpeta no trae archivo de cita.

---

## English

[Español](#español) | **English**

R code that reproduces the analysis of the zodiac sign against the clinical records in the public diagnosis-related group (GRD) files of Fonasa, Chile's public health insurer (2019-2024).

The analysis has two parts. The first repeats a naive analysis: an unadjusted chi-square filter over 3,744 binary clinical variables (specialty, diagnoses and procedures), applied to all 5.8 million records. The second tests whether the retained variables predict the sign in data that were not used to select them, with five classifiers, balanced bootstrap samples and cross-validation.

The original analysis was done with scikit-learn notebooks. This code translates it to R with the same hyperparameters, and its chi-square statistic reproduces `sklearn.feature_selection.chi2`.

---

### Contents

```
Zodiaco_grd_Code/
├── LICENSE
├── README.md
├── 00_funciones.R       settings (paths, seed, parameters) and shared functions
├── 01_preparar_datos.R  reads the six GRD files, computes the sign and the clinical variables
├── 02_chi_cuadrado.R    chi-square filter with the 12-sign and 13-sign calendars
├── 03_modelos.R         balanced bootstrap, cross-validation and five models
└── 04_resultados.R      means, Wilcoxon test, summaries and figures
```

The five models are logistic regression, decision tree, random forest, k-nearest neighbours and support vector machine. Their parameters are in `PARAMS`, inside `00_funciones.R`.

Each diagnosis is grouped by the first letter of its ICD-10 code and each procedure by its ICD-9-CM group from 00 to 99; empty values become `NA` and values that do not fit that format become `OTROS`. Every level of specialty, of each diagnosis position and of each procedure position is a binary variable. The sign is computed with the 12-sign ranges of Encyclopaedia Britannica and, as an alternative, with a 13-sign calendar that adds Ophiuchus.

---

### Requirements

R 4.2 or later and six CRAN packages:

```r
install.packages(c("data.table", "glmnet", "rpart", "ranger", "e1071", "ggplot2"))
```

R must run in a UTF-8 locale, the default on Windows since R 4.2, on macOS and on Linux, because the files contain accented characters; otherwise `00_funciones.R` warns when it is loaded. The code was tested with R 4.3.3 on Linux.

`04_resultados.R` saves the figures with `cairo_pdf`, so R needs Cairo support (`capabilities("cairo")` must return `TRUE`); without it the CSV summaries are written but the figures fail.

`01_preparar_datos.R` reads each file whole into memory as text (the 2024 file, in addition, as raw bytes) before turning it into a table, and then joins the six years into one table, so it needs a computer with plenty of free memory.

---

### Data

Download the six files `GRD_PUBLICO_2019.txt` to `GRD_PUBLICO_2024.txt` from the [Fonasa GRD data catalogue](https://public.tableau.com/views/PropuestaTableroGRD/PropuestaTableroGRD) and place them, without renaming them, in a `datos_grd/` folder next to the scripts. That dashboard is linked from the [Financiamiento y Gastos de salud](https://datosabiertos.fonasa.cl/dimensiones-financiamientos/) page (financing and health spending) of the Fonasa open data portal. The [StrokeGRDCL](../StrokeGRDCL/data/README.md) project, in this same repository, uses the same six files and downloads them from that portal.

The 2022 and 2023 files are encoded in UTF-16 and the 2024 file contains damaged bytes. `01_preparar_datos.R` handles the three cases without intervention: it decodes the 2024 file as latin-1 and replaces the invalid bytes, removes the byte order mark when there is one, drops lines with more fields than the header and fills the ones with fewer. Files before 2024 call the beneficiary identifier `CIP_ENCRIPTADO` and the 2024 file calls it `ID_BENEFICIARIO`; the script unifies them under the latter name.

Data and results are not stored in the repository because of their size: the `.gitignore` at the root of the repository keeps `datos_grd/`, `datos/` and `resultados/` out of git.

---

### Running the analysis

From the code folder, in this order:

```bash
Rscript 01_preparar_datos.R
Rscript 02_chi_cuadrado.R
Rscript 03_modelos.R
Rscript 04_resultados.R
```

`00_funciones.R` is not run on its own, because the other scripts load it. Paths, seed and parameters are set there.

`02_chi_cuadrado.R` applies the filter to all episodes, before the 80/20 split, on purpose: that is what the original analysis reproduced here did. `03_modelos.R` makes the 80/20 split, stratified by sign, afterwards.

`03_modelos.R` runs four experiments, selected in the `EJECUTAR` variable at the top of the script: the main experiment, sampling from all records, the 13-sign calendar with Ophiuchus, and the sensitivity of the decision tree to sample size. The four take about four hours on a single-core desktop computer. Every iteration uses a fixed seed, so two runs give the same results. For a short test, lower `n_iter` in `CFG` (`00_funciones.R`) and the `n_iter = 100` of the sensitivity analysis at the end of `03_modelos.R`, or leave a single experiment in `EJECUTAR`.

Every time `03_modelos.R` writes a detail file it appends a row with its run time to `resultados/tiempos.csv`, and nothing empties that file, so repeated runs accumulate there.

`04_resultados.R` accepts another results folder as an argument, for example the `4_results` folder of the original `Tesis_ML_Zodiac` repository, which has the same structure:

```bash
Rscript 04_resultados.R Tesis_ML_Zodiac/4_results
```

In that folder it uses `chi2_12.csv` or, when it is missing, the `v2_chi2_resultados.csv` file of the original repository. It needs at least the main experiment and one of those two filter files; missing experiments are skipped with the message `No está:` (not found) followed by the path of the missing file.

---

### What each script produces

| Script | Main output |
|---|---|
| `01_preparar_datos.R` | `datos/base_grd.rds` and, in `resultados/`, the excluded records and the counts by beneficiary and by sign |
| `02_chi_cuadrado.R` | `resultados/chi2_12.csv` and `chi2_13.csv`, with their summaries by family, and the retained variables in `datos/seleccion_12.rds` and `datos/seleccion_13.rds` |
| `03_modelos.R` | metrics by iteration, sign and model in one folder per model (`resultados/modelo_rf/`, `modelo_dt/`, `modelo_knn/`, `modelo_lr/` and `modelo_svm/`), in the same folders ending in `_full_dataset` (for example `modelo_rf_full_dataset/`), in `Ofiuco/` and in `modelo_dt_sensibilidad_n/`, plus `resultados/tiempos.csv` |
| `04_resultados.R` | in `resultados/resumen/`: means by sign and model, Wilcoxon test, sensitivity, filter counts by family and the figures `fig_chi2.pdf`, `fig_auc.pdf` and `fig_sensibilidad.pdf` |

#### Format of the main outputs

| File | Columns |
|---|---|
| `datos/base_grd.rds` | `ID_BENEFICIARIO`, `ESPECIALIDAD_MEDICA`, `DIAGNOSTICO1` to `DIAGNOSTICO35`, `PROCEDIMIENTO1` to `PROCEDIMIENTO30` (grouped and stored as factors), `ANIO_ARCHIVO`, `SIGNO`, `SIGNO13` and `ESTANCIA_DIAS` (days between admission and discharge; empty or negative becomes 0) |
| `resultados/filas_excluidas.csv` | the episodes without a valid birth date, with the columns read from the original file |
| `resultados/episodios_por_beneficiario.csv` | `indicador`, `valor`: episodes, unique beneficiaries, episodes per beneficiary, and how many beneficiaries and episodes belong to beneficiaries with more than one episode |
| `resultados/episodios_por_signo.csv` | `signo`, `doce_signos`, `trece_signos` |
| `resultados/chi2_12.csv` and `chi2_13.csv` | `variable`, `familia`, `chi2`, `p_value`, `significativa` (p < 0.01), `bonferroni_01` (also passes the Bonferroni correction, reported only) |
| `resultados/chi2_12_familias.csv` and `chi2_13_familias.csv` | `familia`, `total_variables`, `significativas`, `bonferroni_01` |
| `datos/seleccion_12.rds` and `seleccion_13.rds` | `campo`, `nivel`, `codigo`, `variable` of every retained variable |
| `resultados/modelo_rf/rf_detalle.csv` and the other detail files, one per model and experiment (for example `modelo_rf_full_dataset/rf_full_detalle.csv` or `modelo_dt_sensibilidad_n/dt_detalle_n100.csv`) | one row per sign and iteration: `modelo`, `signo`, `iter`, `n_sample`, `cv_accuracy`, `cv_precision`, `cv_recall`, `cv_f1`, `cv_roc_auc` (mean of the five folds) |
| `resultados/tiempos.csv` | `experimento`, `archivo`, `segundos` |
| `resultados/resumen/medias_principal.csv`, `medias_completo.csv` and `medias_ofiuco.csv` | `modelo`, `signo`, `accuracy`, `precision`, `recall`, `f1`, `roc_auc` |
| `resultados/resumen/wilcoxon.csv` | per model: `n`, `n_sin_empates_en_05`, `media`, `mediana`, `de`, `sobre_05`, `estadistico_V`, `p_value` and `p_bonferroni` of the one-sided test of ROC-AUC against 0.5 |
| `resultados/resumen/sensibilidad.csv` | `n_sample`, `media_auc`, `de_auc` |
| `resultados/resumen/chi2_familias.csv` | `familia`, `total`, `p_001`, `bonferroni` |

#### Figures

According to the comments in `04_resultados.R`, the three figures are those of the article and are saved at their final size (one column is 3.1 inches wide and the full width is 6.5):

| File | Figure | Content | Size (inches) |
|---|---|---|---|
| `fig_chi2.pdf` | Figure 1 | -log10(p) of the chi-square filter by variable family, with the p = 0.01 and Bonferroni thresholds | 3.1 x 2.6 |
| `fig_auc.pdf` | Figure 2 | distribution of ROC-AUC per iteration, by sign and model, in the main experiment | 6.5 x 2.6 |
| `fig_sensibilidad.pdf` | Figure 3 | mean and standard deviation of the decision tree ROC-AUC by bootstrap sample size | 6.5 x 1.85 |

---

### Licence and citation

The code is distributed under the MIT licence ([LICENSE](LICENSE)) and the folder has no citation file.
