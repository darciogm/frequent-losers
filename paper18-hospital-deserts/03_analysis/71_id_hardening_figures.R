#!/usr/bin/env Rscript
# 71_id_hardening_figures.R
#
# Appendix event-study figures for the two identification-hardening checks
# (scripts 69 recipient-control spillover, 70 LOCOCOR displacement). Each
# overlays the headline suicide event study against the robustness variant,
# so the reader sees the trajectory is unchanged.
#
# Outputs:
#   04_figures/fig_es_displacement_suicide.pdf  — out-of-hospital deaths vs all deaths
#   04_figures/fig_es_recipient_suicide.pdf     — recipient controls dropped vs all controls
#
# Usage: Rscript 03_analysis/71_id_hardening_figures.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})
setFixest_nthreads(4); setDTthreads(4)

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
FIG   <- file.path(ROOT, "04_figures")
LOGF  <- file.path(ROOT, "04_logs", "71_id_hardening_figures.log")
PANEL <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")

force <- "--force" %in% commandArgs(TRUE)
out1 <- file.path(FIG, "fig_es_displacement_suicide.pdf")
out2 <- file.path(FIG, "fig_es_recipient_suicide.pdf")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOGF, append = TRUE) }
cat(sprintf("==== 71_id_hardening_figures %s ====\n", Sys.time()), file = LOGF)

if (file.exists(out1) && file.exists(out2) && !force) {
  say("outputs exist, skipping (use --force)"); quit(save = "no")
}

OK <- "#0072B2"; ORANGE <- "#D55E00"; GREY <- "gray55"

# event-study coefficients + aggregate ATT, mirroring D5/D6 estimate()
es_coefs <- function(d, yn, wt = TRUE) {
  d <- copy(d)[is.finite(get(yn)) & (!wt | is.finite(pop))]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  w <- if (wt) d$pop else NULL
  m <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
             d, cluster = "muni_id", weights = w)
  att <- as.numeric(coef(summary(m, agg = "att"))[1])
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  list(es = es[is.finite(cf) & is.finite(se) & se > 0], att = att)
}

overlay_plot <- function(base, var, base_lab, var_lab, title) {
  d <- rbind(data.table(base$es, series = base_lab),
             data.table(var$es,  series = var_lab))[e >= -6 & e <= 8]
  d[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  d[, series := factor(series, levels = c(base_lab, var_lab))]
  ggplot(d, aes(e, cf, color = series)) +
    geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
    geom_pointrange(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.55),
                    linewidth = 0.5, size = 0.32) +
    scale_color_manual(values = setNames(c(OK, ORANGE), c(base_lab, var_lab)), name = NULL) +
    scale_x_continuous(breaks = seq(-6, 8, 2)) +
    labs(x = "Years since closure", y = "ATT (per 100,000)", title = title) +
    theme_minimal(base_size = 9.5) +
    theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10, hjust = 0),
          legend.position = "bottom")
}

P <- as.data.table(read_parquet(PANEL))

base <- es_coefs(P, "suicide_per100k", TRUE)
say("VALIDATION baseline suicide ATT = %.4f (target ~ +0.28)", base$att)
stopifnot(abs(base$att - 0.28) < 0.05)

# ---- displacement: out-of-hospital suicide ----
lc <- as.data.table(read_parquet(file.path(INTER, "lococor_counts.parquet")))
Pd <- merge(P, lc[, .(codmun_6, year, n_suicide_out)], by = c("codmun_6", "year"), all.x = TRUE)
Pd[is.na(n_suicide_out), n_suicide_out := 0]
Pd[, suicide_out_per100k := n_suicide_out / pop * 1e5]
disp <- es_coefs(Pd, "suicide_out_per100k", TRUE)
say("displacement out-of-hospital suicide ATT = %.2f (target ~ -0.01)", disp$att)

# ---- spillover: drop revealed-recipient never-treated controls (thresh 0.01) ----
rf <- as.data.table(read_parquet(file.path(INTER, "recipient_control_flow.parquet")))
recip <- rf[max_delta_share > 0.01, codmun_6]
ctrl  <- P[is.na(g_emb) | g_emb == 0, unique(codmun_6)]
drop_munis <- intersect(recip, ctrl)
say("recipient never-treated controls dropped: %d (target ~ 1424)", length(drop_munis))
Ps <- P[!(codmun_6 %in% drop_munis)]
spill <- es_coefs(Ps, "suicide_per100k", TRUE)
say("recipient-dropped suicide ATT = %.2f (target ~ -0.04)", spill$att)

ggsave(out1, overlay_plot(base, disp, "All suicide deaths", "Out-of-hospital only",
                          "Suicide event study: out-of-hospital deaths"),
       width = 5.6, height = 4.0, device = "pdf")
say("wrote %s", out1)
ggsave(out2, overlay_plot(base, spill, "All controls", "Recipient controls dropped",
                          "Suicide event study: spillover-robust controls"),
       width = 5.6, height = 4.0, device = "pdf")
say("wrote %s", out2)
say("done")
