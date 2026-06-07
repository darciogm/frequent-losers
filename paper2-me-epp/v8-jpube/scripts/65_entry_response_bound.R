# 65_entry_response_bound.R -------------------------------------------
# Lever C: is the welfare ranking (price preference V3 beats full
# set-aside V0 in standardized non-pharmaceutical procurement) robust to
# ENDOGENOUS entry under the preference regime?
#
# The welfare comparison in the paper holds entry at observed rates. V3
# (a k% SME price preference, all firms eligible) is simulated with
# pre-policy entry for both types. A real preference would change entry:
# non-SMEs face a handicap and may enter less, which is the worst case
# for V3 (fewer non-SMEs -> weaker price discipline -> higher V3 cost).
#
# A fully endogenous free-entry counterfactual would require the entry
# cost, which the legal shock does not identify (the paper says so). So I
# BOUND instead of point-identify: parameterize non-SME retention under V3
# by phi in [0,1], with lambda_ns^V3 = phi * lambda_ns^pre (phi=1 is the
# paper's no-response assumption), hold SME entry conservatively at the
# pre-policy rate (a real preference would raise it, helping V3), and find
# the breakdown phi* at which V3's welfare loss rises to equal V0's, i.e.,
# where the ranking flips. (1 - phi*) is the share of non-SME entrants the
# preference would have to drive out before the set-aside wins.
#
# Also reports V3 under post-policy SME entry (best case) to show the
# ranking only strengthens when SME entry responds.
#
# NO manuscript edits here. Result first.
#
# Outputs:
#   v8-jpube/output/entry_response_grid.csv
#   v8-jpube/output/values_entry_bound.tex
#   v8-jpube/output/65_entry_response_bound.log
# ----------------------------------------------------------------------

suppressPackageStartupMessages({ library(data.table); library(duckdb); library(DBI) })

ROOT    <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
V6_DATA <- file.path(ROOT, "v6-jpube/data/processed")
V8_OUT  <- file.path(ROOT, "v8-jpube/output")

logf <- file(file.path(V8_OUT, "65_entry_response_bound.log"), open = "wt")
logln <- function(...) { l <- sprintf(...); message(l); writeLines(l, logf); flush(logf) }

set.seed(20260607L)
B    <- 8000L      # MC draws; high so the phi-grid is smooth
LAM  <- 0.30       # MCPF (lambdaMain)
KPREF<- 0.10       # headline preference rate (prefMainPct)

logln("[65] host=%s | entry-response bound on welfare ranking | B=%d lambda=%.2f k=%.2f",
      Sys.info()[["nodename"]], B, LAM, KPREF)

# 1. Primitives -------------------------------------------------------
con <- dbConnect(duckdb::duckdb()); dbExecute(con, "PRAGMA threads=12")
bids <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod='pregao' AND c_norm_clean>0 AND c_norm_clean<=3
    AND period IN ('Pre','Post')", file.path(V6_DATA, "bids_uh_cleaned.parquet"))) |> setDT()
entry <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s') WHERE mod='pregao' GROUP BY 1,2",
  file.path(V6_DATA, "entry_rates.parquet"))) |> setDT()
dbDisconnect(con, shutdown = TRUE)

fc <- list()
for (ph in c(0,1)) for (per in c("Pre","Post")) for (sm in c(0,1)) {
  x <- bids[pharma_narrow==ph & period==per & sme_bec==sm, c]
  if (length(x) >= 50) fc[[paste(ph,per,sm,sep="_")]] <- x
}

# 2. Preference auction (verbatim from script 61_optimal_preference) --
simulate_pref <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, k) {
  sme_disc <- 1 - k
  n_s  <- rpois(1, n_sme); n_ns <- rpois(1, n_nonsme)
  if (n_s + n_ns < 2) return(list(price=NA, sme_won=NA, c1=NA))
  c_s <- if (n_s  > 0) sample(fc_sme,    n_s,  replace=TRUE) else numeric()
  c_n <- if (n_ns > 0) sample(fc_nonsme, n_ns, replace=TRUE) else numeric()
  c_s_eff  <- c_s * sme_disc
  all_eff  <- c(c_s_eff, c_n); all_real <- c(c_s, c_n)
  ord <- order(all_eff)
  is_sme_winner <- ord[1] <= n_s
  c2_eff <- all_eff[ord[2]]
  price <- if (is_sme_winner) c2_eff / sme_disc else c2_eff
  list(price=price, sme_won=is_sme_winner, c1=all_real[ord[1]])
}

mean_run <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, k) {
  p <- numeric(B); c1 <- numeric(B); w <- logical(B)
  for (b in seq_len(B)) {
    r <- simulate_pref(n_sme, n_nonsme, fc_sme, fc_nonsme, k)
    p[b] <- r$price; c1[b] <- r$c1; w[b] <- r$sme_won
  }
  list(price=mean(p,na.rm=TRUE), c1=mean(c1,na.rm=TRUE), won=mean(w,na.rm=TRUE))
}

