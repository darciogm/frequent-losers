# Layer 1 / Track C --- Heckman parametric selection model on the UTG.
#
# First stage (probit on the urgent panel): probability of admin-channel
# acceptance as a function of pre-period item characteristics that proxy
# for the SES/SP scientific committee's cost-effectiveness criteria.
# Second stage: log neg price on Admin + inverse Mills ratio + item, year,
# PBU FE.
#
# The first-stage covariates use information observed *before* the
# urgent purchase: the item's mean reference price in its pre-treatment
# ordinary purchases, SUS-formulary status, modality (sealed-bid vs reverse
# auction), and historical supplier-base depth. These map naturally to the
# committee's criteria (essentiality, cost, sourceability) without being
# downstream of the regime under study.
#
# Output:
#   - tab_utg_heckman.tex
#   - macros: BPutgHeckmanCoef, BPutgHeckmanSE, BPutgHeckmanRho,
#             BPutgHeckmanLambda, BPutgHeckmanLambdaSE,
#             BPutgFirstStageN, BPutgFirstStagePseudoR, BPutgPointBounded,
#             BPutgPointBoundedCIlow, BPutgPointBoundedCIhigh

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(sampleSelection)
  library(kableExtra)
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
LOG  <- file.path(LOGS, "41_utg_heckman.log")
writeLines(sprintf("# 41_utg_heckman | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# ---- pre-period item characteristics (committee's information set) ----
# For each item, compute the mean log reference price and modality share
# from purchases observed BEFORE the item's first urgent purchase.
first_urg <- dt[purchase_type %in% c(1, 2),
                .(first_urg_year = min(year_n, na.rm = TRUE)), by = item]
dt2 <- merge(dt, first_urg, by = "item", all.x = TRUE)
pre_period <- dt2[purchase_type == 0L & year_n < first_urg_year,
                  .(pre_mean_logref = mean(bid_price_ref_log, na.rm = TRUE),
                    pre_n_orders    = .N,
                    pre_mean_qty    = mean(bid_qty, na.rm = TRUE),
                    pre_mean_firms  = mean(n_firms_bids, na.rm = TRUE)),
                  by = item]
cat("Items with pre-period data:", nrow(pre_period), "\n")

# UTG sample
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]
d <- merge(d, pre_period, by = "item", all.x = TRUE)
d <- d[!is.na(pre_mean_logref) & !is.na(pre_mean_qty)]

# SUS formulary indicator: presence of either has_sus or in_sus column
sus_var <- intersect(c("sus_basic", "has_sus", "in_sus"), names(d))[1]
if (!is.na(sus_var)) d[, sus := as.integer(get(sus_var) == 1L)] else d[, sus := NA_integer_]

cat("Heckman sample N:", nrow(d), "\n")

# ---- first stage: probit on Admin = 1 ----
# Identification of the selection equation requires at least one variable
# affecting the selection probability but excluded from the outcome
# equation. We use pre_n_orders (frequency of pre-urgent ordinary
# purchases): a high pre-urgent order frequency proxies for the
# committee's perception that the item is routinely sourceable, raising
# admin-channel acceptance probability, while not directly affecting the
# urgent price formation given item, year, PBU FE.
fs_form <- admin ~ pre_mean_logref + pre_mean_qty + pre_mean_firms +
                   pre_n_orders + sus
# drop rows with NA in any first-stage covariate up front so the row counts
# of d and m_fs's design match (glm silently drops them otherwise)
fs_vars <- c("admin", "pre_mean_logref", "pre_mean_qty", "pre_mean_firms",
             "pre_n_orders", "sus", "bid_price_log", "item_id", "year_n", "pbu_id")
d <- d[complete.cases(d[, ..fs_vars])]
cat("Heckman complete-cases sample N:", nrow(d), "\n")

m_fs <- glm(fs_form, data = d, family = binomial("probit"))
cat("First-stage probit summary:\n"); print(summary(m_fs))
xb <- predict(m_fs, newdata = d, type = "link")
d[, mills := ifelse(admin == 1L,
                    dnorm(xb) / pnorm(xb),
                    -dnorm(xb) / (1 - pnorm(xb)))]
fs_n <- nobs(m_fs)
fs_r2 <- 1 - m_fs$deviance / m_fs$null.deviance  # McFadden pseudo-R^2
bp_log_step("first stage done", t0, LOG)

# ---- second stage: log price ~ admin + mills + FE ----
m_ss <- feols(bid_price_log ~ admin + mills | item_id + year_n + pbu_id,
              data = d, cluster = ~pbu_id)
b_ss   <- coef(m_ss)["admin"]
se_ss  <- sqrt(diag(vcov(m_ss)))["admin"]
b_mil  <- coef(m_ss)["mills"]
se_mil <- sqrt(diag(vcov(m_ss)))["mills"]
bp_log_step("second stage done", t0, LOG)

# rho cross-check via full ML using sampleSelection::heckit (no FE; sanity check)
m_heckit <- tryCatch(
  heckit(selection = fs_form,
         outcome   = bid_price_log ~ admin + factor(year_n) + factor(pbu_id),
         data = d, method = "ml"),
  error = function(e) NULL
)
rho_hat <- if (!is.null(m_heckit)) m_heckit$estimate["rho"] else NA_real_

# ---- assemble bounded point estimate ----
# Heckman-corrected admin coefficient is the FE second-stage 'admin' coef.
# Translate into lit-vs-admin pct: (e^{-b_ss} - 1) * 100.
pct_corr <- (exp(-b_ss) - 1) * 100
ci_lo_log <- b_ss - 1.96 * se_ss
ci_hi_log <- b_ss + 1.96 * se_ss
ci_lo_pct <- (exp(-ci_hi_log) - 1) * 100
ci_hi_pct <- (exp(-ci_lo_log) - 1) * 100

cat(sprintf("Heckman-corrected UTG: b=%.4f (SE=%.4f) -> lit-vs-admin pct = %.2f%% [%.2f, %.2f]\n",
            b_ss, se_ss, pct_corr, ci_lo_pct, ci_hi_pct))

# Output table
res <- data.table(
  row = c("First stage: pre-period log ref price",
          "First stage: pre-period mean qty",
          "First stage: pre-period mean firms",
          "First stage: pre-period n orders (excl)",
          "First stage: SUS formulary",
          "Second stage: Admin coef",
          "Second stage: inverse Mills ratio",
          "Second stage: implied lit-over-admin (\\%)",
          "Heckit ML: rho"),
  coef = c(coef(m_fs)["pre_mean_logref"], coef(m_fs)["pre_mean_qty"],
           coef(m_fs)["pre_mean_firms"], coef(m_fs)["pre_n_orders"],
           coef(m_fs)["sus"],
           b_ss, b_mil, pct_corr, rho_hat),
  se = c(sqrt(diag(vcov(m_fs)))["pre_mean_logref"],
         sqrt(diag(vcov(m_fs)))["pre_mean_qty"],
         sqrt(diag(vcov(m_fs)))["pre_mean_firms"],
         sqrt(diag(vcov(m_fs)))["pre_n_orders"],
         sqrt(diag(vcov(m_fs)))["sus"],
         se_ss, se_mil, NA, NA)
)
ktab <- kbl(res, format = "latex", booktabs = TRUE, digits = 3,
            col.names = c("Term", "Estimate", "SE"),
            label = "tab:utg_heckman",
            caption = "Heckman selection-corrected UTG estimate.",
            escape = FALSE) |>
  footnote(general = paste(
    "First stage: probit of admin on pre-period item characteristics.",
    "pre\\_n\\_orders is excluded from the outcome equation as the exclusion",
    "restriction. Second stage: feols with item, year, and PBU FE; Mills",
    "ratio constructed from the first-stage prediction. Standard errors",
    "clustered at the PBU level. Heckit ML rho reported as a sanity",
    "cross-check; identification of rho without FE is fragile."),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_utg_heckman.tex"))

bp_macros_emit("41_utg_heckman", list(
  utgHeckmanCoef            = bp_fmt(b_ss),
  utgHeckmanSE              = bp_fmt(se_ss),
  utgHeckmanRho             = if (is.na(rho_hat)) "n/a" else bp_fmt(rho_hat),
  utgHeckmanLambda          = bp_fmt(b_mil),
  utgHeckmanLambdaSE        = bp_fmt(se_mil),
  utgFirstStageN            = bp_fmt_int(fs_n),
  utgFirstStagePseudoR           = bp_fmt(fs_r2),
  utgPointBounded           = bp_fmt_pct(pct_corr),
  utgPointBoundedCIlow      = bp_fmt_pct(ci_lo_pct),
  utgPointBoundedCIhigh     = bp_fmt_pct(ci_hi_pct)
))
bp_log_step("done", t0, LOG)
