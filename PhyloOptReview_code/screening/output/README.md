# screening/output

[Español](#español) · [English](#english)

## Español

Una línea JSON por registro evaluado. Los lotes 01 a 17 son de la primera ronda, 18 a 30 de la segunda y 31 a 36 de la tercera (bloque Q7). Un registro excluido trae `id`, `inc` = 0 y `why` (`application`, `other_domain` o `no_method`); un registro incluido trae `inc` = 1 y los campos `type`, `cat`, `crit`, `alg`, `rep`, `ops`, `nobj`, `dsd`, `data`, `soft`, `name` y `note`, con los códigos de `../protocol/llm_prompt.txt`. `03_merge_coding.R` lee todos los archivos de esta carpeta.

## English

One JSON line per assessed record. Batches 01 to 17 belong to the first round, 18 to 30 to the second and 31 to 36 to the third (block Q7). An excluded record has `id`, `inc` = 0 and `why` (`application`, `other_domain` or `no_method`); an included record has `inc` = 1 and the fields `type`, `cat`, `crit`, `alg`, `rep`, `ops`, `nobj`, `dsd`, `data`, `soft`, `name` and `note`, with the codes of `../protocol/llm_prompt.txt`. `03_merge_coding.R` reads every file in this folder.
