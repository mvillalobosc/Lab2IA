/* ============================================================
   REPORTES · Informes HTML y CSV PERSONALIZADOS POR VISTA.
   Cada pestaña (Resumen, Indicadores, Perfiles, Analítica,
   Dominio) genera su propio informe con las secciones que le
   corresponden, respetando el filtro activo (institución,
   departamento, periodo). Reutiliza las funciones de datos de
   app_views.js, app_profile.js y app_analytics.js.
   ============================================================ */

/* ---------- utilidades ---------- */
function downloadCSV(filename, rows){
  if(!rows.length) return;
  const cols = Object.keys(rows[0]);
  const esc = v => `"${clean(v).replace(/<[^>]*>/g,"").replace(/"/g,'""')}"`;
  const csv = [cols.join(","), ...rows.map(r => cols.map(c => esc(r[c])).join(","))].join("\n");
  const blob = new Blob(["\ufeff", csv], {type:"text/csv;charset=utf-8"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(a.href);
}

function reportContext(){
  const inst = el("f_institucion").value ? prettyOrg(el("f_institucion").value) : "Todas las instituciones";
  const dep  = el("f_departamento").value ? prettyOrg(el("f_departamento").value) : "Todos los departamentos";
  return { inst, dep, y0: state.years[0], y1: state.years[1], n: state.filtered.length };
}

function repEsc(v){ return clean(v).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

/* Tabla del informe. rawCols: columnas cuyo valor se inserta como HTML (p.ej. enlaces). */
function reportTable(headers, rows, rawCols){
  rawCols = rawCols || [];
  const cell = (h, r) => rawCols.indexOf(h) >= 0 ? (r[h] != null ? r[h] : "") : repEsc(r[h]);
  const th = headers.map(h => `<th>${repEsc(h)}</th>`).join("");
  const tb = rows.map(r => `<tr>${headers.map(h => `<td>${cell(h, r)}</td>`).join("")}</tr>`).join("");
  return `<table><thead><tr>${th}</tr></thead><tbody>${tb || `<tr><td colspan="${headers.length}">${tt("report.noData","Sin datos")}</td></tr>`}</tbody></table>`;
}
/* alias retrocompatible */
function tablaHTMLReport(headers, rows){ return reportTable(headers, rows); }

function reportKPIs(rows){
  const pre = countWhere(rows, r => valid(r.PREGRADO));
  const pos = countWhere(rows, r => valid(r.POSGRADO));
  const cog = countWhere(rows, r => valid(r["PROFESOR COGUIA"]));
  const guides = (typeof allAcademicsIn === "function" ? allAcademicsIn(rows).length : 0);
  const areas = new Set(); rows.forEach(r => { const a = cleanDomain(r.AREA_CONOCIMIENTO); if(a) areas.add(a); });
  const kpi = (v,l) => `<div class="k"><b>${v}</b><span>${l}</span></div>`;
  return `<div class="kpis">${kpi(fmt(rows.length),"Trabajos")}${kpi(fmt(pre),"Pregrado")}${kpi(fmt(pos),"Posgrado")}${kpi(fmt(cog),"Con co-guía")}${kpi(fmt(guides),"Guías distintos(as)")}${kpi(fmt(areas.size),"Áreas distintas")}</div>`;
}

/* ---------- encabezado tipo CV (foto + identidad) ---------- */
function cvInitials(name){
  const p = clean(name).split(/\s+/).filter(Boolean);
  if(!p.length) return "·";
  return ((p[0][0] || "") + (p[1] ? p[1][0] : "")).toLocaleUpperCase("es-CL");
}
function cvHero(ctx, c, fecha){
  const isDept = ctx.isDept;
  const info = (!isDept && ctx.sel && Array.isArray(state.academics))
    ? state.academics.find(a => clean(a.ACADEMICO) === ctx.sel) : null;
  const name  = isDept ? "Departamento de Ingeniería Informática" : compactName(ctx.sel);
  const role  = isDept ? repEsc(c.inst) : `Académico(a) · ${repEsc(c.dep)}`;
  const mail  = isDept ? "" : clean(info && info.CORREO);
  const photo = isDept ? "" : clean(info && info.IMAGEN);
  const ini   = isDept ? "DI" : cvInitials(name);
  // La foto es la URL institucional (misma que usa la tarjeta de perfil); si no carga,
  // se mantiene el recuadro con iniciales. referrerpolicy evita bloqueos por hotlinking.
  const photoTag = photo
    ? `<img src="${repEsc(photo)}" alt="${repEsc(name)}" referrerpolicy="no-referrer" onerror="this.remove()">`
    : "";
  return `
  <div class="cv">
    <div class="cv-photo"><span class="cv-ini">${repEsc(ini)}</span>${photoTag}</div>
    <div class="cv-info">
      <h1>${repEsc(name)}</h1>
      <p class="cv-role">${role}</p>
      ${mail ? `<p class="cv-mail">${repEsc(mail)}</p>` : ""}
      <p class="meta">${repEsc(c.inst)} · Periodo ${c.y0}–${c.y1} · ${c.n} trabajos en el filtro · Generado el ${fecha}</p>
    </div>
  </div>`;
}

/* ---------- secciones por vista ---------- */

function secResumen(rows){
  const byYear = new Map();
  rows.forEach(r => { const y = yearOf(r); if(y) byYear.set(y, (byYear.get(y)||0)+1); });
  const annual = [...byYear.entries()].sort((a,b) => a[0]-b[0]).map(([y,n]) => ({"Año":y, "Trabajos":n}));
  const conoc = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 15).map(d => ({"Área de conocimiento": d.name, "Trabajos": d.value}));
  const aplic = topCounts(rows, r => cleanDomain(r.AREA_APLICACION), 15).map(d => ({"Área de aplicación": d.name, "Trabajos": d.value}));
  const swe   = topCounts(rows, r => cleanDomain(r.AREA_SWEBOK), 15).map(d => ({"Área SWEBOK": d.name, "Trabajos": d.value}));
  return `
    <h2>Distribución anual</h2>
    ${reportTable(["Año","Trabajos"], annual)}
    <h2>Áreas de conocimiento</h2>
    ${reportTable(["Área de conocimiento","Trabajos"], conoc)}
    <h2>Áreas de aplicación</h2>
    ${reportTable(["Área de aplicación","Trabajos"], aplic)}
    <h2>Áreas del SWEBOK</h2>
    ${reportTable(["Área SWEBOK","Trabajos"], swe)}`;
}

function secIndicadores(){
  const ind = indicatorRows().map(r => ({Indicador:r.Indicador, "Descripción":r["Descripción"], Cantidad:r.Cantidad, "Part. (%)":r["Participación (%)"]}));
  const acad = academicIndicatorRows();
  return `
    <h2>Indicadores institucionales</h2>
    ${reportTable(["Indicador","Descripción","Cantidad","Part. (%)"], ind)}
    <h2>Académicos(as) por participación</h2>
    ${reportTable(["Académico(a)","Guiados","Co-guiados","Total","Pregrado","Posgrado","Áreas"], acad)}`;
}

function secPerfiles(rows, ctx){
  const total = rows.length;
  const pre = countWhere(rows, r => valid(r.PREGRADO));
  const pos = countWhere(rows, r => valid(r.POSGRADO));
  const co  = (ctx.mode === "academico" && ctx.sel)
    ? countWhere(state.filtered, r => clean(r["PROFESOR COGUIA"]) === ctx.sel)
    : countWhere(rows, r => valid(r["PROFESOR COGUIA"]));
  const guia = (ctx.mode === "academico" && ctx.sel) ? countWhere(state.filtered, r => clean(r["PROFESOR GUIA"]) === ctx.sel) : total;

  const metrics = [
    {"Métrica":"Trabajos dirigidos (guía)", "Valor": fmt(guia)},
    {"Métrica":"Participación como co-guía", "Valor": fmt(co)},
    {"Métrica":"Pregrado", "Valor": fmt(pre)},
    {"Métrica":"Posgrado", "Valor": fmt(pos)}
  ];
  const conoc = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 15).map(d => ({"Área de conocimiento": d.name, "Trabajos": d.value}));
  const kw = (typeof keywordCounts === "function" ? keywordCounts(rows) : []).slice(0,25).map(d => ({"Palabra clave": d.text, "Peso": d.weight}));
  const trabajos = registroRows(rows);

  return `
    <h2>Métricas del perfil</h2>
    ${reportTable(["Métrica","Valor"], metrics)}
    <h2>Áreas de conocimiento del perfil</h2>
    ${reportTable(["Área de conocimiento","Trabajos"], conoc)}
    <h2>Palabras clave dominantes</h2>
    ${reportTable(["Palabra clave","Peso"], kw)}
    <h2>Trabajos del perfil (${fmt(trabajos.length)})</h2>
    ${reportTable(["Año","Estudiante","Título","Programa","Guía","Co-guía","Enlace"], trabajos, ["Enlace"])}`;
}

function secAnalitica(rows){
  const insights = (typeof anaInsightsItems === "function" ? anaInsightsItems(rows) : [])
    .map(x => ({"Aspecto": String(x.title||"").replace(/<[^>]*>/g,""), "Detalle": String(x.text||"").replace(/<[^>]*>/g,"")}));

  let contHTML;
  if(typeof anaContinuityData === "function"){
    const c = anaContinuityData(rows);
    if(!c.risks.length){
      contHTML = `<p class="ok">Ningún guía quedó sin trabajos dirigidos en el trienio ${c.start}–${c.anchor} con los filtros actuales.</p>`;
    } else {
      const cr = c.risks.map(x => ({"Guía": compactName(x.guide), "Último año dirigido": x.last, "Total dirigidos": x.total}));
      contHTML = `<p class="note">Guías sin trabajos dirigidos en el trienio ${c.start}–${c.anchor}.</p>` +
                 reportTable(["Guía","Último año dirigido","Total dirigidos"], cr);
    }
  } else contHTML = "";

  let oppHTML;
  if(typeof anaOpportunityPairs === "function"){
    const o = anaOpportunityPairs(rows);
    if(!o.enough){
      oppHTML = `<p class="note">Se necesitan al menos dos guías con los filtros actuales.</p>`;
    } else if(!o.pairs.length){
      oppHTML = `<p class="note">No se detectaron oportunidades claras (o los guías del filtro ya colaboran entre sí).</p>`;
    } else {
      const op = o.pairs.map(p => ({
        "Guía A": compactName(p.a), "Guía B": compactName(p.b),
        "Similitud": nf(p.sim*100) + "%",
        "Temas en común": p.common.slice(0,6).map(titleCase).join(", ")
      }));
      oppHTML = reportTable(["Guía A","Guía B","Similitud","Temas en común"], op);
    }
  } else oppHTML = "";

  return `
    <h2>Hallazgos automáticos</h2>
    ${reportTable(["Aspecto","Detalle"], insights)}
    <h2>Continuidad de dirección de tesis</h2>
    ${contHTML}
    <h2>Oportunidades de colaboración</h2>
    ${oppHTML}`;
}

function secDominio(rows){
  const field = el("dom_tipo") ? el("dom_tipo").value : "AREA_CONOCIMIENTO";
  const fieldLabel = el("dom_tipo") ? (el("dom_tipo").options[el("dom_tipo").selectedIndex] || {}).text || field : field;
  const ranking = topCounts(rows, r => cleanDomain(r[field]), 20).map(d => ({"Dominio": d.name, "Trabajos": d.value}));

  const selected = el("dom_clave") ? el("dom_clave").value : "";
  let detHTML = "";
  if(selected && typeof dominioRows === "function"){
    const det = dominioRows().filter(d => d.palabra === selected)
      .sort((a,b) => (a.autor.localeCompare(b.autor,"es")) || (a.year - b.year))
      .map(d => ({"Guía": d.autor, "Año": d.year, "Trabajos": d.value}));
    detHTML = `<h2>Detalle del término: ${repEsc(selected)}</h2>${reportTable(["Guía","Año","Trabajos"], det)}`;
  }

  return `
    <h2>Ranking de ${repEsc(fieldLabel)}</h2>
    ${reportTable(["Dominio","Trabajos"], ranking)}
    ${detHTML}`;
}

/* ---------- documento y despacho ---------- */

function baseReportDoc(tab, c, fecha, kpisHTML, bodyHTML, opts){
  opts = opts || {};
  const header = opts.hero ? opts.hero : `
  <h1>Informe de trabajos de título · ${repEsc(tab)}</h1>
  <p class="sub">${repEsc(c.inst)} · ${repEsc(c.dep)}</p>
  ${opts.extraSub ? `<p class="sub">${repEsc(opts.extraSub)}</p>` : ""}
  <p class="meta">Periodo ${c.y0}–${c.y1} · ${c.n} trabajos en el filtro · Generado el ${fecha}</p>`;
  return `<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Informe ${repEsc(tab)} · Memorias DIINF</title>
<style>
  :root{--p:#8C4799;--o:#EA7600;--t:#00A499;--ink:#2A2340;--mut:#6B6480;--line:#E7DEF0;}
  *{box-sizing:border-box;} body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:var(--ink);background:#fff;padding:40px;max-width:960px;margin:0 auto;}
  h1{font-size:1.5rem;margin:0 0 4px;} h2{font-size:1.05rem;color:var(--p);border-bottom:2px solid var(--line);padding-bottom:6px;margin:30px 0 12px;}
  .sub{color:var(--mut);font-size:.92rem;margin:0 0 2px;font-weight:600;} .meta{color:var(--mut);font-size:.82rem;margin:0 0 18px;}
  .kpis{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:16px 0;}
  .k{border:1px solid var(--line);border-radius:10px;padding:12px 14px;background:#FBF8FC;} .k b{display:block;font-size:1.3rem;color:var(--p);} .k span{font-size:.78rem;color:var(--mut);}
  table{width:100%;border-collapse:collapse;font-size:.85rem;margin:6px 0 4px;} th,td{text-align:left;padding:7px 9px;border-bottom:1px solid var(--line);} th{background:#F4EEF7;color:var(--p);font-weight:700;}
  td a{color:var(--p);text-decoration:none;} td a:hover{text-decoration:underline;}
  .ok{color:#1B7A4B;background:#EAF7F0;border:1px solid #CDE9DA;border-radius:8px;padding:9px 12px;font-size:.85rem;}
  .note{color:var(--mut);font-size:.85rem;margin:2px 0 8px;}
  .cv{display:flex;gap:22px;align-items:center;margin:0 0 10px;}
  .cv-photo{position:relative;width:112px;height:112px;flex:0 0 auto;border-radius:16px;overflow:hidden;background:linear-gradient(135deg,var(--p),var(--o));display:flex;align-items:center;justify-content:center;box-shadow:0 2px 10px rgba(140,71,153,.25);}
  .cv-ini{color:#fff;font-size:2.3rem;font-weight:800;letter-spacing:1px;}
  .cv-photo img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;}
  .cv-info h1{margin:0 0 3px;font-size:1.7rem;line-height:1.15;}
  .cv-role{margin:0 0 4px;color:var(--p);font-weight:600;font-size:.95rem;}
  .cv-mail{margin:0 0 4px;color:var(--mut);font-size:.9rem;}
  .foot{margin-top:32px;padding-top:14px;border-top:1px solid var(--line);color:var(--mut);font-size:.8rem;}
  @media print{ .cv-photo{-webkit-print-color-adjust:exact;print-color-adjust:exact;} }
</style></head><body>
  ${header}
  ${kpisHTML}
  ${bodyHTML}
  <div class="foot">Analizador de Memorias DIINF · v2 · Desarrollado por Manuel Villalobos-Cid y Valentina Cares Cárdenas · Universidad de Santiago de Chile</div>
</body></html>`;
}

function construirInforme(tab){
  const c = reportContext();
  const fecha = new Date().toLocaleDateString("es-CL", {year:"numeric", month:"long", day:"numeric"});
  let scopeRows = state.filtered, body = "", opts = {};

  switch(tab){
    case "Indicadores":
      body = secIndicadores();
      break;
    case "Perfiles": {
      const mode = state.profileMode;
      const sel = el("perf_academico") ? el("perf_academico").value : "";
      const isDept = mode === "departamento" || !sel;
      scopeRows = (typeof currentProfileRows === "function") ? currentProfileRows() : state.filtered;
      const ctx = {mode, sel, isDept};
      body = secPerfiles(scopeRows, ctx);
      opts = { hero: cvHero(ctx, c, fecha) };   // encabezado tipo CV con foto
      break;
    }
    case "Analítica":
      body = secAnalitica(scopeRows);
      break;
    case "Dominio":
      body = secDominio(scopeRows);
      break;
    case "Resumen":
    default:
      body = secResumen(scopeRows);
  }
  return baseReportDoc(tab, c, fecha, reportKPIs(scopeRows), body, opts);
}

function nombreInforme(tab){
  const slug = String(tab).normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-zA-Z0-9]+/g,"_").replace(/^_|_$/g,"");
  return `Informe_${slug}_${new Date().toISOString().slice(0,10)}`;
}

