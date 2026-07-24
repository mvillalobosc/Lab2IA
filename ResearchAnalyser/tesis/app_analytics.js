/* ============================================================
   Analítica · hallazgos automáticos, oportunidades de
   colaboración, alerta de continuidad y buscador global.
   Trabaja sobre la base filtrada (state.filtered). Sin API.
   ============================================================ */

function anaEsc(s){ return clean(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c])); }
function anaNorm(s){ return clean(s).toLocaleLowerCase("es-CL").normalize("NFD").replace(/[\u0300-\u036f]/g,""); }

/* Diversidad temática: índice de Shannon normalizado (0 = concentrado, 1 = disperso) */
function shannonEvenness(counts){
  const vals = [...counts.values()].filter(x => x > 0);
  const total = vals.reduce((s,x)=>s+x,0);
  if(vals.length <= 1 || !total) return 0;
  let h = 0;
  vals.forEach(x => { const p = x/total; h -= p*Math.log(p); });
  return h / Math.log(vals.length);
}

function areaCountsFor(rows, field){
  const m = new Map();
  rows.forEach(r => { const v = cleanDomain(r[field]); if(v) m.set(v, (m.get(v)||0)+1); });
  return m;
}

function buildAnalytics(){
  const rows = state.filtered;
  const box = el("ana_insights");
  if(!rows.length){
    if(box) box.innerHTML = `<div class="cmp-empty">${tt("ana.noData","Sin datos con los filtros actuales.")}</div>`;
    ["ana_continuity","ana_opportunities","ana_search_results"].forEach(id => { if(el(id)) el(id).innerHTML = ""; });
    return;
  }
  renderInsights(rows);
  renderContinuity(rows);
  renderOpportunities(rows);
  wireGlobalSearch();
  runGlobalSearch(el("ana_search") ? el("ana_search").value : "");
}

function anaInsightsItems(rows){
  const total = rows.length;
  const years = rows.map(yearOf).filter(Boolean);
  const maxY = years.length ? Math.max(...years) : state.years[1];
  const recent = rows.filter(r => yearOf(r) >= maxY-2).length;
  const prev = rows.filter(r => { const y = yearOf(r); return y >= maxY-5 && y <= maxY-3; }).length;
  const growth = prev ? ((recent - prev)/prev*100) : (recent ? 100 : 0);

  const co = countWhere(rows, r => valid(r["PROFESOR COGUIA"]));
  const pre = countWhere(rows, r => valid(r.PREGRADO));
  const pos = countWhere(rows, r => valid(r.POSGRADO));
  const withAbstract = countWhere(rows, r => valid(r.RESUMEN));
  const topArea = topCounts(rows, r => cleanDomain(r.AREA_CONOCIMIENTO), 1)[0];
  const topGuide = topCounts(rows, r => clean(r["PROFESOR GUIA"]), 1)[0];
  const guides = new Set(); rows.forEach(r => { if(valid(r["PROFESOR GUIA"])) guides.add(clean(r["PROFESOR GUIA"])); });
  const evenness = shannonEvenness(areaCountsFor(rows, "AREA_CONOCIMIENTO"));
  const span = years.length ? (Math.max(...years) - Math.min(...years) + 1) : 1;

  const trendDir = growth >= 0 ? "fa-arrow-trend-up" : "fa-arrow-trend-down";
  const sign = growth >= 0 ? "+" : "";
  const items = [
    {icon:trendDir, title:tt("ana.trend","Tendencia reciente"), text:tf("ana.trend.text",`${fmt(recent)} trabajos en los últimos 3 años del periodo seleccionado; variación ${sign}${nf(growth)}% frente al trienio previo.`,{n:fmt(recent),sign:sign,g:nf(growth)})},
    {icon:"fa-people-arrows", title:tt("ana.coguia","Co-guía"), text:tf("ana.coguia.text",`${fmt(co)} trabajos con profesor(a) co-guía (${pct(percent(co,total))} de los trabajos seleccionados).`,{n:fmt(co),p:pct(percent(co,total))})},
    {icon:"fa-scale-balanced", title:tt("ana.prepos","Pregrado vs posgrado"), text:tf("ana.prepos.text",`${fmt(pre)} de pregrado (${pct(percent(pre,total))}) y ${fmt(pos)} de posgrado (${pct(percent(pos,total))}).`,{pre:fmt(pre),pp:pct(percent(pre,total)),pos:fmt(pos),pop:pct(percent(pos,total))})},
    {icon:"fa-layer-group", title:tt("ana.domArea","Área dominante"), text: topArea ? tf("ana.domArea.text",`${topArea.name} concentra ${fmt(topArea.value)} trabajos (${pct(percent(topArea.value,total))}).`,{area:topArea.name,n:fmt(topArea.value),p:pct(percent(topArea.value,total))}) : tt("ana.noAreas","Sin áreas informadas.")},
    {icon:"fa-shapes", title:tt("ana.diversity","Diversidad temática"), text:tf("ana.diversity.text",`Índice de Shannon normalizado ${nf(evenness)} (0 = concentrado en pocas áreas, 1 = muy diverso).`,{e:nf(evenness)})},
    {icon:"fa-chalkboard-user", title:tt("ana.guideLoad","Carga de guía"), text: topGuide ? tf("ana.guideLoad.text",`${compactName(topGuide.name)} lidera con ${fmt(topGuide.value)} trabajos guiados; ${fmt(guides.size)} académicos(as) guiando en total.`,{name:compactName(topGuide.name),n:fmt(topGuide.value),g:fmt(guides.size)}) : tt("ana.noGuides","Sin guías informados.")},
    {icon:"fa-gauge-high", title:tt("ana.avgProd","Producción media"), text:tf("ana.avgProd.text",`≈ ${(total/span).toLocaleString("es-CL",{maximumFractionDigits:1})} trabajos por año, considerando ${fmt(span)} años del periodo seleccionado.`,{n:(total/span).toLocaleString("es-CL",{maximumFractionDigits:1}),span:fmt(span)})},
    {icon:"fa-file-lines", title:tt("ana.abstractCov","Cobertura de resumen"), text:tf("ana.abstractCov.text",`${fmt(withAbstract)} trabajos con resumen registrado (${pct(percent(withAbstract,total))}).`,{n:fmt(withAbstract),p:pct(percent(withAbstract,total))})}
  ];
  return items;
}
function renderInsights(rows){
  el("ana_insights").innerHTML = anaInsightsItems(rows).map(x => `
    <div class="insight-item"><i class="fa-solid ${x.icon}"></i><div><b>${x.title}</b><span>${anaEsc(x.text)}</span></div></div>
  `).join("");
}

