# Layer 1 / Track F --- Wild cluster bootstrap on UTG specifications.
#
# fwildclusterboot is unavailable for R 4.5; we implement the standard
# Rademacher wild cluster bootstrap manually with feols. ~100 PBU clusters
# warrants this since asymptotic CR-cluster SEs may be liberal.
#
# Procedure (Cameron-Gelbach-Miller 2008, MacKinnon-Webb 2017):
#   1. Estimate the unrestricted model y = X*beta + FE + e; collect residuals.
#   2. Estimate the null-imposed model y = X_red*beta_red + FE + e_null
#      where the coefficient of interest is constrained to 0.
#   3. For B replicates:
#      - Draw cluster-level Rademacher weights w_c in {-1, +1}.
#      - Form y* = X_red*beta_red_hat + FE_hat + w_c[c(i)] * e_null_i.
#      - Refit unrestricted model; store t-statistic for the constrained coef.
#   4. Bootstrap p = share of |t*| >= |t_obs|.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))
bp_set_threads(12L)

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
LOG  <- file.path(LOGS, "44_wild_bootstrap.log")
writeLines(sprintf("# 44_wild_bootstrap | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

bp_wild_cluster <- function(d, fmla_full, fmla_null_only_fe,
                             param = "admin", clusterid = "pbu_id",
                             B = 999L, seed = 20260504L) {
  set.seed(seed)
  m_full <- feols(fmla_full, data = d, cluster = as.formula(paste0("~", clusterid)))
  b_obs  <- coef(m_full)[param]
  se_obs <- sqrt(diag(vcov(m_full)))[param]
  t_obs  <- b_obs / se_obs

  m_null <- feols(fmla_null_only_fe, data = d, cluster = as.formula(paste0("~", clusterid)))
  d2 <- copy(d)
  d2[, .y_null_pred := predict(m_null, newdata = d2)]
  d2[, .e_null      := get(all.vars(fmla_null_only_fe)[1]) - .y_null_pred]
  d2[, .clust       := as.character(get(clusterid))]
  clusters <- unique(d2$.clust)

  t_boot <- numeric(B)
  for (b in seq_len(B)) {
    w <- sample(c(-1, 1), length(clusters), replace = TRUE)
    map <- data.table(.clust = clusters, w = w)
    d2[, .w := map[.SD, on = ".clust", w]]
    d2[, .y_star := .y_null_pred + .w * .e_null]
    fmla_full_str <- as.character(fmla_full)
    rhs <- paste(fmla_full_str[3], collapse = " ")
    fmla_b <- as.formula(paste(".y_star ~", rhs))
    m_b <- feols(fmla_b, data = d2, cluster = as.formula(paste0("~", clusterid)))
    b_b  <- coef(m_b)[param]
    se_b <- sqrt(diag(vcov(m_b)))[param]
    t_boot[b] <- b_b / se_b
  }
  p_boot <- mean(abs(t_boot) >= abs(t_obs))
  ci_lo <- b_obs + quantile(t_boot, 0.025) * se_obs
  ci_hi <- b_obs + quantile(t_boot, 0.975) * se_obs
  list(coef = b_obs, se = se_obs, t = t_obs,
       p_boot = p_boot, ci_lo = ci_lo, ci_hi = ci_hi, B = B)
}

# Preferred FE: item + year + PBU
fmla_full_1 <- bid_price_log ~ admin | item_id + year_n + pbu_id
fmla_null_1 <- bid_price_log ~ 1 | item_id + year_n + pbu_id
cat("[1] preferred FE bootstrapping...\n")
boo1 <- bp_wild_cluster(d, fmla_full_1, fmla_null_1, B = 999L)
cat(sprintf("[1] preferred FE: p_boot=%.4f  CI=[%.4f, %.4f]  t_obs=%.3f\n",
            boo1$p_boot, boo1$ci_lo, boo1$ci_hi, boo1$t))
bp_log_step("preferred FE done", t0, LOG)

# Tightest: item x year-month + PBU
ym_col <- intersect(c("ym_id", "year_month", "yyyymm"), names(d))[1]
if (is.na(ym_col)) {
  if ("po_date" %in% names(d)) {
    d[, ym := format(as.Date(po_date), "%Y-%m")]
  } else {
    d[, ym := as.character(year_n)]
  }
} else {
  d[, ym := as.character(get(ym_col))]
}
d[, item_ym := paste(item_id, ym, sep = "_")]
fmla_full_2 <- bid_price_log ~ admin | item_ym + pbu_id
fmla_null_2 <- bid_price_log ~ 1 | item_ym + pbu_id
cat("[2] item-x-ym FE bootstrapping...\n")
boo2 <- bp_wild_cluster(d, fmla_full_2, fmla_null_2, B = 999L)
cat(sprintf("[2] item-x-ym FE: p_boot=%.4f  CI=[%.4f, %.4f]  t_obs=%.3f\n",
            boo2$p_boot, boo2$ci_lo, boo2$ci_hi, boo2$t))
bp_log_step("item-x-ym FE done", t0, LOG)

res <- data.table(
  spec = c("Preferred (item + year + PBU)", "Tightest (item x ym + PBU)"),
  coef = c(boo1$coef, boo2$coef),
  asy_se = c(boo1$se, boo2$se),
  t_obs = c(boo1$t, boo2$t),
  p_boot = c(boo1$p_boot, boo2$p_boot),
  ci_lo = c(boo1$ci_lo, boo2$ci_lo),
  ci_hi = c(boo1$ci_hi, boo2$ci_hi),
  B = c(boo1$B, boo2$B)
)
fwrite(res, file.path(OUT, "tables", "tab_utg_boottest.csv"))
print(res)

bp_macros_emit("44_wild_bootstrap", list(
  utgBoottestPval     = bp_fmt(boo1$p_boot, digits = 4),
  utgBoottestCIlow    = bp_fmt(boo1$ci_lo),
  utgBoottestCIhigh   = bp_fmt(boo1$ci_hi),
  utgBoottestB        = bp_fmt_int(boo1$B),
  utgBoottestPvalIYM  = bp_fmt(boo2$p_boot, digits = 4),
  utgBoottestCIlowIYM = bp_fmt(boo2$ci_lo),
  utgBoottestCIhighIYM= bp_fmt(boo2$ci_hi)
))
bp_log_step("done", t0, LOG)
