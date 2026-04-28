"""
Consolida pop municipal 2015–2025 em um único parquet.

Fontes:
- 02_data/raw/ibge/populacao_estimada_6579_2010_2021.json  (Sidra t6579, 2010-2021)
- 02_data/raw/ibge/pop_municipal_2022_2025.parquet         (script 00; 2022 Censo, 2023 interp, 2024-25 DOU)

Saída:
- 02_data/intermediate/pop_municipal_2015_2025.parquet
  Schema: cod_mun (str7), nome_mun, ano (int), pop (int), fonte, interpolated (bool)
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import polars as pl

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "ibge"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00b_consolidate_pop_panel.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("pop")


def load_2010_2021() -> pl.DataFrame:
    src = RAW / "populacao_estimada_6579_2010_2021.json"
    raw = json.loads(src.read_text())
    rows = raw[1:]
    df = pl.DataFrame(
        [
            {
                "cod_mun": r["D1C"],
                "nome_mun": r["D1N"],
                "ano": int(r["D3C"]),
                "pop": int(r["V"]) if r["V"] not in ("...", "-", "X", "") else None,
                "fonte": f"sidra_6579_{r['D3C']}",
                "interpolated": False,
            }
            for r in rows
        ]
    )
    log.info("loaded 2010–2021 series: %d rows, anos=%s", len(df), sorted(df["ano"].unique().to_list()))
    return df


def load_2022_2025() -> pl.DataFrame:
    src = RAW / "pop_municipal_2022_2025.parquet"
    df = pl.read_parquet(src)
    log.info("loaded 2022–2025 series: %d rows, anos=%s", len(df), sorted(df["ano"].unique().to_list()))
    return df


def main():
    df_a = load_2010_2021()
    df_b = load_2022_2025()

    # codmun de 7 dígitos: 2010-2021 está em 7 dígitos; 2022-2025 está em 7 dígitos
    # padronizar como string com zero-pad
    df_a = df_a.with_columns(cod_mun=pl.col("cod_mun").cast(pl.Utf8).str.zfill(7))
    df_b = df_b.with_columns(cod_mun=pl.col("cod_mun").cast(pl.Utf8).str.zfill(7))
    df_a = df_a.with_columns(ano=pl.col("ano").cast(pl.Int32))
    df_b = df_b.with_columns(ano=pl.col("ano").cast(pl.Int32))

    full = (
        pl.concat([df_a, df_b], how="diagonal_relaxed")
        .filter(pl.col("ano") >= 2015)
        .sort(["cod_mun", "ano"])
    )
    out = INTER / "pop_municipal_2015_2025.parquet"
    full.write_parquet(out)

    summary = (
        full.group_by("ano")
        .agg(
            n_mun=pl.len(),
            pop_total=pl.col("pop").sum(),
            pop_missing=pl.col("pop").is_null().sum(),
            interp=pl.col("interpolated").sum(),
        )
        .sort("ano")
    )
    log.info("\n=== summary ===\n%s", summary)
    log.info("wrote %s (rows=%d)", out, len(full))


if __name__ == "__main__":
    t0 = time.time()
    main()
    log.info("elapsed %.1fs", time.time() - t0)
