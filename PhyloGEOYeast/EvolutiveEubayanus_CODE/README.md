# EvolutiveEubayanus_CODE

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el pipeline filogeográfico en R configurado para *Saccharomyces eubayanus*. Lo forman 20 scripts: `00_config.R`, que fija rutas, columnas y umbrales y define las funciones comunes; 18 pasos numerados; y `99_correr_todo.R`, que los corre en orden. La carpeta [EvolutiveSCerevisiae_CODE/](../EvolutiveSCerevisiae_CODE/) tiene el mismo código configurado para *S. cerevisiae*, y el [README del proyecto](../README.md) explica cómo se relaciona el pipeline con la app.

### Requisitos

El pipeline usa solo R base. El paquete `rstudioapi` es opcional: cada script lo usa, si está instalado, para ubicar su carpeta cuando se ejecutan líneas sueltas en RStudio, y permite lanzar la corrida como Job. Los resultados que trae la app registran R 4.3.3.

### Entradas en DATA/

Los scripts leen sus entradas desde una carpeta `DATA/` dentro de esta carpeta. El repositorio no la incluye.

| Archivo | Lo lee | Contenido |
|---|---|---|
| `DATA/filtered_eub.recode.vcf.bgz` | `02_variantes.R` | VCF comprimido de las cepas. El script lo lee con `gzfile()` en lotes de 20.000 líneas (`CHUNK`) y descarta los contigs cuyo nombre contiene `mtDNA`. |
| `DATA/MetaData_SEu.csv` | `01_datos.R` | Metadata de las cepas, con las columnas de la tabla siguiente. |
| `DATA/sitios_coords.csv` | `01_datos.R` | Coordenadas por sitio, con las columnas `Site`, `Latitud` y `Longitud`. |
| `DATA/SGD_features.tab` o `DATA/gene_result.txt` | `16_marcadores.R` | Anotación de genes, opcional. El paso usa la primera que encuentre; sin ninguna, no anota genes. |
| `DATA/outgroup_ancestral.tsv` | `07_psi.R` | Estado ancestral por sitio, opcional, con las columnas `chrom`, `pos` y `ancestral`. Solo se usa con `POLARIZAR <- "outgroup"`. |

La función `leer_tabla()` detecta si el separador de la metadata y de las coordenadas es punto y coma, coma o tabulador. De la metadata se usan estas columnas:

| Columna | Variable en `00_config.R` | Uso |
|---|---|---|
| `Strain` | `COL_CEPA` | Identifica la cepa y debe calzar con los nombres de muestra del VCF. `RENOMBRAR` cambia `467` por `CL467` en los dos lados. |
| `Site` | `COL_SITIO` | Sitio de colecta. Cruza con `sitios_coords.csv` y forma los grupos de los escenarios `sitio` y `sitio_linaje`. |
| `Population` | `COL_LINAJE` | Linaje. Forma los grupos de `sitio_linaje` y `linaje`; las cepas `Admix` quedan fuera de `sitio_linaje`. |
| `Continente` | `COL_CONT` | Opcional. Alimenta la cobertura por continente, el aviso de muestreo dominado por una región y la partición de varianza de `14_indicadores.R`. |
| `Sustate` | `COL_ECOL` | Opcional. Ecología o sustrato, que `11_controles.R` usa como estrato de sensibilidad. |
| `Source`, `Fuente`, `Study` o `Estudio` | | Opcional. Si la metadata trae una de estas columnas, `11_controles.R` repite la estimación dejando fuera cada campaña. |

`00_config.R` también define `COL_PAIS <- "Country"`, pero ningún paso la usa. En esta especie `COL_PLOIDIA` queda vacía.

### Cómo se corre

Con `Rscript`, hay que lanzarlo desde esta carpeta, porque cada script busca `00_config.R` en el directorio de trabajo:

```bash
cd PhyloGEOYeast/EvolutiveEubayanus_CODE
Rscript 99_correr_todo.R 01 12    # todos los pasos, en los tres escenarios
Rscript 99_correr_todo.R 06 09    # del paso 06 al 09
```

En RStudio basta con abrir `99_correr_todo.R` y apretar Source, o lanzarlo en segundo plano:

