"""
00d_download_cnes_hb.py

Baixa CNES-HB (Habilitações) do FTP DATASUS para 2015-2025, converte
.dbc -> .parquet, e salva em 02_data/raw/cnes_hb/.

HB = habilitações de alta complexidade por estabelecimento × competência.
Cols esperadas: CNES, CODUFMUN, COMPETEN, NU_HABIL (código), CMPT_INI, CMPT_FIM, etc.

Período: 2015-2025 (paper18 usa 2015-2022 como core; margens p/ event-study).
Volume estimado: ~2 KB cada, 27 UF × 11 anos × 12 meses ≈ 3.500 arquivos.

Stack: requests (FTP via curl-like) + pyreaddbc (DBC -> DataFrame).
Cache: pula se .parquet final já existe.
Paralelo: 4 workers (regras DarcioWork).
"""

from __future__ import annotations

import logging
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import urllib.request
import urllib.error

import dbfread
import polars as pl
from pyreaddbc import dbc2dbf
from tqdm import tqdm

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "cnes_hb"
TMP = ROOT / "02_data" / "raw" / "cnes_hb" / "_dbc_cache"
LOG = ROOT / "04_logs"
RAW.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00d_download_cnes_hb.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("hb")

UFS = [
    "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA",
    "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN",
    "RO", "RR", "RS", "SC", "SE", "SP", "TO",
]

YEARS = range(2015, 2026)  # 2015..2025
MONTHS = range(1, 13)

FTP_BASE = "ftp://ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/HB"


def list_remote_files() -> list[tuple[str, int, int]]:
    """Retorna lista (uf, year, month) que esperamos existir no servidor."""
    return [(uf, y, m) for uf in UFS for y in YEARS for m in MONTHS]


def fname_dbc(uf: str, year: int, month: int) -> str:
    yy = f"{year % 100:02d}"
    return f"HB{uf}{yy}{month:02d}.dbc"


def fname_parquet(uf: str, year: int, month: int) -> str:
    yy = f"{year % 100:02d}"
    return f"hb{uf.lower()}{yy}{month:02d}.parquet"


def download_one(uf: str, year: int, month: int) -> tuple[str, str]:
    """Baixa 1 arquivo .dbc, converte p/ parquet, devolve (status, fname)."""
    pq_path = RAW / fname_parquet(uf, year, month)
    if pq_path.exists() and pq_path.stat().st_size > 100:
        return ("cache", pq_path.name)

    dbc_name = fname_dbc(uf, year, month)
    dbc_path = TMP / dbc_name
    url = f"{FTP_BASE}/{dbc_name}"

    if not dbc_path.exists() or dbc_path.stat().st_size < 100:
        try:
            data = urllib.request.urlopen(url, timeout=60).read()
            if len(data) < 100:
                return ("missing", dbc_name)
            dbc_path.write_bytes(data)
        except urllib.error.URLError as e:
            msg = str(e).lower()
            if "550" in msg or "no such" in msg or "not found" in msg:
                return ("missing", dbc_name)
            return (f"err_dl:{e}", dbc_name)
        except Exception as e:
            return (f"err_dl:{e}", dbc_name)

    dbf_path = dbc_path.with_suffix(".dbf")
    try:
        dbc2dbf(str(dbc_path).encode("utf-8"), str(dbf_path).encode("utf-8"))
        recs = list(dbfread.DBF(str(dbf_path), encoding="latin1"))
        if not recs:
            return ("empty", dbc_name)
        df = pl.DataFrame([dict(r) for r in recs], infer_schema_length=None)
        df.write_parquet(pq_path, compression="snappy")
        # cleanup
        for p in (dbc_path, dbf_path):
            try:
                p.unlink()
            except Exception:
                pass
        return ("ok", pq_path.name)
    except Exception as e:
        # cleanup parcial
        try:
            if dbf_path.exists():
                dbf_path.unlink()
        except Exception:
            pass
        return (f"err_parse:{e}", dbc_name)


def main():
    t0 = time.time()
    targets = list_remote_files()
    log.info("alvo: %d arquivos (UF×ano×mês) -- %d UFs × %d anos × 12 meses",
             len(targets), len(UFS), len(list(YEARS)))

    counts = {"ok": 0, "cache": 0, "missing": 0, "empty": 0, "err": 0}
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(download_one, uf, y, m): (uf, y, m) for (uf, y, m) in targets}
        with tqdm(total=len(futs), desc="HB", ncols=100) as pbar:
            for f in as_completed(futs):
                status, fname = f.result()
                if status.startswith("err"):
                    counts["err"] += 1
                    if counts["err"] <= 5:
                        log.warning("%s -> %s", fname, status)
                else:
                    counts[status] = counts.get(status, 0) + 1
                pbar.update(1)
                pbar.set_postfix(ok=counts["ok"], cache=counts["cache"],
                                 miss=counts["missing"], err=counts["err"])

    log.info("==== summary ====")
    for k, v in counts.items():
        log.info("  %s: %d", k, v)
    log.info("elapsed %.1fs", time.time() - t0)

    # cleanup tmp dir if empty
    try:
        if not any(TMP.iterdir()):
            TMP.rmdir()
    except OSError:
        pass


if __name__ == "__main__":
    main()
