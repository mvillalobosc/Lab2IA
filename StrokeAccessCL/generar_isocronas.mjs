#!/usr/bin/env node
/* =====================================================================
   generar_isocronas.mjs — se corre UNA VEZ para dejar las coberturas
   precalculadas dentro de la app (data/isocronas.js).

   Uso (desde la carpeta de la app, requiere Node 18+):

       node generar_isocronas.mjs

   Con clave propia de OpenRouteService (recomendado, gratis en
   openrouteservice.org):

       ORS_KEY=tu_clave node generar_isocronas.mjs

   Qué hace: consulta OpenRouteService (driving-car, 1800/2700/3600 s,
   el método de la tesis) para los 93 establecimientos, respetando el
   límite de 20 peticiones/min, y escribe data/isocronas.js. Si se corta,
   vuelve a correrlo: retoma desde donde quedó (isocronas_progreso.json).
   Cuando data/isocronas.js existe, la app abre al instante y nunca
   muestra el «Preparando coberturas».
   ===================================================================== */
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const ORS_URL = process.env.ORS_URL || 'https://api.openrouteservice.org/v2/isochrones/driving-car';
const ORS_KEY = process.env.ORS_KEY || '';
if (!ORS_KEY) {
  console.error('Falta ORS_KEY. Ejecuta: ORS_KEY=tu_clave node generar_isocronas.mjs');
  process.exit(1);
}
const RANGOS = [1800,2700,3600];           // 30/45/60 min
const PROGRESO = path.join(AQUI,'isocronas_progreso.json');
const SALIDA = path.join(AQUI,'data','isocronas.js');

/* --- lee los establecimientos desde data/establecimientos.js --- */
const src = fs.readFileSync(path.join(AQUI,'data','establecimientos.js'),'utf8');
const ESTS = JSON.parse(src.replace(/^window\.ESTABLISHMENTS\s*=\s*/,'').replace(/;\s*$/,''));

/* --- progreso previo, si lo hay --- */
let iso = {};
if (fs.existsSync(PROGRESO)) {
  iso = JSON.parse(fs.readFileSync(PROGRESO,'utf8'));
  console.log(`Retomando: ${Object.keys(iso).length}/${ESTS.length} ya listos.`);
}

const redondear = g => ({type:g.type, coordinates:JSON.parse(JSON.stringify(
  g.coordinates,(k,v)=>typeof v==='number'?Math.round(v*1e4)/1e4:v))});
const espera = ms => new Promise(r=>setTimeout(r,ms));

const pendientes = ESTS.filter(e=>!iso[e.id]);
console.log(`Establecimientos pendientes: ${pendientes.length} de ${ESTS.length}.`);

for (let i=0; i<pendientes.length; i+=3) {
  const lote = pendientes.slice(i,i+3);
  let intento = 0;
  while (true) {
    try {
      const res = await fetch(ORS_URL,{method:'POST',
        headers:{'Authorization':ORS_KEY,'Content-Type':'application/json'},
        body:JSON.stringify({locations:lote.map(e=>[e.lon,e.lat]),
          range:RANGOS, range_type:'time', location_type:'start'})});
      if (res.status===429) { console.log('  · límite por minuto, esperando 25 s…'); await espera(25000); continue; }
      if (res.status===401||res.status===403)
        throw new Error('Clave de OpenRouteService inválida o con el límite diario agotado. '+
          'Crea una gratis en openrouteservice.org y corre: ORS_KEY=tu_clave node generar_isocronas.mjs');
      if (!res.ok) throw new Error('HTTP '+res.status);
      const gj = await res.json();
      lote.forEach(e=>iso[e.id]=iso[e.id]||{});
      for (const f of (gj.features||[])) {
        const e = lote[f.properties.group_index];
        const min = Math.round(f.properties.value/60);
        if (e && [30,45,60].includes(min)) iso[e.id][min]=redondear(f.geometry);
      }
      fs.writeFileSync(PROGRESO,JSON.stringify(iso));
      const listos = Object.keys(iso).length;
      console.log(`  ${listos}/${ESTS.length} · ${lote.map(e=>e.name.slice(0,38)).join(' | ')}`);
      break;
    } catch (err) {
      if (String(err).includes('openrouteservice.org')) { console.error('\n'+err.message); process.exit(1); }
      if (++intento>3) { console.error('  falló el lote tras 3 intentos:',err.message); process.exit(1); }
      console.log('  · reintentando…'); await espera(5000);
    }
  }
  if (i+3<pendientes.length) await espera(1600);   // 20 peticiones/min
}

/* --- verificación y escritura final --- */
const incompletos = ESTS.filter(e=>!iso[e.id] || !iso[e.id][30] || !iso[e.id][45] || !iso[e.id][60]);
if (incompletos.length)
  console.warn(`Ojo: ${incompletos.length} establecimientos quedaron sin los 3 tiempos (islas o zonas sin red vial): `+
    incompletos.map(e=>e.name).join(', '));

const contenido =
  '// Coberturas precalculadas: '+ESTS.length+' establecimientos x 30/45/60 min en auto.\n'+
  '// Método: OpenRouteService driving-car (tesis I. Guajardo, DIINF-USACH). Generado: '+new Date().toISOString().slice(0,10)+'.\n'+
  'window.ISOCRONAS='+JSON.stringify(iso)+';';
fs.writeFileSync(SALIDA,contenido);
fs.rmSync(PROGRESO,{force:true});
const mb=(fs.statSync(SALIDA).size/1048576).toFixed(1);
console.log(`\nListo: ${path.relative(AQUI,SALIDA)} (${mb} MB). La app ahora abre al instante; comprime la carpeta y compártela así.`);
