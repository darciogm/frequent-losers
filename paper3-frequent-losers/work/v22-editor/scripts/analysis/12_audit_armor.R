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

# --- SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05) -------------------------
# Parse --source= (default "bec") and take ALL paths/constants/key lambdas/output
# dirs/spill from get_source_config(). BEC fields equal the prior literals byte-
# for-byte (DATA=data/processed, OUT diagnostics=outputs/diagnostics, FL_CUT 14,
# /tmp/duckdb_spill, window 2009-2019, crossmatch CSV). Federal differs ONLY
# where the data genuinely differ (see notes at each block). A regression gate
# diffs BEC outputs, so BEC behaviour is held identical.
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

# Key-extraction SQL helpers (G1). BEC: buyer/year are substrings of numerodaoc
# (cfg$*_from_key). FED: numerodaoc is 9-char NNNNNYYYY -> buyer is the separate
# codigo_ug column (cfg$buyer_col, via item-panel join) and the trailing 4 digits
# are the NUMBERING year (wrong for 22.8% of rows) so year MUST come from
# cfg$get_year_map(); the substring lambdas are NULL federally and never called.
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
# Lead decision #1: item-group is observed ONLY where cfg$has_item_group is TRUE.
# BEC: codigoitem is a short bare product code -> SUBSTR(1,2) is a genuine product
#   group prefix (cfg$ig_from_key supplies the SQL). MEDIUM cell = (ig, year, pbu).
# FED: codigoitem is a 22-char composite whose first 6 chars ARE codigo_ug, so its
#   2-digit prefix duplicates the UASG's first 2 digits (buyer-collinear). item-group
#   is NOT_OBSERVED federally (cfg$has_item_group = FALSE, cfg$ig_from_key = NULL):
#   the federal MEDIUM cell collapses to (year, pbu) and ig-dependent outputs emit
#   NA with a note. sql_ig_key() is therefore called ONLY when cfg$has_item_group.
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

# FLAG accumulator for armor components that degrade under missing cfg/upstream.
ARMOR_FLAGS <- character(0)
flag <- function(...) { m <- sprintf(...); ARMOR_FLAGS[[length(ARMOR_FLAGS)+1L]] <<- m; say("FLAG: %s", m) }

ftm_path <- cfg$firm_tender_map
# SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05): source-gated 14-char
# normalizer (cfg$norm14_safe). Applied to canonical códigofornecedor + firm_loss_stats
# firm_code (NA-collapse risk for the 119 federal non-numeric ESTRANG*/junk codes) AND
# to CADE-side firm_cnpj/firm_id (numeric -> harmless). BEC -> exact legacy
# sprintf("%014.0f", as.numeric(x)) (byte-identity, gate R1); federal -> numeric pad14,
# non-numeric RAW passthrough (they legitimately never match a CADE CNPJ).
norm14 <- cfg$norm14_safe

# --- upstream caches (built by 00_build_canonical_validation_targets.R + 02) --
frame_path <- file.path(cfg$dirs$cache, "firm_opportunity_adjusted_frame.csv")
canon_path <- file.path(cfg$dirs$cache, "canonical_cobidders_broad.csv")
if (!file.exists(frame_path) || !file.exists(canon_path))
  stop(sprintf(paste0("Required upstream caches missing for source '%s':\n  %s\n  %s\n",
       "Run 00_build_canonical_validation_targets.R and 02_opportunity_adjusted_validation.R ",
       "for --source=%s first."), SRC, frame_path, canon_path, SRC))
frame <- fread(frame_path)
canon <- fread(canon_path)
loss  <- as.data.table(arrow::read_parquet(cfg$firm_loss_stats))

# --- direct CADE defendants: cade_layout-aware resolution --------------------
# BEC : crossmatch CSV, firm_cnpj column -> norm14.
# FED : direct_defendants_federal.parquet (cade_link_v3), firm_id already 14-char.
if (cfg$cade_layout == "bec_csv") {
  xm    <- fread(cfg$cade$crossmatch)
  direct_codes <- unique(norm14(xm$firm_cnpj))
} else {
  dd <- as.data.table(arrow::read_parquet(cfg$cade$direct_defendants))
  direct_codes <- unique(norm14(dd$firm_id))
}
say("source=%s  direct CADE defendants resolved: %d", SRC, length(direct_codes))

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
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))   # SOURCE-CONFIG ADAPTATION
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
dbWriteTable(con, "al_firms", data.frame(firm_code = al_codes), overwrite = TRUE)
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): MEDIUM-cell keys --
# MEDIUM cell. BEC: (ig, year, buyer) with ig = cfg$ig_from_key(codigoitem); pbu &
# year are substrings of numerodaoc. FED: buyer (codigo_ug) and result-year come
# from the item panel via join on (numerodaoc, codigoitem) -- the substring buyer/
# year are INVALID federally (G1) -- and item-group is NOT_OBSERVED (Lead decision
# #1: federal codigoitem's 2-digit prefix duplicates codigo_ug, buyer-collinear).
# When !HAS_IG the ig axis is dropped (constant NULL ig) so the federal MEDIUM cell
# collapses to (year, buyer). Multi-UG (numerodaoc,codigoitem) pairs are dropped
# federally via cfg$drop_multi_ug_pairs() before the buyer join.
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
  pview <- cfg$drop_multi_ug_pairs(con)   # registers TEMP VIEW panel_single_ug
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
say("AL participation rows: %s", format(nrow(part), big.mark=","))

