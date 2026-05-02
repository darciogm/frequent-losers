# Final JLEO Audit Memo — Paper 3 (v19, PART 7)

**Status:** Final pre-submission JLEO audit complete. PDFs compile clean (main 45 pp, online appendix 15 pp). Zero rendered occurrences of JPART/JPAM register markers (`triage`, `deployable`, `operationally honest`, `operational claim`, `oversight body`). All headline numbers consistent across abstract, body, validation, results, mechanisms, robustness, limitations, conclusion, tables, and appendix.

---

## A. Issues found and fixed in PART 7

### A.1 JPART/JPAM-register leakage

The JLEO reframe in PARTs 2–6 reframed the major sections but left several JPART/JPAM register markers in robustness, limitations, data section, mechanisms, and three table notes. PART 7 swept them out.

| Location | Before | After |
|---|---|---|
| §9.3 subsection title | "Operational Metrics: In-Sample vs Temporal Holdout" | "Temporal Holdout: Generalization of the Screening Statistic" |
| §9.3 opener | "The deployment claim rests on operational metrics... operationally honest projection for a screening tool that is built on past participation data and deployed against a future case-load." | "In-sample evaluation of the screening statistic confounds classification with prediction... constructing the score on 2009–2016 participation only and evaluating on items in 2017–2019 yields a firm-level AUC of $\valAUCFLfirmTemp$." |
| §9.3 closing | "Three operational implications follow. First, the construct is deployable... Second, the temporal holdout is the honest reference... Third, periodic rescoring matters: an oversight body running the screen in production..." | "The generalization audit reads against the screening framing of §5.3 as a diagnostic of how well the participation primitive separates cartel-adjacent from non-cartel-adjacent firms when the score is computed on data predating the labels." |
| §9 opener | "the most consequential disclosure for deployment claims" | "the most consequential disclosure for the screening reading" |
| §9.4 closing | "The construct's competitive position is therefore informational complementarity, not dominance... The administrative pathway in §11... the Screen stage runs on award records, the Forensic stage deploys bid-distribution methods" | "The relationship between the screening statistic and bid-distribution detectors is therefore informational complementarity rather than dominance... The architectural separation in §11 reads this as a two-stage enforcement structure: an award-layer screening stage that runs on contract-record data, and a bid-layer forensic stage that runs on the bid-distribution moment battery; the gain from sequencing the two is identifiable in the data and the two stages answer different questions." |
| §11.1 closing | "For the construct's intended use---prioritizing oversight case-load---this descriptive scope is sufficient: a screen needs to flag environments at higher prior risk than random selection would, on data the oversight body already holds." | "For the construct as a screening statistic on the award layer, this descriptive scope is sufficient: the screening object is the loser-side participation footprint where the cartel deploys it, not a counterfactual treatment effect on prices." |
| §11.2 (cover-bidder readings) | "build operational priors on competitor behavior" | "accumulate priors on competitor behavior" |
| §11.2 (adversarial closing) | "operational lifetime in any deployment requires periodic recalibration" | "the informativeness of the screening signal in any application of the construct requires periodic recalibration" |
| §11.2 (direct-defendant scope) | "A deploying oversight body that wants to identify cartel ringleaders directly will need a different tool" | "An enforcement program that requires firm-level membership identification will need a different statistic" |
| §11.3 portability prerequisites | "identifiable in any candidate jurisdiction before deployment" | "identifiable in any candidate jurisdiction" |
| §11.3 (BEC sample boundary) | "the BEC sample begins after the platform's operational stabilization" | "the BEC sample begins after the platform's initial stabilization" |
| §11.1 / §11.2 (oversight gradient) | "oversight gradient" / "procuring-unit-size oversight gradient" | "detection-regime gradient" / "procuring-unit-size detection-regime" |
| §4.2 (paragraph "Strict temporal validation") | "deployable triage trigger... discriminating reference we adopt for operational claims" | "the binary rule is the information-coarsening of the continuous primitive... AUC of $\valAUCFLfirmTemp$ is the conservative discriminating reference we use throughout the paper" |
| §4.2 (binary–continuous closing) | "We treat the binary rule as the deployable operational implementation and the continuous statistic as the discriminating instrument" | "The binary rule is the information-coarsening of the continuous primitive; we use the continuous statistic as the discriminating instrument and the binary rule as the discrete cut-off the screening framing flags" |
| §8.1 opener | "The deployable binary rule that defines frequent losers" | "The binary rule that defines frequent losers" |
| §8.1 closing | "We adopt the binary FL14 rule as the operational implementation throughout the paper because it is administratively interpretable" | "We use the binary FL14 rule as the discrete cut-off and the continuous statistic as the discriminating instrument" |
| §9.1 closing (threshold sensitivity) | "is the operational sweet spot between coverage and signal density" | "balances coverage and signal density" |
| §9.2 closing (leakage audit reference) | "operational-metrics audit in §9.3" | "temporal-holdout audit in §9.3" |
| §9.3 (in-sample column) | "We disclose the gap explicitly and operate on the temporal-holdout column" | "We disclose the gap explicitly and report headline metrics on the holdout column" |

