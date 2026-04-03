# ============================================================================
# figures_new.R
# Darcio Genicolo-Martins — INSPER, 2026
#
# Additional figures for the screening paper (Paper 1).
# Three pieces that the reviewer feedback and the JLE repositioning called for:
#   (1) Corner solution showing the quorum constraint vs. calibrated interior
#   (2) Dispersion paradox — the core of the Regime 2 argument
#   (3) Enforcement flowchart with real numbers from the pipeline
#
# Run standalone:  Rscript code/figures_new.R
# Or from master:  source("code/figures_new.R")
# ============================================================================

cat("=== figures_new.R ===\n")

# ── Setup ────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(ggplot2)
  if (!requireNamespace("latex2exp", quietly = TRUE))
    install.packages("latex2exp", repos = "https://cloud.r-project.org", quiet = TRUE)
  library(latex2exp)
  if (!requireNamespace("showtext", quietly = TRUE))
    install.packages("showtext", repos = "https://cloud.r-project.org", quiet = TRUE)
  library(showtext)
})

setDTthreads(min(parallel::detectCores(logical = FALSE), 16L))

# Determine BASE: works both via source() and Rscript
.get_script_dir <- function() {
  # Try sys.frame first (when source'd)
  for (i in seq_len(sys.nframe())) {
    f <- sys.frame(i)$ofile
    if (!is.null(f)) return(dirname(normalizePath(f)))
  }
  # Try commandArgs (when Rscript'd)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0)
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  # Fallback
  return(getwd())
}
BASE <- normalizePath(file.path(.get_script_dir(), ".."), mustWork = FALSE)
OUT_FIG <- file.path(BASE, "output", "figures")
OUT_IMG <- file.path(BASE, "manuscript", "v4", "images")
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_IMG, recursive = TRUE, showWarnings = FALSE)

# Paths
PROJECT_ROOT <- normalizePath(file.path(BASE, "..", ".."), mustWork = FALSE)
PARQUET_BL  <- file.path(PROJECT_ROOT, "v3", "data", "processed",
                         "bid_level_analysis.parquet")
PARQUET_BWP <- file.path(PROJECT_ROOT, "v3", "data", "processed",
                         "bid_level_with_prices.parquet")
PARAMS_CSV  <- file.path(PROJECT_ROOT, "papers_finais", "paper2_structural",
                         "work", "v6", "tables", "cartel_primitives.csv")

# Try Palatino for consistency with the LaTeX manuscript; fall back to serif
font_ok <- tryCatch({
  showtext_auto()
  font_add("Palatino", regular = "pplr8a.pfb")
  TRUE
}, error = function(e) FALSE)
FONT_FAMILY <- if (font_ok) "Palatino" else "serif"

# Colour palette and dimensions — kept sober for journal submission
FL_BLUE   <- "#2c5f8a"
GREY_DARK <- "#4a4a4a"
FIG_W <- 7
FIG_H <- 5

theme_paper <- function(base_size = 10) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(family = FONT_FAMILY),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(colour = "grey92"),
      axis.line        = element_line(colour = "black", linewidth = 0.3),
      axis.ticks       = element_line(colour = "black", linewidth = 0.3),
      legend.background = element_blank(),
      legend.key        = element_blank(),
      plot.margin       = margin(8, 12, 8, 8)
    )
}

save_fig <- function(plot, filename, w = FIG_W, h = FIG_H, dir = OUT_FIG) {
  fp <- file.path(dir, filename)
  ggsave(fp, plot, width = w, height = h, device = cairo_pdf)
  cat("  Saved:", fp, "\n")
}


# ============================================================================
# FIGURE 1 — Corner solution + strategic complementarity
# ============================================================================
# The idea here is to show both the mechanical corner (Lei 8.666 quorum, n<3)
# and the calibrated interior in a single panel. I overlay the theoretical
# curve on empirical binned means so the reader can judge the fit visually.
# The key surprise is that gamma > 0: cartels deploy MORE cover bidders in
# more competitive tenders, not fewer. The corner and interior slopes go in
# opposite directions — that's the institutional punchline for the JLE.
#
# Data: tender-level (n_gen, n_fl) from bid_level_analysis.parquet
#       calibrated params from paper2_structural (cartel_primitives.csv)
# ============================================================================

