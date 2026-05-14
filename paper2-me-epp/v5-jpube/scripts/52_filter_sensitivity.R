# ----------------------------------------------------------------------
# Filter sensitivity of the BNE decomposition (regime all-bidders, v3 final).
# Four cut configurations:
#   baseline   : c_norm_clean ∈ (0, 3],  n_firms ≥ 2   (v3 final)
#   tight      : c_norm_clean ∈ (0, 2],  n_firms ≥ 3
#   very_tight : c_norm_clean ∈ (0, 1.5], n_firms ≥ 3
#   looif      : c_norm_clean ∈ (0, 5],  n_firms ≥ 2
#
# Temporal window (18m) is not varied here — would require re-generating
# bids_uh_cleaned with date_oc_numb preservado; fica como open risk.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/52_filter_sensitivity.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("52", "start: filter sensitivity", logf)

entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao' GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

load_bids <- function(c_upper, n_min) {
  dbGetQuery(con, sprintf("
    SELECT period, pharma_narrow, sme_bec, n_firms_auc, role,
           c_norm_clean AS c
    FROM read_parquet('%s')
    WHERE mod = 'pregao'
      AND c_norm_clean > 0 AND c_norm_clean <= %f
      AND n_firms_auc >= %d
      AND period IN ('Pre','Post')
  ", path_v3("data/processed/bids_uh_cleaned.parquet"),
     c_upper, n_min)) |> setDT()
}

make_samples <- function(dt) {
  out <- list()
  for (ph in c(0, 1)) for (per in c("Pre", "Post")) for (sm in c(0, 1)) {
    x <- dt[pharma_narrow == ph & period == per & sme_bec == sm, c]
    if (length(x) >= 50)
      out[[paste(ph, per, sm, sep = "_")]] <- x
  }
  out
}

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, B = 2000) {
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

run_bne <- function(fc_samples) {
  rows <- list()
  for (ph in c(0, 1)) {
    sme_pre  <- fc_samples[[paste(ph, "Pre",  1, sep = "_")]]
    sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
    ns_pre   <- fc_samples[[paste(ph, "Pre",  0, sep = "_")]]
    if (is.null(sme_pre) || is.null(ns_pre)) next
    n_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
    n_post <- entry[period == "Post" & pharma_narrow == ph]
    set.seed(20260423)
    p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, sme_pre, ns_pre)
    set.seed(20260423)
    p_S2 <- simulate_auction(n_pre$n_sme, 0, sme_pre, ns_pre)
    set.seed(20260423)
    p_S3 <- simulate_auction(n_post$n_sme, 0,
                              if (!is.null(sme_post)) sme_post else sme_pre,
                              ns_pre)
    m1 <- mean(p_S1, na.rm = TRUE)
    m2 <- mean(p_S2, na.rm = TRUE)
    m3 <- mean(p_S3, na.rm = TRUE)
    rows[[length(rows) + 1]] <- data.table(
      pharma_narrow = ph,
      mean_S1 = m1, mean_S2 = m2, mean_S3 = m3,
      delta_total = m3 - m1,
      share_int = abs(m2 - m1) / (abs(m2 - m1) + abs(m3 - m2)) * 100)
  }
  out <- rbindlist(rows)
  out[, share_ent := 100 - share_int]
  out
}

filters <- list(
  baseline    = list(c_up = 3.0, n_min = 2),
  tight       = list(c_up = 2.0, n_min = 3),
  `very-tight` = list(c_up = 1.5, n_min = 3),
  looif       = list(c_up = 5.0, n_min = 2))

set.seed(20260423)
all_res <- list()
for (name in names(filters)) {
  f <- filters[[name]]
  bids <- load_bids(f$c_up, f$n_min)
  samples <- make_samples(bids)
  r <- run_bne(samples)
  r[, filter := name]
  r[, n_bids := nrow(bids)]
  all_res[[name]] <- r
}
res <- rbindlist(all_res)
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res <- res[order(pharma_narrow, factor(filter,
                 levels = c("baseline", "tight", "very-tight", "loose")))]

cat("\n--- filter sensitivity (4 configs × 2 pharma) ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, filter, n_bids,
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
  "\\caption{Filter sensitivity: BNE decomposition under alternative sample cuts}",
  "\\label{tab:v3_filter_sensitivity}",
  "\\small",
  "\\begin{tabular}{llrrrrr}",
  "\\toprule",
  "Class & Filter & $n$ bids & $\\bar p_{S_1}$ & $\\bar p_{S_3}$ & $\\Delta$ total & \\% int. \\\\",
  "\\midrule")
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %.3f & %.3f & %+.4f & %.1f \\\\",
    r$pharma_lbl, r$filter, formt(r$n_bids, big.mark = ","),
    r$mean_S1, r$mean_S3, r$delta_total, r$share_int))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Four filter configuretions applied to Preg\\~ao UH-clean",
  "bids: baseline uses $c_\\epsilon \\le 3$ and $n \\ge 2$ (v3 final);",
  "tight cuts $c_\\epsilon \\le 2$ with $n \\ge 3$; very-tight",
  "$c_\\epsilon \\le 1.5$ with $n \\ge 3$; looif $c_\\epsilon \\le 5$.",
  "Entry counts held fixed across filters. All-bidders regime, BNE",
  "with 2{,}000 MC draws per scenario.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_filter_sensitivity.tex"))

log_step("52", "done", logf)
