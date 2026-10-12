/* ============================================================
   ASISTENTE BIBLIOMÉTRICO LOCAL
   La comprensión de la pregunta vive en ../asistente.js (motor
   compartido con el módulo de tesis). Este archivo solo le dice
   al motor cómo leer los campos de las publicaciones y cómo
   dibujar cada tipo de respuesta. Sin API ni servidor.
   ============================================================ */

const ChatLocal = { wired: false, asked: false, engine: null };

const CHAT_PROMPTS = {
  es: [
    '¿Cuáles son las publicaciones más citadas?',
    'Publicaciones Q1 de Villalobos desde 2020',
    'Cuántas publicaciones sobre inteligencia artificial hay en WoS',
    '¿Quiénes son los autores más productivos?',
    'Coautores de Manuel Villalobos',
    'Compara a Bonacic con Parada',
    'Publicaciones por año en actas de congreso',
    'Países de colaboración',
    '¿En qué revistas se publica más?',
    '¿Qué significan las áreas ACM?'
  ],
  en: [
    'Which are the most cited publications?',
    'Q1 publications by Villalobos since 2020',
    'How many publications about artificial intelligence are in WoS',
    'Who are the most productive authors?',
    'Coauthors of Manuel Villalobos',
    'Compare Bonacic with Parada',
    'Conference papers by year',
    'Collaboration countries',
    'Which journals are most frequent?',
    'What do ACM areas mean?'
  ],
  pt: [
    'Quais são as publicações mais citadas?',
    'Publicações Q1 de Villalobos desde 2020',
    'Quantas publicações sobre inteligência artificial há na WoS',
    'Quem são os autores mais produtivos?',
    'Coautores de Manuel Villalobos',
    'Compare Bonacic com Parada',
    'Publicações por ano em anais de congresso',
    'Países de colaboração',
    'Em que revistas se publica mais?',
    'O que significam as áreas ACM?'
  ]
};

/* Textos propios de este módulo (el motor trae los suyos) */
const CHAT_UI = {
  es: { greet1: 'Puedo explorar <b>{n}</b> publicaciones únicas del filtro activo.', greet2: 'Combino condiciones en una misma pregunta: <b>persona</b>, <b>años</b>, <b>cuartil</b>, <b>WoS o Scopus</b>, <b>tipo de documento</b>, <b>tema</b> y <b>país</b>. Por ejemplo: “cuántas publicaciones Q1 tiene Villalobos entre 2020 y 2023”, “coautores de Bonacic”, “publicaciones por año sobre salud”, “compara a X con Y” o “revistas más frecuentes”.', pubs: 'publicaciones', unique: 'publicaciones únicas', cites: 'citas', perPub: 'citas por publicación', hIndex: 'índice h', q1: 'Q1', q1pct: 'de Q1', years: 'periodo', authors: 'académicos(as)', wos: 'en WoS', scopus: 'en Scopus', both: 'en ambas', journal: 'artículos de revista', conf: 'actas', byAuthor: 'Publicaciones por académico(a)', citesByAuthor: 'Citas acumuladas', byYear: 'Publicaciones por año', citesByYear: 'Citas por año de publicación', sources: 'Revistas y fuentes más frecuentes', countries: 'Países de coautoría (sin Chile)', intl: 'con coautoría internacional', noCountries: 'No hay países de coautoría registrados en estas publicaciones.', coauth: 'Coautores(as) más frecuentes de', coauthTitle: 'Coautorías', unranked: 'Sin cuartil', coauthExt: 'Coautores(as) externos más frecuentes', coauthInt: 'Coautoría dentro de la unidad', noCoauth: 'No encontré coautorías registradas para', quartiles: 'Distribución por cuartil', specialties: 'Especialidades', applications: 'Aplicaciones', keywords: 'Palabras clave', more: '…y {n} publicaciones más. Pide “todas” o agrega una condición para acotar.', compare: 'Comparación dentro del filtro consultado', period: 'periodo', topArea: 'Especialidad frecuente', records: 'registros', tryAlso: 'Prueba con', noPubs: 'No encontré publicaciones para esa consulta.', suggest: ['Publicaciones Q1 desde 2020', 'Coautores de Villalobos', 'Publicaciones sobre optimización'] },
  en: { greet1: 'I can explore <b>{n}</b> unique publications in the active filter.', greet2: 'I combine conditions in one question: <b>person</b>, <b>years</b>, <b>quartile</b>, <b>WoS or Scopus</b>, <b>document type</b>, <b>topic</b> and <b>country</b>. For example: “how many Q1 publications does Villalobos have between 2020 and 2023”, “coauthors of Bonacic”, “publications by year about health”, “compare X with Y” or “most frequent journals”.', pubs: 'publications', unique: 'unique publications', cites: 'citations', perPub: 'citations per publication', hIndex: 'h-index', q1: 'Q1', q1pct: 'Q1 share', years: 'period', authors: 'academics', wos: 'in WoS', scopus: 'in Scopus', both: 'in both', journal: 'journal articles', conf: 'proceedings', byAuthor: 'Publications per academic', citesByAuthor: 'Accumulated citations', byYear: 'Publications per year', citesByYear: 'Citations by publication year', sources: 'Most frequent journals and sources', countries: 'Co-authorship countries (excluding Chile)', intl: 'with international co-authorship', noCountries: 'No co-authorship countries are recorded for these publications.', coauth: 'Most frequent co-authors of', coauthTitle: 'Co-authorships', unranked: 'No quartile', coauthExt: 'Most frequent external co-authors', coauthInt: 'Co-authorship within the unit', noCoauth: 'No co-authorships recorded for', quartiles: 'Distribution by quartile', specialties: 'Specialties', applications: 'Applications', keywords: 'Keywords', more: '…and {n} more publications. Ask for “all” or add a condition to narrow it down.', compare: 'Comparison within the queried filter', period: 'period', topArea: 'Frequent specialty', records: 'records', tryAlso: 'Try', noPubs: 'No publications found for that query.', suggest: ['Q1 publications since 2020', 'Coauthors of Villalobos', 'Publications about optimization'] },
  pt: { greet1: 'Posso explorar <b>{n}</b> publicações únicas do filtro ativo.', greet2: 'Combino condições numa mesma pergunta: <b>pessoa</b>, <b>anos</b>, <b>quartil</b>, <b>WoS ou Scopus</b>, <b>tipo de documento</b>, <b>tema</b> e <b>país</b>. Por exemplo: “quantas publicações Q1 tem Villalobos entre 2020 e 2023”, “coautores de Bonacic”, “publicações por ano sobre saúde”, “compare X com Y” ou “revistas mais frequentes”.', pubs: 'publicações', unique: 'publicações únicas', cites: 'citações', perPub: 'citações por publicação', hIndex: 'índice h', q1: 'Q1', q1pct: 'de Q1', years: 'período', authors: 'acadêmicos(as)', wos: 'na WoS', scopus: 'na Scopus', both: 'em ambas', journal: 'artigos de revista', conf: 'anais', byAuthor: 'Publicações por acadêmico(a)', citesByAuthor: 'Citações acumuladas', byYear: 'Publicações por ano', citesByYear: 'Citações por ano de publicação', sources: 'Revistas e fontes mais frequentes', countries: 'Países de coautoria (sem Chile)', intl: 'com coautoria internacional', noCountries: 'Não há países de coautoria registrados nessas publicações.', coauth: 'Coautores(as) mais frequentes de', coauthTitle: 'Coautorias', unranked: 'Sem quartil', coauthExt: 'Coautores(as) externos mais frequentes', coauthInt: 'Coautoria dentro da unidade', noCoauth: 'Não encontrei coautorias registradas para', quartiles: 'Distribuição por quartil', specialties: 'Especialidades', applications: 'Aplicações', keywords: 'Palavras-chave', more: '…e mais {n} publicações. Peça “todas” ou acrescente uma condição para delimitar.', compare: 'Comparação dentro do filtro consultado', period: 'período', topArea: 'Especialidade frequente', records: 'registros', tryAlso: 'Tente', noPubs: 'Não encontrei publicações para essa consulta.', suggest: ['Publicações Q1 desde 2020', 'Coautores de Villalobos', 'Publicações sobre otimização'] }
};
const cu = () => CHAT_UI[S.lang] || CHAT_UI.es;

