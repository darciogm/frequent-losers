#  31_honest_did.R --- Honest DiD event study around first court order
#  Callaway-Sant'Anna (2021, JoE) + Borusyak-Jaravel-Spiess (2024, REStud)
#  + Rambachan-Roth (2023, REStud) HonestDiD sensitivity
#
#  Addresses Referee 2's concern that the TWFE event study in 30_referee_analyses.R
#  shows a large pre-trend (-0.43 between t=-5 and t=-1) and cannot be read as a
#  clean parallel-trends test. CS and BJS control for heterogeneous, staggered
#  adoption; HonestDiD bounds the post-treatment ATT under plausible pre-trend
#  violations.


suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(did)
  library(HonestDiD)
  library(ggplot2)
})
setFixest_nthreads(12L)
setDTthreads(12L)

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
source(file.path(.this_dir, "_macros.R"))

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v6-jpub-short/output"
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "tables"),  recursive = TRUE, showWarnings = FALSE)

# 1.  Build item-year panel
cat("Loading cache...\n")
dt <- readRDS("/tmp/v4_prepared.rds")
cat("  Rows:", nrow(dt), "\n")

# Winner-only, non-missing price
dt <- dt[po_firm_winner == 1 & !is.na(bid_price_log) & !is.na(year_n)]
cat("  After winner + non-missing price:", nrow(dt), "\n")

# First year of litigation for each item (NA if never litigated)
first_lit <- dt[purchase_type == 2, .(g = min(year_n, na.rm = TRUE)), by = item]
dt <- merge(dt, first_lit, by = "item", all.x = TRUE)
dt[is.na(g), g := 0L]   # did's convention: g = 0 for never-treated

# Item numeric id + modal PBU per item (for clustering-ish)
dt[, item_id_num := as.integer(as.factor(item))]
item_pbu_modal <- dt[, .(pbu_modal = as.integer(names(sort(table(pbu_code), decreasing = TRUE))[1])),
                     by = item_id_num]

# Collapse to item-year mean log price
panel <- dt[, .(bid_price_log = mean(bid_price_log, na.rm = TRUE),
                n_obs = .N,
                g     = first(g)),
            keyby = .(item_id_num, year_n)]
panel <- merge(panel, item_pbu_modal, by = "item_id_num", all.x = TRUE)

# Restrict to items that ever appear pre- AND post-2010 (avoids singletons)
it_years <- panel[, .(n_years = uniqueN(year_n)), by = item_id_num]
panel    <- panel[item_id_num %in% it_years[n_years >= 3, item_id_num]]
cat("  Panel:", nrow(panel), "item-years;",
    uniqueN(panel$item_id_num), "items;",
    uniqueN(panel[g > 0, item_id_num]), "treated items;",
    uniqueN(panel[g == 0, item_id_num]), "never-treated items.\n")

# 2.  Callaway-Sant'Anna (2021) ATT(g,t) + dynamic aggregation
cat("\n-- Callaway-Sant'Anna ATT(g,t) --\n")
att_cs <- att_gt(
  yname         = "bid_price_log",
  tname         = "year_n",
  idname        = "item_id_num",
  gname         = "g",
  xformla       = ~1,
  data          = as.data.frame(panel),
  control_group = "nevertreated",
  allow_unbalanced_panel = TRUE,
  est_method    = "dr",
  clustervars   = "pbu_modal"
)

dyn_cs <- aggte(att_cs, type = "dynamic", min_e = -5, max_e = 5, na.rm = TRUE)
cat("  Overall dynamic ATT (post, CS):", round(dyn_cs$overall.att, 4),
    "(SE", round(dyn_cs$overall.se, 4), ")\n")

cs_df <- data.table(
  event_time = dyn_cs$egt,
  coef       = dyn_cs$att.egt,
  se         = dyn_cs$se.egt,
  method     = "Callaway-Sant'Anna"
)
cs_df[, `:=`(ci_lo = coef - 1.96 * se, ci_hi = coef + 1.96 * se)]

# 3.  Borusyak-Jaravel-Spiess (2024) imputation estimator
cat("\n-- BJS imputation via fixest::feols (DID2S-style) --\n")
# First stage: on untreated obs, predict outcome with unit + time FE
panel[, treated := as.integer(g > 0 & year_n >= g)]
panel[, event_time := fifelse(g == 0, NA_integer_, as.integer(year_n - g))]

