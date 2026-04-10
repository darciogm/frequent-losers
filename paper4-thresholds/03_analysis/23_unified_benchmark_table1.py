#!/usr/bin/env python3
"""
23_unified_benchmark_table1.py — unified close-margin benchmark (Rec 2)

Purpose
-------
Run *all* classical bid-distribution screens (cv_bid, spread, mv, n_firms)
and the worker-flow / co-bidding network screens on the *same* close-margin
sample that produces the worker-flow headline AUC. Previous pipeline reports
classical AUCs on N≈3,905 cartel-active pregão (no close-margin filter) and
worker-flow AUCs on N≈2,351 cartel-active pregão (|MV|<0.10). The abstract
claims both are "on the same benchmark" — they aren't. This script produces
the apples-to-apples comparison.

Method
------
1. Load df_{pregao,convite}_with_cartel_flags.parquet (pair-level, one row per
   bidding firm per auction) and restrict to |MV| < 0.10.
2. Collapse to auction-level winner/runner-up pairs (same logic as script 17),
   carrying cartel flags from the pair file.
3. Join auction-level classical screens (cv_bid, spread, mv, n_firms) from
   auction_screens_{pregao,convite}.parquet — the mv column is now sanity-
   masked (script 16 with the Rec 1 fix).
4. Join firm-firm worker-flow edges (shared_workers, jaccard) from
   firm_firm_worker_flow_edges.parquet. Zero-impute pairs with no edge.
5. Join co-bidding edges if available.
6. For every screen, compute the same three statistics on the unified sample:
   Δ mean (treat−control), Welch t, Wilcoxon rank-sum p, and Mann-Whitney AUC.
7. Write a single Table 1 CSV + a plain-text report.

Samples considered (pregão + convite)
-------------------------------------
- full             : all |MV|<0.10 auctions in the modality
- cartel_active    : ≥1 cartel-active firm participated during cartel window
- cartel_listed    : ≥1 cartel-listed firm (any time)
- pair_matched_act : BOTH winner+runner are cartel-active (strict)
- pair_matched_lst : BOTH winner+runner are cartel-listed (any time)
- clean            : no cartel firm (control)
"""
from __future__ import annotations

import time
from math import sqrt, erf
from pathlib import Path

import numpy as np
import polars as pl
from scipy import stats

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO  = FINAL / "df_pregao_with_cartel_flags.parquet"
PAIRS_CONVITE = FINAL / "df_convite_with_cartel_flags.parquet"
SCREENS_PREGAO  = FINAL / "auction_screens_pregao.parquet"
SCREENS_CONVITE = FINAL / "auction_screens_convite.parquet"
WF_EDGES   = FIRMS / "firm_firm_worker_flow_edges.parquet"
COB_EDGES  = FIRMS / "firm_firm_cobidding_edges.parquet"

OUT_REPORT = INTER / "table1_unified_benchmark.txt"
OUT_CSV    = INTER / "table1_unified_benchmark.csv"

MV_BANDWIDTH = 0.10  # close-margin envelope — must match script 17


