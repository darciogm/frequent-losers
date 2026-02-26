# =============================================================================
# 09_pub_figures.R — Publication-ready figures
# Bitter Pills to Swallow — v4 (R/fixest)
# Output: v4/pub/figures/ (8 .pdf files, grayscale, 6.5x4in, cairo PDF)
# =============================================================================

cat("=== 09_pub_figures.R ===\n")
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

# --- Output directory --------------------------------------------------------
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# --- Publication settings ----------------------------------------------------
FIG_W <- 6.5   # width in inches (elsarticle 12pt page width)
FIG_H <- 4     # height in inches
BASE_SIZE <- 9  # font size

# Grayscale-safe palette
colors_3type <- c("Ordinary" = "black", "Administrative" = "gray40",
                  "Litigated" = "gray65")
lines_3type  <- c("Ordinary" = "solid", "Administrative" = "dashed",
                  "Litigated" = "dotted")

colors_2type <- c("Administrative" = "gray40", "Litigated" = "gray65")
lines_2type  <- c("Administrative" = "dashed", "Litigated" = "dotted")

colors_urg <- c("Ordinary" = "black", "Urgent" = "gray50")
lines_urg  <- c("Ordinary" = "solid", "Urgent" = "dashed")

# Publication theme
theme_pub <- function(base_size = BASE_SIZE) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.margin = margin(t = -2),
      plot.title = element_blank(),
      strip.text = element_text(face = "bold")
    )
}

# Save helper (cairo PDF for better font rendering)
save_pub <- function(plot, filename) {
  filepath <- file.path(PUB_FIG, filename)
  ggsave(filepath, plot, width = FIG_W, height = FIG_H, device = cairo_pdf)
  cat("  Saved:", filepath, "\n")
}

# --- Load data ---------------------------------------------------------------
cat("\n--- Loading data ---\n")
dt <- readRDS(DATA_CACHE)
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]

# Type labels
dt_win[, type_label := factor(
  ifelse(purchase_type == 0, "Ordinary",
         ifelse(purchase_type == 1, "Administrative", "Litigated")),
  levels = c("Ordinary", "Administrative", "Litigated")
)]
dt[, type_label := factor(
  ifelse(purchase_type == 0, "Ordinary",
         ifelse(purchase_type == 1, "Administrative", "Litigated")),
  levels = c("Ordinary", "Administrative", "Litigated")
)]

# =============================================================================
# Figure 1: Kernel Density — Log Reference Price
# =============================================================================
cat("Figure 1: Log reference price density\n")
p1 <- ggplot(dt_win[!is.na(bid_price_ref_log)],
             aes(x = bid_price_ref_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.6) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = lines_3type) +
  labs(x = "Log Reference Price", y = "Density") +
  theme_pub()
save_pub(p1, "fig_01_ref_price_density.pdf")

# =============================================================================
# Figure 2: Kernel Density — Log Negotiated Price
# =============================================================================
cat("Figure 2: Log negotiated price density\n")
p2 <- ggplot(dt_win[!is.na(bid_price_log)],
             aes(x = bid_price_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.6) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = lines_3type) +
  labs(x = "Log Negotiated Price", y = "Density") +
  theme_pub()
save_pub(p2, "fig_02_negprice_density.pdf")

# =============================================================================
# Figure 3: Kernel Density — Log Quantity
# =============================================================================
cat("Figure 3: Log quantity density\n")
p3 <- ggplot(dt_win[!is.na(bid_qty_log)],
             aes(x = bid_qty_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.6) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = lines_3type) +
  labs(x = "Log Quantity", y = "Density") +
  theme_pub()
save_pub(p3, "fig_03_qty_density.pdf")

# =============================================================================
# Figure 4: Kernel Density — Log Number of Bidding Firms
# =============================================================================
cat("Figure 4: Log firms density\n")
p4 <- ggplot(dt[!is.na(ln_n_firms)],
             aes(x = ln_n_firms, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.6) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = lines_3type) +
  labs(x = "Log Number of Bidding Firms", y = "Density") +
  theme_pub()
save_pub(p4, "fig_04_firms_density.pdf")

