"""
O1_discover_sia_raas_files.py

Descobre quais arquivos SIA (Produção Ambulatorial) e RAAS (Psicossocial)
existem no FTP DATASUS para a grade família × ano × mês × UF pedida, e
escreve o manifesto CSV que O2 consome.

Estratégia (servidor é read-only aqui — descoberta nunca baixa o dado):
  1) PRIMÁRIA: listagem de diretório via ftplib NLST (passive) de
     SIASUS/200801_/Dados, com retries/backoff. Parse por regex.
  2) FALLBACK: o NLST do DATASUS frequentemente dá timeout. Então
     ENUMERAMOS deterministicamente os nomes candidatos da grade e
     probamos cada um com FTP SIZE. size devolvido -> available;
     550/None -> missing; outro erro de servidor -> ambiguous.

RAAS-PS tipicamente só começa ~2013 — NÃO afirmamos isso; o probe revela.

Famílias: prefixo PA -> sia_pa, PS -> raas_ps; qualquer outro prefixo de
2 letras vira other_<prefixo>. Nada de hardcode da lista completa de arquivos.

Manifesto: ROOT/02_data/processed/outpatient_mental_health/sia_raas_file_manifest.csv
Colunas EXATAS:
  source_system, file_family, uf, year, month, filename, remote_path,
  size_bytes, modified_date, status   (status ∈ available|missing|ambiguous)

Exemplos:
  python O1_discover_sia_raas_files.py --dry-run
  python O1_discover_sia_raas_files.py --families sia_pa --start-year 2015 --end-year 2022
  python O1_discover_sia_raas_files.py --families raas_ps --ufs SP,RJ,MG
"""

from __future__ import annotations

import argparse
import csv
import ftplib
import logging
import re
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_analysis"))
from _telemetry import StepTimer, write_json  # noqa: E402

LOG = ROOT / "04_logs" / "outpatient"
MANIFEST_DIR = ROOT / "02_data" / "processed" / "outpatient_mental_health"
MANIFEST = MANIFEST_DIR / "sia_raas_file_manifest.csv"

LOG.mkdir(parents=True, exist_ok=True)
MANIFEST_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "O1_discover_sia_raas_files.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("O1")

UFS_ALL = [
    "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA",
    "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN",
    "RO", "RR", "RS", "SC", "SE", "SP", "TO",
]

FTP_HOST = "ftp.datasus.gov.br"
FTP_DIR = "/dissemin/publicos/SIASUS/200801_/Dados"
FTP_BASE_URL = f"ftp://{FTP_HOST}{FTP_DIR}"

# família principal -> prefixo de arquivo no FTP
FAMILY_PREFIX = {"sia_pa": "PA", "raas_ps": "PS"}
PREFIX_FAMILY = {v: k for k, v in FAMILY_PREFIX.items()}

# nome de arquivo SIASUS: PREFIXO(2) UF(2) AA(2) MM(2) [parte a-z] .dbc
# UFs grandes (SP/MG/RJ/RS) têm meses particionados em sufixo de letra:
# PASP1501a.dbc + PASP1501b.dbc. Sem o grupo opcional, esses meses são
# invisíveis e o manifesto os marca "missing" — buraco silencioso de dados.
FNAME_RE = re.compile(r"^([A-Za-z]{2})([A-Z]{2})(\d{2})(\d{2})([a-z]?)\.dbc$", re.IGNORECASE)

MANIFEST_COLUMNS = [
    "source_system", "file_family", "uf", "year", "month", "filename",
    "remote_path", "size_bytes", "modified_date", "status",
]


def prefix_to_family(prefix: str) -> str:
    """PA->sia_pa, PS->raas_ps, resto -> other_<prefixo minúsculo>."""
    p = prefix.upper()
    return PREFIX_FAMILY.get(p, f"other_{prefix.lower()}")


def family_to_source(family: str) -> str:
    return "RAAS" if family.startswith("raas") else "SIA"


def yy(year: int) -> str:
    return f"{year % 100:02d}"


