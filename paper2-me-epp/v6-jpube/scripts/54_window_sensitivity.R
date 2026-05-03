# S5 / task 54 -------------------------------------------------------
# Window sensitivity da BNE decomposition: 18m (baseline v3) vs 12m
# vs 6m. Janelas em Stata-monthly date units centradas em cutoff 698
# (March 2018):
#   win_18m = [680, 715]  (v3 baseline)
#   win_12m = [686, 709]
#   win_06m = [692, 703]
#
# Join bids_uh_cleaned com g65_keys para trazer data_oc_numb.
# Entry counts recomputed por janela (contagem média de bidders
# por auction dentro da janela). Regime all-bidders (v3 final).

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v3("logs/54_window_sensitivity.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("54", "start: window sensitivity", logf)

# Bids com data_oc_numb via join em g65_keys. ------------------------
bids <- dbGetQuery(con, sprintf("
  SELECT b.numerodaoc, b.codigoitem, b.cod_forn, b.period, b.pharma_narrow,
         b.sme_bec, b.role, b.c_norm_clean AS c,
         k.data_oc_numb
  FROM read_parquet('%s') b
  LEFT JOIN read_parquet('%s') k
    ON b.numerodaoc = k.numerodaoc AND b.codigoitem = k.codigoitem
  WHERE b.mod = 'pregao'
    AND b.c_norm_clean > 0 AND b.c_norm_clean <= 3
    AND b.period IN ('Pre','Post')
    AND k.data_oc_numb IS NOT NULL
", path_v3("data/processed/bids_uh_cleaned.parquet"),
   path_v3("data/processed/g65_keys.parquet"))) |> setDT()

log_step("54", sprintf("bids after join = %s (de 297.967 original)",
                       format(nrow(bids), big.mark = ",")), logf)

windows <- list(
  "18m" = win_18m,
  "12m" = win_12m,
  "6m"  = win_06m)

make_samples <- function(dt) {
  out <- list()
  for (ph in c(0, 1)) for (per in c("Pre", "Post")) for (sm in c(0, 1)) {
    x <- dt[pharma_narrow == ph & period == per & sme_bec == sm, c]
    if (length(x) >= 50)
      out[[paste(ph, per, sm, sep = "_")]] <- x
  }
  out
}

compute_entry <- function(dt) {
  # Firmas distintas (cod_forn) por auction, depois soma por tipo,
  # depois média por estrato. Sem cod_forn no unique, todos os SMEs
  # de um auction colapsam em 1 row — bug que eu já paguei 1×.
  dt_firm <- unique(dt[, .(numerodaoc, codigoitem, cod_forn, period,
                            pharma_narrow, sme_bec)])
  per_auction <- dt_firm[, .(
    n_sme    = sum(sme_bec == 1),
    n_nonsme = sum(sme_bec == 0)),
    by = .(numerodaoc, codigoitem, period, pharma_narrow)]
  per_auction[, .(n_sme = mean(n_sme), n_nonsme = mean(n_nonsme)),
              by = .(period, pharma_narrow)]
}

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme,
                             B = 2000) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s <- rpois(1, lambda = n_sme)
    n_ns <- rpois(1, lambda = n_nonsme)
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

run_bne_win <- function(fc_samples, entry_dt) {
  rows <- list()
  for (ph in c(0, 1)) {
    sme_pre  <- fc_samples[[paste(ph, "Pre",  1, sep = "_")]]
    sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
    ns_pre   <- fc_samples[[paste(ph, "Pre",  0, sep = "_")]]
    if (is.null(sme_pre) || is.null(ns_pre)) next
    n_pre  <- entry_dt[period == "Pre"  & pharma_narrow == ph]
    n_post <- entry_dt[period == "Post" & pharma_narrow == ph]
    if (nrow(n_pre) == 0 || nrow(n_post) == 0) next
    p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, sme_pre, ns_pre)
    p_S2 <- simulate_auction(n_pre$n_sme, 0, sme_pre, ns_pre)
    p_S3 <- simulate_auction(n_post$n_sme, 0,
                              if (!is.null(sme_post)) sme_post else sme_pre,
                              ns_pre)
    m1 <- mean(p_S1, na.rm = TRUE)
    m2 <- mean(p_S2, na.rm = TRUE)
    m3 <- mean(p_S3, na.rm = TRUE)
    rows[[length(rows) + 1]] <- data.table(
      pharma_narrow = ph,
      n_sme_pre = round(n_pre$n_sme, 2),
      n_ns_pre  = round(n_pre$n_nonsme, 2),
      n_sme_post = round(n_post$n_sme, 2),
      mean_S1 = m1, mean_S3 = m3,
      delta_total = m3 - m1,
      share_int = abs(m2 - m1) / (abs(m2 - m1) + abs(m3 - m2)) * 100)
  }
  out <- rbindlist(rows)
  out[, share_ent := 100 - share_int]
  out
}

set.seed(seed_for_script(54))
all_res <- list()
for (name in names(windows)) {
  w <- windows[[name]]
  sub <- bids[data_oc_numb >= w[1] & data_oc_numb <= w[2]]
  ent <- compute_entry(sub)
  samp <- make_samples(sub)
  r <- run_bne_win(samp, ent)
  r[, window := name]
  r[, n_bids := nrow(sub)]
  r[, n_auctions := uniqueN(sub[, .(numerodaoc, codigoitem)])]
  all_res[[name]] <- r
}
res <- rbindlist(all_res)
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res <- res[order(pharma_narrow, factor(window, levels = c("18m", "12m", "6m")))]

cat("\n--- window sensitivity: 3 janelas × 2 pharma ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, window, n_bids, n_auctions,
              n_sme_pre, n_ns_pre, n_sme_post,
              mean_S1 = round(mean_S1, 4),
              mean_S3 = round(mean_S3, 4),
              delta_total = round(delta_total, 4),
              share_int = round(share_int, 2),
              share_ent = round(share_ent, 2))])
sink()

# LaTeX --------------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Temporal window sensitivity: BNE decomposition, 18m / 12m / 6m}",
  "\\label{tab:v3_window_sensitivity}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  "Class & Window & $n$ auctions & $N^{\\text{SME}}_{\\text{Pre}}$ & $N^{\\text{SME}}_{\\text{Post}}$ & $\\Delta$ total & \\% int. & \\% entry \\\\",
  "\\midrule")
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %.2f & %.2f & %+.4f & %.1f & %.1f \\\\",
    r$pharma_lbl, r$window, format(r$n_auctions, big.mark = ","),
    r$n_sme_pre, r$n_sme_post,
    r$delta_total, r$share_int, r$share_ent))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Windows are in Stata monthly-date units centered at cutoff",
  "698 (March 2018): 18m = [680,715], 12m = [686,709], 6m = [692,703].",
  "Entry counts $N^k_\\tau$ are recomputed within each window. Cost",
  "distributions $F_c$ are re-estimated (all-bidders regime). Narrower",
  "windows reduce power; the 6m window may hide steady-state behavior",
  "masked by short-run noise. Baseline v3 is 18m.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_window_sensitivity.tex"))

log_step("54", "done", logf)
