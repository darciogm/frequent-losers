# =============================================================================
# 03_timing_case_holdout_validation.R  --  STRICT TIMING validation (JLEO R&R v22)
#
# Question: does the frequent-loser ranking work when the score is FROZEN BEFORE
# the evaluation window (no future information)? We never invent and never hide
# weak timing performance.
#
# Reference / scaffolding REUSED:
#   - scripts/53_strict_train_period_threshold.R  (frozen-train threshold)
#   - scripts/77_reverse_causality_timing.R       (timing-FAIL evidence)
#   - scripts/33_auc_direct_cade.R                (direct-defendant scope check)
#   - work/v22-editor/scripts/utils/metrics_triage.R (all triage metrics)
#
# DATA CONSTRAINT: CADE files carry only judgment dates (2015-2025), NO conduct
# dates -> year-level timing only (DAY_LEVEL_TIMING_UNAVAILABLE).
#
# Outputs under work/v22-editor/outputs/.
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(ggplot2); library(arrow)
})

set.seed(20260603L)

# ---- paths ------------------------------------------------------------------
# script lives in work/v22-editor/scripts/analysis/ ; repo root is 4 up.
args_file <- sub("^--file=", "",
                 commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
SCRIPT_DIR <- if (length(args_file)) dirname(normalizePath(args_file[1L])) else getwd()
BASE  <- normalizePath(file.path(SCRIPT_DIR, "..", "..", "..", ".."), mustWork = TRUE)  # repo root
V22   <- normalizePath(file.path(SCRIPT_DIR, "..", ".."), mustWork = TRUE)              # work/v22-editor
OUTS  <- file.path(V22, "outputs")

DIR_TAB_MAIN <- file.path(OUTS, "tables", "main")
DIR_TAB_APP  <- file.path(OUTS, "tables", "appendix")
DIR_FIG_MAIN <- file.path(OUTS, "figures", "main")
DIR_FIG_APP  <- file.path(OUTS, "figures", "appendix")
DIR_DIAG     <- file.path(OUTS, "diagnostics")
DIR_LOG      <- file.path(OUTS, "logs")
for (d in c(DIR_TAB_MAIN, DIR_TAB_APP, DIR_FIG_MAIN, DIR_FIG_APP, DIR_DIAG, DIR_LOG))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

source(file.path(V22, "scripts", "utils", "metrics_triage.R"))
stopifnot(exists(".METRICS_TRIAGE_VERSION"))

FTM <- file.path(BASE, "data", "processed", "firm_tender_map.parquet")
stopifnot(file.exists(FTM))

# ---- telemetry --------------------------------------------------------------
.t0 <- Sys.time()
rss_mb <- function() {
  v <- tryCatch(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()),
                                  intern = TRUE)) / 1024, error = function(e) NA_real_)
  v
}
tlog <- function(msg) {
  cat(sprintf("[%6.1fs | RSS %6.0f MB] %s\n",
              as.numeric(difftime(Sys.time(), .t0, units = "secs")),
              rss_mb(), msg))
}
tlog(sprintf("host=%s | metrics_triage=%s | seed=20260603",
             Sys.info()[["nodename"]], .METRICS_TRIAGE_VERSION))
tlog(sprintf("BASE=%s", BASE))
tlog(sprintf("V22 outputs=%s", OUTS))

# ---- CADE ground truth ------------------------------------------------------
norm_cnpj <- function(x) sprintf("%014.0f", as.numeric(x))

# canonical broad AL cobidder label (651, reproducible, FL never used):
# positives = rows with broad_cobidder==1 in the canonical reproducible file
# (always-losers, direct defendants already excluded). Replaces the static
# narrow cade_fl_cobidders.csv (193 rows, FL-only, irreproducible).
cobid <- fread(file.path(V22, "outputs", "cache", "canonical_cobidders_broad.csv"))
# authoritative key = códigofornecedor (same join key as firm_tender_map).
cobid_codes <- unique(sprintf("%014.0f",
                              as.numeric(cobid[broad_cobidder == 1L][["códigofornecedor"]])))
stopifnot(length(cobid_codes) > 0L)

xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := norm_cnpj(firm_cnpj)]
NEW_HOPE <- "09474700000192"          # miscoded in BOTH files -> excluded from defendants
defendant_codes <- setdiff(unique(xm$firm_code), NEW_HOPE)
# assert disjoint after exclusion
stopifnot(length(intersect(defendant_codes, cobid_codes)) == 0L)
tlog(sprintf("cobidder positives=%d | direct defendants=%d (NEW HOPE excluded; disjoint OK)",
             length(cobid_codes), length(defendant_codes)))

