# Bosque_eubayanus/ · YeastForest_code

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los scripts del bosque de *S. eubayanus*. Cada uno escribe sus resultados en esta misma carpeta y el bosque lee sus entradas desde `DATA/` relativa al directorio de trabajo, así que conviene correrlos desde aquí. El orden del paper es `bosque_Eubayanus.R`, `grupos_Eubayanus.R` y `publicar_bosque.R`. El [README del proyecto](../README.md) explica el flujo completo y los datos de entrada.

| Script | Qué hace | Lee | Escribe |
| --- | --- | --- | --- |
| `bosque_Eubayanus.R` | Hace lo mismo que el bosque de *S. cerevisiae* y además ubica los genes de NCBI, anotados sobre FM1318, en el ensamblaje CBS 12357 del VCF: en la primera corrida descarga los dos genomas de NCBI a `DATA/` y busca cada gen por secuencia, con anclas de 40 pb en cada extremo. | `DATA/filtered_eub.recode.vcf.bgz` y `DATA/gene_result.txt` | `Eubayanus_arboles.nwk`, `Eubayanus_distancias_geneticas.csv.gz`, `Eubayanus_RF.csv.gz`, `Eubayanus_concordancia.csv.gz`, `Eubayanus_resumen.tsv` y `Eubayanus_genes_sin_ubicar.tsv`; además `Eubayanus_muestras_renombradas.tsv` si algún identificador del VCF no es válido en Newick |
| `grupos_Eubayanus.R` | Agrupa los árboles con las mismas funciones MST-kNN de `clusters_SCerevisiae.R` y no prueba enriquecimiento, que el paper no reporta para esta especie. En el resumen deja enriquecido = "pendiente", la marca que `preparar_app.R` y la app leen como "no calculado". No tiene la opción `PHYLO_LIBRARY_ONLY`. | `Eubayanus_RF.csv.gz` y `Eubayanus_resumen.tsv` | `Eubayanus_clusters.tsv` y `Eubayanus_clusters_resumen.tsv` |
| `clusters_Eubayanus.R` | Es una variante opcional que agrupa igual y además prueba enriquecimiento GO y KEGG llevando cada gen a su ORF de *S. cerevisiae* (por una tabla de ortólogos, por el nombre sistemático de SGD o por el nombre del gen). No es parte del flujo del paper. | `Eubayanus_RF.csv.gz`, `Eubayanus_resumen.tsv` y la anotación GFF de `CONFIG$annotation` | `Eubayanus_clusters.tsv`, `Eubayanus_clusters_resumen.tsv` y `Eubayanus_enriquecimiento.tsv` |
| `publicar_bosque.R` | Corre los análisis A, B y D del paper; el análisis F solo aplica a *S. cerevisiae*. Importa las funciones de `bosque_Eubayanus.R` con `PHYLO_LIBRARY_ONLY=1`, así que los dos archivos tienen que estar juntos. | los resultados del bosque y de los grupos, `cepas_eubayanus.tsv` y la anotación (`gene_result.txt`, `gene_result_eubayanus.txt` o `DATA/gene_result.txt`, en esta carpeta o en la de arriba) | `Eubayanus_pub_A_*`, `_pub_B_*` y `_pub_D_*` |

`grupos_Eubayanus.R` y `clusters_Eubayanus.R` escriben los mismos archivos de grupos, así que correr uno sobrescribe el resultado del otro. El `CONFIG` de `clusters_Eubayanus.R` apunta la anotación a `~/EvolutiveEubayanus/DATA/GCA_003327605.1_genomic.gff`, una ruta que hay que cambiar en otro equipo. `publicar_bosque.R` es idéntico al de [Bosque_cerevisiae](../Bosque_cerevisiae/), donde está la lista completa de sus tablas.

Mientras corre, `bosque_Eubayanus.R` guarda su avance en la carpeta oculta `.tmp_bosque_Eubayanus` y retoma desde el último lote si se interrumpe; al terminar borra esa carpeta. Usa los mismos paquetes que el bosque de *S. cerevisiae* más `Biostrings`, compila sus funciones con Rcpp (requiere un compilador de C++) y necesita internet en la primera corrida para bajar los genomas. `grupos_Eubayanus.R` usa `data.table`, `igraph` y `mstknnclust`; `clusters_Eubayanus.R` usa además `R.utils`, `AnnotationDbi`, `org.Sc.sgd.db`, `GO.db` y `KEGGREST`.

