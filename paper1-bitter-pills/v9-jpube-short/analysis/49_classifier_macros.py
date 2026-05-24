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
    jud = re.search(r"Judicial:\s*\n\s*Precision:\s*([\d.]+)\s*\n\s*Recall:\s*([\d.]+)\s*\n\s*F1:\s*([\d.]+)\s*\n\s*TP=(\d+) FP=(\d+) FN=(\d+) TN=(\d+)", text)
    adm = re.search(r"Administrative:\s*\n\s*Precision:\s*([\d.]+)\s*\n\s*Recall:\s*([\d.]+)\s*\n\s*F1:\s*([\d.]+)\s*\n\s*TP=(\d+) FP=(\d+) FN=(\d+) TN=(\d+)", text)
    if not (jud and adm):
        raise SystemExit("[49] could not parse ensemble F1 blocks")
    prec_jud, rec_jud, f1_jud = float(jud.group(1)), float(jud.group(2)), float(jud.group(3))
    jud_tp, jud_fp, jud_fn, jud_tn = (int(jud.group(i)) for i in range(4, 8))
    prec_adm, rec_adm, f1_adm = float(adm.group(1)), float(adm.group(2)), float(adm.group(3))
    adm_tp, adm_fp, adm_fn, adm_tn = (int(adm.group(i)) for i in range(4, 8))
    admin_tp, admin_fn = adm_tp, adm_fn
    admin_gt = admin_tp + admin_fn
    # ML hold-out
    jud_ho = re.search(r"Judicial:\s*P=([\d.]+)\s*R=([\d.]+)\s*F1=([\d.]+)", text)
    adm_ho = re.search(r"Admin:\s*P=([\d.]+)\s*R=([\d.]+)\s*F1=([\d.]+)", text)
    if not (jud_ho and adm_ho):
        raise SystemExit("[49] could not parse ML hold-out metric blocks")
    prec_jud_ho, rec_jud_ho, f1_jud_ho = (float(jud_ho.group(i)) for i in range(1, 4))
    prec_adm_ho, rec_adm_ho, f1_adm_ho = (float(adm_ho.group(i)) for i in range(1, 4))
    n_train = grab(r"Train size:\s*(\d+)", text, cast=int)
    n_test = grab(r"Test size:\s*(\d+)", text, cast=int)
    dual_ens = grab(r"both judicial=1 and admin=1:\s*(\d+)", text, cast=int)
    dual_gt = grab(r"GT has ~([\d,]+) overlapping", text, cast=lambda s: int(s.replace(",", "")))
    return dict(
        n_classified=n_classified, n_gt=n_gt, exact_n=exact_n, exact_pct=exact_pct,
        prec_jud=prec_jud, rec_jud=rec_jud, f1_jud=f1_jud,
        prec_adm=prec_adm, rec_adm=rec_adm, f1_adm=f1_adm,
        jud_tp=jud_tp, jud_fp=jud_fp, jud_fn=jud_fn, jud_tn=jud_tn,
        adm_tp=adm_tp, adm_fp=adm_fp, adm_fn=adm_fn, adm_tn=adm_tn,
        prec_jud_ho=prec_jud_ho, rec_jud_ho=rec_jud_ho, f1_jud_ho=f1_jud_ho,
        prec_adm_ho=prec_adm_ho, rec_adm_ho=rec_adm_ho, f1_adm_ho=f1_adm_ho,
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
    jud_fpr = 100.0 * r["jud_fp"] / (r["jud_fp"] + r["jud_tn"])
    jud_fnr = 100.0 * r["jud_fn"] / (r["jud_tp"] + r["jud_fn"])
    adm_fpr = 100.0 * r["adm_fp"] / (r["adm_fp"] + r["adm_tn"])
    adm_fnr = 100.0 * r["adm_fn"] / (r["adm_tp"] + r["adm_fn"])
    jud_contam = 100.0 * r["jud_fp"] / (r["jud_tp"] + r["jud_fp"])
    adm_contam = 100.0 * r["adm_fp"] / (r["adm_tp"] + r["adm_fp"])
    jud_atten = 1.0 - jud_fpr / 100.0 - jud_fnr / 100.0
    adm_atten = 1.0 - adm_fpr / 100.0 - adm_fnr / 100.0
    macros = {
        "regexNClassified": latex_int(r["n_classified"]),
        "regexNGroundTruth": latex_int(r["n_gt"]),
        "regexNTrain": latex_int(r["n_train"]),
        "regexNHO": latex_int(r["n_test"]),
        "regexNLabeledTotal": latex_int(n_labeled),
        "regexExactMatchPct": f"{r['exact_pct']:.1f}\\%",
        "regexExactMatchN": latex_int(r["exact_n"]),
        "regexPrecJud": f"{r['prec_jud']:.2f}",
        "regexRecallJud": f"{r['rec_jud']:.2f}",
        "regexFoneJud": f"{r['f1_jud']:.2f}",
        "regexJudTP": latex_int(r["jud_tp"]),
        "regexJudFP": latex_int(r["jud_fp"]),
        "regexJudFN": latex_int(r["jud_fn"]),
        "regexJudTN": latex_int(r["jud_tn"]),
        "regexFprJudPct": f"{jud_fpr:.2f}\\%",
        "regexFnrJudPct": f"{jud_fnr:.2f}\\%",
        "regexContamJudPct": f"{jud_contam:.1f}\\%",
        "regexAttenJud": f"{jud_atten:.3f}",
        "regexPrecAdm": f"{r['prec_adm']:.2f}",
        "regexRecallAdm": f"{r['rec_adm']:.2f}",
        "regexFoneAdm": f"{r['f1_adm']:.2f}",
        "regexAdmTP": latex_int(r["adm_tp"]),
        "regexAdmFP": latex_int(r["adm_fp"]),
        "regexAdmFN": latex_int(r["adm_fn"]),
        "regexAdmTN": latex_int(r["adm_tn"]),
        "regexFprAdmPct": f"{adm_fpr:.2f}\\%",
        "regexFnrAdmPct": f"{adm_fnr:.2f}\\%",
        "regexContamAdmPct": f"{adm_contam:.1f}\\%",
        "regexAttenAdm": f"{adm_atten:.3f}",
        "regexFoneJudHO": f"{r['f1_jud_ho']:.2f}",
        "regexPrecJudHO": f"{r['prec_jud_ho']:.2f}",
        "regexRecallJudHO": f"{r['rec_jud_ho']:.2f}",
        "regexFoneAdmHO": f"{r['f1_adm_ho']:.2f}",
        "regexPrecAdmHO": f"{r['prec_adm_ho']:.2f}",
        "regexRecallAdmHO": f"{r['rec_adm_ho']:.2f}",
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
