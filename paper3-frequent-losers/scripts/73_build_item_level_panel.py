#!/usr/bin/env python3
"""
73_build_item_level_panel.py
============================

Extract ItemLicitacao.csv from 84 CGU monthly ZIPs and build the
federal item-level panel needed by AN-039 (selection mechanism)
and AN-040 (within-cell mechanism).

Inputs
------
- /home/darciogm1/projetos/comprasnet/data/raw/portal/{YYYYMM}_Licitacoes.zip
  (84 ZIPs, 2013-01..2019-12)
- data/processed_comprasnet/bid_level_full_year.parquet
  (used to compute n_firms per item, year tagging already applied)

Output
------
- data/processed_comprasnet/item_level_panel.parquet
  One row per (numerodaoc, codigoitem, year) with:
    valor_item       -- final award value
    quantidade_item
    codigo_vencedor  -- CNPJ-14 of winner
    nome_vencedor
    descricao_item
    codigo_ug, nome_ug
    modality_code
    year             -- from filename YYYYMM
    n_firms          -- bidders per item (from bid_level_full_year join)
    n_firms_winners  -- winners flagged in participation
"""

from __future__ import annotations

import logging
import re
import sys
import time
import zipfile
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
ZIP_DIR = Path("/home/darciogm1/projetos/comprasnet/data/raw/portal")
EXTRACT_DIR = Path("/tmp/duckdb_spill_comprasnet/extracted_items")
OUT = ROOT / "data/processed_comprasnet/item_level_panel.parquet"
PANEL_INPUT = ROOT / "data/processed_comprasnet/bid_level_full_year.parquet"
MODALITIES = (5, 9999)
YYYYMM_RE = re.compile(r"(\d{6})_Licitacoes\.zip$")


def extract_item_csvs() -> None:
    EXTRACT_DIR.mkdir(parents=True, exist_ok=True)
    zips = sorted(ZIP_DIR.glob("*_Licitacoes.zip"))
    logging.info(f"  extracting ItemLicitacao from {len(zips)} ZIPs")
    for zp in zips:
        m = YYYYMM_RE.search(zp.name)
        if not m:
            continue
        ym = m.group(1)
        target = EXTRACT_DIR / f"{ym}_ItemLicitacao.csv"
        if target.exists():
            continue
        with zipfile.ZipFile(zp) as zf:
            for n in zf.namelist():
                if "ItemLicita" in n and n.endswith(".csv"):
                    with zf.open(n) as src, target.open("wb") as dst:
                        while True:
                            chunk = src.read(2**20)
                            if not chunk:
                                break
                            dst.write(chunk)
                    break


def build_panel() -> None:
    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill_items'")

    glob_pat = str(EXTRACT_DIR / "*_ItemLicitacao.csv")
    modality_list = ",".join(str(m) for m in MODALITIES)

    logging.info("  building item_level_raw view ...")
    t0 = time.time()
    con.sql(f"""
        CREATE OR REPLACE VIEW item_level_raw AS
        SELECT
            "Número Licitação"      AS numerodaoc,
            "Código Item Compra"    AS códigoitem,
            CAST(SUBSTR(
                REGEXP_EXTRACT(filename, '(\\d{{6}})_ItemLicitacao'),
                1, 4
            ) AS INTEGER) AS year,
            CAST("Código Modalidade Compra" AS INTEGER) AS po_phase_code,
            CAST("Código UG" AS VARCHAR)                AS codigo_ug,
            "Nome UG"               AS nome_ug,
            "Código Órgão"          AS codigo_orgao,
            "Descrição"             AS descricao_item,
            TRY_CAST(REPLACE(REPLACE("Quantidade Item", '.', ''), ',', '.') AS DOUBLE) AS quantidade_item,
            TRY_CAST(REPLACE(REPLACE("Valor Item", '.', ''), ',', '.') AS DOUBLE) AS valor_item,
            LPAD("Código Vencedor", 14, '0') AS codigo_vencedor,
            "Nome Vencedor"         AS nome_vencedor
        FROM read_csv(
            '{glob_pat}',
            delim=';', encoding='latin-1', header=true, all_varchar=true,
            ignore_errors=true, filename=true
        )
        WHERE CAST("Código Modalidade Compra" AS INTEGER) IN ({modality_list})
    """)

    n_raw = con.sql("SELECT COUNT(*) FROM item_level_raw").fetchone()[0]
    logging.info(f"    item_level_raw: {n_raw:,} rows ({time.time()-t0:.1f}s)")

    # Build n_firms aggregate from participation panel
    logging.info("  computing n_firms per (tender, item) ...")
    t0 = time.time()
    con.sql(f"""
        CREATE OR REPLACE VIEW participation_agg AS
        SELECT
            numerodaoc,
            códigoitem,
            year,
            COUNT(DISTINCT códigofornecedor)              AS n_firms,
            COUNT(*)                                       AS n_participations,
            SUM(flagvencedor)                              AS n_winners,
            SUM(CASE WHEN flagvencedor = 0 THEN 1 ELSE 0 END) AS n_losers
        FROM '{PANEL_INPUT}'
        GROUP BY numerodaoc, códigoitem, year
    """)
    n_part = con.sql("SELECT COUNT(*) FROM participation_agg").fetchone()[0]
    logging.info(f"    participation_agg: {n_part:,} rows ({time.time()-t0:.1f}s)")

    logging.info("  joining + writing parquet ...")
    t0 = time.time()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    con.sql(f"""
        COPY (
            SELECT
                ilr.numerodaoc,
                ilr.códigoitem,
                ilr.year,
                ilr.po_phase_code,
                ilr.codigo_ug,
                ilr.nome_ug,
                ilr.codigo_orgao,
                ilr.descricao_item,
                ilr.quantidade_item,
                ilr.valor_item,
                ilr.codigo_vencedor,
                ilr.nome_vencedor,
                COALESCE(pa.n_firms, 0)        AS n_firms,
                COALESCE(pa.n_participations, 0) AS n_participations,
                COALESCE(pa.n_winners, 0)      AS n_winners,
                COALESCE(pa.n_losers, 0)       AS n_losers
            FROM item_level_raw ilr
            LEFT JOIN participation_agg pa
              ON ilr.numerodaoc = pa.numerodaoc
             AND ilr.códigoitem = pa.códigoitem
             AND ilr.year = pa.year
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    logging.info(f"    write done ({time.time()-t0:.1f}s)")

    n = con.sql(f"SELECT COUNT(*) FROM '{OUT}'").fetchone()[0]
    n_valid = con.sql(f"""
        SELECT COUNT(*) FROM '{OUT}'
        WHERE valor_item IS NOT NULL AND valor_item > 0 AND n_firms > 0
    """).fetchone()[0]
    logging.info(f"  total rows: {n:,}")
    logging.info(f"  with valid valor_item + n_firms > 0: {n_valid:,}")


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    extract_item_csvs()
    build_panel()


if __name__ == "__main__":
    main()
