# ============================================================================
# 05_robustness.R — Robustness checks: placebo, alt clustering, winsorization,
#                   randomization inference
# ============================================================================

cat("=== 05_robustness.R: Robustness checks ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data ------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

robustness <- list()

# ============================================================================
# 1. PLACEBO / FALSIFICATION TESTS
# ============================================================================
cat("\n  --- Placebo tests (fake treatment dates) ---\n")

# Fake date 1: September 2017 → data_oc_numb < 692 on pre-period data [680, 697]
# Fake date 2: March 2017     → data_oc_numb < 686 on pre-period data [674, 691]

run_placebo <- function(dv, data, fake_date, window, completed = FALSE) {
  sub <- data[data_oc_numb >= window[1] & data_oc_numb <= window[2]]
  if (completed) sub <- sub[oc_item_status == 1L]
  sub[, Pre_placebo := as.integer(data_oc_numb < fake_date)]
  sub[, g65_pre_placebo := g65 * Pre_placebo]
  fml <- as.formula(paste0(dv, " ~ g65_pre_placebo + convite + lquantidade | item_alt"))
  feols(fml, data = sub, cluster = ~item_alt, fixef.rm = "none")
}

# Placebo 1: Sep 2017 cutoff on data within [680, 697] (only pre-real-treatment)
PLACEBO1_DATE <- 692L
PLACEBO1_WIN  <- c(680L, 697L)

# Placebo 2: Mar 2017 cutoff on data within [680, 691] (bounded by 18m window start)
PLACEBO2_DATE <- 686L
PLACEBO2_WIN  <- c(680L, 691L)

dvs_placebo <- list(
  list(dv = "lpreco_final", completed = TRUE,  label = "prices"),
  list(dv = "lnum_firms",   completed = FALSE, label = "firms"),
  list(dv = "lnum_bids",    completed = FALSE, label = "bids"),
  list(dv = "dist1",        completed = TRUE,  label = "distance")
)

for (v in dvs_placebo) {
  cat("    Placebo 1 (Sep 2017):", v$label, "...\n")
  robustness[[paste0("placebo1_", v$label)]] <-
    run_placebo(v$dv, dt, PLACEBO1_DATE, PLACEBO1_WIN, v$completed)

  cat("    Placebo 2 (Mar 2017):", v$label, "...\n")
  robustness[[paste0("placebo2_", v$label)]] <-
    run_placebo(v$dv, dt, PLACEBO2_DATE, PLACEBO2_WIN, v$completed)
}

# ============================================================================
# 2. ALTERNATIVE CLUSTERING
# ============================================================================
cat("\n  --- Alternative clustering (18-month window) ---\n")

dvs_cluster <- list(
  list(dv = "lpreco_final", completed = TRUE,  label = "prices"),
  list(dv = "lnum_firms",   completed = FALSE, label = "firms"),
  list(dv = "lnum_bids",    completed = FALSE, label = "bids"),
  list(dv = "dist1",        completed = TRUE,  label = "distance")
)

cluster_specs <- list(
  list(var = "grupo_f",          label = "grupo"),
  list(var = "pbu_alt",          label = "pbu"),
  list(var = "item_alt + pbu_alt", label = "twoway")
)

for (v in dvs_cluster) {
  for (cl in cluster_specs) {
    cat("    ", v$label, "- cluster:", cl$label, "...\n")
    robustness[[paste0("altcl_", v$label, "_", cl$label)]] <-
      run_didir_altcluster(v$dv, dt, WIN_18M, add_pbu = FALSE,
                            completed = v$completed, cluster_var = cl$var)
  }
}

# ============================================================================
# 3. WINSORIZATION ROBUSTNESS
# ============================================================================
cat("\n  --- Winsorized regressions (18-month window) ---\n")

win_dvs <- list(
  list(dv = "lpreco_final_w01", label = "prices_w01", completed = TRUE),
  list(dv = "dist1_w01",        label = "dist_w01",   completed = TRUE),
  list(dv = "lpreco_final_w05", label = "prices_w05", completed = TRUE),
  list(dv = "dist1_w05",        label = "dist_w05",   completed = TRUE)
)

for (v in win_dvs) {
  if (!(v$dv %in% names(dt))) {
    cat("    Skipping", v$dv, "(not available)\n")
    next
  }
  cat("    ", v$label, "base...\n")
  robustness[[paste0("win_", v$label, "_base")]] <-
    run_didir(v$dv, dt, WIN_18M, add_pbu = FALSE, completed = v$completed)
  cat("    ", v$label, "pbu...\n")
  robustness[[paste0("win_", v$label, "_pbu")]] <-
    run_didir(v$dv, dt, WIN_18M, add_pbu = TRUE, completed = v$completed)
}

# ============================================================================
# 4. RANDOMIZATION INFERENCE (Permutation test)
# ============================================================================
cat("\n  --- Randomization inference (permutation test) ---\n")

N_PERM <- 500L
set.seed(42)

# Observed coefficient (18-month, base spec, log prices)
obs_model <- run_didir("lpreco_final", dt, WIN_18M, add_pbu = FALSE, completed = TRUE)
obs_coef  <- coef(obs_model)["g65_pre"]
cat("    Observed coefficient:", pfmt(obs_coef, 4), "\n")

# Permutation: reassign g65 indicator across groups (permute group labels)
perm_sub <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                oc_item_status == 1L]

# Get unique group labels and which are g65
group_levels <- unique(perm_sub$codigogrupo)
cat("    Unique groups:", length(group_levels), "\n")
cat("    Running", N_PERM, "permutations...\n")

perm_coefs <- numeric(N_PERM)
for (i in seq_len(N_PERM)) {
  if (i %% 100 == 0) cat("      Permutation", i, "of", N_PERM, "\n")
  # Shuffle which group is "65"
  shuffled <- sample(group_levels)
  fake_g65_groups <- shuffled[seq_len(sum(group_levels == "65"))]
  perm_sub[, g65_perm := as.integer(codigogrupo %in% fake_g65_groups)]
  perm_sub[, g65_pre_perm := g65_perm * Pre]

  m <- tryCatch({
    feols(lpreco_final ~ g65_pre_perm + convite + lquantidade | item_alt,
          data = perm_sub, cluster = ~item_alt, fixef.rm = "none")
  }, error = function(e) NULL)

  perm_coefs[i] <- if (!is.null(m)) coef(m)["g65_pre_perm"] else NA_real_
}

perm_pval <- mean(abs(perm_coefs) >= abs(obs_coef), na.rm = TRUE)
cat("    Permutation p-value:", pfmt(perm_pval, 4), "\n")

robustness$permutation <- list(
  observed_coef = obs_coef,
  perm_coefs    = perm_coefs,
  perm_pval     = perm_pval,
  n_perm        = N_PERM
)

# ---- Save all robustness models -------------------------------------------
robustness_path <- "/tmp/p2_robustness.rds"
saveRDS(robustness, robustness_path)
cat("  Robustness models saved:", robustness_path, "\n")

# Free memory
rm(dt, perm_sub, obs_model)
gc(verbose = FALSE)
