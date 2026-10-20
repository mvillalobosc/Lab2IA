# data/

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene dos partes. [raw/](raw/) guarda todos los datos de entrada, versionados y en UTF-8. `processed/` no está en el repositorio: `R/00_config.R` la crea al correr y cada módulo deja ahí su resultado como `.rds` (`01_ingest.rds`, `02_clean.rds`, `03_frequency.rds`, `04_topics.rds`, `05_sentiment.rds`, `06_readability.rds` y `07_popularity.rds`), que los módulos siguientes leen con `load_step()`. El `.gitignore` de la raíz del repositorio Lab2IA ignora `processed/`, y borrarla solo obliga a volver a correr el pipeline desde el módulo 1. Vuelve al [README del proyecto](../README.md) o al [README en inglés](../README.en.md).

## English

This folder has two parts. [raw/](raw/) holds all the input data, versioned and in UTF-8. `processed/` is not in the repository: `R/00_config.R` creates it when the pipeline runs, and each module leaves its result there as an `.rds` file (`01_ingest.rds`, `02_clean.rds`, `03_frequency.rds`, `04_topics.rds`, `05_sentiment.rds`, `06_readability.rds` and `07_popularity.rds`), which the following modules read with `load_step()`. The `.gitignore` at the root of the Lab2IA repository ignores `processed/`, and deleting it only means running the pipeline again from module 1. Back to the [project README](../README.en.md).
