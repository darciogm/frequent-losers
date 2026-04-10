#!/usr/bin/env python3
"""
16_variance_cv_screens.py — A.4 variance/CV screens vs CADE ground truth

Purpose
-------
Implement classical bid-distribution screens (Abrantes-Metz et al. 2006;
Imhof, Karagök & Rutz 2018) and test their detection accuracy against
the CADE-confirmed cartels in BEC.

Screens (computed at auction level on FIRM-BEST bids — one bid per firm)
------------------------------------------------------------------------
  1. cv_bid    = sd(bids) / mean(bids)
                 Coefficient of variation. Lower under cover-bidding.
  2. spread    = (max - min) / mean
                 Range normalized by mean. Lower if cover bids clustered.
  3. diff_pct  = (second_lowest - lowest) / lowest
                 Margin of victory percentage. Lower if rotation cartel.
  4. p99_p1    = 99th pct - 1st pct (within auction)
  5. cv_diff   = cv(bids) - cv(bids excluding winner)
                 Negative = winner is anomalously close to other bids
                 (consistent with cover bidding with the winner inside the
                 cover-bid distribution).
  6. n_bidders : sample-size confound; reported separately

For each screen, evaluate against the cartel ground truth:
  - Compare distribution in cartel-exposed vs control auctions
  - Run two-sample t-test (welch)
  - Compute ROC and AUC for cartel detection

Inputs
------
  /home/.../paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet
  02_data/firms/cade_ground_truth.parquet

Outputs
-------
  02_data/final/auction_screens_pregao.parquet
  02_data/final/auction_screens_convite.parquet
  02_data/intermediate/variance_screens_results.txt
  04_figures/variance_screens_distributions.pdf  (if matplotlib available)
"""
from __future__ import annotations

import time
from pathlib import Path

import polars as pl

PAPER3 = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
SOURCE = PAPER3 / "v3/data/processed/bid_level_with_prices.parquet"
GT_PATH = BASE / "02_data" / "firms" / "cade_ground_truth.parquet"

OUT_PREGAO  = BASE / "02_data" / "final" / "auction_screens_pregao.parquet"
OUT_CONVITE = BASE / "02_data" / "final" / "auction_screens_convite.parquet"
OUT_REPORT  = BASE / "02_data" / "intermediate" / "variance_screens_results.txt"

YEAR_RANGE = (2009, 2019)


def parse_year(col: pl.Expr) -> pl.Expr:
    return col.str.slice(3, 4).cast(pl.Int32, strict=False)


