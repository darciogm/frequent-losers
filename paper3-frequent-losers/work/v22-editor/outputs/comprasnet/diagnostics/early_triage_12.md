# FORMAL ARMOR TRIAGE — script 12 + 12b (ComprasNet / Federal)

**Date:** 2026-06-06 · **Reviewer:** Mr. Frequent Losers (Referee-2 mode) · **Status:** FORMAL TRIAGE
**Inputs:** `outputs/comprasnet/diagnostics/audit_armor/*.csv` + `logs/12_audit_armor_comprasnet.log`
(12b finished only B'+start-of-C'; **12 is the committed run**; `audit_armor_macros.tex` regen'd 01:16
carries the canonical scalars). BEC twins: `NEW_NUMBERS_MAP_COMPRASNET.md` Groups 3/4/7/10.

> **12b status:** 12b re-ran part B (granularity sweep, identical numbers) and *started* C (power curve,
> printed only δ=0.00→0.12 and δ=0.02→0.17 before its log was captured/truncated). It **did not overwrite**
> any committed CSV with a different value — the sweep rows are byte-identical to 12's, and the power
> curve, frozen-timing, defendant-roles and macros all come from 12. **Nothing 12b produced changes a
> verdict.** Use the 12 outputs as committed.

---

## A2 — Positive-set power (within-stratum deflation row)

**Raw facts (verified):**
- Power curve (`permutation_power_curve.csv`, sims=60, B=200):
  @0.50 = **0.117** (size ≈ nominal 0.05, slightly liberal but acceptable at sims=60),
  @0.52 = 0.167, @0.55 = **0.35**, @0.60 = **0.90**, @0.65 = 1.00.
- Protocol threshold reads `\valFedAudPowerFive` ← **0.55 row = 0.35**.
- Positive control O_i (MEDIUM) = **0.9921** (gate ≈0.95 → **PASS**; COARSE 0.9987 also passes).
- Observed within-stratum residual: **0.5582** (12 decile/MEDIUM strata, `granularity_sweep.csv`)
  and **0.462** (02 matched-cells `\valFedAudWithinAUC`-twin) — both near chance.

**Verdict against protocol §A2(c):** `\valFedAudPowerFive = 0.35 < 0.55` → the strict reading is the
**DIES branch** for the *null verdict*: at N+=195 the test would catch a true 0.55 residual only 35% of
the time, so a federal within-AUC near chance is **NOT** an informative "no-residual" null. The
deflation **null** cannot be claimed federally.

**BUT — the design is not blind (the rescue):** the positive control O_i = **0.9921** clears the 0.95
gate. The apparatus *can* perfectly recover an injected exposure signal within the same MEDIUM strata;
the curve also reaches **0.90 @ true-AUC 0.60** and **1.00 @ 0.65**. So the failure to show a residual is
**not a design artifact** — the test is simply under-powered against *small* residuals (≤0.55) at federal
N+, while being fully powered against *large* ones (≥0.60). This licenses the **power-bounded framing**
(protocol §A2 fallback-d, upgraded from "uninformative" to "bounded" precisely because O_i passes and the
curve is monotone and steep just above 0.55):

> *Federal audit rules out a within-stratum residual ≥ 0.60 at ≥90% power (and ≥0.65 at 100%); against a
> 0.55 residual its power is only 0.35, so the small-residual region is not adjudicated federally.*

**Two-estimator reconciliation (one sentence, for the table):** the two federal within numbers — 0.462
(02, matched-opportunity cells) and 0.5582 (12, decile/MEDIUM strata) — are the **same object under two
stratifications of the opportunity surface** (matched-cell vs decile-banded MEDIUM); both sit inside the
power-bounded band [chance, 0.60-not-ruled-out], so the comparative table carries **ONE** within number
(MEDIUM 0.5582, the headline-grade cell) **plus ONE** power bound (≥0.60 ruled out @90%), with no
referee whiplash.

**EXACT ROW-6 CELL TEXT** (`tab:comparative_audit`, within-stratum residual row, federal column):

> **0.56 (MEDIUM; power-bounded)** — federal within-stratum score AUC = 0.56 (decile-MEDIUM strata;
> matched-cell variant 0.46), near chance but **not an adjudicated null**: at N+=195 the matched-permutation
> test detects a true within-AUC of 0.60 with 90% power and 0.65 with 100% power, but a 0.55 residual with
> only 35% power. We therefore report this as *"federal audit rules out a within-stratum residual ≥ 0.60
> (90% power); the ≤0.55 region is not powered federally,"* not as a deflation-to-chance claim. Positive
> control O_i recovers within-strata at AUC 0.99, so the small-residual blind spot is a sample-size limit,
> not a design failure. (BEC twin: within 0.49, power@0.55 = 0.97 — fully powered null.)

