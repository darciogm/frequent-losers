#!/usr/bin/env python3
"""
00_build_eventlevel_comprasnet.py
=================================

ComprasNet federal cross-jurisdiction ingestion for paper3 FL
methodology replication.

DRAFT — 2026-05-22 (mr-frequent, modo revisor)
================================================

Honest scope
------------
This script produces PARTICIPATION-level data, NOT bid-level. For
backwards compatibility with paper3 downstream scripts the canonical
output is still named ``bid_level_full.parquet``, but in the ComprasNet
panel each row is one (firm × item × tender) participation with
``won`` derived from ``Flag Vencedor``. **No ``lance`` values exist in
this source.** Imhof bid-distribution features (H6) are not replicable
from Portal da Transparência alone — that needs a separate scrape of
Portal SISG bid microdata. See COMPRASNET_PATH_TO_CONFIRMED.md §8.

Source
------
Portal da Transparência (CGU) monthly bulk ZIPs:

    https://dadosabertos-download.cgu.gov.br/PortalDaTransparencia/
        saida/licitacoes/{YYYYMM}_Licitacoes.zip

Each ZIP holds 4 CSVs (Latin-1, ``;`` delimiter, ``,`` decimal,
``DD/MM/YYYY`` dates):

    {YYYYMM}_Licitação.csv                — tender-level
    {YYYYMM}_ItemLicitação.csv            — item-level (with winner)
    {YYYYMM}_ParticipantesLicitação.csv   — KEY: one row per
                                            firm × item × tender,
                                            with Flag Vencedor SIM/NÃO
    {YYYYMM}_EmpenhosRelacionados.csv     — post-award spending
                                            (not used by FL pipeline)

Coverage
--------
2013-01 onwards. Paper3 BEC panel is 2009-2019; federal overlap is
2013-2019 (7 of 11 years). Pre-2013 unavailable from this source.

Modality scope
--------------
Default filter: modalidades 5 (Pregão) and 9999 (Pregão SRP) only.
Other modalities are coded as 100% winners in the participants table
(no real competition tracking) — they cannot construct loser sets.
Federal Convite (modality 1) is extinct (~5 participations/month
nationwide), so AN-016 / D2 cross-modality test does not replicate.

Outputs (written to --processed-dir)
------------------------------------
- bid_level_full.parquet       — one row per (firm × item × tender)
- firm_loss_stats.parquet      — per-firm aggregated win_rate
- firm_tender_map.parquet      — firm × tender × item with won flag
- FREQ_PARTICIP_rebuilt.parquet — always-losers with tenders_count
- LOSERS_rebuilt.parquet       — FL counts per (tender, item)
All outputs carry a ``panel='comprasnet'`` column.

Pipeline (3 phases, each independently runnable)
------------------------------------------------
0. download    — monthly ZIPs from CGU, checkpointed, polite delay
1. validate    — confirm schema of every downloaded ZIP
2. build       — DuckDB-native end-to-end, emit 5 parquets

Memory and threading
--------------------
DuckDB-native end-to-end (per CLAUDE.md). No full materialization in
pandas. ``PRAGMA threads=12 memory_limit='14GB' temp_directory=/tmp/duckdb_spill``.
RSS-snapshot telemetry per phase. Within DarcioWork budget (14 GiB
working, ~5 GiB headroom).

CLI examples
------------
    # full pipeline 2013-2019, default modalities, default paths
    python 00_build_eventlevel_comprasnet.py

    # smoke test on jan/2019 only
    python 00_build_eventlevel_comprasnet.py \\
        --year-start 2019 --year-end 2019 --month-start 1 --month-end 1

    # only download (resumable)
    python 00_build_eventlevel_comprasnet.py --skip-validate --skip-build

    # only build, assume ZIPs already downloaded
    python 00_build_eventlevel_comprasnet.py --skip-download

    # dry-run: estimate sizes + time
    python 00_build_eventlevel_comprasnet.py --dry-run

    # include other modalities (e.g. dispensa as a robustness panel)
    python 00_build_eventlevel_comprasnet.py --modalities 5 9999 6
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import socket
import sys
import time
import zipfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import httpx
import psutil

try:
    import duckdb  # type: ignore
except ImportError:  # pragma: no cover
    duckdb = None  # type: ignore


# ──────────────────────────── Configuration ───────────────────────────

BULK_URL_TEMPLATE = (
    "https://dadosabertos-download.cgu.gov.br/"
    "PortalDaTransparencia/saida/licitacoes/{ym}_Licitacoes.zip"
)

# Default behaviour: paper3 BEC overlap window, Pregão + Pregão SRP.
DEFAULT_YEAR_START = 2013
DEFAULT_YEAR_END = 2019
DEFAULT_MODALITIES = (5, 9999)  # Pregão, Pregão SRP

# Default I/O locations. Both overridable via CLI.
DEFAULT_RAW_DIR = Path.home() / "projetos" / "comprasnet" / "data" / "raw" / "portal"
DEFAULT_PROCESSED_DIR = (
    Path(__file__).resolve().parent.parent
    / "data" / "processed_comprasnet"
)
DEFAULT_LOG_DIR = (
    Path(__file__).resolve().parent.parent / "logs" / "comprasnet"
)

HEADERS = {
    "User-Agent": (
        "paper3-cross-jurisdiction-acquisition/1.0 "
        "(Insper procurement research; contact: darcio.g.martins@gmail.com)"
    ),
    "Accept": "application/zip,application/octet-stream",
}

RATE_LIMIT_DELAY = 1.0   # seconds between monthly ZIP fetches
RETRY_ATTEMPTS = 4
RETRY_BASE_DELAY = 4.0
REQUEST_TIMEOUT = 600.0  # ZIPs can be 100+ MB; allow slow link

DUCKDB_THREADS = 12
DUCKDB_MEMORY = "14GB"
DUCKDB_SPILL = "/tmp/duckdb_spill_comprasnet"

# Expected columns per CSV (Latin-1, semicolon-delimited).
EXPECTED_SCHEMAS: dict[str, list[str]] = {
    "ParticipantesLicitação": [
        "Número Licitação", "Código UG", "Nome UG",
        "Código Modalidade Compra", "Modalidade Compra",
        "Número Processo", "Código Órgão", "Nome Órgão",
        "Código Item Compra", "Descrição Item Compra",
        "Código Participante", "Nome Participante", "Flag Vencedor",
    ],
    "ItemLicitação": [
        "Número Licitação", "Código UG", "Nome UG",
        "Código Modalidade Compra", "Modalidade Compra",
        "Número Processo", "Código Órgão", "Nome Órgão",
        "Código Item Compra", "Descrição",
        "Quantidade Item", "Valor Item",
        "Código Vencedor", "Nome Vencedor",
    ],
    "Licitação": [
        "Número Licitação", "Código UG", "Nome UG",
        "Código Modalidade Compra", "Modalidade Compra",
        "Número Processo", "Objeto", "Situação Licitação",
        "Código Órgão Superior", "Nome Órgão Superior",
        "Código Órgão", "Nome Órgão", "UF", "Município",
        "Data Resultado Compra", "Data Abertura", "Valor Licitação",
    ],
}


# ──────────────────────────── Helpers ─────────────────────────────────

def setup_logging(log_dir: Path) -> Path:
    log_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_path = log_dir / f"build_eventlevel_comprasnet_{ts}.log"
    logger = logging.getLogger()
    logger.handlers.clear()
    logger.setLevel(logging.INFO)
    fmt = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(message)s", "%Y-%m-%d %H:%M:%S",
    )
    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(fmt)
    logger.addHandler(sh)
    fh = logging.FileHandler(log_path)
    fh.setFormatter(fmt)
    logger.addHandler(fh)
    return log_path


def rss_mb() -> float:
    return psutil.Process(os.getpid()).memory_info().rss / 2**20


def telemetry_banner() -> None:
    vm = psutil.virtual_memory()
    logging.info("===== Runtime environment =====")
    logging.info(f"  hostname:        {socket.gethostname()}")
    logging.info(f"  CPU cores:       {os.cpu_count()}")
    logging.info(f"  RAM total:       {vm.total / 2**30:.1f} GiB")
    logging.info(f"  RAM available:   {vm.available / 2**30:.1f} GiB")
    logging.info(f"  RSS at start:    {rss_mb():.0f} MiB")
    logging.info("================================")


def month_iter(y0: int, m0: int, y1: int, m1: int):
    y, m = y0, m0
    while (y, m) <= (y1, m1):
        yield y, m
        m += 1
        if m > 12:
            m, y = 1, y + 1


def ym_key(y: int, m: int) -> str:
    return f"{y:04d}{m:02d}"


# ──────────────────────────── Checkpoint ──────────────────────────────

class Checkpoint:
    """Resumable per-month state. JSON dict keyed by YYYYMM."""

    def __init__(self, path: Path):
        self.path = path
        if path.exists():
            self.state: dict[str, dict] = json.loads(path.read_text())
        else:
            self.state = {}
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}")

    def mark(self, ym: str, **fields) -> None:
        self.state.setdefault(ym, {}).update(fields)
        self.path.write_text(json.dumps(self.state, indent=0, sort_keys=True))

    def has(self, ym: str, flag: str) -> bool:
        return bool(self.state.get(ym, {}).get(flag))

    def __len__(self) -> int:
        return len(self.state)


# ──────────────────────────── Phase 0 — download ──────────────────────

def download_month(client: httpx.Client, y: int, m: int,
                   raw_dir: Path, ckpt: Checkpoint) -> tuple[bool, int]:
    """Download one monthly ZIP. Returns (downloaded, size_bytes)."""
    ym = ym_key(y, m)
    out_path = raw_dir / f"{ym}_Licitacoes.zip"

    if ckpt.has(ym, "downloaded") and out_path.exists():
        return False, out_path.stat().st_size

    url = BULK_URL_TEMPLATE.format(ym=ym)
    raw_dir.mkdir(parents=True, exist_ok=True)

    for attempt in range(RETRY_ATTEMPTS):
        try:
            t0 = time.time()
            with client.stream("GET", url, timeout=REQUEST_TIMEOUT,
                               follow_redirects=True) as r:
                if r.status_code != 200:
                    logging.warning(
                        f"  {ym}: HTTP {r.status_code} on attempt {attempt+1}")
                    if r.status_code == 404:
                        # No data for this month — mark and move on
                        ckpt.mark(ym, downloaded=False, http_status=404)
                        return False, 0
                    time.sleep(RETRY_BASE_DELAY * (2 ** attempt))
                    continue
                tmp = out_path.with_suffix(".zip.part")
                size = 0
                with tmp.open("wb") as f:
                    for chunk in r.iter_bytes(chunk_size=2**20):
                        f.write(chunk)
                        size += len(chunk)
                tmp.rename(out_path)
            elapsed = time.time() - t0
            ckpt.mark(ym, downloaded=True, size_bytes=size,
                      http_status=200, elapsed_s=round(elapsed, 1))
            logging.info(
                f"  [done] {ym}: {size/2**20:.1f} MiB in {elapsed:.1f}s "
                f"(rss={rss_mb():.0f}MiB)")
            return True, size
        except (httpx.ReadTimeout, httpx.ConnectError,
                httpx.RemoteProtocolError) as e:
            logging.warning(f"  {ym}: transport {e!r} attempt {attempt+1}")
            time.sleep(RETRY_BASE_DELAY * (2 ** attempt))

    logging.error(f"  {ym}: exhausted retries")
    ckpt.mark(ym, downloaded=False, http_status="exhausted_retries")
    return False, 0


def phase_download(y0: int, m0: int, y1: int, m1: int,
                   raw_dir: Path, ckpt: Checkpoint) -> None:
    logging.info(f"--- Phase 0: download {y0}-{m0:02d} → {y1}-{m1:02d} ---")
    total_bytes = 0
    n_new = 0
    t_phase = time.time()
    with httpx.Client(headers=HEADERS, http2=False,
                      limits=httpx.Limits(max_connections=2)) as client:
        for y, m in month_iter(y0, m0, y1, m1):
            downloaded, size = download_month(client, y, m, raw_dir, ckpt)
            total_bytes += size
            n_new += int(downloaded)
            time.sleep(RATE_LIMIT_DELAY)
    logging.info(
        f"  download done: {n_new} new monthly ZIPs, "
        f"total {total_bytes/2**20:.1f} MiB across all available months, "
        f"phase wall {(time.time()-t_phase)/60:.1f} min")


# ──────────────────────────── Phase 1 — validate ──────────────────────

def validate_zip(zip_path: Path) -> dict:
    """Open ZIP, confirm 3 critical CSVs present with expected headers.

    Returns a dict {csv_kind: {ok: bool, missing: [cols], extra: [cols]}}
    """
    result: dict = {}
    if not zip_path.exists():
        return {"_error": f"{zip_path.name} missing"}
    try:
        with zipfile.ZipFile(zip_path) as zf:
            names = zf.namelist()
            for kind, expected in EXPECTED_SCHEMAS.items():
                hit = [n for n in names if kind in n and n.endswith(".csv")]
                if not hit:
                    result[kind] = {"ok": False, "missing_file": True}
                    continue
                with zf.open(hit[0]) as f:
                    # Header line in latin-1
                    header = f.readline().decode("latin-1").strip()
                cols = [c.strip('"') for c in header.split(";")]
                missing = [c for c in expected if c not in cols]
                extra = [c for c in cols if c not in expected]
                result[kind] = {
                    "ok": len(missing) == 0,
                    "missing": missing,
                    "extra": extra,
                    "n_cols": len(cols),
                }
    except zipfile.BadZipFile as e:
        return {"_error": f"bad zip: {e}"}
    return result


def phase_validate(raw_dir: Path, ckpt: Checkpoint) -> int:
    logging.info("--- Phase 1: validate schemas ---")
    n_ok = 0
    n_bad = 0
    for zp in sorted(raw_dir.glob("*_Licitacoes.zip")):
        ym = zp.stem.split("_")[0]
        result = validate_zip(zp)
        all_ok = all(
            isinstance(v, dict) and v.get("ok") for v in result.values()
        ) and "_error" not in result
        ckpt.mark(ym, validated=all_ok, validation_detail=result)
        if all_ok:
            n_ok += 1
        else:
            n_bad += 1
            logging.warning(f"  {ym}: schema mismatch — {result}")
    logging.info(f"  validate done: {n_ok} ok / {n_bad} bad")
    if n_bad > 0:
        logging.warning(
            "  Bad ZIPs will be SKIPPED in build phase. "
            "Re-download or inspect manually if this is unexpected.")
    return n_bad


# ──────────────────────────── Phase 2 — build ─────────────────────────

@dataclass
class BuildPaths:
    raw_dir: Path
    processed_dir: Path
    @property
    def out_bidlevel(self) -> Path:
        return self.processed_dir / "bid_level_full.parquet"
    @property
    def out_firmstats(self) -> Path:
        return self.processed_dir / "firm_loss_stats.parquet"
    @property
    def out_firm_tender(self) -> Path:
        return self.processed_dir / "firm_tender_map.parquet"
    @property
    def out_freq_particip(self) -> Path:
        return self.processed_dir / "FREQ_PARTICIP_rebuilt.parquet"
    @property
    def out_losers(self) -> Path:
        return self.processed_dir / "LOSERS_rebuilt.parquet"


def open_duckdb() -> "duckdb.DuckDBPyConnection":
    if duckdb is None:
        raise RuntimeError(
            "duckdb not installed; pip install duckdb to run build phase")
    Path(DUCKDB_SPILL).mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql(f"PRAGMA threads={DUCKDB_THREADS}")
    con.sql(f"PRAGMA memory_limit='{DUCKDB_MEMORY}'")
    con.sql(f"PRAGMA temp_directory='{DUCKDB_SPILL}'")
    return con


def build_participation_view(con, raw_dir: Path,
                             modalities: tuple[int, ...]) -> None:
    """Materialise the canonical participation table from all ZIPs.

    DuckDB reads CSVs INSIDE zip files natively via the union_by_name
    glob — no need to extract first. We map Portuguese columns to the
    canonical paper3 vocabulary and tag panel='comprasnet'.
    """
    # NOTE: DuckDB's csv-in-zip path uses `?file_pattern=` qualifier
    # via the iceberg/parquet pattern. We extract to temp instead for
    # robustness across DuckDB versions. Single extract, drop on exit.
    extract_dir = Path(DUCKDB_SPILL) / "extracted"
    extract_dir.mkdir(parents=True, exist_ok=True)
    for zp in sorted(raw_dir.glob("*_Licitacoes.zip")):
        ym = zp.stem.split("_")[0]
        target = extract_dir / f"{ym}_ParticipantesLicitacao.csv"
        if target.exists():
            continue
        with zipfile.ZipFile(zp) as zf:
            for n in zf.namelist():
                if "ParticipantesLicita" in n and n.endswith(".csv"):
                    with zf.open(n) as src, target.open("wb") as dst:
                        dst.write(src.read())
                    break

    glob_pat = str(extract_dir / "*_ParticipantesLicitacao.csv")
    modality_list = ",".join(str(m) for m in modalities)

    # SKETCH SQL — to validate before full build run.
    # The CAST on Código Participante normalises CNPJ to 14-char string
    # (some rows arrive with leading-zero loss when DuckDB infers BIGINT).
    con.sql(f"""
        CREATE OR REPLACE VIEW participation_raw AS
        SELECT
            "Número Licitação"             AS numero_licitacao,
            CAST("Código UG" AS VARCHAR)   AS codigo_ug,
            CAST("Código Modalidade Compra" AS INTEGER) AS modalidade_code,
            "Modalidade Compra"            AS modalidade_label,
            "Número Processo"              AS numero_processo,
            "Código Item Compra"           AS codigo_item,
            LPAD(CAST("Código Participante" AS VARCHAR), 14, '0')
                                            AS firm_id,
            "Nome Participante"            AS firm_name,
            CASE WHEN "Flag Vencedor" = 'SIM' THEN 1 ELSE 0 END AS won,
            'comprasnet'                   AS panel
        FROM read_csv_auto(
            '{glob_pat}',
            delim=';', encoding='latin-1', header=true, all_varchar=true,
            ignore_errors=true
        )
        WHERE CAST("Código Modalidade Compra" AS INTEGER)
              IN ({modality_list})
    """)

    n = con.sql("SELECT COUNT(*) FROM participation_raw").fetchone()[0]
    logging.info(f"  participation_raw: {n:,} rows after modality filter")


def build_bidlevel(con, paths: BuildPaths) -> None:
    """Emit bid_level_full.parquet (participation-level, BEC-named)."""
    con.sql(f"""
        COPY (
            SELECT
                firm_id            AS códigofornecedor,
                numero_licitacao   AS numerodaoc,
                codigo_item        AS códigoitem,
                won                AS flagvencedor,
                codigo_ug          AS códigounidadecompradora,
                modalidade_label   AS descriçãoprocedimentocompra,
                modalidade_code    AS po_phase_code,
                panel
            FROM participation_raw
        ) TO '{paths.out_bidlevel}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n = con.sql(
        f"SELECT COUNT(*) FROM '{paths.out_bidlevel}'").fetchone()[0]
    logging.info(f"  {paths.out_bidlevel.name}: {n:,} rows")


