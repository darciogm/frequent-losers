"""
Baixa população municipal 2022, 2023, 2024 (e bônus 2025).
- 2022: Censo 2022 (contagem real), API Sidra tabela 4709, variável 93.
- 2024: estimativa TCU-validada (DOU), FTP IBGE.
- 2025: estimativa TCU-validada (DOU), FTP IBGE.
- 2023: interpolação linear 2022 ↔ 2024 (IBGE não publicou; flag interpolated=True).

Saída:
- 02_data/raw/ibge/pop_2022_censo.json (raw API)
- 02_data/raw/ibge/estimativa_dou_2024.xls (raw FTP)
- 02_data/raw/ibge/estimativa_dou_2025.xls (raw FTP)
- 02_data/raw/ibge/pop_municipal_2022_2025.parquet (consolidado)
"""

from __future__ import annotations

import json
import logging
import sys
import time
from io import BytesIO
from pathlib import Path

import polars as pl
import requests
from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "ibge"
LOG = ROOT / "04_logs"
RAW.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00_download_pop_2022_2024.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("pop")


def fetch_url(url: str, dest: Path, *, force: bool = False, timeout: int = 120) -> Path:
    if dest.exists() and not force:
        log.info("cache hit %s (%.1f KB)", dest.name, dest.stat().st_size / 1024)
        return dest
    log.info("GET %s", url)
    r = requests.get(url, timeout=timeout)
    r.raise_for_status()
    dest.write_bytes(r.content)
    log.info("saved %s (%.1f KB)", dest.name, len(r.content) / 1024)
    return dest


def parse_censo_2022(path: Path) -> pl.DataFrame:
    """Tabela 4709, variável 93 (População residente)."""
    raw = json.loads(path.read_text())
    rows = raw[1:]  # header é o índice 0
    df = pl.DataFrame(
        [
            {
                "cod_mun": r["D1C"],
                "nome_mun": r["D1N"],
                "ano": int(r["D3C"]),
                "pop": int(r["V"]) if r["V"] not in ("...", "-", "X") else None,
                "fonte": "censo_2022",
                "interpolated": False,
            }
            for r in rows
        ]
    )
    return df


def fetch_dou_xls(year: int) -> Path:
    url = f"https://ftp.ibge.gov.br/Estimativas_de_Populacao/Estimativas_{year}/estimativa_dou_{year}.xls"
    dest = RAW / f"estimativa_dou_{year}.xls"
    fetch_url(url, dest, timeout=120)
    return dest


def parse_dou_xls(path: Path, year: int) -> pl.DataFrame:
    """Lê aba 'MUNICÍPIOS' do XLS DOU. Estrutura: cabeçalho a partir da linha 2,
    colunas UF, COD_UF, COD_MUN, NOME_MUNICIPIO, POP_ESTIMADA. O layout varia por
    ano; resolvemos lendo dinamicamente."""
    # Para .xls antigo (BIFF), openpyxl não funciona — usar xlrd.
    import xlrd

    book = xlrd.open_workbook(str(path))
    sheet_names = book.sheet_names()
    log.info("xls %s sheets: %s", path.name, sheet_names)
    target = next((s for s in sheet_names if "munic" in s.lower()), sheet_names[0])
    sheet = book.sheet_by_name(target)

    # heurística: encontrar linha de header procurando 'COD' ou 'UF'
    header_row = None
    for i in range(min(10, sheet.nrows)):
        row_vals = [str(c.value).strip().upper() for c in sheet.row(i)]
        if "UF" in row_vals and any("COD" in v for v in row_vals):
            header_row = i
            break
    if header_row is None:
        header_row = 1
    header = [str(c.value).strip() for c in sheet.row(header_row)]
    log.info("header_row=%d cols=%s", header_row, header)

    # mapping flexível
    col_uf = next(i for i, h in enumerate(header) if h.upper() == "UF")
    col_cod_uf = next(i for i, h in enumerate(header) if "COD" in h.upper() and "UF" in h.upper())
    col_cod_mun = next(i for i, h in enumerate(header) if "COD" in h.upper() and ("MUNI" in h.upper() or "MUN" in h.upper()))
    col_nome = next(i for i, h in enumerate(header) if "NOME" in h.upper() and "MUN" in h.upper())
    col_pop = next(
        i
        for i, h in enumerate(header)
        if "POP" in h.upper() and ("ESTIM" in h.upper() or "RESID" in h.upper())
    )

    records = []
    for r in range(header_row + 1, sheet.nrows):
        row = sheet.row(r)
        cod_uf_v = row[col_cod_uf].value
        cod_mun_v = row[col_cod_mun].value
        pop_v = row[col_pop].value
        if cod_uf_v in ("", None) or cod_mun_v in ("", None):
            continue
        cod_mun = f"{int(cod_uf_v):02d}{int(cod_mun_v):05d}"
        # pop pode vir como "1.234.567" string ou int direto
        if isinstance(pop_v, str):
            pop_v = pop_v.replace(".", "").replace(",", "").strip()
            pop_v = int(pop_v) if pop_v.isdigit() else None
        else:
            pop_v = int(pop_v) if pop_v not in (None, "") else None
        records.append(
            {
                "cod_mun": cod_mun,
                "nome_mun": str(row[col_nome].value).strip(),
                "ano": year,
                "pop": pop_v,
                "fonte": f"dou_{year}",
                "interpolated": False,
            }
        )
    df = pl.DataFrame(records)
    log.info("parsed %s: %d rows", path.name, len(df))
    return df


