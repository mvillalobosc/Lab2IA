'use strict';
/* =====================================================================
   Accesibilidad ACV Chile — visor HTML/JS autosuficiente
   Basado en la memoria de título de I. Guajardo (DIINF-USACH, 2025).

   Comportamiento:
   - Al abrir, el mapa muestra TODO: los 93 establecimientos y sus
     isócronas de 30/45/60 min. Las isócronas se calculan con
     OpenRouteService (driving-car, método de la tesis) la primera vez
     y quedan guardadas en el navegador; mientras se calculan se van
     pintando progresivamente.
   - Desde ahí el usuario filtra: apaga tiempos, elige región/comuna,
     o pincha un hospital para destacar su cobertura.
   ===================================================================== */

/* ---------- resultados de la tesis (Tabla 5.1: cobertura a 45 min) ---------- */
const COBERTURA_REGIONAL = { // codregion: {pob %, ter %}
  15:{pob:98.94,ter:2.30}, 1:{pob:97.34,ter:0.54}, 2:{pob:89.23,ter:0.53},
  3:{pob:81.08,ter:1.09}, 4:{pob:83.97,ter:4.85}, 5:{pob:94.69,ter:16.94},
  13:{pob:99.79,ter:25.68}, 6:{pob:94.31,ter:17.39}, 7:{pob:86.95,ter:15.93},
  16:{pob:85.15,ter:23.75}, 8:{pob:90.44,ter:13.74}, 9:{pob:93.26,ter:21.33},
  14:{pob:72.53,ter:3.11}, 10:{pob:87.75,ter:8.32}, 11:{pob:60.91,ter:0.41},
  12:{pob:81.76,ter:0.16}
};
/* población cubierta por región (Tabla 5.2, intersección proporcional) */
const POB_CUBIERTA = {13:6809145,5:1539971,8:1238288,7:661421,6:638452,9:627008,
  10:532111,4:511854,2:502970,1:298132,16:283033,3:209871,15:202680,14:198211,
  12:122881,11:49427};
/* indicadores de salud regionales CASEN 2022 (Tabla A.6) */
const SALUD_REGIONAL = {
  1:{hta:4.73,dm:3.84,m60:12.44}, 2:{hta:5.69,dm:4.57,m60:15.88},
  3:{hta:6.43,dm:3.94,m60:17.40}, 4:{hta:9.77,dm:5.11,m60:20.41},
  5:{hta:9.49,dm:4.81,m60:19.83}, 6:{hta:11.35,dm:5.86,m60:21.46},
  7:{hta:9.76,dm:6.34,m60:18.57}, 8:{hta:9.23,dm:6.46,m60:19.94},
  9:{hta:8.84,dm:5.68,m60:18.22}, 10:{hta:8.41,dm:5.24,m60:20.85},
  11:{hta:5.02,dm:3.56,m60:13.71}, 12:{hta:8.76,dm:7.15,m60:22.60},
  13:{hta:8.97,dm:5.25,m60:18.77}, 14:{hta:8.78,dm:5.88,m60:19.09},
  15:{hta:5.54,dm:3.93,m60:16.10}, 16:{hta:11.47,dm:6.84,m60:19.99}
};

const TIERS = [30,45,60];
const TIER_COLOR = {30:'#00A499',45:'#EAAA00',60:'#EA7600'};
const ORS_URL = 'https://api.openrouteservice.org/v2/isochrones/driving-car';
const ORS_KEY_PROYECTO = ''; // GitHub/public version: paste your ORS key in Help if live recalculation is needed.
const CHILE_BOUNDS = [[-56.2,-76.8],[-17.4,-66.2]];

const $ = id => document.getElementById(id);
const ESTS = window.ESTABLISHMENTS;
const REG = window.REGIONES, COM = window.COMUNAS;

/* =====================================================================
   Estado
===================================================================== */
const S = {
  region:'', comuna:'',
  filtroHosp:new Set(),   // ids elegidos en el buscador (si hay, mandan)
  activos:{30:false,45:false,60:false},
  iso:{},              // code -> {30:geom,45:geom,60:geom}
  capas:{},            // code -> {30:L.GeoJSON,45:…,60:…} dibujadas
  sel:null,            // code del hospital destacado
  cargando:null,       // AbortController de la carga en curso
  puntoModo:false,
  simModo:false,
  sim:null,             // {marker, capas:[], lat, lon}
  nacional:null, nacionalSalud:null
};

/* =====================================================================
   Utilidades
===================================================================== */
const norm = s=>(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'');
const tr = (k,p)=>window.I18N.t(k,p);
const fmt = (n,d=1)=>n.toLocaleString(window.I18N.locale(),{minimumFractionDigits:d,maximumFractionDigits:d});
/* "Región de X" según idioma */
const regionLabel = name=>tr('regionPrefix',{name:nombreCorto(name)});
const nombreCorto = n=>(n||'').replace(/^Región (de la |del |de )?/i,'')
  .replace("Libertador Bernardo O'Higgins","O'Higgins")
  .replace('Metropolitana de Santiago','Metropolitana')
  .replace('Aysén del Gral.Ibañez del Campo','Aysén')
  .replace('Magallanes y Antártica Chilena','Magallanes');
const haversine=(a,b)=>{const R=6371,r=x=>x*Math.PI/180,dLa=r(b[0]-a[0]),dLo=r(b[1]-a[1]);
  const s=Math.sin(dLa/2)**2+Math.cos(r(a[0]))*Math.cos(r(b[0]))*Math.sin(dLo/2)**2;
  return 2*R*Math.asin(Math.sqrt(s));};

/* punto en polígono (ray casting) para Polygon y MultiPolygon GeoJSON */
function dentroDeAnillo(pt,ring){
  let dentro=false;
  for(let i=0,j=ring.length-1;i<ring.length;j=i++){
    const xi=ring[i][0],yi=ring[i][1],xj=ring[j][0],yj=ring[j][1];
    if(((yi>pt[1])!==(yj>pt[1])) && (pt[0] < (xj-xi)*(pt[1]-yi)/(yj-yi)+xi)) dentro=!dentro;
  }
  return dentro;
}
function dentroDeGeom(pt,geom){
  if(!geom) return false;
  const polys = geom.type==='Polygon'? [geom.coordinates]
              : geom.type==='MultiPolygon'? geom.coordinates : [];
  for(const poly of polys){
    if(dentroDeAnillo(pt,poly[0])){
      let enHoyo=false;
      for(let h=1;h<poly.length;h++) if(dentroDeAnillo(pt,poly[h])){enHoyo=true;break;}
      if(!enHoyo) return true;
    }
  }
  return false;
}
function bboxDeGeom(geom){
  let w=180,s=90,e=-180,n=-90;
  const rec=c=>{ if(typeof c[0]==='number'){ if(c[0]<w)w=c[0]; if(c[0]>e)e=c[0];
      if(c[1]<s)s=c[1]; if(c[1]>n)n=c[1]; } else c.forEach(rec); };
  rec(geom.coordinates);
  return {w,s,e,n};
}
function areaGeomKm2(geom){
  const polys=geom.type==='Polygon'?[geom.coordinates]:geom.coordinates;
  let tot=0;
  for(const poly of polys){
    for(let r=0;r<poly.length;r++){
      const ring=poly[r]; let a=0;
      const lat0=ring[0][1]*Math.PI/180, kx=111.32*Math.cos(lat0), ky=110.57;
      for(let i=0,j=ring.length-1;i<ring.length;j=i++)
        a+=(ring[j][0]*kx)*(ring[i][1]*ky)-(ring[i][0]*kx)*(ring[j][1]*ky);
      tot += (r===0?1:-1)*Math.abs(a/2);
    }
  }
  return Math.abs(tot);
}

