#!/usr/bin/env python3
"""
24_thickness_analysis.py — Market-thickness heterogeneity (Table 5 + Figure 1)

Purpose
-------
Reproduce Table 5 (tab:thickness) and Figure 1 (thickness_gradient.pdf) from
the unified close-margin benchmark, with full reproducibility and arithmetic
transparency.

Method
------
1. Build the same unified close-margin sample as script 23.
2. Compute median bidders per item code from *clean control* auctions only
   (≥5 clean auctions per item code), to avoid cartel contamination.
3. Classify auctions by market thickness: thin (median ≤ 5) vs thick (> 5).
4. Compute AUCs for all screens within each thickness group.
5. Also compute 8-bin breakdown for the thickness_gradient figure.
6. Report full arithmetic: thin_N + thick_N + unmatched_N = total_N.

Output
------
- 02_data/intermediate/thickness_analysis.txt  (human-readable report)
- 02_data/intermediate/thickness_analysis.csv  (machine-readable)
- 01_manuscript/paper_beneath/thickness_gradient.pdf  (figure)
"""
from __future__ import annotations

import time
from math import sqrt
from pathlib import Path

import numpy as np
import polars as pl
from scipy import stats

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
MANUSCRIPT = BASE / "01_manuscript" / "paper_beneath"

PAIRS_PREGAO  = FINAL / "df_pregao_with_cartel_flags.parquet"
SCREENS_PREGAO = FINAL / "auction_screens_pregao.parquet"
WF_EDGES   = FIRMS / "firm_firm_worker_flow_edges.parquet"
COB_EDGES  = FIRMS / "firm_firm_cobidding_edges.parquet"

OUT_REPORT = INTER / "thickness_analysis.txt"
OUT_CSV    = INTER / "thickness_analysis.csv"
OUT_FIGURE = MANUSCRIPT / "thickness_gradient.pdf"

MV_BANDWIDTH = 0.10
MIN_CLEAN_OBS = 5  # minimum clean-control auctions per item code


# ── Reuse build logic from script 23 ────────────────────────────────────────

def build_unified_sample() -> pl.DataFrame:
    """Build unified close-margin pregão sample with classical + network screens."""
    print("Loading pair file...", flush=True)
    pairs = pl.read_parquet(PAIRS_PREGAO)
    pairs = pairs.filter(pl.col("MV").abs() < MV_BANDWIDTH)
    print(f"  after |MV|<{MV_BANDWIDTH}: {pairs.height:,}")

    pairs = pairs.with_columns(
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
        .str.slice(0, 8).alias("cnpj_raiz_n")
    )

    for c in ("has_active_cartel", "both_cartel_active"):
        if c not in pairs.columns:
            pairs = pairs.with_columns(pl.lit(0).cast(pl.Int8).alias(c))

    # Extract winner and runner-up
    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item", "numerodaoc", "códigoitem", "year",
        pl.col("cnpj_raiz_n").alias("winner_cnpj"),
        "has_any_cartel_firm", "has_active_cartel",
        "both_cartel_firm", "both_cartel_active",
    ]).unique(subset=["auction_item"], keep="first")

    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz_n").alias("loser_cnpj"),
    ]).unique(subset=["auction_item"], keep="first")

    auctions = winners.join(losers, on="auction_item", how="inner")
    print(f"  auction-level rows: {auctions.height:,}")

    # Undirected edge key
    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("winner_cnpj"))
        .otherwise(pl.col("loser_cnpj")).alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("loser_cnpj"))
        .otherwise(pl.col("winner_cnpj")).alias("cnpj_b"),
    ])

    # Attach classical screens
    screens = (
        pl.read_parquet(SCREENS_PREGAO)
        .with_columns(
            (pl.col("numerodaoc") + pl.lit("_") + pl.col("códigoitem"))
            .alias("auction_item")
        )
        .select(["auction_item", "cv_bid", "spread", "mv", "n_firms"])
    )
    auctions = auctions.join(screens, on="auction_item", how="left")

    # Attach worker-flow edges
    wf = pl.read_parquet(WF_EDGES).select(["cnpj_a", "cnpj_b", "shared_workers", "jaccard"])
    auctions = auctions.join(wf, on=["cnpj_a", "cnpj_b"], how="left").with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    # Attach co-bidding edges
    if COB_EDGES.exists():
        cob = pl.read_parquet(COB_EDGES)
        for cand in ("n_cobids", "cobidding_count", "n_shared_auctions", "weight"):
            if cand in cob.columns:
                auctions = auctions.join(
                    cob.select(["cnpj_a", "cnpj_b", pl.col(cand).alias("n_cobids")]),
                    on=["cnpj_a", "cnpj_b"], how="left"
                ).with_columns(pl.col("n_cobids").fill_null(0))
                break
        else:
            auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))
    else:
        auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))

    for c in ("has_active_cartel", "has_any_cartel_firm",
              "both_cartel_firm", "both_cartel_active"):
        auctions = auctions.with_columns(pl.col(c).cast(pl.Int8))

    return auctions


