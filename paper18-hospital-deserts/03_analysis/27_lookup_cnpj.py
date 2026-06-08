"""
27_lookup_cnpj.py

Etapa 2 do R1: lookup CNPJ → razão social, nome fantasia, situação cadastral
e CNAE via BrasilAPI (https://brasilapi.com.br/docs#tag/CNPJ).

API pública gratuita, rate limit free ~3 req/min — usamos 1 req/seg conservador.
Cache em sqlite para idempotência (não bate API se já tem resposta válida).

Variável extra de bandeira: situacao_cadastral.
- "BAIXADA" / "EXTINTA" / "INAPTA" → sinal forte de fechamento real
- "ATIVA" → CNPJ ainda existe (pode ser CNPJ matriz com filial fechada)
- "SUSPENSA" → ambiguidade

Output: 02_data/intermediate/closures_metadata_with_cnpj.parquet
  schema: + razao_social, nome_fantasia, cnae_descr, situacao_cadastral,
            data_situacao, motivo_situacao, municipio_cnpj, uf_cnpj,
            api_status (success/failed/cached), api_timestamp
"""

from __future__ import annotations

import argparse
import json
import logging
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import polars as pl
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
CACHE = ROOT / "02_data" / "intermediate" / "cnpj_cache.sqlite"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "27_lookup_cnpj.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("cnpj")

IN_FILE = INTER / "closures_metadata.parquet"
OUT_FILE = INTER / "closures_metadata_with_cnpj.parquet"

API_URL = "https://brasilapi.com.br/api/cnpj/v1/{}"
SLEEP_BETWEEN_CALLS = 1.0  # 1 req/seg
RETRY_ATTEMPTS = 2
TIMEOUT = 10


def init_cache():
    con = sqlite3.connect(CACHE)
    con.execute("""
        CREATE TABLE IF NOT EXISTS cnpj_cache (
            cnpj TEXT PRIMARY KEY,
            timestamp_utc TEXT,
            status TEXT,
            payload_json TEXT
        )
    """)
    con.commit()
    return con


def cache_get(con, cnpj):
    cur = con.execute("SELECT status, payload_json FROM cnpj_cache WHERE cnpj = ?", (cnpj,))
    row = cur.fetchone()
    if row:
        return row[0], json.loads(row[1]) if row[1] else None
    return None, None


def cache_put(con, cnpj, status, payload):
    con.execute(
        "INSERT OR REPLACE INTO cnpj_cache (cnpj, timestamp_utc, status, payload_json) VALUES (?, ?, ?, ?)",
        (cnpj, datetime.now(timezone.utc).isoformat(),
         status, json.dumps(payload) if payload is not None else None)
    )
    con.commit()