cob_codes <- canon[broad_cobidder==1L, norm14(`códigofornecedor`)]
part[, is_cob_firm := as.integer(firm_code %in% cob_codes)]
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): MEDIUM cell id ----
# When item-group is NOT_OBSERVED (federal), ig is constant -> cell collapses to
# (year, buyer). Pin the dropped axis to a literal so the cell key is unambiguous.
if (!HAS_IG) part[, ig := "_NA_IG_"]
part[, cell_id := paste(ig, year, pbu, sep="|")]   # MEDIUM cells (see CELL_DEF)
say("part A MEDIUM cell_definition: %s ; distinct cells=%d",
    CELL_DEF, uniqueN(part$cell_id))

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
# D. LABEL-FROZEN STRICT TIMING (frozen train window vs prospective test window)
# =============================================================================
# --- SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): frozen split ------
# Lead decision #2: the freeze cutoff is cfg$freeze_year (= 2016 BOTH sources),
# NOT derived from CONS_DATE. CONS_DATE is the federal case-judgment observability
# bound (2025-02-26, OUT of the 2013-2019 window) and was why a predecessor gated
# this block; it is the WRONG object for the train/test freeze. We consume
# cfg$freeze_year directly. BEC: freeze_year=2016 reproduces the prior hard-pinned
# train<=2016 / test 2017-2019 behaviour byte-for-byte (gate diff must be clean).
# FED: the block now RUNS (train<=2016, test 2017-2019, window 2013-2019). Year
# comes from numerodaoc substr for BEC and cfg$get_year_map() federally (G1: never
# string-extract federal year). GRACEFUL GUARD: if cfg$freeze_year is absent we
# STOP with a clear message naming the missing field (do NOT silently skip).
say("\n--- D. label-frozen strict timing ---")
if (is.null(cfg$freeze_year))
  stop("Required config field 'freeze_year' is missing from get_source_config('", SRC,
       "'). D-block freeze cutoff must come from cfg$freeze_year (= 2016 both sources); ",
       "it is NOT derivable from cfg$CONS_DATE (the case-judgment observability bound). ",
       "Add freeze_year to source_config.R before running the label-frozen timing block.")
