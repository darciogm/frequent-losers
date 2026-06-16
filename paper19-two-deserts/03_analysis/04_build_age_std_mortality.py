"""
04_build_age_std_mortality.py

Mortalidade evitável (Nolte-McKee) padronizada por idade via padronização
INDIRETA (SMR), município-nível, janela 2015-2022. Corrige o confound de
estrutura etária que invertia a taxa crua no overlay do §8 (desertos pobres/
rurais são mais jovens -> mortalidade crua menor por demografia, não acesso).

Por que indireta e não direta: municípios pequenos têm contagens etárias
esparsas; taxas etárias diretas explodem. SMR (observado/esperado) é o padrão
epidemiológico para comparação de mortalidade evitável entre áreas pequenas.

Definição amenable: importada de paper18/03_analysis/02_build_amenable_mortality.py
(AMENABLE_GROUPS + amenable_sql_clause) — paridade exata com o painel do paper.

Denominador por idade: estrutura etária do Censo 2022 (faixas 0-74, script 00)
* totais anuais de pop_municipal -> pop_faixa_ano (composição etária ~constante
na janela; documentado).

Construções:
  nat_rate_a   = Σ_my óbitos_a / Σ_my pop_a              (taxa etária nacional)
  Expected_m   = Σ_y Σ_a nat_rate_a * pop_a,m,y          (óbitos esperados)
  Observed_m   = Σ óbitos evitáveis <75 em m na janela
  SMR_m        = Observed_m / Expected_m
  ASMR_m       = SMR_m * crude_nat                        (taxa padronizada /100k)

Disciplina: descritivo. Causal mora no paper18.

Output (paper19):
  02_data/processed/amenable_mortality_agestd.parquet
    codmun_6, observed, expected, smr, asmr_per100k, crude_rate
  02_data/processed/mortality_crude_vs_agestd_by_quadrant.csv  (verificação §8)
"""

from __future__ import annotations

import argparse
import importlib.util
import logging
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
RAW_SIM = PAPER18 / "02_data" / "raw" / "sim"
INTER18 = PAPER18 / "02_data" / "intermediate"
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
PROC19.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "04_build_age_std_mortality.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("agestd")


def _rss_gib() -> float:
    try:
        import psutil
        return psutil.Process().memory_info().rss / 1e9
    except Exception:
        import resource
        return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1e6


def _git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return "unknown"


