# ==========================================================================
# calibrate_cartel_primitives.R — Minimum-distance calibration of cartel
# decision parameters (c_1, phi_0, gamma, psi) from Proposition 1 FOC
#
# Uses cross-PBU variation in m* (FL count) and n (genuine bidders)
# to recover structural primitives. See sec5 "Calibration of Cartel
# Primitives" in the manuscript.
#
# Requires: v3/data/processed/bid_level_analysis.parquet
# Outputs:  work/v6/tables/cartel_primitives.csv
# ==========================================================================
cat("=== Calibration of Cartel Primitives ===\n")
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(stats)  # nls, optim
})
setDTthreads(16L)
BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT <- file.path(BASE, "papers_finais/paper2_structural/work/v6/tables")

# ── Load and prepare ──────────────────────────────────────────────
cat("Loading bid-level data...\n")
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet")))

# Tender-level: count FL and genuine bidders per (oc_code, item_code)
tender <- bl[!is.na(bid_price) & bid_price > 0,
  .(n_fl    = sum(is_fl == 1L, na.rm = TRUE),
    n_gen   = sum(is_fl == 0L, na.rm = TRUE),
    n_total = .N,
    has_fl  = as.integer(any(is_fl == 1L))),
  by = .(oc_code, item_code)]

rm(bl); gc(verbose = FALSE)  # free ~235MB after aggregation

# Recover phase from bid_level_with_prices (has descriçãoprocedimentocompra).
# bid_level_analysis lacks phase info, but shares (oc_code, item_code) keys
# with bid_level_with_prices via numerodaoc/códigoitem.
cat("Loading phase codes from bid_level_with_prices...\n")
bwp_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
has_phase <- FALSE
if (file.exists(bwp_path)) {
  bwp <- as.data.table(read_parquet(bwp_path,
    col_select = c("numerodaoc", "códigoitem", "descriçãoprocedimentocompra")))
  # Map text to numeric: CONVITE=2, PREGÃO ELETRÔNICO=3
  bwp[, phase := fcase(
    descriçãoprocedimentocompra == "CONVITE", 2L,
    descriçãoprocedimentocompra == "PREGÃO ELETRÔNICO", 3L,
    default = NA_integer_)]
  phase_map <- unique(bwp[!is.na(phase),
    .(oc_code = numerodaoc, item_code = códigoitem, phase)])
  rm(bwp); gc(verbose = FALSE)

  cat("  Phase map records:", formatC(nrow(phase_map), big.mark = ","), "\n")
  cat("  Phase distribution:\n")
  print(phase_map[, .N, by = phase][order(phase)])

  tender <- merge(tender, phase_map, by = c("oc_code", "item_code"), all.x = TRUE)
  has_phase <- sum(!is.na(tender$phase)) > 0
  cat("  Tenders matched with phase:", formatC(sum(!is.na(tender$phase)), big.mark = ","),
      "/", formatC(nrow(tender), big.mark = ","), "\n")
  rm(phase_map); gc(verbose = FALSE)
} else {
  cat("  WARNING: bid_level_with_prices.parquet not found.\n")
}
cat("Tenders:", formatC(nrow(tender), big.mark = ","), "\n")
cat("FL-present tenders:", formatC(sum(tender$has_fl == 1L), big.mark = ","), "\n")

# Extract PBU code from oc_code (first 11 chars per CLAUDE.md)
tender[, pbu_code := substr(oc_code, 1, 11)]

if (has_phase) {
  tender[, is_convite := as.integer(phase == 2L)]
} else {
  # Fallback: use po_phase_code if extracted
  tender[, is_convite := NA_integer_]
  cat("WARNING: phase_code not found; convite/pregao split unavailable.\n")
}

# ── PBU-level aggregation ──────────────────────────────────────────
# PBU size = total tenders (proxy for oversight/theta_k)
pbu_stats <- tender[, .(
  pbu_size    = .N,
  pbu_fl_rate = mean(has_fl)
), by = pbu_code]

tender <- merge(tender, pbu_stats[, .(pbu_code, pbu_size)],
                by = "pbu_code", all.x = TRUE)

