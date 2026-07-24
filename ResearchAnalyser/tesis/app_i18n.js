/* ============================================================
   Idiomas (ES / PT / EN) + tooltips de ayuda + modal + ACM
   Traduce el "chrome" de la interfaz (pestañas, filtros, títulos,
   botones, controles, pies). Los datos y descripciones detalladas
   permanecen en español porque la base es de una universidad chilena.
   ============================================================ */

/* ---------- Referencias ACM / marcos curriculares ---------- */
const ACM_CURRICULUM_URL = "https://www.acm.org/education/curricula-recommendations";
const ACM_CS2023_URL = "https://csed.acm.org/";
const SWEBOK_URL = "https://www.computer.org/education/bodies-of-knowledge/software-engineering";

const ACM_AREA_HELP = `Las áreas de conocimiento se leen como un marco disciplinar para Informática/Computación, inspirado en las recomendaciones curriculares ACM/IEEE (por ejemplo, CS2023). <br><br><a href="${ACM_CURRICULUM_URL}" target="_blank" rel="noopener">Recomendaciones curriculares ACM</a> · <a href="${ACM_CS2023_URL}" target="_blank" rel="noopener">CS2023</a><br><br>Si la app se usa en otra carrera, estas áreas deben reemplazarse por el marco propio de esa disciplina.`;
const APP_AREA_HELP = `Las áreas de aplicación indican hacia qué campo se orienta el trabajo (educación, salud, ingeniería, ciencias sociales, etc.). No son lo mismo que las áreas de conocimiento: un trabajo puede tener una especialidad computacional y aplicarse en otra disciplina.`;
const SWEBOK_HELP = `Áreas del SWEBOK (Software Engineering Body of Knowledge): clasifican el trabajo según las áreas de conocimiento de la ingeniería de software. <br><br><a href="${SWEBOK_URL}" target="_blank" rel="noopener">Ver SWEBOK (IEEE)</a>`;