def fetch_brasilapi(cnpj):
    """Fetch CNPJ data from BrasilAPI. Returns (status, payload).

    status ∈ {"success", "not_found", "invalid", "rate_limited", "error"}.
    """
    url = API_URL.format(cnpj)
    req = urllib.request.Request(url, headers={"User-Agent": "paper18-research/1.0"})
    for attempt in range(RETRY_ATTEMPTS):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                if resp.status == 200:
                    return "success", json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="ignore")
            try:
                err = json.loads(body)
                if "inválido" in err.get("message", "").lower():
                    return "invalid", err
                if e.code == 404:
                    return "not_found", err
            except Exception:
                pass
            if e.code == 429:
                if attempt < RETRY_ATTEMPTS - 1:
                    time.sleep(15)
                    continue
                return "rate_limited", {"error": body}
            return "error", {"http_code": e.code, "body": body}
        except urllib.error.URLError as e:
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(3)
                continue
            return "error", {"url_error": str(e)}
        except Exception as e:
            return "error", {"exception": str(e)}
    return "error", {"reason": "exhausted retries"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="reprocessa todos (ignora cache de output)")
    ap.add_argument("--no-api", action="store_true",
                    help="não bate API; usa só cache existente")
    args = ap.parse_args()

    t0 = time.time()
    log.info("==== begin CNPJ lookup ====")

    df_in = pl.read_parquet(IN_FILE)
    log.info("closures alvo: %d", len(df_in))

    cache_con = init_cache()

    rows_out = []
    n_api_calls = 0
    n_cache_hits = 0
    n_no_cnpj = 0
    n_invalid = 0

    for i, r in enumerate(df_in.iter_rows(named=True)):
        cnpj = r.get("cnpj_best")
        rec = dict(r)

        if cnpj is None or cnpj == "":
            rec.update({
                "razao_social": None, "nome_fantasia": None,
                "cnae_descr": None, "situacao_cadastral": None,
                "data_situacao": None, "motivo_situacao": None,
                "municipio_cnpj": None, "uf_cnpj": None,
                "api_status": "no_cnpj", "api_timestamp": None,
            })
            n_no_cnpj += 1
            rows_out.append(rec)
            continue

        # cache lookup
        status, payload = cache_get(cache_con, cnpj)
        if status is not None:
            n_cache_hits += 1
        elif args.no_api:
            log.warning("[%d/%d] CNES=%s sem cache e --no-api ativo, pulando",
                        i + 1, len(df_in), r["CNES"])
            rec.update({
                "razao_social": None, "nome_fantasia": None,
                "cnae_descr": None, "situacao_cadastral": None,
                "data_situacao": None, "motivo_situacao": None,
                "municipio_cnpj": None, "uf_cnpj": None,
                "api_status": "skipped", "api_timestamp": None,
            })
            rows_out.append(rec)
            continue
        else:
            log.info("[%d/%d] querying CNPJ %s (CNES %s, %s/%s)",
                     i + 1, len(df_in), cnpj, r["CNES"],
                     r.get("codmun_hosp_name"), r.get("uf"))
            status, payload = fetch_brasilapi(cnpj)
            cache_put(cache_con, cnpj, status, payload)
            n_api_calls += 1
            time.sleep(SLEEP_BETWEEN_CALLS)

        if status == "success" and payload:
            rec.update({
                "razao_social":       payload.get("razao_social"),
                "nome_fantasia":      payload.get("nome_fantasia"),
                "cnae_descr":         payload.get("cnae_fiscal_descricao"),
                "situacao_cadastral": payload.get("descricao_situacao_cadastral"),
                "data_situacao":      payload.get("data_situacao_cadastral"),
                "motivo_situacao":    payload.get("descricao_motivo_situacao_cadastral"),
                "municipio_cnpj":     payload.get("municipio"),
                "uf_cnpj":            payload.get("uf"),
                "api_status":         "success",
                "api_timestamp":      datetime.now(timezone.utc).isoformat(),
            })
        else:
            rec.update({
                "razao_social": None, "nome_fantasia": None,
                "cnae_descr": None, "situacao_cadastral": None,
                "data_situacao": None, "motivo_situacao": None,
                "municipio_cnpj": None, "uf_cnpj": None,
                "api_status":   status,
                "api_timestamp": datetime.now(timezone.utc).isoformat(),
            })
            if status == "invalid":
                n_invalid += 1
        rows_out.append(rec)

    log.info("API calls: %d  cache hits: %d  no_cnpj: %d  invalid: %d",
             n_api_calls, n_cache_hits, n_no_cnpj, n_invalid)

    df_out = pl.DataFrame(rows_out)
    df_out.write_parquet(OUT_FILE, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT_FILE, len(df_out))

    # ---- summaries ----
    log.info("\n=== api_status × status ===")
    log.info("\n%s", df_out.group_by(["status", "api_status"])
             .agg(pl.len().alias("n"))
             .sort(["status", "api_status"]))

    log.info("\n=== situacao_cadastral × tp_unid (apenas success) ===")
    log.info("\n%s", df_out.filter(pl.col("api_status") == "success")
             .group_by(["situacao_cadastral", "tp_unid"])
             .agg(pl.len().alias("n"))
             .sort(["situacao_cadastral", "tp_unid"]))

    log.info("\n=== amostra (5 com fantasia preenchida) ===")
    log.info("\n%s", df_out.filter(pl.col("nome_fantasia").is_not_null()
                                    & (pl.col("nome_fantasia") != ""))
             .select(["CNES", "year_closure", "razao_social",
                      "nome_fantasia", "situacao_cadastral",
                      "codmun_hosp_name", "uf", "tp_unid", "status"])
             .head(5))

    log.info("==== done ==== elapsed %.1fs (%.0fmin)",
             time.time() - t0, (time.time() - t0) / 60)


if __name__ == "__main__":
    main()
