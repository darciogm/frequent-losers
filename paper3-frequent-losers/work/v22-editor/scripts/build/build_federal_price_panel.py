#!/usr/bin/env python3
"""
build_federal_price_panel.py

Build the federal price-panel for the ComprasNet price-scope replication of the
frequent-losers cartel screen. Joins the dense API price signals (reference price
`valorEstimadoItem` + lowest bid `menorLance`, both absent from the Portal panel)
to the Portal CGU panel for winner identity and competition counts.

INPUTS (verified — see work/v22-editor/outputs/comprasnet/diagnostics/
        item_pregao_linkability.md):
  - data/processed_comprasnet/item_pregao_api.parquet  (12,427,818 rows, item grain)
        idCompraItem(22) == codigoitem == UASG(6)+'05'+numerodaoc(9)+item_seq(5).
        valorEstimadoItem (100% >0), menorLance (94.7% >0),
        valorHomologadoItem (84.3% >0, UNIT price), quantidadeItem,
        situacaoItem ('homologado' = awarded). fornecedorVencedor 100% null.
        year is closing-date-derived; window overlap leaks a few out-of-range rows.
  - data/processed_comprasnet/item_level_panel.parquet (Portal CGU panel 2013-2019)
        códigoitem (same 22-char composite), codigo_ug, numerodaoc, year (result
        year), valor_item (awarded TOTAL = unit×qty), codigo_vencedor, n_firms.

JOIN RULE (validated): direct item-level string equality
        api.codigoitem = panel."códigoitem". 65-74% item-level match in 2013-2019;
        zero before 2013 (panel does not cover 2009-2012 — API extends backward).

OUTPUT:
  - data/processed_comprasnet/federal_price_panel.parquet (snappy)
  - stats log to stdout (rows, match rate by year, % homologado, discount
    distribution p1..p99 pre/post trim-flag).

CLI:
  --smoke   run the whole flow on a 100k-row API sample, threads=2/mem=2GB,
            write to a *.smoke.parquet sidecar. Does NOT touch the real output.

House style mirrors parse_item_pregao_api.py: telemetry log, deterministic,
DuckDB PRAGMA threads=12 memory_limit='14GB' with /tmp spill.
"""
import argparse
import os
import sys
import time

import duckdb
import psutil

BASE = "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
API_PATH = os.path.join(BASE, "data/processed_comprasnet/item_pregao_api.parquet")
PANEL_PATH = os.path.join(BASE, "data/processed_comprasnet/item_level_panel.parquet")
OUT_PATH = os.path.join(BASE, "data/processed_comprasnet/federal_price_panel.parquet")
SMOKE_OUT_PATH = os.path.join(
    BASE, "data/processed_comprasnet/federal_price_panel.smoke.parquet")
SPILL_DIR = "/tmp/duckdb_spill"

# Discount-ratio trim band (flag, do NOT drop): outliers are the data-entry tail.
RATIO_HI = 10.0     # discount > 10  => ratio_outlier
RATIO_LO = 0.001    # discount < 0.001 => ratio_outlier


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def log(msg):
    print(msg, flush=True)


def connect(smoke):
    """DuckDB connection. Under --smoke, cap to threads=2/mem=2GB so the script can
    be validated while a heavy regression job runs concurrently."""
    con = duckdb.connect()
    if smoke:
        con.sql("PRAGMA threads=2")
        con.sql("PRAGMA memory_limit='2GB'")
    else:
        con.sql("PRAGMA threads=12")
        con.sql("PRAGMA memory_limit='14GB'")
    os.makedirs(SPILL_DIR, exist_ok=True)
    con.sql(f"PRAGMA temp_directory='{SPILL_DIR}'")
    return con


def api_source_sql(smoke):
    """API source relation. Under --smoke, a deterministic 100k-row sample
    (USING SAMPLE with a fixed seed -> reproducible)."""
    base = f"read_parquet('{API_PATH}')"
    if smoke:
        return f"(SELECT * FROM {base} USING SAMPLE 100000 ROWS (reservoir, 42))"
    return base