```r
rstudioapi::jobRunScript("99_correr_todo.R", name = "filogeografia",
                         workingDir = getwd(), importEnv = FALSE)
```

Ten en cuenta estos puntos antes de correr:

- `00_config.R` trae `PASO_DESDE <- "01"` y `PASO_HASTA <- "12"`, de modo que sin argumentos `Rscript 99_correr_todo.R` corre el pipeline completo. En RStudio el tramo sale siempre de esos dos valores.
- `99_correr_todo.R` corre los pasos en el orden de su vector `PASOS`: 01 a 11, 13 a 18 y al final 12, de modo que el tramo `01 12` cubre los 18 pasos.
- `02_variantes.R` es el paso caro porque vuelve a leer el VCF completo cada vez que corre. Solo lo evita si en `resultados/<escenario>/` hay un `paso_conteos.rds` de la versión anterior del pipeline. Para repetir un tramo sin releer el VCF, empieza desde el paso 03 o uno posterior.
- `RAPIDO <- TRUE` en `00_config.R` submuestrea el panel y baja las réplicas, para revisar en minutos si los números tienen sentido. Esos resultados no son finales.
- Cuando `12_validar.R` encuentra comprobaciones en FALLA, lo deja escrito en el log y en `12_validacion.tsv`, pero termina con estado 0. Para que corte con estado 1, corre antes `options(filo.cortar_si_falla = TRUE)`.
- Los comentarios de `00_config.R` y `99_correr_todo.R` mencionan `options(filo.desde)`, `options(filo.hasta)` y `options(filo.ignorar_validacion)`, pero el código no las lee.
- Cada paso también corre suelto (abrirlo y apretar Source). Sin escenario activo usa los valores por defecto de `00_config.R` (grupo `Site`, fusión por coordenada y sin exclusiones) y escribe directamente en `resultados/`, no en una subcarpeta de escenario.

### Escenarios

`00_config.R` define tres escenarios en `ESCENARIOS`, y `99_correr_todo.R` corre el pipeline completo en cada uno:

| Escenario | Grupo | Fusión por coordenada | Excluye | Para qué sirve |
|---|---|---|---|---|
| `sitio` | `Site` | Sí | Nada | Sostiene el mapa y la superficie de origen. |
| `sitio_linaje` | `Site` + `Population` | No | `Admix` | Mide la diversidad dentro de linaje sin perder la geografía. |
| `linaje` | `Population` | No | Nada | Aporta el árbol de linajes, f3 y los tiempos de divergencia, no el origen ni psi. |

### Pasos y salidas

Cada paso deja en `resultados/<escenario>/` un intermedio `paso_<nombre>.rds`, que leen los pasos siguientes, y un registro `<NN>_<nombre>.log`. La tabla indica además las tablas y árboles que escribe cada uno.

