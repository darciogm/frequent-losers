# 77_reverse_causality_timing.R
#
# Reverse-causality / deployment timing test (Referee Major 4). The frequent-
# loser (FL) signal is observationally ambiguous: cobidders could be cartel
# cover bidders DEPLOYED during a cartel's operation (FL is a cartel role), or
# they could be sincere low-cost optimists who bid on everything and rarely win
# (FL is just persistent losing; conditioning on win_rate=0 compounds this via
# survivorship). The two stories differ in TIMING:
#   DEPLOYMENT          -> participation concentrated around cartel contact.
#   SINCERE PERSISTENCE -> flat participation across the firm's active life.
#
# Cartel conduct windows are NOT available as structured data (CADE records give
# only filing year and post-window judgment dates; explicit conduct spans exist
# only as free text for ~3 cases). We therefore use a window-FREE, within-firm
# anchor that needs no exogenous window: each cobidder's CADE-CONTACT YEARS --
# the years in which it actually co-bid in the same tender-item as a direct CADE
# defendant. The test asks whether a cobidder's participation is OVER-weighted
# toward its contact years relative to the share of its active years that are
# contact years. That difference is mechanically zero under uniform (sincere)
# participation and positive under deployment.
#
# Three tests:
#  (1) PRIMARY within-cobidder: Delta_share = (share of participation in contact
#      years) - (share of active years that are contact years). Mean > 0 with
#      p<0.05 => participation bunches in cartel-contact years (deployment).
#  (2) CROSS-FIRM volume-matched concentration: cobidders vs FL non-cobidders,
#      CEM-matched on tenders_count (mirrors scripts 74/76). Compare temporal
#      concentration (year-HHI), active-year count, active-year span. Higher
#      concentration / shorter span for cobidders => episodic (deployment);
#      similar/longer => spread (sincere persistence).
#  (3) EVENT STUDY around first contact year (tau = year - first_contact_year),
#      mean participation by tau; descriptive support.
#
# PRE-COMMITTED VERDICT (stated before reading results):
#   DEPLOYMENT-CONSISTENT (reverse-causality concern weakened) iff
#     (i)  mean Delta_share > 0 with p < 0.05, AND
#     (ii) cobidders show higher temporal concentration (year-HHI) than
#          volume-matched FL non-cobidders (Cohen's d > 0, Wilcoxon p < 0.05).
#   Otherwise: SINCERE PERSISTENCE NOT RULED OUT -> the manuscript must disclose
#   the observational equivalence; the screen stays predictive/triage, not causal.
#
# Outputs:
#   output/reverse_causality_timing/firm_year_panel.csv
#   output/reverse_causality_timing/concentration_metrics.csv
#   output/reverse_causality_timing/event_study_tau.csv
#   output/reverse_causality_timing/audit_log.txt

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow); library(MatchIt)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "reverse_causality_timing")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)
setDTthreads(12L); set.seed(20260530L)

LOG <- file.path(OUT, "audit_log.txt"); .t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
stamp <- function(s) say("  [%s] elapsed=%.1fs", s, as.numeric(difftime(Sys.time(), .t0, units="secs")))
say("=== 77_reverse_causality_timing.R ===  host=%s date=%s", Sys.info()[["nodename"]], format(Sys.time()))

# ---------- (0) classes ------------------------------------------------------
cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cob$firm_code)
xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(xm$firm_code)
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, cobidder := as.integer(firm_code %in% cob_codes)]
say("always-losers=%d  cobidders-in-universe=%d  defendants=%d", nrow(al), al[cobidder==1,.N], length(direct_codes))

# ---------- (1) firm x year panel + contact years (DuckDB) -------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
ftm_path <- file.path(BASE, "data/processed/firm_tender_map.parquet")

# participation per firm-year = distinct tender-items
fy <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           (CAST(\"numerodaoc\" AS VARCHAR)||'|'||CAST(\"códigoitem\" AS VARCHAR)) AS ti,
           CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS INTEGER) AS yr
    FROM read_parquet('%s')
  )
  SELECT firm_code, yr, COUNT(DISTINCT ti) AS n_part
  FROM ftm WHERE yr BETWEEN 2009 AND 2019 GROUP BY 1,2
", ftm_path)))

# contact years: cobidder x year where it shares a tender-item with a defendant
contact <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           (CAST(\"numerodaoc\" AS VARCHAR)||'|'||CAST(\"códigoitem\" AS VARCHAR)) AS ti,
           CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR),12,4) AS INTEGER) AS yr
    FROM read_parquet('%s')
  ),
  def_items AS (SELECT DISTINCT ti FROM ftm JOIN direct d ON ftm.firm_code=d.firm_code)
  SELECT f.firm_code, f.yr, COUNT(DISTINCT f.ti) AS n_contact_items
  FROM ftm f JOIN def_items di ON f.ti = di.ti
  WHERE f.yr BETWEEN 2009 AND 2019 GROUP BY 1,2
", ftm_path)))
dbDisconnect(con, shutdown = TRUE)
stamp("duckdb panel")

fy <- fy[firm_code %in% al$firm_code]      # restrict to always-loser universe
fwrite(fy, file.path(OUT, "firm_year_panel.csv"))
say("firm-year rows (always-losers): %s ; contact rows: %s",
    format(nrow(fy), big.mark=","), format(nrow(contact), big.mark=","))

