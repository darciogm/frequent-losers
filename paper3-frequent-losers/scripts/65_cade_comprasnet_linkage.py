#!/usr/bin/env python3
"""
65_cade_comprasnet_linkage.py
=============================

Build CADE × ComprasNet federal ground-truth linkage for v20.

Stage 1c, version 1 — uses only BEC crossmatch reuse (D1 step 1) for
CNPJ enrichment. v2 will re-run after Receita Federal base
enrichment (D1 step 2) if necessary.

Inputs
------
- data/processed/cade_carteis_licitacoes_2009_2019.csv     (65 rows, 25 with CNPJ)
- data/processed/cade_bec_crossmatch.csv                   (49 firms with CNPJ from BEC pipeline)
- data/processed_comprasnet/bid_level_full.parquet         (51.3M participation rows)
- data/processed_comprasnet/firm_loss_stats.parquet
- data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet  (35,943 always-losers; FL = tenders_count >= 32)

Outputs (data/processed_comprasnet/cade_link_v1/)
-------------------------------------------------
- cnpjs_enriched.csv              (CADE row × CNPJ, after BEC reuse + match audit)
- direct_defendants_federal.parquet
- cobidders_federal.parquet
- anchored_tenders_federal.parquet
- summary.md                      (markdown sanity report)

Decisions encoded
-----------------
- D2 (federal-vs-state): inclusive — any CADE-convicted firm with
  federal participation enters as positive. case_scope column flags
  Nacional vs state for downstream sub-analysis.
- D3 (ordering): this is the v1 POC. Output dir is `cade_link_v1/`
  to allow versioning; v2 would write to `cade_link_v2/`.
- Fuzzy match: difflib.SequenceMatcher.ratio() ≥ 0.85 on normalized
  razão social. Manual audit log written to summary.md for all fuzzy
  matches so they can be inspected and reverted.

Usage
-----
    python scripts/65_cade_comprasnet_linkage.py
    python scripts/65_cade_comprasnet_linkage.py --fuzzy-threshold 0.80   # looser
    python scripts/65_cade_comprasnet_linkage.py --out-version v2         # next run after RF base
"""

from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent

CADE_CSV = ROOT / "data" / "processed" / "cade_carteis_licitacoes_2009_2019.csv"
BEC_XMATCH_CSV = ROOT / "data" / "processed" / "cade_bec_crossmatch.csv"
COMPRASNET_DIR = ROOT / "data" / "processed_comprasnet"

NACIONAL_UF = {"NACIONAL", "BRASIL", "BR"}

# ─────────────────────── normalisation helpers ──────────────────────

def strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


CORP_SUFFIX_RE = re.compile(
    r"\b(LTDA|S\.?A\.?|EIRELI|ME|EPP|"
    r"COMERCIO|COMERCIAL|COM|INDUSTRIA|IND|"
    r"DO BRASIL|BRASIL|"
    r"SERVICOS|SERV|"
    r"CIA|CO|GROUP)\b\.?",
    flags=re.IGNORECASE,
)
SPACES_RE = re.compile(r"\s+")


def normalize_name(s: str | None) -> str:
    if not s:
        return ""
    s = strip_accents(s).upper()
    s = re.sub(r"[^A-Z0-9 ]+", " ", s)
    s = CORP_SUFFIX_RE.sub(" ", s)
    s = SPACES_RE.sub(" ", s).strip()
    return s


