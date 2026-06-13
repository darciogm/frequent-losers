"""
O6_build_outpatient_mental_health_panel.py

Agrega producao ambulatorial de saude mental (SIA-PA / RAAS-PS) a
municipio-ano, DUAS vezes e em arquivos SEPARADOS:

  (a) RESIDENCE-based  -> chave = municipio de RESIDENCIA do paciente x ano.
      So construido para familias cujo schema_audit confirma campo de
      residencia com cobertura adequada (non-missing >= RES_MIN_NONMISS).
  (b) PROVIDER-based    -> chave = municipio do ESTABELECIMENTO x ano.
      Sempre construivel.

REGRA CARDINAL: municipio do provedor NUNCA e tratado como residencia.
Os dois panels vivem em arquivos distintos, cada um com coluna `basis`.

Outputs (02_data/processed/outpatient_mental_health/):
  outpatient_mh_municipality_year.parquet           (basis='residence')
  outpatient_mh_provider_municipality_year.parquet  (basis='provider')
  outpatient_mh_panel_summary.csv                   (diagnosticos de cobertura)

Inputs upstream (convertidos): 02_data/intermediate/{sia,raas}/family=<fam>/
year=<yyyy>/uf=<UF>/*.parquet. Nomes de colunas DATASUS variam -> resolvidos
via sia_raas_schema_audit.csv (nunca hardcoded). Procedimentos de SM e suas
categorias via mental_health_outpatient_codebook.csv.

Se um input critico falta: LOG + exit 0 (nao quebra, nao fabrica).
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_analysis"))
from _telemetry import StepTimer, runtime_header, write_json  # noqa: E402

INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed" / "outpatient_mental_health"
LOGDIR = ROOT / "04_logs" / "outpatient"
LOGDIR.mkdir(parents=True, exist_ok=True)
PROC.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOGDIR / "O6_build_outpatient_mental_health_panel.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("o6_outpatient_mh")

# ---- paths ----
SIA_DIR = INTER / "sia"
RAAS_DIR = INTER / "raas"
SCHEMA_AUDIT = PROC / "sia_raas_schema_audit.csv"
CODEBOOK = PROC / "mental_health_outpatient_codebook.csv"
STAGGERED = INTER / "staggered_panel_pnash48_ext.parquet"
POP_FALLBACK = INTER / "pop_municipal_2015_2025.parquet"

OUT_RES = PROC / "outpatient_mh_municipality_year.parquet"
OUT_PROV = PROC / "outpatient_mh_provider_municipality_year.parquet"
OUT_SUMMARY = PROC / "outpatient_mh_panel_summary.csv"
JSON_FILE = LOGDIR / "O6_build_outpatient_mental_health_panel.telemetry.json"

# Limiar de cobertura do campo de residencia para uma familia entrar no
# panel residence-based. SIA-PA historicamente nem sempre tem MUNPCN; abaixo
# disso o municipio de residencia e ruim demais para tratar como denominador.
RES_MIN_NONMISS = 0.80

# Familias canonicas e a categoria de codebook esperada para cada bucket.
# (apenas labels de saida; o filtro real vem do codebook)
FAMILIES_ALL = ["sia_pa", "raas_ps"]

# Fallback de candidatos por papel, caso o schema_audit nao exista OU nao tenha
# linha para o papel. Inclui realidade RAAS-PS: residencia=MUNPAC,
# provedor=UFMUN, cnes=CNES_EXEC/CNS_PAC, proc=PA_PROC_ID, qty=PA_QTDAPR/QTDPRO.
# RAAS NAO tem coluna de valor (sem PA_VALAPR) -> value pode ficar None (counts-only).
FALLBACK_CANDIDATES = {
    "residence": ["PA_MUNPCN", "MUNPCN", "CODMUNRES", "MUN_PAC", "MUNPAC"],
    "provider": ["PA_UFMUN", "CODUFMUN", "UFMUN", "PA_MVM", "MUNCOD"],
    "cnes": ["PA_CODUNI", "CNES", "CNES_EXEC", "CNS_PAC", "CODUNI"],
    "proc": ["PA_PROC_ID", "PROC_REA", "PROC_ID", "COD_PROC"],
    "qty": ["PA_QTDAPR", "QTDAPR", "PA_QTDPRO", "QT_APRES"],
    "value": ["PA_VALAPR", "VALAPR", "VL_APRES"],
}

# O schema_audit (O4) nomeia os papeis geograficos como residence_muni /
# provider_muni; aqui os buckets sao residence / provider. Mapeia os aliases do
# audit para o papel canonico do O6 (sem isso, a busca no audit falha e o
# fallback some com RAAS-PS).
AUDIT_ROLE_ALIASES = {
    "residence_muni": "residence",
    "provider_muni": "provider",
}


def family_dir(fam: str) -> Path:
    return RAAS_DIR if fam.startswith("raas") else SIA_DIR


def family_glob(fam: str, sy: int, ey: int) -> str | None:
    """Glob de parquet convertido para uma familia; None se nada existe."""
    base = family_dir(fam)
    g = base / f"family={fam}"
    if not g.exists():
        return None
    # Confere se ha algum parquet no intervalo de anos.
    hits = []
    for y in range(sy, ey + 1):
        hits.extend((g / f"year={y}").glob("uf=*/*.parquet"))
    if not hits:
        return None
    return str(g / "year=*" / "uf=*" / "*.parquet")


def load_schema_audit() -> dict | None:
    """
    Retorna {family: {role: {'col': name, 'nonmiss': float}}} a partir do
    sia_raas_schema_audit.csv. None se ausente.
    Colunas esperadas: family,target_role,matched_column_name,non_missing_rate.
    """
    if not SCHEMA_AUDIT.exists():
        return None
    out: dict = {}
    with SCHEMA_AUDIT.open(newline="") as f:
        rdr = csv.DictReader(f)
        cols = {c.lower(): c for c in (rdr.fieldnames or [])}
        c_fam = cols.get("family")
        c_role = cols.get("target_role")
        c_col = cols.get("matched_column_name")
        c_nm = cols.get("non_missing_rate")
        if not (c_fam and c_role and c_col):
            log.warning("schema_audit sem colunas esperadas: %s", rdr.fieldnames)
            return None
        for row in rdr:
            fam = (row[c_fam] or "").strip()
            role = (row[c_role] or "").strip().lower()
            role = AUDIT_ROLE_ALIASES.get(role, role)
            col = (row[c_col] or "").strip()
            if not (fam and role and col):
                continue
            try:
                nm = float(row[c_nm]) if c_nm and row.get(c_nm) not in (None, "") else 1.0
            except ValueError:
                nm = 1.0
            # O audit pode ter VARIAS linhas por papel (ex.: raas_ps qty =
            # PA_QTDAPR, PA_QTDPRO, QTDATE, QTDPCN). Guarda TODOS os candidatos;
            # resolve_columns escolhe pela prioridade de FALLBACK_CANDIDATES.
            out.setdefault(fam, {}).setdefault(role, []).append({"col": col, "nonmiss": nm})
    return out or None


def resolve_columns(fam: str, available: set[str], audit: dict | None) -> tuple[dict, bool]:
    """
    Resolve nome real de cada papel para a familia. Retorna (mapping, used_fallback).
    mapping[role] = {'col': name|None, 'nonmiss': float}. col=None se nao achado.
    Prioriza schema_audit; fallback por padrao de candidatos.
    """
    mapping: dict = {}
    used_fallback = False
    aud_fam = (audit or {}).get(fam, {})
    for role, cands in FALLBACK_CANDIDATES.items():
        col = None
        nm = 0.0
        # 1) Audit: pode ter varios candidatos por papel. Prefere o que aparece
        #    primeiro na lista de prioridade FALLBACK_CANDIDATES e existe nos
        #    dados; senao, primeiro candidato do audit presente nas colunas.
        aud_cands = aud_fam.get(role, [])
        if aud_cands:
            by_col = {a["col"]: a for a in aud_cands if a["col"] in available}
            for c in cands:
                if c in by_col:
                    col, nm = by_col[c]["col"], by_col[c]["nonmiss"]
                    break
            if col is None:
                for a in aud_cands:
                    if a["col"] in available:
                        col, nm = a["col"], a["nonmiss"]
                        break
        # 2) Fallback puro: primeiro candidato presente nas colunas reais.
        if col is None:
            for c in cands:
                if c in available:
                    col = c
                    nm = 1.0
                    used_fallback = True
                    break
        mapping[role] = {"col": col, "nonmiss": nm}
    return mapping, used_fallback


def parquet_columns(con: duckdb.DuckDBPyConnection, glob: str) -> set[str]:
    desc = con.execute(
        f"SELECT * FROM read_parquet('{glob}', union_by_name=true) LIMIT 0"
    ).description
    return {d[0] for d in desc}


def load_codebook(con: duckdb.DuckDBPyConnection) -> bool:
    """
    Cria TEMP TABLE codebook(proc_code STRING, category STRING). True se carregado.
    Espera colunas: proc_code, category, mental_health_flag.
    """
    if not CODEBOOK.exists():
        return False
    con.execute(
        f"""
        CREATE OR REPLACE TEMP TABLE codebook_raw AS
        SELECT * FROM read_csv_auto('{CODEBOOK}', header=true, all_varchar=true)
        """
    )
    cb_cols = {d[0].lower(): d[0] for d in con.execute("SELECT * FROM codebook_raw LIMIT 0").description}
    c_code = cb_cols.get("proc_code")
    c_cat = cb_cols.get("category")
    c_flag = cb_cols.get("mental_health_flag")
    if not c_code:
        log.warning("codebook sem coluna proc_code: %s", list(cb_cols.values()))
        return False
    flag_clause = ""
    if c_flag:
        # aceita 1/true/yes/sim
        flag_clause = (
            f"WHERE lower(CAST(\"{c_flag}\" AS VARCHAR)) IN ('1','true','t','yes','y','sim')"
        )
    cat_expr = f'"{c_cat}"' if c_cat else "'mental_health'"
    con.execute(
        f"""
        CREATE OR REPLACE TEMP TABLE codebook AS
        SELECT DISTINCT
            -- normaliza proc_code: tira nao-digitos, zero-pad para 10 (padrao SIGTAP)
            regexp_replace(CAST("{c_code}" AS VARCHAR), '[^0-9]', '', 'g') AS proc_code,
            lower(CAST({cat_expr} AS VARCHAR))                              AS category
        FROM codebook_raw
        {flag_clause}
        """
    )
    n = con.execute("SELECT COUNT(*) FROM codebook").fetchone()[0]
    log.info("codebook: %d procedimentos de saude mental", n)
    return n > 0


def pop_source(con: duckdb.DuckDBPyConnection) -> str:
    """
    Cria TEMP TABLE pop(codmun_6, year, pop). Prefere pop ja no staggered panel
    (mantem rates consistentes com psych_adm_per1k); fallback pop_municipal.
    Retorna label da fonte usada.
    """
    if STAGGERED.exists():
        sp_cols = parquet_columns(con, str(STAGGERED))
        if {"codmun_6", "year", "pop"} <= sp_cols:
            con.execute(
                f"""
                CREATE OR REPLACE TEMP TABLE pop AS
                SELECT DISTINCT
                    CAST(codmun_6 AS VARCHAR) AS codmun_6,
                    CAST(year AS INTEGER)     AS year,
                    MAX(pop)                  AS pop
                FROM read_parquet('{STAGGERED}')
                WHERE pop IS NOT NULL
                GROUP BY 1, 2
                """
            )
            return "staggered_panel_pnash48_ext"
    if POP_FALLBACK.exists():
        con.execute(
            f"""
            CREATE OR REPLACE TEMP TABLE pop AS
            SELECT SUBSTR(CAST(cod_mun AS VARCHAR), 1, 6) AS codmun_6,
                   CAST(ano AS INTEGER)                   AS year,
                   MAX(pop)                               AS pop
            FROM read_parquet('{POP_FALLBACK}')
            GROUP BY 1, 2
            """
        )
        return "pop_municipal_2015_2025 (fallback)"
    return ""


def stage_family(
    con: duckdb.DuckDBPyConnection,
    fam: str,
    glob: str,
    cols: dict,
    sy: int,
    ey: int,
    have_codebook: bool,
) -> int:
    """
    Le a familia, filtra procedimentos de SM via codebook, e materializa uma
    tabela longa fam_rows(basis-agnostic) com ambas as chaves geograficas
    (res_codmun_6 + prov_codmun_6), categoria, qty, value, cnes.
    Le por ano para nao carregar tudo de uma vez (chunking).
    Retorna n linhas materializadas.
    """
    proc_col = cols["proc"]["col"]
    qty_col = cols["qty"]["col"]
    val_col = cols["value"]["col"]
    res_col = cols["residence"]["col"]
    prov_col = cols["provider"]["col"]
    cnes_col = cols["cnes"]["col"]

    if proc_col is None:
        log.warning("[%s] sem coluna de procedimento -> familia ignorada", fam)
        return 0
    if prov_col is None and res_col is None:
        log.warning("[%s] sem coluna geografica -> familia ignorada", fam)
        return 0

    # Helpers de SQL defensivos: colunas ausentes viram NULL.
    def g6(c):
        # codmun_6: DATASUS ja e 6-digit; se 7, SUBSTR(1,6). LPAD garante 6.
        if c is None:
            return "NULL"
        return f"SUBSTR(LPAD(regexp_replace(CAST(\"{c}\" AS VARCHAR),'[^0-9]','','g'),6,'0'),1,6)"

    proc_norm = f"regexp_replace(CAST(\"{proc_col}\" AS VARCHAR),'[^0-9]','','g')"
    qty_expr = f"TRY_CAST(\"{qty_col}\" AS DOUBLE)" if qty_col else "1.0"
    val_expr = f"TRY_CAST(\"{val_col}\" AS DOUBLE)" if val_col else "0.0"
    cnes_expr = f"CAST(\"{cnes_col}\" AS VARCHAR)" if cnes_col else "NULL"

    # Regular (NOT temp) table so the on-disk buffer manager pages it to disk;
    # a temp/in-memory accumulator at line-item grain (~770M rows) OOMs.
    con.execute(f'CREATE OR REPLACE TABLE "rows_{fam}" (\
        family VARCHAR, year INTEGER, res_codmun_6 VARCHAR, prov_codmun_6 VARCHAR, \
        cnes VARCHAR, category VARCHAR, qty DOUBLE, value DOUBLE)')

    join_cb = (
        "JOIN codebook cb ON cb.proc_code = t.proc_norm"
        if have_codebook
        else "LEFT JOIN (SELECT NULL::VARCHAR proc_code, 'all_outpatient'::VARCHAR category) cb ON FALSE"
    )
    cat_expr = "cb.category" if have_codebook else "'all_outpatient'"

    total = 0
    for y in range(sy, ey + 1):
        yglob = glob.replace("year=*", f"year={y}")
        # pula anos vazios
        if not list(family_dir(fam).glob(f"family={fam}/year={y}/uf=*/*.parquet")):
            continue
        # Collapse to the patient-flow EDGE grain in the INSERT itself: tens of
        # millions of line items per year -> distinct (res,prov,cnes,category)
        # with summed qty/value. Exact downstream because cnes+category stay in
        # the grain (panel-level SUM(buckets) and COUNT(DISTINCT cnes) unchanged),
        # and the hash aggregation spills instead of materialising every line.
        con.execute(
            f"""
            INSERT INTO "rows_{fam}"
            SELECT
                '{fam}'                AS family,
                {y}                    AS year,
                {g6(res_col)}          AS res_codmun_6,
                {g6(prov_col)}         AS prov_codmun_6,
                {cnes_expr}            AS cnes,
                {cat_expr}             AS category,
                SUM(COALESCE({qty_expr}, 0.0))  AS qty,
                SUM(COALESCE({val_expr}, 0.0))  AS value
            FROM (
                SELECT *, {proc_norm} AS proc_norm
                FROM read_parquet('{yglob}', union_by_name=true)
            ) t
            {join_cb}
            GROUP BY 1, 2, 3, 4, 5, 6
            """
        )
        n = con.execute(f'SELECT COUNT(*) FROM "rows_{fam}" WHERE year={y}').fetchone()[0]
        total = con.execute(f'SELECT COUNT(*) FROM "rows_{fam}"').fetchone()[0]
        log.info("[%s] year=%d -> +%s linhas de SM (acum %s)", fam, y, f"{n:,}", f"{total:,}")
    return total


# Mapeia categoria do codebook -> buckets de outcome. Categorias do codebook
# variam; usamos matching por substring (lower) defensivo.
def bucket_case(cat_col: str) -> dict[str, str]:
    c = f"lower(COALESCE({cat_col},''))"
    return {
        "caps_procedures": f"CASE WHEN {c} LIKE '%caps%' THEN qty ELSE 0 END",
        "psychiatric_consults": f"CASE WHEN {c} LIKE '%consult%' OR {c} LIKE '%psiquiat%' THEN qty ELSE 0 END",
        "psychotherapy_actions": f"CASE WHEN {c} LIKE '%psicoterap%' OR {c} LIKE '%therap%' THEN qty ELSE 0 END",
        "alcohol_drug_actions": f"CASE WHEN {c} LIKE '%alcool%' OR {c} LIKE '%alcohol%' OR {c} LIKE '%drog%' OR {c} LIKE '%ad%' THEN qty ELSE 0 END",
    }


COUNT_OUTCOMES = [
    "total_mh_procedures",
    "caps_procedures",
    "raas_psychosocial_actions",
    "psychiatric_consults",
    "psychotherapy_actions",
    "alcohol_drug_actions",
]


def aggregate_panel(
    con: duckdb.DuckDBPyConnection,
    geo_col: str,
    fam_tables: list[str],
    pop_label: str,
) -> str:
    """
    Agrega a tabela longa unificada por (geo_col -> codmun_6, year). geo_col e
    'res_codmun_6' ou 'prov_codmun_6'. Cria TEMP TABLE 'agg'. Retorna nome.
    raas_psychosocial_actions = qty da familia raas_ps.
    """
    union = " UNION ALL ".join(f'SELECT * FROM "{t}"' for t in fam_tables)
    bk = bucket_case("category")
    # Aggregate straight from the edge-grain union to (codmun_6, year). The geo
    # filter is inlined into WHERE so we never re-materialise a second full copy.
    con.execute(
        f"""
        CREATE OR REPLACE TEMP TABLE agg AS
        SELECT
            {geo_col}                          AS codmun_6,
            year,
            SUM(qty)                           AS total_mh_procedures,
            SUM({bk['caps_procedures']})       AS caps_procedures,
            SUM(CASE WHEN family='raas_ps' THEN qty ELSE 0 END) AS raas_psychosocial_actions,
            SUM({bk['psychiatric_consults']})  AS psychiatric_consults,
            SUM({bk['psychotherapy_actions']}) AS psychotherapy_actions,
            SUM({bk['alcohol_drug_actions']})  AS alcohol_drug_actions,
            SUM(value)                         AS mh_value,
            COUNT(DISTINCT cnes)               AS n_cnes_mh_providers,
            COUNT(DISTINCT CASE WHEN lower(COALESCE(category,'')) LIKE '%caps%'
                                THEN cnes END) AS n_caps_providers
        FROM ({union})
        WHERE {geo_col} IS NOT NULL AND {geo_col} <> '' AND {geo_col} NOT LIKE '%NULL%'
        GROUP BY 1, 2
        """
    )
    return "agg"


def write_panel(con: duckdb.DuckDBPyConnection, basis: str, out: Path, sy: int, ey: int) -> int:
    """Junta agg com pop+staggered, normaliza per1k, grava. Retorna n linhas."""
    has_stag = STAGGERED.exists()
    if has_stag:
        stag_join = f"""
            LEFT JOIN (
                SELECT DISTINCT CAST(codmun_6 AS VARCHAR) AS codmun_6,
                       CAST(year AS INTEGER) AS year,
                       FIRST(uf) AS uf, FIRST(g_emb) AS g_emb
                FROM read_parquet('{STAGGERED}')
                GROUP BY 1,2
            ) s USING (codmun_6, year)
        """
        uf_sel, gemb_sel = "s.uf", "s.g_emb"
    else:
        stag_join, uf_sel, gemb_sel = "", "NULL AS uf", "NULL AS g_emb"

    per1k = ",\n".join(
        f"CASE WHEN p.pop>0 THEN 1000.0*a.{o}/p.pop ELSE NULL END AS {o}_per1k"
        for o in COUNT_OUTCOMES
    )
    con.execute(
        f"""
        COPY (
            SELECT
                a.codmun_6, a.year,
                p.pop,
                {uf_sel}, {gemb_sel},
                '{basis}' AS basis,
                a.total_mh_procedures, a.caps_procedures, a.raas_psychosocial_actions,
                a.psychiatric_consults, a.psychotherapy_actions, a.alcohol_drug_actions,
                a.mh_value, a.n_cnes_mh_providers, a.n_caps_providers,
                CASE WHEN p.pop>0 THEN a.mh_value/p.pop ELSE NULL END AS mh_value_per_capita,
                {per1k}
            FROM agg a
            LEFT JOIN pop p USING (codmun_6, year)
            {stag_join}
            WHERE a.year BETWEEN {sy} AND {ey}
            ORDER BY a.codmun_6, a.year
        ) TO '{out}' (FORMAT PARQUET, COMPRESSION 'snappy')
        """
    )
    return con.execute(f"SELECT COUNT(*) FROM read_parquet('{out}')").fetchone()[0]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--start-year", type=int, default=2010)
    ap.add_argument("--end-year", type=int, default=2024)
    ap.add_argument("--families", nargs="+", default=["all"],
                    choices=["sia_pa", "raas_ps", "all"])
    args = ap.parse_args()

    header = runtime_header(ROOT)
    log.info("runtime: %s", header)

    if OUT_RES.exists() and OUT_PROV.exists() and not args.force:
        log.info("outputs ja existem -- use --force para reprocessar")
        write_json(JSON_FILE, {"status": "skipped_existing", "telemetry": header})
        return

    fams = FAMILIES_ALL if "all" in args.families else list(args.families)
    sy, ey = args.start_year, args.end_year

    # An IN-MEMORY DuckDB keeps STORED-table data resident in RAM -- only operator
    # intermediates (joins/sorts) honour temp_directory. Staging the national
    # SIA-PA+RAAS line items (~770M rows) into such a table OOM-kills the process
    # regardless of memory_limit. Use an on-disk database file so the buffer
    # manager pages stored tables to disk; memory_limit then actually binds.
    dbfile = Path(os.environ.get(
        "DUCKDB_WORK_DB", str(ROOT / "cache" / "o6_build.duckdb")))
    dbfile.parent.mkdir(parents=True, exist_ok=True)
    for stale in (dbfile, dbfile.with_suffix(dbfile.suffix + ".wal")):
        if stale.exists():
            stale.unlink()
    con = duckdb.connect(str(dbfile))
    con.execute("PRAGMA threads=12")
    spill = os.environ.get("DUCKDB_SPILL_DIR", str(ROOT / "cache" / "duckdb_spill"))
    Path(spill).mkdir(parents=True, exist_ok=True)
    con.execute(f"PRAGMA temp_directory='{spill}'")
    con.execute(f"PRAGMA memory_limit='{os.environ.get('DUCKDB_MEM_LIMIT', '14GB')}'")
    log.info("duckdb on-disk db=%s spill=%s", dbfile, spill)
    timer = StepTimer(log)

    # --- inputs criticos: parquet convertido existe para alguma familia? ---
    fam_globs = {f: family_glob(f, sy, ey) for f in fams}
    fam_globs = {f: g for f, g in fam_globs.items() if g}
    if not fam_globs:
        log.error("Nenhum parquet SIA/RAAS convertido encontrado em %s | %s -- "
                  "rode a conversao upstream primeiro. exit 0.", SIA_DIR, RAAS_DIR)
        write_json(JSON_FILE, {"status": "missing_input_converted_parquet",
                               "telemetry": header})
        return

    pop_label = pop_source(con)
    if not pop_label:
        log.error("Sem fonte de populacao (staggered nem fallback). exit 0.")
        write_json(JSON_FILE, {"status": "missing_pop", "telemetry": header})
        return
    log.info("populacao: fonte=%s", pop_label)

    have_codebook = load_codebook(con)
    if not have_codebook:
        log.warning("CODEBOOK ausente/vazio (%s) -- produzindo diagnostico "
                    "'all_outpatient' NAO filtrado por saude mental.", CODEBOOK)

    audit = load_schema_audit()
    if audit is None:
        log.warning("schema_audit ausente (%s) -- usando FALLBACK de candidatos.", SCHEMA_AUDIT)

    timer.mark("load_inputs")

    # --- stage cada familia (resolve colunas + filtra SM + chunk por ano) ---
    fam_tables: list[str] = []
    res_eligible: list[str] = []  # familias com residencia adequada
    diag_rows: list[dict] = []
    for fam, glob in fam_globs.items():
        available = parquet_columns(con, glob)
        cols, used_fb = resolve_columns(fam, available, audit)
        res_info = cols["residence"]
        res_ok = res_info["col"] is not None and res_info["nonmiss"] >= RES_MIN_NONMISS
        log.info("[%s] cols resolvidas: %s (fallback=%s) | residence_ok=%s (col=%s nonmiss=%.2f)",
                 fam, {k: v["col"] for k, v in cols.items()}, used_fb,
                 res_ok, res_info["col"], res_info["nonmiss"])
        n = stage_family(con, fam, glob, cols, sy, ey, have_codebook)
        if n > 0:
            fam_tables.append(f"rows_{fam}")
            if res_ok:
                res_eligible.append(fam)
        diag_rows.append({
            "family": fam,
            "n_mh_rows": n,
            "residence_col": res_info["col"] or "",
            "residence_nonmiss": round(res_info["nonmiss"], 4),
            "residence_eligible": res_ok,
            "provider_col": cols["provider"]["col"] or "",
            "proc_col": cols["proc"]["col"] or "",
            "qty_col": cols["qty"]["col"] or "",
            "value_col": cols["value"]["col"] or "",
            "cnes_col": cols["cnes"]["col"] or "",
            "used_fallback_columns": used_fb,
        })
    timer.mark("stage_families")

    if not fam_tables:
        log.error("Nenhuma linha de saude mental materializada. exit 0.")
        write_json(JSON_FILE, {"status": "no_mh_rows", "telemetry": header})
        return

    # --- (b) PROVIDER panel: sempre construivel, TODAS as familias staged ---
    aggregate_panel(con, "prov_codmun_6", fam_tables, pop_label)
    n_prov = write_panel(con, "provider", OUT_PROV, sy, ey)
    n_prov_munis = con.execute(
        f"SELECT COUNT(DISTINCT codmun_6) FROM read_parquet('{OUT_PROV}')").fetchone()[0]
    log.info("[provider] %s linhas, %s municipios -> %s",
             f"{n_prov:,}", f"{n_prov_munis:,}", OUT_PROV.name)
    timer.mark("provider_panel")

    # --- (a) RESIDENCE panel: SO familias com residencia adequada ---
    n_res = 0
    n_res_munis = 0
    if res_eligible:
        res_tables = [f"rows_{f}" for f in res_eligible]
        aggregate_panel(con, "res_codmun_6", res_tables, pop_label)
        n_res = write_panel(con, "residence", OUT_RES, sy, ey)
        n_res_munis = con.execute(
            f"SELECT COUNT(DISTINCT codmun_6) FROM read_parquet('{OUT_RES}')").fetchone()[0]
        log.info("[residence] %s linhas, %s municipios (familias=%s) -> %s",
                 f"{n_res:,}", f"{n_res_munis:,}", res_eligible, OUT_RES.name)
    else:
        # Escreve um residence panel VAZIO (mesmo schema) e sinaliza no summary.
        log.warning("NENHUMA familia atingiu residence non-missing >= %.2f -- "
                    "residence panel sera vazio/flag. SIA-PA frequentemente sem MUNPCN.",
                    RES_MIN_NONMISS)
        con.execute("CREATE OR REPLACE TEMP TABLE agg AS SELECT NULL::VARCHAR codmun_6, "
                    "NULL::INTEGER year, NULL::DOUBLE total_mh_procedures, "
                    "NULL::DOUBLE caps_procedures, NULL::DOUBLE raas_psychosocial_actions, "
                    "NULL::DOUBLE psychiatric_consults, NULL::DOUBLE psychotherapy_actions, "
                    "NULL::DOUBLE alcohol_drug_actions, NULL::DOUBLE mh_value, "
                    "NULL::BIGINT n_cnes_mh_providers, NULL::BIGINT n_caps_providers "
                    "WHERE FALSE")
        n_res = write_panel(con, "residence", OUT_RES, sy, ey)
    timer.mark("residence_panel")

    # --- SIGTAP-pending labeling ----------------------------------------
    # Colunas de outcome fino (caps/consult/psicoterapia/alcool-droga) zeram
    # offline: o codebook source-grounded so rende categorias COARSE
    # (sia_psychosocial/raas_psychosocial); distinguir os finos precisa do
    # texto descritivo do SIGTAP (adiado). Calculamos aqui QUAIS colunas estao
    # inteiramente zeradas no painel (sum==0) para rotular -- nunca dropamos
    # as colunas (schema estavel para quando o SIGTAP entrar).
    outcome_cols = COUNT_OUTCOMES + ["mh_value", "n_cnes_mh_providers", "n_caps_providers"]
    # Soma sobre os dois panels escritos: provider sempre existe; residence
    # tambem (vazio nao gera coluna populada). Uma coluna so e "pending" se
    # zera em AMBOS (uniao das fontes nao a popula).
    panel_paths = [str(OUT_PROV)]
    if n_res and n_res > 0:
        panel_paths.append(str(OUT_RES))
    sum_select = ", ".join(f"COALESCE(SUM({c}),0) AS {c}" for c in outcome_cols)
    union_panels = " UNION ALL ".join(
        f"SELECT {', '.join(outcome_cols)} FROM read_parquet('{p}')" for p in panel_paths
    )
    sums = con.execute(
        f"SELECT {sum_select} FROM ({union_panels})"
    ).fetchone()
    col_sum = dict(zip(outcome_cols, sums))
    sigtap_pending = [c for c in outcome_cols if (col_sum[c] or 0) == 0]
    populated = [c for c in outcome_cols if (col_sum[c] or 0) != 0]
    log.info("SIGTAP-pending (all-zero) outcomes: %s", sigtap_pending)
    log.info("populated outcomes: %s", populated)

    # --- summary CSV (diagnosticos de cobertura) ---
    years_present = con.execute(
        f"SELECT MIN(year), MAX(year) FROM read_parquet('{OUT_PROV}')").fetchone()
    with OUT_SUMMARY.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["section", "key", "value"])
        w.writerow(["global", "families_used", "|".join(fam_globs.keys())])
        w.writerow(["global", "year_min", years_present[0]])
        w.writerow(["global", "year_max", years_present[1]])
        w.writerow(["global", "pop_source", pop_label])
        w.writerow(["global", "codebook_present", have_codebook])
        w.writerow(["global", "mental_health_filtered", have_codebook])
        w.writerow(["global", "schema_audit_present", audit is not None])
        w.writerow(["global", "residence_min_nonmiss_threshold", RES_MIN_NONMISS])
        w.writerow(["global", "residence_panel_buildable", bool(res_eligible)])
        w.writerow(["global", "residence_n_rows", n_res])
        w.writerow(["global", "residence_n_munis", n_res_munis])
        w.writerow(["global", "provider_n_rows", n_prov])
        w.writerow(["global", "provider_n_munis", n_prov_munis])
        w.writerow(["global", "residence_eligible_families", "|".join(res_eligible) or "NONE"])
        # SIGTAP-pending labeling: zeros computados, nao hardcoded. Distingue
        # "0 porque SIGTAP nao carregado" de "0 ambulatorial medido".
        w.writerow(["global", "sigtap_pending_outcomes", "|".join(sigtap_pending)])
        w.writerow(["global", "populated_outcomes", "|".join(populated)])
        w.writerow(["global", "sigtap_pending_reason",
                    "fine MH categories require SIGTAP descriptions (offline "
                    "source-grounded codebook only yields coarse "
                    "sia_psychosocial/raas_psychosocial)"])
        w.writerow([])
        w.writerow(["family", "field", "value"])
        for d in diag_rows:
            for k, v in d.items():
                if k == "family":
                    continue
                w.writerow([d["family"], k, v])
    log.info("summary -> %s", OUT_SUMMARY.name)

    payload = {
        "status": "ok",
        "telemetry": header,
        "families_used": list(fam_globs.keys()),
        "residence_eligible_families": res_eligible,
        "mental_health_filtered": have_codebook,
        "schema_audit_present": audit is not None,
        "n_residence_rows": n_res,
        "n_provider_rows": n_prov,
        "peak_rss_gb": timer.peak_rss_gb,
        "outputs": {
            "residence": str(OUT_RES),
            "provider": str(OUT_PROV),
            "summary": str(OUT_SUMMARY),
        },
    }
    write_json(JSON_FILE, payload)
    timer.mark("write_summary")

    # The on-disk work db holds the edge-grain accumulator (can be tens of GB);
    # drop it once the panels are written.
    con.close()
    for stale in (dbfile, dbfile.with_suffix(dbfile.suffix + ".wal")):
        if stale.exists():
            stale.unlink()
    log.info("==== done ====")


if __name__ == "__main__":
    main()