# ── Restrict to FL-present interior-solution tenders ───────────────
# Interior solution: m* > underline_n(tau) - n
# For convite: underline_n = 3; for pregao: underline_n = 0
# Interior means the cartel chose m voluntarily, not forced by constraint.
fl_tenders <- tender[has_fl == 1L & n_fl > 0]

if (has_phase && !all(is.na(fl_tenders$is_convite))) {
  fl_tenders[, min_bidder_req := fifelse(is_convite == 1L, 3L, 0L)]
  fl_tenders[, is_corner := as.integer(n_fl <= (min_bidder_req - n_gen))]
  fl_tenders[is.na(is_corner), is_corner := 0L]
  interior <- fl_tenders[is_corner == 0L]
  corner   <- fl_tenders[is_corner == 1L]
} else {
  # If no phase info, treat all as potential interior
  interior <- fl_tenders
  corner   <- fl_tenders[0]  # empty
}
cat("Interior-solution tenders:", formatC(nrow(interior), big.mark = ","), "\n")
cat("Corner-solution tenders:", formatC(nrow(corner), big.mark = ","), "\n")

# ── PBU-level moments for calibration ─────────────────────────────
pbu_moments <- interior[, .(
  m_bar   = mean(n_fl),
  n_bar   = mean(n_gen),
  n_tenders = .N,
  pbu_size = first(pbu_size)
), by = pbu_code]

# Filter PBUs with enough observations
pbu_moments <- pbu_moments[n_tenders >= 10 & m_bar > 0 & n_bar > 0]
cat("PBUs for calibration:", nrow(pbu_moments), "\n")

# Log-transform
pbu_moments[, log_m := log(m_bar)]
pbu_moments[, log_n := log(n_bar)]
pbu_moments[, log_pbu := log(pbu_size)]

# ── NLS Calibration ────────────────────────────────────────────────
# From eq (calibration_moment) — updated parametrization:
# log(m_bar) = a0 + gamma*log(n_bar) - log(c1 + theta_bar * pbu_size^psi * phi0) + nu
#
# gamma > 0 implies strategic complementarity (Proposition 3):
# cartels deploy more cover bidders in more competitive tenders.
#
# Two-step approach:
# Step 1: OLS of log(m_bar) on log(n_bar) and log(pbu_size) to get gamma
#         and the PBU-size gradient
# Step 2: Profile NLS concentrating out psi

cat("\n--- Step 1: Log-linear approximation ---\n")
step1 <- lm(log_m ~ log_n + log_pbu, data = pbu_moments,
            weights = n_tenders)
cat("  gamma (from log n):", round(coef(step1)["log_n"], 4), "\n")
cat("  pbu gradient:", round(coef(step1)["log_pbu"], 4), "\n")
cat("  R-squared:", round(summary(step1)$r.squared, 4), "\n")
print(summary(step1))

gamma_start <- coef(step1)["log_n"]  # positive = complementarity

# ══════════════════════════════════════════════════════════════════
# Step 2: Profile likelihood over psi
# Fix psi on a grid, estimate (log_pi0, gamma, c1, phi0) at each
# point. Pick psi* that minimizes weighted RSS.
# ══════════════════════════════════════════════════════════════════
cat("\n--- Step 2: Profile likelihood over psi ---\n")

psi_grid <- seq(0.1, 3.0, by = 0.1)
profile <- data.frame(psi = psi_grid, rss = NA_real_,
                       log_pi0 = NA_real_, gamma = NA_real_,
                       c1 = NA_real_, phi0 = NA_real_)

