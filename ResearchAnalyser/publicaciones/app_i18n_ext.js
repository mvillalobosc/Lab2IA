/* ============================================================
   EXTENSIÓN i18n v16 — Traducciones EN/PT para HELPS y TABLAS
   El español canónico vive en app.js (FRIENDLY_HELP / TEXT_HELP
   y las etiquetas de tablas). Aquí sólo se agregan EN y PT y se
   sobrescriben los resolvers fhL / thL / L.
   ============================================================ */
(function () {

  /* URLs ACM (definidas en app.js, accesibles como globales léxicas) */
  var _acmCur = (typeof ACM_CURRICULUM_URL !== 'undefined') ? ACM_CURRICULUM_URL : 'https://www.acm.org/education/curricula-recommendations';
  var _acmCS = (typeof ACM_CS2023_URL !== 'undefined') ? ACM_CS2023_URL : 'https://csed.acm.org/';
  var A = s => `<a href="${_acmCur}" target="_blank" rel="noopener">${s[0]}</a> · <a href="${_acmCS}" target="_blank" rel="noopener">${s[1]}</a>`;

  var ACM_EN = `These specialties are used as a disciplinary reading framework for Computer Science/Computing. In this app they draw on ACM/IEEE/AAAI curricular recommendations, such as CS2023. <br><br>${A(['ACM curricular recommendations','CS2023'])}<br><br>Important: if the app is used in another program, the specialty areas must be replaced by that discipline's own framework. For example, Biomedical Engineering should not be read with the same ACM Computing areas.`;
  var ACM_PT = `Estas especialidades são usadas como um marco de leitura disciplinar para Informática/Computação. Neste app inspiram-se em recomendações curriculares ACM/IEEE/AAAI, como o CS2023. <br><br>${A(['Ver recomendações curriculares ACM','Ver CS2023'])}<br><br>Importante: se o app for usado em outro curso, as áreas de especialidade devem ser trocadas pelo marco próprio dessa disciplina. Por exemplo, Engenharia Biomédica não deveria ser lida com as mesmas áreas ACM de Computação.`;
  var APP_EN = `Application areas indicate the field the publication is oriented toward: education, engineering, health, medicine, social sciences or other domains. They are not the same as ACM areas: a publication may have a computational specialty and be applied in another discipline.<br><br>For other programs, these areas must be adapted to that discipline's vocabulary and not assumed to be universal.`;
  var APP_PT = `As áreas de aplicação indicam para qual campo a publicação está orientada: educação, engenharia, saúde, medicina, ciências sociais ou outros domínios. Não são o mesmo que as áreas ACM: uma publicação pode ter uma especialidade computacional e ser aplicada em outra disciplina.<br><br>Para outros cursos, estas áreas devem ser adaptadas ao vocabulário dessa disciplina e não assumidas como universais.`;
  var FLU_EN = `Connects specialty areas with application areas. In Computer Science, specialties follow an ACM/IEEE/AAAI-style reading; in other programs, the set of specialties must be replaced by the corresponding disciplinary framework.<br><br>${A(['ACM curricular recommendations','CS2023'])}`;
  var FLU_PT = `Conecta áreas de especialidade com áreas de aplicação. Em Informática, as especialidades seguem uma leitura tipo ACM/IEEE/AAAI; em outros cursos, o conjunto de especialidades deve ser substituído pelo marco disciplinar correspondente.<br><br>${A(['Ver recomendações curriculares ACM','Ver CS2023'])}`;

  var _oecd = (typeof OECD_FRASCATI_URL !== 'undefined') ? OECD_FRASCATI_URL : 'https://www.oecd.org/sti/inno/frascati-manual.htm';
  var _anid = (typeof ANID_URL !== 'undefined') ? ANID_URL : 'https://anid.cl';
  var _un = (typeof UN_SDG_URL !== 'undefined') ? UN_SDG_URL : 'https://sdgs.un.org/goals';
  var OCDE_EN = `The OECD classification organizes research into broad fields of knowledge (Natural Sciences, Engineering and Technology, Medical and Health Sciences, Agricultural Sciences, Social Sciences and Humanities) following the Frascati Manual. In Chile, ANID uses it to classify research output and projects.<br><br><a href="${_oecd}" target="_blank" rel="noopener">Frascati Manual (OECD)</a> · <a href="${_anid}" target="_blank" rel="noopener">ANID</a>`;
  var OCDE_PT = `A classificação OCDE organiza a pesquisa em grandes campos do conhecimento (Ciências Naturais, Engenharia e Tecnologia, Ciências Médicas e da Saúde, Ciências Agrícolas, Ciências Sociais e Humanidades) seguindo o Manual de Frascati. No Chile, a ANID a utiliza para classificar a produção científica e os projetos.<br><br><a href="${_oecd}" target="_blank" rel="noopener">Manual de Frascati (OCDE)</a> · <a href="${_anid}" target="_blank" rel="noopener">ANID</a>`;
  var ODS_EN = `The SDG (ANID) areas link each publication to the Sustainable Development Goals of the UN 2030 Agenda, grouped by ANID into broad areas: human wellbeing and capabilities, sustainable and just economies, food systems, energy decarbonization and global environmental commons.<br><br><a href="${_un}" target="_blank" rel="noopener">Sustainable Development Goals (UN)</a> · <a href="${_anid}" target="_blank" rel="noopener">ANID</a>`;
  var ODS_PT = `As áreas ODS (ANID) vinculam cada publicação aos Objetivos de Desenvolvimento Sustentável da Agenda 2030 da ONU, agrupados pela ANID em grandes áreas: bem-estar humano e capacidades, economias sustentáveis e justas, sistemas alimentares, descarbonização energética e bens comuns ambientais.<br><br><a href="${_un}" target="_blank" rel="noopener">Objetivos de Desenvolvimento Sustentável (ONU)</a> · <a href="${_anid}" target="_blank" rel="noopener">ANID</a>`;

  /* ---------- FRIENDLY_HELP (siglas + resumen) ---------- */
  var FH = { en: {}, pt: {} };
  var _fh = {
    'summary.total': [['Total output','Counts how many publications fall in the selected period. It also shows how many academics contribute to that set and the simple average of publications per academic.'],['Produção total','Conta quantas publicações há no período selecionado. Também mostra quantos acadêmicos(as) contribuem para esse conjunto e a média simples de publicações por acadêmico(a).']],
    'summary.tipo': [['Document type','Splits output into journal articles, conference papers and other documents. Useful to see whether the unit publishes more in journals or conferences.'],['Tipo de documento','Separa a produção entre artigos de revista, atas de conferência e outros documentos. Serve para ver se a unidade publica mais em revistas ou conferências.']],
    'summary.index': [['Indexing','Shows how many publications are recorded in Web of Science and how many only in Scopus, according to the flag available in the database.'],['Indexação','Mostra quantas publicações estão registradas na Web of Science e quantas só na Scopus, conforme a marca disponível na base.']],
    'summary.citas': [['Total citations','Sums all citations received by the publications in the active filter. It is a signal of impact, but should always be read together with the field, year and publication type.'],['Citações totais','Soma todas as citações recebidas pelas publicações do filtro ativo. É um sinal de impacto, mas deve sempre ser lido junto com a área, o ano e o tipo de publicação.']],
    'summary.h': [['h-index','An h-index of 10 means there are 10 publications with at least 10 citations each. Here it is computed only from the publications in the active filter.'],['Índice h','Um índice h de 10 significa que existem 10 publicações com pelo menos 10 citações cada. Aqui é calculado apenas com as publicações do filtro ativo.']],
    'summary.q1': [['Q1 journals','Counts articles published in first-quartile journals: journals in the top impact tier within their category.'],['Revistas Q1','Conta os artigos publicados em revistas do primeiro quartil: revistas no tramo superior de impacto dentro de sua categoria.']],
    'summary.global': [['Global reach','Counts the countries appearing in co-authorship affiliations. It helps to look at international collaboration, not quality by itself.'],['Alcance global','Conta os países que aparecem nas afiliações de coautoria. Ajuda a observar a colaboração internacional, não a qualidade por si só.']],
    'summary.especialidad': [['Top specialty', ACM_EN],['Especialidade principal', ACM_PT]],
    'summary.aplicacion': [['Top application', APP_EN],['Aplicação principal', APP_PT]],
    'summary.ocde': [['Top OECD area', OCDE_EN],['Área OCDE principal', OCDE_PT]],
    'summary.ocdeSub': [['Top OECD subarea', OCDE_EN],['Subárea OCDE principal', OCDE_PT]],
    'summary.ods': [['Top SDG area', ODS_EN],['Área ODS principal', ODS_PT]],
    'summary.revista': [['Most published journal','Source or journal with the highest number of articles in the active filter. It indicates recurrence, not necessarily impact.'],['Revista mais publicada','Fonte ou revista com o maior número de artigos do filtro ativo. Indica recorrência, não necessariamente impacto.']],
    'summary.coautoria': [['Co-authorship and collaboration','Authors per publication shows the average team size. Institutional co-authorship indicates the share of publications that include more than one academic from the unit.'],['Coautoria e colaboração','Autores por publicação mostra o tamanho médio das equipes. Coautoria institucional indica a porcentagem de publicações que incluem mais de um(a) acadêmico(a) da unidade.']],
    'summary.mas_citada': [['Most cited publication','The paper with the most citations within the active filter. It may favour older publications because they have had more time to accumulate citations.'],['Publicação mais citada','O artigo com mais citações dentro do filtro ativo. Pode favorecer publicações antigas porque tiveram mais tempo para acumular citações.']],
    'summary.sjr': [['Highest SJR','Shows the publication in the source with the highest SJR. SJR is a measure of impact of the journal or conference, not of the individual article.'],['Maior SJR','Mostra a publicação na fonte com o maior SJR. O SJR é uma medida de impacto da revista ou conferência, não do artigo individual.']],
    'TP': [['Total publications','Number of publication records in the active filter. In institutional tables it may include more than one row per publication if several academics from the unit take part.'],['Total de publicações','Número de registros de publicações no filtro ativo. Em tabelas institucionais pode incluir mais de uma linha por publicação se vários acadêmicos(as) da unidade participarem.']],
    'TPU': [['Unique publications','Counts each publication only once, even if it has more than one academic from the unit as author. Useful to avoid double counting.'],['Publicações únicas','Conta cada publicação uma única vez, mesmo que tenha mais de um(a) acadêmico(a) da unidade como autor. Útil para evitar contagem dupla.']],
    'TPj': [['Journal publications','Number of documents classified as journal articles.'],['Publicações em revistas','Quantidade de documentos classificados como artigos de revista.']],
    'TPp': [['Conference publications','Number of documents classified as conference papers or proceedings.'],['Publicações em atas','Quantidade de documentos classificados como conference paper ou atas de conferência.']],
    'PTPj': [['% in journals','Share of output that corresponds to journal articles.'],['% em revistas','Porcentagem da produção que corresponde a artigos de revista.']],
    'PTPp': [['% in proceedings','Share of output that corresponds to conference proceedings.'],['% em atas','Porcentagem da produção que corresponde a atas de conferência.']],
    'h': [['h-index','Measures output and impact at once: h publications have at least h citations each. Here it is computed only on the active filter.'],['Índice h','Mede produção e impacto ao mesmo tempo: h publicações têm ao menos h citações cada. Aqui é calculado apenas sobre o filtro ativo.']],
    'g': [['g-index','Similar to the h-index, but gives more weight to highly cited publications. Helps detect impact concentrated in standout works.'],['Índice g','Semelhante ao índice h, mas dá mais peso a publicações muito citadas. Ajuda a detectar impacto concentrado em trabalhos de destaque.']],
    'PPA': [['Average per academic','Simple average of publications per academic of the unit in the active filter.'],['Média por acadêmico(a)','Média simples de publicações por acadêmico(a) da unidade no filtro ativo.']],
    'PPAj': [['Journals per academic','Average of journal articles per academic.'],['Revistas por acadêmico(a)','Média de artigos de revista por acadêmico(a).']],
    'PPAp': [['Proceedings per academic','Average of conference proceedings per academic.'],['Atas por acadêmico(a)','Média de atas de conferência por acadêmico(a).']],
    'PPAA': [['Average per year','Average number of publications per year within the selected period.'],['Média por ano','Quantidade média de publicações por ano dentro do período selecionado.']],
    'PPAjA': [['Journals per year','Average number of journal articles per year.'],['Revistas por ano','Quantidade média de artigos de revista por ano.']],
    'PPApA': [['Proceedings per year','Average number of conference proceedings per year.'],['Atas por ano','Quantidade média de atas de conferência por ano.']],
    'TPA': [['Active years','Number of years in the period with at least one publication.'],['Anos ativos','Número de anos do período em que houve ao menos uma publicação.']],
    'PAPP': [['Productivity per active year','Average of publications considering only years with output.'],['Produtividade por ano ativo','Média de publicações considerando apenas os anos com produção.']],
    'TC': [['Total citations','Sum of citations received by the publications in the active filter.'],['Citações totais','Soma de citações recebidas pelas publicações do filtro ativo.']],
    'maxC': [['Maximum citations','Highest number of citations received by a publication in the active filter.'],['Máximo de citações','Maior número de citações recebido por uma publicação do filtro ativo.']],
    'medC': [['Median citations','Central citation value: half of the publications have this many citations or fewer. Less sensitive to extreme cases.'],['Mediana de citações','Valor central de citações: metade das publicações tem esse número de citações ou menos. Menos sensível a casos extremos.']],
    'PCPP': [['Citations per publication','Average citations per publication. It can rise a lot if there are a few highly cited works.'],['Citações por publicação','Média de citações por publicação. Pode subir muito se houver poucos trabalhos muito citados.']],
    'TCPP': [['Cited publications','Number of publications with at least one citation.'],['Publicações citadas','Quantidade de publicações com ao menos uma citação.']],
    'PCP': [['Cited share','Share of output that has already received at least one citation.'],['Proporção citadas','Parte da produção que já recebeu ao menos uma citação.']],
    'CPP': [['Citations per cited publication','Average citations considering only publications that have citations.'],['Citações por publicação citada','Média de citações considerando apenas as publicações que têm citações.']],
    'Q1': [['Q1 journals','Number of articles in first-quartile journals.'],['Revistas Q1','Quantidade de artigos em revistas do primeiro quartil.']],
    'Q2': [['Q2 journals','Number of articles in second-quartile journals.'],['Revistas Q2','Quantidade de artigos em revistas do segundo quartil.']],
    'Q3': [['Q3 journals','Number of articles in third-quartile journals.'],['Revistas Q3','Quantidade de artigos em revistas do terceiro quartil.']],
    'Q4': [['Q4 journals','Number of articles in fourth-quartile journals.'],['Revistas Q4','Quantidade de artigos em revistas do quarto quartil.']],
    'PQ1': [['% articles in Q1','Share of journal articles that are in Q1.'],['% artigos em Q1','Porcentagem de artigos de revista que estão em Q1.']],
    'TINT': [['Internationalization rate','Share of publications with at least one country other than Chile in author affiliations.'],['Taxa de internacionalização','Porcentagem de publicações com ao menos um país diferente do Chile nas afiliações de autores.']],
    'PDOI': [['% with DOI','Share of publications with a registered DOI. Eases traceability and access.'],['% com DOI','Porcentagem de publicações com DOI registrado. Facilita rastreabilidade e acesso.']],
    'PSJR': [['Average SJR','Average SJR of the sources where work was published. It is a measure of the source, not the article.'],['SJR médio','Média do indicador SJR das fontes onde se publicou. É uma medida da fonte, não do artigo.']],
    'maxSJR': [['Maximum SJR','Highest SJR observed among the sources in the active filter.'],['SJR máximo','Maior SJR observado entre as fontes do filtro ativo.']],
    'minSJR': [['Minimum SJR','Lowest SJR observed among the sources in the active filter.'],['SJR mínimo','Menor SJR observado entre as fontes do filtro ativo.']],
    'TA': [['Total academics','Number of academics from the unit that appear with publications in the active filter.'],['Total de acadêmicos(as)','Quantidade de acadêmicos(as) da unidade que aparecem com publicações no filtro ativo.']],
    'NCA': [['Unique collaborators','Number of distinct authors detected in the publications, including internal and external ones.'],['Colaboradores(as) únicos','Quantidade de autores distintos detectados nas publicações, incluindo internos e externos.']],
    'ANCA': [['Average collaborators','Average of distinct authors per publication. Approximates the size of collaboration networks.'],['Média de colaboradores(as)','Média de autores distintos por publicação. Aproxima o tamanho das redes de colaboração.']],
    'PC': [['With co-authorship','Number of publications with more than one author.'],['Com coautoria','Quantidade de publicações com mais de um autor.']],
    'PPCA': [['% with co-authorship','Share of publications written by two or more authors.'],['% com coautoria','Porcentagem de publicações escritas por dois ou mais autores.']],
    'PCAI': [['Institutional co-authorship','Number of publications with more than one academic from the unit taking part.'],['Coautoria institucional','Quantidade de publicações onde participa mais de um(a) acadêmico(a) da unidade.']],
    'PPCAI': [['% institutional co-authorship','Share of publications with internal collaboration within the unit.'],['% coautoria institucional','Porcentagem de publicações com colaboração interna dentro da unidade.']],
    'PPA1': [['% first author','Share of publications where an academic from the unit appears as first author.'],['% primeiro autor','Porcentagem de publicações onde um(a) acadêmico(a) da unidade aparece como primeiro autor.']],
    'PPA2': [['% middle author','Share of publications where an academic from the unit appears in a middle position.'],['% autor intermediário','Porcentagem de publicações onde um(a) acadêmico(a) da unidade aparece em posição intermediária.']],
    'PPA3': [['% last author','Share of publications where an academic from the unit appears as last author.'],['% último autor','Porcentagem de publicações onde um(a) acadêmico(a) da unidade aparece como último autor.']]
  };
  Object.keys(_fh).forEach(k => { FH.en[k] = _fh[k][0]; FH.pt[k] = _fh[k][1]; });
  window.__FH_L = FH;

})();

