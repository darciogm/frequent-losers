"""
26_extract_closure_metadata.py

Etapa 1 do R1 (NLP de motivos de fechamento): extrai metadata textual e
estrutural para cada closure-alvo, preparando o dataset que o lookup CNPJ
(27) e o classificador LLM (28) vão consumir.

Closures-alvo:
- F5_survivors: 60 closures que passaram em todos os filtros do S1.
- F5_recovery_candidates: closures que passaram F1-F4 mas falharam em F5
  (queda de admissões >50% no ano pré). Estes podem ter motivo
  administrativo/fiscal mascarado por queda de demanda decorrente da causa
  de fechamento (ex.: hospital com problema financeiro tem queda de demanda
  *porque* já está perdendo pacientes pré-fechamento).

Para cada closure alvo, output:
  CNES, year_closure, codmun_hosp, codmun_hosp_name, uf, tp_unid,
  qt_sus_pre, n_int_t_minus_1, ratio_pre,
  cnpj_best (se houver),
  status: 'F5_survivor' | 'F5_recovery_candidate'

CNPJ é o "mais próximo do ano de fechamento" (idealmente do ano pré),
não-zerado. Closures sem CNPJ (~16/60) terão null e cairão no fallback
de web search direto via CNES+município+ano.

Output: 02_data/intermediate/closures_metadata.parquet
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_ST = ROOT / "02_data" / "raw" / "cnes_st"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "26_extract_closure_metadata.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("clo_meta")

CLO_IN = INTER / "hospital_closures_exogenous.parquet"
CENT_IN = INTER / "municipios_centroids.parquet"
OUT = INTER / "closures_metadata.parquet"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin closure metadata ====")

    files = sorted(RAW_ST.glob("*.parquet"))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("CNES-ST files: %d", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")

    # ---- montar set de candidates (F5_survivor + F5_recovery_candidate) ----
    log.info("[1/4] montando candidates (F5_survivor + recovery)...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE candidates AS
        SELECT
            CNES,
            codmun_6 AS codmun_hosp,
            year_closure,
            tp_unid,
            qt_sus_pre,
            n_int_t_minus_1,
            ratio_pre,
            CASE
              WHEN exogenous = TRUE
                  THEN 'F5_survivor'
              WHEN f1_window AND f2_type AND f3_beds AND f4_mass
                   AND (NOT f5_not_demand_driven OR ratio_pre IS NULL)
                  THEN 'F5_recovery_candidate'
              ELSE NULL
            END AS status
        FROM read_parquet('{CLO_IN}')
    """)
    n_surv = con.sql("SELECT COUNT(*) FROM candidates WHERE status = 'F5_survivor'").fetchone()[0]
    n_rec = con.sql("SELECT COUNT(*) FROM candidates WHERE status = 'F5_recovery_candidate'").fetchone()[0]
    log.info("    F5_survivors: %d", n_surv)
    log.info("    F5_recovery_candidates: %d", n_rec)

    # ---- nome do município + UF (do centroides parquet) ----
    log.info("[2/4] juntando nome do município + UF...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE muns AS
        SELECT cod_mun_6 AS codmun_hosp, nome_mun, uf
        FROM read_parquet('{CENT_IN}')
    """)

    # ---- CNPJ-best por CNES ----
    log.info("[3/4] localizando CNPJ válido mais próximo do year_closure...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE cnes_text AS
        SELECT
            CNES,
            CPF_CNPJ,
            CAST(SUBSTR(COMPETEN, 1, 4) AS INTEGER) AS year_data
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE CPF_CNPJ IS NOT NULL
          AND LENGTH(TRIM(CPF_CNPJ)) = 14
          AND CPF_CNPJ != '00000000000000'
    """)
    n_text = con.sql("SELECT COUNT(*) FROM cnes_text").fetchone()[0]
    log.info("    cnes_text rows (CNPJ válido): %s", f"{n_text:,}")

    # ---- combinar ----
    log.info("[4/4] gerando output...")
    con.execute(f"""
        COPY (
            SELECT
                c.CNES,
                c.year_closure,
                c.codmun_hosp,
                m.nome_mun           AS codmun_hosp_name,
                m.uf                 AS uf,
                c.tp_unid,
                c.qt_sus_pre,
                c.n_int_t_minus_1,
                c.ratio_pre,
                c.status,
                (
                  SELECT CT.CPF_CNPJ
                  FROM cnes_text CT
                  WHERE CT.CNES = c.CNES
                  ORDER BY ABS(CT.year_data - c.year_closure)
                  LIMIT 1
                ) AS cnpj_best,
                (
                  SELECT MAX(CT.year_data)
                  FROM cnes_text CT
                  WHERE CT.CNES = c.CNES
                ) AS cnpj_year_max
            FROM candidates c
            LEFT JOIN muns m USING (codmun_hosp)
            WHERE c.status IS NOT NULL
            ORDER BY c.status, c.year_closure, c.CNES
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_out = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT}')").fetchone()[0]
    log.info("rows escritas: %d", n_out)

    # sumarios
    log.info("\n=== output by status × cnpj availability ===")
    df = con.sql(f"""
        SELECT status,
               COUNT(*) AS n,
               SUM(CASE WHEN cnpj_best IS NOT NULL THEN 1 ELSE 0 END) AS n_with_cnpj,
               SUM(CASE WHEN cnpj_best IS NULL THEN 1 ELSE 0 END) AS n_no_cnpj
        FROM read_parquet('{OUT}')
        GROUP BY status
    """).pl()
    log.info("\n%s", df)

    log.info("\n=== output by tp_unid ===")
    df = con.sql(f"""
        SELECT tp_unid, status,
               COUNT(*) AS n
        FROM read_parquet('{OUT}')
        GROUP BY tp_unid, status
        ORDER BY tp_unid, status
    """).pl()
    log.info("\n%s", df)

    log.info("\n=== amostra de 5 registros ===")
    df = con.sql(f"""
        SELECT CNES, year_closure, codmun_hosp_name, uf, tp_unid, status,
               cnpj_best, ratio_pre
        FROM read_parquet('{OUT}')
        LIMIT 5
    """).pl()
    log.info("\n%s", df)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