for (i in seq_along(psi_grid)) {
  psi_fix <- psi_grid[i]
  # Pre-compute the pbu term for this psi
  pbu_moments[, pbu_psi := pbu_size^psi_fix]

  fit_i <- tryCatch(
    nls(log_m ~ log_pi0 + gamma * log_n - log(c1 + phi0 * pbu_psi),
        data = pbu_moments,
        start = list(log_pi0 = coef(step1)["(Intercept)"],
                     gamma = unname(gamma_start),
                     c1 = 0.1, phi0 = 0.001),
        lower = c(log_pi0 = -Inf, gamma = -Inf, c1 = 1e-6, phi0 = 1e-8),
        upper = c(log_pi0 =  Inf, gamma =  Inf, c1 = 50,   phi0 = 10),
        algorithm = "port",
        weights = pbu_moments$n_tenders,
        control = nls.control(maxiter = 1000, tol = 1e-6, warnOnly = TRUE)),
    error = function(e) NULL)

  if (!is.null(fit_i)) {
    profile$rss[i] <- sum(resid(fit_i)^2 * pbu_moments$n_tenders)
    cc <- coef(fit_i)
    profile$log_pi0[i] <- cc["log_pi0"]
    profile$gamma[i]   <- cc["gamma"]
    profile$c1[i]      <- cc["c1"]
    profile$phi0[i]    <- cc["phi0"]
  }
}
pbu_moments[, pbu_psi := NULL]  # clean up temp column

n_converged_profile <- sum(!is.na(profile$rss))
cat("  Profile convergence:", n_converged_profile, "/", length(psi_grid), "\n")

if (n_converged_profile > 0) {
  cat("\n  psi      RSS          gamma    c1       phi0\n")
  for (i in which(!is.na(profile$rss))) {
    cat(sprintf("  %.1f  %12.2f  %7.4f  %7.4f  %9.6f\n",
        profile$psi[i], profile$rss[i], profile$gamma[i],
        profile$c1[i], profile$phi0[i]))
  }

  # Check if profile is flat (RSS range < 1% of mean)
  rss_range <- diff(range(profile$rss, na.rm = TRUE))
  rss_mean  <- mean(profile$rss, na.rm = TRUE)
  profile_is_flat <- (rss_range / rss_mean) < 0.01

  best_idx <- which.min(profile$rss)
  psi_star <- profile$psi[best_idx]
  cat("\n  Best psi*:", psi_star, "\n")
  cat("  RSS at psi*:", round(profile$rss[best_idx], 2), "\n")
  cat("  RSS range/mean:", round(100 * rss_range / rss_mean, 2), "%\n")
  cat("  Profile is flat:", profile_is_flat, "\n")
}

# ══════════════════════════════════════════════════════════════════
# Step 3: Full NLS at psi* (or fallback to Step 1 if profile flat)
# ══════════════════════════════════════════════════════════════════
nls_converged <- FALSE

if (n_converged_profile > 0 && !profile_is_flat) {
  cat("\n--- Step 3: NLS at psi* =", psi_star, "---\n")
  pbu_moments[, pbu_psi_star := pbu_size^psi_star]

  nls_fit <- tryCatch(
    nls(log_m ~ log_pi0 + gamma * log_n - log(c1 + phi0 * pbu_psi_star),
        data = pbu_moments,
        start = list(log_pi0 = profile$log_pi0[best_idx],
                     gamma = profile$gamma[best_idx],
                     c1 = profile$c1[best_idx],
                     phi0 = profile$phi0[best_idx]),
        lower = c(log_pi0 = -Inf, gamma = -Inf, c1 = 1e-6, phi0 = 1e-8),
        upper = c(log_pi0 =  Inf, gamma =  Inf, c1 = 50,   phi0 = 10),
        algorithm = "port",
        weights = pbu_moments$n_tenders,
        control = nls.control(maxiter = 1000, tol = 1e-6)),
    error = function(e) { cat("NLS at psi* failed:", e$message, "\n"); NULL })

  if (!is.null(nls_fit)) {
    cat("NLS converged at psi* =", psi_star, "\n")
    print(summary(nls_fit))
    nls_coefs <- coef(nls_fit)
    params <- c(pi0 = unname(exp(nls_coefs["log_pi0"])),
                gamma = unname(nls_coefs["gamma"]),
                c1 = unname(nls_coefs["c1"]),
                phi0 = unname(nls_coefs["phi0"]),
                psi = psi_star)
    nls_converged <- TRUE
  }
  pbu_moments[, pbu_psi_star := NULL]
}

