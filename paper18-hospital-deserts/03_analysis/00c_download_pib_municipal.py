"""
Baixa PIB municipal 2015–2023 da API Sidra (IBGE), tabela 5938.

Variáveis colhidas:
- 37    PIB a preços correntes (Mil R$)            -> pib_corr
- 498   VAB total (Mil R$)                          -> vab_total
- 525   VAB administração + educação + saúde pública (Mil R$) -> vab_admin_publica
- 6575  VAB serviços privados (Mil R$)              -> vab_servicos_priv

API tem limite ~50k registros por request → paginar por (variável × ano).

Saída:
- 02_data/raw/ibge/pib_5938/{var}_{ano}.json (raw API)
- 02_data/intermediate/pib_municipal_2015_2023.parquet (consolidado wide)
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import polars as pl
import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "ibge" / "pib_5938"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
RAW.mkdir(parents=True, exist_ok=True)
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00c_download_pib_municipal.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("pib")

VARS = {
    37: "pib_corr",
    498: "vab_total",
    525: "vab_admin_publica",
    6575: "vab_servicos_priv",
}
YEARS = list(range(2015, 2024))


def fetch_var_year(var_id: int, year: int) -> Path:
    dest = RAW / f"v{var_id}_y{year}.json"
    if dest.exists() and dest.stat().st_size > 1000:
        return dest
    url = f"https://apisidra.ibge.gov.br/values/t/5938/n6/all/v/{var_id}/p/{year}"
    log.info("GET v=%d y=%d", var_id, year)
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    dest.write_bytes(r.content)
    n = len(r.json()) - 1
    log.info("  saved %s (%d records, %.1f KB)", dest.name, n, len(r.content) / 1024)
    return dest


def parse_var_year(path: Path, var_id: int, year: int, alias: str) -> pl.DataFrame:
    raw = json.loads(path.read_text())
    rows = raw[1:]
    out = []
    for r in rows:
        v = r["V"]
        if v in ("...", "-", "X", ".."):
            val = None
        else:
            try:
                val = float(v)
            except ValueError:
                val = None
        out.append({
            "cod_mun": str(r["D1C"]).zfill(7),
            "ano": year,
            alias: val,
        })
    return pl.DataFrame(out)


def main():
    t0 = time.time()
    log.info("==== begin PIB download ====")

    by_var: dict[str, list[pl.DataFrame]] = {alias: [] for alias in VARS.values()}
    for var_id, alias in VARS.items():
        for year in YEARS:
            path = fetch_var_year(var_id, year)
            df = parse_var_year(path, var_id, year, alias)
            by_var[alias].append(df)

    # consolidar: long por variável → join wide
    base = None
    for alias, parts in by_var.items():
        df = pl.concat(parts, how="vertical").sort(["cod_mun", "ano"])
        log.info("var %s: %d rows, missing=%d", alias, len(df), df[alias].is_null().sum())
        if base is None:
            base = df
        else:
            base = base.join(df, on=["cod_mun", "ano"], how="full", coalesce=True)

    # adicionar fonte
    base = base.with_columns(fonte=pl.lit("sidra_5938")).sort(["cod_mun", "ano"])

    out = INTER / "pib_municipal_2015_2023.parquet"
    base.write_parquet(out)
    log.info("wrote %s (rows=%d, cols=%s)", out, len(base), base.columns)

    # sanity
    summary = (
        base.group_by("ano")
        .agg(
            n_mun=pl.len(),
            pib_total_bi=pl.col("pib_corr").sum() / 1e6,  # mil R$ -> bilhões R$
            pib_missing=pl.col("pib_corr").is_null().sum(),
        )
        .sort("ano")
    )
    log.info("\n=== summary ===\n%s", summary)
    log.info("==== done ====")
    log.info("elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
