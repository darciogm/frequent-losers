# 76_exposure_adjusted_audit.R
#
# Exposure-adjusted AUC — the falsifiable number Referee 2 (JLEO/JLE Major 1)
# demanded. sec04 calls exposure adjustment "a required audit, not optional
# robustness", but App. D.2 reports prose only and binds no macro. This script
# produces the missing statistic.
#
# The threat (coupon-collector): the cobidder LABEL (always-loser that co-bid in
# the same tender-item as a direct CADE defendant) and the SCORE (participation
# intensity among always-losers) both load on participation volume. A firm that
# participates more has mechanically more chances to intersect a defendant-
# bearing tender-item, independent of any cartel role.
#
# Because a cobidder is BY DEFINITION a realized co-participant, realized
# co-bidding cannot be the conditioning variable (it equals the label). We
# instead condition on OPPORTUNITY at the market level: a firm "could have met"
# a defendant if it participated in the same procurement cell (buyer x year x
# item-group) where defendants are active, WITHOUT requiring the exact tender-
# item. The falsifiable question: among always-losers equally exposed to
# defendant-active markets, does loss intensity still rank cobidders?
#
# Cell = (PBU buyer = substr(oc,1,11), year = substr(oc,12,4),
#         item-group = substr(item,1,2)). Modality dropped: "where support
#         permits" (sec04:134); only buyer/year/item-group are recoverable from
#         award records alone, which is the layer the screen lives in anyway.
#
# PRE-COMMITTED REJECTION REGION (stated before reading results):
#   The award layer adds triage value beyond exposure ONLY IF
#     (i)  the within-opportunity-stratum AUC of the score stays >= 0.70, AND
#     (ii) the score adds >= 0.02 AUC over an exposure-only model (DeLong p<0.05).
#   If the within-opportunity AUC collapses toward 0.5, the 0.924 headline is an
#   exposure artifact and the core claim fails.
#
# Outputs:
#   output/exposure_adjusted_audit/firm_panel.csv
#   output/exposure_adjusted_audit/auc_summary.csv
#   output/exposure_adjusted_audit/audit_log.txt

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow)
  library(pROC); library(MatchIt)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "exposure_adjusted_audit")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)
setDTthreads(12L); set.seed(20260530L)

LOG <- file.path(OUT, "audit_log.txt"); .t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE))/1024), error = function(e) NA_real_)
stamp <- function(s) say("  [%s] elapsed=%.1fs RSS=%s MB", s, as.numeric(difftime(Sys.time(), .t0, units="secs")), rss_mb())

say("=== 76_exposure_adjusted_audit.R ===")
say("host=%s nproc=%s date=%s", Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e) "?"), format(Sys.time()))

# ---------- (0) firm classes -------------------------------------------------
cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cob$firm_code)
say("cobidder positives: %d", length(cob_codes))

xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(xm$firm_code)
say("direct CADE defendants: %d", length(direct_codes))

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, cobidder := as.integer(firm_code %in% cob_codes)]
al[, fl14     := as.integer(tenders_count >= 14L)]
al[, log_tc   := log1p(tenders_count)]
say("always-losers: %d  (cobidders in universe: %d)", nrow(al), al[cobidder==1, .N])
stamp("classes")

# ---------- (1) opportunity from firm_tender_map -----------------------------
# CADE-active cell = (PBU, year, item-group) where any direct defendant bids.
# opportunity = # distinct tender-items a firm bid on inside CADE-active cells
#               (potential to meet a defendant; NOT realized co-bidding).
ftm_path <- file.path(BASE, "data/processed/firm_tender_map.parquet")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)