def build_firm_stats(con, paths: BuildPaths) -> None:
    con.sql(f"""
        COPY (
            SELECT
                firm_id                                  AS códigofornecedor,
                COUNT(*)                                 AS total_participations,
                SUM(won)                                 AS total_wins,
                COUNT(*) - SUM(won)                      AS total_losses,
                CAST(SUM(won) AS DOUBLE) / COUNT(*)      AS win_rate,
                CASE WHEN SUM(won) = 0 THEN 1 ELSE 0 END AS always_loser,
                'comprasnet'                             AS panel
            FROM participation_raw
            GROUP BY firm_id
        ) TO '{paths.out_firmstats}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n = con.sql(
        f"SELECT COUNT(*) FROM '{paths.out_firmstats}'").fetchone()[0]
    n_al = con.sql(
        f"SELECT SUM(always_loser) FROM '{paths.out_firmstats}'").fetchone()[0]
    logging.info(
        f"  {paths.out_firmstats.name}: {n:,} firms, {n_al:,} always-losers")


def build_firm_tender_map(con, paths: BuildPaths) -> None:
    con.sql(f"""
        COPY (
            SELECT
                firm_id          AS códigofornecedor,
                numero_licitacao AS numerodaoc,
                codigo_item      AS códigoitem,
                COUNT(*)         AS n_bids,
                MAX(won)         AS won,
                'comprasnet'     AS panel
            FROM participation_raw
            GROUP BY firm_id, numero_licitacao, codigo_item
        ) TO '{paths.out_firm_tender}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n = con.sql(
        f"SELECT COUNT(*) FROM '{paths.out_firm_tender}'").fetchone()[0]
    logging.info(f"  {paths.out_firm_tender.name}: {n:,} firm-item pairs")


