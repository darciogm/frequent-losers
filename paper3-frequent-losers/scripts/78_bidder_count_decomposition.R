# 78_bidder_count_decomposition.R
#
# Decomposes the within-cell winner-to-reference price compression (Referee
# Major 5). Script 62 showed the FL-presence price effect (winner_vs_ref ~
# losers, coef ~ -0.048) vanishes to +0.008 (n.s.) once log(n_firms) is added,
# and FL-present cells carry ~+0.507 more log-bidders. The manuscript reads the
# bidder-count channel as cover-bidding "theater". BUT "more bidders compress
# the winning bid toward the reference" is ALSO the reduced-form prediction of
# GENUINE pro-competitive entry. The undifferentiated log(n_firms) cannot tell
# the two apart.
#
# Mechanical fact: the winner is NEVER an FL firm (FL = always-loser, win_rate
# 0). Cover bidders submit losing (high) bids that do not set the winning price.
# So if the compression is real competition it must load on the GENUINE
# (non-FL) bidder count, not the FL count. This script splits n_firms into
#   losers_count   = FL participants   (already in p3_prepared.rds)
#   n_firms_excl   = non-FL "genuine"  (= n_firms - losers_count, already built)
# and re-runs the within-cell regression with the two counts entered separately.
#
# PRE-COMMITTED INTERPRETATION (stated before reading results):
#   "Cover-bidding theater" is IDENTIFIED (not benign entry) only if the
#   winner-to-reference compression loads on the FL bidder count (losers_count)
#   and NOT on the genuine bidder count (n_firms_excl). If instead the genuine
#   count carries the compression (and/or FL-present cells simply have more
#   genuine bidders), the channel is observationally pro-competitive entry and
#   the "theater" language is unidentified -> downgrade to "bidder-count
#   inflation of ambiguous origin" and disclose the equivalence.
#
# Mirrors script 62's overlap_cell, DV, cluster exactly; only the bidder-count
# regressors change. Outputs:
#   output/mechanism_within_cell/bidder_decomp.csv
#   output/mechanism_within_cell/bidder_decomp_log.txt

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({ library(data.table); library(fixest) })
BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "mechanism_within_cell")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
setFixest_nthreads(12L)
LOG <- file.path(OUT, "bidder_decomp_log.txt"); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
say("=== 78_bidder_count_decomposition.R === %s", format(Sys.time()))

dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]
dt[, log_ref_price := log1p(pmax(bid_ref_price_min, 0))]
dt <- dt[is.finite(log_ref_price) & log_ref_price > 0]
dt[, winner_vs_ref := lneg_price - log_ref_price]
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q, tender_value_q, drop = TRUE)]
dt[, has_treat := as.integer(any(losers == 1L)), by = overlap_cell]
dt[, has_ctrl  := as.integer(any(losers == 0L)), by = overlap_cell]
ov <- dt[has_treat == 1L & has_ctrl == 1L]

# sanity: identity n_firms = losers_count + n_firms_excl
ov[, check := n_firms - losers_count - n_firms_excl]
say("identity check n_firms - losers_count - n_firms_excl: max|.|=%g", max(abs(ov$check), na.rm=TRUE))
say("overlap items=%s ; treated=%s ; mean losers_count(FL-present)=%.2f ; mean n_firms_excl=%.2f",
    format(nrow(ov), big.mark=","), format(sum(ov$losers==1L), big.mark=","),
    ov[losers==1L, mean(losers_count)], ov[, mean(n_firms_excl)])

ov[, l_fl  := log1p(losers_count)]     # FL bidder count (cover-bidder candidates)
ov[, l_gen := log1p(n_firms_excl)]     # genuine (non-FL) bidder count