/* ---------- TEXT_HELP (tooltips contextuales) ---------- */
(function () {
  var _acmCur = (typeof ACM_CURRICULUM_URL !== 'undefined') ? ACM_CURRICULUM_URL : 'https://www.acm.org/education/curricula-recommendations';
  var _acmCS = (typeof ACM_CS2023_URL !== 'undefined') ? ACM_CS2023_URL : 'https://csed.acm.org/';
  var FLU_EN = `Connects specialty areas with application areas. In Computer Science, specialties follow an ACM/IEEE/AAAI-style reading; in other programs, the set of specialties must be replaced by the corresponding disciplinary framework.<br><br><a href="${_acmCur}" target="_blank" rel="noopener">ACM curricular recommendations</a> · <a href="${_acmCS}" target="_blank" rel="noopener">CS2023</a>`;
  var FLU_PT = `Conecta áreas de especialidade com áreas de aplicação. Em Informática, as especialidades seguem uma leitura tipo ACM/IEEE/AAAI; em outros cursos, o conjunto de especialidades deve ser substituído pelo marco disciplinar correspondente.<br><br><a href="${_acmCur}" target="_blank" rel="noopener">Ver recomendações curriculares ACM</a> · <a href="${_acmCS}" target="_blank" rel="noopener">Ver CS2023</a>`;

  var TH = { en: {}, pt: {} };
  var _th = {
    'Universidad': [['University','Filters the database to show only publications associated with the selected university.'],['Universidade','Filtra a base para mostrar apenas publicações associadas à universidade selecionada.']],
    'Unidad académica': [['Academic unit','Filters output by department, program or academic unit.'],['Unidade acadêmica','Filtra a produção por departamento, curso ou unidade acadêmica.']],
    'Periodo de publicación': [['Publication period','Sets the year range used across all views, charts, tables and reports.'],['Período de publicação','Define o intervalo de anos usado em todas as visões, gráficos, tabelas e relatórios.']],
    'Resumen': [['Summary','Quick view of the main figures for output, impact, indexing and collaboration.'],['Resumo','Visão rápida com os principais números de produção, impacto, indexação e colaboração.']],
    'Indicadores': [['Indicators','Tables with bibliometric metrics. Hover over the abbreviations or click to see an explanation.'],['Indicadores','Tabelas com métricas bibliométricas. Passe o cursor sobre as siglas ou clique para ver a explicação.']],
    'Perfiles': [['Profiles','Lets you review the output of a whole unit or of a specific academic.'],['Perfis','Permite revisar a produção de uma unidade inteira ou de um(a) acadêmico(a) específico.']],
    'Dominio': [['Domain','Type of thematic information to analyze: specialty, application, subarea or keyword.'],['Domínio','Tipo de informação temática a analisar: especialidade, aplicação, subárea ou palavra-chave.']],
    'Asistente': [['Assistant','Free local chat to query the database without using an API or external server.'],['Assistente','Chat local gratuito para consultar a base sem usar API nem servidor externo.']],
    'Nivel de análisis': [['Analysis level','Choose whether to see indicators for the whole unit or broken down by academic.'],['Nível de análise','Escolha se quer ver indicadores da unidade inteira ou detalhados por acadêmico(a).']],
    'Selección': [['Selection','Switch between the institutional profile and an academic profile.'],['Seleção','Alterna entre o perfil institucional e o perfil de um(a) acadêmico(a).']],
    'Académico(a)': [['Academic','Select the person whose bibliometric profile you want to review.'],['Acadêmico(a)','Selecione a pessoa cujo perfil bibliométrico deseja revisar.']],
    'Indexación': [['Indexing','Use all publications, only Web of Science or only Scopus.'],['Indexação','Permite usar todas as publicações, só Web of Science ou só Scopus.']],
    'Tipo de documento': [['Document type','Filters the domain analysis by all publications, Web of Science or Scopus.'],['Tipo de documento','Filtra a análise de domínio por todas as publicações, Web of Science ou Scopus.']],
    'Término': [['Term','Choose the word, area or subarea you want to track over time.'],['Termo','Escolha a palavra, área ou subárea que deseja acompanhar ao longo do tempo.']],
    'Frecuencia anual de publicaciones': [['Annual frequency','Shows how many publications there are per year within the active filter.'],['Frequência anual','Mostra quantas publicações há por ano dentro do filtro ativo.']],
    'Trayectoria académica': [['Academic trajectory','Combines annual publications and cumulative citations to see evolution over time.'],['Trajetória acadêmica','Combina publicações anuais e citações acumuladas para ver a evolução ao longo do tempo.']],
    'Distribución': [['Distribution','Summarizes the profile by journal quartile and document type.'],['Distribuição','Resume o perfil por quartil de revista e tipo de documento.']],
    'Principales coautores(as)': [['Main co-authors','Shows the people who most often appear as co-authors in the profile publications.'],['Principais coautores(as)','Mostra as pessoas que mais aparecem como coautoras nas publicações do perfil.']],
    'Revistas y fuentes': [['Journals and sources','Shows where the selected profile publishes most often.'],['Revistas e fontes','Mostra onde o perfil selecionado publica com mais frequência.']],
    'Detalles': [['Details','Summarizes extra information, such as languages, DOI and available links.'],['Detalhes','Resume informações adicionais, como idiomas, DOI e links disponíveis.']],
    'Flujo de áreas': [['Area flow', FLU_EN],['Fluxo de áreas', FLU_PT]],
    'Palabras clave más frecuentes': [['Frequent keywords','Shows the terms that appear most in the publications of the profile or unit.'],['Palavras-chave frequentes','Mostra os termos que mais aparecem nas publicações do perfil ou unidade.']],
    'Fuentes más frecuentes': [['Frequent sources','Lists journals or conferences where most work is published.'],['Fontes frequentes','Lista revistas ou conferências onde mais se publica.']],
    'Red de coautorías': [['Co-authorship network','Each node represents an academic and the links indicate shared publications.'],['Rede de coautorias','Cada nó representa um(a) acadêmico(a) e os links indicam publicações compartilhadas.']],
    'Similitud temática entre académicos(as)': [['Thematic similarity','Groups academics by textual similarity of abstracts, keywords and areas.'],['Similaridade temática','Agrupa acadêmicos(as) pela semelhança textual de resumos, palavras-chave e áreas.']],
    'Distancia euclidiana': [['Euclidean distance','Clustering based on distance between thematic profiles. Smaller distance means greater similarity.'],['Distância euclidiana','Agrupamento baseado na distância entre perfis temáticos. Menor distância indica maior similaridade.']],
    'Correlación': [['Correlation','Clustering based on similar thematic patterns, even if publication volumes differ.'],['Correlação','Agrupamento baseado em padrões temáticos similares, mesmo que os volumes de publicação sejam distintos.']],
    'Colaboración internacional': [['International collaboration','Map of countries present in co-author affiliations.'],['Colaboração internacional','Mapa de países presentes nas afiliações de coautores.']],
    'Producción': [['Output','Summary of the number of publications in the profile and their distribution by indexing.'],['Produção','Resumo do número de publicações do perfil e sua distribuição por indexação.']],
    'Publicaciones': [['Publications','Number of publications in the active filter or profile.'],['Publicações','Quantidade de publicações do filtro ou perfil ativo.']],
    'Identificadores Scopus': [['Scopus identifiers','Codes used by Scopus to identify authors. There may be more than one per person.'],['Identificadores Scopus','Códigos usados pela Scopus para identificar autores. Pode haver mais de um por pessoa.']],
    'Identificadores Web of Science': [['Web of Science identifiers','Author codes used by Web of Science. The link opens the associated author profile or record when available.'],['Identificadores Web of Science','Códigos de autor usados pela Web of Science. O link abre o perfil ou registro de autor associado quando disponível.']],
    'Citas totales': [['Total citations','Sum of citations received by the publications in the active filter.'],['Citações totais','Soma de citações recebidas pelas publicações do filtro ativo.']],
    'Índice h': [['h-index','h publications have at least h citations each.'],['Índice h','h publicações têm ao menos h citações cada.']],
    'Índice g': [['g-index','Indicator similar to h, but more sensitive to highly cited publications.'],['Índice g','Indicador parecido ao h, mas mais sensível a publicações muito citadas.']],
    'Citas / pub.': [['Citations per publication','Average citations received per publication.'],['Citações por publicação','Média de citações recebidas por publicação.']],
    '% en Q1': [['Percentage in Q1','Share of articles placed in first-quartile journals.'],['Porcentagem em Q1','Porcentagem de artigos em revistas do primeiro quartil.']],
    'SJR medio': [['Average SJR','Average SJR of the sources where the profile publishes.'],['SJR médio','Média do indicador SJR das fontes onde o perfil publica.']],
    'Coautores': [['Co-authors','Number of distinct co-authors detected for the profile.'],['Coautores','Quantidade de coautores distintos detectados para o perfil.']],
    '% internac.': [['International percentage','Share of publications with at least one country other than Chile.'],['Porcentagem internacional','Porcentagem de publicações com ao menos um país diferente do Chile.']],
    'Años activo': [['Active years','Number of years between the first and last publication of the profile in the active filter.'],['Anos ativo','Quantidade de anos entre a primeira e a última publicação do perfil no filtro ativo.']],
    'Chat local': [['Local chat','The assistant answers using rules and searches over the CSV loaded in your browser.'],['Chat local','O assistente responde usando regras e buscas sobre o CSV carregado no seu navegador.']],
    'Preguntas rápidas': [['Quick questions','Shortcuts to send frequent queries to the assistant.'],['Perguntas rápidas','Atalhos para enviar consultas frequentes ao assistente.']],
    'Limpiar chat': [['Clear chat','Deletes the current conversation and restores the initial help message.'],['Limpar chat','Apaga a conversa atual e restaura a mensagem inicial de ajuda.']],
    'Hallazgos automáticos': [['Automatic findings','Summarizes relevant patterns in the active filter: recent trend, editorial quality, international collaboration, dominant specialty and highest-impact publication.'],['Achados automáticos','Resume padrões relevantes do filtro ativo: tendência recente, qualidade editorial, colaboração internacional, especialidade dominante e publicação de maior impacto.']],
    'Buscador global': [['Global search','Searches the entire filtered database: title, authors, DOI, source, abstract, keywords, areas, subareas and available codes. If the record has a DOI or link, the title opens the original publication.'],['Busca global','Pesquisa em toda a base filtrada: título, autores, DOI, fonte, resumo, palavras-chave, áreas, subáreas e códigos disponíveis. Se o registro tiver DOI ou link, o título abre a publicação original.']],
    'Comparador χ² entre académicos(as)': [['Chi-squared comparator','Compares two groups on a categorical variable: academic vs academic, academic vs rest of the unit, or rest vs academic. Positive residuals indicate topics more present in A; negative ones, topics more present in B.'],['Comparador qui-quadrado','Compara dois grupos em uma variável categórica: acadêmico(a) vs acadêmico(a), acadêmico(a) vs resto da unidade, ou resto vs acadêmico(a). Resíduos positivos indicam temas mais presentes em A; negativos, temas mais presentes em B.']],
    'Oportunidades de colaboración': [['Collaboration opportunities','Suggests pairs of academics with similar vocabulary or areas that do not appear as co-authors in the filtered database. It is an exploratory signal, not a definitive recommendation.'],['Oportunidades de colaboração','Sugere pares de acadêmicos(as) com vocabulário ou áreas similares que não aparecem como coautores na base filtrada. É um sinal exploratório, não uma recomendação definitiva.']]
  };
  Object.keys(_th).forEach(k => { TH.en[k] = _th[k][0]; TH.pt[k] = _th[k][1]; });
  window.__TH_L = TH;
})();

