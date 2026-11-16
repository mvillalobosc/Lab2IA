# RheumaCL_code

[Español](#español) · [English](#english)

## Español

Este proyecto caracteriza 12 enfermedades reumáticas con los datos de la 1.ª Encuesta de la Red de Pacientes Reumáticos de Chile. Para cada enfermedad selecciona variables con chi-cuadrado, compara una regresión logística (RL), un Random Forest (RF) y un XGBoost (XGB) con validación cruzada repetida, elige el modelo de mayor hipervolumen y lo explica con valores SHAP.

El código es una reorganización del script `Analisis_Unificado_FINAL.R`, que tenía todo el análisis en un solo archivo. Aquí está separado en configuración, funciones y cuatro pasos. El tablero con los resultados descriptivos de la misma encuesta está en [`../RheumaCL/`](../RheumaCL/).

### Contenido

```
RheumaCL_code/
├── README.md
├── LICENSE                     licencia MIT del código
├── config.R                    rutas, variables, semillas y parámetros
├── run_all.R                   corre los cuatro pasos en orden
├── R/                          ver R/README.md
│   ├── 00_inicio.R             paquetes, configuración, carpetas y funciones
│   ├── 01_preparar_datos.R     lee la encuesta y deja la base de modelamiento
│   ├── 02_ajustar_modelos.R    el paso largo: un checkpoint por enfermedad
│   ├── 03_tablas.R             Excel de resultados y tablas CSV
│   ├── 04_figuras.R            figuras SHAP
│   └── funciones_*.R           siete archivos de funciones
└── data/                       sin datos versionados, ver data/README.md
```

### Cómo correrlo

**Requisitos.** El código se probó con R 4.3.3; en Windows hace falta R 4.2 o superior, que es desde cuando R usa UTF-8. Usa quince paquetes de CRAN:

```r
install.packages(c("readxl", "dplyr", "tidyr", "forcats", "caret", "randomForest",
                   "xgboost", "pROC", "doParallel", "foreach", "doRNG", "fastshap",
                   "shapviz", "ggplot2", "openxlsx"))
```

Ningún script instala paquetes: si falta alguno, el paso se detiene y muestra la llamada a `install.packages()` lista para copiar.

**Datos.** La encuesta no viene en el repositorio. Hay que copiar `data_encuesta_filtrado.xlsx` en `data/raw/`; los detalles están en [`data/README.md`](data/README.md).

**Ejecución.** Siempre desde la carpeta del proyecto, o llamando a `run_all.R`, que se mueve solo a su carpeta.

```bash
Rscript run_all.R --lista         # muestra los pasos
Rscript run_all.R --prueba        # todo el flujo en minutos, para comprobar la instalación
Rscript run_all.R                 # el análisis completo, pasos 1 a 4
```

`run_all.R` también acepta `--desde N`, `--hasta N` y `--solo N`, y se detiene en el primer paso que falla. El modo de prueba usa 3 repeticiones y grillas reducidas, y escribe en `results_prueba/` y en `data/processed_prueba/`, así que no toca los resultados reales. Sus cifras no sirven para el artículo.

El paso 2 es el largo: 1.000 repeticiones por 5 folds por 3 modelos por 12 enfermedades. Guarda un checkpoint por enfermedad apenas la termina, de modo que se puede interrumpir y retomar. También acepta códigos de enfermedad, para repartir la corrida entre sesiones o máquinas:

```bash
Rscript R/02_ajustar_modelos.R V8 V10
```

Para repetir una enfermedad hay que borrar su archivo de `results/checkpoints/`. Los pasos 3 y 4 solo leen checkpoints y toman segundos, así que las tablas y las figuras se rehacen sin reentrenar. Los checkpoints que dejó el script de un solo archivo (`checkpoints_caracterizacion/<hoja>.rds`) tienen la misma estructura: copiados en `results/checkpoints/`, sirven para los pasos 3 y 4 sin volver a correr el paso 2.

El `.gitignore` de la raíz del repositorio deja fuera de git `data/raw/`, `data/processed/`, `results/` y sus equivalentes del modo de prueba.

### El pipeline

| Paso | Qué hace | Salida principal |
|---|---|---|
| 1 | Lee el Excel, unifica las respuestas SI y NO, convierte todo a factor y saca V5, V19, V21 y V22 | `data/processed/encuesta_modelo.rds`, `results/tables/flujo_registros.csv`, `results/tables/prevalencias.csv` |
| 2 | Para cada enfermedad: chi-cuadrado, one-hot encoding, grid search de RF y XGB, validación cruzada repetida de los tres modelos, modelos finales, hipervolumen, ganador y SHAP | `results/checkpoints/<hoja>.rds` |
| 3 | Arma el Excel con una hoja por enfermedad y una hoja de resumen, y las mismas tablas en CSV | `results/tables/Resultados_Unificado.xlsx`, `resumen.csv`, `comparacion_modelos.csv`, `estabilidad_cv.csv`, `shap_top.csv` |
| 4 | Dibuja la figura SHAP del modelo ganador de cada enfermedad, con etiquetas en inglés | `results/figures/SHAP_<hoja>_<ganador>.png` y `.pdf` |

Cada paso deja en `results/logs/sesion_<paso>.txt` la fecha, la versión de R, la configuración regional, la versión de cada paquete y los parámetros con que corrió.

Dentro del paso 2, cada enfermedad sigue este orden:

1. **Selección de variables.** Prueba chi-cuadrado entre cada variable y la enfermedad sobre la muestra completa. Quedan las variables con p < 0,05 y, de ellas, las 20 de menor valor p.
2. **Casos completos.** Salen las filas con algún dato faltante en esas variables. El número queda anotado en la configuración de la enfermedad.
3. **One-hot encoding.** Cada nivel pasa a ser una columna 0/1; en las variables SI/NO se elimina la columna NO.
4. **Grid search** de RF (mtry y ntree) y de XGB (eta, max_depth y nrounds) con validación cruzada de 5 folds y AUC-ROC.
5. **Validación cruzada repetida.** 1.000 repeticiones de 5 folds estratificados. En cada fold se sobremuestrea la clase SI solo en el entrenamiento, se ajusta el modelo, se anotan las variables que selecciona y se evalúa en el fold de validación, que conserva la proporción original.
6. **Modelo final** de cada tipo, ajustado con la muestra completa balanceada.
7. **Ganador.** El modelo con mayor hipervolumen, que es el producto de las medias de precisión, recall, F1 y AUC-ROC.
8. **SHAP** del modelo ganador con `fastshap` (50 repeticiones Monte Carlo), sobre todas las filas originales.

### Configuración

Los scripts no tienen rutas ni valores fijos: todos leen la lista `CFG` de [`config.R`](config.R). Estos son los parámetros que cambian resultados, con los valores del script original:

```r
alfa_chi2     = 0.05                       # umbral del chi-cuadrado
max_variables = 20                         # variables por enfermedad
rf_ntree      = c(100, 250, 500)           # grilla de RF (mtry: 5 valores hasta 20)
xgb_eta       = c(0.01, 0.05, 0.1, 0.3)    # grilla de XGB
xgb_max_depth = c(2, 4, 6, 8)
xgb_nrounds   = c(100, 250, 500)
n_iter        = 1000                       # repeticiones de la validación cruzada
k_fold        = 5
semilla_grid  = 321
semilla_final = 789
semilla_shap  = 123
shap_nsim     = 50
```

### Reproducibilidad

- Cada etapa fija su propia semilla: `set.seed(321)` antes de cada grid search, `set.seed(i)` en la repetición `i` de la validación cruzada, `set.seed(789)` antes de cada modelo final y `set.seed(123)` antes de SHAP. El resultado de una enfermedad no depende de cuáles se corrieron antes ni de si la corrida se retomó desde un checkpoint.
- El grid search corre en paralelo con `%dorng%`, que da a cada combinación su propio flujo de números aleatorios. El resultado no depende del número de núcleos.
- La versión de `xgboost` cambia los números de XGB, porque el método de construcción de árboles por defecto no es el mismo en la serie 1.7 que en las posteriores. El código se probó con xgboost 1.7.11.1 y no se ha probado con la serie 3.x. La versión usada queda anotada en la configuración de cada enfermedad y en `results/logs/`.
- La configuración regional también influye: `as.factor()` ordena los niveles de cada variable según `LC_COLLATE`, y ese orden fija el de las columnas one-hot que reciben RF y XGB. También queda anotada en `results/logs/`.
- La reorganización se comparó con el script de un solo archivo usando los mismos datos, semillas y versiones de paquetes (R 4.3.3, xgboost 1.7.11.1, randomForest 4.7-1.1, caret 6.0-94, fastshap 0.1.1). Las tablas, el modelo ganador, los valores SHAP y las predicciones del modelo ganador coincidieron exactamente en las 12 enfermedades. La comparación se hizo con 3 repeticiones de la validación cruzada, no con las 1.000.

Frente al script original, las salidas cambian en tres cosas que no tocan los números: lo que el Excel llamaba "bootstrap" ahora se llama "CV repetida", porque el código no remuestrea con reemplazo; la configuración de cada enfermedad suma las filas excluidas por datos faltantes y las versiones de R, randomForest y xgboost; y las figuras SHAP salen en el paso 4, con etiquetas en inglés y colores pastel.

### Licencia y cita

El código usa la licencia MIT; ver [`LICENSE`](LICENSE). Los datos de la encuesta no se distribuyen con el código y conservan sus propios términos.

El análisis sale del trabajo de titulación de Javiera Vásquez-Salgado en el Departamento de Ingeniería Informática de la Universidad de Santiago de Chile. La referencia del artículo se agregará aquí cuando se publique.

## English

This project characterises 12 rheumatic diseases with the data of the 1st Survey of the Chilean Network of Rheumatic Patients. For each disease it selects variables with a chi-square test, compares a logistic regression (RL), a Random Forest (RF) and an XGBoost (XGB) model with repeated cross-validation, picks the model with the largest hypervolume and explains it with SHAP values.

The code is a reorganisation of the script `Analisis_Unificado_FINAL.R`, which held the whole analysis in a single file. Here it is split into configuration, functions and four steps. The dashboard with the descriptive results of the same survey is in [`../RheumaCL/`](../RheumaCL/).

The code, its comments and its messages are in Spanish. The figures are labelled in English.

### Contents

```
RheumaCL_code/
├── README.md
├── LICENSE                     MIT licence of the code
├── config.R                    paths, variables, seeds and parameters
├── run_all.R                   runs the four steps in order
├── R/                          see R/README.md
│   ├── 00_inicio.R             packages, configuration, folders and functions
│   ├── 01_preparar_datos.R     reads the survey and builds the modelling dataset
│   ├── 02_ajustar_modelos.R    the long step: one checkpoint per disease
│   ├── 03_tablas.R             results workbook and CSV tables
│   ├── 04_figuras.R            SHAP figures
│   └── funciones_*.R           seven function files
└── data/                       no data committed, see data/README.md
```

### How to run it

**Requirements.** The code was tested with R 4.3.3; on Windows it needs R 4.2 or later, the first version where R uses UTF-8. It uses fifteen CRAN packages:

```r
install.packages(c("readxl", "dplyr", "tidyr", "forcats", "caret", "randomForest",
                   "xgboost", "pROC", "doParallel", "foreach", "doRNG", "fastshap",
                   "shapviz", "ggplot2", "openxlsx"))
```

No script installs packages: a missing one stops the step with a ready-to-paste `install.packages()` call.

**Data.** The survey is not in the repository. Copy `data_encuesta_filtrado.xlsx` into `data/raw/`; see [`data/README.md`](data/README.md).

**Run.** Always from the project folder, or by calling `run_all.R`, which moves to its own folder.

```bash
Rscript run_all.R --lista         # lists the steps
Rscript run_all.R --prueba        # the whole workflow in minutes, to check the installation
Rscript run_all.R                 # the full analysis, steps 1 to 4
```

`run_all.R` also accepts `--desde N` (from), `--hasta N` (to) and `--solo N` (only), and stops at the first failing step. Test mode (`--prueba`) uses 3 repetitions and reduced grids and writes to `results_prueba/` and `data/processed_prueba/`, so it does not touch the real results. Its figures are not the ones of the paper.

Step 2 is the long one: 1,000 repetitions by 5 folds by 3 models by 12 diseases. It saves one checkpoint per disease as soon as it finishes, so a run can be interrupted and resumed. It also accepts disease codes, so a run can be split across sessions or machines:

```bash
Rscript R/02_ajustar_modelos.R V8 V10
```

To repeat a disease, delete its file in `results/checkpoints/`. Steps 3 and 4 only read checkpoints and take seconds, so tables and figures are rebuilt without refitting. The checkpoints written by the single-file script (`checkpoints_caracterizacion/<sheet>.rds`) have the same structure: copied into `results/checkpoints/`, they feed steps 3 and 4 without running step 2 again.

The `.gitignore` at the root of the repository keeps `data/raw/`, `data/processed/`, `results/` and their test-mode counterparts out of git.

### The pipeline

| Step | Does | Main output |
|---|---|---|
| 1 | Reads the workbook, unifies the SI and NO answers, converts everything to factors and drops V5, V19, V21 and V22 | `data/processed/encuesta_modelo.rds`, `results/tables/flujo_registros.csv`, `results/tables/prevalencias.csv` |
| 2 | For each disease: chi-square, one-hot encoding, grid search for RF and XGB, repeated cross-validation of the three models, final models, hypervolume, winner and SHAP | `results/checkpoints/<sheet>.rds` |
| 3 | Builds the workbook with one sheet per disease and a summary sheet, and the same tables as CSV | `results/tables/Resultados_Unificado.xlsx`, `resumen.csv`, `comparacion_modelos.csv`, `estabilidad_cv.csv`, `shap_top.csv` |
| 4 | Draws the SHAP figure of the winning model of each disease, labelled in English | `results/figures/SHAP_<sheet>_<winner>.png` and `.pdf` |

Every step writes to `results/logs/sesion_<step>.txt` the date, the R version, the locale, the version of every package and the parameters it ran with.

Inside step 2, each disease follows this order:

1. **Variable selection.** Chi-square test between each variable and the disease over the full sample. Variables with p < 0.05 are kept and, among them, the 20 with the smallest p-value.
2. **Complete cases.** Rows with a missing value in any of those variables are dropped. The count is recorded in the configuration of the disease.
3. **One-hot encoding.** Every level becomes a 0/1 column; for SI/NO variables the NO column is dropped.
4. **Grid search** for RF (mtry and ntree) and XGB (eta, max_depth and nrounds) with 5-fold cross-validation and ROC AUC.
5. **Repeated cross-validation.** 1,000 repetitions of 5 stratified folds. In each fold the SI class is oversampled in the training part only, the model is fitted, the variables it selects are recorded and it is evaluated on the validation fold, which keeps the original proportion.
6. **Final model** of each kind, fitted on the balanced full sample.
7. **Winner.** The model with the largest hypervolume, which is the product of the mean precision, recall, F1 and ROC AUC.
8. **SHAP** values of the winning model with `fastshap` (50 Monte Carlo repetitions), over all the original rows.

### Configuration

The scripts hold no paths or fixed values: they all read the `CFG` list in [`config.R`](config.R). These are the parameters that change results, with the values of the original script:

```r
alfa_chi2     = 0.05                       # chi-square threshold
max_variables = 20                         # variables per disease
rf_ntree      = c(100, 250, 500)           # RF grid (mtry: 5 values up to 20)
xgb_eta       = c(0.01, 0.05, 0.1, 0.3)    # XGB grid
xgb_max_depth = c(2, 4, 6, 8)
xgb_nrounds   = c(100, 250, 500)
n_iter        = 1000                       # repetitions of the cross-validation
k_fold        = 5
semilla_grid  = 321                        # seeds
semilla_final = 789
semilla_shap  = 123
shap_nsim     = 50
```

### Reproducibility

- Every stage sets its own seed: `set.seed(321)` before each grid search, `set.seed(i)` in repetition `i` of the cross-validation, `set.seed(789)` before each final model and `set.seed(123)` before SHAP. The result for a disease does not depend on which diseases ran before it or on whether the run was resumed from a checkpoint.
- The grid search runs in parallel with `%dorng%`, which gives every combination its own random number stream. The result does not depend on the number of cores.
- The `xgboost` version changes the XGB numbers, because the default tree construction method differs between the 1.7 series and the later ones. The code was tested with xgboost 1.7.11.1 and has not been tested with the 3.x series. The version in use is recorded in the configuration of every disease and in `results/logs/`.
- The locale matters too: `as.factor()` orders the levels of each variable according to `LC_COLLATE`, and that order fixes the order of the one-hot columns that RF and XGB receive. It is also recorded in `results/logs/`.
- The reorganisation was compared with the single-file script on the same data, seeds and package versions (R 4.3.3, xgboost 1.7.11.1, randomForest 4.7-1.1, caret 6.0-94, fastshap 0.1.1). The tables, the winning model, the SHAP values and the predictions of the winning model matched exactly for the 12 diseases. The comparison used 3 repetitions of the cross-validation, not the 1,000.

Compared with the original script, the outputs change in three ways that do not touch the numbers: what the workbook called "bootstrap" is now "CV repetida" (repeated CV), because the code does not resample with replacement; the configuration of every disease adds the rows dropped for missing values and the versions of R, randomForest and xgboost; and the SHAP figures are drawn in step 4, labelled in English and in pastel colours.

### Licence and citation

Code under the MIT licence, see [`LICENSE`](LICENSE). The survey data are not distributed with the code and keep their own terms.

The analysis comes from the final project of Javiera Vásquez-Salgado at the Department of Informatics Engineering of the Universidad de Santiago de Chile. The reference of the paper will be added here once it is published.
