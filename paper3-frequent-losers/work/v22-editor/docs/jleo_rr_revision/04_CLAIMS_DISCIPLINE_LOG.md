# 04 — CLAIMS DISCIPLINE LOG (JLEO R&R v22)

Two sections. Section A = claims only defensible if NEW analysis survives (with allowed/fallback language). Section B = forbidden/dangerous language + candidate files. **Do not mass-edit yet** — this is the audit; edits happen in the section passes.

Scan basis: 4-agent fan-out, 2026-06-02. Current prose forbidden-term scan came back **clean** — every risky term currently appears in *negated/disclaimer* form, consistent with the locked rules. The risk in this revision is **re-introducing** overclaim while strengthening, not existing violations.

---

## Section A — Claims contingent on new analysis

### A1. "The ranking survives opportunity-set exposure"
- **Currently cited:** App D.2 exposure-adjusted audit (prose-only until v22).
- **Now supported by:** `76_exposure_adjusted_audit.R` — within-opportunity-stratum AUC `log_tc`=0.7715 (≥0.70), increment over exposure-only +0.0415 (DeLong p=2.08e-06). PASS.
- **Allowed language (if it holds):** "Within matched opportunity sets, the award-layer ranking retains discriminating power, adding information beyond participation volume and opportunity exposure (within-stratum AUC ≈ 0.77; +0.04 over an exposure-only model, p<0.001)."
- **Required honesty:** must state exposure-only *alone* already reaches AUC 0.946; the claim is **incremental**, not that the raw 0.92 is exposure-free.
- **Fallback if it weakens (e.g. extra strata kill the increment):** "the ranking is partly, not wholly, an exposure artifact; we report the residual signal and bound its size" — and demote from core claim.

### A2. "The award-layer signal adds non-redundant information to bid-layer forensics"
- **Currently cited:** Imhof horse-race (`\valAUCImhofPlusFL`=0.942 vs Imhof 0.846).
- **Required stronger evidence:** documented bid-layer benchmark (features/learner/CV/missingness/case-holdout — Table E) + incremental-AUC with leakage controls (`49`).
- **Allowed:** "comparable discrimination at lower informational cost; the award layer adds non-redundant signal."
- **Fallback:** "the layers are complementary in coverage, not strictly additive in AUC" — never "outperforms."

### A3. "The sequential gatekeeper is operationally valuable"
- **Currently cited:** single "83% pool reduction" + `\valGateSeqKTwoKOneTPIn`=131/193 recovered.
- **Required:** frontier over K1 and cost denominators (Table D); PR-AUC/precision@k/recall@k/FP/FN; run script 56.
- **Allowed:** "across a range of first-stage cutoffs, the award layer concentrates the bid-microdata pool while retaining most adjudicated cobidders; the operator chooses a point on the cost-recall frontier."
- **Fallback:** if recall collapses at affordable K1, report the frontier honestly and frame as "useful only under specific budget regimes."

### A4. "Cobidders have economic content beyond high-volume losing"
- **Currently cited:** §5 profile vs other frequent losers; LCA cover probabilities.
- **Required:** volume-matched profile (`74`), and disclose script 78 (compression loads on genuine bidders, not FL count).
- **Allowed:** "even matched on participation volume, cobidders differ on [verified dimensions]."
- **Fallback:** if matching erases the difference, "cobidders are largely high-volume losers; the screen's value is operational ranking, not a distinct firm type."

### A5. "Price patterns support scope evidence"
- **Currently cited:** sign-reversal decomposition; `\valCSAttPrice`=+0.145.
- **Required:** keep as **descriptive scope only**; integrate `78` (theater not identified).
- **Allowed:** "price patterns are consistent with the screen's scope and corroborate where to look; they are not a damages base or proof of a price effect."
- **Fallback / mandatory:** drop any "cover-bidding theater" mechanism claim — `78` shows within-cell compression is genuine-bidder entry (l_gen=−0.137) not FL count (l_fl≈ns).

### A6. "Strict timing supports prospective use"
- **Currently cited:** temporal holdout (`\valAUCFLfirmTemp`=0.864); frozen-train (`53`).
- **Required:** report `53` (binary 0.767 > continuous 0.750 on strict pool — a **flip**) and `77` honestly.
- **Allowed (bounded):** "out-of-time, the ranking retains moderate discrimination (frozen-threshold AUC ≈ 0.77)."
- **MANDATORY honesty:** script 77 verdict is FAIL — cobidders are *more* temporally spread (year-HHI d=−0.66), so deployment vs sincere persistence are **observationally equivalent**. Must state: "we cannot distinguish strategic deployment from sincere persistent participation; the timing evidence does not establish prospective causal use."

## Section B — Forbidden / dangerous language

Search terms + current candidate files (all current hits are negated/disclaimer; flagged so the section passes don't flip them to affirmative).

| Term | Current status | Candidate files (file basis) | Rule |
|---|---|---|---|
| detect cartel(s) / detects cartelists | clean (not used affirmatively) | sec01, sec03 | never affirmative; "flags/screens/prioritizes forensic attention" |
| cartel member / membership / cartel firm | negated only | sec01:22,58; sec03:50,90,155; sec04:341; app01:144,160; app02:112 | always "not membership"; screen targets priority not membership |
| proves / proof (as claim) | enforcement concept only | sec01:4,11,135,160; sec03:10,155; sec08:43,52; frontmatter | "before proof"/"not proof"; never "the screen proves" |
| overcharge | negated only | sec07:25-32; app04:34-38 | "not an overcharge/damages base" |
| damages | negated only | sec07:7,25-32,331,340; sec08:45 | scope, not damages |
| causal (price/mechanism) | negated only | sec04:157; sec07:58,77,104,138,331; app02:169; app04:5 | "descriptive, not causal" |
| cover bid / cover-bidding (mechanism) | hedged hypothesis | sec05:96,136,156,182; sec07:12,20,157,170,180,191,237; sec08:30 | **DOWNGRADE per script 78** — theater not identified; keep as unproven hypothesis or drop |
| guilty | **zero hits** | — | keep zero |
| liability | negated only | sec01:7,144; sec08:31; app01:154-175; app06:20,85 | "liability remains in richer record" |
| fraud | **zero hits** | — | keep zero |
| cartel-adjacent / cartel-adjacency | affirmative (label) | sec02:173,219; sec04:24,81,219; sec05:1,136; sec07:54; frontmatter:22 | **use sparingly**; prefer "adjudication-anchored exposure" in technical text; define cartel-adjacent ONCE, legally bounded |
| outperforms / dominates (vs benchmark) | check | sec06 | never; "comparable at lower cost" |

### B-actions for the integration pass
1. Replace most technical-text "cartel-adjacent" with **"adjudication-anchored exposure"**; keep one bounded definition.
2. Audit every "cover bid/theater" instance against script 78 — convert to unproven-hypothesis or delete.
3. After each section edit, re-run the term scan to confirm no affirmative flip was introduced.
4. Abstract currently says "ranks loser-side cartel-adjacency risk" — soften to "ranks loser-side adjudication-anchored exposure" in the technical sense; keep the legal-boundary sentence.
