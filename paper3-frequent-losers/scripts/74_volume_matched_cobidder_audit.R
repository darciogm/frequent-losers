# 74_volume_matched_cobidder_audit.R
#
# Volume-matched cobidder audit — the "strongest remaining within-data audit"
# flagged in docs/hypotheses/{exposure-discipline,cobidder-profile-distinct}.md.
#
# Concern (Referee 2): cobidders inside the always-loser stratum participate in
# MORE tenders than other frequent losers. AN-028 (7 participation dimensions,
# Cohen's d 0.19-1.00) and AN-031 (bid-level gap-to-winner d = -0.28) could
# therefore be artifacts of raw participation volume rather than evidence of a
# qualitatively distinct cover-bidder type. unique_winners crossed, pairs at
# least 5, and item groups touched all mechanically increase with the number of
# bids; a high-volume firm looks "distinct" for purely arithmetic reasons.
#
# This script holds participation volume fixed by matching cobidders (treated)
# to FL non-cobidders (control) on tenders_count, then re-computes the
# standardized differences inside the matched sample. A dimension whose
# Cohen's d survives matching is distinct *beyond* volume; a dimension whose d
# collapses toward zero was a volume artifact.
#
# Two matching estimators:
#   M1  Nearest-neighbour 1:1 on the logit propensity score of tenders_count,
#       caliper 0.2 SD, no replacement  (the "PS matching on tenders_count"
#       the docs ask for).
#   M2  Coarsened exact matching (CEM) on tenders_count cutpoints, weighted.
#
# Honest-accounting flags baked in:
#   * share_facing_direct_cade is CIRCULAR — cobidders are DEFINED as
#     always-losers that bid alongside direct CADE defendants, so this
#     dimension is ~tautological. Computed for completeness, EXCLUDED from the
#     headline verdict.
#   * unique_winners / pairs_at_least_5 / n_item_groups are volume-mechanical;
#     attenuation under matching is expected and is itself the finding.
#   * The causal-distinctness claim of H5 rests on the NON-volume,
#     NON-circular dimensions: share_repeat_5, item_group_HHI,
#     median_gap_to_winner, sd_gap_to_winner.
#
# Outputs:
#   output/volume_matched_audit/firm_panel.csv
#   output/volume_matched_audit/balance.csv
#   output/volume_matched_audit/matched_standardized_diffs.csv
#   output/volume_matched_audit/audit_log.txt

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb)
  library(data.table); library(arrow)
  library(MatchIt)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "volume_matched_audit")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)
set.seed(20260523L)

# ---------- telemetry ------------------------------------------------------
LOG <- file.path(OUT, "audit_log.txt")
.t0 <- Sys.time()
say <- function(...) {
  msg <- sprintf(...)
  cat(msg, "\n")
  cat(msg, "\n", file = LOG, append = TRUE)
}
rss_mb <- function() {
  tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE)) / 1024),
           error = function(e) NA_real_)
}
stamp <- function(stage) say("  [%s] elapsed=%.1fs  RSS=%s MB",
                             stage, as.numeric(difftime(Sys.time(), .t0, units = "secs")), rss_mb())

cat("", file = LOG)  # truncate
say("=== 74_volume_matched_cobidder_audit.R ===")
say("host=%s  nproc=%s  date=%s",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern = TRUE), error = function(e) "?"),
    format(Sys.time()))
say("RAM: %s", tryCatch(paste(system("free -h | awk 'NR==2{print $2\" total, \"$7\" avail\"}'", intern = TRUE)),
                        error = function(e) "?"))

# ---------- (0) firm classification (mirrors scripts 60/62) ----------------

cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cob$firm_code)

xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(xm$firm_code)

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count >= 14L)]
fl_codes <- fp[is_fl == 1L, firm_code]

fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

class_dt <- data.table(firm_code = fls$firm_code,
                       tenders_count = fls$total_participations)
