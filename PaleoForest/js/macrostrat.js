/* ======================================================================
 * PaleoForest — Cliente Macrostrat
 *
 * Segunda fuente de edades, y por otra vía que PaleoDB: Macrostrat no busca
 * taxones, busca UNIDADES ESTRATIGRÁFICAS. Sirve cuando sabes la formación
 * pero PaleoDB no tiene el taxón: le pides «Hornitos Formation» y devuelve su
 * rango.
 *
 * Cubre pocos casos, y hay que decirlo: el resto de los faltantes no es
 * problema de base de datos, es que nadie publicó un rango para ese taxón. Ahí
 * la única fuente es el paper original, a mano.
 *
 * La edad que devuelve es la de la FORMACIÓN, no la del taxón: el taxón podría
 * ocupar solo una parte de ella. Por eso la fuente se marca aparte.
 *
 * Como PaleoDB: único punto que usa la red, y sólo bajo acción explícita.
 * ==================================================================== */
(function (global) {
  'use strict';

  const ENDPOINT = 'https://macrostrat.org/api/v2/defs/strat_names';
  const UNITS = 'https://macrostrat.org/api/v2/units';

  /** Busca una unidad por nombre. Devuelve [{name, rank, b_age, t_age, ref}]. */
  async function findUnit(name) {
    const q = String(name || '').trim();
    if (!q) return [];
    const url = UNITS + '?strat_name=' + encodeURIComponent(q) + '&response=long&format=json';
    const r = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!r.ok) throw new Error('Macrostrat ' + r.status);
    const j = await r.json();
    const rows = (j && j.success && j.success.data) || [];
    const out = [];
    const seen = new Set();
    rows.forEach(u => {
      if (u.b_age == null || u.t_age == null) return;
      const key = (u.strat_name_long || u.unit_name) + '|' + u.b_age + '|' + u.t_age;
      if (seen.has(key)) return;
      seen.add(key);
      out.push({
        name: u.strat_name_long || u.unit_name || q,
        rank: u.strat_name_rank || '',
        fad: +u.b_age,                 // base = más antiguo
        lad: +u.t_age,                 // techo = más joven
        col: u.col_area || '',
        ref: u.refs && u.refs.length ? String(u.refs[0]) : ''
      });
    });
    // el rango más acotado primero: es el más informativo
    out.sort((a, b) => (a.fad - a.lad) - (b.fad - b.lad));
    return out;
  }

  /** Sugerencias de nombre, para cuando el usuario no sabe cómo se escribe. */
  async function suggest(name) {
    const q = String(name || '').trim();
    if (q.length < 3) return [];
    const r = await fetch(ENDPOINT + '?strat_name_like=' + encodeURIComponent(q) + '&format=json',
      { headers: { Accept: 'application/json' } });
    if (!r.ok) return [];
    const j = await r.json();
    const rows = (j && j.success && j.success.data) || [];
    const out = [], seen = new Set();
    rows.forEach(u => {
      const n = u.strat_name_long || u.strat_name;
      if (!n || seen.has(n)) return;
      seen.add(n);
      out.push({ name: n, rank: u.rank || '' });
    });
    return out.slice(0, 12);
  }

  global.PFMacro = { findUnit: findUnit, suggest: suggest };
})(typeof window !== 'undefined' ? window : globalThis);
