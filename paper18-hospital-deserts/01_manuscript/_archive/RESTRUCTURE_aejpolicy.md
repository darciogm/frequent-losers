# Restructure brief — Paper 18 → AEJ:Policy

**Status:** draft spine for author approval. Canonical `.tex` untouched until approved.
**Date:** 2026-06-07. **Diagnostic basis:** health-outcome gate + PNASH power test + 2010–2014 pre-period backfill (scripts D1–D4, `*_ext` panels). All mortality numbers are population-weighted Sun-Abraham on the PNASH-anchored psychiatric-closure sample with real (backfilled) pre-periods.

---

## 1. The one-sentence test (corridor recount)

> *When psychiatric hospitals closed under Brazil's deinstitutionalization reform, the feared mortality catastrophe did not occur among the patients who actually depended on them — a population that distance-based exposure, the closure literature's standard, systematically misidentifies.*

Two load-bearing claims, one paper: a **measurement** fix (who is exposed) and a **policy** answer (what happened to them). The measurement makes the null credible; the null makes the measurement matter.

## 2. Headline number (one, with a palco)

**The exposed population's suicide mortality did not rise: +0.28 per 100,000 (95% CI [−0.7, +1.3]), ruling out the increases above one-quarter of baseline that critics of deinstitutionalization predicted.** Same value, same sample, same units in abstract, p.1, and conclusion. The measurement statistic (distance misclassifies 293 of 337 municipality–closure pairs; verified from exposure_panel — the old draft's "495" was a bug) is the supporting cast, not a second headline.

## 3. Title (claim, not description)

**Primary:** *Closure Without Catastrophe: Patient-Flow Exposure and the Mortality Effects of Psychiatric Deinstitutionalization in Brazil*

**Sober alternative (if AEJ:Policy editor prefers):** *Who Is Exposed When a Hospital Closes? Patient-Flow Measurement and the Mortality Effects of Brazil's Psychiatric Reform*

(Drops "embedding" from the title entirely — it was the single biggest desk-reject risk. Node2vec is demoted to an appendix measurement diagnostic.)

## 4. Section architecture (what each current section becomes)

| New § | Content | Built from |
|---|---|---|
| 1. Introduction | 5 movements (below). Policy question first, measurement as the tool, null as the answer. | rewrite of `introduction.tex` |
| 2. The Reforma Psiquiátrica and SUS closures | Institutional setting: Lei 10.216/2001, PNASH inspection cycles, reimbursement freeze → exogenous institution-level closures. The contested mortality fear is the paper's hook. | `setting.tex` (tighten, lead with the policy stakes) |
| 3. Data | SIH (flows), SIM (mortality, residence), CNES (closures), IBGE pop **2010–2024** (backfilled — now states full window). | `data.tex` + note backfill |
| 4. Measuring exposure: flow vs distance | E1 share-based exposure vs E2 distance placebo. The 97/196/293 misclassification + divergence map (Figure 1). Embedding → one paragraph + appendix. | `method.tex` §4.1–4.2 collapsed |
| 5. Identification | Staggered Sun-Abraham; the three assumptions; PNASH-anchoring as the exogeneity argument; **parallel-trends now tested on real 2010–2024 pre-periods**. | `method.tex` §4.4 + `results.tex` PT block |
| 6. Results | (a) First stage: travel −7.10 km (E1 captures real far-dependence). (b) **Headline: mortality null** (suicide, self-harm) with bounds. (c) Transparent non-result: ICSAP pre-trend rejects → declined as causal. | `results.tex` rebuilt around mortality |
| 7. Robustness | Sample (spec07/pnash48/psymax60), weighting (OLS/WLS both null), estimators (SA/CS21/BJS), threshold sweep, capitals, pandemic. | `robustness.tex` (mortality-focused) |
| 8. Discussion / Policy | What a credible null means for deinstitutionalization debates; the measurement lesson for closure studies in single-payer systems; scope and limits (bounded null, SUS-only, N). | `discussion.tex` reframed |
| 9. Conclusion | Restate the one sentence + headline. | `conclusion.tex` rewrite |

**Cut/demote:** node2vec embedding → appendix; causal forest → appendix (marginal); counterfactual perturbation → appendix; LLM motive classifier → robustness only (external validation still pending — keep honest). ICSAP → demoted to a transparently-reported non-result, NOT a headline.

## 5. Figure 1

The divergence map (`fig_map_divergence`) — stands alone: red = flow-isolated (patients bypass the near hospital), blue = river/air access distance misses. Caption self-contained. It IS the measurement contribution in one image.

---

## 6. Draft abstract

