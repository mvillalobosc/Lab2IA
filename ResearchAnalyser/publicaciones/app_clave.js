/* ============================================================
   CLAVE DE DESCARGA
   Pide una contraseña antes de bajar la base de datos completa.

   La clave NO está en este archivo. Solo va su hash SHA-256, así
   nadie la saca mirando el código fuente con Ctrl+U.

   Para cambiarla, saca el hash nuevo y reemplaza CLAVE_HASH:
     Linux/Mac : echo -n "TuClaveNueva" | shasum -a 256
     R         : digest::digest("TuClaveNueva", algo="sha256", serialize=FALSE)
     Navegador : abre la consola (F12) y pega:
                 sha256Hex("TuClaveNueva")

   Alcance: esto controla la DESCARGA del archivo, no el acceso a
   la app. Pensado para uso interno del departamento.
   ============================================================ */

const CLAVE_HASH = "39ce7bc4b5c30ab4d68e94c4c77a5cf3d8aaa829d99fffd374be296fc1eccb10";

/* Queda desbloqueado mientras la pestaña siga abierta. Al recargar,
   vuelve a pedir la clave. No se guarda en el disco. */
let CLAVE_OK = false;

const CLAVE_TXT = {
  es: {
    titulo: "Descarga protegida",
    texto: "La base completa es de uso interno del Departamento. Escribe la contraseña para descargarla.",
    ph: "Contraseña",
    ok: "Descargar",
    cancelar: "Cancelar",
    error: "Contraseña incorrecta.",
    mostrar: "Mostrar contraseña",
    ocultar: "Ocultar contraseña",
    pedir: "¿No la tienes? Solicítala a manuel.villalobos@usach.cl"
  },
  en: {
    titulo: "Protected download",
    texto: "The full database is for internal Department use. Enter the password to download it.",
    ph: "Password",
    ok: "Download",
    cancelar: "Cancel",
    error: "Wrong password.",
    mostrar: "Show password",
    ocultar: "Hide password",
    pedir: "Don't have it? Request it at manuel.villalobos@usach.cl"
  },
  pt: {
    titulo: "Download protegido",
    texto: "A base completa é de uso interno do Departamento. Digite a senha para baixá-la.",
    ph: "Senha",
    ok: "Baixar",
    cancelar: "Cancelar",
    error: "Senha incorreta.",
    mostrar: "Mostrar senha",
    ocultar: "Ocultar senha",
    pedir: "Não tem? Solicite em manuel.villalobos@usach.cl"
  }
};

function claveTxt() {
  let lang = "es";
  try {
    if (typeof S === "object" && S && S.lang) lang = S.lang;
    else if (typeof state === "object" && state && state.lang) lang = state.lang;
  } catch (e) {}
  return CLAVE_TXT[lang] || CLAVE_TXT.es;
}

/* ------------------------------------------------------------
   SHA-256 propio.
   crypto.subtle NO existe al abrir la app con doble clic
   (file://), porque el navegador no lo considera contexto
   seguro. Por eso el hash se calcula acá y la clave funciona
   igual offline, sin servidor.
   ------------------------------------------------------------ */
function sha256Hex(msg) {
  const K = [
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  let H = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
  const utf8 = unescape(encodeURIComponent(msg));
  const len = utf8.length;
  const words = [];
  for (let i = 0; i < len; i++) words[i >> 2] |= (utf8.charCodeAt(i) & 0xff) << (24 - (i % 4) * 8);
  words[len >> 2] |= 0x80 << (24 - (len % 4) * 8);
  words[((len + 8) >> 6) * 16 + 15] = len * 8;
  const w = new Array(64);
  const rr = (x, n) => (x >>> n) | (x << (32 - n));
  for (let b = 0; b < words.length; b += 16) {
    for (let i = 0; i < 16; i++) w[i] = words[b + i] | 0;
    for (let i = 16; i < 64; i++) {
      const s0 = rr(w[i-15],7) ^ rr(w[i-15],18) ^ (w[i-15] >>> 3);
      const s1 = rr(w[i-2],17) ^ rr(w[i-2],19) ^ (w[i-2] >>> 10);
      w[i] = (w[i-16] + s0 + w[i-7] + s1) | 0;
    }
    let a = H[0], bb = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];
    for (let i = 0; i < 64; i++) {
      const S1 = rr(e,6) ^ rr(e,11) ^ rr(e,25);
      const ch = (e & f) ^ (~e & g);
      const t1 = (h + S1 + ch + K[i] + w[i]) | 0;
      const S0 = rr(a,2) ^ rr(a,13) ^ rr(a,22);
      const mj = (a & bb) ^ (a & c) ^ (bb & c);
      const t2 = (S0 + mj) | 0;
      h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = bb; bb = a; a = (t1 + t2) | 0;
    }
    H = [(H[0]+a)|0,(H[1]+bb)|0,(H[2]+c)|0,(H[3]+d)|0,(H[4]+e)|0,(H[5]+f)|0,(H[6]+g)|0,(H[7]+h)|0];
  }
  return H.map(x => (x >>> 0).toString(16).padStart(8, "0")).join("");
}