# Welfare loss (% of p_S1) for a policy given its (entry, k) config.
welfare <- function(ph) {
  s_pre  <- fc[[paste(ph,"Pre",1,sep="_")]]; n_pre <- fc[[paste(ph,"Pre",0,sep="_")]]
  s_post <- fc[[paste(ph,"Post",1,sep="_")]]
  en_pre  <- entry[period=="Pre"  & pharma_narrow==ph]
  en_post <- entry[period=="Post" & pharma_narrow==ph]

  S1 <- mean_run(en_pre$n_sme, en_pre$n_nonsme, s_pre, n_pre, 0)   # open benchmark
  V0 <- mean_run(en_post$n_sme, 0, s_post, n_pre, 0)               # full set-aside
  loss_V0 <- (V0$c1 - S1$c1 + LAM*(V0$price - S1$price)) / S1$price * 100

  # V3 welfare loss as a function of non-SME retention phi (SME at pre rate).
  v3_loss <- function(phi, sme_rate) {
    V3 <- mean_run(sme_rate, phi*en_pre$n_nonsme, s_pre, n_pre, KPREF)
    (V3$c1 - S1$c1 + LAM*(V3$price - S1$price)) / S1$price * 100
  }
  list(p_S1=S1$price, loss_V0=loss_V0, v3_loss=v3_loss,
       sme_pre=en_pre$n_sme, sme_post=en_post$n_sme, ns_pre=en_pre$n_nonsme)
}

# 3. Sweep phi; find breakdown phi* where loss_V3 == loss_V0 ----------
phi_grid <- seq(1.00, 0.00, by = -0.05)
run_class <- function(ph, lbl) {
  w <- welfare(ph)
  logln("[65] %s: p_S1=%.3f | loss_V0=%.1f%% | SME entry pre=%.2f post=%.2f | nonSME pre=%.2f",
        lbl, w$p_S1, w$loss_V0, w$sme_pre, w$sme_post, w$ns_pre)
  rows <- lapply(phi_grid, function(phi) {
    l_pre  <- w$v3_loss(phi, w$sme_pre)    # conservative: SME at pre rate
    l_post <- w$v3_loss(phi, w$sme_post)   # best case: SME entry responds
    data.table(class=lbl, phi=phi, ns_rate=round(phi*w$ns_pre,2),
               lossV3_smePre=round(l_pre,2), lossV3_smePost=round(l_post,2),
               lossV0=round(w$loss_V0,2),
               v3_wins_smePre = l_pre < w$loss_V0)
  })
  dt <- rbindlist(rows)
  # Breakdown: smallest (1-phi) discouragement at which V3 no longer beats V0
  # (worst case = SME held at pre rate).
  flip <- dt[v3_wins_smePre == FALSE]
  phi_star <- if (nrow(flip)) max(flip$phi) else NA_real_  # highest phi that already flipped
  for (i in seq_len(nrow(dt))) {
    r <- dt[i]
    logln("[65]   %s phi=%.2f (nonSME rate %.2f) | lossV3(SMEpre)=%.1f lossV3(SMEpost)=%.1f vs lossV0=%.1f | V3 wins: %s",
          lbl, r$phi, r$ns_rate, r$lossV3_smePre, r$lossV3_smePost, r$lossV0,
          if (r$v3_wins_smePre) "YES" else "NO")
  }
  list(dt=dt, phi_star=phi_star, loss_V0=w$loss_V0)
}

logln("[65] === non-pharma ===")
np <- run_class(0, "non-pharma")
logln("[65] === pharma ===")
ph <- run_class(1, "pharma")

allres <- rbind(np$dt, ph$dt)
fwrite(allres, file.path(V8_OUT, "entry_response_grid.csv"))

# 4. Macros -----------------------------------------------------------
# Discouragement needed to flip = 1 - phi_star (worst phi that flips).
fmtdisc <- function(phi_star) if (is.na(phi_star)) ">100" else sprintf("%.0f", (1-phi_star)*100)
np_disc <- fmtdisc(np$phi_star); ph_disc <- fmtdisc(ph$phi_star)
writeLines(c(
  "%% Entry-response bound on the welfare ranking (Lever C) — script",
  "%% 65_entry_response_bound.R 2026-06-07. phi = non-SME retention under V3",
  "%% (lambda_ns^V3 = phi * pre-policy rate); SME held at pre-policy rate",
  "%% (conservative). Breakdown = non-SME discouragement (1-phi*) at which the",
  "%% V3-preference welfare loss rises to the full set-aside V0 loss.",
  sprintf("\\providecommand{\\entryFlipDiscNp}{}\\renewcommand{\\entryFlipDiscNp}{%s}", np_disc),
  sprintf("\\providecommand{\\entryFlipDiscPh}{}\\renewcommand{\\entryFlipDiscPh}{%s}", ph_disc)
), file.path(V8_OUT, "values_entry_bound.tex"))

logln("[65] ============================================================")
logln("[65] FLIP: non-pharma needs %s%% non-SME discouragement to flip V3>V0; pharma %s%%",
      np_disc, ph_disc)
logln("[65] (SME entry held at pre-policy; letting it respond only widens V3's margin.)")
logln("[65] done")
close(logf)
