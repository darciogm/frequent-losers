"""
05_link_rais.py — Link Paper 2 suppliers to RAIS Estabelecimento 2017 (SP).

Input:
  - data/processed/paper2_me_epp.parquet (v3, contains cnpj_fornecedor, cnpj_raiz)
  - ../paper4-thresholds/RAIS/parquet/estb/BR_2017_ESTB.parquet (BR, all UFs)

Output:
  - data/processed/rais_estb_2017_br_by_raiz.parquet  (one row per cnpj_raiz, BR)
  - data/processed/paper2_suppliers_rais_linked.parquet  (distinct suppliers + RAIS)
  - output/tables/diag_rais_link_coverage.txt  (plain-text diagnostics)

Method:
  DuckDB out-of-core. CNPJ raiz = first 8 digits of 14-digit CNPJ.
  RAIS ESTB 2017 aggregated at BR level (no UF filter); an "has_sp_estab" flag
  flags suppliers with at least one establishment in SP (UF=35).
  Per CNPJ raiz aggregate: n_estabs, n_estabs_sp, total_vinculos_ativos,
  max_tamanho, any_simples, oldest_data_abertura, modal_cnae, modal_municipio,
  modal UF.
"""

from __future__ import annotations
import duckdb
import sys
import time
from pathlib import Path

P2      = Path("/home/darciogm1/projetos/bitter-pills/paper2-me-epp")
P4_RAIS = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS/parquet")

P2_PARQ = P2 / "data/processed/paper2_me_epp.parquet"
ESTB_17 = P4_RAIS / "estb/BR_2017_ESTB.parquet"

OUT_DIR       = P2 / "data/processed"
TAB_DIR       = P2 / "output/tables"
RAIS_BR_AGG   = OUT_DIR / "rais_estb_2017_br_by_raiz.parquet"
LINKED        = OUT_DIR / "paper2_suppliers_rais_linked.parquet"
DIAG          = TAB_DIR / "diag_rais_link_coverage.txt"

OUT_DIR.mkdir(parents=True, exist_ok=True)
TAB_DIR.mkdir(parents=True, exist_ok=True)


