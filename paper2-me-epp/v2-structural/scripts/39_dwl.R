# ============================================================================
# 39_dwl.R — Sprint 8: deadweight loss from the SME-only restriction
# ============================================================================
# Using the CPV-recovered cost distributions F_c^A (SME) and F_c^B (NonSME)
# from Convite G65 Pre-period, compute the allocative deadweight loss of
# the SME-only regime:
#
#     DWL per auction = E[ min_{i in SME}  c_i ]
#                     - E[ min_{i in ALL}  c_i ]
#
# i.e., the excess resource cost incurred because the lowest-cost bidder
# (who might be a non-SME) is excluded from Group-65 auctions under the
# regime.
#
# By construction DWL >= 0 (excluding bidders can only raise min-cost).
# Analytically, with n_A SMEs + n_B non-SMEs:
#
#     E[c_open]    = integral_{underline c}^{overline c} (1-F_A(c))^{n_A}
#                                                        (1-F_B(c))^{n_B} dc
#                  + underline c
#     E[c_sme]     = integral_{underline c}^{overline c} (1-F_A(c))^{n_A}  dc
#                  + underline c
#     DWL per auc  = E[c_sme] - E[c_open]  (in c/ref units; multiply by ref)
#
# Decomposition of the fiscal cost:
#     Total fiscal cost    = E[b_sme_win] - E[b_open_win]
#     DWL (resource loss)  = E[c_sme_win] - E[c_open_win]
#     Transfer (rents)     = Fiscal cost - DWL   (= change in equilibrium
#                                                  markup from Open to SME-only)
#
# Outputs:
#   output/tables/tab_v2_dwl.tex         — DWL in R$ and % of procurement
#   output/tables/tab_v2_dwl.csv         — per-auction and aggregate
#   output/figures/fig_v2_dwl_by_N.pdf   — DWL decomposition by N-bin
#   logs/39_dwl.log
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
log_msg("=== 39_dwl.R — deadweight loss calculation ===")
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
# 1. LOAD CPV PSEUDO-COSTS AND BID-LEVEL CONVITE DATA
# ============================================================================
log_msg("Loading CPV pseudo-costs and bid-level Convite G65...")
cpv <- as.data.table(read_parquet(file.path(V2_DATA, "convite_cpv_costs.parquet")))
# Keep clean Pre-period observations (primitives we trust most)
clean_pre <- cpv[period_lbl == "Pre" & is.finite(c_norm) &
                 c_norm > 0.001 & c_norm < 1.5]
log_msg(sprintf("  clean Pre pseudo-costs: %s (SME=%d, NonSME=%d)",
                format(nrow(clean_pre), big.mark = ","),
                sum(clean_pre$sme_lbl == "SME"),
                sum(clean_pre$sme_lbl == "NonSME")))

# Bid-level for auction compositions and observed fiscal cost
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]

fa <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, codigofornecedor, Pre, pharma)]

