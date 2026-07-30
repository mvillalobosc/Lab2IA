# =============================================================================
# R/09_tables_and_figures.R
#
# STEP 9 - Manuscript tables and figures, rebuilt from the raw outputs.
#
# Input : results/selection/metrics_<scenario>.csv       (step 7)
#         results/final_model/<scenario>_shap_values.csv (step 8)
#         results/tables/shap_summary_<scenario>.csv     (step 8)
#         data/processed/discharges.parquet              (step 3)
#         data/processed/municipal_indicators.parquet    (step 4, optional)
#         data/external/feature_labels.csv               (optional, cosmetic)
# Output: results/tables/hypervolume.csv
#         results/tables/table1_model_comparison.csv     and .tex
#         results/tables/tableS1_all_models.csv          and .tex
#         results/tables/table2_municipal_indicators.csv and .tex
#         results/tables/tableS2_S4_municipal_profiles.csv
#         results/figures/figure_shap_<scenario>.pdf
#         results/figures/figure3_episodes_by_municipality.pdf
#         results/figures/figureS1_S3_subtype_<municipality>.pdf
#
# Why this script exists
#   Every number in Table 1 and Table S1 is recomputed here from the per-replicate
#   metric files, the hypervolume is recomputed from the same files, and every
#   figure is drawn from the processed parquet or from the SHAP values of step 8.
#   Nothing is transcribed by hand. In the tables of the current manuscript draft
#   the precision column matches the per-replicate output for all nine scenarios
#   while sensitivity, F1 and accuracy match in only four, and several of the
#   mismatching triples reappear verbatim in unrelated rows, which is the
#   signature of a misaligned join made while assembling the tables. Rebuilding
#   them from the source files removes that whole class of error.
# =============================================================================

source("R/utils.R")
source("R/lib_hypervolume.R")
source("R/lib_shap.R")

cfg <- load_config()
require_pkgs("ggplot2", attach = TRUE)

log_start(cfg, "09_tables_and_figures")

con <- db_connect(cfg)
on.exit(db_close(con), add = TRUE)

scen <- scenario_table(cfg)
fig_ext <- cfg$reporting$figure_format %||% "pdf"

METRIC_COLS <- c("precision", "sensitivity", "f1", "accuracy")
MODEL_LABELS <- c(lasso = "RLM", random_forest = "RF", knn = "KNN")


# -----------------------------------------------------------------------------
# Small LaTeX writer
#
# booktabs style, numbers already formatted, no external dependency. Escapes the
# characters that would break a LaTeX compile.
# -----------------------------------------------------------------------------

latex_escape <- function(x) {
  x <- as.character(x)
  # A literal backslash is parked in a placeholder first, otherwise the brace
  # escaping below would mangle the replacement it produces.
  x <- gsub("\\", "<<BSLASH>>", x, fixed = TRUE)
  for (ch in c("&", "%", "$", "#", "_", "{", "}")) {
    x <- gsub(ch, paste0("\\", ch), x, fixed = TRUE)
  }
  gsub("<<BSLASH>>", "\\textbackslash{}", x, fixed = TRUE)
}

write_latex_table <- function(df, path, caption, label, align = NULL, notes = NULL) {
  align <- align %||% paste0("l", strrep("r", ncol(df) - 1L))
  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste0(paste(latex_escape(names(df)), collapse = " & "), " \\\\"),
    "\\midrule"
  )
  for (i in seq_len(nrow(df))) {
    row <- vapply(df[i, ], function(v) {
      if (is.numeric(v)) formatC(v, format = "f", digits = 4) else latex_escape(v)
    }, character(1))
    lines <- c(lines, paste0(paste(row, collapse = " & "), " \\\\"))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}")
  if (!is.null(notes)) {
    lines <- c(lines, paste0("\\begin{flushleft}\\footnotesize ", notes, "\\end{flushleft}"))
  }
  lines <- c(lines, "\\end{table}")

  ensure_dir(dirname(path))
  writeLines(lines, path, useBytes = FALSE)
  invisible(path)
}


# -----------------------------------------------------------------------------
# 9.1  Model comparison tables
# -----------------------------------------------------------------------------

metric_files <- cfg_path(cfg, "selection", paste0("metrics_", scen$name, ".csv"))
available <- file.exists(metric_files)