if (!nls_converged && n_converged_profile > 0) {
  # NLS at psi* failed, but profile gave conditional estimates.
  # Use profile-best parameters for overidentification and reporting.
  cat("\n--- Using profile-best parameters (psi* =", psi_star, ") ---\n")
  params <- c(pi0 = unname(exp(profile$log_pi0[best_idx])),
              gamma = unname(profile$gamma[best_idx]),
              c1 = unname(profile$c1[best_idx]),
              phi0 = unname(profile$phi0[best_idx]),
              psi = psi_star)
  cat("  pi0:", round(params["pi0"], 4), "\n")
  cat("  gamma:", round(params["gamma"], 4), "\n")
  cat("  c1:", round(params["c1"], 4), "\n")
  cat("  phi0:", round(params["phi0"], 6), "\n")
  cat("  psi:", params["psi"], "\n")
  # Flag that these come from profile, not full NLS
  params_from_profile <- TRUE
} else if (!nls_converged) {
  cat("\n--- Falling back to Step 1 log-linear ---\n")
  if (exists("profile_is_flat") && profile_is_flat) {
    cat("  Reason: profile is flat — psi not identified (enforcement variation too weak).\n")
  }
  params <- c(pi0 = unname(exp(coef(step1)["(Intercept)"])),
              gamma = unname(gamma_start),
              c1 = NA_real_, phi0 = NA_real_, psi = NA_real_)
  params_from_profile <- FALSE
} else {
  params_from_profile <- FALSE
}

# ══════════════════════════════════════════════════════════════════
# Step 4: PBU-clustered bootstrap (conditional on psi*)
# ══════════════════════════════════════════════════════════════════
cat("\n--- PBU-clustered bootstrap (500 reps) ---\n")
set.seed(2026)
B <- 500

if (nls_converged || params_from_profile) {
  # Bootstrap the 4-param model at fixed psi*
  boot_params <- matrix(NA, B, 5,
    dimnames = list(NULL, c("pi0", "gamma", "c1", "phi0", "psi")))
  boot_start <- list(log_pi0 = log(params["pi0"]), gamma = params["gamma"],
                     c1 = params["c1"], phi0 = params["phi0"])
  pbu_moments[, pbu_psi_star := pbu_size^psi_star]

  for (b in seq_len(B)) {
    idx <- sample(nrow(pbu_moments), nrow(pbu_moments), replace = TRUE)
    bdat <- pbu_moments[idx]
    fit_b <- tryCatch(
      nls(log_m ~ log_pi0 + gamma * log_n - log(c1 + phi0 * pbu_psi_star),
          data = bdat,
          start = boot_start,
          lower = c(log_pi0 = -Inf, gamma = -Inf, c1 = 1e-6, phi0 = 1e-8),
          upper = c(log_pi0 =  Inf, gamma =  Inf, c1 = 50,   phi0 = 10),
          algorithm = "port",
          weights = bdat$n_tenders,
          control = nls.control(maxiter = 1000, tol = 1e-6, warnOnly = TRUE)),
      error = function(e) NULL)
    if (!is.null(fit_b)) {
      bc <- coef(fit_b)
      boot_params[b, ] <- c(exp(bc["log_pi0"]), bc["gamma"],
                             bc["c1"], bc["phi0"], psi_star)
    }
    if (b %% 100 == 0) cat("  Bootstrap rep", b, "/", B, "\n")
  }
  pbu_moments[, pbu_psi_star := NULL]
} else {
  # Bootstrap the Step 1 OLS
  boot_params <- matrix(NA, B, 2,
    dimnames = list(NULL, c("pi0", "gamma")))
  for (b in seq_len(B)) {
    idx <- sample(nrow(pbu_moments), nrow(pbu_moments), replace = TRUE)
    bdat <- pbu_moments[idx]
    fit_b <- lm(log_m ~ log_n + log_pbu, data = bdat, weights = n_tenders)
    boot_params[b, ] <- c(exp(coef(fit_b)["(Intercept)"]),
                           coef(fit_b)["log_n"])
    if (b %% 100 == 0) cat("  Bootstrap rep", b, "/", B, "\n")
  }
}