| Script | Qué hace | Escribe, además del `.rds` y el `.log` |
|---|---|---|
| `00_config.R` | Fija rutas, columnas, escenarios y umbrales, guarda en `REFERENCIAS` las 22 fuentes de los métodos y define las funciones comunes. Todos los pasos lo cargan. | Crea la carpeta de salida. |
| `01_datos.R` | Lee la metadata y las coordenadas, forma los grupos del escenario, fusiona los que comparten coordenada cuando corresponde y registra cada cepa excluida con su motivo. | |
| `02_variantes.R` | Lee el VCF por lotes y arma los conteos alélicos por grupo en dos paneles (estricto, con MAF 0,05 y poda por distancia, y amplio, casi sin filtro de frecuencia) y los bloques de remuestreo de 100 kb. | |
| `03_diagnostico.R` | Revisa las condiciones previas: espectro de frecuencias, geometría del muestreo, cobertura del rango y clones. | |
| `04_diversidad.R` | Calcula pi por grupo con bootstrap de bloques, la rarefacción y la descomposición de Wahlund dentro y entre linajes. | `04_diversidad.tsv` |
| `05_diferenciacion.R` | Calcula el FST de Hudson por pares, la distancia de Nei y el aislamiento por distancia con Mantel y la regresión de Rousset. | `05_pares.tsv` |
| `06_gradiente.R` | Busca sobre una grilla de 0,5 grados el origen que mejor explica la caída de la diversidad con la distancia. | `06_superficie.tsv` |
| `07_psi.R` | Calcula el índice de direccionalidad psi (Peter y Slatkin 2013), polarizando por mayoría salvo que haya grupo externo. | `07_psi.tsv` |
| `08_arbol.R` | Construye el árbol de grupos por neighbor-joining con soporte por bootstrap de bloques. | `08_arbol.nwk`, `08_soporte.tsv` |
| `09_tiempos.R` | Ordena las divergencias en unidades de deriva y da los años solo como cota. | `09_eventos.tsv` |
| `10_modelos.R` | Compara el origen contra modelos alternativos (nulo, fundador serial, aislamiento por distancia y dos refugios) con AIC y validación cruzada. | `10_modelos.tsv` |
| `11_controles.R` | Corre seis controles: nulo por permutación de la geografía, simulación sin expansión, campañas fuera, robustez a Wahlund, estratos ecológicos y efecto de borde. | `11_campanas.tsv`, solo si la metadata trae columna de campaña |
| `12_validar.R` | Cruza los productos de los pasos anteriores y marca cada comprobación como FALLA, AVISO u OK. | `12_validacion.tsv` |
| `13_estructura.R` | Hace el PCA de frecuencias por grupo y la prueba f3 de mezcla, con error estándar por bloques. Su log es `13_mezcla.log` y su intermedio `paso_mezcla.rds`. | `13_pca.tsv`, `13_f3.tsv` |
| `14_indicadores.R` | Calcula Ho, Fis, LD, alelos privados, D de Tajima, la partición de varianza tipo AMOVA y Procrustes entre el mapa genético y el geográfico. | `14_indicadores_poblacion.tsv`, `14_indicadores_globales.tsv` |
| `15_asignacion.R` | Asigna cada cepa al grupo de mayor verosimilitud, restando antes sus propios alelos de las frecuencias de su grupo. | `15_asignacion.tsv`, `15_exactitud_por_grupo.tsv` |
| `16_marcadores.R` | Busca marcadores diagnósticos por grupo (diferencia de frecuencia y prueba de Fisher con corrección de Benjamini y Hochberg) y los anota en genes si hay anotación. Para cruzar la anotación con el VCF lleva cada nombre de cromosoma a un número, de modo que `chrIV`, `IV` y `CBS12357_Chr04_polished` dan 4. | `16_marcadores.tsv`, `16_resumen_grupos.tsv` y, con anotación, `16_genes.tsv` |
| `17_potencia.R` | Estima por simulación la potencia, la identificabilidad, la sensibilidad a decisiones del análisis y dónde convendría colectar la próxima campaña. | `17_potencia.tsv`, `17_sensibilidad.tsv`, `17_diseno_optimo.tsv` |
| `18_origen_cepa.R` | Estima la ancestría por cepa (factorización no negativa con K = 6), el vecino genético más cercano, las cepas atípicas y los alelos privados rarefaccionados. | `18_ancestria.tsv`, `18_vecino_cercano.tsv`, `18_atipicas.tsv`, `18_privados_rarefaccionados.tsv` |
| `99_correr_todo.R` | Recorre los tres escenarios y, en cada uno, el tramo de pasos pedido. Si un escenario falla, lo anota y sigue con el siguiente. | `resultados/tiempos.tsv` (escenario, paso, segundos) |

### Parámetros principales

Todos están en `00_config.R`, que es el único archivo que se edita a mano.

| Parámetro | Valor | Qué controla |
|---|---|---|
| `MIN_MAF`, `MIN_CALL`, `MIN_DIST_LD` | 0,05; 0,80; 20 pb | Filtros del panel estricto: frecuencia mínima del alelo menor, fracción mínima de genotipos llamados y distancia mínima entre SNPs. |
| `MAF_AMPLIO`, `CALL_AMPLIO`, `FRAC_AMPLIO` | 0,002; 0,60; 0,35 | Panel amplio, que conserva la cola de alelos raros: sus dos filtros y la fracción de sitios que se toma al azar. |
| `TAM_BLOQUE` | 100.000 pb | Ventana genómica que se remuestrea. |
| `N_BOOTSTRAP`, `N_PERMUTA` | 500; 1.000 | Réplicas de bootstrap y permutaciones. |
| `SEMILLA` | 20260819 | Semilla de los remuestreos. |
| `GRILLA_PASO`, `GRILLA_MARGEN` | 0,5; 5 grados | Grilla de orígenes candidatos. |
| `POLARIZAR` | `"mayoria"` | Cómo se define el alelo derivado en psi (`"mayoria"`, `"outgroup"` o `"referencia"`). |
| `N_MIN_GRUPO_EST` | 3 | Cepas mínimas por grupo en los pasos que estiman algo por grupo. |
| `K_ANCESTRIA` | 6 | Componentes de ancestría en `18_origen_cepa.R`. |
| `LARGO_GENOMA` | 12.071.326 pb | Largo del genoma llamable, para convertir la diversidad del panel a diversidad por par de bases. |
| `MU_*`, `GEN_ANO_*` | ver archivo | Tasa de mutación y generaciones por año para las cotas en años. |