/* ---------- Diccionario de idiomas ---------- */
const I18N = {
  es: {
    "brand.kicker": "Universidad de Santiago de Chile",
    "brand.title": "Analizador de Memorias DIINF",
    "brand.sub": "Trabajos de título · pregrado, posgrado, guías, co-guías y dominios temáticos",
    "ov.title": "Cargando memorias", "ov.sub": "Leyendo base local 2015-2025",
    "filter.institution": "Institución", "filter.department": "Departamento", "filter.period": "Periodo de publicación",
    "tab.summary": "Resumen", "tab.indicators": "Indicadores", "tab.profiles": "Perfiles",
    "tab.analytics": "Analítica", "tab.domain": "Dominio", "tab.assistant": "Asistente",
    "report.html": "Reporte HTML",
    "resumen.kicker": "Panorama general", "resumen.title": "Vista general de trabajos de título",
    "resumen.desc": "Síntesis del periodo activo: volumen, programas, participación de guías, co-guías y áreas dominantes.",
    "indicadores.kicker": "Métricas detalladas", "indicadores.title": "Indicadores de memorias",
    "indicadores.desc": "Cálculo institucional o por académico(a). Pasa el cursor por las siglas para ver ayuda; haz clic para una explicación más amigable.",
    "indicadores.assist": "<b>Departamento</b> resume la unidad completa. <b>Por académico(a)</b> muestra una tabla con una fila por persona: trabajos guiados, co-guiados, total, pregrado, posgrado y áreas distintas dentro del periodo activo.",
    "control.level": "Nivel de análisis", "control.byDept": "Departamento", "control.byAcademic": "Por académico(a)",
    "perfiles.kicker": "Análisis por unidad o persona", "perfiles.title": "Perfiles de guía académica",
    "perfiles.desc": "Explora la producción del departamento o de un académico(a), con trayectoria, programas, co-guías y relaciones.",
    "control.selection": "Selección", "control.academic": "Académico(a)",
    "perfiles.annualTitle": "Frecuencia anual", "perfiles.annualHint": "trabajos del perfil activo",
    "perfiles.programsTitle": "Programas", "perfiles.programsHint": "distribución por carrera o posgrado",
    "perfiles.gcTitle": "Guía / co-guía", "perfiles.gcHint": "solo cuando se elige académico(a)",
    "perfiles.sankeyTitle": "Flujo programa → especialidad → aplicación", "perfiles.sankeyHint": "Sankey con filtros actuales",
    "perfiles.netTitle": "Relaciones guía/co-guía", "perfiles.netHint": "clic en un nodo o enlace para ver la frecuencia · arrastra los nodos",
    "perfiles.kwTitle": "Nube de palabras clave", "perfiles.kwHint": "tamaño según frecuencia en títulos y keywords",
    "network.focus": "Enfocar", "network.reset": "Ver red completa", "network.placeholder": "Selecciona académico(a)...", "network.works": "trabajos", "network.coguiaWorks": "trabajos en co-guía",
    "analitica.kicker": "Lectura automática", "analitica.title": "Analítica con filtros actuales",
    "analitica.desc": "Hallazgos calculados en el navegador, comparación entre académicos(as), oportunidades de colaboración, alerta de continuidad y buscador global.",
    "ana.insightsTitle": "Hallazgos automáticos", "ana.insightsHint": "se recalculan con los filtros",
    "ana.oppTitle": "Oportunidades de colaboración", "ana.oppHint": "afinidad temática sin co-guía registrada",
    "ana.searchTitle": "Buscador global", "ana.searchHint": "busca en título, resumen, keywords y áreas",
    "ana.searchBtn": "Buscar", "ana.searchPlaceholder": "Ej: machine learning, salud, ciberseguridad...",
    "compare.title": "Comparación entre académicos(as)", "compare.hint": "qué distingue el perfil temático de cada quién",
    "compare.assist": "<b>Cómo leer:</b> compara cómo dos académicos(as) reparten sus trabajos en la variable elegida. También puedes comparar a alguien contra el <b>resto del departamento</b>. Barras a la derecha = términos sobre-representados en A; a la izquierda = sobre-representados en B. χ² y p son referenciales.",
    "compare.aLabel": "Académico(a) A", "compare.bLabel": "Académico(a) B", "compare.varLabel": "Variable",
    "dominio.kicker": "Análisis de dominio", "dominio.title": "Áreas y aparición temporal",
    "dominio.desc": "Selecciona un dominio y revisa qué académicos aparecen asociados a esa categoría por año.",
    "dominio.domainLabel": "Dominio", "dominio.categoryLabel": "Categoría",
    "dominio.timelineTitle": "Presencia por académico(a) y año", "dominio.timelineHint": "intensidad según frecuencia",
    "dominio.rankingTitle": "Ranking del dominio activo", "dominio.rankingHint": "categorías más frecuentes",
    "asistente.kicker": "Chat local", "asistente.title": "Asistente Leo USACH",
    "asistente.desc": "Consulta la base de memorias sin API, sin servidor y sin costo. Las respuestas se calculan en tu navegador con los filtros actuales.",
    "asistente.assist": "Modo local: no usa servicios externos. Trabaja sólo con los datos cargados y respeta institución, departamento y periodo activos.",
    "chat.placeholder": "Pregunta por guías, temas, áreas, años o comparaciones...",
    "help.kicker": "Ayuda", "help.hint": "Haz clic para ver ayuda",
    "footer.download": "Descargar base de datos (CSV)",
    "footer.meta": "Trabajos de título 2015–2025 · Universidad de Santiago de Chile · Departamento de Ingeniería Informática · versión v2",
    "footer.credits": "Desarrollado por Manuel Villalobos-Cid y Valentina Cares Cárdenas · DIINF · USACH",
    "col.indicator": "Indicador", "col.description": "Descripción", "col.qty": "Cantidad", "col.share": "Participación (%)",
    "col.academic": "Académico(a)", "col.guided": "Guiados", "col.coguided": "Co-guiados", "col.total": "Total",
    "col.pre": "Pregrado", "col.pos": "Posgrado", "col.areas": "Áreas",
    "card.works": "Trabajos de título", "card.pre": "Pregrado", "card.pos": "Posgrado", "card.coguia": "Con co-guía",
    "card.topYear": "Año más activo", "card.topGuide": "Guía con más trabajos", "card.topArea": "Área dominante",
    "pstat.guided": "Guiadas", "pstat.coguia": "Co-guías", "pstat.pre": "Pregrado", "pstat.pos": "Posgrado"
  },
  pt: {
    "brand.kicker": "Universidade de Santiago do Chile",
    "brand.title": "Analisador de Trabalhos DIINF",
    "brand.sub": "Trabalhos de conclusão · graduação, pós-graduação, orientadores, co-orientadores e domínios temáticos",
    "ov.title": "Carregando trabalhos", "ov.sub": "Lendo base local 2015-2025",
    "filter.institution": "Instituição", "filter.department": "Departamento", "filter.period": "Período de publicação",
    "tab.summary": "Resumo", "tab.indicators": "Indicadores", "tab.profiles": "Perfis",
    "tab.analytics": "Analítica", "tab.domain": "Domínio", "tab.assistant": "Assistente",
    "report.html": "Relatório HTML",
    "resumen.kicker": "Panorama geral", "resumen.title": "Visão geral dos trabalhos de conclusão",
    "resumen.desc": "Síntese do período ativo: volume, programas, participação de orientadores, co-orientadores e áreas dominantes.",
    "indicadores.kicker": "Métricas detalhadas", "indicadores.title": "Indicadores de trabalhos",
    "indicadores.desc": "Cálculo institucional ou por acadêmico(a). Passe o cursor sobre as siglas para ver ajuda; clique para uma explicação mais amigável.",
    "indicadores.assist": "<b>Departamento</b> resume a unidade completa. <b>Por acadêmico(a)</b> mostra uma tabela com uma linha por pessoa: orientados, co-orientados, total, graduação, pós-graduação e áreas distintas no período ativo.",
    "control.level": "Nível de análise", "control.byDept": "Departamento", "control.byAcademic": "Por acadêmico(a)",
    "perfiles.kicker": "Análise por unidade ou pessoa", "perfiles.title": "Perfis de orientação acadêmica",
    "perfiles.desc": "Explore a produção do departamento ou de um acadêmico(a), com trajetória, programas, co-orientações e relações.",
    "control.selection": "Seleção", "control.academic": "Acadêmico(a)",
    "perfiles.annualTitle": "Frequência anual", "perfiles.annualHint": "trabalhos do perfil ativo",
    "perfiles.programsTitle": "Programas", "perfiles.programsHint": "distribuição por curso ou pós-graduação",
    "perfiles.gcTitle": "Orientação / co-orientação", "perfiles.gcHint": "apenas quando se escolhe acadêmico(a)",
    "perfiles.sankeyTitle": "Fluxo programa → especialidade → aplicação", "perfiles.sankeyHint": "Sankey do filtro ativo",
    "perfiles.netTitle": "Relações orientador/co-orientador", "perfiles.netHint": "clique em um nó ou aresta para ver a frequência · arraste os nós",
    "perfiles.kwTitle": "Nuvem de palavras-chave", "perfiles.kwHint": "tamanho conforme frequência em títulos e keywords",
    "network.focus": "Focar", "network.reset": "Ver rede completa", "network.placeholder": "Selecione acadêmico(a)...", "network.works": "trabalhos", "network.coguiaWorks": "trabalhos em coorientação",
    "analitica.kicker": "Leitura automática", "analitica.title": "Analítica do filtro ativo",
    "analitica.desc": "Achados calculados no navegador, comparação entre acadêmicos(as), oportunidades de colaboração, alerta de continuidade e busca global.",
    "ana.insightsTitle": "Achados automáticos", "ana.insightsHint": "recalculados com os filtros",
    "ana.oppTitle": "Oportunidades de colaboração", "ana.oppHint": "afinidade temática sem co-orientação registrada",
    "ana.searchTitle": "Busca global", "ana.searchHint": "busca em título, resumo, keywords e áreas",
    "ana.searchBtn": "Buscar", "ana.searchPlaceholder": "Ex: machine learning, saúde, cibersegurança...",
    "compare.title": "Comparação entre acadêmicos(as)", "compare.hint": "o que distingue o perfil temático de cada um",
    "compare.assist": "<b>Como ler:</b> compara como dois acadêmicos(as) distribuem seus trabalhos na variável escolhida. Também é possível comparar alguém com o <b>resto do departamento</b>. Barras à direita = termos super-representados em A; à esquerda = em B. χ² e p são referenciais.",
    "compare.aLabel": "Acadêmico(a) A", "compare.bLabel": "Acadêmico(a) B", "compare.varLabel": "Variável",
    "dominio.kicker": "Análise de domínio", "dominio.title": "Áreas e aparição temporal",
    "dominio.desc": "Selecione um domínio e veja quais acadêmicos aparecem associados a essa categoria por ano.",
    "dominio.domainLabel": "Domínio", "dominio.categoryLabel": "Categoria",
    "dominio.timelineTitle": "Presença por acadêmico(a) e ano", "dominio.timelineHint": "intensidade conforme frequência",
    "dominio.rankingTitle": "Ranking do domínio ativo", "dominio.rankingHint": "categorias mais frequentes",
    "asistente.kicker": "Chat local", "asistente.title": "Assistente Leo USACH",
    "asistente.desc": "Consulte a base de trabalhos sem API, sem servidor e sem custo. As respostas são calculadas no seu navegador com o filtro ativo.",
    "asistente.assist": "Modo local: não usa serviços externos. Trabalha apenas com os dados carregados e respeita instituição, departamento e período ativos.",
    "chat.placeholder": "Pergunte por orientadores, temas, áreas, anos ou comparações...",
    "help.kicker": "Ajuda", "help.hint": "Clique para ver ajuda",
    "footer.download": "Baixar base de dados (CSV)",
    "footer.meta": "Trabalhos de conclusão 2015–2025 · Universidade de Santiago do Chile · Departamento de Engenharia Informática · versão v2",
    "footer.credits": "Desenvolvido por Manuel Villalobos-Cid e Valentina Cares Cárdenas · DIINF · USACH",
    "col.indicator": "Indicador", "col.description": "Descrição", "col.qty": "Quantidade", "col.share": "Participação (%)",
    "col.academic": "Acadêmico(a)", "col.guided": "Orientados", "col.coguided": "Co-orientados", "col.total": "Total",
    "col.pre": "Graduação", "col.pos": "Pós-graduação", "col.areas": "Áreas",
    "card.works": "Trabalhos de conclusão", "card.pre": "Graduação", "card.pos": "Pós-graduação", "card.coguia": "Com co-orientação",
    "card.topYear": "Ano mais ativo", "card.topGuide": "Orientador com mais trabalhos", "card.topArea": "Área dominante",
    "pstat.guided": "Orientadas", "pstat.coguia": "Co-orientações", "pstat.pre": "Graduação", "pstat.pos": "Pós-graduação"
  },
  en: {
    "brand.kicker": "University of Santiago, Chile",
    "brand.title": "DIINF Theses Analyzer",
    "brand.sub": "Final projects · undergraduate, graduate, advisors, co-advisors and thematic domains",
    "ov.title": "Loading theses", "ov.sub": "Reading local database 2015-2025",
    "filter.institution": "Institution", "filter.department": "Department", "filter.period": "Publication period",
    "tab.summary": "Summary", "tab.indicators": "Indicators", "tab.profiles": "Profiles",
    "tab.analytics": "Analytics", "tab.domain": "Domain", "tab.assistant": "Assistant",
    "report.html": "HTML report",
    "resumen.kicker": "General overview", "resumen.title": "Overview of final projects",
    "resumen.desc": "Snapshot of the active period: volume, programs, advisor and co-advisor participation and dominant areas.",
    "indicadores.kicker": "Detailed metrics", "indicadores.title": "Thesis indicators",
    "indicadores.desc": "Institutional or per-academic calculation. Hover the acronyms for help; click for a friendlier explanation.",
    "indicadores.assist": "<b>Department</b> summarizes the whole unit. <b>Per academic</b> shows a table with one row per person: advised, co-advised, total, undergraduate, graduate and distinct areas within the active period.",
    "control.level": "Analysis level", "control.byDept": "Department", "control.byAcademic": "Per academic",
    "perfiles.kicker": "Analysis by unit or person", "perfiles.title": "Academic advising profiles",
    "perfiles.desc": "Explore the department's or an academic's output, with trajectory, programs, co-advising and relationships.",
    "control.selection": "Selection", "control.academic": "Academic",
    "perfiles.annualTitle": "Annual frequency", "perfiles.annualHint": "works of the active profile",
    "perfiles.programsTitle": "Programs", "perfiles.programsHint": "distribution by degree or graduate program",
    "perfiles.gcTitle": "Advisor / co-advisor", "perfiles.gcHint": "only when an academic is selected",
    "perfiles.sankeyTitle": "Flow program → specialty → application", "perfiles.sankeyHint": "Sankey of the active filter",
    "perfiles.netTitle": "Advisor/co-advisor relationships", "perfiles.netHint": "click a node or edge to see the frequency · drag the nodes",
    "perfiles.kwTitle": "Keyword cloud", "perfiles.kwHint": "size by frequency in titles and keywords",
    "network.focus": "Focus", "network.reset": "Show full network", "network.placeholder": "Select academic...", "network.works": "works", "network.coguiaWorks": "works as co-advisor",
    "analitica.kicker": "Automatic reading", "analitica.title": "Analytics of the active filter",
    "analitica.desc": "Findings computed in the browser, comparison between academics, collaboration opportunities, continuity alert and global search.",
    "ana.insightsTitle": "Automatic findings", "ana.insightsHint": "recomputed with the filters",
    "ana.oppTitle": "Collaboration opportunities", "ana.oppHint": "thematic affinity without recorded co-advising",
    "ana.searchTitle": "Global search", "ana.searchHint": "searches title, abstract, keywords and areas",
    "ana.searchBtn": "Search", "ana.searchPlaceholder": "e.g. machine learning, health, cybersecurity...",
    "compare.title": "Comparison between academics", "compare.hint": "what sets each person's thematic profile apart",
    "compare.assist": "<b>How to read:</b> compare how two academics distribute their works across the chosen variable. You can also compare someone against the <b>rest of the department</b>. Bars to the right = terms over-represented in A; to the left = in B. χ² and p are indicative.",
    "compare.aLabel": "Academic A", "compare.bLabel": "Academic B", "compare.varLabel": "Variable",
    "dominio.kicker": "Domain analysis", "dominio.title": "Areas and temporal appearance",
    "dominio.desc": "Pick a domain and see which academics appear associated with that category by year.",
    "dominio.domainLabel": "Domain", "dominio.categoryLabel": "Category",
    "dominio.timelineTitle": "Presence by academic and year", "dominio.timelineHint": "intensity by frequency",
    "dominio.rankingTitle": "Active domain ranking", "dominio.rankingHint": "most frequent categories",
    "asistente.kicker": "Local chat", "asistente.title": "Leo USACH Assistant",
    "asistente.desc": "Query the thesis database with no API, no server and no cost. Answers are computed in your browser with the active filter.",
    "asistente.assist": "Local mode: no external services. It works only with the loaded data and respects the active institution, department and period.",
    "chat.placeholder": "Ask about advisors, topics, areas, years or comparisons...",
    "help.kicker": "Help", "help.hint": "Click to see help",
    "footer.download": "Download database (CSV)",
    "footer.meta": "Final projects 2015–2025 · University of Santiago, Chile · Department of Computer Engineering · version v2",
    "footer.credits": "Developed by Manuel Villalobos-Cid and Valentina Cares Cárdenas · DIINF · USACH",
    "col.indicator": "Indicator", "col.description": "Description", "col.qty": "Count", "col.share": "Share (%)",
    "col.academic": "Academic", "col.guided": "Advised", "col.coguided": "Co-advised", "col.total": "Total",
    "col.pre": "Undergraduate", "col.pos": "Graduate", "col.areas": "Areas",
    "card.works": "Final projects", "card.pre": "Undergraduate", "card.pos": "Graduate", "card.coguia": "With co-advisor",
    "card.topYear": "Most active year", "card.topGuide": "Advisor with most works", "card.topArea": "Dominant area",
    "pstat.guided": "Advised", "pstat.coguia": "Co-advised", "pstat.pre": "Undergraduate", "pstat.pos": "Graduate"
  }
};

