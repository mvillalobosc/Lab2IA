# TE_worldwide_code/data

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene la base de datos del análisis y, en [`raw/`](raw/README.md), las tres fuentes desde las que se arma. Los cuatro archivos están versionados, así que el pipeline corre sin descargar nada. El README del proyecto es [`../README.md`](../README.md).

`dataset_country_year.csv` es la base que leen todos los pasos desde el 04. La escribe `R/03_build_dataset.R` y tiene 720 filas (120 países por los años 2015 a 2020) y 31 columnas. Los valores faltantes son celdas vacías, y el único valor imputado es el de médicos de Albania en 2018, interpolado entre 2016 y 2019. Para cualquier análisis adicional conviene partir de este archivo.

| Columna | Contenido | Fuente o rol |
|---|---|---|
| `code` | código ISO 3166-1 alfa-3 del país | |
| `country` | nombre del país | |
| `year` | año calendario, 2015 a 2020 | |
| `income` | grupo de ingreso del Banco Mundial que registra la tesis fuente: `Low`, `Lower-mid`, `Upper-mid`, `High` | |
| `financing` | modelo de financiamiento dominante del sistema de salud: `Public`, `Mixed`, `Private` (perfiles del Commonwealth Fund) | |
| `in_main_sample` | `TRUE` en los 466 país-año de las fronteras anuales del análisis principal | |
| `che_gdp` | gasto corriente en salud, % del PIB | SH.XPD.CHEX.GD.ZS, insumo de DEA |
| `phys` | médicos por 1.000 habitantes | SH.MED.PHYS.ZS, insumo de DEA |
| `phys_interpolated` | `TRUE` solo para Albania 2018, cuyo valor ya no se publica y se interpola | |
| `beds` | camas hospitalarias por 1.000 habitantes | SH.MED.BEDS.ZS, insumo de DEA |
| `le` | esperanza de vida al nacer, años | SP.DYN.LE00.IN, producto de DEA |
| `imr` | mortalidad infantil por 1.000 nacidos vivos | SP.DYN.IMRT.IN |
| `inf_surv` | supervivencia infantil, 1 / `imr` | producto de DEA |
| `che_pc_ppp` | gasto corriente en salud per cápita, dólares PPP | SH.XPD.CHEX.PP.CD, análisis de sensibilidad |
| `cbr` | tasa bruta de natalidad por 1.000 habitantes | SP.DYN.CBRT.IN, segunda etapa |
| `cdr` | tasa bruta de mortalidad por 1.000 habitantes | SP.DYN.CDRT.IN, segunda etapa |
| `gni_pc` | INB per cápita, método Atlas, USD corrientes | NY.GNP.PCAP.CD, segunda etapa |
| `lf` | fuerza de trabajo total, personas | SL.TLF.TOTL.IN, segunda etapa |
| `edu` | gasto público en educación, % del PIB | SE.XPD.TOTL.GD.ZS, segunda etapa |
| `gdp_pc` | PIB per cápita, USD corrientes | NY.GDP.PCAP.CD, segunda etapa |
| `dens` | personas por km² de superficie terrestre | EN.POP.DNST, segunda etapa |
| `rur` | población rural, % del total | SP.RUR.TOTL.ZS, segunda etapa |
| `pop` | población total | SP.POP.TOTL, solo en la Tabla S9 |
| `cases_pm` | casos confirmados de COVID-19 acumulados por millón de habitantes al 31 de diciembre de 2020 | Our World in Data, solo 2020 |
| `deaths_pm` | muertes confirmadas por COVID-19 acumuladas por millón de habitantes a esa fecha | Our World in Data, solo 2020 |
| `r_mean` | promedio diario del número reproductivo efectivo en 2020 (vacío para Laos) | Our World in Data, solo 2020 |
| `r_days` | días de 2020 con estimación del número reproductivo | Our World in Data, solo 2020 |
| `te_io_crs` | puntaje publicado orientado a insumos, retornos constantes (modelo principal, Tabla S6) | tesis fuente, dos decimales |
| `te_oo_crs` | puntaje publicado orientado a productos, retornos constantes | tesis fuente |
| `te_io_vrs` | puntaje publicado orientado a insumos, retornos variables | tesis fuente |
| `te_oo_vrs` | puntaje publicado orientado a productos, retornos variables | tesis fuente |