opp <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc,
           CAST(\"códigoitem\" AS VARCHAR)  AS item,
           SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),1,11) AS pbu,
           SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS yr,
           SUBSTR(CAST(\"códigoitem\" AS VARCHAR),1,2)  AS ig
    FROM read_parquet('%s')
  ),
  cade_cells AS (
    SELECT DISTINCT f.pbu, f.yr, f.ig
    FROM ftm f JOIN direct d ON f.firm_code = d.firm_code
  ),
  firm_opp AS (
    SELECT f.firm_code,
           COUNT(DISTINCT (f.oc || '|' || f.item))            AS n_items_total,
           COUNT(DISTINCT CASE WHEN c.pbu IS NOT NULL
                 THEN (f.oc || '|' || f.item) END)             AS n_opp_items,
           COUNT(DISTINCT CASE WHEN c.pbu IS NOT NULL
                 THEN (f.pbu||'|'||f.yr||'|'||f.ig) END)       AS n_opp_cells
    FROM ftm f
    LEFT JOIN cade_cells c USING (pbu, yr, ig)
    GROUP BY f.firm_code
  )
  SELECT * FROM firm_opp
", ftm_path)))
dbDisconnect(con, shutdown = TRUE)
say("firms with opportunity computed: %s", format(nrow(opp), big.mark=","))
stamp("opportunity")

# ---------- (2) assemble always-loser panel ---------------------------------
dt <- merge(al, opp, by = "firm_code", all.x = TRUE)
for (v in c("n_items_total","n_opp_items","n_opp_cells"))
  dt[is.na(get(v)), (v) := 0L]
dt[, exposed := as.integer(n_opp_items > 0L)]
dt[, log_opp := log1p(n_opp_items)]
fwrite(dt, file.path(OUT, "firm_panel.csv"))
say("\nPanel: %d always-losers; exposed(opp>0)=%d (%.1f%%); cobidders=%d (all exposed=%s)",
    nrow(dt), dt[exposed==1,.N], 100*mean(dt$exposed), dt[cobidder==1,.N],
    all(dt[cobidder==1, exposed]==1))
say("cobidders among exposed=%d ; non-cobidder controls among exposed=%d",
    dt[exposed==1 & cobidder==1,.N], dt[exposed==1 & cobidder==0,.N])
stamp("panel")

# ---------- (3) AUC helpers --------------------------------------------------
auc1 <- function(label, score, dat) {
  r <- pROC::roc(dat[[label]], dat[[score]], quiet = TRUE, direction = "<")
  ci <- pROC::ci.auc(r)
  list(auc = as.numeric(r$auc), lo = ci[1], hi = ci[3], n = nrow(dat),
       npos = sum(dat[[label]]==1))
}
# Stratified (pooled within-stratum) C-statistic: concordant pairs / comparable
# pairs summed across strata. This is the "within comparable opportunity sets"
# AUC the referee asked for.
strat_auc <- function(dat, score, label, stratum) {
  num <- 0; den <- 0
  for (s in unique(dat[[stratum]])) {
    sub <- dat[dat[[stratum]] == s]
    p <- sub[[score]][sub[[label]]==1]; n <- sub[[score]][sub[[label]]==0]
    if (length(p) == 0 || length(n) == 0) next
    # concordant + 0.5 ties over all pos x neg pairs
    cmp <- outer(p, n, function(a,b) (a>b) + 0.5*(a==b))
    num <- num + sum(cmp); den <- den + length(p)*length(n)
  }
  list(auc = if (den>0) num/den else NA_real_, comparable_pairs = den)
}

res <- list()
add <- function(name, universe, score, a)
  res[[length(res)+1L]] <<- data.table(metric=name, universe=universe, score=score,
    auc=a$auc, ci_lo=a$lo %||% NA, ci_hi=a$hi %||% NA, n=a$n %||% NA, npos=a$npos %||% NA)
`%||%` <- function(x,y) if (is.null(x)) y else x

# ---------- (4) baseline (replicate headline) + missing scope row -----------
say("\n[4] Unconditional AUC over all %d always-losers:", nrow(dt))
a_fl  <- auc1("cobidder","fl14",  dt); add("unconditional","all_AL","fl14_binary", a_fl)
a_log <- auc1("cobidder","log_tc",dt); add("unconditional","all_AL","log_tc", a_log)
a_raw <- auc1("cobidder","tenders_count",dt); add("unconditional","all_AL","tenders_count_raw", a_raw)
say("  FL14 binary      AUC=%.4f [%.4f, %.4f]  (headline \\valAUCFLfirm 0.924)", a_fl$auc, a_fl$lo, a_fl$hi)
say("  log_tc           AUC=%.4f [%.4f, %.4f]  (\\valScopeRowTwo 0.939)", a_log$auc, a_log$lo, a_log$hi)
say("  tenders_count    AUC=%.4f [%.4f, %.4f]  (MISSING SCOPE ROW B: raw participation count)", a_raw$auc, a_raw$lo, a_raw$hi)

# ---------- (5) opportunity-only model (exposure baseline) ------------------
say("\n[5] Exposure-only AUC (can pure opportunity reproduce the label?):")
a_opp <- auc1("cobidder","log_opp",dt); add("exposure_only","all_AL","log_opportunity", a_opp)
say("  log(opportunity) AUC=%.4f [%.4f, %.4f]", a_opp$auc, a_opp$lo, a_opp$hi)

# ---------- (6) EXPOSURE-RESTRICTED universe (opp>0) -------------------------
ex <- dt[exposed == 1]
say("\n[6] Among exposed firms only (opp>0, N=%d, pos=%d):", nrow(ex), ex[cobidder==1,.N])
a_fl_e  <- auc1("cobidder","fl14",ex);   add("exposed_only","opp>0","fl14_binary", a_fl_e)
a_log_e <- auc1("cobidder","log_tc",ex); add("exposed_only","opp>0","log_tc", a_log_e)
say("  FL14   AUC=%.4f [%.4f, %.4f]", a_fl_e$auc, a_fl_e$lo, a_fl_e$hi)
say("  log_tc AUC=%.4f [%.4f, %.4f]", a_log_e$auc, a_log_e$lo, a_log_e$hi)

# ---------- (7) WITHIN-OPPORTUNITY-STRATUM AUC (headline exposure-adjusted) --
# Strata = deciles of opportunity count among exposed firms. Holds the AMOUNT of
# opportunity fixed; asks whether loss intensity still ranks cobidders within.
ex[, opp_decile := cut(n_opp_items, breaks = unique(quantile(n_opp_items, probs=seq(0,1,0.1))),
                       include.lowest = TRUE, labels = FALSE)]
s_log <- strat_auc(ex, "log_tc", "cobidder", "opp_decile")
s_fl  <- strat_auc(ex, "fl14",   "cobidder", "opp_decile")
add("within_opp_stratum","opp>0 x opp-decile","log_tc",
    list(auc=s_log$auc, lo=NA, hi=NA, n=nrow(ex), npos=ex[cobidder==1,.N]))
add("within_opp_stratum","opp>0 x opp-decile","fl14",
    list(auc=s_fl$auc, lo=NA, hi=NA, n=nrow(ex), npos=ex[cobidder==1,.N]))
say("\n[7] WITHIN-OPPORTUNITY-STRATUM pooled C-statistic (HEADLINE exposure-adjusted):")
say("  log_tc  AUC=%.4f  (comparable pairs=%s)", s_log$auc, format(s_log$comparable_pairs, big.mark=","))
say("  FL14    AUC=%.4f  (comparable pairs=%s)", s_fl$auc,  format(s_fl$comparable_pairs, big.mark=","))

# ---------- (8) incremental AUC over exposure (logit, same sample) ----------
say("\n[8] Incremental AUC of score OVER exposure model (DeLong, exposed firms):")
ex$cobidder <- as.integer(ex$cobidder)
m_opp  <- glm(cobidder ~ log_opp, data = ex, family = binomial())
m_full <- glm(cobidder ~ log_opp + log_tc, data = ex, family = binomial())
r_opp  <- pROC::roc(ex$cobidder, predict(m_opp,  type="response"), quiet=TRUE, direction="<")
r_full <- pROC::roc(ex$cobidder, predict(m_full, type="response"), quiet=TRUE, direction="<")
dl <- pROC::roc.test(r_opp, r_full, method="delong", paired=TRUE)
add("logit_exposure_only","opp>0","exposure_logit",
    list(auc=as.numeric(r_opp$auc), lo=NA,hi=NA,n=nrow(ex),npos=ex[cobidder==1,.N]))
add("logit_exposure_plus_score","opp>0","exposure+score_logit",
    list(auc=as.numeric(r_full$auc), lo=NA,hi=NA,n=nrow(ex),npos=ex[cobidder==1,.N]))
say("  exposure-only logit AUC = %.4f", as.numeric(r_opp$auc))
say("  exposure+score logit AUC = %.4f", as.numeric(r_full$auc))
say("  increment = %+.4f ; DeLong Z=%.3f p=%.3g", as.numeric(r_full$auc-r_opp$auc), dl$statistic, dl$p.value)
say("  score coef (log_tc) in full logit = %+.4f (z=%.2f, p=%.3g)",
    coef(summary(m_full))["log_tc","Estimate"], coef(summary(m_full))["log_tc","z value"],
    coef(summary(m_full))["log_tc","Pr(>|z|)"])

# ---------- (9) CEM matching on opportunity, AUC of score in matched sample --
say("\n[9] CEM on opportunity deciles (mirror script 74 discipline), AUC of log_tc in matched sample:")
cutp <- unique(quantile(ex$n_opp_items, probs=seq(0,1,0.1)))
mm <- tryCatch(matchit(cobidder ~ n_opp_items, data = ex, method="cem",
                       cutpoints = list(n_opp_items = cutp)), error=function(e) NULL)
if (!is.null(mm)) {
  md <- as.data.table(match.data(mm))
  smd_raw <- (mean(ex[cobidder==1,n_opp_items]) - mean(ex[cobidder==0,n_opp_items])) /
             sqrt((var(ex[cobidder==1,n_opp_items])+var(ex[cobidder==0,n_opp_items]))/2)
  smd_m  <- (weighted.mean(md[cobidder==1,n_opp_items], md[cobidder==1,weights]) -
             weighted.mean(md[cobidder==0,n_opp_items], md[cobidder==0,weights])) /
             sqrt((var(md[cobidder==1,n_opp_items])+var(md[cobidder==0,n_opp_items]))/2)
  a_m <- auc1("cobidder","log_tc",md)
  add("cem_opp_matched","opp-CEM","log_tc", a_m)
  say("  opportunity SMD raw=%.3f -> matched=%.3f ; matched N=%d (pos=%d)",
      smd_raw, smd_m, nrow(md), md[cobidder==1,.N])
  say("  log_tc AUC in opportunity-matched sample = %.4f [%.4f, %.4f]", a_m$auc, a_m$lo, a_m$hi)
}

# ---------- (10) verdict against pre-committed rejection region -------------
hl <- s_log$auc                       # headline within-opportunity-stratum AUC
incr <- as.numeric(r_full$auc - r_opp$auc)
say("\n========== VERDICT vs PRE-COMMITTED REJECTION REGION ==========")
say("  (i)  within-opportunity-stratum AUC (log_tc) = %.4f   [pass if >= 0.70]: %s",
    hl, ifelse(hl >= 0.70, "PASS", "FAIL"))
say("  (ii) increment over exposure-only = %+.4f (DeLong p=%.3g)  [pass if >=0.02 & p<0.05]: %s",
    incr, dl$p.value, ifelse(incr >= 0.02 & dl$p.value < 0.05, "PASS", "FAIL"))
say("  OVERALL: %s", ifelse(hl >= 0.70 & incr >= 0.02 & dl$p.value < 0.05,
    "award layer adds triage value BEYOND exposure", "claim NOT supported beyond exposure"))

out <- rbindlist(res, fill = TRUE)
fwrite(out, file.path(OUT, "auc_summary.csv"))
say("\nWrote %s", file.path(OUT, "auc_summary.csv"))
stamp("DONE")
