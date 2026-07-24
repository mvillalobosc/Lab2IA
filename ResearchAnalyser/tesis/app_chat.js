/* ============================================================
   Asistente Leo USACH · chat local sin API ni servidor.
   Responde con reglas y búsquedas sobre la base filtrada de
   memorias (state.filtered). Todo se calcula en el navegador.
   ============================================================ */
const ChatLocal = { wired: false, asked: false };

const CHAT_PROMPTS = [
  "Muéstrame todas las tesis sobre inteligencia artificial",
  "¿Quiénes son los guías con más trabajos?",
  "¿Cuáles son las áreas más frecuentes?",
  "Trabajos guiados por Bonacic",
  "Compara a Bonacic con Parada",
  "Memorias de 2023",
  "Co-guías de Villalobos",
  "¿Qué es Software Design?"
];

const AREA_DEFS = {
  "software engineering": "Ingeniería de software: organiza el desarrollo como proceso — requisitos, arquitectura, diseño, pruebas, mantenimiento, calidad y evolución de sistemas.",
  "software development fundamentals": "Fundamentos de desarrollo de software: programación, diseño básico, pruebas, depuración, control de versiones y buenas prácticas.",
  "software design": "Diseño de software (SWEBOK): estructura interna del software, patrones, descomposición en módulos y decisiones de arquitectura de bajo nivel.",
  "software requirements": "Requisitos de software (SWEBOK): elicitación, análisis, especificación y validación de lo que el sistema debe hacer.",
  "software architecture": "Arquitectura de software (SWEBOK): organización de alto nivel del sistema, componentes, conectores y atributos de calidad.",
  "software testing": "Pruebas de software (SWEBOK): técnicas para verificar y validar el software y detectar defectos.",
  "software engineering models and methods": "Modelos y métodos de ingeniería de software (SWEBOK): modelado, metodologías y técnicas sistemáticas de desarrollo.",
  "research/investigation": "Investigación: trabajos con foco en método científico, experimentación o generación de conocimiento nuevo.",
  "artificial intelligence": "Inteligencia artificial: sistemas que aprenden, razonan, predicen o deciden a partir de datos, reglas o modelos. Incluye aprendizaje automático, visión y lenguaje natural.",
  "algorithms and complexity": "Algoritmos y complejidad: métodos para resolver problemas y cuántos recursos (tiempo, memoria) requieren; escalabilidad de las soluciones.",
  "specialized platform development": "Desarrollo de plataformas especializadas: sistemas embebidos, móviles, web, cloud, IoT o entornos de ejecución específicos.",
  "security": "Seguridad: protección de sistemas, datos y comunicaciones frente a accesos no autorizados, ataques y vulnerabilidades.",
  "data management": "Gestión de datos: almacenar, organizar, consultar, integrar y gobernar datos; bases de datos y grandes volúmenes.",
  "human-computer interaction": "Interacción humano-computador: usabilidad, experiencia de usuario, accesibilidad, interfaces y evaluación con personas.",
  "networking and communication": "Redes y comunicación: protocolos, transmisión de datos, conectividad, rendimiento y seguridad de la comunicación digital.",
  "computer science": "Ciencias de la computación: campo general de aplicación cuando el trabajo es propiamente computacional y no de otra disciplina."
};

function chatEsc(s){ return clean(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c])); }
function chatNorm(s){ return clean(s).toLocaleLowerCase("es-CL").normalize("NFD").replace(/[\u0300-\u036f]/g,""); }
function chatRows(){ return state.filtered; }

const CHAT_STOP = new Set(("de del la los las un una y en para con por a al o que se como mas más " +
  "profesor profesora profesores academico académico academica académica guia guía guias guías coguia coguía " +
  "co-guia co-guía cotutor trabajo trabajos memoria memorias tesis dirigida dirigidas dirigido dirigidos " +
  "guiada guiadas guiado guiados compara comparar comparacion comparación versus vs contra entre coautor " +
  "coautores tema temas area área areas áreas sobre acerca busca buscar muestra listar dame quien quién " +
  "cuantas cuántas cuantos cuántos hay son define definir significa el año anio muestrame muéstrame muestra mostrar ver quiero necesito dame todas todos toda todo all completa completo completas completos lista listar").split(/\s+/));