Object.assign(I18N.es, {
  "resumen.annualTitle":"Frecuencia anual","resumen.annualHint":"trabajos por año",
  "resumen.programsTitle":"Programas","resumen.programsHint":"pregrado y posgrado",
  "resumen.areaKnowTitle":"Áreas de conocimiento","resumen.areaKnowHint":"top 10 con filtros actuales",
  "resumen.areaAppTitle":"Áreas de aplicación","resumen.areaAppHint":"top 10 con filtros actuales"
});
Object.assign(I18N.pt, {
  "resumen.annualTitle":"Frequência anual","resumen.annualHint":"trabalhos por ano",
  "resumen.programsTitle":"Programas","resumen.programsHint":"graduação e pós-graduação",
  "resumen.areaKnowTitle":"Áreas de conhecimento","resumen.areaKnowHint":"top 10 do filtro ativo",
  "resumen.areaAppTitle":"Áreas de aplicação","resumen.areaAppHint":"top 10 do filtro ativo"
});
Object.assign(I18N.en, {
  "resumen.annualTitle":"Annual frequency","resumen.annualHint":"works per year",
  "resumen.programsTitle":"Programs","resumen.programsHint":"undergraduate and graduate",
  "resumen.areaKnowTitle":"Knowledge areas","resumen.areaKnowHint":"top 10 of the active filter",
  "resumen.areaAppTitle":"Application areas","resumen.areaAppHint":"top 10 of the active filter"
});

