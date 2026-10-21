# data/ · YeastForest

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda dos cosas distintas. En la raíz de `data/` están los insumos que lee `preparar_app.R` y la metadata original de *S. cerevisiae*; esos archivos se mantienen a mano y el script no los modifica. `especies.js` y las carpetas `cerevisiae/` y `eubayanus/` son la salida del script y son lo que carga `index.html`. El [README del proyecto](../README.md) explica cómo se regeneran.

### Insumos (se mantienen a mano)

| Archivo | Contenido | Quién lo lee |
| --- | --- | --- |
| `cepas_cerevisiae.tsv` | Tiene 1.011 cepas y 13 columnas: cepa, Población, Aislado, Población de origen, Continente, País, Sitio, Ecología, Sustrato, Ploidía, Latitud, Longitud y Precision. Población es la asignación de Peter et al. (2018) y queda vacía en 48 cepas; las columnas de Aislado a Ploidía son las de `MetaData_Scer.csv`, y Latitud, Longitud y Precision vienen de `sitios_coords_Scer.csv` según el sitio (943 cepas tienen coordenadas). | `preparar_app.R` |
| `cepas_eubayanus.tsv` | Tiene 471 cepas y 7 columnas: cepa, Linaje, País, Localidad, Hospedero, Sustrato y Continente. Según el comentario de `preparar_app.R`, sale de `MetaData_SEu.csv`, que no está en el repositorio. | `preparar_app.R` |
| `genes_cerevisiae.tsv` | Tiene 3.903 genes con las columnas orf, nombre, descripcion y enlace (la ficha del gen en yeastgenome.org). | `preparar_app.R` |
| `gene_result_eubayanus.txt` | Es la lista de genes de *S. eubayanus* exportada de NCBI Gene (Send to > File > Tabular): 5.687 genes con columnas como GeneID, Symbol, Aliases, description, chromosome y las posiciones en el ensamblaje FM1318. El script toma el símbolo (o el GeneID si no hay símbolo) como identificador, los alias como nombre y la descripción. | `preparar_app.R` |
| `MetaData_Scer.csv` | Es la metadata original de las 1.011 cepas de *S. cerevisiae*, separada por `;`, con las columnas Strain, Aislado, Population, Continente, Country, Site, Ecologia, Sustrato y Ploidia. | Ningún script; es la fuente de las columnas de metadata de `cepas_cerevisiae.tsv` |
| `sitios_coords_Scer.csv` | Tiene las coordenadas de 369 sitios, separadas por `;`, con las columnas Site, Latitud, Longitud y Precision. Precision indica la escala de la coordenada: localidad, región, país, continente o centroide de varias cepas o localidades. | Ningún script; de aquí salen las coordenadas de `cepas_cerevisiae.tsv` |

El script lee los TSV en UTF-8. Las cabeceras de los dos `cepas_*.tsv` son los nombres de capa que ve el usuario en la app, y por eso están en castellano.

### Datos de la app (los genera `preparar_app.R`)

Todos los `.js` contienen JSON envuelto en `BF.load("<clave>", <json>);`, de modo que `index.html` los carga como `<script>` también al abrirlo con doble clic. La versión incluida pesa 143 MB, y la mayor parte está en las carpetas `arboles/`.

`especies.js` registra las dos especies: clave, nombre, fuente de los datos, plantilla del enlace de cada gen, número de árboles, de cepas y de grupos de cepas, capas, ORF sin árbol y sin ubicar, grupos MST-kNN, estado del enriquecimiento, SNP y biparticiones de la referencia, vecinos por árbol y fecha de preparación (2026-10-05 en la versión incluida).

Cada especie tiene su carpeta, `cerevisiae/` o `eubayanus/`, con estos archivos:

