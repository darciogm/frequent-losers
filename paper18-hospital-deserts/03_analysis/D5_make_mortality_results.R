#!/usr/bin/env Rscript
# D5_make_mortality_results.R
#
# Publication outputs for the AEJ:Policy mortality-null results, from the
# pop-backfilled *_ext staggered panels (real 2010-2024 pre-periods):
#   tab_mortality_null.tex        — bounds table (first stage + suicide/self-harm null + robustness)
#   fig_firststage_travel.pdf     — travel burden first stage (validates the flow exposure rule)
#   fig_es_mortality.pdf          — suicide + self-harm event studies (the null)
#   fig_es_icsap_pretrend.pdf     — ICSAP event study (pre-existing trend; the declined non-result)
#
# Primary sample: pnash48 (48 PNASH-anchored psychiatric closures, 104 exposed munis).
# Robustness: spec07 (41 specialized exogenous), psymax60 (60 all psychiatric).

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2); library(patchwork)
})

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
FIG   <- file.path(ROOT, "04_figures")
TAB   <- file.path(ROOT, "01_manuscript", "tables")

OK   <- "#0072B2"  # Okabe-Ito blue
GREY <- "gray55"

estimate <- function(panel_file, yn, wt = FALSE) {
  d <- as.data.table(read_parquet(file.path(INTER, panel_file)))
  d <- d[is.finite(get(yn)) & (!wt | is.finite(pop))]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  fml <- as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn))
  m <- if (wt) feols(fml, d, cluster = "muni_id", weights = ~pop)
       else    feols(fml, d, cluster = "muni_id")
  a <- summary(m, agg = "att"); att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- if (wt) weighted.mean(d[gn < 10000 & year < 2015][[yn]], d[gn < 10000 & year < 2015]$pop, na.rm = TRUE)
          else    mean(d[gn < 10000 & year < 2015][[yn]], na.rm = TRUE)
  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0][order(e)]
  pre <- es[e <= -2 & e >= -6]; W <- sum((pre$cf / pre$se)^2); k <- nrow(pre)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       base = base, ub_pct = 100 * (att + 1.96 * se) / base,
       p_pre = 1 - pchisq(W, k), n_tr = d[gn < 10000, uniqueN(muni_id)], es = es)
}

# ---- compute everything ----
P <- "staggered_panel_pnash48_ext.parquet"
suic_w <- estimate(P, "suicide_per100k", TRUE)
suic_o <- estimate(P, "suicide_per100k", FALSE)
self_w <- estimate(P, "selfharm_per100k", TRUE)
self_o <- estimate(P, "selfharm_per100k", FALSE)
trav   <- estimate(P, "travel_burden_km", FALSE)
icsap  <- estimate(P, "icsap_per1k", FALSE)
rob <- list(
  spec07   = estimate("staggered_panel_spec07_ext.parquet",   "suicide_per100k", TRUE),
  psymax60 = estimate("staggered_panel_psymax60_ext.parquet", "suicide_per100k", TRUE)
)

# ---- TABLE ----
fmt <- function(r) sprintf("$%+.2f$ & $[%+.2f,\\,%+.2f]$ & $%+.0f\\%%$ & %.2f & %d",
                           r$att, r$lo, r$hi, r$ub_pct, r$p_pre, r$n_tr)
tab <- c(
"\\begin{table}[h!]\\centering",
"\\caption{Mortality effects of psychiatric hospital closures. Staggered Sun-Abraham ATT on patient-flow--exposed municipalities, pre-periods observed back to 2010. Population-weighted rows give the effect on the average exposed person (the policy-relevant quantity); municipality-weighted rows are the unweighted complement. ``Upper bound'' is the 95\\% CI upper limit as a share of the pre-treatment treated-group baseline. Cluster-robust SE at the municipality level.}",
"\\label{tab:mortality-null}\\small",
"\\begin{tabular}{llccccc}",
"\\toprule",
" & Weighting & ATT & 95\\% CI & Upper bound & Pre-trend $p$ & $N_{\\text{tr}}$ \\\\",
"\\midrule",
"\\multicolumn{7}{l}{\\textit{First stage --- the flow rule captures real dependence}}\\\\",
sprintf("Travel burden (km) & --- & %s \\\\", fmt(trav)),
"\\addlinespace",
"\\multicolumn{7}{l}{\\textit{Headline --- the feared outcome}}\\\\",
sprintf("Suicide (per 100k) & Population & %s \\\\", fmt(suic_w)),
sprintf(" & Municipality & %s \\\\", fmt(suic_o)),
sprintf("Self-harm (per 100k) & Population & %s \\\\", fmt(self_w)),
sprintf(" & Municipality & %s \\\\", fmt(self_o)),
"\\addlinespace",
"\\multicolumn{7}{l}{\\textit{Robustness --- suicide, population-weighted, alternative closure samples}}\\\\",
sprintf("Specialized exogenous ($n{=}41$) & Population & %s \\\\", fmt(rob$spec07)),
sprintf("All psychiatric ($n{=}60$) & Population & %s \\\\", fmt(rob$psymax60)),
"\\bottomrule",
"\\multicolumn{7}{l}{\\footnotesize Primary sample: 48 PNASH-anchored psychiatric closures, 104 exposed municipalities, 2010--2024.}\\\\",
"\\end{tabular}\\end{table}")
writeLines(tab, file.path(TAB, "tab_mortality_null.tex"))
cat("wrote tab_mortality_null.tex\n")

