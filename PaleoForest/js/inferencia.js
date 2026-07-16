/* Módulo 1 · Inferencia filogenética
   1. Matriz     — taxones, caracteres, estados, aditividad, pesos, ccode.
   2. Búsqueda   — adición + rearreglos + ratchet, en Worker.
   3. Resultados — topologías, colapso, consensos, exportación, entrega al módulo 2.
*/
(function () {
'use strict';

/* ============================== utilidades ============================== */
const $ = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ic = (p, c) => `<svg viewBox="0 0 24 24" class="${c || ''}" aria-hidden="true" focusable="false">${p}</svg>`;
const SVGI = {
  arrowR: '<path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowL: '<path d="M19 12H5M11 18l-6-6 6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  dl: '<path d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  copy: '<rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10" fill="none" stroke="currentColor" stroke-width="2"/>',
  check: '<path d="M4 12l5 5L20 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  info: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 11v5M12 8h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  warn: '<path d="M12 3.5 22 20H2z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M12 10v4M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  play: '<path d="M8 5.2v13.6L19 12z" fill="currentColor" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>',
  stop: '<rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor"/>',
  plus: '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  trash: '<path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  up: '<path d="M6 15l6-6 6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
};

/* Ayuda por control: un «?» que abre un panel corto. Sin esto no hay forma de
   saber qué hace cada parámetro. */
function qm(key) {
  return `<button class="qm" data-help="${key}" aria-label="${esc(t('help_a'))}: ${esc(t(key + '_l') || key)}">?</button>`;
}
let helpPop = null;
function closeHelp() { if (helpPop) { helpPop.remove(); helpPop = null; } }
function wireHelp(root) {
  $$('.qm', root || document).forEach(b => b.onclick = e => {
    e.stopPropagation();
    const open = helpPop && helpPop.dataset.k === b.dataset.help;
    closeHelp();
    if (open) return;
    helpPop = document.createElement('div');
    helpPop.className = 'helppop';
    helpPop.dataset.k = b.dataset.help;
    helpPop.setAttribute('role', 'tooltip');
    helpPop.innerHTML = `<div class="hp-t">${esc(t(b.dataset.help + '_l'))}</div><p>${t(b.dataset.help + '_h')}</p>`;
    document.body.appendChild(helpPop);
    const r = b.getBoundingClientRect();
    const w = Math.min(300, innerWidth - 24);
    helpPop.style.width = w + 'px';
    helpPop.style.left = Math.max(12, Math.min(innerWidth - w - 12, r.left - w / 2 + r.width / 2)) + 'px';
    helpPop.style.top = (r.bottom + scrollY + 8) + 'px';
  });
}
addEventListener('click', closeHelp);
addEventListener('keydown', e => { if (e.key === 'Escape') closeHelp(); });

let toastWrap;
function toast(msg) {
  if (!toastWrap) {
    toastWrap = document.createElement('div'); toastWrap.className = 'toast-wrap';
    toastWrap.setAttribute('role', 'status'); toastWrap.setAttribute('aria-live', 'polite');
    document.body.appendChild(toastWrap);
  }
  const el = document.createElement('div'); el.className = 'toast';
  el.innerHTML = ic(SVGI.check) + '<span>' + esc(msg) + '</span>';
  toastWrap.appendChild(el);
  const raf = (typeof requestAnimationFrame === 'function') ? requestAnimationFrame : (f => setTimeout(f, 16));
  raf(() => el.classList.add('on'));
  setTimeout(() => { el.classList.remove('on'); setTimeout(() => el.remove(), 250); }, 2100);
}
function copy(txt) { try { navigator.clipboard.writeText(txt); } catch (e) {} toast(t('copied')); }
function download(name, content) {
  const b = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = name;
  document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => { try { URL.revokeObjectURL(a.href); } catch (e) {} }, 4000);
  toast(t('dl_ok'));
}

/* ================================ estado ================================ */
const S = {
  lang: (localStorage.getItem('pf_lang') || (navigator.language || 'es').slice(0, 2).toLowerCase()),
  tab: 0,
  mx: null,            // { taxa:[], matrix:{tx->[tok]}, ordered:Set, inactive:Set, weights:{}, gapAsState, name }
  page: 0, perPage: 30, ccBase: 0, mxView: 'cells', mxq: '',
  cfg: { mode: 'SPR', replicates: 10, start: 'ras', ratchetIter: 5, ratchetFrac: .25, ratchetAmount: 2, hold: 100, seed: 1, weighting: 'equal', k: 3, fuse: true, threads: 0 },
  run: null,           // { worker, t0, phase, rep, best, archive }
  res: null
};
if (['es', 'en', 'pt'].indexOf(S.lang) < 0) S.lang = 'es';
const t = k => (I18N_INF[S.lang][k] != null ? I18N_INF[S.lang][k] : k);

/* ============================ modelo de matriz ============================ */
function emptyMx(name) {
  return { name: name || '—', taxa: [], matrix: {}, ordered: new Set(), inactive: new Set(),
           weights: {}, costs: {}, gapAsState: false };
}
function nChar(mx) { return mx.taxa.length ? mx.matrix[mx.taxa[0]].length : 0; }
function mxStats(mx) {
  const n = nChar(mx); let miss = 0, gaps = 0, poly = 0, cells = mx.taxa.length * n, maxSt = 0;
  mx.taxa.forEach(tx => mx.matrix[tx].forEach(v => {
    if (v === '?') miss++;
    else if (v === '-') gaps++;
    else { if (v.length > 1) poly++; for (const c of v) { const d = parseInt(c, 36); if (!isNaN(d) && d + 1 > maxSt) maxSt = d + 1; } }
  }));
  return { n, miss, gaps, poly, cells, maxSt };
}
/* Emite en la misma base con la que se lee. */
/* Ancho de la matriz de costos de un carácter: hasta el mayor estado observado.
   Se dimensiona por los datos, no a ojo. */
function charK(mx, c) {
  let mx2 = 1;
  mx.taxa.forEach(tx => {
    const tok = mx.matrix[tx][c];
    if (tok === '?' || tok === '-') return;
    for (const ch of tok) { const d = parseInt(ch, 36); if (!isNaN(d) && d + 1 > mx2) mx2 = d + 1; }
  });
  return Math.max(2, mx2);
}
/* Matriz por defecto al pasar un carácter a Sankoff: costos uniformes, que es
   exactamente Fitch. Así el puntaje no cambia hasta que el usuario la edite. */
function defaultCost(k) {
  const M = [];
  for (let a = 0; a < k; a++) { M.push([]); for (let b = 0; b < k; b++) M[a].push(a === b ? 0 : 1); }
  return M;
}
function charType(mx, c) {
  if (mx.costs[c]) return 'sank';
  if (mx.ordered.has(c)) return 'ord';
  return 'fitch';
}
function setCharType(mx, c, ty) {
  delete mx.costs[c]; mx.ordered.delete(c);
  if (ty === 'ord') mx.ordered.add(c);
  else if (ty === 'sank') mx.costs[c] = defaultCost(charK(mx, c));
}

/* Reparto de caracteres por modelo: es lo que la búsqueda va a aplicar de
   verdad. Se calcula de la matriz, no se declara aparte. */
function charMix(mx) {
  const n = nChar(mx);
  let fitch = 0, ord = 0, sank = 0, off = 0;
  for (let c = 0; c < n; c++) {
    if (mx.inactive.has(c) || mx.weights[c] === 0) { off++; continue; }
    const ty = charType(mx, c);
    if (ty === 'sank') sank++; else if (ty === 'ord') ord++; else fitch++;
  }
  return { fitch: fitch, ord: ord, sank: sank, off: off, active: fitch + ord + sank };
}

function ccodeString(mx, base) {
  base = base == null ? S.ccBase : (base ? 1 : 0);
  const n = nChar(mx), parts = [];
  const ord = [...mx.ordered].sort((a, b) => a - b);
  const off = [...mx.inactive].sort((a, b) => a - b);
  const rng = arr => {
    const out = []; let i = 0;
    while (i < arr.length) { let j = i; while (j + 1 < arr.length && arr[j + 1] === arr[j] + 1) j++;
      out.push(i === j ? String(arr[i] + base) : (arr[i] + base) + '.' + (arr[j] + base)); i = j + 1; }
    return out.join(' ');
  };
  const span = base + '.' + (n - 1 + base);
  parts.push('- ' + span);          // todo no aditivo
  parts.push('/1 ' + span);         // todo peso 1
  parts.push('[ ' + span);          // todo activo
  if (ord.length) parts.push('+ ' + rng(ord));
  if (off.length) parts.push('] ' + rng(off));
  const byW = {};
  Object.keys(mx.weights).forEach(k => { const w = mx.weights[k]; if (w !== 1) (byW[w] = byW[w] || []).push(+k); });
  Object.keys(byW).forEach(w => parts.push('/' + w + ' ' + rng(byW[w].sort((a, b) => a - b))));
  return 'ccode ' + parts.join(' ') + ' ;';
}
function tntString(mx) {
  const n = nChar(mx);
  const w = Math.max.apply(null, mx.taxa.map(x => x.length).concat([8])) + 2;
  const rows = mx.taxa.map(tx => tx.padEnd(w) + mx.matrix[tx].map(v => v.length > 1 ? '[' + v + ']' : v).join(''));
  return `xread\n'${mx.name} — PaleoForest'\n${n} ${mx.taxa.length}\n${rows.join('\n')}\n;\n${ccodeString(mx)}\nproc/;\n`;
}
function loadTNT(raw, name) {
  const m = parseTNTMatrixLocal(raw);
  if (!m || !m.taxa.length) return null;
  const mx = emptyMx(name);
  mx.taxa = m.taxa; mx.matrix = m.matrix;
  if (/ccode/i.test(raw)) applyCcode(mx, raw, S.ccBase);
  return mx;
}
function parseTNTMatrixLocal(raw) {
  const lines = raw.split(/\r?\n/);
  let di = -1, ntax = 0;
  for (let i = 0; i < lines.length; i++) if (/^\s*xread/i.test(lines[i])) {
    for (let j = i + 1; j < i + 8 && j < lines.length; j++) {
      const mm = lines[j].match(/^\s*'?\s*(\d+)\s+(\d+)\s*'?\s*$/);
      if (mm) { di = j; ntax = +mm[2]; break; }
    }
    break;
  }
  if (di < 0) return null;
  const matrix = {}, taxa = []; let k = di + 1, n = 0;
  while (k < lines.length && n < ntax) {
    const l = lines[k].replace(/\r$/, ''); k++;
    const tt = l.trim();
    if (!tt || tt.startsWith('&')) continue;
    if (tt === ';' || /^\s*(proc|ccode|cc)\b/i.test(l)) break;
    const mm = l.match(/^(\S+)\s+(.+)$/);
    if (mm) { const nm = mm[1].replace(/^'|'$/g, ''); matrix[nm] = tntTokens(mm[2].trim()); taxa.push(nm); n++; }
  }
  return { taxa, matrix };
}
/* Lector de ccode:  +  aditivo   -  no aditivo   [  activo   ]  inactivo   /N  peso
   Rangos con «.» o «-». `base` es 0 o 1 según cómo numere el archivo. */
function parseCcodeFull(text, n, base) {
  const blocks = [];
  const re = /\bccode\b([\s\S]*?);/gi;
  let mm;
  while ((mm = re.exec(text)) !== null) blocks.push(mm[1]);
  if (!blocks.length) return null;
  base = base ? 1 : 0;
  const out = { ordered: new Set(), nonadd: new Set(), inactive: new Set(), active: new Set(), weights: {} };
  const toks = blocks.join(' ').trim().split(/\s+/).filter(Boolean);
  let mode = null, wt = null, seen = false;
  const apply = list => {
    seen = true;
    list.forEach(i => {
      if (i < 0 || i >= n) return;
      if (mode === '+') { out.ordered.add(i); out.nonadd.delete(i); }
      else if (mode === '-') { out.nonadd.add(i); out.ordered.delete(i); }
      else if (mode === ']') { out.inactive.add(i); out.active.delete(i); }
      else if (mode === '[') { out.active.add(i); out.inactive.delete(i); }
      else if (mode === '/') out.weights[i] = wt;
    });
  };
  const all = () => { const a = []; for (let i = 0; i < n; i++) a.push(i); return a; };
  for (let k = 0; k < toks.length; k++) {
    let tk = toks[k];
    // un token puede traer varios prefijos pegados: "-/1", "+13", "]5.9"
    for (;;) {
      const wm = /^\/(\d+(?:\.\d+)?)/.exec(tk);
      if (wm) { mode = '/'; wt = +wm[1]; tk = tk.slice(wm[0].length); continue; }
      const head = /^([+\-\[\]])(?![0-9])/.exec(tk) || (/^([+\[\]])/.exec(tk));
      if (head) { mode = head[1]; tk = tk.slice(1); continue; }
      break;
    }
    if (!tk) continue;
    // «*» es ambiguo entre «todos los caracteres» y terminador: se ignora.
    if (tk === '*' || tk === ';') continue;
    const r = /^(\d+)[.\-](\d+)$/.exec(tk);
    if (r) { const a = []; for (let i = +r[1]; i <= +r[2]; i++) a.push(i - base); apply(a); continue; }
    if (/^\d+$/.test(tk)) { apply([+tk - base]); continue; }
  }
  return seen ? out : null;
}
function applyCcode(mx, text, base) {
  const n = nChar(mx);
  const cc = parseCcodeFull(text, n, base == null ? S.ccBase : base);
  if (!cc) return false;
  mx.ordered = cc.ordered;
  mx.inactive = cc.inactive;
  mx.weights = {};
  Object.keys(cc.weights).forEach(k => { if (cc.weights[k] !== 1) mx.weights[+k] = cc.weights[k]; });
  return true;
}
/* El ejemplo usa D.ordered: es el conjunto verificado contra L=1322. */
function mxFromExample() {
  const D = window.PF_DATA;
  const mx = emptyMx(D.name || 'Arackar licanantay');
  mx.taxa = D.taxa.slice();
  mx.taxa.forEach(tx => mx.matrix[tx] = D.matrix[tx].slice());
  mx.ordered = new Set(D.ordered || []);
  mx.isExample = true;      // sólo para acreditar la fuente en la barra
  return mx;
}
/* =============================== chrome =============================== */
function renderChrome() {
  const H = I18N_HUB[S.lang];
  $('#brand').innerHTML = `${logoSVG()}<div class="brand-txt"><div class="k">${esc(t('appName'))}</div><div class="s">${esc(t('appSub'))}</div></div>`;
  $('#langs').innerHTML =
    `<button class="helpbtn tourbtn" id="tourBtn" title="${esc(I18N[S.lang].tour_hint)}">${ic(SVGI.play)}<span>${esc(I18N[S.lang].tour_start)}</span></button>` +
    `<a class="helpbtn" href="index.html">${ic(SVGI.arrowL)}<span>${esc(H.backHub)}</span></a>` +
    ['es', 'en', 'pt'].map(l => `<button class="lang ${l === S.lang ? 'on' : ''}" data-lang="${l}" lang="${l}"
       aria-label="${esc(I18N[l]._flag)}" aria-pressed="${l === S.lang}">${FLAGS[l]}</button>`).join('');
  $$('#langs .lang').forEach(b => b.onclick = () => {
    S.lang = b.dataset.lang; localStorage.setItem('pf_lang', S.lang);
    // la guía se relanza sola en el idioma nuevo; dejarla abierta la deja a medias
    PFTour.end();
    document.documentElement.lang = S.lang; renderChrome(); render();
  });
  $('#tourBtn').onclick = startTour;
  renderSteps();
  $('#foot').innerHTML = PFCite.footerHTML(S.lang);
  PFCite.wireFooter($('#foot'), txt => copy(txt));
}
function renderSteps() {
  $('#steps').innerHTML = I18N_INF[S.lang].tabs.map((s, i) => {
    const lock = (i === 1 && !S.mx) || (i === 2 && !S.res);
    return `<button class="step ${i === S.tab ? 'on' : ''} ${lock ? 'lockd' : ''}" data-i="${i}"
      aria-current="${i === S.tab ? 'step' : 'false'}" ${lock ? 'aria-disabled="true"' : ''}><span class="num" aria-hidden="true">${i + 1}</span>${esc(s)}</button>`;
  }).join('');
  $$('#steps .step').forEach(b => b.onclick = () => go(+b.dataset.i));
}
function go(i) {
  if (i === 1 && !S.mx) { toast(t('se_nomx')); return; }
  if (i === 2 && !S.res) return;
  S.tab = i; renderSteps(); render();
  try { scrollTo({ top: 0, behavior: 'smooth' }); } catch (e) {}
}

/* =============================== 1. matriz =============================== */
function viewMatrix() {
  const M = S.mx;
  if (!M) return `
    <div class="wrap">
      <h2 class="vh">${esc(t('mx_h'))}</h2>
      <p class="lead" style="margin:22px 0 16px">${t('mx_p')}</p>
      <div class="card pad">
        <div class="drop" id="drop">
          <div style="font-weight:700;color:var(--usach-slate)">${esc(t('mx_drop'))}</div>
          <div style="font-size:12px;color:var(--muted);margin:8px 0">${esc(t('mx_or'))}</div>
          <button class="btn ghost" id="pick">${ic(SVGI.dl)}${esc(t('mx_load'))}</button>
          <input type="file" id="file" accept=".tnt,.txt" hidden>
        </div>
        <div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:16px">
          <button class="btn" id="ex">${ic(SVGI.play)}${esc(t('mx_example'))}</button>
          <button class="btn ghost" id="nw">${ic(SVGI.plus)}${esc(t('mx_new'))}</button>
        </div>
      </div>
    </div>`;

  const st = mxStats(M), n = st.n;
  const pages = Math.max(1, Math.ceil(n / S.perPage));
  S.page = Math.min(S.page, pages - 1);
  const c0 = S.page * S.perPage, c1 = Math.min(n, c0 + S.perPage);
  const cols = []; for (let c = c0; c < c1; c++) cols.push(c);

  const head = cols.map(c => {
    const cls = (M.inactive.has(c) ? 'off ' : '') + (M.ordered.has(c) ? 'ord' : '');
    const st = M.inactive.has(c) ? t('mx_inact') : t('mx_act');
    return `<th class="${cls}" data-c="${c}" scope="col" tabindex="0" role="columnheader"
      aria-label="${esc(t('mx_char'))} ${c + 1}, ${esc(st)}" title="${esc(t('mx_char'))} ${c + 1}">${c + 1}</th>`;
  }).join('');
  const q = S.mxq.trim().toLowerCase();
  const rows = M.taxa.map((tx, i) => [tx, i]).filter(r => !q || r[0].toLowerCase().indexOf(q) >= 0);
  const body = rows.map(([tx, ti]) => `<tr>
      <th class="tx" data-tx="${ti}" scope="row" tabindex="0" title="${esc(tx)}"
        aria-label="${esc(t('mx_rename'))}: ${esc(tx)}">${esc(tx)}</th>`+`
      ${cols.map(c => {
        const v = M.matrix[tx][c];
        const k = v === '?' ? 'q' : v === '-' ? 'g' : v.length > 1 ? 'p' : '';
        return `<td class="${k} ${M.inactive.has(c) ? 'off' : ''}" data-tx="${ti}" data-c="${c}"
          contenteditable="true" spellcheck="false" role="textbox"
          aria-label="${esc(tx)}, ${esc(t('mx_char'))} ${c + 1}">${esc(v)}</td>`;
      }).join('')}
    </tr>`).join('');

  const chRows = cols.map(c => {
    const cs = charStates(M.matrix, c);
    const cov = Math.round(100 * (M.taxa.length - cs.missing) / M.taxa.length);
    return `<tr class="${M.inactive.has(c) ? 'off' : ''}" data-c="${c}">
      <td class="c1">${c + 1}</td>
      <td class="st">${cs.states.length ? esc(cs.states.join(' ')) : '<span class="c1">—</span>'}</td>
      <td>${cov}%</td>
      <td>${cs.poly || '<span class="c1">·</span>'}</td>
      <td><select class="tysel" data-c="${c}" aria-label="${esc(t('mx_type'))} ${c + 1}">
        <option value="fitch" ${charType(M, c) === 'fitch' ? 'selected' : ''}>${esc(t('ty_fitch'))}</option>
        <option value="ord" ${charType(M, c) === 'ord' ? 'selected' : ''}>${esc(t('ty_ord'))}</option>
        <option value="sank" ${charType(M, c) === 'sank' ? 'selected' : ''}>${esc(t('ty_sank'))}</option>
      </select>${charType(M, c) === 'sank' ? `<button class="toolbtn cmx" data-c="${c}" aria-label="${esc(t('mx_costs'))} ${c + 1}">${esc(t('mx_costs'))}</button>` : ''}</td>
      <td><input type="checkbox" class="ck-act" data-c="${c}" ${M.inactive.has(c) ? '' : 'checked'}></td>
      <td><input class="win" type="number" min="0" step="1" data-c="${c}" value="${M.weights[c] == null ? 1 : M.weights[c]}"></td>
    </tr>`;
  }).join('');

  return `
  <div class="wrap">
      <h2>${esc(t('mx_h'))}</h2></div>

    <div class="statrow" style="margin-bottom:18px">
      <div class="stat"><div class="v">${M.taxa.length}</div><div class="l">${esc(t('mx_taxa'))}${qm('mx_taxa')}</div></div>
      <div class="stat"><div class="v">${n}</div><div class="l">${esc(t('mx_chars'))}${qm('mx_chars')}</div></div>
      <div class="stat"><div class="v">${st.maxSt}</div><div class="l">${esc(t('mx_states'))}${qm('mx_states')}</div></div>
      <div class="stat"><div class="v">${st.cells ? Math.round(100 * st.miss / st.cells) : 0}%</div><div class="l">${esc(t('mx_miss'))}${qm('mx_miss')}</div></div>
    </div>

    <div class="toolbar">
      <span class="kpi">${M.ordered.size} <b>${esc(t('mx_addc'))}</b></span>
      <span class="kpi">${M.inactive.size} <b>${esc(t('mx_inact'))}</b></span>
      <span class="kpi">${Object.keys(M.weights).filter(k => M.weights[k] !== 1).length} <b>${esc(t('mx_wt'))}</b></span>
      <div class="spacer"></div>
      <div class="seg" id="gapseg" role="group" aria-label="${esc(t('mx_gapmode'))}">
        <button data-g="0" class="${M.gapAsState ? '' : 'on'}" aria-pressed="${!M.gapAsState}">${esc(t('mx_gap_missing'))}</button>
        <button data-g="1" class="${M.gapAsState ? 'on' : ''}" aria-pressed="${M.gapAsState}">${esc(t('mx_gap_state'))}</button>
      </div>${qm('mx_gapmode')}
      <button class="toolbtn accent" id="mx-dl">${ic(SVGI.dl)}${esc(t('mx_export'))}</button>
      <button class="toolbtn" id="mx-cc">${ic(SVGI.copy)}${esc(t('mx_exportcc'))}</button>
    </div>

    <div class="viewbar">
      <div class="seg mxseg" id="mx-view" role="tablist">
        <button data-v="cells" class="${S.mxView === 'cells' ? 'on' : ''}" role="tab" aria-selected="${S.mxView === 'cells'}">${esc(t('mx_grid'))}</button>
        <button data-v="chars" class="${S.mxView === 'chars' ? 'on' : ''}" role="tab" aria-selected="${S.mxView === 'chars'}">${esc(t('mx_charpanel'))}</button>
      </div>
      ${qm(S.mxView === 'cells' ? 'mx_grid' : 'mx_charpanel')}
      <div class="spacer"></div>
      <div class="searchbox">
        ${ic(SVGI.search)}
        <input id="mx-q" type="search" value="${esc(S.mxq)}" placeholder="${esc(t('mx_find'))}" aria-label="${esc(t('mx_find'))}">
        ${S.mxq ? `<button class="xbtn" id="mx-qx" aria-label="${esc(t('mx_clear'))}">×</button>` : ''}
      </div>
    </div>
    <p class="viewnote">${esc(t(S.mxView === 'cells' ? 'mx_grid_p' : 'mx_charpanel_p'))}</p>

    ${S.mxView === 'cells' ? `
    <div class="card pad">
      <div class="hint" style="margin-bottom:10px">${ic(SVGI.info)}<span>${t('mx_cellhint')}</span>${qm('mx_cell')}</div>
      <div class="legend mxlegend">
        <span class="lg-item"><i class="lg-cell q">?</i>${esc(t('lg_miss'))}</span>
        <span class="lg-item"><i class="lg-cell g">-</i>${esc(t('lg_gap'))}</span>
        <span class="lg-item"><i class="lg-cell p">01</i>${esc(t('lg_poly'))}</span>
        <span class="lg-item"><i class="lg-cell ord">15</i>${esc(t('lg_ord'))}</span>
        <span class="lg-item"><i class="lg-cell off">7</i>${esc(t('lg_off'))}</span>
      </div>
      <div class="mxpage">
        <button class="toolbtn" id="pg-prev" ${S.page === 0 ? 'disabled' : ''}>${ic(SVGI.arrowL)}${esc(t('mx_prev'))}</button>
        <span class="mono">${esc(t('mx_page'))} ${S.page + 1} ${esc(t('mx_of'))} ${pages} · ${esc(t('mx_char'))} ${c0 + 1}–${c1}</span>
        <button class="toolbtn" id="pg-next" ${S.page >= pages - 1 ? 'disabled' : ''}>${esc(t('mx_next'))}${ic(SVGI.arrowR)}</button>
        <div class="spacer"></div>
        <button class="toolbtn" id="add-tax">${ic(SVGI.plus)}${esc(t('mx_addtax'))}</button>
        <button class="toolbtn" id="add-char">${ic(SVGI.plus)}${esc(t('mx_addchar'))}</button>
      </div>
      <div class="mxwrap"><table class="mxtbl"><caption class="vh">${esc(t('mx_h'))}</caption><thead><tr><th class="tx" scope="col">${esc(t('mx_taxa'))}</th>${head}</tr></thead><tbody>${body}</tbody></table></div>
    </div>` : `
    <div class="card pad">
      <div class="mxpage">
        <button class="toolbtn" id="pg-prev" ${S.page === 0 ? 'disabled' : ''}>${ic(SVGI.arrowL)}${esc(t('mx_prev'))}</button>
        <span class="mono">${esc(t('mx_page'))} ${S.page + 1} ${esc(t('mx_of'))} ${pages} · ${esc(t('mx_char'))} ${c0 + 1}–${c1}</span>
        <button class="toolbtn" id="pg-next" ${S.page >= pages - 1 ? 'disabled' : ''}>${esc(t('mx_next'))}${ic(SVGI.arrowR)}</button>
      </div>
      <div class="tbl-wrap" style="max-height:460px;overflow:auto">
        <table class="cetbl"><thead><tr>
          <th scope="col">#${qm('mx_num')}</th><th scope="col">${esc(t('mx_st'))}${qm('mx_st')}</th><th scope="col">${esc(t('mx_cov'))}${qm('mx_cov')}</th><th scope="col">${esc(t('mx_poly'))}${qm('mx_poly')}</th>
          <th scope="col">${esc(t('mx_type'))}${qm('mx_type')}</th><th scope="col">${esc(t('mx_act'))}${qm('mx_act')}</th><th scope="col">${esc(t('mx_w'))}${qm('mx_w')}</th>
        </tr></thead><tbody>${chRows}</tbody></table>
      </div>
      ${Object.keys(M.costs).length ? `<p class="viewnote" style="margin-top:12px">${esc(t('mx_sank_slow').replace('{n}', Object.keys(M.costs).length))}</p>` : ''}
      <div class="eyebrow" style="margin-top:20px">${esc(t('mx_ccode'))}${qm('mx_ccode')}</div>
      <p style="font-size:12.5px;color:var(--muted);margin-top:6px">${t('mx_ccode_p')}</p>
      <textarea class="pcin" id="cc-txt" rows="3" style="margin-top:8px" aria-label="ccode">${esc(ccodeString(M))}</textarea>
      <div style="display:flex;gap:9px;align-items:center;margin-top:8px;flex-wrap:wrap">
        <button class="toolbtn" id="cc-apply">${ic(SVGI.check)}${esc(t('mx_ccode_apply'))}</button>
        <span class="mono" style="font-size:11px;color:var(--muted)">${esc(t('mx_base'))}</span>
        <div class="seg" id="seg-base" role="group" aria-label="${esc(t('mx_base'))}">
          <button data-b="0" class="${S.ccBase === 0 ? 'on' : ''}" aria-pressed="${S.ccBase === 0}">0</button>
          <button data-b="1" class="${S.ccBase === 1 ? 'on' : ''}" aria-pressed="${S.ccBase === 1}">1</button>
        </div>
        ${qm('mx_base')}
      </div>
    </div>`}

    <div class="card pad" style="margin-top:18px;display:flex;justify-content:flex-end">
      <button class="btn" id="to-search">${esc(t('mx_search'))}${ic(SVGI.arrowR)}</button>
    </div>
  </div>`;
}

function wireMatrix() {
  const M = S.mx;
  if (!M) {
    const file = $('#file');
    $('#pick').onclick = () => file.click();
    file.onchange = e => { const f = e.target.files[0]; if (f) readTNT(f); };
    const dz = $('#drop');
    ['dragenter', 'dragover'].forEach(ev => dz.addEventListener(ev, e => { e.preventDefault(); dz.classList.add('hi'); }));
    ['dragleave', 'drop'].forEach(ev => dz.addEventListener(ev, e => { e.preventDefault(); dz.classList.remove('hi'); }));
    dz.addEventListener('drop', e => { const f = e.dataTransfer.files[0]; if (f) readTNT(f); });
    $('#ex').onclick = () => { S.mx = mxFromExample(); S.page = 0; toast(t('mx_loaded')); renderSteps(); render(); };
    $('#nw').onclick = () => {
      const mx = emptyMx('nueva');
      for (let i = 0; i < 4; i++) { const nm = 'Taxon_' + (i + 1); mx.taxa.push(nm); mx.matrix[nm] = new Array(10).fill('?'); }
      S.mx = mx; S.page = 0; renderSteps(); render();
    };
    return;
  }

  $$('#mx-view button').forEach(b => b.onclick = () => { S.mxView = b.dataset.v; render(); });
  const pv = $('#pg-prev'); if (pv) pv.onclick = () => { S.page--; render(); };
  const pn = $('#pg-next'); if (pn) pn.onclick = () => { S.page++; render(); };
  $('#mx-dl').onclick = () => download((M.name || 'matrix').replace(/[^\w.-]+/g, '_') + '.tnt', tntString(M));
  $('#mx-cc').onclick = () => copy(ccodeString(M));
  const qi = $('#mx-q');
  if (qi) {
    qi.oninput = () => { S.mxq = qi.value; S.page = S.page; renderRowsOnly(); };
    qi.onkeydown = e => { if (e.key === 'Escape') { S.mxq = ''; render(); } };
  }
  const qx = $('#mx-qx'); if (qx) qx.onclick = () => { S.mxq = ''; render(); };
  $('#to-search').onclick = () => go(1);
  $$('#gapseg button').forEach(b => b.onclick = () => { M.gapAsState = b.dataset.g === '1'; render(); });

  const _add_tax = $('#add-tax'); if (_add_tax) _add_tax.onclick = () => {
    const nm = prompt(t('mx_newtax'), 'Taxon_' + (M.taxa.length + 1));
    if (!nm || M.matrix[nm]) return;
    M.taxa.push(nm); M.matrix[nm] = new Array(nChar(M) || 1).fill('?'); render();
  };
  const _add_char = $('#add-char'); if (_add_char) _add_char.onclick = () => { M.taxa.forEach(tx => M.matrix[tx].push('?')); S.page = Math.floor((nChar(M) - 1) / S.perPage); render(); };

  wireCells();
  $$('.tysel').forEach(sel => sel.onchange = () => { setCharType(M, +sel.dataset.c, sel.value); render(); });
  $$('.cmx').forEach(b => b.onclick = () => openCosts(+b.dataset.c));
  $$('.ck-act').forEach(b => b.onchange = () => { const c = +b.dataset.c; b.checked ? M.inactive.delete(c) : M.inactive.add(c); render(); });
  $$('.win').forEach(i => i.onchange = () => { const c = +i.dataset.c, w = +i.value; if (w === 1) delete M.weights[c]; else M.weights[c] = w; render(); });

  const _cc_apply = $('#cc-apply'); if (_cc_apply) _cc_apply.onclick = () => {
    if (applyCcode(M, $('#cc-txt').value, S.ccBase)) { toast(t('mx_ccode_ok')); render(); }
    else toast(t('mx_ccode_bad'));
  };
  $$('#seg-base button').forEach(b => b.onclick = () => { S.ccBase = +b.dataset.b; render(); });
}
/* Al teclear en el buscador sólo se repinta la tabla: si se repinta todo, el
   campo pierde el foco en cada tecla. */
function renderRowsOnly() {
  const wrap = $('.mxwrap');
  if (!wrap) { render(); return; }
  const keep = document.activeElement;
  const holder = document.createElement('div');
  holder.innerHTML = viewMatrix();
  const fresh = holder.querySelector('.mxwrap');
  if (fresh) { wrap.innerHTML = fresh.innerHTML; wireCells(); }
  if (keep && keep.id === 'mx-q') { try { keep.focus(); } catch (e) {} }
}

function wireCells() {
  const M = S.mx;
  $$('.mxtbl th.tx[data-tx]').forEach(th => {
    th.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); th.onclick(); } };
    th.onclick = () => {
    const i = +th.dataset.tx, old = M.taxa[i];
    const nm = prompt(t('mx_rename'), old);
    if (nm === null) return;
    if (nm === '') { if (M.taxa.length <= 3) return; M.taxa.splice(i, 1); delete M.matrix[old]; render(); return; }
    if (nm !== old && !M.matrix[nm]) { M.matrix[nm] = M.matrix[old]; delete M.matrix[old]; M.taxa[i] = nm; render(); }
    };
  });
  const toggleChar = c => { if (M.inactive.has(c)) M.inactive.delete(c); else M.inactive.add(c); render(); };
  $$('.mxtbl thead th[data-c]').forEach(th => {
    th.onclick = () => toggleChar(+th.dataset.c);
    th.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleChar(+th.dataset.c); } };
  });

  $$('.mxtbl td[contenteditable]').forEach(td => {
    td.onblur = () => {
      const tx = M.taxa[+td.dataset.tx], c = +td.dataset.c;
      let v = (td.textContent || '').trim();
      if (!v) v = '?';
      if (v !== '?' && v !== '-') { v = v.replace(/[^0-9a-zA-Z]/g, ''); if (!v) v = '?'; }
      M.matrix[tx][c] = v;
      render();
    };
    td.onkeydown = e => { if (e.key === 'Enter') { e.preventDefault(); td.blur(); } };
  });

}