def yy_to_year(yy_str: str, start: int, end: int) -> int:
    """2 dígitos -> 4 dígitos, escolhendo o ano dentro [start,end] se possível."""
    n = int(yy_str)
    candidates = [c for c in (2000 + n, 1900 + n) if start <= c <= end]
    if candidates:
        return candidates[0]
    return 2000 + n  # default sensato; SIASUS é todo pós-2000


# ---------------------------------------------------------------------------
# PRIMÁRIA: listagem NLST com retries
# ---------------------------------------------------------------------------

def ftp_listing(retries: int = 3) -> list[str] | None:
    """Tenta NLST do diretório de Dados. Devolve lista de nomes ou None."""
    backoff = 2
    for attempt in range(1, retries + 1):
        try:
            ftp = ftplib.FTP(FTP_HOST, timeout=120)
            ftp.login()  # anonymous
            ftp.set_pasv(True)
            ftp.cwd(FTP_DIR)
            names = ftp.nlst()
            try:
                ftp.quit()
            except Exception:
                pass
            # NLST pode devolver caminhos completos — fica só o basename
            names = [n.rsplit("/", 1)[-1] for n in names if n]
            log.info("NLST ok (tentativa %d): %d entradas", attempt, len(names))
            return names
        except Exception as e:
            log.warning("NLST falhou (tentativa %d/%d): %s", attempt, retries, e)
            if attempt < retries:
                time.sleep(backoff)
                backoff *= 2
    return None


# ---------------------------------------------------------------------------
# FALLBACK: probe por arquivo via FTP SIZE
# ---------------------------------------------------------------------------

def probe_size(filename: str, retries: int = 3) -> tuple[str, int | None]:
    """
    Proba 1 arquivo via FTP SIZE. Devolve (status, size_bytes).
      status ∈ available|missing|ambiguous
    """
    backoff = 2
    last_err = None
    for attempt in range(1, retries + 1):
        ftp = None
        try:
            ftp = ftplib.FTP(FTP_HOST, timeout=120)
            ftp.login()
            ftp.set_pasv(True)
            ftp.cwd(FTP_DIR)
            try:
                ftp.sendcmd("TYPE I")  # SIZE exige modo binário
            except Exception:
                pass
            try:
                size = ftp.size(filename)
            finally:
                try:
                    ftp.quit()
                except Exception:
                    pass
            if size is not None and size > 0:
                return ("available", int(size))
            return ("missing", None)
        except ftplib.error_perm as e:
            # 550 = não existe; outros perm errors -> ambíguo
            if ftp is not None:
                try:
                    ftp.close()
                except Exception:
                    pass
            msg = str(e).lower()
            if "550" in msg or "no such" in msg or "not found" in msg:
                return ("missing", None)
            return ("ambiguous", None)
        except Exception as e:
            last_err = e
            if ftp is not None:
                try:
                    ftp.close()
                except Exception:
                    pass
            if attempt < retries:
                time.sleep(backoff)
                backoff *= 2
    log.debug("probe %s ambíguo após retries: %s", filename, last_err)
    return ("ambiguous", None)


# ---------------------------------------------------------------------------
# grade de candidatos
# ---------------------------------------------------------------------------

def build_grid(families: list[str], ufs: list[str],
               start_year: int, end_year: int) -> list[dict]:
    """Enumera candidatos (família, uf, ano, mês) -> registros parciais."""
    grid = []
    for fam in families:
        prefix = FAMILY_PREFIX.get(fam)
        if prefix is None:
            log.warning("família %s sem prefixo conhecido; pulada na grade", fam)
            continue
        for uf in ufs:
            for year in range(start_year, end_year + 1):
                for month in range(1, 13):
                    fname = f"{prefix}{uf}{yy(year)}{month:02d}.dbc"
                    grid.append({
                        "source_system": family_to_source(fam),
                        "file_family": fam,
                        "uf": uf,
                        "year": year,
                        "month": month,
                        "filename": fname,
                        "remote_path": f"{FTP_BASE_URL}/{fname}",
                    })
    return grid