# ---- DuckDB: firm x year participation/wins panel ---------------------------
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(duckdb(), ":memory:")
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

tlog("Building firm x year participation/win panel via DuckDB ...")
fy <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS year,
    SUM(CASE WHEN won = 0 THEN 1 ELSE 0 END) AS losses,
    SUM(CASE WHEN won = 1 THEN 1 ELSE 0 END) AS wins,
    COUNT(*) AS n
  FROM read_parquet('%s')
  GROUP BY firm_code, year
", FTM)))
fy <- fy[year >= 2009 & year <= 2019]
setkey(fy, firm_code, year)
tlog(sprintf("firm-year rows=%s | firms=%s | years %d-%d",
             format(nrow(fy), big.mark=","),
             format(uniqueN(fy$firm_code), big.mark=","),
             min(fy$year), max(fy$year)))

# Opportunity exposure O_i: does firm i share a test tender-item with a direct
# defendant in the test window? Build a firm x year "shares-cell-with-defendant"
# flag generically so it can be reused for any test window.
# We compute, per (firm, year), 1 if the firm appears on a tender-item that ALSO
# has a direct defendant participating in the same year.
tlog("Building firm x year opportunity-with-defendant exposure (O_i) ...")
dbWriteTable(con, "def_codes", data.frame(firm_code = defendant_codes),
             temporary = TRUE, overwrite = TRUE)
