#!/usr/bin/env python3
"""
65a_build_gkm_pnash48.py

Build the distance-rule treatment cohort (g_km) for the 48 PNASH psychiatric
closures, so the flow-vs-distance first-stage head-to-head (65, 65b) can hold
the closures, outcome, and municipality universe fixed and vary only the
exposure rule.

Source of truth: closure_sample_exposure_flags_long.parquet (built by script 63),
sample_id = 'pnash_psychiatric_closures' -- the canonical per-(closure,
municipality) exposure flags for the main sample. flow_exposed is the >=5%
pre-closure flow-share rule (g_emb); distance_exposed is the top-3 nearest-
hospital rule (g_km), identical to the definitions in 21_define_exposure /
63_closure_sample_architecture.

Validation gate: the flow cohort reconstructed here must reproduce, exactly, the
104 treated municipalities (codmun_6 + cohort year) carried in
staggered_panel_pnash48_ext.parquet. If it does not, g_km is not trustworthy and
the script aborts rather than writing a mismatched cohort.

Output: 02_data/intermediate/g_km_pnash48.parquet  (codmun_6, g_km)

Usage: python3 03_analysis/65a_build_gkm_pnash48.py [--force]
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
LOG = ROOT / "04_logs"

FLAGS = PROC / "closure_sample_exposure_flags_long.parquet"
PANEL = INTER / "staggered_panel_pnash48_ext.parquet"
OUT = INTER / "g_km_pnash48.parquet"
SAMPLE = "pnash_psychiatric_closures"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="rebuild even if output exists")
    args = ap.parse_args()
    t0 = time.perf_counter()
    LOG.mkdir(exist_ok=True)
    logf = (LOG / "65a_build_gkm_pnash48.log").open("w")

    def say(m: str) -> None:
        print(m)
        logf.write(m + "\n")

    if OUT.exists() and not args.force:
        say(f"{OUT.name} exists; skipping (use --force)")
        return

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")

    con.execute(f"""
        CREATE TEMP TABLE s AS
        SELECT * FROM read_parquet('{FLAGS}') WHERE sample_id = '{SAMPLE}'
    """)
    n_clo = con.sql("SELECT COUNT(DISTINCT (CNES, year_closure)) FROM s").fetchone()[0]
    say(f"sample={SAMPLE}  closures={n_clo}")

    # cohorts: first closure year a municipality is exposed under each rule
    g_emb = con.sql(
        "SELECT municipality AS codmun_6, MIN(year_closure) AS g_emb "
        "FROM s WHERE flow_exposed GROUP BY 1"
    ).df()
    g_km = con.sql(
        "SELECT municipality AS codmun_6, MIN(year_closure) AS g_km "
        "FROM s WHERE distance_exposed GROUP BY 1"
    ).df()
    say(f"flow-treated munis={len(g_emb)}  distance-treated munis={len(g_km)}")

    # validation gate: flow cohort must match the panel's 104 treated munis exactly
    panel_emb = con.sql(
        f"SELECT DISTINCT codmun_6, CAST(g_emb AS INTEGER) AS g_emb "
        f"FROM read_parquet('{PANEL}') WHERE g_emb > 0"
    ).df()
    con.register("g_emb_rec", g_emb)
    con.register("panel_emb", panel_emb)
    match = con.sql(
        "SELECT COUNT(*) FROM g_emb_rec r JOIN panel_emb p "
        "ON r.codmun_6 = p.codmun_6 AND CAST(r.g_emb AS INTEGER) = p.g_emb"
    ).fetchone()[0]
    n_panel, n_rec = len(panel_emb), len(g_emb)
    say(f"validation: flow cohort exact match {match}/{n_panel} panel ({n_rec} reconstructed)")
    if not (match == n_panel == n_rec):
        say("ABORT: reconstructed flow cohort does not match the panel; g_km not trustworthy")
        sys.exit(1)

    # disagreement summary (for the exhibit / sanity)
    con.register("g_km_rec", g_km)
    both = con.sql("SELECT COUNT(*) FROM g_emb_rec e JOIN g_km_rec k USING (codmun_6)").fetchone()[0]
    say(f"overlap={both}  flow-only={n_rec - both}  distance-only={len(g_km) - both}  "
        f"Jaccard={both / (n_rec + len(g_km) - both):.3f}")

    g_km.to_parquet(OUT, index=False)
    say(f"wrote {OUT}  ({len(g_km)} rows)  in {time.perf_counter() - t0:.1f}s")
    logf.close()


if __name__ == "__main__":
    main()
