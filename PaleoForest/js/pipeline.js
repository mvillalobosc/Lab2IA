// ============================================================================
// Núcleo del pipeline filogenético — port a JS.
//   Pipeline de medoides:  Concha, C. (2023), USACH.
//   Plataforma R/Shiny:    Acosta Méndez, C. A. (2024), USACH.
//   Publicación:           Concha-Toro et al. (2026), Org. Divers. Evol.
//                          doi:10.1007/s13127-026-00702-8
// RF distance, MDS, clustering (PAM/k-means/jerárquico), Dunn/Conn/Silhouette,
// selección por hipervolumen, medoides y soporte nodal.
// ============================================================================

// ---------- Parser Newick ----------
function parseNewick(s) {
  let i = 0;
  s = s.trim();
  function parseNode() {
    const node = { children: [], name: null };
    if (s[i] === '(') {
      i++;
      while (true) {
        node.children.push(parseNode());
        if (s[i] === ',') { i++; continue; }
        if (s[i] === ')') { i++; break; }
      }
    }
    let name = '';
    while (i < s.length && !',());'.includes(s[i]) && s[i] !== ':') name += s[i++];
    if (s[i] === ':') { i++; while (i < s.length && !',()); '.includes(s[i])) i++; }
    node.name = name || null;
    return node;
  }
  const t = parseNode();
  return t;
}

// Hojas de un árbol (en orden)
function leaves(tree) {
  const out = [];
  (function rec(n){ if(!n.children.length) out.push(n.name); else n.children.forEach(rec); })(tree);
  return out;
}

// ---------- Bipartitions (clades) as bitsets over a fixed taxon index ----------
function bipartitions(tree, taxonIndex) {
  const n = Object.keys(taxonIndex).length;
  const words = (n >> 5) + 1;
  const clades = [];
  function rec(node) {
    const bs = new Uint32Array(words);
    if (!node.children.length) {
      const idx = taxonIndex[node.name];
      bs[idx >> 5] |= (1 << (idx & 31));
      return bs;
    }
    for (const c of node.children) {
      const cb = rec(c);
      for (let w = 0; w < words; w++) bs[w] |= cb[w];
    }
    // internal clade (not the full set / root)
    clades.push(bs);
    return bs;
  }
  rec(tree);
  return clades;
}

function keyOf(bs) { return Array.from(bs).join(','); }

// canonical key: use the side not containing taxon 0 so complements match
function canonicalKey(bs, words, n) {
  const inSet0 = (bs[0] & 1) === 1;
  if (inSet0) {
    const comp = new Uint32Array(words);
    for (let w = 0; w < words; w++) comp[w] = ~bs[w] >>> 0;
    // mask trailing bits
    const rem = n & 31;
    if (rem) comp[words - 1] &= (1 << rem) - 1;
    return keyOf(comp);
  }
  return keyOf(bs);
}

// ---------- Robinson–Foulds (normalized, symmetric difference of clades) ----------
function rfMatrix(trees, taxa) {
  const taxonIndex = {}; taxa.forEach((t, i) => taxonIndex[t] = i);
  const n = taxa.length, words = (n >> 5) + 1;
  // precompute clade key-sets per tree (only non-trivial bipartitions)
  const sets = trees.map(tr => {
    const cl = bipartitions(tr, taxonIndex);
    const s = new Set();
    for (const bs of cl) {
      // count bits
      let cnt = 0; for (let w = 0; w < words; w++) { let x = bs[w]; while (x) { x &= x - 1; cnt++; } }
      if (cnt >= 2 && cnt <= n - 2) s.add(canonicalKey(bs, words, n));
    }
    return s;
  });
  const T = trees.length;
  const D = Array.from({ length: T }, () => new Float64Array(T));
  for (let a = 0; a < T; a++) {
    for (let b = a + 1; b < T; b++) {
      const A = sets[a], B = sets[b];
      let shared = 0;
      for (const k of A) if (B.has(k)) shared++;
      const rf = (A.size - shared) + (B.size - shared);
      const denom = A.size + B.size; // normalized RF (Robinson-Foulds / max possible for these)
      const val = denom ? rf / denom : 0;
      D[a][b] = D[b][a] = Math.round(val * 100) / 100;
    }
  }
  return D;
}

// ---------- Classical MDS (PCoA) to 2D ----------
function classicalMDS(D, dim = 2) {
  const n = D.length;
  const B = Array.from({ length: n }, () => new Float64Array(n));
  const sq = D.map(r => r.map(v => v * v));
  const rowMean = sq.map(r => r.reduce((a, b) => a + b, 0) / n);
  const grand = rowMean.reduce((a, b) => a + b, 0) / n;
  for (let i = 0; i < n; i++)
    for (let j = 0; j < n; j++)
      B[i][j] = -0.5 * (sq[i][j] - rowMean[i] - rowMean[j] + grand);
  // power iteration for top `dim` eigenvectors
  const vecs = [], vals = [];
  let Bc = B.map(r => Float64Array.from(r));
  for (let d = 0; d < dim; d++) {
    let v = new Float64Array(n).map(() => Math.random());
    let lambda = 0;
    for (let it = 0; it < 300; it++) {
      const w = new Float64Array(n);
      for (let i = 0; i < n; i++) { let s = 0; for (let j = 0; j < n; j++) s += Bc[i][j] * v[j]; w[i] = s; }
      let norm = Math.hypot(...w) || 1;
      for (let i = 0; i < n; i++) w[i] /= norm;
      lambda = norm;
      let diff = 0; for (let i = 0; i < n; i++) diff += Math.abs(w[i] - v[i]);
      v = w; if (diff < 1e-9) break;
    }
    vecs.push(v); vals.push(lambda);
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) Bc[i][j] -= lambda * v[i] * v[j];
  }
  const coords = [];
  for (let i = 0; i < n; i++) {
    const row = [];
    for (let d = 0; d < dim; d++) row.push(vecs[d][i] * Math.sqrt(Math.max(vals[d], 0)));
    coords.push(row);
  }
  return coords;
}