## English

This folder holds the phylogeographic R pipeline configured for *Saccharomyces eubayanus*. It has 20 scripts: `00_config.R`, which sets paths, columns, and thresholds and defines the shared functions; 18 numbered steps; and `99_correr_todo.R`, which runs them in order. The [EvolutiveSCerevisiae_CODE/](../EvolutiveSCerevisiae_CODE/) folder holds the same code configured for *S. cerevisiae*, and the [project README](../README.md) explains how the pipeline relates to the app.

### Requirements

The pipeline uses base R only. The `rstudioapi` package is optional: when it is installed, each script uses it to find its folder when single lines are run in RStudio, and it allows launching the run as a Job. The results bundled in the app record R 4.3.3.

### Inputs in DATA/

The scripts read their inputs from a `DATA/` folder inside this folder. The repository does not include it.

| File | Read by | Content |
|---|---|---|
| `DATA/filtered_eub.recode.vcf.bgz` | `02_variantes.R` | Compressed VCF of the strains. The script reads it with `gzfile()` in batches of 20,000 lines (`CHUNK`) and drops the contigs whose name contains `mtDNA`. |
| `DATA/MetaData_SEu.csv` | `01_datos.R` | Strain metadata, with the columns in the next table. |
| `DATA/sitios_coords.csv` | `01_datos.R` | Coordinates per site, with the columns `Site`, `Latitud`, and `Longitud`. |
| `DATA/SGD_features.tab` or `DATA/gene_result.txt` | `16_marcadores.R` | Optional gene annotation. The step uses the first one it finds; without either, it does not annotate genes. |
| `DATA/outgroup_ancestral.tsv` | `07_psi.R` | Optional ancestral state per site, with the columns `chrom`, `pos`, and `ancestral`. It is only used with `POLARIZAR <- "outgroup"`. |

The `leer_tabla()` function detects whether the metadata and the coordinates use semicolons, commas, or tabs as separator. These metadata columns are used:

| Column | Variable in `00_config.R` | Use |
|---|---|---|
| `Strain` | `COL_CEPA` | Identifies the strain and must match the sample names in the VCF. `RENOMBRAR` changes `467` to `CL467` on both sides. |
| `Site` | `COL_SITIO` | Collection site. It joins with `sitios_coords.csv` and forms the groups of the `sitio` and `sitio_linaje` scenarios. |
| `Population` | `COL_LINAJE` | Lineage. It forms the groups of `sitio_linaje` and `linaje`; `Admix` strains are left out of `sitio_linaje`. |
| `Continente` | `COL_CONT` | Optional. It feeds the coverage by continent, the warning about sampling dominated by one region, and the variance partition in `14_indicadores.R`. |
| `Sustate` | `COL_ECOL` | Optional. Ecology or substrate, which `11_controles.R` uses as a sensitivity stratum. |
| `Source`, `Fuente`, `Study`, or `Estudio` | | Optional. If the metadata has one of these columns, `11_controles.R` repeats the estimate leaving out each sampling campaign. |

`00_config.R` also defines `COL_PAIS <- "Country"`, but no step uses it. For this species `COL_PLOIDIA` is empty.

### How to run it

With `Rscript`, launch it from this folder, because each script looks for `00_config.R` in the working directory:

```bash
cd PhyloGEOYeast/EvolutiveEubayanus_CODE
Rscript 99_correr_todo.R 01 12    # all steps, in the three scenarios
Rscript 99_correr_todo.R 06 09    # from step 06 to step 09
```

