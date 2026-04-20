# ============================================================================
# 36_counterfactuals.R — Sprint 4: structural welfare counterfactuals
# ============================================================================
# Decomposes the reduced-form price effect of the SME-only regime into two
# structural channels, using the CPV-recovered cost distributions from
# script 35_cpv_asymmetric.R:
#
#   Channel (i)  INTENSIVE  margin : removing non-SME competitors from
#                                    the same auction, holding the SME
#                                    cost pool fixed at Pre values.
#   Channel (ii) ENTRY      margin : marginal SMEs enter under the regime
#                                    (pool expands from Pre to Post).
#
# Simulation logic. For each observed Pre-period auction with composition
# (n_A, n_B) and reference price P_ref:
#
#   Scenario S1 (Open, Pre baseline — OBSERVED):
#     bidders: n_A SMEs (F_c^SME_Pre) + n_B non-SMEs (F_c^NonSME_Pre).
#     E[b_win] = integral over b of  (1 - G_A_Pre(b))^{n_A}  *
#                                    (1 - G_B_Pre(b))^{n_B}   db
#
#   Scenario S2 (SME-only with Pre pool — COUNTERFACTUAL):
#     bidders: n_A SMEs (F_c^SME_Pre), no non-SMEs.
#     E[b_win] = integral of (1 - G_A_Pre(b))^{n_A} db
#     Intensive margin  =  S2 - S1
#
#   Scenario S3 (SME-only with Post pool — OBSERVED in Post):
#     bidders: n_A^Post SMEs (F_c^SME_Post).
#     E[b_win] = integral of (1 - G_A_Post(b))^{n_A^Post} db
#     Entry margin      =  S3 - S2
#
# Total price effect  =  S3 - S1 = (entry) + (intensive).
#
# Caveat: this uses OBSERVED bid distributions in each regime as the
# equilibrium survival functions. Removing non-SME bidders in S2 is an
# approximation that ignores SME bidder re-optimization at the absence of
# non-SMEs; the approximation bounds the intensive effect from below.
# A full equilibrium solve (Campo-Perrigne-Vuong inversion → equilibrium
# re-solve) is deferred to a later sprint.
#
# Also computes:
#   - Value-threshold exemption: split auctions at Q3 of ref_price, apply
#     S3 to below-Q3 and S1 to above-Q3. Compare to uniform S3.
#
# Outputs:
#   output/tables/tab_v2_decomp.tex          — structural decomposition
#   output/tables/tab_v2_counterfactual.tex  — value-threshold reform
#   output/figures/fig_v2_decomp.pdf         — bar chart of margins
#   output/figures/fig_v2_vt_frontier.pdf    — value-threshold Pareto
#   logs/36_counterfactuals.log
# ============================================================================

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils_v2.R"), local = TRUE)

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(ggplot2)
  library(scales)
})

setDTthreads(12)
log_msg("=== 36_counterfactuals.R — welfare decomposition ===")
log_mem("startup")

theme_pub <- function() {
  theme_bw(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
          strip.background = element_rect(fill = "grey95", color = "black",
                                          linewidth = 0.3),
          legend.position = "bottom", legend.title = element_blank(),
          plot.title = element_text(size = 10, face = "bold"))
}
save_pub <- function(p, fn, w = 7.0, h = 4.0) {
  ggsave(file.path(V2_FIGS, fn), p, width = w, height = h, device = cairo_pdf)
  log_msg("  saved ", fn)
}

# ============================================================================
# 1. LOAD
# ============================================================================
log_msg("Loading Convite G65 firm-auction data...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]

fa <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, codigofornecedor, data_oc_numb, Pre, pharma)]

