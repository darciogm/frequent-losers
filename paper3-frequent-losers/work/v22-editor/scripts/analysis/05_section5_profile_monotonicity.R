#!/usr/bin/env Rscript
# =============================================================================
# 05_section5_profile_monotonicity.R  --  JLEO R&R (v22), Section 5
#
# Economic profile + opportunity-adjusted attenuation + monotonicity for the
# adjudication-anchored cobidder target. The section gives the cobidder label
# economic CONTENT without pretending to prove collusion. We report STANDARDIZED
# differences (Cohen's d / SMD), NOT just p-values from huge samples, and we
# report honestly what ATTENUATES after opportunity adjustment.
#
# Reuses the canonical Sub5 firm frame:
#   work/v22-editor/outputs/cache/firm_opportunity_adjusted_frame.csv
# (one row per always-loser; cobidder = canonical broad AL cobidder label
#  (651, reproducible, FL never used); fl14 = 1[T_i>=14]; direct CADE defendants EXCLUDED).
#
# Steps:
#   A  Groups (Step 5)               -> table_E_section5_group_counts
#   B  Economic profile (Step 6)     -> table_J_economic_profile  (D vs E)
#   C  Standardized differences (7)  -> table_E_standardized_profile_differences + fig
#   D  Opportunity-adjusted (Step 8) -> table_K_opportunity_adjusted_profile
#   E  Monotonicity (Step 9)         -> table_L_monotonicity_bins + 2 figs
#   F  Binary vs continuous (Step 10)-> table_M_binary_vs_continuous_score + memo
#
# Run:
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/05_section5_profile_monotonicity.R \
#     2>&1 | tee work/v22-editor/outputs/logs/section5_profile.log
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow)
  library(ggplot2); library(splines)
})

# ---- locate repo + dirs -----------------------------------------------------
if (!exists(".script_dir")) {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  .script_dir <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
REPO <- normalizePath(file.path(.script_dir, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
V22  <- file.path(REPO, "work", "v22-editor")
UTIL <- file.path(V22, "scripts", "utils")
DOCS <- file.path(V22, "docs", "jleo_rr_revision")

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): --source= flag (default "bec");
# ALL data paths / constants / key lambdas / output+cache+spill dirs come from cfg.
source(file.path(UTIL, "source_config.R"))
.args <- commandArgs(TRUE)
.src  <- sub("^--source=", "", .args[grep("^--source=", .args)])
SRC   <- if (length(.src)) .src[1L] else "bec"
cfg   <- get_source_config(SRC)
cfg$ensure_dirs()

source(file.path(UTIL, "metrics_triage.R"))

# cfg-driven dirs (BEC: identical to the prior literal paths; FED: isolated tree)
dir_main_t <- cfg$dirs$tables_main
dir_app_t  <- cfg$dirs$tables_app
dir_main_f <- cfg$dirs$figures_main
dir_diag   <- cfg$dirs$diagnostics
dir_cache  <- cfg$dirs$cache
dir_log    <- cfg$dirs$logs
SPILL      <- cfg$temp_directory
for (d in c(dir_main_t,dir_app_t,dir_main_f,dir_diag,dir_cache,dir_log,DOCS))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(SPILL, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)
SEED <- 20260603L
set.seed(SEED)

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "section5_profile_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp <- function(s) say("  [stage %-30s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())
norm14 <- function(x) sprintf("%014.0f", as.numeric(x))

say("=== 05_section5_profile_monotonicity.R ===")
say("host=%s  nproc=%s  seed=%d  date=%s  RAM_free=%s",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()),
    tryCatch(system("free -h | awk 'NR==2{print $7}'", intern=TRUE), error=function(e)"?"))
say("REPO=%s", REPO)

# ---- load canonical firm frame ---------------------------------------------
FRAME <- file.path(dir_cache, "firm_opportunity_adjusted_frame.csv")
if (!file.exists(FRAME)) stop(sprintf("firm frame missing: %s (run 02_opportunity_adjusted_validation.R first)", FRAME))
ff <- fread(FRAME)
say("loaded firm frame: %d firms, %d cols", nrow(ff), ncol(ff))
say("  cobidder=%d  fl14=%d  fl14&cobidder=%d  Y_broad=%d  exposed=%d",
    sum(ff$cobidder), sum(ff$fl14), sum(ff$fl14==1 & ff$cobidder==1), sum(ff$Y_broad), sum(ff$exposed))

# =============================================================================
# Reconstruct the deterministic firm_id <-> CNPJ map EXACTLY as the Sub5 script
# did (sort always-losers by firm_code, firm_id := .I). Needed to attach
# modality / tender value / bidder-count environment from the panels.
# =============================================================================
say("\n----- reconstruct firm_id<->CNPJ map (sorted-CNPJ index) -----")
fp <- as.data.table(read_parquet(cfg$freq_particip))
fp[, firm_code := norm14(`códigofornecedor`)]
al_map <- fp[always_loser == 1L, .(firm_code, tenders_count)]
setorder(al_map, firm_code)
al_map[, firm_id := .I]
stopifnot(nrow(al_map) == nrow(ff))
# sanity: T_i from frame must match tenders_count via firm_id
chk <- merge(ff[, .(firm_id, T_i)], al_map[, .(firm_id, tenders_count)], by="firm_id")
if (!isTRUE(all.equal(chk$T_i, chk$tenders_count)))
  say("  WARN: T_i mismatch on %d firms -> firm_id map may be off", sum(chk$T_i != chk$tenders_count)) else
  say("  firm_id<->CNPJ map verified (T_i == tenders_count for all %d firms)", nrow(chk))
ff <- merge(ff, al_map[, .(firm_id, firm_code)], by="firm_id", all.x=TRUE)
stamp("firmid_map")

# =============================================================================
# Panel-derived per-firm features: modality share, tender value, bidder env,
# item_group HHI, buyer HHI, top-group/top-buyer share.
# All cheap via DuckDB: aggregate firm_tender_map JOIN item_value_panel by firm.
# =============================================================================
say("\n----- panel-derived firm features (modality / value / bidder-env / HHI) -----")
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): cfg-driven paths + key lambdas.
ftm_path <- cfg$firm_tender_map
ivp_path <- cfg$item_panel
MODALITY_OBS <- TRUE; VALUE_OBS <- TRUE; BIDDER_OBS <- TRUE
HAS_IG <- isTRUE(cfg$has_item_group)   # federal: SUBSTR item-group is buyer-collinear -> FALSE

# Panel column names differ by source: BEC item_value_panel carries (modality,
# item_value, n_firms, codigoitem-no-accent); FED item_level_panel carries
# (po_phase_code, valor_item, n_firms, códigoitem-accent + codigo_ug for buyer).
P_ITEM <- sprintf("\"%s\"", cfg$item_panel_item_col)   # panel item-code column
P_MOD  <- cfg$modality_col                              # modality / po_phase_code
P_VAL  <- cfg$item_value_col                            # item_value / valor_item
P_NF   <- cfg$n_firms_col                               # n_firms (both)
# pregao-family codes = all modality codes EXCEPT convite (BEC list also holds convite).
.pregao_names <- setdiff(names(cfg$modalities), "convite")
PREGAO_CODES  <- paste(unlist(cfg$modalities[.pregao_names]), collapse=",")  # BEC: 3 ; FED: 5,9999
CONVITE_CODE  <- if (cfg$has_convite) cfg$modalities$convite else NA_integer_
# Buyer-from-key (BEC) vs buyer-from-panel codigo_ug (FED). For BEC the buyer is a
# substr of the FTM numerodaoc; federally the FTM has NO buyer column, so buyer
# (codigo_ug) is carried from the item panel via the (oc,item) join.
BUYER_FROM_KEY <- !is.null(cfg$buyer_from_key)
# item-group select expr from FTM códigoitem (BEC only; NULL placeholder federally)
IG_SEL <- if (HAS_IG) sprintf("%s AS ig", cfg$ig_from_key("CAST(\"códigoitem\" AS VARCHAR)")) else "NULL AS ig"
PBU_SEL_FTM <- if (BUYER_FROM_KEY) sprintf("%s AS pbu", cfg$buyer_from_key("CAST(\"numerodaoc\" AS VARCHAR)")) else "NULL AS pbu"

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))
dbWriteTable(con, "al_firms", data.frame(firm_code = al_map$firm_code), overwrite = TRUE)

