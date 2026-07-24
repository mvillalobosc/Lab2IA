/* ============================================================
   PERFIL INDIVIDUAL ENRIQUECIDO — vista por académico(a)
   Aprovecha: AUTORES, AUTORES_ID, LINK, DOI, QUARTILE, SJR,
   CITADO_POR, PAISES_AUTORES, IDIOMA, TIPO_DOCUMENTO, etc.
   ============================================================ */

/* empareja nombre↔id de coautores (van por posición) */
function pairAuthors(r) {
  const names = String(r.AUTORES || '').split(';').map(x => x.trim()).filter(Boolean);
  const ids = String(r.AUTORES_ID || '').split(';').map(x => x.trim()).filter(Boolean);
  return names.map((n, i) => ({ name: n, id: ids[i] || '' }));
}
function paperLink(r) {
  const doi = String(r.DOI || '').trim();
  if (doi && !['na', 'n/a', '#n/a', 'null', ''].includes(doi.toLowerCase())) return 'https://doi.org/' + doi;
  const lk = String(r.LINK || '').trim();
  if (lk && /^https?:\/\//.test(lk)) return lk;
  return null;
}
function gIndexOf(cites) {
  const s = [...cites].sort((a, b) => b - a); let acc = 0, g = 0;
  for (let i = 0; i < s.length; i++) { acc += s[i]; if (acc >= (i + 1) * (i + 1)) g = i + 1; else break; }
  return g;
}

/* ---------- A. Banda de métricas individuales ---------- */
function renderPerfilMetrics(dv) {
  const cont = document.getElementById('perfil_metrics');
  if (!cont) return;
  const TP = dv.length;
  const TC = dv.reduce((s, r) => s + int0(r.CITADO_POR), 0);
  const H = hIndex(dv.map(r => int0(r.CITADO_POR)));
  const G = gIndexOf(dv.map(r => int0(r.CITADO_POR)));
  const arts = dv.filter(r => r.TIPO_DOCUMENTO === 'Article');
  const Q1 = dv.filter(r => String(r.QUARTILE).toUpperCase() === 'Q1').length;
  const an = dv.map(r => int0(r.ANO)).filter(y => y > 1900);
  const span = an.length ? (Math.max(...an) - Math.min(...an) + 1) : 0;
  const excl = (typeof S !== 'undefined' && S.perfSel === 'Institucionales') ? new Set() : new Set(uniq(dv.map(r => String(r.SCOPUS_ID || '').trim()).filter(Boolean)));
  const coIds = new Set();
  dv.forEach(r => pairAuthors(r).forEach(p => { if (p.id && !excl.has(p.id)) coIds.add(p.id); }));
  let intl = 0; dv.forEach(r => { const ps = String(r.PAISES_AUTORES || '').split(', ').map(x => x.trim()).filter(Boolean); if (ps.some(p => p && p !== 'Chile')) intl++; });
  const sjrVals = dv.map(r => num(r.SJR)).filter(x => x > 0);
  const sjrAvg = sjrVals.length ? nf(sjrVals.reduce((a, b) => a + b) / sjrVals.length) : '0';

  const cards = [
    ['Publicaciones', TP, 'fa-layer-group', ''],
    ['Citas totales', TC.toLocaleString('es'), 'fa-quote-right', ''],
    ['Índice h', H, 'fa-ranking-star', 'amber'],
    ['Índice g', G, 'fa-chart-line', 'amber'],
    ['Citas / pub.', TP ? nf(TC / TP) : '0', 'fa-divide', ''],
    ['% en Q1', arts.length ? Math.round(Q1 / arts.length * 100) + '%' : '0%', 'fa-award', ''],
    ['SJR medio', sjrAvg, 'fa-star', 'amber'],
    ['Coautores', coIds.size, 'fa-users', ''],
    ['% internac.', TP ? Math.round(intl / TP * 100) + '%' : '0%', 'fa-earth-americas', ''],
    ['Años activo', span, 'fa-calendar', '']
  ];
  cont.innerHTML = cards.map(c => `
    <div class="pm-card ${c[3]}">
      <div class="pm-ic"><i class="fa-solid ${c[2]}"></i></div>
      <div class="pm-v">${c[1]}</div>
      <div class="pm-l">${c[0]}</div>
    </div>`).join('');
}

/* ---------- B. Lista de publicaciones (DataTable) ---------- */
function renderPerfilPubs(dv) {
  const sel = '#perfil_pubs_table';
  if ($.fn.DataTable.isDataTable(sel)) { $(sel).DataTable().destroy(); }
  $(sel).empty();
  const rows = [...dv].sort((a, b) => int0(b.ANO) - int0(a.ANO) || int0(b.CITADO_POR) - int0(a.CITADO_POR))
    .map(r => {
      const link = paperLink(r);
      const titulo = link
        ? `<a href="${link}" target="_blank" rel="noopener" class="pub-link">${r.TITULO || '—'} <i class="fa-solid fa-arrow-up-right-from-square"></i></a>`
        : (r.TITULO || '—');
      const q = String(r.QUARTILE || '').toUpperCase();
      const qBadge = /^Q[1-4]$/.test(q) ? `<span class="q-badge q-${q.toLowerCase()}">${q}</span>` : '';
      const tipo = r.TIPO_DOCUMENTO === 'Article' ? 'Revista' : (r.TIPO_DOCUMENTO === 'Conference paper' ? 'Conferencia' : (r.TIPO_DOCUMENTO || ''));
      return [titulo, int0(r.ANO) || '', r.FUENTE || '', tipo, qBadge, num(r.SJR) ? nf(num(r.SJR)) : '', int0(r.CITADO_POR)];
    });
  $(sel).DataTable({
    data: rows,
    columns: [
      { title: 'Título', className: 'pub-title' },
      { title: 'Año', className: 'dt-num' },
      { title: 'Fuente' },
      { title: 'Tipo' },
      { title: 'Q', className: 'dt-num' },
      { title: 'SJR', className: 'dt-num' },
      { title: 'Citas', className: 'dt-num' }
    ],
    order: [[1, 'desc']], pageLength: 10, scrollX: true,
    dom: 'Bfrtip', buttons: [{ extend: 'csv', text: '↓ CSV', className: 'dt-button' }],
    language: dtLang()
  });
}

/* ---------- C. Top coautores ---------- */
function renderPerfilCoautores(dv, dfFull) {
  const cont = document.getElementById('perfil_coautores');
  if (!cont) return;
  const excl = (typeof S !== 'undefined' && S.perfSel === 'Institucionales') ? new Set() : new Set(uniq(dv.map(r => String(r.SCOPUS_ID || '').trim()).filter(Boolean)));
  const internos = new Set(uniq(dfFull.map(r => r.SCOPUS_ID)));
  const co = {};
  dv.forEach(r => {
    const paises = String(r.PAISES_AUTORES || '');
    pairAuthors(r).forEach(p => {
      if (!p.id || excl.has(p.id)) return;
      if (!co[p.id]) co[p.id] = { name: p.name, n: 0, interno: internos.has(p.id) };
      co[p.id].n++;
    });
  });
  const top = Object.values(co).sort((a, b) => b.n - a.n).slice(0, 12);
  if (!top.length) { cont.innerHTML = '<div class="empty">Sin coautorías registradas.</div>'; return; }
  const max = top[0].n;
  cont.innerHTML = top.map(c => `
    <div class="co-row">
      <span class="co-name">${titleCase(c.name)} ${c.interno ? '<span class="co-tag">unidad</span>' : ''}</span>
      <span class="co-track"><span class="co-fill ${c.interno ? 'int' : ''}" style="width:${c.n / max * 100}%"></span></span>
      <span class="co-n">${c.n}</span>
    </div>`).join('');
}

/* ---------- D. Trayectoria: publicaciones + citas acumuladas ---------- */
function plotPerfilTrayectoria(dv) {
  const el = document.getElementById('perfil_trayectoria'); if (!el) return;
  const yc = {}, cc = {};
  dv.forEach(r => { const y = int0(r.ANO); if (y > 1900) { yc[y] = (yc[y] || 0) + 1; cc[y] = (cc[y] || 0) + int0(r.CITADO_POR); } });
  const years = Object.keys(yc).map(Number).sort((a, b) => a - b);
  if (!years.length) { el.innerHTML = '<div class="empty">Sin datos temporales.</div>'; return; }
  const pubs = years.map(y => yc[y]);
  let acc = 0; const citAcc = years.map(y => (acc += cc[y]));
  Plotly.newPlot('perfil_trayectoria', [
    { type: 'bar', x: years, y: pubs, name: T('Publicaciones'), marker: { color: C.emerald }, yaxis: 'y', hovertemplate: '%{x}: %{y} pub.<extra></extra>' },
    { type: 'scatter', mode: 'lines+markers', x: years, y: citAcc, name: T('Citas acumuladas'), line: { color: C.amber, width: 3 }, marker: { size: 7, color: C.amber }, yaxis: 'y2', hovertemplate: '%{x}: %{y} citas acum.<extra></extra>' }
  ], Object.assign({}, PLAYOUT, {
    margin: { t: 16, r: 54, b: 44, l: 46 },
    xaxis: { dtick: 1, tickangle: -45, gridcolor: 'rgba(0,0,0,0)' },
    yaxis: { title: T('publicaciones'), gridcolor: C.line, zeroline: false },
    yaxis2: { title: T('citas acumuladas'), overlaying: 'y', side: 'right', gridcolor: 'rgba(0,0,0,0)', zeroline: false },
    legend: { orientation: 'h', y: 1.14, x: 0, font: { size: 11 } }, bargap: 0.45
  }), PCFG);
}

/* ---------- E. Distribución cuartil + tipo (dos donas) ---------- */
function plotPerfilDist(dv) {
  const el = document.getElementById('perfil_dist'); if (!el) return;
  const arts = dv.filter(r => r.TIPO_DOCUMENTO === 'Article');
  const q = { Q1: 0, Q2: 0, Q3: 0, Q4: 0 };
  arts.forEach(r => { const x = String(r.QUARTILE).toUpperCase(); if (q[x] !== undefined) q[x]++; });
  const sinQ = arts.length - (q.Q1 + q.Q2 + q.Q3 + q.Q4);
  const nArt = dv.filter(r => r.TIPO_DOCUMENTO === 'Article').length;
  const nConf = dv.filter(r => r.TIPO_DOCUMENTO === 'Conference paper').length;
  const nOtr = dv.length - nArt - nConf;
  Plotly.newPlot('perfil_dist', [
    { type: 'pie', hole: 0.62, domain: { column: 0 }, name: T('Cuartil'),
      labels: ['Q1', 'Q2', 'Q3', 'Q4', T('Sin Q')], values: [q.Q1, q.Q2, q.Q3, q.Q4, sinQ],
      marker: { colors: ['#00A499', '#55b9b0', '#9bd3ce', '#c9e7e4', '#e4e7ea'] },
      textinfo: 'label+value', textfont: { size: 11 }, sort: false, hoverinfo: 'label+value+percent' },
    { type: 'pie', hole: 0.62, domain: { column: 1 }, name: T('Tipo'),
      labels: [T('Revistas'), T('Conferencias'), T('Otros')], values: [nArt, nConf, nOtr],
      marker: { colors: ['#00A499', '#EA7600', '#9aa0a6'] },
      textinfo: 'label+value', textfont: { size: 11 }, sort: false, hoverinfo: 'label+value+percent' }
  ], Object.assign({}, PLAYOUT, {
    grid: { rows: 1, columns: 2 }, margin: { t: 30, r: 10, b: 10, l: 10 }, showlegend: false,
    annotations: [
      { text: T('CUARTIL'), x: 0.16, y: 1.08, xref: 'paper', yref: 'paper', showarrow: false, font: { size: 10, color: C.muted } },
      { text: T('TIPO'), x: 0.84, y: 1.08, xref: 'paper', yref: 'paper', showarrow: false, font: { size: 10, color: C.muted } }
    ]
  }), PCFG);
}

/* ---------- F. Revistas donde publica ---------- */
function renderPerfilRevistas(dv) {
  const cont = document.getElementById('perfil_revistas'); if (!cont) return;
  const map = new Map();
  dv.filter(r => r.FUENTE).forEach(r => {
    const k = r.FUENTE;
    if (!map.has(k)) map.set(k, { fuente: k, n: 0, sjr: num(r.SJR), q: String(r.QUARTILE).toUpperCase(), cit: 0 });
    const o = map.get(k); o.n++; o.cit += int0(r.CITADO_POR);
    if (num(r.SJR) > o.sjr) o.sjr = num(r.SJR);
  });
  const rows = [...map.values()].sort((a, b) => b.n - a.n || b.sjr - a.sjr).slice(0, 12);
  if (!rows.length) { cont.innerHTML = '<div class="empty">Sin datos de revistas.</div>'; return; }
  cont.innerHTML = `<table class="rev-table"><thead><tr><th>Revista / fuente</th><th>Pubs</th><th>Q</th><th>SJR</th><th>Citas</th></tr></thead><tbody>${
    rows.map(r => {
      const q = /^Q[1-4]$/.test(r.q) ? `<span class="q-badge q-${r.q.toLowerCase()}">${r.q}</span>` : '';
      return `<tr><td>${r.fuente}</td><td class="dt-num">${r.n}</td><td>${q}</td><td class="dt-num">${r.sjr ? nf(r.sjr) : ''}</td><td class="dt-num">${r.cit}</td></tr>`;
    }).join('')
  }</tbody></table>`;
}

/* ---------- G. Idiomas + métricas de formato ---------- */
function renderPerfilExtra(dv) {
  const cont = document.getElementById('perfil_extra'); if (!cont) return;
  const idiomas = countBy(dv.map(r => r.IDIOMA).filter(Boolean));
  const idiomaStr = [...idiomas.entries()].sort((a, b) => b[1] - a[1])
    .map(([k, v]) => `<span class="chip">${k} <b>${v}</b></span>`).join('');
  const conDOI = dv.filter(r => { const v = String(r.DOI || '').toLowerCase(); return v && !['', 'na', 'n/a', '#n/a', 'null'].includes(v); }).length;
  const conLink = dv.filter(r => paperLink(r)).length;
  const discE = [...countBy(dv.map(r => String(r.DISCIPLINA_OCDE || '').trim()).filter(v => v && v !== '#N/A')).entries()].sort((a, b) => b[1] - a[1]);
  const ocdeE = [...countBy(dv.map(r => String(r.AREA_OCDE || '').trim()).filter(v => v && v !== '#N/A')).entries()].sort((a, b) => b[1] - a[1]);
  const odsE = [...countBy(dv.map(r => String(r.AREA_ODS_ANID || '').trim()).filter(v => v && v !== '#N/A' && !/No claramente asociado/i.test(v))).entries()].sort((a, b) => b[1] - a[1]);
  const discStr = discE.slice(0, 4).map(([k, v]) => `<span class="chip">${k} <b>${v}</b></span>`).join('') || '—';
  const ocdeStr = ocdeE.slice(0, 4).map(([k, v]) => `<span class="chip">${k} <b>${v}</b></span>`).join('') || '—';
  const odsStr = odsE.slice(0, 4).map(([k, v]) => `<span class="chip">${k} <b>${v}</b></span>`).join('') || '—';
  cont.innerHTML = `
    <div class="extra-block"><div class="extra-h">Áreas OCDE</div><div class="chips">${discStr}</div></div>
    <div class="extra-block"><div class="extra-h">Subáreas OCDE</div><div class="chips">${ocdeStr}</div></div>
    <div class="extra-block"><div class="extra-h">Áreas ODS (ANID)</div><div class="chips">${odsStr}</div></div>
    <div class="extra-block"><div class="extra-h">Idiomas de publicación</div><div class="chips">${idiomaStr || '—'}</div></div>
    <div class="extra-block"><div class="extra-h">Accesibilidad</div>
      <div class="chips">
        <span class="chip">Con DOI <b>${conDOI}</b></span>
        <span class="chip">Con enlace <b>${conLink}</b></span>
      </div></div>`;
}

/* ---------- Orquestador del bloque individual ---------- */
function buildPerfilIndividual(dv, dfFull) {
  renderPerfilMetrics(dv);
  renderPerfilPubs(dv);
  renderPerfilCoautores(dv, dfFull);
  plotPerfilTrayectoria(dv);
  plotPerfilDist(dv);
  renderPerfilRevistas(dv);
  renderPerfilExtra(dv);
}
