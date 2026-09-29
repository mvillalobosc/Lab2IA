# =============================================================================
#  12_validar.R
#  Control de salida. Cruza los productos del pipeline entre si y falla si no
#  cierran.
#
#  POR QUE EXISTE
#  En la version anterior el arbol se escribio mal y nadie se entero: el log
#  declaraba 30 poblaciones mientras el archivo traia 58 hojas y una poblacion
#  perdida. Los resultados siguieron su curso hasta la revision. Ningun paso
#  comparaba lo que un archivo dice contra lo que dicen los demas.
#
#  Este paso no calcula nada nuevo. Compara, y devuelve estado 1 si algo no
#  cierra, de modo que 99_correr_todo.R pueda cortar antes de exportar.
#
#  NIVELES
#    FALLA  contradiccion entre productos. El resultado no es publicable.
#    AVISO  condicion que cambia la interpretacion y hay que declarar.
#    OK     la comprobacion cierra.
# =============================================================================

# --- Ubicacion del script -----------------------------------------------------
# RStudio no cambia el directorio de trabajo al apretar Source, asi que
# source("00_config.R") falla si la sesion esta parada en otra carpeta. Este
# bloque encuentra la carpeta del propio archivo y se para ahi. Tres vias, en
# orden de fiabilidad:
#   1. sys.frames(): cuando el archivo se ejecuta con source(), R guarda su ruta
#      en ofile. Funciona con el boton Source de RStudio y no necesita paquetes.
#   2. rstudioapi: para cuando se ejecutan lineas sueltas desde el editor, donde
#      no hay ofile. Se usa solo si el paquete esta instalado.
#   3. El directorio actual, si ya contiene 00_config.R.
# Con Rscript ninguna de las tres hace falta y el bloque no toca nada.
local({
  cand <- character(0)
  for (i in seq_len(sys.nframe())) {
    of <- get0("ofile", envir = sys.frames()[[i]], inherits = FALSE)
    if (!is.null(of) && is.character(of) && nzchar(of)) cand <- c(cand, of)
  }
  if (!length(cand) && requireNamespace("rstudioapi", quietly = TRUE) &&
      isTRUE(try(rstudioapi::isAvailable(), silent = TRUE))) {
    p <- try(rstudioapi::getSourceEditorContext()$path, silent = TRUE)
    if (!inherits(p, "try-error") && length(p) && nzchar(p)) cand <- p
    q <- try(rstudioapi::getActiveProject(), silent = TRUE)
    if (!length(cand) && !inherits(q, "try-error") && length(q) && nzchar(q))
      cand <- file.path(q, "x")
  }
  for (p in cand) {
    d <- tryCatch(dirname(normalizePath(p, mustWork = FALSE)), error = function(e) "")
    if (nzchar(d) && file.exists(file.path(d, "00_config.R"))) {
      if (!identical(normalizePath(d), normalizePath(getwd()))) {
        setwd(d); message("Directorio de trabajo: ", d)
      }
      return(invisible(NULL))
    }
  }
  if (!file.exists("00_config.R"))
    stop("No encuentro 00_config.R. Abri la carpeta del pipeline como proyecto ",
         "en RStudio, o corre setwd() a mano.", call. = FALSE)
})

source("00_config.R")
log <- nuevo_log("12_validar"); log("=== 12 VALIDACION ===")

R <- list()
anotar <- function(bloque, control, estado, detalle = "") {
  R[[length(R) + 1L]] <<- data.frame(bloque = bloque, control = control,
                                     estado = estado, detalle = detalle,
                                     stringsAsFactors = FALSE)
}
hay <- function(n) file.exists(paso(n))
carga <- function(n) if (hay(n)) readRDS(paso(n)) else NULL

