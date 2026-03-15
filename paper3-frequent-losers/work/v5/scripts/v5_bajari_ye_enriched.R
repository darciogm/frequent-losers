# ============================================================================
# v5_bajari_ye_enriched.R — Enriched Bajari-Ye first stage (referee M3)
# Uses v2/data/processed/bid_level_analysis.parquet (has bid_price, ref_price, is_fl)
# ============================================================================
suppressPackageStartupMessages({
  library(data.table); library(fixest); library(arrow)
})
setDTthreads(16L); setFixest_nthreads(16L); setFixest_estimation(lean = FALSE)  # need residuals

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT  <- file.path(BASE, "work/v5/tables/tab_bajari_ye_enriched.tex")

cat("=== Enriched Bajari-Ye First Stage ===\n")

# ---- Load bid-level data with prices ----------------------------------------
cat("Loading bid_level_analysis.parquet (40M rows)...\n")
bids <- as.data.table(read_parquet(file.path(BASE, "v2/data/processed/bid_level_analysis.parquet")))
cat(sprintf("  Loaded: %s rows\n", formatC(nrow(bids), big.mark=",")))

# ---- Load firm characteristics -----------------------------------------------
cat("Loading firm characteristics...\n")
firms <- as.data.table(read_parquet(file.path(BASE, "data/processed/Firms_final.parquet"),
  col_select = c("códigofornecedor", "porte_empresa", "cnae_fiscal", "data_inicio_atividade")))
setnames(firms, "códigofornecedor", "firm_id")
firms[, cnae_sector := substr(as.character(cnae_fiscal), 1, 2)]
firms[, firm_age := as.numeric(difftime(as.Date("2014-07-01"),
  as.Date(data_inicio_atividade), units="days")) / 365.25]

# ---- Merge -------------------------------------------------------------------
bids <- merge(bids, firms[, .(firm_id, porte_empresa, cnae_sector, firm_age)],
              by = "firm_id", all.x = TRUE)

# ---- Filter to losing bids with valid prices ----------------------------------
bids <- bids[won == 0 & !is.na(bid_price) & bid_price > 0]
cat(sprintf("  Losing bids with valid prices: %s\n", formatC(nrow(bids), big.mark=",")))

# ---- Create variables ---------------------------------------------------------
bids[, log_bid := log(bid_price)]
bids[, log_ref := fifelse(!is.na(ref_price) & ref_price > 0, log(ref_price), NA_real_)]

# Extract year from MM/YYYY format
bids[, year := as.integer(sub(".*/", "", as.character(month_year)))]
cat(sprintf("  Year range: %d - %d\n", min(bids$year, na.rm=TRUE), max(bids$year, na.rm=TRUE)))

bids[, tender_id := paste0(oc_code, "_", item_code)]
bids[, item_f := as.factor(item_code)]
bids[, year_f := as.factor(year)]

# ---- Sample for tractability -------------------------------------------------
if (nrow(bids) > 5e6) {
  set.seed(42)
  tids <- unique(bids$tender_id)
  n_t <- min(500000L, length(tids))
  bids <- bids[tender_id %chin% sample(tids, n_t)]
  cat(sprintf("  Sampled to %s rows\n", formatC(nrow(bids), big.mark=",")))
}

cat(sprintf("  FL bids: %s (%.1f%%)\n",
  formatC(sum(bids$is_fl == 1, na.rm=TRUE), big.mark=","),
  100 * mean(bids$is_fl == 1, na.rm=TRUE)))

# ---- Model 1: Baseline --------------------------------------------------------
cat("\nModel 1: Baseline (porte + item/year FE)...\n")
d1 <- bids[!is.na(porte_empresa)]
m1 <- tryCatch(feols(log_bid ~ porte_empresa | item_f + year_f, data=d1, fixef.rm="none"),
               error=function(e){cat("  Failed:",e$message,"\n"); NULL})
r2_1 <- NA_real_
if (!is.null(m1)) {
  r2_1 <- fitstat(m1, "r2")$r2
  cat(sprintf("  R2=%.4f, N=%s\n", r2_1, formatC(nobs(m1), big.mark=",")))
  d1[, resid_base := residuals(m1)]
}

# ---- Model 2: Enriched --------------------------------------------------------
cat("Model 2: Enriched (+ref price, age, CNAE)...\n")
# Enriched: porte + firm_age + cnae_sector (ref_price only 3.2% coverage at bid level)
d2 <- bids[!is.na(porte_empresa) & !is.na(firm_age)]
d2[, cnae_s := fifelse(!is.na(cnae_sector) & cnae_sector != "" & cnae_sector != "NA",
                        cnae_sector, "UNK")]
cat(sprintf("  Valid obs: %s\n", formatC(nrow(d2), big.mark=",")))
m2 <- tryCatch(feols(log_bid ~ porte_empresa + firm_age + cnae_s | item_f + year_f,
                      data=d2, fixef.rm="none"),
               error=function(e){cat("  Failed:",e$message,"\n"); NULL})
r2_2 <- NA_real_
if (!is.null(m2)) {
  r2_2 <- fitstat(m2, "r2")$r2
  cat(sprintf("  R2=%.4f, N=%s\n", r2_2, formatC(nobs(m2), big.mark=",")))
  d2[, resid_enr := residuals(m2)]
}

# ---- Model 3: No FE -----------------------------------------------------------
cat("Model 3: No FE...\n")
m3 <- tryCatch(feols(log_bid ~ porte_empresa + firm_age + cnae_s, data=d2, fixef.rm="none"),
               error=function(e){cat("  Failed:",e$message,"\n"); NULL})
