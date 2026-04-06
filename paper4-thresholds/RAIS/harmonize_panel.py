#!/usr/bin/env python3
"""
Harmonize RAIS vínculos parquet files across years (2009-2017) into a
consistent panel with unified column names, types, and ordering.

Three eras of variable naming:
  - 2009-2010: short UPPERCASE names (MUNICIPIO, CLAS CNAE 95, etc.)
  - 2011-2014: descriptive Portuguese (Município, CNAE 95 Classe, etc.)
  - 2015-2017: same as 2011-2014 + new variables (CEP, Razão Social, monthly wages)

This script:
  1. Renames all variants to a single canonical name (snake_case English)
  2. Casts types to be consistent across years
  3. Outputs harmonized parquet files to RAIS/parquet/harmonized/

Usage:
    python3 harmonize_panel.py              # process all
    python3 harmonize_panel.py --dry-run    # show plan without writing
    python3 harmonize_panel.py --year 2012  # process single year
"""
import polars as pl
import gc
import sys
import time
from pathlib import Path

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS/parquet")
SRC = BASE / "vinculos"
DST = BASE / "harmonized"

DRY_RUN = "--dry-run" in sys.argv
SINGLE_YEAR = None
if "--year" in sys.argv:
    idx = sys.argv.index("--year")
    SINGLE_YEAR = int(sys.argv[idx + 1])

# ════════════════════════════════════════════════════════════════════════
# RENAME DICTIONARIES
# Canonical names: snake_case English for code consistency
# ════════════════════════════════════════════════════════════════════════

# Mapping from ALL source variants → canonical name
# Organized by conceptual group for readability

