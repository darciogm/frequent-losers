#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

import duckdb
import polars as pl

from _telemetry import StepTimer, runtime_header, write_json

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG_DIR = ROOT / "04_logs"

OUT_SIM = INTER / "sim_quality_panel.parquet"
OUT_AMEN = INTER / "amenable_mortality_redistributed.parquet"
LOG_FILE = LOG_DIR / "02b_build_sim_quality_panel.log"
JSON_FILE = LOG_DIR / "02b_build_sim_quality_panel.json"


def build_logger() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(LOG_FILE, mode="w"), logging.StreamHandler(sys.stdout)],
    )
    return logging.getLogger("sim_quality")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    log = build_logger()
    header = runtime_header(ROOT, seeds=[42])
    log.info("==== begin 02b_build_sim_quality_panel ====")
    log.info("telemetry=%s", json.dumps(header, ensure_ascii=True))

    if OUT_SIM.exists() and OUT_AMEN.exists() and not args.force:
        log.info("outputs already exist; use --force to rebuild")
        write_json(JSON_FILE, {"status": "skipped_existing", "telemetry": header})
        return

    timer = StepTimer(log)
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_spill'")

    sim_glob = str(INTER / "sim_consolidated" / "sim_do_*.parquet")
    log.info("building municipality-year SIM quality panel from %s", sim_glob)
    sim_df = con.sql(
        f"""
        WITH sim AS (
            SELECT
                LPAD(CAST(codmunres AS VARCHAR), 6, '0') AS codmun_6,
                EXTRACT(YEAR FROM dtobito) AS year,
                causabas
            FROM read_parquet('{sim_glob}', union_by_name=true)
            WHERE codmunres IS NOT NULL
              AND dtobito IS NOT NULL
              AND causabas IS NOT NULL
              AND EXTRACT(YEAR FROM dtobito) BETWEEN 2010 AND 2023
        )
        SELECT
            codmun_6,
            year,
            COUNT(*) AS n_total_deaths,
            SUM(CASE WHEN SUBSTR(causabas, 1, 1) = 'R' THEN 1 ELSE 0 END) AS n_r_any,
            SUM(CASE WHEN SUBSTR(causabas, 1, 3) IN ('R96', 'R97', 'R98', 'R99') THEN 1 ELSE 0 END) AS n_r96_r99,
            SUM(CASE WHEN SUBSTR(causabas, 1, 3) = 'R99' THEN 1 ELSE 0 END) AS n_r99
        FROM sim
        GROUP BY 1, 2
        """
    ).pl().with_columns(
        [
            (pl.col("n_r_any") / pl.col("n_total_deaths")).alias("frac_r_any"),
            (pl.col("n_r96_r99") / pl.col("n_total_deaths")).alias("frac_r96_r99"),
            (pl.col("n_r99") / pl.col("n_total_deaths")).alias("frac_r99"),
        ]
    )
    OUT_SIM.parent.mkdir(parents=True, exist_ok=True)
    sim_df.write_parquet(OUT_SIM, compression="snappy")
    write_json(
        OUT_SIM.with_suffix(".metadata.json"),
        {
            "telemetry": header,
            "rows": sim_df.height,
            "columns": sim_df.columns,
            "peak_rss_gb": timer.peak_rss_gb,
        },
    )
    step_sim = timer.mark("build_sim_quality_panel")

    amen = pl.read_parquet(INTER / "amenable_mortality.parquet")
    amen_adj = (
        amen.join(sim_df.select(["codmun_6", "year", "n_total_deaths", "n_r96_r99", "frac_r96_r99"]), on=["codmun_6", "year"], how="left")
        .with_columns(
            [
                pl.col("frac_r96_r99").fill_null(0.0),
                (pl.col("n_amenable") + pl.col("frac_r96_r99") * pl.col("n_total")).alias("n_amenable_redistributed"),
            ]
        )
        .with_columns(
            [
                pl.when(pl.col("pop").is_not_null() & (pl.col("pop") > 0))
                .then(pl.col("n_amenable_redistributed") / pl.col("pop") * 1e5)
                .otherwise(None)
                .alias("rate_per100k_redistributed")
            ]
        )
    )
    amen_adj.write_parquet(OUT_AMEN, compression="snappy")
    write_json(
        OUT_AMEN.with_suffix(".metadata.json"),
        {
            "telemetry": header,
            "rows": amen_adj.height,
            "columns": amen_adj.columns,
            "adjustment": "adds municipality-year R96-R99 share times total deaths to amenable count as a sensitivity redistribution, not a validated cause-of-death recode",
            "peak_rss_gb": timer.peak_rss_gb,
        },
    )
    step_amen = timer.mark("build_amenable_redistributed")

    payload = {
        "status": "ok",
        "telemetry": header,
        "steps": [step_sim, step_amen],
        "outputs": {
            "sim_quality_panel": str(OUT_SIM),
            "amenable_mortality_redistributed": str(OUT_AMEN),
        },
        "summary": {
            "sim_quality_rows": sim_df.height,
            "amenable_rows": amen_adj.height,
            "total_r96_r99_deaths": int(sim_df["n_r96_r99"].sum()),
            "mean_frac_r96_r99": float(sim_df["frac_r96_r99"].mean()),
        },
    }
    write_json(JSON_FILE, payload)
    log.info("done")


if __name__ == "__main__":
    main()
