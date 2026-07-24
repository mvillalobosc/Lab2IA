import {
  CAPTURE,
  REGISTRATION,
  TEMPLATE,
  UNIT_SQUARE,
  framePagePoints,
  markerPagePoints,
  qrPagePoints,
} from "./config.js?v=99";
import {
  averageSideLength,
  homographyLS,
  isConvexQuad,
  localScale,
  pointSetMovement,
  reprojectionError,
  smoothPointSet,
  transformPoint,
} from "./geometry.js?v=99";
import { idFromPayload } from "./characters.js?v=99";

function grayscale(r, g, b) {
  return (r * 77 + g * 150 + b * 29) >> 8;
}

/** Umbral de Otsu sobre un histograma de 256 niveles. Devuelve umbral y medias de clase. */
function otsu(histogram, total) {
  let sum = 0;
  for (let level = 0; level < 256; level += 1) sum += level * histogram[level];
  let sumBackground = 0;
  let weightBackground = 0;
  let best = -1;
  let threshold = 128;
  for (let level = 0; level < 256; level += 1) {
    weightBackground += histogram[level];
    if (!weightBackground) continue;
    const weightForeground = total - weightBackground;
    if (!weightForeground) break;
    sumBackground += level * histogram[level];
    const meanBackground = sumBackground / weightBackground;
    const meanForeground = (sum - sumBackground) / weightForeground;
    const variance = weightBackground * weightForeground * (meanBackground - meanForeground) ** 2;
    if (variance > best) {
      best = variance;
      threshold = level;
    }
  }
  let darkSum = 0;
  let darkCount = 0;
  let lightSum = 0;
  let lightCount = 0;
  for (let level = 0; level < 256; level += 1) {
    if (level <= threshold) { darkSum += level * histogram[level]; darkCount += histogram[level]; }
    else { lightSum += level * histogram[level]; lightCount += histogram[level]; }
  }
  return {
    threshold,
    darkMean: darkCount ? darkSum / darkCount : 0,
    lightMean: lightCount ? lightSum / lightCount : 255,
    darkFraction: darkCount / total,
  };
}

function convexHull(points) {
  const sorted = points.slice().sort((a, b) => (a[0] - b[0]) || (a[1] - b[1]));
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const build = (list) => {
    const out = [];
    for (const point of list) {
      while (out.length >= 2 && cross(out[out.length - 2], out[out.length - 1], point) <= 0) out.pop();
      out.push(point);
    }
    out.pop();
    return out;
  };
  if (sorted.length < 3) return sorted;
  return build(sorted).concat(build(sorted.reverse()));
}

function polygonArea(points) {
  let area = 0;
  for (let index = 0; index < points.length; index += 1) {
    const [x0, y0] = points[index];
    const [x1, y1] = points[(index + 1) % points.length];
    area += x0 * y1 - x1 * y0;
  }
  return Math.abs(area) / 2;
}

/**
 * Busca el cuadrado negro impreso dentro de un recorte y devuelve su centro subpíxel.
 * `gray` es Uint8Array de width*height; (targetX, targetY) es dónde se predijo la marca.
 *
 * Los criterios son invariantes a rotación a propósito: en la imagen el cuadrado es un
 * paralelogramo girado, y medirlo con un bounding box alineado a los ejes lo rechaza en
 * cuanto la hoja se inclina.
 */