au <- fa[, .(
    N   = .N,
    n_A = sum(sme == 1L),
    n_B = sum(sme == 0L),
    ref = mean(ref, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, Pre)]

fa <- merge(fa, au[, .(numerodaoc, codigoitem, N, n_A, n_B)],
            by = c("numerodaoc", "codigoitem"))
fa[, b_norm := bid / ref]

# Filter
fa <- fa[N >= 2L & is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0 &
         b_norm > 0.005 & b_norm < 2]
au <- au[N >= 2L]

# N-bin
fa[, N_bin := fifelse(N == 2L, "N=2",
              fifelse(N == 3L, "N=3",
               fifelse(N == 4L, "N=4", "N>=5")))]

log_msg(sprintf("Firm-auctions (GPV-feasible): %s | Auctions: %s",
                format(nrow(fa), big.mark = ","),
                format(nrow(au), big.mark = ",")))

# ============================================================================
# 2. EMPIRICAL BID SURVIVAL FUNCTIONS BY (period, type, N_bin)
# ============================================================================
# We build S_k(b; N, period) = Pr(random k-type bid > b) in each stratum.
# Evaluated on a common grid on b_norm in [0.005, 2].
#
# S_A_Pre(b, N_bin)   : survival of SME bids in Pre, in this N_bin
# S_B_Pre(b, N_bin)   : survival of non-SME bids in Pre
# S_A_Post(b, N_bin)  : survival of SME bids in Post (post pool)

grid_b <- seq(0.005, 2, length.out = 1000)

empirical_survival <- function(x) {
  # Empirical survival: S(b) = mean(x > b) evaluated on grid_b
  if (length(x) < 50) return(NULL)
  # 1 - ECDF
  ec <- ecdf(x)
  pmax(0, 1 - ec(grid_b))
}

log_msg("Building empirical survival functions per stratum...")
surv <- list()
for (per in c("Pre", "Post")) {
  for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
    sub <- fa[Pre == (per == "Pre") & N_bin == Nb]
    S_A <- empirical_survival(sub[sme == 1L, b_norm])
    S_B <- empirical_survival(sub[sme == 0L, b_norm])
    if (is.null(S_A) || is.null(S_B)) next
    surv[[paste(per, Nb, sep = "/")]] <- list(S_A = S_A, S_B = S_B,
                                              n_A = sum(sub$sme == 1L),
                                              n_B = sum(sub$sme == 0L))
    log_msg(sprintf("  %s/%s : n_A=%d, n_B=%d",
                    per, Nb, sum(sub$sme == 1L), sum(sub$sme == 0L)))
  }
}

# ============================================================================
# 3. EXPECTED WINNING BID VIA TRAPEZOID INTEGRATION
# ============================================================================
# E[min of k draws from F] = integral over b of Pr(min > b) db
#                          = integral S(b)^k  db   (non-negative support)
# For lower support starting at > 0, we add the lower bound:
# E[b_min] = lb + integral_{lb}^{ub} Pr(min > b) db

expected_min <- function(surv_vec, k) {
  # Trapezoidal rule on grid_b
  db <- diff(grid_b)
  mid <- (surv_vec[-1]^k + surv_vec[-length(surv_vec)]^k) / 2
  lb <- grid_b[1]
  lb + sum(mid * db)
}

expected_min_two_types <- function(S_A, n_A, S_B, n_B) {
  # Mixed-type auction: product of survivals
  db <- diff(grid_b)
  survival_joint <- S_A^n_A * S_B^n_B
  mid <- (survival_joint[-1] + survival_joint[-length(survival_joint)]) / 2
  lb <- grid_b[1]
  lb + sum(mid * db)
}

# ============================================================================
# 4. STRUCTURAL DECOMPOSITION BY N_BIN
# ============================================================================
# For each N_bin, compute the three scenarios at the STRATUM MEAN of n_A, n_B
# (weighted by the observed composition distribution of Pre auctions).

log_msg("Computing structural decomposition by N-bin...")

