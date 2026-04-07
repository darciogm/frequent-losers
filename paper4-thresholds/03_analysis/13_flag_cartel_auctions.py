#!/usr/bin/env python3
"""
13_flag_cartel_auctions.py — Auction-level cartel exposure flags

Purpose
-------
Take the firm-level CADE ground truth from script 12 and produce
auction-level "cartel exposure" flags by joining with BEC pregão and
convite pair files. This is the input for screen-evaluation analyses.

For each (auction, firm) row, compute:
  - cartel_firm           : is this firm in CADE ground truth (any process)?
  - cartel_in_period      : is this firm cartelized AND auction year falls
                            within the cartel's active period?
  - cartel_setor          : sector of the cartel (if any)

Then aggregate to auction level:
  - has_any_cartel_firm   : at least one firm in this auction is in CADE
  - has_active_cartel     : at least one firm is cartelized in the year of
                            the auction
  - n_cartel_firms        : count of cartel firms participating
  - winner_is_cartel      : the winner specifically is a cartel firm
  - runnerup_is_cartel    : the runner-up specifically is a cartel firm
  - both_cartel           : both winner and runner-up are cartel firms (pair
                            match — strongest signal of designated rotation)

Outputs
-------
  02_data/final/df_pregao_with_cartel_flags.parquet
  02_data/final/df_convite_with_cartel_flags.parquet
  02_data/intermediate/cartel_auction_coverage.txt
"""
from __future__ import annotations

import time
from pathlib import Path

import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
GT_PATH      = BASE / "02_data" / "firms" / "cade_ground_truth.parquet"
PREGAO_PATH  = BASE / "02_data" / "final" / "df_pregao_winner_looser.parquet"
CONVITE_PATH = BASE / "02_data" / "final" / "df_convite_winner_looser.parquet"

OUT_PREGAO   = BASE / "02_data" / "final" / "df_pregao_with_cartel_flags.parquet"
OUT_CONVITE  = BASE / "02_data" / "final" / "df_convite_with_cartel_flags.parquet"
OUT_REPORT   = BASE / "02_data" / "intermediate" / "cartel_auction_coverage.txt"


def load_gt() -> pl.DataFrame:
    """Load and prepare cartel firm-period table."""
    gt = pl.read_parquet(GT_PATH)
    # Keep only entries with both cnpj_raiz AND cartel period (we need
    # period to define exposure during specific years)
    gt = gt.filter(
        pl.col("cnpj_raiz").is_not_null()
        & pl.col("cartel_start_year").is_not_null()
    )
    print(f"  ground-truth firms with period info: {gt.height}")
    print(f"  unique cnpj_raiz: {gt['cnpj_raiz'].n_unique()}")
    return gt