boot_se <- apply(boot_params, 2, sd, na.rm = TRUE)
boot_ci <- apply(boot_params, 2, quantile, c(0.025, 0.975), na.rm = TRUE)
converged_boot <- sum(complete.cases(boot_params))
cat("  Bootstrap convergence:", converged_boot, "/", B, "\n")
cat("  Bootstrap SEs:", paste(round(boot_se, 4), collapse = ", "), "\n")
if (ncol(boot_ci) >= 2) {
  cat("  95% CIs:\n")
  for (j in seq_len(ncol(boot_ci))) {
    cat("    ", colnames(boot_ci)[j], ": [",
        round(boot_ci[1, j], 4), ",", round(boot_ci[2, j], 4), "]\n")
  }
}

# ── Overidentification: split-sample out-of-sample prediction ──────
# Estimate on 2/3 of PBUs, predict m̄ on the holdout 1/3.
# Reports correlation, RMSE, and mean absolute error.
cat("\n--- Overidentification: split-sample prediction ---\n")
if (!is.na(params["c1"])) {
  set.seed(2026)
  n_pbus <- nrow(pbu_moments)
  train_idx <- sort(sample(n_pbus, round(n_pbus * 2/3)))
  test_idx <- setdiff(seq_len(n_pbus), train_idx)
  train <- pbu_moments[train_idx]
  test  <- pbu_moments[test_idx]
  cat("  Train PBUs:", nrow(train), "| Test PBUs:", nrow(test), "\n")

  # Re-estimate on training set at fixed psi*
  train[, pbu_psi_star := pbu_size^psi_star]
  oos_fit <- tryCatch(
    nls(log_m ~ log_pi0 + gamma * log_n - log(c1 + phi0 * pbu_psi_star),
        data = train,
        start = list(log_pi0 = log(params["pi0"]), gamma = params["gamma"],
                     c1 = params["c1"], phi0 = params["phi0"]),
        lower = c(log_pi0 = -Inf, gamma = -Inf, c1 = 1e-6, phi0 = 1e-8),
        upper = c(log_pi0 =  Inf, gamma =  Inf, c1 = 50,   phi0 = 10),
        algorithm = "port",
        weights = train$n_tenders,
        control = nls.control(maxiter = 1000, tol = 1e-6, warnOnly = TRUE)),
    error = function(e) NULL)

  if (!is.null(oos_fit)) {
    oos_coefs <- coef(oos_fit)
    # Predict on test set
    test[, pbu_psi_star := pbu_size^psi_star]
    test[, log_m_pred := oos_coefs["log_pi0"] + oos_coefs["gamma"] * log_n -
           log(oos_coefs["c1"] + oos_coefs["phi0"] * pbu_psi_star)]

    oos_cor <- cor(test$log_m, test$log_m_pred, use = "complete.obs")
    oos_rmse <- sqrt(mean((test$log_m - test$log_m_pred)^2, na.rm = TRUE))
    oos_mae <- mean(abs(test$log_m - test$log_m_pred), na.rm = TRUE)
    oos_r2 <- 1 - sum((test$log_m - test$log_m_pred)^2) /
                  sum((test$log_m - mean(test$log_m))^2)

    cat("  Train estimates: gamma =", round(oos_coefs["gamma"], 4),
        ", c1 =", round(oos_coefs["c1"], 4), "\n")
    cat("  Out-of-sample correlation:", round(oos_cor, 4), "\n")
    cat("  Out-of-sample R²:", round(oos_r2, 4), "\n")
    cat("  RMSE (log scale):", round(oos_rmse, 4), "\n")
    cat("  MAE (log scale):", round(oos_mae, 4), "\n")

    # Comparison: naive model (predict mean)
    naive_rmse <- sqrt(mean((test$log_m - mean(train$log_m))^2))
    cat("  Naive RMSE (predict mean):", round(naive_rmse, 4), "\n")
    cat("  RMSE improvement vs naive:", round(100 * (1 - oos_rmse / naive_rmse), 1), "%\n")
  } else {
    cat("  NLS on training set failed — using Step 1 OLS for OOS test.\n")
    oos_ols <- lm(log_m ~ log_n + log_pbu, data = train, weights = n_tenders)
    test[, log_m_pred := predict(oos_ols, newdata = test)]
    oos_cor <- cor(test$log_m, test$log_m_pred)
    oos_r2 <- 1 - sum((test$log_m - test$log_m_pred)^2) /
                  sum((test$log_m - mean(test$log_m))^2)
    oos_rmse <- sqrt(mean((test$log_m - test$log_m_pred)^2))
    naive_rmse <- sqrt(mean((test$log_m - mean(train$log_m))^2))
    cat("  Out-of-sample correlation:", round(oos_cor, 4), "\n")
    cat("  Out-of-sample R²:", round(oos_r2, 4), "\n")
    cat("  RMSE (log scale):", round(oos_rmse, 4), "\n")
    cat("  RMSE improvement vs naive:", round(100 * (1 - oos_rmse / naive_rmse), 1), "%\n")
  }

  # Save OOS predictions
  write.csv(test[, .(pbu_code, log_m, log_m_pred, n_tenders)],
            file.path(OUT, "oos_predictions.csv"), row.names = FALSE)
  cat("  OOS predictions saved to oos_predictions.csv\n")

  # Repeated splits for stability
  cat("\n  --- Stability: 100 random splits ---\n")
  set.seed(42)
  n_splits <- 100
  split_r2 <- numeric(n_splits)
  split_cor <- numeric(n_splits)
  for (s in seq_len(n_splits)) {
    s_train <- sort(sample(n_pbus, round(n_pbus * 2/3)))
    s_test <- setdiff(seq_len(n_pbus), s_train)
    s_ols <- lm(log_m ~ log_n + log_pbu, data = pbu_moments[s_train],
                weights = n_tenders)
    s_pred <- predict(s_ols, newdata = pbu_moments[s_test])
    s_obs <- pbu_moments[s_test]$log_m
    split_cor[s] <- cor(s_obs, s_pred)
    split_r2[s] <- 1 - sum((s_obs - s_pred)^2) / sum((s_obs - mean(s_obs))^2)
  }
  cat("  Median OOS R²:", round(median(split_r2), 4), "\n")
  cat("  IQR OOS R²: [", round(quantile(split_r2, 0.25), 4), ",",
      round(quantile(split_r2, 0.75), 4), "]\n")
  cat("  Median OOS correlation:", round(median(split_cor), 4), "\n")
}

