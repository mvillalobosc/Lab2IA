# Lab2IA

[Español](#español) · [English](#english)

## Español

Lab2IA reúne aplicaciones web, pipelines de análisis y el código de artículos desarrollados en el Departamento de Ingeniería Informática (DIINF) de la Universidad de Santiago de Chile, muchos de ellos a partir de trabajos de titulación que guía Manuel Villalobos Cid. Cada carpeta de primer nivel es un proyecto independiente: trae su propio README, sus requisitos y su licencia, y se puede usar sin las demás.

### Proyectos

**Bioinformática y filogenia**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [YeastForest](YeastForest/) | Muestra los bosques filogenéticos de *S. cerevisiae* y *S. eubayanus*: un árbol por gen, el árbol de referencia, los grupos de árboles y la metadata de las cepas. | App web |
| [YeastForest_code](YeastForest_code/) | Calcula esos bosques desde un VCF, compara todos los árboles entre sí, los agrupa y produce las figuras del manuscrito. | Código R de un artículo |
| [PhyloGEOYeast](PhyloGEOYeast/) | Explora la filogeografía de *S. eubayanus* y *S. cerevisiae* (muestreo, diversidad, estructura, mezcla, árboles y validación del origen) y guarda el pipeline R que la calcula. | App web y pipeline R |
| [MOPhyloKmer](MOPhyloKmer/) | Compara NSGA-II, un recocido simulado multiobjetivo y una búsqueda aleatoria para inferir árboles filogenéticos desde distancias de k-meros. | Experimentos en R |
| [PaleoForest](PaleoForest/) | Busca árboles más parsimoniosos en matrices morfológicas TNT y explora el conjunto de topologías con clustering, medoides y escala de tiempo geológico. | App web |
| [Phyli](Phyli/) | Dibuja árboles y redes filogenéticas en el navegador a partir de Newick o Newick extendido y los exporta a SVG, PNG, Newick o JSON. | App web |

**Salud y registros clínicos**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [StrokeAccessCL](StrokeAccessCL/) | Muestra en un mapa los 93 establecimientos de Chile que atienden el ataque cerebrovascular y sus coberturas de traslado a 30, 45 y 60 minutos. | App web |
| [StrokeAccessRM](StrokeAccessRM/) | Muestra, por zona censal de la Región Metropolitana, indicadores de riesgo de ACV, el tiempo al hospital y la red de establecimientos. | App web |
| [StrokeGRDCL](StrokeGRDCL/) | Caracteriza el ACV en Chile con los egresos GRD de Fonasa de 2019 a 2024, seleccionando variables con un consenso de tres modelos de aprendizaje automático. | Pipeline R |
| [Zodiaco_grd_Code](Zodiaco_grd_Code/) | Repite un análisis ingenuo del signo zodiacal frente a los registros GRD de Fonasa y prueba si las variables que retiene predicen el signo en datos que no usó. | Pipeline R |
| [TE_worldwide_code](TE_worldwide_code/) | Estima con DEA la eficiencia técnica de los sistemas de salud de 120 países entre 2015 y 2020 y compara cómo cambia según el conjunto de referencia. | Pipeline R |

**Texto y lenguaje natural**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [BookAnalyses](BookAnalyses/) | Mide cómo cambian la legibilidad, el léxico, la sintaxis y las emociones de las lecturas sugeridas del currículum chileno entre 1° básico y 4° medio. | Pipeline R |
| [Papelucho](Papelucho/) | Compara con minería de texto los 12 libros de *Papelucho* de Marcela Paz con un corpus de 63 novelas en español. | Pipeline R |
| [PichintunNLP](PichintunNLP/) | Analiza el lenguaje de los 34 capítulos de la serie infantil *Pichintún* y los factores asociados a su recepción en YouTube. | Pipeline R |

**Redes neuronales**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [SNN_ANN_code](SNN_ANN_code/) | Reúne los datos, los protocolos y los scripts de una revisión sistemática sobre la evidencia de eficiencia energética de las redes de espigas frente a las redes artificiales. | Datos y código R de un artículo |

**Docencia y gestión académica**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [BACPPlanner](BACPPlanner/) | Genera mallas curriculares balanceadas con NSGA-II, simula el avance de una cohorte y planifica los semestres que le faltan a un estudiante. | App web |
| [ResearchAnalyser](ResearchAnalyser/) | Explora la producción científica y los trabajos de título del DIINF con catálogos, perfiles, redes de coautoría, analítica, informes y un asistente local. | App web |
| [PaleoColorCL](PaleoColorCL/) | Anima con realidad aumentada los animales prehistóricos de Chile que niñas y niños colorean en una plantilla impresa. | App web |

**Edición científica**

| Proyecto | Qué hace | Tipo |
| --- | --- | --- |
| [PDF2JATS](PDF2JATS/) | Extrae metadatos, autoría, cuerpo y referencias de artículos en PDF, los deja revisar junto al original y los exporta a XML JATS, SciELO PS o Clarivate. | Herramienta web en Python |

### Cómo abrir o correr cada proyecto

Las apps web se abren desde su `index.html`. Casi todas funcionan con doble clic, sin servidor; PaleoColorCL necesita un servidor local porque usa módulos ES y la cámara, y PDF2JATS es una app Flask que se levanta con Python. Los pipelines en R se corren desde la carpeta del proyecto con el script que indica la tabla. Cada README detalla los requisitos, los paquetes y los datos que hacen falta.

| Proyecto | Punto de entrada |
| --- | --- |
| BACPPlanner, PaleoForest, Phyli, PhyloGEOYeast, ResearchAnalyser, StrokeAccessCL, StrokeAccessRM, YeastForest | `index.html` |
| PaleoColorCL | `python -m http.server 8000` dentro de la carpeta y luego `http://localhost:8000` |
| PDF2JATS | `pip install -r requirements.txt` y `python3 app.py`, luego `http://127.0.0.1:5000` |
| BookAnalyses, Papelucho, PichintunNLP, StrokeGRDCL, TE_worldwide_code | `Rscript run_all.R` |
| MOPhyloKmer | `Rscript main.R` (un conjunto) o `Rscript run_experiments.R` (experimento completo) |
| SNN_ANN_code | `Rscript scripts/00_run_all.R` |
| Zodiaco_grd_Code | `Rscript 01_preparar_datos.R` a `Rscript 04_resultados.R`, en orden |
| YeastForest_code | Los scripts de `Bosque_cerevisiae/` y `Bosque_eubayanus/`, y después `preparar_app.R` y `figuras_MER.R` |
| PhyloGEOYeast (pipeline) | `Rscript 99_correr_todo.R` dentro de `EvolutiveEubayanus_CODE/` o `EvolutiveSCerevisiae_CODE/` |

Varios pipelines necesitan datos que no vienen en el repositorio, como los archivos GRD de Fonasa, los VCF de las levaduras, las exportaciones de Scopus y Web of Science o los textos de los libros. El README de cada proyecto dice qué datos trae, cuáles hay que conseguir y dónde dejarlos.

### Organización del repositorio

- Cada carpeta tiene un `README.md` que describe sus archivos. Las excepciones son las carpetas que el código borra y vuelve a escribir (por ejemplo `YeastForest/data/cerevisiae/` y `YeastForest/data/eubayanus/`) y las que solo guardan fuentes, íconos o capturas, que describe el README de la carpeta que las contiene.
- La documentación está en castellano y en inglés. La mayoría de los README trae los dos idiomas en el mismo archivo; Papelucho, PichintunNLP y SNN_ANN_code usan un archivo por idioma, y PaleoColorCL, PaleoForest y StrokeAccessCL agregan portugués.
- El [`.gitignore`](.gitignore) de esta carpeta ignora, proyecto por proyecto, lo que el código genera al correr y los datos que no se distribuyen. SNN_ANN_code trae además su propio `.gitignore`.
- [`claves.zip`](claves.zip) guarda, cifradas con contraseña, la clave de OpenRouteService de StrokeAccessCL y el enlace de la carpeta de Drive de BookAnalyses. La contraseña no está en el repositorio, y el `.gitignore` ignora el `claves.txt` descomprimido para que no se suba por error.
- Los nombres de las carpetas de cada proyecto se mantienen como están, porque los usan rutas del código, despliegues y publicaciones.

### Versiones publicadas

Los archivos de estos proyectos indican una versión publicada en el servidor del DIINF:

| Proyecto | Dirección |
| --- | --- |
| BACPPlanner | <https://mvillalobosc.diinf.usach.cl/BACPPlanner/> |
| PDF2JATS | <https://mvillalobosc.diinf.usach.cl/PDF2JATS/> |
| PaleoForest | <https://mvillalobosc.diinf.usach.cl/PaleoForest/> |
| Phyli | <https://mvillalobosc.diinf.usach.cl/Phyli/> |
| StrokeAccessCL | <https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/> |
| StrokeAccessRM | <https://mvillalobosc.diinf.usach.cl/StrokeAccessRM/> |
| YeastForest | <https://mvillalobosc.diinf.usach.cl/YeastForest/> |

### Licencias

No hay una licencia común: cada proyecto trae la suya.

| Licencia | Proyectos |
| --- | --- |
| MIT | BACPPlanner, BookAnalyses, MOPhyloKmer, PDF2JATS, PaleoColorCL, PaleoForest, Papelucho, PhyloGEOYeast, PichintunNLP, StrokeAccessRM, StrokeGRDCL, TE_worldwide_code, YeastForest, YeastForest_code, Zodiaco_grd_Code |
| MIT para el código y CC BY 4.0 para los datos y protocolos | SNN_ANN_code |
| CC BY-SA 4.0 | Phyli |
| Licencia académica propia: permite revisión académica, docencia y reproducibilidad con atribución, y pide permiso para reutilizar o redistribuir | StrokeAccessCL |
| Todos los derechos reservados | ResearchAnalyser |

Salvo en SNN_ANN_code, que también licencia sus datos y protocolos, las licencias cubren el código. Los datos, los logos institucionales y las librerías de terceros que trae cada proyecto conservan sus propios términos, que explican su README y su archivo de licencia.

### Cómo citar

Cada README trae la referencia de su trabajo asociado (artículo, manuscrito, memoria o trabajo de titulación) tal como aparece en sus archivos. BACPPlanner, PDF2JATS, PaleoColorCL, Phyli, PichintunNLP, ResearchAnalyser, StrokeAccessCL, StrokeAccessRM y StrokeGRDCL traen además un `CITATION.cff` en su carpeta. GitHub solo muestra el botón "Cite this repository" cuando el archivo está en la raíz, así que en este repositorio hay que usar el de cada proyecto.

Estos son los trabajos publicados con DOI:

- PaleoForest: Concha-Toro, C., Riquelme-Zamora, C., Aranciaga-Rolando, M., & Villalobos-Cid, M. (2026). *Exploring topological landscapes in morphological phylogenetics using clustering and medoid selection: case studies from Chilean fossil taxa*. Organisms Diversity & Evolution. <https://doi.org/10.1007/s13127-026-00702-8>
- ResearchAnalyser: Villalobos-Cid, M., Cabezas-Carvajal, P., Ilabaca, C., & Chourio-Acevedo, L. (2025). *A Web-Based Tool to Explore Research Production Focused on Student Engagement*. 2025 44th International Conference of the Chilean Computer Science Society (SCCC), pp. 1-8. <https://doi.org/10.1109/SCCC67219.2025.11420777>
- StrokeAccessRM: Garrido-Delgado, D., Lillo-Vidal, J., Escudero-Bell, M., Hurtado-Meneses, V., & Villalobos-Cid, M. (2025). *Spatiotemporal characterisation of stroke care accessibility and hospital coverage in the Santiago Metropolitan Region*. 2025 21st International Symposium on Biomedical Image Processing and Analysis (SIPAIM), pp. 1-5. <https://doi.org/10.1109/SIPAIM67325.2025.11283388>

### Contacto

Manuel Villalobos Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile: manuel.villalobos@usach.cl.

## English

Lab2IA gathers web applications, analysis pipelines and the code of papers developed at the Department of Informatics Engineering (DIINF) of the Universidad de Santiago de Chile, many of them from student theses and final projects supervised by Manuel Villalobos Cid. Each top-level folder is an independent project: it has its own README, requirements and licence, and it can be used without the others.

### Projects

**Bioinformatics and phylogenetics**

| Project | What it does | Type |
| --- | --- | --- |
| [YeastForest](YeastForest/) | Displays the phylogenetic forests of *S. cerevisiae* and *S. eubayanus*: one tree per gene, the reference tree, the groups of trees and the strain metadata. | Web app |
| [YeastForest_code](YeastForest_code/) | Computes those forests from a VCF, compares every tree with every other, groups them and produces the figures of the manuscript. | R code of a paper |
| [PhyloGEOYeast](PhyloGEOYeast/) | Explores the phylogeography of *S. eubayanus* and *S. cerevisiae* (sampling, diversity, structure, admixture, trees and validation of the origin) and keeps the R pipeline that computes it. | Web app and R pipeline |
| [MOPhyloKmer](MOPhyloKmer/) | Compares NSGA-II, a multi-objective simulated annealing and a random search for inferring phylogenetic trees from k-mer distances. | R experiments |
| [PaleoForest](PaleoForest/) | Searches for most parsimonious trees in TNT morphological matrices and explores the set of topologies with clustering, medoids and a geological time scale. | Web app |
| [Phyli](Phyli/) | Draws phylogenetic trees and networks in the browser from Newick or extended Newick and exports them to SVG, PNG, Newick or JSON. | Web app |

**Health and clinical records**

| Project | What it does | Type |
| --- | --- | --- |
| [StrokeAccessCL](StrokeAccessCL/) | Maps the 93 facilities in Chile that treat stroke and their 30, 45 and 60 minute travel coverage. | Web app |
| [StrokeAccessRM](StrokeAccessRM/) | Shows, for each census zone of the Santiago Metropolitan Region, stroke risk indicators, the travel time to hospital and the network of facilities. | Web app |
| [StrokeGRDCL](StrokeGRDCL/) | Characterises stroke in Chile with the FONASA DRG discharge records from 2019 to 2024, selecting variables through a consensus of three machine learning models. | R pipeline |
| [Zodiaco_grd_Code](Zodiaco_grd_Code/) | Repeats a naive analysis of zodiac sign against the FONASA DRG records and tests whether the variables it keeps predict the sign on data it did not use. | R pipeline |
| [TE_worldwide_code](TE_worldwide_code/) | Estimates with DEA the technical efficiency of the health systems of 120 countries from 2015 to 2020 and compares how it changes with the reference set. | R pipeline |

**Text and natural language**

| Project | What it does | Type |
| --- | --- | --- |
| [BookAnalyses](BookAnalyses/) | Measures how readability, vocabulary, syntax and emotions change across the suggested readings of the Chilean school curriculum, from grade 1 to the last year of secondary school. | R pipeline |
| [Papelucho](Papelucho/) | Compares, with text mining, the 12 *Papelucho* books by Marcela Paz against a corpus of 63 Spanish-language novels. | R pipeline |
| [PichintunNLP](PichintunNLP/) | Analyses the language of the 34 episodes of the children's series *Pichintún* and the factors associated with its reception on YouTube. | R pipeline |

**Neural networks**

| Project | What it does | Type |
| --- | --- | --- |
| [SNN_ANN_code](SNN_ANN_code/) | Gathers the data, protocols and scripts of a systematic review of the energy-efficiency evidence for spiking versus artificial neural networks. | Data and R code of a paper |

**Teaching and academic management**

| Project | What it does | Type |
| --- | --- | --- |
| [BACPPlanner](BACPPlanner/) | Builds balanced curricula with NSGA-II, simulates the progress of a cohort and plans the semesters a student still has to take. | Web app |
| [ResearchAnalyser](ResearchAnalyser/) | Explores the research output and the final projects of DIINF with catalogues, profiles, co-authorship networks, analytics, reports and a local assistant. | Web app |
| [PaleoColorCL](PaleoColorCL/) | Uses augmented reality to animate the prehistoric animals of Chile that children colour on a printed template. | Web app |

**Scholarly publishing**

| Project | What it does | Type |
| --- | --- | --- |
| [PDF2JATS](PDF2JATS/) | Extracts metadata, authorship, body and references from PDF articles, lets an editor review them next to the original and exports JATS, SciELO PS or Clarivate XML. | Python web tool |

### How to open or run each project

The web apps open from their `index.html`. Almost all of them work with a double click, without a server; PaleoColorCL needs a local server because it uses ES modules and the camera, and PDF2JATS is a Flask app started with Python. The R pipelines run from the project folder with the script given in the table. Each README lists the requirements, packages and data needed.

| Project | Entry point |
| --- | --- |
| BACPPlanner, PaleoForest, Phyli, PhyloGEOYeast, ResearchAnalyser, StrokeAccessCL, StrokeAccessRM, YeastForest | `index.html` |
| PaleoColorCL | `python -m http.server 8000` inside the folder, then `http://localhost:8000` |
| PDF2JATS | `pip install -r requirements.txt` and `python3 app.py`, then `http://127.0.0.1:5000` |
| BookAnalyses, Papelucho, PichintunNLP, StrokeGRDCL, TE_worldwide_code | `Rscript run_all.R` |
| MOPhyloKmer | `Rscript main.R` (one dataset) or `Rscript run_experiments.R` (full experiment) |
| SNN_ANN_code | `Rscript scripts/00_run_all.R` |
| Zodiaco_grd_Code | `Rscript 01_preparar_datos.R` to `Rscript 04_resultados.R`, in order |
| YeastForest_code | The scripts in `Bosque_cerevisiae/` and `Bosque_eubayanus/`, then `preparar_app.R` and `figuras_MER.R` |
| PhyloGEOYeast (pipeline) | `Rscript 99_correr_todo.R` inside `EvolutiveEubayanus_CODE/` or `EvolutiveSCerevisiae_CODE/` |

Several pipelines need data that are not in the repository, such as the FONASA DRG files, the yeast VCF files, the Scopus and Web of Science exports or the book texts. Each project README says which data it includes, which ones have to be obtained and where to put them.

### Repository layout

- Each folder has a `README.md` that describes its files. The exceptions are the folders that the code deletes and writes again (for example `YeastForest/data/cerevisiae/` and `YeastForest/data/eubayanus/`) and the ones that only hold fonts, icons or screenshots, which the README of the enclosing folder describes.
- The documentation is in Spanish and English. Most READMEs carry both languages in the same file; Papelucho, PichintunNLP and SNN_ANN_code use one file per language, and PaleoColorCL, PaleoForest and StrokeAccessCL add Portuguese.
- The [`.gitignore`](.gitignore) in this folder ignores, project by project, what the code generates when it runs and the data that are not distributed. SNN_ANN_code also has its own `.gitignore`.
- [`claves.zip`](claves.zip) holds, password-protected, the OpenRouteService key of StrokeAccessCL and the link to the BookAnalyses Drive folder. The password is not in the repository, and the `.gitignore` ignores the unpacked `claves.txt` so it is not committed by mistake.
- The folder names of each project stay as they are, because code paths, deployments and publications use them.

### Published versions

The files of these projects point to a version published on the DIINF server:

| Project | Address |
| --- | --- |
| BACPPlanner | <https://mvillalobosc.diinf.usach.cl/BACPPlanner/> |
| PDF2JATS | <https://mvillalobosc.diinf.usach.cl/PDF2JATS/> |
| PaleoForest | <https://mvillalobosc.diinf.usach.cl/PaleoForest/> |
| Phyli | <https://mvillalobosc.diinf.usach.cl/Phyli/> |
| StrokeAccessCL | <https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/> |
| StrokeAccessRM | <https://mvillalobosc.diinf.usach.cl/StrokeAccessRM/> |
| YeastForest | <https://mvillalobosc.diinf.usach.cl/YeastForest/> |

### Licences

There is no common licence: each project carries its own.

| Licence | Projects |
| --- | --- |
| MIT | BACPPlanner, BookAnalyses, MOPhyloKmer, PDF2JATS, PaleoColorCL, PaleoForest, Papelucho, PhyloGEOYeast, PichintunNLP, StrokeAccessRM, StrokeGRDCL, TE_worldwide_code, YeastForest, YeastForest_code, Zodiaco_grd_Code |
| MIT for the code and CC BY 4.0 for the data and protocols | SNN_ANN_code |
| CC BY-SA 4.0 | Phyli |
| Own academic licence: it allows academic review, teaching and reproducibility with attribution, and asks for permission to reuse or redistribute | StrokeAccessCL |
| All rights reserved | ResearchAnalyser |

Except in SNN_ANN_code, which also licenses its data and protocols, the licences cover the code. The data, institutional logos and third-party libraries shipped with each project keep their own terms, which its README and its licence file explain.

### How to cite

Each README gives the reference of its associated work (paper, manuscript, thesis or final project) as it appears in its files. BACPPlanner, PDF2JATS, PaleoColorCL, Phyli, PichintunNLP, ResearchAnalyser, StrokeAccessCL, StrokeAccessRM and StrokeGRDCL also carry a `CITATION.cff` in their folder. GitHub only shows the "Cite this repository" button when that file sits at the root, so in this repository you need the one in each project.

These are the published works with a DOI:

- PaleoForest: Concha-Toro, C., Riquelme-Zamora, C., Aranciaga-Rolando, M., & Villalobos-Cid, M. (2026). *Exploring topological landscapes in morphological phylogenetics using clustering and medoid selection: case studies from Chilean fossil taxa*. Organisms Diversity & Evolution. <https://doi.org/10.1007/s13127-026-00702-8>
- ResearchAnalyser: Villalobos-Cid, M., Cabezas-Carvajal, P., Ilabaca, C., & Chourio-Acevedo, L. (2025). *A Web-Based Tool to Explore Research Production Focused on Student Engagement*. 2025 44th International Conference of the Chilean Computer Science Society (SCCC), pp. 1-8. <https://doi.org/10.1109/SCCC67219.2025.11420777>
- StrokeAccessRM: Garrido-Delgado, D., Lillo-Vidal, J., Escudero-Bell, M., Hurtado-Meneses, V., & Villalobos-Cid, M. (2025). *Spatiotemporal characterisation of stroke care accessibility and hospital coverage in the Santiago Metropolitan Region*. 2025 21st International Symposium on Biomedical Image Processing and Analysis (SIPAIM), pp. 1-5. <https://doi.org/10.1109/SIPAIM67325.2025.11283388>

### Contact

Manuel Villalobos Cid, Department of Informatics Engineering, Universidad de Santiago de Chile: manuel.villalobos@usach.cl.
