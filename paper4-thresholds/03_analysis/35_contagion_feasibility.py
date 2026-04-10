#!/usr/bin/env python3
"""
35_contagion_feasibility.py — Feasibility check for "Collusion Contagion" paper

Questions:
1. How many BEC firms absorb ex-cartel workers, with identifiable timing?
2. Of those, how many bid on the same item codes pre & post hire?
3. What's the effective DiD sample size (firm × item × period)?
4. Is there dose variation (managers vs operational)?
"""
from __future__ import annotations
import time
from pathlib import Path
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "contagion_feasibility.txt"


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Identify ex-cartel workers who move to other BEC firms ───────

    print("Step 1: Identifying ex-cartel worker moves...", flush=True)

    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS start_yr,
               cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL AND cartel_end_year <= 2016
    """)

    # Worker-year panel at BEC firms
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year,
               LEFT(cbo2002, 1) AS cbo_major,
               TRY_CAST(REPLACE(rem_dez_sm, ',', '.') AS DOUBLE) AS wage_sm
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)

    # Workers at cartel firms during conduct
    con.sql("""
        CREATE OR REPLACE TABLE cartel_workers AS
        SELECT DISTINCT w.pis, w.cnpj_raiz AS cartel_cnpj,
               cf.setor, cf.end_yr,
               w.cbo_major, w.wage_sm,
               CASE WHEN w.cbo_major IN ('1','2') THEN 'manager_professional'
                    ELSE 'operational' END AS worker_type
        FROM worker_year w
        JOIN cartel_firms cf ON w.cnpj_raiz = cf.cnpj_raiz
        WHERE w.year BETWEEN cf.start_yr AND cf.end_yr
    """)
    n_cw = con.sql("SELECT count(DISTINCT pis) FROM cartel_workers").fetchone()[0]
    print(f"  workers at cartel firms during conduct: {n_cw:,}")

    # Their first appearance at a DIFFERENT BEC firm after conduct ends
    con.sql("""
        CREATE OR REPLACE TABLE moves AS
        SELECT
            cw.pis,
            cw.cartel_cnpj,
            cw.setor,
            cw.end_yr,
            cw.worker_type,
            w2.cnpj_raiz AS receiving_firm,
            MIN(w2.year) AS arrival_year
        FROM cartel_workers cw
        JOIN worker_year w2 ON cw.pis = w2.pis
        WHERE w2.cnpj_raiz != cw.cartel_cnpj
          AND w2.year > cw.end_yr
          -- Exclude moves to other cartel firms in same cartel
          AND w2.cnpj_raiz NOT IN (
              SELECT cnpj_raiz FROM cartel_firms WHERE setor = cw.setor
          )
        GROUP BY cw.pis, cw.cartel_cnpj, cw.setor, cw.end_yr,
                 cw.worker_type, w2.cnpj_raiz
    """)

    # ── Step 2: Characterize receiving firms ─────────────────────────────────

    print("Step 2: Characterizing receiving firms...", flush=True)

    receiving_stats = con.sql("""
        SELECT
            count(DISTINCT pis) AS n_workers_moved,
            count(DISTINCT receiving_firm) AS n_receiving_firms,
            count(DISTINCT CASE WHEN worker_type = 'manager_professional'
                THEN pis END) AS n_managers_moved,
            count(DISTINCT CASE WHEN worker_type = 'operational'
                THEN pis END) AS n_operational_moved
        FROM moves
    """).fetchdf()
    print(f"  {receiving_stats.to_string()}")

    # Workers per receiving firm distribution
    firm_doses = con.sql("""
        SELECT receiving_firm, arrival_year,
               count(DISTINCT pis) AS n_absorbed,
               count(DISTINCT CASE WHEN worker_type = 'manager_professional'
                   THEN pis END) AS n_managers,
               count(DISTINCT CASE WHEN worker_type = 'operational'
                   THEN pis END) AS n_operational
        FROM moves
        GROUP BY receiving_firm, arrival_year
    """).fetchdf()

    # ── Step 3: Check bidding overlap — do receiving firms bid on cartel items? ──

    print("Step 3: Checking bidding overlap...", flush=True)

    # Item codes where cartel firms bid during conduct
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_items AS
        SELECT DISTINCT
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz,
            "códigoitem", year
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] IN (
            SELECT cnpj_raiz FROM cartel_firms
        )
    """)
    con.sql("""
        CREATE OR REPLACE TABLE cartel_item_codes AS
        SELECT DISTINCT ci."códigoitem", cf.setor
        FROM cartel_items ci
        JOIN cartel_firms cf ON ci.cnpj_raiz = cf.cnpj_raiz
    """)
    n_cartel_items = con.sql("SELECT count(*) FROM cartel_item_codes").fetchone()[0]
    print(f"  item codes where cartel firms bid: {n_cartel_items:,}")

    # Receiving firms' bids on those same item codes
    con.sql(f"""
        CREATE OR REPLACE TABLE receiving_bids AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz,
            "códigoitem", year,
            flagvencedor AS won
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] IN (
            SELECT DISTINCT receiving_firm FROM moves
        )
    """)

    # How many receiving firms bid on cartel item codes?
    overlap = con.sql("""
        SELECT
            count(DISTINCT rb.cnpj_raiz) AS n_firms_bidding_cartel_items,
            count(DISTINCT rb.cnpj_raiz || '_' || rb."códigoitem") AS n_firm_item_pairs,
            count(*) AS n_bids
        FROM receiving_bids rb
        JOIN cartel_item_codes ci ON rb."códigoitem" = ci."códigoitem"
    """).fetchdf()
    print(f"  receiving firms bidding on cartel items:\n{overlap.to_string()}")

    # How many have bids BOTH before and after absorbing the worker?
    con.sql("""
        CREATE OR REPLACE TABLE did_candidates AS
        SELECT
            m.receiving_firm,
            m.arrival_year,
            rb."códigoitem",
            count(DISTINCT CASE WHEN rb.year < m.arrival_year THEN rb.year END) AS n_pre_years,
            count(DISTINCT CASE WHEN rb.year >= m.arrival_year THEN rb.year END) AS n_post_years,
            count(CASE WHEN rb.year < m.arrival_year THEN 1 END) AS n_pre_bids,
            count(CASE WHEN rb.year >= m.arrival_year THEN 1 END) AS n_post_bids
        FROM moves m
        JOIN receiving_bids rb ON m.receiving_firm = rb.cnpj_raiz
        JOIN cartel_item_codes ci ON rb."códigoitem" = ci."códigoitem"
        GROUP BY m.receiving_firm, m.arrival_year, rb."códigoitem"
        HAVING n_pre_years >= 1 AND n_post_years >= 1
    """)

    did_stats = con.sql("""
        SELECT
            count(*) AS n_firm_item_pairs,
            count(DISTINCT receiving_firm) AS n_firms,
            count(DISTINCT "códigoitem") AS n_items,
            sum(n_pre_bids) AS total_pre_bids,
            sum(n_post_bids) AS total_post_bids,
            avg(n_pre_years) AS avg_pre_years,
            avg(n_post_years) AS avg_post_years
        FROM did_candidates
    """).fetchdf()
    print(f"\n  DiD candidates (pre+post bids on cartel items):\n{did_stats.to_string()}")

    # ── Step 4: Dose variation ───────────────────────────────────────────────

    print("Step 4: Checking dose variation...", flush=True)

    # Among DiD candidates, how many absorbed managers vs operational?
    dose = con.sql("""
        SELECT
            dc.receiving_firm,
            dc."códigoitem",
            m_agg.n_total_absorbed,
            m_agg.n_managers_absorbed,
            m_agg.n_operational_absorbed
        FROM did_candidates dc
        JOIN (
            SELECT receiving_firm,
                   count(DISTINCT pis) AS n_total_absorbed,
                   count(DISTINCT CASE WHEN worker_type = 'manager_professional'
                       THEN pis END) AS n_managers_absorbed,
                   count(DISTINCT CASE WHEN worker_type = 'operational'
                       THEN pis END) AS n_operational_absorbed
            FROM moves
            GROUP BY receiving_firm
        ) m_agg ON dc.receiving_firm = m_agg.receiving_firm
    """).fetchdf()

    # ── Step 5: Control group ────────────────────────────────────────────────

    print("Step 5: Sizing control group...", flush=True)

    # Firms that bid on cartel item codes but did NOT absorb ex-cartel workers
    control_n = con.sql(f"""
        WITH bidders AS (
            SELECT DISTINCT
                LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz
            FROM read_parquet('{PAIRS_PREGAO}')
            WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_item_codes)
        )
        SELECT count(*) AS n_control_firms
        FROM bidders b
        WHERE b.cnpj_raiz NOT IN (SELECT DISTINCT receiving_firm FROM moves)
          AND b.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """).fetchone()[0]
    print(f"  control firms (bid on cartel items, no ex-cartel workers): {control_n:,}")

    # ── Write report ─────────────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Collusion Contagion — Feasibility Report\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("Q1: HOW MANY FIRMS ABSORB EX-CARTEL WORKERS?\n")
        f.write("-" * 50 + "\n")
        for col in receiving_stats.columns:
            f.write(f"  {col}: {int(receiving_stats[col].iloc[0]):,}\n")
        f.write("\n")

        f.write("  Dose distribution (workers per receiving firm):\n")
        for q in [0.25, 0.50, 0.75, 0.90, 0.99]:
            v = firm_doses["n_absorbed"].quantile(q)
            f.write(f"    p{int(q*100):02d}: {v:.0f}\n")
        f.write(f"    max: {firm_doses['n_absorbed'].max()}\n")
        f.write(f"    firms with ≥1 manager: "
                f"{(firm_doses['n_managers'] > 0).sum():,}\n\n")

        f.write("Q2: HOW MANY BID ON CARTEL ITEM CODES PRE+POST?\n")
        f.write("-" * 50 + "\n")
        for col in did_stats.columns:
            val = did_stats[col].iloc[0]
            f.write(f"  {col}: {val:,.1f}\n") if isinstance(val, float) else \
                f.write(f"  {col}: {int(val):,}\n")
        f.write("\n")

        f.write("Q3: EFFECTIVE DiD SAMPLE SIZE\n")
        f.write("-" * 50 + "\n")
        n_fp = int(did_stats["n_firm_item_pairs"].iloc[0])
        n_firms_did = int(did_stats["n_firms"].iloc[0])
        total_bids = int(did_stats["total_pre_bids"].iloc[0]) + \
                     int(did_stats["total_post_bids"].iloc[0])
        f.write(f"  Treated firm × item pairs: {n_fp:,}\n")
        f.write(f"  Treated firms:             {n_firms_did:,}\n")
        f.write(f"  Total bids (pre+post):     {total_bids:,}\n")
        f.write(f"  Control firms:             {control_n:,}\n\n")

        f.write("Q4: DOSE VARIATION (managers vs operational)\n")
        f.write("-" * 50 + "\n")
        n_with_mgr = int((dose["n_managers_absorbed"] > 0).sum())
        n_total_pairs = len(dose)
        f.write(f"  DiD pairs with ≥1 manager absorbed: "
                f"{n_with_mgr:,} / {n_total_pairs:,} "
                f"({n_with_mgr/n_total_pairs*100:.1f}%)\n")
        f.write(f"  DiD pairs with only operational:     "
                f"{n_total_pairs - n_with_mgr:,} "
                f"({(n_total_pairs - n_with_mgr)/n_total_pairs*100:.1f}%)\n\n")

        # Verdict
        f.write("FEASIBILITY VERDICT\n")
        f.write("=" * 50 + "\n")
        if n_fp >= 100 and total_bids >= 500:
            f.write("  ✓ FEASIBLE. Sufficient treated firm × item pairs\n")
            f.write(f"    and bid observations for DiD estimation.\n")
        elif n_fp >= 30:
            f.write("  △ MARGINAL. Small sample — results will be\n")
            f.write("    suggestive but imprecise.\n")
        else:
            f.write("  ✗ NOT FEASIBLE. Too few treated firm × item\n")
            f.write("    pairs for meaningful estimation.\n")

    print(f"\n[written] {OUT_REPORT}")
    con.close()
    print(f"Total time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