def build_unified_sample(modality: str) -> pl.DataFrame:
    """Build the close-margin unified sample with classical + network screens."""
    if modality == "pregao":
        pairs_path, screens_path = PAIRS_PREGAO, SCREENS_PREGAO
    else:
        pairs_path, screens_path = PAIRS_CONVITE, SCREENS_CONVITE

    print(f"\n[{modality}] loading pair file...", flush=True)
    pairs = pl.read_parquet(pairs_path)
    print(f"  total rows: {pairs.height:,}")
    print(f"  columns: {pairs.columns}")

    pairs = pairs.filter(pl.col("MV").abs() < MV_BANDWIDTH)
    print(f"  after |MV|<{MV_BANDWIDTH}: {pairs.height:,}")

    # Handle two schemas:
    #   pregão: has numerodaoc, códigoitem, códigofornecedor, has_active_cartel,
    #           both_cartel_active
    #   convite: has auction_item, cnpj_raiz, cnpj_full, no active-period flags
    if "códigofornecedor" in pairs.columns:
        pairs = pairs.with_columns(
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
            .str.slice(0, 8).alias("cnpj_raiz_n")
        )
    else:
        pairs = pairs.with_columns(
            pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8).alias("cnpj_raiz_n")
        )

    # Derive numerodaoc and códigoitem from auction_item if absent
    if "numerodaoc" not in pairs.columns:
        # auction_item is "<numerodaoc>_<códigoitem>" — split on first underscore
        # from the LEFT (numerodaoc is fixed-length in BEC, so left split is safe)
        # Actually: keep numerodaoc as everything before the last '_' to be safe
        pairs = pairs.with_columns([
            pl.col("auction_item").str.split("_").list.slice(0, -1)
              .list.join("_").alias("numerodaoc"),
            pl.col("auction_item").str.split("_").list.last().alias("códigoitem"),
        ])

    # Ensure the active flags exist (convite has no active-period flags)
    for c in ("has_active_cartel", "both_cartel_active"):
        if c not in pairs.columns:
            pairs = pairs.with_columns(pl.lit(0).cast(pl.Int8).alias(c))

    # Extract winner and runner-up rows
    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item", "numerodaoc", "códigoitem", "year",
        pl.col("cnpj_raiz_n").alias("winner_cnpj"),
        "has_any_cartel_firm", "has_active_cartel",
        "both_cartel_firm", "both_cartel_active",
    ])
    # Deduplicate winners (pair file is at bidding-firm level; one winner per auction)
    winners = winners.unique(subset=["auction_item"], keep="first")
    print(f"  unique winner rows: {winners.height:,}")

    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz_n").alias("loser_cnpj"),
    ]).unique(subset=["auction_item"], keep="first")
    print(f"  unique runner-up rows: {losers.height:,}")

    auctions = winners.join(losers, on="auction_item", how="inner")
    print(f"  auction-level rows after join: {auctions.height:,}")

    # Build undirected edge key: smaller cnpj first
    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("winner_cnpj"))
        .otherwise(pl.col("loser_cnpj")).alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("loser_cnpj"))
        .otherwise(pl.col("winner_cnpj")).alias("cnpj_b"),
    ])

    # Attach auction-level classical screens (cv_bid, spread, mv, n_firms)
    # Join on auction_item (= numerodaoc || '_' || códigoitem) for schema
    # robustness across pregão/convite.
    print("  joining classical screens from auction_screens parquet...")
    screens = (
        pl.read_parquet(screens_path)
        .with_columns(
            (pl.col("numerodaoc") + pl.lit("_") + pl.col("códigoitem"))
            .alias("auction_item")
        )
        .select(["auction_item", "cv_bid", "spread", "mv", "n_firms"])
    )
    auctions = auctions.join(screens, on="auction_item", how="left")
    n_matched = auctions.filter(pl.col("cv_bid").is_not_null()).height
    print(f"  classical screens matched: {n_matched:,} / {auctions.height:,}")

    # Attach worker-flow edges
    print("  joining worker-flow edges...")
    wf = pl.read_parquet(WF_EDGES).select([
        "cnpj_a", "cnpj_b", "shared_workers", "jaccard"
    ])
    auctions = auctions.join(wf, on=["cnpj_a", "cnpj_b"], how="left").with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    # Attach co-bidding edges if available
    if COB_EDGES.exists():
        print("  joining co-bidding edges...")
        cob = pl.read_parquet(COB_EDGES)
        cob_cols = [c for c in cob.columns if c not in ("cnpj_a", "cnpj_b")]
        # Look for the reasonable candidate column
        cob_col = None
        for cand in ("n_cobids", "cobidding_count", "n_shared_auctions", "weight"):
            if cand in cob_cols:
                cob_col = cand
                break
        if cob_col is not None:
            auctions = auctions.join(
                cob.select(["cnpj_a", "cnpj_b", pl.col(cob_col).alias("n_cobids")]),
                on=["cnpj_a", "cnpj_b"], how="left"
            ).with_columns(pl.col("n_cobids").fill_null(0))
        else:
            print(f"    no known co-bidding count column in {cob.columns}")
            auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))
    else:
        auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))

    # Force int-casting of cartel flags that come through as bool
    for c in ("has_active_cartel", "has_any_cartel_firm",
              "both_cartel_firm", "both_cartel_active"):
        auctions = auctions.with_columns(pl.col(c).cast(pl.Int8))

    return auctions


