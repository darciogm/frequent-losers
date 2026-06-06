# Claims-Consistency Check After Repositioning (v22, Jun 6 build)

**Scope.** Final claims-consistency pass on the repositioned JLEO package:
`submission_clean/paper_submission_clean.pdf` (47 pp) +
`online_appendix_submission_clean.pdf` (40 pp). Cross-checked against
`docs/jleo_rr_revision/CONSOLIDATED_RESULTS_FEDERAL.md` and `values.tex`.

**Headline verdict.** Every major claim is graded **supported** as worded. The
paper is consistently governance-first; nothing reads as a successful cartel
screen. Zero "too strong" claims found. Two production defects (not claim
defects) are documented in the visual-review companion doc; they do not change
any grade here.

---

## Claim-by-claim grades

| # | Claim | Final PDF wording (quoted) | Support | Grade |
|---|---|---|---|---|
| 1 | Award-layer records can organize audit-worthy suspicion | Abstract: "Routine procurement-award records are cheap and broad but legally thin … we study the minimal award-layer screen". Box 1 row "Raw ranking → Yes, the raw concentration is real → Worth auditing as exposure, not yet read as conduct." | §1, §2, Box 1 | **supported** |
| 2 | Raw frequent-loser ranking concentrates exposure | §4.1: "On the full always-loser pool the continuous score ranks the label at ROC-AUC 0.761 … the raw ranking is picking up a pattern worth auditing, not noise." | §4.1, Table 3 (raw 0.761), Table A.3 | **supported** |
| 3 | Opportunity explains much of raw concentration | §1: "Most of it is procurement opportunity"; §4.2: "label-blind opportunity ranking at only 0.553 … Genuine opportunity structure, purged of the label, therefore explains little on its own" / "The apparent reach of the routine record is opportunity arithmetic." | §4.2, Table 3, Table C.1, federal Table 5 (0.553) | **supported** |
| 4 | Residual ordering is marginal | §4.2: "conditional on opportunity the residual ordering is marginal at best and not robust across designs … within opportunity strata … AUC 0.471 … both indistinguishable from chance." Nested DeLong "+0.010 (p = 0.013)". | §4.2, Table 3, Table C.1 (WITHIN 0.471; NESTED +0.010) | **supported** |
| 5 | Strict prospective ranking fails outside incumbents | §4.3: "On the realistic full candidate universe … discrimination is at or below chance: ROC-AUC 0.474, PR-AUC 0.014, and precision@500 = 0 … A screen that returns zero true positives in its top 500 candidates cannot be deployed." | §4.3, Table 4, Table C.2 | **supported** |
| 6 | Case concentration limits portability of the BEC score | §4.3: "The largest case … supplies 32.0% of all positives and 45.4% of the top-500 true positives. Dropping it cuts PR-AUC from 0.143 to 0.090 (−37%)." §7.2: "The estimated ranking travels poorly as a cartel score." | §4.3, Table 4, Table C.3, §7.2 | **supported** |
| 7 | Audit logic travels across platforms (stress-test, NOT independent validation; overlapping anchors) | §5: "ComprasNet is a stress test of the protocol's portability, not an independent cartel universe; the two platforms share part of the same CADE record, so we read the federal result as neither confirmation nor refutation of any firm's legal status." §5.2: "partially overlapping CADE anchors". Abstract & §1: "stress-tested on a second procurement platform". | §5, Table 5, App. G | **supported** — "partially overlapping legal anchors" present; "stress test" framing explicit; no independent-validation overclaim |
| 8 | Bid-layer benchmark is a full-observability comparator (not "beats bid forensics") | §7.1: "comparable discrimination at lower informational cost, not a victory of one layer over the other"; "The combined award-plus-bid model … is therefore a full-observability upper bound, not a first-stage rule." | §7.1, Table 6, App. E | **supported** — no "beats bid forensics" anywhere |
| 9 | Cost-recall frontier is a recovery-footprint object (operating point, not optimum) | §7.2: "There is no optimal cutoff. The frontier itself, not any single operating point, is the enforcement-design object." / "K1 = 2,000 is thus one operating point on the frontier, not a calibrated optimum." | §7.2, Table 7, Fig. 3, App. E.7 | **supported** |
| 10 | Price evidence is scope only (no damages/overcharge/causal) | §8: "It is scope evidence … It is not a damages estimate, an overcharge, a cartel markup, a causal price effect … or proof of a cover-bidding mechanism. We draw the boundary once and hold to it." | §8, App. F | **supported** |
| 11 | Liability remains in the richer evidentiary record | Abstract: "Liability stays where the evidence is richest." §2: "liability stays in the bid layer." Conclusion: "leave liability in the richer evidentiary record where it belongs." | §1, §2, §9, Corollary 4 (App. B) | **supported** |