Object.assign(I18N.es, {
  "card.sub.period":"Periodo","card.sub.works":"trabajos","card.sub.noData":"Sin datos","card.sub.ofFilter":"con filtros actuales"
});
Object.assign(I18N.pt, {
  "card.sub.period":"Período","card.sub.works":"trabalhos","card.sub.noData":"Sem dados","card.sub.ofFilter":"do filtro ativo",
  "ind.TT":"Total de trabalhos de conclusão","ind.TTpre":"Total de trabalhos de graduação",
  "ind.TTC":"Trabalhos de Engenharia Civil em Informática","ind.TTE":"Trabalhos de Engenharia de Execução em Computação e Informática",
  "ind.TTpos":"Total de trabalhos de pós-graduação","ind.TTmgi":"Trabalhos do Mestrado em Engenharia Informática",
  "ind.TTmgc":"Trabalhos do Mestrado em Segurança, Perícia e Auditoria em Processos Informáticos",
  "ind.TTdoc":"Trabalhos do Doutorado em Ciências da Engenharia, menção Engenharia Informática",
  "ind.TTCG":"Trabalhos com professor(a) co-orientador(a)","ind.ACAD":"Acadêmicos(as) distintos que atuam como orientador",
  "ind.AREAS":"Áreas de conhecimento distintas presentes","ind.TCG%":"Taxa de co-orientação (trabalhos com co-orientação / total)",
  "ind.PRE%":"Proporção de graduação","ind.POS%":"Proporção de pós-graduação",
  "ind.DIV":"Diversidade temática (Shannon normalizado 0–1)","ind.MEDIA":"Produção média anual",
  "ind.CONC5":"Concentração: participação dos 5 orientadores principais"
});
Object.assign(I18N.en, {
  "card.sub.period":"Period","card.sub.works":"works","card.sub.noData":"No data","card.sub.ofFilter":"of the active filter",
  "ind.TT":"Total final projects","ind.TTpre":"Total undergraduate final projects",
  "ind.TTC":"Computer Civil Engineering theses","ind.TTE":"Computer Execution Engineering theses",
  "ind.TTpos":"Total graduate final projects","ind.TTmgi":"Master in Computer Engineering theses",
  "ind.TTmgc":"Master in Security, Forensics and Auditing of IT Processes theses",
  "ind.TTdoc":"PhD in Engineering Sciences (Computer Engineering) theses",
  "ind.TTCG":"Final projects with a co-advisor","ind.ACAD":"Distinct academics acting as advisor",
  "ind.AREAS":"Distinct knowledge areas present","ind.TCG%":"Co-advising rate (works with co-advisor / total)",
  "ind.PRE%":"Undergraduate share","ind.POS%":"Graduate share",
  "ind.DIV":"Thematic diversity (normalized Shannon 0–1)","ind.MEDIA":"Average yearly output",
  "ind.CONC5":"Concentration: share of the top 5 advisors"
});

