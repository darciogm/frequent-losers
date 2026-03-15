# Fix Warning 4: Regenerate Figure 2 with threshold annotation
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(ggplot2); library(scales)
})

cat("Loading FREQ_PARTICIP...\n")
fp <- as.data.table(read_parquet("data/processed/FREQ_PARTICIP_rebuilt.parquet"))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]; threshold <- q[2] + 1.5 * iqr_val
cat(sprintf("Threshold: %.0f (median=%.0f, IQR=%.0f)\n", threshold, q[2], iqr_val))
cat(sprintf("FL firms: %d / %d\n", sum(fp$tenders_count > threshold), nrow(fp)))

theme_pub <- function() {
  theme_minimal(base_size = 11) + theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(size = 12, face = "bold"),
    axis.title = element_text(size = 10))
}

# Figure 1: Distribution
p1 <- ggplot(fp, aes(x = tenders_count)) +
  geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
  geom_vline(xintercept = threshold, linetype = "dashed", color = "red", linewidth = 0.7) +
  annotate("text", x = threshold + 5, y = Inf, vjust = 2, hjust = 0,
           label = paste0("Threshold = ", round(threshold)), size = 3.5, color = "red") +
  labs(x = "Number of Tender Participations", y = "Number of Firms") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()
ggsave("work/v5/figures/fig_01_losses_distribution.pdf", p1, width=8, height=5)
cat("Saved fig_01\n")

# Figure 2: IQR identification (zoomed in)
p2 <- ggplot(fp[tenders_count <= 200], aes(x = tenders_count)) +
  geom_histogram(bins = 60, fill = "gray60", color = "gray30", linewidth = 0.3) +
  geom_vline(xintercept = threshold, linetype = "dashed", color = "red", linewidth = 0.7) +
  annotate("text", x = threshold + 3, y = Inf, vjust = 2, hjust = 0,
           label = sprintf("Threshold = %d\n(median + 1.5 x IQR)", round(threshold)),
           size = 3.5, color = "red") +
  annotate("rect", xmin = threshold, xmax = 200, ymin = -Inf, ymax = Inf,
           alpha = 0.08, fill = "red") +
  annotate("text", x = 100, y = Inf, vjust = 2,
           label = "FL firms", size = 3, color = "red", fontface = "italic") +
  labs(x = "Number of Tender Participations", y = "Number of Firms",
       title = "IQR Identification of Frequent Losers") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()
ggsave("work/v5/figures/fig_02_iqr_identification.pdf", p2, width=8, height=5)
cat("Saved fig_02\n")
