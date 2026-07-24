/* ============================================================
   INIT v3 — coords, alias, eventos, slider, exportación
   ============================================================ */
window.COUNTRY_COORDS = {"Afghanistan": [33.9391, 67.71], "Albania": [41.1533, 20.1683], "Algeria": [28.0339, 1.6596], "Andorra": [42.5063, 1.5218], "Angola": [-11.2027, 17.8739], "Antigua and Barbuda": [17.0608, -61.7964], "Argentina": [-38.4161, -63.6167], "Armenia": [40.0691, 45.0382], "Australia": [-25.2744, 133.7751], "Austria": [47.5162, 14.5501], "Azerbaijan": [40.1431, 47.5769], "Bahamas": [25.0343, -77.3963], "Bahrain": [26.0667, 50.55], "Bangladesh": [23.685, 90.3563], "Barbados": [13.1939, -59.5432], "Belarus": [53.7098, 27.9534], "Belgium": [50.5039, 4.4699], "Belize": [17.1899, -88.4976], "Benin": [9.3077, 2.3158], "Bhutan": [27.5142, 90.4336], "Bolivia": [-16.2902, -63.5887], "Bosnia and Herzegovina": [43.9159, 17.6791], "Botswana": [-22.3285, 24.6849], "Brazil": [-14.235, -51.9253], "Brunei": [4.5353, 114.7277], "Bulgaria": [42.7339, 25.4858], "Burkina Faso": [12.2383, -1.5616], "Burundi": [-3.3731, 29.9189], "Cabo Verde": [16.002, -24.0131], "Cambodia": [12.5657, 104.991], "Cameroon": [7.54, 11.5021], "Canada": [56.1304, -106.3468], "Central African Republic": [6.6111, 20.9394], "Chad": [15.4542, 18.7322], "Chile": [-35.6751, -71.543], "China": [35.8617, 104.1954], "Colombia": [4.5709, -74.2973], "Comoros": [-11.6455, 43.3333], "Congo": [-0.228, 15.8277], "Costa Rica": [9.7489, -83.7534], "Croatia": [45.1, 15.2], "Cuba": [21.5218, -77.7812], "Cyprus": [35.1264, 33.4299], "Czech Republic": [49.8175, 14.475], "Denmark": [56.2639, 9.5018], "Djibouti": [11.8251, 42.5903], "Dominica": [15.415, -61.371], "Dominican Republic": [18.7357, -70.1627], "Ecuador": [-1.8312, -78.1834], "Egypt": [26.8206, 30.8025], "El Salvador": [13.7942, -88.8965], "Equatorial Guinea": [1.6508, 10.2679], "Eritrea": [15.1794, 39.7823], "Estonia": [58.5953, 25.0136], "Eswatini": [-26.5225, 31.4659], "Ethiopia": [9.145, 40.4897], "Fiji": [-17.7134, 179.4144], "Finland": [61.9241, 25.7482], "France": [46.2276, 2.2137], "Gabon": [-0.8037, 11.6094], "Gambia": [13.4432, -15.3101], "Georgia": [42.3154, 43.4836], "Germany": [51.1657, 10.4515], "Ghana": [7.9465, -1.0232], "Greece": [39.0742, 21.8243], "Grenada": [12.1165, -61.679], "Guatemala": [15.7835, -90.2308], "Guinea": [9.9456, -9.6966], "Guinea-Bissau": [11.8037, -15.1804], "Guyana": [4.8604, -58.9302], "Haiti": [18.9712, -72.2852], "Honduras": [15.1994, -86.2419], "Hungary": [47.1625, 19.5033], "Iceland": [64.9631, -19.0208], "India": [20.5937, 78.9629], "Indonesia": [-0.7893, 113.9213], "Iran": [32.4279, 53.688], "Iraq": [33.2232, 43.6793], "Ireland": [53.4129, -8.2439], "Israel": [31.0461, 34.8516], "Italy": [41.8719, 12.5674], "Jamaica": [18.1096, -77.2975], "Japan": [36.2048, 138.2529], "Jordan": [30.5852, 36.2384], "Kazakhstan": [48.0196, 66.9237], "Kenya": [0.0236, 37.9062], "Kiribati": [1.3733, 167.7358], "Kuwait": [29.3117, 47.4818], "Kyrgyzstan": [42.856, 74.7661], "Laos": [19.8563, 102.4955], "Latvia": [56.8796, 24.6032], "Lebanon": [33.8547, 35.8623], "Lesotho": [-29.61, 28.2336], "Liberia": [6.4281, -9.4295], "Libya": [26.3351, 17.2283], "Liechtenstein": [47.166, 9.5554], "Lithuania": [55.1694, 23.8813], "Luxembourg": [49.8153, 6.1296], "Madagascar": [-18.7669, 46.8273], "Malawi": [-13.2543, 34.3015], "Malaysia": [4.2105, 101.9758], "Maldives": [3.2028, 73.5361], "Mali": [17.5707, -4.0383], "Malta": [35.9375, 14.3754], "Marshall Islands": [7.1315, 167.5433], "Mauritania": [21.0079, -10.9408], "Mauritius": [-20.3484, 57.5522], "Mexico": [23.6345, -102.5528], "Micronesia": [6.9118, 138.1525], "Moldova": [47.4116, 28.3699], "Monaco": [43.7384, 7.4128], "Mongolia": [46.8625, 103.8467], "Montenegro": [42.7087, 19.3744], "Morocco": [31.7917, -7.0926], "Mozambique": [-18.6657, 35.5296], "Myanmar": [21.9162, 95.956], "Namibia": [-22.9576, 18.4904], "Nauru": [-0.5228, 166.9315], "Nepal": [28.3949, 84.124], "Netherlands": [52.1326, 5.2913], "New Zealand": [-40.9006, 174.886], "Nicaragua": [12.8654, -85.2072], "Niger": [17.6078, 8.0817], "Nigeria": [9.082, 8.6753], "North Korea": [40.3399, 127.5101], "North Macedonia": [41.6086, 21.7453], "Norway": [60.472, 8.4689], "Oman": [21.5125, 55.9233], "Pakistan": [30.3753, 69.3451], "Palau": [7.515, 134.5825], "Panama": [8.538, -80.7821], "Papua New Guinea": [-6.315, 143.9555], "Paraguay": [-23.4425, -58.4438], "Peru": [-9.19, -75.0152], "Philippines": [12.8797, 121.774], "Poland": [51.9194, 19.1451], "Portugal": [39.3999, -8.2245], "Qatar": [25.3548, 51.1839], "Romania": [45.9432, 24.9668], "Russia": [61.524, 105.3188], "Rwanda": [-1.9403, 29.8739], "Saint Kitts and Nevis": [17.3578, -62.7177], "Saint Lucia": [13.9094, -60.9789], "Saint Vincent and the Grenadines": [12.9849, -61.2225], "Samoa": [-13.759, -172.1046], "San Marino": [43.9424, 12.4578], "Sao Tome and Principe": [0.1864, 6.7335], "Saudi Arabia": [23.8859, 45.0792], "Senegal": [14.4974, -14.4524], "Serbia": [44.0165, 20.4489], "Seychelles": [-4.6796, 55.492], "Sierra Leone": [8.4606, -11.7799], "Singapore": [1.3521, 103.8198], "Slovakia": [48.669, 19.699], "Slovenia": [46.1512, 14.9955], "Solomon Islands": [-9.6457, 160.1562], "Somalia": [5.1521, 46.1996], "South Africa": [-30.5595, 22.9375], "South Korea": [35.9078, 127.7669], "South Sudan": [6.877, 31.307], "Spain": [40.4637, -3.7492], "Sri Lanka": [7.8731, 80.7718], "Sudan": [12.8628, 30.2176], "Suriname": [3.9193, -56.0278], "Sweden": [60.1282, 18.6435], "Switzerland": [46.8182, 8.2275], "Syria": [34.8021, 38.9968], "Taiwan": [23.6978, 120.9605], "Tajikistan": [38.861, 71.2271], "Tanzania": [-6.369, 34.8888], "Thailand": [15.87, 100.9925], "Timor-Leste": [8.8742, 125.7275], "Togo": [8.6195, 0.8248], "Tonga": [-20.5353, -175.1982], "Trinidad and Tobago": [10.6918, -61.2225], "Tunisia": [33.8869, 9.5375], "Turkey": [38.9637, 35.2433], "Turkmenistan": [38.9697, 59.5563], "Tuvalu": [-8.5099, 177.6493], "Uganda": [1.3733, 32.2903], "Ukraine": [48.3794, 31.1656], "United Arab Emirates": [23.4241, 53.8478], "United Kingdom": [55.3781, -3.436], "USA": [37.0902, -95.7129], "United States": [37.0902, -95.7129], "Uruguay": [-32.5228, -55.7658], "Uzbekistan": [41.3775, 64.5853], "Vanuatu": [-15.3767, 166.9592], "Venezuela": [6.4238, -66.5897], "Vietnam": [14.0583, 105.811], "Yemen": [15.5527, 48.5164], "Zambia": [-13.1339, 28.2025], "Zimbabwe": [-19.0154, 29.1549]};
window.COUNTRY_ALIAS = {"Czechia": [49.8175, 14.475], "Hong Kong SAR China": [22.3193, 114.1694], "Russian Federation": [61.524, 105.3188], "Viet Nam": [14.0583, 105.811], "Korea": [35.9078, 127.7669], "Republic of Korea": [35.9078, 127.7669], "UK": [55.3781, -3.436], "U.S.A.": [37.0902, -95.7129], "Türkiye": [38.9637, 35.2433]};

