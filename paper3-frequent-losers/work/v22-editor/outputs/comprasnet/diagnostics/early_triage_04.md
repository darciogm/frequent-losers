# Early triage — Script 04 (case-holdout / dominance, federal/ComprasNet)

**Attack:** R4 **A3 — Case concentration ("the result is one cartel")** — highest-kill-probability attack.
**Triage by:** Mr. Frequent Losers (reviewer mode) · **Date:** 2026-06-05 · **Run:** 04 completed 19:41, 9 min, seed 20260603.
**Discipline:** light reads only; chain re-running concurrently; no heavy compute touched.

---

## 1. Log read — blocks run/skipped/warnings

Log file: `outputs/comprasnet/logs/04_case_holdout_dominance_comprasnet.log` (and diagnostics `case_holdout_dominance_audit_log.txt`).

- **Stage A (candidate set):** 195 broad-AL cobidder positives, 195 distinct firms; candidate universe 35,939 always-losers (minus direct defendants). **TI/DF exclusion PRESENT and logged:** "FEDERAL defendants: 7 numbered cases; **dropped 2 estab(s) of the unnumbered TI/DF case (gate G3)**" (line 7). 0 unlinked positives (all 195 map to ≥1 of the 7 numbered cases). ✅ A8 disclosure-in-output satisfied.
- **Per-case positives (LINK ROWS, not distinct firms):** A trens_metros 69 · D medicamentos 63 · C sacos_lixo 27 · F medic_genericos 22 · medic_antirretrovirais 12 · merenda 8 · transporte_escolar 4. Sum = **205 link-rows** (= 195 distinct firms + 10 multi-case firms). Matches the post-sentinel-fix expectation (F=22, A=69, D=63). ✅
- **Stage B0 (contact O_i + env, DuckDB):** 4,191 firms with O_i>0; 15,036 positive participation rows; **98.0% modality matched**. Three `[1] 0` print artifacts (DuckDB scalar echoes) — benign, not warnings.
- **Stage A LOCO:** 7 cases evaluated; **1 of 7 too_sparse (<5 pos)** = transporte_escolar (4 pos). ✅ expected.
- **Stage C environment:** **convite branch SKIPPED** — logged explicitly: "source=comprasnet has no convite; gate G5 pure pregao" (A14 modality-loss handled in-output). modality dimension = 2 groups (pregao 5 + SRP 9999), SRP largest_share 0.641. ✅
- **Stage D LODGO:** 13 of 22 defendants feasible (≥5 distinct positives).
- **Stage E clustered RI:** ran with **stratification = buyer × item_group × year** (170 positive-bearing cells, **91.8% of positives shufflable**). NOTE: BEC RI used the coarser **item_group × year**; federal added the buyer margin. Output table written (`table_D_clustered_randomization_inference.csv`), so the stage completed despite the log tail truncating right after the stratification-choice line (the human-readable log was captured mid-flush; the CSV + audit_log confirm completion).
- **No R warnings/errors anywhere in the log.** Clean run.

---

## 2. LOCO / dominance table — FEDERAL vs BEC

Sources: federal `table_G_…csv`, `table_H_…csv`, `table_D_clustered_randomization_inference.csv`, `case_dominance_summary.csv`; BEC twins `outputs/tables/main/table_H…`, `…/main/table_G…`, `…/appendix/table_D_clustered…`.

