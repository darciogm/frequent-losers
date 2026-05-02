# JLEO Empirical-Object Reframe Memo — Paper 3 (v19, PART 4a)

**Status:** §5 (Empirical Strategy) and §7 (Main Results §7.1–§7.3) rewritten so that the broad-sample and overlap-restricted estimates are explicitly framed as two distinct empirical objects, and the sign reversal becomes the diagnostic that locates the construct as a screening-value object. PDF compiles at 44 pp.
**Files touched:** `sec5_emp_v15.tex`, `sec_results_v15.tex`.

---

## 1. The two empirical objects, named

Under the screening framing, the paper now distinguishes:

### Object 1: $\beta$ — the broad-sample conditional association
- The within-cell mean difference in $\log p_{\text{negotiated}}$ between tender-items that include at least one frequent-loser participant and otherwise comparable items in the same product code, year, and procuring unit.
- Estimated on $\valSampleN$ items, bracketed by four estimators (OLS, cross-fit, CEM, IPW), conditional range $\valHeadlineRange$.
- **What it is:** the empirical content the construct is designed to recover — the conditional association at the items where frequent losers actually deploy, integrated over the cartel's deployment distribution.
- **What it is not:** a treatment-effect estimate. We do not claim $\beta$ would survive a counterfactual that reweights items to remove the deployment sorting. Under the screening framing that question is not the relevant one.

### Object 2: $\beta^{\text{ov}}$ — the overlap-restricted association
- The within-support comparison computed at the subsample where treated and control populations genuinely overlap on observables. Two implementations: overlap-cell ATT $\valMatchOverlapCoef$, propensity-score-trimmed ATT $\valMatchPSCoef$.
- **What it is:** the within-support comparison at the cells where the treated and control populations look alike on observables, computed by holding the participation footprint fixed at that subsample. The estimand a treatment-effect framing would target.
- **What it is not:** a sharper version of $\beta$. It is a different empirical object that answers a different question.

---

## 2. How $\beta$ is now interpreted

| Element | Treatment-effect framing (rejected) | Screening framing (adopted) |
|---|---|---|
| What $\beta$ measures | Average price differential between treated and control items, holding observables fixed | Conditional association at the items frequent losers actually deploy in, integrated over the deployment distribution |
| Status of deployment sorting | A confound to be matched, weighted, or instrumented away | Constitutive of the empirical object — the deployment is the equilibrium response to unobserved incentives the framework characterizes |
| Diagnostic for $\beta$ | Sensitivity bounds (Cinelli/Oster), overlap-restricted matching, IV | Sensitivity bounds (Cinelli/Oster) bound selection on observables already absorbed by the FE; overlap-restricted matching delivers a *different empirical object* $\beta^{\text{ov}}$, not a sharper version of $\beta$; IV reads classical attenuation in the binary indicator |
| Failure mode | Overlap-restricted estimate reverses sign → causal-effect interpretation collapses | Overlap-restricted estimate reverses sign → diagnostic that the broad-sample object carries content the within-support object discards |
| What $\beta>0$ means | Treated items are causally costlier than matched controls | Items where the cartel deploys frequent losers carry a positive screening signal in negotiated prices |

The screening framing does not require $\beta$ to be defended against the standard treatment-effect-identification critique; under that framing, the question of whether $\beta$ would survive a counterfactual that strips deployment sorting is not the relevant question.

---

## 3. How $\beta^{\text{ov}}$ is now interpreted

| Element | Old framing (sign-reversal-as-failure) | New framing (different-object) |
|---|---|---|
| Role | Robustness check for $\beta$ | Different empirical object answering a different question |
| What its sign tells us | Whether $\beta$ survives matching → if reverses, $\beta$ collapses | Whether the cartel deploys cover bidders preferentially in items that look observably different from non-deployment items → if reverses, deployment sorting is informative |
| Why we report it | To pass a robustness threshold | To instantiate the alternative empirical object whose contrast with $\beta$ identifies the screening-value interpretation |
| Diagnostic value of the reversal | Negative (signals failure) | Positive (signals presence of equilibrium sorting that generates the screening content) |

We do not claim $\beta^{\text{ov}}$ is wrong; we claim it answers a different question. Under a treatment-effect framing $\beta^{\text{ov}}$ is the relevant estimand. Under the screening framing $\beta$ is the relevant object, and $\beta^{\text{ov}}$ provides the diagnostic that the deployment sorting is non-trivial.

---

## 4. Why the screening framing is more JLEO-consistent

### 4.1 The framework does the work
Under JLEO standards, the framework needs to deliver more than ornamentation. The screening framing makes the framework load-bearing: the separating equilibrium identifies $\log(1+\text{tc})$ as a sufficient ranking statistic, identifies $\text{wins}=0$ as a separating choice, and characterizes the cartel's deployment problem as the source of the endogenous sorting. The empirical object reads against the framework's deployment distribution rather than against a counterfactual support — that is what links theory to evidence in a JLEO-recognizable way.

