# ============================================================================
# 10_fl_characteristics.R — "Who Are Frequent Losers?"
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# Characterize FL firms using CNPJ registry data from Firms_final.parquet.
# Compares FL firms vs non-FL always-losers vs winners on:
#   - Firm size (porte_empresa)
#   - Firm age (data_inicio_atividade)
#   - Industry (cnae_resumido / secao_cnae)
#   - Geography (state, municipality concentration)
# ============================================================================

cat("=== 10_fl_characteristics.R: FL firm characterization ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages(library(scales))

# ---- Load data --------------------------------------------------------------
if (!file.exists(DATA_CACHE_FP)) stop("Run 01_clean.R first")
fp <- readRDS(DATA_CACHE_FP)

if (!file.exists(DATA_CACHE_FIRMS)) stop("Run 01_clean.R first")
firms <- readRDS(DATA_CACHE_FIRMS)

if (!file.exists(DATA_CACHE_FLS)) stop("Run 01_clean.R first (with bid-level data)")
fls <- readRDS(DATA_CACHE_FLS)

cat("  FREQ_PARTICIP rows:", pfmt_int(nrow(fp)), "\n")
cat("  Firms_final rows:", pfmt_int(nrow(firms)), "\n")
cat("  firm_loss_stats rows:", pfmt_int(nrow(fls)), "\n")

# ---- Normalize column names -------------------------------------------------
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

firms_col <- grep("fornecedor", names(firms), value = TRUE, ignore.case = TRUE)
if (length(firms_col) >= 1) {
  # Use the códigofornecedor column
  forn_col <- grep("^c.digofornecedor$", names(firms), value = TRUE, ignore.case = TRUE)
  if (length(forn_col) == 1) setnames(firms, forn_col, "firm_id")
}

fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
if (length(fls_col) == 1 && fls_col != "firm_id") setnames(fls, fls_col, "firm_id")

# ---- Compute IQR threshold and classify firms -------------------------------
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val  # median + 1.5*IQR

fl_ids <- fp[tenders_count > threshold, firm_id]
non_fl_al_ids <- fp[tenders_count <= threshold, firm_id]

cat(sprintf("  IQR threshold (median + 1.5*IQR): %.0f\n", threshold))
cat(sprintf("  FL firms: %s, Non-FL always-losers: %s\n",
            pfmt_int(length(fl_ids)), pfmt_int(length(non_fl_al_ids))))

# Winner firms = firms in fls that are NOT always-losers
winner_ids <- fls[always_loser == 0, firm_id]
cat(sprintf("  Winner firms (at least 1 win): %s\n", pfmt_int(length(winner_ids))))

# ---- Merge with Firms_final ------------------------------------------------
firms[, group := fifelse(firm_id %chin% fl_ids, "FL",
                  fifelse(firm_id %chin% non_fl_al_ids, "Non-FL Always-Losers",
                  fifelse(firm_id %chin% winner_ids, "Winners", "Other")))]

firms_classified <- firms[group != "Other"]
cat("  Firms matched to a group:", pfmt_int(nrow(firms_classified)), "\n")
cat("  Group distribution:\n")
print(firms_classified[, .N, by = group][order(-N)])

# ---- Firm age ---------------------------------------------------------------
cat("  Computing firm age...\n")
firms_classified[, start_date := as.Date(data_inicio_atividade, format = "%Y-%m-%d")]
# If that fails, try other formats
if (sum(!is.na(firms_classified$start_date)) < nrow(firms_classified) * 0.3) {
  firms_classified[, start_date := as.Date(data_inicio_atividade, format = "%d/%m/%Y")]
}
firms_classified[, firm_age_years := as.numeric(difftime(as.Date("2019-12-31"),
                                                          start_date, units = "days")) / 365.25]
firms_classified[firm_age_years < 0 | firm_age_years > 200, firm_age_years := NA_real_]

# ---- Generate summary table -------------------------------------------------
cat("  Generating characteristics summary...\n")

# Helper: compute summary stats for a group
group_summary <- function(dt, grp) {
  sub <- dt[group == grp]
  n <- nrow(sub)

  # Firm size distribution
  size_tab <- sub[!is.na(porte_empresa), .N, by = porte_empresa]
  size_tab[, pct := N / sum(N) * 100]

  # Firm age
  age_mean <- mean(sub$firm_age_years, na.rm = TRUE)
  age_sd   <- sd(sub$firm_age_years, na.rm = TRUE)

  # Geography: % in SP
  sp_pct <- if ("fornec_estado_SP" %in% names(sub)) {
    mean(sub$fornec_estado_SP, na.rm = TRUE) * 100
  } else {
    sp_count <- sum(grepl("SP|S.o Paulo", sub$descriçãouffornecedor, ignore.case = TRUE), na.rm = TRUE)
    sp_count / n * 100
  }

  # Municipality diversity
  n_munic <- uniqueN(sub$descriçãomunicípiofornecedor[!is.na(sub$descriçãomunicípiofornecedor)])

  # Top CNAE sector
  cnae_tab <- sub[!is.na(cnae_resumido) & cnae_resumido != "", .N, by = cnae_resumido][order(-N)]

  list(
    n = n,
    size_tab = size_tab,
    age_mean = age_mean, age_sd = age_sd,
    sp_pct = sp_pct, n_munic = n_munic,
    cnae_tab = cnae_tab
  )
}

groups <- c("FL", "Non-FL Always-Losers", "Winners")
summaries <- lapply(groups, function(g) group_summary(firms_classified, g))
names(summaries) <- groups

# ---- Write LaTeX table -------------------------------------------------------
cat("  Writing tab_fl_characteristics.tex...\n")

lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Characteristics of Frequent Losers vs.\\ Other Firms}",
  "\\label{tab:fl_characteristics}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & FL & Non-FL Always-Losers & Winners \\\\",
  "\\midrule"
)