cat("\n  Figure 1: Corner solution + complementarity...\n")

# Load calibrated params
params <- fread(PARAMS_CSV)
pi0   <- params[param == "pi0",   value]
gamma <- params[param == "gamma", value]
c1    <- params[param == "c1",    value]
phi0  <- params[param == "phi0",  value]
psi   <- params[param == "psi",   value]
cat("    Params: pi0=", round(pi0, 4), " gamma=", round(gamma, 4),
    " c1=", round(c1, 4), " phi0=", round(phi0, 6), " psi=", psi, "\n")

# Load tender-level data
cat("    Loading bid-level data...\n")
bl <- as.data.table(read_parquet(PARQUET_BL))
tender <- bl[!is.na(bid_price) & bid_price > 0,
  .(n_fl  = sum(is_fl == 1L, na.rm = TRUE),
    n_gen = sum(is_fl == 0L, na.rm = TRUE),
    n_total = .N,
    has_fl = as.integer(any(is_fl == 1L))),
  by = .(oc_code, item_code)]

# Get PBU from oc_code (first 11 chars)
tender[, pbu_code := substr(oc_code, 1, 11)]
pbu_size <- tender[, .N, by = pbu_code]
setnames(pbu_size, "N", "pbu_size")
tender <- merge(tender, pbu_size, by = "pbu_code", all.x = TRUE)

fl_tenders <- tender[has_fl == 1L & n_fl > 0]
median_pbu <- median(fl_tenders$pbu_size, na.rm = TRUE)
cat("    Median PBU size:", median_pbu, "\n")
cat("    FL-present tenders:", nrow(fl_tenders), "\n")

# Bin at integer values of n_gen; cap at 12 because above that
# the bins get thin and a catch-all would be misleading
fl_tenders[, n_gen_cap := pmin(n_gen, 12L)]
binned <- fl_tenders[n_gen <= 12,
  .(mean_nfl = mean(n_fl), se = sd(n_fl) / sqrt(.N), N = .N),
  by = n_gen_cap][order(n_gen_cap)]
# Keep bins with N >= 50 for visual clarity
binned <- binned[N >= 50]

# Calibrated interior: m(n) = pi0 * n^gamma / (c1 + phi0 * theta)
# I evaluate at the Q1 PBU size rather than the median because FL-present
# tenders skew toward smaller purchasing units (cf. oversight heterogeneity)
theta_med <- quantile(fl_tenders$pbu_size, 0.25, na.rm = TRUE)^psi
denom     <- c1 + phi0 * theta_med
cat("    PBU Q1 for curve:", quantile(fl_tenders$pbu_size, 0.25, na.rm = TRUE), "\n")

n_seq <- seq(0.1, 13, by = 0.1)
m_interior_raw <- pi0 * n_seq^gamma / denom

# The calibration was done at PBU level (paper 2), so the raw curve sits
# below the tender-level means. I rescale multiplicatively (OLS through
# the origin) to match the level while preserving the calibrated shape.
interior_bins <- binned[n_gen_cap >= 3]
m_at_bins <- pi0 * interior_bins$n_gen_cap^gamma / denom
k_shift <- sum(interior_bins$mean_nfl * m_at_bins) / sum(m_at_bins^2)  # OLS through origin
cat("    Level shift k:", round(k_shift, 3), "\n")

m_interior <- k_shift * m_interior_raw
m_corner   <- pmax(3 - n_seq, 0)
m_star     <- ifelse(n_seq < 3, pmax(m_corner, m_interior), m_interior)

curve_dt <- data.table(n = n_seq, m = m_star,
                       region = ifelse(n_seq < 3, "Corner (quorum rule)", "Interior"))

# Also make pure corner line for overlay
corner_dt <- data.table(n = seq(0, 3, by = 0.1), m = pmax(3 - seq(0, 3, by = 0.1), 0))

# ── Rug: distribution of n_gen in FL-present tenders ──
rug_dt <- fl_tenders[n_gen <= 12, .(n_gen)]

