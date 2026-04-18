#!/usr/bin/env python3
"""
50_horse_race_screen.py — Horse race #1: Labor-network screen

Minimum-viable diagnostic: can pre-conduct worker co-location similarity
distinguish convicted cartel pairs from random non-cartel BEC pairs?

Metric. For each firm with RAIS data in 2009 (before any cartel conduct
end), build a normalized (CBO × municipality) employment vector. For each
pair of firms, compute cosine similarity.

Groups compared:
  (a) Within-cartel pairs: both firms in the same CADE-convicted setor
  (b) Between-cartel pairs: both firms cartel-convicted but different setor
  (c) Random non-cartel pairs: two BEC firms that bid on cartel items but
      neither is itself a cartel firm

Output: mean cosine similarity per group, bootstrap 95% CI, and the ROC
AUC of a binary classifier (label = same cartel, score = cosine sim)
evaluated on cartel firms + matched controls.

Decision rule: AUC >= 0.65 → idea worth pursuing as RAND paper #1.
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT = INTER / "horse_race_screen.txt"

PRE_YEAR   = 2009
N_CONTROLS = 500   # random control firms to sample
SEED       = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # 1. Cartels and cartel firms
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1
          AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year IS NOT NULL
          AND cartel_end_year <= 2016
    """)
    cf = con.sql("SELECT * FROM cf ORDER BY setor, cnpj_raiz").fetchdf()
    log(f"cartel firms: {len(cf)}  sectors: {cf['setor'].nunique()}", t0)

    # 2. Sample non-cartel control firms (firms that bid on cartel items)
    con.sql(f"""
        CREATE TABLE cartel_items AS
        SELECT DISTINCT "códigoitem" AS item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cartel_firm = 1
    """)
    con.sql(f"""
        CREATE TABLE candidate_controls AS
        SELECT DISTINCT cnpj_raiz
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND "códigoitem" IN (SELECT item FROM cartel_items)
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """)
    n_cand = con.sql("SELECT COUNT(*) FROM candidate_controls").fetchone()[0]
    log(f"candidate control firms (bid on cartel items): {n_cand:,}", t0)

    rng = np.random.default_rng(SEED)
    controls_all = con.sql("SELECT cnpj_raiz FROM candidate_controls").fetchdf()
    n_draw = min(N_CONTROLS, len(controls_all))
    control_idx = rng.choice(len(controls_all), size=n_draw, replace=False)
    controls = controls_all.iloc[control_idx].copy()
    controls["setor"] = "_control_"
    log(f"sampled control firms: {len(controls)}", t0)

    # 3. Pull pre-year employment vectors for cartel + control firms
    firms_all = pd.concat([cf[["cnpj_raiz", "setor"]], controls], ignore_index=True)
    firm_list = firms_all["cnpj_raiz"].tolist()
    firm_set_sql = ",".join(f"'{f}'" for f in firm_list)

    log("pulling pre-year employment vectors...", t0)
    con.sql(f"""
        CREATE TABLE emp AS
        SELECT cnpj_raiz           AS firm,
               cbo2002::VARCHAR    AS cbo,
               mun_estab::VARCHAR  AS mun,
               COUNT(*)            AS n
        FROM read_parquet('{RAIS_DIR / f"rais_vinculos_{PRE_YEAR}.parquet"}')
        WHERE cnpj_raiz IN ({firm_set_sql})
          AND cbo2002 IS NOT NULL
          AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    emp = con.sql("SELECT * FROM emp").fetchdf()
    con.close()
    log(f"emp rows: {len(emp):,}  firms with any data: {emp['firm'].nunique()}", t0)

    # 4. Build firm × cell matrix, normalize, compute cosine similarity
    emp["cell"] = emp["cbo"].astype(str) + "|" + emp["mun"].astype(str)
    mat = emp.pivot_table(index="firm", columns="cell", values="n",
                          fill_value=0, aggfunc="sum").astype(float)
    firms_with_data = mat.index.values
    mat_vals = mat.values
    norms = np.linalg.norm(mat_vals, axis=1, keepdims=True)
    mat_n = mat_vals / np.where(norms > 0, norms, 1)
    sim = mat_n @ mat_n.T  # firm × firm cosine similarity
    log(f"similarity matrix: {sim.shape}", t0)

    # Keep a mapping from firm → setor for classification
    firm_to_setor = dict(zip(firms_all["cnpj_raiz"], firms_all["setor"]))
    firm_setor = np.array([firm_to_setor.get(f, "_missing_") for f in firms_with_data])

    # 5. Build pair-level score list and labels
    # Label classes:
    #   "same_cartel": both in cartel, same setor
    #   "diff_cartel": both in cartel, different setor
    #   "cartel_vs_ctrl": one cartel, one control
    #   "ctrl_vs_ctrl": both control
    n = len(firms_with_data)
    triu_i, triu_j = np.triu_indices(n, k=1)
    scores = sim[triu_i, triu_j]
    s_i = firm_setor[triu_i]
    s_j = firm_setor[triu_j]

    is_cartel_i = (s_i != "_control_") & (s_i != "_missing_")
    is_cartel_j = (s_j != "_control_") & (s_j != "_missing_")
    same_cartel   = is_cartel_i & is_cartel_j & (s_i == s_j)
    diff_cartel   = is_cartel_i & is_cartel_j & (s_i != s_j)
    cartel_vs_ctrl = (is_cartel_i ^ is_cartel_j)
    ctrl_vs_ctrl  = (~is_cartel_i) & (~is_cartel_j)

    def summarize(mask, label):
        x = scores[mask]
        if len(x) == 0:
            return None
        return {
            "label": label,
            "n": len(x),
            "mean": float(x.mean()),
            "median": float(np.median(x)),
            "p25": float(np.percentile(x, 25)),
            "p75": float(np.percentile(x, 75)),
            "frac_pos": float((x > 0).mean()),
        }

    groups = [summarize(m, lab) for m, lab in [
        (same_cartel,    "same_cartel"),
        (diff_cartel,    "diff_cartel"),
        (cartel_vs_ctrl, "cartel_vs_ctrl"),
        (ctrl_vs_ctrl,   "ctrl_vs_ctrl"),
    ]]

    # 6. AUC of classifier: label = same_cartel (positive), scores = cosine
    # Compare same-cartel pairs vs a pooled negative class (ctrl_vs_ctrl +
    # diff_cartel), which represents "not the same conspiracy."
    pos_scores = scores[same_cartel]
    neg_scores = scores[diff_cartel | ctrl_vs_ctrl]
    if len(pos_scores) > 0 and len(neg_scores) > 0:
        # Mann-Whitney U → AUC
        from scipy.stats import mannwhitneyu
        stat, p = mannwhitneyu(pos_scores, neg_scores, alternative="greater")
        auc = stat / (len(pos_scores) * len(neg_scores))
    else:
        auc, p = float("nan"), float("nan")

    # Also compute AUC using only control-vs-control as negatives
    neg_scores_strict = scores[ctrl_vs_ctrl]
    if len(pos_scores) > 0 and len(neg_scores_strict) > 0:
        from scipy.stats import mannwhitneyu
        stat2, p2 = mannwhitneyu(pos_scores, neg_scores_strict, alternative="greater")
        auc_strict = stat2 / (len(pos_scores) * len(neg_scores_strict))
    else:
        auc_strict, p2 = float("nan"), float("nan")

    # Bootstrap CI on AUC_strict
    rng = np.random.default_rng(SEED)
    if len(pos_scores) >= 5 and len(neg_scores_strict) >= 100:
        B = 500
        boot_auc = np.zeros(B)
        for b in range(B):
            pb = rng.choice(pos_scores, size=len(pos_scores), replace=True)
            nb = rng.choice(neg_scores_strict,
                            size=len(neg_scores_strict), replace=True)
            ps = rng.permutation(np.concatenate([pb, nb]))
            # Simpler: recompute via Mann-Whitney on bootstrap
            from scipy.stats import mannwhitneyu
            s, _ = mannwhitneyu(pb, nb, alternative="greater")
            boot_auc[b] = s / (len(pb) * len(nb))
        auc_lo, auc_hi = np.percentile(boot_auc, [2.5, 97.5])
    else:
        auc_lo = auc_hi = float("nan")

    # 7. Write report
    with open(OUT, "w") as f:
        f.write("Horse race #1: Labor-network cartel screen\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Score: cosine similarity of firms' 2009 CBO × municipality\n")
        f.write("         employment vectors (pre-conduct for all cartels).\n")
        f.write("  Positive class: same_cartel (two firms in same CADE setor)\n")
        f.write("  Negative class: ctrl_vs_ctrl (two random non-cartel BEC firms)\n\n")

        f.write("PAIR-GROUP SIMILARITY STATISTICS\n")
        f.write("-" * 50 + "\n")
        f.write(f"{'group':<18s} {'n':>8s} {'mean':>8s} {'median':>8s} "
                f"{'p25':>7s} {'p75':>7s}\n")
        for g in groups:
            if g is None:
                continue
            f.write(f"{g['label']:<18s} {g['n']:>8,d} {g['mean']:>8.4f} "
                    f"{g['median']:>8.4f} {g['p25']:>7.4f} {g['p75']:>7.4f}\n")

        f.write("\nAUC OF CLASSIFIER (cosine similarity → same-cartel label)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Positive class n: {len(pos_scores):,}\n")
        f.write(f"  Negative class (ctrl_vs_ctrl) n: {len(neg_scores_strict):,}\n")
        f.write(f"  Negative class (pooled) n: {len(neg_scores):,}\n")
        f.write(f"  AUC (vs ctrl_vs_ctrl, strict) = {auc_strict:.4f}  "
                f"p = {p2:.4f}\n")
        if not np.isnan(auc_lo):
            f.write(f"  95% bootstrap CI: [{auc_lo:.4f}, {auc_hi:.4f}]\n")
        f.write(f"  AUC (vs pooled negatives)     = {auc:.4f}  p = {p:.4f}\n\n")

        f.write("DECISION\n")
        f.write("-" * 50 + "\n")
        if auc_strict >= 0.70:
            verdict = "✓ STRONG: AUC ≥ 0.70"
        elif auc_strict >= 0.65:
            verdict = "△ PROMISING: 0.65 ≤ AUC < 0.70"
        elif auc_strict >= 0.55:
            verdict = "○ WEAK: 0.55 ≤ AUC < 0.65"
        else:
            verdict = "✗ DEAD: AUC < 0.55"
        f.write(f"  AUC_strict = {auc_strict:.4f}  →  {verdict}\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())


if __name__ == "__main__":
    main()
