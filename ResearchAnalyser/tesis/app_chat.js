/* ============================================================
   Asistente local de memorias, sin API ni servidor.
   La comprensión de la pregunta vive en ../shared/asistente.js (motor
   compartido con el módulo de publicaciones). Aquí solo se le
   explica cómo leer las memorias (state.filtered) y cómo dibujar
   cada respuesta. Todo se calcula en el navegador.
   ============================================================ */
const ChatLocal = { wired: false, asked: false, engine: null };

const CHAT_PROMPTS = {
  es: [
    'Memorias sobre inteligencia artificial guiadas por Bonacic',
    'Cuántos trabajos de doctorado hay desde 2020',
    '¿Quiénes son los guías con más trabajos?',
    'Trabajos por año de Villalobos',
    'Compara a Bonacic con Parada',
    'Co-guías de Villalobos',
    'Memorias de 2025 sin enlace',
    '¿Cuáles son las áreas más frecuentes?',
    'Trabajos por programa',
    '¿Qué es Software Design?'
  ],
  en: [
    'Final projects about artificial intelligence advised by Bonacic',
    'How many doctoral works since 2020',
    'Who are the advisors with most works?',
    'Works by year of Villalobos',
    'Compare Bonacic with Parada',
    'Co-advisors of Villalobos',
    '2025 works without link',
    'What are the most frequent areas?',
    'Works by program',
    'What is Software Design?'
  ],
  pt: [
    'Trabalhos sobre inteligência artificial orientados por Bonacic',
    'Quantos trabalhos de doutorado há desde 2020',
    'Quem são os orientadores com mais trabalhos?',
    'Trabalhos por ano de Villalobos',
    'Compare Bonacic com Parada',
    'Coorientações de Villalobos',
    'Trabalhos de 2025 sem link',
    'Quais são as áreas mais frequentes?',
    'Trabalhos por programa',
    'O que é Software Design?'
  ]
};