/* Alerta de continuidad: guías sin trabajos en el trienio reciente del filtro */
function anaContinuityData(rows){
  const years = rows.map(yearOf).filter(Boolean);
  const anchor = years.length ? Math.max(...years) : state.years[1];
  const start = anchor - 2;
  const byGuide = new Map();
  rows.forEach(r => {
    const g = clean(r["PROFESOR GUIA"]);
    const y = yearOf(r);
    if(!valid(g) || !y) return;
    if(!byGuide.has(g)) byGuide.set(g, []);
    byGuide.get(g).push(y);
  });
  const risks = [...byGuide.entries()].map(([g, ys]) => {
    const last = Math.max(...ys);
    return {guide:g, last, gap: Math.max(0, anchor-last), total: ys.length};
  }).filter(x => x.last < start)
    .sort((a,b) => b.gap - a.gap || a.guide.localeCompare(b.guide, "es"))
    .slice(0, 10);
  return { start, anchor, risks };
}
function renderContinuity(rows){
  const box = el("ana_continuity");
  if(!box) return;
  const { start, anchor, risks } = anaContinuityData(rows);
  if(!risks.length){
    box.innerHTML = `<div class="continuity-ok"><i class="fa-solid fa-circle-check"></i><span>${tf("ana.contOk",`Ningún guía quedó sin trabajos dirigidos en el trienio ${start}–${anchor} con los filtros actuales.`,{start:start,anchor:anchor})}</span></div>`;
    return;
  }
  box.innerHTML = `
    <div class="continuity-alert">
      <div class="continuity-head">
        <i class="fa-solid fa-triangle-exclamation"></i>
        <div><b>${tt("ana.contTitle","Continuidad de dirección de tesis")}</b><span>${tf("ana.contDesc",`Guías sin trabajos dirigidos en el trienio ${start}–${anchor}, considerando los filtros actuales. Útil para revisar carga académica, disponibilidad y relevo en la dirección de memorias.`,{start:start,anchor:anchor})}</span></div>
      </div>
      <div class="continuity-authors">${risks.map(x => `
        <div class="continuity-chip"><b>${compactName(x.guide)}</b><span>${tf("ana.contChip",`último trabajo dirigido: ${x.last} · ${fmt(x.total)} en total`,{last:x.last,total:fmt(x.total)})}</span></div>
      `).join("")}</div>
    </div>`;
}

/* Oportunidades de colaboración: pares de guías con alta similitud temática
   (Jaccard sobre áreas + palabras clave) que aún no han co-dirigido juntos. */
