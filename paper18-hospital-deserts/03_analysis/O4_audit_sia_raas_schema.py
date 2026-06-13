"""
O4_audit_sia_raas_schema.py

Ground-truth schema audit of the converted SIA/RAAS outpatient parquet
(produced upstream by O3). The whole point is to discover — from the real
files, never from assumed DATASUS layouts — which families carry a usable
MUNICIPALITY OF RESIDENCE (so downstream O6 can do residence-based catchment
analysis) versus only the PROVIDER municipality.

Column names drift across years, so every candidate is matched case-insensitively
against pattern lists; we record WHICH actual column matched each semantic role.

Outputs:
- notes/SIA_RAAS_SCHEMA_AUDIT.md
    human-readable, with a prominent residence-municipality YES/NO/PARTIAL table.
- 02_data/processed/outpatient_mental_health/sia_raas_schema_audit.csv
    machine-readable, one row per (family, target_role, matched_column_name).
    O6 reads THIS to pick residence vs provider fields.

If the converted input dirs are empty (O2/O3 not yet run), logs and exits 0.
"""

from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
from collections import defaultdict
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "04_logs" / "outpatient"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "O4_audit_sia_raas_schema.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("O4")

sys.path.insert(0, str(ROOT / "03_analysis"))
from _telemetry import StepTimer, write_json  # noqa: E402

INTER = ROOT / "02_data" / "intermediate"
PROC_DIR = ROOT / "02_data" / "processed" / "outpatient_mental_health"
NOTES = ROOT / "notes"
CSV_OUT = PROC_DIR / "sia_raas_schema_audit.csv"
MD_OUT = NOTES / "SIA_RAAS_SCHEMA_AUDIT.md"
JSON_OUT = LOG_DIR / "O4_audit_sia_raas_schema.json"

# Family -> base intermediate dir. Each holds family=<fam>/year=<yyyy>/uf=<UF>/*.parquet.
# (file_family is a column too, but the directory partitioning is what O3 wrote.)
FAMILY_DIRS = {
    "sia_pa": INTER / "sia",
    "raas_ps": INTER / "raas",
}

# Provenance columns added by O3 — not DATASUS-original, exclude from candidate matching.
PROVENANCE = {
    "source_system",
    "file_family",
    "uf",
    "year",
    "month",
    "source_filename",
}

# Semantic role -> case-insensitive regex patterns matched against column NAMES.
# Order within a role = preference (first match wins for the "primary" pick, but we
# still record every column that matches any role).
ROLE_PATTERNS: dict[str, list[str]] = {
    # municipality of RESIDENCE (the patient) — what enables catchment analysis
    "residence_muni": [
        r"^PA_MUNPCN$",
        r"^MUNPCN$",
        r"^MUNPAC$",       # RAAS residence field — one letter off from MUNPCN
        r"^MUN_PAC$",
        r"^CODMUNRES$",
        r"^MUNRES$",
        r"MUNPCN",
        r"MUNPAC",
        r"_RES$",
        r"RESID",
    ],
    # municipality of SERVICE / establishment (provider)
    "provider_muni": [
        r"^PA_UFMUN$",
        r"^UFMUN$",
        r"^CODUFMUN$",
        r"^MUNATEN$",
        r"UFMUN",
    ],
    # CNES establishment id
    "cnes": [
        r"^PA_CODUNI$",
        r"^CODUNI$",
        r"^CNES$",
        r"CODUNI",
    ],
    # procedure code. Tightened so the bare token PROC can't grab date columns
    # like DT_PROCESS (a competence date, not a procedure).
    "proc": [
        r"^PA_PROC_ID$",
        r"^PROC_ID$",
        r"^PROC_REA$",
        r"^PA_PROC",
        r"PROC_ID",
        r"PROC_REA",
        r"_PROC$",
    ],
    # CID / diagnosis
    "cid": [
        r"^PA_CIDPRI$",
        r"^CIDPRI$",
        r"^CID$",
        r"CID",
    ],
    # quantity
    "qty": [
        r"^PA_QTDAPR$",
        r"^QTDAPR$",
        r"^QT_.*",
        r"QTD",
    ],
    # approved value
    "value": [
        r"^PA_VALAPR$",
        r"^VALAPR$",
        r"^VL_.*",
        r"VALAPR",
    ],
    "age": [
        r"^NU_IDADE$",
        r"^IDADE$",
        r"IDADE",
    ],
    "sex": [
        r"^SEXO$",
        r"SEXO",
    ],
    # establishment type
    "esttype": [
        r"^TPUPS$",
        r"^TP_UNID$",
        r"TPUPS",
        r"TP_UNID",
    ],
    # competence month/year
    "competence": [
        r"^PA_MVM$",
        r"^PA_CMP$",
        r"^NU_VPA.*",
        r"^MES$",
        r"^ANO$",
    ],
}


