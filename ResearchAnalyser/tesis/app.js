const C = {
  purple: "#8C4799",
  purpleDark: "#66356F",
  purpleSoft: "#EFE3F2",
  orange: "#EA7600",
  teal: "#00A499",
  blue: "#002F6C",
  gray: "#394049",
  line: "#E4DAEA"
};

const PREGRADO = [
  "INGENIERÍA DE EJECUCIÓN EN COMPUTACIÓN E INFORMÁTICA",
  "INGENIERÍA CIVIL EN INFORMÁTICA"
];

const POSGRADO = [
  "MAGÍSTER EN INGENIERÍA INFORMÁTICA",
  "MAGÍSTER EN SEGURIDAD, PERITAJE Y AUDITORÍA EN PROCESOS INFORMÁTICOS",
  "DOCTORADO EN CIENCIAS DE LA INGENIERÍA, MENCIÓN INGENIERÍA INFORMÁTICA"
];

const INVALID = new Set(["", "-", "NA", "#N/A", "N/A", "SIN INFORMACIÓN", "SIN INFORMACION"]);

const state = {
  data: [],
  academics: [],
  filtered: [],
  years: [2015, 2025],
  indicatorMode: "departamento",
  profileMode: "departamento",
  tables: {},
  network: null,
  bound: false
};

function el(id){ return document.getElementById(id); }
function tt(key, es){
  if(typeof T !== "function") return es;
  const v = T(key);
  return (v && v !== key) ? v : es;
}
function tf(key, es, vars){
  let s = tt(key, es);
  if(vars) Object.keys(vars).forEach(k => { s = s.split("{"+k+"}").join(vars[k]); });
  return s;
}

function clean(v){
  return (v ?? "").toString().trim();
}

function valid(v){
  const x = clean(v).toUpperCase();
  return x && !INVALID.has(x);
}

function titleCase(s){
  return clean(s).toLocaleLowerCase("es-CL").replace(/(^|\s|\/|-)(\p{L})/gu, (m, p1, p2) => p1 + p2.toLocaleUpperCase("es-CL"));
}

function compactName(s){
  return titleCase(s).replace(/\s+/g, " ");
}

function programOf(row){          // etiqueta para mostrar: todos los niveles del trabajo
  return programsOf(row).join(" · ");
}
/* Niveles de programa a los que pertenece el trabajo. Una tesis puede ser de
   pregrado Y posgrado a la vez, así que devolvemos ambos (no solo el pregrado). */
function programsOf(row){
  const out = [];
  if(valid(row.PREGRADO)) out.push(clean(row.PREGRADO));
  if(valid(row.POSGRADO)) out.push(clean(row.POSGRADO));
  if(!out.length && valid(row.MODALIDAD)) out.push(clean(row.MODALIDAD));
  return out.length ? out : ["Sin programa informado"];
}
/* Etiqueta corta para ejes de gráficos (el nombre completo va en el hover) */
function shortProgram(name){
  const n = clean(name).toLocaleUpperCase("es-CL");
  if(!valid(name) || n.includes("SIN PROGRAMA")) return tt("prog.none", "Sin programa");
  if(n.includes("EJECUCI")) return tt("prog.exec", "Ing. de Ejecución");
  if(n.includes("CIVIL")) return tt("prog.civil", "Ing. Civil en Informática");
  if(n.includes("DOCTOR")) return tt("prog.phd", "Doctorado en Cs. Ingeniería");
  if(n.includes("SEGURIDAD") || n.includes("PERITAJE") || n.includes("AUDITOR")) return tt("prog.msec", "Magíster en Seguridad");
  if(n.includes("MAG")) return tt("prog.minf", "Magíster en Informática");
  const t = titleCase(name);
  return t.length > 30 ? t.slice(0, 28) + "…" : t;
}

function yearOf(row){
  return Number(row["ANIO PUBLICACION"]) || null;
}

function cleanDomain(v){
  let x = clean(v);
  if(!valid(x)) return "";
  if(/does not belong to the computer science field/i.test(x)) return "";
  x = x.replace(/\(.*?\)/g, "").trim();
  if(!valid(x)) return "";
  return titleCase(x);
}

function topCounts(rows, accessor, limit = 10){
  const map = new Map();
  rows.forEach(row => {
    const raw = accessor(row);
    const values = Array.isArray(raw) ? raw : [raw];   // permite accessors multivaluados
    values.forEach(value => {
      if(!valid(value)) return;
      map.set(value, (map.get(value) || 0) + 1);
    });
  });
  return [...map.entries()]
    .map(([name, value]) => ({name, value}))
    .sort((a,b) => b.value - a.value || a.name.localeCompare(b.name))
    .slice(0, limit);
}

