# ============================================================================
# 16_regime_test.R — Regime test formalization (NEW for v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# (a) Minimal bid-distribution model: simulate 2 regimes [R2.7]
#     Regime 1 (complementary): U[b_bar, b_bar + delta]
#     Regime 2 (coordinated): N(mu_c, sigma_c^2) with sigma_c < sigma_genuine
# (b) Oversight heterogeneity: PBU size, municipal vs state [R2.7]
# ============================================================================

cat("=== 16_regime_test.R: Regime test formalization ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

regime_results <- list()

# ============================================================================
# (a) Bid-distribution model simulation
# ============================================================================

cat("  (a) Simulated bid densities...\n")

set.seed(42)
n_sim <- 10000

# Parameters calibrated from empirical data
# Genuine bids: log-normal around winning price
genuine_mean <- 0  # in log-deviation from winning price
genuine_sd   <- 0.30

# Regime 1 (complementary): uniform above winning price
r1_lower <- 0.05  # 5% above
r1_upper <- 1.50  # up to 150% above

# Regime 2 (coordinated): normal, tighter around winning price
r2_mean <- 0.10   # 10% above
r2_sd   <- 0.08   # low dispersion

# Simulate
sim_genuine <- rnorm(n_sim, genuine_mean, genuine_sd)
sim_regime1 <- runif(n_sim, r1_lower, r1_upper)
sim_regime2 <- rnorm(n_sim, r2_mean, r2_sd)

sim_data <- rbind(
  data.table(spread = sim_genuine, type = "Genuine bidders"),
  data.table(spread = sim_regime1, type = "Regime 1 (complementary)"),
  data.table(spread = sim_regime2, type = "Regime 2 (coordinated)")
)

# Plot simulated densities
p_sim <- ggplot(sim_data, aes(x = spread, fill = type, color = type)) +
  geom_density(alpha = 0.3, linewidth = 0.7) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray40") +
  scale_x_continuous(limits = c(-1, 2),
                     labels = scales::percent_format(accuracy = 1)) +
  labs(x = "Bid Spread: (Bid - Winning) / Winning",
       y = "Density") +
  theme_pub() +
  theme(legend.position = "bottom")

# If empirical data exists, overlay
bl_spread_file <- file.path(DATA_V4, "fl_cover_bid_spread.parquet")
if (!file.exists(bl_spread_file)) {
  bl_spread_file <- file.path(.v4_dir, "..", "v3", "data", "processed", "fl_cover_bid_spread.parquet")
}

if (file.exists(bl_spread_file)) {
  fl_spread <- as.data.table(read_parquet(bl_spread_file))
  fl_emp <- fl_spread[cover_bid_spread > -0.5 & cover_bid_spread < 2,
                       .(spread = cover_bid_spread, type = "FL empirical")]

  sim_data_emp <- rbind(sim_data, fl_emp)

  p_sim <- ggplot(sim_data_emp, aes(x = spread, color = type)) +
    geom_density(linewidth = 0.7, alpha = 0.4) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray40") +
    scale_x_continuous(limits = c(-0.5, 2),
                       labels = scales::percent_format(accuracy = 1)) +
    labs(x = "Bid Spread: (Bid - Winning) / Winning", y = "Density") +
    theme_pub() +
    theme(legend.position = "bottom")

  cat("  Added empirical FL spread overlay.\n")
}

save_pub(p_sim, "fig_regime_densities.pdf")
regime_results[["simulation"]] <- list(
  genuine_sd = genuine_sd, r1_range = c(r1_lower, r1_upper),
  r2_mean = r2_mean, r2_sd = r2_sd
)

# ============================================================================
# (b) Oversight heterogeneity
# ============================================================================

cat("  (b) Oversight heterogeneity...\n")

d_price <- dt[!is.na(lneg_price)]

# By PBU size quartile (larger PBUs -> more oversight)
oversight_results <- list()
for (q_val in 1:4) {
  d_q <- d_price[pbu_size_q == q_val]
  if (nrow(d_q) > 100) {
    m_q <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f,
            data = d_q, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )
    if (!is.null(m_q)) {
      oversight_results[[paste0("pbu_q", q_val)]] <- list(
        quartile = q_val,
        coef = coef(m_q)["losers"],
        se = sqrt(vcov(m_q)["losers", "losers"]),
        n = m_q$nobs
      )
      cat(sprintf("    PBU size Q%d: coef=%.4f (%.4f), N=%s\n",
                  q_val, coef(m_q)["losers"],
                  sqrt(vcov(m_q)["losers", "losers"]),
                  pfmt_int(m_q$nobs)))
    }
  }
}