/* ---------- Etiquetas de tablas + varios + RESOLVERS ---------- */
(function () {
  var LBL = {
    /* varios */
    'Haz clic para ver ayuda': ['Click to see help','Clique para ver ajuda'],
    'Ficha de perfil': ['Profile card','Ficha do perfil'],
    'Resume el perfil institucional o académico seleccionado, incluyendo producción e indexación.': ['Summarizes the selected institutional or academic profile, including output and indexing.','Resume o perfil institucional ou acadêmico selecionado, incluindo produção e indexação.'],
    /* encabezados de columna (institucional) */
    'Indicador': ['Indicator','Indicador'],
    'Sigla': ['Code','Sigla'],
    'Valor': ['Value','Valor'],
    'Académico(a)': ['Academic','Acadêmico(a)'],
    /* etiquetas de filas — rendimiento institucional */
    'Total de publicaciones': ['Total publications','Total de publicações'],
    'Publicaciones únicas': ['Unique publications','Publicações únicas'],
    'En revistas': ['In journals','Em revistas'],
    'En actas de conferencia': ['In conference proceedings','Em atas de conferência'],
    '% en revistas': ['% in journals','% em revistas'],
    '% en actas': ['% in proceedings','% em atas'],
    'Índice h institucional': ['Institutional h-index','Índice h institucional'],
    'Índice g': ['g-index','Índice g'],
    'Promedio por académico(a)': ['Average per academic','Média por acadêmico(a)'],
    'Revistas por académico(a)': ['Journals per academic','Revistas por acadêmico(a)'],
    'Actas por académico(a)': ['Proceedings per academic','Atas por acadêmico(a)'],
    'Promedio por año': ['Average per year','Média por ano'],
    'Revistas por año': ['Journals per year','Revistas por ano'],
    'Actas por año': ['Proceedings per year','Atas por ano'],
    'Años activos': ['Active years','Anos ativos'],
    'Productividad por año activo': ['Productivity per active year','Produtividade por ano ativo'],
    'Total de citas': ['Total citations','Citações totais'],
    'Máximo de citas': ['Maximum citations','Máximo de citações'],
    'Mediana de citas': ['Median citations','Mediana de citações'],
    'Citas por publicación': ['Citations per publication','Citações por publicação'],
    'Publicaciones citadas': ['Cited publications','Publicações citadas'],
    'Proporción citadas': ['Cited share','Proporção citadas'],
    'Citas por publicación citada': ['Citations per cited publication','Citações por publicação citada'],
    'Revistas en Q1': ['Q1 journals','Revistas em Q1'],
    'Revistas en Q2': ['Q2 journals','Revistas em Q2'],
    'Revistas en Q3': ['Q3 journals','Revistas em Q3'],
    'Revistas en Q4': ['Q4 journals','Revistas em Q4'],
    '% artículos en Q1': ['% articles in Q1','% artigos em Q1'],
    'Tasa de internacionalización (%)': ['Internationalization rate (%)','Taxa de internacionalização (%)'],
    '% con DOI': ['% with DOI','% com DOI'],
    'SJR promedio': ['Average SJR','SJR médio'],
    'SJR máximo': ['Maximum SJR','SJR máximo'],
    'SJR mínimo': ['Minimum SJR','SJR mínimo'],
    /* etiquetas de filas — colaboración institucional */
    'Total de académicos(as)': ['Total academics','Total de acadêmicos(as)'],
    'Colaboradores(as) únicos': ['Unique collaborators','Colaboradores(as) únicos'],
    'Promedio de colaboradores(as)': ['Average collaborators','Média de colaboradores(as)'],
    'Con coautoría': ['With co-authorship','Com coautoria'],
    '% con coautoría': ['% with co-authorship','% com coautoria'],
    'Coautoría institucional': ['Institutional co-authorship','Coautoria institucional'],
    '% coautoría institucional': ['% institutional co-authorship','% coautoria institucional'],
    '% primer autor': ['% first author','% primeiro autor'],
    '% autor intermedio': ['% middle author','% autor intermediário'],
    '% último autor': ['% last author','% último autor'],
    /* encabezados por académico (abreviados) */
    'Rev': ['Jrnl','Rev'],
    'Act': ['Conf','Atas'],
    '% Rev': ['% Jrnl','% Rev'],
    'Pub/año': ['Pub/yr','Pub/ano'],
    'Años': ['Years','Anos'],
    '1er': ['1st','1º'],
    'Últ': ['Last','Últ'],
    'Pub.cit': ['Cited','Pub.cit'],
    'Coaut. únicos': ['Uniq. co.','Coaut. únicos'],
    'Con coaut.': ['W/ co.','Com coaut.'],
    'Coaut. inst.': ['Inst. co.','Coaut. inst.'],
    'Internac.': ['Intl.','Internac.'],
    '% Internac.': ['% Intl.','% Internac.'],
    'Países': ['Countries','Países'],
    '% 1er': ['% 1st','% 1º'],
    '% Interm.': ['% Middle','% Interm.'],
    '% Últ.': ['% Last','% Últ.'],
    /* tooltips de columnas por académico */
    'Nombre del/de la académico(a)': ['Name of the academic','Nome do(a) acadêmico(a)'],
    'Publicaciones sin coautoría de la unidad': ['Publications without co-authorship from the unit','Publicações sem coautoria da unidade'],
    'Publicaciones en revistas': ['Journal publications','Publicações em revistas'],
    'Publicaciones en actas de conferencia': ['Conference publications','Publicações em atas de conferência'],
    'Porcentaje en revistas': ['Percentage in journals','Porcentagem em revistas'],
    'Índice h (en el periodo y filtro actual)': ['h-index (in the current period and filter)','Índice h (no período e filtro atual)'],
    'Promedio de publicaciones por año activo': ['Average publications per active year','Média de publicações por ano ativo'],
    'Años activos con publicaciones': ['Active years with publications','Anos ativos com publicações'],
    'Año de la primera publicación': ['Year of the first publication','Ano da primeira publicação'],
    'Año de la última publicación': ['Year of the last publication','Ano da última publicação'],
    'Publicaciones con al menos una cita': ['Publications with at least one citation','Publicações com ao menos uma citação'],
    'Proporción de publicaciones citadas': ['Share of cited publications','Proporção de publicações citadas'],
    'Factor de impacto SJR promedio': ['Average SJR impact factor','Fator de impacto SJR médio'],
    'Factor de impacto SJR máximo': ['Maximum SJR impact factor','Fator de impacto SJR máximo'],
    'Publicaciones en revistas Q1': ['Publications in Q1 journals','Publicações em revistas Q1'],
    'Coautores(as) distintos': ['Distinct co-authors','Coautores(as) distintos'],
    'Promedio de autores por publicación': ['Average authors per publication','Média de autores por publicação'],
    'Publicaciones con coautoría': ['Publications with co-authorship','Publicações com coautoria'],
    'Porcentaje con coautoría': ['Percentage with co-authorship','Porcentagem com coautoria'],
    'Publicaciones con coautoría institucional': ['Publications with institutional co-authorship','Publicações com coautoria institucional'],
    'Porcentaje de coautoría institucional': ['Percentage of institutional co-authorship','Porcentagem de coautoria institucional'],
    'Publicaciones con coautoría internacional': ['Publications with international co-authorship','Publicações com coautoria internacional'],
    'Porcentaje de coautoría internacional': ['Percentage of international co-authorship','Porcentagem de coautoria internacional'],
    'Países distintos de coautoría': ['Distinct co-authorship countries','Países distintos de coautoria'],
    'Porcentaje como primer autor': ['Percentage as first author','Porcentagem como primeiro autor'],
    'Porcentaje como autor intermedio': ['Percentage as middle author','Porcentagem como autor intermediário'],
    'Porcentaje como último autor': ['Percentage as last author','Porcentagem como último autor']
  };
  window.__LBL_L = LBL;

  /* ---------- RESOLVERS (reemplazan los stubs de app.js) ---------- */
  fhL = function (code) {
    var es = (typeof FRIENDLY_HELP !== 'undefined') ? FRIENDLY_HELP[code] : null;
    if (!es) return null;
    var o = (window.__FH_L[S.lang] || {})[code];
    return o || es;
  };
  thL = function (txt) {
    var es = (typeof TEXT_HELP !== 'undefined') ? TEXT_HELP[txt] : null;
    if (!es) return null;
    var o = (window.__TH_L[S.lang] || {})[txt];
    return o || es;
  };
  LBLT = function (s) {
    if (!s || S.lang === 'es') return s;
    var o = window.__LBL_L[s];
    if (!o) return s;
    return (S.lang === 'en' ? o[0] : o[1]) || s;
  };
})();

