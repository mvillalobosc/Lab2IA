/* ============================================================
   VISUALIZACIONES v3 — Perfiles y Dominio
   ============================================================ */

function termsFrom(rows, field, sep) {
  const out = [];
  rows.forEach(r => String(r[field] || '').split(sep || /[;,|]/).forEach(t => {
    let w = stripParen(t).trim().toUpperCase();
    if (w && w !== '#N/A') out.push(w);
  }));
  return out;
}

function perfilCtx() {
  let dfFull = byIndex(base(), S.perfIndex);
  let dv = dfFull;
  if (S.perfSel !== 'Institucionales' && S.perfAutor) dv = dfFull.filter(r => r.NOMBRE_AUTOR === S.perfAutor);
  return { dfFull, dv };
}

/* ---------- Ficha ---------- */
function renderFicha(dv) {
  const total = dv.length, wos = dv.filter(r => r.WOS === 'SI').length, sco = total - wos;
  const pct = n => total ? (n / total * 100).toFixed(1) : '0';
  let foto = S.perfSel === 'Institucionales' ? (dv[0] || {}).URL_FOTO_DEPARTAMENTO : (dv[0] || {}).URL_FOTO_ACADEMICO;
  const nombre = S.perfSel === 'Institucionales' ? `${S.sec}` : titleCase(S.perfAutor || '');
  const inicial = (nombre.trim()[0] || '?').toUpperCase();

  let avatar = foto ? `<img src="${foto}" class="avatar" referrerpolicy="no-referrer" onerror="this.outerHTML='<div class=\\'avatar-fallback\\'>${inicial}</div>'">`
                    : `<div class="avatar-fallback">${inicial}</div>`;

  let ids = '';
  if (S.perfSel !== 'Institucionales') {
    const validId = id => {
      const v = String(id || '').trim();
      return v && !['NA', 'N/A', '#N/A', 'NULL', 'SIN CLASIFICACIÓN'].includes(v.toUpperCase());
    };
    // Una celda puede traer varios identificadores (p.ej. "DVH-0552-2022; D-3696-2009"),
    // y una persona puede tener varios IDs repartidos en distintas filas: se juntan todos.
    const splitMulti = v => String(v || '').split(/[;,]/).map(x => x.trim()).filter(Boolean);
    const collectIds = col => uniq(dv.flatMap(r => splitMulti(r[col])).filter(validId));
    const scopusIds = collectIds('SCOPUS_ID');
    const wosIds = collectIds('WOS_ID');
    const scopusBlock = scopusIds.length ? `<div class="pl-h">Identificadores Scopus</div>` +
      scopusIds.map(id => {
        id = String(id).trim();
        return `<div class="prod-row"><span class="k">Scopus ID</span><a class="id-link" target="_blank" rel="noopener" href="https://www.scopus.com/authid/detail.uri?authorId=${encodeURIComponent(id)}">${id} <i class="fa-solid fa-arrow-up-right-from-square" style="font-size:.7rem;"></i></a></div>`;
      }).join('') : '';
    const wosBlock = wosIds.length ? `<div class="pl-h">Identificadores Web of Science</div>` +
      wosIds.map(id => {
        id = String(id).trim();
        return `<div class="prod-row"><span class="k">WOS ID</span><a class="id-link" target="_blank" rel="noopener" href="https://www.webofscience.com/wos/author/record/${encodeURIComponent(id)}">${id} <i class="fa-solid fa-arrow-up-right-from-square" style="font-size:.7rem;"></i></a></div>`;
      }).join('') : '';
    ids = scopusBlock + wosBlock;
  }

  document.getElementById('profile_card').innerHTML = `
    ${avatar}
    <div style="font-family:'Fraunces';font-weight:600;font-size:1.05rem;line-height:1.25;margin-bottom:2px;">${nombre}</div>
    <div style="font-size:.78rem;color:var(--muted);">${S.perfSel === 'Institucionales' ? 'Unidad académica' : 'Académico(a)'}</div>
    <div class="prod-list">
      <div class="pl-h">Producción</div>
      <div class="prod-row"><span class="k">Total</span><span class="v">${total}</span></div>
      <div class="prod-row"><span class="k">Web of Science</span><span class="v">${wos}<span class="vp">${pct(wos)}%</span></span></div>
      <div class="prod-row"><span class="k">Scopus</span><span class="v">${sco}<span class="vp">${pct(sco)}%</span></span></div>
      ${ids}
    </div>`;
}

