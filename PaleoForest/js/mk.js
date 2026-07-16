/* PaleoForest · js/mk.js
   Verosimilitud Mk (Lewis 2001) sobre un conjunto de árboles YA encontrado.

   Qué es y qué no es
   ------------------
   Esto NO busca árboles. Buscar bajo verosimilitud exige optimizar ~173
   longitudes de rama por cada topología candidata, y eso mata el atajo
   incremental que hace viable el TBR: serían horas por réplica. Puntuar, en
   cambio, es barato. Así que la parsimonia busca —rápido, y devuelve la meseta—
   y esto puntúa esa meseta.

   Sirve para lo que la parsimonia no puede: dentro de un conjunto donde todos
   los árboles empatan en el mismo largo, la verosimilitud sí los ordena.

   El modelo
   ---------
   Mk = Jukes-Cantor generalizado a k estados, tasas simétricas. Su simetría lo
   hace barato: la suma sobre estados colapsa a

       parcial_hijo[s] = (1-β)/k · Σ L_hijo + β · L_hijo[s],     β = e^(-k·t/(k-1))

   o sea O(k) por nodo y carácter, no O(k²).

   Corrección Mkv: las matrices morfológicas sólo codifican caracteres
   variables, así que la verosimilitud se condiciona a que el carácter varíe.
   Sin esa corrección el modelo está sesgado (Lewis 2001).

   Longitudes de rama
   ------------------
   Se optimiza UN parámetro global: todas las ramas comparten largo y se busca
   el que maximiza la verosimilitud. NO es ML con ramas libres. Es más
   restrictivo —equivale a un reloj con ramas iguales— y hay que decirlo: dos
   topologías podrían ordenarse distinto bajo ramas libres. Optimizar 173 ramas
   por árbol es lo correcto y no cabe en una pestaña.
*/
(function (root) {
'use strict';

/** Estados observados de un carácter y vector de cada hoja. */
function packMk(matrix, taxa, opts) {
  opts = opts || {};
  const nTax = taxa.length;
  const nchar = matrix[taxa[0]].length;
  const off = new Set(opts.inactive || []);
  const chars = [];
  for (let c = 0; c < nchar; c++) {
    if (off.has(c)) continue;
    const seen = new Set();
    for (let t = 0; t < nTax; t++) {
      const tok = matrix[taxa[t]][c];
      if (tok === '?' || tok === '-') continue;
      for (const ch of tok) { const d = parseInt(ch, 36); if (!isNaN(d)) seen.add(d); }
    }
    if (seen.size < 2) continue;              // constante: Mkv lo excluye por definición
    const st = [...seen].sort((a, b) => a - b);
    const idx = {}; st.forEach((v, i) => idx[v] = i);
    const k = st.length;
    const tip = new Float64Array(nTax * k);
    for (let t = 0; t < nTax; t++) {
      const tok = matrix[taxa[t]][c];
      const any = (tok === '?' || tok === '-');
      if (any) { for (let i = 0; i < k; i++) tip[t * k + i] = 1; continue; }
      for (const ch of tok) { const d = parseInt(ch, 36); if (idx[d] != null) tip[t * k + idx[d]] = 1; }
      let s = 0; for (let i = 0; i < k; i++) s += tip[t * k + i];
      if (!s) for (let i = 0; i < k; i++) tip[t * k + i] = 1;   // ilegible: tratar como faltante
    }
    chars.push({ c: c, k: k, tip: tip });
  }
  return { nTax: nTax, chars: chars, taxa: taxa.slice() };
}

/** lnL de un carácter con longitud de rama global t. Poda de Felsenstein. */
function charLnL(tree, M, ch, t, scratch) {
  const k = ch.k, n = M.nTax;
  const b = Math.exp(-k * t / (k - 1));
  const p0 = (1 - b) / k;                       // parte que no depende del estado
  const L = scratch;                            // (2n-1) × k
  let scale = 0;
  const post = [];
  (function walk(nd) { if (nd < n) return; walk(tree.left[nd]); walk(tree.right[nd]); post.push(nd); })(tree.root);
  for (let i = 0; i < n; i++) for (let s = 0; s < k; s++) L[i * k + s] = ch.tip[i * k + s];
  for (let i = 0; i < post.length; i++) {
    const nd = post[i], l = tree.left[nd], r = tree.right[nd];
    let sl = 0, sr = 0;
    for (let s = 0; s < k; s++) { sl += L[l * k + s]; sr += L[r * k + s]; }
    let mx = 0;
    for (let s = 0; s < k; s++) {
      const a = p0 * sl + b * L[l * k + s];
      const c2 = p0 * sr + b * L[r * k + s];
      const v = a * c2;
      L[nd * k + s] = v;
      if (v > mx) mx = v;
    }
    if (mx > 0 && mx < 1e-150) {                 // escalado: si no, se va a cero
      for (let s = 0; s < k; s++) L[nd * k + s] /= mx;
      scale += Math.log(mx);
    }
  }
  let tot = 0;
  for (let s = 0; s < k; s++) tot += L[tree.root * k + s] / k;
  return Math.log(tot) + scale;
}

/** lnL de un patrón constante (todas las hojas en el estado `st`). */
function constLnL(tree, M, ch, t, st, scratch) {
  const k = ch.k, n = M.nTax;
  const b = Math.exp(-k * t / (k - 1));
  const p0 = (1 - b) / k;
  const L = scratch;
  let scale = 0;
  const post = [];
  (function walk(nd) { if (nd < n) return; walk(tree.left[nd]); walk(tree.right[nd]); post.push(nd); })(tree.root);
  for (let i = 0; i < n; i++) for (let s = 0; s < k; s++) L[i * k + s] = (s === st) ? 1 : 0;
  for (let i = 0; i < post.length; i++) {
    const nd = post[i], l = tree.left[nd], r = tree.right[nd];
    let sl = 0, sr = 0;
    for (let s = 0; s < k; s++) { sl += L[l * k + s]; sr += L[r * k + s]; }
    let mx = 0;
    for (let s = 0; s < k; s++) {
      const v = (p0 * sl + b * L[l * k + s]) * (p0 * sr + b * L[r * k + s]);
      L[nd * k + s] = v; if (v > mx) mx = v;
    }
    if (mx > 0 && mx < 1e-150) { for (let s = 0; s < k; s++) L[nd * k + s] /= mx; scale += Math.log(mx); }
  }
  let tot = 0;
  for (let s = 0; s < k; s++) tot += L[tree.root * k + s] / k;
  return Math.log(tot) + scale;
}

/** lnL del árbol con longitud global t. `mkv` aplica la corrección de Lewis. */
function treeLnL(tree, M, t, mkv, scratch) {
  let tot = 0;
  for (let i = 0; i < M.chars.length; i++) {
    const ch = M.chars[i];
    let l = charLnL(tree, M, ch, t, scratch);
    if (mkv) {
      // condicionar a que el carácter varíe: lnL - log(1 - P(constante))
      let pc = 0;
      for (let s = 0; s < ch.k; s++) pc += Math.exp(constLnL(tree, M, ch, t, s, scratch));
      const rest = 1 - pc;
      l -= Math.log(rest > 1e-12 ? rest : 1e-12);
    }
    tot += l;
  }
  return tot;
}

/** Optimiza la longitud global por sección áurea. Devuelve { lnL, t }. */
function optLnL(tree, M, opts) {
  opts = opts || {};
  const mkv = opts.mkv !== false;
  const scratch = new Float64Array((2 * M.nTax) * 8);
  let lo = 1e-4, hi = 5;
  const gr = (Math.sqrt(5) - 1) / 2;
  let a = lo, b = hi;
  let c = b - gr * (b - a), d = a + gr * (b - a);
  let fc = -treeLnL(tree, M, c, mkv, scratch), fd = -treeLnL(tree, M, d, mkv, scratch);
  for (let i = 0; i < (opts.iters || 24); i++) {
    if (fc < fd) { b = d; d = c; fd = fc; c = b - gr * (b - a); fc = -treeLnL(tree, M, c, mkv, scratch); }
    else { a = c; c = d; fc = fd; d = a + gr * (b - a); fd = -treeLnL(tree, M, d, mkv, scratch); }
    if (Math.abs(b - a) < 1e-4) break;
  }
  const t = (a + b) / 2;
  return { lnL: treeLnL(tree, M, t, mkv, scratch), t: t };
}

/** Puntúa un conjunto. Devuelve [{i, lnL, t}] ordenado de mejor a peor. */
async function scoreSet(trees, M, opts) {
  opts = opts || {};
  const out = [];
  for (let i = 0; i < trees.length; i++) {
    const r = optLnL(trees[i], M, opts);
    out.push({ i: i, lnL: r.lnL, t: r.t });
    if (opts.onProgress && (i & 7) === 0) opts.onProgress({ phase: 'mk', done: i, of: trees.length });
    if ((i & 7) === 0 && opts.yield) await opts.yield();
    if (opts.stop && opts.stop()) break;
  }
  out.sort((a, b) => b.lnL - a.lnL);
  return out;
}

root.PFMk = { packMk: packMk, treeLnL: treeLnL, optLnL: optLnL, scoreSet: scoreSet, charLnL: charLnL };

})(typeof window !== 'undefined' ? window : globalThis);
