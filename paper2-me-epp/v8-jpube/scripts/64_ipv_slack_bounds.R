# 64_ipv_slack_bounds.R -----------------------------------------------
# Lever A: is the exclusion-dominant decomposition robust to departures
# from the exact exit-at-cost (IPV-clock POINT) interpretation?
#
# Motivation. The structural layer interprets a losing bidder's Pregao
# drop-out price as its cost (exit-at-cost). Haile-Tamer (2003) show that
# in ascending/clock auctions one need not assume exact exit-at-cost:
# observed exits BOUND the underlying value/cost distribution. Two pieces:
#
#   (a) The MECHANICAL Haile-Tamer increment bound. Its width is the bid
#       increment Delta. BEC's electronic Pregao has a near-continuous
#       clock, so Delta is tiny and the increment bound is tight (computed
#       in 64b separately / reported as the typical decrement). This
#       script handles the BEHAVIORAL margin, which the increment bound
#       does NOT cover.
#
#   (b) The BEHAVIORAL margin: bidders may exit strategically ABOVE cost
#       (leave money on the table). A markup COMMON to all bidders cancels
#       in the decomposition differences (S2-S1, S3-S2). The real threat is
#       a TYPE-DIFFERENTIAL markup: SMEs and non-SMEs shading by different
#       amounts. Individual rationality bounds true cost <= exit, so the
#       admissible transform is c_true = exit * (1 - m_k), m_k in [0, 1).
#       The IPV point case is m_SME = m_nonSME = 0.
#
# Worst case for exclusion-dominance: SMEs much cheaper than they look
# (m_SME large) and non-SMEs at face value (m_nonSME = 0), which shrinks
# the SME-vs-non-SME cost gap that drives the exclusion channel.
#
# This script sweeps (m_SME, m_nonSME), recomputes the S1/S2/S3
# decomposition at each grid point (entry held at observed rates; only the
# cost primitives are transformed), and finds the BREAKDOWN markup at which
# exclusion-dominance fails (abs. exclusion share <= 50% OR net <= 0).
#
# NO manuscript edits here. Result first; writing only if it survives.
#
# Outputs:
#   v8-jpube/output/ipv_slack_grid.csv
#   v8-jpube/output/values_ipv_slack.tex
#   v8-jpube/output/64_ipv_slack_bounds.log
# ----------------------------------------------------------------------

suppressPackageStartupMessages({ library(data.table); library(duckdb); library(DBI) })

ROOT    <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
V6_DATA <- file.path(ROOT, "v6-jpube/data/processed")
V8_OUT  <- file.path(ROOT, "v8-jpube/output")

logf <- file(file.path(V8_OUT, "64_ipv_slack_bounds.log"), open = "wt")
logln <- function(...) { l <- sprintf(...); message(l); writeLines(l, logf); flush(logf) }

set.seed(20260607L)  # fixed: grid comparisons must be smooth across markup
B_MC <- 6000L        # high MC draws so grid differences are not MC noise

logln("[64] host=%s | IPV behavioral-slack sensitivity | B_MC=%d",
      Sys.info()[["nodename"]], B_MC)

# 1. Cost vectors per cell (full sample, all-bidders regime = canonical) ----
con <- dbConnect(duckdb::duckdb()); dbExecute(con, "PRAGMA threads=12")
bids <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, period, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod='pregao' AND c_norm_clean>0 AND c_norm_clean<=3
    AND period IN ('Pre','Post')", file.path(V6_DATA, "bids_uh_cleaned.parquet"))) |> setDT()
entry <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s') WHERE mod='pregao' GROUP BY 1,2",
  file.path(V6_DATA, "entry_rates.parquet"))) |> setDT()
dbDisconnect(con, shutdown = TRUE)

cell <- function(ph, per, sm) bids[pharma_narrow == ph & period == per & sme_bec == sm, c]