### A.2 Table-level register fixes

| Table | Issue | Fix |
|---|---|---|
| `tab_operational_metrics` notes | "operationally honest projection... operational claims... operational deployment requires only contract-award records" + computational-cost editorializing | Notes rewritten in JLEO register: "generalization reference for the screening statistic"; "screening statistic requires only contract-award records"; computational-cost paragraph removed. |
| `tab_imhof_full` notes | "which is the operational claim of the paper" | Replaced with "which is the architectural claim of the paper: the screening stage operates on the data layer that survives most enforcement environments, and integrates with the bid-distribution forensic stage where microdata are available." |
| `tab_threshold_q3iqr` notes | "the operational rule used to discretize... while the binary FL rule is an administrative deployment choice" | "the rule used to discretize the underlying participation-count distribution... binary rule is its information-coarsening (§8.1)" |
| `tab_theory_operationalization` notes | "the binary FL rule as an administrative compression" | "the binary FL rule is its information-coarsening rather than a theoretically unique boundary" |

### A.3 Appendix Section A theory

- "above the operational threshold" → "above the threshold"
- "information-coarsening operational form" → "information-coarsening form"
- "binary frequent-loser rule" (deployable removed already in PART 6 sweep)

### A.4 Appendix section labels

- "Operational Metrics and Detector Comparison" → "Generalization Audit and Detector Comparison"
- "Operational lifetime depends on..." → "Practical lifetime depends on..."

---

## B. Issues found but not automatically fixed

### B.1 §9.3 inline `0.864` rendered alongside macro `\valAUCFLfirmTemp`

The §9.3 prose now uses `\valAUCFLfirmTemp` macros consistently, but `tab_operational_metrics.tex` carries the literal `0.864` inline in its table cells. The numbers match, but if a future re-estimation drifts the number, the table file would have to be regenerated by its source script (`scripts/42_operational_metrics.R + scripts/43_precision_at_k_audit.R`). Acceptable; flagged in `REPRODUCIBILITY_LINKING_MEMO.md` §2.2 and §5.2.

### B.2 §6.2 conservative-benchmark "$30$ firm-defendants, $210$, $108$" macros not yet emitted by upstream
The macros `\valConservativeFD`, `\valConservativeCobidders`, `\valConservativeFL`, `\valConservativeCases`, `\valConservativeCutoff` were added to `values.tex` and to `99_make_paper_values.R` in PART 6, but they sit in the hand-curated block at the script tail rather than being re-extracted from CSV at run time. Acceptable for a stable benchmark; flagged in `REPRODUCIBILITY_LINKING_MEMO.md` §5.1.

### B.3 The label `app:operational` (Appendix~E) is a leftover label name

The appendix section was renamed in PART 7 from "Operational Metrics" to "Generalization Audit and Detector Comparison", but the LaTeX label remained `app:operational` to avoid breaking cross-references. This is invisible to the reader but a copy-edit pass might wish to rename to `app:generalization` and update all `\ref{app:operational}` callers. Out of scope for this audit; flagged.