const AREA_DEFINITIONS = {
  'artificial intelligence': 'Área de computación dedicada a sistemas que aprenden, razonan, predicen o toman decisiones a partir de datos, reglas o modelos. Incluye aprendizaje automático, visión, lenguaje natural y sistemas inteligentes.',
  'algorithms and complexity': 'Estudia métodos para resolver problemas computacionales y cuánto tiempo, memoria o recursos necesitan. Ayuda a entender si una solución escala bien o se vuelve impracticable.',
  'parallel and distributed computing': 'Trabaja con cómputo repartido entre varios procesadores, máquinas o nodos. Incluye concurrencia, sistemas distribuidos, nube, alto rendimiento y coordinación entre procesos.',
  'networking and communication': 'Se enfoca en redes de computadores, protocolos, transmisión de datos, conectividad, rendimiento y seguridad de la comunicación digital.',
  'specialized platform development': 'Diseño y construcción de plataformas específicas, por ejemplo sistemas embebidos, móviles, web, cloud, IoT o entornos especializados de ejecución.',
  'human-computer interaction': 'Estudia cómo las personas interactúan con sistemas computacionales. Incluye usabilidad, experiencia de usuario, accesibilidad, interfaces y evaluación con usuarios.',
  'operating systems': 'Área dedicada a los sistemas que administran recursos del computador, como memoria, procesos, archivos, dispositivos y concurrencia.',
  'society, ethics and professionalism': 'Analiza impactos sociales, éticos y profesionales de la computación: privacidad, sesgos, responsabilidad, regulación, educación y uso responsable de tecnología.',
  'data management': 'Se ocupa de almacenar, organizar, consultar, integrar y gobernar datos. Incluye bases de datos, recuperación de información, calidad de datos y gestión de grandes volúmenes.',
  'software development fundamentals': 'Fundamentos para construir software: programación, diseño básico, pruebas, depuración, control de versiones y buenas prácticas de desarrollo.',
  'graphics and interactive techniques': 'Área sobre visualización, gráficos por computador, interacción visual, realidad virtual/aumentada, animación y representación de objetos o escenas.',
  'software engineering': 'Disciplina que organiza el desarrollo de software como proceso: requisitos, arquitectura, diseño, pruebas, mantenimiento, calidad, gestión y evolución de sistemas.',
  'architecture and organization': 'Estudia cómo se estructuran los computadores y sus componentes: procesadores, memoria, instrucciones, rendimiento y organización interna.',
  'security': 'Área dedicada a proteger sistemas, datos y comunicaciones frente a accesos no autorizados, ataques, vulnerabilidades y riesgos.',
  'mathematical and statistical foundations': 'Base matemática y estadística de la computación: probabilidad, inferencia, optimización, álgebra, modelos y análisis cuantitativo.',
  'foundations of programming languages': 'Estudia el diseño, la semántica y la implementación de los lenguajes de programación: tipos, compiladores, intérpretes y paradigmas.',
  'systems fundamentals': 'Principios comunes a los sistemas computacionales: rendimiento, confiabilidad, paralelismo, virtualización y evaluación de sistemas.',
  'it does not belong to the computer science field': 'La publicación fue clasificada como fuera del campo principal de computación. Puede estar relacionada con otra disciplina, aunque use herramientas computacionales.',

  'systems physiology': 'Área biomédica que estudia cómo funcionan sistemas del cuerpo humano o animal, integrando señales, órganos, regulación y respuestas fisiológicas.',
  'neural engineering': 'Área que combina ingeniería, neurociencia y tecnología para estudiar, medir, modelar o intervenir el sistema nervioso.',
  'medical imaging': 'Área dedicada a adquisición, procesamiento y análisis de imágenes médicas, como resonancia magnética, tomografía, ultrasonido o imágenes radiológicas.',
  'clinical engineering': 'Área orientada a tecnología médica en entornos clínicos: equipamiento, seguridad, gestión tecnológica, mantenimiento y soporte a procesos hospitalarios.',
  'rehabilitation engineering': 'Desarrollo de tecnologías para apoyar recuperación funcional, movilidad, prótesis, órtesis, terapias y asistencia a personas con discapacidad.',
  'bioinformatics': 'Uso de computación, estadística e inteligencia artificial para analizar datos biológicos, como secuencias genómicas, proteínas, expresión génica o evolución.',
  'bioinstrumentation': 'Diseño y uso de instrumentos para medir señales o variables biológicas, fisiológicas o clínicas.',
  'genetic engineering': 'Área enfocada en modificación, edición o análisis aplicado de material genético con fines biomédicos, biotecnológicos o experimentales.',
  'cellular and tissue engineering': 'Área que diseña, cultiva o modifica células y tejidos para estudiar, reparar o reemplazar funciones biológicas.',
  'biomechanics': 'Estudia fuerzas, movimiento y comportamiento mecánico de tejidos, órganos o del cuerpo completo.',
  'bionics': 'Integra biología e ingeniería para crear sistemas artificiales que imitan, reemplazan o mejoran funciones biológicas.',
  'biomedical electronics': 'Diseño de circuitos, sensores y sistemas electrónicos usados en medición, diagnóstico, monitoreo o intervención biomédica.',
  'biofluid': 'Estudia el comportamiento de fluidos biológicos, como sangre, aire en vías respiratorias u otros flujos relevantes para sistemas vivos.',
  'biomaterials': 'Materiales diseñados para interactuar con sistemas biológicos: implantes, andamios, recubrimientos y dispositivos compatibles con el cuerpo.',
  'biomechatronics': 'Integra mecánica, electrónica y control con el cuerpo humano: exoesqueletos, prótesis activas y sistemas de asistencia al movimiento.',
  'orthopaedic bioengineering': 'Aplica la ingeniería al sistema musculoesquelético: implantes, fijaciones, huesos, articulaciones y su comportamiento mecánico.',
  'it does not belong to the bioengineering field': 'La publicación fue clasificada como fuera del campo principal de bioingeniería o ingeniería biomédica.',
  'it does not belong to bioengineering field': 'La publicación fue clasificada como fuera del campo principal de bioingeniería o ingeniería biomédica.'
};
const BIOMED_AREA_KEYS = new Set([
  'systems physiology', 'neural engineering', 'medical imaging', 'clinical engineering',
  'rehabilitation engineering', 'bioinformatics', 'bioinstrumentation', 'genetic engineering',
  'cellular and tissue engineering', 'biomechanics', 'bionics', 'biomedical electronics',
  'biofluid', 'biomaterials', 'biomechatronics', 'orthopaedic bioengineering',
  'it does not belong to the bioengineering field', 'it does not belong to bioengineering field'
]);
/* Nombres en español y portugués de las áreas, para poder preguntar "define seguridad" */
const AREA_ALIAS = {
  'inteligencia artificial': 'artificial intelligence', 'inteligencia artificial generativa': 'artificial intelligence',
  'algoritmos y complejidad': 'algorithms and complexity', 'algoritmos': 'algorithms and complexity', 'complejidad': 'algorithms and complexity',
  'computacion paralela y distribuida': 'parallel and distributed computing', 'computacion paralela': 'parallel and distributed computing', 'sistemas distribuidos': 'parallel and distributed computing',
  'redes y comunicacion': 'networking and communication', 'redes': 'networking and communication', 'redes de computadores': 'networking and communication',
  'desarrollo de plataformas especializadas': 'specialized platform development', 'plataformas especializadas': 'specialized platform development',
  'interaccion humano computador': 'human-computer interaction', 'interaccion humano-computador': 'human-computer interaction', 'hci': 'human-computer interaction',
  'sistemas operativos': 'operating systems',
  'sociedad etica y profesionalismo': 'society, ethics and professionalism', 'etica': 'society, ethics and professionalism', 'sociedad': 'society, ethics and professionalism',
  'gestion de datos': 'data management', 'bases de datos': 'data management',
  'fundamentos de desarrollo de software': 'software development fundamentals', 'desarrollo de software': 'software development fundamentals',
  'graficos y tecnicas interactivas': 'graphics and interactive techniques', 'graficos': 'graphics and interactive techniques', 'visualizacion': 'graphics and interactive techniques',
  'ingenieria de software': 'software engineering', 'engenharia de software': 'software engineering',
  'arquitectura y organizacion': 'architecture and organization', 'arquitectura de computadores': 'architecture and organization',
  'seguridad': 'security', 'seguranca': 'security', 'ciberseguridad': 'security',
  'fundamentos matematicos y estadisticos': 'mathematical and statistical foundations', 'matematicas': 'mathematical and statistical foundations', 'estadistica': 'mathematical and statistical foundations',
  'lenguajes de programacion': 'foundations of programming languages', 'fundamentos de sistemas': 'systems fundamentals',
  'fisiologia de sistemas': 'systems physiology', 'fisiologia': 'systems physiology',
  'ingenieria neural': 'neural engineering', 'neuroingenieria': 'neural engineering',
  'imagenes medicas': 'medical imaging', 'imagenologia': 'medical imaging',
  'ingenieria clinica': 'clinical engineering', 'ingenieria de rehabilitacion': 'rehabilitation engineering', 'rehabilitacion': 'rehabilitation engineering',
  'bioinformatica': 'bioinformatics', 'bioinstrumentacion': 'bioinstrumentation', 'ingenieria genetica': 'genetic engineering',
  'ingenieria celular y de tejidos': 'cellular and tissue engineering', 'ingenieria de tejidos': 'cellular and tissue engineering',
  'biomecanica': 'biomechanics', 'bionica': 'bionics', 'electronica biomedica': 'biomedical electronics', 'biofluidos': 'biofluid',
  'biomateriales': 'biomaterials', 'biomecatronica': 'biomechatronics', 'bioingenieria ortopedica': 'orthopaedic bioengineering'
};

