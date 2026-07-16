/* Portada: reparte hacia el módulo 1 (inferencia) y el módulo 2 (paisajes). */
(function () {
  'use strict';
  const $ = (s, r) => (r || document).querySelector(s);
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const ic = p => `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">${p}</svg>`;
  const copy = txt => { try { navigator.clipboard.writeText(txt); } catch (e) {} };
  const I = {
    arrowR: '<path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    grid: '<rect x="3" y="3" width="8" height="8" rx="1.5" fill="none" stroke="currentColor" stroke-width="2"/><rect x="13" y="3" width="8" height="8" rx="1.5" fill="none" stroke="currentColor" stroke-width="2"/><rect x="3" y="13" width="8" height="8" rx="1.5" fill="none" stroke="currentColor" stroke-width="2"/><rect x="13" y="13" width="8" height="8" rx="1.5" fill="none" stroke="currentColor" stroke-width="2"/>',
    tree: '<path d="M4 12h4M8 5v14M8 5h6M8 12h6M8 19h6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="16" cy="5" r="2.2" fill="currentColor"/><circle cx="16" cy="12" r="2.2" fill="currentColor"/><circle cx="16" cy="19" r="2.2" fill="currentColor"/>',
    scatter: '<circle cx="6" cy="17" r="2" fill="currentColor"/><circle cx="10" cy="9" r="2" fill="currentColor"/><circle cx="17" cy="13" r="2" fill="currentColor"/><circle cx="14" cy="5" r="2" fill="currentColor"/><circle cx="19" cy="19" r="2" fill="currentColor"/>',
    clock: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 7v5l3 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    off: '<path d="M12 3v9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M6.5 6.8a8 8 0 1 0 11 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    doc: '<path d="M6 3h8l4 4v14H6z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M14 3v4h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10" fill="none" stroke="currentColor" stroke-width="2"/>'
  };

  let tw;
  function toast(msg) {
    if (!tw) { tw = document.createElement('div'); tw.className = 'toast-wrap'; tw.setAttribute('role', 'status'); tw.setAttribute('aria-live', 'polite'); document.body.appendChild(tw); }
    const e = document.createElement('div'); e.className = 'toast'; e.textContent = msg;
    tw.appendChild(e);
    const raf = (typeof requestAnimationFrame === 'function') ? requestAnimationFrame : (f => setTimeout(f, 16));
    raf(() => e.classList.add('on'));
    setTimeout(() => { e.classList.remove('on'); setTimeout(() => e.remove(), 250); }, 2100);
  }

  let lang = (localStorage.getItem('pf_lang') || (navigator.language || 'es').slice(0, 2).toLowerCase());
  if (['es', 'en', 'pt'].indexOf(lang) < 0) lang = 'es';

  function forestSVG() {
    let s = '<svg class="hub-forest" viewBox="0 0 1200 340" preserveAspectRatio="xMidYMid slice" aria-hidden="true">';
    const rnd = (n => () => (n = (n * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff)(20260715);
    for (let i = 0; i < 26; i++) {
      const x = 20 + rnd() * 1160, y = 40 + rnd() * 260, sc = .5 + rnd() * .9, o = .07 + rnd() * .14;
      s += `<g transform="translate(${x.toFixed(1)},${y.toFixed(1)}) scale(${sc.toFixed(2)})" opacity="${o.toFixed(2)}" stroke="#fff" fill="none" stroke-width="2.4" stroke-linecap="round">
        <path d="M-26 0h13M-13 -18v36M-13 -18h13M-13 0h13M-13 18h13"/>
        <circle cx="0" cy="-18" r="3.1" fill="#fff" stroke="none"/><circle cx="0" cy="0" r="3.1" fill="#fff" stroke="none"/><circle cx="0" cy="18" r="3.1" fill="#fff" stroke="none"/>
      </g>`;
    }
    return s + '</svg>';
  }

  function render() {
    const H = I18N_HUB[lang], L = I18N[lang];
    $('#brand').innerHTML = `${logoSVG()}<div class="brand-txt"><div class="k">${esc(H.hubName)}</div><div class="s">${esc(H.hubSub)}</div></div>`;
    $('#langs').innerHTML = ['es', 'en', 'pt'].map(l =>
      `<button class="lang ${l === lang ? 'on' : ''}" data-lang="${l}" lang="${l}"
         aria-label="${esc(I18N[l]._flag)}" aria-pressed="${l === lang}">${FLAGS[l]}</button>`).join('');
    $('#langs').querySelectorAll('.lang').forEach(b => b.onclick = () => {
      lang = b.dataset.lang; localStorage.setItem('pf_lang', lang);
      document.documentElement.lang = lang; render();
    });

    $('#main').innerHTML = `
      <div class="wrap">
        <section class="hub-hero">
          ${forestSVG()}
          <div class="hub-hero-in">
            <div class="eyebrow" style="color:#7fded4">${esc(H.hubEyebrow)}</div>
            <h1>${esc(H.hubTitle)}</h1>
            <p class="lead">${esc(H.hubLead)}</p>
          </div>
        </section>

        <section class="hub-cards">
          <a class="hub-card m1" href="inferencia.html">
            <div class="hub-k">${esc(H.m1Kicker)}</div>
            <h2>${esc(H.m1Name)}</h2>
            <p>${esc(H.m1Desc)}</p>
            <div class="hub-subs">
              <div class="hub-sub"><span class="hub-si">${ic(I.grid)}</span><div><span class="t">${esc(H.m1a)}</span><span class="d">${H.m1aD}</span></div></div>
              <div class="hub-sub"><span class="hub-si">${ic(I.tree)}</span><div><span class="t">${esc(H.m1b)}</span><span class="d">${H.m1bD}</span></div></div>
            </div>
            <span class="hub-go">${esc(H.enter)}${ic(I.arrowR)}</span>
          </a>

          <a class="hub-card m2" href="pipeline.html">
            <div class="hub-k">${esc(H.m2Kicker)}</div>
            <h2>${esc(H.m2Name)}</h2>
            <p>${esc(H.m2Desc)}</p>
            <div class="hub-subs">
              <div class="hub-sub"><span class="hub-si">${ic(I.scatter)}</span><div><span class="t">${esc(H.m2a)}</span><span class="d">${H.m2aD}</span></div></div>
              <div class="hub-sub"><span class="hub-si">${ic(I.clock)}</span><div><span class="t">${esc(H.m2b)}</span><span class="d">${H.m2bD}</span></div></div>
            </div>
            <span class="hub-go">${esc(H.enter)}${ic(I.arrowR)}</span>
          </a>
        </section>

        <section class="card pad" style="margin-top:22px">
          <div class="eyebrow">${esc(H.hubFlowT)}</div>
          <div class="hub-flow">
            ${H.hubFlow.map((f, i) => `
              <div class="hub-fstep">
                <span class="hub-fn">${i + 1}</span>
                <div><b>${esc(f[0])}</b><p>${f[1]}</p></div>
              </div>${i < H.hubFlow.length - 1 ? '<span class="hub-farrow">' + ic(I.arrowR) + '</span>' : ''}`).join('')}
          </div>
          <div class="notice" style="margin-top:16px">${ic(I.doc)}<div>${H.hubNote}</div></div>
        </section>
      </div>`;

    $('#foot').innerHTML = PFCite.footerHTML(lang);
    PFCite.wireFooter($('#foot'), txt => { try { navigator.clipboard.writeText(txt); } catch (e) {} toast(I18N_HUB[lang].copied); });
  }

  document.documentElement.lang = lang;
  render();
})();
