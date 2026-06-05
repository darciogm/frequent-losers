#!/usr/bin/env Rscript
# 12b_audit_armor_fixup.R -- parts B-E of the armor pack (A done in 12) + the
# label-blind within-stratum diagnostic motivated by A's leakage finding.
suppressPackageStartupMessages({ library(DBI); library(duckdb); library(data.table) })
set.seed(20260605L)
say <- function(...) cat(sprintf(...), "\n")
fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
SD <- if (length(fa)) dirname(normalizePath(fa[1])) else getwd()
REPO <- normalizePath(file.path(SD, "..", "..", "..", ".."))
V22  <- file.path(REPO, "work", "v22-editor")
OUT  <- file.path(V22, "outputs", "diagnostics", "audit_armor")
source(file.path(V22, "scripts", "utils", "metrics_triage.R"))
ftm_path <- file.path(REPO, "data", "processed", "firm_tender_map.parquet")
frame <- fread(file.path(V22, "outputs", "cache", "firm_opportunity_adjusted_frame.csv"))
canon <- fread(file.path(V22, "outputs", "cache", "canonical_cobidders_broad.csv"),
               colClasses = list(character = "códigofornecedor"))
xm    <- fread(file.path(REPO, "data", "processed", "cade_bec_crossmatch.csv"))
loss  <- as.data.table(arrow::read_parquet(file.path(REPO, "data", "processed", "firm_loss_stats.parquet")))
norm14 <- function(x) sprintf("%014.0f", as.numeric(x))
direct_codes <- unique(norm14(xm$firm_cnpj))
al_codes  <- canon[direct_cade_defendant==0 & W_i==0][["códigofornecedor"]]
cob_codes <- canon[broad_cobidder==1L][["códigofornecedor"]]

auc <- function(y, s) { r <- rank(s); n1 <- sum(y==1); n0 <- sum(y==0)
  if (!n1 || !n0) return(NA_real_); (sum(r[y==1]) - n1*(n1+1)/2)/(n1*n0) }
strat_auc <- function(dt, score, label, stratum) {
  sv <- dt[[stratum]]; sc <- as.numeric(dt[[score]]); lb <- dt[[label]]
  num <- 0; den <- 0
  for (st in unique(sv)) {
    p <- sc[sv==st & lb==1]; n <- sc[sv==st & lb==0]
    if (!length(p) || !length(n)) next
    cmp <- outer(p, n, function(a,b) (a>b)+0.5*(a==b))
    num <- num + sum(cmp); den <- den + length(p)*length(n)
  }
  list(auc = if (den>0) num/den else NA_real_, pairs = den)
}
qcut <- function(x, k=10L) {                # unique-breaks safe decile cut
  br <- unique(quantile(x, probs=seq(0,1,length.out=k+1), na.rm=TRUE))
  if (length(br) < 3L) return(rep(1L, length(x)))
  as.integer(cut(x, breaks=br, include.lowest=TRUE, labels=FALSE))
}

fr <- copy(frame); fr[, y := cobidder]

