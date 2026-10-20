# examples/

[Español](#español) · [English](#english)

## Español

Esta carpeta trae cuatro árboles de prueba para [Phyli](../README.md). La aplicación no los ofrece en su lista de ejemplos (sus ejemplos integrados son el árbol de la vida y la red de *Saccharomyces*, que viven dentro de `index.html`), así que se cargan a mano: con el botón para abrir un archivo local, arrastrándolos a la página o pegando su contenido. El selector de archivos acepta, entre otras, las extensiones `.nwk` y `.tree`.

| Archivo | Contenido |
|---|---|
| `simple.nwk` | Árbol mínimo en Newick clásico con 6 puntas (A a F) y longitudes de rama, útil para probar el trazado y el enraizamiento. |
| `tree-of-life.nwk` | Árbol de 3 puntas (Archaea, Bacteria y Eukarya) con un clado interno con nombre, `Cellular_life`, y longitudes de rama. Es distinto del árbol de la vida integrado en la aplicación, que tiene 191 taxones. |
| `vertebrates.nwk` | Árbol de 7 vertebrados (Human, Chimpanzee, Mouse, Rat, Chicken, Frog y Zebrafish) con cuatro clados internos con nombre (Primates, Rodents, Aquatic y Outgroup), soporte entre corchetes (por ejemplo `[99]`) y longitudes de rama. |
| `1011_REF.tree` | Árbol de 1011 puntas en una sola línea de Newick (30 KB), con etiquetas cortas como `ASD`, `BKI` o `SACE_YAD` y longitudes de rama grandes; 96 de ellas son negativas. No tiene nombres internos ni soportes. El repositorio no documenta de dónde proviene. |

Los cuatro archivos son árboles; ninguno trae nodos híbridos de Newick extendido.

## English

This folder holds four test trees for [Phyli](../README.md). The application does not list them among its examples (its embedded examples are the tree of life and the *Saccharomyces* network, which live inside `index.html`), so they are loaded by hand: through the button that opens a local file, by dragging them onto the page or by pasting their contents. The file selector accepts, among others, the `.nwk` and `.tree` extensions.

| File | Contents |
|---|---|
| `simple.nwk` | Minimal classic Newick tree with 6 tips (A to F) and branch lengths, handy for testing layout and rooting. |
| `tree-of-life.nwk` | Three-tip tree (Archaea, Bacteria and Eukarya) with one named internal clade, `Cellular_life`, and branch lengths. It differs from the tree of life embedded in the application, which has 191 taxa. |
| `vertebrates.nwk` | Tree of 7 vertebrates (Human, Chimpanzee, Mouse, Rat, Chicken, Frog and Zebrafish) with four named internal clades (Primates, Rodents, Aquatic and Outgroup), bracketed support (for example `[99]`) and branch lengths. |
| `1011_REF.tree` | Tree with 1011 tips on a single Newick line (30 KB), with short labels such as `ASD`, `BKI` or `SACE_YAD` and large branch lengths, 96 of which are negative. It has no internal names and no support values. The repository does not document where it comes from. |

All four files are trees; none of them contains extended-Newick hybrid nodes.