# Within-stratum design: cobidder vs FL-non-cobidder ONLY. Direct CADE
# defendants are removed even if they happen to be cobidders, to keep the
# treated class clean (cover-bidder type, not adjudicated principals).
class_dt[, class_label := fcase(
  firm_code %in% setdiff(cob_codes, direct_codes), "cobidder",
  firm_code %in% setdiff(setdiff(fl_codes, cob_codes), direct_codes), "FL_non_cobidder",
  default = "other"
)]
panel <- class_dt[class_label %in% c("cobidder", "FL_non_cobidder")]
say("\nWithin-FL stratum: cobidders=%d  FL_non_cobidders=%d",
    panel[class_label == "cobidder", .N], panel[class_label == "FL_non_cobidder", .N])
stamp("classification")

# ---------- (1) participation dimensions via DuckDB (mirrors script 60) ----

say("\n[1] participation dimensions from firm_tender_map ...")
ftm_path <- file.path(BASE, "data/processed/firm_tender_map.parquet")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

losers_winners <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc,
           CAST(\"códigoitem\"  AS VARCHAR) AS item,
           CAST(\"won\" AS INTEGER) AS won
    FROM read_parquet('%s')
  ),
  winners AS (SELECT oc, item, firm_code AS winner FROM ftm WHERE won = 1),
  losers  AS (SELECT oc, item, firm_code AS loser  FROM ftm WHERE won = 0)
  SELECT loser AS firm_code, winner, oc, item
  FROM losers JOIN winners USING (oc, item)
", ftm_path)))
dbDisconnect(con, shutdown = TRUE)
say("  loser-winner edges: %s", format(nrow(losers_winners), big.mark = ","))
stamp("ftm-extract")

pairs <- losers_winners[, .N, by = .(firm_code, winner)]
setnames(pairs, "N", "pair_n")
firm_pairs <- pairs[, .(
  unique_winners   = uniqueN(winner),
  pairs_at_least_5 = sum(pair_n >= 5L),
  share_repeat_5   = sum(pair_n[pair_n >= 5L]) / sum(pair_n)
), by = firm_code]

fp_cade <- pairs[, .(cade_pair_bids = sum(pair_n[winner %in% direct_codes]),
                     total_pair_bids = sum(pair_n)), by = firm_code]
fp_cade[, share_facing_direct_cade := cade_pair_bids / pmax(total_pair_bids, 1L)]
firm_pairs <- merge(firm_pairs, fp_cade[, .(firm_code, share_facing_direct_cade)],
                    by = "firm_code", all.x = TRUE)
firm_pairs[is.na(share_facing_direct_cade), share_facing_direct_cade := 0]

losers_winners[, item_group := substr(item, 1, 2)]
firm_ig <- losers_winners[, .(n_bids = .N), by = .(firm_code, item_group)]
firm_ig[, total := sum(n_bids), by = firm_code]
firm_ig[, share := n_bids / total]
firm_ig_hhi <- firm_ig[, .(item_group_HHI = sum(share^2),
                           n_item_groups  = uniqueN(item_group)), by = firm_code]
firm_pairs <- merge(firm_pairs, firm_ig_hhi, by = "firm_code", all.x = TRUE)
rm(losers_winners, pairs, firm_ig); gc()
stamp("participation-dims")

# ---------- (2) bid-level gap-to-winner via DuckDB (mirrors script 62) -----

say("\n[2] bid-level gap-to-winner from bid_level_full_v14 ...")
bid_path <- file.path(BASE, "data/processed/bid_level_full_v14.parquet")
stopifnot(file.exists(bid_path))
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

firm_bid <- as.data.table(dbGetQuery(con, sprintf("
  WITH cleaned AS (
    SELECT LPAD(CAST(\"Código Fornecedor\" AS VARCHAR), 14, '0') AS firm_code,
           \"Numero da OC\" AS oc, \"Código Item\" AS item,
           TRY_CAST(\"Flag Vencedor\" AS INTEGER) AS won,
           TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bp
    FROM read_parquet('%s')
    WHERE \"Código Fornecedor\" IS NOT NULL
      AND \"Valor Unitário Proposta\" IS NOT NULL
      AND \"Descrição Procedimento Compra\" IN ('CONVITE', 'PREGÃO ELETRÔNICO')
  ),
  with_winner AS (
    SELECT *, MIN(CASE WHEN won = 1 AND bp > 0 THEN bp END)
                OVER (PARTITION BY oc, item) AS win_bp
    FROM cleaned WHERE bp > 0
  ),
  per_bid AS (
    SELECT firm_code,
           CASE WHEN win_bp > 0 AND (bp - win_bp) / win_bp BETWEEN -0.99 AND 10
                THEN (bp - win_bp) / win_bp END AS gap_to_winner
    FROM with_winner WHERE won = 0
  )
  SELECT firm_code,
         COUNT(gap_to_winner)                AS n_with_gap,
         AVG(gap_to_winner)                  AS mean_gap_to_winner,
         STDDEV(gap_to_winner)               AS sd_gap_to_winner,
         approx_quantile(gap_to_winner, 0.5) AS median_gap_to_winner,
         approx_quantile(gap_to_winner, 0.75) AS p75_gap_to_winner
  FROM per_bid GROUP BY firm_code HAVING COUNT(gap_to_winner) >= 5
", bid_path)))
dbDisconnect(con, shutdown = TRUE)
say("  firms with >=5 usable gap obs: %s", format(nrow(firm_bid), big.mark = ","))
stamp("bidlevel-dims")

# ---------- (3) assemble firm panel ----------------------------------------

panel <- merge(panel, firm_pairs, by = "firm_code", all.x = TRUE)
panel <- merge(panel, firm_bid,   by = "firm_code", all.x = TRUE)
panel[, treat := as.integer(class_label == "cobidder")]
# Firms with no loss-bid edges (NA participation dims) cannot be characterized.
panel <- panel[!is.na(unique_winners)]
fwrite(panel, file.path(OUT, "firm_panel.csv"))
say("  panel firms: %d (cob=%d, FLnc=%d) ; with gap=%d",
    nrow(panel), panel[treat == 1, .N], panel[treat == 0, .N],
    panel[!is.na(median_gap_to_winner), .N])

# Dimension registry: name, label, kind, requires_gap
dims <- data.table(
  name = c("unique_winners", "pairs_at_least_5", "n_item_groups",
           "share_repeat_5", "item_group_HHI",
           "share_facing_direct_cade",
           "median_gap_to_winner", "sd_gap_to_winner",
           "mean_gap_to_winner", "p75_gap_to_winner"),
  kind = c("volume-mechanical", "volume-mechanical", "volume-mechanical",
           "behavioral", "behavioral",
           "CIRCULAR (excluded from verdict)",
           "behavioral", "behavioral", "behavioral", "behavioral"),
  needs_gap = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE)
)

# ---------- (4) Cohen's d helpers ------------------------------------------

cd_unw <- function(x, y) {
  x <- x[is.finite(x)]; y <- y[is.finite(y)]
  if (length(x) < 3L || length(y) < 3L) return(NA_real_)
  sp <- sqrt(((length(x)-1)*var(x) + (length(y)-1)*var(y)) / (length(x)+length(y)-2))
  if (!is.finite(sp) || sp == 0) return(NA_real_)
  (mean(x) - mean(y)) / sp
}
wmean <- function(x, w) sum(x*w) / sum(w)
wvar  <- function(x, w) { m <- wmean(x, w); sum(w*(x-m)^2) / (sum(w) - 1) }
cd_w <- function(x, y, wx, wy) {
  ok <- is.finite(x) & is.finite(wx); x <- x[ok]; wx <- wx[ok]
  ok <- is.finite(y) & is.finite(wy); y <- y[ok]; wy <- wy[ok]
  if (length(x) < 3L || length(y) < 3L) return(NA_real_)
  nx <- sum(wx); ny <- sum(wy)
  sp <- sqrt(((nx-1)*wvar(x,wx) + (ny-1)*wvar(y,wy)) / (nx+ny-2))
  if (!is.finite(sp) || sp == 0) return(NA_real_)
  (wmean(x,wx) - wmean(y,wy)) / sp
}

# Compute a row of d / p / means for a given subset + weight vector
diff_row <- function(dt, dim, w = NULL, label = "") {
  xt <- dt[treat == 1, get(dim)]; xc <- dt[treat == 0, get(dim)]
  if (is.null(w)) {
    d <- cd_unw(xt, xc)
    a <- xt[is.finite(xt)]; b <- xc[is.finite(xc)]
    p <- if (length(a) >= 3 && length(b) >= 3)
      tryCatch(wilcox.test(a, b)$p.value, error = function(e) NA_real_) else NA_real_
    mt <- mean(xt, na.rm = TRUE); mc <- mean(xc, na.rm = TRUE)
    n_t <- sum(is.finite(xt)); n_c <- sum(is.finite(xc))
  } else {
    wt <- dt[treat == 1, get(w)]; wc <- dt[treat == 0, get(w)]
    d <- cd_w(xt, xc, wt, wc)
    p <- NA_real_  # weighted Wilcoxon not standard; rely on weighted d for CEM
    mt <- wmean(xt[is.finite(xt)], wt[is.finite(xt)])
    mc <- wmean(xc[is.finite(xc)], wc[is.finite(xc)])
    n_t <- sum(wt[is.finite(xt)]); n_c <- sum(wc[is.finite(xc)])
  }
  data.table(estimator = label, dimension = dim,
             mean_cob = mt, mean_ctrl = mc, cohens_d = d, wilcoxon_p = p,
             n_cob = n_t, n_ctrl = n_c)
}

# ---------- (5) RAW (unmatched) standardized diffs -------------------------

say("\n[5] RAW (unmatched) standardized diffs ...")
raw_rows <- rbindlist(lapply(dims$name, function(dm) {
  sub <- if (dims[name == dm, needs_gap]) panel[!is.na(get(dm))] else panel
  diff_row(sub, dm, w = NULL, label = "RAW")
}))
print(raw_rows[, .(dimension, mean_cob = round(mean_cob,3), mean_ctrl = round(mean_ctrl,3),
                   d = round(cohens_d,3), p = signif(wilcoxon_p,3), n_cob, n_ctrl)])

# ---------- (6) M1: PS nearest-neighbour 1:1 caliper -----------------------

say("\n[6] M1 — PS NN 1:1 on tenders_count, caliper 0.2 SD ...")
m1 <- matchit(treat ~ tenders_count, data = panel,
              method = "nearest", distance = "glm", link = "logit",
              caliper = 0.2, ratio = 1, replace = FALSE)
say("%s", paste(capture.output(print(summary(m1)$nn)), collapse = "\n"))
md1 <- as.data.table(match.data(m1))
say("  matched: cob=%d  ctrl=%d", md1[treat==1,.N], md1[treat==0,.N])

# Balance on tenders_count: standardized mean diff pre vs post
smd <- function(dt, var) {
  t <- dt[treat==1, get(var)]; c <- dt[treat==0, get(var)]
  (mean(t,na.rm=TRUE) - mean(c,na.rm=TRUE)) /
    sqrt((var(t,na.rm=TRUE) + var(c,na.rm=TRUE))/2)
}
bal <- data.table(
  variable = "tenders_count",
  smd_raw     = smd(panel, "tenders_count"),
  smd_matched_M1 = smd(md1, "tenders_count"),
  mean_cob_raw = panel[treat==1, mean(tenders_count)],
  mean_ctrl_raw= panel[treat==0, mean(tenders_count)],
  mean_cob_M1  = md1[treat==1, mean(tenders_count)],
  mean_ctrl_M1 = md1[treat==0, mean(tenders_count)]
)
fwrite(bal, file.path(OUT, "balance.csv"))
say("  tenders_count SMD: raw=%.3f -> matched=%.3f", bal$smd_raw, bal$smd_matched_M1)

m1_rows <- rbindlist(lapply(dims$name, function(dm) {
  sub <- if (dims[name == dm, needs_gap]) md1[!is.na(get(dm))] else md1
  diff_row(sub, dm, w = NULL, label = "M1_PS_NN")
}))

# ---------- (7) M2: CEM on tenders_count, weighted -------------------------

say("\n[7] M2 — CEM on tenders_count cutpoints, weighted ...")
cut_tc <- unique(quantile(panel$tenders_count, probs = seq(0, 1, 0.1), na.rm = TRUE))
m2 <- matchit(treat ~ tenders_count, data = panel, method = "cem",
              cutpoints = list(tenders_count = cut_tc))
md2 <- as.data.table(match.data(m2))
say("  CEM retained: cob=%d  ctrl=%d (weights sum cob=%.1f ctrl=%.1f)",
    md2[treat==1,.N], md2[treat==0,.N],
    md2[treat==1, sum(weights)], md2[treat==0, sum(weights)])
say("  tenders_count SMD after CEM: %.3f",
    (wmean(md2[treat==1,tenders_count], md2[treat==1,weights]) -
     wmean(md2[treat==0,tenders_count], md2[treat==0,weights])) /
    sqrt((var(md2[treat==1,tenders_count]) + var(md2[treat==0,tenders_count]))/2))

m2_rows <- rbindlist(lapply(dims$name, function(dm) {
  sub <- if (dims[name == dm, needs_gap]) md2[!is.na(get(dm))] else md2
  diff_row(sub, dm, w = "weights", label = "M2_CEM")
}))

# ---------- (8) assemble, attenuation, verdict -----------------------------

all_rows <- rbindlist(list(raw_rows, m1_rows, m2_rows), fill = TRUE)
all_rows <- merge(all_rows, dims[, .(dimension = name, kind, needs_gap)],
                  by = "dimension", all.x = TRUE)

wide <- dcast(all_rows, dimension + kind ~ estimator, value.var = "cohens_d")
setnames(wide, c("RAW","M1_PS_NN","M2_CEM"), c("d_raw","d_M1","d_M2"), skip_absent = TRUE)
wide[, retention_M1 := ifelse(abs(d_raw) > 1e-9, d_M1 / d_raw, NA_real_)]
ord <- c("unique_winners","pairs_at_least_5","n_item_groups",
         "share_repeat_5","item_group_HHI","share_facing_direct_cade",
         "median_gap_to_winner","sd_gap_to_winner","mean_gap_to_winner","p75_gap_to_winner")
wide <- wide[match(ord, dimension)]

fwrite(all_rows, file.path(OUT, "matched_standardized_diffs.csv"))

say("\n========== VERDICT TABLE (Cohen's d: cobidder vs FL non-cobidder) ==========")
say("%-26s %-18s %7s %7s %7s %7s", "dimension","kind","d_raw","d_M1","d_M2","ret_M1")
for (i in seq_len(nrow(wide))) {
  r <- wide[i]
  say("%-26s %-18s %7.3f %7.3f %7.3f %6.0f%%",
      r$dimension, substr(r$kind,1,18),
      r$d_raw, r$d_M1, r$d_M2,
      100*ifelse(is.na(r$retention_M1),NA,r$retention_M1))
}

# Headline verdict: non-volume, non-circular dims
verdict_dims <- c("share_repeat_5","item_group_HHI","median_gap_to_winner","sd_gap_to_winner")
say("\n--- Headline (non-volume, non-circular) dimensions after PS matching (M1) ---")
for (dm in verdict_dims) {
  r <- m1_rows[dimension == dm]
  rr <- raw_rows[dimension == dm]
  say("  %-24s d_raw=%+.3f -> d_M1=%+.3f  (Wilcoxon p_M1=%.3g, n_cob=%d)",
      dm, rr$cohens_d, r$cohens_d, r$wilcoxon_p, r$n_cob)
}
stamp("DONE")
say("\nOutputs in %s", OUT)
