/* Recorrido guiado, genérico.

   El módulo 2 ya tenía uno propio dentro de app.js. Este es el mismo mecanismo
   —máscara con agujero, anillo y tarjeta— pero sin saber nada de la app: recibe
   los objetivos y los pasos. Así el módulo 1 no necesita una copia que después
   se desincronice.

   PFTour.start({
     targets: ['#sel1', '#sel2'],           // uno por paso
     steps:   [[titulo, texto], ...],       // mismo largo que targets
     labels:  { skip, prev, next, done },
     before:  i => {}                       // opcional: preparar la vista del paso i
   })
*/
(function (root) {
'use strict';

const $ = (s, r) => (r || document).querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g,
  c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let bk = null, cur = 0, cfg = null;

function end() { if (bk) { bk.classList.remove('on'); setTimeout(() => { if (bk && !bk.classList.contains('on')) { bk.remove(); bk = null; } }, 250); } }

function show() {
  if (!bk || !cfg) return;
  const step = cfg.steps[cur];
  if (cfg.before) { try { cfg.before(cur); } catch (e) {} }
  const tgt = document.querySelector(cfg.targets[cur]);
  if (!tgt) {
    /* Saltar es mejor que reventar, pero un salto silencioso esconde que la
       guía está incompleta: el usuario ve 1/13 y después 6/13. Se avisa. */
    if (typeof console !== 'undefined' && console.warn)
      console.warn('[tour] paso ' + (cur + 1) + '/' + cfg.steps.length + ' sin objetivo: ' + cfg.targets[cur]);
    if (cur < cfg.steps.length - 1) { cur++; show(); } else end();
    return;
  }
  try { tgt.scrollIntoView({ block: 'center', behavior: 'smooth' }); } catch (e) {}
  const r = tgt.getBoundingClientRect();
  const ring = $('.tour-ring', bk), card = $('.tour-card', bk), mask = $('.tour-mask', bk);
  const pad = 6, rx = r.left - pad, ry = r.top - pad, rw = r.width + pad * 2, rh = r.height + pad * 2;
  ring.style.left = rx + 'px'; ring.style.top = ry + 'px';
  ring.style.width = rw + 'px'; ring.style.height = rh + 'px';
  mask.style.setProperty('--m', `radial-gradient(circle at ${r.left + r.width / 2}px ${r.top + r.height / 2}px, transparent ${Math.max(rw, rh) / 1.4}px, #000 ${Math.max(rw, rh) / 1.2}px)`);
  $('.tc-eye', bk).textContent = (cur + 1) + ' / ' + cfg.steps.length;
  $('.tour-card h4', bk).textContent = step[0];
  $('.tour-card p', bk).innerHTML = step[1];
  $('#tr-prev', bk).style.visibility = cur === 0 ? 'hidden' : 'visible';
  $('#tr-next', bk).textContent = cur === cfg.steps.length - 1 ? cfg.labels.done : cfg.labels.next;
  let top = ry + rh + 12; if (top + 200 > innerHeight) top = Math.max(12, ry - 210);
  let left = Math.min(Math.max(12, r.left), innerWidth - 350);
  card.style.top = top + 'px'; card.style.left = left + 'px';
}

function start(c) {
  cfg = c;
  if (!cfg || !cfg.steps || !cfg.steps.length) return;
  if (bk) bk.remove();
  bk = document.createElement('div');
  bk.className = 'tour-bk';
  bk.setAttribute('role', 'dialog');
  bk.setAttribute('aria-modal', 'true');
  bk.innerHTML = `<div class="tour-mask"></div><div class="tour-ring"></div>
    <div class="tour-card"><div class="tc-eye"></div><h4></h4><p></p>
      <div class="tour-foot">
        <button class="toolbtn" id="tr-skip">${esc(cfg.labels.skip)}</button><span class="sp" style="flex:1"></span>
        <button class="toolbtn" id="tr-prev">${esc(cfg.labels.prev)}</button>
        <button class="btn" id="tr-next">${esc(cfg.labels.next)}</button>
      </div></div>`;
  document.body.appendChild(bk);
  $('#tr-skip', bk).onclick = end;
  $('#tr-next', bk).onclick = () => { if (cur >= cfg.steps.length - 1) end(); else { cur++; show(); } };
  $('#tr-prev', bk).onclick = () => { if (cur > 0) { cur--; show(); } };
  bk.addEventListener('keydown', e => { if (e.key === 'Escape') end(); });
  cur = 0;
  bk.classList.add('on');
  show();
  try { $('#tr-next', bk).focus(); } catch (e) {}
}

addEventListener('resize', () => { if (bk && bk.classList.contains('on')) show(); });

root.PFTour = { start: start, end: end, get open() { return !!bk && bk.classList.contains('on'); } };

})(typeof window !== 'undefined' ? window : globalThis);
