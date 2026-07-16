/* ======================================================================
 * PaleoForest — Cliente Paleobiology Database (PBDB)
 * Réplica del comportamiento del pipeline original en R:
 *   pbdb_occurrences(base_name=..., show=c("coords","classext"), vocab="pbdb")
 *   pbdb_temp_range(..., rank="species")  ->  FAD / LAD
 *   emparejamiento por stringdist(method="lv") <= 4  |  coincidencia de prefijo
 *   estados: encontrada / AMBIGUO / NO ENCONTRADA
 * Único punto de la app que usa la red, y solo bajo acción explícita del
 * usuario. Sin conexión, el flujo continúa con ingreso manual.
 * ==================================================================== */
(function (global) {
  'use strict';

  const ENDPOINT = 'https://paleobiodb.org/data1.2/occs/taxa.json';
  const CHUNK = 12;          // nombres por consulta (mantiene la URL corta)
  const LV_MAX = 4;          // umbral Levenshtein del R original

  /* ---------- distancia de Levenshtein ---------- */
  function lev(a, b) {
    a = String(a); b = String(b);
    if (a === b) return 0;
    const m = a.length, n = b.length;
    if (!m) return n; if (!n) return m;
    let prev = new Array(n + 1), cur = new Array(n + 1);
    for (let j = 0; j <= n; j++) prev[j] = j;
    for (let i = 1; i <= m; i++) {
      cur[0] = i;
      for (let j = 1; j <= n; j++) {
        const cost = a.charCodeAt(i - 1) === b.charCodeAt(j - 1) ? 0 : 1;
        cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
      }
      const tmp = prev; prev = cur; cur = tmp;
    }
    return prev[n];
  }

  // "Arackar_licanantay" -> "Arackar licanantay"  (formatear_nombre_especies del R)
  function formatName(t) { return String(t).replace(/_/g, ' ').trim(); }
  const norm = s => formatName(s).toLowerCase();

  /* ---------- consulta HTTP ---------- */
  function fetchChunk(names, signal) {
    const url = ENDPOINT + '?base_name=' + encodeURIComponent(names.join(','))
      + '&show=app,classext&vocab=pbdb&limit=all';
    return fetch(url, { signal: signal })
      .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .then(j => (j && j.records) || []);
  }

  /* ---------- rango temporal por registro PBDB ---------- */
  function recRange(r) {
    const fad = num(r.firstapp_max_ma) != null ? num(r.firstapp_max_ma) : num(r.max_ma);
    const lad = num(r.lastapp_min_ma) != null ? num(r.lastapp_min_ma) : num(r.min_ma);
    if (fad == null || lad == null) return null;
    return { fad: fad, lad: lad };
  }
  function num(v) { const x = parseFloat(v); return isFinite(x) ? x : null; }

  /**
   * Consulta PBDB para una lista de taxones y devuelve, por cada uno:
   *   { tip, status:'found'|'ambiguous'|'notfound'|'error', match, fad, lad, hierarchy, family, genus, clazz }
   * onProgress(done, total, currentName)
   */
  function lookup(tips, opts) {
    opts = opts || {};
    const onProgress = opts.onProgress || function () { };
    const signal = opts.signal;
    const queries = tips.map(formatName);
    const out = [];
    let i = 0;

    function step() {
      if (i >= queries.length) return Promise.resolve(out);
      const slice = queries.slice(i, i + CHUNK);
      const tipSlice = tips.slice(i, i + CHUNK);
      onProgress(i, queries.length, slice[0]);
      return fetchChunk(slice, signal)
        .then(records => {
          // índice nombre PBDB -> rango temporal (equivalente a pbdb_temp_range rank="species")
          const rows = records.map(r => ({
            name: r.taxon_name || r.accepted_name || r.nam || '',
            rank: r.taxon_rank || r.rnk || '',
            range: recRange(r),
            family: r.family || '', genus: r.genus || '', clazz: r.class || ''
          })).filter(r => r.name && r.range);

          tipSlice.forEach(tip => {
            const q = norm(tip);
            // mismo criterio que el R: lv<=4 O el nombre consultado es prefijo/substring del PBDB
            const hits = rows.filter(r => {
              const p = norm(r.name);
              return lev(q, p) <= LV_MAX || p.indexOf(q) >= 0 || q.indexOf(p) >= 0;
            });
            // prioriza rango de especie exacto
            const exact = hits.filter(r => norm(r.name) === q);
            const pool = exact.length ? exact : hits;
            if (!pool.length) { out.push({ tip: tip, status: 'notfound' }); return; }
            if (pool.length > 1 && !exact.length) {
              // AMBIGUO en el R; aquí conservamos los candidatos para que el usuario elija
              out.push({
                tip: tip, status: 'ambiguous',
                candidates: pool.slice(0, 8).map(r => ({ name: r.name, fad: r.range.fad, lad: r.range.lad }))
              });
              return;
            }
            const r = pool[0];
            out.push({
              tip: tip, status: 'found', match: r.name,
              fad: r.range.fad, lad: r.range.lad,
              family: r.family, genus: r.genus, clazz: r.clazz,
              hierarchy: global.GEO ? global.GEO.hierarchyAt(r.range.fad) : null,
              hierarchyEnd: global.GEO ? global.GEO.hierarchyAt(r.range.lad) : null
            });
          });
          i += CHUNK;
          onProgress(Math.min(i, queries.length), queries.length, '');
          return step();
        });
    }
    return step();
  }



  /* ---------- clado de referencia ----------
     Saurópodo, terópodo y ornitisquio NO son rangos linneanos: son clados, y
     `classext` sólo devuelve rangos (class, order, family). El linaje completo
     se pide aparte, con rel=all_parents, y se busca en él el primero de la
     lista. Una consulta más por taxón, así que se cachea. */
  const CLADES = [
    { key: 'sauropoda', names: ['Sauropoda'] },
    { key: 'theropoda', names: ['Theropoda'] },
    { key: 'ornithischia', names: ['Ornithischia'] },
    { key: 'crocodylomorpha', names: ['Crocodylomorpha', 'Crocodyliformes'] },
    { key: 'pterosauria', names: ['Pterosauria'] },
    { key: 'mammalia', names: ['Mammalia', 'Mammaliaformes'] },
    { key: 'testudinata', names: ['Testudinata', 'Testudines'] }
  ];
  const cladeCache = {};

  /** Devuelve la clave del clado, o '' si no está en la lista o no se conoce. */
  async function cladeOf(name) {
    const q = String(name || '').replace(/_/g, ' ').trim();
    if (!q) return '';
    if (cladeCache[q] !== undefined) return cladeCache[q];
    try {
      const url = 'https://paleobiodb.org/data1.2/taxa/list.json?base_name=' +
        encodeURIComponent(q) + '&rel=all_parents&vocab=pbdb&limit=all';
      const r = await fetch(url, { headers: { Accept: 'application/json' } });
      if (!r.ok) throw new Error('PBDB ' + r.status);
      const j = await r.json();
      const names = ((j && j.records) || []).map(x => String(x.taxon_name || x.nam || ''));
      let hit = '';
      for (let i = 0; i < CLADES.length && !hit; i++)
        if (CLADES[i].names.some(n => names.indexOf(n) >= 0)) hit = CLADES[i].key;
      cladeCache[q] = hit;
      return hit;
    } catch (e) { cladeCache[q] = ''; return ''; }
  }

  /** Resuelve una lista, en tandas. cb(hechos, total). */
  async function cladesFor(tips, cb) {
    const out = {};
    for (let i = 0; i < tips.length; i++) {
      out[tips[i]] = await cladeOf(tips[i]);
      if (cb && (i & 3) === 0) cb(i + 1, tips.length);
    }
    if (cb) cb(tips.length, tips.length);
    return out;
  }

  global.PBDB = { lookup: lookup, lev: lev, formatName: formatName, ENDPOINT: ENDPOINT,
    cladeOf: cladeOf, cladesFor: cladesFor, CLADES: CLADES };

})(typeof window !== 'undefined' ? window : globalThis);
