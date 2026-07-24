/* ============================================================
   ANALIZADOR BIBLIOMÉTRICO v15 — núcleo
   ============================================================ */

const C = {
  emerald: '#00A499', emerald2: '#007A72', emeraldSoft: '#CFEDEA',
  amber: '#EA7600', amberSoft: '#F8D4A8', rust: '#394049',
  ink: '#21262B', muted: '#5C636B', line: '#DBE2E8', paper: '#ffffff', gris: '#394049'
};
const CAT = ['#00A499', '#EA7600', '#394049', '#55B9B0', '#F2A65A', '#6E777F', '#9BD3CE', '#F8D4A8', '#8C969D', '#007A72'];
const PFONT = { family: 'Inter, sans-serif', color: C.ink, size: 12 };
const PCFG = { responsive: true, displaylogo: false, locale: 'es',
  modeBarButtonsToRemove: ['lasso2d', 'select2d', 'autoScale2d'] };
const PLAYOUT = { plot_bgcolor: 'rgba(0,0,0,0)', paper_bgcolor: 'rgba(0,0,0,0)', font: PFONT };

const DT_LANG = {
  es: {
    emptyTable: 'Sin datos', info: '_START_–_END_ de _TOTAL_', infoEmpty: '0 registros',
    infoFiltered: '(de _MAX_)', lengthMenu: 'Ver _MENU_', loadingRecords: 'Cargando…',
    processing: 'Procesando…', search: '', searchPlaceholder: 'Buscar…', zeroRecords: 'Sin resultados',
    paginate: { first: '«', last: '»', next: '›', previous: '‹' }
  },
  en: {
    emptyTable: 'No data', info: '_START_–_END_ of _TOTAL_', infoEmpty: '0 records',
    infoFiltered: '(from _MAX_)', lengthMenu: 'Show _MENU_', loadingRecords: 'Loading…',
    processing: 'Processing…', search: '', searchPlaceholder: 'Search…', zeroRecords: 'No results',
    paginate: { first: '«', last: '»', next: '›', previous: '‹' }
  },
  pt: {
    emptyTable: 'Sem dados', info: '_START_–_END_ de _TOTAL_', infoEmpty: '0 registros',
    infoFiltered: '(de _MAX_)', lengthMenu: 'Ver _MENU_', loadingRecords: 'Carregando…',
    processing: 'Processando…', search: '', searchPlaceholder: 'Buscar…', zeroRecords: 'Sem resultados',
    paginate: { first: '«', last: '»', next: '›', previous: '‹' }
  }
};
function dtLang(){ return DT_LANG[S.lang] || DT_LANG.es; }

let DATA = [], HEADERS = [];
let S = {
  uni: null, sec: null, yMin: null, yMax: null, tab: 'resumen',
  indNivel: 'Institucionales', indIndex: 'Todas',
  perfSel: 'Institucionales', perfAutor: null, perfIndex: 'Todas',
  domDoc: 'Todos', domDom: 'Áreas de especialidad', domPalabra: null,
  chatIndex: 'Todas',
  lang: (() => { try { return localStorage.getItem('biblio_lang') || 'es'; } catch(e) { return 'es'; } })()
};
let _map = null, _mapLayer = null, _net = null;

const I18N = {
  es: {
    'brand.kicker': 'Universidad de Santiago de Chile',
    'assist.ind': '<b>Institucional</b> resume la unidad completa. <b>Por académico(a)</b> calcula rendimiento y colaboración por persona, siempre dentro de la afiliación seleccionada.',
    'assist.perfil': 'En <b>Por autor(a)</b>, las publicaciones del perfil corresponden al autor seleccionado solo cuando aparecen asociadas a la universidad y unidad filtradas.',
    'assist.dominio': 'Selecciona el dominio y luego un término; el gráfico muestra qué autores lo usan y en qué años aparece.',
    'note.acmFramework': 'En Informática, las especialidades se leen como áreas ACM/IEEE/AAAI. Para otras carreras, se deben usar áreas propias de la disciplina.',
    'brand.title': 'Analizador Bibliométrico',
    'brand.sub': 'Producción científica indexada · Web of Science & Scopus',
    'filter.university': 'Universidad',
    'filter.unit': 'Unidad académica',
    'filter.period': 'Periodo de publicación',
    'filter.indexing': 'Indexación',
    'tab.summary': 'Resumen',
    'tab.indicators': 'Indicadores',
    'tab.profiles': 'Perfiles',
    'tab.analytics': 'Analítica',
    'tab.domain': 'Dominio',
    'tab.assistant': 'Asistente',
    'chat.kicker': 'Chat local',
    'chat.title': 'Asistente bibliométrico',
    'chat.desc': 'Consulta la base filtrada sin API, sin servidor y sin costo. Las respuestas se calculan en tu navegador.',
    'chat.localNote': 'Modo local: no usa Gemini ni ChatGPT. Trabaja sólo con el CSV cargado por la app y respeta universidad, unidad, periodo y afiliación efectiva.',
    'chat.advisor': 'Asesor Leo USACH',
    'chat.advisorDesc': 'Consulta publicaciones, áreas, autores y cualquier campo de la base.',
    'chat.clear': 'Limpiar chat',
    'chat.quick': 'Preguntas rápidas',
    'chat.placeholder': 'Pregunta por autores, Q1, coautores, citas, temas, keywords o cualquier campo...',
    'chat.send': 'Enviar',
    'report.html': 'Reporte HTML',
    'control.institutional': 'Institucional',
    'control.byAcademic': 'Por académico(a)',
    'control.byAuthor': 'Por autor(a)',
    'control.academic': 'Académico(a)',
    'control.all': 'Todas',
    'network.focus': 'Enfocar',
    'network.reset': 'Ver red completa',
    'domain.docType': 'Tipo de documento',
    'domain.domain': 'Dominio',
    'domain.specialty': 'Áreas de especialidad',
    'domain.application': 'Áreas de aplicación',
    'domain.subareas': 'Subáreas de aplicación',
    'domain.ocde': 'Áreas OCDE',
    'domain.ocdeSub': 'Subáreas OCDE',
    'domain.ods': 'Áreas ODS (ANID)',
    'domain.keywords': 'Palabras claves',
    'domain.term': 'Término'
  },
  en: {
    'brand.kicker': 'Universidad de Santiago de Chile',
    'assist.ind': '<b>Institutional</b> summarizes the whole unit. <b>By academic</b> computes performance and collaboration per person, always within the selected affiliation.',
    'assist.perfil': 'In <b>By author</b>, the profile\'s publications correspond to the selected author only when they appear associated with the filtered university and unit.',
    'assist.dominio': 'Select the domain and then a term; the chart shows which authors use it and in which years it appears.',
    'note.acmFramework': 'In Computer Science, specialties are read as ACM/IEEE/AAAI areas. For other disciplines, field-specific areas should be used.',
    'brand.title': 'Bibliometric Analyzer',
    'brand.sub': 'Indexed scientific output · Web of Science & Scopus',
    'filter.university': 'University',
    'filter.unit': 'Academic unit',
    'filter.period': 'Publication period',
    'filter.indexing': 'Indexing',
    'tab.summary': 'Summary',
    'tab.indicators': 'Indicators',
    'tab.profiles': 'Profiles',
    'tab.analytics': 'Analytics',
    'tab.domain': 'Domain',
    'tab.assistant': 'Assistant',
    'chat.kicker': 'Local chat',
    'chat.title': 'Bibliometric assistant',
    'chat.desc': 'Query the filtered database without an API, server, or cost. Answers are computed in your browser.',
    'chat.localNote': 'Local mode: it does not use Gemini or ChatGPT. It works only with the CSV loaded by the app and respects the active filters.',
    'chat.advisor': 'Leo USACH Advisor',
    'chat.advisorDesc': 'Ask about publications, areas, authors, and any database field.',
    'chat.clear': 'Clear chat',
    'chat.quick': 'Quick questions',
    'chat.placeholder': 'Ask about authors, Q1, coauthors, citations, topics, keywords, or any field...',
    'chat.send': 'Send',
    'report.html': 'HTML report',
    'control.institutional': 'Institutional',
    'control.byAcademic': 'By academic',
    'control.byAuthor': 'By author',
    'control.academic': 'Academic',
    'control.all': 'All',
    'network.focus': 'Focus',
    'network.reset': 'Full network',
    'domain.docType': 'Document type',
    'domain.domain': 'Domain',
    'domain.specialty': 'Specialty areas',
    'domain.application': 'Application areas',
    'domain.subareas': 'Application subareas',
    'domain.ocde': 'OECD areas',
    'domain.ocdeSub': 'OECD subareas',
    'domain.ods': 'SDG areas (ANID)',
    'domain.keywords': 'Keywords',
    'domain.term': 'Term'
  },
  pt: {
    'brand.kicker': 'Universidad de Santiago de Chile',
    'assist.ind': '<b>Institucional</b> resume a unidade completa. <b>Por acadêmico(a)</b> calcula desempenho e colaboração por pessoa, sempre dentro da afiliação selecionada.',
    'assist.perfil': 'Em <b>Por autor(a)</b>, as publicações do perfil correspondem ao autor selecionado apenas quando aparecem associadas à universidade e unidade filtradas.',
    'assist.dominio': 'Selecione o domínio e depois um termo; o gráfico mostra quais autores o usam e em que anos aparece.',
    'note.acmFramework': 'Em Computação, as especialidades são lidas como áreas ACM/IEEE/AAAI. Para outros cursos, devem ser usadas áreas próprias da disciplina.',
    'brand.title': 'Analisador Bibliométrico',
    'brand.sub': 'Produção científica indexada · Web of Science & Scopus',
    'filter.university': 'Universidade',
    'filter.unit': 'Unidade acadêmica',
    'filter.period': 'Período de publicação',
    'filter.indexing': 'Indexação',
    'tab.summary': 'Resumo',
    'tab.indicators': 'Indicadores',
    'tab.profiles': 'Perfis',
    'tab.analytics': 'Analítica',
    'tab.domain': 'Domínio',
    'tab.assistant': 'Assistente',
    'chat.kicker': 'Chat local',
    'chat.title': 'Assistente bibliométrico',
    'chat.desc': 'Consulte a base filtrada sem API, sem servidor e sem custo. As respostas são calculadas no navegador.',
    'chat.localNote': 'Modo local: não usa Gemini nem ChatGPT. Trabalha apenas com o CSV carregado pela app e respeita os filtros ativos.',
    'chat.advisor': 'Assessor Leo USACH',
    'chat.advisorDesc': 'Consulte publicações, áreas, autores e qualquer campo da base.',
    'chat.clear': 'Limpar chat',
    'chat.quick': 'Perguntas rápidas',
    'chat.placeholder': 'Pergunte por autores, Q1, coautores, citações, temas, keywords ou qualquer campo...',
    'chat.send': 'Enviar',
    'report.html': 'Relatório HTML',
    'control.institutional': 'Institucional',
    'control.byAcademic': 'Por acadêmico(a)',
    'control.byAuthor': 'Por autor(a)',
    'control.academic': 'Acadêmico(a)',
    'control.all': 'Todas',
    'network.focus': 'Focar',
    'network.reset': 'Ver rede completa',
    'domain.docType': 'Tipo de documento',
    'domain.domain': 'Domínio',
    'domain.specialty': 'Áreas de especialidade',
    'domain.application': 'Áreas de aplicação',
    'domain.subareas': 'Subáreas de aplicação',
    'domain.ocde': 'Áreas OCDE',
    'domain.ocdeSub': 'Subáreas OCDE',
    'domain.ods': 'Áreas ODS (ANID)',
    'domain.keywords': 'Palavras-chave',
    'domain.term': 'Termo'
  }
};
function tr(key) {
  const lang = I18N[S.lang] ? S.lang : 'es';
  return (I18N[lang] && I18N[lang][key]) || I18N.es[key] || key;
}
function applyLanguage() {
  const lang = I18N[S.lang] ? S.lang : 'es';
  S.lang = lang;
  document.documentElement.lang = lang;
  document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = tr(el.dataset.i18n); });
  document.querySelectorAll('[data-i18n-html]').forEach(el => { el.innerHTML = tr(el.dataset.i18nHtml); });
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => { el.placeholder = tr(el.dataset.i18nPlaceholder); });
  document.querySelectorAll('#lang_switch button').forEach(b => b.classList.toggle('on', b.dataset.lang === lang));
  if (typeof i18nDynamic === 'function') i18nDynamic(document.body);
}
function setLanguage(lang) {
  if (!I18N[lang]) return;
  S.lang = lang;
  try { localStorage.setItem('biblio_lang', lang); } catch(e) {}
  applyLanguage();
  if (typeof rebuildTab === 'function') rebuildTab();
  else if (S.tab === 'asistente' && typeof buildChat === 'function') buildChat(true);
}

