/* ResearchAnalyser: task-based publication interface.
 * The original data, metric functions, visualisations and report builders are retained.
 * This module supplies navigation, lazy rendering and the complete publication catalogue.
 */
(() => {
'use strict';
const UI_TEXT = {
 es: {moduleTheses:'Tesis y memorias',brand:'ResearchAnalyser',brandSub:'Producción científica',assistant:'Asistente',allModules:'ResearchAnalyser',science:'Producción científica',allTools:'Todas las herramientas',fullData:'Base completa',summary:'Resumen',papers:'Publicaciones',people:'Académicos y unidad',analysis:'Análisis',reports:'Informes',currentScope:'Consulta activa',editFilters:'Cambiar filtros',sharedScope:'Contexto compartido',scope:'Filtros de consulta',scopeHint:'Estos filtros se aplican a todas las vistas, tablas e informes.',resetFilters:'Restablecer filtros',applyScope:'Ver resultados',overview:'Vista general',topics:'Temas',collaboration:'Colaboración',similarity:'Similitud temática',indicators:'Indicadores',insights:'Hallazgos',comparison:'Comparaciones',areas:'Áreas y evolución',opportunities:'Oportunidades',catalogueKicker:'Catálogo de investigación',catalogueDesc:'Consulta todas las publicaciones del filtro activo y abre su información completa.',search:'Buscar',searchPlaceholder:'Buscar por título, autores, DOI, resumen, áreas o palabras clave',author:'Académico(a)',quartile:'Cuartil',countMode:'Mostrar',uniqueWorks:'Una fila por publicación',authorRecords:'Una fila por académico(a)',sort:'Orden',recent:'Más recientes',cited:'Más citadas',alphabetic:'Título A–Z',list:'Lista',table:'Tabla',countNote:'Una publicación puede estar asociada a varios académicos. El catálogo permite consultar los trabajos únicos o los registros individuales; los indicadores conservan las reglas de conteo de la base original.',reportKicker:'Resultados para compartir',reportsDesc:'Genera los informes completos y las tablas CSV con el contexto seleccionado.',reportKind:'Contenido del informe',reportScope:'Alcance',reportTables:'Tablas y resultados detallados',reportTablesHint:'Cada tabla de indicadores, publicaciones o comparaciones conserva su exportación CSV.',goAnalysis:'Abrir análisis',fullDataHint:'Descarga el archivo original con todas sus columnas y registros.',downloadData:'Descargar base',paperDetail:'Ficha de publicación',allAuthors:'Todos los académicos',allQuartiles:'Todos los cuartiles',noQuartile:'Sin cuartil registrado',results:'resultados',works:'publicaciones',records:'registros',scopePubs:'publicaciones',barUnit:'Unidad',barPeriod:'Periodo',barAfil:'Filiación',barIdx:'Indexación',barType:'Tipo',barCol:'Colección WoS',year:'Año',citations:'Citas',source:'Fuente',type:'Tipo',indexing:'Indexación',empty:'No hay publicaciones para estos filtros.',prev:'Anterior',next:'Siguiente',page:'Página',of:'de',openPaper:'Abrir publicación',unitAuthors:'Académicos de la unidad',abstract:'Resumen',noAbstract:'No hay un resumen registrado para esta publicación.',classifications:'Áreas y clasificaciones',keywords:'Palabras clave',allFields:'Todos los campos de la base',associatedRecords:'registros en la base, uno por académico(a) de la unidad',openProfile:'Abrir perfil',noValue:'Sin información',countOriginal:'Los indicadores originales contabilizan registros asociados a académicos. El catálogo también permite agrupar publicaciones únicas.',productionIndex:'Producción e indexación',topicSummary:'Áreas y fuentes',collabSummary:'Colaboración y alcance',highlights:'Publicaciones destacadas',profileSummary:'Perfil institucional o individual',profilePublications:'Publicaciones, revistas y fuentes',profileTopics:'Flujo de áreas y palabras clave',profileCollaboration:'Coautores, red y mapa',profileSimilarity:'Dendrogramas de similitud temática',compareDesc:'Compara académicos o un académico frente al resto de la unidad, con tablas y residuos χ².',insightsDesc:'Hallazgos, continuidad investigativa y búsqueda en todos los campos.',opportunitiesDesc:'Explora coincidencias temáticas y posibles colaboraciones.',scopeUnit:'Informe de la unidad',scopeAuthor:'Informe individual',reportAuthorHint:'Los informes individuales utilizan el informe completo de perfil del académico seleccionado.',reportNoData:'No hay registros para generar este informe.',close:'Cerrar',scopeFootnote:'Los CSV del catálogo incluyen los registros completos asociados a los resultados.',loadError:'No se pudo actualizar esta vista. Prueba otro filtro o vuelve a abrir la aplicación.',doi:'DOI',bibliographic:'Datos bibliográficos',specialty:'Áreas de especialidad',application:'Áreas de aplicación',subareas:'Subáreas de aplicación',oecd:'Clasificación OCDE',sdg:'Clasificación ODS (ANID)',originalAuthor:'Autor del registro',fullRecord:'Registro completo',journal:'Artículo de revista',conference:'Acta de congreso',review:'Revisión',authorSearch:'Por autor o unidad',moreFields:'Identificadores, filiaciones y demás campos',overviewTools:'Todos los indicadores del resumen se conservan en los apartados siguientes.'},
 en: {moduleTheses:'Theses and projects',brand:'ResearchAnalyser',brandSub:'Research output',assistant:'Assistant',allModules:'ResearchAnalyser',science:'Research output',allTools:'All tools',fullData:'Full database',summary:'Overview',papers:'Publications',people:'Academics and unit',analysis:'Analysis',reports:'Reports',currentScope:'Current scope',editFilters:'Change filters',sharedScope:'Shared context',scope:'Query filters',scopeHint:'These filters apply to every view, table and report.',resetFilters:'Reset filters',applyScope:'View results',overview:'Overview',topics:'Topics',collaboration:'Collaboration',similarity:'Thematic similarity',indicators:'Indicators',insights:'Insights',comparison:'Comparisons',areas:'Areas and trends',opportunities:'Opportunities',catalogueKicker:'Research catalogue',catalogueDesc:'Browse every publication in the current scope and open its complete record.',search:'Search',searchPlaceholder:'Search titles, authors, DOI, abstracts, areas or keywords',author:'Academic',quartile:'Quartile',countMode:'Show',uniqueWorks:'One row per publication',authorRecords:'One row per academic',sort:'Order',recent:'Most recent',cited:'Most cited',alphabetic:'Title A–Z',list:'List',table:'Table',countNote:'A publication may be associated with several academics. The catalogue offers unique works or individual records; indicators retain the counting rules of the original database.',reportKicker:'Results to share',reportsDesc:'Generate complete reports and CSV tables for the selected scope.',reportKind:'Report contents',reportScope:'Scope',reportTables:'Tables and detailed results',reportTablesHint:'Every indicator, publication and comparison table retains its CSV export.',goAnalysis:'Open analysis',fullDataHint:'Download the original file with all its fields and records.',downloadData:'Download database',paperDetail:'Publication details',allAuthors:'All academics',allQuartiles:'All quartiles',noQuartile:'No recorded quartile',results:'results',works:'publications',records:'records',scopePubs:'publications',barUnit:'Unit',barPeriod:'Period',barAfil:'Affiliation',barIdx:'Indexing',barType:'Type',barCol:'WoS collection',year:'Year',citations:'Citations',source:'Source',type:'Type',indexing:'Indexing',empty:'No publications match these filters.',prev:'Previous',next:'Next',page:'Page',of:'of',openPaper:'Open publication',unitAuthors:'Academics in this unit',abstract:'Abstract',noAbstract:'No abstract is recorded for this publication.',classifications:'Areas and classifications',keywords:'Keywords',allFields:'All database fields',associatedRecords:'records in the database, one per unit academic',openProfile:'Open profile',noValue:'No information',countOriginal:'The original indicators count records associated with academics. The catalogue also groups unique publications.',productionIndex:'Output and indexing',topicSummary:'Areas and sources',collabSummary:'Collaboration and reach',highlights:'Highlighted publications',profileSummary:'Institutional or individual profile',profilePublications:'Publications, journals and sources',profileTopics:'Area flows and keywords',profileCollaboration:'Co-authors, network and map',profileSimilarity:'Thematic similarity dendrograms',compareDesc:'Compare academics, or an academic against the rest of the unit, with χ² tables and residuals.',insightsDesc:'Insights, research continuity and search across all fields.',opportunitiesDesc:'Explore shared topics and possible collaborations.',scopeUnit:'Unit report',scopeAuthor:'Individual report',reportAuthorHint:'Individual reports use the complete profile report for the selected academic.',reportNoData:'There are no records for this report.',close:'Close',scopeFootnote:'Catalogue CSV files contain the complete records associated with the results.',loadError:'This view could not be updated. Try another filter or reopen the application.',doi:'DOI',bibliographic:'Bibliographic details',specialty:'Specialty areas',application:'Application areas',subareas:'Application subareas',oecd:'OECD classification',sdg:'SDG classification (ANID)',originalAuthor:'Record author',fullRecord:'Complete record',journal:'Journal article',conference:'Conference paper',review:'Review',authorSearch:'By author or unit',moreFields:'Identifiers, affiliations and other fields',overviewTools:'All overview indicators are retained in the following sections.'},
 pt: {moduleTheses:'Teses e trabalhos',brand:'ResearchAnalyser',brandSub:'Produção científica',assistant:'Assistente',allModules:'ResearchAnalyser',science:'Produção científica',allTools:'Todas as ferramentas',fullData:'Base completa',summary:'Resumo',papers:'Publicações',people:'Acadêmicos e unidade',analysis:'Análise',reports:'Relatórios',currentScope:'Consulta ativa',editFilters:'Alterar filtros',sharedScope:'Contexto compartilhado',scope:'Filtros de consulta',scopeHint:'Estes filtros se aplicam a todas as vistas, tabelas e relatórios.',resetFilters:'Restabelecer filtros',applyScope:'Ver resultados',overview:'Visão geral',topics:'Temas',collaboration:'Colaboração',similarity:'Similaridade temática',indicators:'Indicadores',insights:'Achados',comparison:'Comparações',areas:'Áreas e evolução',opportunities:'Oportunidades',catalogueKicker:'Catálogo de pesquisa',catalogueDesc:'Consulte todas as publicações do filtro ativo e abra suas informações completas.',search:'Buscar',searchPlaceholder:'Buscar por título, autores, DOI, resumo, áreas ou palavras-chave',author:'Acadêmico(a)',quartile:'Quartil',countMode:'Mostrar',uniqueWorks:'Uma linha por publicação',authorRecords:'Uma linha por acadêmico(a)',sort:'Ordem',recent:'Mais recentes',cited:'Mais citadas',alphabetic:'Título A–Z',list:'Lista',table:'Tabela',countNote:'Uma publicação pode estar associada a vários acadêmicos. O catálogo permite consultar trabalhos únicos ou registros individuais; os indicadores mantêm as regras de contagem da base original.',reportKicker:'Resultados para compartilhar',reportsDesc:'Gere relatórios completos e tabelas CSV com o contexto selecionado.',reportKind:'Conteúdo do relatório',reportScope:'Escopo',reportTables:'Tabelas e resultados detalhados',reportTablesHint:'Cada tabela de indicadores, publicações ou comparações mantém sua exportação CSV.',goAnalysis:'Abrir análise',fullDataHint:'Baixe o arquivo original com todos os campos e registros.',downloadData:'Baixar base',paperDetail:'Ficha da publicação',allAuthors:'Todos os acadêmicos',allQuartiles:'Todos os quartis',noQuartile:'Sem quartil registrado',results:'resultados',works:'publicações',records:'registros',scopePubs:'publicações',barUnit:'Unidade',barPeriod:'Período',barAfil:'Filiação',barIdx:'Indexação',barType:'Tipo',barCol:'Coleção WoS',year:'Ano',citations:'Citações',source:'Fonte',type:'Tipo',indexing:'Indexação',empty:'Não há publicações para estes filtros.',prev:'Anterior',next:'Seguinte',page:'Página',of:'de',openPaper:'Abrir publicação',unitAuthors:'Acadêmicos da unidade',abstract:'Resumo',noAbstract:'Não há resumo registrado para esta publicação.',classifications:'Áreas e classificações',keywords:'Palavras-chave',allFields:'Todos os campos da base',associatedRecords:'registros na base, um por acadêmico(a) da unidade',openProfile:'Abrir perfil',noValue:'Sem informação',countOriginal:'Os indicadores originais contam registros associados a acadêmicos. O catálogo também permite agrupar publicações únicas.',productionIndex:'Produção e indexação',topicSummary:'Áreas e fontes',collabSummary:'Colaboração e alcance',highlights:'Publicações em destaque',profileSummary:'Perfil institucional ou individual',profilePublications:'Publicações, revistas e fontes',profileTopics:'Fluxo de áreas e palavras-chave',profileCollaboration:'Coautores, rede e mapa',profileSimilarity:'Dendrogramas de similaridade temática',compareDesc:'Compare acadêmicos ou um acadêmico com o restante da unidade, com tabelas e resíduos χ².',insightsDesc:'Achados, continuidade da pesquisa e busca em todos os campos.',opportunitiesDesc:'Explore temas compartilhados e possíveis colaborações.',scopeUnit:'Relatório da unidade',scopeAuthor:'Relatório individual',reportAuthorHint:'Relatórios individuais usam o relatório completo de perfil do acadêmico selecionado.',reportNoData:'Não há registros para gerar este relatório.',close:'Fechar',scopeFootnote:'Os CSV do catálogo incluem os registros completos associados aos resultados.',loadError:'Não foi possível atualizar esta vista. Tente outro filtro ou abra o aplicativo novamente.',doi:'DOI',bibliographic:'Dados bibliográficos',specialty:'Áreas de especialidade',application:'Áreas de aplicação',subareas:'Subáreas de aplicação',oecd:'Classificação OCDE',sdg:'Classificação ODS (ANID)',originalAuthor:'Autor do registro',fullRecord:'Registro completo',journal:'Artigo de revista',conference:'Anais de congresso',review:'Revisão',authorSearch:'Por autor ou unidade',moreFields:'Identificadores, afiliações e outros campos',overviewTools:'Todos os indicadores do resumo permanecem nos seguintes grupos.'}
};
const SUMMARY_TEXT = {
 es: {summaryKicker:'Panorama de investigación',summaryTitle:'La investigación,\nen perspectiva.',summaryIntro:'Una mirada a la producción, el impacto y las conexiones de la unidad.',summaryPeriod:'Periodo de análisis',summaryExplore:'Explorar publicaciones',annualTitle:'Producción a lo largo del tiempo',annualDesc:'Registros de publicaciones por año',annualPeak:'Año con más registros',annualTable:'Ver datos anuales',summaryRecords:'Registros',summaryTypes:'Producción e indexación',summaryHighlights:'Publicaciones que destacan',summaryHighlightsDesc:'Los trabajos con más citas y mayor SJR dentro de la consulta activa.',summaryAreas:'Dónde se concentra la investigación',summaryAreasDesc:'Especialidades, aplicaciones, clasificaciones y fuentes predominantes.',summaryAllAreas:'Explorar todas las áreas',summaryNetwork:'Ver red y mapa',summaryNetworkDesc:'Explora los coautores y las conexiones internacionales de la unidad.',summaryFullPaper:'Ver ficha completa',metricHelp:'Cómo se calcula',summaryMethod:'Sobre estas cifras',summaryOthers:'Sin indexación registrada'},
 en: {summaryKicker:'Research overview',summaryTitle:'Research,\nin perspective.',summaryIntro:'A view of the unit’s output, impact and connections.',summaryPeriod:'Analysis period',summaryExplore:'Explore publications',annualTitle:'Research output over time',annualDesc:'Publication records by year',annualPeak:'Year with most records',annualTable:'View annual data',summaryRecords:'Records',summaryTypes:'Output and indexing',summaryHighlights:'Publications in focus',summaryHighlightsDesc:'The most cited work and the work with the highest SJR in the current scope.',summaryAreas:'Where research is concentrated',summaryAreasDesc:'Leading specialties, applications, classifications and sources.',summaryAllAreas:'Explore all research areas',summaryNetwork:'View network and map',summaryNetworkDesc:'Explore the unit’s co-authors and international connections.',summaryFullPaper:'View complete record',metricHelp:'How this is calculated',summaryMethod:'About these figures',summaryOthers:'No recorded indexing'},
 pt: {summaryKicker:'Panorama da pesquisa',summaryTitle:'A pesquisa,\nem perspectiva.',summaryIntro:'Um olhar sobre a produção, o impacto e as conexões da unidade.',summaryPeriod:'Período de análise',summaryExplore:'Explorar publicações',annualTitle:'Produção ao longo do tempo',annualDesc:'Registros de publicações por ano',annualPeak:'Ano com mais registros',annualTable:'Ver dados anuais',summaryRecords:'Registros',summaryTypes:'Produção e indexação',summaryHighlights:'Publicações em destaque',summaryHighlightsDesc:'Os trabalhos com mais citações e maior SJR na consulta ativa.',summaryAreas:'Onde a pesquisa se concentra',summaryAreasDesc:'Especialidades, aplicações, classificações e fontes predominantes.',summaryAllAreas:'Explorar todas as áreas',summaryNetwork:'Ver rede e mapa',summaryNetworkDesc:'Explore os coautores e as conexões internacionais da unidade.',summaryFullPaper:'Ver ficha completa',metricHelp:'Como se calcula',summaryMethod:'Sobre estes números',summaryOthers:'Sem indexação registrada'}
};
Object.entries(SUMMARY_TEXT).forEach(([lang,words])=>Object.assign(UI_TEXT[lang],words));
Object.assign(UI_TEXT.es,{summaryCountUnit:'registros de publicaciones',allModules:'Inicio'});
Object.assign(UI_TEXT.en,{summaryCountUnit:'publication records',allModules:'Home'});
Object.assign(UI_TEXT.pt,{summaryCountUnit:'registros de publicações',allModules:'Início'});
Object.assign(UI_TEXT.es,{compareAcademics:'Comparar académicos',areaAccess:'Áreas y evolución'});
Object.assign(UI_TEXT.en,{compareAcademics:'Compare academics',areaAccess:'Areas and trends'});
Object.assign(UI_TEXT.pt,{compareAcademics:'Comparar acadêmicos',areaAccess:'Áreas e evolução'});
Object.entries(UI_TEXT).forEach(([lang,words])=>{Object.entries(words).forEach(([key,value])=>{I18N[lang]['ui.'+key]=value;});});
const U=key=>tr('ui.'+key);
const $id=id=>document.getElementById(id);
const html=value=>escAttr(String(value??''));
const number=value=>new Intl.NumberFormat(S.lang==='es'?'es-CL':S.lang==='pt'?'pt-BR':'en-GB').format(value);
const fold=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
const valid=value=>Boolean(String(value??'').trim())&&!/^(?:#?n\/?a|null|undefined|sin clasificaci[oó]n)$/i.test(String(value).trim());
const display=value=>valid(value)?html(value):html(U('noValue'));
const safeLink=value=>{try{const url=new URL(String(value));return /^https?:$/.test(url.protocol)?url.href:null;}catch{return null;}};
const doiOf=row=>{const d=String(row.DOI||'').trim().replace(/^https?:\/\/(?:dx\.)?doi\.org\//i,'').replace(/^doi:\s*/i,'');return /^10\.\d{4,9}\/.+/i.test(d)?d.toLowerCase():'';};
const titleKey=row=>[row.TITULO,row.ANO,row.FUENTE,row.TIPO_DOCUMENTO].map(x=>fold(x).replace(/\s+/g,' ').trim()).join('||');
/** Do not use WOS_ID here: this database stores an author identifier in that field. */
function catalogueDocuments(rows,mode='papers'){
 if(mode==='records')return rows.map((row,i)=>({key:'record:'+i,record:row,rows:[row],authors:[row.NOMBRE_AUTOR].filter(Boolean),citations:int0(row.CITADO_POR)}));
 const byTitle=new Map();rows.forEach(r=>{const doi=doiOf(r);if(doi){const k=titleKey(r);if(!byTitle.has(k))byTitle.set(k,new Set());byTitle.get(k).add(doi);}});
 const papers=new Map();
 rows.forEach(row=>{
  let doi=doiOf(row);const matches=byTitle.get(titleKey(row));if(!doi&&matches?.size===1)doi=[...matches][0];
  let key=doi?'doi:'+doi:'';
  if(!key){const link=safeLink(row.LINK);if(link){const eid=new URL(link).searchParams.get('eid');if(eid)key='eid:'+eid;}}
  if(!key)key='title:'+titleKey(row);
  if(!papers.has(key))papers.set(key,{key,record:row,rows:[],authors:[],citations:0});
  const doc=papers.get(key);doc.rows.push(row);if(row.NOMBRE_AUTOR&&!doc.authors.includes(row.NOMBRE_AUTOR))doc.authors.push(row.NOMBRE_AUTOR);doc.citations=Math.max(doc.citations,int0(row.CITADO_POR));
 });
 return [...papers.values()];
}
const UI={route:'resumen',profile:'overview',analysis:'indicators',cache:new Map(),cat:{query:'',author:'',quartile:'',mode:'papers',sort:'recent',layout:'list',page:1,pageSize:12,docs:[]},returnRoute:'resumen',started:false};
const comparator=ResearchAcademicTools.createComparison({
 a:'ana_author_a',b:'ana_author_b',rest:ANA_REST,lang:()=>S.lang,
 rows:(value,other)=>anaCompareRows(value,other),names:rows=>uniq(rows.map(r=>r.NOMBRE_AUTOR).filter(Boolean)),
 name:titleCase,unit:()=>titleCase(S.sec),count:rows=>anaPubs(rows).length,
 countLabel:()=>S.lang==='en'?'unique publications':S.lang==='pt'?'publicações únicas':'publicaciones únicas',
 photo:name=>DATA.find(r=>r.NOMBRE_AUTOR===name&&safeLink(r.URL_FOTO_ACADEMICO))?.URL_FOTO_ACADEMICO||'',
 run:()=>runChiCompare(),profile:author=>go('perfiles','overview',{author})
});
const areaFilter=ResearchAcademicTools.createAreaFilter({
 host:'catalogue_filters',lang:()=>S.lang,fields:Object.values(DOMF),
 label:field=>LBLT(ANA_FIELDS[field].label),terms:(row,field)=>anaTerms([row],field),
 change:()=>{UI.cat.page=1;renderCatalogue();}
});
function signature(extra=''){return JSON.stringify([S.uni,S.sec,S.yMin,S.yMax,S.afil,S.idx,S.tipo,S.col,S.lang,extra]);}
function setPanel(id){document.querySelectorAll('.panel').forEach(p=>p.classList.toggle('active',p.id===id));}
function controlsSelection(id,value){document.querySelectorAll('#'+id+' button').forEach(b=>b.classList.toggle('on',b.dataset.v===value));}
function translate(){
 document.querySelectorAll('[data-i18n]').forEach(el=>{if(el.dataset.i18n.startsWith('ui.'))el.textContent=tr(el.dataset.i18n);});
 document.querySelectorAll('[data-i18n-placeholder]').forEach(el=>{if(el.dataset.i18nPlaceholder.startsWith('ui.'))el.placeholder=tr(el.dataset.i18nPlaceholder);});
 document.querySelectorAll('[data-close]').forEach(b=>b.setAttribute('aria-label',U('close')));
 $id('directory_open').setAttribute('aria-label',U('allTools'));
}
function updateScope(){
 // La barra de consulta es el único resumen del alcance: cuántas publicaciones quedan y cada filtro con su etiqueta.
 const opt=(grupo,key)=>{const par=(OPCIONES[grupo]||[]).find(o=>o[0]===S[grupo]);return par?tr(par[1]):'';};
 // Unidad, periodo y filiación siempre; indexación, tipo y colección solo cuando restringen algo.
 const unidad=titleCase(S.sec).replace(/\b(De|Del|La|Las|Los|Y|En)\b/g,m=>m.toLowerCase());
 const pairs=[[U('barUnit'),unidad],[U('barPeriod'),S.yMin+'–'+S.yMax],[U('barAfil'),opt('afil')]];
 if(S.idx&&S.idx!=='todas')pairs.push([U('barIdx'),opt('idx')]);
 if(S.tipo&&S.tipo!=='todos')pairs.push([U('barType'),opt('tipo')]);
 if(Array.isArray(S.col)&&S.col.length)pairs.push([U('barCol'),S.col.join(', ')]);
 const count='<span class="scope-chip scope-count"><strong>'+number(base().length)+'</strong> '+html(U('of'))+' '+number(baseAmplia().length)+' '+html(U('scopePubs'))+'</span>';
 $id('scope_chips').innerHTML=count+pairs.map(([label,value])=>'<span class="scope-chip"><strong>'+html(label)+':</strong> '+html(value)+'</span>').join('');
}
function summaryElement(tag,className,content){
 const el=document.createElement(tag);el.className=className;if(content!==undefined)el.innerHTML=content;return el;
}
function summaryHeading(title,description,action){
 return summaryElement('div','overview-section-heading','<div><h3>'+html(U(title))+'</h3>'+(description?'<p>'+html(U(description))+'</p>':'')+'</div>'+(action||''));
}
function summaryHelp(card){
 // Keep the original explanations on explicit, keyboard-accessible help buttons.
 const title=card.getAttribute('data-help-title');if(!title)return;
 const button=summaryElement('button','overview-help','<i class="fa-regular fa-circle-question" aria-hidden="true"></i>');
 button.setAttribute('type','button');button.setAttribute('aria-label',U('metricHelp')+': '+title);
 ['data-help-title','data-help-body'].forEach(attr=>{button.setAttribute(attr,card.getAttribute(attr)||'');card.removeAttribute(attr);});
 card.removeAttribute('title');card.appendChild(button);
}
function annualSummaryChart(rows){
 const years=[];for(let y=S.yMin;y<=S.yMax;y++)years.push(y);
 const counts=new Map(years.map(y=>[y,0]));rows.forEach(r=>{const y=int0(r.ANO);if(counts.has(y))counts.set(y,counts.get(y)+1);});
 const values=years.map(y=>counts.get(y)),max=Math.max(1,...values),peakIndex=values.indexOf(Math.max(...values));
 const rough=max/4,power=10**Math.floor(Math.log10(rough)),step=Math.max(1,[1,2,5,10].find(n=>n>=rough/power)*power),top=Math.ceil(max/step)*step;
 const W=720,H=258,left=42,right=14,upper=27,bottom=38,width=W-left-right,height=H-upper-bottom;
 const gap=width/Math.max(1,years.length),barWidth=Math.min(52,gap*.62),labelEvery=Math.max(1,Math.ceil(years.length/12));
 let marks='';
 for(let value=0;value<=top;value+=step){const y=upper+height-value/top*height;marks+='<line x1="'+left+'" y1="'+y+'" x2="'+(W-right)+'" y2="'+y+'" class="overview-gridline"/><text x="'+(left-10)+'" y="'+(y+5)+'" text-anchor="end" class="overview-axis">'+number(value)+'</text>';}
 years.forEach((year,i)=>{
  const count=values[i],h=count/top*height,x=left+i*gap+(gap-barWidth)/2,y=upper+height-h;
  marks+='<g><rect class="overview-year-bar'+(i===peakIndex?' is-peak':'')+'" data-year="'+year+'" data-count="'+count+'" x="'+x+'" y="'+y+'" width="'+barWidth+'" height="'+h+'" rx="3"><title>'+year+': '+number(count)+' '+html(U('summaryRecords').toLowerCase())+'</title></rect>';
  if(years.length<=14)marks+='<text class="overview-bar-value" x="'+(x+barWidth/2)+'" y="'+(y-9)+'" text-anchor="middle">'+number(count)+'</text>';
  if(i%labelEvery===0||i===years.length-1)marks+='<text class="overview-axis'+(i===peakIndex?' is-peak':'')+'" x="'+(x+barWidth/2)+'" y="'+(H-12)+'" text-anchor="middle">'+year+'</text>';
  marks+='</g>';
 });
 const svg='<svg id="summary_annual_chart" role="img" aria-labelledby="summary_annual_title summary_annual_desc" viewBox="0 0 '+W+' '+H+'"><title id="summary_annual_title">'+html(U('annualTitle'))+'</title><desc id="summary_annual_desc">'+years.map((year,i)=>year+': '+number(values[i])).join('; ')+'.</desc>'+marks+'</svg>';
 const table='<details class="overview-year-data"><summary>'+html(U('annualTable'))+' <i class="fa-solid fa-angle-down" aria-hidden="true"></i></summary><div class="overview-year-table"><table><thead><tr><th scope="col">'+html(U('year'))+'</th><th scope="col">'+html(U('summaryRecords'))+'</th></tr></thead><tbody>'+years.map((year,i)=>'<tr><th scope="row">'+year+'</th><td>'+number(values[i])+'</td></tr>').join('')+'</tbody></table></div></details>';
 return {svg,table,peak:years[peakIndex]+' · '+number(values[peakIndex])};
}
function tidySummary(){
 const box=$id('summary'),cards=[...box.children].filter(c=>c.classList.contains('stat'));UI.summaryPapers=[];
 box.classList.add('research-overview');if(!cards.length)return;
 const rows=base();cards.forEach(summaryHelp);box.replaceChildren();
 const period=S.yMin+'–'+S.yMax;
 const hero=summaryElement('div','overview-hero');
 const intro=summaryElement('div','overview-hero-copy','<div class="overview-eyebrow"><span class="overview-live-mark" aria-hidden="true"></span>'+html(U('summaryKicker'))+'</div><h2>'+html(U('summaryTitle')).replace('\n',' <br>')+'</h2><p class="overview-unit">'+html(titleCase(S.sec))+'</p><p class="overview-intro">'+html(U('summaryIntro'))+'</p><button type="button" class="overview-hero-link" data-route="publicaciones">'+html(U('summaryExplore'))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>');
 const heroMetric=summaryElement('div','overview-hero-metric','<div class="overview-period"><span>'+html(U('summaryPeriod'))+'</span><strong>'+html(period)+'</strong></div>');
 cards[0].classList.add('overview-total');cards[0].querySelector('.stat-big').appendChild(summaryElement('span','overview-record-unit',html(U('summaryCountUnit'))));heroMetric.appendChild(cards[0]);hero.appendChild(intro);hero.appendChild(heroMetric);box.appendChild(hero);
 const metrics=summaryElement('div','overview-metrics');[3,4,5,6].forEach(i=>metrics.appendChild(cards[i]));box.appendChild(metrics);
 const trajectory=summaryElement('div','overview-trajectory');
 const chart=annualSummaryChart(rows);
 const annual=summaryElement('section','overview-annual');
 annual.appendChild(summaryHeading('annualTitle','annualDesc','<span class="overview-period-tag">'+html(period)+'</span>'));
 annual.appendChild(summaryElement('div','overview-chart-canvas',chart.svg));
 annual.appendChild(summaryElement('div','overview-chart-footer','<span><i class="overview-peak-mark" aria-hidden="true"></i>'+html(U('annualPeak'))+' <strong>'+html(chart.peak)+'</strong></span>'+chart.table));
 trajectory.appendChild(annual);
 const distribution=summaryElement('section','overview-distributions');distribution.appendChild(summaryHeading('summaryTypes'));[1,2].forEach(i=>distribution.appendChild(cards[i]));
 // Show the unindexed category as well when it has records; source calculations are unchanged.
 const unindexed=contarProcedencia(rows).ninguna;
 if(unindexed){const extra=summaryElement('div','lg','<span class="sw" style="background:#c8d4d6"></span>'+html(U('summaryOthers'))+' <b>'+number(unindexed)+'</b><span class="pct">'+(unindexed/rows.length*100).toFixed(1)+'%</span>');cards[2].querySelector('.legend').appendChild(extra);}
 [1,2].forEach(i=>{cards[i].querySelectorAll('circle').forEach(circle=>{if(circle.getAttribute('stroke')==='#b8b0a0')circle.setAttribute('stroke','#c8d4d6');});cards[i].querySelectorAll('.sw').forEach(swatch=>{if(swatch.getAttribute('style')?.includes('#b8b0a0'))swatch.setAttribute('style','background:#c8d4d6');});});
 trajectory.appendChild(distribution);box.appendChild(trajectory);
 const highlights=summaryElement('section','overview-highlights');highlights.appendChild(summaryHeading('summaryHighlights','summaryHighlightsDesc'));
 const paperGrid=summaryElement('div','overview-paper-grid');
 const citationMax=Math.max(...rows.map(r=>int0(r.CITADO_POR))),sjrMax=Math.max(...rows.map(r=>num(r.SJR)));
 const mostCited=rows.find(r=>int0(r.CITADO_POR)===citationMax);
 const highestSjr=rows.find(r=>num(r.SJR)===sjrMax);UI.summaryPapers=[mostCited,highestSjr];
 [14,15].forEach((index,i)=>{
  const card=cards[index],row=UI.summaryPapers[i];card.classList.add('overview-paper');
  const score=card.querySelector('.sc-big');
  if(score){const measure=summaryElement('div','overview-paper-score');measure.appendChild(score);measure.appendChild(summaryElement('span','overview-paper-score-unit',html(i===0?U('citations'):'SJR')));card.appendChild(measure);}
  if(row){card.querySelector('.sc-title').textContent=row.TITULO;card.querySelector('.sc-meta').textContent=titleCase(row.NOMBRE_AUTOR)+' · '+row.ANO;card.appendChild(summaryElement('button','overview-text-link overview-paper-link',''+html(U('summaryFullPaper'))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i>'));const link=card.querySelector('.overview-paper-link');link.setAttribute('type','button');link.setAttribute('data-summary-paper',i);}
  paperGrid.appendChild(card);
 });
 highlights.appendChild(paperGrid);box.appendChild(highlights);
 const areas=summaryElement('section','overview-areas');areas.appendChild(summaryHeading('summaryAreas','summaryAreasDesc','<button type="button" class="overview-text-link" data-tool-route="analisis" data-tool-view="domain">'+html(U('summaryAllAreas'))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>'));
 const areaGrid=summaryElement('div','overview-area-grid');[7,8,9,10,11,12].forEach(i=>areaGrid.appendChild(cards[i]));areas.appendChild(areaGrid);box.appendChild(areas);
 const collaboration=summaryElement('section','overview-collaboration');collaboration.appendChild(cards[13]);collaboration.appendChild(summaryElement('div','overview-network-link','<p>'+html(U('summaryNetworkDesc'))+'</p><button type="button" class="overview-text-link" data-tool-route="perfiles" data-tool-view="collaboration">'+html(U('summaryNetwork'))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>'));box.appendChild(collaboration);
 // Any additional original summary cards remain visible if the source grows.
 const used=new Set([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]);const rest=cards.filter((_,i)=>!used.has(i));if(rest.length){const extra=summaryElement('div','overview-area-grid');rest.forEach(card=>extra.appendChild(card));box.appendChild(extra);}
 // Los accesos a Comparar académicos y Áreas y evolución viven en la barra lateral; no se repiten bajo la portada.
 box.appendChild(summaryElement('div','overview-method','<i class="fa-solid fa-circle-info" aria-hidden="true"></i><p><strong>'+html(U('summaryMethod'))+'</strong>'+html(U('countOriginal'))+'</p>'));
}
function resizeVisible(){
 window.requestAnimationFrame(()=>{
  document.querySelectorAll('.panel.active .js-plotly-plot').forEach(p=>{if(p.getClientRects().length)try{Plotly.Plots.resize(p);}catch(e){console.warn('Plot resize',e);}});
  try{if($.fn.dataTable)$.fn.dataTable.tables({visible:true,api:true}).columns.adjust();}catch(e){console.warn('Table resize',e);}
  if(UI.route==='perfiles'&&UI.profile==='collaboration'){if(_map)_map.invalidateSize();if(_net)_net.fit({animation:false});}
 });
}
function errorMessage(error){console.error(error);$id('app_error').textContent=U('loadError');$id('app_error').hidden=false;}
function renderProfile(){
 const group=UI.profile;$id('perfil-individual').style.display='';document.querySelectorAll('[data-profile-panel]').forEach(p=>p.hidden=p.dataset.profilePanel!==group);document.querySelectorAll('[data-profile-view]').forEach(b=>{b.classList.toggle('on',b.dataset.profileView===group);b.setAttribute('aria-pressed',String(b.dataset.profileView===group));});
 const {dfFull,dv}=perfilCtx();const sig=signature([S.perfSel,S.perfAutor,S.perfIndex]);
 if(!dv.length){$id('profile_card').innerHTML='<div class="empty">'+html(U('empty'))+'</div>';$id('perfil_metrics').replaceChildren();document.querySelectorAll('[data-profile-panel="'+group+'"] .viz').forEach(v=>{let empty=v.querySelector('.profile-empty');if(!empty){empty=document.createElement('p');empty.className='profile-empty empty';v.appendChild(empty);}empty.textContent=U('empty');[...v.children].forEach(c=>{if(c!==empty)c.hidden=true;});});UI.cache.delete('profile:'+group);return;}
 document.querySelectorAll('.profile-empty').forEach(e=>{const parent=e.parentElement;e.remove();[...parent.children].forEach(c=>c.hidden=false);});
 renderFicha(dv);renderPerfilMetrics(dv);
 if(UI.cache.get('profile:'+group)!==sig){
  if(group==='overview'){plotAnios(dv);plotPerfilTrayectoria(dv);plotPerfilDist(dv);renderPerfilExtra(dv);}
  if(group==='publications'){renderPerfilPubs(dv);renderPerfilRevistas(dv);plotFuentes(dv);}
  if(group==='topics'){$id('compare_sel').innerHTML='';$id('v_words_title').textContent=LBLT('Palabras clave más frecuentes');plotSankey(dv);plotPalabras(dv);}
  if(group==='collaboration'){renderPerfilCoautores(dv,dfFull);plotRed(dfFull,S.perfSel==='Institucionales'?null:S.perfAutor);plotMapa(dv);}
  if(group==='similarity'){const highlighted=S.perfSel==='Institucionales'?null:S.perfAutor;plotDendro('v_dendro1',dfFull,'euclidean',highlighted);plotDendro('v_dendro2',dfFull,'correlation',highlighted);}
  UI.cache.set('profile:'+group,sig);
 }
}
function analyticsControls(rows){
 const sig=signature();if(UI.cache.get('analytics:controls')===sig)return;
 const a=$id('ana_author_a'),b=$id('ana_author_b'),oldA=a.value,oldB=b.value;delete a.dataset.ready;
 wireAnalyticsControls(rows);
 if([...a.options].some(o=>o.value===oldA))a.value=oldA;
 if([...b.options].some(o=>o.value===oldB))b.value=oldB;
 UI.cache.set('analytics:controls',sig);
}
function renderAnalysis(){
 const which=UI.analysis;document.querySelectorAll('[data-analysis-view]').forEach(b=>{b.classList.toggle('on',b.dataset.analysisView===which);b.setAttribute('aria-pressed',String(b.dataset.analysisView===which));});
 if(which==='indicators'){S.tab='indicadores';setPanel('p-indicadores');buildIndicadores();return;}
 if(which==='domain'){S.tab='dominio';setPanel('p-dominio');buildDomPalabras();buildDominio();return;}
 S.tab='analitica';setPanel('p-analitica');document.querySelectorAll('[data-analytics-panel]').forEach(p=>p.hidden=p.dataset.analyticsPanel!==which);
 const title=$id('p-analitica').querySelector('.panel-title'),desc=$id('p-analitica').querySelector('.panel-desc');title.textContent=U({insights:'insights',comparison:'comparison',opportunities:'opportunities'}[which]);desc.textContent=U({insights:'insightsDesc',comparison:'compareDesc',opportunities:'opportunitiesDesc'}[which]);
 const rows=base();analyticsControls(rows);
 if(which==='comparison')comparator.refresh();
 if(!rows.length){['ana_insights','ana_continuity','ana_search_results','ana_compare_summary','ana_opportunities'].forEach(id=>$id(id).innerHTML='<div class="empty">'+html(U('empty'))+'</div>');$id('ana_chi_legend').replaceChildren();try{Plotly.purge('ana_chi_plot');}catch(e){console.warn(e);}killDT('#ana_chi_table');return;}
 if(which==='insights'){renderInsights(rows);renderContinuityAlert(rows);runGlobalSearch($id('ana_search').value);}
 if(which==='comparison')runChiCompare();
 if(which==='opportunities')renderOpportunities(rows);
}
function fillOptions(id,items,selected){const el=$id(id);el.replaceChildren();items.forEach(([value,label])=>{const option=document.createElement('option');option.value=value;option.textContent=label;el.appendChild(option);});el.value=items.some(x=>x[0]===selected)?selected:items[0]?.[0]||'';return el.value;}
function catalogueFilter(){
 const rows=base();const authors=uniq(rows.map(r=>r.NOMBRE_AUTOR).filter(Boolean)).sort();UI.cat.author=fillOptions('catalogue_author',[['',U('allAuthors')],...authors.map(a=>[a,titleCase(a)])],UI.cat.author);
 areaFilter.render(rows);
 const quartiles=uniq(rows.map(r=>String(r.QUARTILE||'')).filter(Boolean)).sort();UI.cat.quartile=fillOptions('catalogue_quartile',[['',U('allQuartiles')],...quartiles.map(q=>[q,/^Q[1-4]$/i.test(q)?q:U('noQuartile')])],UI.cat.quartile);
 const tokens=fold(UI.cat.query).trim().split(/\s+/).filter(Boolean);
 const matches=rows.filter(r=>areaFilter.matches(r)&&(!UI.cat.author||r.NOMBRE_AUTOR===UI.cat.author)&&(!UI.cat.quartile||r.QUARTILE===UI.cat.quartile)&&(!tokens.length||tokens.every(t=>fold(HEADERS.map(h=>r[h]||'').join(' ')).includes(t))));
 const docs=catalogueDocuments(matches,UI.cat.mode);docs.sort((a,b)=>UI.cat.sort==='cites'?b.citations-a.citations||int0(b.record.ANO)-int0(a.record.ANO):UI.cat.sort==='title'?String(a.record.TITULO).localeCompare(String(b.record.TITULO),S.lang):int0(b.record.ANO)-int0(a.record.ANO)||b.citations-a.citations);
 UI.cat.docs=docs;const maxPage=Math.max(1,Math.ceil(docs.length/UI.cat.pageSize));UI.cat.page=Math.min(UI.cat.page,maxPage);return {docs,matches};
}
function docTags(doc){
 const row=doc.record;const q=String(row.QUARTILE||'').toUpperCase();const types=uniq(doc.rows.map(r=>r.TIPO_DOCUMENTO).filter(Boolean));let tags=/^Q[1-4]$/.test(q)?'<span class="q-badge q-'+q.toLowerCase()+'">'+html(q)+'</span>':'';
 tags+=types.map(t=>'<span class="chip">'+html(t==='Article'?U('journal'):t==='Conference paper'?U('conference'):t==='Review'?U('review'):t)+'</span>').join('');
 const collections=uniq(doc.rows.flatMap(r=>colecciones(r)));if(collections.length)tags+='<span class="ix ix-wos">'+html(collections.join(' · '))+'</span>';else if(doc.rows.some(tieneWos))tags+='<span class="ix ix-wos">WoS</span>';
 if(doc.rows.some(tieneScopus))tags+='<span class="ix ix-scopus">Scopus</span>';return tags;
}
function publicationButton(doc,index){return '<button type="button" class="paper-title" data-publication="'+index+'">'+display(doc.record.TITULO)+'</button>';}
function renderCatalogue(){
 const {docs,matches}=catalogueFilter();$id('catalogue_mode').value=UI.cat.mode;$id('catalogue_sort').value=UI.cat.sort;
 const workCount=catalogueDocuments(matches).length;$id('catalogue_count').innerHTML='<strong>'+number(workCount)+'</strong> '+html(U('works'))+' <span class="count-detail">· '+number(matches.length)+' '+html(U('records'))+'</span>';$id('catalogue_count').title=U('countNote');
 document.querySelectorAll('[data-layout]').forEach(b=>{b.classList.toggle('on',b.dataset.layout===UI.cat.layout);b.setAttribute('aria-pressed',String(b.dataset.layout===UI.cat.layout));});
 $id('catalogue_list').hidden=UI.cat.layout!=='list';$id('catalogue_pager').hidden=UI.cat.layout!=='list';$id('catalogue_table_wrap').hidden=UI.cat.layout!=='table';
 if(UI.cat.layout==='table'){
  const table='#catalogue_table';killDT(table);
  $(table).DataTable({data:docs.map((d,i)=>[publicationButton(d,i),int0(d.record.ANO),html(d.authors.map(titleCase).join('; ')),display(d.record.FUENTE),display(d.record.TIPO_DOCUMENTO),docTags(d),num(d.record.SJR),d.citations]),columns:[{title:U('papers'),className:'pub-title'},{title:U('year'),className:'dt-num'},{title:U('unitAuthors')},{title:U('source')},{title:U('type')},{title:U('indexing')+' / Q'},{title:'SJR',className:'dt-num'},{title:U('citations'),className:'dt-num'}],pageLength:12,order:UI.cat.sort==='cites'?[[7,'desc']]:UI.cat.sort==='title'?[[0,'asc']]:[[1,'desc']],language:dtLang(),scrollX:true,dom:'Bfrtip',buttons:[{extend:'csv',text:'↓ CSV',filename:()=>nombreExport('Catalogo')} ]});
 }else{
  const start=(UI.cat.page-1)*UI.cat.pageSize;const visible=docs.slice(start,start+UI.cat.pageSize);
  $id('catalogue_list').innerHTML=visible.length?'<div class="catalogue-papers">'+visible.map((d,j)=>'<article class="catalogue-paper"><div>'+publicationButton(d,start+j)+'<div class="paper-meta">'+html(d.authors.map(titleCase).join(' · '))+'<br>'+display(d.record.FUENTE)+'</div><div class="paper-tags">'+docTags(d)+'</div><div class="paper-record">'+(UI.cat.mode==='records'?html(U('originalAuthor'))+': '+html(titleCase(d.record.NOMBRE_AUTOR)):d.rows.length>1?number(d.rows.length)+' '+html(U('associatedRecords')):'')+'</div></div><div class="paper-number paper-year">'+int0(d.record.ANO)+'<small>'+U('year')+'</small></div><div class="paper-number">'+number(d.citations)+'<small>'+U('citations')+'</small></div></article>').join('')+'</div>':'<div class="empty">'+html(U('empty'))+'</div>';
  const max=Math.max(1,Math.ceil(docs.length/UI.cat.pageSize));$id('catalogue_pager').innerHTML='<button type="button" class="btn btn-ghost" data-catalogue-page="prev"'+(UI.cat.page<=1?' disabled':'')+'>'+html(U('prev'))+'</button><span>'+html(U('page'))+' '+UI.cat.page+' '+U('of')+' '+max+'</span><button type="button" class="btn btn-ghost" data-catalogue-page="next"'+(UI.cat.page>=max?' disabled':'')+'>'+html(U('next'))+'</button>';
 }
 $id('catalogue_csv').setAttribute('title',U('scopeFootnote'));
}
const FIELD_LABELS={UNIVERSIDAD:'Universidad',SESION:'Unidad académica',NOMBRE_AUTOR:'Académico(a) del registro',SCOPUS_ID:'Identificador Scopus del académico',WOS_ID:'Identificador Web of Science del académico',FIALIACION_SESION:'Filiación en la unidad',WOS:'Cuenta como WoS en reporte institucional',AUTORES:'Autores de la publicación',AUTORES_ID:'Identificadores de los autores',TITULO:'Título',WOS_Science_Index:'Identificador del registro WoS',WOS_COLECCION:'Colecciones de Web of Science',ANO:'Año',FUENTE:'Revista o fuente',SJR:'SJR',QUARTILE:'Cuartil',VOLUMEN:'Volumen',PAG_COMIENZO:'Página inicial',PAG_FINAL:'Página final',CITADO_POR:'Citas registradas',DOI:'DOI',LINK:'Enlace de la publicación','AFILIACIÓN_AUTOR':'Filiación del autor','AFILIACIÓN_AUTORES':'Filiaciones de los autores',PAISES_AUTORES:'Países de los autores',RESUMEN:'Resumen',AUTOR_PALABRAS_CLAVES:'Palabras clave de los autores',INDEX_PALABRAS_CLAVES:'Palabras clave indexadas',ISSN:'ISSN',IDIOMA:'Idioma',TIPO_DOCUMENTO:'Tipo de documento',AREA_ODS_ANID:'Área ODS (ANID)',CODIGO_ODS_ANID:'Código ODS (ANID)',NOMBRE_ODS_ANID:'Nombre ODS (ANID)',AREA_OCDE:'Área OCDE',CODIGO_OCDE:'Código OCDE',DISCIPLINA_OCDE:'Disciplina OCDE',SUBDISCIPLINA_OCDE:'Subdisciplina OCDE',AREA_COMPUTACION:'Área de especialidad',CATEGORIAS:'Subáreas de aplicación',AREAS:'Áreas de aplicación',URL_FOTO_ACADEMICO:'URL de fotografía del académico',URL_FOTO_DEPARTAMENTO:'URL de imagen de la unidad'};
function detailField(label,value){return '<div class="detail-field"><dt>'+html(label)+'</dt><dd>'+display(value)+'</dd></div>';}
function section(title,body){return '<section class="detail-section"><h3>'+html(title)+'</h3>'+body+'</section>';}
function publicationDetail(index,selectedDoc){
 const doc=selectedDoc||UI.cat.docs[index];if(!doc)return;const row=doc.record;const doi=doiOf(row);const links=[];
 if(doi)links.push(['DOI',safeLink('https://doi.org/'+doi)]);const originalLink=safeLink(row.LINK);if(originalLink)links.push([U('openPaper'),originalLink]);
 const authors=doc.authors.map(a=>'<button type="button" class="btn btn-ghost" data-academic="'+html(a)+'">'+html(titleCase(a))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>').join('');
 const classes=[detailField(U('specialty'),row.AREA_COMPUTACION),detailField(U('application'),row.AREAS),detailField(U('subareas'),row.CATEGORIAS),detailField(U('oecd'),[row.DISCIPLINA_OCDE,row.AREA_OCDE,row.SUBDISCIPLINA_OCDE,row.CODIGO_OCDE].filter(valid).join(' · ')),detailField(U('sdg'),[row.AREA_ODS_ANID,row.NOMBRE_ODS_ANID,row.CODIGO_ODS_ANID].filter(valid).join(' · ')),detailField(U('keywords'),[row.AUTOR_PALABRAS_CLAVES,row.INDEX_PALABRAS_CLAVES].filter(valid).join('; '))].join('');
 const records=doc.rows.map((record,i)=>'<details class="details-record"'+(doc.rows.length===1?' open':'')+'><summary>'+html(titleCase(record.NOMBRE_AUTOR||''))+' · '+html(U('fullRecord'))+' '+(i+1)+'</summary><div class="detail-table-wrap"><table class="detail-table"><tbody>'+HEADERS.map(h=>'<tr><th scope="row">'+html(S.lang==='es'?(FIELD_LABELS[h]||h):h.replace(/_/g,' '))+'</th><td>'+display(record[h])+'</td></tr>').join('')+'</tbody></table></div></details>').join('');
 $id('publication_detail').innerHTML='<h2 class="detail-headline" id="publication_title">'+display(row.TITULO)+'</h2><div class="detail-meta">'+display(row.FUENTE)+' · '+int0(row.ANO)+' · '+number(doc.citations)+' '+U('citations')+'</div><div class="detail-authors">'+display(row.AUTORES)+'</div><div class="paper-tags">'+docTags(doc)+'</div><div class="detail-links">'+links.filter(x=>x[1]).map(([label,url])=>'<a class="btn btn-ghost" href="'+html(url)+'" target="_blank" rel="noopener noreferrer">'+html(label)+' <i class="fa-solid fa-arrow-up-right-from-square" aria-hidden="true"></i></a>').join('')+'</div>'+section(U('unitAuthors'),'<div class="detail-links">'+authors+'</div>')+section(U('abstract'),'<p>'+html(valid(row.RESUMEN)?row.RESUMEN:U('noAbstract'))+'</p>')+section(U('classifications'),'<dl class="detail-grid">'+classes+'</dl>')+section(U('allFields'),'<p>'+html(U('moreFields'))+'</p>'+records);
 showDialog('publication_dialog');
}
function downloadText(text,filename,mime){const blob=new Blob(['\ufeff',text],{type:mime+';charset=utf-8'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=filename;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function catalogueCSV(){const rows=UI.cat.docs.flatMap(d=>d.rows);if(!rows.length)return;downloadText(rowsToCSV(rows),nombreExport('Publicaciones_registros')+'.csv','text/csv');}
function reportState(){
 const author=$id('report_scope').value==='author';const kind=author?'Perfiles':$id('report_kind').value;return {author,kind,name:$id('report_author').value};
}
function renderReportContext(){
 const {author,kind,name}=reportState();$id('report_author_box').hidden=!author;$id('report_kind').disabled=author;
 const rows=author?base().filter(r=>r.NOMBRE_AUTOR===name):base();$id('report_context').innerHTML='<strong>'+html(author?titleCase(name):S.sec)+'</strong><br>'+html(S.uni)+' · '+S.yMin+'–'+S.yMax+'<br>'+number(rows.length)+' '+U('records')+' · '+html(author?U('scopeAuthor'):LBLT(kind))+(author?'<p style="margin:9px 0 0;font-size:11px">'+html(U('reportAuthorHint'))+'</p>':'');
 $id('report_html').disabled=$id('report_csv').disabled=!rows.length;
}
function renderReports(){
 const names=uniq(base().map(r=>r.NOMBRE_AUTOR).filter(Boolean)).sort();fillOptions('report_author',names.map(a=>[a,titleCase(a)]),$id('report_author').value||S.perfAutor||names[0]||'');renderReportContext();
}
function reportPayload(format){
 const chosen=reportState();const previous={perfSel:S.perfSel,perfAutor:S.perfAutor,perfIndex:S.perfIndex};
 try{
  S.perfSel=chosen.author?'Por autor(a)':'Institucionales';S.perfAutor=chosen.name;S.perfIndex='Todas';
  const scope=reportScope(chosen.kind);if(!scope.d.length)return null;
  return {text:format==='html'?construirInforme(chosen.kind):rowsToCSV(scope.d),name:nombreArchivo(chosen.kind),kind:chosen.kind};
 }finally{Object.assign(S,previous);}
}
function exportReport(format){try{const payload=reportPayload(format);if(payload)downloadText(payload.text,payload.name+'.'+format,format==='html'?'text/html':'text/csv');}catch(e){errorMessage(e);}}
function directory(){
 const groups=[['summary',[['summary','resumen',null]]],['papers',[['uniqueWorks','publicaciones',null],['table','publicaciones','table'],['paperDetail','publicaciones',null]]],['people',[['profileSummary','perfiles','overview'],['profilePublications','perfiles','publications'],['profileTopics','perfiles','topics'],['profileCollaboration','perfiles','collaboration'],['profileSimilarity','perfiles','similarity']]],['analysis',[['indicators','analisis','indicators'],['insights','analisis','insights'],['comparison','analisis','comparison'],['areas','analisis','domain'],['opportunities','analisis','opportunities']]],['reports',[['reports','informes',null],['reportTables','analisis','indicators']]],['assistant',[['assistant','asistente',null]]]];
 $id('tools_directory').innerHTML=groups.map(([label,items])=>'<section class="tool-group"><h3>'+html(U(label))+'</h3>'+items.map(([text,route,view])=>'<button type="button" data-tool-route="'+route+'"'+(view?' data-tool-view="'+view+'"':'')+'>'+html(U(text))+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>').join('')+'</section>').join('');
 $id('tools_directory').appendChild(summaryElement('section','tool-group','<h3>'+html(U('allModules'))+'</h3><a class="btn btn-ghost" href="../index.html">'+html(U('allModules'))+' <i class="fa-solid fa-arrow-up-right-from-square" aria-hidden="true"></i></a>'));
}
function showDialog(id){const dialog=$id(id);if(!dialog.open)dialog.showModal();}
function closeDialog(id){const dialog=$id(id);if(dialog.open)dialog.close();const help=$id('help_modal');if(dialog.contains(help)){help.classList.remove('show');help.setAttribute('aria-hidden','true');document.body.appendChild(help);}}
function go(route,view,options={}){
 const compareAuthor=UI.route==='perfiles'&&S.perfSel!=='Institucionales'?S.perfAutor:null;
 if(['comparaciones','comparar','areas','dominio'].includes(route)){view=['comparaciones','comparar'].includes(route)?'comparison':'domain';route='analisis';}
 if(!['resumen','publicaciones','perfiles','analisis','informes','asistente'].includes(route))route='resumen';
 if(route==='asistente')UI.returnRoute=UI.route;
 UI.route=route;if(route==='perfiles'&&['overview','publications','topics','collaboration','similarity'].includes(view))UI.profile=view;
 if(route==='analisis'&&['indicators','insights','comparison','domain','opportunities'].includes(view))UI.analysis=view;
 if(route==='publicaciones'&&view==='table')UI.cat.layout='table';
 if(options.author){S.perfSel='Por autor(a)';S.perfAutor=options.author;controlsSelection('perf_sel',S.perfSel);refreshAutor();}
 document.querySelectorAll('#main_nav [data-route]').forEach(b=>{const active=b.dataset.route===route;if(active)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
 document.querySelectorAll('#main_nav [data-tool-route]').forEach(b=>{const active=b.dataset.toolRoute===route&&b.dataset.toolView===UI.analysis;if(active)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
 if(route==='analisis'&&['comparison','domain'].includes(UI.analysis))$id('main_nav').querySelector('[data-route="analisis"]').removeAttribute('aria-current');
 $id('assistant_link').classList.toggle('btn-primary',route==='asistente');$id('analysis_nav').hidden=route!=='analisis';
 S.tab=route;setPanel('p-'+(route==='analisis'?'indicadores':route));
 try{history.replaceState(null,'','#'+route+(route==='perfiles'?'/'+UI.profile:route==='analisis'?'/'+UI.analysis:''));}catch(e){console.warn('Navigation history',e);}
 refresh();
 if(route==='analisis'&&UI.analysis==='comparison'&&compareAuthor&&[...$id('ana_author_a').options].some(o=>o.value===compareAuthor)){$id('ana_author_a').value=compareAuthor;if($id('ana_author_b').value===compareAuthor)$id('ana_author_b').value=ANA_REST;runChiCompare();}
}
function refresh(){
 if(!UI.started)return;
 $id('app_error').hidden=true;translate();updateScope();
 try{
  if(UI.route==='resumen'){S.tab='resumen';buildResumen();}
  else if(UI.route==='publicaciones'){S.tab='publicaciones';renderCatalogue();}
  else if(UI.route==='perfiles'){S.tab='perfiles';renderProfile();}
  else if(UI.route==='analisis')renderAnalysis();
  else if(UI.route==='informes'){S.tab='informes';renderReports();}
  else if(UI.route==='asistente'){S.tab='asistente';buildChat(true);}
  applyFriendlyTooltips();i18nDynamic(document.body);translate();resizeVisible();
 }catch(e){errorMessage(e);}
}
function resetScope(){
 areaFilter.reset();
 S.afil='unidad';S.idx='todas';S.tipo='todos';S.col=[];initSlider();poblarFiltros2();refreshAutor();UI.cat.author='';UI.cat.quartile='';UI.cat.page=1;rebuild(true);
}
function init(){
 UI.started=true;translate();directory();
 const direct={scope_open:()=>showDialog('scope_dialog'),directory_open:()=>{directory();showDialog('tools_dialog');},directory_side:()=>{directory();showDialog('tools_dialog');},assistant_link:()=>go(UI.route==='asistente'?UI.returnRoute:'asistente'),scope_reset:resetScope,catalogue_csv:catalogueCSV,report_html:()=>exportReport('html'),report_csv:()=>exportReport('csv')};
 Object.entries(direct).forEach(([id,handler])=>$id(id).onclick=handler);
 let searchTimer; $id('catalogue_query').oninput=e=>{UI.cat.query=e.target.value;UI.cat.page=1;clearTimeout(searchTimer);searchTimer=setTimeout(()=>{if(UI.route==='publicaciones')renderCatalogue();},120);};
 [['catalogue_author','author'],['catalogue_quartile','quartile'],['catalogue_mode','mode'],['catalogue_sort','sort']].forEach(([id,key])=>$id(id).onchange=e=>{UI.cat[key]=e.target.value;UI.cat.page=1;renderCatalogue();resizeVisible();});
 ['report_kind','report_scope','report_author'].forEach(id=>$id(id).onchange=renderReportContext);
 document.addEventListener('click',e=>{
  const target=e.target;if(!(target instanceof Element))return;
  const close=target.closest('[data-close]');if(close){closeDialog(close.dataset.close);return;}
  const route=target.closest('[data-route]');if(route){go(route.dataset.route,route.dataset.route==='analisis'?'indicators':undefined);return;} // Análisis abre siempre en Indicadores
  const tool=target.closest('[data-tool-route]');if(tool){closeDialog('tools_dialog');go(tool.dataset.toolRoute,tool.dataset.toolView);return;}
  const profile=target.closest('[data-profile-view]');if(profile){go('perfiles',profile.dataset.profileView);return;}
  const analysis=target.closest('[data-analysis-view]');if(analysis){go('analisis',analysis.dataset.analysisView);return;}
  const layout=target.closest('[data-layout]');if(layout){UI.cat.layout=layout.dataset.layout;renderCatalogue();resizeVisible();return;}
  const page=target.closest('[data-catalogue-page]');if(page&&!page.disabled){UI.cat.page+=page.dataset.cataloguePage==='next'?1:-1;renderCatalogue();$id('catalogue_list').scrollIntoView({block:'start',behavior:'auto'});return;}
  const publication=target.closest('[data-publication]');if(publication){publicationDetail(Number(publication.dataset.publication));return;}
  const summaryPaper=target.closest('[data-summary-paper]');if(summaryPaper){const row=UI.summaryPapers[Number(summaryPaper.dataset.summaryPaper)];const doc=catalogueDocuments(base()).find(doc=>doc.rows.includes(row));if(doc)publicationDetail(null,doc);return;}
  const academic=target.closest('[data-academic]');if(academic){closeDialog('publication_dialog');go('perfiles','overview',{author:academic.dataset.academic});}
 });
 ['scope_dialog','tools_dialog','publication_dialog'].forEach(id=>{$id(id).addEventListener('click',e=>{if(e.target===$id(id)){const rect=$id(id).getBoundingClientRect();if(e.clientX<rect.left||e.clientX>rect.right||e.clientY<rect.top||e.clientY>rect.bottom)closeDialog(id);}});$id(id).addEventListener('close',()=>{const help=$id('help_modal');if($id(id).contains(help)){help.classList.remove('show');document.body.appendChild(help);}});});
 window.addEventListener('resize',resizeVisible);
 window.addEventListener('hashchange',()=>{const [route,view]=location.hash.slice(1).split('/');go(route,view);});
 const [route,view]=location.hash.slice(1).split('/');go(route||'resumen',view);
}
// Bridge the original filter and language handlers to the new navigation.
const originalWire=wire;wire=function(){originalWire();init();};
const originalSummary=buildResumen;buildResumen=function(){originalSummary();if(UI.started)tidySummary();};
const originalChiCompare=runChiCompare;runChiCompare=function(){originalChiCompare();comparator.refresh();};
rebuildTab=refresh;
const originalLanguage=applyLanguage;applyLanguage=function(){originalLanguage();if(UI.started)translate();};
const originalHelp=showFriendlyHelp;showFriendlyHelp=function(title,body){const openDialog=document.querySelector('dialog[open]');const modal=$id('help_modal');(openDialog||document.body).appendChild(modal);originalHelp(title,body);};
// Narrow inspection API for local verification; no user records are written by this interface.
window.ResearchAnalyserUI={go,refresh,catalogueDocuments,reportPayload,state:UI};
})();
