#!/usr/bin/env Rscript
# =============================================================================
# 12_audit_armor.R -- JLEO hostile-review repair pack (doc 97, MAJOR M2)
#
# Four audit-of-the-audit computations + one provenance regeneration, all on
# existing data (no new objects):
#   A  cell-level label-blind leakage check on the exposure benchmark
#      (p_g recomputed EXCLUDING ALL eventual cobidders' rows, not just firm i)
#   B  within-stratum AUC granularity sweep (COARSE/MEDIUM/STRICT) + positive
#      control (O_i within the same strata: the design CAN detect a residual)
#   C  power curve for the matched-strata permutation (Design C): rejection
#      rate vs injected within-stratum residual effect size
#   D  label-frozen strict timing: AL status, cobidder label, and score ALL
#      frozen on 2009-2016; evaluated against (d1) test-window 2017-2019
#      defendant contact and (d2) frozen retrospective contact
#   E  defendant role stats regenerated from current pipeline (replaces
#      v13-legacy %src for \valDirectShareAL / \valDirectMedWR / \valOthersMedWR)
#
# Outputs: outputs/diagnostics/audit_armor/*.csv + audit_armor_macros.tex
# Discipline: DuckDB threads=12 mem=12GB; seed 20260605; base-R metrics utils.
# =============================================================================

suppressPackageStartupMessages({ library(DBI); library(duckdb); library(data.table) })
set.seed(20260605L)
t0 <- Sys.time()
say <- function(...) cat(sprintf(...), "\n")

fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
SD <- if (length(fa)) dirname(normalizePath(fa[1])) else getwd()
REPO <- normalizePath(file.path(SD, "..", "..", "..", ".."))
V22  <- file.path(REPO, "work", "v22-editor")
OUT  <- file.path(V22, "outputs", "diagnostics", "audit_armor")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
source(file.path(V22, "scripts", "utils", "metrics_triage.R"))

ftm_path <- file.path(REPO, "data", "processed", "firm_tender_map.parquet")
frame <- fread(file.path(V22, "outputs", "cache", "firm_opportunity_adjusted_frame.csv"))
canon <- fread(file.path(V22, "outputs", "cache", "canonical_cobidders_broad.csv"))
xm    <- fread(file.path(REPO, "data", "processed", "cade_bec_crossmatch.csv"))
loss  <- as.data.table(arrow::read_parquet(file.path(REPO, "data", "processed", "firm_loss_stats.parquet")))
norm14 <- function(x) sprintf("%014.0f", as.numeric(x))
direct_codes <- unique(norm14(xm$firm_cnpj))

auc <- function(y, s) { r <- rank(s); n1 <- sum(y==1); n0 <- sum(y==0)
  if (!n1 || !n0) return(NA_real_); (sum(r[y==1]) - n1*(n1+1)/2)/(n1*n0) }
strat_auc <- function(dt, score, label, stratum) {
  num <- 0; den <- 0
  for (s in unique(dt[[stratum]])) {
    sub <- dt[dt[[stratum]]==s]
    p <- sub[[score]][sub[[label]]==1]; n <- sub[[score]][sub[[label]]==0]
    if (!length(p) || !length(n)) next
    cmp <- outer(p, n, function(a,b) (a>b)+0.5*(a==b))
    num <- num + sum(cmp); den <- den + length(p)*length(n)
  }
  list(auc = if (den>0) num/den else NA_real_, pairs = den)
}

say("=== 12_audit_armor.R === host=%s", Sys.info()[["nodename"]])

# =============================================================================
# Rebuild the AL participation table (verbatim logic from 02, MEDIUM keys only)
# =============================================================================
al_codes <- canon[direct_cade_defendant==0 & W_i==0, norm14(`códigofornecedor`)]
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
    FROM read_parquet('%s')
  ),
  def_items AS (SELECT DISTINCT oc, item FROM ftm WHERE firm_code IN (SELECT firm_code FROM direct)),
  al_part AS (
    SELECT f.firm_code, f.oc, f.item, f.pbu, f.year, f.ig,
           CASE WHEN di.oc IS NOT NULL THEN 1 ELSE 0 END AS touches_defendant
    FROM ftm f JOIN al_firms a ON f.firm_code = a.firm_code
    LEFT JOIN def_items di ON f.oc = di.oc AND f.item = di.item)
  SELECT * FROM al_part", ftm_path)))
