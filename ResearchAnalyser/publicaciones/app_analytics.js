/* ============================================================
   ANALÍTICA v15 — hallazgos, comparación χ² y oportunidades
   ============================================================ */

const ANA_FIELDS = {
  AREA_COMPUTACION: { label: 'Áreas de especialidad', sep: /[;,|]/ },
  AREAS: { label: 'Áreas de aplicación', sep: /[;,|]/ },
  CATEGORIAS: { label: 'Subáreas de aplicación', sep: /[;,|]/ },
  DISCIPLINA_OCDE: { label: 'Áreas OCDE', sep: null },
  AREA_OCDE: { label: 'Subáreas OCDE', sep: null },
  AREA_ODS_ANID: { label: 'Áreas ODS (ANID)', sep: null },
  INDEX_PALABRAS_CLAVES: { label: 'Palabras clave', sep: /[;,|]/ },
  QUARTILE: { label: 'Cuartil', sep: null },
  TIPO_DOCUMENTO: { label: 'Tipo de documento', sep: null }
};
const ANA_REST = '__RESTO_UNIDAD__';

function anaRows(){ return base(); }
function anaTerms(rows, field){
  const meta = ANA_FIELDS[field] || ANA_FIELDS.INDEX_PALABRAS_CLAVES;
  const out = [];
  rows.forEach(r => {
    const raw = String(r[field] || '').trim();
    const vals = meta.sep ? raw.split(meta.sep) : [raw];
    const fixed = (field === 'QUARTILE' || field === 'TIPO_DOCUMENTO');
    vals.forEach(v => {
      if (fixed) {
        const w = titleCase(stripParen(v).replace(/^\d+\s*/, '').replace(/'/g, '').trim());
        if (w && w !== '#N/A' && w !== 'Sin Clasificación') out.push(w);
      } else {
        const w = kwLabel(v, field);
        if (w) out.push(w);
      }
    });
  });
  return out;
}
function anaAuthorRows(author){ return anaRows().filter(r => r.NOMBRE_AUTOR === author); }
function anaCompareRows(value, otherValue){
  const rows = anaRows();
  if (value === ANA_REST) {
    return otherValue && otherValue !== ANA_REST
      ? rows.filter(r => r.NOMBRE_AUTOR !== otherValue)
      : rows;
  }
  return rows.filter(r => r.NOMBRE_AUTOR === value);
}
function anaCompareLabel(value, otherValue, short){
  if (value !== ANA_REST) return titleCase(value || '-');
  if (short) return 'Resto de la unidad';
  return otherValue && otherValue !== ANA_REST
    ? `Resto de la unidad (sin ${titleCase(otherValue)})`
    : 'Resto de la unidad';
}
function anaPubs(rows){ return uniquePubs(rows); }

function erfApprox(x){
  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x);
  const a1=0.254829592,a2=-0.284496736,a3=1.421413741,a4=-1.453152027,a5=1.061405429,p=0.3275911;
  const t = 1/(1+p*x);
  const y = 1-(((((a5*t+a4)*t)+a3)*t+a2)*t+a1)*t*Math.exp(-x*x);
  return sign*y;
}
function normalCDF(x){ return 0.5*(1+erfApprox(x/Math.SQRT2)); }
function chiSquarePApprox(x, df){
  if (!df || df < 1) return 1;
  const z = (Math.pow(x/df, 1/3) - (1 - 2/(9*df))) / Math.sqrt(2/(9*df));
  return Math.max(0, Math.min(1, 1 - normalCDF(z)));
}

function buildAnalitica(){
  const rows = anaRows();
  if (!rows.length) {
    document.getElementById('ana_insights').innerHTML = '<div class="empty">Sin datos para el filtro activo.</div>';
    const cont = document.getElementById('ana_continuity');
    if (cont) cont.innerHTML = '';
    return;
  }
  wireAnalyticsControls(rows);
  renderInsights(rows);
  renderContinuityAlert(rows);
  renderOpportunities(rows);
  runGlobalSearch('');
  runChiCompare();
}

function wireAnalyticsControls(rows){
  const authors = uniq(rows.map(r => r.NOMBRE_AUTOR).filter(Boolean)).sort();
  const a = document.getElementById('ana_author_a');
  const b = document.getElementById('ana_author_b');
  if (!a || !b) return;
  const opts = `<option value="${ANA_REST}">Resto de la unidad</option>` +
    authors.map(x => `<option value="${escAttr(x)}">${titleCase(x)}</option>`).join('');
  if (!a.dataset.ready) {
    a.innerHTML = opts;
    b.innerHTML = opts;
    if (authors[0]) a.value = authors[0];
    b.value = ANA_REST;
    ['ana_author_a','ana_author_b','ana_var'].forEach(id => {
      const el = document.getElementById(id);
      if (el) el.onchange = runChiCompare;
    });
    const search = document.getElementById('ana_search');
    const btn = document.getElementById('ana_search_btn');
    if (search) search.oninput = () => runGlobalSearch(search.value);
    if (btn) btn.onclick = () => runGlobalSearch(search ? search.value : '');
    a.dataset.ready = '1';
  } else {
    const oldA = a.value, oldB = b.value;
    a.innerHTML = opts;
    b.innerHTML = opts;
    if (oldA === ANA_REST || authors.includes(oldA)) a.value = oldA;
    else if (authors[0]) a.value = authors[0];
    if (oldB === ANA_REST || authors.includes(oldB)) b.value = oldB;
    else b.value = ANA_REST;
  }
}

function renderInsights(rows){
  const years = rows.map(r => int0(r.ANO)).filter(y => y > 1900);
  const maxY = years.length ? Math.max(...years) : S.yMax;
  const recent = rows.filter(r => int0(r.ANO) >= maxY - 2);
  const prev = rows.filter(r => int0(r.ANO) >= maxY - 5 && int0(r.ANO) <= maxY - 3);
  const q1 = rows.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
  const articles = rows.filter(r => r.TIPO_DOCUMENTO === 'Article').length || 1;
  const intl = rows.filter(r => String(r.PAISES_AUTORES || '').split(', ').some(p => p.trim() && p.trim() !== 'Chile')).length;
  const topArea = sortEnt(countBy(anaTerms(rows, 'AREA_COMPUTACION')))[0] || ['-', 0];
  const topCited = [...anaPubs(rows)].sort((a,b) => int0(b.CITADO_POR)-int0(a.CITADO_POR))[0];
  const growth = prev.length ? ((recent.length - prev.length) / prev.length * 100) : (recent.length ? 100 : 0);
  const items = [
    { icon:'fa-arrow-trend-up', title:'Tendencia reciente', text:`${recent.length} publicaciones en los últimos 3 años del filtro; variación aproximada ${nf(growth)}% frente al trienio previo.` },
    { icon:'fa-award', title:'Calidad editorial', text:`${q1} artículos Q1 (${nf(q1/articles*100)}% sobre artículos con cuartil).` },
    { icon:'fa-globe', title:'Colaboración internacional', text:`${intl} publicaciones con al menos un país distinto de Chile.` },
    { icon:'fa-layer-group', title:'Especialidad dominante', text:`${topArea[0]} concentra ${topArea[1]} registros.` },
    { icon:'fa-fire', title:'Mayor impacto por citas', text: topCited ? `${topCited.TITULO} · ${int0(topCited.CITADO_POR)} citas.` : 'Sin publicaciones citadas.' }
  ];
  document.getElementById('ana_insights').innerHTML = items.map(x => `
    <div class="insight-item"><i class="fa-solid ${x.icon}"></i><div><b>${x.title}</b><span>${chatEsc(x.text)}</span></div></div>
  `).join('');
}

function continuityRisks(rows){
  const anchor = S.yMax || Math.max(...rows.map(r => int0(r.ANO)).filter(y => y > 1900));
  const recentStart = anchor - 2;
  const byAuthor = new Map();
  rows.forEach(r => {
    const a = r.NOMBRE_AUTOR;
    const y = int0(r.ANO);
    if (!a || y <= 1900) return;
    if (!byAuthor.has(a)) byAuthor.set(a, []);
    byAuthor.get(a).push(r);
  });
  return [...byAuthor.entries()].map(([author, rs]) => {
    const years = rs.map(r => int0(r.ANO)).filter(y => y > 1900);
    const last = years.length ? Math.max(...years) : 0;
    return { author, last, gap: Math.max(0, anchor - last), pubs: anaPubs(rs).length };
  }).filter(x => x.last && x.last < recentStart)
    .sort((a,b) => b.gap - a.gap || a.last - b.last || a.author.localeCompare(b.author));
}

function renderContinuityAlert(rows){
  const box = document.getElementById('ana_continuity');
  if (!box) return;
  const anchor = S.yMax || Math.max(...rows.map(r => int0(r.ANO)).filter(y => y > 1900));
  const recentStart = anchor - 2;
  const risks = continuityRisks(rows).slice(0, 8);
  if (!risks.length) {
    box.innerHTML = `<div class="continuity-ok"><i class="fa-solid fa-circle-check"></i><span>No se detectan académicos(as) del filtro activo sin publicaciones en el trienio ${recentStart}-${anchor}.</span></div>`;
    return;
  }
  box.innerHTML = `
    <div class="continuity-alert">
      <div class="continuity-head">
        <i class="fa-solid fa-triangle-exclamation"></i>
        <div><b>Alerta de continuidad investigativa</b><span>Personas del filtro activo sin publicaciones registradas en el trienio ${recentStart}-${anchor}.</span></div>
      </div>
      <div class="continuity-authors">${risks.map(x => `
        <div class="continuity-chip"><b>${titleCase(x.author)}</b><span>última publicación: ${x.last} · ${x.pubs} pubs en el periodo</span></div>
      `).join('')}</div>
    </div>`;
}

function runGlobalSearch(q){
  const box = document.getElementById('ana_search_results');
  if (!box) return;
  const rows = anaRows();
  const query = chatNorm(q || '');
  const pubs = anaPubs(rows);
  let hits = pubs;
  if (query) {
    const toks = query.split(/\s+/).filter(t => t.length > 1);
    hits = pubs.map(r => {
      const text = chatNorm((HEADERS || Object.keys(r)).map(h => r[h]).join(' '));
      const score = toks.reduce((s,t) => s + (text.includes(t) ? 1 : 0), 0);
      return { r, score };
    }).filter(x => x.score).sort((a,b) => b.score - a.score || int0(b.r.CITADO_POR)-int0(a.r.CITADO_POR)).map(x => x.r);
  }
  hits = hits.slice(0, 10);
  box.innerHTML = hits.length ? hits.map(r => {
    const link = typeof paperLink === 'function' ? paperLink(r) : null;
    const title = chatEsc(r.TITULO || '-');
    const titleHTML = link
      ? `<a href="${chatEsc(link)}" target="_blank" rel="noopener">${title} <i class="fa-solid fa-arrow-up-right-from-square"></i></a>`
      : title;
    return `<article class="ana-hit">
      <b>${titleHTML}</b>
      <span>${chatEsc(r.ANO || '')} · ${chatEsc(r.FUENTE || '')} · ${int0(r.CITADO_POR)} citas</span>
    </article>`;
  }).join('') : '<div class="empty">Sin coincidencias.</div>';
}

function runChiCompare(){
  const a = document.getElementById('ana_author_a')?.value;
  const b = document.getElementById('ana_author_b')?.value;
  const field = document.getElementById('ana_var')?.value || 'AREA_COMPUTACION';
  if (!a || !b) return;
  if (a === ANA_REST && b === ANA_REST) {
    document.getElementById('ana_compare_summary').innerHTML = '<div class="empty">Selecciona un académico(a) en A o B para comparar contra el resto de la unidad.</div>';
    const legend = document.getElementById('ana_chi_legend');
    if (legend) legend.innerHTML = '';
    Plotly.purge('ana_chi_plot');
    drawAnaTable([]);
    return;
  }
  const ra = anaCompareRows(a, b), rb = anaCompareRows(b, a);
  const labelA = anaCompareLabel(a, b);
  const labelB = anaCompareLabel(b, a);
  const shortA = anaCompareLabel(a, b, true);
  const shortB = anaCompareLabel(b, a, true);
  const ca = countBy(anaTerms(ra, field)), cb = countBy(anaTerms(rb, field));
  const keys = uniq([...ca.keys(), ...cb.keys()]).filter(k => (ca.get(k)||0)+(cb.get(k)||0) > 0);
  const totalA = [...ca.values()].reduce((s,x)=>s+x,0), totalB = [...cb.values()].reduce((s,x)=>s+x,0);
  let chi = 0;
  const table = keys.map(k => {
    const oa = ca.get(k)||0, ob = cb.get(k)||0, row = oa+ob, n = totalA+totalB || 1;
    const ea = row*totalA/n, eb = row*totalB/n;
    const contrib = (ea ? Math.pow(oa-ea,2)/ea : 0) + (eb ? Math.pow(ob-eb,2)/eb : 0);
    chi += contrib;
    const resid = ea ? (oa-ea)/Math.sqrt(ea) : 0;
    return { Término:k, A:oa, B:ob, 'Residuo A':+resid.toFixed(2), 'Contribución χ²':+contrib.toFixed(2) };
  }).sort((x,y) => Math.abs(y['Residuo A']) - Math.abs(x['Residuo A']));
  const df = Math.max(1, keys.length-1);
  const p = chiSquarePApprox(chi, df);
  document.getElementById('ana_compare_summary').innerHTML = `
    <div class="mini-stat"><b>${chatEsc(labelA)}</b><span>${anaPubs(ra).length} pubs únicas</span></div>
    <div class="mini-stat"><b>${chatEsc(labelB)}</b><span>${anaPubs(rb).length} pubs únicas</span></div>
    <div class="mini-stat"><b>χ²=${chi.toFixed(2)}</b><span>gl=${df} · p≈${p.toFixed(3)}</span></div>
    <div class="mini-stat"><b>${ANA_FIELDS[field]?.label || field}</b><span>variable comparada</span></div>`;
  const legend = document.getElementById('ana_chi_legend');
  if (legend) legend.innerHTML = `
    <span><i style="background:${C.emerald2}"></i> Más presente en ${chatEsc(shortA)}</span>
    <span><i style="background:${C.rust}"></i> Más presente en ${chatEsc(shortB)}</span>
    <em>La longitud de la barra muestra cuánto se aparta cada término de lo esperado.</em>`;
  const top = table.slice(0, 18).reverse();
  Plotly.newPlot('ana_chi_plot', [
    {
      type:'bar', orientation:'h', name:`Más presente en ${shortA}`,
      y: top.map(r => r.Término), x: top.map(r => r['Residuo A'] >= 0 ? r['Residuo A'] : null),
      marker:{ color:C.emerald2 },
      hovertemplate:'%{y}<br>Residuo A: %{x:.2f}<extra></extra>'
    },
    {
      type:'bar', orientation:'h', name:`Más presente en ${shortB}`,
      y: top.map(r => r.Término), x: top.map(r => r['Residuo A'] < 0 ? r['Residuo A'] : null),
      marker:{ color:C.rust },
      hovertemplate:'%{y}<br>Residuo A: %{x:.2f}<extra></extra>'
    }
  ], Object.assign({}, PLAYOUT, {
    margin:{t:36,r:16,b:48,l:230},
    barmode:'overlay',
    showlegend:true,
    legend:{orientation:'h', y:1.12, x:0, font:{size:11, color:C.muted}},
    xaxis:{title:'residuo estandarizado para A', zeroline:true, zerolinecolor:C.muted, gridcolor:C.line},
    yaxis:{automargin:true}
  }), PCFG);
  drawAnaTable(table.slice(0, 50));
}

function drawAnaTable(rows){
  const sel = '#ana_chi_table';
  if ($.fn.DataTable.isDataTable(sel)) $(sel).DataTable().destroy();
  $(sel).empty();
  if (!rows.length) return;
  const cols = Object.keys(rows[0]).map(k => ({ title:k, data:k }));
  $(sel).DataTable({ data:rows, columns:cols, dom:'Bfrtip',
    buttons:[{ extend:'csv', text:'↓ CSV', className:'dt-button' }],
    pageLength:10, order:[[4,'desc']], language:dtLang(), scrollX:true });
}

function renderOpportunities(rows){
  const authors = uniq(rows.map(r => r.NOMBRE_AUTOR).filter(Boolean)).sort();
  const termSets = new Map();
  const coPairs = new Set();
  authors.forEach(a => {
    const ra = rows.filter(r => r.NOMBRE_AUTOR === a);
    termSets.set(a, new Set(anaTerms(ra, 'INDEX_PALABRAS_CLAVES').concat(anaTerms(ra, 'AREA_COMPUTACION')).map(chatNorm).filter(t => t.length > 2)));
    ra.forEach(r => pairAuthors(r).forEach(p => {
      const n = chatNorm(p.name);
      if (n) coPairs.add([chatNorm(a), n].sort().join('||'));
    }));
  });
  const pairs = [];
  for (let i=0;i<authors.length;i++) for (let j=i+1;j<authors.length;j++) {
    const a=authors[i], b=authors[j], key=[chatNorm(a),chatNorm(b)].sort().join('||');
    if (coPairs.has(key)) continue;
    const A=termSets.get(a), B=termSets.get(b);
    const inter=[...A].filter(x => B.has(x));
    const union=new Set([...A,...B]);
    const sim=union.size ? inter.length/union.size : 0;
    if (sim > 0) pairs.push({a,b,sim,common:inter.slice(0,5)});
  }
  pairs.sort((x,y) => y.sim - x.sim);
  const top = pairs.slice(0, 10);
  document.getElementById('ana_opportunities').innerHTML = top.length ? top.map(p => `
    <div class="opp-item">
      <div><b>${titleCase(p.a)}</b> + <b>${titleCase(p.b)}</b><span>Similitud ${nf(p.sim*100)}%</span></div>
      <p>${p.common.map(titleCase).join(', ')}</p>
    </div>
  `).join('') : '<div class="empty">No se detectaron oportunidades claras con el filtro activo.</div>';
}
