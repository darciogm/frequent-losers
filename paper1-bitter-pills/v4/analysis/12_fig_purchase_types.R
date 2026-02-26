# =============================================================================
# 12_fig_purchase_types.R — Visual table: Types of Purchases
# Bitter Pills to Swallow — v4 (R/fixest)
# Output: v4/pub/figures/fig_00c_purchase_types.pdf
# =============================================================================

cat("=== 12_fig_purchase_types.R ===\n")
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

# --- Output directory ---------------------------------------------------------
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# --- Table content ------------------------------------------------------------
tbl <- data.frame(
  feature = rep(c("Source of funds", "Quantity", "Delivery time",
                   "Threat of punishment"), each = 3),
  type    = rep(c("Ordinary", "Administrative", "Litigated"), times = 4),
  value   = c(
    "Dedicated budget", "Diverted budget",    "Diverted budget",
    "Large",            "Small",              "Small",
    "Long",             "Short",              "Short",
    "None",             "None",               "Potential punishment"
  ),
  stringsAsFactors = FALSE
)

# --- Column layout (seamless tiles) -------------------------------------------
ROW_W <- 1.8   # row label column width
COL_W <- 1.3   # data column width
row_x <- ROW_W / 2
col_x <- ROW_W + COL_W * (0.5 + 0:2)  # centers: 2.45, 3.75, 5.05
type_x <- setNames(col_x, c("Ordinary", "Administrative", "Litigated"))

# Numeric coordinates for the grid
tbl$x <- type_x[tbl$type]
tbl$y <- match(tbl$feature, rev(c("Source of funds", "Quantity",
                                    "Delivery time", "Threat of punishment")))

# Cell fill categories
tbl$fill <- ifelse(tbl$type == "Ordinary", "ordinary",
            ifelse(tbl$value == "Potential punishment", "key_diff", "shared"))

# --- Header row ---------------------------------------------------------------
header <- data.frame(
  x     = col_x,
  y     = max(tbl$y) + 1,
  label = c("Ordinary", "Administrative", "Litigated"),
  stringsAsFactors = FALSE
)

# --- Row labels ---------------------------------------------------------------
row_labels <- data.frame(
  x     = row_x,
  y     = sort(unique(tbl$y)),
  label = rev(c("Source of funds", "Quantity",
                 "Delivery time", "Threat of punishment")),
  stringsAsFactors = FALSE
)

# --- Build ggplot -------------------------------------------------------------
FIG_W <- 6.5
FIG_H <- 2.5
BASE_SIZE <- 9

fill_vals <- c("ordinary" = "white", "shared" = "gray92", "key_diff" = "gray75")

p <- ggplot() +
  # Data cells
  geom_tile(data = tbl,
            aes(x = x, y = y, fill = fill),
            width = COL_W, color = "gray70", linewidth = 0.3) +
  geom_text(data = tbl,
            aes(x = x, y = y, label = value),
            size = 2.8, color = "black") +
  # Header cells
  geom_tile(data = header,
            aes(x = x, y = y),
            width = COL_W, fill = "gray85", color = "gray70", linewidth = 0.3) +
  geom_text(data = header,
            aes(x = x, y = y, label = label),
            size = 3, fontface = "bold", color = "black") +
  # Row label cells
  geom_tile(data = row_labels,
            aes(x = x, y = y),
            width = ROW_W, fill = "white", color = "gray70", linewidth = 0.3) +
  geom_text(data = row_labels,
            aes(x = x, y = y, label = label),
            size = 2.8, fontface = "bold", color = "black") +
  # Top-left empty cell
  geom_tile(data = data.frame(x = row_x, y = max(tbl$y) + 1),
            aes(x = x, y = y),
            width = ROW_W, fill = "gray85", color = "gray70", linewidth = 0.3) +
  scale_fill_manual(values = fill_vals, guide = "none") +
  scale_x_continuous(expand = expansion(mult = 0.01)) +
  scale_y_continuous(expand = expansion(mult = 0.05)) +
  coord_cartesian(clip = "off") +
  theme_void(base_size = BASE_SIZE) +
  theme(plot.margin = margin(5, 10, 5, 10))

# --- Save ---------------------------------------------------------------------
filepath <- file.path(PUB_FIG, "fig_00c_purchase_types.pdf")
ggsave(filepath, p, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat("  Saved:", filepath, "\n")

cat("=== 12_fig_purchase_types.R complete ===\n")
