#  35_figure_decomposition.R --- Three-channel decomposition table + figure.
#
#  Wave 3 (T4.1 / T4.2 / F.1 / F.2). Refits the four-spec cascade
#    (1) baseline   bid_price_log ~ urgent | item + year + PBU
#    (2) + log qty  bid_price_log ~ urgent + bid_qty_log | ...           -- C1 absorbed
#    (3) + firm FE  bid_price_log ~ urgent           | ... + firm_f      -- C3 selection absorbed
#    (4) + both     bid_price_log ~ urgent + bid_qty_log | ... + firm_f  -- residual
#  for two comparison levels: urgent-vs-ordinary (Tabela tab_three_channel_uo)
#  and litigated-vs-administrative within urgent (Tabela tab_three_channel_utg).
#
#  Outputs:
#    output/tables/tab_three_channel_uo.tex   (T4.1, with caption + label)
#    output/tables/tab_three_channel_utg.tex  (T4.2, with caption + label)
#    output/figures/fig_three_channel_cascade.pdf  (F.1, the new headline figure)
#    output/figures/fig_qty_ratio_density.pdf      (F.2, raw distributional)


suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
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

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v7-r2round1/output"
dir.create(file.path(OUT, "tables"),  recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)

cat("Loading cache...\n")
dt <- readRDS("/tmp/v4_prepared.rds")

# Sample 1: urgent vs ordinary (winners, items with both, both qty + firm_id available)
d_uo <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
           !is.na(bid_price_log) & !is.na(bid_qty_log) & !is.na(firm_id)]
d_uo[, firm_f := as.factor(firm_id)]
cat(sprintf("  Urgent-vs-Ord sample: %d obs, %d items, %d firms\n",
            nrow(d_uo), uniqueN(d_uo$item), uniqueN(d_uo$firm_f)))

# Sample 2: UTG (urgent only, items with both admin and litigated)
d_utg <- dt[has_admin == TRUE & has_litigated == TRUE & urgent == 1L &
            po_firm_winner == 1L & !is.na(bid_price_log) & !is.na(bid_qty_log) & !is.na(firm_id)]
d_utg[, firm_f := as.factor(firm_id)]
cat(sprintf("  UTG sample: %d obs, %d items, %d firms\n",
            nrow(d_utg), uniqueN(d_utg$item), uniqueN(d_utg$firm_f)))


# T4.1 -- Cascade for urgent-vs-ordinary
cat("\n-- T4.1 Three-channel cascade (urgent-vs-ord) --\n")
m_uo_1 <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                data = d_uo, cluster = ~pbu_id)
m_uo_2 <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                data = d_uo, cluster = ~pbu_id)
m_uo_3 <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id + firm_f,
                data = d_uo, cluster = ~pbu_id)
m_uo_4 <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id + firm_f,
                data = d_uo, cluster = ~pbu_id)

extract_uo <- function(m, lab) {
  b <- unname(coef(m)["urgent"])
  s <- sqrt(vcov(m)["urgent", "urgent"])
  p <- 2 * pnorm(-abs(b / s))
  pct <- (exp(b) - 1) * 100
  data.table(spec = lab, coef = b, se = s, pval = p, pct = pct, n = m$nobs)
}
uo_tab <- rbindlist(list(
  extract_uo(m_uo_1, "(1) Baseline (item+year+PBU)"),
  extract_uo(m_uo_2, "(2) + log quantity"),
  extract_uo(m_uo_3, "(3) + firm FE"),
  extract_uo(m_uo_4, "(4) + log qty + firm FE")
))
print(uo_tab[, .(spec, coef = round(coef,3), se = round(se,3), pct = round(pct,2), n)])


# T4.2 -- Cascade for UTG (lit-vs-admin within urgent)
cat("\n-- T4.2 Three-channel cascade (UTG: lit-vs-admin) --\n")
m_utg_1 <- feols(bid_price_log ~ is_admin | item_id + year_n + pbu_id,
                 data = d_utg, cluster = ~pbu_id)
m_utg_2 <- feols(bid_price_log ~ is_admin + bid_qty_log | item_id + year_n + pbu_id,
                 data = d_utg, cluster = ~pbu_id)
