/* ============================================================
   PERFIL · tarjeta, guía/co-guía, sankey de áreas, red de
   coautorías y nube de palabras. Depende del núcleo (app.js).
   ============================================================ */
function currentProfileRows(){
  const selected = el("perf_academico").value;
  if(state.profileMode === "departamento") return state.filtered;
  return state.filtered.filter(r => clean(r["PROFESOR GUIA"]) === selected);
}

function renderProfileCard(rows){
  const selected = el("perf_academico").value;
  const total = rows.length;
  const pre = countWhere(rows, r => valid(r.PREGRADO));
  const pos = countWhere(rows, r => valid(r.POSGRADO));
  const co = state.profileMode === "academico" ? countWhere(state.filtered, r => clean(r["PROFESOR COGUIA"]) === selected) : countWhere(rows, r => valid(r["PROFESOR COGUIA"]));
  const info = state.academics.find(a => clean(a.ACADEMICO) === selected);
  const isDept = state.profileMode === "departamento";
  const img = isDept ? "../shared/img/tesis-chat.webp" : (info?.IMAGEN || "../shared/img/tesis-academica.webp");
  const name = isDept ? "Departamento de Ingeniería Informática" : compactName(selected);
  const mail = isDept ? "Trabajos de título del periodo activo" : clean(info?.CORREO || "Sin correo informado");

  el("profile_card").innerHTML = `
    <img class="profile-avatar" src="${img}" alt="${name}" onerror="this.src='../shared/img/tesis-academica.webp'">
    <div class="profile-name">${name}</div>
    <div class="profile-mail">${mail}</div>
    <div class="profile-stats">
      <div class="profile-stat"><b>${fmt(total)}</b><span>${tt("pstat.guided","Guiadas")}</span></div>
      <div class="profile-stat"><b>${fmt(co)}</b><span>${tt("pstat.coguia","Co-guías")}</span></div>
      <div class="profile-stat"><b>${fmt(pre)}</b><span>${tt("pstat.pre","Pregrado")}</span></div>
      <div class="profile-stat"><b>${fmt(pos)}</b><span>${tt("pstat.pos","Posgrado")}</span></div>
    </div>
  `;
}

function renderGuidePie(){
  const selected = el("perf_academico").value;
  if(state.profileMode !== "academico" || !selected){
    Plotly.react("perfil_guia_coguia", [], plotLayout({
      annotations: [{text:"Elige un académico(a) para ver guía/co-guía", showarrow:false, x:.5, y:.5, font:{size:16, color:C.gray}}],
      xaxis:{visible:false}, yaxis:{visible:false}
    }), plotConfig());
    return;
  }
  const guia = countWhere(state.filtered, r => clean(r["PROFESOR GUIA"]) === selected);
  const co = countWhere(state.filtered, r => clean(r["PROFESOR COGUIA"]) === selected);
  Plotly.react("perfil_guia_coguia", [{
    type: "pie",
    labels: ["Guía", "Co-guía"],
    values: [guia, co],
    hole: .55,
    marker: {colors: [C.purple, C.orange]},
    textinfo: "label+percent",
    hovertemplate: "%{label}<br>%{value} trabajos<extra></extra>"
  }], plotLayout({margin:{l:10,r:10,t:10,b:10}, showlegend:false}), plotConfig());
}