def main():
    t0 = time.time()
    assert P2_PARQ.exists(), f"missing {P2_PARQ}"
    assert ESTB_17.exists(), f"missing {ESTB_17}"

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    print(f"[1/5] Building BR ESTB 2017 aggregate by CNPJ raiz → {RAIS_BR_AGG.name}")
    con.sql(f"""
        COPY (
            SELECT
                LPAD(CAST("CNPJ Raiz" AS VARCHAR), 8, '0') AS cnpj_raiz,
                COUNT(*)                                   AS n_estab,
                SUM(CASE WHEN UF = 35 THEN 1 ELSE 0 END)   AS n_estab_sp,
                SUM("Qtd Vínculos Ativos")                 AS vinc_ativos_sum,
                SUM(CASE WHEN UF = 35 THEN "Qtd Vínculos Ativos" ELSE 0 END)
                                                           AS vinc_ativos_sp,
                SUM("Qtd Vínculos CLT")                    AS vinc_clt_sum,
                MAX("Tamanho Estabelecimento")             AS tamanho_max,
                MAX(CASE WHEN "Ind Simples" = 1 THEN 1 ELSE 0 END) AS any_simples,
                MIN("Data Abertura")                       AS data_abertura_min,
                MODE() WITHIN GROUP (ORDER BY "CNAE 2.0 Classe") AS cnae20_modal,
                MODE() WITHIN GROUP (ORDER BY "Município")       AS mun_modal,
                MODE() WITHIN GROUP (ORDER BY UF)                AS uf_modal,
                MAX("Natureza Jurídica")                         AS natjur_max
            FROM read_parquet('{ESTB_17}')
            WHERE "CNPJ Raiz" IS NOT NULL
            GROUP BY 1
        ) TO '{RAIS_BR_AGG}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    n_br_raiz = con.sql(
        f"SELECT COUNT(*) AS n FROM read_parquet('{RAIS_BR_AGG}')"
    ).fetchone()[0]
    print(f"      BR CNPJ raízes in RAIS 2017: {n_br_raiz:,}")

    print(f"[2/5] Distinct Paper-2 suppliers with valid CNPJ + linking")
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE p2_suppliers AS
        WITH src AS (
            SELECT
                cnpj_fornecedor,
                CASE WHEN regexp_matches(cnpj_fornecedor, '^[0-9]{{14}}$')
                     THEN substr(cnpj_fornecedor, 1, 8) END AS cnpj_raiz,
                data_oc_numb, fornec_enquad, porte_empresa, uf_forn
            FROM read_parquet('{P2_PARQ}')
            WHERE cnpj_fornecedor IS NOT NULL
        )
        SELECT
            cnpj_raiz,
            MIN(cnpj_fornecedor) AS cnpj_example_14,
            COUNT(*)            AS n_obs_paper2,
            SUM(CASE WHEN data_oc_numb < 698 THEN 1 ELSE 0 END) AS n_pre,
            SUM(CASE WHEN data_oc_numb >= 698 THEN 1 ELSE 0 END) AS n_post,
            MODE() WITHIN GROUP (ORDER BY fornec_enquad) AS fornec_enquad_modal,
            MODE() WITHIN GROUP (ORDER BY porte_empresa) AS porte_empresa_modal,
            MODE() WITHIN GROUP (ORDER BY uf_forn)       AS uf_forn_modal
        FROM src
        WHERE cnpj_raiz IS NOT NULL
        GROUP BY cnpj_raiz
    """)
    n_p2_raiz = con.sql("SELECT COUNT(*) FROM p2_suppliers").fetchone()[0]
    print(f"      Paper-2 distinct CNPJ raízes: {n_p2_raiz:,}")

    print(f"[3/5] Left join + persist → {LINKED.name}")
    con.sql(f"""
        COPY (
            SELECT p.*,
                   r.n_estab,
                   r.n_estab_sp,
                   r.vinc_ativos_sum,
                   r.vinc_ativos_sp,
                   r.vinc_clt_sum,
                   r.tamanho_max,
                   r.any_simples,
                   r.data_abertura_min,
                   r.cnae20_modal,
                   r.mun_modal,
                   r.uf_modal,
                   r.natjur_max,
                   (r.cnpj_raiz IS NOT NULL)                      AS rais_match,
                   (r.cnpj_raiz IS NOT NULL AND r.n_estab_sp > 0) AS has_sp_estab
            FROM p2_suppliers p
            LEFT JOIN read_parquet('{RAIS_BR_AGG}') r USING (cnpj_raiz)
        ) TO '{LINKED}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    print(f"[4/5] Coverage diagnostics → {DIAG.name}")
    cov = con.sql(f"""
        SELECT
            COUNT(*) AS n_sup,
            SUM(CASE WHEN rais_match   THEN 1 ELSE 0 END) AS n_matched_br,
            SUM(CASE WHEN has_sp_estab THEN 1 ELSE 0 END) AS n_matched_sp,
            AVG(CASE WHEN rais_match   THEN 1.0 ELSE 0.0 END) AS share_br,
            AVG(CASE WHEN has_sp_estab THEN 1.0 ELSE 0.0 END) AS share_sp,
            SUM(n_obs_paper2)                                 AS n_obs_total,
            SUM(CASE WHEN rais_match THEN n_obs_paper2 ELSE 0 END) AS n_obs_matched
        FROM read_parquet('{LINKED}')
    """).fetchdf()

    # Cross-tab: Paper-2 enquadramento × RAIS match (BR vs SP-only)
    xtab_match = con.sql(f"""
        SELECT
            fornec_enquad_modal AS fornec_enquad,
            COUNT(*)            AS n_firms,
            SUM(CASE WHEN rais_match   THEN 1 ELSE 0 END) AS n_matched_br,
            SUM(CASE WHEN has_sp_estab THEN 1 ELSE 0 END) AS n_matched_sp,
            AVG(CASE WHEN rais_match   THEN 1.0 ELSE 0.0 END) AS share_br,
            AVG(CASE WHEN has_sp_estab THEN 1.0 ELSE 0.0 END) AS share_sp
        FROM read_parquet('{LINKED}')
        GROUP BY 1 ORDER BY 1
    """).fetchdf()

    xtab_size = con.sql(f"""
        SELECT
            fornec_enquad_modal AS fornec_enquad,
            SUM(CASE WHEN vinc_ativos_sum BETWEEN 0 AND 9   THEN 1 ELSE 0 END) AS micro_0_9,
            SUM(CASE WHEN vinc_ativos_sum BETWEEN 10 AND 49 THEN 1 ELSE 0 END) AS small_10_49,
            SUM(CASE WHEN vinc_ativos_sum BETWEEN 50 AND 99 THEN 1 ELSE 0 END) AS mid_50_99,
            SUM(CASE WHEN vinc_ativos_sum >= 100            THEN 1 ELSE 0 END) AS large_100p,
            SUM(CASE WHEN vinc_ativos_sum IS NULL           THEN 1 ELSE 0 END) AS unmatched,
            SUM(CASE WHEN any_simples = 1                   THEN 1 ELSE 0 END) AS simples_flag
        FROM read_parquet('{LINKED}')
        GROUP BY 1 ORDER BY 1
    """).fetchdf()

    # Newly-matched firms (BR-only, not in SP): where are they?
    newly_by_uf = con.sql(f"""
        SELECT uf_modal AS rais_uf,
               COUNT(*)                              AS n_firms,
               SUM(n_obs_paper2)                     AS n_obs
        FROM read_parquet('{LINKED}')
        WHERE rais_match = TRUE AND has_sp_estab = FALSE
        GROUP BY 1 ORDER BY 2 DESC
        LIMIT 15
    """).fetchdf()

    with open(DIAG, "w") as f:
        f.write("=== Paper 2 ↔ RAIS ESTB 2017 (Brasil) linkage ===\n\n")
        f.write(f"Build time: {time.time()-t0:.1f}s\n")
        f.write(f"BR CNPJ raízes in RAIS 2017: {n_br_raiz:,}\n")
        f.write(f"Paper-2 distinct CNPJ raízes: {n_p2_raiz:,}\n\n")
        f.write("-- Overall coverage (BR vs SP-only) --\n")
        f.write(cov.to_string(index=False) + "\n\n")
        f.write("-- By fornec_enquad: match rate BR vs SP --\n")
        f.write(xtab_match.to_string(index=False) + "\n\n")
        f.write("-- By fornec_enquad × RAIS BR employment bucket --\n")
        f.write(xtab_size.to_string(index=False) + "\n\n")
        f.write("-- Top 15 UFs among firms matched BR-wide but without SP estab --\n")
        f.write(newly_by_uf.to_string(index=False) + "\n")

    print(f"[5/5] Done in {time.time()-t0:.1f}s.  See {DIAG}")
    print("\n" + DIAG.read_text())


if __name__ == "__main__":
    main()
