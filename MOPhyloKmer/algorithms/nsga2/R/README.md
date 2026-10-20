# nsga2/R

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los módulos de NSGA-II. `run_nsga.R` carga primero `packages.R` y después cada archivo `*.R` de la carpeta, así que cada módulo solo define funciones. Vuelve al [README de nsga2/](../README.md) para ver cómo se combinan en una corrida.

| Archivo | Función | Qué hace |
|---|---|---|
| `packages.R` | | Carga los 13 paquetes del proyecto sin instalar ni actualizar nada y se detiene con la lista de los que faltan. Antes antepone a `.libPaths()` la biblioteca `~/R/x86_64-pc-linux-gnu-library/4.3`. Es idéntico al de `mosa/R/`. |
| `lectura_secuencias.R` | `read_sequences(ruta_archivo, tipo)` | Lee un archivo PHYLIP con `ape::read.dna()` o `ape::read.aa()` según el tipo (`"DNA"` o `"AA"`) y lo devuelve como objeto `phyDat`. |
| `crear_arbol_base.R` | `build_base_tree(sequences, k)` | Calcula la matriz de distancias de k-meros con `kmer::kdistance()`, construye el árbol por NJ, pone en cero las ramas negativas, resuelve las politomías y lo enraíza en el punto medio. Guarda la matriz en `$dist_kmer`. |
| `crear_poblacion_arboles.R` | `build_population(base_tree, n)` | Arma la población inicial: el árbol base más `n - 1` árboles obtenidos al sumar a su matriz un ruido uniforme entre -0,01 y 0,01. Todos guardan la matriz original en `$dist_original`. |
| `objetivos.R` | `compute_scores()`, `compute_normalized_scores()` | Calculan ME (suma de los largos de rama) y LS (suma de las diferencias absolutas entre la matriz original y las distancias cofenéticas) de cada árbol, y sus versiones normalizadas. |
| `nom_dominated_sort_cw.R` | `non_dominated_sort_cw(arboles)` | Hace el ordenamiento no dominado con `ecr::doNondominatedSorting()` y calcula la distancia de crowding de cada frente. Devuelve un data frame con `LS`, `ME`, `LSnorm`, `MEnorm`, `ranking` y `crowding2`. |
| `torneo_binario.R` | `tournament_selection(population, data, orden)` | Elige dos individuos al azar y devuelve la matriz del ganador: gana el de menor rango y, si empatan, el de mayor distancia de crowding. |
| `crossover.R` | `crossover(padre1, padre2, porcentaje)` | Combina dos matrices como `porcentaje` x padre1 + (1 - `porcentaje`) x padre2 y recorta el resultado al intervalo [0, 1]. |
| `mutacion.R` | `mutation(porcentaje, individuo)` | Suma un ruido uniforme entre `-porcentaje` y `porcentaje` a las celdas que elige con probabilidad `porcentaje` y recorta el resultado al intervalo [0, 1]. |
| `generate_randomTree.R` | `generate_random_tree(individuo)` | Devuelve una matriz simétrica con valores U(0, 1) y diagonal cero, del mismo tamaño que la del individuo, para inyectar diversidad. |
| `hypervolumen.R` | `compute_hypervolume(frente)` | Calcula con `ecr::computeHV()` el hipervolumen de un frente (matriz con LS y ME normalizados) respecto del punto (2, 2). |

## English

This folder holds the NSGA-II modules. `run_nsga.R` loads `packages.R` first and then every `*.R` file in the folder, so each module only defines functions. See the [nsga2/ README](../README.md) for how they come together in one run.

| File | Function | What it does |
|---|---|---|
| `packages.R` | | Loads the 13 project packages without installing or updating anything and stops with the list of missing ones. Before that it puts the library `~/R/x86_64-pc-linux-gnu-library/4.3` first in `.libPaths()`. It is identical to the one in `mosa/R/`. |
| `lectura_secuencias.R` | `read_sequences(ruta_archivo, tipo)` | Reads a PHYLIP file with `ape::read.dna()` or `ape::read.aa()` depending on the type (`"DNA"` or `"AA"`) and returns it as a `phyDat` object. |
| `crear_arbol_base.R` | `build_base_tree(sequences, k)` | Computes the k-mer distance matrix with `kmer::kdistance()`, builds the NJ tree, sets negative branches to zero, resolves polytomies, and roots it at the midpoint. It stores the matrix in `$dist_kmer`. |
| `crear_poblacion_arboles.R` | `build_population(base_tree, n)` | Builds the initial population: the base tree plus `n - 1` trees obtained by adding a uniform noise between -0.01 and 0.01 to its matrix. All of them keep the original matrix in `$dist_original`. |
| `objetivos.R` | `compute_scores()`, `compute_normalized_scores()` | Compute ME (sum of branch lengths) and LS (sum of the absolute differences between the original matrix and the cophenetic distances) of each tree, and their normalised versions. |
| `nom_dominated_sort_cw.R` | `non_dominated_sort_cw(arboles)` | Runs the non-dominated sort with `ecr::doNondominatedSorting()` and computes the crowding distance of each front. It returns a data frame with `LS`, `ME`, `LSnorm`, `MEnorm`, `ranking`, and `crowding2`. |
| `torneo_binario.R` | `tournament_selection(population, data, orden)` | Picks two individuals at random and returns the matrix of the winner: the lower rank wins and, on a tie, the larger crowding distance. |
| `crossover.R` | `crossover(padre1, padre2, porcentaje)` | Combines two matrices as `porcentaje` x parent1 + (1 - `porcentaje`) x parent2 and clips the result to [0, 1]. |
| `mutacion.R` | `mutation(porcentaje, individuo)` | Adds a uniform noise between `-porcentaje` and `porcentaje` to the cells it picks with probability `porcentaje` and clips the result to [0, 1]. |
| `generate_randomTree.R` | `generate_random_tree(individuo)` | Returns a symmetric matrix with U(0, 1) values and a zero diagonal, the same size as the individual's, to inject diversity. |
| `hypervolumen.R` | `compute_hypervolume(frente)` | Computes with `ecr::computeHV()` the hypervolume of a front (matrix of normalised LS and ME) with respect to the point (2, 2). |