/* Editor de la matriz de costos: C[i][j] = lo que cuesta pasar del estado i al j.
   La diagonal es 0 y no se toca. */
let costModal = null;
function openCosts(c) {
  const M = S.mx, C = M.costs[c];
  const k = C.length;
  closeCosts();
  costModal = document.createElement('div');
  costModal.className = 'loadscrim on';
  costModal.setAttribute('role', 'dialog');
  costModal.setAttribute('aria-modal', 'true');
  costModal.setAttribute('aria-label', t('mx_costs') + ' ' + (c + 1));
  let grid = '<table class="costtbl"><thead><tr><th></th>';
  for (let b = 0; b < k; b++) grid += `<th scope="col">${b}</th>`;
  grid += '</tr></thead><tbody>';
  for (let a = 0; a < k; a++) {
    grid += `<tr><th scope="row">${a}</th>`;
    for (let b = 0; b < k; b++) {
      grid += a === b
        ? '<td class="diag">0</td>'
        : `<td><input type="number" min="0" step="1" data-a="${a}" data-b="${b}" value="${C[a][b]}"
             aria-label="${a} → ${b}"></td>`;
    }
    grid += '</tr>';
  }
  grid += '</tbody></table>';
  costModal.innerHTML = `<div class="loadcard costcard">
      <div class="hp-t">${esc(t('mx_costs'))} · ${esc(t('mx_char'))} ${c + 1}</div>
      <p class="costp">${esc(t('mx_costs_p'))}</p>
      ${grid}
      <div class="costbtns">
        <button class="toolbtn" data-preset="flat">${esc(t('cost_flat'))}</button>
        <button class="toolbtn" data-preset="lin">${esc(t('cost_lin'))}</button>
        <div class="spacer"></div>
        <button class="btn" id="cost-ok">${esc(t('mx_ccode_apply'))}</button>
      </div>
    </div>`;
  document.body.appendChild(costModal);
  const put = f => { for (let a = 0; a < k; a++) for (let b = 0; b < k; b++) if (a !== b) C[a][b] = f(a, b); openCosts(c); };
  $$('[data-preset]', costModal).forEach(b => b.onclick = () => {
    put(b.dataset.preset === 'flat' ? () => 1 : (a, b2) => Math.abs(a - b2));
  });
  $$('input', costModal).forEach(i => i.onchange = () => {
    const v = Math.max(0, +i.value || 0);
    C[+i.dataset.a][+i.dataset.b] = v; i.value = v;
  });
  $('#cost-ok', costModal).onclick = () => { closeCosts(); render(); };
  costModal.addEventListener('keydown', e => { if (e.key === 'Escape') { closeCosts(); render(); } });
  costModal.addEventListener('click', e => { if (e.target === costModal) { closeCosts(); render(); } });
  try { $('#cost-ok', costModal).focus(); } catch (e) {}
}
function closeCosts() { if (costModal) { costModal.remove(); costModal = null; } }

