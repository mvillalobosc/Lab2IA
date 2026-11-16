# =============================================================================
# R/funciones_shap.R
# Valores SHAP del modelo ganador, su tabla resumen y su figura.
# =============================================================================

# -----------------------------------------------------------------------------
# Valores SHAP del modelo ganador con fastshap (aproximación Monte Carlo por
# permutaciones, CFG$shap_nsim repeticiones por variable).
# Se calculan sobre todas las filas originales, sin las copias del
# sobremuestreo, para describir a todos los encuestados; el modelo que se
# explica es el final, ajustado con la muestra completa balanceada.
#   datos: versión one-hot de la muestra (la de RL si ganó RL, la de RF y XGB
#          en otro caso; solo cambia el orden de niveles de la enfermedad).
# Devuelve las predictoras (X_shap), la matriz de valores SHAP como data.frame
# (valores) y la tabla resumen (tabla).
# -----------------------------------------------------------------------------
explicar_ganador <- function(ganador, modelo, datos, enfermedad) {
  set.seed(CFG$semilla_shap)

  X_shap <- datos %>% select(-all_of(enfermedad))
  pred_fun <- switch(
    ganador,
    RL  = function(object, newdata) predict(object, newdata = newdata, type = "response"),
    RF  = function(object, newdata) predict(object, newdata = newdata, type = "prob")[, "SI"],
    XGB = function(object, newdata) predict(object, newdata = as.matrix(newdata))
  )

  shap_obj <- fastshap::explain(modelo, X = X_shap, pred_wrapper = pred_fun,
                                nsim = CFG$shap_nsim)
  sv <- shapviz(shap_obj, X = X_shap)

  list(X_shap = X_shap, valores = as.data.frame(sv$S), tabla = tabla_shap(sv))
}

# -----------------------------------------------------------------------------
# Tabla SHAP de las CFG$shap_top_n variables más importantes.
#   Importancia        media del valor absoluto de SHAP
#   SHAP_si_presente   SHAP medio de los encuestados con la característica
#                      (variable = 1). Positivo: acerca al diagnóstico SI;
#                      negativo: lo aleja
#   SHAP_si_ausente    SHAP medio de los encuestados sin la característica
#   N_presente         encuestados con la característica; con pocos, el SHAP
#                      medio es poco estable
# -----------------------------------------------------------------------------
tabla_shap <- function(sv) {
  shap_long <- as.data.frame(sv$S) %>%
    mutate(id = row_number()) %>%
    pivot_longer(-id, names_to = "var", values_to = "shap") %>%
    left_join(
      as.data.frame(sv$X) %>%
        mutate(id = row_number()) %>%
        pivot_longer(-id, names_to = "var", values_to = "valor"),
      by = c("id", "var")
    )

  shap_long %>%
    group_by(var) %>%
    summarise(
      Importancia      = round(mean(abs(shap), na.rm = TRUE), 4),
      SHAP_si_presente = round(mean(shap[valor == 1], na.rm = TRUE), 4),
      SHAP_si_ausente  = round(mean(shap[valor == 0], na.rm = TRUE), 4),
      N_presente       = sum(valor == 1, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(Importancia)) %>%
    slice_head(n = CFG$shap_top_n) %>%
    rename(Variable = var)
}

# -----------------------------------------------------------------------------
# Figura SHAP para publicación: una barra por variable con el SHAP medio de
# quienes tienen la característica, ordenadas por importancia. Etiquetas en
# inglés y colores pastel. Las variables que ningún encuestado presenta
# (SHAP_si_presente = NA) no tienen barra que dibujar y quedan fuera.
#   etiquetas: vector con nombre opcional (nombre = variable, valor = texto
#              para el eje); las variables sin etiqueta muestran su código.
# -----------------------------------------------------------------------------
grafico_shap <- function(shap_tabla, titulo, etiquetas = NULL) {
  df_plot <- shap_tabla %>%
    filter(!is.na(SHAP_si_presente)) %>%
    mutate(Direccion = ifelse(SHAP_si_presente >= 0,
                              "Towards presence", "Towards absence"),
           Etiqueta  = Variable)

  if (!is.null(etiquetas)) {
    con_etiqueta <- df_plot$Variable %in% names(etiquetas)
    df_plot$Etiqueta[con_etiqueta] <- etiquetas[df_plot$Variable[con_etiqueta]]
  }
  df_plot$Etiqueta <- fct_reorder(make.unique(df_plot$Etiqueta), df_plot$Importancia)

  ggplot(df_plot, aes(x = SHAP_si_presente, y = Etiqueta, fill = Direccion)) +
    geom_col(width = 0.72, colour = "grey40", linewidth = 0.25) +
    geom_vline(xintercept = 0, linewidth = 0.3, colour = "grey25") +
    geom_text(aes(label = sprintf("%.3f", SHAP_si_presente),
                  hjust = ifelse(SHAP_si_presente >= 0, -0.15, 1.15)),
              size = 3, colour = "grey20") +
    scale_fill_manual(values = c("Towards presence" = "#F4A9A0",
                                 "Towards absence"  = "#A9C9E8"),
                      breaks = c("Towards presence", "Towards absence"),
                      labels = c("Towards presence of the disease",
                                 "Towards absence of the disease"),
                      name = NULL) +
    scale_x_continuous(expand = expansion(mult = 0.14)) +
    labs(x = "Mean SHAP value when the characteristic is present",
         y = NULL, title = titulo) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major.y  = element_blank(),
          panel.grid.minor    = element_blank(),
          axis.text.y         = element_text(colour = "grey15"),
          legend.position     = "bottom",
          legend.justification = "center",
          plot.title          = element_text(face = "bold", size = 12),
          plot.title.position = "plot")
}
