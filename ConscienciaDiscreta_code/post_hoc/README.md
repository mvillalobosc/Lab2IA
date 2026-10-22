# post_hoc

[Español](#español) · [English](#english)

## Español

Análisis posteriores a la corrida del servidor, estadística y figuras del artículo. `cargar_funciones.R` carga las funciones y la configuración de `../consciencia_discreta.R` sin correr su sección 10, de modo que estos análisis usan el mismo agente, los mismos bancos de ensayos y los mismos objetivos que la corrida. Los scripts leen `../salida/` y escriben en `resultados/`, `estadistica/` y `figuras/`, y se corren desde esta carpeta.

### Uso

```
cd post_hoc
Rscript correr_post_hoc.R                  # todo
SALTAR_LENTOS=1 Rscript correr_post_hoc.R  # sin los tres pasos lentos (unos dos minutos)
N_CORES=8 Rscript correr_post_hoc.R        # núcleos para los pasos lentos
```

`correr_post_hoc.R` corre los scripts en el orden de la tabla y se detiene si alguno termina con error. Con `SALTAR_LENTOS=1` usa los resultados de los pasos lentos que ya están en `resultados/`. Cada script también se puede correr solo, en el mismo orden; por ejemplo, `Rscript analisis.R ../salida estadistica`. Las figuras necesitan la fuente TeX Gyre Heros y soporte de Cairo en R, y la Fig. 1 necesita pdflatex con TikZ.

### Scripts

| Orden | Script | Qué hace | Salida |
| --- | --- | --- | --- |
|  | `cargar_funciones.R` | Carga las funciones y la configuración del script principal; lo usan los scripts que simulan con el agente. |  |
| 1 | `rodillas_ausencias.R` | Rodillas de cada arquitectura y régimen con el costo en log10 también en la distancia al punto ideal (Sect. 3.5), y demostración de ausencias con esas rodillas. | `resultados/rodillas_corregidas.csv`, `resultados/ausencias_corregidas/` |
| 2 | `mimetismo.R` | Verosimilitud de cada observador sintético bajo su generador con los parámetros verdaderos, para separar el mimetismo de las fallas de optimización. | `resultados/mimetismo.csv` |
| 3 | `reajuste_deodato.R` (lento) | Reajuste de los 38 participantes de Deodato y Melcher con el ISI leído como pausa en blanco entre destellos de 10 ms (152 ajustes, unas dos horas con un núcleo). | `resultados/ajuste_deodato_pausa.csv` |
| 4 | `resumen_deodato.R` | Resumen de ese reajuste y comparación con la lectura del ISI entre inicios de la corrida del servidor. | pantalla |
| 5 | `haarlem_cota.R` (lento) | Cota inferior del umbral de un lector periódico en el paradigma de Haarlem et al., con GA para T de 10 a 120 ms (cerca de una hora con un núcleo). | `resultados/haarlem_cota_periodica_10_120.csv` |
| 6 | `haarlem_rejilla.R` (lento) | Comprobación de esa cota con una rejilla en siete periodos entre 30 y 120 ms (unos 11 minutos con un núcleo). | `resultados/haarlem_rejilla_30_120.csv` |
| 7 | `cota_final.R` | Cota final (mínimo entre GA y rejilla, con regresión isotónica) y periodo máximo compatible con el umbral de cada participante. | `resultados/cota_haarlem_final.csv` |
| 8 | `analisis.R` | Estadística de la validación del optimizador, del diseño, de la sensibilidad, de la recuperación de modelos y de Haarlem et al. | `estadistica/resumen.txt` y tablas `A_` a `K_` |
| 9 | `analisis_complementario.R` | Cifras del diseño, de los intervalos entre lecturas y de la sensibilidad que el artículo cita y que `analisis.R` no calcula, más los indicadores de calidad (IGD+, épsilon aditivo y espaciado) y los valores extremos de NSGA-III y de la búsqueda aleatoria. | `estadistica/resumen_complementario.txt` y tablas `L_` |
| 10 | `figuras.R` | Fig. 2 a 16. | `figuras/`, `resultados/ecm_curva_deodato_pausa.csv` y `resultados/haarlem_T_max.csv` |
| 11 | `Fig1.tex` | Diagrama TikZ de la Fig. 1, que `correr_post_hoc.R` compila con pdflatex. | `figuras/Fig1.pdf` |

Fuera de los tres pasos lentos, cada script tarda segundos; `analisis.R` y `figuras.R` tardan menos de un minuto cada uno.

### Salidas

- `resultados/`: rodillas, ausencias, mimetismo, reajuste de Deodato y Melcher y cota de Haarlem et al., ver `resultados/README.md`.
- `estadistica/`: resúmenes de texto y tablas de la estadística, ver `estadistica/README.md`.
- `figuras/`: figuras del artículo, ver `figuras/README.md`.

## English

Analyses after the server run, statistics and figures of the paper. `cargar_funciones.R` loads the functions and the configuration of `../consciencia_discreta.R` without running its section 10, so these analyses use the same agent, trial banks and objectives as the run. The scripts read `../salida/` and write to `resultados/`, `estadistica/` and `figuras/`, and they are run from this folder.

### Usage

```
cd post_hoc
Rscript correr_post_hoc.R                  # everything
SALTAR_LENTOS=1 Rscript correr_post_hoc.R  # without the three slow steps (about two minutes)
N_CORES=8 Rscript correr_post_hoc.R        # cores for the slow steps
```

`correr_post_hoc.R` runs the scripts in the order of the table and stops if one of them ends with an error. With `SALTAR_LENTOS=1`, it uses the results of the slow steps already stored in `resultados/`. Each script can also be run alone, in the same order; for example, `Rscript analisis.R ../salida estadistica`. The figures need the TeX Gyre Heros font and Cairo support in R, and Fig. 1 needs pdflatex with TikZ.

### Scripts

| Order | Script | What it does | Output |
| --- | --- | --- | --- |
|  | `cargar_funciones.R` | Loads the functions and the configuration of the main script; the scripts that simulate with the agent use it. |  |
| 1 | `rodillas_ausencias.R` | Knees of each architecture and regime with the cost in log10 also in the distance to the ideal point (Sect. 3.5), and demonstration of absences with those knees. | `resultados/rodillas_corregidas.csv`, `resultados/ausencias_corregidas/` |
| 2 | `mimetismo.R` | Log-likelihood of each synthetic observer under its generator with the true parameters, to separate mimicry from optimisation failures. | `resultados/mimetismo.csv` |
| 3 | `reajuste_deodato.R` (slow) | Refit of the 38 participants of Deodato and Melcher with the ISI read as a blank gap between 10 ms flashes (152 fits, about two hours on one core). | `resultados/ajuste_deodato_pausa.csv` |
| 4 | `resumen_deodato.R` | Summary of that refit and comparison with the onset-to-onset reading of the ISI of the server run. | screen |
| 5 | `haarlem_cota.R` (slow) | Lower bound of the threshold of a periodic reader in the paradigm of Haarlem et al., with GA for T from 10 to 120 ms (about one hour on one core). | `resultados/haarlem_cota_periodica_10_120.csv` |
| 6 | `haarlem_rejilla.R` (slow) | Check of that bound with a grid at seven periods between 30 and 120 ms (about 11 minutes on one core). | `resultados/haarlem_rejilla_30_120.csv` |
| 7 | `cota_final.R` | Final bound (lowest of GA and grid, with an isotonic regression) and longest period compatible with the threshold of each participant. | `resultados/cota_haarlem_final.csv` |
| 8 | `analisis.R` | Statistics of the validation of the optimiser, the design, the sensitivity, the model recovery and Haarlem et al. | `estadistica/resumen.txt` and tables `A_` to `K_` |
| 9 | `analisis_complementario.R` | Numbers of the design, the intervals between reads and the sensitivity that the paper cites and that `analisis.R` does not compute, plus the quality indicators (IGD+, additive epsilon and spacing) and the extreme values of NSGA-III and random search. | `estadistica/resumen_complementario.txt` and tables `L_` |
| 10 | `figuras.R` | Figs. 2 to 16. | `figuras/`, `resultados/ecm_curva_deodato_pausa.csv` and `resultados/haarlem_T_max.csv` |
| 11 | `Fig1.tex` | TikZ diagram of Fig. 1, which `correr_post_hoc.R` compiles with pdflatex. | `figuras/Fig1.pdf` |

Apart from the three slow steps, each script takes seconds; `analisis.R` and `figuras.R` take less than one minute each.

### Outputs

- `resultados/`: knees, absences, mimicry, refit of Deodato and Melcher and bound of Haarlem et al., see `resultados/README.md`.
- `estadistica/`: text summaries and tables of the statistics, see `estadistica/README.md`.
- `figuras/`: figures of the paper, see `figuras/README.md`.