/* Textos propios de este módulo (el motor trae los suyos) */
const CHAT_UI = {
  es: { greet2: 'Combino condiciones en una misma pregunta: <b>académico(a)</b>, <b>años</b>, <b>programa</b>, <b>tema</b> y <b>con o sin enlace</b>. Por ejemplo: “memorias sobre seguridad guiadas por Bonacic”, “cuántos trabajos de magíster hay desde 2020”, “co-guías de Villalobos”, “trabajos por año” o “compara a X con Y”.', works: 'trabajos', asGuide: 'como guía', asCoguide: 'como co-guía', period: 'periodo', programs: 'programas', guides: 'guías', withLink: 'con enlace', students: 'estudiantes', topArea: 'área frecuente', byYear: 'Trabajos por año', byProgram: 'Trabajos por programa', byGuide: 'Guías con más trabajos', byCoguide: 'Co-guías con más trabajos', areasK: 'Áreas de conocimiento', areasA: 'Áreas de aplicación', areasS: 'Áreas del SWEBOK', keywords: 'Palabras clave', partners: 'Personas que han compartido guía o co-guía con', partnersTitle: 'Colaboraciones', pairs: 'Parejas guía + co-guía más frecuentes', noPartners: 'no registra guía o co-guía compartida con otra persona en estas condiciones.', compare: 'Comparación con las condiciones indicadas', shared: 'Áreas en común', only: 'Solo', hint: 'Para el detalle estadístico (χ² y residuos) usa el comparador en la pestaña <b>Perfiles</b>.', more: '…y {n} trabajos más. Pide “todos” o agrega una condición para acotar.', noWorks: 'No encontré trabajos para esa consulta con los filtros actuales.', tryAlso: 'Prueba con', suggest: ['Trabajos guiados por Bonacic', 'Memorias de 2023', 'Memorias sobre videojuegos'], guide: 'Guía', coguide: 'Co-guía', noDef: 'No tengo una definición para eso. Puedo definir áreas como <b>Software Design</b>, <b>Software Engineering</b>, <b>Artificial Intelligence</b>, <b>Security</b>, <b>Algorithms and Complexity</b> o <b>Research/Investigation</b>.', defCount: 'Con los filtros actuales hay {n} trabajos asociados a esta área.', progNames: { exec: 'Ingeniería de Ejecución en Computación e Informática', civil: 'Ingeniería Civil en Informática', phd: 'Doctorado en Ciencias de la Ingeniería', msec: 'Magíster en Seguridad, Peritaje y Auditoría', minf: 'Magíster en Ingeniería Informática', mag: 'Magíster (todos)', pregrado: 'Pregrado', posgrado: 'Posgrado' } },
  en: { greet2: 'I combine conditions in one question: <b>academic</b>, <b>years</b>, <b>program</b>, <b>topic</b> and <b>with or without link</b>. For example: “works about security advised by Bonacic”, “how many master works since 2020”, “co-advisors of Villalobos”, “works by year” or “compare X with Y”.', works: 'works', asGuide: 'as advisor', asCoguide: 'as co-advisor', period: 'period', programs: 'programs', guides: 'advisors', withLink: 'with link', students: 'students', topArea: 'frequent area', byYear: 'Works per year', byProgram: 'Works per program', byGuide: 'Advisors with most works', byCoguide: 'Co-advisors with most works', areasK: 'Knowledge areas', areasA: 'Application areas', areasS: 'SWEBOK areas', keywords: 'Keywords', partners: 'People who shared advising or co-advising with', partnersTitle: 'Collaborations', pairs: 'Most frequent advisor + co-advisor pairs', noPartners: 'has no shared advising with another person under these conditions.', compare: 'Comparison under the given conditions', shared: 'Areas in common', only: 'Only', hint: 'For the statistical detail (χ² and residuals) use the comparator in the <b>Profiles</b> tab.', more: '…and {n} more works. Ask for “all” or add a condition to narrow it down.', noWorks: 'No works found for that query with the current filters.', tryAlso: 'Try', suggest: ['Works advised by Bonacic', 'Works from 2023', 'Works about video games'], guide: 'Advisor', coguide: 'Co-advisor', noDef: 'I have no definition for that. I can define areas such as <b>Software Design</b>, <b>Software Engineering</b>, <b>Artificial Intelligence</b>, <b>Security</b>, <b>Algorithms and Complexity</b> or <b>Research/Investigation</b>.', defCount: 'With the current filters there are {n} works associated with this area.', progNames: { exec: 'Computer Execution Engineering', civil: 'Computer Civil Engineering', phd: 'PhD in Engineering Sciences', msec: 'MSc in Security, Forensics and Auditing', minf: 'MSc in Informatics Engineering', mag: 'Master (all)', pregrado: 'Undergraduate', posgrado: 'Graduate' } },
  pt: { greet2: 'Combino condições numa mesma pergunta: <b>acadêmico(a)</b>, <b>anos</b>, <b>programa</b>, <b>tema</b> e <b>com ou sem link</b>. Por exemplo: “trabalhos sobre segurança orientados por Bonacic”, “quantos trabalhos de mestrado há desde 2020”, “coorientações de Villalobos”, “trabalhos por ano” ou “compare X com Y”.', works: 'trabalhos', asGuide: 'como orientador(a)', asCoguide: 'como coorientador(a)', period: 'período', programs: 'programas', guides: 'orientadores', withLink: 'com link', students: 'estudantes', topArea: 'área frequente', byYear: 'Trabalhos por ano', byProgram: 'Trabalhos por programa', byGuide: 'Orientadores com mais trabalhos', byCoguide: 'Coorientadores com mais trabalhos', areasK: 'Áreas de conhecimento', areasA: 'Áreas de aplicação', areasS: 'Áreas do SWEBOK', keywords: 'Palavras-chave', partners: 'Pessoas que compartilharam orientação ou coorientação com', partnersTitle: 'Colaborações', pairs: 'Duplas orientador + coorientador mais frequentes', noPartners: 'não registra orientação compartilhada com outra pessoa nessas condições.', compare: 'Comparação com as condições indicadas', shared: 'Áreas em comum', only: 'Só', hint: 'Para o detalhe estatístico (χ² e resíduos) use o comparador na aba <b>Perfis</b>.', more: '…e mais {n} trabalhos. Peça “todos” ou acrescente uma condição para delimitar.', noWorks: 'Não encontrei trabalhos para essa consulta com os filtros atuais.', tryAlso: 'Tente', suggest: ['Trabalhos orientados por Bonacic', 'Trabalhos de 2023', 'Trabalhos sobre videogames'], guide: 'Orientador(a)', coguide: 'Coorientador(a)', noDef: 'Não tenho uma definição para isso. Posso definir áreas como <b>Software Design</b>, <b>Software Engineering</b>, <b>Artificial Intelligence</b>, <b>Security</b>, <b>Algorithms and Complexity</b> ou <b>Research/Investigation</b>.', defCount: 'Com os filtros atuais há {n} trabalhos associados a esta área.', progNames: { exec: 'Engenharia de Execução em Computação e Informática', civil: 'Engenharia Civil em Informática', phd: 'Doutorado em Ciências da Engenharia', msec: 'Mestrado em Segurança, Perícia e Auditoria', minf: 'Mestrado em Engenharia Informática', mag: 'Mestrado (todos)', pregrado: 'Graduação', posgrado: 'Pós-graduação' } }
};
const cu = () => CHAT_UI[typeof MEM_LANG === 'string' ? MEM_LANG : 'es'] || CHAT_UI.es;