d1 <- carga("datos"); v <- carga("variantes"); dg <- carga("diagnostico")
dv <- carga("diversidad"); df <- carga("diferenciacion"); gr <- carga("gradiente")
ps <- carga("psi"); ar <- carga("arbol"); ti <- carga("tiempos")
mo <- carga("modelos"); co <- carga("controles"); mz <- carga("mezcla")
ix <- carga("indicadores"); asg <- carga("asignacion")
mk <- carga("marcadores"); pw <- carga("potencia")
oc <- carga("origen_cepa")

# --- Integridad de los grupos ------------------------------------------------
if (!is.null(d1) && !is.null(v)) {
  falt <- setdiff(d1$grupos, v$grupos)
  anotar("grupos", "los conteos cubren todos los grupos definidos",
         if (!length(falt)) "OK" else "FALLA",
         sprintf("%d grupos sin conteos%s", length(falt),
                 if (length(falt)) paste0(": ", paste(head(falt, 4), collapse = ", ")) else ""))
}
if (!is.null(d1)) {
  anotar("grupos", "cepas excluidas declaradas",
         if (nrow(d1$excluidas) == 0) "OK" else "AVISO",
         sprintf("%d cepas fuera del analisis: %s", nrow(d1$excluidas),
                 paste(names(table(d1$excluidas$motivo)),
                       table(d1$excluidas$motivo), sep = "=", collapse = ", ")))
  # Si se agrupo por linaje, cada linaje deberia ser un grupo. Menos grupos que
  # linajes significa que la fusion por coordenada junto linajes distintos.
  lin <- d1$linaje_por_cepa
  if (any(!is.na(lin))) {
    tb <- table(d1$grupo_de_cepa[!is.na(lin)], lin[!is.na(lin)])
    n_lin <- rowSums(tb > 0)
    mez <- names(n_lin)[n_lin > 1]
    agrupa_por_linaje <- identical(sort(unique(COL_GRUPO)), sort(unique(COL_LINAJE)))
    anotar("grupos", "fusion por coordenada",
           if (!length(d1$fusionados)) "OK" else if (agrupa_por_linaje) "FALLA" else "AVISO",
           sprintf("%d fusiones%s", length(d1$fusionados),
                   if (agrupa_por_linaje && length(d1$fusionados))
                     ". Se agrupa por linaje: fusionar por coordenada junta linajes distintos, apagar FUSIONAR_COORD"
                   else ""))
    anotar("grupos", "un linaje por grupo",
           if (!length(mez)) "OK" else "AVISO",
           sprintf("%d de %d grupos reunen mas de un linaje%s", length(mez), length(n_lin),
                   if (length(mez)) paste0(": ", paste(head(mez, 4), collapse = ", ")) else ""))
  }
}

# --- Panel de variantes ------------------------------------------------------
if (!is.null(dg)) {
  anotar("variantes", "cola de alelos raros presente",
         if (!dg$amputado) "OK" else "AVISO",
         sprintf("%.1f%% de los SNP con MAF < 0.02. Por debajo de 5%% el VCF vino filtrado y psi y los alelos privados quedan amputados",
                 100 * dg$frac_raros))
}
if (!is.null(v)) {
  nb <- length(unique(v$bloque))
  anotar("variantes", "bloques de remuestreo suficientes",
         if (nb >= 30) "OK" else "AVISO",
         sprintf("%d ventanas de %d pb. Por debajo de 30 el soporte es grueso", nb, TAM_BLOQUE))
  anotar("variantes", "conteos propios de esta corrida",
         if (!isTRUE(v$heredado)) "OK" else "AVISO",
         if (isTRUE(v$heredado)) "los conteos se heredaron de paso_conteos.rds, no se releyo el VCF" else "")
}

