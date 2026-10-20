# figures/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las figuras 2 a 5 del manuscrito, en PDF vectorial. Las escribe `scripts/12_figures.R` a partir de `data/results/mapping.csv`, con 131 mm de ancho y letra de 8 pt, y `scripts/00_run_all.R` las sobrescribe en cada corrida. El contexto está en el [README del proyecto](../README.md).

| Archivo | Alto | Contenido |
|---|---|---|
| `Fig2_year_category.pdf` | 80 mm | Estudios incluidos por año y categoría. |
| `Fig3_evidence_year.pdf` | 78 mm | Base de la evidencia de eficiencia en los estudios C1 (medida en hardware, medida y estimada, estimación analítica, afirmación sin cifras, base no declarada o sin cifra de eficiencia), por año, junto con la proporción medida. |
| `Fig4_platforms.pdf` | 92 mm | Plataformas de la SNN y de la ANN en las comparaciones ANN-SNN. |
| `Fig5_sparsity.pdf` | 118 mm | Métodos de esparsidad y presencia de un término de costo en el objetivo, por familia de métodos. |

Para regenerarlas sin correr toda la cadena: `Rscript scripts/12_figures.R figures` desde la raíz del proyecto. Hace falta R con soporte para Cairo y los paquetes data.table, ggplot2, patchwork y scales.

## English

This folder holds Figures 2 to 5 of the manuscript as vector PDF. `scripts/12_figures.R` writes them from `data/results/mapping.csv`, 131 mm wide with 8 pt type, and `scripts/00_run_all.R` overwrites them on every run. The context is in the [project README](../README.md).

| File | Height | Content |
|---|---|---|
| `Fig2_year_category.pdf` | 80 mm | Included studies by year and category. |
| `Fig3_evidence_year.pdf` | 78 mm | Basis of the efficiency evidence in the C1 studies (measured on hardware, measured and estimated, analytical estimate, claim without figures, basis not stated or no efficiency figure), by year, together with the measured share. |
| `Fig4_platforms.pdf` | 92 mm | Platforms of the SNN and of the ANN in the ANN-SNN comparisons. |
| `Fig5_sparsity.pdf` | 118 mm | Sparsity methods and presence of a cost term in the objective, by method family. |

To rebuild them without running the whole pipeline: `Rscript scripts/12_figures.R figures` from the project root. It needs R with Cairo support and the data.table, ggplot2, patchwork and scales packages.