const AREA_DEFS = {
  "software engineering": "Ingeniería de software: organiza el desarrollo como proceso: requisitos, arquitectura, diseño, pruebas, mantenimiento, calidad y evolución de sistemas.",
  "software development fundamentals": "Fundamentos de desarrollo de software: programación, diseño básico, pruebas, depuración, control de versiones y buenas prácticas.",
  "software design": "Diseño de software (SWEBOK): estructura interna del software, patrones, descomposición en módulos y decisiones de arquitectura de bajo nivel.",
  "software requirements": "Requisitos de software (SWEBOK): elicitación, análisis, especificación y validación de lo que el sistema debe hacer.",
  "software architecture": "Arquitectura de software (SWEBOK): organización de alto nivel del sistema, componentes, conectores y atributos de calidad.",
  "software testing": "Pruebas de software (SWEBOK): técnicas para verificar y validar el software y detectar defectos.",
  "software construction": "Construcción de software (SWEBOK): codificación, verificación unitaria, integración y depuración para producir software que funcione.",
  "software maintenance": "Mantenimiento de software (SWEBOK): modificación del software ya entregado para corregir errores, mejorar rendimiento o adaptarlo a cambios.",
  "software configuration management": "Gestión de configuración (SWEBOK): control de versiones, construcción y entrega del software a lo largo de su ciclo de vida.",
  "software engineering management": "Gestión de la ingeniería de software (SWEBOK): planificación, seguimiento y control de proyectos de software.",
  "software engineering process": "Proceso de ingeniería de software (SWEBOK): definición, evaluación y mejora de los procesos de desarrollo.",
  "software engineering models and methods": "Modelos y métodos de ingeniería de software (SWEBOK): modelado, metodologías y técnicas sistemáticas de desarrollo.",
  "software quality": "Calidad de software (SWEBOK): aseguramiento, verificación, validación y medición de la calidad del producto y del proceso.",
  "software engineering professional practice": "Práctica profesional (SWEBOK): ética, trabajo en equipo, comunicación y responsabilidades del ingeniero de software.",
  "research/investigation": "Investigación: trabajos con foco en método científico, experimentación o generación de conocimiento nuevo.",
  "artificial intelligence": "Inteligencia artificial: sistemas que aprenden, razonan, predicen o deciden a partir de datos, reglas o modelos. Incluye aprendizaje automático, visión y lenguaje natural.",
  "algorithms and complexity": "Algoritmos y complejidad: métodos para resolver problemas y cuántos recursos (tiempo, memoria) requieren; escalabilidad de las soluciones.",
  "specialized platform development": "Desarrollo de plataformas especializadas: sistemas embebidos, móviles, web, cloud, IoT o entornos de ejecución específicos.",
  "security": "Seguridad: protección de sistemas, datos y comunicaciones frente a accesos no autorizados, ataques y vulnerabilidades.",
  "data management": "Gestión de datos: almacenar, organizar, consultar, integrar y gobernar datos; bases de datos y grandes volúmenes.",
  "human-computer interaction": "Interacción humano-computador: usabilidad, experiencia de usuario, accesibilidad, interfaces y evaluación con personas.",
  "networking and communication": "Redes y comunicación: protocolos, transmisión de datos, conectividad, rendimiento y seguridad de la comunicación digital.",
  "parallel and distributed computing": "Computación paralela y distribuida: cómputo repartido entre procesadores o nodos, concurrencia, nube y alto rendimiento.",
  "graphics and interactive techniques": "Gráficos y técnicas interactivas: visualización, gráficos por computador, realidad virtual o aumentada y animación.",
  "operating systems": "Sistemas operativos: administración de memoria, procesos, archivos, dispositivos y concurrencia.",
  "architecture and organization": "Arquitectura y organización: estructura de los computadores, procesadores, memoria e instrucciones.",
  "society, ethics and professionalism": "Sociedad, ética y profesionalismo: impactos sociales y éticos de la computación, privacidad, sesgos y regulación.",
  "mathematical and statistical foundations": "Fundamentos matemáticos y estadísticos: probabilidad, inferencia, optimización y modelos cuantitativos.",
  "computer science": "Ciencias de la computación: campo general de aplicación cuando el trabajo es propiamente computacional y no de otra disciplina."
};
const AREA_ALIAS = {
  seguridad: "security", seguranca: "security", ciberseguridad: "security",
  diseno: "software design", "diseno de software": "software design", design: "software design",
  pruebas: "software testing", testing: "software testing", testes: "software testing",
  requisitos: "software requirements", requirements: "software requirements",
  arquitectura: "software architecture", arquitetura: "software architecture",
  construccion: "software construction", mantenimiento: "software maintenance", manutencao: "software maintenance",
  calidad: "software quality", qualidade: "software quality",
  "inteligencia artificial": "artificial intelligence", ia: "artificial intelligence", ai: "artificial intelligence",
  "gestion de datos": "data management", "bases de datos": "data management", "banco de dados": "data management",
  redes: "networking and communication", algoritmos: "algorithms and complexity", complejidad: "algorithms and complexity",
  investigacion: "research/investigation", pesquisa: "research/investigation", research: "research/investigation",
  "ingenieria de software": "software engineering", "engenharia de software": "software engineering",
  "interaccion humano computador": "human-computer interaction", hci: "human-computer interaction", usabilidad: "human-computer interaction",
  "plataformas especializadas": "specialized platform development", "computacion paralela": "parallel and distributed computing",
  graficos: "graphics and interactive techniques", "sistemas operativos": "operating systems", etica: "society, ethics and professionalism",
  "ciencias de la computacion": "computer science", "ciencia de la computacion": "computer science"
};

