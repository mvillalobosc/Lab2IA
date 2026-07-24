/* ============================================================
   VISTAS · Resumen (tarjetas/gráficos), Indicadores
   (institucionales y por académico), Dominio, Registro y el
   orquestador renderAll(). Depende del núcleo (app.js).
   ============================================================ */
function renderSummaryCards(){
  const rows = state.filtered;
  const total = rows.length;
  const pre = countWhere(rows, r => PREGRADO.includes(clean(r.PREGRADO)));
  const pos = countWhere(rows, r => POSGRADO.includes(clean(r.POSGRADO)));
  const coguia = countWhere(rows, r => valid(r["PROFESOR COGUIA"]));
  const topYear = topCounts(rows, r => yearOf(r)?.toString(), 1)[0];
  const topGuide = topCounts(rows, r => clean(r["PROFESOR GUIA"]), 1)[0];
  const topArea = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 1)[0];

  const S = k => tt("card.sub."+k, {period:"Periodo",works:"trabajos",noData:"Sin datos",ofFilter:"con filtros actuales"}[k]);
  const cards = [
    {k:tt("card.works","Trabajos de título"), h:"card.works", v:fmt(total), s:`${S("period")} ${state.years[0]}-${state.years[1]}`, icon:"fa-file-lines", cls:""},
    {k:tt("card.pre","Pregrado"), h:"card.pre", v:fmt(pre), s:`${pct(percent(pre,total))} ${S("ofFilter")}`, icon:"fa-user-graduate", cls:"teal"},
    {k:tt("card.pos","Posgrado"), h:"card.pos", v:fmt(pos), s:`${pct(percent(pos,total))} ${S("ofFilter")}`, icon:"fa-building-columns", cls:"orange"},
    {k:tt("card.coguia","Con co-guía"), h:"card.coguia", v:fmt(coguia), s:`${pct(percent(coguia,total))} ${S("ofFilter")}`, icon:"fa-people-arrows", cls:""},
    {k:tt("card.topYear","Año más activo"), h:"card.topYear", v:topYear ? topYear.name : "—", s:topYear ? `${fmt(topYear.value)} ${S("works")}` : S("noData"), icon:"fa-calendar-days", cls:"teal"},
    {k:tt("card.topGuide","Guía con más trabajos"), h:"card.topGuide", v:topGuide ? fmt(topGuide.value) : "—", s:topGuide ? compactName(topGuide.name) : S("noData"), icon:"fa-chalkboard-user", cls:"orange"},
    {k:tt("card.topArea","Área dominante"), h:"card.topArea", v:topArea ? fmt(topArea.value) : "—", s:topArea ? topArea.name : S("noData"), icon:"fa-diagram-project", cls:""},
  ];

  el("summary_cards").innerHTML = cards.map(c => `
    <article class="metric ${c.cls}" data-help="${c.h}">
      <div class="m-icon"><i class="fa-solid ${c.icon}"></i></div>
      <div class="m-k">${c.k}</div>
      <div class="m-v">${c.v}</div>
      <div class="m-s">${c.s}</div>
    </article>
  `).join("");
}

function renderAnnualChart(target, rows){
  const counts = topCounts(rows, r => yearOf(r)?.toString(), 100).sort((a,b) => Number(a.name) - Number(b.name));
  Plotly.react(target, [{
    type: "bar",
    x: counts.map(d => d.name),
    y: counts.map(d => d.value),
    marker: {color: C.purple, line: {color: C.purpleDark, width: 1}},
    hovertemplate: "Año %{x}<br>%{y} trabajos<extra></extra>"
  }], plotLayout({
    margin: {l: 46, r: 16, t: 16, b: 46},
    yaxis: {gridcolor: "#F0EAF3", title: "Trabajos", rangemode: "tozero"},
    xaxis: {gridcolor: "#F0EAF3", title: ""}
  }), plotConfig());
}

function renderBar(target, rows, accessor, orientation = "h", limit = 10, labelFn = null){
  const counts = topCounts(rows, accessor, limit).reverse();
  const full = counts.map(d => d.name);
  const labels = labelFn ? full.map(labelFn) : full;
  Plotly.react(target, [{
    type: "bar",
    orientation,
    x: counts.map(d => d.value),
    y: labels,
    customdata: full,
    marker: {color: counts.map((_,i) => i % 2 ? C.orange : C.purple)},
    hovertemplate: "%{customdata}<br>%{x} " + tt("chart.works", "trabajos") + "<extra></extra>"
  }], plotLayout({
    margin: {l: labelFn ? 150 : 160, r: 20, t: 16, b: 42},
    xaxis: {gridcolor: "#F0EAF3", rangemode: "tozero"},
    yaxis: {gridcolor: "rgba(0,0,0,0)", automargin: true}
  }), plotConfig());
}

