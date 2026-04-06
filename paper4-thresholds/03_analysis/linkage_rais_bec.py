#!/usr/bin/env python3
"""
Link RAIS firm-level data to BEC-SP procurement suppliers.

Steps:
  1. Extract unique BEC supplier CNPJs (cnpj_raiz = first 8 digits)
  2. Process RAIS ESTB: filter to BEC suppliers, build firm panel
  3. Process RAIS vinculos (harmonized): aggregate wages, worker composition
  4. Merge and write final linked dataset

Output:
  02_data/rais_bec_linked.parquet — firm × year panel for BEC suppliers

Usage:
    python3 linkage_rais_bec.py                 # full pipeline
    python3 linkage_rais_bec.py --estb-only     # only ESTB (vinculos not ready)
    python3 linkage_rais_bec.py --check         # verify linkage rates
"""
import gc
import sys
import time
from pathlib import Path

import polars as pl

# ═══════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
BEC_FINAL = BASE / "02_data" / "final" / "df_convite_winner_looser.parquet"
BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
FIRMS = BASE / "02_data" / "firms" / "Firms_final.parquet"
ESTB_DIR = BASE / "RAIS" / "parquet" / "estb"
VINCULOS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
OUTPUT = BASE / "02_data" / "rais_bec_linked.parquet"

ESTB_ONLY = "--estb-only" in sys.argv
CHECK_ONLY = "--check" in sys.argv

YEARS = range(2009, 2018)  # RAIS coverage


# ═══════════════════════════════════════════════════════════════
# STEP 1: Extract BEC supplier CNPJs
# ═══════════════════════════════════════════════════════════════

def get_bec_cnpjs() -> pl.DataFrame:
    """Get unique supplier CNPJs from BEC data."""
    print("Step 1: Extracting BEC supplier CNPJs...", flush=True)

    # Use pre-built list if available
    if BEC_CNPJ_LIST.exists():
        cnpj_df = pl.read_parquet(BEC_CNPJ_LIST)
        print(f"  Loaded {len(cnpj_df):,} CNPJs from bec_cnpj_list.parquet")
    else:
        # Extract from main BEC dataset
        bec = pl.scan_parquet(BEC_FINAL)
        cnpj_df = (
            bec.select(
                pl.col("códigofornecedor").alias("firm_cnpj")
            )
            .unique()
            .collect()
        )
        # Derive cnpj_raiz (first 8 digits)
        cnpj_df = cnpj_df.with_columns(
            pl.col("firm_cnpj").str.slice(0, 8).alias("cnpj_raiz")
        )
        print(f"  Extracted {len(cnpj_df):,} unique suppliers from BEC")

    # Ensure cnpj_raiz is zero-padded to 8 digits
    cnpj_df = cnpj_df.with_columns(
        pl.col("cnpj_raiz").str.zfill(8)
    )

    unique_raiz = cnpj_df.select("cnpj_raiz").unique()
    print(f"  Unique cnpj_raiz (firm groups): {len(unique_raiz):,}")
    return cnpj_df


# ═══════════════════════════════════════════════════════════════
# STEP 2: Process RAIS ESTB
# ═══════════════════════════════════════════════════════════════

def _col_or(df: pl.DataFrame, *candidates) -> str:
    """Return the first column name found in df from candidates list."""
    for c in candidates:
        if c in df.columns:
            return c
    raise KeyError(f"None of {candidates} found in columns: {df.columns}")


# ESTB column name mapping: (canonical, era1_2009-2010, era2_2011+)
ESTB_COL_MAP = {
    "cnpj_raiz":       ("RADIC CNPJ",      "CNPJ Raiz"),
    "cnpj_cei":        ("IDENTIFICAD",      "CNPJ / CEI"),
    "n_employees":     ("ESTOQUE",          "Qtd Vínculos Ativos"),
    "n_employees_clt": ("EST CLT OUT",      "Qtd Vínculos CLT"),
    "n_employees_estat":("ESTOQUE ESTA",    "Qtd Vínculos Estatutários"),
    "size_class":      ("TAMESTAB",         "Tamanho Estabelecimento"),
    "cnae20":          ("CLAS CNAE 20",     "CNAE 2.0 Classe"),
    "cnae95":          ("CLAS CNAE 95",     "CNAE 95 Classe"),
    "cnae20_sub":      ("SB CLAS 20",       "CNAE 2.0 Subclasse"),
    "mun_estab":       ("MUNICIPIO",        "Município"),
    "nat_juridica":    ("NAT JURIDICA",     "Natureza Jurídica"),
    "ind_simples":     ("IND SIMPLES",      "Ind Simples"),
    "rais_negativa":   ("IND RAIS NEG",     "Ind Rais Negativa"),
    "data_abertura_raw":("DT ABERT COM",    "Data Abertura"),
    "razao_social":    ("RAZAO SOCIAL",     "Razão Social"),
    "cep_estab":       ("CEP",              "CEP Estab"),
}


