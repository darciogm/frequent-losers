#!/usr/bin/env python3
"""
67_rf_base_enrich.py
====================

Receita Federal Empresas base lookup for CADE rows unmatched after
D1 step 1 (BEC reuse). Produces an enriched CNPJ list to feed
linkage v2.

Inputs
------
- data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv
  Rows with enrich_source LIKE 'unmatched%' are candidates.
- /home/darciogm1/projetos/comprasnet/data/raw/rf_cnpj_2026_05_10/Empresas{0..9}.zip
  Open-data Receita Federal Empresas tables (CC-BY). Schema (CSV,
  Latin-1, ';' delimited, no header):
    cnpj_basico (8 chars) ; razao_social ; natureza_juridica ;
    qualificacao_responsavel ; capital_social ; porte_empresa ;
    ente_federativo_responsavel

Output
------
- data/processed_comprasnet/cade_link_v1/cnpjs_rf_candidates.csv
  Candidate matches with similarity scores. Manual review recommended
  before promoting to cnpjs_enriched.csv.

Strategy
--------
1. Load CADE unmatched names + normalised tokens.
2. For each ZIP, stream Empresas CSV via DuckDB. Filter rows whose
   normalised razao_social shares at least one token with any target.
3. Compute fuzzy similarity (Jaro-Winkler proxy via SequenceMatcher).
4. For each target, keep top-3 candidates with score >= 0.85.
5. Write audit CSV; do NOT auto-promote (manual review keeps
   anti-FP discipline).
"""

from __future__ import annotations

import csv
import logging
import re
import sys
import unicodedata
import zipfile
from difflib import SequenceMatcher
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
CADE_ENRICHED = ROOT / "data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv"
RF_DIR = Path.home() / "projetos/comprasnet/data/raw/rf_cnpj_2026_05_10"
OUT_CSV = ROOT / "data/processed_comprasnet/cade_link_v1/cnpjs_rf_candidates.csv"

# Words ignored when checking token overlap (too generic to anchor a match)
STOPWORDS = {
    "LTDA", "SA", "S", "A", "ME", "EPP", "EIRELI",
    "DO", "DA", "DE", "DOS", "DAS", "E", "EM", "BRASIL",
    "COMERCIO", "COMERCIAL", "COM", "INDUSTRIA", "IND",
    "SERVICOS", "SERV", "CIA", "CO", "GROUP", "GRUPO",
}

CORP_SUFFIX_RE = re.compile(
    r"\b(LTDA|S\.?A\.?|EIRELI|ME|EPP|"
    r"COMERCIO|COMERCIAL|COM|INDUSTRIA|IND|"
    r"DO BRASIL|BRASIL|"
    r"SERVICOS|SERV|"
    r"CIA|CO|GROUP)\b\.?",
    flags=re.IGNORECASE,
)
SPACES_RE = re.compile(r"\s+")


def strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def normalize_name(s: str | None) -> str:
    if not s:
        return ""
    s = strip_accents(s).upper()
    s = re.sub(r"[^A-Z0-9 ]+", " ", s)
    s = CORP_SUFFIX_RE.sub(" ", s)
    s = SPACES_RE.sub(" ", s).strip()
    return s


def informative_tokens(s: str) -> set[str]:
    return {t for t in s.split() if len(t) >= 3 and t not in STOPWORDS}


