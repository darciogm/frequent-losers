#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# identification_tests.R — FL entry event study + min-bidder constraint
# Addresses Concern 1 from external referee: causal identification
# ═══════════════════════════════════════════════════════════════════
cat("=== IDENTIFICATION TESTS ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(fixest); library(ggplot2)
})
setDTthreads(16L)

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "work/v8/tables")
OUT_F <- file.path(BASE, "work/v8/images")
cb <- c("#0072B2","#D55E00","#009E73","#CC79A7")

# ── Load data ─────────────────────────────────────────────────────
cat("Loading data...\n")
bec <- as.data.table(read_parquet(file.path(BASE, "data/processed/BEC_collapse_final.parquet"),
  col_select=c("po_phase_code","po_item_merge_key","n_firms","bid_unit_price_negot_min")))
los <- as.data.table(read_parquet(file.path(BASE, "data/processed/LOSERS_rebuilt.parquet")))
setnames(los, "numerodaoc", "oc_code")

bec[, oc_code := substr(po_item_merge_key, 1, 22)]
bec[, pbu := substr(po_item_merge_key, 1, 11)]
bec[, year := as.integer(substr(po_item_merge_key, 12, 15))]
bec <- bec[po_phase_code %in% c(2L, 3L)]
bec[, convite := as.integer(po_phase_code == 2L)]
bec[bid_unit_price_negot_min > 0, log_price := log(bid_unit_price_negot_min)]

los_agg <- los[, .(fl_count = sum(losers_count, na.rm=TRUE)), by=oc_code]
bec <- merge(bec, los_agg, by="oc_code", all.x=TRUE)
bec[is.na(fl_count), fl_count := 0L]
bec[, has_fl := as.integer(fl_count > 0)]
bec[, genuine_n := pmax(n_firms - fl_count, 0L)]
cat("Tenders:", formatC(nrow(bec), big.mark=","), "\n\n")

# ═══════════════════════════════════════════════════════════════════
# TEST 1: FL ENTRY EVENT STUDY (within-PBU)
# ═══════════════════════════════════════════════════════════════════
cat("=== TEST 1: FL Entry Event Study ===\n")

fl_entry <- bec[has_fl == 1, .(first_fl_year = min(year)), by=pbu]
cat("PBUs with FL entry:", nrow(fl_entry), "\n")

panel <- bec[!is.na(log_price), .(
  mean_log_price = mean(log_price, na.rm=TRUE),
  n_tenders = .N,
  pct_fl = mean(has_fl)
), by=.(pbu, year)]

panel <- merge(panel, fl_entry, by="pbu", all.x=TRUE)
panel[is.na(first_fl_year), first_fl_year := 9999L]
panel[, rel_year := year - first_fl_year]
panel[, treated := as.integer(first_fl_year <= 2019)]
panel[, post := as.integer(year >= first_fl_year)]

pbu_counts <- panel[, .N, by=pbu]
pbu_3plus <- pbu_counts[N >= 3, pbu]
panel_es <- panel[pbu %in% pbu_3plus & n_tenders >= 5]
cat("Event study sample:", formatC(nrow(panel_es), big.mark=","), "PBU-years\n")

# TWFE event study
m_es <- tryCatch(
  feols(mean_log_price ~ i(rel_year, treated, ref=-1) | pbu + year,
        data=panel_es[abs(rel_year) <= 4], cluster=~pbu),
  error=function(e) {cat("ES error:", e$message, "\n"); NULL})

