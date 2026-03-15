#!/usr/bin/env python3
# ============================================================================
# roc_detection.py — ROC analysis for FL screening using CADE ground truth (v6)
# Paper 3 v6: Frequent Losers in Public Procurement
# ============================================================================
# Purpose: Evaluate the FL screening tool's detection performance by varying
#          the IQR multiplier threshold and computing TPR/FPR against CADE
#          ground truth (firms co-bidding with convicted cartelists).
# Outputs:
#   - work/v6/images/fig_roc_fl_screen.pdf
#   - work/v6/tables/tab_roc_detection.tex
#   - work/v6/FLAG_roc.txt (if data missing)
# ============================================================================

import os
import sys
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime

# ---- Path constants ---------------------------------------------------------
BASE_DIR = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
DATA_DIR = BASE_DIR / "data" / "processed"
V6_DIR   = BASE_DIR / "work" / "v6"
OUT_TAB  = V6_DIR / "tables"
OUT_IMG  = V6_DIR / "images"
FLAG_DIR = V6_DIR

OUT_TAB.mkdir(parents=True, exist_ok=True)
OUT_IMG.mkdir(parents=True, exist_ok=True)

# ---- Check required data ----------------------------------------------------
FP_FILE   = DATA_DIR / "FREQ_PARTICIP_rebuilt.parquet"
CADE_FILE = DATA_DIR / "cade_fl_cobidders.csv"
FLS_FILE  = DATA_DIR / "firm_loss_stats.parquet"

missing = []
if not FP_FILE.exists():
    missing.append(f"FREQ_PARTICIP_rebuilt.parquet at {FP_FILE}")
if not CADE_FILE.exists():
    missing.append(f"cade_fl_cobidders.csv at {CADE_FILE}")

if missing:
    flag_msg = (
        "FLAG: ROC detection analysis cannot run.\n"
        "Missing data:\n" +
        "\n".join(f"  - {m}" for m in missing) +
        f"\n\nTimestamp: {datetime.now()}\n"
    )
    flag_path = FLAG_DIR / "FLAG_roc.txt"
    flag_path.write_text(flag_msg)
    print(f"  FLAG written to: {flag_path}")
    sys.exit(0)

# ---- Load data --------------------------------------------------------------
print("=== roc_detection.py: ROC analysis for FL screen ===")

print("  Loading FREQ_PARTICIP_rebuilt.parquet...")
fp = pd.read_parquet(FP_FILE)
# Standardize firm ID column
firm_col = [c for c in fp.columns if "fornecedor" in c.lower()]
if firm_col and "firm_id" not in fp.columns:
    fp = fp.rename(columns={firm_col[0]: "firm_id"})
fp["firm_id"] = fp["firm_id"].astype(str).str.strip()
print(f"  Always-losers (FREQ_PARTICIP): {len(fp):,} firms")
print(f"  Columns: {list(fp.columns)}")

print("  Loading cade_fl_cobidders.csv...")
cade = pd.read_csv(CADE_FILE)
# Standardize firm ID column
cade_firm_col = [c for c in cade.columns if "fornecedor" in c.lower() or "firm" in c.lower() or "codigo" in c.lower() or "código" in c.lower()]
if cade_firm_col and "firm_id" not in cade.columns:
    cade = cade.rename(columns={cade_firm_col[0]: "firm_id"})
cade["firm_id"] = cade["firm_id"].astype(str).str.strip()
print(f"  CADE co-bidders: {len(cade):,} FL firms")
print(f"  Columns: {list(cade.columns)}")

# Also load firm_loss_stats for the full universe of always-losers
fls = None
if FLS_FILE.exists():
    print("  Loading firm_loss_stats.parquet...")
    fls = pd.read_parquet(FLS_FILE)
    fls_col = [c for c in fls.columns if "fornecedor" in c.lower()]
    if fls_col and "firm_id" not in fls.columns:
        fls = fls.rename(columns={fls_col[0]: "firm_id"})
    fls["firm_id"] = fls["firm_id"].astype(str).str.strip()
    print(f"  Firm loss stats: {len(fls):,} firms")

