import { CAPTURE } from "./config.js?v=99";
import { transformPoint } from "./geometry.js?v=99";

function createCanvas(width, height, readFrequently = false) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const options = readFrequently ? { willReadFrequently: true } : undefined;
  return { canvas, context: canvas.getContext("2d", options) };
}

function bilinearSample(pixels, width, height, x, y, out) {
  const cx = Math.max(0, Math.min(width - 1.001, x));
  const cy = Math.max(0, Math.min(height - 1.001, y));
  const x0 = Math.floor(cx);
  const y0 = Math.floor(cy);
  const x1 = Math.min(width - 1, x0 + 1);
  const y1 = Math.min(height - 1, y0 + 1);
  const tx = cx - x0;
  const ty = cy - y0;
  const i00 = (y0 * width + x0) * 4;
  const i10 = (y0 * width + x1) * 4;
  const i01 = (y1 * width + x0) * 4;
  const i11 = (y1 * width + x1) * 4;
  for (let channel = 0; channel < 3; channel += 1) {
    const top = pixels[i00 + channel] * (1 - tx) + pixels[i10 + channel] * tx;
    const bottom = pixels[i01 + channel] * (1 - tx) + pixels[i11 + channel] * tx;
    out[channel] = top * (1 - ty) + bottom * ty;
  }
  return out;
}

/**
 * Dilata una máscara alfa unos px. Las 7 máscaras de partes particionan la silueta con
 * solape CERO: al rotar un brazo o una pierna se abre una cuña de fondo en la articulación
 * (medido: 1,3% del cuerpo con amplitudes reales). Dilatando cada parte, la que se dibuja
 * después tapa la costura. La dilatación no filtra papel: `sourceCanvas` ya es transparente
 * fuera de la silueta, así que el anillo extra sólo existe donde hay dibujo.
 */
function dilateMask(image, width, height, radius) {
  const { canvas, context } = createCanvas(width, height);
  for (const ring of [1, 0.66, 0.33]) {
    const r = radius * ring;
    for (let i = 0; i < 12; i += 1) {
      const angle = (i / 12) * Math.PI * 2;
      context.drawImage(image, Math.cos(angle) * r, Math.sin(angle) * r, width, height);
    }
  }
  context.drawImage(image, 0, 0, width, height);
  return canvas;
}

export class TextureSampler {
  constructor() {
    this.width = 0;
    this.height = 0;
    const frame = createCanvas(1, 1, true);
    this.frameCanvas = frame.canvas;
    this.frameContext = frame.context;
    // Se crean en 1x1 y se redimensionan en load(): el tamaño lo trae el marco del personaje.
    const source = createCanvas(1, 1, true);
    this.sourceCanvas = source.canvas;
    this.sourceContext = source.context;
    this.character = null;
    this.paperColour = null;
    this.silhouettePixels = null;
    this.partMasks = {};
    this.partCanvases = {};
    this.ready = false;
  }

  /** Carga un personaje ya resuelto por characters.js. Cambiar de personaje es llamarla de nuevo. */
  load(character) {
    this.character = character;
    // El tamaño de textura lo define el marco del personaje, no una constante: un dibujo
    // de perfil es apaisado y en 384x512 quedaría casi todo vacío.
    [this.width, this.height] = character.frame.texture;
    this.sourceCanvas.width = this.width;
    this.sourceCanvas.height = this.height;
    this.partMasks = {};
    this.partCanvases = {};
    for (const part of character.parts) {
      this.partMasks[part.id] = character.masks[part.id];
      this.partCanvases[part.id] = createCanvas(this.width, this.height).canvas;
    }
    const mask = createCanvas(this.width, this.height, true);
    mask.context.drawImage(character.silhouette, 0, 0, this.width, this.height);
    this.silhouettePixels = mask.context.getImageData(0, 0, this.width, this.height).data;
    this.ready = false;
  }

