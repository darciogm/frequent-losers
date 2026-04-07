#!/usr/bin/env python3
"""
06_rd_pregao_prep.py — Build RD analysis sample for PREGÃO (Pivot 4)

Analog of 03_rd_pilot_prep.py but using df_pregao_winner_looser.parquet
(built by 05_build_pregao_pairs.py) as input.

Key differences from the convite prep:
  - Source file has fewer columns; `item_class`, `item_group`, Kawai-style
    `was_incumbent`, `was_last_bid` are absent.
  - Pregão has much wider MV distribution with extreme outliers from near-zero
    winning bids; we drop |MV| > 10 before further processing.
  - `last bid` outcome is mechanically near 1 for the winner in a descending
    auction (the last bid is always the winning bid), so we do not use it.
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
SOURCE_DEFAULT = BASE / "02_data" / "final" / "df_pregao_winner_looser.parquet"
PANEL_PATH     = BASE / "02_data" / "firms" / "firm_year_panel.parquet"
OUTPUT_DEFAULT = BASE / "02_data" / "final" / "rd_pilot_pregao_sample.parquet"

TREAT_YEARS_DEFAULT = list(range(2009, 2016))  # 2009–2015 for RAIS window
MV_MAX_DEFAULT = 0.10


def load_bec(path: Path, mv_max: float, treat_years: list[int]) -> pl.DataFrame:
    print(f"Loading pregão pairs from {path.name}...", flush=True)
    bec = (
        pl.scan_parquet(path)
        .filter(pl.col("year").is_in(treat_years))
        # drop outliers from near-zero winning bids
        .filter(pl.col("MV").abs() < mv_max)
        .with_columns([
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
            pl.col("flagvencedor").cast(pl.Int8).alias("won"),
            (-pl.col("MV")).alias("running"),   # + running = won (convention)
        ])
        .with_columns(pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"))
        .rename({
            "valorunitárioproposta": "bid",
            "valorunitárioreferência": "ref_price",
            "códigounidadecompradora": "pbu_code",
        })
        .select([
            "auction_item", "year", "cnpj_full", "cnpj_raiz",
            "won", "MV", "running", "bid", "ref_price", "pbu_code",
            pl.col("won").alias("treat"),
        ])
        .collect()
    )
    print(f"  rows: {bec.height:,}")
    print(f"  unique firms: {bec['cnpj_raiz'].n_unique():,}")
    print(f"  unique auctions: {bec['auction_item'].n_unique():,}")
    return bec


def attach_outcomes(bec: pl.DataFrame, panel: pl.DataFrame) -> pl.DataFrame:
    print("\nAttaching firm-year outcomes at t-1, t, t+1, t+2...", flush=True)

    outcome_cols = [
        "n_employees_3112", "n_vinculos_total", "n_hires_year",
        "n_separations_year", "total_payroll_dez", "avg_wage_dez",
        "med_wage_dez", "share_female", "avg_age", "share_university",
        "avg_tenure_months", "share_managerial",
        "n_hires_from_public", "share_hires_from_public",
    ]
    panel_min = panel.select(["cnpj_raiz", "ano"] + outcome_cols)

    result = bec
    for k in [-1, 0, 1, 2]:
        suffix = f"_t{'m' if k < 0 else 'p' if k > 0 else ''}{abs(k)}"
        lookup = (
            panel_min
            .with_columns((pl.col("ano") - k).alias("_join_year"))
            .rename({c: c + suffix for c in outcome_cols})
            .drop("ano")
            .rename({"_join_year": "year"})
        )
        result = result.join(lookup, on=["cnpj_raiz", "year"], how="left")
        result = result.with_columns(
            pl.col(f"n_employees_3112{suffix}").is_not_null()
                .cast(pl.Int8)
                .alias(f"survived{suffix}")
        )
    print(f"  analysis sample: {result.height:,} rows")
    return result


def compute_derived(df: pl.DataFrame) -> pl.DataFrame:
    df = df.with_columns([
        (pl.col("n_employees_3112_tm1") + 1).log().alias("log_emp_tm1"),
        (pl.col("n_employees_3112_t0")  + 1).log().alias("log_emp_t0"),
        (pl.col("n_employees_3112_tp1") + 1).log().alias("log_emp_tp1"),
        (pl.col("n_employees_3112_tp2") + 1).log().alias("log_emp_tp2"),

        (pl.col("total_payroll_dez_tm1").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tm1"),
        (pl.col("total_payroll_dez_t0").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_t0"),
        (pl.col("total_payroll_dez_tp1").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tp1"),
        (pl.col("total_payroll_dez_tp2").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tp2"),

        (pl.col("avg_wage_dez_tm1") + 1).log().alias("log_avg_wage_tm1"),
        (pl.col("avg_wage_dez_tp1") + 1).log().alias("log_avg_wage_tp1"),

        # Contract stakes proxy: log(ref price × 1)
        (pl.col("ref_price").clip(lower_bound=0) + 1)
            .log().alias("log_ref_price"),
    ])
    df = df.with_columns([
        (pl.col("log_emp_tp1") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp1_tm1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp2_tm1"),
        (pl.col("log_payroll_tp1") - pl.col("log_payroll_tm1"))
            .alias("dlog_payroll_tp1_tm1"),
    ])
    return df


def sanity_report(df: pl.DataFrame) -> None:
    print("\n" + "=" * 70)
    print("  SANITY REPORT (pregão pair-level)")
    print("=" * 70)
    print(f"  Rows: {df.height:,}")
    print(f"  Unique firms: {df['cnpj_raiz'].n_unique():,}")
    print(f"  Unique auctions: {df['auction_item'].n_unique():,}")

    print("\n  Coverage of outcomes:")
    for col in ["log_emp_tm1", "log_emp_tp1", "log_emp_tp2",
                "dlog_emp_tp1_tm1", "survived_tp1", "survived_tp2"]:
        if col in df.columns:
            frac = 1 - df[col].null_count() / df.height
            print(f"    {col:20s}: {100*frac:5.1f}%")

    print("\n  Running variable (flipped MV):")
    print(df["running"].describe())

    print("\n  Observations within each bandwidth:")
    for h in [0.005, 0.01, 0.02, 0.05]:
        n = df.filter(pl.col("running").abs() < h).height
        n_cov = df.filter(
            (pl.col("running").abs() < h) & pl.col("log_emp_tp1").is_not_null()
        ).height
        print(f"    |r|<{h:.3f}: n={n:>9,}  with log_emp_tp1={n_cov:>9,}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE_DEFAULT)
    parser.add_argument("--output", type=Path, default=OUTPUT_DEFAULT)
    parser.add_argument("--mv-max", type=float, default=MV_MAX_DEFAULT)
    args = parser.parse_args()

    t0 = time.time()
    print("Pregão RD prep — Paper 4 / Pivot 4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    bec = load_bec(args.source, args.mv_max, TREAT_YEARS_DEFAULT)
    panel = pl.read_parquet(PANEL_PATH)
    print(f"\nPanel: {panel.height:,} firm-years")
    df = attach_outcomes(bec, panel)
    df = compute_derived(df)
    sanity_report(df)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.write_parquet(args.output, compression="snappy")
    print(f"\n[written] {args.output} ({args.output.stat().st_size/1e6:.1f} MB)")
    print(f"Total time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
