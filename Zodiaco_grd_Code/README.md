# Zodiaco_grd_Code

**Español** | [English](#english)

## Español

Código en R que reproduce el análisis del signo zodiacal frente a los registros clínicos de los archivos GRD públicos de Fonasa (2019-2024).

El análisis tiene dos partes. La primera repite un análisis ingenuo: un filtro chi-cuadrado sin corrección sobre 3.744 variables clínicas binarias (especialidad, diagnósticos y procedimientos), aplicado a los 5,8 millones de registros. La segunda evalúa si las variables retenidas permiten predecir el signo en datos que no se usaron para seleccionarlas, con cinco clasificadores, muestras bootstrap balanceadas y validación cruzada.

---

### Contenido

```
Zodiaco_grd_Code/
├── 00_funciones.R       configuración (rutas, semilla, parámetros) y funciones comunes
├── 01_preparar_datos.R  lectura de los seis archivos GRD, signo y variables clínicas
├── 02_chi_cuadrado.R    filtro chi-cuadrado con el calendario de 12 y de 13 signos
├── 03_modelos.R         bootstrap balanceado, validación cruzada y cinco modelos
└── 04_resultados.R      medias, prueba de Wilcoxon, resúmenes y figuras
```

Los cinco modelos son regresión logística, árbol de decisión, random forest, k vecinos más cercanos y máquina de soporte vectorial. Sus parámetros están en `PARAMS`, dentro de `00_funciones.R`.

---

### Requisitos

R 4.2 o superior y seis paquetes de CRAN:

```r
install.packages(c("data.table", "glmnet", "rpart", "ranger", "e1071", "ggplot2"))
```

R debe correr con una configuración regional UTF-8, que es la opción por defecto en Windows desde R 4.2, en macOS y en Linux, porque los archivos traen tildes y eñes. El código se probó con R 4.3.3 en Linux.

---

### Datos

Los seis archivos `GRD_PUBLICO_2019.txt` a `GRD_PUBLICO_2024.txt` se descargan del [catálogo de datos GRD de Fonasa](https://public.tableau.com/views/PropuestaTableroGRD/PropuestaTableroGRD) y se dejan, sin cambiarles el nombre, en una carpeta `datos_grd/` junto a los scripts.

Los archivos de 2022 y 2023 vienen en UTF-16 y el de 2024 trae bytes dañados. `01_preparar_datos.R` resuelve los tres casos sin intervención. Los datos y los resultados no se suben al repositorio por su tamaño.

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

`03_modelos.R` corre cuatro experimentos, que se eligen en la variable `EJECUTAR`: el principal, el muestreo desde todos los registros, el calendario de 13 signos con Ofiuco y la sensibilidad del árbol de decisión al tamaño de la muestra. Los cuatro toman unas cuatro horas en un computador de escritorio con un núcleo. Cada iteración usa una semilla fija, de modo que dos corridas dan los mismos resultados.

---

### Qué produce cada script

| Script | Salida principal |
|---|---|
| `01_preparar_datos.R` | `datos/base_grd.rds` y, en `resultados/`, los registros excluidos y los conteos por beneficiario y por signo |
| `02_chi_cuadrado.R` | `resultados/chi2_12.csv` y `chi2_13.csv`, con sus resúmenes por familia, y las variables retenidas en `datos/seleccion_12.rds` y `datos/seleccion_13.rds` |
| `03_modelos.R` | métricas por iteración, signo y modelo en `resultados/modelo_<modelo>/`, `modelo_<modelo>_full_dataset/`, `Ofiuco/` y `modelo_dt_sensibilidad_n/`, más `resultados/tiempos.csv` |
| `04_resultados.R` | en `resultados/resumen/`: medias por signo y modelo, prueba de Wilcoxon, sensibilidad, conteo del filtro por familia y las figuras `fig_chi2.pdf`, `fig_auc.pdf` y `fig_sensibilidad.pdf` |

---

## English

[Español](#español) | **English**

R code that reproduces the analysis of the zodiac sign against the clinical records in the public diagnosis-related group (GRD) files of Fonasa, Chile's public health insurer (2019-2024).

The analysis has two parts. The first repeats a naive analysis: an unadjusted chi-square filter over 3,744 binary clinical variables (specialty, diagnoses and procedures), applied to all 5.8 million records. The second tests whether the retained variables predict the sign in data that were not used to select them, with five classifiers, balanced bootstrap samples and cross-validation.

---

### Contents

```
Zodiaco_grd_Code/
├── 00_funciones.R       settings (paths, seed, parameters) and shared functions
├── 01_preparar_datos.R  reads the six GRD files, computes the sign and the clinical variables
├── 02_chi_cuadrado.R    chi-square filter with the 12-sign and 13-sign calendars
├── 03_modelos.R         balanced bootstrap, cross-validation and five models
└── 04_resultados.R      means, Wilcoxon test, summaries and figures
```

The five models are logistic regression, decision tree, random forest, k-nearest neighbours and support vector machine. Their parameters are in `PARAMS`, inside `00_funciones.R`.

---

### Requirements

R 4.2 or later and six CRAN packages:

```r
install.packages(c("data.table", "glmnet", "rpart", "ranger", "e1071", "ggplot2"))
```

R must run in a UTF-8 locale, the default on Windows since R 4.2, on macOS and on Linux, because the files contain accented characters. The code was tested with R 4.3.3 on Linux.

---

### Data

Download the six files `GRD_PUBLICO_2019.txt` to `GRD_PUBLICO_2024.txt` from the [Fonasa GRD data catalogue](https://public.tableau.com/views/PropuestaTableroGRD/PropuestaTableroGRD) and place them, without renaming them, in a `datos_grd/` folder next to the scripts.

The 2022 and 2023 files are encoded in UTF-16 and the 2024 file contains damaged bytes. `01_preparar_datos.R` handles the three cases without intervention. Data and results are not stored in the repository because of their size.

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

`03_modelos.R` runs four experiments, selected in the `EJECUTAR` variable: the main experiment, sampling from all records, the 13-sign calendar with Ophiuchus, and the sensitivity of the decision tree to sample size. The four take about four hours on a single-core desktop computer. Every iteration uses a fixed seed, so two runs give the same results.

---

### What each script produces

| Script | Main output |
|---|---|
| `01_preparar_datos.R` | `datos/base_grd.rds` and, in `resultados/`, the excluded records and the counts by beneficiary and by sign |
| `02_chi_cuadrado.R` | `resultados/chi2_12.csv` and `chi2_13.csv`, with their summaries by family, and the retained variables in `datos/seleccion_12.rds` and `datos/seleccion_13.rds` |
| `03_modelos.R` | metrics by iteration, sign and model in `resultados/modelo_<model>/`, `modelo_<model>_full_dataset/`, `Ofiuco/` and `modelo_dt_sensibilidad_n/`, plus `resultados/tiempos.csv` |
| `04_resultados.R` | in `resultados/resumen/`: means by sign and model, Wilcoxon test, sensitivity, filter counts by family and the figures `fig_chi2.pdf`, `fig_auc.pdf` and `fig_sensibilidad.pdf` |