def build_auction_screens(proc_label: str) -> pl.DataFrame:
    """Aggregate bid-level data to auction-level screens for one procedure."""
    print(f"\n[{proc_label}] loading bids and aggregating...", flush=True)

    # Step 1: load bid-level data, restrict to procedure type, drop missing
    bids = (
        pl.scan_parquet(SOURCE)
        .filter(pl.col("descriçãoprocedimentocompra") == proc_label)
        .filter(pl.col("bid_price") > 0)
        .with_columns(parse_year(pl.col("mêsanoencerramento")).alias("year"))
        .filter((pl.col("year") >= YEAR_RANGE[0]) &
                (pl.col("year") <= YEAR_RANGE[1]))
        .select([
            "numerodaoc", "códigoitem", "year",
            "códigofornecedor", "bid_price", "won",
        ])
        .collect()
    )
    print(f"  raw bids: {bids.height:,}")

    # Step 2: aggregate to firm-level best bid per auction (min bid per firm)
    firm_auction = (
        bids.group_by(["numerodaoc", "códigoitem", "códigofornecedor"])
        .agg([
            pl.col("bid_price").min().alias("best_bid"),
            pl.col("won").max().alias("won_any"),
            pl.col("year").first().alias("year"),
        ])
    )
    print(f"  firm × auction rows: {firm_auction.height:,}")

    # Filter early to auctions with ≥2 firms (so runner-up extraction works)
    auction_sizes = (
        firm_auction.group_by(["numerodaoc", "códigoitem"])
        .agg(pl.len().alias("n_firms_check"))
        .filter(pl.col("n_firms_check") >= 2)
    )
    firm_auction = firm_auction.join(
        auction_sizes.select(["numerodaoc", "códigoitem"]),
        on=["numerodaoc", "códigoitem"], how="inner"
    )
    print(f"  after ≥2 firm filter: {firm_auction.height:,}")

    # Step 3: compute auction-level statistics
    print("  computing auction-level screens...", flush=True)
    auction = (
        firm_auction.group_by(["numerodaoc", "códigoitem"])
        .agg([
            pl.col("year").first(),
            pl.len().alias("n_firms"),
            pl.col("best_bid").min().alias("bid_min"),
            pl.col("best_bid").max().alias("bid_max"),
            pl.col("best_bid").mean().alias("bid_mean"),
            pl.col("best_bid").std().alias("bid_sd"),
            pl.col("best_bid").median().alias("bid_med"),
            # Winner bid (firm with won=1) and runner-up
            pl.col("best_bid").filter(pl.col("won_any") == 1).min()
                .alias("winner_bid"),
        ])
        .with_columns([
            (pl.col("bid_sd") / pl.col("bid_mean")).alias("cv_bid"),
            ((pl.col("bid_max") - pl.col("bid_min")) / pl.col("bid_mean"))
                .alias("spread"),
        ])
    )
    print(f"  unique auctions: {auction.height:,}")

    # Compute runner-up bid as second-lowest (now safe — all have ≥2 firms)
    runnerup = (
        firm_auction.sort(["numerodaoc", "códigoitem", "best_bid"])
        .group_by(["numerodaoc", "códigoitem"], maintain_order=True)
        .agg([
            pl.col("best_bid").get(1).alias("runnerup_bid"),
        ])
    )
    auction = auction.join(runnerup, on=["numerodaoc", "códigoitem"], how="left")

    # Margin of victory at the auction level
    # Sanity mask: set mv to NULL whenever (i) winner_bid is missing or
    # non-positive (division by zero), (ii) mv is negative (anomalous: winner
    # is not lowest bidder — rare, possible under disqualifications, excluded
    # for screen comparability with the literature), or (iii) mv > MV_MAX
    # (data-entry error or bid typo — runner-up bidding more than MV_MAX*100%
    # above the winner is implausible for competitive procurement).
    # Pre-fix, ~a handful of auctions with winner_bid ≈ 0 pulled control means
    # into the hundreds, contaminating every downstream t-test and AUC in
    # variance_screens_results.txt and table1_multiscreen_report.txt.
    MV_MAX = 1.0  # 100% margin: runner-up is at most double the winner
    auction = auction.with_columns([
        pl.when(
            (pl.col("winner_bid").is_not_null())
            & (pl.col("winner_bid") > 0)
            & (pl.col("runnerup_bid").is_not_null())
        )
        .then((pl.col("runnerup_bid") - pl.col("winner_bid")) / pl.col("winner_bid"))
        .otherwise(None)
        .alias("mv_raw"),
    ])
    auction = auction.with_columns([
        pl.when(
            pl.col("mv_raw").is_not_null()
            & (pl.col("mv_raw") >= 0)
            & (pl.col("mv_raw") <= MV_MAX)
        )
        .then(pl.col("mv_raw"))
        .otherwise(None)
        .alias("mv"),
    ])

    n_total = auction.height
    n_mv_ok = auction.filter(pl.col("mv").is_not_null()).height
    n_mv_neg = auction.filter(
        pl.col("mv_raw").is_not_null() & (pl.col("mv_raw") < 0)
    ).height
    n_mv_big = auction.filter(
        pl.col("mv_raw").is_not_null() & (pl.col("mv_raw") > MV_MAX)
    ).height
    n_mv_null_raw = auction.filter(pl.col("mv_raw").is_null()).height
    print(
        f"  mv sanity: total={n_total:,}  kept={n_mv_ok:,}  "
        f"dropped_raw_null={n_mv_null_raw:,}  dropped_neg={n_mv_neg:,}  "
        f"dropped_gt_{MV_MAX}={n_mv_big:,}"
    )

    # Drop the raw helper column so downstream scripts see a clean schema
    auction = auction.drop("mv_raw")

    return auction


