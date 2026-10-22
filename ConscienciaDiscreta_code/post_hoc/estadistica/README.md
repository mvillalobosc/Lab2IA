# post_hoc/estadistica

[Español](#español) · [English](#english)

## Español

Estadística del artículo, escrita por `analisis.R` (resumen y tablas `A_` a `K_`) y por `analisis_complementario.R` (resumen complementario y tablas `L_`). Las letras de las tablas siguen las secciones de `resumen.txt`; las tablas D, E y J están en su sección C.

| Archivo | Contenido |
| --- | --- |
| `resumen.txt` | Salida de `analisis.R` por secciones: A parametrización, B convergencia, C consistencia entre semillas y NSGA-III frente a búsqueda aleatoria, F diseño, G sensibilidad, H recuperación de modelos y ajuste, I Haarlem et al. y K cobertura cruzada entre los lectores de eventos y periódico con ambos optimizadores. |
| `resumen_complementario.txt` | Salida de `analisis_complementario.R`: 1 fronteras de Pareto en dos dimensiones contra el costo, 2 error mínimo con presupuesto de lecturas y latencias, 3 parámetros elegidos por el optimizador, 4 intervalos entre lecturas y banda alfa, 5 sensibilidad, 6 NSGA-III frente a búsqueda aleatoria en dos dimensiones, 7 agentes de eventos muy ralos, 8 soluciones distintas de los frentes validados y de la última población de NSGA-III y 9 indicadores de calidad y valores extremos de NSGA-III y de la búsqueda aleatoria. |
| `A_parametrizacion_rangos.csv` | Rango medio de Friedman de las 27 configuraciones (bloques: arquitectura y semilla), Wilcoxon contra la mejor con corrección de Holm y A12 (Fig. A1). |
| `B_convergencia_corte.csv` | Fracción del hipervolumen final que alcanza cada corrida larga en el corte de 1000 generaciones. |
| `C_arquitecturas_hv.csv`, `C_arquitecturas_fraccion.csv` | Wilcoxon pareado con corrección de Holm y A12 entre pares de arquitecturas, para el hipervolumen de validación y para la fracción del frente combinado de las 11 semillas. |
| `D_nsga_vs_random.csv` | NSGA-III frente a búsqueda aleatoria por arquitectura: hipervolumen medio y desviación, Wilcoxon con corrección de Holm, A12, tamaño de los frentes, cobertura en ambos sentidos y lo mismo con el frente aleatorio recortado (Tabla 5). |
| `E_random_recortado.csv` | Por semilla, tamaño e hipervolumen de los frentes de NSGA-III, de la búsqueda aleatoria y de esta recortada por nichado al tamaño del frente de NSGA-III. |
| `F_presupuesto.csv` | Error, umbral y latencia mínimos de cada arquitectura y régimen con un presupuesto de lecturas por segundo (Tabla 9). |
| `J_frente_conjunto.csv` | Fracción del frente conjunto de NSGA-III y la búsqueda aleatoria (misma semilla) que aporta NSGA-III. |
| `K_cobertura_cruzada.csv` | Cobertura entre los frentes de eventos y periódico por semilla, con ambos optimizadores. |
| `L_indicadores_extremos.csv`, `L_indicadores_extremos_pruebas.csv` | Por corrida del estudio de semillas, IGD+, épsilon aditivo y espaciado del frente validado frente al frente de referencia de su arquitectura (objetivos normalizados como en el hipervolumen) y mejor valor de cada objetivo entre los agentes funcionales; y Wilcoxon pareado de NSGA-III contra la búsqueda aleatoria con corrección de Holm dentro de cada indicador y A12 de NSGA-III (Tabla 6). |

## English

Statistics of the paper, written by `analisis.R` (summary and tables `A_` to `K_`) and by `analisis_complementario.R` (complementary summary and tables `L_`). The letters of the tables follow the sections of `resumen.txt`; tables D, E and J are in its section C.

| File | Content |
| --- | --- |
| `resumen.txt` | Output of `analisis.R` by sections: A parametrisation, B convergence, C consistency over seeds and NSGA-III against random search, F design, G sensitivity, H model recovery and fits, I Haarlem et al. and K cross coverage between the event and periodic readers with both optimisers. |
| `resumen_complementario.txt` | Output of `analisis_complementario.R`: 1 two-dimensional Pareto frontiers against the cost, 2 lowest error within a reading budget and latencies, 3 parameters chosen by the optimiser, 4 intervals between reads and alpha band, 5 sensitivity, 6 NSGA-III against random search in two dimensions, 7 very sparse event agents, 8 distinct solutions of the validated fronts and of the last population of NSGA-III and 9 quality indicators and extreme values of NSGA-III and random search. |
| `A_parametrizacion_rangos.csv` | Mean Friedman rank of the 27 configurations (blocks: architecture and seed), Wilcoxon test against the best one with Holm correction and A12 (Fig. A1). |
| `B_convergencia_corte.csv` | Fraction of the final hypervolume that each long run reaches at the cutoff of 1000 generations. |
| `C_arquitecturas_hv.csv`, `C_arquitecturas_fraccion.csv` | Paired Wilcoxon tests with Holm correction and A12 between pairs of architectures, for the validation hypervolume and for the share of the combined front of the 11 seeds. |
| `D_nsga_vs_random.csv` | NSGA-III against random search per architecture: mean hypervolume and standard deviation, Wilcoxon test with Holm correction, A12, front sizes, coverage in both directions and the same with the reduced random front (Table 5). |
| `E_random_recortado.csv` | Per seed, size and hypervolume of the fronts of NSGA-III, of random search and of the latter reduced by niching to the size of the NSGA-III front. |
| `F_presupuesto.csv` | Lowest error, threshold and latency of each architecture and regime within a budget of reads per second (Table 9). |
| `J_frente_conjunto.csv` | Share of the joint front of NSGA-III and random search (same seed) contributed by NSGA-III. |
| `K_cobertura_cruzada.csv` | Coverage between the event and periodic fronts per seed, with both optimisers. |
| `L_indicadores_extremos.csv`, `L_indicadores_extremos_pruebas.csv` | Per run of the seed study, IGD+, additive epsilon and spacing of the validated front against the reference front of its architecture (objectives normalised as in the hypervolume) and best value of each objective among functional agents; and paired Wilcoxon tests of NSGA-III against random search with Holm correction within each indicator and the A12 of NSGA-III (Table 6). |