def fuzzy_ratio(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


def load_targets(path: Path) -> list[dict]:
    targets = []
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get("enrich_source", "").startswith("unmatched"):
                continue
            name = (row.get("razao_social") or "").strip()
            if not name:
                continue
            norm = normalize_name(name)
            tokens = informative_tokens(norm)
            if not tokens:
                continue
            targets.append({
                "cade_idx": row["cade_idx"],
                "razao_social": name,
                "norm": norm,
                "tokens": tokens,
                "processo": row.get("numero_processo", ""),
                "setor": row.get("setor", ""),
            })
    return targets


def find_candidates_for_zip(zip_path: Path, targets: list[dict],
                            con: "duckdb.DuckDBPyConnection") -> list[dict]:
    """Stream Empresas CSV inside ZIP via DuckDB; return candidate hits.

    DuckDB does NOT read CSV inside ZIP directly in older versions,
    so we extract to a temp file first.
    """
    extract_dir = Path("/tmp/rf_extracted")
    extract_dir.mkdir(parents=True, exist_ok=True)
    out_csv = extract_dir / (zip_path.stem + ".csv")
    if not out_csv.exists():
        with zipfile.ZipFile(zip_path) as zf:
            names = [n for n in zf.namelist() if n.endswith((".csv", ".EMPRECSV"))
                     or "EMPRE" in n.upper()]
            if not names:
                logging.warning(f"  no Empresas CSV in {zip_path.name}")
                return []
            target = names[0]
            with zf.open(target) as src, out_csv.open("wb") as dst:
                while True:
                    chunk = src.read(2**20)
                    if not chunk:
                        break
                    dst.write(chunk)

    # Build a regex of "any informative token" for cheap pre-filter
    all_tokens = set()
    for t in targets:
        all_tokens.update(t["tokens"])
    # Pre-filter via DuckDB regex (LIKE list)
    regex_alts = "|".join(re.escape(tok) for tok in sorted(all_tokens, key=len, reverse=True))
    sql = f"""
        SELECT column0 AS cnpj_basico, column1 AS razao_social
        FROM read_csv(
            '{out_csv}',
            delim=';', encoding='latin-1', header=false,
            all_varchar=true, ignore_errors=true,
            columns={{
                'column0': 'VARCHAR', 'column1': 'VARCHAR',
                'column2': 'VARCHAR', 'column3': 'VARCHAR',
                'column4': 'VARCHAR', 'column5': 'VARCHAR',
                'column6': 'VARCHAR'
            }}
        )
        WHERE regexp_matches(upper(strip_accents(column1)), '({regex_alts})')
    """
    # DuckDB has no strip_accents UDF; use plain upper() and let token compare in Python
    sql = sql.replace("strip_accents(column1)", "column1")
    rows = con.execute(sql).fetchall()
    logging.info(f"  {zip_path.name}: {len(rows):,} prefilter hits")

    hits = []
    for cnpj_basico, raw_razao in rows:
        if not raw_razao:
            continue
        norm = normalize_name(raw_razao)
        cand_tokens = informative_tokens(norm)
        for t in targets:
            shared = t["tokens"] & cand_tokens
            if not shared:
                continue
            score = fuzzy_ratio(t["norm"], norm)
            if score >= 0.85:
                hits.append({
                    "cade_idx": t["cade_idx"],
                    "cade_name": t["razao_social"],
                    "rf_razao_social": raw_razao,
                    "rf_cnpj_basico": cnpj_basico,
                    "score": round(score, 3),
                    "shared_tokens": "|".join(sorted(shared)),
                    "source_zip": zip_path.name,
                })
    logging.info(f"  {zip_path.name}: {len(hits)} fuzzy hits at score >= 0.85")
    return hits


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    targets = load_targets(CADE_ENRICHED)
    logging.info(f"  {len(targets)} CADE rows still unmatched after D1 step 1")
    for t in targets:
        logging.info(f"    -> {t['razao_social']:50s} tokens={sorted(t['tokens'])}")

    con = duckdb.connect()
    con.execute("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    all_hits: list[dict] = []
    for zip_path in sorted(RF_DIR.glob("Empresas*.zip")):
        all_hits.extend(find_candidates_for_zip(zip_path, targets, con))

    # Group by cade_idx, keep top-5 per target by score
    by_target: dict = {}
    for h in all_hits:
        by_target.setdefault(h["cade_idx"], []).append(h)

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "cade_idx", "cade_name", "score", "rf_razao_social",
            "rf_cnpj_basico", "shared_tokens", "source_zip",
        ])
        writer.writeheader()
        for cade_idx, hits in sorted(by_target.items()):
            hits.sort(key=lambda r: -r["score"])
            for h in hits[:5]:
                writer.writerow({k: h.get(k, "") for k in writer.fieldnames})
    n_targets_hit = len(by_target)
    n_rows_written = sum(min(len(v), 5) for v in by_target.values())
    logging.info(f"  {n_targets_hit} of {len(targets)} targets have candidates")
    logging.info(f"  {n_rows_written} candidate rows written to {OUT_CSV}")


if __name__ == "__main__":
    main()
