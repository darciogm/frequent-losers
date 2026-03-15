# Fix Warning 3: Correct CV computation for Imhof screen
suppressPackageStartupMessages({
  library(data.table); library(fixest); library(arrow)
})
setDTthreads(16L); setFixest_nthreads(16L); setFixest_estimation(lean=TRUE)

cat("Loading data...\n")
dt <- readRDS("/tmp/p3v4_prepared.rds")

# Load bid_price_mean from BEC (correct denominator)
bec <- as.data.table(read_parquet("data/processed/BEC_collapse_final.parquet",
  col_select = c("po_item_merge_key", "bid_price_sd", "bid_price_mean")))
dt <- merge(dt, bec[, .(po_item_merge_key, bec_sd=bid_price_sd, bec_mean=bid_price_mean)],
            by="po_item_merge_key", all.x=TRUE)
rm(bec); gc(verbose=FALSE)

# Correct CV
dt[, cv_bids := fifelse(bec_sd > 0 & bec_mean > 0 & !is.na(bec_sd) & !is.na(bec_mean),
                         bec_sd / bec_mean, NA_real_)]
cat(sprintf("CV stats: median=%.4f, mean=%.4f, N=%d\n",
    median(dt$cv_bids, na.rm=TRUE), mean(dt$cv_bids, na.rm=TRUE), sum(!is.na(dt$cv_bids))))

# Item-group median split
cv_med <- dt[!is.na(cv_bids), .(cv_median = median(cv_bids)), by = item_group]
dt <- merge(dt, cv_med, by="item_group", all.x=TRUE)
dt[, imhof_flag := as.integer(!is.na(cv_bids) & cv_bids > cv_median)]
cat(sprintf("Imhof flag=1: %d (%.1f%%)\n", sum(dt$imhof_flag, na.rm=TRUE),
    100*mean(dt$imhof_flag, na.rm=TRUE)))

# Horse race
d <- dt[!is.na(lneg_price) & !is.na(imhof_flag)]
m1 <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f, data=d, cluster=~item_f, fixef.rm="none")
m2 <- feols(lneg_price ~ imhof_flag + convite | item_f + year_f + pbu_f, data=d, cluster=~item_f, fixef.rm="none")
m3 <- feols(lneg_price ~ losers + imhof_flag + convite | item_f + year_f + pbu_f, data=d, cluster=~item_f, fixef.rm="none")

cat("\nResults:\n")
cat(sprintf("  FL only: %.4f (%.4f)\n", coef(m1)["losers"], sqrt(vcov(m1)["losers","losers"])))
cat(sprintf("  Imhof only: %.4f (%.4f)\n", coef(m2)["imhof_flag"], sqrt(vcov(m2)["imhof_flag","imhof_flag"])))
cat(sprintf("  Horse race FL: %.4f (%.4f)\n", coef(m3)["losers"], sqrt(vcov(m3)["losers","losers"])))
cat(sprintf("  Horse race Imhof: %.4f (%.4f)\n", coef(m3)["imhof_flag"], sqrt(vcov(m3)["imhof_flag","imhof_flag"])))
cat(sprintf("  Correlation(FL, Imhof): %.4f\n", cor(d$losers, d$imhof_flag, use="complete.obs")))

# Stars helper
ps <- function(p) ifelse(p<0.01,"***",ifelse(p<0.05,"**",ifelse(p<0.1,"*","")))
pf <- function(x,d=4) formatC(x,format="f",digits=d,big.mark=",")

OUT <- "work/v5/tables/tab_screen_horserace.tex"
get_row <- function(m, var, label) {
  b <- coef(m)[var]; se <- sqrt(vcov(m)[var,var]); p <- 2*pnorm(-abs(b/se))
  c(sprintf("%s & %s%s &", label, pf(b), ps(p)),
    sprintf(" & (%s) &", pf(se)))
}

lines <- c(
"\\begin{table}[htbp]","\\centering",
"\\caption{FL Screen vs.\\ Imhof-Style Bid-Level Screens: Horse-Race Regression}",
"\\label{tab:screen_horserace}",
"\\begin{adjustbox}{max width=\\textwidth}",
"\\begin{threeparttable}","\\small",
"\\begin{tabular}{lccc}","\\toprule",
" & (1) FL only & (2) Imhof only & (3) Horse race \\\\","\\midrule")

# FL rows
b1 <- coef(m1)["losers"]; se1 <- sqrt(vcov(m1)["losers","losers"]); p1 <- 2*pnorm(-abs(b1/se1))
b3 <- coef(m3)["losers"]; se3 <- sqrt(vcov(m3)["losers","losers"]); p3 <- 2*pnorm(-abs(b3/se3))
lines <- c(lines,
  sprintf("FL presence & %s%s & & %s%s \\\\", pf(b1), ps(p1), pf(b3), ps(p3)),
  sprintf(" & (%s) & & (%s) \\\\", pf(se1), pf(se3)))

# Imhof rows
b2 <- coef(m2)["imhof_flag"]; se2 <- sqrt(vcov(m2)["imhof_flag","imhof_flag"]); p2 <- 2*pnorm(-abs(b2/se2))
b3i <- coef(m3)["imhof_flag"]; se3i <- sqrt(vcov(m3)["imhof_flag","imhof_flag"]); p3i <- 2*pnorm(-abs(b3i/se3i))
lines <- c(lines,
  sprintf("Imhof flag (above-median CV) & & %s%s & %s%s \\\\", pf(b2), ps(p2), pf(b3i), ps(p3i)),
  sprintf(" & & (%s) & (%s) \\\\", pf(se2), pf(se3i)))

lines <- c(lines, "\\midrule",
  sprintf("Observations & \\multicolumn{3}{c}{%s} \\\\", formatC(nrow(d),format="d",big.mark=",")),
  sprintf("Correlation(FL, Imhof) & \\multicolumn{3}{c}{%.3f} \\\\",
    cor(d$losers, d$imhof_flag, use="complete.obs")),
  "Item + Year + PBU FE & YES & YES & YES \\\\",
  "\\bottomrule","\\end{tabular}",
  "\\begin{tablenotes}","\\small",
  paste0("\\item \\textit{Notes:} DV: log negotiated price. Imhof flag = 1 if the ",
         "within-item-group coefficient of variation of bid prices exceeds the item-group median. ",
         "CV computed as bid\\_price\\_sd / bid\\_price\\_mean from BEC records. ",
         "SE clustered at item level. *** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."),
  "\\end{tablenotes}","\\end{threeparttable}",
  "\\end{adjustbox}","\\end{table}")

writeLines(lines, OUT)
cat("Saved:", OUT, "\n")