# ── Plot ──
p1 <- ggplot() +
  # Blue shading for the constraint-binding region
  annotate("rect", xmin = -0.2, xmax = 3, ymin = -0.15, ymax = Inf,
           fill = FL_BLUE, alpha = 0.07) +
  # Corner: m* = 3 - n
  geom_line(data = corner_dt, aes(x = n, y = m),
            linewidth = 1.2, colour = FL_BLUE) +
  # Interior: calibrated m*(n) with level shift
  geom_line(data = curve_dt[region == "Interior"],
            aes(x = n, y = m), linewidth = 1.2, colour = GREY_DARK) +
  # n = 3 transition
  geom_vline(xintercept = 3, linetype = "dashed", colour = "grey50", linewidth = 0.5) +
  # Empirical binned means with error bars
  geom_pointrange(data = binned,
                  aes(x = n_gen_cap, y = mean_nfl,
                      ymin = pmax(mean_nfl - 1.96 * se, 0),
                      ymax = mean_nfl + 1.96 * se),
                  size = 0.4, colour = "black") +
  # Rug plot (subsample for clarity)
  geom_rug(data = rug_dt[sample(.N, min(.N, 5000))],
           aes(x = n_gen), sides = "b", alpha = 0.04, colour = GREY_DARK) +
  # Text labels
  annotate("text", x = 0.6, y = max(binned$mean_nfl) + 0.15,
           label = "Constraint binding\n(quorum rule, n < 3)",
           size = 3, colour = FL_BLUE, fontface = "italic", family = FONT_FAMILY,
           hjust = 0, vjust = 0) +
  annotate("text", x = 8.5, y = max(m_interior[n_seq > 7]) + 0.08,
           label = "Interior: strategic complementarity",
           size = 3, colour = GREY_DARK, fontface = "italic", family = FONT_FAMILY) +
  annotate("text", x = 3.05, y = 0.05, label = "n = 3", hjust = 0,
           size = 2.5, colour = "grey50", family = FONT_FAMILY) +
  # Scales
  scale_x_continuous(
    name = expression(italic(n)~"(genuine bidders)"),
    breaks = 0:12, limits = c(-0.2, 12.5), expand = c(0, 0)
  ) +
  scale_y_continuous(
    name = expression(italic(m)*"*"~"(FL / cover bidders)"),
    limits = c(-0.15, max(binned$mean_nfl + 1.96 * binned$se) + 0.3),
    expand = c(0, 0)
  ) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank())

save_fig(p1, "fig_corner_solution.pdf")

# Appendix version: declining interior (what the textbook story would predict
# if there were diminishing returns rather than complementarity)
n_ill <- seq(0.1, 15, 0.1)
m_ill_int <- 0.8 * exp(-0.6 * (n_ill - 3))
m_ill <- ifelse(n_ill < 3, pmax(3 - n_ill, m_ill_int), m_ill_int)
ill_dt <- data.table(n = n_ill, m = m_ill,
                     region = ifelse(n_ill < 3, "Corner", "Interior"))
corner_ill <- data.table(n = seq(0, 3, 0.1), m = pmax(3 - seq(0, 3, 0.1), 0))

p1_app <- ggplot() +
  annotate("rect", xmin = -0.2, xmax = 3, ymin = -0.15, ymax = Inf,
           fill = FL_BLUE, alpha = 0.07) +
  geom_line(data = corner_ill, aes(x = n, y = m),
            linewidth = 1.2, colour = FL_BLUE) +
  geom_line(data = ill_dt[region == "Interior"],
            aes(x = n, y = m), linewidth = 1.2, colour = GREY_DARK) +
  geom_vline(xintercept = 3, linetype = "dashed", colour = "grey50", linewidth = 0.5) +
  annotate("text", x = 1.2, y = 2.8,
           label = "Constraint binding\n(quorum rule, n < 3)",
           size = 3, colour = FL_BLUE, fontface = "italic", family = FONT_FAMILY) +
  annotate("text", x = 9, y = 0.45,
           label = "Interior: diminishing returns",
           size = 3, colour = GREY_DARK, fontface = "italic", family = FONT_FAMILY) +
  scale_x_continuous(name = TeX("$n$ (genuine bidders)"),
                     breaks = 0:15, limits = c(-0.2, 15.5), expand = c(0, 0)) +
  scale_y_continuous(name = TeX("$m^*$ (cover bidders)"),
                     limits = c(-0.15, 3.5), expand = c(0, 0)) +
  theme_paper()

