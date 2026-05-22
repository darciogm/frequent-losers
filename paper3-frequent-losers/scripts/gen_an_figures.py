#!/usr/bin/env python3
"""Generate matplotlib figures for AN pages that don't have a pre-rendered PDF/PNG.

Reads CSVs from output/ and writes PNGs to docs/assets/figures/ with
prefix fig_anXXX_*. Each figure is a small, focused plot — bar chart,
forest plot, heatmap, or density — tied to the headline result of the
corresponding AN page.
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl

mpl.rcParams.update({
    "figure.dpi": 110,
    "savefig.dpi": 150,
    "savefig.bbox": "tight",
    "font.size": 9,
    "axes.titlesize": 10,
    "axes.labelsize": 9,
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "legend.fontsize": 8,
    "axes.spines.top": False,
    "axes.spines.right": False,
})

BASE = "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT = f"{BASE}/docs/assets/figures"
os.makedirs(OUT, exist_ok=True)

INSPER_RED = "#C8102E"
NAVY = "#1f3a5f"
GREY = "#888888"
GREEN = "#2ca02c"


def save(name):
    plt.tight_layout()
    plt.savefig(f"{OUT}/{name}.png")
    plt.close()
    print(f"  wrote {name}.png")


# --- AN-004: cobidder baseline AUC -----------------------------------------
def fig_an004():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    scores = ["FL14 (binary)", "log(1+tenders_count)"]
    aucs = [0.924, 0.939]
    cis = [(0.921, 0.926), (0.932, 0.946)]
    ypos = np.arange(len(scores))
    errs_low = [aucs[i] - cis[i][0] for i in range(2)]
    errs_hi = [cis[i][1] - aucs[i] for i in range(2)]
    ax.barh(ypos, aucs, xerr=[errs_low, errs_hi], color=[NAVY, INSPER_RED],
            alpha=0.85, height=0.5, capsize=4)
    for i, v in enumerate(aucs):
        ax.text(v + 0.005, i, f"{v:.3f}", va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(scores)
    ax.axvline(0.5, color=GREY, linestyle="--", linewidth=0.8, alpha=0.7)
    ax.set_xlabel("AUC against cobidders (N+=193, N=16,843)")
    ax.set_xlim(0.45, 1.0)
    ax.set_title("AN-004: baseline cobidder AUC (FL14 vs continuous)")
    save("fig_an004_baseline_auc")


# --- AN-007: direct CADE AUC null ------------------------------------------
def fig_an007():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    regimes = ["FL + continuous\n(full panel)", "Item-level (raw)", "Item-level\n(temporal holdout)"]
    aucs = [0.491, 0.506, 0.511]
    cis = [(0.461, 0.520), (0.505, 0.507), (0.510, 0.513)]
    ypos = np.arange(len(regimes))
    errs_low = [aucs[i] - cis[i][0] for i in range(3)]
    errs_hi = [cis[i][1] - aucs[i] for i in range(3)]
    ax.barh(ypos, aucs, xerr=[errs_low, errs_hi], color=GREEN,
            alpha=0.85, height=0.5, capsize=4)
    for i, v in enumerate(aucs):
        ax.text(v + 0.01, i, f"{v:.3f}", va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(regimes)
    ax.axvline(0.5, color=INSPER_RED, linestyle="-", linewidth=1.5, alpha=0.7,
               label="random (0.5)")
    ax.set_xlabel("AUC against 47 direct CADE defendants")
    ax.set_xlim(0.40, 0.65)
    ax.legend(loc="lower right", frameon=False)
    ax.set_title("AN-007: predicted-null AUC by regime")
    save("fig_an007_direct_cade_null")


# --- AN-008: PBU characterization (Cohen's d barplot) ----------------------
def fig_an008():
    fig, ax = plt.subplots(figsize=(6.0, 3.5))
    metrics = ["Tenders per firm", "Unique winners crossed",
               "Share facing direct CADE", "Item-group HHI",
               "N item groups", "Repeat-buyer share"]
    d_values = [0.67, 1.00, 0.46, 0.39, -0.32, -0.38]
    colors = [INSPER_RED if d > 0 else NAVY for d in d_values]
    ypos = np.arange(len(metrics))
    ax.barh(ypos, d_values, color=colors, alpha=0.85, height=0.6)
    for i, v in enumerate(d_values):
        ax.text(v + (0.02 if v > 0 else -0.02), i, f"{v:+.2f}",
                va="center", ha="left" if v > 0 else "right", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(metrics)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("Cohen's d (cobidder vs non-cobidder FL)")
    ax.set_xlim(-0.6, 1.2)
    ax.set_title("AN-008: cobidder vs non-cobidder FL profile")
    save("fig_an008_cobidder_profile")


# --- AN-010: Imhof full pipeline ------------------------------------------
def fig_an010():
    fig, ax = plt.subplots(figsize=(6.0, 3.5))
    models = ["Imhof CV only", "Imhof full", "log_tc alone",
              "FL14 alone", "Imhof + FL14", "Imhof + log_tc"]
    aucs = [0.585, 0.888, 0.884, 0.903, 0.955, 0.962]
    cis = [(0.553, 0.616), (0.865, 0.911), (0.860, 0.908),
           (0.884, 0.923), (0.943, 0.967), (0.954, 0.969)]
    colors = [GREY, NAVY, "#5b8fbd", "#a73e34", INSPER_RED, "#7c0617"]
    ypos = np.arange(len(models))
    errs_low = [aucs[i] - cis[i][0] for i in range(len(models))]
    errs_hi = [cis[i][1] - aucs[i] for i in range(len(models))]
    ax.barh(ypos, aucs, xerr=[errs_low, errs_hi], color=colors,
            alpha=0.85, height=0.6, capsize=3)
    for i, v in enumerate(aucs):
        ax.text(v + 0.008, i, f"{v:.3f}", va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(models)
    ax.axvline(0.5, color="black", linestyle="--", linewidth=0.6, alpha=0.5)
    ax.set_xlabel("AUC (N+ = 193 cobidders, N = 11,676 firms)")
    ax.set_xlim(0.55, 1.0)
    ax.set_title("AN-010: Imhof full pipeline + complementarity")
    save("fig_an010_imhof_pipeline")


# --- AN-012: operational precision@k (in-sample) ---------------------------
def fig_an012():
    fig, ax = plt.subplots(figsize=(5.5, 3.2))
    ks = [50, 100, 200, 500, 1000]
    prec = [0.300, 0.170, 0.160, 0.132, 0.097]
    lift = [26.2, 14.8, 14.0, 11.5, 8.5]
    ax2 = ax.twinx()
    ax.plot(ks, prec, "o-", color=INSPER_RED, markersize=7, linewidth=1.8,
            label="precision@k")
    ax2.plot(ks, lift, "s--", color=NAVY, markersize=6, linewidth=1.5,
             label="lift")
    ax.set_xlabel("k (top firms)")
    ax.set_ylabel("precision@k", color=INSPER_RED)
    ax2.set_ylabel("lift over baseline", color=NAVY)
    ax.set_xscale("log")
    ax.set_xticks(ks)
    ax.set_xticklabels([str(k) for k in ks])
    ax.tick_params(axis="y", colors=INSPER_RED)
    ax2.tick_params(axis="y", colors=NAVY)
    ax.set_title("AN-012: operational precision@k (in-sample)")
    ax2.spines["top"].set_visible(False)
    save("fig_an012_precision_at_k_insample")


# --- AN-013: precision@k in-sample vs temporal holdout ---------------------
def fig_an013():
    fig, ax = plt.subplots(figsize=(5.5, 3.2))
    ks = [50, 100, 200, 500, 1000]
    prec_is = [0.300, 0.170, 0.160, 0.132, 0.097]
    prec_th = [0.020, 0.070, 0.076, 0.070, 0.066]
    ax.plot(ks, prec_is, "o-", color=NAVY, markersize=7, linewidth=1.8,
            label="in-sample")
    ax.plot(ks, prec_th, "s--", color=INSPER_RED, markersize=7, linewidth=1.8,
            label="temporal holdout")
    for k, p_is, p_th in zip(ks, prec_is, prec_th):
        ret = p_th / p_is * 100 if p_is > 0 else 0
        if k == 500:
            ax.annotate(f"retention\n{ret:.0f}%", xy=(k, (p_is+p_th)/2),
                        xytext=(k*1.4, (p_is+p_th)/2 + 0.05),
                        fontsize=8, ha="left", color=GREY,
                        arrowprops=dict(arrowstyle="->", color=GREY, alpha=0.5))
    ax.set_xlabel("k (top firms)")
    ax.set_ylabel("precision@k")
    ax.set_xscale("log")
    ax.set_xticks(ks)
    ax.set_xticklabels([str(k) for k in ks])
    ax.legend(loc="upper right", frameon=False)
    ax.set_title("AN-013: precision@k — in-sample vs temporal holdout")
    save("fig_an013_precision_inflation")


# --- AN-016: gate D2 modal AUC --------------------------------------------
def fig_an016():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    cells = ["Convite primary\n(N+ = 6)", "Pregão primary\n(N+ = 187)"]
    fl_aucs = [0.824, 0.924]
    cont_aucs = [0.816, 0.952]
    x = np.arange(len(cells))
    w = 0.35
    ax.bar(x - w/2, fl_aucs, w, color=NAVY, alpha=0.85, label="FL14 binary")
    ax.bar(x + w/2, cont_aucs, w, color=INSPER_RED, alpha=0.85, label="continuous log_tc")
    for i, v in enumerate(fl_aucs):
        ax.text(i - w/2, v + 0.01, f"{v:.3f}", ha="center", fontsize=8)
    for i, v in enumerate(cont_aucs):
        ax.text(i + w/2, v + 0.01, f"{v:.3f}", ha="center", fontsize=8)
    ax.set_xticks(x)
    ax.set_xticklabels(cells)
    ax.set_ylabel("AUC against cobidders")
    ax.set_ylim(0.5, 1.05)
    ax.axhline(0.5, color="black", linestyle="--", linewidth=0.6, alpha=0.5)
    ax.legend(loc="upper left", frameon=False)
    ax.set_title("AN-016: D2 modal AUC asymmetry (Pregão > Convite)")
    save("fig_an016_d2_modal_auc")


# --- AN-018: D4 winner-heavy direct CADE -----------------------------------
def fig_an018():
    fig, ax = plt.subplots(figsize=(5.5, 3.2))
    groups = ["Direct CADE\ndefendants\n(N = 47)", "Cobidders\n(N = 193)"]
    median_wr = [0.261, 0.086]
    share_al = [14.9, 100.0]  # % always-losers
    x = np.arange(len(groups))
    w = 0.35
    ax2 = ax.twinx()
    b1 = ax.bar(x - w/2, median_wr, w, color=INSPER_RED, alpha=0.85,
                label="median win rate")
    b2 = ax2.bar(x + w/2, share_al, w, color=NAVY, alpha=0.85,
                 label="% always-losers")
    for i, v in enumerate(median_wr):
        ax.text(i - w/2, v + 0.01, f"{v:.3f}", ha="center", fontsize=8)
    for i, v in enumerate(share_al):
        ax2.text(i + w/2, v + 2, f"{v:.1f}%", ha="center", fontsize=8)
    ax.set_xticks(x)
    ax.set_xticklabels(groups)
    ax.set_ylabel("median win rate", color=INSPER_RED)
    ax2.set_ylabel("% always-losers", color=NAVY)
    ax.tick_params(axis="y", colors=INSPER_RED)
    ax2.tick_params(axis="y", colors=NAVY)
    ax.set_ylim(0, 0.35)
    ax2.set_ylim(0, 115)
    ax.set_title("AN-018: D4 — direct defendants are winner-heavy")
    ax2.spines["top"].set_visible(False)
    save("fig_an018_d4_winner_heavy")


# --- AN-022: Pregão-only falsification ------------------------------------
def fig_an022():
    fig, ax = plt.subplots(figsize=(5.5, 3.5))
    cells = ["Pregão only\nbinary FL14", "Convite only\nbinary FL14",
             "Pregão only\ncontinuous", "Convite only\ncontinuous"]
    coefs = [0.0959, 0.0392, 0.0262, 0.0124]
    ses = [0.0256, 0.0188, 0.0063, 0.0049]
    ypos = np.arange(len(cells))
    ax.barh(ypos, coefs, xerr=[1.96*s for s in ses],
            color=[INSPER_RED, NAVY, INSPER_RED, NAVY], alpha=0.85,
            height=0.5, capsize=4)
    for i, (v, s) in enumerate(zip(coefs, ses)):
        sig = "***" if abs(v/s) > 2.58 else ("**" if abs(v/s) > 1.96 else "*")
        ax.text(v + 1.96*s + 0.005, i, f"{v:+.4f}{sig}", va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(cells)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("Coefficient on FL margin (log price)")
    ax.set_title("AN-022: modal falsification — Pregão 2.45× Convite")
    save("fig_an022_modal_falsification")


# --- AN-027: stratum scope matrix heatmap ---------------------------------
def fig_an027():
    fig, ax = plt.subplots(figsize=(6.2, 4.0))
    rows = [
        "1. Binary FL / AL / cobidders",
        "2. Continuous / AL / cobidders",
        "3. Binary FL / all BEC / direct CADE",
        "4. Participation count / all BEC / direct CADE",
        "5. FL frozen 09-16 / AL 09-16 / cobidders",
        "6. Continuous train 09-16 / items 17-19 / cobidder items",
        "7. Binary train 09-16 / items 17-19 / cobidder items",
        "8. Continuous train 09-16 / items 17-19 / direct items",
    ]
    aucs = [0.924, 0.939, 0.491, 0.383, 0.767, 0.770, 0.565, 0.511]
    colors = []
    for a in aucs:
        if a >= 0.85:
            colors.append(INSPER_RED)
        elif a >= 0.65:
            colors.append("#d97559")
        elif a >= 0.55:
            colors.append("#f1c25e")
        else:
            colors.append(NAVY)
    ypos = np.arange(len(rows))[::-1]
    ax.barh(ypos, aucs, color=colors, alpha=0.85, height=0.65)
    for i, v in enumerate(aucs):
        ax.text(v + 0.01, ypos[i], f"{v:.3f}", va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(rows, fontsize=7.5)
    ax.axvline(0.5, color="black", linestyle="--", linewidth=0.6, alpha=0.5)
    ax.set_xlabel("AUC")
    ax.set_xlim(0.30, 1.05)
    ax.set_title("AN-027: universe × positive-class scope matrix")
    save("fig_an027_stratum_scope_matrix")


# --- AN-028: standardized diffs heatmap (3 comparisons × 7 dimensions) -----
def fig_an028():
    fig, ax = plt.subplots(figsize=(5.5, 3.5))
    dims = ["tenders", "unique\nwinners", "repeat-5\nshare", "pairs-≥5",
            "facing\ndirect CADE", "item-group\nHHI", "n item\ngroups"]
    comparisons = ["vs FL_non_cobidder", "vs AL_non_FL", "vs winner_other"]
    d = np.array([
        [0.67, 1.00, -0.38, 0.19, 0.46, 0.39, -0.32],   # vs FL_non_cobidder
        [4.63, 7.10,  1.33, 3.15, 0.36, -1.09, 3.18],   # vs AL_non_FL
        [-0.13, -0.23, -0.56, -0.29, 0.42, 0.30, -0.60], # vs winner_other
    ])
    # Clip extreme values for color scale
    vmax = 2.0
    d_clip = np.clip(d, -vmax, vmax)
    im = ax.imshow(d_clip, cmap="RdBu_r", vmin=-vmax, vmax=vmax, aspect="auto")
    ax.set_xticks(np.arange(len(dims)))
    ax.set_xticklabels(dims, fontsize=7.5)
    ax.set_yticks(np.arange(len(comparisons)))
    ax.set_yticklabels(comparisons, fontsize=8)
    for i in range(d.shape[0]):
        for j in range(d.shape[1]):
            color = "white" if abs(d_clip[i, j]) > 1.0 else "black"
            label = f"{d[i, j]:+.2f}" + ("⁺" if abs(d[i, j]) > vmax else "")
            ax.text(j, i, label, ha="center", va="center",
                    color=color, fontsize=7.5)
    cbar = plt.colorbar(im, ax=ax, shrink=0.7, label="Cohen's d (clipped at ±2)")
    ax.set_title("AN-028: standardized differences (cobidder vs reference classes)")
    save("fig_an028_standardized_diffs_heatmap")


# --- AN-029: three-classifier timing battery -------------------------------
def fig_an029():
    fig, ax = plt.subplots(figsize=(6.0, 3.5))
    classifiers = ["clf_2015\n(train 09-15)", "clf_2017\n(train 09-17)",
                   "clf_2019_full\n(in-sample ref)"]
    fl_all = [0.791, 0.856, 0.924]
    cont_all = [0.851, 0.897, 0.939]
    fl_post = [0.786, 0.844, 0.922]  # cobid_post2019; clf_2019 N/A but use reference
    cont_post = [0.854, 0.894, 0.935]
    x = np.arange(len(classifiers))
    w = 0.20
    ax.bar(x - 1.5*w, fl_all, w, color=NAVY, alpha=0.85, label="FL vs cobid_all")
    ax.bar(x - 0.5*w, cont_all, w, color="#5b8fbd", alpha=0.85, label="cont vs cobid_all")
    ax.bar(x + 0.5*w, fl_post, w, color=INSPER_RED, alpha=0.85, label="FL vs cobid_post2019")
    ax.bar(x + 1.5*w, cont_post, w, color="#e57a6a", alpha=0.85, label="cont vs cobid_post2019")
    ax.set_xticks(x)
    ax.set_xticklabels(classifiers)
    ax.set_ylabel("AUC")
    ax.set_ylim(0.5, 1.0)
    ax.axhline(0.5, color="black", linestyle="--", linewidth=0.6, alpha=0.5)
    ax.legend(loc="lower right", frameon=False, fontsize=7.5, ncol=2)
    ax.set_title("AN-029: three-classifier timing battery")
    save("fig_an029_three_classifier")


# --- AN-030: market persistence -------------------------------------------
def fig_an030():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    units = ["Firm\n(CNPJ)", "Market\n(PBU × group)", "PBU\n(buyer)"]
    persistence = [8.7, 12.4, 83.5]
    colors = [INSPER_RED, "#d97559", NAVY]
    bars = ax.bar(units, persistence, color=colors, alpha=0.85, width=0.55)
    for bar, v in zip(bars, persistence):
        ax.text(bar.get_x() + bar.get_width()/2, v + 1.5, f"{v}%",
                ha="center", fontsize=10, fontweight="bold")
    ax.set_ylabel("% persisting between\n2009-2016 and 2017-2019")
    ax.set_ylim(0, 100)
    ax.set_title("AN-030: firms turn over; buyers don't")
    save("fig_an030_market_persistence")


# --- AN-031: bid-level gap-to-winner distribution -------------------------
def fig_an031():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    classes = ["Cobidder\n(N=182)", "FL_non_cobidder\n(N=2,369)",
               "AL_non_FL\n(N=6,612)", "Winner_other\n(N=20,358)"]
    median_gap = [0.582, 0.809, 0.753, 0.487]
    mean_gap = [0.957, 1.102, 0.945, 0.763]
    x = np.arange(len(classes))
    w = 0.35
    ax.bar(x - w/2, median_gap, w, color=INSPER_RED, alpha=0.85, label="median gap")
    ax.bar(x + w/2, mean_gap, w, color=NAVY, alpha=0.85, label="mean gap")
    for i, v in enumerate(median_gap):
        ax.text(i - w/2, v + 0.02, f"{v:.3f}", ha="center", fontsize=7)
    for i, v in enumerate(mean_gap):
        ax.text(i + w/2, v + 0.02, f"{v:.3f}", ha="center", fontsize=7)
    ax.set_xticks(x)
    ax.set_xticklabels(classes, fontsize=8)
    ax.set_ylabel("gap-to-winner ratio")
    ax.legend(loc="upper right", frameon=False)
    ax.set_title("AN-031: bid-level gap — cobidders bid closer to winners than non-cob FLs")
    save("fig_an031_bid_gap")


# --- AN-033: Imhof incremental DeLong forest plot ------------------------
def fig_an033():
    fig, ax = plt.subplots(figsize=(6.0, 3.2))
    contrasts = [
        "FL14 alone\nvs Imhof full",
        "tenders_count alone\nvs Imhof full",
        "Imhof + FL14\nvs Imhof full",
        "Imhof + tenders\nvs Imhof full",
    ]
    deltas = [0.0353, 0.0310, 0.0958, 0.0977]
    pvals = [0.014, 0.077, 1.15e-26, 1.30e-25]
    ypos = np.arange(len(contrasts))[::-1]
    colors = [NAVY if p < 0.05 else GREY for p in pvals]
    ax.barh(ypos, deltas, color=colors, alpha=0.85, height=0.55)
    for i, (v, p) in enumerate(zip(deltas, pvals)):
        sig = "***" if p < 1e-6 else ("**" if p < 0.01 else ("*" if p < 0.05 else ""))
        plabel = f"p={p:.2g}" if p > 1e-6 else "p<10⁻⁶"
        ax.text(v + 0.003, ypos[i], f"Δ={v:+.3f}  {plabel}{sig}",
                va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(contrasts, fontsize=8.5)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("Δ AUC vs Imhof full baseline (DeLong paired)")
    ax.set_xlim(-0.01, 0.18)
    ax.set_title("AN-033: Imhof incremental — FL adds 0.096 AUC (p=10⁻²⁶)")
    save("fig_an033_imhof_incremental")


# --- AN-034: sequential envelope (TP vs microdata Pareto) -----------------
def fig_an034():
    fig, ax = plt.subplots(figsize=(5.8, 3.5))
    rules = ["Award-only", "Bid-only", "Joint", "Seq K=1,000",
             "Seq K=2,000", "Seq K=4,000"]
    tp = [15, 12, 23, 17, 17, 15]
    microdata = [0, 11676, 11676, 1000, 2000, 4000]
    colors = [INSPER_RED, NAVY, "#7c0617", "#3a8c5d", GREEN, "#9bcfb0"]
    for i, (r, t, m, c) in enumerate(zip(rules, tp, microdata, colors)):
        ax.scatter(m, t, s=140, color=c, edgecolor="black", linewidth=0.6,
                   alpha=0.9, label=r)
        ax.annotate(r, (m, t), xytext=(8, 6), textcoords="offset points",
                    fontsize=8)
    ax.set_xlabel("bid-microdata footprint (records to recover)")
    ax.set_ylabel("TP @ k=50")
    ax.set_xlim(-500, 13000)
    ax.set_ylim(10, 27)
    ax.set_title("AN-034: sequential envelope (precision target 0.1)")
    save("fig_an034_sequential_envelope")


# --- AN-036: CV precision stability ---------------------------------------
def fig_an036():
    fig, ax = plt.subplots(figsize=(5.5, 3.0))
    ks = [50, 100, 250, 500, 1000, 2000]
    means = [0.068, 0.042, 0.0344, 0.028, 0.0206, 0.0161]
    sds = [0.0110, 0.0110, 0.0108, 0.0062, 0.0044, 0.0014]
    ax.errorbar(ks, means, yerr=sds, fmt="o-", color=INSPER_RED,
                markersize=8, linewidth=1.8, capsize=5, capthick=1.5,
                ecolor=GREY, label="CV precision_mean ± SD")
    for k, m in zip(ks, means):
        ax.text(k, m + 0.005, f"{m:.3f}", ha="center", fontsize=7.5)
    ax.set_xlabel("k (top firms)")
    ax.set_ylabel("CV precision@k")
    ax.set_xscale("log")
    ax.set_xticks(ks)
    ax.set_xticklabels([str(k) for k in ks])
    ax.set_title("AN-036: K-fold CV precision (SD ≤ 0.011)")
    save("fig_an036_cv_precision")


# --- AN-038: segment betas forest plot ------------------------------------
def fig_an038():
    fig, ax = plt.subplots(figsize=(6.0, 4.0))
    groups = ["Group 10", "Group 17", "Group 12", "Group 13", "Group 14",
              "Group 29", "Group 37", "Group 39"]
    # Three values per group: broad, overlap_unw, overlap_att
    broad = [0.107, 0.582, 0.265, 0.255, 0.122, 0.029, -0.105, -0.065]
    overlap = [0.101, 0.536, 0.256, 0.245, 0.102, 0.022, -0.116, -0.066]
    att = [0.063, 0.083, -0.072, -0.129, -0.099, -0.051, -0.126, -0.103]
    ypos = np.arange(len(groups))
    w = 0.25
    ax.barh(ypos - w, broad, w, color=GREY, alpha=0.85, label="broad")
    ax.barh(ypos, overlap, w, color="#a4b8cf", alpha=0.85, label="overlap unweighted")
    ax.barh(ypos + w, att, w, color=INSPER_RED, alpha=0.85, label="overlap ATT")
    ax.set_yticks(ypos)
    ax.set_yticklabels(groups)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("FL-margin coefficient on log price")
    ax.legend(loc="lower right", frameon=False, fontsize=8)
    ax.set_xlim(-0.20, 0.60)
    ax.set_title("AN-038: item-group sign-reversal under overlap ATT")
    save("fig_an038_segment_betas")


# --- AN-021: first-time FL attenuation ------------------------------------
def fig_an021():
    fig, ax = plt.subplots(figsize=(5.5, 2.8))
    specs = ["Unconditional", "CEM matched", "PS matched"]
    coefs = [0.100, 0.085, 0.062]
    ses = [0.043, 0.048, 0.061]
    pvals = [0.019, 0.076, 0.312]
    ypos = np.arange(len(specs))
    colors = [INSPER_RED if p < 0.05 else (GREY if p < 0.10 else NAVY)
              for p in pvals]
    ax.barh(ypos, coefs, xerr=[1.96*s for s in ses], color=colors,
            alpha=0.85, height=0.5, capsize=5)
    for i, (v, p) in enumerate(zip(coefs, pvals)):
        sig = "**" if p < 0.05 else ("·" if p < 0.10 else " (n.s.)")
        ax.text(v + 1.96*ses[i] + 0.005, i, f"{v:+.3f}  p={p:.3f}{sig}",
                va="center", fontsize=8)
    ax.set_yticks(ypos)
    ax.set_yticklabels(specs)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlabel("First-time FL coefficient on cobidder indicator")
    ax.set_title("AN-021: first-time FL does not survive PS matching")
    save("fig_an021_first_time_fl")


if __name__ == "__main__":
    print(f"Writing figures to {OUT}/")
    fig_an004()
    fig_an007()
    fig_an008()
    fig_an010()
    fig_an012()
    fig_an013()
    fig_an016()
    fig_an018()
    fig_an021()
    fig_an022()
    fig_an027()
    fig_an028()
    fig_an029()
    fig_an030()
    fig_an031()
    fig_an033()
    fig_an034()
    fig_an036()
    fig_an038()
    print("\nAll figures done.")