RENAME = {
    # ── Geography / Establishment ──
    "MUNICIPIO":                     "mun_estab",
    "Município":                     "mun_estab",
    "Mun Trab":                      "mun_trab",

    # ── Sector / Activity ──
    "CLAS CNAE 95":                  "cnae95_classe",
    "CNAE 95 Classe":                "cnae95_classe",
    "CLAS CNAE 20":                  "cnae20_classe",
    "CNAE 2.0 Classe":               "cnae20_classe",
    "SB CLAS 20":                    "cnae20_subclasse",
    "CNAE 2.0 Subclasse":            "cnae20_subclasse",
    "IBGE Subsetor":                 "ibge_subsetor",

    # ── Employment link ──
    "EMP EM 31/12":                  "vinculo_ativo_3112",
    "Vínculo Ativo 31/12":           "vinculo_ativo_3112",
    "TP VINCULO":                    "tipo_vinculo",
    "Tipo Vínculo":                  "tipo_vinculo",
    "IND ALVARA":                    "ind_alvara",
    "Ind Vínculo Alvará":            "ind_alvara",
    "TIPO ADM":                      "tipo_admissao",
    "Tipo Admissão":                 "tipo_admissao",
    "CAUSA DESLI":                   "motivo_desligamento",
    "Motivo Desligamento":           "motivo_desligamento",
    "MES DESLIG":                    "mes_desligamento",
    "Mês Desligamento":              "mes_desligamento",
    "DIA DESL":                      "dia_desligamento",
    "Dia de Desligamento":           "dia_desligamento",
    "DT ADMISSAO":                   "data_admissao",
    "Data Admissão Declarada":       "data_admissao",
    "TEMP EMPR":                     "tempo_emprego",
    "Tempo Emprego":                 "tempo_emprego",

    # ── Wages / Salary ──
    "TIPO SAL":                      "tipo_salario",
    "Tipo Salário":                  "tipo_salario",
    "REM MED (R$)":                  "rem_media_nom",
    "Vl Remun Média Nom":            "rem_media_nom",
    "REM MEDIA":                     "rem_media_sm",
    "Vl Remun Média (SM)":           "rem_media_sm",
    "REM DEZ (R$)":                  "rem_dez_nom",
    "Vl Remun Dezembro Nom":         "rem_dez_nom",
    "REM DEZEMBRO":                  "rem_dez_sm",
    "Vl Remun Dezembro (SM)":        "rem_dez_sm",
    "ULT REM":                       "rem_ultima_ano",
    "Vl Última Remuneração Ano":     "rem_ultima_ano",
    "SAL CONTR":                     "sal_contratual",
    "Vl Salário Contratual":         "sal_contratual",
    "HORAS CONTR":                   "horas_contratuais",
    "Qtd Hora Contr":                "horas_contratuais",

    # Monthly wages (2015+)
    "Vl Rem Janeiro CC":             "rem_jan",
    "Vl Rem Fevereiro CC":           "rem_fev",
    "Vl Rem Março CC":               "rem_mar",
    "Vl Rem Abril CC":               "rem_abr",
    "Vl Rem Maio CC":                "rem_mai",
    "Vl Rem Junho CC":               "rem_jun",
    "Vl Rem Julho CC":               "rem_jul",
    "Vl Rem Agosto CC":              "rem_ago",
    "Vl Rem Setembro CC":            "rem_set",
    "Vl Rem Outubro CC":             "rem_out",
    "Vl Rem Novembro CC":            "rem_nov",

    # ── Worker demographics ──
    "GENERO":                        "sexo",
    "Sexo Trabalhador":              "sexo",
    "GR INSTRUCAO":                  "escolaridade",
    "Escolaridade após 2005":        "escolaridade",
    "NACIONALIDAD":                  "nacionalidade",
    "Nacionalidade":                 "nacionalidade",
    "RACA_COR":                      "raca_cor",
    "Raça Cor":                      "raca_cor",
    "PORT DEFIC":                    "ind_deficiencia",
    "Ind Portador Defic":            "ind_deficiencia",
    "TP DEFIC":                      "tipo_deficiencia",
    "Tipo Defic":                    "tipo_deficiencia",
    "DT NASCIMENT":                  "data_nascimento",
    "Data de Nascimento":            "data_nascimento",
    "Idade":                         "idade",

    # ── Worker identifiers ──
    "PIS":                           "pis",
    "CPF":                           "cpf",
    "NOME":                          "nome_trabalhador",
    "Nome Trabalhador":              "nome_trabalhador",
    "NUME CTPS":                     "num_ctps",
    "Número CTPS":                   "num_ctps",

    # ── Occupation ──
    "OCUPACAO 94":                   "cbo94",
    "CBO 94 Ocupação":               "cbo94",
    "OCUP 2002":                     "cbo2002",
    "CBO Ocupação 2002":             "cbo2002",

    # ── Establishment identifiers ──
    "IDENTIFICAD":                   "cnpj_cei",
    "CNPJ / CEI":                    "cnpj_cei",
    "RADIC CNPJ":                    "cnpj_raiz",
    "CNPJ Raiz":                     "cnpj_raiz",
    "CEI VINC":                      "cei_vinculado",
    "CEI Vinculado":                 "cei_vinculado",
    "IND CEI VINC":                  "ind_cei_vinculado",
    "Ind CEI Vinculado":             "ind_cei_vinculado",
    "TAMESTAB":                      "tamanho_estab",
    "Tamanho Estabelecimento":       "tamanho_estab",
    "NAT JURIDICA":                  "natureza_juridica",
    "Natureza Jurídica":             "natureza_juridica",
    "TIPO ESTBL":                    "tipo_estab",
    "TIPO ESTB ID":                  "tipo_estab_id",  # 2009 only, different from tipo_estab
    "Tipo Estab":                    "tipo_estab",
    "IND PAT":                       "ind_pat",
    "Ind Estab Participa PAT":       "ind_pat",
    "IND SIMPLES":                   "ind_simples",
    "Ind Simples":                   "ind_simples",
    "CEP Estab":                     "cep_estab",
    "Razão Social":                  "razao_social",

    # ── Leave of absence ──
    "CAUS AFAST 1":                  "causa_afast_1",
    "Causa Afastamento 1":           "causa_afast_1",
    "DIA INI AF 1":                  "dia_ini_afast_1",
    "Dia Ini AF1":                   "dia_ini_afast_1",
    "MES INI AF 1":                  "mes_ini_afast_1",
    "Mês Ini AF1":                   "mes_ini_afast_1",
    "DIA FIM AF 1":                  "dia_fim_afast_1",
    "Dia Fim AF1":                   "dia_fim_afast_1",
    "MES FIM AF 1":                  "mes_fim_afast_1",
    "Mês Fim AF1":                   "mes_fim_afast_1",
    "CAUS AFAST 2":                  "causa_afast_2",
    "Causa Afastamento 2":           "causa_afast_2",
    "DIA INI AF 2":                  "dia_ini_afast_2",
    "Dia Ini AF2":                   "dia_ini_afast_2",
    "MES INI AF 2":                  "mes_ini_afast_2",
    "Mês Ini AF2":                   "mes_ini_afast_2",
    "DIA FIM AF 2":                  "dia_fim_afast_2",
    "Dia Fim AF2":                   "dia_fim_afast_2",
    "MES FIM AF 2":                  "mes_fim_afast_2",
    "Mês Fim AF2":                   "mes_fim_afast_2",
    "CAUS AFAST 3":                  "causa_afast_3",
    "Causa Afastamento 3":           "causa_afast_3",
    "DIA INI AF 3":                  "dia_ini_afast_3",
    "Dia Ini AF3":                   "dia_ini_afast_3",
    "MES INI AF 3":                  "mes_ini_afast_3",
    "Mês Ini AF3":                   "mes_ini_afast_3",
    "DIA FIM AF 3":                  "dia_fim_afast_3",
    "Dia Fim AF3":                   "dia_fim_afast_3",
    "MES FIM AF 3":                  "mes_fim_afast_3",
    "Mês Fim AF3":                   "mes_fim_afast_3",
    "QT DIAS AFAS":                  "qtd_dias_afast",
    "Qtd Dias Afastamento":          "qtd_dias_afast",

    # ── Other ──
    "ANO CHEGADA2":                  "ano_chegada_brasil",
    "Ano Chegada Brasil":            "ano_chegada_brasil",
    "Ano Chegada Brasil_duplicated_0": "ano_chegada_brasil_dup",  # drop later
    "Ind Trab Parcial":              "ind_trab_parcial",
    "Ind Trab Intermitente":         "ind_trab_intermitente",
    "Ind Sindical":                  "ind_sindical",

    # ── Metadata added during conversion ──
    "ano":                           "ano",
    "uf_arquivo":                    "uf_arquivo",
}

