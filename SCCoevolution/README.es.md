# Selección multiobjetivo de ORFs para filogenética de levadura

Código y datos reproducibles de una optimización multiobjetivo que selecciona
conjuntos pequeños de ORFs cuya filogenía concatenada aproxima un árbol de
referencia de genoma completo de 1011 cepas de *Saccharomyces cerevisiae*.

Se minimizan dos objetivos a la vez:

| | Objetivo | Dirección |
|---|---|---|
| 1 | Número de ORFs (normalizado) | menos es mejor |
| 2 | Distancia de Robinson-Foulds normalizada al árbol de referencia | más cerca es mejor |

Se comparan dos estrategias, **MOSA** (recocido simulado multiobjetivo) y
**NSGA-II**, y el frente de Pareto resultante se compara contra un conjunto de
genes de referencia de trabajo previo.

---

## Inicio rápido

```bash
Rscript -e 'install.packages(c("readr","dplyr","tidyr","stringr","ggplot2",
                               "ape","phangorn","RColorBrewer","UpSetR","plotly"))'
Rscript run_all.R
```

`UpSetR` y `plotly` son opcionales: sin ellos las tablas igual se escriben y solo
se omiten el gráfico UpSet y las versiones interactivas en HTML.

El paso 04 descomprime `data/alignments_used.tar.gz` en la primera corrida y es el
paso lento, ya que lee 106 alineamientos de 1011 taxones cada uno.

---

## Pipeline

| Paso | Script | Qué hace |
|---|---|---|
| 01 | `01_pareto_front.R` | Frente de Pareto y convergencia entre las cinco generaciones registradas |
| 02 | `02_hypervolume.R` | Hipervolumen MOSA vs NSGA-II, con comparación estadística |
| 03 | `03_solution_overlap.R` | Solapamiento por pares, recurrencia de ORFs, recuperación del conjunto de referencia, UpSet |
| 04 | `04_build_trees.R` | Árbol de neighbour-joining por solución con distancias de Hamming promediadas |
| 05 | `05_colour_trees.R` | Colorea un JSON de árbol por clado de cepa. Se corre a demanda con el árbol como argumento |

```bash
Rscript run_all.R 02                       # un solo paso
Rscript R/04_build_trees.R S2 S9           # solo estas soluciones
Rscript R/05_colour_trees.R trees/sol2_tree.json
```

---

## Datos

| Archivo | Contenido |
|---|---|
| `data/solutions.csv` | Los 15 conjuntos de ORFs en formato largo. **Única fuente de verdad.** |
| `data/pareto_fronts.csv` | 63 puntos de las generaciones F0 a F4 |
| `data/hypervolume.csv` | 60 corridas independientes, 31 MOSA y 29 NSGA-II |
| `data/strain_metadata.csv` | 1043 cepas con clado, origen y fenotipos |
| `data/alignment_manifest.csv` | Los 6015 alineamientos de la base, con tamaños y marca de los 106 usados acá |
| `data/alignments_db/alignments_part1.zip` | 3141 alineamientos, 75 MB |
| `data/alignments_db/alignments_part2.zip` | 2874 alineamientos, 69 MB |
| `data/enrichment/` | Tablas de GO, KEGG y frecuencias de ORFs |

### La base de alineamientos

Van los **6015** alineamientos completos, de 1011 taxones cada uno, **8,4 GB
descomprimidos** y 144 MB comprimidos. Viajan en dos partes zip porque GitHub
rechaza cualquier archivo individual sobre 100 MB. La división es por archivo, no
por rango de bytes, así que cada parte es un archivo válido por sí sola y no hay
nada que concatenar.

Una versión anterior de este repositorio distribuía solo los 106 alineamientos que
referencian las quince soluciones finales. Eso alcanza para reconstruir todos los
árboles del paper, pero no para volver a correr la búsqueda: MOSA y NSGA-II
evalúan subconjuntos candidatos de ORFs contra los 6015 genes, así que alguien con
solo 106 podría verificar el resultado y no reproducir el método. Para un paper de
método esa es la mitad equivocada.