function renderSankey(rows){
  const links = new Map();
  const type = new Map(); // etiqueta -> 'prog' | 'esp' | 'apl'
  rows.forEach(row => {
    const esp = cleanDomain(row.AREA_CONOCIMIENTO) || "Sin área";
    const apl = cleanDomain(row.AREA_APLICACION) || "Sin aplicación";
    type.set(esp, "esp"); type.set(apl, "apl");
    // Una tesis puede pertenecer a varios programas (pregrado y posgrado): un flujo por cada uno.
    programsOf(row).forEach(p => {
      type.set(p, "prog");
      const k = `${p}|||${esp}`;
      links.set(k, (links.get(k) || 0) + 1);
    });
    const k2 = `${esp}|||${apl}`;
    links.set(k2, (links.get(k2) || 0) + 1);
  });
  // umbral adaptativo: en vistas pequeñas (un perfil) mostramos todo; en la vista amplia filtramos ruido
  const threshold = rows.length > 150 ? 2 : 1;
  const entries = [...links.entries()]
    .map(([key, value]) => { const [s,t] = key.split("|||"); return {s, t, value}; })
    .filter(d => d.value >= threshold)
    .sort((a,b) => b.value - a.value)
    .slice(0, 120);

  if(!entries.length){
    Plotly.react("perfil_sankey", [], plotLayout({margin:{l:10,r:10,t:10,b:10}}), plotConfig());
    return;
  }

  // solo los nodos que participan en enlaces visibles (evita nodos huérfanos)
  const idx = new Map();
  const order = [];
  const use = lbl => { if(!idx.has(lbl)){ idx.set(lbl, order.length); order.push(lbl); } return idx.get(lbl); };
  entries.forEach(d => { use(d.s); use(d.t); });

  const colorByType = {prog: C.purple, esp: C.orange, apl: C.teal};
  const xByType = {prog: 0.02, esp: 0.5, apl: 0.98};

  Plotly.react("perfil_sankey", [{
    type: "sankey",
    arrangement: "snap",
    node: {
      label: order,
      x: order.map(l => (xByType[type.get(l)] != null ? xByType[type.get(l)] : 0.5)),
      pad: 14,
      thickness: 12,
      line: {width: 0},
      color: order.map(l => colorByType[type.get(l)] || C.blue)
    },
    link: {
      source: entries.map(d => idx.get(d.s)),
      target: entries.map(d => idx.get(d.t)),
      value: entries.map(d => d.value),
      color: "rgba(140,71,153,.18)"
    }
  }], plotLayout({margin:{l:10,r:10,t:10,b:10}}), plotConfig());
}

function renderNetwork(rows){
  const nodeMap = new Map();
  const edges = new Map();
  const add = (name, group) => {
    if(!valid(name)) return null;
    const id = clean(name);
    if(!nodeMap.has(id)){
      nodeMap.set(id, {id, label: compactName(id), group, value: 1});
    } else {
      nodeMap.get(id).value += 1;
    }
    return id;
  };
  rows.forEach(row => {
    const g = add(row["PROFESOR GUIA"], "guia");
    const c = add(row["PROFESOR COGUIA"], "coguia");
    if(g && c && g !== c){
      const key = [g,c].sort().join("|||");
      edges.set(key, (edges.get(key) || 0) + 1);
    }
  });
  const nodes = [...nodeMap.values()].sort((a,b) => b.value - a.value).slice(0, 70);
  const keep = new Set(nodes.map(n => n.id));
  const edgeRows = [...edges.entries()].map(([key,value]) => {
    const [from,to] = key.split("|||");
    return {from, to, value, title: `${compactName(from)} ↔ ${compactName(to)} · ${value} ${tt("network.coguiaWorks","en co-guía")}`,
            width: Math.min(1 + value, 8), color: {color:"rgba(140,71,153,.32)"}};
  }).filter(e => keep.has(e.from) && keep.has(e.to)).slice(0, 120);

  const container = el("perfil_red");
  if(state.network){ try { state.network.destroy(); } catch(e){} state.network = null; }
  container.innerHTML = "";
  const data = {
    nodes: new vis.DataSet(nodes.map(n => ({
      ...n,
      shape: "dot",
      size: Math.min(10 + n.value * 2, 34),
      title: `${n.label} · ${n.value} ${tt("network.works","trabajos")}`,
      color: n.group === "guia" ? C.purple : C.orange,
      font: {face: "Inter", color: C.gray}
    }))),
    edges: new vis.DataSet(edgeRows)
  };
  state.network = new vis.Network(container, data, {
    interaction: {hover: true, tooltipDelay: 80},
    physics: {stabilization: true, barnesHut: {gravitationalConstant: -6200, springLength: 150}},
    edges: {smooth: {type: "dynamic"}}
  });
  // Clic en nodo o arista -> muestra la frecuencia en la barra de estado
  state.network.on("click", p => {
    const st = el("red_search_status"); if(!st) return;
    if(p.nodes && p.nodes.length){
      const nd = data.nodes.get(p.nodes[0]);
      if(nd) st.textContent = `${nd.label} · ${fmt(nd.value)} ${tt("network.works","trabajos")}`;
    } else if(p.edges && p.edges.length){
      const ed = data.edges.get(p.edges[0]);
      if(ed){ const a = data.nodes.get(ed.from), b = data.nodes.get(ed.to);
        st.textContent = `${a ? a.label : ed.from} ↔ ${b ? b.label : ed.to} · ${fmt(ed.value)} ${tt("network.coguiaWorks","trabajos en co-guía")}`; }
    }
  });
  wireNetworkSearch(nodes);
}