au <- fa[, .(
    N   = .N,
    n_A = sum(sme == 1L),
    n_B = sum(sme == 0L),
    ref = mean(ref, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, Pre)]
au[, N_bin := fifelse(N == 2L, "N=2",
              fifelse(N == 3L, "N=3",
               fifelse(N == 4L, "N=4", "N>=5")))]
au <- au[N >= 2L & is.finite(ref) & ref > 0 & ref < 1e6]
au_pre <- au[Pre == 1L]
log_msg(sprintf("  Pre auctions with valid composition+ref: %s",
                format(nrow(au_pre), big.mark = ",")))

# ============================================================================
# 2. EMPIRICAL SURVIVAL FUNCTIONS OF c_norm (PRIMITIVES)
# ============================================================================
# Build S_A(c) = Pr(c_SME > c) and S_B(c) = Pr(c_NonSME > c) from clean
# CPV pseudo-costs at Pre period. Use a fine grid on c in (0, 1.5).

grid_c <- seq(0.001, 1.5, length.out = 1000)

survival_from <- function(c_vec) {
  # returns S(c) = 1 - ECDF(c) evaluated on grid_c
  ec <- ecdf(c_vec)
  pmax(0, 1 - ec(grid_c))
}

S_A <- survival_from(clean_pre[sme_lbl == "SME",    c_norm])
S_B <- survival_from(clean_pre[sme_lbl == "NonSME", c_norm])
log_msg(sprintf("  S_A at c=0.3: %.3f | S_B at c=0.3: %.3f (similar → similar distributions)",
                S_A[findInterval(0.3, grid_c)],
                S_B[findInterval(0.3, grid_c)]))

# ============================================================================
# 3. EXPECTED MIN-COST (ANALYTICAL) PER AUCTION
# ============================================================================
# E[c_open_win] = lower_bound + integral over c in [lb, ub] of
#                 (1-F_A(c))^{n_A} (1-F_B(c))^{n_B} dc
#               = grid_c[1] + sum over grid of S_A^{n_A} * S_B^{n_B} * dc

dc <- diff(grid_c)
lb <- grid_c[1]

expected_open <- function(n_A, n_B) {
  joint_S <- S_A^n_A * S_B^n_B
  mid <- (joint_S[-1] + joint_S[-length(joint_S)]) / 2
  lb + sum(mid * dc)
}

expected_sme_only <- function(n_A) {
  if (n_A < 1) return(NA_real_)
  sS <- S_A^n_A
  mid <- (sS[-1] + sS[-length(sS)]) / 2
  lb + sum(mid * dc)
}

log_msg("Computing per-auction expected min-cost under Open vs SME-only...")

au_pre[, E_c_open := mapply(expected_open, n_A, n_B)]
au_pre[, E_c_sme  := mapply(function(nA) expected_sme_only(nA), n_A)]
au_pre[, DWL_norm := E_c_sme - E_c_open]          # c/ref units
au_pre[, DWL_R    := DWL_norm * ref]              # R$ units

# Validation: DWL should always be ≥ 0
n_neg <- sum(au_pre$DWL_norm < -1e-6, na.rm = TRUE)
log_msg(sprintf("  DWL violation (DWL<0): %d of %d auctions (%.3f%%)",
                n_neg, nrow(au_pre), 100 * n_neg / nrow(au_pre)))

# ============================================================================
# 4. FISCAL COST (same procedure, bids instead of costs)
# ============================================================================
# We computed fiscal cost in 36_counterfactuals.R; reuse the same logic
# here so the decomposition is internally consistent. Use observed bid
# survival by type.

fa[, b_norm := bid / ref]
fa[, N := .N, by = .(numerodaoc, codigoitem)]
fa <- fa[N >= 2L & is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0 &
         b_norm > 0.005 & b_norm < 2]

b_A_pre <- fa[Pre == 1L & sme == 1L, b_norm]
b_B_pre <- fa[Pre == 1L & sme == 0L, b_norm]

SB_A <- survival_from(b_A_pre)
SB_B <- survival_from(b_B_pre)

expected_open_bid <- function(n_A, n_B) {
  joint <- SB_A^n_A * SB_B^n_B
  mid   <- (joint[-1] + joint[-length(joint)]) / 2
  lb + sum(mid * dc)
}
expected_sme_bid  <- function(n_A) {
  if (n_A < 1) return(NA_real_)
  s <- SB_A^n_A
  mid <- (s[-1] + s[-length(s)]) / 2
  lb + sum(mid * dc)
}
au_pre[, E_b_open := mapply(expected_open_bid, n_A, n_B)]
au_pre[, E_b_sme  := mapply(function(nA) expected_sme_bid(nA), n_A)]

au_pre[, fiscal_norm := E_b_sme - E_b_open]
au_pre[, fiscal_R    := fiscal_norm * ref]
# Rent change = Δ(winner profit) = Δ(b_win - c_win) = Fiscal - DWL
# Under SME-only, SMEs compete symmetrically → smaller markups → rents fall.
# If rent_change_R < 0, winners lose surplus (in addition to buyer's fiscal cost).
# Resource cost equality: DWL = Fiscal - rent_change = fiscal + (−rent_change_R).
au_pre[, rent_change_R := fiscal_R - DWL_R]

# ============================================================================
# 5. AGGREGATION
# ============================================================================
total <- au_pre[is.finite(DWL_R) & is.finite(fiscal_R), .(
    n_auc          = .N,
    proc_value_R   = round(sum(ref)),
    fiscal_R       = round(sum(fiscal_R)),
    DWL_R          = round(sum(DWL_R)),
    rent_change_R  = round(sum(rent_change_R)),
    DWL_pct_proc   = round(100 * sum(DWL_R) / sum(ref), 2),
    DWL_pct_fiscal = round(100 * sum(DWL_R) / sum(fiscal_R), 1),
    rent_pct_fiscal = round(100 * sum(rent_change_R) / sum(fiscal_R), 1)
  )]
log_msg("")
log_msg("AGGREGATE DWL DECOMPOSITION (Convite G65, Pre-period, R$):")
print(total)
log_msg("")
log_msg("WELFARE ACCOUNTING under the SME-only rule:")
log_msg(sprintf("  Procurement value (baseline):    R$ %s (over %s auctions, 18 months)",
                format(total$proc_value_R, big.mark = ","),
                format(total$n_auc, big.mark = ",")))
log_msg(sprintf("  Buyer's fiscal cost (extra paid): R$ %s (%.1f%% of procurement)",
                format(total$fiscal_R, big.mark = ","),
                100 * total$fiscal_R / total$proc_value_R))
log_msg(sprintf("  Winner's rent change:             R$ %s (%+.1f%% of fiscal)",
                format(total$rent_change_R, big.mark = ","),
                total$rent_pct_fiscal))
log_msg(sprintf("  Deadweight loss (total social):   R$ %s (%.2f%% of procurement)",
                format(total$DWL_R, big.mark = ","),
                total$DWL_pct_proc))
log_msg(sprintf("  Resource-cost identity: DWL = fiscal - rent change = %s",
                format(total$fiscal_R - total$rent_change_R, big.mark = ",")))

# Break down by N-bin
by_N <- au_pre[is.finite(DWL_R) & is.finite(fiscal_R), .(
    n_auc         = .N,
    proc_R        = round(sum(ref)),
    fiscal_R      = round(sum(fiscal_R)),
    DWL_R         = round(sum(DWL_R)),
    rent_change_R = round(sum(rent_change_R)),
    DWL_pct_fiscal = round(100 * sum(DWL_R) / sum(fiscal_R), 1)
  ), by = N_bin][order(N_bin)]
log_msg("")
log_msg("By auction size:")
print(by_N)
fwrite(by_N,  file.path(V2_TABLES, "tab_v2_dwl_by_n.csv"))
fwrite(total, file.path(V2_TABLES, "tab_v2_dwl_aggregate.csv"))

# ============================================================================
# 6. LaTeX TABLE
# ============================================================================
USD_RATE <- 3.50  # paper's sample-period reference
sink(file.path(V2_TABLES, "tab_v2_dwl.tex"))
cat("% Auto-generated by 39_dwl.R\n")
cat("\\begin{tabular}{lrrrrrr}\n\\toprule\n")
cat(" & Auctions & Proc.\\ value & Fiscal cost & Deadweight loss & Transfer & DWL/Fiscal \\\\\n")
cat(" & & (R\\\\$) & (R\\\\$) & (R\\\\$ / US\\\\$) & (R\\\\$) & \\\\\n\\midrule\n")

fmt <- function(x) format(x, big.mark = ",", scientific = FALSE)
cat("\\textbf{Total (Convite G65 Pre)} &",
    fmt(total$n_auc), "&",
    fmt(total$proc_value_R), "&",
    fmt(total$fiscal_R), "&",
    paste0(fmt(total$DWL_R), " / ", fmt(round(total$DWL_R / USD_RATE))), "&",
    fmt(total$rent_change_R), "&",
    paste0(total$DWL_pct_fiscal, "\\%"), "\\\\\n")

cat("\\midrule\n\\textit{By auction size:} & & & & & & \\\\\n")
for (i in seq_len(nrow(by_N))) {
  with(by_N[i], cat(
    N_bin, "&",
    fmt(n_auc), "&",
    fmt(proc_R), "&",
    fmt(fiscal_R), "&",
    paste0(fmt(DWL_R), " / ", fmt(round(DWL_R / USD_RATE))), "&",
    fmt(rent_change_R), "&",
    paste0(DWL_pct_fiscal, "\\%"), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()
log_msg("Saved LaTeX table: tab_v2_dwl.tex")

# ============================================================================
# 7. FIGURE: welfare decomposition by N-bin
# ============================================================================
# For plotting, stack fiscal (what buyer pays) and (-rent_change) (what
# winners lose) — these two together sum to DWL.
fig_df <- by_N[, .(N_bin,
                   fiscal = fiscal_R,
                   rent_loss = -rent_change_R)]  # positive = winners lose
fig_dwl <- ggplot(melt(fig_df, id.vars = "N_bin",
                       variable.name = "component", value.name = "R"),
                  aes(x = N_bin, y = R / 1e3, fill = component)) +
  geom_col(position = position_stack()) +
  scale_fill_manual(values = c("fiscal" = "grey25", "rent_loss" = "grey70"),
                    labels = c("Buyer's fiscal cost",
                               "Winner's rent loss")) +
  scale_y_continuous(labels = function(x) paste0("R$", round(x), "k")) +
  labs(x = "Auction size (N-bin)",
       y = "Amount (R$ thousands)",
       title = "Deadweight loss decomposition by auction size (Convite G65)",
       subtitle = "DWL = Buyer's extra payment + Winners' lost rents (symmetric SME competition)") +
  theme_pub()
save_pub(fig_dwl, "fig_v2_dwl_by_N.pdf", w = 7.0, h = 4.2)

log_mem("final")
log_msg("=== 39_dwl.R: DONE ===")