// ---------- k-medoids (PAM, build + swap) on precomputed distances ----------
function pam(D, k, seedList) {
  const n = D.length;
  let medoids = seedList ? seedList.slice() : [];
  if (!medoids.length) {
    // BUILD phase
    const totals = D.map(r => r.reduce((a, b) => a + b, 0));
    medoids.push(totals.indexOf(Math.min(...totals)));
    while (medoids.length < k) {
      let best = -1, bestGain = -Infinity;
      for (let c = 0; c < n; c++) {
        if (medoids.includes(c)) continue;
        let gain = 0;
        for (let j = 0; j < n; j++) {
          const dNear = Math.min(...medoids.map(m => D[j][m]));
          gain += Math.max(0, dNear - D[j][c]);
        }
        if (gain > bestGain) { bestGain = gain; best = c; }
      }
      medoids.push(best);
    }
  }
  function assign() {
    const a = new Int32Array(n);
    for (let j = 0; j < n; j++) {
      let bm = 0, bd = Infinity;
      medoids.forEach((m, mi) => { if (D[j][m] < bd) { bd = D[j][m]; bm = mi; } });
      a[j] = bm;
    }
    return a;
  }
  let a = assign();
  let improved = true, guard = 0;
  while (improved && guard++ < 100) {
    improved = false;
    for (let mi = 0; mi < k; mi++) {
      const cluster = []; for (let j = 0; j < n; j++) if (a[j] === mi) cluster.push(j);
      let bestCost = cluster.reduce((s, j) => s + D[j][medoids[mi]], 0), bestCand = medoids[mi];
      for (const cand of cluster) {
        const cost = cluster.reduce((s, j) => s + D[j][cand], 0);
        if (cost < bestCost) { bestCost = cost; bestCand = cand; }
      }
      if (bestCand !== medoids[mi]) { medoids[mi] = bestCand; improved = true; a = assign(); }
    }
  }
  return { clustering: Array.from(a).map(x => x + 1), medoids };
}

// ---------- k-means on MDS coordinates ----------
function kmeans(coords, k, iters = 50) {
  const n = coords.length, d = coords[0].length;
  let seeds = []; let step = Math.floor(n / k);
  for (let i = 0; i < k; i++) seeds.push(coords[(i * step) % n].slice());
  let assign = new Int32Array(n);
  for (let it = 0; it < iters; it++) {
    for (let j = 0; j < n; j++) {
      let bd = Infinity, bi = 0;
      for (let c = 0; c < k; c++) {
        let s = 0; for (let x = 0; x < d; x++) s += (coords[j][x] - seeds[c][x]) ** 2;
        if (s < bd) { bd = s; bi = c; }
      }
      assign[j] = bi;
    }
    const sums = Array.from({ length: k }, () => new Float64Array(d)), cnt = new Int32Array(k);
    for (let j = 0; j < n; j++) { cnt[assign[j]]++; for (let x = 0; x < d; x++) sums[assign[j]][x] += coords[j][x]; }
    for (let c = 0; c < k; c++) if (cnt[c]) for (let x = 0; x < d; x++) seeds[c][x] = sums[c][x] / cnt[c];
  }
  return Array.from(assign).map(x => x + 1);
}

// ---------- hierarchical (average linkage) on distances ----------

// ---------- Cluster validity indices ----------
function silhouette(D, labels) {
  const n = D.length, groups = {};
  labels.forEach((l, i) => (groups[l] = groups[l] || []).push(i));
  let sum = 0;
  for (let i = 0; i < n; i++) {
    const own = groups[labels[i]];
    if (own.length <= 1) { continue; }
    const a = own.reduce((s, j) => s + (j === i ? 0 : D[i][j]), 0) / (own.length - 1);
    let b = Infinity;
    for (const l in groups) { if (+l === labels[i]) continue;
      const g = groups[l]; const avg = g.reduce((s, j) => s + D[i][j], 0) / g.length;
      if (avg < b) b = avg;
    }
    sum += (b - a) / Math.max(a, b);
  }
  return sum / n;
}
function dunn(D, labels) {
  const groups = {};
  labels.forEach((l, i) => (groups[l] = groups[l] || []).push(i));
  const ids = Object.keys(groups);
  let minInter = Infinity, maxIntra = 0;
  for (const g of ids) {
    const pts = groups[g];
    for (let a = 0; a < pts.length; a++) for (let b = a + 1; b < pts.length; b++)
      if (D[pts[a]][pts[b]] > maxIntra) maxIntra = D[pts[a]][pts[b]];
  }
  for (let x = 0; x < ids.length; x++) for (let y = x + 1; y < ids.length; y++) {
    const A = groups[ids[x]], B = groups[ids[y]];
    for (const a of A) for (const b of B) if (D[a][b] < minInter) minInter = D[a][b];
  }
  return maxIntra === 0 ? 0 : minInter / maxIntra;
}
function connectivity(D, labels, L = 10) {
  const n = D.length;
  const nn = [];
  for (let i = 0; i < n; i++) {
    const order = [...Array(n).keys()].filter(j => j !== i).sort((p, q) => D[i][p] - D[i][q]);
    nn.push(order.slice(0, L));
  }
  let conn = 0;
  for (let i = 0; i < n; i++) for (let r = 0; r < L; r++) {
    const j = nn[i][r];
    if (labels[i] !== labels[j]) conn += 1 / (r + 1);
  }
  return conn;
}