if (!any(available)) {
  log_warn("No step 7 metric files found; skipping Table 1 and Table S1")
} else {
  if (any(!available)) {
    log_warn("Missing metrics for: ", paste(scen$name[!available], collapse = ", "))
  }

  metrics <- do.call(rbind, lapply(metric_files[available], read_csv_utf8))
  log_info("Loaded ", nrow(metrics), " replicate-model rows from ",
           sum(available), " scenarios")

  # Mean over replicates, plus the count of replicates that produced a usable
  # value for each metric. A metric is NA when the model predicted no positive
  # case in that replicate, so reporting the denominator matters.
  agg <- do.call(rbind, lapply(split(metrics, list(metrics$scenario, metrics$model),
                                     drop = TRUE), function(d) {
    out <- data.frame(
      scenario = d$scenario[1],
      model = d$model[1],
      n_replicates = nrow(d),
      stringsAsFactors = FALSE
    )
    for (mc in c(METRIC_COLS, "auc")) {
      out[[mc]] <- mean(d[[mc]], na.rm = TRUE)
      out[[paste0("n_", mc)]] <- sum(!is.na(d[[mc]]))
    }
    out$seconds_per_replicate <- mean(d$seconds, na.rm = TRUE)
    out$n_features_selected_mean <- mean(d$n_features_selected, na.rm = TRUE)
    out
  }))
  rownames(agg) <- NULL

  # Hypervolume, recomputed here from the same replicate files, so the column can
  # never drift from the metrics it summarises.
  hv <- hypervolume_table(
    metrics,
    objectives = unlist(cfg$hypervolume$objectives),
    ref = as.numeric(cfg$hypervolume$reference_point),
    mode = cfg$hypervolume$mode %||% "mean"
  )
  write_csv_utf8(hv, cfg_path(cfg, "tables", "hypervolume.csv"))
  log_info("Hypervolume (mode '", cfg$hypervolume$mode, "') computed for ",
           nrow(hv), " scenario-model pairs")

  agg$hypervolume <- hv$hypervolume[match(paste(agg$scenario, agg$model),
                                          paste(hv$scenario, hv$model))]

  agg$label <- scen$label[match(agg$scenario, scen$name)]
  agg$model_label <- MODEL_LABELS[agg$model]
  agg$model_label[is.na(agg$model_label)] <- agg$model[is.na(agg$model_label)]

  # Order rows the way the manuscript does.
  agg <- agg[order(match(agg$scenario, scen$name),
                   match(agg$model, names(MODEL_LABELS))), ]

  # --- Table S1: every model ------------------------------------------------
  tS1 <- data.frame(
    Scenario = agg$label,
    Model = agg$model_label,
    Precision = agg$precision,
    Sensitivity = agg$sensitivity,
    F1 = agg$f1,
    Accuracy = agg$accuracy,
    Hypervolume = agg$hypervolume,
    stringsAsFactors = FALSE
  )
  # Print the scenario name only on its first row, as in the manuscript.
  tS1$Scenario[duplicated(tS1$Scenario)] <- ""

  write_csv_utf8(agg, cfg_path(cfg, "tables", "tableS1_all_models.csv"))
  write_latex_table(
    tS1, cfg_path(cfg, "tables", "tableS1_all_models.tex"),
    caption = paste0("Internal comparison of the three feature selection models ",
                     "across the analytical scenarios. Chilean DRG records, 2019--2024."),
    label = "tab:S1",
    notes = paste0("Source: authors' calculations. Values are averaged over ",
                   max(agg$n_replicates), " balanced resampling replicates ",
                   "conducted in the development subset. RLM: Lasso-penalised ",
                   "logistic model; RF: Random Forest; KNN: K nearest neighbours. ",
                   "These metrics were used only to compare feature selection models.")
  )

  # --- Table 1: the model with the largest hypervolume per scenario ----------
  # Ties and missing hypervolume fall back to the largest F1, which is stated in
  # the output so the choice is never silent.
  pick <- do.call(rbind, lapply(split(agg, agg$scenario), function(d) {
    if (all(is.na(d$hypervolume))) {
      d$selection_rule <- "largest mean F1 (hypervolume unavailable)"
      d[which.max(d$f1), ]
    } else {
      d$selection_rule <- "largest hypervolume"
      d[which.max(d$hypervolume), ]
    }
  }))
  pick <- pick[order(match(pick$scenario, scen$name)), ]

  t1 <- data.frame(
    Scenario = pick$label,
    Model = pick$model_label,
    Precision = pick$precision,
    Sensitivity = pick$sensitivity,
    F1 = pick$f1,
    Accuracy = pick$accuracy,
    Hypervolume = pick$hypervolume,
    stringsAsFactors = FALSE
  )

  write_csv_utf8(pick, cfg_path(cfg, "tables", "table1_model_comparison.csv"))
  write_latex_table(
    t1, cfg_path(cfg, "tables", "table1_model_comparison.tex"),
    caption = paste0("Internal comparison metrics for the model selected by ",
                     "hypervolume in each analytical scenario. Chilean DRG records, ",
                     "2019--2024."),
    label = "tab:1",
    notes = paste0("Source: authors' calculations. Metrics were averaged over ",
                   max(pick$n_replicates), " balanced resampling replicates ",
                   "(n = ", 2 * as.integer(cfg$resampling$n_per_class),
                   ") in the development subset and were used only to compare ",
                   "feature selection and models.")
  )

  log_info("Table 1 model per scenario: ",
           paste(sprintf("%s=%s", pick$scenario, pick$model_label), collapse = ", "))
  if (length(unique(pick$model)) == 1L) {
    log_info("The same model wins every scenario (", unique(pick$model_label), ")")
  }
}