def evaluate_screen(treat_vals: np.ndarray, control_vals: np.ndarray,
                    direction: str) -> dict:
    """Return Δ, t, Wilcoxon p, AUC, cohen's d, n_t, n_c.

    direction: 'lower_is_cartel' | 'higher_is_cartel'
    """
    t = treat_vals[~np.isnan(treat_vals)]
    c = control_vals[~np.isnan(control_vals)]
    n_t, n_c = len(t), len(c)
    if n_t < 2 or n_c < 2:
        return dict(n_t=n_t, n_c=n_c, delta=np.nan, t=np.nan, p=np.nan,
                    auc=np.nan, cohen_d=np.nan, wilcox_p=np.nan)

    # Welch t
    res = stats.ttest_ind(t, c, equal_var=False)
    delta = float(t.mean() - c.mean())

    # Pooled sd for Cohen's d
    sd_t = t.std(ddof=1) if n_t > 1 else 0.0
    sd_c = c.std(ddof=1) if n_c > 1 else 0.0
    pooled_sd = sqrt(((n_t - 1) * sd_t**2 + (n_c - 1) * sd_c**2) /
                     max(n_t + n_c - 2, 1))
    cohen_d = delta / pooled_sd if pooled_sd > 0 else np.nan

    # Wilcoxon rank-sum
    try:
        w_res = stats.ranksums(t, c)
        wilcox_p = float(w_res.pvalue)
    except Exception:
        wilcox_p = np.nan

    # Mann-Whitney AUC with correct direction
    # For 'lower_is_cartel', we want AUC = P(treat < control). scipy's
    # mannwhitneyu with alternative='less' or the U1/(n_t*n_c) formula.
    # Use ranking: rank 1 = smallest. U1 = R1 - n1(n1+1)/2 counts
    # (treat, control) pairs where treat > control. So:
    #   P(treat > control) = U1 / (n_t * n_c)
    #   P(treat < control) = 1 - P(>) - P(=)  ≈ 1 - U1/(n_t*n_c)
    all_scores = np.concatenate([t, c])
    labels = np.concatenate([np.ones(n_t), np.zeros(n_c)])
    order = np.argsort(all_scores, kind="mergesort")
    ranks = np.empty_like(order, dtype=float)
    # handle ties via average-rank
    sorted_scores = all_scores[order]
    # Assign average ranks
    i = 0
    while i < len(sorted_scores):
        j = i
        while j < len(sorted_scores) and sorted_scores[j] == sorted_scores[i]:
            j += 1
        avg_rank = (i + j + 1) / 2.0  # average of ranks (i+1) .. j
        ranks[order[i:j]] = avg_rank
        i = j
    rank_sum_t = ranks[labels == 1].sum()
    u1 = rank_sum_t - n_t * (n_t + 1) / 2.0
    auc_gt = u1 / (n_t * n_c)  # P(treat > control)
    if direction == "higher_is_cartel":
        auc = auc_gt
    else:  # lower_is_cartel
        auc = 1.0 - auc_gt

    return dict(n_t=n_t, n_c=n_c, delta=delta,
                t=float(res.statistic), p=float(res.pvalue),
                auc=float(auc), cohen_d=float(cohen_d), wilcox_p=wilcox_p)