function wireNetworkSearch(nodes){
  const select = el("red_select"), btn = el("red_search_btn"), clear = el("red_clear_btn"), status = el("red_search_status");
  if(!select || !btn || !clear || !state.network) return;
  const items = nodes.slice().sort((a, b) => String(a.label).localeCompare(String(b.label), "es"));
  const escA = s => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  const ph = (typeof T === "function") ? T("network.placeholder") : "Selecciona académico(a)...";
  select.innerHTML = `<option value="">${ph}</option>` + items.map(n => `<option value="${escA(n.id)}">${escA(n.label)}</option>`).join("");
  const setStatus = m => { if(status) status.textContent = m || ""; };
  const focusNode = () => {
    const id = select.value;
    if(!id){ setStatus(""); state.network.unselectAll(); return; }
    const hit = items.find(x => String(x.id) === String(id));
    if(!hit){ state.network.unselectAll(); setStatus(""); return; }
    state.network.selectNodes([hit.id]);
    state.network.focus(hit.id, {scale: 1.4, animation: {duration: 620, easingFunction: "easeInOutQuad"}});
    setStatus(hit.label);
  };
  btn.onclick = focusNode;
  select.onchange = focusNode;
  clear.onclick = () => { select.value = ""; setStatus(""); state.network.unselectAll(); state.network.fit({animation: {duration: 480, easingFunction: "easeInOutQuad"}}); };
}

const KW_STOP = new Set(("de la el los las y en para con del un una por a al o u e su sus lo le les " +
  "que se como más mas este esta estos estas ese esa entre sobre desde hasta cada según segun " +
  "sistema sistemas desarrollo desarrollar implementacion implementación analisis análisis diseño diseno " +
  "aplicado aplicada aplicacion aplicación basada basado basado usando mediante través traves partir " +
  "trabajo titulo título memoria proyecto herramienta modelo modelos metodo método metodos métodos " +
  "propuesta caso casos estudio general nueva nuevo actual proceso procesos tipo tipos parte partes " +
  "the and for with this that from into their using based approach study analysis system model data " +
  "etc chile empresa area área datos uso apoyo tesis").split(/\s+/));

function keywordCounts(rows){
  const counts = new Map();
  const bump = raw => {
    let w = clean(raw).toLocaleLowerCase("es-CL").replace(/^[\s\-·]+|[\s\-·]+$/g, "");
    if(!w) return;
    const bare = w.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    if(bare.length < 4 || KW_STOP.has(bare) || /^\d+$/.test(bare)) return;
    counts.set(w, (counts.get(w) || 0) + 1);
  };
  rows.forEach(row => {
    const kw = clean(row.KEYWORDS);
    if(valid(kw)) kw.split(/[,;/]+/).forEach(bump);            // términos ya listados
    clean(row.TITULO).split(/[^a-zA-ZñÑáéíóúüÁÉÍÓÚÜ]+/).forEach(bump); // + palabras del título
  });
  return [...counts.entries()]
    .map(([text, weight]) => ({text: titleCase(text), weight}))
    .sort((a, b) => b.weight - a.weight || a.text.localeCompare(b.text))
    .slice(0, 90);
}

function renderKeywords(rows){
  WordCloud.render(el("perfil_keywords"), keywordCounts(rows), {
    family: "Inter, sans-serif",
    minHeight: 460,
    colors: [C.purple, C.orange, C.teal, C.blue, C.purpleDark]
  });
}

function renderProfile(){
  el("perf_academico_box").style.display = state.profileMode === "academico" ? "" : "none";
  const rows = currentProfileRows();
  renderProfileCard(rows);
  renderAnnualChart("perfil_anios", rows);
  renderBar("perfil_programas", rows, programsOf, "h", 10, shortProgram);
  renderGuidePie();
  renderSankey(rows);
  renderNetwork(state.profileMode === "academico" ? state.filtered.filter(r => clean(r["PROFESOR GUIA"]) === el("perf_academico").value || clean(r["PROFESOR COGUIA"]) === el("perf_academico").value) : state.filtered);
  renderKeywords(rows);
}