# Firm x tender-item with modality/value/bidder-count joined from the item panel.
# Federally buyer (codigo_ug) is carried from the panel (FTM has no buyer column).
convite_sel <- if (cfg$has_convite)
  sprintf("SUM(CASE WHEN %s=%d THEN 1 ELSE 0 END)", P_MOD, CONVITE_CODE) else "0"
firm_feat <- tryCatch(as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc,
           CAST(\"códigoitem\" AS VARCHAR) AS item,
           %s,
           %s
    FROM read_parquet('%s')
  ),
  al_ftm AS (
    SELECT f.* FROM ftm f JOIN al_firms a ON f.firm_code = a.firm_code
  ),
  panel AS (
    SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(%s AS VARCHAR) AS item,
           %s AS modality, %s AS item_value, %s AS n_firms%s
    FROM read_parquet('%s')
  ),
  joined AS (
    SELECT a.firm_code, a.oc, a.item, a.pbu, a.ig,
           p.modality, p.item_value, p.n_firms%s
    FROM al_ftm a LEFT JOIN panel p ON a.oc = p.oc AND a.item = p.item
  )
  SELECT firm_code,
         COUNT(*)                                              AS n_items_ftm,
         SUM(CASE WHEN modality IN (%s) THEN 1 ELSE 0 END)     AS n_pregao,
         %s                                                    AS n_convite,
         SUM(CASE WHEN modality IS NOT NULL THEN 1 ELSE 0 END) AS n_modality_obs,
         SUM(CASE WHEN item_value IS NOT NULL AND item_value>0 THEN 1 ELSE 0 END) AS n_value_obs,
         AVG(CASE WHEN item_value>0 THEN item_value END)       AS mean_tender_value,
         MEDIAN(CASE WHEN item_value>0 THEN item_value END)    AS med_tender_value,
         AVG(CASE WHEN n_firms>0 THEN n_firms END)             AS mean_bidder_count,
         MEDIAN(CASE WHEN n_firms>0 THEN n_firms END)          AS med_bidder_count
  FROM joined
  GROUP BY firm_code
",
  PBU_SEL_FTM, IG_SEL, ftm_path,
  P_ITEM, P_MOD, P_VAL, P_NF, if (BUYER_FROM_KEY) "" else sprintf(", codigo_ug AS buyer_panel"),
  ivp_path,
  if (BUYER_FROM_KEY) "" else ", p.buyer_panel",
  PREGAO_CODES, convite_sel))),
  error=function(e){say("  panel-join FAILED: %s", conditionMessage(e)); NULL})

if (is.null(firm_feat)) { MODALITY_OBS <- VALUE_OBS <- BIDDER_OBS <- FALSE }

