# Layer 1 / Track G (CRITICAL PATH) --- Reconcile observed UTG against
# its mechanical C1 prediction, with the within-firm-buyer-item offset
# isolating the supplier-composition residual.
#
# Identity (in log-points, admin minus lit):
#   observed UTG  =  mechanical C1 prediction
#                  + within-firm offset
#                  + supplier composition residual
#
# v8 update (2026-05-05): added cluster-bootstrap on PBU for 95% CIs on each
# of the four bars; redesigned headline figure to put the within-firm null in
# visual headline (neutral fill + heavy outline + direct annotation).
#
# Outputs:
#   - tab_utg_reconciliation.tex
#   - fig_sourcing_vs_pricing.pdf  (headline figure: 4-bar identity with IC95)
#   - macros (point estimates + CI bounds for each component)

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(kableExtra)
})

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
bp_set_threads(12L)

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"),  recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)
LOG  <- file.path(LOGS, "45_reconciliation.log")
writeLines(sprintf("# 45_reconciliation | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# UTG sample
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 &
        !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

# need a firm identifier
firm_col <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner",
                        "cnpj_raiz_winner"), names(d))[1]
if (is.na(firm_col) || all(is.na(d[[firm_col]]))) {
  stop("No firm identifier column available; check cache build.")
}
d[, firm := as.factor(get(firm_col))]
d[, fbi := paste(firm, pbu_id, item_id, sep = "_")]

qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if (is.na(qty_col)) stop("No quantity column found.")
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") {
  d[, lqty := bid_qty_log]
} else {
  d[, lqty := log(pmax(get(qty_col), 1))]
}

n_per_fbi <- d[, .N, by = .(fbi, admin)]
fbi_both <- unique(merge(n_per_fbi[admin == 0L][, .(fbi)],
                         n_per_fbi[admin == 1L][, .(fbi)],
                         by = "fbi")$fbi)
d_triple <- d[fbi %in% fbi_both]
cat(sprintf("UTG firm-buyer-item triples observed in both regimes: %d\n",
            length(fbi_both)))
cat(sprintf("Triple sample N: %d\n", nrow(d_triple)))

# ============================================================================
# Point estimates (the four components of the identity)
# ============================================================================
fit_components <- function(dat, dat_triple) {
  m_naive  <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
                    data = dat, notes = FALSE, warn = FALSE)
  m_triple <- feols(bid_price_log ~ admin | fbi + year_n,
                    data = dat_triple, notes = FALSE, warn = FALSE)
  m_qty    <- feols(lqty ~ admin | item_id + year_n + pbu_id,
                    data = dat, notes = FALSE, warn = FALSE)
  m_be     <- feols(bid_price_log ~ lqty | item_id + year_n + pbu_id,
                    data = dat, notes = FALSE, warn = FALSE)

  b_naive   <- unname(coef(m_naive)["admin"])
  b_triple  <- unname(coef(m_triple)["admin"])
  qty_gap   <- unname(coef(m_qty)["admin"])
  bulk_el   <- unname(coef(m_be)["lqty"])
  mech_c1   <- bulk_el * qty_gap
  comp_res  <- b_naive - mech_c1 - b_triple

  list(b_naive = b_naive, b_triple = b_triple,
       qty_gap = qty_gap, bulk_el = bulk_el,
       mech_c1 = mech_c1, comp_res = comp_res,
       se_triple = unname(sqrt(diag(vcov(m_triple, cluster = ~pbu_id)))["admin"]),
       n_triple  = nobs(m_triple))
}

pt <- fit_components(d, d_triple)
cat(sprintf("Triple UTG admin coef: %.4f (SE %.4f, N=%d)\n",
            pt$b_triple, pt$se_triple, pt$n_triple))
cat(sprintf("Log qty gap (admin minus lit): %.4f\n", pt$qty_gap))
cat(sprintf("Bulk-discount elasticity: %.4f\n", pt$bulk_el))
cat(sprintf("Mechanical C1 (admin minus lit): %.4f\n", pt$mech_c1))
cat(sprintf("Supplier composition residual: %.4f\n", pt$comp_res))
bp_log_step("point estimates", t0, LOG)

