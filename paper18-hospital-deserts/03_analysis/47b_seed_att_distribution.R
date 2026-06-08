#!/usr/bin/env Rscript
# E1_emb rule used here:
# for each closure-year pair, restrict to municipalities with positive
# pre-closure flow to the closing hospital (n_aih_pre > 0) and mark as exposed
# the closest tercile by municipality-hospital embedding cosine distance.
# A municipality's treatment cohort g_emb_seed is the first closure year in
# which it satisfies that rule for any exogenous closure.
suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")
SEED_DIR <- file.path(INTER, "seed_runs")
dir.create(SEED_DIR, showWarnings = FALSE, recursive = TRUE)

OUT_JSON <- file.path(LOG_DIR, "47b_seed_att_distribution.json")
OUT_FIG <- file.path(FIG_DIR, "fig_seed_att_distribution.pdf")
OUT_TAB <- file.path(TAB_DIR, "tab_seed_att_distribution.tex")
OUT_BLOCKED <- file.path(LOG_DIR, "blocked_47b.md")
force <- "--force" %in% commandArgs(trailingOnly = TRUE)

HIGH_COMPLEX <- c("CARDIO", "ONCO", "NEURO", "RENAL", "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE")
SEEDS <- 0:19

pick_python <- function() {
  candidates <- c(
    file.path(ROOT, ".venv-gnn", "bin", "python"),
    file.path(ROOT, ".venv", "bin", "python")
  )
  for (py in candidates) {
    if (!file.exists(py)) next
    status <- system2(py, c("-c", shQuote("import pecanpy")), stdout = FALSE, stderr = FALSE)
    if (identical(status, 0L)) return(py)
  }
  ""
}

run_sa_att <- function(panel, g_col) {
  d <- copy(panel)[is.finite(travel_burden_km)]
  d[, gn_use := ifelse(is.na(get(g_col)) | get(g_col) == 0, 10000L, as.integer(get(g_col)))]
  m <- feols(travel_burden_km ~ sunab(gn_use, year) | muni_id + year, data = d, cluster = ~muni_id)
  agg <- summary(m, agg = "att")
  list(
    att = as.numeric(coef(agg)[1]),
    se = as.numeric(se(agg)[1]),
    n_treated = d[gn_use < 10000, uniqueN(muni_id)]
  )
}

read_embed_parts <- function(path) {
  emb <- as.data.table(read_parquet(path))
  dim_cols <- grep("^dim_", names(emb), value = TRUE)
  muni <- emb[node_type == "M", c("node_id", dim_cols), with = FALSE]
  hosp <- emb[node_type == "H", c("node_id", dim_cols), with = FALSE]
  setnames(muni, "node_id", "codmun_6")
  setnames(hosp, "node_id", "CNES")
  list(muni = muni, hosp = hosp, dim_cols = dim_cols)
}

compute_iso_summary <- function(muni, hosp, dim_cols, hub_cnes) {
  hub <- hosp[CNES %in% hub_cnes]
  if (nrow(hub) == 0 || nrow(muni) == 0) {
    return(list(mean = NA_real_, median = NA_real_, p90 = NA_real_, max = NA_real_))
  }
  muni_mat <- as.matrix(muni[, ..dim_cols])
  hub_mat <- as.matrix(hub[, ..dim_cols])
  muni_norm <- sqrt(rowSums(muni_mat^2))
  hub_norm <- sqrt(rowSums(hub_mat^2))
  muni_norm[muni_norm == 0] <- 1
  hub_norm[hub_norm == 0] <- 1
  sim <- (muni_mat / muni_norm) %*% t(hub_mat / hub_norm)
  iso <- 1 - apply(sim, 1, max)
  list(
    mean = mean(iso),
    median = median(iso),
    p90 = as.numeric(quantile(iso, 0.9)),
    max = max(iso)
  )
}

build_seed_g <- function(exposure_base, muni, hosp, dim_cols) {
  mun_use <- copy(muni)
  hosp_use <- copy(hosp)
  setnames(mun_use, dim_cols, paste0("m_", dim_cols))
  setnames(hosp_use, dim_cols, paste0("h_", dim_cols))
  d <- merge(exposure_base, mun_use, by = "codmun_6", all.x = FALSE, all.y = FALSE)
  d <- merge(d, hosp_use, by = "CNES", all.x = FALSE, all.y = FALSE)
  if (nrow(d) == 0) {
    return(data.table(codmun_6 = character(), g_emb_seed = integer(), n_treat_emb_seed = integer()))
  }
  m_cols <- paste0("m_", dim_cols)
  h_cols <- paste0("h_", dim_cols)
  m_mat <- as.matrix(d[, ..m_cols])
  h_mat <- as.matrix(d[, ..h_cols])
  numer <- rowSums(m_mat * h_mat)
  denom <- sqrt(rowSums(m_mat^2)) * sqrt(rowSums(h_mat^2))
  denom[denom == 0] <- 1
  d[, emb_dist_to_closing_hosp := 1 - numer / denom]
  d[, emb_rank := frank(emb_dist_to_closing_hosp, ties.method = "average"), by = .(CNES, year_closure)]
  d[, emb_cutoff := pmax(1L, ceiling(.N / 3)), by = .(CNES, year_closure)]
  d[, exposed_emb_seed := emb_rank <= emb_cutoff]
  d[exposed_emb_seed == TRUE, .(
    g_emb_seed = min(year_closure),
    n_treat_emb_seed = .N
  ), by = codmun_6]
}