m_utg_3 <- feols(bid_price_log ~ is_admin | item_id + year_n + pbu_id + firm_f,
                 data = d_utg, cluster = ~pbu_id)
m_utg_4 <- feols(bid_price_log ~ is_admin + bid_qty_log | item_id + year_n + pbu_id + firm_f,
                 data = d_utg, cluster = ~pbu_id)

# UTG: report litigated premium (positive sign) by flipping admin coefficient.
extract_utg <- function(m, lab) {
  b <- unname(coef(m)["is_admin"])
  s <- sqrt(vcov(m)["is_admin", "is_admin"])
  p <- 2 * pnorm(-abs(b / s))
  pct <- (exp(-b) - 1) * 100   # litigated premium
  data.table(spec = lab, coef = b, se = s, pval = p, pct = pct, n = m$nobs)
}
utg_tab <- rbindlist(list(
  extract_utg(m_utg_1, "(1) Baseline (item+year+PBU)"),
  extract_utg(m_utg_2, "(2) + log quantity"),
  extract_utg(m_utg_3, "(3) + firm FE"),
  extract_utg(m_utg_4, "(4) + log qty + firm FE")
))
print(utg_tab[, .(spec, coef = round(coef,3), se = round(se,3), pct = round(pct,2), n)])


# Three-channel decomposition (recomputed from this clean run)
chan_qty_uo  <- uo_tab[1, pct] - uo_tab[2, pct]
chan_firm_uo <- uo_tab[1, pct] - uo_tab[3, pct]
chan_resid_uo <- uo_tab[4, pct]
chan_qty_utg <- utg_tab[1, pct] - utg_tab[2, pct]
chan_firm_utg <- utg_tab[1, pct] - utg_tab[3, pct]
chan_resid_utg <- utg_tab[4, pct]
cat(sprintf("\n  UO decomposition: total %.2f%% | C1 (qty) %.2f pp | C3 (firm sel) %.2f pp | residual %.2f pp\n",
            uo_tab[1, pct], chan_qty_uo, chan_firm_uo, chan_resid_uo))
cat(sprintf("  UTG decomposition: total %.2f%% | C1 (qty) %.2f pp | C3 (firm sel) %.2f pp | residual %.2f pp\n",
            utg_tab[1, pct], chan_qty_utg, chan_firm_utg, chan_resid_utg))


# Helper -- LaTeX table writer for a 4-spec cascade
write_cascade_table <- function(tab, label_str, caption_str, treat_lab, file_path) {
  pstars <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
  fmt3 <- function(x) formatC(x, format = "f", digits = 3)
  fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
  # Compute decomposition: drop from spec (1) to (2) = qty channel (C1)
  total_pct <- tab[1, pct]
  qty_drop  <- tab[1, pct] - tab[2, pct]
  firm_drop <- tab[1, pct] - tab[3, pct]
  resid     <- tab[4, pct]

  lines <- c(
    "\\begin{table}[ht]",
    "  \\centering",
    paste0("  \\caption{", caption_str, "}"),
    paste0("  \\label{tab:", label_str, "}"),
    "  \\small",
    "  \\begin{threeparttable}",
    "  \\begin{tabular}{lcccc}",
    "    \\hline\\hline",
    "                                    & (1)         & (2)            & (3)        & (4)             \\\\",
    "                                    & Baseline    & + log qty.\\   & + firm FE  & + qty + firm FE \\\\",
    "    \\hline"
  )
  lines <- c(lines,
    paste0("    ", treat_lab, " & ",
           paste(sprintf("%s%s", fmt3(tab$coef), pstars(tab$pval)), collapse = " & "), " \\\\"),
    paste0("                                    & ",
           paste(sprintf("(%s)", fmt3(tab$se)), collapse = " & "), " \\\\[3pt]"),
    paste0("    Implied premium (\\%)            & ",
           paste(sprintf("%.2f\\%%", tab$pct), collapse = " & "), " \\\\")
  )
  lines <- c(lines,
    "    \\hline",
    "    Item FE                          & Yes & Yes & Yes & Yes \\\\",
    "    Year FE                          & Yes & Yes & Yes & Yes \\\\",
    "    PBU FE                           & Yes & Yes & Yes & Yes \\\\",
    "    Firm FE                          & No  & No  & Yes & Yes \\\\",
    "    log Quantity control             & No  & Yes & No  & Yes \\\\",
    "    \\hline",
    paste0("    Observations                     & ",
           paste(sapply(tab$n, fmt_int), collapse = " & "), " \\\\"),
    "    \\hline\\hline",
    "  \\end{tabular}",
    "  \\begin{tablenotes}",
    "    \\small",
    "    \\item \\textit{Notes:} Three-channel decomposition. Column (1) gives",
    "    the total premium under the preferred specification. Columns (2)--(4)",
    "    progressively absorb channels: (2) absorbs \\emph{C1 demand fragmentation}",
    "    via log quantity; (3) absorbs \\emph{C3 supplier composition shift}",
    "    via firm fixed effects; (4) absorbs both, leaving the C2",
    "    \\emph{competition channel} residual (and any within-firm markup).",
    sprintf("    Decomposition: total %.2f\\%% = %.2f pp (C1 quantity) + %.2f pp (C3 firm",
            total_pct, qty_drop, firm_drop),
    sprintf("    selection) + %.2f pp (residual).", resid),
    "    Standard errors clustered at the PBU level in parentheses.",
    "    *** $p<0.01$, ** $p<0.05$, * $p<0.10$.",
    "  \\end{tablenotes}",
    "  \\end{threeparttable}",
    "\\end{table}"
  )
  writeLines(lines, file_path)
  cat("  Saved:", file_path, "\n")
}