# 2. Simulation core (verbatim logic from scripts 45/60) --------------
simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, B = B_MC) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s  <- rpois(1, n_sme); n_ns <- rpois(1, n_nonsme)
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(if (n_s  > 0) sample(fc_sme,    n_s,  replace = TRUE) else numeric(),
               if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

# Decomposition at a given type-differential markup (m_sme, m_ns).
# c_true = exit * (1 - m). m=0 reproduces the point IPV baseline.
run_decomp <- function(m_sme, m_ns, ph) {
  sme_pre  <- cell(ph, "Pre",  1) * (1 - m_sme)
  sme_post <- cell(ph, "Post", 1) * (1 - m_sme)
  ns_pre   <- cell(ph, "Pre",  0) * (1 - m_ns)
  np_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
  np_post <- entry[period == "Post" & pharma_narrow == ph]
  S1 <- mean(simulate_auction(np_pre$n_sme,  np_pre$n_nonsme, sme_pre,  ns_pre), na.rm = TRUE)
  S2 <- mean(simulate_auction(np_pre$n_sme,  0,               sme_pre,  ns_pre), na.rm = TRUE)
  S3 <- mean(simulate_auction(np_post$n_sme, 0,               sme_post, ns_pre), na.rm = TRUE)
  intens <- S2 - S1; entry_eff <- S3 - S2; total <- S3 - S1
  denom <- abs(intens) + abs(entry_eff)
  list(S1 = S1, S2 = S2, S3 = S3, intens = intens, entry = entry_eff,
       total = total, share = if (denom > 0) abs(intens) / denom * 100 else NA)
}

# 3. Validate m=0 reproduces the canonical point estimates ------------
b0np <- run_decomp(0, 0, 0); b0ph <- run_decomp(0, 0, 1)
logln("[64] VALIDATE m=0 NP: intens=%.3f entry=%.3f total=%.3f share=%.1f (canonical 0.371/-0.144/0.227/72.0)",
      b0np$intens, b0np$entry, b0np$total, b0np$share)
logln("[64] VALIDATE m=0 PH: intens=%.3f entry=%.3f total=%.3f share=%.1f (canonical 0.565/-0.256/0.309/68.8)",
      b0ph$intens, b0ph$entry, b0ph$total, b0ph$share)
if (abs(b0np$share - 72.0) > 3 || abs(b0np$total - 0.227) > 0.03)
  logln("[64] WARN: m=0 NP deviates from canonical beyond MC tolerance; inspect before trusting grid.")

# 4. Worst-case line: m_ns = 0, sweep m_sme; find breakdown -----------
surv <- function(r) (r$total > 0) && (r$share > 50)
m_grid <- seq(0, 0.30, by = 0.01)
breakdown <- function(ph) {
  last_ok <- NA_real_
  for (m in m_grid) {
    r <- run_decomp(m, 0, ph)
    ok <- surv(r)
    logln("[64]   ph=%d m_sme=%.2f m_ns=0 | intens=%.3f entry=%.3f total=%.3f share=%.1f | %s",
          ph, m, r$intens, r$entry, r$total, r$share, if (ok) "OK" else "BREAK")
    if (!ok) return(list(break_m = m, last_ok = last_ok))
    last_ok <- m
  }
  list(break_m = NA_real_, last_ok = max(m_grid))  # survives whole grid
}
logln("[64] --- worst-case line (m_ns=0), non-pharma ---")
bn <- breakdown(0)
logln("[64] --- worst-case line (m_ns=0), pharma ---")
bp <- breakdown(1)

# 5. Coarse 2D grid (for a future appendix heatmap) -------------------
grid2d <- CJ(m_sme = seq(0, 0.30, 0.05), m_ns = seq(0, 0.30, 0.05))
res <- rbindlist(lapply(seq_len(nrow(grid2d)), function(i) {
  ms <- grid2d$m_sme[i]; mn <- grid2d$m_ns[i]
  rn <- run_decomp(ms, mn, 0); rp <- run_decomp(ms, mn, 1)
  data.table(m_sme = ms, m_ns = mn,
             share_np = rn$share, total_np = rn$total, surv_np = surv(rn),
             share_ph = rp$share, total_ph = rp$total, surv_ph = surv(rp))
}))
fwrite(res, file.path(V8_OUT, "ipv_slack_grid.csv"))

# 6. Macros + summary -------------------------------------------------
bdNp <- if (is.na(bn$break_m)) ">0.30" else sprintf("%.2f", bn$break_m)
bdPh <- if (is.na(bp$break_m)) ">0.30" else sprintf("%.2f", bp$break_m)
lastNp <- sprintf("%.2f", bn$last_ok); lastPh <- sprintf("%.2f", bp$last_ok)
writeLines(c(
  "%% IPV behavioral-slack sensitivity (Lever A) — script 64_ipv_slack_bounds.R 2026-06-07.",
  "%% Type-differential proportional markup c_true=exit*(1-m_k); worst case m_ns=0.",
  "%% Breakdown m_sme = smallest SME-vs-nonSME markup gap at which exclusion-dominance",
  "%% (net>0 AND abs. exclusion share>50%) fails. Entry held at observed rates.",
  sprintf("\\providecommand{\\ipvSlackBreakNp}{}\\renewcommand{\\ipvSlackBreakNp}{%s}", bdNp),
  sprintf("\\providecommand{\\ipvSlackBreakPh}{}\\renewcommand{\\ipvSlackBreakPh}{%s}", bdPh),
  sprintf("\\providecommand{\\ipvSlackLastOkNp}{}\\renewcommand{\\ipvSlackLastOkNp}{%s}", lastNp),
  sprintf("\\providecommand{\\ipvSlackLastOkPh}{}\\renewcommand{\\ipvSlackLastOkPh}{%s}", lastPh)
), file.path(V8_OUT, "values_ipv_slack.tex"))

logln("[64] ============================================================")
logln("[64] BREAKDOWN markup (m_ns=0): NP m_sme*=%s (survives through %s); PH m_sme*=%s (survives through %s)",
      bdNp, lastNp, bdPh, lastPh)
logln("[64] Interpretation: exclusion-dominance survives unless SMEs exit with a proportional")
logln("[64] markup more than this many points above non-SMEs at every auction.")
logln("[64] done")
close(logf)
