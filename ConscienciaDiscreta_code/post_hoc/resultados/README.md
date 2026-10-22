# post_hoc/resultados

[Español](#español) · [English](#english)

## Español

Salidas de los análisis post hoc que simulan con el agente. Con `SALTAR_LENTOS=1`, `correr_post_hoc.R` usa los archivos de los pasos lentos que ya están aquí (`ajuste_deodato_pausa.csv`, `haarlem_cota_periodica_10_120.csv` y `haarlem_rejilla_30_120.csv`).

| Archivo | Script | Contenido |
| --- | --- | --- |
| `rodillas_corregidas.csv` | `rodillas_ausencias.R` | Solución rodilla de cada arquitectura y régimen: semilla, parámetros y los cuatro objetivos. Son las rodillas de la Tabla 7 y de las Fig. 2 y 10. |
| `ausencias_corregidas/` | `rodillas_ausencias.R` | Demostración de ausencias con esas rodillas, ver `ausencias_corregidas/README.md`. |
| `mimetismo.csv` | `mimetismo.R` | Por observador sintético: log-verosimilitud y AIC con los parámetros verdaderos y con el ajuste de su generador, arquitectura mejor ajustada, mejor alternativa y si hay falla de optimización o mimetismo. |
| `ajuste_deodato_pausa.csv` | `reajuste_deodato.R` | Ajuste de cada arquitectura a cada participante de Deodato y Melcher con el ISI leído como pausa en blanco, con las mismas columnas que `../../salida/ajuste_participantes.csv`. |
| `ecm_curva_deodato_pausa.csv` | `figuras.R` | Error cuadrático medio entre la curva psicométrica promedio de Deodato y Melcher y la de cada arquitectura con ese reajuste (Fig. 8). |
| `haarlem_cota_periodica_10_120.csv` | `haarlem_cota.R` | Para cada T de 10 a 120 ms: mejor umbral en el banco de entrenamiento y en el de validación, exactitud máxima validada, parámetros (`tau`, `theta_p`, `m`, `w`) y minutos. |
| `haarlem_rejilla_30_120.csv` | `haarlem_rejilla.R` | Lo mismo con la rejilla (`mT` es m/T). |
| `cota_haarlem_final.csv` | `cota_final.R` | Para cada T: umbral validado del GA y de la rejilla, el menor de ambos y su fuente, si queda censurado (no llega al 75 % de aciertos con ISI de hasta 150 ms) y la cota con regresión isotónica (Fig. 9). |
| `haarlem_T_max.csv` | `figuras.R` | Periodo máximo de un lector periódico compatible con el umbral de cada participante de Haarlem et al., junto con sus periodos alfa en reposo y prestímulo (Fig. 9). |

## English

Outputs of the post hoc analyses that simulate with the agent. With `SALTAR_LENTOS=1`, `correr_post_hoc.R` uses the files of the slow steps already stored here (`ajuste_deodato_pausa.csv`, `haarlem_cota_periodica_10_120.csv` and `haarlem_rejilla_30_120.csv`).

| File | Script | Content |
| --- | --- | --- |
| `rodillas_corregidas.csv` | `rodillas_ausencias.R` | Knee solution of each architecture and regime: seed, parameters and the four objectives. These are the knees of Table 7 and of Figs. 2 and 10. |
| `ausencias_corregidas/` | `rodillas_ausencias.R` | Demonstration of absences with those knees, see `ausencias_corregidas/README.md`. |
| `mimetismo.csv` | `mimetismo.R` | Per synthetic observer: log-likelihood and AIC with the true parameters and with the fit of its generator, best fitted architecture, best alternative and whether there is an optimisation failure or mimicry. |
| `ajuste_deodato_pausa.csv` | `reajuste_deodato.R` | Fit of each architecture to each participant of Deodato and Melcher with the ISI read as a blank gap, with the same columns as `../../salida/ajuste_participantes.csv`. |
| `ecm_curva_deodato_pausa.csv` | `figuras.R` | Mean squared error between the mean psychometric curve of Deodato and Melcher and the one of each architecture with that refit (Fig. 8). |
| `haarlem_cota_periodica_10_120.csv` | `haarlem_cota.R` | For each T from 10 to 120 ms: best threshold on the training bank and on the validation bank, highest validated accuracy, parameters (`tau`, `theta_p`, `m`, `w`) and minutes. |
| `haarlem_rejilla_30_120.csv` | `haarlem_rejilla.R` | The same with the grid (`mT` is m/T). |
| `cota_haarlem_final.csv` | `cota_final.R` | For each T: validated threshold of GA and of the grid, the lower of both and its source, whether it is censored (it does not reach 75% correct with ISIs up to 150 ms) and the bound with an isotonic regression (Fig. 9). |
| `haarlem_T_max.csv` | `figuras.R` | Longest period of a periodic reader compatible with the threshold of each participant of Haarlem et al., together with their alpha periods at rest and before the stimulus (Fig. 9). |