/* =====================================================================
   Mapa base y marcadores
===================================================================== */
let map, capaIso, capaHosp, marcadores={}, puntoMarker=null;

function initMap(){
  map=L.map('map',{zoomControl:false,attributionControl:true,minZoom:4,maxZoom:18});
  L.control.zoom({position:'topright'}).addTo(map);
  L.control.scale({position:'bottomleft',imperial:false}).addTo(map);
  L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    {subdomains:'abcd',maxZoom:19,attribution:'© OpenStreetMap · © CARTO'}).addTo(map);
  map.fitBounds(CHILE_BOUNDS,{paddingTopLeft:[10,10]});
  capaIso=L.layerGroup().addTo(map);
  dibujarHospitales();
  map.on('click',clicEnMapa);
}

function iconoHosp(sel){
  const c = sel? '#394049' : '#C8102E';
  return L.divIcon({className:'pin-h'+(sel?' sel':''),iconSize:[27,27],iconAnchor:[13,26],popupAnchor:[0,-24],
    html:`<svg width="27" height="27" viewBox="0 0 26 26"><path d="M13 0C6.4 0 1 5.2 1 11.6 1 20 13 26 13 26s12-6 12-14.4C25 5.2 19.6 0 13 0Z" fill="${c}"/><circle cx="13" cy="11.3" r="7.2" fill="#fff"/><path d="M13 6.8v9M8.5 11.3h9" stroke="${c}" stroke-width="2.2" stroke-linecap="round"/></svg>`});
}
function dibujarHospitales(){
  capaHosp=L.markerClusterGroup({showCoverageOnHover:false,maxClusterRadius:40,
    disableClusteringAtZoom:9,
    iconCreateFunction:c=>{const n=c.getChildCount();const s=n<10?34:40;
      return L.divIcon({className:'marker-cluster',iconSize:[s,s],html:`<div style="width:${s-6}px;height:${s-6}px;margin:3px;font-size:${n<10?13:14}px">${n}</div>`});}});
  ESTS.forEach(e=>{
    const m=L.marker([e.lat,e.lon],{icon:iconoHosp(false),title:e.name});
    m.on('click',ev=>{ L.DomEvent.stopPropagation(ev); seleccionarHospital(e.id); });
    marcadores[e.id]=m; capaHosp.addLayer(m);
  });
  map.addLayer(capaHosp);
}

/* =====================================================================
   Selección de hospital: se destaca TODA su cobertura
===================================================================== */
function seleccionarHospital(id){
  if(S.sel===id){ deseleccionarHospital(); return; }
  S.sel=id;
  const e=ESTS.find(x=>x.id===id);
  Object.values(marcadores).forEach(m=>m.setIcon(iconoHosp(false)));
  marcadores[id].setIcon(iconoHosp(true));
  restilarIsocronas();
  marcadores[id].bindPopup(
    `<div class="pop-n">${e.name}</div>
     <div class="pop-c">${e.comuna} · ${regionLabel(e.region)}</div>
     <div class="pop-c" style="margin-top:5px">${tr('pop.covHighlight')}</div>`
  ).openPopup();
  aviso(tr('aviso.covHighlight',{name:e.name}),{ocultarEn:5000});
  actualizarCobertura();
}
function deseleccionarHospital(){
  if(S.sel===null) return;
  if(marcadores[S.sel]){ marcadores[S.sel].closePopup(); marcadores[S.sel].setIcon(iconoHosp(false)); }
  S.sel=null;
  restilarIsocronas();
  actualizarCobertura();
}

/* =====================================================================
   Preparación en segundo plano (píldora propia, no pisa los avisos)
===================================================================== */
function prep(txt,progreso){
  const p=$('prep');
  if(txt===null){ p.classList.remove('on'); return; }
  $('prepTxt').textContent=txt;
  if(progreso!=null) $('prepBar').firstElementChild.style.width=(progreso*100)+'%';
  p.classList.add('on');
}

/* =====================================================================
   Aviso (mensajes transitorios sobre el mapa)
===================================================================== */
function aviso(txt,{error=false,ocultarEn=0}={}){
  const a=$('aviso');
  if(txt===null){ a.classList.remove('on','err'); return; }
  $('avisoTxt').innerHTML=txt;
  a.classList.add('on'); a.classList.toggle('err',error);
  clearTimeout(aviso._t);
  if(ocultarEn) aviso._t=setTimeout(()=>a.classList.remove('on','err'),ocultarEn);
}

/* =====================================================================
   Isócronas: carga nacional automática al abrir (con caché local)
===================================================================== */
function orsKey(){ return (localStorage.getItem('acv_key')||'').trim() || ORS_KEY_PROYECTO; }
function cacheGet(code){ try{const v=localStorage.getItem('iso_'+code);return v?JSON.parse(v):null;}catch(e){return null;} }
function cacheSet(code,obj){
  try{ localStorage.setItem('iso_'+code,JSON.stringify(obj)); }
  catch(e){ try{
      const claves=Object.keys(localStorage).filter(k=>k.startsWith('iso_'));
      claves.slice(0,Math.ceil(claves.length/2)).forEach(k=>localStorage.removeItem(k));
      localStorage.setItem('iso_'+code,JSON.stringify(obj));
    }catch(e2){}
  }
}
const redondear=geom=>({type:geom.type,coordinates:JSON.parse(JSON.stringify(geom.coordinates,
  (k,v)=>typeof v==='number'?Math.round(v*1e4)/1e4:v))});

