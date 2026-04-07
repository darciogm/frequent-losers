#!/usr/bin/env python3
"""
02_build_revolving_door.py — Revolving-door flags for Paper 4 / Caminho 4

Purpose
-------
For each worker hired by a BEC supplier, determine whether that worker had
any prior formal employment in the Brazilian PUBLIC SECTOR (natureza_juridica
codes 1000-1999). This produces the micro-level evidence base for the
revolving-door subsection of the paper.

Pipeline
--------
For each year t ∈ {2010, …, 2017}:
  1. Load `new_hires_{t}.parquet` (output of 01_build_firm_year_panel.py)
     → set S_t of (pis, cnpj_raiz, year_hired, ...).
  2. Scan RAIS vinculos for years [2009, t-1] filtered to pis ∈ S_t:
     collect (pis, ano_prior, natureza_juridica_prior, cnpj_raiz_prior).
  3. For each worker in S_t, compute:
       - `ever_public_before`    : any prior vínculo with NJ in [1000, 1999]
       - `last_nj_before`        : NJ of most recent prior vínculo
       - `years_since_last_public`: t - max(ano_prior with public NJ)
       - `prior_in_same_firm`    : had any prior vínculo in the destination
                                   BEC firm (→ internal mobility, not RD)
  4. Merge flags back to the hires table and write
     `02_data/firms/hires_with_prior_flags_{year}.parquet`.
  5. Aggregate to firm-year:
       - `n_hires_from_public`
       - `share_hires_from_public`
       - `n_hires_from_public_mgr` (subset where is_managerial == 1)
     Append to firm_year_panel.parquet.

Caveats
-------
- RAIS harmonized coverage is 2009–2017, so revolving-door is left-censored:
  for hires in 2009 we cannot observe any prior; for hires in 2010 we observe
  only one prior year; coverage improves with t. The analysis should either
  restrict to t ≥ 2012 (three years of back-history) or explicitly discuss
  censoring.
- The destination is the BEC firm (cnpj_raiz ∈ BEC set); the ORIGIN
  (prior establishment) can be any firm in RAIS — public or private. Thus
  this script must scan UNFILTERED RAIS, not the BEC-filtered slice.
- Memory: per-year scans of full RAIS vinculos, filtered by pis ∈ S_t, are
  the memory peak. Each year's RAIS vinculos is ~40-60M rows but after pis
  filtering drops to ~few hundred thousand per (t, t-k) pair.

Usage
-----
  python3 03_analysis/02_build_revolving_door.py
  python3 03_analysis/02_build_revolving_door.py --year 2015
  python3 03_analysis/02_build_revolving_door.py --no-update-panel
"""
from __future__ import annotations

import argparse
import gc
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
# Paths and constants
# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

VINCULOS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
HIRES_DIR    = BASE / "02_data" / "firms" / "new_hires"
PANEL_PATH   = BASE / "02_data" / "firms" / "firm_year_panel.parquet"

OUT_DIR      = BASE / "02_data" / "firms"
OUT_RD_DIR   = OUT_DIR / "revolving_door"

TREAT_YEARS = list(range(2010, 2018))  # can't do 2009: no prior RAIS coverage
RAIS_MIN_YEAR = 2009                   # earliest harmonized vinculos year

PUBLIC_NJ_MIN = 1000
PUBLIC_NJ_MAX = 1999


