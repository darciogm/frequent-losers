#!/usr/bin/env python3
"""
67_rais_enrich.py
=================

RAIS Estabelecimento lookup for CADE rows unmatched after D1 step 1
(BEC reuse). RAIS BR 2009-2017 covers the CADE adjudication window
and is already on disk as parquet at
`paper4-thresholds/RAIS/parquet/estb/BR_{YYYY}_ESTB.parquet`,
4.8 GB total, with columns including Razão Social, CNPJ Raiz,
CNPJ/CEI, ano, UF.

Inputs
------
- data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv
  Rows with enrich_source LIKE 'unmatched%' are candidates.
- paper4-thresholds/RAIS/parquet/estb/BR_{2009..2017}_ESTB.parquet

Output
------
- data/processed_comprasnet/cade_link_v1/cnpjs_rais_candidates.csv
  Audit-style table: cade_idx, cade_name, rais_razao_social,
  rais_cnpj_raiz, rais_cnpj_completo, year, uf, score, shared_tokens.
  Manual inspection before promoting to cnpjs_enriched.csv keeps
  anti-FP discipline (rule learned from Visaplas/OkPlast incident).

Strategy
--------
1. Load CADE unmatched names + normalised tokens.
2. For each RAIS estb parquet, DuckDB filter using token-overlap regex
   AND restrict to states that match the CADE row's UF where set
   (e.g., merenda_escolar SP cartel -> filter UF=SP first).
3. Compute fuzzy score against normalised target. Keep top-5 per
   target with score >= 0.85.
4. Group across years; rank by score then by year (prefer most recent
   match, all else equal).
"""

from __future__ import annotations

import csv
import logging
import re
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
CADE_ENRICHED = ROOT / "data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv"
RAIS_DIR = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS/parquet/harmonized")
OUT_CSV = ROOT / "data/processed_comprasnet/cade_link_v1/cnpjs_rais_candidates.csv"

STOPWORDS = {
    "LTDA", "SA", "S", "A", "ME", "EPP", "EIRELI",
    "DO", "DA", "DE", "DOS", "DAS", "E", "EM", "BRASIL",
    "COMERCIO", "COMERCIAL", "COM", "INDUSTRIA", "IND",
    "SERVICOS", "SERV", "CIA", "CO", "GROUP", "GRUPO",
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
                "uf": (row.get("uf_licitacao") or "").upper(),
                "processo": row.get("numero_processo", ""),
                "setor": row.get("setor", ""),
            })
    return targets


def find_candidates(parquet_path: Path, targets: list[dict],
                    con: "duckdb.DuckDBPyConnection") -> list[dict]:
    """Stream estb parquet via DuckDB; return candidate hits.

    DuckDB does the heavy lifting:
      - Pre-filter by token regex on Razão Social.
      - Project only the columns we need.
    Then Python fuzzy-scores the survivors.
    """
    all_tokens = set()
    for t in targets:
        all_tokens.update(t["tokens"])
    regex_alts = "|".join(re.escape(tok) for tok in sorted(all_tokens, key=len, reverse=True))

    # harmonized parquet has unified schema across 2009-2017
    sql = f"""
        SELECT
            LPAD(CAST(cnpj_raiz AS VARCHAR), 8, '0') AS cnpj_raiz,
            LPAD(CAST(cnpj_cei AS VARCHAR), 14, '0') AS cnpj_completo,
            razao_social AS razao,
            ano,
            uf_arquivo AS uf
        FROM '{parquet_path}'
        WHERE razao_social IS NOT NULL
          AND regexp_matches(upper(razao_social), '({regex_alts})')
        GROUP BY cnpj_raiz, cnpj_cei, razao_social, ano, uf_arquivo
    """
    rows = con.execute(sql).fetchall()
    logging.info(f"  {parquet_path.name}: {len(rows):,} prefilter hits")

    hits = []
    for cnpj_raiz, cnpj_completo, razao, ano, uf in rows:
        if not razao:
            continue
        norm = normalize_name(razao)
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
                    "rais_razao_social": razao,
                    "rais_cnpj_raiz": str(cnpj_raiz).zfill(8) if cnpj_raiz else "",
                    "rais_cnpj_completo": str(cnpj_completo).zfill(14) if cnpj_completo else "",
                    "year": int(ano) if ano else 0,
                    "uf": str(uf) if uf else "",
                    "score": round(score, 3),
                    "shared_tokens": "|".join(sorted(shared)),
                })
    logging.info(f"  {parquet_path.name}: {len(hits)} fuzzy hits at score >= 0.85")
    return hits


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    targets = load_targets(CADE_ENRICHED)
    logging.info(f"  {len(targets)} CADE rows unmatched")
    for t in targets:
        logging.info(f"    -> {t['razao_social']:50s} UF={t['uf']:9s} tokens={sorted(t['tokens'])}")

    con = duckdb.connect()
    con.execute("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    all_hits: list[dict] = []
    parquets = sorted(RAIS_DIR.glob("rais_vinculos_*.parquet"))
    for p in parquets:
        all_hits.extend(find_candidates(p, targets, con))

    # Group by cade_idx; rank by score desc, then most recent year
    by_target: dict = {}
    for h in all_hits:
        by_target.setdefault(h["cade_idx"], []).append(h)

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    fields = ["cade_idx", "cade_name", "cade_uf", "score",
              "rais_razao_social", "rais_cnpj_raiz", "rais_cnpj_completo",
              "year", "uf", "shared_tokens"]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        # Output unique (cade_idx, rais_cnpj_raiz) keeping best year per pair
        for cade_idx, hits in sorted(by_target.items()):
            by_raiz: dict = {}
            for h in hits:
                k = h["rais_cnpj_raiz"]
                if k not in by_raiz or h["score"] > by_raiz[k]["score"]:
                    by_raiz[k] = h
            top = sorted(by_raiz.values(),
                         key=lambda r: (-r["score"], -r["year"]))[:5]
            for h in top:
                writer.writerow({k: h.get(k, "") for k in fields})

    n_targets_hit = len(by_target)
    n_total = len(targets)
    logging.info(f"  {n_targets_hit} of {n_total} targets have candidates")
    logging.info(f"  wrote {OUT_CSV}")


if __name__ == "__main__":
    main()