def attach_cartel_flags_pregao(gt: pl.DataFrame) -> pl.DataFrame:
    """Attach cartel flags to the pregão winner-loser pair file."""
    print("\n[pregão] loading pair file...", flush=True)
    pairs = pl.read_parquet(PREGAO_PATH)
    print(f"  rows: {pairs.height:,}")

    pairs = pairs.with_columns([
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
            .str.slice(0, 8).alias("cnpj_raiz"),
    ])

    # Build a per-(cnpj_raiz, year) cartel-active table
    # A firm is "cartel-active" in year y if any of its CADE entries has
    # cartel_start_year <= y <= cartel_end_year
    print("  building firm-year cartel activity table...", flush=True)

    # Expand each ground-truth row into firm × year
    gt_expanded = gt.select([
        "cnpj_raiz",
        "processo",
        "setor",
        pl.col("cartel_start_year").cast(pl.Int32),
        pl.col("cartel_end_year").cast(pl.Int32),
    ]).with_columns(
        pl.int_ranges(
            pl.col("cartel_start_year"),
            pl.col("cartel_end_year") + 1,
        ).alias("year_list")
    ).explode("year_list").rename({"year_list": "year"}).drop([
        "cartel_start_year", "cartel_end_year"
    ])
    print(f"  firm-year cartel rows: {gt_expanded.height:,}")
    print(f"  unique firm-years cartelized: "
          f"{gt_expanded.select(['cnpj_raiz','year']).unique().height:,}")

    # Mark per-firm flags (any-time, regardless of year)
    cartel_firms = gt.select([
        "cnpj_raiz",
        pl.col("setor").alias("cartel_setor_any"),
    ]).unique(subset=["cnpj_raiz"])

    pairs = pairs.join(cartel_firms, on="cnpj_raiz", how="left")
    pairs = pairs.with_columns(
        pl.col("cartel_setor_any").is_not_null()
            .cast(pl.Int8)
            .alias("cartel_firm")
    )
    print(f"  rows where firm is cartel-listed (anytime): "
          f"{pairs['cartel_firm'].sum():,}")

    # Active-period flag (year-specific)
    cartel_active = gt_expanded.unique(subset=["cnpj_raiz", "year"]).with_columns(
        pl.lit(1, dtype=pl.Int8).alias("cartel_in_period")
    ).select(["cnpj_raiz", "year", "cartel_in_period"])

    pairs = pairs.join(
        cartel_active, on=["cnpj_raiz", "year"], how="left"
    ).with_columns(
        pl.col("cartel_in_period").fill_null(0)
    )
    print(f"  rows where firm is cartel-active in auction year: "
          f"{pairs['cartel_in_period'].sum():,}")

    # ─────────────────────────────────────────────────────────────────
    # Aggregate to auction level
    # ─────────────────────────────────────────────────────────────────
    print("\n  computing auction-level cartel exposure...", flush=True)
    auction_agg = (
        pairs.group_by("auction_item")
        .agg([
            pl.col("cartel_firm").max().alias("has_any_cartel_firm"),
            pl.col("cartel_in_period").max().alias("has_active_cartel"),
            pl.col("cartel_firm").sum().alias("n_cartel_firms"),
            pl.col("cartel_in_period").sum().alias("n_cartel_active"),
            # Winner-specific
            ((pl.col("flagvencedor") == 1) & (pl.col("cartel_firm") == 1))
                .max().alias("winner_is_cartel_firm"),
            ((pl.col("flagvencedor") == 1) & (pl.col("cartel_in_period") == 1))
                .max().alias("winner_is_cartel_active"),
            # Runner-up specific
            ((pl.col("flagvencedor") == 0) & (pl.col("cartel_firm") == 1))
                .max().alias("runnerup_is_cartel_firm"),
            ((pl.col("flagvencedor") == 0) & (pl.col("cartel_in_period") == 1))
                .max().alias("runnerup_is_cartel_active"),
        ])
        .with_columns([
            ((pl.col("winner_is_cartel_firm") == 1) &
             (pl.col("runnerup_is_cartel_firm") == 1))
                .cast(pl.Int8).alias("both_cartel_firm"),
            ((pl.col("winner_is_cartel_active") == 1) &
             (pl.col("runnerup_is_cartel_active") == 1))
                .cast(pl.Int8).alias("both_cartel_active"),
        ])
    )

    pairs = pairs.join(auction_agg, on="auction_item", how="left")
    print(f"  augmented pair file: {pairs.shape}")
    return pairs, auction_agg


def attach_cartel_flags_convite(gt: pl.DataFrame) -> pl.DataFrame:
    """Same logic for convite. Convite file has different schema (no
    proc_type)."""
    print("\n[convite] loading pair file...", flush=True)
    pairs = pl.scan_parquet(CONVITE_PATH).select([
        "auction_item",
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
        pl.col("year").cast(pl.Int32),
        pl.col("flagvencedor").cast(pl.Int8),
        pl.col("MV").cast(pl.Float64),
    ]).with_columns(
        pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz")
    ).collect()
    print(f"  rows: {pairs.height:,}")

    cartel_firms = gt.select([
        "cnpj_raiz",
        pl.col("setor").alias("cartel_setor_any"),
    ]).unique(subset=["cnpj_raiz"])

    pairs = pairs.join(cartel_firms, on="cnpj_raiz", how="left")
    pairs = pairs.with_columns(
        pl.col("cartel_setor_any").is_not_null()
            .cast(pl.Int8)
            .alias("cartel_firm")
    )
    print(f"  rows where firm is cartel-listed: "
          f"{pairs['cartel_firm'].sum():,}")

    gt_expanded = gt.select([
        "cnpj_raiz",
        pl.col("cartel_start_year").cast(pl.Int32),
        pl.col("cartel_end_year").cast(pl.Int32),
    ]).with_columns(
        pl.int_ranges(
            pl.col("cartel_start_year"),
            pl.col("cartel_end_year") + 1,
        ).alias("year_list")
    ).explode("year_list").rename({"year_list": "year"}).drop([
        "cartel_start_year", "cartel_end_year"
    ])

    cartel_active = gt_expanded.unique(subset=["cnpj_raiz", "year"]).with_columns(
        pl.lit(1, dtype=pl.Int8).alias("cartel_in_period")
    )

    pairs = pairs.join(
        cartel_active, on=["cnpj_raiz", "year"], how="left"
    ).with_columns(
        pl.col("cartel_in_period").fill_null(0)
    )
    print(f"  rows where firm is cartel-active in auction year: "
          f"{pairs['cartel_in_period'].sum():,}")

    auction_agg = (
        pairs.group_by("auction_item")
        .agg([
            pl.col("cartel_firm").max().alias("has_any_cartel_firm"),
            pl.col("cartel_in_period").max().alias("has_active_cartel"),
            pl.col("cartel_firm").sum().alias("n_cartel_firms"),
            ((pl.col("flagvencedor") == 1) & (pl.col("cartel_firm") == 1))
                .max().alias("winner_is_cartel_firm"),
            ((pl.col("flagvencedor") == 0) & (pl.col("cartel_firm") == 1))
                .max().alias("runnerup_is_cartel_firm"),
        ])
        .with_columns(
            ((pl.col("winner_is_cartel_firm") == 1) &
             (pl.col("runnerup_is_cartel_firm") == 1))
                .cast(pl.Int8).alias("both_cartel_firm")
        )
    )
    pairs = pairs.join(auction_agg, on="auction_item", how="left")
    return pairs, auction_agg


