#!/usr/bin/env python3
"""
11_motivo_desligamento.py — Investigate exit mechanisms via separation reasons

Purpose
-------
Test the "rescue" interpretation of the survival results by examining
WHY workers leave firms in the year following a close-bid auction. If
narrow losers exit via financial distress (mass dismissals, codes 10-12),
the rescue story is supported: contracts prevent firms from going under.
If narrow losers exit via voluntary terminations (codes 20-29) or contract
ends (30-39), the story is weaker.

Pipeline
--------
1. Build a firm-year separation breakdown by motivo bucket from the
   harmonized RAIS vinculos files.
2. Merge with the close-bid pregão sample.
3. Compare separation composition between narrow winners and narrow losers.

Motivo buckets (per RAIS layout)
--------------------------------
- dismissal_distressed : codes 10, 11, 12 (involuntary, employer-initiated;
                         includes mass dismissals)
- voluntary            : codes 20-29 (employee-initiated)
- contract_end         : codes 30-39 (term contract ended)
- other                : retirement, death, transfer, mutual agreement

Outputs
-------
  02_data/firms/separation_breakdown.parquet  — firm × year separation buckets
  02_data/intermediate/motivo_desligamento_report.txt
"""
from __future__ import annotations

import gc
import time
from pathlib import Path

import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
VINCULOS_DIR  = BASE / "RAIS" / "parquet" / "harmonized"
PREGAO_SAMPLE = BASE / "02_data" / "final" / "rd_pilot_pregao_sample.parquet"
SEP_OUT       = BASE / "02_data" / "firms" / "separation_breakdown.parquet"
REPORT_OUT    = BASE / "02_data" / "intermediate" / "motivo_desligamento_report.txt"

YEARS = list(range(2010, 2018))  # need t+1 data for treatments 2009-2016


def bucket_motivo(col: pl.Expr) -> pl.Expr:
    """Map raw motivo_desligamento codes to interpretable buckets."""
    return (
        pl.when((col >= 10) & (col <= 12)).then(pl.lit("dismissal_distressed"))
        .when((col >= 20) & (col <= 29)).then(pl.lit("voluntary"))
        .when((col >= 30) & (col <= 39)).then(pl.lit("contract_end"))
        .when(col == 0).then(pl.lit("active"))  # not separated
        .otherwise(pl.lit("other"))
    )


def build_separation_panel(bec_set: set[str]) -> pl.DataFrame:
    print("Building firm-year separation breakdown from harmonized vinculos...",
          flush=True)
    frames = []
    for year in YEARS:
        fpath = VINCULOS_DIR / f"rais_vinculos_{year}.parquet"
        if not fpath.exists():
            continue
        print(f"  [{year}] scanning...", flush=True)
        df = (
            pl.scan_parquet(fpath)
            .filter(pl.col("cnpj_raiz").is_in(bec_set))
            .select([
                "cnpj_raiz",
                pl.col("motivo_desligamento").cast(pl.Int8),
            ])
            .with_columns(bucket_motivo(pl.col("motivo_desligamento"))
                          .alias("motivo_bucket"))
            .group_by(["cnpj_raiz", "motivo_bucket"])
            .agg(pl.len().alias("n"))
            .with_columns(pl.lit(year, dtype=pl.Int16).alias("ano"))
            .collect()
        )
        # Pivot to wide format
        wide = df.pivot(
            values="n",
            index=["cnpj_raiz", "ano"],
            on="motivo_bucket",
            aggregate_function="first",
        ).fill_null(0)

        frames.append(wide)
        print(f"    rows: {wide.height:,}")
        del df, wide
        gc.collect()

    panel = pl.concat(frames, how="diagonal_relaxed").fill_null(0)
    print(f"  Combined panel: {panel.height:,} firm-years")
    return panel