No claim graded "partially supported," "too strong," or "should delete." No fix
required for any claim.

---

## Critical failure-condition checks (each PASS/FAIL)

### 1. Does the paper anywhere read as a SUCCESSFUL cartel screen (overclaim)? — **PASS (no overclaim)**
- Grep of both PDFs for `detect cartel / detects cartel / proves / outperform /
  cartel detector / successful screen / conduct identifier`: **zero positive
  assertions.** All "cartel membership / cartel member" hits are **negations**
  ("not cartel membership", "is not thereby a cartel member", "not a portable
  cartel score").
- The headline of the empirical core is deflationary by design: §4.2 "the score
  no longer supports a conduct interpretation"; §1 "What we offer as portable is
  the architecture, not a validated score"; §9 "The estimated ranking is not a
  portable cartel score." The contribution is explicitly the **audit
  architecture / cost-recall frontier**, never a working detector.

### 2. Does it call cobidders cartel members, or the FL score a conduct identifier? — **PASS**
- Cobidder is defined throughout as "an adjudication-anchored exposure label, not
  membership" (§2.2, Table 1, Table 2 notes, every appendix that uses the term).
- §2.2: "Cobidder status is not legal membership or a latent truth about
  agreement."
- FL score: §3.1 "It orders firms for forensic priority; it does not assign a
  firm type"; §6.1 "The award-layer rank is therefore an exposure ranking, not a
  collusion-intensity ranking." No conduct-identifier claim anywhere.

### 3. Does it claim platform-wide prospective deployment? — **PASS (all negated)**
- Every occurrence of "prospective / platform-wide / deploy" is a **denial**:
  §1 "this is a retrospective cost-footprint design … not a fully prospective
  deployment test"; Box 1 Timing row "No platform-wide prospective deployment";
  §4.3 "explicitly not a prospective, platform-wide screen"; §7.2 "not a
  prospective platform-wide deployment test."

### 4. Is the 193 target anywhere (should be 651)? — **PASS (zero occurrences of 193)**
- `grep "193"` on both PDFs: **0 hits.** The BEC validation target is **651**
  always-loser cobidders everywhere (§1, §2.2, Table 1, Table 2, Table A.2/A.3,
  §6, §7, App. E). FL composition is consistently 341 FL / 310 non-FL of 651.
- Federal target is **195** broad-AL cobidders (3,850 under the broad rule before
  the AL restriction) — matches CONSOLIDATED_RESULTS_FEDERAL.md exactly
  (`B_broad_AL_cobidders_MAIN = 195`; broad rule 3,850). §5.2 wording "3,850 …
  under the broad rule and 195 under the broad always-loser restriction" is
  internally consistent and source-faithful.

---

## Cross-source numeric spot-checks (all consistent)
- Raw BEC AUC 0.761; label-blind opportunity 0.553; within-stratum 0.471; nested
  +0.010 (p=0.013); matched-perm p=0.127; power 0.97@0.55 / 1.00@0.60 — all match
  values.tex and consolidated doc.
- Federal: raw 0.744; exposure-only 0.754; label-blind 0.611; within 0.462;
  nested +0.005 (p=0.191); matched-perm p=0.906; power 0.35@0.55 / 0.90@0.60;
  top-case 35.4%; prospective frozen 0.595, retrospective 0.740 — all match
  Table 5 / Table G.2–G.4 / consolidated doc.
- 47 BEC-active direct defendants; 12 CADE cases / 65 defendants; 16,843
  always-losers; 2,735 FL (16.2%); cutoff 13.5 → Ti≥14 — all consistent.
- Federal direct-defendant scope AUC 0.651 (full) / 0.548 (within-AL) vs BEC
  0.491 — consistent; loser-side boundary "ports."

**Overall claims verdict: CLEAN. All 11 major claims supported as worded; all 4
critical failure conditions PASS. No prose fix required. The only open items are
LaTeX rendering defects in Appendix G (documented in the visual-review doc), which
do not touch any claim grade.**