def discover_via_listing(names: list[str], grid: list[dict],
                         start_year: int, end_year: int) -> list[dict] | None:
    """
    Usa a listagem NLST para marcar available/missing sem probar 1-a-1.
    Só vale se a listagem realmente trouxe arquivos .dbc (senão devolve None
    para o caller cair no probe).
    """
    # indexa por mês (stem sem o sufixo de parte): um mês pode ter 1 arquivo
    # exato (PASP1201.dbc) ou N partes (PASP1501a.dbc, PASP1501b.dbc).
    by_month: dict[str, list[str]] = {}
    n_parsed = 0
    for n in names:
        m = FNAME_RE.match(n)
        if m:
            n_parsed += 1
            month_key = (m.group(1) + m.group(2) + m.group(3) + m.group(4)).lower()
            by_month.setdefault(month_key, []).append(n)
    if not by_month:
        log.info("listagem não trouxe .dbc parseáveis; caindo para probe")
        return None
    log.info("listagem: %d arquivos .dbc reconhecidos (%d meses)",
             n_parsed, len(by_month))

    rows = []
    for rec in grid:
        month_key = rec["filename"].lower().removesuffix(".dbc")
        parts = sorted(by_month.get(month_key, []))
        if parts:
            for real in parts:  # uma linha de manifesto por parte
                rows.append({**rec, "filename": real,
                             "remote_path": f"{FTP_BASE_URL}/{real}",
                             "size_bytes": "", "modified_date": "",
                             "status": "available"})
        else:
            rows.append({**rec, "size_bytes": "", "modified_date": "",
                         "status": "missing"})
    return rows


def discover_via_probe(grid: list[dict]) -> list[dict]:
    """Proba cada candidato via FTP SIZE em paralelo (4 workers)."""
    rows = [None] * len(grid)

    def work(i: int, rec: dict) -> tuple[int, dict]:
        status, size = probe_size(rec["filename"])
        out = {
            **rec,
            "size_bytes": "" if size is None else str(size),
            "modified_date": "",
            "status": status,
        }
        return i, out

    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(work, i, rec): i for i, rec in enumerate(grid)}
        done = 0
        total = len(futs)
        for f in as_completed(futs):
            i, out = f.result()
            rows[i] = out
            done += 1
            if done % 200 == 0 or done == total:
                log.info("probe %d/%d", done, total)
    return rows


# ---------------------------------------------------------------------------

def write_manifest(rows: list[dict]) -> None:
    with MANIFEST.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_COLUMNS)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in MANIFEST_COLUMNS})
    log.info("manifesto escrito: %s (%d linhas)", MANIFEST, len(rows))


def summarize(rows: list[dict]) -> None:
    """Imprime contagens por família/ano/UF e o que está faltando."""
    by_fam = defaultdict(lambda: defaultdict(int))
    by_year = defaultdict(lambda: defaultdict(int))
    by_uf = defaultdict(lambda: defaultdict(int))
    for r in rows:
        by_fam[r["file_family"]][r["status"]] += 1
        by_year[(r["file_family"], r["year"])][r["status"]] += 1
        by_uf[(r["file_family"], r["uf"])][r["status"]] += 1

    log.info("==== resumo por família ====")
    for fam in sorted(by_fam):
        c = by_fam[fam]
        log.info("  %-12s available=%d missing=%d ambiguous=%d",
                 fam, c["available"], c["missing"], c["ambiguous"])

    log.info("==== anos/famílias SEM nenhum arquivo available ====")
    fam_year_avail = defaultdict(int)
    fam_years = defaultdict(set)
    for (fam, year), c in by_year.items():
        fam_years[fam].add(year)
        fam_year_avail[(fam, year)] = c["available"]
    any_missing = False
    for fam in sorted(fam_years):
        missing_years = sorted(y for y in fam_years[fam]
                               if fam_year_avail[(fam, y)] == 0)
        if missing_years:
            any_missing = True
            log.info("  %-12s sem available em: %s", fam,
                     ", ".join(str(y) for y in missing_years))
    if not any_missing:
        log.info("  (nenhum — todo ano/família tem ao menos 1 available)")

    log.info("==== available por família × ano ====")
    for fam in sorted(fam_years):
        for year in sorted(fam_years[fam]):
            n = fam_year_avail[(fam, year)]
            log.info("  %-12s %d: available=%d", fam, year, n)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Descobre arquivos SIA/RAAS no FTP DATASUS.")
    p.add_argument("--dry-run", action="store_true",
                   help="descobre + escreve manifesto + imprime resumo (servidor read-only de qualquer modo)")
    p.add_argument("--force", action="store_true",
                   help="re-descobre mesmo que o manifesto já exista")
    p.add_argument("--start-year", type=int, default=2010)
    p.add_argument("--end-year", type=int, default=2024)
    p.add_argument("--ufs", default="all",
                   help="lista separada por vírgula (default: todas as 27)")
    p.add_argument("--families", default="all",
                   help="sia_pa, raas_ps, ou all (vírgula p/ múltiplas)")
    return p.parse_args()


