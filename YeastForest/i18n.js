/* Local interface translations. Dataset identifiers and recorded values are preserved. */
(() => {
  'use strict';
  const dictionary = window.BF_TRANSLATIONS;
  const help = window.BF_HELP_TRANSLATIONS;
  const originalText = new WeakMap();
  const originalAttributes = new WeakMap();
  const helpSections = [...document.querySelectorAll('.help-sec')];
  const spanishHelp = helpSections.map(s => s.innerHTML);
  let language = 'es', scheduled = false;
  const changedRoots = new Set();
  try { const saved = localStorage.getItem('bf-interface-language'); if (['es','en','pt-BR'].includes(saved)) language = saved; } catch (_) {}
  const phrases = Object.keys(dictionary).filter(k => k.length >= 5 || ['país'].includes(k)).sort((a,b) => b.length-a.length);
  const escape = s => s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  const phrasePattern = new RegExp(phrases.map(escape).join('|'),'g');
  function translate(source) {
    if (language === 'es' || !source) return source;
    const trimmed = source.trim().replace(/\s+/g,' '), column = language === 'en' ? 0 : 1;
    let result;
    if (dictionary[trimmed]) result = dictionary[trimmed][column];
    else if (/^Página \d+ de \d+$/.test(trimmed)) {
      const [page,total] = trimmed.match(/\d+/g); result = language==='en'?`Page ${page} of ${total}`:`Página ${page} de ${total}`;
    } else {
      result = trimmed.replace(phrasePattern, (key,offset) => {
        // Preserve matches inside words, identifiers and source tokens.
        if ((offset && /[\p{L}_]/u.test(trimmed[offset-1])) || /[\p{L}_]/u.test(trimmed[offset+key.length]||'')) return key;
        return dictionary[key][column];
      });
    }
    if(language==='en')result=result.replace(/([0-9.,]+) de (?=[0-9])/g,'$1 of ');
    return source.slice(0,source.length-source.trimStart().length)+result+source.slice(source.trimEnd().length);
  }
  function isSourceData(node) {
    const p = node.nodeType===1 ? node : node.parentElement;
    return !p || !!p.closest('script,style,.tsvg,.help-sec,[data-i18n-preserve],#metaBody td:not(:first-child),.strain-meta dd,.gene-desc:not(.empty),.genes-wrap .gchip,.leg-chips .lchip[data-cl],#legendScroll .chip[data-group]');
  }
  function translateText(node) {
    if(isSourceData(node)||!node.nodeValue.trim())return;
    let record=originalText.get(node);
    if(!record || node.nodeValue!==record.rendered) record={source:node.nodeValue,rendered:node.nodeValue};
    const rendered=translate(record.source);record.rendered=rendered;originalText.set(node,record);
    if(node.nodeValue!==rendered)node.nodeValue=rendered;
  }
  function apply(roots = [document.body]) {
    observer.disconnect();
    function process(node){
      if(node.nodeType===3){translateText(node);return;}
      if(node.nodeType!==1||node.closest('#languageSwitch'))return;
      let record=originalAttributes.get(node)||{};
      for(const attr of ['title','placeholder','aria-label']){
        const value=node.getAttribute(attr);if(value===null)continue;
        if(!record[attr]||value!==record[attr].rendered)record[attr]={source:value,rendered:value};
        const translated=translate(record[attr].source);record[attr].rendered=translated;
        if(value!==translated)node.setAttribute(attr,translated);
      }
      originalAttributes.set(node,record);
    }
    for(const root of roots){
      if(!root.isConnected||isSourceData(root))continue;
      process(root);
      if(root.nodeType!==1)continue;
      const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT,{acceptNode(node){return isSourceData(node)?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT;}});
      while(walker.nextNode())process(walker.currentNode);
    }
    document.documentElement.lang=language;
    document.title=language==='en'?'Phylogenetic Forest · Saccharomyces · USACH':language==='pt-BR'?'Floresta Filogenética · Saccharomyces · USACH':'Bosque Filogenético · Saccharomyces · USACH';
    document.querySelectorAll('[data-language]').forEach(b=>{const active=b.dataset.language===language;b.classList.toggle('on',active);b.setAttribute('aria-pressed',String(active));});
    observer.observe(document.body,{childList:true,characterData:true,subtree:true,attributes:true,attributeFilter:['title','placeholder','aria-label']});
  }
  const observer=new MutationObserver(records=>{for(const r of records){if(r.type==='childList')for(const n of r.addedNodes)changedRoots.add(n);else changedRoots.add(r.target);}if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;const roots=[...changedRoots];changedRoots.clear();apply(roots);});});
  function setLanguage(next){
    if(!['es','en','pt-BR'].includes(next))return;
    language=next;
    helpSections.forEach((section,i)=>{
      if(next==='es')section.innerHTML=spanishHelp[i];
      else {const [title,body]=help[next][i];section.innerHTML=`<h3><span class="n">${i+1}</span>${title}</h3>${body}`;}
      section.lang=next;
    });
    try{localStorage.setItem('bf-interface-language',language);}catch(_){}
    apply();
    const status=document.getElementById('languageStatus');status.textContent=next==='es'?'Idioma: español':next==='en'?'Language: English':'Idioma: português do Brasil';
  }
  document.getElementById('languageSwitch').addEventListener('click',e=>{const button=e.target.closest('[data-language]');if(button)setLanguage(button.dataset.language);});
  window.BF_i18n={setLanguage,apply,translate,get language(){return language;}};
  setLanguage(language);
})();
