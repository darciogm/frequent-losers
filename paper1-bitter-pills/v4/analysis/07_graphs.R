# Publication-quality figures

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

# Load data
dt <- readRDS(DATA_CACHE)

# Analysis sample
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]

# Color palette
colors_3type <- c("Ordinary" = "#1f4e79", "Administrative" = "#c00000",
                  "Litigated" = "#2e7d32")
colors_2type <- c("Administrative" = "#c00000", "Litigated" = "#2e7d32")
colors_urg   <- c("Ordinary" = "#1f4e79", "Urgent" = "#c00000")

# Type label factor
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

# Figure 1: Kernel Density — Log Reference Price
cat("Figure 1: Kernel density — log reference price\n")
p1 <- ggplot(dt_win[!is.na(bid_price_ref_log)],
             aes(x = bid_price_ref_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.7) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = c("solid", "dashed", "longdash")) +
  labs(x = "Log Reference Price", y = "Density",
       title = "Distribution of Reference Prices by Purchase Type") +
  theme_paper()
ggsave(file.path(GRAP, "fig_price_density.pdf"), p1, width = 8, height = 5)

# Figure 2: Kernel Density — Log Negotiated Price
cat("Figure 2: Kernel density — log negotiated price\n")
p2 <- ggplot(dt_win[!is.na(bid_price_log)],
             aes(x = bid_price_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.7) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = c("solid", "dashed", "longdash")) +
  labs(x = "Log Negotiated Price", y = "Density",
       title = "Distribution of Negotiated Prices by Purchase Type") +
  theme_paper()
ggsave(file.path(GRAP, "fig_negprice_density.pdf"), p2, width = 8, height = 5)

# Figure 3: Kernel Density — Log Quantity
cat("Figure 3: Kernel density — log quantity\n")
p3 <- ggplot(dt_win[!is.na(bid_qty_log)],
             aes(x = bid_qty_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.7) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = c("solid", "dashed", "longdash")) +
  labs(x = "Log Quantity", y = "Density",
       title = "Distribution of Quantities by Purchase Type") +
  theme_paper()
ggsave(file.path(GRAP, "fig_qty_density.pdf"), p3, width = 8, height = 5)

# Figure 4: Kernel Density — Log Number of Bidding Firms
cat("Figure 4: Kernel density — log firms\n")
p4 <- ggplot(dt[!is.na(ln_n_firms)],
             aes(x = ln_n_firms, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.7) +
  scale_color_manual(values = colors_3type) +
  scale_linetype_manual(values = c("solid", "dashed", "longdash")) +
  labs(x = "Log Number of Bidding Firms", y = "Density",
       title = "Distribution of Bidding Firms by Purchase Type") +
  theme_paper()
ggsave(file.path(GRAP, "fig_firms_density.pdf"), p4, width = 8, height = 5)

# Figure 5: Kernel Density — Admin vs Litigated (Urgent Only)
cat("Figure 5: Kernel density — UTG (admin vs litigated)\n")
dt_urg_win <- dt_win[purchase_type %in% c(1, 2)]
p5 <- ggplot(dt_urg_win[!is.na(bid_price_log)],
             aes(x = bid_price_log, color = type_label, linetype = type_label)) +
  geom_density(linewidth = 0.7) +
  scale_color_manual(values = colors_2type) +
  scale_linetype_manual(values = c("solid", "dashed")) +
  labs(x = "Log Negotiated Price", y = "Density",
       title = "Negotiated Prices: Administrative vs Litigated (Urgent Only)") +
  theme_paper()
ggsave(file.path(GRAP, "fig_utg_density.pdf"), p5, width = 8, height = 5)

# Figure 6: Bar Chart — Success Rate by Purchase Type
cat("Figure 6: Bar chart — success rate\n")
success_dt <- dt[, .(success_rate = mean(po_firm_winner, na.rm = TRUE)), by = type_label]
p6 <- ggplot(success_dt, aes(x = type_label, y = success_rate, fill = type_label)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%", success_rate * 100)),
            vjust = -0.5, size = 4) +
  scale_fill_manual(values = colors_3type) +
  scale_y_continuous(labels = scales::percent_format(), expand = expansion(mult = c(0, 0.1))) +
  labs(x = "", y = "Success Rate",
       title = "Tender Success Rate by Purchase Type") +
  theme_paper() +
  theme(legend.position = "none")
ggsave(file.path(GRAP, "fig_success_bar.pdf"), p6, width = 6, height = 5)

# Figure 7: Time Trends — Mean Log Negotiated Price by Year-Month
cat("Figure 7: Time trends — prices over time\n")

# Create a proper date for x-axis
dt_win[, ym_date := as.Date(m_y)]
dt_win[, urg_label := ifelse(urgent == 1, "Urgent", "Ordinary")]

trends_dt <- dt_win[!is.na(bid_price_log),
                     .(mean_price = mean(bid_price_log, na.rm = TRUE)),
                     by = .(ym_date, urg_label)]

p7 <- ggplot(trends_dt, aes(x = ym_date, y = mean_price,
                              color = urg_label, linetype = urg_label)) +
  geom_line(linewidth = 0.6) +
  scale_color_manual(values = colors_urg) +
  scale_linetype_manual(values = c("solid", "dashed")) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(x = "Year", y = "Mean Log Negotiated Price",
       title = "Price Trends: Ordinary vs Urgent Purchases") +
  theme_paper() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(GRAP, "fig_time_trends.pdf"), p7, width = 9, height = 5)

# Figure 8: Coefficient Plot — Treatment Effects from Tables 4-7
cat("Figure 8: Coefficient plot\n")

# Run preferred spec (Item+Year+PBU) for each table
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

# Extract coefficients
extract_coef <- function(model, label) {
  b <- coef(model)["urgent"]
  se <- sqrt(vcov(model)["urgent", "urgent"])
  data.frame(
    table = label,
    coef = b, se = se,
    ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se,
    stringsAsFactors = FALSE
  )
}

coef_df <- rbind(
  extract_coef(m_t4,  "T4: Ref Price"),
  extract_coef(m_t5,  "T5: Quantity"),
  extract_coef(m_t6a, "T6A: Neg Price (Total)"),
  extract_coef(m_t6b, "T6B: Neg Price (Direct)"),
  extract_coef(m_t7a, "T7A: Firms (Total)"),
  extract_coef(m_t7b, "T7B: Firms (Direct)")
)
coef_df$table <- factor(coef_df$table, levels = rev(coef_df$table))

p8 <- ggplot(coef_df, aes(x = coef, y = table)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.2, linewidth = 0.6) +
  geom_point(size = 3, color = "#1f4e79") +
  labs(x = "Coefficient on Urgent Purchase", y = "",
       title = "Treatment Effects Across Outcomes (Item+Year+PBU FE)") +
  theme_paper()
ggsave(file.path(GRAP, "fig_coefplot.pdf"), p8, width = 8, height = 5)

cat("\nAll figures saved to:", GRAP, "\n")