# ─────────────────────────────────────────────────────────────────────
# Core: for one treatment year, compute prior flags
# ─────────────────────────────────────────────────────────────────────
def process_year(year_hired: int) -> pl.DataFrame:
    """For hires in `year_hired`, scan prior RAIS years and flag
    revolving-door origins."""
    hires_path = HIRES_DIR / f"new_hires_{year_hired}.parquet"
    if not hires_path.exists():
        print(f"  [SKIP] {year_hired}: new_hires file not found")
        return pl.DataFrame()

    print(f"\n[{year_hired}] Loading hires...", flush=True)
    hires = pl.read_parquet(hires_path)
    n_hires = hires.height
    pis_set_size = hires["pis"].n_unique()
    print(f"  {n_hires:,} hires at BEC firms, {pis_set_size:,} unique PIS")

    # Build the set of PIS we need prior info for
    pis_set = hires["pis"].unique()

    # Scan prior RAIS years for any vínculo of these workers
    prior_years = list(range(RAIS_MIN_YEAR, year_hired))
    if not prior_years:
        print(f"  No prior RAIS coverage for {year_hired} → all flags null")
        flags = hires.with_columns([
            pl.lit(None, dtype=pl.Int8).alias("ever_public_before"),
            pl.lit(None, dtype=pl.Int16).alias("last_nj_before"),
            pl.lit(None, dtype=pl.Int16).alias("years_since_last_public"),
            pl.lit(None, dtype=pl.Int8).alias("prior_in_same_firm"),
            pl.lit(None, dtype=pl.Int8).alias("any_prior_vinc"),
        ])
        return flags

    print(f"  Scanning prior years {prior_years[0]}–{prior_years[-1]}...", flush=True)

    prior_frames = []
    pis_df = pl.DataFrame({"pis": pis_set})
    for py in prior_years:
        pf = VINCULOS_DIR / f"rais_vinculos_{py}.parquet"
        if not pf.exists():
            continue
        # Use semi-join to filter by pis set via a join on lazy scan
        scan = (
            pl.scan_parquet(pf)
            .select([
                "pis",
                pl.lit(py, dtype=pl.Int16).alias("ano_prior"),
                pl.col("natureza_juridica").alias("nj_prior"),
                pl.col("cnpj_raiz").alias("cnpj_raiz_prior"),
            ])
            .join(pis_df.lazy(), on="pis", how="inner")
            .collect()
        )
        prior_frames.append(scan)
        print(f"    {py}: {scan.height:,} prior vínculos matched", flush=True)
        gc.collect()

    if not prior_frames:
        print("  No prior vínculos found — all flags null")
        return hires.with_columns([
            pl.lit(0, dtype=pl.Int8).alias("ever_public_before"),
            pl.lit(None, dtype=pl.Int16).alias("last_nj_before"),
            pl.lit(None, dtype=pl.Int16).alias("years_since_last_public"),
            pl.lit(0, dtype=pl.Int8).alias("prior_in_same_firm"),
            pl.lit(0, dtype=pl.Int8).alias("any_prior_vinc"),
        ])

    prior = pl.concat(prior_frames, how="diagonal_relaxed")
    del prior_frames
    gc.collect()
    print(f"  Total prior vínculos collected: {prior.height:,}")

    prior = prior.with_columns([
        ((pl.col("nj_prior") >= PUBLIC_NJ_MIN) &
         (pl.col("nj_prior") <= PUBLIC_NJ_MAX))
            .cast(pl.Int8)
            .alias("is_public_prior"),
    ])

    # Aggregate per PIS: did they ever have a public-sector vínculo before?
    per_pis = (
        prior.group_by("pis")
        .agg([
            pl.col("is_public_prior").max().alias("ever_public_before"),
            # Most recent prior year overall (not just public)
            pl.col("ano_prior").max().alias("last_year_any_prior"),
            pl.lit(1, dtype=pl.Int8).alias("any_prior_vinc"),
        ])
    )

    # Years-since-last-public: latest year with public NJ
    last_public = (
        prior.filter(pl.col("is_public_prior") == 1)
        .group_by("pis")
        .agg(pl.col("ano_prior").max().alias("last_year_public"))
    )

    # NJ of most recent prior vínculo (any type) — for descriptives
    last_nj = (
        prior.sort(["pis", "ano_prior"], descending=[False, True])
        .group_by("pis", maintain_order=True)
        .agg(pl.col("nj_prior").first().alias("last_nj_before"))
    )

    per_pis = (
        per_pis
        .join(last_public, on="pis", how="left")
        .join(last_nj, on="pis", how="left")
        .with_columns([
            (year_hired - pl.col("last_year_public")).cast(pl.Int16)
                .alias("years_since_last_public"),
        ])
        .drop(["last_year_any_prior", "last_year_public"])
    )

    # Prior in same firm? — worker had a vínculo in the destination BEC firm
    # before year_hired (internal mobility, not external revolving door)
    same_firm = (
        hires.select(["pis", "cnpj_raiz"])
        .join(prior.select(["pis", "cnpj_raiz_prior"]).unique(),
              left_on=["pis", "cnpj_raiz"],
              right_on=["pis", "cnpj_raiz_prior"],
              how="inner")
        .select("pis")
        .unique()
        .with_columns(pl.lit(1, dtype=pl.Int8).alias("prior_in_same_firm"))
    )

    # Merge back to hires
    flags = (
        hires
        .join(per_pis, on="pis", how="left")
        .join(same_firm, on="pis", how="left")
        .with_columns([
            pl.col("ever_public_before").fill_null(0),
            pl.col("any_prior_vinc").fill_null(0),
            pl.col("prior_in_same_firm").fill_null(0),
        ])
    )

    n_public = flags["ever_public_before"].sum()
    n_any = flags["any_prior_vinc"].sum()
    print(f"  Results: {n_any:,} workers with any prior vínculo "
          f"({100*n_any/n_hires:.1f}%)")
    print(f"           {n_public:,} with prior PUBLIC-sector vínculo "
          f"({100*n_public/n_hires:.2f}% of all hires, "
          f"{100*n_public/max(n_any,1):.2f}% of workers with prior history)")

    return flags