/* pinta (o repinta) las isócronas de un establecimiento */
function esVisible(e){
  if(S.filtroHosp.size) return S.filtroHosp.has(e.id);
  if(S.comuna) return e.cod_comuna===+S.comuna;
  if(S.region) return e.codregion===+S.region;
  return true;
}
function refrescarVisibles(){
  capaHosp.clearLayers();
  ESTS.forEach(e=>{ if(esVisible(e)) capaHosp.addLayer(marcadores[e.id]); });
  ESTS.forEach(e=>{
    const capas=S.capas[e.id]; if(!capas) return;
    TIERS.forEach(t=>{
      const c=capas[t]; if(!c) return;
      const on=S.activos[t] && esVisible(e);
      if(on){ if(!capaIso.hasLayer(c)) c.addTo(capaIso); } else capaIso.removeLayer(c);
    });
  });
  if(S.sel!==null){ const e=ESTS.find(x=>x.id===S.sel); if(e && !esVisible(e)) deseleccionarHospital(); }
}
function pintarHospital(e){
  if(S.capas[e.id]) Object.values(S.capas[e.id]).forEach(l=>capaIso.removeLayer(l));
  S.capas[e.id]={};
  if(!S.iso[e.id]) return;
  for(const t of [60,45,30]){                 // grande abajo, chico arriba
    const g=S.iso[e.id][t];
    if(!g) continue;
    const capa=L.geoJSON({type:'Feature',geometry:g},{style:estiloIso(e.id,t)})
      .bindTooltip(tr('tooltip.reachIn',{name:e.name,t}),{sticky:true})
      .on('click',ev=>{
        if(S.puntoModo||S.simModo) return;           // deja pasar el clic al mapa
        L.DomEvent.stopPropagation(ev); seleccionarHospital(e.id);
      });
    if(S.activos[t] && esVisible(e)) capa.addTo(capaIso);
    S.capas[e.id][t]=capa;
  }
}
function estiloIso(id,t){
  const base={color:TIER_COLOR[t],fillColor:TIER_COLOR[t]};
  if(S.sel===null)   return {...base,weight:1.1,opacity:.6,fillOpacity:.16};
  if(S.sel===id)   return {...base,weight:2.6,opacity:1,fillOpacity:.32};
  return {...base,weight:.7,opacity:.2,fillOpacity:.04}; // atenuadas
}
function restilarIsocronas(){
  for(const e of ESTS){
    const capas=S.capas[e.id]; if(!capas) continue;
    for(const t of TIERS){
      if(!capas[t]) continue;
      capas[t].setStyle(estiloIso(e.id,t));
      if(S.sel===e.id) capas[t].bringToFront();
    }
  }
  if(S.sel!==null && marcadores[S.sel]) { /* pin arriba de todo */ }
}
function alternarTier(t){
  S.activos[t]=!S.activos[t];
  if(S.activos[t] && !Object.keys(S.iso).length && S.cargando)
    aviso(tr('load.preparing'),{ocultarEn:4000});
  $('t'+t).setAttribute('aria-pressed',S.activos[t]);
  refrescarVisibles();
}

async function cargarCoberturaNacional(){
  /* 0) archivo precalculado del proyecto (data/isocronas.js), si existe */
  if(!window.ISOCRONAS){
    console.warn('[VisorACV] data/isocronas.js no cargó datos: o no se subió al servidor, '+
      'o sigue siendo el stub de comentarios, o el servidor respondió 404.');
  }
  if(window.ISOCRONAS){
    let n=0;
    for(const id in window.ISOCRONAS){
      const e=ESTS.find(x=>x.id===+id);
      if(e && !S.iso[e.id]){ S.iso[e.id]=window.ISOCRONAS[id]; pintarHospital(e); n++; }
    }
    if(Object.keys(S.iso).length>=ESTS.length){
      actualizarCobertura();
      aviso(sinTiemposActivos()? tr('load.fromFileOn') : tr('load.fromFile'),{ocultarEn:7000});
      refrescarVeredictoPendiente();
      return;
    }
    console.warn(`[VisorACV] data/isocronas.js está incompleto: trae ${n} de ${ESTS.length} establecimientos. Se completa el resto en vivo.`);
    aviso(tr('load.incomplete',{n,total:ESTS.length}),{error:true,ocultarEn:10000});
  }

  /* 1) lo que ya está en caché de este navegador: aparece al instante */
  let enCache=0;
  for(const e of ESTS){
    const c=cacheGet(e.id);
    if(c){ S.iso[e.id]=c; pintarHospital(e); enCache++; }
  }
  const pendientes=ESTS.filter(e=>!S.iso[e.id]);
  actualizarCobertura();
  if(!pendientes.length){
    if(!window.ISOCRONAS){
      aviso(tr('load.cacheNoFile'),{ocultarEn:0});
      $('avisoDescargar').onclick=descargarIsocronas;
    }else{
      aviso(sinTiemposActivos()? tr('load.readyOn') : tr('load.ready'),{ocultarEn:7000});
    }
    refrescarVeredictoPendiente();
    return;
  }
  if(!window.ISOCRONAS){
    aviso(tr('load.noFileLive'),{error:true,ocultarEn:9000});
  }

  if(!navigator.onLine){
    aviso(tr('load.offline'),{error:true});
    $('avisoRetry').onclick=cargarCoberturaNacional;
    return;
  }
  const ctrl=new AbortController(); S.cargando=ctrl;
  $('prepCancel').onclick=()=>ctrl.abort();
  const total=ESTS.length; let hechos=enCache, falloDef=null;

  prep(tr('load.prep',{done:hechos,total}),hechos/total);

  for(let i=0;i<pendientes.length;i+=3){
    if(ctrl.signal.aborted) break;
    const lote=pendientes.slice(i,i+3);
    try{
      const res=await fetch(ORS_URL,{method:'POST',signal:ctrl.signal,
        headers:{'Authorization':orsKey(),'Content-Type':'application/json'},
        body:JSON.stringify({locations:lote.map(e=>[e.lon,e.lat]),
          range:[1800,2700,3600],range_type:'time',location_type:'start'})});
      if(res.status===429){ prep(tr('load.rate'),hechos/total);
        await new Promise(r=>setTimeout(r,20000)); i-=3; continue; }
      if(res.status===401||res.status===403){ falloDef='clave'; break; }
      if(!res.ok) throw new Error('HTTP '+res.status);
      const gj=await res.json();
      lote.forEach(e=>S.iso[e.id]=S.iso[e.id]||{});
      (gj.features||[]).forEach(f=>{
        const e=lote[f.properties.group_index];
        const min=Math.round(f.properties.value/60);
        if(e && TIERS.includes(min)) S.iso[e.id][min]=redondear(f.geometry);
      });
      lote.forEach(e=>{
        if(S.iso[e.id] && Object.keys(S.iso[e.id]).length){ cacheSet(e.id,S.iso[e.id]); pintarHospital(e); }
      });
      hechos+=lote.length;
      prep(tr('load.prep',{done:Math.min(hechos,total),total}),hechos/total);
      refrescarVeredictoPendiente();
      if(i+3<pendientes.length) await new Promise(r=>setTimeout(r,1600)); // 20 peticiones/min
    }catch(err){
      if(ctrl.signal.aborted) break;
      falloDef='red'; break;
    }
  }
  S.cargando=null;
  prep(null);
  actualizarCobertura();
  if(ctrl.signal.aborted){
    aviso(tr('load.paused'),{ocultarEn:0});
    $('avisoRetry').onclick=cargarCoberturaNacional;
  }else if(falloDef==='clave'){
    aviso(tr('load.keyFail'),{error:true});
    $('avisoAyuda').onclick=()=>{$('btnAyuda').click();};
  }else if(falloDef==='red'){
    aviso(tr('load.netFail'),{error:true});
    $('avisoRetry').onclick=cargarCoberturaNacional;
  }else{
    if(!window.ISOCRONAS){
      aviso(sinTiemposActivos()? tr('load.doneNoFileOn') : tr('load.doneNoFile'),{ocultarEn:0});
      $('avisoDescargar').onclick=descargarIsocronas;
    }else{
      aviso(sinTiemposActivos()? tr('load.readyOn') : tr('load.ready'),{ocultarEn:7000});
    }
  }
  refrescarVeredictoPendiente();
}