.freeze_yr <- as.integer(cfg$freeze_year)
run_timing <- !is.na(.freeze_yr) && .freeze_yr >= cfg$year_min && .freeze_yr < cfg$year_max
if (!run_timing) {
  flag(paste0("D (label-frozen timing) SKIPPED for source '%s': cfg$freeze_year=%s ",
              "outside usable range [%d, %d). frozen_timing.csv not written, timing ",
              "macros emitted as NA."),
       SRC, as.character(.freeze_yr), cfg$year_min, cfg$year_max)
  alf <- data.table(); d1 <- NA_real_; d2 <- NA_real_
  d1_n <- NA_integer_; d2_n <- NA_integer_; pool_n <- NA_integer_
} else {
  say("D: freeze_year=%d (train<=%d, test %d-%d, window %d-%d)",
      .freeze_yr, .freeze_yr, .freeze_yr+1L, cfg$year_max, cfg$year_min, cfg$year_max)
  # year SQL: BEC substr ; federal via get_year_map join on (numerodaoc,codigoitem)
  if (IS_BEC) {
    yr_ftm <- sprintf(
      "SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
              CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
              CAST(%s AS INTEGER) AS yr, won
       FROM read_parquet('%s') WHERE \"códigofornecedor\" <> '-1'",
      sql_year_key("CAST(\"numerodaoc\" AS VARCHAR)"), ftm_path)
  } else {
    ymap <- as.data.frame(cfg$get_year_map(con))          # (numerodaoc, codigoitem, year)
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
    train AS (SELECT firm_code, COUNT(*) T_train, SUM(won) W_train
              FROM ftm WHERE yr <= %d GROUP BY firm_code),
    def_tr AS (SELECT DISTINCT oc,item FROM ftm
               WHERE yr <= %d AND firm_code IN (SELECT firm_code FROM direct)),
    def_te AS (SELECT DISTINCT oc,item FROM ftm
               WHERE yr BETWEEN %d AND %d AND firm_code IN (SELECT firm_code FROM direct)),
    cob_tr AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_tr d ON f.oc=d.oc AND f.item=d.item
               WHERE f.yr <= %d AND f.firm_code NOT IN (SELECT firm_code FROM direct)),
    cob_te AS (SELECT DISTINCT f.firm_code FROM ftm f JOIN def_te d ON f.oc=d.oc AND f.item=d.item
               WHERE f.yr BETWEEN %d AND %d AND f.firm_code NOT IN (SELECT firm_code FROM direct))
    SELECT t.firm_code, t.T_train, t.W_train,
           CASE WHEN ctr.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_frozen_train,
           CASE WHEN cte.firm_code IS NOT NULL THEN 1 ELSE 0 END AS cob_testwin
    FROM train t
    LEFT JOIN cob_tr ctr ON t.firm_code = ctr.firm_code
    LEFT JOIN cob_te cte ON t.firm_code = cte.firm_code
    WHERE t.firm_code NOT IN (SELECT firm_code FROM direct)",
    yr_ftm, .freeze_yr, .freeze_yr, .freeze_yr + 1L, cfg$year_max,
    .freeze_yr, .freeze_yr + 1L, cfg$year_max)))
  alf <- froz[W_train==0 & T_train>0]                       # frozen-AL incumbents (rankable)
  alf[, score := log1p(T_train)]
  d1 <- auc(alf$cob_testwin,      alf$score)   # prospective: future contact
  d2 <- auc(alf$cob_frozen_train, alf$score)   # fully frozen retrospective
  d1_n <- alf[cob_testwin==1,.N]; d2_n <- alf[cob_frozen_train==1,.N]; pool_n <- nrow(alf)
  froz_out <- data.table(
    design = c(sprintf("d1: frozen score+AL; label = NEW defendant contact %d-%d (prospective)", .freeze_yr+1L, cfg$year_max),
               sprintf("d2: frozen score+AL; label = defendant contact within %d-%d (retrospective, fully frozen)", cfg$year_min, .freeze_yr)),
    pool_n = pool_n, npos = c(d1_n, d2_n),
    auc = round(c(d1, d2), 4),
    note = c("the referee's clean out-of-time test on rankable incumbents",
             "no cross-window leakage in EITHER label or pool"))
  fwrite(froz_out, file.path(OUT, "frozen_timing.csv"))
  say("D: pool=%s ; d1 prospective AUC=%.4f (npos=%d) ; d2 frozen retrospective AUC=%.4f (npos=%d)",
      format(pool_n, big.mark=","), d1, d1_n, d2, d2_n)
}
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
 sprintf("\\newcommand{\\valArmorFrozenProspAUC}{%s} %% d1 prospective", if (is.na(d1)) "NA" else sprintf("%.3f", d1)),
 sprintf("\\newcommand{\\valArmorFrozenProspN}{%s}", if (is.na(d1_n)) "NA" else as.character(d1_n)),
 sprintf("\\newcommand{\\valArmorFrozenRetroAUC}{%s} %% d2 fully frozen", if (is.na(d2)) "NA" else sprintf("%.3f", d2)),
 sprintf("\\newcommand{\\valArmorFrozenPool}{%s}", if (is.na(pool_n)) "NA" else format(pool_n, big.mark=",")),
 sprintf("\\newcommand{\\valDirectShareALnew}{%.1f\\%%} %% src: defendant_roles.csv", 100*mean(defs$always_loser==1)),
 sprintf("\\newcommand{\\valDirectMedWRnew}{%.3f}", median(defs$win_rate)),
 sprintf("\\newcommand{\\valOthersMedWRnew}{%.3f}", median(cobs$win_rate)))
writeLines(mac, file.path(OUT, "audit_armor_macros.tex"))

# --- SOURCE-CONFIG ADAPTATION (Phase 1): degrade-gracefully FLAG report -------
if (length(ARMOR_FLAGS)) {
  fwrite(data.table(source = SRC, flag = unlist(ARMOR_FLAGS)),
         file.path(OUT, "armor_flags.csv"))
  say("\n%d armor FLAG(s) written to %s", length(ARMOR_FLAGS), file.path(OUT, "armor_flags.csv"))
} else say("\nno armor FLAGs (all components ran for source '%s')", SRC)
say("DONE in %.1f min", as.numeric(difftime(Sys.time(), t0, units="mins")))