/* Equivalencias ES/EN/PT propias de este módulo (se suman a las del motor) */
const CHAT_BILINGUAL_TERMS = {
  'student engagement': ['compromiso estudiantil', 'participacion estudiantil', 'engajamento estudantil'],
  'compromiso estudiantil': ['student engagement'],
  'fuera del area': ['does not belong'],
  'fuera del campo': ['does not belong'],
  'no pertenece': ['does not belong'],
  'sin clasificacion': ['sin clasificacion', 'does not belong']
};

/* Países: nombre canónico del mapa de la app más nombres en español y portugués */
const CHAT_PAISES_ALIAS = {
  'estados unidos': 'United States', 'eeuu': 'United States', 'ee uu': 'United States', 'usa': 'United States', 'norteamerica': 'United States',
  'reino unido': 'United Kingdom', 'inglaterra': 'United Kingdom', 'escocia': 'United Kingdom', 'uk': 'United Kingdom', 'gran bretana': 'United Kingdom',
  'espana': 'Spain', 'espanha': 'Spain', 'brasil': 'Brazil', 'alemania': 'Germany', 'alemanha': 'Germany', 'francia': 'France', 'franca': 'France',
  'italia': 'Italy', 'mexico': 'Mexico', 'peru': 'Peru', 'canada': 'Canada', 'suiza': 'Switzerland', 'suica': 'Switzerland', 'suecia': 'Sweden',
  'japon': 'Japan', 'japao': 'Japan', 'belgica': 'Belgium', 'paises bajos': 'Netherlands', 'holanda': 'Netherlands', 'irlanda': 'Ireland',
  'polonia': 'Poland', 'grecia': 'Greece', 'noruega': 'Norway', 'dinamarca': 'Denmark', 'finlandia': 'Finland', 'nueva zelanda': 'New Zealand',
  'nova zelandia': 'New Zealand', 'sudafrica': 'South Africa', 'africa do sul': 'South Africa', 'corea del sur': 'South Korea', 'corea': 'South Korea',
  'coreia do sul': 'South Korea', 'rusia': 'Russia', 'russia': 'Russia', 'turquia': 'Turkey', 'egipto': 'Egypt', 'egito': 'Egypt', 'marruecos': 'Morocco',
  'marrocos': 'Morocco', 'arabia saudita': 'Saudi Arabia', 'singapur': 'Singapore', 'singapura': 'Singapore', 'hong kong': 'Hong Kong SAR China',
  'republica checa': 'Czech Republic', 'chequia': 'Czech Republic', 'hungria': 'Hungary', 'iran': 'Iran', 'pakistan': 'Pakistan', 'malasia': 'Malaysia',
  'tailandia': 'Thailand', 'vietnam': 'Vietnam', 'filipinas': 'Philippines', 'emiratos arabes unidos': 'United Arab Emirates', 'croacia': 'Croatia',
  'eslovenia': 'Slovenia', 'rumania': 'Romania', 'ucrania': 'Ukraine', 'luxemburgo': 'Luxembourg', 'lituania': 'Lithuania', 'letonia': 'Latvia',
  'republica dominicana': 'Dominican Republic', 'puerto rico': 'United States', 'escandinavia': 'Sweden', 'taiwan': 'Taiwan', 'china': 'China',
  'india': 'India', 'australia': 'Australia', 'austria': 'Austria', 'portugal': 'Portugal', 'argentina': 'Argentina', 'colombia': 'Colombia',
  'ecuador': 'Ecuador', 'uruguay': 'Uruguay', 'chile': 'Chile', 'cuba': 'Cuba', 'panama': 'Panama', 'paraguay': 'Paraguay', 'bolivia': 'Bolivia',
  'venezuela': 'Venezuela', 'costa rica': 'Costa Rica', 'israel': 'Israel', 'nigeria': 'Nigeria', 'kenia': 'Kenya', 'etiopia': 'Ethiopia',
  'argelia': 'Algeria', 'tunez': 'Tunisia', 'libano': 'Lebanon', 'jordania': 'Jordan', 'catar': 'Qatar', 'indonesia': 'Indonesia',
  'bangladesh': 'Bangladesh', 'nepal': 'Nepal', 'sri lanka': 'Sri Lanka', 'kazajistan': 'Kazakhstan', 'estonia': 'Estonia', 'islandia': 'Iceland',
  'eslovaquia': 'Slovakia', 'serbia': 'Serbia', 'bulgaria': 'Bulgaria', 'chipre': 'Cyprus', 'malta': 'Malta'
};
let CHAT_PAISES = null;
function chatPaises() {
  if (CHAT_PAISES) return CHAT_PAISES;
  const n = Asistente.norm;
  const lista = [];
  Object.keys(window.COUNTRY_COORDS || {}).forEach(k => lista.push([n(k), k === 'USA' ? 'United States' : k]));
  Object.keys(window.COUNTRY_ALIAS || {}).forEach(k => lista.push([n(k), k]));
  Object.entries(CHAT_PAISES_ALIAS).forEach(([a, c]) => lista.push([n(a), c]));
  CHAT_PAISES = lista.filter(([a]) => a.length > 2);
  return CHAT_PAISES;
}