function renderSummaryCharts(){
  renderAnnualChart("chart_anios", state.filtered);
  renderBar("chart_programas", state.filtered, programsOf, "h", 10, shortProgram);
  renderBar("chart_area_conocimiento", state.filtered, r => cleanDomain(r.AREA_CONOCIMIENTO), "h", 10);
  renderBar("chart_area_aplicacion", state.filtered, r => cleanDomain(r.AREA_APLICACION), "h", 10);
}

function indicatorRows(){
  const rows = state.filtered;
  const totalHist = state.data.length;
  const total = rows.length;
    const pre = rows.filter(r => valid(r.PREGRADO));
    const pos = rows.filter(r => valid(r.POSGRADO));
    const coguia = rows.filter(r => valid(r["PROFESOR COGUIA"]));
    const values = [
      ["TT", "Total de trabajos de título", total],
      ["TTpre", "Total de trabajos de título de pregrado", pre.length],
      ["TTC", "Total de trabajos de Ingeniería Civil en Informática", countWhere(rows, r => clean(r.PREGRADO) === "INGENIERÍA CIVIL EN INFORMÁTICA")],
      ["TTE", "Total de trabajos de Ingeniería de Ejecución en Computación e Informática", countWhere(rows, r => clean(r.PREGRADO) === "INGENIERÍA DE EJECUCIÓN EN COMPUTACIÓN E INFORMÁTICA")],
      ["TTpos", "Total de trabajos de título de posgrado", pos.length],
      ["TTmgi", "Total de trabajos de Magíster en Ingeniería Informática", countWhere(rows, r => clean(r.POSGRADO) === "MAGÍSTER EN INGENIERÍA INFORMÁTICA")],
      ["TTmgc", "Total de trabajos de Magíster en Seguridad, Peritaje y Auditoría en Procesos Informáticos", countWhere(rows, r => clean(r.POSGRADO) === "MAGÍSTER EN SEGURIDAD, PERITAJE Y AUDITORÍA EN PROCESOS INFORMÁTICOS")],
      ["TTdoc", "Total de trabajos de Doctorado en Ciencias de la Ingeniería, mención Ingeniería Informática", countWhere(rows, r => clean(r.POSGRADO) === "DOCTORADO EN CIENCIAS DE LA INGENIERÍA, MENCIÓN INGENIERÍA INFORMÁTICA")],
      ["TTCG", "Total de trabajos de título con profesores co-guía", coguia.length]
    ];
    const base = values.map(([ind, desc, n]) => ({Indicador: ind, Descripción: desc, Cantidad: n, "Participación (%)": pct(percent(n, totalHist))}));

    // --- Indicadores derivados (tasas y diversidad con los filtros actuales) ---
    const guides = new Set(); rows.forEach(r => { if(valid(r["PROFESOR GUIA"])) guides.add(clean(r["PROFESOR GUIA"])); });
    const areasSet = new Set(); rows.forEach(r => { const a = cleanDomain(r.AREA_CONOCIMIENTO); if(a) areasSet.add(a); });
    const years = rows.map(yearOf).filter(Boolean);
    const span = years.length ? (Math.max(...years) - Math.min(...years) + 1) : 1;
    // Shannon evenness (0 concentrado, 1 diverso) sobre áreas de conocimiento
    const areaCounts = new Map(); rows.forEach(r => { const a = cleanDomain(r.AREA_CONOCIMIENTO); if(a) areaCounts.set(a, (areaCounts.get(a)||0)+1); });
    const av = [...areaCounts.values()]; const at = av.reduce((s,x)=>s+x,0);
    let H = 0; if(av.length > 1 && at){ av.forEach(x => { const p = x/at; H -= p*Math.log(p); }); H /= Math.log(av.length); }
    // Concentración: participación de los 5 guías con más trabajos
    const top5 = topCounts(rows, r => clean(r["PROFESOR GUIA"]), 5).reduce((s,d)=>s+d.value,0);

    const derived = [
      ["ACAD", "Académicos(as) distintos que actúan como guía", fmt(guides.size), "—"],
      ["AREAS", "Áreas de conocimiento distintas presentes", fmt(areasSet.size), "—"],
      ["TCG%", "Tasa de co-guía (trabajos con co-guía / total)", pct(percent(coguia.length, total)), "—"],
      ["PRE%", "Proporción de pregrado", pct(percent(pre.length, total)), "—"],
      ["POS%", "Proporción de posgrado", pct(percent(pos.length, total)), "—"],
      ["DIV", "Diversidad temática (Shannon normalizado 0–1)", H.toLocaleString("es-CL", {maximumFractionDigits: 2}), "—"],
      ["MEDIA", "Producción media anual", (total/span).toLocaleString("es-CL", {maximumFractionDigits: 1}), "—"],
      ["CONC5", "Concentración: participación de los 5 guías principales", pct(percent(top5, total)), "—"]
    ];
    const out = base.concat(derived.map(([ind, desc, val, part]) => ({Indicador: ind, Descripción: desc, Cantidad: val, "Participación (%)": part})));
    return out.map(r => ({...r, "Descripción": tt("ind." + r.Indicador, r["Descripción"])}));
}

