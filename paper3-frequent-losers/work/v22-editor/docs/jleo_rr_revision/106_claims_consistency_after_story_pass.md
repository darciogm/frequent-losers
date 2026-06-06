# Claims Consistency — After Story/Compression Pass

**Date:** 2026-06-06
**Source graded:** compressed `paper_submission_clean.pdf` (~48pp) + `online_appendix_submission_clean.pdf`,
text extracted to `outputs/diagnostics/final_manuscript_text_story_pass.txt` /
`final_appendix_text_story_pass.txt`.
**Scope:** read-only grading of the 13 major claims against the compressed prose. Line numbers
refer to `final_manuscript_text_story_pass.txt` unless prefixed `app:`.

**Verdict:** all 13 claims **SUPPORTED** at the altitude the prose states (none too-strong).
All four critical-fail checks **CLEAN**.

---

## 13 Major Claims

| # | Claim | Grade | Grounding quote |
|---|-------|-------|-----------------|
| 1 | Award layer organizes suspicion (allocates forensic attention, not proof) | **SUPPORTED** | "The flag identifies no firm type and assigns no cartel membership; it allocates forensic attention, leaving the richer bid layer to judge tender-level conduct and agreement." (L95–97) |
| 2 | Raw FL concentrates exposure | **SUPPORTED** | "Read raw, the ranking does concentrate adjudication-anchored cobidders inside the always-loser stratum." (L123–124) — stated as a raw, pre-audit fact. |
| 3 | Opportunity explains much of the concentration | **SUPPORTED** | "Most is procurement opportunity: firms that participate more, in the same environments as adjudicated defendants, meet them more often." (L125–126); label-blind benchmark "leaves an opportunity ranking at just 0.553" (L631). |
| 4 | Residual signal is marginal | **SUPPORTED** | "Within comparable opportunity sets the residual ordering is marginal—close to chance in matched cells, a small increment over an exposure-only model" (L126–128); "the exposure-only model raises AUC by 0.010 (DeLong p = 0.013)" (L655). Honestly hedged: power-bounded at 0.55 (L683). |
| 5 | Prospective ranking fails outside incumbents | **SUPPORTED** | "Strict prospective ranking fails outside the incumbent pool" (L129); "it does not support platform-wide deployment" (L733–734). |
| 6 | Case concentration limits portability | **SUPPORTED** | "the apparent reach is case-sensitive: a single adjudicated case supplies a large share of the positives" (L130–131); "The single largest CADE case supplies 32.0% of the positives and 45.4% of the true positives" (L1380–1381). |
| 7 | Over-crediting bias explains the inflation | **SUPPORTED** | "the raw screen's reach is mostly an over-crediting bias we characterize: a size-bias whose magnitude is governed by participation-volume dispersion, summarized by a sufficient statistic" (abstract L18–20); CV-of-participation sufficient statistic (L177, L650, L1563). |
| 8 | The audit travels (not the score) | **SUPPORTED** | "The audit travels; the score does not." (L885–886); "What travels is the decomposition—label construction, opportunity adjustment, timing discipline..." (L1382–1384). |
| 9 | The score does not travel | **SUPPORTED** | "the loser-side score again fails to survive the opportunity adjustment" (L888); "The estimated ranking travels poorly as a cartel score." (L1382); "The estimated ranking is not a portable cartel score" (L1599). |
| 10 | Bid benchmark is a full-observability upper bound | **SUPPORTED** | "it is a full-observability upper bound, not a first-stage rule" (L1248); "The combined model is a full-observability upper bound, not a first-stage screen" (L1297); §7.2 titled "Bid-Layer Forensics as a Full-Observability Benchmark" (L1218). |
| 11 | Cost–recall = recovery-footprint accounting (no optimal cutoff) | **SUPPORTED** | "No single cutoff is optimal; the frontier itself is the enforcement-design object." (L142–143); "'There is no optimal cutoff' is then a result, not a confession" (L155–156); "it prices the recovery footprint" (L1210). Denominator honestly disclosed: "large in firms opened, far smaller in tender-items and bid rows" (L141–143). |
| 12 | Price evidence is scope only | **SUPPORTED** | "Price evidence enters only as scope information" (L196); "price evidence is scope, not damages" (L1594); §8 title "Scope, Limits, and Price Corroboration" (L1497). |
| 13 | Liability stays in the richer record | **SUPPORTED** | "Liability stays in the richer record." (abstract L22); "it supports triage rather than liability: the award layer orders attention... and richer records then judge" (L1147–1148). |

No claim is graded **too-strong** or **needs-qualification**: every headline carries its own
hedge in the compressed prose (power bound at 0.55, case-fragility %, denominator caveat,
ComprasNet shared-anchor caveat, full-observability "upper bound, not a first-stage rule").

---

## Four Critical-Fail Checks

| Check | Status | Evidence |
|-------|--------|----------|
| No overclaim-as-detector | **CLEAN** | "this paper is therefore not a new cartel detector. It is an audit architecture for deciding" (L manuscript). No instance of "cartel detector / detects cartelists / outperforms" used affirmatively; `operationally useful screen`, `signal survives`, `cartel-adjacent`, `cover-bidding theater` = 0 hits in both PDFs. |
| Cobidders ≠ members | **CLEAN** | All 9 manuscript + 4 appendix occurrences of "cartel members/membership" are in the disclaiming form: "Cobidders are adjudication-anchored exposure labels, not cartel members" (L838); "against reproducible adjudication-anchored exposure rather than cartel membership" (L106); "not cartel membership" repeated at L95, 454, 541, 968, 1296, 1410, 1594. `legal membership anchors` = 0 hits. |
| No platform-wide prospective deployment | **CLEAN** | "it does not support platform-wide deployment" (L733–734); "not a fully prospective deployment test" (L154, L729). Both occurrences of "prospective deployment" are negated. |
| 651 not 193 | **CLEAN** | `193` = **0 hits** in manuscript, appendix, and supplement PDFs. `651` appears 30× in the manuscript; target stated as "the set of 651 unique always-loser firms that share at least one tender-item with a BEC-active direct CADE defendant" (L107–108). `archived`, `frequent-loser only`, `cade_fl_cobidders` = 0 hits. |

**Overall: CLEAN.** No blocker. All 13 claims supported at stated altitude; all four critical
fails verified clean against the compressed PDF text.