function readTNT(f) {
  const r = new FileReader();
  r.onload = () => {
    const mx = loadTNT(r.result, f.name.replace(/\.[^.]+$/, ''));
    if (!mx) { toast(t('mx_bad')); return; }
    S.mx = mx; S.page = 0; toast(t('mx_loaded')); renderSteps(); render();
  };
  r.readAsText(f);
}

/* ============================== 2. búsqueda ============================== */
function viewSearch() {
  const C = S.cfg;
  const st = mxStats(S.mx);
  const mix = charMix(S.mx);
  return `
  <div class="wrap">
      <h2>${esc(t('se_h'))}</h2><p class="lead" style="margin-top:8px">${esc(t('se_p'))}</p></div>

    <div class="grid g2">
      <div class="card pad">
        <div class="eyebrow">${esc(t('se_crit'))}${qm('se_crit')}</div>
        <div class="critbox">
          <div class="crit-h">${esc(t('se_crit_name'))}${C.weighting === 'iw' ? ` <span class="crit-k">k = ${C.k}</span>` : ''}</div>
          <p class="crit-p">${esc(t('se_crit_p'))}</p>
          <div class="cfgrow" style="margin:12px 0 4px">
            <label>${esc(t('se_wt'))}${qm('se_wt')}</label>
            <div class="seg" id="seg-wt">
              <button data-v="equal" class="${C.weighting === 'equal' ? 'on' : ''}">${esc(t('se_wt_eq'))}</button>
              <button data-v="iw" class="${C.weighting === 'iw' ? 'on' : ''}">${esc(t('se_wt_iw'))}</button>
            </div>
          </div>
          ${C.weighting === 'iw' ? `
          <div class="cfgrow" style="margin:0 0 10px">
            <label>${esc(t('se_k'))}${qm('se_k')}</label>
            <input type="number" class="pcin num" id="c-k" min="0.5" max="1000" step="0.5" value="${C.k}">
          </div>
          <p class="viewnote" style="margin:0 0 8px">${esc(t('se_iw_slow'))}</p>` : ''}
          <div class="critrows">
            <div class="critrow"><i class="cd f"></i><span>${esc(t('ty_fitch'))} <b class="mono">(Fitch)</b></span><b>${mix.fitch}</b></div>
            <div class="critrow"><i class="cd o"></i><span>${esc(t('ty_ord'))} <b class="mono">(Wagner)</b></span><b>${mix.ord}</b></div>
            <div class="critrow ${mix.sank ? '' : 'nil'}"><i class="cd s"></i><span>${esc(t('ty_sank'))} <b class="mono">(${esc(t('mx_costs'))})</b></span><b>${mix.sank}</b></div>
            <div class="critrow ${mix.off ? '' : 'nil'}"><i class="cd x"></i><span>${esc(t('mx_inact'))}</span><b>${mix.off}</b></div>
          </div>
          <button class="toolbtn" id="crit-edit">${ic(SVGI.arrowL)}${esc(t('se_crit_edit'))}</button>
        </div>

        <div class="eyebrow" style="margin-top:20px">${esc(t('se_start'))}</div>
        <div class="cfgrow">
          <label>${esc(t('se_startmode'))}${qm('se_startmode')}</label>
          <div class="seg" id="seg-start">
            <button data-v="ras" class="${C.start === 'ras' ? 'on' : ''}">${esc(t('se_ras'))}</button>
            <button data-v="random" class="${C.start === 'random' ? 'on' : ''}">${esc(t('se_rand'))}</button>
          </div>
        </div>
        <div class="cfgrow"><label>${esc(t('se_reps'))}${qm('se_reps')}</label>
          <input type="number" class="pcin num" id="c-reps" min="1" max="500" value="${C.replicates}"></div>

        <div class="eyebrow" style="margin-top:20px">${esc(t('se_swap'))}</div>
        <div class="cfgrow">
          <label>${esc(t('se_mode'))}${qm('se_mode')}</label>
          <div class="seg" id="seg-mode">
            <button data-v="NNI" class="${C.mode === 'NNI' ? 'on' : ''}">NNI</button>
            <button data-v="SPR" class="${C.mode === 'SPR' ? 'on' : ''}">SPR</button>
            <button data-v="TBR" class="${C.mode === 'TBR' ? 'on' : ''}">TBR</button>
          </div>
        </div>

        <div class="cfgrow" style="margin-top:20px">
          <label>${esc(t('se_fuse'))}${qm('se_fuse')}</label>
          <label class="chk"><input type="checkbox" id="c-fuse" ${C.fuse ? 'checked' : ''}> ${esc(t('se_fuse_on'))}</label>
        </div>

        <div class="eyebrow" style="margin-top:20px">${esc(t('se_ratchet'))}</div>
        <div class="cfgrow"><label>${esc(t('se_ratiter'))}${qm('se_ratiter')}</label><input type="number" class="pcin num" id="c-rit" min="0" max="200" value="${C.ratchetIter}"></div>
        <div class="cfgrow"><label>${esc(t('se_ratfrac'))}${qm('se_ratfrac')}</label><input type="number" class="pcin num" id="c-rfr" min="1" max="90" value="${Math.round(C.ratchetFrac * 100)}"></div>
        <div class="cfgrow"><label>${esc(t('se_ratamt'))}${qm('se_ratamt')}</label><input type="number" class="pcin num" id="c-ram" min="2" max="10" value="${C.ratchetAmount}"></div>
      </div>

      <div class="card pad">
        <div class="eyebrow">${esc(t('se_out'))}</div>
        <div class="cfgrow"><label>${esc(t('se_hold'))}${qm('se_hold')}</label>
          <input type="number" class="pcin num" id="c-hold" min="1" max="200000" step="100" value="${C.hold}"></div>

        <div class="cfgrow"><label>${esc(t('se_threads'))}${qm('se_threads')}</label>
          <input type="number" class="pcin num" id="c-th" min="0" max="64" step="1" value="${C.threads}"
                 placeholder="0" title="${esc(t('se_threads_auto'))}"></div>
        <div class="cfgrow"><label>${esc(t('se_seed'))}${qm('se_seed')}</label>
          <input type="number" class="pcin num" id="c-seed" min="0" step="1" value="${C.seed}"></div>

        <div class="statrow" style="grid-template-columns:1fr 1fr;margin-top:20px">
          <div class="stat"><div class="v">${S.mx.taxa.length}</div><div class="l">${esc(t('mx_taxa'))}</div></div>
          <div class="stat"><div class="v">${mix.active}</div><div class="l">${esc(t('mx_chars'))}${qm('mx_chars')}</div></div>
        </div>

        <div style="margin-top:20px">
          <button class="btn" id="run">${ic(SVGI.play)}${esc(t('se_run'))}</button>
          <p class="runnote">${esc(t('se_slow'))}</p>
        </div>
      </div>
    </div>
  </div>`;
}
function wireSearch() {
  const C = S.cfg;
  $$('#seg-start button').forEach(b => b.onclick = () => { C.start = b.dataset.v; render(); });
  $$('#seg-mode button').forEach(b => b.onclick = () => { C.mode = b.dataset.v; render(); });
  const num = (id, k, f) => { const e = $(id); if (e) e.onchange = () => { C[k] = f ? f(+e.value) : +e.value; }; };
  num('#c-reps', 'replicates'); num('#c-rit', 'ratchetIter'); num('#c-rfr', 'ratchetFrac', v => v / 100);
  num('#c-ram', 'ratchetAmount'); num('#c-hold', 'hold'); num('#c-seed', 'seed');
  $$('#seg-wt button').forEach(b => b.onclick = () => { C.weighting = b.dataset.v; render(); });
  const ck = $('#c-k'); if (ck) ck.onchange = () => { C.k = Math.max(0.5, +ck.value || 3); render(); };
  const ce = $('#crit-edit'); if (ce) ce.onclick = () => { S.mxView = 'chars'; go(0); };
  const cf = $('#c-fuse'); if (cf) cf.onchange = () => C.fuse = cf.checked;
  const r = $('#run'); if (r) r.onclick = startRun;
}
function startRun() {
  const M = S.mx, C = S.cfg;
  const pack = {
    ordered: [...M.ordered], inactive: [...M.inactive], weights: M.weights,
    nst: Math.max(8, mxStats(M).maxSt + 1), gapAsState: M.gapAsState, stripUninformative: true,
    costs: M.costs,
    implied: C.weighting === 'iw' ? C.k : null
  };
  const search = {
    mode: C.mode, replicates: C.replicates, start: C.start,
    ratchetIter: C.ratchetIter, ratchetFrac: C.ratchetFrac, ratchetAmount: C.ratchetAmount,
    hold: C.hold, seed: C.seed, expand: true, fuse: C.fuse
  };
  S.run = { worker: null, stop: false, t0: Date.now(), last: null };
  renderSteps(); render();
  showScrim();

  // Un Worker no se puede crear desde file://. Si no se puede, el mismo motor
  // corre en el hilo principal cediendo control entre pasadas.
  if (PFPool.canWork()) {
    S.run.threads = PFPool.threadsFor(C.replicates, C.threads);
    PFPool.runPool({
      matrix: M.matrix, taxa: M.taxa, pack: pack, search: search, threads: C.threads,
      onProgress: p => { if (S.run) { S.run.last = p; paintProgress(p); } },
      onPhase: ph => { if (S.run) S.run.phase = ph; }
    }).then(d => { if (S.run) finish(d); })
      .catch(e => { if (!S.run) return; hideScrim(); S.run = null; toast(String(e && e.message || e)); renderSteps(); render(); });
  } else {
    S.run.threads = 1;
    runInline(pack, search);
  }
}