# Number of firms
lines <- c(lines, sprintf("Number of firms & %s & %s & %s \\\\",
  pfmt_int(summaries[["FL"]]$n),
  pfmt_int(summaries[["Non-FL Always-Losers"]]$n),
  pfmt_int(summaries[["Winners"]]$n)
))

# Firm age
lines <- c(lines, "\\midrule", "\\multicolumn{4}{l}{\\textit{Firm Age (years)}} \\\\")
lines <- c(lines, sprintf("Mean (SD) & %s (%s) & %s (%s) & %s (%s) \\\\",
  pfmt(summaries[["FL"]]$age_mean, 1), pfmt(summaries[["FL"]]$age_sd, 1),
  pfmt(summaries[["Non-FL Always-Losers"]]$age_mean, 1),
  pfmt(summaries[["Non-FL Always-Losers"]]$age_sd, 1),
  pfmt(summaries[["Winners"]]$age_mean, 1), pfmt(summaries[["Winners"]]$age_sd, 1)
))

# Firm size distribution
lines <- c(lines, "\\midrule", "\\multicolumn{4}{l}{\\textit{Firm Size (\\%)}} \\\\")
all_sizes <- unique(firms_classified[!is.na(porte_empresa), porte_empresa])
for (sz in sort(all_sizes)) {
  vals <- sapply(groups, function(g) {
    row <- summaries[[g]]$size_tab[porte_empresa == sz]
    if (nrow(row) > 0) pfmt(row$pct, 1) else "0.0"
  })
  lines <- c(lines, sprintf("%s & %s & %s & %s \\\\", sz, vals[1], vals[2], vals[3]))
}

# Geography
lines <- c(lines, "\\midrule", "\\multicolumn{4}{l}{\\textit{Geography}} \\\\")
lines <- c(lines, sprintf("\\%% in S\\~{a}o Paulo & %s & %s & %s \\\\",
  pfmt(summaries[["FL"]]$sp_pct, 1),
  pfmt(summaries[["Non-FL Always-Losers"]]$sp_pct, 1),
  pfmt(summaries[["Winners"]]$sp_pct, 1)
))
lines <- c(lines, sprintf("Unique municipalities & %s & %s & %s \\\\",
  pfmt_int(summaries[["FL"]]$n_munic),
  pfmt_int(summaries[["Non-FL Always-Losers"]]$n_munic),
  pfmt_int(summaries[["Winners"]]$n_munic)
))

# Top CNAE sectors (top 3 for FL firms)
lines <- c(lines, "\\midrule", "\\multicolumn{4}{l}{\\textit{Top Industry Sectors (FL firms)}} \\\\")
top_cnae <- summaries[["FL"]]$cnae_tab
if (nrow(top_cnae) > 0) {
  top3 <- head(top_cnae, 3)
  fl_total <- summaries[["FL"]]$cnae_tab[, sum(N)]
  for (i in seq_len(nrow(top3))) {
    lines <- c(lines, sprintf("%s & %s\\%% & & \\\\",
      top3$cnae_resumido[i], pfmt(top3$N[i] / fl_total * 100, 1)))
  }
}

lines <- c(lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} FL = Frequent Losers (always-losers above the IQR threshold).",
  "Non-FL Always-Losers = firms that never won but below the threshold.",
  "Winners = firms with at least one win.",
  "Firm characteristics from CNPJ registry (Firms\\_final.parquet).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_fl_characteristics.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_fl_characteristics.tex"), "\n")

# ---- Figure: Firm size distribution by group ---------------------------------
cat("  Generating fig_fl_size_distribution.pdf...\n")

size_data <- firms_classified[!is.na(porte_empresa),
  .N, by = .(group, porte_empresa)]
size_data[, total := sum(N), by = group]
size_data[, pct := N / total * 100]
size_data[, group := factor(group, levels = c("FL", "Non-FL Always-Losers", "Winners"))]

p_size <- ggplot(size_data, aes(x = porte_empresa, y = pct, fill = group)) +
  geom_col(position = "dodge", color = "gray30", linewidth = 0.3) +
  scale_fill_manual(values = c("FL" = "gray30",
                                "Non-FL Always-Losers" = "gray60",
                                "Winners" = "gray85")) +
  labs(x = "Firm Size Category", y = "Percentage of Firms (%)") +
  theme_pub() +
  theme(legend.position = "bottom")

save_pub(p_size, "fig_fl_size_distribution.pdf")

cat("  Done.\n")