| Archivo | Contenido |
| --- | --- |
| `arboles.js` | Guarda una fila por árbol, en columnas: id, ORF, SNP, biparticiones, resolución, respaldo medio y mediano, RF media al resto del bosque, concordancia media, RF a la referencia, concordancia con la referencia en ambos sentidos, grupo MST-kNN y las proyecciones t-SNE, UMAP y MDS. |
| `vecinos.js` | Guarda los 15 árboles más cercanos por RF de cada árbol, como `[índice, RF, concordancia en un sentido, concordancia en el otro]`. |
| `grupos.js` | Guarda el estado del enriquecimiento, los grupos MST-kNN (tamaño, origen, medoide, RF media dentro del grupo y a la referencia, genes anotados, si está enriquecido y número de términos) y las pruebas de enriquecimiento que el script conserva: las de FDR menor que 0,25 y las tres mejores de cada grupo. *S. cerevisiae* tiene 210 grupos y 907 pruebas guardadas; *S. eubayanus* tiene 114 grupos y su enriquecimiento figura como pendiente. |
| `cepas.js` | Guarda los nombres de las cepas, las capas de color con sus grupos, las 10 cepas genéticamente más cercanas a cada una, la distancia genética media de cada cepa y, solo en *S. cerevisiae*, la metadata de cada cepa. |
| `genes.js` | Guarda el nombre, la descripción y el enlace de cada gen con anotación: 3.899 genes en *S. cerevisiae* y 5.320 en *S. eubayanus*. |
| `omitidos.js` | Guarda los ORF sin árbol con su motivo y número de SNP (710 en *S. cerevisiae* y 1.731 en *S. eubayanus*) y, en *S. eubayanus*, los 368 genes que no se pudieron ubicar en el genoma del VCF. |
| `meta.json` | Repite el registro de la especie que va en `especies.js`. |
| `huella.txt` | Anota el nombre, el tamaño y la fecha de modificación de los insumos de la última corrida; con ella el script decide si rehace la especie. |
| `arboles/` | Tiene un archivo por árbol: 5.904 en *S. cerevisiae* (5.903 `ORF_<id>.js` y `REF_TOTAL.js`) y 3.590 en *S. eubayanus* (3.589 `ORF_<id>.js` y `REF_TOTAL.js`). Cada archivo guarda el Newick del árbol sin raíz como cadena JSON, con largos de rama y el respaldo del bosque (porcentaje) en los nodos internos. En *S. cerevisiae* el id es el nombre sistemático de SGD (`ORF_YAL001C.js`) y en *S. eubayanus* es el símbolo de NCBI (`ORF_AAD14.js`) o, en 264 genes sin símbolo, el locus (`ORF_DI49_0065.js`). |

Estas dos carpetas no llevan README porque `preparar_app.R` las borra y las vuelve a escribir cada vez que rehace una especie.

## English

This folder holds two different things. The root of `data/` holds the inputs read by `preparar_app.R` and the original *S. cerevisiae* metadata; those files are kept by hand and the script never changes them. `especies.js` and the folders `cerevisiae/` and `eubayanus/` are the output of the script and are what `index.html` loads. The [project README](../README.md) explains how to rebuild them.

### Inputs (kept by hand)

| File | Content | Read by |
| --- | --- | --- |
| `cepas_cerevisiae.tsv` | It has 1,011 strains and 13 columns: cepa, Población, Aislado, Población de origen, Continente, País, Sitio, Ecología, Sustrato, Ploidía, Latitud, Longitud and Precision. Población is the assignment of Peter et al. (2018) and is empty for 48 strains; the columns from Aislado to Ploidía are those of `MetaData_Scer.csv`, and Latitud, Longitud and Precision come from `sitios_coords_Scer.csv` through the site (943 strains have coordinates). | `preparar_app.R` |
| `cepas_eubayanus.tsv` | It has 471 strains and 7 columns: cepa, Linaje, País, Localidad, Hospedero, Sustrato and Continente. According to the comment in `preparar_app.R`, it comes from `MetaData_SEu.csv`, which is not in the repository. | `preparar_app.R` |
| `genes_cerevisiae.tsv` | It has 3,903 genes with the columns orf, nombre, descripcion and enlace (the gene page at yeastgenome.org). | `preparar_app.R` |
| `gene_result_eubayanus.txt` | It is the *S. eubayanus* gene list exported from NCBI Gene (Send to > File > Tabular): 5,687 genes with columns such as GeneID, Symbol, Aliases, description, chromosome and the positions on the FM1318 assembly. The script takes the symbol (or the GeneID when there is no symbol) as identifier, the aliases as name, and the description. | `preparar_app.R` |
| `MetaData_Scer.csv` | It is the original metadata of the 1,011 *S. cerevisiae* strains, separated by `;`, with the columns Strain, Aislado, Population, Continente, Country, Site, Ecologia, Sustrato and Ploidia. | No script; it is the source of the metadata columns of `cepas_cerevisiae.tsv` |
| `sitios_coords_Scer.csv` | It has the coordinates of 369 sites, separated by `;`, with the columns Site, Latitud, Longitud and Precision. Precision gives the scale of the coordinate: locality, region, country, continent or centroid of several strains or localities. | No script; the coordinates of `cepas_cerevisiae.tsv` come from here |

