/* Orquestador de hilos.

   Fase A (paralela): las réplicas se reparten entre workers. Son independientes
   —cada una con su semilla derivada— así que no hay estado compartido y el
   resultado es idéntico con 1 hilo o con 8.

   Fase B (un hilo): la meseta se expande desde los árboles que trajo la fase A.
   Esto NO se reparte: el archivo es compartido y crece, y repartirlo obligaría a
   sincronizar en cada hallazgo para no duplicar trabajo.

   Si no se pueden crear workers (file://), quien llama cae al motor en el hilo
   principal: mismo código, un solo hilo. */
(function (root) {
'use strict';

function canWork() {
  try { const w = new Worker('js/search-worker.js'); w.terminate(); return true; }
  catch (e) { return false; }
}

/* `want` = 0 o null: todos los núcleos. Fijarlo sirve para comparar: la misma
   corrida con 1 y con 4 da el mismo resultado y distinto tiempo. */
function threadsFor(replicates, want) {
  const hw = (typeof navigator !== 'undefined' && navigator.hardwareConcurrency) || 4;
  const cap = (want && want > 0) ? Math.min(want, hw) : hw;
  return Math.max(1, Math.min(cap, replicates));
}
function maxThreads() { return (typeof navigator !== 'undefined' && navigator.hardwareConcurrency) || 4; }

/** Reparte `total` réplicas en `n` tajadas lo más parejas posible. */
function slices(total, n) {
  const out = [];
  let from = 0;
  for (let i = 0; i < n; i++) {
    const k = Math.floor(total / n) + (i < total % n ? 1 : 0);
    if (k > 0) out.push({ from: from, count: k });
    from += k;
  }
  return out;
}

/**
 * opts = { matrix, taxa, pack, search, onProgress, onPhase }
 * Devuelve la misma forma que finishSearchA.
 */
function runPool(opts) {
  const search = opts.search;
  const parts = slices(search.replicates, threadsFor(search.replicates, opts.threads));
  const workers = [];
  let done = 0, failed = null;
  const results = [];
  const t0 = Date.now();
  const seen = {};   // rep -> último aviso, para no pisar el progreso entre hilos

  return new Promise(function (resolve, reject) {
    function killAll() { workers.forEach(function (w) { try { w.terminate(); } catch (e) {} }); }

    parts.forEach(function (sl, i) {
      let w;
      try { w = new Worker('js/search-worker.js'); }
      catch (e) { failed = e; return; }
      workers.push(w);
      w.onerror = function (e) { if (!failed) { failed = e; killAll(); reject(e); } };
      w.onmessage = function (e) {
        const d = e.data;
        if (d.type === 'progress') {
          if (opts.onProgress) {
            const p = d.p;
            if (p.phase === 'replicate') { seen[p.rep] = p; p.threads = parts.length; }
            opts.onProgress(p);
          }
          return;
        }
        if (d.type === 'error') { if (!failed) { failed = new Error(d.message); killAll(); reject(failed); } return; }
        if (d.type === 'slice') {
          results.push(d);
          w.terminate();
          if (++done === parts.length) merge();
        }
      };
      w.postMessage({
        cmd: 'run', matrix: opts.matrix, taxa: opts.taxa, pack: opts.pack,
        search: Object.assign({}, search, {
          replicates: sl.count, repFrom: sl.from, repTotal: search.replicates, expand: false
        })
      });
    });

    if (!workers.length) { reject(new Error('sin workers')); return; }

    function merge() {
      // el mejor global manda: lo que traiga un hilo con un largo peor se tira
      let best = Infinity;
      results.forEach(function (r) { if (r.best < best) best = r.best; });
      let nwk = [];
      results.forEach(function (r) { if (r.best === best) nwk = nwk.concat(r.newicks); });
      // ordenar la bitácora por número de réplica: los hilos terminan desordenados
      let log = [];
      results.forEach(function (r) { log = log.concat(r.log); });
      log.sort(function (a, b) { return a.rep - b.rep; });
      // el «mejor hasta aquí» de la bitácora es por hilo: se recalcula global
      let run = Infinity;
      log.forEach(function (l) { if (l.final < run) run = l.final; l.best = run; });

      if (opts.onPhase) opts.onPhase('expand');
      let ex;
      try { ex = new Worker('js/search-worker.js'); }
      catch (e) { reject(e); return; }
      ex.onerror = function (e) { ex.terminate(); reject(e); };
      ex.onmessage = function (e) {
        const d = e.data;
        if (d.type === 'progress') { if (opts.onProgress) opts.onProgress(d.p); return; }
        if (d.type === 'error') { ex.terminate(); reject(new Error(d.message)); return; }
        if (d.type === 'done') {
          ex.terminate();
          d.threads = parts.length;
          d.ms = Date.now() - t0;
          resolve(d);
        }
      };
      workers.push(ex);
      ex.postMessage({
        cmd: 'expand', matrix: opts.matrix, taxa: opts.taxa, pack: opts.pack,
        newicks: nwk, best: best, hold: search.hold, seed: search.seed,
        mode: search.mode, log: log, ms: Date.now() - t0
      });
    }

    opts.__kill = killAll;
  });
}

root.PFPool = { canWork: canWork, threadsFor: threadsFor, maxThreads: maxThreads, slices: slices, runPool: runPool };

})(typeof window !== 'undefined' ? window : globalThis);