async function runInline(pack, search) {
  const M = S.mx;
  try {
    await PFSearch.yieldNow();          // deja que el popup se pinte antes de bloquear
    const D = PFSearch.packData(M.matrix, M.taxa, pack);
    const stop = () => !S.run || S.run.stop;
    const onProgress = p => { if (S.run) { S.run.last = p; paintProgress(p); } };
    const R = await PFSearch.searchMPA(D, Object.assign({}, search, { onProgress, stop }));
    if (stop()) return;
    const out = await PFSearch.finishSearchA(D, R, M.taxa, { onProgress, stop });
    if (stop()) return;
    finish(out);
  } catch (e) {
    hideScrim(); S.run = null; toast(String((e && e.message) || e)); renderSteps(); render();
  }
}

function finish(d) {
  hideScrim();
  S.mk = null;   // el conjunto cambió: la puntuación anterior ya no aplica
  if (d.threads == null) d.threads = (S.run && S.run.threads) || 1;
  S.res = d;
  S.res.cfg = JSON.parse(JSON.stringify(S.cfg));
  S.res.mix = charMix(S.mx);
  S.run = null;
  toast(t('se_done'));
  S.tab = 2; renderSteps(); render();
}

/* Popup de espera. Se pinta antes de arrancar; bajo file:// el motor corre en
   este mismo hilo, así que sin ceder control primero no alcanzaría a aparecer. */
