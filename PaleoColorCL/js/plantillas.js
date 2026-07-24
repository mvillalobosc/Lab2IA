import { APP_VERSION } from "./config.js?v=99";
import { BRAND, citationText, contactText } from "./credits.js?v=99";
import { listCharacters, loadCharacter } from "./characters.js?v=99";
import { loadBrandLogo, renderSheet } from "./template.js?v=99";

/**
 * Las hojas no se guardan como PNG: se generan desde el manifiesto de cada personaje.
 * Así un personaje es UN archivo y la plantilla nunca puede quedar desincronizada del rig.
 */
const $ = (id) => document.getElementById(id);
const grid = $("grid");
let logo = null;

function download(name, url) {
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

function printCanvas(canvas, name) {
  const frame = document.createElement("iframe");
  frame.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0";
  document.body.appendChild(frame);
  const doc = frame.contentWindow.document;
  doc.open();
  doc.write(`<style>@page{size:A4 portrait;margin:0}html,body{margin:0}img{width:100%;display:block}</style>`
    + `<img alt="${name}" src="${canvas.toDataURL("image/png")}">`);
  doc.close();
  frame.contentWindow.focus();
  const img = doc.querySelector("img");
  img.onload = () => {
    frame.contentWindow.print();
    setTimeout(() => frame.remove(), 1000);
  };
}

async function card(entry) {
  const box = document.createElement("article");
  box.className = "sheet";
  box.dataset.id = entry.id;
  box.innerHTML = `<div class="head"><b class="num">${entry.number ?? "·"}</b><strong>${entry.name}</strong><small>${entry.habitat ?? ""}</small></div>
    <div class="thumb"><span>Generando…</span></div>
    <div class="acts"><button class="dl" type="button">Descargar PNG</button><button class="pr" type="button">Imprimir</button></div>`;
  grid.appendChild(box);
  try {
    const character = await loadCharacter(entry.id);
    const { canvas } = renderSheet({
      id: character.id, name: character.name, lineart: character.lineart, logo,
      frame: character.frameId, number: character.number,
    });
    const thumb = box.querySelector(".thumb");
    thumb.innerHTML = "";
    const img = new Image();
    img.src = canvas.toDataURL("image/png");
    img.alt = `Plantilla de ${character.name}`;
    thumb.appendChild(img);
    box.querySelector(".dl").onclick = () => download(`plantilla_${character.id}.png`, canvas.toDataURL("image/png"));
    box.querySelector(".pr").onclick = () => printCanvas(canvas, character.name);
  } catch (error) {
    box.querySelector(".thumb").innerHTML = `<span class="err">${error.message}</span>`;
    box.querySelectorAll("button").forEach((b) => { b.disabled = true; });
  }
}

/**
 * Filtros.
 *
 * Pensados para un niño de 8 años, no para un taxónomo: primero DÓNDE VIVÍA (que es lo que se
 * ve y se escucha), después qué tipo de animalito, después cuándo. Los chips muestran cuántos
 * hay en cada uno: un filtro que deja la lista vacía es una trampa.
 *
 * El buscador va sin acentos ni mayúsculas: "estegouros" tiene que encontrar a Stegouros.
 */
const HABITAT = { agua: "🌊 En el mar", tierra: "🌋 En la tierra", aire: "💨 Por el aire" };
const filtro = { habitat: null, epoch: null, texto: "" };
let indice = [];

const normal = (s) => String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");

/**
 * Búsqueda tolerante. Un niño escribe "estegouros" y el bicho se llama "Stegouros": la
 * subcadena falla justo al revés de lo que uno espera, porque lo escrito CONTIENE al nombre.
 * Así que se compara en las dos direcciones, palabra por palabra. Y sin acentos ni mayúsculas.
 */
function calza(entry, q) {
  const campos = normal(`${entry.name} ${entry.group} ${entry.epoch} ${entry.number}`);
  if (campos.includes(q)) return true;
  for (const palabra of campos.split(/\s+/)) {
    if (palabra.length >= 4 && q.includes(palabra)) return true;
  }
  return false;
}

function pasa(entry) {
  if (filtro.habitat && entry.habitat !== filtro.habitat) return false;
  if (filtro.epoch && entry.epoch !== filtro.epoch) return false;
  if (filtro.texto) return calza(entry, filtro.texto);
  return true;
}

function chips(box, campo, valores, etiqueta) {
  box.innerHTML = "";
  const todos = document.createElement("button");
  todos.type = "button";
  todos.className = filtro[campo] === null ? "chip on" : "chip";
  todos.textContent = `Todos (${indice.length})`;
  todos.onclick = () => { filtro[campo] = null; refresh(); };
  box.appendChild(todos);
  for (const v of valores) {
    // se cuenta con los OTROS filtros puestos: el número dice lo que pasaría al tocar
    const n = indice.filter((e) => pasa({ ...e, [campo]: v }) && e[campo] === v).length;
    const b = document.createElement("button");
    b.type = "button";
    b.className = filtro[campo] === v ? "chip on" : "chip";
    b.disabled = n === 0;
    b.textContent = `${etiqueta(v)} (${n})`;
    b.onclick = () => { filtro[campo] = filtro[campo] === v ? null : v; refresh(); };
    box.appendChild(b);
  }
}

function refresh() {
  // Sólo dos filtros, y es a propósito. El de grupo daba **29 chips** y 17 de ellos filtraban
  // UNA sola especie: eso no es un filtro, es una lista con botones. El buscador ya lo hace
  // mejor —"plesio" da 3, "mosasaurio" da 1— y sin ocupar media pantalla.
  const habitats = [...new Set(indice.map((e) => e.habitat))];
  const epocas = [...new Set(indice.map((e) => e.epoch))].sort();
  chips($("fHabitat"), "habitat", habitats, (v) => HABITAT[v] ?? v);
  chips($("fEpoch"), "epoch", epocas, (v) => v);
  const visibles = indice.filter(pasa);
  $("result").textContent = visibles.length === indice.length
    ? `${indice.length} especies`
    : `${visibles.length} de ${indice.length}`;
  for (const box of grid.children) {
    box.hidden = !visibles.some((e) => e.id === box.dataset.id);
  }
  $("empty").hidden = visibles.length > 0;
}

(async () => {
  $("credit").textContent = citationText();
  $("contact").textContent = contactText();
  $("unit").textContent = BRAND.unit;
  $("build").textContent = `v${APP_VERSION}`;
  logo = await loadBrandLogo();
  if (logo) $("logo").src = BRAND.logo;
  indice = await listCharacters();
  if (!indice.length) {
    grid.innerHTML = `<p class="empty">No hay personajes en <code>assets/characters/index.json</code>.</p>`;
    return;
  }
  $("search").addEventListener("input", (e) => { filtro.texto = normal(e.target.value.trim()); refresh(); });
  $("clear").addEventListener("click", () => {
    filtro.habitat = filtro.epoch = null;
    filtro.texto = "";
    $("search").value = "";
    refresh();
  });
  refresh();
  for (const entry of indice) await card(entry);
  refresh();
})();
