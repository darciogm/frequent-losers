"""
00e_download_cnes_pf.py

Baixa CNES-PF (Profissionais) do FTP DATASUS para 2015-2025, converte
.dbc -> .parquet, e salva em 02_data/raw/cnes_pf/.

PF = vínculo profissional × estabelecimento × competência. Cada profissional
da saúde aparece com CBO, carga horária, vínculo SUS/não-SUS.

Volume: ~25 GB DBC bruto, ~10 GB parquet final (SP/MG/RJ dominam).
Tempo: ~2h com 4 workers (4 conexões FTP + dbfread CPU-bound).

Robustez: fallback automático com raw=True para arquivos com bytes corrompidos
em campos numéricos — evita 2ª passada como precisamos no HB.
"""

from __future__ import annotations

import logging
import os
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import dbfread
import polars as pl
from pyreaddbc import dbc2dbf
from tqdm import tqdm

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "cnes_pf"
TMP = RAW / "_dbc_cache"
LOG = ROOT / "04_logs"
RAW.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00e_download_cnes_pf.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("pf")

UFS = [
    "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA",
    "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN",
    "RO", "RR", "RS", "SC", "SE", "SP", "TO",
]
YEARS = range(2015, 2026)
MONTHS = range(1, 13)
FTP_BASE = "ftp://ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/PF"

# campos numéricos típicos em PF
NUMERIC_INT_FIELDS = {"CARGAHOR", "VINCULAC", "VINCULO_C", "CHCONTR", "CHGESTAO", "CHOUTROS"}


def fname_dbc(uf: str, year: int, month: int) -> str:
    yy = f"{year % 100:02d}"
    return f"PF{uf}{yy}{month:02d}.dbc"


def fname_parquet(uf: str, year: int, month: int) -> str:
    yy = f"{year % 100:02d}"
    return f"pf{uf.lower()}{yy}{month:02d}.parquet"


def parse_clean_records(dbf_path: Path) -> list[dict]:
    """Tenta dbfread regular; se falhar por qualquer motivo, fallback raw=True."""
    try:
        return [dict(r) for r in dbfread.DBF(str(dbf_path), encoding="latin1")]
    except Exception:
        pass
    # fallback: bytes brutos, sanitizar à mão
    cleaned = []
    for r in dbfread.DBF(str(dbf_path), encoding="latin1", raw=True):
        d = {}
        for k, v in r.items():
            if isinstance(v, bytes):
                try:
                    s = v.decode("latin1").strip()
                except Exception:
                    s = ""
                if k in NUMERIC_INT_FIELDS:
                    try:
                        d[k] = int(re.sub(r"\D", "", s)) if s else None
                    except Exception:
                        d[k] = None
                else:
                    d[k] = s
            else:
                d[k] = v
        cleaned.append(d)
    return cleaned


def download_one(uf: str, year: int, month: int) -> tuple[str, str]:
    pq_path = RAW / fname_parquet(uf, year, month)
    if pq_path.exists() and pq_path.stat().st_size > 100:
        return ("cache", pq_path.name)

    dbc_name = fname_dbc(uf, year, month)
    dbc_path = TMP / dbc_name
    url = f"{FTP_BASE}/{dbc_name}"

    if not dbc_path.exists() or dbc_path.stat().st_size < 100:
        try:
            data = urllib.request.urlopen(url, timeout=120).read()
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
        dbc2dbf(str(dbc_path).encode(), str(dbf_path).encode())
        recs = parse_clean_records(dbf_path)
        if not recs:
            return ("empty", dbc_name)
        df = pl.DataFrame(recs, infer_schema_length=None)
        df.write_parquet(pq_path, compression="snappy")
        for p in (dbc_path, dbf_path):
            try:
                p.unlink()
            except Exception:
                pass
        return ("ok", pq_path.name)
    except Exception as e:
        try:
            if dbf_path.exists():
                dbf_path.unlink()
        except Exception:
            pass
        return (f"err_parse:{e}", dbc_name)


def main():
    t0 = time.time()
    targets = [(uf, y, m) for uf in UFS for y in YEARS for m in MONTHS]
    log.info("alvo: %d arquivos -- %d UFs × %d anos × 12 meses",
             len(targets), len(UFS), len(list(YEARS)))
    log.info("workers=4, FTP=%s", FTP_BASE)

    counts: dict[str, int] = {}
    err_log: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(download_one, *t): t for t in targets}
        with tqdm(total=len(futs), desc="PF", ncols=110) as pbar:
            for f in as_completed(futs):
                status, fname = f.result()
                key = "err" if status.startswith("err") else status
                counts[key] = counts.get(key, 0) + 1
                if key == "err":
                    err_log.append((fname, status))
                    if len(err_log) <= 5 or len(err_log) % 50 == 0:
                        log.warning("err #%d %s -> %s", len(err_log), fname, status[:200])
                pbar.update(1)
                pbar.set_postfix(
                    ok=counts.get("ok", 0),
                    cache=counts.get("cache", 0),
                    miss=counts.get("missing", 0),
                    err=counts.get("err", 0),
                )

    log.info("==== summary ====")
    for k, v in sorted(counts.items()):
        log.info("  %s: %d", k, v)
    if err_log:
        log.info("=== sample errors (first 20) ===")
        for fname, status in err_log[:20]:
            log.info("  %s -> %s", fname, status)

    try:
        if not any(TMP.iterdir()):
            TMP.rmdir()
    except OSError:
        pass

    log.info("elapsed %.1fs (%.1fmin)", time.time() - t0, (time.time() - t0) / 60)


if __name__ == "__main__":
    main()
