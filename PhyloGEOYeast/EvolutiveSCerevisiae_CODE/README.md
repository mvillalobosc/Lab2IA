# EvolutiveSCerevisiae_CODE

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el mismo pipeline filogeográfico en R de [EvolutiveEubayanus_CODE/](../EvolutiveEubayanus_CODE/), configurado para *Saccharomyces cerevisiae*. De sus 20 scripts, 19 son idénticos byte a byte a los de esa carpeta; solo cambia `00_config.R`, en las 11 líneas que muestra la tabla de abajo. El README de *S. eubayanus* describe paso por paso qué hace y qué escribe cada script, y el [README del proyecto](../README.md) explica cómo se relaciona el pipeline con la app.

### Requisitos

El pipeline usa solo R base; `rstudioapi` es opcional y sirve para correrlo cómodamente desde RStudio. Los resultados que trae la app registran R 4.3.3.

### Entradas en DATA/

Los scripts leen sus entradas desde una carpeta `DATA/` dentro de esta carpeta, que el repositorio no incluye.

| Archivo | Lo lee | Contenido |
|---|---|---|
| `DATA/1011Matrix.gvcf.gz` | `02_variantes.R` | VCF comprimido del panel. El script lo lee con `gzfile()` en lotes de 20.000 líneas y descarta los contigs cuyo nombre contiene `chromosome17`. |
| `DATA/MetaData_Scer.csv` | `01_datos.R` | Metadata de las cepas. |
| `DATA/sitios_coords_Scer.csv` | `01_datos.R` | Coordenadas por sitio, con las columnas `Site`, `Latitud` y `Longitud`. |
| `DATA/SGD_features.tab` o `DATA/gene_result.txt` | `16_marcadores.R` | Anotación de genes, opcional. |
| `DATA/outgroup_ancestral.tsv` | `07_psi.R` | Estado ancestral por sitio, opcional, con las columnas `chrom`, `pos` y `ancestral`; solo se usa con `POLARIZAR <- "outgroup"`. |

De la metadata se usan `Strain` (debe calzar con los nombres de muestra del VCF), `Site`, `Population` (linaje), y como opcionales `Continente`, `Ecologia` (estrato de sensibilidad en `11_controles.R`) y `Ploidia` (`01_datos.R` avisa cuando hay cepas con ploidía mayor que 2). Una columna `Source`, `Fuente`, `Study` o `Estudio`, si existe, activa el control que deja fuera cada campaña. Según `REFERENCIAS` en `00_config.R`, el panel de *S. cerevisiae* y sus etiquetas de linaje vienen de Peter et al. (2018).

En este repositorio, la carpeta [../../YeastForest/data/](../../YeastForest/data/) trae archivos con los mismos nombres que espera esta configuración (`MetaData_Scer.csv` y `sitios_coords_Scer.csv`) y con las columnas que se leen. El VCF no está en el repositorio.

### Diferencias con la configuración de S. eubayanus

| Línea de `00_config.R` | *S. cerevisiae* (esta carpeta) | *S. eubayanus* |
|---|---|---|
| `ARCHIVO_VCF` | `DATA/1011Matrix.gvcf.gz` | `DATA/filtered_eub.recode.vcf.bgz` |
| `ARCHIVO_META` | `DATA/MetaData_Scer.csv` | `DATA/MetaData_SEu.csv` |
| `ARCHIVO_COORDS` | `DATA/sitios_coords_Scer.csv` | `DATA/sitios_coords.csv` |
| `ESPECIE` | `"Saccharomyces cerevisiae"` | `"Saccharomyces eubayanus"` |
| `COL_ECOL` | `"Ecologia"` | `"Sustate"` |
| `COL_PLOIDIA` | `"Ploidia"` | vacía |
| `RENOMBRAR` | sin cambios de nombre | `467` pasa a `CL467` |
| `CONTIG_EXCLUIR` | `"chromosome17"` | `"mtDNA"` |
| `MIN_DIST_LD` | 50 pb | 20 pb |
| `FRAC_AMPLIO` | 0,15 | 0,35 |
| `LARGO_GENOMA` | 12.071.326 pb, con el comentario "S. cerevisiae S288C" | el mismo valor, con el comentario "S. eubayanus CBS 12357" |

Lo demás (escenarios, umbrales, semilla, número de réplicas y lista de referencias) es igual en las dos carpetas, así que cualquier corrección a un paso hay que copiarla en ambas.

### Cómo se corre

```bash
cd PhyloGEOYeast/EvolutiveSCerevisiae_CODE
Rscript 99_correr_todo.R 01 12    # todos los pasos, en los tres escenarios
Rscript 99_correr_todo.R 06 09    # del paso 06 al 09
```

