# ============================================================================
# 21_figures_v14.R — Paper 3 v14 figures (F3.1, F3.6, F3.7, F3.4)
# Paper 3 v14
#
# Generates four key figures for the paper-β:
#   F3.1 fig_puzzle.pdf            — distribution of always-loser tenders_count
#                                     with FL threshold + expected-profit annotation
#   F3.6 fig_rdd_176k.pdf          — sharp RDD plot at R$176k cap (post-Decreto)
#   F3.7 fig_first_time_density.pdf — log(bid/winner) density FL vs non-FL on
#                                     first tender appearance
#   F3.4 fig_detection_vs_id.pdf   — conceptual 2D map (data richness × ID
#                                     feasibility) showing where paper3 / Imhof /
#                                     Bajari-Ye sit
# ============================================================================

cat("=== 21_figures_v14.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2); library(scales)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "figures_v14")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

theme_paper <- function(base_size = 11) {
  theme_bw(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          plot.title       = element_text(size = base_size + 1, face = "plain"),
          plot.subtitle    = element_text(size = base_size - 1, color = "gray30"),
          legend.position  = "bottom")
}

# ============================================================================
# F3.1 — The puzzle: tenders_count distribution among always-losers
# ============================================================================
cat("\n--- F3.1: puzzle figure ---\n")

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
al <- fp[always_loser == 1L]
THRESH <- 14L

# Annotation: cumulative bidding cost at various participation counts
costs <- data.table(
  count = c(THRESH, 25, 50, 100),
  label = c(sprintf("threshold = %d\nR$700–7,000", THRESH),
            "25 tenders\nR$1,250–12,500",
            "50 tenders\nR$2,500–25,000",
            "100 tenders\nR$5,000–50,000")
)

p_puzzle <- ggplot(al, aes(x = tenders_count)) +
  geom_histogram(binwidth = 1, fill = "#5b8aa6", color = "white",
                 alpha = 0.85, boundary = 0) +
  geom_vline(xintercept = THRESH, linetype = "dashed", color = "#d73027",
             linewidth = 0.7) +
  annotate("text", x = THRESH + 1, y = Inf, vjust = 1.5, hjust = 0,
           label = sprintf("FL threshold\n= median + 1.5 × IQR\n= %d tenders", THRESH),
           color = "#d73027", size = 3.2, lineheight = 0.95) +
  scale_x_log10(labels = comma_format(),
                breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 500),
                limits = c(1, max(al$tenders_count))) +
  scale_y_continuous(labels = comma_format()) +
  labs(x = "Tenders participated in (zero-win firms only, log scale)",
       y = "Number of firms",
       title = "Why do thousands of firms participate without ever winning?",
       subtitle = sprintf("São Paulo BEC, 2009–2019. %s always-loser firms; %s above the threshold (FL).",
                          format(nrow(al), big.mark = ","),
                          format(sum(al$tenders_count > THRESH), big.mark = ","))) +
  theme_paper()

ggsave(file.path(OUT, "fig_puzzle.pdf"), p_puzzle,
       width = 7, height = 4, device = cairo_pdf)
cat("  Saved:", file.path(OUT, "fig_puzzle.pdf"), "\n")

# ============================================================================
# F3.6 — Sharp RDD plot at R$176k cap (post-Decreto 2018-2019)
# ============================================================================
cat("\n--- F3.6: RDD plot at R$176k post-Decreto ---\n")

iv <- as.data.table(read_parquet(file.path(BASE, "data/processed/item_value_panel.parquet")))
d_post <- iv[modality %in% c(1L, 3L) & year >= 2018L & item_value > 0 &
             is.finite(item_value)]
CAP <- 176000
d_post[, running := log(item_value) - log(CAP)]
d_post[, convite := as.integer(modality == 1L)]

