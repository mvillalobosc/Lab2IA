# R

[Español](#español) · [English](#english)

## Español

Scripts del análisis. Se corren desde la carpeta `PhyloOptReview_code/`, en el orden de su número, con `Rscript R/00_run_all.R`. Cada script explica en sus comentarios qué lee, qué escribe y por qué toma cada decisión. `01_merge.R` y `02_screen.R` necesitan las exportaciones de Scopus y Web of Science, que no se distribuyen; sin ellas, `00_run_all.R` los omite. `10_bib.R` no forma parte de la corrida: recibe la ruta del manuscrito (`Rscript R/10_bib.R ruta/main.tex`) y escribe `references.bib` junto a él con las claves `R#####` de la base y las referencias de contexto de `references/classics.bib`. La tabla de scripts está en el README de la carpeta principal.

## English

Analysis scripts. They run from the `PhyloOptReview_code/` folder, in the order of their number, with `Rscript R/00_run_all.R`. Each script explains in its comments what it reads, what it writes and why it takes each decision. `01_merge.R` and `02_screen.R` need the Scopus and Web of Science exports, which are not distributed; without them, `00_run_all.R` skips them. `10_bib.R` is not part of the run: it takes the path of the manuscript (`Rscript R/10_bib.R path/main.tex`) and writes `references.bib` next to it, with the `R#####` keys of the database and the background references of `references/classics.bib`. The table of scripts is in the README of the main folder.