def resolve_ufs(arg: str) -> list[str]:
    if arg.strip().lower() == "all":
        return list(UFS_ALL)
    out = []
    for tok in arg.split(","):
        tok = tok.strip().upper()
        if tok and tok in UFS_ALL:
            out.append(tok)
        elif tok:
            log.warning("UF desconhecida ignorada: %s", tok)
    return out or list(UFS_ALL)


def resolve_families(arg: str) -> list[str]:
    valid = {"sia_pa", "raas_ps"}
    if arg.strip().lower() == "all":
        return ["sia_pa", "raas_ps"]
    out = []
    for tok in arg.split(","):
        tok = tok.strip().lower()
        if tok == "all":
            return ["sia_pa", "raas_ps"]
        if tok in valid:
            out.append(tok)
        elif tok:
            log.warning("família desconhecida ignorada: %s", tok)
    return out or ["sia_pa", "raas_ps"]


def main() -> int:
    args = parse_args()
    timer = StepTimer(log)

    if MANIFEST.exists() and MANIFEST.stat().st_size > 100 and not args.force \
            and not args.dry_run:
        log.info("manifesto já existe (%s); use --force para refazer. Saindo.", MANIFEST)
        return 0

    families = resolve_families(args.families)
    ufs = resolve_ufs(args.ufs)
    log.info("famílias=%s ufs=%d anos=%d..%d",
             families, len(ufs), args.start_year, args.end_year)

    grid = build_grid(families, ufs, args.start_year, args.end_year)
    if not grid:
        log.warning("grade vazia — nada a descobrir. Saindo limpo.")
        write_manifest([])
        return 0
    log.info("grade: %d candidatos", len(grid))

    rows = None
    names = ftp_listing()
    if names is not None:
        rows = discover_via_listing(names, grid, args.start_year, args.end_year)
        if rows is not None:
            log.info("método de descoberta: LISTAGEM (NLST)")
    if rows is None:
        log.info("método de descoberta: PROBE (FTP SIZE por arquivo)")
        rows = discover_via_probe(grid)

    timer.mark("discovery")
    write_manifest(rows)
    summarize(rows)
    timer.mark("manifest+summary")

    n_avail = sum(1 for r in rows if r["status"] == "available")
    n_miss = sum(1 for r in rows if r["status"] == "missing")
    n_amb = sum(1 for r in rows if r["status"] == "ambiguous")
    log.info("TOTAL available=%d missing=%d ambiguous=%d", n_avail, n_miss, n_amb)

    write_json(LOG / "O1_discover_summary.json", {
        "families": families,
        "ufs": ufs,
        "start_year": args.start_year,
        "end_year": args.end_year,
        "available": n_avail,
        "missing": n_miss,
        "ambiguous": n_amb,
        "manifest": str(MANIFEST),
        "peak_rss_gb": round(timer.peak_rss_gb, 3),
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
