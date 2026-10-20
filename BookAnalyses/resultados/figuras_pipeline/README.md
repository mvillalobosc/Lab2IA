# resultados/figuras_pipeline/

[Español](#español) · [English](#english)

## Español

Estas 11 figuras diagnósticas salen de los módulos 04 a 08 en la corrida del manuscrito, cada una en PDF (`cairo_pdf`) y PNG a 300 ppp, con títulos en castellano. Los módulos las escriben en `output/figuras` con estos mismos nombres; aquí están copiadas a mano. Vuelve a [resultados/](../README.md).

| Figura | Módulo | Qué muestra |
|---|---|---|
| `04_pos_por_nivel` | 04 | La proporción de sustantivos, verbos, adjetivos, adverbios y conjunciones subordinantes por nivel, calculada sobre esas cinco categorías. |
| `04_pos_residuos` | 04 | Los residuos estandarizados del chi-cuadrado de categoría gramatical por nivel. |
| `05_polaridad_por_nivel` | 05 | La polaridad media de cada libro por nivel, con el léxico NRC en español. |
| `05_emociones_por_nivel` | 05 | La proporción media de cada emoción NRC por nivel. |
| `05_arcos_clusters` | 05 | Los arcos emocionales (DCT de 100 puntos) agrupados por cluster. |
| `06_complejidad_estandarizada` | 06 | La media por nivel de los puntajes z de complejidad y diversidad; en Szigriszt-Pazos un valor alto indica un texto más fácil. |
| `06_legibilidad_espanol` | 06 | Los índices de legibilidad calibrados para el español por nivel. |
| `07_keyness_etapas` | 07 | Los lemas característicos de cada etapa según log-likelihood. |
| `08_dendrograma_lsa` | 08 | El agrupamiento jerárquico del espacio semántico LSA con distancia chord y Ward.D2. |
| `08_pvclust_metricas` | 08 | El pvclust sobre el perfil de métricas, con los valores de soporte AU y BP de cada rama. |
| `08_umap_lsa` | 08 | La proyección UMAP del espacio semántico LSA. |

Dos detalles importan al leerlas. `08_pvclust_metricas` se generó con `pvclust_nboot = 200`, como dice su título; ese es el valor que `config.R` marca como de demo, y el comentario pide 1000 para la versión final. Además, con cientos de libros como hojas, las etiquetas de los dos dendrogramas no se leen, así que sirven para ver la estructura de las ramas altas. Las figuras `09_topicos_tendencia`, `10_gam_trayectorias` y `11_desajustados`, que también escribe el pipeline, no se copiaron. Tres PNG pasan de 1 MB (`05_arcos_clusters`, `08_dendrograma_lsa` y `08_pvclust_metricas`).

## English

These 11 diagnostic figures come from modules 04 to 08 in the manuscript run, each in PDF (`cairo_pdf`) and 300 dpi PNG, with Spanish titles. The modules write them to `output/figuras` under the same names; here they are copied by hand. Back to [resultados/](../README.md).

| Figure | Module | What it shows |
|---|---|---|
| `04_pos_por_nivel` | 04 | The share of nouns, verbs, adjectives, adverbs and subordinating conjunctions per grade, computed over those five categories. |
| `04_pos_residuos` | 04 | The standardised residuals of the part-of-speech by grade chi-squared test. |
| `05_polaridad_por_nivel` | 05 | The mean polarity of each book per grade, with the Spanish NRC lexicon. |
| `05_emociones_por_nivel` | 05 | The mean share of each NRC emotion per grade. |
| `05_arcos_clusters` | 05 | The emotional arcs (100-point DCT) grouped by cluster. |
| `06_complejidad_estandarizada` | 06 | The per-grade mean of the complexity and diversity z-scores; for Szigriszt-Pazos a high value means an easier text. |
| `06_legibilidad_espanol` | 06 | The Spanish-calibrated readability indices per grade. |
| `07_keyness_etapas` | 07 | The characteristic lemmas of each stage by log-likelihood. |
| `08_dendrograma_lsa` | 08 | The hierarchical clustering of the LSA semantic space with chord distance and Ward.D2. |
| `08_pvclust_metricas` | 08 | The pvclust run on the metric profile, with the AU and BP support values of each branch. |
| `08_umap_lsa` | 08 | The UMAP projection of the LSA semantic space. |

Two details matter when reading them. `08_pvclust_metricas` was generated with `pvclust_nboot = 200`, as its title says; that is the value `config.R` marks as the demo setting, and its comment asks for 1000 in the final version. Also, with hundreds of books as leaves, the labels of both dendrograms cannot be read, so they are useful to see the structure of the upper branches. The figures `09_topicos_tendencia`, `10_gam_trayectorias` and `11_desajustados`, which the pipeline also writes, were not copied. Three PNG files are larger than 1 MB (`05_arcos_clusters`, `08_dendrograma_lsa` and `08_pvclust_metricas`).
