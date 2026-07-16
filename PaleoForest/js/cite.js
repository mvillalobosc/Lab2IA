/* Pie de referencias, compartido por la portada y los módulos.
   Las dos fichas salen de la MISMA función: no pueden divergir en botones ni
   en tratamiento visual. Requiere i18n.js (PAPER) e i18n-inf.js (ARACKAR). */
(function (root) {
'use strict';

const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g,
  c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ic = p => `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">${p}</svg>`;
const ICO = {
  arrowR: '<path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  copy: '<rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10" fill="none" stroke="currentColor" stroke-width="2"/>'
};

/* La publicación del pipeline. PAPER (i18n.js) no trae BibTeX; se arma aquí
   para que las dos referencias ofrezcan exactamente lo mismo. */
const PUB = {
  authors: PAPER.authors, year: PAPER.year, title: PAPER.title,
  journal: PAPER.journal, doi: PAPER.doi, url: PAPER.url, tail: '',
  cite: function () {
    return this.authors + ' (' + this.year + '). ' + this.title + '. ' +
           this.journal + '. https://doi.org/' + this.doi;
  },
  bibtex: function () {
    return '@article{conchatoro' + this.year + 'paleoforest,\n' +
      '  author  = {Concha-Toro, Camila and Riquelme-Zamora, Camilo and Aranciaga-Rolando, Mauricio and Villalobos-Cid, Manuel},\n' +
      '  title   = {' + this.title + '},\n' +
      '  journal = {' + this.journal + '},\n' +
      '  year    = {' + this.year + '},\n' +
      '  doi     = {' + this.doi + '}\n}';
  }
};
const DATA = ARACKAR;

function refLine(r) {
  return `<b>${esc(r.authors)}</b> (${esc(r.year)}). <i>${esc(r.title)}</i>. ${esc(r.journal)}` +
    (r.volume ? `, ${esc(r.volume)}, ${esc(r.article)}` : '') + '.';
}

/** Una ficha. `id` prefija los botones. Idénticas por construcción. */
function card(r, eyebrow, id, H) {
  return `<div class="refcol">
    <h2 class="eyebrow" id="${id}-h">${esc(eyebrow)}</h2>
    <div class="cite" role="group" aria-labelledby="${id}-h">
      <p class="cite-txt">${refLine(r)}</p>
      <div class="citebtns">
        <a class="toolbtn" href="${esc(r.url)}" target="_blank" rel="noopener"
           aria-label="${esc(H.open_ref)}: ${esc(r.short || r.authors)} ${esc(r.year)}">${ic(ICO.arrowR)}${esc(H.open_ref)}</a>
        <button class="toolbtn" data-cp="${id}-cite"
           aria-label="${esc(H.copy_cite)}: ${esc(r.short || r.authors)} ${esc(r.year)}">${ic(ICO.copy)}${esc(H.copy_cite)}</button>
        <button class="toolbtn" data-cp="${id}-bib"
           aria-label="${esc(H.copy_bib)}: ${esc(r.short || r.authors)} ${esc(r.year)}">${ic(ICO.copy)}${esc(H.copy_bib)}</button>
      </div>
    </div>
  </div>`;
}

function footerHTML(lang) {
  const H = I18N_HUB[lang];
  return `<div class="foot-in">
    <div class="refgrid">
      ${card(PUB, H.cr_pub, 'pub', H)}
      ${card(DATA, H.cr_data, 'dat', H)}
    </div>
    <div class="foot-bar"><span>DIINF · Universidad de Santiago de Chile</span></div>
  </div>`;
}

/** `onCopy(texto)` recibe el contenido a copiar. */
function wireFooter(el, onCopy) {
  const map = {
    'pub-cite': () => PUB.cite(), 'pub-bib': () => PUB.bibtex(),
    'dat-cite': () => DATA.cite(), 'dat-bib': () => DATA.bibtex()
  };
  Array.prototype.forEach.call(el.querySelectorAll('[data-cp]'), b => {
    b.onclick = () => onCopy(map[b.dataset.cp]());
  });
}

root.PFCite = { footerHTML: footerHTML, wireFooter: wireFooter, PUB: PUB, DATA: DATA };

})(typeof window !== 'undefined' ? window : globalThis);
