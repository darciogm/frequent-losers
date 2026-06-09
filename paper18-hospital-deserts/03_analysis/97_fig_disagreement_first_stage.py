"""
LaTeX caption (do not bake into figure):

\\begin{figure}[htbp]
\\centering
\\includegraphics[width=\\linewidth]{fig_disagreement_first_stage}
\\caption{\\textbf{Sun--Abraham ATTs by disagreement group --- PNASH psychiatric sample.}
Population-weighted Sun--Abraham average treatment effects on the treated (ATTs)
for three disagreement groups relative to never-flagged control municipalities,
estimated in the PNASH psychiatric sample.
\\textit{Panel A} (travel burden) shows that all three groups experience a mechanical
shift in travel distance after a nearby hospital closure; the outcome does not
discriminate between groups.
\\textit{Panel B} (psychiatric admissions per 1{,}000) is the discriminating first-stage
outcome: flow-flagged municipalities (``Flow-only'' and ``Both'') lose substantially
more inpatient psychiatric volume than distance-only false positives, whose much
smaller ATT also fails the pre-trend test ($p < 0.001$), raising concerns about
contamination by pre-existing trends.
Pre-trend $p$-values (joint test across pre-event periods) are annotated next to
each point; a missing annotation indicates the test was not estimable.
Horizontal bars are 95\\% confidence intervals.}
\\label{fig:disagreement_first_stage}
\\end{figure}
"""

import csv
import math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

# ------------------------------------------------------------------
# 0.  Load data (stdlib only — no pandas dependency assumption)
# ------------------------------------------------------------------
DATA_PATH = "02_data/processed/disagreement_placebo_results.csv"
FIG_PATH  = "04_figures/fig_disagreement_first_stage.pdf"

rows = []
with open(DATA_PATH, newline="") as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        rows.append(row)

# Filter: PNASH_psychiatric only, outcomes of interest
TARGET_OUTCOMES = {"travel_burden_km", "psych_adm_per1k"}
TARGET_GROUPS   = ["flow_only", "both", "distance_only"]

data = {}   # data[outcome][group] = dict
for row in rows:
    if row["sample"] != "PNASH_psychiatric":
        continue
    if row["outcome"] not in TARGET_OUTCOMES:
        continue
    o = row["outcome"]
    g = row["group"]
    if o not in data:
        data[o] = {}
    data[o][g] = {
        "att":       float(row["att"]),
        "ci_lo":     float(row["ci_lo"]),
        "ci_hi":     float(row["ci_hi"]),
        "pretrend_p": row["pretrend_p"],   # string; may be empty
        "n_treated": int(row["n_treated"]),
    }

# ------------------------------------------------------------------
# 1.  Design tokens
# ------------------------------------------------------------------
COLOR_SIGNAL  = "#0072B2"   # Okabe-Ito blue  (flow_only, both)
COLOR_FP      = "#999999"   # grey            (distance_only)
MARKER_SIZE   = 7
CAP_SIZE      = 4
LINE_WIDTH    = 1.4
ANNOT_SIZE    = 8.0

GROUP_LABELS = {
    "flow_only":      "Flow-only\n(distance misses)",
    "both":           "Both rules",
    "distance_only":  "Distance-only\n(flow misses)",
}
GROUP_COLORS = {
    "flow_only":     COLOR_SIGNAL,
    "both":          COLOR_SIGNAL,
    "distance_only": COLOR_FP,
}

# y positions: top = flow_only (y=2), middle = both (y=1), bottom = distance_only (y=0)
Y_POS = {"flow_only": 2, "both": 1, "distance_only": 0}

# ------------------------------------------------------------------
# 2.  Matplotlib rc
# ------------------------------------------------------------------
plt.rcParams.update({
    "font.family":      "DejaVu Sans",
    "font.size":        9.5,
    "axes.linewidth":   0.8,
    "xtick.major.width": 0.8,
    "ytick.major.width": 0.8,
    "xtick.labelsize":  9.0,
    "ytick.labelsize":  9.5,
    "axes.spines.top":   False,
    "axes.spines.right": False,
    "savefig.dpi":       300,
    "savefig.bbox":     "tight",
})