# ════════════════════════════════════════════════════════════════════════
# CANONICAL SCHEMA: desired type for each harmonized column
# All columns cast to these types for consistency
# ════════════════════════════════════════════════════════════════════════

CANONICAL_TYPES = {
    # Geography
    "mun_estab":             pl.Int32,
    "mun_trab":              pl.Int32,
    # Sector
    "cnae95_classe":         pl.Int32,
    "cnae20_classe":         pl.Int32,
    "cnae20_subclasse":      pl.Int32,
    "ibge_subsetor":         pl.Int16,
    # Employment link
    "vinculo_ativo_3112":    pl.Int8,
    "tipo_vinculo":          pl.Int8,
    "ind_alvara":            pl.Int8,
    "tipo_admissao":         pl.Int8,
    "motivo_desligamento":   pl.Int8,
    "mes_desligamento":      pl.Int8,
    "dia_desligamento":      pl.Int8,
    "data_admissao":         pl.Int32,
    "tempo_emprego":         pl.Utf8,  # "X,YY" format varies, keep as string
    # Wages
    "tipo_salario":          pl.Int8,
    "rem_media_nom":         pl.Utf8,  # decimal comma strings → parse later
    "rem_media_sm":          pl.Utf8,
    "rem_dez_nom":           pl.Utf8,
    "rem_dez_sm":            pl.Utf8,
    "rem_ultima_ano":        pl.Utf8,
    "sal_contratual":        pl.Utf8,
    "horas_contratuais":     pl.Int16,
    # Monthly wages (2015+)
    "rem_jan":               pl.Utf8,
    "rem_fev":               pl.Utf8,
    "rem_mar":               pl.Utf8,
    "rem_abr":               pl.Utf8,
    "rem_mai":               pl.Utf8,
    "rem_jun":               pl.Utf8,
    "rem_jul":               pl.Utf8,
    "rem_ago":               pl.Utf8,
    "rem_set":               pl.Utf8,
    "rem_out":               pl.Utf8,
    "rem_nov":               pl.Utf8,
    # Demographics
    "sexo":                  pl.Int8,
    "escolaridade":          pl.Int8,
    "nacionalidade":         pl.Int16,
    "raca_cor":              pl.Int8,
    "ind_deficiencia":       pl.Int8,
    "tipo_deficiencia":      pl.Int8,
    "data_nascimento":       pl.Int32,
    "idade":                 pl.Int8,
    # Worker IDs
    "pis":                   pl.Int64,
    "cpf":                   pl.Utf8,  # may have leading zeros → string
    "nome_trabalhador":      pl.Utf8,
    "num_ctps":              pl.Int64,
    # Occupation
    "cbo94":                 pl.Utf8,
    "cbo2002":               pl.Utf8,
    # Establishment IDs
    "cnpj_cei":              pl.Utf8,  # may have leading zeros
    "cnpj_raiz":             pl.Utf8,
    "cei_vinculado":         pl.Int64,
    "ind_cei_vinculado":     pl.Int8,
    "tamanho_estab":         pl.Int8,
    "natureza_juridica":     pl.Int16,
    "tipo_estab":            pl.Int8,
    "tipo_estab_id":         pl.Int8,
    "ind_pat":               pl.Int8,
    "ind_simples":           pl.Int8,
    "cep_estab":             pl.Utf8,
    "razao_social":          pl.Utf8,
    # Leave
    "causa_afast_1":         pl.Int8,
    "dia_ini_afast_1":       pl.Int8,
    "mes_ini_afast_1":       pl.Int8,
    "dia_fim_afast_1":       pl.Int8,
    "mes_fim_afast_1":       pl.Int8,
    "causa_afast_2":         pl.Int8,
    "dia_ini_afast_2":       pl.Int8,
    "mes_ini_afast_2":       pl.Int8,
    "dia_fim_afast_2":       pl.Int8,
    "mes_fim_afast_2":       pl.Int8,
    "causa_afast_3":         pl.Int8,
    "dia_ini_afast_3":       pl.Int8,
    "mes_ini_afast_3":       pl.Int8,
    "dia_fim_afast_3":       pl.Int8,
    "mes_fim_afast_3":       pl.Int8,
    "qtd_dias_afast":        pl.Int16,
    # Other
    "ano_chegada_brasil":    pl.Int16,
    "ind_trab_parcial":      pl.Int8,
    "ind_trab_intermitente": pl.Int8,
    "ind_sindical":          pl.Int8,
    # Metadata
    "ano":                   pl.Int16,
    "uf_arquivo":            pl.Utf8,
}