> Critics of psychiatric deinstitutionalization warned that closing hospitals would raise patient mortality. Evaluating this claim requires knowing which populations actually depended on a closing hospital — and in systems where patients cross municipal borders for specialized care, the distance-based exposure rule standard in the closure literature misidentifies them. Across 60 exogenous closures of Brazilian SUS hospitals during 2010–2024, distance misclassifies treatment for 293 of 495 municipality–closure pairs: it misses 97 municipalities that depended on the closing hospital through specialized referral and falsely treats 196 that did not. We replace it with a patient-flow exposure rule built from 179.5 million SUS admissions and estimate effects with a staggered Sun-Abraham event study, anchoring closure exogeneity to the federal PNASH inspection calendar and the SUS reimbursement freeze. A first-stage validation confirms the flow rule captures real dependence: travel burden falls 7.1 km after closure, where a distance rule recovers only half as much. For the feared outcome, we find no harm. Suicide mortality among the exposed population changes by +0.28 per 100,000 (95% CI [−0.7, +1.3]) — ruling out the increases above one-quarter of baseline that critics predicted — with parallel pre-trends that hold on backfilled 2010–2024 data; self-harm mortality is likewise null. We are transparent about a limit: preventable hospitalizations were already trending upward in exposed municipalities before closure, so we decline to read them causally. The catastrophe predicted for Brazil's psychiatric reform does not appear in the mortality of the populations that actually bore the closures — populations a distance-based analysis would not have found.

(196 words. JEL: I18, I14, I11, H75. Keywords: hospital closures, deinstitutionalization, patient-flow exposure, mortality, staggered difference-in-differences, SUS, Brazil.)

---

## 7. Draft introduction (5 movements)

**M1 — the policy stakes + the measurement problem.** Deinstitutionalization is one of the most contested health reforms of the past half-century; its critics predicted that closing psychiatric beds without adequate community substitutes would raise suicide and self-harm. Testing this requires identifying who depended on a closing hospital. The closure literature defines exposure by geographic proximity, but in single-payer systems patients cross borders for specialized care that no nearby facility provides — so proximity mismeasures dependence. Concrete example (the CNES 2082683 psychiatric closure: 2,331 pre-closure admissions across 20 municipalities, 16 of them 36–107 km away, invisible to any top-3 distance rule). The choice of exposure measure is not a technicality: it determines whether the population the policy actually touched enters the estimate at all.

**M2 — the flow exposure rule, validated.** A municipality is exposed to a closure if pre-closure admissions to the closing hospital exceeded a 5% share of its total — flow dependence, not proximity. Across 60 closures, distance and flow disagree on 293 of 495 municipality–closure pairs (97 missed, 196 false), concentrated in the river-corridor North and semi-arid Northeast (Figure 1). The flow rule is validated by a first stage: travel burden falls 7.1 km after closure (a distance rule recovers half), direct evidence that exposed patients had been traveling far for care with no local substitute. (Node2vec embedding of the flow network appears in Appendix X as a measurement diagnostic; it does not drive the causal design.)

**M3 — identification.** Staggered Sun-Abraham on the psychiatric closures, exogeneity anchored to the PNASH federal inspection cycles and the SUS reimbursement freeze (institution-level, not local-demand, timing). Three assumptions stated; parallel trends now tested on **backfilled 2010–2024 pre-periods** (the binding earlier-data gap is closed). Mortality recorded at municipality of residence.

**M4 — the result: no catastrophe.** Population-weighted suicide mortality among the exposed: +0.28 per 100,000 [−0.7, +1.3], parallel pre-trends holding (p=0.26); self-harm null. We rule out the >25% increases critics predicted; we cannot rule out small effects, and say so. The null is robust across exposure samples, weighting, estimators, and the threshold sweep.

**M5 — honesty, contribution, roadmap.** The transparent non-result: preventable hospitalizations (ICSAP) were already rising in exposed municipalities before closure (pre-trend rejects on the real pre-periods) — we report the trajectory and decline the causal claim rather than launder it. Contributions: (i) a portable patient-flow exposure measure for closure studies in single-payer systems, validated against a mechanical first stage; (ii) a credibly-identified mortality null on a globally contested reform, on the population that distance-based analysis would have missed. Roadmap.

---

## 8. Honest odds + open issues for the author

- **P(R&R) AEJ:Policy ≈ 20–30%.** A credible null on a major contested policy + a measurement contribution is their taste, but: the bound is moderate (~25%, not a tight zero), N is modest, SUS-only. Not a slam dunk; the best realistic Tier-1 target.
- **OLS vs WLS divergence** must be addressed head-on (effect concentrated in/diluted by small municipalities). WLS = policy-relevant (per affected person); OLS robustness. Both null — that is the defense.
- **PNASH exogeneity is an argument, not an instrument.** Frame honestly; the reimbursement freeze + inspection calendar is institution-level but not randomized.
- **Re-confirm 97/196/293** against `exposure_panel.parquet` during the rewrite (unchanged by this diagnostic, but cite-check).
- **Sample choice:** pnash48 (PNASH-anchored, cleanest PT) primary; spec07 (41) and psymax60 (60) as robustness. State one primary, avoid the multi-number sample confusion.
