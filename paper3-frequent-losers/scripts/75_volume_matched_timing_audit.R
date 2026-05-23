# 75_volume_matched_timing_audit.R
#
# Second behavioral channel for H5, under the same volume-matching discipline
# as AN-041 (script 74). AN-041 showed the cobidder PROFILE distinctness
# survives matching on tenders_count, but the only surviving BID-CONDUCT signal
# was the median gap-to-winner (the dispersion sub-signal collapsed). A single
# bid-conduct channel is thin. This script asks whether cobidders are also
# distinct on BID TIMING --- a channel orthogonal to price --- and whether that
# distinctness survives volume matching.
#
# Timing metrics (PREGAO only, where real-time revision dynamics exist; 100%
# timestamp coverage, mean 3.76 bids/firm-item):
#   - mean_nbids        : revision intensity (bids per tender-item)
#   - median_interbid   : seconds between a firm's consecutive bids (firm_span/(nb-1))
#   - mean_last_pos     : normalized position of the firm's LAST bid in the
#                         tender's bidding window [0,1] (1 = bids to the end)
#   - mean_engage_frac  : fraction of the tender window the firm is active [0,1]
#
# Matching: cobidder (treated) vs FL non-cobidder (control) on tenders_count
# (total_participations), PS nearest-neighbour caliper + CEM, identical to
# script 74.
#
# Verdict question: does a timing dimension hold |d| away from 0 with p<0.05
# AFTER volume matching? If yes, H5's bid-conduct distinctness rests on two
# independent channels (price gap + timing), not one.
#
# Outputs:
#   output/volume_matched_timing/firm_timing_panel.csv
#   output/volume_matched_timing/timing_standardized_diffs.csv
#   output/volume_matched_timing/timing_balance.csv
#   output/volume_matched_timing/timing_audit_log.txt

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
OUT  <- file.path(BASE, "output", "volume_matched_timing")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)
setDTthreads(12L)
set.seed(20260523L)

LOG <- file.path(OUT, "timing_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE))/1024), error = function(e) NA_real_)
stamp <- function(s) say("  [%s] elapsed=%.1fs RSS=%s MB", s, as.numeric(difftime(Sys.time(), .t0, units = "secs")), rss_mb())

say("=== 75_volume_matched_timing_audit.R ===")
say("host=%s nproc=%s date=%s", Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern = TRUE), error = function(e) "?"), format(Sys.time()))

# ---------- (0) classification (mirrors script 74) -------------------------
cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]; cob_codes <- unique(cob$firm_code)
xm  <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]; direct_codes <- unique(xm$firm_code)
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count >= 14L)]
fl_codes <- fp[is_fl == 1L, firm_code]
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

class_dt <- data.table(firm_code = fls$firm_code, tenders_count = fls$total_participations)
class_dt[, class_label := fcase(
  firm_code %in% setdiff(cob_codes, direct_codes), "cobidder",
  firm_code %in% setdiff(setdiff(fl_codes, cob_codes), direct_codes), "FL_non_cobidder",
  default = "other")]
panel <- class_dt[class_label %in% c("cobidder", "FL_non_cobidder")]
say("\nWithin-FL stratum: cobidders=%d FL_non_cobidders=%d",
    panel[class_label=="cobidder", .N], panel[class_label=="FL_non_cobidder", .N])
stamp("classification")

# ---------- (1) per-firm pregão timing metrics via DuckDB ------------------
say("\n[1] extracting pregão timing metrics ...")
bid_path <- file.path(BASE, "data/processed/bid_level_full_v14.parquet")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