function chatEsc(s){ return Asistente.esc(clean(s)); }
function chatNorm(s){ return Asistente.norm(clean(s)); }
function chatRows(){ return state.filtered; }
function fmtK(n){ const lg = typeof MEM_LANG === 'string' ? MEM_LANG : 'es'; return Number(n || 0).toLocaleString(lg === 'en' ? 'en-GB' : lg === 'pt' ? 'pt-BR' : 'es-CL'); }

function chatAuthorList(){
  const set = new Set();
  state.data.forEach(r => {
    if(valid(r["PROFESOR GUIA"])) set.add(clean(r["PROFESOR GUIA"]));
    if(valid(r["PROFESOR COGUIA"])) set.add(clean(r["PROFESOR COGUIA"]));
  });
  return [...set];
}
function esDe(r, name){ return clean(r["PROFESOR GUIA"]) === name || clean(r["PROFESOR COGUIA"]) === name; }
function esDeRol(r, name, rol){ return clean(r[rol === 'coguia' ? "PROFESOR COGUIA" : "PROFESOR GUIA"]) === name; }

/* Programas: clave → patrón en la pregunta (ya normalizada, sin acentos). El orden importa: lo específico primero. */
const CHAT_PROGRAMAS = [
  ['msec', /\b(magister en seguridad|magister de seguridad|mestrado em seguranca|msc in security|master in security|master of security|peritaje|auditoria)\b/],
  ['minf', /\b(magister en (ingenieria )?informatica|mestrado em (engenharia )?informatica|msc in informatics|master in informatics|master of informatics)\b/],
  ['phd', /\b(doctorado|doutorado|phd|doctoral|doctorate|doctorales)\b/],
  ['exec', /\b(ingenieria de ejecucion|ing de ejecucion|ejecucion|execucao|execution)\b/],
  ['civil', /\b(ingenieria civil|ing civil|civil)\b/],
  ['mag', /\b(magister|mestrado|master|msc|maestria)\b/],
  ['posgrado', /\b(posgrado|postgrado|pos graduacao|posgraduacao|graduate|postgraduate)\b/],
  ['pregrado', /\b(pregrado|graduacao|undergraduate|undergrad)\b/]
];
function chatProgramaDe(r){
  const out = [];
  const pre = clean(r.PREGRADO).toLocaleUpperCase('es-CL'), pos = clean(r.POSGRADO).toLocaleUpperCase('es-CL');
  if(valid(r.PREGRADO)) out.push('pregrado');
  if(valid(r.POSGRADO)) out.push('posgrado');
  [pre, pos].forEach(n => {
    if(n.includes('EJECUCI')) out.push('exec');
    if(n.includes('CIVIL')) out.push('civil');
    if(n.includes('DOCTOR')) out.push('phd');
    if(n.includes('SEGURIDAD') || n.includes('PERITAJE') || n.includes('AUDITOR')) out.push('msec', 'mag');
    else if(n.includes('MAG')) out.push('minf', 'mag');
  });
  return [...new Set(out)];
}
function chatProgramaNombre(clave){ return cu().progNames[clave] || clave; }

