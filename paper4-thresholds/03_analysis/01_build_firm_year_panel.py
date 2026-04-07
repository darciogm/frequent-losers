#!/usr/bin/env python3
"""
01_build_firm_year_panel.py — Firm × year outcome panel for Paper 4 (Caminho 1)

Purpose
-------
Build the primary firm-year panel of outcomes consumed by the close-bid RD
design. Inputs are the harmonized RAIS vinculos (worker-level, already produced
by RAIS/harmonize_panel.py) and the ESTB-based firm summary already in
`rais_bec_linked.parquet`. This script does NOT touch BEC microdata directly —
the merge with BEC happens downstream in the RD scripts.

Outcomes produced (per cnpj_raiz × ano)
----------------------------------------
  Employment
    n_employees_3112             active vínculos on Dec 31
    n_vinculos_total             total vínculos seen in the year
    n_hires_year                 hires made during the year (admissão in year)
    n_separations_year           separations during the year

  Payroll
    total_payroll_dez            sum of December wages over active vínculos
    total_payroll_mean           sum of mean annual wages over all vínculos
    avg_wage_dez                 mean December wage
    med_wage_dez                 median December wage
    sd_wage_dez                  std of December wage

  Workforce composition
    share_female
    avg_age
    avg_escolaridade
    share_university             escolaridade ≥ 9 (higher education)
    avg_tenure_months
    n_occupations                distinct CBO2002 codes
    share_managerial             share with CBO2002 starting with '1' (mgmt)

  Public-sector ties (firm level, for revolving-door section)
    share_from_public_sector     share of workers whose _current_ vínculo's
                                 natureza_juridica is in public codes (1xxx);
                                 mostly zero for BEC suppliers but useful as
                                 sanity check

Separate outputs for revolving-door analysis
---------------------------------------------
For each year, also writes a per-worker "new hires" file containing the PIS
of workers hired by BEC suppliers in that year, so that a second script can
look up their prior vínculos across RAIS and flag public-sector origins.

Outputs
-------
  02_data/firms/firm_year_panel.parquet
  02_data/firms/new_hires/new_hires_{year}.parquet  (one per year)

Usage
-----
  python3 03_analysis/01_build_firm_year_panel.py                # all years
  python3 03_analysis/01_build_firm_year_panel.py --year 2015    # single year
  python3 03_analysis/01_build_firm_year_panel.py --dry-run      # schema check

Notes
-----
- `rem_dez_nom` is a string with Brazilian decimal comma, zero-padded; parsed
  with cleanup.
- `data_admissao` is a DDMMYYYY integer (7 or 8 digits); hire-year extracted
  as `data_admissao % 10000`.
- `natureza_juridica` codes 1000-1999 identify public-sector establishments
  (Brazilian IBGE classification).
- Workers can appear in multiple vínculos in a year at the same firm; we count
  vínculos not headcount. For Dec-31 headcount we rely on
  `vinculo_ativo_3112 == 1`.
"""
from __future__ import annotations

import argparse
import gc
import sys
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
# Paths and constants
# ─────────────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
VINCULOS_DIR  = BASE / "RAIS" / "parquet" / "harmonized"
RAIS_LINKED   = BASE / "02_data" / "rais_bec_linked.parquet"

OUT_DIR       = BASE / "02_data" / "firms"
OUT_PANEL     = OUT_DIR / "firm_year_panel.parquet"
OUT_HIRES_DIR = OUT_DIR / "new_hires"

YEARS = list(range(2009, 2018))  # RAIS harmonized coverage

# natureza_juridica: Brazilian IBGE classification
# Codes 1000-1999 = public administration (direct, indirect, autarquias, etc.)
PUBLIC_NJ_MIN = 1000
PUBLIC_NJ_MAX = 1999


# ─────────────────────────────────────────────────────────────────────
# Wage parser: "0001234567,89" → 12345.67 (R$)
# ─────────────────────────────────────────────────────────────────────
def parse_wage(expr: pl.Expr) -> pl.Expr:
    """Parse Brazilian-format wage string (0-padded, comma decimal) to Float64.
    Missing / malformed values → null."""
    return (
        expr.cast(pl.Utf8)
        .str.strip_chars()
        .str.replace(",", ".", literal=True)
        .cast(pl.Float64, strict=False)
    )