/* =====================================================================
   Paso 1: territorio (solo enfoca; la cobertura ya está pintada)
===================================================================== */
function poblarRegiones(){
  const selReg=$('selRegion');
  const prev=selReg.value;
  /* quita opciones ya agregadas (conserva el placeholder "Todo Chile") */
  [...selReg.querySelectorAll('option')].forEach(o=>{ if(o.value!=='') o.remove(); });
  const porRegion={};
  ESTS.forEach(e=>porRegion[e.codregion]=(porRegion[e.codregion]||0)+1);
  const feats=[...REG.features].sort((a,b)=>a.properties.codregion-b.properties.codregion);
  for(const f of feats){
    const cod=f.properties.codregion, n=porRegion[cod]||0;
    const o=document.createElement('option');
    o.value=cod;
    const est = n===1 ? tr('est.one') : tr('est.many');
    o.textContent = n? tr('regionOpt',{name:nombreCorto(f.properties.Region),n,est})
                      : tr('regionOptNone',{name:nombreCorto(f.properties.Region),est});
    selReg.appendChild(o);
  }
  if(prev) selReg.value=prev;
}
function poblarComunas(cod){
  const sel=$('selComuna');
  sel.innerHTML='';
  const lista=ESTS.filter(e=>e.codregion===+cod);
  if(!lista.length){ sel.disabled=true; sel.innerHTML=`<option value="">${tr('comunaNone')}</option>`; return; }
  sel.disabled=false;
  sel.innerHTML=`<option value="">${tr('comunaAll')}</option>`;
  const porProv={};
  lista.forEach(e=>{ porProv[e.provincia]=porProv[e.provincia]||new Map();
    porProv[e.provincia].set(e.cod_comuna,e.comuna); });
  Object.keys(porProv).sort().forEach(p=>{
    const g=document.createElement('optgroup'); g.label=tr('provincia',{name:p});
    [...porProv[p].entries()].sort((a,b)=>a[1].localeCompare(b[1]))
      .forEach(([id,nom])=>{const o=document.createElement('option');o.value=id;o.textContent=nom;g.appendChild(o);});
    sel.appendChild(g);
  });
}
function irARegion(cod){
  S.region=cod; S.comuna='';
  if(S.filtroHosp.size){ S.filtroHosp.clear(); renderHospChips(); }
  actualizarReset(); $('btnReset').classList.toggle('on',!!cod);
  deseleccionarHospital(); limpiarPunto();
  if(!cod){
    $('selComuna').disabled=true;
    $('selComuna').innerHTML=`<option value="">${tr('p1.comunaFirst')}</option>`;
    map.flyToBounds(CHILE_BOUNDS,{duration:.8});
    refrescarVisibles(); actualizarCobertura();
    return;
  }
  poblarComunas(cod);
  const f=REG.features.find(x=>x.properties.codregion===+cod);
  if(f) map.flyToBounds(L.geoJSON(f).getBounds().pad(.06),{duration:.8});
  refrescarVisibles(); actualizarCobertura();
}
function irAComuna(id){
  S.comuna=id;
  deseleccionarHospital(); limpiarPunto();
  if(!id){ irARegion(S.region); return; }
  const f=COM.features.find(x=>x.properties.cod_comuna===+id);
  if(f) map.flyToBounds(L.geoJSON(f).getBounds().pad(.12),{duration:.7});
  refrescarVisibles(); actualizarCobertura();
}

/* =====================================================================
   Buscador de establecimientos con selección múltiple
===================================================================== */
function renderHospChips(){
  const box=$('hospChips');
  const sel=[...S.filtroHosp].map(id=>ESTS.find(e=>e.id===id));
  box.innerHTML = sel.map(e=>
    `<span class="chip"><span title="${e.name}">${e.name}</span>
       <button data-quita="${e.id}" aria-label="${tr('chip.remove',{name:e.name})}">✕</button></span>`).join('')
    + (sel.length? `<span class="chip limpiar" id="chipLimpiar">${tr('chip.clear',{n:sel.length})}</span>` : '');
  $('hospHint').hidden = true;
  if(typeof actualizarReset==='function') actualizarReset();
  box.querySelectorAll('[data-quita]').forEach(b=>b.onclick=()=>{
    S.filtroHosp.delete(+b.dataset.quita);
    renderHospChips(); refrescarVisibles(); encuadrarSeleccion();
  });
  const lim=$('chipLimpiar');
  if(lim) lim.onclick=()=>{ S.filtroHosp.clear(); renderHospChips(); refrescarVisibles();
    aviso(tr('chip.clearedAll'),{ocultarEn:4000}); };
}
function encuadrarSeleccion(){
  const sel=[...S.filtroHosp].map(id=>ESTS.find(e=>e.id===id));
  if(!sel.length) return;
  const b=L.latLngBounds(sel.map(e=>[e.lat,e.lon]));
  map.flyToBounds(b.pad(.35),{duration:.7,maxZoom:11});
}
function renderHospSug(q){
  const caja=$('hospSug');
  const nq=norm(q);
  if(nq.length<2){ caja.hidden=true; caja.innerHTML=''; return; }
  const hits=ESTS.filter(e=>norm(e.name+' '+e.comuna).includes(nq)).slice(0,8);
  if(!hits.length){ caja.innerHTML=`<button disabled>${tr('sug.none')}</button>`; caja.hidden=false; return; }
  caja.innerHTML=hits.map(e=>
    `<button data-id="${e.id}"><span class="ck ${S.filtroHosp.has(e.id)?'on':''}"></span>
       <span class="txt">${e.name}<small>${e.comuna} · ${regionLabel(e.region)}</small></span></button>`).join('');
  caja.hidden=false;
  caja.querySelectorAll('button[data-id]').forEach(b=>b.onclick=ev=>{
    ev.stopPropagation();
    const id=+b.dataset.id;
    if(S.filtroHosp.has(id)) S.filtroHosp.delete(id); else S.filtroHosp.add(id);
    b.querySelector('.ck').classList.toggle('on',S.filtroHosp.has(id));
    renderHospChips(); refrescarVisibles(); encuadrarSeleccion();
  });
}