Los indicadores del Banco Mundial vienen de la extracción del 27 de septiembre de 2026. Las variables de la pandemia solo están llenas en 2020 y para los 59 países de la frontera de ese año. El encabezado de `R/03_build_dataset.R` tiene este mismo diccionario.

## English

This folder holds the analysis database and, in [`raw/`](raw/README.md), the three sources it is built from. Everything is tracked, so the pipeline runs without downloading anything. The project README is [`../README.md`](../README.md).

`dataset_country_year.csv` is the database that every step from 04 onwards reads. `R/03_build_dataset.R` writes it, with 720 rows (120 countries by the years 2015 to 2020) and 31 columns. Missing values are empty cells, and the only imputed value is physicians for Albania in 2018, interpolated between 2016 and 2019. Any further analysis should start from this file.

| Column | Content | Source or role |
|---|---|---|
| `code` | ISO 3166-1 alpha-3 country code | |
| `country` | country name | |
| `year` | calendar year, 2015 to 2020 | |
| `income` | World Bank income group recorded in the source thesis: `Low`, `Lower-mid`, `Upper-mid`, `High` | |
| `financing` | dominant financing model of the health system: `Public`, `Mixed`, `Private` (Commonwealth Fund profiles) | |
| `in_main_sample` | `TRUE` for the 466 country-years of the annual frontiers of the main analysis | |
| `che_gdp` | current health expenditure, % of GDP | SH.XPD.CHEX.GD.ZS, DEA input |
| `phys` | physicians per 1,000 people | SH.MED.PHYS.ZS, DEA input |
| `phys_interpolated` | `TRUE` only for Albania 2018, whose value is no longer published and is interpolated | |
| `beds` | hospital beds per 1,000 people | SH.MED.BEDS.ZS, DEA input |
| `le` | life expectancy at birth, years | SP.DYN.LE00.IN, DEA output |
| `imr` | infant mortality per 1,000 live births | SP.DYN.IMRT.IN |
| `inf_surv` | infant survival, 1 / `imr` | DEA output |
| `che_pc_ppp` | current health expenditure per capita, PPP dollars | SH.XPD.CHEX.PP.CD, sensitivity analysis |
| `cbr` | crude birth rate per 1,000 people | SP.DYN.CBRT.IN, second stage |
| `cdr` | crude death rate per 1,000 people | SP.DYN.CDRT.IN, second stage |
| `gni_pc` | GNI per capita, Atlas method, current USD | NY.GNP.PCAP.CD, second stage |
| `lf` | total labour force, persons | SL.TLF.TOTL.IN, second stage |
| `edu` | government expenditure on education, % of GDP | SE.XPD.TOTL.GD.ZS, second stage |
| `gdp_pc` | GDP per capita, current USD | NY.GDP.PCAP.CD, second stage |
| `dens` | people per km² of land area | EN.POP.DNST, second stage |
| `rur` | rural population, % of total | SP.RUR.TOTL.ZS, second stage |
| `pop` | total population | SP.POP.TOTL, Table S9 only |
| `cases_pm` | cumulative confirmed COVID-19 cases per million people at 31 December 2020 | Our World in Data, 2020 only |
| `deaths_pm` | cumulative confirmed COVID-19 deaths per million people at that date | Our World in Data, 2020 only |
| `r_mean` | mean daily effective reproduction number over 2020 (empty for Laos) | Our World in Data, 2020 only |
| `r_days` | days of 2020 with a reproduction-number estimate | Our World in Data, 2020 only |
| `te_io_crs` | published input-oriented score, constant returns to scale (main model, Table S6) | source thesis, two decimals |
| `te_oo_crs` | published output-oriented score, constant returns to scale | source thesis |
| `te_io_vrs` | published input-oriented score, variable returns to scale | source thesis |
| `te_oo_vrs` | published output-oriented score, variable returns to scale | source thesis |

The World Bank indicators come from the extraction of 27 September 2026. The pandemic variables are filled only for 2020 and for the 59 countries of that year's frontier. The header of `R/03_build_dataset.R` holds the same dictionary.