write_cascade_table(uo_tab, "three_channel_uo",
                    "Three-Channel Decomposition: Urgent vs.\\ Ordinary Procurement",
                    "Urgent purchase",
                    file.path(OUT, "tables", "tab_three_channel_uo.tex"))
write_cascade_table(utg_tab, "three_channel_utg",
                    "Three-Channel Decomposition: Litigated vs.\\ Administrative (Under the Gun)",
                    "Administrative (vs Lit.)",
                    file.path(OUT, "tables", "tab_three_channel_utg.tex"))


# F.1 -- Cascade waterfall figure
cat("\n-- F.1 Three-channel cascade waterfall figure --\n")
# Two-panel: top = urgent-vs-ord; bottom = UTG. Each panel: 4 bars (cascade).
fig_data <- rbindlist(list(
  cbind(uo_tab,  comparison = "Urgent vs. Ordinary"),
  cbind(utg_tab, comparison = "Under the Gun (Litigated vs. Administrative)")
))
fig_data[, comparison := factor(comparison,
                                levels = c("Urgent vs. Ordinary",
                                           "Under the Gun (Litigated vs. Administrative)"))]
spec_levels <- c("(1) Baseline", "(2) + qty.", "(3) + firm FE", "(4) + qty + firm FE")
fig_data[, spec_short := factor(rep(spec_levels, 2), levels = spec_levels)]
fig_data[, pct_lab := sprintf("%.1f%%", pct)]
fig_data[, ci_lo := pct - 1.96 * (se * 100)]   # rough back-of-envelope CI
fig_data[, ci_hi := pct + 1.96 * (se * 100)]

p_cascade <- ggplot(fig_data, aes(x = spec_short, y = pct)) +
  geom_col(fill = "steelblue", width = 0.65) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, color = "gray30") +
  geom_hline(yintercept = 0, color = "gray40", linewidth = 0.3) +
  geom_text(aes(label = pct_lab,
                vjust = ifelse(pct >= 0, -0.5, 1.5)),
            size = 2.8) +
  facet_wrap(~comparison, scales = "free_y", ncol = 1) +
  labs(x = NULL, y = "Implied price premium (\\%)",
       title = "Three-Channel Decomposition of the Procurement Cost of Judicial Enforcement",
       caption = "Cascade across the four canonical specifications. Drop from (1)->(2) absorbs C1 (demand fragmentation, via log quantity); drop from (1)->(3) absorbs C3 (supplier composition shift, via firm FE); column (4) is the residual. Top panel: urgent-vs-ordinary across the full sample. Bottom panel: litigated-vs-administrative within the urgent sub-sample (UTG). Error bars = 95% CI.") +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "white"),
        strip.text = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0, size = 7),
        plot.title = element_text(size = 9, face = "bold"))
