#!/usr/bin/env python3
"""
05_build_pregao_pairs.py — Build pregão winner-loser pair file for Pivot 4

Purpose
-------
Construct an analogue of 02_data/final/df_convite_winner_looser.parquet for
PREGÃO ELETRÔNICO auctions, using the paper3 bid_level_with_prices.parquet
as source.

Source subtlety
---------------
In paper3's bid_level_with_prices.parquet, the pregão slice stores one row
per BID event (descending auction → each bidder can bid multiple times).
So we cannot treat rows as firm × auction directly.

Pipeline
--------
1. Filter to PREGÃO ELETRÔNICO.
2. Aggregate by (auction, firm) → firm's BEST (minimum) bid in that auction
   + indicator of whether any of that firm's bids had won=1.
3. For each auction, identify the winner (firm with won=1 flag, tie-break
   on lowest best bid) and the runner-up (second-lowest best bid among all
   firms in the auction, excluding the winner).
4. Compute MV = (runner_up_bid - winner_bid) / winner_bid.
5. Write two rows per auction (winner + runner-up) to the output file.

Filters
-------
- Only auctions with ≥2 unique bidders (need winner + runner-up).
- Only auctions with exactly 1 identified winner (drops ambiguous multi-winner
  auctions; majority of pregão auctions are 1-winner).
- Year range: 2009–2019 (same as source).

Output
------
  02_data/final/df_pregao_winner_looser.parquet

Usage
-----
  python3 03_analysis/05_build_pregao_pairs.py
"""
from __future__ import annotations

import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
SOURCE = Path(
    "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/"
    "data/processed/bid_level_with_prices.parquet"
)
OUTPUT = BASE / "02_data" / "final" / "df_pregao_winner_looser.parquet"


