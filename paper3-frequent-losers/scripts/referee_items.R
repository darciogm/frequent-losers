# ============================================================================
# referee_items.R — Four estimation items requested by referees
# ============================================================================

cat("=== Referee estimation items ===\n")

.script_dir <- "scripts"
source(file.path(.script_dir, "utils.R"), local = TRUE)

dt  <- readRDS(DATA_CACHE)
fls <- readRDS(DATA_CACHE_FLS)
ftm <- readRDS(DATA_CACHE_FTM)
fp  <- readRDS(DATA_CACHE_FP)
cat("  dt:", pfmt_int(nrow(dt)), "rows\n")
cat("  ftm:", pfmt_int(nrow(ftm)), "rows\n")
cat("  fls:", pfmt_int(nrow(fls)), "firms\n")

# Rename columns for convenience
setnames(fls, "códigofornecedor", "cnpj", skip_absent = TRUE)
setnames(ftm, c("códigofornecedor", "numerodaoc", "códigoitem"),
         c("cnpj", "oc_code", "item_code"), skip_absent = TRUE)

# Always-losers
al_cnpjs <- fls[always_loser == TRUE]$cnpj
cat("  Always-losers:", length(al_cnpjs), "\n")

# FL threshold (from freq_particip)
setnames(fp, "códigofornecedor", "cnpj", skip_absent = TRUE)
# The FL definition: always-loser with tenders_count > median + 1.5*IQR
al_stats <- fls[always_loser == TRUE]
med_tc <- median(al_stats$total_participations)
iqr_tc <- IQR(al_stats$total_participations)
thresh <- med_tc + 1.5 * iqr_tc
fl_cnpjs <- al_stats[total_participations > thresh]$cnpj
cat("  FL threshold:", round(thresh), " FL firms:", length(fl_cnpjs), "\n")

# Build tender-level FL flag from ftm
# Join key between dt and ftm: oc_code + item_code
ftm[, is_fl := as.integer(cnpj %in% fl_cnpjs)]
fl_by_tender <- ftm[, .(n_fl = sum(is_fl)), by = .(oc_code, item_code)]
fl_by_tender[, has_fl := as.integer(n_fl > 0)]

# ============================================================================
# ITEM 1: Cross-fit decomposition
# ============================================================================
cat("\n--- ITEM 1: Cross-fit decomposition ---\n")

# Extract year from oc_code (chars 12-15)
ftm[, year := as.integer(substr(oc_code, 12, 15))]

# Odd-year firm stats
ftm_odd <- ftm[year %% 2 == 1]
firm_stats_odd <- ftm_odd[, .(
  tc_odd = .N,
  wins_odd = sum(won, na.rm = TRUE)
), by = cnpj]
firm_stats_odd[, wr_odd := wins_odd / tc_odd]

# Always-losers in odd years
al_odd <- firm_stats_odd[wr_odd == 0]
med_odd <- median(al_odd$tc_odd)
iqr_odd <- IQR(al_odd$tc_odd)
thresh_odd <- med_odd + 1.5 * iqr_odd
fl_odd <- al_odd[tc_odd > thresh_odd]$cnpj
cat("  Odd-year FL firms:", length(fl_odd), " (threshold:", round(thresh_odd), ")\n")

# Apply odd-year FL list to FULL sample
ftm[, is_fl_odd := as.integer(cnpj %in% fl_odd)]
fl_odd_by_tender <- ftm[, .(n_fl_odd = sum(is_fl_odd)), by = .(oc_code, item_code)]
fl_odd_by_tender[, losers_odd := as.integer(n_fl_odd > 0)]

# Merge onto dt
dt_decomp <- copy(dt)
dt_decomp[fl_odd_by_tender, losers_odd := i.losers_odd,
          on = .(oc_code, item_code)]
dt_decomp[is.na(losers_odd), losers_odd := 0L]

m_decomp <- feols(
  lneg_price ~ losers_odd + convite | item_f + year_f + pbu_f,
  data = dt_decomp[!is.na(lneg_price)],
  cluster = ~item_f, fixef.rm = "none"
)