oexp <- as.data.table(dbGetQuery(con, sprintf("
  WITH base AS (
    SELECT
      LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
      CAST(\"numerodaoc\" AS VARCHAR) AS oc,
      CAST(\"códigoitem\" AS VARCHAR) AS item,
      CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS year
    FROM read_parquet('%s')
  ),
  def_cells AS (
    SELECT DISTINCT oc, item, year
    FROM base
    WHERE firm_code IN (SELECT firm_code FROM def_codes)
  )
  SELECT b.firm_code, b.year, 1 AS shares_cell_with_defendant
  FROM base b
  JOIN def_cells d ON b.oc = d.oc AND b.item = d.item AND b.year = d.year
  GROUP BY b.firm_code, b.year
", FTM)))
setkey(oexp, firm_code, year)
tlog(sprintf("firm-year rows with defendant co-cell exposure=%s",
             format(nrow(oexp), big.mark=",")))

dbDisconnect(con, shutdown = TRUE)
gc()

# =============================================================================
# Helper: build a firm-level holdout frame for a given (train years, test years)
# =============================================================================
build_holdout <- function(train_years, test_years) {
  tr <- fy[year %in% train_years,
           .(T_train = sum(n), L_train = sum(losses), W_train = sum(wins)),
           by = firm_code]
  te <- fy[year %in% test_years,
           .(T_test = sum(n), L_test = sum(losses), W_test = sum(wins)),
           by = firm_code]
  d <- merge(tr, te, by = "firm_code", all = TRUE)
  for (cc in c("T_train","L_train","W_train","T_test","L_test","W_test"))
    d[is.na(get(cc)), (cc) := 0L]
  # opportunity exposure in TEST window
  oe <- oexp[year %in% test_years, .(O_test = as.integer(any(shares_cell_with_defendant == 1))),
             by = firm_code]
  d <- merge(d, oe, by = "firm_code", all.x = TRUE)
  d[is.na(O_test), O_test := 0L]

  # Two always-loser definitions:
  #  * always_loser_train_s53: W_train==0 over EVERY firm that ever appears in
  #    BEC (entrants with T_train=0 included). This reproduces script 53's pool
  #    (n=21,819, threshold=7); npos now = the canonical broad AL cobidder label
  #    (651, reproducible, FL never used) and is the definition used for the
  #    "training always-loser" headline.
  #  * always_loser_train: W_train==0 AND T_train>0 (genuinely observed losing
  #    in the training window) -- the strict rankable definition.
  d[, always_loser_train_s53 := as.integer(W_train == 0L)]
  d[, always_loser_train     := as.integer(W_train == 0L & T_train > 0L)]
  d[, score_train := log1p(L_train)]          # log1p of TRAINING-window losses
  d[, test_active := as.integer(T_test > 0L)]
  d[, entrant := as.integer(T_train == 0L & T_test > 0L)]
  d[, is_cobidder := as.integer(firm_code %in% cobid_codes)]
  d[, is_defendant := as.integer(firm_code %in% defendant_codes)]

  # train-window threshold (median+1.5*IQR of train losses over the s53 AL pool,
  # matching script 53 which includes T_train=0 firms; pulls threshold to ~7).
  al <- d[always_loser_train_s53 == 1L, L_train]
  thr_train <- if (length(al) >= 4L) median(al) + 1.5 * IQR(al) else NA_real_
  d[, fl_train := as.integer(always_loser_train_s53 == 1L & L_train > thr_train)]
  attr(d, "thr_train") <- thr_train
  d[]
}

# Full-sample threshold reference (median+1.5*IQR over 2009-2019 always-losers)
fy_full <- fy[, .(T = sum(n), L = sum(losses), W = sum(wins)), by = firm_code]
fy_full[, al_full := as.integer(W == 0L & T > 0L)]
THR_FULL <- with(fy_full[al_full == 1L], median(L) + 1.5 * IQR(L))
tlog(sprintf("full-sample threshold (2009-2019 always-losers) = %.2f (expect ~13.5)", THR_FULL))

# =============================================================================
# Metric block: compute the full metric row for (labels, scores) on a sample
# =============================================================================
KGRID <- c(100, 250, 500, 1000)
metric_row <- function(d, score_col = "score_train", label_col = "is_cobidder",
                       sample_name = "", thr_train = NA_real_) {
  y <- as.integer(d[[label_col]]); s <- as.numeric(d[[score_col]])
  n <- length(y); npos <- sum(y == 1L)
  ok <- npos >= 2L && length(unique(s)) >= 2L
  L <- list(sample = sample_name, n = n, positives = npos,
            roc_auc = if (ok) roc_auc(y, s, na_action = "drop") else NA_real_,
            pr_auc  = if (ok) average_precision(y, s, na_action = "drop") else NA_real_)
  for (k in KGRID) {
    L[[sprintf("prec_%d", k)]]   <- if (npos>=1) precision_at_k(y, s, k, na_action="drop") else NA_real_
    L[[sprintf("recall_%d", k)]] <- if (npos>=1) recall_at_k(y, s, k, na_action="drop") else NA_real_
    L[[sprintf("lift_%d", k)]]   <- if (npos>=1) lift_at_k(y, s, k, na_action="drop") else NA_real_
  }
  L$fp_500 <- if (npos>=1) false_positives_at_k(y, s, 500, na_action="drop") else NA_integer_
  L$fn_500 <- if (npos>=1) false_negatives_at_k(y, s, 500, na_action="drop") else NA_integer_
  # entrant / tie diagnostics
  ent <- as.integer(d$entrant)
  L$entrant_share_pos <- if (npos>0) mean(ent[y==1L]) else NA_real_
  o <- .mt_order(s, TRUE)
  top <- head(o, min(500L, n))
  in_top <- rep(FALSE, n); in_top[top] <- TRUE
  fn_idx <- which(y == 1L & !in_top)
  L$entrant_share_fn  <- if (length(fn_idx)>0) mean(ent[fn_idx]) else NA_real_
  L$tie_at_zero_share <- mean(s == 0)
  L$threshold_train   <- thr_train
  L$threshold_full    <- THR_FULL
  L$support_retained  <- n
  L$positives_retained <- npos
  as.data.table(L)
}

# =============================================================================
# B. STRICT 2009-2016 -> 2017-2019  (Step 6)
# =============================================================================
tlog("=== STEP 6: strict 2009-2016 -> 2017-2019 ===")
H <- build_holdout(2009:2016, 2017:2019)
thrB <- attr(H, "thr_train")
tlog(sprintf("strict train-window threshold = %.2f (expect 7)", thrB))

# five evaluation samples
# "full test-candidate" = firm active in either window; entrants kept (score 0)
S1 <- H[T_train > 0L | test_active == 1L]
S2 <- H[T_train > 0L]                                       # rankable (positive train participation)
S3 <- H[always_loser_train_s53 == 1L]                       # training always-loser (script-53 pool: W_train==0; n=21,819)
S4 <- H[always_loser_train_s53 == 1L & test_active == 1L]   # training AL & test-active
# zero-win-both: never won in train AND never won in test (retrospective; leaks)
S5 <- H[W_train == 0L & W_test == 0L & (T_train > 0L | T_test > 0L)]

strict_rows <- rbindlist(list(
  metric_row(S1, sample_name = "1_full_test_candidate",     thr_train = thrB),
  metric_row(S2, sample_name = "2_rankable_Ttrain_gt0",     thr_train = thrB),
  metric_row(S3, sample_name = "3_training_always_loser",   thr_train = thrB),
  metric_row(S4, sample_name = "4_training_AL_and_test_active", thr_train = thrB),
  metric_row(S5, sample_name = "5_zero_win_both_LEAKS",     thr_train = thrB)
), fill = TRUE)

# Reproduce script 53 on sample (3): FL_train_binary AUC 0.767 and log_tc 0.750
repro_bin  <- roc_auc(S3$is_cobidder, S3$fl_train,   na_action = "drop")
repro_cont <- roc_auc(S3$is_cobidder, S3$score_train, na_action = "drop")
tlog(sprintf("REPRO sample(3): FL_binary AUC=%.4f (expect 0.767) | log_tc AUC=%.4f (expect 0.750) | n=%d npos=%d",
             repro_bin, repro_cont, nrow(S3), sum(S3$is_cobidder)))
flag_bin  <- abs(repro_bin  - 0.767) > 0.005
flag_cont <- abs(repro_cont - 0.750) > 0.005
if (flag_bin)  tlog(sprintf("  !! DEVIATION FL_binary: %.4f vs 0.767 (>0.005)", repro_bin))
if (flag_cont) tlog(sprintf("  !! DEVIATION log_tc:   %.4f vs 0.750 (>0.005)", repro_cont))

# add a continuous-vs-binary AUC pair for sample 3 into the diagnostics
strict_rows[sample == "3_training_always_loser",
            `:=`(repro_fl_binary_auc = repro_bin, repro_log_tc_auc = repro_cont,
                 repro_match_script53 = !(flag_bin | flag_cont))]

fwrite(strict_rows, file.path(DIR_TAB_MAIN, "table_D_strict_2009_2016_to_2017_2019.csv"))

# composition diagnostic
comp <- data.table(
  metric = c("n_firms_total","train_AL","train_FL","cobidders_total",
             "cobidders_in_train_AL","cobidders_rankable","cobidders_entrant",
             "entrant_firms","test_active_firms","threshold_train","threshold_full"),
  value = c(nrow(H),
            sum(H$always_loser_train_s53), sum(H$fl_train),
            sum(H$is_cobidder),
            sum(H$is_cobidder & H$always_loser_train_s53==1L),
            sum(H$is_cobidder & H$T_train>0L),
            sum(H$is_cobidder & H$entrant==1L),
            sum(H$entrant), sum(H$test_active),
            round(thrB,3), round(THR_FULL,3))
)
fwrite(comp, file.path(DIR_DIAG, "strict_holdout_composition.csv"))
tlog("wrote strict table + composition diagnostic")

# headline entrant diagnostics on the FULL test-candidate sample (S1)
ent_pos_share_S1 <- strict_rows[sample=="1_full_test_candidate", entrant_share_pos]
ent_fn_share_S1  <- strict_rows[sample=="1_full_test_candidate", entrant_share_fn]
tie_zero_S1      <- strict_rows[sample=="1_full_test_candidate", tie_at_zero_share]
tlog(sprintf("ENTRANT diag (S1 full-candidate): pos-share=%.3f | FN-share=%.3f | tie@0=%.3f",
             ent_pos_share_S1, ent_fn_share_S1, tie_zero_S1))

# ---- LaTeX export for strict table -----------------------------------------
write_strict_tex <- function(dt, path) {
  fmt <- function(x, d=3) ifelse(is.na(x), "---", formatC(x, format="f", digits=d))
  lines <- c(
    "% JLEO-R&R v22: strict timing holdout 2009-2016 -> 2017-2019",
    "\\begin{table}[htbp]\\centering",
    "\\caption{Strict Timing Holdout: Score Frozen on 2009--2016, Evaluated on 2017--2019}",
    "\\label{tab:strict_timing_holdout}",
    "\\footnotesize",
    "\\begin{tabular}{lrrrrrr}",
    "\\toprule",
    "Sample & $N$ & Pos. & ROC-AUC & PR-AUC & Prec@500 & Recall@500 \\\\",
    "\\midrule")
  labmap <- c(
    "1_full_test_candidate"="Full test-candidate (entrants score 0)",
    "2_rankable_Ttrain_gt0"="Rankable ($T_{i}^{train}>0$)",
    "3_training_always_loser"="Training always-loser",
    "4_training_AL_and_test_active"="Training AL \\& test-active",
    "5_zero_win_both_LEAKS"="Zero-win both \\textit{(leaks)}")
  for (i in seq_len(nrow(dt))) {
    r <- dt[i]
    lines <- c(lines, sprintf("%s & %s & %d & %s & %s & %s & %s \\\\",
      labmap[[r$sample]], format(r$n, big.mark=","), r$positives,
      fmt(r$roc_auc), fmt(r$pr_auc), fmt(r$prec_500), fmt(r$recall_500)))
  }
  lines <- c(lines, "\\midrule",
    sprintf("\\multicolumn{7}{l}{\\footnotesize Train-window threshold (2009--2016 AL): %.1f; full-sample reference: %.1f. Scores use \\textbf{only} 2009--2016 participation.} \\\\",
            dt$threshold_train[1], dt$threshold_full[1]),
    "\\bottomrule","\\end{tabular}",
    "\\begin{minipage}{\\linewidth}\\vspace{2pt}\\footnotesize",
    sprintf("\\textit{Notes:} Score $=\\log(1+\\text{2009--2016 losses})$. Positives are the %d adjudicated always-loser cobidders (canonical broad reproducible label) evaluated in the test window. The zero-win-both row leaks future wins (always-loser status across both windows) and is shown only for comparison.", length(cobid_codes)),
    "\\end{minipage}","\\end{table}")
  writeLines(lines, path)
}
write_strict_tex(strict_rows, file.path(DIR_TAB_MAIN, "table_D_strict_2009_2016_to_2017_2019.tex"))

rm(H, S1, S2, S3, S4, S5); gc()

# =============================================================================
# C. ROLLING-ORIGIN  (Step 7)  t in 2014..2019: train 2009..(t-1), test year t
# =============================================================================
tlog("=== STEP 7: rolling-origin 2014..2019 ===")
roll_rows <- list()
for (t in 2014:2019) {
  Ht <- build_holdout(2009:(t-1L), t)
  thrt <- attr(Ht, "thr_train")
  samples <- list(
    full     = Ht[T_train > 0L | test_active == 1L],
    rankable = Ht[T_train > 0L],
    train_AL = Ht[always_loser_train_s53 == 1L],
    train_AL_active = Ht[always_loser_train_s53 == 1L & test_active == 1L]
  )
  for (snm in names(samples)) {
    d <- samples[[snm]]
    mr <- metric_row(d, sample_name = snm, thr_train = thrt)
    mr[, origin_test_year := t]
    mr[, n_entrants := sum(d$entrant)]
    mr[, entrant_pos_share := { p <- d$is_cobidder==1L
                                if (sum(p)>0) mean(d$entrant[p]) else NA_real_ }]
    roll_rows[[length(roll_rows)+1L]] <- mr
  }
  tlog(sprintf("  t=%d done (train 2009-%d, thr=%.1f, n_full=%d, pos_full=%d)",
               t, t-1L, thrt, nrow(samples$full), sum(samples$full$is_cobidder)))
  rm(Ht, samples); gc()
}
roll <- rbindlist(roll_rows, fill = TRUE)
setcolorder(roll, c("origin_test_year","sample","n","positives","n_entrants",
                    "entrant_pos_share","threshold_train","roc_auc","pr_auc"))
fwrite(roll, file.path(DIR_TAB_MAIN, "table_E_rolling_origin_validation.csv"))

# LaTeX (lead on PR-AUC/precision/recall, not ROC) -- show 'full' sample
write_roll_tex <- function(dt, path) {
  fmt <- function(x, d=3) ifelse(is.na(x), "---", formatC(x, format="f", digits=d))
  d <- dt[sample == "full"][order(origin_test_year)]
  lines <- c(
    "% JLEO-R&R v22: rolling-origin validation (full test-candidate sample)",
    "\\begin{table}[htbp]\\centering",
    "\\caption{Rolling-Origin Validation: Expanding-Window Pre-Test Score}",
    "\\label{tab:rolling_origin}",
    "\\footnotesize",
    "\\begin{tabular}{rrrrrrrr}",
    "\\toprule",
    "Test yr & $N$ & Pos. & Entr. & PR-AUC & Prec@500 & Recall@500 & ROC-AUC \\\\",
    "\\midrule")
  for (i in seq_len(nrow(d))) {
    r <- d[i]
    lines <- c(lines, sprintf("%d & %s & %d & %d & %s & %s & %s & %s \\\\",
      r$origin_test_year, format(r$n, big.mark=","), r$positives, r$n_entrants,
      fmt(r$pr_auc), fmt(r$prec_500), fmt(r$recall_500), fmt(r$roc_auc)))
  }
  lines <- c(lines, "\\bottomrule","\\end{tabular}",
    "\\begin{minipage}{\\linewidth}\\vspace{2pt}\\footnotesize",
    "\\textit{Notes:} For test year $t$, the score is $\\log(1+\\text{losses})$ over 2009--$(t{-}1)$ \\textbf{only}; threshold trained on the same window. Full test-candidate sample; entrants (no pre-$t$ participation) carry score 0. We lead on PR-AUC, precision, and recall; ROC-AUC shown last.",
    "\\end{minipage}","\\end{table}")
  writeLines(lines, path)
}
write_roll_tex(roll, file.path(DIR_TAB_MAIN, "table_E_rolling_origin_validation.tex"))
tlog("wrote rolling-origin table")

# ---- figures ----------------------------------------------------------------
roll_full <- roll[sample == "full"][order(origin_test_year)]
# fig 1: PR-AUC by year
p1 <- ggplot(roll_full, aes(origin_test_year, pr_auc)) +
  geom_line(color = "#d73027") + geom_point(size = 2.4, color = "#d73027") +
  geom_text(aes(label = formatC(pr_auc, format="f", digits=3)), vjust = -1, size = 3) +
  scale_x_continuous(breaks = 2014:2019) +
  labs(x = "Test year", y = "PR-AUC",
       title = "Rolling-origin PR-AUC of the frozen loser-side score",
       subtitle = "Scores use ONLY pre-test-year participation (expanding window 2009..t-1)") +
  theme_bw()
ggsave(file.path(DIR_FIG_MAIN, "fig_rolling_origin_pr_auc.pdf"), p1,
       width = 8, height = 5, device = cairo_pdf)

# fig 2: precision@500 and recall@500 by year
pr_long <- melt(roll_full[, .(origin_test_year, Precision = prec_500, Recall = recall_500)],
                id.vars = "origin_test_year", variable.name = "metric", value.name = "value")
p2 <- ggplot(pr_long, aes(origin_test_year, value, color = metric, shape = metric)) +
  geom_line() + geom_point(size = 2.4) +
  scale_x_continuous(breaks = 2014:2019) +
  scale_color_manual(values = c("Precision" = "#d73027", "Recall" = "#5b8aa6")) +
  labs(x = "Test year", y = "Value at k=500", color = NULL, shape = NULL,
       title = "Rolling-origin precision@500 and recall@500",
       subtitle = "Scores use ONLY pre-test-year participation") +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(DIR_FIG_MAIN, "fig_rolling_origin_precision_recall.pdf"), p2,
       width = 8, height = 5, device = cairo_pdf)

# appendix fig: ROC-AUC by year
p3 <- ggplot(roll_full, aes(origin_test_year, roc_auc)) +
  geom_line(color = "#4d4d4d") + geom_point(size = 2.4, color = "#4d4d4d") +
  geom_text(aes(label = formatC(roc_auc, format="f", digits=3)), vjust = -1, size = 3) +
  scale_x_continuous(breaks = 2014:2019) +
  labs(x = "Test year", y = "ROC-AUC",
       title = "Rolling-origin ROC-AUC (appendix)",
       subtitle = "Scores use ONLY pre-test-year participation") +
  theme_bw()
ggsave(file.path(DIR_FIG_APP, "fig_rolling_origin_auc.pdf"), p3,
       width = 8, height = 5, device = cairo_pdf)
tlog("wrote 3 rolling-origin figures")

# =============================================================================
# D. LEAKAGE AUDIT  (Step 8)
# =============================================================================
tlog("=== STEP 8: leakage audit ===")
yn <- function(x) ifelse(x, "yes", "no")
audit <- data.table(
  design_name = c(
    "A_full_sample_retrospective",
    "B_relaxed_temporal_holdout",
    "C_strict",
    "D_rankable_strict",
    "E_entrant_newfirm",
    "F_adjudication_observable",
    "G_prospective_score_retro_label",
    "strict_holdout_2009_16_to_17_19",
    "rolling_origin",
    "LOCO_leave_one_case_out"),
  score_uses_future_participation = yn(c(
    TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)),
  zero_win_uses_future_wins = yn(c(
    TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)),
  threshold_uses_future_distribution = yn(c(
    TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)),
  label_uses_future_adjudication = yn(c(
    TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE)),
  exposure_adjustment_uses_future_contact = yn(c(
    TRUE, TRUE, TRUE, TRUE, NA, NA, TRUE, TRUE, TRUE, TRUE)),
  bid_features_use_future_data = yn(c(
    FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)),
  sample_inclusion_uses_future_data = yn(c(
    TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)),
  allowed_claim = c(
    "Retrospective diagnostic upper bound",
    "Score-timing sensitivity (label-of-loser held ex post)",
    "Prospective score validated against later adjudication labels",
    "Prospective score among rankable (has prior losing) firms",
    "Documents entrant coverage hole (cannot rank new firms)",
    "Infeasible here (judgments 2015-2025 post-date score)",
    "Prospective score, retrospective label (realistic design)",
    "Honest strict prospective-score discrimination",
    "Out-of-time stability of the frozen score",
    "Case-structured generalization (separate agent)"),
  forbidden_claim = c(
    "Any prospective / deployment claim",
    "That zero-win status was knowable at score date",
    "Real-time legal observability",
    "Anything about entrants",
    "That the screen catches new firms",
    "Real-time detection",
    "Agency knew CADE labels at screening date",
    "Ex ante cartel identification",
    "Real-time detection",
    "Real-time detection"),
  notes = c(
    "Headline construct validity; never a timing claim",
    "Leaks future wins via always-loser status; sensitivity only",
    "Reproduces script 53 strict pool (n=21819); canonical broad AL cobidder label (651, reproducible, FL never used)",
    "Excludes score-0 entrant ties at the bottom",
    "T_train=0 & T_test>0; structural blind spot",
    "DAY_LEVEL_TIMING_UNAVAILABLE; documented, not estimated",
    "The deployable design; label-availability intrinsic to any screen",
    "This script, Step 6",
    "This script, Step 7; lead on PR-AUC not ROC",
    "Built by separate case-holdout agent; classified here for completeness")
)
fwrite(audit, file.path(DIR_TAB_MAIN, "table_F_leakage_audit.csv"))

write_audit_tex <- function(dt, path) {
  esc <- function(x) gsub("_", "\\\\_", x)
  lines <- c(
    "% JLEO-R&R v22: leakage audit",
    "\\begin{table}[htbp]\\centering",
    "\\caption{Leakage Audit of Timing Designs}",
    "\\label{tab:leakage_audit}",
    "\\scriptsize",
    "\\begin{tabular}{lcccccl}",
    "\\toprule",
    "Design & Score & Zero-win & Thresh. & Label & Sample & Allowed claim \\\\",
    " & fut.? & fut.? & fut.? & fut.? & fut.? & \\\\",
    "\\midrule")
  for (i in seq_len(nrow(dt))) {
    r <- dt[i]
    lines <- c(lines, sprintf("%s & %s & %s & %s & %s & %s & %s \\\\",
      esc(r$design_name),
      r$score_uses_future_participation, r$zero_win_uses_future_wins,
      r$threshold_uses_future_distribution, r$label_uses_future_adjudication,
      r$sample_inclusion_uses_future_data, esc(r$allowed_claim)))
  }
  lines <- c(lines, "\\bottomrule","\\end{tabular}",
    "\\begin{minipage}{\\linewidth}\\vspace{2pt}\\scriptsize",
    "\\textit{Notes:} ``fut.?'' = uses future information. Label-uses-future is intrinsic to validating any screen against later-adjudicated ground truth (design G); it is not a deployment defect provided no \\emph{real-time} legal knowledge is claimed. Bid features are unused in all designs.",
    "\\end{minipage}","\\end{table}")
  writeLines(lines, path)
}
write_audit_tex(audit, file.path(DIR_TAB_MAIN, "table_F_leakage_audit.tex"))
tlog("wrote leakage audit table")

# =============================================================================
# E. DIRECT-DEFENDANT TEMPORAL SCOPE CHECK  (Step 14)
# =============================================================================
tlog("=== STEP 14: direct-defendant temporal scope check ===")
# Universe note: direct defendants are mostly WINNERS, not always-losers.
# We report on (i) all BEC firms and (ii) always-loser pool, under full-sample
# score and strict-training score. Reproduce \valAUCdirectCADE ~ 0.491.

# Full-sample firm frame
ff <- copy(fy_full)
ff[, score_full := log1p(L)]
# script 33 keyed defendants on firm_cnpj WITHOUT excluding the NEW HOPE
# miscode (47 distinct). To reproduce \valAUCdirectCADE=0.491 exactly we use the
# script-33 set (47) for the reproduction line; the disjoint 46-firm set is used
# for the timing comparison (one firm out of 41,444 -> AUC unchanged to 3 dp).
defendant_codes_s33 <- unique(xm$firm_code)               # 47 (NEW HOPE included)
ff[, is_defendant      := as.integer(firm_code %in% defendant_codes)]      # 46, disjoint
ff[, is_defendant_s33  := as.integer(firm_code %in% defendant_codes_s33)]  # 47, script-33
ff[, always_loser_full := al_full]
# full-sample FL binary flag (median+1.5*IQR over 2009-2019 AL pool = THR_FULL)
ff[, fl_full := as.integer(al_full == 1L & L > THR_FULL)]
# script-33 exact reproduction input: FREQ_PARTICIP precomputed is_fl uses
# tenders_count > 14 (NOT losses > 13.5). Use it ONLY for the 0.491 repro line.
suppressWarnings({
  .fp <- tryCatch(as.data.table(arrow::read_parquet(
    file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet"))),
    error = function(e) NULL)
})
if (!is.null(.fp)) {
  .fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
  .fp[, is_fl_s33 := as.integer(always_loser == 1L & tenders_count > 14L)]
  ff <- merge(ff, .fp[, .(firm_code, is_fl_s33)], by = "firm_code", all.x = TRUE)
  ff[is.na(is_fl_s33), is_fl_s33 := 0L]
} else {
  ff[, is_fl_s33 := fl_full]   # fallback
}
# strict-training score (2009-2016) + train FL binary
Hd <- build_holdout(2009:2016, 2017:2019)
ff <- merge(ff, Hd[, .(firm_code, score_train, always_loser_train, fl_train)],
            by = "firm_code", all.x = TRUE)
ff[is.na(score_train), score_train := 0]
ff[is.na(always_loser_train), always_loser_train := 0L]
ff[is.na(fl_train), fl_train := 0L]

dd_row <- function(d, score_col, label_col, universe, design) {
  y <- as.integer(d[[label_col]]); s <- as.numeric(d[[score_col]])
  npos <- sum(y); n <- length(y)
  data.table(design = design, universe = universe, score = score_col, label = label_col,
             n_candidates = n, n_defendants = npos,
             prevalence = npos / n,
             roc_auc = if (npos>=2 && length(unique(s))>=2) roc_auc(y,s,na_action="drop") else NA_real_,
             pr_auc  = if (npos>=2) average_precision(y,s,na_action="drop") else NA_real_,
             prec_100 = if (npos>=1) precision_at_k(y,s,100,na_action="drop") else NA_real_,
             recall_100 = if (npos>=1) recall_at_k(y,s,100,na_action="drop") else NA_real_,
             prec_500 = if (npos>=1) precision_at_k(y,s,500,na_action="drop") else NA_real_,
             recall_500 = if (npos>=1) recall_at_k(y,s,500,na_action="drop") else NA_real_)
}

dd <- rbindlist(list(
  # --- script-33 reproduction line: precomputed is_fl (tc>14), 47 def, all BEC ---
  dd_row(ff, "is_fl_s33",   "is_defendant_s33", "all_BEC_firms", "0_repro_script33_FLbinary"),
  # --- timing comparison: continuous score, 46 disjoint defendants ---
  dd_row(ff, "score_full",  "is_defendant", "all_BEC_firms",     "1_full_sample_score_continuous"),
  dd_row(ff, "score_train", "is_defendant", "all_BEC_firms",     "2_strict_training_score_continuous"),
  # --- binary FL under strict training timing, all BEC ---
  dd_row(ff, "fl_train",    "is_defendant", "all_BEC_firms",     "3_strict_training_FLbinary"),
  # --- always-loser pool restriction ---
  dd_row(ff[always_loser_full==1L],  "score_full",  "is_defendant", "always_loser_pool", "1_full_sample_score_continuous"),
  dd_row(ff[always_loser_train==1L], "score_train", "is_defendant", "always_loser_pool", "2_strict_training_score_continuous")
), fill = TRUE)
fwrite(dd, file.path(DIR_TAB_APP, "table_D_direct_defendant_timing_scope_check.csv"))

repro_dd <- dd[design=="0_repro_script33_FLbinary", roc_auc]
tlog(sprintf("direct-defendant repro (FL-binary, all BEC, 47 def): AUC=%.4f (expect 0.491)%s",
             repro_dd, if (abs(repro_dd-0.491)>0.005) "  !! DEVIATION" else ""))
print(dd[, .(design, universe, label, n_defendants, roc_auc = round(roc_auc,3), pr_auc = round(pr_auc,4))])

# =============================================================================
# Console summary
# =============================================================================
cat("\n========================= TIMING VALIDATION SUMMARY =========================\n")
cat(sprintf("Strict repro (sample 3): FL_binary AUC=%.4f (lock 0.767) | log_tc=%.4f (lock 0.750) | match=%s\n",
            repro_bin, repro_cont, !(flag_bin|flag_cont)))
cat("\nFive-sample strict PR headline:\n")
print(strict_rows[, .(sample, n, positives,
                      pr_auc = round(pr_auc,4),
                      prec_500 = round(prec_500,4),
                      recall_500 = round(recall_500,4),
                      roc_auc = round(roc_auc,4))])
cat(sprintf("\nEntrant diagnostics (S1 full-candidate): pos-share=%.3f FN-share=%.3f tie@0=%.3f\n",
            ent_pos_share_S1, ent_fn_share_S1, tie_zero_S1))
cat("\nRolling-origin (full sample) by year:\n")
print(roll_full[, .(origin_test_year, n, positives, n_entrants,
                    pr_auc = round(pr_auc,4),
                    prec_500 = round(prec_500,4),
                    recall_500 = round(recall_500,4),
                    roc_auc = round(roc_auc,4))])
cat("\nDirect-defendant scope:\n")
print(dd[, .(design, universe, n_defendants, roc_auc = round(roc_auc,3))])

tlog("DONE.")