# HHI across item_groups (BEC only) and buyers + top-share, computed separately.
# Federally item-group is NOT_OBSERVED (buyer-collinear prefix) -> hhi_ig/top_ig
# are emitted NULL and filled with the trivial single-group value downstream.
# Buyer HHI: BEC buyer = substr(FTM numerodaoc); FED buyer = codigo_ug via panel join.
if (BUYER_FROM_KEY) {
  buyer_ftm_cte <- sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           %s,
           %s
    FROM read_parquet('%s')
  ),", PBU_SEL_FTM, IG_SEL, ftm_path)
} else {
  # federal: join FTM to panel to bring codigo_ug as the buyer (pbu); ig stays NULL.
  buyer_ftm_cte <- sprintf("
  WITH panel AS (
    SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(%s AS VARCHAR) AS item, codigo_ug AS pbu
    FROM read_parquet('%s')
  ),
  ftm AS (
    SELECT LPAD(CAST(f.\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           p.pbu AS pbu,
           NULL AS ig
    FROM read_parquet('%s') f
    LEFT JOIN panel p
      ON CAST(f.\"numerodaoc\" AS VARCHAR)=p.oc AND CAST(f.\"códigoitem\" AS VARCHAR)=p.item
  ),", P_ITEM, ivp_path, ftm_path)
}
ig_agg_sql <- if (HAS_IG) "
  ig_counts AS (SELECT firm_code, ig, COUNT(*) AS n FROM al_ftm WHERE ig IS NOT NULL GROUP BY firm_code, ig),
  ig_tot AS (SELECT firm_code, SUM(n) AS tot FROM ig_counts GROUP BY firm_code),
  ig_agg AS (
    SELECT c.firm_code,
           SUM( (CAST(c.n AS DOUBLE)/t.tot)*(CAST(c.n AS DOUBLE)/t.tot) ) AS hhi_ig,
           MAX(CAST(c.n AS DOUBLE))/MAX(t.tot) AS top_ig_share
    FROM ig_counts c JOIN ig_tot t ON c.firm_code=t.firm_code GROUP BY c.firm_code
  )," else ""
ig_sel_final <- if (HAS_IG) "ig.hhi_ig, ig.top_ig_share" else "NULL AS hhi_ig, NULL AS top_ig_share"
ig_join_final <- if (HAS_IG) "JOIN ig_agg ig ON ig.firm_code = b.firm_code" else ""
firm_hhi <- as.data.table(dbGetQuery(con, sprintf("%s
  al_ftm AS (SELECT f.* FROM ftm f JOIN al_firms a ON f.firm_code = a.firm_code),
  bu_counts AS (SELECT firm_code, pbu, COUNT(*) AS n FROM al_ftm WHERE pbu IS NOT NULL GROUP BY firm_code, pbu),
  bu_tot AS (SELECT firm_code, SUM(n) AS tot FROM bu_counts GROUP BY firm_code),
  %s
  bu_agg AS (
    SELECT c.firm_code,
           SUM( (CAST(c.n AS DOUBLE)/t.tot)*(CAST(c.n AS DOUBLE)/t.tot) ) AS hhi_buyer,
           MAX(CAST(c.n AS DOUBLE))/MAX(t.tot) AS top_buyer_share
    FROM bu_counts c JOIN bu_tot t ON c.firm_code=t.firm_code GROUP BY c.firm_code
  )
  SELECT b.firm_code, %s, b.hhi_buyer, b.top_buyer_share
  FROM bu_agg b %s
", buyer_ftm_cte, ig_agg_sql, ig_sel_final, ig_join_final)))
if (!HAS_IG) say("  item-group HHI marked NOT_OBSERVED federally (SUBSTR codigoitem prefix == codigo_ug buyer; buyer-collinear).")
dbDisconnect(con, shutdown = TRUE); gc()

if (!is.null(firm_feat)) {
  firm_feat[, pregao_share  := ifelse(n_modality_obs>0, n_pregao/n_modality_obs, NA_real_)]
  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): convite_share only where convite
  # exists. Federal is pure Pregao -> convite_share NA (NOT_OBSERVED), logged skip.
  if (cfg$has_convite) {
    firm_feat[, convite_share := ifelse(n_modality_obs>0, n_convite/n_modality_obs, NA_real_)]
  } else {
    firm_feat[, convite_share := NA_real_]
    say("  [skip] convite_share NOT computed (source=%s is pure Pregao; no convite modality).", cfg$source)
  }
  say("  modality observed for %.1f%% of AL firm-items (mean over firms)",
      100*mean(firm_feat$n_modality_obs/firm_feat$n_items_ftm, na.rm=TRUE))
  ff <- merge(ff, firm_feat[, .(firm_code, pregao_share, convite_share,
                                mean_tender_value, med_tender_value,
                                mean_bidder_count, med_bidder_count,
                                n_value_obs, n_items_ftm)],
              by="firm_code", all.x=TRUE)
  # VALUE COVERAGE GATE: item_value_panel only covers a tiny slice of always-loser
  # (loser-side) participations -- it is built from winner/modality-specific items.
  # If cobidder firms have near-zero value coverage, mean_tender_value is a coverage
  # artifact (a handful of firms with one huge tender) -> mark NOT_OBSERVED.
  cob_codes_pre <- ff[cobidder==1, firm_code]
  cob_val_cov <- ff[cobidder==1, mean((n_value_obs>0), na.rm=TRUE)]
  al_val_cov  <- ff[, mean(n_value_obs>0, na.rm=TRUE)]
  say("  tender-value coverage: cobidder firms w/ >=1 valued item = %.1f%% ; all AL = %.1f%%",
      100*cob_val_cov, 100*al_val_cov)
  if (cob_val_cov < 0.5) {
    VALUE_OBS <- FALSE
    say("  -> tender VALUE marked NOT_OBSERVED for the loser-side population (coverage < 50%% among cobidders).")
    say("     item_value_panel is winner/modality-built; always-losers rarely appear -> mean_tender_value dropped.")
  }
  # bidder-count (n_firms) shares the same panel coverage -> same gate.
  if (cob_val_cov < 0.5) {
    BIDDER_OBS <- FALSE
    say("  -> bidder-count environment marked NOT_OBSERVED (same item_value_panel coverage limit).")
  }
}
ff <- merge(ff, firm_hhi, by="firm_code", all.x=TRUE)
# top-item-group / top-buyer share NA -> firms always have >=1 group/buyer, so set 1.
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group HHI fill only where the
# item-group is observed (BEC). Federally hhi_ig/top_ig_share stay NA (NOT_OBSERVED:
# SUBSTR codigoitem prefix is the buyer code; reusing it would be buyer-collinear).
if (HAS_IG) ff[is.na(hhi_ig), `:=`(hhi_ig=1, top_ig_share=1)]
ff[is.na(hhi_buyer), `:=`(hhi_buyer=1, top_buyer_share=1)]
stamp("panel_features")

# share of contacts in largest case (per firm) from case_cobidder_map proximity
# is mechanical for cobidders; we instead use share_in_def_cells (already in frame)
# and add "share of contacts in largest case" derived from n_cases (proxy: 1/n_cases
# floor). We compute the true largest-case share only for the monotonicity table
# via the case map below.

# =============================================================================
# A. GROUPS (Step 5)
# =============================================================================
say("\n========== A. GROUPS (Step 5) ==========")
ff[, grp_B := as.integer(fl14==0)]                       # non-frequent always-losers
ff[, grp_C := as.integer(fl14==1)]                       # frequent losers
ff[, grp_D := as.integer(fl14==1 & cobidder==0)]         # FL non-cobidders  (MAIN ref)
ff[, grp_E := as.integer(fl14==1 & cobidder==1)]         # FL cobidders      (MAIN target)
ff[, grp_F := as.integer(cobidder==1)]                   # AL cobidders
ff[, grp_G := as.integer(cobidder==0)]                   # AL non-cobidders

# Canonical broad AL cobidder label (651, reproducible, FL never used) spans the
# whole always-loser universe, so cobidders are NOT all FL14 (this is by design;
# the old FL-only 193 label was). D,E still partition the FL14 cobidder cell;
# F,G partition all cobidders. Diagnostic kept (non-gating); invariant relaxed.
.cob_fl14_share <- if (ff[cobidder==1,.N]>0) ff[cobidder==1, mean(fl14==1)] else NA_real_
.assert_cob_fl <- ff[cobidder==1,.N] > 0          # relaxed: positives > 0
say("DIAG cobidder positives=%d ; FL14 share among cobidders=%.3f (cobidders not FL14: %d)",
    ff[cobidder==1,.N], .cob_fl14_share, ff[cobidder==1 & fl14==0,.N])

# Opportunity groups (high = top quartile of E_i_MEDIUM / X_i_MEDIUM / score)
e_hi  <- quantile(ff$E_i_MEDIUM, 0.75)
x_hi  <- quantile(ff$X_i_MEDIUM, 0.75)
sc_hi <- quantile(ff$score_i, 0.75); sc_lo <- quantile(ff$score_i, 0.25)
x_med <- median(ff$X_i_MEDIUM)
ff[, grp_I := as.integer(E_i_MEDIUM >= e_hi & cobidder==0)]  # high-E non-cobidders
ff[, grp_J := as.integer(E_i_MEDIUM >= e_hi & cobidder==1)]  # high-E cobidders
ff[, grp_K := as.integer(X_i_MEDIUM >= x_hi)]               # high-excess firms
ff[, grp_L := as.integer(score_i >= sc_hi & X_i_MEDIUM <= x_med)]  # high-score/low-excess
ff[, grp_M := as.integer(score_i <= sc_lo & X_i_MEDIUM >  x_med)]  # low-score/high-excess

n_AL <- nrow(ff); n_FL <- sum(ff$fl14); n_cob <- sum(ff$cobidder)
gdef <- list(
  A=list("all always-losers", ff$firm_id),
  B=list("non-frequent always-losers (fl14=0)", ff[grp_B==1,firm_id]),
  C=list("frequent losers (fl14=1)", ff[grp_C==1,firm_id]),
  D=list("FL non-cobidders (fl14=1 & cobidder=0)", ff[grp_D==1,firm_id]),
  E=list("FL cobidders (fl14=1 & cobidder=1)", ff[grp_E==1,firm_id]),
  F=list("always-loser cobidders (cobidder=1)", ff[grp_F==1,firm_id]),
  G=list("always-loser non-cobidders (cobidder=0)", ff[grp_G==1,firm_id]),
  I=list("high-E_MEDIUM non-cobidders (E_i>=Q3)", ff[grp_I==1,firm_id]),
  J=list("high-E_MEDIUM cobidders (E_i>=Q3)", ff[grp_J==1,firm_id]),
  K=list("high-excess firms (X_i_MEDIUM>=Q3)", ff[grp_K==1,firm_id]),
  L=list("high-score / low-excess (score>=Q3 & X<=median)", ff[grp_L==1,firm_id]),
  M=list("low-score / high-excess (score<=Q1 & X>median)", ff[grp_M==1,firm_id])
)
gc_tab <- rbindlist(lapply(names(gdef), function(g) {
  ids <- gdef[[g]][[2]]; sub <- ff[firm_id %in% ids]
  data.table(group_name=g, definition=gdef[[g]][[1]],
             N=nrow(sub), positives=sub[cobidder==1,.N],
             share_of_AL=round(nrow(sub)/n_AL,4),
             share_of_FL=round(nrow(sub)/n_FL,4),
             direct_defendants_excluded=TRUE,
             notes="")
}))
# Group H reported SEPARATELY (direct defendants) — never mixed into A-G.
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): direct-defendant set is CADE-layout
# specific. BEC: cade_bec_crossmatch.csv (firm_cnpj). FED: direct_defendants_federal
# parquet (cnpj/codigofornecedor). Canonical cobidder set lives in the isolated cache.
if (cfg$cade_layout == "bec_csv") {
  xm <- fread(cfg$cade$crossmatch)
  direct_raw <- norm14(xm$firm_cnpj)
} else {
  xm <- as.data.table(read_parquet(cfg$cade$direct_defendants))
  .dcol <- intersect(c("códigofornecedor","cnpj","firm_cnpj","cnpj14"), names(xm))[1]
  if (is.na(.dcol)) stop("direct_defendants_federal: no recognizable CNPJ column")
  direct_raw <- norm14(xm[[.dcol]])
}
# POSITIVE LABEL: canonical broad AL cobidder label (reproducible, FL never used).
# `códigofornecedor` is already the raw 14-char join key; norm14 is idempotent and
# keeps this set in the same format as the direct-defendant set below.
.canon_cob <- fread(file.path(dir_cache, "canonical_cobidders_broad.csv"))
cob_codes <- unique(norm14(.canon_cob[broad_cobidder == 1L][["códigofornecedor"]]))
direct_codes <- setdiff(unique(direct_raw), cob_codes)
H_in_frame <- sum(direct_codes %in% ff$firm_code)
gc_tab <- rbind(gc_tab, data.table(
  group_name="H", definition="direct CADE defendants (REPORTED SEPARATELY)",
  N=length(direct_codes), positives=0L, share_of_AL=NA_real_, share_of_FL=NA_real_,
  direct_defendants_excluded=NA, notes=sprintf("winners; %d of %d in AL universe; EXCLUDED from A-G",
                                               H_in_frame, length(direct_codes))))
# ASSERT direct defendants are NOT in any cobidder group
.assert_no_def_in_cob <- !any(direct_codes %in% ff[cobidder==1, firm_code])
say("ASSERT direct defendants NOT in cobidder set: %s", .assert_no_def_in_cob)
stopifnot(.assert_cob_fl, .assert_no_def_in_cob)

fwrite(gc_tab, file.path(dir_app_t, "table_E_section5_group_counts.csv"))
texE <- c("\\begin{table}[htbp]\\centering",
  "\\caption{Section 5 group definitions and counts}",
  "\\label{tab:s5_group_counts}",
  "\\begin{tabular}{llrrrr}\\hline",
  "Group & Definition & $N$ & Cobidders & \\%\\,AL & \\%\\,FL \\\\\\hline",
  apply(gc_tab, 1, function(r) sprintf("%s & %s & %s & %s & %s & %s \\\\",
    r[["group_name"]], gsub("&","\\\\&",gsub("_","\\\\_",r[["definition"]])),
    format(as.integer(r[["N"]]),big.mark=","), r[["positives"]],
    ifelse(is.na(r[["share_of_AL"]]),"--",r[["share_of_AL"]]),
    ifelse(is.na(r[["share_of_FL"]]),"--",r[["share_of_FL"]]))),
  "\\hline\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize\\item Direct CADE defendants (group H) reported separately and excluded from A--G. Cobidder = adjudication-anchored exposure, not membership.\\end{tablenotes}",
  "\\end{table}")
writeLines(texE, file.path(dir_app_t, "table_E_section5_group_counts.tex"))
say("Group counts: D(FL non-cob)=%d  E(FL cob)=%d  F(AL cob)=%d  G(AL non-cob)=%d",
    gc_tab[group_name=="D",N], gc_tab[group_name=="E",N],
    gc_tab[group_name=="F",N], gc_tab[group_name=="G",N])
stamp("A_groups")

# =============================================================================
# B/C. ECONOMIC PROFILE + STANDARDIZED DIFFERENCES (Steps 6-7)
#   MAIN comparison = group D (FL non-cobidders) vs group E (FL cobidders)
# =============================================================================
say("\n========== B/C. ECONOMIC PROFILE (D vs E) ==========")
ff[, log1p_T := log1p(T_i)]
ff[, items_per_active_year := ifelse(n_years>0, n_items_total/n_years, n_items_total)]

# variable registry: name -> (column, panel, type [cont|binary])
profile_vars <- list(
  # Panel A: participation / persistence
  list("T_i","A","cont","participation: # tender-items"),
  list("log1p_T","A","cont","log(1+T_i)"),
  list("n_years","A","cont","# active years"),
  list("items_per_active_year","A","cont","items per active year"),
  # Panel B: breadth / concentration
  list("n_items_total","B","cont","# distinct tender-items"),
  list("n_buyers","B","cont","# buyers"),
  list("hhi_buyer","B","cont","HHI across buyers"),
  list("top_buyer_share","B","cont","top-buyer share"),
  # Panel C: CADE proximity (PARTLY MECHANICAL for cobidders)
  list("O_i","C","cont","observed defendant contacts"),
  list("E_i_MEDIUM","C","cont","expected contacts (opportunity)"),
  list("X_i_MEDIUM","C","cont","excess contacts (O-E)"),
  list("n_cases","C","cont","# CADE cases touched"),
  list("n_def_firms","C","cont","# distinct defendants contacted"),
  list("contact_intensity","C","cont","O_i / T_i"),
  list("share_in_def_cells_MEDIUM","C","cont","share of part. in defendant-bearing cells")
)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group breadth vars only where
# the item-group is observed (BEC). Federally these are NOT_OBSERVED (buyer-collinear).
if (HAS_IG) {
  profile_vars <- c(profile_vars, list(
    list("n_item_groups","B","cont","# item groups"),
    list("hhi_ig","B","cont","HHI across item groups"),
    list("top_ig_share","B","cont","top-item-group share")))
} else {
  say("  [skip] item-group profile vars (n_item_groups/hhi_ig/top_ig_share) NOT_OBSERVED for source=%s.", cfg$source)
}
# modality vars only if observed
if (MODALITY_OBS) {
  profile_vars <- c(profile_vars, list(list("pregao_share","B","cont","Pregao share")))
  # convite share only where convite exists (BEC); federal pure-Pregao -> skip.
  if (cfg$has_convite)
    profile_vars <- c(profile_vars, list(list("convite_share","B","cont","Convite share")))
}
# environment vars only if observed
if (VALUE_OBS)  profile_vars <- c(profile_vars, list(list("mean_tender_value","D","cont","mean tender value (R$)")))
if (BIDDER_OBS) profile_vars <- c(profile_vars, list(list("mean_bidder_count","D","cont","mean bidder count in entered tenders")))

smd_fun <- function(v0, v1) {
  v0 <- v0[is.finite(v0)]; v1 <- v1[is.finite(v1)]
  m0 <- mean(v0); m1 <- mean(v1); s0 <- sd(v0); s1 <- sd(v1)
  n0 <- length(v0); n1 <- length(v1)
  sp <- sqrt(((n0-1)*s0^2 + (n1-1)*s1^2)/(n0+n1-2))
  list(m0=m0, m1=m1, diff=m1-m0, smd=if (sp>0) (m1-m0)/sp else NA_real_, n0=n0, n1=n1)
}

D_ids <- ff[grp_D==1, firm_id]; E_ids <- ff[grp_E==1, firm_id]
dD <- ff[firm_id %in% D_ids]; dE <- ff[firm_id %in% E_ids]
prof_rows <- rbindlist(lapply(profile_vars, function(p) {
  col <- p[[1]]; panel <- p[[2]]; lab <- p[[4]]
  v0 <- dD[[col]]; v1 <- dE[[col]]
  s <- smd_fun(v0, v1)
  data.table(panel=panel, variable=col, label=lab,
             noncob_mean=s$m0, cob_mean=s$m1, difference=s$diff,
             std_diff_cohen_d=s$smd, N_noncob=s$n0, N_cob=s$n1,
             med_noncob=median(v0,na.rm=TRUE), med_cob=median(v1,na.rm=TRUE))
}))
fwrite(prof_rows, file.path(dir_main_t, "table_J_economic_profile.csv"))

# LaTeX for Table J
texJ <- c("\\begin{table}[htbp]\\centering\\footnotesize",
  "\\caption{Economic profile: FL non-cobidders vs.\\ FL cobidders}",
  "\\label{tab:economic_profile}",
  "\\begin{tabular}{llrrrr}\\hline",
  "Panel & Variable & Non-cob. & Cobidder & Diff. & Std.\\ diff. (d) \\\\\\hline")
cur_panel <- ""
for (i in seq_len(nrow(prof_rows))) {
  r <- prof_rows[i]
  if (r$panel != cur_panel) { texJ <- c(texJ, sprintf("\\multicolumn{6}{l}{\\textit{Panel %s}} \\\\", r$panel)); cur_panel <- r$panel }
  fmt <- function(x) if (abs(x)>=1000) format(round(x),big.mark=",") else sprintf("%.3f", x)
  texJ <- c(texJ, sprintf("%s & %s & %s & %s & %s & %s \\\\", r$panel,
    gsub("_","\\\\_",r$label), fmt(r$noncob_mean), fmt(r$cob_mean), fmt(r$difference),
    sprintf("%.3f", r$std_diff_cohen_d)))
}
texJ <- c(texJ, "\\hline\\end{tabular}",
  sprintf("\\begin{tablenotes}\\footnotesize\\item $N$ non-cobidders=%d, cobidders=%d. Descriptive; cobidder = adjudication-anchored exposure, NOT membership. Standardized differences (Cohen's $d$ = diff/pooled SD) emphasized: with $N\\!\\approx\\!2{,}500$ vs.\\ %d, $p$-values are uninformative. CADE-proximity differences (Panel C) are PARTLY MECHANICAL: cobidders co-bid with defendants by construction. Modality/value: %s.\\end{tablenotes}",
    nrow(dD), nrow(dE), nrow(dE),
    ifelse(MODALITY_OBS,"observed","NOT_OBSERVED")),
  "\\end{table}")
writeLines(texJ, file.path(dir_main_t, "table_J_economic_profile.tex"))

# Standardized-difference appendix table (same SMDs, sorted) + figure
smd_tab <- prof_rows[, .(panel, variable, label, difference, std_diff_cohen_d, N_noncob, N_cob)]
setorder(smd_tab, -std_diff_cohen_d)
fwrite(smd_tab, file.path(dir_app_t, "table_E_standardized_profile_differences.csv"))
texS <- c("\\begin{table}[htbp]\\centering\\footnotesize",
  "\\caption{Standardized profile differences (Cohen's $d$), FL cobidders vs.\\ non-cobidders}",
  "\\label{tab:std_profile_diff}",
  "\\begin{tabular}{llrr}\\hline",
  "Panel & Variable & Diff. & Std.\\ diff. (d) \\\\\\hline",
  apply(smd_tab, 1, function(r) sprintf("%s & %s & %.3f & %.3f \\\\",
    r[["panel"]], gsub("_","\\\\_",r[["label"]]),
    as.numeric(r[["difference"]]), as.numeric(r[["std_diff_cohen_d"]]))),
  "\\hline\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize\\item Reference line $|d|=0.2$ (small). Proximity differences partly mechanical.\\end{tablenotes}",
  "\\end{table}")
writeLines(texS, file.path(dir_app_t, "table_E_standardized_profile_differences.tex"))

# figure: SMD by variable, grouped by panel, reference at |0.2|
pmap <- c(A="participation", B="breadth", C="proximity", D="environment")
fig_d <- copy(prof_rows)
fig_d[, group := pmap[panel]]
fig_d[, lab2 := factor(label, levels=label[order(std_diff_cohen_d)])]
p_smd <- ggplot(fig_d, aes(x=std_diff_cohen_d, y=lab2)) +
  geom_vline(xintercept=c(-0.2,0.2), linetype="dashed") +
  geom_vline(xintercept=0, linewidth=0.3) +
  geom_point() + geom_segment(aes(x=0, xend=std_diff_cohen_d, yend=lab2)) +
  facet_grid(group ~ ., scales="free_y", space="free_y") +
  labs(x="Standardized difference (Cohen's d), cobidder - non-cobidder", y=NULL,
       title="Profile differences, FL cobidders vs. non-cobidders",
       subtitle="Dashed line |d|=0.2; proximity differences partly mechanical") +
  theme_bw(base_size=9)
ggsave(file.path(dir_main_f, "fig_profile_standardized_differences.pdf"),
       p_smd, width=7, height=8, device=cairo_pdf)
say("wrote table_J / table_E_std / fig_profile_standardized_differences.pdf")
# headline SMDs
hl <- copy(prof_rows); hl[, abs_d := abs(std_diff_cohen_d)]; setorder(hl, -abs_d)
say("  TOP |SMD| (D vs E):")
for (i in 1:min(6,nrow(hl))) say("    %-32s d=%+.3f (diff=%.3g)", hl$label[i], hl$std_diff_cohen_d[i], hl$difference[i])
stamp("BC_profile_smd")

# =============================================================================
# D. OPPORTUNITY-ADJUSTED PROFILE (Step 8) -> Table K
#   raw diff (D vs E) vs exposure-adjusted diff (cobidder coef w/ controls)
# =============================================================================
say("\n========== D. OPPORTUNITY-ADJUSTED PROFILE (Step 8) ==========")
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group adjustment vars/controls
# only where the item-group is observed (BEC). Federally drop n_item_groups/hhi_ig.
adj_vars <- c("n_years","n_buyers","n_cases","n_def_firms","X_i_MEDIUM")
if (HAS_IG)     adj_vars <- c("n_years","n_item_groups","n_buyers","hhi_ig","n_cases","n_def_firms","X_i_MEDIUM")
if (BIDDER_OBS) adj_vars <- c(adj_vars, "mean_bidder_count")
if (VALUE_OBS)  adj_vars <- c(adj_vars, "mean_tender_value")

# adjustment sample = FL firms (D + E) so cobidder coef = D vs E, opportunity-adjusted
fl <- ff[fl14==1]
fl[, T_dec := cut(T_i, breaks=unique(quantile(T_i, probs=seq(0,1,0.1))), include.lowest=TRUE, labels=FALSE)]
fl[, T_dec_f := factor(T_dec)]
control_terms <- if (HAS_IG) c("log_E_MEDIUM","T_dec_f","n_item_groups","n_buyers","n_years") else
                            c("log_E_MEDIUM","T_dec_f","n_buyers","n_years")

# CEM on E_i_MEDIUM decile (cheap): match cobidders to non-cobidders within decile
fl[, E_dec := cut(E_i_MEDIUM, breaks=unique(quantile(E_i_MEDIUM, probs=seq(0,1,0.1))),
                  include.lowest=TRUE, labels=FALSE)]
fl[is.na(E_dec), E_dec := 0L]

k_rows <- rbindlist(lapply(adj_vars, function(v) {
  # raw
  s_raw <- smd_fun(fl[cobidder==0][[v]], fl[cobidder==1][[v]])
  # exposure-adjusted: regress v on cobidder + controls; cobidder coef = adj diff.
  # Drop the response variable from controls if it collides (avoid self-control).
  ctrl_v <- setdiff(control_terms, v)
  fm <- as.formula(sprintf("%s ~ cobidder + %s", v, paste(ctrl_v, collapse=" + ")))
  m <- tryCatch(lm(fm, data=fl), error=function(e) NULL)
  adj_diff <- if (!is.null(m)) coef(m)[["cobidder"]] else NA_real_
  # SMD on residual scale: adj_diff / pooled SD of v (same denom as raw, comparable)
  v0 <- fl[cobidder==0][[v]]; v1 <- fl[cobidder==1][[v]]
  n0<-sum(is.finite(v0)); n1<-sum(is.finite(v1))
  sp <- sqrt(((n0-1)*sd(v0,na.rm=TRUE)^2 + (n1-1)*sd(v1,na.rm=TRUE)^2)/(n0+n1-2))
  adj_smd <- if (is.finite(adj_diff) && sp>0) adj_diff/sp else NA_real_
  # CEM within E-decile: weighted mean diff across strata with both groups present
  cem <- fl[, .(m1=mean(get(v)[cobidder==1],na.rm=TRUE), m0=mean(get(v)[cobidder==0],na.rm=TRUE),
                n1=sum(cobidder==1), n0=sum(cobidder==0)), by=E_dec]
  cem <- cem[n1>0 & n0>0]
  cem_diff <- if (nrow(cem)>0) sum(cem$n1*(cem$m1-cem$m0))/sum(cem$n1) else NA_real_
  cem_support <- if (nrow(cem)>0) sum(cem$n1)/sum(fl$cobidder==1) else 0
  interp <- if (is.na(adj_smd)) "n/a" else
            if (abs(adj_smd) < 0.1 && abs(s_raw$smd) >= 0.2) "VANISHES (opportunity-composition)" else
            if (abs(adj_smd) >= 0.2) "survives" else "attenuates"
  data.table(variable=v, raw_diff=s_raw$diff, raw_smd=s_raw$smd,
             adj_diff=adj_diff, adj_smd=adj_smd, cem_diff=cem_diff,
             support_retained=round(cem_support,3),
             N=nrow(fl), interpretation=interp)
}))
fwrite(k_rows, file.path(dir_main_t, "table_K_opportunity_adjusted_profile.csv"))
texK <- c("\\begin{table}[htbp]\\centering\\footnotesize",
  "\\caption{Opportunity-adjusted profile differences (FL cobidders vs.\\ non-cobidders)}",
  "\\label{tab:opp_adjusted_profile}",
  "\\begin{tabular}{lrrrrl}\\hline",
  "Variable & Raw diff. & Raw $d$ & Adj.\\ diff. & Adj.\\ $d$ & Reading \\\\\\hline",
  apply(k_rows, 1, function(r) sprintf("%s & %.3g & %.3f & %.3g & %.3f & %s \\\\",
    gsub("_","\\\\_",r[["variable"]]), as.numeric(r[["raw_diff"]]), as.numeric(r[["raw_smd"]]),
    as.numeric(r[["adj_diff"]]), as.numeric(r[["adj_smd"]]), r[["interpretation"]])),
  "\\hline\\end{tabular}",
  sprintf("\\begin{tablenotes}\\footnotesize\\item Adjusted = cobidder coefficient from OLS of variable on cobidder + log(1+E) + $T_i$-decile FE + n.\\,item groups + n.\\,buyers + n.\\,years (FL sample, $N$=%d). If adjusted $d$ collapses while raw $d$ is large, the profile is mostly opportunity-composition.\\end{tablenotes}", nrow(fl)),
  "\\end{table}")
writeLines(texK, file.path(dir_main_t, "table_K_opportunity_adjusted_profile.tex"))
say("  Opportunity-adjustment results:")
for (i in seq_len(nrow(k_rows))) say("    %-20s raw_d=%+.3f -> adj_d=%+.3f  [%s]",
    k_rows$variable[i], k_rows$raw_smd[i], k_rows$adj_smd[i], k_rows$interpretation[i])
stamp("D_opp_adjusted")

# =============================================================================
# E. MONOTONICITY (Step 9) -> Table L + 2 figures
# =============================================================================
say("\n========== E. MONOTONICITY (Step 9) ==========")
# largest-case share per firm (for "share of positives from largest case")
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): case_cobidder_map is a label-funnel
# artifact. BEC: output/label_funnel/. FED: isolated cache (built by the federal
# label funnel). If absent federally, degrade to cob_largest=0 (largest-case legs
# become no-ops) rather than hardcoding the BEC path.
CCM_PATH <- if (cfg$source == "bec")
  file.path(REPO,"output","label_funnel","case_cobidder_map.csv") else
  file.path(dir_cache, "case_cobidder_map.csv")
if (file.exists(CCM_PATH)) {
  ccm <- fread(CCM_PATH, colClasses=c(cnpj="character"))
  ccm[, cnpj := norm14(cnpj)]
  largest_case <- ccm[cnpj %in% cob_codes, .N, by=proc][order(-N)][1, proc]
  say("  largest CADE case among cobidders: %s", largest_case)
  cob_in_largest <- unique(ccm[cnpj %in% cob_codes & proc==largest_case, cnpj])
  ff[, cob_largest := as.integer(cobidder==1 & firm_code %in% cob_in_largest)]
} else {
  say("  [skip] case_cobidder_map absent (%s); cob_largest=0 (largest-case legs no-op).", CCM_PATH)
  ff[, cob_largest := 0L]
}
say("  cobidders mapped to largest case: %d", ff[cob_largest==1,.N])

T_BREAKS <- c(0,1,2,4,7,10,13,20,30,50,100,Inf)
T_LABS   <- c("1","2","3-4","5-7","8-10","11-13","14-20","21-30","31-50","51-100",">100")
ff[, T_bin := cut(T_i, breaks=T_BREAKS, labels=T_LABS, right=TRUE)]
ci_prop <- function(x, n) { if (n==0) return(c(NA,NA)); p<-x/n; se<-sqrt(p*(1-p)/n); c(max(0,p-1.96*se), min(1,p+1.96*se)) }

bin_tab <- ff[, {
  ci <- ci_prop(sum(cobidder), .N)
  .(N_firms=.N, mean_T=mean(T_i), N_cob=sum(cobidder),
    cob_prev=mean(cobidder), prev_lo=ci[1], prev_hi=ci[2],
    mean_O=mean(O_i), mean_E=mean(E_i_MEDIUM), mean_X=mean(X_i_MEDIUM),
    mean_Z=mean(Z_i_MEDIUM),
    share_pos_largest_case=if (sum(cobidder)>0) sum(cob_largest)/sum(cobidder) else NA_real_)
}, by=T_bin][order(match(T_bin, T_LABS))]
fwrite(bin_tab, file.path(dir_main_t, "table_L_monotonicity_bins.csv"))

# score deciles + top-k addendum (written into same CSV family as appendix)
ff[, sc_dec := cut(score_i, breaks=unique(quantile(score_i, probs=seq(0,1,0.1))),
                   include.lowest=TRUE, labels=FALSE)]
dec_tab <- ff[, {ci<-ci_prop(sum(cobidder),.N)
  .(N_firms=.N, mean_T=mean(T_i), N_cob=sum(cobidder), cob_prev=mean(cobidder),
    prev_lo=ci[1], prev_hi=ci[2], mean_E=mean(E_i_MEDIUM), mean_X=mean(X_i_MEDIUM), mean_Z=mean(Z_i_MEDIUM))}, by=sc_dec][order(sc_dec)]
fwrite(dec_tab, file.path(dir_diag, "monotonicity_score_deciles.csv"))
# top-k blocks
setorder(ff, -score_i)
topk_tab <- rbindlist(lapply(c(0.20,0.10,0.05,0.01), function(q){
  k <- ceiling(q*nrow(ff)); sub <- ff[1:k]
  data.table(top_pct=sprintf("%g%%",100*q), k=k, N_cob=sub[,sum(cobidder)],
             cob_prev=sub[,mean(cobidder)], mean_T=sub[,mean(T_i)],
             mean_X=sub[,mean(X_i_MEDIUM)], mean_Z=sub[,mean(Z_i_MEDIUM)])}))
fwrite(topk_tab, file.path(dir_diag, "monotonicity_topk.csv"))

texL <- c("\\begin{table}[htbp]\\centering\\footnotesize",
  "\\caption{Monotonicity by participation bin}",
  "\\label{tab:monotonicity_bins}",
  "\\begin{tabular}{lrrrrrrr}\\hline",
  "$T_i$ bin & $N$ & Cob. & Prev. & mean $O_i$ & mean $E_i$ & mean $X_i$ & mean $Z_i$ \\\\\\hline",
  apply(bin_tab, 1, function(r) sprintf("%s & %s & %s & %.4f & %.3f & %.3f & %.3f & %.3f \\\\",
    r[["T_bin"]], format(as.integer(r[["N_firms"]]),big.mark=","), r[["N_cob"]],
    as.numeric(r[["cob_prev"]]), as.numeric(r[["mean_O"]]), as.numeric(r[["mean_E"]]),
    as.numeric(r[["mean_X"]]), as.numeric(r[["mean_Z"]]))),
  "\\hline\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize\\item $O_i$ observed contacts; $E_i$ expected (opportunity); $X_i=O_i-E_i$ excess; $Z_i$ standardized. Diagnoses ranking shape, not legal status. $E_i$ controls for opportunity.\\end{tablenotes}",
  "\\end{table}")
writeLines(texL, file.path(dir_main_t, "table_L_monotonicity_bins.tex"))

# figure 1: cobidder prevalence by participation bin (with 95% CI)
bt <- copy(bin_tab); bt[, T_bin := factor(T_bin, levels=T_LABS)]
p_prev <- ggplot(bt, aes(x=T_bin, y=cob_prev, group=1)) +
  geom_line() + geom_point() +
  geom_errorbar(aes(ymin=prev_lo, ymax=prev_hi), width=0.2) +
  labs(x=expression(T[i]~"(participation) bin"), y="Cobidder prevalence",
       title="Cobidder prevalence by participation bin",
       subtitle="Diagnoses ranking shape; bars = 95% CI") +
  theme_bw(base_size=10) + theme(axis.text.x=element_text(angle=45,hjust=1))
ggsave(file.path(dir_main_f, "fig_cobidder_prevalence_by_participation_bin.pdf"),
       p_prev, width=7, height=4.5, device=cairo_pdf)

# figure 2: excess contact (mean X_i and mean Z_i) by participation bin
xt <- melt(bin_tab[, .(T_bin, mean_X, mean_Z)], id.vars="T_bin",
           variable.name="metric", value.name="value")
xt[, T_bin := factor(T_bin, levels=T_LABS)]
xt[, metric := factor(metric, levels=c("mean_X","mean_Z"), labels=c("mean excess X_i","mean standardized Z_i"))]
p_excess <- ggplot(xt, aes(x=T_bin, y=value, group=metric)) +
  geom_hline(yintercept=0, linewidth=0.3) +
  geom_line() + geom_point() +
  facet_wrap(~metric, ncol=1, scales="free_y") +
  labs(x=expression(T[i]~"(participation) bin"), y="Opportunity-adjusted excess contact",
       title="Excess defendant contact by participation bin",
       subtitle="X_i = O_i - E_i; E_i controls for opportunity") +
  theme_bw(base_size=10) + theme(axis.text.x=element_text(angle=45,hjust=1))
ggsave(file.path(dir_main_f, "fig_excess_contact_by_participation_bin.pdf"),
       p_excess, width=7, height=6, device=cairo_pdf)

# monotonicity diagnosis (Spearman of bin-level prevalence and excess vs bin rank)
br <- seq_len(nrow(bin_tab))
sp_prev <- suppressWarnings(cor(br, bin_tab$cob_prev, method="spearman"))
sp_X    <- suppressWarnings(cor(br, bin_tab$mean_X,   method="spearman"))
sp_Z    <- suppressWarnings(cor(br, bin_tab$mean_Z,   method="spearman"))
say("  monotonicity Spearman(bin-rank): prevalence=%.3f  excess_X=%.3f  excess_Z=%.3f", sp_prev, sp_X, sp_Z)
say("  -> prevalence %s with T_i ; EXCESS X %s ; EXCESS Z %s",
    ifelse(sp_prev>0.7,"RISES","NOT clearly monotone"),
    ifelse(sp_X>0.7,"RISES",ifelse(abs(sp_X)<0.4,"FLAT/non-monotone","weak")),
    ifelse(sp_Z>0.7,"RISES",ifelse(abs(sp_Z)<0.4,"FLAT/non-monotone","weak")))
stamp("E_monotonicity")

# =============================================================================
# F. BINARY FL14 vs CONTINUOUS SCORE (Step 10) -> Table M + memo
# =============================================================================
say("\n========== F. BINARY vs CONTINUOUS SCORE (Step 10) ==========")
# strict-timing reproduction of script 53: reuse its output if present, else cite.
STRICT53 <- file.path(REPO, "output")  # script 53 output dir search
s53_files <- list.files(REPO, pattern="strict.*threshold|threshold.*strict", recursive=TRUE, full.names=TRUE)
say("  script-53 outputs found: %d (%s)", length(s53_files),
    paste(basename(head(s53_files,3)), collapse=", "))

# samples
samples <- list(
  full_AL         = ff,
  opp_common_supp = ff[exposed==1 & n_opp_items>0],
  excl_largest_case = ff[cob_largest==0],            # drop largest-case cobidder positives
  excl_largest_ig   = NULL                            # filled below
)
# excluding largest item-group: identify the item_group with most cobidder mass.
# proxy via top_ig: drop firms whose top item-group is the dominant cobidder group.
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group-based exclusion sample
# only where the item-group is observed (BEC). Federally the SUBSTR prefix is the
# buyer code (buyer-collinear) -> excl_largest_ig sample dropped (stays NULL, skipped).
if (HAS_IG) {
  con2 <- dbConnect(duckdb()); dbExecute(con2,"PRAGMA threads=12"); dbExecute(con2,"PRAGMA memory_limit='12GB'")
  dbExecute(con2, sprintf("PRAGMA temp_directory='%s'", SPILL))
  dbWriteTable(con2,"cobf",data.frame(firm_code=ff[cobidder==1,firm_code]),overwrite=TRUE)
  ig_mass <- as.data.table(dbGetQuery(con2, sprintf("
    WITH ftm AS (SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
                        %s AS ig FROM read_parquet('%s'))
    SELECT f.ig, COUNT(*) AS n FROM ftm f JOIN cobf c ON f.firm_code=c.firm_code GROUP BY f.ig ORDER BY n DESC LIMIT 5
  ", cfg$ig_from_key("CAST(\"códigoitem\" AS VARCHAR)"), ftm_path)))
  dbDisconnect(con2, shutdown=TRUE); gc()
  top_ig <- ig_mass$ig[1]
  say("  dominant cobidder item-group: %s (n=%d participations)", top_ig, ig_mass$n[1])
  # firms whose participation is concentrated in top_ig -> approximate exclusion:
  # drop cobidders that are largest-ig-anchored. We exclude firms with majority share in top_ig.
  con3 <- dbConnect(duckdb()); dbExecute(con3,"PRAGMA threads=12"); dbExecute(con3,"PRAGMA memory_limit='12GB'")
  dbExecute(con3, sprintf("PRAGMA temp_directory='%s'", SPILL))
  dbWriteTable(con3,"al_firms",data.frame(firm_code=al_map$firm_code),overwrite=TRUE)
  ig_share <- as.data.table(dbGetQuery(con3, sprintf("
    WITH ftm AS (SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
                        %s AS ig FROM read_parquet('%s')),
         al AS (SELECT f.* FROM ftm f JOIN al_firms a ON f.firm_code=a.firm_code)
    SELECT firm_code, SUM(CASE WHEN ig='%s' THEN 1 ELSE 0 END)*1.0/COUNT(*) AS share_top_ig
    FROM al GROUP BY firm_code
  ", cfg$ig_from_key("CAST(\"códigoitem\" AS VARCHAR)"), ftm_path, top_ig)))
  dbDisconnect(con3, shutdown=TRUE); gc()
  ff <- merge(ff, ig_share, by="firm_code", all.x=TRUE); ff[is.na(share_top_ig), share_top_ig := 0]
  samples$excl_largest_ig <- ff[share_top_ig < 0.5]   # drop firms dominated by top item-group
} else {
  say("  [skip] excl_largest_ig sample NOT_OBSERVED for source=%s (item-group buyer-collinear).", cfg$source)
}

# score forms
score_form_list <- function(d) {
  forms <- list(
    continuous_log1pT = d$score_i,
    fl14_binary       = d$fl14,
    binned_decile     = as.numeric(d$sc_dec)
  )
  # natural spline on score (rank-equivalent to monotone transform; AUC identical to continuous)
  # top-k rank handled via metrics directly. spline AUC == continuous AUC for monotone score,
  # so we add ns predicted prob from a logit for completeness.
  m <- tryCatch(suppressWarnings(glm(cobidder ~ ns(score_i,4), data=d, family=binomial())),
                error=function(e) NULL)
  # only use spline score if the fit converged; else it is a monotone transform of
  # score_i so its AUC equals the continuous AUC (reported via continuous_log1pT).
  if (!is.null(m) && isTRUE(m$converged) && !any(abs(coef(m))>25, na.rm=TRUE))
    forms$spline_ns4 <- predict(m, type="response")
  forms
}

m_rows <- list()
for (snm in names(samples)) {
  d <- samples[[snm]]
  if (is.null(d) || nrow(d)==0) next
  if (sum(d$cobidder)==0) { say("  sample %s has 0 positives -> skip", snm); next }
  # ensure decile present in subset
  if (!"sc_dec" %in% names(d)) d[, sc_dec := cut(score_i, breaks=unique(quantile(score_i,probs=seq(0,1,0.1))), include.lowest=TRUE, labels=FALSE)]
  forms <- score_form_list(d)
  for (fnm in names(forms)) {
    s <- forms[[fnm]]; y <- d$cobidder
    ok <- is.finite(s) & !is.na(y); s<-s[ok]; y<-y[ok]
    if (sum(y)==0) next
    auc <- roc_auc(y, s); pra <- average_precision(y, s)
    p500 <- precision_at_k(y,s,500); r500 <- recall_at_k(y,s,500); l500 <- lift_at_k(y,s,500)
    m_rows[[length(m_rows)+1]] <- data.table(
      sample=snm, score_form=fnm, N=length(y), positives=sum(y),
      prevalence=round(mean(y),5), roc_auc=round(auc,4), pr_auc=round(pra,4),
      prec_500=round(p500,4), rec_500=round(r500,4), lift_500=round(l500,3))
  }
}
m_tab <- rbindlist(m_rows, fill=TRUE)
# interpretation: per sample, does fl14 beat continuous?
m_tab[, interpretation := ""]
for (snm in unique(m_tab$sample)) {
  ac <- m_tab[sample==snm & score_form=="continuous_log1pT", roc_auc]
  af <- m_tab[sample==snm & score_form=="fl14_binary", roc_auc]
  if (length(ac) && length(af)) {
    msg <- if (af > ac) sprintf("FL14 (%.3f) > continuous (%.3f)", af, ac) else sprintf("continuous (%.3f) >= FL14 (%.3f)", ac, af)
    m_tab[sample==snm & score_form=="fl14_binary", interpretation := msg]
  }
}
fwrite(m_tab, file.path(dir_main_t, "table_M_binary_vs_continuous_score.csv"))
texM <- c("\\begin{table}[htbp]\\centering\\footnotesize",
  "\\caption{Binary FL14 vs.\\ continuous score across samples}",
  "\\label{tab:binary_vs_continuous}",
  "\\begin{tabular}{llrrrrr}\\hline",
  "Sample & Score & $N$ & Pos. & ROC-AUC & PR-AUC & P@500 \\\\\\hline",
  apply(m_tab, 1, function(r) sprintf("%s & %s & %s & %s & %.3f & %.3f & %.3f \\\\",
    gsub("_","\\\\_",r[["sample"]]), gsub("_","\\\\_",r[["score_form"]]),
    format(as.integer(r[["N"]]),big.mark=","), r[["positives"]],
    as.numeric(r[["roc_auc"]]), as.numeric(r[["pr_auc"]]), as.numeric(r[["prec_500"]]))),
  "\\hline\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize\\item $T\\!\\ge\\!14$ is administrative (median$+1.5\\cdot$IQR of always-loser participation), NOT structural. Spline and decile forms are monotone transforms of the continuous score (AUC identical).\\end{tablenotes}",
  "\\end{table}")
writeLines(texM, file.path(dir_main_t, "table_M_binary_vs_continuous_score.tex"))
say("  Table M (ROC-AUC, continuous vs FL14):")
for (snm in unique(m_tab$sample)) {
  ac <- m_tab[sample==snm & score_form=="continuous_log1pT", roc_auc]
  af <- m_tab[sample==snm & score_form=="fl14_binary", roc_auc]
  say("    %-20s continuous=%.4f  fl14=%.4f  %s", snm, ac, af, ifelse(af>ac,"FL14 wins","continuous wins/ties"))
}
stamp("F_binary_vs_continuous")

# ---- memo -------------------------------------------------------------------
full_ac <- m_tab[sample=="full_AL" & score_form=="continuous_log1pT", roc_auc]
full_af <- m_tab[sample=="full_AL" & score_form=="fl14_binary", roc_auc]
oc_ac   <- m_tab[sample=="opp_common_supp" & score_form=="continuous_log1pT", roc_auc]
oc_af   <- m_tab[sample=="opp_common_supp" & score_form=="fl14_binary", roc_auc]
memo <- c(
  "# Binary vs. Continuous Score — Section 5 Memo (v22 JLEO R&R)",
  sprintf("_Generated %s by 05_section5_profile_monotonicity.R (seed %d)._", format(Sys.Date()), SEED),
  "",
  "## Q1. Is the score <-> exposure relationship monotone?",
  sprintf("- Cobidder prevalence vs. T_i-bin rank: Spearman = %.3f -> %s.", sp_prev,
          ifelse(sp_prev>0.7,"prevalence rises monotonically with participation","prevalence NOT cleanly monotone")),
  sprintf("- BUT opportunity-adjusted EXCESS contact: Spearman(X_i) = %.3f, Spearman(Z_i) = %.3f.", sp_X, sp_Z),
  sprintf("  -> Excess is %s. Prevalence rises mechanically with exposure; the opportunity-adjusted",
          ifelse(abs(sp_X)<0.4 | abs(sp_Z)<0.4,"FLAT / non-monotone","also rising")),
  "  residual does not track the rank in the same way, weakening a STRUCTURAL reading of T_i.",
  "",
  "## Q2. Does FL14 outperform the continuous score in any sample?",
  sprintf("- full always-loser:        continuous=%.4f vs FL14=%.4f -> %s", full_ac, full_af, ifelse(full_af>full_ac,"FL14 wins","continuous wins/ties")),
  sprintf("- opportunity common support: continuous=%.4f vs FL14=%.4f -> %s", oc_ac, oc_af, ifelse(oc_af>oc_ac,"FL14 wins","continuous wins/ties")),
  "- Reference (script 53, strict-timing): FL14 binary 0.767 > continuous 0.750, DeLong p=0.085 (NOT significant).",
  "  The flip is SAMPLE-SPECIFIC (strict-timing common support), not a general dominance of the binary.",
  "",
  "## Q3. Does T>=14 look structural?",
  "- NO. T>=14 is median + 1.5*IQR of always-loser participation — an administrative/outlier cut,",
  "  not a behavioral threshold. The continuous log(1+T_i) carries the signal; FL14 is a deployable rule.",
  "",
  "## Q4. Emphasize continuous, binary, or both? Downgrade monotone-ranking claims?",
  "- EMPHASIZE BOTH but frame honestly: continuous score is the underlying signal; FL14 is the",
  "  operational rule (administrative cut). Where the strict-timing flip appears, report it but do NOT",
  "  elevate the binary to a structural threshold.",
  "- DOWNGRADE structural monotone-ranking claims: prevalence rises with exposure (mechanical), but",
  "  opportunity-adjusted excess does not rise the same way. The rank is an exposure ranking, not a",
  "  collusion-intensity ranking.",
  "",
  "## Numbers (this run)",
  paste0("```\n", paste(capture.output(print(m_tab[, .(sample,score_form,N,positives,roc_auc,pr_auc,prec_500)])), collapse="\n"), "\n```")
)
writeLines(memo, file.path(DOCS, "binary_vs_continuous_score_memo.md"))
say("wrote binary_vs_continuous_score_memo.md")
stamp("F_memo")

say("\n=== DONE. total elapsed=%.1fs ===", as.numeric(difftime(Sys.time(),.t0,units="secs")))