# =============================================================================
# Figure 5: Kernel Density — Admin vs Litigated (Urgent Only)
# =============================================================================
cat("Figure 5: UTG density (admin vs litigated)\n")
dt_urg_win <- dt_win[purchase_type %in% c(1, 2)]
p5 <- ggplot(dt_urg_win[!is.na(bid_price_log)],
             aes(x = bid_price_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.6) +
  scale_color_manual(values = colors_2type) +
  scale_linetype_manual(values = lines_2type) +
  labs(x = "Log Negotiated Price", y = "Density") +
  theme_pub()
save_pub(p5, "fig_05_utg_density.pdf")

# =============================================================================
# Figure 6: Bar Chart — Success Rate by Purchase Type
# =============================================================================
cat("Figure 6: Success rate bar chart\n")
success_dt <- dt[, .(success_rate = mean(po_firm_winner, na.rm = TRUE)), by = type_label]
p6 <- ggplot(success_dt, aes(x = type_label, y = success_rate, fill = type_label)) +
  geom_col(width = 0.6, color = "black", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.1f%%", success_rate * 100)),
            vjust = -0.5, size = 3) +
  scale_fill_manual(values = c("Ordinary" = "gray90", "Administrative" = "gray60",
                               "Litigated" = "gray30")) +
  scale_y_continuous(labels = scales::percent_format(), expand = expansion(mult = c(0, 0.12))) +
  labs(x = "", y = "Success Rate") +
  theme_pub() +
  theme(legend.position = "none")
save_pub(p6, "fig_06_success_bar.pdf")

# =============================================================================
# Figure 7: Time Trends — Mean Log Negotiated Price by Year-Month
# =============================================================================
cat("Figure 7: Time trends\n")
dt_win[, ym_date := as.Date(m_y)]
dt_win[, urg_label := ifelse(urgent == 1, "Urgent", "Ordinary")]

trends_dt <- dt_win[!is.na(bid_price_log),
                     .(mean_price = mean(bid_price_log, na.rm = TRUE)),
                     by = .(ym_date, urg_label)]

p7 <- ggplot(trends_dt, aes(x = ym_date, y = mean_price,
                              color = urg_label, linetype = urg_label)) +
  geom_line(linewidth = 0.5) +
  scale_color_manual(values = colors_urg) +
  scale_linetype_manual(values = lines_urg) +
  scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
  labs(x = "Year", y = "Mean Log Negotiated Price") +
  theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pub(p7, "fig_07_time_trends.pdf")

# =============================================================================
# Figure 8: Coefficient Plot — Treatment Effects from Tables 4-7
# =============================================================================
cat("Figure 8: Coefficient plot\n")

spec_fe <- "item_id + year_n + pbu_id"
m_t4  <- feols(as.formula(paste0("bid_price_ref_log ~ urgent | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)
m_t5  <- feols(as.formula(paste0("bid_qty_log ~ urgent | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)
m_t6a <- feols(as.formula(paste0("bid_price_log ~ urgent | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)
m_t6b <- feols(as.formula(paste0("bid_price_log ~ urgent + bid_qty_log | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)
m_t7a <- feols(as.formula(paste0("ln_n_firms ~ urgent | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)
m_t7b <- feols(as.formula(paste0("ln_n_firms ~ urgent + bid_qty_log | ", spec_fe)),
               data = dt_win, cluster = ~pbu_id)

extract_coef <- function(model, label) {
  b <- coef(model)["urgent"]
  se_val <- se(model)["urgent"]
  data.frame(table = label, coef = b, se = se_val,
             ci_lo = b - 1.96 * se_val, ci_hi = b + 1.96 * se_val,
             stringsAsFactors = FALSE)
}

coef_df <- rbind(
  extract_coef(m_t4,  "Ref. Price"),
  extract_coef(m_t5,  "Quantity"),
  extract_coef(m_t6a, "Neg. Price (Total)"),
  extract_coef(m_t6b, "Neg. Price (Direct)"),
  extract_coef(m_t7a, "Firms (Total)"),
  extract_coef(m_t7b, "Firms (Direct)")
)
coef_df$table <- factor(coef_df$table, levels = rev(coef_df$table))

p8 <- ggplot(coef_df, aes(y = table, x = coef, xmin = ci_lo, xmax = ci_hi)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray60") +
  geom_errorbar(width = 0.2, linewidth = 0.5, orientation = "y") +
  geom_point(size = 2.5, shape = 16) +
  labs(x = "Coefficient on Urgent Purchase", y = "") +
  theme_pub()
save_pub(p8, "fig_08_coefplot.pdf")

# =============================================================================
# SUMMARY
# =============================================================================
n_files <- length(list.files(PUB_FIG, pattern = "\\.pdf$"))
cat(sprintf("\n=== 09_pub_figures.R complete: %d .pdf files in %s ===\n", n_files, PUB_FIG))
