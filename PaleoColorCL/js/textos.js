import { APP_VERSION } from "./config.js?v=99";
import { BRAND, citationText, contactText } from "./credits.js?v=99";
import { listCharacters, loadCharacter } from "./characters.js?v=99";
import { drawFactCard } from "./facts.js?v=99";
import { loadBrandLogo } from "./template.js?v=99";

/**
 * Editor de textos.
 *
 * Antes había un editor de figuras. El rig lo resuelve solo (js/rig.js + el reparto
 * automático), y lo que de verdad se itera cien veces son los TEXTOS: qué se cuenta, con qué
 * palabras y qué se destaca.
 *
 * El preview usa `drawFactCard`, el mismo del visor. Lo que se ve acá es exactamente lo que
 * verá el niño: si acá no se lee, en el celular tampoco.
 */

const $ = (id) => document.getElementById(id);
const state = { id: null, manifest: null, facts: null, index: 0 };
const preview = $("preview");
const pctx = preview.getContext("2d");

/* ------------------------------------------------------------------ carga y guardado */

async function raw(id) {
  const response = await fetch(`assets/characters/${id}.json`);
  if (!response.ok) throw new Error(`No se pudo leer ${id}.json`);
  return response.json();
}

async function pick(id) {
  state.id = id;
  state.manifest = await raw(id);
  state.facts = structuredClone(state.manifest.facts ?? { items: [] });
  state.facts.items = state.facts.items ?? [];
  state.index = 0;
  fillForm();
  renderList();
  draw();
}

function fillForm() {
  const f = state.facts;
  $("pronunciation").value = f.pronunciation ?? "";
  $("meaning").value = f.meaning ?? "";
  $("group").value = f.group ?? "";
  $("sizeM").value = f.sizeM ?? "";
  $("age").value = f.age ?? "";
  $("bubble").value = state.manifest.voice?.bubble ?? "";
}

function readForm() {
  const f = state.facts;
  f.pronunciation = $("pronunciation").value.trim();
  f.meaning = $("meaning").value.trim();
  f.group = $("group").value.trim();
  const size = Number.parseFloat($("sizeM").value);
  if (Number.isFinite(size)) f.sizeM = size; else delete f.sizeM;
  f.age = $("age").value.trim();
  if (state.manifest.voice) state.manifest.voice.bubble = $("bubble").value.trim();
}

/* ---------------------------------------------------------------------- lista de datos */

function renderList() {
  const box = $("items");
  box.innerHTML = "";
  state.facts.items.forEach((item, i) => {
    const row = document.createElement("li");
    row.className = i === state.index ? "item on" : "item";
    row.innerHTML = `<b>${escape(item.label)}</b><span>${escape(strip(item.text)).slice(0, 60)}</span>`;
    const tools = document.createElement("div");
    tools.className = "tools";
    tools.append(
      button("↑", () => move(i, -1)),
      button("↓", () => move(i, 1)),
      button("✕", () => remove(i), "del"),
    );
    row.appendChild(tools);
    row.addEventListener("click", (e) => { if (e.target === row || e.target.tagName !== "BUTTON") select(i); });
    box.appendChild(row);
  });
  $("count").textContent = `${state.facts.items.length} datos`;
}

function button(text, fn, cls = "") {
  const b = document.createElement("button");
  b.type = "button";
  b.textContent = text;
  b.className = cls;
  b.addEventListener("click", (e) => { e.stopPropagation(); fn(); });
  return b;
}

const escape = (s) => String(s).replace(/[<>&]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;" }[c]));
const strip = (s) => String(s).replace(/\*\*/g, "");

function select(i) {
  state.index = i;
  const item = state.facts.items[i];
  $("label").value = item?.label ?? "";
  $("text").value = item?.text ?? "";
  renderList();
  draw();
}

function move(i, d) {
  const j = i + d;
  if (j < 0 || j >= state.facts.items.length) return;
  const [it] = state.facts.items.splice(i, 1);
  state.facts.items.splice(j, 0, it);
  state.index = j;
  renderList();
  draw();
}

function remove(i) {
  state.facts.items.splice(i, 1);
  state.index = Math.max(0, Math.min(state.index, state.facts.items.length - 1));
  select(state.index);
}

/* ------------------------------------------------------------------------- preview */

let logo = null;
function draw() {
  readForm();
  const item = state.facts.items[state.index];
  if (item) {
    item.label = $("label").value;
    item.text = $("text").value;
  }
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  // El ancho lo manda el contenedor, no un número fijo: estaba clavado en 380 px y en un
  // celular de 360 el preview se salía de la tarjeta.
  const w = Math.max(240, Math.min(380, preview.parentElement?.clientWidth ?? 380));
  const h = 300;
  preview.width = w * ratio;
  preview.height = h * ratio;
  preview.style.width = `${w}px`;
  preview.style.height = `${h}px`;
  pctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  pctx.fillStyle = "#e9e6e2";
  pctx.fillRect(0, 0, w, h);
  if (!state.facts.items.length) return;
  // hoja arriba: la tarjeta cae debajo, igual que en el visor
  const pose = { points: [[30, 4], [w - 30, 4], [w - 30, 54], [30, 54]], center: [w / 2, 29], width: w - 60, height: 50, angle: 0 };
  // drawFactCard recibe {index, since}, no un tiempo: la tarjeta ya no avanza sola. Esto
  // quedó pasando un número cuando cambió la firma y reventaba el preview entero.
  drawFactCard(pctx, pose, { ...state.manifest, facts: state.facts },
    { index: state.index, since: 1000, hidden: false }, { width: w, height: h });
  const chars = state.facts.items[state.index]?.text?.length ?? 0;
  $("hint").textContent = `${chars} caracteres · ${(state.facts.items[state.index]?.text.match(/\*\*/g)?.length ?? 0) / 2} destacadas`;
  $("hint").className = chars > 190 ? "hint bad" : "hint";
}

/* ------------------------------------------------------------------------ exportar */

function exportJson() {
  readForm();
  const out = { ...state.manifest, facts: state.facts };
  const blob = new Blob([JSON.stringify(out)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${state.id}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

/* ---------------------------------------------------------------------------- inicio */

for (const id of ["pronunciation", "meaning", "group", "sizeM", "age", "bubble", "label", "text"]) {
  $(id).addEventListener("input", () => { draw(); if (id === "label" || id === "text") renderList(); });
}
$("add").addEventListener("click", () => {
  state.facts.items.push({ label: "Nuevo dato", text: "Escribe acá. Destaca con **dos asteriscos**." });
  select(state.facts.items.length - 1);
});
$("export").addEventListener("click", exportJson);
$("character").addEventListener("change", (e) => pick(e.target.value));

(async () => {
  $("credit").textContent = citationText();
  $("contact").textContent = contactText();
  $("unit").textContent = BRAND.unit;
  $("build").textContent = `v${APP_VERSION}`;
  logo = await loadBrandLogo();
  if (logo) $("logo").src = BRAND.logo;
  const list = await listCharacters();
  const sel = $("character");
  for (const entry of list) {
    const o = document.createElement("option");
    o.value = entry.id;
    o.textContent = entry.name;
    sel.appendChild(o);
  }
  if (list.length) {
    await pick(list[0].id);
    select(0);
  }
})();
