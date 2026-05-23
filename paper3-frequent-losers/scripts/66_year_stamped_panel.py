#!/usr/bin/env python3
"""
66_year_stamped_panel.py
========================

Build a year-stamped ComprasNet participation panel for temporal-split
analyses (AN-006 strict prospective holdout, AN-014 leakage audit).

Input:  84 extracted CSVs already in /tmp/duckdb_spill_comprasnet/extracted/
        (artifact of the 00_build_eventlevel_comprasnet.py run). Each is
        named {YYYYMM}_ParticipantesLicitacao.csv. The YYYY portion of
        the filename is used as the year stamp (corresponds to CGU bulk
        dump month = procurement homologation period).

Output: data/processed_comprasnet/bid_level_full_year.parquet
        Same schema as bid_level_full.parquet PLUS a `year` column.

Why a separate parquet: the existing bid_level_full.parquet does NOT
preserve any date. Temporal splits need year. Rather than rebuild
the full pipeline, this script piggybacks on the extracted CSVs in
/tmp (still present from the build run).
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb


ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = Path("/tmp/duckdb_spill_comprasnet/extracted")
OUT = ROOT / "data/processed_comprasnet/bid_level_full_year.parquet"
MODALITIES = (5, 9999)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    if not EXTRACTED.exists():
        sys.exit(
            f"missing input dir: {EXTRACTED}. Either keep the extracted "
            f"CSVs in place after 00_build_eventlevel_comprasnet.py, or "
            f"re-run that script to regenerate them."
        )

    csvs = sorted(EXTRACTED.glob("*_ParticipantesLicitacao.csv"))
    logging.info(f"found {len(csvs)} CSVs in {EXTRACTED}")
    if len(csvs) < 70:
        logging.warning(f"only {len(csvs)} CSVs; expected ~84")

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill_year'")

    glob_pat = str(EXTRACTED / "*_ParticipantesLicitacao.csv")
    modality_list = ",".join(str(m) for m in MODALITIES)

    t0 = time.time()
    logging.info("reading + year-stamping panel ...")
    OUT.parent.mkdir(parents=True, exist_ok=True)

    con.sql(f"""
        COPY (
            SELECT
                LPAD(CAST("Código Participante" AS VARCHAR), 14, '0')
                    AS códigofornecedor,
                "Número Licitação"      AS numerodaoc,
                "Código Item Compra"    AS códigoitem,
                CASE WHEN "Flag Vencedor" = 'SIM' THEN 1 ELSE 0 END AS flagvencedor,
                CAST("Código UG" AS VARCHAR) AS códigounidadecompradora,
                "Modalidade Compra"     AS descriçãoprocedimentocompra,
                CAST("Código Modalidade Compra" AS INTEGER) AS po_phase_code,
                'comprasnet'            AS panel,
                CAST(SUBSTR(
                    REGEXP_EXTRACT(filename, '(\\d{{6}})_ParticipantesLicitacao'),
                    1, 4
                ) AS INTEGER) AS year
            FROM read_csv(
                '{glob_pat}',
                delim=';', encoding='latin-1', header=true, all_varchar=true,
                ignore_errors=true, filename=true
            )
            WHERE CAST("Código Modalidade Compra" AS INTEGER) IN ({modality_list})
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    t1 = time.time()
    logging.info(f"wrote {OUT} in {t1 - t0:.1f}s")

    # Sanity: row count and year distribution
    n = con.sql(f"SELECT COUNT(*) FROM '{OUT}'").fetchone()[0]
    logging.info(f"  rows: {n:,}")
    yr_dist = con.sql(f"""
        SELECT year, COUNT(*) AS n_rows
        FROM '{OUT}' GROUP BY year ORDER BY year
    """).fetchall()
    for y, n in yr_dist:
        logging.info(f"    year={y}: {n:,}")


if __name__ == "__main__":
    main()