cat("==== begin seed ATT distribution ====\n")
if (file.exists(OUT_JSON) && file.exists(OUT_FIG) && file.exists(OUT_TAB) && !force) {
  cat("outputs already exist; use --force to rebuild\n")
  quit(save = "no", status = 0)
}

python_bin <- pick_python()
if (python_bin == "") {
  writeLines(
    c(
      "# Blocked step 47b: no Python environment with pecanpy",
      "",
      "Neither `.venv-gnn` nor `.venv` can import `pecanpy`, so the 20-seed",
      "node2vec rerun cannot proceed in this workspace."
    ),
    OUT_BLOCKED
  )
  stop("pecanpy unavailable in both local environments")
}

panel_base <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
base_sa <- run_sa_att(panel_base, "g_emb")
exposure_base <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))[n_aih_pre > 0]
hub <- as.data.table(read_parquet(file.path(INTER, "hospital_hub_classification.parquet")))
hub <- hub[hub_categoria %in% HIGH_COMPLEX & hub_ativo_qualquer_mes == TRUE, .(CNES)]
hub_cnes <- unique(hub$CNES)

rows <- vector("list", length(SEEDS))
for (i in seq_along(SEEDS)) {
  s <- SEEDS[i]
  out_file <- file.path(SEED_DIR, sprintf("embeddings_node2vec_seed_%d.parquet", s))
  log_file <- file.path(LOG_DIR, sprintf("47b_seed_%02d_train.log", s))
  wall0 <- Sys.time()
  cat(sprintf("training seed %d with %s ...\n", s, python_bin))
  status <- system2(
    python_bin,
    c("03_analysis/06_train_node2vec.py", "--seed", as.character(s), "--output", out_file),
    stdout = log_file,
    stderr = log_file
  )
  wall_sec <- as.numeric(difftime(Sys.time(), wall0, units = "secs"))
  rss_peak <- NA_real_
  if (file.exists(log_file)) {
    log_lines <- readLines(log_file, warn = FALSE)
    peak_lines <- grep("peak_RSS=", log_lines, value = TRUE)
    if (length(peak_lines) > 0) {
      rss_peak <- suppressWarnings(as.numeric(sub(".*peak_RSS=([0-9.]+)GB.*", "\\1", tail(peak_lines, 1))))
    }
  }
  if (!identical(status, 0L) || !file.exists(out_file)) {
    rows[[i]] <- data.table(
      seed = s,
      output_file = out_file,
      train_status = status,
      train_wall_seconds = wall_sec,
      train_peak_rss_gb = rss_peak,
      n_treated = NA_integer_,
      att_travel_e1_emb = NA_real_,
      se_travel_e1_emb = NA_real_,
      iso_emb_hosp_mean = NA_real_,
      iso_emb_hosp_median = NA_real_,
      iso_emb_hosp_p90 = NA_real_,
      iso_emb_hosp_max = NA_real_
    )
    next
  }

  emb_parts <- read_embed_parts(out_file)
  iso_summary <- compute_iso_summary(emb_parts$muni, emb_parts$hosp, emb_parts$dim_cols, hub_cnes)
  g_seed <- build_seed_g(exposure_base, emb_parts$muni, emb_parts$hosp, emb_parts$dim_cols)

  panel_seed <- merge(
    panel_base[, !c("g_emb", "n_treat_emb", "rel_t_emb", "treat_emb_yr"), with = FALSE],
    g_seed,
    by = "codmun_6",
    all.x = TRUE
  )
  panel_seed[is.na(g_emb_seed), g_emb_seed := 0L]
  panel_seed[is.na(n_treat_emb_seed), n_treat_emb_seed := 0L]
  panel_seed[, rel_t_emb_seed := ifelse(g_emb_seed > 0, year - g_emb_seed, NA_integer_)]
  panel_seed[, treat_emb_yr_seed := g_emb_seed > 0 & year >= g_emb_seed]
  sa_seed <- run_sa_att(panel_seed, "g_emb_seed")

  rows[[i]] <- data.table(
    seed = s,
    output_file = out_file,
    train_status = status,
    train_wall_seconds = wall_sec,
    train_peak_rss_gb = rss_peak,
    n_treated = sa_seed$n_treated,
    att_travel_e1_emb = sa_seed$att,
    se_travel_e1_emb = sa_seed$se,
    iso_emb_hosp_mean = iso_summary$mean,
    iso_emb_hosp_median = iso_summary$median,
    iso_emb_hosp_p90 = iso_summary$p90,
    iso_emb_hosp_max = iso_summary$max
  )
}