### B.4 The `tab_operational_metrics` filename is also a leftover

Same logic as B.3: file is at `output/tables/tab_operational_metrics.tex` and `\input{...}` paths in `sec_appendix_v15.tex` still point to it. Renaming would touch the table-emission scripts (`scripts/42`, `scripts/43`). Out of scope; flagged.

### B.5 Three rendered occurrences of `261.6` vs one rendered occurrence of `261.64` (in `tab_oster_delta`)

Body prose uses `\valOsterDelta = 261.6` (3 occurrences); the `tab_oster_delta.tex` table cell still renders the inline `261.64` value the underlying script emitted. The values agree to one decimal place; the discrepancy is rounding only. Flagged in `REPRODUCIBILITY_LINKING_MEMO.md` §6 with mitigation: future binding of `tab_oster_delta` cells to `\val*` macros that round consistently with `\valOsterDelta`.

---

## C. Numerical consistency checks — final

| Symbol | Macro | Rendered occurrences (rounded down) |
|---|---|---|
| 2,735 (`\valFL`) | bound | 6 |
| 16,843 (`\valAlwaysLosers`) | bound | 5 |
| 41,444 (BEC participants) | inline literal in §6.1 table | 2 (only place needed) |
| 193 (`\valCobidders`) | bound | 15 |
| 47 (`\valDirectCADE`) | bound | 6 |
| 1,673,837 (`\valSampleN`) | bound | 4 |
| 0.748 (`\valAUCprePost`) | bound | 5 |
| 0.864 (`\valAUCFLfirmTemp`) | bound | 12 |
| 0.924 (`\valAUCFLfirm`) | bound | 11 |
| 0.911 (`\valAUCFLBinSameSample` + `\valHorseAUCBin`) | bound | 5 |
| 0.939 (`\valAUClogtc` + `\valHorseAUCCont`) | bound | 4 |
| 0.491 (`\valAUCdirectStd`) | bound | 6 |
| +3.6%–+7.7% (`\valHeadlineRange`) | bound | 9/8 |
| −9.72% (`\valMatchOverlapCoef`) | bound | 6 |
| −30.67% (`\valMatchPSCoef`) | bound | 6 |
| 12.6× (`\valPBUgradientRatio`) | bound | 5 |
| 261.6 (`\valOsterDelta`) | bound | 3 |
| +0.0653, +0.0188, −0.0746 (horse-race coefs) | bound (`\valHorseFLOne` etc) | 3 each |
| −0.097, −0.307 (overlap-restricted ATTs) | bound (`\valScopeOverlapCoef` etc) | 5/3 |
| 0.2138, 0.0111, 0.0660, 0.0165 (quartile coefs) | bound (`\valOversightQ*Coef`) | 1 each (table only) |
| +0.0959, +0.0392 (modal coefs) | bound (`\valFalBinPregCoef` etc) | 2 each (table + prose) |
| 0.062 (`\valExclCADECoef`) | bound | 1 |

All headline numbers are macro-bound and consistent across the manuscript and appendix. No drift detected.

---

## D. Claim-discipline checks — final

After PART 7 the manuscript contains zero rendered occurrences of:

- `triage` (was the central old framing word; gone)
- `deployable` / `deployable triage` (gone)
- `operational claim` / `operationally honest` (gone)
- `oversight body` / `oversight bodies` (gone — the construct is no longer addressed to a specific actor)
- `administrative pathway` / `administrative deployment` (gone)
- `operational lifetime in any deployment` (replaced)

Remaining `operational` rendered occurrences are all conceptual or technical:

| Phrase | Where | Acceptable? |
|---|---|---|
| "operational logs" | §1, §3 (BEC platform's archival layer) | Yes — descriptive of the actual bit of infrastructure |
| "operational coarsening" | §1 | Yes — JLEO register, refers to the data-layer transformation |
| "binary operationalization" | §1 roadmap | Yes — econometric register |
| "BEC operational system" | §3 | Yes — actual name for the BEC bit |
| "operational records that survive" | §3 | Yes — descriptive |
| "operational cartel activity" | §3 | Yes — describes cartel period |

Remaining `deployment` rendered occurrences are all about the cartel's deployment problem (mechanism design register), which is the JLEO-correct usage:

| Phrase | Where |
|---|---|
| "the cartel's deployment problem" | §5.1, §6.2 |
| "the deployment distribution" | §5.1 |
| "the deployment optimum / sorting" | §5.1, §7.1, §7.2 |
| "deployment of cover bidders" | §6.2, App A |
| "stationary deployment process" | App A |
| "deployment counting process" | App A |

All correct under the JLEO frame.

---

## E. Title / abstract / conclusion alignment — final read

### Title
> *Screening Under Incomplete Observability: Equilibrium Loser-Side Participation as an Award-Layer Signal of Cartel Activity*

### Abstract opening
> *Cartel-screening methods in the empirical literature presuppose bid-level observability. In many enforcement environments only the contract-award layer survives, and the question of what collusion-relevant information remains under that coarsening is open.*

### Abstract closing
> *The exercise locates the construct as cartel-adjacency evidence under coarsened observability, separates an award-layer screening stage from a bid-layer forensic stage, and frames the heterogeneity across buyer size as variation in the detection regime rather than as identification of an institutional channel.*

### Introduction first paragraph
> *The empirical literature on cartel detection has converged on methods that read collusion off the distribution of submitted bids... Real enforcement environments rarely match this informational benchmark.*

### Introduction last paragraph (Scope)
> *We claim that the participation primitive identified by the framework carries collusion-relevant information that survives the coarsening from the bid layer to the award layer; that the screening-value interpretation makes the sign reversal under overlap restrictions diagnostic rather than confounding; and that the construct discriminates a structurally appropriate cartel-adjacency object at rates well above random matching at comparable participation volume.*

### Conclusion last paragraph
> *Wherever an enforcement environment exposes the award layer without exposing the bid layer, the question is not whether bid-distribution screens can be retrofitted but what participation primitive the collusive arrangement generates that survives the coarsening, and how the screening stage that reads that primitive should be sequenced before the forensic stage that requires bid-level evidence.*

The title, abstract opener, abstract closing, intro first paragraph, intro scope paragraph, and conclusion last paragraph all sit in the same JLEO register. The vocabulary is consistent (incomplete observability / data coarsening / award layer / bid layer / screening stage / forensic stage / loser-side participation / cartel adjacency). Three concrete claims appear in all three sections: (i) what survives data coarsening; (ii) the architectural separation between screening and forensic stages; (iii) cartel adjacency as the appropriate validation object.

No promotional or operational drift detected.

---

## F. Top 5 remaining vulnerabilities for JLEO

### V1. The screening-value vs treatment-effect distinction is the paper's central interpretive bet
The reframing in PART 4 reads $\beta$ and $\beta^{\text{ov}}$ as different empirical objects rather than as alternative estimates of the same parameter. A skeptical referee may push for evidence that this is a substantive interpretive claim rather than a relabeling of an apparent identification failure. Three structural mitigations exist in the paper: (i) the framework predates the empirical exercise and predicts the deployment sorting that the overlap restriction strips; (ii) cartel-adjacency validation is independent of the broad-sample price coefficient and corroborates the screening reading; (iii) the continuous-dose dominance is a model-predicted pattern that pure-confound readings of $\beta$ do not predict. Whether a JLEO referee accepts these as sufficient is the paper's central open question. **Severity:** high. **Mitigation in body:** explicit; cannot be improved further without changing the empirical design.

### V2. The architectural claim about screening vs forensic stages does not have a dedicated section
The abstract and intro promise a screening-stage / forensic-stage architecture; §11 conclusion ¶4 states it as an implication; §9.4 has the empirical evidence (Imhof comparison) but is labeled as a "robustness" subsection. There is no dedicated §10 "Screening vs Forensic Stages". A JLEO referee may read the architectural claim as undersold given its prominence in title, abstract, and conclusion. The editorial map (`JLEO_EDITORIAL_MAP.md` §4) proposed a dedicated §10; PART 7 did not create it. **Severity:** medium. **Mitigation if a referee asks:** promote §9.4 to a standalone §10 with its current content, no new evidence required.

### V3. Buyer-size gradient is reframed but still under-identified
"Detection-regime variation" is the JLEO-register reading of the buyer-size gradient. The reframe is structurally correct but a JLEO referee may push for evidence that the regime variation is what is measured rather than confounded institutional features (officer tenure, audit infrastructure, item composition, discretionary procedure use). The paper now disclaims the channel identification explicitly — but the reframe makes the disclaim more visible than the JPART version. **Severity:** medium. **Mitigation in body:** explicit disclosure throughout §7.3, §11.1, and tab_regime_oversight notes.

### V4. The framework in Online Appendix A does heavier conceptual work than its formal content
The screening framing in §1, §5, §7.2, and §9.3 references the framework's deployment problem to justify reading the deployment sorting as constitutive rather than confounding. The framework's lemma + 2 propositions are technically correct but minimalist; they identify the participation primitive and characterize the comparative static, but they do not formally model the source of the unobserved heterogeneity that drives the deployment sorting. A JLEO referee may push for a more developed model, particularly the link between the deployment problem and the unobservables. **Severity:** medium-high. **Mitigation in body:** the framework is honest about being an organizing device; if a referee asks for a more developed model, this is a reasonable major-revision response.

### V5. Cobidder labels are indirect by construction
The validation defends cobidders as the structurally appropriate validation object given the data layer. A JLEO referee who refuses indirect labels will reject regardless of the corroborating evidence. The paper's defense is structural (the screening statistic is *designed* to recover loser-side participation, and cobidders are the loser side) and empirical (the asymmetry between cobidder AUC $\valAUCFLfirm$ and direct-defendant AUC $\valAUCdirectStd$ is the design's empirical signature). No further evidence will fix this. **Severity:** medium. **Mitigation in body:** stated four times across abstract / §1 / §6 opening / §11.2; the structural defense is clear.