function findSquare(gray, width, height, expectedSide, targetX, targetY) {
  const total = width * height;
  const histogram = new Uint32Array(256);
  for (let index = 0; index < total; index += 1) histogram[gray[index]] += 1;
  const stats = otsu(histogram, total);
  if (stats.lightMean - stats.darkMean < REGISTRATION.minContrast) return null;
  if (stats.darkFraction < 0.01 || stats.darkFraction > 0.72) return null;

  const cut = stats.threshold;
  const labels = new Int32Array(total).fill(-1);
  const stack = new Int32Array(total);
  const expectedArea = expectedSide * expectedSide;
  const minArea = expectedArea * REGISTRATION.minSideRatio ** 2;
  const maxArea = expectedArea * REGISTRATION.maxSideRatio ** 2;
  let best = null;

  for (let seed = 0; seed < total; seed += 1) {
    if (labels[seed] !== -1 || gray[seed] > cut) continue;
    let size = 0;
    let count = 0;
    let minX = width;
    let minY = height;
    let maxX = -1;
    let maxY = -1;
    let sumX = 0;
    let sumY = 0;
    let sumXX = 0;
    let sumYY = 0;
    let sumXY = 0;
    stack[size++] = seed;
    labels[seed] = seed;
    while (size > 0) {
      const current = stack[--size];
      const x = current % width;
      const y = (current / width) | 0;
      count += 1;
      sumX += x; sumY += y; sumXX += x * x; sumYY += y * y; sumXY += x * y;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x > 0 && labels[current - 1] === -1 && gray[current - 1] <= cut) { labels[current - 1] = seed; stack[size++] = current - 1; }
      if (x < width - 1 && labels[current + 1] === -1 && gray[current + 1] <= cut) { labels[current + 1] = seed; stack[size++] = current + 1; }
      if (y > 0 && labels[current - width] === -1 && gray[current - width] <= cut) { labels[current - width] = seed; stack[size++] = current - width; }
      if (y < height - 1 && labels[current + width] === -1 && gray[current + width] <= cut) { labels[current + width] = seed; stack[size++] = current + width; }
    }

    // Área proyectada: invariante a rotación, sólo la reduce el escorzo.
    if (count < minArea || count > maxArea) continue;
    // Un marcador cortado por el borde del recorte no sirve para centrar.
    if (minX === 0 || minY === 0 || maxX === width - 1 || maxY === height - 1) continue;

    // Elongación desde los momentos centrales: 1 para un cuadrado en cualquier giro.
    const meanX = sumX / count;
    const meanY = sumY / count;
    const varX = sumXX / count - meanX * meanX;
    const varY = sumYY / count - meanY * meanY;
    const covXY = sumXY / count - meanX * meanY;
    const trace = varX + varY;
    const root = Math.sqrt(Math.max(0, (varX - varY) ** 2 + 4 * covXY * covXY));
    const lambda1 = (trace + root) / 2;
    const lambda2 = (trace - root) / 2;
    if (!(lambda2 > 1e-6)) continue;
    const elongation = Math.sqrt(lambda1 / lambda2);
    if (elongation > REGISTRATION.maxElongation) continue;

    // Solidez contra la envolvente convexa: separa un paralelogramo de una letra o un trazo.
    const hullPoints = [];
    for (let y = minY; y <= maxY; y += 1) {
      let lo = -1;
      let hi = -1;
      for (let x = minX; x <= maxX; x += 1) {
        if (labels[y * width + x] !== seed) continue;
        if (lo < 0) lo = x;
        hi = x;
      }
      if (lo < 0) continue;
      hullPoints.push([lo, y], [hi + 1, y], [lo, y + 1], [hi + 1, y + 1]);
    }
    const hullArea = polygonArea(convexHull(hullPoints));
    const solidity = hullArea > 0 ? count / hullArea : 0;
    if (solidity < REGISTRATION.minSolidity) continue;

    const equivalentSide = Math.sqrt(count);
    const distance = Math.hypot(meanX - targetX, meanY - targetY) / Math.max(1, expectedSide);
    const score = distance * 1.6
      + Math.abs(Math.log(equivalentSide / expectedSide)) * 1.2
      + (1 - solidity) * 2
      + (elongation - 1) * 0.5;
    if (!best || score < best.score) {
      best = { score, label: seed, minX, minY, maxX, maxY, side: equivalentSide, solidity, elongation };
    }
  }
  if (!best) return null;

  // Centroide subpíxel ponderado por oscuridad dentro de la caja del blob (con 2 px de guarda).
  const pad = 2;
  const x0 = Math.max(0, best.minX - pad);
  const y0 = Math.max(0, best.minY - pad);
  const x1 = Math.min(width - 1, best.maxX + pad);
  const y1 = Math.min(height - 1, best.maxY + pad);
  const span = Math.max(1, stats.lightMean - stats.darkMean);
  let weightSum = 0;
  let sumX = 0;
  let sumY = 0;
  for (let y = y0; y <= y1; y += 1) {
    for (let x = x0; x <= x1; x += 1) {
      const value = gray[y * width + x];
      const weight = Math.max(0, Math.min(1, (stats.lightMean - value) / span));
      if (weight <= 0) continue;
      weightSum += weight;
      sumX += weight * x;
      sumY += weight * y;
    }
  }
  if (weightSum < 1) return null;
  return { point: [sumX / weightSum, sumY / weightSum], side: best.side, score: best.score };
}