r2_3 <- if(!is.null(m3)) fitstat(m3,"r2")$r2 else NA_real_
if(!is.na(r2_3)) cat(sprintf("  R2 (no FE)=%.4f\n", r2_3))

# ---- KS Tests -----------------------------------------------------------------
cat("\nKS tests...\n")
run_ks <- function(rc, d, lab) {
  fl <- d[is_fl==1, get(rc)]; nfl <- d[is_fl==0, get(rc)]
  fl <- fl[!is.na(fl)]; nfl <- nfl[!is.na(nfl)]
  if(length(fl)<10||length(nfl)<10) return(list(D=NA,p=NA))
  ks <- ks.test(fl, nfl)
  cat(sprintf("  %s: D=%.4f, p=%.2e\n", lab, ks$statistic, ks$p.value))
  list(D=ks$statistic, p=ks$p.value)
}
ks1 <- if(!is.null(m1)) run_ks("resid_base",d1,"Baseline") else list(D=NA,p=NA)
ks2 <- if(!is.null(m2)) run_ks("resid_enr",d2,"Enriched") else list(D=NA,p=NA)

# ---- Pairwise Products -------------------------------------------------------
cat("\nPairwise products...\n")
comp_pp <- function(rc, d, fl_v, lab) {
  sub <- d[is_fl==fl_v & !is.na(get(rc))]
  sub[, ntend := .N, by=tender_id]
  sub <- sub[ntend >= 2]
  if(nrow(sub)==0){cat(sprintf("  %s: no tenders\n",lab)); return(NA)}
  tids <- unique(sub$tender_id)
  if(length(tids)>50000){set.seed(42);tids<-sample(tids,50000);sub<-sub[tender_id%chin%tids]}
  pp <- sub[, {r<-get(rc); if(length(r)>=2){p<-combn(r,2); .(v=mean(p[1,]*p[2,]))} else .(v=NA_real_)}, by=tender_id]
  res <- mean(pp$v, na.rm=TRUE)
  cat(sprintf("  %s: %.4f (N=%d tenders)\n", lab, res, sum(!is.na(pp$v))))
  res
}
pp1f <- pp1n <- pp2f <- pp2n <- NA_real_
if(!is.null(m1)){pp1f<-comp_pp("resid_base",d1,1,"Base FL"); pp1n<-comp_pp("resid_base",d1,0,"Base non-FL")}
if(!is.null(m2)){pp2f<-comp_pp("resid_enr",d2,1,"Enr FL"); pp2n<-comp_pp("resid_enr",d2,0,"Enr non-FL")}

# ---- Write LaTeX --------------------------------------------------------------
cat("\nWriting table...\n")
pf <- function(x,d=4) if(is.na(x)) "---" else formatC(x,format="f",digits=d)
pp_fmt <- function(x) if(is.na(x)||x>=0.001) pf(x,4) else "$<$0.001"

L <- c(
"\\begin{table}[htbp]","\\centering",
"\\caption{Bajari--Ye Tests: Baseline vs.\\ Enriched First Stage}",
"\\label{tab:bajari_ye_enriched}",
"\\begin{adjustbox}{max width=\\textwidth}",
"\\begin{threeparttable}","\\small",
"\\begin{tabular}{lcc}","\\toprule",
" & Baseline & Enriched \\\\",
" & (porte + item/year FE) & (+age, CNAE sector) \\\\",
"\\midrule",
"\\textit{Panel A: First-Stage $R^2$} & & \\\\",
sprintf("\\quad $R^2$ & %s & %s \\\\", pf(r2_1), pf(r2_2)),
sprintf("\\quad $R^2$ (no FE) & --- & %s \\\\", pf(r2_3)),
sprintf("\\quad Observations & %s & %s \\\\",
  if(!is.null(m1)) formatC(nobs(m1),big.mark=",") else "---",
  if(!is.null(m2)) formatC(nobs(m2),big.mark=",") else "---"),
"[6pt]",
"\\textit{Panel B: Exchangeability (KS test)} & & \\\\",
sprintf("\\quad $D$ statistic & %s & %s \\\\", pf(ks1$D), pf(ks2$D)),
sprintf("\\quad $p$-value & %s & %s \\\\", pp_fmt(ks1$p), pp_fmt(ks2$p)),
"[6pt]",
"\\textit{Panel C: Conditional Independence} & & \\\\",
sprintf("\\quad FL pairwise product & %s & %s \\\\", pf(pp1f), pf(pp2f)),
sprintf("\\quad Non-FL pairwise product & %s & %s \\\\", pf(pp1n), pf(pp2n)),
sprintf("\\quad Difference (FL $-$ non-FL) & %s & %s \\\\",
  if(!is.na(pp1f)&&!is.na(pp1n)) pf(pp1f-pp1n) else "---",
  if(!is.na(pp2f)&&!is.na(pp2n)) pf(pp2f-pp2n) else "---"),
"\\bottomrule","\\end{tabular}",
"\\begin{tablenotes}","\\small",
paste0("\\item \\textit{Notes:} Panel A: auxiliary bid regression of $\\log(\\text{bid})$ on ",
"cost shifters. Baseline includes firm size (porte) and item + year FE. ",
"Enriched adds firm age and CNAE sector (2-digit). Reference price is a tender-level ",
"variable (only 3.2\\% coverage at bid level) and is absorbed by item FE. ",
"Panel B: KS test on FL vs.\\ non-FL residuals. ",
"Panel C: mean product of pairwise within-tender residuals ",
"(sampled up to 50K tenders for tractability). ",
"Sample: losing bids only."),
"\\end{tablenotes}","\\end{threeparttable}",
"\\end{adjustbox}","\\end{table}")

writeLines(L, OUT)
cat("Saved:", OUT, "\n\nDone.\n")
