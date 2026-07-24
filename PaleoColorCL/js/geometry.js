// Álgebra de homografías con normalización de Hartley y ajuste por mínimos cuadrados.

function solveLinearSystem(matrix, vector) {
  const size = vector.length;
  const augmented = matrix.map((row, index) => [...row, vector[index]]);
  for (let column = 0; column < size; column += 1) {
    let pivot = column;
    for (let row = column + 1; row < size; row += 1) {
      if (Math.abs(augmented[row][column]) > Math.abs(augmented[pivot][column])) pivot = row;
    }
    if (Math.abs(augmented[pivot][column]) < 1e-12) return null;
    [augmented[column], augmented[pivot]] = [augmented[pivot], augmented[column]];
    const divisor = augmented[column][column];
    for (let item = column; item <= size; item += 1) augmented[column][item] /= divisor;
    for (let row = 0; row < size; row += 1) {
      if (row === column) continue;
      const factor = augmented[row][column];
      if (!factor) continue;
      for (let item = column; item <= size; item += 1) augmented[row][item] -= factor * augmented[column][item];
    }
  }
  return augmented.map((row) => row[size]);
}

function matMul3(a, b) {
  const out = new Array(9).fill(0);
  for (let row = 0; row < 3; row += 1) {
    for (let column = 0; column < 3; column += 1) {
      let sum = 0;
      for (let k = 0; k < 3; k += 1) sum += a[row * 3 + k] * b[k * 3 + column];
      out[row * 3 + column] = sum;
    }
  }
  return out;
}

function matInverse3(m) {
  const a = m[4] * m[8] - m[5] * m[7];
  const b = m[5] * m[6] - m[3] * m[8];
  const c = m[3] * m[7] - m[4] * m[6];
  const determinant = m[0] * a + m[1] * b + m[2] * c;
  if (Math.abs(determinant) < 1e-14) return null;
  const inverse = determinant;
  return [
    a / inverse,
    (m[2] * m[7] - m[1] * m[8]) / inverse,
    (m[1] * m[5] - m[2] * m[4]) / inverse,
    b / inverse,
    (m[0] * m[8] - m[2] * m[6]) / inverse,
    (m[2] * m[3] - m[0] * m[5]) / inverse,
    c / inverse,
    (m[1] * m[6] - m[0] * m[7]) / inverse,
    (m[0] * m[4] - m[1] * m[3]) / inverse,
  ];
}

export function transformPoint(matrix, x, y) {
  const denominator = matrix[6] * x + matrix[7] * y + matrix[8];
  if (Math.abs(denominator) < 1e-10) return [Number.NaN, Number.NaN];
  return [
    (matrix[0] * x + matrix[1] * y + matrix[2]) / denominator,
    (matrix[3] * x + matrix[4] * y + matrix[5]) / denominator,
  ];
}

function transformPoints(matrix, points) {
  return points.map(([x, y]) => transformPoint(matrix, x, y));
}

function buildNormalizer(points) {
  let centerX = 0;
  let centerY = 0;
  for (const [x, y] of points) {
    centerX += x;
    centerY += y;
  }
  centerX /= points.length;
  centerY /= points.length;
  let distance = 0;
  for (const [x, y] of points) distance += Math.hypot(x - centerX, y - centerY);
  distance /= points.length;
  const scale = distance > 1e-9 ? Math.SQRT2 / distance : 1;
  return [scale, 0, -scale * centerX, 0, scale, -scale * centerY, 0, 0, 1];
}

/**
 * Homografía source -> destination por DLT normalizado.
 * Acepta 4 o más correspondencias; con más de 4 resuelve por mínimos cuadrados ponderados.
 */