function chatNorm(s) { return Asistente.norm(s); }
function chatEsc(s) { return Asistente.esc(s); }
function chatRows() { return byIndex(base(), S.chatIndex || 'Todas'); }
function uniquePubs(rows) {
  const map = new Map();
  rows.forEach(r => {
    const k = llave(r);
    if (!map.has(k)) map.set(k, Object.assign({}, r, { _autoresUnidad: new Set(), _idsUnidad: new Set() }));
    const o = map.get(k);
    if (r.NOMBRE_AUTOR) o._autoresUnidad.add(r.NOMBRE_AUTOR);
    if (r.SCOPUS_ID) o._idsUnidad.add(r.SCOPUS_ID);
    if (int0(r.CITADO_POR) > int0(o.CITADO_POR)) o.CITADO_POR = r.CITADO_POR;
  });
  return [...map.values()];
}
/* Texto normalizado de cada fila, calculado una sola vez */
const CHAT_TEXTO = new WeakMap();
function chatTexto(r) {
  let p = CHAT_TEXTO.get(r);
  if (p) return p;
  const n = chatNorm;
  const vals = HEADERS && HEADERS.length ? HEADERS.map(h => r[h]) : Object.values(r || {});
  p = {
    titulo: n(r.TITULO),
    claves: n([r.AUTOR_PALABRAS_CLAVES, r.INDEX_PALABRAS_CLAVES].join(' ; ')),
    resumen: n(r.RESUMEN),
    areas: n([r.AREA_COMPUTACION, r.CATEGORIAS, r.AREAS, r.FUENTE, r.AREA_OCDE, r.DISCIPLINA_OCDE, r.SUBDISCIPLINA_OCDE, r.NOMBRE_ODS_ANID].join(' ; ')),
    todo: n(vals.join(' ; '))
  };
  CHAT_TEXTO.set(r, p);
  return p;
}
function chatPaisesDe(r) {
  return String(r.PAISES_AUTORES || '').split(/[;,]/).map(x => x.trim()).filter(Boolean).map(x => x === 'USA' ? 'United States' : x);
}
function chatPersonas() {
  return uniq(DATA.filter(r => r.UNIVERSIDAD === S.uni && r.SESION === S.sec).map(r => r.NOMBRE_AUTOR).filter(Boolean));
}
function chatOrden(a, b) { return int0(b.ANO) - int0(a.ANO) || int0(b.CITADO_POR) - int0(a.CITADO_POR); }
const nombreCorto = s => titleCase(s).replace(/\.([a-záéíóúñü])/g, (m, c) => '.' + c.toUpperCase());
function pct(n, t) { return t ? Math.round(n * 100 / t) + '%' : '0%'; }
function fmtK(n) { return Number(n || 0).toLocaleString(S.lang === 'en' ? 'en-GB' : S.lang === 'pt' ? 'pt-BR' : 'es-CL'); }