# -----------------------------------------------------------------------------
# 9.2  Figure 2 and Supplementary Figures S4 to S11 - SHAP contributions
#
# The values were computed in step 8. Here they are only ranked and drawn.
# -----------------------------------------------------------------------------

# Optional label table, so that PROC_87_03 prints as "Head CT (87.03)".
label_path <- cfg_path(cfg, "external", "feature_labels.csv")
label_table <- NULL
if (file.exists(label_path)) {
  label_table <- read_csv_utf8(label_path)
  if (!all(c("feature", "label") %in% names(label_table))) {
    log_warn(basename(label_path), " ignored: it needs the columns feature and label")
    label_table <- NULL
  } else {
    log_info("Feature labels loaded: ", nrow(label_table), " entries")
  }
} else {
  log_info("No ", basename(label_path), ": raw column names will be shown in the ",
           "SHAP figures")
}

top_n_plot <- as.integer(cfg$consensus$top_n_plot %||% 10L)
n_shap_figures <- 0L

for (i in seq_len(nrow(scen))) {
  outcome <- scen$name[i]
  shap_path <- cfg_path(cfg, "final_model", paste0(outcome, "_shap_values.csv"))
  feat_path <- cfg_path(cfg, "final_model", paste0(outcome, "_shap_features.csv"))
  summ_path <- cfg_path(cfg, "tables", paste0("shap_summary_", outcome, ".csv"))

  if (!all(file.exists(c(shap_path, feat_path, summ_path)))) next

  shap_df <- read_csv_utf8(shap_path)
  feat_df <- read_csv_utf8(feat_path)
  summ <- read_csv_utf8(summ_path)

  # The two files must refer to the same records in the same order.
  if (!identical(shap_df$RECORD_ID, feat_df$RECORD_ID)) {
    ord <- match(shap_df$RECORD_ID, feat_df$RECORD_ID)
    if (anyNA(ord)) {
      log_warn("  ", outcome, ": SHAP and feature files do not share their records; skipped")
      next
    }
    feat_df <- feat_df[ord, , drop = FALSE]
  }

  meta <- c("RECORD_ID", "Y", "base_value", "linear_predictor")
  phi <- as.matrix(shap_df[, setdiff(names(shap_df), meta), drop = FALSE])
  X_shap <- as.matrix(feat_df[, setdiff(names(feat_df), c("RECORD_ID", "Y")), drop = FALSE])

  common <- intersect(colnames(phi), colnames(X_shap))
  if (length(common) == 0L) {
    log_warn("  ", outcome, ": no feature is present in both files; skipped")
    next
  }

  p <- shap_plot(phi[, common, drop = FALSE], X_shap[, common, drop = FALSE],
                 summ[summ$feature %in% common, ], scen$label[i],
                 top_n = top_n_plot, label_table = label_table)
  if (is.null(p)) next

  height <- max(2.8, 0.42 * min(top_n_plot, length(common)) + 1.4)
  out <- cfg_path(cfg, "figures", paste0("figure_shap_", outcome, ".", fig_ext))
  ggsave(out, p, width = 7.4, height = height, dpi = as.integer(cfg$reporting$figure_dpi), bg = "white")
  n_shap_figures <- n_shap_figures + 1L
  log_info("Wrote ", basename(out), " (", min(top_n_plot, length(common)), " features, ",
           nrow(phi), " records)")
}

