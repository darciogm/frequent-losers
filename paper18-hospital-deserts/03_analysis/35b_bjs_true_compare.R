#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(jsonlite)
  library(HonestDiD)
  library(did)
  library(did2s)
  library(didimputation)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")
RR_JSON <- file.path(LOG_DIR, "43_rambachan_roth_icsap.json")

set.seed(42)
cat("==== begin staggered estimator compare ====\n")

compute_joint_wald <- function(att_vec, inf_fun) {
  if (is.list(inf_fun)) {
    if (!is.null(inf_fun$dynamic.inf.func.e)) {
      inf_fun <- inf_fun$dynamic.inf.func.e
    } else if (length(inf_fun) > 0) {
      inf_fun <- inf_fun[[1]]
    }
  }
  keep <- which(is.finite(att_vec))
  if (length(keep) == 0 || is.null(inf_fun)) {
    return(list(stat = NA_real_, df = 0L, p_value = NA_real_))
  }
  if_mat <- as.matrix(inf_fun[, keep, drop = FALSE])
  if_mat[!is.finite(if_mat)] <- 0
  Sigma <- stats::cov(if_mat) / nrow(if_mat)
  if (!is.matrix(Sigma)) {
    Sigma <- matrix(Sigma, nrow = 1, ncol = 1)
  }
  ridge <- max(1e-8, mean(diag(Sigma), na.rm = TRUE) * 1e-8)
  Sigma <- Sigma + diag(ridge, nrow(Sigma))
  b <- matrix(att_vec[keep], ncol = 1)
  stat <- as.numeric(t(b) %*% solve(Sigma, b))
  df <- length(keep)
  list(stat = stat, df = df, p_value = stats::pchisq(stat, df = df, lower.tail = FALSE))
}

run_sa <- function(panel, yname) {
  d <- copy(panel)[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  m <- feols(as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname)), data = d, cluster = ~muni_id)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]), se = as.numeric(se(agg)[1]))
}

run_cs21 <- function(panel, yname) {
  d <- copy(panel)[is.finite(get(yname))]
  d[, gn := fifelse(g_emb > 0, as.integer(g_emb), 0L)]
  est_method <- "ipw"
  attgt <- tryCatch(
    did::att_gt(
      yname = yname,
      tname = "year",
      idname = "muni_id",
      gname = "gn",
      data = d,
      xformla = ~1,
      control_group = "notyettreated",
      est_method = est_method,
      panel = TRUE,
      allow_unbalanced_panel = TRUE,
      faster_mode = FALSE,
      bstrap = FALSE,
      cband = FALSE,
      print_details = FALSE
    ),
    error = function(e) e
  )
  if (inherits(attgt, "error")) {
    est_method <- "reg"
    attgt <- did::att_gt(
      yname = yname,
      tname = "year",
      idname = "muni_id",
      gname = "gn",
      data = d,
      xformla = ~1,
      control_group = "notyettreated",
      est_method = est_method,
      panel = TRUE,
      allow_unbalanced_panel = TRUE,
      faster_mode = FALSE,
      bstrap = FALSE,
      cband = FALSE,
      print_details = FALSE
    )
  }
  agg_simple <- did::aggte(attgt, type = "simple", na.rm = TRUE)
  agg_dynamic <- did::aggte(attgt, type = "dynamic", na.rm = TRUE)
  post_idx <- which(agg_dynamic$egt >= 0)
  joint <- compute_joint_wald(agg_dynamic$att.egt[post_idx], agg_dynamic$inf.function)
  list(
    att = as.numeric(agg_simple$overall.att),
    se = as.numeric(agg_simple$overall.se),
    est_method = est_method,
    post_wald_stat = joint$stat,
    post_wald_df = joint$df,
    post_wald_p = joint$p_value
  )
}

run_bjs <- function(panel, yname) {
  d <- copy(panel)[is.finite(get(yname))]
  d[, first_treat := fifelse(g_emb > 0, as.integer(g_emb), 0L)]
  d[, treat_emb_yr := as.integer(treat_emb_yr)]

  did2s_fit <- did2s::did2s(
    data = d,
    yname = yname,
    first_stage = ~ 0 | muni_id + year,
    second_stage = ~ i(treat_emb_yr, ref = FALSE),
    treatment = "treat_emb_yr",
    cluster_var = "muni_id"
  )
  did2s_att <- as.numeric(coef(did2s_fit)[1])
  did2s_se <- as.numeric(sqrt(diag(vcov(did2s_fit)))[1])

  didimp_fit <- didimputation::did_imputation(
    data = d,
    yname = yname,
    gname = "first_treat",
    tname = "year",
    idname = "muni_id",
    cluster_var = "muni_id"
  )
  didimp_att <- as.numeric(didimp_fit$estimate[1])
  didimp_se <- as.numeric(didimp_fit$std.error[1])

  list(
    did2s_att = did2s_att,
    did2s_se = did2s_se,
    didimp_att = didimp_att,
    didimp_se = didimp_se
  )
}

extract_did2s_event_study <- function(panel, yname) {
  d <- copy(panel)[is.finite(get(yname))]
  d[, treat_emb_yr := as.integer(treat_emb_yr)]
  d[, rel_year_bjs := fifelse(g_emb > 0, year - g_emb, Inf)]

  fit <- did2s::did2s(
    data = d,
    yname = yname,
    first_stage = ~ 0 | muni_id + year,
    second_stage = ~ i(rel_year_bjs, ref = c(-1, Inf)),
    treatment = "treat_emb_yr",
    cluster_var = "muni_id"
  )
  cf <- coef(fit)
  vc <- vcov(fit)
  match <- regmatches(names(cf), regexec("^rel_year_bjs::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(match), function(i) {
    mi <- match[[i]]
    if (length(mi) == 2) {
      data.table(idx = i, e = as.integer(mi[2]), cf = as.numeric(cf[i]))
    } else {
      NULL
    }
  }))
  es <- es[order(e)]
  keep <- es$e != -1
  es <- es[keep]
  Sigma <- vc[es$idx, es$idx, drop = FALSE]
  ord <- order(es$e)
  list(e = es$e[ord], betahat = es$cf[ord], sigma = Sigma[ord, ord, drop = FALSE])
}

