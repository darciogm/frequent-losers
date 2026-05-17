# Bunching feasibility at R$80k threshold (item-auction level, not bidder-item)
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(ggplot2); library(rdrobust); library(rddensity)
})

PROJ_ROOT <- getwd()
dt <- as.data.table(read_parquet(file.path(PROJ_ROOT, "data/processed/paper2_me_epp.parquet")))
TREAT_DATE <- 698L; WIN_18M <- c(680L, 715L); THRESH <- 80000

dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, Post := as.integer(data_oc_numb >= TREAT_DATE)]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == 6531L)]

# Collapse to ITEM-AUCTION level: one row per (item_alt × data_oc_numb)
# Within an item-auction, valor_total_ref + lpreco_final + lpreco_ref + g65 are constants
items <- dt[, .(
  vtr = first(valor_total_ref),
  lpf = first(lpreco_final),
  lpr = first(lpreco_ref),
  g65 = first(g65),
  Post = first(Post),
  pharma = first(pharma),
  num_bids = first(num_bids),
  data_oc_numb = first(data_oc_numb),
  n_bidder_rows = .N
), by = .(item_alt)]

cat("=== Feasibility (item-auction level) ===\n")
cat("Total item-auctions in window:", format(nrow(items), big.mark=","), "\n")
cat("Group 65 items:", format(sum(items$g65), big.mark=","), "\n")
cat("Group 65 post:", format(sum(items$g65 == 1 & items$Post == 1), big.mark=","), "\n\n")

# Distribution of valor_total_ref
cat("valor_total_ref summary (g65 items):\n")
print(summary(items[g65 == 1, vtr]))
cat("\nQuantiles around R$80k threshold (g65 items):\n")
print(quantile(items[g65 == 1, vtr], probs = c(0.5, 0.75, 0.9, 0.95, 0.99), na.rm = TRUE))

# Sample sizes around threshold by band
cat("\nSample sizes around R$80k (item-auction level):\n")
for (pct in c(0.10, 0.20, 0.30, 0.50)) {
  lo <- THRESH * (1 - pct); hi <- THRESH * (1 + pct)
  n_post_g65 <- items[g65 == 1 & Post == 1 & vtr >= lo & vtr <= hi, .N]
  n_below <- items[g65 == 1 & Post == 1 & vtr >= lo & vtr <= THRESH, .N]
  n_above <- items[g65 == 1 & Post == 1 & vtr >  THRESH & vtr <= hi, .N]
  n_pre_g65 <- items[g65 == 1 & Post == 0 & vtr >= lo & vtr <= hi, .N]
  n_post_np <- items[g65 == 1 & pharma == 0 & Post == 1 & vtr >= lo & vtr <= hi, .N]
  n_post_ph <- items[g65 == 1 & pharma == 1 & Post == 1 & vtr >= lo & vtr <= hi, .N]
  cat(sprintf("  ±%2.0f%%: g65 post = %s (%s below/%s above); g65 pre = %s; NP/PH = %s/%s\n",
              100*pct, format(n_post_g65, big.mark=","),
              format(n_below, big.mark=","), format(n_above, big.mark=","),
              format(n_pre_g65, big.mark=","),
              format(n_post_np, big.mark=","), format(n_post_ph, big.mark=",")))
}

# McCrary density test at R$80k (g65 post)
cat("\n[Density test] manipulation around R$80k:\n")
for (period_label in c("Pre", "Post")) {
  per <- if (period_label == "Pre") 0 else 1
  x <- items[g65 == 1 & Post == per & is.finite(vtr) & vtr > 1000 & vtr < 1e7, vtr]
  cat(sprintf("  %s (n = %s):\n", period_label, format(length(x), big.mark=",")))
  dt_test <- tryCatch(
    rddensity::rddensity(X = x, c = THRESH),
    error = function(e) { cat("    failed:", conditionMessage(e), "\n"); NULL }
  )
  if (!is.null(dt_test)) {
    cat(sprintf("    T-stat: %.3f, p = %.4f, h_left=%.0f, h_right=%.0f\n",
                dt_test$test$t_jk, dt_test$test$p_jk,
                dt_test$h$left, dt_test$h$right))
  }
}

# Quick RD on log(p_final/p_ref) for g65 post-period
items[, lpf_norm := lpf - lpr]
items[, vtr_dev := vtr - THRESH]

rd_sample <- items[g65 == 1 & Post == 1 & is.finite(lpf_norm) & is.finite(vtr) & vtr > 0]
cat(sprintf("\n[RD] sample (g65 post, valid lpf_norm + vtr): %s obs\n",
            format(nrow(rd_sample), big.mark=",")))

cat("\n[RD] rdrobust on log(p_final/p_ref):\n")
rd_out <- tryCatch({
  rdrobust::rdrobust(y = rd_sample$lpf_norm, x = rd_sample$vtr, c = THRESH, all = TRUE)
}, error = function(e) { cat("  failed:", conditionMessage(e), "\n"); NULL })
if (!is.null(rd_out)) {
  cat(sprintf("  Conventional: %.4f (SE %.4f), p = %.4f\n", rd_out$coef[1], rd_out$se[1], rd_out$pv[1]))
  cat(sprintf("  Robust:       %.4f (SE %.4f), p = %.4f\n", rd_out$coef[3], rd_out$se[3], rd_out$pv[3]))
  cat(sprintf("  N left/right: %d/%d\n", rd_out$N_h[1], rd_out$N_h[2]))
  cat(sprintf("  Bandwidth h:  %.0f\n", rd_out$bws[1,1]))
}

# Same RD on lpreco_final to check direction
cat("\n[RD] rdrobust on log(p_final):\n")
rd_out2 <- tryCatch({
  rdrobust::rdrobust(y = rd_sample$lpf, x = rd_sample$vtr, c = THRESH, all = TRUE)
}, error = function(e) NULL)
if (!is.null(rd_out2)) {
  cat(sprintf("  Robust:       %.4f (SE %.4f), p = %.4f\n", rd_out2$coef[3], rd_out2$se[3], rd_out2$pv[3]))
  cat(sprintf("  N left/right: %d/%d, h = %.0f\n", rd_out2$N_h[1], rd_out2$N_h[2], rd_out2$bws[1,1]))
}

# Falsification: same RD on g65 PRE-period (threshold shouldn't bite then)
rd_pre <- items[g65 == 1 & Post == 0 & is.finite(lpf_norm) & is.finite(vtr) & vtr > 0]
cat(sprintf("\n[RD-falsification] same RD on g65 PRE-period (threshold should NOT bite): n = %s\n",
            format(nrow(rd_pre), big.mark=",")))
rd_pre_out <- tryCatch({
  rdrobust::rdrobust(y = rd_pre$lpf_norm, x = rd_pre$vtr, c = THRESH, all = TRUE)
}, error = function(e) NULL)
if (!is.null(rd_pre_out)) {
  cat(sprintf("  Robust: %.4f (SE %.4f), p = %.4f, h = %.0f\n",
              rd_pre_out$coef[3], rd_pre_out$se[3], rd_pre_out$pv[3], rd_pre_out$bws[1,1]))
}

cat("\n=== Feasibility check complete ===\n")
