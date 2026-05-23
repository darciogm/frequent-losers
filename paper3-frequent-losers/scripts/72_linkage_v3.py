#!/usr/bin/env python3
"""
69_linkage_v2.py
================

Re-run CADE x ComprasNet linkage using the v2-enriched CNPJ list
(`data/processed_comprasnet/cade_link_v3/cnpjs_enriched.csv`,
produced by 68_promote_rais_to_v2.py from the RAIS audit).

Skips the BEC-reuse fuzzy enrichment of 65_cade_comprasnet_linkage.py
and goes straight to the federal linkage step with the curated CNPJ
set. Outputs follow the same v1 layout in
`data/processed_comprasnet/cade_link_v3/`.

FL convention: tenders_count >= threshold (default 32).
"""

from __future__ import annotations

import argparse
import csv
import logging
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
COMPRASNET_DIR = ROOT / "data" / "processed_comprasnet"
NACIONAL_UF = {"NACIONAL", "BRASIL", "BR"}


def cnpj_raiz(cnpj14: str) -> str:
    if not cnpj14:
        return ""
    return cnpj14[:8].zfill(8)


def load_enriched_v2(path: Path) -> list[dict]:
    out = []
    with path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if not row.get("cnpj14"):
                continue
            out.append({
                "cade_idx": row["cade_idx"],
                "cnpj14": row["cnpj14"],
                "cnpj_raiz": row.get("cnpj_raiz_enriched") or cnpj_raiz(row["cnpj14"]),
                "razao_social": row["razao_social"],
                "processo": row.get("numero_processo", ""),
                "setor": row.get("setor", ""),
                "uf_caso": (row.get("uf_licitacao") or "").upper(),
                "enrich_source": row.get("enrich_source", ""),
                "enrich_score": float(row.get("enrich_score") or 0),
            })
    return out