Object.assign(I18N.pt, {
  "ana.trend":"Tendência recente","ana.trend.text":"{n} trabalhos nos últimos 3 anos do filtro; variação {sign}{g}% frente ao triênio anterior.",
  "ana.coguia":"Co-orientação","ana.coguia.text":"{n} trabalhos com co-orientador(a) ({p} do filtro).",
  "ana.prepos":"Graduação vs pós-graduação","ana.prepos.text":"{pre} de graduação ({pp}) e {pos} de pós-graduação ({pop}).",
  "ana.domArea":"Área dominante","ana.domArea.text":"{area} concentra {n} trabalhos ({p}).","ana.noAreas":"Sem áreas informadas.",
  "ana.diversity":"Diversidade temática","ana.diversity.text":"Índice de Shannon normalizado {e} (0 = concentrado em poucas áreas, 1 = muito diverso).",
  "ana.guideLoad":"Carga de orientação","ana.guideLoad.text":"{name} lidera com {n} trabalhos orientados; {g} acadêmicos(as) orientando no total.","ana.noGuides":"Sem orientadores informados.",
  "ana.avgProd":"Produção média","ana.avgProd.text":"≈ {n} trabalhos por ano em {span} anos do filtro.",
  "ana.abstractCov":"Cobertura de resumo","ana.abstractCov.text":"{n} trabalhos com resumo registrado ({p}).",
  "ana.contOk":"Nenhum orientador do filtro ativo ficou sem trabalhos dirigidos no triênio {start}–{anchor}.",
  "ana.contTitle":"Continuidade de orientação","ana.contDesc":"Orientadores do filtro ativo sem trabalhos dirigidos no triênio {start}–{anchor}. Útil para revisar carga, disponibilidade e sucessão na orientação.",
  "ana.contChip":"último trabalho dirigido: {last} · {total} no total",
  "ana.need2":"São necessários ao menos dois orientadores no filtro ativo.","ana.sim":"Similaridade {p}%",
  "ana.oppNone":"Não foram detectadas oportunidades claras (ou os orientadores do filtro já colaboram).",
  "ana.noData":"Sem dados para o filtro ativo.","ana.noMatch":"Sem correspondências no filtro ativo."
});
Object.assign(I18N.en, {
  "ana.trend":"Recent trend","ana.trend.text":"{n} works in the last 3 years of the filter; {sign}{g}% vs the previous 3-year period.",
  "ana.coguia":"Co-advising","ana.coguia.text":"{n} works with a co-advisor ({p} of the filter).",
  "ana.prepos":"Undergraduate vs graduate","ana.prepos.text":"{pre} undergraduate ({pp}) and {pos} graduate ({pop}).",
  "ana.domArea":"Dominant area","ana.domArea.text":"{area} concentrates {n} works ({p}).","ana.noAreas":"No areas reported.",
  "ana.diversity":"Thematic diversity","ana.diversity.text":"Normalized Shannon index {e} (0 = concentrated in few areas, 1 = very diverse).",
  "ana.guideLoad":"Advising load","ana.guideLoad.text":"{name} leads with {n} advised works; {g} academics advising in total.","ana.noGuides":"No advisors reported.",
  "ana.avgProd":"Average output","ana.avgProd.text":"≈ {n} works per year over {span} years of the filter.",
  "ana.abstractCov":"Abstract coverage","ana.abstractCov.text":"{n} works with a recorded abstract ({p}).",
  "ana.contOk":"No advisor in the active filter was left without directed works in the {start}–{anchor} period.",
  "ana.contTitle":"Thesis advising continuity","ana.contDesc":"Advisors in the active filter with no directed works in the {start}–{anchor} period. Useful to review academic load, availability and advising handover.",
  "ana.contChip":"last directed work: {last} · {total} total",
  "ana.need2":"At least two advisors are needed in the active filter.","ana.sim":"Similarity {p}%",
  "ana.oppNone":"No clear opportunities found (or the filter's advisors already collaborate).",
  "ana.noData":"No data for the active filter.","ana.noMatch":"No matches in the active filter."
});