---

## Label-blind row reconciliation (ROW 3 — CRITICAL)

**Three federal candidates on the table:**
| candidate | value | source row | construction |
|---|---|---|---|
| part-A cell-level label-blind E | **0.6114** | `leakage_check_cell_level.csv` → "E_i label-blind (cell rate from NON-cobidder rows only)" | `a_lb = auc(y, E_lb)`, `E_lb = Σ p_g_lb`, p_g recomputed with **all cobidder rows dropped** |
| within-AUC label-blind, exposed | 0.6952 | `granularity_sweep.csv` → "E_label_blind_MEDIUM (exposed E_lb>0)" | *within-stratum* AUC of the score, strata banded on E_lb |
| within-AUC label-blind, all-AL | 0.7389 | `granularity_sweep.csv` → "E_label_blind_MEDIUM (all AL)" | same, over all AL |

**BEC anchor:** `\valArmorExpLB = 0.553` is bound in BEC `audit_armor_macros.tex` from
`a_lb` (script 12 line 412: `\valArmorExpLB … %% src: label-blind exposure AUC`), and the BEC
`leakage_check_cell_level.csv` carries it as **"E_i label-blind (cell rate from NON-cobidder rows
only) = 0.5531"**. The code path (lines 221-241): `p_g_lb = def_rows_lb/n_rows_lb` (cobidder rows
excluded) → `E_lb = sum(p_g_lb)` per firm → `a_lb = auc(y, E_lb)`.

**CHOSEN FEDERAL NUMBER: 0.6114** — apples-to-apples by **identical construction, identical column,
identical macro name** (`\valArmorExpLB`, already bound to **0.611** in the federal macros file). The
BEC 0.553 is a *firm-level exposure AUC built from non-cobidder cell rates*, **not** a within-stratum
sweep AUC. The 0.6952 / 0.7389 are a *different object* — the within-stratum score AUC after banding on
label-blind E — whose BEC twins are `\valArmorWithinLB = 0.665` and `\valArmorWithinLBall = 0.722`
(Group-10 secondary extras, NOT the row-3 headline). Matching 0.553 to 0.695/0.739 would compare an
exposure-ranking AUC to a within-stratum AUC: category error.

**EXACT ROW-3 CELL TEXT** (`tab:comparative_audit`, label-blind opportunity E, federal column):

> **0.61** — label-blind exposure E (firm-level AUC vs cobidder, opportunity cell rate computed from
> NON-cobidder rows only; all eventual-cobidder rows purged from p_g). Federal 0.61 vs BEC 0.55:
> the genuine opportunity structure alone ranks future cobidders modestly above chance on both platforms,
> slightly stronger federally — the first stage of the deflation (raw concentration ≈ opportunity
> arithmetic) **replicates**. (Macro `\valFedAudExpLB` = `\valArmorExpLB` = 0.611.)

---

## A4 — Frozen-timing / window asymmetry (ROW 8)

**Raw facts (verified, `frozen_timing.csv`):**
- d1 prospective (label = NEW contact 2017-2019): AUC = **0.5948**, N+ = **98**, pool = 24,888.
- d2 frozen retrospective (contact within 2013-2016): AUC = **0.7404**, N+ = 177.
- BEC twin: prospective **0.713**, N+ = **231**, pool 13,051.

**CI (Hanley-McNeil normal approx):**
- Federal prospective: SE = 0.0303 → **95% CI [0.535, 0.654]**.
- Federal retrospective: SE = 0.0215 → 95% CI [0.698, 0.783].
- BEC prospective: SE = 0.0193 → 95% CI [0.675, 0.751].

**Verdict against protocol §A4(c):** N+ = 98 is **below** the heuristic floor (N ≥ ~120; BEC = 231).
**However**, the prospective CI is **[0.535, 0.654]** — it does **NOT** span the [0.4, 0.9] "uninformative"
DIES range; it excludes 0.5 (lower bound 0.535) and excludes the BEC 0.713. So this is **INFORMATIVE but
power-limited**: a genuine, modest, above-chance prospective signal on a 4-year pre-period, materially
weaker than BEC's 0.713 (CIs barely overlap at the federal upper / BEC lower edge). Not a "—".