let DEB=null;
function rebuild(spin){ if(spin) ov('Actualizando','Recalculando…'); clearTimeout(DEB);
  DEB=setTimeout(()=>{ try{ rebuildTab(); }catch(e){ console.error(e); } ovHide(); }, 220); }
function rebuildTab(){
  if(S.tab==='resumen') buildResumen();
  else if(S.tab==='indicadores') buildIndicadores();
  else if(S.tab==='perfiles') buildPerfiles();
  else if(S.tab==='analitica') buildAnalitica();
  else if(S.tab==='dominio'){ buildDomPalabras(); buildDominio(); }
  else if(S.tab==='asistente') buildChat();
  if (typeof applyFriendlyTooltips === 'function') applyFriendlyTooltips();
  if (typeof i18nDynamic === 'function') i18nDynamic(document.body);
}

/* ---------- filtros ---------- */
function initFilters(){
  const unis=uniq(DATA.map(r=>r.UNIVERSIDAD)).sort();
  document.getElementById('f_uni').innerHTML=unis.map(u=>`<option>${u}</option>`).join('');
  S.uni=unis[0]; populateSec(); initSlider();
}
function populateSec(){
  const secs=uniq(DATA.filter(r=>r.UNIVERSIDAD===S.uni).map(r=>r.SESION)).sort();
  const el=document.getElementById('f_sec');
  el.innerHTML=secs.map(s=>`<option>${s}</option>`).join('');
  S.sec=secs.includes(S.sec)?S.sec:secs[0]; el.value=S.sec;
}
function initSlider(){
  const rows=DATA.filter(r=>r.UNIVERSIDAD===S.uni&&r.SESION===S.sec);
  const ys=rows.map(r=>int0(r.ANO)).filter(y=>y>1900);
  const lo=ys.length?Math.min(...ys):1990, hi=ys.length?Math.max(...ys):2025;
  const mn=document.getElementById('y_min'), mx=document.getElementById('y_max');
  mn.min=mx.min=lo; mn.max=mx.max=hi;
  S.yMin=Math.max(lo,hi-5); S.yMax=hi; mn.value=S.yMin; mx.value=S.yMax;
  syncSlider();
}
function syncSlider(){
  const mn=document.getElementById('y_min'), mx=document.getElementById('y_max');
  document.getElementById('y_lo').textContent=S.yMin;
  document.getElementById('y_hi').textContent=S.yMax;
  const lo=+mn.min, hi=+mn.max, span=hi-lo||1;
  const a=(S.yMin-lo)/span*100, b=(S.yMax-lo)/span*100;
  const fill=document.getElementById('y_fill');
  fill.style.left=a+'%'; fill.style.width=(b-a)+'%';
}

/* ---------- selector autor ---------- */
function refreshAutor(){
  const box=document.getElementById('perf_autor_box');
  const wrap=document.getElementById('perf_autor_wrap');
  if(S.perfSel==='Institucionales'){ box.style.display='none'; return; }
  box.style.display='';
  const autores=uniq(base().map(r=>r.NOMBRE_AUTOR)).sort();
  if(!S.perfAutor||!autores.includes(S.perfAutor)) S.perfAutor=autores[0]||null;
  wrap.innerHTML=`<div class="sel" style="min-width:260px;"><select id="perf_autor_sel">${autores.map(a=>`<option value="${a}" ${a===S.perfAutor?'selected':''}>${titleCase(a)}</option>`).join('')}</select></div>`;
  document.getElementById('perf_autor_sel').onchange=e=>{ S.perfAutor=e.target.value; rebuild(true); };
}

/* ---------- segmented control helper ---------- */
function wireSeg(id, cb){
  document.querySelectorAll(`#${id} button`).forEach(b=>{
    b.onclick=()=>{ document.querySelectorAll(`#${id} button`).forEach(x=>x.classList.remove('on'));
      b.classList.add('on'); cb(b.dataset.v); };
  });
}

/* ---------- eventos ---------- */
function wire(){
  document.querySelectorAll('#lang_switch button').forEach(btn => {
    btn.onclick = () => setLanguage(btn.dataset.lang);
  });
  document.getElementById('f_uni').onchange=e=>{ S.uni=e.target.value; populateSec(); initSlider(); refreshAutor(); rebuild(true); };
  document.getElementById('f_sec').onchange=e=>{ S.sec=e.target.value; initSlider(); refreshAutor(); rebuild(true); };
  const mn=document.getElementById('y_min'), mx=document.getElementById('y_max');
  const onY=()=>{ let a=int0(mn.value), b=int0(mx.value); if(a>b)[a,b]=[b,a];
    S.yMin=a; S.yMax=b; mn.value=a; mx.value=b; syncSlider(); refreshAutor(); rebuild(true); };
  mn.oninput=mx.oninput=onY;

  document.querySelectorAll('#tabs button').forEach(btn=>{
    btn.onclick=()=>{ document.querySelectorAll('#tabs button').forEach(b=>b.classList.remove('active'));
      document.querySelectorAll('.panel').forEach(p=>p.classList.remove('active'));
      btn.classList.add('active'); S.tab=btn.dataset.tab;
      document.getElementById('p-'+S.tab).classList.add('active');
      ov('Cargando','Preparando la vista…'); setTimeout(()=>{ try{ rebuildTab(); }catch(e){ console.error(e); } ovHide(); }, 70);
    };
  });

  wireSeg('ind_nivel', v=>{ S.indNivel=v; rebuild(true); });
  wireSeg('ind_index', v=>{ S.indIndex=v; rebuild(true); });
  wireSeg('perf_sel', v=>{ S.perfSel=v; refreshAutor(); rebuild(true); });
  wireSeg('perf_index', v=>{ S.perfIndex=v; rebuild(true); });
  wireSeg('chat_index', v=>{ S.chatIndex=v; buildChat(true); if (typeof applyFriendlyTooltips === 'function') applyFriendlyTooltips(); });

  document.getElementById('dom_doc').onchange=e=>{ S.domDoc=e.target.value; rebuild(true); };
  document.getElementById('dom_dom').onchange=e=>{ S.domDom=e.target.value; S.domPalabra=null; rebuild(true); };
  document.getElementById('dom_palabra').onchange=e=>{ S.domPalabra=e.target.value; buildDominio(); };
}