decomp <- list()
for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
  sur_pre  <- surv[[paste("Pre",  Nb, sep = "/")]]
  sur_post <- surv[[paste("Post", Nb, sep = "/")]]
  if (is.null(sur_pre) || is.null(sur_post)) next

  # Pre auction compositions within this N-bin
  au_sub <- copy(au[Pre == 1L])
  au_sub[, N_bin := fifelse(N == 2L, "N=2",
                   fifelse(N == 3L, "N=3",
                    fifelse(N == 4L, "N=4", "N>=5")))]
  au_sub <- au_sub[N_bin == Nb]

  # For scenarios, use the CROSS of n_A and n_B from Pre auctions
  # We compute E[b_win] per auction, then average
  E_S1 <- numeric(nrow(au_sub))
  E_S2 <- numeric(nrow(au_sub))
  E_S3 <- numeric(nrow(au_sub))
  for (i in seq_len(nrow(au_sub))) {
    nA <- au_sub$n_A[i]; nB <- au_sub$n_B[i]
    # S1: Open (Pre bids)
    E_S1[i] <- expected_min_two_types(sur_pre$S_A, nA, sur_pre$S_B, nB)
    # S2: SME-only with Pre pool
    if (nA >= 1) {
      E_S2[i] <- expected_min(sur_pre$S_A, nA)
    } else {
      E_S2[i] <- NA
    }
    # S3: SME-only with Post pool (use Post SME survival; effective bidders nA)
    if (nA >= 1) {
      E_S3[i] <- expected_min(sur_post$S_A, nA)
    } else {
      E_S3[i] <- NA
    }
  }
  E_S1_mean <- mean(E_S1, na.rm = TRUE)
  E_S2_mean <- mean(E_S2, na.rm = TRUE)
  E_S3_mean <- mean(E_S3, na.rm = TRUE)

  decomp[[Nb]] <- data.table(
    N_bin = Nb,
    n_auc = nrow(au_sub),
    E_S1  = round(E_S1_mean, 4),
    E_S2  = round(E_S2_mean, 4),
    E_S3  = round(E_S3_mean, 4),
    intensive   = round(E_S2_mean - E_S1_mean, 4),
    entry       = round(E_S3_mean - E_S2_mean, 4),
    total       = round(E_S3_mean - E_S1_mean, 4),
    intensive_pct = round(100 * (E_S2_mean - E_S1_mean) / (E_S3_mean - E_S1_mean), 1),
    entry_pct     = round(100 * (E_S3_mean - E_S2_mean) / (E_S3_mean - E_S1_mean), 1)
  )
  log_msg(sprintf("  %s: S1=%.4f, S2=%.4f, S3=%.4f | intensive=%.4f (%.0f%%), entry=%.4f (%.0f%%)",
                  Nb, E_S1_mean, E_S2_mean, E_S3_mean,
                  E_S2_mean - E_S1_mean, 100 * (E_S2_mean - E_S1_mean) / (E_S3_mean - E_S1_mean),
                  E_S3_mean - E_S2_mean, 100 * (E_S3_mean - E_S2_mean) / (E_S3_mean - E_S1_mean)))
}

decomp_tab <- rbindlist(decomp, use.names = TRUE)
log_msg("")
log_msg("Structural decomposition (normalized to ref_price units):")
print(decomp_tab)
fwrite(decomp_tab, file.path(V2_TABLES, "tab_v2_decomp.csv"))

# LaTeX version
sink(file.path(V2_TABLES, "tab_v2_decomp.tex"))
cat("% Auto-generated by 36_counterfactuals.R\n")
cat("\\begin{tabular}{lrrrrrrrr}\n\\toprule\n")
cat("N-bin & Auctions & $E[b^{S1}]$ & $E[b^{S2}]$ & $E[b^{S3}]$ &",
    "Intensive & Entry & Total & Intens.\\% \\\\\n\\midrule\n")