Igual que en *S. eubayanus*, `00_config.R` quedó con `PASO_DESDE <- "16"` y `PASO_HASTA <- "16"`, así que sin argumentos el orquestador corre solo el paso 16 en cada escenario. Para la corrida completa pasa `01 12` o cambia esos valores a `"01"` y `"12"`. El resto de las advertencias (relectura del VCF en el paso 02, modo `RAPIDO`, estado de salida de `12_validar.R`) está en el [README de S. eubayanus](../EvolutiveEubayanus_CODE/README.md#cómo-se-corre).

### Salidas

Las salidas quedan en `resultados/<escenario>/`, con un escenario por carpeta (`sitio`, `sitio_linaje` y `linaje`), y el orquestador escribe además `resultados/tiempos.tsv`. Los nombres de archivo son los mismos que en *S. eubayanus*; la [tabla de pasos y salidas](../EvolutiveEubayanus_CODE/README.md#pasos-y-salidas) los lista uno por uno.

## English

This folder holds the same phylogeographic R pipeline as [EvolutiveEubayanus_CODE/](../EvolutiveEubayanus_CODE/), configured for *Saccharomyces cerevisiae*. Of its 20 scripts, 19 are byte-identical to the ones in that folder; only `00_config.R` changes, in the 11 lines shown in the table below. The *S. eubayanus* README describes step by step what each script does and writes, and the [project README](../README.md) explains how the pipeline relates to the app.

### Requirements

The pipeline uses base R only; `rstudioapi` is optional and makes it easier to run from RStudio. The results bundled in the app record R 4.3.3.

### Inputs in DATA/

The scripts read their inputs from a `DATA/` folder inside this folder, which the repository does not include.

| File | Read by | Content |
|---|---|---|
| `DATA/1011Matrix.gvcf.gz` | `02_variantes.R` | Compressed VCF of the panel. The script reads it with `gzfile()` in batches of 20,000 lines and drops the contigs whose name contains `chromosome17`. |
| `DATA/MetaData_Scer.csv` | `01_datos.R` | Strain metadata. |
| `DATA/sitios_coords_Scer.csv` | `01_datos.R` | Coordinates per site, with the columns `Site`, `Latitud`, and `Longitud`. |
| `DATA/SGD_features.tab` or `DATA/gene_result.txt` | `16_marcadores.R` | Optional gene annotation. |
| `DATA/outgroup_ancestral.tsv` | `07_psi.R` | Optional ancestral state per site, with the columns `chrom`, `pos`, and `ancestral`; it is only used with `POLARIZAR <- "outgroup"`. |

From the metadata the pipeline uses `Strain` (it must match the sample names in the VCF), `Site`, `Population` (lineage), and optionally `Continente`, `Ecologia` (a sensitivity stratum in `11_controles.R`), and `Ploidia` (`01_datos.R` warns when strains have ploidy above 2). A `Source`, `Fuente`, `Study`, or `Estudio` column, when present, enables the control that leaves out each sampling campaign. According to `REFERENCIAS` in `00_config.R`, the *S. cerevisiae* panel and its lineage labels come from Peter et al. (2018).

In this repository, the [../../YeastForest/data/](../../YeastForest/data/) folder holds files with the names this configuration expects (`MetaData_Scer.csv` and `sitios_coords_Scer.csv`) and with the columns that are read. The VCF is not in the repository.

### Differences from the S. eubayanus configuration

| Line in `00_config.R` | *S. cerevisiae* (this folder) | *S. eubayanus* |
|---|---|---|
| `ARCHIVO_VCF` | `DATA/1011Matrix.gvcf.gz` | `DATA/filtered_eub.recode.vcf.bgz` |
| `ARCHIVO_META` | `DATA/MetaData_Scer.csv` | `DATA/MetaData_SEu.csv` |
| `ARCHIVO_COORDS` | `DATA/sitios_coords_Scer.csv` | `DATA/sitios_coords.csv` |
| `ESPECIE` | `"Saccharomyces cerevisiae"` | `"Saccharomyces eubayanus"` |
| `COL_ECOL` | `"Ecologia"` | `"Sustate"` |
| `COL_PLOIDIA` | `"Ploidia"` | empty |
| `RENOMBRAR` | no renaming | `467` becomes `CL467` |
| `CONTIG_EXCLUIR` | `"chromosome17"` | `"mtDNA"` |
| `MIN_DIST_LD` | 50 bp | 20 bp |
| `FRAC_AMPLIO` | 0.15 | 0.35 |
| `LARGO_GENOMA` | 12,071,326 bp, with the comment "S. cerevisiae S288C" | the same value, with the comment "S. eubayanus CBS 12357" |

The rest (scenarios, thresholds, seed, number of replicates, and the reference list) is the same in both folders, so any fix to a step has to be copied to both.

### How to run it

```bash
cd PhyloGEOYeast/EvolutiveSCerevisiae_CODE
Rscript 99_correr_todo.R 01 12    # all steps, in the three scenarios
Rscript 99_correr_todo.R 06 09    # from step 06 to step 09
```

As in *S. eubayanus*, `00_config.R` was left with `PASO_DESDE <- "16"` and `PASO_HASTA <- "16"`, so without arguments the runner executes only step 16 in each scenario. For the full run, pass `01 12` or change those values to `"01"` and `"12"`. The other warnings (VCF re-read in step 02, `RAPIDO` mode, exit status of `12_validar.R`) are in the [S. eubayanus README](../EvolutiveEubayanus_CODE/README.md#how-to-run-it).

### Outputs

The outputs go to `resultados/<scenario>/`, with one folder per scenario (`sitio`, `sitio_linaje`, and `linaje`), and the runner also writes `resultados/tiempos.tsv`. The file names are the same as for *S. eubayanus*; the [table of steps and outputs](../EvolutiveEubayanus_CODE/README.md#steps-and-outputs) lists them one by one.
