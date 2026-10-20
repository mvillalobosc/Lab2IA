# resultados/figuras_paper/

[Español](#español) · [English](#english)

## Español

Estas son las ocho figuras del manuscrito, cada una en PDF (vectorial) y PNG. Tienen títulos y ejes en inglés y fondos de color que marcan las tres etapas escolares (básica inicial, básica superior y media). Ningún script del repositorio las produce: sus nombres no aparecen en el código y su diseño es distinto al de las figuras que escribe `guardar_fig()`, así que se hicieron aparte a partir de las tablas de la corrida. Vuelve a [resultados/](../README.md).

| Figura | Qué muestra |
|---|---|
| `fig_emotions` | Ocho paneles, uno por emoción NRC (alegría, confianza, anticipación, sorpresa, tristeza, miedo, ira y asco), con la proporción media de palabras emocionales por nivel y su intervalo de confianza del 95 %. |
| `fig_entropy` | La entropía de Shannon media (en bits) por nivel, con banda de ±1 desviación estándar, la media de cada etapa como segmento grueso y el epsilon cuadrado de Kruskal-Wallis (0,38). |
| `fig_gam` | Seis paneles con las trayectorias GAM de las métricas con el efecto de nivel más fuerte (HD-D, entropía de Shannon, MATTR-100, proporción de hapax, perfil mu y distancia media de dependencia), con banda de ±2 errores estándar y un intercepto aleatorio por título. |
| `fig_mattr` | MATTR-100 medio por nivel, con banda de ±1 desviación estándar y la media de cada etapa, sobre 577 obras. |
| `fig_prediction` | El nivel predicho por la regresión ordinal con validación dejando uno fuera frente al nivel asignado, para 575 obras; el área de cada burbuja es el número de obras. |
| `fig_readability_en` | Las medianas por nivel de ARI y RIX estandarizados dentro del corpus, donde un valor más alto indica más dificultad. |
| `fig_readability_es` | Las medianas por nivel de los índices calibrados para el español (Fernández Huerta, Szigriszt-Pazos y perfil mu) estandarizados dentro del corpus, donde un valor más alto indica un texto más fácil. |
| `fig_sentiment` | La polaridad media por nivel (léxico NRC, polaridad por oración normalizada por su largo y promediada por obra), con banda de ±1 desviación estándar y la media de cada etapa. |

## English

These are the eight manuscript figures, each in PDF (vector) and PNG. They have English titles and axes and coloured backgrounds that mark the three school stages (early primary, upper primary and secondary). No script in the repository produces them: their names do not appear in the code and their design differs from the figures that `guardar_fig()` writes, so they were made separately from the run tables. Back to [resultados/](../README.md).

| Figure | What it shows |
|---|---|
| `fig_emotions` | Eight panels, one per NRC emotion (joy, trust, anticipation, surprise, sadness, fear, anger and disgust), with the mean share of emotion words per grade and its 95 % confidence interval. |
| `fig_entropy` | Mean Shannon entropy (in bits) per grade, with a ±1 standard deviation band, each stage mean as a thick segment and the Kruskal-Wallis epsilon squared (0.38). |
| `fig_gam` | Six panels with the GAM trajectories of the metrics with the strongest grade effect (HD-D, Shannon entropy, MATTR-100, hapax ratio, mu profile and mean dependency distance), with a ±2 standard error band and a random intercept per title. |
| `fig_mattr` | Mean MATTR-100 per grade, with a ±1 standard deviation band and each stage mean, over 577 works. |
| `fig_prediction` | The grade predicted by leave-one-out ordinal regression against the assigned grade, for 575 works; the area of each bubble is the number of works. |
| `fig_readability_en` | Per-grade medians of ARI and RIX standardised within the corpus, where higher values mean more difficulty. |
| `fig_readability_es` | Per-grade medians of the Spanish-calibrated indices (Fernández Huerta, Szigriszt-Pazos and the mu profile) standardised within the corpus, where higher values mean an easier text. |
| `fig_sentiment` | Mean polarity per grade (NRC lexicon, per-sentence polarity normalised by sentence length and averaged per work), with a ±1 standard deviation band and each stage mean. |
