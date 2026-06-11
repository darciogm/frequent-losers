"""
O3_convert_sia_raas_to_parquet.py

Converte os .dbc cacheados (por O2) em parquet particionado, UM ARQUIVO POR VEZ
(SIA-PA por UF-mês é grande): del df + gc.collect() entre arquivos, nunca dois
frames em memória ao mesmo tempo.

Primitiva DBC->parquet (provada em 00d/00e): dbc2dbf -> dbfread.DBF(latin1);
fallback raw=True com saneamento bytes->str em QUALQUER exceção.

Adiciona 6 colunas de proveniência a TODA linha:
  source_system, file_family, uf, year, month, source_filename
Preserva todas as colunas originais. Cast seguro só por padrão de nome
(o schema SIA muda por ano — nada de schema fixo):
  muni/CNES/proc/CID -> Utf8 ; quantidade/valor -> Float64.

Saída particionada:
  ROOT/02_data/intermediate/sia/family=<fam>/year=<yyyy>/uf=<UF>/<filename>.parquet
  ROOT/02_data/intermediate/raas/family=<fam>/year=<yyyy>/uf=<UF>/<filename>.parquet

Exemplos:
  python O3_convert_sia_raas_to_parquet.py --dry-run
  python O3_convert_sia_raas_to_parquet.py --families sia_pa --start-year 2015 --end-year 2022
  python O3_convert_sia_raas_to_parquet.py --families raas_ps --ufs SP,RJ --force
"""

from __future__ import annotations

import argparse
import gc
import logging
import re
import sys
from collections import defaultdict
from pathlib import Path

import dbfread
import polars as pl
from pyreaddbc import dbc2dbf

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_analysis"))
from _telemetry import StepTimer, write_json  # noqa: E402

LOG = ROOT / "04_logs" / "outpatient"
INTERMEDIATE = ROOT / "02_data" / "intermediate"
CACHE_DIR = {
    "sia": ROOT / "02_data" / "raw" / "sia" / "_dbc_cache",
    "raas": ROOT / "02_data" / "raw" / "raas" / "_dbc_cache",
}

LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "O3_convert_sia_raas_to_parquet.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("O3")

UFS_ALL = [
    "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA",
    "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN",
    "RO", "RR", "RS", "SC", "SE", "SP", "TO",
]

# sufixo opcional de parte (PASP1501a.dbc): UFs grandes particionam o mês em
# a/b/...; cada parte vira parquet próprio (stem distinto), mesmo (uf, ano, mês)
FNAME_RE = re.compile(r"^([A-Za-z]{2})([A-Z]{2})(\d{2})(\d{2})([a-z]?)\.dbc$", re.IGNORECASE)
FAMILY_PREFIX = {"sia_pa": "PA", "raas_ps": "PS"}
PREFIX_FAMILY = {"PA": "sia_pa", "PS": "raas_ps"}

# padrões de nome de coluna -> tipo alvo. Casados case-insensitive por substring.
# muni/CNES/proc/CID são códigos: Utf8 (preservar zeros à esquerda).
STR_PATTERNS = [
    "MUNIC", "CODUFMUN", "UFMUN", "MUN_",      # município
    "CNES",                                      # estabelecimento
    "PROC", "PA_PROC", "PA_CIDPRI",             # procedimento (proc fica antes de CID p/ catch)
    "CID", "CIDPRI", "CIDSEC", "CIDCAS",        # CID
    "CBO", "CGCCPF", "CNS", "CNPJ",             # outros identificadores
]
FLOAT_PATTERNS = [
    "QT", "QTD", "QUANT", "QT_APRES", "QT_APROV",  # quantidades
    "VL", "VAL", "VLR", "VL_APRES", "VL_APROV",    # valores
]


def family_to_system(family: str) -> str:
    return "raas" if family.startswith("raas") else "sia"


def parse_filename(name: str) -> dict | None:
    """PREFIXO UF AA MM .dbc -> dict de proveniência, ou None se não bater."""
    m = FNAME_RE.match(name)
    if not m:
        return None
    prefix, uf, yy_s, mm_s = m.group(1).upper(), m.group(2).upper(), m.group(3), m.group(4)
    family = PREFIX_FAMILY.get(prefix, f"other_{prefix.lower()}")
    year = 2000 + int(yy_s)  # SIASUS é todo pós-2000
    month = int(mm_s)
    return {
        "prefix": prefix,
        "file_family": family,
        "source_system": "RAAS" if family.startswith("raas") else "SIA",
        "uf": uf,
        "year": year,
        "month": month,
    }


def target_path(meta: dict, filename: str) -> Path:
    system = family_to_system(meta["file_family"])
    stem = Path(filename).stem
    return (INTERMEDIATE / system
            / f"family={meta['file_family']}"
            / f"year={meta['year']}"
            / f"uf={meta['uf']}"
            / f"{stem}.parquet")


