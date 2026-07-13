import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exitCode = 1;
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function read(relativePath) {
  const fullPath = path.join(root, relativePath);
  assert(fs.existsSync(fullPath), `Missing file: ${relativePath}`);
  return fs.readFileSync(fullPath, 'utf8');
}

function parseDataFile(relativePath, variableName) {
  const text = read(relativePath).trim();
  const prefix = `window.${variableName}=`;
  assert(text.startsWith(prefix), `${relativePath} must start with ${prefix}`);
  assert(text.endsWith(';'), `${relativePath} must end with a semicolon`);

  const jsonText = text.slice(prefix.length, -1);
  let data;
  try {
    data = JSON.parse(jsonText);
  } catch (error) {
    fail(`${relativePath} contains invalid JSON: ${error.message}`);
    return { type: null, features: [] };
  }

  assert(data.type === 'FeatureCollection', `${relativePath} must be a GeoJSON FeatureCollection`);
  assert(Array.isArray(data.features), `${relativePath} must contain a features array`);
  return data;
}

function validateProperties(data, requiredKeys, label) {
  for (const [index, feature] of data.features.entries()) {
    assert(feature?.type === 'Feature', `${label} feature ${index} is not a GeoJSON Feature`);
    assert(feature?.geometry, `${label} feature ${index} has no geometry`);
    assert(feature?.properties, `${label} feature ${index} has no properties`);
    for (const key of requiredKeys) {
      assert(Object.hasOwn(feature.properties, key), `${label} feature ${index} is missing property ${key}`);
    }
  }
}

const index = read('index.html');
for (const asset of [
  'lib/leaflet.css',
  'lib/MarkerCluster.css',
  'lib/MarkerCluster.Default.css',
  'lib/leaflet.js',
  'lib/leaflet.markercluster.js',
  'data/comunas.js',
  'data/resultados.js',
  'data/isocronas.js',
  'data/hospitales.js',
]) {
  assert(index.includes(asset), `index.html does not reference ${asset}`);
  assert(fs.existsSync(path.join(root, asset)), `Referenced asset does not exist: ${asset}`);
}

const zones = parseDataFile('data/resultados.js', 'DATA_RESULTADOS');
const municipalities = parseDataFile('data/comunas.js', 'DATA_COMUNAS');
const isochrones = parseDataFile('data/isocronas.js', 'DATA_ISOCRONAS');
const facilities = parseDataFile('data/hospitales.js', 'DATA_HOSPITALES');

assert(zones.features.length === 2371, `Expected 2,371 census zones, found ${zones.features.length}`);
assert(municipalities.features.length === 52, `Expected 52 municipalities, found ${municipalities.features.length}`);
assert(isochrones.features.length === 6, `Expected 6 isochrones, found ${isochrones.features.length}`);
assert(facilities.features.length === 113, `Expected 113 facilities, found ${facilities.features.length}`);

validateProperties(zones, [
  'geocodigo', 'nom_comuna', 'codigo_com', 'P_AB', 'P_DB_Diabe', 'P_HT',
  'FonasaAoB', 'Diabetes', 'Hipertensi', 'POB_30_MAS', 'POB_60_MAS',
  'TASA_ADULT', 'minutos_vi', 'cluster',
], 'Census zone');

validateProperties(municipalities, ['NOM_COMUNA', 'CUT', 'NOM_PROVIN'], 'Municipality');
validateProperties(isochrones, ['contour'], 'Isochrone');
validateProperties(facilities, ['nombre', 'tipo', 'comuna', 'acv'], 'Facility');
for (const [index, feature] of facilities.features.entries()) {
  if (Boolean(feature.properties.acv)) {
    for (const key of ['f2019', 'f2020', 'f2021', 'fprom']) {
      assert(Object.hasOwn(feature.properties, key), `Stroke facility feature ${index} is missing property ${key}`);
    }
  }
}

const contours = [...new Set(isochrones.features.map((feature) => Number(feature.properties.contour)))].sort((a, b) => a - b);
assert(JSON.stringify(contours) === JSON.stringify([10, 20, 30, 40, 50, 60]), `Unexpected isochrone intervals: ${contours.join(', ')}`);

const facilityTypes = new Set(facilities.features.map((feature) => feature.properties.tipo));
for (const expectedType of ['Hospital', 'Clínica', 'Instituto']) {
  assert(facilityTypes.has(expectedType), `Missing facility type: ${expectedType}`);
}

const strokeHospitals = facilities.features.filter((feature) => Boolean(feature.properties.acv)).length;
assert(strokeHospitals === 21, `Expected 21 stroke hospitals, found ${strokeHospitals}`);

if (process.exitCode) {
  console.error('Validation failed.');
  process.exit(process.exitCode);
}

console.log('Validation passed:');
console.log(`- ${zones.features.length.toLocaleString('en-US')} census zones`);
console.log(`- ${municipalities.features.length} municipalities`);
console.log(`- ${isochrones.features.length} isochrone intervals`);
console.log(`- ${facilities.features.length} healthcare facilities`);
console.log(`- ${strokeHospitals} stroke-treating hospitals`);
