/* ============================================================
   ASISTENTE BIBLIOMÉTRICO LOCAL
   Chat sin API: responde con reglas y búsquedas sobre el CSV activo.
   ============================================================ */

const ChatLocal = { wired: false, asked: false };

const CHAT_PROMPTS = {
  es: [
    '¿Cuáles son las publicaciones más citadas?',
    'Muéstrame todas las publicaciones sobre inteligencia artificial',
    'Publicaciones Q1 desde 2020',
    '¿Quiénes son los autores más productivos?',
    '¿Cuáles son los temas principales?',
    'Coautores de Manuel Villalobos',
    '¿Qué significan las áreas ACM?',
    'Define las áreas biomédicas'
  ],
  en: [
    'Which are the most cited publications?',
    'Show me all publications about artificial intelligence',
    'Q1 publications since 2020',
    'Who are the most productive authors?',
    'What are the main research topics?',
    'Coauthors of Manuel Villalobos',
    'What do ACM areas mean?',
    'Define biomedical areas'
  ],
  pt: [
    'Quais são as publicações mais citadas?',
    'Mostre todas as publicações sobre inteligência artificial',
    'Publicações Q1 desde 2020',
    'Quem são os autores mais produtivos?',
    'Quais são os principais temas?',
    'Coautores de Manuel Villalobos',
    'O que significam as áreas ACM?',
    'Defina as áreas biomédicas'
  ]
};

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
  'it does not belong to the bioengineering field': 'La publicación fue clasificada como fuera del campo principal de bioingeniería o ingeniería biomédica.',
  'it does not belong to bioengineering field': 'La publicación fue clasificada como fuera del campo principal de bioingeniería o ingeniería biomédica.'
};

const AREA_DEFINITION_RE = /\b(define|definir|definiciones?|definicion(?:es)?|definición(?:es)?|descripciones?|descripcion(?:es)?|descripción(?:es)?|describe|significa|significan|que es|qué es|decicion(?:es)?|decisión(?:es)?|area acm|areas acm|áreas acm|biomedica|biomédica|biomedicas|biomédicas|bioingenier)\b/;
const BIOMED_AREA_KEYS = new Set([
  'systems physiology', 'neural engineering', 'medical imaging', 'clinical engineering',
  'rehabilitation engineering', 'bioinformatics', 'bioinstrumentation', 'genetic engineering',
  'cellular and tissue engineering', 'biomechanics', 'bionics', 'biomedical electronics',
  'biofluid', 'it does not belong to the bioengineering field',
  'it does not belong to bioengineering field'
]);

const CHAT_BILINGUAL_TERMS = {
  'ia': ['artificial intelligence', 'inteligencia artificial', 'ai'],
  'ai': ['artificial intelligence', 'inteligencia artificial', 'ia'],
  'inteligencia artificial': ['artificial intelligence', 'ai'],
  'artificial intelligence': ['inteligencia artificial', 'ia'],
  'aprendizaje automatico': ['machine learning', 'ml'],
  'aprendizaje automático': ['machine learning', 'ml'],
  'machine learning': ['aprendizaje automatico', 'aprendizaje automático', 'ml'],
  'aprendizaje profundo': ['deep learning', 'neural networks', 'redes neuronales'],
  'deep learning': ['aprendizaje profundo', 'redes neuronales', 'neural networks'],
  'redes neuronales': ['neural networks', 'deep learning'],
  'neural networks': ['redes neuronales', 'aprendizaje profundo'],
  'procesamiento de lenguaje natural': ['natural language processing', 'nlp'],
  'procesamiento del lenguaje natural': ['natural language processing', 'nlp'],
  'natural language processing': ['procesamiento de lenguaje natural', 'procesamiento del lenguaje natural', 'nlp'],
  'nlp': ['natural language processing', 'procesamiento de lenguaje natural'],
  'mineria de datos': ['data mining'],
  'minería de datos': ['data mining'],
  'data mining': ['mineria de datos', 'minería de datos'],
  'ciencia de datos': ['data science'],
  'data science': ['ciencia de datos'],
  'analitica de datos': ['data analytics', 'analytics'],
  'analítica de datos': ['data analytics', 'analytics'],
  'data analytics': ['analitica de datos', 'analítica de datos'],
  'vision computacional': ['computer vision'],
  'visión computacional': ['computer vision'],
  'computer vision': ['vision computacional', 'visión computacional'],
  'interaccion humano computador': ['human-computer interaction', 'hci'],
  'interacción humano computador': ['human-computer interaction', 'hci'],
  'human-computer interaction': ['interaccion humano computador', 'interacción humano computador', 'hci'],
  'hci': ['human-computer interaction', 'interaccion humano computador'],
  'ingenieria de software': ['software engineering'],
  'ingeniería de software': ['software engineering'],
  'software engineering': ['ingenieria de software', 'ingeniería de software'],
  'educacion': ['education'],
  'educación': ['education'],
  'education': ['educacion', 'educación'],
  'estudiantes': ['students', 'student'],
  'students': ['estudiantes', 'student'],
  'student engagement': ['compromiso estudiantil', 'participacion estudiantil', 'participación estudiantil'],
  'compromiso estudiantil': ['student engagement'],
  'participacion estudiantil': ['student engagement'],
  'participación estudiantil': ['student engagement'],
  'engajamento estudantil': ['student engagement', 'compromiso estudiantil'],
  'salud': ['health'],
  'health': ['salud'],
  'biomedica': ['biomedical', 'biomédica'],
  'biomédica': ['biomedical', 'biomedica'],
  'biomedical': ['biomedica', 'biomédica'],
  'imagenes medicas': ['medical imaging'],
  'imágenes médicas': ['medical imaging'],
  'medical imaging': ['imagenes medicas', 'imágenes médicas'],
  'bioinformatica': ['bioinformatics'],
  'bioinformática': ['bioinformatics'],
  'bioinformatics': ['bioinformatica', 'bioinformática']
};

