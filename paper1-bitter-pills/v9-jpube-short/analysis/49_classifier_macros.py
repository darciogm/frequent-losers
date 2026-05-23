#!/usr/bin/env python3
"""Macro-bind the purchase-type classifier numbers straight from their sources.

Replaces the hand-transcribed MANUAL block in values.tex: validation metrics
come from classification_report.txt, pattern counts and voting weights come from
classify_editais_full.py (parsed, not eyeballed). Run from anywhere; paths are
resolved relative to the repo root.
"""
import ast
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]  # paper1-bitter-pills/
REPORT = REPO / "datasets" / "Classif_editais" / "classification_report.txt"
CODE = REPO / "datasets" / "Classif_editais" / "classify_editais_full.py"
VALUES = HERE.parent / "manuscript" / "paper" / "values.tex"
SCRIPT_ID = "49_classifier_macros"


def latex_int(n: int) -> str:
    return f"{n:,}".replace(",", "{,}")


def grab(pattern: str, text: str, group: int = 1, cast=str):
    m = re.search(pattern, text)
    if not m:
        raise SystemExit(f"[49] pattern not found in report: {pattern!r}")
    return cast(m.group(group))


def parse_report(text: str) -> dict:
    n_classified = grab(r"Total OCs classified:\s*([\d,]+)", text, cast=lambda s: int(s.replace(",", "")))
    n_gt = grab(r"GROUND TRUTH VALIDATION \(([\d,]+) labeled OCs\)", text, cast=lambda s: int(s.replace(",", "")))
    exact_n = grab(r"Exact match:\s*([\d,]+)/", text, cast=lambda s: int(s.replace(",", "")))
    exact_pct = grab(r"Exact match:.*\(([\d.]+)%\)", text, cast=float)
    # ensemble F1 (first Judicial/Administrative blocks)
    jud = re.search(r"Judicial:\s*\n\s*Precision:\s*([\d.]+)\s*\n\s*Recall:\s*([\d.]+)\s*\n\s*F1:\s*([\d.]+)\s*\n\s*TP=(\d+) FP=(\d+) FN=(\d+)", text)
    adm = re.search(r"Administrative:\s*\n\s*Precision:\s*([\d.]+)\s*\n\s*Recall:\s*([\d.]+)\s*\n\s*F1:\s*([\d.]+)\s*\n\s*TP=(\d+) FP=(\d+) FN=(\d+)", text)
    if not (jud and adm):
        raise SystemExit("[49] could not parse ensemble F1 blocks")
    f1_jud, f1_adm = float(jud.group(3)), float(adm.group(3))
    admin_tp, admin_fn = int(adm.group(4)), int(adm.group(6))
    admin_gt = admin_tp + admin_fn
    # ML hold-out
    f1_jud_ho = grab(r"Judicial:\s*P=[\d.]+ R=[\d.]+ F1=([\d.]+)", text, cast=float)
    f1_adm_ho = grab(r"Admin:\s*P=[\d.]+ R=[\d.]+ F1=([\d.]+)", text, cast=float)
    n_train = grab(r"Train size:\s*(\d+)", text, cast=int)
    n_test = grab(r"Test size:\s*(\d+)", text, cast=int)
    dual_ens = grab(r"both judicial=1 and admin=1:\s*(\d+)", text, cast=int)
    dual_gt = grab(r"GT has ~([\d,]+) overlapping", text, cast=lambda s: int(s.replace(",", "")))
    return dict(
        n_classified=n_classified, n_gt=n_gt, exact_n=exact_n, exact_pct=exact_pct,
        f1_jud=f1_jud, f1_adm=f1_adm, f1_jud_ho=f1_jud_ho, f1_adm_ho=f1_adm_ho,
        n_train=n_train, n_test=n_test, dual_ens=dual_ens, dual_gt=dual_gt,
        admin_gt=admin_gt,
    )