/* ---------- 1. Barras por año ---------- */
function plotAnios(rows) {
  const counts = {}; for (let y = S.yMin; y <= S.yMax; y++) counts[y] = 0;
  rows.forEach(r => { const y = int0(r.ANO); if (y >= S.yMin && y <= S.yMax) counts[y]++; });
  const x = Object.keys(counts), y = x.map(k => counts[k]);
  Plotly.newPlot('v_anios', [{
    type: 'bar', x, y, marker: { color: C.emerald, line: { width: 0 } },
    hovertemplate: '<b>%{x}</b> · %{y} pub.<extra></extra>'
  }], Object.assign({}, PLAYOUT, {
    margin: { t: 14, r: 14, b: 48, l: 44 },
    xaxis: { dtick: 1, tickangle: -45, gridcolor: 'rgba(0,0,0,0)' },
    yaxis: { gridcolor: C.line, zeroline: false }, bargap: 0.45
  }), PCFG);
}

/* ---------- 2. Sankey rediseñado ---------- */
function plotSankey(rows) {
  const links = new Map();
  const tgtTotals = new Map();
  rows.forEach(r => {
    const src = titleCase(stripParen(r.AREA_COMPUTACION).trim());
    String(r.AREAS || '').split('; ').forEach(a => {
      a = a.trim(); if (a === 'Computer Science') return;
      let tgt = (a === '#N/A' ? 'Sin clasificación' : titleCase(a));
      if (!src || !tgt) return;
      const k = src + '||' + tgt; links.set(k, (links.get(k) || 0) + 1);
      tgtTotals.set(tgt, (tgtTotals.get(tgt) || 0) + 1);
    });
  });
  if (!links.size) { document.getElementById('v_sankey').innerHTML = '<div class="empty">Sin datos de áreas para este perfil.</div>'; return; }

  // Limitar destinos a top 10; agrupar el resto en "Otras áreas"
  const TOPN = 10;
  const topTargets = new Set([...tgtTotals.entries()].sort((a, b) => b[1] - a[1]).slice(0, TOPN).map(e => e[0]));
  const merged = new Map();
  links.forEach((v, k) => {
    let [a, b] = k.split('||');
    if (!topTargets.has(b)) b = 'Otras áreas';
    const nk = a + '||' + b; merged.set(nk, (merged.get(nk) || 0) + v);
  });

  const srcTotals = new Map();
  merged.forEach((v, k) => { const a = k.split('||')[0]; srcTotals.set(a, (srcTotals.get(a) || 0) + v); });
  const sourcesSorted = [...srcTotals.entries()].sort((a, b) => b[1] - a[1]).map(e => e[0]);

  const nodes = [], nodeColor = [], nodeX = [], nodeY = [];
  const srcMax = Math.max(...srcTotals.values());
  const idx = (name, isSource) => {
    let i = nodes.indexOf(name);
    if (i < 0) {
      nodes.push(name);
      if (isSource) nodeColor.push(CAT[sourcesSorted.indexOf(name) % CAT.length]);
      else nodeColor.push(name === 'Otras áreas' ? '#9aa0a6' : C.amber);
      i = nodes.length - 1;
    }
    return i;
  };
  const s = [], t = [], v = [], lc = [];
  // ordenar links por volumen para apilado prolijo
  [...merged.entries()].sort((a, b) => b[1] - a[1]).forEach(([k, val]) => {
    const [a, b] = k.split('||');
    const si = idx(a, true), ti = idx(b, false);
    s.push(si); t.push(ti); v.push(val);
    lc.push(hexA(nodeColor[si], 0.34));
  });

  Plotly.newPlot('v_sankey', [{
    type: 'sankey', orientation: 'h',
    arrangement: 'snap',
    valueformat: ',d', valuesuffix: ' pub.',
    node: {
      label: nodes, color: nodeColor, pad: 22, thickness: 16,
      line: { color: 'rgba(255,255,255,.6)', width: 1 },
      hovertemplate: '<b>%{label}</b><br>%{value}<extra></extra>'
    },
    link: {
      source: s, target: t, value: v, color: lc,
      hovertemplate: '%{source.label} → %{target.label}<br><b>%{value}</b><extra></extra>'
    }
  }], Object.assign({}, PLAYOUT, {
    margin: { t: 14, b: 14, l: 10, r: 10 },
    font: { family: 'Inter', size: 12, color: C.ink },
    annotations: [
      { x: 0.01, y: 1.06, xref: 'paper', yref: 'paper', text: 'ESPECIALIDAD', showarrow: false,
        font: { size: 10, color: C.muted, family: 'Inter' }, xanchor: 'left' },
      { x: 0.99, y: 1.06, xref: 'paper', yref: 'paper', text: 'APLICACIÓN', showarrow: false,
        font: { size: 10, color: C.muted, family: 'Inter' }, xanchor: 'right' }
    ]
  }), PCFG);
}
function hexA(hex, a) {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}