# ── AUC computation (from script 23) ────────────────────────────────────────

def compute_auc(treat_vals: np.ndarray, control_vals: np.ndarray,
                direction: str) -> dict:
    t = treat_vals[~np.isnan(treat_vals)]
    c = control_vals[~np.isnan(control_vals)]
    n_t, n_c = len(t), len(c)
    if n_t < 2 or n_c < 2:
        return dict(n_t=n_t, n_c=n_c, auc=np.nan, cohen_d=np.nan)

    delta = float(t.mean() - c.mean())
    sd_t = t.std(ddof=1)
    sd_c = c.std(ddof=1)
    pooled_sd = sqrt(((n_t - 1) * sd_t**2 + (n_c - 1) * sd_c**2) /
                     max(n_t + n_c - 2, 1))
    cohen_d = delta / pooled_sd if pooled_sd > 0 else np.nan

    # Mann-Whitney AUC with average-rank tie handling
    all_scores = np.concatenate([t, c])
    labels = np.concatenate([np.ones(n_t), np.zeros(n_c)])
    order = np.argsort(all_scores, kind="mergesort")
    sorted_scores = all_scores[order]
    ranks = np.empty_like(order, dtype=float)
    i = 0
    while i < len(sorted_scores):
        j = i
        while j < len(sorted_scores) and sorted_scores[j] == sorted_scores[i]:
            j += 1
        avg_rank = (i + j + 1) / 2.0
        ranks[order[i:j]] = avg_rank
        i = j
    rank_sum_t = ranks[labels == 1].sum()
    u1 = rank_sum_t - n_t * (n_t + 1) / 2.0
    auc_gt = u1 / (n_t * n_c)
    auc = auc_gt if direction == "higher_is_cartel" else 1.0 - auc_gt

    return dict(n_t=n_t, n_c=n_c, auc=float(auc), cohen_d=float(cohen_d))


SCREEN_DIRS = {
    "cv_bid": "lower_is_cartel",
    "spread": "lower_is_cartel",
    "n_firms": "lower_is_cartel",
    "shared_workers": "higher_is_cartel",
    "jaccard": "higher_is_cartel",
    "n_cobids": "higher_is_cartel",
}


# ── Main analysis ───────────────────────────────────────────────────────────