let scrim = null;
function showScrim() {
  if (!scrim) {
    scrim = document.createElement('div');
    scrim.className = 'loadscrim';
    scrim.setAttribute('role', 'dialog');
    scrim.setAttribute('aria-modal', 'true');
    scrim.setAttribute('aria-label', t('se_running'));
    scrim.addEventListener('keydown', e => { if (e.key === 'Escape') stopRun(); });
    document.body.appendChild(scrim);
  }
  scrim.innerHTML = `<div class="loadcard">
      <div class="spinner"></div>
      <h4>${esc(t('se_running'))}</h4>
      <div class="lphase" id="sc-ph" role="status" aria-live="polite">—</div>
      <div class="lbar" role="progressbar" aria-valuemin="0" aria-valuemax="100" id="sc-pb"><i id="sc-bar"></i></div>
      <div class="lstats">
        <div><span>${esc(t('se_best'))}</span><b id="sc-best">—</b></div>
        <div><span>${esc(t('se_found'))}</span><b id="sc-arc">—</b></div>
        <div><span>${esc(t('se_threads'))}</span><b id="sc-th">${S.run && S.run.threads ? S.run.threads : 1}</b></div>
        <div><span>${esc(t('se_elapsed'))}</span><b id="sc-ms">0s</b></div>
      </div>
      <button class="btn ghost" id="sc-stop">${ic(SVGI.stop)}${esc(t('se_stop'))}</button>
    </div>`;
  const sb = $('#sc-stop', scrim);
  sb.onclick = stopRun;
  const raf = (typeof requestAnimationFrame === 'function') ? requestAnimationFrame : (f => setTimeout(f, 16));
  raf(() => { scrim.classList.add('on'); try { sb.focus(); } catch (e) {} });
}
function hideScrim() {
  if (!scrim) return;
  scrim.classList.remove('on');
  const sc = scrim;
  setTimeout(() => { if (sc.parentNode && !sc.classList.contains('on')) sc.remove(); }, 300);
  scrim = null;
}

