# TE_worldwide_code/data/raw

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las tres fuentes desde las que `R/03_build_dataset.R` arma la base `../dataset_country_year.csv` (ver [`../README.md`](../README.md)). Son los archivos que usó el artículo; el README del proyecto es [`../../README.md`](../../README.md).

| Archivo | Filas | Columnas | Origen |
|---|---|---|---|
| `worldbank_2026-09-27.csv` | 720 (120 países por 2015 a 2020) | `code`, `year` y los 15 indicadores: `che_gdp`, `che_pc_ppp`, `phys`, `beds`, `le`, `imr`, `cbr`, `cdr`, `gni_pc`, `lf`, `edu`, `gdp_pc`, `dens`, `rur`, `pop` | extracción del Banco Mundial del 27 de septiembre de 2026; `R/01_download_worldbank.R` produce archivos con este mismo formato y los códigos de cada indicador están en su encabezado |
| `published_scores_2024.csv` | 466 (83, 84, 84, 85, 71 y 59 país-año entre 2015 y 2020) | `code`, `country`, `income`, `financing`, `year`, `te_io_crs`, `te_oo_crs`, `te_io_vrs`, `te_oo_vrs` | puntajes de eficiencia de la tesis fuente (Valenzuela-Silva 2024, apéndices H a K) con dos decimales, más el grupo de ingreso del Banco Mundial y el modelo de financiamiento de cada país; ningún script lo genera |
| `covid_2020_owid.csv` | 59 (los países de la frontera de 2020) | `code`, `cases_pm`, `deaths_pm`, `r_mean`, `r_days` | extracción de Our World in Data que hace `R/02_download_owid.R`; Laos (`LAO`) no tiene estimación del número reproductivo, así que su `r_mean` está vacío y su `r_days` vale 0 |

`worldbank_2026-09-27.csv` y `published_scores_2024.csv` tienen fin de línea CRLF; `read.csv` los lee igual.

Si se vuelve a correr `R/01_download_worldbank.R`, el archivo nuevo queda en esta carpeta con la fecha del día en el nombre y la instantánea no se toca. `R/02_download_owid.R`, en cambio, sobrescribe `covid_2020_owid.csv`.

## English

This folder holds the three sources from which `R/03_build_dataset.R` builds the database `../dataset_country_year.csv` (see [`../README.md`](../README.md)). They are the files the article used; the project README is [`../../README.md`](../../README.md).

| File | Rows | Columns | Origin |
|---|---|---|---|
| `worldbank_2026-09-27.csv` | 720 (120 countries by 2015 to 2020) | `code`, `year` and the 15 indicators: `che_gdp`, `che_pc_ppp`, `phys`, `beds`, `le`, `imr`, `cbr`, `cdr`, `gni_pc`, `lf`, `edu`, `gdp_pc`, `dens`, `rur`, `pop` | World Bank extraction of 27 September 2026; `R/01_download_worldbank.R` writes files in the same format, and the code of every indicator is listed in its header |
| `published_scores_2024.csv` | 466 (83, 84, 84, 85, 71 and 59 country-years between 2015 and 2020) | `code`, `country`, `income`, `financing`, `year`, `te_io_crs`, `te_oo_crs`, `te_io_vrs`, `te_oo_vrs` | efficiency scores of the source thesis (Valenzuela-Silva 2024, appendices H to K) with two decimals, plus the World Bank income group and the financing model of each country; no script generates it |
| `covid_2020_owid.csv` | 59 (the countries of the 2020 frontier) | `code`, `cases_pm`, `deaths_pm`, `r_mean`, `r_days` | Our World in Data extraction made by `R/02_download_owid.R`; Laos (`LAO`) has no reproduction-number estimate, so its `r_mean` is empty and its `r_days` is 0 |

`worldbank_2026-09-27.csv` and `published_scores_2024.csv` use CRLF line endings; `read.csv` reads them all the same.

If `R/01_download_worldbank.R` runs again, the new file lands in this folder with the day's date in its name and the snapshot is left untouched. `R/02_download_owid.R`, by contrast, overwrites `covid_2020_owid.csv`.
