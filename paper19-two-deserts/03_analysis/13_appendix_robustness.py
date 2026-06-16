"""
13_appendix_robustness.py

Estatisticas de suporte do apendice:
  (A) matriz de correlacao entre as medidas de deserto (distancia, F1, F2, F3)
      -> mostra honestamente que F2/F3 NAO replicam F1 (dimensoes distintas).
  (B) sensibilidade da taxonomia 2x2 a limiares alternativos (quartil vs tercil
      vs cortes absolutos em km) -> mostra que o off-diagonal central nao depende
      de um unico corte.

Entrada: master_muni_panel.parquet + f3_fragility_panel.parquet.
Saida:
  02_data/processed/appendix_correlation_matrix.csv
  02_data/processed/appendix_threshold_sensitivity.csv
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "13_appendix_robustness.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("appx")

VARS = [("iso_km", "Distância"), ("f1_km", "F1 (burden)"),
        ("iso_emb", "F2 (embedding)"), ("hub_dependence", "F3 (hub dep.)"),
        ("dest_hhi", "F3 (HHI dest.)")]


def main() -> None:
    t0 = time.perf_counter()
    M = (PROC19 / "master_muni_panel.parquet").as_posix()
    F3 = (PROC19 / "f3_fragility_panel.parquet").as_posix()
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")

    con.execute(f"""
        CREATE TEMP TABLE d AS
        SELECT m.codmun_6, m.iso_km, m.f1_km, m.iso_emb, m.divergence_z, m.quadrant,
               f.hub_dependence, f.dest_hhi
        FROM read_parquet('{M}') m JOIN read_parquet('{F3}') f USING (codmun_6)
        WHERE m.iso_emb IS NOT NULL
    """)
    n = con.sql("SELECT COUNT(*) FROM d").fetchone()[0]

    # (A) matriz de correlacao
    log.info("[A] matriz de correlacao (N=%d)...", n)
    cols = [v for v, _ in VARS]
    rows = []
    for a in cols:
        row = {"var": dict(VARS)[a]}
        for b in cols:
            r = con.sql(f"SELECT corr({a},{b}) FROM d").fetchone()[0]
            row[dict(VARS)[b]] = round(r, 3)
        rows.append(row)
    import pandas as pd
    cm = pd.DataFrame(rows).set_index("var")
    cm.to_csv(PROC19 / "appendix_correlation_matrix.csv")
    log.info("\n%s", cm.to_string())

    # (B) sensibilidade a limiares
    log.info("[B] sensibilidade da taxonomia 2x2 a limiares...")
    rules = [
        ("Quartil superior (corpo)", "quantile_cont(iso_km,0.75) OVER ()", "quantile_cont(f1_km,0.75) OVER ()"),
        ("Tercil superior",          "quantile_cont(iso_km,0.667) OVER ()", "quantile_cont(f1_km,0.667) OVER ()"),
        ("Decil superior",           "quantile_cont(iso_km,0.90) OVER ()",  "quantile_cont(f1_km,0.90) OVER ()"),
        ("Absoluto 30 / 60 km",      "30", "60"),
        ("Absoluto 50 / 100 km",     "50", "100"),
    ]
    out = []
    for name, dc, fc in rules:
        q = con.sql(f"""
            WITH z AS (SELECT iso_km, f1_km, {dc} AS dcut, {fc} AS fcut FROM d)
            SELECT
              SUM(CASE WHEN iso_km<=dcut AND f1_km>fcut THEN 1 ELSE 0 END) AS flow_only,
              SUM(CASE WHEN iso_km>dcut AND f1_km<=fcut THEN 1 ELSE 0 END) AS distance_only,
              SUM(CASE WHEN iso_km>dcut AND f1_km>fcut THEN 1 ELSE 0 END) AS both
            FROM z
        """).df().iloc[0]
        fo, do_, bo = int(q.flow_only), int(q.distance_only), int(q.both)
        disagree = round(100.0 * (fo + do_) / max(fo + do_ + bo, 1), 1)
        out.append({"Regra": name, "flow_only": fo, "distance_only": do_,
                    "both": bo, "% desacordo": disagree})
    sens = pd.DataFrame(out)
    sens.to_csv(PROC19 / "appendix_threshold_sensitivity.csv", index=False)
    log.info("\n%s", sens.to_string(index=False))

    log.info("==== fim %.1fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