def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    auctions = build_unified_sample()
    total_N = auctions.height

    # ── Step 1: Compute median bidders per item code from clean control ──────

    clean = auctions.filter(pl.col("has_any_cartel_firm") == 0)
    treat = auctions.filter(pl.col("has_active_cartel") == 1)

    # Median bidders per item code, from clean auctions with ≥ MIN_CLEAN_OBS
    item_thickness = (
        clean
        .filter(pl.col("n_firms").is_not_null())
        .group_by("códigoitem")
        .agg([
            pl.col("n_firms").median().alias("median_bidders"),
            pl.col("n_firms").count().alias("n_clean_obs"),
        ])
        .filter(pl.col("n_clean_obs") >= MIN_CLEAN_OBS)
    )
    print(f"\nItem codes with ≥{MIN_CLEAN_OBS} clean obs: {item_thickness.height:,}")
    print(f"  median of median_bidders: {item_thickness['median_bidders'].median():.1f}")

    # Attach thickness to auctions
    auctions = auctions.join(item_thickness.select(["códigoitem", "median_bidders"]),
                             on="códigoitem", how="left")

    # ── Step 2: Classify and report arithmetic ──────────────────────────────

    has_thickness = auctions.filter(pl.col("median_bidders").is_not_null())
    no_thickness  = auctions.filter(pl.col("median_bidders").is_null())

    # Overall median for the split
    overall_median = item_thickness["median_bidders"].median()
    print(f"  overall median of item-code medians: {overall_median:.1f}")

    # Thin: median_bidders ≤ 5; Thick: > 5
    THIN_CUTOFF = 5.0
    thin_all  = has_thickness.filter(pl.col("median_bidders") <= THIN_CUTOFF)
    thick_all = has_thickness.filter(pl.col("median_bidders") > THIN_CUTOFF)

    thin_treat  = thin_all.filter(pl.col("has_active_cartel") == 1)
    thick_treat = thick_all.filter(pl.col("has_active_cartel") == 1)
    thin_ctrl   = thin_all.filter(pl.col("has_any_cartel_firm") == 0)
    thick_ctrl  = thick_all.filter(pl.col("has_any_cartel_firm") == 0)

    no_thickness_treat = no_thickness.filter(pl.col("has_active_cartel") == 1)
    no_thickness_ctrl  = no_thickness.filter(pl.col("has_any_cartel_firm") == 0)

    # ── Step 3: Compute AUCs ─────────────────────────────────────────────────

    rows = []

    def eval_group(label, treat_df, ctrl_df):
        for screen, direction in SCREEN_DIRS.items():
            if screen not in treat_df.columns:
                continue
            t_vals = treat_df[screen].to_numpy().astype(float)
            c_vals = ctrl_df[screen].to_numpy().astype(float)
            r = compute_auc(t_vals, c_vals, direction)
            rows.append(dict(group=label, screen=screen, direction=direction, **r))

    eval_group("Thin (≤5)", thin_treat, thin_ctrl)
    eval_group("Thick (>5)", thick_treat, thick_ctrl)
    eval_group("Unmatched", no_thickness_treat, no_thickness_ctrl)
    eval_group("All (benchmark)", treat, clean)

    # ── Step 4: Tercile decomposition ────────────────────────────────────────

    # Terciles of median_bidders among cartel-active auctions with thickness
    treat_with_thick = has_thickness.filter(pl.col("has_active_cartel") == 1)
    ctrl_with_thick  = has_thickness.filter(pl.col("has_any_cartel_firm") == 0)

    if treat_with_thick.height > 0:
        tercile_cuts = treat_with_thick["median_bidders"].quantile(0.333), \
                       treat_with_thick["median_bidders"].quantile(0.667)
        t1_treat = treat_with_thick.filter(pl.col("median_bidders") <= tercile_cuts[0])
        t2_treat = treat_with_thick.filter(
            (pl.col("median_bidders") > tercile_cuts[0]) &
            (pl.col("median_bidders") <= tercile_cuts[1])
        )
        t3_treat = treat_with_thick.filter(pl.col("median_bidders") > tercile_cuts[1])
        t1_ctrl = ctrl_with_thick.filter(pl.col("median_bidders") <= tercile_cuts[0])
        t2_ctrl = ctrl_with_thick.filter(
            (pl.col("median_bidders") > tercile_cuts[0]) &
            (pl.col("median_bidders") <= tercile_cuts[1])
        )
        t3_ctrl = ctrl_with_thick.filter(pl.col("median_bidders") > tercile_cuts[1])

        for label, tt, tc in [
            (f"T1 (≤{tercile_cuts[0]:.0f})", t1_treat, t1_ctrl),
            (f"T2 ({tercile_cuts[0]:.0f}<x≤{tercile_cuts[1]:.0f})", t2_treat, t2_ctrl),
            (f"T3 (>{tercile_cuts[1]:.0f})", t3_treat, t3_ctrl),
        ]:
            eval_group(label, tt, tc)

    # ── Step 5: 8-bin breakdown for figure ───────────────────────────────────

    bin_edges = [0, 3, 4, 5, 6, 7, 9, 12, 999]
    bin_labels = ["2-3", "4", "5", "6", "7", "8-9", "10-12", "13+"]
    bin_results = []

    for i in range(len(bin_edges) - 1):
        lo, hi = bin_edges[i], bin_edges[i + 1]
        label = bin_labels[i]

        bt = treat_with_thick.filter(
            (pl.col("median_bidders") > lo) & (pl.col("median_bidders") <= hi)
        ) if lo > 0 else treat_with_thick.filter(pl.col("median_bidders") <= hi)
        bc = ctrl_with_thick.filter(
            (pl.col("median_bidders") > lo) & (pl.col("median_bidders") <= hi)
        ) if lo > 0 else ctrl_with_thick.filter(pl.col("median_bidders") <= hi)

        for screen in ("shared_workers", "n_firms"):
            direction = SCREEN_DIRS[screen]
            t_vals = bt[screen].to_numpy().astype(float)
            c_vals = bc[screen].to_numpy().astype(float)
            r = compute_auc(t_vals, c_vals, direction)
            bin_results.append(dict(
                bin=label, bin_lo=lo, bin_hi=hi,
                screen=screen, n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
            ))

    # ── Step 6: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write(f"Market-Thickness Heterogeneity Analysis\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"MV bandwidth: {MV_BANDWIDTH}\n")
        f.write(f"Min clean obs per item code: {MIN_CLEAN_OBS}\n")
        f.write("=" * 70 + "\n\n")

        f.write("ARITHMETIC TRANSPARENCY\n")
        f.write("-" * 40 + "\n")
        f.write(f"Total auctions (|MV|<{MV_BANDWIDTH}):  {total_N:,}\n")
        f.write(f"  with thickness assigned:              {has_thickness.height:,}\n")
        f.write(f"  without thickness (item code <{MIN_CLEAN_OBS} clean obs): "
                f"{no_thickness.height:,}\n")
        f.write(f"  SUM:                                  "
                f"{has_thickness.height + no_thickness.height:,}\n\n")

        f.write(f"Cartel-active auctions:\n")
        f.write(f"  Total:                   {treat.height:,}\n")
        f.write(f"  Thin (≤{THIN_CUTOFF:.0f}):              "
                f"{thin_treat.height:,}\n")
        f.write(f"  Thick (>{THIN_CUTOFF:.0f}):             "
                f"{thick_treat.height:,}\n")
        f.write(f"  Unmatched (no thickness):{no_thickness_treat.height:,}\n")
        f.write(f"  SUM:                     "
                f"{thin_treat.height + thick_treat.height + no_thickness_treat.height:,}\n")
        gap = treat.height - (thin_treat.height + thick_treat.height + no_thickness_treat.height)
        if gap != 0:
            f.write(f"  ⚠️  GAP: {gap:,} auctions unaccounted!\n")
        f.write("\n")

        f.write(f"Clean control auctions:\n")
        f.write(f"  Total:                   {clean.height:,}\n")
        f.write(f"  Thin:                    {thin_ctrl.height:,}\n")
        f.write(f"  Thick:                   {thick_ctrl.height:,}\n")
        f.write(f"  Unmatched:               {no_thickness_ctrl.height:,}\n\n")

        # Median split table
        f.write("TABLE 5 — Screen Performance by Market Thickness\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'Group':20s} {'N_t':>7s} {'N_c':>9s} {'CV':>6s} {'Spread':>7s} "
                f"{'N_firms':>7s} {'Shared':>7s} {'Jaccard':>7s}\n")
        f.write("-" * 70 + "\n")

        for group_label in ["Thin (≤5)", "Thick (>5)", "Unmatched", "All (benchmark)"]:
            grp_rows = [r for r in rows if r["group"] == group_label]
            if not grp_rows:
                continue
            n_t = grp_rows[0]["n_t"]
            n_c = grp_rows[0]["n_c"]
            vals = {}
            for r in grp_rows:
                vals[r["screen"]] = r["auc"]
            f.write(f"{group_label:20s} {n_t:>7,} {n_c:>9,} "
                    f"{vals.get('cv_bid', float('nan')):>6.3f} "
                    f"{vals.get('spread', float('nan')):>7.3f} "
                    f"{vals.get('n_firms', float('nan')):>7.3f} "
                    f"{vals.get('shared_workers', float('nan')):>7.3f} "
                    f"{vals.get('jaccard', float('nan')):>7.3f}\n")
        f.write("\n")

        # Tercile decomposition
        if treat_with_thick.height > 0:
            f.write(f"TERCILE DECOMPOSITION (cuts at {tercile_cuts[0]:.0f}, "
                    f"{tercile_cuts[1]:.0f})\n")
            f.write("-" * 70 + "\n")
            for tl in [r["group"] for r in rows if r["group"].startswith("T")]:
                grp_rows = [r for r in rows if r["group"] == tl]
                if not grp_rows:
                    continue
                n_t = grp_rows[0]["n_t"]
                vals = {r["screen"]: r["auc"] for r in grp_rows}
                f.write(f"  {tl:30s} N_t={n_t:>5,}  "
                        f"SW={vals.get('shared_workers', float('nan')):.3f}  "
                        f"CV={vals.get('cv_bid', float('nan')):.3f}\n")
            f.write("\n")

        # 8-bin breakdown
        f.write("8-BIN BREAKDOWN (for Figure 1)\n")
        f.write("-" * 50 + "\n")
        f.write(f"{'Bin':>6s} {'N_t':>6s} {'SW AUC':>7s} {'Nfirms AUC':>10s}\n")
        for i, label in enumerate(bin_labels):
            sw = [r for r in bin_results if r["bin"] == label and r["screen"] == "shared_workers"]
            nf = [r for r in bin_results if r["bin"] == label and r["screen"] == "n_firms"]
            sw_auc = sw[0]["auc"] if sw else float("nan")
            nf_auc = nf[0]["auc"] if nf else float("nan")
            n_t = sw[0]["n_t"] if sw else 0
            f.write(f"{label:>6s} {n_t:>6,} {sw_auc:>7.3f} {nf_auc:>10.3f}\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Step 7: Produce figure (BEFORE mutating bin_results) ────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        sw_bins = [r for r in bin_results if r["screen"] == "shared_workers" and not np.isnan(r["auc"])]
        nf_bins = [r for r in bin_results if r["screen"] == "n_firms" and not np.isnan(r["auc"])]

        if sw_bins and nf_bins:
            x_sw = list(range(len(sw_bins)))
            x_nf = list(range(len(nf_bins)))
            labels_sw = [r["bin"] for r in sw_bins]
            labels_nf = [r["bin"] for r in nf_bins]

            fig, ax = plt.subplots(figsize=(8, 5))
            ax.plot(x_sw, [r["auc"] for r in sw_bins], "o-", color="#2166ac",
                    linewidth=2, markersize=7, label="Worker-flow (shared workers)")
            ax.plot(x_nf, [r["auc"] for r in nf_bins], "s--", color="#b2182b",
                    linewidth=2, markersize=7, label="Classical (bidder count)")
            ax.axhline(0.5, color="grey", linestyle=":", linewidth=1, alpha=0.7)

            # Annotate sample sizes
            for xi, r in zip(x_sw, sw_bins):
                ax.annotate(f"n={r['n_t']}", (xi, r["auc"]),
                            textcoords="offset points", xytext=(0, 10),
                            fontsize=7, ha="center", color="#2166ac")

            ax.set_xticks(x_sw)
            ax.set_xticklabels(labels_sw)
            ax.set_xlabel("Market thickness (median bidders per item code)", fontsize=11)
            ax.set_ylabel("AUC", fontsize=11)
            ax.set_ylim(0.20, 0.90)
            ax.legend(loc="upper left", fontsize=9, frameon=True)
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)

            fig.tight_layout()
            fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
            plt.close(fig)
            print(f"[written] {OUT_FIGURE}")
        else:
            print("  ⚠️  Not enough bin data for figure")
    except ImportError:
        print("  ⚠️  matplotlib not available; skipping figure")

    # ── Step 8: Write CSV (after figure, so bin_results can be mutated) ──────

    import csv
    for r in bin_results:
        r["group"] = f"bin_{r.pop('bin')}"
        r.pop("bin_lo", None)
        r.pop("bin_hi", None)
        for k in ("direction", "cohen_d"):
            if k not in r:
                r[k] = ""
    all_csv_rows = rows + bin_results
    all_keys = list(dict.fromkeys(k for row in all_csv_rows for k in row))
    with open(OUT_CSV, "w", newline="") as cf:
        if all_csv_rows:
            w = csv.DictWriter(cf, fieldnames=all_keys, extrasaction="ignore")
            w.writeheader()
            w.writerows(all_csv_rows)
    print(f"[written] {OUT_CSV}")

    # ── Report preview ───────────────────────────────────────────────────────
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