def build(con, smoke):
    api = api_source_sql(smoke)
    panel = f"read_parquet('{PANEL_PATH}')"

    # 1. Clean API frame: restrict year window, awarded flag, discount + outlier
    #    flag. We keep BOTH homologado and non-homologado (with is_homologado
    #    flag); analysis decides. Rows are NOT dropped on the outlier flag.
    #
    # 2. LEFT JOIN panel on codigoitem equality; carry codigo_ug, panel year,
    #    valor_item, codigo_vencedor, n_firms; in_portal_panel flag; year_best
    #    prefers the panel result year over the API closing-date year.
    sql = f"""
    WITH api_clean AS (
        SELECT
            a.codigoitem,
            a.idCompra,
            a.codigo_ug                                   AS codigo_ug_api,
            a.numerodaoc,
            a.situacaoItem,
            (a.situacaoItem = 'homologado')               AS is_homologado,
            a.year                                        AS year_api,
            a.quantidadeItem,
            a.valorEstimadoItem,
            a.menorLance,
            a.valorHomologadoItem,
            -- unit award x qty -> total, to align with panel valor_item when needed
            CASE WHEN a.valorHomologadoItem > 0 AND a.quantidadeItem > 0
                 THEN a.valorHomologadoItem * a.quantidadeItem END
                                                          AS valorHomologadoTotal,
            CASE WHEN a.menorLance > 0 AND a.valorEstimadoItem > 0
                 THEN a.menorLance / a.valorEstimadoItem END
                                                          AS discount,
            a.decreto7174,
            a.tratamentoDiferenciado
        FROM {api} a
        WHERE a.year BETWEEN 2009 AND 2019
    ),
    api_flagged AS (
        SELECT
            *,
            (discount IS NOT NULL
             AND (discount > {RATIO_HI} OR discount < {RATIO_LO})) AS ratio_outlier
        FROM api_clean
    )
    SELECT
        c.codigoitem,
        c.idCompra,
        c.numerodaoc,
        c.situacaoItem,
        c.is_homologado,
        -- price signals (API value-add; absent from Portal panel)
        c.valorEstimadoItem,
        c.menorLance,
        c.valorHomologadoItem,
        c.valorHomologadoTotal,
        c.quantidadeItem,
        c.discount,
        c.ratio_outlier,
        c.decreto7174,
        c.tratamentoDiferenciado,
        -- UASG: prefer the API-derived ug, fall back to panel
        COALESCE(c.codigo_ug_api, p.codigo_ug)            AS codigo_ug,
        -- Portal panel carry-overs
        (p."códigoitem" IS NOT NULL)                      AS in_portal_panel,
        p.valor_item                                      AS valor_item_panel,
        p.codigo_vencedor,
        p.n_firms,
        -- years: keep both, plus year_best preferring the panel result year
        c.year_api,
        p.year                                            AS year_panel,
        COALESCE(p.year, c.year_api)                      AS year_best
    FROM api_flagged c
    LEFT JOIN {panel} p
        ON c.codigoitem = p."códigoitem"
    """
    return sql


def write_output(con, select_sql, out_path):
    con.sql(f"""
        COPY ({select_sql}) TO '{out_path}'
        (FORMAT PARQUET, COMPRESSION 'snappy')
    """)