/* Texto normalizado de cada fila, calculado una sola vez */
const CHAT_TEXTO = new WeakMap();
function chatTexto(r){
  let p = CHAT_TEXTO.get(r);
  if(p) return p;
  const n = chatNorm;
  p = {
    titulo: n(r.TITULO),
    claves: n(r.KEYWORDS),
    resumen: n(r.RESUMEN),
    areas: n([r.AREA_CONOCIMIENTO, r.AREA_APLICACION, r.AREA_SWEBOK].join(' ; ')),
    todo: n([r.TITULO, r.KEYWORDS, r.RESUMEN, r.AREA_CONOCIMIENTO, r.AREA_APLICACION, r.AREA_SWEBOK, r.ESTUDIANTE, r.PREGRADO, r.POSGRADO, r.MODALIDAD, r["PROFESOR GUIA"], r["PROFESOR COGUIA"]].join(' ; '))
  };
  CHAT_TEXTO.set(r, p);
  return p;
}
function chatOrden(a, b){ return (yearOf(b) || 0) - (yearOf(a) || 0) || clean(a.TITULO).localeCompare(clean(b.TITULO)); }

function chatKpis(){
  const rows = chatRows();
  const guides = new Set(); rows.forEach(r => { if(valid(r["PROFESOR GUIA"])) guides.add(clean(r["PROFESOR GUIA"])); });
  const programs = new Set(rows.flatMap(programsOf));
  const topArea = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 1)[0];
  return {total: rows.length, guides: guides.size, programs: programs.size, topArea};
}

/* ---------- piezas de respuesta ---------- */
function thesisCards(rows, limit = Infinity){
  const u = cu();
  const cap = Math.min(limit, 60);
  const list = rows.slice(0, cap);
  if(!list.length) return `<div class="chat-empty">${chatEsc(u.noWorks)}</div>`;
  return `<div class="chat-pubs">${list.map(r => {
    const link = tieneEnlace(r);
    const title = chatEsc(r.TITULO || "-");
    const area = cleanDomain(r.AREA_CONOCIMIENTO);
    const tags = [
      valid(r["PROFESOR GUIA"]) ? `${u.guide}: ${compactName(r["PROFESOR GUIA"])}` : "",
      valid(r["PROFESOR COGUIA"]) ? `${u.coguide}: ${compactName(r["PROFESOR COGUIA"])}` : "",
      area || ""
    ].filter(Boolean);
    return `<article class="chat-pub">
      <div class="chat-pub-title">${link ? `<a href="${chatEsc(r.ENLACE)}" target="_blank" rel="noopener">${title}</a>` : title}</div>
      <div class="chat-pub-meta">${chatEsc(yearOf(r) || "")} · ${chatEsc(programOf(r))} · ${chatEsc(compactName(r.ESTUDIANTE))}</div>
      <div class="chat-pub-tags">${tags.map(t => `<span>${chatEsc(t)}</span>`).join("")}</div>
    </article>`;
  }).join("")}${rows.length > list.length ? `<div class="chat-more">${chatEsc(u.more.replace('{n}', fmtK(rows.length - list.length)))}</div>` : ""}</div>`;
}

function miniBars(title, pairs){
  if(!pairs.length) return "";
  const max = Math.max(...pairs.map(p => p[1])) || 1;
  return `<div class="chat-bars"><b>${chatEsc(title)}</b>${pairs.map(([k,v]) => `
    <div class="chat-bar"><span class="chat-bar-l">${chatEsc(k)}</span><span class="chat-bar-track"><i style="width:${Math.max(6, v/max*100)}%"></i></span><span class="chat-bar-v">${fmtK(v)}</span></div>
  `).join("")}</div>`;
}
function kpiPills(items){
  return `<div class="chat-context chat-metrics">${items.filter(Boolean).map(([v, l, wide]) => `<div class="chat-kpi${wide ? ' wide' : ''}"><b>${chatEsc(v)}</b><span>${chatEsc(l)}</span></div>`).join('')}</div>`;
}

function answerHelp(){
  const k = chatKpis();
  return `<p>${tf("chat.greeting1", `Puedo explorar <b>${fmtK(k.total)}</b> trabajos de título con los filtros actuales.`, {n:fmtK(k.total)})}</p><p>${cu().greet2}</p>`;
}

function answerAreaDef(q){
  const nq = chatNorm(q);
  if(/\b(cuant\w*|how many|quant\w*|por ano|by year|top|ranking|quien|quienes|who|quem|compara\w*|compare|coguia\w*|co-guia\w*|coorient\w*|list\w*|muestra\w*|lista\w*)\b/.test(nq)) return null;
  let best = null, bestLen = 0;
  Object.keys(AREA_DEFS).forEach(key => {
    const k = chatNorm(key);
    if(nq.includes(k) && k.length > bestLen){ best = key; bestLen = k.length; }
  });
  if(!best){
    const hit = Object.keys(AREA_ALIAS).filter(a => new RegExp('\\b' + a + '\\b').test(nq)).sort((a,b) => b.length - a.length)[0];
    if(hit) best = AREA_ALIAS[hit];
  }
  if(!best) return /\b(define|definir|defina|definicion|significa|meaning|definition)\b/.test(nq) ? `<p>${cu().noDef}</p>` : null;
  const rows = chatRows();
  const inCon = countWhere(rows, r => chatNorm(cleanDomain(r.AREA_CONOCIMIENTO)) === chatNorm(best));
  const inSwe = countWhere(rows, r => chatNorm(cleanDomain(r.AREA_SWEBOK)) === chatNorm(best));
  const inApp = countWhere(rows, r => chatNorm(cleanDomain(r.AREA_APLICACION)) === chatNorm(best));
  const n = Math.max(inCon, inSwe, inApp);
  return `<p><b>${titleCase(best)}</b></p><p>${chatEsc(AREA_DEFS[best])}</p>${n ? `<p class="chat-hint">${chatEsc(cu().defCount.replace('{n}', fmtK(n)))}</p>` : ""}`;
}