function chatNorm(s) {
  return String(s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
}
function chatEsc(s) {
  return String(s ?? '').replace(/[&<>"']/g, m => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
}
function chatRows() {
  return byIndex(base(), S.chatIndex || 'Todas');
}
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
function chatLimit(q, fallback = 10) {
  const m = chatNorm(q).match(/\b(\d{1,2})\b/);
  return m ? Math.max(1, Math.min(30, parseInt(m[1], 10))) : fallback;
}
function chatYearFilter(rows, q) {
  const s = chatNorm(q);
  const years = [...s.matchAll(/\b(19|20)\d{2}\b/g)].map(m => parseInt(m[0], 10));
  if (s.includes('desde') && years.length) return rows.filter(r => int0(r.ANO) >= years[0]);
  if ((s.includes('hasta') || s.includes('antes')) && years.length) return rows.filter(r => int0(r.ANO) <= years[0]);
  if (years.length >= 2) return rows.filter(r => int0(r.ANO) >= Math.min(...years) && int0(r.ANO) <= Math.max(...years));
  if (years.length === 1) return rows.filter(r => int0(r.ANO) === years[0]);
  return rows;
}
const CHAT_AUTHOR_STOP = new Set([
  'publicacion', 'publicaciones', 'paper', 'papers', 'articulo', 'articulos',
  'coautor', 'coautores', 'coautoria', 'coautorias', 'autor', 'autores',
  'academico', 'academica', 'academicos', 'academicas', 'profesor', 'profesora',
  'busca', 'buscar', 'buscame', 'muestra', 'mostrar', 'lista', 'listar',
  'dame', 'sobre', 'con', 'del', 'de', 'la', 'el', 'los', 'las', 'para',
  'top', 'citas', 'citadas', 'q1', 'wos', 'scopus', 'desde', 'hasta',
  'compara', 'comparar', 'comparacion', 'versus'
]);
function chatNameTokens(q) {
  return chatNorm(q)
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(t => t.length > 2 && !CHAT_AUTHOR_STOP.has(t));
}
function chatAuthorCandidates(q, rows) {
  const nq = chatNorm(q);
  const qTokens = uniq(chatNameTokens(q));
  if (!qTokens.length) return [];
  const authors = uniq(rows.map(r => r.NOMBRE_AUTOR).filter(Boolean));
  return authors.map(name => {
    const na = chatNorm(name);
    const aTokens = na.split(/\s+/).filter(Boolean);
    let score = 0;
    if (nq.includes(na)) score += 130;
    qTokens.forEach(t => {
      if (aTokens.includes(t)) {
        score += 28;
        if (aTokens[0] === t) score += 52;
        if (aTokens[aTokens.length - 1] === t) score += 28;
      } else if (aTokens.some(a => a.startsWith(t) || t.startsWith(a))) {
        score += 16;
      }
    });
    for (let i = 0; i < qTokens.length - 1; i++) {
      const pair = `${qTokens[i]} ${qTokens[i + 1]}`;
      if (na.includes(pair) || nq.includes(pair)) score += 24;
    }
    const exactMatches = qTokens.filter(t => aTokens.includes(t)).length;
    return { name, score, exactMatches };
  }).filter(x => x.score > 0)
    .sort((a, b) => b.score - a.score || b.exactMatches - a.exactMatches || a.name.localeCompare(b.name));
}
function chatFindAuthors(q, rows) {
  const c = chatAuthorCandidates(q, rows);
  if (!c.length) return [];
  const qTokens = uniq(chatNameTokens(q));
  const top = c[0].score;
  if (qTokens.length === 1) {
    const strong = c.filter(x => x.score >= Math.max(70, top - 8));
    if (strong.length) return strong.map(x => x.name).slice(0, 4);
    return c.length === 1 ? [c[0].name] : c.filter(x => x.score === top).map(x => x.name).slice(0, 4);
  }
  return c.filter(x => x.score >= 55).map(x => x.name).slice(0, 4);
}
function answerAuthorAmbiguity(authors) {
  return `<p>Encontré más de un académico(a) compatible con ese nombre. Para evitar mezclar publicaciones, escribe el nombre más completo:</p>
    <div class="chat-pubs">${authors.slice(0, 6).map(a => `<article class="chat-pub"><div class="chat-pub-title">${chatEsc(titleCase(a))}</div></article>`).join('')}</div>`;
}
function chatText(r) {
  const vals = HEADERS && HEADERS.length ? HEADERS.map(h => r[h]) : Object.values(r || {});
  return chatNorm(vals.join(' '));
}
function chatSearchParts(r) {
  const vals = HEADERS && HEADERS.length ? HEADERS.map(h => r[h]) : Object.values(r || {});
  return {
    title: chatNorm(r.TITULO),
    abstract: chatNorm(r.RESUMEN),
    keywords: chatNorm([r.AUTOR_PALABRAS_CLAVES, r.INDEX_PALABRAS_CLAVES].join(' ')),
    areas: chatNorm([r.AREA_COMPUTACION, r.CATEGORIAS, r.AREAS, r.FUENTE].join(' ')),
    all: chatNorm(vals.join(' '))
  };
}
function cleanAreaName(s) {
  return String(s || '').replace(/^\(\d+\)\s*/, '').replace(/[.;:]+$/g, '').trim();
}
function areaKey(s) {
  return chatNorm(cleanAreaName(s));
}
function areaDefinitionFor(s) {
  return AREA_DEFINITIONS[areaKey(s)] || null;
}
function areaDisplayName(s) {
  const clean = cleanAreaName(s);
  if (areaKey(clean).startsWith('it does not belong')) return 'Fuera del campo de bioingeniería';
  return titleCase(clean);
}
function areaKind(s) {
  const k = areaKey(s);
  if (BIOMED_AREA_KEYS.has(k)) return 'Biomédica';
  return 'ACM / Computación';
}
function chatExtractSearch(q) {
  let s = chatNorm(q);
  s = s.replace(/\b(publicaciones?|papers?|articulos?|artículos?|publications?|articles?|sobre|about|de|do|da|dos|das|del|la|el|los|las|the|a|an|in|em|any|qualquer|en|con|with|que|qué|dame|muestra|show|busca|buscar|buscame|búscame|search|procura|procurar|lista|listar|list|top|mas|más|most|citadas?|cited|q1|wos|scopus|desde|since|hasta|until|entre|between|anos|años|years?|keyword|keywords|key words|palavra chave|palavras chave|palabra clave|palabras clave|termino|término|term|campo|campos|field|fields|base|database|bd|csv|subarea|subárea|subareas|subáreas|subsubarea|subsubárea|subsubareas|subsubáreas)\b/g, ' ');
  s = s.replace(/\b(19|20)\d{2}\b/g, ' ').replace(/\d+/g, ' ').replace(/\s+/g, ' ').trim();
  const alias = { ia: 'inteligencia artificial', ai: 'artificial intelligence', ml: 'machine learning' };
  return alias[s] || s;
}
function chatSearchTerms(q) {
  const term = chatExtractSearch(q);
  const terms = new Set();
  const add = v => {
    const n = chatNorm(v);
    if (n && n.length > 1) terms.add(n);
  };
  add(term);
  Object.entries(CHAT_BILINGUAL_TERMS).forEach(([key, vals]) => {
    const nk = chatNorm(key);
    if (term === nk || term.includes(nk) || chatNorm(q).includes(nk)) {
      add(key);
      vals.forEach(add);
    }
  });
  return [...terms];
}
function chatKpis(rows) {
  const pubs = uniquePubs(rows);
  const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const topArea = sortEnt(countBy(rows.map(r => stripParen(r.AREA_COMPUTACION).trim()).filter(Boolean)))[0] || ['-', 0];
  return { pubs, total: pubs.length, authors: uniq(rows.map(r => r.NOMBRE_AUTOR)).length, cites, topArea };
}

function pubListHTML(rows, limit) {
  const all = uniquePubs(rows);
  const pubs = (limit && limit < all.length) ? all.slice(0, limit) : all;
  if (!pubs.length) return '<div class="chat-empty">No encontré publicaciones para esa consulta.</div>';
  return `<div class="chat-pubs">${pubs.map(r => {
    const link = paperLink(r);
    const q = String(r.QUARTILE || '').toUpperCase();
    const badge = /^Q[1-4]$/.test(q) ? `<span class="q-badge q-${q.toLowerCase()}">${q}</span>` : '';
    const autores = r._autoresUnidad && r._autoresUnidad.size ? [...r._autoresUnidad].map(titleCase).join(', ') : titleCase(r.NOMBRE_AUTOR || '');
    return `<article class="chat-pub">
      <div class="chat-pub-title">${link ? `<a href="${chatEsc(link)}" target="_blank" rel="noopener">${chatEsc(r.TITULO || '-')}</a>` : chatEsc(r.TITULO || '-')}</div>
      <div class="chat-pub-meta">${chatEsc(r.ANO || '')} · ${chatEsc(r.FUENTE || '')}</div>
      <div class="chat-pub-tags">
        ${badge}<span>${chatEsc(r.WOS === 'SI' ? 'WoS' : 'Scopus')}</span><span>${int0(r.CITADO_POR)} citas</span><span>${chatEsc(autores)}</span>
      </div>
    </article>`;
  }).join('')}</div>`;
}

function answerHelp(rows) {
  const k = chatKpis(rows);
  return `<p>Puedo ayudarte a explorar <b>${k.total}</b> publicaciones únicas del filtro activo.</p>
    <p>Prueba preguntas como: <b>top citadas</b>, <b>publicaciones Q1</b>, <b>coautores de un autor</b>, <b>autores más productivos</b>, <b>temas principales</b> o <b>publicaciones sobre IA desde 2020</b>.</p>`;
}

function answerTopics(rows) {
  const areas = kwFold(rows, 'AREA_COMPUTACION', 'title').slice(0, 8);
  const appTop = kwFold(rows, 'AREAS', 'title').filter(([k]) => k.toLowerCase() !== 'computer science').slice(0, 8);
  const kwTop = kwFold(rows, 'INDEX_PALABRAS_CLAVES', 'title').slice(0, 10);
  return `<p>Los temas dominantes del filtro activo se concentran en estas líneas:</p>
    ${miniBars('Especialidades', areas)}
    ${miniBars('Aplicaciones', appTop)}
    ${miniBars('Palabras clave', kwTop)}`;
}

function answerAreaDefinitions(rows, q) {
  const nq = chatNorm(q);
  const all = sortEnt(countBy(rows.map(r => r.AREA_COMPUTACION).filter(Boolean))).map(([area, n]) => ({ area, n, def: areaDefinitionFor(area), kind: areaKind(area) }));
  const glossary = Object.keys(AREA_DEFINITIONS).map(area => ({ area, n: 0, def: AREA_DEFINITIONS[area], kind: areaKind(area) }));
  let selected = all.filter(x => x.def);

  const specific = selected.filter(x => {
    const k = areaKey(x.area);
    return nq.includes(k) || k.split(/\s+/).some(w => w.length > 5 && nq.includes(w));
  });
  if (specific.length) selected = specific;
  else if (nq.includes('biomed') || nq.includes('bioingenier') || nq.includes('biomedical')) selected = selected.filter(x => x.kind === 'Biomédica');
  else if (nq.includes('acm') || nq.includes('computacion') || nq.includes('computación') || nq.includes('computer science')) selected = selected.filter(x => x.kind === 'ACM / Computación');

  if (!selected.length && (nq.includes('biomed') || nq.includes('bioingenier') || nq.includes('biomedical'))) {
    selected = glossary.filter(x => x.kind === 'Biomédica');
  } else if (!selected.length && (nq.includes('acm') || nq.includes('computacion') || nq.includes('computación') || nq.includes('computer science'))) {
    selected = glossary.filter(x => x.kind === 'ACM / Computación');
  } else if (!selected.length) {
    selected = glossary.filter(x => {
      const k = areaKey(x.area);
      return nq.includes(k) || k.split(/\s+/).some(w => w.length > 5 && nq.includes(w));
    });
  }

  selected = selected.slice(0, 14);
  if (!selected.length) return '<p>No encontré esa área en el glosario local. Prueba con “define Artificial Intelligence”, “qué significan las áreas ACM” o “áreas biomédicas”.</p>';
  const fromFilter = selected.some(x => x.n > 0);
  return `<p>${fromFilter ? 'Estas son definiciones breves de las áreas que aparecen en el filtro activo:' : 'Estas son definiciones generales del glosario local:'}</p>
    <div class="area-defs">${selected.map(x => `
      <div class="area-def">
        <div class="area-def-head"><b>${chatEsc(areaDisplayName(x.area))}</b><span>${x.kind}${x.n ? ` · ${x.n} registros` : ''}</span></div>
        <p>${chatEsc(x.def)}</p>
      </div>`).join('')}</div>`;
}

function miniBars(title, pairs) {
  if (!pairs.length) return '';
  const max = pairs[0][1] || 1;
  return `<div class="chat-mini"><div class="chat-mini-title">${title}</div>${pairs.map(([k, v]) =>
    `<div class="chat-mini-row"><span>${chatEsc(k)}</span><b>${v}</b><i style="width:${Math.max(8, v / max * 100)}%"></i></div>`
  ).join('')}</div>`;
}

function answerTopCited(rows, q) {
  const nq = chatNorm(q);
  const all = /\b(todas|todos|all|completa|completo)\b/.test(nq);
  const lim = all ? Infinity : chatLimit(q, 10);
  const pubs = uniquePubs(chatYearFilter(rows, q)).sort((a, b) => int0(b.CITADO_POR) - int0(a.CITADO_POR)).slice(0, lim);
  return `<p>${all ? 'Publicaciones ordenadas por citas' : 'Estas son las <b>'+pubs.length+'</b> publicaciones más citadas'} del filtro consultado.</p>${pubListHTML(pubs)}`;
}

function answerQ1(rows, q) {
  const pubs = chatYearFilter(rows, q).filter(r => String(r.QUARTILE).toUpperCase() === 'Q1')
    .sort((a, b) => int0(b.ANO) - int0(a.ANO) || int0(b.CITADO_POR) - int0(a.CITADO_POR));
  return `<p>Encontré <b>${uniquePubs(pubs).length}</b> publicaciones Q1 en el filtro consultado.</p>${pubListHTML(pubs)}`;
}

function answerAuthors(rows) {
  const ranked = sortEnt(countBy(rows.map(r => r.NOMBRE_AUTOR).filter(Boolean))).slice(0, 12);
  return `<p>Ranking por registros de autor-publicación dentro del filtro activo:</p>${miniBars('Académicos(as)', ranked.map(([a, n]) => [titleCase(a), n]))}`;
}

function answerAuthor(rows, author, q) {
  const da = chatYearFilter(rows.filter(r => r.NOMBRE_AUTOR === author), q);
  const pubs = uniquePubs(da);
  const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const q1 = uniquePubs(da.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1')).length;
  const all = [...pubs].sort((a, b) => int0(b.CITADO_POR) - int0(a.CITADO_POR));
  return `<p><b>${titleCase(author)}</b> registra <b>${pubs.length}</b> publicaciones únicas, <b>${cites}</b> citas y <b>${q1}</b> publicaciones Q1 en el filtro consultado.</p>${pubListHTML(all)}`;
}

function answerCoauthors(rows, author) {
  const da = rows.filter(r => r.NOMBRE_AUTOR === author);
  const me = String((da[0] || {}).SCOPUS_ID || '').trim();
  const co = new Map();
  da.forEach(r => pairAuthors(r).forEach(p => {
    if (!p.id || p.id === me) return;
    const name = p.name || p.id;
    co.set(name, (co.get(name) || 0) + 1);
  }));
  const ranked = sortEnt(co).slice(0, 15).map(([a, n]) => [titleCase(a), n]);
  if (!ranked.length) return `<p>No encontré coautorías registradas para <b>${titleCase(author)}</b> en el filtro activo.</p>`;
  return `<p>Principales coautores(as) de <b>${titleCase(author)}</b>:</p>${miniBars('Coautorías', ranked)}`;
}

function answerCompare(rows, authors) {
  const cards = authors.slice(0, 2).map(a => {
    const da = rows.filter(r => r.NOMBRE_AUTOR === a);
    const pubs = uniquePubs(da);
    const cites = pubs.reduce((s, r) => s + int0(r.CITADO_POR), 0);
    const q1 = uniquePubs(da.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1')).length;
    const years = da.map(r => int0(r.ANO)).filter(y => y > 1900);
    const span = years.length ? `${Math.min(...years)}-${Math.max(...years)}` : '-';
    const topArea = sortEnt(countBy(da.map(r => titleCase(stripParen(r.AREA_COMPUTACION).trim())).filter(Boolean)))[0] || ['-', 0];
    return `<div class="chat-compare-card">
      <h4>${titleCase(a)}</h4>
      <div><b>${pubs.length}</b><span>publicaciones únicas</span></div>
      <div><b>${cites}</b><span>citas</span></div>
      <div><b>${q1}</b><span>Q1</span></div>
      <div><b>${span}</b><span>periodo</span></div>
      <p>Especialidad frecuente: <b>${chatEsc(topArea[0])}</b> (${topArea[1]} registros).</p>
    </div>`;
  }).join('');
  return `<p>Comparación dentro del filtro activo:</p><div class="chat-compare">${cards}</div>`;
}

function answerNotBelong(rows, q) {
  const lim = chatLimit(q, 15);
  const hits = rows.filter(r => {
    const t = chatNorm([r.AREA_COMPUTACION, r.CATEGORIAS, r.AREAS].join(' '));
    return t.includes('does not belong') || t.includes('no pertenece') || t.includes('sin clasificacion');
  }).sort((a, b) => int0(b.ANO) - int0(a.ANO));
  return `<p>Encontré <b>${uniquePubs(hits).length}</b> publicaciones clasificadas como fuera del área, sin clasificación o equivalentes.</p>${pubListHTML(hits)}`;
}

function answerSearch(rows, q) {
  const terms = chatSearchTerms(q);
  const term = terms[0] || '';
  if (!term) return answerHelp(rows);
  const toks = terms.flatMap(t => t.split(/\s+/)).filter(t => t.length > 2);
  const uniqToks = uniq(toks);
  const fieldHits = { keywords: 0, title: 0, abstract: 0, areas: 0, all: 0 };
  const scored = chatYearFilter(rows, q).map(r => {
    const p = chatSearchParts(r);
    let score = 0;
    terms.forEach(t => {
      if (p.keywords.includes(t)) { score += 8; fieldHits.keywords++; }
      if (p.title.includes(t)) { score += 5; fieldHits.title++; }
      if (p.abstract.includes(t)) { score += 3; fieldHits.abstract++; }
      if (p.areas.includes(t)) { score += 2; fieldHits.areas++; }
      if (p.all.includes(t)) { score += 1; fieldHits.all++; }
    });
    score += uniqToks.reduce((s, t) => s + (p.keywords.includes(t) ? 3 : 0) + (p.title.includes(t) ? 2 : 0) + (p.all.includes(t) ? 1 : 0), 0);
    return { r, score };
  }).filter(x => x.score > 0).sort((a, b) => b.score - a.score || int0(b.r.CITADO_POR) - int0(a.r.CITADO_POR)).map(x => x.r);
  const n = uniquePubs(scored).length;
  const labels = {
    es: { keywords:'palabras clave', title:'título', abstract:'resumen', areas:'áreas/subáreas', all:'otros campos', tried:'También probé equivalentes', searched:'Busqué', inWord:'en', allFields:'todos los campos de la BD', fields:'Campos con coincidencias', found:'Encontré', pubs:'publicaciones únicas' },
    en: { keywords:'keywords', title:'title', abstract:'abstract', areas:'areas/subareas', all:'other fields', tried:'I also tried equivalents', searched:'I searched for', inWord:'in', allFields:'all database fields', fields:'Fields with matches', found:'Found', pubs:'unique publications' },
    pt: { keywords:'palavras-chave', title:'título', abstract:'resumo', areas:'áreas/subáreas', all:'outros campos', tried:'Também testei equivalentes', searched:'Busquei', inWord:'em', allFields:'todos os campos da base', fields:'Campos com correspondências', found:'Encontrei', pubs:'publicações únicas' }
  }[S.lang] || {};
  const hitList = Object.entries(fieldHits)
    .filter(([,v]) => v > 0)
    .sort((a,b) => b[1] - a[1])
    .slice(0, 5)
    .map(([k,v]) => `${labels[k] || k} (${v})`)
    .join(', ');
  const extra = terms.length > 1 ? ` <span class="chat-note">${labels.tried}: ${terms.slice(1, 5).map(chatEsc).join(', ')}.</span>` : '';
  const where = hitList ? `<br><span class="chat-note"><b>${labels.fields}:</b> ${chatEsc(hitList)}.</span>` : '';
  return `<p>${labels.searched} <b>${chatEsc(term)}</b> ${labels.inWord} <b>${labels.allFields}</b>.${extra} ${labels.found} <b>${n}</b> ${labels.pubs}.${where}</p>${pubListHTML(scored)}`;
}

function localAnswer(q) {
  let rows = chatRows();
  const nq = chatNorm(q);
  if (!rows.length && AREA_DEFINITION_RE.test(nq)) return answerAreaDefinitions([], q);
  if (!rows.length) return '<p>No hay datos para el filtro activo.</p>';
  if (!nq || /\b(ayuda|hola|que puedes|qué puedes|como funciona|cómo funciona)\b/.test(nq)) return answerHelp(rows);
  if (nq.includes('wos') || nq.includes('web of science')) rows = rows.filter(r => r.WOS === 'SI');
  if (nq.includes('scopus')) rows = rows.filter(r => r.WOS === 'NO');

  const authors = chatFindAuthors(q, rows);
  const searchIntent = /\b(busca|buscar|buscame|búscame|search|procura|procurar|muestra|lista|listar|publicaciones? sobre|papers? sobre|articulos? sobre|artículos? sobre|keyword|keywords|palabra clave|palabras clave|termino|término|campo|campos|field|fields|base|bd|csv|subarea|subárea|subsubarea|subsubárea)\b/.test(nq);
  const compareIntent = /\b(compara|comparar|comparacion|comparación|versus| vs )\b/.test(nq);
  if (AREA_DEFINITION_RE.test(nq)) return answerAreaDefinitions(rows, q);
  if (compareIntent && authors.length >= 2) return answerCompare(rows, authors);
  if (!compareIntent && authors.length > 1) return answerAuthorAmbiguity(authors);
  if (nq.includes('coautor') && authors.length) return answerCoauthors(rows, authors[0]);
  if (nq.includes('no pertenece') || nq.includes('fuera del area') || nq.includes('fuera del área') || nq.includes('does not belong')) return answerNotBelong(rows, q);
  if (searchIntent && !authors.length) return answerSearch(rows, q);
  if (/\b(tema|temas|lineas|líneas|area|área|areas|áreas|palabras clave|resume|resumen)\b/.test(nq)) return answerTopics(rows);
  if (/\b(top|mas citad|más citad|citas|citadas)\b/.test(nq)) return answerTopCited(rows, q);
  if (/\b(q1|quartil 1|cuartil 1)\b/.test(nq)) return answerQ1(rows, q);
  if (/\b(autores|academicos|académicos|productivos|productivas|ranking)\b/.test(nq) && !authors.length) return answerAuthors(rows);
  if (authors.length) return answerAuthor(rows, authors[0], q);
  return answerSearch(rows, q);
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
  const k = chatKpis(chatRows());
  el.innerHTML = `
    <div class="chat-kpi"><b>${k.total}</b><span>publicaciones únicas</span></div>
    <div class="chat-kpi"><b>${k.authors}</b><span>académicos(as)</span></div>
    <div class="chat-kpi"><b>${k.cites.toLocaleString('es')}</b><span>citas acumuladas</span></div>
    <div class="chat-kpi wide"><b>${chatEsc(k.topArea[0])}</b><span>especialidad más frecuente (${k.topArea[1]})</span></div>`;
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
