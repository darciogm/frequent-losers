# Early triage — Script 03 (timing / case-holdout / strict-temporal validation), ComprasNet federal

**Reviewer:** Mr. Frequent Losers (reviewer mode)
**Run:** 2026-06-05 19:04, `03_timing_case_holdout_validation.R --source=comprasnet`, exit 0, wall 48.3s, peak RSS 6.36 GB.
**Answers R4 attack A4** (window asymmetry: federal window 2013–2019; only 4 training years vs BEC's 8).
**Scope note:** script 03 owns the **strict-holdout, rolling-origin, leakage-audit, and direct-defendant-scope** rows of Group 7. The **frozen-timing / frozen-pool** cells (`\valFedAud Frozen*`) are produced by the *armor pack* (a separate script writing `diagnostics/audit_armor/frozen_timing.csv`), which **has not run** — `outputs/comprasnet/diagnostics/audit_armor/` does not exist yet. A4's frozen-pool floor (N≥120) cannot be evaluated from 03 alone; see "Open / hand-off" below.

---

## 1. Log health

Clean run, exit 0. One benign warning, no fatal skips:

- L40–42 **Warning** `NAs introduced by coercion` in `sprintf("%014.0f", as.numeric(códigofornecedor))` inside STEP 14 (direct-defendant scope). Non-fatal: a handful of non-numeric supplier IDs coerce to NA in the zero-pad; the defendant AUC still computes on 25 defendants. Cosmetic, expected on federal supplier-ID hygiene.
- L4 gate G3 dropped 2 estab(s) from the unnumbered TI/DF case (by design).
- L5 **195 cobidder positives / 25 direct defendants, disjoint OK** — this is the broad-AL-restricted target (`\valFedAudCobiddersBroadAL` = 195), matching the numbers map.
- L20–22 **REPRO DEVIATION flags fired** (FL_binary 0.6344 vs BEC-lock 0.767; log_tc 0.6660 vs 0.750). **This is expected deflation, not a bug** — the locks are BEC values; the deviation check just confirms the federal numbers differ from the transported BEC reference, which is the whole point of the cross-platform audit. The federal strict-pool continuous AUC = **0.666**, sitting just below the BEC twin 0.684.

**All four blocks ran fully (none degraded):** STEP 6 strict holdout, STEP 7 rolling-origin (6 origin years), STEP 8 leakage audit, STEP 14 direct-defendant scope. Federal panel: 247,475 firm-year rows, 92,070 firms, window 2013–2019; defendant-co-cell exposure rows = 8,475.

---

## 2. Strict-temporal results (federal vs BEC twins)

**Federal strict holdout: train ≤2016 → test 2017–2019.** Train-window AL threshold = **7.5** (BEC twin ≈ 7.5 — coincides). Composition (strict_holdout_composition.csv): 195 cobidders all in train-AL pool; 135 rankable, **60 entrants (30.8%)**; tie-at-zero share 32.4% in the full universe.

### Table T1 — Strict holdout, federal vs BEC (ROC-AUC by sample design)

| Sample design | Federal AUC | Fed N / pos | BEC AUC | BEC N / pos |
|---|---|---|---|---|
| 1 — full test universe (entrants @ score 0) | **0.489** | 92,070 / 195 | 0.474 | 41,444 / 651 |
| 2 — rankable (T_train>0) | 0.496 | 66,734 / 135 | 0.471 | 32,682 / 498 |
| 3 — training-AL pool, **continuous** score | **0.666** | 50,230 / 195 | **0.684** | 21,819 / 651 |
| 3 — training-AL pool, **FL-binary** | 0.634 | 50,230 / 195 | (≈0.65 twin) | 21,819 / 651 |
| 4 — train-AL ∩ test-active | 0.643 | 32,768 / 116 | 0.667 | 11,351 / 312 |
| 5 — zero-win both (LEAKS) | 0.622 | 35,414 / 195 | 0.646 | 16,843 / 651 |

### Table T2 — Rolling-origin, full-universe ROC by origin year (entrants @ 0)

| Origin year | Federal | BEC |
|---|---|---|
| 2014 | 0.517 | 0.462 |
| 2015 | 0.480 | **0.446 (BEC worst)** |
| 2016 | 0.501 | 0.465 |
| 2017 | 0.495 | 0.478 |
| 2018 | 0.511 | 0.479 |
| 2019 | 0.501 | 0.496 |
| **worst-year** | **0.480 (2015)** | 0.446 (2015) |

Federal rolling-origin train-AL pool ROC runs **0.66–0.73** across years (e.g. 2018 train-AL 0.718, 2016 train-AL-active 0.719), tracking the BEC profile. Full-universe ROC hovers at/below 0.50 every year on both platforms — the entrant blind spot is structural and ports.

### Table T3 — Direct-defendant temporal scope (25 federal defendants)

| Design | Federal AUC | (BEC reading) |
|---|---|---|
| 0 — script-33 FL-binary repro | 0.465 | ≈ chance |
| 1 — full-sample continuous | 0.651 | weak |
| 2 — strict-training continuous | 0.707 | weak-moderate |
| 3 — strict-training FL-binary | 0.503 | chance |

Consistent with the locked thesis: the screen ranks **cobidders** (exposure label), not **direct defendants** (FL-binary AUC ≈ 0.46–0.50 vs defendants).

---

## 3. A4 verdict (per R4 protocol)

**The strict-timing federal result SURVIVES, on the row that A4(d) names as the load-bearing carrier.**

A4's pass/fail floor (N≥120 frozen-pool prospective cases) applies to the **frozen-pool row**, which is *not* produced by script 03 and is **pending the armor pack**. But A4(d) is explicit: *"the prospective-ranking-collapses-outside-the-incumbent-pool claim is carried by the strict-universe row, not the frozen-pool row, so the thesis survives the loss."* Script 03 delivers exactly that strict-universe row, and it behaves as required:

- **Strict full-universe ROC = 0.489** (federal) / 0.474 (BEC) — both at/below chance with entrants scored at 0. The prospective ranking collapses outside the incumbent pool on **both** platforms. This needs only the 2017–2019 test window and is **robust to the 4-year pre-period** — exactly A4's fallback carrier.
- **Strict training-AL continuous ROC = 0.666** (federal) vs 0.684 (BEC): a ~0.018 deflation, same sign, same magnitude class. The construct ports and deflates; it does not break.
- **Worst rolling-origin year 0.480** (federal) — no below-chance excursion as bad as BEC's 0.446, i.e. the federal out-of-time profile is, if anything, slightly *steadier*, removing any "too noisy on 4 years" handle.
- Entrant share among positives = 30.8% (federal) ≈ 30.8% (BEC strict) — the structural blind spot is the **same size** on both platforms, so the short pre-period did not manufacture a different coverage hole.

**Net A4 verdict: SURVIVES via the strict-universe collapse row.** The 4-year pre-period does not degrade the rows 03 owns. The only open item is whether the *frozen-pool prospective* row (armor pack) clears N≥120; if it does not, A4(d)'s fallback is already in hand and the comparative table simply marks the frozen-timing cell "—, 4-yr pre-period insufficient" while the strict-universe row carries the prospective claim.

**Consistency with the deflation reading — and the metric-confusion trap.** Yes, fully consistent, *and the high raw timing numbers are NOT a contradiction.* The strict-timing AUCs (0.49 full / 0.67 training-pool) measure the **temporal stability of the RAW screen score** — can a score frozen on the past rank later cobidders? They do **not** measure the opportunity-adjusted residual (within-cell, defendant-contact-adjusted), which is the deflation object (BEC within ≈ 0.553; federal within-strict ≈ 0.462–0.60). These are **different estimands on different samples**: raw-timing is marginal discrimination over the firm universe across time; the deflation rows are residual discrimination *after* netting out exposure/opportunity within matched cells. A referee who reads "timing AUC 0.67" as contradicting "within-cell increment null at 0.46" has conflated the marginal and the residual. The comparative table must label them so this collision cannot happen (see §4).

---

## 4. Labeling guidance for the comparative table (one sentence per row)

To prevent a referee from reading the raw-timing row as a rebuttal of the deflation rows, each row must state its **estimand + sample** in the note:

- **Strict full-universe timing (0.489 fed / 0.474 BEC):** "Raw frozen score over the *entire* test-window firm universe (entrants scored at 0); measures temporal ranking stability of the unadjusted screen, **not** any opportunity-adjusted effect — collapses to chance because new firms are unrankable."
- **Strict training-AL continuous (0.666 fed / 0.684 BEC):** "Raw frozen score among incumbents with prior losing history; measures whether last-period loss-intensity still orders later cobidders — a **marginal** discrimination metric, *before* opportunity/exposure adjustment."
- **Strict training-AL FL-binary (0.634 fed):** "Same incumbent pool, deployable FL cut instead of continuous score; secondary to the continuous row, reported for cut-invariance."
- **Rolling-origin worst-year (0.480 fed / 0.446 BEC):** "Worst out-of-time full-universe ROC across 2014–2019 origins; out-of-time *stability* check of the raw score, not a deflation row."
- **Opportunity-adjusted within-cell (≈0.46–0.55, separate deflation block):** "Residual discrimination **after** netting out defendant-contact exposure within matched item×year×buyer cells; this is the headline deflation object and is **not** comparable to the raw-timing rows above — different estimand, different sample."

**One-line table caption to enforce the wall:** *"Raw-timing rows (frozen-score temporal stability) and opportunity-adjusted rows (within-cell residual) measure different estimands on different samples; a high raw-timing AUC and a null adjusted increment are mutually consistent, not contradictory."*

---

## 5. Anomalous / open / hand-off

- **REPRO deviation flags (L20–22) are cosmetic-by-design:** they compare federal to BEC locks; firing = federal deflation, not a defect. Do not chase.
- **Filename carries the BEC window string** `table_D_strict_2009_2016_to_2017_2019.csv` even on the federal run, although the federal window is **2013–2019** (log L11, threshold 7.5). The numbers-map slot expects `table_D_strict_2013_2016_to_2017_2019.csv`. **Action for integration:** either rename the federal output to the 2013 string or annotate the map that the federal file reuses the BEC filename; otherwise the `\valFedAudStrict*` link step will look for a non-existent file. (Numbers are correct; only the filename token is stale.)
- **Frozen-timing row is PENDING (not 03's job):** `audit_armor/frozen_timing.csv` does not exist; `\valFedAudFrozenPool / FrozenProspAUC / FrozenProspN / FrozenRetroAUC` cannot be filled from this run. A4's formal N≥120 pass/fail is deferred to the armor-pack run. The strict-universe carrier is already sufficient for survival regardless of that outcome.
- **Defendant-ID coercion NAs (L40–42):** confirm the dropped-to-NA supplier IDs are negligible in count before the direct-defendant scope row goes to print (low priority; AUC is robust).