function answerMetrics(rows, c){
  const u = cu();
  const years = rows.map(yearOf).filter(Boolean);
  const items = [];
  if(c.personas.length === 1){
    const name = c.personas[0];
    items.push([fmtK(rows.filter(r => clean(r["PROFESOR GUIA"]) === name).length), u.asGuide]);
    items.push([fmtK(rows.filter(r => clean(r["PROFESOR COGUIA"]) === name).length), u.asCoguide]);
  } else {
    items.push([fmtK(new Set(rows.map(r => clean(r["PROFESOR GUIA"])).filter(valid)).size), u.guides]);
  }
  items.push([years.length ? Math.min(...years) + '–' + Math.max(...years) : '-', u.period]);
  items.push([fmtK(new Set(rows.flatMap(programsOf)).size), u.programs]);
  items.push([fmtK(rows.filter(tieneEnlace).length), u.withLink]);
  const top = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 1)[0];
  if(top) items.push([top.name, u.topArea + ' (' + fmtK(top.value) + ')', true]);
  return kpiPills(items);
}

function answerShortSummary(rows, c){
  const u = cu();
  const years = rows.map(yearOf).filter(Boolean);
  const parts = [years.length ? Math.min(...years) + '–' + Math.max(...years) : '', fmtK(new Set(rows.flatMap(programsOf)).size) + ' ' + u.programs, fmtK(rows.filter(tieneEnlace).length) + ' ' + u.withLink];
  if(c.personas.length !== 1) parts.push(fmtK(new Set(rows.map(r => clean(r["PROFESOR GUIA"])).filter(valid)).size) + ' ' + u.guides);
  return `<p class="chat-note">${parts.filter(Boolean).map(chatEsc).join(' · ')}</p>` + thesisCards([...rows].sort(chatOrden), 5);
}

function answerCoauthors(rows, name){
  const u = cu();
  if(name){
    const partners = new Map();
    rows.forEach(r => {
      const g = clean(r["PROFESOR GUIA"]), c = clean(r["PROFESOR COGUIA"]);
      [g, c].forEach(p => { if(valid(p) && p !== name) partners.set(p, (partners.get(p)||0)+1); });
    });
    const pairs = [...partners.entries()].sort((a,b) => b[1]-a[1]).slice(0, 12).map(([k,v]) => [compactName(k), v]);
    if(!pairs.length) return `<p><b>${compactName(name)}</b> ${chatEsc(u.noPartners)}</p>`;
    return `<p>${chatEsc(u.partners)} <b>${compactName(name)}</b>:</p>${miniBars(u.partnersTitle, pairs)}`;
  }
  const pares = new Map();
  rows.forEach(r => {
    const g = clean(r["PROFESOR GUIA"]), c = clean(r["PROFESOR COGUIA"]);
    if(valid(g) && valid(c) && g !== c){ const k = [compactName(g), compactName(c)].sort().join(' + '); pares.set(k, (pares.get(k)||0)+1); }
  });
  const co = topCounts(rows, r => clean(r["PROFESOR COGUIA"]), 10).map(d => [compactName(d.name), d.value]);
  return miniBars(u.pairs, [...pares.entries()].sort((a,b) => b[1]-a[1]).slice(0, 12)) + miniBars(u.byCoguide, co);
}