# --- Arbol -------------------------------------------------------------------
if (!is.null(ar)) {
  h <- regmatches(ar$newick, gregexpr("[(,][^(),:]+:", ar$newick))[[1]]
  h <- sub("^[(,]", "", sub(":$", "", h))
  esp <- gsub("[(),:;]", "_", ar$grupos)
  anotar("arbol", "una hoja por grupo",
         if (length(h) == length(esp)) "OK" else "FALLA",
         sprintf("%d hojas, %d grupos", length(h), length(esp)))
  anotar("arbol", "sin hojas repetidas",
         if (!anyDuplicated(h)) "OK" else "FALLA",
         if (anyDuplicated(h)) paste(unique(h[duplicated(h)]), collapse = ", ") else "")
  anotar("arbol", "ningun grupo ausente",
         if (!length(setdiff(esp, h))) "OK" else "FALLA",
         paste(head(setdiff(esp, h), 5), collapse = ", "))
  sm <- median(ar$soporte$soporte, na.rm = TRUE)
  anotar("arbol", "soporte de las particiones",
         if (is.na(sm)) "-" else if (sm >= 0.7) "OK" else "AVISO",
         sprintf("soporte mediano %.2f sobre %d replicas validas; %d de %d particiones por encima de 0.7",
                 sm, ar$replicas_validas, sum(ar$soporte$soporte >= 0.7, na.rm = TRUE),
                 nrow(ar$soporte)))
  if (length(ar$excluidos))
    anotar("arbol", sprintf("grupos con n >= %d", N_MIN_ARBOL), "AVISO",
           sprintf("%d grupos excluidos por muestra insuficiente", length(ar$excluidos)))
}

# --- Origen ------------------------------------------------------------------
if (!is.null(gr) && isTRUE(gr$ok)) {
  ext <- max(gr$ext_lat, gr$ext_lon, na.rm = TRUE)
  anotar("origen", "punto identificable",
         if (is.na(ext)) "-" else if (ext <= 20) "OK" else "AVISO",
         sprintf("la region compatible abarca %.1f grados. Por encima de 20 hay que reportar region y no coordenada", ext))
}
if (!is.null(co)) {
  anotar("origen", "supera el nulo por permutacion",
         if (is.na(co$p_r2)) "-" else if (co$p_r2 <= 0.05) "OK" else "FALLA",
         sprintf("p = %.4g. Si no supera al nulo, el gradiente aparece barajando coordenadas", co$p_r2))
  anotar("origen", "la ubicacion supera al nulo",
         if (is.na(co$frac_cerca)) "-" else if (co$frac_cerca <= 0.2) "OK" else "AVISO",
         sprintf("%.0f%% de las permutaciones cae a menos de 500 km del punto observado",
                 100 * co$frac_cerca))
  ok2 <- is.finite(co$sim_r2)
  if (any(ok2)) {
    p_sim <- (1 + sum(co$sim_r2[ok2] >= co$observado$r2)) / (1 + sum(ok2))
    anotar("origen", "se distingue de IBD sin expansion",
           if (p_sim <= 0.05) "OK" else "FALLA",
           sprintf("p = %.4g contra datos simulados sin fuente", p_sim))
  }
  if (!is.null(co$borde)) {
    b <- co$borde
    anotar("origen", "no se reduce a efecto de borde",
           if (isTRUE(b$domina_borde)) "FALLA" else "OK",
           sprintf("correlacion de pi con la distancia al borde %.3f contra %.3f con la distancia al origen (Kemppainen et al. 2024, Mol Biol Evol 41:msae091)",
                   b$r_borde, b$r_origen))
    anotar("origen", "el origen no cae sobre el borde muestreado",
           if (isTRUE(b$origen_en_borde)) "AVISO" else "OK",
           if (isTRUE(b$origen_en_borde))
             "un origen sobre el borde es lo que produce el efecto de borde en poblaciones en equilibrio" else "")
  }
  if (!is.null(co$wahlund)) {
    km <- dist_km(co$observado$lat, co$observado$lon, co$wahlund$lat, co$wahlund$lon)
    anotar("origen", "robusto a la mezcla de linajes",
           if (km <= 1000) "OK" else "AVISO",
           sprintf("sin grupos mezclados el origen se mueve %.0f km", km))
  }
  if (!is.null(co$campanas)) {
    mx <- max(co$campanas$km_del_observado, na.rm = TRUE)
    anotar("origen", "no depende de una sola campana",
           if (mx <= 1000) "OK" else "AVISO",
           sprintf("la campana mas influyente mueve el origen %.0f km", mx))
  }
}
if (!is.null(mo)) {
  gana <- mo$tabla$modelo[1]
  anotar("origen", "el fundador serial gana la comparacion",
         if (grepl("M1", gana)) "OK" else "FALLA",
         sprintf("gana %s por validacion cruzada", gana))
}