/* ---------- 3a. Barras palabras ---------- */
function plotPalabras(rows) {
  const f = kwFold(rows, 'INDEX_PALABRAS_CLAVES', 'title').slice(0, 20).reverse();
  if (!f.length) { document.getElementById('v_words').innerHTML = '<div class="empty">Sin palabras clave.</div>'; return; }
  Plotly.newPlot('v_words', [{
    type: 'bar', orientation: 'h', y: f.map(e => e[0]), x: f.map(e => e[1]),
    marker: { color: C.emerald }, hovertemplate: '%{y}: %{x}<extra></extra>'
  }], Object.assign({}, PLAYOUT, {
    margin: { t: 10, r: 16, b: 40, l: 230 },
    xaxis: { gridcolor: C.line, zeroline: false }, yaxis: { automargin: true }, bargap: 0.3
  }), PCFG);
}

/* ---------- 3b. Comparación chi² ---------- */
const FIELD = { 'Palabras claves': 'INDEX_PALABRAS_CLAVES', 'Áreas de especialidad': 'AREA_COMPUTACION', 'Áreas de aplicación': 'AREAS', 'Subáreas de aplicación': 'CATEGORIAS' };
function chiRes(a, ta, b, tb) {
  const N = ta + tb; if (!N) return 0;
  const exp = (a + b) * ta / N; if (!exp) return 0;
  return (a - exp) / Math.sqrt(exp);
}
function plotComparacion(dv, dfFull, comp, vari) {
  const field = FIELD[vari] || 'INDEX_PALABRAS_CLAVES';
  const setV = new Set(dv.map(r => r.NOMBRE_AUTOR));
  const grupo = comp === 'EL RESTO DE ACADÉMICOS(AS)' ? dfFull.filter(r => !setV.has(r.NOMBRE_AUTOR)) : dfFull.filter(r => r.NOMBRE_AUTOR === comp);
  const dict = kwDict(field);
  const countKey = rs => { const m = new Map(); rs.forEach(r => String(r[field] || '').split(/[;,|]/).forEach(t => { const k = kwKey(t); if (k) m.set(k, (m.get(k) || 0) + 1); })); return m; };
  const fa = countKey(dv), fg = countKey(grupo);
  const ta = [...fa.values()].reduce((a, b) => a + b, 0), tg = [...fg.values()].reduce((a, b) => a + b, 0);
  const words = uniq([...fa.keys(), ...fg.keys()]);
  const rows = words.map(k => { const x = fa.get(k) || 0, y = fg.get(k) || 0; return { w: titleCase(dict.get(k) || k), x, y, chi: chiRes(x, ta, y, tg) }; });
  const top = [...rows.filter(r => r.chi > 0).sort((a, b) => b.chi - a.chi).slice(0, 10),
              ...rows.filter(r => r.chi < 0).sort((a, b) => a.chi - b.chi).slice(0, 10)].sort((a, b) => a.chi - b.chi);
  if (!top.length) { document.getElementById('v_words').innerHTML = '<div class="empty">Sin términos comparables.</div>'; return; }
  Plotly.newPlot('v_words', [{
    type: 'bar', orientation: 'h',
    y: top.map(r => `${r.w}  (${r.x}/${r.y})`), x: top.map(r => r.chi),
    marker: { color: top.map(r => r.chi > 0 ? C.emerald : C.rust) },
    hovertemplate: '%{y}<br>residuo χ²: %{x:.2f}<extra></extra>'
  }], Object.assign({}, PLAYOUT, {
    margin: { t: 10, r: 16, b: 44, l: 250 },
    xaxis: { title: { text: 'sobre-representado (+) · sub-representado (−)', font: { size: 11 } }, gridcolor: C.line, zeroline: true, zerolinecolor: C.muted },
    yaxis: { automargin: true }, bargap: 0.28
  }), PCFG);
}