# ---- rebuild E_lb per firm (label-blind, MEDIUM cells) -----------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
dbWriteTable(con, "al_firms", data.frame(firm_code = al_codes), overwrite = TRUE)
part <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
           SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),1,11) AS pbu,
           SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS year,
           SUBSTR(CAST(\"códigoitem\"  AS VARCHAR),1,2) AS ig
    FROM read_parquet('%s')),
  def_items AS (SELECT DISTINCT oc, item FROM ftm WHERE firm_code IN (SELECT firm_code FROM direct)),
  al_part AS (
    SELECT f.firm_code, f.oc, f.item, f.pbu, f.year, f.ig,
           CASE WHEN di.oc IS NOT NULL THEN 1 ELSE 0 END AS touches_defendant
    FROM ftm f JOIN al_firms a ON f.firm_code = a.firm_code
    LEFT JOIN def_items di ON f.oc = di.oc AND f.item = di.item)
  SELECT * FROM al_part", ftm_path)))
part[, is_cob_firm := as.integer(firm_code %in% cob_codes)]
part[, cell_id := paste(ig, year, pbu, sep="|")]
cellagg <- part[, .(n_rows=.N, n_rows_lb=sum(is_cob_firm==0L),
                    def_rows_lb=sum(touches_defendant[is_cob_firm==0L])), by=cell_id]
cellagg[, p_g_lb := ifelse(n_rows_lb>0, def_rows_lb/n_rows_lb, 0)]
fe <- merge(part[, .(firm_code, cell_id)], cellagg[, .(cell_id, p_g_lb)], by="cell_id")[
  , .(E_lb = sum(p_g_lb)), by=firm_code]
fe <- merge(data.table(firm_code=al_codes), fe, by="firm_code", all.x=TRUE)
fe[is.na(E_lb), E_lb := 0]
fe[, y := as.integer(firm_code %in% cob_codes)]
# attach score (T_i) from canon
tt <- canon[, .(firm_code=`códigofornecedor`, T_i)]
fe <- merge(fe, tt, by="firm_code", all.x=TRUE)
fe[, score := log1p(T_i)]

# =============================================================================
# B'. GRANULARITY SWEEP + POSITIVE CONTROL + LABEL-BLIND STRATIFICATION
# =============================================================================
say("--- B'. granularity sweep ---")
sweep <- rbindlist(lapply(c("COARSE","MEDIUM","STRICT"), function(g) {
  ecol <- paste0("E_i_loo_", g)
  d <- fr[get(ecol) > 0]
  d[, stratum := qcut(get(ecol))]
  s_sc <- strat_auc(d, "score_i", "y", "stratum")
  s_Oi <- strat_auc(d, "O_i",     "y", "stratum")
  data.table(stratifier = paste0("E_loo_", g), n_retained = nrow(d), npos = d[y==1,.N],
             within_AUC_score = round(s_sc$auc,4), pairs = s_sc$pairs,
             within_AUC_Oi_positive_control = round(s_Oi$auc,4))
}))
# label-blind stratification (the leakage-purged design)
dlb <- fe[E_lb > 0]; dlb[, stratum := qcut(E_lb)]
s_lb  <- strat_auc(dlb, "score", "y", "stratum")
dlb_all <- copy(fe); dlb_all[, stratum := qcut(E_lb)]
s_lb_all <- strat_auc(dlb_all, "score", "y", "stratum")
sweep <- rbind(sweep,
  data.table(stratifier="E_label_blind_MEDIUM (exposed E_lb>0)", n_retained=nrow(dlb),
             npos=dlb[y==1,.N], within_AUC_score=round(s_lb$auc,4), pairs=s_lb$pairs,
             within_AUC_Oi_positive_control=NA_real_),
  data.table(stratifier="E_label_blind_MEDIUM (all AL)", n_retained=nrow(dlb_all),
             npos=dlb_all[y==1,.N], within_AUC_score=round(s_lb_all$auc,4), pairs=s_lb_all$pairs,
             within_AUC_Oi_positive_control=NA_real_))
fwrite(sweep, file.path(OUT, "granularity_sweep.csv"))
print(sweep)

# =============================================================================
# C'. PERMUTATION POWER CURVE
# =============================================================================
say("--- C'. permutation power curve ---")
fr[, e_dec := qcut(E_i_loo_MEDIUM)]
fr[, t_q  := qcut(T_i, 5L)]
fr[, stratum := paste(e_dec, t_q)]
perm_p <- function(y, s, strat, B=200L) {
  obs <- average_precision(y, s)
  null <- replicate(B, { yy <- y
    for (st in unique(strat)) { idx <- which(strat==st); yy[idx] <- sample(y[idx]) }
    average_precision(yy, s) })
  mean(null >= obs)
}
inject <- function(delta) {
  yy <- integer(nrow(fr))
  for (st in unique(fr$stratum)) {
    idx <- which(fr$stratum==st); k <- sum(fr$y[idx]); if (!k) next
    z <- as.numeric(scale(rank(fr$score_i[idx]))); z[is.na(z)] <- 0
    yy[sample(idx, k, prob=exp(4*delta*z))] <- 1L
  }
  yy
}
pow <- rbindlist(lapply(c(0, .02, .05, .10, .15), function(d) {
  rej <- mean(replicate(60, perm_p(inject(d), fr$score_i, fr$stratum, B=200L) <= 0.05))
  say("  delta=%.2f -> rejection %.2f", d, rej)
  data.table(injected_within_AUC = 0.5+d, rejection_rate_alpha05 = rej, sims=60L, B=200L)
}))
fwrite(pow, file.path(OUT, "permutation_power_curve.csv"))

# =============================================================================
# D'. LABEL-FROZEN TIMING
# =============================================================================
say("--- D'. label-frozen timing ---")
froz <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
           CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS INTEGER) AS yr, won
    FROM read_parquet('%s') WHERE \"códigofornecedor\" <> '-1'),
  train AS (SELECT firm_code, COUNT(*) T_train, SUM(won) W_train FROM ftm WHERE yr<=2016 GROUP BY firm_code),
  def_tr AS (SELECT DISTINCT oc,item FROM ftm WHERE yr<=2016 AND firm_code IN (SELECT firm_code FROM direct)),
  def_te AS (SELECT DISTINCT oc,item FROM ftm WHERE yr BETWEEN 2017 AND 2019 AND firm_code IN (SELECT firm_code FROM direct)),
  cob_tr AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_tr d ON f.oc=d.oc AND f.item=d.item
             WHERE f.yr<=2016 AND f.firm_code NOT IN (SELECT firm_code FROM direct)),
  cob_te AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_te d ON f.oc=d.oc AND f.item=d.item
             WHERE f.yr BETWEEN 2017 AND 2019 AND f.firm_code NOT IN (SELECT firm_code FROM direct))
  SELECT t.firm_code, t.T_train, t.W_train,
         CASE WHEN ctr.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_frozen_train,
         CASE WHEN cte.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_testwin
  FROM train t
  LEFT JOIN cob_tr ctr ON t.firm_code=ctr.firm_code
  LEFT JOIN cob_te cte ON t.firm_code=cte.firm_code
  WHERE t.firm_code NOT IN (SELECT firm_code FROM direct)", ftm_path)))