SCREEN_DIRECTIONS = {
    # Classical — bid-rotation model predicts compression ⇒ lower is cartel
    "cv_bid":          "lower_is_cartel",
    "spread":          "lower_is_cartel",
    "mv":              "lower_is_cartel",
    "n_firms":         "lower_is_cartel",
    # Network — coordination proxies, higher is cartel
    "shared_workers":  "higher_is_cartel",
    "jaccard":         "higher_is_cartel",
    "n_cobids":        "higher_is_cartel",
}


def run_modality(modality: str, f_out) -> list[dict]:
    auctions = build_unified_sample(modality)
    f_out.write(f"\n{'=' * 70}\n{modality.upper()} — |MV|<{MV_BANDWIDTH}\n"
                f"{'=' * 70}\n")
    f_out.write(f"Total auctions: {auctions.height:,}\n")

    control = auctions.filter(pl.col("has_any_cartel_firm") == 0)
    samples = {
        "full":                auctions,
        "cartel_active":       auctions.filter(pl.col("has_active_cartel") == 1),
        "cartel_listed":       auctions.filter(pl.col("has_any_cartel_firm") == 1),
        "pair_matched_active": auctions.filter(pl.col("both_cartel_active") == 1),
        "pair_matched_listed": auctions.filter(pl.col("both_cartel_firm") == 1),
        "clean":               control,
    }
    f_out.write("\nSample sizes:\n")
    for k, v in samples.items():
        f_out.write(f"  {k:25s}  N={v.height:,}\n")

    # Confirmation — this should match worker_flow_screen_results.txt
    f_out.write(f"\nSanity check vs script 17:\n")
    f_out.write(f"  cartel_active N = {samples['cartel_active'].height:,}  "
                f"(script 17 reported 2,351 for pregão; 263 for convite)\n")
    f_out.write(f"  clean control N = {samples['clean'].height:,}  "
                f"(script 17 reported 527,259 pregão; 519,557 convite)\n\n")

    rows = []
    for screen in ["cv_bid", "spread", "mv", "n_firms",
                   "shared_workers", "jaccard", "n_cobids"]:
        if screen not in auctions.columns:
            continue
        direction = SCREEN_DIRECTIONS[screen]
        f_out.write(f"\nScreen: {screen}  (direction: {direction})\n")
        for sname, sub in samples.items():
            if sname == "clean":
                continue
            if sub.height == 0:
                continue
            t_vals = sub[screen].to_numpy().astype(float)
            c_vals = control[screen].to_numpy().astype(float)
            r = evaluate_screen(t_vals, c_vals, direction)
            f_out.write(
                f"  {sname:22s} "
                f"N_t={r['n_t']:>6,}  Δ={r['delta']:+.4f}  "
                f"d={r['cohen_d']:+.3f}  t={r['t']:+7.3f}  "
                f"wilcox_p={r['wilcox_p']:.3g}  AUC={r['auc']:.3f}\n"
            )
            rows.append(dict(
                modality=modality, screen=screen, sample=sname,
                direction=direction, **r,
            ))
    return rows


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    print("=" * 70)
    print("Unified close-margin benchmark (Rec 2)")
    print(f"Run: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"MV bandwidth: {MV_BANDWIDTH}")
    print("=" * 70)

    all_rows: list[dict] = []
    with open(OUT_REPORT, "w") as f:
        f.write(f"Unified close-margin benchmark (|MV|<{MV_BANDWIDTH})\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("Classical + network screens on a SINGLE sample per modality.\n")
        f.write("Rec 2 of mr-beneath /rev parecer 2026-04-09.\n")
        f.write("=" * 70 + "\n")
        all_rows.extend(run_modality("pregao", f))
        all_rows.extend(run_modality("convite", f))

    import csv
    with open(OUT_CSV, "w", newline="") as cf:
        if all_rows:
            w = csv.DictWriter(cf, fieldnames=list(all_rows[0].keys()))
            w.writeheader()
            w.writerows(all_rows)

    print(f"\n[written] {OUT_REPORT}")
    print(f"[written] {OUT_CSV}")
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
