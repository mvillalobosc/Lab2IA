# data

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los 13 conjuntos de secuencias que usa el experimento, en formato PHYLIP (15,4 MB en total). La primera línea de cada archivo da el número de taxones y de sitios. Los drivers leen un archivo con `read_sequences()`, que llama a `ape::read.dna()` o a `ape::read.aa()` según `SEQ_TYPE`, y la lista de conjuntos del experimento está en `DATASETS` de [config.R](../config.R). Vuelve al [README del proyecto](../README.md) para ver cómo se usan.

| Archivo | Taxones | Sitios | Secuencias | Tamaño |
|---|---:|---:|---|---:|
| `conrado_126.phylip` | 126 | 609 | aminoácidos | 102 KB |
| `hasegawa.phylip` | 7 | 232 | ADN | 2 KB |
| `HIV1_192.phylip` | 192 | 817 | ADN | 209 KB |
| `HIV2_72.phylip` | 72 | 828 | ADN | 79 KB |
| `membracidae1_81.phylip` | 81 | 3.321 | ADN | 356 KB |
| `mtDNA_186.phylip` | 186 | 16.608 | ADN | 4,1 MB |
| `primates_14.phylip` | 14 | 232 | ADN | 4 KB |
| `rbcL_55.phylip` | 55 | 1.314 | ADN | 96 KB |
| `RDPII_218.phylip` | 218 | 4.182 | ADN | 1,2 MB |
| `RIM15.phylip` | 1.011 | 5.748 | ADN | 5,8 MB |
| `S1482_346.phylip` | 346 | 897 | ADN | 410 KB |
| `YDR385W_menos.phylip` | 1.011 | 2.529 | ADN | 2,6 MB |
| `ZILLA_500.phylip` | 500 | 759 | ADN | 506 KB |

Algunas observaciones que importan al correr:

- `conrado_126.phylip` trae secuencias de aminoácidos, pero `SEQ_TYPE` vale `"DNA"` para todos los conjuntos en `config.R` (y también dentro de los scripts de `tuning/`), así que ese archivo se lee con `ape::read.dna()`.
- `RIM15.phylip` y `YDR385W_menos.phylip` son los más grandes en número de taxones: 1.011 secuencias, una por línea, con nombres que empiezan por `SACE_`.
- `primates_14.phylip` es el conjunto que corre `main.R` por defecto (`DATASET` en `config.R`), y `primates_14`, `rbcL_55`, `conrado_126` y `mtDNA_186` son los conjuntos de entrenamiento del afinado (`INSTANCES`).
- Ningún archivo del repositorio indica la fuente ni la cita de estos conjuntos.

## English

This folder holds the 13 sequence sets used by the experiment, in PHYLIP format (15.4 MB in total). The first line of each file gives the number of taxa and sites. The drivers read a file with `read_sequences()`, which calls `ape::read.dna()` or `ape::read.aa()` depending on `SEQ_TYPE`, and the list of data sets in the experiment is `DATASETS` in [config.R](../config.R). See the [project README](../README.md) for how they are used.

| File | Taxa | Sites | Sequences | Size |
|---|---:|---:|---|---:|
| `conrado_126.phylip` | 126 | 609 | amino acids | 102 KB |
| `hasegawa.phylip` | 7 | 232 | DNA | 2 KB |
| `HIV1_192.phylip` | 192 | 817 | DNA | 209 KB |
| `HIV2_72.phylip` | 72 | 828 | DNA | 79 KB |
| `membracidae1_81.phylip` | 81 | 3,321 | DNA | 356 KB |
| `mtDNA_186.phylip` | 186 | 16,608 | DNA | 4.1 MB |
| `primates_14.phylip` | 14 | 232 | DNA | 4 KB |
| `rbcL_55.phylip` | 55 | 1,314 | DNA | 96 KB |
| `RDPII_218.phylip` | 218 | 4,182 | DNA | 1.2 MB |
| `RIM15.phylip` | 1,011 | 5,748 | DNA | 5.8 MB |
| `S1482_346.phylip` | 346 | 897 | DNA | 410 KB |
| `YDR385W_menos.phylip` | 1,011 | 2,529 | DNA | 2.6 MB |
| `ZILLA_500.phylip` | 500 | 759 | DNA | 506 KB |

A few notes that matter when running:

- `conrado_126.phylip` holds amino acid sequences, but `SEQ_TYPE` is `"DNA"` for every data set in `config.R` (and also inside the `tuning/` scripts), so that file is read with `ape::read.dna()`.
- `RIM15.phylip` and `YDR385W_menos.phylip` are the largest in number of taxa: 1,011 sequences, one per line, with names that start with `SACE_`.
- `primates_14.phylip` is the data set that `main.R` runs by default (`DATASET` in `config.R`), and `primates_14`, `rbcL_55`, `conrado_126` and `mtDNA_186` are the training sets of the tuning (`INSTANCES`).
- No file in the repository states the source or the citation of these data sets.
