# YeastForest · Bosque Filogenético

[Español](#español) · [English](#english)

## Español

YeastForest es la aplicación web que muestra los bosques filogenéticos de *Saccharomyces cerevisiae* y *Saccharomyces eubayanus*; en la interfaz se llama "Bosque Filogenético". Cada bosque reúne un árbol neighbour-joining sin raíz por ORF y un árbol de referencia construido con todos los SNP del genoma. El bosque de *S. cerevisiae* tiene 5.903 árboles de ORF sobre 1.011 cepas y el de *S. eubayanus* tiene 3.589 árboles sobre 471 cepas, según `data/especies.js`. La versión publicada está en <https://mvillalobosc.diinf.usach.cl/YeastForest/> y el código R que calcula los bosques está en [YeastForest_code](../YeastForest_code/).

### Abrir la app

Abre `index.html` con doble clic; si recibiste la app en un paquete, descomprime antes la carpeta completa. También puedes ejecutar `python servir.py`, que levanta un servidor local en el primer puerto libre desde el 8000, abre el navegador y se detiene con Ctrl+C. La app no necesita servidor porque los datos de `data/` son archivos `.js` que envuelven JSON en una llamada `BF.load(...)`: el navegador los carga como `<script>` aunque no permita `fetch()` en `file://`. La única conexión externa son las fuentes de Google Fonts, y sin red la app usa las fuentes del sistema.

### Uso

1. Elige la especie.
2. Busca un gen por ORF, nombre o descripción, o selecciona un punto del bosque.
3. Consulta el árbol y su ficha. En móvil, usa Explorar, Árbol y Ficha y vecinos.
4. Busca otro gen en Comparar para ver sus biparticiones compartidas y métricas.
5. Usa Descargar para exportar el árbol o los vecinos.

Las opciones de color, grupos, ramas y nombres están en secciones desplegables. Ampliar árbol dedica el espacio al árbol y el mismo botón devuelve los paneles. La tecla / lleva a la búsqueda y Escape cierra la ayuda, la comparación o el filtro.

Las ayudas junto a los paneles explican las proyecciones, RF, concordancia, resolución y respaldo, y Guía técnica abre las fórmulas en diez secciones: qué es, el bosque, leer un árbol, respaldo, RF y concordancia, grupos, enriquecimiento, referencia, controles y créditos. El respaldo del bosque no es bootstrap, y las posiciones en el bosque no son coordenadas geográficas ni tiempo evolutivo.

La barra de navegación tiene seis vistas: Cepas y metadata, Bosque, Grupos, Referencia, Especies y Omitidos. Desde ellas puedes descargar cada árbol en Newick, SVG o PNG, sus vecinos en CSV y su vecindario en Newick, los genes y el enriquecimiento de un grupo en CSV, el árbol de referencia en SVG o Newick y la lista de ORF omitidos en CSV.

Validación: la carga, el dibujo de los árboles, la comparación y las ayudas se probaron con datos de ambas especies mediante DOM automatizado, y la sintaxis JavaScript se verificó. La apariencia y los gestos táctiles requieren una comprobación en un navegador real.

### Metadata de *S. cerevisiae*

La sección Cepas y metadata consulta las 1.011 cepas e incluye aislado, población de origen, continente, país, sitio, ecología, sustrato, ploidía, coordenadas y precisión geográfica. Hay 943 cepas con coordenadas registradas. Los CSV originales se incluyen completos en `data/MetaData_Scer.csv` y `data/sitios_coords_Scer.csv`. La población que ya usaba la app (Peter et al., 2018) se mantiene en la columna Población, y la población del CSV se conserva como el campo separado Población de origen.

En la barra de grupos de cepas eliges la variable que colorea el anillo. Un clic en una cepa de la tabla abre su ficha en Referencia, y el CSV exportado respeta la búsqueda activa. `data/cepas_cerevisiae.tsv` y `preparar_app.R` conservan la metadata en las regeneraciones siguientes.

### Idiomas

Los botones superiores 🇨🇱 ES, 🇬🇧 EN y 🇧🇷 BR alternan la interfaz, las fichas, los mensajes, las búsquedas, las tablas y las ayudas técnicas entre español, inglés y portugués de Brasil. El navegador recuerda la elección en la clave `bf-interface-language` de `localStorage`. Las traducciones vienen en el paquete (`i18n.js`, `i18n-dictionary.js` e `i18n-help.js`) y funcionan sin un servicio de traducción externo. Los identificadores científicos y los valores originales de la metadata se conservan.

### Contenido de la carpeta

```
YeastForest/
├── .htaccess
├── LICENSE
├── README.md
├── index.html
├── i18n.js
├── i18n-dictionary.js
├── i18n-help.js
├── preparar_app.R
├── servir.py
├── Bosque_eubayanus/
└── data/
```

| Archivo o carpeta | Qué contiene o hace |
| --- | --- |
| `index.html` | Contiene la app completa en un solo archivo: estilos, HTML y los scripts que dibujan el bosque, los árboles, la comparación, la referencia, los grupos y la metadata. |
| `i18n.js` | Traduce la interfaz en el navegador y maneja los botones de idioma. |
| `i18n-dictionary.js` | Guarda la traducción al inglés y al portugués de Brasil de los textos de la interfaz. |
| `i18n-help.js` | Guarda las diez secciones de la ayuda técnica en inglés y en portugués de Brasil. |
| `servir.py` | Sirve la carpeta en `http://localhost:<puerto>/index.html` y abre el navegador; usa solo la biblioteca estándar de Python 3 y avisa si no encuentra `index.html` a su lado. |
| `preparar_app.R` | Genera `data/especies.js` y las carpetas de cada especie a partir de los resultados del bosque. |
| `.htaccess` | Configura Apache para publicar la app (ver más abajo). |
| [`data/`](data/) | Guarda los datos que carga la app y los insumos de `preparar_app.R`. |
| [`Bosque_eubayanus/`](Bosque_eubayanus/) | Guarda los grupos MST-kNN de *S. eubayanus* que `preparar_app.R` lleva a la app. |

### Regenerar los datos de la app

`preparar_app.R` escribe `data/especies.js` y, para cada especie, la carpeta `data/<especie>/` con los árboles, los vecinos, los grupos, las cepas, la anotación de genes y los ORF omitidos; [data/README.md](data/README.md) describe cada archivo. Para correrlo necesitas, junto al script, las carpetas `Bosque_cerevisiae/` y `Bosque_eubayanus/` con los resultados del bosque que produce [YeastForest_code](../YeastForest_code/). Son obligatorios `<prefijo>_resumen.tsv`, `<prefijo>_arboles.nwk`, `<prefijo>_RF.csv.gz`, `<prefijo>_concordancia.csv.gz` y `<prefijo>_distancias_geneticas.csv.gz`, y son opcionales `<prefijo>_clusters.tsv`, `<prefijo>_clusters_resumen.tsv`, `<prefijo>_enriquecimiento.tsv` y `<prefijo>_genes_sin_ubicar.tsv`, donde el prefijo es `SCerevisiae` o `Eubayanus`. Esos resultados no vienen en el repositorio: aquí solo está `Bosque_eubayanus/` con los dos TSV de grupos, de modo que el script no puede rehacer `data/` desde esta carpeta tal como está.

El script lee además los insumos que viven en `data/`: `cepas_cerevisiae.tsv` y `cepas_eubayanus.tsv`, con una fila por cepa, y la anotación de genes. Para *S. cerevisiae* usa `data/genes_cerevisiae.tsv`, que es el archivo con que se generó `data/`, y para *S. eubayanus* usa `data/gene_result_eubayanus.txt`. Ninguno de los dos depende de rutas fuera del repositorio, así que el resultado no cambia de una máquina a otra.

```bash
Rscript preparar_app.R
```

Desde R también sirve `source("preparar_app.R")`. El script resuelve las rutas desde su propia carpeta, así que no depende del directorio de trabajo. Usa los paquetes `data.table`, `jsonlite`, `ape`, `Rtsne`, `uwot` y `R.utils`, e instala desde CRAN los que falten. Debe correr con un locale UTF-8: con el locale C, R compara mal los nombres de columna con tilde y "Población de origen" termina como capa de color, mientras que con UTF-8 salen las siete capas (Población, Continente, País, Sitio, Ecología, Sustrato y Ploidía). Si tu sesión no usa UTF-8, en Linux o macOS puedes correr `LANG=C.UTF-8 Rscript preparar_app.R`.

El script rehace solo la especie cuyos insumos cambiaron: compara el nombre, el tamaño y la fecha de modificación de cada insumo con `data/<especie>/huella.txt`, y `rehacer = TRUE` en `CONFIG` obliga a rehacer las dos especies. Cuando rehace una especie borra `data/<especie>/` y la vuelve a escribir, así que no guardes nada a mano en esas carpetas. Con la variable de entorno `PREPARAR_APP_LIBRARY_ONLY=1` el script carga sus funciones sin ejecutarse.

La primera columna de cada `cepas_*.tsv` es el nombre de la cepa y cada columna siguiente es una capa categórica que la app ofrece para colorear el anillo; la cabecera de la columna es el nombre que ve el usuario. En *S. cerevisiae*, las columnas Aislado, Población de origen, Latitud, Longitud y Precision van a la ficha de la cepa (campo `metadata` de `cepas.js`) y no se usan como capas. `YeastForest_code/preparar_app.R` es la versión en inglés del mismo script, pero no escribe el campo `metadata`, no separa esas columnas y traduce al inglés los motivos de los ORF omitidos; para regenerar esta app con la vista de metadata usa el `preparar_app.R` de esta carpeta.

La carpeta `data/` incluida se generó el 2026-10-05, la fecha que trae `data/especies.js`. La metadata de *S. cerevisiae* se agregó después a `data/cerevisiae/cepas.js` y a `data/especies.js`; por eso `data/cerevisiae/meta.json` todavía lista una sola capa y `data/cerevisiae/huella.txt` registra un `cepas_cerevisiae.tsv` de dos columnas. Una corrida nueva de `preparar_app.R` rehace las dos especies con los insumos actuales.

### Publicar

La carpeta se publica como un sitio estático. `.htaccess` es opcional y funciona en Apache cuando la carpeta tiene `AllowOverride All`: declara el tipo MIME de `.js`, comprime las respuestas con `mod_deflate`, deja los datos en caché por siete días y el HTML por una hora con `mod_expires`, y apaga el listado de carpetas. La caché larga no causa problemas porque la app pide los datos con `?v=<fecha de preparación>`.

### Créditos y cita

La sección Créditos y cita de la app dice que la herramienta se desarrolló en los trabajos de titulación de Mónica A. López Neilaf y Omar Sáez Arias, con Manuel Villalobos Cid como profesor guía (Departamento de Ingeniería Informática, Universidad de Santiago de Chile), y lista estas referencias:

- López Neilaf, M. A. (2026). *Desarrollo de herramienta computacional para visualización y análisis de bosque filogenético basado en datos genómicos de S. cerevisiae*. Tesis para optar al título de Ingeniera Civil en Informática. Profesor guía: Manuel Villalobos Cid. Departamento de Ingeniería Informática, Universidad de Santiago de Chile.
- Sáez Arias, O. (2026). Trabajo de titulación, Departamento de Ingeniería Informática, Universidad de Santiago de Chile. Profesor guía: Manuel Villalobos Cid.

Los datos de *S. cerevisiae* vienen del panel de 1.011 aislados de Peter et al. (2018) y sus ORF, de SGD. Los de *S. eubayanus* vienen del panel de cepas del CECTA-USACH sobre el genoma CBS12357, con los genes de NCBI ubicados por secuencia. Las anotaciones GO salen de org.Sc.sgd.db y las rutas, de KEGG. En la app figuran la Universidad de Santiago de Chile, el DIINF, el Laboratorio de Inteligencia Artificial y Bioinformática y el CECTA. Los bosques se describen en el manuscrito *Gene-tree discordance across yeast genomes: phylogenetic forests of Saccharomyces cerevisiae and Saccharomyces eubayanus* (Villalobos-Cid, López Neilaf, Sáez Arias, Salinas, Cubillos, Villarreal y Kessi-Pérez), cuyo código está en [YeastForest_code](../YeastForest_code/).

### Licencia

El código se distribuye con licencia MIT ([LICENSE](LICENSE)), igual que el del proyecto hermano [YeastForest_code](../YeastForest_code/). Los datos de cepas y genes conservan los términos de sus fuentes.

## English

YeastForest is the web application that displays the phylogenetic forests of *Saccharomyces cerevisiae* and *Saccharomyces eubayanus*; the interface calls it "Bosque Filogenético". Each forest holds one unrooted neighbour-joining tree per ORF and a reference tree built from all the SNPs of the genome. The *S. cerevisiae* forest has 5,903 ORF trees over 1,011 strains and the *S. eubayanus* forest has 3,589 trees over 471 strains, according to `data/especies.js`. The published version is at <https://mvillalobosc.diinf.usach.cl/YeastForest/> and the R code that computes the forests is in [YeastForest_code](../YeastForest_code/).

### Opening the app

Open `index.html` with a double click; if you received the app as a package, unpack the whole folder first. You can also run `python servir.py`, which starts a local server on the first free port from 8000, opens the browser and stops with Ctrl+C. The app needs no server because the files in `data/` are `.js` files that wrap JSON in a `BF.load(...)` call: the browser loads them as `<script>` even though it does not allow `fetch()` on `file://`. The only external connection is Google Fonts, and without a network the app falls back to the system fonts.

### Usage

1. Choose the species.
2. Search a gene by ORF, name or description, or pick a point in the forest.
3. Look at the tree and its card. On a phone, use Explorar, Árbol and Ficha y vecinos.
4. Search another gene in Comparar to see the bipartitions they share and their metrics.
5. Use Descargar to export the tree or its neighbours.

The colour, group, branch and label options sit in collapsible sections. Ampliar árbol gives the whole space to the tree and the same button brings the panels back. The / key jumps to the search box and Escape closes the help, the comparison or the filter.

The help notes next to the panels explain the projections, RF, concordance, resolution and support, and Guía técnica opens the formulas in ten sections: what it is, the forest, reading a tree, support, RF and concordance, groups, enrichment, reference, controls and credits. Forest support is not bootstrap, and positions in the forest are neither geographic coordinates nor evolutionary time.

The navigation bar has six views: Cepas y metadata, Bosque, Grupos, Referencia, Especies and Omitidos. From them you can download each tree as Newick, SVG or PNG, its neighbours as CSV and its neighbourhood as Newick, the genes and the enrichment of a group as CSV, the reference tree as SVG or Newick and the list of omitted ORFs as CSV.

Validation: loading, tree drawing, comparison and help were tested with data from both species through automated DOM checks, and the JavaScript syntax was verified. Appearance and touch gestures need a check in a real browser.

### *S. cerevisiae* metadata

The Cepas y metadata section lists the 1,011 strains with isolate, population of origin, continent, country, site, ecology, substrate, ploidy, coordinates and geographic precision. 943 strains have recorded coordinates. The original CSV files are included in full as `data/MetaData_Scer.csv` and `data/sitios_coords_Scer.csv`. The population the app already used (Peter et al., 2018) stays in the Población column, and the population from the CSV is kept as the separate field Población de origen.

In the strain group bar you choose the variable that colours the ring. Clicking a strain in the table opens its card in Referencia, and the exported CSV follows the active search. `data/cepas_cerevisiae.tsv` and `preparar_app.R` keep the metadata in later regenerations.

### Languages

The top buttons 🇨🇱 ES, 🇬🇧 EN and 🇧🇷 BR switch the interface, cards, messages, searches, tables and technical help between Spanish, English and Brazilian Portuguese. The browser remembers the choice in the `bf-interface-language` key of `localStorage`. The translations ship with the package (`i18n.js`, `i18n-dictionary.js` and `i18n-help.js`) and work without an external translation service. Scientific identifiers and the original metadata values are kept as they are.

### Folder contents

```
YeastForest/
├── .htaccess
├── LICENSE
├── README.md
├── index.html
├── i18n.js
├── i18n-dictionary.js
├── i18n-help.js
├── preparar_app.R
├── servir.py
├── Bosque_eubayanus/
└── data/
```

| File or folder | What it holds or does |
| --- | --- |
| `index.html` | Holds the whole app in one file: styles, HTML and the scripts that draw the forest, the trees, the comparison, the reference, the groups and the metadata. |
| `i18n.js` | Translates the interface in the browser and handles the language buttons. |
| `i18n-dictionary.js` | Stores the English and Brazilian Portuguese translation of the interface texts. |
| `i18n-help.js` | Stores the ten sections of the technical help in English and Brazilian Portuguese. |
| `servir.py` | Serves the folder at `http://localhost:<port>/index.html` and opens the browser; it uses only the Python 3 standard library and warns if `index.html` is not next to it. |
| `preparar_app.R` | Builds `data/especies.js` and the folder of each species from the forest results. |
| `.htaccess` | Configures Apache to publish the app (see below). |
| [`data/`](data/) | Stores the data the app loads and the inputs of `preparar_app.R`. |
| [`Bosque_eubayanus/`](Bosque_eubayanus/) | Stores the MST-kNN groups of *S. eubayanus* that `preparar_app.R` brings into the app. |

### Rebuilding the app data

`preparar_app.R` writes `data/especies.js` and, for each species, the folder `data/<species>/` with the trees, neighbours, groups, strains, gene annotation and omitted ORFs; [data/README.md](data/README.md) describes every file. To run it you need, next to the script, the folders `Bosque_cerevisiae/` and `Bosque_eubayanus/` with the forest results produced by [YeastForest_code](../YeastForest_code/). The required files are `<prefix>_resumen.tsv`, `<prefix>_arboles.nwk`, `<prefix>_RF.csv.gz`, `<prefix>_concordancia.csv.gz` and `<prefix>_distancias_geneticas.csv.gz`, and the optional ones are `<prefix>_clusters.tsv`, `<prefix>_clusters_resumen.tsv`, `<prefix>_enriquecimiento.tsv` and `<prefix>_genes_sin_ubicar.tsv`, where the prefix is `SCerevisiae` or `Eubayanus`. Those results are not in the repository: only `Bosque_eubayanus/` with the two group TSV files is here, so the script cannot rebuild `data/` from this folder as it stands.

The script also reads the inputs stored in `data/`: `cepas_cerevisiae.tsv` and `cepas_eubayanus.tsv`, with one row per strain, and the gene annotation. For *S. cerevisiae* it uses `data/genes_cerevisiae.tsv`, the file `data/` was generated with, and for *S. eubayanus* it uses `data/gene_result_eubayanus.txt`. Neither depends on paths outside the repository, so the result does not change from one machine to another.

```bash
Rscript preparar_app.R
```

From R, `source("preparar_app.R")` works too. The script resolves paths from its own folder, so it does not depend on the working directory. It uses the packages `data.table`, `jsonlite`, `ape`, `Rtsne`, `uwot` and `R.utils` and installs the missing ones from CRAN. It must run under a UTF-8 locale: under the C locale, R compares the column names that carry accents incorrectly and "Población de origen" ends up as a colour layer, while under UTF-8 the seven layers come out (Población, Continente, País, Sitio, Ecología, Sustrato and Ploidía). If your session does not use UTF-8, on Linux or macOS you can run `LANG=C.UTF-8 Rscript preparar_app.R`.

The script rebuilds only the species whose inputs changed: it compares the name, size and modification time of each input with `data/<species>/huella.txt`, and `rehacer = TRUE` in `CONFIG` forces a full rebuild. When it rebuilds a species it deletes `data/<species>/` and writes it again, so do not keep anything by hand in those folders. With the environment variable `PREPARAR_APP_LIBRARY_ONLY=1` the script loads its functions without running.

The first column of each `cepas_*.tsv` file is the strain name and every other column is a categorical layer that the app offers to colour the ring; the column header is the name the user sees. In *S. cerevisiae*, the columns Aislado, Población de origen, Latitud, Longitud and Precision go to the strain card (the `metadata` field of `cepas.js`) and are not used as layers. `YeastForest_code/preparar_app.R` is the English version of the same script, but it does not write the `metadata` field, does not set those columns apart and translates the reasons of the omitted ORFs into English; to rebuild this app with the metadata view, use the `preparar_app.R` in this folder.

The included `data/` folder was generated on 2026-10-05, the date stored in `data/especies.js`. The *S. cerevisiae* metadata was added afterwards to `data/cerevisiae/cepas.js` and `data/especies.js`; this is why `data/cerevisiae/meta.json` still lists a single layer and `data/cerevisiae/huella.txt` records a two-column `cepas_cerevisiae.tsv`. A new run of `preparar_app.R` rebuilds both species from the current inputs.

### Publishing

The folder is published as a static site. `.htaccess` is optional and works on Apache when the folder has `AllowOverride All`: it declares the MIME type of `.js`, compresses responses with `mod_deflate`, caches the data for seven days and the HTML for one hour with `mod_expires`, and turns off directory listings. The long cache is safe because the app requests the data with `?v=<preparation date>`.

### Credits and citation

The Créditos y cita section of the app states that the tool was developed in the undergraduate final projects of Mónica A. López Neilaf and Omar Sáez Arias, supervised by Manuel Villalobos Cid (Departamento de Ingeniería Informática, Universidad de Santiago de Chile), and lists these references:

- López Neilaf, M. A. (2026). *Desarrollo de herramienta computacional para visualización y análisis de bosque filogenético basado en datos genómicos de S. cerevisiae*. Tesis para optar al título de Ingeniera Civil en Informática. Profesor guía: Manuel Villalobos Cid. Departamento de Ingeniería Informática, Universidad de Santiago de Chile.
- Sáez Arias, O. (2026). Trabajo de titulación, Departamento de Ingeniería Informática, Universidad de Santiago de Chile. Profesor guía: Manuel Villalobos Cid.

The *S. cerevisiae* data come from the panel of 1,011 isolates of Peter et al. (2018) and its ORFs from SGD. The *S. eubayanus* data come from the CECTA-USACH strain panel on the CBS12357 genome, with the NCBI genes located by sequence. GO annotations come from org.Sc.sgd.db and pathways from KEGG. The app names Universidad de Santiago de Chile, DIINF, the Laboratorio de Inteligencia Artificial y Bioinformática and CECTA. The forests are described in the manuscript *Gene-tree discordance across yeast genomes: phylogenetic forests of Saccharomyces cerevisiae and Saccharomyces eubayanus* (Villalobos-Cid, López Neilaf, Sáez Arias, Salinas, Cubillos, Villarreal and Kessi-Pérez), whose code is in [YeastForest_code](../YeastForest_code/).

### Licence

The code is distributed under the MIT licence ([LICENSE](LICENSE)), like the code of the sibling project [YeastForest_code](../YeastForest_code/). The strain and gene data keep the terms of their sources.