function countWhere(rows, pred){
  return rows.reduce((acc, row) => acc + (pred(row) ? 1 : 0), 0);
}

function percent(n, total){
  return total ? (n * 100 / total) : 0;
}

function fmt(n){
  return Number(n || 0).toLocaleString("es-CL");
}

// Enteros sin decimales; el resto con UNA cifra decimal.
function nf(v){
  const x = Number(v);
  if(!isFinite(x)) return v;
  const r = Math.round(x * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
}

function pct(n){
  return `${Number(n || 0).toLocaleString("es-CL", {maximumFractionDigits: 1})}%`;
}

function plotLayout(extra = {}){
  return {
    paper_bgcolor: "rgba(0,0,0,0)",
    plot_bgcolor: "rgba(0,0,0,0)",
    font: {family: "Inter, sans-serif", color: C.gray},
    margin: {l: 48, r: 18, t: 20, b: 58},
    colorway: [C.purple, C.orange, C.teal, C.blue],
    xaxis: {gridcolor: "#F0EAF3", zeroline: false},
    yaxis: {gridcolor: "#F0EAF3", zeroline: false},
    hoverlabel: {bgcolor: "#fff", bordercolor: C.line, font: {color: C.gray}},
    ...extra
  };
}

function plotConfig(){
  return {displayModeBar: false, responsive: true, locale: "es"};
}

function setOptions(select, values, allLabel){
  select.innerHTML = "";
  if(allLabel){
    const opt = document.createElement("option");
    opt.value = "";
    opt.textContent = allLabel;
    select.appendChild(opt);
  }
  values.forEach(v => {
    const opt = document.createElement("option");
    opt.value = v;
    opt.textContent = compactName(v);
    select.appendChild(opt);
  });
}

function allAcademics(){
  const s = new Set();
  state.data.forEach(row => {
    if(valid(row["PROFESOR GUIA"])) s.add(clean(row["PROFESOR GUIA"]));
    if(valid(row["PROFESOR COGUIA"])) s.add(clean(row["PROFESOR COGUIA"]));
  });
  return [...s].sort((a,b) => a.localeCompare(b, "es"));
}

function applyFilters(){
  const yMin = Number(el("y_min").value);
  const yMax = Number(el("y_max").value);
  const lo = Math.min(yMin, yMax);
  const hi = Math.max(yMin, yMax);
  const inst = el("f_institucion").value;
  const dep = el("f_departamento").value;
  state.years = [lo, hi];

  state.filtered = state.data.filter(row => {
    const y = yearOf(row);
    if(!y || y < lo || y > hi) return false;
    if(inst && clean(row.UNIVERSIDAD) !== inst) return false;
    if(dep && clean(row.DEPARTAMENTO) !== dep) return false;
    return true;
  });

  updateYearFill();
  renderAll();
}

// Nombre institucional legible (minúsculas en conectores)
function prettyOrg(s){
  const low = new Set(["de","del","la","las","los","el","y","en","e","da","do"]);
  return titleCase(s).split(" ").map((w,i) => (i>0 && low.has(w.toLocaleLowerCase("es-CL"))) ? w.toLocaleLowerCase("es-CL") : w).join(" ");
}

// Departamentos disponibles según la institución elegida (cascada)
function populateDepartamentos(){
  const inst = el("f_institucion").value;
  const deps = [...new Set(state.data.filter(r => !inst || clean(r.UNIVERSIDAD) === inst).map(r => clean(r.DEPARTAMENTO)).filter(Boolean))].sort((a,b) => a.localeCompare(b, "es"));
  const cur = el("f_departamento").value;
  const sel = el("f_departamento");
  sel.innerHTML = deps.map(d => `<option value="${d.replace(/"/g,"&quot;")}">${prettyOrg(d)}</option>`).join("");
  if(deps.includes(cur)) sel.value = cur;
}

function updateYearFill(){
  const min = Number(el("y_min").min);
  const max = Number(el("y_min").max);
  const [lo, hi] = state.years;
  el("y_lo").textContent = lo;
  el("y_hi").textContent = hi;
  const left = ((lo - min) / (max - min)) * 100;
  const right = 100 - ((hi - min) / (max - min)) * 100;
  el("y_fill").style.left = `${left}%`;
  el("y_fill").style.right = `${right}%`;
}