The script reads the TSV files as UTF-8. The headers of the two `cepas_*.tsv` files are the layer names the user sees in the app, which is why they are in Spanish.

### App data (generated by `preparar_app.R`)

Every `.js` file holds JSON wrapped in `BF.load("<key>", <json>);`, so `index.html` loads them as `<script>` also when it is opened with a double click. The included version takes 143 MB, and most of it sits in the `arboles/` folders.

`especies.js` registers the two species: key, name, data source, gene link template, number of trees, strains and strain groups, layers, ORFs without a tree and unplaced genes, MST-kNN groups, enrichment status, SNPs and bipartitions of the reference, neighbours per tree and preparation date (2026-10-05 in the included version).

Each species has its own folder, `cerevisiae/` or `eubayanus/`, with these files:

| File | Content |
| --- | --- |
| `arboles.js` | Stores one row per tree, in columns: id, ORF, SNPs, bipartitions, resolution, mean and median support, mean RF to the rest of the forest, mean concordance, RF to the reference, concordance with the reference in both directions, MST-kNN group and the t-SNE, UMAP and MDS projections. |
| `vecinos.js` | Stores the 15 closest trees by RF for each tree, as `[index, RF, concordance one way, concordance the other way]`. |
| `grupos.js` | Stores the enrichment status, the MST-kNN groups (size, origin, medoid, mean RF within the group and to the reference, annotated genes, whether it is enriched and number of terms) and the enrichment tests the script keeps: those with FDR below 0.25 plus the best three of each group. *S. cerevisiae* has 210 groups and 907 stored tests; *S. eubayanus* has 114 groups and its enrichment is marked as pending. |
| `cepas.js` | Stores the strain names, the colour layers with their groups, the 10 genetically closest strains to each one, the mean genetic distance of each strain and, for *S. cerevisiae* only, the metadata of each strain. |
| `genes.js` | Stores the name, description and link of each annotated gene: 3,899 genes for *S. cerevisiae* and 5,320 for *S. eubayanus*. |
| `omitidos.js` | Stores the ORFs without a tree with their reason and SNP count (710 for *S. cerevisiae* and 1,731 for *S. eubayanus*) and, for *S. eubayanus*, the 368 genes that could not be placed on the genome of the VCF. |
| `meta.json` | Repeats the species record that goes into `especies.js`. |
| `huella.txt` | Records the name, size and modification time of the inputs of the last run; the script uses it to decide whether to rebuild the species. |
| `arboles/` | It has one file per tree: 5,904 for *S. cerevisiae* (5,903 `ORF_<id>.js` and `REF_TOTAL.js`) and 3,590 for *S. eubayanus* (3,589 `ORF_<id>.js` and `REF_TOTAL.js`). Each file stores the Newick of the unrooted tree as a JSON string, with branch lengths and the forest support (percentage) on the internal nodes. For *S. cerevisiae* the id is the SGD systematic name (`ORF_YAL001C.js`) and for *S. eubayanus* it is the NCBI symbol (`ORF_AAD14.js`) or, for 264 genes without a symbol, the locus tag (`ORF_DI49_0065.js`). |

These two folders have no README because `preparar_app.R` deletes and writes them again each time it rebuilds a species.