# By procedure type (pregao more transparent than convite)
m_pregao <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
                  data = d_price[pregao == 1L], cluster = ~item_f, fixef.rm = "none")
m_convite <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
                   data = d_price[convite == 1L], cluster = ~item_f, fixef.rm = "none")

oversight_results[["pregao"]] <- list(
  coef = coef(m_pregao)["losers"],
  se = sqrt(vcov(m_pregao)["losers", "losers"]),
  n = m_pregao$nobs
)
oversight_results[["convite"]] <- list(
  coef = coef(m_convite)["losers"],
  se = sqrt(vcov(m_convite)["losers", "losers"]),
  n = m_convite$nobs
)

regime_results[["oversight"]] <- oversight_results

# Write oversight table
cat("  Writing tab_regime_oversight.tex...\n")

ov_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{FL Price Effect by Oversight Proxy}",
  "\\label{tab:regime_oversight}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  "Sub-sample & Coefficient & SE & N \\\\", "\\midrule",
  "\\textit{By PBU size quartile:} & & & \\\\"
)

for (q_val in 1:4) {
  key <- paste0("pbu_q", q_val)
  if (!is.null(oversight_results[[key]])) {
    r <- oversight_results[[key]]
    p <- 2 * pnorm(-abs(r$coef / r$se))
    ov_lines <- c(ov_lines, sprintf(
      "\\quad Q%d (%s oversight) & %s%s & (%s) & %s \\\\",
      q_val, if (q_val <= 2) "lower" else "higher",
      pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)))
  }
}

ov_lines <- c(ov_lines, "\\midrule",
  "\\textit{By procedure type:} & & & \\\\")

for (proc in c("pregao", "convite")) {
  r <- oversight_results[[proc]]
  if (!is.null(r)) {
    p <- 2 * pnorm(-abs(r$coef / r$se))
    lbl <- if (proc == "pregao") "Preg\\~{a}o (electronic, more transparent)" else
      "Convite (sealed-bid, less transparent)"
    ov_lines <- c(ov_lines, sprintf(
      "\\quad %s & %s%s & (%s) & %s \\\\",
      lbl, pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)))
  }
}

ov_lines <- c(ov_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} If FL coefficient is smaller under higher oversight,",
  "this is consistent with the regime model where detection probability",
  "$\\theta$ constrains cartel behavior. Item and year FE (PBU FE for procedure split).",
  "SE clustered at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(ov_lines, file.path(OUT_TAB, "tab_regime_oversight.tex"))

# Winner HHI distribution figure
if (file.exists(NETWORK_CACHE_V4)) {
  cat("  Creating fig_network_hhi.pdf...\n")
  network <- readRDS(NETWORK_CACHE_V4)
  fl_metrics <- network$fl_metrics

  p_hhi <- ggplot(fl_metrics[winner_hhi > 0], aes(x = winner_hhi)) +
    geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
    geom_vline(xintercept = network$hhi_median, linetype = "dashed",
               color = "black", linewidth = 0.7) +
    annotate("text", x = network$hhi_median, y = Inf, vjust = 2, hjust = -0.1,
             label = paste0("Median = ", round(network$hhi_median, 3)), size = 3) +
    labs(x = "Winner HHI (concentration of winners in FL firm's tenders)",
         y = "Number of FL Firms") +
    theme_pub()
  save_pub(p_hhi, "fig_network_hhi.pdf")
}

# ============================================================================
# Save
# ============================================================================

saveRDS(regime_results, REGIME_CACHE_V4)
cat("  Regime test results saved:", REGIME_CACHE_V4, "\n")
cat("  Done.\n")