def main() -> None:
    t0 = time.time()
    print("=" * 70)
    print("Motivo desligamento — exit mechanism analysis")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # Step 1: load BEC firm set
    bec = pl.read_parquet(BEC_CNPJ_LIST)
    bec_set = set(
        bec.select(pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8))["cnpj_raiz"]
        .unique().to_list()
    )
    bec_set.discard("00000000")
    print(f"\nBEC supplier set: {len(bec_set):,} unique cnpj_raiz")

    # Step 2: build separation breakdown
    sep = build_separation_panel(bec_set)
    SEP_OUT.parent.mkdir(parents=True, exist_ok=True)
    sep.write_parquet(SEP_OUT, compression="snappy")
    print(f"\n[written] {SEP_OUT}")
    print(f"  shape: {sep.shape}")
    print(f"  cols: {sep.columns}")

    # Step 3: merge with close-bid pregão sample for t+1
    print("\nMerging with pregão sample (looking up t+1)...", flush=True)
    pregao = pl.read_parquet(PREGAO_SAMPLE)
    print(f"  pregão sample: {pregao.height:,} rows")

    # Restrict to a clean close-bid window
    pregao_close = pregao.filter(pl.col("running").abs() < 0.02)
    print(f"  close-bid (|r|<0.02): {pregao_close.height:,} rows")

    # Lookup separations at year t+1
    sep_t1 = sep.with_columns(
        (pl.col("ano") - 1).alias("year")  # bring t+1 separations into row of treatment year t
    ).rename({
        "dismissal_distressed": "n_dismissal_distressed_tp1",
        "voluntary": "n_voluntary_tp1",
        "contract_end": "n_contract_end_tp1",
        "other": "n_other_sep_tp1",
        "active": "n_active_tp1",
    }).drop("ano")

    # Drop conflicting cols if present
    for col in ["n_dismissal_distressed_tp1", "n_voluntary_tp1",
                "n_contract_end_tp1", "n_other_sep_tp1", "n_active_tp1"]:
        if col in pregao_close.columns:
            pregao_close = pregao_close.drop(col)

    merged = pregao_close.join(sep_t1, on=["cnpj_raiz", "year"], how="left")
    print(f"  merged: {merged.height:,} rows")

    # Compute totals and shares
    sep_cols = ["n_dismissal_distressed_tp1", "n_voluntary_tp1",
                "n_contract_end_tp1", "n_other_sep_tp1"]
    for c in sep_cols:
        merged = merged.with_columns(pl.col(c).fill_null(0))
    merged = merged.with_columns(
        sum(pl.col(c) for c in sep_cols).alias("total_seps_tp1")
    )

    # Coverage
    has_data = merged.filter(pl.col("total_seps_tp1") > 0)
    print(f"  rows with separation data: {has_data.height:,} "
          f"({100*has_data.height/merged.height:.1f}%)")

    # Step 4: compute means by treat
    print("\n" + "=" * 70)
    print("  COMPARISON: narrow winners vs narrow losers (|r| < 0.02)")
    print("=" * 70)

    by_treat = (
        merged.group_by("treat")
        .agg([
            pl.len().alias("n_firms"),
            pl.col("n_dismissal_distressed_tp1").mean().alias("mean_distressed"),
            pl.col("n_voluntary_tp1").mean().alias("mean_voluntary"),
            pl.col("n_contract_end_tp1").mean().alias("mean_contract_end"),
            pl.col("n_other_sep_tp1").mean().alias("mean_other"),
            pl.col("total_seps_tp1").mean().alias("mean_total"),
            (pl.col("n_dismissal_distressed_tp1") /
             pl.col("total_seps_tp1").clip(lower_bound=1))
                .mean().alias("share_distressed"),
            (pl.col("n_voluntary_tp1") /
             pl.col("total_seps_tp1").clip(lower_bound=1))
                .mean().alias("share_voluntary"),
        ])
        .sort("treat")
    )
    print()
    print(by_treat)

    # Even better: among firms with ANY separation, what's the split?
    has_seps = merged.filter(pl.col("total_seps_tp1") > 0)
    by_treat_cond = (
        has_seps.group_by("treat")
        .agg([
            pl.len().alias("n_firms"),
            (pl.col("n_dismissal_distressed_tp1") /
             pl.col("total_seps_tp1")).mean().alias("share_distressed"),
            (pl.col("n_voluntary_tp1") /
             pl.col("total_seps_tp1")).mean().alias("share_voluntary"),
            (pl.col("n_contract_end_tp1") /
             pl.col("total_seps_tp1")).mean().alias("share_contract_end"),
            pl.col("total_seps_tp1").mean().alias("mean_total"),
        ])
        .sort("treat")
    )
    print("\n  Among firms with at least one separation in t+1:")
    print(by_treat_cond)

    # Headcount-normalized: separations relative to firm size
    # using n_employees_3112_t0 as baseline
    if "n_employees_3112_t0" in merged.columns:
        norm = merged.filter(pl.col("n_employees_3112_t0") > 0)
        by_treat_norm = (
            norm.group_by("treat")
            .agg([
                pl.len().alias("n_firms"),
                (pl.col("n_dismissal_distressed_tp1") /
                 pl.col("n_employees_3112_t0")).mean()
                    .alias("rate_distressed_per_emp"),
                (pl.col("n_voluntary_tp1") /
                 pl.col("n_employees_3112_t0")).mean()
                    .alias("rate_voluntary_per_emp"),
                (pl.col("total_seps_tp1") /
                 pl.col("n_employees_3112_t0")).mean()
                    .alias("rate_total_per_emp"),
            ])
            .sort("treat")
        )
        print("\n  Rates per employee at t (separation intensity):")
        print(by_treat_norm)

    # Persist
    REPORT_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(REPORT_OUT, "w") as f:
        f.write(f"Motivo desligamento report — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Pregão close-bid sample (|r|<0.02): {merged.height:,} rows\n")
        f.write(f"With separation data: {has_data.height:,}\n\n")
        f.write("By treat (winner=1, loser=0):\n\n")
        f.write(str(by_treat) + "\n\n")
        f.write("Conditional on having any separation:\n\n")
        f.write(str(by_treat_cond) + "\n\n")
        if "n_employees_3112_t0" in merged.columns:
            f.write("Rates per employee at t:\n\n")
            f.write(str(by_treat_norm) + "\n\n")
    print(f"\n[written] {REPORT_OUT}")

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
