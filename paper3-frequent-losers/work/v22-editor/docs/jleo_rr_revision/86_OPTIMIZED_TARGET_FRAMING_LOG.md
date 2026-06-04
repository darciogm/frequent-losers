# 86 — OPTIMIZED TARGET FRAMING LOG (JLEO final optimization)

**Date:** 2026-06-04
**Mode:** Mr. Frequent Losers — FINAL OPTIMIZATION MODE
**Branch:** `v22` (working branch dedicated to this revision; v22-editor tree clean at start;
dirty files in `git status` belong to other papers in the monorepo and are not touched.
Decision: stay on `v22` rather than create `rr_jleo_optimized_target_framing` — `v22` IS the
safe dedicated branch per project convention; all prior subprompts committed here.)

**Objective:** make the main validation target reproducible, non-circular, cleanly framed.
Kill the fatal appendix statement that the 193 main target is a static narrow-definition
frequent-loser-only file whose builder is archived and not reproduced.

---

## Session log (append-only)

### Step 1 — Safety
- `pwd` = work/v22-editor; branch `v22`; HEAD `132e274`.
- v22-editor subtree clean. Proceeding.

### Step 2 — Reads & inventory (fan-out)
- Read: `docs/jleo_rr_revision/label_reconciliation_memo.md` — KEY FINDING:
  - 193 = static `cade_fl_cobidders.csv`, narrow cartel-tender def, **FL stratum**, builder ABSENT (blocker B3).
  - Scripted reproducible counts already exist (script `01_label_funnel_reconciliation.R`):
    **651** broad AL cobidders (full 12-case), **341** broad FL cobidders, **208** conservative AL,
    **107** conservative FL, **19** conservative BEC-active direct defendants, **41** BEC-active direct
    defendants (full), 52,013 shared tender-items, 149 = static193 ∩ broad341.
  - 30-defendant figure was an unreproducible over-count → 19 (already dropped).
  - Assertions A1–A10: 9 pass / 1 warning (A8 = two-axis definition difference) / 0 fail.
- Launched 3 background inventory agents:
  1. Manuscript term/number inventory (submission_clean LaTeX sources).
  2. Script label-consumption map (scripts/analysis 01–11, Makefile, figures script).
  3. Prior-audit summary (docs 44/52/71/68/22/05, subprompt logs 11–29, unit definitions).
- Results recorded in `87_TARGET_AND_FRAMING_INVENTORY.md`.

### Files read directly (lead)
- label_reconciliation_memo.md
- scripts/analysis/01_label_funnel_reconciliation.R (target-construction core)
- parquet schemas (firm_tender_map / firm_loss_stats / FREQ_PARTICIP / imhof_firm_features)
- static cade_fl_cobidders.csv header (FL-only confirmed)

### Steps 3–5 — Canonical targets + decision (2026-06-04)
- Wrote + ran `scripts/analysis/00_build_canonical_validation_targets.R` (1.6 s, assertions
  T1–T10 ALL PASS, deterministic two-path check).
- Counts: MAIN broad AL cobidders **651** (341 FL + 310 non-FL); conservative 208 / 19
  crossmatch (16 BEC-active) defendants; timing rankable 498 + 153 entrants; universe 16,843;
  defendants 41 BEC-active / 48 crossmatch; def tender-items 52,013.
- Outputs: `outputs/targets/{canonical_firm_labels,canonical_case_labels,canonical_target_counts}.csv`,
  `outputs/cache/canonical_cobidders_broad.csv` (raw keys, downstream),
  `outputs/diagnostics/{target_construction_assertions,target_set_comparisons}.csv`,
  `outputs/diagnostics/canonical_target_macros.tex`.
- **DECISION (memo 89): CASE 2** — narrow archived target not reproducible AND FL-conditioned
  (circular); broad AL 651 adopted as MAIN. U2 "disclose+robustness" superseded.

### Step 7 — downstream label swap (fan-out, 3 agents) + regeneration
- 9 scripts edited to read `canonical_cobidders_broad.csv` (`broad_cobidder == 1`):
  02, 03, 04, 05, 06, 07, 08, 09, 10, 11 (+ lead rewrote 01's Table A/B/figure/notes:
  main = broad AL; archived row excluded from submitted .tex, kept as internal CSV row).
- Assertions relaxed: 03 `==193` → `>0`; 05 all-cobidders-FL14 invariant (true only under the
  circular label) → positives>0 + composition diagnostic; 08/10 historical-benchmark
  comparisons relabeled informational.
- All 11 scripts parse OK. Regeneration chain: 01→02→03→04→05→06→11 (background log
  `outputs/logs/regen_nonbid_chain.log`), then 07→08→09→10 (bid chain, sequential for RAM).

