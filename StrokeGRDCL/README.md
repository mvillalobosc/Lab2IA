# StrokeGRDCL

[Español](#español) · [English](#english)

## Español

Este proyecto contiene el pipeline reproducible del estudio *Machine learning
characterisation of stroke in Chile using Diagnosis-Related Group records,
2019-2024*.

El flujo toma los archivos anuales de egresos hospitalarios que publica el Fondo
Nacional de Salud (FONASA), identifica los episodios de accidente
cerebrovascular (ACV) por código CIE-10, tamiza cerca de diez mil diagnósticos y
procedimientos candidatos y caracteriza nueve escenarios analíticos con un
consenso de tres modelos de selección de variables sobre 500 remuestreos
balanceados. Los modelos se usan solo para seleccionar variables, nunca para
predicción clínica individual.

El pipeline solo usa campos que cualquier sistema de egresos GRD o case-mix ya
contiene: diagnósticos y procedimientos codificados, datos demográficos básicos,
días de estada y un identificador de residencia, de modo que se puede llevar a
datos administrativos comparables de otros países.

El código, `config.yml` y `CITATION.cff` llaman al proyecto `stroke-drg-chile`;
en este repositorio vive en la carpeta `StrokeGRDCL/`.

---

### Contenido

```
StrokeGRDCL/                       stroke-drg-chile en config.yml y CITATION.cff
├── README.md
├── LICENSE                        licencia MIT del código
├── CITATION.cff                   metadatos de cita
├── config.yml                     todas las rutas, umbrales y parámetros
├── run_all.R                      ordena los nueve pasos en R
├── R/                             ver R/README.md
│   ├── utils.R                    configuración, registro, DuckDB, métricas
│   ├── lib_learners.R             los tres modelos detrás de una sola interfaz
│   ├── 01_ingest_grd.R            texto crudo a parquet, por año
│   ├── 02_clean_and_derive.R      limpieza, deduplicación, variables derivadas
│   ├── 03_define_outcomes.R       definición de caso y tabla larga de códigos
│   ├── 04_municipal_indicators.R  vínculo territorial (opcional)
│   ├── 05_split_and_screen.R      partición 70/30, tamizaje chi-cuadrado
│   ├── 06_build_model_matrix.R    columnas indicadoras y dummies de comuna
│   ├── 07_select_features.R       remuestreo y selección multimodelo
│   ├── 08_consensus.R             índice de consenso, Lasso final, valores SHAP
│   ├── 09_tables_and_figures.R    tablas del manuscrito y todas las figuras
│   ├── lib_hypervolume.R          indicador de hipervolumen
│   └── lib_shap.R                 valores SHAP exactos y sus figuras
└── data/                          sin datos versionados, ver data/README.md
    ├── README.md
    └── external/
        ├── README.md
        └── feature_labels.example.csv
```

La carpeta [`R/`](R/README.md) tiene la descripción de cada script, y
[`data/`](data/README.md) explica qué datos hay que descargar o preparar.

---

### Inicio rápido

**Requisitos.** R 4.1 o superior y once paquetes de CRAN; no hace falta otro
lenguaje:

```r
install.packages(c("DBI", "duckdb", "arrow", "data.table", "lubridate", "yaml",
                   "glmnet", "ranger", "caret", "ggplot2", "readr"))
```

`readr` solo se usa si algún año viene en UTF-16. El resto es R base o uno de
los otros diez paquetes. Ningún script instala paquetes: si falta alguno, el
paso se detiene y muestra la llamada a `install.packages()` lista para copiar.

**Datos.** Cree a mano la carpeta `data/raw/grd/` (el código crea las demás
carpetas de trabajo, pero no esa) y descargue ahí los seis archivos anuales. Los
detalles están en [`data/README.md`](data/README.md).

**Ejecución.** Siempre desde la carpeta del proyecto, porque `load_config()`
busca `config.yml` en el directorio de trabajo (o en la ruta que indique la
variable de entorno `STROKE_DRG_CONFIG`).

```bash
Rscript run_all.R --list          # muestra los pasos
Rscript run_all.R                 # el pipeline completo, pasos 1 a 9
```

o paso a paso, que es lo recomendable la primera vez:

```bash
Rscript run_all.R --to 6          # de la ingesta a la matriz de modelos
Rscript R/07_select_features.R    # selección, el paso largo
Rscript R/08_consensus.R          # consenso, Lasso final, valores SHAP
Rscript R/09_tables_and_figures.R # hipervolumen, tablas, todas las figuras
```

`run_all.R` también acepta `--from N`, `--to N` y `--only N`. Se detiene en el
primer paso que falla, salvo en el paso 4, que es opcional: si falta
`data/external/municipal_indicators.csv`, el paso 4 falla, `run_all.R` sigue con
el paso 5 y el paso 9 omite la Tabla 2 y las Tablas S2 a S4 con un aviso en su
registro.

Los pasos 7 y 8 aceptan el nombre de un escenario, así que una corrida larga se
puede repartir entre sesiones o máquinas:

```bash
Rscript R/07_select_features.R D1_ACV_GENERAL
Rscript R/07_select_features.R D1_HEM_VS_ISQ
```

Cada paso deja un registro con hora en `results/logs/<paso>.log` y una copia del
entorno que lo produjo en `results/run_metadata_<paso>.txt`. Los pasos 1, 2, 3 y
5 anotan en `results/tables/record_flow.csv` cuántos registros quedan después de
cada regla; si se repite un paso, sus filas reemplazan a las anteriores, así que
el flujo de registros que el paso 9 escribe en `record_flow.tex` no se duplica.

**Tiempos aproximados:** 40 a 90 minutos para el paso 1 (unos 4 GB de texto), 20
a 40 minutos para los pasos 2 a 6 y 3 a 6 horas para el paso 7 en una máquina de
cuatro núcleos. Los pasos 8 y 9 toman minutos.

El `.gitignore` de la raíz del repositorio deja fuera de git `data/raw/`,
`data/interim/`, `data/processed/`, los dos archivos que usted crea en
`data/external/` y `results/`.

---

### El pipeline

| Paso | Qué hace | Salida principal |
|---|---|---|
| 1 | lee cada año detectando su codificación, interpreta fechas y columnas numéricas y conserva los códigos como texto | `data/interim/grd_<año>.parquet` |
| 2 | elimina filas vacías y fechas inconsistentes, deduplica y deriva edad, días de estada y sexo binario | `data/interim/grd_clean.parquet` |
| 3 | aplica la definición de caso CIE-10 y despivota todas las columnas de códigos en una tabla larga | `data/processed/discharges.parquet`, `data/interim/code_long.parquet` |
| 4 | vincula los indicadores comunales por nombre normalizado más distancia de Levenshtein | `data/processed/municipal_indicators.parquet` |
| 5 | hace la partición 70/30 estratificada y después el tamizaje chi-cuadrado dentro del subconjunto de desarrollo | `results/tables/selected_features.csv` |
| 6 | arma las columnas indicadoras, las dummies de comuna y la matriz de análisis | `data/processed/model_matrix.parquet` |
| 7 | toma 500 remuestreos balanceados, ajusta tres modelos en cada uno y guarda métricas y frecuencias de selección | `results/selection/*.csv` |
| 8 | calcula el índice de consenso, ajusta el Lasso final ponderado por clase y obtiene valores SHAP exactos | `results/tables/consensus_*.csv`, `results/final_model/*.csv`, incluido `<escenario>_shap_features.csv`, que el paso 9 necesita |
| 9 | calcula el hipervolumen y arma la Tabla 1, la Tabla S1, la Tabla 2 y todas las figuras | `results/tables/*.csv` y `.tex`, `results/figures/*` |

Todos los archivos intermedios son parquet y toda operación pesada corre dentro
de DuckDB, así que R nunca carga en memoria la tabla de 5,8 millones de filas.

#### Qué salida alimenta cada parte del manuscrito

| Elemento del manuscrito | Lo produce |
|---|---|
| Flujo de registros (5 808 542 a 5 801 438) | `results/tables/record_flow.csv`, que el paso 9 pasa a `record_flow.tex` |
| Tabla 1, comparación de modelos | paso 9, `table1_model_comparison.csv` / `.tex` |
| Tabla 2, indicadores comunales | paso 9, `table2_municipal_indicators.csv` / `.tex` |
| Tabla S1, los tres modelos | paso 9, `tableS1_all_models.csv` / `.tex` |
| Tablas S2 a S4, perfiles comunales | paso 9, `tableS2_S4_municipal_profiles.csv` |
| Figura 1, flujo de trabajo | se dibujó a mano, no se genera |
| Figura 2 y Figuras S4 a S11, SHAP | el paso 8 calcula y el paso 9 dibuja un `figure_shap_<escenario>.pdf` por escenario; el código no registra qué escenario corresponde a cada número de figura |
| Figura 3, episodios por comuna | paso 9, `figure3_episodes_by_municipality.pdf` |
| Figuras S1 a S3, subtipo por comuna | paso 9, `figureS1_subtype_puente_alto.pdf`, `figureS2_subtype_coquimbo.pdf` y `figureS3_subtype_san_carlos.pdf`, en el orden de `reporting$focus_municipalities` |

---

### Configuración

Ningún script tiene rutas ni valores fijos en el código. Los interruptores que
cambian resultados, y no solo la plomería, son:

```yaml
case_definition:
  mode: "manuscript"                          # o "extended"
  exclude_outcome_codes_from_predictors: true
model_matrix:
  provenance_aware_indicators: false
  min_comuna_records: 0
resampling:
  n_replicates: 500
  n_per_class: 100
models:
  lasso:
    selection_rule: "nonzero"
  random_forest:
    selection_rule: "top_k"                   # o "above_mean", "positive"
  knn:
    selection_rule: "top_k"                   # o "auc_above", "all_retained"
hypervolume:
  mode: "mean"                                # o "front"
```

Cada uno está documentado en `config.yml`, con una nota sobre qué valor
reproduce la corrida publicada.

#### Reproducibilidad

- El muestreo usa el generador aleatorio de R con una semilla explícita por
  réplica, así que la misma semilla vuelve a generar los mismos 500 remuestreos.
  El original los sacaba con `ORDER BY random()` dentro de DuckDB, algo que
  `set.seed()` de R no controla.
- La partición 70/30 y la submuestra del ajuste final ordenan los registros por
  `HASH(RECORD_ID, seed)` en vez de `random()`, de modo que el resultado no
  depende del número de hilos.
- Random Forest corre en un solo hilo, y eso es lo que le da sentido a su
  semilla.
- Los tres modelos ven los mismos remuestreos y la misma asignación de pliegues,
  así que una diferencia entre modelos es una diferencia entre modelos.
- Los valores p se comparan en escala log10. Con el umbral que usa el estudio
  (5e-100), tanto el valor p crudo como el ajustado se vuelven exactamente cero
  en doble precisión y dejan de poder ordenarse.

---

### Diferencias entre este código y la corrida publicada

`config.yml` se refiere a esta sección como "Deviations from the published run".

Esta sección es la razón para leer el README antes que el código. Los scripts
que se entregaron eran `Base de datos.Rmd` y `KNN.Rmd`: el Lasso, el Random
Forest, el hipervolumen, el paso SHAP, la partición 70/30 y el vínculo con CASEN
y el Censo no venían entre ellos, y aquí se reimplementan a partir de la sección
de Métodos. Cuando una decisión no se pudo recuperar del manuscrito, la opción
que se tomó queda documentada en el archivo que la aplica.

Cuatro de las diferencias son sustantivas.

#### 1. La Tabla 1 y la Tabla S1 no calzan con los archivos por réplica

Al promediar las 500 réplicas de los archivos entregados
`resultados_knn_500iter_*.csv` se reproduce la columna de precisión de las filas
KNN de la Tabla S1 en los nueve escenarios, pero la sensibilidad, el F1 y la
exactitud solo en cuatro.

| Escenario | Tabla S1, KNN | Recalculado desde el CSV |
|---|---|---|
| ACV, principal | 0.9541 / 0.7822 / 0.7678 / 0.7652 | 0.9541 / **0.5979 / 0.7190 / 0.7829** |
| ACV, secundario | 0.9395 / 0.9114 / 0.8898 / 0.8870 | 0.9395 / **0.3993 / 0.5466 / 0.6858** |
| Hemorrágico, principal | 0.9497 / 0.8905 / 0.8715 / 0.8692 | 0.9497 / **0.4633 / 0.6040 / 0.7180** |
| Hemorrágico, secundario | 0.9565 / 0.3249 / 0.4758 / 0.6544 | 0.9565 / 0.3249 / 0.4758 / 0.6544 |
| Isquémico, principal | 0.9596 / 0.8241 / 0.8010 / 0.7951 | 0.9596 / **0.6714 / 0.7773 / 0.8201** |
| Isquémico, secundario | 0.9417 / 0.4361 / 0.5788 / 0.7031 | 0.9418 / 0.4361 / 0.5788 / 0.7031 |
| No especificado, principal | 0.9191 / 0.6779 / 0.6629 / 0.6556 | 0.9191 / **0.6734 / 0.7641 / 0.8040** |
| No especificado, secundario | 0.8606 / 0.4363 / 0.5611 / 0.6789 | 0.8606 / 0.4363 / 0.5611 / 0.6790 |
| Hemorrágico frente a isquémico | 0.6574 / 0.8475 / 0.7304 / 0.6891 | 0.6574 / 0.8475 / 0.7304 / 0.6891 |

Los tríos que no calzan no son al azar: reaparecen en otras partes de las mismas
tablas. `0.7822 / 0.7678 / 0.7652` es también la fila RF de "Haemorrhagic versus
ischaemic" en la Tabla S1. `0.3249 / 0.4758 / 0.6544`, que corresponde a KNN en
hemorrágico secundario, es también la fila RLM de "Haemorrhagic stroke,
principal" en la Tabla 1. `0.6734 / 0.7641 / 0.8040`, que corresponde a KNN en no
especificado principal, es también la fila RLM de "Stroke, principal diagnosis"
en la Tabla 1. Ese patrón es la firma de un cruce de tablas en que las columnas
de sensibilidad, F1 y exactitud se pegaron con un índice de fila desplazado
mientras la precisión quedó bien.

Solo KNN se puede revisar, porque los archivos por réplica del Lasso y del
Random Forest no venían en el archivo entregado. El mismo paso de armado produjo
los tres grupos de filas, así que hay que regenerar ambas tablas y volver a
examinar el orden de modelos que respaldan.

La columna de hipervolumen tiene un problema aparte: informa exactamente 0.0625
para cuatro escenarios cuyos vectores de métricas difieren bastante, y 0.0625 es
0.5 elevado a la cuarta. Un hipervolumen no puede ser insensible al punto desde
el que se calcula.

El paso 9 rehace ambas tablas desde `results/selection/metrics_*.csv` y
recalcula el hipervolumen desde los mismos archivos, con el punto de referencia y
el modo que fija la configuración. Ninguna de las dos tablas vuelve a
transcribirse a mano.

#### 2. La definición de caso del código no es la de la sección de Métodos

La sección de Métodos declara infarto cerebral I63, hemorragia intracerebral I61
y ACV no especificado I64. El código entregado usa:

```sql
ischaemic    ^I63 OR ^I65 OR ^I66
haemorrhagic ^I60 OR ^I61 OR ^I62
unspecified  ^I64
```

Luego el filtro chi-cuadrado excluye de los predictores candidatos solo `I63`,
`I61` e `I64`, así que `I60.9` e `I62.0` siguen como variables mientras también
definen el resultado hemorrágico. Aparecen en los archivos de frecuencia
entregados como `DIAG2_35_I60_9` y `DIAG2_35_I62_0`, y son las dos primeras
variables de la Figura Suplementaria S11.

La consecuencia es que "subdural and subarachnoid haemorrhage characterised the
haemorrhagic subtype" es en parte circular con la definición que de verdad usó el
código: un registro codificado I62.0 es hemorrágico por construcción. Con la
definición que declara la sección de Métodos, donde hemorrágico es solo I61, el
mismo hallazgo es legítimo y se lee como un sangrado concurrente.

I65 e I66 también son discutibles como ACV isquémico: codifican oclusión y
estenosis de arterias cerebrales y precerebrales *sin* infarto.

`case_definition$mode` elige entre las dos definiciones. El valor por defecto es
`manuscript`, y `extended` reproduce la corrida publicada. Por separado,
`exclude_outcome_codes_from_predictors` (por defecto `true`) quita del conjunto
candidato toda familia de códigos que define el resultado activo, lo que cierra
la fuga en cualquiera de los dos modos; con `false` se reproduce el
comportamiento publicado. Ambas opciones quedan registradas en
`results/run_metadata_*.txt` en cada corrida.

#### 3. Los códigos de procedimiento terminados en cero se corrompían

`Base de datos.Rmd` incluye `PROCEDIMIENTO1` a `PROCEDIMIENTO11` en la lista de
columnas numéricas:

```r
cols_num <- c(paste0("PESORN", 1:4), paste0("PROCEDIMIENTO", 1:11), ...)
```

Los códigos de procedimiento CIE-9-CM no son números. Tras pasar por doble
precisión, 99.10 (inyección de agente trombolítico) se convierte en 99.1 y 89.50
en 89.5, mientras los mismos códigos quedan intactos en `PROCEDIMIENTO12` a
`PROCEDIMIENTO30`, que se dejaron como texto. Así, un mismo código se vuelve dos
textos distintos según la columna en que cayó, y el indicador construido con él
queda subcontado.

El efecto se ve en el propio manuscrito: la Figura Suplementaria S11 rotula sus
variables "Thrombolytic injection (99.1)" y "Non-surgical heart and vessel
examination (89.5)", y ninguno de los dos es un código CIE-9-CM completo. La
trombólisis es uno de los hallazgos principales del estudio para el subtipo
isquémico, así que vale la pena reconstruir los conteos que la sostienen.

Aquí los códigos se mantienen como texto en todas partes, y ninguna columna de
diagnóstico o procedimiento pasa por `as.numeric`.

#### 4. Dos de las tres frecuencias de selección son degeneradas

El índice de consenso es el promedio de las tres frecuencias de selección por
modelo, así que solo aporta información si la selección de cada modelo en cada
remuestreo es un subconjunto real de las variables candidatas. Dos de las tres no
lo son.

*KNN.* El original registraba `rownames(varImp(model)$importance)`, que es cada
columna que sobrevivió al filtro de varianza casi nula, sin mirar nunca los
valores. Los conteos miden la supervivencia a un filtro de varianza, no la
importancia. Se nota en los archivos entregados: decenas de variables quedan
exactamente en 500 de 500 en `frecuencia_variables_knn_*.csv`, incluidas algunas
como `PROC_90_39` que no tienen una razón particular para quedar seleccionadas en
cada remuestreo.

*Random Forest.* La regla obvia, importancia por impureza mayor que cero, casi
siempre se cumple. Medido en un remuestreo de la misma forma que los reales, con
200 filas y 122 columnas tras el filtro de varianza, un bosque de 500 árboles da
importancia estrictamente positiva a **122 de 122** columnas.

*KNN, segundo intento.* `caret::filterVarImp` informa el mayor entre AUC y 1 -
AUC, así que su puntaje nunca baja de 0.5 y un corte en 0.5 selecciona **114 de
122**.

Con dos frecuencias clavadas cerca de 1 para cualquier variable, el índice de
consenso es en la
práctica la frecuencia del Lasso más una constante, y el "consenso de tres
modelos complementarios" es un modelo con dos abstenciones.

La regla que usa cada modelo ahora es configurable. Por defecto, el Lasso cuenta
los coeficientes distintos de cero y los otros dos modelos usan una regla de
rango: una variable cuenta como seleccionada en un remuestreo cuando está entre
las `consensus$top_n_features` primeras de ese modelo por importancia. Es la
lectura habitual de la selección por estabilidad y se puede comparar entre
modelos. En el mismo remuestreo sintético, los valores por defecto seleccionan 6,
30 y 30 de 122 en vez de 10, 122 y 114, los tres recuperan todas las variables
informativas plantadas y el índice de consenso se reparte entre 0.19 y 1.00 en
vez de amontonarse arriba. `selection_rule: "positive"` y
`selection_rule: "all_retained"` reproducen el comportamiento original.

#### Diferencias menores

| Qué | Corrida publicada | Aquí |
|---|---|---|
| Edad | `DATE_DIFF('year', birth, admission)`, que cuenta cambios de año calendario y sobrestima en un año la edad de quien cumple años después de la fecha de ingreso | años cumplidos |
| Edad 0 | se pasaba a faltante y luego se imputaba con la mediana, lo que empuja los egresos obstétricos y neonatales al centro de la distribución adulta | se mantiene como válida, porque edad 0 significa menos de un año; `cleaning$treat_age_zero_as_missing` restaura el comportamiento anterior |
| Diagnóstico principal faltante | `REGEXP_MATCHES(NULL, ...)` devuelve NULL, así que `WHERE outcome = 0` sacaba en silencio esos registros del grupo de controles | las marcas de resultado valen 0, no NULL; solo el contraste hemorrágico frente a isquémico conserva los NULL, donde significan "no comparable" |
| Imputación de edad y días de estada | mediana de cada remuestreo, de modo que el valor imputado depende del remuestreo | mediana del subconjunto de desarrollo, calculada una vez en el paso 5 |
| Partición 70/30 | no está en el código entregado, aunque la sección de Métodos la informa | paso 5, estratificada y basada en hash |
| Tamizaje chi-cuadrado | una consulta SQL por código y por resultado, cerca de veinte mil recorridos de una tabla de 5,8 millones de filas, y luego `chisq.test()` en cada tabla 2x2 | un solo cruce agrupado sobre la tabla larga de códigos, con el estadístico en forma cerrada y vectorizado |
| Alcance del tamizaje | el conjunto de datos completo | solo el subconjunto de desarrollo, como describe la sección de Métodos |
| Valores candidatos de k para KNN | `seq(3, 25, by = 2)`, doce valores; los archivos de resultados entregados no tienen columna `K_usado`, así que vienen de una versión anterior que reajustaba k dentro de cada réplica | cinco valores, como informa la sección de Métodos, ajustados una vez por escenario y luego fijos |
| Registros codificados con ambos subtipos | quedaban como isquémicos por el orden del `CASE WHEN` | se excluyen del contraste de subtipos como no comparables |
| Dummies de comuna | una por cada texto crudo distinto, así que `CONCEPCION`, `CONCEPCIÓN` y `CONCEPCI<D3>N` producían columnas separadas; el código entregado lo repara en los nombres de las dummies, pero no aplica la misma normalización de forma consistente en los pasos previos | una sola función de normalización, usada para las dummies, el vínculo y las figuras |
| Vínculo territorial | no está en el código entregado | paso 4, con un archivo de auditoría para cada decisión de emparejamiento |

#### Una nota de procedencia

El `Base de datos.Rmd` entregado recalcula el tamizaje chi-cuadrado, pero la
columna `origen` que implican los nombres de variables publicados (`DIAG1`,
`DIAG2_35`, `PROC`) la crea una rama que solo se ejecuta cuando la columna no
existe, y esa rama produciría `D` y `PROC` en vez de los prefijos observados. Eso
indica que la corrida publicada leyó su lista de códigos significativos desde un
CSV previo (`chi2_sig_corregido_final.csv`) y no desde el código tal como se
entregó. Importa para la frase "code available from the corresponding author on
request": lo que se entregó es una reconstrucción del análisis, no el script que
produjo los números publicados. Este pipeline regenera el tamizaje desde los
archivos crudos, así que su lista de variables se puede derivar de principio a
fin.

---

### Qué se verificó

El núcleo numérico se revisó contra referencias independientes, no solo leyendo
el código:

| Componente | Prueba | Resultado |
|---|---|---|
| tamizaje chi-cuadrado | estadístico, valor p y conteo esperado mínimo contra `chisq.test(correct = FALSE)` en 300 tablas 2x2 al azar | coincide hasta 1e-8 |
| valores p en escala log | una tabla del tamaño que produce este estudio | chi-cuadrado 4 019 873, log10(p) = -872 908, cuando el valor p crudo es exactamente 0 en doble precisión |
| desborde de enteros | el producto de los cuatro marginales con entradas enteras | se detectó y se corrigió; la función convierte primero a doble precisión |
| hipervolumen | 2, 3 y 4 dimensiones contra valores calculados por inclusión y exclusión, más un punto de referencia distinto del origen y puntos bajo la referencia | exacto |
| aditividad SHAP | valor base más contribuciones contra el predictor lineal | error máximo 1.8e-15, y el script se niega a escribir resultados sobre 1e-8 |
| partición 70/30 | la misma partición recalculada con 1 y con 8 hilos de DuckDB | conjuntos de registros idénticos |
| dialecto SQL | cada sentencia generada se corrió contra DuckDB 1.5.5 sobre una tabla sintética: `union_by_name`, deduplicación con `QUALIFY` sobre todas las columnas de contenido, orden por `HASH`, `DATE_DIFF` con `STRFTIME`, el despivote, `REGEXP_MATCHES`, la cadena de normalización de comunas, `* EXCLUDE`, `COPY ... COMPRESSION ZSTD` | todas se ejecutan |
| figura SHAP | estructura del gráfico construido: dos cajas por variable, ambos colores de grupo, línea de cero, orden y qué filas se reducen a marcas planas | 14 cajas para 7 variables, 10 de ellas planas, justo los indicadores binarios |
| los tres modelos | se ajustaron en remuestreos sintéticos con la forma real y tres variables informativas plantadas | los tres las recuperan; Lasso y Random Forest se reproducen exactamente desde una semilla |
| métricas y pliegues | precisión, sensibilidad, F1, exactitud y AUC contra valores calculados a mano; pliegues por reproducibilidad y estratificación | exacto |
| normalización de comunas | `CONCEPCION`, `CONCEPCIÓN` y `CONCEPCI<D3>N` | se reducen a una sola clave |

Lo que no se ha corrido es el pipeline sobre los archivos reales, que necesita
los 4 GB de datos de FONASA. Los tiempos de este README son estimaciones.

---

### Resumen del método

**Identificación de casos.** Los casos se identifican por código CIE-10 según
`case_definition$mode`. El diagnóstico principal (`DIAGNOSTICO1`) se distingue de
los diagnósticos secundarios (`DIAGNOSTICO2` a `DIAGNOSTICO35`), un contraste que
el texto llama jerarquía diagnóstica.

**Tamizaje.** Los registros se dividen 70/30, estratificados por presencia de
ACV. Dentro del subconjunto de desarrollo, cada código distinto de diagnóstico y
procedimiento se prueba contra la presencia de ACV con una prueba chi-cuadrado de
Pearson sobre una tabla 2x2, sin corrección de continuidad, y se descartan las
tablas con algún conteo esperado menor que cinco. Los valores p se ajustan por
Bonferroni sobre el número de códigos probados y se comparan en escala log10
contra 5e-100. Es una regla pragmática de tamizaje en alta dimensión, no un
control formal de la tasa de error por familia.

**Selección.** Para cada uno de los nueve escenarios se sacan 500 remuestreos de
100 casos y 100 controles del subconjunto de desarrollo. En cada remuestreo se
ajustan tres modelos: una regresión logística con penalización Lasso (`glmnet`,
lambda por validación cruzada interna), un Random Forest (`ranger`, 500 árboles,
mtry = sqrt(p)) y K vecinos más cercanos (`caret::knn3` sobre predictores
estandarizados). La frecuencia de selección es la proporción de remuestreos en
que un modelo seleccionó la variable, y el índice de consenso es el promedio de
las tres frecuencias. Por escenario se conservan las 30 variables de mayor
consenso.

**Comparación.** La precisión, la sensibilidad, el F1 y la exactitud salen de las
predicciones fuera de pliegue agrupadas de una partición estratificada común de
10 pliegues, y se combinan con el indicador de hipervolumen, que es monótono
respecto de la dominancia de Pareto y no necesita pesos. Son diagnósticos del
flujo de selección, no afirmaciones sobre utilidad clínica.

**Interpretación.** Sobre el subconjunto de desarrollo, restringido a las
variables de consenso, se ajusta un Lasso ponderado por clase. Como el modelo es
lineal, los valores SHAP son exactos y tienen forma cerrada,
`phi_ij = beta_j * (x_ij - E[x_j])`, en escala log-odds, de modo que no hay
aproximación ni una implementación SHAP externa. El paso 8 verifica que las
contribuciones sumen el predictor lineal y no escribe nada si no lo hacen.

**Cómo leer las figuras SHAP.** Un indicador binario en un modelo lineal solo
puede tomar dos valores SHAP, así que su fila son dos marcas delgadas, mientras
una variable continua como la edad se abre en una caja con bigotes. El ancho de
una fila refleja el rango de valores de la variable, no su importancia; la
importancia la indica el orden.

---

### Limitaciones heredadas de la fuente de datos

Los registros GRD no traen puntaje NIHSS, hora de inicio de síntomas, demora
prehospitalaria, detalle de imágenes, momento de los tratamientos, estado
funcional al alta ni seguimiento. La gravedad solo se puede aproximar con
procedimientos como ventilación y cuidados críticos. La práctica de codificación
varía entre establecimientos y en el tiempo, y un código no especificado puede
reflejar incertidumbre clínica, documentación incompleta o costumbres locales de
codificación.

La unidad de análisis es el egreso, no una persona vinculada de forma única: no
se pueden excluir los ingresos repetidos y los conteos de episodios no son
conteos de personas. Los indicadores comunales son agregados y no se pueden
trasladar a individuos sin riesgo de sesgo ecológico. Los conteos absolutos por
comuna no son incidencia, porque no se aplican denominadores de población ni
estandarización por edad.

---

### Cita

[`CITATION.cff`](CITATION.cff) trae los metadatos de cita del software y del
artículo: el título, el año 2026 y la autora registrada en el archivo, Ivania
Elena Guzmán-Madriaga (Departamento de Ingeniería Informática, Universidad de
Santiago de Chile). El archivo no incluye revista ni DOI.

### Licencia

El código usa la licencia MIT; ver [`LICENSE`](LICENSE). Las fuentes de datos
(FONASA, la encuesta CASEN 2022 y el Censo 2024) tienen sus propios términos de
uso.

## English

This project holds the reproducible pipeline for the study *Machine learning
characterisation of stroke in Chile using Diagnosis-Related Group records,
2019-2024*.

The workflow takes the yearly hospital discharge files published by the National
Health Fund (FONASA), identifies stroke episodes by ICD-10 code, screens roughly
ten thousand candidate diagnoses and procedures, and characterises nine
analytical scenarios through a consensus of three feature selection models over
500 balanced resamples. Models are used for feature selection only, never for
individual clinical prediction.

Only fields that any DRG or case-mix discharge system already contains are used:
coded diagnoses, coded procedures, basic demographics, length of stay and a
residence identifier, so the pipeline can be ported to comparable administrative
data in other countries.

The code, `config.yml` and `CITATION.cff` call the project `stroke-drg-chile`;
in this repository it lives in the `StrokeGRDCL/` folder.

---

### Contents

```
StrokeGRDCL/                       stroke-drg-chile in config.yml and CITATION.cff
├── README.md
├── LICENSE                        MIT licence of the code
├── CITATION.cff                   citation metadata
├── config.yml                     every path, threshold and parameter
├── run_all.R                      sequences the nine R steps
├── R/                             see R/README.md
│   ├── utils.R                    configuration, logging, DuckDB, metrics
│   ├── lib_learners.R             the three models behind one interface
│   ├── 01_ingest_grd.R            raw text to parquet, per year
│   ├── 02_clean_and_derive.R      cleaning, deduplication, derived variables
│   ├── 03_define_outcomes.R       case definition and long code table
│   ├── 04_municipal_indicators.R  territorial linkage (optional)
│   ├── 05_split_and_screen.R      70/30 partition, chi-square screening
│   ├── 06_build_model_matrix.R    indicator columns and comuna dummies
│   ├── 07_select_features.R       resampling and multimodel selection
│   ├── 08_consensus.R             consensus index, final Lasso, SHAP values
│   ├── 09_tables_and_figures.R    manuscript tables and all figures
│   ├── lib_hypervolume.R          hypervolume indicator
│   └── lib_shap.R                 exact SHAP values and the SHAP figures
└── data/                          no data committed, see data/README.md
    ├── README.md
    └── external/
        ├── README.md
        └── feature_labels.example.csv
```

The [`R/`](R/README.md) folder describes each script, and [`data/`](data/README.md)
explains which data you have to download or prepare.

---

### Quick start

**Requirements.** R 4.1 or later and eleven CRAN packages; no other runtime is
needed:

```r
install.packages(c("DBI", "duckdb", "arrow", "data.table", "lubridate", "yaml",
                   "glmnet", "ranger", "caret", "ggplot2", "readr"))
```

`readr` is only used if a year turns out to be UTF-16. Everything else is either
base R or one of the other ten packages. No script installs packages: a missing
one stops the step with a ready-to-paste `install.packages()` call.

**Data.** Create `data/raw/grd/` by hand (the code creates every other working
folder, not that one) and download the six yearly files into it. See
[`data/README.md`](data/README.md).

**Run.** Always from the project folder, because `load_config()` looks for
`config.yml` in the working directory (or at the path given by the
`STROKE_DRG_CONFIG` environment variable).

```bash
Rscript run_all.R --list          # what the steps are
Rscript run_all.R                 # the whole pipeline, steps 1 to 9
```

or step by step, which is what you want the first time:

```bash
Rscript run_all.R --to 6          # ingestion through model matrix
Rscript R/07_select_features.R    # selection, the long step
Rscript R/08_consensus.R          # consensus, final Lasso, SHAP values
Rscript R/09_tables_and_figures.R # hypervolume, tables, all figures
```

`run_all.R` also accepts `--from N`, `--to N` and `--only N`. It stops at the
first failing step except step 4, which is optional: without
`data/external/municipal_indicators.csv` step 4 fails, `run_all.R` carries on
with step 5 and step 9 skips Table 2 and Tables S2 to S4 with a warning in its
log.

Steps 7 and 8 accept a scenario name, so a long run can be split across sessions
or machines:

```bash
Rscript R/07_select_features.R D1_ACV_GENERAL
Rscript R/07_select_features.R D1_HEM_VS_ISQ
```

Every step writes a timestamped log to `results/logs/<step>.log` and a copy of
the environment that produced it to `results/run_metadata_<step>.txt`. Steps 1,
2, 3 and 5 record in `results/tables/record_flow.csv` how many records remain
after each rule; when a step is re-run its rows replace the earlier ones, so the
record flow that step 9 writes to `record_flow.tex` has no repeated rows.

**Expect roughly:** 40 to 90 minutes for step 1 (about 4 GB of text), 20 to 40
minutes for steps 2 to 6, and 3 to 6 hours for step 7 on a four-core machine.
Steps 8 and 9 take minutes.

The `.gitignore` at the root of the repository keeps `data/raw/`,
`data/interim/`, `data/processed/`, the two files you create in `data/external/`
and `results/` out of git.

---

### The pipeline

| Step | Does | Main output |
|---|---|---|
| 1 | reads each year with encoding detection, parses dates and numerics, keeps codes as text | `data/interim/grd_<year>.parquet` |
| 2 | drops empty rows and inconsistent dates, deduplicates, derives age, length of stay and binary sex | `data/interim/grd_clean.parquet` |
| 3 | applies the ICD-10 case definition, unpivots all code columns into a long table | `data/processed/discharges.parquet`, `data/interim/code_long.parquet` |
| 4 | links municipal indicators by normalised name plus Levenshtein distance | `data/processed/municipal_indicators.parquet` |
| 5 | makes the stratified 70/30 partition, then runs the chi-square screening inside the development subset | `results/tables/selected_features.csv` |
| 6 | builds the indicator columns, the comuna dummies and the analysis matrix | `data/processed/model_matrix.parquet` |
| 7 | draws 500 balanced resamples, fits three models on each and records metrics and selection frequencies | `results/selection/*.csv` |
| 8 | computes the consensus index, fits the final class-weighted Lasso and derives exact SHAP values | `results/tables/consensus_*.csv`, `results/final_model/*.csv`, including `<scenario>_shap_features.csv`, which step 9 needs |
| 9 | computes the hypervolume, then builds Table 1, Table S1, Table 2 and every figure | `results/tables/*.csv` and `.tex`, `results/figures/*` |

Every intermediate file is parquet and every heavy operation runs inside DuckDB,
so R never holds the 5.8-million-row table in memory.

#### Which output feeds which part of the manuscript

| Manuscript element | Produced by |
|---|---|
| Record flow (5 808 542 to 5 801 438) | `results/tables/record_flow.csv`, which step 9 turns into `record_flow.tex` |
| Table 1, model comparison | step 9, `table1_model_comparison.csv` / `.tex` |
| Table 2, municipal indicators | step 9, `table2_municipal_indicators.csv` / `.tex` |
| Table S1, all three models | step 9, `tableS1_all_models.csv` / `.tex` |
| Tables S2 to S4, municipal profiles | step 9, `tableS2_S4_municipal_profiles.csv` |
| Figure 1, workflow | drawn by hand, not generated |
| Figure 2 and Figures S4 to S11, SHAP | step 8 computes, step 9 draws one `figure_shap_<scenario>.pdf` per scenario; the code does not record which scenario is which figure number |
| Figure 3, episodes by municipality | step 9, `figure3_episodes_by_municipality.pdf` |
| Figures S1 to S3, subtype by municipality | step 9, `figureS1_subtype_puente_alto.pdf`, `figureS2_subtype_coquimbo.pdf` and `figureS3_subtype_san_carlos.pdf`, in the order of `reporting$focus_municipalities` |

---

### Configuration

Nothing is hard-coded in the scripts. The switches that change results rather
than plumbing:

```yaml
case_definition:
  mode: "manuscript"                          # or "extended"
  exclude_outcome_codes_from_predictors: true
model_matrix:
  provenance_aware_indicators: false
  min_comuna_records: 0
resampling:
  n_replicates: 500
  n_per_class: 100
models:
  lasso:
    selection_rule: "nonzero"
  random_forest:
    selection_rule: "top_k"                   # or "above_mean", "positive"
  knn:
    selection_rule: "top_k"                   # or "auc_above", "all_retained"
hypervolume:
  mode: "mean"                                # or "front"
```

Each is documented in place in `config.yml`, with a note on which value
reproduces the published run.

#### Reproducibility

- Sampling uses R's RNG with an explicit per-replicate seed, so the same seed
  regenerates the same 500 resamples. The original drew them with
  `ORDER BY random()` inside DuckDB, which `set.seed()` in R does not control.
- The 70/30 partition and the subsample of the final fit rank records by
  `HASH(RECORD_ID, seed)` rather than by `random()`, so the result does not depend
  on the thread count.
- Random Forest runs single-threaded, which is what makes its seed meaningful.
- The three models see the same resamples and the same fold assignment, so a
  difference between models is a difference between models.
- p-values are compared on the log10 scale. At the threshold this study uses
  (5e-100) both the raw and the adjusted p-value underflow to exactly zero in
  double precision and stop being rankable.

---

### Differences between this code and the published run

`config.yml` refers to this section as "Deviations from the published run".

This section is the reason to read the README before the code. The scripts that
were handed over consisted of `Base de datos.Rmd` and `KNN.Rmd`: the Lasso, the
Random Forest, the hypervolume, the SHAP step, the 70/30 partition and the
CASEN/Census linkage were not among them, and are reimplemented here from the
Methods section. Where a decision could not be recovered from the manuscript, the
choice made here is documented in the file that makes it.

Four of the differences are substantive.

#### 1. Table 1 and Table S1 do not match the per-replicate output files

Averaging the 500 replicates in the delivered `resultados_knn_500iter_*.csv`
reproduces the precision column of the KNN rows of Table S1 in all nine
scenarios, and reproduces sensitivity, F1 and accuracy in only four.

| Scenario | Table S1, KNN | Recomputed from the CSV |
|---|---|---|
| Stroke, principal | 0.9541 / 0.7822 / 0.7678 / 0.7652 | 0.9541 / **0.5979 / 0.7190 / 0.7829** |
| Stroke, secondary | 0.9395 / 0.9114 / 0.8898 / 0.8870 | 0.9395 / **0.3993 / 0.5466 / 0.6858** |
| Haemorrhagic, principal | 0.9497 / 0.8905 / 0.8715 / 0.8692 | 0.9497 / **0.4633 / 0.6040 / 0.7180** |
| Haemorrhagic, secondary | 0.9565 / 0.3249 / 0.4758 / 0.6544 | 0.9565 / 0.3249 / 0.4758 / 0.6544 |
| Ischaemic, principal | 0.9596 / 0.8241 / 0.8010 / 0.7951 | 0.9596 / **0.6714 / 0.7773 / 0.8201** |
| Ischaemic, secondary | 0.9417 / 0.4361 / 0.5788 / 0.7031 | 0.9418 / 0.4361 / 0.5788 / 0.7031 |
| Unspecified, principal | 0.9191 / 0.6779 / 0.6629 / 0.6556 | 0.9191 / **0.6734 / 0.7641 / 0.8040** |
| Unspecified, secondary | 0.8606 / 0.4363 / 0.5611 / 0.6789 | 0.8606 / 0.4363 / 0.5611 / 0.6790 |
| Haemorrhagic vs ischaemic | 0.6574 / 0.8475 / 0.7304 / 0.6891 | 0.6574 / 0.8475 / 0.7304 / 0.6891 |

The mismatching triples are not random: they reappear elsewhere in the same
tables. `0.7822 / 0.7678 / 0.7652` is also the RF row of "Haemorrhagic versus
ischaemic" in Table S1. `0.3249 / 0.4758 / 0.6544`, which belongs to KNN on
haemorrhagic secondary, is also the RLM row of "Haemorrhagic stroke, principal" in
Table 1. `0.6734 / 0.7641 / 0.8040`, which belongs to KNN on unspecified
principal, is also the RLM row of "Stroke, principal diagnosis" in Table 1. That
pattern is the signature of a join in which the sensitivity, F1 and accuracy
columns were attached with a shifted row index while precision stayed correct.

Only KNN can be checked, because the Lasso and Random Forest per-replicate files
were not in the delivered archive. The same assembly step produced all three sets
of rows, so both tables need regenerating and the model ranking they support needs
re-examining.

The hypervolume column has an independent problem: it reports exactly 0.0625 for
four scenarios whose metric vectors differ substantially, and 0.0625 is 0.5 to the
fourth power. A hypervolume cannot be insensitive to the point it is computed
from.

Step 9 rebuilds both tables from `results/selection/metrics_*.csv` and recomputes
the hypervolume from the same files, with the reference point and the mode stated
in the configuration. Neither table is ever transcribed by hand again.

#### 2. The case definition in the code is not the one in the Methods section

The Methods section states cerebral infarction I63, intracerebral haemorrhage I61
and unspecified stroke I64. The delivered code uses:

```sql
ischaemic    ^I63 OR ^I65 OR ^I66
haemorrhagic ^I60 OR ^I61 OR ^I62
unspecified  ^I64
```

The chi-square filter then excludes only `I63`, `I61` and `I64` from the candidate
predictors, so `I60.9` and `I62.0` remain features while also defining the
haemorrhagic outcome. They are present in the delivered frequency files as
`DIAG2_35_I60_9` and `DIAG2_35_I62_0`, and they are the top two features of
Supplementary Figure S11.

The consequence is that "subdural and subarachnoid haemorrhage characterised the
haemorrhagic subtype" is partly circular under the definition the code actually
used: a record coded I62.0 is haemorrhagic by construction. Under the definition
the Methods section states, where haemorrhagic is I61 only, the same finding is
legitimate and reads as a co-occurring bleed.

I65 and I66 are also questionable as ischaemic stroke: they code occlusion and
stenosis of cerebral and precerebral arteries *without* infarction.

`case_definition$mode` selects between the two. The default is `manuscript`, and
`extended` reproduces the published run. Independently,
`exclude_outcome_codes_from_predictors` (default `true`) removes every code family
that defines the active outcome from the candidate set, which closes the leak in
either mode. Setting it to `false` reproduces the published behaviour. Both flags
are recorded in `results/run_metadata_*.txt` for every run.

#### 3. Procedure codes ending in zero were corrupted

`Base de datos.Rmd` includes `PROCEDIMIENTO1` to `PROCEDIMIENTO11` in the list of
numeric columns:

```r
cols_num <- c(paste0("PESORN", 1:4), paste0("PROCEDIMIENTO", 1:11), ...)
```

ICD-9-CM procedure codes are not numbers. After a round trip through double
precision, 99.10 (injection of thrombolytic agent) becomes 99.1 and 89.50 becomes
89.5, while the same codes stay intact in `PROCEDIMIENTO12` to `PROCEDIMIENTO30`,
which were left as text. As a result, one code becomes two different strings
depending on which column it landed in, and the indicator built from it is
undercounted.

The effect is visible in the manuscript itself: Supplementary Figure S11 labels
its features "Thrombolytic injection (99.1)" and "Non-surgical heart and vessel
examination (89.5)", neither of which is a complete ICD-9-CM code. Thrombolysis is
one of the study's headline findings for the ischaemic subtype, so the counts
behind it are worth rebuilding.

Codes are kept as character everywhere here, and no diagnosis or procedure column
is ever passed through `as.numeric`.

#### 4. Two of the three selection frequencies are degenerate

The consensus index is the mean of the three per-model selection frequencies, so
it only carries information if each model's per-resample selection is a genuine
subset of the candidate features. Two of the three are not.

*KNN.* The original recorded `rownames(varImp(model)$importance)`, which is every
column that survived the near-zero-variance filter, without ever looking at the
values. The counts measure survival of a variance filter, not importance. It
shows in the delivered files: dozens of features sit at exactly 500 out of 500 in
`frecuencia_variables_knn_*.csv`, including things like `PROC_90_39` that have no
particular reason to be selected in every single resample.

*Random Forest.* The obvious rule, impurity importance above zero, is almost
always true. Measured on a resample of the same shape as the real ones, 200 rows
and 122 columns after the variance filter, a forest of 500 trees gives strictly
positive importance to **122 of 122** columns.

*KNN, second attempt.* `caret::filterVarImp` reports the larger of AUC and
1 - AUC, so its score never falls below 0.5 and a 0.5 cut-off selects **114 of
122**.

With two frequencies pinned near 1 for everything, the consensus index is
effectively the Lasso frequency plus a constant, and the "consensus of three
complementary models" is one model with two abstentions.

The rule each model uses is now configurable, and the defaults are a non-zero
coefficient for the Lasso and a rank rule for the other two: a feature counts as
selected in a resample when it is among that model's top `consensus$top_n_features`
by importance. This is the usual stability-selection reading and it is comparable
across models. On the same synthetic resample the defaults select 6, 30 and 30 of
122 instead of 10, 122 and 114, all three still recover every planted informative
feature, and the consensus index spreads across 0.19 to 1.00 instead of piling up
at the top. `selection_rule: "positive"` and `selection_rule: "all_retained"`
reproduce the original behaviour.

#### Smaller differences

| What | Published run | Here |
|---|---|---|
| Age | `DATE_DIFF('year', birth, admission)`, which counts calendar-year boundaries and overstates age by one year for anyone whose birthday falls after the admission date | completed years |
| Age 0 | mapped to missing, then median-imputed, which pushes obstetric and neonatal discharges to the middle of the adult distribution | kept as valid, since age 0 means under one year. `cleaning$treat_age_zero_as_missing` restores the old behaviour |
| Missing principal diagnosis | `REGEXP_MATCHES(NULL, ...)` returns NULL, so `WHERE outcome = 0` silently dropped those records from the control pool | outcome flags are 0, not NULL; only the haemorrhagic-versus-ischaemic contrast keeps NULLs, where they mean "not comparable" |
| Imputation of age and length of stay | median of each resample, so the imputed value depends on the resample | median of the development subset, computed once in step 5 |
| 70/30 partition | not present in the delivered code, although the Methods section reports it | step 5, stratified, hash-based |
| Chi-square screening | one SQL query per code and per outcome, roughly twenty thousand scans of a 5.8-million-row table, then `chisq.test()` on each 2x2 table | one grouped join over the long code table, closed-form statistic, vectorised |
| Screening scope | run over the whole dataset | development subset only, as the Methods section describes |
| Number of k candidates for KNN | `seq(3, 25, by = 2)`, twelve values; the delivered result files have no `K_usado` column, so they come from an earlier version that retuned k inside every replicate | five values, as the Methods section reports, tuned once per scenario and then held fixed |
| Records coded with both subtypes | assigned to ischaemic by the order of the `CASE WHEN` | excluded from the subtype contrast as not comparable |
| Comuna dummies | one per distinct raw string, so `CONCEPCION`, `CONCEPCIÓN` and `CONCEPCI<D3>N` produced separate columns; the delivered code repairs this for the dummy names but the same normalisation is not applied consistently upstream | one normalisation function, used for the dummies, the linkage and the figures |
| Territorial linkage | not present in the delivered code | step 4, with an audit file for every matching decision |

#### One provenance note

The delivered `Base de datos.Rmd` recomputes the chi-square screening, but the
`origen` column that the published feature names imply (`DIAG1`, `DIAG2_35`,
`PROC`) is created by a branch that only fires when the column is absent, and it
would produce `D` and `PROC` rather than the observed prefixes. This means the
published run read its significant-code list from a pre-existing CSV
(`chi2_sig_corregido_final.csv`) rather than from the code as delivered. This
matters for the "code available from the corresponding author on request"
statement: what was handed over is a reconstruction of the analysis, not the
script that produced the published numbers. The pipeline here regenerates the
screening from the raw files, so its feature list is derivable end to end.

---

### What has been verified

The numerical core was checked against independent references rather than only
read over:

| Component | Check | Result |
|---|---|---|
| chi-square screening | statistic, p-value and minimum expected count against `chisq.test(correct = FALSE)` on 300 random 2x2 tables | agrees to 1e-8 |
| log-scale p-values | a table of the size this study produces | chi-square 4 019 873, log10(p) = -872 908, where the raw p-value is exactly 0 in double precision |
| integer overflow | the product of the four marginals with integer inputs | caught and fixed; the function coerces to double first |
| hypervolume | 2, 3 and 4 dimensions against values computed by inclusion and exclusion, plus a non-origin reference point and points below the reference | exact |
| SHAP additivity | base value plus contributions against the linear predictor | maximum error 1.8e-15, and the script refuses to write output above 1e-8 |
| 70/30 partition | the same split recomputed with 1 and with 8 DuckDB threads | identical record sets |
| SQL dialect | every generated statement run against DuckDB 1.5.5 on a synthetic table: `union_by_name`, `QUALIFY` deduplication over all payload columns, `HASH` ranking, `DATE_DIFF` with `STRFTIME`, the unpivot, `REGEXP_MATCHES`, the comuna normalisation chain, `* EXCLUDE`, `COPY ... COMPRESSION ZSTD` | all execute |
| SHAP figure | structure of the built plot object: two boxes per feature, both group colours, zero line, ordering, and which rows collapse to flat markers | 14 boxes for 7 features, 10 of them flat, exactly the binary indicators |
| the three models | fitted on synthetic resamples of the real shape, with three informative features planted | all three recover them; Lasso and Random Forest reproduce exactly from a seed |
| metrics and folds | precision, sensitivity, F1, accuracy and AUC against hand-computed values; folds for reproducibility and stratification | exact |
| comuna normalisation | `CONCEPCION`, `CONCEPCIÓN` and `CONCEPCI<D3>N` | collapse to one key |

What has not been run is the pipeline on the real files, which needs the 4 GB of
FONASA data. Runtimes in this README are estimates.

---

### Method summary

**Case identification.** Cases are identified by ICD-10 code according to
`case_definition$mode`. The principal diagnosis (`DIAGNOSTICO1`) is distinguished
from the secondary diagnoses (`DIAGNOSTICO2` to `DIAGNOSTICO35`), a contrast
referred to throughout as the diagnostic hierarchy.

**Screening.** Records are split 70/30, stratified by stroke presence. Inside the
development subset, every distinct diagnosis and procedure code is tested against
stroke presence with a Pearson chi-square test on a 2x2 table, without continuity
correction, discarding tables with any expected count below five. p-values are
Bonferroni-adjusted over the number of codes tested and compared on the log10
scale against 5e-100. This is a pragmatic high-dimensional screening rule, not
formal control of the family-wise error rate.

**Selection.** For each of nine scenarios, 500 resamples of 100 cases and 100
controls are drawn from the development subset. On each resample, three models are
fitted: a Lasso-penalised logistic model (`glmnet`, lambda by internal
cross-validation), a Random Forest (`ranger`, 500 trees, mtry = sqrt(p)) and
K-nearest neighbours (`caret::knn3` on standardised predictors). Selection
frequency is the share of resamples in which a model selected the feature, and the
consensus index is the mean of the three frequencies. The 30 highest-consensus
features are retained per scenario.

**Comparison.** Precision, sensitivity, F1 and accuracy come from pooled
out-of-fold predictions of a shared stratified 10-fold split, and are combined by
the hypervolume indicator, which is monotone with respect to Pareto dominance and
needs no weights. These are diagnostics of the selection workflow. They are not
claims about clinical utility.

**Interpretation.** A class-weighted Lasso is fitted on the development subset
restricted to the consensus features. Because the model is linear, SHAP values are
exact and closed form, `phi_ij = beta_j * (x_ij - E[x_j])`, on the log-odds scale,
so no approximation and no external SHAP implementation are involved. Step 8
verifies that the contributions add up to the linear predictor and refuses to write
anything if they do not.

**Reading the SHAP figures.** A binary indicator in a linear model can take only
two SHAP values, so its row is two thin markers, while a continuous feature such
as age spreads into a box and whiskers. The width of a row reflects the value range
of the feature, not its importance. The ordering does that.

---

### Limitations inherited from the data source

DRG records carry no NIHSS score, no symptom onset time, no prehospital delay, no
imaging detail, no treatment timing, no functional status at discharge and no
follow-up. Severity can only be approximated through procedures such as
ventilation and critical care. Coding practice varies between facilities and over
time, and an unspecified code may reflect clinical uncertainty, incomplete
documentation or local coding behaviour.

The unit of analysis is the discharge, not a uniquely linked person: repeated
admissions cannot be excluded, and episode counts are not counts of individuals.
Municipal indicators are aggregate and cannot be transferred to individuals
without risking ecological bias. Absolute counts by comuna are not incidence: no
population denominators and no age standardisation are applied.

---

### Citation

[`CITATION.cff`](CITATION.cff) holds the citation metadata of the software and of
the article: the title, the year 2026 and the author recorded in the file, Ivania
Elena Guzmán-Madriaga (Departamento de Ingeniería Informática, Universidad de
Santiago de Chile). The file gives no journal and no DOI.

### Licence

Code under the MIT licence, see [`LICENSE`](LICENSE). The data sources (FONASA,
the CASEN 2022 survey and the 2024 Census) carry their own terms of use.
