/* ============================================================
   Comparación entre académicos(as) · Perfiles
   Prueba χ² con residuos estandarizados sobre la base filtrada.
   Compara A vs B (o A vs "resto del departamento") en la variable
   elegida: áreas de conocimiento/aplicación/SWEBOK, palabras clave
   o programa. Reutiliza helpers globales de app.js.
   ============================================================ */
const CMP_REST = "__RESTO_DEPTO__";

const CMP_VARS = {
  AREA_CONOCIMIENTO: {label: "Áreas de conocimiento", get: r => { const v = cleanDomain(r.AREA_CONOCIMIENTO); return v ? [v] : []; }},
  AREA_APLICACION:   {label: "Áreas de aplicación",   get: r => { const v = cleanDomain(r.AREA_APLICACION);   return v ? [v] : []; }},
  AREA_SWEBOK:       {label: "Áreas del SWEBOK",       get: r => { const v = cleanDomain(r.AREA_SWEBOK);       return v ? [v] : []; }},
  KEYWORDS:          {label: "Palabras clave",         get: r => cmpKwTerms(r)},
  PROGRAMA:          {label: "Programa",               get: r => programsOf(r)}
};

function cmpKwTerms(row){
  const out = [];
  const kw = clean(row.KEYWORDS);
  if(!valid(kw)) return out;
  kw.split(/[,;/]+/).forEach(raw => {
    let w = clean(raw).toLocaleLowerCase("es-CL").replace(/^[\s\-·]+|[\s\-·]+$/g, "");
    if(!w) return;
    const bare = w.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    if(bare.length < 4 || KW_STOP.has(bare) || /^\d+$/.test(bare)) return;
    out.push(titleCase(w));
  });
  return out;
}

function cmpInvolves(row, name){
  return clean(row["PROFESOR GUIA"]) === name || clean(row["PROFESOR COGUIA"]) === name;
}

function cmpRows(value, other){
  const rows = state.filtered;
  if(value === CMP_REST){
    return (other && other !== CMP_REST) ? rows.filter(r => !cmpInvolves(r, other)) : rows.slice();
  }
  return rows.filter(r => cmpInvolves(r, value));
}

function cmpLabel(value, other, short){
  if(value !== CMP_REST) return compactName(value || "-");
  if(short) return "Resto del depto";
  return (other && other !== CMP_REST) ? `Resto del depto. (sin ${compactName(other)})` : "Resto del departamento";
}

function cmpTerms(rows, field){
  const meta = CMP_VARS[field] || CMP_VARS.AREA_CONOCIMIENTO;
  const out = [];
  rows.forEach(r => meta.get(r).forEach(v => { if(v) out.push(v); }));
  return out;
}

function countMap(list){
  const m = new Map();
  list.forEach(v => m.set(v, (m.get(v) || 0) + 1));
  return m;
}

/* χ² p-value aproximado (Wilson–Hilferty) — solo referencial */
function cmpErf(x){
  const s = x < 0 ? -1 : 1; x = Math.abs(x);
  const a1=0.254829592,a2=-0.284496736,a3=1.421413741,a4=-1.453152027,a5=1.061405429,p=0.3275911;
  const t = 1/(1+p*x);
  return s*(1-(((((a5*t+a4)*t)+a3)*t+a2)*t+a1)*t*Math.exp(-x*x));
}
function cmpNormCDF(x){ return 0.5*(1+cmpErf(x/Math.SQRT2)); }
function cmpChiP(x, df){
  if(!df || df < 1) return 1;
  const z = (Math.pow(x/df, 1/3) - (1 - 2/(9*df))) / Math.sqrt(2/(9*df));
  return Math.max(0, Math.min(1, 1 - cmpNormCDF(z)));
}

function cmpOptions(){
  const academics = allAcademics();
  return `<option value="${CMP_REST}">Resto del departamento</option>` +
    academics.map(a => `<option value="${a.replace(/"/g,"&quot;")}">${compactName(a)}</option>`).join("");
}

function buildCompare(){
  const selA = el("cmp_a"), selB = el("cmp_b");
  if(!selA || !selB) return;
  const academics = allAcademics();

  if(!selA.dataset.ready){
    const opts = cmpOptions();
    selA.innerHTML = opts;
    selB.innerHTML = opts;
    // por defecto: el guía más activo del histórico vs el resto
    const topGuide = topCounts(state.data, r => clean(r["PROFESOR GUIA"]), 1)[0];
    selA.value = topGuide ? topGuide.name : (academics[0] || CMP_REST);
    selB.value = CMP_REST;
    ["cmp_a", "cmp_b", "cmp_var"].forEach(id => el(id).addEventListener("change", renderCompare));
    selA.dataset.ready = "1";
  } else {
    const oldA = selA.value, oldB = selB.value;
    const opts = cmpOptions();
    selA.innerHTML = opts; selB.innerHTML = opts;
    selA.value = (oldA === CMP_REST || academics.includes(oldA)) ? oldA : (academics[0] || CMP_REST);
    selB.value = (oldB === CMP_REST || academics.includes(oldB)) ? oldB : CMP_REST;
  }
  renderCompare();
}