function cleanAreaName(s) { return String(s || '').replace(/^\(\d+\)\s*/, '').replace(/[.;:]+$/g, '').trim(); }
function areaKey(s) { return chatNorm(cleanAreaName(s)); }
function areaDefinitionFor(s) { return AREA_DEFINITIONS[areaKey(s)] || null; }
function areaDisplayName(s) {
  const clean = cleanAreaName(s);
  const k = areaKey(clean);
  if (k.startsWith('it does not belong')) return k.includes('computer') ? 'Fuera del campo de computación' : 'Fuera del campo de bioingeniería';
  return titleCase(clean);
}
function areaKind(s) { return BIOMED_AREA_KEYS.has(areaKey(s)) ? 'Biomédica' : 'ACM / Computación'; }

function chatKpis(rows) {
  const pubs = uniquePubs(rows);
  const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const topArea = sortEnt(countBy(rows.map(r => stripParen(r.AREA_COMPUTACION).trim()).filter(Boolean)))[0] || ['-', 0];
  return { pubs, total: pubs.length, authors: uniq(rows.map(r => r.NOMBRE_AUTOR)).length, cites, topArea };
}

/* ---------- piezas de respuesta ---------- */
function pubListHTML(rows, limit) {
  const all = uniquePubs(rows);
  const cap = Math.min(limit || all.length, 60);
  const pubs = all.slice(0, cap);
  if (!pubs.length) return `<div class="chat-empty">${chatEsc(cu().noPubs)}</div>`;
  const rest = all.length - pubs.length;
  return `<div class="chat-pubs">${pubs.map(r => {
    const link = paperLink(r);
    const q = String(r.QUARTILE || '').toUpperCase();
    const badge = /^Q[1-4]$/.test(q) ? `<span class="q-badge q-${q.toLowerCase()}">${q}</span>` : '';
    const autores = r._autoresUnidad && r._autoresUnidad.size ? [...r._autoresUnidad].map(titleCase).join(', ') : titleCase(r.NOMBRE_AUTOR || '');
    return `<article class="chat-pub">
      <div class="chat-pub-title">${link ? `<a href="${chatEsc(link)}" target="_blank" rel="noopener">${chatEsc(r.TITULO || '-')}</a>` : chatEsc(r.TITULO || '-')}</div>
      <div class="chat-pub-meta">${chatEsc(r.ANO || '')} · ${chatEsc(r.FUENTE || '')}</div>
      <div class="chat-pub-tags">
        ${badge}<span>${chatEsc(tr(PROC_ETIQUETA[procedencia(r)]))}</span><span>${int0(r.CITADO_POR)} ${chatEsc(cu().cites)}</span><span>${chatEsc(autores)}</span>
      </div>
    </article>`;
  }).join('')}${rest > 0 ? `<div class="chat-more">${chatEsc(cu().more.replace('{n}', fmtK(rest)))}</div>` : ''}</div>`;
}

function miniBars(title, pairs) {
  if (!pairs.length) return '';
  const max = Math.max(...pairs.map(p => p[1])) || 1;
  return `<div class="chat-bars"><b>${chatEsc(title)}</b>${pairs.map(([k, v]) =>
    `<div class="chat-bar"><span class="chat-bar-l">${chatEsc(k)}</span><span class="chat-bar-track"><i style="width:${Math.max(6, v / max * 100)}%"></i></span><span class="chat-bar-v">${fmtK(v)}</span></div>`
  ).join('')}</div>`;
}
function kpiPills(items) {
  return `<div class="chat-context chat-metrics">${items.filter(Boolean).map(([v, l, wide]) => `<div class="chat-kpi${wide ? ' wide' : ''}"><b>${chatEsc(v)}</b><span>${chatEsc(l)}</span></div>`).join('')}</div>`;
}

function answerHelp(rows) {
  const k = chatKpis(rows); const u = cu();
  return `<p>${u.greet1.replace('{n}', fmtK(k.total))}</p><p>${u.greet2}</p>`;
}