def _load_amenable_clause() -> str:
    """Importa amenable_sql_clause do script 02 do paper18 (paridade exata)."""
    p = PAPER18 / "03_analysis" / "02_build_amenable_mortality.py"
    spec = importlib.util.spec_from_file_location("p18_amenable", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.amenable_sql_clause()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-start", type=int, default=2015)
    ap.add_argument("--window-end", type=int, default=2022)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    ws, we = args.window_start, args.window_end

    census = PROC19 / "census2022_age_structure.parquet"
    master = PROC19 / "master_muni_panel.parquet"
    if not census.exists():
        log.error("falta %s — rode 00_download_census_age_structure.py", census)
        sys.exit(1)

    out_panel = PROC19 / "amenable_mortality_agestd.parquet"
    out_cmp = PROC19 / "mortality_crude_vs_agestd_by_quadrant.csv"
    if out_panel.exists() and not args.force:
        log.info("output já existe (%s) — use --force", out_panel.name)
        return

    t0 = time.perf_counter()
    log.info("==== build age-standardized amenable mortality ====")
    log.info("host=%s cores=%s git=%s window=%d-%d",
             socket.gethostname(), os.cpu_count(), _git_sha(), ws, we)

    files = []
    for y in range(ws, we + 1):
        files.extend(sorted(RAW_SIM.glob(f"do*{y}.parquet")))
    if not files:
        log.error("nenhum arquivo SIM em %s para %d-%d", RAW_SIM, ws, we)
        sys.exit(1)
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("SIM raw files: %d", len(files))

    clause = _load_amenable_clause()
    pop = (INTER18 / "pop_municipal_2015_2025.parquet").as_posix()
    cen = census.as_posix()

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    # ---- 1) óbitos evitáveis <75 por (codmun_6, year, age_band) ----
    log.info("[1/4] varredura SIM + decode idade + flag amenable + banding...")
    con.execute(f"""
        CREATE TEMP TABLE sim_clean AS
        SELECT
            CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) AS year,
            LPAD(CODMUNRES,6,'0') AS codmun_6,
            CAUSABAS,
            CASE WHEN SUBSTR(IDADE,1,1)='4' THEN CAST(SUBSTR(IDADE,2,2) AS INTEGER) END AS idade_anos,
            CASE WHEN SUBSTR(IDADE,1,1) IN ('1','2','3') THEN TRUE ELSE FALSE END AS is_subanual,
            CASE WHEN SUBSTR(IDADE,1,1)='5' THEN TRUE ELSE FALSE END AS is_centenarian,
            CASE WHEN IDADE IS NULL OR SUBSTR(IDADE,1,1)='9' THEN TRUE ELSE FALSE END AS age_unknown
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE CAUSABAS IS NOT NULL AND CODMUNRES IS NOT NULL AND DTOBITO IS NOT NULL
          AND LENGTH(DTOBITO)=8
          AND CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) BETWEEN {ws} AND {we}
    """)

    con.execute(f"""
        CREATE TEMP TABLE deaths AS
        SELECT codmun_6, year,
               CASE WHEN is_subanual OR idade_anos < 5 THEN '00-04'
                    ELSE printf('%02d-%02d',
                               CAST(LEAST(FLOOR(idade_anos/5.0)*5, 70) AS INTEGER),
                               CAST(LEAST(FLOOR(idade_anos/5.0)*5, 70)+4 AS INTEGER))
               END AS age_band,
               COUNT(*) AS n_deaths
        FROM sim_clean
        WHERE NOT is_centenarian AND NOT age_unknown
          AND (is_subanual OR idade_anos < 75)
          AND {clause}
        GROUP BY 1,2,3
    """)
    n_obs = con.sql("SELECT SUM(n_deaths) FROM deaths").fetchone()[0]
    # diagnóstico: fração amenable com idade ignorada (dropada da padronização)
    n_unknown = con.sql(f"""
        SELECT COUNT(*) FROM sim_clean
        WHERE age_unknown AND NOT is_centenarian AND {clause}
    """).fetchone()[0]
    log.info("    óbitos evitáveis <75 banded: %s | dropados age_unknown: %s (%.2f%%) | rss=%.2fGiB",
             f"{int(n_obs):,}", f"{int(n_unknown):,}",
             100.0*n_unknown/(n_obs+n_unknown), _rss_gib())

    # ---- 2) pop por (codmun_6, year, age_band): share censo * total anual ----
    log.info("[2/4] denominador por idade (share Censo 2022 * total anual)...")
    con.execute(f"""
        CREATE TEMP TABLE pop_band AS
        WITH cen AS (SELECT codmun_6, age_band, pop_band FROM read_parquet('{cen}')),
        tot2022 AS (
            SELECT substr(cod_mun,1,6) AS codmun_6, pop AS pop_total_2022
            FROM read_parquet('{pop}') WHERE ano=2022
        ),
        share AS (
            SELECT c.codmun_6, c.age_band,
                   c.pop_band::DOUBLE / NULLIF(t.pop_total_2022,0) AS w_a
            FROM cen c JOIN tot2022 t USING(codmun_6)
        ),
        yearly AS (
            SELECT substr(cod_mun,1,6) AS codmun_6, ano AS year, pop AS pop_total
            FROM read_parquet('{pop}') WHERE ano BETWEEN {ws} AND {we}
        )
        SELECT s.codmun_6, y.year, s.age_band, s.w_a * y.pop_total AS pop_a
        FROM share s JOIN yearly y USING(codmun_6)
    """)

    # ---- 3) taxas etárias nacionais + esperado/observado por município ----
    log.info("[3/4] taxas nacionais, óbitos esperados, SMR...")
    con.execute("""
        CREATE TEMP TABLE nat AS
        SELECT pb.age_band,
               SUM(COALESCE(d.n_deaths,0)) AS deaths_a,
               SUM(pb.pop_a)               AS pop_a,
               SUM(COALESCE(d.n_deaths,0)) / NULLIF(SUM(pb.pop_a),0) AS nat_rate_a
        FROM pop_band pb
        LEFT JOIN deaths d USING (codmun_6, year, age_band)
        GROUP BY pb.age_band
    """)
    crude_nat = con.sql("""
        SELECT SUM(deaths_a)/NULLIF(SUM(pop_a),0)*1e5 FROM nat
    """).fetchone()[0]

    con.execute("""
        CREATE TEMP TABLE muni AS
        WITH exp AS (
            SELECT pb.codmun_6, SUM(pb.pop_a * n.nat_rate_a) AS expected,
                   SUM(pb.pop_a) AS pyears
            FROM pop_band pb JOIN nat n USING (age_band)
            GROUP BY pb.codmun_6
        ),
        obs AS (
            SELECT codmun_6, SUM(n_deaths) AS observed
            FROM deaths GROUP BY codmun_6
        )
        SELECT e.codmun_6,
               COALESCE(o.observed,0)            AS observed,
               e.expected,
               COALESCE(o.observed,0)/NULLIF(e.expected,0) AS smr,
               e.pyears
        FROM exp e LEFT JOIN obs o USING (codmun_6)
    """)
    con.execute(f"""
        CREATE TEMP TABLE final AS
        SELECT codmun_6, observed, expected, smr,
               smr * {crude_nat} AS asmr_per100k,
               observed / NULLIF(pyears,0) * 1e5 AS crude_rate
        FROM muni
    """)
    con.execute(
        f"COPY (SELECT * FROM final ORDER BY codmun_6) "
        f"TO '{out_panel.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')"
    )
    log.info("    crude nacional=%.1f/100k | municípios=%d",
             crude_nat, con.sql("SELECT COUNT(*) FROM final").fetchone()[0])

    # ---- 4) verificação §8: crude vs padronizada por quadrante ----
    if master.exists():
        log.info("[4/4] crude vs age-std por quadrante (verificação da inversão §8)...")
        cmp = con.sql(f"""
            SELECT m.quadrant,
                   COUNT(*) AS n_mun,
                   ROUND(median(m.amenable_rate),1)  AS med_crude_rate,
                   ROUND(median(f.asmr_per100k),1)    AS med_asmr,
                   ROUND(median(f.smr),3)             AS med_smr
            FROM read_parquet('{master.as_posix()}') m
            JOIN final f USING (codmun_6)
            GROUP BY m.quadrant
            ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
        """).df()
        cmp.to_csv(out_cmp, index=False)
        log.info("\n%s", cmp.to_string(index=False))
    else:
        log.warning("[4/4] master ausente — pulei verificação por quadrante")

    log.info("outputs: %s ; %s", out_panel.name, out_cmp.name)
    log.info("==== fim em %.1fs (rss~%.2fGiB) ====", time.perf_counter()-t0, _rss_gib())


if __name__ == "__main__":
    main()
