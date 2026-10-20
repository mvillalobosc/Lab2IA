/* Appearance only: original data and numerical methods are unchanged. */
(() => {
 const module=document.body.dataset.module;
 if(module==='publicaciones'){
  Object.assign(C,{emerald:'#00A499',emerald2:'#006F67',amber:'#E77500',rust:'#394049',gris:'#394049',ink:'#282F36',muted:'#5F6C75',line:'#DFE5E9',paper:'#FFFFFF'});
  CAT.forEach((value,i)=>{if(value.toUpperCase()==='#EA7600')CAT[i]='#E77500';});
  if(typeof construirInforme==='function'){
   const originalReport=construirInforme;
   construirInforme=function(...args){return originalReport(...args).replace(/#EA7600/gi,'#E77500').replace(/#007A72/gi,'#006F67');};
  }
 } else if(module==='tesis'){
  Object.assign(C,{purple:'#E77500',purpleDark:'#984A00',purpleSoft:'#FFF4EB',orange:'#00A499',teal:'#E77500',blue:'#498BCA',gray:'#394049',line:'#DFE5E9'});
  const originalLayout=plotLayout;
  plotLayout=function(...args){const layout=originalLayout(...args);layout.colorway=['#E77500','#00A499','#394049','#8C4799','#498BCA','#EAAA00'];['xaxis','yaxis'].forEach(axis=>{if(layout[axis]?.gridcolor==='#F0EAF3')layout[axis].gridcolor='#EDF1F3';});return layout;};
  const originalDoc=baseReportDoc;
  baseReportDoc=function(...args){return originalDoc(...args)
   .replace(/--p:#8C4799;--o:#EA7600;--t:#00A499;--ink:#2A2340;--mut:#6B6480;--line:#E7DEF0;/g,'--p:#984A00;--o:#E77500;--t:#00A499;--ink:#394049;--mut:#5F6C75;--line:#DFE5E9;')
   .replace(/#FBF8FC|#F4EEF7/gi,'#F8FAFB').replace(/rgba\(140,71,153,.25\)/g,'rgba(57,64,73,.12)');};
 }
})();