function renderCompare(){
  const a = el("cmp_a").value, b = el("cmp_b").value;
  const field = el("cmp_var").value || "AREA_CONOCIMIENTO";
  const summary = el("cmp_summary"), legend = el("cmp_legend");

  if(a === CMP_REST && b === CMP_REST){
    summary.innerHTML = `<div class="cmp-empty">Elige al menos un académico(a) en A o B para comparar contra el resto del departamento.</div>`;
    legend.innerHTML = "";
    Plotly.purge("cmp_plot");
    if(state.tables["cmp_table"]){ state.tables["cmp_table"].clear().destroy(); state.tables["cmp_table"] = null; el("cmp_table").innerHTML = ""; }
    return;
  }
  if(a !== CMP_REST && a === b){
    summary.innerHTML = `<div class="cmp-empty">A y B son la misma persona. Cambia uno para comparar.</div>`;
    legend.innerHTML = "";
    Plotly.purge("cmp_plot");
    if(state.tables["cmp_table"]){ state.tables["cmp_table"].clear().destroy(); state.tables["cmp_table"] = null; el("cmp_table").innerHTML = ""; }
    return;
  }

  const ra = cmpRows(a, b), rb = cmpRows(b, a);
  const labelA = cmpLabel(a, b), labelB = cmpLabel(b, a);
  const shortA = cmpLabel(a, b, true), shortB = cmpLabel(b, a, true);
  const ca = countMap(cmpTerms(ra, field)), cb = countMap(cmpTerms(rb, field));
  const keys = [...new Set([...ca.keys(), ...cb.keys()])].filter(k => (ca.get(k)||0)+(cb.get(k)||0) > 0);
  const totalA = [...ca.values()].reduce((s,x)=>s+x,0);
  const totalB = [...cb.values()].reduce((s,x)=>s+x,0);

  let chi = 0;
  const table = keys.map(k => {
    const oa = ca.get(k)||0, ob = cb.get(k)||0, rowN = oa+ob, n = totalA+totalB || 1;
    const ea = rowN*totalA/n, eb = rowN*totalB/n;
    const contrib = (ea ? Math.pow(oa-ea,2)/ea : 0) + (eb ? Math.pow(ob-eb,2)/eb : 0);
    chi += contrib;
    const resid = ea ? (oa-ea)/Math.sqrt(ea) : 0;
    return {"Término": k, [shortA]: oa, [shortB]: ob, "Residuo A": +resid.toFixed(2), "Contribución χ²": +contrib.toFixed(2)};
  }).sort((x,y) => Math.abs(y["Residuo A"]) - Math.abs(x["Residuo A"]));

  const df = Math.max(1, keys.length-1);
  const p = cmpChiP(chi, df);

  summary.innerHTML = `
    <div class="mini-stat"><b>${labelA}</b><span>${fmt(ra.length)} trabajos · ${fmt(totalA)} etiquetas</span></div>
    <div class="mini-stat"><b>${labelB}</b><span>${fmt(rb.length)} trabajos · ${fmt(totalB)} etiquetas</span></div>
    <div class="mini-stat"><b>χ² = ${chi.toFixed(2)}</b><span>gl = ${df} · p ≈ ${p.toFixed(3)}</span></div>
    <div class="mini-stat"><b>${CMP_VARS[field]?.label || field}</b><span>variable comparada</span></div>`;

  legend.innerHTML = `
    <span><i style="background:${C.teal}"></i> Más presente en ${shortA}</span>
    <span><i style="background:${C.orange}"></i> Más presente en ${shortB}</span>
    <em>El largo de la barra indica cuánto se aparta cada término de lo esperado.</em>`;

  const top = table.slice(0, 16).reverse();
  Plotly.newPlot("cmp_plot", [
    {
      type:"bar", orientation:"h", name:`Más en ${shortA}`,
      y: top.map(r => r["Término"]), x: top.map(r => r["Residuo A"] >= 0 ? r["Residuo A"] : null),
      marker:{color:C.teal}, hovertemplate:"%{y}<br>Residuo: %{x:.2f}<extra></extra>"
    },
    {
      type:"bar", orientation:"h", name:`Más en ${shortB}`,
      y: top.map(r => r["Término"]), x: top.map(r => r["Residuo A"] < 0 ? r["Residuo A"] : null),
      marker:{color:C.orange}, hovertemplate:"%{y}<br>Residuo: %{x:.2f}<extra></extra>"
    }
  ], plotLayout({
    margin:{t:16, r:16, b:46, l:200}, barmode:"overlay", showlegend:false,
    xaxis:{title:"residuo estandarizado (A)", zeroline:true, zerolinecolor:C.gray, gridcolor:"#F0EAF3"},
    yaxis:{automargin:true, gridcolor:"rgba(0,0,0,0)"}
  }), plotConfig());

  const cols = table.length ? Object.keys(table[0]) : [];
  renderDataTable("cmp_table", table.slice(0, 60), cols);
}
