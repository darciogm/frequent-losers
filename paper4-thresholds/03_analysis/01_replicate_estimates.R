#!/usr/bin/env Rscript
# ============================================================================
# 01_replicate_estimates.R
# Replicate ALL key RDD estimates from Paper (Dario) and LACEA (Sergio)
# using fixest, with proper FE and clustering.
#
# Goal: determine which set of results is correct and robust.
# ============================================================================

library(arrow)
library(fixest)
library(data.table)

setFixest_nthreads(8)

# ── Load data ──
cat("Loading data...\n")
df <- as.data.table(read_parquet(
  "/home/darciogm1/projetos/bitter-pills/paper4-thresholds/02_data/final/df_convite_winner_looser.parquet"
))
cat(sprintf("  Loaded: %s rows x %s cols\n", format(nrow(df), big.mark=","), ncol(df)))

# ── Check key variables exist ──
outcomes_to_check <- c(
  "won_t_minus_1", "won_t_minus_1_compr", "won_t_minus_1_market",
  "won_t_minus_1_market_item", "won_t_minus_1_item_class",
  "last",
  "share_won90_market_item", "share_won90_compr",
  "share_won120_market_item",
  "cumprof_won_120_market_item_std", "cumprof_won_120_compr_std__",
  "cumprof_won_90_market_item_std"
)
cat("\n── Outcome variables ──\n")
for (v in outcomes_to_check) {
  if (v %in% names(df)) {
    vals <- df[[v]]
    n_ok <- sum(!is.na(vals))
    cat(sprintf("  %-40s  N=%s  mean=%.4f\n", v, format(n_ok, big.mark=","), mean(vals, na.rm=TRUE)))
  } else {
    cat(sprintf("  %-40s  NOT FOUND\n", v))
  }
}

# ── Check FE variables ──
fe_vars <- c("year", "market_item", "market",
             "códigogrupo", "códigounidadecompradora",
             "códigoclasse")
cat("\n── FE variables ──\n")
for (v in fe_vars) {
  if (v %in% names(df)) {
    cat(sprintf("  %-40s  %s unique values\n", v, format(uniqueN(df[[v]]), big.mark=",")))
  } else {
    cat(sprintf("  %-40s  NOT FOUND\n", v))
  }
}

# ── Ensure proper types ──
df[, flagvencedor := as.integer(flagvencedor)]
df[, MV := as.numeric(MV)]

# Convert FE to factors for fixest
for (v in fe_vars) {
  if (v %in% names(df)) df[, (v) := as.factor(get(v))]
}

# ── Helper: run one RDD spec and return summary row ──
run_rdd <- function(outcome, bw, fe_formula, cluster_var, label) {
  # Build sample
  d <- df[!is.na(get(outcome)) & !is.na(MV) & abs(MV) < bw & MV != 0]
  n <- nrow(d)
  if (n < 100) return(NULL)

  # Formula: outcome ~ flagvencedor * MV | FE
  if (is.null(fe_formula) || fe_formula == "") {
    fml <- as.formula(paste0(outcome, " ~ flagvencedor * MV"))
  } else {
    fml <- as.formula(paste0(outcome, " ~ flagvencedor * MV | ", fe_formula))
  }

  # Clustering
  if (!is.null(cluster_var) && cluster_var %in% names(d)) {
    fit <- tryCatch(
      feols(fml, data = d, cluster = cluster_var, lean = TRUE),
      error = function(e) { cat(sprintf("  ERROR [%s]: %s\n", label, e$message)); NULL }
    )
  } else {
    fit <- tryCatch(
      feols(fml, data = d, vcov = "hetero", lean = TRUE),
      error = function(e) { cat(sprintf("  ERROR [%s]: %s\n", label, e$message)); NULL }
    )
  }

  if (is.null(fit)) return(NULL)

  ct <- coeftable(fit)
  # Get flagvencedor coefficient (main effect)
  idx <- which(rownames(ct) == "flagvencedor")
  if (length(idx) == 0) return(NULL)

  data.table(
    label    = label,
    outcome  = outcome,
    bw       = bw,
    fe       = ifelse(is.null(fe_formula) || fe_formula == "", "none", fe_formula),
    cluster  = ifelse(is.null(cluster_var), "HC1", cluster_var),
    coef     = ct[idx, 1],
    se       = ct[idx, 2],
    tstat    = ct[idx, 3],
    pval     = ct[idx, 4],
    n        = n,
    mean_dv  = mean(d[[outcome]], na.rm = TRUE),
    sd_dv    = sd(d[[outcome]], na.rm = TRUE)
  )
}

