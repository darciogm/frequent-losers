#!/usr/bin/env python
"""
70a_build_lococor.py

Referee #5 mechanical-displacement check, build step.

Decompose suicide (CAUSABAS X60-X84) and self-harm (X60-X84 + Y10-Y34) deaths
by PLACE OF OCCURRENCE (SIM field LOCOCOR) at municipality of RESIDENCE
(CODMUNRES, 6-digit) x year (DTOBITO positions 5-8). Split each into
IN-HOSPITAL (LOCOCOR='1') vs OUT-OF-HOSPITAL (LOCOCOR != '1', i.e. health
establishment other than hospital / home / public road / other / unknown).

CID and key conventions match the canonical build (D1_build_psych_gate.py):
  suicide  : SUBSTR(CAUSABAS,1,3) BETWEEN 'X60' AND 'X84'
  selfharm : suicide OR SUBSTR(CAUSABAS,1,3) BETWEEN 'Y10' AND 'Y34'
  year     : CAST(SUBSTR(DTOBITO,5,4) AS INTEGER), window 2010-2023
  codmun_6 : LPAD(CODMUNRES,6,'0')

Output: 02_data/intermediate/lococor_counts.parquet
  (codmun_6, year, n_suicide_in, n_suicide_out, n_selfharm_in, n_selfharm_out)

DuckDB engine. Per ~/.claude convention: telemetry, cache-aware (--force).
A concurrent parallel job is running -> PRAGMA threads=4.
"""
import argparse
import glob
import logging
import os
import sys
import time

import duckdb
import psutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "02_data", "raw", "sim")
OUT = os.path.join(ROOT, "02_data", "intermediate", "lococor_counts.parquet")
LOG = os.path.join(ROOT, "04_logs", "70a_build_lococor.log")

YR_LO, YR_HI = 2010, 2023


def setup_log():
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    log = logging.getLogger("65a")
    log.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    fh = logging.FileHandler(LOG, mode="w")
    fh.setFormatter(fmt)
    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(fmt)
    log.addHandler(fh)
    log.addHandler(sh)
    return log


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="rebuild even if output exists")
    args = ap.parse_args()

    log = setup_log()
    vm = psutil.virtual_memory()
    log.info("host=%s threads=4 RAM_total=%.1fGB RAM_free=%.1fGB",
             os.uname().nodename, vm.total / 1e9, vm.available / 1e9)

    if os.path.exists(OUT) and not args.force:
        log.info("output exists, skipping (use --force to rebuild): %s", OUT)
        return

    # canonical per-year glob avoids corrupt out-of-window files (e.g. dorj2003)
    files = []
    for y in range(YR_LO, YR_HI + 1):
        files += glob.glob(os.path.join(RAW, f"do*{y}.parquet"))
    files = sorted(files)
    log.info("SIM files in window %d-%d: %d", YR_LO, YR_HI, len(files))
    if not files:
        log.error("no SIM files found")
        sys.exit(1)
    flist = "[" + ",".join(f"'{f}'" for f in files) + "]"

    con = duckdb.connect()
    con.sql("PRAGMA threads=4")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    t0 = time.time()
    log.info("[1/2] decomposing suicide/self-harm by LOCOCOR ...")
    # in-hospital := LOCOCOR='1'; out-of-hospital := everything else (2,3,4,5,6,9, '')
    q = f"""
    WITH d AS (
        SELECT CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) AS year,
               LPAD(CODMUNRES,6,'0')               AS codmun_6,
               SUBSTR(CAUSABAS,1,3)                AS c3,
               (LOCOCOR = '1')                     AS in_hosp
        FROM read_parquet({flist}, union_by_name=true)
        WHERE CAUSABAS IS NOT NULL AND CODMUNRES IS NOT NULL
          AND DTOBITO IS NOT NULL AND LENGTH(DTOBITO)=8
          AND CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) BETWEEN {YR_LO} AND {YR_HI}
    ),
    tagged AS (
        SELECT codmun_6, year,
               (c3 BETWEEN 'X60' AND 'X84')                              AS is_suic,
               (c3 BETWEEN 'X60' AND 'X84' OR c3 BETWEEN 'Y10' AND 'Y34') AS is_self,
               in_hosp
        FROM d
    )
    SELECT codmun_6, year,
           SUM(CASE WHEN is_suic AND in_hosp        THEN 1 ELSE 0 END) AS n_suicide_in,
           SUM(CASE WHEN is_suic AND NOT in_hosp    THEN 1 ELSE 0 END) AS n_suicide_out,
           SUM(CASE WHEN is_self AND in_hosp        THEN 1 ELSE 0 END) AS n_selfharm_in,
           SUM(CASE WHEN is_self AND NOT in_hosp    THEN 1 ELSE 0 END) AS n_selfharm_out
    FROM tagged
    WHERE is_suic OR is_self
    GROUP BY codmun_6, year
    ORDER BY codmun_6, year
    """
    con.sql(f"CREATE TABLE counts AS {q}")
    log.info("  done in %.1fs RSS=%.2fGB rows=%d",
             time.time() - t0, rss_gb(),
             con.sql("SELECT COUNT(*) FROM counts").fetchone()[0])

    # sanity: national totals + in-hospital shares
    chk = con.sql("""
        SELECT SUM(n_suicide_in) si, SUM(n_suicide_out) so,
               SUM(n_selfharm_in) hi, SUM(n_selfharm_out) ho
        FROM counts
    """).df().iloc[0]
    suic_tot = chk.si + chk.so
    self_tot = chk.hi + chk.ho
    log.info("national suicide deaths: %d (in=%d out=%d, in-share=%.2f%%)",
             int(suic_tot), int(chk.si), int(chk.so), 100 * chk.si / suic_tot)
    log.info("national selfharm deaths: %d (in=%d out=%d, in-share=%.2f%%)",
             int(self_tot), int(chk.hi), int(chk.ho), 100 * chk.hi / self_tot)

    log.info("[2/2] writing parquet -> %s", OUT)
    con.sql(f"COPY counts TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')")
    con.close()
    log.info("DONE total=%.1fs RSS=%.2fGB", time.time() - t0, rss_gb())


if __name__ == "__main__":
    main()