/* ---------- descargas ---------- */
function descargarBaseDatos(){
  // Pide la clave antes de entregar la base completa (ver app_clave.js)
  pedirClave(() => {
    const blob=new Blob([window.PAPERS_CSV],{type:'text/csv;charset=utf-8'});
    const u=URL.createObjectURL(blob); const a=document.createElement('a');
    a.href=u; a.download='Base_Datos_'+new Date().toISOString().slice(0,10)+'.csv'; a.click(); URL.revokeObjectURL(u);
  });
}

/* ===== INFORME ACADÉMICO AUTÓNOMO ===== */
function nombreArchivo(tab){
  const sc=reportScope(tab);
  const slug = (sc.esAutor?sc.titulo:tab).normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9]+/g,'_').replace(/^_|_$/g,'');
  return `Informe_${slug}_${new Date().toISOString().slice(0,10)}`;
}

function exportarInforme(tab){           // HTML
  ov('Generando informe','Componiendo el documento…');
  setTimeout(()=>{
    try{
      const html = construirInforme(tab);
      const blob=new Blob([html],{type:'text/html;charset=utf-8'}); const u=URL.createObjectURL(blob);
      const a=document.createElement('a'); a.href=u; a.download=nombreArchivo(tab)+'.html'; a.click(); URL.revokeObjectURL(u);
    }catch(e){ console.error(e); alert('No se pudo generar el informe.'); }
    ovHide();
  },120);
}