# ============================================================================
# BLOCK 1: PAPER SPECIFICATIONS (Dario — 02_a_analysis_incumbency.do)
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("BLOCK 1: PAPER SPECIFICATIONS (Dario)\n")
cat(strrep("=", 70), "\n\n")

paper_specs <- rbindlist(Filter(Negate(is.null), list(
  # Incumbent (market) — BW 0.02, no FE
  run_rdd("won_t_minus_1_market", 0.02, NULL, NULL,
          "Paper: Incumbent(mkt) BW=0.02 no-FE"),
  # Incumbent (market) — BW 0.02, FE: year + market_item
  run_rdd("won_t_minus_1_market", 0.02, "year + market_item", "market_item",
          "Paper: Incumbent(mkt) BW=0.02 FE=yr+mkt cl=mkt"),
  # Incumbent (market) — BW 0.01
  run_rdd("won_t_minus_1_market", 0.01, NULL, NULL,
          "Paper: Incumbent(mkt) BW=0.01 no-FE"),
  run_rdd("won_t_minus_1_market", 0.01, "year + market_item", "market_item",
          "Paper: Incumbent(mkt) BW=0.01 FE=yr+mkt cl=mkt"),
  # Last bid — BW 0.011
  run_rdd("last", 0.011, NULL, NULL,
          "Paper: Last BW=0.011 no-FE"),
  run_rdd("last", 0.011, "year + market_item", "market_item",
          "Paper: Last BW=0.011 FE=yr+mkt cl=mkt"),
  # Last bid — BW 0.01
  run_rdd("last", 0.01, NULL, NULL,
          "Paper: Last BW=0.01 no-FE"),
  run_rdd("last", 0.01, "year + market_item", "market_item",
          "Paper: Last BW=0.01 FE=yr+mkt cl=mkt")
)))

print(paper_specs[, .(label, coef=round(coef,4), se=round(se,4),
                       t=round(tstat,2), n=format(n, big.mark=","),
                       mean_dv=round(mean_dv,3))])

# ============================================================================
# BLOCK 2: LACEA SPECIFICATIONS (Sergio — sergio_1024.do)
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("BLOCK 2: LACEA SPECIFICATIONS (Sergio)\n")
cat(strrep("=", 70), "\n\n")

lacea_specs <- rbindlist(Filter(Negate(is.null), list(
  # Incumbent (buyer) — BW 0.01, FE: year + group + buyer
  run_rdd("won_t_minus_1_compr", 0.01, NULL, NULL,
          "LACEA: Incumbent(buyer) BW=0.01 no-FE"),
  run_rdd("won_t_minus_1_compr", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "LACEA: Incumbent(buyer) BW=0.01 FE=yr+grp+buyer cl=buyer"),
  # Ratio Won (buyer) — share_won90_compr
  run_rdd("share_won90_compr", 0.01, NULL, NULL,
          "LACEA: RatioWon(buyer) BW=0.01 no-FE"),
  run_rdd("share_won90_compr", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "LACEA: RatioWon(buyer) BW=0.01 FE=yr+grp+buyer cl=buyer"),
  # Backlog (buyer) — cumprof_won_120_compr_std_
  run_rdd("cumprof_won_120_compr_std_", 0.01, NULL, NULL,
          "LACEA: Backlog(buyer) BW=0.01 no-FE"),
  run_rdd("cumprof_won_120_compr_std_", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "LACEA: Backlog(buyer) BW=0.01 FE=yr+grp+buyer cl=buyer")
)))

