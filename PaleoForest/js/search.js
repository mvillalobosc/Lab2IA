/* PaleoForest · js/search.js
   Búsqueda de árboles más parsimoniosos.
     Wagner RAS -> NNI/SPR/TBR con búfer de meseta -> ratchet -> cruzamiento
   Objetivo: parsimonia. Fitch (no aditivos) + Wagner (aditivos), mismo criterio
   que pipeline.js, sobre arreglos tipados y con largo incremental.

   Sin DOM. Corre en Worker o en Node.

   Árbol binario enraizado: nodos 0..nTax-1 hojas, nTax..2*nTax-2 internos.
   El largo del enraizado == largo sin raíz, así que la raíz da igual para el
   puntaje; la identidad topológica se compara por biparticiones canónicas
   (el lado que no contiene al taxón 0).
*/
(function (root) {
'use strict';

/* ============================== utilidades ============================== */

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shuffleIn(a, rnd) {
  for (let i = a.length - 1; i > 0; i--) { const j = (rnd() * (i + 1)) | 0; const t = a[i]; a[i] = a[j]; a[j] = t; }
  return a;
}

/* ========================= empaquetado de matriz ========================= */

const ALLF = 0xFFFFFFFF | 0;
const GAP_STATE = 15;

function tokMaskF(tok, gap) {
  if (tok === '?') return ALLF;
  if (tok === '-') return gap ? (1 << GAP_STATE) : ALLF;
  let m = 0;
  for (let i = 0; i < tok.length; i++) { const d = parseInt(tok[i], 36); if (!isNaN(d)) m |= (1 << d); }
  return m || ALLF;
}
function tokRangeW(tok, nst, gap) {
  if (tok === '?') return [0, nst - 1];
  if (tok === '-') return gap ? [nst, nst] : [0, nst - 1];
  let lo = 1e9, hi = -1;
  for (let i = 0; i < tok.length; i++) { const d = parseInt(tok[i], 36); if (!isNaN(d)) { if (d < lo) lo = d; if (d > hi) hi = d; } }
  if (hi < 0) return [0, nst - 1];
  return [lo, hi];
}
function isInformative(matrix, taxa, c, gap) {
  const cnt = new Map();
  for (let t = 0; t < taxa.length; t++) {
    const tok = matrix[taxa[t]][c];
    if (tok === '?') continue;
    if (tok === '-' && !gap) continue;
    cnt.set(tok, (cnt.get(tok) || 0) + 1);
  }
  if (cnt.size <= 1) return false;
  let multi = 0;
  cnt.forEach(function (v) { if (v >= 2) multi++; });
  return multi >= 2;
}
function complement(n, keep) {
  const k = new Set(keep), out = [];
  for (let i = 0; i < n; i++) if (!k.has(i)) out.push(i);
  return out;
}

/** opts = { ordered, inactive, weights, nst, gapAsState, stripUninformative } */
function packData(matrix, taxa, opts) {
  opts = opts || {};
  const nTax = taxa.length;
  const nchar = matrix[taxa[0]].length;
  const ord = new Set(opts.ordered || []);
  const off = new Set(opts.inactive || []);
  const wts = opts.weights || {};
  const nst = opts.nst || 8;
  const gap = !!opts.gapAsState;
  const strip = opts.stripUninformative !== false;

  const costs = opts.costs || {};             // { idxCarácter: matriz kxk }
  const keepF = [], keepW = [], keepS = [], dropF = [], dropW = [];
  for (let c = 0; c < nchar; c++) {
    if (off.has(c)) continue;
    if ((wts[c] == null ? 1 : wts[c]) === 0) continue;
    if (costs[c]) { keepS.push(c); continue; }   // Sankoff: no se filtra ni se poda
    const inf = !strip || isInformative(matrix, taxa, c, gap);
    if (ord.has(c)) (inf ? keepW : dropW).push(c); else (inf ? keepF : dropF).push(c);
  }
  const nF = keepF.length, nW = keepW.length, nS = keepS.length, nNode = 2 * nTax - 1;
  // los caracteres Sankoff comparten el ancho k = mayor matriz declarada
  let kS = 0;
  keepS.forEach(function (c) { if (costs[c].length > kS) kS = costs[c].length; });

  const D = {
    /* Pesos implícitos (Goloboff 1993). Si `implied` trae un valor de k, el
       puntaje deja de ser la suma de pasos y pasa a ser la suma de
       inaptitudes: e_i/(k+e_i), donde e_i son los pasos EXTRA del carácter i
       (los que sobran por encima de su mínimo posible). Un carácter que cambia
       mucho pesa menos por sí solo, sin que nadie declare el peso.

       Rompe el atajo incremental: la inaptitud es una función cóncava de los
       pasos POR CARÁCTER, así que no se puede acumular un escalar a lo largo
       del camino. Con k activo se recalcula el árbol entero por candidato. */
    implied: (opts.implied == null || opts.implied <= 0) ? null : +opts.implied,
    minF: new Float64Array(nF), minW: new Float64Array(nW),
    stepF: new Float64Array(nF), stepW: new Float64Array(nW),
    nTax: nTax, taxa: taxa.slice(), nchar: nchar, nF: nF, nW: nW, nS: nS, kS: kS, nNode: nNode,
    keepF: keepF, keepW: keepW, keepS: keepS, constant: 0,
    wF: new Float64Array(nF), wW: new Float64Array(nW), wS: new Float64Array(nS),
    cS: new Float64Array(nS * kS * kS),          // matrices de costo aplanadas
    gS: new Float64Array(nNode * nS * kS),       // vectores de Sankoff por nodo
    pS: new Float64Array((nNode + 2) * nS * kS),
    dsF: new Int32Array(nNode * nF),
    dsWlo: new Int32Array(nNode * nW),
    dsWhi: new Int32Array(nNode * nW),
    nodeSteps: new Float64Array(nNode),
    toRoot: new Float64Array(nNode),
    post: new Int32Array(nNode),
    pre: new Int32Array(nNode),
    stack: new Int32Array(nNode + 8),
    pF: new Int32Array((nNode + 2) * nF),
    pWlo: new Int32Array((nNode + 2) * nW),
    pWhi: new Int32Array((nNode + 2) * nW)
  };
  for (let j = 0; j < nF; j++) {
    const c = keepF[j];
    D.wF[j] = wts[c] == null ? 1 : wts[c];
    for (let t = 0; t < nTax; t++) D.dsF[t * nF + j] = tokMaskF(matrix[taxa[t]][c], gap);
  }
  for (let j = 0; j < nW; j++) {
    const c = keepW[j];
    D.wW[j] = wts[c] == null ? 1 : wts[c];
    for (let t = 0; t < nTax; t++) {
      const r = tokRangeW(matrix[taxa[t]][c], nst, gap);
      D.dsWlo[t * nW + j] = r[0]; D.dsWhi[t * nW + j] = r[1];
    }
  }
  // Sankoff: coste de ir del estado i al j según la matriz declarada.
  // g[nodo][s] = suma sobre hijos de min_t ( C[s][t] + g[hijo][t] ).
  for (let j = 0; j < nS; j++) {
    const c = keepS[j], M = costs[c];
    D.wS[j] = wts[c] == null ? 1 : wts[c];
    for (let a = 0; a < kS; a++) for (let b = 0; b < kS; b++) {
      const v = (M[a] && M[a][b] != null) ? M[a][b] : (a === b ? 0 : Infinity);
      D.cS[(j * kS + a) * kS + b] = v;
    }
    for (let tx = 0; tx < nTax; tx++) {
      const tok = matrix[taxa[tx]][c];
      const any = (tok === '?') || (tok === '-' && !gap);
      const obs = [];
      if (!any) for (let i2 = 0; i2 < tok.length; i2++) { const d = parseInt(tok[i2], 36); if (!isNaN(d)) obs.push(d); }
      for (let a = 0; a < kS; a++) {
        D.gS[(tx * nS + j) * kS + a] = (any || obs.indexOf(a) >= 0) ? 0 : Infinity;
      }
    }
  }

  /* Pasos mínimos posibles de cada carácter: los que cuesta en CUALQUIER árbol.
     Fitch: nº de estados observados - 1. Wagner: el rango observado. Lo que
     exceda eso es homoplasia, y es lo que los pesos implícitos penalizan. */
  for (let j = 0; j < nF; j++) {
    const c = keepF[j], seen = new Set();
    for (let t = 0; t < nTax; t++) {
      const tok = matrix[taxa[t]][c];
      if (tok === '?' || (tok === '-' && !gap)) continue;
      for (const ch of tok) { const d = parseInt(ch, 36); if (!isNaN(d)) seen.add(d); }
      if (tok === '-' && gap) seen.add(GAP_STATE);
    }
    D.minF[j] = Math.max(0, seen.size - 1);
  }
  for (let j = 0; j < nW; j++) {
    const c = keepW[j];
    let lo = 1e9, hi = -1;
    for (let t = 0; t < nTax; t++) {
      const tok = matrix[taxa[t]][c];
      if (tok === '?' || tok === '-') continue;
      for (const ch of tok) { const d = parseInt(ch, 36); if (!isNaN(d)) { if (d < lo) lo = d; if (d > hi) hi = d; } }
    }
    D.minW[j] = hi < 0 ? 0 : Math.max(0, hi - lo);
  }
  if (dropF.length || dropW.length) {
    const sub = packData(matrix, taxa, {
      ordered: dropW, inactive: complement(nchar, dropF.concat(dropW)),
      weights: wts, nst: nst, gapAsState: gap, stripUninformative: false
    });
    D.constant = scoreFull(ladderTree(nTax), sub, Infinity);
  }
  return D;
}

/* ============================ árbol / topología ============================ */

function newTree(nTax) {
  const nNode = 2 * nTax - 1;
  return {
    n: nTax, nNode: nNode,
    left: new Int32Array(nNode).fill(-1),
    right: new Int32Array(nNode).fill(-1),
    up: new Int32Array(nNode).fill(-1),
    root: -1, free: [], len: -1
  };
}
function cloneTree(t) {
  const o = newTree(t.n);
  o.left.set(t.left); o.right.set(t.right); o.up.set(t.up);
  o.root = t.root; o.free = t.free.slice(); o.len = t.len;
  return o;
}
function ladderTree(nTax) {
  const t = newTree(nTax);
  const ints = []; for (let i = nTax; i < t.nNode; i++) ints.push(i);
  let cur = ints.pop();
  t.left[cur] = 0; t.right[cur] = 1; t.up[0] = cur; t.up[1] = cur;
  for (let i = 2; i < nTax; i++) {
    const m = ints.pop();
    t.left[m] = cur; t.right[m] = i; t.up[cur] = m; t.up[i] = m; cur = m;
  }
  t.root = cur; t.up[cur] = -1; t.free = ints;
  return t;
}
/** Inserta `sub` en la arista (up[v], v) con el interno libre `w`. */
function insertAt(t, w, v, sub) {
  const u = t.up[v];
  t.left[w] = v; t.right[w] = sub;
  t.up[v] = w; t.up[sub] = w; t.up[w] = u;
  if (u === -1) t.root = w;
  else if (t.left[u] === v) t.left[u] = w; else t.right[u] = w;
}
/** Poda el subárbol de raíz x; devuelve el interno liberado (o -1). */
function prune(t, x) {
  const p = t.up[x];
  if (p === -1) return -1;
  const sib = t.left[p] === x ? t.right[p] : t.left[p];
  const g = t.up[p];
  t.up[sib] = g;
  if (g === -1) t.root = sib;
  else if (t.left[g] === p) t.left[g] = sib; else t.right[g] = sib;
  t.up[x] = -1; t.left[p] = -1; t.right[p] = -1; t.up[p] = -1;
  return p;
}
function randomTree(nTax, rnd) {
  const order = []; for (let i = 0; i < nTax; i++) order.push(i);
  shuffleIn(order, rnd);
  const t = newTree(nTax);
  const ints = []; for (let i = nTax; i < t.nNode; i++) ints.push(i);
  const m = ints.pop();
  t.left[m] = order[0]; t.right[m] = order[1];
  t.up[order[0]] = m; t.up[order[1]] = m; t.up[m] = -1; t.root = m;
  const edges = [order[0], order[1]];
  for (let i = 2; i < nTax; i++) {
    const v = edges[(rnd() * edges.length) | 0];
    const w = ints.pop();
    insertAt(t, w, v, order[i]);
    edges.push(order[i]); edges.push(v);
  }
  t.free = ints;
  return t;
}

function postorder(t, D) {
  const st = D.stack, po = D.post;
  let sp = 0, cnt = 0;
  st[sp++] = t.root;
  while (sp) {
    const nd = st[--sp];
    if (nd < t.n) continue;
    po[cnt++] = nd;
    st[sp++] = t.left[nd]; st[sp++] = t.right[nd];
  }
  for (let i = 0, j = cnt - 1; i < j; i++, j--) { const x = po[i]; po[i] = po[j]; po[j] = x; }
  return cnt;
}
function preorderAll(t, D) {
  const st = D.stack, pre = D.pre;
  let sp = 0, cnt = 0;
  st[sp++] = t.root;
  while (sp) {
    const nd = st[--sp];
    pre[cnt++] = nd;
    if (nd >= t.n) { st[sp++] = t.left[nd]; st[sp++] = t.right[nd]; }
  }
  return cnt;
}
function subtreeNodes(t, r) {
  const out = [], st = [r];
  while (st.length) { const nd = st.pop(); out.push(nd); if (nd >= t.n) { st.push(t.left[nd]); st.push(t.right[nd]); } }
  return out;
}

/* =============================== puntuación =============================== */

function scoreFull(t, D, bound) {
  const cnt = postorder(t, D);
  const nF = D.nF, nW = D.nW, nS = D.nS, ds = D.dsF, wF = D.wF;
  const dlo = D.dsWlo, dhi = D.dsWhi, wW = D.wW;
  const L = t.left, R = t.right, ns = D.nodeSteps, po = D.post;
  bound = bound == null ? Infinity : bound;
  const iw = D.implied;
  if (iw) { D.stepF.fill(0); D.stepW.fill(0); }
  let total = 0;
  for (let i = 0; i < cnt; i++) {
    const nd = po[i], l = L[nd], r = R[nd];
    const lo = l * nF, ro = r * nF, no = nd * nF;
    let st = 0;
    for (let c = 0; c < nF; c++) {
      const a = ds[lo + c], b = ds[ro + c], s = a & b;
      if (s) ds[no + c] = s; else { ds[no + c] = a | b; st += wF[c]; if (iw) D.stepF[c]++; }
    }
    if (nW) {
      const lw = l * nW, rw = r * nW, nw = nd * nW;
      for (let c = 0; c < nW; c++) {
        const a0 = dlo[lw + c], a1 = dhi[lw + c], b0 = dlo[rw + c], b1 = dhi[rw + c];
        const x = a0 > b0 ? a0 : b0, y = a1 < b1 ? a1 : b1;
        if (x <= y) { dlo[nw + c] = x; dhi[nw + c] = y; }
        else if (a1 < b0) { st += (b0 - a1) * wW[c]; if (iw) D.stepW[c] += (b0 - a1); dlo[nw + c] = a1; dhi[nw + c] = b0; }
        else { st += (a0 - b1) * wW[c]; if (iw) D.stepW[c] += (a0 - b1); dlo[nw + c] = b1; dhi[nw + c] = a0; }
      }
    }

    if (nS) {
      const kk = D.kS, gs = D.gS, cs = D.cS;
      const lg = l * nS * kk, rg = r * nS * kk, ng = nd * nS * kk;
      for (let j = 0; j < nS; j++) {
        const jo = j * kk, cb = j * kk * kk;
        for (let a = 0; a < kk; a++) {
          let bl = Infinity, br = Infinity;
          const ca = cb + a * kk;
          for (let b = 0; b < kk; b++) {
            const x = cs[ca + b] + gs[lg + jo + b]; if (x < bl) bl = x;
            const y = cs[ca + b] + gs[rg + jo + b]; if (y < br) br = y;
          }
          gs[ng + jo + a] = bl + br;
        }
      }
    }
    ns[nd] = st; total += st;
    if (!iw && total > bound) return Infinity;   // bajo k el puntaje no es la suma de pasos
  }
  if (iw) return impliedScore(D);
  return total + D.constant + (nS ? sankRoot(t, D) : 0);
}

/* Suma de inaptitudes: e_i/(k+e_i), con e_i = pasos extra del carácter i.
   Menor es mejor, igual que la parsimonia. Cada carácter aporta como mucho 1,
   así que el puntaje está acotado por el nº de caracteres: no es comparable
   con un largo de parsimonia. */
function impliedScore(D) {
  const k = D.implied;
  let tot = 0;
  for (let c = 0; c < D.nF; c++) {
    const e = D.stepF[c] - D.minF[c];
    if (e > 0) tot += e / (k + e);
  }
  for (let c = 0; c < D.nW; c++) {
    const e = D.stepW[c] - D.minW[c];
    if (e > 0) tot += e / (k + e);
  }
  return tot;
}

/* El aporte de los caracteres Sankoff se cobra en la raíz: min_s g[raíz][s].
   No entra en la cota incremental (no es acumulativo por nodo), así que los
   caracteres Sankoff no cortan la búsqueda antes de tiempo: sólo la encarecen. */
function sankRoot(t, D) {
  const kk = D.kS, gs = D.gS, wS = D.wS, nS = D.nS;
  const ro = t.root * nS * kk;
  let tot = 0;
  for (let j = 0; j < nS; j++) {
    let m = Infinity;
    const jo = j * kk;
    for (let a = 0; a < kk; a++) { const v = gs[ro + jo + a]; if (v < m) m = v; }
    tot += m * wS[j];
  }
  return tot;
}

/** ds/nodeSteps sólo dentro del subárbol de raíz r (para el subárbol suelto). */
function scoreSubtree(t, D, r) {
  if (r < t.n) return 0;
  const order = [], st = [r], seen = [];
  while (st.length) { const nd = st.pop(); if (nd < t.n) continue; seen.push(nd); st.push(t.left[nd]); st.push(t.right[nd]); }
  for (let i = seen.length - 1; i >= 0; i--) order.push(seen[i]);
  const nF = D.nF, nW = D.nW, nS = D.nS, ds = D.dsF, wF = D.wF, dlo = D.dsWlo, dhi = D.dsWhi, wW = D.wW;
  let tot = 0;
  for (let i = 0; i < order.length; i++) {
    const nd = order[i], l = t.left[nd], rr = t.right[nd];
    const lo = l * nF, ro = rr * nF, no = nd * nF;
    let s2 = 0;
    for (let c = 0; c < nF; c++) {
      const a = ds[lo + c], b = ds[ro + c], s = a & b;
      if (s) ds[no + c] = s; else { ds[no + c] = a | b; s2 += wF[c]; }
    }
    if (nW) {
      const lw = l * nW, rw = rr * nW, nw = nd * nW;
      for (let c = 0; c < nW; c++) {
        const a0 = dlo[lw + c], a1 = dhi[lw + c], b0 = dlo[rw + c], b1 = dhi[rw + c];
        const x = a0 > b0 ? a0 : b0, y = a1 < b1 ? a1 : b1;
        if (x <= y) { dlo[nw + c] = x; dhi[nw + c] = y; }
        else if (a1 < b0) { s2 += (b0 - a1) * wW[c]; dlo[nw + c] = a1; dhi[nw + c] = b0; }
        else { s2 += (a0 - b1) * wW[c]; dlo[nw + c] = b1; dhi[nw + c] = a0; }
      }
    }

    if (nS) {
      const kk = D.kS, gs = D.gS, cs = D.cS;
      const lg = l * nS * kk, rg = rr * nS * kk, ng = nd * nS * kk;
      for (let j = 0; j < nS; j++) {
        const jo = j * kk, cb = j * kk * kk;
        for (let a = 0; a < kk; a++) {
          let bl = Infinity, br = Infinity;
          const ca = cb + a * kk;
          for (let b = 0; b < kk; b++) {
            const x = cs[ca + b] + gs[lg + jo + b]; if (x < bl) bl = x;
            const y = cs[ca + b] + gs[rg + jo + b]; if (y < br) br = y;
          }
          gs[ng + jo + a] = bl + br;
        }
      }
    }
    D.nodeSteps[nd] = s2; tot += s2;
  }
  return tot;
}
function fillToRoot(t, D) {
  const cnt = preorderAll(t, D);
  const pre = D.pre, up = t.up, ns = D.nodeSteps, tr = D.toRoot;
  for (let i = 0; i < cnt; i++) {
    const nd = pre[i], s = nd < t.n ? 0 : ns[nd];
    tr[nd] = up[nd] === -1 ? s : s + tr[up[nd]];
  }
}
function prepare(t, D) { t.len = scoreFull(t, D, Infinity); fillToRoot(t, D); return t.len; }

/**
 * Largo de insertar el subárbol `sub` (ds ya calculado) en la arista (up[v], v)
 * del árbol `t`, sin modificarlo. `baseLen` = largo de `t`, preparado.
 * Sólo recalcula el camino nuevo hasta la raíz; corta por cota.
 */
function evalInsert(t, D, v, sub, baseLen, bound) {
  const nF = D.nF, nW = D.nW;
  const ds = D.dsF, wF = D.wF, dlo = D.dsWlo, dhi = D.dsWhi, wW = D.wW;
  const pF = D.pF, pWlo = D.pWlo, pWhi = D.pWhi;
  const L = t.left, R = t.right, up = t.up, tr = D.toRoot;
  const u = up[v];
  let acc = (u === -1 ? baseLen : baseLen - tr[u]);
  if (acc > bound) return Infinity;
  {
    const ao = v * nF, bo = sub * nF;
    let st = 0;
    for (let c = 0; c < nF; c++) {
      const a = ds[ao + c], b = ds[bo + c], s = a & b;
      if (s) pF[c] = s; else { pF[c] = a | b; st += wF[c]; }
    }
    if (nW) {
      const aw = v * nW, bw = sub * nW;
      for (let c = 0; c < nW; c++) {
        const a0 = dlo[aw + c], a1 = dhi[aw + c], b0 = dlo[bw + c], b1 = dhi[bw + c];
        const x = a0 > b0 ? a0 : b0, y = a1 < b1 ? a1 : b1;
        if (x <= y) { pWlo[c] = x; pWhi[c] = y; }
        else if (a1 < b0) { st += (b0 - a1) * wW[c]; pWlo[c] = a1; pWhi[c] = b0; }
        else { st += (a0 - b1) * wW[c]; pWlo[c] = b1; pWhi[c] = a0; }
      }
    }
    acc += st;
    if (acc > bound) return Infinity;
  }
  if (u === -1) return acc;
  let child = v, prevSlot = 0, slot = 1, k = u;
  while (k !== -1) {
    const other = L[k] === child ? R[k] : L[k];
    const po = prevSlot * nF, oo = other * nF, no = slot * nF;
    let st = 0;
    for (let c = 0; c < nF; c++) {
      const a = pF[po + c], b = ds[oo + c], s = a & b;
      if (s) pF[no + c] = s; else { pF[no + c] = a | b; st += wF[c]; }
    }
    if (nW) {
      const pw = prevSlot * nW, ow = other * nW, nw = slot * nW;
      for (let c = 0; c < nW; c++) {
        const a0 = pWlo[pw + c], a1 = pWhi[pw + c], b0 = dlo[ow + c], b1 = dhi[ow + c];
        const x = a0 > b0 ? a0 : b0, y = a1 < b1 ? a1 : b1;
        if (x <= y) { pWlo[nw + c] = x; pWhi[nw + c] = y; }
        else if (a1 < b0) { st += (b0 - a1) * wW[c]; pWlo[nw + c] = a1; pWhi[nw + c] = b0; }
        else { st += (a0 - b1) * wW[c]; pWlo[nw + c] = b1; pWhi[nw + c] = a0; }
      }
    }
    acc += st;
    if (acc > bound) return Infinity;
    child = k; prevSlot = slot; slot++; k = up[k];
  }
  return acc;
}

/**
 * Inserta de verdad, puntúa y deshace. Se usa cuando hay caracteres Sankoff:
 * su coste se cobra en la raíz, no por nodo, así que el camino incremental no
 * lo sabe calcular. Es exacto y ~40x más lento que evalInsert.
 */
function exactInsert(t, D, v, sub, freed, bound) {
  insertAt(t, freed, v, sub);
  const L = scoreFull(t, D, bound);
  prune(t, sub);           // deshace exactamente lo que hizo insertAt
  return L;
}

/**
 * Rerootea el subárbol SUELTO de raíz x (up[x] === -1) sobre la arista (up/v, v).
 * Reutiliza x como nueva raíz. Devuelve x, o -1 si v no aplica.
 */
function rerootLoose(t, x, v) {
  if (v === x) return x;
  if (t.up[v] === x) return x;              // ya es esa raíz
  const chainNodes = [], others = [];
  let cur = v;
  while (t.up[cur] !== -1) {
    const p = t.up[cur];
    chainNodes.push(p);
    others.push(t.left[p] === cur ? t.right[p] : t.left[p]);
    cur = p;
    if (p === x) break;
  }
  if (chainNodes[chainNodes.length - 1] !== x) return -1;
  const m = chainNodes.length;              // chainNodes[m-1] === x
  let acc = others[m - 1];                  // el "otro" hijo de x
  for (let i = m - 2; i >= 0; i--) {
    t.left[chainNodes[i]] = others[i];
    t.right[chainNodes[i]] = acc;
    t.up[others[i]] = chainNodes[i];
    t.up[acc] = chainNodes[i];
    acc = chainNodes[i];
  }
  t.left[x] = v; t.right[x] = acc;
  t.up[v] = x; t.up[acc] = x; t.up[x] = -1;
  return x;
}

/* ============================ biparticiones ============================ */

function bitWords(n) { return (n + 31) >> 5; }
function popcnt(x) {
  x = x - ((x >>> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >>> 2) & 0x33333333);
  x = (x + (x >>> 4)) & 0x0f0f0f0f;
  return (Math.imul(x, 0x01010101) >>> 24);
}
function cmpRow(a, b) {
  const L = Math.min(a.length, b.length);
  for (let i = 0; i < L; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  return a.length - b.length;
}
/** Conjunto canónico y ordenado de biparticiones internas, aplanado. */
function splitKey(t, D) {
  const n = t.n, W = bitWords(n);
  const cnt = postorder(t, D);
  const bits = new Uint32Array(t.nNode * W);
  for (let i = 0; i < n; i++) bits[i * W + (i >> 5)] |= (1 << (i & 31));
  const rows = [];
  const lastMask = (n & 31) ? (0xFFFFFFFF >>> (32 - (n & 31))) : 0xFFFFFFFF;
  for (let i = 0; i < cnt; i++) {
    const nd = D.post[i], l = t.left[nd], r = t.right[nd];
    const no = nd * W, lo = l * W, ro = r * W;
    for (let w = 0; w < W; w++) bits[no + w] = (bits[lo + w] | bits[ro + w]) >>> 0;
    // Los dos hijos de la raíz definen conjuntos complementarios, o sea la MISMA
    // bipartición sin raíz. Contar ambos duplica la rama y corrompe el soporte y
    // los umbrales de consenso. Se toma sólo uno.
    if (nd === t.root || nd === t.right[t.root]) continue;
    const has0 = (bits[no] & 1) !== 0;
    const row = new Uint32Array(W);
    let pop = 0;
    for (let w = 0; w < W; w++) {
      let x = has0 ? (~bits[no + w]) : bits[no + w];
      if (w === W - 1) x &= lastMask;
      row[w] = x >>> 0;
      pop += popcnt(row[w]);
    }
    if (pop < 2 || pop > n - 2) continue;
    rows.push(row);
  }
  rows.sort(cmpRow);
  const out = new Uint32Array(rows.length * W);
  for (let i = 0; i < rows.length; i++) out.set(rows[i], i * W);
  return out;
}
function fnv(a) {
  let h = 0x811c9dc5;
  for (let i = 0; i < a.length; i++) {
    let v = a[i];
    for (let b = 0; b < 4; b++) { h ^= (v & 0xFF); h = Math.imul(h, 0x01000193); v >>>= 8; }
  }
  return h >>> 0;
}

function Archive(limit) {
  this.map = new Map(); this.list = []; this.limit = limit || 100000; this.dups = 0;
}
Archive.prototype.add = function (tree, key) {
  const h = fnv(key);
  let b = this.map.get(h);
  if (!b) { b = []; this.map.set(h, b); }
  for (let i = 0; i < b.length; i++) {
    if (b[i].key.length === key.length && cmpRow(b[i].key, key) === 0) { this.dups++; return false; }
  }
  if (this.list.length >= this.limit) return false;
  const rec = { key: key, tree: tree };
  b.push(rec); this.list.push(rec);
  return true;
};
Archive.prototype.has = function (key) {
  const b = this.map.get(fnv(key));
  if (!b) return false;
  for (let i = 0; i < b.length; i++) if (b[i].key.length === key.length && cmpRow(b[i].key, key) === 0) return true;
  return false;
};
Archive.prototype.size = function () { return this.list.length; };
Archive.prototype.full = function () { return this.list.length >= this.limit; };

/* ========================= adición de Wagner (RAS) ========================= */

function wagnerAdd(D, order, rnd) {
  const n = D.nTax;
  const t = newTree(n);
  const ints = []; for (let i = n; i < t.nNode; i++) ints.push(i);
  const m = ints.pop();
  t.left[m] = order[0]; t.right[m] = order[1];
  t.up[order[0]] = m; t.up[order[1]] = m; t.up[m] = -1; t.root = m;
  const edges = [order[0], order[1]];
  for (let i = 2; i < n; i++) {
    const tx = order[i];
    prepare(t, D);
    const base = t.len;
    let best = Infinity, bestV = -1, ties = 0;
    const wFree = ints[ints.length - 1];
    for (let e = 0; e <= edges.length; e++) {
      const v = (e === edges.length) ? t.root : edges[e];
      const L = (D.nS || D.implied) ? exactInsert(t, D, v, tx, wFree, best)
                                    : evalInsert(t, D, v, tx, base, best);
      if (L < best) { best = L; bestV = v; ties = 1; }
      else if (L === best && L !== Infinity) { ties++; if (rnd() < 1 / ties) bestV = v; }
    }
    if (bestV < 0) bestV = edges[0];
    const w = ints.pop();
    insertAt(t, w, bestV, tx);
    edges.push(tx); edges.push(bestV);
    if (t.up[w] !== -1) edges.push(w);
  }
  t.free = ints;
  prepare(t, D);
  return t;
}


/* ============================ Neighbor joining ============================

   NJ no es un criterio de optimalidad: es un algoritmo que construye UN árbol
   a partir de una matriz de distancias. Acá sirve como punto de partida, no
   como resultado: da un árbol razonable de una pasada, y después el TBR lo
   mejora bajo parsimonia.

   Ojo con usarlo en varias réplicas: NJ es determinista, así que las réplicas
   arrancarían todas del mismo árbol y dejarían de explorar. Por eso searchMPA
   sólo lo usa en la primera y sigue con adición aleatoria en las demás.

   NO se ofrece en la interfaz, y es a propósito: medido en Arackar, NJ arranca
   en 1534 contra 1395 de la adición de Wagner. Es PEOR punto de partida, porque
   optimiza distancia y no parsimonia, y con 61% de faltantes las p-distancias
   son ruido. Queda accesible por `start:'nj'` para quien lo quiera comparar. */

/** p-distancia entre dos taxones: proporción de caracteres comparables que
    difieren. Un carácter es comparable si ninguno de los dos es faltante.
    Dos estados difieren si sus conjuntos no se intersectan (un polimorfismo
    que incluye al otro estado NO cuenta como diferencia). */
function pDist(D, a, b) {
  const nF = D.nF, ds = D.dsF, ao = a * nF, bo = b * nF;
  let comp = 0, diff = 0;
  for (let c = 0; c < nF; c++) {
    const x = ds[ao + c], y = ds[bo + c];
    if (x === ALLF || y === ALLF) continue;   // faltante: no compara
    comp++;
    if ((x & y) === 0) diff++;
  }
  const nW = D.nW, lo = D.dsWlo, hi = D.dsWhi;
  for (let c = 0; c < nW; c++) {
    const aw = a * nW + c, bw = b * nW + c;
    const a0 = lo[aw], a1 = hi[aw], b0 = lo[bw], b1 = hi[bw];
    // rango completo = faltante
    if ((a1 - a0) > 6 || (b1 - b0) > 6) continue;
    comp++;
    if (a1 < b0 || b1 < a0) diff++;
  }
  return comp ? diff / comp : 0;   // sin nada comparable: no hay evidencia de diferencia
}

/** Matriz de p-distancias, simétrica. */
function distMatrix(D) {
  const n = D.nTax;
  const M = [];
  for (let i = 0; i < n; i++) M.push(new Float64Array(n));
  for (let i = 0; i < n; i++)
    for (let j = i + 1; j < n; j++) { const d = pDist(D, i, j); M[i][j] = d; M[j][i] = d; }
  return M;
}

/** Neighbor joining (Saitou & Nei 1987). Devuelve un árbol plano binario. */
function njTree(D, dm) {
  const n = D.nTax;
  if (n < 3) return ladderTree(n);
  const M = dm || distMatrix(D);
  const t = newTree(n);
  const ints = []; for (let i = n; i < t.nNode; i++) ints.push(i);

  // d[] indexado por «cluster vivo»; cada cluster apunta a un nodo del árbol
  let act = [];                       // ids de nodo de los clusters vivos
  for (let i = 0; i < n; i++) act.push(i);
  const d = {};                       // d[a][b] entre ids de nodo
  act.forEach(a => { d[a] = {}; });
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (i !== j) d[i][j] = M[i][j];

  while (act.length > 2) {
    const m = act.length;
    const r = {};
    act.forEach(a => { let s2 = 0; act.forEach(b => { if (a !== b) s2 += d[a][b]; }); r[a] = s2; });
    let bi = -1, bj = -1, bq = Infinity;
    for (let i = 0; i < m; i++) for (let j = i + 1; j < m; j++) {
      const a = act[i], b = act[j];
      const q = (m - 2) * d[a][b] - r[a] - r[b];
      if (q < bq) { bq = q; bi = a; bj = b; }
    }
    const u = ints.pop();
    t.left[u] = bi; t.right[u] = bj; t.up[bi] = u; t.up[bj] = u;
    d[u] = {};
    act.forEach(k => {
      if (k === bi || k === bj) return;
      const dk = (d[bi][k] + d[bj][k] - d[bi][bj]) / 2;
      d[u][k] = dk; d[k][u] = dk;
    });
    act = act.filter(x => x !== bi && x !== bj);
    act.push(u);
  }
  // los dos últimos se juntan en la raíz
  const rt = ints.pop();
  t.left[rt] = act[0]; t.right[rt] = act[1];
  t.up[act[0]] = rt; t.up[act[1]] = rt; t.up[rt] = -1;
  t.root = rt; t.free = ints;
  return t;
}

/* ======================== rearreglos NNI / SPR / TBR ======================== */

/**
 * Recorre la vecindad de `t`. cb(cloneCallback, len) por cada vecino con len <= bound.
 * cb devuelve true para cortar. `mode`: 'NNI' | 'SPR' | 'TBR'.
 * Devuelve { evaluated, stopped }.
 */
function swapNeighbourhood(t, D, mode, bound, cb, rnd, opts) {
  opts = opts || {};
  const n = t.n;
  let evaluated = 0;
  const preCnt = preorderAll(t, D);
  const prunes = [];
  for (let i = 0; i < preCnt; i++) {
    const x = D.pre[i];
    if (x === t.root || t.up[x] === t.root) continue;
    prunes.push(x);
  }
  if (opts.randomize !== false && rnd) shuffleIn(prunes, rnd);

  for (let pi = 0; pi < prunes.length; pi++) {
    const x = prunes[pi];
    const work = cloneTree(t);
    const p = work.up[x];
    const sib = work.left[p] === x ? work.right[p] : work.left[p];
    const freed = prune(work, x);
    if (freed < 0) continue;

    // OJO: el largo base debe incluir los pasos INTERNOS del subárbol podado.
    // scoreFull(residual) sólo cuenta el residual; sin esto, podar un clado
    // subestima el largo por todo lo que el clado aporta por dentro.
    const resLen = scoreFull(work, D, Infinity);
    fillToRoot(work, D);

    // candidatos de reinjerto en el residual
    let cand = subtreeNodes(work, work.root).filter(function (v) { return v !== sib && v !== work.root; });
    cand.push(work.root);
    if (mode === 'NNI') {
      const near = new Set();
      const gp = work.up[sib];
      if (gp !== -1) {
        const unc = work.left[gp] === sib ? work.right[gp] : work.left[gp];
        near.add(unc);
      }
      if (sib >= n) { near.add(work.left[sib]); near.add(work.right[sib]); }
      cand = cand.filter(function (v) { return near.has(v); });
    }
    if (opts.randomize !== false && rnd) shuffleIn(cand, rnd);

    // rerooteos del subárbol podado
    const subNodes = subtreeNodes(work, x);
    let reroots = [x];
    if (mode === 'TBR' && x >= n) {
      reroots = [x].concat(subNodes.filter(function (v) { return v !== x && work.up[v] !== x; }));
      if (opts.randomize !== false && rnd) { const h = reroots.shift(); shuffleIn(reroots, rnd); reroots.unshift(h); }
      if (opts.maxReroot) reroots = reroots.slice(0, opts.maxReroot);
    }
    // respaldo del subárbol para poder restaurar entre rerooteos
    const bkL = {}, bkR = {}, bkU = {};
    subNodes.forEach(function (nd) { bkL[nd] = work.left[nd]; bkR[nd] = work.right[nd]; bkU[nd] = work.up[nd]; });

    for (let ri = 0; ri < reroots.length; ri++) {
      if (ri > 0) {
        subNodes.forEach(function (nd) { work.left[nd] = bkL[nd]; work.right[nd] = bkR[nd]; work.up[nd] = bkU[nd]; });
        const nr = rerootLoose(work, x, reroots[ri]);
        if (nr < 0) continue;
      }
      const subSteps = scoreSubtree(work, D, x);
      const baseLen = resLen + subSteps;
      // con Sankoff cada candidato hace un scoreFull que pisa los ds; el
      // residual se vuelve a preparar dentro de exactInsert, así que no hace
      // falta nada más aquí.
      for (let ci = 0; ci < cand.length; ci++) {
        const v = cand[ci];
        const L = (D.nS || D.implied) ? exactInsert(work, D, v, x, freed, bound)
                                      : evalInsert(work, D, v, x, baseLen, bound);
        evaluated++;
        if (L === Infinity) continue;
        const nt = cloneTree(work);
        insertAt(nt, freed, v, x);
        nt.len = L;
        nt.free = nt.free.filter(function (z) { return z !== freed; });
        if (cb(nt, L)) return { evaluated: evaluated, stopped: true };
      }
    }
  }
  return { evaluated: evaluated, stopped: false };
}

/* ============================ colapso de ramas ============================ */

/**
 * ¿La rama (up[v], v) tiene soporte? Criterio operativo, equivalente a la regla
 * "largo mínimo = 0": la rama NO tiene soporte si alguno de sus dos rearreglos
 * NNI da el mismo largo. Si ambas alternativas son estrictamente peores, la
 * rama está sostenida por al menos un carácter y no se colapsa.
 * No modifica el árbol (deshace los cambios).
 */
function branchSupported(t, D, v, best) {
  const u = t.up[v];
  if (u === -1 || v < t.n) return true;          // sólo ramas internas
  const o = t.left[u] === v ? t.right[u] : t.left[u];
  const a = t.left[v], b = t.right[v];
  const tol = 1e-9;
  const oIsLeft = t.left[u] !== v;
  function setU(x) { if (oIsLeft) t.left[u] = x; else t.right[u] = x; }

  // alternativa 1: v=(o,b), u=(v,a)
  t.left[v] = o; t.right[v] = b; t.up[o] = v;
  setU(a); t.up[a] = u;
  const s1 = scoreFull(t, D, best + tol);
  // alternativa 2: v=(a,o), u=(v,b)
  t.left[v] = a; t.right[v] = o; t.up[a] = v; t.up[o] = v;
  setU(b); t.up[b] = u;
  const s2 = scoreFull(t, D, best + tol);
  // restaurar
  t.left[v] = a; t.right[v] = b; t.up[a] = v; t.up[b] = v;
  setU(o); t.up[o] = u;

  return !(s1 <= best + tol || s2 <= best + tol);
}

/** Biparticiones que sobreviven al colapso de ramas sin soporte. */
function collapsedKey(t, D, best) {
  const n = t.n, W = bitWords(n);
  const cnt = postorder(t, D);
  const bits = new Uint32Array(t.nNode * W);
  for (let i = 0; i < n; i++) bits[i * W + (i >> 5)] |= (1 << (i & 31));
  const order = [];
  for (let i = 0; i < cnt; i++) {
    const nd = D.post[i], l = t.left[nd], r = t.right[nd];
    const no = nd * W, lo = l * W, ro = r * W;
    for (let w = 0; w < W; w++) bits[no + w] = (bits[lo + w] | bits[ro + w]) >>> 0;
    order.push(nd);
  }
  const lastMask = (n & 31) ? (0xFFFFFFFF >>> (32 - (n & 31))) : 0xFFFFFFFF;
  const rows = [];
  for (let i = 0; i < order.length; i++) {
    const nd = order[i];
    if (nd === t.root || nd === t.right[t.root]) continue;
    const no = nd * W;
    const has0 = (bits[no] & 1) !== 0;
    const row = new Uint32Array(W);
    let pop = 0;
    for (let w = 0; w < W; w++) {
      let x = has0 ? (~bits[no + w]) : bits[no + w];
      if (w === W - 1) x &= lastMask;
      row[w] = x >>> 0; pop += popcnt(row[w]);
    }
    if (pop < 2 || pop > n - 2) continue;
    if (!branchSupported(t, D, nd, best)) continue;   // rama colapsada: se descarta
    rows.push(row);
  }
  rows.sort(cmpRow);
  const out = new Uint32Array(rows.length * W);
  for (let i = 0; i < rows.length; i++) out.set(rows[i], i * W);
  return out;
}


/* ============================== Tree fusing ==============================

   Goloboff (1999). Es lo que hace rápido a TNT, no el C.

   Dos árboles que salieron de réplicas distintas suelen coincidir en casi todo
   y diferir en unas pocas regiones: cada uno resolvió bien una parte. Fusing
   busca clados con EXACTAMENTE la misma composición de taxones en ambos, y
   pasa la versión de uno al otro. Como la composición es idéntica, el injerto
   siempre da un árbol válido: no hace falta reparar nada.

   Visto desde computación evolutiva, esto es crossover con reparación implícita
   —el operador que todo GA de árboles tiene que inventar—. Goloboff llegó ahí
   por otro camino y sin usar la palabra.

   Sólo rinde entre árboles YA rearreglados: dos árboles al azar no comparten
   clados de igual composición y no hay nada que intercambiar. Por eso va después
   de las réplicas, sobre el pool de óptimos locales. */

/** Conjunto de hojas de cada nodo, como clave hex. Devuelve Map clave -> nodo. */
function cladeMap(t, D) {
  const n = t.n, W = bitWords(n);
  const cnt = postorder(t, D);
  const bits = new Uint32Array(t.nNode * W);
  for (let i = 0; i < n; i++) bits[i * W + (i >> 5)] |= (1 << (i & 31));
  const m = new Map();
  for (let i = 0; i < cnt; i++) {
    const nd = D.post[i], l = t.left[nd], r = t.right[nd];
    const no = nd * W, lo = l * W, ro = r * W;
    for (let w = 0; w < W; w++) bits[no + w] = (bits[lo + w] | bits[ro + w]) >>> 0;
    if (nd === t.root) continue;
    let pop = 0, key = '';
    for (let w = 0; w < W; w++) { pop += popcnt(bits[no + w]); key += bits[no + w].toString(16).padStart(8, '0'); }
    if (pop < 3) continue;             // con menos de 3 hojas no hay dos topologías
    m.set(key, nd);
  }
  return m;
}

/** ¿Los subárboles x (de a) e y (de b) tienen la misma forma? */
function sameShape(a, x, b, y) {
  if (x < a.n || y < b.n) return x === y;
  return (sameShape(a, a.left[x], b, b.left[y]) && sameShape(a, a.right[x], b, b.right[y])) ||
         (sameShape(a, a.left[x], b, b.right[y]) && sameShape(a, a.right[x], b, b.left[y]));
}

/** Reemplaza el subárbol x de `dst` por la forma del subárbol y de `src`.
    Los dos tienen las mismas hojas, así que sobran exactamente los mismos
    internos: se reutilizan sus ids. */
function graftClade(dst, x, src, y) {
  const pool = [];
  (function walk(nd) { if (nd < dst.n) return; pool.push(nd); walk(dst.left[nd]); walk(dst.right[nd]); })(x);
  let pi = 0;
  function build(nd) {
    if (nd < src.n) return nd;                 // hoja: mismo id en los dos árboles
    const id = pool[pi++];
    const a = build(src.left[nd]), b = build(src.right[nd]);
    dst.left[id] = a; dst.right[id] = b; dst.up[a] = id; dst.up[b] = id;
    return id;
  }
  const up = dst.up[x];
  const nr = build(y);
  dst.up[nr] = up;
  if (up === -1) dst.root = nr;
  else if (dst.left[up] === x) dst.left[up] = nr; else dst.right[up] = nr;
  return nr;
}

/**
 * Una ronda de fusing entre `a` y `b`. Prueba cada clado compartido y se queda
 * con el mejor árbol que encuentre. Devuelve null si ninguno mejora ni empata.
 * cb(arbol, largo) por cada empate en `best`.
 */
function fusePair(a, b, D, best, cb, tol) {
  tol = tol || 1e-9;
  const ma = cladeMap(a, D), mb = cladeMap(b, D);
  let bestT = null, bestL = best + tol;
  let tried = 0;
  ma.forEach(function (x, key) {
    const y = mb.get(key);
    if (y == null) return;
    if (sameShape(a, x, b, y)) return;         // misma forma: no hay nada que pasar
    const t = cloneTree(a);
    graftClade(t, x, b, y);
    const L = scoreFull(t, D, bestL);
    tried++;
    if (L === Infinity) return;
    t.len = L;
    if (L < bestL - tol) { bestL = L; bestT = t; }
    else if (Math.abs(L - best) <= tol && cb) cb(t, L);
  });
  return { tree: bestT, tried: tried };
}

/**
 * Fusing sobre un pool de árboles. `pool` es un arreglo de árboles ya
 * rearreglados. Devuelve { best, trees, fused, tried }.
 * opts = { rounds, stop, onProgress, cb }
 */
async function fuseRounds(pool, D, best, opts) {
  opts = opts || {};
  const rounds = opts.rounds == null ? 3 : opts.rounds;
  const stop = opts.stop || function () { return false; };
  let cur = pool.slice(), fused = 0, tried = 0;
  for (let r = 0; r < rounds && !stop(); r++) {
    let improved = false;
    for (let i = 0; i < cur.length && !stop(); i++) {
      for (let j = 0; j < cur.length && !stop(); j++) {
        if (i === j) continue;
        const out = fusePair(cur[i], cur[j], D, best, opts.cb);
        tried += out.tried;
        if (out.tree) {
          cur[i] = out.tree; best = out.tree.len; fused++; improved = true;
          if (opts.onProgress) opts.onProgress({ phase: 'fuse', round: r + 1, of: rounds, best: best, fused: fused });
        }
        await yieldNow();
      }
    }
    if (!improved) break;
  }
  return { best: best, trees: cur, fused: fused, tried: tried };
}

/* ======================== escalada / ratchet / meseta ======================== */

/** Escalada por primera mejora. Devuelve el óptimo local (árbol nuevo). */
function hillClimb(t, D, mode, rnd, opts) {
  opts = opts || {};
  const maxPass = opts.maxPass || 1000;
  let cur = cloneTree(t);
  prepare(cur, D);
  for (let pass = 0; pass < maxPass; pass++) {
    let found = null;
    const bound = cur.len - 1e-9;
    swapNeighbourhood(cur, D, mode, bound, function (nt, L) {
      if (L < cur.len) { found = nt; return true; }
      return false;
    }, rnd, { randomize: opts.randomize !== false, maxReroot: opts.maxReroot });
    if (!found) break;
    cur = found;
    prepare(cur, D);
  }
  return cur;
}

/** Repesa una fracción de caracteres. Devuelve la función para restaurar. */
function perturbWeights(D, rnd, frac, amount) {
  frac = frac == null ? 0.25 : frac;
  amount = amount == null ? 2 : amount;
  const oF = Float64Array.from(D.wF), oW = Float64Array.from(D.wW);
  for (let i = 0; i < D.nF; i++) if (rnd() < frac) D.wF[i] = oF[i] * amount;
  for (let i = 0; i < D.nW; i++) if (rnd() < frac) D.wW[i] = oW[i] * amount;
  return function () { D.wF.set(oF); D.wW.set(oW); };
}

/**
 * Expansión de la meseta (equivalente a `bbreak` de TNT): recorre el archivo
 * rearreglando cada árbol y guardando TODO empate en `best`, hasta que no
 * aparezcan topologías nuevas o se tope `hold`.
 */
function collectPlateau(archive, D, mode, best, rnd, opts) {
  opts = opts || {};
  const tol = opts.tol || 1e-9;
  let i = 0, better = null;
  while (i < archive.list.length && !archive.full()) {
    const T = archive.list[i].tree;
    prepare(T, D);
    swapNeighbourhood(T, D, mode, best + tol, function (nt, L) {
      if (L < best - tol) { better = nt; return true; }
      if (Math.abs(L - best) <= tol) {
        const k = splitKey(nt, D);
        archive.add(nt, k);
      }
      return archive.full();
    }, rnd, { randomize: opts.randomize !== false, maxReroot: opts.maxReroot });
    if (better) return better;
    i++;
    archive.visited = i;
    if (opts.onStep) opts.onStep(i, archive.size());
  }
  return null;
}

/**
 * Búsqueda completa.
 * opts = {
 *   replicates, mode:'NNI'|'SPR'|'TBR', start:'ras'|'random'|'asis',
 *   ratchetIter, ratchetFrac, ratchetAmount,
 *   hold, seed, collapse, expand, maxReroot, onProgress
 * }
 */
function searchMP(D, opts) {
  opts = opts || {};
  const mode = opts.mode || 'TBR';
  const reps = opts.replicates == null ? 20 : opts.replicates;
  const ratIter = opts.ratchetIter == null ? 10 : opts.ratchetIter;
  const hold = opts.hold || 10000;
  const seed = opts.seed == null ? 1 : opts.seed;
  const rnd = mulberry32(seed);
  const n = D.nTax;
  const archive = new Archive(hold);
  const log = [];
  let best = Infinity;
  const t0 = Date.now();

  function register(t) {
    prepare(t, D);
    if (t.len < best) { best = t.len; archive.map = new Map(); archive.list = []; archive.dups = 0; }
    if (t.len === best) archive.add(cloneTree(t), splitKey(t, D));
  }

  for (let r = 0; r < reps; r++) {
    let t;
    if (opts.start === 'random') t = randomTree(n, rnd);
    else { const ord = []; for (let i = 0; i < n; i++) ord.push(i); shuffleIn(ord, rnd); t = wagnerAdd(D, ord, rnd); }
    const wagLen = (prepare(t, D), t.len);
    t = hillClimb(t, D, mode, rnd, opts);
    for (let it = 0; it < ratIter; it++) {
      const restore = perturbWeights(D, rnd, opts.ratchetFrac, opts.ratchetAmount);
      const tb = hillClimb(t, D, mode, rnd, opts);
      restore();
      const t2 = hillClimb(tb, D, mode, rnd, opts);
      prepare(t2, D); prepare(t, D);
      if (t2.len <= t.len) t = t2;
      if (t.len < best) register(t);
    }
    register(t);
    if (opts.fuse !== false) pool.push(cloneTree(t));
    log.push({ rep: from + r, wagner: wagLen, final: t.len, best: best, archive: archive.size() });
    if (opts.onProgress) opts.onProgress({
      phase: 'replicate', rep: r, of: reps, wagner: wagLen, final: t.len,
      best: best, archive: archive.size(), ms: Date.now() - t0
    });
    if (archive.full()) break;
  }

  // expansión de la meseta
  let expanded = 0;
  if (opts.expand !== false && archive.size()) {
    for (;;) {
      const better = collectPlateau(archive, D, mode, best, rnd, {
        maxReroot: opts.maxReroot,
        onStep: opts.onProgress ? function (i, sz) {
          opts.onProgress({ phase: 'expand', done: i, archive: sz, best: best, ms: Date.now() - t0 });
        } : null
      });
      if (!better) break;
      register(better);
      expanded++;
      if (expanded > 50) break;
    }
  }
  return {
    best: best, trees: archive.list.map(function (r) { return r.tree; }),
    unique: archive.size(), truncated: archive.full(), hold: hold,
    log: log, ms: Date.now() - t0, seed: seed, mode: mode
  };
}

/* ====================== Newick / consenso / colapsado ====================== */

function nwName(s) { return /[\s(),:;'\[\]]/.test(s) ? "'" + String(s).replace(/'/g, "''") + "'" : s; }

/** Árbol binario -> Newick. */
function toNewick(t, taxa) {
  const out = [];
  (function rec(nd) {
    if (nd < t.n) { out.push(nwName(taxa[nd])); return; }
    out.push('(');
    rec(t.left[nd]); out.push(',');
    rec(t.right[nd]);
    out.push(')');
  })(t.root);
  return out.join('') + ';';
}

/** Biparticiones canónicas como arreglo de Uint32Array (lado sin el taxón 0). */
function splitsOf(t, D, filterFn) {
  const n = t.n, W = bitWords(n);
  const cnt = postorder(t, D);
  const bits = new Uint32Array(t.nNode * W);
  for (let i = 0; i < n; i++) bits[i * W + (i >> 5)] |= (1 << (i & 31));
  const lastMask = (n & 31) ? (0xFFFFFFFF >>> (32 - (n & 31))) : 0xFFFFFFFF;
  const rows = [];
  for (let i = 0; i < cnt; i++) {
    const nd = D.post[i], l = t.left[nd], r = t.right[nd];
    const no = nd * W, lo = l * W, ro = r * W;
    for (let w = 0; w < W; w++) bits[no + w] = (bits[lo + w] | bits[ro + w]) >>> 0;
  }
  for (let i = 0; i < cnt; i++) {
    const nd = D.post[i];
    if (nd === t.root || nd === t.right[t.root]) continue;
    const no = nd * W, has0 = (bits[no] & 1) !== 0;
    const row = new Uint32Array(W);
    let pop = 0;
    for (let w = 0; w < W; w++) {
      let x = has0 ? (~bits[no + w]) : bits[no + w];
      if (w === W - 1) x &= lastMask;
      row[w] = x >>> 0; pop += popcnt(row[w]);
    }
    if (pop < 2 || pop > n - 2) continue;
    if (filterFn && !filterFn(nd)) continue;
    rows.push(row);
  }
  return rows;
}
function popOf(row) { let p = 0; for (let i = 0; i < row.length; i++) p += popcnt(row[i]); return p; }
function isSubset(a, b) { for (let i = 0; i < a.length; i++) if ((a[i] & ~b[i]) !== 0) return false; return true; }
function rowHex(row) { let s = ''; for (let i = 0; i < row.length; i++) s += (row[i] >>> 0).toString(16).padStart(8, '0'); return s; }

/**
 * Construye un árbol (posiblemente politómico) desde un conjunto de biparticiones
 * compatibles. Devuelve Newick. `labels` opcional: hex de fila -> etiqueta de nodo.
 */
function newickFromSplits(rows, n, taxa, labels) {
  const W = bitWords(n);
  const sorted = rows.slice().sort(function (a, b) { return popOf(a) - popOf(b); });
  let comps = [];
  for (let i = 0; i < n; i++) {
    const bits = new Uint32Array(W); bits[i >> 5] |= (1 << (i & 31));
    comps.push({ bits: bits, nw: nwName(taxa[i]) });
  }
  for (let s = 0; s < sorted.length; s++) {
    const S = sorted[s];
    const inside = [], rest = [];
    for (let i = 0; i < comps.length; i++) (isSubset(comps[i].bits, S) ? inside : rest).push(comps[i]);
    if (inside.length < 2) continue;
    const bits = new Uint32Array(W);
    for (let i = 0; i < inside.length; i++) for (let w = 0; w < W; w++) bits[w] |= inside[i].bits[w];
    const lab = labels ? (labels[rowHex(S)] || '') : '';
    rest.push({ bits: bits, nw: '(' + inside.map(function (c) { return c.nw; }).join(',') + ')' + lab });
    comps = rest;
  }
  return '(' + comps.map(function (c) { return c.nw; }).join(',') + ');';
}

/** Newick del árbol tras colapsar las ramas sin soporte. */
function collapsedNewick(t, D, best, taxa) {
  const keep = {};
  const rows = splitsOf(t, D, function (nd) { return branchSupported(t, D, nd, best); });
  return newickFromSplits(rows, t.n, taxa, null);
}

/**
 * Consenso. thresh = 1 -> estricto; 0.5 -> mayoría; 0 -> mayoría extendida (greedy).
 * Devuelve { newick, splits:[{freq,size}], n }
 */
function consensus(trees, D, thresh, taxa, opts) {
  opts = opts || {};
  const n = D.nTax;
  const freq = new Map();
  for (let i = 0; i < trees.length; i++) {
    const rows = splitsOf(trees[i], D, null);
    for (let j = 0; j < rows.length; j++) {
      const h = rowHex(rows[j]);
      const e = freq.get(h);
      if (e) e.c++; else freq.set(h, { c: 1, row: rows[j] });
    }
  }
  const all = [];
  freq.forEach(function (v, k) { all.push({ hex: k, row: v.row, freq: v.c / trees.length }); });
  all.sort(function (a, b) { return b.freq - a.freq || popOf(b.row) - popOf(a.row); });

  let keep;
  if (thresh > 0) {
    keep = all.filter(function (x) { return x.freq >= thresh - 1e-9; });
  } else {
    // mayoría extendida: aceptar por frecuencia mientras sea compatible
    keep = [];
    for (let i = 0; i < all.length; i++) {
      let ok = true;
      for (let j = 0; j < keep.length; j++) if (!compatible(all[i].row, keep[j].row, n)) { ok = false; break; }
      if (ok) keep.push(all[i]);
    }
  }
  const labels = {};
  if (opts.labelFreq) keep.forEach(function (x) { labels[x.hex] = String(Math.round(x.freq * 100)); });
  return {
    newick: newickFromSplits(keep.map(function (x) { return x.row; }), n, taxa, opts.labelFreq ? labels : null),
    splits: keep.map(function (x) { return { freq: x.freq, size: popOf(x.row) }; }),
    nodes: keep.length, maxNodes: n - 3, nTrees: trees.length
  };
}
/** Dos biparticiones son compatibles si uno de los cuatro cruces es vacío. */
function compatible(a, b, n) {
  const W = a.length;
  let ab = 0, aNb = 0, nAb = 0, nAnB = 0;
  const lastMask = (n & 31) ? (0xFFFFFFFF >>> (32 - (n & 31))) : 0xFFFFFFFF;
  for (let i = 0; i < W; i++) {
    const m = (i === W - 1) ? lastMask : 0xFFFFFFFF;
    ab |= (a[i] & b[i]) & m;
    aNb |= (a[i] & ~b[i]) & m;
    nAb |= (~a[i] & b[i]) & m;
    nAnB |= (~a[i] & ~b[i]) & m;
  }
  return !ab || !aNb || !nAb || !nAnB;
}

/** Frecuencia de cada bipartición de `t` dentro del conjunto `trees` (soporte). */
function splitSupport(t, D, trees) {
  const freq = new Map();
  for (let i = 0; i < trees.length; i++)
    splitsOf(trees[i], D, null).forEach(function (r) { const h = rowHex(r); freq.set(h, (freq.get(h) || 0) + 1); });
  const out = [];
  splitsOf(t, D, null).forEach(function (r) {
    out.push({ hex: rowHex(r), size: popOf(r), freq: (freq.get(rowHex(r)) || 0) / trees.length });
  });
  return out;
}

/* ===================== versión asíncrona (hilo principal) =====================
   Los Web Workers no existen bajo file://, y la app tiene que funcionar con
   doble clic. Estas variantes ceden el control al navegador entre pasadas, así
   la interfaz responde y el botón de detener sirve, con o sin Worker. */

/* Ceder control sin que la pestaña de fondo lo estrangule.
   setTimeout se limita a ~1/s cuando la pestaña no está visible; MessageChannel
   no. Una corrida de minutos en primer plano tardaría horas si cediera con
   setTimeout y el usuario cambia de ventana. */
let _mc = null;
const _mcQ = [];
function yieldNow() {
  if (typeof MessageChannel === 'function') {
    return new Promise(function (r) {
      if (!_mc) {
        _mc = new MessageChannel();
        _mc.port1.onmessage = function () { const f = _mcQ.shift(); if (f) f(); };
        if (_mc.port1.start) _mc.port1.start();
      }
      _mcQ.push(r);
      _mc.port2.postMessage(0);
    });
  }
  return new Promise(function (r) { setTimeout(r, 0); });
}

/** Escalada asíncrona. opts.stop() -> true corta. */
async function hillClimbA(t, D, mode, rnd, opts) {
  opts = opts || {};
  const maxPass = opts.maxPass || 1000;
  let cur = cloneTree(t);
  prepare(cur, D);
  for (let pass = 0; pass < maxPass; pass++) {
    let found = null;
    swapNeighbourhood(cur, D, mode, cur.len - 1e-9, function (nt, L) {
      if (L < cur.len) { found = nt; return true; }
      return false;
    }, rnd, { randomize: opts.randomize !== false, maxReroot: opts.maxReroot });
    if (!found) break;
    cur = found;
    prepare(cur, D);
    await yieldNow();
    if (opts.onTick) opts.onTick(cur.len, pass);
    if (opts.stop && opts.stop()) break;
  }
  return cur;
}

async function collectPlateauA(archive, D, mode, best, rnd, opts) {
  opts = opts || {};
  const tol = opts.tol || 1e-9;
  let i = 0, better = null;
  /* Cuántos árboles del archivo alcanzamos a rearreglar antes de cortar. Si se
     recorrieron TODOS sin encontrar nada nuevo, la meseta está cerrada bajo
     este operador: es la meseta completa, no una muestra. Si se cortó por el
     tope, la proporción de hallazgos nuevos frente a repetidos dice cuánto
     falta: tasa alta = viste una fracción; tasa baja = estabas cerca. */
  archive.visited = 0;
  while (i < archive.list.length && !archive.full()) {
    const T = archive.list[i].tree;
    prepare(T, D);
    swapNeighbourhood(T, D, mode, best + tol, function (nt, L) {
      if (L < best - tol) { better = nt; return true; }
      if (Math.abs(L - best) <= tol) archive.add(nt, splitKey(nt, D));
      return archive.full();
    }, rnd, { randomize: opts.randomize !== false, maxReroot: opts.maxReroot });
    if (better) return better;
    i++;
    archive.visited = i;
    if (opts.onStep) opts.onStep(i, archive.size());
    await yieldNow();
    if (opts.stop && opts.stop()) return null;
  }
  return null;
}

/** Igual que searchMP pero cede control. opts.stop() -> true corta. */
/* Semilla derivada por réplica.

   Antes todas las réplicas consumían UN mismo flujo mulberry32(seed) en
   secuencia, así que la réplica 7 dependía de cuánto azar habían gastado las
   seis anteriores. Consecuencia: correr 10 réplicas y correr 20 daba
   trayectorias distintas para las mismas primeras 10 — la semilla no
   reproducía nada si cambiabas cualquier otro parámetro.

   Con la semilla derivada cada réplica es independiente y reproducible por sí
   sola. Y como no comparten estado, se pueden repartir entre workers: el
   resultado es el mismo con 1 hilo o con 8. */
function repSeed(seed, r) { return (seed + Math.imul(r + 1, 2654435761)) | 0; }

async function searchMPA(D, opts) {
  opts = opts || {};
  const mode = opts.mode || 'TBR';
  const reps = opts.replicates == null ? 20 : opts.replicates;
  const ratIter = opts.ratchetIter == null ? 10 : opts.ratchetIter;
  const hold = opts.hold || 10000;
  const seed = opts.seed == null ? 1 : opts.seed;
  const from = opts.repFrom || 0;              // para repartir réplicas entre workers
  const rnd = mulberry32(seed);                // sólo para la expansión de la meseta
  const n = D.nTax;
  const archive = new Archive(hold);
  /* Fusing necesita los óptimos locales DISTINTOS, y el archivo sólo guarda los
     que empatan en el mejor largo: tira justo lo que sirve. Por eso el pool se
     lleva aparte, con el resultado de cada réplica gane o no. */
  const pool = [];
  const log = [];
  const stop = opts.stop || function () { return false; };
  let best = Infinity;
  const t0 = Date.now();

  function register(t) {
    prepare(t, D);
    if (t.len < best) { best = t.len; archive.map = new Map(); archive.list = []; archive.dups = 0; }
    if (t.len === best) archive.add(cloneTree(t), splitKey(t, D));
  }

  for (let r = 0; r < reps && !stop(); r++) {
    // aviso al ARRANCAR: si no, el primer dato llegaría recién al terminar la
    // réplica, que con TBR pueden ser decenas de segundos en blanco.
    const say = function (extra) {
      if (!opts.onProgress) return;
      opts.onProgress(Object.assign({
        phase: 'replicate', rep: from + r, of: opts.repTotal || reps, best: best,
        archive: archive.size(), ms: Date.now() - t0
      }, extra || {}));
    };
    say();
    const tick = function (len) { say({ cur: len }); };
    // flujo propio: la réplica r da lo mismo corras 1 o 100, y en cualquier hilo
    const rr = mulberry32(repSeed(seed, from + r));
    let t;
    if (opts.start === 'nj' && r === 0 && from === 0) {
      // NJ es determinista: si todas las réplicas partieran de él, serían la
      // misma. Se usa en la primera y las demás siguen con adición aleatoria.
      t = njTree(D);
    } else if (opts.start === 'random') t = randomTree(n, rr);
    else { const ord = []; for (let i = 0; i < n; i++) ord.push(i); shuffleIn(ord, rr); t = wagnerAdd(D, ord, rr); }
    prepare(t, D);
    const wagLen = t.len;
    say({ cur: wagLen });
    await yieldNow();
    t = await hillClimbA(t, D, mode, rr, { stop: stop, maxReroot: opts.maxReroot, onTick: tick });
    for (let it = 0; it < ratIter && !stop(); it++) {
      const restore = perturbWeights(D, rr, opts.ratchetFrac, opts.ratchetAmount);
      const tb = await hillClimbA(t, D, mode, rr, { stop: stop, maxReroot: opts.maxReroot });
      restore();
      const t2 = await hillClimbA(tb, D, mode, rr, { stop: stop, maxReroot: opts.maxReroot, onTick: tick });
      prepare(t2, D); prepare(t, D);
      if (t2.len <= t.len) t = t2;
      if (t.len < best) register(t);
    }
    register(t);
    if (opts.fuse !== false) pool.push(cloneTree(t));
    log.push({ rep: from + r, wagner: wagLen, final: t.len, best: best, archive: archive.size() });
    say({ wagner: wagLen, final: t.len, finished: true });
    await yieldNow();
    if (archive.full()) break;
  }

  /* Fusing entre los óptimos locales que dejaron las réplicas. Va acá y no
     antes porque necesita árboles YA rearreglados: dos árboles al azar no
     comparten clados de igual composición y no hay nada que intercambiar. */
  let fused = 0;
  if (opts.fuse !== false && pool.length > 1 && !stop()) {
    if (opts.onProgress) opts.onProgress({ phase: 'fuse', best: best, archive: archive.size(), ms: Date.now() - t0 });
    const F = await fuseRounds(pool, D, best, {
      rounds: opts.fuseRounds == null ? 3 : opts.fuseRounds, stop: stop,
      onProgress: opts.onProgress ? function (p) { opts.onProgress(Object.assign({ ms: Date.now() - t0 }, p)); } : null
    });
    fused = F.fused;
    if (F.best < best) {
      // encontró algo mejor que todas las réplicas: el archivo caduca entero
      best = F.best;
      archive.map = new Map(); archive.list = []; archive.dups = 0;
    }
    F.trees.forEach(function (t) {
      prepare(t, D);
      if (t.len === best) archive.add(t, splitKey(t, D));
    });
  }

  if (opts.expand !== false && archive.size() && !stop()) {
    for (let guard = 0; guard < 50; guard++) {
      const better = await collectPlateauA(archive, D, mode, best, rnd, {
        maxReroot: opts.maxReroot, stop: stop,
        onStep: opts.onProgress ? function (i, sz) {
          opts.onProgress({ phase: 'expand', done: i, archive: sz, best: best, ms: Date.now() - t0 });
        } : null
      });
      if (!better) break;
      register(better);
    }
  }
  /* found / (found + dups) al momento de cortar: la tasa a la que seguían
     apareciendo topologías nuevas. Es lo único que dice cuánto falta cuando el
     conjunto quedó truncado. */
  const seenAll = archive.size() + archive.dups;
  return {
    best: best, trees: archive.list.map(function (r) { return r.tree; }),
    unique: archive.size(), truncated: archive.full(), hold: hold,
    saturated: !archive.full() && archive.visited >= archive.list.length,
    visited: archive.visited || 0,
    rate: seenAll ? archive.size() / seenAll : 1,
    log: log, ms: Date.now() - t0, seed: seed, mode: mode, stopped: stop(), fused: fused
  };
}

/** Post-proceso común al Worker y al hilo principal: consensos y soporte.
    No se colapsan ramas: la variación entre topologías es justamente lo que el
    análisis de paisaje topológico necesita ver. */
async function finishSearchA(D, R, taxa, opts) {
  opts = opts || {};
  await yieldNow();
  const out = {
    type: 'done',
    best: R.best, unique: R.unique, truncated: R.truncated, hold: R.hold,
    saturated: !!R.saturated, visited: R.visited || 0, rate: R.rate == null ? 1 : R.rate,
    ms: R.ms, seed: R.seed, mode: R.mode, log: R.log, stopped: !!R.stopped,
    newicks: R.trees.map(function (t) { return toNewick(t, taxa); })
  };
  await yieldNow();
  out.consensus = {
    strict: consensus(R.trees, D, 1, taxa, {}),
    major: consensus(R.trees, D, 0.5, taxa, { labelFreq: true }),
    greedy: consensus(R.trees, D, 0, taxa, {})
  };
  await yieldNow();
  out.support = R.trees.length ? splitSupport(R.trees[0], D, R.trees) : [];
  return out;
}

root.PFSearch = {
  yieldNow: yieldNow, hillClimbA: hillClimbA, collectPlateauA: collectPlateauA,
  searchMPA: searchMPA, finishSearchA: finishSearchA, repSeed: repSeed,
  fusePair: fusePair, fuseRounds: fuseRounds, cladeMap: cladeMap, graftClade: graftClade, sameShape: sameShape,
  toNewick: toNewick, splitsOf: splitsOf, newickFromSplits: newickFromSplits,
  collapsedNewick: collapsedNewick, consensus: consensus, compatible: compatible,
  splitSupport: splitSupport, rowHex: rowHex, popOf: popOf,
  mulberry32: mulberry32, shuffleIn: shuffleIn, packData: packData,
  hillClimb: hillClimb, perturbWeights: perturbWeights,
  collectPlateau: collectPlateau, searchMP: searchMP,
  newTree: newTree, cloneTree: cloneTree, ladderTree: ladderTree, randomTree: randomTree,
  insertAt: insertAt, prune: prune, postorder: postorder, preorderAll: preorderAll,
  subtreeNodes: subtreeNodes, scoreFull: scoreFull, scoreSubtree: scoreSubtree,
  exactInsert: exactInsert, sankRoot: sankRoot, impliedScore: impliedScore,
  fillToRoot: fillToRoot, prepare: prepare, evalInsert: evalInsert, rerootLoose: rerootLoose,
  collapsedKey: collapsedKey, branchSupported: branchSupported, splitKey: splitKey, fnv: fnv, cmpRow: cmpRow, Archive: Archive,
  wagnerAdd: wagnerAdd, swapNeighbourhood: swapNeighbourhood,
  njTree: njTree, distMatrix: distMatrix, pDist: pDist
};

})(typeof window !== 'undefined' ? window : globalThis);
