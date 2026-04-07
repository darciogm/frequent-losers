#!/usr/bin/env python3
"""
12_build_cade_ground_truth.py — CADE cartel ground-truth file for Track A

Purpose
-------
Build a clean cnpj_raiz × cartel period table from the three CADE files in
paper3-frequent-losers/data/processed/. This is the foundation for testing
cartel detection screens against ground truth.

Sources
-------
  cade_carteis_licitacoes_2009_2019.csv  — master list, 65 rows, with
      process number, sector, judgment date, conduct, fines, notes.
  cade_bec_crossmatch.csv  — 49 rows, BEC firms matched to cartel processes
      with full CNPJ + win statistics (already verified to exist in BEC).
  cade_fl_cobidders.csv    — 193 rows, frequent-loser firms that co-bid with
      cartel firms (used as a separate "exposure" measure).

Outputs
-------
  02_data/firms/cade_ground_truth.parquet
      schema: cnpj_full, cnpj_raiz, razao_social, processo, setor,
              cartel_start_year, cartel_end_year, judgment_year,
              is_sp, conduct_type, source

  02_data/firms/cade_cartel_processes.parquet
      schema: processo, setor, sp_relevant, judgment_year,
              cartel_start_year, cartel_end_year, conduct, n_firms,
              total_fines

  02_data/intermediate/cade_ground_truth_report.txt
"""
from __future__ import annotations

import re
import time
from pathlib import Path

import polars as pl

# ─────────────────────────────────────────────────────────────────────
PAPER3 = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

CADE_MASTER     = PAPER3 / "data/processed/cade_carteis_licitacoes_2009_2019.csv"
CADE_CROSSMATCH = PAPER3 / "data/processed/cade_bec_crossmatch.csv"
CADE_COBIDDERS  = PAPER3 / "data/processed/cade_fl_cobidders.csv"

BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
FIRM_PANEL    = BASE / "02_data" / "firms" / "firm_year_panel.parquet"

OUT_GT      = BASE / "02_data" / "firms" / "cade_ground_truth.parquet"
OUT_PROCESS = BASE / "02_data" / "firms" / "cade_cartel_processes.parquet"
OUT_REPORT  = BASE / "02_data" / "intermediate" / "cade_ground_truth_report.txt"

# ─────────────────────────────────────────────────────────────────────
# Hand-curated cartel period info, parsed from CADE README + notes column.
# Each entry: (processo, start_year, end_year). end_year = None means
# cartel was still active or end date not known; we use judgment_year as a
# conservative upper bound in that case.
# ─────────────────────────────────────────────────────────────────────
CARTEL_PERIODS = {
    "08012.010022/2008-16": (2006, 2010),  # merenda escolar SP — Pregão 73/2006 + 08/2009
    "08700.004617/2013-41": (1998, 2013),  # trens/metrôs SP — desde 1998 Linha 5 Metrô
    "08012.001273/2010-24": (2009, 2013),  # aquecedores solares MCMV
    "08700.005876/2019-85": (2017, 2019),  # transporte escolar Fernandópolis
    "08700.007278/2015-17": (2010, 2015),  # cafeterias Infraero
    "08700.005789/2015-02": (2008, 2014),  # sacos de lixo SP MG PR — Op Colludium
    "08012.003931/2005-55": (2004, 2006),  # ambulâncias SUS SES-SP 2005
    "08012.002222/2011-09": (2007, 2011),  # medicamentos SP MG BA PE
    "08012.009732/2008-01": (2005, 2010),  # unidades móveis saúde nacional
    "08012.011853/2008-13": (2005, 2009),  # coleta lixo RS Santa Rosa
    "08012.008821/2008-22": (2006, 2008),  # antirretrovirais nacional
    "08012.005928/2003-12": (2000, 2003),  # medicamentos genéricos / Merck
    # IT_DF case has no formal process number in the CSV
    "IT_DF": (2005, 2008),                 # TI Brasília 4 empresas
}