/* =====================================================================
   Paso 3: cuadro de cobertura (nacional / regional / comunal)
===================================================================== */
function calcularNacional(){
  let pobCub=0,pobTot=0,terPond=0,areaTot=0;
  let hta=0,dm=0,m60=0;
  for(const f of REG.features){
    const cod=f.properties.codregion, c=COBERTURA_REGIONAL[cod];
    if(!c) continue;
    const cub=POB_CUBIERTA[cod]||0;
    const tot=c.pob>0? cub/(c.pob/100):0;
    pobCub+=cub; pobTot+=tot;
    const a=areaGeomKm2(f.geometry);
    terPond+=c.ter*a; areaTot+=a;
    const sr=SALUD_REGIONAL[cod];
    if(sr){ hta+=sr.hta*tot; dm+=sr.dm*tot; m60+=sr.m60*tot; }
  }
  S.nacional={pob:pobCub/pobTot*100, ter:terPond/areaTot};
  S.nacionalSalud={hta:hta/pobTot, dm:dm/pobTot, m60:m60/pobTot};
}
function gaugeHTML(lbl,val,nac,nota){
  return `<div class="gauge">
    <div class="g-top"><span class="g-lbl">${lbl}</span><span class="g-val">${fmt(val)}%</span></div>
    <div class="g-track"><span class="g-fill" style="width:${Math.min(100,val)}%"></span>
      ${nac!=null?`<span class="g-nac" style="left:${Math.min(100,nac)}%" title="${tr('gauge.nacAvg',{v:fmt(nac)})}"></span>`:''}</div>
    ${nota?`<div class="g-foot">${nota}</div>`:''}
  </div>`;
}

function deltaPP(v,n){
  const d=v-n, sig=d>=0?'+':'−';
  return `<small style="color:${d>=0?'#C8102E':'#00A499'};font-weight:700"> ${sig}${fmt(Math.abs(d))} pp</small>`;
}

function actualizarCobertura(){
  const card=$('cobCard');

  /* hospital destacado: características de su población regional */
  if(S.sel!==null){
    const e=ESTS.find(x=>x.id===S.sel);
    const c=COBERTURA_REGIONAL[e.codregion], sr=SALUD_REGIONAL[e.codregion], ns=S.nacionalSalud;
    card.innerHTML=`
      <div class="cob-head"><div class="amb">${tr('cob.destacado')}</div>
        <div class="nom">${e.name}</div></div>
      <div class="cob-body">
        <div class="g-top" style="margin-bottom:2px"><span class="g-lbl">${tr('cob.comuna')}</span><span style="font-weight:700">${e.comuna}</span></div>
        <div class="g-top" style="margin-bottom:10px"><span class="g-lbl">${tr('cob.region')}</span><span style="font-weight:700">${nombreCorto(e.region)}</span></div>
        ${c?gaugeHTML(tr('gauge.regPobCub'),c.pob,S.nacional.pob,tr('cob.vsNac',{v:fmt(S.nacional.pob)})):''}
      </div>
      ${sr?`<div class="riesgo"><h4 title="${tr('risk.regTitle.title')}">${tr('risk.regTitle')}</h4>
        <div class="fila">
          <div class="rk"><b>${fmt(sr.hta)}%</b><span>${tr('risk.hta')}${deltaPP(sr.hta,ns.hta)}</span></div>
          <div class="rk"><b>${fmt(sr.dm)}%</b><span>${tr('risk.dm')}${deltaPP(sr.dm,ns.dm)}</span></div>
          <div class="rk"><b>${fmt(sr.m60)}%</b><span>${tr('risk.m60')}${deltaPP(sr.m60,ns.m60)}</span></div>
        </div>
        <p class="hint" style="margin:8px 0 0">${tr('risk.arrowNote')}</p></div>`:''}
      <div class="cob-note" style="display:flex;gap:8px;align-items:center;justify-content:space-between">
        <a href="https://www.google.com/maps/dir/?api=1&destination=${e.lat},${e.lon}" target="_blank" rel="noopener" style="color:var(--mar-2);font-weight:700;text-decoration:none">${tr('cob.route')}</a>
        <button id="btnSoltar" style="color:var(--gris);font-weight:600;font-size:12px">${tr('cob.drop')}</button>
      </div>`;
    $('btnSoltar').onclick=deseleccionarHospital;
    return;
  }

  /* nacional (por defecto) */
  if(!S.region){
    card.innerHTML=`
      <div class="cob-head"><div class="amb">${tr('cob.headThesis')}</div>
        <div class="nom">${tr('cob.chile93')}</div></div>
      <div class="cob-body">
        ${gaugeHTML(tr('gauge.pobCub'),S.nacional.pob,null)}
        ${gaugeHTML(tr('gauge.terCub'),S.nacional.ter,null)}
      </div>
      <div class="cob-note">${tr('cob.nacNote')}</div>`;
    return;
  }

  const cod=+S.region;
  const reg=REG.features.find(f=>f.properties.codregion===cod);
  const c=COBERTURA_REGIONAL[cod];
  const s=SALUD_REGIONAL[cod];

  if(!S.comuna){
    card.innerHTML=`
      <div class="cob-head"><div class="amb">${tr('cob.headThesis')}</div>
        <div class="nom">${regionLabel(reg.properties.Region)}</div></div>
      <div class="cob-body">
        ${gaugeHTML(tr('gauge.pobCub'),c.pob,S.nacional.pob,tr('cob.vsNac',{v:fmt(S.nacional.pob)}))}
        ${gaugeHTML(tr('gauge.terCub'),c.ter,S.nacional.ter,tr('cob.vsNac',{v:fmt(S.nacional.ter)}))}
      </div>
      <div class="cob-note">${tr('cob.regNote')}</div>
      ${s?`<div class="riesgo"><h4 title="${tr('risk.factTitle.title')}">${tr('risk.factTitle')}</h4>
        <div class="fila">
          <div class="rk"><b>${fmt(s.hta)}%</b><span>${tr('risk.hta')}</span></div>
          <div class="rk"><b>${fmt(s.dm)}%</b><span>${tr('risk.dm')}</span></div>
          <div class="rk"><b>${fmt(s.m60)}%</b><span>${tr('risk.m60')}</span></div>
        </div></div>`:''}`;
    return;
  }

  /* comuna */
  const fCom=COM.features.find(x=>x.properties.cod_comuna===+S.comuna);
  const hosps=ESTS.filter(e=>e.cod_comuna===+S.comuna);
  const est=estimarCoberturaComuna(fCom);
  const cuerpo = est==null
    ? `<div class="cob-note" style="padding-top:13px">${tr('cob.comPending')}</div>`
    : `<div class="cob-body">${gaugeHTML(tr('gauge.terComCub'),est,c.ter,
        tr('cob.vsReg',{v:fmt(c.ter)}))}</div>
       <div class="cob-note">${tr('cob.comNote')}</div>`;
  card.innerHTML=`
    <div class="cob-head"><div class="amb">${tr('cob.comHead')}</div>
      <div class="nom">${fCom?fCom.properties.Comuna:''}</div></div>
    ${cuerpo}
    <div class="riesgo"><h4>${hosps.length? tr('cob.comHosps'):tr('cob.comNoHosps')}</h4>
      ${hosps.map(h=>`<div class="hosp-item"><span class="nm">${h.name}</span>
        <a href="#" data-vuela="${h.id}">${tr('cob.see')}</a></div>`).join('')||
        `<p class="hint" style="margin:0">${tr('cob.comVecinas')}</p>`}
    </div>`;
  card.querySelectorAll('[data-vuela]').forEach(a=>a.onclick=ev=>{
    ev.preventDefault();
    const e=ESTS.find(x=>x.id===+a.dataset.vuela);
    map.flyTo([e.lat,e.lon],12,{duration:.7});
    seleccionarHospital(e.id);
  });
}