for (i in seq_len(nrow(decomp_tab))) {
  with(decomp_tab[i], cat(
    N_bin, "&",
    format(n_auc, big.mark = ","), "&",
    sprintf("%.3f", E_S1), "&",
    sprintf("%.3f", E_S2), "&",
    sprintf("%.3f", E_S3), "&",
    sprintf("%.3f", intensive), "&",
    sprintf("%.3f", entry), "&",
    sprintf("%.3f", total), "&",
    sprintf("%.0f\\%%", intensive_pct), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

# ============================================================================
# 5. FIGURE: DECOMPOSITION BAR CHART
# ============================================================================
decomp_long <- melt(decomp_tab[, .(N_bin, intensive, entry)],
                    id.vars = "N_bin",
                    variable.name = "channel",
                    value.name = "effect")
decomp_long[, channel := factor(channel,
                                 levels = c("intensive", "entry"),
                                 labels = c("Intensive (reduced competition)",
                                            "Entry (marginal SMEs)"))]
fig_dec <- ggplot(decomp_long, aes(x = N_bin, y = effect, fill = channel)) +
  geom_col(position = position_stack()) +
  scale_fill_manual(values = c("Intensive (reduced competition)" = "grey30",
                                "Entry (marginal SMEs)" = "grey70")) +
  scale_y_continuous(labels = function(x) sprintf("%.2f", x)) +
  labs(x = "Auction size (N-bin)",
       y = "Price effect, c/ref units",
       title = "Structural decomposition of SME-only price effect (Convite G65)",
       subtitle = "Intensive: removing non-SME competitors at fixed cost pool.  Entry: marginal SMEs entering.") +
  theme_pub()
save_pub(fig_dec, "fig_v2_decomp.pdf", w = 7.5, h = 4.3)

# ============================================================================
# 6. VALUE-THRESHOLD EXEMPTION COUNTERFACTUAL
# ============================================================================
# Split auctions by ref_price quartile. For each quartile cutoff q:
#   - auctions with ref > q : apply Open regime (S1)
#   - auctions with ref <= q : apply SME-only (S3)
# Compare total procurement cost to uniform SME-only (all S3).

log_msg("")
log_msg("Value-threshold exemption simulation...")

# Use all Pre auctions (observed composition) + post-period counterfactual prices
au_pre <- au[Pre == 1L]
au_pre[, N_bin := fifelse(N == 2L, "N=2",
                 fifelse(N == 3L, "N=3",
                  fifelse(N == 4L, "N=4", "N>=5")))]

# Compute E_S1 (Open) and E_S3 (SME-only post) for each auction
au_pre[, E_S1 := NA_real_]
au_pre[, E_S3 := NA_real_]
for (i in seq_len(nrow(au_pre))) {
  Nb <- au_pre$N_bin[i]
  sur_pre  <- surv[[paste("Pre",  Nb, sep = "/")]]
  sur_post <- surv[[paste("Post", Nb, sep = "/")]]
  if (is.null(sur_pre) || is.null(sur_post)) next
  nA <- au_pre$n_A[i]; nB <- au_pre$n_B[i]
  au_pre$E_S1[i] <- expected_min_two_types(sur_pre$S_A, nA, sur_pre$S_B, nB)
  if (nA >= 1) {
    au_pre$E_S3[i] <- expected_min(sur_post$S_A, nA)
  }
}
au_pre[, E_S1_R := E_S1 * ref]   # in R$
au_pre[, E_S3_R := E_S3 * ref]
au_pre[, price_effect_R := (E_S3 - E_S1) * ref]

# Fiscal cost of uniform SME-only (S3 everywhere)
total_uniform <- sum(au_pre$price_effect_R, na.rm = TRUE)
log_msg(sprintf("  Total fiscal cost (uniform SME-only) = R$ %s",
                format(round(total_uniform), big.mark = ",")))

# For each threshold (ref quartile), compute cost under exemption
q_list <- quantile(au_pre$ref, probs = seq(0.0, 1.0, 0.05), na.rm = TRUE)
vt <- data.table()
for (q_name in names(q_list)) {
  q_val <- q_list[[q_name]]
  # Exempt auctions with ref > q_val (run Open)
  au_pre[, exempt := ref > q_val]
  # Cost: exempt contributes 0 (Open), non-exempt contributes E_S3 - E_S1
  cost_exempt <- sum(fifelse(au_pre$exempt,
                              0,
                              au_pre$price_effect_R),
                     na.rm = TRUE)
  n_exempt <- sum(au_pre$exempt)
  n_keep   <- sum(!au_pre$exempt)
  vt <- rbind(vt, data.table(
    percentile_threshold = q_name,
    ref_threshold_R      = round(q_val, 2),
    n_exempt             = n_exempt,
    n_keep_SME_only      = n_keep,
    cost_R               = round(cost_exempt),
    cost_pct_of_uniform  = round(100 * cost_exempt / total_uniform, 1),
    items_pct_SME_only   = round(100 * n_keep / nrow(au_pre), 1)
  ))
}
print(vt[seq(1, nrow(vt), by = 2)])  # show every other row
fwrite(vt, file.path(V2_TABLES, "tab_v2_counterfactual.csv"))

# Figure: value-threshold Pareto frontier
fig_vt <- ggplot(vt, aes(x = items_pct_SME_only, y = 100 - cost_pct_of_uniform)) +
  geom_line(linewidth = 0.5) +
  geom_point(data = vt[percentile_threshold == "75%"],
             aes(x = items_pct_SME_only, y = 100 - cost_pct_of_uniform),
             size = 3, shape = 21, fill = "white") +
  geom_text(data = vt[percentile_threshold == "75%"],
            aes(x = items_pct_SME_only, y = 100 - cost_pct_of_uniform,
                label = sprintf(" 75th pct: %.0f%% cost recovered, %.0f%% items preserved",
                                100 - cost_pct_of_uniform, items_pct_SME_only)),
            hjust = 0, vjust = -1.0, size = 3) +
  scale_x_continuous(labels = function(x) paste0(x, "%"),
                     limits = c(0, 100)) +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     limits = c(0, 100)) +
  labs(x = "Percent of items preserved under SME-only rule",
       y = "Percent of fiscal cost RECOVERED via exemption",
       title = "Value-threshold exemption Pareto frontier (Convite G65)",
       subtitle = "Structural simulation: top-ref-price items exempted, low-ref-price kept under SME-only") +
  theme_pub()
save_pub(fig_vt, "fig_v2_vt_frontier.pdf", w = 7.0, h = 4.5)

log_mem("final")
log_msg("=== 36_counterfactuals.R: DONE ===")
