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

# --- SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05) -------------------------
# --source= (default "bec"). ALL paths/constants/key lambdas/dirs/spill from
# get_source_config(). BEC fields equal the prior literals byte-for-byte (the
# regression gate diffs BEC outputs). Federal differs only where data differ.
.args <- commandArgs(trailingOnly = TRUE)
.src  <- sub("^--source=", "", .args[grep("^--source=", .args)])
SRC   <- if (length(.src)) .src[1L] else "bec"
source(file.path(V22, "scripts", "utils", "source_config.R"))
cfg  <- get_source_config(SRC)
cfg$ensure_dirs()
IS_BEC <- identical(SRC, "bec")
DATA   <- cfg$data_dir
SPILL  <- cfg$temp_directory
OUT    <- file.path(cfg$dirs$diagnostics, "audit_armor")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
source(file.path(V22, "scripts", "utils", "metrics_triage.R"))

# Key-extraction SQL helpers (G1) -- see 12_audit_armor.R header for rationale.
# BEC: buyer/year are numerodaoc substrings. FED: buyer = codigo_ug (panel join),
# year = cfg$get_year_map() (numbering year wrong 22.8%); substring lambdas NULL.
sql_buyer_key <- function(noc_alias) {
  if (!is.null(cfg$buyer_from_key)) cfg$buyer_from_key(noc_alias)
  else stop("buyer is not a substring for source ", SRC,
            " -- join the item panel on (numerodaoc,codigoitem) for cfg$buyer_col.")
}
sql_year_key <- function(noc_alias) {
  if (!is.null(cfg$year_from_key)) cfg$year_from_key(noc_alias)
  else stop("year must come from cfg$get_year_map() for source ", SRC, " -- never string-extract.")
}
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): item-group axis ---
# Lead decision #1 (see 12_audit_armor.R header): item-group observed only where
# cfg$has_item_group. BEC ig = cfg$ig_from_key(codigoitem) -> MEDIUM (ig,year,pbu);
# FED item-group NOT_OBSERVED (composite codigoitem 2-digit prefix == codigo_ug
# prefix, buyer-collinear) -> MEDIUM collapses to (year, pbu). sql_ig_key() called
# only when HAS_IG.
HAS_IG <- isTRUE(cfg$has_item_group)
CELL_DEF <- if (HAS_IG) {
  "MEDIUM = (item_group, year, buyer)"
} else {
  "MEDIUM = (year, buyer)  [item-group NOT_OBSERVED on this platform (buyer-collinear composite item code)]"
}
sql_ig_key <- function(item_alias) {
  if (!HAS_IG || is.null(cfg$ig_from_key))
    stop("item-group is NOT_OBSERVED for source ", SRC,
         " (cfg$has_item_group=FALSE) -- sql_ig_key() must not be called.")
  cfg$ig_from_key(item_alias)
}
say("cell_definition in force: %s", CELL_DEF)

ARMOR_FLAGS <- character(0)
flag <- function(...) { m <- sprintf(...); ARMOR_FLAGS[[length(ARMOR_FLAGS)+1L]] <<- m; say("FLAG: %s", m) }

ftm_path <- cfg$firm_tender_map
# SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05): source-gated 14-char
# normalizer (cfg$norm14_safe). Applied to firm_loss_stats firm_code (NA-collapse risk
# for the 119 federal non-numeric ESTRANG*/junk codes) AND CADE-side firm_cnpj/firm_id
# (numeric -> harmless). BEC -> exact legacy sprintf("%014.0f", as.numeric(x)) (byte-
# identity, gate R1); federal -> numeric pad14, non-numeric RAW passthrough.
norm14 <- cfg$norm14_safe

# --- upstream caches (00_build_canonical_validation_targets.R + 02 + 12 part A) -
frame_path <- file.path(cfg$dirs$cache, "firm_opportunity_adjusted_frame.csv")
canon_path <- file.path(cfg$dirs$cache, "canonical_cobidders_broad.csv")
leakA_path <- file.path(OUT, "leakage_check_cell_level.csv")  # written by 12 part A
if (!file.exists(frame_path) || !file.exists(canon_path))
  stop(sprintf(paste0("Required upstream caches missing for source '%s':\n  %s\n  %s\n",
       "Run 00_build_canonical_validation_targets.R and 02_opportunity_adjusted_validation.R ",
       "for --source=%s first."), SRC, frame_path, canon_path, SRC))
frame <- fread(frame_path)
canon <- fread(canon_path, colClasses = list(character = "códigofornecedor"))
loss  <- as.data.table(arrow::read_parquet(cfg$firm_loss_stats))