function cerrarModalClave() {
  const m = document.getElementById("clave_modal");
  if (m) m.remove();
}

/* Muestra el modal y ejecuta alDesbloquear() solo si la clave es correcta. */
function pedirClave(alDesbloquear) {
  if (CLAVE_OK) { alDesbloquear(); return; }
  if (document.getElementById("clave_modal")) return;

  const t = claveTxt();
  const wrap = document.createElement("div");
  wrap.id = "clave_modal";
  wrap.style.cssText =
    "position:fixed;inset:0;z-index:9999;display:flex;align-items:center;" +
    "justify-content:center;padding:20px;background:rgba(16,24,40,.55);" +
    "backdrop-filter:blur(5px);";

  wrap.innerHTML = `
    <div role="dialog" aria-modal="true" aria-labelledby="clave_t" style="
      width:min(430px,100%);padding:26px;border-radius:14px;background:#fff;
      box-shadow:0 30px 70px rgba(7,27,61,.28);font-family:inherit;">
      <div id="clave_t" style="font-size:.76rem;font-weight:700;letter-spacing:.07em;
        text-transform:uppercase;color:#5C636B;margin-bottom:6px;">
        <i class="fa-solid fa-lock"></i> ${t.titulo}
      </div>
      <p style="margin:0 0 16px;color:#5C636B;line-height:1.55;font-size:.95rem;">${t.texto}</p>

      <div style="position:relative;">
        <input id="clave_input" type="password" autocomplete="off" placeholder="${t.ph}"
          style="width:100%;padding:12px 46px 12px 14px;border:1px solid #DBE2E8;
          border-radius:9px;font:inherit;font-size:1rem;box-sizing:border-box;">
        <button id="clave_ver" type="button" aria-label="${t.mostrar}" title="${t.mostrar}"
          style="position:absolute;right:5px;top:50%;transform:translateY(-50%);
          width:36px;height:36px;display:flex;align-items:center;justify-content:center;
          border:0;border-radius:8px;background:transparent;color:#8C969D;
          cursor:pointer;font-size:1rem;padding:0;">
          <i id="clave_ojo" class="fa-solid fa-eye"></i>
        </button>
      </div>

      <div id="clave_err" style="display:none;margin-top:9px;color:#C0392B;
        font-size:.87rem;font-weight:600;"></div>
      <div style="display:flex;gap:10px;margin-top:18px;">
        <button id="clave_ok" style="flex:1;padding:12px;border:0;border-radius:9px;
          background:#00A499;color:#fff;font:inherit;font-weight:700;cursor:pointer;">
          ${t.ok}
        </button>
        <button id="clave_no" style="padding:12px 18px;border:1px solid #DBE2E8;
          border-radius:9px;background:#fff;color:#5C636B;font:inherit;cursor:pointer;">
          ${t.cancelar}
        </button>
      </div>
      <p style="margin:16px 0 0;font-size:.82rem;color:#8C969D;line-height:1.5;">${t.pedir}</p>
    </div>`;

  document.body.appendChild(wrap);

  const input = document.getElementById("clave_input");
  const err = document.getElementById("clave_err");
  const btnVer = document.getElementById("clave_ver");
  const ojo = document.getElementById("clave_ojo");
  input.focus();

  /* Ojito: alterna entre ver y ocultar la contraseña. */
  btnVer.addEventListener("click", () => {
    const oculta = input.type === "password";
    input.type = oculta ? "text" : "password";
    ojo.className = oculta ? "fa-solid fa-eye-slash" : "fa-solid fa-eye";
    const etiqueta = oculta ? t.ocultar : t.mostrar;
    btnVer.setAttribute("aria-label", etiqueta);
    btnVer.setAttribute("title", etiqueta);
    btnVer.style.color = oculta ? "#00A499" : "#8C969D";
    /* Devuelve el cursor al final del texto para seguir escribiendo. */
    input.focus();
    const n = input.value.length;
    try { input.setSelectionRange(n, n); } catch (e) {}
  });

  function verificar() {
    const valor = input.value;
    if (!valor) return;
    if (sha256Hex(valor) === CLAVE_HASH) {
      CLAVE_OK = true;
      cerrarModalClave();
      alDesbloquear();
    } else {
      err.textContent = t.error;
      err.style.display = "block";
      input.value = "";
      input.focus();
    }
  }

  document.getElementById("clave_ok").onclick = verificar;
  document.getElementById("clave_no").onclick = cerrarModalClave;
  input.addEventListener("keydown", e => {
    if (e.key === "Enter") verificar();
    if (e.key === "Escape") cerrarModalClave();
  });
  wrap.addEventListener("click", e => { if (e.target === wrap) cerrarModalClave(); });
}