# ─────────────────────────────────────────────────────────────────────
# Aggregate hire-level flags to firm-year, merge into the main panel
# ─────────────────────────────────────────────────────────────────────
def update_firm_year_panel(all_flags: pl.DataFrame) -> None:
    print("\nAggregating flags to firm × year...", flush=True)

    firm_year_rd = (
        all_flags.group_by(["cnpj_raiz", "year_hired"])
        .agg([
            pl.len().alias("n_hires_rd_window"),
            pl.col("ever_public_before").sum().alias("n_hires_from_public"),
            (pl.col("ever_public_before") * pl.col("is_managerial"))
                .sum()
                .alias("n_hires_from_public_mgr"),
            pl.col("any_prior_vinc").sum().alias("n_hires_with_prior_history"),
            pl.col("prior_in_same_firm").sum().alias("n_hires_internal"),
        ])
        .with_columns([
            (pl.col("n_hires_from_public") / pl.col("n_hires_rd_window"))
                .alias("share_hires_from_public"),
        ])
        .rename({"year_hired": "ano"})
    )

    print(f"  Firm-year-RD aggregation: {firm_year_rd.height:,} rows")

    # Merge into existing panel
    if not PANEL_PATH.exists():
        print(f"  [WARN] {PANEL_PATH} not found — skipping merge")
        return

    panel = pl.read_parquet(PANEL_PATH)
    print(f"  Existing panel: {panel.height:,} firm-years, "
          f"{len(panel.columns)} cols")

    # Drop any previous RD columns to make the merge idempotent
    rd_cols = [
        "n_hires_rd_window", "n_hires_from_public", "n_hires_from_public_mgr",
        "n_hires_with_prior_history", "n_hires_internal",
        "share_hires_from_public",
    ]
    panel = panel.drop([c for c in rd_cols if c in panel.columns])

    merged = panel.join(firm_year_rd, on=["cnpj_raiz", "ano"], how="left")
    merged.write_parquet(PANEL_PATH, compression="snappy")
    print(f"  Updated panel: {merged.height:,} rows, "
          f"{len(merged.columns)} cols")
    print(f"  Written: {PANEL_PATH}")

    # Brief sanity summary
    total_public_hires = merged["n_hires_from_public"].sum()
    total_hires = merged["n_hires_rd_window"].sum()
    if total_hires is not None and total_hires > 0:
        overall = 100 * total_public_hires / total_hires
        print(f"  Overall: {total_public_hires:,} / {total_hires:,} hires "
              f"from public sector ({overall:.2f}%)")


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, default=None)
    parser.add_argument("--no-update-panel", action="store_true")
    args = parser.parse_args()

    t0 = time.time()
    print("Revolving-door flags build — Paper 4 / Caminho 4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    OUT_RD_DIR.mkdir(parents=True, exist_ok=True)

    years_to_run = [args.year] if args.year else TREAT_YEARS

    all_flags = []
    for y in years_to_run:
        flags = process_year(y)
        if flags.is_empty():
            continue
        out = OUT_RD_DIR / f"hires_with_prior_flags_{y}.parquet"
        flags.write_parquet(out, compression="snappy")
        print(f"  [written] {out.name}")
        all_flags.append(flags)

    if not all_flags:
        print("No flags produced. Exiting.")
        return

    combined = pl.concat(all_flags, how="diagonal_relaxed")
    print(f"\nCombined flags: {combined.height:,} rows")

    if not args.no_update_panel:
        update_firm_year_panel(combined)

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