# direct CADE defendants: cade_layout-aware (BEC crossmatch CSV ; FED parquet v3).
if (cfg$cade_layout == "bec_csv") {
  xm    <- fread(cfg$cade$crossmatch)
  direct_codes <- unique(norm14(xm$firm_cnpj))
} else {
  dd <- as.data.table(arrow::read_parquet(cfg$cade$direct_defendants))
  direct_codes <- unique(norm14(dd$firm_id))
}
al_codes  <- canon[direct_cade_defendant==0 & W_i==0][["códigofornecedor"]]
cob_codes <- canon[broad_cobidder==1L][["códigofornecedor"]]
say("source=%s  direct CADE defendants resolved: %d", SRC, length(direct_codes))

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
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))   # SOURCE-CONFIG ADAPTATION
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
dbWriteTable(con, "al_firms", data.frame(firm_code = al_codes), overwrite = TRUE)
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): MEDIUM-cell keys --
# BEC: (ig,year,pbu) with ig = cfg$ig_from_key; pbu/year are numerodaoc substrings.
# FED: buyer (codigo_ug) + result-year from item panel join on (numerodaoc,
# codigoitem); substring buyer/year are INVALID federally (G1) and item-group is
# NOT_OBSERVED (Lead decision #1) -> drop the ig axis (constant NULL), MEDIUM cell
# collapses to (year, pbu). Multi-UG pairs dropped via cfg$drop_multi_ug_pairs.
ig_expr_ftm <- if (HAS_IG) sql_ig_key("CAST(\"códigoitem\" AS VARCHAR)")    else "NULL"
ig_expr_t   <- if (HAS_IG) sql_ig_key("CAST(t.\"códigoitem\" AS VARCHAR)")  else "NULL"
if (IS_BEC) {
  ftm_select <- sprintf(
    "SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
            CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
            %s AS pbu, %s AS year, %s AS ig
     FROM read_parquet('%s')",
    sql_buyer_key("CAST(\"numerodaoc\" AS VARCHAR)"),
    sql_year_key("CAST(\"numerodaoc\" AS VARCHAR)"),
    ig_expr_ftm, ftm_path)
} else {
  pview <- cfg$drop_multi_ug_pairs(con)
  ftm_select <- sprintf(
    "WITH ymap AS (
       SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
              CAST(MAX(%s) AS VARCHAR) AS pbu, CAST(MAX(year) AS VARCHAR) AS year
       FROM %s GROUP BY 1,2)
     SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
            CAST(t.\"numerodaoc\" AS VARCHAR) AS oc, CAST(t.\"códigoitem\" AS VARCHAR) AS item,
            ym.pbu AS pbu, ym.year AS year, %s AS ig
     FROM read_parquet('%s') t
     LEFT JOIN ymap ym ON CAST(t.\"numerodaoc\" AS VARCHAR)=ym.oc
                      AND CAST(t.\"códigoitem\" AS VARCHAR)=ym.item",
    cfg$buyer_col, pview,
    ig_expr_t, ftm_path)
}
part <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (%s),
  def_items AS (SELECT DISTINCT oc, item FROM ftm WHERE firm_code IN (SELECT firm_code FROM direct)),
  al_part AS (
    SELECT f.firm_code, f.oc, f.item, f.pbu, f.year, f.ig,
           CASE WHEN di.oc IS NOT NULL THEN 1 ELSE 0 END AS touches_defendant
    FROM ftm f JOIN al_firms a ON f.firm_code = a.firm_code
    LEFT JOIN def_items di ON f.oc = di.oc AND f.item = di.item)
  SELECT * FROM al_part", ftm_select)))
part[, is_cob_firm := as.integer(firm_code %in% cob_codes)]
# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): pin dropped ig axis to
# a literal when item-group NOT_OBSERVED -> MEDIUM cell collapses to (year, pbu).
if (!HAS_IG) part[, ig := "_NA_IG_"]
part[, cell_id := paste(ig, year, pbu, sep="|")]
say("E_lb MEDIUM cell_definition: %s ; distinct cells=%d", CELL_DEF, uniqueN(part$cell_id))
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
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): see 12_audit_armor.R
# D-block notes. Lead decision #2: freeze cutoff = cfg$freeze_year (=2016 both),
# NOT derived from CONS_DATE (the federal case-judgment bound 2025-02-26 is OUT of
# the 2013-2019 window). BEC freeze_year=2016 reproduces the prior train<=2016 /
# test 2017-2019 behaviour byte-for-byte. FED block now RUNS. Year from numerodaoc
# substr (BEC) or cfg$get_year_map() (federal, G1). GRACEFUL GUARD: stop with a
# clear message if cfg$freeze_year is absent (do NOT silently skip).
say("--- D'. label-frozen timing ---")
if (is.null(cfg$freeze_year))
  stop("Required config field 'freeze_year' is missing from get_source_config('", SRC,
       "'). D'-block freeze cutoff must come from cfg$freeze_year (= 2016 both sources); ",
       "it is NOT derivable from cfg$CONS_DATE. Add freeze_year to source_config.R.")
.freeze_yr <- as.integer(cfg$freeze_year)
run_timing <- !is.na(.freeze_yr) && .freeze_yr >= cfg$year_min && .freeze_yr < cfg$year_max
if (!run_timing) {
  flag(paste0("D' (label-frozen timing) SKIPPED for source '%s': cfg$freeze_year=%s ",
              "outside usable range [%d, %d). frozen_timing.csv not written, timing ",
              "macros emitted as NA."),
       SRC, as.character(.freeze_yr), cfg$year_min, cfg$year_max)
  alf <- data.table(); d1 <- NA_real_; d2 <- NA_real_
  d1_n <- NA_integer_; d2_n <- NA_integer_; pool_n <- NA_integer_
} else {
  say("D': freeze_year=%d (train<=%d, test %d-%d, window %d-%d)",
      .freeze_yr, .freeze_yr, .freeze_yr+1L, cfg$year_max, cfg$year_min, cfg$year_max)
  if (IS_BEC) {
    yr_ftm <- sprintf(
      "SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
              CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
              CAST(%s AS INTEGER) AS yr, won
       FROM read_parquet('%s') WHERE \"códigofornecedor\" <> '-1'",
      sql_year_key("CAST(\"numerodaoc\" AS VARCHAR)"), ftm_path)
  } else {
    ymap <- as.data.frame(cfg$get_year_map(con))
    dbWriteTable(con, "ymap_fed", ymap, overwrite = TRUE)
    yr_ftm <- sprintf(
      "SELECT LPAD(CAST(t.\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
              CAST(t.\"numerodaoc\" AS VARCHAR) AS oc, CAST(t.\"códigoitem\" AS VARCHAR) AS item,
              CAST(ym.year AS INTEGER) AS yr, t.won
       FROM read_parquet('%s') t
       JOIN ymap_fed ym ON CAST(t.\"numerodaoc\" AS VARCHAR)=ym.numerodaoc
                       AND CAST(t.\"códigoitem\" AS VARCHAR)=ym.\"códigoitem\"
       WHERE t.\"códigofornecedor\" <> '-1'", ftm_path)
  }
  froz <- as.data.table(dbGetQuery(con, sprintf("
    WITH ftm AS (%s),
    train AS (SELECT firm_code, COUNT(*) T_train, SUM(won) W_train FROM ftm WHERE yr<=%d GROUP BY firm_code),
    def_tr AS (SELECT DISTINCT oc,item FROM ftm WHERE yr<=%d AND firm_code IN (SELECT firm_code FROM direct)),
    def_te AS (SELECT DISTINCT oc,item FROM ftm WHERE yr BETWEEN %d AND %d AND firm_code IN (SELECT firm_code FROM direct)),
    cob_tr AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_tr d ON f.oc=d.oc AND f.item=d.item
               WHERE f.yr<=%d AND f.firm_code NOT IN (SELECT firm_code FROM direct)),
    cob_te AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_te d ON f.oc=d.oc AND f.item=d.item
               WHERE f.yr BETWEEN %d AND %d AND f.firm_code NOT IN (SELECT firm_code FROM direct))
    SELECT t.firm_code, t.T_train, t.W_train,
           CASE WHEN ctr.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_frozen_train,
           CASE WHEN cte.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_testwin
    FROM train t
    LEFT JOIN cob_tr ctr ON t.firm_code=ctr.firm_code
    LEFT JOIN cob_te cte ON t.firm_code=cte.firm_code
    WHERE t.firm_code NOT IN (SELECT firm_code FROM direct)",
    yr_ftm, .freeze_yr, .freeze_yr, .freeze_yr+1L, cfg$year_max,
    .freeze_yr, .freeze_yr+1L, cfg$year_max)))
  alf <- froz[W_train==0 & T_train>0]; alf[, score := log1p(T_train)]
  d1 <- auc(alf$cob_testwin, alf$score); d2 <- auc(alf$cob_frozen_train, alf$score)
  d1_n <- alf[cob_testwin==1,.N]; d2_n <- alf[cob_frozen_train==1,.N]; pool_n <- nrow(alf)
  fwrite(data.table(
    design=c(sprintf("d1 frozen score+AL; label=NEW contact %d-%d (prospective)", .freeze_yr+1L, cfg$year_max),
             sprintf("d2 frozen score+AL; label=contact within %d-%d (fully frozen retrospective)", cfg$year_min, .freeze_yr)),
    pool_n=pool_n, npos=c(d1_n, d2_n),
    auc=round(c(d1,d2),4)), file.path(OUT, "frozen_timing.csv"))
  say("D: pool=%s d1=%.4f (npos=%d) d2=%.4f (npos=%d)",
      format(pool_n,big.mark=","), d1, d1_n, d2, d2_n)
}
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
# leakage_check_cell_level.csv is part A, written by 12_audit_armor.R (same OUT).
if (file.exists(leakA_path)) {
  leakA <- fread(leakA_path)
  a_loo <- leakA[2, auc_vs_cobidder]; a_lb <- leakA[3, auc_vs_cobidder]
} else {
  flag("part-A leakage_check_cell_level.csv absent at %s -- run 12_audit_armor.R for source '%s' first; ExpLOO/ExpLB macros emitted as NA.", leakA_path, SRC)
  a_loo <- NA_real_; a_lb <- NA_real_
}
.f3 <- function(x) if (length(x)!=1L || is.na(x)) "NA" else sprintf("%.3f", x)   # NA-safe macro fmt
.fd <- function(x) if (length(x)!=1L || is.na(x)) "NA" else as.character(x)
mac <- c("% Auto-generated by 12/12b audit armor (doc 97 M2)",
 sprintf("\\newcommand{\\valArmorExpLOO}{%s}", .f3(a_loo)),
 sprintf("\\newcommand{\\valArmorExpLB}{%s}", .f3(a_lb)),
 # PROVENANCE FIX (2026-06-06): select sweep rows by stratifier name, not row
 # index. Same index-fragility class as the power-curve bug below; keying on the
 # `stratifier` string makes the macro->row mapping order-independent.
 sprintf("\\newcommand{\\valArmorWithinCoarse}{%.3f}", sweep[grepl("E_loo_COARSE", stratifier), within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinMedium}{%.3f}", sweep[grepl("E_loo_MEDIUM", stratifier), within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinStrict}{%.3f}", sweep[grepl("E_loo_STRICT", stratifier), within_AUC_score]),
 sprintf("\\newcommand{\\valArmorOiControlMedium}{%.3f}", sweep[grepl("E_loo_MEDIUM", stratifier), within_AUC_Oi_positive_control]),
 sprintf("\\newcommand{\\valArmorWithinLB}{%.3f}", sweep[grepl("E_label_blind_MEDIUM \\(exposed", stratifier), within_AUC_score]),
 sprintf("\\newcommand{\\valArmorWithinLBall}{%.3f}", sweep[grepl("E_label_blind_MEDIUM \\(all AL", stratifier), within_AUC_score]),
 # PROVENANCE FIX (2026-06-06): select power rows by injected_within_AUC value,
 # not by row index. pow[2]/pow[4] silently mapped to AUC 0.52/0.60 (the row
 # ORDER), so \valArmorPowerFive emitted the 0.52 rejection rate (0.28) instead
 # of the 0.55 rate (0.97). values.tex (hand-maintained, authoritative) is
 # correct; this only desynced the auto-generated macros.tex on the next run.
 sprintf("\\newcommand{\\valArmorPowerFive}{%.2f}", pow[abs(injected_within_AUC - 0.55) < 1e-9, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorPowerTen}{%.2f}", pow[abs(injected_within_AUC - 0.60) < 1e-9, rejection_rate_alpha05]),
 sprintf("\\newcommand{\\valArmorFrozenProspAUC}{%s}", .f3(d1)),
 sprintf("\\newcommand{\\valArmorFrozenProspN}{%s}", .fd(d1_n)),
 sprintf("\\newcommand{\\valArmorFrozenRetroAUC}{%s}", .f3(d2)),
 sprintf("\\newcommand{\\valArmorFrozenRetroN}{%s}", .fd(d2_n)),
 sprintf("\\newcommand{\\valArmorFrozenPool}{%s}", if (is.na(pool_n)) "NA" else format(pool_n, big.mark=",")),
 sprintf("\\newcommand{\\valDirectShareALnew}{%.1f\\%%}", 100*mean(defs$always_loser==1)),
 sprintf("\\newcommand{\\valDirectMedWRnew}{%.3f}", median(defs$win_rate)),
 sprintf("\\newcommand{\\valOthersMedWRnew}{%.3f}", median(cobs$win_rate)))
writeLines(mac, file.path(OUT, "audit_armor_macros.tex"))

# --- SOURCE-CONFIG ADAPTATION (Phase 1): degrade-gracefully FLAG report -------
if (length(ARMOR_FLAGS)) {
  fwrite(data.table(source = SRC, flag = unlist(ARMOR_FLAGS)),
         file.path(OUT, "armor_flags_12b.csv"))
  say("%d armor FLAG(s) written to %s", length(ARMOR_FLAGS), file.path(OUT, "armor_flags_12b.csv"))
} else say("no armor FLAGs (all components ran for source '%s')", SRC)
say("DONE")