# ---- Define ground truth ----------------------------------------------------
# Ground truth: FL firms that co-bid with CADE-convicted cartelists
# These are plausible collusion suspects.
# The CADE file has 193 FL firms that co-bid with CADE cartelists.

# We need: for each always-loser, is it a "true positive" (co-bids with CADE)?
# And the "score" is tenders_count (more participations = more suspicious).

cade_positive_ids = set(cade["firm_id"].unique())
print(f"  Ground truth positives (CADE co-bidders among FL): {len(cade_positive_ids)}")

# Check overlap
fp_ids = set(fp["firm_id"].unique())
overlap = cade_positive_ids & fp_ids
print(f"  Overlap with FREQ_PARTICIP: {len(overlap)} / {len(cade_positive_ids)}")

# Mark ground truth
fp["is_cade_cobidder"] = fp["firm_id"].isin(cade_positive_ids).astype(int)
print(f"  CADE co-bidders in FREQ_PARTICIP: {fp['is_cade_cobidder'].sum()}")

# ---- Compute IQR threshold parameters --------------------------------------
q25 = fp["tenders_count"].quantile(0.25)
q50 = fp["tenders_count"].quantile(0.50)  # median
q75 = fp["tenders_count"].quantile(0.75)
iqr_val = q75 - q25

print(f"  Tenders count: Q25={q25:.0f}, Q50={q50:.0f}, Q75={q75:.0f}, IQR={iqr_val:.0f}")

# The paper uses: threshold = median + multiplier * IQR
# Baseline: multiplier = 1.5 -> threshold ~ 14
baseline_threshold = q50 + 1.5 * iqr_val
print(f"  Baseline threshold (1.5x IQR): {baseline_threshold:.1f}")

# ---- Vary IQR multiplier and compute TPR/FPR --------------------------------
print("  Computing ROC curve by varying IQR multiplier...")

multipliers = np.arange(0.0, 5.05, 0.05)
results = []

total_positive = fp["is_cade_cobidder"].sum()
total_negative = len(fp) - total_positive

if total_positive == 0:
    flag_msg = (
        "FLAG: No ground truth positives found.\n"
        f"CADE co-bidder IDs: {len(cade_positive_ids)}\n"
        f"Overlap with FREQ_PARTICIP: {len(overlap)}\n"
        f"This may indicate a firm_id matching issue.\n"
        f"\nCADE firm_id sample: {list(cade['firm_id'].head(5))}\n"
        f"FP firm_id sample: {list(fp['firm_id'].head(5))}\n"
        f"\nTimestamp: {datetime.now()}\n"
    )
    flag_path = FLAG_DIR / "FLAG_roc.txt"
    flag_path.write_text(flag_msg)
    print(f"  FLAG written to: {flag_path}")
    sys.exit(0)

for mult in multipliers:
    threshold = q50 + mult * iqr_val
    # "Flagged" = firms with tenders_count > threshold (predicted positive)
    flagged = fp["tenders_count"] > threshold
    n_flagged = flagged.sum()

    # True positives: flagged AND is_cade_cobidder
    tp = (flagged & (fp["is_cade_cobidder"] == 1)).sum()
    fp_count = (flagged & (fp["is_cade_cobidder"] == 0)).sum()
    fn = ((~flagged) & (fp["is_cade_cobidder"] == 1)).sum()
    tn = ((~flagged) & (fp["is_cade_cobidder"] == 0)).sum()

    tpr = tp / total_positive if total_positive > 0 else 0
    fpr = fp_count / total_negative if total_negative > 0 else 0

    # Precision and F1
    precision = tp / (tp + fp_count) if (tp + fp_count) > 0 else 0
    f1 = 2 * precision * tpr / (precision + tpr) if (precision + tpr) > 0 else 0

    results.append({
        "multiplier": mult,
        "threshold": threshold,
        "n_flagged": n_flagged,
        "tp": tp, "fp": fp_count, "fn": fn, "tn": tn,
        "tpr": tpr, "fpr": fpr,
        "precision": precision, "f1": f1,
        "youden_j": tpr - fpr
    })

