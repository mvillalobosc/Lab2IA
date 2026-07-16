/* ============================================================================
 * PaleoForest — capa de aplicación (render + interacción + usabilidad)
 * Reimplementación web del pipeline de Concha-Toro et al. (2026).
 * Sin backend: el cálculo corre en el navegador. Trilingüe (ES/EN/PT).
 * ==========================================================================*/
(function () {
  'use strict';

  /* ======================================================================
   * 1. i18n suplementario — usabilidad, ayudas contextuales y glosario
   * ==================================================================== */
  const UX = {
    es: {
      swipe: "Desliza para ver el árbol completo",
      help: "Ayuda", tour_start: "Ver guía", tour_hint: "Recorrido guiado en el idioma seleccionado", glossary: "Glosario", shortcuts: "Atajos",
      close: "Cerrar", skip: "Saltar guía", next: "Siguiente", prev: "Anterior", done: "Entendido",
      nav_prev: "Anterior", nav_next: "Siguiente paso",
      run_first: "Ejecuta el análisis para desbloquear este paso.",
      run_now: "Ejecutar ahora", locked: "Requiere análisis",
      computing: "Calculando el pipeline…", compute_done: "Análisis completo",
      c_rf: "Distancias Robinson–Foulds", c_mds: "Escalamiento MDS",
      c_clu: "Agrupamiento e índices", c_hv: "Selección por hipervolumen",
      c_med: "Medoides y soporte nodal",
      export: "Exportar", export_csv: "Descargar CSV", export_svg: "Descargar SVG",
      export_png: "Descargar PNG", export_nwk: "Descargar Newick",
      copy_cite: "Copiar cita", copy_bibtex: "Copiar BibTeX",
      copied: "Copiado al portapapeles", downloaded: "Archivo descargado",
      reorder: "Ordenar por clúster", reorder_off: "Orden original",
      search_taxon: "Buscar taxón…", zoom: "Zoom", fit: "Ajustar", reset_view: "Reiniciar vista",
      no_match: "Sin coincidencias",
      tip_cell: "Distancia RF", tip_tree: "Árbol", tip_vs: "vs",
      tip_node: "Nodo interno", tip_support: "Soporte", tip_taxa: "taxones",
      tip_range: "Rango fósil", tip_period: "Período", tip_diet: "Dieta",
      show_medoid: "Ver en «Árbol medoide»",
      empty_noage_h: "Sin temporalidad disponible",
      onboard_h: "Bienvenido a PaleoForest",
      onboard_p: "Una guía rápida de 6 pasos para recorrer el pipeline: de las topologías al árbol representativo escalado en el tiempo.",
      onboard_go: "Comenzar guía", onboard_no: "Explorar por mi cuenta",
      progress: "Progreso del análisis", clusters: "clústeres", clu_lbl: "Clúster", med_lbl: "medoide",
      diet_herbivore: "herbívoro", diet_carnivore: "carnívoro", diet_omnivore: "omnívoro",
      kbd_help: "Atajos de teclado",
      kbd: [
        ["← / →", "Paso anterior / siguiente"],
        ["1 … 9", "Ir a un paso"],
        ["G", "Abrir glosario"],
        ["?", "Mostrar atajos"],
        ["Esc", "Cerrar ventanas"]
      ],
      tour: [
        ["Nueve pasos, un pipeline", "La barra superior es tu mapa. Cada pestaña es una etapa del método; avanza con los botones inferiores o con las flechas del teclado."],
        ["Los datos ya están cargados", "El ejemplo Arackar licanantay está listo. Aquí también puedes cargar tus propios árboles TNT, la matriz de caracteres y, si las tienes, edades fósiles."],
        ["Edades: PaleoDB o a mano", "Si a un taxón le falta el rango fósil, se consulta la Paleobiology Database con un clic. Lo que quede ambiguo o sin resultado lo escribes tú en la tabla."],
        ["Tú eliges el análisis", "Métodos de agrupamiento y rango de k. El cálculo ocurre en tu navegador: no hay backend que espere resultados."],
        ["Agrupar para decidir", "«Agrupamiento» no es adorno: el hipervolumen elige el par método–k sobre cuatro objetivos, y de esa partición salen los medoides de clúster. Aquí se decide todo lo que viene después."],
        ["El paisaje, ya explicado", "«Bosque» proyecta la matriz RF en 2D con MDS: cada punto es un árbol completo. Los colores no los inventa el gráfico, vienen del agrupamiento del paso anterior."],
        ["¿Perdido? Pregunta", "Cualquier símbolo «?» abre una explicación en lenguaje llano. La tecla G abre el glosario completo cuando lo necesites."]
      ],
      gloss: {
        icons: ["Iconos de clado", "Cada hoja lleva la silueta de su clado. Sale del <b>linaje</b> de la Paleobiology Database, y esa es una consulta <b>distinta</b> a la de las edades: las edades vienen de <span class='mono'>occs/taxa</span>, el linaje de <span class='mono'>taxa/list</span> con <span class='mono'>rel=all_parents</span>. Hacen falta las dos porque saurópodo o terópodo no son rangos linneanos sino clados: <span class='mono'>classext</span> devuelve «Reptilia» y «Saurischia», y con eso no se distingue un saurópodo de un terópodo.<br><br>La <b>huella</b> es para los que PaleoDB no conoce: va más tenue porque no es un clado, es un «no sabemos».<br><br>Al escribir en el buscador, el icono del taxón que coincide pasa a naranjo."],
        tscale: ["Escalamiento temporal", "Los árboles de parsimonia no traen tiempo: sólo topología. Escalar es ponerle edad a cada nodo usando los FAD/LAD de los taxones. Los cinco métodos son los de <span class='mono'>timePaleoPhy</span> (paleotree, Bapst 2012) y no son intercambiables: cambian dónde queda cada ancestro.<br><br><b>basic</b> — cada nodo va al FAD del descendiente más antiguo. Deja ramas de largo cero donde el ancestro aparece a la vez que su descendiente. No usa vartime.<br><b>equal</b> — reparte por igual el tiempo de la rama positiva más cercana entre las ramas de largo cero (Brusatte et al. 2008). vartime es el tiempo que se le agrega a la raíz para tener de dónde repartir.<br><b>aba</b> — suma vartime a TODAS las ramas. El propio paleotree advierte que deforma el árbol: los tips pueden quedar fuera de orden respecto de los FAD.<br><b>zlba</b> — suma vartime sólo a las ramas de largo cero.<br><b>mbl</b> — ninguna rama mide menos que vartime; las cortas empujan al ancestro hacia atrás, en cascada (Laurin 2004).<br><br><b>vartime</b> es la variable de tiempo en Ma que usan los cuatro últimos. No sale de los datos: la eliges tú."],
        rf: ["Distancia Robinson–Foulds (RF)", "Cuenta cuántas particiones (clados) difieren entre dos árboles. Normalizada a [0,1]: 0 = topologías idénticas, valores altos = muy distintas."],
        proj: ["PCA vs. MDS", "Dos formas distintas de aplastar la matriz RF a 2D. PCA trata cada fila como un vector de variables y busca las direcciones de mayor varianza; MDS busca posiciones que respeten las distancias RF. El pipeline original en R usa PCA (vía fviz_cluster). Los clústeres son los mismos en ambas: solo cambia dónde caen los puntos."],
                mds: ["MDS (escalamiento multidimensional)", "Proyecta la matriz de distancias a 2D conservando las cercanías. Puntos próximos = árboles parecidos. Es un mapa del «paisaje» de topologías."],
        pam: ["PAM (k-medoides)", "Agrupa usando árboles reales como centros (medoides). Robusto y trabaja directamente sobre la matriz de distancias RF."],
        kmeans: ["k-medias", "Agrupa sobre las coordenadas MDS minimizando la distancia a centroides. Rápido, pero los centros son puntos abstractos, no árboles."],
        fanny: ["FANNY (agrupamiento difuso)", "Cada árbol recibe un grado de pertenencia a cada grupo en vez de una asignación tajante; al final se queda con el grupo de mayor pertenencia. Con memb.exp = 1.1 el resultado es casi duro, pero la fase difusa le permite acomodar árboles fronterizos."],
        clara: ["CLARA", "PAM aplicado sobre varias muestras del conjunto en vez de sobre todo: elige los medoides en la muestra y asigna el resto al más cercano. Pensado para conjuntos grandes."],
        som: ["SOM (mapas autoorganizados)", "Una grilla de neuronas que se acomoda a los datos; cada árbol cae en la neurona que más se le parece. Los grupos son las neuronas que quedaron ocupadas, así que k no se fija: sale del entrenamiento."],
        dbscan: ["DBSCAN", "Agrupa por densidad: junta lo que está apretado y deja como ruido lo aislado. No se le pide k, pero sí un radio (eps), que aquí se toma del codo de la curva de distancias al 4.º vecino."],
        mstknn: ["MST-kNN", "Construye el árbol de expansión mínima y el grafo de k vecinos más cercanos, y se queda con las aristas que están en ambos. Los grupos son las componentes que quedan; k sale solo."],
        dunn: ["Índice de Dunn", "Razón entre la menor separación entre clústeres y el mayor diámetro interno. Más alto es mejor: grupos compactos y bien separados."],
        conn: ["Connectivity", "Penaliza cuando vecinos cercanos caen en clústeres distintos. Más bajo es mejor: agrupamientos coherentes con la vecindad local."],
        sil: ["Silhouette", "Para cada árbol compara su cohesión interna con la separación al clúster vecino, en [-1,1]. Más alto es mejor."],
        hv: ["Hipervolumen (ConHyp)", "Integra los cuatro objetivos (min k, max Dunn, min Connectivity, max Silhouette) en un solo número. La combinación método–k con mayor hipervolumen es la elegida."],
        medoid: ["Medoide", "El elemento más central de un grupo: el árbol cuya distancia promedio al resto es mínima. A diferencia del consenso, no es un resumen: es uno de los árboles originales, con todos sus nodos resueltos."],
        support: ["Soporte de nodo", "Frecuencia con que un clado (bipartición) reaparece entre todos los árboles más parsimoniosos. 1 = presente en todos; valores bajos = clado inestable."],
        parsimony: ["Árboles más parsimoniosos", "Los que explican los datos con el menor número de cambios morfológicos. Suele haber muchos empatados en el óptimo."],
        consensus: ["Consenso y politomía", "Un árbol de consenso resume el acuerdo entre topologías, pero colapsa los conflictos en politomías: nodos sin resolver, que ninguno de los árboles originales tenía."],
        matrix: ["Matriz de caracteres", "La tabla de la que sale todo: una fila por taxón, una columna por carácter, y en cada celda el estado observado (0, 1, 2…), «?» si no se sabe y «−» si no aplica. Los árboles no la contienen: la parsimonia se calcula cruzando árbol y matriz. Cambiar de matriz cambia el puntaje aunque los árboles sean los mismos."],
                base: ["Numeración de caracteres (base 0 o 1)", "TNT numera los caracteres desde 0: el primero es el carácter 0. Los papers casi siempre los numeran desde 1. Un carácter de diferencia parece trivial, pero desplaza toda la lista y cambia el puntaje. Es exactamente el error que trae el ccode de este archivo: la mitad convertida a base 0 y la mitad no."],
        gap: ["Vacíos «-» y faltantes «?»", "«?» significa «no se sabe»: el carácter puede tener cualquier estado y no cuesta pasos. El «-» es ambiguo por convención: unos lo leen como faltante (no se pudo observar) y otros como un estado propio (la estructura no existe, que es información real). La decisión cambia el puntaje: en Arackar, tratarlos como estado propio rompe la consistencia entre árboles."],
        weight: ["Peso de un carácter", "Multiplica los pasos de ese carácter. Peso 3 significa que cada cambio cuenta triple, así que el árbol evitará contradecirlo. Sirve para dar menos voz a caracteres homoplásicos. Por defecto todos pesan 1."],
        active: ["Carácter activo o desactivado", "Un carácter desactivado no aporta pasos: queda fuera del cálculo, como si no estuviera en la matriz. Se usa para excluir caracteres poco fiables sin borrarlos del archivo."],
        ccode: ["ccode (ajuste de caracteres)", "El comando de TNT que declara cómo se trata cada carácter: «+» aditivo, «−» no aditivo, «[» y «]» activar o desactivar, «/N» peso. No es un detalle técnico: es una decisión del investigador que cambia el puntaje y puede cambiar qué árboles son óptimos."],
                ordered: ["Caracteres aditivos (ordenados)", "Un carácter aditivo asume que los estados están en una serie: pasar de 0 a 2 cuesta 2, no 1. Se cuentan con Wagner. Los no aditivos cobran 1 paso por cambio (Fitch). Cuáles son aditivos lo decide quien arma la matriz, y cambia el puntaje final."],
                fad: ["FAD y LAD", "FAD (First Appearance Datum) es la aparición más antigua del taxón en el registro fósil; LAD (Last Appearance Datum), la más reciente. Juntos definen la barra de rango fósil."],
        geoscale: ["Escala cronoestratigráfica", "La jerarquía oficial del tiempo geológico (ICS/IUGS): eón → era → período → época → piso. Cada nivel es una lectura distinta del mismo eje temporal, de lo más grueso a lo más fino."],
        clade: ["Clado / bipartición", "Un grupo de taxones que descienden de un mismo ancestro. En un árbol equivale a una bipartición: la división que produce una rama interna."]
      }
    },
    en: {
      swipe: "Swipe to see the whole tree",
      help: "Help", tour_start: "Take the tour", tour_hint: "Guided walkthrough in the selected language", glossary: "Glossary", shortcuts: "Shortcuts",
      close: "Close", skip: "Skip tour", next: "Next", prev: "Back", done: "Got it",
      nav_prev: "Previous", nav_next: "Next step",
      run_first: "Run the analysis to unlock this step.",
      run_now: "Run now", locked: "Needs analysis",
      computing: "Computing the pipeline…", compute_done: "Analysis complete",
      c_rf: "Robinson–Foulds distances", c_mds: "MDS scaling",
      c_clu: "Clustering & indices", c_hv: "Hypervolume selection",
      c_med: "Medoids & node support",
      export: "Export", export_csv: "Download CSV", export_svg: "Download SVG",
      export_png: "Download PNG", export_nwk: "Download Newick",
      copy_cite: "Copy citation", copy_bibtex: "Copy BibTeX",
      copied: "Copied to clipboard", downloaded: "File downloaded",
      reorder: "Order by cluster", reorder_off: "Original order",
      search_taxon: "Find taxon…", zoom: "Zoom", fit: "Fit", reset_view: "Reset view",
      no_match: "No matches",
      tip_cell: "RF distance", tip_tree: "Tree", tip_vs: "vs",
      tip_node: "Internal node", tip_support: "Support", tip_taxa: "taxa",
      tip_range: "Fossil range", tip_period: "Period", tip_diet: "Diet",
      show_medoid: "Show in “Medoid tree”",
      empty_noage_h: "No temporality available",
      onboard_h: "Welcome to PaleoForest",
      onboard_p: "A quick 6-step tour through the pipeline: from the topology landscape to the representative tree scaled in time.",
      onboard_go: "Start tour", onboard_no: "Explore on my own",
      progress: "Analysis progress", clusters: "clusters", clu_lbl: "Cluster", med_lbl: "medoid",
      diet_herbivore: "herbivore", diet_carnivore: "carnivore", diet_omnivore: "omnivore",
      kbd_help: "Keyboard shortcuts",
      kbd: [
        ["← / →", "Previous / next step"],
        ["1 … 9", "Jump to a step"],
        ["G", "Open glossary"],
        ["?", "Show shortcuts"],
        ["Esc", "Close overlays"]
      ],
      tour: [
        ["Nine steps, one pipeline", "The top bar is your map. Each tab is a stage of the method; move with the buttons below or the keyboard arrows."],
        ["Data is already loaded", "The Arackar licanantay example is ready. You can also load your own TNT trees, character matrix and, if you have them, fossil ages."],
        ["Ages: PaleoDB or by hand", "If a taxon is missing its fossil range, the Paleobiology Database is one click away. Anything ambiguous or not found, you type into the table."],
        ["You choose the analysis", "Clustering methods and the k range. Computation runs in your browser: there is no backend waiting on results."],
        ["Cluster to decide", "“Clustering” is not decoration: the hypervolume picks the method–k pair over four objectives, and that partition yields the cluster medoids. Everything downstream is decided here."],
        ["The landscape, already explained", "“Forest” projects the RF matrix into 2D with MDS: each point is a whole tree. The colours are not invented by the plot, they come from the previous clustering."],
        ["Lost? Just ask", "Any “?” symbol opens a plain-language explanation. Press G for the full glossary whenever you need it."]
      ],
      gloss: {
        icons: ["Clade icons", "Each tip carries its clade's silhouette. It comes from the Paleobiology Database <b>lineage</b>, and that is a <b>different</b> query from the ages one: ages come from <span class='mono'>occs/taxa</span>, the lineage from <span class='mono'>taxa/list</span> with <span class='mono'>rel=all_parents</span>. Both are needed because sauropod or theropod are not Linnean ranks but clades: <span class='mono'>classext</span> returns «Reptilia» and «Saurischia», and that does not tell a sauropod from a theropod.<br><br>The <b>footprint</b> is for those PaleoDB does not know: it is fainter because it is not a clade, it is an «unknown».<br><br>Typing in the search box turns the matching taxon's icon orange."],
        tscale: ["Time-scaling", "Parsimony trees carry no time: only topology. Scaling means giving each node an age using the taxa’s FADs/LADs. The five methods are those of <span class='mono'>timePaleoPhy</span> (paleotree, Bapst 2012) and they are not interchangeable: they change where each ancestor lands.<br><br><b>basic</b> — each node goes to the FAD of its oldest descendant. Leaves zero-length branches where the ancestor appears at the same time as its descendant. Does not use vartime.<br><b>equal</b> — shares the nearest positive branch’s time equally among the zero-length branches (Brusatte et al. 2008). vartime is the time added to the root so there is something to share.<br><b>aba</b> — adds vartime to EVERY branch. paleotree itself warns that it warps the tree: tips can end up out of order with the FADs.<br><b>zlba</b> — adds vartime only to zero-length branches.<br><b>mbl</b> — no branch is shorter than vartime; short ones push the ancestor back, cascading (Laurin 2004).<br><br><b>vartime</b> is the time variable in Ma used by the last four. It does not come from the data: you choose it."],
        rf: ["Robinson–Foulds (RF) distance", "Counts how many partitions (clades) differ between two trees. Normalized to [0,1]: 0 = identical topologies, high = very different."],
        proj: ["PCA vs. MDS", "Two different ways of flattening the RF matrix to 2D. PCA treats each row as a vector of variables and finds the directions of greatest variance; MDS finds positions that respect the RF distances. The original R pipeline uses PCA (via fviz_cluster). The clusters are the same in both: only where the points land changes."],
                mds: ["MDS (multidimensional scaling)", "Projects the distance matrix to 2D preserving closeness. Nearby points = similar trees. It is a map of the topology landscape."],
        pam: ["PAM (k-medoids)", "Clusters using real trees as centers (medoids). Robust and works directly on the RF distance matrix."],
        kmeans: ["k-means", "Clusters on the MDS coordinates minimizing distance to centroids. Fast, but centers are abstract points, not trees."],
        fanny: ["FANNY (fuzzy clustering)", "Each tree gets a degree of membership in every group instead of a hard assignment; the final label is the group with the highest membership. With memb.exp = 1.1 the result is nearly hard, but the fuzzy phase lets it accommodate borderline trees."],
        clara: ["CLARA", "PAM applied to several samples of the set rather than the whole: it picks medoids within the sample and assigns the rest to the nearest one. Built for large sets."],
        som: ["SOM (self-organising maps)", "A grid of neurons that adapts to the data; each tree lands on the neuron it resembles most. The clusters are the occupied neurons, so k is not fixed: it comes out of training."],
        dbscan: ["DBSCAN", "Density-based: it joins what is tightly packed and leaves isolated points as noise. It needs no k, but it does need a radius (eps), taken here from the knee of the 4th-nearest-neighbour distance curve."],
        mstknn: ["MST-kNN", "Builds the minimum spanning tree and the k-nearest-neighbour graph, and keeps the edges present in both. The clusters are the resulting components; k emerges on its own."],
        dunn: ["Dunn index", "Ratio of the smallest between-cluster separation to the largest within-cluster diameter. Higher is better: compact, well-separated groups."],
        conn: ["Connectivity", "Penalizes near neighbours landing in different clusters. Lower is better: groupings consistent with local neighbourhood."],
        sil: ["Silhouette", "For each tree compares within-cluster cohesion to separation from the neighbouring cluster, in [-1,1]. Higher is better."],
        hv: ["Hypervolume (ConHyp)", "Integrates the four objectives (min k, max Dunn, min Connectivity, max Silhouette) into one number. The method–k with the largest hypervolume is chosen."],
        medoid: ["Medoid", "The most central member of a group: the tree with minimal average distance to the rest. Unlike a consensus, it is not a summary: it is one of the original trees, with every node resolved."],
        support: ["Node support", "How often a clade (bipartition) recurs across all most-parsimonious trees. 1 = present in all; low values = unstable clade."],
        parsimony: ["Most-parsimonious trees", "Those explaining the data with the fewest morphological changes. Many usually tie at the optimum."],
        consensus: ["Consensus & polytomy", "A consensus tree summarizes agreement between topologies, but collapses conflicts into polytomies: unresolved nodes that none of the original trees had."],
        matrix: ["Character matrix", "The table everything comes from: one row per taxon, one column per character, and in each cell the observed state (0, 1, 2…), “?” if unknown and “−” if not applicable. Trees do not contain it: parsimony is computed by crossing tree and matrix. Changing matrix changes the score even if the trees are the same."],
                base: ["Character numbering (base 0 or 1)", "TNT numbers characters from 0: the first one is character 0. Papers almost always number from 1. One character of difference looks trivial, but it shifts the whole list and changes the score. It is exactly the bug in this file's ccode: half converted to base 0, half not."],
        gap: ["Gaps “-” and missing “?”", "“?” means “unknown”: the character may take any state and costs no steps. “-” is ambiguous by convention: some read it as missing (could not be observed), others as its own state (the structure does not exist, which is real information). The choice changes the score: on Arackar, treating them as their own state breaks consistency across trees."],
        weight: ["Character weight", "Multiplies that character's steps. Weight 3 means each change counts triple, so the tree will avoid contradicting it. Used to give homoplastic characters less say. By default everything weighs 1."],
        active: ["Active or deactivated character", "A deactivated character contributes no steps: it is left out of the computation, as if it were not in the matrix. Used to exclude unreliable characters without deleting them from the file."],
        ccode: ["ccode (character settings)", "The TNT command that declares how each character is treated: “+” additive, “−” non-additive, “[” and “]” activate or deactivate, “/N” weight. Not a technical detail: it is a researcher's decision that changes the score and can change which trees are optimal."],
                ordered: ["Additive (ordered) characters", "An additive character assumes states form a series: going from 0 to 2 costs 2, not 1. These are counted with Wagner. Non-additive ones charge 1 step per change (Fitch). Which are additive is decided by whoever builds the matrix, and it changes the final score."],
                fad: ["FAD and LAD", "FAD (First Appearance Datum) is the taxon's oldest occurrence in the fossil record; LAD (Last Appearance Datum), the youngest. Together they define the fossil range bar."],
        geoscale: ["Chronostratigraphic chart", "The official hierarchy of geological time (ICS/IUGS): eon → era → period → epoch → stage. Each level is a different reading of the same time axis, from coarsest to finest."],
        clade: ["Clade / bipartition", "A group of taxa descending from a common ancestor. On a tree it is a bipartition: the split produced by an internal branch."]
      }
    },
    pt: {
      swipe: "Deslize para ver a árvore completa",
      help: "Ajuda", tour_start: "Ver guia", tour_hint: "Percurso guiado no idioma selecionado", glossary: "Glossário", shortcuts: "Atalhos",
      close: "Fechar", skip: "Pular guia", next: "Próximo", prev: "Voltar", done: "Entendi",
      nav_prev: "Anterior", nav_next: "Próxima etapa",
      run_first: "Execute a análise para desbloquear esta etapa.",
      run_now: "Executar agora", locked: "Requer análise",
      computing: "Calculando o pipeline…", compute_done: "Análise concluída",
      c_rf: "Distâncias Robinson–Foulds", c_mds: "Escalonamento MDS",
      c_clu: "Agrupamento e índices", c_hv: "Seleção por hipervolume",
      c_med: "Medoides e suporte nodal",
      export: "Exportar", export_csv: "Baixar CSV", export_svg: "Baixar SVG",
      export_png: "Baixar PNG", export_nwk: "Baixar Newick",
      copy_cite: "Copiar citação", copy_bibtex: "Copiar BibTeX",
      copied: "Copiado", downloaded: "Arquivo baixado",
      reorder: "Ordenar por cluster", reorder_off: "Ordem original",
      search_taxon: "Buscar táxon…", zoom: "Zoom", fit: "Ajustar", reset_view: "Reiniciar vista",
      no_match: "Sem correspondências",
      tip_cell: "Distância RF", tip_tree: "Árvore", tip_vs: "vs",
      tip_node: "Nó interno", tip_support: "Suporte", tip_taxa: "táxons",
      tip_range: "Intervalo fóssil", tip_period: "Período", tip_diet: "Dieta",
      show_medoid: "Ver em «Árvore medoide»",
      empty_noage_h: "Sem temporalidade disponível",
      onboard_h: "Bem-vindo ao PaleoForest",
      onboard_p: "Um guia rápido de 6 passos pelo pipeline: da paisagem de topologias à árvore representativa escalonada no tempo.",
      onboard_go: "Iniciar guia", onboard_no: "Explorar sozinho",
      progress: "Progresso da análise", clusters: "clusters", clu_lbl: "Cluster", med_lbl: "medoide",
      diet_herbivore: "herbívoro", diet_carnivore: "carnívoro", diet_omnivore: "onívoro",
      kbd_help: "Atalhos de teclado",
      kbd: [
        ["← / →", "Etapa anterior / próxima"],
        ["1 … 9", "Ir a uma etapa"],
        ["G", "Abrir glossário"],
        ["?", "Mostrar atalhos"],
        ["Esc", "Fechar janelas"]
      ],
      tour: [
        ["Nove passos, um pipeline", "A barra superior é o seu mapa. Cada aba é uma etapa do método; avance com os botões inferiores ou as setas do teclado."],
        ["Os dados já estão carregados", "O exemplo Arackar licanantay está pronto. Você também pode carregar suas próprias árvores TNT, a matriz de caracteres e, se tiver, idades fósseis."],
        ["Idades: PaleoDB ou à mão", "Se falta o intervalo fóssil de um táxon, consulta-se a Paleobiology Database com um clique. O que ficar ambíguo ou sem resultado, você digita na tabela."],
        ["Você escolhe a análise", "Métodos de agrupamento e intervalo de k. O cálculo ocorre no seu navegador: não há backend à espera de resultados."],
        ["Agrupar para decidir", "«Agrupamento» não é enfeite: o hipervolume escolhe o par método–k sobre quatro objetivos, e dessa partição saem os medoides de cluster. Aqui se decide tudo o que vem depois."],
        ["A paisagem, já explicada", "«Floresta» projeta a matriz RF em 2D com MDS: cada ponto é uma árvore inteira. As cores não são invenção do gráfico, vêm do agrupamento do passo anterior."],
        ["Perdido? Pergunte", "Qualquer símbolo «?» abre uma explicação em linguagem simples. A tecla G abre o glossário completo quando precisar."]
      ],
      gloss: {
        icons: ["Ícones de clado", "Cada folha leva a silhueta do seu clado. Vem da <b>linhagem</b> da Paleobiology Database, e essa é uma consulta <b>diferente</b> da das idades: as idades vêm de <span class='mono'>occs/taxa</span>, a linhagem de <span class='mono'>taxa/list</span> com <span class='mono'>rel=all_parents</span>. Precisam-se as duas porque saurópode ou terópode não são postos lineanos e sim clados: <span class='mono'>classext</span> devolve «Reptilia» e «Saurischia», e com isso não se distingue um saurópode de um terópode.<br><br>A <b>pegada</b> é para os que o PaleoDB não conhece: vai mais tênue porque não é um clado, é um «não sabemos».<br><br>Ao escrever no buscador, o ícone do táxon que coincide passa a laranja."],
        tscale: ["Escalonamento temporal", "As árvores de parcimônia não trazem tempo: só topologia. Escalonar é dar idade a cada nó usando os FAD/LAD dos táxons. Os cinco métodos são os de <span class='mono'>timePaleoPhy</span> (paleotree, Bapst 2012) e não são intercambiáveis: mudam onde fica cada ancestral.<br><br><b>basic</b> — cada nó vai ao FAD do descendente mais antigo. Deixa ramos de comprimento zero onde o ancestral aparece junto com seu descendente. Não usa vartime.<br><b>equal</b> — reparte por igual o tempo do ramo positivo mais próximo entre os ramos de comprimento zero (Brusatte et al. 2008). vartime é o tempo somado à raiz para haver o que repartir.<br><b>aba</b> — soma vartime a TODOS os ramos. O próprio paleotree avisa que deforma a árvore: os tips podem ficar fora de ordem em relação aos FAD.<br><b>zlba</b> — soma vartime só aos ramos de comprimento zero.<br><b>mbl</b> — nenhum ramo mede menos que vartime; os curtos empurram o ancestral para trás, em cascata (Laurin 2004).<br><br><b>vartime</b> é a variável de tempo em Ma usada pelos quatro últimos. Não sai dos dados: você a escolhe."],
        rf: ["Distância Robinson–Foulds (RF)", "Conta quantas partições (clados) diferem entre duas árvores. Normalizada em [0,1]: 0 = topologias idênticas, altos = muito diferentes."],
        proj: ["PCA vs. MDS", "Duas formas distintas de achatar a matriz RF para 2D. O PCA trata cada linha como um vetor de variáveis e procura as direções de maior variância; o MDS procura posições que respeitem as distâncias RF. O pipeline original em R usa PCA (via fviz_cluster). Os clusters são os mesmos em ambas: só muda onde caem os pontos."],
                mds: ["MDS (escalonamento multidimensional)", "Projeta a matriz de distâncias em 2D preservando proximidades. Pontos próximos = árvores parecidas. É um mapa da paisagem de topologias."],
        pam: ["PAM (k-medoides)", "Agrupa usando árvores reais como centros (medoides). Robusto e trabalha diretamente sobre a matriz RF."],
        kmeans: ["k-médias", "Agrupa sobre as coordenadas MDS minimizando a distância aos centroides. Rápido, mas os centros são pontos abstratos, não árvores."],
        fanny: ["FANNY (agrupamento difuso)", "Cada árvore recebe um grau de pertença a cada grupo em vez de uma atribuição rígida; no fim fica com o grupo de maior pertença. Com memb.exp = 1.1 o resultado é quase rígido, mas a fase difusa acomoda árvores de fronteira."],
        clara: ["CLARA", "PAM aplicado sobre várias amostras do conjunto em vez do todo: escolhe os medoides na amostra e atribui o resto ao mais próximo. Pensado para conjuntos grandes."],
        som: ["SOM (mapas auto-organizados)", "Uma grelha de neurónios que se acomoda aos dados; cada árvore cai no neurónio mais parecido. Os grupos são os neurónios ocupados, portanto k não se fixa: sai do treino."],
        dbscan: ["DBSCAN", "Agrupa por densidade: junta o que está apertado e deixa como ruído o isolado. Não pede k, mas pede um raio (eps), aqui tirado do cotovelo da curva de distâncias ao 4.º vizinho."],
        mstknn: ["MST-kNN", "Constrói a árvore de expansão mínima e o grafo de k vizinhos mais próximos, e fica com as arestas presentes em ambos. Os grupos são as componentes resultantes; k sai sozinho."],
        dunn: ["Índice de Dunn", "Razão entre a menor separação entre clusters e o maior diâmetro interno. Mais alto é melhor: grupos compactos e bem separados."],
        conn: ["Connectivity", "Penaliza quando vizinhos próximos caem em clusters diferentes. Mais baixo é melhor: agrupamentos coerentes com a vizinhança."],
        sil: ["Silhouette", "Para cada árvore compara a coesão interna com a separação ao cluster vizinho, em [-1,1]. Mais alto é melhor."],
        hv: ["Hipervolume (ConHyp)", "Integra os quatro objetivos (min k, max Dunn, min Connectivity, max Silhouette) em um número. A combinação método–k de maior hipervolume é a escolhida."],
        medoid: ["Medoide", "O membro mais central de um grupo: a árvore com menor distância média às demais. Ao contrário do consenso, não é um resumo: é uma das árvores originais, com todos os nós resolvidos."],
        support: ["Suporte do nó", "Frequência com que um clado (bipartição) reaparece entre todas as árvores mais parcimoniosas. 1 = presente em todas; baixos = clado instável."],
        parsimony: ["Árvores mais parcimoniosas", "As que explicam os dados com o menor número de mudanças morfológicas. Costumam existir muitas empatadas no ótimo."],
        consensus: ["Consenso e politomia", "Uma árvore de consenso resume a concordância, mas colapsa conflitos em politomias: nós por resolver, que nenhuma das árvores originais tinha."],
        matrix: ["Matriz de caracteres", "A tabela de onde sai tudo: uma linha por táxon, uma coluna por carácter, e em cada célula o estado observado (0, 1, 2…), «?» se não se sabe e «−» se não se aplica. As árvores não a contêm: a parcimônia calcula-se cruzando árvore e matriz. Mudar de matriz muda a pontuação mesmo que as árvores sejam as mesmas."],
                base: ["Numeração de caracteres (base 0 ou 1)", "O TNT numera os caracteres a partir de 0: o primeiro é o carácter 0. Os papers quase sempre numeram a partir de 1. Um carácter de diferença parece trivial, mas desloca toda a lista e muda a pontuação. É exatamente o erro do ccode deste ficheiro: metade convertida para base 0 e metade não."],
        gap: ["Vazios «-» e faltantes «?»", "«?» significa «não se sabe»: o carácter pode ter qualquer estado e não custa passos. O «-» é ambíguo por convenção: uns leem-no como faltante (não se pôde observar) e outros como um estado próprio (a estrutura não existe, o que é informação real). A decisão muda a pontuação: em Arackar, tratá-los como estado próprio quebra a consistência entre árvores."],
        weight: ["Peso de um carácter", "Multiplica os passos desse carácter. Peso 3 significa que cada mudança conta a triplicar, portanto a árvore evitará contradizê-lo. Serve para dar menos voz a caracteres homoplásicos. Por omissão todos pesam 1."],
        active: ["Carácter ativo ou desativado", "Um carácter desativado não contribui com passos: fica fora do cálculo, como se não estivesse na matriz. Usa-se para excluir caracteres pouco fiáveis sem os apagar do ficheiro."],
                ccode: ["ccode (ajuste de caracteres)", "O comando do TNT que declara como se trata cada carácter: «+» aditivo, «−» não aditivo, «[» e «]» ativar ou desativar, «/N» peso. Não é um detalhe técnico: é uma decisão do investigador que muda a pontuação e pode mudar que árvores são ótimas."],
        ordered: ["Caracteres aditivos (ordenados)", "Um carácter aditivo assume que os estados formam uma série: passar de 0 a 2 custa 2, não 1. Contam-se com Wagner. Os não aditivos cobram 1 passo por mudança (Fitch). Quais são aditivos decide quem monta a matriz, e muda a pontuação final."],
                fad: ["FAD e LAD", "FAD (First Appearance Datum) é a ocorrência mais antiga do táxon no registro fóssil; LAD (Last Appearance Datum), a mais recente. Juntos definem a barra de intervalo fóssil."],
        geoscale: ["Tabela cronoestratigráfica", "A hierarquia oficial do tempo geológico (ICS/IUGS): éon → era → período → época → andar. Cada nível é uma leitura distinta do mesmo eixo temporal, do mais grosso ao mais fino."],
        clade: ["Clado / bipartição", "Um grupo de táxons que descendem de um ancestral comum. Numa árvore equivale a uma bipartição: a divisão produzida por um ramo interno."]
      }
    }
  };
  ['es', 'en', 'pt'].forEach(l => Object.assign(I18N[l], UX[l]));

  /* ======================================================================
   * 2. CSS suplementario (componentes de usabilidad)
   * ==================================================================== */
  const CSS = `
  .hchip{display:inline-grid;place-items:center;width:16px;height:16px;border-radius:50%;
    border:1.5px solid var(--usach-teal-l);background:#fff;color:var(--usach-teal-d);
    font-size:10px;font-weight:800;font-family:var(--mono);vertical-align:middle;margin-left:5px;
    cursor:help;transition:.14s;padding:0;line-height:1}
  .hchip:hover{background:var(--usach-teal);color:#fff;border-color:var(--usach-teal);transform:translateY(-1px)}
  .hchip:focus-visible{outline:2px solid var(--usach-teal);outline-offset:2px}
  .pop{position:fixed;z-index:90;max-width:290px;background:#fff;border:1px solid var(--line);
    border-radius:12px;box-shadow:var(--shadow-lg);padding:14px 15px;font-size:13px;line-height:1.5;
    color:var(--ink);opacity:0;transform:translateY(4px);transition:.13s;pointer-events:none}
  .pop.on{opacity:1;transform:none;pointer-events:auto}
  .pop h5{margin:0 0 5px;font-size:13px;color:var(--usach-slate);letter-spacing:-.01em}
  .pop .pk{font-family:var(--mono);font-size:10px;color:var(--usach-teal-d);text-transform:uppercase;letter-spacing:.1em}
  .helpbtn{display:inline-flex;align-items:center;gap:7px;padding:7px 12px;border-radius:9px;
    border:1px solid var(--line);background:#fff;font-size:12.5px;font-weight:700;color:var(--usach-slate);
    box-shadow:var(--shadow);transition:.14s}
  .helpbtn:hover{background:var(--bg-strata);transform:translateY(-1px)}
  .helpbtn svg{width:15px;height:15px;stroke:var(--usach-teal-d)}
  .modal-bk{position:fixed;inset:0;z-index:100;background:rgba(20,26,30,.44);backdrop-filter:blur(3px);
    display:grid;place-items:center;padding:22px;opacity:0;transition:.16s;pointer-events:none}
  .modal-bk.on{opacity:1;pointer-events:auto}
  .modal{background:#fff;border-radius:18px;max-width:640px;width:100%;max-height:86vh;overflow:auto;
    box-shadow:var(--shadow-lg);transform:translateY(10px);transition:.18s}
  .modal-bk.on .modal{transform:none}
  .modal-hd{position:sticky;top:0;background:#fff;padding:20px 24px 14px;border-bottom:1px solid var(--line);
    display:flex;align-items:center;gap:12px;z-index:2}
  .modal-hd h3{font-size:19px;flex:1}
  .modal-x{width:32px;height:32px;border-radius:9px;border:1px solid var(--line);background:#fff;
    display:grid;place-items:center;font-size:17px;color:var(--muted);transition:.14s}
  .modal-x:hover{background:var(--bg-strata);color:var(--usach-slate)}
  .modal-bd{padding:18px 24px 24px}
  .gloss-item{padding:13px 0;border-bottom:1px dashed var(--line)}
  .gloss-item:last-child{border-bottom:none}
  .gloss-item h4{font-size:14.5px;color:var(--usach-teal-d);margin-bottom:4px}
  .gloss-item p{font-size:13.5px;color:var(--ink);line-height:1.55}
  .kbd-row{display:flex;align-items:center;gap:14px;padding:9px 0;border-bottom:1px dashed var(--line)}
  .kbd-row:last-child{border-bottom:none}
  .kbd{font-family:var(--mono);font-size:12px;font-weight:700;background:var(--bg-strata);
    border:1px solid var(--line);border-bottom-width:2px;border-radius:7px;padding:4px 9px;color:var(--usach-slate);min-width:64px;text-align:center}
  .kbd-row span{font-size:13.5px;color:var(--muted)}
  .toast-wrap{position:fixed;left:50%;bottom:26px;transform:translateX(-50%);z-index:120;
    display:flex;flex-direction:column;gap:9px;align-items:center;pointer-events:none}
  .toast{background:var(--usach-slate);color:#fff;padding:11px 18px;border-radius:12px;font-size:13.5px;
    font-weight:600;box-shadow:var(--shadow-lg);display:flex;align-items:center;gap:9px;
    opacity:0;transform:translateY(10px);transition:.2s}
  .toast.on{opacity:1;transform:none}
  .toast svg{width:16px;height:16px;stroke:var(--usach-teal-l);flex:none}
  .navbtns{display:flex;justify-content:space-between;gap:12px;margin-top:26px;padding-top:20px;border-top:1px solid var(--line)}
  .navbtn{display:inline-flex;align-items:center;gap:9px;padding:11px 18px;border-radius:11px;
    border:1px solid var(--line);background:#fff;font-size:13.5px;font-weight:700;color:var(--usach-slate);
    box-shadow:var(--shadow);transition:.14s}
  .navbtn:hover:not(:disabled){background:var(--bg-strata);transform:translateY(-1px)}
  .navbtn.primary{background:var(--usach-teal);color:#fff;border-color:var(--usach-teal);box-shadow:0 4px 14px rgba(0,164,153,.28)}
  .navbtn.primary:hover:not(:disabled){background:var(--usach-teal-d)}
  .navbtn:disabled{opacity:.4;cursor:not-allowed}
  .navbtn svg{width:15px;height:15px}
  .prog{display:flex;align-items:center;gap:5px;margin:8px 0 0;flex-wrap:wrap}
  .prog-dot{display:flex;align-items:center;gap:6px;font-size:11px;color:var(--muted);font-weight:600}
  .prog-dot .d{width:9px;height:9px;border-radius:50%;background:var(--bg-strata);border:1.5px solid var(--line);transition:.2s}
  .prog-dot.done .d{background:var(--usach-teal);border-color:var(--usach-teal)}
  .prog-dot.done{color:var(--usach-teal-d)}
  .lock{display:inline-grid;place-items:center;width:15px;height:15px;opacity:.5}
  .lock svg{width:12px;height:12px;stroke:var(--muted)}
  .step.lockd{opacity:.62}
  .toolbtn{display:inline-flex;align-items:center;gap:7px;padding:7px 12px;border-radius:9px;
    border:1px solid var(--line);background:#fff;font-size:12.5px;font-weight:600;color:var(--usach-slate);transition:.14s}
  .toolbtn:hover{background:var(--bg-strata);border-color:var(--usach-teal-l)}
  .toolbtn.on{background:var(--usach-teal);color:#fff;border-color:var(--usach-teal)}
  .toolbtn svg{width:14px;height:14px}
  .searchbox{display:inline-flex;align-items:center;gap:8px;padding:0 11px;border:1px solid var(--line);
    border-radius:9px;background:#fff;height:34px}
  .searchbox svg{width:14px;height:14px;stroke:var(--muted);flex:none}
  .searchbox input{border:none;outline:none;font-family:inherit;font-size:13px;background:transparent;width:150px;color:var(--ink)}
  .loadscrim{position:fixed;inset:0;z-index:110;background:rgba(244,246,245,.82);backdrop-filter:blur(3px);
    display:grid;place-items:center;opacity:0;transition:.18s;pointer-events:none}
  .loadscrim.on{opacity:1;pointer-events:auto}
  .loadcard{background:#fff;border:1px solid var(--line);border-radius:16px;box-shadow:var(--shadow-lg);
    padding:26px 30px;width:min(380px,90vw);text-align:center}
  .spinner{width:38px;height:38px;margin:0 auto 16px;border-radius:50%;border:3px solid var(--bg-strata);
    border-top-color:var(--usach-teal);animation:spin .8s linear infinite}
  @keyframes spin{to{transform:rotate(360deg)}}
  .loadcard h4{font-size:15px;margin-bottom:14px}
  .lbar{height:7px;border-radius:5px;background:var(--bg-strata);overflow:hidden;margin-bottom:12px}
  .lbar>i{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--usach-teal),var(--usach-teal-l));transition:width .3s}
  .lsteps{text-align:left;font-size:12px;color:var(--muted);display:grid;gap:6px}
  .lsteps .ls{display:flex;align-items:center;gap:8px}
  .lsteps .ls .mk{width:14px;height:14px;border-radius:50%;border:1.5px solid var(--line);flex:none;display:grid;place-items:center}
  .lsteps .ls.done{color:var(--usach-teal-d)}
  .lsteps .ls.done .mk{background:var(--usach-teal);border-color:var(--usach-teal)}
  .lsteps .ls.done .mk svg{width:8px;height:8px;stroke:#fff;stroke-width:3.5}
  .tour-foot .sp{flex:1;font-size:12px;color:var(--muted);font-family:var(--mono)}
  .empty{text-align:center;padding:40px 22px;color:var(--muted)}
  .empty .ei{width:52px;height:52px;margin:0 auto 14px;border-radius:14px;background:var(--bg-strata);
    display:grid;place-items:center}
  .empty .ei svg{width:26px;height:26px;stroke:var(--usach-teal-d)}
  .empty h4{font-size:16px;color:var(--usach-slate);margin-bottom:6px}
  .empty p{font-size:13.5px;max-width:44ch;margin:0 auto 16px}
  .taxon-hl{outline:2px solid var(--usach-orange);outline-offset:1px}
  .zoomctl{display:inline-flex;border:1px solid var(--line);border-radius:9px;overflow:hidden;background:#fff}
  .zoomctl button{width:34px;height:34px;border:none;border-right:1px solid var(--line);background:#fff;
    font-size:16px;font-weight:700;color:var(--usach-slate)}
  .zoomctl button:last-child{border-right:none}
  .zoomctl button:hover{background:var(--bg-strata)}
  @media (prefers-reduced-motion: reduce){*{animation-duration:.001ms!important;transition-duration:.001ms!important}}
  :focus-visible{outline:2px solid var(--usach-teal);outline-offset:2px}
  `;
  const styleEl = document.createElement('style'); styleEl.textContent = CSS; document.head.appendChild(styleEl);

  /* ======================================================================
   * 3. Escala geológica — delegada a geoscale.js (ICS/IUGS, 5 niveles)
   * ==================================================================== */
  // unidad cronoestratigráfica a partir de un nombre (cualquier nivel)
  function unitOf(name) { return GEO.byName(name); }
  // color asociado a un taxón: usa el nivel más fino disponible en la anotación
  function taxonColor(a) {
    if (!a) return 'var(--usach-teal)';
    const u = GEO.byName(a.stage) || GEO.byName(a.epoch) || GEO.byName(a.period)
      || GEO.byName(a.era) || (a.fad != null ? GEO.atAge('period', a.fad) : null);
    return u ? u.c : 'var(--usach-teal)';
  }
  // etiqueta jerárquica legible: "Mesozoico · Cretácico · Cretácico Superior"
  function geoLabel(a) {
    if (!a) return '—';
    const parts = [a.era, a.period, a.epoch, a.stage].filter(Boolean);
    if (parts.length) return parts.join(' · ');
    if (a.fad != null) { const h = GEO.hierarchyAt(a.fad); return [h.era, h.period, h.epoch].filter(Boolean).join(' · '); }
    return '—';
  }

  /* ======================================================================
   * 4. Estado global
   * ==================================================================== */
  /* La app carga un único conjunto de ejemplo: Arackar licanantay
     (data/arackar/dataset.js). Los demás casos de la memoria viven en
     examples/, una carpeta por especie, y se cargan por el paso «Datos». */
  const S = {
    lang: 'es', step: 0, data: null, trees: null, D: null, coords: null,
    tsType: 'basic', tsVar: 1, clades: null, tmq: '',
    // los siete métodos del pipeline original (Acosta Méndez, 2024)
    methods: { 'PAM': true, 'K-Means': true, 'FANNY': true, 'CLARA': true, 'SOM': true, 'DBSCAN': true, 'MST-kNN': true },
    kmin: 2, kmax: 15,          // rango de la tesis
    proj: 'pca',                // 'pca' (como fviz_cluster del R) | 'mds'
    rows: null, best: null, labels: null, gm: null, cm: null, cur: null,
    computed: false, computing: false, reorder: false, hlCluster: null,
    computeMs: 0, curTreeIdx: null,
    isExample: true,                        // false cuando el usuario carga lo suyo
    geoLevels: ['era', 'period', 'epoch'],  // "modelos de eras" activos en temporalidad
    ageSrc: {},                             // taxón -> 'csv' | 'pbdb' | 'manual'
    pbdb: null,                             // último resultado de consulta PBDB
    pars: null, parsBest: null, notMP: [], deg: null,  // parsimonia
    parsCfg: null, applied: null, consensus: [], keepConsensus: false
  };
  const METHOD_KEYS = ['PAM', 'K-Means', 'FANNY', 'CLARA', 'SOM', 'DBSCAN', 'MST-kNN'];
  const NO_K = ['DBSCAN', 'MST-kNN'];   // determinan k por sí mismos
  const GLOSS_OF = { 'PAM': 'pam', 'K-Means': 'kmeans', 'FANNY': 'fanny', 'CLARA': 'clara', 'SOM': 'som', 'DBSCAN': 'dbscan', 'MST-kNN': 'mstknn' };
  const CLUSTER_COLORS = ['#00A499', '#EA7600', '#812b92', '#34b2c9', '#7fc64e', '#fd9a52', '#394049', '#d64545'];
  const RESULT_STEPS = [3, 4, 5, 6, 8]; // requieren cómputo; «Edades» (7) no, es entrada de datos

  /* ======================================================================
   * 5. Utilidades DOM / i18n / feedback
   * ==================================================================== */
  const $ = (s, r) => (r || document).querySelector(s);
  const t = k => I18N[S.lang][k];
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const pretty = n => String(n).replace(/_/g, ' ');
  const gl = id => I18N[S.lang].gloss[id]; // [term, def]
  // ayuda contextual inline

  /* ---------- siluetas por clado ----------
     Dibujadas acá, sin IP de nadie. `hit` cambia el color: es el resaltado del
     buscador del árbol temporal. */
  const CLADE_PATH = {
    sauropoda: 'M2 13c1-4 4-5 6-5 1-3 3-4 5-3 2 1 2 3 1 4 2 1 4 3 4 6 0 1-1 2-2 2h-1l-1-3-1 3h-2l-1-3-1 3H8l-1-3-1 3H4c-1 0-2-1-2-2z',
    theropoda: 'M4 15l3-4c0-3 2-6 5-6h3l2 2-3 1-1 2 2 3-3 1-1 3-2-1 1-3-2-1-2 4z',
    ornithischia: 'M3 13c1-3 3-4 5-4l1-2 3-1 2 2 3 1-1 2 2 3-3 1-1 2-3-1-2 2-2-1 1-2-3-1z',
    crocodylomorpha: 'M1 11h5l2-2h6l4 2 2 1-2 1-4 2H8l-2-2H1zM6 9l1-2 1 2z',
    pterosauria: 'M2 8l7 3 3-5 3 5 5-3-4 6-4-1-4 1z',
    mammalia: 'M4 14c0-4 3-6 6-6l2-3 2 3c2 1 3 3 3 6l-2 1-1-2-2 2-2-2-2 2-1-2z',
    testudinata: 'M3 12c0-4 3-6 7-6s7 2 7 6l-2 2H5zM17 10l3-1-2 3z',
    /* Huella: para los que PaleoDB no conoce. Antes no se dibujaba nada y la
       fila quedaba coja; la huella dice «hay un bicho acá y no sabemos cuál»,
       que es información, no ruido. */
    '': 'M7 16c-1.4 0-2.4-1.1-2.2-2.4.2-1.3 1.2-2.2 2.6-2.6 1.4-.4 2.8-.4 4.2 0 1.4.4 2.4 1.3 2.6 2.6.2 1.3-.8 2.4-2.2 2.4zM5.6 9.4a1.5 1.7 0 1 1 0-3.4 1.5 1.7 0 0 1 0 3.4zM9.2 8.2a1.5 1.8 0 1 1 0-3.6 1.5 1.8 0 0 1 0 3.6zM12.8 8.6a1.5 1.8 0 1 1 0-3.6 1.5 1.8 0 0 1 0 3.6zM15.9 10.4a1.4 1.6 0 1 1 0-3.2 1.4 1.6 0 0 1 0 3.2z'
  };
  /* El mismo trazo, pero como <g> para meterlo dentro del SVG del árbol. */
  function cladeGlyph(key) {
    // la huella va más tenue: es un «no sabemos», no un dato
    return `<path d="${CLADE_PATH[key] || CLADE_PATH['']}" fill="var(--usach-slate)" fill-opacity="${key ? '.62' : '.3'}"/>`;
  }
  function cladeIcon(key) {
    return `<svg class="cli" viewBox="0 0 22 20" width="15" height="14"><path d="${CLADE_PATH[key] || CLADE_PATH['']}" fill="currentColor"/></svg>`;
  }

  function hchip(id) { return `<button class="hchip" data-help="${id}" aria-label="${esc(gl(id)[0])}" tabindex="0">?</button>`; }

  const SVGI = {
    arrowR: '<path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    arrowL: '<path d="M19 12H5M11 18l-6-6 6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    dl: '<path d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10" fill="none" stroke="currentColor" stroke-width="2"/>',
    check: '<path d="M4 12l5 5L20 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    help: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M9.2 9.3a2.8 2.8 0 0 1 5.4 1c0 1.9-2.6 2.3-2.6 3.7M12 17.2h.01" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    search: '<circle cx="11" cy="11" r="7" fill="none" stroke="currentColor" stroke-width="2"/><path d="M20 20l-3.5-3.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    lock: '<rect x="5" y="11" width="14" height="9" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="2"/>',
    clock: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 7v5l3 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    info: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 11v5M12 8h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    globe: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3 12h18M12 3c2.5 2.7 2.5 15.3 0 18M12 3c-2.5 2.7-2.5 15.3 0 18" fill="none" stroke="currentColor" stroke-width="2"/>',
    play: '<path d="M8 5.2v13.6L19 12z" fill="currentColor" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>',
    swipe: '<path d="M4 12h16M8 8l-4 4 4 4M16 8l4 4-4 4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
  };
  // Algunos entornos sin rAF (o con la pestaña oculta) hacen reventar el handler
  // entero si se llama a pelo. Guarda una sola vez, para todos.
  const RAF = f => (typeof requestAnimationFrame === 'function' ? requestAnimationFrame(f) : setTimeout(f, 16));
  const ic = (p, cls) => `<svg viewBox="0 0 24 24" class="${cls || ''}">${p}</svg>`;

  // toasts
  let toastWrap;
  function toast(msg, okIcon) {
    if (!toastWrap) { toastWrap = document.createElement('div'); toastWrap.className = 'toast-wrap'; document.body.appendChild(toastWrap); }
    const el = document.createElement('div'); el.className = 'toast';
    el.innerHTML = (okIcon !== false ? ic(SVGI.check) : '') + '<span>' + esc(msg) + '</span>';
    toastWrap.appendChild(el);
    const raf = (typeof requestAnimationFrame === 'function') ? requestAnimationFrame : (f => setTimeout(f, 16));
    raf(() => el.classList.add('on'));
    setTimeout(() => { el.classList.remove('on'); setTimeout(() => el.remove(), 250); }, 2100);
  }
  function copy(txt) { navigator.clipboard.writeText(txt).then(() => toast(t('copied'))).catch(() => toast(t('copied'))); }
  function download(name, content, mime) {
    const blob = new Blob([content], { type: mime || 'text/plain;charset=utf-8' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(a.href);
    toast(t('downloaded'));
  }

  // popover de ayuda contextual
  let pop;
  function ensurePop() { if (!pop) { pop = document.createElement('div'); pop.className = 'pop'; document.body.appendChild(pop); } return pop; }
  function openPop(anchor, id) {
    const g = gl(id); ensurePop();
    /* La definición es contenido propio, no entrada del usuario: va como HTML.
       Escapándola se veían los <br> y los <b> como texto. */
    pop.innerHTML = `<div class="pk">${esc(t('help'))}</div><h5>${esc(g[0])}</h5><div>${g[1]}</div>`;
    pop.classList.add('on');
    const r = anchor.getBoundingClientRect(), pw = 290;
    let left = r.left + r.width / 2 - pw / 2;
    left = Math.max(12, Math.min(left, innerWidth - pw - 12));
    let top = r.bottom + 9;
    pop.style.left = left + 'px'; pop.style.top = top + 'px';
    if (top + pop.offsetHeight > innerHeight - 12) pop.style.top = (r.top - pop.offsetHeight - 9) + 'px';
  }
  function closePop() { if (pop) pop.classList.remove('on'); }
  document.addEventListener('click', e => {
    const h = e.target.closest('.hchip');
    if (h) { e.stopPropagation(); openPop(h, h.dataset.help); }
    else if (!e.target.closest('.pop')) closePop();
  });
  document.addEventListener('mouseover', e => { const h = e.target.closest('.hchip'); if (h) openPop(h, h.dataset.help); });
  addEventListener('scroll', closePop, true);

  // tooltip flotante (usa el #tip del template)
  const TIP = $('#tip');
  function showTip(html, x, y) {
    TIP.innerHTML = html; TIP.style.opacity = '1';
    const w = TIP.offsetWidth, h = TIP.offsetHeight;
    let l = x + 14, tp = y + 14;
    if (l + w > innerWidth - 8) l = x - w - 14;
    if (tp + h > innerHeight - 8) tp = y - h - 14;
    TIP.style.left = l + 'px'; TIP.style.top = tp + 'px';
  }
  function hideTip() { TIP.style.opacity = '0'; }

  // modal genérico
  let modalBk;
  /* Volver al ejemplo TIRA lo que esté cargado. Si eso no es el ejemplo —datos
     del módulo 1 o archivos del usuario— hay que preguntar: no hay deshacer, y
     los árboles del módulo 1 ya se consumieron del almacenamiento. */
  function confirmReset(onYes) {
    const L = I18N[S.lang];
    if (S.isExample || !S.data) { onYes(); return; }
    const fromMod1 = S.data.key === 'handoff';
    openModal(L.rst_t, `
      <p class="lead" style="font-size:14px">${esc(fromMod1 ? L.rst_p_hand.replace('{n}', S.data.nTrees) : L.rst_p_own.replace('{n}', S.data.nTrees))}</p>
      <div class="warnbox" style="margin-top:14px">${ic(SVGI.info)}<div><p>${esc(L.rst_gone)}</p></div></div>
      <div style="display:flex;gap:10px;margin-top:18px;justify-content:flex-end">
        <button class="btn ghost" id="rst-no">${esc(L.rst_no)}</button>
        <button class="btn" id="rst-yes">${esc(L.rst_yes)}</button>
      </div>`);
    $('#rst-no', modalBk).onclick = closeModal;
    $('#rst-yes', modalBk).onclick = () => { closeModal(); onYes(); };
  }

  function openModal(title, bodyHTML) {
    if (!modalBk) {
      modalBk = document.createElement('div'); modalBk.className = 'modal-bk';
      modalBk.innerHTML = `<div class="modal" role="dialog" aria-modal="true"><div class="modal-hd"><h3></h3><button class="modal-x" aria-label="${esc(t('close'))}">×</button></div><div class="modal-bd"></div></div>`;
      document.body.appendChild(modalBk);
      modalBk.addEventListener('click', e => { if (e.target === modalBk || e.target.closest('.modal-x')) closeModal(); });
    }
    $('.modal-hd h3', modalBk).textContent = title;
    $('.modal-bd', modalBk).innerHTML = bodyHTML;
    modalBk.classList.add('on');
  }
  function closeModal() { if (modalBk) modalBk.classList.remove('on'); }

  /* ======================================================================
   * 6. Pipeline (usa funciones globales de pipeline.js)
   * ==================================================================== */
  function loadDataset(d, srcTag) {
    /* El conjunto de origen, tal cual llegó. Sin esto, cualquier recarga interna
       tenía que ir a buscar window.PF_DATA —el ejemplo— y borraba lo que el
       usuario hubiera cargado o recibido del módulo 1. */
    S.source = d; S.sourceTag = srcTag;
    S.data = JSON.parse(JSON.stringify(d));   // copia: las edades se editan en vivo
    S.data.ages = S.data.ages || {};
    S.isExample = d.key === 'arackar';
    S.trees = S.data.newicks.map(parseNewick);

    /* Los .tre de TNT traen el consenso pegado al final. No es un árbol más
       parsimonioso —tiene politomías y por monotonía cuesta más— y si entra
       contamina la matriz RF, el agrupamiento y los medoides. Se detecta
       comparando biparticiones contra el consenso estricto del resto, y se
       excluye por defecto. El usuario puede reincorporarlo. */
    S.imputed = 0;
    S.consensus = [];
    if (S.keepConsensus !== true) {
      const found = findConsensusTrees(S.trees, S.data.taxa);
      if (found.length) {
        S.consensus = found.map(i => ({ n: i + 1, deg: maxDegree(S.trees[i]) }));
        const keep = S.trees.map((_, i) => i).filter(i => found.indexOf(i) < 0);
        S.data.newicks = keep.map(i => S.data.newicks[i]);
        S.data.nTrees = S.data.newicks.length;
        S.trees = keep.map(i => S.trees[i]);
      }
    }

    S.D = S.coords = S.rows = S.best = S.labels = S.gm = S.cm = null;
    S.computed = false; S.curTreeIdx = null; S.pbdb = null;
    S.pars = null; S.parsBest = null; S.notMP = []; S.deg = null;
    S.parsCfg = defaultParsCfg(); S.applied = null;
    S.ageSrc = {};
    Object.keys(S.data.ages).forEach(k => { S.ageSrc[k] = srcTag || 'csv'; });
    // Imputación automática: sin edad, el taxón queda fuera del árbol temporal.
    S.imputed = imputeMissing();
  }
  function hasAges() { return S.data && S.data.ages && Object.keys(S.data.ages).length > 0; }

  /* El pipeline completo (7 métodos × k=2..15) es pesado: con ~100 árboles son
     decenas de segundos de cálculo. Se ejecuta por trozos, cediendo el hilo entre
     cada paso, para que la barra avance de verdad y la pestaña no se congele. */
  function runPipelineAsync(onStep, done) {
    const yieldy = fn => new Promise(res => setTimeout(() => res(fn()), 0));
    const rows = [];
    let D, E, coords;
    const push = (method, labels) => {
      const k = new Set(labels).size;
      rows.push({
        method, k, _labels: labels,
        Dunn: dunn(D, labels),                    // los índices usan RF, no el euclídeo
        Connectivity: connectivity(D, labels),
        Silhouette: silhouette(D, labels)
      });
    };
    // lista de tareas: cada una es un trozo de trabajo con su etiqueta
    const tasks = [];
    tasks.push(['pars', () => {
      // puntaje de parsimonia por árbol + detección de topologías no óptimas
      if (S.data.matrix && Object.keys(S.data.matrix).length) {
        // caracteres aditivos (Wagner) segun el dataset; el resto va Fitch
        const pc = S.applied || S.parsCfg || defaultParsCfg();
        S.ordered = pc.ordered || S.data.ordered || [];
        S.pars = S.trees.map(t => parsimonyScoreEx(t, S.data.matrix, pc));
        S.deg = S.trees.map(t => maxDegree(t));
        const best = Math.min.apply(null, S.pars);
        S.parsBest = best;
        S.notMP = S.pars.map((v, i) => v > best ? i : -1).filter(i => i >= 0);
      } else { S.pars = null; S.parsBest = null; S.notMP = []; S.deg = null; S.ordered = []; }
    }]);
    tasks.push(['rf', () => { D = roundMatrix2(rfMatrix(S.trees, S.data.taxa)); }]);
    tasks.push(['rf', () => { E = euclideanFromRows(D); }]);
    tasks.push(['proj', () => {
      coords = S.proj === 'pca' ? pcaRows(D, 2) : { scores: classicalMDS(D, 2), pct: null };
    }]);
    for (let k = S.kmin; k <= S.kmax; k++) {
      const kk = k;
      METHOD_KEYS.forEach(m => {
        if (!S.methods[m] || NO_K.indexOf(m) >= 0) return;
        tasks.push([m + ' k=' + kk, () => {
          if (m === 'PAM') push('PAM', pam(E, kk).clustering);
          else if (m === 'K-Means') push('K-Means', kmeans(D, kk));
          else if (m === 'FANNY') push('FANNY', fanny(E, kk, 1.1).clustering);
          else if (m === 'CLARA') push('CLARA', clara(D, kk, E).clustering);
          else if (m === 'SOM') push('SOM', somClusters(D, kk));
        }]);
      });
    }
    if (S.methods['DBSCAN']) tasks.push(['DBSCAN', () => {
      const lb = dbscan(E, dbscanEps(E, 4), 5);
      rows.push({
        method: 'DBSCAN', k: new Set(lb).size, _labels: lb,
        Dunn: 0,                                   // el R lo fija en 0 para evitar el infinito
        Connectivity: connectivity(D, lb), Silhouette: silhouette(D, lb)
      });
    }]);
    if (S.methods['MST-kNN']) tasks.push(['MST-kNN', () => push('MST-kNN', mstknn(E))]);
    tasks.push(['hv', () => {
      const hv = hypervolume(rows); rows.forEach((r, i) => r.ConHyp = hv[i]);
    }]);
    tasks.push(['med', () => {
      const sorted = rows.slice().sort((a, b) => b.ConHyp - a.ConHyp);
      const best = sorted[0];
      S.D = D; S.E = E; S.coords = coords.scores; S.projPct = coords.pct;
      S.rows = sorted; S.best = best; S.labels = best._labels;
      S.gm = generalMedoid(D); S.cm = clusterMedoids(D, best._labels);
      S.curTreeIdx = S.gm; S.computed = true;
    }]);

    let i = 0;
    (function next() {
      if (i >= tasks.length) return done();
      const [label, fn] = tasks[i];
      onStep(i / tasks.length, label);
      yieldy(fn).then(() => { i++; next(); });
    })();
  }

  // soporte nodal para un índice de árbol dado (parseamos fresco para no mutar S.trees)
  function medoidTreeWithSupport(idx) {
    const tr = parseNewick(S.data.newicks[idx]);
    nodeSupport(tr, S.trees, S.data.taxa);
    return tr;
  }

  /* ======================================================================
   * 7. Cómputo con overlay de progreso
   * ==================================================================== */
  let scrim;
  function computeThen(after) {
    if (S.computing) return;
    S.computing = true;
    if (!scrim) {
      scrim = document.createElement('div'); scrim.className = 'loadscrim';
      document.body.appendChild(scrim);
    }
    const stages = [t('c_rf'), t('c_mds'), t('c_clu'), t('c_hv'), t('c_med')];
    scrim.innerHTML = `<div class="loadcard"><div class="spinner"></div><h4>${esc(t('computing'))}</h4>
      <div class="lbar"><i id="lbar-i"></i></div>
      <div class="lnow mono" id="lbar-now"></div>
      <div class="lsteps">${stages.map((s, i) => `<div class="ls" id="ls-${i}"><span class="mk">${ic(SVGI.check)}</span>${esc(s)}</div>`).join('')}</div></div>`;
    RAF(() => scrim.classList.add('on'));
    const bar = $('#lbar-i', scrim), now = $('#lbar-now', scrim);
    // etapa visible según la tarea en curso: progreso real, no animación de adorno
    const stageOf = label => label === 'rf' ? 0 : label === 'proj' ? 1
      : label === 'hv' ? 3 : label === 'med' ? 4 : 2;
    runPipelineAsync(
      (frac, label) => {
        bar.style.width = Math.max(3, frac * 100).toFixed(1) + '%';
        now.textContent = ['rf', 'proj', 'hv', 'med'].indexOf(label) >= 0 ? '' : label;
        const st = stageOf(label);
        for (let i = 0; i < st; i++) { const e = $('#ls-' + i, scrim); if (e) e.classList.add('done'); }
      },
      () => {
        bar.style.width = '100%';
        for (let i = 0; i < 5; i++) { const e = $('#ls-' + i, scrim); if (e) e.classList.add('done'); }
        setTimeout(() => {
          scrim.classList.remove('on'); S.computing = false;
          toast(t('compute_done'));
          after && after();
        }, 260);
      }
    );
  }

  /* ======================================================================
   * 8. Chrome: brand, idiomas, botón de ayuda, pasos
   * ==================================================================== */
  function renderChrome() {
    const L = I18N[S.lang];
    $('#brand').innerHTML = `${logoSVG()}<div class="brand-txt"><div class="k">${esc(L.appName)}</div><div class="s">${esc(L.appSub)}</div></div>`;
    // idiomas + ayuda
    const langs = $('#langs');
    langs.innerHTML =
      `<a class="helpbtn" href="index.html">${ic(SVGI.arrowL)}<span>${esc(I18N_HUB[S.lang].backHub)}</span></a>` +
      `<button class="helpbtn tourbtn" id="tourBtn" title="${esc(L.tour_hint)}">${ic(SVGI.play)}<span>${esc(L.tour_start)}</span></button>` +
      `<button class="helpbtn" id="helpBtn" aria-haspopup="menu">${ic(SVGI.help)}<span>${esc(L.help)}</span></button>` +
      ['es', 'en', 'pt'].map(l => `<button class="lang ${l === S.lang ? 'on' : ''}" data-lang="${l}" aria-label="${esc(I18N[l]._flag)}" title="${esc(I18N[l]._flag)}">${FLAGS[l]}</button>`).join('');
    langs.querySelectorAll('.lang').forEach(b => b.onclick = () => setLang(b.dataset.lang));
    $('#helpBtn').onclick = openHelpMenu;
    $('#tourBtn').onclick = startTour;
    renderSteps();
  }
  function renderSteps() {
    const steps = I18N[S.lang].steps;
    $('#steps').innerHTML = steps.map((s, i) => {
      const locked = !S.data ? i !== 0 : (RESULT_STEPS.indexOf(i) >= 0 && !S.computed);
      return `<button class="step ${i === S.step ? 'on' : ''} ${locked ? 'lockd' : ''}" data-i="${i}" title="${esc(s)}">
        <span class="num">${i + 1}</span>${esc(s)}${locked ? '<span class="lock">' + ic(SVGI.lock) + '</span>' : ''}</button>`;
    }).join('');
    $('#steps').querySelectorAll('.step').forEach(b => b.onclick = () => go(+b.dataset.i));
  }
  function progressStrip() {
    const items = [['c_rf', S.computed], ['c_clu', S.computed], ['c_hv', !!S.best], ['c_med', S.computed]];
    return `<div class="prog" aria-label="${esc(t('progress'))}">` +
      items.map(([k, on]) => `<span class="prog-dot ${on ? 'done' : ''}"><span class="d"></span>${esc(t(k))}</span>`).join('<span style="color:var(--line)">·</span>') +
      `</div>`;
  }

  function setLang(l) {
    S.lang = l;
    endTour(); closeModal(); closePop(); hideTip();  // la guía se relanza ya en el idioma nuevo
    renderChrome(); render();
  }
  // acción explícita del usuario: ejecuta el análisis y luego navega
  function runThenGo(i) { computeThen(() => { S.step = i; renderSteps(); render(); }); }

  function go(i) {
    if (!S.data && i !== 0) { S.step = 0; renderSteps(); render(); toast(I18N[S.lang].none_first); return; }
    // Los pasos de resultados están bloqueados hasta ejecutar el análisis.
    // Antes el clic los auto-ejecutaba: el candado no gateaba nada y disparaba
    // un cálculo largo sin que nadie lo pidiera. Ahora manda a Configuración.
    if (RESULT_STEPS.indexOf(i) >= 0 && !S.computed) {
      S.step = 2; renderSteps(); render();
      toast(I18N[S.lang].run_first);
      const btn = document.getElementById('cfg-run');
      if (btn) {
        btn.classList.add('flash');
        setTimeout(() => btn.classList.remove('flash'), 1600);
        if (btn.scrollIntoView) btn.scrollIntoView({ block: 'center', behavior: 'smooth' });
      }
      return;
    }
    S.step = i; renderSteps(); render();
    const tab = document.querySelector('.step[data-i="' + i + '"]');
    if (tab && tab.scrollIntoView) tab.scrollIntoView({ inline: 'center', block: 'nearest' });
    if (typeof scrollTo === 'function') try { scrollTo({ top: 0, behavior: 'smooth' }); } catch (e) {}
  }

  /* ======================================================================
   * 9. Navegación inferior (prev/next) + barra de progreso
   * ==================================================================== */
  function navBar(mount) {
    const total = I18N[S.lang].steps.length;
    const prev = S.step > 0, next = S.step < total - 1;
    const wrap = document.createElement('div'); wrap.className = 'navbtns';
    wrap.innerHTML =
      `<button class="navbtn" ${prev ? '' : 'disabled'} id="nb-prev">${ic(SVGI.arrowL)}<span>${esc(t('nav_prev'))}</span></button>
       <button class="navbtn primary" ${next ? '' : 'disabled'} id="nb-next"><span>${esc(t('nav_next'))}</span>${ic(SVGI.arrowR)}</button>`;
    mount.appendChild(wrap);
    if (prev) $('#nb-prev', wrap).onclick = () => go(S.step - 1);
    if (next) $('#nb-next', wrap).onclick = () => {
      const nx = S.step + 1;
      // avanzar desde Configuración es pedir el análisis, no un clic perdido
      if (RESULT_STEPS.indexOf(nx) >= 0 && !S.computed) runThenGo(nx); else go(nx);
    };
  }

  /* ======================================================================
   * 10. Toolbar de exportación reutilizable
   * ==================================================================== */
  function toolbar(mount, buttons) {
    const bar = document.createElement('div'); bar.className = 'toolbar';
    buttons.forEach(b => {
      const el = document.createElement('button'); el.className = 'toolbtn' + (b.on ? ' on' : '');
      el.innerHTML = (b.icon || ic(SVGI.dl)) + '<span>' + esc(b.label) + '</span>';
      el.onclick = () => b.onClick(el); bar.appendChild(el);
    });
    mount.appendChild(bar); return bar;
  }
  function svgString(svg) {
    const clone = svg.cloneNode(true);
    // inline CSS vars usadas
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + new XMLSerializer().serializeToString(clone);
  }
  function svgToPng(svg, name, scale) {
    scale = scale || 2;
    const vb = svg.viewBox.baseVal, w = (vb && vb.width) || svg.clientWidth, h = (vb && vb.height) || svg.clientHeight;
    const data = svgString(resolveVars(svg));
    const img = new Image();
    img.onload = () => {
      const c = document.createElement('canvas'); c.width = w * scale; c.height = h * scale;
      const cx = c.getContext('2d'); cx.fillStyle = '#fff'; cx.fillRect(0, 0, c.width, c.height);
      cx.drawImage(img, 0, 0, c.width, c.height);
      c.toBlob(b => { const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = name; a.click(); URL.revokeObjectURL(a.href); toast(t('downloaded')); });
    };
    img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(data)));
  }
  // reemplaza var(--x) por su valor computado para exportar
  function resolveVars(svg) {
    const cs = getComputedStyle(document.documentElement);
    const map = {};
    ['--usach-teal', '--usach-teal-d', '--usach-teal-l', '--usach-orange', '--usach-slate', '--line', '--muted', '--ink', '--bg-strata', '--permian', '--triassic', '--jurassic', '--cretaceous', '--paleogene'].forEach(v => map[v] = cs.getPropertyValue(v).trim());
    const clone = svg.cloneNode(true);
    let s = clone.outerHTML;
    Object.keys(map).forEach(v => { s = s.split('var(' + v + ')').join(map[v]); });
    const wrap = document.createElement('div'); wrap.innerHTML = s; return wrap.firstChild;
  }

  /* ======================================================================
   * 11. Paneles
   * ==================================================================== */
  const MAIN = $('#main');
  // en móvil los árboles no se encogen: se deslizan
  const swipeHint = () => `<div class="swipe-hint">${ic(SVGI.swipe)}${esc(t('swipe'))}</div>`;

  function panel(html) { const p = document.createElement('div'); p.className = 'panel on'; p.innerHTML = html; return p; }

  function render() {
    MAIN.innerHTML = '';
    const fn = [pHome, pData, pConfig, pDistances, pMethod, pForest, pMedoid, pAges, pTemporality][S.step];
    const el = fn();
    MAIN.appendChild(el);
    navBar(el);
    renderFooter();
  }

  /* ---- Paso 0: Inicio ---- */
  /* De dónde salió lo que está cargado. Sin esto, el paso Inicio muestra la
     ficha del ejemplo y el usuario no distingue sus datos de la publicidad. */
  function handBanner() {
    const L = I18N[S.lang];
    if (S.handFailed) {
      return `<div class="warnbox" style="margin-bottom:14px">${ic(SVGI.info)}<div><b>${esc(L.hand_no_t)}</b>` +
        `<p>${esc(L.hand_no_p)}</p></div></div>`;
    }
    if (!S.data || S.data.key !== 'handoff') return '';
    return `<div class="warnbox ok" style="margin-bottom:14px">${ic(SVGI.check)}<div><b>${esc(L.hand_t)}</b>` +
      `<p>${esc(L.hand_p.replace('{n}', S.data.nTrees).replace('{l}', S.data.parsRef == null ? '?' : S.data.parsRef))}</p></div></div>`;
  }

  /* Inicio sin conjunto: el hero y los dos botones, nada más. */
  function pHomeEmpty() {
    const L = I18N[S.lang];
    const p = panel(`
      <div class="section-top">
        <div class="hero"><div class="hero-forest">${heroForestSVG()}</div><div class="hero-in">
          <div class="eyebrow" style="color:#8ee6dc">${esc(L.hero_eye)}</div>
          <h1>${esc(L.hero_h)}</h1>
          <p class="lead">${esc(L.hero_p)}</p>
          <div style="display:flex;flex-wrap:wrap;gap:11px;margin-top:24px">
            <button class="btn" id="e-ex">${ic(SVGI.arrowR)}${esc(L.hero_run)}</button>
            <button class="btn ghost" id="e-load">${esc(L.hero_load)}</button>
          </div>
        </div></div>
        ${handBanner()}
      </div>
      <div class="card pad" style="margin-top:18px">
        <div class="empty">
          <div class="ei">${ic(SVGI.info)}</div>
          <h4>${esc(L.none_h)}</h4>
          <p>${esc(L.none_p)}</p>
        </div>
      </div>`);
    $('#e-ex', p).onclick = () => { loadDataset(window.PF_DATA); toast(L.ds_loaded_ex); renderSteps(); render(); };
    $('#e-load', p).onclick = () => { loadDataset(window.PF_DATA); S.step = 1; renderSteps(); render(); };
    return p;
  }

  function pHome() {
    const L = I18N[S.lang];
    if (!S.data) return pHomeEmpty();
    const st = [
      [L.st_trees, S.data.nTrees],
      [L.st_taxa, S.data.nTaxa],
      [L.st_ages, Object.keys(S.data.ages || {}).length],
      [L.st_time, S.computed ? '✓' : '—']
    ];
    const p = panel(`
      <div class="section-top">
        <div class="hero"><div class="hero-forest">${heroForestSVG()}</div><div class="hero-in">
          <div class="eyebrow" style="color:#8ee6dc">${esc(L.hero_eye)}</div>
          <h1>${esc(L.hero_h)}</h1>
          <p class="lead">${esc(L.hero_p)}</p>
          <div style="display:flex;flex-wrap:wrap;gap:11px;margin-top:24px">
            <button class="btn" id="h-run">${ic(SVGI.arrowR)}${esc(L.hero_run)}</button>
            <button class="btn ghost" id="h-load">${esc(L.hero_load)}</button>
          </div>
        </div></div>
        ${handBanner()}
      </div>
      <div class="statrow" style="margin-bottom:18px">${st.map(([l, v]) => `<div class="stat"><div class="v">${v}</div><div class="l">${esc(l)}</div></div>`).join('')}</div>
      <div class="grid g2">
        <div class="card pad">
          <div class="eyebrow">${esc(L.ctx_h)} ${hchip('consensus')}</div>
          <p style="margin-top:12px;font-size:14.5px;color:var(--ink);line-height:1.65">${esc(L.ctx_p)}</p>
          <div class="notice" style="margin-top:14px">${ic(SVGI.info)}<div>${esc(L.ctx_p2)}</div></div>
        </div>
        <div class="card pad">
          <div class="eyebrow">${esc(L.how_h)}</div>
          <div class="flow" style="margin-top:8px">
            ${L.how.map((h, i) => `<div class="flow-step"><div class="flow-ic">${[flowI(0), flowI(1), flowI(2), flowI(3), flowI(4)][i]}</div><div><h4>${esc(h[0])} ${hchip(['rf', 'sil', 'hv', 'medoid', 'support'][i])}</h4><p>${esc(h[1])}</p></div></div>`).join('')}
          </div>
        </div>
      </div>`);
    $('#h-run', p).onclick = () => runThenGo(4);
    $('#h-load', p).onclick = () => go(1);
    return p;
  }
  function flowI(i) {
    const paths = [
      '<path d="M4 12h16M4 6h10M4 18h7"/>',
      '<circle cx="7" cy="8" r="2.4"/><circle cx="16" cy="7" r="2.4"/><circle cx="12" cy="16" r="2.4"/>',
      '<path d="M4 20V8l5-4 6 3 5-3v12l-5 3-6-3-5 4z"/>',
      '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5"/>',
      '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>'
    ];
    return `<svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${paths[i]}</svg>`;
  }

  /* ---- Paso 1: Datos ---- */
  function pData() {
    const L = I18N[S.lang];
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[1])}</div><h2>${esc(L.data_h)}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.data_p)}</p></div>
      <div class="grid g2">
        <div class="card pad">
          <div class="drop" id="drop"><p style="font-size:13.5px;color:var(--muted)">${esc(L.up_drop)}</p></div>
          <div style="margin-top:16px;display:grid;gap:14px">
            <div><label class="field">${esc(L.up_tre)} ${hchip('parsimony')}</label><input type="file" id="f-tre" accept=".tre,.tree,.nwk,.newick"></div>
            <div><label class="field">${esc(L.up_tnt)} ${hchip('clade')}</label><input type="file" id="f-tnt" accept=".tnt"></div>
            <div><label class="field">${esc(L.up_csv)} ${hchip('support')}</label><input type="file" id="f-csv" accept=".csv"></div>
          </div>
          <div style="display:flex;gap:11px;margin-top:18px">
            <button class="btn" id="d-analyze" disabled>${esc(L.btn_analyze)}</button>
            <button class="btn ghost" id="d-reset">${esc(L.btn_reset)}</button>
          </div>
          <div id="d-status"></div>
        </div>
        <div class="card pad">
          <div class="eyebrow">${esc(L.ds_example)}</div>
          <div class="exhero ${S.isExample ? '' : 'off'}">
            <div class="exh-top">
              <div>
                <div class="exh-name">Arackar licanantay</div>
                <div class="exh-group">Sauropoda (Titanosauria) · Rubilar-Rogers et al., 2021</div>
              </div>
              <span class="exh-badge">${esc(S.isExample ? L.ds_active : L.ds_example)}</span>
            </div>
            <p class="exh-desc">${esc(L.ds_example_p)}</p>
            <div class="exh-stats">
              <span><b>97</b> ${esc(L.st_trees.toLowerCase())}</span>
              <span><b>88</b> ${esc(L.st_taxa.toLowerCase())}</span>
              <span class="ok"><b>88</b> ${esc(L.st_ages.toLowerCase())}</span>
            </div>
            ${S.isExample ? '' : `<button class="btn ghost" id="d-back" style="margin-top:12px">${esc(L.btn_reset)}</button>`}
          </div>
          <div class="notice" style="margin-top:16px">${ic(SVGI.info)}<div>${L.ds_more_p}</div></div>
        </div>
      </div>
      <div class="card pad" style="margin-top:18px">
        ${handBanner()}
        <div class="eyebrow">${esc(L.ds_current)}</div>
        <div style="font-size:22px;font-weight:800;color:var(--usach-slate);margin:8px 0 2px;font-style:italic">${esc(S.data.name)}</div>
        <div class="statrow" style="margin-top:14px">
          <div class="stat"><div class="v">${S.data.nTrees}</div><div class="l">${esc(L.st_trees)}</div></div>
          <div class="stat"><div class="v">${S.data.nTaxa}</div><div class="l">${esc(L.st_taxa)}</div></div>
          <div class="stat"><div class="v">${Object.keys(S.data.ages || {}).length}</div><div class="l">${esc(L.st_ages)}</div></div>
          <div class="stat"><div class="v">${hasAges() ? '✓' : '—'}</div><div class="l">${esc(L.steps[8])}</div></div>
        </div>
        <div class="tbl-wrap" style="margin-top:16px;max-height:260px;overflow:auto">
          <table><thead><tr><th>${esc(L.st_taxa)}</th><th>FAD</th><th>LAD</th><th style="text-align:left">${esc(L.geo_hier)}</th></tr></thead><tbody>
          ${S.data.taxa.slice(0, 40).map(tx => { const a = (S.data.ages || {})[tx]; return `<tr><td style="font-style:italic">${esc(pretty(tx))}</td><td>${a ? a.fad : '—'}</td><td>${a ? a.lad : '—'}</td><td style="text-align:left">${a ? esc(geoLabel(a)) : '—'}</td></tr>`; }).join('')}
          </tbody></table>
        </div>
        ${S.data.taxa.length > 40 ? `<p class="hint" style="margin-top:8px">+ ${S.data.taxa.length - 40} ${esc(L.st_taxa.toLowerCase())}</p>` : ''}
      </div>
      ${parsConfigCard()}
      ${charEditorCard()}`);
    parsConfigWire(p);
    charEditorWire(p);
    const back = $('#d-back', p);
    if (back) back.onclick = () => confirmReset(() => {
      loadDataset(window.PF_DATA); S.handFailed = false; toast(L.btn_reset); renderSteps(); render();
    });
    // manejo de carga
    const files = { tre: null, tnt: null, csv: null };
    const chk = () => $('#d-analyze', p).disabled = !(files.tre && files.tnt);
    ['tre', 'tnt', 'csv'].forEach(k => { $('#f-' + k, p).onchange = e => { files[k] = e.target.files[0]; chk(); }; });
    $('#d-reset', p).onclick = () => confirmReset(() => {
      loadDataset(window.PF_DATA); S.handFailed = false; toast(L.btn_reset); render(); renderSteps();
    });
    $('#d-analyze', p).onclick = () => handleUpload(files, $('#d-status', p));
    // drag&drop
    const drop = $('#drop', p);
    ['dragover', 'dragenter'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.add('hi'); }));
    ['dragleave', 'drop'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.remove('hi'); }));
    drop.addEventListener('drop', e => {
      [...e.dataTransfer.files].forEach(f => {
        const n = f.name.toLowerCase();
        if (n.endsWith('.tnt')) { files.tnt = f; $('#f-tnt', p).files = mkFL(f); }
        else if (n.endsWith('.csv')) { files.csv = f; }
        else { files.tre = f; }
      }); chk();
    });
    return p;
  }
  function mkFL() { return undefined; } // (algunos navegadores no permiten set files; se ignora visualmente)

  function handleUpload(files, statusEl) {
    const rd = f => new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = rej; r.readAsText(f, 'latin1'); });
    Promise.all([rd(files.tre), rd(files.tnt), files.csv ? rd(files.csv) : Promise.resolve('')]).then(([treTxt, tntTxt, csvTxt]) => {
      try {
        const taxa = parseTNTtaxa(tntTxt);
        const newicks = parseTREfile(treTxt, taxa);
        if (!newicks.length) throw new Error('trees');
        const ages = csvTxt ? parseAges(csvTxt) : {};
        loadDataset({ key: null, name: files.tre.name.replace(/\.[^.]+$/, ''), group: '', taxa, newicks, ages, nTrees: newicks.length, nTaxa: taxa.length });
        statusEl.innerHTML = `<div class="notice" style="margin-top:14px">${ic(SVGI.check)}<div>${newicks.length} ${esc(t('st_trees').toLowerCase())} · ${taxa.length} ${esc(t('st_taxa').toLowerCase())}</div></div>`;
        toast(t('compute_done')); renderSteps(); setTimeout(() => go(2), 400);   // -> Configuración
      } catch (err) {
        statusEl.innerHTML = `<div class="notice" style="margin-top:14px;background:rgba(214,69,69,.08);border-color:rgba(214,69,69,.3)">${ic(SVGI.info)}<div>${esc(t('run_first'))} (${esc(String(err.message || err))})</div></div>`;
      }
    });
  }
  // parsers de subida (espejo de prep.py, tolerantes)

  /* Matriz de caracteres TNT -> { taxon: [tokens] }.
     Tolera nombres entre comillas y polimorfismos [01]; el nº de columnas se
     cuenta DESPUÉS de tokenizar, porque "[01]" son 4 caracteres y 1 columna. */
  function parseTNTMatrix(raw) {
    const lines = raw.split(/\r?\n/);
    let di = -1, ntax = 0;
    for (let i = 0; i < lines.length; i++) if (/^\s*xread/i.test(lines[i])) {
      for (let j = i + 1; j < i + 6 && j < lines.length; j++) {
        const m = lines[j].match(/^\s*'*\s*(\d+)\s+(\d+)\s*$/);
        if (m) { di = j; ntax = +m[2]; break; }
      }
      break;
    }
    if (di < 0) return null;
    const out = {}; let k = di + 1, n = 0;
    while (k < lines.length && n < ntax) {
      const l = lines[k].replace(/\r$/, ''); k++;
      const t = l.trim();
      if (!t || t.startsWith('&')) continue;
      if (t === ';' || /^\s*proc/i.test(l)) break;
      const m = l.match(/^(\S+)\s+(.+)$/);
      if (m) { out[m[1].replace(/^'|'$/g, '')] = tntTokens(m[2].trim()); n++; }
    }
    return out;
  }

  function parseTNTtaxa(raw) {
    const lines = raw.split(/\r?\n/); let di = -1, ntax = 0;
    for (let i = 0; i < lines.length; i++) if (/^\s*xread/i.test(lines[i])) {
      for (let j = i + 1; j < i + 6 && j < lines.length; j++) { const m = lines[j].match(/^\s*(\d+)\s+(\d+)\s*$/); if (m) { di = j; ntax = +m[2]; break; } } break;
    }
    if (di < 0) throw new Error('TNT xread');
    const taxa = []; let k = di + 1;
    while (k < lines.length && taxa.length < ntax) {
      const l = lines[k].replace(/\r$/, ''); k++;
      if (!l.trim() || l.trim().startsWith('&')) continue;
      if (l.trim() === ';' || /^\s*proc/i.test(l)) break;
      const m = l.match(/^(\S+)\s+(.+)$/); if (m) taxa.push(m[1].replace(/^'|'$/g, ''));
    }
    return taxa;
  }
  function parseTREfile(raw, taxa) {
    const lines = raw.split(/\r?\n/).filter(l => l.trim().startsWith('('));
    // Si los árboles ya usan nombres (contienen letras), se dejan; si son índices TNT, se mapean.
    return lines.map(l => {
      if (/[A-Za-z_]{2,}/.test(l.replace(/tread|proc/gi, ''))) return l.trim().replace(/\*?;?\s*$/, '') + ';';
      return tntToNewick(l, taxa);
    });
  }
  function tntToNewick(s, names) {
    s = s.trim().replace(/\*?;?\s*$/, ''); let pos = 0;
    function parse() {
      pos++; const ch = [];
      while (true) {
        while (s[pos] === ' ') pos++;
        if (s[pos] === '(') ch.push(parse());
        else if (s[pos] === ')') { pos++; break; }
        else { const m = s.slice(pos).match(/^\d+/); const num = +m[0]; pos += m[0].length; ch.push((names[num] || ('t' + num)).replace(/ /g, '_')); }
      }
      return '(' + ch.join(',') + ')';
    }
    while (s[pos] === ' ') pos++;
    return parse() + ';';
  }
  function parseAges(raw) {
    const lines = raw.split(/\r?\n/); const sep = lines[0].indexOf(';') >= 0 ? ';' : ','; const h = lines[0].replace(/\r$/, '').split(sep).map(x => x.trim().toUpperCase());
    const ci = n => h.indexOf(n); const cT = ci('TIPS'), cF = ci('FIRST'), cL = ci('LAST'),
      cEon = ci('INI_EON'), cEra = ci('INI_ERA'), cPer = ci('INI_PERIOD'), cEp = ci('INI_EPOCH'), cAge = ci('INI_AGE'), cD = ci('DIET');
    const g = (c, i) => (i >= 0 && i < c.length ? (c[i] || '').trim() : '');
    const out = {};
    for (let i = 1; i < lines.length; i++) {
      const r = lines[i].replace(/\r$/, ''); if (!r.trim()) continue;
      const c = r.split(sep); const fad = parseFloat(c[cF]), lad = parseFloat(c[cL]);
      if (isNaN(fad) || isNaN(lad)) continue;
      out[c[cT].trim()] = {
        fad, lad, eon: g(c, cEon), era: g(c, cEra), period: g(c, cPer),
        epoch: g(c, cEp), stage: g(c, cAge), diet: g(c, cD)
      };
    }
    return out;
  }


  /* Aviso: el consenso estricto venía en el .tre y se excluyó del análisis.
     TNT lo deja pegado al final; no es un árbol más parsimonioso y, por
     monotonía de Fitch/Wagner, nunca puede costar menos que los resueltos. */
  function consensusNotice() {
    const L = I18N[S.lang];
    if (!S.consensus || !S.consensus.length) return '';
    const list = S.consensus.map(c =>
      `<li><b>${L.for_tree} #${c.n}</b> — ${L.cons_poly.replace('{n}', c.deg)}</li>`).join('');
    return `<div class="warnbox ok">${ic(SVGI.check)}
      <div><b>${esc(L.cons_h)}</b>
        <p>${esc(L.cons_p)}</p>
        <ul>${list}</ul>
        <p class="hint" style="margin-top:8px">${esc(L.cons_note)}</p>
        <button class="toolbtn" id="cons-keep">${esc(L.cons_keep)}</button>
      </div></div>`;
  }
  // árboles que, aun sin ser consenso, no son más parsimoniosos
  function parsNotice() {
    const L = I18N[S.lang];
    if (!S.pars || !S.notMP || !S.notMP.length) return '';
    const list = S.notMP.map(i => {
      const poly = S.deg && S.deg[i] > 2 ? ` · ${L.pars_poly.replace('{n}', S.deg[i])}` : '';
      return `<li><b>${L.for_tree} #${i + 1}</b> — ${L.pars_score}: <span class="mono">${S.pars[i]}</span>
        (${L.pars_vs} <span class="mono">${S.parsBest}</span>)${poly}</li>`;
    }).join('');
    return `<div class="warnbox">${ic(SVGI.info)}
      <div><b>${esc(L.pars_warn_h)}</b>
        <p>${esc(L.pars_warn_p)}</p>
        <ul>${list}</ul>
        <p class="hint" style="margin-top:8px">${esc(L.pars_warn_note)}</p>
        <button class="toolbtn" id="pars-drop">${esc(L.pars_drop)}</button>
      </div></div>`;
  }
  function parsNoticeWire(p) {
    const keep = $('#cons-keep', p);
    if (keep) keep.onclick = () => {
      S.keepConsensus = true;
      loadDataset(S.source || window.PF_DATA, S.sourceTag);   // el conjunto actual, no el ejemplo
      toast(I18N[S.lang].cons_kept);
      go(2);   // Configuración
    };
    const b = $('#pars-drop', p);
    if (b) b.onclick = () => {
      const idx = S.trees.map((_, i) => i).filter(i => S.notMP.indexOf(i) < 0);
      const d = JSON.parse(JSON.stringify(S.data));
      d.newicks = idx.map(i => S.data.newicks[i]);
      d.nTrees = d.newicks.length;
      S.keepConsensus = true;   // ya están filtrados; no volver a tocar
      loadDataset(d);
      toast(I18N[S.lang].pars_dropped.replace('{n}', d.nTrees));
      go(2);   // Configuración
    };
  }


  /* ==================================================================
   * Ajuste de la matriz para el cálculo de parsimonia.
   *
   * Existe porque los propios autores tuvieron que ajustarla: la carpeta trae
   * dos matrices que difieren en 3 columnas y un bloque `ccode` que no
   * reproduce el puntaje publicado. El criterio de validación no es "cuadra
   * con el número esperado" sino algo más fuerte: TODOS los árboles más
   * parsimoniosos de una misma búsqueda deben dar el MISMO puntaje. Si dan
   * puntajes distintos, el ajuste está mal.
   * ================================================================== */
  function parsConfigCard() {
    const L = I18N[S.lang];
    const cfg = S.parsCfg;
    const has = S.data.matrix && Object.keys(S.data.matrix).length;
    if (!has) return `<div class="card pad" style="margin-top:18px">
      <div class="eyebrow">${esc(L.pc_h)}</div>
      <p class="hint" style="margin-top:8px">${ic(SVGI.info)}${esc(L.pc_nomatrix)}</p>
      <button class="toolbtn" id="pc-load" style="margin-top:10px">${esc(L.pc_load)}</button>
      <input type="file" id="pc-file" accept=".tnt,.txt" hidden></div>`;
    return `<div class="card pad" style="margin-top:18px">
      <div class="eyebrow">${esc(L.pc_h)} ${hchip('ccode')}</div>
      <p class="hint" style="margin:8px 0 14px">${ic(SVGI.info)}${esc(L.pc_p)}</p>
      <div class="pcgrid">
        <div>
          <label class="field">${esc(L.pc_gap)} ${hchip('gap')}</label>
          <div class="lvls">
            <button class="lvl${!cfg.gapAsState ? ' on' : ''}" data-gap="0">${esc(L.pc_gap_missing)}</button>
            <button class="lvl${cfg.gapAsState ? ' on' : ''}" data-gap="1">${esc(L.pc_gap_state)}</button>
          </div>
        </div>
        <div>
          <label class="field">${esc(L.pc_matrix)} ${hchip('matrix')}</label>
          <div class="pcmx mono">${esc(cfg.matrixName || L.pc_matrix_ds)}</div>
        </div>
      </div>
      <div class="toolbar" style="margin-top:14px">
        <button class="btn" id="pc-run">${ic(SVGI.check)}${esc(L.pc_check)}</button>
        <button class="toolbtn" id="pc-load">${esc(L.pc_load)}</button>
        <button class="toolbtn" id="pc-reset">${esc(L.pc_reset)}</button>
        <input type="file" id="pc-file" accept=".tnt,.txt" hidden>
      </div>
      <div id="pc-out"></div>
    </div>`;
  }

  function parsConfigWire(p) {
    const L = I18N[S.lang], cfg = S.parsCfg;
    const file = $('#pc-file', p), load = $('#pc-load', p);
    if (load) load.onclick = () => file.click();
    if (file) file.onchange = e => {
      const f = e.target.files[0]; if (!f) return;
      const r = new FileReader();
      r.onload = () => {
        const m = parseTNTMatrix(r.result);
        if (!m || !Object.keys(m).length) { toast(L.pc_badmatrix); return; }
        const miss = S.data.taxa.filter(t => !m[t]).length;
        S.data.matrix = m;
        S.parsCfg.matrixName = f.name;
        const cc = parseCcode(r.result);
        if (cc && cc.length) { S.parsCfg.ordered = cc.slice(); S.parsCfg.base = 0; toast(L.pc_ccode_ok.replace('{n}', cc.length)); }
        else toast(L.pc_matrix_ok.replace('{n}', Object.keys(m).length));
        if (miss) toast(L.pc_missing.replace('{n}', miss));
        render();
      };
      r.readAsText(f);
    };
    if (!$('#pc-run', p)) return;
    p.querySelectorAll('[data-gap]').forEach(b => b.onclick = () => {
      cfg.gapAsState = b.dataset.gap === '1';
      p.querySelectorAll('[data-gap]').forEach(x => x.classList.toggle('on', (x.dataset.gap === '1') === cfg.gapAsState));
    });
    $('#pc-reset', p).onclick = () => {
      S.parsCfg = defaultParsCfg(); render();
    };
    $('#pc-run', p).onclick = () => {
      const out = $('#pc-out', p);
      out.innerHTML = `<p class="hint" style="margin-top:12px">${esc(L.pc_running)}</p>`;
      setTimeout(() => {
        const sc = S.trees.map(t => parsimonyScoreEx(t, S.data.matrix, cfg));
        const tally = {};
        sc.forEach(v => tally[v] = (tally[v] || 0) + 1);
        const vals = Object.keys(tally).map(Number).sort((a, b) => a - b);
        const uniform = vals.length === 1;
        const ref = S.data.parsRef;
        const okExp = ref == null ? null : (uniform && vals[0] === ref);
        const rows = vals.map(v => `<tr><td class="mono">${v}</td><td>${tally[v]}</td></tr>`).join('');
        out.innerHTML = `
          <div class="pcres ${uniform ? 'ok' : 'bad'}">
            ${ic(uniform ? SVGI.check : SVGI.info)}
            <div>
              <b>${esc(uniform ? L.pc_uniform : L.pc_split)}</b>
              <p>${esc(uniform ? L.pc_uniform_p : L.pc_split_p)}</p>
              <table class="pctbl"><thead><tr><th>${esc(L.pars_score)}</th><th>${esc(L.st_trees)}</th></tr></thead>
                <tbody>${rows}</tbody></table>
              ${okExp === null ? '' : `<p class="pcexp ${okExp ? 'ok' : 'bad'}">${okExp
                ? ic(SVGI.check) + esc(L.pc_match.replace('{n}', ref).replace('{s}', S.data.parsRefSrc || ''))
                : ic(SVGI.info) + esc(L.pc_nomatch.replace('{n}', ref).replace('{s}', S.data.parsRefSrc || ''))}</p>`}
              <p class="hint" style="margin-top:8px">${esc(L.pc_cfg_now
                .replace('{o}', cfg.ordered.length)
                .replace('{g}', cfg.gapAsState ? L.pc_gap_state : L.pc_gap_missing))}</p>
              ${uniform ? `<button class="toolbtn" id="pc-apply">${esc(L.pc_apply)}</button>` : ''}
            </div>
          </div>`;
        const ap = $('#pc-apply', p);
        if (ap) ap.onclick = () => {
          S.applied = { ordered: cfg.ordered.slice(), inactive: cfg.inactive.slice(),
            weights: Object.assign({}, cfg.weights), nst: cfg.nst, gapAsState: cfg.gapAsState };
          S.data.ordered = cfg.ordered.slice();
          S.computed = false;
          toast(L.pc_applied); renderSteps(); go(2);   // Configuración
        };
      }, 30);
    };
  }

  function defaultParsCfg() {
    return {
      ordered: (S.data && S.data.ordered ? S.data.ordered.slice() : []),
      inactive: [], weights: {},
      base: 0, gapAsState: false, nst: 8,
      matrixName: null, filter: 'all', page: 0
    };
  }

  /* ==================================================================
   * Editor de caracteres (equivalente al bloque `ccode` de TNT)
   *   +  aditivo / ordenado      -> Wagner
   *   -  no aditivo              -> Fitch
   *   [ ]  activar / desactivar
   *   /N   peso
   * Es lo que se ajusta en un paper: Rubilar-Rogers et al. (2021) declararon
   * 24 caracteres como ordenados, y ese ajuste vale 13 pasos en Arackar.
   * ================================================================== */
  const PC_PAGE = 60;
  function charEditorCard() {
    const L = I18N[S.lang], cfg = S.parsCfg;
    if (!S.data.matrix || !Object.keys(S.data.matrix).length) return '';
    const nchar = S.data.matrix[Object.keys(S.data.matrix)[0]].length;
    const ord = new Set(cfg.ordered), off = new Set(cfg.inactive);
    let idx = Array.from({ length: nchar }, (_, i) => i);
    if (cfg.filter === 'ord') idx = idx.filter(i => ord.has(i));
    else if (cfg.filter === 'off') idx = idx.filter(i => off.has(i));
    else if (cfg.filter === 'w') idx = idx.filter(i => cfg.weights[i] != null && cfg.weights[i] !== 1);
    const pages = Math.max(1, Math.ceil(idx.length / PC_PAGE));
    const page = Math.min(cfg.page, pages - 1);
    const slice = idx.slice(page * PC_PAGE, page * PC_PAGE + PC_PAGE);
    const rows = slice.map(i => {
      const st = charStates(S.data.matrix, i);
      const w = cfg.weights[i] == null ? 1 : cfg.weights[i];
      return `<tr class="${off.has(i) ? 'off' : ''}" data-c="${i}">
        <td class="mono">${i}<span class="c1">/${i + 1}</span></td>
        <td><button class="pcb ${ord.has(i) ? 'on' : ''}" data-tog="ord" data-c="${i}">${ord.has(i) ? '+' : '−'}</button></td>
        <td><button class="pcb ${off.has(i) ? 'no' : 'on'}" data-tog="act" data-c="${i}">${off.has(i) ? ']' : '['}</button></td>
        <td><input class="pcw" type="number" min="0" step="1" value="${w}" data-c="${i}"></td>
        <td class="mono st">${st.states.join(' ') || '—'}</td>
        <td class="mono dim">${st.missing}?${st.gaps ? ' · ' + st.gaps + '-' : ''}${st.poly ? ' · ' + st.poly + '[]' : ''}</td>
      </tr>`;
    }).join('');
    return `<div class="card pad" style="margin-top:18px">
      <div class="toolbar" style="margin-bottom:6px">
        <div class="eyebrow" style="flex:1">${esc(L.ce_h)} ${hchip('ccode')}</div>
        <span class="field" style="margin:0">${esc(L.pc_base)} ${hchip('base')}</span>
        <div class="lvls" id="ce-base">
          <button class="lvl${cfg.base === 0 ? ' on' : ''}" data-base="0">0</button>
          <button class="lvl${cfg.base === 1 ? ' on' : ''}" data-base="1">1</button>
        </div>
      </div>
      <div class="toolbar" style="margin-bottom:10px">
        <div class="lvls" id="ce-filter">
          ${[['all', L.ce_all + ' (' + nchar + ')'], ['ord', '+ ' + cfg.ordered.length],
      ['off', '] ' + cfg.inactive.length], ['w', '/ ' + Object.keys(cfg.weights).filter(k => cfg.weights[k] !== 1).length]]
        .map(([k, lb]) => `<button class="lvl${cfg.filter === k ? ' on' : ''}" data-f="${k}">${esc(lb)}</button>`).join('')}
        </div>
      </div>
      <p class="hint" style="margin-bottom:10px">${ic(SVGI.info)}${esc(L.ce_p)}</p>
      <div class="tbl-wrap" style="max-height:340px;overflow:auto">
        <table class="cetbl"><thead><tr>
          <th>${esc(L.ce_char)} ${hchip('base')}</th><th>${esc(L.ce_add)} ${hchip('ordered')}</th><th>${esc(L.ce_act)} ${hchip('active')}</th>
          <th>${esc(L.ce_w)} ${hchip('weight')}</th><th>${esc(L.ce_states)}</th><th>${esc(L.ce_cov)} ${hchip('gap')}</th>
        </tr></thead><tbody>${rows || `<tr><td colspan="6" style="text-align:center;color:var(--muted);padding:16px">${esc(L.ce_none)}</td></tr>`}</tbody></table>
      </div>
      <div class="toolbar" style="margin-top:10px">
        <button class="toolbtn" id="ce-prev" ${page === 0 ? 'disabled' : ''}>←</button>
        <span class="mono" style="font-size:11.5px;color:var(--muted)">${page + 1} / ${pages}</span>
        <button class="toolbtn" id="ce-next" ${page >= pages - 1 ? 'disabled' : ''}>→</button>
        <span style="flex:1"></span>
        <button class="toolbtn" id="ce-paste">${esc(L.ce_paste)}</button>
        <button class="toolbtn" id="pc-ccode">${esc(L.pc_ccode)}</button>
        <button class="toolbtn" id="ce-export">${ic(SVGI.copy)}${esc(L.ce_export)}</button>
      </div>
    </div>`;
  }

  function charEditorWire(p) {
    const cfg = S.parsCfg, L = I18N[S.lang];
    p.querySelectorAll('#ce-filter .lvl').forEach(b => b.onclick = () => { cfg.filter = b.dataset.f; cfg.page = 0; render(); });
    const prev = $('#ce-prev', p), next = $('#ce-next', p);
    if (prev) prev.onclick = () => { cfg.page = Math.max(0, cfg.page - 1); render(); };
    if (next) next.onclick = () => { cfg.page = cfg.page + 1; render(); };
    p.querySelectorAll('[data-tog]').forEach(b => b.onclick = () => {
      const c = +b.dataset.c;
      if (b.dataset.tog === 'ord') {
        const i = cfg.ordered.indexOf(c);
        if (i >= 0) cfg.ordered.splice(i, 1); else cfg.ordered.push(c);
        cfg.ordered.sort((x, y) => x - y);
      } else {
        const i = cfg.inactive.indexOf(c);
        if (i >= 0) cfg.inactive.splice(i, 1); else cfg.inactive.push(c);
        cfg.inactive.sort((x, y) => x - y);
      }
      render();
    });
    p.querySelectorAll('.pcw').forEach(inp => inp.onchange = () => {
      const c = +inp.dataset.c, v = parseInt(inp.value, 10);
      if (isNaN(v) || v === 1) delete cfg.weights[c]; else cfg.weights[c] = v;
      render();
    });
    const ex = $('#ce-export', p);
    if (ex) ex.onclick = () => copy(buildCcode());

    // numeración: solo afecta a cómo se LEEN y se MUESTRAN los números
    p.querySelectorAll('#ce-base .lvl').forEach(b => b.onclick = () => {
      cfg.base = +b.dataset.base; render();
    });

    // leer el ccode del .tnt del conjunto
    const cc = $('#pc-ccode', p);
    if (cc) cc.onclick = () => {
      const raw = S.data.rawCcode;
      const list = raw ? parseCcode(raw) : null;
      if (!list || !list.length) { toast(L.pc_noccode); return; }
      cfg.ordered = list.slice(); cfg.base = 0; cfg.filter = 'ord'; cfg.page = 0;
      toast(L.pc_ccode_ok.replace('{n}', list.length));
      render();
    };

    // pegado masivo: útil para transcribir la lista de un paper de una vez
    const ps = $('#ce-paste', p);
    if (ps) ps.onclick = () => {
      openModal(L.ce_paste_h, `
        <p class="hint" style="margin-bottom:10px">${esc(L.ce_paste_p.replace('{b}', cfg.base))}</p>
        <textarea id="ce-pt" class="pcin" rows="4" placeholder="14, 61, 100, 276-279, 299">${esc(charListToText(cfg.ordered, cfg.base))}</textarea>
        <div style="display:flex;gap:10px;margin-top:14px">
          <button class="btn" id="ce-pt-ok">${esc(L.ce_paste_ok)}</button>
          <button class="btn ghost" id="ce-pt-no">${esc(L.cancel || 'Cancelar')}</button>
        </div>`);
      $('#ce-pt-ok', modalBk).onclick = () => {
        cfg.ordered = parseCharList($('#ce-pt', modalBk).value, cfg.base);
        cfg.filter = 'ord'; cfg.page = 0;
        closeModal(); toast(L.ce_paste_done.replace('{n}', cfg.ordered.length)); render();
      };
      $('#ce-pt-no', modalBk).onclick = closeModal;
    };
  }

  // reconstruye un bloque `ccode` de TNT a partir del ajuste actual
  function buildCcode() {
    const cfg = S.parsCfg;
    const rng = arr => {
      const out = []; let i = 0;
      const a = arr.slice().sort((x, y) => x - y);
      while (i < a.length) {
        let j = i; while (j + 1 < a.length && a[j + 1] === a[j] + 1) j++;
        out.push(j > i + 1 ? a[i] + '.' + a[j] : a.slice(i, j + 1).join(' '));
        i = j + 1;
      }
      return out.join(' ');
    };
    const parts = [];
    if (cfg.ordered.length) parts.push('+ ' + rng(cfg.ordered));
    if (cfg.inactive.length) parts.push('] ' + rng(cfg.inactive));
    Object.keys(cfg.weights).forEach(c => { if (cfg.weights[c] !== 1) parts.push('/' + cfg.weights[c] + ' ' + c); });
    return 'ccode ' + parts.join(' ') + ' *;\n';
  }

  /* ==================================================================
   * Paso 2: Edades fósiles — PaleoDB + ingreso manual
   * Replica el flujo del pipeline original: si el taxón no trae anotación,
   * se consulta la Paleobiology Database; lo que siga faltando (o quede
   * ambiguo) se completa a mano.
   * ================================================================== */
  function ageOf(tx) { return S.data.ages[tx] || null; }
  function setAge(tx, fad, lad, src, extra) {
    if (fad == null || lad == null || isNaN(fad) || isNaN(lad)) { delete S.data.ages[tx]; delete S.ageSrc[tx]; return; }
    if (fad < lad) { const s = fad; fad = lad; lad = s; }   // FAD siempre más antiguo
    const h = GEO.hierarchyAt(fad);
    S.data.ages[tx] = Object.assign({
      fad: fad, lad: lad, eon: h.eon, era: h.era, period: h.period, epoch: h.epoch, stage: h.stage, diet: ''
    }, extra || {});
    S.ageSrc[tx] = src;
    S.computed = S.computed; // las edades no invalidan el clustering (solo la temporalidad)
  }
  function missingTaxa() { return S.data.taxa.filter(tx => !S.data.ages[tx]); }

  /* Imputación de edades faltantes.

     La envolvente (FAD más antiguo, LAD más joven) es honesta como declaración
     de ignorancia, pero en el árbol temporal deja al taxón como el más antiguo
     del conjunto: se ve como un dato fuerte, no como un hueco. La media de los
     FAD y de los LAD lo deja donde está la masa de los datos y no deforma los
     extremos. Es imputación por la media, con lo que eso implica: reduce la
     varianza y no es un dato. Por eso va marcada aparte. */
  function ageStats() {
    let fs = [], ls = [];
    S.data.taxa.forEach(tx => {
      const a = S.data.ages[tx];
      if (!a || S.ageSrc[tx] === 'env') return;
      fs.push(a.fad); ls.push(a.lad);
    });
    if (!fs.length) return null;
    const mean = v => v.reduce((x, y) => x + y, 0) / v.length;
    return { fad: Math.round(mean(fs) * 100) / 100, lad: Math.round(mean(ls) * 100) / 100 };
  }
  /* Se corre sola al cargar el conjunto: si falta una edad, imputarla es mejor
     que dejar al taxón fuera del árbol temporal. No hay botón. */
  function imputeMissing() {
    const m = ageStats();
    if (!m) return 0;
    const miss = missingTaxa();
    miss.forEach(tx => setAge(tx, m.fad, m.lad, 'env'));
    return miss.length;
  }

  function pAges() {
    const L = I18N[S.lang];
    const withAge = S.data.taxa.filter(tx => S.data.ages[tx]).length;
    const missing = missingTaxa().length;
    const p = panel(`
      ${S.imputed ? `<div class="warnbox" style="margin-bottom:16px">${ic(SVGI.info)}<div><b>${esc(L.ag_imp_t.replace('{n}', S.imputed))}</b><p>${L.ag_imp_p}</p></div></div>` : ''}
      <div class="section-top"><div class="eyebrow">${esc(L.steps[7])}</div><h2>${esc(L.ag_h)} ${hchip('fad')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.ag_p)}</p></div>

      <div class="card pad">
        <div class="statrow" style="grid-template-columns:repeat(3,1fr)">
          <div class="stat"><div class="v">${S.data.nTaxa}</div><div class="l">${esc(L.st_taxa)}</div></div>
          <div class="stat"><div class="v" style="color:var(--usach-teal-d)">${withAge}</div><div class="l">${esc(L.ag_with)}</div></div>
          <div class="stat"><div class="v" style="color:${missing ? 'var(--usach-orange)' : 'var(--muted)'}">${missing}</div><div class="l">${esc(L.ag_missing)}</div></div>
        </div>
        <div class="toolbar" style="margin-top:16px">
          <button class="btn" id="ag-pbdb"${missing ? '' : ' disabled'}>${ic(SVGI.globe)}${esc(L.ag_query)}</button>
          <button class="toolbtn" id="ag-pbdb-all">${esc(L.ag_query_all)}</button>
          <span style="flex:1"></span>
          <button class="toolbtn" id="ag-strat">${ic(SVGI.globe)}${esc(L.ms_btn)}</button>
          <button class="toolbtn" id="ag-csv"${withAge ? '' : ' disabled'}>${ic(SVGI.copy)}${esc(L.ag_export)}</button>
          <button class="toolbtn" id="ag-clear"${withAge ? '' : ' disabled'}>${esc(L.ag_clear)}</button>
        </div>
        <p class="hint" style="margin-top:10px">${ic(SVGI.info)}${esc(L.ag_net)}</p>
        <div id="ag-status"></div>
      </div>

      <div class="card pad" style="margin-top:18px">
        <div class="toolbar" style="margin-bottom:12px">
          <div class="eyebrow">${esc(L.ag_table)}</div>
          <div class="spacer"></div>
          <div class="searchbox">
            ${ic(SVGI.search)}
            <input id="ag-q" type="search" placeholder="${esc(L.ag_find)}" aria-label="${esc(L.ag_find)}">
          </div>
          <select id="ag-filter" class="tysel" aria-label="${esc(L.ag_filter)}">
            <option value="">${esc(L.ag_f_all)}</option>
            <option value="env">${esc(L.src_env)}</option>
            <option value="manual">${esc(L.src_manual)}</option>
            <option value="pbdb">${esc(L.src_pbdb)}</option>
            <option value="strat">${esc(L.src_strat)}</option>
            <option value="csv">${esc(L.src_csv)}</option>
            <option value="none">${esc(L.ag_f_none)}</option>
          </select>
        </div>
        <div class="tbl-wrap" style="max-height:520px;overflow:auto">
          <table class="agetbl"><thead><tr>
            <th style="text-align:left">${esc(L.st_taxa)}</th>
            <th>FAD (Ma)</th><th>LAD (Ma)</th>
            <th style="text-align:left">${esc(L.geo_hier)}</th>
            <th>${esc(L.ag_source)}</th>
          </tr></thead><tbody id="ag-body"></tbody></table>
        </div>
        <p class="hint" style="margin-top:10px">${ic(SVGI.info)}${esc(L.ag_manual_hint)}</p>
      </div>`);

    const only = { src: '', q: '' };
    function rows() {
      let list = S.data.taxa;
      if (only.src === 'none') list = missingTaxa();
      else if (only.src) list = list.filter(tx => (S.ageSrc[tx] || '') === only.src);
      const q = only.q.trim().toLowerCase();
      if (q) list = list.filter(tx => pretty(tx).toLowerCase().indexOf(q) >= 0);
      if (!list.length) return `<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:20px">${esc(q ? L.ag_no_hits : L.ag_all_done)}</td></tr>`;
      return list.map(tx => {
        const a = ageOf(tx), src = S.ageSrc[tx] || '';
        const badge = src ? `<span class="srcb ${src}">${esc(L['src_' + src] || src)}</span>` : `<span class="srcb none">${esc(L.src_none)}</span>`;
        return `<tr data-tx="${esc(tx)}">
          <td style="text-align:left;font-style:italic">${esc(pretty(tx))}</td>
          <td><input class="ain" type="number" step="0.1" min="0" data-f="fad" value="${a ? a.fad : ''}" placeholder="—"></td>
          <td><input class="ain" type="number" step="0.1" min="0" data-f="lad" value="${a ? a.lad : ''}" placeholder="—"></td>
          <td style="text-align:left;font-size:12px;color:var(--muted)">${a ? esc(geoLabel(a)) : '—'}</td>
          <td>${badge}</td></tr>`;
      }).join('');
    }
    function paint() {
      $('#ag-body', p).innerHTML = rows();
      p.querySelectorAll('.ain').forEach(inp => {
        inp.onchange = () => {
          const tr = inp.closest('tr'), tx = tr.dataset.tx;
          const fad = parseFloat($('.ain[data-f="fad"]', tr).value);
          const lad = parseFloat($('.ain[data-f="lad"]', tr).value);
          if (isNaN(fad) || isNaN(lad)) { toast(L.ag_need_both); return; }
          setAge(tx, fad, lad, 'manual');
          toast(L.ag_saved); paint(); refreshHead();
        };
      });
    }
    function refreshHead() { renderSteps(); const w = S.data.taxa.filter(tx => S.data.ages[tx]).length; const m = S.data.nTaxa - w; const st = p.querySelectorAll('.stat .v'); if (st[1]) st[1].textContent = w; if (st[2]) st[2].textContent = m; $('#ag-pbdb', p).disabled = !m; $('#ag-csv', p).disabled = !w; $('#ag-clear', p).disabled = !w; }
    paint();

    $('#ag-filter', p).onchange = e => { only.src = e.target.value; paint(); };
    $('#ag-q', p).oninput = e => { only.q = e.target.value; paint(); };
    $('#ag-q', p).onkeydown = e => { if (e.key === 'Escape') { e.target.value = ''; only.q = ''; paint(); } };
    $('#ag-pbdb', p).onclick = () => queryPBDB(missingTaxa(), $('#ag-status', p), () => {
      S.imputed = imputeMissing();   // lo que PaleoDB no resuelve, se imputa
      render();
    });
    $('#ag-pbdb-all', p).onclick = () => queryPBDB(S.data.taxa.slice(), $('#ag-status', p), () => { paint(); refreshHead(); });
    $('#ag-strat', p).onclick = () => openStrat();
    $('#ag-clear', p).onclick = () => { S.data.ages = {}; S.ageSrc = {}; toast(L.ag_cleared); paint(); refreshHead(); };
    $('#ag-csv', p).onclick = () => download((S.data.name || 'dataset').replace(/\s+/g, '_') + '_ages.csv', agesToCSV(), 'text/csv');
    return p;
  }

  /* Macrostrat resuelve por FORMACIÓN, no por taxón: sirve cuando sabes dónde
     salió el fósil pero PaleoDB no tiene la especie. La edad que devuelve es la
     de la unidad completa, así que se marca con fuente propia. */
  function openStrat() {
    const L = I18N[S.lang];
    const miss = missingTaxa();
    const list = miss.length ? miss : S.data.taxa.filter(tx => S.ageSrc[tx] === 'env');
    openModal(L.ms_t, `
      <p class="lead" style="font-size:13.5px">${esc(L.ms_p)}</p>
      <div class="warnbox" style="margin:12px 0">${ic(SVGI.info)}<div><p>${esc(L.ms_warn)}</p></div></div>
      <label class="field" for="ms-tx">${esc(L.ms_taxon)}</label>
      <select id="ms-tx" class="tysel" style="width:100%;margin-bottom:10px">
        ${(list.length ? list : S.data.taxa).map(tx => `<option value="${esc(tx)}">${esc(pretty(tx))}</option>`).join('')}
      </select>
      <label class="field" for="ms-q">${esc(L.ms_unit)}</label>
      <div style="display:flex;gap:8px">
        <input id="ms-q" class="pcin" style="flex:1" placeholder="${esc(L.ms_ph)}">
        <button class="btn" id="ms-go">${esc(L.ms_search)}</button>
      </div>
      <div id="ms-out" style="margin-top:14px"></div>`);
    const out = () => $('#ms-out', modalBk);
    $('#ms-go', modalBk).onclick = async () => {
      const q = $('#ms-q', modalBk).value.trim();
      if (!q) return;
      out().innerHTML = `<p class="hint">${ic(SVGI.globe)}${esc(L.ms_searching)}</p>`;
      try {
        const rows = await PFMacro.findUnit(q);
        if (!rows.length) {
          const sug = await PFMacro.suggest(q);
          out().innerHTML = `<p class="hint">${esc(L.ms_none)}</p>` + (sug.length
            ? `<p class="hint" style="margin-top:8px">${esc(L.ms_maybe)}</p><div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:6px">` +
              sug.map(x => `<button class="toolbtn" data-sug="${esc(x.name)}">${esc(x.name)}</button>`).join('') + '</div>'
            : '');
          out().querySelectorAll('[data-sug]').forEach(b => b.onclick = () => { $('#ms-q', modalBk).value = b.dataset.sug; $('#ms-go', modalBk).click(); });
          return;
        }
        out().innerHTML = `<div class="cluout">` + rows.slice(0, 8).map((r, i) => `
          <div class="clurow">
            <span class="clun">${esc(r.name)}</span>
            <span class="clus">${esc(r.rank)}</span>
            <span class="clum mono">${r.fad} – ${r.lad} Ma</span>
            <button class="toolbtn" data-pick="${i}">${esc(L.ms_use)}</button>
          </div>`).join('') + '</div>';
        out().querySelectorAll('[data-pick]').forEach(b => b.onclick = () => {
          const r = rows[+b.dataset.pick], tx = $('#ms-tx', modalBk).value;
          setAge(tx, r.fad, r.lad, 'strat');
          closeModal();
          toast(L.ms_ok.replace('{t}', pretty(tx)).replace('{u}', r.name));
          render();
        });
      } catch (e) {
        out().innerHTML = `<p class="hint">${esc(L.ms_err)} ${esc(String(e.message || e))}</p>`;
      }
    };
    $('#ms-q', modalBk).onkeydown = e => { if (e.key === 'Enter') $('#ms-go', modalBk).click(); };
  }

  /* Pide el linaje a PaleoDB para cada taxón y guarda el clado. Es una consulta
     por taxón —el linaje no viene con las edades—, así que va bajo botón y se
     cachea. Los taxones que PaleoDB no conoce se quedan sin icono: los mismos
     que se imputan. */
  async function fetchClades(btn) {
    const L = I18N[S.lang];
    if (btn) { btn.disabled = true; btn.textContent = L.cl_wait.replace('{n}', 0).replace('{t}', S.data.taxa.length); }
    try {
      const out = await PBDB.cladesFor(S.data.taxa.slice(), (i, n) => {
        if (btn) btn.textContent = L.cl_wait.replace('{n}', i).replace('{t}', n);
      });
      S.clades = out;
      const n = Object.keys(out).filter(k => out[k]).length;
      toast(L.cl_ok.replace('{n}', n).replace('{t}', S.data.taxa.length));
      render();
    } catch (e) {
      toast(String((e && e.message) || e));
      if (btn) { btn.disabled = false; btn.textContent = L.cl_get; }
    }
  }

  function agesToCSV() {
    const head = ['TIPS', 'INI_EON', 'INI_ERA', 'INI_PERIOD', 'INI_EPOCH', 'INI_AGE', 'FIRST', 'LAST', 'DIET', 'SOURCE'];
    const rows = S.data.taxa.filter(tx => S.data.ages[tx]).map(tx => {
      const a = S.data.ages[tx];
      return [tx, a.eon || '', a.era || '', a.period || '', a.epoch || '', a.stage || '', a.fad, a.lad, a.diet || '', S.ageSrc[tx] || ''].join(';');
    });
    return head.join(';') + '\n' + rows.join('\n') + '\n';
  }

  function queryPBDB(tips, statusEl, done) {
    const L = I18N[S.lang];
    if (!tips.length) { toast(L.ag_nothing); return; }
    statusEl.innerHTML = `<div class="notice" style="margin-top:14px">${ic(SVGI.globe)}<div><b>${esc(L.ag_querying)}</b><div class="prog" style="margin-top:8px"><i id="ag-bar" style="width:4%"></i></div><div id="ag-cnt" class="hint" style="margin-top:6px">0 / ${tips.length}</div></div></div>`;
    PBDB.lookup(tips, {
      onProgress: (d, tot) => {
        const b = document.getElementById('ag-bar'); if (b) b.style.width = Math.max(4, d / tot * 100) + '%';
        const c = document.getElementById('ag-cnt'); if (c) c.textContent = d + ' / ' + tot;
      }
    }).then(res => {
      S.pbdb = res;
      let ok = 0, amb = 0, nf = 0;
      res.forEach(r => {
        if (r.status === 'found') { setAge(r.tip, r.fad, r.lad, 'pbdb', { match: r.match, family: r.family, genus: r.genus }); ok++; }
        else if (r.status === 'ambiguous') amb++;
        else nf++;
      });
      const ambList = res.filter(r => r.status === 'ambiguous');
      statusEl.innerHTML = `<div class="notice" style="margin-top:14px">${ic(SVGI.check)}<div>
        <b>${esc(L.ag_done)}</b><br>
        <span class="mono" style="font-size:12.5px">${ok} ${esc(L.ag_found)} · ${amb} ${esc(L.ag_ambig)} · ${nf} ${esc(L.ag_notfound)}</span>
        ${amb ? `<div style="margin-top:10px"><button class="toolbtn" id="ag-amb">${esc(L.ag_resolve)} (${amb})</button></div>` : ''}
        ${nf ? `<div class="hint" style="margin-top:8px">${esc(L.ag_manual_rest)}</div>` : ''}
      </div></div>`;
      if (amb) document.getElementById('ag-amb').onclick = () => openAmbiguous(ambList, done);
      toast(L.ag_done); done();
    }).catch(err => {
      statusEl.innerHTML = `<div class="notice" style="margin-top:14px;background:rgba(214,69,69,.08);border-color:rgba(214,69,69,.3)">${ic(SVGI.info)}<div>
        <b>${esc(L.ag_offline_h)}</b><div class="hint" style="margin-top:6px">${esc(L.ag_offline_p)}</div>
        <div class="mono" style="font-size:11px;color:var(--muted);margin-top:6px">${esc(String(err.message || err))}</div></div></div>`;
    });
  }

  // resolución de taxones ambiguos (el R los marcaba "AMBIGUO" y los descartaba)
  function openAmbiguous(list, done) {
    const L = I18N[S.lang];
    openModal(L.ag_resolve, `<p class="hint" style="margin-bottom:12px">${esc(L.ag_resolve_p)}</p>
      <div style="display:grid;gap:14px">${list.map((r, i) => `
        <div class="card pad" style="padding:12px">
          <div style="font-style:italic;font-weight:700;font-size:13.5px">${esc(pretty(r.tip))}</div>
          <div style="display:grid;gap:6px;margin-top:8px">
            ${r.candidates.map((c, j) => `<button class="navbtn" style="justify-content:flex-start;font-size:12.5px" data-i="${i}" data-j="${j}">
              <span style="font-style:italic">${esc(c.name)}</span><span class="mono" style="margin-left:auto;color:var(--muted)">${c.fad}–${c.lad} Ma</span></button>`).join('')}
          </div>
        </div>`).join('')}</div>`);
    modalBk.querySelectorAll('[data-i]').forEach(b => {
      b.onclick = () => {
        const r = list[+b.dataset.i], c = r.candidates[+b.dataset.j];
        setAge(r.tip, c.fad, c.lad, 'pbdb', { match: c.name });
        b.closest('.card').style.opacity = '.4';
        b.closest('.card').querySelectorAll('button').forEach(x => x.disabled = true);
        toast(L.ag_saved); done();
      };
    });
  }

  /* ---- Paso 3: Configuración ---- */
  function pConfig() {
    const L = I18N[S.lang];
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[3])}</div><h2>${esc(L.cfg_h)}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.cfg_p)}</p></div>
      <div class="grid g2">
        <div class="card pad">
          <label class="field" style="font-size:13.5px">${esc(L.cfg_methods)}</label>
          <div class="mgrid" id="cfg-methods">
            ${METHOD_KEYS.map(m => `
              <div class="mrow ${S.methods[m] ? 'on' : ''}" data-m="${m}">
                <button class="mtoggle" data-m="${m}" role="switch" aria-checked="${S.methods[m] ? 'true' : 'false'}">
                  <span class="cbx">${ic(SVGI.check)}</span>
                  <span class="mname">${esc(m)}</span>
                  ${NO_K.indexOf(m) >= 0 ? `<span class="nok" title="${esc(L.cfg_nok)}">${esc(L.cfg_kauto)}</span>` : ''}
                  <span class="mstate">${S.methods[m] ? esc(L.cfg_on) : esc(L.cfg_off)}</span>
                </button>
                ${hchip(GLOSS_OF[m])}
              </div>`).join('')}
          </div>
          <div class="mcount"><span id="cfg-count"></span></div>

          <label class="field" style="font-size:13.5px;margin-top:22px">${esc(L.cfg_k)}</label>
          <div class="kbox">
            <div class="kfield"><label for="kmin">${esc(L.cfg_kfrom)}</label>
              <input type="number" id="kmin" min="2" max="30" step="1" value="${S.kmin}"></div>
            <span class="kdash">→</span>
            <div class="kfield"><label for="kmax">${esc(L.cfg_kto)}</label>
              <input type="number" id="kmax" min="2" max="30" step="1" value="${S.kmax}"></div>
            <div class="ktrack" aria-hidden="true"><i id="kspan"></i></div>
          </div>
          <p class="hint" style="margin-top:8px">${ic(SVGI.info)}<span id="cfg-rows"></span></p>
          <div class="notice" style="margin-top:18px">${ic(SVGI.info)}<div>${esc(L.cfg_note)}
            ${(S.data.ordered && S.data.ordered.length) ? `<br><br><b>${S.data.ordered.length}</b> ${esc(L.pars_ordered)}.` : ''}</div></div>
          <button class="btn" id="cfg-run" style="margin-top:18px">${ic(SVGI.arrowR)}${esc(L.cfg_run)}</button>
        </div>
        <div class="card pad">
          <div class="eyebrow">${esc(L.how_h)}</div>
          <div class="flow" style="margin-top:8px">
            ${L.how.map((h, i) => `<div class="flow-step"><div class="flow-ic">${flowI(i)}</div><div><h4>${esc(h[0])}</h4><p>${esc(h[1])}</p></div></div>`).join('')}
          </div>
        </div>
      </div>`);
    const L2 = I18N[S.lang];
    const kmin = $('#kmin', p), kmax = $('#kmax', p);
    // nº de filas que se van a calcular + aviso de duración
    function refreshCount() {
      const withK = METHOD_KEYS.filter(m => S.methods[m] && NO_K.indexOf(m) < 0).length;
      const auto = METHOD_KEYS.filter(m => S.methods[m] && NO_K.indexOf(m) >= 0).length;
      const nk = Math.max(0, S.kmax - S.kmin + 1);
      const rows = withK * nk + auto;
      const cnt = $('#cfg-count', p);
      if (cnt) cnt.textContent = L2.cfg_sel
        .replace('{on}', METHOD_KEYS.filter(m => S.methods[m]).length)
        .replace('{tot}', METHOD_KEYS.length);
      const el = $('#cfg-rows', p);
      if (el) el.textContent = L2.cfg_rows.replace('{n}', rows).replace('{k}', nk);
      const span = $('#kspan', p);
      if (span) {
        const lo = (S.kmin - 2) / 28 * 100, hi = (S.kmax - 2) / 28 * 100;
        span.style.left = lo + '%'; span.style.width = Math.max(1, hi - lo) + '%';
      }
    }
    $('#cfg-methods', p).querySelectorAll('.mtoggle').forEach(btn => btn.onclick = () => {
      const m = btn.dataset.m;
      const on = Object.values(S.methods).filter(Boolean).length;
      if (S.methods[m] && on <= 1) { toast(L2.cfg_min1); return; }
      S.methods[m] = !S.methods[m];
      const row = btn.closest('.mrow');
      row.classList.toggle('on', S.methods[m]);
      btn.setAttribute('aria-checked', S.methods[m] ? 'true' : 'false');
      $('.mstate', row).textContent = S.methods[m] ? L2.cfg_on : L2.cfg_off;
      refreshCount();
    });
    const clampK = () => {
      let a = Math.max(2, Math.min(30, parseInt(kmin.value, 10) || 2));
      let b = Math.max(2, Math.min(30, parseInt(kmax.value, 10) || 2));
      if (a > b) { if (document.activeElement === kmin) b = a; else a = b; }
      kmin.value = a; kmax.value = b; S.kmin = a; S.kmax = b;
      refreshCount();
    };
    kmin.oninput = clampK; kmax.oninput = clampK;
    kmin.onblur = clampK; kmax.onblur = clampK;
    refreshCount();
    $('#cfg-run', p).onclick = () => runThenGo(4);
    return p;
  }

  /* ---- Paso 3: Distancias (heatmap RF) ---- */
  function pDistances() {
    const L = I18N[S.lang];
    const order = S.reorder ? clusterOrder() : S.trees.map((_, i) => i);
    const p = panel(`
      ${consensusNotice()}
      ${parsNotice()}
      <div class="section-top"><div class="eyebrow">${esc(L.steps[4])}</div><h2>${esc(L.hm_h)} ${hchip('rf')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.hm_p)}</p>${progressStrip()}</div>
      <div class="card pad">
        <div id="hm-tools"></div>
        <div class="viz" id="hm-viz" style="max-width:560px;margin:0 auto"></div>
        <div class="legend" style="margin-top:14px;justify-content:center">
          <div class="lg-item"><span>${esc(L.hm_scale)}</span><span class="rampbar"></span><span class="mono">0</span>→<span class="mono">${Math.max(...S.D.map(r => Math.max(...r))).toFixed(2)}</span></div>
        </div>
      </div>`);
    toolbar($('#hm-tools', p), [
      { label: S.reorder ? t('reorder_off') : t('reorder'), on: S.reorder, onClick: () => { S.reorder = !S.reorder; render(); } },
      { label: t('export_png'), onClick: () => exportHeatmapPNG(order) },
      { label: t('export_csv'), onClick: () => download('rf_matrix.csv', rfCSV(), 'text/csv') }
    ]);
    drawHeatmap($('#hm-viz', p), order);
    parsNoticeWire(p);
    return p;
  }
  function clusterOrder() { const idx = S.trees.map((_, i) => i); return idx.sort((a, b) => (S.labels[a] - S.labels[b]) || (a - b)); }
  function rampColor(v) { // 0 verde-claro .. alto rojo (RF: bajo=similar). Usamos verde->amber->rojo invertido a rampbar
    // rampbar va rojo->amber->verde (0->1). Para RF bajo=similar queremos claro. Definimos: 0 => verde claro, max=> rojo.
    const c0 = [58, 166, 87], c1 = [224, 165, 58], c2 = [214, 69, 69];
    let a, b, tt; if (v < 0.5) { a = c0; b = c1; tt = v / 0.5; } else { a = c1; b = c2; tt = (v - 0.5) / 0.5; }
    return `rgb(${a.map((x, i) => Math.round(x + (b[i] - x) * tt)).join(',')})`;
  }
  function drawHeatmap(mount, order) {
    const n = order.length, cell = Math.max(3, Math.min(9, Math.floor(520 / n)));
    const size = n * cell;
    const cv = document.createElement('canvas'); cv.width = cv.height = size;
    cv.style.width = cv.style.height = Math.min(520, size) + 'px'; cv.style.cursor = 'crosshair';
    const cx = cv.getContext('2d');
    const mx = Math.max(...S.D.map(r => Math.max(...r))) || 1;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) { cx.fillStyle = rampColor(S.D[order[i]][order[j]] / mx); cx.fillRect(j * cell, i * cell, cell, cell); }
    mount.appendChild(cv);
    cv.onmousemove = e => {
      const r = cv.getBoundingClientRect(), sc = size / r.width;
      const j = Math.floor((e.clientX - r.left) * sc / cell), i = Math.floor((e.clientY - r.top) * sc / cell);
      if (i < 0 || j < 0 || i >= n || j >= n) return hideTip();
      const a = order[i], b = order[j];
      showTip(`<b>${t('tip_cell')}: ${S.D[a][b].toFixed(3)}</b><br><span class="mono">${t('tip_tree')} ${a + 1} ${t('tip_vs')} ${b + 1}</span>`, e.clientX, e.clientY);
    };
    cv.onmouseleave = hideTip;
  }
  function exportHeatmapPNG(order) {
    const n = order.length, cell = 10, size = n * cell;
    const cv = document.createElement('canvas'); cv.width = cv.height = size; const cx = cv.getContext('2d');
    const mx = Math.max(...S.D.map(r => Math.max(...r))) || 1;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) { cx.fillStyle = rampColor(S.D[order[i]][order[j]] / mx); cx.fillRect(j * cell, i * cell, cell, cell); }
    cv.toBlob(b => { const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = 'rf_heatmap.png'; a.click(); toast(t('downloaded')); });
  }
  function rfCSV() {
    let s = 'tree,' + S.trees.map((_, i) => 't' + (i + 1)).join(',') + '\n';
    for (let i = 0; i < S.D.length; i++) s += 't' + (i + 1) + ',' + S.D[i].map(v => v.toFixed(3)).join(',') + '\n';
    return s;
  }

  /* ---- Paso 4: Bosque (MDS scatter) ---- */
  function pForest() {
    const L = I18N[S.lang];
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[6])}</div><h2>${esc(L.for_h)} ${hchip('mds')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.for_p)}</p></div>
      <div class="card pad">
        <div class="toolbar" style="margin-bottom:12px">
          <span class="eyebrow" style="margin-right:2px">${esc(L.for_proj)} ${hchip('proj')}</span>
          <div class="lvls" id="fo-proj">
            <button class="lvl${S.proj === 'pca' ? ' on' : ''}" data-p="pca">PCA</button>
            <button class="lvl${S.proj === 'mds' ? ' on' : ''}" data-p="mds">MDS</button>
          </div>
          <div class="searchbox">${ic(SVGI.search)}<input id="fo-search" type="number" min="1" max="${S.trees.length}" placeholder="${esc(L.search_tree)}"></div>
          <span style="flex:1"></span>
          <div id="fo-tools"></div>
        </div>
        <div class="viz" id="fo-viz"></div>
        ${swipeHint()}
        <div class="legend" id="fo-legend" style="margin-top:14px"></div>
        <div class="hint" style="margin-top:10px">${ic(SVGI.info)}${esc(L.for_hint)}</div>
        <div class="hint" style="margin-top:6px">${ic(SVGI.info)}${esc(S.proj === 'pca' ? L.for_pca_p : L.for_mds_p)}</div>
        <div class="hint" style="margin-top:6px">${ic(SVGI.info)}${esc(L.for_after)}</div>
      </div>`);
    toolbar($('#fo-tools', p), [
      { label: t('export_svg'), onClick: () => download('forest_' + S.proj + '.svg', svgString(resolveVars($('#fo-viz svg', p))), 'image/svg+xml') },
      { label: t('export_png'), onClick: () => svgToPng($('#fo-viz svg', p), 'forest_' + S.proj + '.png') }
    ]);
    drawForest($('#fo-viz', p), $('#fo-legend', p));
    $('#fo-search', p).oninput = e => highlightTree($('#fo-viz', p), e.target.value);
    p.querySelectorAll('#fo-proj .lvl').forEach(b => {
      b.onclick = () => {
        if (b.dataset.p === S.proj) return;
        S.proj = b.dataset.p;
        // reproyecta sin recalcular RF ni el agrupamiento
        const r = S.proj === 'pca' ? pcaRows(S.D, 2) : { scores: classicalMDS(S.D, 2), pct: null };
        S.coords = r.scores; S.projPct = r.pct;
        render();
      };
    });
    return p;
  }

  // resalta un árbol por su número (1-based) en el bosque MDS
  function highlightTree(mount, q) {
    const n = parseInt(q, 10);
    mount.querySelectorAll('.fpt').forEach(el => el.classList.remove('hit'));
    const halo = mount.querySelector('#fo-halo');
    if (halo) halo.remove();
    if (!q || isNaN(n)) return;
    const el = mount.querySelector('.fpt[data-i="' + (n - 1) + '"]');
    if (!el) { toast(I18N[S.lang].tree_nf); return; }
    el.classList.add('hit');
    const svg = mount.querySelector('svg');
    const cx = el.dataset.cx, cy = el.dataset.cy;
    if (cx != null && cy != null) {
      const ring = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      ring.setAttribute('id', 'fo-halo');
      ring.setAttribute('cx', cx); ring.setAttribute('cy', cy); ring.setAttribute('r', 13);
      ring.setAttribute('fill', 'none'); ring.setAttribute('stroke', 'var(--usach-orange)');
      ring.setAttribute('stroke-width', '2.5');
      svg.appendChild(ring);
    }
  }
  function drawForest(mount, legendEl) {
    const L = I18N[S.lang];
    const W = 700, H = 460, pad = 34;
    const xs = S.coords.map(c => c[0]), ys = S.coords.map(c => c[1]);
    const xmin = Math.min(...xs), xmax = Math.max(...xs), ymin = Math.min(...ys), ymax = Math.max(...ys);
    const sx = v => pad + (v - xmin) / (xmax - xmin || 1) * (W - 2 * pad);
    const sy = v => H - pad - (v - ymin) / (ymax - ymin || 1) * (H - 2 * pad);
    const cmVals = Object.values(S.cm);
    let s = `<svg viewBox="0 0 ${W} ${H}" style="width:100%;max-width:${W}px;display:block;margin:0 auto">`;
    s += `<rect x="0" y="0" width="${W}" height="${H}" fill="var(--surface)"/>`;
    // ejes con su rótulo real: PCA -> Dim1/Dim2 (% varianza); MDS -> coordenadas
    s += `<line x1="${pad}" y1="${H - pad}" x2="${W - pad}" y2="${H - pad}" stroke="var(--line)"/><line x1="${pad}" y1="${pad}" x2="${pad}" y2="${H - pad}" stroke="var(--line)"/>`;
    const ax = (i) => S.proj === 'pca'
      ? `Dim${i + 1}` + (S.projPct ? ` (${S.projPct[i].toFixed(1)}%)` : '')
      : `${L.for_coord} ${i + 1}`;
    s += `<text x="${W - pad}" y="${H - pad + 16}" font-size="10.5" font-family="var(--mono)" text-anchor="end" fill="var(--muted)">${esc(ax(0))}</text>`;
    s += `<text x="${pad - 6}" y="${pad + 2}" font-size="10.5" font-family="var(--mono)" text-anchor="start" fill="var(--muted)" transform="rotate(-90 ${pad - 6} ${pad + 2})">${esc(ax(1))}</text>`;
    // orden de pintado: primero los árboles normales, después los medoides (para que queden encima)
    const marks = [];
    S.coords.forEach((c, i) => {
      const cl = S.labels[i], col = CLUSTER_COLORS[(cl - 1) % CLUSTER_COLORS.length];
      const isCM = cmVals.indexOf(i) >= 0, isGM = i === S.gm;
      const dim = S.hlCluster && S.hlCluster !== cl;
      const px = +sx(c[0]).toFixed(1), py = +sy(c[1]).toFixed(1);
      const common = `class="fpt" data-i="${i}" data-cx="${px}" data-cy="${py}" style="cursor:pointer"`;
      if (isGM) {
        // medoide general: estrella naranja con anillo, siempre encima
        marks.push({ z: 3, s: `<g ${common} opacity="${dim ? .25 : 1}">
          <circle cx="${px}" cy="${py}" r="12" fill="none" stroke="var(--usach-orange)" stroke-width="1.6" stroke-dasharray="2.5 2.5"/>
          <path d="${star(px, py, 5, 9, 4.2)}" fill="var(--usach-orange)" stroke="var(--usach-slate)" stroke-width="1.3" stroke-linejoin="round"/>
        </g>` });
        marks.push({ z: 4, s: `<text x="${px + 14}" y="${py - 9}" font-size="10.5" font-family="var(--mono)" font-weight="700" fill="var(--usach-orange)" pointer-events="none">#${i + 1}</text>` });
      } else if (isCM) {
        // medoide de clúster: relleno del clúster + anillo oscuro grueso (igual que la leyenda)
        marks.push({ z: 2, s: `<circle cx="${px}" cy="${py}" r="7.5" fill="${col}" stroke="var(--usach-slate)" stroke-width="2.4" opacity="${dim ? .25 : 1}" ${common}/>` });
        marks.push({ z: 4, s: `<text x="${px + 11}" y="${py - 8}" font-size="10.5" font-family="var(--mono)" font-weight="700" fill="var(--usach-slate)" pointer-events="none">#${i + 1}</text>` });
      } else {
        marks.push({ z: 1, s: `<circle cx="${px}" cy="${py}" r="4.6" fill="${col}" stroke="rgba(0,0,0,.15)" stroke-width="1" opacity="${dim ? .16 : .8}" ${common}/>` });
      }
    });
    marks.sort((a, b) => a.z - b.z).forEach(m => { s += m.s; });
    s += `</svg>`;
    mount.innerHTML = s;
    const svg = mount.querySelector('svg');
    svg.querySelectorAll('.fpt').forEach(el => {
      const i = +el.dataset.i;
      el.onmousemove = e => {
        const cl = S.labels[i];
        const both = i === S.gm && Object.values(S.cm).indexOf(i) >= 0;
        const role = i === S.gm ? (both ? L.for_both : L.for_general)
          : (Object.values(S.cm).indexOf(i) >= 0 ? L.for_cluster : L.for_tree);
        showTip(`<b>${role}</b><br><span class="mono">${L.for_tree} #${i + 1} · ${esc(L.clu_lbl)} ${cl}</span>`, e.clientX, e.clientY);
      };
      el.onmouseleave = hideTip;
      el.onclick = () => { S.curTreeIdx = i; hideTip(); toast(L.show_medoid); go(6); };   // Árbol medoide
    });
    // leyenda: los símbolos replican exactamente los del gráfico
    const uniq = [...new Set(S.labels)].sort((a, b) => a - b);
    legendEl.innerHTML = uniq.map(cl => `<button class="lg-item" data-cl="${cl}" style="background:none;border:none;cursor:pointer;${S.hlCluster === cl ? 'font-weight:800' : ''}"><span class="lg-dot" style="background:${CLUSTER_COLORS[(cl - 1) % CLUSTER_COLORS.length]}"></span>${esc(L.clu_lbl)} ${cl}</button>`).join('') +
      `<span class="lg-item"><svg width="17" height="17" viewBox="0 0 17 17"><circle cx="8.5" cy="8.5" r="7.4" fill="none" stroke="var(--usach-orange)" stroke-width="1.2" stroke-dasharray="2 2"/><path d="${star(8.5, 8.5, 5, 5.6, 2.6)}" fill="var(--usach-orange)" stroke="var(--usach-slate)" stroke-width=".9" stroke-linejoin="round"/></svg>${L.for_general}</span>` +
      `<span class="lg-item"><svg width="17" height="17" viewBox="0 0 17 17"><circle cx="8.5" cy="8.5" r="5.6" fill="${CLUSTER_COLORS[0]}" stroke="var(--usach-slate)" stroke-width="2.2"/></svg>${L.for_cluster}</span>` +
      `<span class="lg-item" style="color:var(--muted);font-size:11px">${esc(L.for_note)}</span>`;
    legendEl.querySelectorAll('[data-cl]').forEach(b => b.onclick = () => { const cl = +b.dataset.cl; S.hlCluster = S.hlCluster === cl ? null : cl; render(); });
  }
  function star(cx, cy, n, R, r) {
    let d = ''; for (let i = 0; i < n * 2; i++) { const ang = Math.PI / n * i - Math.PI / 2; const rad = i % 2 ? r : R; d += (i ? 'L' : 'M') + (cx + Math.cos(ang) * rad).toFixed(1) + ' ' + (cy + Math.sin(ang) * rad).toFixed(1); } return d + 'Z';
  }

  /* ---- Paso 5: Método (tabla hipervolumen) ---- */
  function pMethod() {
    const L = I18N[S.lang];
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[5])}</div><h2>${esc(L.met_h)} ${hchip('hv')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.met_p)}</p></div>
      <div class="card pad">
        <div style="display:flex;flex-wrap:wrap;gap:14px;align-items:center;margin-bottom:14px">
          <div class="kpi">${esc(L.met_best)}: <b>${esc(S.best.method)} · k=${S.best.k}</b></div>
          <div style="flex:1"></div>
          <div id="mt-tools"></div>
        </div>
        <div class="tbl-wrap">
          <table><thead><tr>
            <th>${esc(L.th_method)}</th><th>${esc(L.th_k)}</th>
            <th>${esc(L.th_dunn)} ${hchip('dunn')}</th><th>${esc(L.th_conn)} ${hchip('conn')}</th>
            <th>${esc(L.th_sil)} ${hchip('sil')}</th><th>${esc(L.th_hv)} ${hchip('hv')}</th>
          </tr></thead><tbody>
          ${S.rows.map(r => `<tr class="${r === S.best ? 'best' : ''}"><td>${esc(r.method)}</td><td>${r.k}</td><td>${(+r.Dunn).toFixed(3)}</td><td>${(+r.Connectivity).toFixed(2)}</td><td>${(+r.Silhouette).toFixed(3)}</td><td>${r.ConHyp.toFixed(4)}</td></tr>`).join('')}
          </tbody></table>
        </div>
      </div>

      <div class="card pad" style="margin-top:18px">
        <div class="eyebrow">${esc(L.met_out_h)}</div>
        <div class="cluout">
          ${Object.keys(S.cm).map((cl, i) => {
      const n = S.labels.filter(x => +x === +cl).length;
      const col = CLUSTER_COLORS[(cl - 1) % CLUSTER_COLORS.length];
      return `<div class="clurow"><span class="cludot" style="background:${col}"></span>
            <span class="clun">${esc(L.clu_lbl)} ${cl}</span>
            <span class="clus mono">${n} ${esc(L.st_trees.toLowerCase())}</span>
            <span class="clum mono">${esc(L.med_lbl)} → #${S.cm[cl] + 1}</span></div>`;
    }).join('')}
        </div>
        <p class="hint" style="margin-top:10px">${ic(SVGI.info)}${esc(L.met_out_p)} <b>#${S.gm + 1}</b>.</p>
      </div>

      <div class="card pad" style="margin-top:18px">
        <div class="eyebrow">${esc(L.met_why_h)}</div>
        <div class="whygrid">
          ${[L.met_why, L.met_why2, L.met_why3].map((w, i) => `
            <div class="whyitem"><span class="whyn">${i + 1}</span>
              <div><h4>${esc(w[0])}</h4><p>${esc(w[1])}</p></div></div>`).join('')}
        </div>
      </div>`);
    toolbar($('#mt-tools', p), [{ label: t('export_csv'), onClick: () => download('method_selection.csv', methodCSV(), 'text/csv') }]);
    return p;
  }
  function methodCSV() {
    let s = 'method,k,Dunn,Connectivity,Silhouette,ConHyp,selected\n';
    S.rows.forEach(r => s += `${r.method},${r.k},${(+r.Dunn).toFixed(4)},${(+r.Connectivity).toFixed(4)},${(+r.Silhouette).toFixed(4)},${r.ConHyp.toFixed(5)},${r === S.best ? 1 : 0}\n`);
    return s;
  }

  /* ---- Selector de árbol compartido por «Árbol medoide» y «Temporalidad».
         Ambos pasos muestran EL MISMO árbol (S.curTreeIdx): uno la topología,
         el otro esa topología escalada en el tiempo. ---- */
  function curIdx() { return S.curTreeIdx == null ? S.gm : S.curTreeIdx; }

  // parsimonia del árbol i, si se pudo calcular
  function parsTag(i) {
    if (!S.pars || S.pars[i] == null) return '';
    const L = I18N[S.lang];
    const mp = S.pars[i] === S.parsBest;
    return ` · ${L.pars_score} ${S.pars[i]}${mp ? '' : ' ⚠'}`;
  }
  function treeRole(i) {
    const L = I18N[S.lang];
    const isGM = i === S.gm;
    const cl = Object.keys(S.cm).find(k => S.cm[k] === i);
    if (isGM && cl) return `★ ${L.for_general} · ${L.clu_lbl} ${cl}`;
    if (isGM) return `★ ${L.for_general}`;
    if (cl) return `${L.for_cluster} · ${L.clu_lbl} ${cl}`;
    return `${L.for_tree} · ${L.clu_lbl} ${S.labels[i]}`;
  }

  function treePickerHTML(id) {
    const L = I18N[S.lang], idx = curIdx();
    const cmEntries = Object.entries(S.cm);
    const medoidIdx = new Set([S.gm].concat(cmEntries.map(([, i]) => +i)));
    const opt = (i, label) => `<option value="${i}" ${i === idx ? 'selected' : ''}>${esc(label)}</option>`;
    let html = `<select id="${id}" class="treepick">`;
    html += `<optgroup label="${esc(L.pick_medoids)}">`;
    html += opt(S.gm, `★ ${L.for_general} — #${S.gm + 1}`);
    cmEntries.forEach(([cl, i]) => {
      if (+i === S.gm) return;   // ya listado como medoide general
      html += opt(+i, `${L.for_cluster} ${cl} — #${(+i) + 1}`);
    });
    html += `</optgroup><optgroup label="${esc(L.pick_all)}">`;
    for (let i = 0; i < S.trees.length; i++) {
      if (medoidIdx.has(i)) continue;
      html += opt(i, `${L.for_tree} #${i + 1} · ${L.clu_lbl} ${S.labels[i]}`);
    }
    html += `</optgroup></select>`;
    return html;
  }

  function nwkName(i) {
    const base = (S.data.name || 'tree').replace(/\s+/g, '_');
    const tag = i === S.gm ? 'medoide_general' : (Object.keys(S.cm).find(k => S.cm[k] === i) ? 'medoide_clu' + Object.keys(S.cm).find(k => S.cm[k] === i) : 'arbol');
    return `${base}_${tag}_${i + 1}.nwk`;
  }
  function downloadNwk(i) {
    const L = I18N[S.lang];
    const header = `[ ${S.data.name} · #${i + 1} · ${treeRole(i)}${parsTag(i)} · PaleoForest ]\n`;
    download(nwkName(i), header + S.data.newicks[i] + '\n', 'text/plain');
  }

  /* ---- Paso 7: Árbol medoide (cladograma con soporte) ---- */
  function pMedoid() {
    const L = I18N[S.lang];
    const idx = curIdx();
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[7])}</div><h2>${esc(L.md_h)} ${hchip('support')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.md_p)}</p></div>
      <div class="card pad">
        <div class="pickbar">
          <label class="field" for="md-pick">${esc(L.md_pick)}</label>
          ${treePickerHTML('md-pick')}
          <span class="pickrole" id="md-role">${esc(treeRole(idx) + parsTag(idx))}</span>
          <span style="flex:1"></span>
          <div class="searchbox">${ic(SVGI.search)}<input id="md-search" placeholder="${esc(t('search_taxon'))}"></div>
        </div>
        <div class="toolbar" style="margin:12px 0"><div id="md-tools"></div></div>
        <div class="viz" id="md-viz" style="max-height:640px"></div>
        ${swipeHint()}
        <div class="legend" style="margin-top:14px">
          <div class="lg-item"><span>${esc(L.md_support)}</span><span class="rampbar" style="background:linear-gradient(90deg,#d64545,#e0a53a,#3aa657)"></span>
            <span class="mono">${esc(L.md_low)}</span> → <span class="mono">${esc(L.md_high)}</span></div>
        </div>
        <div class="hint" style="margin-top:8px">${ic(SVGI.info)}${esc(L.pick_sync)}</div>
      </div>`);
    const draw = i => { drawCladogram($('#md-viz', p), medoidTreeWithSupport(i)); $('#md-role', p).textContent = treeRole(i) + parsTag(i); };
    draw(idx);
    $('#md-pick', p).onchange = e => {
      S.curTreeIdx = +e.target.value; draw(S.curTreeIdx);
      const q = $('#md-search', p).value; if (q) highlightTaxon($('#md-viz', p), q);
    };
    $('#md-search', p).oninput = e => highlightTaxon($('#md-viz', p), e.target.value);
    toolbar($('#md-tools', p), [
      { label: t('export_nwk'), onClick: () => downloadNwk(curIdx()) },
      { label: t('export_svg'), onClick: () => download('medoid_tree.svg', svgString(resolveVars($('#md-viz svg', p))), 'image/svg+xml') },
      { label: t('export_png'), onClick: () => svgToPng($('#md-viz svg', p), 'medoid_tree.png') }
    ]);
    return p;
  }
  // ladderize + layout de cladograma
  function layoutTree(root) {
    let leafCount = 0;
    (function count(n) { if (!n.children.length) { n._n = 1; return 1; } n._n = n.children.reduce((s, c) => s + count(c), 0); return n._n; })(root);
    (function ladder(n) { n.children.sort((a, b) => a._n - b._n); n.children.forEach(ladder); })(root);
    let yi = 0;
    (function y(n) { if (!n.children.length) { n._y = yi++; return n._y; } const ys = n.children.map(y); n._y = (Math.min(...ys) + Math.max(...ys)) / 2; return n._y; })(root);
    (function h(n) { if (!n.children.length) { n._h = 0; return 0; } n._h = 1 + Math.max(...n.children.map(h)); return n._h; })(root);
    return { leaves: yi, height: root._h };
  }
  function drawCladogram(mount, root) {
    const L = I18N[S.lang];
    const info = layoutTree(root);
    const rowH = 17, top = 16, bottom = 16, left = 22, labelW = 220, right = labelW + 24;
    const H = top + bottom + info.leaves * rowH;
    const W = 760;
    const plotW = W - left - right;
    const sx = h => left + (info.height - h) / (info.height || 1) * plotW; // tips (h=0) a la derecha
    const sy = y => top + y * rowH + rowH / 2;
    let s = `<svg viewBox="0 0 ${W} ${H}" style="width:100%;max-width:${W}px;display:block">`;
    s += `<rect width="${W}" height="${H}" fill="var(--surface)"/>`;
    // ramas
    (function edges(n) {
      const x = sx(n._h), y = sy(n._y);
      n.children.forEach(c => {
        const cx = sx(c._h), cy = sy(c._y);
        s += `<path d="M${x} ${y} L${x} ${cy} L${cx} ${cy}" fill="none" stroke="var(--usach-slate)" stroke-width="1.4" stroke-opacity=".75"/>`;
        edges(c);
      });
    })(root);
    // nodos internos (soporte) + hojas
    (function nodes(n) {
      const x = sx(n._h), y = sy(n._y);
      if (n.children.length) {
        if (n.support != null) s += `<circle cx="${x}" cy="${y}" r="4.2" fill="${rampSupport(n.support)}" stroke="#fff" stroke-width="1" class="mnode" data-s="${n.support.toFixed(2)}" data-taxa="${countLeaves(n)}"/>`;
      } else {
        s += `<circle cx="${x}" cy="${y}" r="2.6" fill="var(--usach-slate)"/>`;
        s += `<text x="${x + 7}" y="${y + 3.4}" font-size="11" font-style="italic" fill="var(--ink)" class="tlabel" data-name="${esc(n.name)}">${esc(pretty(n.name))}</text>`;
      }
      n.children.forEach(nodes);
    })(root);
    s += `</svg>`;
    mount.innerHTML = s;
    mount.querySelectorAll('.mnode').forEach(el => {
      el.onmousemove = e => showTip(`<b>${L.tip_node}</b><br>${L.tip_support}: <span class="mono">${el.dataset.s}</span> · ${el.dataset.taxa} ${L.tip_taxa}`, e.clientX, e.clientY);
      el.onmouseleave = hideTip;
    });
  }
  function countLeaves(n) { if (!n.children.length) return 1; return n.children.reduce((s, c) => s + countLeaves(c), 0); }
  function rampSupport(v) { const c0 = [214, 69, 69], c1 = [224, 165, 58], c2 = [58, 166, 87]; let a, b, tt; if (v < .5) { a = c0; b = c1; tt = v / .5; } else { a = c1; b = c2; tt = (v - .5) / .5; } return `rgb(${a.map((x, i) => Math.round(x + (b[i] - x) * tt)).join(',')})`; }
  function highlightTaxon(mount, q) {
    q = q.trim().toLowerCase();
    let hit = 0;
    mount.querySelectorAll('.tlabel').forEach(el => {
      const m = q && el.dataset.name.toLowerCase().indexOf(q) >= 0;
      el.setAttribute('fill', m ? 'var(--usach-orange)' : 'var(--ink)');
      el.setAttribute('font-weight', m ? '800' : '400'); if (m) hit++;
    });
    // el icono del clado también cambia de color: es lo que pidió el usuario
    mount.querySelectorAll('.clg path').forEach(el => {
      const m = q && el.parentNode.dataset.name.toLowerCase().indexOf(q) >= 0;
      const known = !!el.parentNode.dataset.clade;
      el.setAttribute('fill', m ? 'var(--usach-orange)' : 'var(--usach-slate)');
      el.setAttribute('fill-opacity', m ? '1' : (known ? '.62' : '.3'));
    });
    // en el árbol temporal, resalta también la barra de rango fósil
    mount.querySelectorAll('.trange').forEach(el => {
      const m = q && el.dataset.name.toLowerCase().indexOf(q) >= 0;
      el.setAttribute('stroke', m ? 'var(--usach-orange)' : 'var(--usach-slate)');
      el.setAttribute('stroke-width', m ? '2.2' : '.5');
      el.setAttribute('stroke-opacity', m ? '1' : '.35');
    });
    if (q && !hit) toast(t('no_match'), false);
  }

  /* ---- Paso 7: Temporalidad ---- */
  /* Escalamiento temporal, los cinco tipos de paleotree::timePaleoPhy
     (Bapst 2012). El tiempo decrece: el presente es 0, y la edad de un nodo es
     su antigüedad en Ma.

       basic  cada nodo va al FAD del descendiente más antiguo. Deja ramas de
              largo cero donde el ancestro aparece a la vez que su descendiente.
              No usa vartime.
       equal  reparte por igual el tiempo de la rama con largo positivo más
              cercana entre las ramas de largo cero que cuelgan de ella
              (Brusatte et al. 2008). vartime es el tiempo que se agrega a la
              raíz para tener de dónde repartir.
       aba    all branches additive: suma vartime a TODAS las ramas. El propio
              paleotree advierte que deforma el árbol y puede dejar tips fuera
              de orden respecto de los FAD.
       zlba   zero-length branches additive: suma vartime SOLO a las de largo 0.
       mbl    minimum branch length (Laurin 2004): ninguna rama mide menos que
              vartime; las cortas empujan al ancestro hacia atrás, en cascada.

     La edad «basic» de cada nodo tiene que estar ya en n._age. */
  function timeScale(root, type, vartime) {
    if (!type || type === 'basic') return;
    const v = (vartime == null || isNaN(vartime)) ? 0 : Math.abs(vartime);

    // largos de rama del árbol «basic»: b(hijo) = edad(padre) - edad(hijo)
    (function mark(n, parent) {
      n._parent = parent || null;
      n._b0 = parent ? (parent._age - n._age) : 0;
      n._basic = n._age;
      (n.children || []).forEach(c => mark(c, n));
    })(root, null);

    if (type === 'aba' || type === 'zlba' || type === 'mbl') {
      // una pasada de abajo hacia arriba: la edad nueva del padre es la del
      // hijo más exigente más el largo de rama corregido
      (function up(n) {
        if (!n.children || !n.children.length) return n._age;
        let mx = -Infinity;
        n.children.forEach(c => {
          const ca = up(c);
          let b = c._b0;
          if (type === 'aba') b += v;
          else if (type === 'zlba') { if (b <= 1e-9) b += v; }
          else if (type === 'mbl') { if (b < v) b = v; }
          const a = ca + b;
          if (a > mx) mx = a;
        });
        n._age = mx;
        return n._age;
      })(root);
      return;
    }

    if (type === 'equal') {
      // la raíz necesita tiempo propio del que repartir
      root._age = root._basic + v;
      /* Para cada cadena de ramas de largo cero, se busca la primera rama
         rootward con largo positivo y se reparte su tiempo entre todas por
         igual. Se recorre desde las hojas hacia la raíz. */
      const nodes = [];
      (function collect(n) { nodes.push(n); (n.children || []).forEach(collect); })(root);
      const lenOf = n => (n._parent ? n._parent._age - n._age : 0);
      let guard = 0;
      for (;;) {
        // la rama de largo cero más profunda que todavía no se resolvió
        let z = null;
        for (let i = nodes.length - 1; i >= 0; i--) {
          const n = nodes[i];
          if (n._parent && lenOf(n) <= 1e-9 && !n._eq) { z = n; break; }
        }
        if (!z || ++guard > 20000) break;
        // subir hasta la primera rama con largo positivo
        const chain = [z];
        let k = z._parent;
        while (k && k._parent && lenOf(k) <= 1e-9) { chain.push(k); k = k._parent; }
        if (!k || !k._parent) { chain.forEach(c => c._eq = true); continue; }
        const donor = k, L = lenOf(donor), m = chain.length + 1;
        if (L <= 1e-9) { chain.forEach(c => c._eq = true); donor._eq = true; continue; }
        const share = L / m;
        // el donante cede: su edad baja hasta quedar a `share` de su padre
        donor._age = donor._parent._age - share;
        // y la cadena se estira `share` por rama, de arriba hacia abajo
        for (let i = chain.length - 1; i >= 0; i--) {
          const nd = chain[i];
          nd._age = nd._parent._age - share;
          nd._eq = true;
        }
        donor._eq = true;
      }
      nodes.forEach(n => { delete n._eq; });
      return;
    }
  }

  function pTemporality() {
    const L = I18N[S.lang];
    if (!hasAges()) {
      const e = panel(`
        <div class="section-top"><div class="eyebrow">${esc(L.steps[8])}</div><h2>${esc(L.tm_h)} ${hchip('parsimony')}</h2></div>
        <div class="card"><div class="empty"><div class="ei">${ic(SVGI.clock)}</div>
          <h4>${esc(t('empty_noage_h'))}</h4><p>${esc(L.tm_noage)}</p>
          <button class="btn" id="tm-go">${ic(SVGI.globe)}${esc(L.tm_goages)}</button></div></div>`);
      $('#tm-go', e).onclick = () => go(7);   // Edades
      return e;
    }
    const idx = curIdx();
    const p = panel(`
      <div class="section-top"><div class="eyebrow">${esc(L.steps[8])}</div><h2>${esc(L.tm_h)} ${hchip('clade')}</h2>
        <p class="lead" style="margin-top:8px">${esc(L.tm_p)}</p></div>
      <div class="card pad">
        <div class="pickbar">
          <label class="field" for="tm-pick">${esc(L.md_pick)}</label>
          ${treePickerHTML('tm-pick')}
          <span class="pickrole" id="tm-role">${esc(treeRole(idx) + parsTag(idx))}</span>
          <span style="flex:1"></span>
          <div class="searchbox">${ic(SVGI.search)}<input id="tm-search" placeholder="${esc(t('search_taxon'))}"></div>
        </div>
        <div class="toolbar" style="margin:12px 0;align-items:center">
          <button class="toolbtn" id="tm-clades">${ic(SVGI.globe)}${esc(S.clades ? L.cl_again : L.cl_get)}</button>${hchip('icons')}
          <span class="eyebrow" style="margin-left:8px;margin-right:2px">${esc(L.ts_h)} ${hchip('tscale')}</span>
          <select id="ts-type" class="tysel" aria-label="${esc(L.ts_h)}">
            ${['basic', 'equal', 'aba', 'zlba', 'mbl'].map(k =>
              `<option value="${k}" ${S.tsType === k ? 'selected' : ''}>${esc(L['ts_' + k])}</option>`).join('')}
          </select>
          <label class="field" for="ts-var" style="${S.tsType === 'basic' ? 'display:none' : ''}">vartime</label>
          <input id="ts-var" class="ain" type="number" min="0" step="0.5" value="${S.tsVar}"
                 style="${S.tsType === 'basic' ? 'display:none' : ''}" aria-label="vartime">
          <span class="tsnote">${esc(L['tsn_' + S.tsType])}</span>
          <span style="flex:1"></span>
        </div>
        <div class="toolbar" style="margin:12px 0;align-items:center">
          <span class="eyebrow" style="margin-right:2px">${esc(L.tm_model)} ${hchip('geoscale')}</span>
          <div class="lvls" id="tm-lvls">
            ${GEO.LEVEL_KEYS.map(k => `<button class="lvl${S.geoLevels.indexOf(k) >= 0 ? ' on' : ''}" data-lvl="${k}">${esc(L['lvl_' + k])}</button>`).join('')}
          </div>
          <span style="flex:1"></span>
          <div id="tm-tools"></div>
        </div>
        ${S.clades ? `<div class="legend clleg">${PBDB.CLADES.map(c =>
          `<span class="lg-item">${cladeIcon(c.key)}${esc(L['cl_' + c.key] || c.key)}</span>`).join('') +
          `<span class="lg-item">${cladeIcon('')}${esc(L.cl_unknown)}</span>`}</div>` : ''}
        <div id="tm-legend" class="legend" style="margin:10px 0 4px"></div>
        <div class="viz" id="tm-viz" style="max-height:760px"></div>
        ${swipeHint()}
        <div class="hint" style="margin-top:8px">${ic(SVGI.info)}${esc(L.tm_ma)} · ${esc(L.tm_ics)}</div>
        <div class="hint" style="margin-top:6px">${ic(SVGI.info)}${esc(L.pick_sync)}</div>
      </div>`);
    const redraw = () => {
      drawTimeTree($('#tm-viz', p), medoidTreeWithSupport(curIdx()), $('#tm-legend', p));
      $('#tm-role', p).textContent = treeRole(curIdx()) + parsTag(curIdx());
      const q = $('#tm-search', p).value;
      if (q) highlightTaxon($('#tm-viz', p), q);
    };
    redraw();
    $('#tm-pick', p).onchange = e => { S.curTreeIdx = +e.target.value; redraw(); };
    $('#tm-search', p).oninput = e => highlightTaxon($('#tm-viz', p), e.target.value);
    $('#tm-clades', p).onclick = e => fetchClades(e.currentTarget);
    $('#ts-type', p).onchange = e => { S.tsType = e.target.value; render(); };
    $('#ts-var', p).onchange = e => { S.tsVar = Math.max(0, +e.target.value || 0); render(); };
    p.querySelectorAll('.lvl').forEach(b => {
      b.onclick = () => {
        const k = b.dataset.lvl, i = S.geoLevels.indexOf(k);
        if (i >= 0) { if (S.geoLevels.length === 1) { toast(L.tm_one_level); return; } S.geoLevels.splice(i, 1); }
        else S.geoLevels.push(k);
        S.geoLevels.sort((a, c) => GEO.LEVEL_KEYS.indexOf(a) - GEO.LEVEL_KEYS.indexOf(c));
        b.classList.toggle('on'); redraw();
      };
    });
    toolbar($('#tm-tools', p), [
      { label: t('export_nwk'), onClick: () => downloadNwk(curIdx()) },
      { label: t('export_svg'), onClick: () => download('time_tree.svg', svgString(resolveVars($('#tm-viz svg', p))), 'image/svg+xml') },
      { label: t('export_png'), onClick: () => svgToPng($('#tm-viz svg', p), 'time_tree.png') }
    ]);
    return p;
  }
  function drawTimeTree(mount, root, legendEl) {
    const L = I18N[S.lang], ages = S.data.ages;
    layoutTree(root);
    // «basic»: hoja = FAD, interno = FAD del descendiente más antiguo
    (function age(n) {
      if (!n.children.length) { const a = ages[n.name]; n._fad = a ? a.fad : null; n._lad = a ? a.lad : null; n._age = a ? a.fad : 0; return n._age; }
      const cs = n.children.map(age); n._age = Math.max.apply(null, cs); return n._age;
    })(root);
    timeScale(root, S.tsType || 'basic', S.tsVar);
    let minMa = Infinity, maxMa = -Infinity;
    (function scan(n) { if (!n.children.length) { if (n._lad != null) minMa = Math.min(minMa, n._lad); if (n._fad != null) maxMa = Math.max(maxMa, n._fad); } else { maxMa = Math.max(maxMa, n._age); } n.children.forEach(scan); })(root);
    if (!isFinite(minMa)) minMa = 0; maxMa = Math.max(maxMa, root._age);
    const padT = maxMa - minMa || 1; minMa -= padT * 0.02; maxMa += padT * 0.04;
    const leaves = []; (function col(n) { if (!n.children.length) leaves.push(n); else n.children.forEach(col); })(root);

    // ---- escala cronoestratigráfica: una fila por nivel activo ----
    const levels = S.geoLevels.slice().sort((a, b) => GEO.LEVEL_KEYS.indexOf(a) - GEO.LEVEL_KEYS.indexOf(b));
    const bandsByLevel = levels.map(k => ({ level: k, items: GEO.bands(k, maxMa, minMa) })).filter(b => b.items.length);
    const bandH = 17, gap = 2;
    const scaleH = bandsByLevel.length * (bandH + gap);

    /* El margen izquierdo lo manda la etiqueta de fila más larga («PERÍODO»,
       «ÉPOCA»…), que va anclada al final en left-4. Con left=18 arrancaba en
       x negativo y se cortaba: estuvo mal desde siempre. Se mide, no se adivina. */
    const lvlNames = (S.geoLevels || []).map(k => String(I18N[S.lang]['lvl_' + k] || k));
    const lvlW = lvlNames.reduce((m, n) => Math.max(m, n.length), 0) * 5.6 + 10;
    /* La leyenda de clados va DENTRO del SVG: si vive en un div de al lado, no
       viaja en la descarga y el archivo sale sin decir qué es cada silueta. */
    const legKeys = S.clades
      ? Object.keys(CLADE_PATH).filter(k => k && Object.keys(S.clades).some(t => S.clades[t] === k))
      : [];
    const legUnk = S.clades && Object.keys(S.clades).some(t => !S.clades[t]);
    const legH = (legKeys.length || legUnk) ? 26 : 0;
    const rowH = 18, top = 16 + scaleH + 10, bottom = 34 + legH, labelW = 220,
          left = Math.max(18, Math.round(lvlW)), axisR = labelW + 18;
    const H = top + bottom + leaves.length * rowH, W = 860, plotW = W - left - axisR;
    const sx = ma => left + (maxMa - ma) / (maxMa - minMa) * plotW; // más antiguo a la izquierda
    const sy = y => top + y * rowH + rowH / 2;
    const plotTop = top - 4, plotBot = H - bottom + 4;

    let s = `<svg viewBox="0 0 ${W} ${H}" style="width:100%;max-width:${W}px;display:block">`;
    s += `<rect width="${W}" height="${H}" fill="var(--surface)"/>`;

    // tinte de fondo con el nivel más fino activo (columnas estratigráficas)
    const finest = bandsByLevel.length ? bandsByLevel[bandsByLevel.length - 1] : null;
    if (finest) finest.items.forEach(b => {
      const x1 = sx(b.from), x2 = sx(b.to);
      if (x2 - x1 > .5) s += `<rect x="${x1.toFixed(1)}" y="${plotTop}" width="${(x2 - x1).toFixed(1)}" height="${plotBot - plotTop}" fill="${b.col}" opacity=".10"/>`;
    });

    // filas de bandas apiladas (eón → era → período → época → piso)
    bandsByLevel.forEach((row, ri) => {
      const y = 16 + ri * (bandH + gap);
      s += `<text x="${left - 4}" y="${y + bandH / 2 + 3.2}" font-size="8.5" font-family="var(--mono)" text-anchor="end" fill="var(--muted)" letter-spacing=".06em">${esc((I18N[S.lang]['lvl_' + row.level] || row.level).toUpperCase())}</text>`;
      row.items.forEach(b => {
        const x1 = sx(b.from), x2 = sx(b.to), w = x2 - x1;
        if (w < .5) return;
        s += `<rect class="gband" x="${x1.toFixed(1)}" y="${y}" width="${w.toFixed(1)}" height="${bandH}" fill="${b.col}" stroke="#fff" stroke-width=".8"
                data-n="${esc(b.name)}" data-l="${esc(I18N[S.lang]['lvl_' + row.level] || row.level)}" data-f="${b.from.toFixed(2)}" data-t="${b.to.toFixed(2)}"/>`;
        /* La etiqueta se centra en la parte VISIBLE de la banda, no en la banda
           entera: si la banda empieza antes del borde del gráfico, el centro
           queda fuera y el texto se corta. Y si no cabe, se recorta con puntos
           suspensivos: «Upper Tr» a secas parece un nombre, no un recorte. */
        const vx1 = Math.max(x1, left), vx2 = Math.min(x2, W - axisR), vw = vx2 - vx1;
        if (vw > 10) {
          const cx = (vx1 + vx2) / 2, label = b.name;
          if (vw > label.length * 5.4 + 6) {
            s += `<text x="${cx.toFixed(1)}" y="${y + bandH / 2 + 3.4}" font-size="9.5" text-anchor="middle" fill="#1e2429" font-weight="600" pointer-events="none">${esc(label)}</text>`;
          } else {
            const fit = Math.max(1, Math.floor(vw / 5.2) - 1);
            if (fit >= 2) s += `<text x="${cx.toFixed(1)}" y="${y + bandH / 2 + 3.4}" font-size="8.5" text-anchor="middle" fill="#1e2429" font-weight="700" pointer-events="none">${esc(label.slice(0, fit) + '…')}</text>`;
          }
        }
        // líneas guía verticales en los límites del nivel más fino
        if (row === finest) s += `<line x1="${x1.toFixed(1)}" y1="${plotTop}" x2="${x1.toFixed(1)}" y2="${plotBot}" stroke="${b.col}" stroke-opacity=".45" stroke-width=".8"/>`;
      });
    });

    // eje temporal
    s += `<line x1="${left}" y1="${plotBot}" x2="${W - axisR}" y2="${plotBot}" stroke="var(--line)"/>`;
    const tickStep = niceStep(maxMa - minMa);
    for (let ma = Math.ceil(minMa / tickStep) * tickStep; ma <= maxMa; ma += tickStep) {
      const x = sx(ma);
      s += `<line x1="${x}" y1="${plotTop}" x2="${x}" y2="${plotBot}" stroke="var(--line)" stroke-dasharray="2 4" opacity=".55"/><text x="${x}" y="${H - bottom + 18}" font-size="10" text-anchor="middle" fill="var(--muted)" font-family="var(--mono)">${ma.toFixed(0)}</text>`;
    }
    s += `<text x="${W - axisR}" y="${H - bottom + 30}" font-size="9.5" text-anchor="end" fill="var(--muted)" font-family="var(--mono)">${esc(L.tm_ma)}</text>`;
    // ramas (horizontal en x=edad)
    (function edges(n) {
      const x = sx(n._age), y = sy(n._y);
      n.children.forEach(c => { const cx = sx(c._age), cy = sy(c._y); s += `<path d="M${x} ${y} L${x} ${cy} L${cx} ${cy}" fill="none" stroke="var(--usach-slate)" stroke-width="1.3" stroke-opacity=".7"/>`; edges(c); });
    })(root);
    // hojas: barra de rango fósil + etiqueta
    leaves.forEach(n => {
      const y = sy(n._y), a = ages[n.name];
      if (a) {
        const x1 = sx(a.fad), x2 = sx(a.lad);
        s += `<rect x="${Math.min(x1, x2)}" y="${y - 4}" width="${Math.abs(x2 - x1) + 2}" height="8" rx="3" fill="${taxonColor(a)}" stroke="var(--usach-slate)" stroke-width=".5" stroke-opacity=".35" class="trange" data-name="${esc(n.name)}" data-fad="${a.fad}" data-lad="${a.lad}" data-geo="${esc(geoLabel(a))}" data-src="${esc(S.ageSrc[n.name] || '')}" data-diet="${esc(a.diet || '')}"/>`;
      } else { s += `<circle cx="${sx(n._age)}" cy="${y}" r="3" fill="var(--muted)"/>`; }
      /* Icono del clado, entre el rango y el nombre. Sale del linaje de PaleoDB;
         sin consulta o sin linaje conocido, no se dibuja nada: un icono
         genérico para todos no informa, estorba. */
      /* Si se consultaron los clados, TODOS llevan icono: el conocido su
         silueta, el desconocido una huella. Dejar la fila sin nada la deja
         coja y no dice que el dato falta. */
      const ck = S.clades ? (S.clades[n.name] || '') : null;
      let xlab = W - axisR + 8;
      if (ck !== null) {
        s += `<g class="clg ${ck || 'unk'}" data-name="${esc(n.name)}" data-clade="${esc(ck)}" transform="translate(${xlab},${y - 7})">${cladeGlyph(ck)}</g>`;
        xlab += 19;
      }
      s += `<text x="${xlab}" y="${y + 3.4}" font-size="11" font-style="italic" fill="var(--ink)" class="tlabel" data-name="${esc(n.name)}">${esc(pretty(n.name))}</text>`;
    });
    if (legH) {
      const ly = H - 12;
      let lx = left;
      s += `<g class="cladeleg-svg">`;
      legKeys.forEach(k => {
        s += `<g transform="translate(${lx},${ly - 11})"><path d="${CLADE_PATH[k]}" fill="var(--usach-slate)" fill-opacity=".62" transform="scale(.8)"/></g>`;
        const lbl = String(L['cld_' + k] || k);
        s += `<text x="${lx + 20}" y="${ly}" font-size="10.5" fill="var(--usach-slate)">${esc(lbl)}</text>`;
        lx += 20 + lbl.length * 5.6 + 16;
      });
      if (legUnk) {
        s += `<g transform="translate(${lx},${ly - 11})"><path d="${CLADE_PATH['']}" fill="var(--usach-slate)" fill-opacity=".3" transform="scale(.8)"/></g>`;
        s += `<text x="${lx + 20}" y="${ly}" font-size="10.5" fill="var(--muted)">${esc(L.cld_unk)}</text>`;
      }
      s += `</g>`;
    }
    s += `</svg>`;
    mount.innerHTML = s;
    mount.querySelectorAll('.trange').forEach(el => {
      el.onmousemove = e => {
        const diet = el.dataset.diet; const dl = diet ? `<br>${L.tip_diet}: ${esc(t('diet_' + diet.toLowerCase()) || diet)}` : '';
        const src = el.dataset.src ? `<br>${L.ag_source}: ${esc(L['src_' + el.dataset.src] || el.dataset.src)}` : '';
        showTip(`<b style="font-style:italic">${esc(pretty(el.dataset.name))}</b><br>${L.tip_range}: <span class="mono">${el.dataset.fad}–${el.dataset.lad} Ma</span><br>${esc(el.dataset.geo)}${dl}${src}`, e.clientX, e.clientY);
      };
      el.onmouseleave = hideTip;
    });
    mount.querySelectorAll('.gband').forEach(el => {
      el.onmousemove = e => showTip(`<b>${esc(el.dataset.n)}</b><br>${esc(el.dataset.l)}<br><span class="mono">${el.dataset.f}–${el.dataset.t} Ma</span>`, e.clientX, e.clientY);
      el.onmouseleave = hideTip;
    });
    // leyenda: unidades visibles del nivel más fino activo
    if (finest) {
      legendEl.innerHTML = `<span class="lg-item" style="color:var(--muted);font-family:var(--mono);font-size:10.5px">${esc((I18N[S.lang]['lvl_' + finest.level] || '').toUpperCase())}</span>`
        + finest.items.map(b => `<span class="lg-item"><span class="lg-dot" style="background:${b.col}"></span>${esc(b.name)} <span class="mono" style="color:var(--muted);font-size:10.5px">${b.from.toFixed(0)}–${b.to.toFixed(0)}</span></span>`).join('');
    } else legendEl.innerHTML = '';
  }
  function niceStep(range) { const raw = range / 6; const p = Math.pow(10, Math.floor(Math.log10(raw))); const n = raw / p; return (n < 1.5 ? 1 : n < 3 ? 2 : n < 7 ? 5 : 10) * p; }

  /* ---- Paso 8: Créditos ---- */
  /* ---- Créditos: pie de página permanente (visible en todos los pasos) ---- */
  const FOOT = document.getElementById('foot');
  function renderFooter() {
    const L = I18N[S.lang];
    const cite = `${PAPER.authors} (${PAPER.year}). ${PAPER.title}. ${PAPER.journal}. https://doi.org/${PAPER.doi}`;
    const bibtex = `@article{conchatoro${PAPER.year}paleoforest,\n  author={Concha-Toro, C. and Riquelme-Zamora, C. and Aranciaga-Rolando, M. and Villalobos-Cid, M.},\n  title={${PAPER.title}},\n  journal={${PAPER.journal}},\n  year={${PAPER.year}},\n  doi={${PAPER.doi}}\n}`;
    FOOT.innerHTML = `
      <div class="foot-in">
        <div class="foot-grid2">
          <div>
            <div class="eyebrow">${esc(L.cr_papers)}</div>
            <div class="cite" style="margin-top:10px">
              <b>${esc(PAPER.authors)}</b> (${PAPER.year}). <i>${esc(PAPER.title)}</i>. ${esc(PAPER.journal)}.
              <div class="citebtns">
                <a class="toolbtn" href="${PAPER.url}" target="_blank" rel="noopener">${ic(SVGI.arrowR)}${esc(L.open_paper)}</a>
                <button class="toolbtn" id="cp-cite">${ic(SVGI.copy)}${esc(L.copy_cite)}</button>
                <button class="toolbtn" id="cp-bib">${ic(SVGI.copy)}${esc(L.copy_bibtex)}</button>
              </div>
            </div>
            <div class="cite" style="margin-top:12px">
              <b>${esc(ARACKAR.authors)}</b> (${ARACKAR.year}). <i>${esc(ARACKAR.title)}</i>. ${esc(ARACKAR.journal)}, ${ARACKAR.volume}, ${ARACKAR.article}.
              <div class="citebtns">
                <a class="toolbtn" href="${ARACKAR.url}" target="_blank" rel="noopener">${ic(SVGI.arrowR)}${esc(L.open_paper)}</a>
                <button class="toolbtn" id="cp-acite">${ic(SVGI.copy)}${esc(L.copy_cite)}</button>
                <button class="toolbtn" id="cp-abib">${ic(SVGI.copy)}${esc(L.copy_bibtex)}</button>
              </div>
            </div>
          </div>
          <div>
            <div class="eyebrow">${esc(L.cr_theses)}</div>
            <div class="theses">
              ${THESES.map((th, i) => `
                <div class="thesis">
                  <div class="th-kind">${esc(L[th.kind])}</div>
                  <div class="th-cite"><b>${esc(th.authors)}</b> (${th.year}). <i>${esc(th.title)}</i>.</div>
                  <div class="th-detail">${esc(th.detail)}</div>
                  <button class="toolbtn" data-th="${i}">${ic(SVGI.copy)}${esc(L.copy_cite)}</button>
                </div>`).join('')}
            </div>
            <div class="eyebrow" style="margin-top:18px">${esc(L.cr_sources)}</div>
            <p class="foot-p">${esc(L.cr_sources_p)}</p>
          </div>
        </div>
        <div class="foot-bar">
          <span>DIINF · Universidad de Santiago de Chile</span>
        </div>
      </div>`;
    $('#cp-cite', FOOT).onclick = () => copy(cite);
    $('#cp-acite', FOOT).onclick = () => copy(ARACKAR.cite());
    $('#cp-abib', FOOT).onclick = () => copy(ARACKAR.bibtex());
    $('#cp-bib', FOOT).onclick = () => copy(bibtex);
    FOOT.querySelectorAll('[data-th]').forEach(b => {
      b.onclick = () => {
        const th = THESES[+b.dataset.th];
        copy(`${th.authors} (${th.year}). ${th.title}. ${th.detail}`);
      };
    });
  }

  /* ======================================================================
   * 12. Menú de ayuda, glosario, atajos, tour guiado
   * ==================================================================== */
  function openHelpMenu() {
    const L = I18N[S.lang];
    openModal(L.help, `
      <div style="display:grid;gap:10px">
        <button class="navbtn" id="hm-tour" style="justify-content:flex-start">${ic(SVGI.help)}${esc(L.tour_start)}</button>
        <button class="navbtn" id="hm-gloss" style="justify-content:flex-start">${ic(SVGI.info)}${esc(L.glossary)}</button>
        <button class="navbtn" id="hm-kbd" style="justify-content:flex-start">${ic(SVGI.arrowR)}${esc(L.kbd_help)}</button>
      </div>`);
    $('#hm-tour', modalBk).onclick = () => { closeModal(); startTour(); };
    $('#hm-gloss', modalBk).onclick = openGlossary;
    $('#hm-kbd', modalBk).onclick = openShortcuts;
  }
  function openGlossary() {
    const g = I18N[S.lang].gloss;
    const order = ['parsimony', 'consensus', 'clade', 'rf', 'mds', 'proj', 'pam', 'kmeans', 'fanny', 'clara', 'som', 'dbscan', 'mstknn', 'dunn', 'conn', 'sil', 'hv', 'medoid', 'support', 'ordered', 'ccode', 'matrix', 'base', 'gap', 'weight', 'active', 'fad', 'geoscale'];
    openModal(I18N[S.lang].glossary, order.map(k => `<div class="gloss-item"><h4>${esc(g[k][0])}</h4><p>${esc(g[k][1])}</p></div>`).join(''));
  }
  function openShortcuts() {
    openModal(I18N[S.lang].kbd_help, I18N[S.lang].kbd.map(([k, d]) => `<div class="kbd-row"><span class="kbd">${esc(k)}</span><span>${esc(d)}</span></div>`).join(''));
  }

  // tour con spotlight
  /* Los objetivos: uno por paso de L.tour. Tras mover «Edades» al 7, la guía
     los recorre en el orden del pipeline, no en el de la barra. */
  const TOUR_TARGETS = ['.step[data-i="0"]', '.step[data-i="1"]', '.step[data-i="7"]',
    '.step[data-i="2"]', '.step[data-i="4"]', '.step[data-i="5"]', '#helpBtn'];

  /* El recorrido guiado vive en js/tour.js, compartido con el módulo 1. Antes
     había una copia aquí adentro: dos implementaciones del mismo mecanismo que
     se iban a desincronizar sola. */
  function startTour() {
    const L = I18N[S.lang];
    PFTour.start({
      targets: TOUR_TARGETS,
      steps: L.tour,
      labels: { skip: L.skip, prev: L.prev, next: L.next, done: L.done }
    });
  }
  function endTour() { PFTour.end(); }

  /* ======================================================================
   * 13. Atajos de teclado
   * ==================================================================== */
  addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 'Escape') { closeModal(); closePop(); endTour(); hideTip(); return; }
    if (e.key === 'ArrowRight') { if (S.step < I18N[S.lang].steps.length - 1) go(S.step + 1); }
    else if (e.key === 'ArrowLeft') { if (S.step > 0) go(S.step - 1); }
    else if (e.key >= '1' && e.key <= '9') { const i = +e.key - 1; if (i < I18N[S.lang].steps.length) go(i); }
    else if (e.key === 'g' || e.key === 'G') openGlossary();
    else if (e.key === '?') openShortcuts();
  });

  /* ======================================================================
   * 14. Init
   * ==================================================================== */
  /* Entrega desde el módulo 1: la búsqueda deja el conjunto en sessionStorage y
     navega aquí. Llegan sólo los árboles encontrados —sin consensos— así que
     findConsensusTrees no debería sacar ninguno; igual corre, por si el usuario
     cargó otra cosa encima. Sin edades: se piden en el paso «Edades». */
  function readHandoff() {
    let h = null;
    try { h = JSON.parse(localStorage.getItem('pf_handoff') || 'null'); } catch (e) { return null; }
    if (!h || h.from !== 'inferencia' || !h.newicks || !h.newicks.length) return null;
    // un envío de hace horas no es lo que el usuario está mirando ahora
    if (h.at && Date.now() - h.at > 10 * 60 * 1000) { localStorage.removeItem('pf_handoff'); return null; }
    localStorage.removeItem('pf_handoff');   // se consume una vez
    return {
      key: 'handoff',
      name: h.name || '—',
      group: '',
      desc: { es: '', en: '', pt: '' },
      taxa: h.taxa,
      newicks: h.newicks,
      ages: {},
      matrix: h.matrix,
      ordered: h.ordered || [],
      parsRef: h.best,
      parsRefSrc: 'módulo 1',
      nTrees: h.newicks.length,
      nTaxa: h.taxa.length,
      _handoff: { seed: h.seed, truncated: !!h.truncated, best: h.best }
    };
  }

  function boot() {
    // Sin onboarding automático: la guía se inicia con un clic ("Ver guía"),
    // ya con el idioma elegido por el usuario.
    const hand = readHandoff();
    if (hand) {
      loadDataset(hand);
      renderChrome();
      render();
      toast(I18N[S.lang].hand_ok.replace('{n}', hand.nTrees));
      return;
    }
    /* Venía del módulo 1 y no llegó nada. Caer al ejemplo en silencio es lo
       peor que se puede hacer acá: el usuario ve «Arackar, 97 árboles» y cree
       que son los suyos. Se dice qué pasó. */
    if (/[?&]from=inferencia/.test(location.search)) {
      S.handFailed = true;
    }
    /* Nada se carga solo. Antes boot() hacía loadDataset(window.PF_DATA) y el
       módulo abría con el ejemplo puesto: el usuario veía 96 árboles sin haber
       pedido nada y no tenía cómo saber de dónde salían. El paso Inicio ya trae
       los dos botones para elegir; ahora sí deciden algo. */
    S.data = null;
    renderChrome();
    render();
  }

  // hero forest decorativo
  function heroForestSVG() {
    let s = `<svg viewBox="0 0 700 340" preserveAspectRatio="xMidYMid slice" style="width:100%;height:100%">`;
    for (let i = 0; i < 26; i++) {
      const x = 40 + (i * 27) % 660, y = 40 + ((i * 53) % 260), sc = .5 + (i % 4) * .28, op = .06 + (i % 3) * .04;
      s += `<g transform="translate(${x} ${y}) scale(${sc})" opacity="${op}" stroke="#eafcf9" stroke-width="2" fill="none" stroke-linecap="round">
        <path d="M0 30 V6 M0 6 L-10 -6 M0 6 L10 -6 M-10 -6 L-16 -16 M-10 -6 L-4 -16 M10 -6 L4 -16 M10 -6 L16 -16"/></g>`;
    }
    return s + `</svg>`;
  }

  if (document.readyState === 'loading') addEventListener('DOMContentLoaded', boot); else boot();
})();