function answerAreaDefinitions(rows, q) {
  const nq = chatNorm(q);
  if (/\b(citad\w*|cuant\w*|how many|quant\w*|por ano|by year|per year|top|ranking|quien|quienes|who|quem|compara\w*|compare|coautor\w*|coauthor\w*|cited|list\w*|muestra\w*|lista\w*)\b/.test(nq)) return null;
  const all = sortEnt(countBy(rows.map(r => r.AREA_COMPUTACION).filter(Boolean))).map(([area, n]) => ({ area, n, def: areaDefinitionFor(area), kind: areaKind(area) }));
  const glossary = Object.keys(AREA_DEFINITIONS).map(area => ({ area, n: 0, def: AREA_DEFINITIONS[area], kind: areaKind(area) }));
  const mencionada = k => nq.includes(k) || k.split(/\s+/).some(w => w.length > 5 && new RegExp('\\b' + w).test(nq));
  const aliasHit = Object.keys(AREA_ALIAS).filter(a => new RegExp('\\b' + a + '\\b').test(nq)).sort((a, b) => b.length - a.length)[0];
  const quiere = x => mencionada(areaKey(x.area)) || (aliasHit && areaKey(x.area) === AREA_ALIAS[aliasHit]);
  const biomed = /biomed|bioingenier|biomedical|bioengineering/.test(nq);
  const acm = /\bacm\b|computacion|computer science|computacao/.test(nq);

  let selected = all.filter(x => x.def && quiere(x));
  if (!selected.length && biomed) selected = (all.some(x => x.kind === 'Biomédica' && x.def) ? all : glossary).filter(x => x.def && x.kind === 'Biomédica');
  if (!selected.length && acm) selected = (all.some(x => x.kind === 'ACM / Computación' && x.def) ? all : glossary).filter(x => x.def && x.kind === 'ACM / Computación');
  if (!selected.length) selected = glossary.filter(quiere);
  if (!selected.length) return null;   /* no es una pregunta del glosario: el motor sigue con otra intención */

  selected = selected.slice(0, 18);
  const fromFilter = selected.some(x => x.n > 0);
  return `<p>${fromFilter ? 'Definiciones breves de las áreas que aparecen en el filtro activo:' : 'Definiciones generales del glosario local:'}</p>
    <div class="area-defs">${selected.map(x => `
      <div class="area-def">
        <div class="area-def-head"><b>${chatEsc(areaDisplayName(x.area))}</b><span>${x.kind}${x.n ? ` · ${fmtK(x.n)} ${chatEsc(cu().records)}` : ''}</span></div>
        <p>${chatEsc(x.def)}</p>
      </div>`).join('')}</div>`;
}

function answerTopics(rows) {
  const u = cu();
  const areas = kwFold(rows, 'AREA_COMPUTACION', 'title').slice(0, 8);
  const appTop = kwFold(rows, 'AREAS', 'title').filter(([k]) => k.toLowerCase() !== 'computer science').slice(0, 8);
  const kwTop = kwFold(rows, 'INDEX_PALABRAS_CLAVES', 'title').slice(0, 10);
  return miniBars(u.specialties, areas) + miniBars(u.applications, appTop) + miniBars(u.keywords, kwTop);
}

function answerRanking(rows, c, limit) {
  const u = cu();
  const porAutor = new Map();
  rows.forEach(r => { if (!porAutor.has(r.NOMBRE_AUTOR)) porAutor.set(r.NOMBRE_AUTOR, []); porAutor.get(r.NOMBRE_AUTOR).push(r); });
  const stats = [...porAutor.entries()].map(([a, rs]) => { const p = uniquePubs(rs); return [titleCase(a), p.length, p.reduce((s, r) => s + int0(r.CITADO_POR), 0)]; });
  const pubs = stats.sort((x, y) => y[1] - x[1] || y[2] - x[2]).slice(0, limit).map(([a, n]) => [a, n]);
  const cites = [...stats].sort((x, y) => y[2] - x[2]).slice(0, Math.min(limit, 8)).map(([a, , ci]) => [a, ci]);
  return miniBars(u.byAuthor, pubs) + miniBars(u.citesByAuthor, cites);
}

function answerTopCited(rows, limit) {
  const pubs = uniquePubs(rows).sort((a, b) => int0(b.CITADO_POR) - int0(a.CITADO_POR));
  return pubListHTML(pubs, limit);
}

function answerCoauthors(rows, author) {
  const u = cu();
  const idsUnidad = new Set(DATA.map(r => String(r.SCOPUS_ID || '').trim()).filter(Boolean));
  if (author) {
    const da = rows.filter(r => r.NOMBRE_AUTOR === author);
    const me = new Set(da.map(r => String(r.SCOPUS_ID || '').trim()).filter(Boolean));
    const co = new Map();
    uniquePubs(da).forEach(r => pairAuthors(r).forEach(p => {
      if (!p.id || me.has(p.id)) return;
      const name = p.name || p.id;
      co.set(name, (co.get(name) || 0) + 1);
    }));
    const ranked = sortEnt(co).slice(0, 15).map(([a, n]) => [nombreCorto(a), n]);
    if (!ranked.length) return `<p>${chatEsc(u.noCoauth)} <b>${chatEsc(titleCase(author))}</b>.</p>`;
    return `<p>${chatEsc(u.coauth)} <b>${chatEsc(titleCase(author))}</b>:</p>${miniBars(u.coauthTitle, ranked)}`;
  }
  /* sin persona: coautoría general del conjunto */
  const pubs = uniquePubs(rows);
  const ext = new Map(); const pares = new Map();
  pubs.forEach(r => {
    pairAuthors(r).forEach(p => { if (p.id && !idsUnidad.has(p.id)) ext.set(p.name || p.id, (ext.get(p.name || p.id) || 0) + 1); });
    const au = [...(r._autoresUnidad || [])].sort();
    for (let i = 0; i < au.length; i++) for (let j = i + 1; j < au.length; j++) { const k = titleCase(au[i]) + ' + ' + titleCase(au[j]); pares.set(k, (pares.get(k) || 0) + 1); }
  });
  return miniBars(u.coauthInt, sortEnt(pares).slice(0, 10)) + miniBars(u.coauthExt, sortEnt(ext).slice(0, 12).map(([a, n]) => [nombreCorto(a), n]));
}