/* ---------- 4. Fuentes ---------- */
function plotFuentes(rows) {
  const f = sortEnt(countBy(rows.map(r => r.FUENTE))).slice(0, 20).reverse();
  if (!f.length) { document.getElementById('v_fuentes').innerHTML = '<div class="empty">Sin datos.</div>'; return; }
  Plotly.newPlot('v_fuentes', [{
    type: 'bar', orientation: 'h', y: f.map(e => e[0]), x: f.map(e => e[1]),
    marker: { color: C.amber }, hovertemplate: '%{y}: %{x}<extra></extra>'
  }], Object.assign({}, PLAYOUT, {
    margin: { t: 10, r: 16, b: 40, l: 320 },
    xaxis: { gridcolor: C.line, zeroline: false }, yaxis: { automargin: true }, bargap: 0.3
  }), PCFG);
}

/* ---------- 5. Red coautorías ---------- */
function plotRed(rows, destacado) {
  const cont = document.getElementById('v_red');
  if (!rows.length) { cont.innerHTML = '<div class="empty">Sin datos.</div>'; return; }
  const nm = new Map();      // clave: nombre normalizado -> nodo
  const id2key = new Map();  // SCOPUS_ID -> nombre normalizado (para resolver aristas)
  const splitMulti = v => String(v || '').split(/[;,]/).map(x => x.trim()).filter(Boolean);
  rows.forEach(r => {
    const key = normTxt(r.NOMBRE_AUTOR);
    if (!key) return;
    const name = titleCase(r.NOMBRE_AUTOR);
    if (!nm.has(key)) nm.set(key, { id: key, label: name, n: 0 });
    nm.get(key).n++;
    splitMulti(r.SCOPUS_ID).forEach(sid => id2key.set(sid, key));
  });
  const target = destacado ? titleCase(destacado) : '';
  const nodes = [...nm.values()].map(o => ({
    id: o.id, label: o.label, value: o.n, title: `${o.label} · ${o.n} pub.`,
    color: o.label === target
      ? { background: C.amber, border: C.rust }
      : { background: C.emeraldSoft, border: C.emerald },
    font: { color: C.ink, size: 13, face: 'Inter' }
  }));
  const keySet = new Set(nm.keys());
  const em = new Map();
  rows.forEach(r => { const from = normTxt(r.NOMBRE_AUTOR);
    if (!keySet.has(from)) return;
    splitIds(r.AUTORES_ID).forEach(aid => { const to = id2key.get(aid);
      if (!to || to === from || !keySet.has(to)) return;
      const k = [from, to].sort().join('|'); em.set(k, (em.get(k) || 0) + 1); }); });
  const edges = [...em.entries()].map(([k, w]) => { const [a, b] = k.split('|');
    const la = (nm.get(a) || {}).label || a, lb = (nm.get(b) || {}).label || b;
    return { from: a, to: b, value: w, title: `${la} ↔ ${lb} · ${w} pub. compartidas`,
             width: Math.min(w, 6), color: { color: 'rgba(111,106,96,.3)', highlight: C.emerald, hover: C.emerald } }; });
  cont.innerHTML = '';
  if (_net) { _net.destroy(); _net = null; }
  const nodeData = new vis.DataSet(nodes);
  const edgeData = new vis.DataSet(edges);
  _net = new vis.Network(cont, { nodes: nodeData, edges: edgeData }, {
    nodes: { shape: 'dot', scaling: { min: 10, max: 44 }, borderWidth: 2, shadow: { enabled: true, size: 6, x: 0, y: 2, color: 'rgba(28,27,24,.15)' } },
    edges: { smooth: { type: 'continuous' } },
    physics: { stabilization: false, barnesHut: { gravitationalConstant: -7000, springLength: 130, springConstant: 0.03 } },
    interaction: { hover: true, tooltipDelay: 120 }
  });
  // Clic en nodo o arista -> muestra la frecuencia en la barra de estado
  _net.on('click', p => {
    const st = document.getElementById('red_search_status'); if (!st) return;
    if (p.nodes && p.nodes.length) {
      const nd = nodeData.get(p.nodes[0]);
      if (nd) st.textContent = `${nd.label} · ${nd.value} pub.`;
    } else if (p.edges && p.edges.length) {
      const ed = edgeData.get(p.edges[0]);
      if (ed) { const a = nodeData.get(ed.from), b = nodeData.get(ed.to);
        st.textContent = `${a ? a.label : ed.from} ↔ ${b ? b.label : ed.to} · ${ed.value} pub. compartidas`; }
    }
  });
  wireRedSearch(nodes);
}