def report_coverage(label, pairs, auction_agg, f):
    f.write(f"\n{'='*60}\n{label}\n{'='*60}\n")
    f.write(f"Total pair rows: {pairs.height:,}\n")
    f.write(f"Total unique auctions: {pairs['auction_item'].n_unique():,}\n\n")

    n_auctions = auction_agg.height
    n_any_cartel = auction_agg["has_any_cartel_firm"].sum()
    n_active = (auction_agg["has_active_cartel"].sum() if
                "has_active_cartel" in auction_agg.columns else None)

    f.write(f"Auctions with ≥1 cartel-listed firm:    {n_any_cartel:>8,} "
            f"({100*n_any_cartel/n_auctions:.2f}%)\n")
    if n_active is not None:
        f.write(f"Auctions with ≥1 cartel-active firm:    {n_active:>8,} "
                f"({100*n_active/n_auctions:.2f}%)\n")

    n_winner = auction_agg["winner_is_cartel_firm"].sum()
    n_runner = auction_agg["runnerup_is_cartel_firm"].sum()
    n_both = auction_agg["both_cartel_firm"].sum()

    f.write(f"Auctions where winner is cartel firm:   {n_winner:>8,} "
            f"({100*n_winner/n_auctions:.2f}%)\n")
    f.write(f"Auctions where runner-up is cartel firm:{n_runner:>8,} "
            f"({100*n_runner/n_auctions:.2f}%)\n")
    f.write(f"Auctions where BOTH are cartel firms:   {n_both:>8,} "
            f"({100*n_both/n_auctions:.2f}%)\n")
    f.write("  ↑ This is the strongest signal: pair-matched cartel "
            "head-to-head\n")
    print(f"  {label}: {n_any_cartel:,} / {n_auctions:,} auctions cartel-exposed; "
          f"{n_both:,} pair-matched")


def main() -> None:
    t0 = time.time()
    print("=" * 70)
    print("Auction-level cartel exposure flags — Track A")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    print("\n[1] Loading CADE ground truth...")
    gt = load_gt()

    pregao, pregao_agg = attach_cartel_flags_pregao(gt)
    convite, convite_agg = attach_cartel_flags_convite(gt)

    print("\n[2] Writing outputs...")
    OUT_PREGAO.parent.mkdir(parents=True, exist_ok=True)
    pregao.write_parquet(OUT_PREGAO, compression="snappy")
    print(f"  [written] {OUT_PREGAO} ({OUT_PREGAO.stat().st_size/1e6:.1f} MB)")

    convite.write_parquet(OUT_CONVITE, compression="snappy")
    print(f"  [written] {OUT_CONVITE} ({OUT_CONVITE.stat().st_size/1e6:.1f} MB)")

    print("\n[3] Coverage report...")
    OUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_REPORT, "w") as f:
        f.write(f"Cartel auction coverage — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n")
        report_coverage("PREGÃO", pregao, pregao_agg, f)
        report_coverage("CONVITE", convite, convite_agg, f)

        # Cross-tab by year for pregão
        f.write("\n\nPregão cartel-exposed auctions by year:\n")
        f.write(str(
            pregao.group_by("year")
                .agg([
                    pl.col("auction_item").n_unique().alias("n_auctions"),
                    ((pl.col("cartel_firm") == 1) & (pl.col("flagvencedor") == 1))
                        .sum().alias("winner_is_cartel"),
                    ((pl.col("cartel_in_period") == 1) & (pl.col("flagvencedor") == 1))
                        .sum().alias("winner_cartel_active"),
                    pl.col("cartel_in_period").sum().alias("rows_cartel_active"),
                ])
                .sort("year")
        ))

    print(f"  [written] {OUT_REPORT}")

    # Print summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    n_pregao_active = pregao_agg["has_active_cartel"].sum()
    n_pregao_total = pregao_agg.height
    n_pregao_both = pregao_agg["both_cartel_active"].sum()
    print(f"  Pregão: {n_pregao_active:,} / {n_pregao_total:,} auctions "
          f"have ≥1 cartel-active firm "
          f"({100*n_pregao_active/n_pregao_total:.2f}%)")
    print(f"  Pregão: {n_pregao_both:,} 'pair-matched' (both winner AND "
          f"runner-up are cartel-active)")

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