| Metric | **BEC** | **Federal** | Read |
|---|---|---|---|
| N positives | 651 | 195 | federal = 30% of BEC |
| Top-case share of **positives** | 32.0% (208/651) | **35.4%** (69/195) | comparable, slightly worse |
| Top-**two** share of positives | ~— | **64.4%** of link-rows (132/205) / **67.7%** of distinct firms (132/195) | materially worse than BEC |
| Top-case share of **O_i contacts** | — | **47.8%** (matches prompt's 47.7%) | concentration moderate on contacts |
| Top-case share of **TP@500** | 45.4% | **87.5%** (7 of 8 TP) | **far worse** — k-metrics one-cartel-dominated |
| **ROC-AUC full** | 0.761 | 0.744 | comparable |
| **ROC-AUC drop-largest** | 0.763 (+0%) | **0.744 (−0.1%)** | **ROC fully robust to LOCO** |
| ROC-AUC drop-top-two | 0.752 | 0.710 (−4.6%) | robust |
| **PR-AUC full** | 0.143 | **0.0142** | federal PR tiny (prevalence ~0.5%) |
| **PR-AUC drop-largest** | 0.090 (**−37.5%**) | **0.0079 (−44.4%)** | over the ≤40% band, just |
| PR-AUC drop-top-two | 0.058 (−59%) | **0.0038 (−73.3%)** | both collapse on top-2 |
| Clustered RI p (ROC ordering) | 0.001 | **0.001** | ordering non-random ✅ |
| RI p (case-coverage breadth) | 0.103 (NS) | **0.487 (NS)** | **federal breadth far more NS** |
| RI stratification | item_group×year | buyer×item_group×year (91.8% shufflable) | finer federally |

**LODGO (leave-one-defendant-group-out, 13 feasible groups):** mean ROC-AUC 0.772 (non-sparse), no single defendant's removal guts the ordering — the per-defendant ROC stays in 0.60–0.93. This is the ROC-side good news: the **ranking** is not one-defendant-driven.

**Environment robustness (stage C):** drop-largest-buyer ROC 0.744→0.739; drop-largest-item_group 0.744→0.718; drop-top-years 0.744→0.734. ROC ordering robust to every environment leave-out. item_group HHI 0.204 (largest group 15 = 38%) is the one concentrated environment margin.

---

## 3. A3 VERDICT — **DEGRADED / SPLIT**, retreat to stress-test framing required for PR/k-metrics; ROC-ordering claim survives

Per protocol thresholds (R4 §A3.c):

- **Kill threshold = "DIES as one cartel if PR-AUC drop-largest > 60% OR drop-top-two leaves PR at chance."**
  - PR drop-largest = **−44.4%** → **does NOT cross the −60% kill line**, but is **above** the BEC −37% and above the SURVIVES tolerance (≤~40%). → **MARGINAL**, not dead.
  - PR drop-top-two = **−73.3%** and TP@500 is **87.5% one case** → on the **precision/recall-at-k and PR-AUC axis the federal result IS one-to-two cartels.** Cannot claim cross-case generality on these metrics.
- **SURVIVES side:** the **ROC-AUC ordering is fully LOCO-robust** (0.744 → 0.744 drop-largest; 0.710 drop-top-two) and the clustered-RI ordering p = **0.001** (BEC-identical). So the *rank-ordering* signal is genuinely multi-case; removing trens_metros does not move it.
- **Breadth test fails the SURVIVES clause:** R4 requires `\valFedAudClusterRIcovP` show "the ordering spans more than the dominant case." Federal RI case-coverage p = **0.487 (NS)** — the number of distinct cases among the top-500 (2) is **not** distinguishable from random. BEC was already NS (0.103) but federal is far weaker. **This clause is NOT met federally.**

### Honest reading — which concentration metric to foreground

The three concentration metrics tell different stories and the manuscript must not cherry-pick:
- **Top-case by positives = 35.4%** (comparable to BEC 32%) — the most flattering, **do NOT lead with this alone**; it understates the problem.
- **Top-case by O_i contacts = 47.8%** — the honest middle metric.
- **Top-case by TP@500 = 87.5%** and **top-2 positives = 64–68%** — the damning metrics; the realized detections are one-cartel-dominated.

**Foreground recommendation:** lead App G with **top-two-by-positives (64.4%)** as the headline concentration disclosure (the protocol's mandated number) AND **TP@500 = 87.5% one case** as the honest operational-concentration number. Do not foreground the 35.4%-top-case figure in isolation — it is the metric that hides the concentration.

### What the federal section MAY claim vs MUST retreat from

- ✅ **MAY claim** (carried by LOCO-robust ROC + RI p=0.001 + LODGO): *"the rank-ordering produced by the loser-side construct is not driven by any single cartel — leaving out the largest case (trens_metros) leaves the ROC-AUC essentially unchanged (0.744→0.744) and the clustered-randomization ordering test rejects randomness at p=0.001."* This is honest and survives.
- ❌ **MUST retreat** on precision/recall-at-k and PR-AUC: the realized top-500 detections are **87.5% one case** and PR collapses −73% on dropping the top two. The federal section **cannot** claim the *operational ranking* (who you'd actually audit) generalizes across cases. Per A3(d) fallback, frame the federal leg as a **"single-system, concentrated-anchor stress test of the protocol"**, not a multi-case generalization — paired with the per-case LOCO table (table_G) so the reader sees exactly which case carries the k-metrics.
- **Mandatory disclosure (R4 §A3.c, regardless of outcome):** "the federal positive base is more case-concentrated than BEC (top-two ~64%)" — must appear in App G + comparative-table notes. The output supports it; hiding it is fatal, disclosing it is survivable.

**Net:** A3 does not kill the section, but it **forces the dual framing** — ROC-ordering robustness (survives) + explicit concentrated-anchor stress-test retreat on the operational/PR metrics (does not generalize). This is exactly the protocol's predicted "degraded → disclosure + stress-test" path, not the clean-survive path.

---

## 4. Comparative-table macros — Group-8 fill status & spec mismatches

**Macros now backed by real federal values** (fill report `federal_fill_report.csv` was generated 19:01, BEFORE 04 ran at 19:41, so it still flags all of these "missing/file not found" — must be re-run to pick them up):

| Macro | Value now available | Source cell |
|---|---|---|
| `\valFedAudTopCaseShare` | **35.4%** (69/195) | table_G / case_dominance_summary |
| `\valFedAudTopCaseTP` | **87.5%** (TP@500) | table_H / case_dominance_summary `share_tp_500` |
| `\valFedAudLOCOfullPRAUC` | **0.0142** | table_H::full |
| `\valFedAudLOCOdropLargestPRAUC` | **0.0079** | table_H::drop_largest_case |
| `\valFedAudLOCOdropPct` | **−44.4%** | derived |
| `\valFedAudLOCOdropTwoPRAUC` | **0.0038** (−73.3%) | table_H::drop_top_two_cases |
| `\valFedAudClusterRIp` | **0.001** | table_D_clustered…::roc_auc emp_p |
| `\valFedAudClusterRIcovP` | **0.487 (NS)** | table_D_clustered…::topk500_case_coverage emp_p |
| `\valFedAudClusterRIverdict` / `…covVerdict` | ordering non-random / breadth NS | derived |

**SPEC MISMATCHES vs numbers map (fix the fill specs):**

1. **RI file path mismatch.** Fill report + numbers map (line 203–204) expect the clustered-RI CSV at `outputs/comprasnet/tables/**appendix/**table_D_clustered_randomization_inference.csv`. Script 04 wrote it to `outputs/comprasnet/tables/table_D_clustered_randomization_inference.csv` (**no `appendix/` subdir** — that subdir does not exist under comprasnet/tables; BEC twin IS in `outputs/tables/appendix/`). → **Either move/symlink the federal RI table into an `appendix/` subdir, or repoint the fill spec to the flat path.** This is the only path-level blocker for Group 8.

2. **`\valFedAudTopCaseTP` source naming.** Numbers map says "case-dominance diag" / table_H "(top-case TP@500)". The value lives in `case_dominance_summary.csv` column `share_tp_500` (top row = 0.875), not as a labeled cell in `table_H_case_dominance_validation.csv` (which has the full/drop scenarios, not the per-case TP share). → point the fill spec at `case_dominance_summary.csv::share_tp_500[case==largest]` or `case_topk_coverage.csv::largest_case_share_of_tp[k==500]`.

3. **Top-two concentration metric — denominator ambiguity to lock.** The per-case counts (69+63+…=205) are **link-rows**, not distinct firms. Top-two = 132/205 = **64.4%** (link-row basis, = the protocol's quoted number) vs 132/195 = **67.7%** (distinct-firm basis). `case_dominance_summary.csv::share_pos` uses /195 as denominator so its shares sum to >1 (205/195). → **Lock one basis in the macro and state it**; recommend the link-row 64.4% to match the protocol text, with a note that 10 firms are multi-case.

4. **RI stratification differs from BEC (not a bug, an annotation need).** Federal RI = buyer×item_group×year; BEC = item_group×year. The comparative-table note must state the federal RI added the buyer margin (91.8% positives shufflable). Not a fill error, but the comparative cell should not imply identical RI design.

No other naming mismatches; table_G, table_H, environment/LODGO tables all match the map's expected filenames.

---

## 5. Anomalies in the log

- **Log tail truncation (benign):** the human-readable `.log` ends at the RI stratification-choice line (line 139) with no printed emp_p; the `case_holdout_dominance_audit_log.txt` ends identically. The RI **output CSV was written** (5 metrics incl. emp_p), so the stage completed — the prints were simply captured before the final flush. Not a failure; flag only so a reader doesn't think RI crashed.
- **`[1] 0` echoes** (3×) at the top of B0 and D stages — DuckDB scalar-return artifacts, harmless.
- **`case_dominance_summary.csv` shares sum to >1** (share_pos column: 205/195) — expected given multi-case firms, but will look like an error to a referee unless the note explains the link-row denominator. (See spec mismatch #3.)
- **Fill report is stale** (19:01 < 04's 19:41) — every Group-8 row reads "missing/file not found." Re-run the fill step after 04 to populate. Not a data problem.

---

## TL;DR

- **A3 verdict: DEGRADED / SPLIT** — survives on ROC-ordering (LOCO-robust 0.744→0.744, RI ordering p=0.001, LODGO clean), but the **operational k-metrics are one-cartel-dominated** (TP@500 = 87.5% one case; PR drop-largest −44%, drop-top-two −73%; RI breadth p=0.487 NS).
- **Does NOT cross the −60% one-cartel kill line** (−44% < −60%) → section is not dead, but **cannot claim multi-case operational generality.**
- **Licensed framing:** "rank-ordering not driven by a single cartel (ROC LOCO-robust, RI p=0.001)" + mandatory retreat to **"single-system, concentrated-anchor stress test"** for the precision/recall ranking, with top-two=64.4% and TP@500=87.5% disclosed.
- **Foreground the TP@500=87.5% and top-two=64.4% metrics, not the flattering 35.4% top-case-by-positives.**
- **Spec fixes for fill:** (1) RI table path lacks `appendix/` subdir; (2) `\valFedAudTopCaseTP` source = `case_dominance_summary.csv::share_tp_500`, not table_H; (3) lock top-two denominator (link-row 64.4% vs firm 67.7%); (4) re-run stale fill report. RI stratification differs from BEC (annotate).