---

## G. Final recommendation

**The paper now reads as JLEO-facing.** Title, abstract, introduction, related literature, institutional setting, empirical strategy, validation, results, mechanism heterogeneity, robustness, limitations, and conclusion all sit in the same JLEO register. The vocabulary is consistent (incomplete observability / coarsened data / award layer / bid layer / screening stage / forensic stage / loser-side participation / cartel adjacency / equilibrium deployment / detection regime). The screening-value-vs-treatment-effect distinction is the load-bearing interpretive claim and is articulated in three independent places (§5.1, §7.2, §11). The cartel-adjacency validation is anchored on the conservative pre-2020 benchmark and supported by the temporal-holdout generalization audit. The architectural claim about screening and forensic stages closes the conclusion.

The paper is not perfect: V2 (no dedicated §10) is the most visible structural gap, V1 (screening-value interpretation) is the most consequential interpretive bet, and V4 (framework depth) is the most likely future-revision item. None of these are JPART/JPAM problems; they are JLEO-internal questions that a serious referee would raise.

**Recommendation:** the paper is ready to submit to JLEO as the v19 draft. If the editorial team wants one further round before submission, the highest-leverage item is V2 (promote §9.4 content into a dedicated §10 "Screening vs Forensic Stages"); the second-highest is V4 (light expansion of Online Appendix A's framework, particularly the link between deployment sorting and unobservables). Both are major-revision items if a referee requests them; neither is required to make the paper coherent under the JLEO frame as it stands.

The paper has fully shed its JPART/JPAM identity. A JLEO referee reading the v19 draft cold will encounter a paper about screening under incomplete observability, with procurement as the empirical setting, not the identity. That was the goal of the JLEO reframe.

---

*End of audit. v19 final.*