say("AL participation rows: %s", format(nrow(part), big.mark=","))

cob_codes <- canon[broad_cobidder==1L, norm14(`códigofornecedor`)]
part[, is_cob_firm := as.integer(firm_code %in% cob_codes)]
part[, cell_id := paste(ig, year, pbu, sep="|")]   # MEDIUM cells

# =============================================================================
# A. CELL-LEVEL LABEL-BLIND LEAKAGE CHECK
# =============================================================================
say("\n--- A. cell-level label-blind leakage check (MEDIUM) ---")
cellagg <- part[, .(
  n_rows = .N, def_rows = sum(touches_defendant),
  n_rows_lb = sum(is_cob_firm==0L), def_rows_lb = sum(touches_defendant[is_cob_firm==0L])
), by=cell_id]
cellagg[, p_g     := def_rows / n_rows]                                   # plug-in (as in 02 pre-LOO)
cellagg[, p_g_lb  := ifelse(n_rows_lb > 0, def_rows_lb / n_rows_lb, 0)]  # label-blind: NO cobidder rows
pp <- merge(part[, .(firm_code, cell_id)], cellagg[, .(cell_id, p_g, p_g_lb)], by="cell_id")
fe <- pp[, .(E_plug = sum(p_g), E_lb = sum(p_g_lb)), by=firm_code]
fe <- merge(fe, data.table(firm_code = al_codes), by="firm_code", all.y=TRUE)
for (v in c("E_plug","E_lb")) fe[is.na(get(v)), (v) := 0]
fe[, y := as.integer(firm_code %in% cob_codes)]
# LOO version from the cached frame for comparability
fr <- copy(frame); fr[, y := cobidder]
a_loo  <- auc(fr$y, fr$E_i_loo_MEDIUM)
a_plug <- auc(fe$y, fe$E_plug)
a_lb   <- auc(fe$y, fe$E_lb)
leakA <- data.table(
  benchmark = c("E_i plug-in (cell rate incl. all rows)",
                "E_i firm-LOO (paper's exposure benchmark)",
                "E_i label-blind (cell rate from NON-cobidder rows only)"),
  auc_vs_cobidder = round(c(a_plug, a_loo, a_lb), 4),
  note = c("upper bound; encodes label twice (own + neighbors)",
           "as reported (unconditional ~0.905)",
           "removes ALL cobidder rows from p_g; residual = genuine opportunity structure"))
fwrite(leakA, file.path(OUT, "leakage_check_cell_level.csv"))
say("A: plug=%.4f  firmLOO=%.4f  label-blind=%.4f  (leakage share of firmLOO above 0.5: %.1f%%)",
    a_plug, a_loo, a_lb, 100*(a_loo - a_lb)/(a_loo - 0.5))

# =============================================================================
# B. GRANULARITY SWEEP + POSITIVE CONTROL
# =============================================================================
say("\n--- B. within-stratum AUC granularity sweep + positive control ---")
sweep <- rbindlist(lapply(c("COARSE","MEDIUM","STRICT"), function(g) {
  ecol <- paste0("E_i_loo_", g)
  d <- fr[get(ecol) > 0]                                   # exposed support under this def
  d[, stratum := cut(get(ecol), breaks=quantile(get(ecol), probs=seq(0,1,0.1), na.rm=TRUE),
                     include.lowest=TRUE, labels=FALSE)]
  s_score <- strat_auc(d, "score_i", "y", "stratum")
  s_Oi    <- strat_auc(d, "O_i",     "y", "stratum")       # positive control
  data.table(granularity = g, n_retained = nrow(d), npos = d[y==1,.N],
             within_AUC_score = round(s_score$auc,4), comparable_pairs_score = s_score$pairs,
             within_AUC_Oi_positive_control = round(s_Oi$auc,4))
}))
fwrite(sweep, file.path(OUT, "granularity_sweep.csv"))
print(sweep)

