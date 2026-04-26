# ----------------------------------------------------------------------
# Compares the four versions of the decomposition (intensive vs entry share)
# num grid 2×2:
#   raw F_c × fixed-pool   (proxy of the that v2 faz)
#   raw F_c × endogenous   (intermediate)
#   clean F_c × fixed-pool (intermediate)
#   clean F_c × endogenous (version final v3)
#
# Shows quanto each improvement methodological shifts the headline.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/46_decomp_compare.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("46", "start: decomposition grid comparison", logf)

# Reaproveita a estrutura of the script 45 but with F_c raw vs clean. --

load_fc <- function(uh, losers_only = FALSE) {
  field <- if (uh) "c_norm_clean" else "c_norm"
  role_clause <- if (losers_only) "AND role = 'loser'" else ""
  dt <- dbGetQuery(con, sprintf("
    SELECT period, pharma_narrow, sme_bec, %s AS c
    FROM read_parquet('%s')
    WHERE mod = 'pregao' %s
      AND %s > 0 AND %s <= 3
      AND period IN ('Pre','Post')
  ", field, path_v3("data/processed/bids_uh_cleaned.parquet"),
     role_clause, field, field)) |> setDT()
  samples <- list()
  for (ph in c(0, 1)) for (per in c("Pre","Post")) for (sm in c(0, 1)) {
    x <- dt[pharma_narrow == ph & period == per & sme_bec == sm, c]
    if (length(x) >= 50)
      samples[[paste(ph, per, sm, sep = "_")]] <- x
  }
  samples
}

entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
  GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

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

run_scenario <- function(fc_samples, entry_counts, endogenous = TRUE) {
  rows <- list()
  for (ph in c(0, 1)) {
    fc_sme_pre <- fc_samples[[paste(ph, "Pre", 1, sep = "_")]]
    fc_sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
    fc_ns_pre <- fc_samples[[paste(ph, "Pre", 0, sep = "_")]]
    if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next
    n_pre  <- entry_counts[period == "Pre"  & pharma_narrow == ph]
    n_post <- entry_counts[period == "Post" & pharma_narrow == ph]

    set.seed(20260423)
    p_S1 <- simulate_auction(n_pre$n_sme,  n_pre$n_nonsme,
                              fc_sme_pre, fc_ns_pre)
    set.seed(20260423)
    p_S2 <- simulate_auction(n_pre$n_sme,  0,
                              fc_sme_pre, fc_ns_pre)
    # S3: endógena usa N^SME_Post; fixed-pool keep N^SME_Pre.
    n_sme_S3 <- if (endogenous) n_post$n_sme else n_pre$n_sme
    set.seed(20260423)
    p_S3 <- simulate_auction(n_sme_S3, 0,
                              if (!is.null(fc_sme_post)) fc_sme_post
                              else fc_sme_pre,
                              fc_ns_pre)
    rows[[length(rows) + 1]] <- date.table(
      pharma_narrow = ph,
      mean_S1 = mean(p_S1, na.rm = TRUE),
      mean_S2 = mean(p_S2, na.rm = TRUE),
      mean_S3 = mean(p_S3, na.rm = TRUE))
  }
  out <- rbindlist(rows)
  out[, effect_total    := mean_S3 - mean_S1]
  out[, effect_intens   := mean_S2 - mean_S1]
  out[, effect_entry    := mean_S3 - mean_S2]
  out[, share_intens    := round(abs(effect_intens) /
                                    (abs(effect_intens) + abs(effect_entry)) * 100,
                                 2)]
  out[, share_entry     := round(100 - share_intens, 2)]
  out
}

set.seed(20260423)
# Main grid: all-bidders F_c (winner + loser). Corrige MC3.
fc_raw   <- load_fc(FALSE, losers_only = FALSE)
fc_clean <- load_fc(TRUE,  losers_only = FALSE)

log_step("46", "rodando 4 combinations (all-bidders)", logf)

grid <- rbindlist(list(
  cbind(method = "raw + fixed-pool",   run_scenario(fc_raw,   entry, FALSE)),
  cbind(method = "raw + endogenous",   run_scenario(fc_raw,   entry, TRUE)),
  cbind(method = "clean + fixed-pool", run_scenario(fc_clean, entry, FALSE)),
  cbind(method = "clean + endogenous", run_scenario(fc_clean, entry, TRUE))
))
grid[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
grid <- grid[order(pharma_narrow, method)]

cat("\n--- grid 2x2: raw/clean × fixed-pool/endogenous (all-bidders F_c) ---\n",
    file = logf)
sink(logf, append = TRUE)
print(grid[, .(pharma_lbl, method,
               mean_S1 = round(mean_S1, 4),
               mean_S2 = round(mean_S2, 4),
               mean_S3 = round(mean_S3, 4),
               effect_total = round(effect_total, 4),
               share_intens, share_entry)])
sink()

# Sensitivity: losers-only vs all-bidders in the version final
# (clean + endogenous). Reporta only in the log — documenta a magnitude
# of the bias MC3 for o memo.
set.seed(20260423)
fc_clean_losers <- load_fc(TRUE, losers_only = TRUE)
sens <- cbind(method = "clean + endogenous [LOSERS-ONLY]",
              run_scenario(fc_clean_losers, entry, TRUE))
sens[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

cat("\n--- sensitivity MC3: clean+endog, losers-only vs all-bidders ---\n",
    file = logf)
sink(logf, append = TRUE)
sens_cmp <- rbind(
  grid[method == "clean + endogenous",
       .(sample = "all", pharma_lbl, mean_S1 = round(mean_S1, 4),
         mean_S3 = round(mean_S3, 4), effect_total = round(effect_total, 4),
         share_intens, share_entry)],
  sens[, .(sample = "losers", pharma_lbl, mean_S1 = round(mean_S1, 4),
           mean_S3 = round(mean_S3, 4), effect_total = round(effect_total, 4),
           share_intens, share_entry)])
print(sens_cmp[order(pharma_lbl, sample)])
sink()

arrow::write_parquet(grid,
  path_v3("data/processed/decomp_grid.parquet"),
  compression = "snappy")

# LaTeX --------------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Decomposition grid: raw vs UH-clean $F_c$, fixed-pool vs endogenous entry}",
  "\\label{tab:v3_decomp_grid}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  "Class & Method & $\\bar p_{S_1}$ & $\\bar p_{S_2}$ & $\\bar p_{S_3}$ & $\\Delta$ total & \\% intensive & \\% entry \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(grid))) {
  r <- grid[i]
  tex <- c(tex, sprintf(
    "%s & %s & %.3f & %.3f & %.3f & %+.4f & %.1f & %.1f \\\\",
    r$pharma_lbl, r$method,
    r$mean_S1, r$mean_S2, r$mean_S3, r$effect_total,
    r$share_intens, r$share_entry))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Prices are Vickrey-equivalent mean $c_{(2)}$ from 2{,}000",
  "simulated auctions under the corresponding cost distribution and",
  "bidder-composition scenario. Cost draws sample all Preg\\~ao",
  "bidders (winners plus losers) to attenuate the upward bias of a",
  "losers-only ECDF. Row ``raw + fixed-pool'' is the proxy for v2's",
  "headline specification; ``clean + endogenous'' is the v3 final.",
  "Movement across rows shows sensitivity of the intensive/entry",
  "split to the methodological improvements introduced in S3--S4.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_decomp_grid.tex"))

log_step("46", "done", logf)