def parse_code(text: str) -> dict:
    tree = ast.parse(text)
    lists, consts = {}, {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if isinstance(node.value, ast.List):
                lists[name] = len(node.value.elts)
            elif isinstance(node.value, ast.Constant) and isinstance(node.value.value, int):
                consts[name] = node.value.value
    need_l = ["JUDICIAL_PATTERNS", "ADMIN_PATTERNS", "BOILERPLATE_PATTERNS"]
    need_c = ["W_ML", "W_JSON", "W_REGEX", "W_POSITION", "VOTE_THRESHOLD"]
    for k in need_l:
        if k not in lists:
            raise SystemExit(f"[49] list {k} not found in classifier code")
    for k in need_c:
        if k not in consts:
            raise SystemExit(f"[49] constant {k} not found in classifier code")
    return dict(
        n_jud=lists["JUDICIAL_PATTERNS"], n_adm=lists["ADMIN_PATTERNS"],
        n_boiler=lists["BOILERPLATE_PATTERNS"],
        w_ml=consts["W_ML"], w_json=consts["W_JSON"], w_regex=consts["W_REGEX"],
        w_pos=consts["W_POSITION"], vote=consts["VOTE_THRESHOLD"],
    )


def emit(values_path: Path, script_id: str, macros: dict):
    begin = f"% ===== AUTO BEGIN: {script_id} ====="
    end = f"% ===== AUTO END: {script_id} ====="
    body = []
    for name, val in macros.items():
        body.append(f"\\providecommand{{\\BP{name}}}{{}}")
        body.append(f"\\renewcommand{{\\BP{name}}}{{{val}}}")
    block = "\n".join([begin, *body, end])
    lines = values_path.read_text(encoding="utf-8").splitlines()
    try:
        i0, i1 = lines.index(begin), lines.index(end)
        out = lines[:i0] + block.splitlines() + lines[i1 + 1:]
    except ValueError:
        out = lines + ["", *block.splitlines()]
    values_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"[49] wrote {len(macros)} macros for {script_id} -> {values_path}")


def main():
    r = parse_report(REPORT.read_text(encoding="utf-8", errors="replace"))
    c = parse_code(CODE.read_text(encoding="utf-8", errors="replace"))
    n_labeled = r["n_train"] + r["n_test"]
    admin_overlap_pct = 100.0 * r["dual_gt"] / r["admin_gt"]
    macros = {
        "regexNClassified": latex_int(r["n_classified"]),
        "regexNGroundTruth": latex_int(r["n_gt"]),
        "regexNTrain": latex_int(r["n_train"]),
        "regexNHO": latex_int(r["n_test"]),
        "regexNLabeledTotal": latex_int(n_labeled),
        "regexExactMatchPct": f"{r['exact_pct']:.1f}\\%",
        "regexExactMatchN": latex_int(r["exact_n"]),
        "regexFoneJud": f"{r['f1_jud']:.2f}",
        "regexFoneAdm": f"{r['f1_adm']:.2f}",
        "regexFoneJudHO": f"{r['f1_jud_ho']:.2f}",
        "regexFoneAdmHO": f"{r['f1_adm_ho']:.2f}",
        "regexFone": f"{(r['f1_jud'] + r['f1_adm']) / 2:.2f}",
        "regexDualEnsemble": latex_int(r["dual_ens"]),
        "regexDualGT": latex_int(r["dual_gt"]),
        "regexAdminOverlapPct": f"{admin_overlap_pct:.1f}\\%",
        "clfNPatternsJud": str(c["n_jud"]),
        "clfNPatternsAdm": str(c["n_adm"]),
        "clfNPatternsBoiler": str(c["n_boiler"]),
        "clfWeightML": str(c["w_ml"]),
        "clfWeightJSON": str(c["w_json"]),
        "clfWeightRegex": str(c["w_regex"]),
        "clfWeightPosition": str(c["w_pos"]),
        "clfVoteThreshold": str(c["vote"]),
    }
    emit(VALUES, SCRIPT_ID, macros)
    for k, v in macros.items():
        print(f"  \\BP{k} = {v}")


if __name__ == "__main__":
    main()
