# V7 Coefficient Plots
# Output: 2 PDF figures in v4/pub/figures/


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
source(file.path(.this_dir, "utils.R"))

library(ggplot2)

PUB_FIG <- file.path(V4, "pub", "figures")
CHECKPOINT <- file.path(V4, "checkpoints_v7")

# Helper: extract coef from preferred spec (Item+Year+PBU)
extract_coef <- function(models, var, label) {
  m <- models[["Item+Year+PBU"]]
  b  <- coef(m)[var]
  se_val <- se(m)[var]
  data.frame(
    label  = label,
    coef   = b,
    se     = se_val,
    ci90_lo = b - 1.645 * se_val,
    ci90_hi = b + 1.645 * se_val,
    ci95_lo = b - 1.96  * se_val,
    ci95_hi = b + 1.96  * se_val,
    stringsAsFactors = FALSE
  )
}

# Grayscale theme for publication
theme_pub <- function(base_size = 9) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.ticks = element_line(linewidth = 0.3),
      legend.position = "none",
      plot.title = element_text(face = "bold", size = base_size + 1),
      plot.subtitle = element_text(size = base_size - 1, color = "gray40"),
      axis.title.x = element_text(size = base_size),
      axis.title.y = element_blank()
    )
}

# FIGURE 1: Under the Gun — Extended Outcomes (Task 1)
cat("Figure: UTG Extended Outcomes (Task 1)\n")

t1_ref     <- readRDS(file.path(CHECKPOINT, "t1_ref_total.rds"))
t1_qty     <- readRDS(file.path(CHECKPOINT, "t1_qty_total.rds"))
t1_firms   <- readRDS(file.path(CHECKPOINT, "t1_firms.rds"))
t1_success <- readRDS(file.path(CHECKPOINT, "t1_success.rds"))

# Also load original UTG neg price results for comparison
dt_raw <- readRDS(DATA_CACHE)
dt_raw <- dt_raw[has_litigated == TRUE & has_ordinary == TRUE]
dt <- copy(dt_raw)
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
dt_utg_win <- dt_utg[po_firm_winner == 1]

t10a_orig <- run_feols4("bid_price_log", "is_admin", dt_utg_win, cluster = ~pbu_id)

df_t1 <- rbind(
  extract_coef(t1_ref,            "is_admin", "Reference Price"),
  extract_coef(t1_qty,            "is_admin", "Quantity"),
  extract_coef(t10a_orig,         "is_admin", "Negotiated Price"),
  extract_coef(t1_firms$total,    "is_admin", "N. Firms"),
  extract_coef(t1_success$total,  "is_admin", "Tender Success")
)
df_t1$label <- factor(df_t1$label, levels = rev(df_t1$label))

p1 <- ggplot(df_t1, aes(x = coef, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_linerange(aes(xmin = ci95_lo, xmax = ci95_hi), linewidth = 0.6, color = "gray60") +
  geom_linerange(aes(xmin = ci90_lo, xmax = ci90_hi), linewidth = 1.2, color = "gray30") +
  geom_point(size = 2.5, color = "black") +
  labs(
    title = "Under the Gun: Administrative vs. Litigated",
    subtitle = "Preferred specification (Item + Year + PBU FE). Inner bars: 90% CI; Outer bars: 95% CI.",
    x = "Coefficient (log scale / pp)"
  ) +
  theme_pub()

cairo_pdf(file.path(PUB_FIG, "fig_09_utg_coefplot_v7.pdf"),
          width = 6.5, height = 4)
print(p1)
dev.off()
cat("  Saved: fig_09_utg_coefplot_v7.pdf\n")

# FIGURE 2: Litigated vs Ordinary — All Outcomes (Task 2)
cat("Figure: Litigated vs Ordinary (Task 2)\n")

t2_ref     <- readRDS(file.path(CHECKPOINT, "t2_ref.rds"))
t2_qty     <- readRDS(file.path(CHECKPOINT, "t2_qty.rds"))
t2_neg     <- readRDS(file.path(CHECKPOINT, "t2_neg.rds"))
t2_firms   <- readRDS(file.path(CHECKPOINT, "t2_firms.rds"))
t2_success <- readRDS(file.path(CHECKPOINT, "t2_success.rds"))

df_t2 <- rbind(
  extract_coef(t2_ref,            "litigated", "Reference Price"),
  extract_coef(t2_qty,            "litigated", "Quantity"),
  extract_coef(t2_neg$total,      "litigated", "Neg. Price (total)"),
  extract_coef(t2_neg$direct,     "litigated", "Neg. Price (direct)"),
  extract_coef(t2_firms$total,    "litigated", "N. Firms (total)"),
  extract_coef(t2_firms$direct,   "litigated", "N. Firms (direct)"),
  extract_coef(t2_success$total,  "litigated", "Tender Success (total)"),
  extract_coef(t2_success$direct, "litigated", "Tender Success (direct)")
)
df_t2$label <- factor(df_t2$label, levels = rev(df_t2$label))

p2 <- ggplot(df_t2, aes(x = coef, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_linerange(aes(xmin = ci95_lo, xmax = ci95_hi), linewidth = 0.6, color = "gray60") +
  geom_linerange(aes(xmin = ci90_lo, xmax = ci90_hi), linewidth = 1.2, color = "gray30") +
  geom_point(size = 2.5, color = "black") +
  labs(
    title = "Litigated vs. Ordinary Purchases",
    subtitle = "Preferred specification (Item + Year + PBU FE). Inner bars: 90% CI; Outer bars: 95% CI.",
    x = "Coefficient (log scale / pp)"
  ) +
  theme_pub()

cairo_pdf(file.path(PUB_FIG, "fig_10_litigated_coefplot_v7.pdf"),
          width = 6.5, height = 4)
print(p2)
dev.off()
cat("  Saved: fig_10_litigated_coefplot_v7.pdf\n")

cat("\n17_v7_figures.R complete\n")