`R/utils_solutions.R` extrae **solo los alineamientos que necesita cada corrida**,
así construir un árbol cuesta un archivo y no una descompresión de 8,4 GB. Sin
lista de ORFs descomprime la base entera, que es lo que exige volver a correr la
optimización.

`alignment_manifest.csv` lista los 6015 con tamaños en bytes y una marca para los
106 que usan las soluciones finales, y la rutina de descompresión verifica el
conteo extraído contra él, así una descompresión truncada o un disco lleno se
detecta de inmediato en vez de aparecer después como un gen faltante.
---

## Problema de datos conocido

**La solución S10 lista `YJR138W2`, que no existe en la base de alineamientos.**
La coincidencia más cercana es `YJR138W`, que usa la solución S11. El
`crear_arboles.R` original advertía del archivo faltante y después construía el
árbol con los genes restantes, así que el árbol de S10 se construyó con **dos**
ORFs en vez de los tres que dice su definición, y nada en la salida lo registraba.

Este pipeline no lo tapa. `04_build_trees.R` escribe el número de ORFs pedidos y
realmente usados de cada solución en `outputs/tables/04_tree_summary.csv` y marca
todo árbol construido con un conjunto incompleto. Si `YJR138W2` es un error de
tipeo por `YJR138W` o un locus distinto es decisión de los autores, no del código.

---

## Qué cambió respecto a los scripts originales

Los análisis no cambian. La reorganización ataca modos de falla que vuelven los
resultados difíciles de confiar o de reproducir.

**Los quince conjuntos de genes estaban escritos a mano tres veces.** Las mismas
130 líneas de vectores literales de ORFs aparecían textualmente en
`Upset/main.R` y `Upset/interseccion.R`, con una tercera copia parcial comentada y
descomentada arriba de `Arboles/crear_arboles.R`. Tres copias son tres
oportunidades de editar una y olvidar las otras, y después no hay forma de saber
cuál copia produjo una figura publicada. Ahora viven en `data/solutions.csv`.

**Elegir una solución implicaba editar un script.** `crear_arboles.R` cambiaba de
solución moviendo marcadores de comentario, mientras el nombre del archivo de
salida estaba escrito aparte como `sol1_tree.nwk`. Construir la solución 2 y
olvidar esa línea sobrescribía en silencio el árbol de la solución 1 con la
topología de la 2.

**Los alineamientos faltantes eran un warning, no un error.** Ver el problema de
datos de arriba.

**Las etiquetas del Pareto eran posicionales.** `Convergencia/grafico.R` pegaba
las etiquetas de solución mediante un vector escrito a mano cuyo orden tenía que
calzar exactamente con el orden de filas de `f4.csv`, sin que nada lo verificara.
Reordenar el CSV movía cada etiqueta al punto equivocado.

**Solo se graficaba el frente final.** El script cargaba `f0.csv` a `f4.csv` y
graficaba solo `f4`, así que la convergencia que sugieren los nombres de archivo
nunca se mostraba. El paso 01 grafica los cinco.

**La figura de hipervolumen no tenía prueba detrás.** Dos violines que se solapan
no responden si un algoritmo es mejor. El paso 02 reporta Mann-Whitney con tamaño
de efecto rango-biserial e intervalo de confianza bootstrap.

**El eje y del hipervolumen estaba fijado a 1 y 4.** Cualquier corrida fuera de esa
ventana se habría caído de la figura con solo un mensaje de ggplot fácil de pasar
por alto. Ahora los límites se calculan de los datos. Con los datos actuales no se
estaba perdiendo nada.

**El solapamiento se medía por conteos crudos.** Los tamaños van de 1 a 22 ORFs,
así que la mayor intersección cruda queda dominada por el par más grande. El paso
03 reporta el índice de Jaccard al lado.

**Cada script asumía que su propia carpeta era el directorio de trabajo.** Rutas
como `"f4.csv"` y `"../BD/Secuencias_alineadas/"` solo funcionaban si R se iniciaba
en el lugar justo. Ahora todas las rutas vienen de `00_config.R`.

**`.RData` y `.Rhistory` estaban commiteados en tres carpetas.** Los objetos
viejos de sesión ensombrecen en silencio una corrida limpia. Van al gitignore.

