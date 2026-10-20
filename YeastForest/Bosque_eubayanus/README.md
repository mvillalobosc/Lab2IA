# Bosque_eubayanus/ · YeastForest

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los grupos MST-kNN del bosque de *S. eubayanus*. `preparar_app.R` la usa como carpeta de resultados de esa especie (`carpeta = "Bosque_eubayanus"` en su `CONFIG`) y toma de ella los grupos que muestra la vista Grupos. Los dos archivos los escribe `grupos_Eubayanus.R`, que está en [YeastForest_code/Bosque_eubayanus](../../YeastForest_code/Bosque_eubayanus/). Los resultados obligatorios del bosque (`Eubayanus_resumen.tsv`, `Eubayanus_arboles.nwk`, `Eubayanus_RF.csv.gz`, `Eubayanus_concordancia.csv.gz` y `Eubayanus_distancias_geneticas.csv.gz`) no están aquí, y sin ellos `preparar_app.R` no puede rehacer la especie. El [README del proyecto](../README.md) explica la regeneración completa.

| Archivo | Contenido |
| --- | --- |
| `Eubayanus_clusters.tsv` | Tiene un árbol de ORF por fila (3.589 filas) con las columnas tree_id, orf, cluster, tamano_cluster, origen, n_snps, n_splits, RF_al_global, orf_sgd y como_se_mapeo. Las dos últimas quedan en NA porque `grupos_Eubayanus.R` no lleva los genes a sus ORF de *S. cerevisiae*. |
| `Eubayanus_clusters_resumen.tsv` | Tiene un grupo por fila (114 filas) con las columnas cluster, tamano, origen, genes_anotados, RF_media_dentro, RF_media_al_global, terminos_FDR, principales y enriquecido. |

De los 114 grupos, 52 salen de MST-kNN y reúnen 3.527 árboles. Los otros 62 tienen origen "solo en MST-kNN": son árboles que `mst.knn` dejó fuera de la solución y que el script devuelve como grupos de un ORF. Los 114 grupos tienen enriquecido = "pendiente", la marca que `preparar_app.R` y la app leen como "no calculado". Los dos archivos usan tabulador como separador y comillas en los textos.

## English

This folder holds the MST-kNN groups of the *S. eubayanus* forest. `preparar_app.R` uses it as the results folder of that species (`carpeta = "Bosque_eubayanus"` in its `CONFIG`) and takes from it the groups shown in the Grupos view. Both files are written by `grupos_Eubayanus.R`, which lives in [YeastForest_code/Bosque_eubayanus](../../YeastForest_code/Bosque_eubayanus/). The required forest results (`Eubayanus_resumen.tsv`, `Eubayanus_arboles.nwk`, `Eubayanus_RF.csv.gz`, `Eubayanus_concordancia.csv.gz` and `Eubayanus_distancias_geneticas.csv.gz`) are not here, and without them `preparar_app.R` cannot rebuild the species. The [project README](../README.md) explains the full rebuild.

| File | Content |
| --- | --- |
| `Eubayanus_clusters.tsv` | It has one ORF tree per row (3,589 rows) with the columns tree_id, orf, cluster, tamano_cluster, origen, n_snps, n_splits, RF_al_global, orf_sgd and como_se_mapeo. The last two are NA because `grupos_Eubayanus.R` does not map the genes to their *S. cerevisiae* ORFs. |
| `Eubayanus_clusters_resumen.tsv` | It has one group per row (114 rows) with the columns cluster, tamano, origen, genes_anotados, RF_media_dentro, RF_media_al_global, terminos_FDR, principales and enriquecido. |

Of the 114 groups, 52 come from MST-kNN and hold 3,527 trees. The other 62 have the origin "solo en MST-kNN": they are trees that `mst.knn` left out of the solution and that the script returns as one-ORF groups. All 114 groups have enriquecido = "pendiente", the flag that `preparar_app.R` and the app read as "not computed". Both files use tabs as separators and quote the text fields.