Object.assign(I18N.es, {
  "chat.leoDesc":"Pregunta por académicos(as), áreas, temas, co-guías o años.",
  "chat.quickQuestions":"Preguntas rápidas","chat.clear":"Limpiar chat","chat.send":"Enviar"
});
Object.assign(I18N.pt, {
  "chat.kpi.works":"trabalhos no filtro","chat.kpi.guiding":"acadêmicos(as) orientando","chat.kpi.programs":"programas","chat.kpi.topArea":"área mais frequente",
  "chat.greeting1":"Olá, sou o <b>Leo USACH</b> 🦁. Posso explorar <b>{n}</b> trabalhos de conclusão do filtro ativo.",
  "chat.greeting2":"Pergunte por: <b>trabalhos orientados por um(a) acadêmico(a)</b>, <b>co-orientações de alguém</b>, <b>trabalhos sobre um tema</b>, <b>áreas mais frequentes</b>, <b>orientadores com mais trabalhos</b>, <b>trabalhos de um ano</b>, <b>comparar dois acadêmicos(as)</b> ou <b>o que significa uma área</b>. (Leo responde em espanhol.)",
  "chat.leoDesc":"Pergunte por acadêmicos(as), áreas, temas, co-orientações ou anos.",
  "chat.quickQuestions":"Perguntas rápidas","chat.clear":"Limpar chat","chat.send":"Enviar"
});
Object.assign(I18N.en, {
  "chat.kpi.works":"works in the filter","chat.kpi.guiding":"academics advising","chat.kpi.programs":"programs","chat.kpi.topArea":"most frequent area",
  "chat.greeting1":"Hi, I'm <b>Leo USACH</b> 🦁. I can explore <b>{n}</b> final projects in the active filter.",
  "chat.greeting2":"Ask me about: <b>works advised by an academic</b>, <b>someone's co-advising</b>, <b>works on a topic</b>, <b>most frequent areas</b>, <b>advisors with most works</b>, <b>works from a year</b>, <b>compare two academics</b> or <b>what an area means</b>. (Leo answers in Spanish.)",
  "chat.leoDesc":"Ask about academics, areas, topics, co-advising or years.",
  "chat.quickQuestions":"Quick questions","chat.clear":"Clear chat","chat.send":"Send"
});

Object.assign(I18N.es, {
  "chart.works":"trabajos",
  "prog.exec":"Ing. de Ejecución","prog.civil":"Ing. Civil en Informática","prog.phd":"Doctorado en Cs. Ingeniería",
  "prog.msec":"Magíster en Seguridad","prog.minf":"Magíster en Informática","prog.none":"Sin programa"
});
Object.assign(I18N.pt, {
  "chart.works":"trabalhos",
  "prog.exec":"Eng. de Execução","prog.civil":"Eng. Civil em Informática","prog.phd":"Doutorado em Cs. Eng.",
  "prog.msec":"Mestrado em Segurança","prog.minf":"Mestrado em Informática","prog.none":"Sem programa"
});
Object.assign(I18N.en, {
  "chart.works":"works",
  "prog.exec":"Computer Execution Eng.","prog.civil":"Computer Civil Eng.","prog.phd":"PhD in Eng. Sciences",
  "prog.msec":"MSc in Security","prog.minf":"MSc in Informatics","prog.none":"No program"
});

let MEM_LANG = "es";
try { const s = localStorage.getItem("memorias_lang"); if(s && I18N[s]) MEM_LANG = s; } catch(e){}

function T(key){
  const lang = I18N[MEM_LANG] ? MEM_LANG : "es";
  return (I18N[lang] && I18N[lang][key]) || I18N.es[key] || key;
}

function applyLanguage(){
  const lang = I18N[MEM_LANG] ? MEM_LANG : "es";
  MEM_LANG = lang;
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-i18n]").forEach(el => { el.textContent = T(el.dataset.i18n); });
  document.querySelectorAll("[data-i18n-html]").forEach(el => { el.innerHTML = T(el.dataset.i18nHtml); });
  document.querySelectorAll("[data-i18n-placeholder]").forEach(el => { el.placeholder = T(el.dataset.i18nPlaceholder); });
  document.querySelectorAll("#lang_switch button").forEach(b => b.classList.toggle("on", b.dataset.lang === lang));
  if(typeof applyFriendlyTooltips === "function") applyFriendlyTooltips();
}

function setLanguage(lang){
  if(!I18N[lang]) return;
  MEM_LANG = lang;
  try { localStorage.setItem("memorias_lang", lang); } catch(e){}
  applyLanguage();
  if(typeof renderAll === "function") renderAll();
  if(typeof buildChat === "function" && document.getElementById("p-asistente")?.classList.contains("active")) buildChat(true);
}

