"""
00d2_patch_cnes_hb.py — recupera os 52 arquivos HB que falharam no script 00d
por causa de campo NULEITOS com bytes corrompidos.

Estratégia: usar dbfread com raw=True para evitar coerção de tipo, depois
sanitizar NULEITOS como string e converter NA quando inválido.
"""

from __future__ import annotations

import logging
import re
import sys
import time
from pathlib import Path

import dbfread
import polars as pl
from pyreaddbc import dbc2dbf

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "cnes_hb"
TMP = RAW / "_dbc_cache"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "00d2_patch_cnes_hb.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("hb-patch")


def parse_one(dbc_path: Path) -> int:
    """Retorna nº linhas escritas no parquet correspondente."""
    # nome do parquet: hb<uf><yymm>.parquet a partir do dbc HB<UF><YYMM>.dbc
    m = re.match(r"^HB([A-Z]{2})(\d{4})\.dbc$", dbc_path.name)
    if not m:
        log.warning("nome inesperado: %s", dbc_path.name)
        return 0
    uf, yymm = m.group(1).lower(), m.group(2)
    pq_path = RAW / f"hb{uf}{yymm}.parquet"
    if pq_path.exists():
        return -1  # já existe

    dbf_path = dbc_path.with_suffix(".dbf")
    try:
        dbc2dbf(str(dbc_path).encode(), str(dbf_path).encode())
        recs_raw = list(dbfread.DBF(str(dbf_path), encoding="latin1", raw=True))
    except Exception as e:
        log.warning("falha decompressão %s: %s", dbc_path.name, e)
        return 0

    cleaned = []
    for r in recs_raw:
        d = {}
        for k, v in r.items():
            if isinstance(v, bytes):
                try:
                    s = v.decode("latin1").strip()
                except Exception:
                    s = ""
                d[k] = s
            else:
                d[k] = v
        # NULEITOS para int (None se inválido)
        nu = d.get("NULEITOS")
        if isinstance(nu, str):
            try:
                d["NULEITOS"] = int(re.sub(r"\D", "", nu)) if nu else None
            except Exception:
                d["NULEITOS"] = None
        cleaned.append(d)

    if not cleaned:
        log.warning("vazio: %s", dbc_path.name)
        return 0

    df = pl.DataFrame(cleaned, infer_schema_length=None)
    df.write_parquet(pq_path, compression="snappy")
    try:
        dbc_path.unlink()
        dbf_path.unlink()
    except Exception:
        pass
    return len(df)


def main():
    t0 = time.time()
    pending = sorted(TMP.glob("HB*.dbc"))
    log.info("retry %d arquivos", len(pending))
    ok = 0
    skip = 0
    for p in pending:
        n = parse_one(p)
        if n > 0:
            ok += 1
        elif n == -1:
            skip += 1
    log.info("ok=%d skip=%d falhou=%d  elapsed %.1fs",
             ok, skip, len(pending) - ok - skip, time.time() - t0)


if __name__ == "__main__":
    main()