if (!is.null(m_es)) {
  cat("Event study estimated.\n")
  cf <- as.data.table(coeftable(m_es), keep.rownames=TRUE)
  setnames(cf, c("term","estimate","se","tstat","pval"))
  cf[, rel_year := as.integer(gsub(".*::(-?\\d+):.*","\\1", term))]
  cf <- cf[!is.na(rel_year)]
  cf[, ci_lo := estimate - 1.96*se]
  cf[, ci_hi := estimate + 1.96*se]

  cat("\nEvent study coefficients:\n")
  print(cf[order(rel_year), .(rel_year, est=round(estimate,4), se=round(se,4), p=round(pval,3))])

  # Plot
  p_es <- ggplot(cf, aes(x=rel_year, y=estimate, ymin=ci_lo, ymax=ci_hi)) +
    geom_hline(yintercept=0, linetype="dashed", color="gray50") +
    geom_vline(xintercept=-0.5, linetype="dotted", color=cb[2], linewidth=0.8) +
    geom_ribbon(alpha=0.15, fill=cb[1]) +
    geom_line(color=cb[1], linewidth=1) +
    geom_point(color=cb[1], size=2.5) +
    labs(x="Years relative to first FL entry in PBU",
         y="Log price (relative to t = -1)") +
    theme_bw(base_size=12) +
    theme(panel.grid.minor=element_blank())
  ggsave(file.path(OUT_F, "fig_fl_entry_event_study.pdf"), p_es,
         width=7, height=4.5, device=cairo_pdf)
  cat("Event study figure saved.\n")
}

# Simple DiD
m_did <- feols(mean_log_price ~ post | pbu + year,
               data=panel_es[treated==1], cluster=~pbu)
cat(sprintf("\nDiD (pre vs post FL entry): %.4f (SE=%.4f, p=%.4f)\n",
    coef(m_did)["post"], sqrt(vcov(m_did)["post","post"]),
    coeftable(m_did)["post","Pr(>|t|)"]))

# ═══════════════════════════════════════════════════════════════════
# TEST 2: MINIMUM-BIDDER CONSTRAINT VARIATION
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 2: Minimum-Bidder Constraint ===\n")

conv_all <- bec[convite == 1 & !is.na(log_price)]
conv_all[, constraint := as.integer(genuine_n < 3)]
conv_all[, item_grp := substr(po_item_merge_key, 23, 30)]

cat("Convite tenders:", formatC(nrow(conv_all), big.mark=","), "\n")
cat("  With FL:", sum(conv_all$has_fl), "\n")
cat("  Constraint binds (n<3):", sum(conv_all$constraint & conv_all$has_fl), "\n")

# FL × constraint interaction
m_inter <- feols(log_price ~ has_fl * constraint | item_grp + year,
                 data=conv_all, cluster=~item_grp)

cat("\nFL × constraint interaction:\n")
cat(sprintf("  FL (n>=3):        %.4f (SE=%.4f, p=%.4f)\n",
    coef(m_inter)["has_fl"], sqrt(vcov(m_inter)["has_fl","has_fl"]),
    coeftable(m_inter)["has_fl","Pr(>|t|)"]))
cat(sprintf("  FL × (n<3):       %.4f (SE=%.4f, p=%.4f)\n",
    coef(m_inter)["has_fl:constraint"],
    sqrt(vcov(m_inter)["has_fl:constraint","has_fl:constraint"]),
    coeftable(m_inter)["has_fl:constraint","Pr(>|t|)"]))
cat(sprintf("  FL total (n<3):   %.4f\n",
    coef(m_inter)["has_fl"] + coef(m_inter)["has_fl:constraint"]))

# ═══════════════════════════════════════════════════════════════════
# SAVE RESULTS
# ═══════════════════════════════════════════════════════════════════
results <- data.frame(
  test = c("fl_entry_did", "fl_constraint_free", "fl_x_constraint", "fl_total_constrained"),
  coef = round(c(coef(m_did)["post"], coef(m_inter)["has_fl"],
    coef(m_inter)["has_fl:constraint"],
    coef(m_inter)["has_fl"] + coef(m_inter)["has_fl:constraint"]), 5),
  se = round(c(sqrt(vcov(m_did)["post","post"]),
    sqrt(vcov(m_inter)["has_fl","has_fl"]),
    sqrt(vcov(m_inter)["has_fl:constraint","has_fl:constraint"]), NA), 5)
)
write.csv(results, file.path(OUT_T, "identification_tests.csv"), row.names=FALSE)
cat("\nResults saved.\n=== DONE ===\n")