alf <- froz[W_train==0 & T_train>0]; alf[, score := log1p(T_train)]
d1 <- auc(alf$cob_testwin, alf$score); d2 <- auc(alf$cob_frozen_train, alf$score)
fwrite(data.table(
  design=c("d1 frozen score+AL; label=NEW contact 2017-2019 (prospective)",
           "d2 frozen score+AL; label=contact within 2009-2016 (fully frozen retrospective)"),
  pool_n=nrow(alf), npos=c(alf[cob_testwin==1,.N], alf[cob_frozen_train==1,.N]),
  auc=round(c(d1,d2),4)), file.path(OUT, "frozen_timing.csv"))
say("D: pool=%s d1=%.4f (npos=%d) d2=%.4f (npos=%d)",
    format(nrow(alf),big.mark=","), d1, alf[cob_testwin==1,.N], d2, alf[cob_frozen_train==1,.N])
dbDisconnect(con, shutdown=TRUE)

# =============================================================================
# E'. DEFENDANT ROLES
# =============================================================================
setnames(loss, "códigofornecedor", "firm_code")
loss[, firm_code := norm14(firm_code)]
defs <- loss[firm_code %in% direct_codes]; cobs <- loss[firm_code %in% cob_codes]
fwrite(data.table(stat=c("defendants_matched","defendant_share_AL","defendant_med_wr","cobidder_med_wr"),
  value=c(nrow(defs), round(mean(defs$always_loser==1),3), round(median(defs$win_rate),3),
          round(median(cobs$win_rate),3))), file.path(OUT, "defendant_roles.csv"))
say("E: defs=%d shareAL=%.3f medWRdef=%.3f medWRcob=%.3f",
    nrow(defs), mean(defs$always_loser==1), median(defs$win_rate), median(cobs$win_rate))

# ---- macros ------------------------------------------------------------------
leakA <- fread(file.path(OUT, "leakage_check_cell_level.csv"))
a_loo <- leakA[2, auc_vs_cobidder]; a_lb <- leakA[3, auc_vs_cobidder]
mac <- c("% Auto-generated by 12/12b audit armor (doc 97 M2)",
 sprintf("\\newcommand{\\valArmorExpLOO}{%.3f}", a_loo),
 sprintf("\\newcommand{\\valArmorExpLB}{%.3f}", a_lb),
 sprintf("\\newcommand{\\valArmorWithinCoarse}{%.3f}", sweep[1, within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinMedium}{%.3f}", sweep[2, within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinStrict}{%.3f}", sweep[3, within_AUC_score]),
 sprintf("\\newcommand{\\valArmorOiControlMedium}{%.3f}", sweep[2, within_AUC_Oi_positive_control]),
 sprintf("\\newcommand{\\valArmorWithinLB}{%.3f}", sweep[4, within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinLBall}{%.3f}", sweep[5, within_AUC_score]),
 sprintf("\\newcommand{\\valArmorPowerFive}{%.2f}", pow[2, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorPowerTen}{%.2f}", pow[4, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorFrozenProspAUC}{%.3f}", d1),
 sprintf("\\newcommand{\\valArmorFrozenProspN}{%d}", alf[cob_testwin==1,.N]),
 sprintf("\\newcommand{\\valArmorFrozenRetroAUC}{%.3f}", d2),
 sprintf("\\newcommand{\\valArmorFrozenRetroN}{%d}", alf[cob_frozen_train==1,.N]),
 sprintf("\\newcommand{\\valArmorFrozenPool}{%s}", format(nrow(alf), big.mark=",")),
 sprintf("\\newcommand{\\valDirectShareALnew}{%.1f\\%%}", 100*mean(defs$always_loser==1)),
 sprintf("\\newcommand{\\valDirectMedWRnew}{%.3f}", median(defs$win_rate)),
 sprintf("\\newcommand{\\valOthersMedWRnew}{%.3f}", median(cobs$win_rate)))
writeLines(mac, file.path(OUT, "audit_armor_macros.tex"))
say("DONE")