// ---------- Hipervolumen (réplica de la función R) ----------
// objetivos: minimizar k, -Dunn, Connectivity, -Silhouette ; normalizar [0,1]; ref=2
function hypervolume(rows) {
  const obj = rows.map(r => [Number(r.k), -Number(r.Dunn), Number(r.Connectivity), -Number(r.Silhouette)]);
  for (let c = 0; c < 4; c++) {
    let mn = Infinity, mx = -Infinity;
    obj.forEach(o => { if (o[c] < mn) mn = o[c]; if (o[c] > mx) mx = o[c]; });
    obj.forEach(o => { o[c] = (mx === mn) ? 0 : Math.round(((o[c] - mn) / (mx - mn)) * 1e4) / 1e4; });
  }
  return obj.map(o => o.reduce((p, v) => p * (2 - v), 1));
}

// ---------- medoids ----------
function generalMedoid(D) {
  const means = D.map(r => r.reduce((a, b) => a + b, 0) / r.length);
  return means.indexOf(Math.min(...means));
}
function clusterMedoids(D, labels) {
  const groups = {};
  labels.forEach((l, i) => (groups[l] = groups[l] || []).push(i));
  const out = {};
  for (const l in groups) {
    const pts = groups[l];
    let bm = pts[0], bd = Infinity;
    for (const p of pts) { const m = pts.reduce((s, q) => s + D[p][q], 0) / pts.length; if (m < bd) { bd = m; bm = p; } }
    out[l] = bm;
  }
  return out;
}

// ---------- node support (recurrence of each clade across all trees) ----------
function nodeSupport(medoidTree, trees, taxa) {
  const taxonIndex = {}; taxa.forEach((t, i) => taxonIndex[t] = i);
  const n = taxa.length, words = (n >> 5) + 1;
  const counts = new Map();
  for (const tr of trees) {
    const cl = bipartitions(tr, taxonIndex);
    const seen = new Set();
    for (const bs of cl) { const k = canonicalKey(bs, words, n); seen.add(k); }
    for (const k of seen) counts.set(k, (counts.get(k) || 0) + 1);
  }
  // annotate medoid tree internal nodes
  (function rec(node) {
    if (!node.children.length) { node._bs = null; return; }
    node.children.forEach(rec);
    const bs = new Uint32Array(words);
    (function collect(nn){ if(!nn.children.length){ const idx=taxonIndex[nn.name]; bs[idx>>5]|=(1<<(idx&31)); } else nn.children.forEach(collect); })(node);
    const k = canonicalKey(bs, words, n);
    node.support = (counts.get(k) || 0) / trees.length;
  })(medoidTree);
  return medoidTree;
}


/* =====================================================================
 * Fidelidad a la plataforma original en R (Acosta Méndez, 2024).
 *
 * Detalle que cambia los resultados: en el R la matriz RF se pasa a
 * kmeans/pam/fanny/clara SIN diss=TRUE, es decir NO como disimilitud.
 * Cada árbol se trata como un vector de sus distancias RF al resto y el
 * agrupamiento ocurre en espacio EUCLÍDEO sobre esas filas. En cambio,
 * los índices (Dunn, Connectivity, Silhouette) sí se calculan con la
 * matriz RF como disimilitud. Se replica esa asimetría.
 *
 *   distancia_arboles <- RF.dist(arboles, normalize=TRUE)
 *   distancia_arboles <- round(distancia_arboles, 2)   <- se replica
 *   distancia_arboles <- as.matrix(distancia_arboles)
 * =================================================================== */

// redondeo a 2 decimales, como round(RF.dist(...), 2) en el R
function roundMatrix2(D) {
  return D.map(r => r.map(v => Math.round(v * 100) / 100));
}

// distancias euclídeas entre las FILAS de la matriz RF (el espacio en que agrupa el R)
function euclideanFromRows(X) {
  const n = X.length, E = Array.from({ length: n }, () => new Float64Array(n));
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      let s = 0;
      for (let d = 0; d < X[i].length; d++) { const t = X[i][d] - X[j][d]; s += t * t; }
      const v = Math.sqrt(s); E[i][j] = v; E[j][i] = v;
    }
  }
  return E;
}