b1 <- coef(m_decomp)["losers_odd"]
se1 <- sqrt(vcov(m_decomp)["losers_odd", "losers_odd"])
cat("  Odd-year FL list on full sample:\n")
cat("    coeff =", pfmt(b1, 4), " SE =", pfmt(se1, 4),
    " N =", pfmt_int(m_decomp$nobs), "\n")
cat("  Comparison: baseline OLS = 0.0636, cross-fit avg = 0.036\n")
cat("  If close to 0.06 → noise explains most of attenuation\n")
cat("  If close to 0.04 → mechanical link explains most\n")

# ============================================================================
# ITEM 2: AUC bootstrap 95% CI
# ============================================================================
cat("\n--- ITEM 2: AUC bootstrap 95% CI ---\n")

# Use fp dataset which has always-losers and their tenders_count
# Need CADE co-participation flag
cade_file1 <- file.path(DATA_PROC, "..", "cade_fl_cobidders.csv")
cade_file2 <- file.path(DATA_PROC, "cade_fl_cobidders.csv")
cade_file3 <- file.path(BASE, "data", "cade_fl_cobidders.csv")

cade_path <- NULL
for (f in c(cade_file1, cade_file2, cade_file3)) {
  if (file.exists(f)) { cade_path <- f; break }
}

if (!is.null(cade_path)) {
  cade_fl <- fread(cade_path)
  setnames(cade_fl, "códigofornecedor", "cnpj", skip_absent = TRUE)
  if (!"cnpj" %in% names(cade_fl)) setnames(cade_fl, names(cade_fl)[1], "cnpj")
  cat("  CADE FL co-bidders:", nrow(cade_fl), "\n")

  al_roc <- copy(al_stats)
  al_roc[, cade := as.integer(cnpj %in% cade_fl$cnpj)]

  suppressPackageStartupMessages(library(pROC))
  roc_obj <- roc(al_roc$cade, al_roc$total_participations,
                 quiet = TRUE, direction = "<")

  set.seed(42)
  ci_result <- ci.auc(roc_obj, method = "bootstrap", boot.n = 1000,
                       conf.level = 0.95, progress = "none")

  cat("  AUC:", pfmt(auc(roc_obj), 3), "\n")
  cat("  95% Bootstrap CI: [", pfmt(ci_result[1], 3), ",",
      pfmt(ci_result[3], 3), "]\n")
  cat("  N pos:", sum(al_roc$cade), " N neg:", sum(1 - al_roc$cade), "\n")
} else {
  cat("  CADE file not found. Searching...\n")
  cade_files <- list.files(BASE, pattern = "cade", recursive = TRUE, full.names = TRUE)
  cat("  Found:", paste(cade_files, collapse = "\n  "), "\n")

  # Alternative: use cade_bec_crossmatch.csv
  xm_path <- NULL
  for (f in cade_files) {
    if (grepl("crossmatch", f)) { xm_path <- f; break }
  }
  if (!is.null(xm_path)) {
    xm <- fread(xm_path)
    cat("  Using crossmatch file:", xm_path, "\n")
    cat("  Cols:", paste(names(xm), collapse = ", "), "\n")

    # Get CADE firms' CNPJs
    setnames(xm, old = names(xm)[grep("cnpj|forn|CNPJ", names(xm), ignore.case=TRUE)[1]],
             new = "cnpj", skip_absent = TRUE)

    # Find FL firms that co-participate with these CADE firms
    cade_cnpjs <- unique(xm$cnpj)
    # Tenders with CADE firms
    cade_tenders <- ftm[cnpj %in% cade_cnpjs, .(oc_code, item_code)]
    cade_tenders <- unique(cade_tenders)
    # Firms in those tenders
    firms_in_cade_tenders <- ftm[cade_tenders, on = .(oc_code, item_code), nomatch = 0]
    cobid_cnpjs <- unique(firms_in_cade_tenders[cnpj %in% al_cnpjs]$cnpj)

    al_roc <- copy(al_stats)
    al_roc[, cade := as.integer(cnpj %in% cobid_cnpjs)]

    suppressPackageStartupMessages(library(pROC))
    roc_obj <- roc(al_roc$cade, al_roc$total_participations,
                   quiet = TRUE, direction = "<")

    set.seed(42)
    ci_result <- ci.auc(roc_obj, method = "bootstrap", boot.n = 1000,
                         conf.level = 0.95, progress = "none")

    cat("  AUC:", pfmt(auc(roc_obj), 3), "\n")
    cat("  95% Bootstrap CI: [", pfmt(ci_result[1], 3), ",",
        pfmt(ci_result[3], 3), "]\n")
    cat("  N pos:", sum(al_roc$cade), " N neg:", sum(1 - al_roc$cade), "\n")
  } else {
    cat("  No CADE data found. Skipping AUC.\n")
  }
}

