#!/usr/bin/env python3
"""
32_worker_characteristics.py — Who migrates from cartel firms?

Purpose
-------
Characterize workers who flow from cartel firms to rivals post-conduct using
RAIS variables: education, occupation (CBO major group), wage, tenure, age.

Compare three groups:
  (a) MOVERS: workers who leave cartel firms post-conduct and go to BEC rivals
  (b) STAYERS: workers who remain at cartel firms post-conduct
  (c) CONTROL MOVERS: workers who move between non-cartel BEC firms in the
      same markets during the same period

Key question: are knowledge-carrying workers (managers, high-wage, long tenure)
overrepresented among movers from cartel firms?

Output
------
- 02_data/intermediate/worker_characteristics.txt
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "worker_characteristics.txt"


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Identify cartel firms and conduct periods ────────────────────

    print("Step 1: Loading cartel firms...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS start_yr,
               cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016  -- need at least 1 year post-conduct in RAIS
    """)
    n_cf = con.sql("SELECT count(*) FROM cartel_firms").fetchone()[0]
    print(f"  cartel firms: {n_cf}")

    # ── Step 2: Build worker panel at cartel firms (last year of conduct) ────

    print("Step 2: Building worker panel at cartel firms...", flush=True)

    # Workers at cartel firms in the last year of conduct
    # Get their characteristics from that year
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_workers AS
        SELECT
            r.pis,
            r.cnpj_raiz,
            cf.setor,
            cf.end_yr,
            r.ano AS obs_year,
            r.escolaridade,
            LEFT(r.cbo2002, 1) AS cbo_major,
            TRY_CAST(REPLACE(r.rem_dez_sm, ',', '.') AS DOUBLE) AS wage_sm,
            TRY_CAST(REPLACE(r.tempo_emprego, ',', '.') AS DOUBLE) AS tenure_months,
            r.idade,
            r.sexo
        FROM read_parquet('{rais_glob}') r
        JOIN cartel_firms cf ON r.cnpj_raiz = cf.cnpj_raiz
        WHERE r.ano = cf.end_yr
          AND r.pis IS NOT NULL
    """)
    n_cw = con.sql("SELECT count(*) FROM cartel_workers").fetchone()[0]
    print(f"  workers at cartel firms in last conduct year: {n_cw:,}")

    # ── Step 3: Classify movers vs stayers ───────────────────────────────────

    print("Step 3: Classifying movers vs stayers...", flush=True)

    # Find which of these workers appear at a DIFFERENT BEC firm post-conduct
    con.sql(f"""
        CREATE OR REPLACE TABLE post_destinations AS
        SELECT DISTINCT
            r.pis,
            r.cnpj_raiz AS dest_cnpj,
            r.ano AS dest_year
        FROM read_parquet('{rais_glob}') r
        WHERE r.cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND r.pis IN (SELECT pis FROM cartel_workers)
          AND r.pis IS NOT NULL
    """)

    # Movers: workers who appear at a different BEC firm after conduct ends
    con.sql("""
        CREATE OR REPLACE TABLE movers AS
        SELECT DISTINCT cw.pis, cw.cnpj_raiz, cw.setor, cw.end_yr
        FROM cartel_workers cw
        JOIN post_destinations pd ON cw.pis = pd.pis
        WHERE pd.dest_cnpj != cw.cnpj_raiz
          AND pd.dest_year > cw.end_yr
    """)

    # Stayers: workers NOT found at any other BEC firm post-conduct
    con.sql("""
        CREATE OR REPLACE TABLE stayers AS
        SELECT DISTINCT cw.pis, cw.cnpj_raiz, cw.setor, cw.end_yr
        FROM cartel_workers cw
        LEFT JOIN movers m ON cw.pis = m.pis AND cw.cnpj_raiz = m.cnpj_raiz
        WHERE m.pis IS NULL
    """)

    n_movers = con.sql("SELECT count(*) FROM movers").fetchone()[0]
    n_stayers = con.sql("SELECT count(*) FROM stayers").fetchone()[0]
    print(f"  movers: {n_movers:,}  stayers: {n_stayers:,}")

    # ── Step 4: Control movers — non-cartel firms in same markets ────────────

    print("Step 4: Building control movers...", flush=True)

    # Non-cartel BEC firms that bid on the same item codes as cartel firms
    # Take workers at those firms who moved to other BEC firms in same period
    con.sql(f"""
        CREATE OR REPLACE TABLE control_firms AS
        SELECT DISTINCT
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz
        FROM read_parquet('/home/darciogm1/projetos/bitter-pills/paper4-thresholds/02_data/final/df_pregao_with_cartel_flags.parquet')
        WHERE has_any_cartel_firm = 0
    """)

    # Workers at control firms in 2011-2014 (overlapping with cartel end years)
    # who moved to other BEC firms
    con.sql(f"""
        CREATE OR REPLACE TABLE control_workers AS
        SELECT
            r.pis,
            r.cnpj_raiz,
            r.ano AS obs_year,
            r.escolaridade,
            LEFT(r.cbo2002, 1) AS cbo_major,
            TRY_CAST(REPLACE(r.rem_dez_sm, ',', '.') AS DOUBLE) AS wage_sm,
            TRY_CAST(REPLACE(r.tempo_emprego, ',', '.') AS DOUBLE) AS tenure_months,
            r.idade,
            r.sexo
        FROM read_parquet('{rais_glob}') r
        JOIN control_firms cf ON r.cnpj_raiz = cf.cnpj_raiz
        WHERE r.ano BETWEEN 2011 AND 2014
          AND r.pis IS NOT NULL
        USING SAMPLE 10 PERCENT (bernoulli)
    """)

    con.sql(f"""
        CREATE OR REPLACE TABLE control_movers AS
        SELECT DISTINCT cw.pis, cw.cnpj_raiz, cw.obs_year
        FROM control_workers cw
        JOIN (
            SELECT DISTINCT pis, cnpj_raiz, ano
            FROM read_parquet('{rais_glob}')
            WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
              AND pis IN (SELECT pis FROM control_workers)
        ) pd ON cw.pis = pd.pis
        WHERE pd.cnpj_raiz != cw.cnpj_raiz
          AND pd.ano > cw.obs_year AND pd.ano <= cw.obs_year + 3
    """)
    n_ctrl = con.sql("SELECT count(*) FROM control_movers").fetchone()[0]
    print(f"  control movers (10% sample): {n_ctrl:,}")

    # ── Step 5: Compare characteristics ──────────────────────────────────────

    print("Step 5: Computing characteristic comparisons...", flush=True)

    # Cartel movers characteristics
    mover_chars = con.sql("""
        SELECT cw.escolaridade, cw.cbo_major, cw.wage_sm,
               cw.tenure_months, cw.idade, cw.sexo,
               'cartel_mover' AS group_name
        FROM cartel_workers cw
        JOIN movers m ON cw.pis = m.pis AND cw.cnpj_raiz = m.cnpj_raiz
    """).fetchdf()

    # Cartel stayers characteristics
    stayer_chars = con.sql("""
        SELECT cw.escolaridade, cw.cbo_major, cw.wage_sm,
               cw.tenure_months, cw.idade, cw.sexo,
               'cartel_stayer' AS group_name
        FROM cartel_workers cw
        JOIN stayers s ON cw.pis = s.pis AND cw.cnpj_raiz = s.cnpj_raiz
    """).fetchdf()

    # Control movers characteristics
    ctrl_chars = con.sql("""
        SELECT cw.escolaridade, cw.cbo_major, cw.wage_sm,
               cw.tenure_months, cw.idade, cw.sexo,
               'control_mover' AS group_name
        FROM control_workers cw
        JOIN control_movers cm ON cw.pis = cm.pis AND cw.cnpj_raiz = cm.cnpj_raiz
    """).fetchdf()

    all_chars = pd.concat([mover_chars, stayer_chars, ctrl_chars], ignore_index=True)

    # CBO major group labels
    cbo_labels = {
        "0": "Military/unclassified",
        "1": "Directors/managers",
        "2": "Professionals (degree)",
        "3": "Technicians",
        "4": "Admin/clerical",
        "5": "Service/sales",
        "6": "Agriculture",
        "7": "Production/craft",
        "8": "Machine operators",
        "9": "Maintenance/repair",
    }

    # Education labels (RAIS codes)
    edu_labels = {
        1: "Illiterate",
        2: "Primary incomplete",
        3: "Primary complete",
        4: "Lower secondary incomplete",
        5: "Lower secondary complete",
        6: "Upper secondary incomplete",
        7: "Upper secondary complete",
        8: "Tertiary incomplete",
        9: "Tertiary complete",
        10: "Master's",
        11: "Doctorate",
    }

    # ── Step 6: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Worker Characteristics: Who Migrates from Cartel Firms?\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("SAMPLE SIZES\n")
        f.write("-" * 40 + "\n")
        f.write(f"  Cartel movers:   {len(mover_chars):>7,}\n")
        f.write(f"  Cartel stayers:  {len(stayer_chars):>7,}\n")
        f.write(f"  Control movers:  {len(ctrl_chars):>7,}\n\n")

        # Summary statistics by group
        f.write("CONTINUOUS VARIABLES (means)\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'Variable':20s} {'Cartel movers':>14s} {'Cartel stayers':>15s} "
                f"{'Control movers':>15s}\n")
        f.write("-" * 70 + "\n")

        for var in ["wage_sm", "tenure_months", "idade"]:
            means = all_chars.groupby("group_name")[var].mean()
            m = means.get("cartel_mover", np.nan)
            s = means.get("cartel_stayer", np.nan)
            c = means.get("control_mover", np.nan)
            label = {"wage_sm": "Wage (min wages)", "tenure_months": "Tenure (months)",
                     "idade": "Age"}[var]
            f.write(f"{label:20s} {m:>14.2f} {s:>15.2f} {c:>15.2f}\n")
        f.write("\n")

        # Education distribution
        f.write("EDUCATION DISTRIBUTION (%)\n")
        f.write("-" * 70 + "\n")
        for group in ["cartel_mover", "cartel_stayer", "control_mover"]:
            sub = all_chars[all_chars["group_name"] == group]
            edu_dist = sub["escolaridade"].value_counts(normalize=True).sort_index()
            f.write(f"  {group}:\n")
            for code, pct in edu_dist.items():
                label = edu_labels.get(int(code), f"code_{code}")
                if pct > 0.02:  # only show >2%
                    f.write(f"    {label:30s}  {pct*100:>5.1f}%\n")
            f.write("\n")

        # CBO major group distribution
        f.write("OCCUPATION DISTRIBUTION (CBO major group, %)\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'CBO group':30s} {'Cartel movers':>14s} {'Cartel stayers':>15s} "
                f"{'Control movers':>15s}\n")
        f.write("-" * 70 + "\n")

        for cbo_code in sorted(cbo_labels.keys()):
            pcts = []
            for group in ["cartel_mover", "cartel_stayer", "control_mover"]:
                sub = all_chars[all_chars["group_name"] == group]
                total = len(sub)
                n_match = (sub["cbo_major"] == cbo_code).sum()
                pct = n_match / total * 100 if total > 0 else 0
                pcts.append(pct)
            if max(pcts) > 1.0:  # only show >1%
                f.write(f"{cbo_labels[cbo_code]:30s} {pcts[0]:>13.1f}% "
                        f"{pcts[1]:>14.1f}% {pcts[2]:>14.1f}%\n")
        f.write("\n")

        # Gender
        f.write("GENDER (% male)\n")
        f.write("-" * 50 + "\n")
        for group in ["cartel_mover", "cartel_stayer", "control_mover"]:
            sub = all_chars[all_chars["group_name"] == group]
            pct_male = (sub["sexo"] == 1).mean() * 100
            f.write(f"  {group:20s}  {pct_male:.1f}%\n")
        f.write("\n")

        # Key comparison: are managers/directors overrepresented among movers?
        f.write("KEY TEST: Are knowledge-carrying workers overrepresented?\n")
        f.write("-" * 60 + "\n")
        for group in ["cartel_mover", "cartel_stayer", "control_mover"]:
            sub = all_chars[all_chars["group_name"] == group]
            pct_mgr = (sub["cbo_major"].isin(["1", "2"])).mean() * 100
            mean_wage = sub["wage_sm"].mean()
            mean_tenure = sub["tenure_months"].mean()
            f.write(f"  {group:20s}  managers+professionals={pct_mgr:.1f}%  "
                    f"wage={mean_wage:.1f}SM  tenure={mean_tenure:.0f}mo\n")

    print(f"\n[written] {OUT_REPORT}")
    con.close()
    print(f"Total time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