In RStudio, open `99_correr_todo.R` and press Source, or launch it in the background:

```r
rstudioapi::jobRunScript("99_correr_todo.R", name = "filogeografia",
                         workingDir = getwd(), importEnv = FALSE)
```

Keep these points in mind before running it:

- `00_config.R` sets `PASO_DESDE <- "01"` and `PASO_HASTA <- "12"`, so without arguments `Rscript 99_correr_todo.R` runs the full pipeline. In RStudio the step range always comes from those two values.
- `99_correr_todo.R` runs the steps in the order of its `PASOS` vector: 01 to 11, 13 to 18, and 12 last, so the `01 12` range covers all 18 steps.
- `02_variantes.R` is the expensive step because it reads the whole VCF again every time it runs. It only skips that when `resultados/<scenario>/` holds a `paso_conteos.rds` from the previous version of the pipeline. To repeat a range without reading the VCF, start from step 03 or later.
- `RAPIDO <- TRUE` in `00_config.R` subsamples the panel and lowers the number of replicates, so you can check in minutes whether the numbers make sense. Those results are not final.
- When `12_validar.R` finds checks in FALLA, it writes them to the log and to `12_validacion.tsv` but ends with exit status 0. To make it stop with status 1, run `options(filo.cortar_si_falla = TRUE)` first.
- The comments in `00_config.R` and `99_correr_todo.R` mention `options(filo.desde)`, `options(filo.hasta)`, and `options(filo.ignorar_validacion)`, but the code does not read them.
- Each step also runs on its own (open it and press Source). Without an active scenario it uses the defaults in `00_config.R` (group `Site`, merging by coordinate, no exclusions) and writes straight to `resultados/`, not to a scenario subfolder.

### Scenarios

`00_config.R` defines three scenarios in `ESCENARIOS`, and `99_correr_todo.R` runs the whole pipeline in each one:

| Scenario | Group | Merge by coordinate | Excludes | What it is for |
|---|---|---|---|---|
| `sitio` | `Site` | Yes | Nothing | Supports the map and the origin surface. |
| `sitio_linaje` | `Site` + `Population` | No | `Admix` | Measures within-lineage diversity while keeping the geography. |
| `linaje` | `Population` | No | Nothing | Provides the lineage tree, f3, and divergence times, not the origin or psi. |

### Steps and outputs

Each step writes to `resultados/<scenario>/` an intermediate file `paso_<name>.rds`, which the later steps read, and a log `<NN>_<name>.log`. The table also lists the tables and trees that each step writes.