### 4.2 The sign reversal becomes evidence rather than a vulnerability
The treatment-effect framing positions the sign reversal as a failure that the paper has to explain away. The screening framing reads it as positive evidence of the equilibrium sorting the framework predicts: the cartel deploys cover bidders in environments that differ systematically from the non-deployment environments, and that deployment is informative. The paper now uses three independent corroborations (cartel-adjacency validation; continuous-dose dominance over binary; selection-on-observables sensitivity bounds) to support the screening reading rather than the confound reading.

### 4.3 Cartel adjacency is the appropriate validation object under coarsened observability
Under a treatment-effect framing the appropriate validation would be against direct cartel members, and the AUC of $\valAUCdirectStd$ against direct CADE defendants would be a failure. Under the screening framing the appropriate validation is against cobidders — the population the screening statistic is designed to recover — and the asymmetry between $\valAUCFLfirm$ (cobidders) and $\valAUCdirectStd$ (direct defendants) is the design's empirical signature, not a failure. The screening framing makes the validation discipline explicit.

### 4.4 The architectural claim of §10
The JLEO contribution is not "we have a deployable triage tool" but "an award-layer screening stage and a bid-layer forensic stage answer different questions about coordinated bidding". Under the treatment-effect framing the paper does not have an architectural claim because the empirical object is local to a within-support subsample. Under the screening framing the empirical object is precisely what the screening stage produces, and §10 (the new section in the editorial map) compares it to the bid-distribution forensic stage on the same cases. The screening framing is what makes §10 a coherent closing rather than a robustness footnote.

### 4.5 The buyer-size gradient becomes informativeness across detection regimes
Under the treatment-effect framing the buyer-size gradient is mechanism heterogeneity that the paper struggles to identify causally and ends up disclaiming. Under the screening framing the gradient is heterogeneity in the screening object across the monitoring environment — informativeness of the screen across detection regimes. The framework's $\partial m^*/\partial \theta_k < 0$ comparative static is observationally consistent with this gradient, and the gradient is read as evidence that the screening signal varies with the enforcement environment. The vocabulary is JLEO-native (monitoring environment, detection regime) and the empirical content does not require a channel-identification claim that the design cannot deliver.

---

## 5. What we explicitly did not do

- **We did not pretend the problem disappears.** The sign reversal is real, large, and reported in the body. The screening framing reinterprets it; it does not hide it.
- **We did not make causal claims.** Neither $\beta$ nor $\beta^{\text{ov}}$ is a causal estimate. The paper's contribution is the screening-value interpretation of the broad-sample object, not a causal estimate of cover-bidding's effect on prices.
- **We did not weaken the failed-design honesty.** The two design-based strategies (RDD, DiD) that return null are still reported in §5.1 with the same diagnostic detail (McCrary $\valMcCraryRatio$ and $\valMcCraryDisc$, parallel-trends failure for the 2018 Decreto). The screening framing does not require their success — but their failure also does not undermine the screening framing, because the screening framing does not require a causal identification of $\beta$.
- **We did not change a single number.** All literals are macro-bound and unchanged. The reframe is interpretive throughout.

---

## 6. Specific edits made

### §5 Empirical Strategy

| Subsection | Change |
|---|---|
| §5.1 (renamed *"The Empirical Object: Screening Value Under Coarsened Observability"*) | Rebuilt around the two-objects distinction. Opens with the conceptual statement that the empirical object is the screening value of endogenous loser-side participation, not a treatment effect. Introduces $\beta$ and $\beta^{\text{ov}}$ as paired objects. Explains why the screening framing privileges $\beta$ and the treatment-effect framing privileges $\beta^{\text{ov}}$. Frames the sign reversal as the empirical signature of the distinction between the two. The two failed design-based strategies (RDD, DiD) are kept and explicitly noted as not constraining the screening interpretation. |
| §5.2 Reduced-Form Specification | Equation unchanged. Clarifies that the four estimators bracket the broad-sample object $\beta$ under the screening framing, not a treatment-effect target. The IV is described as a measurement-error diagnostic for the binary indicator, not as a causal estimate. |
| §5.3 (new — Identification Audits as Screening-Value Diagnostics) | Reorganized so that each audit answers a question about the screening object. Cinelli/Oster bound selection-on-observables explanations of $\beta$. Strict-overlap matching delivers $\beta^{\text{ov}}$ as the alternative empirical object. The leakage audit is a generalization diagnostic for the screening statistic. The placebo is a specification diagnostic for the participation primitive. |
| §5.4 Heterogeneity (renamed) | Buyer-size gradient now read as heterogeneity in the screening object across the monitoring environment; cell-heterogeneity grid as descriptive scope of the screening object. |

### §7 Main Results