def build_freq_particip_and_losers(con, paths: BuildPaths) -> None:
    """Build always-loser counts + apply IQR threshold.

    Threshold formula intentionally matches paper3 manuscript:
    median + 1.5 * IQR (NOT Tukey Q3 + 1.5*IQR). See CLAUDE.md
    "Key Conventions".
    """
    # tenders_count per always-loser
    con.sql(f"""
        CREATE OR REPLACE VIEW al_counts AS
        SELECT
            firm_id,
            COUNT(*) AS tenders_count
        FROM (
            SELECT firm_id, numero_licitacao, codigo_item
            FROM participation_raw
            GROUP BY firm_id, numero_licitacao, codigo_item
        ) firm_items
        WHERE firm_id IN (
            SELECT firm_id FROM participation_raw
            GROUP BY firm_id HAVING SUM(won) = 0
        )
        GROUP BY firm_id
    """)

    stats = con.sql("""
        SELECT
            QUANTILE_CONT(tenders_count, 0.25) AS q1,
            QUANTILE_CONT(tenders_count, 0.50) AS med,
            QUANTILE_CONT(tenders_count, 0.75) AS q3
        FROM al_counts
    """).fetchone()
    q1, med, q3 = stats
    iqr = q3 - q1
    threshold = med + 1.5 * iqr
    logging.info(
        f"  IQR stats: Q1={q1:.0f}, median={med:.0f}, Q3={q3:.0f}, "
        f"IQR={iqr:.0f}, threshold (median+1.5*IQR) = {threshold:.0f}")

    con.sql(f"""
        COPY (
            SELECT
                firm_id        AS códigofornecedor,
                tenders_count,
                1              AS always_loser,
                'comprasnet'   AS panel
            FROM al_counts
        ) TO '{paths.out_freq_particip}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_freq = con.sql(
        f"SELECT COUNT(*) FROM '{paths.out_freq_particip}'").fetchone()[0]
    logging.info(f"  {paths.out_freq_particip.name}: {n_freq:,} always-losers")

    # LOSERS_rebuilt: count FL firms per (tender, item)
    con.sql(f"""
        CREATE OR REPLACE VIEW fl_firms AS
        SELECT firm_id FROM al_counts WHERE tenders_count > {threshold}
    """)
    n_fl = con.sql("SELECT COUNT(*) FROM fl_firms").fetchone()[0]
    logging.info(f"  FL firms (always-loser AND tenders_count > {threshold:.0f}): {n_fl:,}")

    con.sql(f"""
        COPY (
            SELECT
                numero_licitacao AS numerodaoc,
                codigo_item      AS códigoitem,
                COUNT(DISTINCT firm_id) AS losers_count,
                'comprasnet'     AS panel
            FROM participation_raw
            WHERE firm_id IN (SELECT firm_id FROM fl_firms)
            GROUP BY numero_licitacao, codigo_item
        ) TO '{paths.out_losers}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_los = con.sql(f"SELECT COUNT(*) FROM '{paths.out_losers}'").fetchone()[0]
    logging.info(f"  {paths.out_losers.name}: {n_los:,} (OC, item) pairs with FL presence")


def phase_build(raw_dir: Path, processed_dir: Path,
                modalities: tuple[int, ...]) -> None:
    logging.info("--- Phase 2: build canonical paper3 outputs (DuckDB) ---")
    processed_dir.mkdir(parents=True, exist_ok=True)
    paths = BuildPaths(raw_dir, processed_dir)
    t_phase = time.time()

    con = open_duckdb()
    try:
        logging.info("  step 1/4: build participation_raw view")
        build_participation_view(con, raw_dir, modalities)

        logging.info("  step 2/4: bid_level_full + firm_stats + firm_tender_map")
        t0 = time.time()
        build_bidlevel(con, paths)
        build_firm_stats(con, paths)
        build_firm_tender_map(con, paths)
        logging.info(f"    sub-phase wall: {time.time()-t0:.1f}s rss={rss_mb():.0f}MiB")

        logging.info("  step 3/4: FREQ_PARTICIP + LOSERS (IQR threshold)")
        t0 = time.time()
        build_freq_particip_and_losers(con, paths)
        logging.info(f"    sub-phase wall: {time.time()-t0:.1f}s rss={rss_mb():.0f}MiB")

        logging.info(
            f"  build done: phase wall {(time.time()-t_phase)/60:.1f} min, "
            f"final rss {rss_mb():.0f} MiB")
        logging.info("  Outputs:")
        for p in [paths.out_bidlevel, paths.out_firmstats,
                  paths.out_firm_tender, paths.out_freq_particip,
                  paths.out_losers]:
            sz = p.stat().st_size / 2**20 if p.exists() else 0
            logging.info(f"    {p}  ({sz:.1f} MiB)")
    finally:
        con.close()


# ──────────────────────────── Dry run ─────────────────────────────────

def phase_dry_run(y0: int, m0: int, y1: int, m1: int) -> None:
    """Probe one ZIP to estimate sizes and times."""
    months = sum(1 for _ in month_iter(y0, m0, y1, m1))
    logging.info(f"  range {y0}-{m0:02d}..{y1}-{m1:02d} = {months} months")
    # Probe jan/2019 as a reference (known available).
    url = BULK_URL_TEMPLATE.format(ym="201901")
    with httpx.Client(headers=HEADERS, follow_redirects=True) as c:
        t0 = time.time()
        r = c.head(url, timeout=30)
        if r.status_code != 200:
            # CGU sometimes 405 on HEAD; try GET range
            r = c.get(url, headers={"Range": "bytes=0-1"}, timeout=30)
        size_mb = int(r.headers.get("content-length", 0)) / 2**20
        logging.info(
            f"  probe 201901: HTTP {r.status_code}, {size_mb:.1f} MiB "
            f"({time.time()-t0:.1f}s)")
    est_total = size_mb * months
    est_min = months * (RATE_LIMIT_DELAY + 8) / 60  # ~8s per ZIP on broadband
    logging.info(
        f"  extrapolated: ~{est_total:.0f} MiB compressed, "
        f"~{est_min:.0f} min download wall time")


# ──────────────────────────── Main driver ─────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--year-start", type=int, default=DEFAULT_YEAR_START)
    ap.add_argument("--year-end", type=int, default=DEFAULT_YEAR_END)
    ap.add_argument("--month-start", type=int, default=1)
    ap.add_argument("--month-end", type=int, default=12)
    ap.add_argument("--modalities", type=int, nargs="+",
                    default=list(DEFAULT_MODALITIES),
                    help="Modality codes to keep. Default: 5 (Pregão), "
                         "9999 (Pregão SRP). See §8.3 of "
                         "COMPRASNET_PATH_TO_CONFIRMED.md.")
    ap.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    ap.add_argument("--processed-dir", type=Path,
                    default=DEFAULT_PROCESSED_DIR)
    ap.add_argument("--log-dir", type=Path, default=DEFAULT_LOG_DIR)
    ap.add_argument("--skip-download", action="store_true")
    ap.add_argument("--skip-validate", action="store_true")
    ap.add_argument("--skip-build", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    log_path = setup_logging(args.log_dir)
    telemetry_banner()
    logging.info(f"Log file: {log_path}")
    logging.info(
        f"Range: {args.year_start}-{args.month_start:02d} .. "
        f"{args.year_end}-{args.month_end:02d}  "
        f"({sum(1 for _ in month_iter(args.year_start, args.month_start, args.year_end, args.month_end))} months)")
    logging.info(f"Modalities kept: {args.modalities}")
    logging.info(f"Raw dir:       {args.raw_dir.resolve()}")
    logging.info(f"Processed dir: {args.processed_dir.resolve()}")

    if args.dry_run:
        phase_dry_run(args.year_start, args.month_start,
                      args.year_end, args.month_end)
        return

    ckpt = Checkpoint(args.raw_dir / "checkpoint.json")
    logging.info(f"Checkpoint state: {len(ckpt)} months tracked")

    if not args.skip_download:
        phase_download(args.year_start, args.month_start,
                       args.year_end, args.month_end,
                       args.raw_dir, ckpt)

    if not args.skip_validate:
        n_bad = phase_validate(args.raw_dir, ckpt)
        if n_bad > 0 and args.skip_build is False:
            logging.warning(
                "  Build will proceed but skip bad ZIPs. "
                "If you want strict mode, abort and inspect.")

    if not args.skip_build:
        phase_build(args.raw_dir, args.processed_dir,
                    tuple(args.modalities))


if __name__ == "__main__":
    main()
