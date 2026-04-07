#!/usr/bin/env python3
"""
07_rd_pregao_firmyear_prep.py — Pregão Pivot 1 (firm × year)

Purpose
-------
Robustness check for the pregão pilot: rebuild the analysis sample at the
firm × year level instead of firm × auction. Each firm-year is represented by
its closest pregão auction in that year (smallest |MV|, after dropping exact
ties). Eliminates the double-counting that may inflate variance and bias
inference in the firm × auction spec.

Pipeline
--------
1. Load df_pregao_winner_looser, restrict to treatment years 2009-2015,
   drop exact ties (|MV| < 1e-6), drop |MV| > 0.10 (envelope).
2. For each (cnpj_raiz, year), pick the row with smallest |MV| (the
   firm-year's "key" pregão contest).
3. Join with firm_year_panel for outcomes at t-1, t, t+1, t+2.
4. Compute log outcomes and growth rates.
5. Write 02_data/final/rd_pilot_pregao_firmyear_sample.parquet.

Notes
-----
- Donut threshold 1e-6 is applied BEFORE the closest-auction selection so
  that ties don't artificially become a firm-year's "closest" contest.
- We also persist intensity counts (n auctions per firm-year, n narrow
  wins, etc.) for descriptive use.
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
PAIRS_PATH = BASE / "02_data" / "final" / "df_pregao_winner_looser.parquet"
PANEL_PATH = BASE / "02_data" / "firms" / "firm_year_panel.parquet"
OUTPUT     = BASE / "02_data" / "final" / "rd_pilot_pregao_firmyear_sample.parquet"

TREAT_YEARS_DEFAULT = list(range(2009, 2016))
MV_MAX_DEFAULT = 0.10
DONUT_EPSILON = 1e-6


def build_firmyear_key(mv_max: float, treat_years: list[int]) -> pl.DataFrame:
    print(f"Loading pregão pairs, |MV|<{mv_max}, donut>{DONUT_EPSILON}, "
          f"years {treat_years[0]}–{treat_years[-1]}...", flush=True)

    bec = (
        pl.scan_parquet(PAIRS_PATH)
        .filter(pl.col("year").is_in(treat_years))
        .filter(pl.col("MV").abs() < mv_max)
        .filter(pl.col("MV").abs() >= DONUT_EPSILON)
        .with_columns([
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
            pl.col("flagvencedor").cast(pl.Int8).alias("won"),
            pl.col("MV").abs().alias("abs_mv"),
        ])
        .with_columns(pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"))
        .collect()
    )
    print(f"  raw filtered rows: {bec.height:,}")

    # Intensity counts per firm-year
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

    # Closest auction per firm-year
    key = (
        bec.sort(["cnpj_raiz", "year", "abs_mv"])
        .group_by(["cnpj_raiz", "year"], maintain_order=True)
        .first()
    )
    print(f"  after closest-auction pick: {key.height:,}")

    # Join intensity
    key = key.join(counts, on=["cnpj_raiz", "year"], how="left")

    key = key.with_columns([
        (pl.col("won") == 1).cast(pl.Int8).alias("treat"),
        (-pl.col("MV")).alias("running"),  # +running = won
    ])
    print(f"  treat share: {100*key['treat'].mean():.1f}%")
    print(f"  unique firms: {key['cnpj_raiz'].n_unique():,}")
    return key


def attach_outcomes(key: pl.DataFrame, panel: pl.DataFrame) -> pl.DataFrame:
    print("\nAttaching firm-year outcomes...", flush=True)

    outcome_cols = [
        "n_employees_3112", "n_vinculos_total", "n_hires_year",
        "n_separations_year", "total_payroll_dez", "avg_wage_dez",
        "med_wage_dez", "share_female", "avg_age", "share_university",
        "avg_tenure_months", "share_managerial",
        "n_hires_from_public", "share_hires_from_public",
    ]
    panel_min = panel.select(["cnpj_raiz", "ano"] + outcome_cols)

    result = key
    # Include t-2 for the event-study identification check; t+3 ditto.
    # Edge years (2009-2010 treat → no t-2 in RAIS; 2014-2015 treat → no t+3
    # except 2014→2017 which is OK) will simply have null outcomes there.
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
    print(f"  sample: {result.height:,} rows × {len(result.columns)} cols")
    return result


def compute_derived(df: pl.DataFrame) -> pl.DataFrame:
    print("\nComputing log outcomes and growth rates...", flush=True)
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

        (pl.col("valorunitárioreferência").clip(lower_bound=0) + 1)
            .log().alias("log_ref_price"),
    ])
    # Year-over-year growth rates — used for event-study identification check.
    # dlog_emp_yoy_t{k} = log_emp at year (treatment + k) MINUS log_emp at year
    # (treatment + k - 1). Under valid local randomization, the pre-treatment
    # YoY rates (k = -1, 0) should be ≈ 0; post-treatment (k = +1, +2, +3)
    # should reveal the dynamic effect.
    df = df.with_columns([
        # Pre-treatment YoY (placebo)
        (pl.col("log_emp_tm1") - pl.col("log_emp_tm2"))
            .alias("dlog_emp_yoy_tm1"),
        # Impact (during contract year)
        (pl.col("log_emp_t0") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_yoy_t0"),
        # Post-treatment dynamic
        (pl.col("log_emp_tp1") - pl.col("log_emp_t0"))
            .alias("dlog_emp_yoy_tp1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tp1"))
            .alias("dlog_emp_yoy_tp2"),
        (pl.col("log_emp_tp3") - pl.col("log_emp_tp2"))
            .alias("dlog_emp_yoy_tp3"),

        # Same for payroll
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

        # Cumulative growth from t-1 baseline (event-study in levels, normalized)
        (pl.col("log_emp_tm2") - pl.col("log_emp_tm1")).alias("dlog_emp_cum_tm2"),
        (pl.col("log_emp_t0")  - pl.col("log_emp_tm1")).alias("dlog_emp_cum_t0"),
        (pl.col("log_emp_tp1") - pl.col("log_emp_tm1")).alias("dlog_emp_cum_tp1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tm1")).alias("dlog_emp_cum_tp2"),
        (pl.col("log_emp_tp3") - pl.col("log_emp_tm1")).alias("dlog_emp_cum_tp3"),

        # Original growth rates (kept for back-compat with script 07 R)
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
    print("  SANITY REPORT (pregão firm-year)")
    print("=" * 70)
    print(f"  Rows (firm-years): {df.height:,}")
    print(f"  Unique firms: {df['cnpj_raiz'].n_unique():,}")
    print(f"  Year range: {df['year'].min()}–{df['year'].max()}")

    print("\n  n_auctions per firm-year (collapsed):")
    print(df["n_auctions_year"].describe())

    print("\n  Coverage of outcomes:")
    for col in ["log_emp_tm1", "log_emp_tp1", "log_emp_tp2",
                "dlog_emp_tp1_tm1", "survived_tp1", "survived_tp2"]:
        if col in df.columns:
            frac = 1 - df[col].null_count() / df.height
            print(f"    {col:20s}: {100*frac:5.1f}%")

    print("\n  Observations within each bandwidth:")
    for h in [0.005, 0.01, 0.02, 0.05]:
        n = df.filter(pl.col("running").abs() < h).height
        n_cov = df.filter(
            (pl.col("running").abs() < h) & pl.col("log_emp_tp1").is_not_null()
        ).height
        print(f"    |r|<{h:.3f}: n={n:>7,}  with log_emp_tp1={n_cov:>7,}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mv-max", type=float, default=MV_MAX_DEFAULT)
    args = parser.parse_args()

    t0 = time.time()
    print("Pregão firm-year RD prep — Paper 4 / Pivot 4 + Pivot 1 robustness")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    key = build_firmyear_key(args.mv_max, TREAT_YEARS_DEFAULT)
    panel = pl.read_parquet(PANEL_PATH)
    print(f"\nPanel: {panel.height:,} firm-years")
    df = attach_outcomes(key, panel)
    df = compute_derived(df)
    sanity_report(df)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    df.write_parquet(OUTPUT, compression="snappy")
    print(f"\n[written] {OUTPUT} ({OUTPUT.stat().st_size/1e6:.1f} MB)")
    print(f"Total time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
