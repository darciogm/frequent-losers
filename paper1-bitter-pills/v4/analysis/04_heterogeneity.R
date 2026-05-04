# Heterogeneous Effects (4 dimensions)

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "utils.R"))

# Load data
dt <- readRDS(DATA_CACHE)

# Analysis sample: items with both litigated and ordinary, winners
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]
cat("Winners sample:", nrow(dt_win), "obs\n")

# Base spec: bid_price_log ~ urgent | item_id + year_n + pbu_id
# Preferred specification from Table 6A

# Helper: run split-sample + interaction for one dimension
run_heterogeneity <- function(dt_win, split_var, split_label, file_prefix) {
  cat("\nHeterogeneity by", split_label, "\n")

  # Ensure the split variable has no NAs for this analysis
  dt_sub <- dt_win[!is.na(get(split_var))]

  # Split-sample regressions
  dt_lo <- dt_sub[get(split_var) == 0]
  dt_hi <- dt_sub[get(split_var) == 1]

  cat("  Low group:", nrow(dt_lo), "obs; High group:", nrow(dt_hi), "obs\n")

  # 4 FE specs for each subsample
  models_lo <- run_feols4("bid_price_log", "urgent", dt_lo, cluster = ~pbu_id)
  models_hi <- run_feols4("bid_price_log", "urgent", dt_hi, cluster = ~pbu_id)

  # Combine for split table: low specs then high specs (preferred spec 3 only)
  split_models <- list(
    "Low: Item"          = models_lo[["Item"]],
    "Low: Item+Year"     = models_lo[["Item+Year"]],
    "Low: Item+Yr+PBU"   = models_lo[["Item+Year+PBU"]],
    "Low: Item+YM+PBU"   = models_lo[["Item+YM+PBU"]],
    "High: Item"         = models_hi[["Item"]],
    "High: Item+Year"    = models_hi[["Item+Year"]],
    "High: Item+Yr+PBU"  = models_hi[["Item+Year+PBU"]],
    "High: Item+YM+PBU"  = models_hi[["Item+YM+PBU"]]
  )

  save_table(split_models,
             paste0("Heterogeneity — ", split_label, " (Split Sample)"),
             paste0(file_prefix, "_split"),
             coef_map = coef_labels)

  # Interaction model: urgent × split_var
  fml_interact <- as.formula(paste0(
    "bid_price_log ~ urgent * ", split_var, " | item_id + year_n + pbu_id"
  ))
  m_interact <- list(
    "Item+Yr+PBU" = feols(fml_interact, data = dt_sub, cluster = ~pbu_id)
  )

  # Also run with all 4 FE specs
  interact_models <- list()
  fe_specs <- list(
    "Item"          = "item_id",
    "Item+Year"     = "item_id + year_n",
    "Item+Year+PBU" = "item_id + year_n + pbu_id",
    "Item+YM+PBU"   = "item_id + ym_f + pbu_id"
  )
  for (nm in names(fe_specs)) {
    fml <- as.formula(paste0("bid_price_log ~ urgent * ", split_var,
                             " | ", fe_specs[[nm]]))
    interact_models[[nm]] <- feols(fml, data = dt_sub, cluster = ~pbu_id)
  }

  save_table(interact_models,
             paste0("Heterogeneity — ", split_label, " (Interaction)"),
             paste0(file_prefix, "_interaction"),
             coef_map = coef_labels)

  # Print key results
  m3 <- interact_models[["Item+Year+PBU"]]
  cat("  Interaction model (Item+Year+PBU):\n")
  print(summary(m3, se = "cluster"))

  invisible(list(split = split_models, interaction = interact_models))
}

# Dimension 1: SUS Component (Basic vs Specialized)
het_sus <- run_heterogeneity(dt_win, "sus_basic", "SUS Component",
                              "heterogeneity_sus")

# Dimension 2: Time Period (Early vs Late)
het_period <- run_heterogeneity(dt_win, "late_period", "Time Period (2014+)",
                                 "heterogeneity_period")

# Dimension 3: Market Competition (Low vs High)
het_comp <- run_heterogeneity(dt_win, "high_competition", "Market Competition",
                               "heterogeneity_competition")

# Dimension 4: PBU Size (Small vs Large)
het_pbu <- run_heterogeneity(dt_win, "large_pbu", "PBU Size",
                              "heterogeneity_pbu_size")


# Emit macros for the manuscript layer
.bp_macros_path <- file.path(.this_dir, "..", "..", "v6-jpub-short", "analysis", "_macros.R")
if (file.exists(.bp_macros_path)) {
  source(.bp_macros_path)
  m <- list()

  # SUS basic vs specialized: split-sample preferred spec
  if (!is.null(het_sus)) {
    b_basic <- coef(het_sus$split[["High: Item+Yr+PBU"]])["urgent"]   # sus_basic == 1
    b_spec  <- coef(het_sus$split[["Low: Item+Yr+PBU"]])["urgent"]    # sus_basic == 0
    if (length(b_basic) == 1 && !is.na(b_basic)) m$hetSUSbasic <- bp_fmt(b_basic, 3)
    if (length(b_spec)  == 1 && !is.na(b_spec))  m$hetSUSspec  <- bp_fmt(b_spec, 3)
  }

  # Market competition: split-sample preferred spec + interaction
  if (!is.null(het_comp)) {
    b_comp_hi <- coef(het_comp$split[["High: Item+Yr+PBU"]])["urgent"]   # high competition
    b_comp_lo <- coef(het_comp$split[["Low: Item+Yr+PBU"]])["urgent"]    # low competition
    inter_m   <- het_comp$interaction[["Item+Year+PBU"]]
    inter_var <- intersect(c("urgent:high_competition", "urgent:high_competitionTRUE"),
                           names(coef(inter_m)))[1]
    if (length(b_comp_hi) == 1) m$hetCompetitive   <- bp_fmt(b_comp_hi, 3)
    if (length(b_comp_lo) == 1) m$hetConcentrated  <- bp_fmt(b_comp_lo, 3)
    if (!is.na(inter_var))      m$hetInteraction   <- bp_fmt(coef(inter_m)[inter_var], 3)
  }

  if (length(m) > 0) bp_macros_emit("04_heterogeneity", m)
}

cat("\n04_heterogeneity.R complete\n")
