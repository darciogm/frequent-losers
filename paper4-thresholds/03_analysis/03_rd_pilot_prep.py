#!/usr/bin/env python3
"""
03_rd_pilot_prep.py — Build RD analysis sample for Paper 4 / Caminho 1 pilot

Purpose
-------
Join the BEC convite winner-loser pair file with the firm-year panel (RAIS
outcomes) to produce a single analysis file that the R-based rdrobust script
consumes. This is the gate-check #2 data preparation: if the pilot RD works,
the Caminho 1 design is validated.

Treatment window
----------------
t ∈ {2009, …, 2015} (7 years). Constraint: RAIS coverage ends at 2017, so
treatment in t ≤ 2015 allows outcomes at t+2 within coverage.

Unit of observation
-------------------
(cnpj_raiz, auction_item) — one row per firm per close-bid auction in which
that firm participated as winner OR runner-up. The BEC source already filters
to winner-loser pairs (2 rows per auction).

Outcomes
--------
For k ∈ {-1, 0, 1, 2}, we look up firm_year_panel at year = t + k and bring:
  n_employees_3112, n_vinculos_total, n_hires_year, total_payroll_dez,
  avg_wage_dez, share_female, avg_escolaridade, survived, etc.

We also construct log-outcomes via log(1+x) to handle zeros.

Filter
------
Keep only observations with |MV| < 0.10 (safety envelope; rdrobust picks the
optimal bandwidth within this). This is 10× the baseline bandwidth we care
about (|MV| < 0.01).

Output
------
  02_data/final/rd_pilot_sample.parquet   (one row per firm × auction)

Usage
-----
  python3 03_analysis/03_rd_pilot_prep.py
  python3 03_analysis/03_rd_pilot_prep.py --mv-max 0.05
  python3 03_analysis/03_rd_pilot_prep.py --years 2010 2015

Notes
-----
- We restrict to auctions in treatment years but the firm-year lookups use
  the panel for all years (including t-1 for balance and t+1/t+2 for
  outcomes).
- log outcomes: log1p(x) = log(1+x), which handles zero employment.
- Cluster variable (for SEs) is auction_item (not auction_num, since
  auction_num may not be unique across batches).
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
# Paths and constants
# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

BEC_ANALYSIS  = BASE / "02_data" / "final" / "df_convite_winner_looser.parquet"
FIRM_PANEL    = BASE / "02_data" / "firms" / "firm_year_panel.parquet"
OUTPUT        = BASE / "02_data" / "final" / "rd_pilot_sample.parquet"

# Treatment window — constrained by RAIS coverage ending 2017
TREAT_YEARS_DEFAULT = list(range(2009, 2016))  # 2009–2015 inclusive

# Safety envelope around the cutoff (rdrobust chooses the actual bandwidth)
MV_MAX_DEFAULT = 0.10


# ─────────────────────────────────────────────────────────────────────
# Step 1: Prepare BEC pair file
# ─────────────────────────────────────────────────────────────────────
def load_bec(mv_max: float, treat_years: list[int]) -> pl.DataFrame:
    print(f"Loading BEC pairs, |MV| < {mv_max}, years {treat_years[0]}–{treat_years[-1]}...",
          flush=True)

    bec = (
        pl.scan_parquet(BEC_ANALYSIS)
        .select([
            "auction_item",
            "auction_num",
            pl.col("year").cast(pl.Int32).alias("year"),
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
            pl.col("firm").cast(pl.Int32).alias("firm_id"),
            pl.col("flagvencedor").cast(pl.Int8).alias("won"),
            pl.col("MV").cast(pl.Float64).alias("mv"),
            pl.col("bid_diff").cast(pl.Float64).alias("bid_diff"),
            pl.col("valorunitárioproposta").cast(pl.Float64).alias("bid"),
            pl.col("min_bid").cast(pl.Float64).alias("min_bid"),
            pl.col("max_bid").cast(pl.Float64).alias("max_bid"),
            pl.col("descclasseitem").alias("item_class_desc"),
            pl.col("códigoclasse").cast(pl.Int16).alias("item_class"),
            pl.col("códigogrupo").cast(pl.Int8).alias("item_group"),
            pl.col("códigounidadecompradora").alias("pbu_code"),
            # Kawai-style outcomes (used later as validation/balance):
            pl.col("won_previous_market").cast(pl.Float64).alias("was_incumbent"),
            pl.col("last").cast(pl.Float64).alias("was_last_bid"),
        ])
        .filter(pl.col("mv").abs() < mv_max)
        .filter(pl.col("year").is_in(treat_years))
        .with_columns([
            pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"),
            # Sign of MV: winner has mv<0, loser has mv>0 (from source).
            # For rdrobust we use the LOSING-side convention so cutoff=0
            # means "barely lost"; coefficient sign: RHS → treat=1 (won).
            (pl.col("won") == 1).cast(pl.Int8).alias("treat"),
            # Running variable: signed distance from cutoff, positive means "won"
            # Kawai uses margin of victory where negative = won; flip sign here
            # so that higher running variable → closer to winning, standard RD.
            (-pl.col("mv")).alias("running"),
        ])
        .collect()
    )

    print(f"  Filtered BEC pairs: {bec.height:,}")
    print(f"  Unique firms: {bec['cnpj_raiz'].n_unique():,}")
    print(f"  Unique auctions: {bec['auction_item'].n_unique():,}")
    print(f"  Treat (won): {bec['treat'].sum():,} "
          f"({100*bec['treat'].mean():.1f}%)")
    return bec


# ─────────────────────────────────────────────────────────────────────
# Step 2: Attach firm-year outcomes at offsets t+k
# ─────────────────────────────────────────────────────────────────────
def attach_outcomes(bec: pl.DataFrame, panel: pl.DataFrame) -> pl.DataFrame:
    """For each (cnpj_raiz, year) row in bec, look up firm_year_panel at
    year + k for k ∈ {-1, 0, 1, 2}. Columns are renamed with `_tk` suffix."""
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
        # Survival flag: firm present in panel at t+k
        result = result.with_columns(
            pl.col(f"n_employees_3112{suffix}").is_not_null()
                .cast(pl.Int8)
                .alias(f"survived{suffix}")
        )
        print(f"  t{'+' if k>=0 else ''}{k}: joined")

    print(f"  Analysis sample: {result.height:,} rows, {len(result.columns)} cols")
    return result


# ─────────────────────────────────────────────────────────────────────
# Step 3: Compute log outcomes and growth rates
# ─────────────────────────────────────────────────────────────────────
def compute_derived(df: pl.DataFrame) -> pl.DataFrame:
    print("\nComputing log outcomes and growth rates...", flush=True)

    df = df.with_columns([
        # log(1 + employment) and log(1 + payroll)
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
    ])

    # First-difference in log employment (growth rate)
    df = df.with_columns([
        (pl.col("log_emp_tp1") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp1_tm1"),
        (pl.col("log_emp_tp2") - pl.col("log_emp_tm1"))
            .alias("dlog_emp_tp2_tm1"),
    ])

    return df


# ─────────────────────────────────────────────────────────────────────
# Step 4: Sanity report
# ─────────────────────────────────────────────────────────────────────
def sanity_report(df: pl.DataFrame) -> None:
    print("\n" + "=" * 70)
    print("  SANITY REPORT")
    print("=" * 70)

    print(f"  Total rows: {df.height:,}")
    print(f"  Unique firms: {df['cnpj_raiz'].n_unique():,}")
    print(f"  Unique auctions: {df['auction_item'].n_unique():,}")

    # Coverage of pre/post outcomes
    print("\n  Coverage of outcomes (fraction non-null):")
    for col in ["log_emp_tm1", "log_emp_t0", "log_emp_tp1", "log_emp_tp2",
                "log_payroll_tp1", "survived_tp1", "survived_tp2"]:
        if col in df.columns:
            frac = 1 - df[col].null_count() / df.height
            print(f"    {col:20s}: {100*frac:5.1f}%")

    # Running variable summary
    print("\n  Running variable (flipped MV, + = closer to winning):")
    print(df["running"].describe())

    # By MV band
    print("\n  Observations within each bandwidth (on `running`):")
    for h in [0.005, 0.01, 0.02, 0.05]:
        n = df.filter(pl.col("running").abs() < h).height
        n_cov = df.filter(
            (pl.col("running").abs() < h) & pl.col("log_emp_tp1").is_not_null()
        ).height
        print(f"    |r| < {h:.3f}: n={n:>8,}  with log_emp_tp1={n_cov:>8,}")


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mv-max", type=float, default=MV_MAX_DEFAULT)
    parser.add_argument("--years", nargs=2, type=int, default=None,
                        metavar=("START", "END"))
    args = parser.parse_args()

    if args.years:
        treat_years = list(range(args.years[0], args.years[1] + 1))
    else:
        treat_years = TREAT_YEARS_DEFAULT

    t0 = time.time()
    print("RD pilot sample prep — Paper 4 / Caminho 1")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    bec = load_bec(args.mv_max, treat_years)

    print("\nLoading firm-year panel...", flush=True)
    panel = pl.read_parquet(FIRM_PANEL)
    print(f"  Panel: {panel.height:,} firm-years, {len(panel.columns)} cols")

    df = attach_outcomes(bec, panel)
    df = compute_derived(df)
    sanity_report(df)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    df.write_parquet(OUTPUT, compression="snappy")
    size_mb = OUTPUT.stat().st_size / 1e6
    print(f"\n[written] {OUTPUT} ({size_mb:.1f} MB)")

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