m_y0 <- feols(bid_price_log ~ 1 | item_id_num + year_n,
              data = panel[treated == 0L])
panel[, y0_hat := predict(m_y0, newdata = panel)]
panel[, tau    := bid_price_log - y0_hat]

# Event-time averages of tau on treated
bjs_df <- panel[!is.na(event_time) & event_time >= -5 & event_time <= 5,
                .(coef = mean(tau, na.rm = TRUE),
                  se   = sd(tau, na.rm = TRUE) / sqrt(.N)),
                keyby = event_time]
setnames(bjs_df, "event_time", "event_time")
bjs_df[, method := "Borusyak-Jaravel-Spiess (imputation)"]
bjs_df[, `:=`(ci_lo = coef - 1.96 * se, ci_hi = coef + 1.96 * se)]

# 4.  TWFE (for comparison with existing Figure A.?)
cat("\n-- TWFE event study for reference --\n")
panel_es <- panel[!is.na(event_time) & event_time >= -5 & event_time <= 5]
panel_es[, et_f := relevel(factor(event_time), ref = "-1")]
m_twfe <- feols(bid_price_log ~ et_f | item_id_num + year_n,
                data = panel_es, cluster = ~item_id_num)
twfe_df <- data.table(
  event_time = as.integer(gsub("et_f", "", names(coef(m_twfe)))),
  coef       = coef(m_twfe),
  se         = sqrt(diag(vcov(m_twfe)))
)
twfe_df <- rbind(twfe_df, data.table(event_time = -1L, coef = 0, se = 0))
twfe_df[, method := "Two-way FE (reference)"]
twfe_df[, `:=`(ci_lo = coef - 1.96 * se, ci_hi = coef + 1.96 * se)]

# 5.  Combine + plot
combined <- rbindlist(list(bjs_df, cs_df, twfe_df), use.names = TRUE, fill = TRUE)
combined[, method := factor(method, levels = c("Two-way FE (naive, for reference)",
                                               "Callaway-Sant'Anna (never-treated control)",
                                               "Borusyak-Jaravel-Spiess (imputation)"))]
# Relabel to match the factor levels
combined[method == "Two-way FE (reference)",
         method := factor("Two-way FE (naive, for reference)",
                          levels = levels(combined$method))]
combined[method == "Callaway-Sant'Anna",
         method := factor("Callaway-Sant'Anna (never-treated control)",
                          levels = levels(combined$method))]
fwrite(combined, file.path(OUT, "tables", "tab_es_honest.csv"))

p <- ggplot(combined, aes(x = event_time, y = coef,
                          color = method, shape = method, fill = method)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray60") +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi),
              alpha = 0.15, color = NA,
              data = combined[method == "Borusyak-Jaravel-Spiess (imputation)"]) +
  geom_line(linewidth = 0.5, alpha = 0.85) +
  geom_point(size = 2.2) +
  scale_color_manual(values = c(
    "Two-way FE (naive, for reference)"          = "gray60",
    "Callaway-Sant'Anna (never-treated control)" = "firebrick",
    "Borusyak-Jaravel-Spiess (imputation)"       = "black")) +
  scale_fill_manual(values  = c(
    "Two-way FE (naive, for reference)"          = "gray60",
    "Callaway-Sant'Anna (never-treated control)" = "firebrick",
    "Borusyak-Jaravel-Spiess (imputation)"       = "black")) +
  scale_shape_manual(values = c(
    "Two-way FE (naive, for reference)"          = 1,
    "Callaway-Sant'Anna (never-treated control)" = 17,
    "Borusyak-Jaravel-Spiess (imputation)"       = 16)) +
  scale_x_continuous(breaks = -5:5) +
  coord_cartesian(ylim = c(-0.5, 0.35)) +
  labs(x = "Years Relative to First Court Order",
       y = "Log Negotiated Price (relative to t = -1)",
       color = NULL, shape = NULL, fill = NULL,
       caption = "BJS preferred (shaded 95% CI). CS with never-treated control is noisier because never-litigated items are a systematically different comparison group.") +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom",
        legend.direction = "vertical",
        panel.grid.minor = element_blank())

ggsave(file.path(OUT, "figures", "fig_event_study_honest.pdf"),
       p, width = 6.5, height = 4.2, device = cairo_pdf)
cat("  Saved: fig_event_study_honest.pdf\n")

