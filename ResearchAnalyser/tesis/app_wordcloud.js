/* ============================================================
   Nube de palabras · motor propio (sin librerías, offline)
   Colocación en espiral de Arquímedes con detección de colisión.
   Uso:  WordCloud.render(container, [{text, weight}, ...], opts)
   ============================================================ */
const WordCloud = (function(){
  let measurer = null;
  let last = null; // {container, words, opts} para re-render en resize

  let tipEl = null;
  function ensureTip(){
    if(tipEl && tipEl.isConnected) return;
    tipEl = document.createElement("div");
    tipEl.className = "wc-tip";
    tipEl.style.display = "none";
    document.body.appendChild(tipEl);
  }
  function wcMove(e){
    const w = e.target.closest && e.target.closest(".wc-word");
    if(!w){ wcHide(); return; }
    ensureTip();
    const n = Number(w.dataset.freq) || 0;
    const term = w.dataset.term || w.textContent;
    tipEl.innerHTML = `<b>${term}</b><span>Frecuencia: ${n} ${n === 1 ? "aparición" : "apariciones"}</span>`;
    tipEl.style.display = "block";
    const pad = 14, r = tipEl.getBoundingClientRect();
    let x = e.clientX + pad, y = e.clientY + pad;
    if(x + r.width > window.innerWidth - 8) x = e.clientX - r.width - pad;
    if(y + r.height > window.innerHeight - 8) y = e.clientY - r.height - pad;
    tipEl.style.left = Math.max(6, x) + "px";
    tipEl.style.top = Math.max(6, y) + "px";
  }
  function wcHide(){ if(tipEl) tipEl.style.display = "none"; }

  function ctx(){
    if(!measurer) measurer = document.createElement("canvas").getContext("2d");
    return measurer;
  }
  function measure(text, fontSize, weight, family){
    const g = ctx();
    g.font = `${weight} ${fontSize}px ${family}`;
    return { w: Math.ceil(g.measureText(text).width), h: Math.ceil(fontSize * 1.16) };
  }
  function overlaps(a, b, pad){
    return !(a.x + a.w + pad < b.x || b.x + b.w + pad < a.x ||
             a.y + a.h + pad < b.y || b.y + b.h + pad < a.y);
  }

  function render(container, words, opts){
    if(!container) return;
    opts = opts || {};
    last = { container, words, opts };

    const family  = opts.family  || "Inter, sans-serif";
    const colors  = opts.colors  || ["#8C4799"];
    const pad     = opts.pad != null ? opts.pad : 3;
    const minH    = opts.minHeight || 440;

    container.classList.add("wc-canvas");
    container.innerHTML = "";
    if(!words || !words.length){
      container.classList.remove("wc-canvas");
      container.innerHTML = `<p class="panel-desc">No hay palabras suficientes con los filtros actuales.</p>`;
      return;
    }

    const W = Math.max(container.clientWidth || 600, 260);
    const H = Math.max(container.clientHeight || 0, minH);
    container.style.height = H + "px";

    const ws  = words.map(d => d.weight);
    const wMax = Math.max(...ws), wMin = Math.min(...ws);
    const fMax = opts.fontMax || Math.max(30, Math.min(66, W / 11));
    const fMin = opts.fontMin || 13;
    const sizeOf = w => {
      if(wMax === wMin) return Math.round((fMax + fMin) / 2);
      const t = (Math.sqrt(w) - Math.sqrt(wMin)) / (Math.sqrt(wMax) - Math.sqrt(wMin));
      return Math.round(fMin + t * (fMax - fMin));
    };

    const placed = [];
    const cx = W / 2, cy = H / 2;
    const frag = document.createDocumentFragment();
    let shown = 0;

    words.forEach((d, idx) => {
      const fs = sizeOf(d.weight);
      const dim = measure(d.text, fs, 800, family);
      // rota unas pocas palabras cortas para dar textura de nube
      const vertical = (idx % 8 === 5) && d.text.length <= 13 && fs <= fMax * 0.7;
      const bw = vertical ? dim.h : dim.w;   // caja ocupada tras rotar
      const bh = vertical ? dim.w : dim.h;

      let found = null;
      for(let t = 0; t < 340; t += 0.32){
        const r   = 4.2 * t;
        const px  = cx + r * Math.cos(t);          // centro candidato
        const py  = cy + r * Math.sin(t) * 0.62;   // aplasta vertical -> llena caja ancha
        const rect = { x: px - bw / 2, y: py - bh / 2, w: bw, h: bh };
        const inside = rect.x > 2 && rect.y > 2 && rect.x + rect.w < W - 2 && rect.y + rect.h < H - 2;
        if(!inside && placed.length && r < Math.max(W, H)) continue; // mantiene dentro mientras haya espacio
        let hit = false;
        for(let k = 0; k < placed.length; k++){ if(overlaps(rect, placed[k], pad)){ hit = true; break; } }
        if(!hit){ found = { rect, px, py }; break; }
      }
      if(!found) return; // antes de solapar, se omite la palabra

      placed.push(found.rect);
      const span = document.createElement("span");
      span.className = "wc-word" + (vertical ? " wc-v" : "");
      span.textContent = d.text;
      span.style.left = (found.px - dim.w / 2) + "px";
      span.style.top  = (found.py - dim.h / 2) + "px";
      span.style.fontSize = fs + "px";
      span.style.color = colors[idx % colors.length];
      span.dataset.term = d.text;
      span.dataset.freq = d.weight;
      frag.appendChild(span);
      shown++;
    });

    container.appendChild(frag);
    ensureTip();
    if(!container.dataset.wcTipBound){
      container.addEventListener("mousemove", wcMove);
      container.addEventListener("mouseleave", wcHide);
      container.dataset.wcTipBound = "1";
    }
    if(!shown){
      container.classList.remove("wc-canvas");
      container.innerHTML = `<p class="panel-desc">No hay palabras suficientes con los filtros actuales.</p>`;
    }
  }

  // Re-dibuja al cambiar el ancho disponible (cambio de pestaña / ventana)
  let raf = null;
  window.addEventListener("resize", () => {
    if(!last || !last.container || !last.container.isConnected) return;
    if(!last.container.offsetParent) return; // panel oculto
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(() => render(last.container, last.words, last.opts));
  });

  return { render };
})();