def _sanitize_record(rec: dict) -> dict:
    """Saneia bytes -> str(latin1, strip) para o caminho raw=True."""
    out = {}
    for k, v in rec.items():
        if isinstance(v, bytes):
            s = v.decode("latin1").strip()
            out[k] = s if s != "" else None
        else:
            out[k] = v
    return out


# chunk de streaming: 250k dicts ≈ 0.5-1 GB transitório. Materializar o DBF
# inteiro como lista de dicts estourava 15 GB nas partes multi-part de SP.
STREAM_CHUNK = 250_000


def read_dbc_frames(dbc_path: Path) -> list[pl.DataFrame]:
    """
    Lê 1 .dbc -> lista de DataFrames (1 por chunk de STREAM_CHUNK registros).
    Primário: dbfread latin1. Fallback em QUALQUER exceção (mesmo no meio do
    stream): recomeça o arquivo inteiro com raw=True + saneamento de bytes —
    mesma semântica do caminho antigo, que relia tudo no fallback.
    """
    dbf_path = dbc_path.with_suffix(".dbf")
    dbc2dbf(str(dbc_path).encode("utf-8"), str(dbf_path).encode("utf-8"))

    def stream(raw: bool) -> list[pl.DataFrame]:
        frames, buf = [], []
        for r in dbfread.DBF(str(dbf_path), encoding="latin1", raw=raw):
            buf.append(_sanitize_record(dict(r)) if raw else dict(r))
            if len(buf) >= STREAM_CHUNK:
                frames.append(pl.DataFrame(buf, infer_schema_length=None))
                buf.clear()
        if buf:
            frames.append(pl.DataFrame(buf, infer_schema_length=None))
        return frames

    try:
        try:
            return stream(raw=False)
        except Exception as e:
            log.warning("DBF latin1 falhou em %s (%s); fallback raw=True",
                        dbc_path.name, e)
            return stream(raw=True)
    finally:
        try:
            if dbf_path.exists():
                dbf_path.unlink()
        except Exception:
            pass


def cast_columns(df: pl.DataFrame) -> pl.DataFrame:
    """Cast seguro só nas colunas que EXISTEM, por padrão de nome."""
    exprs = []
    for col in df.columns:
        up = col.upper()
        is_float = any(p in up for p in FLOAT_PATTERNS)
        is_str = any(p in up for p in STR_PATTERNS)
        # códigos vencem quando há ambiguidade (preservar formato textual)
        if is_str:
            exprs.append(pl.col(col).cast(pl.Utf8, strict=False).alias(col))
        elif is_float:
            exprs.append(
                pl.col(col).cast(pl.Utf8, strict=False)
                .str.strip_chars()
                .str.replace_all(",", ".")
                .cast(pl.Float64, strict=False)
                .alias(col)
            )
    if exprs:
        df = df.with_columns(exprs)
    return df


def add_provenance(df: pl.DataFrame, meta: dict, filename: str) -> pl.DataFrame:
    return df.with_columns([
        pl.lit(meta["source_system"]).alias("source_system"),
        pl.lit(meta["file_family"]).alias("file_family"),
        pl.lit(meta["uf"]).alias("uf"),
        pl.lit(int(meta["year"])).cast(pl.Int64).alias("year"),
        pl.lit(int(meta["month"])).cast(pl.Int64).alias("month"),
        pl.lit(filename).alias("source_filename"),
    ])


def convert_one(dbc_path: Path, force: bool) -> tuple[str, int]:
    """Converte 1 .dbc. Devolve (status, n_rows). status ∈ ok|skip|empty|error."""
    meta = parse_filename(dbc_path.name)
    if meta is None:
        log.warning("nome não reconhecido, pulado: %s", dbc_path.name)
        return ("error", 0)

    out = target_path(meta, dbc_path.name)
    if not force and out.exists() and out.stat().st_size > 100:
        return ("skip", 0)

    out.parent.mkdir(parents=True, exist_ok=True)

    df = None
    tmp = out.with_name(out.name + ".tmp")
    try:
        frames = read_dbc_frames(dbc_path)
        if not frames:
            return ("empty", 0)
        # diagonal_relaxed: reconcilia schema entre chunks (coluna toda-None
        # num chunk, tipos promovidos noutro)
        df = frames[0] if len(frames) == 1 else pl.concat(frames, how="diagonal_relaxed")
        del frames
        df = cast_columns(df)
        df = add_provenance(df, meta, dbc_path.name)
        n = df.height
        # escrita atômica: um kill no meio do write não pode deixar parquet
        # parcial que o check de skip (size>100) aceitaria como pronto
        df.write_parquet(tmp, compression="snappy")
        tmp.replace(out)
        return ("ok", n)
    except Exception as e:
        log.warning("erro convertendo %s: %s", dbc_path.name, e)
        try:
            if tmp.exists():
                tmp.unlink()
        except Exception:
            pass
        return ("error", 0)
    finally:
        # memory-safe: largar o frame e forçar GC entre arquivos
        del df
        gc.collect()