def build_federal_sets(con, cade: list[dict], out_dir: Path,
                       bid_level: Path, freq_particip: Path,
                       fl_threshold: int) -> dict:
    raiz_rows = []
    seen = set()
    for c in cade:
        r = c["cnpj_raiz"]
        if not r or r in seen:
            continue
        seen.add(r)
        case_scope = "national" if c["uf_caso"] in NACIONAL_UF else "state"
        raiz_rows.append({
            "cnpj_raiz": r,
            "razao_cade": c["razao_social"],
            "processo": c["processo"],
            "setor": c["setor"],
            "uf_caso": c["uf_caso"],
            "case_scope": case_scope,
            "enrich_source": c["enrich_source"],
            "enrich_score": c["enrich_score"],
        })

    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
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
    logging.info(f"  cade_raiz: {n_raizes} distinct CNPJ raizes loaded")

    out_dir.mkdir(parents=True, exist_ok=True)
    direct_path = out_dir / "direct_defendants_federal.parquet"
    tenders_path = out_dir / "anchored_tenders_federal.parquet"
    cobid_path = out_dir / "cobidders_federal.parquet"

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
                fa.firm_id, fa.cnpj_raiz,
                cr.razao_cade, cr.processo, cr.setor, cr.uf_caso,
                cr.case_scope, cr.enrich_source, cr.enrich_score,
                fa.n_participations, fa.n_wins, fa.win_rate, fa.always_loser
            FROM firm_agg fa
            JOIN cade_raiz cr USING (cnpj_raiz)
            ORDER BY fa.n_participations DESC
        ) TO '{direct_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_direct = con.sql(f"SELECT COUNT(*) FROM '{direct_path}'").fetchone()[0]
    n_direct_raizes = con.sql(
        f"SELECT COUNT(DISTINCT cnpj_raiz) FROM '{direct_path}'").fetchone()[0]
    logging.info(
        f"  direct_defendants_federal: {n_direct} estabs across "
        f"{n_direct_raizes} matched raizes")

    con.sql(f"""
        COPY (
            SELECT DISTINCT bl.numerodaoc, bl.códigoitem
            FROM '{bid_level}' bl
            WHERE bl.códigofornecedor IN (SELECT firm_id FROM '{direct_path}')
        ) TO '{tenders_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_tenders = con.sql(f"SELECT COUNT(*) FROM '{tenders_path}'").fetchone()[0]
    logging.info(f"  anchored_tenders_federal: {n_tenders:,} pairs")

    fls = COMPRASNET_DIR / "firm_loss_stats.parquet"
    con.sql(f"""
        COPY (
            WITH cobid_raw AS (
                SELECT
                    bl.códigofornecedor AS firm_id,
                    COUNT(*) AS n_cobids,
                    SUM(bl.flagvencedor) AS n_wins_in_cobids
                FROM '{bid_level}' bl
                JOIN '{tenders_path}' tnd
                  ON bl.numerodaoc = tnd.numerodaoc AND bl.códigoitem = tnd.códigoitem
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
            LEFT JOIN '{fls}' fs
              ON cr.firm_id = fs.códigofornecedor
            ORDER BY cr.n_cobids DESC
        ) TO '{cobid_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_cobid = con.sql(f"SELECT COUNT(*) FROM '{cobid_path}'").fetchone()[0]
    n_al_cobid = con.sql(
        f"SELECT COUNT(*) FROM '{cobid_path}' WHERE always_loser = 1").fetchone()[0]
    n_fl_cobid = con.sql(
        f"SELECT COUNT(*) FROM '{cobid_path}' WHERE is_FL_federal = 1").fetchone()[0]
    logging.info(
        f"  cobidders_federal: {n_cobid} firms total, "
        f"{n_al_cobid} always-loser, {n_fl_cobid} FL (tenders_count >= {fl_threshold})")

    by_scope = con.sql(f"""
        SELECT case_scope, COUNT(DISTINCT cnpj_raiz) AS raizes,
               COUNT(*) AS estab_rows,
               SUM(n_participations) AS sum_part
        FROM '{direct_path}'
        GROUP BY case_scope ORDER BY case_scope
    """).fetchall()

    summary_md = out_dir / "summary.md"
    with summary_md.open("w", encoding="utf-8") as f:
        f.write("# CADE x ComprasNet linkage -- v2 summary\n\n")
        f.write("Enrichment source: D1 step 1 (BEC reuse, fuzzy 0.92) + D1 step 2 "
                "(RAIS 2015-2017 audit + manual promotion of 7 firms via "
                "scripts/68_promote_rais_to_v2.py).\n\n")
        f.write("## Headline counts\n\n")
        f.write("| Quantity | Value |\n|---|---:|\n")
        f.write(f"| CADE raizes loaded | {n_raizes} |\n")
        f.write(f"| CADE raizes with federal participation | {n_direct_raizes} |\n")
        f.write(f"| Direct-defendant federal estabs | {n_direct} |\n")
        f.write(f"| Anchored (tender, item) pairs | {n_tenders:,} |\n")
        f.write(f"| Cobidder firms | {n_cobid:,} |\n")
        f.write(f"| Cobidders that are always-loser | {n_al_cobid:,} |\n")
        f.write(f"| Cobidders that are FL (tenders_count >= {fl_threshold}) | {n_fl_cobid:,} |\n\n")
        f.write("## Split by case_scope (D2)\n\n")
        f.write("| case_scope | raizes | estab rows | participations |\n|---|---:|---:|---:|\n")
        for row in by_scope:
            scope, raizes, estabs, partic = row
            f.write(f"| {scope} | {raizes} | {estabs} | {partic:,} |\n")
    logging.info(f"  wrote {summary_md}")

    return {
        "n_raizes_total": n_raizes,
        "n_direct_estabs": n_direct,
        "n_direct_raizes_matched": n_direct_raizes,
        "n_anchored_tenders": n_tenders,
        "n_cobidders": n_cobid,
        "n_al_cobidders": n_al_cobid,
        "n_fl_cobidders": n_fl_cobid,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fl-threshold", type=int, default=32)
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    enriched_csv = COMPRASNET_DIR / "cade_link_v3" / "cnpjs_enriched.csv"
    out_dir = COMPRASNET_DIR / "cade_link_v3"
    bid_level = COMPRASNET_DIR / "bid_level_full.parquet"
    freq_particip = COMPRASNET_DIR / "FREQ_PARTICIP_rebuilt.parquet"

    logging.info("[linkage v2] loading enriched v2 CSV")
    cade = load_enriched_v2(enriched_csv)
    logging.info(f"  {len(cade)} CADE rows with enriched CNPJ")

    con = duckdb.connect()
    stats = build_federal_sets(con, cade, out_dir, bid_level,
                               freq_particip, args.fl_threshold)
    logging.info("[linkage v2] done")


if __name__ == "__main__":
    main()