# Columns to drop after rename (duplicates, artifacts)
DROP_COLS = {"ano_chegada_brasil_dup"}

# Ordered output columns (core first, then extras)
CORE_COLS = [
    # IDs
    "ano", "uf_arquivo", "pis", "cpf", "cnpj_cei", "cnpj_raiz",
    # Estab
    "mun_estab", "mun_trab", "tamanho_estab", "natureza_juridica",
    "tipo_estab", "cep_estab", "razao_social",
    # Sector
    "cnae95_classe", "cnae20_classe", "cnae20_subclasse", "ibge_subsetor",
    # Link
    "vinculo_ativo_3112", "tipo_vinculo", "tipo_admissao", "data_admissao",
    "motivo_desligamento", "mes_desligamento", "dia_desligamento",
    "tempo_emprego", "ind_alvara",
    # Demographics
    "sexo", "idade", "data_nascimento", "escolaridade",
    "nacionalidade", "raca_cor", "ind_deficiencia", "tipo_deficiencia",
    "nome_trabalhador", "num_ctps",
    # Occupation
    "cbo94", "cbo2002",
    # Wages
    "tipo_salario", "horas_contratuais",
    "rem_media_nom", "rem_media_sm", "rem_dez_nom", "rem_dez_sm",
    "rem_ultima_ano", "sal_contratual",
    # Monthly wages
    "rem_jan", "rem_fev", "rem_mar", "rem_abr", "rem_mai", "rem_jun",
    "rem_jul", "rem_ago", "rem_set", "rem_out", "rem_nov",
    # Estab flags
    "ind_pat", "ind_simples", "ind_cei_vinculado", "cei_vinculado",
    # Leave
    "causa_afast_1", "dia_ini_afast_1", "mes_ini_afast_1",
    "dia_fim_afast_1", "mes_fim_afast_1",
    "causa_afast_2", "dia_ini_afast_2", "mes_ini_afast_2",
    "dia_fim_afast_2", "mes_fim_afast_2",
    "causa_afast_3", "dia_ini_afast_3", "mes_ini_afast_3",
    "dia_fim_afast_3", "mes_fim_afast_3",
    "qtd_dias_afast",
    # Other
    "ano_chegada_brasil",
    "ind_trab_parcial", "ind_trab_intermitente", "ind_sindical",
]