function wireRedSearch(nodes) {
  const select = document.getElementById('red_select');
  const btn = document.getElementById('red_search_btn');
  const clear = document.getElementById('red_clear_btn');
  const status = document.getElementById('red_search_status');
  if (!select || !btn || !clear || !_net) return;
  const items = nodes.slice().sort((a, b) => String(a.label).localeCompare(String(b.label), 'es'));
  select.innerHTML = '<option value="">Selecciona académico(a)...</option>' +
    items.map(n => `<option value="${escAttr(n.id)}">${escAttr(n.label)}</option>`).join('');
  const setStatus = msg => { if (status) status.textContent = msg || ''; };
  const focusNode = () => {
    const id = select.value;
    if (!id) { setStatus('Selecciona un académico(a).'); return; }
    const hit = items.find(x => String(x.id) === String(id));
    if (!hit) { _net.unselectAll(); setStatus('No se encontró el nodo.'); return; }
    _net.selectNodes([hit.id]);
    _net.focus(hit.id, { scale: 1.45, animation: { duration: 650, easingFunction: 'easeInOutQuad' } });
    setStatus(hit.label);
  };
  btn.onclick = focusNode;
  select.onchange = focusNode;
  clear.onclick = () => {
    select.value = '';
    setStatus('');
    _net.unselectAll();
    _net.fit({ animation: { duration: 500, easingFunction: 'easeInOutQuad' } });
  };
}

/* ---------- 6. Dendrogramas ---------- */
const STOP = new Set('de la que el en y a los del se las por un para con no una su al lo como mas pero sus le ya o este si porque esta entre cuando muy sin sobre tambien me hasta hay donde quien desde todo nos durante todos uno les ni contra otros ese eso ante ellos esto antes the of and to in for is on with as at by an be this are from'.split(' '));
function tfMatrix(rows) {
  const by = new Map();
  rows.forEach(r => { const a = r.NOMBRE_AUTOR;
    const t = [r.INDEX_PALABRAS_CLAVES, r.RESUMEN, r.CATEGORIAS, r.AREAS].join(' ');
    by.set(a, (by.get(a) || '') + ' ' + t); });
  const autores = [...by.keys()]; const vocab = new Map();
  const toks = autores.map(a => { const ws = by.get(a).toLowerCase().replace(/[^a-záéíóúñ\s]/g, ' ').split(/\s+/).filter(w => w.length > 2 && !STOP.has(w));
    ws.forEach(w => { if (!vocab.has(w)) vocab.set(w, vocab.size); }); return ws; });
  const V = vocab.size;
  const M = toks.map(ws => { const v = new Float64Array(V); ws.forEach(w => v[vocab.get(w)]++); return v; });
  return { autores, M };
}
const euclid = (a, b) => { let s = 0; for (let i = 0; i < a.length; i++) { const d = a[i] - b[i]; s += d * d; } return Math.sqrt(s); };
function corrDist(a, b) { const n = a.length; let ma = 0, mb = 0;
  for (let i = 0; i < n; i++) { ma += a[i]; mb += b[i]; } ma /= n; mb /= n;
  let nu = 0, da = 0, db = 0; for (let i = 0; i < n; i++) { const x = a[i] - ma, y = b[i] - mb; nu += x * y; da += x * x; db += y * y; }
  return (da === 0 || db === 0) ? 1 : 1 - nu / Math.sqrt(da * db); }