**Los colores se definían por separado en cada script**, así que el mismo
algoritmo aparecía de colores distintos entre figuras. Una sola paleta en
`00_config.R`.

---

## Resultados destacados

Reproducibles con `Rscript run_all.R`; tablas en `outputs/tables/`.

**NSGA-II le gana a MOSA con separación perfecta.** Correlación rango-biserial
**−1,000** (IC 95% [−1,000, −1,000]), p = 3,1e-11: toda corrida de NSGA-II alcanza
mayor hipervolumen que toda corrida de MOSA. Mediana 2,811 contra 1,719.

**Un ORF domina el frente de Pareto.** `YPL009C` es seleccionado por **10 de las
14** soluciones del Pareto (71 por ciento), y **no** está en el conjunto de
referencia.

**El frente de Pareto y el conjunto de referencia casi no se solapan.** La
solución de referencia tiene 22 ORFs. Entre las 14 soluciones del Pareto el frente
recupera **1** de ellos (`YHR205W`). La optimización converge a genes casi
completamente distintos.

**Las soluciones S10 y S11 son conjuntos distintos con valores objetivo
idénticos**, así que 14 soluciones ocupan 13 puntos del frente final.

---

## Volver a correr la optimización

La búsqueda está en el pipeline, no solo sus salidas. Los pasos 10 y 11 vuelven a
correr los dos algoritmos desde cero y reconstruyen `solutions.csv`,
`pareto_fronts.csv` y `hypervolume.csv` con las corridas nuevas.

```bash
# primero descomprimir la base completa de 6015 alineamientos (~8,4 GB libres)
Rscript -e 'source("R/00_config.R"); source("R/utils_solutions.R"); ensure_alignments()'

# prueba rápida de todo el loop, minutos, con configuración mínima
OPT_QUICK=1 Rscript run_all.R 10 11

# lo real: 31 corridas independientes de cada algoritmo
Rscript run_all.R 10 11

Rscript R/10_run_optimisation.R nsga2      # un solo algoritmo
Rscript R/10_run_optimisation.R mosa 5     # solo 5 corridas
```

Todo hiperparámetro vive en `OPT` dentro de `R/00_config.R`. Los pasos 10 y 11 no
están en la secuencia por defecto: una corrida completa toma muchas horas y
reconstruir los archivos de datos reemplaza las soluciones publicadas. Los
archivos anteriores se respaldan con timestamp en vez de sobrescribirse.

### Sembrar la población inicial

`main.r` sembraba la población desde una planilla, `Grupos y medoides.xlsx`, con
`buildTreeFromXSLX`. Ese archivo nunca se liberó con el código, así que una
corrida sembrada no la podía reproducir nadie más; la función además anteponía un
espacio a cada nombre de archivo, lo que hacía que `match()` devolviera `NA` en
silencio cuando los alineamientos no traían ese espacio.

El sembrado ahora lee de `data/solutions.csv`, que sí está en el repositorio:

```bash
Rscript R/10_run_optimisation.R nsga2 31 SV     # sembrar desde el conjunto de referencia
Rscript R/10_run_optimisation.R nsga2 31 S2     # sembrar desde una solución del Pareto
Rscript R/10_run_optimisation.R nsga2 31 none   # arranque aleatorio (default)
```

La semilla se valida antes de arrancar, no a mitad de camino: un nombre de
solución desconocido, una solución más grande que `OPT$max_genes`, o ORFs que
falten del conjunto de genes producen un error inmediato y específico. Los ORFs
ausentes del conjunto se descartan con un mensaje que los nombra, que es como
aparece el `YJR138W2` faltante de S10 en vez de encoger la semilla en silencio.

### Correcciones al optimizador

**El recocido simulado no tenía esquema de temperatura funcionando.** En el
`simAnnMO.r` original la prueba de aceptación era una función separada de nivel
superior que leía `T`:

```r
checkTemperature <- function(deltaE){ prob = exp((-deltaE/T)); ... }
simulatedAnnealingMO <- function(..., T, alpha, ...){ ... T = T * alpha }
```