# =============================================================================
# C. POWER CURVE for the matched-strata permutation (Design C analogue)
# =============================================================================
say("\n--- C. permutation power curve (B=200, sims=60 per effect) ---")
# matched strata: E-decile x participation-quintile (mirrors Design C's
# exposure-by-participation matching)
fr[, e_dec := cut(E_i_loo_MEDIUM, breaks=unique(quantile(E_i_loo_MEDIUM, seq(0,1,0.1))),
                  include.lowest=TRUE, labels=FALSE)]
fr[is.na(e_dec), e_dec := 0L]
fr[, t_q  := cut(T_i, breaks=unique(quantile(T_i, seq(0,1,0.2))), include.lowest=TRUE, labels=FALSE)]
fr[, stratum := paste(e_dec, t_q)]
npos_total <- fr[y==1,.N]
perm_p <- function(y, s, strat, B=200L) {
  obs <- average_precision(y, s)
  null <- replicate(B, { yy <- y
    for (st in unique(strat)) { idx <- which(strat==st); yy[idx] <- sample(y[idx]) }
    average_precision(yy, s) })
  mean(null >= obs)
}
inject <- function(delta) {
  # tilt label placement within strata toward high score: target within-AUC = 0.5+delta
  yy <- integer(nrow(fr))
  for (st in unique(fr$stratum)) {
    idx <- which(fr$stratum==st); k <- sum(fr$y[idx])
    if (k==0L) next
    z <- scale(rank(fr$score_i[idx]))[,1]
    gamma <- 4*delta                                   # logistic tilt approx: AUC ~ 0.5 + gamma/4 (small)
    w <- exp(gamma*z); yy[sample(idx, k, prob=w)] <- 1L
  }
  yy
}
pow <- rbindlist(lapply(c(0, .02, .05, .10, .15), function(d) {
  rej <- mean(replicate(60, perm_p(inject(d), fr$score_i, fr$stratum, B=200L) <= 0.05))
  say("  delta=%.2f -> rejection rate %.2f", d, rej)
  data.table(injected_within_AUC = 0.5+d, rejection_rate_alpha05 = rej, sims=60L, B=200L)
}))
fwrite(pow, file.path(OUT, "permutation_power_curve.csv"))

# =============================================================================
# D. LABEL-FROZEN STRICT TIMING (train 2009-2016)
# =============================================================================
say("\n--- D. label-frozen strict timing ---")
froz <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
           CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS INTEGER) AS yr,
           won
    FROM read_parquet('%s') WHERE \"códigofornecedor\" <> '-1'
  ),
  train AS (SELECT firm_code, COUNT(*) T_train, SUM(won) W_train
            FROM ftm WHERE yr <= 2016 GROUP BY firm_code),
  def_tr AS (SELECT DISTINCT oc,item FROM ftm
             WHERE yr <= 2016 AND firm_code IN (SELECT firm_code FROM direct)),
  def_te AS (SELECT DISTINCT oc,item FROM ftm
             WHERE yr BETWEEN 2017 AND 2019 AND firm_code IN (SELECT firm_code FROM direct)),
  cob_tr AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_tr d ON f.oc=d.oc AND f.item=d.item
             WHERE f.yr <= 2016 AND f.firm_code NOT IN (SELECT firm_code FROM direct)),
  cob_te AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_te d ON f.oc=d.oc AND f.item=d.item
             WHERE f.yr BETWEEN 2017 AND 2019 AND f.firm_code NOT IN (SELECT firm_code FROM direct))
  SELECT t.firm_code, t.T_train, t.W_train,
         CASE WHEN ctr.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_frozen_train,
         CASE WHEN cte.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_testwin
  FROM train t
  LEFT JOIN cob_tr ctr ON t.firm_code = ctr.firm_code
  LEFT JOIN cob_te cte ON t.firm_code = cte.firm_code
  WHERE t.firm_code NOT IN (SELECT firm_code FROM direct)", ftm_path)))