# ============================================================================
# Cluster bootstrap on PBU --- 95% CI for each component
# ============================================================================
B <- 499L  # cluster bootstrap on PBU; 499 reps respect Coviello et al. 2018
            # convention. A B=999 attempt 2026-05-05 hit pathological fixest
            # FE-cache slowdown (~7.8 s/rep vs ~0.14 s/rep at B=499); kept at
            # 499 pending efficient implementation (e.g., one-step influence-
            # function bootstrap on pre-fitted residuals).
pbu_levels <- unique(d$pbu_id)
n_pbu <- length(pbu_levels)
set.seed(20260505L)

boot_mat <- matrix(NA_real_, nrow = B, ncol = 4L,
                   dimnames = list(NULL, c("obs", "mech", "within", "comp")))

t_boot <- Sys.time()
for (b in seq_len(B)) {
  idx <- sample.int(n_pbu, n_pbu, replace = TRUE)
  pbus_b <- pbu_levels[idx]
  # Build the resampled dataset (preserve cluster structure)
  d_b <- d[d$pbu_id %in% pbus_b]
  fbi_both_b <- intersect(fbi_both, unique(d_b$fbi))
  if (length(fbi_both_b) < 50L) next  # skip degenerate draws
  d_triple_b <- d_b[fbi %in% fbi_both_b]
  est <- tryCatch(
    fit_components(d_b, d_triple_b),
    error = function(e) NULL
  )
  if (is.null(est)) next
  boot_mat[b, ] <- c(est$b_naive, est$mech_c1, est$b_triple, est$comp_res)
  if (b %% 50L == 0L) cat(sprintf("  bootstrap rep %d/%d\n", b, B))
}
boot_mat <- boot_mat[complete.cases(boot_mat), , drop = FALSE]
cat(sprintf("Bootstrap reps usable: %d / %d\n", nrow(boot_mat), B))
bp_log_step("cluster bootstrap", t_boot, LOG)

ci_pct <- function(x) (exp(quantile(x, c(0.025, 0.975), na.rm = TRUE)) - 1) * 100
to_pct <- function(b) (exp(b) - 1) * 100

cis <- list(
  obs    = ci_pct(boot_mat[, "obs"]),
  mech   = ci_pct(boot_mat[, "mech"]),
  within = ci_pct(boot_mat[, "within"]),
  comp   = ci_pct(boot_mat[, "comp"])
)

# ============================================================================
# Reconciliation table (point estimates only --- table format unchanged)
# ============================================================================
res <- data.table(
  component = c("Observed UTG (admin minus lit, log price)",
                "Mechanical C1: bulk-discount x qty gap",
                "Within firm-buyer-item offset",
                "Supplier composition residual"),
  log_pct = c(pt$b_naive, pt$mech_c1, pt$b_triple, pt$comp_res),
  pct     = c(to_pct(pt$b_naive), to_pct(pt$mech_c1),
              to_pct(pt$b_triple), to_pct(pt$comp_res))
)
print(res)