# ---- (A) replicate 62: total-count channel --------------------------------
mA0 <- feols(winner_vs_ref ~ losers | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
mA1 <- feols(winner_vs_ref ~ losers + log(n_firms) | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
say("\n[A] replicate script 62:")
say("  losers only            : losers=%+.4f (se %.4f)", coef(mA0)[1], se(mA0)[1])
say("  + log(n_firms)         : losers=%+.4f (se %.4f) ; log(n_firms)=%+.4f (se %.4f)",
    coef(mA1)["losers"], se(mA1)["losers"], coef(mA1)["log(n_firms)"], se(mA1)["log(n_firms)"])

# ---- (B) decomposition: genuine vs FL bidder counts entered separately ----
mB_gen  <- feols(winner_vs_ref ~ losers + l_gen | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
mB_fl   <- feols(winner_vs_ref ~ losers + l_fl  | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
mB_both <- feols(winner_vs_ref ~ losers + l_gen + l_fl | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
say("\n[B] decomposed bidder-count channels (winner_vs_ref):")
say("  + genuine only  : losers=%+.4f (se %.4f) ; l_gen=%+.4f (se %.4f)",
    coef(mB_gen)["losers"], se(mB_gen)["losers"], coef(mB_gen)["l_gen"], se(mB_gen)["l_gen"])
say("  + FL only       : losers=%+.4f (se %.4f) ; l_fl =%+.4f (se %.4f)",
    coef(mB_fl)["losers"], se(mB_fl)["losers"], coef(mB_fl)["l_fl"], se(mB_fl)["l_fl"])
say("  + both          : losers=%+.4f (se %.4f) ; l_gen=%+.4f (se %.4f) ; l_fl=%+.4f (se %.4f)",
    coef(mB_both)["losers"], se(mB_both)["losers"],
    coef(mB_both)["l_gen"], se(mB_both)["l_gen"], coef(mB_both)["l_fl"], se(mB_both)["l_fl"])

# ---- (C) decompose the +0.507 inflation: is it FL or genuine bidders? ------
mC_tot <- feols(log(n_firms)        ~ losers | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
mC_gen <- feols(l_gen               ~ losers | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
mC_fl  <- feols(l_fl                ~ losers | overlap_cell, ov, cluster=~overlap_cell, lean=TRUE)
say("\n[C] what does FL presence add to the bidder pool? (RHS=losers)")
say("  log(n_firms)  : %+.4f (se %.4f)", coef(mC_tot)[1], se(mC_tot)[1])
say("  l_gen (genuine): %+.4f (se %.4f)  <- does FL presence bring MORE GENUINE bidders?", coef(mC_gen)[1], se(mC_gen)[1])
say("  l_fl  (FL)     : %+.4f (se %.4f)  <- mechanical (losers=1 => losers_count>=1)", coef(mC_fl)[1], se(mC_fl)[1])

# ---- verdict ---------------------------------------------------------------
b_gen <- coef(mB_both)["l_gen"]; b_fl <- coef(mB_both)["l_fl"]
p_gen <- pvalue(mB_both)["l_gen"]; p_fl <- pvalue(mB_both)["l_fl"]
gen_drives <- (abs(b_gen) > abs(b_fl)) && (p_gen < 0.05)
say("\n========== VERDICT vs PRE-COMMITTED INTERPRETATION ==========")
say("  genuine-count coef=%+.4f (p=%.3g) ; FL-count coef=%+.4f (p=%.3g)", b_gen, p_gen, b_fl, p_fl)
say("  compression loads on: %s", ifelse(abs(b_gen) > abs(b_fl), "GENUINE bidders", "FL bidders"))
say("  also: FL presence brings %+.4f genuine log-bidders (p=%.3g)", coef(mC_gen)[1], pvalue(mC_gen)["losers"])
say("  => %s", ifelse(gen_drives,
    "BENIGN ENTRY NOT EXCLUDED: compression is genuine competition -> 'theater' UNIDENTIFIED -> downgrade language",
    "FL-count channel dominates -> cover-bidding-consistent (still observational)"))

out <- rbindlist(list(
  data.table(spec="winner_vs_ref~losers",              term="losers", coef=coef(mA0)[1], se=se(mA0)[1]),
  data.table(spec="+log(n_firms)",                     term="losers", coef=coef(mA1)["losers"], se=se(mA1)["losers"]),
  data.table(spec="+log(n_firms)",                     term="log_n_firms", coef=coef(mA1)["log(n_firms)"], se=se(mA1)["log(n_firms)"]),
  data.table(spec="+genuine+FL",                       term="losers", coef=coef(mB_both)["losers"], se=se(mB_both)["losers"]),
  data.table(spec="+genuine+FL",                       term="l_gen", coef=b_gen, se=se(mB_both)["l_gen"]),
  data.table(spec="+genuine+FL",                       term="l_fl",  coef=b_fl, se=se(mB_both)["l_fl"]),
  data.table(spec="inflation: l_gen~losers",           term="losers", coef=coef(mC_gen)[1], se=se(mC_gen)[1]),
  data.table(spec="inflation: l_fl~losers",            term="losers", coef=coef(mC_fl)[1], se=se(mC_fl)[1])
), fill=TRUE)
fwrite(out, file.path(OUT, "bidder_decomp.csv"))
say("\nwrote %s", file.path(OUT, "bidder_decomp.csv"))