function chatAuthorList(){
  const set = new Set();
  state.data.forEach(r => {
    if(valid(r["PROFESOR GUIA"])) set.add(clean(r["PROFESOR GUIA"]));
    if(valid(r["PROFESOR COGUIA"])) set.add(clean(r["PROFESOR COGUIA"]));
  });
  return [...set];
}
function chatNameTokens(q){
  return chatNorm(q).split(/\s+/).filter(t => t.length > 2 && !CHAT_STOP.has(t) && !/^\d+$/.test(t));
}
function chatMatchAll(q){ // autores que contienen TODOS los tokens de nombre
  const toks = chatNameTokens(q);
  if(!toks.length) return [];
  return chatAuthorList().filter(a => {
    const na = chatNorm(a).split(/\s+/);
    return toks.every(t => na.some(w => w.startsWith(t)));
  });
}
function chatCandidates(q){ // autores rankeados por nº de tokens coincidentes
  const toks = chatNameTokens(q);
  if(!toks.length) return [];
  return chatAuthorList().map(a => {
    const na = chatNorm(a).split(/\s+/);
    const hits = toks.filter(t => na.some(w => w.startsWith(t))).length;
    return {a, hits};
  }).filter(x => x.hits > 0).sort((x,y) => y.hits - x.hits).map(x => x.a);
}
function chatCompareTargets(q){
  const parts = chatNorm(q).split(/\bcon\b|\bvs\.?\b|\bcontra\b|\bversus\b|\by\b/).map(p => p.trim()).filter(Boolean);
  let picks = [];
  parts.forEach(p => { const m = chatMatchAll(p)[0] || chatCandidates(p)[0]; if(m && !picks.includes(m)) picks.push(m); });
  if(picks.length < 2){ picks = chatCandidates(q).slice(0, 2); }
  return picks.slice(0, 2);
}

function worksOf(name){
  const rows = chatRows();
  return {
    guiadas: rows.filter(r => clean(r["PROFESOR GUIA"]) === name),
    coguiadas: rows.filter(r => clean(r["PROFESOR COGUIA"]) === name),
    all: rows.filter(r => clean(r["PROFESOR GUIA"]) === name || clean(r["PROFESOR COGUIA"]) === name)
  };
}

function chatKpis(){
  const rows = chatRows();
  const guides = new Set(); rows.forEach(r => { if(valid(r["PROFESOR GUIA"])) guides.add(clean(r["PROFESOR GUIA"])); });
  const programs = new Set(rows.flatMap(programsOf));
  const topArea = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 1)[0];
  return {total: rows.length, guides: guides.size, programs: programs.size, topArea};
}

function thesisCards(rows, limit = Infinity){
  const list = rows.slice(0, limit);
  if(!list.length) return `<div class="chat-empty">No encontré trabajos para esa consulta con los filtros actuales.</div>`;
  return `<div class="chat-pubs">${list.map(r => {
    const link = valid(r.ENLACE);
    const title = chatEsc(r.TITULO || "—");
    const area = cleanDomain(r.AREA_CONOCIMIENTO);
    const tags = [
      valid(r["PROFESOR GUIA"]) ? `Guía: ${compactName(r["PROFESOR GUIA"])}` : "",
      valid(r["PROFESOR COGUIA"]) ? `Co-guía: ${compactName(r["PROFESOR COGUIA"])}` : "",
      area || ""
    ].filter(Boolean);
    return `<article class="chat-pub">
      <div class="chat-pub-title">${link ? `<a href="${chatEsc(r.ENLACE)}" target="_blank" rel="noopener">${title}</a>` : title}</div>
      <div class="chat-pub-meta">${chatEsc(yearOf(r) || "")} · ${chatEsc(programOf(r))} · ${chatEsc(compactName(r.ESTUDIANTE))}</div>
      <div class="chat-pub-tags">${tags.map(t => `<span>${chatEsc(t)}</span>`).join("")}</div>
    </article>`;
  }).join("")}${rows.length > limit ? `<div class="chat-more">…y ${fmt(rows.length - limit)} trabajos más con los filtros actuales.</div>` : ""}</div>`;
}