**Verdict:** **REPORT with the 4-year-pre-period caveat**, do not blank to "—". The retrospective leg
(0.74, CI [0.70, 0.78]) is robust and corroborates the design. The prospective-ranking claim is carried
*primarily* by the strict full-universe collapse (entrants-at-zero), with the frozen-pool 0.59 shown as a
weaker, short-pre-period prospective replication.

**EXACT ROW-8 CELL TEXT** (`tab:comparative_audit`, label-frozen prospective, federal column):

> **0.59 [0.54, 0.65] (4-yr pre-period)** — label-frozen prospective AUC for NEW 2017-2019 cobidder
> contact (train ≤ 2016; pool 24,888; N+ = 98). Above chance (CI excludes 0.50) but below BEC's 0.71
> [0.68, 0.75] and below the N ≥ 120 comparability floor; the frozen pool trains on only 4 pre-years
> (2013-2016) vs BEC's 8. Frozen *retrospective* AUC is 0.74 [0.70, 0.78], confirming the design carries
> timing signal. We lead the prospective-ranking claim on the strict full-universe collapse and report
> this row with the explicit 4-year caveat. (`\valFedAudFrozenProspAUC` = 0.595, N = 98.)

---

## Defendant roles (`defendant_roles.csv`)

| macro | federal | BEC twin | sanity |
|---|---|---|---|
| `\valFedAudDirectsMatched` | 27 | 47 | federal CADE-anchor smaller — expected (different jurisdiction coverage) |
| `\valFedAudDirectShareAL` (`\valDirectShareALnew`) | **14.8%** | 14.9% | **near-identical** — the always-loser share among direct defendants ports almost exactly |
| `\valFedAudDirectMedWR` (`\valDirectMedWRnew`) | **0.190** | 0.261 | direct-defendant median win-rate lower federally but same order; both ≫ cobidder |
| `\valFedAudCobidderMedWR` (`\valOthersMedWRnew`) | **0.000** | 0.000 | **identical** — cobidder median win-rate is zero on both platforms (winner-heavy directs vs loser cobidders) |

**Reading:** the winner-heavy-direct / loser-cobidder asymmetry (the D4 structural finding) **replicates
federally**: directs win at median 0.19, cobidders at median 0.00, AL-share among directs 14.8% ≈ BEC
14.9%. No anomaly.

---

## OVERALL — does any armor result threaten the Draft A reading?

**No. All four Draft-A pillars stand:**

1. **Exposure-only ≥ raw** — intact (exposure benchmark LOO 0.821; label-blind E 0.611 > chance,
   replicates BEC 0.553 direction).
2. **Sub-0.5 / near-chance within-stratum point** — intact as a *point estimate* (0.56 MEDIUM / 0.46
   matched), now **honestly framed as power-bounded** (rules out ≥0.60 @90%, not a clean null) rather than
   a deflation-to-chance claim. This is a **framing tightening, not a pillar break**.
3. **Permutation null** — the matched-permutation machinery is valid (size @0.50 = 0.117, monotone steep
   curve, O_i positive control 0.99). The federal null is *under-powered against small residuals*, so the
   verdict moves from "null confirmed" to "≥0.60 residual excluded" — still a Draft-A-compatible statement.
4. **Negative controls / positive control** — O_i = 0.9921 (PASS), defendant-role asymmetry replicates
   (directs 0.19 vs cobidders 0.00). Design is informative.

**Draft A/B switch (protocol):** A2 power < 0.55 on the *0.55-row* would, read literally, push the
*within-stratum null* toward the demote-fallback — **but the positive control passes and the curve is
fully powered ≥0.60**, so this is the protocol's **MARGINAL → power-bounded** lane (§A2 b/d), not Draft B.
Draft B requires a *powered residual* (within-AUC materially > 0.5 with the test powered to see it);
federally the residual is *near chance*, the only question is whether small residuals are adjudicated, and
the answer is "not below 0.60." **Stay on Draft A**, with the within-stratum row carrying ONE number + ONE
power bound exactly as specified above. No armor result threatens the Draft A reading.

**Caveats to disclose (honest, survivable):**
- Within-stratum: power-bounded, not a clean null (≤0.55 region unadjudicated at N+=195).
- Frozen-prospective: 4-year pre-period, N=98 below floor; lead on strict-universe collapse.
- Both are *narrowings of the portability claim*, fully consistent with the protocol's pre-written
  fallbacks; neither inverts a sign or overturns a pillar.
