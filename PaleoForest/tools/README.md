# tools/

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene una sola herramienta, `prep.py`, el script de Python 3 que preparó los datos de [PaleoForest](../README.md) a partir del proyecto R de la memoria. Usa solo la biblioteca estándar (`re`, `json`, `os` y `shutil`) y no tiene opciones de línea de comandos.

### Qué hace `prep.py`

El script clasifica cada archivo de origen por su contenido (`xread` para matrices TNT, `tread` o `(` para árboles y la cabecera `TIPS;INI_EON` para edades), porque los nombres del proyecto R original no eran confiables. Su catálogo `CASES` define cinco conjuntos: Arackar licanantay, Burkesuchus mallingrandensis, Chilesaurus diegosuarezi, Orretherium tzen y Punatitan coughlini con Bravasaurus arrierosorum. Para cada conjunto copia la matriz, los árboles y, si existen, las edades; convierte los árboles a Newick con nombres y escribe un `info.json`. Para Arackar arma además `dataset.js` con la matriz, los árboles, las edades, los 24 caracteres aditivos (índices desde 0) y el largo de referencia 1322, que toma del nombre del archivo de árboles.

### Rutas que usa

Todas las rutas son relativas al directorio desde el que se ejecuta el script, no a esta carpeta:

| Ruta | Uso |
|---|---|
| `codigo/tesis-disenio_final/data/` | Datos de origen que lee (matrices, árboles y edades de la memoria). |
| `project/data/arackar/` | Salida del ejemplo integrado: `dataset.js`, `matrix.tnt`, `trees.tre`, `trees.nwk`, `ages.csv` y `meta.json`. |
| `project/examples/<Especie>/` | Salida de cada conjunto: `matrix.tnt`, `trees.tre`, `trees.nwk`, `ages.csv` si existe e `info.json`. |
| `project/examples/README.md` | Resumen de los conjuntos que el script genera. |

Antes de escribir, el script borra `project/data/` y `project/examples/` completas con `shutil.rmtree`. Ninguna de estas carpetas existe en el repositorio, así que `prep.py` no se puede ejecutar aquí sin los datos de origen de la memoria. El contenido actual de [`../data/`](../data/README.md) y [`../examples/`](../examples/README.md) corresponde a esa salida, aunque de los cinco conjuntos del catálogo solo vienen tres (faltan Orretherium y Punatitan/Bravasaurus). Para regenerarlos hay que correr el script donde estén los datos de origen y copiar después su salida a esas dos carpetas. Al copiar, conviene dejar fuera el `README.md` que el script escribe en `project/examples/`, porque es otro resumen, solo en castellano, y reemplazaría al README de `../examples/`.

## English

This folder holds a single tool, `prep.py`, the Python 3 script that prepared the [PaleoForest](../README.md) data from the R project of the thesis. It uses only the standard library (`re`, `json`, `os` and `shutil`) and has no command-line options.

### What `prep.py` does

The script classifies each source file by its content (`xread` for TNT matrices, `tread` or `(` for trees and the `TIPS;INI_EON` header for ages), because the names in the original R project were not reliable. Its `CASES` catalogue defines five datasets: Arackar licanantay, Burkesuchus mallingrandensis, Chilesaurus diegosuarezi, Orretherium tzen and Punatitan coughlini with Bravasaurus arrierosorum. For each dataset it copies the matrix, the trees and, when present, the ages; it converts the trees to Newick with names and writes an `info.json`. For Arackar it also builds `dataset.js` with the matrix, the trees, the ages, the 24 additive characters (zero-based indices) and the reference length 1322, which it takes from the name of the tree file.

### Paths it uses

Every path is relative to the directory the script runs from, not to this folder:

| Path | Use |
|---|---|
| `codigo/tesis-disenio_final/data/` | Source data it reads (matrices, trees and ages from the thesis). |
| `project/data/arackar/` | Output of the embedded example: `dataset.js`, `matrix.tnt`, `trees.tre`, `trees.nwk`, `ages.csv` and `meta.json`. |
| `project/examples/<Species>/` | Output of each dataset: `matrix.tnt`, `trees.tre`, `trees.nwk`, `ages.csv` when present and `info.json`. |
| `project/examples/README.md` | Summary of the datasets that the script generates. |

Before writing, the script deletes `project/data/` and `project/examples/` entirely with `shutil.rmtree`. None of these folders exists in the repository, so `prep.py` cannot run here without the thesis source data. The current contents of [`../data/`](../data/README.md) and [`../examples/`](../examples/README.md) match that output, although only three of the five catalogue datasets are included (Orretherium and Punatitan/Bravasaurus are missing). To regenerate them, run the script where the source data are and then copy its output into those two folders. When copying, leave out the `README.md` that the script writes in `project/examples/`, because it is a different summary, in Spanish only, and it would replace the README of `../examples/`.
