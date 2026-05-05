# Layer 1 / Track G (CRITICAL PATH) --- Reconcile observed UTG against
# its mechanical C1 prediction, with the within-firm-buyer-item offset
# isolating the supplier-composition residual.
#
# Identity (in log-points, lit minus admin):
#   observed UTG  =  mechanical C1 prediction
#                  + within-firm offset
#                  + supplier composition residual
#
# Inputs:
#   - bulk-discount elasticity  (v7: -0.341 from UTG Panel B qty coef)
#   - log qty gap admin minus lit  (v7: 1.34)
#   - within-firm-buyer-item triple coef  --- recomputed here for the UTG
#     contrast (lit vs admin within urgent), since v7's triple coef is for
#     urgent vs ordinary
#
# Output:
#   - tab_utg_reconciliation.tex
#   - fig_sourcing_vs_pricing.pdf  (headline figure for v8: bar chart of
#     observed UTG vs the three reconciliation components)
#   - macros: BPutgMechanicalCone, BPutgWithinFirmOffset,
#             BPutgCompositionResidual

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
n_per_fbi <- d[, .N, by = .(fbi, admin)]
fbi_both <- unique(merge(n_per_fbi[admin == 0L][, .(fbi)],
                         n_per_fbi[admin == 1L][, .(fbi)],
                         by = "fbi")$fbi)
d_triple <- d[fbi %in% fbi_both]
cat(sprintf("UTG firm-buyer-item triples observed in both regimes: %d\n",
            length(fbi_both)))
cat(sprintf("Triple sample N: %d\n", nrow(d_triple)))

# 1. Naive UTG (preferred FE)
m_naive <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
                 data = d, cluster = ~pbu_id)
b_naive <- coef(m_naive)["admin"]   # negative: admin cheaper

# 2. Within-firm-buyer-item triple coef in UTG
m_triple <- feols(bid_price_log ~ admin | fbi + year_n,
                  data = d_triple, cluster = ~pbu_id)
b_triple <- coef(m_triple)["admin"]
se_triple <- sqrt(diag(vcov(m_triple)))["admin"]
cat(sprintf("Triple UTG admin coef: %.4f (SE %.4f, N=%d)\n",
            b_triple, se_triple, nobs(m_triple)))

# 3. Mechanical C1 prediction
# log qty gap admin minus lit (positive = admin orders larger)
qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if (is.na(qty_col)) stop("No quantity column found.")
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") {
  d[, lqty := bid_qty_log]
} else {
  d[, lqty := log(pmax(get(qty_col), 1))]
}
m_qty <- feols(lqty ~ admin | item_id + year_n + pbu_id, data = d, cluster = ~pbu_id)
qty_gap <- coef(m_qty)["admin"]
cat(sprintf("Log qty gap (admin minus lit): %.4f\n", qty_gap))

# bulk-discount elasticity: regress log price on log qty within UTG
m_be <- feols(bid_price_log ~ lqty | item_id + year_n + pbu_id, data = d, cluster = ~pbu_id)
bulk_elast <- coef(m_be)["lqty"]
cat(sprintf("Bulk-discount elasticity: %.4f\n", bulk_elast))

mech_c1_log <- bulk_elast * qty_gap
cat(sprintf("Mechanical C1 prediction (admin minus lit log price): %.4f -> pct = %.2f%%\n",
            mech_c1_log, (exp(mech_c1_log) - 1) * 100))

# 4. Supplier composition residual = observed - mechanical - within-firm offset
# All in log points, admin minus lit perspective
composition_log <- b_naive - mech_c1_log - b_triple
cat(sprintf("Supplier composition residual: %.4f log -> pct %.2f%%\n",
            composition_log, (exp(composition_log) - 1) * 100))

# Build reconciliation table
to_pct <- function(b) (exp(b) - 1) * 100
res <- data.table(
  component = c("Observed UTG (admin minus lit, log price)",
                "Mechanical C1: bulk-discount x qty gap",
                "Within firm-buyer-item offset",
                "Supplier composition residual"),
  log_pct = c(b_naive, mech_c1_log, b_triple, composition_log),
  pct     = c(to_pct(b_naive), to_pct(mech_c1_log),
              to_pct(b_triple), to_pct(composition_log))
)
print(res)

ktab <- kbl(res, format = "latex", booktabs = TRUE, digits = 3,
            col.names = c("Component", "Log-points (admin minus lit)",
                          "Implied \\% (admin vs lit)"),
            label = "tab:utg_reconciliation",
            caption = paste0("UTG reconciliation: observed log-price gap decomposed into mechanical bulk-discount prediction, within firm-buyer-item offset, and supplier composition residual. ",
                             format(length(fbi_both), big.mark = ","), " triples observed in both regimes."),
            escape = FALSE) |>
  footnote(general = paste(
    "Identity: observed UTG = mechanical C1 + within-firm offset + composition residual.",
    "Within-firm offset estimated on firm-buyer-item triples observed under both",
    "litigated and administrative urgent procurement (no mechanical C1 contribution).",
    "Composition residual is the part of the observed UTG that operates through",
    "equilibrium changes in which firm wins the contract."),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_utg_reconciliation.tex"))

# Headline figure: sourcing vs pricing dichotomy
plot_df <- data.table(
  comp = factor(c("Observed", "Mechanical\nC1 (qty)",
                  "Within-firm\noffset", "Composition\n(sourcing)"),
                levels = c("Observed", "Mechanical\nC1 (qty)",
                           "Within-firm\noffset", "Composition\n(sourcing)")),
  pct = c(to_pct(b_naive), to_pct(mech_c1_log),
          to_pct(b_triple), to_pct(composition_log))
)
p <- ggplot(plot_df, aes(comp, pct, fill = comp)) +
  geom_col(width = 0.65) +
  geom_hline(yintercept = 0, color = "grey30") +
  scale_fill_manual(values = c("Observed" = "grey20",
                               "Mechanical\nC1 (qty)" = "#1f77b4",
                               "Within-firm\noffset" = "#2ca02c",
                               "Composition\n(sourcing)" = "#d62728"),
                    guide = "none") +
  labs(x = NULL,
       y = "Log price gap, admin minus lit (%)",
       caption = "Identity: Observed = Mechanical C1 + Within-firm + Composition.\nThe 'within-firm' bar is the price effect of urgency among same firm-buyer-item triples;\nthe 'composition' bar is the residual --- equilibrium changes in which firm wins.") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.x = element_blank())
ggsave(file.path(OUT, "figures", "fig_sourcing_vs_pricing.pdf"),
       p, width = 6.5, height = 4, device = cairo_pdf)

bp_macros_emit("45_reconciliation", list(
  utgMechanicalCone            = bp_fmt_pct(to_pct(mech_c1_log)),
  utgWithinFirmOffset        = bp_fmt_pct(to_pct(b_triple)),
  utgCompositionResidual     = bp_fmt_pct(to_pct(composition_log)),
  utgTripleCoefUTG           = bp_fmt(b_triple),
  utgTripleSEUTG             = bp_fmt(se_triple),
  utgTripleNUTG              = bp_fmt_int(nobs(m_triple)),
  utgTripleCountUTG          = bp_fmt_int(length(fbi_both)),
  utgQtyGapAdminLit          = bp_fmt(qty_gap),
  utgBulkElasticity          = bp_fmt(bulk_elast)
))
bp_log_step("done", t0, LOG)