function csvEscape(v){
  const s = String(v ?? '');
  return /[",\n;]/.test(s) ? `"${s.replace(/"/g,'""')}"` : s;
}
function rowsToCSV(rows){
  const headers = HEADERS && HEADERS.length ? HEADERS : Object.keys(rows[0] || {});
  return [headers.join(';')].concat(rows.map(r => headers.map(h => csvEscape(r[h])).join(';'))).join('\n');
}
function exportarInformeCSV(tab){
  try{
    const sc = reportScope(tab);
    const csv = rowsToCSV(sc.d);
    const blob = new Blob([csv], { type:'text/csv;charset=utf-8' });
    const u = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = u;
    a.download = nombreArchivo(tab) + '.csv';
    a.click();
    URL.revokeObjectURL(u);
  }catch(e){ console.error(e); alert('No se pudo generar el CSV.'); }
}

/* Determina el conjunto de datos y el encabezado según la pestaña y el contexto */
function reportScope(tab){
  // Perfiles por autor => datos del autor; resto => institucional
  if(tab==='Perfiles' && S.perfSel!=='Institucionales' && S.perfAutor){
    const d = byIndex(base(), S.perfIndex).filter(r=>r.NOMBRE_AUTOR===S.perfAutor);
    return { d, titulo:titleCase(S.perfAutor), subtitulo:`${S.sec} · ${S.uni}`, esAutor:true,
             idx:(S.perfIndex==='Todas'?'WoS + Scopus':S.perfIndex),
             foto:(d[0]||{}).URL_FOTO_ACADEMICO || '', tipoFoto:rpt('academic') };
  }
  const idxSel = (tab==='Indicadores') ? S.indIndex : 'Todas';
  const d = byIndex(base(), idxSel);
  return { d, titulo:S.sec, subtitulo:S.uni, esAutor:false,
           idx:(idxSel==='Todas'?'WoS + Scopus':idxSel),
           foto:(d[0]||{}).URL_FOTO_DEPARTAMENTO || '', tipoFoto:rpt('unit') };
}

const RPT = {
  es: {
    individual:'Informe individual', report:'Informe', academic:'Académico(a)', unit:'Unidad académica',
    indicator:'Indicador', acronym:'Sigla', value:'Valor', publications:'Publicaciones', citations:'Citas', hIndex:'Índice h',
    title:'Título', year:'Año', source:'Fuente', journal:'Revista', rank:'#', author:'Académico(a)', coauthor:'Coautor(a)', type:'Tipo', shared:'Publicaciones compartidas',
    noSjr:'Sin datos de SJR.', noData:'Sin datos disponibles.', noCoauthors:'Sin coautorías registradas.', noPubs:'No hay publicaciones para el filtro seleccionado.',
    summary:'Síntesis', topCitedPub:'Publicación con más citas', topSjrPub:'Publicación de mayor impacto (SJR)', totalCitations:'Citas totales',
    q1:'Revistas Q1', countries:'Países', academics:'Académicos(as)', coauthors:'Coautores(as)', wosScopus:'WoS + Scopus',
    lead:(ctx)=>`Durante el periodo <b>${ctx.yMin}–${ctx.yMax}</b>, ${ctx.subject} <b>${ctx.total}</b> publicaciones${ctx.who}, acumulando <b>${ctx.cites}</b> citas y un índice h de <b>${ctx.h}</b>. El ${ctx.wosPct}% corresponde a Web of Science y el ${ctx.artPct}% a publicaciones en revistas. El reporte respeta el filtro activo de universidad, unidad, periodo e indexación.`,
    unitSubject:'la unidad registra', authorSubject:(name)=>`<b>${name}</b> registra`, academicsOf:(n)=>` de <b>${n}</b> académicos(as)`,
    impactPubs:'Publicaciones con mayor impacto', top5Cited:'Top 5 más citadas', top5Sjr:'Top 5 de mayor impacto por SJR',
    perf:'Indicadores de rendimiento', colab:'Indicadores de colaboración', evolution:'Evolución temporal', quartile:'Distribución por cuartil',
    thematic:'Líneas temáticas', appAreas:'Áreas de aplicación', mainCoauthors:'Principales coautores(as)', frequentCoauthors:'Coautores(as) frecuentes',
    keywords:'Palabras clave', dominantKeywords:'Palabras clave dominantes', productiveAcademics:'Académicos(as) más productivos(as)', specialty:'Áreas de especialidad',
    generated:'Generado por el Analizador Bibliométrico · Manuel Villalobos Cid', internal:'Unidad', external:'Externo(a)'
  },
  en: {
    individual:'Individual report', report:'Report', academic:'Academic', unit:'Academic unit',
    indicator:'Indicator', acronym:'Acronym', value:'Value', publications:'Publications', citations:'Citations', hIndex:'h-index',
    title:'Title', year:'Year', source:'Source', journal:'Journal', rank:'#', author:'Academic', coauthor:'Coauthor', type:'Type', shared:'Shared publications',
    noSjr:'No SJR data.', noData:'No available data.', noCoauthors:'No coauthorships recorded.', noPubs:'No publications for the selected filter.',
    summary:'Summary', topCitedPub:'Most cited publication', topSjrPub:'Highest impact publication (SJR)', totalCitations:'Total citations',
    q1:'Q1 journals', countries:'Countries', academics:'Academics', coauthors:'Coauthors', wosScopus:'WoS + Scopus',
    lead:(ctx)=>`During <b>${ctx.yMin}–${ctx.yMax}</b>, ${ctx.subject} <b>${ctx.total}</b> publications${ctx.who}, with <b>${ctx.cites}</b> citations and an h-index of <b>${ctx.h}</b>. ${ctx.wosPct}% corresponds to Web of Science and ${ctx.artPct}% to journal publications. The report respects the active university, unit, period, and indexing filters.`,
    unitSubject:'the unit records', authorSubject:(name)=>`<b>${name}</b> records`, academicsOf:(n)=>` from <b>${n}</b> academics`,
    impactPubs:'Highest impact publications', top5Cited:'Top 5 most cited', top5Sjr:'Top 5 by SJR impact',
    perf:'Performance indicators', colab:'Collaboration indicators', evolution:'Time evolution', quartile:'Quartile distribution',
    thematic:'Thematic lines', appAreas:'Application areas', mainCoauthors:'Main coauthors', frequentCoauthors:'Frequent coauthors',
    keywords:'Keywords', dominantKeywords:'Dominant keywords', productiveAcademics:'Most productive academics', specialty:'Specialty areas',
    generated:'Generated by the Bibliometric Analyzer · Manuel Villalobos Cid', internal:'Unit', external:'External'
  },
  pt: {
    individual:'Relatório individual', report:'Relatório', academic:'Acadêmico(a)', unit:'Unidade acadêmica',
    indicator:'Indicador', acronym:'Sigla', value:'Valor', publications:'Publicações', citations:'Citações', hIndex:'Índice h',
    title:'Título', year:'Ano', source:'Fonte', journal:'Revista', rank:'#', author:'Acadêmico(a)', coauthor:'Coautor(a)', type:'Tipo', shared:'Publicações compartilhadas',
    noSjr:'Sem dados de SJR.', noData:'Sem dados disponíveis.', noCoauthors:'Sem coautorias registradas.', noPubs:'Não há publicações para o filtro selecionado.',
    summary:'Síntese', topCitedPub:'Publicação com mais citações', topSjrPub:'Publicação de maior impacto (SJR)', totalCitations:'Citações totais',
    q1:'Revistas Q1', countries:'Países', academics:'Acadêmicos(as)', coauthors:'Coautores(as)', wosScopus:'WoS + Scopus',
    lead:(ctx)=>`Durante o período <b>${ctx.yMin}–${ctx.yMax}</b>, ${ctx.subject} <b>${ctx.total}</b> publicações${ctx.who}, acumulando <b>${ctx.cites}</b> citações e índice h de <b>${ctx.h}</b>. ${ctx.wosPct}% corresponde à Web of Science e ${ctx.artPct}% a publicações em revistas. O relatório respeita os filtros ativos de universidade, unidade, período e indexação.`,
    unitSubject:'a unidade registra', authorSubject:(name)=>`<b>${name}</b> registra`, academicsOf:(n)=>` de <b>${n}</b> acadêmicos(as)`,
    impactPubs:'Publicações com maior impacto', top5Cited:'Top 5 mais citadas', top5Sjr:'Top 5 de maior impacto por SJR',
    perf:'Indicadores de desempenho', colab:'Indicadores de colaboração', evolution:'Evolução temporal', quartile:'Distribuição por quartil',
    thematic:'Linhas temáticas', appAreas:'Áreas de aplicação', mainCoauthors:'Principais coautores(as)', frequentCoauthors:'Coautores(as) frequentes',
    keywords:'Palavras-chave', dominantKeywords:'Palavras-chave dominantes', productiveAcademics:'Acadêmicos(as) mais produtivos(as)', specialty:'Áreas de especialidade',
    generated:'Gerado pelo Analisador Bibliométrico · Manuel Villalobos Cid', internal:'Unidade', external:'Externo(a)'
  }
};
function rpt(key){
  const lang = RPT[S.lang] ? S.lang : 'es';
  return (RPT[lang] && RPT[lang][key]) || RPT.es[key] || key;
}
function rptDate(d){
  const loc = S.lang === 'en' ? 'en-US' : S.lang === 'pt' ? 'pt-BR' : 'es-CL';
  return d.toLocaleDateString(loc,{year:'numeric',month:'long',day:'numeric'});
}
function rptTab(tab){
  const keys = { Resumen:'tab.summary', Indicadores:'tab.indicators', Perfiles:'tab.profiles', 'Analítica':'tab.analytics', Dominio:'tab.domain' };
  return keys[tab] && typeof tr === 'function' ? tr(keys[tab]) : tab;
}

function tablaIndicadoresHTML(d){
  const r = indInst(d);
  const fila = o=>`<tr><td class="r-ind">${o.Indicador}</td><td class="r-sig">${o.Sigla}</td><td class="r-val">${o.Valor}</td></tr>`;
  const head = `<thead><tr><th>${rpt('indicator')}</th><th>${rpt('acronym')}</th><th>${rpt('value')}</th></tr></thead>`;
  return {
    rend:`<table class="r-table">${head}<tbody>${r.rend.map(fila).join('')}</tbody></table>`,
    colab:`<table class="r-table">${head}<tbody>${r.colab.map(fila).join('')}</tbody></table>`
  };
}

function rankingAutoresHTML(d){
  const acs = uniq(d.map(x=>x.NOMBRE_AUTOR));
  const rows = acs.map(ac=>{ const da=d.filter(x=>x.NOMBRE_AUTOR===ac);
    const TC=da.reduce((s,x)=>s+int0(x.CITADO_POR),0);
    return { ac:titleCase(ac), TP:da.length, TC, h:hIndex(da.map(x=>int0(x.CITADO_POR))) };
  }).sort((a,b)=>b.TP-a.TP).slice(0,15);
  return `<table class="r-table"><thead><tr><th>${rpt('rank')}</th><th>${rpt('author')}</th><th>${rpt('publications')}</th><th>${rpt('citations')}</th><th>${rpt('hIndex')}</th></tr></thead><tbody>${
    rows.map((r,i)=>`<tr><td class="r-rank">${i+1}</td><td class="r-ind">${r.ac}</td><td class="r-val">${r.TP}</td><td class="r-val">${r.TC}</td><td class="r-val">${r.h}</td></tr>`).join('')
  }</tbody></table>`;
}

/* Top 5 más citadas */
function topCitadasHTML(d){
  const rows=[...d].sort((a,b)=>int0(b.CITADO_POR)-int0(a.CITADO_POR)).slice(0,5);
  return `<table class="r-table"><thead><tr><th>${rpt('title')}</th><th>${rpt('year')}</th><th>${rpt('source')}</th><th>${rpt('citations')}</th></tr></thead><tbody>${
    rows.map(r=>`<tr><td class="r-ind">${r.TITULO||'—'}</td><td class="r-val" style="font-weight:500;">${r.ANO||''}</td><td style="font-size:.8rem;color:var(--mut);">${r.FUENTE||''}</td><td class="r-val">${int0(r.CITADO_POR)}</td></tr>`).join('')
  }</tbody></table>`;
}
/* Top 5 mayor impacto (SJR) */
function topImpactoHTML(d){
  const rows=[...d].filter(r=>num(r.SJR)>0).sort((a,b)=>num(b.SJR)-num(a.SJR)).slice(0,5);
  if(!rows.length) return `<p style="color:var(--mut);font-style:italic;">${rpt('noSjr')}</p>`;
  return `<table class="r-table"><thead><tr><th>${rpt('title')}</th><th>${rpt('year')}</th><th>${rpt('journal')}</th><th>SJR</th></tr></thead><tbody>${
    rows.map(r=>`<tr><td class="r-ind">${r.TITULO||'—'}</td><td class="r-val" style="font-weight:500;">${r.ANO||''}</td><td style="font-size:.8rem;color:var(--mut);">${r.FUENTE||''}</td><td class="r-val" style="color:var(--naranja-d,#c4630a);">${nf(num(r.SJR))}</td></tr>`).join('')
  }</tbody></table>`;
}
/* Distribución por cuartil (mini barras) */
function cuartilesHTML(d){
  const arts=d.filter(r=>r.TIPO_DOCUMENTO==='Article');
  const q={Q1:0,Q2:0,Q3:0,Q4:0}; arts.forEach(r=>{const x=String(r.QUARTILE).toUpperCase(); if(q[x]!==undefined)q[x]++;});
  const tot=q.Q1+q.Q2+q.Q3+q.Q4||1; const max=Math.max(q.Q1,q.Q2,q.Q3,q.Q4,1);
  const col={Q1:'var(--usach-teal,#00A499)',Q2:'#55b9b0',Q3:'#9bd3ce',Q4:'#c9e7e4'};
  return `<div class="r-bars">${['Q1','Q2','Q3','Q4'].map(k=>
    `<div class="r-bar-row"><span class="r-bar-lab">${k} <span style="color:var(--faint);font-size:.78rem;">(${nf(q[k]/tot*100)}%)</span></span><span class="r-bar-track"><span class="r-bar-fill" style="width:${q[k]/max*100}%;background:${col[k]};"></span></span><span class="r-bar-val">${q[k]}</span></div>`
  ).join('')}</div>`;
}
/* Evolución temporal de publicaciones (mini barras por año) */
function evolucionHTML(d){
  const yc={}; for(let y=S.yMin;y<=S.yMax;y++) yc[y]=0;
  d.forEach(r=>{const y=int0(r.ANO); if(y>=S.yMin&&y<=S.yMax)yc[y]++;});
  const max=Math.max(1,...Object.values(yc));
  return `<div class="r-bars">${Object.entries(yc).map(([y,v])=>
    `<div class="r-bar-row"><span class="r-bar-lab">${y}</span><span class="r-bar-track"><span class="r-bar-fill" style="width:${v/max*100}%"></span></span><span class="r-bar-val">${v}</span></div>`
  ).join('')}</div>`;
}

function topListHTML(d, field, sep, n, excl){
  let top = kwFold(d, field, 'title');
  if(excl && excl.length){ const ex=new Set(excl.map(e=>String(e).toLowerCase())); top=top.filter(([k])=>!ex.has(String(k).toLowerCase())); }
  top = top.slice(0,n);
  const max=top.length?top[0][1]:1;
  if(!top.length) return `<p style="color:var(--mut);font-style:italic;">${rpt('noData')}</p>`;
  return top.map(([k,v])=>`<div class="r-bar-row"><span class="r-bar-lab">${k}</span><span class="r-bar-track"><span class="r-bar-fill" style="width:${v/max*100}%"></span></span><span class="r-bar-val">${v}</span></div>`).join('');
}

function coautoresReporteHTML(d, sc){
  const instIds = new Set(uniq(base().map(r=>String(r.SCOPUS_ID||'').trim()).filter(Boolean)));
  const selfIds = sc.esAutor ? new Set(d.map(r=>String(r.SCOPUS_ID||'').trim()).filter(Boolean)) : new Set();
  const co = new Map();
  d.forEach(r=>{
    pairAuthors(r).forEach(p=>{
      const id = String(p.id||'').trim();
      const name = String(p.name||id||'').trim();
      if(!id || selfIds.has(id)) return;
      if(!co.has(id)) co.set(id,{name,n:0,interno:instIds.has(id)});
      co.get(id).n++;
    });
  });
  const rows=[...co.values()].sort((a,b)=>b.n-a.n).slice(0,15);
  if(!rows.length) return `<p style="color:var(--mut);font-style:italic;">${rpt('noCoauthors')}</p>`;
  return `<table class="r-table"><thead><tr><th>${rpt('rank')}</th><th>${rpt('coauthor')}</th><th>${rpt('type')}</th><th>${rpt('shared')}</th></tr></thead><tbody>${
    rows.map((r,i)=>`<tr><td class="r-rank">${i+1}</td><td class="r-ind">${titleCase(r.name)}</td><td>${r.interno?rpt('internal'):rpt('external')}</td><td class="r-val">${r.n}</td></tr>`).join('')
  }</tbody></table>`;
}

function analiticaHallazgosHTML(d){
  const years = d.map(r=>int0(r.ANO)).filter(y=>y>1900);
  const maxY = years.length ? Math.max(...years) : S.yMax;
  const recent = d.filter(r=>int0(r.ANO)>=maxY-2).length;
  const prev = d.filter(r=>int0(r.ANO)>=maxY-5 && int0(r.ANO)<=maxY-3).length;
  const growth = prev ? nf((recent-prev)/prev*100)+'%' : (recent ? '+100%' : '0%');
  const q1 = d.filter(r=>String(r.QUARTILE).toUpperCase()==='Q1').length;
  const arts = d.filter(r=>r.TIPO_DOCUMENTO==='Article').length || 1;
  const intl = d.filter(r=>String(r.PAISES_AUTORES||'').split(', ').some(p=>p.trim() && p.trim()!=='Chile')).length;
  const topArea = sortEnt(countBy(d.map(r=>titleCase(stripParen(r.AREA_COMPUTACION||'').trim())).filter(Boolean)))[0] || ['-',0];
  const topCited = [...d].sort((a,b)=>int0(b.CITADO_POR)-int0(a.CITADO_POR))[0];
  const rows = [
    ['Tendencia reciente', `${recent} publicaciones en el último trienio del filtro; variación ${growth} frente al trienio previo.`],
    ['Revistas Q1', `${q1} artículos Q1 (${nf(q1/arts*100)}% sobre artículos).`],
    ['Colaboración internacional', `${intl} publicaciones con al menos un país distinto de Chile.`],
    ['Especialidad dominante', `${topArea[0]} (${topArea[1]} registros).`],
    ['Mayor impacto por citas', topCited ? `${topCited.TITULO} · ${int0(topCited.CITADO_POR)} citas.` : 'Sin publicaciones citadas.']
  ];
  return `<table class="r-table"><thead><tr><th>Hallazgo</th><th>Lectura</th></tr></thead><tbody>${
    rows.map(r=>`<tr><td class="r-ind">${r[0]}</td><td>${r[1]}</td></tr>`).join('')
  }</tbody></table>`;
}

function analiticaContinuidadHTML(d){
  const anchor = S.yMax || Math.max(...d.map(r=>int0(r.ANO)).filter(y=>y>1900));
  const recentStart = anchor - 2;
  const risks = typeof continuityRisks === 'function' ? continuityRisks(d).slice(0,12) : [];
  if(!risks.length) return `<p style="color:var(--mut);">No se detectan académicos(as) del filtro activo sin publicaciones en el trienio ${recentStart}-${anchor}.</p>`;
  return `<p style="color:var(--mut);margin-top:0;">Personas del filtro activo sin publicaciones registradas en el trienio ${recentStart}-${anchor}.</p>
  <table class="r-table"><thead><tr><th>Académico(a)</th><th>Última publicación</th><th>Brecha</th><th>Publicaciones en periodo</th></tr></thead><tbody>${
    risks.map(r=>`<tr><td class="r-ind">${titleCase(r.author)}</td><td>${r.last}</td><td>${r.gap} años</td><td class="r-val">${r.pubs}</td></tr>`).join('')
  }</tbody></table>`;
}

function oportunidadesReporteHTML(d){
  const authors = uniq(d.map(r=>r.NOMBRE_AUTOR).filter(Boolean)).sort();
  const sets = new Map(), coPairs = new Set();
  authors.forEach(a=>{
    const da = d.filter(r=>r.NOMBRE_AUTOR===a);
    const terms = [];
    da.forEach(r=>{
      String(r.INDEX_PALABRAS_CLAVES||'').split(/[;,|]/).forEach(t=>terms.push(chatNorm(t)));
      terms.push(chatNorm(r.AREA_COMPUTACION));
    });
    sets.set(a, new Set(terms.filter(t=>t && t.length>2)));
    da.forEach(r=>pairAuthors(r).forEach(p=>{
      const n = chatNorm(p.name);
      if(n) coPairs.add([chatNorm(a),n].sort().join('||'));
    }));
  });
  const out = [];
  for(let i=0;i<authors.length;i++) for(let j=i+1;j<authors.length;j++){
    const a=authors[i], b=authors[j], key=[chatNorm(a),chatNorm(b)].sort().join('||');
    if(coPairs.has(key)) continue;
    const A=sets.get(a), B=sets.get(b);
    const inter=[...A].filter(x=>B.has(x));
    const union=new Set([...A,...B]);
    const sim=union.size ? inter.length/union.size : 0;
    if(sim>0) out.push({a,b,sim,common:inter.slice(0,4)});
  }
  const rows = out.sort((a,b)=>b.sim-a.sim).slice(0,10);
  if(!rows.length) return `<p style="color:var(--mut);font-style:italic;">${rpt('noData')}</p>`;
  return `<table class="r-table"><thead><tr><th>#</th><th>Académico(a) A</th><th>Académico(a) B</th><th>Similitud</th><th>Términos comunes</th></tr></thead><tbody>${
    rows.map((r,i)=>`<tr><td class="r-rank">${i+1}</td><td class="r-ind">${titleCase(r.a)}</td><td class="r-ind">${titleCase(r.b)}</td><td class="r-val">${nf(r.sim*100)}%</td><td>${r.common.map(titleCase).join(', ')}</td></tr>`).join('')
  }</tbody></table>`;
}

function construirInforme(tab, printMode){
  const fecha=rptDate(new Date(2026, 6, 2));
  const sc=reportScope(tab); const d=sc.d;
  const total=d.length, autores=uniq(d.map(r=>r.NOMBRE_AUTOR)).length;
  const wos=d.filter(r=>r.WOS==='SI').length;
  const nArt=d.filter(r=>r.TIPO_DOCUMENTO==='Article').length;
  const TC=d.reduce((s,r)=>s+int0(r.CITADO_POR),0);
  const H=hIndex(d.map(r=>int0(r.CITADO_POR)));
  const Q1=d.filter(r=>String(r.QUARTILE).toUpperCase()==='Q1').length;
  const paises=new Set(); d.forEach(r=>String(r.PAISES_AUTORES||'').split(', ').forEach(p=>{p=p.trim();if(p)paises.add(p);}));
  const maxCit=total?Math.max(...d.map(r=>int0(r.CITADO_POR))):0; const mc=d.find(r=>int0(r.CITADO_POR)===maxCit);
  const maxSJR=total?Math.max(...d.map(r=>num(r.SJR))):0; const mi=d.find(r=>num(r.SJR)===maxSJR);

  if(!total){
    return baseDoc(tab, sc, fecha, `<section class="r-sec"><p class="r-lead">${rpt('noPubs')}</p></section>`, printMode);
  }

  const selfIds = sc.esAutor ? new Set(d.map(r=>String(r.SCOPUS_ID||'').trim()).filter(Boolean)) : new Set();
  const coautorCount = sc.esAutor ? uniq(d.flatMap(r=>splitIds(r.AUTORES_ID)).filter(id=>id && !selfIds.has(id))).length : 0;
  const kpis=[
    [rpt('publications'),total],
    sc.esAutor?[rpt('coauthors'),coautorCount]:[rpt('academics'),autores],
    [rpt('totalCitations'),TC.toLocaleString('es')],
    [rpt('hIndex'),H],[rpt('q1'),Q1],[rpt('countries'),paises.size]
  ];
  const yA = mc?` · ${mc.ANO}`:''; const yB = mi?` · ${mi.ANO}`:'';
  const sujeto = sc.esAutor ? rpt('authorSubject')(sc.titulo) : rpt('unitSubject');
  const quien = sc.esAutor ? '' : rpt('academicsOf')(autores);
  const leadCtx = { yMin:S.yMin, yMax:S.yMax, subject:sujeto, total, who:quien, cites:TC.toLocaleString('es'), h:H,
    wosPct:nf(wos/total*100), artPct:nf(nArt/total*100) };

  let secciones = `
  <section class="r-sec">
    <h2><span class="r-num">01</span> ${rpt('summary')}</h2>
    <p class="r-lead">${rpt('lead')(leadCtx)}</p>
    <div class="r-kpis">${kpis.map(k=>`<div class="r-kpi"><div class="r-kpi-v">${k[1]}</div><div class="r-kpi-l">${k[0]}</div></div>`).join('')}</div>
    <div class="r-highlights">
      <div class="r-hl"><div class="r-hl-t">${rpt('topCitedPub')}</div><div class="r-hl-q">"${mc?mc.TITULO:'—'}"</div><div class="r-hl-m"><b>${maxCit}</b> ${rpt('citations').toLowerCase()} · ${mc?titleCase(mc.NOMBRE_AUTOR):''}${yA}</div></div>
      <div class="r-hl amber"><div class="r-hl-t">${rpt('topSjrPub')}</div><div class="r-hl-q">"${mi?mi.TITULO:'—'}"</div><div class="r-hl-m"><b>${mi?num(mi.SJR):'—'}</b> SJR · ${mi?titleCase(mi.NOMBRE_AUTOR):''}${yB}</div></div>
    </div>
  </section>`;

  // sección dual de top-5 (común a todos los informes)
  const topDual = `
    <section class="r-sec"><h2><span class="r-num">★</span> ${rpt('impactPubs')}</h2>
      <h3 class="r-sub">${rpt('top5Cited')}</h3>${topCitadasHTML(d)}
      <h3 class="r-sub" style="margin-top:22px;">${rpt('top5Sjr')}</h3>${topImpactoHTML(d)}
    </section>`;

  if(sc.esAutor){
    const t=tablaIndicadoresHTML(d);
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> ${rpt('perf')}</h2>${t.rend}</section>
    <section class="r-sec"><h2><span class="r-num">03</span> ${rpt('evolution')}</h2>${evolucionHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">04</span> ${rpt('quartile')}</h2>${cuartilesHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">05</span> ${rpt('thematic')}</h2><div class="r-bars">${topListHTML(d,'AREA_COMPUTACION',';',8)}</div></section>
    <section class="r-sec"><h2><span class="r-num">06</span> ${rpt('appAreas')}</h2><div class="r-bars">${topListHTML(d,'AREAS',/;\s*/,12,['Computer Science'])}</div></section>
    <section class="r-sec"><h2><span class="r-num">07</span> ${rpt('mainCoauthors')}</h2>${coautoresReporteHTML(d, sc)}</section>
    <section class="r-sec"><h2><span class="r-num">08</span> ${rpt('keywords')}</h2><div class="r-bars">${topListHTML(d,'INDEX_PALABRAS_CLAVES',/;\s*/,12)}</div></section>
    ${topDual.replace('★','09')}`;
  } else if(tab==='Indicadores'){
    const t=tablaIndicadoresHTML(d);
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> ${rpt('perf')}</h2>${t.rend}</section>
    <section class="r-sec"><h2><span class="r-num">03</span> ${rpt('colab')}</h2>${t.colab}</section>
    <section class="r-sec"><h2><span class="r-num">04</span> ${rpt('quartile')}</h2>${cuartilesHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">05</span> ${rpt('productiveAcademics')}</h2>${rankingAutoresHTML(d)}</section>
    ${topDual.replace('★','06')}`;
  } else if(tab==='Perfiles'){
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> ${rpt('productiveAcademics')}</h2>${rankingAutoresHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">03</span> ${rpt('evolution')}</h2>${evolucionHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">04</span> ${rpt('specialty')}</h2><div class="r-bars">${topListHTML(d,'AREA_COMPUTACION',';',10)}</div></section>
    <section class="r-sec"><h2><span class="r-num">05</span> ${rpt('appAreas')}</h2><div class="r-bars">${topListHTML(d,'AREAS',/;\s*/,12,['Computer Science'])}</div></section>
    <section class="r-sec"><h2><span class="r-num">06</span> ${rpt('frequentCoauthors')}</h2>${coautoresReporteHTML(d, sc)}</section>
    <section class="r-sec"><h2><span class="r-num">07</span> ${rpt('dominantKeywords')}</h2><div class="r-bars">${topListHTML(d,'INDEX_PALABRAS_CLAVES',/;\s*/,15)}</div></section>
    ${topDual.replace('★','08')}`;
  } else if(tab==='Analítica'){
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> Hallazgos automáticos</h2>${analiticaHallazgosHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">03</span> Continuidad investigativa</h2>${analiticaContinuidadHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">04</span> Oportunidades de colaboración</h2>${oportunidadesReporteHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">05</span> ${rpt('specialty')}</h2><div class="r-bars">${topListHTML(d,'AREA_COMPUTACION',';',12)}</div></section>
    <section class="r-sec"><h2><span class="r-num">06</span> ${rpt('dominantKeywords')}</h2><div class="r-bars">${topListHTML(d,'INDEX_PALABRAS_CLAVES','; ',15)}</div></section>
    ${topDual.replace('★','07')}`;
  } else if(tab==='Dominio'){
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> ${rpt('specialty')}</h2><div class="r-bars">${topListHTML(d,'AREA_COMPUTACION',';',12)}</div></section>
    <section class="r-sec"><h2><span class="r-num">03</span> ${rpt('appAreas')}</h2><div class="r-bars">${topListHTML(d,'AREAS','; ',12,['Computer Science'])}</div></section>
    <section class="r-sec"><h2><span class="r-num">04</span> ${rpt('dominantKeywords')}</h2><div class="r-bars">${topListHTML(d,'INDEX_PALABRAS_CLAVES','; ',15)}</div></section>
    ${topDual.replace('★','05')}`;
  } else { // Resumen
    const t=tablaIndicadoresHTML(d);
    secciones+=`
    <section class="r-sec"><h2><span class="r-num">02</span> ${rpt('evolution')}</h2>${evolucionHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">03</span> ${rpt('specialty')}</h2><div class="r-bars">${topListHTML(d,'AREA_COMPUTACION',';',10)}</div></section>
    <section class="r-sec"><h2><span class="r-num">04</span> ${rpt('quartile')}</h2>${cuartilesHTML(d)}</section>
    <section class="r-sec"><h2><span class="r-num">05</span> ${rpt('perf')}</h2>${t.rend}</section>
    ${topDual.replace('★','06')}`;
  }
  return baseDoc(tab, sc, fecha, secciones, printMode);
}

/* Documento HTML autónomo con paleta USACH oficial */
function baseDoc(tab, sc, fecha, secciones, printMode){
  const lang = RPT[S.lang] ? S.lang : 'es';
  const etiqueta = sc.esAutor ? rpt('individual') : `${rpt('report')} ${rptTab(tab)}`;
  const inicial = (String(sc.titulo || '?').trim()[0] || '?').toUpperCase();
  const foto = String(sc.foto || '').trim();
  const fotoHTML = foto
    ? `<img class="cover-photo-img" src="${escAttr(foto)}" alt="${escAttr(sc.tipoFoto || 'Foto')}" referrerpolicy="no-referrer" onerror="this.outerHTML='<div class=&quot;cover-photo-fallback&quot;>${inicial}</div>'">`
    : `<div class="cover-photo-fallback">${inicial}</div>`;
  return `<!DOCTYPE html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${etiqueta} · ${sc.titulo}</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=Inter:wght@400;500;600;700;800&display=swap');
:root{
  --usach-naranja:#eeb77b;--usach-gris:#33485a;--usach-teal:#8bd9d5;
  --ink:#22313f;--mut:#647687;--faint:#9daeba;--line:#d8e5ea;--line2:#edf4f6;
  --teal:#8bd9d5;--teal-d:#007a72;--teal-dd:#007a72;--teal-bg:#effcfc;
  --naranja:#eeb77b;--naranja-bg:#fff7ee;--naranja-d:#8a5a28;
  --pink:#8bd9d5;--pink-bg:#effcfc;--lemon:#f0cf87;--lemon-bg:#fff9e9;
  --paper:#f4f8fa;--card:#ffffff;
}
@page{size:A4;margin:14mm 0;}
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:'Inter',system-ui,sans-serif;color:var(--ink);background:linear-gradient(180deg,#fbfdfe,#f1f8f9);line-height:1.55;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
.doc{max-width:900px;margin:0 auto;background:var(--card);}
.cover{padding:50px 56px 38px;background:linear-gradient(135deg,#effcfc 0%,#fff 54%,#f5f9fb 100%);color:var(--ink);position:relative;overflow:hidden;border-bottom:5px solid #d9f3f1;}
.cover::before{content:'✦';position:absolute;left:28px;top:24px;color:var(--naranja);font-size:1.8rem;text-shadow:62px 62px 0 var(--teal),735px 34px 0 #a8d0f0;}
.cover::after{content:'';position:absolute;right:-120px;top:-120px;width:360px;height:360px;border-radius:50%;background:radial-gradient(circle,rgba(127,216,208,.22),transparent 70%);}
.cover-main{position:relative;z-index:2;display:grid;grid-template-columns:1fr 176px;gap:34px;align-items:center;}
.cover-text{min-width:0;}
.cover-kick{display:inline-flex;align-items:center;gap:8px;font-size:.7rem;letter-spacing:.18em;text-transform:uppercase;color:var(--teal-d);font-weight:700;background:#fff;border:2px solid #d9f3f1;padding:5px 12px;border-radius:99px;box-shadow:0 3px 0 #d9f3f1;}
.cover h1{font-family:'Space Grotesk';font-weight:700;font-size:2.6rem;line-height:1.06;margin:18px 0 6px;letter-spacing:0;}
.cover .sub{font-size:1rem;color:var(--mut);font-weight:500;}
.cover .meta{margin-top:30px;display:flex;gap:14px;flex-wrap:wrap;}
.cover .meta .m{background:#fff;border:2px solid #d9f3f1;border-radius:8px;padding:11px 16px;box-shadow:0 3px 0 #d9f3f1;}
.cover .meta b{color:var(--pink);display:block;font-family:'Space Grotesk';font-weight:700;font-size:1rem;}
.cover .meta span{font-size:.72rem;color:var(--mut);text-transform:uppercase;letter-spacing:.06em;font-weight:700;}
.cover-photo{justify-self:end;width:176px;}
.cover-photo-frame{width:176px;height:176px;border-radius:18px;padding:8px;background:#fff;border:3px solid #d9f3f1;box-shadow:0 5px 0 #d9f3f1,0 18px 40px rgba(34,49,63,.16);}
.cover-photo-img{width:100%;height:100%;object-fit:cover;border-radius:13px;display:block;background:#fff;}
.cover-photo-fallback{width:100%;height:100%;border-radius:13px;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,var(--teal-bg),#fff);color:var(--teal-dd);font-family:'Space Grotesk';font-size:3.2rem;font-weight:700;}
.cover-photo-label{margin-top:10px;text-align:center;font-size:.68rem;text-transform:uppercase;letter-spacing:.1em;color:rgba(255,255,255,.62);font-weight:700;}
.body{padding:44px 56px 56px;}
.r-sec{margin-bottom:38px;}
.r-sec h2{font-family:'Space Grotesk';font-weight:600;font-size:1.32rem;color:var(--ink);display:flex;align-items:center;gap:12px;margin-bottom:18px;}
.r-num{font-family:'Space Grotesk';font-weight:700;color:#fff;background:linear-gradient(135deg,var(--teal-d),var(--teal));font-size:.8rem;min-width:30px;height:30px;padding:0 7px;display:inline-flex;align-items:center;justify-content:center;border-radius:9px;flex-shrink:0;box-shadow:0 3px 0 #d9f3f1;}
.r-sec h2::after{content:'';flex:1;height:1px;border-top:2px dashed var(--line);background:transparent;}
.r-sub{font-family:'Space Grotesk';font-weight:700;font-size:.95rem;color:var(--teal-d);margin-bottom:10px;}
.r-lead{font-size:1.04rem;color:var(--ink);line-height:1.7;margin-bottom:22px;}
.r-lead b{color:var(--teal-dd);font-weight:600;}
.r-kpis{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:22px;}
.r-kpi{background:linear-gradient(160deg,#fff,var(--teal-bg));border:2px solid #d9f3f1;border-radius:8px;padding:16px 10px;text-align:center;box-shadow:0 3px 0 #d9f3f1;}
.r-kpi:nth-child(even){background:linear-gradient(160deg,#fff,var(--teal-bg));border-color:#aee9e6;}
.r-kpi-v{font-family:'Space Grotesk';font-weight:700;font-size:1.55rem;color:var(--pink);line-height:1;letter-spacing:0;}
.r-kpi-l{font-size:.62rem;text-transform:uppercase;letter-spacing:.06em;color:var(--mut);margin-top:8px;font-weight:600;}
.r-highlights{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
.r-hl{background:var(--teal-bg);border:2px solid #d9f3f1;border-radius:8px;padding:18px 20px;position:relative;overflow:hidden;box-shadow:0 3px 0 #d9f3f1;}
.r-hl::before{content:'★';position:absolute;right:15px;top:12px;color:var(--lemon);font-size:1.1rem;background:transparent;width:auto;}
.r-hl.amber{background:var(--naranja-bg);border-color:#ffd5a8;}.r-hl.amber::before{color:var(--naranja);}
.r-hl-t{font-size:.64rem;text-transform:uppercase;letter-spacing:.1em;color:var(--mut);font-weight:700;margin-bottom:9px;}
.r-hl-q{font-weight:500;font-size:.96rem;color:var(--ink);line-height:1.45;}
.r-hl-m{margin-top:11px;font-size:.82rem;color:var(--mut);}.r-hl-m b{color:var(--teal-dd);font-family:'Space Grotesk';font-size:1.15rem;font-weight:700;}
.r-hl.amber .r-hl-m b{color:var(--naranja-d);}
.r-table{width:100%;border-collapse:collapse;font-size:.88rem;}
.r-table th{text-align:left;font-size:.64rem;text-transform:uppercase;letter-spacing:.07em;color:var(--teal-d);font-weight:700;padding:10px 11px;border-bottom:2px solid var(--line);background:#f6fbfb;}
.r-table td{padding:10px 11px;border-bottom:1px solid var(--line2);vertical-align:top;}
.r-table tbody tr:nth-child(even){background:#fafbfb;}
.r-ind{font-weight:500;}
.r-sig{font-family:'Space Grotesk';font-size:.78rem;color:var(--teal-d);font-weight:500;}
.r-val{text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-family:'Space Grotesk';white-space:nowrap;}
.r-rank{font-family:'Space Grotesk';font-weight:700;color:var(--usach-naranja);text-align:center;width:36px;}
.r-bars{display:flex;flex-direction:column;gap:10px;}
.r-bar-row{display:grid;grid-template-columns:1fr 150px 46px;align-items:center;gap:14px;}
.r-bar-lab{font-size:.88rem;color:var(--ink);}
.r-bar-track{height:9px;background:var(--line2);border-radius:5px;overflow:hidden;}
.r-bar-fill{display:block;height:100%;background:linear-gradient(90deg,var(--teal),#a8d0f0);border-radius:5px;}
.r-bar-val{font-variant-numeric:tabular-nums;font-weight:700;font-family:'Space Grotesk';color:var(--pink);text-align:right;font-size:.88rem;}
.r-foot{padding:24px 56px 40px;border-top:1px solid var(--line);font-size:.74rem;color:var(--faint);display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px;}
@media print{
  html,body{background:#fff;}
  .doc{max-width:none;box-shadow:none;}
  .cover{padding:38px 40px 30px;}
  .body{padding:30px 40px;}
  .r-foot{padding:18px 40px 0;}
  .r-sec{margin-bottom:26px;page-break-inside:avoid;break-inside:avoid;}
  .r-table,.r-bars,.r-highlights,.r-kpis{page-break-inside:avoid;break-inside:avoid;}
  .cover h1{font-size:2.1rem;}
}
@media(max-width:680px){.cover,.body,.r-foot{padding-left:22px;padding-right:22px;}.cover-main{grid-template-columns:1fr;}.cover-photo{justify-self:start;width:138px;}.cover-photo-frame{width:138px;height:138px;}.r-kpis{grid-template-columns:repeat(3,1fr);}.r-highlights{grid-template-columns:1fr;}.cover h1{font-size:1.9rem;}.r-bar-row{grid-template-columns:1fr 90px 40px;}}
</style></head>
<body><div class="doc" id="report-doc">
  <div class="cover">
    <div class="cover-main">
      <div class="cover-text">
        <div class="cover-kick">Analizador Bibliométrico · ${etiqueta}</div>
        <h1>${sc.titulo}</h1>
        <div class="sub">${sc.subtitulo}</div>
        <div class="meta">
          <div class="m"><b>${S.yMin}–${S.yMax}</b><span>Periodo</span></div>
          <div class="m"><b>${sc.idx}</b><span>Indexación</span></div>
          <div class="m"><b>${fecha}</b><span>Emisión</span></div>
        </div>
      </div>
      <div class="cover-photo">
        <div class="cover-photo-frame">${fotoHTML}</div>
        <div class="cover-photo-label">${sc.tipoFoto || ''}</div>
      </div>
    </div>
  </div>
  <div class="body">${secciones}</div>
  <div class="r-foot">
    <span>${S.uni} · ${S.sec}</span>
    <span>${rpt('generated')}</span>
  </div>
</div></body></html>`;
}

/* ---------- boot ---------- */
function boot(){
  ov('Cargando repositorio','Procesando la base de datos…');
  setTimeout(()=>{
    const p=parseCSV(window.PAPERS_CSV); HEADERS=p.headers; DATA=p.rows;
    initFilters(); refreshAutor(); wire(); wireFriendlyHelp(); buildResumen(); applyLanguage(); applyFriendlyTooltips(); ovHide();
  },60);
}
window.addEventListener('DOMContentLoaded', boot);
