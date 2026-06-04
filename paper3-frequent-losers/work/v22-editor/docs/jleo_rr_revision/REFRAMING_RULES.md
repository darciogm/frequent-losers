# REFRAMING RULES — binding for all manuscript-edit agents (2026-06-04)

Read together with `NEW_NUMBERS_MAP.md` (the only permitted source of numbers).

## 0. The target story (Step 6 — what the paper now says)

> "The main validation label is the broad adjudication-anchored cobidder target: a unique
> always-loser firm that shares at least one BEC tender-item with a BEC-active direct CADE
> defendant. Direct defendants are excluded. The frequent-loser flag is not used to construct
> the label."

FORBIDDEN in submitted text (remove/replace wherever found):
- "archived", "not reproduced", "builder", "replication caveat", "frequent-loser only",
  "narrow cartel-tender", "static narrow", "cade_fl_cobidders", "$193$" as a target count,
  "the $210$/$108$ figures in earlier drafts", "earlier drafts"
- "cartel-adjacent"/"cartel adjacency" (use "adjudication-anchored exposure")
- "legal membership anchors" / "cartel membership anchors" (use "legal anchors" or
  "adjudicated defendants")
- "cartel detector", "cartel members" (for cobidders), "detects cartels", "proves"

## 1. The honest empirical verdict (binding — Step 9 adapted to actual evidence)

Under the reproducible non-circular label, the decomposition is MORE deflationary than the
previous draft: the award-layer score's apparent reach is mostly procurement opportunity and
case concentration; **within comparable opportunity sets the residual ordering is marginal at
best and not robust across designs** (within-stratum AUC ≈ chance; nested increment +0.010,
p = 0.013; matched permutation p = 0.127; FL-enrichment p = 0.067; matched FL14 gap negative).
NEVER write "limited but statistically reliable residual" — the supported phrasing is
"marginal at best and not robust across designs" or "no robust residual ordering net of
opportunity".

The paper's claim: a transferable framework for auditing the reach and limits of cheap
award-layer screens before opening costly bid records. Value = disciplined forensic
prioritization audit + showing where cheap screens stop. NOT a screen-works paper, NOT a
membership classifier.

## 2. Replacements (Step 9)

| Forbidden / discouraged | Use instead |
|---|---|
| operationally useful | (drop, or) retrospective adjudication-anchored validation |
| deployable / deployment-ready | incumbent-firm triage (with caveat) |
| prospective (as achieved property) | retrospective; "not platform-wide prospective deployment" |
| screen works / transferable screen | transferable diagnostic framework |
| cartel-adjacency target | adjudication-anchored exposure target |
| legal membership anchors | legal anchors / adjudicated defendants |
| Imhof full pipeline / state of the art | transparent bid-moment random-forest benchmark inspired by Imhof–Wallimann-style screens |
| dominates / outperforms (our results) | "is comparable to" / report both numbers |
| adds non-redundant information | conditional complementarity with this implemented benchmark |
| recovers/reduces X% of costs | recovery-footprint reduction (state denominator) |
| optimal cutoff | one operating point on the frontier |

## 3. Timing caveats (Step 10) — attach to EVERY operational claim

- "incumbent-firm triage", "rankable incumbent pool", "retrospective adjudication-anchored
  validation", "not platform-wide prospective deployment".
- §6 must carry (verbatim or near): "Because strict timing for the bid rerank is not available
  with the current LANCES features, the sequential frontier should be read as a retrospective
  cost-footprint design conditional on the validated incumbent ranking, not as a fully
  prospective deployment test."

## 4. Case-dominance framing (Step 11)

- The method is transferable; the estimated BEC ranking is case-sensitive (largest case 32.0%
  of positives, 45.4% of TP@500; drop-largest PR −37%).
- Keep/insert: "The estimated ranking is not a portable cartel score. The transferable object
  is the decomposition framework: label construction, opportunity adjustment, timing
  discipline, case-composition audit, bid-layer comparison, and cost-recall accounting."

## 5. Bid-layer benchmark framing (Step 12)

- "transparent bid-moment random-forest benchmark inspired by Imhof–Wallimann-style screens".
- Not a state-of-the-art horse race; full-observability forensic benchmark; combined model is
  an upper bound; complementarity is conditional on THIS implemented benchmark.
- HONESTY (new numbers): award ≈ bid pooled (0.760/0.143 vs 0.717/0.116); combined beats award
  on PR under random CV (0.188) but falls BELOW award-only under case-grouped folds
  (0.103 vs 0.143). Say so.

## 6. Cost-recall framing (Step 13)

- The frontier is the object, not K1 = 2000; K1 = 1000 happens to beat K1 = 2000 at k = 500
  here — further proof no K is "optimal".
- Firm-count savings (88% at K1=2000) overstate bid-row savings (33%); tender-items and bid
  rows are the realistic denominators; report FP and missed positives; recovery-footprint
  measures, not measured agency budget savings.
- FORBIDDEN: "saves 83% of costs" (any % without explicit denominator), "optimal cutoff",
  "drastically reduces proof costs", "deployment-ready".

## 7. Price framing (Step 14)

- Price is scope evidence; no damages, no overcharge, no causal price effect, no mechanism
  proof; broad positive association + overlap-cell sign reversal block simple markup readings;
  peripheral to the main contribution; ≤1 short main-text paragraph in §7 beyond the table.

## 8. Production hygiene (Step 15)

- No "Appendix Appendix", no double-period headings ("Performance..", "..,"), no
  "not_observed" in prose, no TODO/BLOCKED/FIXME/Subprompt/Claude/Mr. Frequent Losers.
- Figure 1 vocabulary: "Costly recovered bid record", "Routine award record",
  "Bid-distribution forensics", "Award-layer triage score", "Information coarsening /
  administrative visibility"; caption states "This is an information-cost diagram, not a
  detector horse race." Remove any AUC literal from Figure 1 unless regenerated.
- One "not proof / not membership" disclaimer per section, not five.
- Tag each edited file once at top: `% REVISED: canonical-target reframe 2026-06-04`.

## 9. Macro vocabulary (agreed with the values.tex agent)

New macros (already defined): \valMainCobidders (651), \valMainCobFL (341), \valMainCobNonFL
(310), \valMainConsCobidders (208), \valMainConsFD (19), \valMainTimingCobidders (498),
\valMainEntrantPositives (153).
Replace \valCobidders → \valMainCobidders everywhere (fix surrounding prose: positives are
ALWAYS-LOSER cobidders, not "frequent-loser cobidders").
Macros listed in NEW_NUMBERS_MAP as rebound keep their names (values agent rebinds). Any
old-label number NOT in the map: do not cite; if the sentence needs it, rewrite the sentence.
