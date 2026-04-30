# ============================================================================
# 29_power_roadmap.R — Prospective power roadmap (A5.1)
# Paper 3 v14
#
# For each null test in v14, compute the sample size (and equivalent
# years of additional data) needed to detect smaller effects with 80%
# power. Concretely: given current SE_current at sample N_current,
# what N_required is needed to achieve SE = target/2.80, where target
# is the effect size we'd like to be able to detect?
#
# SE scales as 1/sqrt(N). So:
#   N_required = N_current × (SE_current / SE_target)^2
#   Years equivalent = (N_required - N_current) / (N_current / 11)
#
# Targets considered: 1pp, 2pp, 3pp, 5pp, 10pp.
#
# Output:
#   output/power_roadmap/power_roadmap.csv
#   output/power_roadmap/fig_power_roadmap.pdf
# ============================================================================

cat("=== 29_power_roadmap.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "power_roadmap")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load MDE results from script 23 -------------------------------------
mde_path <- file.path(BASE, "output/mde_calculations/mde_summary.csv")
if (!file.exists(mde_path)) stop("Run 23_mde_calculations.R first")
mde <- fread(mde_path)

# Sample window: 11 years (2009-2019)
SAMPLE_YEARS <- 11

cat("\n  Current MDE summary (from script 23):\n")
print(mde[, .(test, coef, se, mde_80, n)])

# ---- Power roadmap: for each test × target, compute required N ----------
targets_pp <- c(1, 2, 3, 5, 10)
roadmap <- list()
for (i in seq_len(nrow(mde))) {
  row <- mde[i]
  for (target_pp in targets_pp) {
    target_se <- (target_pp / 100) / 2.80   # 80% power, two-sided α=0.05
    if (row$se <= target_se) {
      # Already detect at this level
      n_req <- row$n
      years_eq <- 0
      already <- TRUE
    } else {
      n_req <- row$n * (row$se / target_se)^2
      years_eq <- (n_req - row$n) / (row$n / SAMPLE_YEARS)
      already <- FALSE
    }
    roadmap[[length(roadmap) + 1]] <- data.table(
      test = row$test,
      current_se = row$se,
      current_n  = row$n,
      target_pp  = target_pp,
      n_required = n_req,
      n_multiplier = n_req / row$n,
      years_eq   = years_eq,
      already_detect = already
    )
  }
}
roadmap_dt <- rbindlist(roadmap)
fwrite(roadmap_dt, file.path(OUT, "power_roadmap.csv"))

cat("\n  ===== Power roadmap =====\n")
print(roadmap_dt[, .(test, target_pp,
                      mult = round(n_multiplier, 1),
                      years_eq = round(years_eq, 1),
                      already = already_detect)])

# ---- Plot: heatmap of (test × target) → years_eq -------------------------
plot_dt <- copy(roadmap_dt)
plot_dt[, test_short := gsub(", ", "\n", test, fixed = TRUE)]
plot_dt[, years_label := fcase(
  already_detect, "✓",
  years_eq < 1,   sprintf("%.1fy", years_eq),
  years_eq < 100, sprintf("%.0fy", years_eq),
  default = sprintf("%.0fy", years_eq)
)]
plot_dt[, log_years := pmin(log10(pmax(years_eq, 0.1)), 4)]

p <- ggplot(plot_dt, aes(x = factor(target_pp), y = test_short,
                          fill = log_years)) +
  geom_tile(color = "white") +
  geom_text(aes(label = years_label), size = 3.2, color = "gray20") +
  scale_fill_gradient2(low = "#5b8aa6", mid = "#fffbcc", high = "#d73027",
                       midpoint = 1, na.value = "white",
                       breaks = c(0, 1, 2, 3, 4),
                       labels = c("0y", "10y", "100y", "1ky", "10ky"),
                       name = "Additional\nyears needed\n(log scale)") +
  labs(x = "Target effect to detect (pp, 80% power)",
       y = NULL,
       title = "Prospective power roadmap: years needed to detect smaller effects",
       subtitle = "Cells show additional years of BEC-equivalent data required to achieve 80% power") +
  theme_bw() +
  theme(panel.grid = element_blank())

ggsave(file.path(OUT, "fig_power_roadmap.pdf"), p,
       width = 10, height = 5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_power_roadmap.pdf")))

# ---- Narrative summary for the paper -------------------------------------
cat("\n  Narrative summary for §9:\n")
for (i in seq_len(nrow(mde))) {
  row <- mde[i]
  cat(sprintf("\n  TEST: %s\n", row$test))
  cat(sprintf("    Current: coef=%+.4f (SE=%.4f, n=%s)\n",
              row$coef, row$se, format(row$n, big.mark=",")))
  cat(sprintf("    MDE (80%% power): ±%.2f pp\n", row$mde_80 * 100))

  # What targets are within reach?
  reach <- roadmap_dt[test == row$test & already_detect]
  if (nrow(reach) > 0) {
    cat(sprintf("    Already detects effects ≥ %d pp\n", min(reach$target_pp)))
  }
  for (tp in c(1, 2)) {
    rr <- roadmap_dt[test == row$test & target_pp == tp][1]
    if (!rr$already_detect) {
      cat(sprintf("    To detect %d pp effect: need %.0fx sample size (~%.0f more years)\n",
                  tp, rr$n_multiplier, rr$years_eq))
    }
  }
}

cat("\n  Done.\n")