# ─────────────────────────────────────────────────────────────────────
def _strip_cnpj(s: str | None) -> str | None:
    """Normalize CNPJ string: keep only digits, zero-pad to 14, return None
    if empty."""
    if s is None or s == "":
        return None
    digits = re.sub(r"\D", "", str(s))
    if not digits:
        return None
    return digits.zfill(14)


def main() -> None:
    t0 = time.time()
    print("=" * 70)
    print("CADE ground-truth build — Paper 4 / Track A")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # ─────────────────────────────────────────────────────────────────
    # Step 1: load master CADE list (65 rows)
    # ─────────────────────────────────────────────────────────────────
    print("\n[1] Loading CADE master list...", flush=True)
    master = pl.read_csv(CADE_MASTER, infer_schema_length=200, ignore_errors=True)
    print(f"  rows: {master.height}")
    print(f"  cols: {master.columns}")

    # Normalize CNPJ
    master = master.with_columns([
        pl.col("cnpj")
            .map_elements(_strip_cnpj, return_dtype=pl.Utf8)
            .alias("cnpj_full"),
    ])
    master = master.with_columns([
        pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz"),
        pl.col("data_julgamento")
            .str.slice(0, 4)
            .cast(pl.Int32, strict=False)
            .alias("judgment_year"),
    ])
    n_with_cnpj = master.filter(pl.col("cnpj_full").is_not_null()).height
    print(f"  with full CNPJ: {n_with_cnpj}/{master.height}")

    # ─────────────────────────────────────────────────────────────────
    # Step 2: load BEC crossmatch (49 rows, all have CNPJ)
    # ─────────────────────────────────────────────────────────────────
    print("\n[2] Loading BEC crossmatch...", flush=True)
    crossmatch = pl.read_csv(CADE_CROSSMATCH, infer_schema_length=200,
                             ignore_errors=True)
    print(f"  rows: {crossmatch.height}")
    crossmatch = crossmatch.with_columns([
        pl.col("firm_cnpj")
            .map_elements(_strip_cnpj, return_dtype=pl.Utf8)
            .alias("cnpj_full"),
    ])
    crossmatch = crossmatch.with_columns(
        pl.col("cnpj_full").str.slice(0, 8).alias("cnpj_raiz")
    )

    # ─────────────────────────────────────────────────────────────────
    # Step 3: build process-level metadata
    # ─────────────────────────────────────────────────────────────────
    print("\n[3] Building process-level metadata...", flush=True)
    process_meta = (
        master.group_by("numero_processo")
        .agg([
            pl.col("setor").drop_nulls().first().alias("setor"),
            pl.col("uf_licitacao").drop_nulls().first().alias("uf"),
            pl.col("tipo_conduta").drop_nulls().first().alias("conduct_type"),
            pl.col("judgment_year").drop_nulls().first(),
            pl.col("multa_reais").max().alias("max_fine_reais"),
            pl.len().alias("n_master_rows"),
        ])
        .filter(pl.col("numero_processo").is_not_null())
        .filter(pl.col("numero_processo") != "")
    )
    print(f"  unique processes: {process_meta.height}")

    # Add curated cartel periods
    period_df = pl.DataFrame({
        "numero_processo": list(CARTEL_PERIODS.keys()),
        "cartel_start_year": [p[0] for p in CARTEL_PERIODS.values()],
        "cartel_end_year": [p[1] for p in CARTEL_PERIODS.values()],
    })
    process_meta = process_meta.join(
        period_df, on="numero_processo", how="left"
    )
    n_with_period = process_meta.filter(
        pl.col("cartel_start_year").is_not_null()
    ).height
    print(f"  with curated cartel period: {n_with_period}/{process_meta.height}")

    # SP relevance flag
    process_meta = process_meta.with_columns(
        (pl.col("uf") == "SP").cast(pl.Int8).alias("sp_relevant")
    )
    process_meta.write_parquet(OUT_PROCESS, compression="snappy")
    print(f"  [written] {OUT_PROCESS}")

    # ─────────────────────────────────────────────────────────────────
    # Step 4: build firm-level ground-truth (long format)
    # ─────────────────────────────────────────────────────────────────
    print("\n[4] Building firm-level ground-truth...", flush=True)

    # Source 1: master list rows that DO have CNPJ
    gt_master = (
        master
        .filter(pl.col("cnpj_full").is_not_null())
        .select([
            pl.col("cnpj_full"),
            pl.col("cnpj_raiz"),
            pl.col("razao_social"),
            pl.col("numero_processo").alias("processo"),
            pl.col("setor"),
            pl.col("uf_licitacao").alias("uf"),
            pl.col("tipo_conduta").alias("conduct_type"),
            pl.col("judgment_year"),
            pl.lit("master").alias("source"),
        ])
    )
    print(f"  from master list (with CNPJ): {gt_master.height}")

    # Source 2: BEC crossmatch (all have CNPJ + verified BEC presence)
    gt_xmatch = (
        crossmatch
        .select([
            pl.col("cnpj_full"),
            pl.col("cnpj_raiz"),
            pl.col("razao_bec").alias("razao_social"),
            pl.col("processo"),
            pl.col("setor"),
            pl.col("uf"),
            pl.lit(None, dtype=pl.Utf8).alias("conduct_type"),
            pl.lit(None, dtype=pl.Int32).alias("judgment_year"),
            pl.lit("bec_crossmatch").alias("source"),
        ])
    )
    print(f"  from BEC crossmatch: {gt_xmatch.height}")

    # Stack and dedupe by (cnpj_raiz, processo)
    gt = pl.concat([gt_master, gt_xmatch], how="diagonal_relaxed")
    gt = gt.unique(subset=["cnpj_raiz", "processo"], keep="first")
    print(f"  after dedupe (cnpj_raiz × processo): {gt.height}")

    # Attach cartel period from process_meta
    period_lookup = process_meta.select([
        pl.col("numero_processo").alias("processo"),
        "cartel_start_year",
        "cartel_end_year",
        "sp_relevant",
        pl.col("conduct_type").alias("conduct_type_proc"),
        pl.col("judgment_year").alias("judgment_year_proc"),
    ])
    gt = gt.join(period_lookup, on="processo", how="left")

    # Coalesce conduct_type and judgment_year (firm row may have it; otherwise
    # take from process meta)
    gt = gt.with_columns([
        pl.coalesce([pl.col("conduct_type"), pl.col("conduct_type_proc")])
            .alias("conduct_type"),
        pl.coalesce([pl.col("judgment_year"), pl.col("judgment_year_proc")])
            .alias("judgment_year"),
    ]).drop(["conduct_type_proc", "judgment_year_proc"])

    print(f"  unique cnpj_raiz: {gt['cnpj_raiz'].n_unique()}")
    print(f"  unique processes: {gt['processo'].n_unique()}")

    # ─────────────────────────────────────────────────────────────────
    # Step 5: cross-check coverage against BEC universe
    # ─────────────────────────────────────────────────────────────────
    print("\n[5] Cross-checking against BEC universe...", flush=True)

    bec = pl.read_parquet(BEC_CNPJ_LIST).with_columns(
        pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8)
    )
    bec_set = set(bec["cnpj_raiz"].unique().to_list())
    bec_set.discard("00000000")
    print(f"  BEC universe: {len(bec_set):,} unique cnpj_raiz")

    panel = pl.read_parquet(FIRM_PANEL)
    panel_set = set(panel["cnpj_raiz"].unique().to_list())
    panel_set.discard("00000000")
    print(f"  RAIS-linked firm panel: {len(panel_set):,} unique cnpj_raiz")

    gt = gt.with_columns([
        pl.col("cnpj_raiz").is_in(bec_set).cast(pl.Int8).alias("in_bec"),
        pl.col("cnpj_raiz").is_in(panel_set).cast(pl.Int8).alias("in_rais_panel"),
    ])

    n_in_bec = gt.filter(pl.col("in_bec") == 1).height
    n_in_rais = gt.filter(pl.col("in_rais_panel") == 1).height
    print(f"  CADE entries with cnpj_raiz in BEC: "
          f"{n_in_bec}/{gt.height} ({100*n_in_bec/gt.height:.1f}%)")
    print(f"  CADE entries with cnpj_raiz in RAIS panel: "
          f"{n_in_rais}/{gt.height} ({100*n_in_rais/gt.height:.1f}%)")

    # ─────────────────────────────────────────────────────────────────
    # Step 6: write
    # ─────────────────────────────────────────────────────────────────
    print("\n[6] Writing ground-truth file...", flush=True)
    OUT_GT.parent.mkdir(parents=True, exist_ok=True)
    gt = gt.sort(["processo", "cnpj_raiz"])
    gt.write_parquet(OUT_GT, compression="snappy")
    print(f"  [written] {OUT_GT}")
    print(f"  shape: {gt.shape}")
    print(f"  cols: {gt.columns}")

    # ─────────────────────────────────────────────────────────────────
    # Step 7: process-level summary
    # ─────────────────────────────────────────────────────────────────
    print("\n[7] Per-process coverage:")
    summary = (
        gt.group_by(["processo", "setor"])
        .agg([
            pl.len().alias("n_firms"),
            pl.col("in_bec").sum().alias("n_in_bec"),
            pl.col("in_rais_panel").sum().alias("n_in_rais"),
            pl.col("cartel_start_year").first(),
            pl.col("cartel_end_year").first(),
            pl.col("sp_relevant").first(),
        ])
        .sort("processo")
    )
    print(summary)

    # ─────────────────────────────────────────────────────────────────
    # Step 8: write text report
    # ─────────────────────────────────────────────────────────────────
    OUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_REPORT, "w") as f:
        f.write(f"CADE ground-truth report — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Master list: {master.height} rows\n")
        f.write(f"Master with CNPJ: {n_with_cnpj}\n")
        f.write(f"BEC crossmatch: {crossmatch.height} rows\n")
        f.write(f"Final ground-truth: {gt.height} rows\n")
        f.write(f"Unique cnpj_raiz: {gt['cnpj_raiz'].n_unique()}\n")
        f.write(f"Unique processes: {gt['processo'].n_unique()}\n\n")
        f.write(f"In BEC: {n_in_bec}/{gt.height} ({100*n_in_bec/gt.height:.1f}%)\n")
        f.write(f"In RAIS panel: {n_in_rais}/{gt.height} ({100*n_in_rais/gt.height:.1f}%)\n\n")
        f.write("Per-process coverage:\n\n")
        f.write(str(summary) + "\n\n")
        f.write("Process-level metadata (with curated cartel periods):\n\n")
        f.write(str(process_meta) + "\n")
    print(f"\n[written] {OUT_REPORT}")

    # ─────────────────────────────────────────────────────────────────
    # Step 9: final headline counts
    # ─────────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("HEADLINE COUNTS for ground truth")
    print("=" * 70)

    sp_in_bec = gt.filter(
        (pl.col("in_bec") == 1) & (pl.col("sp_relevant") == 1)
    )
    n_sp_firms = sp_in_bec["cnpj_raiz"].n_unique()
    n_sp_proc = sp_in_bec["processo"].n_unique()
    print(f"  SP-relevant CADE firms in BEC universe: "
          f"{n_sp_firms} firms across {n_sp_proc} processes")

    rais_in_bec = gt.filter(
        (pl.col("in_bec") == 1) &
        (pl.col("in_rais_panel") == 1) &
        (pl.col("sp_relevant") == 1)
    )
    n_rais_firms = rais_in_bec["cnpj_raiz"].n_unique()
    print(f"  ... of which in RAIS-linked panel: {n_rais_firms} firms")

    # Cartel period × bec audit
    in_bec_with_period = gt.filter(
        (pl.col("in_bec") == 1) &
        pl.col("cartel_start_year").is_not_null()
    )
    print(f"  CADE firms in BEC with known cartel period: "
          f"{in_bec_with_period.height} entries, "
          f"{in_bec_with_period['cnpj_raiz'].n_unique()} unique firms")

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
