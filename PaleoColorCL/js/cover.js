import { listCharacters, loadSilhouette } from "./characters.js?v=99";
import { BRAND } from "./credits.js?v=99";

/**
 * Portada.
 *
 * Las siluetas no son un dibujo aparte: se sacan de los propios manifiestos, los mismos que
 * usa el visor. Si mañana se agrega o se saca una especie, la portada se entera sola y no hay
 * ninguna imagen que actualizar a mano ni que pueda quedar desincronizada.
 */
export async function renderCover(canvas, list) {
  const characters = [];
  for (const entry of list) {
    try {
      characters.push(await loadSilhouette(entry.id));
    } catch (error) {
      console.warn(`No se pudo dibujar ${entry.id} en la portada.`, error);
    }
  }
  if (!characters.length) return false;

  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const width = canvas.clientWidth || 320;
  const height = 96;
  canvas.width = width * ratio;
  canvas.height = height * ratio;
  const context = canvas.getContext("2d");
  context.scale(ratio, ratio);
  context.clearRect(0, 0, width, height);

  // Cada silueta se escala a un alto común y se reparten a lo ancho. El Atacamatitan mide
  // 8 m y el Chilesaurus 3: a escala real uno sería una mancha, así que se normaliza el alto.
  const gap = 10;
  const slot = (width - gap * (characters.length - 1)) / characters.length;
  characters.forEach((character, index) => {
    const [tw, th] = character.frame.texture;
    // La caja se mide de la propia silueta: no hace falta cargar el personaje entero para eso.
    const box = boxOf(character.silhouette, tw, th);
    const cw = box.x1 - box.x0;
    const ch = box.y1 - box.y0;
    const scale = Math.min(slot / cw, (height - 12) / ch);
    const x = index * (slot + gap) + (slot - cw * scale) / 2;
    const y = height - 6 - ch * scale;
    context.save();
    context.globalAlpha = 0.9;
    context.translate(x, y);
    context.scale(scale, scale);
    context.translate(-box.x0, -box.y0);
    context.drawImage(tintedSilhouette(character), 0, 0);
    context.restore();
  });
  return true;
}

/** Caja que ocupa la silueta dentro de su textura. */
const boxes = new Map();
function boxOf(img, tw, th) {
  const clave = img.src ? String(img.src).slice(-24) : String(tw) + th;
  if (boxes.has(clave)) return boxes.get(clave);
  const c = document.createElement("canvas");
  c.width = tw;
  c.height = th;
  const x = c.getContext("2d", { willReadFrequently: true });
  x.drawImage(img, 0, 0, tw, th);
  const d = x.getImageData(0, 0, tw, th).data;
  let x0 = tw;
  let y0 = th;
  let x1 = 0;
  let y1 = 0;
  for (let y = 0; y < th; y += 1) {
    for (let xx = 0; xx < tw; xx += 1) {
      if (d[(y * tw + xx) * 4 + 3] <= 15) continue;
      if (xx < x0) x0 = xx;
      if (xx > x1) x1 = xx;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  const box = x1 < x0 ? { x0: 0, y0: 0, x1: tw, y1: th } : { x0, y0, x1: x1 + 1, y1: y1 + 1 };
  boxes.set(clave, box);
  return box;
}

const cache = new Map();
function tintedSilhouette(character) {
  if (cache.has(character.id)) return cache.get(character.id);
  const [tw, th] = character.frame.texture;
  const canvas = document.createElement("canvas");
  canvas.width = tw;
  canvas.height = th;
  const context = canvas.getContext("2d");
  context.drawImage(character.silhouette, 0, 0, tw, th);
  context.globalCompositeOperation = "source-in";
  const gradient = context.createLinearGradient(0, 0, 0, th);
  gradient.addColorStop(0, BRAND.teal);
  gradient.addColorStop(1, "#00706a");
  context.fillStyle = gradient;
  context.fillRect(0, 0, tw, th);
  context.globalCompositeOperation = "source-over";
  cache.set(character.id, canvas);
  return canvas;
}

export { listCharacters };