def has_input(base: Path) -> bool:
    return base.exists() and any(base.rglob("*.parquet"))


def list_partition_files(base: Path) -> list[tuple[int | None, str | None, str]]:
    """Enumerate (year, uf, path) from the hive partition tree — filesystem only,
    no DuckDB, no row scan. year/uf come from the PATH, so we never depend on the
    in-file year/uf columns being populated."""
    out: list[tuple[int | None, str | None, str]] = []
    for p in base.rglob("*.parquet"):
        year: int | None = None
        uf: str | None = None
        for seg in p.parts:
            if seg.startswith("year="):
                v = seg.split("=", 1)[1]
                year = int(v) if v.isdigit() else None
            elif seg.startswith("uf="):
                uf = seg.split("=", 1)[1] or None
        out.append((year, uf, str(p)))
    return out


def bounded_sample_files(
    files: list[tuple[int | None, str | None, str]], files_per_year: int
) -> list[tuple[int | None, str | None, str]]:
    """Pick at most `files_per_year` files per year, spreading across distinct UFs
    for column coverage. Deterministic (sorted) so reruns are reproducible. This is
    what bounds the scan: we sample tens of files, never the full 5k-file glob."""
    by_year: dict[int | None, list[tuple[int | None, str | None, str]]] = defaultdict(list)
    for rec in files:
        by_year[rec[0]].append(rec)

    picked: list[tuple[int | None, str | None, str]] = []
    for year in sorted(by_year, key=lambda y: (y is None, y)):
        items = sorted(by_year[year], key=lambda t: (t[1] or "", t[2]))
        seen_uf: set[str | None] = set()
        chosen: list[tuple[int | None, str | None, str]] = []
        for rec in items:
            if rec[1] not in seen_uf:
                chosen.append(rec)
                seen_uf.add(rec[1])
            if len(chosen) >= files_per_year:
                break
        if not chosen:  # all UFs identical/None — fall back to first N by path
            chosen = items[:files_per_year]
        picked.extend(chosen)
    return picked


# Date-like column names. These are never a semantic data role here (a DATE is
# not a procedure / cid / etc.), so they're excluded from ALL role matching —
# this is what kept DT_PROCESS from being mis-detected as the procedure code.
DATE_COL = re.compile(r"^(DT_|DATA)|PROCESS|_DT$|^DT")