function answerCompare(rows, a, b){
  const u = cu();
  const wa = rows.filter(r => esDe(r, a)), wb = rows.filter(r => esDe(r, b));
  const areaA = new Set(topCounts(wa, r => cleanDomain(r.AREA_CONOCIMIENTO), 20).map(d => d.name));
  const areaB = new Set(topCounts(wb, r => cleanDomain(r.AREA_CONOCIMIENTO), 20).map(d => d.name));
  const shared = [...areaA].filter(x => areaB.has(x));
  const onlyA = [...areaA].filter(x => !areaB.has(x));
  const onlyB = [...areaB].filter(x => !areaA.has(x));
  const ya = wa.map(yearOf).filter(Boolean), yb = wb.map(yearOf).filter(Boolean);
  const span = ys => ys.length ? Math.min(...ys) + '–' + Math.max(...ys) : '-';
  return `<p>${chatEsc(u.compare)}:</p>
    <div class="chat-cmp">
      <div><b>${compactName(a)}</b><span>${fmtK(wa.length)} ${chatEsc(u.works)} · ${span(ya)}</span></div>
      <div><b>${compactName(b)}</b><span>${fmtK(wb.length)} ${chatEsc(u.works)} · ${span(yb)}</span></div>
    </div>
    <p><b>${chatEsc(u.shared)}:</b> ${shared.length ? shared.map(chatEsc).join(", ") : "-"}</p>
    <p><b>${chatEsc(u.only)} ${compactName(a)}:</b> ${onlyA.length ? onlyA.slice(0,6).map(chatEsc).join(", ") : "-"}</p>
    <p><b>${chatEsc(u.only)} ${compactName(b)}:</b> ${onlyB.length ? onlyB.slice(0,6).map(chatEsc).join(", ") : "-"}</p>
    <p class="chat-hint">${u.hint}</p>`;
}

function answerTopAreas(rows){
  const u = cu();
  const con = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 8).map(d => [d.name, d.value]);
  const app = topCounts(rows, r => cleanDomain(r.AREA_APLICACION), 6).map(d => [d.name, d.value]);
  const swe = topCounts(rows, r => cleanDomain(r.AREA_SWEBOK), 6).map(d => [d.name, d.value]);
  const kw = new Map();
  rows.forEach(r => clean(r.KEYWORDS).split(/[,;]/).map(x => chatNorm(x)).filter(x => x.length > 2 && x !== 'na' && !Asistente.STOP.has(x)).forEach(x => kw.set(x, (kw.get(x)||0)+1)));
  const kws = [...kw.entries()].sort((a,b) => b[1]-a[1]).slice(0, 10);
  return miniBars(u.areasK, con) + miniBars(u.areasA, app) + miniBars(u.areasS, swe) + miniBars(u.keywords, kws);
}

function answerRanking(rows, c, limit){
  const u = cu();
  const g = topCounts(rows, r => clean(r["PROFESOR GUIA"]), limit).map(d => [compactName(d.name), d.value]);
  const co = topCounts(rows, r => clean(r["PROFESOR COGUIA"]), Math.min(limit, 8)).map(d => [compactName(d.name), d.value]);
  return miniBars(u.byGuide, g) + miniBars(u.byCoguide, co);
}

function answerEvolution(rows){
  const m = new Map();
  rows.forEach(r => { const y = yearOf(r); if(y) m.set(y, (m.get(y)||0)+1); });
  const years = [...m.keys()].sort((a,b) => a-b);
  return miniBars(cu().byYear, years.map(y => [String(y), m.get(y)]));
}

function answerPrograms(rows){
  return miniBars(cu().byProgram, topCounts(rows, programsOf, 12).map(d => [d.name, d.value]));
}

function answerSuggestions(){
  const u = cu();
  return `<p class="chat-note">${chatEsc(u.tryAlso)}: ${u.suggest.map(s => `<b>${chatEsc(s)}</b>`).join(' · ')}.</p>`;
}

/* ---------- el motor configurado para memorias ---------- */
function chatEngine(){
  if(ChatLocal.engine) return ChatLocal.engine;
  ChatLocal.engine = Asistente.crear({
    modulo: 'tesis',
    lang: () => (typeof MEM_LANG === 'string' ? MEM_LANG : 'es'),
    filas: chatRows,
    personas: chatAuthorList,
    nombre: compactName,
    dePersona: esDe,
    rolDe: esDeRol,
    anio: r => yearOf(r) || 0,
    programas: CHAT_PROGRAMAS,
    programaDe: chatProgramaDe,
    programaNombre: chatProgramaNombre,
    enlace: tieneEnlace,
    texto: chatTexto,
    orden: chatOrden,
    ayuda: answerHelp,
    definir: answerAreaDef,
    comparar: answerCompare,
    coautores: answerCoauthors,
    lista: (rows, limit) => thesisCards(rows, limit),
    ranking: answerRanking,
    temas: answerTopAreas,
    evolucion: answerEvolution,
    programasResumen: answerPrograms,
    metricas: answerMetrics,
    resumenCorto: answerShortSummary,
    sugerencias: answerSuggestions
  });
  return ChatLocal.engine;
}

function localAnswer(q){
  try { return chatEngine().responder(q); }
  catch(e){ console.error('asistente', e); return `<p>${chatEsc(cu().noWorks)}</p>`; }
}

