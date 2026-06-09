from __future__ import annotations

import re
from datetime import datetime

import pandas as pd

from revision_utils import LOG, PROC, ROOT, TAB, begin_log, end_log, ensure_dirs, logger_for, parse_args, write_text


SCRIPT = "sample_consistency_audit"
EXPECTED = {
    "f5_economically_meaningful_closures": 60,
    "pnash_psychiatric_closures": 48,
    "general_hospital_f5_closures": 18,
    "hospital_day_f5_closures": 1,
    "nonpsychiatric_f5_closures": 19,
    "failed_f5_predecline_closures": 30,
}


def main() -> None:
    parse_args("Check sample-count consistency")
    ensure_dirs()
    logger = logger_for(SCRIPT)
    t0 = begin_log(logger, SCRIPT, seeds=[])
    warnings: list[str] = []

    master_path = PROC / "master_closure_sample_table.parquet"
    if not master_path.exists():
        raise FileNotFoundError(master_path)
    master = pd.read_parquet(master_path)
    for sid, expected in EXPECTED.items():
        row = master[master["sample_id"] == sid]
        if row.empty:
            warnings.append(f"missing sample_id in master table: {sid}")
            continue
        got = int(row.iloc[0]["number_of_closures"])
        if got != expected:
            warnings.append(f"{sid}: expected closures={expected}, got={got}")
        logger.info("sample_count %s closures=%s expected=%s", sid, got, expected)

    f5_path = PROC / "flow_distance_disagreement_f5.parquet"
    if f5_path.exists():
        f5 = pd.read_parquet(f5_path)
        union = f5["flow_exposed"] | f5["distance_exposed"]
        flow_only = int((f5["flow_exposed"] & ~f5["distance_exposed"]).sum())
        distance_only = int((~f5["flow_exposed"] & f5["distance_exposed"]).sum())
        both = int((f5["flow_exposed"] & f5["distance_exposed"]).sum())
        logger.info("f5_disagreement flow_only=%d distance_only=%d both=%d union=%d misclassified=%d",
                    flow_only, distance_only, both, int(union.sum()), flow_only + distance_only)
        if int(union.sum()) != 337 or flow_only + distance_only != 293:
            warnings.append(
                f"F5 disagreement differs from manuscript macros: union={int(union.sum())}, misclassified={flow_only + distance_only}"
            )
    else:
        warnings.append(f"missing {f5_path}")

    first_stage = PROC / "first_stage_by_sample_estimates.csv"
    if first_stage.exists():
        fs = pd.read_csv(first_stage)
        for sid in ["f5_economically_meaningful_closures", "pnash_psychiatric_closures", "nonpsychiatric_f5_closures", "failed_f5_predecline_closures"]:
            if sid not in set(fs["sample_id"]):
                warnings.append(f"first-stage table missing {sid}")
    else:
        warnings.append(f"missing {first_stage}")

    # Lightweight manuscript scan for the most dangerous stale labels.
    stale_patterns = [
        r"Reference \(main\): F5 panel",
        r"F5 main sample",
        r"F5 main",
        r"60 closures.*mortality",
        r"all 60 closures.*suicide",
    ]
    active_tex = []
    for path in (ROOT / "01_manuscript").glob("*.tex"):
        if "_archive" in path.parts:
            continue
        active_tex.append(path)
    for path in active_tex + list(TAB.glob("*.tex")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pat in stale_patterns:
            for match in re.finditer(pat, text, flags=re.IGNORECASE):
                warnings.append(f"stale label pattern `{pat}` in {path.relative_to(ROOT)}:{text[:match.start()].count(chr(10)) + 1}")

    report = [
        f"Sample consistency audit: {datetime.now().isoformat(timespec='seconds')}",
        "",
        "Warnings:",
    ]
    report.extend([f"- {w}" for w in warnings] or ["- none"])
    out = LOG / f"sample_consistency_audit_{datetime.now().strftime('%Y%m%d')}.log"
    write_text(out, "\n".join(report) + "\n")
    for w in warnings:
        logger.warning(w)
    logger.info("wrote %s", out)
    end_log(logger, t0)


if __name__ == "__main__":
    main()
