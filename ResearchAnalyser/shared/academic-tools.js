/* Shared presentation controls. Counts and comparisons use each module's original functions. */
(() => {
'use strict';
const WORDS = {
 es: {compare:'Comparar académicos',areas:'Áreas y evolución',shortcuts:'Explorar la investigación',one:'1 vs 1',all:'1 vs todos',reverse:'Todos vs 1',rest:'Resto de la unidad',choose:'Elegir con fotos',chooseTitle:'Elegir académico(a)',search:'Buscar por nombre',close:'Cerrar',empty:'No hay académicos con ese nombre.',previous:'Anterior',next:'Siguiente',of:'de',people:'académicos(as)',excluding:'sin',scope:'“Todos” corresponde al resto de la unidad en los filtros y el periodo activos; excluye al académico seleccionado.',same:'Elige dos académicos distintos para comparar.',noPeople:'No hay académicos en los filtros activos.',family:'Clasificación',term:'Valor de la clasificación',allAreas:'Sin filtrar por clasificación',allTerms:'Elige una clasificación',anyTerm:'Todos los valores',clear:'Quitar filtro de clasificación',profile:'Ver perfil',noPhoto:'Foto no disponible'},
 en: {compare:'Compare academics',areas:'Areas and trends',shortcuts:'Explore the research',one:'1 vs 1',all:'1 vs all',reverse:'All vs 1',rest:'Rest of the unit',choose:'Choose with photos',chooseTitle:'Choose an academic',search:'Search by name',close:'Close',empty:'No academics match that name.',previous:'Previous',next:'Next',of:'of',people:'academics',excluding:'excluding',scope:'“All” is the rest of the unit within the active filters and period, excluding the selected academic.',same:'Choose two different academics to compare.',noPeople:'No academics match the active filters.',family:'Classification',term:'Classification value',allAreas:'No classification filter',allTerms:'Choose a classification',anyTerm:'All values',clear:'Remove classification filter',profile:'View profile',noPhoto:'Photo unavailable'},
 pt: {compare:'Comparar acadêmicos',areas:'Áreas e evolução',shortcuts:'Explorar a pesquisa',one:'1 vs 1',all:'1 vs todos',reverse:'Todos vs 1',rest:'Restante da unidade',choose:'Escolher com fotos',chooseTitle:'Escolher acadêmico(a)',search:'Buscar por nome',close:'Fechar',empty:'Nenhum acadêmico com esse nome.',previous:'Anterior',next:'Próxima',of:'de',people:'acadêmicos(as)',excluding:'sem',scope:'“Todos” corresponde ao restante da unidade nos filtros e no período ativos, excluindo o acadêmico selecionado.',same:'Escolha dois acadêmicos diferentes para comparar.',noPeople:'Nenhum acadêmico nos filtros ativos.',family:'Classificação',term:'Valor da classificação',allAreas:'Sem filtro de classificação',allTerms:'Escolha uma classificação',anyTerm:'Todos os valores',clear:'Remover filtro de classificação',profile:'Ver perfil',noPhoto:'Foto indisponível'}
};
const escape = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm = value => String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
const words = lang => WORDS[lang] || WORDS.es;
const element = (tag,cls,content) => {const n=document.createElement(tag);n.className=cls;if(content!==undefined)n.innerHTML=content;return n;};
const initials = name => String(name).trim().split(/\s+/).filter(Boolean).slice(0,2).map(w=>w[0]).join('');
function photo(name,url,small=false){
 let safe='';try{const link=new URL(String(url));if(/^https?:$/.test(link.protocol))safe=link.href;}catch(e){}
 return '<span class="academic-photo'+(small?' academic-photo-small':'')+'"><span aria-hidden="true">'+escape(initials(name))+'</span>'+(safe?'<img src="'+escape(safe)+'" alt="'+escape(name)+'" loading="lazy" referrerpolicy="no-referrer">':'')+'</span>';
}
function imageFallback(root){root.querySelectorAll('.academic-photo img').forEach(img=>img.addEventListener('error',()=>{img.hidden=true;}));}
function shortcuts(lang){const w=words(lang);return '<nav class="academic-shortcuts" aria-label="'+escape(w.shortcuts)+'"><button class="btn btn-ghost" type="button" data-tool-route="analisis" data-tool-view="comparison"><i class="fa-solid fa-user-group" aria-hidden="true"></i>'+escape(w.compare)+'</button><button class="btn btn-ghost" type="button" data-tool-route="analisis" data-tool-view="domain"><i class="fa-solid fa-layer-group" aria-hidden="true"></i>'+escape(w.areas)+'</button></nav>';}
function createComparison(config){
 const a=document.getElementById(config.a),b=document.getElementById(config.b);
 const oldControls=a.closest('.controls');
 const shell=element('section','academic-comparator');shell.id='academic_comparator';
 shell.innerHTML='<div class="academic-mode" role="group"></div><p class="academic-scope"></p><div class="academic-pair"><article class="academic-side" data-compare-slot="a"><div class="academic-preview"></div><div class="academic-original-control"></div><div class="academic-actions"></div></article><span class="academic-versus" aria-hidden="true">vs</span><article class="academic-side" data-compare-slot="b"><div class="academic-preview"></div><div class="academic-original-control"></div><div class="academic-actions"></div></article></div><p class="academic-message" role="status"></p>';
 oldControls.parentElement.insertBefore(shell,oldControls);
 shell.querySelector('[data-compare-slot="a"] .academic-original-control').appendChild(a.closest('.control'));
 shell.querySelector('[data-compare-slot="b"] .academic-original-control').appendChild(b.closest('.control'));
 shell.querySelector('[data-compare-slot="a"] label').setAttribute('for',config.a);
 shell.querySelector('[data-compare-slot="b"] label').setAttribute('for',config.b);
 oldControls.classList.add('academic-variable-controls');
 const picker=element('dialog','academic-picker');picker.id='academic_picker_dialog';picker.setAttribute('aria-labelledby','academic_picker_title');
 picker.innerHTML='<div class="dialog-heading"><h2 id="academic_picker_title"></h2><button class="icon-btn" type="button" data-picker-close><i class="fa-solid fa-xmark" aria-hidden="true"></i></button></div><label class="sr-only" for="academic_picker_query"></label><input id="academic_picker_query" type="search" autocomplete="off"><p class="academic-picker-count" aria-live="polite"></p><div class="academic-picker-grid"></div><div class="academic-picker-pager"></div>';
 document.body.appendChild(picker);
 const state={slot:'a',query:'',page:1,pageSize:18};
 const list=()=>{const active=config.activeNames?new Set(config.activeNames()):null;return [...a.options].map(o=>o.value).filter(v=>v&&v!==config.rest&&(!active||active.has(v)));};
 const format=n=>new Intl.NumberFormat(config.lang()==='en'?'en-GB':config.lang()==='pt'?'pt-BR':'es-CL').format(n);
 function refresh(){
  const w=words(config.lang()),authors=list(),valueA=a.value,valueB=b.value;
  const mode=valueA===config.rest?'all-one':valueB===config.rest?'one-all':'one-one';
  shell.querySelector('.academic-mode').setAttribute('aria-label',w.compare);
  shell.querySelector('.academic-mode').innerHTML=[['one-one',w.one,authors.length<2],['one-all',w.all,!authors.length],['all-one',w.reverse,!authors.length]].map(([key,label,disabled])=>'<button type="button" class="academic-mode-button'+(mode===key?' on':'')+'" data-compare-mode="'+key+'" aria-pressed="'+(mode===key)+'"'+(disabled?' disabled':'')+'>'+escape(label)+'</button>').join('');
  shell.querySelector('.academic-scope').textContent=w.scope;
  for(const slot of ['a','b']){
   const selected=slot==='a'?valueA:valueB,other=slot==='a'?valueB:valueA,rows=config.rows(selected,other),names=config.names(rows),isRest=selected===config.rest;
   const name=isRest?w.rest:config.name(selected||'—');
   const members=isRest?'<div class="academic-group-photos">'+names.slice(0,4).map(n=>photo(config.name(n),config.photo(n),true)).join('')+(names.length>4?'<span class="academic-group-more">+'+format(names.length-4)+'</span>':'')+'</div>':photo(name,config.photo(selected));
   const groupNote=isRest?format(names.length)+' '+w.people+(other&&other!==config.rest?' · '+w.excluding+' '+config.name(other):''):config.unit();
   const side=shell.querySelector('[data-compare-slot="'+slot+'"]');
   side.querySelector('.academic-preview').innerHTML=members+'<div><span class="academic-slot-label">'+slot.toUpperCase()+'</span><h3>'+escape(name)+'</h3><p>'+escape(groupNote)+'</p><strong class="academic-work-count">'+format(config.count(rows))+' <span>'+escape(config.countLabel())+'</span></strong></div>';
   side.querySelector('.academic-actions').innerHTML='<button class="btn btn-ghost" type="button" data-choose-slot="'+slot+'"><i class="fa-regular fa-address-card" aria-hidden="true"></i>'+escape(w.choose)+'</button>'+(!isRest&&selected?'<button class="academic-profile-link" type="button" data-compare-profile="'+escape(selected)+'">'+escape(w.profile)+' <i class="fa-solid fa-arrow-right" aria-hidden="true"></i></button>':'');
   [...(slot==='a'?a:b).options].filter(o=>o.value===config.rest).forEach(o=>o.textContent=w.rest);
  }
  shell.querySelector('.academic-message').textContent=!authors.length?w.noPeople:(valueA!==config.rest&&valueA===valueB?w.same:'');
  shell.querySelector('.academic-message').hidden=!shell.querySelector('.academic-message').textContent;
  imageFallback(shell);
  if(picker.open)renderPicker();
 }
 function changeMode(mode){
  const authors=list();if(!authors.length)return;
  let selected=a.value!==config.rest?a.value:b.value!==config.rest?b.value:authors[0];
  if(!authors.includes(selected))selected=authors[0];
  if(mode==='one-all'){a.value=selected;b.value=config.rest;}
  else if(mode==='all-one'){a.value=config.rest;b.value=selected;}
  else{if(authors.length<2)return;a.value=selected;if(b.value===config.rest||b.value===selected)b.value=authors.find(n=>n!==selected);}
  config.run();
 }
 function renderPicker(){
  const w=words(config.lang()),authors=list().filter(name=>norm(config.name(name)).includes(norm(state.query))),max=Math.max(1,Math.ceil(authors.length/state.pageSize));state.page=Math.max(1,Math.min(max,state.page));
  const shown=authors.slice((state.page-1)*state.pageSize,state.page*state.pageSize);
  picker.querySelector('h2').textContent=w.chooseTitle+' · '+state.slot.toUpperCase();picker.querySelector('[data-picker-close]').setAttribute('aria-label',w.close);picker.querySelector('label').textContent=w.search;picker.querySelector('input').placeholder=w.search;
  picker.querySelector('.academic-picker-count').textContent=format(authors.length)+' '+w.people;
  picker.querySelector('.academic-picker-grid').innerHTML=shown.length?shown.map(name=>'<button class="academic-picker-person" type="button" data-picker-academic="'+escape(name)+'" aria-pressed="'+((state.slot==='a'?a:b).value===name)+'">'+photo(config.name(name),config.photo(name))+'<span><strong>'+escape(config.name(name))+'</strong><span>'+format(config.count(config.rows(name,null)))+' '+escape(config.countLabel())+'</span></span></button>').join(''):'<p class="empty">'+escape(w.empty)+'</p>';
  picker.querySelector('.academic-picker-pager').innerHTML='<button class="btn btn-ghost" type="button" data-picker-page="prev"'+(state.page===1?' disabled':'')+'>'+escape(w.previous)+'</button><span>'+state.page+' '+escape(w.of)+' '+max+'</span><button class="btn btn-ghost" type="button" data-picker-page="next"'+(state.page===max?' disabled':'')+'>'+escape(w.next)+'</button>';
  imageFallback(picker);
 }
 shell.addEventListener('click',event=>{
  const mode=event.target.closest('[data-compare-mode]');if(mode&&!mode.disabled){changeMode(mode.dataset.compareMode);return;}
  const pick=event.target.closest('[data-choose-slot]');if(pick){state.slot=pick.dataset.chooseSlot;state.query='';state.page=1;picker.querySelector('input').value='';renderPicker();if(!picker.open)picker.showModal();picker.querySelector('input').focus();return;}
  const profile=event.target.closest('[data-compare-profile]');if(profile)config.profile(profile.dataset.compareProfile);
 });
 picker.querySelector('input').oninput=event=>{state.query=event.target.value;state.page=1;renderPicker();};
 picker.addEventListener('click',event=>{
  if(event.target.closest('[data-picker-close]')){picker.close();return;}
  const person=event.target.closest('[data-picker-academic]');if(person){(state.slot==='a'?a:b).value=person.dataset.pickerAcademic;picker.close();config.run();return;}
  const page=event.target.closest('[data-picker-page]');if(page&&!page.disabled){state.page+=page.dataset.pickerPage==='next'?1:-1;renderPicker();}
 });
 return {refresh};
}
function createAreaFilter(config){
 const root=element('div','area-filter-controls');
 root.innerHTML='<div class="control"><label for="catalogue_area_family"></label><select id="catalogue_area_family"></select></div><div class="control"><label for="catalogue_area_term"></label><select id="catalogue_area_term"></select></div><button class="btn btn-ghost" type="button" data-area-clear></button>';
 document.getElementById(config.host).appendChild(root);
 const family=root.querySelector('#catalogue_area_family'),term=root.querySelector('#catalogue_area_term'),state={family:'',term:''};
 function render(rows){
  const w=words(config.lang());root.querySelector('[for="catalogue_area_family"]').textContent=w.family;root.querySelector('[for="catalogue_area_term"]').textContent=w.term;
  family.innerHTML='<option value="">'+escape(w.allAreas)+'</option>'+config.fields.map(key=>'<option value="'+escape(key)+'">'+escape(config.label(key))+'</option>').join('');family.value=state.family;
  const terms=state.family?[...new Set(rows.flatMap(row=>config.terms(row,state.family)))].sort((a,b)=>a.localeCompare(b,config.lang())):[];
  if(state.term&&!terms.includes(state.term))state.term='';
  term.innerHTML='<option value="">'+escape(state.family?(w.anyTerm||w.allTerms):w.allTerms)+'</option>'+terms.map(value=>'<option value="'+escape(value)+'">'+escape(value)+'</option>').join('');term.value=state.term;term.disabled=!state.family;
  root.querySelector('[data-area-clear]').textContent=w.clear;root.querySelector('[data-area-clear]').hidden=!state.family;
 }
 family.onchange=()=>{state.family=family.value;state.term='';config.change();};term.onchange=()=>{state.term=term.value;config.change();};root.querySelector('[data-area-clear]').onclick=()=>{state.family='';state.term='';config.change();};
 return {render,matches:row=>!state.family||!state.term||config.terms(row,state.family).includes(state.term),reset(){state.family='';state.term='';},state};
}
window.ResearchAcademicTools={createComparison,createAreaFilter,shortcuts};
})();
