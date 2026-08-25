# =============================================================================
# config.R : parametros del pipeline. Editar SOLO este archivo.
# Pipeline de progresion textual por libro y por nivel escolar.
# =============================================================================

config <- list(

  version_pipeline = "2026-08-19-b",

  # --- RUTAS -----------------------------------------------------------------
  # Catalogo real (hoja Libros de Principal_guia.xlsx). Los textos van en
  # datos/textos con nombre parecido al titulo; el emparejamiento es por
  # titulo normalizado y queda auditable en output/tablas/mapeo_archivos.csv.
  # Para el smoke test sintetico: ruta_xlsx = "demo/catalogo_demo.xlsx",
  # carpeta_textos = "demo/textos", col_titulo = "Titulo",
  # col_archivo = "Archivo", col_nivel = "Curso", filtros vacios list().
  # Carpeta de Drive con los textos. Bajarlos una vez con:
  #   Rscript R/descarga_drive.R
  drive_url = "https://drive.google.com/drive/folders/1d2KgpXucOBDLyaYifzUtgq1R4p055QC-?usp=sharing",

  ruta_xlsx      = "demo/catalogo_demo.xlsx",
  hoja_xlsx      = NA,
  carpeta_textos = "demo/textos",
  carpeta_salida = "output",

  # --- MAPEO DE COLUMNAS DEL XLSX -------------------------------------------
  # Nombres exactos de las columnas. col_archivo = NA: se empareja por titulo.
  col_titulo  = "Titulo",
  col_archivo = "Archivo",
  col_nivel   = "Curso",
  col_autor   = NA,     # para el emparejador por contenido
  col_numero  = NA,       # los archivos del Drive van prefijados con este
                             # numero ("0639_Titulo.pdf"): match deterministico
  solo_numero_si_existe = TRUE,  # obra con numero y sin archivo para ese
                             # numero se excluye (no conseguida); evita que el
                             # fallback por titulo pesque un libro parecido

  # --- EMPAREJADOR POR CONTENIDO (R/emparejar_contenido.R) -------------------
  umbral_auto     = 70,      # puntaje minimo para asignar automatico
  margen_auto     = 15,      # ventaja minima sobre el segundo candidato
  n_chars_inicio  = 2500,    # cuanto texto inicial se usa para reconocer    # acepta "5 basico", "3 o 4 medio", listas con coma

  # --- FILTROS DEL CATALOGO ---------------------------------------------------
  # filtros_mantener: conserva solo las filas con esos valores exactos.
  # filtros_excluir_regex: bota filas cuya columna calza el regex; los NA se
  # CONSERVAN (en el catalogo real Genero viene vacio en la mitad de las
  # filas, sobre todo 5 a 8 basico y media, y esos NA son mayormente novelas).
  # Todo lo filtrado queda contado en el log.
  filtros_mantener = list(),
  filtros_excluir_regex = list(),
  expandir_multicurso = TRUE,  # "7 basico, 2 medio" entra en ambos niveles

  # --- INGESTA Y VALIDACION --------------------------------------------------
  detener_si_faltan = FALSE,   # TRUE: aborta si falta un archivo del catalogo.
                               # FALSE: excluye con justificacion en el log.
  min_palabras      = 300,     # bajo esto el libro se marca en advertencias
  umbral_espanol    = 0.15,    # proporcion minima de stopwords ES esperada
  excluir_no_espanol = TRUE,   # bajo el umbral se excluye con motivo en el log
                               # (capa de texto corrupta o libro en otro idioma)

  # --- LECTURA DE PDF --------------------------------------------------------
  # Si pdftools no compila, el pipeline usa el binario pdftotext. Se busca en
  # PATH y rutas tipicas de usuario; si vive en otra parte, apuntarla aca:
  ruta_pdftotext = NA,       # ej: "~/.local/poppler/bin/pdftotext"

  # --- ANOTACION UDPIPE ------------------------------------------------------
  ruta_modelo = "models",      # carpeta donde se guarda spanish-gsd-ud-2.5
  ncores      = 1,             # subir en el servidor (ej. 4 u 8)
  usar_cache  = TRUE,          # reutiliza anotaciones ya calculadas

  # --- METRICAS --------------------------------------------------------------
  ventanas_mattr   = c(50, 100),
  hdd_muestra      = 42,
  min_oraciones_arco = 30,     # minimo de oraciones para el arco emocional
  incluir_propn    = FALSE,    # PROPN en tfidf y chi2 de terminos (nombres
                               # propios dominan clusters; ver README)

  # --- LEXICO ----------------------------------------------------------------
  n_terminos_chi2 = 500,       # lemas mas frecuentes para chi2 termino x nivel
  keyness_min_frec = 10,
  min_df = 3,                  # lema presente en al menos N libros para tfidf

  # --- SEMANTICA Y CLUSTERING ------------------------------------------------
  lsa_dim        = 150,
  pvclust_nboot  = 200,        # DEMO. Para la version final usar 1000
  run_pvclust_lexico = FALSE,  # bootstrap tambien sobre el espacio tfidf (lento)
  mantel_perm    = 999,
  umap_vecinos   = 15,
  semilla        = 20260810,

  # --- TOPICOS (STM) ---------------------------------------------------------
  run_topicos    = TRUE,
  chunk_palabras = 300,        # tamano de pasaje, como el paper original
  stm_K          = 25,         # numero de topicos; evaluar 20 a 40 en el real
  stm_min_docs   = 5,          # lema presente en al menos N pasajes
  stm_max_iter   = 75,

  # --- ESTADISTICA POR NIVEL -------------------------------------------------
  jt_perm  = 2000,             # permutaciones Jonckheere-Terpstra
  gam_k    = 6,
  metricas_kw = c("ari", "rix", "flesch_kincaid", "fernandez_huerta",
                  "szigriszt_pazos", "perfil_mu", "mattr_100", "mattr_50",
                  "mtld", "hdd", "yule_k", "entropia_shannon", "hapax_ratio",
                  "maas", "long_oracion_media", "dist_dependencia_media",
                  "profundidad_arbol_media", "subordinadas_por_oracion",
                  "razon_sust_verbo", "nominalizaciones_x1000",
                  "polaridad_media", "prop_alegria", "prop_tristeza",
                  "prop_miedo"),

  # --- MODELO DE DESAJUSTADOS ------------------------------------------------
  # sin fernandez_huerta: colineal con szigriszt_pazos y rompe el predict
  features_modelo = c("ari", "rix", "szigriszt_pazos",
                      "mattr_100", "mtld", "yule_k", "entropia_shannon",
                      "long_oracion_media", "dist_dependencia_media",
                      "subordinadas_por_oracion", "polaridad_media",
                      "prop_alegria", "prop_tristeza"),
  umbral_z_robusto = 2.5,
  umbral_delta_nivel = 2
)