if (n_shap_figures == 0L) {
  log_warn("No SHAP figures drawn. Run: Rscript R/08_consensus.R")
}


# -----------------------------------------------------------------------------
# 9.3  Figure 3 - episodes by municipality
# -----------------------------------------------------------------------------

discharges_path <- cfg_path(cfg, "processed", "discharges.parquet")
if (!file.exists(discharges_path)) {
  log_warn("Missing ", discharges_path, "; skipping the descriptive figures")
} else {
  top_n_muni <- as.integer(cfg$reporting$top_municipalities_figure %||% 15L)

  by_muni <- db_get(con, sprintf("
    SELECT
      COMUNA_KEY,
      ANY_VALUE(COMUNA)                       AS comuna_display,
      SUM(D1_ACV_GENERAL)                     AS episodes_principal,
      SUM(D1_ACV_ISQUEMICO)                   AS ischaemic,
      SUM(D1_ACV_HEMORRAGICO)                 AS haemorrhagic,
      SUM(D1_ACV_NOESPECIFICADO)              AS unspecified,
      COUNT(*)                                AS discharges_total
    FROM read_parquet('%s')
    WHERE COMUNA_KEY IS NOT NULL AND COMUNA_KEY <> ''
    GROUP BY COMUNA_KEY
    ORDER BY episodes_principal DESC
  ", sql_path(discharges_path)))

  write_csv_utf8(by_muni, cfg_path(cfg, "tables", "episodes_by_municipality.csv"))
  log_info("Municipalities with at least one stroke episode: ",
           sum(by_muni$episodes_principal > 0))

  top <- utils::head(by_muni[order(-by_muni$episodes_principal), ], top_n_muni)
  top$comuna_display <- factor(top$comuna_display,
                               levels = rev(top$comuna_display))

  p3 <- ggplot(top, aes(x = comuna_display, y = episodes_principal)) +
    geom_col(fill = "#2C6E9B", width = 0.75) +
    geom_text(aes(label = format(episodes_principal, big.mark = ",")),
              hjust = -0.12, size = 2.6) +
    coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(
      title = "Hospitalised stroke episodes by municipality of residence",
      x = "Municipality", y = "Number of episodes"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = 11, hjust = 0.5)
    )

  fig3_path <- cfg_path(cfg, "figures", paste0("figure3_episodes_by_municipality.", fig_ext))
  ggsave(fig3_path, p3, width = 7.2, height = 4.6, dpi = as.integer(cfg$reporting$figure_dpi), bg = "white")
  log_info("Wrote ", basename(fig3_path))

  # ---------------------------------------------------------------------------
  # 9.4  Figures S1 to S3 - subtype composition of the focus municipalities
  # ---------------------------------------------------------------------------

  focus <- normalise_place(unlist(cfg$reporting$focus_municipalities))
  for (i in seq_along(focus)) {
    key <- focus[i]
    row <- by_muni[by_muni$COMUNA_KEY == key, ]
    if (nrow(row) == 0L) {
      log_warn("Focus municipality not found in the data: ", key)
      next
    }

    sub <- data.frame(
      subtype = factor(c("Haemorrhagic", "Ischaemic", "Unspecified"),
                       levels = c("Haemorrhagic", "Ischaemic", "Unspecified")),
      episodes = c(row$haemorrhagic[1], row$ischaemic[1], row$unspecified[1])
    )

    p <- ggplot(sub, aes(x = subtype, y = episodes, fill = subtype)) +
      geom_col(width = 0.6, colour = "grey20") +
      geom_text(aes(label = format(episodes, big.mark = ",")),
                vjust = -0.6, size = 3, fontface = "bold") +
      scale_fill_manual(values = c(Haemorrhagic = "#C0504D",
                                   Ischaemic = "#2C6E9B",
                                   Unspecified = "#E8A33D"), guide = "none") +
      scale_y_continuous(expand = expansion(mult = c(0, 0.14))) +
      labs(
        title = paste0("Stroke episodes by subtype: ", row$comuna_display[1]),
        x = NULL, y = "Number of episodes"
      ) +
      theme_minimal(base_size = 10) +
      theme(
        panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 11, hjust = 0.5)
      )

    fname <- sprintf("figureS%d_subtype_%s.%s", i,
                     tolower(gsub(" ", "_", key)), fig_ext)
    out <- cfg_path(cfg, "figures", fname)
    ggsave(out, p, width = 5.4, height = 4.2, dpi = as.integer(cfg$reporting$figure_dpi), bg = "white")
    log_info("Wrote ", basename(out), " (",
             sum(sub$episodes), " episodes: ",
             paste(sprintf("%s %d", sub$subtype, sub$episodes), collapse = ", "), ")")
  }
}


