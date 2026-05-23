#!/usr/bin/env python3
"""
70_rf_enrich.py
===============

Receita Federal "Empresas" base lookup for the 8 CADE rows still
unmatched after RAIS (D1 step 2). RF Empresas is a universal CNPJ
snapshot (active + inactive firms), so it captures firms that left
RAIS before 2015 -- Astéria, Visaplas, etc.

Inputs
------
- data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv
  Rows with enrich_source LIKE 'unmatched%' (8 firms + 5 nameless).
- /home/darciogm1/projetos/comprasnet/data/raw/rf_cnpj_2026_05/Empresas{0..9}.zip
  Schema (CSV Latin-1, ';' delim, no header):
    cnpj_basico ; razao_social ; natureza_juridica ;
    qualificacao_responsavel ; capital_social ; porte_empresa ;
    ente_federativo_responsavel

Output
------
- data/processed_comprasnet/cade_link_v2/cnpjs_rf_candidates.csv
"""

from __future__ import annotations

import csv
import logging
import re
import unicodedata
import zipfile
from difflib import SequenceMatcher
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
CADE_ENRICHED = ROOT / "data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv"
RF_DIR = Path("/home/darciogm1/projetos/comprasnet/data/raw/rf_cnpj_2026_05")
OUT_CSV = ROOT / "data/processed_comprasnet/cade_link_v2/cnpjs_rf_candidates.csv"

STOPWORDS = {
    "LTDA", "SA", "S", "A", "ME", "EPP", "EIRELI",
    "DO", "DA", "DE", "DOS", "DAS", "E", "EM", "BRASIL",
    "COMERCIO", "COMERCIAL", "COM", "INDUSTRIA", "IND",
    "SERVICOS", "SERV", "CIA", "CO", "GROUP", "GRUPO",
    "DISTRIBUIDORA", "FARMACEUTICA",
}
CORP_SUFFIX_RE = re.compile(
    r"\b(LTDA|S\.?A\.?|EIRELI|ME|EPP|"
    r"COMERCIO|COMERCIAL|COM|INDUSTRIA|IND|"
    r"DO BRASIL|BRASIL|SERVICOS|SERV|CIA|CO|GROUP)\b\.?",
    flags=re.IGNORECASE,
)
SPACES_RE = re.compile(r"\s+")
NONALPHA_RE = re.compile(r"[^A-Z0-9 ]+")


def strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def normalize_name(s: str | None) -> str:
    if not s:
        return ""
    s = strip_accents(s).upper()
    s = NONALPHA_RE.sub(" ", s)
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
        for row in csv.DictReader(f):
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
                "uf": (row.get("uf_licitacao") or "").upper(),
            })
    return targets


def find_candidates_for_zip(zip_path: Path, targets: list[dict],
                            con: "duckdb.DuckDBPyConnection") -> list[dict]:
    """Extract Empresas CSV inside ZIP, prefilter via DuckDB, fuzzy-score."""
    extract_dir = Path("/tmp/rf_empresas_extracted")
    extract_dir.mkdir(parents=True, exist_ok=True)
    out_csv = extract_dir / (zip_path.stem + ".csv")
    if not out_csv.exists():
        with zipfile.ZipFile(zip_path) as zf:
            names = zf.namelist()
            target = names[0]  # one CSV per ZIP
            logging.info(f"  extracting {target} from {zip_path.name}")
            with zf.open(target) as src, out_csv.open("wb") as dst:
                while True:
                    chunk = src.read(2 ** 20)
                    if not chunk:
                        break
                    dst.write(chunk)

    all_tokens = set()
    for t in targets:
        all_tokens.update(t["tokens"])
    regex_alts = "|".join(re.escape(tok) for tok in sorted(all_tokens, key=len, reverse=True))

    sql = f"""
        SELECT column0 AS cnpj_basico, column1 AS razao_social
        FROM read_csv(
            '{out_csv}',
            delim=';', encoding='latin-1', header=false,
            quote='\"',
            all_varchar=true, ignore_errors=true,
            columns={{
                'column0': 'VARCHAR', 'column1': 'VARCHAR',
                'column2': 'VARCHAR', 'column3': 'VARCHAR',
                'column4': 'VARCHAR', 'column5': 'VARCHAR',
                'column6': 'VARCHAR'
            }}
        )
        WHERE column1 IS NOT NULL
          AND regexp_matches(upper(column1), '({regex_alts})')
    """
    rows = con.execute(sql).fetchall()
    logging.info(f"  {zip_path.name}: {len(rows):,} prefilter hits")

    hits = []
    for cnpj_basico, raw_razao in rows:
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
                    "cade_uf": t["uf"],
                    "rf_razao_social": raw_razao,
                    "rf_cnpj_basico": str(cnpj_basico).zfill(8) if cnpj_basico else "",
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
    logging.info(f"  {len(targets)} CADE rows still unmatched after RAIS")
    for t in targets:
        logging.info(f"    -> {t['razao_social']:50s} UF={t['uf']:9s} tokens={sorted(t['tokens'])}")

    con = duckdb.connect()
    con.execute("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    all_hits: list[dict] = []
    parquets = sorted(RF_DIR.glob("Empresas*.zip"))
    for p in parquets:
        all_hits.extend(find_candidates_for_zip(p, targets, con))

    by_target: dict = {}
    for h in all_hits:
        by_target.setdefault(h["cade_idx"], []).append(h)

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    fields = ["cade_idx", "cade_name", "cade_uf", "score",
              "rf_razao_social", "rf_cnpj_basico", "shared_tokens", "source_zip"]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for cade_idx, hits in sorted(by_target.items()):
            hits.sort(key=lambda r: -r["score"])
            for h in hits[:5]:
                writer.writerow({k: h.get(k, "") for k in fields})

    logging.info(f"  {len(by_target)} of {len(targets)} targets have candidates")
    logging.info(f"  wrote {OUT_CSV}")


if __name__ == "__main__":
    main()