save_fig(p1_app, "fig_corner_solution_appendix.pdf")


# ============================================================================
# FIGURE 2 — The dispersion paradox
# ============================================================================
# Empirical kernel densities of log(bid / winning price) for FL vs non-FL
# losing bids, positive spread only, trimmed at the 99th percentile.
#
# The point I want to make visually: FL bids sit well above the winner
# (location shift), but within any given tender they cluster tightly —
# the structural sigma_c / sigma_g = 0.72. That within-tender tightness
# is why CV-based screens miss coordinated cover bidding (Regime 2).
# I chose not to overlay theoretical densities because the empirical
# distributions already tell the story clearly; an overlay just adds clutter.
#
# Replicates the subsetting logic from sanity_checks.R (paper 2).
# ============================================================================

cat("\n  Figure 2: Dispersion paradox...\n")

# Already have bl loaded from Figure 1
winners <- bl[won == 1L & !is.na(bid_price) & bid_price > 0,
              .(win_price = min(bid_price)), by = .(oc_code, item_code)]
losers <- merge(bl[won == 0L & !is.na(bid_price) & bid_price > 0],
                winners, by = c("oc_code", "item_code"), all.x = FALSE)
losers[, log_spread := log(bid_price) - log(win_price)]

fl_pos    <- losers[is_fl == 1L & log_spread > 0 & is.finite(log_spread)]
nonfl_pos <- losers[is_fl == 0L & log_spread > 0 & is.finite(log_spread)]

rm(bl, winners); gc(verbose = FALSE)

# Summary stats for the in-figure annotation
fl_n    <- nrow(fl_pos)
nonfl_n <- nrow(nonfl_pos)
fl_sd   <- sd(fl_pos$log_spread)
nonfl_sd <- sd(nonfl_pos$log_spread)
fl_mean <- mean(fl_pos$log_spread)
nonfl_mean <- mean(nonfl_pos$log_spread)
ks_stat <- suppressWarnings(ks.test(
  sample(fl_pos$log_spread, min(fl_n, 50000)),
  sample(nonfl_pos$log_spread, min(nonfl_n, 50000))
))

cat("    FL: N=", fl_n, " mean=", round(fl_mean, 3), " sd=", round(fl_sd, 3), "\n")
cat("    NonFL: N=", nonfl_n, " mean=", round(nonfl_mean, 3), " sd=", round(nonfl_sd, 3), "\n")

# Trim at 99th percentile for clean plot
fl_q99    <- quantile(fl_pos$log_spread, 0.99)
nonfl_q99 <- quantile(nonfl_pos$log_spread, 0.99)
upper_lim <- max(fl_q99, nonfl_q99)

# 22M points is too many for a kernel density; subsample non-FL
set.seed(42)
nonfl_sub <- nonfl_pos[sample(.N, min(.N, 500000))]

# Combine for plotting
dens_dt <- rbind(
  data.table(log_spread = fl_pos[log_spread <= upper_lim, log_spread],
             group = paste0("FL losing bids (N = ", formatC(fl_n, big.mark = ","), ")")),
  data.table(log_spread = nonfl_sub[log_spread <= upper_lim, log_spread],
             group = paste0("Non-FL losing bids (N = ", formatC(nonfl_n, big.mark = ",", format = "d"), ")"))
)

# Factor ordering: FL on top so its density line isn't hidden
dens_dt[, group := factor(group, levels = unique(group))]

