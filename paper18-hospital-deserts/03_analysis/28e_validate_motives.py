#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import math
import sys
from pathlib import Path

import polars as pl

from _telemetry import StepTimer, runtime_header, write_json

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG_DIR = ROOT / "04_logs"
TAB_DIR = ROOT / "01_manuscript" / "tables"

IN_CLASS = INTER / "closures_classified_v2.parquet"
IN_EXO = INTER / "hospital_closures_exogenous.parquet"
OUT_SAMPLE = INTER / "closure_validation_sample.csv"
OUT_HUMAN = INTER / "closures_human_validated.parquet"
LOG_FILE = LOG_DIR / "28e_validate_motives.log"
JSON_FILE = LOG_DIR / "28e_validation.json"
JSON_FILE_V2 = LOG_DIR / "28e_validation_v2.json"
BLOCKED_FILE = LOG_DIR / "blocked_28e.md"
TABLE_FILE = TAB_DIR / "tab_motive_validation.tex"
SEED = 20260501


def build_logger() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(LOG_FILE, mode="w"), logging.StreamHandler(sys.stdout)],
    )
    return logging.getLogger("validate_motives")


def build_table(
    *,
    n_universe: int,
    n_sample: int,
    n_flagged: int,
    n_keep: int,
    coder_a_done: int,
    coder_b_done: int,
    adjudicated_done: int,
    kappa_label: str,
) -> None:
    lines = [
        "\\begin{table}[h!]",
        "\\centering",
        "\\caption{Documentary motive validation and sensitivity screen for exogenous closures. The two-coder audit remains incomplete in this workspace, but the fragility screen used to define the non-fragile subset is fully observed and is the relevant quantity for the Phase B re-estimation.}",
        "\\label{tab:motive-validation}",
        "\\small",
        "\\begin{tabular}{lcc}",
        "\\toprule",
        "Metric & Count & Status \\\\",
        "\\midrule",
        f"Documentary F5 universe & {n_universe} & observed \\\\",
        f"Blinded audit sample drawn (10\\% of F5 universe) & {n_sample} & observed \\\\",
        f"Coder A completed & {coder_a_done} & pending \\\\",
        f"Coder B completed & {coder_b_done} & pending \\\\",
        f"Adjudicated labels completed & {adjudicated_done} & pending \\\\",
        f"Cohen's $\\kappa$ & {kappa_label} & pending \\\\",
        f"Fragile closures dropped by sensitivity screen & {n_flagged} & observed \\\\",
        f"Non-fragile closures retained for sensitivity subset & {n_keep} & observed \\\\",
        "\\bottomrule",
        "\\end{tabular}",
        "\\end{table}",
    ]
    TABLE_FILE.write_text("\n".join(lines) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    log = build_logger()
    header = runtime_header(ROOT, seeds=[SEED])
    log.info("==== begin 28e_validate_motives ====")
    log.info("telemetry=%s", json.dumps(header, ensure_ascii=True))

    if OUT_SAMPLE.exists() and OUT_HUMAN.exists() and not args.force:
        log.info("outputs already exist; use --force to rebuild")
        write_json(JSON_FILE, {"status": "skipped_existing", "telemetry": header})
        write_json(JSON_FILE_V2, {"status": "skipped_existing", "telemetry": header})
        return

    timer = StepTimer(log)
    exo = pl.read_parquet(IN_EXO).filter(pl.col("exogenous")).select("CNES")
    clas = pl.read_parquet(IN_CLASS).join(exo, on="CNES", how="inner")
    n_universe = clas.height
    n_sample = max(6, math.ceil(0.10 * n_universe))
    log.info("F5 documentary universe: %d closures; audit sample: %d", n_universe, n_sample)

    clas = clas.with_columns(
        [
            pl.when(pl.col("data_situacao").is_not_null())
            .then(pl.col("data_situacao").str.slice(0, 4).cast(pl.Int32, strict=False))
            .otherwise(None)
            .alias("situ_year")
        ]
    ).with_columns(
        [
            (pl.col("year_closure") - pl.col("situ_year")).abs().alias("abs_receita_lag_years"),
            (
                pl.col("motivo_v2").is_in(["fiscal", "falencia"])
                & (pl.col("situ_year").is_null() | (pl.col("year_closure") - pl.col("situ_year")).abs() > 2)
            ).alias("fragile_receita_status"),
            (
                pl.col("web_source_used")
                & pl.col("snippet_available")
                & (pl.col("situacao_cadastral").is_null() | (pl.col("year_closure") - pl.col("situ_year")).abs() > 2)
            ).alias("fragile_only_web_snippet"),
        ]
    ).with_columns(
        [
            (pl.col("fragile_receita_status") | pl.col("fragile_only_web_snippet")).alias("fragile_sensitivity_flag"),
            (~(pl.col("fragile_receita_status") | pl.col("fragile_only_web_snippet"))).alias("sensitivity_keep_human_validated"),
        ]
    )
    step_flags = timer.mark("flag_fragile_subclasses")

    sample = clas.sample(n=n_sample, seed=SEED, shuffle=True).with_row_index("validation_id")
    sample = sample.select(
        [
            "validation_id",
            "CNES",
            "year_closure",
            "codmun_hosp_name",
            "uf",
            "tp_unid",
            "qt_sus_pre",
            "n_int_t_minus_1",
            "ratio_pre",
            "situacao_cadastral",
            "data_situacao",
            "motivo_situacao",
            "razao_social",
            "nome_fantasia",
            "cnae_descr",
            "snippet_available",
            "web_source_used",
        ]
    )
    OUT_SAMPLE.parent.mkdir(parents=True, exist_ok=True)
    sample.write_csv(OUT_SAMPLE)
    step_sample = timer.mark("write_blinded_sample")

    if OUT_HUMAN.exists():
        human = pl.read_parquet(OUT_HUMAN)
        if "validation_id" not in human.columns:
            human = human.with_row_index("validation_id")
    else:
        human = clas.with_row_index("validation_id").with_columns(
            [
                pl.lit(None, dtype=pl.String).alias("coder_a_label"),
                pl.lit(None, dtype=pl.Int64).alias("coder_a_confidence"),
                pl.lit(None, dtype=pl.String).alias("coder_a_notes"),
                pl.lit(None, dtype=pl.String).alias("coder_b_label"),
                pl.lit(None, dtype=pl.Int64).alias("coder_b_confidence"),
                pl.lit(None, dtype=pl.String).alias("coder_b_notes"),
                pl.lit(None, dtype=pl.String).alias("adjudicated_label"),
                pl.lit("pending_human_labels").alias("validation_status"),
            ]
        )
        human.write_parquet(OUT_HUMAN, compression="snappy")

    write_json(
        OUT_HUMAN.with_suffix(".metadata.json"),
        {
            "telemetry": header,
            "rows": human.height,
            "columns": human.columns,
            "sample_seed": SEED,
            "note": "Human-label file present, but coder fields remain incomplete in this workspace.",
            "peak_rss_gb": timer.peak_rss_gb,
        },
    )
    step_scaffold = timer.mark("refresh_human_validation_file")

    n_flagged = int(human["fragile_sensitivity_flag"].sum())
    n_keep = int(human["sensitivity_keep_human_validated"].sum())
    coder_a_done = int(
        human.select(pl.col("coder_a_label").is_not_null().sum()).item()
        if "coder_a_label" in human.columns
        else 0
    )
    coder_b_done = int(
        human.select(pl.col("coder_b_label").is_not_null().sum()).item()
        if "coder_b_label" in human.columns
        else 0
    )
    adjudicated_done = int(
        human.select(pl.col("adjudicated_label").is_not_null().sum()).item()
        if "adjudicated_label" in human.columns
        else 0
    )
    kappa_label = "---" if min(coder_a_done, coder_b_done) == 0 else "available"
    build_table(
        n_universe=n_universe,
        n_sample=n_sample,
        n_flagged=n_flagged,
        n_keep=n_keep,
        coder_a_done=coder_a_done,
        coder_b_done=coder_b_done,
        adjudicated_done=adjudicated_done,
        kappa_label=kappa_label,
    )

    BLOCKED_FILE.write_text(
        "# Step 28e status: audit coders still pending, sensitivity subset observed\n\n"
        "The two-coder external audit is still incomplete in `closures_human_validated.parquet`.\n"
        "However, the fragility screen used for the Phase B sensitivity rerun is observed:\n"
        f"`{n_flagged}` closures are flagged as fragile and `{n_keep}` are retained.\n",
    )

    payload = {
        "status": "ok_partial_audit_real_sensitivity_subset",
        "telemetry": header,
        "steps": [step_flags, step_sample, step_scaffold],
        "universe_n": n_universe,
        "sample_n": n_sample,
        "fragile_counts": {
            "fragile_receita_status": int(human["fragile_receita_status"].sum()),
            "fragile_only_web_snippet": int(human["fragile_only_web_snippet"].sum()),
            "flagged_union": n_flagged,
            "kept_for_sensitivity": n_keep,
        },
        "outputs": {
            "closure_validation_sample_csv": str(OUT_SAMPLE),
            "closures_human_validated_parquet": str(OUT_HUMAN),
            "table_tex": str(TABLE_FILE),
        },
        "audit_progress": {
            "coder_a_completed": coder_a_done,
            "coder_b_completed": coder_b_done,
            "adjudicated_completed": adjudicated_done,
            "kappa_status": kappa_label,
        },
    }
    write_json(JSON_FILE, payload)
    write_json(JSON_FILE_V2, payload)
    log.info("done")


if __name__ == "__main__":
    main()