# ════════════════════════════════════════════════════════════════════════
# PROCESSING
# ════════════════════════════════════════════════════════════════════════

def safe_cast(df: pl.DataFrame, col: str, target_type) -> pl.DataFrame:
    """Cast a column to target type, handling String→Int conversions."""
    if col not in df.columns:
        return df

    current_type = df[col].dtype

    if current_type == target_type:
        return df

    # ── Special case: sexo (GENERO) is "MASCULINO"/"FEMININO" in 2009-2010 ──
    if col == "sexo" and current_type == pl.Utf8:
        df = df.with_columns(
            pl.when(pl.col(col).str.to_uppercase().str.starts_with("M"))
            .then(pl.lit(1, dtype=pl.Int8))
            .when(pl.col(col).str.to_uppercase().str.starts_with("F"))
            .then(pl.lit(2, dtype=pl.Int8))
            .otherwise(pl.lit(None, dtype=pl.Int8))
            .alias(col)
        )
        return df

    # String → numeric: need to handle commas, non-numeric values
    if current_type == pl.Utf8 and target_type in (
        pl.Int8, pl.Int16, pl.Int32, pl.Int64, pl.Float32, pl.Float64
    ):
        # For integer targets from string: strip, replace comma, cast strict=False
        df = df.with_columns(
            pl.col(col)
            .str.strip_chars()
            .str.replace(",", ".", literal=True)
            .cast(pl.Float64, strict=False)
            .cast(target_type, strict=False)
            .alias(col)
        )
        return df

    # Numeric → String
    if target_type == pl.Utf8:
        df = df.with_columns(pl.col(col).cast(pl.Utf8, strict=False).alias(col))
        return df

    # Numeric → smaller numeric
    try:
        df = df.with_columns(pl.col(col).cast(target_type, strict=False).alias(col))
    except Exception:
        # Fallback: go through string
        df = df.with_columns(
            pl.col(col).cast(pl.Utf8).cast(target_type, strict=False).alias(col)
        )
    return df


def zero_pad_ids(df: pl.DataFrame) -> pl.DataFrame:
    """Zero-pad CNPJ/CPF fields that were stored as int64 and lost leading zeros."""
    # CNPJ/CEI: 14 digits
    if "cnpj_cei" in df.columns:
        df = df.with_columns(
            pl.col("cnpj_cei").str.zfill(14).alias("cnpj_cei")
        )
    # CNPJ raiz: 8 digits
    if "cnpj_raiz" in df.columns:
        df = df.with_columns(
            pl.col("cnpj_raiz").str.zfill(8).alias("cnpj_raiz")
        )
    # CPF: 11 digits
    if "cpf" in df.columns:
        df = df.with_columns(
            pl.col("cpf").str.zfill(11).alias("cpf")
        )
    return df