function stopRun() {
  if (!S.run) return;
  S.run.stop = true;
  if (S.run.worker) S.run.worker.terminate();
  if (S.run.pool && S.run.pool.__kill) S.run.pool.__kill();
  S.run = null;
  hideScrim();
  toast(t('se_stopped')); renderSteps(); render();
}
function paintProgress(p) {
  if (!scrim || !S.run) return;
  const secs = ((Date.now() - S.run.t0) / 1000).toFixed(0);
  let head = '', pct = 0;
  if (p.phase === 'replicate') {
    head = t('se_rep') + ' ' + (p.rep + 1) + ' / ' + p.of + (p.cur != null ? ' · ' + p.cur : '');
    pct = 100 * (p.rep + (p.finished ? 1 : 0)) / p.of;
  }
  else if (p.phase === 'fuse') { head = t('se_fuse') + (p.fused ? ' · ' + p.fused : ''); pct = 100; }
  else if (p.phase === 'expand') { head = t('se_expand'); pct = 100; }
  const set = (id, v) => { const e = $(id, scrim); if (e) e.textContent = v; };
  set('#sc-ph', head);
  set('#sc-best', p.best != null && isFinite(p.best) ? p.best : '—');
  set('#sc-arc', p.archive != null ? p.archive : '—');
  set('#sc-ms', secs + 's');
  const bar = $('#sc-bar', scrim);
  if (bar) bar.style.width = Math.min(100, pct).toFixed(1) + '%';
  const pb = $('#sc-pb', scrim);
  if (pb) pb.setAttribute('aria-valuenow', Math.round(Math.min(100, pct)));
}