def process_estb(bec_raiz_set: set) -> pl.DataFrame:
    """Read ESTB parquets, filter to BEC suppliers, build firm panel."""
    print("\nStep 2: Processing RAIS ESTB...", flush=True)

    frames = []
    for year in YEARS:
        fpath = ESTB_DIR / f"BR_{year}_ESTB.parquet"
        if not fpath.exists():
            print(f"  SKIP {year}: file not found")
            continue

        df = pl.read_parquet(fpath)

        # Detect era from column names
        col_cnpj_raiz = _col_or(df, "CNPJ Raiz", "RADIC CNPJ")
        col_cnpj_cei = _col_or(df, "CNPJ / CEI", "IDENTIFICAD")

        # Zero-pad CNPJ fields (stored as int64)
        df = df.with_columns([
            pl.col(col_cnpj_raiz).cast(pl.Utf8).str.zfill(8).alias("cnpj_raiz"),
            pl.col(col_cnpj_cei).cast(pl.Utf8).str.zfill(14).alias("cnpj_cei"),
        ])

        # Filter to BEC suppliers only (exclude invalid CNPJ "00000000")
        df_filtered = df.filter(
            pl.col("cnpj_raiz").is_in(bec_raiz_set)
            & (pl.col("cnpj_raiz") != "00000000")
        )

        n_match = len(df_filtered)
        n_total = len(df)
        print(f"  {year}: {n_match:,} / {n_total:,} establishments matched", flush=True)

        if n_match == 0:
            del df, df_filtered
            gc.collect()
            continue

        # Build select list dynamically based on available columns
        def _get(canonical: str) -> pl.Expr:
            era1, era2 = ESTB_COL_MAP[canonical]
            src_col = era2 if era2 in df_filtered.columns else era1
            return pl.col(src_col)

        def _safe_int(expr: pl.Expr, dtype) -> pl.Expr:
            """Cast to int type, handling dirty string values gracefully."""
            return expr.cast(pl.Utf8).str.strip_chars().str.replace(",", ".", literal=True).cast(pl.Float64, strict=False).cast(dtype, strict=False)

        estb_year = df_filtered.select([
            pl.lit(year).cast(pl.Int16).alias("ano"),
            "cnpj_raiz",
            "cnpj_cei",
            _safe_int(_get("n_employees"), pl.Int32).alias("n_employees"),
            _safe_int(_get("n_employees_clt"), pl.Int32).alias("n_employees_clt"),
            _safe_int(_get("n_employees_estat"), pl.Int32).alias("n_employees_estat"),
            _safe_int(_get("size_class"), pl.Int8).alias("size_class"),
            _safe_int(_get("cnae20"), pl.Int32).alias("cnae20"),
            _safe_int(_get("cnae95"), pl.Int32).alias("cnae95"),
            _safe_int(_get("cnae20_sub"), pl.Int32).alias("cnae20_sub"),
            _safe_int(_get("mun_estab"), pl.Int32).alias("mun_estab"),
            _safe_int(_get("nat_juridica"), pl.Int16).alias("nat_juridica"),
            _safe_int(_get("ind_simples"), pl.Int8).alias("ind_simples"),
            _safe_int(_get("rais_negativa"), pl.Int8).alias("rais_negativa"),
            _get("data_abertura_raw").cast(pl.Utf8).alias("data_abertura_raw"),
            _get("razao_social").cast(pl.Utf8).alias("razao_social"),
            _get("cep_estab").cast(pl.Utf8).str.zfill(8).alias("cep_estab"),
        ])

        frames.append(estb_year)
        del df, df_filtered
        gc.collect()

    if not frames:
        print("  No ESTB data matched!")
        return pl.DataFrame()

    estb_panel = pl.concat(frames, how="diagonal_relaxed")
    del frames
    gc.collect()

    print(f"  ESTB panel: {len(estb_panel):,} establishment-years")
    return estb_panel