# ---- FIGURES ----
plot_es <- function(r, title, ylab, hl_pre = FALSE) {
  d <- r$es[e >= -6 & e <= 8]
  d[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  d[, sig_pre := e < 0 & lo > 0]  # significant positive pre-period coef (pre-trend flag)
  col <- if (hl_pre) ifelse(d$sig_pre, "#D55E00", OK) else OK
  ggplot(d, aes(e, cf)) +
    geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, fill = OK) +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = col, linewidth = 0.55, size = 0.38) +
    geom_line(color = OK, linewidth = 0.4, alpha = 0.55) +
    scale_x_continuous(breaks = seq(-6, 8, 2)) +
    labs(x = "Years since closure", y = ylab, title = title) +
    theme_minimal(base_size = 9.5) +
    theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10, hjust = 0))
}

ggsave(file.path(FIG, "fig_firststage_travel.pdf"),
       plot_es(trav, "First stage: travel burden falls after closure", "ATT, travel burden (km)"),
       width = 5.4, height = 3.8, device = "pdf")
cat("wrote fig_firststage_travel.pdf\n")

fig_mort <- plot_es(suic_w, "(a) Suicide mortality", "ATT (per 100,000)") +
            plot_es(self_w, "(b) Self-harm mortality", "ATT (per 100,000)")
ggsave(file.path(FIG, "fig_es_mortality.pdf"), fig_mort, width = 9.6, height = 3.9, device = "pdf")
cat("wrote fig_es_mortality.pdf\n")

ggsave(file.path(FIG, "fig_es_icsap_pretrend.pdf"),
       plot_es(icsap, "Preventable hospitalizations: a pre-existing trend, not an effect",
               "ATT (per 1,000)", hl_pre = TRUE),
       width = 5.8, height = 3.9, device = "pdf")
cat("wrote fig_es_icsap_pretrend.pdf\n")

# ---- console summary for prose ----
cat("\n=== numbers for results.tex prose ===\n")
cat(sprintf("travel:    ATT=%+.2f [%+.2f,%+.2f] PTp=%.2f\n", trav$att, trav$lo, trav$hi, trav$p_pre))
cat(sprintf("suicide W: ATT=%+.2f [%+.2f,%+.2f] base=%.2f ub=%+.0f%% PTp=%.2f\n",
            suic_w$att, suic_w$lo, suic_w$hi, suic_w$base, suic_w$ub_pct, suic_w$p_pre))
cat(sprintf("suicide O: ATT=%+.2f [%+.2f,%+.2f] base=%.2f ub=%+.0f%% PTp=%.2f\n",
            suic_o$att, suic_o$lo, suic_o$hi, suic_o$base, suic_o$ub_pct, suic_o$p_pre))
cat(sprintf("selfharmW: ATT=%+.2f [%+.2f,%+.2f] ub=%+.0f%% PTp=%.2f\n",
            self_w$att, self_w$lo, self_w$hi, self_w$ub_pct, self_w$p_pre))
cat(sprintf("icsap O:   ATT=%+.2f [%+.2f,%+.2f] PTp=%.4f  pre-coefs e=-5/-4/-3: %s\n",
            icsap$att, icsap$lo, icsap$hi, icsap$p_pre,
            paste(round(icsap$es[e %in% c(-5,-4,-3)]$cf,2), collapse="/")))