# Bin into running-variable bins for binscatter
d_post[, bin := cut(running, breaks = seq(-1.0, 1.0, by = 0.05))]
binscatter <- d_post[abs(running) <= 1.0, .(
  mean_running = mean(running),
  share_convite = mean(convite),
  has_fl_share  = mean(has_fl, na.rm = TRUE),
  n             = .N
), by = bin][!is.na(bin) & n >= 5]

# Two-panel figure: convite share + FL prevalence
p_rdd_a <- ggplot(binscatter, aes(x = mean_running, y = share_convite)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "#d73027") +
  geom_point(aes(size = n), alpha = 0.6, color = "#5b8aa6") +
  geom_smooth(data = binscatter[mean_running < 0], method = "lm",
              se = TRUE, color = "#3b8dbd", linewidth = 0.7) +
  geom_smooth(data = binscatter[mean_running > 0], method = "lm",
              se = TRUE, color = "#3b8dbd", linewidth = 0.7) +
  scale_size_continuous(name = "items", range = c(0.5, 4)) +
  scale_x_continuous(breaks = c(-0.7, 0, 0.7),
                     labels = c("R$87k", "R$176k", "R$355k")) +
  labs(x = "Item value (log, centered at R$176k cap)",
       y = "Share of items in convite",
       title = "(a) First stage: modality jumps at the R$176k cap",
       subtitle = "Sharp RDD, post-Decreto 9.412/2018 sample (2018–2019)") +
  theme_paper()

p_rdd_b <- ggplot(binscatter, aes(x = mean_running, y = has_fl_share)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "#d73027") +
  geom_point(aes(size = n), alpha = 0.6, color = "#9e3a4d") +
  geom_smooth(data = binscatter[mean_running < 0], method = "lm",
              se = TRUE, color = "#9e3a4d", linewidth = 0.7) +
  geom_smooth(data = binscatter[mean_running > 0], method = "lm",
              se = TRUE, color = "#9e3a4d", linewidth = 0.7) +
  scale_size_continuous(name = "items", range = c(0.5, 4)) +
  scale_x_continuous(breaks = c(-0.7, 0, 0.7),
                     labels = c("R$87k", "R$176k", "R$355k")) +
  labs(x = "Item value (log, centered at R$176k cap)",
       y = "FL prevalence",
       title = "(b) FL prevalence: no jump at the cap",
       subtitle = "FL is robust to the regulatory regime change") +
  theme_paper()

# Combine vertically
suppressPackageStartupMessages({
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    install.packages("patchwork", repos = "https://cran.r-project.org")
  }
  library(patchwork)
})
p_rdd <- p_rdd_a / p_rdd_b
ggsave(file.path(OUT, "fig_rdd_176k.pdf"), p_rdd,
       width = 6.5, height = 7, device = cairo_pdf)
cat("  Saved:", file.path(OUT, "fig_rdd_176k.pdf"), "\n")

# ============================================================================
# F3.7 — log(bid/winner) density on first tender, FL vs non-FL always-losers
# ============================================================================
cat("\n--- F3.7: first-time-FL density ---\n")

# Generated by 15_first_time_fl.R already; we re-extract from cache or rerun
ftpath <- file.path(BASE, "output/first_time_fl/first_time_fl_summary.csv")
if (file.exists(ftpath)) {
  cat("  Loading existing first-time-FL data ...\n")
}

# Re-build the panel directly to plot density (15_first_time_fl computed it
# but didn't save the panel as parquet — re-compute briefly here)
suppressPackageStartupMessages({library(duckdb); library(DBI)})
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

al_codes <- fp[always_loser == 1L, `códigofornecedor`]
al_codes_path <- "/tmp/al_codes_for_fig.parquet"
write_parquet(data.table(firm_code = al_codes), al_codes_path)