def aggregate_estb_to_firm(estb: pl.DataFrame) -> pl.DataFrame:
    """Aggregate establishment-level ESTB to firm-level (cnpj_raiz × year).
    Sum employees across branches, take mode for categorical vars."""
    print("  Aggregating ESTB to firm level...", flush=True)

    firm_panel = estb.group_by(["cnpj_raiz", "ano"]).agg([
        # Sum employees across all branches
        pl.col("n_employees").sum().alias("firm_n_employees"),
        pl.col("n_employees_clt").sum().alias("firm_n_employees_clt"),
        # Count establishments
        pl.col("cnpj_cei").n_unique().alias("n_establishments"),
        # Sector: mode (most common across branches)
        pl.col("cnae20").mode().first().alias("firm_cnae20"),
        pl.col("cnae95").mode().first().alias("firm_cnae95"),
        # Legal form: mode
        pl.col("nat_juridica").mode().first().alias("firm_nat_juridica"),
        # Simples: any branch on Simples
        pl.col("ind_simples").max().alias("firm_simples"),
        # Main municipality (largest branch)
        pl.col("mun_estab").first().alias("firm_mun_main"),
        # Earliest opening date
        pl.col("data_abertura_raw").min().alias("firm_data_abertura"),
        # Max size class
        pl.col("size_class").max().alias("firm_size_class"),
    ]).sort(["cnpj_raiz", "ano"])

    # Sanity check: flag and cap implausible employee counts
    # (source data has misaligned rows in some years, e.g. 2010 ESTB)
    emp_p999 = firm_panel["firm_n_employees"].quantile(0.999)
    n_outliers = firm_panel.filter(pl.col("firm_n_employees") > emp_p999 * 10).height
    if n_outliers > 0:
        print(f"  WARNING: {n_outliers} firm-years with employees > {emp_p999*10:.0f} "
              f"(10× p99.9) — capping to null")
        firm_panel = firm_panel.with_columns(
            pl.when(pl.col("firm_n_employees") > emp_p999 * 10)
            .then(None)
            .otherwise(pl.col("firm_n_employees"))
            .alias("firm_n_employees")
        )
    # Also cap negative values (parsing artifacts)
    n_neg = firm_panel.filter(pl.col("firm_n_employees") < 0).height
    if n_neg > 0:
        print(f"  WARNING: {n_neg} firm-years with negative employees — setting to null")
        firm_panel = firm_panel.with_columns(
            pl.when(pl.col("firm_n_employees") < 0)
            .then(None)
            .otherwise(pl.col("firm_n_employees"))
            .alias("firm_n_employees")
        )

    print(f"  Firm panel: {len(firm_panel):,} firm-years, "
          f"{firm_panel['cnpj_raiz'].n_unique():,} unique firms")
    return firm_panel


# ═══════════════════════════════════════════════════════════════
# STEP 3: Process RAIS Vinculos (harmonized)
# ═══════════════════════════════════════════════════════════════

def process_vinculos(bec_raiz_set: set) -> pl.DataFrame:
    """Read harmonized vinculos, filter to BEC suppliers, aggregate to firm-year."""
    print("\nStep 3: Processing RAIS vinculos...", flush=True)

    vinculos_files = sorted(VINCULOS_DIR.glob("rais_vinculos_*.parquet"))
    if not vinculos_files:
        print("  No harmonized vinculos files found! Run harmonize_panel.py first.")
        return pl.DataFrame()

    frames = []
    for fpath in vinculos_files:
        year = int(fpath.stem.split("_")[-1])
        print(f"  Scanning {fpath.name}...", flush=True)

        # Lazy scan → filter → aggregate (memory-safe for large files)
        df = (
            pl.scan_parquet(fpath)
            .filter(pl.col("cnpj_raiz").is_in(bec_raiz_set))
            .filter(pl.col("vinculo_ativo_3112") == 1)  # active links on Dec 31
            .group_by("cnpj_raiz")
            .agg([
                pl.lit(year).cast(pl.Int16).alias("ano"),
                # Wage statistics
                pl.col("rem_dez_nom")
                    .str.replace(",", ".", literal=True)
                    .cast(pl.Float64, strict=False)
                    .mean()
                    .alias("avg_wage_dez"),
                pl.col("rem_dez_nom")
                    .str.replace(",", ".", literal=True)
                    .cast(pl.Float64, strict=False)
                    .median()
                    .alias("med_wage_dez"),
                pl.col("rem_dez_nom")
                    .str.replace(",", ".", literal=True)
                    .cast(pl.Float64, strict=False)
                    .sum()
                    .alias("total_wage_bill"),
                # Worker count (verification)
                pl.len().alias("n_vinculos_ativos"),
                # Hours
                pl.col("horas_contratuais").mean().alias("avg_hours"),
                # Demographics
                pl.col("escolaridade").mean().alias("avg_escolaridade"),
                (pl.col("sexo") == 2).cast(pl.Float64).mean().alias("share_female"),
                pl.col("idade").mean().alias("avg_age_worker"),
                # Tenure
                pl.col("tempo_emprego")
                    .str.replace(",", ".", literal=True)
                    .cast(pl.Float64, strict=False)
                    .mean()
                    .alias("avg_tenure_months"),
                # Occupation diversity
                pl.col("cbo2002").n_unique().alias("n_occupations"),
            ])
            .collect()
        )

        # Flatten the 'ano' column (it's a list from group_by)
        df = df.with_columns(pl.lit(year).cast(pl.Int16).alias("ano"))

        n_firms = len(df)
        print(f"    {year}: {n_firms:,} firms matched with active vinculos", flush=True)
        frames.append(df)

        del df
        gc.collect()

    if not frames:
        return pl.DataFrame()

    vinculos_panel = pl.concat(frames, how="diagonal_relaxed")
    del frames
    gc.collect()

    print(f"  Vinculos firm panel: {len(vinculos_panel):,} firm-years")
    return vinculos_panel