// Tabla por academico(a): un renglon por persona (guia + co-guia) con los filtros actuales
function allAcademicsIn(rows){
  const s = new Set();
  rows.forEach(r => { if(valid(r["PROFESOR GUIA"])) s.add(clean(r["PROFESOR GUIA"])); if(valid(r["PROFESOR COGUIA"])) s.add(clean(r["PROFESOR COGUIA"])); });
  return [...s].sort((a,b) => a.localeCompare(b, "es"));
}
function academicIndicatorRows(){
  const rows = state.filtered;
  return allAcademicsIn(rows).map(ac => {
    const guia = rows.filter(r => clean(r["PROFESOR GUIA"]) === ac);
    const co = rows.filter(r => clean(r["PROFESOR COGUIA"]) === ac);
    const involved = rows.filter(r => clean(r["PROFESOR GUIA"]) === ac || clean(r["PROFESOR COGUIA"]) === ac);
    const areas = new Set(); involved.forEach(r => { const a = cleanDomain(r.AREA_CONOCIMIENTO); if(a) areas.add(a); });
    return {
      "Académico(a)": compactName(ac),
      "Guiados": guia.length,
      "Co-guiados": co.length,
      "Total": involved.length,
      "Pregrado": countWhere(involved, r => valid(r.PREGRADO)),
      "Posgrado": countWhere(involved, r => valid(r.POSGRADO)),
      "Áreas": areas.size
    };
  }).sort((a,b) => (b.Total - a.Total) || (b.Guiados - a.Guiados) || a["Académico(a)"].localeCompare(b["Académico(a)"], "es"));
}

function renderDataTable(id, rows, columns, opts){
  opts = opts || {};
  if(state.tables[id]){
    state.tables[id].clear().destroy();
    el(id).innerHTML = "";
  }
  const cfg = {
    data: rows,
    columns: columns.map(col => {
      const key = (typeof col === "string") ? col : col.key;
      const title = (typeof col === "string") ? col : (col.title != null ? col.title : col.key);
      return {
        title: title,
        data: null,
        defaultContent: "",
        render: function(_d, _t, row){ const v = row[key]; return (v === null || v === undefined) ? "" : v; }
      };
    }),
    pageLength: id === "tabla_registros" ? 12 : 25,
    lengthChange: false,
    autoWidth: false,
    order: opts.order || [],
    ordering: opts.ordering !== false,
    searching: opts.searching !== false,
    language: {
      search: "Buscar:",
      zeroRecords: "No hay registros con los filtros actuales",
      info: "Mostrando _START_ a _END_ de _TOTAL_ registros",
      infoEmpty: "Sin registros",
      paginate: {previous: "Anterior", next: "Siguiente"}
    }
  };
  if(typeof opts.onDraw === "function"){ cfg.drawCallback = function(){ opts.onDraw(id); }; }
  state.tables[id] = $(`#${id}`).DataTable(cfg);
}