function hclust(M, distFn) {
  const n = M.length;
  let cl = M.map((_, i) => ({ leaf: true, index: i }));
  let D = []; for (let i = 0; i < n; i++) { D[i] = []; for (let j = 0; j < n; j++) D[i][j] = i === j ? 0 : distFn(M[i], M[j]); }
  while (cl.length > 1) {
    let bi = 0, bj = 1, best = Infinity;
    for (let i = 0; i < cl.length; i++) for (let j = i + 1; j < cl.length; j++) if (D[i][j] < best) { best = D[i][j]; bi = i; bj = j; }
    const merged = { leaf: false, height: best, children: [cl[bi], cl[bj]] };
    const newD = [];
    for (let k = 0; k < cl.length; k++) { if (k === bi || k === bj) continue; newD.push(Math.max(D[bi][k], D[bj][k])); }
    const keep = cl.filter((_, k) => k !== bi && k !== bj);
    const kD = [];
    for (let i = 0; i < cl.length; i++) { if (i === bi || i === bj) continue; const row = [];
      for (let j = 0; j < cl.length; j++) { if (j === bi || j === bj) continue; row.push(D[i][j]); } kD.push(row); }
    keep.push(merged); kD.forEach((row, i) => row.push(newD[i])); kD.push([...newD, 0]);
    cl = keep; D = kD;
  }
  return cl[0];
}
function plotDendro(id, rows, metodo, resaltado) {
  const cont = document.getElementById(id);
  const { autores, M } = tfMatrix(rows);
  if (autores.length < 2) { cont.innerHTML = '<div class="empty">Se necesitan al menos 2 académicos(as).</div>'; return; }
  let tree; try { tree = hclust(M, metodo === 'correlation' ? corrDist : euclid); }
  catch (e) { cont.innerHTML = '<div class="empty">No fue posible calcular.</div>'; return; }
  const segs = []; const order = [];
  (function leaves(n) { if (n.leaf) { order.push(n.index); return; } n.children.forEach(leaves); })(tree);
  const xp = new Map(); order.forEach((idx, i) => xp.set(idx, i));
  (function draw(n) { if (n.leaf) return { x: xp.get(n.index), y: 0 };
    const pts = n.children.map(draw); const x = pts.reduce((s, p) => s + p.x, 0) / pts.length; const y = n.height;
    pts.forEach(p => { segs.push({ x: [p.x, p.x], y: [p.y, y] }); segs.push({ x: [p.x, x], y: [y, y] }); });
    return { x, y }; })(tree);
  const shapes = segs.map(s => ({ type: 'line', x0: s.x[0], y0: s.y[0], x1: s.x[1], y1: s.y[1], line: { color: C.muted, width: 1.2 } }));
  let hi = -1;
  if (resaltado) hi = autores.findIndex(a => a.trim().toLowerCase() === String(resaltado).trim().toLowerCase());
  let maxH = 0; segs.forEach(s => { maxH = Math.max(maxH, s.y[0], s.y[1]); });
  const annos = [];
  if (hi >= 0 && xp.has(hi)) {
    const xr = xp.get(hi);
    // banda vertical translúcida que cubre toda la altura
    shapes.push({ type: 'rect', xref: 'x', yref: 'y', x0: xr - .5, x1: xr + .5, y0: 0, y1: maxH * 1.05,
      fillcolor: hexA(C.amber, 0.16), line: { width: 0 }, layer: 'below' });
    // línea de eje del académico
    shapes.push({ type: 'line', x0: xr, x1: xr, y0: 0, y1: maxH * 1.05, line: { color: C.amber, width: 1.4, dash: 'dot' } });
    // marcador-triángulo en la base apuntando a su hoja
    annos.push({ x: xr, y: 0, xref: 'x', yref: 'y', text: '▲', showarrow: false,
      font: { color: C.amber, size: 14 }, yanchor: 'top', yshift: -2 });
  }
  Plotly.newPlot(id, [{ x: [0], y: [0], mode: 'markers', marker: { opacity: 0 }, hoverinfo: 'skip' }],
    Object.assign({}, PLAYOUT, { shapes, annotations: annos, margin: { t: 14, r: 14, b: 150, l: 44 },
      xaxis: { tickvals: order.map((_, i) => i),
        ticktext: order.map(i => i === hi ? `<b style="color:${C.amber}">${titleCase(autores[i])}</b>` : titleCase(autores[i])),
        tickangle: -45, range: [-0.7, order.length - 0.3], zeroline: false, gridcolor: 'rgba(0,0,0,0)' },
      yaxis: { title: 'distancia', zeroline: false, gridcolor: C.line, range: [0, maxH * 1.05] } }), PCFG);
}

