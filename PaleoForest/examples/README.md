# examples/

[Español](#español) · [English](#english)

## Español

Esta carpeta trae tres conjuntos de datos morfológicos para cargar a mano en el paso Datos del módulo 2 de [PaleoForest](../README.md), con su `matrix.tnt`, su `trees.tre` y, si existe, su `ages.csv`. La aplicación no los ofrece en un selector y no lee nada de aquí por su cuenta.

| Carpeta | Árboles | Taxones | Caracteres | Edades | Descripción (según `info.json`) |
|---|---:|---:|---:|---:|---|
| `Arackar_licanantay/` | 97 | 88 | 405 | 88 | Titanosaurio del Cretácico Superior de Atacama, Chile (Rubilar-Rogers et al. 2021). |
| `Burkesuchus_mallingrandensis/` | 100 | 111 | 448 | 111 | Crocodiliforme del Jurásico Superior de Aysén, Chile. |
| `Chilesaurus_diegosuarezi/` | 100 | 62 | 412 | Sin archivo | Terópodo enigmático del Jurásico Superior de Aysén, Chile. |

`Arackar_licanantay/` es una copia exacta del ejemplo integrado en [`../data/arackar/`](../data/README.md): sus `matrix.tnt`, `trees.tre`, `trees.nwk` y `ages.csv` tienen el mismo contenido, así que no es un caso adicional. En ese conjunto, la línea 97 del archivo de árboles es un consenso estricto que la aplicación excluye, de modo que el análisis usa 96 árboles.

### Archivos de cada carpeta

| Archivo | Contenido |
|---|---|
| `matrix.tnt` | Matriz de caracteres en formato TNT (`xread`); define los nombres de los taxones. |
| `trees.tre` | Árboles más parsimoniosos en formato TNT (`tread`), con los taxones como índices numéricos; en Burkesuchus y Chilesaurus el archivo termina con la línea `proc/;`. |
| `trees.nwk` | Los mismos árboles en Newick con los nombres de los taxones, uno por línea, por si se quieren usar en otra herramienta. |
| `ages.csv` | Rangos fósiles con 26 columnas separadas por `;` (UTF-8 con BOM), las mismas de [`../data/arackar/ages.csv`](../data/README.md). Solo lo traen Arackar y Burkesuchus; para Chilesaurus, las edades se completan en el paso Edades con PaleoDB, Macrostrat o a mano. |
| `info.json` | Especie, número de árboles, taxones y edades emparejadas, una nota y la lista de archivos. Lo escribió `tools/prep.py` y la aplicación no lo lee. |

El aviso del paso Datos (clave `ds_more_p` de `js/i18n.js`) menciona además los conjuntos de Orretherium y de Punatitan/Bravasaurus. Esos dos figuran en el catálogo de `tools/prep.py`, pero no vienen en esta carpeta.

## English

This folder holds three morphological datasets to load by hand in the Data step of module 2 of [PaleoForest](../README.md), using their `matrix.tnt`, their `trees.tre` and, when present, their `ages.csv`. The application does not list them in a selector and reads nothing from here on its own.

| Folder | Trees | Taxa | Characters | Ages | Description (from `info.json`) |
|---|---:|---:|---:|---:|---|
| `Arackar_licanantay/` | 97 | 88 | 405 | 88 | Late Cretaceous titanosaur from Atacama, Chile (Rubilar-Rogers et al. 2021). |
| `Burkesuchus_mallingrandensis/` | 100 | 111 | 448 | 111 | Late Jurassic crocodyliform from Aysén, Chile. |
| `Chilesaurus_diegosuarezi/` | 100 | 62 | 412 | No file | Enigmatic Late Jurassic theropod from Aysén, Chile. |

`Arackar_licanantay/` is an exact copy of the example embedded in [`../data/arackar/`](../data/README.md): its `matrix.tnt`, `trees.tre`, `trees.nwk` and `ages.csv` have the same content, so it is not an additional case. In that dataset, line 97 of the tree file is a strict consensus that the application excludes, so the analysis uses 96 trees.

### Files in each folder

| File | Contents |
|---|---|
| `matrix.tnt` | Character matrix in TNT format (`xread`); it defines the taxon names. |
| `trees.tre` | Most parsimonious trees in TNT format (`tread`), with taxa as numeric indices; in Burkesuchus and Chilesaurus the file ends with a `proc/;` line. |
| `trees.nwk` | The same trees in Newick with taxon names, one per line, in case they are needed in another tool. |
| `ages.csv` | Fossil ranges with 26 columns separated by `;` (UTF-8 with a BOM), the same as [`../data/arackar/ages.csv`](../data/README.md). Only Arackar and Burkesuchus have one; for Chilesaurus, ages are completed in the Ages step with PaleoDB, Macrostrat or by hand. |
| `info.json` | Species, number of trees, taxa and matched ages, a note and the list of files. `tools/prep.py` wrote it, and the application does not read it. |

The notice in the Data step (key `ds_more_p` in `js/i18n.js`) also mentions the Orretherium and Punatitan/Bravasaurus datasets. Both appear in the `tools/prep.py` catalogue, but they are not included in this folder.