def attach_cartel_flags(auction: pl.DataFrame, gt: pl.DataFrame,
                        firm_auction_lookup: pl.DataFrame) -> pl.DataFrame:
    """Mark each auction with cartel exposure based on participating firms."""
    print("  attaching cartel exposure flags...", flush=True)

    # Build firm × year cartel-active table
    gt_periods = gt.filter(
        pl.col("cnpj_raiz").is_not_null()
        & pl.col("cartel_start_year").is_not_null()
    ).select([
        "cnpj_raiz",
        pl.col("cartel_start_year").cast(pl.Int32),
        pl.col("cartel_end_year").cast(pl.Int32),
    ]).with_columns(
        pl.int_ranges(
            pl.col("cartel_start_year"),
            pl.col("cartel_end_year") + 1,
        ).alias("year_list")
    ).explode("year_list").rename({"year_list": "year"}).select([
        "cnpj_raiz", "year"
    ]).unique()

    cartel_firms_set = set(
        gt.filter(pl.col("cnpj_raiz").is_not_null())["cnpj_raiz"].to_list()
    )
    print(f"  cartel-listed firms: {len(cartel_firms_set):,}")

    # Mark each firm-auction row with cartel flags
    fa = firm_auction_lookup.with_columns([
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
            .str.slice(0, 8).alias("cnpj_raiz"),
    ])
    fa = fa.with_columns(
        pl.col("cnpj_raiz").is_in(cartel_firms_set)
            .cast(pl.Int8).alias("cartel_firm")
    )
    fa = fa.join(
        gt_periods.with_columns(pl.lit(1, dtype=pl.Int8).alias("cartel_in_period")),
        on=["cnpj_raiz", "year"], how="left"
    ).with_columns(
        pl.col("cartel_in_period").fill_null(0)
    )

    # Aggregate flags to auction level
    auction_flags = (
        fa.group_by(["numerodaoc", "códigoitem"])
        .agg([
            pl.col("cartel_firm").max().alias("has_any_cartel_firm"),
            pl.col("cartel_in_period").max().alias("has_active_cartel"),
            pl.col("cartel_firm").sum().alias("n_cartel_firms"),
        ])
    )
    auction = auction.join(
        auction_flags, on=["numerodaoc", "códigoitem"], how="left"
    ).with_columns([
        pl.col("has_any_cartel_firm").fill_null(0),
        pl.col("has_active_cartel").fill_null(0),
        pl.col("n_cartel_firms").fill_null(0),
    ])

    return auction


# ─────────────────────────────────────────────────────────────────────
def two_sample_t(x_treat, x_control, label, f):
    """Welch's t-test on two columns of a polars Series. Reports robust to NA."""
    import math
    t = x_treat.drop_nulls().to_numpy()
    c = x_control.drop_nulls().to_numpy()
    if len(t) < 30 or len(c) < 30:
        f.write(f"  {label:30s}  [skip — n_t={len(t)}, n_c={len(c)}]\n")
        return None
    mt, mc = t.mean(), c.mean()
    vt, vc = t.var(ddof=1), c.var(ddof=1)
    se = math.sqrt(vt/len(t) + vc/len(c))
    if se == 0:
        f.write(f"  {label:30s}  [se=0]\n")
        return None
    tstat = (mt - mc) / se
    # rough z p-value
    from math import erf, sqrt
    p_two = 2 * (1 - 0.5 * (1 + erf(abs(tstat) / sqrt(2))))
    f.write(f"  {label:30s}  treat: μ={mt:.5f} (n={len(t):>6,})  "
            f"control: μ={mc:.5f} (n={len(c):>7,})  Δ={mt-mc:+.5f}  "
            f"t={tstat:+.3f}  p={p_two:.4g}\n")
    return {"label": label, "mean_treat": mt, "mean_control": mc,
            "delta": mt - mc, "t": tstat, "p": p_two,
            "n_treat": len(t), "n_control": len(c)}


def compute_auc(scores_treat, scores_control, higher_is_cartel=True):
    """Compute ROC AUC for a screen. Higher score = more 'cartel-like'."""
    import numpy as np
    t = scores_treat.drop_nulls().to_numpy()
    c = scores_control.drop_nulls().to_numpy()
    if len(t) < 10 or len(c) < 10:
        return None
    if not higher_is_cartel:
        t, c = -t, -c
    # AUC via Mann-Whitney U
    all_scores = np.concatenate([t, c])
    labels = np.concatenate([np.ones(len(t)), np.zeros(len(c))])
    order = np.argsort(all_scores)
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, len(all_scores) + 1)
    rank_sum_t = ranks[labels == 1].sum()
    n_t, n_c = len(t), len(c)
    auc = (rank_sum_t - n_t * (n_t + 1) / 2) / (n_t * n_c)
    return auc