/* ---------- helpers ---------- */
const num = v => { const n = parseFloat(String(v).replace(',', '.')); return isNaN(n) ? 0 : n; };
const int0 = v => { const n = parseInt(v, 10); return isNaN(n) ? 0 : n; };
const titleCase = s => String(s).toLowerCase().replace(/(^|[\s\-'(/])([a-záéíóúñü])/g, (m, p, c) => p + c.toUpperCase());
const stripParen = s => String(s).replace(/\(.*?\)/g, '');
const uniq = a => [...new Set(a)];
const splitIds = s => String(s).split(';').map(x => x.trim()).filter(Boolean);
function countBy(a) { const m = new Map(); a.forEach(x => m.set(x, (m.get(x) || 0) + 1)); return m; }
function sortEnt(m, dir = 'desc') { return [...m.entries()].sort((a, b) => dir === 'desc' ? b[1] - a[1] : a[1] - b[1]); }

/* ============================================================
   NORMALIZACIÓN DE TÉRMINOS / PALABRAS CLAVE  (v16)
   Une variantes de un mismo concepto para no contarlas por separado:
     humans / human            -> human
     networks / network        -> network
     multi-objective / multi objective / multiobjective -> multiobjective
     neural networks / neural network -> neural network
   La ETIQUETA que se muestra es la forma más frecuente en la base real.
   ============================================================ */
const KW_IRREGULAR = {
  analyses: 'analysis', matrices: 'matrix', indices: 'index', vertices: 'vertex',
  appendices: 'appendix', crises: 'crisis', theses: 'thesis', hypotheses: 'hypothesis',
  diagnoses: 'diagnosis', prognoses: 'prognosis', parentheses: 'parenthesis',
  axes: 'axis', foci: 'focus', children: 'child', men: 'man', women: 'woman',
  mice: 'mouse', feet: 'foot', teeth: 'tooth', phenomena: 'phenomenon', criteria: 'criterion'
};
const KW_INVARIANT = new Set(['series', 'species', 'news', 'means', 'physics', 'mathematics',
  'statistics', 'dynamics', 'economics', 'genetics', 'kinetics', 'robotics', 'ethics',
  'politics', 'status', 'apparatus', 'corpus', 'basis', 'axis', 'analysis', 'virus',
  'census', 'lens', 'bias', 'aids', 'sars', 'gas', 'bus']);

function kwSingular(w) {
  if (!w || w.length <= 3) return w;
  if (KW_IRREGULAR[w]) return KW_IRREGULAR[w];
  if (KW_INVARIANT.has(w)) return w;
  if (/(sis|xis|osis|itis)$/.test(w)) return w;              // analysis, thesis, osteoporosis
  if (/(ss|us|is)$/.test(w)) return w;                       // class, focus, basis
  if (/ies$/.test(w)) return w.slice(0, -3) + 'y';           // studies -> study
  if (/(ches|shes|sses|zzes)$/.test(w)) return w.slice(0, -2); // matches->match, classes->class
  if (/(ses|xes|zes)$/.test(w)) return w.slice(0, -2);       // processes->process, boxes->box
  if (/oes$/.test(w)) return w.slice(0, -2);                 // heroes -> hero
  if (/s$/.test(w)) return w.slice(0, -1);                   // humans->human, networks->network
  return w;
}

/* Superficie legible: sin paréntesis, sin numeración inicial, sin apóstrofes */
function kwClean(raw) {
  let s = String(raw == null ? '' : raw)
    .replace(/\(.*?\)/g, ' ')
    .replace(/[’'`]/g, '')
    .replace(/^\s*\d+[.)\-]?\s+/, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!s) return '';
  const up = s.toUpperCase();
  if (['#N/A', 'NA', 'N/A', 'NULL', 'SIN CLASIFICACIÓN', 'SIN CLASIFICACION', '-'].includes(up)) return '';
  return s;
}

/* Clave de agrupación: minúsculas sin acento, singulariza el último token,
   elimina separadores para unir "multi objective"/"multiobjective"/"multi-objective" */
function kwKey(cleanOrRaw) {
  const s = kwClean(cleanOrRaw);
  if (!s) return '';
  let b = s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[\/_]/g, ' ').replace(/-/g, ' ')
    .replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
  if (!b) return '';
  const toks = b.split(' ');
  toks[toks.length - 1] = kwSingular(toks[toks.length - 1]);
  return toks.join('');
}

/* Diccionario global clave -> etiqueta (forma más frecuente en TODA la base). Memoizado. */
const _kwDictCache = {};
function kwDict(field) {
  const ck = field + '|' + (typeof DATA !== 'undefined' && DATA ? DATA.length : 0);
  if (_kwDictCache[ck]) return _kwDictCache[ck];
  const surf = new Map();
  (typeof DATA !== 'undefined' ? DATA : []).forEach(r => String(r[field] || '').split(/[;,|]/).forEach(t => {
    const c = kwClean(t); if (!c) return;
    const k = kwKey(c); if (!k) return;
    if (!surf.has(k)) surf.set(k, new Map());
    const m = surf.get(k); m.set(c, (m.get(c) || 0) + 1);
  }));
  const dict = new Map();
  surf.forEach((m, k) => {
    let best = null, bc = -1;
    m.forEach((cnt, c) => {
      if (cnt > bc || (cnt === bc && (best === null || c.length < best.length || (c.length === best.length && c < best)))) { best = c; bc = cnt; }
    });
    dict.set(k, best);
  });
  _kwDictCache[ck] = dict;
  return dict;
}

/* Etiqueta canónica de un término suelto */
function kwLabel(raw, field, display) {
  const k = kwKey(raw); if (!k) return '';
  const lab = kwDict(field).get(k) || kwClean(raw);
  return display === 'upper' ? lab.toUpperCase() : titleCase(lab);
}

/* Cuenta términos de 'rows' agrupando por clave. Devuelve [[etiqueta, conteo], ...] desc. */
function kwFold(rows, field, display) {
  const d = kwDict(field);
  const cnt = new Map();
  rows.forEach(r => String(r[field] || '').split(/[;,|]/).forEach(t => {
    const k = kwKey(t); if (!k) return;
    cnt.set(k, (cnt.get(k) || 0) + 1);
  }));
  const disp = s => display === 'upper' ? String(s).toUpperCase() : titleCase(s);
  return [...cnt.entries()]
    .map(([k, v]) => [disp(d.get(k) || k), v])
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
}
function normTxt(v) {
  return String(v || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toUpperCase();
}
function escAttr(s) {
  return String(s ?? '').replace(/[&<>"']/g, m => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
}
function hasUnitAffiliation(r) {
  const raw = r.FIALIACION_SESION ?? r.AFILIACION_SESION ?? r.AFILIACION_UNIDAD ?? '';
  const val = normTxt(raw);
  if (!val) return true;
  return ['SI', 'S', 'YES', 'Y', 'TRUE', '1'].includes(val);
}

const ACM_CURRICULUM_URL = 'https://www.acm.org/education/curricula-recommendations';
const ACM_CS2023_URL = 'https://csed.acm.org/';
const ACM_AREA_HELP_HTML = `Estas especialidades se usan como un marco de lectura disciplinar para Informática/Computación. En esta app se inspiran en recomendaciones curriculares ACM/IEEE/AAAI, como CS2023. <br><br><a href="${ACM_CURRICULUM_URL}" target="_blank" rel="noopener">Ver recomendaciones curriculares ACM</a> · <a href="${ACM_CS2023_URL}" target="_blank" rel="noopener">Ver CS2023</a><br><br>Importante: si la app se usa en otra carrera, las áreas de especialidad deben cambiarse por el marco propio de esa disciplina. Por ejemplo, Ingeniería Biomédica no debería leerse con las mismas áreas ACM de Computación.`;
const APPLICATION_AREA_HELP_HTML = `Las áreas de aplicación indican hacia qué campo se orienta la publicación: educación, ingeniería, salud, medicina, ciencias sociales u otros dominios. No son lo mismo que las áreas ACM: una publicación puede tener una especialidad computacional y aplicarse en otra disciplina.<br><br>Para otras carreras, estas áreas deben adaptarse al vocabulario de esa disciplina y no asumirse como universales.`;

const OECD_FRASCATI_URL = 'https://www.oecd.org/sti/inno/frascati-manual.htm';
const ANID_URL = 'https://anid.cl';
const UN_SDG_URL = 'https://www.un.org/sustainabledevelopment/es/objetivos-de-desarrollo-sostenible/';
const OCDE_AREA_HELP_HTML = `La clasificación OCDE ordena la investigación en grandes campos del conocimiento (Ciencias Naturales, Ingeniería y Tecnología, Ciencias Médicas y de la Salud, Ciencias Agrícolas, Ciencias Sociales y Humanidades) siguiendo el Manual de Frascati. En Chile, ANID la usa para clasificar la producción científica y los proyectos.<br><br><a href="${OECD_FRASCATI_URL}" target="_blank" rel="noopener">Ver Manual de Frascati (OCDE)</a> · <a href="${ANID_URL}" target="_blank" rel="noopener">Ver ANID</a>`;
const ODS_AREA_HELP_HTML = `Las áreas ODS (ANID) vinculan cada publicación con los Objetivos de Desarrollo Sostenible de la Agenda 2030 de la ONU, agrupados por ANID en grandes áreas: bienestar humano y capacidades, economías sostenibles y justas, sistemas alimentarios, descarbonización energética y bienes comunes ambientales.<br><br><a href="${UN_SDG_URL}" target="_blank" rel="noopener">Ver Objetivos de Desarrollo Sostenible (ONU)</a> · <a href="${ANID_URL}" target="_blank" rel="noopener">Ver ANID</a>`;

const FRIENDLY_HELP = {
  'summary.total': ['Producción total', 'Cuenta cuántas publicaciones hay en el periodo seleccionado. También muestra cuántos académicos(as) aportan a ese conjunto y el promedio simple de publicaciones por académico(a).'],
  'summary.tipo': ['Tipo de documento', 'Separa la producción entre artículos de revista, actas de conferencia y otros documentos. Sirve para ver si la unidad publica más en revistas o en conferencias.'],
  'summary.index': ['Indexación', 'Muestra cuántas publicaciones están registradas en Web of Science y cuántas sólo en Scopus, según la marca disponible en la base.'],
  'summary.citas': ['Citas totales', 'Suma todas las citas recibidas por las publicaciones del filtro activo. Es una señal de impacto, pero siempre debe leerse junto con el área, el año y el tipo de publicación.'],
  'summary.h': ['Índice h', 'Un índice h de 10 significa que existen 10 publicaciones con al menos 10 citas cada una. Aquí se calcula sólo con las publicaciones del filtro activo.'],
  'summary.q1': ['Revistas Q1', 'Cuenta los artículos publicados en revistas del primer cuartil. En simple: revistas ubicadas en el tramo superior de impacto dentro de su categoría.'],
  'summary.global': ['Alcance global', 'Cuenta los países que aparecen en las afiliaciones de coautoría. Ayuda a mirar colaboración internacional, no calidad por sí sola.'],
  'summary.especialidad': ['Especialidad top', ACM_AREA_HELP_HTML],
  'summary.aplicacion': ['Aplicación top', APPLICATION_AREA_HELP_HTML],
  'summary.ocde': ['Área OCDE top', OCDE_AREA_HELP_HTML],
  'summary.ocdeSub': ['Subárea OCDE top', OCDE_AREA_HELP_HTML],
  'summary.ods': ['Área ODS top', ODS_AREA_HELP_HTML],
  'summary.revista': ['Revista más publicada', 'Fuente o revista donde aparece el mayor número de artículos del filtro activo. Indica recurrencia, no necesariamente impacto.'],
  'summary.coautoria': ['Coautoría y colaboración', 'Autores por publicación muestra el tamaño promedio de los equipos. Coautoría institucional indica qué porcentaje de publicaciones incluye a más de un académico(a) de la unidad.'],
  'summary.mas_citada': ['Publicación más citada', 'Es el paper con más citas dentro del filtro activo. Puede favorecer publicaciones antiguas porque han tenido más tiempo para acumular citas.'],
  'summary.sjr': ['Mayor SJR', 'Muestra la publicación ubicada en la fuente con mayor SJR. SJR es una medida de impacto de la revista o conferencia, no del artículo individual.'],

  TP: ['Total de publicaciones', 'Número de registros de publicaciones en el filtro activo. En tablas institucionales puede incluir más de una fila por publicación si participan varios académicos(as) de la unidad.'],
  TPU: ['Publicaciones únicas', 'Cuenta cada publicación una sola vez, aunque tenga más de un académico(a) de la unidad como autor. Es útil para evitar doble conteo.'],
  TPj: ['Publicaciones en revistas', 'Cantidad de documentos clasificados como artículos de revista.'],
  TPp: ['Publicaciones en actas', 'Cantidad de documentos clasificados como conference paper o actas de conferencia.'],
  PTPj: ['% en revistas', 'Porcentaje de la producción que corresponde a artículos de revista.'],
  PTPp: ['% en actas', 'Porcentaje de la producción que corresponde a actas de conferencia.'],
  h: ['Índice h', 'Mide producción e impacto a la vez: h publicaciones tienen al menos h citas cada una. Aquí se calcula sólo sobre el filtro activo.'],
  g: ['Índice g', 'Parecido al índice h, pero da más peso a publicaciones muy citadas. Ayuda a detectar impacto concentrado en trabajos destacados.'],
  PPA: ['Promedio por académico(a)', 'Promedio simple de publicaciones por académico(a) de la unidad en el filtro activo.'],
  PPAj: ['Revistas por académico(a)', 'Promedio de artículos de revista por académico(a).'],
  PPAp: ['Actas por académico(a)', 'Promedio de actas de conferencia por académico(a).'],
  PPAA: ['Promedio por año', 'Cantidad promedio de publicaciones por año dentro del periodo seleccionado.'],
  PPAjA: ['Revistas por año', 'Cantidad promedio de artículos de revista por año.'],
  PPApA: ['Actas por año', 'Cantidad promedio de actas de conferencia por año.'],
  TPA: ['Años activos', 'Número de años del periodo en que hubo al menos una publicación.'],
  PAPP: ['Productividad por año activo', 'Promedio de publicaciones considerando sólo los años con producción.'],
  TC: ['Total de citas', 'Suma de citas recibidas por las publicaciones del filtro activo.'],
  maxC: ['Máximo de citas', 'Mayor número de citas recibido por una publicación del filtro activo.'],
  medC: ['Mediana de citas', 'Valor central de citas: la mitad de las publicaciones tiene igual o menos citas que este valor. Es menos sensible a casos extremos.'],
  PCPP: ['Citas por publicación', 'Promedio de citas por publicación. Puede subir mucho si hay pocos trabajos muy citados.'],
  TCPP: ['Publicaciones citadas', 'Cantidad de publicaciones que tienen al menos una cita.'],
  PCP: ['Proporción citadas', 'Parte de la producción que ya recibió al menos una cita.'],
  CPP: ['Citas por publicación citada', 'Promedio de citas considerando sólo las publicaciones que tienen citas.'],
  Q1: ['Revistas Q1', 'Cantidad de artículos en revistas del primer cuartil.'],
  Q2: ['Revistas Q2', 'Cantidad de artículos en revistas del segundo cuartil.'],
  Q3: ['Revistas Q3', 'Cantidad de artículos en revistas del tercer cuartil.'],
  Q4: ['Revistas Q4', 'Cantidad de artículos en revistas del cuarto cuartil.'],
  PQ1: ['% artículos en Q1', 'Porcentaje de artículos de revista que están en Q1.'],
  TINT: ['Tasa de internacionalización', 'Porcentaje de publicaciones con al menos un país distinto de Chile en las afiliaciones de autores.'],
  PDOI: ['% con DOI', 'Porcentaje de publicaciones que tienen DOI registrado. Facilita trazabilidad y acceso.'],
  PSJR: ['SJR promedio', 'Promedio del indicador SJR de las fuentes donde se publicó. Es una medida de la fuente, no del artículo.'],
  maxSJR: ['SJR máximo', 'Mayor SJR observado entre las fuentes del filtro activo.'],
  minSJR: ['SJR mínimo', 'Menor SJR observado entre las fuentes del filtro activo.'],

  TA: ['Total de académicos(as)', 'Cantidad de académicos(as) de la unidad que aparecen con publicaciones en el filtro activo.'],
  NCA: ['Colaboradores(as) únicos', 'Cantidad de autores distintos detectados en las publicaciones, incluyendo internos y externos.'],
  ANCA: ['Promedio de colaboradores(as)', 'Promedio de autores distintos por publicación. Aproxima el tamaño de las redes de colaboración.'],
  PC: ['Con coautoría', 'Cantidad de publicaciones con más de un autor.'],
  PPCA: ['% con coautoría', 'Porcentaje de publicaciones que fueron escritas por dos o más autores.'],
  PCAI: ['Coautoría institucional', 'Cantidad de publicaciones donde participa más de un académico(a) de la unidad.'],
  PPCAI: ['% coautoría institucional', 'Porcentaje de publicaciones con colaboración interna dentro de la unidad.'],
  PPA1: ['% primer autor', 'Porcentaje de publicaciones donde un académico(a) de la unidad aparece en primera autoría.'],
  PPA2: ['% autor intermedio', 'Porcentaje de publicaciones donde un académico(a) de la unidad aparece en una posición intermedia.'],
  PPA3: ['% último autor', 'Porcentaje de publicaciones donde un académico(a) de la unidad aparece como último autor.']
};
const TEXT_HELP = {
  'Universidad': ['Universidad', 'Filtra la base para mostrar sólo publicaciones asociadas a la universidad seleccionada.'],
  'Unidad académica': ['Unidad académica', 'Filtra la producción por departamento, carrera o unidad académica.'],
  'Periodo de publicación': ['Periodo de publicación', 'Define el rango de años usado en todas las vistas, gráficos, tablas e informes.'],
  'Resumen': ['Resumen', 'Vista rápida con los principales números de producción, impacto, indexación y colaboración.'],
  'Indicadores': ['Indicadores', 'Tablas con métricas bibliométricas. Puedes pasar el cursor por las siglas o hacer clic para ver explicación.'],
  'Perfiles': ['Perfiles', 'Permite revisar la producción de una unidad completa o de un académico(a) específico.'],
  'Dominio': ['Dominio', 'Muestra cómo aparecen áreas, subáreas o palabras clave a través del tiempo y por académico(a).'],
  'Asistente': ['Asistente', 'Chat local gratuito para consultar la base sin usar API ni servidor externo.'],
  'Nivel de análisis': ['Nivel de análisis', 'Elige si quieres ver indicadores de la unidad completa o desglosados por académico(a).'],
  'Selección': ['Selección', 'Cambia entre el perfil institucional y el perfil de un académico(a).'],
  'Académico(a)': ['Académico(a)', 'Selecciona la persona cuyo perfil bibliométrico quieres revisar.'],
  'Indexación': ['Indexación', 'Permite usar todas las publicaciones, sólo Web of Science o sólo Scopus.'],
  'Tipo de documento': ['Tipo de documento', 'Filtra el análisis de dominio por todas las publicaciones, Web of Science o Scopus.'],
  'Término': ['Término', 'Elige la palabra, área o subárea que quieres seguir en el tiempo.'],
  'Frecuencia anual de publicaciones': ['Frecuencia anual', 'Muestra cuántas publicaciones hay por año dentro del filtro activo.'],
  'Trayectoria académica': ['Trayectoria académica', 'Combina publicaciones anuales y citas acumuladas para ver evolución en el tiempo.'],
  'Distribución': ['Distribución', 'Resume el perfil por cuartil de revista y tipo de documento.'],
  'Principales coautores(as)': ['Principales coautores(as)', 'Muestra las personas que más aparecen como coautoras en las publicaciones del perfil.'],
  'Publicaciones': ['Publicaciones', 'Lista las publicaciones del perfil; si hay DOI o enlace, puedes abrir el registro.'],
  'Revistas y fuentes': ['Revistas y fuentes', 'Muestra dónde publica con más frecuencia el perfil seleccionado.'],
  'Detalles': ['Detalles', 'Resume información adicional, como idiomas, DOI y enlaces disponibles.'],
  'Flujo de áreas': ['Flujo de áreas', `Conecta áreas de especialidad con áreas de aplicación. En Informática, las especialidades siguen una lectura tipo ACM/IEEE/AAAI; en otras carreras, el conjunto de especialidades debe reemplazarse por el marco disciplinar correspondiente.<br><br><a href="${ACM_CURRICULUM_URL}" target="_blank" rel="noopener">Ver recomendaciones curriculares ACM</a> · <a href="${ACM_CS2023_URL}" target="_blank" rel="noopener">Ver CS2023</a>`],
  'Palabras clave más frecuentes': ['Palabras clave frecuentes', 'Muestra los términos que más aparecen en las publicaciones del perfil o unidad.'],
  'Fuentes más frecuentes': ['Fuentes frecuentes', 'Lista revistas o conferencias donde más se publica.'],
  'Red de coautorías': ['Red de coautorías', 'Cada nodo representa un académico(a) y los enlaces indican publicaciones compartidas.'],
  'Similitud temática entre académicos(as)': ['Similitud temática', 'Agrupa académicos(as) según semejanza textual de resúmenes, palabras clave y áreas.'],
  'Distancia euclidiana': ['Distancia euclidiana', 'Agrupamiento basado en distancia entre perfiles temáticos. Menor distancia indica mayor similitud.'],
  'Correlación': ['Correlación', 'Agrupamiento basado en patrones temáticos similares, aunque los volúmenes de publicación sean distintos.'],
  'Colaboración internacional': ['Colaboración internacional', 'Mapa de países presentes en las afiliaciones de coautores.'],
  'Producción': ['Producción', 'Resumen del número de publicaciones del perfil y su distribución por indexación.'],
  'Identificadores Scopus': ['Identificadores Scopus', 'Códigos usados por Scopus para identificar autores. Puede haber más de uno por persona.'],
  'Identificadores Web of Science': ['Identificadores Web of Science', 'Códigos de autor usados por Web of Science. El enlace abre el perfil o registro de autor asociado cuando está disponible.'],
  'Publicaciones': ['Publicaciones', 'Cantidad de publicaciones del filtro o perfil activo.'],
  'Citas totales': ['Citas totales', 'Suma de citas recibidas por las publicaciones del filtro activo.'],
  'Índice h': ['Índice h', 'h publicaciones tienen al menos h citas cada una.'],
  'Índice g': ['Índice g', 'Indicador parecido al h, pero más sensible a publicaciones muy citadas.'],
  'Citas / pub.': ['Citas por publicación', 'Promedio de citas recibidas por publicación.'],
  '% en Q1': ['Porcentaje en Q1', 'Porcentaje de artículos ubicados en revistas del primer cuartil.'],
  'SJR medio': ['SJR medio', 'Promedio del indicador SJR de las fuentes donde publica el perfil.'],
  'Coautores': ['Coautores', 'Cantidad de coautores distintos detectados para el perfil.'],
  '% internac.': ['Porcentaje internacional', 'Porcentaje de publicaciones con al menos un país distinto de Chile.'],
  'Años activo': ['Años activo', 'Cantidad de años entre la primera y la última publicación del perfil en el filtro activo.'],
  'Dominio': ['Dominio', 'Tipo de información temática que se quiere analizar: especialidad, aplicación, subárea o palabra clave.'],
  'Chat local': ['Chat local', 'El asistente responde usando reglas y búsquedas sobre el CSV cargado en tu navegador.'],
  'Preguntas rápidas': ['Preguntas rápidas', 'Atajos para enviar consultas frecuentes al asistente.'],
  'Limpiar chat': ['Limpiar chat', 'Borra la conversación actual y deja nuevamente el mensaje inicial de ayuda.'],
  'Hallazgos automáticos': ['Hallazgos automáticos', 'Resume patrones relevantes del filtro activo: tendencia reciente, calidad editorial, colaboración internacional, especialidad dominante y publicación con mayor impacto.'],
  'Buscador global': ['Buscador global', 'Busca en toda la base filtrada: título, autores, DOI, fuente, resumen, palabras clave, áreas, subáreas y códigos disponibles. Si el registro tiene DOI o enlace, el título abre la publicación original.'],
  'Comparador χ² entre académicos(as)': ['Comparador chi-cuadrado', 'Compara dos grupos en una variable categórica: académico(a) vs académico(a), académico(a) vs resto de la unidad, o resto vs académico(a). Los residuos positivos indican temas más presentes en A; los negativos, temas más presentes en B.'],
  'Oportunidades de colaboración': ['Oportunidades de colaboración', 'Sugiere pares de académicos(as) con vocabulario o áreas similares que no aparecen como coautores en la base filtrada. Es una señal exploratoria, no una recomendación definitiva.']
};
function helpAttrs(key) {
  const h = fhL(key);
  return h ? ` data-help-title="${escAttr(h[0])}" data-help-body="${escAttr(h[1])}" title="${escAttr(LBLT('Haz clic para ver ayuda'))}"` : '';
}
/* Resolvers i18n (stubs; app_i18n_ext.js los reemplaza con EN/PT) */
function fhL(code){ return FRIENDLY_HELP[code] || null; }
function thL(txt){ return TEXT_HELP[txt] || null; }
function LBLT(s){ return s; }
function T(s){ return s; }            /* traductor inline: sobrescrito en app_i18n_ext.js */
function i18nDynamic(root){ }          /* traductor de DOM: sobrescrito en app_i18n_ext.js */
function esFromDisplay(txt){ return txt; }
function showFriendlyHelp(title, body) {
  const modal = document.getElementById('help_modal');
  if (!modal) return;
  document.getElementById('help_title').textContent = title || 'Ayuda';
  const bodyEl = document.getElementById('help_body');
  bodyEl.innerHTML = body || '';
  modal.classList.add('show');
  modal.setAttribute('aria-hidden', 'false');
}
function hideFriendlyHelp() {
  const modal = document.getElementById('help_modal');
  if (!modal) return;
  modal.classList.remove('show');
  modal.setAttribute('aria-hidden', 'true');
}
function setHelpTarget(el, title, body) {
  if (!el || !title || !body) return;
  el.setAttribute('title', `${title}: ${body}`);
  el.setAttribute('data-help-title', title);
  el.setAttribute('data-help-body', body);
  el.classList.add('has-help');
}
function applyFriendlyTooltips() {
  document.querySelectorAll('#p-asistente [data-help-title], #p-asistente .has-help, .field label, .control label, select, #tabs button').forEach(el => {
    el.removeAttribute('title');
    el.removeAttribute('data-help-title');
    el.removeAttribute('data-help-body');
    el.classList.remove('has-help');
  });
  document.querySelectorAll('.viz-head h4, .card-head h4, .pl-h, .pm-l').forEach(el => {
    const txt = el.textContent.trim();
    const h = thL(esFromDisplay(txt));
    if (h) setHelpTarget(el, h[0], h[1]);
  });
  document.querySelectorAll('.pm-card').forEach(card => {
    const txt = card.querySelector('.pm-l')?.textContent?.trim();
    const h = thL(esFromDisplay(txt || ''));
    if (h) setHelpTarget(card, h[0], h[1]);
  });
  document.querySelectorAll('.profile-card').forEach(card => setHelpTarget(card, LBLT('Ficha de perfil'), LBLT('Resume el perfil institucional o académico seleccionado, incluyendo producción e indexación.')));
}
let HELP_WIRED = false;
function wireFriendlyHelp() {
  if (HELP_WIRED) return;
  document.addEventListener('click', e => {
    const close = e.target.closest('#help_close');
    if (close) { hideFriendlyHelp(); return; }
    const modal = e.target.id === 'help_modal' ? e.target : null;
    if (modal) { hideFriendlyHelp(); return; }
    const el = e.target.closest('[data-help-title]');
    if (!el) return;
    showFriendlyHelp(el.dataset.helpTitle, el.dataset.helpBody);
  });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') hideFriendlyHelp(); });
  HELP_WIRED = true;
}

/* ---------- CSV ---------- */
function parseCSV(raw) {
  raw = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
  const lines = raw.split('\n');
  const headers = lines[0].split('|').map(h => h.trim());
  const H = headers.length;
  // Las 4 últimas columnas (CATEGORIAS, AREAS, URL_FOTO_ACADEMICO, URL_FOTO_DEPARTAMENTO)
  // son siempre los 4 últimos campos de cada fila. Algunas filas (p. ej. las del DIINF)
  // traen campos extra en el bloque de área de computación, lo que corría todo hacia la
  // derecha y dejaba las fotos y categorías en columnas equivocadas. Para esas filas
  // alineamos la cabecera por el frente y la cola por el final.
  const TAIL = 4;
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i]) continue;
    const c = lines[i].split('|'); const o = {};
    if (c.length > H) {
      for (let j = 0; j < H - TAIL; j++) o[headers[j]] = (c[j] !== undefined ? c[j] : '').trim();
      for (let k = 0; k < TAIL; k++) o[headers[H - TAIL + k]] = (c[c.length - TAIL + k] !== undefined ? c[c.length - TAIL + k] : '').trim();
    } else {
      headers.forEach((h, j) => o[h] = (c[j] !== undefined ? c[j] : '').trim());
    }
    rows.push(o);
  }
  return { headers, rows };
}

/* ---------- filtros ---------- */
function base() {
  return DATA.filter(r => r.UNIVERSIDAD === S.uni && r.SESION === S.sec &&
    int0(r.ANO) >= S.yMin && int0(r.ANO) <= S.yMax &&
    hasUnitAffiliation(r));
}
function byIndex(rows, idx) {
  if (idx === 'Web of Science') return rows.filter(r => r.WOS === 'SI');
  if (idx === 'Scopus') return rows.filter(r => r.WOS === 'NO');
  return rows;
}

/* ---------- overlay ---------- */
function ov(t, s) { document.getElementById('ov-t').textContent = t; document.getElementById('ov-s').textContent = s || ''; document.getElementById('overlay').classList.add('show'); }
function ovHide() { document.getElementById('overlay').classList.remove('show'); }

/* ============================================================
   RESUMEN
   ============================================================ */
function buildResumen() {
  const d = base();
  const g = document.getElementById('summary');
  if (!d.length) { g.innerHTML = '<div class="empty c12">No hay datos para el periodo seleccionado.</div>'; return; }

  const total = d.length;
  const autores = uniq(d.map(r => r.NOMBRE_AUTOR)).length;
  const prom = (total / autores).toFixed(1);
  const nArt = d.filter(r => r.TIPO_DOCUMENTO === 'Article').length;
  const nConf = d.filter(r => r.TIPO_DOCUMENTO === 'Conference paper').length;
  const nOtr = total - nArt - nConf;
  const wos = d.filter(r => r.WOS === 'SI').length, sco = total - wos;
  const pc = n => (n / total * 100).toFixed(1);

  const cs = sortEnt(countBy(d.map(r => r.AREA_COMPUTACION).filter(Boolean)));
  const csTop = cs[0] || ['—', 0];

  let areas = [];
  d.forEach(r => String(r.AREAS).split(';').forEach(a => { a = a.trim(); if (a && a !== '#N/A') areas.push(a); }));
  const af = [...countBy(areas).entries()].filter(([k]) => k !== 'Computer Science').sort((a, b) => b[1] - a[1]);
  const appTop = af[0] || ['—', 0];

  const ocdeE = sortEnt(countBy(d.map(r => String(r.DISCIPLINA_OCDE || '').trim()).filter(v => v && v !== '#N/A')));
  const ocdeTop = ocdeE[0] || ['—', 0];
  const ocdeSubE = sortEnt(countBy(d.map(r => String(r.AREA_OCDE || '').trim()).filter(v => v && v !== '#N/A')));
  const ocdeSubTop = ocdeSubE[0] || ['—', 0];
  const odsE = sortEnt(countBy(d.map(r => String(r.AREA_ODS_ANID || '').trim()).filter(v => v && v !== '#N/A' && !/No claramente asociado/i.test(v))));
  const odsTop = odsE[0] || ['—', 0];

  const arts = d.filter(r => r.TIPO_DOCUMENTO === 'Article');
  const rev = arts.length ? sortEnt(countBy(arts.map(r => r.FUENTE)))[0] : ['—', 0];

  const promAut = (d.reduce((s, r) => s + splitIds(r.AUTORES_ID).length, 0) / total).toFixed(1);
  const instIds = new Set(uniq(d.map(r => r.SCOPUS_ID)));
  let multi = 0; d.forEach(r => { if (splitIds(r.AUTORES_ID).filter(i => instIds.has(i)).length > 1) multi++; });
  const pctInst = Math.round(multi / total * 100);

  // métricas de impacto
  const totalCit = d.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const H = hIndex(d.map(r => int0(r.CITADO_POR)));
  const Q1 = d.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
  const maxCit = Math.max(...d.map(r => int0(r.CITADO_POR)));
  const mc = d.find(r => int0(r.CITADO_POR) === maxCit);
  const maxSJR = Math.max(...d.map(r => num(r.SJR)));
  const mi = d.find(r => num(r.SJR) === maxSJR);

  // tendencia anual (sparkline)
  const yc = {}; for (let y = S.yMin; y <= S.yMax; y++) yc[y] = 0;
  d.forEach(r => { const y = int0(r.ANO); if (y >= S.yMin && y <= S.yMax) yc[y]++; });
  const years = Object.keys(yc), vals = years.map(y => yc[y]);
  const spark = sparkBars(years, vals);

  // países distintos de colaboración
  const paises = new Set();
  d.forEach(r => String(r.PAISES_AUTORES || '').split(', ').forEach(p => { p = p.trim(); if (p) paises.add(p); }));

  // donut helpers
  const donut = (parts) => {
    const tot = parts.reduce((s, p) => s + p.v, 0) || 1;
    let acc = 0; const R = 26, C0 = 2 * Math.PI * R;
    const segs = parts.map(p => { const frac = p.v / tot; const dash = `${frac * C0} ${C0}`;
      const off = -acc * C0; acc += frac;
      return `<circle r="${R}" cx="32" cy="32" fill="none" stroke="${p.c}" stroke-width="11" stroke-dasharray="${dash}" stroke-dashoffset="${off}" transform="rotate(-90 32 32)"/>`; }).join('');
    return `<svg width="64" height="64" viewBox="0 0 64 64">${segs}<circle r="20" cx="32" cy="32" fill="var(--paper-2)"/></svg>`;
  };

  g.innerHTML = `
    <div class="stat c5 hero-stat"${helpAttrs('summary.total')}>
      <div class="stat-eyebrow"><i class="fa-solid fa-layer-group si"></i>Producción total</div>
      <div class="hero-flex">
        <div>
          <div class="stat-big">${total}</div>
          <div class="stat-unit"><b style="color:var(--emerald-2)">${autores}</b> ${T('autores(as)')} · ${prom} ${T('por autor(a)')}</div>
        </div>
        <div class="spark">${spark}</div>
      </div>
      <div class="hero-foot">${S.yMin}–${S.yMax} · ${T('publicaciones por año')}</div>
    </div>

    <div class="stat c4"${helpAttrs('summary.tipo')}>
      <div class="stat-eyebrow"><i class="fa-solid fa-shapes si"></i>Tipo de documento</div>
      <div class="donut-row">
        <div class="donut">${donut([{ v: nArt, c: C.emerald }, { v: nConf, c: C.amber }, { v: nOtr, c: '#b8b0a0' }])}</div>
        <div class="legend">
          <div class="lg"><span class="sw" style="background:${C.emerald}"></span>Revistas <b>${nArt}</b><span class="pct">${pc(nArt)}%</span></div>
          <div class="lg"><span class="sw" style="background:${C.amber}"></span>Actas <b>${nConf}</b><span class="pct">${pc(nConf)}%</span></div>
          <div class="lg"><span class="sw" style="background:#b8b0a0"></span>Otros <b>${nOtr}</b><span class="pct">${pc(nOtr)}%</span></div>
        </div>
      </div>
    </div>

    <div class="stat c3"${helpAttrs('summary.index')}>
      <div class="stat-eyebrow"><i class="fa-solid fa-database si"></i>Indexación</div>
      <div class="donut-row">
        <div class="donut">${donut([{ v: wos, c: C.emerald2 }, { v: sco, c: C.emeraldSoft }])}</div>
        <div class="legend">
          <div class="lg"><span class="sw" style="background:${C.emerald2}"></span>WoS <b>${wos}</b><span class="pct">${pc(wos)}%</span></div>
          <div class="lg"><span class="sw" style="background:${C.emeraldSoft}"></span>Scopus <b>${sco}</b><span class="pct">${pc(sco)}%</span></div>
        </div>
      </div>
    </div>

    <div class="stat c3 metric"${helpAttrs('summary.citas')}><div class="stat-eyebrow"><i class="fa-solid fa-quote-right si"></i>Citas totales</div><div class="stat-big" style="font-size:2.2rem;">${totalCit.toLocaleString('es')}</div><div class="stat-unit">${(totalCit / total).toFixed(1)} ${T('por publicación')}</div></div>
    <div class="stat c3 metric amber-metric"${helpAttrs('summary.h')}><div class="stat-eyebrow"><i class="fa-solid fa-ranking-star si"></i>Índice h</div><div class="stat-big" style="font-size:2.2rem;color:var(--amber);">${H}</div><div class="stat-unit">en el periodo seleccionado</div></div>
    <div class="stat c3 metric"${helpAttrs('summary.q1')}><div class="stat-eyebrow"><i class="fa-solid fa-award si"></i>Revistas Q1</div><div class="stat-big" style="font-size:2.2rem;">${Q1}</div><div class="stat-unit">${arts.length ? nf(Q1 / arts.length * 100) : 0}% ${T('de los artículos')}</div></div>
    <div class="stat c3 metric"${helpAttrs('summary.global')}><div class="stat-eyebrow"><i class="fa-solid fa-earth-americas si"></i>Alcance global</div><div class="stat-big" style="font-size:2.2rem;">${paises.size}</div><div class="stat-unit">países de coautoría</div></div>

    <div class="stat c3"${helpAttrs('summary.especialidad')}><div class="stat-eyebrow"><i class="fa-solid fa-arrow-trend-up si"></i>Especialidad top</div><div class="stat-body"><span class="em">${csTop[0]}</span></div><div class="bar"><span style="width:100%"></span></div><div class="stat-unit"><b>${csTop[1]}</b> publicaciones</div></div>
    <div class="stat c3"${helpAttrs('summary.aplicacion')}><div class="stat-eyebrow"><i class="fa-solid fa-bullseye si"></i>Aplicación top</div><div class="stat-body"><span class="em">${appTop[0]}</span></div><div class="bar amber"><span style="width:100%"></span></div><div class="stat-unit"><b>${appTop[1]}</b> publicaciones</div></div>
    <div class="stat c3"${helpAttrs('summary.ocde')}><div class="stat-eyebrow"><i class="fa-solid fa-flask si"></i>Área OCDE top</div><div class="stat-body"><span class="em">${ocdeTop[0]}</span></div><div class="bar"><span style="width:100%"></span></div><div class="stat-unit"><b>${ocdeTop[1]}</b> publicaciones</div></div>
    <div class="stat c3"${helpAttrs('summary.ocdeSub')}><div class="stat-eyebrow"><i class="fa-solid fa-atom si"></i>Subárea OCDE top</div><div class="stat-body"><span class="em">${ocdeSubTop[0]}</span></div><div class="bar"><span style="width:100%"></span></div><div class="stat-unit"><b>${ocdeSubTop[1]}</b> publicaciones</div></div>
    <div class="stat c3"${helpAttrs('summary.ods')}><div class="stat-eyebrow"><i class="fa-solid fa-seedling si"></i>Área ODS top</div><div class="stat-body"><span class="em">${odsTop[0]}</span></div><div class="bar amber"><span style="width:100%"></span></div><div class="stat-unit"><b>${odsTop[1]}</b> publicaciones</div></div>
    <div class="stat c3"${helpAttrs('summary.revista')}><div class="stat-eyebrow"><i class="fa-solid fa-book si"></i>Revista más publicada</div><div class="stat-body"><span class="em">${rev[0]}</span></div><div class="stat-unit"><b>${rev[1]}</b> artículos</div></div>
    <div class="stat c3"${helpAttrs('summary.coautoria')}><div class="stat-eyebrow"><i class="fa-solid fa-handshake si"></i>Coautoría · colaboración</div><div class="stat-rows" style="margin-top:4px;">
      <div class="stat-rk"><span class="lab">Autores por pub.</span><span class="val">${promAut}</span></div>
      <div class="stat-rk"><span class="lab">Coautoría institucional</span><span class="val">${pctInst}%</span></div>
    </div></div>

    <div class="stat c6 showcase"${helpAttrs('summary.mas_citada')}>
      <div class="sc-icon"><i class="fa-solid fa-quote-right"></i></div>
      <div class="sc-label">Publicación más citada</div>
      ${mc ? `<div class="sc-title">${mc.TITULO}</div>
        <div class="sc-meta"><span class="sc-big">${maxCit}</span> ${T('citas')} · ${titleCase(mc.NOMBRE_AUTOR)} · ${mc.ANO}</div>` : '<div class="sc-title">—</div>'}
    </div>
    <div class="stat c6 showcase amber-sc"${helpAttrs('summary.sjr')}>
      <div class="sc-icon"><i class="fa-solid fa-star"></i></div>
      <div class="sc-label">Mayor factor de impacto (SJR)</div>
      ${mi ? `<div class="sc-title">${mi.TITULO}</div>
        <div class="sc-meta"><span class="sc-big">${num(mi.SJR)}</span> SJR · ${titleCase(mi.NOMBRE_AUTOR)} · ${mi.ANO}</div>` : '<div class="sc-title">—</div>'}
    </div>`;
}

/* sparkline de barras en SVG */
function sparkBars(labels, vals) {
  const max = Math.max(1, ...vals); const W = 132, H = 44, n = vals.length;
  const bw = W / n * 0.62, gap = W / n;
  const bars = vals.map((v, i) => {
    const h = v / max * (H - 6); const x = i * gap + (gap - bw) / 2; const y = H - h;
    return `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${bw.toFixed(1)}" height="${h.toFixed(1)}" rx="1.5" fill="var(--emerald)" opacity="${0.5 + 0.5 * v / max}"><title>${labels[i]}: ${v}</title></rect>`;
  }).join('');
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${bars}</svg>`;
}

/* ============================================================
   INDICADORES
   ============================================================ */
function llave(r) {
  for (const c of ['DOI', 'WOS_ID']) { const v = String(r[c] || '').trim().toLowerCase(); if (v && !['', 'na', 'n/a', '#n/a', 'null'].includes(v)) return c + ':' + v; }
  return [r.TITULO, r.ANO, r.FUENTE, r.TIPO_DOCUMENTO].map(x => String(x || '').trim().toLowerCase()).join('||');
}
const unicas = rows => uniq(rows.map(llave)).length;
// Formato numérico: enteros sin decimales, el resto con UNA cifra decimal.
const nf = v => {
  if (typeof v !== 'number' || !isFinite(v)) return v;
  const r = Math.round(v * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
};
const fmt = v => nf(v);
const fmtVal = (label, v) => {
  const isPct = typeof label === 'string' && label.indexOf('%') !== -1;
  if (isPct && typeof v === 'number' && isFinite(v)) return fmt(v) + '%';
  return fmt(v);
};

/* índice-h de una lista de conteos de citas */
function hIndex(cites) {
  const s = [...cites].sort((a, b) => b - a);
  let h = 0;
  for (let i = 0; i < s.length; i++) { if (s[i] >= i + 1) h = i + 1; else break; }
  return h;
}

function indInst(d) {
  const TP = d.length, TPU = unicas(d);
  const TPj = d.filter(r => r.TIPO_DOCUMENTO === 'Article').length;
  const TPp = d.filter(r => r.TIPO_DOCUMENTO === 'Conference paper').length;
  const PTPj = TP ? +(TPj / TP * 100).toFixed(3) : 0, PTPp = TP ? +(TPp / TP * 100).toFixed(3) : 0;
  const na = uniq(d.map(r => r.NOMBRE_AUTOR)).length;
  const PPA = na ? +(TP / na).toFixed(3) : 0, PPAj = na ? +(TPj / na).toFixed(3) : 0, PPAp = na ? +(TPp / na).toFixed(3) : 0;
  const an = d.map(r => int0(r.ANO)); const per = TP ? Math.max(...an) - Math.min(...an) + 1 : 1;
  const PPAA = +(TP / per).toFixed(3), PPAjA = +(TPj / per).toFixed(3), PPApA = +(TPp / per).toFixed(3);
  const TPA = uniq(an).length, PAPP = TPA ? +(TP / TPA).toFixed(3) : 0;
  const TC = d.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const PCPP = TP ? +(TC / TP).toFixed(3) : 0, TCPP = d.filter(r => int0(r.CITADO_POR) > 0).length;
  const PCP = TP ? +(TCPP / TP).toFixed(3) : 0, CPP = TCPP ? +(TC / TCPP).toFixed(3) : 0;
  const sj = d.map(r => num(r.SJR)).filter(x => x >= 0);
  const PSJR = sj.length ? +(sj.reduce((a, b) => a + b) / sj.length).toFixed(3) : 0;
  const maxS = sj.length ? +Math.max(...sj).toFixed(3) : 0, minS = sj.length ? +Math.min(...sj).toFixed(3) : 0;
  const H = hIndex(d.map(r => int0(r.CITADO_POR)));
  const maxCit = TP ? Math.max(...d.map(r => int0(r.CITADO_POR))) : 0;
  const qc = q => d.filter(r => String(r.QUARTILE).toUpperCase() === q).length;
  const Q1 = qc('Q1'), Q2 = qc('Q2'), Q3 = qc('Q3'), Q4 = qc('Q4');
  // índice g
  const gIndex = (() => { const s = d.map(r => int0(r.CITADO_POR)).sort((a, b) => b - a); let acc = 0, g = 0;
    for (let i = 0; i < s.length; i++) { acc += s[i]; if (acc >= (i + 1) * (i + 1)) g = i + 1; else break; } return g; })();
  // mediana de citas
  const citsSorted = d.map(r => int0(r.CITADO_POR)).sort((a, b) => a - b);
  const medianCit = citsSorted.length ? (citsSorted.length % 2 ? citsSorted[(citsSorted.length - 1) / 2]
    : +((citsSorted[citsSorted.length / 2 - 1] + citsSorted[citsSorted.length / 2]) / 2).toFixed(3)) : 0;
  // tasa de internacionalización (con coautor extranjero)
  let intlP = 0; d.forEach(r => { const ps = String(r.PAISES_AUTORES || '').split(', ').map(x => x.trim()).filter(Boolean);
    if (ps.some(p => p && p !== 'Chile')) intlP++; });
  const TINT = TP ? +(intlP / TP * 100).toFixed(3) : 0;
  // % Q1 sobre artículos
  const PQ1 = TPj ? +(Q1 / TPj * 100).toFixed(3) : 0;
  // documentos con DOI
  const conDOI = d.filter(r => { const v = String(r.DOI || '').trim().toLowerCase(); return v && !['', 'na', 'n/a', '#n/a', 'null'].includes(v); }).length;
  const PDOI = TP ? +(conDOI / TP * 100).toFixed(3) : 0;

  const rend = [
    ['Total de publicaciones', 'TP', TP], ['Publicaciones únicas', 'TPU', TPU],
    ['En revistas', 'TPj', TPj], ['En actas de conferencia', 'TPp', TPp],
    ['% en revistas', 'PTPj', PTPj], ['% en actas', 'PTPp', PTPp],
    ['Índice h institucional', 'h', H], ['Índice g', 'g', gIndex],
    ['Promedio por académico(a)', 'PPA', PPA], ['Revistas por académico(a)', 'PPAj', PPAj],
    ['Actas por académico(a)', 'PPAp', PPAp], ['Promedio por año', 'PPAA', PPAA],
    ['Revistas por año', 'PPAjA', PPAjA], ['Actas por año', 'PPApA', PPApA],
    ['Años activos', 'TPA', TPA], ['Productividad por año activo', 'PAPP', PAPP],
    ['Total de citas', 'TC', TC], ['Máximo de citas', 'maxC', maxCit],
    ['Mediana de citas', 'medC', medianCit],
    ['Citas por publicación', 'PCPP', PCPP],
    ['Publicaciones citadas', 'TCPP', TCPP], ['Proporción citadas', 'PCP', PCP],
    ['Citas por publicación citada', 'CPP', CPP],
    ['Revistas en Q1', 'Q1', Q1], ['Revistas en Q2', 'Q2', Q2],
    ['Revistas en Q3', 'Q3', Q3], ['Revistas en Q4', 'Q4', Q4],
    ['% artículos en Q1', 'PQ1', PQ1],
    ['Tasa de internacionalización (%)', 'TINT', TINT],
    ['% con DOI', 'PDOI', PDOI],
    ['SJR promedio', 'PSJR', PSJR], ['SJR máximo', 'maxSJR', maxS], ['SJR mínimo', 'minSJR', minS]
  ].map(r => ({ Indicador: r[0], Sigla: r[1], Valor: fmtVal(r[0], r[2]) }));

  const TA = na;
  const allA = []; d.forEach(r => splitIds(r.AUTORES_ID).forEach(a => allA.push(a)));
  const NCA = uniq(allA).length, ANCA = TP ? +(NCA / TP).toFixed(3) : 0;
  const PC = d.filter(r => splitIds(r.AUTORES_ID).length > 1).length;
  const PPCA = TP ? +(PC / TP * 100).toFixed(3) : 0;
  const inst = new Set(uniq(d.map(r => r.SCOPUS_ID)));
  let PCAI = 0; d.forEach(r => { if (splitIds(r.AUTORES_ID).filter(i => inst.has(i)).length > 1) PCAI++; });
  const PPCAI = TP ? +(PCAI / TP * 100).toFixed(3) : 0;
  let p1 = 0, p2 = 0, p3 = 0;
  d.forEach(r => { const ids = splitIds(r.AUTORES_ID); if (!ids.length) return;
    if (inst.has(ids[0])) p1++; if (ids.length > 2 && ids.slice(1, -1).some(i => inst.has(i))) p2++;
    if (ids.length > 1 && inst.has(ids[ids.length - 1])) p3++; });
  const PPA1 = TP ? +(p1 / TP * 100).toFixed(3) : 0, PPA2 = TP ? +(p2 / TP * 100).toFixed(3) : 0, PPA3 = TP ? +(p3 / TP * 100).toFixed(3) : 0;

  const colab = [
    ['Total de académicos(as)', 'TA', TA], ['Colaboradores(as) únicos', 'NCA', NCA],
    ['Promedio de colaboradores(as)', 'ANCA', ANCA], ['Con coautoría', 'PC', PC],
    ['% con coautoría', 'PPCA', PPCA], ['Coautoría institucional', 'PCAI', PCAI],
    ['% coautoría institucional', 'PPCAI', PPCAI], ['% primer autor', 'PPA1', PPA1],
    ['% autor intermedio', 'PPA2', PPA2], ['% último autor', 'PPA3', PPA3]
  ].map(r => ({ Indicador: r[0], Sigla: r[1], Valor: fmtVal(r[0], r[2]) }));

  return { rend, colab, mode: 'inst' };
}

function indAcad(d) {
  const acs = uniq(d.map(r => r.NOMBRE_AUTOR)).sort();
  const inst = new Set(uniq(d.map(r => r.SCOPUS_ID)));
  // columnas: [titulo visible, tooltip, key]
  const rendCols = [
    ['Académico(a)', 'Nombre del/de la académico(a)'],
    ['TP', 'Total de publicaciones'],
    ['TPU', 'Publicaciones sin coautoría de la unidad'],
    ['Rev', 'Publicaciones en revistas'],
    ['Act', 'Publicaciones en actas de conferencia'],
    ['% Rev', 'Porcentaje en revistas'],
    ['h', 'Índice h (en el periodo y filtro actual)'],
    ['Pub/año', 'Promedio de publicaciones por año activo'],
    ['Años', 'Años activos con publicaciones'],
    ['1er', 'Año de la primera publicación'],
    ['Últ', 'Año de la última publicación'],
    ['TC', 'Total de citas'],
    ['Cit/Pub', 'Citas por publicación'],
    ['Pub.cit', 'Publicaciones con al menos una cita'],
    ['% Cit', 'Proporción de publicaciones citadas'],
    ['SJR x̄', 'Factor de impacto SJR promedio'],
    ['SJR ↑', 'Factor de impacto SJR máximo'],
    ['Q1', 'Publicaciones en revistas Q1']
  ];
  const colabCols = [
    ['Académico(a)', 'Nombre del/de la académico(a)'],
    ['Coaut. únicos', 'Coautores(as) distintos'],
    ['Aut/Pub', 'Promedio de autores por publicación'],
    ['Con coaut.', 'Publicaciones con coautoría'],
    ['% Coaut.', 'Porcentaje con coautoría'],
    ['Coaut. inst.', 'Publicaciones con coautoría institucional'],
    ['% Inst.', 'Porcentaje de coautoría institucional'],
    ['Internac.', 'Publicaciones con coautoría internacional'],
    ['% Internac.', 'Porcentaje de coautoría internacional'],
    ['Países', 'Países distintos de coautoría'],
    ['% 1er', 'Porcentaje como primer autor'],
    ['% Interm.', 'Porcentaje como autor intermedio'],
    ['% Últ.', 'Porcentaje como último autor']
  ];
  const rend = [], colab = [];
  acs.forEach(ac => {
    const da = d.filter(r => r.NOMBRE_AUTOR === ac);
    const TP = da.length;
    const TPU = unicas(da.filter(r => splitIds(r.AUTORES_ID).filter(i => inst.has(i)).length === 1));
    const TPj = da.filter(r => r.TIPO_DOCUMENTO === 'Article').length;
    const TPp = da.filter(r => r.TIPO_DOCUMENTO === 'Conference paper').length;
    const an = da.map(r => int0(r.ANO)).filter(x => x > 1900);
    const span = an.length ? Math.max(...an) - Math.min(...an) + 1 : 1;
    const TC = da.reduce((s, r) => s + int0(r.CITADO_POR), 0);
    const TCPP = da.filter(r => int0(r.CITADO_POR) > 0).length;
    const sj = da.map(r => num(r.SJR)).filter(x => x >= 0);
    const h = hIndex(da.map(r => int0(r.CITADO_POR)));
    const q1 = da.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
    rend.push([
      titleCase(ac), TP, TPU, TPj, TPp,
      TP ? nf(TPj / TP * 100) + '%' : '0%', h,
      an.length ? nf(TP / span) : 0, uniq(an).length,
      an.length ? Math.min(...an) : '—', an.length ? Math.max(...an) : '—',
      TC, TP ? nf(TC / TP) : 0, TCPP, TP ? nf(TCPP / TP * 100) + '%' : '0%',
      sj.length ? nf(sj.reduce((a, b) => a + b) / sj.length) : 0,
      sj.length ? nf(Math.max(...sj)) : 0, q1
    ]);
    const lists = da.map(r => splitIds(r.AUTORES_ID));
    const NCA = uniq(lists.flat()).length;
    let PCAI = 0; lists.forEach(l => { if (l.filter(i => inst.has(i)).length > 1) PCAI++; });
    // internacional: países distintos > 1 (incluye Chile)
    let intl = 0; const paisesSet = new Set();
    da.forEach(r => { const ps = String(r.PAISES_AUTORES || '').split(', ').map(x => x.trim()).filter(Boolean);
      ps.forEach(p => paisesSet.add(p)); if (ps.filter(p => p !== 'Chile').length > 0) intl++; });
    // ID Scopus real del/de la académico(a). En la base hay filas con el SCOPUS_ID mal
    // digitado (un dígito de más) que no calza con el que aparece en AUTORES_ID; eso hacía
    // que primer/intermedio/último autor diera 0%. Elegimos el ID que efectivamente aparece
    // en las autorías de sus propios trabajos; si ninguno calza, el ID común a más trabajos.
    const idCounts = {};
    da.forEach(r => splitIds(r.AUTORES_ID).forEach(id => { idCounts[id] = (idCounts[id] || 0) + 1; }));
    const declared = uniq(da.map(r => String(r.SCOPUS_ID).trim()).filter(Boolean));
    let myId = declared.find(id => idCounts[id]) ||
               Object.keys(idCounts).sort((a, b) => idCounts[b] - idCounts[a])[0] || '';
    let pr = 0, it = 0, ul = 0, cl = 0;
    da.forEach(r => { const ids = splitIds(r.AUTORES_ID);
      if (!ids.length || !myId || !ids.includes(myId)) return; cl++;
      if (ids[0] === myId) pr++; else if (ids.length > 1 && ids[ids.length - 1] === myId) ul++; else it++; });
    colab.push([
      titleCase(ac), NCA, TP ? nf(lists.reduce((s, l) => s + l.length, 0) / TP) : 0,
      lists.filter(l => l.length > 1).length, TP ? nf(lists.filter(l => l.length > 1).length / TP * 100) + '%' : '0%',
      PCAI, TP ? nf(PCAI / TP * 100) + '%' : '0%',
      intl, TP ? nf(intl / TP * 100) + '%' : '0%', paisesSet.size,
      cl ? nf(pr / cl * 100) + '%' : '0%', cl ? nf(it / cl * 100) + '%' : '0%', cl ? nf(ul / cl * 100) + '%' : '0%'
    ]);
  });
  return { rend, colab, rendCols, colabCols, mode: 'acad' };
}

function buildIndicadores() {
  const rows = byIndex(base(), S.indIndex);
  if (!rows.length) { killDT('#t_rend'); killDT('#t_colab'); document.querySelector('#t_rend').innerHTML = '<caption class="empty">Sin datos para el filtro actual.</caption>'; return; }
  if (S.indNivel === 'Institucionales') {
    const res = indInst(rows);
    drawDTObj('#t_rend', res.rend, true);
    drawDTObj('#t_colab', res.colab, true);
  } else {
    const res = indAcad(rows);
    drawDTArr('#t_rend', res.rend, res.rendCols);
    drawDTArr('#t_colab', res.colab, res.colabCols);
  }
}
function killDT(sel) { if ($.fn.DataTable.isDataTable(sel)) { $(sel).DataTable().destroy(); } $(sel).empty(); }

/* Institucional: objetos con claves SIN puntos (Indicador, Sigla, Valor) */
function drawDTObj(sel, data, inst) {
  killDT(sel);
  if (!data.length) return;
  const cols = Object.keys(data[0]).map(k => ({
    title: LBLT(k), data: k,
    render: (inst && k === 'Sigla') ? (dd => {
      const h = fhL(dd);
      const tip = h ? `${h[0]}: ${h[1]}` : dd;
      return `<span class="abbr-chip" title="${escAttr(tip)}">${dd}</span><span class="row-help-dot" title="${escAttr(tip)}"><i class="fa-solid fa-circle-question"></i></span>`;
    }) : (k === 'Indicador' ? (v => escAttr(LBLT(v))) : null)
  }));
  $(sel).DataTable({
    data, columns: cols, dom: 'Brt',
    buttons: [{ extend: 'csv', text: '↓ CSV', className: 'dt-button' }],
    pageLength: 50, ordering: false, order: [], language: dtLang(),
    createdRow: (row, rowData) => {
      const h = fhL(rowData.Sigla);
      if (h) {
        row.setAttribute('data-help-title', h[0]);
        row.setAttribute('data-help-body', h[1]);
        row.setAttribute('title', `${h[0]}: ${h[1]}`);
        row.classList.add('help-row');
      }
    }
  });
}

/* Por académico: filas como ARRAYS + columnas con tooltips (sin bug de puntos) */
function drawDTArr(sel, rows, colDefs) {
  killDT(sel);
  if (!rows.length) return;
  const columns = colDefs.map((c, i) => { const t0 = LBLT(c[0]), t1 = LBLT(c[1]); return ({
    title: `<span class="col-help" data-help-title="${escAttr(t0)}" data-help-body="${escAttr(t1)}" title="${escAttr(t1)}">${t0}${i === 0 ? '' : ' <i class="fa-solid fa-circle-question"></i>'}</span>`,
    className: i === 0 ? 'dt-author' : 'dt-num'
  }); });
  $(sel).DataTable({
    data: rows, columns, dom: 'Bfrtip',
    buttons: [{ extend: 'csv', text: '↓ CSV', className: 'dt-button' }],
    pageLength: 12, ordering: true, order: [[1, 'desc']], scrollX: true,
    language: dtLang()
  });
}