| Script | What it does | Writes, besides the `.rds` and the `.log` |
|---|---|---|
| `00_config.R` | Sets paths, columns, scenarios, and thresholds, keeps the 22 method sources in `REFERENCIAS`, and defines the shared functions. Every step loads it. | Creates the output folder. |
| `01_datos.R` | Reads the metadata and coordinates, forms the groups of the scenario, merges the ones that share a coordinate when that applies, and records each excluded strain with its reason. | |
| `02_variantes.R` | Reads the VCF in batches and builds allele counts per group in two panels (a strict one with MAF 0.05 and distance pruning, and a wide one with almost no frequency filter) plus the 100 kb resampling blocks. | |
| `03_diagnostico.R` | Checks the preconditions: frequency spectrum, sampling geometry, range coverage, and clones. | |
| `04_diversidad.R` | Computes pi per group with block bootstrap, rarefaction, and the Wahlund decomposition within and between lineages. | `04_diversidad.tsv` |
| `05_diferenciacion.R` | Computes pairwise Hudson FST, Nei distance, and isolation by distance with Mantel and the Rousset regression. | `05_pares.tsv` |
| `06_gradiente.R` | Searches a 0.5 degree grid for the origin that best explains the decline of diversity with distance. | `06_superficie.tsv` |
| `07_psi.R` | Computes the psi directionality index (Peter and Slatkin 2013), polarising by majority unless an outgroup is available. | `07_psi.tsv` |
| `08_arbol.R` | Builds the neighbor-joining tree of groups with block-bootstrap support. | `08_arbol.nwk`, `08_soporte.tsv` |
| `09_tiempos.R` | Orders the divergences in drift units and reports years only as a bound. | `09_eventos.tsv` |
| `10_modelos.R` | Compares the origin with alternative models (null, serial founder, isolation by distance, and two refugia) using AIC and cross-validation. | `10_modelos.tsv` |
| `11_controles.R` | Runs six controls: null by permuting the geography, simulation without expansion, campaigns left out, robustness to Wahlund, ecological strata, and edge effect. | `11_campanas.tsv`, only when the metadata has a campaign column |
| `12_validar.R` | Cross-checks the products of the earlier steps and marks each check as FALLA, AVISO, or OK. | `12_validacion.tsv` |
| `13_estructura.R` | Runs the PCA of group frequencies and the f3 admixture test, with block standard errors. Its log is `13_mezcla.log` and its intermediate file is `paso_mezcla.rds`. | `13_pca.tsv`, `13_f3.tsv` |
| `14_indicadores.R` | Computes Ho, Fis, LD, private alleles, Tajima's D, an AMOVA-style variance partition, and Procrustes between the genetic and the geographic map. | `14_indicadores_poblacion.tsv`, `14_indicadores_globales.tsv` |
| `15_asignacion.R` | Assigns each strain to the group with the highest likelihood, after removing its own alleles from its group's frequencies. | `15_asignacion.tsv`, `15_exactitud_por_grupo.tsv` |
| `16_marcadores.R` | Finds diagnostic markers per group (frequency difference and Fisher's test with Benjamini-Hochberg correction) and annotates them on genes when an annotation is available. To match the annotation with the VCF it turns each chromosome name into a number, so `chrIV`, `IV` and `CBS12357_Chr04_polished` all give 4. | `16_marcadores.tsv`, `16_resumen_grupos.tsv` and, with an annotation, `16_genes.tsv` |
| `17_potencia.R` | Estimates by simulation the power, identifiability, sensitivity to analysis decisions, and where the next sampling campaign would help most. | `17_potencia.tsv`, `17_sensibilidad.tsv`, `17_diseno_optimo.tsv` |
| `18_origen_cepa.R` | Estimates ancestry per strain (non-negative factorisation with K = 6), the nearest genetic neighbour, atypical strains, and rarefied private alleles. | `18_ancestria.tsv`, `18_vecino_cercano.tsv`, `18_atipicas.tsv`, `18_privados_rarefaccionados.tsv` |
| `99_correr_todo.R` | Loops over the three scenarios and runs the requested step range in each one. If a scenario fails, it records the error and moves on to the next one. | `resultados/tiempos.tsv` (scenario, step, seconds) |

### Main parameters

They all live in `00_config.R`, the only file meant to be edited by hand.

| Parameter | Value | What it controls |
|---|---|---|
| `MIN_MAF`, `MIN_CALL`, `MIN_DIST_LD` | 0.05; 0.80; 20 bp | Filters of the strict panel: minimum minor allele frequency, minimum fraction of called genotypes, and minimum distance between SNPs. |
| `MAF_AMPLIO`, `CALL_AMPLIO`, `FRAC_AMPLIO` | 0.002; 0.60; 0.35 | Wide panel, which keeps the tail of rare alleles: its two filters and the fraction of sites drawn at random. |
| `TAM_BLOQUE` | 100,000 bp | Genomic window used for resampling. |
| `N_BOOTSTRAP`, `N_PERMUTA` | 500; 1,000 | Bootstrap replicates and permutations. |
| `SEMILLA` | 20260819 | Seed of the resampling. |
| `GRILLA_PASO`, `GRILLA_MARGEN` | 0.5; 5 degrees | Grid of candidate origins. |
| `POLARIZAR` | `"mayoria"` | How the derived allele is defined in psi (`"mayoria"`, `"outgroup"`, or `"referencia"`). |
| `N_MIN_GRUPO_EST` | 3 | Minimum strains per group in the steps that estimate something per group. |
| `K_ANCESTRIA` | 6 | Ancestry components in `18_origen_cepa.R`. |
| `LARGO_GENOMA` | 12,071,326 bp | Callable genome length, used to turn panel diversity into per-base-pair diversity. |
| `MU_*`, `GEN_ANO_*` | see the file | Mutation rate and generations per year for the bounds in years. |