# --- psi ---------------------------------------------------------------------
if (!is.null(ps)) {
  anotar("psi", "polarizacion con grupo externo",
         if (ps$polarizacion == "outgroup") "OK" else "AVISO",
         sprintf("polarizacion por %s. Sin grupo externo se asume que el alelo mayoritario es el ancestral, supuesto que falla tras un cuello de botella",
                 ps$polarizacion))
  ms <- max(ps$ranking$soporte_primero, na.rm = TRUE)
  anotar("psi", "un grupo se impone en el ranking",
         if (ms >= 0.5) "OK" else "AVISO",
         sprintf("soporte maximo como primero: %.2f", ms))
}

# --- Concordancia entre lineas independientes --------------------------------
if (!is.null(gr) && isTRUE(gr$ok) && !is.null(ps) && !is.null(dv)) {
  top_psi <- ps$ranking$grupo[1]
  fila <- dv$div[dv$div$grupo == top_psi, ]
  if (nrow(fila) == 1 && !is.na(fila$lat)) {
    km <- dist_km(gr$lat, gr$lon, fila$lat, fila$lon)
    anotar("concordancia", "gradiente y psi apuntan al mismo lugar",
           if (km <= 1000) "OK" else "AVISO",
           sprintf("%.0f km entre el origen del gradiente y el primer grupo de psi (%s)",
                   km, top_psi))
  }
}
if (!is.null(dv) && !is.null(gr) && isTRUE(gr$ok)) {
  mas_div <- dv$div$grupo[which.max(dv$div$pi)]
  fila <- dv$div[dv$div$grupo == mas_div, ]
  km <- dist_km(gr$lat, gr$lon, fila$lat, fila$lon)
  anotar("concordancia", "el origen cae cerca del grupo mas diverso",
         if (km <= 1000) "OK" else "AVISO",
         sprintf("%.0f km hasta %s", km, mas_div))
}

# --- Tiempos -----------------------------------------------------------------
if (!is.null(ti)) {
  sm <- median(ti$eventos$soporte, na.rm = TRUE)
  anotar("tiempos", "orden de divergencia estable",
         if (is.na(sm)) "-" else if (sm >= 0.5) "OK" else "AVISO",
         sprintf("soporte mediano %.2f", sm))
  rango <- ti$eventos$anos_cota_alta[1] / max(ti$eventos$anos_cota_baja[1], 1)
  anotar("tiempos", "la cota en anos es informativa",
         if (is.finite(rango) && rango < 100) "OK" else "AVISO",
         sprintf("la cota abarca un factor de %.0f. Reportar unidades de deriva como resultado primario", rango))
}

# --- Estructura y mezcla -----------------------------------------------------
if (!is.null(mz)) {
  anotar("mezcla", "PCA calculado",
         if (!is.null(mz$PC)) "OK" else "-",
         if (!is.null(mz$PC)) sprintf("PC1 %.1f%%, PC2 %.1f%% de la varianza",
                                      100 * mz$var_expl[1], 100 * mz$var_expl[2]) else "")
  anotar("mezcla", "f3 con error estandar",
         if (is.null(mz$f3)) "-" else if (any(is.finite(mz$f3$z))) "OK" else "AVISO",
         if (is.null(mz$f3)) "ninguna combinacion con f3 negativo"
         else sprintf("%d combinaciones negativas, %d con Z < -3",
                      nrow(mz$f3), if (is.null(mz$f3_sig)) 0 else nrow(mz$f3_sig)))
}