/* ---------- 7. Mapa ---------- */
function plotMapa(rows) {
  if (!_map) {
    _map = L.map('map', { scrollWheelZoom: false, zoomControl: true }).setView([15, -30], 2);
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      { attribution: '© OpenStreetMap · © CARTO', subdomains: 'abcd', maxZoom: 18 }).addTo(_map);
  }
  if (_mapLayer) { _map.removeLayer(_mapLayer); _mapLayer = null; }
  const conteo = new Map();
  rows.forEach(r => { if (!r.PAISES_AUTORES) return;
    r.PAISES_AUTORES.split(', ').forEach(p => { p = p.trim(); if (p) conteo.set(p, (conteo.get(p) || 0) + 1); }); });
  const layer = L.layerGroup();
  let any = false, maxF = Math.max(1, ...conteo.values());
  conteo.forEach((f, pais) => {
    const c = COUNTRY_COORDS[pais] || COUNTRY_ALIAS[pais];
    if (!c) return; any = true;
    const rad = 6 + Math.sqrt(f / maxF) * 22;
    L.circleMarker([c[0], c[1]], { radius: rad, color: C.emerald2, weight: 1.5, fillColor: C.emerald, fillOpacity: .55 })
      .bindTooltip(`<b>${pais}</b> · ${f} colaboración${f > 1 ? 'es' : ''}`, { sticky: true })
      .addTo(layer);
  });
  layer.addTo(_map); _mapLayer = layer;
  // crucial: recalcular tamaño cuando el contenedor pasa de oculto a visible
  setTimeout(() => { _map.invalidateSize(); }, 60);
  setTimeout(() => { _map.invalidateSize(); }, 350);
  if (!any) cont_empty('map');
}
function cont_empty(id) { /* el mapa siempre muestra el fondo aunque no haya puntos */ }

/* ============================================================
   ORQUESTADOR PERFILES
   ============================================================ */
function buildPerfiles() {
  const { dfFull, dv } = perfilCtx();
  if (!dv.length) { document.getElementById('profile_card').innerHTML = '<div class="empty">Sin datos para el filtro actual.</div>'; return; }
  renderFicha(dv);
  plotAnios(dv); plotSankey(dv); plotFuentes(dv);
  const indiv = document.getElementById('perfil-individual');
  const cs = document.getElementById('compare_sel');
  const wt = document.getElementById('v_words_title');
  if (S.perfSel === 'Institucionales') {
    if (indiv) indiv.style.display = '';
    buildPerfilIndividual(dv, dfFull);
    cs.innerHTML = ''; wt.textContent = 'Palabras clave más frecuentes';
    plotPalabras(dv); plotRed(dv, null);
    plotDendro('v_dendro1', dv, 'euclidean', null);
    plotDendro('v_dendro2', dv, 'correlation', null);
  } else {
    if (indiv) indiv.style.display = '';
    buildPerfilIndividual(dv, dfFull);
    cs.innerHTML = '';
    wt.textContent = 'Palabras clave más frecuentes';
    plotPalabras(dv);
    plotRed(dfFull, S.perfAutor);
    plotDendro('v_dendro1', dfFull, 'euclidean', S.perfAutor);
    plotDendro('v_dendro2', dfFull, 'correlation', S.perfAutor);
  }
  plotMapa(dv);
}