/* ---------- Ayuda amigable (siglas + áreas) ---------- */
const FRIENDLY_HELP = {
  TT:    ["Total de trabajos de título", "Cantidad total de trabajos de título con los filtros actuales (todos los programas y grados)."],
  TTpre: ["Trabajos de pregrado", "Trabajos de título de carreras de pregrado con los filtros actuales."],
  TTC:   ["Ingeniería Civil en Informática", "Trabajos de la carrera Ingeniería Civil en Informática."],
  TTE:   ["Ingeniería de Ejecución", "Trabajos de Ingeniería de Ejecución en Computación e Informática."],
  TTpos: ["Trabajos de posgrado", "Trabajos de título de programas de posgrado (magíster y doctorado)."],
  TTmgi: ["Magíster en Ingeniería Informática", "Trabajos del Magíster en Ingeniería Informática."],
  TTmgc: ["Magíster en Seguridad", "Trabajos del Magíster en Seguridad, Peritaje y Auditoría en Procesos Informáticos."],
  TTdoc: ["Doctorado", "Trabajos del Doctorado en Ciencias de la Ingeniería, mención Ingeniería Informática."],
  TTCG:  ["Con co-guía", "Trabajos de título que registran un(a) profesor(a) co-guía."],
  ACAD:  ["Académicos(as) guía", "Número de académicos(as) distintos que actúan como guía con los filtros actuales."],
  AREAS: ["Áreas distintas", "Número de áreas de conocimiento distintas presentes con los filtros actuales." + "<br><br>" + ACM_AREA_HELP],
  "CONC5": ["Concentración (top 5)", "Participación de los 5 guías con más trabajos entre los trabajos seleccionados. Alta concentración = pocos guías acumulan la mayoría."],
  DIV:   ["Diversidad temática", "Índice de Shannon normalizado (0 a 1) sobre áreas de conocimiento. 0 = todo concentrado en un área; 1 = repartido de forma pareja."],
  MEDIA: ["Producción media anual", "Promedio de trabajos por año dentro del periodo seleccionado."],
  "POS%": ["Proporción de posgrado", "Porcentaje de trabajos de posgrado entre los trabajos seleccionados."],
  "PRE%": ["Proporción de pregrado", "Porcentaje de trabajos de pregrado entre los trabajos seleccionados."],
  "TCG%": ["Tasa de co-guía", "Porcentaje de trabajos con co-guía entre los trabajos seleccionados."]
};

