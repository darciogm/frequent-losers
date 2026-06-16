"""
00_download_census_age_structure.py

Baixa a estrutura etária municipal do Censo 2022 (IBGE SIDRA tabela 9514,
variável 93 = população residente, classificação c287 = idade) em faixas
quinquenais 0–74, para todos os municípios. Usado como denominador por idade
na padronização indireta de mortalidade evitável (script 04).

Por que só <75: mortalidade evitável (Nolte-McKee) tem cap padrão <75 anos.

Por que o Censo 2022 (estrutura constante na janela): SIDRA/DATASUS não dá pop
municipal por faixa etária por ano de forma estável e gratuita; a COMPOSIÇÃO
etária municipal é razoavelmente estável em 7 anos, e combinada com os totais
anuais reais (pop_municipal) recupera pop_faixa_ano. Aproximação documentada.

Output:
  02_data/processed/census2022_age_structure.parquet
    codmun_6, age_band, pop_band  (15 faixas 0-74 por município)
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
import urllib.request
from pathlib import Path

import duckdb
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
PROC.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "00_download_census_age_structure.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("census_age")

# c287 código -> faixa quinquenal (0-74)
BANDS = {
    "93070": "00-04", "93084": "05-09", "93085": "10-14", "93086": "15-19",
    "93087": "20-24", "93088": "25-29", "93089": "30-34", "93090": "35-39",
    "93091": "40-44", "93092": "45-49", "93093": "50-54", "93094": "55-59",
    "93095": "60-64", "93096": "65-69", "93097": "70-74",
}
UFS = [11, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 26, 27, 28, 29,
       31, 32, 33, 35, 41, 42, 43, 50, 51, 52, 53]

OUT = PROC / "census2022_age_structure.parquet"


def fetch_uf(uf: int, codes: str) -> list[dict]:
    url = (
        f"https://apisidra.ibge.gov.br/values/t/9514/n6/in%20n3%20{uf}"
        f"/v/93/p/2022/c287/{codes}/c2/0"
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=90) as r:
                data = json.load(r)
            return data[1:]  # drop header row
        except Exception as e:  # noqa: BLE001
            log.warning("UF %s tentativa %d falhou: %s", uf, attempt + 1, e)
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(f"UF {uf} falhou após 4 tentativas")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if OUT.exists() and not args.force:
        log.info("output já existe (%s) — use --force", OUT.name)
        return

    t0 = time.perf_counter()
    log.info("==== download census 2022 age structure (SIDRA 9514) ====")
    codes = ",".join(BANDS.keys())
    rows: list[dict] = []
    for uf in UFS:
        recs = fetch_uf(uf, codes)
        for rec in recs:
            v = rec.get("V")
            if v in (None, "...", "-", "X"):  # SIDRA sentinelas de vazio
                v = 0
            rows.append({
                "codmun_6": rec["D1C"][:6],
                "age_band": BANDS[rec["D4C"]],
                "pop_band": int(float(v)),
            })
        log.info("UF %s: %d registros (acum=%d)", uf, len(recs), len(rows))

    df = pl.DataFrame(rows)
    n_mun = df["codmun_6"].n_unique()
    log.info("municípios=%d faixas=%d linhas=%d", n_mun, df["age_band"].n_unique(), len(df))

    con = duckdb.connect()
    con.register("df", df.to_arrow())
    con.execute(
        f"COPY (SELECT codmun_6, age_band, pop_band FROM df ORDER BY codmun_6, age_band) "
        f"TO '{OUT.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')"
    )
    log.info("output: %s | %.1fs", OUT.name, time.perf_counter() - t0)


if __name__ == "__main__":
    main()