R usa alcance léxico, así que esa `T` nunca resolvía a la temperatura local.
Resolvía en el entorno global, donde `T` es el alias de R para `TRUE`, o sea **1**.
Medido: con `T = 1000, alpha = 0.8` la función de aceptación ve `1` en cada
iteración; para una brecha de energía de 5 la probabilidad de aceptación fue
0,0067 en vez de 0,995, unas **150 veces menor**. MOSA corrió como un hill climber
casi puro. Ahora la temperatura es un argumento explícito y se devuelve la traza
para poder inspeccionar el esquema.

**Las soluciones eran índices enteros dentro de `list.files()`.** Ese listado se
ordena según la intercalación del locale, así que el índice 500 es un gen distinto
en un Windows en español que en un servidor Linux con locale C, y las soluciones
guardadas solo se podían decodificar en la máquina que las produjo. Ahora las
soluciones son nombres de ORF, y el conjunto de genes se lee del manifiesto
ordenado con `method = "radix"`, independiente del locale.

**No había semilla en ninguna parte, y `foreach %dopar%` sin `doRNG`.** Ninguna
corrida se podía repetir ni en la misma máquina. Ahora cada corrida toma una
semilla derivada de forma determinista de `PARAMS$seed` y el índice de corrida,
así la corrida 7 es la misma en todas partes y se puede repetir sola. Verificado:
misma semilla da frente idéntico, semilla distinta da uno diferente.

**Los presupuestos de evaluación no eran comparables.** NSGA-II corría 19
generaciones de 14 individuos; MOSA corría `external_loops = 2, internal_loops = 2`,
cuatro movimientos propuestos en total. `OPT` ahora le da **532 evaluaciones** a
cada uno.

**Cargar un módulo lanzaba un experimento.** La última línea de `nsga2.r` y de
`simAnnMO.r` ejecutaba una corrida completa con rutas `C:/Users/Vichi/...`
escritas a mano, así que hacer `source()` desde `main.r` arrancaba una corrida no
deseada. Los archivos de algoritmo ahora solo definen funciones.

**MOSA devolvía una solución, no un frente.** Conservaba solo la solución actual,
que no se puede comparar con NSGA-II por hipervolumen. Ahora mantiene un archivo
no dominado.

**El cruce descartaba un hijo según solo la RF.** En una búsqueda de dos objetivos
eso sesga cada generación hacia un objetivo y en contra de los conjuntos chicos de
genes. Se devuelven los dos hijos y la supervivencia la decide el ordenamiento no
dominado.

**La dominancia usaba `<=` en los dos objetivos**, así que dos soluciones
idénticas se reportaban como una dominando a la otra. Ahora es dominancia de
Pareto estricta.

**`buildTree` escribía `out.txt` en cada evaluación de fitness**, con cinco
workers paralelos compitiendo por el mismo archivo. Eliminado.

**Los objetivos se reescalaban contra una población móvil dentro de la búsqueda.**
`MaOEA::Normalize` se aplicaba sobre todo el historial de generaciones al momento
de graficar, y ese historial nunca se guardó, que es por lo que las coordenadas
del frente publicado no se pueden recalcular con los datos liberados. Ahora se
guardan los valores objetivo crudos, la normalización ocurre solo al reportar, y
las constantes se escriben en `11_normalisation_constants.csv`.

**Los alineamientos se releían en cada evaluación.** Las matrices de distancia por
gen ahora se guardan en memoria con un LRU acotado, `OPT$cache_size`. Tasa de
aciertos observada en una corrida corta: cerca del 80 por ciento.

---

## Estructura

```
├── R/
│   ├── 00_config.R            Rutas, parámetros, paleta, chequeo de dependencias
│   ├── utils_solutions.R      Carga las soluciones y verifica los alineamientos
│   └── 01_…05_*.R             Pasos de análisis
├── data/                      CSV ordenados, alineamientos empaquetados, enriquecimiento
├── trees/                     Newick y JSON de phylocanvas, plano y coloreado
├── outputs/
│   ├── figures/               PDF
│   ├── tables/                CSV
│   └── logs/                  sessionInfo por paso
├── run_all.R
└── docs/
```

## Licencia

MIT para el código. Los alineamientos de los 1011 genomas derivan del 1002 Yeast
Genomes Project y quedan sujetos a los términos de ese proyecto.