def collect_dbc(families: list[str], ufs: list[str],
                start_year: int, end_year: int) -> list[Path]:
    """Varre os caches e filtra .dbc por família/UF/ano."""
    systems = {family_to_system(f) for f in families}
    found = []
    for system in systems:
        cache = CACHE_DIR[system]
        if not cache.exists():
            continue
        for p in sorted(cache.glob("*.dbc")):
            meta = parse_filename(p.name)
            if meta is None:
                continue
            if meta["file_family"] not in families:
                continue
            if meta["uf"] not in ufs:
                continue
            if not (start_year <= meta["year"] <= end_year):
                continue
            found.append(p)
    return found


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Converte .dbc SIA/RAAS em parquet particionado.")
    p.add_argument("--dry-run", action="store_true",
                   help="lista o que seria convertido, sem converter")
    p.add_argument("--force", action="store_true",
                   help="reconverte mesmo que o parquet alvo exista")
    p.add_argument("--start-year", type=int, default=2010)
    p.add_argument("--end-year", type=int, default=2024)
    p.add_argument("--ufs", default="all")
    p.add_argument("--families", default="all",
                   help="sia_pa, raas_ps, ou all")
    return p.parse_args()


def resolve_ufs(arg: str) -> list[str]:
    if arg.strip().lower() == "all":
        return list(UFS_ALL)
    out = [t.strip().upper() for t in arg.split(",") if t.strip()]
    out = [t for t in out if t in UFS_ALL]
    return out or list(UFS_ALL)


def resolve_families(arg: str) -> list[str]:
    valid = {"sia_pa", "raas_ps"}
    a = arg.strip().lower()
    if a == "all":
        return ["sia_pa", "raas_ps"]
    out = [t.strip().lower() for t in arg.split(",") if t.strip()]
    if "all" in out:
        return ["sia_pa", "raas_ps"]
    out = [t for t in out if t in valid]
    return out or ["sia_pa", "raas_ps"]


def main() -> int:
    args = parse_args()
    timer = StepTimer(log)

    families = resolve_families(args.families)
    ufs = resolve_ufs(args.ufs)

    dbcs = collect_dbc(families, ufs, args.start_year, args.end_year)
    log.info("famílias=%s ufs=%d anos=%d..%d -> %d .dbc no cache",
             families, len(ufs), args.start_year, args.end_year, len(dbcs))
    if not dbcs:
        log.warning("nenhum .dbc no cache p/ o filtro. Rode O2. Saindo limpo.")
        return 0

    if args.dry_run:
        by_key = defaultdict(int)
        for p in dbcs:
            meta = parse_filename(p.name)
            by_key[(meta["file_family"], meta["year"])] += 1
        log.info("==== DRY-RUN: converteria %d arquivos ====", len(dbcs))
        for (fam, year) in sorted(by_key):
            log.info("  %-12s %d: %d arquivos", fam, year, by_key[(fam, year)])
        timer.mark("dry-run")
        return 0

    # resumo por família/ano/UF
    by_fam = defaultdict(lambda: {"files": 0, "rows": 0})
    counts = defaultdict(int)

    for i, dbc in enumerate(dbcs, 1):
        meta = parse_filename(dbc.name)
        status, n = convert_one(dbc, args.force)
        counts[status] += 1
        if status in ("ok", "skip"):
            key = (meta["file_family"], meta["year"], meta["uf"])
            by_fam[key]["files"] += 1
            by_fam[key]["rows"] += n
        if i % 50 == 0 or i == len(dbcs):
            timer.mark(f"converted {i}/{len(dbcs)}")
            log.info("progress %d/%d ok=%d skip=%d empty=%d error=%d",
                     i, len(dbcs), counts["ok"], counts["skip"],
                     counts["empty"], counts["error"])

    log.info("==== resumo por família/ano/UF (ok+skip) ====")
    for key in sorted(by_fam):
        fam, year, uf = key
        v = by_fam[key]
        log.info("  %-12s %d %s: files=%d rows=%d", fam, year, uf,
                 v["files"], v["rows"])

    log.info("==== contagem de status ====")
    for k in ("ok", "skip", "empty", "error"):
        log.info("  %-8s %d", k, counts[k])
    log.info("peak RSS=%.2f GB", timer.peak_rss_gb)

    total_rows = sum(v["rows"] for v in by_fam.values())
    write_json(LOG / "O3_convert_summary.json", {
        "families": families,
        "ufs": ufs,
        "start_year": args.start_year,
        "end_year": args.end_year,
        "ok": counts["ok"],
        "skip": counts["skip"],
        "empty": counts["empty"],
        "error": counts["error"],
        "total_rows": total_rows,
        "peak_rss_gb": round(timer.peak_rss_gb, 3),
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
