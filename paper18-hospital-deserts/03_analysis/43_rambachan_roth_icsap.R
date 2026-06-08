#!/usr/bin/env Rscript
# 43_rambachan_roth_icsap.R
#
# Path2-rest #B2 (parecer Major B2): Rambachan-Roth (2023) sensitivity
# bounds para o ICSAP post-period ATT sob violações limitadas de
# parallel trends. Reporta:
#   - smoothness restriction (M-bound) sob a qual o intervalo robusto
#     ainda exclui zero
#   - "breakdown M" — maior M que mantém significância
#
# Output: 04_logs/43_rambachan_roth_icsap.json

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
  library(HonestDiD)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")

cat("==== begin Rambachan-Roth sensitivity for ICSAP ====\n")

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel <- panel[is.finite(icsap_per1k)]
panel[, gn_use := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

m <- feols(icsap_per1k ~ sunab(gn_use, year) | muni_id + year,
           data = panel, cluster = "muni_id")

# Extrair coefs do event-study (sunab agrega cohort×time em year::<e>)
cf_all <- coef(m); vc <- vcov(m)
match <- regmatches(names(cf_all), regexec("^year::(-?[0-9]+)$", names(cf_all)))
es <- do.call(rbind, lapply(seq_along(match), function(i) {
  mi <- match[[i]]
  if (length(mi) == 2) data.table(idx = i,
                                   name = names(cf_all)[i],
                                   e = as.integer(mi[2]),
                                   cf = cf_all[i]) else NULL
}))
es <- es[order(e)]
cat("event-study coefs extracted:\n")
print(es)

# Construir vetor beta + sigma na ordem do HonestDiD
# Reference period é -1 (omitted in sunab)
keep_idx_es <- which(es$e != -1)
cf_keep <- es$cf[keep_idx_es]
e_keep <- es$e[keep_idx_es]
idx_in_full <- es$idx[keep_idx_es]
sigma_keep <- vc[idx_in_full, idx_in_full]

# numPrePeriods: número de coefs com e < 0 (excluindo -1)
# numPostPeriods: número de coefs com e >= 0
num_pre  <- sum(e_keep < 0)
num_post <- sum(e_keep >= 0)
cat(sprintf("num_pre=%d  num_post=%d\n", num_pre, num_post))

# Beta vector deve estar em ordem cronológica: pre primeiro, depois post
# (HonestDiD convention)
ord <- order(e_keep)
betahat <- cf_keep[ord]
sigma_full <- sigma_keep[ord, ord]

# Post-period average — l_vec uniforme — corresponde ao ATT agregado
# que o paper reporta (não o coef individual em e=+5)
l_vec <- rep(1 / num_post, num_post)
e_target <- "post-period average"
cat(sprintf("targeting %s (l_vec uniform across %d post-periods)\n",
            e_target, num_post))
cat("l_vec:", round(l_vec, 3), "\n")

# Construct robust CI under relative-magnitudes restriction (Mbar) — RM
# Mbar=0 means no pre-trend deviation allowed (= classical CI)
# Mbar=1 means post-period deviation can equal worst pre-period deviation
M_grid <- c(0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 1.0)

run_sensitivity <- function(M) {
  tryCatch({
    out <- createSensitivityResults_relativeMagnitudes(
      betahat = betahat,
      sigma   = sigma_full,
      numPrePeriods = num_pre,
      numPostPeriods = num_post,
      l_vec = l_vec,
      Mbarvec = c(M),
      gridPoints = 200
    )
    out$lb[1]; out$ub[1]
    list(M = M, lb = out$lb[1], ub = out$ub[1],
         excludes_zero = (out$lb[1] > 0) || (out$ub[1] < 0))
  }, error = function(e) {
    list(M = M, lb = NA, ub = NA, excludes_zero = NA, error = conditionMessage(e))
  })
}

results <- list()
for (M in M_grid) {
  r <- run_sensitivity(M)
  results[[paste0("Mbar_", M)]] <- r
  cat(sprintf("  Mbar=%.2f | CI=[%.3f, %.3f] | excludes 0: %s\n",
              M, r$lb, r$ub, r$excludes_zero))
}

# Original ATT estimate (post-period average)
post_beta <- betahat[(num_pre + 1):(num_pre + num_post)]
post_sigma <- sigma_full[(num_pre + 1):(num_pre + num_post),
                          (num_pre + 1):(num_pre + num_post)]
beta_target <- as.numeric(l_vec %*% post_beta)
se_target   <- as.numeric(sqrt(t(l_vec) %*% post_sigma %*% l_vec))
ci_orig_lb <- beta_target - 1.96 * se_target
ci_orig_ub <- beta_target + 1.96 * se_target
cat(sprintf("\nOriginal target (%s): %.3f (SE=%.3f)  CI=[%.3f, %.3f]\n",
            e_target, beta_target, se_target, ci_orig_lb, ci_orig_ub))

# Breakdown Mbar — maior M com lb > 0 (efeito positivo persiste)
# Strategy: bisection-like
bd_M <- NA
for (M in M_grid) {
  k <- paste0("Mbar_", M)
  if (!is.null(results[[k]]) && !is.na(results[[k]]$lb)) {
    if (results[[k]]$lb > 0) bd_M <- M
  }
}
cat(sprintf("breakdown Mbar (last M with lb>0): %s\n", as.character(bd_M)))

out <- list(
  point_estimate_e5 = beta_target,
  se_e5 = se_target,
  ci_original_e5 = c(ci_orig_lb, ci_orig_ub),
  num_pre = num_pre,
  num_post = num_post,
  e_grid = e_keep[ord],
  betahat = betahat,
  M_grid = M_grid,
  sensitivity_results = results,
  breakdown_Mbar = bd_M
)
write(toJSON(out, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "43_rambachan_roth_icsap.json"))
cat("wrote 43_rambachan_roth_icsap.json\n")