function miniBars(title, pairs){
  if(!pairs.length) return "";
  const max = Math.max(...pairs.map(p => p[1])) || 1;
  return `<div class="chat-bars"><b>${chatEsc(title)}</b>${pairs.map(([k,v]) => `
    <div class="chat-bar"><span class="chat-bar-l">${chatEsc(k)}</span><span class="chat-bar-track"><i style="width:${Math.max(6, v/max*100)}%"></i></span><span class="chat-bar-v">${fmt(v)}</span></div>
  `).join("")}</div>`;
}

function answerHelp(){
  const k = chatKpis();
  return `<p>${tf("chat.greeting1", `Hola, soy <b>Leo USACH</b> 🦁. Puedo explorar <b>${fmt(k.total)}</b> trabajos de título con los filtros actuales.`, {n:fmt(k.total)})}</p>
  <p>${tt("chat.greeting2", "Pregúntame por: <b>trabajos guiados por un académico(a)</b>, <b>co-guías de alguien</b>, <b>memorias sobre un tema</b>, <b>áreas más frecuentes</b>, <b>guías con más trabajos</b>, <b>memorias de un año</b>, <b>comparar dos académicos(as)</b> o <b>qué significa un área</b>.")}</p>`;
}

function answerAuthor(name){
  const w = worksOf(name);
  if(!w.all.length) return `<p>No encontré trabajos de <b>${compactName(name)}</b> con los filtros actuales (prueba ampliar el periodo o el programa).</p>`;
  const areas = topCounts(w.all, r => cleanDomain(r.AREA_CONOCIMIENTO), 5).map(d => [d.name, d.value]);
  return `<p><b>${compactName(name)}</b> — ${fmt(w.guiadas.length)} como guía y ${fmt(w.coguiadas.length)} como co-guía con los filtros actuales (${fmt(w.all.length)} en total).</p>
    ${miniBars("Áreas de conocimiento", areas)}
    ${thesisCards(w.all)}`;
}

function answerCoauthors(name){
  const w = worksOf(name);
  if(!w.all.length) return `<p>No tengo trabajos de <b>${compactName(name)}</b> con los filtros actuales.</p>`;
  const partners = new Map();
  w.all.forEach(r => {
    const g = clean(r["PROFESOR GUIA"]), c = clean(r["PROFESOR COGUIA"]);
    [g, c].forEach(p => { if(valid(p) && p !== name) partners.set(p, (partners.get(p)||0)+1); });
  });
  const pairs = [...partners.entries()].sort((a,b) => b[1]-a[1]).slice(0, 10).map(([k,v]) => [compactName(k), v]);
  if(!pairs.length) return `<p><b>${compactName(name)}</b> no registra guía/co-guía compartida con otra persona con los filtros actuales.</p>`;
  return `<p>Personas que han compartido guía o co-guía con <b>${compactName(name)}</b>:</p>${miniBars("Colaboraciones", pairs)}`;
}

