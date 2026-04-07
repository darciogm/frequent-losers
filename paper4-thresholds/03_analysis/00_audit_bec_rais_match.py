#!/usr/bin/env python3
"""
00_audit_bec_rais_match.py — Gate check for Paper 4 (pivot: Real Effects of Narrow Wins)

Purpose
-------
Diagnose the quality of the BEC-SP × RAIS linkage BEFORE committing to the
close-bid RD design on firm/worker outcomes. If the match rate on the analysis
sample (close-bid convite auctions) is too low, the paper cannot proceed as
planned and the design must be reconsidered.

Inputs
------
  02_data/bec_cnpj_list.parquet            # BEC supplier universe (full CNPJ + raiz)
  02_data/final/df_convite_winner_looser.parquet  # BEC analysis sample
  02_data/rais_bec_linked.parquet          # RAIS firm-year panel (post-linkage)

Outputs
-------
  02_data/intermediate/audit_match_report.txt         # human-readable diagnostic
  02_data/intermediate/audit_match_firm_diagnostics.parquet  # per-firm match diagnostics
  02_data/intermediate/audit_match_by_year.parquet    # year-level match rates

Usage
-----
  python3 03_analysis/00_audit_bec_rais_match.py

Notes
-----
This script does NOT modify the linkage. It audits the existing output of
linkage_rais_bec.py. To regenerate the linkage, run that script instead.

Expected diagnostics reported:
  1. Universe sizes (BEC firms, BEC analysis-sample firms, RAIS-matched firms)
  2. Match rate (unweighted and bid-weighted)
  3. Match rate on the close-bid RD subsample (|MV| < {0.01, 0.02, 0.05})
  4. Year-level coverage (critical: RAIS stops at 2017; BEC runs to 2019)
  5. Trajectory completeness histogram (n RAIS years per firm)
  6. Unmatched-firm profile (possible "ghost firms")
  7. Sector / size distribution of matched vs. unmatched
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
BEC_ANALYSIS  = BASE / "02_data" / "final" / "df_convite_winner_looser.parquet"
RAIS_LINKED   = BASE / "02_data" / "rais_bec_linked.parquet"

OUT_DIR       = BASE / "02_data" / "intermediate"
OUT_REPORT    = OUT_DIR / "audit_match_report.txt"
OUT_FIRM      = OUT_DIR / "audit_match_firm_diagnostics.parquet"
OUT_BY_YEAR   = OUT_DIR / "audit_match_by_year.parquet"

# Close-bid thresholds to test the RD analysis sample at
MV_BANDWIDTHS = [0.01, 0.02, 0.05]

# ─────────────────────────────────────────────────────────────────────
# Report buffer — we collect lines and flush at the end
# ─────────────────────────────────────────────────────────────────────
_BUFFER: list[str] = []

def log(msg: str = "") -> None:
    print(msg, flush=True)
    _BUFFER.append(msg)

def header(title: str) -> None:
    bar = "═" * 70
    log(f"\n{bar}\n  {title}\n{bar}")

def flush_report() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_REPORT.write_text("\n".join(_BUFFER) + "\n")
    print(f"\n[written] {OUT_REPORT}")


# ─────────────────────────────────────────────────────────────────────
# Step 1 — Load universes
# ─────────────────────────────────────────────────────────────────────
def load_universes() -> tuple[pl.DataFrame, pl.LazyFrame, pl.DataFrame]:
    header("STEP 1 — Loading universes")

    bec_list = pl.read_parquet(BEC_CNPJ_LIST).with_columns(
        pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8)
    )
    log(f"  bec_cnpj_list.parquet: {bec_list.height:,} rows "
        f"(unique full CNPJ, unique raiz={bec_list['cnpj_raiz'].n_unique():,})")

    bec_lazy = pl.scan_parquet(BEC_ANALYSIS)
    log(f"  df_convite_winner_looser.parquet: lazy scan")

    rais = pl.read_parquet(RAIS_LINKED)
    rais = rais.filter(pl.col("cnpj_raiz") != "00000000")  # drop junk bucket
    log(f"  rais_bec_linked.parquet: {rais.height:,} firm-years "
        f"(unique raiz={rais['cnpj_raiz'].n_unique():,}, "
        f"years={rais['ano'].min()}–{rais['ano'].max()})")

    return bec_list, bec_lazy, rais


# ─────────────────────────────────────────────────────────────────────
# Step 2 — Extract BEC analysis-sample firms and their bid footprint
# ─────────────────────────────────────────────────────────────────────
def build_bec_firm_footprint(bec_lazy: pl.LazyFrame) -> pl.DataFrame:
    header("STEP 2 — BEC analysis-sample firm footprint")

    fp = (
        bec_lazy
        .select([
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).alias("cnpj_full"),
            pl.col("year").cast(pl.Int32).alias("year"),
            pl.col("flagvencedor").cast(pl.Int8).alias("won"),
            pl.col("MV").cast(pl.Float64).alias("mv"),
        ])
        .with_columns(pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"))
        .group_by("cnpj_raiz")
        .agg([
            pl.len().alias("n_bids"),
            pl.col("won").sum().alias("n_wins"),
            pl.col("year").min().alias("first_year_bec"),
            pl.col("year").max().alias("last_year_bec"),
            pl.col("year").n_unique().alias("n_years_bec"),
            # Close-bid counts: how many of this firm's bids fall inside each bandwidth
            *[
                (pl.col("mv").abs() < h).sum().alias(f"n_bids_mv_lt_{int(h*1000):03d}")
                for h in MV_BANDWIDTHS
            ],
        ])
        .collect()
    )

    log(f"  Unique firms in analysis sample: {fp.height:,}")
    log(f"  Total bids: {fp['n_bids'].sum():,}")
    log(f"  Total wins: {fp['n_wins'].sum():,}")
    log(f"  Firms active in all 11 years (2009–2019): "
        f"{fp.filter(pl.col('n_years_bec') == 11).height:,}")
    log(f"  Firms active in only 1 year: "
        f"{fp.filter(pl.col('n_years_bec') == 1).height:,}")

    return fp


# ─────────────────────────────────────────────────────────────────────
# Step 3 — Build firm-level RAIS coverage summary
# ─────────────────────────────────────────────────────────────────────
def build_rais_coverage(rais: pl.DataFrame) -> pl.DataFrame:
    header("STEP 3 — RAIS coverage per firm")

    cov = (
        rais.group_by("cnpj_raiz")
        .agg([
            pl.col("ano").n_unique().alias("n_years_rais"),
            pl.col("ano").min().alias("first_year_rais"),
            pl.col("ano").max().alias("last_year_rais"),
            pl.col("firm_n_employees").mean().alias("avg_employees"),
            pl.col("firm_n_employees").max().alias("max_employees"),
            pl.col("firm_cnae20").mode().first().alias("modal_cnae20"),
            pl.col("total_wage_bill").mean().alias("avg_wage_bill"),
            pl.col("firm_size_class").max().alias("max_size_class"),
        ])
    )

    log(f"  Unique firms with any RAIS coverage: {cov.height:,}")
    log(f"  Avg years of RAIS coverage per firm: "
        f"{cov['n_years_rais'].mean():.2f} / 9 possible")
    log(f"  Firms with full 9-year RAIS trajectory (2009–2017): "
        f"{cov.filter(pl.col('n_years_rais') == 9).height:,}")

    return cov


# ─────────────────────────────────────────────────────────────────────
# Step 4 — Merge and compute match diagnostics
# ─────────────────────────────────────────────────────────────────────
def compute_match(fp: pl.DataFrame, cov: pl.DataFrame) -> pl.DataFrame:
    header("STEP 4 — Match: BEC firms × RAIS coverage")

    merged = fp.join(cov, on="cnpj_raiz", how="left").with_columns(
        pl.col("n_years_rais").is_not_null().alias("matched_rais")
    )

    n_total = merged.height
    n_matched = merged["matched_rais"].sum()
    rate = 100 * n_matched / n_total

    log(f"  Firms in BEC analysis sample:                {n_total:,}")
    log(f"  Firms matched to RAIS (any year):            {n_matched:,}")
    log(f"  Unweighted match rate:                       {rate:.1f}%")

    # Bid-weighted match rate — the critical number for policy-relevance
    total_bids = merged["n_bids"].sum()
    matched_bids = merged.filter(pl.col("matched_rais"))["n_bids"].sum()
    log(f"  Total bids in analysis sample:               {total_bids:,}")
    log(f"  Bids from matched firms:                     {matched_bids:,}")
    log(f"  Bid-weighted match rate:                     "
        f"{100 * matched_bids / total_bids:.1f}%")

    # Close-bid subsample (the actual RD sample)
    log("")
    log("  Match rate in the close-bid RD subsample:")
    log(f"    {'bandwidth':>12} {'total_bids':>12} {'matched_bids':>14} "
        f"{'rate_%':>10}")
    for h in MV_BANDWIDTHS:
        col = f"n_bids_mv_lt_{int(h*1000):03d}"
        tot_cb = merged[col].sum()
        matched_cb = merged.filter(pl.col("matched_rais"))[col].sum()
        rate_cb = 100 * matched_cb / tot_cb if tot_cb > 0 else float("nan")
        log(f"    |MV|<{h:<7.3f} {tot_cb:>12,} {matched_cb:>14,} {rate_cb:>9.1f}%")

    return merged


# ─────────────────────────────────────────────────────────────────────
# Step 5 — Year-by-year coverage (critical: RAIS ends at 2017)
# ─────────────────────────────────────────────────────────────────────
def year_level_coverage(
    bec_lazy: pl.LazyFrame, rais: pl.DataFrame
) -> pl.DataFrame:
    header("STEP 5 — Year-level coverage")

    bec_year = (
        bec_lazy
        .select([
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).str.slice(0, 8).alias("cnpj_raiz"),
            pl.col("year").cast(pl.Int32),
        ])
        .group_by("year")
        .agg([
            pl.col("cnpj_raiz").n_unique().alias("n_firms_bec"),
            pl.len().alias("n_bids_bec"),
        ])
        .collect()
        .rename({"year": "ano"})
    )

    rais_year = (
        rais.group_by("ano")
        .agg(pl.col("cnpj_raiz").n_unique().alias("n_firms_rais"))
        .with_columns(pl.col("ano").cast(pl.Int32))
    )

    # Firms that appear in BOTH BEC bids AND RAIS in the same year
    bec_year_firm = (
        bec_lazy
        .select([
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14).str.slice(0, 8).alias("cnpj_raiz"),
            pl.col("year").cast(pl.Int32).alias("ano"),
        ])
        .unique()
        .collect()
    )
    rais_year_firm = rais.select(["cnpj_raiz", pl.col("ano").cast(pl.Int32)]).unique()
    joint = bec_year_firm.join(rais_year_firm, on=["cnpj_raiz", "ano"], how="inner")
    joint_year = (
        joint.group_by("ano").agg(pl.col("cnpj_raiz").n_unique().alias("n_firms_matched"))
    )

    by_year = (
        bec_year
        .join(rais_year, on="ano", how="left")
        .join(joint_year, on="ano", how="left")
        .with_columns([
            pl.col("n_firms_rais").fill_null(0),
            pl.col("n_firms_matched").fill_null(0),
            (100 * pl.col("n_firms_matched") / pl.col("n_firms_bec"))
                .alias("match_rate_year_pct"),
        ])
        .sort("ano")
    )

    log(f"  {'year':>6} {'bec_firms':>12} {'rais_firms':>12} "
        f"{'matched':>10} {'rate_%':>10}")
    for row in by_year.iter_rows(named=True):
        rate = row["match_rate_year_pct"]
        rate_str = f"{rate:>9.1f}%" if rate is not None else f"{'n/a':>10}"
        log(
            f"  {row['ano']:>6} {row['n_firms_bec']:>12,} "
            f"{row['n_firms_rais']:>12,} {row['n_firms_matched']:>10,} "
            f"{rate_str}"
        )

    log("")
    log("  ⚠  CRITICAL: RAIS coverage in linked file ends at 2017.")
    log("     BEC analysis extends to 2019 → 2 years of post-treatment outcomes")
    log("     are unavailable for contracts signed in 2016+. Options:")
    log("       (a) re-run linkage extending YEARS through 2019;")
    log("       (b) restrict treatment years to {2009, …, 2015} for t+2 outcomes.")

    return by_year


# ─────────────────────────────────────────────────────────────────────
# Step 6 — Trajectory completeness histogram
# ─────────────────────────────────────────────────────────────────────
def trajectory_histogram(merged: pl.DataFrame) -> None:
    header("STEP 6 — RAIS trajectory completeness")

    hist = (
        merged.filter(pl.col("matched_rais"))
        .group_by("n_years_rais")
        .agg(pl.len().alias("n_firms"))
        .sort("n_years_rais")
    )
    total = hist["n_firms"].sum()
    log(f"  {'n_years_rais':>14} {'n_firms':>10} {'cum_pct':>10}")
    cum = 0
    for row in hist.iter_rows(named=True):
        cum += row["n_firms"]
        log(
            f"  {row['n_years_rais']:>14} {row['n_firms']:>10,} "
            f"{100 * cum / total:>9.1f}%"
        )


# ─────────────────────────────────────────────────────────────────────
# Step 7 — Unmatched-firm profile (ghost-firm suspects)
# ─────────────────────────────────────────────────────────────────────
def unmatched_profile(merged: pl.DataFrame) -> None:
    header("STEP 7 — Profile: unmatched firms (potential ghosts)")

    unm = merged.filter(~pl.col("matched_rais"))
    mat = merged.filter(pl.col("matched_rais"))

    def stats(df: pl.DataFrame, label: str) -> None:
        log(f"  {label}:")
        log(f"    n firms:               {df.height:,}")
        if df.is_empty():
            return
        log(f"    avg n_bids per firm:   {df['n_bids'].mean():.1f}")
        log(f"    avg n_wins per firm:   {df['n_wins'].mean():.1f}")
        log(f"    avg win rate:          "
            f"{(df['n_wins'] / df['n_bids'].cast(pl.Float64)).mean():.3f}")
        log(f"    avg n_years active:    {df['n_years_bec'].mean():.2f}")
        log(f"    firms with only 1 bid: "
            f"{df.filter(pl.col('n_bids') == 1).height:,}")
        log(f"    firms with only 1 year:"
            f"{df.filter(pl.col('n_years_bec') == 1).height:,}")

    stats(mat, "MATCHED (present in RAIS)")
    log("")
    stats(unm, "UNMATCHED (absent from RAIS)")
    log("")
    log("  Interpretation:")
    log("   • Very low avg n_bids + single-year presence in the unmatched group")
    log("     is a signature of either (i) ghost/shell firms or (ii) firms from")
    log("     other Brazilian states not in SP-RAIS slice (if the RAIS linkage")
    log("     was geographically restricted — verify with linkage_rais_bec.py).")
    log("   • A matched set with similar avg_bids to unmatched is best case.")


# ─────────────────────────────────────────────────────────────────────
# Step 8 — Sector and size distribution of matched firms
# ─────────────────────────────────────────────────────────────────────
def sector_size_snapshot(merged: pl.DataFrame) -> None:
    header("STEP 8 — Sector and size snapshot (matched firms)")

    mat = merged.filter(pl.col("matched_rais"))
    if mat.is_empty():
        log("  No matched firms — skipping.")
        return

    log("  Top 10 CNAE 2.0 (2-digit) among matched firms:")
    cnae_top = (
        mat.with_columns((pl.col("modal_cnae20") // 10000).alias("cnae2dig"))
        .group_by("cnae2dig")
        .agg(pl.len().alias("n_firms"))
        .sort("n_firms", descending=True)
        .head(10)
    )
    for row in cnae_top.iter_rows(named=True):
        log(f"    CNAE2={row['cnae2dig']}: {row['n_firms']:,}")

    log("")
    log("  Firm-size class distribution (RAIS size_class, max over years):")
    size_dist = (
        mat.group_by("max_size_class")
        .agg(pl.len().alias("n_firms"))
        .sort("max_size_class")
    )
    for row in size_dist.iter_rows(named=True):
        log(f"    size_class={row['max_size_class']}: {row['n_firms']:,}")


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    t0 = time.time()

    log("BEC × RAIS Match Audit — Gate check for Paper 4 pivot")
    log(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    bec_list, bec_lazy, rais = load_universes()
    fp = build_bec_firm_footprint(bec_lazy)
    cov = build_rais_coverage(rais)
    merged = compute_match(fp, cov)
    by_year = year_level_coverage(bec_lazy, rais)
    trajectory_histogram(merged)
    unmatched_profile(merged)
    sector_size_snapshot(merged)

    # Persist diagnostic tables
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    merged.write_parquet(OUT_FIRM, compression="snappy")
    by_year.write_parquet(OUT_BY_YEAR, compression="snappy")
    log("")
    log(f"[written] {OUT_FIRM}")
    log(f"[written] {OUT_BY_YEAR}")

    log(f"\nTotal time: {time.time() - t0:.1f}s")
    flush_report()


if __name__ == "__main__":
    main()