function escAttr(s){ return String(s).replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

function showFriendlyHelp(title, body){
  const modal = document.getElementById("help_modal");
  if(!modal) return;
  document.getElementById("help_title").textContent = title || T("help.kicker");
  document.getElementById("help_body").innerHTML = body || "";
  modal.classList.add("show");
  modal.setAttribute("aria-hidden", "false");
}
function hideFriendlyHelp(){
  const modal = document.getElementById("help_modal");
  if(!modal) return;
  modal.classList.remove("show");
  modal.setAttribute("aria-hidden", "true");
}

/* Referencias de marcos de áreas (ACM/IEEE, SWEBOK) accesibles desde la UI */
function showAreaHelp(){ showFriendlyHelp("Áreas de conocimiento (marco ACM/IEEE)", ACM_AREA_HELP); }
function showAppAreaHelp(){ showFriendlyHelp("Áreas de aplicación", APP_AREA_HELP); }
function showSwebokHelp(){ showFriendlyHelp("Áreas del SWEBOK", SWEBOK_HELP); }

/* ---------- Ayuda por texto (títulos, encabezados, tarjetas) ---------- */
const TEXT_HELP = {
  // Encabezados de tabla
  "col.indicator": ["Indicador", "Sigla del indicador. Pasa el cursor o haz clic en cada sigla de la tabla para ver su definición."],
  "col.description": ["Descripción", "Explicación de lo que mide cada indicador."],
  "col.qty": ["Cantidad", "Valor del indicador con los filtros actuales."],
  "col.share": ["Participación (%)", "Porcentaje respecto del total histórico de la base."],
  "col.academic": ["Académico(a)", "Profesor(a) que participa como guía o co-guía."],
  "col.guided": ["Guiados", "Trabajos en que la persona es profesor(a) guía."],
  "col.coguided": ["Co-guiados", "Trabajos en que la persona es profesor(a) co-guía."],
  "col.total": ["Total", "Trabajos en que participa como guía o co-guía, sin duplicar."],
  "col.pre": ["Pregrado", "Trabajos de pregrado en que participa."],
  "col.pos": ["Posgrado", "Trabajos de posgrado en que participa."],
  "col.areas": ["Áreas", "Número de áreas de conocimiento distintas en que participa."],
  // Títulos de gráficos (clave = su data-i18n)
  "resumen.annualTitle": ["Frecuencia anual", "Cantidad de trabajos por año con los filtros actuales."],
  "resumen.programsTitle": ["Programas", "Distribución de trabajos por carrera de pregrado o programa de posgrado."],
  "resumen.areaKnowTitle": ["Áreas de conocimiento", "Áreas disciplinares (marco tipo ACM/IEEE) más frecuentes.<br><br>" + ACM_AREA_HELP],
  "resumen.areaAppTitle": ["Áreas de aplicación", APP_AREA_HELP],
  "perfiles.annualTitle": ["Frecuencia anual", "Trabajos por año del perfil seleccionado o de los filtros actuales."],
  "perfiles.programsTitle": ["Programas", "Distribución del perfil por carrera o posgrado."],
  "perfiles.gcTitle": ["Guía / co-guía", "Reparto entre trabajos guiados y co-guiados cuando se elige un académico."],
  "perfiles.sankeyTitle": ["Flujo programa → especialidad → aplicación", "Diagrama que conecta los programas con las áreas de conocimiento (especialidad) y estas con las áreas de aplicación. Una tesis de pregrado y posgrado aparece en ambos programas."],
  "perfiles.netTitle": ["Relaciones guía/co-guía", "Red de académicos: cada nodo es un(a) profesor(a) y las líneas unen a quienes comparten trabajos. Usa el buscador para enfocar a alguien."],
  "perfiles.kwTitle": ["Nube de palabras clave", "Términos más frecuentes en títulos y palabras clave; el tamaño indica la frecuencia."],
  "ana.insightsTitle": ["Hallazgos automáticos", "Resúmenes calculados en el navegador que se recalculan con los filtros."],
  "ana.oppTitle": ["Oportunidades de colaboración", "Pares de guías con temas afines que aún no registran una co-guía en común."],
  "ana.searchTitle": ["Buscador global", "Busca un término en título, resumen, palabras clave y áreas de los trabajos filtrados."],
  "compare.title": ["Comparación entre académicos(as)", "Prueba χ² con residuos estandarizados: muestra qué términos distinguen a una persona de otra o del resto del departamento. Los valores son referenciales."],
  "dominio.timelineTitle": ["Presencia por académico(a) y año", "En qué años aparece cada académico asociado a la categoría elegida."],
  "dominio.rankingTitle": ["Ranking del dominio activo", "Categorías más frecuentes del dominio seleccionado."],
  // Tarjetas de resumen (clave = data-help)
  "card.works": ["Trabajos de título", "Total de trabajos de título con los filtros actuales."],
  "card.pre": ["Pregrado", "Trabajos de carreras de pregrado."],
  "card.pos": ["Posgrado", "Trabajos de programas de posgrado."],
  "card.coguia": ["Con co-guía", "Trabajos que registran profesor(a) co-guía."],
  "card.topYear": ["Año más activo", "Año con más trabajos con los filtros actuales."],
  "card.topGuide": ["Guía con más trabajos", "Profesor(a) guía con mayor cantidad de trabajos."],
  "card.topArea": ["Área dominante", "Área de conocimiento con más trabajos con los filtros actuales."]
};

function setHelp(elm, title, body){
  if(!elm || !title) return;
  elm.classList.add("has-help");
  elm.setAttribute("data-help-title", title);
  elm.setAttribute("data-help-body", body || "");
  elm.setAttribute("title", `${title} — ${T("help.hint")}`);
}
function clearHelp(elm){
  if(!elm) return;
  elm.classList.remove("has-help");
  elm.removeAttribute("data-help-title");
  elm.removeAttribute("data-help-body");
  elm.removeAttribute("title");
}

/* Aplica ayuda a títulos, tarjetas, etiquetas y (vía decorate) a la tabla */
function applyFriendlyTooltips(){
  // títulos de gráficos con data-i18n
  document.querySelectorAll(".viz-head h4[data-i18n]").forEach(h4 => {
    const h = TEXT_HELP[h4.getAttribute("data-i18n")];
    if(h) setHelp(h4, h[0], h[1]);
  });
  // tarjetas y otros elementos con data-help explícito
  document.querySelectorAll("[data-help]").forEach(elm => {
    const h = TEXT_HELP[elm.getAttribute("data-help")];
    if(h) setHelp(elm, h[0], h[1]);
  });
  // etiquetas de filtros y controles (tooltip nativo)
  document.querySelectorAll(".field label, .control label").forEach(l => l.setAttribute("title", l.textContent.trim()));
  // tabla de indicadores: siglas + encabezados
  decorateIndicatorHelp("tabla_indicadores");
}

function decorateIndicatorHelp(id){
  const table = document.getElementById(id);
  if(!table) return;
  // siglas en la primera columna (modo Departamento)
  table.querySelectorAll("tbody tr").forEach(tr => {
    const cell = tr.querySelector("td");
    if(!cell) return;
    const h = FRIENDLY_HELP[cell.textContent.trim()];
    if(h) setHelp(cell, h[0], h[1]); else clearHelp(cell);
  });
  // encabezados por posición según el modo
  const aca = (typeof state !== "undefined" && state && state.indicatorMode === "academico");
  const keys = aca
    ? ["col.academic","col.guided","col.coguided","col.total","col.pre","col.pos","col.areas"]
    : ["col.indicator","col.description","col.qty","col.share"];
  table.querySelectorAll("thead th").forEach((th, i) => {
    const h = TEXT_HELP[keys[i]];
    if(h) setHelp(th, h[0], h[1]);
  });
}

let HELP_WIRED = false;
function wireFriendlyHelp(){
  if(HELP_WIRED) return;
  document.addEventListener("click", e => {
    if(e.target.closest("#help_close")){ hideFriendlyHelp(); return; }
    if(e.target.id === "help_modal"){ hideFriendlyHelp(); return; }
    const el = e.target.closest("[data-help-title]");
    if(el){ showFriendlyHelp(el.getAttribute("data-help-title"), el.getAttribute("data-help-body")); }
  });
  document.addEventListener("keydown", e => { if(e.key === "Escape") hideFriendlyHelp(); });
  HELP_WIRED = true;
}

function initI18nHelp(){
  document.querySelectorAll("#lang_switch button").forEach(btn => {
    btn.addEventListener("click", () => setLanguage(btn.dataset.lang));
  });
  wireFriendlyHelp();
  applyLanguage();
}
document.addEventListener("DOMContentLoaded", initI18nHelp);