function answerCompare(a, b){
  const wa = worksOf(a).all, wb = worksOf(b).all;
  const areaA = new Set(topCounts(wa, r => cleanDomain(r.AREA_CONOCIMIENTO), 20).map(d => d.name));
  const areaB = new Set(topCounts(wb, r => cleanDomain(r.AREA_CONOCIMIENTO), 20).map(d => d.name));
  const shared = [...areaA].filter(x => areaB.has(x));
  const onlyA = [...areaA].filter(x => !areaB.has(x));
  const onlyB = [...areaB].filter(x => !areaA.has(x));
  return `<p>Comparación con los filtros actuales:</p>
    <div class="chat-cmp">
      <div><b>${compactName(a)}</b><span>${fmt(wa.length)} trabajos</span></div>
      <div><b>${compactName(b)}</b><span>${fmt(wb.length)} trabajos</span></div>
    </div>
    <p><b>Áreas en común:</b> ${shared.length ? shared.map(chatEsc).join(", ") : "—"}</p>
    <p><b>Sólo ${compactName(a)}:</b> ${onlyA.length ? onlyA.slice(0,6).map(chatEsc).join(", ") : "—"}</p>
    <p><b>Sólo ${compactName(b)}:</b> ${onlyB.length ? onlyB.slice(0,6).map(chatEsc).join(", ") : "—"}</p>
    <p class="chat-hint">Para el detalle estadístico (χ² y residuos) usa el comparador en la pestaña <b>Perfiles</b>.</p>`;
}

function answerTopAreas(){
  const rows = chatRows();
  const con = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 8).map(d => [d.name, d.value]);
  const app = topCounts(rows, r => cleanDomain(r.AREA_APLICACION), 6).map(d => [d.name, d.value]);
  const swe = topCounts(rows, r => cleanDomain(r.AREA_SWEBOK), 6).map(d => [d.name, d.value]);
  return `${miniBars("Áreas de conocimiento", con)}${miniBars("Áreas de aplicación", app)}${miniBars("Áreas del SWEBOK", swe)}`;
}

function answerTopGuides(){
  const pairs = topCounts(chatRows(), r => clean(r["PROFESOR GUIA"]), 12).map(d => [compactName(d.name), d.value]);
  if(!pairs.length) return `<p>No hay guías con los filtros actuales.</p>`;
  return `<p>Guías con más trabajos dirigidos con los filtros actuales:</p>${miniBars("Trabajos dirigidos", pairs)}`;
}

function answerByYear(q){
  const m = chatNorm(q).match(/\b(20\d{2})\b/);
  if(!m) return null;
  const year = Number(m[1]);
  const rows = chatRows().filter(r => yearOf(r) === year);
  return `<p><b>${fmt(rows.length)}</b> trabajos de título del año <b>${year}</b> con los filtros actuales.</p>${thesisCards(rows)}`;
}

function answerAreaDef(q){
  const nq = chatNorm(q);
  let best = null, bestLen = 0;
  Object.keys(AREA_DEFS).forEach(key => {
    if(nq.includes(chatNorm(key)) && key.length > bestLen){ best = key; bestLen = key.length; }
  });
  if(!best){
    // intenta por palabra suelta del área (p.ej. "seguridad", "diseño")
    const alias = {seguridad:"security", diseno:"software design", diseño:"software design", pruebas:"software testing", requisitos:"software requirements", arquitectura:"software architecture", inteligencia:"artificial intelligence", ia:"artificial intelligence", datos:"data management", redes:"networking and communication", algoritmos:"algorithms and complexity", investigacion:"research/investigation"};
    for(const k in alias){ if(nq.includes(k)){ best = alias[k]; break; } }
  }
  if(!best) return `<p>No tengo una definición para eso. Puedo definir áreas como <b>Software Design</b>, <b>Software Engineering</b>, <b>Artificial Intelligence</b>, <b>Security</b>, <b>Algorithms and Complexity</b> o <b>Research/Investigation</b>.</p>`;
  const rows = chatRows();
  const inCon = countWhere(rows, r => chatNorm(cleanDomain(r.AREA_CONOCIMIENTO)) === chatNorm(best));
  const inSwe = countWhere(rows, r => chatNorm(cleanDomain(r.AREA_SWEBOK)) === chatNorm(best));
  const n = Math.max(inCon, inSwe);
  return `<p><b>${titleCase(best)}</b></p><p>${chatEsc(AREA_DEFS[best])}</p>${n ? `<p class="chat-hint">Con los filtros actuales hay ${fmt(n)} trabajos asociados a esta área.</p>` : ""}`;
}