def harmonize_batch(df: pl.DataFrame, year: int, rename_map: dict,
                    cols_to_drop: list, warned_unmapped: set) -> pl.DataFrame:
    """Harmonize a single polars DataFrame batch (column rename, cast, pad)."""

    # Drop known extras
    for col in ("uf",):
        if col in df.columns:
            df = df.drop(col)

    # Drop duplicate-target columns
    for col in cols_to_drop:
        if col in df.columns:
            df = df.drop(col)

    df = df.rename(rename_map)

    # Drop artifact columns
    for col in DROP_COLS:
        if col in df.columns:
            df = df.drop(col)

    # Cast types
    for col in df.columns:
        if col in CANONICAL_TYPES:
            df = safe_cast(df, col, CANONICAL_TYPES[col])

    # Zero-pad IDs
    df = zero_pad_ids(df)

    # ── Derive idade from data_nascimento when missing (2009-2010) ──
    # DT NASCIMENT is stored as Int64 in DDMMYYYY format (e.g. 29101958)
    if "idade" not in df.columns or df["idade"].is_null().all():
        if "data_nascimento" in df.columns:
            df = df.with_columns(
                (
                    pl.lit(year)
                    - (pl.col("data_nascimento") % 10000)  # extract YYYY
                ).cast(pl.Int8, strict=False).alias("idade")
            )

    # Add missing columns as null
    for col in CORE_COLS:
        if col not in df.columns and col in CANONICAL_TYPES:
            df = df.with_columns(
                pl.lit(None).cast(CANONICAL_TYPES[col]).alias(col)
            )

    # Reorder
    output_cols = [c for c in CORE_COLS if c in df.columns]
    extras = [c for c in df.columns if c not in CORE_COLS]
    df = df.select(output_cols + extras)

    return df


def _build_rename_map(filepath: Path) -> tuple[dict, list, list]:
    """Build rename map and detect issues from a parquet file's schema,
    WITHOUT loading any data. Returns (rename_map, cols_to_drop, unmapped)."""
    import pyarrow.parquet as pq
    schema = pq.read_schema(str(filepath))
    current_cols = [f.name for f in schema]

    rename_map = {}
    seen_targets = set()
    cols_to_drop = []
    known_extras = {"uf"}

    for col in current_cols:
        if col in RENAME:
            target = RENAME[col]
            if target in seen_targets:
                cols_to_drop.append(col)
                continue
            rename_map[col] = target
            seen_targets.add(target)

    unmapped = [c for c in current_cols if c not in RENAME and c not in known_extras]
    return rename_map, cols_to_drop, unmapped


# ── Memory-safe streaming batch size ──
# 300K rows × ~80 cols × ~200 bytes ≈ 500MB per batch (safe for 15GB RAM)
STREAM_BATCH_SIZE = 300_000