res <- rbindlist(rows, fill = TRUE)
ok <- res[train_status == 0 & is.finite(att_travel_e1_emb)]
if (nrow(ok) == 0) {
  writeLines(
    c(
      "# Blocked step 47b: all 20 seed reruns failed",
      "",
      sprintf("Python executable tried: `%s`.", python_bin)
    ),
    OUT_BLOCKED
  )
  stop("all seed reruns failed")
}

att_summary <- list(
  mean = mean(ok$att_travel_e1_emb),
  sd = sd(ok$att_travel_e1_emb),
  iqr = IQR(ok$att_travel_e1_emb),
  min = min(ok$att_travel_e1_emb),
  max = max(ok$att_travel_e1_emb)
)
material_diff <- abs(att_summary$mean - base_sa$att) >= 0.5
instability <- is.finite(att_summary$sd) && att_summary$sd >= 0.5
interpretation <- if (material_diff) {
  "The embedding-driven E1_emb rule yields a materially different ATT than the share-based E1 rule, so the embedding is carrying treatment-relevant information."
} else if (instability) {
  "The mean E1_emb ATT stays close to the share-based E1 estimate, but the seed dispersion is non-trivial, so the embedding-driven treatment assignment is unstable across node2vec initializations."
} else {
  "The embedding-driven E1_emb rule produces a travel ATT close to the share-based E1 estimate and low seed dispersion under this tercile-distance rule."
}

fig <- ggplot(ok, aes(x = att_travel_e1_emb)) +
  geom_histogram(bins = 10, fill = "#1b9e77", color = "white") +
  geom_vline(xintercept = base_sa$att, linetype = "dashed", color = "#d95f02") +
  labs(
    x = "Travel ATT under E1_emb",
    y = "Seed count",
    title = "Seed distribution of embedding-based closure exposure"
  ) +
  theme_minimal(base_size = 10)
ggsave(OUT_FIG, fig, width = 6.5, height = 4.0)

tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Twenty-seed sensitivity of the embedding-driven treatment rule $E1_{emb}$. For each closure, $E1_{emb}$ marks the closest tercile of pre-closure user municipalities by municipality-hospital embedding distance. The benchmark line is the original share-based E1 estimate from the F5 main panel.}",
  "\\label{tab:seed-att-distribution}",
  "\\small",
  "\\begin{tabular}{lrr}",
  "\\toprule",
  "Quantity & Value & Note \\\\",
  "\\midrule",
  sprintf("Successful seed reruns & %d & of 20 requested \\\\", nrow(ok)),
  sprintf("Share-based E1 ATT & %+.3f & SE %.3f \\\\", base_sa$att, base_sa$se),
  sprintf("Mean E1$_{emb}$ ATT across seeds & %+.3f & seed mean \\\\", att_summary$mean),
  sprintf("SD of E1$_{emb}$ ATT across seeds & %.3f & seed dispersion \\\\", att_summary$sd),
  sprintf("IQR of E1$_{emb}$ ATT across seeds & %.3f & Q3$-$Q1 \\\\", att_summary$iqr),
  sprintf("Min / max E1$_{emb}$ ATT & [%+.3f, %+.3f] & support \\\\", att_summary$min, att_summary$max),
  sprintf("Mean treated municipalities under E1$_{emb}$ & %.1f & across seeds \\\\", mean(ok$n_treated)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tab, OUT_TAB)

write(
  toJSON(
    list(
      python_executable = python_bin,
      e1_emb_rule = "For each exogenous closure, E1_emb marks the closest tercile of municipalities with positive pre-closure flow to the closing hospital, ranked by municipality-hospital embedding cosine distance.",
      baseline_share_e1 = base_sa,
      successful_retrains = nrow(ok),
      attempted_retrains = length(SEEDS),
      summary = att_summary,
      results = res,
      interpretation = interpretation
    ),
    auto_unbox = TRUE,
    pretty = TRUE
  ),
  OUT_JSON
)

cat("done\n")