function answerSearch(q){
  const toks = chatNorm(q).split(/\s+/).filter(t => t.length > 2 && !CHAT_STOP.has(t));
  if(!toks.length) return answerHelp();
  const rows = chatRows().filter(r => {
    const text = chatNorm([r.TITULO, r.KEYWORDS, r.RESUMEN, r.AREA_CONOCIMIENTO, r.AREA_APLICACION, r.AREA_SWEBOK, r.ESTUDIANTE].join(" "));
    return toks.every(t => text.includes(t));
  }).sort((a,b) => (yearOf(b)||0) - (yearOf(a)||0));
  return `<p>Encontré <b>${fmt(rows.length)}</b> trabajos que mencionan <b>${chatEsc(toks.join(" "))}</b> con los filtros actuales.</p>${thesisCards(rows)}`;
}

function localAnswer(q){
  const nq = chatNorm(q);
  if(!nq || /\b(ayuda|hola|buenas|que puedes|como funciona|help)\b/.test(nq)) return answerHelp();

  const compareIntent = /\b(compara|comparar|comparacion|versus|vs|contra)\b/.test(nq);
  const defIntent = /\b(define|definir|definicion|que es|qué es|significa)\b/.test(nq);
  const authorsAll = chatMatchAll(q);

  if(compareIntent){
    const t = chatCompareTargets(q);
    if(t.length >= 2) return answerCompare(t[0], t[1]);
    if(t.length === 1) return `<p>Reconocí a <b>${compactName(t[0])}</b>, pero necesito una segunda persona que esté en la base para comparar. Por ejemplo: “compara a ${compactName(t[0]).split(" ")[0]} con Parada”.</p>`;
    return `<p>Para comparar necesito dos apellidos presentes en la base. Ejemplo: “compara a Bonacic con Parada”. Para el detalle estadístico usa el comparador en la pestaña <b>Perfiles</b>.</p>`;
  }
  if(defIntent) return answerAreaDef(q);
  if(/\b(coguia|co-guia|coguias|co-guias|coautor|coautores|colabora|colaboracion)\b/.test(nq)){
    const a = authorsAll[0] || chatCandidates(q)[0];
    if(a) return answerCoauthors(a);
  }
  if(/\b(20\d{2})\b/.test(nq) && /\b(memoria|memorias|trabajo|trabajos|tesis|año|anio)\b/.test(nq)){
    const r = answerByYear(q); if(r) return r;
  }
  if(/\b(area|areas|tema|temas|dominio|dominios)\b/.test(nq) && !authorsAll.length) return answerTopAreas();
  if(/\b(guia|guias|productiv|ranking|dirige|dirigen|dirigido)\b/.test(nq) && !authorsAll.length) return answerTopGuides();

  if(authorsAll.length === 1) return answerAuthor(authorsAll[0]);
  if(authorsAll.length > 1){
    return `<p>Encontré varias personas: ${authorsAll.slice(0,6).map(a => `<b>${compactName(a)}</b>`).join(", ")}. ¿A cuál te refieres?</p>`;
  }
  // sin autor claro: si hay término de tema, busca; si no, ayuda
  if(chatNameTokens(q).length) return answerSearch(q);
  return answerHelp();
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
    <div class="chat-kpi"><b>${fmt(k.total)}</b><span>${tt("chat.kpi.works","trabajos filtrados")}</span></div>
    <div class="chat-kpi"><b>${fmt(k.guides)}</b><span>${tt("chat.kpi.guiding","académicos(as) guiando")}</span></div>
    <div class="chat-kpi"><b>${fmt(k.programs)}</b><span>${tt("chat.kpi.programs","programas")}</span></div>
    <div class="chat-kpi wide"><b>${chatEsc(k.topArea ? k.topArea.name : "—")}</b><span>${tt("chat.kpi.topArea","área más frecuente")}${k.topArea ? ` (${fmt(k.topArea.value)})` : ""}</span></div>`;
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
  prompts.innerHTML = CHAT_PROMPTS.map(p => `<button type="button" class="prompt-chip" data-q="${chatEsc(p)}">${chatEsc(p)}</button>`).join("");
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