def main() -> None:
    t0 = time.time()
    print("Build pregão winner-loser pairs — Paper 4 / Pivot 4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    print(f"\n[1] Loading pregão bids from {SOURCE.name}...", flush=True)
    pregao = (
        pl.scan_parquet(SOURCE)
        .filter(pl.col("descriçãoprocedimentocompra") == "PREGÃO ELETRÔNICO")
        .filter(pl.col("bid_price") > 0)   # drop missing / zero bids
        .select([
            "mêsanoencerramento",
            "numerodaoc",
            "códigoitem",
            "códigofornecedor",
            "códigounidadecompradora",
            "bid_price",
            "ref_price",
            "won",
        ])
        .with_columns([
            # Year from "MM/YYYY"
            pl.col("mêsanoencerramento").str.slice(3, 4).cast(pl.Int32).alias("year"),
        ])
        .collect()
    )
    print(f"  pregão bid rows: {pregao.height:,}")

    # ref_price is reliably populated only on winning rows in the source.
    # Build a separate auction-level ref_price lookup from those rows.
    print("[1b] Building auction-level ref_price from winning rows...",
          flush=True)
    auction_ref = (
        pregao.filter(pl.col("won") == 1)
        .filter(pl.col("ref_price").is_not_null())
        .group_by(["numerodaoc", "códigoitem"])
        .agg(pl.col("ref_price").max().alias("ref_price_auction"))
    )
    print(f"  auctions with ref_price: {auction_ref.height:,}")

    print("\n[2] Aggregating to firm × auction best bid...", flush=True)
    firm_auction = (
        pregao.group_by(
            ["numerodaoc", "códigoitem", "códigofornecedor"]
        )
        .agg([
            pl.col("bid_price").min().alias("best_bid"),
            pl.col("won").max().alias("is_winner"),   # any winning bid → 1
            pl.col("year").first().alias("year"),
            pl.col("códigounidadecompradora").first().alias("pbu_code"),
            # Use max to skip nulls (ref_price is sparse in source)
            pl.col("ref_price").max().alias("ref_price"),
        ])
    )
    print(f"  firm × auction rows: {firm_auction.height:,}")

    print("\n[3] Identifying winner and runner-up per auction...", flush=True)
    # Winners: firms with is_winner=1. Pick the one with min best_bid in case of ties.
    winners = (
        firm_auction.filter(pl.col("is_winner") == 1)
        .sort(["numerodaoc", "códigoitem", "best_bid"])
        .group_by(["numerodaoc", "códigoitem"], maintain_order=True)
        .first()
        .select([
            "numerodaoc",
            "códigoitem",
            pl.col("códigofornecedor").alias("winner_cnpj"),
            pl.col("best_bid").alias("winner_bid"),
        ])
    )
    print(f"  auctions with a winner: {winners.height:,}")

    # Drop auctions with multiple distinct winners (ambiguous)
    winner_counts = (
        firm_auction.filter(pl.col("is_winner") == 1)
        .group_by(["numerodaoc", "códigoitem"])
        .agg(pl.col("códigofornecedor").n_unique().alias("n_winners"))
    )
    single_winner = winner_counts.filter(pl.col("n_winners") == 1).select(
        ["numerodaoc", "códigoitem"]
    )
    winners_clean = winners.join(
        single_winner, on=["numerodaoc", "códigoitem"], how="inner"
    )
    print(f"  auctions with exactly 1 winner: {winners_clean.height:,}")

    # For each clean-winner auction, compute the runner-up = lowest best_bid
    # among non-winner firms in that auction
    non_winners = firm_auction.join(
        winners_clean.select(["numerodaoc", "códigoitem", "winner_cnpj"]),
        on=["numerodaoc", "códigoitem"],
        how="inner",
    ).filter(pl.col("códigofornecedor") != pl.col("winner_cnpj"))
    print(f"  non-winner firm × auction rows: {non_winners.height:,}")

    runners_up = (
        non_winners.sort(["numerodaoc", "códigoitem", "best_bid"])
        .group_by(["numerodaoc", "códigoitem"], maintain_order=True)
        .first()
        .select([
            "numerodaoc",
            "códigoitem",
            pl.col("códigofornecedor").alias("runnerup_cnpj"),
            pl.col("best_bid").alias("runnerup_bid"),
            "year",
            "pbu_code",
            "ref_price",
        ])
    )
    print(f"  auctions with a runner-up: {runners_up.height:,}")

    auction_key = (
        winners_clean.join(runners_up, on=["numerodaoc", "códigoitem"], how="inner")
        .join(auction_ref, on=["numerodaoc", "códigoitem"], how="left")
        .with_columns([
            (
                (pl.col("runnerup_bid") - pl.col("winner_bid"))
                / pl.col("winner_bid")
            ).alias("MV"),
            # Replace the per-firm ref_price (mostly null) with the
            # auction-level lookup
            pl.col("ref_price_auction").alias("ref_price"),
        ])
    )
    print(f"  final auctions with winner + runner-up: {auction_key.height:,}")

    print("\n[4] Building winner-loser pair file (2 rows per auction)...", flush=True)

    winner_rows = auction_key.select([
        pl.lit("PREGAO").alias("proc_type"),
        pl.col("numerodaoc"),
        pl.col("códigoitem"),
        pl.concat_str([pl.col("numerodaoc"), pl.lit("_"), pl.col("códigoitem")])
            .alias("auction_item"),
        pl.col("year"),
        pl.col("winner_cnpj").alias("códigofornecedor"),
        pl.lit(1, dtype=pl.Int8).alias("flagvencedor"),
        pl.col("winner_bid").alias("valorunitárioproposta"),
        (-pl.col("MV")).alias("MV"),   # winner side has MV<0 (matches convite convention)
        pl.col("ref_price").alias("valorunitárioreferência"),
        pl.col("pbu_code").alias("códigounidadecompradora"),
    ])
    loser_rows = auction_key.select([
        pl.lit("PREGAO").alias("proc_type"),
        pl.col("numerodaoc"),
        pl.col("códigoitem"),
        pl.concat_str([pl.col("numerodaoc"), pl.lit("_"), pl.col("códigoitem")])
            .alias("auction_item"),
        pl.col("year"),
        pl.col("runnerup_cnpj").alias("códigofornecedor"),
        pl.lit(0, dtype=pl.Int8).alias("flagvencedor"),
        pl.col("runnerup_bid").alias("valorunitárioproposta"),
        pl.col("MV").alias("MV"),       # loser side has MV>0
        pl.col("ref_price").alias("valorunitárioreferência"),
        pl.col("pbu_code").alias("códigounidadecompradora"),
    ])
    pairs = pl.concat([winner_rows, loser_rows]).sort(["auction_item", "flagvencedor"])
    print(f"  pair rows: {pairs.height:,}")

    print("\n[5] Writing output...", flush=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pairs.write_parquet(OUTPUT, compression="snappy")
    size_mb = OUTPUT.stat().st_size / 1e6
    print(f"  [written] {OUTPUT} ({size_mb:.1f} MB)")

    # Report
    print("\n=== REPORT ===")
    print(f"  Unique pregão auctions: {pairs['auction_item'].n_unique():,}")
    print(f"  Unique firms: {pairs['códigofornecedor'].n_unique():,}")
    print(f"  Year range: {pairs['year'].min()}–{pairs['year'].max()}")
    print()
    print("  MV distribution:")
    print(pairs["MV"].describe())
    print()
    print("  Close-bid subsamples:")
    for h in [0.005, 0.01, 0.02, 0.05, 0.10]:
        n = pairs.filter(pl.col("MV").abs() < h).height
        print(f"    |MV|<{h:.3f}: {n:>10,}")
    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