alf <- froz[W_train==0 & T_train>0]                       # frozen-AL incumbents (rankable)
alf[, score := log1p(T_train)]
d1 <- auc(alf$cob_testwin,      alf$score)   # prospective: future contact
d2 <- auc(alf$cob_frozen_train, alf$score)   # fully frozen retrospective
froz_out <- data.table(
  design = c("d1: frozen score+AL; label = NEW defendant contact 2017-2019 (prospective)",
             "d2: frozen score+AL; label = defendant contact within 2009-2016 (retrospective, fully frozen)"),
  pool_n = nrow(alf), npos = c(alf[cob_testwin==1,.N], alf[cob_frozen_train==1,.N]),
  auc = round(c(d1, d2), 4),
  note = c("the referee's clean out-of-time test on rankable incumbents",
           "no cross-window leakage in EITHER label or pool"))
fwrite(froz_out, file.path(OUT, "frozen_timing.csv"))
say("D: pool=%s ; d1 prospective AUC=%.4f (npos=%d) ; d2 frozen retrospective AUC=%.4f (npos=%d)",
    format(nrow(alf), big.mark=","), d1, alf[cob_testwin==1,.N], d2, alf[cob_frozen_train==1,.N])
dbDisconnect(con, shutdown = TRUE)

# =============================================================================
# E. DEFENDANT ROLE STATS (provenance regeneration)
# =============================================================================
say("\n--- E. defendant role stats from current pipeline ---")
setnames(loss, "códigofornecedor", "firm_code")
loss[, firm_code := norm14(firm_code)]
defs <- loss[firm_code %in% direct_codes]
cobs <- loss[firm_code %in% cob_codes]
E <- data.table(
  stat = c("defendants_matched_in_loss_stats", "defendant_share_always_loser",
           "defendant_median_win_rate", "cobidder_median_win_rate"),
  value = c(nrow(defs), round(mean(defs$always_loser==1),3),
            round(median(defs$win_rate),3), round(median(cobs$win_rate),3)))
fwrite(E, file.path(OUT, "defendant_roles.csv")); print(E)

# ---- macros -----------------------------------------------------------------
mac <- c("% Auto-generated by 12_audit_armor.R (doc 97 M2 armor pack)",
 sprintf("\\newcommand{\\valArmorExpLOO}{%.3f}      %% src: audit_armor/leakage_check_cell_level.csv", a_loo),
 sprintf("\\newcommand{\\valArmorExpLB}{%.3f}       %% src: label-blind exposure AUC", a_lb),
 sprintf("\\newcommand{\\valArmorWithinCoarse}{%.3f} %% src: granularity_sweep.csv", sweep[granularity=="COARSE", within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinMedium}{%.3f}", sweep[granularity=="MEDIUM", within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinStrict}{%.3f}", sweep[granularity=="STRICT", within_AUC_score]),
 sprintf("\\newcommand{\\valArmorOiControlMedium}{%.3f} %% positive control", sweep[granularity=="MEDIUM", within_AUC_Oi_positive_control]),
 sprintf("\\newcommand{\\valArmorPowerTen}{%.2f}    %% rejection rate at injected within-AUC 0.60", pow[abs(injected_within_AUC-0.60)<1e-9, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorPowerFive}{%.2f}   %% rejection rate at injected within-AUC 0.55", pow[abs(injected_within_AUC-0.55)<1e-9, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorFrozenProspAUC}{%.3f} %% d1 prospective", d1),
 sprintf("\\newcommand{\\valArmorFrozenProspN}{%d}", alf[cob_testwin==1,.N]),
 sprintf("\\newcommand{\\valArmorFrozenRetroAUC}{%.3f} %% d2 fully frozen", d2),
 sprintf("\\newcommand{\\valArmorFrozenPool}{%s}", format(nrow(alf), big.mark=",")),
 sprintf("\\newcommand{\\valDirectShareALnew}{%.1f\\%%} %% src: defendant_roles.csv", 100*mean(defs$always_loser==1)),
 sprintf("\\newcommand{\\valDirectMedWRnew}{%.3f}", median(defs$win_rate)),
 sprintf("\\newcommand{\\valOthersMedWRnew}{%.3f}", median(cobs$win_rate)))
writeLines(mac, file.path(OUT, "audit_armor_macros.tex"))
say("\nDONE in %.1f min", as.numeric(difftime(Sys.time(), t0, units="mins")))