def fuzzy_ratio(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


# ─────────────────────── CNPJ helpers ───────────────────────────────

CNPJ_DIGITS_RE = re.compile(r"\D")


def clean_cnpj(s: str | None) -> str | None:
    if not s:
        return None
    digits = CNPJ_DIGITS_RE.sub("", str(s))
    if len(digits) == 14:
        return digits
    if 8 <= len(digits) < 14:
        return digits.zfill(14)
    return None


def cnpj_raiz(cnpj14: str | None) -> str | None:
    if not cnpj14 or len(cnpj14) != 14:
        return None
    return cnpj14[:8]


# ─────────────────────── core pipeline ──────────────────────────────

def load_cade(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            cnpj = clean_cnpj(r.get("cnpj"))
            rows.append({
                "cade_idx": len(rows),
                "cnpj14": cnpj,
                "cnpj_raiz_original": cnpj_raiz(cnpj),
                "razao_social": (r.get("razao_social") or "").strip(),
                "razao_norm": normalize_name(r.get("razao_social")),
                "numero_processo": (r.get("numero_processo") or "").strip(),
                "data_julgamento": (r.get("data_julgamento") or "").strip(),
                "setor": (r.get("setor") or "").strip(),
                "uf_licitacao": (r.get("uf_licitacao") or "").strip().upper(),
                "tipo_conduta": (r.get("tipo_conduta") or "").strip(),
                "multa_reais": (r.get("multa_reais") or "").strip(),
                "notas": (r.get("notas") or "").strip(),
            })
    logging.info(f"  loaded {len(rows)} CADE rows ({sum(1 for r in rows if r['cnpj14'])} with CNPJ)")
    return rows


def load_bec_xmatch(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            cnpj = clean_cnpj(r.get("firm_cnpj") or r.get("fornecedor"))
            if not cnpj:
                continue
            rows.append({
                "cnpj14": cnpj,
                "cnpj_raiz": cnpj_raiz(cnpj),
                "razao_bec_norm": normalize_name(r.get("razao_bec")),
                "cade_name_norm": normalize_name(r.get("cade_name")),
                "razao_bec": (r.get("razao_bec") or "").strip(),
                "cade_name": (r.get("cade_name") or "").strip(),
                "is_FL_bec": (r.get("is_FL") or "").strip().lower() == "true",
                "is_AL_bec": (r.get("is_always_loser") or "").strip().lower() == "true",
            })
    logging.info(f"  loaded {len(rows)} BEC crossmatch firms")
    return rows


def enrich_via_bec(cade: list[dict], bec: list[dict],
                   fuzzy_threshold: float) -> list[dict]:
    """Match each CADE row without CNPJ to BEC crossmatch via fuzzy razão.

    Returns audit list. Updates cade rows in-place with cnpj14,
    cnpj_raiz_enriched, enrich_source, enrich_score.

    Anti-false-positive rules (added 2026-05-22 after Visaplas/OkPlast
    incident):
      1. Score must be >= fuzzy_threshold (default 0.92, was 0.85).
      2. NO CNPJ may be assigned to more than one CADE row via
         fuzzy matching. If duplicate, KEEP the higher-score match;
         demote the other to unmatched + log.
      3. Match must share at least one of: processo, setor heuristic
         — currently only logged; not enforced (heuristic too brittle).
    """
    audit = []
    for c in cade:
        if c["cnpj14"]:
            continue
        best = (None, 0.0, None)
        for b in bec:
            r1 = fuzzy_ratio(c["razao_norm"], b["razao_bec_norm"])
            r2 = fuzzy_ratio(c["razao_norm"], b["cade_name_norm"])
            r = max(r1, r2)
            if r > best[1]:
                best = (b, r, "razao_bec" if r1 >= r2 else "cade_name")
        b_match, score, match_field = best
        if b_match and score >= fuzzy_threshold:
            c["cnpj14"] = b_match["cnpj14"]
            c["cnpj_raiz_enriched"] = b_match["cnpj_raiz"]
            c["enrich_source"] = "bec_reuse"
            c["enrich_score"] = round(score, 3)
            audit.append({
                "cade_idx": c["cade_idx"],
                "cade_name": c["razao_social"],
                "bec_match": b_match["razao_bec"],
                "field": match_field,
                "score": round(score, 3),
                "cnpj14": b_match["cnpj14"],
                "demoted": "",
            })
        else:
            c["enrich_source"] = "unmatched"
            c["enrich_score"] = round(score, 3) if b_match else 0.0
            audit.append({
                "cade_idx": c["cade_idx"],
                "cade_name": c["razao_social"],
                "bec_match": b_match["razao_bec"] if b_match else "",
                "field": match_field if match_field else "",
                "score": round(score, 3) if b_match else 0.0,
                "cnpj14": "",
                "demoted": "",
            })

    # Anti-false-positive rule 2: CNPJ uniqueness. If a single CNPJ is
    # assigned to multiple CADE rows via fuzzy match, keep the highest-
    # score one and demote the rest.
    cnpj_to_rows: dict[str, list[dict]] = {}
    for c in cade:
        if c.get("enrich_source") == "bec_reuse" and c["cnpj14"]:
            cnpj_to_rows.setdefault(c["cnpj14"], []).append(c)
    n_demoted = 0
    for cnpj, rows in cnpj_to_rows.items():
        if len(rows) <= 1:
            continue
        # Sort by score descending; demote all but the first
        rows.sort(key=lambda r: -(r.get("enrich_score") or 0.0))
        kept = rows[0]
        for r in rows[1:]:
            # Find audit entry and update; clear assignment on cade row
            for a in audit:
                if a["cade_idx"] == r["cade_idx"]:
                    a["demoted"] = f"duplicate-cnpj-of:{kept['razao_social']}"
                    break
            r["cnpj14"] = None
            r["cnpj_raiz_enriched"] = None
            r["enrich_source"] = "unmatched_duplicate_cnpj"
            n_demoted += 1
            logging.warning(
                f"  DEMOTED duplicate-cnpj match: {r['razao_social']} → {cnpj} "
                f"(score {r.get('enrich_score'):.3f}; kept {kept['razao_social']})")

    # Fill cnpj_raiz_enriched for originally-known
    for c in cade:
        if c["cnpj14"] and "cnpj_raiz_enriched" not in c:
            c["cnpj_raiz_enriched"] = cnpj_raiz(c["cnpj14"])
            c["enrich_source"] = "cade_original"
            c["enrich_score"] = 1.0

    n_total = len(cade)
    n_original = sum(1 for c in cade if c.get("enrich_source") == "cade_original")
    n_bec = sum(1 for c in cade if c.get("enrich_source") == "bec_reuse")
    n_unmatched = sum(1 for c in cade if c.get("enrich_source") in
                     ("unmatched", "unmatched_duplicate_cnpj"))
    logging.info(
        f"  enrichment: {n_original} from CADE original + {n_bec} from BEC reuse "
        f"+ {n_unmatched} still unmatched (fuzzy ≥ {fuzzy_threshold}, "
        f"{n_demoted} demoted as duplicate-CNPJ) = {n_total} rows total")
    return audit


def write_cnpjs_enriched(cade: list[dict], audit: list[dict], out_dir: Path) -> None:
    csv_path = out_dir / "cnpjs_enriched.csv"
    fields = [
        "cade_idx", "razao_social", "numero_processo", "data_julgamento",
        "setor", "uf_licitacao", "cnpj14", "cnpj_raiz_enriched",
        "enrich_source", "enrich_score",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for c in cade:
            w.writerow({k: c.get(k, "") for k in fields})
    logging.info(f"  wrote {csv_path}")

    audit_path = out_dir / "cnpjs_fuzzy_audit.csv"
    with audit_path.open("w", newline="", encoding="utf-8") as f:
        if audit:
            w = csv.DictWriter(f, fieldnames=list(audit[0].keys()))
            w.writeheader()
            w.writerows(audit)
    logging.info(f"  wrote {audit_path}")


# ─────────────────────── ComprasNet linkage ─────────────────────────

def build_federal_sets(con, cade: list[dict], out_dir: Path,
                       bid_level: Path, freq_particip: Path,
                       fl_threshold: int) -> dict:
    raizes = sorted({c["cnpj_raiz_enriched"] for c in cade if c.get("cnpj_raiz_enriched")})
    if not raizes:
        raise RuntimeError("no CNPJs enriched — cannot proceed")

    con.sql(f"PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # Materialise CADE raiz set with metadata (UF, processo, setor) for case_scope tagging
    raiz_rows = []
    for c in cade:
        r = c.get("cnpj_raiz_enriched")
        if not r:
            continue
        case_scope = (
            "national" if c["uf_licitacao"] in NACIONAL_UF
            else "state"
        )
        raiz_rows.append({
            "cnpj_raiz": r,
            "razao_cade": c["razao_social"],
            "processo": c["numero_processo"],
            "setor": c["setor"],
            "uf_caso": c["uf_licitacao"],
            "case_scope": case_scope,
            "enrich_source": c.get("enrich_source"),
            "enrich_score": c.get("enrich_score"),
        })

    # Load raiz_rows into duckdb. Build a tmp table to enable JOINs.
    con.execute("DROP TABLE IF EXISTS cade_raiz")
    con.execute("""
        CREATE TABLE cade_raiz (
            cnpj_raiz VARCHAR, razao_cade VARCHAR, processo VARCHAR,
            setor VARCHAR, uf_caso VARCHAR, case_scope VARCHAR,
            enrich_source VARCHAR, enrich_score DOUBLE
        )
    """)
    con.executemany(
        "INSERT INTO cade_raiz VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(r["cnpj_raiz"], r["razao_cade"], r["processo"], r["setor"],
          r["uf_caso"], r["case_scope"], r["enrich_source"], r["enrich_score"])
         for r in raiz_rows]
    )
    n_raizes = con.sql("SELECT COUNT(DISTINCT cnpj_raiz) FROM cade_raiz").fetchone()[0]
    logging.info(f"  cade_raiz: {n_raizes} distinct CNPJ raízes loaded")

    # Direct defendants — any federal participation under matched raízes
    direct_path = out_dir / "direct_defendants_federal.parquet"
    con.sql(f"""
        COPY (
            WITH bl AS (
                SELECT
                    códigofornecedor AS firm_id,
                    SUBSTR(códigofornecedor, 1, 8) AS cnpj_raiz,
                    numerodaoc, códigoitem,
                    flagvencedor, po_phase_code
                FROM '{bid_level}'
            ),
            firm_agg AS (
                SELECT
                    firm_id,
                    ANY_VALUE(cnpj_raiz) AS cnpj_raiz,
                    COUNT(*) AS n_participations,
                    SUM(flagvencedor) AS n_wins,
                    CAST(SUM(flagvencedor) AS DOUBLE) / COUNT(*) AS win_rate,
                    CASE WHEN SUM(flagvencedor) = 0 THEN 1 ELSE 0 END AS always_loser
                FROM bl
                WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM cade_raiz)
                GROUP BY firm_id
            )
            SELECT
                fa.firm_id,
                fa.cnpj_raiz,
                cr.razao_cade,
                cr.processo,
                cr.setor,
                cr.uf_caso,
                cr.case_scope,
                cr.enrich_source,
                cr.enrich_score,
                fa.n_participations,
                fa.n_wins,
                fa.win_rate,
                fa.always_loser
            FROM firm_agg fa
            JOIN cade_raiz cr USING (cnpj_raiz)
            ORDER BY fa.n_participations DESC
        ) TO '{direct_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_direct = con.sql(f"SELECT COUNT(*) FROM '{direct_path}'").fetchone()[0]
    n_direct_raizes = con.sql(
        f"SELECT COUNT(DISTINCT cnpj_raiz) FROM '{direct_path}'").fetchone()[0]
    logging.info(
        f"  direct_defendants_federal: {n_direct} estab × CADE-raiz pairs "
        f"(across {n_direct_raizes} matched raízes)")

    # Anchored tenders — every (tender, item) where ANY direct defendant participates
    tenders_path = out_dir / "anchored_tenders_federal.parquet"
    con.sql(f"""
        COPY (
            SELECT DISTINCT
                bl.numerodaoc, bl.códigoitem
            FROM '{bid_level}' bl
            WHERE bl.códigofornecedor IN (
                SELECT firm_id FROM '{direct_path}'
            )
        ) TO '{tenders_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_tenders = con.sql(f"SELECT COUNT(*) FROM '{tenders_path}'").fetchone()[0]
    logging.info(f"  anchored_tenders_federal: {n_tenders:,} (tender, item) pairs")

    # Cobidder set — firms appearing in anchored tenders, EXCLUDING the directs themselves
    cobid_path = out_dir / "cobidders_federal.parquet"
    con.sql(f"""
        COPY (
            WITH cobid_raw AS (
                SELECT
                    bl.códigofornecedor AS firm_id,
                    COUNT(*) AS n_cobids,
                    SUM(bl.flagvencedor) AS n_wins_in_cobids
                FROM '{bid_level}' bl
                JOIN '{tenders_path}' tnd
                  ON bl.numerodaoc = tnd.numerodaoc
                 AND bl.códigoitem = tnd.códigoitem
                WHERE bl.códigofornecedor NOT IN (SELECT firm_id FROM '{direct_path}')
                GROUP BY bl.códigofornecedor
            )
            SELECT
                cr.firm_id,
                cr.n_cobids,
                cr.n_wins_in_cobids,
                fs.total_participations,
                fs.total_wins,
                fs.win_rate,
                fs.always_loser,
                CASE
                    WHEN fp.tenders_count IS NOT NULL AND fp.tenders_count >= {fl_threshold}
                    THEN 1 ELSE 0
                END AS is_FL_federal,
                COALESCE(fp.tenders_count, 0) AS tenders_count_al
            FROM cobid_raw cr
            LEFT JOIN '{freq_particip}' fp
              ON cr.firm_id = fp.códigofornecedor
            LEFT JOIN '{COMPRASNET_DIR / 'firm_loss_stats.parquet'}' fs
              ON cr.firm_id = fs.códigofornecedor
            ORDER BY cr.n_cobids DESC
        ) TO '{cobid_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_cobid = con.sql(f"SELECT COUNT(*) FROM '{cobid_path}'").fetchone()[0]
    n_fl_cobid = con.sql(
        f"SELECT COUNT(*) FROM '{cobid_path}' WHERE is_FL_federal = 1").fetchone()[0]
    n_al_cobid = con.sql(
        f"SELECT COUNT(*) FROM '{cobid_path}' WHERE always_loser = 1").fetchone()[0]
    logging.info(
        f"  cobidders_federal: {n_cobid} firms total, "
        f"{n_al_cobid} always-loser, {n_fl_cobid} FL (tenders_count >= {fl_threshold})")

    # Split-by-case-scope (D2 sub-table)
    by_scope = con.sql(f"""
        SELECT case_scope, COUNT(DISTINCT cnpj_raiz) AS raizes,
               COUNT(*) AS estab_rows,
               SUM(n_participations) AS sum_part
        FROM '{direct_path}'
        GROUP BY case_scope ORDER BY case_scope
    """).fetchall()

    return {
        "n_raizes_total": n_raizes,
        "n_direct_estabs": n_direct,
        "n_direct_raizes_matched": n_direct_raizes,
        "n_anchored_tenders": n_tenders,
        "n_cobidders": n_cobid,
        "n_al_cobidders": n_al_cobid,
        "n_fl_cobidders": n_fl_cobid,
        "by_scope": by_scope,
    }


def write_summary(out_dir: Path, stats: dict, fl_threshold: int) -> None:
    md = out_dir / "summary.md"
    with md.open("w", encoding="utf-8") as f:
        f.write("# CADE × ComprasNet linkage — v1 summary\n\n")
        f.write("**Generated by** `scripts/65_cade_comprasnet_linkage.py`\n\n")
        f.write("Enrichment source: D1 step 1 (BEC reuse only). No Receita Federal "
                "base yet; for v2 re-run after enrichment.\n\n")
        f.write("## Headline counts\n\n")
        f.write("| Quantity | Value |\n|---|---:|\n")
        f.write(f"| CADE raízes loaded | {stats['n_raizes_total']} |\n")
        f.write(f"| CADE raízes with federal participation | {stats['n_direct_raizes_matched']} |\n")
        f.write(f"| Direct-defendant federal estabs | {stats['n_direct_estabs']} |\n")
        f.write(f"| Anchored (tender, item) pairs | {stats['n_anchored_tenders']:,} |\n")
        f.write(f"| Cobidder firms (excl. directs) | {stats['n_cobidders']:,} |\n")
        f.write(f"| Cobidders that are always-loser | {stats['n_al_cobidders']:,} |\n")
        f.write(f"| Cobidders that are FL (tenders_count >= {fl_threshold}) | {stats['n_fl_cobidders']:,} |\n\n")
        f.write("## Split by case_scope (D2)\n\n")
        f.write("| case_scope | raízes | estab rows | participações |\n|---|---:|---:|---:|\n")
        for row in stats["by_scope"]:
            scope, raizes, estabs, partic = row
            f.write(f"| {scope} | {raizes} | {estabs} | {partic:,} |\n")
        f.write("\n## Files in this directory\n\n")
        f.write("- `cnpjs_enriched.csv` — CADE row × CNPJ enriched\n")
        f.write("- `cnpjs_fuzzy_audit.csv` — every fuzzy match attempt (for inspection)\n")
        f.write("- `direct_defendants_federal.parquet` — federal direct defendants\n")
        f.write("- `anchored_tenders_federal.parquet` — (tender × item) pairs anchored by CADE\n")
        f.write("- `cobidders_federal.parquet` — federal cobidder firms\n")
    logging.info(f"  wrote {md}")


# ─────────────────────── main ───────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fuzzy-threshold", type=float, default=0.92,
                    help="Fuzzy razão-social match threshold (default 0.92; "
                         "raised from 0.85 after Visaplas/OkPlast false-positive)")
    ap.add_argument("--fl-threshold", type=int, default=32,
                    help="FL classification threshold on tenders_count "
                         "(default 32 = ComprasNet IQR median+1.5*IQR). "
                         "Convention is tenders_count >= threshold, matching "
                         "BEC FL14 (commits bd504b5, 67aa4eb).")
    ap.add_argument("--out-version", default="v1",
                    help="Subdir under data/processed_comprasnet/ "
                         "(default v1; use v2 after RF base enrichment)")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    logging.info("=== CADE × ComprasNet linkage ===")
    out_dir = COMPRASNET_DIR / f"cade_link_{args.out_version}"
    out_dir.mkdir(parents=True, exist_ok=True)
    logging.info(f"  output dir: {out_dir}")
    logging.info(f"  fuzzy threshold: {args.fuzzy_threshold}")
    logging.info(f"  FL threshold (tenders_count >=): {args.fl_threshold}")

    cade = load_cade(CADE_CSV)
    bec = load_bec_xmatch(BEC_XMATCH_CSV)
    audit = enrich_via_bec(cade, bec, args.fuzzy_threshold)
    write_cnpjs_enriched(cade, audit, out_dir)

    con = duckdb.connect()
    bid_level = COMPRASNET_DIR / "bid_level_full.parquet"
    freq_particip = COMPRASNET_DIR / "FREQ_PARTICIP_rebuilt.parquet"
    stats = build_federal_sets(con, cade, out_dir, bid_level,
                               freq_particip, args.fl_threshold)
    write_summary(out_dir, stats, args.fl_threshold)

    logging.info("=== done ===")


if __name__ == "__main__":
    main()
