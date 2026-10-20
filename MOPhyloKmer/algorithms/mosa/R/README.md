# mosa/R

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los módulos de MOSA, que también usa la búsqueda aleatoria de [rs/](../../rs/). `run_mosa.R` y `run_rs.R` cargan primero `packages.R` y después cada archivo `*.R` de la carpeta, así que cada módulo solo define funciones. A diferencia de las de `nsga2/R/`, las funciones de objetivos e hipervolumen trabajan sobre un solo árbol y guardan sus resultados en `$scores`. Vuelve al [README de mosa/](../README.md) para ver cómo se usan en una corrida.

| Archivo | Función | Qué hace |
|---|---|---|
| `packages.R` | | Carga los 13 paquetes del proyecto sin instalar ni actualizar nada y se detiene con la lista de los que faltan. Es idéntico al de `nsga2/R/`. |
| `lectura_secuencia.R` | `read_sequences(ruta_archivo, tipo)` | Lee un archivo PHYLIP con `ape::read.dna()` o `ape::read.aa()` según el tipo y lo devuelve como `phyDat`. Hace lo mismo que `nsga2/R/lectura_secuencias.R`, con otro nombre de archivo. |
| `crear_arbol_base.R` | `build_base_tree(sequences, k)` | Construye el árbol base con distancias de k-meros y NJ, igual que la versión de `nsga2/R/`, y además guarda la matriz observada en `$dist_original`, contra la que se mide LS. |
| `calcular_objetivos.R` | `compute_objectives(tree)` | Calcula ME (suma de los largos de rama) y LS (suma de las diferencias absolutas entre `$dist_original` y las distancias cofenéticas) de un árbol. |
| `calcular_objetivos_normalizados.R` | `compute_normalized_objectives(tree, max_ls, max_me)` | Divide LS y ME por los máximos de normalización (10 veces los valores del árbol base). |
| `calcular_hypervolumen.R` | `compute_hypervolume(tree)` | Calcula con `ecr::computeHV()` el hipervolumen de una sola solución respecto del punto (2, 2) y lo guarda en `$scores$hyp`. |
| `perturbar_arbol.R` | `perturb_tree(tree)` | Multiplica cada celda de la matriz de distancias por un factor U(0,9; 1,1), reemplaza los valores no positivos por 0,00001, rehace el árbol con NJ y conserva `$dist_original`. Es el vecino de MOSA y el generador de candidatos de la búsqueda aleatoria. |

## English

This folder holds the MOSA modules, which the Random Search in [rs/](../../rs/) also uses. `run_mosa.R` and `run_rs.R` load `packages.R` first and then every `*.R` file in the folder, so each module only defines functions. Unlike those in `nsga2/R/`, the objective and hypervolume functions work on a single tree and store their results in `$scores`. See the [mosa/ README](../README.md) for how they are used in one run.

| File | Function | What it does |
|---|---|---|
| `packages.R` | | Loads the 13 project packages without installing or updating anything and stops with the list of missing ones. It is identical to the one in `nsga2/R/`. |
| `lectura_secuencia.R` | `read_sequences(ruta_archivo, tipo)` | Reads a PHYLIP file with `ape::read.dna()` or `ape::read.aa()` depending on the type and returns it as `phyDat`. It does the same as `nsga2/R/lectura_secuencias.R`, under another file name. |
| `crear_arbol_base.R` | `build_base_tree(sequences, k)` | Builds the base tree from k-mer distances and NJ, like the `nsga2/R/` version, and also stores the observed matrix in `$dist_original`, against which LS is measured. |
| `calcular_objetivos.R` | `compute_objectives(tree)` | Computes ME (sum of branch lengths) and LS (sum of the absolute differences between `$dist_original` and the cophenetic distances) of a tree. |
| `calcular_objetivos_normalizados.R` | `compute_normalized_objectives(tree, max_ls, max_me)` | Divides LS and ME by the normalisation maxima (10 times the values of the base tree). |
| `calcular_hypervolumen.R` | `compute_hypervolume(tree)` | Computes with `ecr::computeHV()` the hypervolume of a single solution with respect to the point (2, 2) and stores it in `$scores$hyp`. |
| `perturbar_arbol.R` | `perturb_tree(tree)` | Multiplies each cell of the distance matrix by a U(0.9, 1.1) factor, replaces non-positive values with 0.00001, rebuilds the tree with NJ, and keeps `$dist_original`. It is the MOSA neighbour move and the candidate generator of the Random Search. |