# 6.  HonestDiD sensitivity (Rambachan-Roth 2023)
cat("\n-- HonestDiD sensitivity on CS estimates --\n")
betahat  <- dyn_cs$att.egt
sigma    <- diag(dyn_cs$se.egt^2)   # diagonal approximation (conservative)
numPre   <- sum(dyn_cs$egt < 0)
numPost  <- sum(dyn_cs$egt >= 0)

# Smoothness restrictions: allow up to Mbar * max-pre-slope in post-periods
mbars <- c(0, 0.5, 1, 2)
# HonestDiD wants l_vec length == numPostPeriods, weighted over post periods
l_vec_att0 <- cbind(c(1, rep(0, numPost - 1)))   # ATT at t = 0
sens <- tryCatch({
  HonestDiD::createSensitivityResults_relativeMagnitudes(
    betahat        = betahat,
    sigma          = sigma,
    numPrePeriods  = numPre,
    numPostPeriods = numPost,
    Mbarvec        = mbars,
    l_vec          = l_vec_att0
  )
}, error = function(e) {
  cat("  HonestDiD skipped:", conditionMessage(e), "\n")
  NULL
})

if (!is.null(sens)) {
  fwrite(as.data.table(sens), file.path(OUT, "tables", "tab_honestdid.csv"))
  cat("  HonestDiD (relative magnitudes, ATT at t=0):\n")
  print(sens)
}

# 7.  Text summary for §A.5 rewrite
summary_txt <- sprintf(
"Honest DiD summary (item-year panel, winner-only obs).

Panel: %d items (%d treated, %d never-treated); %d item-years.

Callaway-Sant'Anna (2021), never-treated control, clustered at modal-PBU:
  Overall post-treatment ATT: %.3f (SE %.3f)
  Event-time 0 ATT: %.3f (SE %.3f)
  Event-time +5 ATT: %.3f (SE %.3f)
  Pre-period max |coef|: %.3f  (parallel-trends stress-test)

Borusyak-Jaravel-Spiess (2024), imputation estimator:
  Event-time 0 ATT: %.3f (SE %.3f)
  Event-time +5 ATT: %.3f (SE %.3f)

TWFE (for reference): event-time 0 = %.3f; event-time +5 = %.3f.
",
uniqueN(panel$item_id_num), uniqueN(panel[g > 0, item_id_num]),
uniqueN(panel[g == 0, item_id_num]), nrow(panel),
dyn_cs$overall.att, dyn_cs$overall.se,
cs_df[event_time == 0, coef], cs_df[event_time == 0, se],
cs_df[event_time == 5, coef], cs_df[event_time == 5, se],
max(abs(cs_df[event_time < 0, coef])),
bjs_df[event_time == 0, coef], bjs_df[event_time == 0, se],
bjs_df[event_time == 5, coef], bjs_df[event_time == 5, se],
twfe_df[event_time == 0, coef],
twfe_df[event_time == 5, coef]
)
writeLines(summary_txt, file.path(OUT, "tables", "honestdid_summary.txt"))
cat(summary_txt)


# Emit macros for the manuscript layer (BJS event-study at t=0 and t=+5)
macros <- list()
b0 <- bjs_df[event_time == 0, coef]
s0 <- bjs_df[event_time == 0, se]
b5 <- bjs_df[event_time == 5, coef]
s5 <- bjs_df[event_time == 5, se]
if (length(b0) == 1 && !is.na(b0)) {
  macros$bjsETzero    <- bp_fmt(b0, 3)
  macros$bjsETzeroSE  <- bp_fmt(s0, 3)
  macros$bjsETzeroPct <- bp_fmt_pct((exp(b0) - 1) * 100, 1)
}
if (length(b5) == 1 && !is.na(b5)) {
  macros$bjsETfive    <- bp_fmt(b5, 3)
  macros$bjsETfiveSE  <- bp_fmt(s5, 3)
  macros$bjsETfivePct <- bp_fmt_pct((exp(b5) - 1) * 100, 1)
}
pre_max <- max(abs(bjs_df[event_time < 0, coef]), na.rm = TRUE)
if (is.finite(pre_max)) macros$bjsPreMaxAbs <- bp_fmt(pre_max, 3)
if (length(macros) > 0) bp_macros_emit("31_honest_did", macros)

cat("\n31_honest_did.R complete\n")
