#!/usr/bin/env Rscript
# =============================================================================
# 14_overcrediting_inflation_sim.R  --  JLEO R&R (v22)  --  OBJECT 2
# THE OVER-CREDITING BIAS AS AN ESTIMABLE OBJECT  (Tier B reframe, memo Object 2)
#
# WHAT THIS IS (and is NOT):
#   A SYNTHETIC simulation that demonstrates the MAGNITUDE of the raw award-screen
#   AUC inflation as a function of (a) participation-volume dispersion CV(T) and
#   (b) the adjudicated base rate. It backs a Proposition that states only the
#   two comparative-static SIGNS. There is NO closed-form magnitude formula here
#   (memo guardrail §2.7): signs are analytic, magnitude is simulation.
#
#   NO confidential microdata enters any output. The two real overlay points use
#   only two scalars per platform -- CV of always-loser tenders_count and the
#   adjudicated base rate -- read from the on-disk FREQ_PARTICIP_rebuilt parquets.
#   No firm identifier, no per-firm row, nothing confidential is written.
#
# MECHANISM (memo §2.2):
#   The award score is monotone in participation volume T (= log(1+T)). The
#   contact-defined cobidder label is mechanically increasing in T:
#       Pr(cobidder_i = 1 | T_i) = 1 - (1-pi)^{T_i}  ~  pi*T_i  (rare target).
#   So BOTH score and label load on T. The positive class is therefore the
#   SIZE-BIASED T distribution and the negative class is ~F_T. Then
#       AUC_raw = Pr(T_i > T_j),  T_i ~ size-biased(F_T),  T_j ~ F_T,
#   a classic size-bias gap. The opportunity-adjusted (within-T-stratum) AUC
#   removes the volume channel; with NO genuine within-stratum signal it sits at
#   ~0.5. Delta = AUC_raw - AUC_within is the over-crediting inflation.
#
# COMPARATIVE STATICS the grid demonstrates (the Proposition's two signs):
#   (a) Delta INCREASING in CV(T):  more volume dispersion => bigger size-bias gap.
#   (b) Delta DECREASING in base rate: as pi*T leaves the rare-target regime the
#       size-biasing saturates (1-(1-pi)^T flattens) => less inflation.
#
# Run:
#   Rscript work/v22-editor/scripts/analysis/14_overcrediting_inflation_sim.R \
#     2>&1 | tee work/v22-editor/outputs/logs/overcrediting_inflation_sim.log
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  ok_ggplot <- requireNamespace("ggplot2", quietly = TRUE)
})
if (ok_ggplot) library(ggplot2)

t0  <- Sys.time()
say <- function(...) cat(sprintf(...), "\n")
SEED <- 20260606L
set.seed(SEED)