p2 <- ggplot(dens_dt, aes(x = log_spread, colour = group, fill = group)) +
  geom_density(linewidth = 0.7, alpha = 0.15, adjust = 1.5) +
  # Dashed lines at group means
  geom_vline(xintercept = fl_mean, linetype = "dashed", colour = FL_BLUE,
             linewidth = 0.5, alpha = 0.7) +
  geom_vline(xintercept = nonfl_mean, linetype = "dashed", colour = GREY_DARK,
             linewidth = 0.5, alpha = 0.7) +
  # FL summary stats
  annotate("text", x = fl_mean + 0.15, y = 1.45,
           label = paste0("FL: \u03bc = ", round(fl_mean, 2),
                          ", \u03c3 = ", round(fl_sd, 2)),
           size = 2.8, colour = FL_BLUE, hjust = 0, family = FONT_FAMILY) +
  # Non-FL summary stats
  annotate("text", x = 2.5, y = 1.3,
           label = paste0("Non-FL: \u03bc = ", round(nonfl_mean, 2),
                          ", \u03c3 = ", round(nonfl_sd, 2)),
           size = 2.8, colour = GREY_DARK, hjust = 0, family = FONT_FAMILY) +
  # The within-tender paradox — the whole point of this figure
  annotate("label", x = upper_lim * 0.55, y = 0.7,
           label = paste0("Within-tender CV:\n",
                          "  FL = 0.57  vs  non-FL = 1.65\n",
                          "Structural  \u03c3c / \u03c3g = 0.72\n",
                          "KS D = ", round(ks_stat$statistic, 2), ",  p < 0.001"),
           size = 2.4, fill = "grey97", colour = "grey30",
           label.padding = unit(0.4, "lines"),
           family = FONT_FAMILY, hjust = 0, vjust = 1) +
  # Arrow calling attention to FL clustering
  annotate("segment", x = 2.2, xend = fl_mean + 0.2,
           y = 0.45, yend = 0.30,
           arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
           colour = FL_BLUE, linewidth = 0.4) +
  annotate("text", x = 2.25, y = 0.48,
           label = "FL bids cluster\nabove winner",
           size = 2.5, colour = FL_BLUE, fontface = "italic",
           family = FONT_FAMILY, hjust = 0) +
  # Scales
  scale_colour_manual(values = c(FL_BLUE, GREY_DARK)) +
  scale_fill_manual(values = c(FL_BLUE, GREY_DARK)) +
  scale_x_continuous(
    name = expression(log(b[l] / b^"*")~~"(log bid spread above winner)"),
    limits = c(0, upper_lim),
    expand = c(0.01, 0)
  ) +
  scale_y_continuous(name = "Density", expand = expansion(mult = c(0, 0.05))) +
  theme_paper() +
  theme(
    legend.position = c(0.78, 0.92),
    legend.text     = element_text(size = 8),
    legend.title    = element_blank()
  )

save_fig(p2, "fig_dispersion_paradox.pdf")

rm(losers, fl_pos, nonfl_pos, nonfl_sub, dens_dt); gc(verbose = FALSE)


# ============================================================================
# FIGURE 3 — Three-stage enforcement flowchart
# ============================================================================
# Mermaid source (.mmd) with a TikZ fallback (.tex) in case mmdc isn't
# installed. I put real numbers from the pipeline in the nodes so the
# reader sees the funnel: 41K firms → 2,735 FL → triaged subset.
# The 93% reduction before any costly investigation is the whole point
# of the Posner (1970) argument in the conclusion.
# ============================================================================

cat("\n  Figure 3: Enforcement flowchart...\n")

