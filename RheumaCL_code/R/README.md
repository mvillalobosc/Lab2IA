# R

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los cuatro pasos del análisis y las funciones que usan. Los pasos se corren desde la carpeta del proyecto, uno por uno o con `run_all.R`. Para el contexto general, revisa el [README del proyecto](../README.md).

### Pasos

| Archivo | Qué hace |
|---|---|
| `00_inicio.R` | Lo carga cada paso. Comprueba la configuración regional, la carpeta de trabajo y los paquetes; lee `config.R`; activa el modo de prueba si se pidió (`--prueba` o `RHEUMACL_PRUEBA=1`); crea las carpetas de salida (`RUTAS`) y carga los archivos de funciones. |
| `01_preparar_datos.R` | Lee la encuesta, unifica SI y NO, convierte las columnas a factor, saca las variables excluidas y guarda la base de modelamiento. Deja también el flujo de registros y la prevalencia de cada enfermedad. |
| `02_ajustar_modelos.R` | Recorre las enfermedades, llama a `analizar_enfermedad()` y guarda un checkpoint por enfermedad. Salta las que ya tienen checkpoint y abre el cluster paralelo solo si queda algo por correr. |
| `03_tablas.R` | Lee los checkpoints y escribe el Excel y las tablas CSV. |
| `04_figuras.R` | Lee los checkpoints y dibuja la figura SHAP de cada enfermedad en PNG (300 ppp) y PDF. Si existe `data/etiquetas_variables.csv`, usa sus textos en vez de los códigos de las variables. |

### Funciones

| Archivo | Funciones |
|---|---|
| `funciones_utiles.R` | `formatear_tiempo()`, `enfermedades_pedidas()` (lee los códigos que se pasan por línea de comandos) y `registrar_sesion()` (escribe el entorno de cada paso en `results/logs/`). |
| `funciones_metricas.R` | `calcular_metricas()` (precisión, recall, F1, exactitud y AUC-ROC de un fold), `calcular_hipervolumen()`, `resumen_cv_repetida()` y `comparar_modelos()`, que arma la tabla comparativa y elige al ganador. |
| `funciones_seleccion.R` | `chi_cuadrado()`, `datos_de_modelamiento()` (casos completos en las variables elegidas) y `codificar_one_hot()`. |
| `funciones_modelos.R` | `balancear()` (sobremuestreo de la clase SI), `entrenar_xgb()`, el grid search de RF y XGB, los tres aprendices (`aprendiz_rl()`, `aprendiz_rf()`, `aprendiz_xgb()`), `cv_repetida()`, que es el único bucle de validación y recibe el aprendiz, y los modelos finales con su ranking de variables u odds ratios. |
| `funciones_shap.R` | `explicar_ganador()` (valores SHAP con `fastshap`), `tabla_shap()` y `grafico_shap()`. |
| `funciones_analisis.R` | `analizar_enfermedad()`: el flujo completo de una enfermedad, de la selección de variables a SHAP. Devuelve la lista que se guarda como checkpoint. |
| `funciones_excel.R` | Las funciones que escriben la hoja de cada enfermedad y la hoja de resumen del Excel. |

Las funciones leen sus parámetros de la lista `CFG`. Ninguna escribe en disco, salvo `registrar_sesion()`: los checkpoints, el Excel, las tablas y las figuras los guardan los pasos.

## English

This folder holds the four steps of the analysis and the functions they use. The steps run from the project folder, one at a time or through `run_all.R`. For the general context, see the [project README](../README.md).

### Steps

| File | What it does |
|---|---|
| `00_inicio.R` | Loaded by every step. Checks the locale, the working folder and the packages; reads `config.R`; turns on test mode when requested (`--prueba` or `RHEUMACL_PRUEBA=1`); creates the output folders (`RUTAS`) and loads the function files. |
| `01_preparar_datos.R` | Reads the survey, unifies SI and NO, converts the columns to factors, drops the excluded variables and saves the modelling dataset. It also writes the record flow and the prevalence of each disease. |
| `02_ajustar_modelos.R` | Goes through the diseases, calls `analizar_enfermedad()` and saves one checkpoint per disease. It skips the ones that already have a checkpoint and opens the parallel cluster only when something is left to run. |
| `03_tablas.R` | Reads the checkpoints and writes the workbook and the CSV tables. |
| `04_figuras.R` | Reads the checkpoints and draws the SHAP figure of each disease as PNG (300 dpi) and PDF. When `data/etiquetas_variables.csv` exists, it uses its texts instead of the variable codes. |

### Functions

| File | Functions |
|---|---|
| `funciones_utiles.R` | `formatear_tiempo()`, `enfermedades_pedidas()` (reads the codes given on the command line) and `registrar_sesion()` (writes the environment of each step to `results/logs/`). |
| `funciones_metricas.R` | `calcular_metricas()` (precision, recall, F1, accuracy and ROC AUC of one fold), `calcular_hipervolumen()`, `resumen_cv_repetida()` and `comparar_modelos()`, which builds the comparison table and picks the winner. |
| `funciones_seleccion.R` | `chi_cuadrado()`, `datos_de_modelamiento()` (complete cases over the selected variables) and `codificar_one_hot()`. |
| `funciones_modelos.R` | `balancear()` (oversampling of the SI class), `entrenar_xgb()`, the grid search for RF and XGB, the three learners (`aprendiz_rl()`, `aprendiz_rf()`, `aprendiz_xgb()`), `cv_repetida()`, which is the only validation loop and takes the learner, and the final models with their variable ranking or odds ratios. |
| `funciones_shap.R` | `explicar_ganador()` (SHAP values with `fastshap`), `tabla_shap()` and `grafico_shap()`. |
| `funciones_analisis.R` | `analizar_enfermedad()`: the full workflow for one disease, from variable selection to SHAP. It returns the list saved as a checkpoint. |
| `funciones_excel.R` | The functions that write the sheet of each disease and the summary sheet of the workbook. |

The functions read their parameters from the `CFG` list. None of them writes to disk, except `registrar_sesion()`: the steps save the checkpoints, the workbook, the tables and the figures.