def interpolate_2023(df_2022: pl.DataFrame, df_2024: pl.DataFrame) -> pl.DataFrame:
    j = (
        df_2022.select(["cod_mun", "nome_mun", pl.col("pop").alias("pop_2022")])
        .join(
            df_2024.select(["cod_mun", pl.col("pop").alias("pop_2024")]),
            on="cod_mun",
            how="inner",
        )
        .with_columns(
            pop=((pl.col("pop_2022") + pl.col("pop_2024")) / 2).round().cast(pl.Int64),
            ano=pl.lit(2023, dtype=pl.Int32),
            fonte=pl.lit("interp_2022_2024"),
            interpolated=pl.lit(True),
        )
        .select(["cod_mun", "nome_mun", "ano", "pop", "fonte", "interpolated"])
    )
    log.info("interpolated 2023: %d municipalities", len(j))
    return j


def main():
    log.info("==== begin pop download ====")

    # ---- 2022 ----
    censo_dest = RAW / "pop_2022_censo.json"
    fetch_url(
        "https://apisidra.ibge.gov.br/values/t/4709/n6/all/v/93/p/2022",
        censo_dest,
    )
    df_2022 = parse_censo_2022(censo_dest)
    log.info("2022 (Censo): %d municípios, pop_total=%s", len(df_2022), df_2022["pop"].sum())

    # ---- 2024 ----
    dest_2024 = fetch_dou_xls(2024)
    df_2024 = parse_dou_xls(dest_2024, 2024)
    log.info("2024 (DOU): %d municípios, pop_total=%s", len(df_2024), df_2024["pop"].sum())

    # ---- 2025 (bônus) ----
    df_2025 = pl.DataFrame()
    try:
        dest_2025 = fetch_dou_xls(2025)
        df_2025 = parse_dou_xls(dest_2025, 2025)
        log.info("2025 (DOU): %d municípios, pop_total=%s", len(df_2025), df_2025["pop"].sum())
    except Exception as e:
        log.warning("2025 falhou (segue sem): %s", e)

    # ---- 2023 (interpolado) ----
    df_2023 = interpolate_2023(df_2022, df_2024)

    # ---- consolidar ----
    parts = [df_2022, df_2023, df_2024]
    if not df_2025.is_empty():
        parts.append(df_2025)
    consolidated = pl.concat(parts, how="diagonal_relaxed").sort(["cod_mun", "ano"])
    out = RAW / "pop_municipal_2022_2025.parquet"
    consolidated.write_parquet(out)
    log.info("wrote %s (rows=%d)", out, len(consolidated))

    # sanity check
    log.info("\n=== sanity ===")
    summary = consolidated.group_by("ano").agg(
        n_mun=pl.len(),
        pop_total=pl.col("pop").sum(),
        pop_missing=pl.col("pop").is_null().sum(),
    ).sort("ano")
    log.info("\n%s", summary)
    log.info("==== done ====")


if __name__ == "__main__":
    t0 = time.time()
    main()
    log.info("elapsed %.1fs", time.time() - t0)
