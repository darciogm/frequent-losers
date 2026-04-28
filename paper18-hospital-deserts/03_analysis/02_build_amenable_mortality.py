"""
02_build_amenable_mortality.py

Constrói painel de mortalidade evitável (amenable mortality) por município ×
ano para 2015–2024, usando a lista canônica Nolte-McKee / OECD 2019.

Input:
- 02_data/raw/sim/do<UF><AAAA>.parquet  (raw SIM, IDADE codificada 1XX..5XX)
- 02_data/intermediate/pop_municipal_2015_2025.parquet  (denominador)

Output:
- 02_data/intermediate/amenable_mortality.parquet
  Schema: codmun_6, year, n_amenable, n_total, pop, rate_per100k, fonte_pop, interpolated

Pipeline DuckDB out-of-core, 12 threads.

Critérios:
- IDADE = '4XX': interpretar XX como anos. Aplicar cap < 75 anos quando exigido pela CID.
- IDADE = '1XX'/'2XX'/'3XX' (subanual): incluir (idade < 1).
- IDADE = '5XX' (centenários): excluir (>= 100 anos).
- IDADE = '9XX' / NULL / inválido: incluir como missing-age (ageless code = TRUE);
  reportar separadamente em sanity log.
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_SIM = ROOT / "02_data" / "raw" / "sim"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "02_build_amenable_mortality.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("amenable")

OUT = INTER / "amenable_mortality.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"

# ---------------------------------------------------------------------------
# Lista Nolte-McKee / OECD 2019 — causas evitáveis (treatable amenable mortality)
# Cada padrão é um prefixo CID-10 (3 chars). Cap de idade <75 padrão; algumas
# exceções (perinatais P*, maternos O*, infantis sem cap).
#
# Estrutura: lista de tuplas (regex_prefix, age_cap)
#   - age_cap = 75   -> só inclui mortes com idade < 75 (incluindo subanuais)
#   - age_cap = None -> sem cap (perinatais, maternos)
# ---------------------------------------------------------------------------
AMENABLE_GROUPS = [
    # Doenças infecciosas tratáveis
    ("A0[0-9]", 75),       # intestinais
    ("A1[5-9]", 75),       # tuberculose
    ("B90", 75),
    ("A3[6-9]", 75),       # difteria, coqueluche, escarlatina
    ("A4[01]", 75),        # septicemias
    ("A48", 75),
    ("A5[0-3]", 75),       # sífilis
    ("A75", 75), ("A78", 75), ("A79", 75),
    ("A80", 75), ("B91", 75),
    ("B05", 75), ("B06", 75),                  # sarampo, rubéola
    ("B1[6-9]", 75),                            # hepatites virais
    ("B2[0-4]", 75),                            # HIV/AIDS
    # Neoplasias com tratamento eficaz
    ("C0[0-9]", 75), ("C1[0-4]", 75),           # cavidade oral/faringe
    ("C15", 75),                                # esôfago
    ("C1[8-9]", 75), ("C2[01]", 75),            # colorretal
    ("C50", 75),                                # mama
    ("C53", 75),                                # cérvix
    ("C73", 75),                                # tireoide
    ("C81", 75),                                # Hodgkin
    ("C9[1-5]", 75),                            # leucemias
    # Sangue e nutricionais
    ("D5[0-9]", 75), ("D6[0-9]", 75), ("D7[0-9]", 75), ("D8[0-9]", 75),
    ("E0[0-7]", 75),                            # tireoide
    ("E1[0-4]", 75),                            # diabetes
    ("E4[0-6]", 75), ("E5[0-9]", 75), ("E6[0-4]", 75),  # nutricionais
    # Neuro
    ("G4[01]", 75),                             # epilepsia
    # Cardiovasculares
    ("I0[5-9]", 75),                            # febre reumática
    ("I1[0-5]", 75),                            # hipertensão
    ("I2[0-5]", 75),                            # isquemia cardíaca (cap 75)
    ("I26", 75), ("I27", 75), ("I28", 75),      # embolia pulmonar
    ("I6[0-9]", 75),                            # cerebrovascular
    # Respiratórias
    ("J0[0-6]", 75),                            # vias aéreas superiores
    ("J0[9]", 75), ("J1[0-1]", 75),             # influenza
    ("J1[2-8]", 75),                            # pneumonia
    ("J2[0-2]", 75),                            # bronquite aguda
    ("J4[0-7]", 75),                            # DPOC, asma
    # Digestivas
    ("K2[5-8]", 75),                            # úlcera péptica
    ("K3[5-8]", 75),                            # apendicite
    ("K4[0-6]", 75),                            # hérnia
    ("K7[0-6]", 75),                            # doença hepática crônica
    ("K8[0-3]", 75),                            # vesícula biliar
    # Renais
    ("N0[0-7]", 75),                            # glomerulonefrite
    ("N1[7-9]", 75),                            # insuficiência renal
    ("N40", 75),                                # HBP
    # Maternas e perinatais
    ("O[0-9][0-9]", None),                      # causas maternas
    ("P[0-9][0-9]", None),                      # perinatais
    # Anomalias congênitas selecionadas
    ("Q2[0-8]", None),                          # cardiopatias congênitas
]


def amenable_sql_clause() -> str:
    """Constrói cláusula SQL para identificar causa amenable.

    Para cada (regex, cap), cria condição:
       (REGEXP_FULL_MATCH(CAUSABAS_PREFIX, regex_3char) AND age_under_cap)
    Retorna OR sobre todas as condições.
    """
    conds = []
    for pattern, cap in AMENABLE_GROUPS:
        # CAUSABAS no SIM tem 4 chars (3+sub); usamos os primeiros 3 chars no match
        # se padrão tem 3 chars (Inn) ou exato.
        m = pattern.replace("[0-9]", "[0-9]")
        plen = len(pattern.replace("[0-9]", "X").replace("[0-1]", "X").replace("[0-2]", "X").replace("[0-3]", "X").replace("[0-4]", "X").replace("[0-5]", "X").replace("[0-6]", "X").replace("[0-7]", "X").replace("[0-8]", "X").replace("[0-9]", "X").replace("[1-5]", "X").replace("[1-9]", "X").replace("[1-8]", "X").replace("[01]", "X").replace("[1-1]", "X").replace("[5-9]", "X").replace("[6-9]", "X").replace("[8-9]", "X").replace("[1-4]", "X").replace("[0]", "X").replace("[1]", "X"))
        # truque: comparamos sempre com prefixo de 3 chars do CAUSABAS
        # mas como padrão pode ter 1, 2 ou 3 chars (e.g. 'I26' tem 3, 'A0[0-9]' tem 6 raw mas vira 3 codes), usamos REGEXP_MATCHES.
        match = f"REGEXP_FULL_MATCH(SUBSTR(CAUSABAS, 1, 3), '^{pattern}$')"
        if cap is None:
            conds.append(match)
        else:
            # idade <75: idadeanos < cap OR subanual (idade começa com 1/2/3)
            age_cond = f"(idade_anos IS NOT NULL AND idade_anos < {cap}) OR is_subanual = TRUE"
            conds.append(f"({match} AND ({age_cond}))")
    return "(\n    " + "\n    OR ".join(conds) + "\n)"


def main():
    t0 = time.time()
    log.info("==== begin amenable mortality build ====")

    # Filtrar globs por ano alvo — alguns arquivos antigos do paper5 estão corrompidos.
    files = []
    for y in range(2010, 2024):
        files.extend(sorted(RAW_SIM.glob(f"do*{y}.parquet")))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("input files: %d (SIM 2010-2023, raw)", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- 1) extrair colunas relevantes + decodificar IDADE -------------
    log.info("[1/3] varredura SIM 2010–2023 + decode IDADE...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sim_clean AS
        SELECT
            CAST(SUBSTR(DTOBITO, 5, 4) AS INTEGER) AS year,
            LPAD(CODMUNRES, 6, '0') AS codmun_6,
            CAUSABAS,
            -- idade em anos quando IDADE='4XX'
            CASE
                WHEN SUBSTR(IDADE, 1, 1) = '4' THEN CAST(SUBSTR(IDADE, 2, 2) AS INTEGER)
                ELSE NULL
            END AS idade_anos,
            -- subanuais (1XX horas, 2XX dias, 3XX meses)
            CASE
                WHEN SUBSTR(IDADE, 1, 1) IN ('1','2','3') THEN TRUE
                ELSE FALSE
            END AS is_subanual,
            -- centenários (excluir)
            CASE
                WHEN SUBSTR(IDADE, 1, 1) = '5' THEN TRUE
                ELSE FALSE
            END AS is_centenarian,
            -- idade ignorada (9XX) ou nula
            CASE
                WHEN IDADE IS NULL OR SUBSTR(IDADE, 1, 1) = '9' THEN TRUE
                ELSE FALSE
            END AS age_unknown
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE CAUSABAS IS NOT NULL
          AND CODMUNRES IS NOT NULL
          AND DTOBITO IS NOT NULL
          AND LENGTH(DTOBITO) = 8
          AND CAST(SUBSTR(DTOBITO, 5, 4) AS INTEGER) BETWEEN 2010 AND 2023
    """)
    n_total = con.sql("SELECT COUNT(*) FROM sim_clean").fetchone()[0]
    log.info("    SIM 2010-2023 limpo: %s óbitos", f"{n_total:,}")

    age_dist = con.sql("""
        SELECT
            SUM(CASE WHEN idade_anos IS NOT NULL THEN 1 ELSE 0 END) AS years_known,
            SUM(CASE WHEN is_subanual THEN 1 ELSE 0 END) AS subanual,
            SUM(CASE WHEN is_centenarian THEN 1 ELSE 0 END) AS centenarian,
            SUM(CASE WHEN age_unknown THEN 1 ELSE 0 END) AS age_unknown
        FROM sim_clean
    """).pl()
    log.info("    age dist: %s", age_dist.to_dicts()[0])

    # ---- 2) flag amenable ----------------------------------------------
    log.info("[2/3] aplicando lista Nolte-McKee/OECD 2019...")
    clause = amenable_sql_clause()
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sim_flagged AS
        SELECT *,
               CASE WHEN {clause} THEN 1 ELSE 0 END AS is_amenable
        FROM sim_clean
        WHERE NOT is_centenarian
    """)
    n_amenable_total = con.sql("SELECT SUM(is_amenable) FROM sim_flagged").fetchone()[0]
    log.info("    óbitos amenable identificados: %s (%.1f%% do total)",
             f"{n_amenable_total:,}", 100.0 * n_amenable_total / n_total)

    # ---- 3) agregar por município × ano + join pop ---------------------
    log.info("[3/3] agregando por (codmun_6, year) + join pop...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE pop AS
        SELECT
            -- pop_municipal_2015_2025 tem cod_mun em 7 dígitos (IBGE com DV).
            -- DATASUS usa 6 dígitos (sem DV). Convertemos pop para 6 dig truncando o 7º.
            SUBSTR(cod_mun, 1, 6) AS codmun_6,
            ano AS year,
            pop,
            fonte AS fonte_pop,
            interpolated
        FROM read_parquet('{POP}')
    """)

    con.execute(f"""
        COPY (
            WITH agg AS (
                SELECT codmun_6, year,
                       SUM(is_amenable) AS n_amenable,
                       COUNT(*) AS n_total,
                       SUM(CASE WHEN age_unknown THEN 1 ELSE 0 END) AS n_age_unknown
                FROM sim_flagged
                GROUP BY codmun_6, year
            )
            SELECT
                a.codmun_6,
                a.year,
                a.n_amenable,
                a.n_total,
                a.n_age_unknown,
                p.pop,
                p.fonte_pop,
                p.interpolated AS pop_interpolated,
                CASE WHEN p.pop > 0 THEN 1.0 * a.n_amenable / p.pop * 100000 ELSE NULL END AS rate_per100k
            FROM agg a
            LEFT JOIN pop p USING (codmun_6, year)
            ORDER BY codmun_6, year
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_rows = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT}')").fetchone()[0]
    log.info("    rows escritas: %s", f"{n_rows:,}")

    # ---- sanity ---------------------------------------------------------
    log.info("\n=== summary by year ===")
    summary = con.sql(f"""
        SELECT year,
               COUNT(*) AS n_munis,
               SUM(n_amenable) AS amenable_total,
               SUM(n_total) AS deaths_total,
               1.0 * SUM(n_amenable) / SUM(n_total) AS pct_amenable,
               SUM(CASE WHEN pop IS NULL THEN 1 ELSE 0 END) AS pop_missing,
               AVG(rate_per100k) AS mean_rate,
               STDDEV(rate_per100k) AS sd_rate
        FROM read_parquet('{OUT}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", summary)

    log.info("\n=== top 10 munis 2018 amenable ===")
    top = con.sql(f"""
        SELECT codmun_6, year, n_amenable, pop, rate_per100k
        FROM read_parquet('{OUT}')
        WHERE year = 2018 AND pop > 50000
        ORDER BY rate_per100k DESC LIMIT 10
    """).pl()
    log.info("\n%s", top)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
