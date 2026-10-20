# YeastForest: R workflow for phylogenetic forests

[Español](#español) · [English](#english)

## Español

Scripts en R del manuscrito *Gene-tree discordance across yeast genomes: phylogenetic forests of Saccharomyces cerevisiae and Saccharomyces eubayanus* (Villalobos-Cid, López Neilaf, Sáez Arias, Salinas, Cubillos, Villarreal y Kessi-Pérez). A partir de un VCF y de una anotación de genes, el flujo construye un árbol neighbour-joining por gen y un árbol de referencia del genoma completo con los mismos aislados, compara cada par de árboles y mide cuántas veces se repite cada rama en el bosque.

Los resultados de las dos especies se pueden explorar en el visor YeastForest: <https://mvillalobosc.diinf.usach.cl/YeastForest/>. El código del visor está en la carpeta [YeastForest](../YeastForest/) de este repositorio.

### Qué calcula el flujo

- **Árboles por gen y árbol de referencia.** Las distancias genéticas son diferencias absolutas medias en la dosis alélica normalizada (copias ALT divididas por la ploidía que declara GT), así que se tratan llamados haploides, diploides y poliploides sin fasear. Cada árbol es un neighbour-joining sin raíz; las ramas internas de largo 1e-10 o menor se colapsan.
- **Respaldo del bosque.** Para cada rama, el script calcula el porcentaje de los otros árboles de gen que contienen la misma bipartición. Es el factor de concordancia génica (Baum 2007; Minh et al. 2020) calculado para cada rama de cada árbol, y no es respaldo bootstrap.
- **Comparación de árboles.** Para cada par de árboles, incluida la referencia, se calculan la distancia de Robinson-Foulds normalizada, RF(A,B) = (sA + sB - 2c)/(sA + sB), y la concordancia direccional, C(A <- B) = 100 c/sA.
- **Grupos y pruebas.** El flujo arma grupos MST-kNN de árboles de gen (paquete `mstknnclust`), prueba enriquecimiento GO/KEGG en *S. cerevisiae*, aplica pruebas de permutación a la posición cromosómica de los grupos y filtros de resolución y de SNP, busca ramas recurrentes ausentes en la referencia y compara con un bosque anterior basado en alineamientos.

### Estructura de carpetas

```
YeastForest_code/
  README.md
  LICENSE
  cepas_cerevisiae.tsv         aislado y población (Peter et al. 2018)
  cepas_eubayanus.tsv          aislado, linaje y metadata geográfica y ecológica
  preparar_app.R               archivos de datos del visor YeastForest
  figuras_MER.R                Figuras 1 a 5 y las cifras del texto
  Bosque_cerevisiae/
    README.md
    bosque_SCerevisiae.R       bosque de S. cerevisiae
    clusters_SCerevisiae.R     grupos MST-kNN y enriquecimiento GO/KEGG
    publicar_bosque.R          análisis A, B, D y F del paper
    DATA/                      entradas: 1011Matrix.gvcf.gz y SGD_features.tab
    Arboles/                   árboles por alineamiento, un <ORF>.nwk por gen (solo análisis F)
  Bosque_eubayanus/
    README.md
    bosque_Eubayanus.R         bosque de S. eubayanus
    grupos_Eubayanus.R         grupos MST-kNN sin enriquecimiento (los del paper)
    clusters_Eubayanus.R       variante opcional: grupos MST-kNN con enriquecimiento por ortólogos
    publicar_bosque.R          análisis A, B y D del paper (el mismo archivo de arriba)
    DATA/                      entradas: filtered_eub.recode.vcf.bgz y gene_result.txt
```

Las carpetas `DATA/` y `Arboles/` no son parte de este repositorio; la sección de datos de entrada explica de dónde salen. El `.gitignore` de la raíz del repositorio ignora `DATA/`, `Arboles/`, las carpetas temporales `.tmp_bosque_*`, los resultados que los scripts escriben junto a sí mismos (`SCerevisiae_*` y `Eubayanus_*`) y las carpetas `data/` y `figs/`. Cada carpeta de especie tiene su propio README con el detalle de sus scripts: [Bosque_cerevisiae](Bosque_cerevisiae/README.md) y [Bosque_eubayanus](Bosque_eubayanus/README.md).

### Cómo correr el flujo

Cada script escribe sus resultados junto a sí mismo. Los scripts de bosque leen `DATA/` relativa al directorio de trabajo, así que cada script se corre desde su propia carpeta:

```
cd Bosque_cerevisiae
Rscript bosque_SCerevisiae.R
Rscript clusters_SCerevisiae.R
Rscript publicar_bosque.R

cd ../Bosque_eubayanus
Rscript bosque_Eubayanus.R
Rscript grupos_Eubayanus.R
Rscript publicar_bosque.R

cd ..
Rscript preparar_app.R
Rscript figuras_MER.R
```

Los scripts también corren con `source()` o como RStudio Jobs. La configuración está al comienzo de cada script, en la lista `CONFIG` cuando existe. Los scripts de bosque guardan su avance en la carpeta oculta `.tmp_bosque_<prefijo>` y, si una corrida se interrumpe, la siguiente retoma desde el último lote; al terminar borran esa carpeta, y para partir de cero basta con borrarla. Con la variable de entorno `PHYLO_LIBRARY_ONLY=1`, un script de bosque o de clusters carga sus funciones sin ejecutarse; `grupos_Eubayanus.R` no tiene esa opción. `preparar_app.R` y `figuras_MER.R` resuelven las rutas desde su propia carpeta.

`clusters_Eubayanus.R` es una variante de `grupos_Eubayanus.R` que además prueba enriquecimiento GO/KEGG en *S. eubayanus*, llevando cada gen a su ORF de *S. cerevisiae*. No es parte del flujo del paper y escribe los mismos `Eubayanus_clusters.tsv` y `Eubayanus_clusters_resumen.tsv` (más `Eubayanus_enriquecimiento.tsv`), así que correr uno sobrescribe el resultado del otro. Su `CONFIG` apunta la anotación a `~/EvolutiveEubayanus/DATA/GCA_003327605.1_genomic.gff`, una ruta que hay que cambiar en otro equipo.

El bosque de *S. cerevisiae* (1.011 aislados, 6.613 ORF) se calculó en un servidor. El número de procesos paralelos se fija con `workers` en `CONFIG`.

### Datos de entrada

- **Genotipos de *S. cerevisiae*:** `1011Matrix.gvcf.gz`, la matriz de genotipos de los 1.011 aislados de Peter et al. (2018), disponible en <http://1002genomes.u-strasbg.fr/files/>.
- **Anotación de *S. cerevisiae*:** `SGD_features.tab`, el archivo de características cromosómicas de Saccharomyces Genome Database (<https://www.yeastgenome.org>).
- **Genotipos de *S. eubayanus*:** `filtered_eub.recode.vcf.bgz`, el conjunto de variantes de 471 aislados sobre el ensamblaje CBS 12357 (GCA_003327605.1). Se depositará en Zenodo junto con los bosques derivados, la metadata de los aislados, el bosque por alineamientos del análisis F y una versión archivada de este código.
- **Anotación de *S. eubayanus*:** `gene_result.txt`, la lista tabular de NCBI Gene (Send to > File > Tabular). Sus coordenadas están en el ensamblaje FM1318 (GCF_001298625.1), por eso `bosque_Eubayanus.R` descarga ambos genomas de NCBI a `DATA/` en su primera corrida y ubica cada gen en CBS 12357 por secuencia. Los genes que no se pueden ubicar sin ambigüedad quedan en `Eubayanus_genes_sin_ubicar.tsv` con el motivo.

Se pueden analizar otras especies cambiando `CONFIG` en un script de bosque: el VCF, la anotación (`SGD_features.tab`, un GFF3 o una tabla con cromosoma, inicio, fin e identificador de gen) y, si los nombres de cromosoma difieren entre ellos, un mapa de cromosomas.

### Archivos de salida principales

Los nombres de archivos y columnas conservan el castellano que se usó durante el proyecto.

| Archivo | Contenido |
| --- | --- |
| `<prefijo>_arboles.nwk` | La línea 1 es el árbol de referencia y después viene un árbol por gen; las etiquetas de los nodos llevan el respaldo del bosque. |
| `<prefijo>_resumen.tsv` | Tiene una fila por árbol con SNP, resolución, respaldo medio y RF a la referencia; los genes sin árbol llevan el motivo. |
| `<prefijo>_RF.csv.gz` | Guarda las distancias RF normalizadas, todos contra todos. |
| `<prefijo>_concordancia.csv.gz` | Guarda la concordancia direccional: % de las ramas del árbol de la fila presentes en el árbol de la columna. |
| `<prefijo>_distancias_geneticas.csv.gz` | Guarda las distancias genéticas entre aislados que usa el árbol de referencia. |
| `<prefijo>_clusters.tsv`, `<prefijo>_clusters_resumen.tsv` | Asignan cada árbol de gen a un grupo MST-kNN y resumen cada grupo. |
| `<prefijo>_enriquecimiento.tsv` | Lista cada prueba de enriquecimiento GO/KEGG (*S. cerevisiae*). |
| `<prefijo>_pub_A_*`, `_pub_B_*`, `_pub_D_*`, `_pub_F_*` | Son las tablas de los análisis A, B, D y F que reporta el paper. |
| `data/` | Contiene los archivos de datos del visor YeastForest; `preparar_app.R` la crea junto a sí mismo. |
| `figs/` | `figuras_MER.R` la crea junto a sí mismo: las Figuras 1 a 5 (`Fig1_esquema`, `Fig2_mapa_genoma`, `Fig3_resolucion`, `Fig4_conflicto` y `Fig5_validacion`, en PDF y PNG), las tablas de apoyo (`ligamiento_grupos_<especie>.tsv`, `tabla2_enriquecidos.tsv`, `conflicto_top_<cer\|eub>.tsv` y `conflicto_biparticiones_<cer\|eub>.tsv`) y `cifras.tsv` con las cifras del texto. La Figura 6 son capturas del visor y no sale de aquí. |

El prefijo es `SCerevisiae` o `Eubayanus`. Palabras en castellano de los nombres de archivo: arboles = trees, resumen = summary, concordancia = concordance, distancias geneticas = genetic distances, enriquecimiento = enrichment, cepas = strains.

`figuras_MER.R` necesita que ya existan `data/` (de `preparar_app.R`), los grupos de las dos especies y las tablas `_pub_*` de `publicar_bosque.R` en las dos carpetas.

### Relación con la app YeastForest

La carpeta [YeastForest](../YeastForest/) trae su propia copia de `preparar_app.R`, que es la que produce la vista de metadata de la app. La copia de aquí es la versión en inglés del mismo script, pero no escribe el campo `metadata` de `cepas.js`, no separa las columnas no categóricas (aislado, población de origen, latitud, longitud, precisión) y traduce al inglés los motivos de los ORF omitidos. Los `cepas_*.tsv` de los dos proyectos tampoco son intercambiables: aquí tienen cabeceras en inglés (`isolate`, `Population`; `isolate`, `Lineage`, `Country`, `Locality`, `Host`, `Substrate`, `Continent`) y en YeastForest las tienen en castellano, y la app muestra esas cabeceras como nombres de capa. `cepas_cerevisiae.tsv` tiene aquí 963 aislados con su población, mientras que el de YeastForest tiene los 1.011 con la metadata completa.

### Requisitos

El flujo necesita R con los paquetes de CRAN `ape`, `data.table`, `Matrix`, `Rcpp`, `digest`, `R.utils`, `igraph`, `mstknnclust`, `jsonlite`, `Rtsne` y `uwot`, y los paquetes de Bioconductor `VariantAnnotation`, `Rsamtools`, `GenomicRanges`, `GenomeInfoDb`, `IRanges`, `SummarizedExperiment`, `S4Vectors`, `Biostrings`, `AnnotationDbi`, `org.Sc.sgd.db`, `GO.db` y `KEGGREST`. Los scripts intentan instalar los paquetes que faltan. Las rutas KEGG y los genomas de NCBI se descargan, así que esos pasos necesitan internet. Las funciones de distancia en C++ se compilan con Rcpp, lo que requiere un compilador de C++. `figuras_MER.R` escribe los PDF con `cairo_pdf`, que exige un R con soporte de Cairo.

### Licencia y contacto

Licencia MIT (ver `LICENSE`). Manuel Villalobos-Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile: manuel.villalobos@usach.cl

### Referencias

- Baum DA (2007) Concordance trees, concordance factors, and the exploration of reticulate genealogy. *Taxon* 56: 417-426.
- Minh BQ, Hahn MW, Lanfear R (2020) New methods to calculate concordance factors for phylogenomic datasets. *Molecular Biology and Evolution* 37: 2727-2733.
- Peter J, De Chiara M, Friedrich A, et al. (2018) Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature* 556: 339-344.

## English

R scripts used in the manuscript *Gene-tree discordance across yeast genomes: phylogenetic forests of Saccharomyces cerevisiae and Saccharomyces eubayanus* (Villalobos-Cid, López Neilaf, Sáez Arias, Salinas, Cubillos, Villarreal and Kessi-Pérez). From a VCF and a gene annotation, the workflow builds one neighbour-joining tree per gene and a genome-wide reference tree with the same isolates, compares every pair of trees and measures how often each branch recurs across the forest.

The results for both species can be explored in the YeastForest viewer: <https://mvillalobosc.diinf.usach.cl/YeastForest/>. The code of the viewer is in the [YeastForest](../YeastForest/) folder of this repository.

### What the workflow computes

- **Gene trees and reference tree.** Genetic distances are mean absolute differences in normalised allele dosage (ALT copies divided by the ploidy declared in GT), so haploid, diploid and polyploid calls are handled without phasing. Each tree is an unrooted neighbour-joining tree; internal branches of length 1e-10 or less are collapsed.
- **Forest support.** For each branch, the percentage of the other gene trees that contain the same bipartition. This is the gene concordance factor (Baum 2007; Minh et al. 2020) computed for every branch of every tree. It is not bootstrap support.
- **Tree comparison.** Normalised Robinson-Foulds distance, RF(A,B) = (sA + sB - 2c)/(sA + sB), and directional concordance, C(A <- B) = 100 c/sA, for every pair of trees, including the reference.
- **Groups and tests.** MST-kNN groups of gene trees (package `mstknnclust`), GO/KEGG enrichment for *S. cerevisiae*, permutation tests for the chromosomal position of the groups, resolution and SNP filters, recurrent branches absent from the reference, and the comparison with an earlier alignment-based forest.

### Folder layout

```
YeastForest_code/
  README.md
  LICENSE
  cepas_cerevisiae.tsv         isolate and population (Peter et al. 2018)
  cepas_eubayanus.tsv          isolate, lineage and geographic/ecological metadata
  preparar_app.R               data files of the YeastForest viewer
  figuras_MER.R                Figures 1 to 5 and the numbers reported in the text
  Bosque_cerevisiae/
    README.md
    bosque_SCerevisiae.R       forest of S. cerevisiae
    clusters_SCerevisiae.R     MST-kNN groups and GO/KEGG enrichment
    publicar_bosque.R          analyses A, B, D and F of the paper
    DATA/                      inputs: 1011Matrix.gvcf.gz and SGD_features.tab
    Arboles/                   alignment-based trees, one <ORF>.nwk per gene (analysis F only)
  Bosque_eubayanus/
    README.md
    bosque_Eubayanus.R         forest of S. eubayanus
    grupos_Eubayanus.R         MST-kNN groups without enrichment (those of the paper)
    clusters_Eubayanus.R       optional variant: MST-kNN groups with enrichment through orthologues
    publicar_bosque.R          analyses A, B and D of the paper (same file as above)
    DATA/                      inputs: filtered_eub.recode.vcf.bgz and gene_result.txt
```

The `DATA/` and `Arboles/` folders are not part of this repository; see the input data section below. The `.gitignore` at the root of the repository ignores `DATA/`, `Arboles/`, the temporary `.tmp_bosque_*` folders, the results the scripts write next to themselves (`SCerevisiae_*` and `Eubayanus_*`) and the `data/` and `figs/` folders. Each species folder has its own README with the details of its scripts: [Bosque_cerevisiae](Bosque_cerevisiae/README.md) and [Bosque_eubayanus](Bosque_eubayanus/README.md).

### Running the workflow

Each script writes its results next to itself. The forest scripts read `DATA/` relative to the working directory, so run every script from its own folder:

```
cd Bosque_cerevisiae
Rscript bosque_SCerevisiae.R
Rscript clusters_SCerevisiae.R
Rscript publicar_bosque.R

cd ../Bosque_eubayanus
Rscript bosque_Eubayanus.R
Rscript grupos_Eubayanus.R
Rscript publicar_bosque.R

cd ..
Rscript preparar_app.R
Rscript figuras_MER.R
```

The scripts can also be run with `source()` or as RStudio Jobs. Settings are at the top of each script, in the `CONFIG` list where there is one. The forest scripts save their progress in the hidden folder `.tmp_bosque_<prefix>` and resume from the last batch if a run is interrupted; they delete that folder when they finish, and deleting it by hand starts a run from scratch. Setting the environment variable `PHYLO_LIBRARY_ONLY=1` loads the functions of a forest or cluster script without running it; `grupos_Eubayanus.R` has no such switch. `preparar_app.R` and `figuras_MER.R` resolve their paths from their own folder.

`clusters_Eubayanus.R` is a variant of `grupos_Eubayanus.R` that also tests GO/KEGG enrichment for *S. eubayanus* by mapping each gene to its *S. cerevisiae* ORF. It is not part of the workflow of the paper and it writes the same `Eubayanus_clusters.tsv` and `Eubayanus_clusters_resumen.tsv` (plus `Eubayanus_enriquecimiento.tsv`), so running one overwrites the output of the other. Its `CONFIG` points the annotation to `~/EvolutiveEubayanus/DATA/GCA_003327605.1_genomic.gff`, a path that has to be changed on another machine.

The *S. cerevisiae* forest (1,011 isolates, 6,613 ORFs) was computed on a server. The number of parallel processes is set with `workers` in `CONFIG`.

### Input data

- ***S. cerevisiae* genotypes:** `1011Matrix.gvcf.gz`, the genotype matrix of the 1,011 isolates of Peter et al. (2018), available at <http://1002genomes.u-strasbg.fr/files/>.
- ***S. cerevisiae* annotation:** `SGD_features.tab`, the chromosomal features file of the Saccharomyces Genome Database (<https://www.yeastgenome.org>).
- ***S. eubayanus* genotypes:** `filtered_eub.recode.vcf.bgz`, the variant call set of 471 isolates on the CBS 12357 assembly (GCA_003327605.1). It will be deposited in Zenodo with the derived forests, the isolate metadata, the alignment-based forest of analysis F and an archived release of this code.
- ***S. eubayanus* annotation:** `gene_result.txt`, the tabular gene list of NCBI Gene (Send to > File > Tabular). Its coordinates refer to the FM1318 assembly (GCF_001298625.1), so `bosque_Eubayanus.R` downloads both genomes from NCBI into `DATA/` on its first run and locates each gene on CBS 12357 by sequence. Genes that cannot be located unambiguously are listed in `Eubayanus_genes_sin_ubicar.tsv` with the reason.

Other species can be analysed by changing `CONFIG` in a forest script: the VCF, the annotation (`SGD_features.tab`, a GFF3 or a table with chromosome, start, end and gene ID) and, if chromosome names differ between them, a chromosome map.

### Main output files

File and column names keep the Spanish names used during the project.

| File | Content |
| --- | --- |
| `<prefix>_arboles.nwk` | line 1 is the reference tree, then one tree per gene; node labels hold the forest support |
| `<prefix>_resumen.tsv` | one row per tree: SNPs, resolution, mean support, RF to the reference; genes without a tree carry the reason |
| `<prefix>_RF.csv.gz` | normalised RF distances, all against all |
| `<prefix>_concordancia.csv.gz` | directional concordance: % of the branches of the row tree present in the column tree |
| `<prefix>_distancias_geneticas.csv.gz` | genetic distances between isolates used by the reference tree |
| `<prefix>_clusters.tsv`, `<prefix>_clusters_resumen.tsv` | MST-kNN group of each gene tree and summary per group |
| `<prefix>_enriquecimiento.tsv` | every GO/KEGG enrichment test (*S. cerevisiae*) |
| `<prefix>_pub_A_*`, `_pub_B_*`, `_pub_D_*`, `_pub_F_*` | tables of the analyses A, B, D and F reported in the paper |
| `data/` | data files of the YeastForest viewer, created by `preparar_app.R` next to itself |
| `figs/` | created by `figuras_MER.R` next to itself: Figures 1 to 5 (`Fig1_esquema`, `Fig2_mapa_genoma`, `Fig3_resolucion`, `Fig4_conflicto` and `Fig5_validacion`, as PDF and PNG), the supporting tables (`ligamiento_grupos_<species>.tsv`, `tabla2_enriquecidos.tsv`, `conflicto_top_<cer\|eub>.tsv` and `conflicto_biparticiones_<cer\|eub>.tsv`) and `cifras.tsv` with the numbers of the text; Figure 6 shows screenshots of the viewer and is not produced here |

The prefix is `SCerevisiae` or `Eubayanus`. Spanish words in the file names: arboles = trees, resumen = summary, concordancia = concordance, distancias geneticas = genetic distances, enriquecimiento = enrichment, cepas = strains.

`figuras_MER.R` needs `data/` (from `preparar_app.R`), the groups of both species and the `_pub_*` tables of `publicar_bosque.R` in both folders to exist already.

### Relation with the YeastForest app

The [YeastForest](../YeastForest/) folder ships its own copy of `preparar_app.R`, which is the one that produces the metadata view of the app. The copy here is the English version of the same script, but it does not write the `metadata` field of `cepas.js`, does not set apart the non-categorical columns (isolate, population of origin, latitude, longitude, precision) and translates the reasons of the omitted ORFs into English. The `cepas_*.tsv` files of the two projects are not interchangeable either: here their headers are in English (`isolate`, `Population`; `isolate`, `Lineage`, `Country`, `Locality`, `Host`, `Substrate`, `Continent`) and in YeastForest they are in Spanish, and the app shows those headers as layer names. Here `cepas_cerevisiae.tsv` has 963 isolates with their population, while the one in YeastForest has all 1,011 with the full metadata.

### Requirements

The workflow needs R with the CRAN packages `ape`, `data.table`, `Matrix`, `Rcpp`, `digest`, `R.utils`, `igraph`, `mstknnclust`, `jsonlite`, `Rtsne` and `uwot`, and the Bioconductor packages `VariantAnnotation`, `Rsamtools`, `GenomicRanges`, `GenomeInfoDb`, `IRanges`, `SummarizedExperiment`, `S4Vectors`, `Biostrings`, `AnnotationDbi`, `org.Sc.sgd.db`, `GO.db` and `KEGGREST`. The scripts try to install missing packages. The KEGG pathways and the NCBI genomes are downloaded, so those steps need internet access. The C++ distance functions are compiled with Rcpp, which requires a C++ compiler. `figuras_MER.R` writes its PDF files with `cairo_pdf`, which needs an R build with Cairo support.

### Licence and contact

MIT licence (see `LICENSE`). Manuel Villalobos-Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile: manuel.villalobos@usach.cl

### References

- Baum DA (2007) Concordance trees, concordance factors, and the exploration of reticulate genealogy. *Taxon* 56: 417-426.
- Minh BQ, Hahn MW, Lanfear R (2020) New methods to calculate concordance factors for phylogenomic datasets. *Molecular Biology and Evolution* 37: 2727-2733.
- Peter J, De Chiara M, Friedrich A, et al. (2018) Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature* 556: 339-344.