def match_roles(colname: str) -> list[str]:
    """Return every semantic role whose patterns match this column name."""
    up = colname.upper()
    if DATE_COL.search(up):
        return []
    roles = []
    for role, patterns in ROLE_PATTERNS.items():
        if any(re.search(p, up) for p in patterns):
            roles.append(role)
    return roles


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def quote_lit(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def audit_family(
    con: duckdb.DuckDBPyConnection,
    family: str,
    base: Path,
    sample_rows: int,
    files_per_year: int,
) -> dict:
    """Discover schema + per-column stats for one family WITHOUT scanning the whole
    corpus. SIA-PA alone is ~103 GB / 5k files of 1.16M-row, 61-col tables; the old
    path globbed all of it with union_by_name and a per-year reservoir, and the
    in-file year/uf columns collide with the hive keys so `WHERE year=...` stopped
    pruning — every per-year branch re-scanned the full glob and blew the memory
    limit. Here the year/UF extent and schema come from the partition PATHS and
    parquet footers (metadata only), and row stats are read from a bounded, explicit
    list of files (a few per year) — a single SIA-PA file already yields 1.16M
    sample rows, so tens of files are ample and memory stays flat."""
    files = list_partition_files(base)
    if not files:
        return {
            "family": family, "n_sampled": 0, "columns": [],
            "years_present": [], "ufs_present": [], "drift": {}, "candidates": [],
        }

    years_present_all = sorted(
        {str(y) for (y, _, _) in files if y is not None}
    )
    ufs_present_all = sorted({uf for (_, uf, _) in files if uf})

    sample_files = bounded_sample_files(files, files_per_year)

    # Schema + drift from metadata (footers), not row data. drift[col] = years where
    # the column appears in any sampled file of that year — an exact structural view,
    # not the old "non-null in a sampled row" approximation.
    file_year: dict[str, int | None] = {p: y for (y, _, p) in sample_files}
    cols_by_year: dict[str, set[str]] = defaultdict(set)
    col_union: list[str] = []
    seen_cols: set[str] = set()
    for (_, _, p) in sample_files:
        fcols = [
            r[0]
            for r in con.execute(
                f"DESCRIBE SELECT * FROM read_parquet({quote_lit(p)})"
            ).fetchall()
        ]
        yk = str(file_year[p]) if file_year[p] is not None else "NA"
        for c in fcols:
            cols_by_year[yk].add(c)
            if c not in seen_cols:
                seen_cols.add(c)
                col_union.append(c)
    columns = col_union

    drift: dict[str, list[str]] = {}
    for col in columns:
        if col in PROVENANCE:
            continue
        drift[col] = [
            y for y in years_present_all if col in cols_by_year.get(y, set())
        ]

    # Row stats over a BOUNDED explicit file list. union_by_name now spans tens of
    # files (not 5k); hive_partitioning=false sidesteps the year/uf name collision
    # (we already have year/uf from the paths). The reservoir caps the temp table,
    # and the feeding scan is streaming, so peak memory is a fraction of the limit.
    file_list = ", ".join(quote_lit(p) for (_, _, p) in sample_files)
    src = (
        f"read_parquet([{file_list}], union_by_name=true, "
        f"filename=true, hive_partitioning=false)"
    )
    con.execute(
        f"CREATE OR REPLACE TEMP TABLE smp AS "
        f"SELECT * FROM {src} USING SAMPLE reservoir({int(sample_rows)} ROWS)"
    )
    n_sampled = con.execute("SELECT COUNT(*) FROM smp").fetchone()[0]

    # Per-candidate stats: only for columns matching at least one semantic role.
    candidates = []
    for col in columns:
        if col in PROVENANCE:
            continue
        roles = match_roles(col)
        if not roles:
            continue
        qi = quote_ident(col)
        stat = con.execute(
            f"SELECT COUNT(*) AS n, COUNT({qi}) AS nn, "
            f"COUNT(DISTINCT {qi}) AS nd FROM smp"
        ).fetchone()
        n, nn, nd = stat
        non_missing_rate = (nn / n) if n else 0.0
        examples = [
            str(r[0])
            for r in con.execute(
                f"SELECT DISTINCT {qi} FROM smp "
                f"WHERE {qi} IS NOT NULL LIMIT 5"
            ).fetchall()
        ]
        years_for_col = drift.get(col, years_present_all)
        for role in roles:
            candidates.append(
                {
                    "family": family,
                    "target_role": role,
                    "matched_column_name": col,
                    "non_missing_rate": round(non_missing_rate, 4),
                    "n_distinct": int(nd),
                    "example_values": "; ".join(examples),
                    "years_present": ",".join(years_for_col),
                }
            )

    log.info(
        "[%s] sampled=%d cols=%d candidate_rows=%d years=%s ufs=%d",
        family,
        n_sampled,
        len(columns),
        len(candidates),
        ",".join(years_present_all) or "-",
        len(ufs_present_all),
    )

    return {
        "family": family,
        "n_sampled": int(n_sampled),
        "columns": columns,
        "years_present": years_present_all,
        "ufs_present": ufs_present_all,
        "drift": drift,
        "candidates": candidates,
    }


def residence_verdict(cands: list[dict]) -> tuple[str, float, str]:
    """YES / PARTIAL / NO for residence-municipality usability, by best non-missing rate."""
    res = [c for c in cands if c["target_role"] == "residence_muni"]
    if not res:
        return "NO", 0.0, ""
    best = max(res, key=lambda c: c["non_missing_rate"])
    rate = best["non_missing_rate"]
    if rate >= 0.95:
        return "YES", rate, best["matched_column_name"]
    if rate > 0.0:
        return "PARTIAL", rate, best["matched_column_name"]
    return "NO", rate, best["matched_column_name"]


def write_csv(all_candidates: list[dict]) -> None:
    PROC_DIR.mkdir(parents=True, exist_ok=True)
    fields = [
        "family",
        "target_role",
        "matched_column_name",
        "non_missing_rate",
        "n_distinct",
        "example_values",
        "years_present",
    ]
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for row in all_candidates:
            w.writerow(row)


def write_md(reports: list[dict]) -> None:
    NOTES.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    lines.append("# SIA / RAAS outpatient schema audit\n")
    lines.append(
        "Auto-generated by `03_analysis/O4_audit_sia_raas_schema.py`. Columns and "
        "stats are discovered from the real converted parquet (sampled, "
        "`union_by_name=true`) — nothing is assumed from DATASUS layouts.\n"
    )

    # Prominent residence-municipality verdict table.
    lines.append("## Does each family carry MUNICIPALITY OF RESIDENCE?\n")
    lines.append(
        "| family | residence muni? | non-missing rate | matched column | catchment-analysis usable |"
    )
    lines.append("|---|---|---|---|---|")
    for rep in reports:
        verdict, rate, col = residence_verdict(rep["candidates"])
        usable = "yes" if verdict == "YES" else ("partial" if verdict == "PARTIAL" else "NO — provider-only")
        lines.append(
            f"| `{rep['family']}` | **{verdict}** | {rate:.2%} | "
            f"{('`' + col + '`') if col else '—'} | {usable} |"
        )
    lines.append("")
    flagged = [
        rep["family"]
        for rep in reports
        if residence_verdict(rep["candidates"])[0] == "NO"
    ]
    if flagged:
        lines.append(
            "> **LIMITATION:** the following families lack a usable residence "
            "municipality and are **LIMITED to provider-municipality analysis**: "
            + ", ".join(f"`{f}`" for f in flagged)
            + ".\n"
        )

    # Per-family detail.
    for rep in reports:
        fam = rep["family"]
        lines.append(f"## Family `{fam}`\n")
        lines.append(
            f"- rows sampled: {rep['n_sampled']:,}\n"
            f"- years present: {', '.join(rep['years_present']) or '—'}\n"
            f"- UFs present: {len(rep['ufs_present'])} "
            f"({', '.join(rep['ufs_present'][:10])}{'…' if len(rep['ufs_present']) > 10 else ''})\n"
            f"- total columns: {len(rep['columns'])}\n"
        )

        lines.append("### Candidate columns by semantic role\n")
        lines.append(
            "| target_role | matched column | non-missing | n_distinct | examples | years |"
        )
        lines.append("|---|---|---|---|---|---|")
        for c in sorted(rep["candidates"], key=lambda x: (x["target_role"], -x["non_missing_rate"])):
            ex = c["example_values"][:60].replace("|", "\\|")
            lines.append(
                f"| {c['target_role']} | `{c['matched_column_name']}` | "
                f"{c['non_missing_rate']:.2%} | {c['n_distinct']} | {ex} | "
                f"{c['years_present']} |"
            )
        lines.append("")

        # Schema drift: years where the present-column set changes.
        drift = rep["drift"]
        if drift and rep["years_present"]:
            sig_by_year: dict[str, set] = {}
            for col, yrs in drift.items():
                for y in yrs:
                    sig_by_year.setdefault(y, set()).add(col)
            ordered = sorted(sig_by_year)
            changes = []
            prev = None
            for y in ordered:
                cur = sig_by_year[y]
                if prev is None:
                    changes.append((y, "baseline", len(cur)))
                else:
                    added = cur - prev
                    dropped = prev - cur
                    if added or dropped:
                        changes.append(
                            (
                                y,
                                f"+{sorted(added)} -{sorted(dropped)}"
                                if (added or dropped)
                                else "no change",
                                len(cur),
                            )
                        )
                prev = cur
            lines.append("### Schema drift (years where the column set changes)\n")
            lines.append("| year | change | n cols present |")
            lines.append("|---|---|---|")
            for y, ch, n in changes:
                ch_s = str(ch)[:90].replace("|", "\\|")
                lines.append(f"| {y} | {ch_s} | {n} |")
            lines.append("")

        lines.append("### All columns (union across years)\n")
        lines.append(", ".join(f"`{c}`" for c in rep["columns"]) + "\n")

    MD_OUT.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit converted SIA/RAAS schema.")
    ap.add_argument("--force", action="store_true", help="rerun even if outputs exist")
    ap.add_argument(
        "--families",
        choices=["sia_pa", "raas_ps", "all"],
        default="all",
        help="which family/families to audit",
    )
    ap.add_argument(
        "--sample-rows",
        type=int,
        default=200_000,
        help="reservoir row cap for per-column stats (drawn from the sampled files)",
    )
    ap.add_argument(
        "--files-per-year",
        type=int,
        default=3,
        help="parquet files sampled per year per family (bounds the scan). "
        "One SIA-PA file is ~1.16M rows, so a few per year is ample.",
    )
    args = ap.parse_args()

    timer = StepTimer(log)

    if not args.force and CSV_OUT.exists() and CSV_OUT.stat().st_size > 100:
        log.info("outputs exist (%s); use --force to rerun. Skipping.", CSV_OUT)
        write_json(JSON_OUT, {"status": "skipped_existing"})
        return 0

    families = (
        list(FAMILY_DIRS) if args.families == "all" else [args.families]
    )

    present = {fam: FAMILY_DIRS[fam] for fam in families if has_input(FAMILY_DIRS[fam])}
    if not present:
        log.info("no converted input found; run O2/O3 first")
        write_json(JSON_OUT, {"status": "no_input", "families_requested": families})
        return 0

    # Spill to real disk. /tmp is tmpfs on some DarcioWork mounts (spill there would
    # land back in RAM); /var/tmp is the on-disk fallback the machine rules mandate.
    spill = Path("/var/tmp/duckdb_spill")
    spill.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='12GB'")
    con.execute(f"PRAGMA temp_directory='{spill}'")

    reports = []
    for fam, base in present.items():
        try:
            reports.append(
                audit_family(con, fam, base, args.sample_rows, args.files_per_year)
            )
        except Exception as e:  # noqa: BLE001 — one bad family shouldn't sink the rest
            log.exception("family %s failed: %s", fam, e)
        timer.mark(f"audit_{fam}")

    if not reports:
        log.info("no family produced a report; nothing to write")
        write_json(JSON_OUT, {"status": "no_report"})
        return 0

    all_candidates = [c for rep in reports for c in rep["candidates"]]
    write_csv(all_candidates)
    write_md(reports)
    timer.mark("write_outputs")

    summary = {
        "status": "ok",
        "families_audited": [r["family"] for r in reports],
        "candidate_rows": len(all_candidates),
        "residence_verdict": {
            r["family"]: residence_verdict(r["candidates"])[0] for r in reports
        },
        "csv": str(CSV_OUT),
        "md": str(MD_OUT),
    }
    write_json(JSON_OUT, summary)
    log.info("done: %s", summary["residence_verdict"])
    log.info("CSV -> %s", CSV_OUT)
    log.info("MD  -> %s", MD_OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