/* ============================================================
   ORQUESTADOR DOMINIO
   ============================================================ */
const DOMF = { 'Áreas de especialidad': 'AREA_COMPUTACION', 'Áreas de aplicación': 'AREAS', 'Subáreas de aplicación': 'CATEGORIAS', 'Áreas OCDE': 'DISCIPLINA_OCDE', 'Subáreas OCDE': 'AREA_OCDE', 'Áreas ODS': 'AREA_ODS_ANID', 'Palabras claves': 'INDEX_PALABRAS_CLAVES' };
function domProcessed() {
  let rows = base();
  if (S.domDoc === 'WOS') rows = rows.filter(r => r.WOS === 'SI');
  else if (S.domDoc === 'SCOPUS') rows = rows.filter(r => r.WOS === 'NO');
  const field = DOMF[S.domDom]; const recs = [];
  const noSplit = (field === 'DISCIPLINA_OCDE' || field === 'AREA_OCDE' || field === 'AREA_ODS_ANID');
  rows.forEach(r => {
    const raw = String(r[field] || '');
    (noSplit ? [raw] : raw.split(/[;,|]/)).forEach(d => {
      let w = kwLabel(d, field);
      if (w) recs.push({ Autor: titleCase(r.NOMBRE_AUTOR), Palabra: w, Anio: int0(r.ANO) });
    });
  });
  return recs;
}
function buildDomPalabras() {
  const recs = domProcessed();
  const palabras = uniq(recs.map(r => r.Palabra).filter(p => !/^[-/]/.test(p))).sort();
  const sel = document.getElementById('dom_palabra'); const prev = S.domPalabra;
  sel.innerHTML = palabras.map(p => `<option>${p}</option>`).join('');
  if (prev && palabras.includes(prev)) sel.value = prev;
  S.domPalabra = sel.value || palabras[0] || null;
}
function buildDominio() {
  const recs = domProcessed(); const cont = document.getElementById('v_dominio');
  if (!recs.length) { cont.innerHTML = '<div class="empty">No hay datos para los filtros seleccionados.</div>'; return; }
  const data = recs.filter(r => r.Palabra === S.domPalabra);
  if (!data.length) { Plotly.purge('v_dominio'); cont.innerHTML = '<div class="empty">Sin datos para ese término.</div>'; return; }
  const agg = new Map();
  data.forEach(r => { const k = r.Autor + '||' + r.Anio; agg.set(k, (agg.get(k) || 0) + 1); });
  const autores = uniq(data.map(r => r.Autor)).sort().reverse();
  const yMin = Math.min(...data.map(r => r.Anio)), yMax = Math.max(...data.map(r => r.Anio));
  const maxF = Math.max(...agg.values());
  const shapes = [];
  agg.forEach((f, k) => { const [a, an] = k.split('||'); const yi = autores.indexOf(a);
    const ratio = maxF > 1 ? (f - 1) / (maxF - 1) : 1;
    shapes.push({ type: 'line', x0: +an - 0.42, x1: +an + 0.42, y0: yi, y1: yi,
      line: { color: lerpEmerald(ratio), width: 9 }, opacity: 0.35 + 0.65 * ratio }); });
  cont.innerHTML = '';
  Plotly.newPlot('v_dominio', [{ x: data.map(r => r.Anio), y: data.map(r => r.Autor), mode: 'markers',
    marker: { opacity: 0 }, hovertext: data.map(r => `${r.Autor} · ${r.Anio}`), hoverinfo: 'text' }],
    Object.assign({}, PLAYOUT, { shapes, margin: { t: 14, r: 16, b: 54, l: 220 },
      xaxis: { title: 'año', dtick: 1, tick0: yMin, range: [yMin - 1, yMax + 1], gridcolor: C.line, zeroline: false },
      yaxis: { type: 'category', automargin: true, categoryorder: 'array', categoryarray: autores, gridcolor: 'rgba(0,0,0,0)' } }), PCFG);
}
function lerpEmerald(t) { const c1 = [200, 235, 232], c2 = [0, 122, 114];
  const c = c1.map((v, i) => Math.round(v + (c2[i] - v) * t)); return `rgb(${c[0]},${c[1]},${c[2]})`; }