  capture(source, geometry) {
    if (!this.silhouettePixels || !geometry?.transform) return { ok: false, reason: "assets-or-geometry" };
    const sourceWidth = source.videoWidth || source.naturalWidth || source.width;
    const sourceHeight = source.videoHeight || source.naturalHeight || source.height;
    if (!sourceWidth || !sourceHeight) return { ok: false, reason: "empty-source" };
    for (const [x, y] of geometry.corners) {
      if (x < 2 || y < 2 || x >= sourceWidth - 2 || y >= sourceHeight - 2) {
        return { ok: false, reason: "character-out-of-frame" };
      }
    }

    const frameWidth = Math.min(CAPTURE.maxFrameWidth, sourceWidth);
    const frameHeight = Math.max(1, Math.round(frameWidth * sourceHeight / sourceWidth));
    this.frameCanvas.width = frameWidth;
    this.frameCanvas.height = frameHeight;
    this.frameContext.drawImage(source, 0, 0, frameWidth, frameHeight);
    const frame = this.frameContext.getImageData(0, 0, frameWidth, frameHeight).data;
    const output = new ImageData(this.width, this.height);
    const target = output.data;
    const scaleX = frameWidth / sourceWidth;
    const scaleY = frameHeight / sourceHeight;
    const steps = Math.max(1, CAPTURE.supersample | 0);
    const samples = steps * steps;
    const colour = [0, 0, 0];

    for (let y = 0; y < this.height; y += 1) {
      for (let x = 0; x < this.width; x += 1) {
        let red = 0;
        let green = 0;
        let blue = 0;
        for (let sy = 0; sy < steps; sy += 1) {
          const v = (y + (sy + 0.5) / steps) / this.height;
          for (let sx = 0; sx < steps; sx += 1) {
            const u = (x + (sx + 0.5) / steps) / this.width;
            const [videoX, videoY] = transformPoint(geometry.transform, u, v);
            bilinearSample(frame, frameWidth, frameHeight, videoX * scaleX, videoY * scaleY, colour);
            red += colour[0];
            green += colour[1];
            blue += colour[2];
          }
        }
        const index = (y * this.width + x) * 4;
        target[index] = red / samples;
        target[index + 1] = green / samples;
        target[index + 2] = blue / samples;
        target[index + 3] = 255;
      }
    }

    const metrics = this.#buildTexture(output.data);
    this.#buildPartCanvases();
    this.ready = true;
    return {
      ok: true,
      ...metrics,
      mode: geometry.mode,
      markerCount: geometry.markerCount,
      error: geometry.error,
    };
  }

  #buildTexture(raw) {
    const paper = this.#estimatePaperColour(raw);
    this.paperColour = paper;
    const scale = [248 / Math.max(100, paper[0]), 248 / Math.max(100, paper[1]), 248 / Math.max(100, paper[2])];
    const image = new ImageData(this.width, this.height);
    const output = image.data;
    let colouredPixels = 0;
    let darkPixels = 0;
    let visiblePixels = 0;

    for (let index = 0; index < raw.length; index += 4) {
      const alpha = this.silhouettePixels[index + 3];
      if (alpha < 15) {
        output[index + 3] = 0;
        continue;
      }
      const red = Math.max(0, Math.min(255, raw[index] * scale[0]));
      const green = Math.max(0, Math.min(255, raw[index + 1] * scale[1]));
      const blue = Math.max(0, Math.min(255, raw[index + 2] * scale[2]));
      output[index] = red;
      output[index + 1] = green;
      output[index + 2] = blue;
      output[index + 3] = alpha;
      visiblePixels += 1;
      const maximum = Math.max(red, green, blue);
      const minimum = Math.min(red, green, blue);
      const average = (red + green + blue) / 3;
      if (maximum - minimum > 12) colouredPixels += 1;
      if (average < 150) darkPixels += 1;
    }

    this.sourceContext.clearRect(0, 0, this.width, this.height);
    this.sourceContext.putImageData(image, 0, 0);
    // Proporción de tinta dentro de la silueta. Si el dibujo impreso está donde el manifiesto
    // dice, hay trazo; si sale casi 0, se está muestreando papel en blanco y la hoja no calza.
    const inkRatio = visiblePixels ? darkPixels / visiblePixels : 0;
    return { colouredPixels, darkPixels, visiblePixels, inkRatio, paperColour: paper };
  }

  #estimatePaperColour(raw) {
    // Mediana aproximada del papel fuera de la silueta: robusta a sombras y a lápiz fuera de línea.
    const reds = [];
    const greens = [];
    const blues = [];
    for (let y = 0; y < this.height; y += 3) {
      for (let x = 0; x < this.width; x += 3) {
        const index = (y * this.width + x) * 4;
        if (this.silhouettePixels[index + 3] > 15) continue;
        reds.push(raw[index]);
        greens.push(raw[index + 1]);
        blues.push(raw[index + 2]);
      }
    }
    if (!reds.length) return [245, 245, 245];
    const percentile = (values, ratio) => {
      values.sort((a, b) => a - b);
      return values[Math.min(values.length - 1, Math.floor(values.length * ratio))];
    };
    // El papel es lo claro: percentil 70 evita sombras y trazos que se salieron del contorno.
    return [percentile(reds, 0.7), percentile(greens, 0.7), percentile(blues, 0.7)];
  }

  #buildPartCanvases() {
    for (const [name, mask] of Object.entries(this.partMasks)) {
      const canvas = this.partCanvases[name];
      const context = canvas.getContext("2d");
      context.clearRect(0, 0, this.width, this.height);
      context.drawImage(this.sourceCanvas, 0, 0);
      context.globalCompositeOperation = "destination-in";
      context.drawImage(mask, 0, 0, this.width, this.height);
      context.globalCompositeOperation = "source-over";
    }
  }

  getParts() {
    return this.ready ? this.partCanvases : null;
  }

  getDebugDataUrl() {
    return this.ready ? this.sourceCanvas.toDataURL("image/png") : null;
  }
}