La carpeta `DATA/` no viene en el repositorio, y el `.gitignore` de la raíz ignora esa carpeta, la carpeta temporal y todos los archivos `Eubayanus_*` que escriben los scripts.

## English

This folder holds the scripts of the *S. eubayanus* forest. Each one writes its results in this same folder and the forest script reads its inputs from `DATA/` relative to the working directory, so run them from here. The order used in the paper is `bosque_Eubayanus.R`, `grupos_Eubayanus.R` and `publicar_bosque.R`. The [project README](../README.md) explains the full workflow and the input data.

| Script | What it does | Reads | Writes |
| --- | --- | --- | --- |
| `bosque_Eubayanus.R` | Does the same as the *S. cerevisiae* forest and also places the NCBI genes, annotated on FM1318, on the CBS 12357 assembly of the VCF: on its first run it downloads both genomes from NCBI into `DATA/` and finds each gene by sequence, with 40 bp anchors at each end. | `DATA/filtered_eub.recode.vcf.bgz` and `DATA/gene_result.txt` | `Eubayanus_arboles.nwk`, `Eubayanus_distancias_geneticas.csv.gz`, `Eubayanus_RF.csv.gz`, `Eubayanus_concordancia.csv.gz`, `Eubayanus_resumen.tsv` and `Eubayanus_genes_sin_ubicar.tsv`; also `Eubayanus_muestras_renombradas.tsv` when a VCF sample ID is not valid in Newick |
| `grupos_Eubayanus.R` | Groups the trees with the same MST-kNN functions as `clusters_SCerevisiae.R` and does not test enrichment, which the paper does not report for this species. In the summary it sets enriquecido = "pendiente", the flag that `preparar_app.R` and the app read as "not computed". It has no `PHYLO_LIBRARY_ONLY` switch. | `Eubayanus_RF.csv.gz` and `Eubayanus_resumen.tsv` | `Eubayanus_clusters.tsv` and `Eubayanus_clusters_resumen.tsv` |
| `clusters_Eubayanus.R` | Is an optional variant that groups the same way and also tests GO and KEGG enrichment by mapping each gene to its *S. cerevisiae* ORF (through an orthologue table, the SGD systematic name or the gene name). It is not part of the workflow of the paper. | `Eubayanus_RF.csv.gz`, `Eubayanus_resumen.tsv` and the GFF annotation in `CONFIG$annotation` | `Eubayanus_clusters.tsv`, `Eubayanus_clusters_resumen.tsv` and `Eubayanus_enriquecimiento.tsv` |
| `publicar_bosque.R` | Runs analyses A, B and D of the paper; analysis F only applies to *S. cerevisiae*. It imports the functions of `bosque_Eubayanus.R` with `PHYLO_LIBRARY_ONLY=1`, so both files must sit together. | the forest and group results, `cepas_eubayanus.tsv` and the annotation (`gene_result.txt`, `gene_result_eubayanus.txt` or `DATA/gene_result.txt`, in this folder or the one above) | `Eubayanus_pub_A_*`, `_pub_B_*` and `_pub_D_*` |

`grupos_Eubayanus.R` and `clusters_Eubayanus.R` write the same group files, so running one overwrites the output of the other. The `CONFIG` of `clusters_Eubayanus.R` points the annotation to `~/EvolutiveEubayanus/DATA/GCA_003327605.1_genomic.gff`, a path that has to be changed on another machine. `publicar_bosque.R` is identical to the one in [Bosque_cerevisiae](../Bosque_cerevisiae/), which lists all its tables.

While it runs, `bosque_Eubayanus.R` saves its progress in the hidden folder `.tmp_bosque_Eubayanus` and resumes from the last batch if it stops; it deletes that folder when it finishes. It uses the same packages as the *S. cerevisiae* forest plus `Biostrings`, compiles its functions with Rcpp (which requires a C++ compiler) and needs internet access on its first run to download the genomes. `grupos_Eubayanus.R` uses `data.table`, `igraph` and `mstknnclust`; `clusters_Eubayanus.R` also uses `R.utils`, `AnnotationDbi`, `org.Sc.sgd.db`, `GO.db` and `KEGGREST`.

The `DATA/` folder is not in the repository, and the root `.gitignore` ignores that folder, the temporary folder and every `Eubayanus_*` file the scripts write.