ggsave(file.path(OUT, "figures", "fig_three_channel_cascade.pdf"),
       p_cascade, width = 6.5, height = 5.5, device = cairo_pdf)
cat("  Saved: fig_three_channel_cascade.pdf\n")


# F.2 -- Distributional density: ratio of admin/lit qty within item-month
cat("\n-- F.2 Distributional density of admin/lit qty ratio within item-month --\n")
d_dens <- dt[has_admin == TRUE & has_litigated == TRUE & urgent == 1L &
             po_firm_winner == 1L & !is.na(bid_qty_log)]
d_dens[, ym_int := as.integer(format(m_y, "%Y")) * 12L + as.integer(format(m_y, "%m"))]
adm_avg <- d_dens[is_admin == 1L,
                  .(mean_log_qty_adm = mean(bid_qty_log, na.rm = TRUE)),
                  by = .(item, ym_int)]
lit_avg <- d_dens[is_admin == 0L,
                  .(mean_log_qty_lit = mean(bid_qty_log, na.rm = TRUE)),
                  by = .(item, ym_int)]
ratios <- merge(adm_avg, lit_avg, by = c("item", "ym_int"))
ratios[, log_ratio := mean_log_qty_adm - mean_log_qty_lit]
ratios[, ratio := exp(log_ratio)]
cat(sprintf("  Cells with both admin and lit: %d\n", nrow(ratios)))
cat(sprintf("  Median admin/lit qty ratio: %.2fx\n", median(ratios$ratio)))
cat(sprintf("  Mean admin/lit qty ratio: %.2fx\n", mean(ratios$ratio)))

p_dens <- ggplot(ratios, aes(x = log_ratio)) +
  geom_density(fill = "darkred", alpha = 0.35, color = "darkred") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = log(median(ratios$ratio)), linetype = "dotted", color = "darkred") +
  scale_x_continuous(breaks = log(c(0.25, 0.5, 1, 2, 4, 8, 16)),
                     labels = c("0.25x", "0.5x", "1x (equal)", "2x", "4x", "8x", "16x")) +
  coord_cartesian(xlim = c(-2, 4.5)) +
  labs(x = "Administrative-to-Litigated order-quantity ratio (log scale)",
       y = "Density",
       title = "Order-Quantity Fragmentation under Judicial Pressure",
       caption = sprintf("Density of (admin / lit) order-quantity ratio within item-month cells with both purchase types present (N = %d cells). Dashed vertical = 1x equality. Dotted vertical = sample median (%.2fx). Distribution is right-shifted: administrative orders are systematically larger than litigated orders for the same item in the same month.",
                          nrow(ratios), median(ratios$ratio))) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        plot.caption = element_text(hjust = 0, size = 7),
        plot.title = element_text(size = 9, face = "bold"))
ggsave(file.path(OUT, "figures", "fig_qty_ratio_density.pdf"),
       p_dens, width = 6.5, height = 4, device = cairo_pdf)
cat("  Saved: fig_qty_ratio_density.pdf\n")

# Emit macros
macros <- list(
  cascadeUOtotalPct = bp_fmt_pct(uo_tab[1, pct], 2),
  cascadeUOqtyPP    = bp_fmt(chan_qty_uo, 2),
  cascadeUOfirmPP   = bp_fmt(chan_firm_uo, 2),
  cascadeUOresidPP  = bp_fmt(chan_resid_uo, 2),
  cascadeUTGtotalPct = bp_fmt_pct(utg_tab[1, pct], 2),
  cascadeUTGqtyPP    = bp_fmt(chan_qty_utg, 2),
  cascadeUTGfirmPP   = bp_fmt(chan_firm_utg, 2),
  cascadeUTGresidPP  = bp_fmt(chan_resid_utg, 2),
  qtyRatioMedianX    = bp_fmt(median(ratios$ratio), 2),
  qtyRatioMeanX      = bp_fmt(mean(ratios$ratio), 2),
  qtyRatioCellsBoth  = bp_fmt_int(nrow(ratios))
)
bp_macros_emit("35_figure_decomposition", macros)

cat("\n35_figure_decomposition.R complete\n")
