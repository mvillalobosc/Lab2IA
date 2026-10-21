# ConscienciaDiscreta_code

[Español](#español) · [English](#english)

## Español

Este proyecto contiene el código en R, los datos y los resultados del manuscrito *Evaluating discrete and continuous conscious access with NSGA-III: a design study contrasted with two-flash fusion data* (Villalobos-Cid y Baladrón). El trabajo pregunta qué esquema de acceso a un sustrato neural continuo debería preferir un sistema perceptivo cuando la exactitud, la resolución temporal, la latencia y el costo del acceso están en conflicto.

Un integrador con fuga modela el sustrato continuo y cuatro compuertas de lectura modelan el acceso a él: lectura continua, lectura continua con un umbral que oscila (continua modulada), lectura periódica y lectura por eventos. En una tarea simulada de fusión de dos pulsos, NSGA-III busca los parámetros de cada arquitectura minimizando cuatro objetivos: la tasa de error, el umbral de fusión, la latencia de acceso y el costo en lecturas por segundo. El código valida el optimizador (parametrización, prueba de convergencia de 1500 generaciones, 11 semillas y una búsqueda aleatoria con el mismo número de evaluaciones), compara las arquitecturas, ajusta los modelos a datos conductuales (observadores sintéticos y dos experimentos públicos de fusión de dos destellos) y simula huecos de acceso para ver si el agente los nota desde dentro.

El proyecto trae los datos de entrada y todos los resultados de la corrida del artículo, así que cada cifra y cada figura se pueden revisar sin volver a correr nada.

### Contenido

```
ConscienciaDiscreta_code/
├── LICENSE
├── README.md
├── consciencia_discreta.R   script principal: agente, NSGA-III, validación, diseño,
│                            sensibilidad, ajuste a datos, ausencias y figuras de control
├── correr_todo.R            fija el número de núcleos y corre consciencia_discreta.R
├── datos_reales/            datos humanos públicos, ver datos_reales/README.md
├── datos_ejemplo/           datos sintéticos de ejemplo, ver datos_ejemplo/README.md
├── salida/                  resultados de la corrida del artículo, ver salida/README.md
└── post_hoc/                análisis posteriores, estadística y figuras del artículo,
                             ver post_hoc/README.md
```

### Requisitos

R 4.1 o superior; el código se probó con R 4.3.3 en Linux (Ubuntu 24.04). El script principal instala solo los paquetes que faltan: rmoo (NSGA-III), ecr (hipervolumen exacto), GA (ajuste a datos), ggplot2, doParallel, doRNG y readxl. La corrida del artículo usó rmoo 0.3.2, ecr 2.1.1 y GA 3.2.5; `salida/sesion.txt` guarda las versiones de todos los paquetes. Los análisis post hoc usan además patchwork y, para las figuras del artículo, la fuente TeX Gyre Heros, soporte de Cairo en R (`capabilities("cairo")` debe dar `TRUE`) y pdflatex con TikZ para la Fig. 1.

R debe correr con una configuración regional UTF-8, porque los scripts traen tildes y eñes; el script principal intenta fijarla si no lo está. El paralelismo usa procesos bifurcados (multicore), que existen en Linux y macOS; en Windows el script corre en un solo núcleo.

### Datos

- `datos_reales/deodato_melcher_2024/`: curvas psicométricas de fusión de dos destellos de 38 participantes (Deodato y Melcher, 2024), del proyecto OSF <https://osf.io/acb9n/>.
- `datos_reales/haarlem_2024/`: umbrales de fusión y frecuencia alfa individual de 31 participantes (Haarlem et al., 2024), de Zenodo <https://doi.org/10.5281/zenodo.10844750>, con licencia CC BY 4.0.
- `datos_ejemplo/`: observadores sintéticos generados por el mismo agente, para probar la ruta de datos reales del script.

Los datos humanos conservan los términos de sus autores y se deben citar las fuentes originales, que están en `datos_reales/README.md`.

### Ejecución

1. Corrida completa, desde esta carpeta:

   ```
   Rscript correr_todo.R
   ```

   `correr_todo.R` usa todos los núcleos menos uno; también se puede correr `N_CORES=60 Rscript consciencia_discreta.R`. Con 63 núcleos, la corrida del artículo tomó 6 horas y 21 minutos (ver `salida/progreso.log` y `salida/sesion.txt`). Para probar que todo corre en pocos minutos, sin resultados útiles, está el modo rápido: `MODO=rapido Rscript consciencia_discreta.R`. Todo queda en `salida/`.

2. Análisis post hoc y figuras del artículo, desde `post_hoc/`:

   ```
   cd post_hoc
   Rscript correr_post_hoc.R
   ```

   Los tres pasos lentos (reajuste de Deodato y Melcher y cota del lector periódico en el paradigma de Haarlem et al.) toman unas tres horas con un núcleo. Con `SALTAR_LENTOS=1 Rscript correr_post_hoc.R` se usan los resultados que ya están en `post_hoc/resultados/` y el resto toma unos dos minutos.

`salida/validation_seed_fronts.csv` viene comprimido como `.csv.gz` por su tamaño; los scripts post hoc lo leen así, y una corrida nueva del script principal lo vuelve a escribir sin comprimir. Para subir una corrida nueva hay que comprimirlo con `gzip -f salida/validation_seed_fronts.csv`; el `.gitignore` de Lab2IA ignora la versión sin comprimir.

### Correspondencia con el artículo

| Elemento del artículo | Dónde está |
| --- | --- |
| Fig. 1 (agente y arquitecturas) | `post_hoc/Fig1.tex` y `post_hoc/figuras/Fig1.pdf` |
| Fig. 2 a 16 (las Fig. 11 a 16 están en el apéndice) | `post_hoc/figuras/`, generadas por `post_hoc/figuras.R` |
| Validación del optimizador (Sect. 4.1, Tabla 5) | `salida/validation_*.csv`, secciones A, B, C y K de `post_hoc/estadistica/resumen.txt` (tablas A a E, J y K) y secciones 6 y 8 de `resumen_complementario.txt` |
| Diseño del acceso (Sect. 4.2, Tablas 6 a 8) | `salida/frentes_validados.csv`, `salida/metricas_frentes.csv`, `salida/cobertura_frentes.csv`, `post_hoc/resultados/rodillas_corregidas.csv`, sección F de `resumen.txt` (tabla F) y secciones 1 a 3 y 7 de `resumen_complementario.txt` |
| Intervalos entre lecturas (Sect. 4.3) | sección F de `resumen.txt` y sección 4 de `resumen_complementario.txt` |
| Sensibilidad (Sect. 4.4) | `salida/sensibilidad_*.csv`, sección G de `resumen.txt` y sección 5 de `resumen_complementario.txt` |
| Identificabilidad y datos humanos (Sect. 4.5) | `salida/ajuste_participantes.csv`, `salida/recuperacion_modelos*.csv`, `salida/haarlem_*.csv`, `post_hoc/resultados/` (mimetismo, reajuste de Deodato y Melcher y cota de Haarlem et al.) y secciones H e I de `resumen.txt` |
| Ausencias (Sect. 4.6) | `post_hoc/resultados/ausencias_corregidas/ausencias.csv` |

Las rodillas y las ausencias del artículo son las de `post_hoc/resultados/`. Ahí el costo entra en escala log10 también en la distancia al punto ideal, como describe el artículo; en el script principal, `rodilla()` recibe el costo en lecturas por segundo, así que `salida/rodillas.csv` y `salida/ausencias.csv` no son las del artículo.

### Cómo citar

Villalobos-Cid, M., y Baladrón, J. (2026). *Evaluating discrete and continuous conscious access with NSGA-III: a design study contrasted with two-flash fusion data*. Manuscrito.

Si usa los datos humanos, cite también a Deodato y Melcher (2024) y a Haarlem et al. (2024), como indica `datos_reales/README.md`.

### Financiamiento

ANID FONDECYT 1261239 y ANID Anillo ACT250038.

### Licencia

El código tiene licencia MIT (ver `LICENSE`). Los datos de `datos_reales/` conservan los términos de sus autores.

---

## English

This project contains the R code, data and results of the manuscript *Evaluating discrete and continuous conscious access with NSGA-III: a design study contrasted with two-flash fusion data* (Villalobos-Cid and Baladrón). The work asks which scheme of access to a continuous neural substrate a perceptual system should prefer when accuracy, temporal resolution, latency and the cost of access are in conflict.

A leaky integrator models the continuous substrate, and four reading gates model the access to it: continuous reading, continuous reading against an oscillating threshold (modulated continuous), periodic reading and event reading. In a simulated two-pulse fusion task, NSGA-III searches the parameters of each architecture by minimising four objectives: the error rate, the fusion threshold, the access latency and the cost in reads per second. The code validates the optimiser (parametrisation, a 1500-generation convergence test, 11 seeds and a random search with the same number of evaluations), compares the architectures, fits the models to behavioural data (synthetic observers and two public two-flash fusion experiments) and simulates access gaps to check if the agent notices them from the inside.

The project includes the input data and all the results of the run of the paper, so every number and figure can be checked without running anything again.

### Contents

```
ConscienciaDiscreta_code/
├── LICENSE
├── README.md
├── consciencia_discreta.R   main script: agent, NSGA-III, validation, design,
│                            sensitivity, fits to data, absences and check figures
├── correr_todo.R            sets the number of cores and runs consciencia_discreta.R
├── datos_reales/            public human data, see datos_reales/README.md
├── datos_ejemplo/           example synthetic data, see datos_ejemplo/README.md
├── salida/                  results of the run of the paper, see salida/README.md
└── post_hoc/                later analyses, statistics and figures of the paper,
                             see post_hoc/README.md
```

### Requirements

R 4.1 or later; the code was tested with R 4.3.3 on Linux (Ubuntu 24.04). The main script installs the missing packages by itself: rmoo (NSGA-III), ecr (exact hypervolume), GA (fits to data), ggplot2, doParallel, doRNG and readxl. The run of the paper used rmoo 0.3.2, ecr 2.1.1 and GA 3.2.5; `salida/sesion.txt` stores the versions of all packages. The post hoc analyses also use patchwork and, for the figures of the paper, the TeX Gyre Heros font, Cairo support in R (`capabilities("cairo")` must return `TRUE`) and pdflatex with TikZ for Fig. 1.

R must run with a UTF-8 locale, since the scripts contain accented characters; the main script tries to set it if needed. Parallelism uses forked processes (multicore), which exist on Linux and macOS; on Windows the script runs on a single core.

### Data

- `datos_reales/deodato_melcher_2024/`: two-flash fusion psychometric curves of 38 participants (Deodato and Melcher, 2024), from the OSF project <https://osf.io/acb9n/>.
- `datos_reales/haarlem_2024/`: fusion thresholds and individual alpha frequency of 31 participants (Haarlem et al., 2024), from Zenodo <https://doi.org/10.5281/zenodo.10844750>, under a CC BY 4.0 licence.
- `datos_ejemplo/`: synthetic observers generated by the same agent, to test the real-data path of the script.

The human data keep the terms of their authors, and the original sources, listed in `datos_reales/README.md`, must be cited.

### Running

1. Full run, from this folder:

   ```
   Rscript correr_todo.R
   ```

   `correr_todo.R` uses all cores but one; `N_CORES=60 Rscript consciencia_discreta.R` also works. With 63 cores, the run of the paper took 6 hours and 21 minutes (see `salida/progreso.log` and `salida/sesion.txt`). To check that everything runs in a few minutes, without useful results, there is a quick mode: `MODO=rapido Rscript consciencia_discreta.R`. Everything goes to `salida/`.

2. Post hoc analyses and figures of the paper, from `post_hoc/`:

   ```
   cd post_hoc
   Rscript correr_post_hoc.R
   ```

   The three slow steps (refit of Deodato and Melcher and bound of the periodic reader in the paradigm of Haarlem et al.) take about three hours on one core. With `SALTAR_LENTOS=1 Rscript correr_post_hoc.R`, the results already stored in `post_hoc/resultados/` are used and the rest takes about two minutes.

`salida/validation_seed_fronts.csv` is stored gzipped as `.csv.gz` because of its size; the post hoc scripts read it as it is, and a new run of the main script writes it again uncompressed. To commit a new run, compress it with `gzip -f salida/validation_seed_fronts.csv`; the `.gitignore` of Lab2IA ignores the uncompressed version.

### Correspondence with the paper

| Element of the paper | Where it is |
| --- | --- |
| Fig. 1 (agent and architectures) | `post_hoc/Fig1.tex` and `post_hoc/figuras/Fig1.pdf` |
| Figs. 2 to 16 (Figs. 11 to 16 are in the appendix) | `post_hoc/figuras/`, produced by `post_hoc/figuras.R` |
| Validation of the optimiser (Sect. 4.1, Table 5) | `salida/validation_*.csv`, sections A, B, C and K of `post_hoc/estadistica/resumen.txt` (tables A to E, J and K) and sections 6 and 8 of `resumen_complementario.txt` |
| Design of access (Sect. 4.2, Tables 6 to 8) | `salida/frentes_validados.csv`, `salida/metricas_frentes.csv`, `salida/cobertura_frentes.csv`, `post_hoc/resultados/rodillas_corregidas.csv`, section F of `resumen.txt` (table F) and sections 1 to 3 and 7 of `resumen_complementario.txt` |
| Intervals between reads (Sect. 4.3) | section F of `resumen.txt` and section 4 of `resumen_complementario.txt` |
| Sensitivity (Sect. 4.4) | `salida/sensibilidad_*.csv`, section G of `resumen.txt` and section 5 of `resumen_complementario.txt` |
| Identifiability and human data (Sect. 4.5) | `salida/ajuste_participantes.csv`, `salida/recuperacion_modelos*.csv`, `salida/haarlem_*.csv`, `post_hoc/resultados/` (mimicry, refit of Deodato and Melcher and bound of Haarlem et al.) and sections H and I of `resumen.txt` |
| Absences (Sect. 4.6) | `post_hoc/resultados/ausencias_corregidas/ausencias.csv` |

The knees and absences of the paper are the ones in `post_hoc/resultados/`. There, the cost enters in log10 scale also in the distance to the ideal point, as the paper describes; in the main script, `rodilla()` receives the cost in reads per second, so `salida/rodillas.csv` and `salida/ausencias.csv` are not the ones of the paper.

### How to cite

Villalobos-Cid, M., & Baladrón, J. (2026). *Evaluating discrete and continuous conscious access with NSGA-III: a design study contrasted with two-flash fusion data*. Manuscript.

If you use the human data, please also cite Deodato and Melcher (2024) and Haarlem et al. (2024), as `datos_reales/README.md` indicates.

### Funding

ANID FONDECYT 1261239 and ANID Anillo ACT250038.

### Licence

The code is under the MIT licence (see `LICENSE`). The data in `datos_reales/` keep the terms of their authors.