function addChatMessage(role, html){
  const box = el("chat_messages");
  if(!box) return;
  const div = document.createElement("div");
  div.className = `chat-msg ${role}`;
  div.innerHTML = role === "user" ? `<div class="chat-bubble user">${chatEsc(html)}</div>` : `<div class="chat-bubble">${html}</div>`;
  box.appendChild(div);
  box.scrollTop = box.scrollHeight;
}

function renderChatContext(){
  const box = el("chat_context");
  if(!box) return;
  const k = chatKpis();
  box.innerHTML = `
    <div class="chat-kpi"><b>${fmtK(k.total)}</b><span>${tt("chat.kpi.works","trabajos filtrados")}</span></div>
    <div class="chat-kpi"><b>${fmtK(k.guides)}</b><span>${tt("chat.kpi.guiding","académicos(as) guiando")}</span></div>
    <div class="chat-kpi"><b>${fmtK(k.programs)}</b><span>${tt("chat.kpi.programs","programas")}</span></div>
    <div class="chat-kpi wide"><b>${chatEsc(k.topArea ? k.topArea.name : "-")}</b><span>${tt("chat.kpi.topArea","área más frecuente")}${k.topArea ? ` (${fmtK(k.topArea.value)})` : ""}</span></div>`;
  // Mientras no haya conversación, el saludo repite el total del filtro activo para que no quede desactualizado.
  const msgs = el("chat_messages");
  if(msgs && msgs.childElementCount && !ChatLocal.asked){ msgs.innerHTML = ""; addChatMessage("bot", answerHelp()); }
}

/* ============================================================
   EFECTO DE ESCRITURA PROGRESIVA (tipo GPT)
   ============================================================ */
function chatTypeInto(el, html, done){
  el.innerHTML = html;
  const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
  const nodes = []; let tn;
  while((tn = walker.nextNode())){
    if(!tn.nodeValue || !tn.nodeValue.trim()) continue;
    nodes.push({node:tn, full:tn.nodeValue}); tn.nodeValue = "";
  }
  const box = document.getElementById("chat_messages");
  let ni = 0, ci = 0, typed = 0; const CAP = 480;
  const revealRest = () => { for(let k=ni;k<nodes.length;k++) nodes[k].node.nodeValue = nodes[k].full; if(box) box.scrollTop = box.scrollHeight; if(done) done(); };
  const step = () => {
    if(ni >= nodes.length){ if(done) done(); return; }
    if(typed >= CAP){ revealRest(); return; }
    const cur = nodes[ni];
    cur.node.nodeValue = cur.full.slice(0, ci+1); ci++; typed++;
    if(ci >= cur.full.length){ ni++; ci = 0; }
    if(box) box.scrollTop = box.scrollHeight;
    setTimeout(step, 11);
  };
  step();
}


function buildChat(keepMessages){
  const box = el("chat_messages"), input = el("chat_input"), form = el("chat_form"), prompts = el("chat_prompts"), clear = el("chat_clear");
  if(!box || !input || !form || !prompts) return;

  renderChatContext();
  const quick = CHAT_PROMPTS[typeof MEM_LANG === 'string' ? MEM_LANG : 'es'] || CHAT_PROMPTS.es;
  prompts.innerHTML = quick.map(p => `<button type="button" class="prompt-chip" data-q="${chatEsc(p)}">${chatEsc(p)}</button>`).join("");
  prompts.querySelectorAll("button").forEach(b => b.onclick = () => { input.value = b.dataset.q; form.requestSubmit(); });

  if(!ChatLocal.wired){
    form.onsubmit = e => {
      e.preventDefault();
      const q = input.value.trim();
      if(!q) return;
      addChatMessage("user", q);
      input.value = "";
      ChatLocal.asked = true;
      const pending = document.createElement("div");
      pending.className = "chat-msg bot";
      pending.innerHTML = '<div class="chat-bubble"><span class="chat-typing"><i></i><i></i><i></i></span></div>';
      box.appendChild(pending); box.scrollTop = box.scrollHeight;
      const html = localAnswer(q);
      setTimeout(() => {
        const bubble = pending.querySelector(".chat-bubble");
        chatTypeInto(bubble, html, () => { box.scrollTop = box.scrollHeight; });
      }, 320);
    };
    ChatLocal.wired = true;
  }
  if(clear && !clear.dataset.wired){
    clear.onclick = () => { box.innerHTML = ""; ChatLocal.asked = false; addChatMessage("bot", answerHelp()); input.focus(); };
    clear.dataset.wired = "1";
  }
  if(!keepMessages || !ChatLocal.asked){
    box.innerHTML = "";
    addChatMessage("bot", answerHelp());
    ChatLocal.asked = false;
  }
}