def process_year(year: int):
    """Process all UF files for a year.
    Memory-safe: reads each UF in batches via pyarrow streaming,
    harmonizes batch-by-batch, writes to temp parquet incrementally.
    Then merges temp files via streaming (Phase 2)."""
    import pyarrow.parquet as pq
    import pyarrow as pa
    import tempfile
    import shutil

    files = sorted(SRC.glob(f"*_{year}.parquet")) + sorted(SRC.glob(f"*_{year}_*.parquet"))
    if not files:
        print(f"  No files for {year}")
        return

    out_path = DST / f"rais_vinculos_{year}.parquet"
    if out_path.exists():
        print(f"  SKIP {year}: {out_path.name} exists")
        return

    print(f"  Processing {year}: {len(files)} files...", flush=True)
    t0 = time.time()

    # Phase 1: harmonize each UF → temp parquet (streaming, batch-by-batch)
    tmp_dir = Path(tempfile.mkdtemp(prefix=f"rais_harm_{year}_"))
    temp_files = []
    total_rows = 0
    warned_unmapped = set()

    for i, f in enumerate(files, 1):
        try:
            file_size_mb = f.stat().st_size / 1e6
            rename_map, cols_to_drop, unmapped = _build_rename_map(f)
            if unmapped:
                new_unmapped = [c for c in unmapped if c not in warned_unmapped]
                if new_unmapped:
                    print(f"    WARNING: unmapped columns in {f.name}: {new_unmapped}")
                    warned_unmapped.update(new_unmapped)

            tmp_path = tmp_dir / f"tmp_{f.stem}.parquet"
            pf = pq.ParquetFile(str(f))
            writer = None
            file_rows = 0

            for batch in pf.iter_batches(batch_size=STREAM_BATCH_SIZE):
                # Convert arrow batch → polars DataFrame
                df_batch = pl.from_arrow(pa.Table.from_batches([batch]))
                # Harmonize
                df_batch = harmonize_batch(df_batch, year, rename_map,
                                           cols_to_drop, warned_unmapped)
                # Convert back to arrow for writing
                arrow_table = df_batch.to_arrow()
                if writer is None:
                    writer = pq.ParquetWriter(str(tmp_path), arrow_table.schema,
                                              compression="snappy")
                # Align schema (add missing columns) before writing
                for field in writer.schema:
                    if field.name not in arrow_table.column_names:
                        arrow_table = arrow_table.append_column(
                            field, pa.nulls(len(arrow_table), type=field.type)
                        )
                arrow_table = arrow_table.select([f.name for f in writer.schema])
                writer.write_table(arrow_table)

                file_rows += len(df_batch)
                del df_batch, arrow_table, batch
                gc.collect()

            if writer is not None:
                writer.close()
                temp_files.append(tmp_path)
            del pf
            gc.collect()

            total_rows += file_rows
            print(f"    [{i}/{len(files)}] {f.name}: {file_rows:,} rows "
                  f"({file_size_mb:.0f}MB)", flush=True)

        except Exception as e:
            print(f"    ERROR on {f.name}: {e}")
            import traceback
            traceback.print_exc()
            continue

    if not temp_files:
        print(f"  No data for {year}!")
        shutil.rmtree(tmp_dir)
        return

    # Phase 2: build unified schema from all temp files, then merge via streaming
    print(f"  Merging {len(temp_files)} temp files ({total_rows:,} rows)...", flush=True)

    # Build unified schema (union of all columns across UFs)
    all_schemas = [pq.read_schema(str(tf)) for tf in temp_files]
    unified_fields = {}
    for s in all_schemas:
        for field in s:
            if field.name not in unified_fields:
                unified_fields[field.name] = field
    unified_schema = pa.schema(list(unified_fields.values()))

    writer = pq.ParquetWriter(str(out_path), unified_schema, compression="snappy")
    MERGE_BATCH = 250_000

    for tmp_path in temp_files:
        pf = pq.ParquetFile(str(tmp_path))
        file_schema = pf.schema_arrow
        for batch in pf.iter_batches(batch_size=MERGE_BATCH):
            table = pa.Table.from_batches([batch], schema=file_schema)
            # Add missing columns as null to match unified schema
            for field in unified_schema:
                if field.name not in table.column_names:
                    table = table.append_column(
                        field, pa.nulls(len(table), type=field.type)
                    )
            # Reorder to match unified schema
            table = table.select([f.name for f in unified_schema])
            writer.write_table(table)
            del table, batch
        del pf
        gc.collect()

    writer.close()

    # Cleanup temp files
    shutil.rmtree(tmp_dir)

    elapsed = time.time() - t0
    out_size = out_path.stat().st_size / 1e9
    print(f"  DONE {year}: {total_rows:,} rows, {out_size:.2f}GB, {elapsed:.0f}s")
    gc.collect()


def main():
    DST.mkdir(parents=True, exist_ok=True)

    years = range(2009, 2018)
    if SINGLE_YEAR:
        years = [SINGLE_YEAR]

    if DRY_RUN:
        print("DRY RUN — showing plan")
        for year in years:
            files = sorted(SRC.glob(f"*_{year}.parquet")) + sorted(SRC.glob(f"*_{year}_*.parquet"))
            total_size = sum(f.stat().st_size for f in files) / 1e9
            print(f"  {year}: {len(files)} files, {total_size:.1f}GB")
        return

    print(f"Harmonizing RAIS vínculos panel (2009-2017)")
    print(f"Source: {SRC}")
    print(f"Output: {DST}")
    print(f"{'='*60}")

    for year in years:
        process_year(year)
        gc.collect()

    # Final summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    total_size = 0
    total_rows = 0
    for year in range(2009, 2018):
        f = DST / f"rais_vinculos_{year}.parquet"
        if f.exists():
            sz = f.stat().st_size / 1e9
            total_size += sz
            # Quick row count
            nrows = pl.scan_parquet(f).select(pl.len()).collect().item()
            total_rows += nrows
            print(f"  {year}: {nrows:>12,} rows, {sz:.2f}GB")

    print(f"  {'─'*40}")
    print(f"  Total: {total_rows:>12,} rows, {total_size:.2f}GB")


if __name__ == "__main__":
    main()