function anaOpportunityPairs(rows){
  const guides = [...new Set(rows.filter(r => valid(r["PROFESOR GUIA"])).map(r => clean(r["PROFESOR GUIA"])))];
  if(guides.length < 2) return { enough:false, pairs:[] };

  const termSet = new Map();
  const coPairs = new Set();
  guides.forEach(g => {
    const rg = rows.filter(r => cmpInvolves(r, g));
    const terms = new Set();
    rg.forEach(r => {
      const a = cleanDomain(r.AREA_CONOCIMIENTO); if(a) terms.add(anaNorm(a));
      cmpKwTerms(r).forEach(t => { const n = anaNorm(t); if(n.length > 3) terms.add(n); });
    });
    termSet.set(g, terms);
  });
  // pares que ya co-dirigieron
  rows.forEach(r => {
    const g = clean(r["PROFESOR GUIA"]), c = clean(r["PROFESOR COGUIA"]);
    if(valid(g) && valid(c)) coPairs.add([g,c].sort().join("|||"));
  });

  const pairs = [];
  for(let i=0;i<guides.length;i++) for(let j=i+1;j<guides.length;j++){
    const a = guides[i], b = guides[j];
    if(coPairs.has([a,b].sort().join("|||"))) continue;
    const A = termSet.get(a), B = termSet.get(b);
    if(!A.size || !B.size) continue;
    const inter = [...A].filter(x => B.has(x));
    if(!inter.length) continue;
    const union = new Set([...A, ...B]);
    pairs.push({a, b, sim: inter.length/union.size, common: inter});
  }
  pairs.sort((x,y) => y.sim - x.sim);
  return { enough:true, pairs: pairs.slice(0, 10) };
}
function renderOpportunities(rows){
  const box = el("ana_opportunities");
  if(!box) return;
  const { enough, pairs } = anaOpportunityPairs(rows);
  if(!enough){ box.innerHTML = `<div class="cmp-empty">${tt("ana.need2","Se necesitan al menos dos guías con los filtros actuales.")}</div>`; return; }
  box.innerHTML = pairs.length ? pairs.map(p => `
    <div class="opp-item">
      <div><b>${compactName(p.a)}</b> + <b>${compactName(p.b)}</b><span>${tf("ana.sim",`Similitud ${nf(p.sim*100)}%`,{p:nf(p.sim*100)})}</span></div>
      <p>${p.common.slice(0,6).map(titleCase).join(", ")}</p>
    </div>
  `).join("") : `<div class="cmp-empty">${tt("ana.oppNone","No se detectaron oportunidades claras (o los guías del filtro ya colaboran entre sí).")}</div>`;
}

/* Buscador global: busca el texto en todos los campos del trabajo */
let anaSearchWired = false;
function wireGlobalSearch(){
  if(anaSearchWired) return;
  const inp = el("ana_search"), btn = el("ana_search_btn");
  if(inp) inp.addEventListener("input", () => runGlobalSearch(inp.value));
  if(btn) btn.addEventListener("click", () => runGlobalSearch(inp ? inp.value : ""));
  anaSearchWired = true;
}

function runGlobalSearch(q){
  const box = el("ana_search_results");
  if(!box) return;
  const query = anaNorm(q || "");
  let hits = state.filtered;
  if(query){
    const toks = query.split(/\s+/).filter(t => t.length > 1);
    hits = state.filtered.map(r => {
      const text = anaNorm(Object.values(r).join(" "));
      const score = toks.reduce((s,t) => s + (text.includes(t) ? 1 : 0), 0);
      return {r, score};
    }).filter(x => x.score === toks.length && x.score > 0)
      .sort((a,b) => (yearOf(b.r)||0) - (yearOf(a.r)||0))
      .map(x => x.r);
  }
  const shown = hits.slice(0, 12);
  box.innerHTML = shown.length ? shown.map(r => {
    const link = valid(r.ENLACE) ? `<a href="${anaEsc(r.ENLACE)}" target="_blank" rel="noopener">${anaEsc(r.TITULO)} <i class="fa-solid fa-arrow-up-right-from-square"></i></a>` : anaEsc(r.TITULO);
    const meta = [yearOf(r), programOf(r), compactName(r["PROFESOR GUIA"])].filter(Boolean).join(" · ");
    return `<article class="ana-hit"><b>${link}</b><span>${anaEsc(meta)} — ${anaEsc(compactName(r.ESTUDIANTE))}</span></article>`;
  }).join("") : `<div class="cmp-empty">${tt("ana.noMatch","Sin coincidencias con los filtros actuales.")}</div>`;
}