# ── Save results ───────────────────────────────────────────────────
results <- data.frame(
  param = c("pi0", "gamma", "c1", "phi0", "psi",
            "se_pi0", "se_gamma",
            if (nls_converged || params_from_profile) c("se_c1", "se_phi0", "se_psi") else NULL,
            "n_pbus", "n_interior_tenders", "n_corner_tenders",
            "step1_gamma", "step1_pbu_gradient", "step1_r2",
            "nls_converged", "profile_flat",
            "profile_psi_star", "profile_rss_range_pct"),
  value = c(params,
            boot_se,
            nrow(pbu_moments), nrow(interior), nrow(corner),
            coef(step1)["log_n"],
            coef(step1)["log_pbu"],
            summary(step1)$r.squared,
            as.integer(nls_converged),
            as.integer(if (exists("profile_is_flat")) profile_is_flat else NA),
            if (exists("psi_star")) psi_star else NA,
            if (exists("rss_range") && exists("rss_mean"))
              round(100 * rss_range / rss_mean, 2) else NA)
)
write.csv(results, file.path(OUT, "cartel_primitives.csv"), row.names = FALSE)

# Save profile grid separately
if (n_converged_profile > 0) {
  write.csv(profile, file.path(OUT, "profile_psi.csv"), row.names = FALSE)
  cat("Profile grid saved to", file.path(OUT, "profile_psi.csv"), "\n")
}

cat("\nResults saved to", file.path(OUT, "cartel_primitives.csv"), "\n")
cat("=== DONE ===\n")