bids <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    CAST(\"Código Fornecedor\" AS VARCHAR)        AS firm_code,
    CAST(\"Numero da OC\"      AS VARCHAR)        AS numerodaoc,
    CAST(\"Código Item\"       AS VARCHAR)        AS codigoitem,
    CAST(\"Mês Ano Encerramento\" AS VARCHAR)     AS mes_ano,
    CAST(\"Valor Unitário Proposta\" AS VARCHAR)  AS bid_str,
    CAST(\"Flag Vencedor\"    AS VARCHAR)         AS won_str
  FROM read_parquet('%s', union_by_name=true)
  WHERE \"Código Fornecedor\" IN (SELECT firm_code FROM read_parquet('%s'))
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"), al_codes_path)))
dbDisconnect(con, shutdown = TRUE)

bids[, bid_price := suppressWarnings(as.numeric(gsub(",", ".", bid_str)))]
bids[, won := suppressWarnings(as.integer(won_str))]
bids[, year := suppressWarnings(as.integer(substr(mes_ano, 4, 4)))]
bids[, month := suppressWarnings(as.integer(substr(mes_ano, 1, 2)))]
bids[, yyyymm := year * 12L + month]

valid <- bids[bid_price > 0 & !is.na(yyyymm)]
setkey(valid, firm_code, yyyymm, numerodaoc, codigoitem)
ff <- valid[, .SD[1], by = firm_code]

# item-level winner price — needs FULL bid-level data (not just al_codes,
# since the winner is by definition NOT an always-loser).
cat("  Pulling item-level winner prices from full bid-level ...\n")
con2 <- dbConnect(duckdb()); dbExecute(con2, "PRAGMA threads=12")
dbExecute(con2, "PRAGMA memory_limit='12GB'")
keys <- ff[, .(numerodaoc, codigoitem)]
keys_path <- "/tmp/ff_keys_for_winner.parquet"
write_parquet(keys, keys_path)
item_w <- as.data.table(dbGetQuery(con2, sprintf("
  WITH bids AS (
    SELECT
      CAST(\"Numero da OC\" AS VARCHAR)              AS numerodaoc,
      CAST(\"Código Item\"  AS VARCHAR)              AS codigoitem,
      TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bp,
      TRY_CAST(CAST(\"Flag Vencedor\" AS VARCHAR) AS INTEGER) AS won
    FROM read_parquet('%s', union_by_name=true)
    WHERE (\"Numero da OC\", \"Código Item\") IN (
      SELECT numerodaoc, codigoitem FROM read_parquet('%s')
    )
  )
  SELECT numerodaoc, codigoitem,
         MAX(CASE WHEN won = 1 AND bp IS NOT NULL AND bp > 0 THEN bp ELSE NULL END) AS item_winner_bid,
         MIN(CASE WHEN bp IS NOT NULL AND bp > 0 THEN bp ELSE NULL END) AS item_min_bid,
         COUNT(*) AS item_n_bids
  FROM bids
  GROUP BY numerodaoc, codigoitem
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"), keys_path)))
dbDisconnect(con2, shutdown = TRUE)
cat(sprintf("  Item-winner table rows: %s\n",
            format(nrow(item_w), big.mark = ",")))

ff <- merge(ff, item_w, by = c("numerodaoc", "codigoitem"), all.x = TRUE)
fp_for_merge <- copy(fp)
setnames(fp_for_merge, "códigofornecedor", "firm_code")
fp_for_merge[, firm_code := as.character(firm_code)]
ff[, firm_code := as.character(firm_code)]
ff <- merge(ff, fp_for_merge[, .(firm_code, tenders_count, always_loser)],
            by = "firm_code", all.x = TRUE)
ff[is.na(always_loser), always_loser := 0L]
ff[is.na(tenders_count), tenders_count := 0L]
ff[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]
ff[, group := fifelse(is_fl == 1L, "FL (frequent losers)", "Other always-losers")]
ff[, log_bw := log(bid_price / pmax(item_winner_bid, 1e-9))]

panel_dens <- ff[!is.na(log_bw) & is.finite(log_bw) & item_winner_bid > 0]
cat(sprintf("  Density panel: %s firms (FL=%s, non-FL=%s)\n",
            format(nrow(panel_dens), big.mark = ","),
            format(sum(panel_dens$is_fl == 1), big.mark = ","),
            format(sum(panel_dens$is_fl == 0), big.mark = ",")))

p_density <- ggplot(panel_dens[abs(log_bw) <= 5],
                     aes(x = log_bw, fill = group, color = group)) +
  geom_density(alpha = 0.4, linewidth = 0.6) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  scale_fill_manual(values = c("FL (frequent losers)" = "#d73027",
                                "Other always-losers" = "#5b8aa6")) +
  scale_color_manual(values = c("FL (frequent losers)" = "#d73027",
                                 "Other always-losers" = "#5b8aa6")) +
  labs(x = "log(bid / winner price) on FIRST tender appearance",
       y = "Density",
       title = "FL firms bid higher than non-FL always-losers — already on first tender",
       subtitle = "No selection on outcome possible; behavioral signature of cover bidding") +
  theme_paper() +
  theme(legend.title = element_blank())

ggsave(file.path(OUT, "fig_first_time_density.pdf"), p_density,
       width = 7, height = 4.2, device = cairo_pdf)
cat("  Saved:", file.path(OUT, "fig_first_time_density.pdf"), "\n")

# ============================================================================
# F3.4 — Conceptual map: data richness × identification feasibility
# ============================================================================
cat("\n--- F3.4: conceptual detection-vs-identification map ---\n")

papers <- data.table(
  paper = c("Porter–Zona\n(Ohio milk)",
            "Pesendorfer\n(NYC stamps)",
            "Asker\n(NYC bid-rigging)",
            "Imhof et al.\n(Swiss highway)",
            "Conley–Decarolis\n(Italy)",
            "Best (QJE 2023)\n(procurement)",
            "Caoui (JLE 2022)\n(timing)",
            "THIS PAPER\n(BEC frequent losers)"),
  data_richness = c(0.88, 0.85, 0.90, 0.92, 0.78, 0.65, 0.70, 0.20),
  identification = c(0.85, 0.80, 0.85, 0.85, 0.65, 0.85, 0.85, 0.30),
  is_this  = c(0, 0, 0, 0, 0, 0, 0, 1)
)

p_map <- ggplot(papers, aes(x = data_richness, y = identification)) +
  geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray70") +
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray70") +
  geom_point(aes(color = factor(is_this), size = factor(is_this)),
             alpha = 0.85) +
  geom_text(aes(label = paper, color = factor(is_this)),
            vjust = -1.3, size = 2.6, lineheight = 0.85, fontface = "plain") +
  scale_color_manual(values = c("0" = "#5b8aa6", "1" = "#d73027"),
                     guide = "none") +
  scale_size_manual(values = c("0" = 3.5, "1" = 6), guide = "none") +
  scale_x_continuous(breaks = c(0, 0.5, 1),
                     labels = c("contract-record only",
                                "moderate microdata",
                                "full bid-by-bid"),
                     limits = c(0, 1)) +
  scale_y_continuous(breaks = c(0, 0.5, 1),
                     labels = c("conditional\nassociation",
                                "partial ID",
                                "strict\ncausal ID"),
                     limits = c(0, 1)) +
  labs(x = "Data richness (bid microdata available?)",
       y = "Identification feasibility",
       title = "Detection versus identification: where this paper fits",
       subtitle = "Most cartel-screening papers operate in data-rich settings.\nThe FL screen runs in the data-thin regime where most procurement actually lives.") +
  theme_paper() +
  theme(panel.grid.major = element_blank())

ggsave(file.path(OUT, "fig_detection_vs_id.pdf"), p_map,
       width = 7.5, height = 5.5, device = cairo_pdf)
cat("  Saved:", file.path(OUT, "fig_detection_vs_id.pdf"), "\n")

cat("\n  Done.\n")