# Mermaid markup — renders with mmdc if available
mmd <- '%%{ init: {"theme": "base", "themeVariables": {"primaryColor": "#e8eef4", "primaryBorderColor": "#2c5f8a"}} }%%
graph TD
    A["<b>PROCUREMENT DATABASE</b><br/>41,000 firms &bull; 4.5M tender-items<br/><i>Participation + outcome records only</i>"]
    A --> B{"<b>STAGE 1: SCREEN</b><br/>Win rate = 0 AND<br/>Participation > IQR threshold (≥ 14)"}
    B -->|"No flag<br/>(38,265 firms)"| C["No action"]
    B -->|"FL flag<br/>(2,735 firms)"| D["<b>STAGE 2: TRIAGE</b><br/>Network metrics (Winner-HHI)<br/>Oversight capacity (PBU size)<br/>Co-bidding concentration"]
    D --> E{"Prioritize by<br/>risk score"}
    E -->|"Low risk"| F["Monitor<br/>(periodic re-screen)"]
    E -->|"High risk"| G["<b>STAGE 3: INVESTIGATE</b><br/>Bid-level forensics on triaged subset<br/>FL + Imhof screens (corr. 0.06)<br/>Bajari&ndash;Ye bid-coordination tests"]
    G --> H[["Referral to CADE / TCU / MP<br/><i>AUC = 0.94 against CADE convictions</i>"]]

    classDef process fill:#f5f5f5,stroke:#666,stroke-width:1px,color:#333
    classDef decision fill:#e8eef4,stroke:#2c5f8a,stroke-width:2px,color:#1a3a5c
    classDef output fill:#e8f4e8,stroke:#5a8a5a,stroke-width:2px,color:#2d4a2d
    classDef noaction fill:#f5f5f5,stroke:#999,stroke-width:1px,color:#999

    class A process
    class B,E decision
    class D,G process
    class H output
    class C,F noaction
'

mmd_path <- file.path(OUT_IMG, "fig_enforcement_flowchart.mmd")
writeLines(mmd, mmd_path)
cat("  Saved:", mmd_path, "\n")

# TikZ standalone fallback (same diagram, compiles with pdflatex)
tikz_src <- r"(\documentclass[border=10pt]{standalone}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, calc}

\definecolor{flblue}{HTML}{2c5f8a}
\definecolor{flbluebg}{HTML}{e8eef4}
\definecolor{outgreen}{HTML}{5a8a5a}
\definecolor{outgreenbg}{HTML}{e8f4e8}
\definecolor{muted}{HTML}{999999}

\begin{document}
\begin{tikzpicture}[
    node distance=0.9cm and 1.5cm,
    every node/.style={font=\small, align=center},
    process/.style={rectangle, rounded corners=4pt, draw=black!50,
                    fill=black!3, minimum width=7.5cm, minimum height=1.1cm,
                    text width=7cm},
    decision/.style={diamond, draw=flblue, fill=flbluebg, thick,
                     minimum width=3cm, inner sep=2pt, text width=5cm,
                     aspect=2.2},
    output/.style={rectangle, rounded corners=4pt, draw=outgreen, fill=outgreenbg,
                   thick, double, minimum width=7.5cm, minimum height=0.9cm,
                   text width=7cm},
    noaction/.style={rectangle, rounded corners=4pt, draw=muted, fill=black!2,
                     text=muted, minimum width=2.5cm},
    arr/.style={-{Stealth[length=5pt]}, thick, color=black!60},
    lab/.style={font=\scriptsize, text=black!60}
]

% Nodes
\node[process] (db)
    {\textbf{PROCUREMENT DATABASE}\\
     41,000 firms $\cdot$ 4.5M tender-items\\
     {\scriptsize\itshape Participation + outcome records only}};

\node[decision, below=1.0cm of db] (screen)
    {\textbf{STAGE 1: SCREEN}\\
     Win rate $= 0$ AND\\
     Participation $\geq$ IQR threshold (14)};

\node[noaction, below left=1.0cm and 2.5cm of screen] (noflag)
    {No action};

\node[process, below right=1.0cm and -1.2cm of screen] (triage)
    {\textbf{STAGE 2: TRIAGE}\\
     Network metrics (Winner-HHI)\\
     Oversight capacity (PBU size quartile)\\
     Co-bidding concentration};

\node[decision, below=0.9cm of triage] (prio)
    {Prioritize by\\risk score};

\node[noaction, below left=0.8cm and 2.5cm of prio] (monitor)
    {Monitor\\{\scriptsize(periodic re-screen)}};

\node[process, below right=0.8cm and -1.2cm of prio] (invest)
    {\textbf{STAGE 3: INVESTIGATE}\\
     Bid-level forensics on triaged subset\\
     FL + Imhof screens (corr.\ 0.06)\\
     Bajari--Ye bid-coordination tests};