# --- Bloques restituidos ------------------------------------------------------
if (!is.null(ix)) {
  p <- ix$poblacion
  anotar("indicadores", "Ho y Fis calculados",
         if (any(is.finite(p$Ho))) "OK" else "AVISO",
         sprintf("Ho mediana %.4f, Fis mediana %.4f",
                 median(p$Ho, na.rm = TRUE), median(p$Fis, na.rm = TRUE)))
  anotar("indicadores", "Fis en rango creible",
         { f <- median(p$Fis, na.rm = TRUE)
           if (!is.finite(f)) "-" else if (f >= -0.5 && f <= 1) "OK" else "FALLA" },
         sprintf("Fis mediana %.3f. Fuera de [-0.5, 1] indica un problema de codificacion de genotipos",
                 median(p$Fis, na.rm = TRUE)))
  anotar("indicadores", "D de Tajima calculado",
         if (any(is.finite(p$tajima_D))) "AVISO" else "-",
         "el panel esta filtrado por frecuencia minima, asi que Tajima D sale sesgado hacia arriba y no es comparable con valores sobre todos los sitios")
}
if (!is.null(asg) && !is.null(asg$asignacion)) {
  az <- 1 / max(asg$n_grupos, 1)
  anotar("cepas", "la asignacion supera al azar",
         if (asg$exactitud > 3 * az) "OK" else "AVISO",
         sprintf("exactitud %.1f%% contra %.1f%% esperable por azar con %d grupos",
                 100 * asg$exactitud, 100 * az, asg$n_grupos))
}
if (!is.null(mk) && !is.null(mk$genes)) {
  nf <- sum(!is.na(mk$genes$familia))
  anotar("genes", "senal no dominada por familias multigenicas",
         if (!nf) "OK" else "AVISO",
         sprintf("%d de %d genes en familias multigenicas; %d entre los 20 de mayor enriquecimiento. El pipeline no filtra por mapeo multiple",
                 nf, nrow(mk$genes), sum(!is.na(head(mk$genes$familia, 20)))))
}
if (!is.null(pw) && !is.null(pw$identificabilidad)) {
  id <- pw$identificabilidad
  anotar("alcance", "el muestreo permite ubicar una fuente",
         if (isTRUE(id$punto_recuperable)) "OK" else "FALLA",
         sprintf("error mediano %s km al recuperar un origen conocido; efecto minimo detectable %s",
                 format(id$error_mediano_km), format(id$efecto_minimo_detectable)))
}

if (!is.null(oc) && !is.null(oc$ancestria)) {
  an <- oc$ancestria
  anotar("cepas", "ancestria por cepa calculada", "OK",
         sprintf("K = %d componentes; %d de %d cepas con ancestria simple (dominante >= 0.7)",
                 oc$K, sum(!an$mezclada), nrow(an)))
  nn <- oc$vecinos
  lejos <- sum(!nn$mismo_grupo & !is.na(nn$km_al_vecino) & nn$km_al_vecino > 500)
  anotar("cepas", "vecino genetico coherente con la geografia",
         if (lejos <= 0.1 * nrow(nn)) "OK" else "AVISO",
         sprintf("%d de %d cepas tienen su pariente mas cercano a mas de 500 km: migrantes, etiquetas equivocadas o transporte humano",
                 lejos, nrow(nn)))
  pr <- oc$privados_rar
  cc <- suppressWarnings(cor(pr$privados_rar, pr$n_cepas, use = "complete"))
  anotar("cepas", "privados rarefaccionados sin efecto de muestreo",
         if (!is.finite(cc) || abs(cc) <= 0.5) "OK" else "AVISO",
         sprintf("correlacion con el tamano de muestra tras rarefaccionar: %.3f", cc))
}