# ═══════════════════════════════════════════════════════════════
# STEP 4: Merge and write
# ═══════════════════════════════════════════════════════════════

def merge_and_write(estb_firm: pl.DataFrame, vinculos_firm: pl.DataFrame):
    """Merge ESTB and vinculos firm panels, write output."""
    print("\nStep 4: Merging panels...", flush=True)

    if vinculos_firm.is_empty():
        merged = estb_firm
        print("  Using ESTB-only panel (no vinculos data)")
    elif estb_firm.is_empty():
        merged = vinculos_firm
        print("  Using vinculos-only panel (no ESTB data)")
    else:
        merged = estb_firm.join(
            vinculos_firm,
            on=["cnpj_raiz", "ano"],
            how="full",
            coalesce=True,
        )
        print(f"  Merged: {len(merged):,} firm-years")

    merged = merged.sort(["cnpj_raiz", "ano"])

    # Write
    merged.write_parquet(OUTPUT, compression="snappy")
    out_size = OUTPUT.stat().st_size / 1e6
    print(f"  Written: {OUTPUT.name} ({out_size:.1f}MB)")
    print(f"  Shape: {merged.shape}")
    print(f"  Unique firms: {merged['cnpj_raiz'].n_unique():,}")
    print(f"  Year range: {merged['ano'].min()} - {merged['ano'].max()}")

    return merged


def check_linkage(merged: pl.DataFrame):
    """Report linkage statistics."""
    print("\n" + "=" * 60)
    print("LINKAGE REPORT")
    print("=" * 60)

    # BEC suppliers
    bec = pl.scan_parquet(BEC_FINAL)
    bec_cnpjs = (
        bec.select(
            pl.col("códigofornecedor").str.slice(0, 8).alias("cnpj_raiz")
        )
        .unique()
        .collect()
    )
    n_bec = len(bec_cnpjs)

    # Matched in RAIS
    rais_cnpjs = merged.select("cnpj_raiz").unique()
    n_rais = len(rais_cnpjs)

    # Match rate
    matched = bec_cnpjs.join(rais_cnpjs, on="cnpj_raiz", how="inner")
    n_matched = len(matched)

    print(f"  BEC suppliers (unique cnpj_raiz): {n_bec:,}")
    print(f"  RAIS firms in linked panel:       {n_rais:,}")
    print(f"  Matched:                          {n_matched:,} ({100*n_matched/n_bec:.1f}%)")
    print(f"  Unmatched BEC suppliers:          {n_bec - n_matched:,}")

    # By year
    print("\n  Match rate by year:")
    by_year = merged.group_by("ano").agg(
        pl.col("cnpj_raiz").n_unique().alias("n_firms"),
        pl.col("firm_n_employees").mean().alias("avg_employees"),
    ).sort("ano")
    print(by_year)


# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

def main():
    t0 = time.time()
    print("RAIS ↔ BEC-SP Linkage")
    print("=" * 60)

    # Step 1
    cnpj_df = get_bec_cnpjs()
    bec_raiz_set = set(cnpj_df["cnpj_raiz"].unique().to_list())

    # Step 2: ESTB
    estb = process_estb(bec_raiz_set)
    estb_firm = aggregate_estb_to_firm(estb) if not estb.is_empty() else pl.DataFrame()
    del estb
    gc.collect()

    # Step 3: Vinculos
    if ESTB_ONLY:
        print("\nSkipping vinculos (--estb-only mode)")
        vinculos_firm = pl.DataFrame()
    else:
        vinculos_firm = process_vinculos(bec_raiz_set)

    # Step 4: Merge
    merged = merge_and_write(estb_firm, vinculos_firm)

    # Report
    check_linkage(merged)

    elapsed = time.time() - t0
    print(f"\nTotal time: {elapsed:.0f}s")


if __name__ == "__main__":
    main()