# ─────────────────────────────────────────────────────────────────────
# Step 1: Load BEC supplier set
# ─────────────────────────────────────────────────────────────────────
def load_bec_set() -> set[str]:
    print("Loading BEC supplier CNPJ raiz set...", flush=True)
    df = pl.read_parquet(BEC_CNPJ_LIST)
    raiz_set = set(
        df.select(pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8))["cnpj_raiz"]
        .unique()
        .to_list()
    )
    # Drop the junk bucket
    raiz_set.discard("00000000")
    print(f"  {len(raiz_set):,} unique BEC CNPJ raiz (non-junk)")
    return raiz_set


# ─────────────────────────────────────────────────────────────────────
# Step 2: Aggregate one year of vinculos to firm × year
# ─────────────────────────────────────────────────────────────────────
def aggregate_year(year: int, bec_set: set[str]) -> pl.DataFrame:
    """Read one year of harmonized vinculos, filter to BEC suppliers,
    aggregate to (cnpj_raiz, ano)."""
    fpath = VINCULOS_DIR / f"rais_vinculos_{year}.parquet"
    if not fpath.exists():
        print(f"  [SKIP] {year}: file not found", flush=True)
        return pl.DataFrame()

    print(f"  [{year}] scanning {fpath.name}...", flush=True)

    # Lazy-scan → filter to BEC → collect base (still at vínculo level, but much smaller)
    base = (
        pl.scan_parquet(fpath)
        .filter(pl.col("cnpj_raiz").is_in(bec_set))
        .select([
            "cnpj_raiz",
            "pis",
            "vinculo_ativo_3112",
            "data_admissao",
            "mes_desligamento",
            "natureza_juridica",
            "sexo",
            "idade",
            "escolaridade",
            "tempo_emprego",
            "cbo2002",
            "rem_dez_nom",
            "rem_media_nom",
        ])
        .with_columns([
            parse_wage(pl.col("rem_dez_nom")).alias("wage_dez"),
            parse_wage(pl.col("rem_media_nom")).alias("wage_mean"),
            parse_wage(pl.col("tempo_emprego")).alias("tenure_months"),
            # Hire-year: DDMMYYYY integer → last 4 digits
            (pl.col("data_admissao").cast(pl.Int64) % 10000).alias("admissao_year"),
            # Managerial: CBO2002 starts with '1' (grande grupo 1 = dirigentes)
            (pl.col("cbo2002").cast(pl.Utf8).str.slice(0, 1) == "1")
                .cast(pl.Int8)
                .alias("is_managerial"),
            # Active on Dec 31
            (pl.col("vinculo_ativo_3112") == 1).cast(pl.Int8).alias("active_3112"),
            # Female = sexo == 2 (RAIS convention)
            (pl.col("sexo") == 2).cast(pl.Float64).alias("female"),
            # University: escolaridade ≥ 9 (superior completo or more)
            (pl.col("escolaridade") >= 9).cast(pl.Float64).alias("university"),
            # Public-sector current vínculo (sanity — should be ≈0 for BEC firms)
            ((pl.col("natureza_juridica") >= PUBLIC_NJ_MIN) &
             (pl.col("natureza_juridica") <= PUBLIC_NJ_MAX))
                .cast(pl.Float64)
                .alias("nj_is_public"),
        ])
        .collect()
    )

    n_vinc = base.height
    if n_vinc == 0:
        print(f"  [{year}] 0 vínculos matched BEC set — skipping", flush=True)
        return pl.DataFrame()

    print(f"  [{year}] {n_vinc:,} vínculos at BEC firms", flush=True)

    # Aggregate to firm × year (all vínculos)
    all_vinc = (
        base.group_by("cnpj_raiz")
        .agg([
            pl.lit(year, dtype=pl.Int16).alias("ano"),
            pl.len().alias("n_vinculos_total"),
            pl.col("active_3112").sum().alias("n_employees_3112"),
            (pl.col("admissao_year") == year).cast(pl.Int8).sum().alias("n_hires_year"),
            (pl.col("mes_desligamento") > 0).cast(pl.Int8).sum().alias("n_separations_year"),
            # Wage stats on ALL vinculos (December wage, filtering zeros as null proxy)
            pl.col("wage_dez").filter(pl.col("wage_dez") > 0).sum().alias("total_payroll_dez"),
            pl.col("wage_mean").filter(pl.col("wage_mean") > 0).sum().alias("total_payroll_mean"),
            pl.col("wage_dez").filter(pl.col("wage_dez") > 0).mean().alias("avg_wage_dez"),
            pl.col("wage_dez").filter(pl.col("wage_dez") > 0).median().alias("med_wage_dez"),
            pl.col("wage_dez").filter(pl.col("wage_dez") > 0).std().alias("sd_wage_dez"),
            # Composition — mean over all vínculos
            pl.col("female").mean().alias("share_female"),
            pl.col("idade").mean().alias("avg_age"),
            pl.col("escolaridade").mean().alias("avg_escolaridade"),
            pl.col("university").mean().alias("share_university"),
            pl.col("tenure_months").mean().alias("avg_tenure_months"),
            pl.col("cbo2002").n_unique().alias("n_occupations"),
            pl.col("is_managerial").mean().alias("share_managerial"),
            pl.col("nj_is_public").mean().alias("share_from_public_sector"),
        ])
    )

    gc.collect()
    return all_vinc, base  # also return base for hires export


