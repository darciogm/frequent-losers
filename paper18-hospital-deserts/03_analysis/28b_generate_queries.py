"""
28b_generate_queries.py

Etapa 3.5 do R1 (R1-α+β): para cada closure-alvo, gerar 2 queries de
WebSearch estruturadas que vão ser executadas pelo agent (Claude Code) e
cujos snippets vão alimentar o classificador Sonnet em 28d.

Estratégia de queries — duas por closure, ranqueadas por especificidade:

  Q1 (primária): "<razao_social ou nome_fantasia>" "<município>" <UF> hospital <ano>
                  (se razão social ou fantasia disponível)
                  fallback: "CNES <numero>" "<município>" <UF> hospital <ano>

  Q2 (motivo): "<razão_social>" <município> (falência OR descredencia OR fechou OR encerrou)
                  fallback: hospital "<município>" <UF> fechou <ano>

Output: 02_data/intermediate/queries_to_run.parquet
  schema: query_id (int), CNES, query_rank (1 ou 2), query_text, search_status
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "28b_generate_queries.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("queries")

IN_FILE = INTER / "closures_metadata_with_cnpj.parquet"
OUT_FILE = INTER / "queries_to_run.parquet"


def safe(s):
    if s is None or s == "":
        return None
    s = s.strip()
    return s if s else None


def make_q1(rec):
    """Query primária: identidade + localização."""
    name = safe(rec.get("nome_fantasia")) or safe(rec.get("razao_social"))
    municipio = safe(rec.get("codmun_hosp_name"))
    uf = safe(rec.get("uf"))
    year = rec.get("year_closure")

    if name and municipio:
        return f'"{name}" {municipio} {uf or ""} hospital {year}'
    if municipio and rec.get("CNES"):
        return f'CNES {rec["CNES"]} hospital {municipio} {uf or ""} {year}'
    return None


def make_q2(rec):
    """Query secundária: motivo do fechamento."""
    name = safe(rec.get("nome_fantasia")) or safe(rec.get("razao_social"))
    municipio = safe(rec.get("codmun_hosp_name"))
    uf = safe(rec.get("uf"))
    year = rec.get("year_closure")

    if name:
        return f'"{name}" {municipio or ""} (falência OR descredenciado OR fechou OR encerrou OR baixada)'
    if municipio:
        return f'hospital "{municipio}" {uf or ""} fechou {year}'
    return None


def main():
    t0 = time.time()
    log.info("==== begin queries generation ====")

    df = pl.read_parquet(IN_FILE)
    log.info("closures alvo: %d", len(df))

    rows = []
    qid = 0
    for r in df.iter_rows(named=True):
        for rank, qfn in [(1, make_q1), (2, make_q2)]:
            q = qfn(r)
            if q:
                qid += 1
                rows.append({
                    "query_id": qid,
                    "CNES": r["CNES"],
                    "year_closure": r["year_closure"],
                    "codmun_hosp_name": r.get("codmun_hosp_name"),
                    "uf": r.get("uf"),
                    "razao_social": r.get("razao_social"),
                    "nome_fantasia": r.get("nome_fantasia"),
                    "query_rank": rank,
                    "query_text": q,
                    "search_status": "pending",
                })

    df_out = pl.DataFrame(rows)
    df_out.write_parquet(OUT_FILE, compression="snappy")
    log.info("queries geradas: %d (sobre %d closures)", len(df_out),
             df_out["CNES"].n_unique())
    log.info("wrote %s", OUT_FILE)

    log.info("\n=== amostra (primeiras 6) ===")
    log.info("\n%s", df_out.head(6))

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