function estimarCoberturaComuna(fCom){
  if(!fCom) return null;
  const codR=fCom.properties.codregion;
  const polys=[];
  ESTS.filter(e=>e.codregion===codR).forEach(e=>{
    const g=S.iso[e.id] && S.iso[e.id][45];
    if(g) polys.push(g);
  });
  if(!polys.length) return null;
  const bb=bboxDeGeom(fCom.geometry);
  let dentroComuna=0,cubiertos=0,intentos=0;
  while(dentroComuna<420 && intentos<4200){
    intentos++;
    const p=[bb.w+Math.random()*(bb.e-bb.w), bb.s+Math.random()*(bb.n-bb.s)];
    if(!dentroDeGeom(p,fCom.geometry)) continue;
    dentroComuna++;
    if(polys.some(g=>dentroDeGeom(p,g))) cubiertos++;
  }
  if(dentroComuna<40) return null;
  return cubiertos/dentroComuna*100;
}

/* =====================================================================
   Paso 4: consulta de punto y modo emergencia
===================================================================== */
function activarPunto(){
  S.puntoModo=!S.puntoModo;
  $('btnPunto').classList.toggle('armado',S.puntoModo);
  $('mainMap').classList.toggle('crosshair',S.puntoModo);
  if(S.puntoModo) aviso(tr('punto.clickMap'),{ocultarEn:4000});
}
function clicEnMapa(ev){
  if(S.simModo){ colocarSim(ev.latlng.lat,ev.latlng.lng); return; }
  if(S.puntoModo){
    S.puntoModo=false;
    $('btnPunto').classList.remove('armado');
    $('mainMap').classList.remove('crosshair');
    evaluarPunto(ev.latlng.lat,ev.latlng.lng,false);
    return;
  }
  deseleccionarHospital();
}
function sinGPS(motivo){
  aviso(motivo+tr('gps.hint'),{error:true,ocultarEn:9000});
  const inp=$('inpDir');
  inp.focus(); inp.scrollIntoView({behavior:'smooth',block:'center'});
}
function usarGPS(){
  if(!navigator.geolocation){ sinGPS(tr('gps.noGeo')); return; }
  if(!window.isSecureContext){
    sinGPS(tr('gps.insecure'));
    return;
  }
  aviso(tr('gps.getting'));
  navigator.geolocation.getCurrentPosition(
    p=>{ evaluarPunto(p.coords.latitude,p.coords.longitude,true); },
    err=>{ sinGPS(err && err.code===1 ? tr('gps.denied') : tr('gps.fail')); },
    {enableHighAccuracy:true,timeout:9000});
}

/* ---------- búsqueda de dirección (Nominatim / OpenStreetMap) ---------- */
function debounce(fn,ms){ let t; return (...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms);}; }
const buscarDireccion=debounce(async q=>{
  const caja=$('dirSug');
  if(q.trim().length<3){ caja.hidden=true; caja.innerHTML=''; return; }
  try{
    const url='https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=cl&limit=5&accept-language='+window.I18N.lang()+'&q='
      +encodeURIComponent(q);
    const res=await fetch(url);
    if(!res.ok) throw new Error(res.status);
    const lista=await res.json();
    if(!lista.length){ caja.innerHTML=`<button disabled>${tr('dir.noResults')}</button>`; caja.hidden=false; return; }
    caja.innerHTML=lista.map((r,i)=>{
      const partes=r.display_name.split(', ');
      return `<button data-i="${i}"><b>${partes.slice(0,2).join(', ')}</b><small>${partes.slice(2,5).join(', ')}</small></button>`;
    }).join('');
    caja.hidden=false;
    caja.querySelectorAll('button[data-i]').forEach(b=>b.onclick=()=>{
      const r=lista[+b.dataset.i];
      caja.hidden=true;
      $('inpDir').value=r.display_name.split(', ').slice(0,2).join(', ');
      evaluarPunto(+r.lat,+r.lon,false);
    });
  }catch(e){
    caja.innerHTML=`<button disabled>${tr('dir.error')}</button>`; caja.hidden=false;
  }
},450);
function evaluarPunto(lat,lon,esEmergencia,silencioso=false){
  S.ultimoPunto={lat,lon,esEmergencia};
  if(!silencioso) aviso(null);
  if(puntoMarker) map.removeLayer(puntoMarker);
  puntoMarker=L.marker([lat,lon],{icon:L.divIcon({className:'',iconSize:[16,16],iconAnchor:[8,8],
    html:'<div class="punto-marker"></div>'})}).addTo(map);

  const pt=[lon,lat];
  const fCom=COM.features.find(f=>dentroDeGeom(pt,f.geometry));

  let mejor=null, algunaCargada=Object.keys(S.iso).length>0;
  for(const e of ESTS){
    if(!S.iso[e.id]) continue;
    for(const t of TIERS){
      if(S.iso[e.id][t] && dentroDeGeom(pt,S.iso[e.id][t])){ if(mejor===null||t<mejor) mejor=t; }
    }
    if(mejor===30) break;
  }

  const cercanos=ESTS.map(e=>({e,d:haversine([lat,lon],[e.lat,e.lon])}))
    .sort((a,b)=>a.d-b.d).slice(0,3);

  const box=$('puntoRes'); box.classList.add('on');
  let veredicto;
  if(mejor!==null){
    veredicto=`<div class="veredicto" style="background:${TIER_COLOR[mejor]}">
      <span class="big">≤ ${mejor} min</span> ${tr('ver.reach')}</div>`;
  }else if(algunaCargada){
    veredicto=`<div class="veredicto" style="background:#C8102E">
      <span class="big">&gt; 60 min</span> ${tr('ver.out')}</div>`;
  }else{
    veredicto=`<div class="veredicto" style="background:var(--gris)">
      ${tr('ver.pending')}</div>`;
  }
  box.innerHTML=`
    <div class="pr-head"><b>${esEmergencia?tr('pr.myLoc'):tr('pr.point')}${fCom?` · ${fCom.properties.Comuna}`:''}</b>
      <button id="prCerrar">${tr('pr.remove')}</button></div>
    ${veredicto}
    <div style="font-size:11px;color:var(--gris);margin-bottom:4px">${tr('pr.nearest')}</div>
    ${cercanos.map(({e,d})=>`<div class="hosp-item">
      <span class="km">${fmt(d)} km</span>
      <span class="nm">${e.name}<small>${e.comuna}</small></span>
      <a href="https://www.google.com/maps/dir/?api=1&origin=${lat},${lon}&destination=${e.lat},${e.lon}" target="_blank" rel="noopener">${tr('pr.route')}</a>
    </div>`).join('')}`;
  $('prCerrar').onclick=limpiarPunto;
  box.scrollIntoView({behavior:'smooth',block:'nearest'});

  if(!silencioso) map.flyTo([lat,lon],Math.max(map.getZoom(),11),{duration:.7});
}
function refrescarVeredictoPendiente(){
  if(S.ultimoPunto && $('puntoRes').classList.contains('on')){
    const p=S.ultimoPunto;
    evaluarPunto(p.lat,p.lon,p.esEmergencia,true);
  }
}
function limpiarPunto(){
  S.ultimoPunto=null;
  $('puntoRes').classList.remove('on'); $('puntoRes').innerHTML='';
  if(puntoMarker){ map.removeLayer(puntoMarker); puntoMarker=null; }
}

