import { ASSETS, QR_PREFIX, frameOf } from "./config.js?v=99";
import { MOTION_NAMES } from "./rig.js?v=99";

/**
 * Un personaje vive en un manifiesto JSON. Los campos de imagen aceptan tanto una ruta
 * relativa (personajes que vienen en el paquete) como un data URL (los que exporta el
 * editor), así que un personaje nuevo es UN archivo que se copia a assets/characters/.
 */

const cache = new Map();

/** Devuelve el id del personaje, o null si el QR no es de esta aplicación. */
export function idFromPayload(data) {
  if (typeof data !== "string" || !data.startsWith(QR_PREFIX)) return null;
  const id = data.slice(QR_PREFIX.length);
  return /^[a-z0-9-]{1,9}$/.test(id) ? id : null;
}

function loadImage(source, baseDir) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`No se pudo cargar la imagen del personaje: ${String(source).slice(0, 48)}`));
    image.src = source.startsWith("data:") ? source : baseDir + source;
  });
}

function validate(manifest, id) {
  if (manifest.id !== id) throw new Error(`El manifiesto dice id "${manifest.id}" pero se pidió "${id}"`);
  if (!manifest.silhouette) throw new Error("Al manifiesto le falta la silueta");
  if (!manifest.lineart) throw new Error("Al manifiesto le falta el dibujo");
  if (!Array.isArray(manifest.parts) || !manifest.parts.length) {
    throw new Error("El manifiesto no declara partes");
  }
  const seen = new Set();
  for (const part of manifest.parts) {
    if (!part.id || seen.has(part.id)) throw new Error(`Parte sin id o repetida: "${part.id}"`);
    seen.add(part.id);
    if (!part.mask) throw new Error(`La parte "${part.id}" no trae máscara`);
    const pivot = part.pivot;
    if (!Array.isArray(pivot) || pivot.length !== 2 || !pivot.every(Number.isFinite)) {
      throw new Error(`Pivote inválido en "${part.id}"`);
    }
    if (part.motion && !MOTION_NAMES.includes(part.motion)) {
      throw new Error(`Movimiento desconocido en "${part.id}": "${part.motion}"`);
    }
  }
}

/** Caja del dibujo dentro de la textura. El dibujo no llena el marco: ese margen es
 *  exactamente el espacio del que dispone para caminar sin salirse. */
function contentBox(image) {
  const canvas = document.createElement("canvas");
  canvas.width = image.width;
  canvas.height = image.height;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  context.drawImage(image, 0, 0);
  const px = context.getImageData(0, 0, canvas.width, canvas.height).data;
  let x0 = canvas.width, y0 = canvas.height, x1 = -1, y1 = -1;
  for (let y = 0; y < canvas.height; y += 1) {
    for (let x = 0; x < canvas.width; x += 1) {
      if (px[(y * canvas.width + x) * 4 + 3] <= 15) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  return x1 < 0 ? { x0: 0, y0: 0, x1: canvas.width, y1: canvas.height } : { x0, y0, x1: x1 + 1, y1: y1 + 1 };
}

function silhouetteBottom(image) {
  const canvas = document.createElement("canvas");
  canvas.width = image.width;
  canvas.height = image.height;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  context.drawImage(image, 0, 0);
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
  for (let y = canvas.height - 1; y >= 0; y -= 1) {
    for (let x = 0; x < canvas.width; x += 1) {
      if (pixels[(y * canvas.width + x) * 4 + 3] > 15) return y + 1;
    }
  }
  return canvas.height;
}

/**
 * Sólo la silueta y su marco. Para quien no necesita el personaje entero.
 *
 * `loadCharacter` decodifica el dibujo, la silueta y las 5-9 máscaras. La portada sólo usa la
 * silueta, así que llamarlo 50 veces significaba parsear **11 MB de JSON y decodificar 420
 * PNG** para dibujar 50 siluetas de 40 px de alto. Eso es lo que hacía que la app tardara en
 * abrir.
 */
export async function loadSilhouette(id) {
  const response = await fetch(`${ASSETS.characterDir}${id}.json`);
  if (!response.ok) throw new Error(`No se pudo leer ${id}.json`);
  const manifest = await response.json();
  return {
    id: manifest.id,
    name: manifest.name,
    frame: frameOf(manifest.frame),
    silhouette: await loadImage(manifest.silhouette),
  };
}

export async function loadCharacter(id) {
  if (cache.has(id)) return cache.get(id);
  const response = await fetch(`${ASSETS.characterDir}${id}.json`);
  if (!response.ok) throw new Error(`No existe el personaje "${id}"`);
  const manifest = await response.json();
  validate(manifest, id);

  // Orden de dibujo: el z de cada parte, de atrás hacia adelante.
  const declared = manifest.parts.slice().sort((a, b) => (a.z ?? 0) - (b.z ?? 0));
  const [silhouette, lineart, ...masks] = await Promise.all([
    loadImage(manifest.silhouette, ASSETS.characterDir),
    loadImage(manifest.lineart, ASSETS.characterDir),
    ...declared.map((part) => loadImage(part.mask, ASSETS.characterDir)),
  ]);
  const character = {
    id,
    name: manifest.name || id,
    voice: manifest.voice ?? null,
    facts: manifest.facts ?? null,
    number: manifest.number ?? null,
    habitat: manifest.habitat ?? null,
    // Pivote y ángulo para alzarse sobre las patas traseras. Sólo lo traen los que pueden.
    rear: manifest.rear && Array.isArray(manifest.rear.pivot)
      ? { pivot: manifest.rear.pivot.slice(), angle: manifest.rear.angle ?? 0 }
      : null,
    frame: frameOf(manifest.frame),
    frameId: manifest.frame ?? "vertical",
    animation: manifest.animation ?? "parada",
    baseDir: ASSETS.characterDir,
    groundY: Number.isFinite(manifest.groundY) ? manifest.groundY : silhouetteBottom(silhouette),
    content: contentBox(silhouette),
    silhouette,
    lineart,
    // parts: la lista que consume el animador. masks: las imágenes, por id.
    parts: declared.map((part) => ({
      id: part.id,
      pivot: part.pivot.slice(),
      motion: part.motion ?? "fija",
      amount: Number.isFinite(part.amount) ? part.amount : 0.1,
      phase: Number.isFinite(part.phase) ? part.phase : 0,
      anchor: Boolean(part.anchor),
    })),
    masks: Object.fromEntries(declared.map((part, index) => [part.id, masks[index]])),
  };
  cache.set(id, character);
  return character;
}

export async function listCharacters() {
  try {
    const response = await fetch(ASSETS.characterIndex);
    if (!response.ok) return [];
    return await response.json();
  } catch (error) {
    return [];
  }
}