function exportarInforme(tab){
  try{
    const html = construirInforme(tab);
    const blob = new Blob([html], {type:"text/html;charset=utf-8"});
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob);
    a.download = nombreInforme(tab)+".html"; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(a.href);
  }catch(e){ console.error(e); alert("No se pudo generar el informe."); }
}

/* CSV por vista: exporta la tabla principal de cada pestaña */
function exportarInformeCSV(tab){
  let rows;
  switch(tab){
    case "Indicadores":
      rows = (state.indicatorMode === "academico" ? academicIndicatorRows() : indicatorRows());
      break;
    case "Perfiles":
      rows = registroRows((typeof currentProfileRows === "function") ? currentProfileRows() : state.filtered);
      break;
    case "Analítica":
      rows = (typeof anaInsightsItems === "function" ? anaInsightsItems(state.filtered) : [])
        .map(x => ({Aspecto: String(x.title||"").replace(/<[^>]*>/g,""), Detalle: String(x.text||"").replace(/<[^>]*>/g,"")}));
      break;
    case "Dominio":
      rows = (typeof dominioRows === "function" ? dominioRows() : [])
        .map(d => ({Guía: d.autor, Dominio: d.palabra, "Año": d.year, "Trabajos": d.value}));
      break;
    case "Resumen":
    default:
      rows = registroRows();
  }
  downloadCSV(nombreInforme(tab)+".csv", rows);
}

function descargarBaseDatos(){
  // Pide la clave antes de entregar la base completa (ver app_clave.js)
  pedirClave(() => _descargarBaseDatosReal());
}

function _descargarBaseDatosReal(){
  const csv = (typeof window !== "undefined" && window.MEMORIAS_CSV) ? window.MEMORIAS_CSV : null;
  if(csv){
    const blob = new Blob(["\ufeff", csv], {type:"text/csv;charset=utf-8"});
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob);
    a.download = "Base_Memorias_DIINF_"+new Date().toISOString().slice(0,10)+".csv";
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(a.href);
  } else {
    downloadCSV("Base_Memorias_DIINF.csv", registroRows());
  }
}