function answerCompare(rows, a, b) {
  const u = cu();
  const cards = [a, b].map(x => {
    const da = rows.filter(r => r.NOMBRE_AUTOR === x);
    const pubs = uniquePubs(da);
    const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
    const q1 = pubs.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
    const years = da.map(r => int0(r.ANO)).filter(y => y > 1900);
    const span = years.length ? `${Math.min(...years)}–${Math.max(...years)}` : '-';
    const topArea = sortEnt(countBy(da.map(r => titleCase(stripParen(r.AREA_COMPUTACION).trim())).filter(Boolean)))[0] || ['-', 0];
    return `<div class="chat-compare-card">
      <h4>${chatEsc(titleCase(x))}</h4>
      <div><b>${fmtK(pubs.length)}</b><span>${chatEsc(u.unique)}</span></div>
      <div><b>${fmtK(cites)}</b><span>${chatEsc(u.cites)}</span></div>
      <div><b>${fmtK(hIndex(pubs.map(r => int0(r.CITADO_POR))))}</b><span>${chatEsc(u.hIndex)}</span></div>
      <div><b>${fmtK(q1)}</b><span>Q1</span></div>
      <div><b>${span}</b><span>${chatEsc(u.period)}</span></div>
      <p>${chatEsc(u.topArea)}: <b>${chatEsc(topArea[0])}</b> (${fmtK(topArea[1])} ${chatEsc(u.records)}).</p>
    </div>`;
  }).join('');
  return `<p>${chatEsc(u.compare)}:</p><div class="chat-compare">${cards}</div>`;
}

function answerEvolution(rows) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const porAnio = new Map(), citas = new Map();
  pubs.forEach(r => { const y = int0(r.ANO); if (!y) return; porAnio.set(y, (porAnio.get(y) || 0) + 1); citas.set(y, (citas.get(y) || 0) + int0(r.CITADO_POR)); });
  const anios = [...porAnio.keys()].sort((a, b) => a - b);
  return miniBars(u.byYear, anios.map(y => [String(y), porAnio.get(y)])) + miniBars(u.citesByYear, anios.map(y => [String(y), citas.get(y)]));
}

function answerSources(rows, limit) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const m = new Map();
  pubs.forEach(r => { const f = String(r.FUENTE || '').trim(); if (f) m.set(f, (m.get(f) || 0) + 1); });
  return miniBars(u.sources, sortEnt(m).slice(0, limit).map(([k, v]) => [titleCase(k), v]));
}

function answerCountries(rows, limit) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const m = new Map(); let intl = 0;
  pubs.forEach(r => { const ps = uniq(chatPaisesDe(r)); if (ps.some(p => p !== 'Chile')) intl++; ps.forEach(p => { if (p !== 'Chile') m.set(p, (m.get(p) || 0) + 1); }); });
  if (!m.size) return `<p>${chatEsc(u.noCountries)}</p>`;
  return `<p><b>${fmtK(intl)}</b> ${chatEsc(u.pubs)} (${pct(intl, pubs.length)}) ${chatEsc(u.intl)}.</p>` + miniBars(u.countries, sortEnt(m).slice(0, limit));
}

function answerQuartiles(rows) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const m = countBy(pubs.map(r => { const q = String(r.QUARTILE || '').toUpperCase(); return /^Q[1-4]$/.test(q) ? q : u.unranked; }));
  const orden = ['Q1', 'Q2', 'Q3', 'Q4'];
  const pairs = [...m.entries()].sort((a, b) => (orden.indexOf(a[0]) + 1 || 9) - (orden.indexOf(b[0]) + 1 || 9));
  return miniBars(u.quartiles, pairs.map(([k, v]) => [k + ' (' + pct(v, pubs.length) + ')', v]));
}

function answerMetrics(rows, c) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const q1 = pubs.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
  const years = pubs.map(r => int0(r.ANO)).filter(y => y > 1900);
  const w = pubs.filter(tieneWos).length, s = pubs.filter(tieneScopus).length;
  const art = pubs.filter(r => r.TIPO_DOCUMENTO === 'Article').length, conf = pubs.filter(r => r.TIPO_DOCUMENTO === 'Conference paper').length;
  const items = [
    [fmtK(cites), u.cites],
    [pubs.length ? (cites / pubs.length).toFixed(1) : '0', u.perPub],
    [fmtK(hIndex(pubs.map(r => int0(r.CITADO_POR)))), u.hIndex],
    [fmtK(q1) + ' (' + pct(q1, pubs.length) + ')', u.q1],
    [years.length ? Math.min(...years) + '–' + Math.max(...years) : '-', u.years],
    c.personas.length !== 1 ? [fmtK(uniq(rows.map(r => r.NOMBRE_AUTOR)).length), u.authors] : null,
    [fmtK(art) + ' / ' + fmtK(conf), u.journal + ' / ' + u.conf],
    [pct(w, pubs.length) + ' / ' + pct(s, pubs.length), u.wos + ' / ' + u.scopus]
  ];
  return kpiPills(items);
}

function answerShortSummary(rows, c) {
  const u = cu();
  const pubs = uniquePubs(rows);
  const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const q1 = pubs.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
  const years = pubs.map(r => int0(r.ANO)).filter(y => y > 1900);
  const parts = [fmtK(cites) + ' ' + u.cites, fmtK(q1) + ' Q1', years.length ? Math.min(...years) + '–' + Math.max(...years) : ''];
  if (c.personas.length !== 1) parts.push(fmtK(uniq(rows.map(r => r.NOMBRE_AUTOR)).length) + ' ' + u.authors);
  return `<p class="chat-note">${parts.filter(Boolean).map(chatEsc).join(' · ')}</p>` + pubListHTML(pubs.sort(chatOrden), 5);
}

function answerSuggestions() {
  const u = cu();
  return `<p class="chat-note">${chatEsc(u.tryAlso)}: ${u.suggest.map(s => `<b>${chatEsc(s)}</b>`).join(' · ')}.</p>`;
}

