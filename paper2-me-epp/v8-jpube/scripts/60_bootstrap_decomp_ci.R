# 60_bootstrap_decomp_ci.R --------------------------------------------
# Bootstrap 95% CIs para os COMPONENTES da decomposicao de preco da
# Tabela 3 (tab_price_decomp_v8): Delta_excl (S2-S1), Delta_pool (S3-S2)
# e Delta_total (S3-S1), por classe (NP/PH), regime baseline "all".
#
# Motivacao (audit 2026-06-07, MAJOR M1): a tabela central do paper
# reporta pontos simulados sem incerteza. O bootstrap canonico
# (v6-jpube/scripts/51_bootstrap_ci.R, B=500, cluster por leilao)
# existe, mas salva apenas delta_total e as shares — descarta
# eff_int/eff_ent por replicate.
#
# Este script RE-EXECUTA o mesmo bootstrap com a MESMA seed stream do
# script 51 (seed_for_iter(51, b)), consumindo o RNG na mesma ordem,
# de modo que cada replicate e bit-identico ao canonico; a unica
# mudanca e salvar m1/m2/m3 por replicate. A identidade e VALIDADA
# contra v6-jpube/data/processed/bootstrap_ci.parquet (assert no fim).
#
# O que o CI cobre: incerteza amostral nas distribuicoes de
# willingness-to-supply (resampling de leiloes com reposicao, por
# estrato pharma x period) + ruido de Monte Carlo (B_MC=500 por
# cenario). O que NAO cobre: incerteza nas taxas de entrada
# (entry_rates fixadas nos pontos observados, como no canonico).
#
# Outputs:
#   v8-jpube/output/bootstrap_decomp_components.parquet
#   v8-jpube/output/values_bootstrap_decomp.tex  (macros p/ values.tex)
#   v8-jpube/output/60_bootstrap_decomp_ci.log
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(duckdb)
  library(DBI)
  library(parallel)
  library(arrow)
})

ROOT    <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
V6_DATA <- file.path(ROOT, "v6-jpube/data/processed")
V8_OUT  <- file.path(ROOT, "v8-jpube/output")

# Seed registry canonico (MASTER_SEED, seed_for_iter).
source(file.path(ROOT, "v6-jpube/scripts/seeds.R"))

logf <- file(file.path(V8_OUT, "60_bootstrap_decomp_ci.log"), open = "wt")
log_step <- function(msg) {
  rss <- tryCatch({
    round(as.numeric(system(paste0("ps -p ", Sys.getpid(), " -o rss="),
                            intern = TRUE)) / 1024^2, 2)
  }, error = function(e) NA_real_)
  line <- sprintf("[%s] 60  RSS=%.2fGb  %s",
                  format(Sys.time(), "%H:%M:%S"), rss, msg)
  message(line); writeLines(line, logf); flush(logf)
}

log_step(sprintf("start: B=500 component bootstrap | host=%s | cores=12 | RAM=%s",
                 Sys.info()[["nodename"]],
                 system("free -h | awk '/Mem:/{print $2}'", intern = TRUE)))