# ------------------------------------------------------------------
# 3.  Plot
# ------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(7.5, 3.6))

PANEL_CONFIG = [
    ("travel_burden_km",  "A. Travel burden (km)",                  axes[0]),
    ("psych_adm_per1k",   "B. Psychiatric admissions per 1,000",    axes[1]),
]

for outcome, panel_title, ax in PANEL_CONFIG:
    od = data[outcome]

    for grp in TARGET_GROUPS:
        if grp not in od:
            continue
        d      = od[grp]
        y      = Y_POS[grp]
        att    = d["att"]
        ci_lo  = d["ci_lo"]
        ci_hi  = d["ci_hi"]
        color  = GROUP_COLORS[grp]
        p_str  = d["pretrend_p"]

        # Error bar lengths (must be positive)
        xerr_lo = att - ci_lo
        xerr_hi = ci_hi - att

        ax.errorbar(
            att, y,
            xerr=[[max(xerr_lo, 0)], [max(xerr_hi, 0)]],
            fmt="o",
            color=color,
            ecolor=color,
            elinewidth=LINE_WIDTH,
            capsize=CAP_SIZE,
            capthick=LINE_WIDTH,
            markersize=MARKER_SIZE,
            zorder=3,
        )

        # Pre-trend p annotation
        if p_str and p_str.strip():
            try:
                p_val = float(p_str)
                if p_val < 0.001:
                    p_label = "p<0.001"
                elif p_val < 0.01:
                    p_label = f"p={p_val:.3f}"
                elif p_val < 0.10:
                    p_label = f"p={p_val:.2f}"
                else:
                    p_label = f"p={p_val:.2f}"
            except ValueError:
                p_label = None

            if p_label:
                # Place annotation above the point
                ax.text(
                    att, y + 0.22,
                    p_label,
                    ha="center", va="bottom",
                    fontsize=ANNOT_SIZE,
                    color=color,
                    style="italic",
                )

    # Vertical reference line at 0
    ax.axvline(0, color="black", linewidth=0.8, linestyle="--", zorder=1)

    # Y-axis: group labels
    ax.set_yticks(list(Y_POS.values()))
    ax.set_yticklabels(
        [GROUP_LABELS[g] for g in Y_POS.keys()],
        fontsize=9.5,
    )
    ax.set_ylim(-0.7, 2.9)

    # X-axis label
    ax.set_xlabel("ATT (Sun–Abraham)", fontsize=9.5)

    # Panel title — left-aligned
    ax.set_title(panel_title, loc="left", fontsize=9.5, fontweight="bold", pad=6)

    # Light horizontal grid lines
    ax.yaxis.grid(True, linestyle=":", linewidth=0.5, color="#cccccc", zorder=0)
    ax.set_axisbelow(True)

    # Spine cleanup
    ax.spines["left"].set_visible(False)
    ax.tick_params(axis="y", length=0)

fig.tight_layout(w_pad=2.5)
fig.savefig(FIG_PATH, format="pdf")
print(f"Saved: {FIG_PATH}")

# ------------------------------------------------------------------
# 4.  Print values for audit
# ------------------------------------------------------------------
print("\n=== Values plotted (PNASH_psychiatric) ===")
for outcome in ("travel_burden_km", "psych_adm_per1k"):
    print(f"\nOutcome: {outcome}")
    for grp in TARGET_GROUPS:
        if grp in data.get(outcome, {}):
            d = data[outcome][grp]
            p_str = d["pretrend_p"] if d["pretrend_p"] else "NA"
            print(
                f"  {grp:20s}  ATT={d['att']:+.4f}  "
                f"95% CI [{d['ci_lo']:+.4f}, {d['ci_hi']:+.4f}]  "
                f"p_pretrend={p_str}  n={d['n_treated']}"
            )
