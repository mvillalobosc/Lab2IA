/* ======================================================================
 * PaleoForest — Escala de tiempo geológico (ICS / IUGS v2023)
 * Jerarquía completa: eón → era → período → época → piso (edad).
 * Cada nivel es un "modelo" seleccionable en el gráfico de temporalidad.
 * Colores oficiales ICS. Rangos en Ma (millones de años).
 * ==================================================================== */
(function (global) {
  'use strict';

  // n = nombre canónico, f = inicio (más antiguo), t = fin (más reciente), c = color ICS
  // a = alias adicionales (el CSV de la tesis trae variantes: "Triasic", "Cretacico"...)
  const EON = [
    { n: 'Hadean', f: 4567, t: 4031, c: '#AE027E', a: ['hadeano', 'hadeico'] },
    { n: 'Archean', f: 4031, t: 2500, c: '#F0047F', a: ['arqueano', 'arcaico'] },
    { n: 'Proterozoic', f: 2500, t: 538.8, c: '#F73563', a: ['proterozoico', 'proterozoico'] },
    { n: 'Phanerozoic', f: 538.8, t: 0, c: '#9AD9DD', a: ['fanerozoico', 'faneurozoico'] }
  ];

  const ERA = [
    { n: 'Paleoproterozoic', f: 2500, t: 1600, c: '#F74370', a: ['paleoproterozoico'] },
    { n: 'Mesoproterozoic', f: 1600, t: 1000, c: '#FDB462', a: ['mesoproterozoico'] },
    { n: 'Neoproterozoic', f: 1000, t: 538.8, c: '#FEB342', a: ['neoproterozoico'] },
    { n: 'Paleozoic', f: 538.8, t: 251.902, c: '#99C08D', a: ['paleozoico', 'paleozoica'] },
    { n: 'Mesozoic', f: 251.902, t: 66, c: '#67C5CA', a: ['mesozoico', 'mesozoica'] },
    { n: 'Cenozoic', f: 66, t: 0, c: '#F2F91D', a: ['cenozoico', 'cenozoica', 'caenozoic'] }
  ];

  const PERIOD = [
    { n: 'Cambrian', f: 538.8, t: 486.85, c: '#7FA056', a: ['cambrico', 'cambriano'] },
    { n: 'Ordovician', f: 486.85, t: 443.1, c: '#009270', a: ['ordovicico', 'ordoviciano'] },
    { n: 'Silurian', f: 443.1, t: 419.62, c: '#B3E1B6', a: ['silurico', 'siluriano'] },
    { n: 'Devonian', f: 419.62, t: 358.86, c: '#CB8C37', a: ['devonico', 'devoniano'] },
    { n: 'Carboniferous', f: 358.86, t: 298.9, c: '#67A599', a: ['carbonifero'] },
    { n: 'Permian', f: 298.9, t: 251.902, c: '#F04028', a: ['permico', 'permiano'] },
    { n: 'Triassic', f: 251.902, t: 201.4, c: '#812B92', a: ['triasico', 'triassico', 'triasic', 'trias'] },
    { n: 'Jurassic', f: 201.4, t: 143.1, c: '#34B2C9', a: ['jurasico', 'jurassico', 'jurasic'] },
    { n: 'Cretaceous', f: 143.1, t: 66, c: '#7FC64E', a: ['cretacico', 'cretaceo', 'cretacic', 'cretaceous'] },
    { n: 'Paleogene', f: 66, t: 23.04, c: '#FD9A52', a: ['paleogeno'] },
    { n: 'Neogene', f: 23.04, t: 2.58, c: '#FFE619', a: ['neogeno'] },
    { n: 'Quaternary', f: 2.58, t: 0, c: '#F9F97F', a: ['cuaternario'] }
  ];

  const EPOCH = [
    { n: 'Mississippian', f: 358.86, t: 323.4, c: '#678F66', a: ['misisipico'] },
    { n: 'Pennsylvanian', f: 323.4, t: 298.9, c: '#99C2B5', a: ['pensilvanico'] },
    { n: 'Cisuralian', f: 298.9, t: 274.4, c: '#EF5845', a: ['cisuraliense', 'lower permian', 'early permian', 'permico inferior'] },
    { n: 'Guadalupian', f: 274.4, t: 259.51, c: '#FB745C', a: ['guadalupiense', 'middle permian', 'permico medio'] },
    { n: 'Lopingian', f: 259.51, t: 251.902, c: '#FBA794', a: ['lopingiense', 'upper permian', 'late permian', 'permico superior'] },
    { n: 'Lower Triassic', f: 251.902, t: 246.7, c: '#983999', a: ['early triassic', 'triasico inferior', 'triasico temprano', 'lower triasic'] },
    { n: 'Middle Triassic', f: 246.7, t: 237, c: '#B168B1', a: ['triasico medio', 'middle triasic'] },
    { n: 'Upper Triassic', f: 237, t: 201.4, c: '#BD8CC3', a: ['late triassic', 'triasico superior', 'triasico tardio', 'upper triasic'] },
    { n: 'Lower Jurassic', f: 201.4, t: 174.7, c: '#42AED0', a: ['early jurassic', 'jurasico inferior', 'jurasico temprano', 'lower jurasic'] },
    { n: 'Middle Jurassic', f: 174.7, t: 161.5, c: '#80CFD8', a: ['jurasico medio', 'middle jurasic'] },
    { n: 'Upper Jurassic', f: 161.5, t: 143.1, c: '#B3E3EE', a: ['late jurassic', 'jurasico superior', 'jurasico tardio', 'upper jurasic'] },
    { n: 'Lower Cretaceous', f: 143.1, t: 100.5, c: '#8CCD57', a: ['early cretaceous', 'cretacico inferior', 'cretacico temprano', 'lower cretacic'] },
    { n: 'Upper Cretaceous', f: 100.5, t: 66, c: '#A6D84A', a: ['late cretaceous', 'cretacico superior', 'cretacico tardio', 'upper cretacic'] },
    { n: 'Paleocene', f: 66, t: 56, c: '#FDA75F', a: ['paleoceno'] },
    { n: 'Eocene', f: 56, t: 33.9, c: '#FDB46C', a: ['eoceno'] },
    { n: 'Oligocene', f: 33.9, t: 23.04, c: '#FDC07A', a: ['oligoceno'] },
    { n: 'Miocene', f: 23.04, t: 5.333, c: '#FFFF00', a: ['mioceno'] },
    { n: 'Pliocene', f: 5.333, t: 2.58, c: '#FFFF99', a: ['plioceno'] },
    { n: 'Pleistocene', f: 2.58, t: 0.0117, c: '#FFF2AE', a: ['pleistoceno'] },
    { n: 'Holocene', f: 0.0117, t: 0, c: '#FEF2E0', a: ['holoceno'] }
  ];

  const STAGE = [
    // Pérmico
    { n: 'Asselian', f: 298.9, t: 293.52, c: '#E36350', a: ['aseliense'] },
    { n: 'Sakmarian', f: 293.52, t: 290.1, c: '#E8705B', a: ['sakmariense'] },
    { n: 'Artinskian', f: 290.1, t: 283.3, c: '#ED7D66', a: ['artinskiense'] },
    { n: 'Kungurian', f: 283.3, t: 274.4, c: '#F28A72', a: ['kunguriense'] },
    { n: 'Roadian', f: 274.4, t: 268.8, c: '#FB8069', a: ['roadiense'] },
    { n: 'Wordian', f: 268.8, t: 265.1, c: '#FC8D77', a: ['wordiense'] },
    { n: 'Capitanian', f: 265.1, t: 259.51, c: '#FC9A85', a: ['capitaniense'] },
    { n: 'Wuchiapingian', f: 259.51, t: 254.14, c: '#FCB4A2', a: ['wuchiapingiense'] },
    { n: 'Changhsingian', f: 254.14, t: 251.902, c: '#FCC0B2', a: ['changhsingiense'] },
    // Triásico
    { n: 'Induan', f: 251.902, t: 251.2, c: '#A4469F', a: ['induense'] },
    { n: 'Olenekian', f: 251.2, t: 246.7, c: '#B051A5', a: ['olenekiense'] },
    { n: 'Anisian', f: 246.7, t: 241.464, c: '#BC75B7', a: ['anisiense'] },
    { n: 'Ladinian', f: 241.464, t: 237, c: '#C983C1', a: ['ladiniense'] },
    { n: 'Carnian', f: 237, t: 227.3, c: '#C99BCB', a: ['carniense', 'carnico'] },
    { n: 'Norian', f: 227.3, t: 208.5, c: '#D6AAD3', a: ['noriense', 'norico'] },
    { n: 'Rhaetian', f: 208.5, t: 201.4, c: '#E3B9DB', a: ['rhaetiense', 'retiense', 'raetiense'] },
    // Jurásico
    { n: 'Hettangian', f: 201.4, t: 199.5, c: '#4EB3D3', a: ['hettangiense'] },
    { n: 'Sinemurian', f: 199.5, t: 192.9, c: '#67BCD8', a: ['sinemuriense'] },
    { n: 'Pliensbachian', f: 192.9, t: 184.2, c: '#80C5DC', a: ['pliensbachiense'] },
    { n: 'Toarcian', f: 184.2, t: 174.7, c: '#99CEE3', a: ['toarciense'] },
    { n: 'Aalenian', f: 174.7, t: 170.9, c: '#9AD9DD', a: ['aaleniense'] },
    { n: 'Bajocian', f: 170.9, t: 168.2, c: '#A6DDE0', a: ['bajociense'] },
    { n: 'Bathonian', f: 168.2, t: 165.3, c: '#B3E2E3', a: ['bathoniense'] },
    { n: 'Callovian', f: 165.3, t: 161.5, c: '#BFE7E7', a: ['calloviense'] },
    { n: 'Oxfordian', f: 161.5, t: 154.8, c: '#BFE7F1', a: ['oxfordiense'] },
    { n: 'Kimmeridgian', f: 154.8, t: 149.2, c: '#CCECF4', a: ['kimmeridgiense'] },
    { n: 'Tithonian', f: 149.2, t: 143.1, c: '#D9F0F8', a: ['tithoniense', 'titoniense'] },
    // Cretácico
    { n: 'Berriasian', f: 143.1, t: 137.05, c: '#8CCD60', a: ['berriasiense'] },
    { n: 'Valanginian', f: 137.05, t: 132.6, c: '#99D36A', a: ['valanginiense'] },
    { n: 'Hauterivian', f: 132.6, t: 125.77, c: '#A6D975', a: ['hauteriviense'] },
    { n: 'Barremian', f: 125.77, t: 121.4, c: '#B3DF7F', a: ['barremiense'] },
    { n: 'Aptian', f: 121.4, t: 113, c: '#BFE48A', a: ['aptiense'] },
    { n: 'Albian', f: 113, t: 100.5, c: '#CCEA97', a: ['albiense'] },
    { n: 'Cenomanian', f: 100.5, t: 93.9, c: '#B3DE53', a: ['cenomaniense'] },
    { n: 'Turonian', f: 93.9, t: 89.8, c: '#BFE35D', a: ['turoniense'] },
    { n: 'Coniacian', f: 89.8, t: 86.3, c: '#CCE968', a: ['coniaciense'] },
    { n: 'Santonian', f: 86.3, t: 83.6, c: '#D9EF74', a: ['santoniense'] },
    { n: 'Campanian', f: 83.6, t: 72.1, c: '#E6F47F', a: ['campaniense', 'campanico'] },
    { n: 'Maastrichtian', f: 72.1, t: 66, c: '#F2FA8C', a: ['maastrichtiense', 'maestrichtiense'] },
    // Paleógeno
    { n: 'Danian', f: 66, t: 61.6, c: '#FDB482', a: ['daniense'] },
    { n: 'Selandian', f: 61.6, t: 59.2, c: '#FDBF8F', a: ['selandiense'] },
    { n: 'Thanetian', f: 59.2, t: 56, c: '#FDC79C', a: ['thanetiense'] },
    { n: 'Ypresian', f: 56, t: 47.8, c: '#FDC28A', a: ['ypresiense'] },
    { n: 'Lutetian', f: 47.8, t: 41.2, c: '#FDCD9B', a: ['luteciense'] },
    { n: 'Bartonian', f: 41.2, t: 37.71, c: '#FDD7A8', a: ['bartoniense'] },
    { n: 'Priabonian', f: 37.71, t: 33.9, c: '#FDE1B6', a: ['priaboniense'] },
    { n: 'Rupelian', f: 33.9, t: 27.82, c: '#FDD0A2', a: ['rupeliense'] },
    { n: 'Chattian', f: 27.82, t: 23.04, c: '#FDDCB3', a: ['chattiense'] }
  ];

  const LEVELS = { eon: EON, era: ERA, period: PERIOD, epoch: EPOCH, stage: STAGE };
  const LEVEL_KEYS = ['eon', 'era', 'period', 'epoch', 'stage'];

  /* ---------- normalización y búsqueda por nombre ---------- */
  function norm(s) {
    return String(s || '').toLowerCase().trim()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')   // quita acentos
      .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  }
  const INDEX = {};
  LEVEL_KEYS.forEach(k => {
    LEVELS[k].forEach(b => {
      b.level = k;
      const keys = [b.n].concat(b.a || []);
      keys.forEach(x => { INDEX[norm(x)] = b; });
    });
  });

  // busca una unidad por nombre en cualquier nivel (exacto, luego por inclusión)
  function byName(name) {
    const n = norm(name);
    if (!n) return null;
    if (INDEX[n]) return INDEX[n];
    let best = null;
    Object.keys(INDEX).forEach(k => {
      if (k && (n === k || n.indexOf(k) >= 0 || k.indexOf(n) >= 0)) {
        if (!best || k.length > norm(best.n).length) best = INDEX[k];
      }
    });
    return best;
  }

  // unidad de un nivel que contiene una edad (Ma)
  function atAge(level, ma) {
    const arr = LEVELS[level] || [];
    for (let i = 0; i < arr.length; i++) if (ma <= arr[i].f && ma >= arr[i].t) return arr[i];
    return null;
  }

  // jerarquía completa a partir de una edad (Ma)
  function hierarchyAt(ma) {
    const o = {};
    LEVEL_KEYS.forEach(k => { const b = atAge(k, ma); o[k] = b ? b.n : ''; });
    return o;
  }

  // bandas de un nivel que intersectan [young, old] (Ma), recortadas al rango
  function bands(level, oldMa, youngMa) {
    const lo = Math.min(oldMa, youngMa), hi = Math.max(oldMa, youngMa);
    return (LEVELS[level] || [])
      .filter(b => b.f > lo && b.t < hi)
      .map(b => ({ name: b.n, col: b.c, from: Math.min(b.f, hi), to: Math.max(b.t, lo), level: level }))
      .sort((a, b) => b.from - a.from);
  }

  // niveles con al menos `min` bandas visibles en el rango (para poblar el selector)
  function usableLevels(oldMa, youngMa, min) {
    return LEVEL_KEYS.filter(k => bands(k, oldMa, youngMa).length >= (min || 1));
  }

  global.GEO = { LEVELS, LEVEL_KEYS, byName, atAge, hierarchyAt, bands, usableLevels, norm };
})(typeof window !== 'undefined' ? window : globalThis);