/* ============================= 3. resultados ============================= */
function viewResults() {
  const R = S.res;
  if (!R) return `<div class="wrap"><div class="card pad">${esc(t('re_none'))}</div></div>`;
  const C = R.cfg;
  const cons = [['strict', 're_strict'], ['major', 're_maj'], ['greedy', 're_greedy']];
  return `
  <div class="wrap">

    <div class="statrow" style="margin-bottom:18px">
      <div class="stat"><div class="v">${R.cfg && R.cfg.weighting === 'iw' ? R.best.toFixed(2) : R.best}</div>
        <div class="l">${esc(R.cfg && R.cfg.weighting === 'iw' ? t('re_fit') : t('re_len'))}${qm(R.cfg && R.cfg.weighting === 'iw' ? 're_fit' : 're_len')}</div></div>
      <div class="stat"><div class="v">${R.unique}</div><div class="l">${esc(t('re_uniq'))} ${R.cfg && R.cfg.weighting === 'iw' ? R.best.toFixed(2) : R.best}${qm('re_uniq')}</div></div>
      <div class="stat"><div class="v">${R.log.length}</div><div class="l">${esc(t('se_reps'))}</div></div>
      <div class="stat"><div class="v">${(R.ms / 1000).toFixed(0)}s</div><div class="l">${esc(t('se_elapsed'))}</div></div>
    </div>

    <div class="card pad sendbar">
      <div class="sendtxt">
        <b>${esc(t('re_ready'))}</b>
        <p>${esc(t(R.truncated ? 're_ready_pt' : 're_ready_p').replace('{n}', R.unique).replace('{l}', R.best))}</p>
      </div>
      <button class="btn" id="to-pipe">${esc(t('re_topipe'))}${ic(SVGI.arrowR)}</button>
    </div>

    ${R.truncated ? `<div class="warnbox" style="margin-bottom:18px">${ic(SVGI.warn)}
      <div><b>${esc(t('re_trunc_t'))}</b>
        <p>${esc(t('re_trunc_p'))}</p>
        <p style="margin-top:8px">${t(R.rate > 0.5 ? 're_rate_hi' : R.rate > 0.1 ? 're_rate_mid' : 're_rate_lo')
          .replace('{p}', Math.round((R.rate == null ? 1 : R.rate) * 100))
          .replace('{v}', R.visited || 0).replace('{n}', R.unique)}</p>
        <button class="toolbtn" id="tr-more">${esc(t('re_trunc_up'))}</button>
      </div></div>`
    : `<div class="warnbox ok" style="margin-bottom:18px">${ic(SVGI.check)}
      <div><b>${esc(t('re_sat_t'))}</b><p>${esc(t('re_sat_p'))}</p></div></div>`}

    <div class="grid g2">
      <div class="card pad">
        <div class="eyebrow">${esc(t('re_cons'))}${qm('re_cons')}</div>
        <div class="cluout" style="margin-top:12px">
          ${cons.map(([k, lbl]) => {
            const c = R.consensus[k];
            return `<div class="clurow">
              <span class="clun">${esc(t(lbl))}${qm('re_' + k)}</span>
              <span class="clus">${c.nodes} ${esc(t('re_consnodes'))} ${c.maxNodes}</span>
              <span class="clum">${Math.round(100 * c.nodes / c.maxNodes)}%</span>
              <button class="toolbtn" data-cons="${k}" aria-label="${esc(t('re_dl_cons'))}: ${esc(t(lbl))}">${ic(SVGI.dl)}</button>
            </div>`;
          }).join('')}
        </div>
        <div style="display:flex;gap:9px;flex-wrap:wrap;margin-top:16px">
          <button class="toolbtn" id="dl-nex">${ic(SVGI.dl)}${esc(t('re_dl_nex'))}</button>
          <button class="toolbtn" id="dl-nwk">${ic(SVGI.dl)}${esc(t('re_dl_nwk'))}</button>
          <button class="toolbtn" id="dl-tre">${ic(SVGI.dl)}${esc(t('re_dl_tre'))}</button>
          <button class="toolbtn" id="cp-nwk">${ic(SVGI.copy)}${esc(t('re_copy_nwk'))}</button>
        </div>

      </div>

      <div class="card pad">
        <div class="eyebrow">${esc(t('re_params'))}</div>
        <table class="pctbl" style="margin-top:10px;width:100%">
          <tr><th>${esc(t('se_crit'))}</th><td class="mono">${esc(t('se_crit_name'))}${C.weighting === 'iw' ? ' · ' + esc(t('se_wt_iw')) + ' k=' + C.k : ' · ' + esc(t('se_wt_eq'))}</td></tr>
          <tr><th>${esc(t('mx_type'))}</th><td class="mono">${R.mix ? `${R.mix.fitch} Fitch · ${R.mix.ord} Wagner${R.mix.sank ? ' · ' + R.mix.sank + ' Sankoff' : ''}` : '—'}</td></tr>
          <tr><th>${esc(t('se_mode'))}</th><td class="mono">${esc(R.mode)}</td></tr>
          <tr><th>${esc(t('se_reps'))}</th><td class="mono">${C.replicates}</td></tr>
          <tr><th>${esc(t('se_ratchet'))}${qm('se_ratiter')}</th><td class="mono">${C.ratchetIter} · ${Math.round(C.ratchetFrac * 100)}% · ×${C.ratchetAmount}</td></tr>
          <tr><th>${esc(t('se_hold'))}</th><td class="mono">${R.hold}</td></tr>
          <tr><th>${esc(t('se_seed'))}</th><td class="mono">${R.seed}</td></tr>
          <tr><th>${esc(t('se_fuse'))}${qm('se_fuse')}</th><td class="mono">${R.fused == null ? '—' : R.fused}</td></tr>
          <tr><th>${esc(t('se_threads'))}</th><td class="mono">${R.threads || 1}${qm('se_threads')}</td></tr>
        </table>
        <div class="eyebrow" style="margin-top:18px">${esc(t('re_supp'))}${qm('re_supp')}</div>
        <p style="font-size:12.5px;color:var(--muted);margin-top:6px">${esc(t('re_supp_p'))}</p>
        <div class="legend" style="margin-top:8px">
          <span class="lg-item"><i class="lg-dot" style="background:var(--usach-teal)"></i>100%</span>
          <span class="lg-item"><i class="lg-dot" style="background:var(--usach-orange)"></i>50–99%</span>
          <span class="lg-item"><i class="lg-dot" style="background:#d64545"></i>&lt;50%</span>
        </div>
        <div class="suppwrap">${suppBars(R.support)}</div>
      </div>
    </div>

    <div class="card pad" style="margin-top:18px">
      <div class="eyebrow">${esc(t('mk_h'))}${qm('mk_h')}</div>
      <p style="font-size:12.5px;color:var(--muted);margin-top:6px">${esc(t('mk_p'))}</p>
      ${S.mk ? mkTable() : `<button class="btn ghost" id="mk-run" style="margin-top:12px">${ic(SVGI.play)}${esc(t('mk_run').replace('{n}', R.unique))}</button>`}
    </div>

    <div class="card pad" style="margin-top:18px">
      <div class="eyebrow">${esc(t('re_log'))}${qm('re_log')}</div>
      <div class="tbl-wrap" style="max-height:260px;overflow:auto;margin-top:10px">
        <table class="cetbl"><thead><tr>
          <th scope="col">${esc(t('re_rep'))}</th><th scope="col">${esc(t('re_wag'))}${qm('re_wag')}</th>
          <th scope="col">${esc(t('re_final'))}${qm('re_final')}</th>
          <th scope="col">${esc(t('se_best'))}${qm('re_best')}</th>
          <th scope="col">${esc(t('re_arc'))}${qm('re_arc')}</th></tr></thead>
          <tbody>${R.log.map(l => `<tr><td class="c1">${l.rep + 1}</td><td class="mono">${l.wagner}</td>
            <td class="mono">${l.final}</td><td class="mono" style="color:var(--usach-teal-d);font-weight:700">${l.best}</td>
            <td class="mono">${l.archive}</td></tr>`).join('')}</tbody></table>
      </div>
    </div>
  </div>`;
}
/* Nexus con TODOS los árboles (bloque TAXA + TREES). */
function nexusTrees(R) {
  const tx = S.mx.taxa;
  const q = n => /[\s(),:;'\[\]]/.test(n) ? "'" + n.replace(/'/g, "''") + "'" : n;
  return '#NEXUS\n\n' +
    'BEGIN TAXA;\n  DIMENSIONS NTAX=' + tx.length + ';\n  TAXLABELS\n    ' +
    tx.map(q).join('\n    ') + '\n  ;\nEND;\n\n' +
    'BEGIN TREES;\n' +
    R.newicks.map((n, i) => '  TREE t' + (i + 1) + ' = [&U] ' + n).join('\n') +
    '\nEND;\n';
}

/* La tabla de verosimilitud: los árboles ordenados por lnL. Todos empatan bajo
   parsimonia, así que este orden es lo único que los distingue. */
function mkTable() {
  const R = S.res, mk = S.mk;
  const best = mk.rows[0].lnL, worst = mk.rows[mk.rows.length - 1].lnL;
  const span = (best - worst) || 1;
  return `
    <div class="statrow" style="grid-template-columns:repeat(3,1fr);margin:14px 0">
      <div class="stat"><div class="v">${mk.rows.length}</div><div class="l">${esc(t('re_uniq'))}</div></div>
      <div class="stat"><div class="v">${new Set(mk.rows.map(r => r.lnL.toFixed(4))).size}</div><div class="l">${esc(t('mk_uniq'))}${qm('mk_uniq')}</div></div>
      <div class="stat"><div class="v">${span.toFixed(1)}</div><div class="l">${esc(t('mk_span'))}${qm('mk_span')}</div></div>
    </div>
    <div class="tbl-wrap" style="max-height:280px;overflow:auto">
      <table class="cetbl"><thead><tr>
        <th scope="col">#</th><th scope="col">${esc(t('mk_tree'))}</th>
        <th scope="col">ln L</th><th scope="col">${esc(t('mk_t'))}${qm('mk_t')}</th>
        <th scope="col" style="width:38%">${esc(t('mk_rel'))}</th>
      </tr></thead><tbody>
      ${mk.rows.map((r, i) => `<tr>
        <td class="c1">${i + 1}</td>
        <td class="mono">${r.i + 1}</td>
        <td class="mono" style="${i === 0 ? 'color:var(--usach-teal-d);font-weight:700' : ''}">${r.lnL.toFixed(2)}</td>
        <td class="mono">${r.t.toFixed(3)}</td>
        <td><div class="suppr"><i style="width:${(100 * (r.lnL - worst) / span).toFixed(1)}%;background:${i === 0 ? 'var(--usach-teal)' : 'var(--usach-orange)'}"></i></div></td>
      </tr>`).join('')}
      </tbody></table>
    </div>
    <div style="display:flex;gap:9px;margin-top:12px;flex-wrap:wrap">
      <button class="toolbtn" id="mk-dl">${ic(SVGI.dl)}${esc(t('mk_csv'))}</button>
      <button class="toolbtn" id="mk-again">${esc(t('mk_again'))}</button>
    </div>`;
}

function suppBars(sup) {
  if (!sup || !sup.length) return '';
  const s = sup.slice().sort((a, b) => b.freq - a.freq);
  return s.map(x => {
    const p = Math.round(x.freq * 100);
    const col = p === 100 ? 'var(--usach-teal)' : p >= 50 ? 'var(--usach-orange)' : '#d64545';
    return `<div class="suppr"><i style="width:${p}%;background:${col}"></i><span class="mono">${p}%</span></div>`;
  }).join('');
}
function wireResults() {
  const R = S.res; if (!R) return;
  const tm = $('#tr-more');
  if (tm) tm.onclick = () => { S.cfg.hold = Math.max(1000, S.cfg.hold * 10); S.tab = 1; renderSteps(); render(); toast(t('re_trunc_set').replace('{n}', S.cfg.hold)); };
  $$('[data-cons]').forEach(b => b.onclick = () => download('consensus_' + b.dataset.cons + '.tre', R.consensus[b.dataset.cons].newick + '\n'));
  $('#dl-nwk').onclick = () => download('trees.nwk', R.newicks.join('\n') + '\n');
  $('#dl-tre').onclick = () => download('trees.tre',
    'tread \'PaleoForest · ' + R.unique + ' MPT · L=' + R.best + ' · seed=' + R.seed + '\'\n' +
    R.newicks.map(n => n.replace(/;$/, '')).join('*\n') + ';\nproc-;\n');
  $('#dl-nex').onclick = () => download('trees.nex', nexusTrees(R));
  $('#cp-nwk').onclick = () => copy(R.newicks.join('\n'));
  const mkb = $('#mk-run');
  if (mkb) mkb.onclick = () => runMk();
  const mka = $('#mk-again'); if (mka) mka.onclick = () => { S.mk = null; render(); };
  const mkd = $('#mk-dl');
  if (mkd) mkd.onclick = () => download('mk_lnl.csv',
    'orden;arbol;lnL;longitud_rama\n' + S.mk.rows.map((r, i) => [i + 1, r.i + 1, r.lnL.toFixed(6), r.t.toFixed(6)].join(';')).join('\n') + '\n');
  $('#to-pipe').onclick = () => {
    try {
      /* localStorage, no sessionStorage: sessionStorage es POR PESTAÑA, así que
         si el módulo 2 ya estaba abierto en otra pestaña no veía nada y cargaba
         el ejemplo. Con localStorage cualquier pestaña lo levanta. La marca de
         tiempo evita que un envío viejo reviva días después. */
      localStorage.setItem('pf_handoff', JSON.stringify({
        from: 'inferencia', at: Date.now(), name: S.mx.name, taxa: S.mx.taxa,
        matrix: S.mx.matrix, ordered: [...S.mx.ordered],
        newicks: R.newicks,
        best: R.best, seed: R.seed, truncated: R.truncated
      }));
      toast(t('re_sent'));
      setTimeout(() => location.href = 'pipeline.html?from=inferencia', 500);
    } catch (e) { toast(String(e.message || e)); }
  };
}

/* Recorrido guiado. Cada paso apunta a algo que EXISTE en la pantalla que
   corresponde, así que la guía navega sola. Si un objetivo no está (por ejemplo
   Resultados sin haber buscado), tour.js lo salta en vez de reventar. */
function startTour() {
  const L = I18N_INF[S.lang];
  /* Sin matriz cargada la vista de Matriz no existe, y la guía se saltaba del
     paso 1 al 6 sin decir nada: cinco pasos de trece, invisibles. La guía es
     para mostrar cómo funciona, así que si no hay nada carga el ejemplo. */
  if (!S.mx) { S.mx = mxFromExample(); S.tab = 0; renderSteps(); render(); toast(t('mx_loaded')); }
  PFTour.start({
    targets: [
      '#steps [data-i="0"]',
      '#mx-view',
      '.mxwrap',
      '#mx-view [data-v="chars"]',
      '#mx-dl',
      '#steps [data-i="1"]',
      '.critbox',
      '#seg-mode',
      '#c-hold',
      '#c-seed',
      '#run',
      '#steps [data-i="2"]',
      '#tourBtn'
    ],
    steps: L.tour,
    labels: { skip: L.tr_skip, prev: L.tr_prev, next: L.tr_next, done: L.tr_done },
    before: i => {
      // la guía lleva al usuario a la pestaña donde vive cada cosa
      if (i <= 4) { if (S.tab !== 0) { S.tab = 0; renderSteps(); render(); } }
      else if (i >= 5 && i <= 10) { if (S.mx && S.tab !== 1) { S.tab = 1; renderSteps(); render(); } }
      if (i === 2 && S.mxView !== 'cells') { S.mxView = 'cells'; render(); }
      if (i === 3 && S.mxView !== 'chars') { S.mxView = 'chars'; render(); }
    }
  });
}

/* Puntuar la meseta bajo Mk. Buscar bajo verosimilitud no cabe —habría que
   optimizar 173 ramas por topología candidata—, pero puntuar un conjunto ya
   encontrado sí: ~170 ms por árbol. */
async function runMk() {
  const R = S.res, M = S.mx;
  const b = $('#mk-run');
  if (b) { b.disabled = true; b.textContent = t('mk_running'); }
  await PFSearch.yieldNow();
  try {
    const P = PFMk.packMk(M.matrix, M.taxa, { inactive: [...M.inactive] });
    const ti = {}; M.taxa.forEach((n, i) => ti[n] = i);
    const trees = R.newicks.map(nw => newickToFlat(nw, ti, M.taxa.length)).filter(Boolean);
    const rows = await PFMk.scoreSet(trees, P, { yield: () => PFSearch.yieldNow() });
    S.mk = { rows: rows, nChar: P.chars.length };
    render();
  } catch (e) {
    toast(String((e && e.message) || e));
    if (b) { b.disabled = false; b.textContent = t('mk_run').replace('{n}', R.unique); }
  }
}

/* Newick -> árbol plano. Sólo binarios. */
function newickToFlat(nw, ti, nTax) {
  let i = 0;
  function node() {
    if (nw[i] === '(') {
      i++; const k = [];
      for (;;) { k.push(node()); if (nw[i] === ',') { i++; continue; } break; }
      if (nw[i] === ')') i++;
      while (i < nw.length && ',();'.indexOf(nw[i]) < 0) i++;
      return { kids: k };
    }
    let nm = '';
    if (nw[i] === "'") { i++; while (i < nw.length && nw[i] !== "'") { nm += nw[i]; i++; } i++; }
    else while (i < nw.length && ',();'.indexOf(nw[i]) < 0) { nm += nw[i]; i++; }
    return { kids: [], name: nm.trim() };
  }
  const r = node();
  let ok = true;
  (function chk(x) { if (!x.kids.length) return; if (x.kids.length !== 2) ok = false; x.kids.forEach(chk); })(r);
  if (!ok) return null;
  const t2 = PFSearch.newTree(nTax);
  const ints = []; for (let k = nTax; k < t2.nNode; k++) ints.push(k);
  let bad = false;
  function build(x) {
    if (!x.kids.length) { const ix = ti[x.name]; if (ix == null) { bad = true; return 0; } return ix; }
    const m = ints.pop(), a = build(x.kids[0]), b2 = build(x.kids[1]);
    t2.left[m] = a; t2.right[m] = b2; t2.up[a] = m; t2.up[b2] = m; return m;
  }
  const rt = build(r);
  if (bad) return null;
  t2.root = rt; t2.up[rt] = -1; t2.free = ints;
  return t2;
}

/* =============================== render =============================== */
function render() {
  closeHelp();
  const m = $('#main');
  m.innerHTML = S.tab === 0 ? viewMatrix() : S.tab === 1 ? viewSearch() : viewResults();
  if (S.tab === 0) wireMatrix(); else if (S.tab === 1) wireSearch(); else wireResults();
  wireHelp(m);
}
function boot() { document.documentElement.lang = S.lang; renderChrome(); render(); }
if (document.readyState === 'loading') addEventListener('DOMContentLoaded', boot); else boot();

})();