/* =====================================================================
   Funciones avanzadas: establecimiento simulado (temporal, no se guarda)
===================================================================== */
const SIM_COLOR='#8C4799';
function iconoSim(){
  return L.divIcon({className:'pin-h',iconSize:[29,29],iconAnchor:[14,28],
    html:`<svg width="29" height="29" viewBox="0 0 26 26"><path d="M13 0C6.4 0 1 5.2 1 11.6 1 20 13 26 13 26s12-6 12-14.4C25 5.2 19.6 0 13 0Z" fill="${SIM_COLOR}" stroke="#fff" stroke-width="1.4" stroke-dasharray="3,2"/><circle cx="13" cy="11.3" r="7" fill="#fff"/><path d="M13 6.9v8.8M8.6 11.3h8.8" stroke="${SIM_COLOR}" stroke-width="2.1" stroke-linecap="round"/></svg>`});
}
function armarSim(){
  quitarSim();
  S.simModo=true; S.puntoModo=false;
  $('btnPunto').classList.remove('armado');
  $('btnSim').classList.add('armado');
  $('mainMap').classList.add('crosshair');
  aviso(tr('sim.clickWhere'),{ocultarEn:5000});
}
function desarmarSim(){
  S.simModo=false;
  $('btnSim').classList.remove('armado');
  $('mainMap').classList.remove('crosshair');
}
async function colocarSim(lat,lon){
  desarmarSim();
  const fCom=COM.features.find(f=>dentroDeGeom([lon,lat],f.geometry));
  S.sim={lat,lon,capas:[],
    marker:L.marker([lat,lon],{icon:iconoSim(),title:tr('sim.markerTitle')}).addTo(map)};
  $('leySim').hidden=false;
  const caja=$('simRes'); caja.classList.add('on');
  caja.innerHTML=`<div class="pr-head"><b>${tr('sim.name')}${fCom?` · ${fCom.properties.Comuna}`:''}</b>
      <button id="simQuitar">${tr('pr.remove')}</button></div>
    <p class="hint" style="margin:0">${tr('sim.calc')}</p>`;
  $('simQuitar').onclick=quitarSim;
  map.flyTo([lat,lon],Math.max(map.getZoom(),9),{duration:.6});
  try{
    const res=await fetch(ORS_URL,{method:'POST',
      headers:{'Authorization':orsKey(),'Content-Type':'application/json'},
      body:JSON.stringify({locations:[[lon,lat]],range:[1800,2700,3600],range_type:'time',location_type:'start'})});
    if(!res.ok) throw new Error('HTTP '+res.status);
    const gj=await res.json();
    if(!S.sim) return; // la quitaron mientras calculaba
    const areas={};
    (gj.features||[]).sort((x,y)=>y.properties.value-x.properties.value).forEach(f=>{
      const min=Math.round(f.properties.value/60);
      if(!TIERS.includes(min)) return;
      areas[min]=areaGeomKm2(f.geometry);
      const capa=L.geoJSON(f,{style:{color:TIER_COLOR[min],weight:2.2,dashArray:'7,6',opacity:.95,
        fillColor:TIER_COLOR[min],fillOpacity:.14}})
        .bindTooltip(tr('sim.tooltip',{t:min}),{sticky:true}).addTo(map);
      S.sim.capas.push(capa);
    });
    caja.innerHTML=`<div class="pr-head"><b>${tr('sim.name')}${fCom?` · ${fCom.properties.Comuna}`:''}</b>
        <button id="simQuitar">${tr('pr.remove')}</button></div>
      <div class="veredicto" style="background:${SIM_COLOR}">${tr('sim.ready')}</div>
      ${[30,45,60].map(t=>areas[t]!=null?`<div class="hosp-item">
        <span style="width:11px;height:11px;border-radius:50%;background:${TIER_COLOR[t]};flex:none"></span>
        <span class="km">≤ ${t} min</span>
        <span class="nm">${tr('sim.cover',{v:fmt(areas[t],0)})}</span></div>`:'').join('')}
      <p class="hint" style="margin:8px 0 0">${tr('sim.tempNote')}</p>
      <div class="punto-btns" style="margin-top:9px">
        <button class="pbtn" id="simReubicar">${tr('sim.relocate')}</button>
        <button class="pbtn" id="simQuitar2">${tr('sim.removeSim')}</button>
      </div>`;
    $('simQuitar').onclick=quitarSim;
    $('simQuitar2').onclick=quitarSim;
    $('simReubicar').onclick=armarSim;
  }catch(err){
    if(!S.sim) return;
    caja.innerHTML=`<div class="pr-head"><b>${tr('sim.name')}</b><button id="simQuitar">${tr('pr.remove')}</button></div>
      <div class="veredicto" style="background:#C8102E">${tr('sim.err')}</div>
      <div class="punto-btns"><button class="pbtn" id="simReintentar">${tr('sim.retry')}</button>
      <button class="pbtn" id="simQuitar2">${tr('pr.remove')}</button></div>`;
    $('simQuitar').onclick=quitarSim; $('simQuitar2').onclick=quitarSim;
    $('simReintentar').onclick=()=>colocarSim(lat,lon);
  }
}
function quitarSim(){
  if(S.sim){
    map.removeLayer(S.sim.marker);
    S.sim.capas.forEach(c=>map.removeLayer(c));
    S.sim=null;
  }
  $('leySim').hidden=true;
  const caja=$('simRes'); caja.classList.remove('on'); caja.innerHTML='';
}