/* ---------- el motor configurado para publicaciones ---------- */
function chatEngine() {
  if (ChatLocal.engine) return ChatLocal.engine;
  ChatLocal.engine = Asistente.crear({
    modulo: 'publicaciones',
    lang: () => S.lang,
    filas: chatRows,
    personas: chatPersonas,
    nombre: titleCase,
    dePersona: (r, name) => r.NOMBRE_AUTOR === name,
    clave: llave,
    anio: r => int0(r.ANO),
    cuartil: r => String(r.QUARTILE || '').toUpperCase(),
    wos: tieneWos,
    scopus: tieneScopus,
    tipo: r => { const t = String(r.TIPO_DOCUMENTO || '').trim(); return t === 'Article' ? 'revista' : t === 'Conference paper' ? 'actas' : 'otro'; },
    paises: chatPaises,
    paisesDe: chatPaisesDe,
    texto: chatTexto,
    orden: chatOrden,
    unico: uniquePubs,
    sinonimos: CHAT_BILINGUAL_TERMS,
    ayuda: () => answerHelp(chatRows()),
    definir: q => answerAreaDefinitions(chatRows(), q),
    comparar: answerCompare,
    coautores: answerCoauthors,
    lista: (rows, limit) => pubListHTML(rows, limit),
    listaTop: answerTopCited,
    ranking: answerRanking,
    temas: answerTopics,
    evolucion: answerEvolution,
    fuentes: answerSources,
    paisesResumen: answerCountries,
    cuartiles: answerQuartiles,
    metricas: answerMetrics,
    resumenCorto: answerShortSummary,
    sugerencias: answerSuggestions
  });
  return ChatLocal.engine;
}

function localAnswer(q) {
  try { return chatEngine().responder(q); }
  catch (e) { console.error('asistente', e); return `<p>${chatEsc(cu().noPubs)}</p>`; }
}

function addChatMessage(role, html) {
  const box = document.getElementById('chat_messages');
  if (!box) return;
  const div = document.createElement('div');
  div.className = `chat-msg ${role}`;
  div.innerHTML = role === 'user' ? `<div class="chat-bubble">${chatEsc(html)}</div>` : `<div class="chat-bubble">${html}</div>`;
  box.appendChild(div);
  box.scrollTop = box.scrollHeight;
}

function renderChatContext() {
  const el = document.getElementById('chat_context');
  if (!el) return;
  const k = chatKpis(chatRows()); const u = cu();
  el.innerHTML = `
    <div class="chat-kpi"><b>${fmtK(k.total)}</b><span>${chatEsc(u.unique)}</span></div>
    <div class="chat-kpi"><b>${fmtK(k.authors)}</b><span>${chatEsc(u.authors)}</span></div>
    <div class="chat-kpi"><b>${fmtK(k.cites)}</b><span>${chatEsc(u.cites)}</span></div>
    <div class="chat-kpi wide"><b>${chatEsc(k.topArea[0])}</b><span>${chatEsc(u.topArea.toLowerCase())} (${fmtK(k.topArea[1])})</span></div>`;
}

/* ============================================================
   EFECTO DE ESCRITURA PROGRESIVA (tipo GPT)
   Inserta el HTML completo (estructura intacta) y revela el texto
   carácter por carácter. Tras un tope de caracteres, muestra el
   resto de golpe (para listas largas de artículos).
   ============================================================ */
function chatTypeInto(el, html, done) {
  el.innerHTML = html;
  const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
  const nodes = [];
  let tn;
  while ((tn = walker.nextNode())) {
    if (!tn.nodeValue || !tn.nodeValue.trim()) continue;
    nodes.push({ node: tn, full: tn.nodeValue });
    tn.nodeValue = '';
  }
  const box = document.getElementById('chat_messages');
  let ni = 0, ci = 0, typed = 0;
  const CAP = 480;            // luego de esto, revela el resto instantáneo
  const revealRest = () => {
    for (let k = ni; k < nodes.length; k++) nodes[k].node.nodeValue = nodes[k].full;
    if (box) box.scrollTop = box.scrollHeight;
    if (done) done();
  };
  const step = () => {
    if (ni >= nodes.length) { if (done) done(); return; }
    if (typed >= CAP) { revealRest(); return; }
    const cur = nodes[ni];
    cur.node.nodeValue = cur.full.slice(0, ci + 1);
    ci++; typed++;
    if (ci >= cur.full.length) { ni++; ci = 0; }
    if (box) box.scrollTop = box.scrollHeight;
    setTimeout(step, 11);
  };
  step();
}

/* ============================================================ */
function buildChat(keepMessages) {
  const box = document.getElementById('chat_messages');
  const input = document.getElementById('chat_input');
  const form = document.getElementById('chat_form');
  const prompts = document.getElementById('chat_prompts');
  const clear = document.getElementById('chat_clear');
  if (!box || !input || !form || !prompts) return;

  renderChatContext();
  const quick = CHAT_PROMPTS[S.lang] || CHAT_PROMPTS.es;
  prompts.innerHTML = quick.map(p => `<button type="button" class="prompt-chip" data-q="${chatEsc(p)}">${chatEsc(p)}</button>`).join('');
  prompts.querySelectorAll('button').forEach(b => b.onclick = () => {
    input.value = b.dataset.q;
    form.requestSubmit();
  });

  if (!ChatLocal.wired) {
    form.onsubmit = e => {
      e.preventDefault();
      const q = input.value.trim();
      if (!q) return;
      addChatMessage('user', q);
      input.value = '';
      ChatLocal.asked = true;
      const box = document.getElementById('chat_messages');
      const pending = document.createElement('div');
      pending.className = 'chat-msg bot';
      pending.innerHTML = '<div class="chat-bubble"><span class="chat-typing"><i></i><i></i><i></i></span></div>';
      box.appendChild(pending); box.scrollTop = box.scrollHeight;
      const html = localAnswer(q);
      setTimeout(() => {
        const bubble = pending.querySelector('.chat-bubble');
        chatTypeInto(bubble, html, () => { box.scrollTop = box.scrollHeight; });
      }, 320);
    };
    ChatLocal.wired = true;
  }
  if (clear && !clear.dataset.wired) {
    clear.onclick = () => {
      box.innerHTML = '';
      ChatLocal.asked = false;
      addChatMessage('bot', answerHelp(chatRows()));
      input.focus();
    };
    clear.dataset.wired = '1';
  }
  if (!keepMessages || !ChatLocal.asked) {
    box.innerHTML = '';
    addChatMessage('bot', answerHelp(chatRows()));
    ChatLocal.asked = false;
  }
}
