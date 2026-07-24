/* ============================================================
   INIT · parseo/carga de CSV, cableado de eventos, arranque.
   Se carga al final; dispara todo en DOMContentLoaded.
   ============================================================ */
function parseCSV(text){
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;

  for(let i = 0; i < text.length; i++){
    const ch = text[i];
    const next = text[i + 1];

    if(ch === '"'){
      if(quoted && next === '"'){
        cell += '"';
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }

    if(ch === "," && !quoted){
      row.push(cell);
      cell = "";
      continue;
    }

    if((ch === "\n" || ch === "\r") && !quoted){
      if(ch === "\r" && next === "\n") i++;
      row.push(cell);
      if(row.some(v => v !== "")) rows.push(row);
      row = [];
      cell = "";
      continue;
    }

    cell += ch;
  }

  row.push(cell);
  if(row.some(v => v !== "")) rows.push(row);
  if(!rows.length) return [];

  const headers = rows[0].map(h => h.replace(/^\uFEFF/, "").trim());
  return rows.slice(1).map(values => {
    const obj = {};
    headers.forEach((h, i) => obj[h] = values[i] ?? "");
    return obj;
  });
}

async function loadCSV(path){
  const response = await fetch(path);
  if(!response.ok) throw new Error(`No se pudo cargar ${path}`);
  const text = await response.text();
  return parseCSV(text);
}

// Lee primero los datos empaquetados en data/data.js (window.*_CSV) para que la
// app funcione con doble clic en index.html, sin servidor. Si no están, cae al
// fetch del CSV (útil al servir la carpeta por http).
async function loadData(globalName, path){
  const embedded = window[globalName];
  if(typeof embedded === "string" && embedded.length){
    return parseCSV(embedded);
  }
  return loadCSV(path);
}

function readFileText(file){
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(reader.error || new Error(`No se pudo leer ${file.name}`));
    reader.readAsText(file, "utf-8");
  });
}

function showManualCSVLoader(err){
  const overlay = el("overlay");
  overlay.classList.remove("hide");
  overlay.innerHTML = `
    <div class="ov-card ov-card-wide">
      <div class="ov-t">No se pudieron leer los datos</div>
      <div class="ov-s">
        Falta el archivo empaquetado <b>data/data.js</b>. La app lo usa para arrancar con doble clic, sin servidor.
        <br><br>
        Regenéralo ejecutando <b>Conversor_tesis_v2.R</b> dentro de la carpeta <b>data/</b>, o sirve la carpeta por http para leer los CSV directamente.
      </div>
    </div>
  `;
}

function bindEvents(){
  if(state.bound) return;
  state.bound = true;

  el("tabs").addEventListener("click", e => {
    const btn = e.target.closest("button[data-tab]");
    if(!btn) return;
    document.querySelectorAll(".tabs button").forEach(b => b.classList.toggle("active", b === btn));
    document.querySelectorAll(".panel").forEach(p => p.classList.toggle("active", p.id === `p-${btn.dataset.tab}`));
    if(btn.dataset.tab === "asistente" && typeof buildChat === "function") buildChat(true);
    setTimeout(() => window.dispatchEvent(new Event("resize")), 80);
  });

  ["y_min", "y_max"].forEach(id => el(id).addEventListener("input", applyFilters));
  el("f_institucion").addEventListener("change", () => { populateDepartamentos(); applyFilters(); });
  el("f_departamento").addEventListener("change", applyFilters);
  ["dom_tipo", "dom_clave"].forEach(id => el(id).addEventListener("change", renderDomain));
  el("perf_academico").addEventListener("change", renderProfile);

  document.querySelectorAll("#ind_nivel button").forEach(btn => btn.addEventListener("click", () => {
    state.indicatorMode = btn.dataset.v;
    document.querySelectorAll("#ind_nivel button").forEach(b => b.classList.toggle("on", b === btn));
    renderIndicators();
  }));
  document.querySelectorAll("#perf_nivel button").forEach(btn => btn.addEventListener("click", () => {
    state.profileMode = btn.dataset.v;
    document.querySelectorAll("#perf_nivel button").forEach(b => b.classList.toggle("on", b === btn));
    renderProfile();
  }));

  const dl = el("dl_base"); if(dl) dl.addEventListener("click", descargarBaseDatos);
}

function bootstrapData(memorias, academicos){
  state.data = memorias.map(r => ({...r, "__year": yearOf(r)}));
  state.academics = academicos;
  const years = state.data.map(yearOf).filter(Boolean);
  const min = Math.min(...years);
  const max = Math.max(...years);
  ["y_min", "y_max"].forEach(id => {
    el(id).min = min;
    el(id).max = max;
  });
  el("y_min").value = min;
  el("y_max").value = max;

  const institutions = [...new Set(state.data.map(r => clean(r.UNIVERSIDAD)).filter(Boolean))].sort((a,b) => a.localeCompare(b, "es"));
  el("f_institucion").innerHTML = institutions.map(u => `<option value="${u.replace(/"/g,"&quot;")}">${prettyOrg(u)}</option>`).join("");
  populateDepartamentos();
  setOptions(el("perf_academico"), allAcademics(), null);

  bindEvents();
  applyFilters();
  el("overlay").classList.add("hide");
}

async function init(){
  const [memorias, academicos] = await Promise.all([
    loadData("MEMORIAS_CSV", "data/memorias.csv"),
    loadData("ACADEMICOS_CSV", "data/academicos.csv")
  ]);
  bootstrapData(memorias, academicos);
}

document.addEventListener("DOMContentLoaded", () => {
  init().catch(err => {
    console.error(err);
    showManualCSVLoader(err);
  });
});