# ─────────────────────────────────────────────────────────────────────
# Step 3: Extract new hires for revolving-door follow-up
# ─────────────────────────────────────────────────────────────────────
def write_new_hires(year: int, base: pl.DataFrame) -> None:
    """Persist the subset of vínculos representing workers hired by BEC firms
    in this year. Feeds the revolving-door script."""
    OUT_HIRES_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_HIRES_DIR / f"new_hires_{year}.parquet"

    hires = (
        base.filter(pl.col("admissao_year") == year)
        .select([
            "cnpj_raiz",
            "pis",
            pl.lit(year, dtype=pl.Int16).alias("year_hired"),
            "cbo2002",
            "is_managerial",
            "wage_dez",
            "wage_mean",
            "idade",
            "escolaridade",
            "sexo",
        ])
    )

    hires.write_parquet(out, compression="snappy")
    print(f"  [{year}] new hires written: {out.name} ({hires.height:,} rows)", flush=True)


# ─────────────────────────────────────────────────────────────────────
# Step 4: Merge with ESTB-based firm panel (already in rais_bec_linked)
# ─────────────────────────────────────────────────────────────────────
def attach_estb(firm_year: pl.DataFrame) -> pl.DataFrame:
    """Merge firm-year vinculos aggregation with ESTB-level variables from
    the existing rais_bec_linked panel."""
    if not RAIS_LINKED.exists():
        print("  [WARN] rais_bec_linked.parquet not found — skipping ESTB merge")
        return firm_year

    estb = pl.read_parquet(RAIS_LINKED).select([
        "cnpj_raiz",
        "ano",
        "n_establishments",
        "firm_cnae20",
        "firm_cnae95",
        "firm_nat_juridica",
        "firm_simples",
        "firm_mun_main",
        "firm_data_abertura",
        "firm_size_class",
    ])

    merged = firm_year.join(
        estb, on=["cnpj_raiz", "ano"], how="left"
    )
    print(f"  Merged ESTB: {merged.height:,} firm-years")
    return merged


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, default=None,
                        help="Process single year (for testing)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Only print schema, don't write")
    parser.add_argument("--no-hires", action="store_true",
                        help="Skip writing new-hires files")
    args = parser.parse_args()

    t0 = time.time()
    print("Firm × year panel build — Paper 4 / Caminho 1")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    bec_set = load_bec_set()

    years_to_run = [args.year] if args.year else YEARS
    frames = []
    for year in years_to_run:
        result = aggregate_year(year, bec_set)
        if isinstance(result, tuple):
            fy, base = result
            frames.append(fy)
            if not args.no_hires:
                write_new_hires(year, base)
            del base
            gc.collect()
        elif not result.is_empty():
            frames.append(result)

    if not frames:
        print("No data produced. Exiting.")
        return

    firm_year = pl.concat(frames, how="diagonal_relaxed")
    print(f"\nConcatenated firm-year panel: {firm_year.height:,} rows")

    firm_year = attach_estb(firm_year)

    firm_year = firm_year.sort(["cnpj_raiz", "ano"])

    if args.dry_run:
        print("\n[DRY RUN] Schema:")
        print(firm_year.schema)
        print(firm_year.head(3))
        return

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    firm_year.write_parquet(OUT_PANEL, compression="snappy")
    size_mb = OUT_PANEL.stat().st_size / 1e6
    print(f"\n[written] {OUT_PANEL} ({size_mb:.1f} MB)")
    print(f"  Unique firms: {firm_year['cnpj_raiz'].n_unique():,}")
    print(f"  Year range: {firm_year['ano'].min()} – {firm_year['ano'].max()}")
    print(f"  Columns ({len(firm_year.columns)}): {firm_year.columns}")

    # Sanity: distribution of headcount
    print("\nHeadcount (n_employees_3112) distribution:")
    print(firm_year["n_employees_3112"].describe())

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