export class SheetTracker {
  constructor(video) {
    this.video = video;
    this.qrCanvas = document.createElement("canvas");
    this.qrContext = this.qrCanvas.getContext("2d", { willReadFrequently: true });
    this.roiCanvas = document.createElement("canvas");
    this.roiContext = this.roiCanvas.getContext("2d", { willReadFrequently: true });

    this.characterId = null;
    this.qrCornersRaw = null;
    this.qrCornersSmooth = null;
    this.markersRaw = null;
    this.markerCount = 0;
    /** El QR saltó: es otra hoja distinta. Lo consume app.js y lo baja. */
    this.sheetChanged = false;
    this.pageTransform = null;
    this.motion = Infinity;
    this.diagnostics = null;
    this.previousMarkers = null;

    this.lastQrSeen = Number.NEGATIVE_INFINITY;
    this.lastMarkersSeen = Number.NEGATIVE_INFINITY;
    this.lastDetection = Number.NEGATIVE_INFINITY;
    this.lastMarkerScan = Number.NEGATIVE_INFINITY;
    this.lastColdScan = Number.NEGATIVE_INFINITY;
    this.coldWidthIndex = 0;
  }

  update(now) {
    if (!this.video.videoWidth || now - this.lastDetection < CAPTURE.detectionIntervalMs) return;
    this.lastDetection = now;
    const qr = this.#detectQr(now);
    if (!qr) return;
    const id = idFromPayload(qr.data);
    if (!id) return;
    this.characterId = id;

    if (!this.isQrVisible(now)) {
      this.qrCornersSmooth = null;
      this.markersRaw = null;
      this.pageTransform = null;
      this.previousMarkers = null;
      this.motion = Infinity;
      this.markerCount = 0;
      }
      // ¿Saltó el QR? Entonces es OTRA hoja, no la misma movida un poco.
      //
      // Acá todavía no hay homografía —se calcula después, con las marcas— así que no sirve
      // localScale. Pero el propio QR es la regla: mide 240 px de página impreso, y de su
      // tamaño en el video sale la escala.
      if (this.qrCornersRaw) {
        const lado = Math.hypot(qr.corners[1][0] - qr.corners[0][0], qr.corners[1][1] - qr.corners[0][1]);
        const ladoPage = TEMPLATE.qr.x1 - TEMPLATE.qr.x0;
        if (lado > 1) {
          const saltoPage = pointSetMovement(this.qrCornersRaw, qr.corners) * (ladoPage / lado);
          if (saltoPage > CAPTURE.maxQrJumpPage) this.sheetChanged = true;
        }
      }
      this.qrCornersRaw = qr.corners;
      this.qrCornersSmooth = smoothPointSet(this.qrCornersSmooth, qr.corners, 0.34);
      this.lastQrSeen = now;

    if (now - this.lastMarkerScan >= CAPTURE.markerScanIntervalMs) {
      this.lastMarkerScan = now;
      this.#scanMarkers(now);
    }
  }

  isQrVisible(now) {
    return Boolean(this.qrCornersSmooth && now - this.lastQrSeen < CAPTURE.qrHoldMs);
  }