/* ============================================================
   TRADUCCIÓN DE CONTENIDO DINÁMICO / ESTÁTICO NO-data-i18n  (v17)
   Recorre el DOM y traduce por diccionario los textos fijos que
   los builders (resumen, perfil, dominio, analítica) y el HTML
   escriben en español. Round-trip seguro es<->en<->pt vía WeakMap.
   ============================================================ */
(function () {
  var DICT = {
    /* ----- Resumen: fichas y unidades ----- */
    'Producción total': ['Total output', 'Produção total'],
    'autores(as)': ['authors', 'autores(as)'],
    'por autor(a)': ['per author', 'por autor(a)'],
    'publicaciones por año': ['publications per year', 'publicações por ano'],
    'Tipo de documento': ['Document type', 'Tipo de documento'],
    'Revistas': ['Journals', 'Revistas'],
    'Actas': ['Proceedings', 'Atas'],
    'Otros': ['Other', 'Outros'],
    'Indexación': ['Indexing', 'Indexação'],
    'Citas totales': ['Total citations', 'Citações totais'],
    'por publicación': ['per publication', 'por publicação'],
    'Índice h': ['h-index', 'Índice h'],
    'en el periodo seleccionado': ['in the selected period', 'no período selecionado'],
    'Revistas Q1': ['Q1 journals', 'Revistas Q1'],
    'de los artículos': ['of articles', 'dos artigos'],
    'Alcance global': ['Global reach', 'Alcance global'],
    'países de coautoría': ['co-authorship countries', 'países de coautoria'],
    'Especialidad top': ['Top specialty', 'Especialidade principal'],
    'publicaciones': ['publications', 'publicações'],
    'Aplicación top': ['Top application', 'Aplicação principal'],
    'Área OCDE top': ['Top OECD area', 'Área OCDE principal'],
    'Subárea OCDE top': ['Top OECD subarea', 'Subárea OCDE principal'],
    'Área ODS top': ['Top SDG area', 'Área ODS principal'],
    'Revista más publicada': ['Most published journal', 'Revista mais publicada'],
    'artículos': ['articles', 'artigos'],
    'Coautoría · colaboración': ['Co-authorship · collaboration', 'Coautoria · colaboração'],
    'Autores por pub.': ['Authors per pub.', 'Autores por pub.'],
    'Coautoría institucional': ['Institutional co-authorship', 'Coautoria institucional'],
    'Publicación más citada': ['Most cited publication', 'Publicação mais citada'],
    'citas': ['citations', 'citações'],
    'Mayor factor de impacto (SJR)': ['Highest impact factor (SJR)', 'Maior fator de impacto (SJR)'],
    'No hay datos para el periodo seleccionado.': ['No data for the selected period.', 'Sem dados para o período selecionado.'],
    /* ----- Perfil individual ----- */
    'Publicaciones': ['Publications', 'Publicações'],
    'Índice g': ['g-index', 'Índice g'],
    'Citas / pub.': ['Citations / pub.', 'Citações / pub.'],
    '% en Q1': ['% in Q1', '% em Q1'],
    'SJR medio': ['Mean SJR', 'SJR médio'],
    'Coautores': ['Co-authors', 'Coautores'],
    '% internac.': ['% intl.', '% internac.'],
    'Años activo': ['Active years', 'Anos ativo'],
    'Título': ['Title', 'Título'],
    'Año': ['Year', 'Ano'],
    'Fuente': ['Source', 'Fonte'],
    'Tipo': ['Type', 'Tipo'],
    'Citas': ['Citations', 'Citações'],
    'Revista': ['Journal', 'Revista'],
    'Conferencia': ['Conference', 'Conferência'],
    'Sin coautorías registradas.': ['No co-authorships on record.', 'Sem coautorias registradas.'],
    'unidad': ['unit', 'unidade'],
    'Sin datos temporales.': ['No temporal data.', 'Sem dados temporais.'],
    'Citas acumuladas': ['Cumulative citations', 'Citações acumuladas'],
    'citas acumuladas': ['cumulative citations', 'citações acumuladas'],
    'Cuartil': ['Quartile', 'Quartil'],
    'Conferencias': ['Conferences', 'Conferências'],
    'Sin Q': ['No Q', 'Sem Q'],
    'CUARTIL': ['QUARTILE', 'QUARTIL'],
    'TIPO': ['TYPE', 'TIPO'],
    'Revista / fuente': ['Journal / source', 'Revista / fonte'],
    'Pubs': ['Pubs', 'Pubs'],
    'Sin datos de revistas.': ['No journal data.', 'Sem dados de revistas.'],
    'Áreas OCDE': ['OECD areas', 'Áreas OCDE'],
    'Subáreas OCDE': ['OECD subareas', 'Subáreas OCDE'],
    'Áreas ODS (ANID)': ['SDG areas (ANID)', 'Áreas ODS (ANID)'],
    'Idiomas de publicación': ['Publication languages', 'Idiomas de publicação'],
    'Accesibilidad': ['Accessibility', 'Acessibilidade'],
    'Con DOI': ['With DOI', 'Com DOI'],
    'Con enlace': ['With link', 'Com link'],
    /* ----- Títulos y hints del HTML estático ----- */
    'Frecuencia anual de publicaciones': ['Annual publication frequency', 'Frequência anual de publicações'],
    'Trayectoria académica': ['Academic trajectory', 'Trajetória acadêmica'],
    'producción anual y citas acumuladas': ['annual output and cumulative citations', 'produção anual e citações acumuladas'],
    'Distribución': ['Distribution', 'Distribuição'],
    'por cuartil y tipo': ['by quartile and type', 'por quartil e tipo'],
    'Principales coautores(as)': ['Main co-authors', 'Principais coautores(as)'],
    'clic en el título para abrir el paper': ['click the title to open the paper', 'clique no título para abrir o artigo'],
    'Revistas y fuentes': ['Journals and sources', 'Revistas e fontes'],
    'Detalles': ['Details', 'Detalhes'],
    'Flujo de áreas': ['Area flow', 'Fluxo de áreas'],
    'Especialidad → Aplicación': ['Specialty → Application', 'Especialidade → Aplicação'],
    'Palabras clave más frecuentes': ['Most frequent keywords', 'Palavras-chave mais frequentes'],
    'Fuentes más frecuentes': ['Most frequent sources', 'Fontes mais frequentes'],
    'Red de coautorías': ['Co-authorship network', 'Rede de coautorias'],
    'arrastra los nodos · pasa el cursor para resaltar': ['drag nodes · hover to highlight', 'arraste os nós · passe o cursor para destacar'],
    'Similitud temática entre académicos(as)': ['Thematic similarity between academics', 'Similaridade temática entre acadêmicos(as)'],
    'agrupamiento jerárquico': ['hierarchical clustering', 'agrupamento hierárquico'],
    'Colaboración internacional': ['International collaboration', 'Colaboração internacional'],
    'países coautores': ['co-author countries', 'países coautores'],
    'Hallazgos automáticos': ['Automatic findings', 'Achados automáticos'],
    'lectura rápida del filtro activo': ['quick read of the active filter', 'leitura rápida do filtro ativo'],
    'Buscador global': ['Global search', 'Busca global'],
    'autores, papers, DOI, áreas, fuentes y códigos': ['authors, papers, DOI, areas, sources and codes', 'autores, artigos, DOI, áreas, fontes e códigos'],
    'Comparador χ² entre académicos(as)': ['χ² comparator between academics', 'Comparador χ² entre acadêmicos(as)'],
    'residuos positivos = sobre-representación': ['positive residuals = over-representation', 'resíduos positivos = sobre-representação'],
    'Oportunidades de colaboración': ['Collaboration opportunities', 'Oportunidades de colaboração'],
    'similitud temática sin coautoría registrada': ['thematic similarity without recorded co-authorship', 'similaridade temática sem coautoria registrada'],
    'Buscar en toda la base filtrada...': ['Search the entire filtered database...', 'Buscar em toda a base filtrada...'],
    /* ----- Selectores de variable / dominio (texto; value queda intacto) ----- */
    'Áreas de especialidad': ['Specialty areas', 'Áreas de especialidade'],
    'Áreas de aplicación': ['Application areas', 'Áreas de aplicação'],
    'Subáreas de aplicación': ['Application subareas', 'Subáreas de aplicação'],
    'Palabras clave': ['Keywords', 'Palavras-chave'],
    'Palabras claves': ['Keywords', 'Palavras-chave'],
    /* ----- Dominio (app_viz) ----- */
    'Identificadores Scopus': ['Scopus identifiers', 'Identificadores Scopus'],
    'Identificadores Web of Science': ['Web of Science identifiers', 'Identificadores Web of Science'],
    'No fue posible calcular.': ['Could not be computed.', 'Não foi possível calcular.'],
    'No hay datos para los filtros seleccionados.': ['No data for the selected filters.', 'Sem dados para os filtros selecionados.'],
    'Producción': ['Output', 'Produção'],
    'Se necesitan al menos 2 académicos(as).': ['At least 2 academics are needed.', 'São necessários pelo menos 2 acadêmicos(as).'],
    'Sin datos de áreas para este perfil.': ['No area data for this profile.', 'Sem dados de áreas para este perfil.'],
    'Sin datos para el filtro actual.': ['No data for the current filter.', 'Sem dados para o filtro atual.'],
    'Sin datos para ese término.': ['No data for that term.', 'Sem dados para esse termo.'],
    'Sin datos.': ['No data.', 'Sem dados.'],
    'Sin palabras clave.': ['No keywords.', 'Sem palavras-chave.'],
    'Sin términos comparables.': ['No comparable terms.', 'Sem termos comparáveis.'],
    'Total': ['Total', 'Total'],
    'Selecciona académico(a)...': ['Select an academic...', 'Selecione um(a) acadêmico(a)...'],
    'Selecciona un académico(a).': ['Select an academic.', 'Selecione um(a) acadêmico(a).'],
    'Sin clasificación': ['Unclassified', 'Sem classificação'],
    'Sin Clasificación': ['Unclassified', 'Sem classificação'],
    'APLICACIÓN': ['APPLICATION', 'APLICAÇÃO'],
    'ESPECIALIDAD': ['SPECIALTY', 'ESPECIALIDADE'],
    'sobre-representado (+) · sub-representado (−)': ['over-represented (+) · under-represented (−)', 'sobre-representado (+) · sub-representado (−)'],
    'año': ['year', 'ano'],
    'distancia': ['distance', 'distância'],
    /* ----- Analítica ----- */
    'Sin publicaciones citadas.': ['No cited publications.', 'Sem publicações citadas.'],
    'La longitud de la barra muestra cuánto se aparta cada término de lo esperado.': ['Bar length shows how far each term departs from the expected.', 'O comprimento da barra mostra o quanto cada termo se afasta do esperado.'],
    'No se detectaron oportunidades claras con el filtro activo.': ['No clear opportunities detected with the active filter.', 'Não foram detectadas oportunidades claras com o filtro ativo.'],
    'Resto de la unidad': ['Rest of the unit', 'Restante da unidade'],
    'Selecciona un académico(a) en A o B para comparar contra el resto de la unidad.': ['Select an academic in A or B to compare against the rest of the unit.', 'Selecione um(a) acadêmico(a) em A ou B para comparar com o restante da unidade.'],
    'Sin coincidencias.': ['No matches.', 'Sem correspondências.'],
    'Sin datos para el filtro activo.': ['No data for the active filter.', 'Sem dados para o filtro ativo.'],
    'variable comparada': ['compared variable', 'variável comparada'],
    'Alerta de continuidad investigativa': ['Research continuity alert', 'Alerta de continuidade em pesquisa'],
    /* ----- Toggles / segmentados ----- */
    'Institucionales': ['Institutional', 'Institucionais'],
    'Por académico(a)': ['By academic', 'Por acadêmico(a)'],
    'Institucional': ['Institutional', 'Institucional'],
    'Por autor(a)': ['By author', 'Por autor(a)']
  };
  window.__DICT_DYN = DICT;

  function trLookup(es) {
    if (!es) return null;
    if (Object.prototype.hasOwnProperty.call(DICT, es)) return DICT[es];
    var o = window.__LBL_L && window.__LBL_L[es];
    return o || null;
  }
  function pick(o) { return S.lang === 'en' ? o[0] : o[1]; }

  /* Traductor inline (para Plotly y strings con números incrustados) */
  T = function (s) {
    if (!s || S.lang === 'es') return s;
    var o = trLookup(s);
    return o ? (pick(o) || s) : s;
  };

  /* Guarda el texto español original por nodo -> round-trip seguro */
  var __ORIG = new WeakMap();
  var SKIP_TAG = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, CANVAS: 1, TEXTAREA: 1, svg: 1 };

  function isSvg(el) { return el.namespaceURI && el.namespaceURI.indexOf('svg') !== -1; }

  function walk(node, lang) {
    for (var n = node.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3) {
        var orig = __ORIG.get(n);
        if (orig === undefined) { orig = n.nodeValue; __ORIG.set(n, orig); }
        var trimmed = orig.replace(/^\s+|\s+$/g, '');
        if (!trimmed) continue;
        var o = trLookup(trimmed);
        if (o) {
          var tgt = (lang === 'es') ? trimmed : (pick(o) || trimmed);
          var lead = (orig.match(/^\s*/) || [''])[0];
          var trail = (orig.match(/\s*$/) || [''])[0];
          var next = lead + tgt + trail;
          if (n.nodeValue !== next) n.nodeValue = next;
        } else if (lang === 'es' && n.nodeValue !== orig) {
          n.nodeValue = orig;
        }
      } else if (n.nodeType === 1) {
        var tag = n.tagName;
        if (SKIP_TAG[tag] || isSvg(n)) continue;
        /* applyLanguage() ya maneja estos: no tocarlos */
        if (n.hasAttribute && (n.hasAttribute('data-i18n') || n.hasAttribute('data-i18n-html') || n.hasAttribute('data-i18n-placeholder'))) continue;
        /* <option> sin value explícito usa su texto COMO valor: no traducir para no romper la lógica */
        if (tag === 'OPTION' && !(n.hasAttribute && n.hasAttribute('value'))) continue;
        if (tag === 'INPUT') {
          if (n.placeholder) {
            var po = __ORIG.get(n);
            if (po === undefined) { po = n.placeholder; __ORIG.set(n, po); }
            var pl = trLookup(po);
            if (pl) n.placeholder = (lang === 'es') ? po : (pick(pl) || po);
          }
          continue;
        }
        walk(n, lang);
      }
    }
  }

  i18nDynamic = function (root) {
    try { walk(root || document.body, (typeof I18N !== 'undefined' && I18N[S.lang]) ? S.lang : 'es'); }
    catch (e) { console.error('i18nDynamic', e); }
  };
})();