export function homographyLS(source, destination, weights = null) {
  const count = source.length;
  if (count < 4 || destination.length !== count) return null;

  const normalizeSource = buildNormalizer(source);
  const normalizeDestination = buildNormalizer(destination);
  const s = transformPoints(normalizeSource, source);
  const d = transformPoints(normalizeDestination, destination);

  const normal = Array.from({ length: 8 }, () => new Array(8).fill(0));
  const rhs = new Array(8).fill(0);

  for (let index = 0; index < count; index += 1) {
    const [x, y] = s[index];
    const [u, v] = d[index];
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(u) || !Number.isFinite(v)) return null;
    const weight = weights ? Math.max(0, weights[index]) : 1;
    if (weight <= 0) continue;
    const rows = [
      { row: [x, y, 1, 0, 0, 0, -x * u, -y * u], value: u },
      { row: [0, 0, 0, x, y, 1, -x * v, -y * v], value: v },
    ];
    for (const { row, value } of rows) {
      for (let i = 0; i < 8; i += 1) {
        if (!row[i]) continue;
        for (let j = 0; j < 8; j += 1) normal[i][j] += weight * row[i] * row[j];
        rhs[i] += weight * row[i] * value;
      }
    }
  }

  const solution = solveLinearSystem(normal, rhs);
  if (!solution || solution.some((value) => !Number.isFinite(value))) return null;

  const normalized = [...solution, 1];
  const inverseDestination = matInverse3(normalizeDestination);
  if (!inverseDestination) return null;
  const matrix = matMul3(inverseDestination, matMul3(normalized, normalizeSource));
  if (Math.abs(matrix[8]) < 1e-12) return null;
  return matrix.map((value) => value / matrix[8]);
}

export function reprojectionError(matrix, source, destination) {
  let maximum = 0;
  let sum = 0;
  for (let index = 0; index < source.length; index += 1) {
    const [x, y] = transformPoint(matrix, source[index][0], source[index][1]);
    if (!Number.isFinite(x) || !Number.isFinite(y)) return { max: Infinity, rms: Infinity };
    const distance = Math.hypot(x - destination[index][0], y - destination[index][1]);
    maximum = Math.max(maximum, distance);
    sum += distance * distance;
  }
  return { max: maximum, rms: Math.sqrt(sum / source.length) };
}

/** Escala local (px de video por px de página) alrededor de un punto de página. */
export function localScale(matrix, x, y, delta = 20) {
  const a = transformPoint(matrix, x - delta, y);
  const b = transformPoint(matrix, x + delta, y);
  const c = transformPoint(matrix, x, y - delta);
  const e = transformPoint(matrix, x, y + delta);
  const horizontal = Math.hypot(b[0] - a[0], b[1] - a[1]) / (2 * delta);
  const vertical = Math.hypot(e[0] - c[0], e[1] - c[1]) / (2 * delta);
  const scale = (horizontal + vertical) / 2;
  return Number.isFinite(scale) && scale > 0 ? scale : null;
}

export function isConvexQuad(points) {
  let sign = 0;
  for (let index = 0; index < 4; index += 1) {
    const a = points[index];
    const b = points[(index + 1) % 4];
    const c = points[(index + 2) % 4];
    const cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
    if (Math.abs(cross) < 1e-6) continue;
    const current = Math.sign(cross);
    if (sign === 0) sign = current;
    else if (current !== sign) return false;
  }
  return sign !== 0;
}

export function smoothPointSet(previous, next, baseAlpha = 0.34) {
  if (!previous || previous.length !== next.length) return next.map((point) => point.slice());
  let movement = 0;
  for (let index = 0; index < next.length; index += 1) {
    movement += Math.hypot(next[index][0] - previous[index][0], next[index][1] - previous[index][1]);
  }
  movement /= next.length;
  const alpha = movement > 40 ? 0.76 : movement > 16 ? 0.52 : baseAlpha;
  return next.map((point, index) => [
    previous[index][0] + (point[0] - previous[index][0]) * alpha,
    previous[index][1] + (point[1] - previous[index][1]) * alpha,
  ]);
}

export function pointSetMovement(previous, next) {
  if (!previous || !next || previous.length !== next.length) return Infinity;
  let movement = 0;
  for (let index = 0; index < next.length; index += 1) {
    movement += Math.hypot(next[index][0] - previous[index][0], next[index][1] - previous[index][1]);
  }
  return movement / next.length;
}

export function averageSideLength(points) {
  let total = 0;
  for (let index = 0; index < points.length; index += 1) {
    const next = points[(index + 1) % points.length];
    total += Math.hypot(next[0] - points[index][0], next[1] - points[index][1]);
  }
  return total / points.length;
}

export function easeInOut(value) {
  const clamped = Math.max(0, Math.min(1, value));
  return clamped * clamped * (3 - 2 * clamped);
}