function renderIndicators(){
  if(state.indicatorMode === "academico"){
    renderDataTable("tabla_indicadores", academicIndicatorRows(), [
      {key:"Académico(a)", title:tt("col.academic","Académico(a)")},
      {key:"Guiados", title:tt("col.guided","Guiados")},
      {key:"Co-guiados", title:tt("col.coguided","Co-guiados")},
      {key:"Total", title:tt("col.total","Total")},
      {key:"Pregrado", title:tt("col.pre","Pregrado")},
      {key:"Posgrado", title:tt("col.pos","Posgrado")},
      {key:"Áreas", title:tt("col.areas","Áreas")}
    ], {searching:false});
  } else {
    renderDataTable("tabla_indicadores", indicatorRows(), [
      {key:"Indicador", title:tt("col.indicator","Indicador")},
      {key:"Descripción", title:tt("col.description","Descripción")},
      {key:"Cantidad", title:tt("col.qty","Cantidad")},
      {key:"Participación (%)", title:tt("col.share","Participación (%)")}
    ], {ordering:false, searching:false, onDraw: (typeof decorateIndicatorHelp === "function") ? decorateIndicatorHelp : null});
  }
}


function dominioRows(){
  const field = el("dom_tipo").value;
  const map = new Map();
  state.filtered.forEach(row => {
    const dom = cleanDomain(row[field]);
    const guide = compactName(row["PROFESOR GUIA"]);
    const year = yearOf(row);
    if(!dom || !guide || !year) return;
    const key = `${guide}|||${dom}|||${year}`;
    map.set(key, (map.get(key) || 0) + 1);
  });
  return [...map.entries()].map(([key, value]) => {
    const [autor, palabra, year] = key.split("|||");
    return {autor, palabra, year:Number(year), value};
  });
}

function updateDomainSelector(){
  const rows = dominioRows();
  const current = el("dom_clave").value;
  const keys = [...new Set(rows.map(d => d.palabra))].sort((a,b) => a.localeCompare(b, "es"));
  setOptions(el("dom_clave"), keys, null);
  if(keys.includes(current)) el("dom_clave").value = current;
}

function renderDomain(){
  updateDomainSelector();
  const rows = dominioRows();
  const selected = el("dom_clave").value;
  const active = rows.filter(d => d.palabra === selected);
  const authors = [...new Set(active.map(d => d.autor))].sort((a,b) => a.localeCompare(b, "es"));

  Plotly.react("dom_timeline", [{
    type: "scatter",
    mode: "markers",
    x: active.map(d => d.year),
    y: active.map(d => d.autor),
    marker: {
      size: active.map(d => 9 + d.value * 4),
      color: active.map(d => d.value),
      colorscale: [[0, C.purpleSoft], [1, C.purple]],
      line: {color: C.purpleDark, width: 1}
    },
    text: active.map(d => `${d.palabra}<br>${d.value} trabajos`),
    hovertemplate: "%{y}<br>Año %{x}<br>%{text}<extra></extra>"
  }], plotLayout({
    margin: {l: 190, r: 20, t: 12, b: 44},
    xaxis: {dtick: 1, range: [state.years[0] - .5, state.years[1] + .5], gridcolor: "#F0EAF3"},
    yaxis: {categoryorder:"array", categoryarray: authors, automargin:true, gridcolor:"rgba(0,0,0,0)"}
  }), plotConfig());

  renderBar("dom_ranking", state.filtered, r => cleanDomain(r[el("dom_tipo").value]), "h", 15);
}

function registroRows(rows){
  return (rows || state.filtered).map(r => ({
    Año: yearOf(r),
    Estudiante: compactName(r.ESTUDIANTE),
    Título: clean(r.TITULO),
    Programa: programOf(r),
    Guía: compactName(r["PROFESOR GUIA"]),
    "Co-guía": compactName(r["PROFESOR COGUIA"]),
    "Área conocimiento": cleanDomain(r.AREA_CONOCIMIENTO),
    "Área aplicación": cleanDomain(r.AREA_APLICACION),
    Enlace: valid(r.ENLACE) ? `<a href="${clean(r.ENLACE)}" target="_blank" rel="noopener">Abrir</a>` : ""
  }));
}

function renderAll(){
  renderSummaryCards();
  renderSummaryCharts();
  renderIndicators();
  renderProfile();
  renderDomain();
  if(typeof buildAnalytics === "function") buildAnalytics();
  if(typeof buildCompare === "function") buildCompare();
  if(typeof renderChatContext === "function") renderChatContext();
  if(typeof applyFriendlyTooltips === "function") applyFriendlyTooltips();
}