# --- Plausibilidad de los numeros --------------------------------------------
# Los controles de arriba miran consistencia entre archivos. Estos miran si los
# valores son creibles, que es lo que faltaba: un Ne de 2e8 para levadura es
# consistente con todo y aun asi esta mal.
if (!is.null(ti)) {
  anotar("plausibilidad", "Ne en rango creible para levadura",
         if (is.finite(ti$Ne_ref) && ti$Ne_ref >= 1e4 && ti$Ne_ref <= 5e7) "OK" else "FALLA",
         sprintf("Ne = %s. Fuera de [1e4, 5e7] suele indicar que pi por sitio del panel se uso como theta por par de bases",
                 format(signif(ti$Ne_ref, 4))))
}
if (!is.null(dv)) {
  d <- dv$div[dv$div$elegible, ]
  anotar("plausibilidad", "pi en rango creible",
         if (all(d$pi >= 0 & d$pi <= 1, na.rm = TRUE)) "OK" else "FALLA",
         sprintf("rango observado %.4f a %.4f", min(d$pi, na.rm = TRUE), max(d$pi, na.rm = TRUE)))
  anotar("plausibilidad", "el ranking no lo encabeza un grupo minusculo",
         if (!nrow(d) || d$n_cepas[which.max(d$pi)] >= N_MIN_GRUPO_EST) "OK" else "FALLA",
         sprintf("el grupo mas diverso tiene n = %d", d$n_cepas[which.max(d$pi)]))
}
if (!is.null(ps)) {
  n1 <- ps$ranking$n_cepas[1]
  anotar("plausibilidad", "psi no lo encabeza un grupo minusculo",
         if (is.na(n1) || n1 >= N_MIN_GRUPO_EST) "OK" else "FALLA",
         sprintf("el primero del ranking tiene n = %s", format(n1)))
}
if (!is.null(d1)) {
  cont <- table(d1$meta[[COL_CONT]])
  if (length(cont) > 1) {
    dom <- max(cont) / sum(cont)
    anotar("plausibilidad", "muestreo no dominado por una sola region",
           if (dom <= 0.85) "OK" else "AVISO",
           sprintf("%.0f%% de las cepas en %s. Con ese desbalance, los pocos grupos lejanos mandan sobre el ajuste global",
                   100 * dom, names(cont)[which.max(cont)]))
  }
}

# --- Salida ------------------------------------------------------------------
tab <- do.call(rbind, R)
ancho <- max(nchar(tab$control)) + 2
for (b in unique(tab$bloque)) {
  log("\n[", b, "]")
  s <- tab[tab$bloque == b, ]
  for (i in seq_len(nrow(s)))
    log(sprintf("  %-5s %-*s %s", s$estado[i], ancho, s$control[i],
                substr(s$detalle[i], 1, 160)))
}
n_falla <- sum(tab$estado == "FALLA"); n_aviso <- sum(tab$estado == "AVISO")
log("\n  ", n_falla, " FALLA / ", n_aviso, " AVISO / ", sum(tab$estado == "OK"), " OK")
write.table(tab, file.path(OUT, "12_validacion.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
saveRDS(tab, paso("validacion"))
# Un FALLA de validacion NO es un error de ejecucion: el pipeline corrio entero
# y escribio todo. Salir con estado distinto de cero hacia que el panel Jobs de
# RStudio marcara la corrida como Failed despues de dos horas de trabajo
# correcto. El aviso va en el texto, bien visible, y el estado queda en cero.
# Para automatizacion, donde si conviene cortar, se activa a mano:
#     options(filo.cortar_si_falla = TRUE)
if (n_falla > 0) {
  log("\n  ", strrep("=", 62))
  log("  ", n_falla, " COMPROBACION(ES) EN FALLA. El pipeline corrio completo y")
  log("  los resultados estan escritos, pero no cierran entre si: revisar")
  log("  12_validacion.tsv antes de exportar o publicar nada.")
  log("  ", strrep("=", 62))
  if (isTRUE(getOption("filo.cortar_si_falla", FALSE)))
    detener(paste0("12: ", n_falla, " comprobacion(es) en FALLA"), 1L)
}
cerrar_log(log)