# 1. Carrega bids (mesma query do script 51) --------------------------
con <- dbConnect(duckdb::duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill_v8'")

bids <- dbGetQuery(con, sprintf("
  SELECT numerodaoc, codigoitem, period, pharma_narrow, sme_bec, role,
         c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", file.path(V6_DATA, "bids_uh_cleaned.parquet"))) |> setDT()

entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao' GROUP BY 1,2,3
", file.path(V6_DATA, "entry_rates.parquet"))) |> setDT()

dbDisconnect(con, shutdown = TRUE)

bids[, auction_id := paste(numerodaoc, codigoitem, sep = "_")]
auctions <- unique(bids[, .(auction_id, period, pharma_narrow)])

log_step(sprintf("bids = %s, auctions unicas = %s (esperado 297,967 / 97,993)",
                 format(nrow(bids), big.mark = ","),
                 format(nrow(auctions), big.mark = ",")))
stopifnot(nrow(bids) == 297967L, nrow(auctions) == 97993L)

# 2. Funcoes core — VERBATIM do script 51 (mesma ordem de consumo de
#    RNG; nao alterar) -------------------------------------------------
turnbull_fit <- function(point_obs, upper_bounds, max_iter = 100,
                         tol = 1e-5) {
  if (length(point_obs) < 20) return(NULL)
  nodes <- sort(unique(c(point_obs, upper_bounds)))
  K <- length(nodes)
  F_init <- ecdf(point_obs)(nodes)
  f <- diff(c(0, F_init)) + 1e-8; f <- f / sum(f)
  upper_idx <- findInterval(upper_bounds, nodes, all.inside = TRUE)
  pt_idx <- match(point_obs, nodes)
  E_pt <- tabulate(pt_idx, nbins = K)
  n_total <- length(point_obs) + length(upper_bounds)
  for (it in seq_len(max_iter)) {
    cf <- cumsum(f)
    w_by_u <- tabulate(upper_idx, nbins = K)
    inv_cf <- ifelse(cf > 0, 1 / cf, 0)
    tail_sum <- rev(cumsum(rev(w_by_u * inv_cf)))
    E_win <- f * tail_sum
    f_new <- (E_pt + E_win) / n_total
    f_new <- f_new / sum(f_new)
    if (max(abs(f_new - f)) < tol) { f <- f_new; break }
    f <- f_new
  }
  list(nodes = nodes, f = f, F_c = cumsum(f))
}

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme,
                             B = 500) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s  <- rpois(1, lambda = n_sme)
    n_ns <- rpois(1, lambda = n_nonsme)
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

# Identica ao 51 exceto o RETURN: adiciona m1/m2/m3 e os componentes.
# Nenhuma chamada de RNG extra — a sequencia de draws e preservada.
run_bne <- function(fc_samples, pharma_narrow_val) {
  ph <- pharma_narrow_val
  sme_pre  <- fc_samples[[paste(ph, "Pre",  1, sep = "_")]]
  sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
  ns_pre   <- fc_samples[[paste(ph, "Pre",  0, sep = "_")]]
  if (is.null(sme_pre) || is.null(ns_pre)) return(NULL)
  n_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
  n_post <- entry[period == "Post" & pharma_narrow == ph]
  p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, sme_pre, ns_pre)
  p_S2 <- simulate_auction(n_pre$n_sme, 0, sme_pre, ns_pre)
  p_S3 <- simulate_auction(n_post$n_sme, 0,
                            if (!is.null(sme_post)) sme_post else sme_pre,
                            ns_pre)
  m1 <- mean(p_S1, na.rm = TRUE); m2 <- mean(p_S2, na.rm = TRUE)
  m3 <- mean(p_S3, na.rm = TRUE)
  eff_total <- m3 - m1
  eff_int   <- m2 - m1
  eff_ent   <- m3 - m2
  denom <- abs(eff_int) + abs(eff_ent)
  list(m1 = m1, m2 = m2, m3 = m3,
       delta_total = eff_total,
       delta_excl  = eff_int,
       delta_pool  = eff_ent,
       share_int   = if (denom > 0) abs(eff_int) / denom * 100 else NA,
       share_ent   = if (denom > 0) abs(eff_ent) / denom * 100 else NA)
}

# 3. Uma rodada de bootstrap — VERBATIM do 51, com seed stream do 51 --
one_bootstrap <- function(bs_idx) {
  set.seed(seed_for_iter(51, bs_idx))  # stream do canonico, NAO 60
  bs_bids <- auctions[, .(
    auction_id = sample(auction_id, .N, replace = TRUE)),
    by = .(period, pharma_narrow)]
  bs <- merge(bids, bs_bids, by = c("period", "pharma_narrow",
                                     "auction_id"),
              allow.cartesian = TRUE)

  fc_los <- list(); fc_all <- list(); fc_tb <- list()
  for (ph in c(0, 1)) for (per in c("Pre","Post")) for (sm in c(0, 1)) {
    tag <- paste(ph, per, sm, sep = "_")
    sub <- bs[pharma_narrow == ph & period == per & sme_bec == sm]
    if (nrow(sub) < 50) next
    fc_all[[tag]] <- sub$c
    fc_los[[tag]] <- sub[role == "loser", c]
    c2 <- sub[role == "loser",
              .(c2 = min(c)),
              by = .(numerodaoc, codigoitem)]
    win_c2 <- merge(sub[role == "winner",
                         .(numerodaoc, codigoitem)],
                     c2, by = c("numerodaoc", "codigoitem"))$c2
    fit <- turnbull_fit(sub[role == "loser", c], win_c2)
    if (is.null(fit)) next
    u <- runif(5000)
    fc_tb[[tag]] <- approx(fit$F_c, fit$nodes, xout = u,
                            rule = 2, method = "linear")$y
  }

  out <- list()
  for (ph in c(0, 1)) {
    for (reg in c("losers", "all", "turnbull")) {
      fc_src <- switch(reg,
                       losers   = fc_los,
                       all      = fc_all,
                       turnbull = fc_tb)
      r <- run_bne(fc_src, ph)
      if (is.null(r)) next
      out[[length(out) + 1]] <- data.table(
        bs = bs_idx, regime = reg, pharma_narrow = ph,
        m1 = r$m1, m2 = r$m2, m3 = r$m3,
        delta_total = r$delta_total,
        delta_excl  = r$delta_excl,
        delta_pool  = r$delta_pool,
        share_int   = r$share_int,
        share_ent   = r$share_ent)
    }
  }
  rbindlist(out)
}

# 4. Paralelizacao -----------------------------------------------------
B <- 500
n_cores <- 12

log_step(sprintf("rodando B=%d em %d cores (seed stream do script 51)", B, n_cores))
t0 <- Sys.time()
results <- mclapply(seq_len(B), one_bootstrap,
                    mc.cores = n_cores, mc.preschedule = TRUE)
elapsed <- as.numeric(Sys.time() - t0, units = "secs")
log_step(sprintf("bootstrap done in %.1fs (%.2f s/bs)", elapsed, elapsed / B))

bs_all <- rbindlist(results)

# 5. VALIDACAO: replicates devem ser identicos ao parquet canonico ----
canon <- read_parquet(file.path(V6_DATA, "bootstrap_ci.parquet")) |> setDT()
chk <- merge(bs_all[, .(bs, regime, pharma_narrow, delta_total_new = delta_total,
                        share_int_new = share_int)],
             canon[, .(bs, regime, pharma_narrow, delta_total, share_int)],
             by = c("bs", "regime", "pharma_narrow"))
stopifnot(nrow(chk) == nrow(canon))
max_dev_total <- chk[, max(abs(delta_total_new - delta_total))]
max_dev_share <- chk[, max(abs(share_int_new - share_int), na.rm = TRUE)]
log_step(sprintf("validacao vs canonico: n=%d, max|d_total dev|=%.2e, max|share dev|=%.2e",
                 nrow(chk), max_dev_total, max_dev_share))
if (max_dev_total > 1e-10 || max_dev_share > 1e-8) {
  stop("FALHA: replicates nao reproduzem o bootstrap canonico do script 51.")
}
log_step("validacao OK: replicates bit-identicos ao bootstrap canonico")

arrow::write_parquet(bs_all,
  file.path(V8_OUT, "bootstrap_decomp_components.parquet"),
  compression = "snappy")

# 6. CIs (percentis 2.5/97.5) e macros --------------------------------
ci <- bs_all[, .(
  excl_lo  = quantile(delta_excl, 0.025, na.rm = TRUE),
  excl_hi  = quantile(delta_excl, 0.975, na.rm = TRUE),
  pool_lo  = quantile(delta_pool, 0.025, na.rm = TRUE),
  pool_hi  = quantile(delta_pool, 0.975, na.rm = TRUE),
  total_lo = quantile(delta_total, 0.025, na.rm = TRUE),
  total_hi = quantile(delta_total, 0.975, na.rm = TRUE),
  share_lo = quantile(share_int, 0.025, na.rm = TRUE),
  share_hi = quantile(share_int, 0.975, na.rm = TRUE),
  pool_neg_pct  = mean(delta_pool < 0, na.rm = TRUE) * 100,
  total_pos_pct = mean(delta_total > 0, na.rm = TRUE) * 100,
  share_gt50_pct = mean(share_int > 50, na.rm = TRUE) * 100,
  n_valid = sum(!is.na(delta_total))),
  by = .(regime, pharma_narrow)]

sink(logf, append = TRUE); print(ci); sink()

base <- ci[regime == "all"]
np <- base[pharma_narrow == 0]; ph <- base[pharma_narrow == 1]

macro_lines <- c(
  "%% Bootstrap 95% CIs, componentes da decomposicao (Tabela 3) 2026-06-07",
  "%% (script v8-jpube/scripts/60_bootstrap_decomp_ci.R). Cluster bootstrap",
  "%% por leilao, B=500, estratos pharma x period, regime baseline all-bidders;",
  "%% MESMOS replicates do canonico 51_bootstrap_ci.R (seed stream 51,",
  "%% validado bit-identico contra bootstrap_ci.parquet). Entry rates fixas",
  "%% nos pontos observados; CI cobre incerteza de F_c + ruido MC.",
  sprintf("\\providecommand{\\bneCiExclLoNp}{}\n\\renewcommand{\\bneCiExclLoNp}{%.3f}   %% NP S2-S1 lo", np$excl_lo),
  sprintf("\\providecommand{\\bneCiExclHiNp}{}\n\\renewcommand{\\bneCiExclHiNp}{%.3f}   %% NP S2-S1 hi", np$excl_hi),
  sprintf("\\providecommand{\\bneCiPoolLoNp}{}\n\\renewcommand{\\bneCiPoolLoNp}{%.3f}   %% NP S3-S2 lo", np$pool_lo),
  sprintf("\\providecommand{\\bneCiPoolHiNp}{}\n\\renewcommand{\\bneCiPoolHiNp}{%.3f}   %% NP S3-S2 hi", np$pool_hi),
  sprintf("\\providecommand{\\bneCiTotalLoNp}{}\n\\renewcommand{\\bneCiTotalLoNp}{%.3f}   %% NP S3-S1 lo", np$total_lo),
  sprintf("\\providecommand{\\bneCiTotalHiNp}{}\n\\renewcommand{\\bneCiTotalHiNp}{%.3f}   %% NP S3-S1 hi", np$total_hi),
  sprintf("\\providecommand{\\bneCiShareLoNp}{}\n\\renewcommand{\\bneCiShareLoNp}{%.1f}   %% NP abs excl share lo", np$share_lo),
  sprintf("\\providecommand{\\bneCiShareHiNp}{}\n\\renewcommand{\\bneCiShareHiNp}{%.1f}   %% NP abs excl share hi", np$share_hi),
  sprintf("\\providecommand{\\bneCiExclLoPh}{}\n\\renewcommand{\\bneCiExclLoPh}{%.3f}   %% PH S2-S1 lo", ph$excl_lo),
  sprintf("\\providecommand{\\bneCiExclHiPh}{}\n\\renewcommand{\\bneCiExclHiPh}{%.3f}   %% PH S2-S1 hi", ph$excl_hi),
  sprintf("\\providecommand{\\bneCiPoolLoPh}{}\n\\renewcommand{\\bneCiPoolLoPh}{%.3f}   %% PH S3-S2 lo", ph$pool_lo),
  sprintf("\\providecommand{\\bneCiPoolHiPh}{}\n\\renewcommand{\\bneCiPoolHiPh}{%.3f}   %% PH S3-S2 hi", ph$pool_hi),
  sprintf("\\providecommand{\\bneCiTotalLoPh}{}\n\\renewcommand{\\bneCiTotalLoPh}{%.3f}   %% PH S3-S1 lo", ph$total_lo),
  sprintf("\\providecommand{\\bneCiTotalHiPh}{}\n\\renewcommand{\\bneCiTotalHiPh}{%.3f}   %% PH S3-S1 hi", ph$total_hi),
  sprintf("\\providecommand{\\bneCiShareLoPh}{}\n\\renewcommand{\\bneCiShareLoPh}{%.1f}   %% PH abs excl share lo", ph$share_lo),
  sprintf("\\providecommand{\\bneCiShareHiPh}{}\n\\renewcommand{\\bneCiShareHiPh}{%.1f}   %% PH abs excl share hi", ph$share_hi)
)
writeLines(macro_lines, file.path(V8_OUT, "values_bootstrap_decomp.tex"))

log_step(sprintf(paste0(
  "RESUMO baseline all | NP: excl [%.3f,%.3f] pool [%.3f,%.3f] total [%.3f,%.3f] ",
  "share [%.1f,%.1f] | pool<0: %.1f%%, total>0: %.1f%%, share>50: %.1f%%"),
  np$excl_lo, np$excl_hi, np$pool_lo, np$pool_hi, np$total_lo, np$total_hi,
  np$share_lo, np$share_hi, np$pool_neg_pct, np$total_pos_pct, np$share_gt50_pct))
log_step(sprintf(paste0(
  "RESUMO baseline all | PH: excl [%.3f,%.3f] pool [%.3f,%.3f] total [%.3f,%.3f] ",
  "share [%.1f,%.1f] | pool<0: %.1f%%, total>0: %.1f%%, share>50: %.1f%%"),
  ph$excl_lo, ph$excl_hi, ph$pool_lo, ph$pool_hi, ph$total_lo, ph$total_hi,
  ph$share_lo, ph$share_hi, ph$pool_neg_pct, ph$total_pos_pct, ph$share_gt50_pct))
log_step("done")
close(logf)