### Regeneration results (all rc=0; logs outputs/logs/regen_{nonbid,bid}_chain.log)
- **HEADLINE SHIFT — the honest label deflates further than predicted:**
  - Raw log_tc vs 651: ROC 0.761 [0.741,0.780], PR 0.143 (old circular-label 0.946/0.939 dead).
  - Exposure-only: 0.905 unconditional (beats raw outright); 0.713/PR 0.300 in exposed logit.
  - Within-opportunity-stratum: **0.4705 (chance)**; FL14 0.5065; CEM 0.626; matched dP −0.017.
  - Nested increment +0.0100 (DeLong p=0.0129) — marginal; matched permutation **p=0.127 ns**;
    FL-enrichment **p=0.067 ns**. Script 02 verdict: "C (signal disappears under exposure adjustment)".
  - Strict timing: full universe ROC 0.474, prec@500=rec@500=0 (unchanged conclusion); training-pool 0.684/0.646.
  - Case composition: largest case 32.0% of positives / 45.4% TP@500 (was 55%/72%); drop-largest PR −37% (was −71%).
  - Direct defendants: FL binary 0.491 (silent); continuous 0.658–0.695 (above chance — old "below random" claim DEAD).
  - Bid benchmark (pool 16,731/651): award 0.760/0.143; bid RF 0.717/0.116; combined 0.756/0.188;
    case-grouped: bid 0.626/0.062, combined 0.689/0.103 (below award-only). Same-sample: 0.665/0.665/0.727.
  - Cost-recall: K1=2000/k=500 TP 116, firm-red. 88.1%, bid-row-red. 32.7%; K1=1000 beats K1=2000 (TP 124 = 93% of joint 133).
- Step-8 concordance built: outputs/tables/appendix/table_A_positive_count_concordance.{csv,tex}.
- Step-7 diagnostics: outputs/diagnostics/{target_sensitive_outputs_regenerated,final_target_number_consistency}.csv.
- Intensity sensitivity (lead, informational only): raw AUC rises with contact-restricted labels
  (≥2: 0.80; ≥5: 0.89) — consistent with opportunity mechanics; recommended future appendix run of
  script 02 under contact≥2. NOT cited in manuscript.

### Manuscript fan-out (Steps 6, 9–18)
- NEW_NUMBERS_MAP.md + REFRAMING_RULES.md written (binding for all agents).
- 7 agents: values.tex rebinder; frontmatter+intro (abstract 137 words, Step-17 arc done);
  sec02+03 (membership-anchors fixed, Figure 1 verified clean, done); sec05+app08; sec06+app05/06/09;
  sec07/08+app04; app00/01/02/03/07 (archived-language purge + concordance inclusion).
- Lead rewrote sec04_validation_submission.tex in full: canonical funnel (Table 2 rows:
  portfolio/main 651/conservative 208), concordance note, §4.2 "no robust residual net of
  opportunity" with permutation evidence, §4.3 new case/timing numbers, §4.4 scope rewritten
  (binary silent 0.49; continuous 0.66–0.70 above chance), boundary reading recentered on the
  audit-as-product.

### Steps 19–22 — scans, build, verdict (2026-06-04, session end)
- values_adversarial.tex regenerated under canonical label (55_adversarial_adaptation_canonical.R:
  base 0.722; combined adaptation 0.607). Prof-block macros rebound (incl. the two missed on
  first pass: NegCtrlRealAUC 0.939→0.761, MarketZeroWinBest 0.774→0.584); negative-control prose
  in sec05/app08 inverted to honest ns reading (p=0.46/0.91 — controls corroborate, not rescue).
- "Appendix Appendix" duplication (23 hits) fixed via sed on `Appendix~\ref{app:` → `\ref{app:`.
- Builds: 4/4 docs 0 errors / 0 undefined. Paper 52pp + appendix 46pp (JLEO pair).
- Scans: optimized_{target_assertions,number_consistency,claims_scan,pdf_text_scan}.csv —
  critical=0; all forbidden terms 0 hits; dead numbers 0 hits.
- Reports: 90_OPTIMIZED_BUILD_LOG.md + 91_OPTIMIZED_TARGET_FRAMING_COMPLETION_REPORT.md.
- **VERDICT D** — broad target adopted, downstream regenerated, framing matches evidence.
  Gate to submission: author sign-off on the more-deflationary empirical story (A1 in doc 91)
  + final hostile referee read.

### All steps completed
Steps 1–23 executed. See 87 (inventory), 88 (definitions), 89 (decision), 90 (build), 91 (verdict).