print(lacea_specs[, .(label, coef=round(coef,4), se=round(se,4),
                       t=round(tstat,2), n=format(n, big.mark=","),
                       mean_dv=round(mean_dv,3))])

# ============================================================================
# BLOCK 3: CROSS-COMPARISON — same outcome, both definitions
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("BLOCK 3: CROSS-COMPARISON (market vs buyer, same BW)\n")
cat(strrep("=", 70), "\n\n")

cross_specs <- rbindlist(Filter(Negate(is.null), list(
  # ── Incumbency: market vs buyer, BW=0.01, with their respective FE ──
  run_rdd("won_t_minus_1_market", 0.01, "year + market_item", "market_item",
          "Incumb(MKT) BW=0.01 FE=yr+mkt"),
  run_rdd("won_t_minus_1_compr", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "Incumb(BUYER) BW=0.01 FE=yr+grp+buyer"),
  # ── Same FE for both (year only) to make comparable ──
  run_rdd("won_t_minus_1_market", 0.01, "year", NULL,
          "Incumb(MKT) BW=0.01 FE=yr only"),
  run_rdd("won_t_minus_1_compr", 0.01, "year", NULL,
          "Incumb(BUYER) BW=0.01 FE=yr only"),
  # ── Share won: market vs buyer, BW=0.01 ──
  run_rdd("share_won90_market_item", 0.01, "year + market_item", "market_item",
          "ShareWon(MKT) BW=0.01 FE=yr+mkt"),
  run_rdd("share_won90_compr", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "ShareWon(BUYER) BW=0.01 FE=yr+grp+buyer"),
  # ── Backlog: market vs buyer, BW=0.01 ──
  run_rdd("cumprof_won_120_market_item_std", 0.01, "year + market_item", "market_item",
          "Backlog(MKT) BW=0.01 FE=yr+mkt"),
  run_rdd("cumprof_won_120_compr_std_", 0.01,
          "year + códigogrupo + códigounidadecompradora",
          "códigounidadecompradora",
          "Backlog(BUYER) BW=0.01 FE=yr+grp+buyer")
)))

print(cross_specs[, .(label, coef=round(coef,4), se=round(se,4),
                       t=round(tstat,2), n=format(n, big.mark=","),
                       mean_dv=round(mean_dv,3))])

# ============================================================================
# BLOCK 4: BANDWIDTH SENSITIVITY (market-level incumbent)
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("BLOCK 4: BANDWIDTH SENSITIVITY\n")
cat(strrep("=", 70), "\n\n")

bw_grid <- c(0.005, 0.0075, 0.01, 0.015, 0.02, 0.025, 0.03, 0.05)

bw_results <- rbindlist(Filter(Negate(is.null), lapply(bw_grid, function(bw) {
  run_rdd("won_t_minus_1_market", bw, "year + market_item", "market_item",
          sprintf("Incumb(mkt) BW=%.4f", bw))
})))

cat("Incumbency (market) — bandwidth sensitivity:\n")
print(bw_results[, .(bw, coef=round(coef,4), se=round(se,4),
                      t=round(tstat,2), n=format(n, big.mark=","))])

bw_backlog <- rbindlist(Filter(Negate(is.null), lapply(bw_grid, function(bw) {
  run_rdd("cumprof_won_120_market_item_std", bw, "year + market_item", "market_item",
          sprintf("Backlog(mkt) BW=%.4f", bw))
})))

cat("\nBacklog (market) — bandwidth sensitivity:\n")
print(bw_backlog[, .(bw, coef=round(coef,4), se=round(se,4),
                      t=round(tstat,2), n=format(n, big.mark=","))])

bw_last <- rbindlist(Filter(Negate(is.null), lapply(bw_grid, function(bw) {
  run_rdd("last", bw, "year + market_item", "market_item",
          sprintf("Last BW=%.4f", bw))
})))

cat("\nLast Bid — bandwidth sensitivity:\n")
print(bw_last[, .(bw, coef=round(coef,4), se=round(se,4),
                   t=round(tstat,2), n=format(n, big.mark=","))])

cat("\n", strrep("=", 70), "\n")
cat("DONE\n")
cat(strrep("=", 70), "\n")
