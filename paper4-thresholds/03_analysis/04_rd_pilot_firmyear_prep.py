#!/usr/bin/env python3
"""
04_rd_pilot_firmyear_prep.py — Pivot 1 sample prep

Purpose
-------
Rebuild the RD analysis sample at the FIRM × YEAR level instead of firm × auction.
Addresses the double-counting issue in the script 03 pilot, where firms with
many auctions in a year were over-weighted in the pooled regression.

Design
------
For each (cnpj_raiz, year) in 2009–2015, we pick ONE key auction: the one
with the smallest |MV| (closest to the cutoff) in that year. That single
auction's MV becomes the running variable, and its flagvencedor becomes the
treatment. Outcomes are read from firm_year_panel at t+k (k ∈ {-1, 0, 1, 2}).

This is a legitimate sharp RD at the firm-year level, because each firm-year
has a single "closest contest" and the running variable is continuous around
zero.

Alternative aggregation considered but rejected
-----------------------------------------------
A continuous-intensity design (treatment = share of narrow auctions won)
would be a fuzzy-RD and requires different inference. We'd also need to take
a stand on the "intensity" definition, which is less transparent than the
closest-auction approach. Keeping it sharp for the pilot.

Input / output
--------------
  in:  02_data/final/df_convite_winner_looser.parquet
       02_data/firms/firm_year_panel.parquet
  out: 02_data/final/rd_pilot_firmyear_sample.parquet

Usage
-----
  python3 03_analysis/04_rd_pilot_firmyear_prep.py
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
BEC_ANALYSIS  = BASE / "02_data" / "final" / "df_convite_winner_looser.parquet"
FIRM_PANEL    = BASE / "02_data" / "firms" / "firm_year_panel.parquet"
OUTPUT        = BASE / "02_data" / "final" / "rd_pilot_firmyear_sample.parquet"

TREAT_YEARS_DEFAULT = list(range(2009, 2016))   # 2009–2015
MV_MAX_DEFAULT = 0.10


# ─────────────────────────────────────────────────────────────────────
def build_firmyear_key(mv_max: float, treat_years: list[int]) -> pl.DataFrame:
    """One row per (cnpj_raiz, year): the closest auction that firm was in."""
    print(f"Building firm-year key auctions, |MV|<{mv_max}, "
          f"{treat_years[0]}–{treat_years[-1]}...", flush=True)

    bec = (
        pl.scan_parquet(BEC_ANALYSIS)
        .select([
            "auction_item",
            pl.col("year").cast(pl.Int32).alias("year"),
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
            pl.col("firm").cast(pl.Int32).alias("firm_id"),
            pl.col("flagvencedor").cast(pl.Int8).alias("won"),
            pl.col("MV").cast(pl.Float64).alias("mv"),
            pl.col("valorunitárioproposta").cast(pl.Float64).alias("bid"),
            pl.col("valortotalproposta").cast(pl.Float64).alias("bid_total"),
            pl.col("códigoclasse").cast(pl.Int16).alias("item_class"),
            pl.col("códigogrupo").cast(pl.Int8).alias("item_group"),
            pl.col("códigounidadecompradora").alias("pbu_code"),
        ])
        .filter(pl.col("year").is_in(treat_years))
        .with_columns([
            pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"),
            pl.col("mv").abs().alias("abs_mv"),
        ])
        .collect()
    )
    print(f"  raw firm × auction rows (in window): {bec.height:,}")

    # Summary counts per firm-year (for intensity information we keep aside)
    counts = (
        bec.group_by(["cnpj_raiz", "year"])
        .agg([
            pl.len().alias("n_auctions_year"),
            pl.col("won").sum().alias("n_wins_year"),
            (pl.col("abs_mv") < 0.005).sum().alias("n_narrow_005"),
            (pl.col("abs_mv") < 0.01).sum().alias("n_narrow_010"),
            (pl.col("abs_mv") < 0.02).sum().alias("n_narrow_020"),
            ((pl.col("abs_mv") < 0.01) & (pl.col("won") == 1))
                .sum().alias("n_narrow_wins_010"),
        ])
    )
    print(f"  firm-year aggregates: {counts.height:,}")

    # Pick the closest auction per firm-year
    key = (
        bec.sort(["cnpj_raiz", "year", "abs_mv"])
        .group_by(["cnpj_raiz", "year"], maintain_order=True)
        .first()
    )
    print(f"  after closest-auction pick: {key.height:,}")

    # Apply |MV| envelope
    key = key.filter(pl.col("abs_mv") < mv_max)
    print(f"  after |MV|<{mv_max}: {key.height:,}")

    # Merge intensity counts
    key = key.join(counts, on=["cnpj_raiz", "year"], how="left")

    # Add derived cols
    key = key.with_columns([
        (pl.col("won") == 1).cast(pl.Int8).alias("treat"),
        (-pl.col("mv")).alias("running"),   # + running = won
        (pl.col("n_narrow_wins_010") / pl.col("n_narrow_010"))
            .alias("narrow_win_rate"),
    ])

    print(f"  Unique firms: {key['cnpj_raiz'].n_unique():,}")
    print(f"  Treat (won): {key['treat'].sum():,} "
          f"({100*key['treat'].mean():.1f}%)")
    return key


# ─────────────────────────────────────────────────────────────────────
def attach_outcomes(key: pl.DataFrame, panel: pl.DataFrame) -> pl.DataFrame:
    """Attach firm-year outcomes from panel at t+k."""
    print("\nAttaching firm-year outcomes at t-1, t, t+1, t+2...", flush=True)

    outcome_cols = [
        "n_employees_3112",
        "n_vinculos_total",
        "n_hires_year",
        "n_separations_year",
        "total_payroll_dez",
        "avg_wage_dez",
        "med_wage_dez",
        "share_female",
        "avg_age",
        "share_university",
        "avg_tenure_months",
        "share_managerial",
        "n_hires_from_public",
        "share_hires_from_public",
    ]

    panel_min = panel.select(["cnpj_raiz", "ano"] + outcome_cols)

    result = key
    # Include t-2 / t+3 for event-study identification check (parallel to
    # script 07 for pregão)
    for k in [-2, -1, 0, 1, 2, 3]:
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
    print(f"  Analysis sample: {result.height:,} rows, {len(result.columns)} cols")
    return result


# ─────────────────────────────────────────────────────────────────────
def compute_derived(df: pl.DataFrame) -> pl.DataFrame:
    print("\nComputing log and growth rates...", flush=True)
    df = df.with_columns([
        (pl.col("n_employees_3112_tm2") + 1).log().alias("log_emp_tm2"),
        (pl.col("n_employees_3112_tm1") + 1).log().alias("log_emp_tm1"),
        (pl.col("n_employees_3112_t0")  + 1).log().alias("log_emp_t0"),
        (pl.col("n_employees_3112_tp1") + 1).log().alias("log_emp_tp1"),
        (pl.col("n_employees_3112_tp2") + 1).log().alias("log_emp_tp2"),
        (pl.col("n_employees_3112_tp3") + 1).log().alias("log_emp_tp3"),

        (pl.col("total_payroll_dez_tm2").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tm2"),
        (pl.col("total_payroll_dez_tm1").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tm1"),
        (pl.col("total_payroll_dez_t0").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_t0"),
        (pl.col("total_payroll_dez_tp1").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tp1"),
        (pl.col("total_payroll_dez_tp2").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tp2"),
        (pl.col("total_payroll_dez_tp3").clip(lower_bound=0) + 1)
            .log().alias("log_payroll_tp3"),

        (pl.col("avg_wage_dez_tm1") + 1).log().alias("log_avg_wage_tm1"),
        (pl.col("avg_wage_dez_tp1") + 1).log().alias("log_avg_wage_tp1"),
    ])
    df = df.with_columns([
        (pl.col("log_emp_tp1") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp1_tm1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp2_tm1"),
        (pl.col("log_payroll_tp1") - pl.col("log_payroll_tm1"))
            .alias("dlog_payroll_tp1_tm1"),
        # Year-over-year growth (event-study spec)
        (pl.col("log_emp_tm1") - pl.col("log_emp_tm2"))
            .alias("dlog_emp_yoy_tm1"),
        (pl.col("log_emp_t0") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_yoy_t0"),
        (pl.col("log_emp_tp1") - pl.col("log_emp_t0"))
            .alias("dlog_emp_yoy_tp1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tp1"))
            .alias("dlog_emp_yoy_tp2"),
        (pl.col("log_emp_tp3") - pl.col("log_emp_tp2"))
            .alias("dlog_emp_yoy_tp3"),
        (pl.col("log_payroll_tm1") - pl.col("log_payroll_tm2"))
            .alias("dlog_payroll_yoy_tm1"),
        (pl.col("log_payroll_t0") - pl.col("log_payroll_tm1"))
            .alias("dlog_payroll_yoy_t0"),
        (pl.col("log_payroll_tp1") - pl.col("log_payroll_t0"))
            .alias("dlog_payroll_yoy_tp1"),
        (pl.col("log_payroll_tp2") - pl.col("log_payroll_tp1"))
            .alias("dlog_payroll_yoy_tp2"),
        (pl.col("log_payroll_tp3") - pl.col("log_payroll_tp2"))
            .alias("dlog_payroll_yoy_tp3"),
    ])
    return df


# ─────────────────────────────────────────────────────────────────────
def sanity_report(df: pl.DataFrame) -> None:
    print("\n" + "=" * 70)
    print("  SANITY REPORT (firm-year)")
    print("=" * 70)
    print(f"  Rows (firm-years): {df.height:,}")
    print(f"  Unique firms: {df['cnpj_raiz'].n_unique():,}")
    print(f"  Year range: {df['year'].min()}–{df['year'].max()}")

    # n_auctions distribution — how many auctions per firm-year did we collapse?
    print("\n  n_auctions per firm-year (in window) — what we collapsed:")
    print(df["n_auctions_year"].describe())

    # Coverage of main outcome
    print("\n  Coverage of outcomes:")
    for col in ["log_emp_tm1", "log_emp_tp1", "log_emp_tp2",
                "dlog_emp_tp1_tm1", "survived_tp1", "survived_tp2"]:
        if col in df.columns:
            frac = 1 - df[col].null_count() / df.height
            print(f"    {col:20s}: {100*frac:5.1f}%")

    # Close-bid subsample sizes
    print("\n  Observations within each bandwidth:")
    for h in [0.005, 0.01, 0.02, 0.05]:
        n = df.filter(pl.col("running").abs() < h).height
        n_cov = df.filter(
            (pl.col("running").abs() < h) & pl.col("log_emp_tp1").is_not_null()
        ).height
        print(f"    |r|<{h:.3f}: n={n:>7,}  with log_emp_tp1={n_cov:>7,}")


# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mv-max", type=float, default=MV_MAX_DEFAULT)
    args = parser.parse_args()

    t0 = time.time()
    print("RD firm-year pilot prep — Paper 4 / Caminho 1 / Pivot 1")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    key = build_firmyear_key(args.mv_max, TREAT_YEARS_DEFAULT)

    print("\nLoading firm-year panel...", flush=True)
    panel = pl.read_parquet(FIRM_PANEL)
    print(f"  Panel: {panel.height:,} firm-years")

    df = attach_outcomes(key, panel)
    df = compute_derived(df)
    sanity_report(df)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    df.write_parquet(OUTPUT, compression="snappy")
    size_mb = OUTPUT.stat().st_size / 1e6
    print(f"\n[written] {OUTPUT} ({size_mb:.1f} MB)")

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