firm_timing <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (
    SELECT LPAD(CAST(\"Código Fornecedor\" AS VARCHAR),14,'0') AS firm_code,
           \"Numero da OC\" AS oc, \"Código Item\" AS item,
           TRY_CAST(\"Data Hr Proposta\" AS TIMESTAMP) AS ts
    FROM read_parquet('%s')
    WHERE \"Descrição Procedimento Compra\" = 'PREGÃO ELETRÔNICO'
      AND \"Data Hr Proposta\" IS NOT NULL
      AND \"Código Fornecedor\" IS NOT NULL
  ),
  tender AS (
    SELECT oc, item, MIN(ts) AS t0, epoch(MAX(ts)) - epoch(MIN(ts)) AS span
    FROM bids GROUP BY oc, item
  ),
  firm_cell AS (
    SELECT b.firm_code, b.oc, b.item, COUNT(*) AS nb,
           epoch(MAX(b.ts)) - epoch(t.t0) AS last_off,
           epoch(MAX(b.ts)) - epoch(MIN(b.ts)) AS firm_span,
           t.span AS span
    FROM bids b JOIN tender t USING (oc, item)
    GROUP BY b.firm_code, b.oc, b.item, t.t0, t.span
  ),
  firm_cell2 AS (
    SELECT firm_code, nb,
           CASE WHEN span > 0 THEN last_off / span END   AS last_pos,
           CASE WHEN span > 0 THEN firm_span / span END   AS engage_frac,
           CASE WHEN nb > 1   THEN firm_span / (nb - 1) END AS interbid_sec
    FROM firm_cell
  )
  SELECT firm_code,
         COUNT(*)                              AS n_pregao_items,
         AVG(nb)                               AS mean_nbids,
         AVG(last_pos)                         AS mean_last_pos,
         AVG(engage_frac)                      AS mean_engage_frac,
         approx_quantile(interbid_sec, 0.5)    AS median_interbid_sec
  FROM firm_cell2
  GROUP BY firm_code
  HAVING COUNT(*) >= 5
", bid_path)))
dbDisconnect(con, shutdown = TRUE)
say("  firms with >=5 pregão items: %s", format(nrow(firm_timing), big.mark = ","))
stamp("timing-extract")

# log-transform the heavy-tailed inter-bid interval
firm_timing[, log_interbid := log1p(median_interbid_sec)]

panel <- merge(panel, firm_timing, by = "firm_code", all.x = TRUE)
panel[, treat := as.integer(class_label == "cobidder")]
panel <- panel[!is.na(n_pregao_items)]
fwrite(panel, file.path(OUT, "firm_timing_panel.csv"))
say("  panel (>=5 pregão items): cob=%d FLnc=%d",
    panel[treat==1, .N], panel[treat==0, .N])

dims <- c("mean_nbids", "log_interbid", "mean_last_pos", "mean_engage_frac")
dim_lab <- c(mean_nbids = "revision intensity (bids/item)",
             log_interbid = "log inter-bid interval (s)",
             mean_last_pos = "last-bid position in window",
             mean_engage_frac = "engagement span fraction")

# ---------- (2) Cohen's d helpers (identical to script 74) -----------------
cd_unw <- function(x, y) { x <- x[is.finite(x)]; y <- y[is.finite(y)]
  if (length(x) < 3L || length(y) < 3L) return(NA_real_)
  sp <- sqrt(((length(x)-1)*var(x) + (length(y)-1)*var(y))/(length(x)+length(y)-2))
  if (!is.finite(sp) || sp == 0) return(NA_real_); (mean(x)-mean(y))/sp }
wmean <- function(x,w) sum(x*w)/sum(w)
wvar  <- function(x,w){ m <- wmean(x,w); sum(w*(x-m)^2)/(sum(w)-1) }
cd_w <- function(x,y,wx,wy){ ok <- is.finite(x)&is.finite(wx); x<-x[ok]; wx<-wx[ok]
  ok <- is.finite(y)&is.finite(wy); y<-y[ok]; wy<-wy[ok]
  if (length(x)<3L||length(y)<3L) return(NA_real_); nx<-sum(wx); ny<-sum(wy)
  sp <- sqrt(((nx-1)*wvar(x,wx)+(ny-1)*wvar(y,wy))/(nx+ny-2))
  if (!is.finite(sp)||sp==0) return(NA_real_); (wmean(x,wx)-wmean(y,wy))/sp }

diff_row <- function(dt, dim, w = NULL, label = "") {
  xt <- dt[treat==1, get(dim)]; xc <- dt[treat==0, get(dim)]
  if (is.null(w)) {
    d <- cd_unw(xt, xc); a <- xt[is.finite(xt)]; b <- xc[is.finite(xc)]
    p <- if (length(a)>=3 && length(b)>=3) tryCatch(wilcox.test(a,b)$p.value, error=function(e) NA_real_) else NA_real_
    mt <- mean(xt, na.rm=TRUE); mc <- mean(xc, na.rm=TRUE); n_t <- length(a); n_c <- length(b)
  } else {
    wt <- dt[treat==1, get(w)]; wc <- dt[treat==0, get(w)]
    d <- cd_w(xt, xc, wt, wc); p <- NA_real_
    mt <- wmean(xt[is.finite(xt)], wt[is.finite(xt)]); mc <- wmean(xc[is.finite(xc)], wc[is.finite(xc)])
    n_t <- sum(wt[is.finite(xt)]); n_c <- sum(wc[is.finite(xc)])
  }
  data.table(estimator=label, dimension=dim, mean_cob=mt, mean_ctrl=mc,
             cohens_d=d, wilcoxon_p=p, n_cob=n_t, n_ctrl=n_c)
}

# ---------- (3) RAW + matched -----------------------------------------------
say("\n[3] RAW (unmatched) timing diffs ...")
raw_rows <- rbindlist(lapply(dims, function(dm) diff_row(panel[!is.na(get(dm))], dm, NULL, "RAW")))
print(raw_rows[, .(dimension, d=round(cohens_d,3), p=signif(wilcoxon_p,3), n_cob, n_ctrl)])

say("\n[4] M1 — PS NN 1:1 caliper 0.2 on tenders_count ...")
m1 <- matchit(treat ~ tenders_count, data = panel, method="nearest",
              distance="glm", link="logit", caliper=0.2, ratio=1, replace=FALSE)
md1 <- as.data.table(match.data(m1))
smd <- function(dt,v){ t<-dt[treat==1,get(v)]; c<-dt[treat==0,get(v)]
  (mean(t,na.rm=TRUE)-mean(c,na.rm=TRUE))/sqrt((var(t,na.rm=TRUE)+var(c,na.rm=TRUE))/2) }
say("  matched cob=%d ctrl=%d ; tenders_count SMD %.3f -> %.3f",
    md1[treat==1,.N], md1[treat==0,.N], smd(panel,"tenders_count"), smd(md1,"tenders_count"))
fwrite(data.table(variable="tenders_count", smd_raw=smd(panel,"tenders_count"),
                  smd_matched_M1=smd(md1,"tenders_count")), file.path(OUT,"timing_balance.csv"))
m1_rows <- rbindlist(lapply(dims, function(dm) diff_row(md1[!is.na(get(dm))], dm, NULL, "M1_PS_NN")))

say("\n[5] M2 — CEM on tenders_count deciles ...")
cut_tc <- unique(quantile(panel$tenders_count, probs=seq(0,1,0.1), na.rm=TRUE))
m2 <- matchit(treat ~ tenders_count, data=panel, method="cem", cutpoints=list(tenders_count=cut_tc))
md2 <- as.data.table(match.data(m2))
m2_rows <- rbindlist(lapply(dims, function(dm) diff_row(md2[!is.na(get(dm))], dm, "weights", "M2_CEM")))

# ---------- (6) verdict -----------------------------------------------------
all_rows <- rbindlist(list(raw_rows, m1_rows, m2_rows), fill=TRUE)
fwrite(all_rows, file.path(OUT, "timing_standardized_diffs.csv"))
wide <- dcast(all_rows, dimension ~ estimator, value.var="cohens_d")
setnames(wide, c("RAW","M1_PS_NN","M2_CEM"), c("d_raw","d_M1","d_M2"), skip_absent=TRUE)

say("\n========== TIMING VERDICT (Cohen's d: cobidder vs FL non-cobidder) ==========")
say("%-34s %8s %8s %8s", "dimension", "d_raw", "d_M1", "d_M2")
for (dm in dims) {
  r <- wide[dimension==dm]; pm1 <- m1_rows[dimension==dm, wilcoxon_p]
  say("%-34s %8.3f %8.3f %8.3f   (p_M1=%.3g)", dim_lab[dm], r$d_raw, r$d_M1, r$d_M2, pm1)
}
surv <- m1_rows[abs(cohens_d) >= 0.2 & wilcoxon_p < 0.05, dimension]
say("\nTiming dimensions surviving matching (|d_M1|>=0.2 & p<0.05): %s",
    if (length(surv)) paste(dim_lab[surv], collapse="; ") else "NONE")
stamp("DONE")
say("\nOutputs in %s", OUT)