run_rambachan_roth <- function(panel) {
  es <- extract_did2s_event_study(panel, "icsap_per1k")
  num_pre <- sum(es$e < 0)
  num_post <- sum(es$e >= 0)
  l_vec <- rep(1 / num_post, num_post)
  M_grid <- c(0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 1.0)

  run_sensitivity <- function(M) {
    out <- createSensitivityResults_relativeMagnitudes(
      betahat = es$betahat,
      sigma = es$sigma,
      numPrePeriods = num_pre,
      numPostPeriods = num_post,
      l_vec = l_vec,
      Mbarvec = c(M),
      gridPoints = 200
    )
    list(
      M = M,
      lb = as.numeric(out$lb[1]),
      ub = as.numeric(out$ub[1]),
      excludes_zero = (out$lb[1] > 0) || (out$ub[1] < 0)
    )
  }

  sensitivity_results <- setNames(lapply(M_grid, run_sensitivity), paste0("Mbar_", M_grid))
  post_slice <- (num_pre + 1):(num_pre + num_post)
  beta_target <- as.numeric(l_vec %*% es$betahat[post_slice])
  se_target <- as.numeric(sqrt(t(l_vec) %*% es$sigma[post_slice, post_slice, drop = FALSE] %*% l_vec))
  ci_original <- c(beta_target - 1.96 * se_target, beta_target + 1.96 * se_target)

  breakdown_M <- NA_real_
  for (nm in names(sensitivity_results)) {
    if (isTRUE(sensitivity_results[[nm]]$lb > 0)) {
      breakdown_M <- sensitivity_results[[nm]]$M
    }
  }

  out <- list(
    method = "did2s_event_study",
    point_estimate_e5 = beta_target,
    se_e5 = se_target,
    ci_original_e5 = ci_original,
    num_pre = num_pre,
    num_post = num_post,
    e_grid = es$e,
    betahat = es$betahat,
    M_grid = M_grid,
    sensitivity_results = sensitivity_results,
    breakdown_Mbar = breakdown_M
  )
  write(toJSON(out, auto_unbox = TRUE, pretty = TRUE, na = "null"), RR_JSON)
  out
}

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
rr <- run_rambachan_roth(panel)

rows <- list()
for (y in c("travel_burden_km", "icsap_per1k")) {
  sa <- run_sa(panel, y)
  cs <- run_cs21(panel, y)
  bj <- run_bjs(panel, y)
  rows[[length(rows) + 1]] <- data.table(
    outcome = y,
    sa_att = sa$att,
    sa_se = sa$se,
    cs_att = cs$att,
    cs_se = cs$se,
    cs_method = cs$est_method,
    cs_post_wald_stat = cs$post_wald_stat,
    cs_post_wald_df = cs$post_wald_df,
    cs_post_wald_p = cs$post_wald_p,
    did2s_att = bj$did2s_att,
    did2s_se = bj$did2s_se,
    didimp_att = bj$didimp_att,
    didimp_se = bj$didimp_se,
    rr_breakdown_M = ifelse(y == "icsap_per1k", rr$breakdown_Mbar, NA_real_)
  )
}
res <- rbindlist(rows)

payload <- list(
  results = res,
  rambachan_roth = rr
)
write(toJSON(payload, auto_unbox = TRUE, pretty = TRUE, na = "null"), file.path(LOG_DIR, "35b_staggered_compare.json"))

tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Comparison of staggered DiD estimators on the F5 main sample. Callaway--Sant'Anna uses the simple aggregation and reports a covariance-respecting post-period joint Wald test from the dynamic aggregation influence function. The BJS slot reports both the true did2s and did_imputation implementations. Rambachan--Roth is re-run on the did2s event-study for ICSAP.}",
  "\\label{tab:staggered-did-compare}",
  "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Outcome & Sun-Abraham & Callaway--Sant'Anna & did2s & did\\_imputation & Rambachan--Roth breakdown \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(res))) {
  rr_lab <- ifelse(is.na(res$rr_breakdown_M[i]), "---", sprintf("$M=%.2f$", res$rr_breakdown_M[i]))
  outcome_lab <- ifelse(res$outcome[i] == "travel_burden_km", "Travel (km)", "ICSAP per 1k")
  tab <- c(
    tab,
    sprintf(
      "%s & $%+.3f$ (%.3f) & $%+.3f$ (%.3f) & $%+.3f$ (%.3f) & $%+.3f$ (%.3f) & %s \\\\",
      outcome_lab,
      res$sa_att[i], res$sa_se[i],
      res$cs_att[i], res$cs_se[i],
      res$did2s_att[i], res$did2s_se[i],
      res$didimp_att[i], res$didimp_se[i],
      rr_lab
    ),
    sprintf(
      "\\multicolumn{6}{l}{\\footnotesize CS (%s) post-period joint Wald: $\\chi^2(%d)=%.2f$, $p=%.4f$.} \\\\",
      res$cs_method[i],
      as.integer(res$cs_post_wald_df[i]),
      res$cs_post_wald_stat[i],
      res$cs_post_wald_p[i]
    )
  )
}
tab <- c(tab, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_staggered_did_compare.tex"))

cat("done\n")