# ============================================================================
# ITEM 3: Continuous FL measure
# ============================================================================
cat("\n--- ITEM 3: Continuous FL measure ---\n")

# Among always-loser participants in each tender: max participation count
ftm_al <- ftm[cnpj %in% al_cnpjs]
ftm_al <- merge(ftm_al, fls[, .(cnpj, total_participations)], by = "cnpj")

fl_intensity <- ftm_al[, .(
  max_al_tc = max(total_participations, na.rm = TRUE),
  log_max_al = log(max(total_participations, na.rm = TRUE))
), by = .(oc_code, item_code)]

dt_cont <- copy(dt)
dt_cont[fl_intensity, `:=`(max_al_tc = i.max_al_tc, log_max_al = i.log_max_al),
        on = .(oc_code, item_code)]
dt_cont[is.na(max_al_tc), `:=`(max_al_tc = 0, log_max_al = 0)]

m_cont <- feols(
  lneg_price ~ log_max_al + convite | item_f + year_f + pbu_f,
  data = dt_cont[!is.na(lneg_price)],
  cluster = ~item_f, fixef.rm = "none"
)

b3 <- coef(m_cont)["log_max_al"]
se3 <- sqrt(vcov(m_cont)["log_max_al", "log_max_al"])
cat("  Continuous measure (log max always-loser participations):\n")
cat("    coeff =", pfmt(b3, 4), " SE =", pfmt(se3, 4),
    " N =", pfmt_int(m_cont$nobs), "\n")

# ============================================================================
# ITEM 4: Placebo FL classification (100 iterations)
# ============================================================================
cat("\n--- ITEM 4: Placebo FL classification ---\n")

set.seed(12345)
n_fl <- length(fl_cnpjs)
n_iter <- 100

placebo_coefs <- numeric(n_iter)

for (i in seq_len(n_iter)) {
  fake_fl <- sample(al_cnpjs, n_fl)
  ftm[, is_fake := as.integer(cnpj %in% fake_fl)]
  fake_by <- ftm[, .(n_fake = sum(is_fake)), by = .(oc_code, item_code)]
  fake_by[, losers_fake := as.integer(n_fake > 0)]

  dt_p <- copy(dt)
  dt_p[, losers_fake := 0L]
  dt_p[fake_by, losers_fake := i.losers_fake, on = .(oc_code, item_code)]

  m_p <- feols(
    lneg_price ~ losers_fake + convite | item_f + year_f + pbu_f,
    data = dt_p[!is.na(lneg_price)],
    cluster = ~item_f, fixef.rm = "none", lean = TRUE
  )
  placebo_coefs[i] <- coef(m_p)["losers_fake"]
  if (i %% 25 == 0) cat("    Iteration", i, "/", n_iter, "\n")
}

cat("  Placebo mean:", pfmt(mean(placebo_coefs), 4), "\n")
cat("  Placebo SD:", pfmt(sd(placebo_coefs), 4), "\n")
cat("  Placebo range: [", pfmt(min(placebo_coefs), 4), ",",
    pfmt(max(placebo_coefs), 4), "]\n")
cat("  Actual FL: 0.0636\n")
cat("  p(placebo >= actual):", pfmt(mean(placebo_coefs >= 0.0636), 4), "\n")

cat("\n=== Done ===\n")