roc_df = pd.DataFrame(results)

# ---- Compute AUC using trapezoidal rule --------------------------------------
# Sort by FPR for proper integration
roc_sorted = roc_df.sort_values("fpr").reset_index(drop=True)
# Remove duplicates in FPR (keep one with highest TPR)
roc_unique = roc_sorted.groupby("fpr").agg({"tpr": "max"}).reset_index().sort_values("fpr")

# Add (0,0) and (1,1) endpoints if not present
if roc_unique["fpr"].iloc[0] > 0:
    roc_unique = pd.concat([pd.DataFrame({"fpr": [0], "tpr": [0]}), roc_unique], ignore_index=True)
if roc_unique["fpr"].iloc[-1] < 1:
    roc_unique = pd.concat([roc_unique, pd.DataFrame({"fpr": [1], "tpr": [1]})], ignore_index=True)

auc = np.trapz(roc_unique["tpr"], roc_unique["fpr"])
print(f"  AUC: {auc:.4f}")

# ---- Find optimal threshold (Youden's J) ------------------------------------
best_idx = roc_df["youden_j"].idxmax()
best = roc_df.loc[best_idx]
print(f"  Optimal (Youden's J = {best['youden_j']:.4f}):")
print(f"    Multiplier: {best['multiplier']:.2f}")
print(f"    Threshold: {best['threshold']:.1f}")
print(f"    TPR: {best['tpr']:.4f}, FPR: {best['fpr']:.4f}")
print(f"    Precision: {best['precision']:.4f}, F1: {best['f1']:.4f}")
print(f"    Flagged: {int(best['n_flagged']):,}")

# Baseline (1.5x) row
baseline_row = roc_df.loc[(roc_df["multiplier"] - 1.5).abs().idxmin()]
print(f"  Baseline (1.5x IQR):")
print(f"    TPR: {baseline_row['tpr']:.4f}, FPR: {baseline_row['fpr']:.4f}")
print(f"    Precision: {baseline_row['precision']:.4f}, F1: {baseline_row['f1']:.4f}")
print(f"    Flagged: {int(baseline_row['n_flagged']):,}")

# ---- Plot ROC curve ----------------------------------------------------------
print("  Plotting ROC curve...")

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages

    fig, ax = plt.subplots(1, 1, figsize=(5, 5))

    # ROC curve
    ax.plot(roc_df["fpr"], roc_df["tpr"], "b-", linewidth=1.5, label=f"FL Screen (AUC = {auc:.3f})")
    ax.plot([0, 1], [0, 1], "k--", linewidth=0.8, alpha=0.5, label="Random classifier")

    # Mark baseline (1.5x)
    ax.scatter(baseline_row["fpr"], baseline_row["tpr"],
               color="red", s=80, zorder=5, marker="o",
               label=f'Baseline (1.5x IQR)')
    ax.annotate(f'1.5x IQR\nTPR={baseline_row["tpr"]:.2f}\nFPR={baseline_row["fpr"]:.2f}',
                xy=(baseline_row["fpr"], baseline_row["tpr"]),
                xytext=(baseline_row["fpr"] + 0.1, baseline_row["tpr"] - 0.15),
                fontsize=8,
                arrowprops=dict(arrowstyle="->", color="red", lw=0.8))

    # Mark optimal
    ax.scatter(best["fpr"], best["tpr"],
               color="green", s=80, zorder=5, marker="^",
               label=f'Optimal ({best["multiplier"]:.1f}x IQR)')
    ax.annotate(f'{best["multiplier"]:.1f}x IQR\nTPR={best["tpr"]:.2f}\nFPR={best["fpr"]:.2f}',
                xy=(best["fpr"], best["tpr"]),
                xytext=(best["fpr"] + 0.12, best["tpr"] + 0.05),
                fontsize=8,
                arrowprops=dict(arrowstyle="->", color="green", lw=0.8))

    ax.set_xlabel("False Positive Rate")
    ax.set_ylabel("True Positive Rate")
    ax.set_title("ROC Curve: FL Screen vs. CADE Ground Truth")
    ax.legend(loc="lower right", fontsize=8)
    ax.set_xlim(-0.02, 1.02)
    ax.set_ylim(-0.02, 1.02)
    ax.set_aspect("equal")
    ax.grid(True, alpha=0.3)

    fig.tight_layout()

    pdf_path = OUT_IMG / "fig_roc_fl_screen.pdf"
    fig.savefig(pdf_path, dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  ROC figure saved to: {pdf_path}")

except ImportError as e:
    print(f"  WARNING: matplotlib not available ({e}). Skipping figure.")
    # Write flag about missing matplotlib
    flag_path = FLAG_DIR / "FLAG_roc_figure.txt"
    flag_path.write_text(
        f"FLAG: ROC figure could not be generated.\n"
        f"matplotlib import error: {e}\n"
        f"ROC table was still generated.\n"
        f"Timestamp: {datetime.now()}\n"
    )

# ---- Write LaTeX table ------------------------------------------------------
print("  Writing LaTeX table...")

# Select key multipliers for the table
key_mults = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0]
# Also include optimal if not already in list
opt_mult = round(best["multiplier"], 1)
if opt_mult not in key_mults:
    key_mults.append(opt_mult)
    key_mults.sort()

