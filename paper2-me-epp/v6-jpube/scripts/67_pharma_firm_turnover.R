# 67_pharma_firm_turnover.R
#
# M6: empirical discriminating test between the "selection" and "no real
# change in F_c^SME" readings of the pharma bifurcation. Computes pharma
# SME firm turnover Pre vs Post the March-2018 cutoff and compares to
# non-pharma SMEs (which serve as a within-paper control).
#
# Logic: if the empirical pre-vs-post difference in $\hat F_c^{\text{SME,Post}}$
# reflects equilibrium selection (firms previously unprofitable under the
# open regime now profitable under exclusion), post-period SME bids should
# come predominantly from firms ABSENT in pre. If most post-period bids are
# from CONTINUING firms (same SMEs bidding more), the strict-invariance
# reading is closer to truth and the main specification overstates the
# attribution to selection.
#
# Outputs:
#   data/processed/pharma_firm_turnover.parquet
#   output/tables/tab_pharma_firm_turnover.tex
#   logs/67_pharma_firm_turnover.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v6("logs/67_pharma_firm_turnover.log"), open = "wt")
on.exit(close(logf), add = TRUE)
con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("67", "start: pharma SME firm turnover Pre vs Post", logf)

# 1. Per (pharma_narrow, period, firm) bid counts on the structural sample.
src <- path_v6("data/processed/bid_level_sme_pharma_g65.parquet")
firm_period <- dbGetQuery(con, sprintf("
  SELECT
    pharma_narrow,
    period,
    cod_forn,
    COUNT(*)  AS n_bids,
    SUM(won)  AS n_wins
  FROM read_parquet('%s')
  WHERE sme_flag = 1
    AND data_oc_numb BETWEEN 680 AND 715
    AND mod = 'pregao'                       -- Pregão only (structural sample)
  GROUP BY pharma_narrow, period, cod_forn
", src)) |> setDT()

log_step("67", sprintf("loaded %s (pharma_narrow, period, firm) cells",
  format(nrow(firm_period), big.mark = ",")), logf)

# 2. For each pharma class, compute turnover stats.
turnover <- function(class_flag) {
  d <- firm_period[pharma_narrow == class_flag]
  pre  <- d[period == "Pre",  unique(cod_forn)]
  post <- d[period == "Post", unique(cod_forn)]
  cont <- intersect(pre, post)
  exit <- setdiff(pre,  post)
  new  <- setdiff(post, pre)

  # Bid-weighted post-period decomposition: among post bids, what share
  # come from continuing vs new firms?
  post_bids       <- d[period == "Post", sum(n_bids)]
  post_bids_cont  <- d[period == "Post" & cod_forn %in% cont, sum(n_bids)]
  post_bids_new   <- d[period == "Post" & cod_forn %in% new,  sum(n_bids)]

  data.table(
    pharma_narrow   = class_flag,
    n_firms_pre     = length(pre),
    n_firms_post    = length(post),
    n_continuing    = length(cont),
    n_exit          = length(exit),
    n_new           = length(new),
    pct_post_firms_new       = 100 * length(new)  / length(post),
    pct_post_firms_cont      = 100 * length(cont) / length(post),
    pct_post_bids_from_new   = 100 * post_bids_new  / post_bids,
    pct_post_bids_from_cont  = 100 * post_bids_cont / post_bids,
    post_bids_total          = post_bids
  )
}

t_np <- turnover(0L)
t_ph <- turnover(1L)
results <- rbind(t_np, t_ph)
print(results)

log_step("67", sprintf("NP: %d firms post, %.1f%% NEW (%.1f%% of bids)",
  t_np$n_firms_post, t_np$pct_post_firms_new, t_np$pct_post_bids_from_new), logf)
log_step("67", sprintf("PH: %d firms post, %.1f%% NEW (%.1f%% of bids)",
  t_ph$n_firms_post, t_ph$pct_post_firms_new, t_ph$pct_post_bids_from_new), logf)

# 3. Persist.
arrow::write_parquet(results,
                     path_v6("data/processed/pharma_firm_turnover.parquet"),
                     compression = "snappy")

# 4. LaTeX table.
fmt_pct <- function(x) sprintf("%.1f\\%%", x)

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{SME firm turnover Pre vs Post the \\policyCutoffMonth{} cutoff, by class. Discriminating test between the selection and strict-invariance readings of $F_c^{\\text{SME,Post}}$.}",
  "\\label{tab:pharma_firm_turnover}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{6pt}",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & Pre-period & Post-period & Continuing & New (Post only) \\\\",
  "Class & SME firms & SME firms & (in both)  & (\\% of Post firms / Post bids) \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(results))) {
  r <- results[i]
  label <- if (r$pharma_narrow == 0) "Non-pharma" else "Pharma"
  tex_lines <- c(tex_lines, sprintf(
    "%s & %s & %s & %s & %s (%s / %s bids)\\\\",
    label,
    format(r$n_firms_pre,  big.mark = ","),
    format(r$n_firms_post, big.mark = ","),
    format(r$n_continuing, big.mark = ","),
    format(r$n_new,        big.mark = ","),
    fmt_pct(r$pct_post_firms_new),
    fmt_pct(r$pct_post_bids_from_new)
  ))
}
tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  sprintf("\\item Sample: Preg\\~ao SME bidders in the \\structuralWindowM-month structural window. Pre = $m < %d$ (Sep 2016--Feb 2018); Post = $m \\ge %d$ (Mar 2018--Aug 2019). Continuing firms appear in both periods; New firms appear only Post; the difference is exit.", 698L, 698L),
  "\\item \\textbf{Discriminating reading.} Under the equilibrium-selection interpretation of $F_c^{\\text{SME,Post}}$ (Assumption~\\ref{a:setaside}, main specification), the protected regime should induce previously unprofitable firms to enter, so a substantial share of post-period bids should come from new firms. Under the strict-invariance reading, post-period bids should be dominated by continuing firms with the same cost primitive. The pharma column compared to the non-pharma column is the within-paper discriminating test.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex_lines, path_v6("output/tables/tab_pharma_firm_turnover.tex"))

# 5. Headline scalars for 98_emit_macros.R.
arrow::write_parquet(
  data.table(
    np_pct_new_firms = t_np$pct_post_firms_new,
    np_pct_new_bids  = t_np$pct_post_bids_from_new,
    np_n_pre         = t_np$n_firms_pre,
    np_n_post        = t_np$n_firms_post,
    np_n_new         = t_np$n_new,
    ph_pct_new_firms = t_ph$pct_post_firms_new,
    ph_pct_new_bids  = t_ph$pct_post_bids_from_new,
    ph_n_pre         = t_ph$n_firms_pre,
    ph_n_post        = t_ph$n_firms_post,
    ph_n_new         = t_ph$n_new
  ),
  path_v6("data/processed/pharma_firm_turnover_meta.parquet"),
  compression = "snappy")

log_step("67", "outputs gravados", logf)
log_step("67", "done", logf)
