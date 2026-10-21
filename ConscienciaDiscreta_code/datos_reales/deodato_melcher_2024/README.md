# deodato_melcher_2024

[Español](#español) · [English](#english)

## Español

Datos de fusión de dos destellos de Deodato y Melcher (2024), tomados de la carpeta FF del proyecto OSF <https://doi.org/10.17605/osf.io/acb9n>. Las referencias completas están en el README de la carpeta `datos_reales`.

| Archivo | Contenido |
| --- | --- |
| `FF.mat` | Archivo original de los autores. La matriz `FF` (50 x 6) trae, por participante, el umbral de fusión ajustado por los autores (ms), la pendiente, la tasa de adivinación, la tasa de lapsos, la bondad de ajuste y una bandera de exclusión (12 excluidos, quedan 38). `Pcorr` (50 x 7) es la proporción de respuestas "dos" en cada ISI (10, 20, 30, 40, 50, 60 y 70 ms; destellos de 10 ms; 50 ensayos por ISI) y `spread` es el ancho de la curva psicométrica. |
| `deodato_melcher_2024_participantes.csv` | Una fila por participante con las columnas de `FF.mat` en castellano (`umbral_ms_autores`, `pendiente`, `tasa_adivinacion`, `tasa_lapsos`, `bondad_ajuste`, `incluido`, `spread`) y la proporción de respuestas "dos" en cada ISI (`p_dos_10` a `p_dos_70`). |
| `deodato_melcher_2024_ensayos.csv` | `Pcorr` expandida a una fila por ensayo en el formato que lee `consciencia_discreta.R`: `participante`, `isi` (ms), `n_pulsos` (siempre 2), `respuesta` (2 en k = Pcorr x 50 filas y 1 en el resto), `iaf` (vacía) e `incluido`. |

No hay ensayos de un solo destello, así que las falsas alarmas no se observan, y este archivo no trae la frecuencia alfa (está en el EEG de reposo del mismo proyecto, que no se incluye por tamaño). Los artículos no definen el ISI; el artículo de este proyecto lo lee como pausa en blanco y como asincronía entre inicios.

## English

Two-flash fusion data of Deodato and Melcher (2024), taken from the FF folder of the OSF project <https://doi.org/10.17605/osf.io/acb9n>. The full references are in the README of the `datos_reales` folder.

| File | Content |
| --- | --- |
| `FF.mat` | Original file of the authors. The matrix `FF` (50 x 6) gives, for each participant, the fusion threshold fitted by the authors (ms), the slope, the guess rate, the lapse rate, the goodness of fit and an exclusion flag (12 excluded, 38 remain). `Pcorr` (50 x 7) is the proportion of "two" answers at each ISI (10, 20, 30, 40, 50, 60 and 70 ms; 10 ms flashes; 50 trials per ISI), and `spread` is the width of the psychometric curve. |
| `deodato_melcher_2024_participantes.csv` | One row per participant with the columns of `FF.mat` in Spanish (`umbral_ms_autores` threshold, `pendiente` slope, `tasa_adivinacion` guess rate, `tasa_lapsos` lapse rate, `bondad_ajuste` goodness of fit, `incluido` included, `spread`) and the proportion of "two" answers at each ISI (`p_dos_10` to `p_dos_70`). |
| `deodato_melcher_2024_ensayos.csv` | `Pcorr` expanded to one row per trial in the format read by `consciencia_discreta.R`: `participante`, `isi` (ms), `n_pulsos` (always 2), `respuesta` (2 in k = Pcorr x 50 rows and 1 in the rest), `iaf` (empty) and `incluido`. |

There are no single-flash trials, so false alarms are not observed, and this file has no alpha frequency (it is in the resting EEG of the same project, which is not included because of its size). The papers do not define the ISI; the paper of this project reads it both as a blank gap and as an onset asynchrony.