# ---------- (2) per-firm concentration metrics ------------------------------
met <- fy[, {
  tot <- sum(n_part)
  shares <- n_part / tot
  .(tenders_count = tot,
    n_active_years = .N,
    year_hhi = sum(shares^2),
    span = max(yr) - min(yr) + 1L,
    peak_share = max(shares))
}, by = firm_code]
met <- merge(met, al[, .(firm_code, cobidder)], by = "firm_code")
fwrite(met, file.path(OUT, "concentration_metrics.csv"))

# ---------- (3) PRIMARY: within-cobidder Delta_share ------------------------
ck <- merge(fy[firm_code %in% cob_codes], contact[, .(firm_code, yr, n_contact_items)],
            by = c("firm_code","yr"), all.x = TRUE)
ck[is.na(n_contact_items), n_contact_items := 0L]
ds <- ck[, {
  ay <- .N                                   # active years
  cy <- sum(n_contact_items > 0)             # contact years
  part_contact <- sum(n_part[n_contact_items > 0])
  tot <- sum(n_part)
  .(active_years = ay, contact_years = cy,
    share_part_contact = part_contact / tot,
    share_years_contact = cy / ay,
    delta_share = part_contact/tot - cy/ay)
}, by = firm_code]
ds_use <- ds[active_years >= 2 & contact_years >= 1 & contact_years < active_years]
say("\n[PRIMARY] within-cobidder Delta_share (cobidders with >=2 active yrs, 1<=contact<active): N=%d", nrow(ds_use))
wt <- wilcox.test(ds_use$delta_share, mu = 0)
tt <- t.test(ds_use$delta_share, mu = 0)
say("  mean Delta_share = %+.4f (median %+.4f)", mean(ds_use$delta_share), median(ds_use$delta_share))
say("  share part-in-contact = %.3f  vs  share years-contact = %.3f",
    mean(ds_use$share_part_contact), mean(ds_use$share_years_contact))
say("  Wilcoxon (mu=0) p=%.3g ; t-test p=%.3g ; frac(Delta>0)=%.3f",
    wt$p.value, tt$p.value, mean(ds_use$delta_share > 0))
P_delta_pos <- (mean(ds_use$delta_share) > 0) && (wt$p.value < 0.05)

# ---------- (4) CROSS-FIRM volume-matched concentration ---------------------
say("\n[CROSS-FIRM] cobidders vs FL non-cobidders, CEM-matched on tenders_count:")
mc <- met[tenders_count >= 14]               # FL stratum (>=14), volume comparison
mc[, treat := cobidder]
say("  FL stratum: cobidders=%d  FL-non-cobidders=%d", mc[treat==1,.N], mc[treat==0,.N])
cutp <- unique(quantile(mc$tenders_count, probs = seq(0,1,0.1)))
mm <- matchit(treat ~ tenders_count, data = mc, method = "cem",
              cutpoints = list(tenders_count = cutp))
md <- as.data.table(match.data(mm))
cohen_w <- function(x, t, w) {
  x1<-x[t==1]; x0<-x[t==0]; w1<-w[t==1]; w0<-w[t==0]
  m1<-weighted.mean(x1,w1); m0<-weighted.mean(x0,w0)
  sp<-sqrt((var(x1)+var(x0))/2); (m1-m0)/sp
}
cross <- data.table()
for (v in c("year_hhi","n_active_years","span","peak_share")) {
  d  <- cohen_w(md[[v]], md$treat, md$weights)
  p  <- wilcox.test(md[treat==1][[v]], md[treat==0][[v]])$p.value
  m1 <- weighted.mean(md[treat==1][[v]], md[treat==1]$weights)
  m0 <- weighted.mean(md[treat==0][[v]], md[treat==0]$weights)
  cross <- rbind(cross, data.table(metric=v, mean_cob=m1, mean_ctrl=m0, cohens_d=d, wilcoxon_p=p))
  say("  %-16s cob=%.3f ctrl=%.3f  d=%+.3f  p=%.3g", v, m1, m0, d, p)
}
fwrite(cross, file.path(OUT, "cross_firm_matched.csv"))
P_conc <- cross[metric=="year_hhi", cohens_d > 0 & wilcoxon_p < 0.05]

# ---------- (5) EVENT STUDY around first contact year -----------------------
fc <- ck[n_contact_items > 0, .(first_contact = min(yr)), by = firm_code]
es <- merge(ck, fc, by = "firm_code")
es[, tau := yr - first_contact]
es_tab <- es[tau >= -3 & tau <= 3, .(mean_part = mean(n_part), n_firms = uniqueN(firm_code)), by = tau][order(tau)]
fwrite(es_tab, file.path(OUT, "event_study_tau.csv"))
say("\n[EVENT STUDY] mean participation by tau (year - first contact):")
for (i in seq_len(nrow(es_tab))) say("  tau=%+d  mean_part=%.2f  (n_firms=%d)", es_tab$tau[i], es_tab$mean_part[i], es_tab$n_firms[i])

# ---------- (6) verdict ------------------------------------------------------
say("\n========== VERDICT vs PRE-COMMITTED CRITERION ==========")
say("  (i)  mean Delta_share>0 & p<0.05         : %s", ifelse(P_delta_pos, "PASS", "FAIL"))
say("  (ii) cobidders higher year-HHI (d>0,p<.05): %s", ifelse(P_conc, "PASS", "FAIL"))
say("  OVERALL: %s", ifelse(P_delta_pos & P_conc,
    "DEPLOYMENT-CONSISTENT (reverse-causality concern weakened)",
    "SINCERE PERSISTENCE NOT RULED OUT -> disclose observational equivalence"))
stamp("DONE")