# -----------------------------------------------------------------------------
# 9.5  Table 2 and Supplementary Tables S2 to S4 - municipal indicators
# -----------------------------------------------------------------------------

ind_path <- cfg_path(cfg, "processed", "municipal_indicators.parquet")
if (!file.exists(ind_path)) {
  log_warn("Missing ", ind_path, "; skipping Table 2 and Tables S2 to S4. ",
           "Run: Rscript R/04_municipal_indicators.R")
} else {
  ind <- db_get(con, sprintf("
    SELECT COMUNA_KEY, indicator, value_pct, source
    FROM read_parquet('%s')
  ", sql_path(ind_path)))

  focus <- normalise_place(unlist(cfg$reporting$focus_municipalities))
  sel <- ind[ind$COMUNA_KEY %in% focus, ]

  if (nrow(sel) == 0L) {
    log_warn("No indicators available for the focus municipalities: ",
             paste(focus, collapse = ", "))
  } else {
    wide <- stats::reshape(
      sel[, c("indicator", "COMUNA_KEY", "value_pct")],
      idvar = "indicator", timevar = "COMUNA_KEY", direction = "wide"
    )
    names(wide) <- sub("^value_pct\\.", "", names(wide))

    # Keep the municipalities in the configured order.
    present <- intersect(focus, names(wide))
    wide <- wide[, c("indicator", present), drop = FALSE]
    names(wide)[1] <- "Municipal indicator (%)"

    write_csv_utf8(wide, cfg_path(cfg, "tables", "tableS2_S4_municipal_profiles.csv"))
    write_latex_table(
      wide, cfg_path(cfg, "tables", "table2_municipal_indicators.tex"),
      caption = paste0("Socio-sanitary (CASEN 2022) and structural (2024 Census) ",
                       "indicators for selected municipalities, Chile. Values in per cent."),
      label = "tab:2",
      align = paste0("l", strrep("r", ncol(wide) - 1L)),
      notes = paste0("Source: authors' calculations using CASEN 2022 and the 2024 ",
                     "Population and Housing Census (INE).")
    )
    write_csv_utf8(wide, cfg_path(cfg, "tables", "table2_municipal_indicators.csv"))
    log_info("Wrote Table 2 with ", nrow(wide), " indicators for ",
             length(present), " municipalities")
  }
}


# -----------------------------------------------------------------------------
# 9.6  Record flow, formatted for the manuscript
# -----------------------------------------------------------------------------

flow_path <- cfg_path(cfg, "tables", "record_flow.csv")
if (file.exists(flow_path)) {
  flow <- read_csv_utf8(flow_path)
  flow$n_records <- format(as.numeric(flow$n_records), big.mark = " ", trim = TRUE)
  write_latex_table(
    flow[, c("stage", "n_records", "note")],
    cfg_path(cfg, "tables", "record_flow.tex"),
    caption = "Record flow from the published files to the analysis dataset.",
    label = "tab:flow",
    align = "llp{7cm}"
  )
  log_info("Wrote record_flow.tex")
}

save_run_metadata(cfg, "09_tables_and_figures", "ggplot2")
log_end()