tex_lines = [
    r"\begin{table}[htbp]",
    r"\centering",
    r"\caption{ROC Analysis: FL Screening Performance by IQR Multiplier}",
    r"\label{tab:roc_detection}",
    r"\begin{adjustbox}{max width=\textwidth}",
    r"\begin{threeparttable}",
    r"\small",
    r"\begin{tabular}{lcccccccc}",
    r"\toprule",
    r"IQR & Threshold & Flagged & TP & FP & TPR & FPR & Precision & Youden's $J$ \\",
    r"Multiplier & & Firms & & & (Sensitivity) & (1-Specificity) & & \\",
    r"\midrule",
]

for mult in key_mults:
    row = roc_df.loc[(roc_df["multiplier"] - mult).abs().idxmin()]
    is_baseline = abs(mult - 1.5) < 0.01
    is_optimal = abs(mult - best["multiplier"]) < 0.01

    marker = ""
    if is_baseline and is_optimal:
        marker = r"$^{\dagger\ddagger}$"
    elif is_baseline:
        marker = r"$^{\dagger}$"
    elif is_optimal:
        marker = r"$^{\ddagger}$"

    tex_lines.append(
        f"{mult:.1f}{marker} & {row['threshold']:.0f} & "
        f"{int(row['n_flagged']):,} & {int(row['tp'])} & {int(row['fp']):,} & "
        f"{row['tpr']:.3f} & {row['fpr']:.3f} & {row['precision']:.3f} & "
        f"{row['youden_j']:.3f} \\\\"
    )

tex_lines.extend([
    r"\midrule",
    f"AUC & \\multicolumn{{8}}{{c}}{{{auc:.4f}}} \\\\",
    r"\bottomrule",
    r"\end{tabular}",
    r"\begin{tablenotes}",
    r"\small",
    r"\item \textit{Notes:} ROC analysis varying the IQR multiplier for the FL",
    r"threshold (median + multiplier $\times$ IQR of participation counts among",
    r"always-losers). Ground truth: 193 FL firms that co-bid with CADE-convicted",
    f"cartelists. Total always-losers: {len(fp):,} (positives: {total_positive},",
    f"negatives: {total_negative:,}).",
    r"$^{\dagger}$ = baseline threshold used in the paper;",
    r"$^{\ddagger}$ = Youden's $J$-optimal threshold.",
    r"\end{tablenotes}",
    r"\end{threeparttable}",
    r"\end{adjustbox}",
    r"\end{table}",
])

tex_path = OUT_TAB / "tab_roc_detection.tex"
tex_path.write_text("\n".join(tex_lines))
print(f"  LaTeX table saved to: {tex_path}")

# ---- Save full ROC data for reference ----------------------------------------
roc_csv_path = OUT_TAB / "roc_detection_full.csv"
roc_df.to_csv(roc_csv_path, index=False)
print(f"  Full ROC data saved to: {roc_csv_path}")

print("  Done.")