  /**
   * Cuánto se puede sostener la última pose, según lo que se esté moviendo el teléfono.
   *
   * Quieto: largo, porque la hoja no se movió y sostener no desalinea nada.
   * Moviéndose: corto, porque cada milisegundo sostenido dibuja al bicho más lejos de su hoja.
   */
  #holdMs() {
    const m = this.motion;
    if (!Number.isFinite(m) || m <= 0.5) return CAPTURE.markerHoldMaxMs;
    // Se sostiene mientras la hoja no se haya corrido más de maxArrastrePage.
    const ms = (CAPTURE.maxArrastrePage * CAPTURE.detectionIntervalMs) / m;
    return Math.max(CAPTURE.markerHoldMinMs, Math.min(CAPTURE.markerHoldMaxMs, ms));
  }

  hasMarkers(now) {
    return Boolean(this.pageTransform && now - this.lastMarkersSeen < this.#holdMs());
  }

  /** Pose suavizada del QR, sólo para dibujar la animación. */
  getQrCorners() {
    return this.qrCornersSmooth ? this.qrCornersSmooth.map((point) => point.slice()) : null;
  }

  /**
   * Geometría del dibujo en el frame ACTUAL, sin suavizado, para muestrear color.
   * Devuelve null si el registro no es fiable.
   */
  /** @param frame marco del personaje activo (rect en coordenadas de página). */
  /**
   * 0..1: cuán fresca es la pose, para desvanecer al personaje si envejece.
   *
   * La gracia NO es opcional: el tracker explora cada `detectionIntervalMs`, así que con la
   * hoja quieta la pose siempre tiene algo de edad. Sin gracia, el bicho parpadea estando
   * todo bien.
   */
  poseFreshness(now) {
    if (!this.pageTransform) return 0;
    const hold = this.#holdMs();
    // Se desvanece en el último tramo del sostén, no en un tiempo fijo: si el sostén es
    // largo porque el teléfono está quieto, el bicho se queda entero todo ese rato.
    const age = now - this.lastMarkersSeen - Math.max(CAPTURE.poseGraceMs, hold - CAPTURE.poseFadeMs);
    if (age <= 0) return 1;
    return Math.max(0, 1 - age / CAPTURE.poseFadeMs);
  }

  /**
   * Las cuatro esquinas del rectángulo de las marcas, en coordenadas de video.
   *
   * Sirve para tapar el dibujo impreso: todo lo que está entre las marcas es territorio de la
   * app. Va aparte de `getCharacterGeometry` porque eso devuelve el marco del PERSONAJE, que es
   * más chico y depende de la especie; las marcas son de la HOJA y son siempre las mismas.
   */
  getSheetGeometry(now) {
    if (!this.hasMarkers(now) || !this.pageTransform) return null;
    const xs = TEMPLATE.markers.map((p) => p[0]);
    const ys = TEMPLATE.markers.map((p) => p[1]);
    const h = TEMPLATE.markerSize / 2;
    const rect = [
      [Math.min(...xs) + h, Math.min(...ys) + h],
      [Math.max(...xs) - h, Math.min(...ys) + h],
      [Math.max(...xs) - h, Math.max(...ys) - h],
      [Math.min(...xs) + h, Math.max(...ys) - h],
    ];
    return rect.map(([x, y]) => transformPoint(this.pageTransform, x, y));
  }

  getCharacterGeometry(now, frame) {
    if (!this.hasMarkers(now)) return null;
    if (this.markerCount < REGISTRATION.minMarkers) return null;

    const corners = framePagePoints(frame).map(([x, y]) => transformPoint(this.pageTransform, x, y));
    if (corners.some(([x, y]) => !Number.isFinite(x) || !Number.isFinite(y))) return null;
    if (!isConvexQuad(corners)) return null;
    const transform = homographyLS(UNIT_SQUARE, corners);
    if (!transform) return null;

    return {
      corners,
      transform,
      pageTransform: this.pageTransform.slice(),
      mode: "markers",
      markerCount: this.markerCount,
      error: this.diagnostics?.qrErrorPage ?? null,
      motion: this.motion,
    };
  }

  getMarkers() {
    return this.markersRaw ? this.markersRaw.map((point) => (point ? point.slice() : null)) : null;
  }

  #detectQr(now) {
    const width = this.video.videoWidth;
    const height = this.video.videoHeight;
    let localResult = null;
    if (this.qrCornersSmooth) {
      const xs = this.qrCornersSmooth.map((point) => point[0]);
      const ys = this.qrCornersSmooth.map((point) => point[1]);
      const minX = Math.min(...xs);
      const minY = Math.min(...ys);
      const boxWidth = Math.max(30, Math.max(...xs) - minX);
      const boxHeight = Math.max(30, Math.max(...ys) - minY);
      localResult = this.#readQrRegion({
        x: Math.max(0, minX - boxWidth * 0.9),
        y: Math.max(0, minY - boxHeight * 0.9),
        width: boxWidth * 2.8,
        height: boxHeight * 2.8,
      }, CAPTURE.qrWarmWidth);
    }
    if (localResult) return localResult;
    // El barrido completo es caro; se limita mientras no hay enganche y se rota la resolución.
    if (now - this.lastColdScan < CAPTURE.qrColdIntervalMs) return null;
    this.lastColdScan = now;
    const widths = CAPTURE.qrColdWidths;
    const target = widths[this.coldWidthIndex % widths.length];
    this.coldWidthIndex += 1;
    return this.#readQrRegion({ x: 0, y: 0, width, height }, target);
  }

  #readQrRegion(region, maxWidth) {
    // Todo entero: jsQR exige data.length === width * height * 4 y el canvas trunca los decimales.
    const originX = Math.max(0, Math.floor(region.x));
    const originY = Math.max(0, Math.floor(region.y));
    const sourceWidth = Math.floor(Math.min(region.width, this.video.videoWidth - originX));
    const sourceHeight = Math.floor(Math.min(region.height, this.video.videoHeight - originY));
    if (sourceWidth < 35 || sourceHeight < 35) return null;
    const targetWidth = Math.round(Math.min(maxWidth, Math.max(320, sourceWidth)));
    const scale = targetWidth / sourceWidth;
    const targetHeight = Math.max(1, Math.round(sourceHeight * scale));
    this.qrCanvas.width = targetWidth;
    this.qrCanvas.height = targetHeight;
    this.qrContext.drawImage(this.video, originX, originY, sourceWidth, sourceHeight, 0, 0, targetWidth, targetHeight);
    const image = this.qrContext.getImageData(0, 0, targetWidth, targetHeight);
    let result = null;
    try {
      result = window.jsQR(image.data, targetWidth, targetHeight, { inversionAttempts: "attemptBoth" });
    } catch (error) {
      return null;
    }
    if (!result?.location) return null;
    const scaleX = sourceWidth / targetWidth;
    const scaleY = sourceHeight / targetHeight;
    const map = (point) => [originX + point.x * scaleX, originY + point.y * scaleY];
    return {
      data: result.data,
      corners: [
        map(result.location.topLeftCorner),
        map(result.location.topRightCorner),
        map(result.location.bottomRightCorner),
        map(result.location.bottomLeftCorner),
      ],
    };
  }

  /**
   * Lee un recorte cuadrado del video alrededor de un punto y lo devuelve en escala de grises.
   * El rástrer se acota a `roiRaster` px: con la hoja cerca de la cámara el recorte puede
   * medir cientos de px y no hace falta esa resolución para centrar un cuadrado.
   */
  #readRoi(centerX, centerY, radius) {
    const videoWidth = this.video.videoWidth;
    const videoHeight = this.video.videoHeight;
    const size = Math.round(radius * 2);
    if (!Number.isFinite(size) || size < 12 || size > videoWidth || size > videoHeight) return null;
    // Se desplaza el recorte para que quepa en el frame; si la marca queda pegada al borde,
    // findSquare la descarta porque el blob toca el límite.
    const x0 = Math.max(0, Math.min(Math.round(centerX - radius), videoWidth - size));
    const y0 = Math.max(0, Math.min(Math.round(centerY - radius), videoHeight - size));
    const raster = Math.min(size, REGISTRATION.roiRaster);
    const scale = raster / size;
    this.roiCanvas.width = raster;
    this.roiCanvas.height = raster;
    this.roiContext.drawImage(this.video, x0, y0, size, size, 0, 0, raster, raster);
    const data = this.roiContext.getImageData(0, 0, raster, raster).data;
    const gray = new Uint8Array(raster * raster);
    for (let index = 0, pixel = 0; index < gray.length; index += 1, pixel += 4) {
      gray[index] = grayscale(data[pixel], data[pixel + 1], data[pixel + 2]);
    }
    return { gray, size: raster, x0, y0, scale };
  }

  #locateMarkers(baseTransform, radiusFactors) {
    const pagePoints = markerPagePoints();
    const found = new Array(4).fill(null);
    // Escala de referencia tomada del propio QR: la homografía del QR extrapolada hasta las
    // marcas inferiores (5,5 alturas de QR más abajo) puede devolver escalas absurdas o
    // negativas. Sirve de acotación.
    const qrSide = averageSideLength(this.qrCornersRaw);
    const referenceScale = qrSide / ((TEMPLATE.qr.x1 - TEMPLATE.qr.x0));

    for (let index = 0; index < 4; index += 1) {
      const [pageX, pageY] = pagePoints[index];
      const prediction = transformPoint(baseTransform, pageX, pageY);
      if (!Number.isFinite(prediction[0]) || !Number.isFinite(prediction[1])) continue;
      let scale = localScale(baseTransform, pageX, pageY, 30);
      if (!scale || !Number.isFinite(scale)) scale = referenceScale;
      scale = Math.max(referenceScale * 0.3, Math.min(referenceScale * 3, scale));
      const expectedSide = TEMPLATE.markerSize * scale;
      if (!(expectedSide >= 5)) continue;
      const factor = Array.isArray(radiusFactors) ? radiusFactors[index] : radiusFactors;
      if (!factor) continue;
      const roi = this.#readRoi(prediction[0], prediction[1], expectedSide * factor);
      if (!roi) continue;
      const square = findSquare(
        roi.gray, roi.size, roi.size, expectedSide * roi.scale,
        (prediction[0] - roi.x0) * roi.scale, (prediction[1] - roi.y0) * roi.scale,
      );
      if (!square) continue;
      found[index] = {
        point: [roi.x0 + square.point[0] / roi.scale, roi.y0 + square.point[1] / roi.scale],
        side: square.side / roi.scale,
        expectedSide,
        score: square.score,
      };
    }
    return found;
  }

  /** Ajuste provisional (QR + las marcas que haya). Sólo sirve para predecir dónde buscar. */
  #fitForPrediction(found) {
    const pagePoints = markerPagePoints();
    const qrPage = qrPagePoints();
    const source = [];
    const destination = [];
    const weights = [];
    for (let index = 0; index < 4; index += 1) {
      source.push(qrPage[index]);
      destination.push(this.qrCornersRaw[index]);
      weights.push(REGISTRATION.qrWeight);
    }
    let count = 0;
    for (let index = 0; index < 4; index += 1) {
      if (!found[index]) continue;
      count += 1;
      source.push(pagePoints[index]);
      destination.push(found[index].point);
      weights.push(REGISTRATION.markerWeight);
    }
    if (count < 2) return null;
    const matrix = homographyLS(source, destination, weights);
    if (!matrix) return null;
    return { matrix, count };
  }

  #scanMarkers(now) {
    if (!this.qrCornersRaw) return;
    const qrPage = qrPagePoints();
    const qrOnly = homographyLS(qrPage, this.qrCornersRaw);
    if (!qrOnly) return;

    const R = REGISTRATION;
    const warm = this.pageTransform && now - this.lastMarkersSeen < this.#holdMs();
    const countOf = (list) => list.filter(Boolean).length;

    // Pasada 1: se predice con el ajuste del frame anterior si sigue fresco, si no con el QR.
    let found = this.#locateMarkers(
      warm ? this.pageTransform : qrOnly,
      warm ? R.searchRadiusWarm : R.searchRadiusCold,
    );
    if (countOf(found) < 4 && warm) {
      const cold = this.#locateMarkers(qrOnly, R.searchRadiusCold);
      if (countOf(cold) > countOf(found)) found = cold;
    }

    // Pasadas siguientes: se re-predice con un ajuste que ya incorpora las marcas halladas.
    // Radio por marca: estrecho para reafinar las encontradas, ancho para las que faltan.
    // Predecir las que faltan con radio estrecho fue justamente lo que las perdía: extrapolar
    // sólo desde el QR erra hasta 3 lados de marca en las inferiores, en vistas oblicuas.
    for (let iteration = 0; iteration < R.refineIterations; iteration += 1) {
      const provisional = this.#fitForPrediction(found);
      if (!provisional) break;
      const radii = found.map((entry) => (entry ? R.searchRadiusWarm : R.searchRadiusMedium));
      const refined = this.#locateMarkers(provisional.matrix, radii);
      const merged = refined.map((entry, index) => entry || found[index]);
      if (countOf(merged) < countOf(found)) break;
      found = merged;
      if (countOf(found) === 4 && iteration > 0) break;
    }

    const points = found.map((entry) => (entry ? entry.point : null));
    const count = countOf(points);
    this.markerCount = count;
    this.markersRaw = points;

    if (count < 4) {
      this.pageTransform = null;
      this.diagnostics = { markerCount: count, missing: this.#missingLabels(points), qrErrorPage: null, motionPage: null };
      return;
    }

    // Ajuste FINAL: sólo las 4 marcas. Las esquinas del QR se excluyen a propósito;
    // jsQR las entrega con un sesgo del orden de un módulo (~11 px de página) y meterlas
    // aquí degrada el ajuste de 0,8 a 5 px de error e inutiliza cualquier gate de residuo.
    const matrix = homographyLS(markerPagePoints(), points);
    if (!matrix || !isConvexQuad(points)) {
      this.pageTransform = null;
      return;
    }

    const pageScale = localScale(matrix, TEMPLATE.width / 2, TEMPLATE.height / 2, 100) || 1;
    const qrErrorPage = reprojectionError(matrix, qrPage, this.qrCornersRaw).max / pageScale;
    const motionVideo = pointSetMovement(this.previousMarkers, points);
    const motionPage = motionVideo / pageScale;
    this.previousMarkers = points.map((point) => point.slice());
    this.diagnostics = {
      markerCount: count,
      missing: [],
      qrErrorPage: Number(qrErrorPage.toFixed(1)),
      motionPage: Number.isFinite(motionPage) ? Number(motionPage.toFixed(1)) : null,
    };

    // Cordura: si las marcas y el QR describen hojas distintas, se enganchó algo que no es
    // una marca. No es un gate de precisión, es un cortafuegos.
    if (!(qrErrorPage <= R.maxQrSanityPage)) {
      this.pageTransform = null;
      return;
    }

    this.motion = motionPage;
    this.pageTransform = matrix;
    this.lastMarkersSeen = now;
  }

  #missingLabels(points) {
    const labels = ["superior izquierda", "superior derecha", "inferior derecha", "inferior izquierda"];
    return labels.filter((_, index) => !points[index]);
  }

  /** Fuerza una detección completa sobre el frame actual, justo antes de capturar. */
  sync(now) {
    this.lastDetection = Number.NEGATIVE_INFINITY;
    this.lastMarkerScan = Number.NEGATIVE_INFINITY;
    this.lastColdScan = Number.NEGATIVE_INFINITY;
    this.coldWidthIndex = 0;
    this.update(now);
  }

  getDiagnostics() {
    return this.diagnostics || { markerCount: 0, missing: [], qrErrorPage: null, motionPage: null };
  }
}