def evaluate(auction: pl.DataFrame, label: str, f) -> None:
    """Run all screens vs cartel exposure on an auction-level table."""
    f.write(f"\n{'='*70}\n{label}\n{'='*70}\n")
    f.write(f"Total auctions: {auction.height:,}\n")
    n_active = auction.filter(pl.col("has_active_cartel") == 1).height
    n_listed = auction.filter(pl.col("has_any_cartel_firm") == 1).height
    f.write(f"  ≥1 cartel-active firm:  {n_active:>6,}\n")
    f.write(f"  ≥1 cartel-listed firm:  {n_listed:>6,}\n")
    f.write(f"  clean control (none):   {auction.height - n_listed:>6,}\n")

    # Define groups: cartel-active auctions vs clean control
    treat = auction.filter(pl.col("has_active_cartel") == 1)
    control = auction.filter(pl.col("has_any_cartel_firm") == 0)
    f.write(f"\nGroup definitions for tests:\n")
    f.write(f"  TREAT (cartel-active):  N={treat.height:,}\n")
    f.write(f"  CONTROL (no cartel):    N={control.height:,}\n\n")

    f.write("Two-sample t-tests on each screen:\n")
    rows = []
    for screen in ["cv_bid", "spread", "mv", "n_firms"]:
        if screen in treat.columns:
            r = two_sample_t(treat[screen], control[screen], screen, f)
            if r is not None:
                rows.append(r)

    f.write("\nROC AUC for cartel detection (cartel-active vs clean control):\n")
    for screen in ["cv_bid", "spread", "mv"]:
        # Lower CV/spread/MV is more 'cartel-like' → higher_is_cartel=False
        auc = compute_auc(treat[screen], control[screen],
                          higher_is_cartel=False)
        if auc is not None:
            f.write(f"  {screen:30s}  AUC = {auc:.4f}  "
                    f"(0.5=chance, 1.0=perfect)\n")

    # Also test the COMPARISON: cartel-firm-listed (any time) vs clean
    f.write("\nAlternative grouping: cartel-listed firms (any time) vs clean:\n")
    treat2 = auction.filter(pl.col("has_any_cartel_firm") == 1)
    for screen in ["cv_bid", "spread", "mv"]:
        if screen in treat2.columns:
            two_sample_t(treat2[screen], control[screen],
                         f"{screen} (any-time)", f)
        auc = compute_auc(treat2[screen], control[screen],
                          higher_is_cartel=False)
        if auc is not None:
            f.write(f"  AUC ({screen} any-time): {auc:.4f}\n")


# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    t0 = time.time()
    print("=" * 70)
    print("Variance/CV screens vs CADE ground truth — Track A.4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # Load ground truth
    gt = pl.read_parquet(GT_PATH)
    print(f"\nGround truth: {gt.height:,} firm × cartel entries")

    # Build auction-level screens for pregão
    print("\n" + "─" * 70)
    print("PREGÃO ELETRÔNICO")
    print("─" * 70)

    # Need a firm-auction lookup for cartel-flag attachment
    pregao_fa = (
        pl.scan_parquet(SOURCE)
        .filter(pl.col("descriçãoprocedimentocompra") == "PREGÃO ELETRÔNICO")
        .filter(pl.col("bid_price") > 0)
        .with_columns(parse_year(pl.col("mêsanoencerramento")).alias("year"))
        .filter((pl.col("year") >= YEAR_RANGE[0]) &
                (pl.col("year") <= YEAR_RANGE[1]))
        .select([
            "numerodaoc", "códigoitem", "códigofornecedor", "year",
        ])
        .unique()
        .collect()
    )
    print(f"  pregão firm-auction lookup: {pregao_fa.height:,} rows")

    pregao_auctions = build_auction_screens("PREGÃO ELETRÔNICO")
    pregao_auctions = attach_cartel_flags(pregao_auctions, gt, pregao_fa)

    OUT_PREGAO.parent.mkdir(parents=True, exist_ok=True)
    pregao_auctions.write_parquet(OUT_PREGAO, compression="snappy")
    print(f"  [written] {OUT_PREGAO} ({OUT_PREGAO.stat().st_size/1e6:.1f} MB)")

    # Same for convite
    print("\n" + "─" * 70)
    print("CONVITE")
    print("─" * 70)

    convite_fa = (
        pl.scan_parquet(SOURCE)
        .filter(pl.col("descriçãoprocedimentocompra") == "CONVITE")
        .filter(pl.col("bid_price") > 0)
        .with_columns(parse_year(pl.col("mêsanoencerramento")).alias("year"))
        .filter((pl.col("year") >= YEAR_RANGE[0]) &
                (pl.col("year") <= YEAR_RANGE[1]))
        .select([
            "numerodaoc", "códigoitem", "códigofornecedor", "year",
        ])
        .unique()
        .collect()
    )
    print(f"  convite firm-auction lookup: {convite_fa.height:,} rows")

    convite_auctions = build_auction_screens("CONVITE")
    convite_auctions = attach_cartel_flags(convite_auctions, gt, convite_fa)
    convite_auctions.write_parquet(OUT_CONVITE, compression="snappy")
    print(f"  [written] {OUT_CONVITE} ({OUT_CONVITE.stat().st_size/1e6:.1f} MB)")

    # Evaluate screens vs ground truth
    OUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_REPORT, "w") as f:
        f.write(f"Variance/CV screens vs CADE ground truth\n")
        f.write(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n")

        evaluate(pregao_auctions, "PREGÃO ELETRÔNICO", f)
        evaluate(convite_auctions, "CONVITE", f)

    print(f"\n[written] {OUT_REPORT}")
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- key results (preview) ---")
    with open(OUT_REPORT) as f:
        print(f.read())


if __name__ == "__main__":
    main()