def stats(con, out_path):
    """Print the required stats log off the written parquet (cheap aggregates)."""
    rel = f"read_parquet('{out_path}')"

    n = con.sql(f"SELECT COUNT(*) FROM {rel}").fetchone()[0]
    log(f"[stats] rows={n:,}")

    hom = con.sql(
        f"SELECT 100.0*AVG(CASE WHEN is_homologado THEN 1 ELSE 0 END) FROM {rel}"
    ).fetchone()[0]
    log(f"[stats] homologado share = {hom:.2f}%")

    inpanel = con.sql(
        f"SELECT 100.0*AVG(CASE WHEN in_portal_panel THEN 1 ELSE 0 END) FROM {rel}"
    ).fetchone()[0]
    log(f"[stats] overall in_portal_panel match = {inpanel:.2f}%")

    log("[stats] match rate by year (year_api):")
    by_year = con.sql(f"""
        SELECT year_api AS y,
               COUNT(*) AS n,
               SUM(CASE WHEN in_portal_panel THEN 1 ELSE 0 END) AS matched,
               100.0*AVG(CASE WHEN in_portal_panel THEN 1 ELSE 0 END) AS pct
        FROM {rel}
        GROUP BY year_api ORDER BY year_api
    """).fetchall()
    for y, ny, m, pct in by_year:
        log(f"         {y}: n={ny:,} matched={m:,} ({pct:.2f}%)")

    outl = con.sql(
        f"SELECT 100.0*AVG(CASE WHEN ratio_outlier THEN 1 ELSE 0 END) FROM {rel} "
        f"WHERE discount IS NOT NULL"
    ).fetchone()[0]
    log(f"[stats] ratio_outlier share (of rows with discount) = {outl:.2f}%")

    log("[stats] discount distribution (rows with discount):")
    pre = con.sql(f"""
        SELECT
            quantile_cont(discount, 0.01) AS p1,
            quantile_cont(discount, 0.25) AS p25,
            quantile_cont(discount, 0.50) AS p50,
            quantile_cont(discount, 0.75) AS p75,
            quantile_cont(discount, 0.99) AS p99
        FROM {rel} WHERE discount IS NOT NULL
    """).fetchone()
    log(f"         pre-trim  : p1={pre[0]:.4f} p25={pre[1]:.4f} "
        f"p50={pre[2]:.4f} p75={pre[3]:.4f} p99={pre[4]:.4f}")
    post = con.sql(f"""
        SELECT
            quantile_cont(discount, 0.01) AS p1,
            quantile_cont(discount, 0.25) AS p25,
            quantile_cont(discount, 0.50) AS p50,
            quantile_cont(discount, 0.75) AS p75,
            quantile_cont(discount, 0.99) AS p99
        FROM {rel} WHERE discount IS NOT NULL AND NOT ratio_outlier
    """).fetchone()
    log(f"         post-flag : p1={post[0]:.4f} p25={post[1]:.4f} "
        f"p50={post[2]:.4f} p75={post[3]:.4f} p99={post[4]:.4f}")

    # discount quartiles convenience line (for the smoke report)
    log(f"[stats] discount quartiles (post-flag) = "
        f"Q1={post[1]:.4f} Q2={post[2]:.4f} Q3={post[3]:.4f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--smoke", action="store_true",
                    help="run on a 100k-row API sample, threads=2/mem=2GB, "
                         "write to *.smoke.parquet")
    args = ap.parse_args()

    out_path = SMOKE_OUT_PATH if args.smoke else OUT_PATH
    mode = "SMOKE (100k sample)" if args.smoke else "FULL"

    vm = psutil.virtual_memory()
    log(f"[init] host={os.uname().nodename} mode={mode} "
        f"RAM_total={vm.total/1e9:.1f}GB RAM_free={vm.available/1e9:.1f}GB "
        f"rss={rss_gb():.2f}GB")
    log(f"[init] api  = {API_PATH}")
    log(f"[init] panel= {PANEL_PATH}")
    log(f"[init] out  = {out_path}")

    for p in (API_PATH, PANEL_PATH):
        if not os.path.exists(p):
            log(f"[fatal] missing input: {p}")
            sys.exit(1)

    t0 = time.time()
    con = connect(args.smoke)

    select_sql = build(con, args.smoke)

    log("[build] writing parquet ...")
    write_output(con, select_sql, out_path)
    log(f"[build] written in {time.time()-t0:.0f}s  rss={rss_gb():.2f}GB  "
        f"size={os.path.getsize(out_path)/1e6:.1f}MB")

    stats(con, out_path)

    con.close()
    log(f"[done] {mode} time={time.time()-t0:.0f}s rss_peak~{rss_gb():.2f}GB")
    log(f"[out]  {out_path}")


if __name__ == "__main__":
    main()
