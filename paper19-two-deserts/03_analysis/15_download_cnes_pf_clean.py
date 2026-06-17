"""
15_download_cnes_pf_clean.py

Baixa e converte CNES-PF (profissionais) de forma LIMPA, corrigindo o bug de
conversao do paper18 (fallback raw=True tudo-ou-nada desalinhava campos ->
CODUFMUN corrompido, ~50% dos municipios perdidos). A correcao usa
datasus_dbc.decompress + dbfread modo normal com skip POR-REGISTRO (nunca
raw=True no arquivo inteiro).

Para mobilidade de medicos ao longo do tempo, baixa 1 snapshot/ano (junho) por
UF. Filtra so MEDICOS na conversao (CBO familias 2231/2251/2252/2253, verificadas
= CONSELHO CRM) para parquet enxuto.

Saida: 02_data/intermediate/cnes_pf_medicos/uf=XX/year=YYYY/data.parquet
  cols: CNS_PROF, CNES, codmun_6, CBO, cbo_fam, CONSELHO, REGISTRO,
        PROF_SUS, PROFNSUS, HORAHOSP, HORA_AMB, HORAOUTR, year
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import datasus_dbc
import dbfread
import duckdb
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "02_data" / "intermediate" / "cnes_pf_medicos"
TMP = Path("/tmp/cnes_pf_dbc")
LOG_DIR = ROOT / "04_logs"
OUT_DIR.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "15_download_cnes_pf_clean.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("pf_clean")

FTP_BASE = "ftp://ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/PF"
UFS = ["AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS",
       "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC",
       "SE", "SP", "TO"]
MED_FAMS = ("2231", "2251", "2252", "2253")  # medicos (CONSELHO CRM)
KEEP = ["CNS_PROF", "CNES", "CODUFMUN", "CBO", "CONSELHO", "REGISTRO",
        "PROF_SUS", "PROFNSUS", "HORAHOSP", "HORA_AMB", "HORAOUTR",
        # caracteristicas adicionais (escolha do pesquisador 2026-06-16):
        "UFMUNRES",                              # municipio de residencia do medico
        "VINCULAC", "VINCUL_C", "VINCUL_A", "VINCUL_N",  # tipo de vinculo
        "TP_UNID",                               # tipo de estabelecimento
        "NAT_JUR", "ESFERA_A", "TPGESTAO",       # publico/privado
        "MICR_REG"]                              # microrregiao do estabelecimento


def convert_one(uf: str, year: int, month: int) -> tuple[str, int]:
    out = OUT_DIR / f"uf={uf}" / f"year={year}" / f"month={month:02d}" / "data.parquet"
    if out.exists() and out.stat().st_size > 100:
        return ("cache", 0)
    fn = f"PF{uf}{year % 100:02d}{month:02d}.dbc"
    dbc = TMP / fn
    dbf = dbc.with_suffix(".dbf")
    url = f"{FTP_BASE}/{fn}"
    for attempt in range(3):
        try:
            if not dbc.exists() or dbc.stat().st_size < 100:
                data = urllib.request.urlopen(url, timeout=180).read()
                if len(data) < 100:
                    return ("missing", 0)
                dbc.write_bytes(data)
            datasus_dbc.decompress(str(dbc), str(dbf))
            break
        except Exception as e:  # noqa: BLE001
            if "550" in str(e) or "No such" in str(e):
                return ("missing", 0)
            if attempt == 2:
                return (f"err:{type(e).__name__}", 0)
            time.sleep(2 * (attempt + 1))

    recs, bad = [], 0
    try:
        it = iter(dbfread.DBF(str(dbf), encoding="latin1", raw=False,
                              ignore_missing_memofile=True))
        while True:
            try:
                r = next(it)
            except StopIteration:
                break
            except Exception:
                bad += 1
                continue
            cbo = str(r.get("CBO", "") or "")
            if cbo[:4] in MED_FAMS:
                recs.append({k: r.get(k) for k in KEEP})
    except Exception as e:  # noqa: BLE001
        return (f"err_parse:{type(e).__name__}", 0)
    finally:
        for p in (dbc, dbf):
            try:
                p.unlink()
            except Exception:
                pass

    if not recs:
        return ("empty", 0)
    df = (pl.DataFrame(recs, infer_schema_length=None)
          .with_columns([
              pl.col("CODUFMUN").cast(pl.Utf8).str.zfill(6).alias("codmun_6"),
              pl.col("UFMUNRES").cast(pl.Utf8).str.zfill(6).alias("codmun_res_6"),
              pl.col("CBO").cast(pl.Utf8).str.slice(0, 4).alias("cbo_fam"),
              pl.lit(year).alias("year"),
              pl.lit(month).alias("month"),
          ]))
    out.parent.mkdir(parents=True, exist_ok=True)
    df.write_parquet(out, compression="snappy")
    return ("ok", len(df))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--year-start", type=int, default=2015)
    ap.add_argument("--year-end", type=int, default=2023)
    ap.add_argument("--months", type=str, default="1-12",
                    help="meses: '1-12' (todos) ou lista '6,12'")
    ap.add_argument("--workers", type=int, default=5)
    args = ap.parse_args()

    if "-" in args.months:
        a, b = args.months.split("-")
        months = list(range(int(a), int(b) + 1))
    else:
        months = [int(x) for x in args.months.split(",")]

    targets = [(uf, y, mth) for uf in UFS
               for y in range(args.year_start, args.year_end + 1)
               for mth in months]
    log.info("==== CNES-PF limpo: %d arquivos (%d UFs x %d anos x %d meses) ====",
             len(targets), len(UFS), args.year_end - args.year_start + 1, len(months))
    t0 = time.perf_counter()
    counts: dict[str, int] = {}
    total_med = 0
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(convert_one, *t): t for t in targets}
        for i, f in enumerate(as_completed(futs), 1):
            uf, y, m = futs[f]
            status, n = f.result()
            key = status.split(":")[0]
            counts[key] = counts.get(key, 0) + 1
            total_med += n
            if status.startswith(("err", "missing")) or i % 25 == 0:
                log.info("[%d/%d] %s %d -> %s (n=%d) | acum_medicos=%d",
                         i, len(targets), uf, y, status, n, total_med)
    log.info("==== fim %.0fs | status=%s | medico-vinculos=%d ====",
             time.perf_counter() - t0, counts, total_med)


if __name__ == "__main__":
    main()