ktab <- kbl(res, format = "latex", booktabs = TRUE, digits = 3,
            col.names = c("Component", "Log-points (admin minus lit)",
                          "Implied \\% (admin vs lit)"),
            label = "utg_reconciliation",
            caption = paste0("UTG reconciliation: observed log-price gap decomposed into mechanical bulk-discount prediction, within firm-buyer-item offset, and supplier composition residual. ",
                             format(length(fbi_both), big.mark = ","), " triples observed in both regimes."),
            escape = FALSE) |>
  footnote(general = paste(
    "Identity: observed UTG = mechanical C1 + within-firm offset + composition residual.",
    "Within-firm offset estimated on firm-buyer-item triples observed under both",
    "litigated and administrative urgent procurement (no mechanical C1 contribution).",
    "Composition residual is the part of the observed UTG that operates through",
    "equilibrium changes in which firm wins the contract.",
    sprintf("95\\%% cluster-bootstrap CIs (PBU, B=%d): observed [%.1f, %.1f]; mech C1 [%.1f, %.1f]; within-firm [%.1f, %.1f]; composition [%.1f, %.1f].",
            nrow(boot_mat),
            cis$obs[1], cis$obs[2],
            cis$mech[1], cis$mech[2],
            cis$within[1], cis$within[2],
            cis$comp[1], cis$comp[2])),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_utg_reconciliation.tex"))

# ============================================================================
# Headline figure --- redesign for v8 (NULL in visual headline)
# ============================================================================
plot_df <- data.table(
  comp_short = c("Observed", "Mechanical C1\n(quantity)",
                 "Within-firm\n(no markup)", "Composition\n(sourcing)"),
  comp_order = 1:4,
  pct        = c(to_pct(pt$b_naive), to_pct(pt$mech_c1),
                 to_pct(pt$b_triple), to_pct(pt$comp_res)),
  ci_lo      = c(cis$obs[1], cis$mech[1], cis$within[1], cis$comp[1]),
  ci_hi      = c(cis$obs[2], cis$mech[2], cis$within[2], cis$comp[2])
)
plot_df[, comp_short := factor(comp_short, levels = comp_short)]

# Highlight: within-firm bar gets neutral fill + heavy outline so the null
# reads visually before the eye reaches the caption.
fill_pal    <- c("grey55", "grey75", "white", "grey75")
outline_pal <- c("grey25", "grey25", "black", "grey25")
linew_pal   <- c(0.4, 0.4, 1.4, 0.4)

y_top <- max(plot_df$pct, plot_df$ci_hi, na.rm = TRUE)
y_bot <- min(plot_df$pct, plot_df$ci_lo, na.rm = TRUE)
y_pad <- 0.05 * (y_top - y_bot)

p <- ggplot(plot_df, aes(comp_short, pct)) +
  geom_col(width = 0.58,
           fill   = fill_pal,
           color  = outline_pal,
           linewidth = linew_pal) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                width = 0.16, color = "grey15", linewidth = 0.45) +
  geom_hline(yintercept = 0, color = "grey20", linewidth = 0.4) +
  annotate("text", x = 3, y = y_top * 0.62,
           label = "no within-firm\nmarkup",
           size = 3.4, fontface = "italic", family = "serif",
           lineheight = 0.95, color = "black") +
  annotate("segment",
           x = 3, xend = 3,
           y = y_top * 0.45,
           yend = plot_df$ci_hi[3] + y_pad,
           color = "black", linewidth = 0.4,
           arrow = arrow(length = unit(0.14, "cm"), type = "closed")) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 6),
                     labels = function(x) sprintf("%+.0f", x)) +
  labs(x = NULL,
       y = "Admin-minus-litigated log price gap (percent)") +
  theme_classic(base_size = 11, base_family = "serif") +
  theme(panel.grid.major.y = element_line(color = "grey92", linewidth = 0.3),
        axis.line.x  = element_line(color = "grey20", linewidth = 0.4),
        axis.line.y  = element_line(color = "grey20", linewidth = 0.4),
        axis.ticks   = element_line(color = "grey20", linewidth = 0.3),
        axis.text    = element_text(color = "black"),
        axis.title.y = element_text(margin = margin(r = 8)),
        plot.margin  = margin(10, 14, 6, 8))

ggsave(file.path(OUT, "figures", "fig_sourcing_vs_pricing.pdf"),
       p, width = 6.8, height = 4.2, device = cairo_pdf)

# ============================================================================
# Emit macros
# ============================================================================
bp_macros_emit("45_reconciliation", list(
  utgMechanicalCone        = bp_fmt_pct(to_pct(pt$mech_c1)),
  utgWithinFirmOffset      = bp_fmt_pct(to_pct(pt$b_triple)),
  utgCompositionResidual   = bp_fmt_pct(to_pct(pt$comp_res)),
  utgTripleCoefUTG         = bp_fmt(pt$b_triple),
  utgTripleSEUTG           = bp_fmt(pt$se_triple),
  utgTripleNUTG            = bp_fmt_int(pt$n_triple),
  utgTripleCountUTG        = bp_fmt_int(length(fbi_both)),
  utgQtyGapAdminLit        = bp_fmt(pt$qty_gap),
  utgBulkElasticity        = bp_fmt(pt$bulk_el),
  utgObsCIlow              = bp_fmt_pct(cis$obs[1]),
  utgObsCIhigh             = bp_fmt_pct(cis$obs[2]),
  utgMechCIlow             = bp_fmt_pct(cis$mech[1]),
  utgMechCIhigh            = bp_fmt_pct(cis$mech[2]),
  utgWithinCIlow           = bp_fmt_pct(cis$within[1]),
  utgWithinCIhigh          = bp_fmt_pct(cis$within[2]),
  utgCompCIlow             = bp_fmt_pct(cis$comp[1]),
  utgCompCIhigh            = bp_fmt_pct(cis$comp[2]),
  utgReconBootB            = bp_fmt_int(nrow(boot_mat))
))
bp_log_step("done", t0, LOG)