| Subsection | Change |
|---|---|
| Opener | Three-move structure announced explicitly: $\beta$ (§7.1), $\beta^{\text{ov}}$ and the screening-value diagnostic (§7.2, *new dedicated subsection*), heterogeneity across detection regimes (§7.3). |
| §7.1 (*"Broad-Sample Conditional Association ($\beta$)"*) | Renamed and restructured. Presents the four-estimator bracket under the screening-framing register. Pregão–convite contrast retained as informativeness across observability regimes. Closing paragraph states explicitly that $\beta$ is the construct's empirical content, not a treatment-effect estimate, and that the relevant question for what follows is whether the deployment sorting is informative — not whether $\beta$ would survive its removal. |
| §7.2 (*"Overlap-Restricted Association ($\beta^{\text{ov}}$) and the Screening-Value Diagnostic"*, new dedicated subsection) | Built around `tab_item_level_scope_match` (now `\input{}`-ed in main text). Names the overlap-cell ATT and the PS-trimmed ATT as the two implementations of $\beta^{\text{ov}}$. States that $\beta$ and $\beta^{\text{ov}}$ are different objects, not the same object computed two ways. Lists three pieces of independent corroboration for the screening reading over the confound reading: (i) cartel-adjacency validation moves with $\beta$; (ii) continuous-dose dominance; (iii) sensitivity bounds. Closes by reporting both objects in parallel. |
| §7.3 (*"Heterogeneity Across Detection Regimes"*, renamed) | Buyer-size gradient unchanged in evidence but reframed in JLEO register: heterogeneity in the screening object across the monitoring environment; framework comparative static observationally consistent; no causal-channel identification claim. |

---

## 7. Risks introduced or sharpened

### R13. The screening framing may read as ad hoc
A skeptical referee may read the screening framing as an ex post rationalization of an empirical pattern that does not survive matching. Three structural answers in the body: (i) the framework predates the empirical exercise (Online Appendix~A), so the screening object is not invented to fit the data; (ii) the cartel-adjacency validation is independent of the broad-sample price coefficient and corroborates the screening reading; (iii) the continuous-dose dominance is a model-predicted pattern (sufficient ranking statistic), and pure-confound readings of $\beta$ do not predict it. Whether a referee accepts these as sufficient is the open question.

### R14. The two-object framing makes a stronger claim than "robustness check"
The old framing ("we report $\beta^{\text{ov}}$ as a robustness check on $\beta$") was apologetic but defensible. The new framing ("$\beta$ and $\beta^{\text{ov}}$ are different empirical objects") is more committed. A hostile referee may read the new framing as an attempt to escape the standard identification critique by relabeling the question. We accept this risk because the alternative (defending $\beta$ as a treatment-effect estimate) is unworkable given the sign reversal, and because the screening framing is what the framework actually delivers.

### R15. The framework now carries more weight than its proofs
The screening framing relies on the framework's deployment problem to justify reading the deployment sorting as informative rather than as confound. The framework in Online Appendix~A is technically correct but deliberately minimal. PART 5 may need to expand the framework slightly — particularly the link between the deployment problem and the unobservables that drive the deployment sorting — or, alternatively, accept a referee push for a more developed model and concede this as future work.

### R16. The "different empirical objects" register may be unfamiliar to applied readers
Some applied-econometrics readers will read $\beta$ and $\beta^{\text{ov}}$ as the same parameter computed under different assumptions. The body now explicitly names them as two objects; the reader has to accept this or reject the framing wholesale. A milder version of this risk would be to call them $\beta_{\text{broad}}$ and $\beta_{\text{ov}}$ and emphasize the framing in subscript. We left them as $\beta$ and $\beta^{\text{ov}}$; the framing is in the prose, not the notation. Subject to PART 5 revisitation if it reads as confusing in a final read-through.

### R17. The architecture promised by the abstract still requires §10
The abstract and intro promise a screening-vs-forensic-stage architectural claim. §5 and §7 now deliver the screening-stage half. The forensic-stage comparison (Imhof–Wallimann) currently lives in the appendix and §9.4. PART 4b or PART 5 must promote it to a dedicated §10 to close the architectural loop. This is the single highest-priority follow-through item from PART 2.

---

## 8. Word counts and PDF impact

| Section | Before (post-PART 3) | After (PART 4a) | Δ |
|---|---|---|---|
| §5 Empirical Strategy | ≈680 | ≈1,020 | +50% |
| §7 Main Results | ≈540 | ≈790 | +46% |
| Main PDF | 40 pp | 44 pp | +4 pp |

The growth is substantive: the screening framing requires explicit articulation, and the two-object structure cannot be expressed as compactly as the old "we treat the empirical content as descriptive" line. PART 5 will compress §6 (Validation) and §8 (Mechanisms) to recover some of this cost, but the body length will likely close at 42–43 pp rather than 38 pp. Acceptable for JLEO.

---

*End of memo. PARTs 4b/5 still pending: §6 Validation reframe, §8 Mechanisms recast, new §10 Screening vs Forensic Stages, §11 Limitations + §12 Conclusion in JLEO register, full reproducibility audit.*