/* =====================================================================
   Ayudas: bienvenida, modal, popovers “?”
===================================================================== */
function wireAyudas(){
  const bienv=$('veloBienv'), ayuda=$('veloAyuda');
  if(!localStorage.getItem('acv_bienv')) bienv.classList.add('on');
  $('btnEmpezar').onclick=()=>{ if($('chkNoMostrar').checked) localStorage.setItem('acv_bienv','1');
    bienv.classList.remove('on'); };
  $('btnGuia').onclick=()=>bienv.classList.add('on');
  const abrirAyuda=()=>{ $('inpKey').value=localStorage.getItem('acv_key')||''; ayuda.classList.add('on'); };
  $('btnAyuda').onclick=abrirAyuda;
  $('linkAyudaFoot').onclick=ev=>{ev.preventDefault();abrirAyuda();};
  $('ayudaCerrar').onclick=()=>ayuda.classList.remove('on');
  [bienv,ayuda].forEach(v=>v.addEventListener('click',ev=>{ if(ev.target===v) v.classList.remove('on'); }));
  document.addEventListener('keydown',ev=>{ if(ev.key==='Escape'){bienv.classList.remove('on');ayuda.classList.remove('on');$('popQ').classList.remove('on');
    if(S.puntoModo) activarPunto();
    if(S.simModo) desarmarSim(); } });
  $('inpKey').addEventListener('change',ev=>localStorage.setItem('acv_key',ev.target.value.trim()));
  $('btnCSV').onclick=ev=>{ ev.preventDefault(); descargarCSV(); };
  $('btnExpIso').onclick=ev=>{ ev.preventDefault(); descargarIsocronas(); };

  const pop=$('popQ');
  document.querySelectorAll('.q').forEach(q=>{
    q.addEventListener('click',ev=>{
      ev.stopPropagation();
      if(pop.classList.contains('on') && pop._src===q){ pop.classList.remove('on'); return; }
      pop.textContent=tr(q.dataset.qk); pop._src=q;
      const r=q.getBoundingClientRect();
      pop.style.left=Math.max(10,Math.min(window.innerWidth-290,r.left-22))+'px';
      pop.style.top=(r.bottom+10)+'px';
      pop.classList.add('on');
    });
  });
  document.addEventListener('click',()=>pop.classList.remove('on'));
}
function descargarIsocronas(){
  const faltan=ESTS.length-Object.keys(S.iso).length;
  if(faltan>0){
    aviso(tr('exp.missing',{n:faltan}),{error:true,ocultarEn:7000});
    return;
  }
  const contenido='// Coberturas precalculadas (93 establecimientos x 30/45/60 min).\n'+
    '// Generado desde la app · método: OpenRouteService driving-car (tesis I. Guajardo, DIINF-USACH).\n'+
    'window.ISOCRONAS='+JSON.stringify(S.iso)+';';
  const blob=new Blob([contenido],{type:'text/javascript;charset=utf-8'});
  const a=document.createElement('a');a.href=URL.createObjectURL(blob);
  a.download='isocronas.js';a.click();
  setTimeout(()=>URL.revokeObjectURL(a.href),1500);
  aviso(tr('exp.done'),{ocultarEn:9000});
}
function descargarCSV(){
  const filas=[['codigo','nombre','comuna','provincia','region','lat','lon'].join(',')];
  ESTS.forEach(e=>filas.push([e.id??'',`"${e.name.replace(/"/g,'""')}"`,`"${e.comuna}"`,
    `"${e.provincia}"`,`"${e.region}"`,e.lat,e.lon].join(',')));
  const blob=new Blob(['\ufeff'+filas.join('\n')],{type:'text/csv;charset=utf-8'});
  const a=document.createElement('a');a.href=URL.createObjectURL(blob);
  a.download='establecimientos_acv_chile.csv';a.click();
  setTimeout(()=>URL.revokeObjectURL(a.href),1500);
}

/* =====================================================================
   Eventos y arranque
===================================================================== */
function sinTiemposActivos(){ return !TIERS.some(t=>S.activos[t]); }

function setModo(hosp){
  $('modoHosp').classList.toggle('on',hosp);  $('modoHosp').setAttribute('aria-pressed',hosp);
  $('modoTerr').classList.toggle('on',!hosp); $('modoTerr').setAttribute('aria-pressed',!hosp);
  $('modoHospBox').hidden=!hosp; $('modoTerrBox').hidden=hosp;
  if(hosp){
    if(S.region||S.comuna){
      S.region=''; S.comuna='';
      $('selRegion').value=''; $('selComuna').disabled=true;
      $('selComuna').innerHTML=`<option value="">${tr('p1.comunaFirst')}</option>`;
    }
    setTimeout(()=>$('inpHosp').focus(),60);
  }else{
    if(S.filtroHosp.size){ S.filtroHosp.clear(); renderHospChips(); }
    $('hospSug').hidden=true;
  }
  deseleccionarHospital(); limpiarPunto();
  refrescarVisibles(); actualizarCobertura(); actualizarReset();
  if(!S.region && !S.comuna && !S.filtroHosp.size) map.flyToBounds(CHILE_BOUNDS,{duration:.7});
}
function actualizarReset(){
  $('btnReset').classList.toggle('on', !!(S.region||S.comuna||S.filtroHosp.size));
}

function wire(){
  $('modoTerr').onclick=()=>setModo(false);
  $('modoHosp').onclick=()=>setModo(true);
  $('selRegion').addEventListener('change',ev=>irARegion(ev.target.value));
  $('selComuna').addEventListener('change',ev=>irAComuna(ev.target.value));
  $('btnReset').onclick=()=>{
    $('selRegion').value='';
    if(S.filtroHosp.size){ S.filtroHosp.clear(); renderHospChips(); }
    irARegion('');
  };
  TIERS.forEach(t=>$('t'+t).addEventListener('click',()=>alternarTier(t)));
  $('leyenda').querySelector('h4').addEventListener('click',()=>$('leyenda').classList.toggle('abierta'));
  $('btnPunto').onclick=activarPunto;
  $('btnGPS').onclick=usarGPS;
  $('inpHosp').addEventListener('input',ev=>renderHospSug(ev.target.value));
  $('inpHosp').addEventListener('focus',ev=>renderHospSug(ev.target.value));
  document.addEventListener('click',ev=>{ if(!ev.target.closest('.hosp-box')) $('hospSug').hidden=true; });
  $('btnSim').onclick=()=>{ if(S.simModo) desarmarSim(); else armarSim(); };
  $('inpDir').addEventListener('input',ev=>buscarDireccion(ev.target.value));
  $('inpDir').addEventListener('keydown',ev=>{
    if(ev.key==='Enter'){ const b=$('dirSug').querySelector('button[data-i]'); if(b) b.click(); }
  });
  document.addEventListener('click',ev=>{ if(!ev.target.closest('.dir-box')) $('dirSug').hidden=true; });
}

/* =====================================================================
   i18n: banderitas del header y re-render en vivo al cambiar idioma
===================================================================== */
function wireIdioma(){
  document.querySelectorAll('.lang-btn').forEach(b=>{
    b.addEventListener('click',()=>window.I18N.setLang(b.dataset.lang));
  });
  window.I18N.applyStatic();   // traduce el HTML estático al idioma detectado
  window.I18N.syncSwitcher();
  window.I18N.onChange(()=>{
    /* re-render de todo lo dinámico conservando la selección actual */
    poblarRegiones();
    if(S.region){ const v=$('selComuna').value; poblarComunas(S.region); $('selComuna').value=v; }
    renderHospChips();
    if($('inpHosp')===document.activeElement) renderHospSug($('inpHosp').value);
    actualizarCobertura();
    refrescarVeredictoPendiente();
    /* si hay una simulación en curso, se recalcula su tarjeta reubicándola */
    if(S.sim){ const {lat,lon}=S.sim; quitarSim(); colocarSim(lat,lon); }
  });
}

wireIdioma();
calcularNacional();
initMap();
poblarRegiones();
wire();
wireAyudas();
actualizarCobertura();
cargarCoberturaNacional();
