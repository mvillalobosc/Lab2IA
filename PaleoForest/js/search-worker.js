/* Hilo de búsqueda.

   Dos modos:
     cmd:'run'     una tajada de réplicas (repFrom..repFrom+replicates-1). Es lo
                   que se reparte entre hilos: cada réplica tiene su semilla
                   derivada, así que el resultado no depende de cuántos hilos
                   haya. Con expand:false devuelve la tajada y el orquestador junta.
     cmd:'expand'  siembra el archivo con árboles ya encontrados y expande la
                   meseta. Va en un solo hilo: el archivo es compartido y
                   repartirlo obligaría a sincronizar en cada hallazgo.

   Bajo file:// no hay workers: la app corre el mismo motor en el hilo principal. */
importScripts('search.js');

let stopped = false;
function reply(type, extra) { postMessage(Object.assign({ type: type }, extra || {})); }

/* Newick -> árbol plano. Sólo binarios: los consensos no pasan por acá. */
function toFlat(nw, taxIdx, nTax) {
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
  const t = PFSearch.newTree(nTax);
  const ints = []; for (let k = nTax; k < t.nNode; k++) ints.push(k);
  let bad = false;
  function build(x) {
    if (!x.kids.length) { const ix = taxIdx[x.name]; if (ix == null) { bad = true; return 0; } return ix; }
    const m = ints.pop(), a = build(x.kids[0]), b = build(x.kids[1]);
    t.left[m] = a; t.right[m] = b; t.up[a] = m; t.up[b] = m; return m;
  }
  const rt = build(r);
  if (bad) return null;
  t.root = rt; t.up[rt] = -1; t.free = ints;
  return t;
}

self.onmessage = async function (e) {
  const m = e.data;
  if (m.cmd === 'stop') { stopped = true; return; }
  const stop = function () { return stopped; };
  const onProgress = function (p) { reply('progress', { p: p }); };

  try {
    if (m.cmd === 'run') {
      const D = PFSearch.packData(m.matrix, m.taxa, m.pack);
      reply('packed', { nF: D.nF, nW: D.nW, constant: D.constant });
      const R = await PFSearch.searchMPA(D, Object.assign({}, m.search, {
        onProgress: onProgress, stop: stop
      }));
      if (m.search.expand === false) {
        reply('slice', {
          best: R.best, unique: R.unique, truncated: R.truncated, log: R.log,
          ms: R.ms, stopped: !!R.stopped,
          newicks: R.trees.map(function (t) { return PFSearch.toNewick(t, m.taxa); })
        });
        return;
      }
      const out = await PFSearch.finishSearchA(D, R, m.taxa, { onProgress: onProgress, stop: stop });
      postMessage(out);
      return;
    }

    if (m.cmd === 'expand') {
      const D = PFSearch.packData(m.matrix, m.taxa, m.pack);
      const taxIdx = {}; m.taxa.forEach(function (n, i) { taxIdx[n] = i; });
      const arc = new PFSearch.Archive(m.hold || 10000);
      m.newicks.forEach(function (nw) {
        const t = toFlat(nw, taxIdx, m.taxa.length);
        if (t) arc.add(t, PFSearch.splitKey(t, D));
      });
      const rnd = PFSearch.mulberry32(m.seed || 1);
      let best = m.best;
      for (let g = 0; g < 50 && !stop(); g++) {
        const better = await PFSearch.collectPlateauA(arc, D, m.mode || 'SPR', best, rnd, {
          stop: stop,
          onStep: function (i, sz) { onProgress({ phase: 'expand', done: i, archive: sz, best: best }); }
        });
        if (!better) break;
        // apareció algo mejor que lo que trajeron los hilos: el archivo caduca
        PFSearch.prepare(better, D);
        best = better.len;
        arc.map = new Map(); arc.list = []; arc.dups = 0;
        arc.add(better, PFSearch.splitKey(better, D));
      }
      const seenAll = arc.size() + arc.dups;
      const R = {
        best: best, trees: arc.list.map(function (r) { return r.tree; }),
        unique: arc.size(), truncated: arc.full(), hold: arc.limit,
        saturated: !arc.full() && (arc.visited || 0) >= arc.list.length,
        visited: arc.visited || 0, rate: seenAll ? arc.size() / seenAll : 1,
        log: m.log || [], ms: m.ms || 0, seed: m.seed, mode: m.mode, stopped: stop()
      };
      const out = await PFSearch.finishSearchA(D, R, m.taxa, { onProgress: onProgress, stop: stop });
      postMessage(out);
      return;
    }
  } catch (err) {
    reply('error', { message: String((err && err.message) || err) });
  }
};