# ---- locate repo + dirs -----------------------------------------------------
fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
SD <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
REPO <- normalizePath(file.path(SD, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
DATA      <- file.path(REPO, "data", "processed")
DATA_FED  <- file.path(REPO, "data", "processed_comprasnet")
V22       <- file.path(REPO, "work", "v22-editor")
OUT       <- file.path(V22, "outputs")
dir_diag  <- file.path(OUT, "diagnostics")
dir_fig   <- file.path(OUT, "figures")
dir_logs  <- file.path(OUT, "logs")
dir_subm  <- file.path(V22, "submission_clean", "output", "figures")
for (d in c(dir_diag, dir_fig, dir_logs, dir_subm))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

say("=== 14_overcrediting_inflation_sim.R === host=%s  seed=%d",
    Sys.info()[["nodename"]], SEED)
say("R %s | ggplot2 available: %s", getRversion(), ok_ggplot)
mem0 <- tryCatch(as.numeric(system("awk '/MemAvailable/{print $2}' /proc/meminfo", intern = TRUE)) / 1e6,
                 error = function(e) NA_real_)
say("MemAvailable at start: %.1f GiB", mem0)

# =============================================================================
# 0.  REAL OVERLAY POINTS  (two scalars per platform, no confidential detail)
# =============================================================================
cv_of <- function(x) sd(x) / mean(x)

bec_T <- arrow::read_parquet(file.path(DATA, "FREQ_PARTICIP_rebuilt.parquet"))$tenders_count
fed_T <- arrow::read_parquet(file.path(DATA_FED, "FREQ_PARTICIP_rebuilt.parquet"))$tenders_count
bec_T <- as.numeric(bec_T); fed_T <- as.numeric(fed_T)

# Locked positive counts (canonical broad always-loser cobidders), memo §2.5 +
# Table C / Appendix G of the submission.
BEC_POS <- 651L; FED_POS <- 195L
bec_cv  <- cv_of(bec_T);  bec_N <- length(bec_T);  bec_br <- BEC_POS / bec_N
fed_cv  <- cv_of(fed_T);  fed_N <- length(fed_T);  fed_br <- FED_POS / fed_N

say("\n--- REAL overlay points (CV of always-loser tenders_count + base rate) ---")
say("BEC : N=%d  pos=%d  CV(T)=%.3f  base_rate=%.5f  mean(T)=%.2f",
    bec_N, BEC_POS, bec_cv, bec_br, mean(bec_T))
say("FED : N=%d  pos=%d  CV(T)=%.3f  base_rate=%.5f  mean(T)=%.2f",
    fed_N, FED_POS, fed_cv, fed_br, mean(fed_T))

# =============================================================================
# 1.  METRIC HELPERS
# =============================================================================
# Rank-based AUC (Mann-Whitney), ties at 0.5.
auc_rank <- function(y, s) {
  n1 <- sum(y == 1L); n0 <- sum(y == 0L)
  if (!n1 || !n0) return(NA_real_)
  r <- rank(s)
  (sum(r[y == 1L]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# Within-T-stratum (opportunity-adjusted) AUC: pool the within-stratum
# concordance over quantile bins of T. With no genuine within-stratum signal
# this is ~0.5 -- it strips the volume channel that the raw AUC rides on. This
# is the synthetic analogue of the paper's within-opportunity-stratum AUC.
auc_within <- function(y, s, strat, score_jitter) {
  num <- 0; den <- 0
  for (g in unique(strat)) {
    idx <- which(strat == g)
    yg  <- y[idx]; sg <- score_jitter[idx]
    n1 <- sum(yg == 1L); n0 <- sum(yg == 0L)
    if (!n1 || !n0) next
    p <- sg[yg == 1L]; n <- sg[yg == 0L]
    cmp <- outer(p, n, function(a, b) (a > b) + 0.5 * (a == b))
    num <- num + sum(cmp); den <- den + n1 * n0
  }
  if (den == 0) return(NA_real_)
  num / den
}

# =============================================================================
# 2.  SIMULATION CORE
# =============================================================================
# T ~ Gamma(shape = 1/CV^2, rate = shape/mean) so E[T]=mean, CV(T)=CV exactly.
# (Gamma is the Poisson-mixing family already used in the framework appendix.)
# Labels: size-biased contact. Pr(y=1|T) = 1 - (1-pi)^T, with pi tuned so the
# realized base rate hits the grid target. A genuine within-stratum signal of
# strength theta (>=0) can be injected by tilting the label odds with a
# within-stratum-standardized noise term; theta=0 is the pure-null curve.
N_FIRMS  <- 80000L   # large enough that grid AUCs are stable to ~0.002
MEAN_T   <- 12       # fixed mean; only CV varies the dispersion (Delta depends on CV, not scale)
# Opportunity-adjusted AUC fixes the volume channel. Strata must be FINE ENOUGH
# in T that residual within-stratum T-variation (and hence residual size-bias)
# is negligible -- otherwise a coarse-stratum "adjustment" leaks the very volume
# channel it is meant to remove. We use many quantile strata of T; under the
# pure-null (theta=0) this drives the adjusted AUC to ~0.5 at every CV, so Delta
# isolates the size-bias gap. This mirrors the paper's within-opportunity-stratum
# object (the genuine-signal floor), which sits at ~chance (BEC 0.471, fed 0.462).
N_STRATA <- 200L     # T-quantile strata for the opportunity adjustment

# pi that yields a target marginal base rate br given the T draw.
solve_pi <- function(Tvec, br_target) {
  f <- function(pi) mean(1 - (1 - pi)^Tvec) - br_target
  lo <- 1e-9; hi <- 1 - 1e-9
  if (f(lo) > 0) return(lo)
  if (f(hi) < 0) return(hi)
  uniroot(f, c(lo, hi), tol = 1e-12)$root
}

# SCORE_NOISE: the real award score (log participation volume) is a NOISY proxy
# for the latent volume that drives contact. A pure log(1+T) score is a perfect
# volume ranker and saturates the raw AUC near 0.95 -- far above the locked
# BEC/federal raw AUCs (0.761/0.744). We calibrate one scalar (SCORE_NOISE, the
# SD of measurement noise added to log(1+T)) so the BEC coordinate reproduces its
# locked raw AUC ~0.76. The SAME scalar is then held fixed across the entire
# grid, so the comparative statics are read on a realistically-leveled surface.
# This is a calibration of the score's informativeness, NOT a fit of the bias
# magnitude -- the magnitude shape comes out of the size-bias mechanism.
SCORE_NOISE <- 1.85   # set by 1-D calibration below; reproduces BEC raw ~0.76

sim_point <- function(cv, br, theta = 0, sigma = SCORE_NOISE, n = N_FIRMS) {
  shape <- 1 / (cv^2)
  rate  <- shape / MEAN_T
  Tvec  <- rgamma(n, shape = shape, rate = rate)
  Tvec  <- pmax(Tvec, 1e-6)
  pi    <- solve_pi(Tvec, br)
  p_base <- 1 - (1 - pi)^Tvec                 # size-biased contact probability
  # genuine within-stratum signal: standardize a noise feature within T-strata
  # and tilt the label log-odds by theta*z. theta=0 -> pure size-bias null.
  brk <- unique(quantile(Tvec, probs = seq(0, 1, length.out = N_STRATA + 1)))
  if (length(brk) < 3L) {
    strat <- rep(1L, n)               # degenerate dispersion: single stratum
  } else {
    strat <- cut(Tvec, breaks = brk, include.lowest = TRUE, labels = FALSE)
  }
  z <- rnorm(n)
  if (theta > 0) {
    zb <- ave(z, strat, FUN = function(x) (x - mean(x)) / (sd(x) + 1e-9))
    odds <- log(p_base / (1 - p_base)) + theta * zb
    p <- 1 / (1 + exp(-odds))
  } else {
    p <- p_base
  }
  y <- rbinom(n, 1L, pmin(pmax(p, 0), 1))
  if (sum(y) < 2L || sum(y) > n - 2L) return(c(auc_raw = NA, auc_adj = NA, delta = NA, br_real = mean(y)))
  # noisy monotone-in-T award score: latent log(1+T) corrupted by measurement noise
  score <- log1p(Tvec) + rnorm(n, 0, sigma)
  raw <- auc_rank(y, score)
  adj <- auc_within(y, score, strat, score)
  c(auc_raw = raw, auc_adj = adj, delta = raw - adj, br_real = mean(y))
}

# ---- calibrate SCORE_NOISE so BEC coordinate reproduces locked raw AUC ~0.76 --
# (one-dimensional, transparent; not a fit of the bias). We solve for sigma at
# the BEC (CV, base rate) point so the simulated raw AUC matches the locked 0.761.
calib_raw <- function(sigma) sim_point(bec_cv, bec_br, theta = 0, sigma = sigma)["auc_raw"]
sig_grid  <- seq(0.5, 3.5, by = 0.25)
sig_aucs  <- vapply(sig_grid, calib_raw, numeric(1))
SCORE_NOISE <- approx(sig_aucs, sig_grid, xout = 0.761, rule = 2)$y
say("\n--- SCORE_NOISE calibration (BEC coord -> locked raw 0.761) ---")
for (i in seq_along(sig_grid)) say("   sigma=%.2f  raw_AUC=%.3f", sig_grid[i], sig_aucs[i])
say("   chosen SCORE_NOISE = %.3f", SCORE_NOISE)

# =============================================================================
# 3.  THE GRID  (CV x base rate), pure-null (theta=0) inflation surface
# =============================================================================
# CV grid brackets BEC (2.79) and federal (3.79). Base-rate grid brackets the
# federal AL-pool rate (~0.005) and the BEC AL-pool rate (~0.039).
# CV grid brackets BEC (2.79) and federal (3.79).
cv_grid <- c(0.5, 1.0, 1.5, 2.0, 2.5, 2.791, 3.0, 3.5, 3.791, 4.0, 4.5, 5.0)
# Base-rate grid: the rare-target regime where BEC (~0.039) and federal (~0.005)
# live is the left edge; we extend to 0.50 so the saturation-driven decline of
# Delta in the base rate is VISIBLE (the comparative static is provable in the
# rare-target linearization but its magnitude only opens up at higher base rates).
br_grid <- c(0.005, 0.0054, 0.01, 0.02, 0.0387, 0.05, 0.10, 0.20, 0.35, 0.50)

say("\n--- GRID: %d CV x %d base-rate points (theta=0 pure null) ---",
    length(cv_grid), length(br_grid))

grid <- expand.grid(cv = cv_grid, base_rate = br_grid)
res  <- t(mapply(function(cv, br) sim_point(cv, br, theta = 0),
                 grid$cv, grid$base_rate))
surface <- data.frame(cv = grid$cv, base_rate = grid$base_rate,
                      auc_raw = res[, "auc_raw"], auc_adj = res[, "auc_adj"],
                      delta = res[, "delta"], base_rate_realized = res[, "br_real"])

# ---- monotonicity confirmation ----------------------------------------------
# (a) Delta increasing in CV at fixed base rate?
say("\n--- (a) Delta vs CV  (at base_rate = 0.0387, BEC-like) ---")
sub_a <- surface[abs(surface$base_rate - 0.0387) < 1e-9, ]
sub_a <- sub_a[order(sub_a$cv), ]
for (i in seq_len(nrow(sub_a)))
  say("   CV=%.3f  AUC_raw=%.3f  AUC_adj=%.3f  Delta=%.3f",
      sub_a$cv[i], sub_a$auc_raw[i], sub_a$auc_adj[i], sub_a$delta[i])
mono_cv <- all(diff(sub_a$delta) >= -0.01)   # allow tiny MC wobble
say("   => Delta MONOTONE-INCREASING in CV: %s", mono_cv)

say("\n--- (b) Delta vs base rate  (at CV = 2.791, BEC) and (CV = 3.791, fed) ---")
for (cvx in c(2.791, 3.791)) {
  sub_b <- surface[abs(surface$cv - cvx) < 1e-9, ]
  sub_b <- sub_b[order(sub_b$base_rate), ]
  say("  CV=%.3f:", cvx)
  for (i in seq_len(nrow(sub_b)))
    say("    base_rate=%.4f  AUC_raw=%.3f  Delta=%.3f",
        sub_b$base_rate[i], sub_b$auc_raw[i], sub_b$delta[i])
  mono_br <- all(diff(sub_b$delta) <= 0.01)
  say("    => Delta MONOTONE-DECREASING in base rate: %s", mono_br)
}

# =============================================================================
# 4.  THE TWO REAL POINTS on the surface (theta=0 prediction at their coords)
# =============================================================================
say("\n--- REAL points: predicted pure-null AUC_raw at (CV, base_rate) ---")
bec_pred <- sim_point(bec_cv, bec_br, theta = 0)
fed_pred <- sim_point(fed_cv, fed_br, theta = 0)
say("BEC  CV=%.3f br=%.5f  ->  predicted AUC_raw=%.3f  (LOCKED raw=0.761)",
    bec_cv, bec_br, bec_pred["auc_raw"])
say("FED  CV=%.3f br=%.5f  ->  predicted AUC_raw=%.3f  (LOCKED raw=0.744)",
    fed_cv, fed_br, fed_pred["auc_raw"])

real_pts <- data.frame(
  platform   = c("BEC", "Federal"),
  cv         = c(bec_cv, fed_cv),
  base_rate  = c(bec_br, fed_br),
  auc_raw_locked = c(0.761, 0.744),
  auc_adj_locked = c(0.471, 0.462),   # within-opportunity-stratum (genuine floor)
  delta_locked   = c(0.761 - 0.471, 0.744 - 0.462),
  auc_raw_sim    = c(bec_pred["auc_raw"], fed_pred["auc_raw"]),
  delta_sim      = c(bec_pred["delta"],   fed_pred["delta"])
)
say("\n--- REAL points: locked vs simulated ---")
print(real_pts, row.names = FALSE)

# =============================================================================
# 5.  WRITE CSV
# =============================================================================
csv_path <- file.path(dir_diag, "inflation_surface.csv")
write.csv(surface[, c("cv", "base_rate", "auc_raw", "auc_adj", "delta")],
          csv_path, row.names = FALSE)
say("\nwrote %s  (%d rows)", csv_path, nrow(surface))
write.csv(real_pts, file.path(dir_diag, "inflation_real_points.csv"), row.names = FALSE)
say("wrote %s", file.path(dir_diag, "inflation_real_points.csv"))

# =============================================================================
# 6.  DENSE RENDER GRID + FIGURE
# =============================================================================
# The reported CSV grid is coarse and unevenly spaced in base rate, which makes
# a raw heatmap unreadable. For the FIGURE only, simulate Delta on a DENSE,
# regularly-spaced render grid (CV linear; base rate log-spaced so the
# rare-target region where BEC/federal live is well-resolved). Same mechanism,
# same calibrated SCORE_NOISE, larger n for smoothness.
say("\n--- DENSE render grid for figure (heatmap) ---")
cv_r <- seq(0.5, 5.0, length.out = 28)
br_r <- exp(seq(log(0.004), log(0.55), length.out = 26))
rgrid <- expand.grid(cv = cv_r, base_rate = br_r)
rres  <- t(mapply(function(cv, br) sim_point(cv, br, theta = 0, n = 40000L),
                  rgrid$cv, rgrid$base_rate))
render <- data.frame(cv = rgrid$cv, base_rate = rgrid$base_rate, delta = rres[, "delta"])
write.csv(render, file.path(dir_diag, "inflation_surface_render.csv"), row.names = FALSE)

if (ok_ggplot) {
  fig_pdf  <- file.path(dir_fig, "fig_inflation_surface.pdf")
  subm_pdf <- file.path(dir_subm, "fig_inflation_surface.pdf")
  pts <- data.frame(
    platform  = c("BEC", "Federal"),
    cv        = c(bec_cv, fed_cv),
    base_rate = c(bec_br, fed_br),
    lab       = c(sprintf("BEC (raw 0.761, within 0.471)"),
                  sprintf("Federal (raw 0.744, exp-only 0.754)"))
  )
  yb <- c(0.005, 0.01, 0.02, 0.05, 0.10, 0.20, 0.50)
  g <- ggplot(render, aes(x = cv, y = base_rate, fill = delta)) +
    geom_tile() +
    geom_contour(aes(z = delta), colour = "white", alpha = 0.55, linewidth = 0.3,
                 breaks = seq(0.05, 0.35, by = 0.05)) +
    scale_fill_viridis_c(name = expression(Delta == AUC[raw] - AUC[within]),
                         option = "magma", direction = -1) +
    geom_point(data = pts, aes(x = cv, y = base_rate),
               inherit.aes = FALSE, shape = 21, size = 4.2,
               fill = "white", colour = "black", stroke = 1.2) +
    geom_text(data = pts, aes(x = cv, y = base_rate, label = lab),
              inherit.aes = FALSE, hjust = c(1.08, 1.08), vjust = -0.9,
              size = 2.9, fontface = "bold") +
    scale_y_log10(breaks = yb, labels = function(x) paste0(100 * x, "%")) +
    coord_cartesian(expand = FALSE) +
    labs(
      x = "Volume dispersion  CV(T)   (the sufficient statistic)",
      y = "Adjudicated base rate (log scale)",
      title = "Over-crediting inflation surface (synthetic)",
      subtitle = expression(paste(Delta,
        " rises with CV(T), falls with the base rate; BEC and federal sit in the rare-target zone"))
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(),
          plot.subtitle = element_text(size = 8.3))
  ggsave(fig_pdf, g, width = 7.4, height = 5.0)
  file.copy(fig_pdf, subm_pdf, overwrite = TRUE)
  say("wrote figure %s", fig_pdf)
  say("copied figure to %s", subm_pdf)
} else {
  say("ggplot2 not available -- figure skipped (CSV still written)")
}

say("\n=== DONE in %.1f s ===", as.numeric(difftime(Sys.time(), t0, units = "secs")))
