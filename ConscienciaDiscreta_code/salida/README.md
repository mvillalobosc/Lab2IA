# salida

[Español](#español) · [English](#english)

## Español

Resultados de la corrida del artículo (`Rscript correr_todo.R` en un servidor Linux con 63 núcleos, 21 de octubre de 2026, 6 horas y 21 minutos). `consciencia_discreta.R` escribe aquí todo lo que produce; una corrida nueva sobrescribe estos archivos. En los nombres de columna, `continua`, `continua_modulada`, `periodica` y `eventos` son las cuatro arquitecturas, y `limpio` y `rafagas` son los regímenes de entrada sin y con distractores.

**Validación del optimizador (régimen limpio)**

| Archivo | Contenido |
| --- | --- |
| `validation_parametrisation_runs.csv` | Las 324 corridas de la parametrización (27 configuraciones, 4 arquitecturas y 3 semillas): configuración, hipervolumen de validación, tamaño del frente y minutos. |
| `validation_parametrisation_summary.csv` | Hipervolumen mediano y medio por configuración, ordenado de mayor a menor; la primera fila es la configuración elegida. |
| `validation_convergence_curve.csv` | Hipervolumen del primer frente (banco de entrenamiento) en cada una de las 1500 generaciones de las 44 corridas largas, y su máximo acumulado. |
| `validation_convergence_cutoff.csv` | Por corrida larga, el hipervolumen final y las generaciones en que llega al 95 %, 99 % y 99,9 % de él. |
| `validation_convergence_chosen_cutoff.csv` | Regla del corte: mediana de la generación del 99 %, margen, mínimo (1000) y generaciones de las corridas principales. |
| `validation_seed_runs.csv` | Hipervolumen de validación, tamaño del frente y minutos de las 11 semillas de NSGA-III y de la búsqueda aleatoria por arquitectura. |
| `validation_seed_summary.csv` | Media, desviación, mínimo, mediana y máximo de ese hipervolumen por método y arquitectura. |
| `validation_seed_fronts.csv.gz` | Frentes validados de esas 88 corridas (comprimido; unos 60 MB sin comprimir). |
| `validation_seed_combined_front.csv` | Fracción del frente combinado de cada arquitectura en cada semilla (NSGA-III). |
| `validation_tests.csv` | Wilcoxon pareado por semilla entre NSGA-III y la búsqueda aleatoria en cada arquitectura, con la cobertura entre ambos métodos, y entre pares de arquitecturas con NSGA-III. |

**Diseño del acceso y sensibilidad**

| Archivo | Contenido |
| --- | --- |
| `frentes_validados.csv` | Frentes validados de las corridas de diseño (3 semillas por arquitectura y régimen): parámetros, los cuatro objetivos y si el agente es funcional (umbral menor que 300 ms). |
| `corridas_nsga3.rds` | Objetos de esas corridas de NSGA-III (rmoo). |
| `metricas_frentes.csv` | Por régimen y arquitectura, tamaño del frente, hipervolumen y fracción del frente combinado, con todas las soluciones y solo con agentes funcionales. |
| `cobertura_frentes.csv` | Cobertura C(A, B) entre arquitecturas, por régimen y subconjunto. |
| `rodillas.csv`, `ausencias.csv` | Rodillas y ausencias calculadas por el script principal, con el costo en lecturas por segundo en la distancia al punto ideal. El artículo usa las de `post_hoc/resultados/`, ver el README del proyecto. |
| `sensibilidad_frentes.csv`, `sensibilidad_metricas.csv`, `sensibilidad_cobertura.csv` | Lo mismo para el análisis de sensibilidad en el régimen limpio: la condición base (las tres semillas de diseño) y cinco cambios de a uno con la semilla 11 (pulsos de 5 y 20 ms, ruido de 0,4 y 0,9 e ISI de 5 a 70 ms). |
| `sensibilidad_periodo_periodico.csv` | Número de lectores periódicos funcionales, periodo mediano y fracción en la banda alfa (80 a 125 ms) por condición. |

**Ajuste a datos y Haarlem et al.**

| Archivo | Contenido |
| --- | --- |
| `datos/` | Los cuatro conjuntos de observadores sintéticos (uno por arquitectura) y sus parámetros verdaderos, en el formato de `datos_ejemplo/`. |
| `ajuste_participantes.csv` | Ajuste de cada arquitectura a cada participante sintético y a los 38 de Deodato y Melcher con el ISI leído como asincronía entre inicios: log-verosimilitud, AIC, parámetros ajustados, prueba de fase, si es el mejor y si la decisión es decisiva. |
| `recuperacion_modelos.csv`, `recuperacion_modelos_margen4.csv` | Número de participantes de cada conjunto (los cuatro sintéticos y Deodato y Melcher) mejor explicados por cada arquitectura según el AIC, con todas las decisiones y solo con las decisivas (margen de AIC de 4 o más sobre el segundo modelo). |
| `ajuste_T_vs_iaf.csv` | Correlación entre el periodo ajustado y 1000/IAF, y fracción de observadores con efecto de fase, por conjunto y arquitectura. |
| `ajuste_ecm_curva_deodato_melcher_2024.csv` | Error cuadrático medio entre la curva psicométrica promedio de Deodato y Melcher y la de cada arquitectura. |
| `haarlem_participantes.csv` | Por participante de Haarlem et al.: umbral (ms), proporción correcta, fusión crítica de parpadeo (Hz), IAF en reposo y prestímulo, sus periodos y el periodo implícito de un lector periódico con ese umbral. |
| `haarlem_correlaciones.csv` | Correlaciones de Pearson y Spearman del umbral con el periodo alfa en reposo y prestímulo y con la fusión crítica de parpadeo, y de la IAF en reposo con esta última. |
| `haarlem_prediccion_periodica.csv`, `haarlem_resumen.csv` | Umbral predicho por un lector periódico canónico para cada T (bruto y con regresión isotónica), y resumen: pendiente predicha y observada, umbral y periodo alfa medios y periodo implícito medio. |
| `haarlem_iaf_prestimulo_correctos_vs_incorrectos.csv` | Diferencia de frecuencia alfa prestímulo entre ensayos correctos e incorrectos por sensor. |

**Registro y figuras de control**

| Archivo | Contenido |
| --- | --- |
| `progreso.log` | Hora, duración, tamaño del frente e hipervolumen (o AIC en los ajustes) de cada corrida. |
| `sesion.txt` | `sessionInfo()` de R (versiones de R y de los paquetes) y duración total. |
| `resultados.rds` | Configuración y resultados de cada sección de la corrida en una lista de R. |
| `fig*.png` | Figuras de control del script principal (no son las del artículo, que están en `post_hoc/figuras/`). |

## English

Results of the run of the paper (`Rscript correr_todo.R` on a Linux server with 63 cores, 21 October 2026, 6 hours and 21 minutes). `consciencia_discreta.R` writes everything it produces here; a new run overwrites these files. In column values, `continua`, `continua_modulada`, `periodica` and `eventos` are the four architectures (continuous, modulated continuous, periodic and event readers), and `limpio` and `rafagas` are the input regimes without and with distractors (clean and bursty).

**Validation of the optimiser (clean regime)**

| File | Content |
| --- | --- |
| `validation_parametrisation_runs.csv` | The 324 runs of the parametrisation (27 configurations, 4 architectures and 3 seeds): configuration, validation hypervolume, front size and minutes. |
| `validation_parametrisation_summary.csv` | Median and mean hypervolume per configuration, sorted from highest to lowest; the first row is the selected configuration. |
| `validation_convergence_curve.csv` | Hypervolume of the first front (training bank) at each of the 1500 generations of the 44 long runs, and its running maximum. |
| `validation_convergence_cutoff.csv` | For each long run, the final hypervolume and the generations at which it reaches 95%, 99% and 99.9% of it. |
| `validation_convergence_chosen_cutoff.csv` | Cutoff rule: median generation of 99%, margin, minimum (1000) and generations of the main runs. |
| `validation_seed_runs.csv` | Validation hypervolume, front size and minutes of the 11 seeds of NSGA-III and of random search per architecture. |
| `validation_seed_summary.csv` | Mean, standard deviation, minimum, median and maximum of that hypervolume per method and architecture. |
| `validation_seed_fronts.csv.gz` | Validated fronts of those 88 runs (gzipped; about 60 MB uncompressed). |
| `validation_seed_combined_front.csv` | Share of the combined front of each architecture in each seed (NSGA-III). |
| `validation_tests.csv` | Paired Wilcoxon tests per seed between NSGA-III and random search in each architecture, with the coverage between both methods, and between pairs of architectures with NSGA-III. |

**Design of access and sensitivity**

| File | Content |
| --- | --- |
| `frentes_validados.csv` | Validated fronts of the design runs (3 seeds per architecture and regime): parameters, the four objectives and whether the agent is functional (threshold below 300 ms). |
| `corridas_nsga3.rds` | Objects of those NSGA-III runs (rmoo). |
| `metricas_frentes.csv` | Per regime and architecture, front size, hypervolume and share of the combined front, with all solutions and with functional agents only. |
| `cobertura_frentes.csv` | Coverage C(A, B) between architectures, per regime and subset. |
| `rodillas.csv`, `ausencias.csv` | Knees and absences computed by the main script, with the cost in reads per second in the distance to the ideal point. The paper uses the ones in `post_hoc/resultados/`, see the README of the project. |
| `sensibilidad_frentes.csv`, `sensibilidad_metricas.csv`, `sensibilidad_cobertura.csv` | The same for the sensitivity analysis in the clean regime: the base condition (the three design seeds) and five one-at-a-time changes with seed 11 (pulses of 5 and 20 ms, noise of 0.4 and 0.9 and ISIs from 5 to 70 ms). |
| `sensibilidad_periodo_periodico.csv` | Number of functional periodic readers, median period and fraction in the alpha band (80 to 125 ms) per condition. |

**Fits to data and Haarlem et al.**

| File | Content |
| --- | --- |
| `datos/` | The four sets of synthetic observers (one per architecture) and their true parameters, in the format of `datos_ejemplo/`. |
| `ajuste_participantes.csv` | Fit of each architecture to each synthetic participant and to the 38 of Deodato and Melcher with the ISI read as an onset asynchrony: log-likelihood, AIC, fitted parameters, phase test, whether it is the best one and whether the decision is decisive. |
| `recuperacion_modelos.csv`, `recuperacion_modelos_margen4.csv` | Number of participants of each set (the four synthetic ones and Deodato and Melcher) best explained by each architecture according to the AIC, with all decisions and with decisive decisions only (AIC margin of 4 or more over the second model). |
| `ajuste_T_vs_iaf.csv` | Correlation between the fitted period and 1000/IAF, and fraction of observers with a phase effect, per set and architecture. |
| `ajuste_ecm_curva_deodato_melcher_2024.csv` | Mean squared error between the mean psychometric curve of Deodato and Melcher and the one of each architecture. |
| `haarlem_participantes.csv` | Per participant of Haarlem et al.: threshold (ms), proportion correct, critical flicker fusion (Hz), IAF at rest and before the stimulus, their periods and the implied period of a periodic reader with that threshold. |
| `haarlem_correlaciones.csv` | Pearson and Spearman correlations of the threshold with the alpha period at rest and before the stimulus and with the critical flicker fusion, and of the IAF at rest with the latter. |
| `haarlem_prediccion_periodica.csv`, `haarlem_resumen.csv` | Threshold predicted by a canonical periodic reader for each T (raw and with isotonic regression), and summary: predicted and observed slope, mean threshold and alpha period and mean implied period. |
| `haarlem_iaf_prestimulo_correctos_vs_incorrectos.csv` | Difference of pre-stimulus alpha frequency between correct and incorrect trials per sensor. |

**Log and check figures**

| File | Content |
| --- | --- |
| `progreso.log` | Time, duration, front size and hypervolume (or AIC in the fits) of each run. |
| `sesion.txt` | R `sessionInfo()` (versions of R and of the packages) and total duration. |
| `resultados.rds` | Configuration and results of each section of the run in one R list. |
| `fig*.png` | Check figures of the main script (not the ones of the paper, which are in `post_hoc/figuras/`). |
