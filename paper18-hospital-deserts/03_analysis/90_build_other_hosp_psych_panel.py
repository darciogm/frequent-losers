#!/usr/bin/env python3
"""
90_build_other_hosp_psych_panel.py

Build the municipality-year outcome that turns the descriptive "other hospitals
do not absorb" into a causal test. For each municipality, decompose inpatient
psychiatric admissions (F00-F99) into volume at the focal closing hospital(s)
it was exposed to versus volume at every OTHER hospital, then express the
"other" component per 1,000 residents. A staggered event study on this outcome
asks, with trends netted out, whether non-closing hospitals pick up the lost
volume after closure.

  other(m,t) = total psychiatric admissions(m,t) - admissions(m,t) to the
               hospital(s) municipality m was flow-exposed to losing.
For never-treated municipalities the focal set is empty, so other = total
(they have ~0 usage of any closing hospital by construction).

Both total and focal are taken from the SAME psychiatric edge list used by the
displacement decomposition (script 88), so other = total - closing is a clean
identity and the event-study outcome is consistent with Table displacement.

Inputs:
  02_data/intermediate/bipartite_edges_psych.parquet   (built by script 88)
  02_data/intermediate/exposure_panel.parquet          (muni -> focal CNES)
  02_data/intermediate/psych_outcomes_panel.parquet    (pop, headline total)

Output:
  02_data/processed/other_hosp_psych_panel.parquet
    codmun_6, year, psych_adm_total, psych_adm_closing, psych_adm_other,
    pop, psych_adm_total_per1k, psych_adm_closing_per1k, psych_adm_other_per1k

Usage: python 03_analysis/90_build_other_hosp_psych_panel.py [--force]
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
EDGES_PSY = INTER / "bipartite_edges_psych.parquet"
EXPOSURE = INTER / "exposure_panel.parquet"
PSYCH_PANEL = INTER / "psych_outcomes_panel.parquet"
OUT = PROC / "other_hosp_psych_panel.parquet"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if OUT.exists() and not args.force:
        print(f"{OUT.name} exists; use --force"); return

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")

    # Focal closing hospitals each municipality was flow-exposed to losing.
    # exposed_emb is the paper's primary (flow-based) exposure flag.
    con.execute(f"""
        CREATE TEMP TABLE focal AS
        SELECT DISTINCT codmun_6, CNES
        FROM read_parquet('{EXPOSURE}')
        WHERE exposed_emb
    """)

    # total and focal-closing psychiatric admissions per municipality-year.
    con.execute(f"""
        CREATE TEMP TABLE dec AS
        WITH tot AS (
            SELECT codmun_6, year, SUM(n_internacoes) AS psych_adm_total
            FROM read_parquet('{EDGES_PSY}')
            GROUP BY codmun_6, year
        ),
        clo AS (
            SELECT e.codmun_6, e.year, SUM(e.n_internacoes) AS psych_adm_closing
            FROM read_parquet('{EDGES_PSY}') e
            JOIN focal f ON f.codmun_6 = e.codmun_6 AND f.CNES = e.CNES
            GROUP BY e.codmun_6, e.year
        )
        SELECT t.codmun_6, t.year,
               t.psych_adm_total,
               COALESCE(c.psych_adm_closing, 0) AS psych_adm_closing,
               t.psych_adm_total - COALESCE(c.psych_adm_closing, 0) AS psych_adm_other
        FROM tot t LEFT JOIN clo c USING (codmun_6, year)
    """)

    # attach population (same denominator as the headline psych_adm_per1k).
    con.execute(f"""
        COPY (
            SELECT d.codmun_6, d.year,
                   d.psych_adm_total, d.psych_adm_closing, d.psych_adm_other,
                   p.pop,
                   d.psych_adm_total   * 1000.0 / NULLIF(p.pop, 0) AS psych_adm_total_per1k,
                   d.psych_adm_closing * 1000.0 / NULLIF(p.pop, 0) AS psych_adm_closing_per1k,
                   d.psych_adm_other   * 1000.0 / NULLIF(p.pop, 0) AS psych_adm_other_per1k
            FROM dec d
            JOIN read_parquet('{PSYCH_PANEL}') p USING (codmun_6, year)
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    # ---- verification ----
    chk = con.sql(f"""
        SELECT
            COUNT(*) n,
            SUM(CASE WHEN psych_adm_other < 0 THEN 1 ELSE 0 END) AS n_negative_other,
            SUM(CASE WHEN ABS(psych_adm_total - psych_adm_closing - psych_adm_other) > 1e-6
                     THEN 1 ELSE 0 END) AS n_identity_break,
            SUM(psych_adm_closing) AS tot_closing,
            SUM(psych_adm_total)   AS tot_total
        FROM read_parquet('{OUT}')
    """).df().iloc[0]
    print(f"[{time.strftime('%H:%M:%S')}] wrote {OUT.name}: {int(chk.n):,} muni-year rows")
    print(f"  negative 'other' rows : {int(chk.n_negative_other)}  (must be 0)")
    print(f"  identity breaks       : {int(chk.n_identity_break)}  (must be 0)")
    print(f"  closing share of total: {100*chk.tot_closing/chk.tot_total:.1f}%")


if __name__ == "__main__":
    main()