/* ---- PRNG determinista: reemplaza a set.seed(2) del R ---- */
function rng(seed) {
  let s = seed >>> 0;
  return function () { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

/* ---- FANNY (fuzzy analysis clustering), memb.exp = 1.1 ----
   Minimiza  sum_v [ sum_ij u_iv^m u_jv^m d_ij / (2 sum_j u_jv^m) ]
   (Kaufman & Rousseeuw). Asignación dura = máxima pertenencia. */
function fanny(E, k, membExp, iters) {
  membExp = membExp || 1.1; iters = iters || 300;
  const n = E.length, m = membExp;
  // Inicialización desde PAM: fanny con memb.exp bajo (1.1) es casi dura y
  // desde membresías uniformes se queda en un punto silla (todo un clúster).
  const p0 = pam(E, k);
  let U = Array.from({ length: n }, (_, i) => {
    const r = new Float64Array(k).fill(0.1 / (k - 1 || 1));
    r[p0.clustering[i] - 1] = 0.9;
    return Array.from(r);
  });
  const pw = (x) => Math.pow(x, m);

  for (let it = 0; it < iters; it++) {
    const K = Array.from({ length: n }, () => new Float64Array(k));
    for (let v = 0; v < k; v++) {
      // b_v = sum_j u_jv^m
      let b = 0;
      for (let j = 0; j < n; j++) b += pw(U[j][v]);
      b = Math.max(b, 1e-12);
      // a_iv = sum_j u_jv^m d_ij      y      N_v = sum_i u_iv^m a_iv
      const a = new Float64Array(n);
      let N = 0;
      for (let i = 0; i < n; i++) {
        let s = 0;
        const Ei = E[i];
        for (let j = 0; j < n; j++) if (j !== i) s += pw(U[j][v]) * Ei[j];
        a[i] = s; N += pw(U[i][v]) * s;
      }
      const Cv = N / (2 * b);   // coste del clúster v
      // ∂C/∂u_iv = 0 con la restricción sum_v u_iv = 1  ->  u_iv ∝ (1/K_iv)^(1/(m-1))
      for (let i = 0; i < n; i++) K[i][v] = Math.max(1e-12, (a[i] - Cv) / b);
    }
    let delta = 0;
    const Un = Array.from({ length: n }, () => new Float64Array(k));
    for (let i = 0; i < n; i++) {
      // en log para sobrevivir al exponente 1/(m-1) = 10 con m = 1.1
      const lg = new Float64Array(k);
      let mx = -Infinity;
      for (let v = 0; v < k; v++) { lg[v] = -Math.log(K[i][v]) / (m - 1); if (lg[v] > mx) mx = lg[v]; }
      let s = 0;
      for (let v = 0; v < k; v++) { lg[v] = Math.exp(lg[v] - mx); s += lg[v]; }
      for (let v = 0; v < k; v++) {
        const nv = lg[v] / (s || 1e-12);
        delta = Math.max(delta, Math.abs(nv - U[i][v]));
        Un[i][v] = nv;
      }
    }
    U = Array.from({ length: n }, (_, i) => Array.from(Un[i]));
    if (delta < 1e-7) break;
  }
  const labels = U.map(u => { let b = 0; for (let v = 1; v < u.length; v++) if (u[v] > u[b]) b = v; return b + 1; });
  return { clustering: relabel(labels), membership: U };
}

/* ---- CLARA: PAM sobre muestras (R: samples=5, sampsize=40+2k) ---- */
function clara(X, k, E) {
  const n = X.length, rnd = rng(2 + k);
  const sampsize = Math.min(n, 40 + 2 * k), samples = 5;
  let best = null, bestCost = Infinity;
  for (let s = 0; s < samples; s++) {
    // muestra aleatoria sin reemplazo
    const idx = [];
    const pool = Array.from({ length: n }, (_, i) => i);
    for (let i = 0; i < sampsize; i++) { const j = Math.floor(rnd() * pool.length); idx.push(pool.splice(j, 1)[0]); }
    const sub = idx.map(i => idx.map(j => E[i][j]));
    const r = pam(sub, k);
    const meds = r.medoids.map(mi => idx[mi]);
    // asigna TODOS los puntos al medoide más cercano y evalúa el coste global
    let cost = 0;
    const labels = new Array(n);
    for (let i = 0; i < n; i++) {
      let b = 0, bd = E[i][meds[0]];
      for (let v = 1; v < meds.length; v++) if (E[i][meds[v]] < bd) { bd = E[i][meds[v]]; b = v; }
      labels[i] = b + 1; cost += bd;
    }
    if (cost < bestCost) { bestCost = cost; best = { clustering: relabel(labels), medoids: meds }; }
  }
  return best;
}

/* ---- DBSCAN. Réplica del R: minPts=5, k=4, eps = codo de la curva kNN ---- */
function knnDist(E, k) {
  return E.map(row => {
    const d = Array.from(row).slice().sort((a, b) => a - b);
    return d[k]; // d[0] es la distancia a sí mismo (0)
  });
}
function dbscanEps(E, k) {
  const d = knnDist(E, k).map(v => Math.round(v * 1000) / 1000).sort((a, b) => a - b);
  let pos = 0, mx = -Infinity;
  for (let i = 0; i < d.length - 1; i++) { const diff = d[i + 1] - d[i]; if (diff > mx) { mx = diff; pos = i; } }
  return d[pos];
}
function dbscan(E, eps, minPts) {
  const n = E.length, labels = new Array(n).fill(0); // 0 = ruido (como en R)
  let cid = 0;
  const neigh = i => { const o = []; for (let j = 0; j < n; j++) if (E[i][j] <= eps) o.push(j); return o; };
  const visited = new Array(n).fill(false);
  for (let i = 0; i < n; i++) {
    if (visited[i]) continue;
    visited[i] = true;
    let N = neigh(i);
    if (N.length < minPts) continue;         // ruido, por ahora
    cid++; labels[i] = cid;
    for (let q = 0; q < N.length; q++) {
      const j = N[q];
      if (!visited[j]) {
        visited[j] = true;
        const N2 = neigh(j);
        if (N2.length >= minPts) N2.forEach(x => { if (N.indexOf(x) < 0) N.push(x); });
      }
      if (labels[j] === 0) labels[j] = cid;
    }
  }
  return labels;
}

/* ---- SOM: grilla hexagonal i×i, entrenamiento en línea (R: rlen=1000, alpha .05→.01)
       Los clústeres son las neuronas ganadoras ocupadas (predict()$unit.classif). ---- */
function somClusters(X, side, rlen) {
  rlen = rlen || 1000;
  const n = X.length, dim = X[0].length, nodes = side * side, rnd = rng(2 + side);
  // posiciones hexagonales de la grilla
  const px = [], py = [];
  for (let r = 0; r < side; r++) for (let c = 0; c < side; c++) { px.push(c + (r % 2) * 0.5); py.push(r * Math.sqrt(3) / 2); }
  // pesos iniciales: muestras al azar del conjunto
  const W = Array.from({ length: nodes }, () => Array.from(X[Math.floor(rnd() * n)]));
  const radius0 = Math.max(1, side / 2);
  for (let t = 0; t < rlen; t++) {
    const prog = t / rlen;
    const alpha = 0.05 + (0.01 - 0.05) * prog;
    const radius = radius0 * (1 - prog) + 0.5;
    const i = Math.floor(rnd() * n), x = X[i];
    // neurona ganadora
    let bmu = 0, bd = Infinity;
    for (let u = 0; u < nodes; u++) {
      let s = 0;
      for (let d = 0; d < dim; d++) { const df = x[d] - W[u][d]; s += df * df; }
      if (s < bd) { bd = s; bmu = u; }
    }
    for (let u = 0; u < nodes; u++) {
      const gx = px[u] - px[bmu], gy = py[u] - py[bmu];
      const gd2 = gx * gx + gy * gy;
      if (gd2 > radius * radius) continue;
      const h = alpha * Math.exp(-gd2 / (2 * radius * radius));
      for (let d = 0; d < dim; d++) W[u][d] += h * (x[d] - W[u][d]);
    }
  }
  // asignación final
  const unit = X.map(x => {
    let bmu = 0, bd = Infinity;
    for (let u = 0; u < nodes; u++) {
      let s = 0;
      for (let d = 0; d < dim; d++) { const df = x[d] - W[u][d]; s += df * df; }
      if (s < bd) { bd = s; bmu = u; }
    }
    return bmu;
  });
  return relabel(unit.map(u => u + 1));
}

/* ---- MST-kNN: intersección de grafo kNN y árbol de expansión mínima,
       aplicada de forma recursiva sobre cada componente (Inostroza-Ponta). ---- */
function mstknn(E) {
  const n = E.length;
  const labels = new Array(n).fill(0);
  let next = 1;
  const work = [Array.from({ length: n }, (_, i) => i)];
  while (work.length) {
    const S_ = work.pop();
    const m = S_.length;
    if (m <= 2) { S_.forEach(i => labels[i] = next); next++; continue; }
    // MST (Prim) sobre el subconjunto
    const inT = new Array(m).fill(false), best = new Float64Array(m).fill(Infinity), par = new Int32Array(m).fill(-1);
    best[0] = 0;
    const edges = [];
    for (let it = 0; it < m; it++) {
      let u = -1, bd = Infinity;
      for (let i = 0; i < m; i++) if (!inT[i] && best[i] < bd) { bd = best[i]; u = i; }
      inT[u] = true;
      if (par[u] >= 0) edges.push([u, par[u], E[S_[u]][S_[par[u]]]]);
      for (let v = 0; v < m; v++) if (!inT[v] && E[S_[u]][S_[v]] < best[v]) { best[v] = E[S_[u]][S_[v]]; par[v] = u; }
    }
    // k = min(floor(ln(m)), grado máx del MST)
    const deg = new Int32Array(m);
    edges.forEach(([a, b]) => { deg[a]++; deg[b]++; });
    const kk = Math.max(1, Math.min(Math.floor(Math.log(m)), Math.max(...deg)));
    // grafo kNN
    const knnSet = new Set();
    for (let i = 0; i < m; i++) {
      const order = Array.from({ length: m }, (_, j) => j).filter(j => j !== i)
        .sort((a, b) => E[S_[i]][S_[a]] - E[S_[i]][S_[b]]).slice(0, kk);
      order.forEach(j => knnSet.add(Math.min(i, j) + ':' + Math.max(i, j)));
    }
    // intersección MST ∩ kNN
    const keep = edges.filter(([a, b]) => knnSet.has(Math.min(a, b) + ':' + Math.max(a, b)));
    // componentes conexas del grafo resultante
    const adj = Array.from({ length: m }, () => []);
    keep.forEach(([a, b]) => { adj[a].push(b); adj[b].push(a); });
    const seen = new Array(m).fill(false);
    const comps = [];
    for (let i = 0; i < m; i++) {
      if (seen[i]) continue;
      const q = [i]; seen[i] = true; const c = [];
      while (q.length) { const u = q.pop(); c.push(u); adj[u].forEach(v => { if (!seen[v]) { seen[v] = true; q.push(v); } }); }
      comps.push(c);
    }
    if (comps.length === 1) { S_.forEach(i => labels[i] = next); next++; }
    else comps.forEach(c => work.push(c.map(i => S_[i])));
  }
  return relabel(labels);
}

// reetiqueta a 1..k consecutivos preservando el orden de aparición
function relabel(labels) {
  const map = new Map(); let next = 1;
  return labels.map(l => { if (!map.has(l)) map.set(l, next++); return map.get(l); });
}

/* ---- PCA sobre las filas de la matriz RF (lo que hace fviz_cluster del R) ----
   fviz_cluster(obj, data = distancia_arboles) aplica prcomp() a `data` y
   grafica Dim1/Dim2 con su % de varianza. No es lo mismo que MDS clásico. */
function pcaRows(X, dim) {
  dim = dim || 2;
  const n = X.length, p = X[0].length;
  const mean = new Float64Array(p);
  for (let j = 0; j < p; j++) { let s = 0; for (let i = 0; i < n; i++) s += X[i][j]; mean[j] = s / n; }
  const C = X.map(r => Float64Array.from(r, (v, j) => v - mean[j]));
  // potencias iteradas con deflación sobre la matriz de covarianza (n×p, p puede ser grande)
  const comps = [], vars = [];
  const Cw = C.map(r => Float64Array.from(r));
  let totVar = 0;
  for (let i = 0; i < n; i++) for (let j = 0; j < p; j++) totVar += C[i][j] * C[i][j];
  totVar /= (n - 1);
  for (let d = 0; d < dim; d++) {
    let v = new Float64Array(p);
    const rnd = rng(7 + d);
    for (let j = 0; j < p; j++) v[j] = rnd() - 0.5;
    let norm = Math.hypot(...v); for (let j = 0; j < p; j++) v[j] /= norm;
    let lambda = 0;
    for (let it = 0; it < 300; it++) {
      // w = C^T (C v) / (n-1)
      const Cv = new Float64Array(n);
      for (let i = 0; i < n; i++) { let s = 0; for (let j = 0; j < p; j++) s += Cw[i][j] * v[j]; Cv[i] = s; }
      const w = new Float64Array(p);
      for (let j = 0; j < p; j++) { let s = 0; for (let i = 0; i < n; i++) s += Cw[i][j] * Cv[i]; w[j] = s / (n - 1); }
      norm = Math.sqrt(w.reduce((a, b) => a + b * b, 0)) || 1e-12;
      let diff = 0;
      for (let j = 0; j < p; j++) { const nv = w[j] / norm; diff = Math.max(diff, Math.abs(nv - v[j])); v[j] = nv; }
      lambda = norm;
      if (diff < 1e-9) break;
    }
    comps.push(v); vars.push(lambda);
    // deflación
    for (let i = 0; i < n; i++) {
      let s = 0; for (let j = 0; j < p; j++) s += Cw[i][j] * v[j];
      for (let j = 0; j < p; j++) Cw[i][j] -= s * v[j];
    }
  }
  const scores = C.map(r => comps.map(v => { let s = 0; for (let j = 0; j < p; j++) s += r[j] * v[j]; return s; }));
  const pct = vars.map(v => totVar > 0 ? (v / totVar) * 100 : 0);
  return { scores, pct };
}

/* =====================================================================
 * Parsimonia (Fitch, caracteres no aditivos)
 *
 * Ni el pipeline en R ni la memoria calculan el puntaje de parsimonia: lo
 * produce TNT antes, fuera de la herramienta. Aquí sí se calcula, a partir
 * de la matriz de caracteres, para poder (a) mostrarlo por árbol y (b)
 * detectar topologías que NO son más parsimoniosas coladas en el conjunto.
 *
 * Advertencia: TNT puede tratar caracteres como aditivos (ordenados) vía
 * `ccode`, y este cálculo los asume todos no aditivos. Si la matriz original
 * declaraba caracteres ordenados, el número no coincidirá con el de TNT.
 * =================================================================== */

// tokeniza una fila de estados TNT: "01?[01]-2" -> ['0','1','?','01','-','2']
function tntTokens(s) {
  const out = [];
  for (let i = 0; i < s.length;) {
    if (s[i] === '[') { const j = s.indexOf(']', i); out.push(s.slice(i + 1, j)); i = j + 1; }
    else { out.push(s[i]); i++; }
  }
  return out;
}

// máscara de estados; '?' y '-' se tratan como faltantes (cualquier estado)
const PARS_ALL = 0xFFFF;
const GAP_STATE = 15;   // estado reservado si '-' se trata como estado propio
function stateMask(tok, gapAsState) {
  if (tok === '?') return PARS_ALL;
  if (tok === '-') return gapAsState ? (1 << GAP_STATE) : PARS_ALL;
  let m = 0;
  for (const c of tok) { const d = parseInt(c, 36); if (!isNaN(d)) m |= 1 << d; }
  return m || PARS_ALL;
}

/* --- Wagner (Farris): caracteres aditivos/ordenados ---
   El estado de cada nodo es un intervalo [min,max]; cuando los intervalos de
   dos hijos son disjuntos, el coste es la distancia entre ellos. Fitch cobra
   1 paso pase lo que pase; Wagner cobra la distancia real entre estados. */
function stateRange(tok, nst, gapAsState) {
  if (tok === '?') return [0, nst - 1];
  if (tok === '-') return gapAsState ? [nst, nst] : [0, nst - 1];
  const v = [];
  for (const c of tok) { const d = parseInt(c, 36); if (!isNaN(d)) v.push(d); }
  if (!v.length) return [0, nst - 1];
  return [Math.min.apply(null, v), Math.max.apply(null, v)];
}

/**
 * Puntaje de parsimonia de un árbol.
 * matrix : { taxon -> array de tokens }
 * ordered: array de índices (0-based) de caracteres aditivos; el resto va Fitch
 * nst    : número de estados (para tratar '?' y '-')
 */
/**
 * opts = { ordered:[idx], inactive:Set|[idx], weights:{idx:w}, nst, gapAsState }
 * Replica lo que declara `ccode` en TNT: aditividad (+/-), activación ([/])
 * y peso (/N). Un carácter inactivo no aporta pasos; el peso multiplica.
 */
function parsimonyScoreEx(tree, matrix, opts) {
  opts = opts || {};
  const names = Object.keys(matrix);
  if (!names.length) return null;
  const nchar = matrix[names[0]].length;
  const ord = new Set(opts.ordered || []);
  const off = new Set(opts.inactive || []);
  const wts = opts.weights || {};
  const nst = opts.nst || 8, gap = !!opts.gapAsState;
  let total = 0;
  for (let c = 0; c < nchar; c++) {
    if (off.has(c)) continue;
    const steps = charSteps(tree, matrix, c, ord.has(c), nst, gap);
    const w = wts[c] == null ? 1 : wts[c];
    total += steps * w;
  }
  return total;
}

// pasos de un solo carácter
function charSteps(tree, matrix, c, isOrdered, nst, gapAsState) {
  let steps = 0;
  if (isOrdered) {
    (function down(nd) {
      if (!nd.children || !nd.children.length) {
        const row = matrix[nd.name];
        return row ? stateRange(row[c], nst, gapAsState) : [0, nst - 1];
      }
      let cur = null;
      for (const kid of nd.children) {
        const a = down(kid);
        if (cur === null) cur = a;
        else {
          const lo = Math.max(cur[0], a[0]), hi = Math.min(cur[1], a[1]);
          if (lo <= hi) cur = [lo, hi];
          else if (cur[1] < a[0]) { steps += a[0] - cur[1]; cur = [cur[1], a[0]]; }
          else { steps += cur[0] - a[1]; cur = [a[1], cur[0]]; }
        }
      }
      return cur;
    })(tree);
  } else {
    (function down(nd) {
      if (!nd.children || !nd.children.length) {
        const row = matrix[nd.name];
        return row ? stateMask(row[c], gapAsState) : PARS_ALL;
      }
      let s = null;
      for (const kid of nd.children) {
        const b = down(kid);
        if (s === null) s = b;
        else { const inter = s & b; if (inter) s = inter; else { s = s | b; steps++; } }
      }
      return s;
    })(tree);
  }
  return steps;
}

// estados observados de un carácter (para el editor)
function charStates(matrix, c) {
  const out = new Set(); let miss = 0, gaps = 0, poly = 0;
  Object.keys(matrix).forEach(n => {
    const t = matrix[n][c];
    if (t === '?') { miss++; return; }
    if (t === '-') { gaps++; return; }
    if (t.length > 1) poly++;
    for (const ch of t) out.add(ch);
  });
  return { states: [...out].sort(), missing: miss, gaps: gaps, poly: poly };
}

function parsimonyScore(tree, matrix, ordered, nst, gapAsState) {
  const names = Object.keys(matrix);
  if (!names.length) return null;
  const nchar = matrix[names[0]].length;
  const ord = new Set(ordered || []);
  nst = nst || 8;
  let total = 0;
  for (let c = 0; c < nchar; c++) {
    let steps = 0;
    if (ord.has(c)) {
      (function down(nd) {
        if (!nd.children || !nd.children.length) {
          const row = matrix[nd.name];
          return row ? stateRange(row[c], nst, gapAsState) : [0, nst - 1];
        }
        let cur = null;
        for (const kid of nd.children) {
          const a = down(kid);
          if (cur === null) cur = a;
          else {
            const lo = Math.max(cur[0], a[0]), hi = Math.min(cur[1], a[1]);
            if (lo <= hi) cur = [lo, hi];
            else if (cur[1] < a[0]) { steps += a[0] - cur[1]; cur = [cur[1], a[0]]; }
            else { steps += cur[0] - a[1]; cur = [a[1], cur[0]]; }
          }
        }
        return cur;
      })(tree);
    } else {
      (function down(nd) {
        if (!nd.children || !nd.children.length) {
          const row = matrix[nd.name];
          return row ? stateMask(row[c], gapAsState) : PARS_ALL;
        }
        let s = null;
        for (const kid of nd.children) {
          const b = down(kid);
          if (s === null) s = b;
          else { const inter = s & b; if (inter) s = inter; else { s = s | b; steps++; } }
        }
        return s;
      })(tree);
    }
    total += steps;
  }
  return total;
}

// compatibilidad: Fitch puro = parsimonyScore sin caracteres ordenados
function fitchScore(tree, matrix) { return parsimonyScore(tree, matrix, [], 8, false); }

/* Lee una lista de caracteres escrita a mano: "14, 61, 276-279, 299".
   Admite rangos con guion o con punto (sintaxis TNT). `base` es 0 o 1. */
function parseCharList(txt, base) {
  const out = [];
  String(txt || '').split(/[\s,;]+/).forEach(tok => {
    if (!tok) return;
    const r = /^(\d+)\s*(?:-|\.\.?)\s*(\d+)$/.exec(tok);
    if (r) { for (let i = +r[1]; i <= +r[2]; i++) out.push(i - base); }
    else if (/^\d+$/.test(tok)) out.push(+tok - base);
  });
  return out.filter(x => x >= 0).sort((a, b) => a - b);
}
function charListToText(arr, base) {
  return (arr || []).map(x => x + base).join(' ');
}

/* Lee el bloque `ccode + ...` de un .tnt y devuelve los índices aditivos.
   TNT numera los caracteres desde 0 y admite rangos con punto: `276.279`. */
function parseCcode(text) {
  const m = /ccode\s+([^;]*);/i.exec(text);
  if (!m) return null;
  const body = m[1];
  const out = [];
  let additive = false;
  body.split(/\s+/).forEach(tok => {
    if (!tok || tok === '*') return;
    if (tok === '+') { additive = true; return; }
    if (tok === '-') { additive = false; return; }
    if (!additive) return;
    const r = /^(\d+)\.(\d+)$/.exec(tok);
    if (r) { for (let i = +r[1]; i <= +r[2]; i++) out.push(i); }
    else if (/^\d+$/.test(tok)) out.push(+tok);
  });
  return out;
}

// grado máximo de un nodo interno: >2 indica politomías (árbol de consenso)
function maxDegree(tree) {
  let mx = 0;
  (function walk(n) {
    if (n.children && n.children.length) { mx = Math.max(mx, n.children.length); n.children.forEach(walk); }
  })(tree);
  return mx;
}

/* =====================================================================
 * Detección de árboles de consenso colados en el conjunto.
 *
 * Los .tre de TNT suelen traer el consenso pegado al final. Ese árbol no es
 * una solución más parsimoniosa: tiene politomías y, por monotonía de Fitch/
 * Wagner, nunca puede costar menos que los árboles resueltos. Si entra al
 * análisis contamina la matriz RF, el agrupamiento y los medoides.
 *
 * No basta con "tiene politomías y puntúa peor": se comprueba de verdad que
 * sus biparticiones sean EXACTAMENTE el consenso estricto de los demás.
 * =================================================================== */

// clave canónica de una bipartición, para poder compararlas entre árboles
function cladeKeys(tree, taxonIndex) {
  const n = Object.keys(taxonIndex).length;
  const out = new Set();
  bipartitions(tree, taxonIndex).forEach(bs => {
    let cnt = 0;
    for (let i = 0; i < n; i++) if (bs[i >> 5] & (1 << (i & 31))) cnt++;
    if (cnt <= 1 || cnt >= n) return;             // trivial
    // se normaliza al lado que NO contiene al taxón 0, para que A|B == B|A
    const flip = !!(bs[0] & 1);
    const bits = [];
    for (let i = 0; i < n; i++) {
      const on = !!(bs[i >> 5] & (1 << (i & 31)));
      if (on !== flip) bits.push(i);
    }
    out.add(bits.join(','));
  });
  return out;
}

/**
 * Devuelve los índices de los árboles que son el consenso estricto del resto.
 * Requiere politomías (un árbol resuelto no puede ser consenso de un conjunto
 * en conflicto) y coincidencia exacta de biparticiones.
 */
function findConsensusTrees(trees, taxa) {
  const n = trees.length;
  if (n < 3) return [];
  const taxonIndex = {};
  taxa.forEach((t, i) => taxonIndex[t] = i);
  const keys = trees.map(t => cladeKeys(t, taxonIndex));
  const polys = [];
  for (let i = 0; i < n; i++) if (maxDegree(trees[i]) > 2) polys.push(i);
  if (!polys.length) return [];
  const found = [];
  polys.forEach(i => {
    // consenso estricto de todos los demás (excluyendo otros candidatos ya hallados)
    let inter = null;
    for (let j = 0; j < n; j++) {
      if (j === i || found.indexOf(j) >= 0 || polys.indexOf(j) >= 0) continue;
      if (inter === null) { inter = new Set(keys[j]); continue; }
      const next = new Set();
      keys[j].forEach(k => { if (inter.has(k)) next.add(k); });
      inter = next;
    }
    if (!inter) return;
    if (inter.size !== keys[i].size) return;
    let same = true;
    keys[i].forEach(k => { if (!inter.has(k)) same = false; });
    if (same) found.push(i);
  });
  return found;
}