\node[output, below=0.9cm of invest] (refer)
    {\textbf{Referral to CADE / TCU / MP}\\
     {\scriptsize\itshape AUC $= 0.94$ against CADE convictions}};

% Arrows
\draw[arr] (db) -- (screen);
\draw[arr] (screen) -| node[lab, pos=0.25, above] {No flag (38,265 firms)} (noflag);
\draw[arr] (screen) -- node[lab, right, pos=0.4] {FL flag (2,735 firms)} (triage);
\draw[arr] (triage) -- (prio);
\draw[arr] (prio) -| node[lab, pos=0.25, above] {Low risk} (monitor);
\draw[arr] (prio) -- node[lab, right, pos=0.4] {High risk} (invest);
\draw[arr] (invest) -- (refer);

\end{tikzpicture}
\end{document}
)"

tikz_path <- file.path(OUT_IMG, "fig_enforcement_flowchart.tex")
writeLines(tikz_src, tikz_path)
cat("  Saved:", tikz_path, "\n")

# Try to compile TikZ to PDF
tikz_ok <- tryCatch({
  old_wd <- getwd()
  setwd(OUT_IMG)
  system2("pdflatex", c("-interaction=nonstopmode", "fig_enforcement_flowchart.tex"),
          stdout = "/dev/null", stderr = "/dev/null")
  setwd(old_wd)
  file.exists(file.path(OUT_IMG, "fig_enforcement_flowchart.pdf"))
}, error = function(e) FALSE)

if (tikz_ok) {
  cat("  Compiled TikZ to PDF:", file.path(OUT_IMG, "fig_enforcement_flowchart.pdf"), "\n")
  # Clean up aux files
  for (ext in c(".aux", ".log")) {
    f <- file.path(OUT_IMG, paste0("fig_enforcement_flowchart", ext))
    if (file.exists(f)) file.remove(f)
  }
} else {
  cat("  TikZ compilation failed — .tex and .mmd saved for manual compilation.\n")
}


# ── LaTeX snippets (for copy-pasting into the manuscript) ──
cat("\n  LaTeX figure environments:\n\n")

cat(r"(% --- Figure 1: Corner Solution ---
\begin{figure}[htbp]
\centering
\includegraphics[width=0.95\textwidth]{fig_corner_solution.pdf}
\caption{Optimal number of cover bidders $m^*$ as a function of genuine
bidders $n$. Blue region: constraint-binding corner solution under the
minimum-bidder rule ($\underline{n} = 3$, Lei~8.666/93). Gray curve:
calibrated interior solution ($\hat{\gamma} = 0.69$, strategic
complementarity). Points: empirical binned means with 95\% CIs.
Rug: distribution of $n$ in FL-present tenders.}
\label{fig:corner_solution}
\end{figure}

% --- Figure 2: Dispersion Paradox ---
\begin{figure}[htbp]
\centering
\includegraphics[width=0.95\textwidth]{fig_dispersion_paradox.pdf}
\caption{Distribution of log bid spread above winning price for FL and
non-FL losing bids. FL bids concentrate above the winner ($\bar{\epsilon}
= 0.83$) with overall $\sigma = 1.19$. Within-tender dispersion is
\emph{lower} for FL bids (CV 0.57 vs.\ 1.65; structural $\hat{\sigma}_c
/ \hat{\sigma}_g = 0.72$), rendering dispersion-based screens
ineffective under coordinated cover bidding (Regime~2).}
\label{fig:dispersion_paradox}
\end{figure}

% --- Figure 3: Enforcement Flowchart ---
\begin{figure}[htbp]
\centering
\includegraphics[width=0.95\textwidth]{images/fig_enforcement_flowchart.pdf}
\caption{Three-stage enforcement pathway. Stage~1 reduces 41,000 firms
to 2,735 FL-flagged firms using participation records alone. Stage~2
prioritizes by network structure and oversight capacity. Stage~3
deploys bid-level forensics on the triaged subset.}
\label{fig:enforcement_flowchart}
\end{figure}
)")

cat("\n\n=== figures_new.R: done ===\n")
