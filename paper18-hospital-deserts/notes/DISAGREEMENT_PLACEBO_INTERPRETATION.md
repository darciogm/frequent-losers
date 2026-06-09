# Disagreement-placebo interpretation (branch `paper18-disagreement-placebo`)

Exposure-validation placebo: split the flow-vs-distance disagreement set into
flow-only / distance-only / both and estimate the first stage separately, against
never-flagged controls. Read mechanically and honestly below.

## The eight questions

1. **Does flow-only show a travel-burden first stage?** Yes. PNASH ATT −6.57 km
   (CI [−10.7, −2.4], pre-trend p=0.07, marginal); F5 ATT −5.47 (p=0.16). Travel falls.

2. **Does flow-only show a psychiatric-admissions first stage?** Yes, and this is the
   cleanest result. PNASH ATT −3.74 per 1,000 (CI [−4.5, −3.0]), **flat pre-trends
   (p=0.30)**. Flow-flagged municipalities lose inpatient psychiatric volume.

3. **Does distance-only behave like controls?** **No — not cleanly.** It moves:
   travel −4.32, admissions −0.95 (CI excludes zero). BUT every distance-only
   pre-trend FAILS (p=0.00), so its movement is not a clean closure response — these
   municipalities sit on differential pre-trends. Two distinct readings by outcome:
   - **Travel burden does NOT discriminate**: distance-only −4.32 ≈ flow-only −6.57.
     Travel shifts mechanically for any municipality near a closing hospital, so this
     outcome cannot separate true from false positives. Do not lead with it.
   - **Psychiatric admissions discriminates**: distance-only −0.95 is one-quarter of
     flow-only −3.74, and its pre-trend fails. Admissions is the right outcome because
     only municipalities that actually used the hospital can lose admissions.

4. **Does both show a first stage?** Yes, strongest (psych −8.87, travel ~0/noisy),
   but pre-trends are uncomputable/contaminated for several both specs (small group,
   n=27; one F5 VCOV blew up). Directionally consistent, statistically fragile.

5. **Are pre-trends acceptable?** Flow-only: yes (psych p=0.30; travel p=0.07–0.16).
   Distance-only: **no, all fail (p=0.00)**. Both: mixed/uncomputable.

6. **Cleaner in PNASH or F5?** PNASH **psychiatric admissions** is the cleanest
   discriminator. F5 **travel burden does not discriminate** (distance −4.71 ≈ flow
   −5.47). So the validation rests on PNASH psychiatric admissions, not on travel.

7. **Main text / appendix / not at all?** → **Appendix (full diagnostics), with at
   most a nuanced one-sentence main-text mention.** This is the spec's *middle*
   decision rule (flow-only strong, distance-only modestly nonzero), sharpened by the
   pre-trend contrast. **Do NOT** add the bold intro sentence (G) or the bold §5.1
   claim that "distance-only municipalities do not respond" — that is false for travel
   burden and overstated for admissions. Honesty over the desired pattern.

8. **Exact sentence the results support** (nuanced, admissions-based):
   > "Splitting the disagreement set, flow-flagged municipalities show the
   > psychiatric-admission first stage with flat pre-trends—admissions fall by about
   > 3.7 per 1,000—four times the movement among distance-only false positives, whose
   > smaller change fails the pre-trend test. The first stage loads primarily on
   > revealed reliance, not proximity. Travel burden, which shifts mechanically for any
   > nearby municipality, does not discriminate the two groups."

## Decision

- **Appendix: yes** — full table (travel, admissions, suicide, self-harm × 3 groups ×
  2 samples) + figure. Referee-auditable. The pre-trend contrast is the honest payoff.
- **Main text: at most the nuanced sentence above**, and only if the author wants it.
  Recommend **appendix-only** by default, because (a) travel burden does not
  discriminate and (b) distance-only is nonzero, so a bold validation headline would
  overclaim. The exposure rule's main support stays the existing travel-burden +
  utilization first stage; this placebo is a corroborating diagnostic, not a new leg.
- **Headline claim NOT supported**: "the first stage loads on revealed use, not
  proximity" as an unqualified statement. Supported only in the nuanced, admissions-
  specific, pre-trend-aware form above.

## Counts (mutually exclusive municipality cohorts)

| Sample | flow_only | distance_only | both | mixed | (pairs: flow/dist/both/union) |
|---|---|---|---|---|---|
| F5 measurement (60) | 86 | 129 | 40 | 1 | 97 / 196 / 44 / 337 |
| PNASH psychiatric (48) | 74 | 102 | 27 | 0 | 82 / 162 / 30 / 274 |

## Remaining risks

- Distance-only's nonzero movement could invite a referee to say "distance also
  captures exposure." The honest rebuttal is the pre-trend failure, not a zero point
  estimate. Frame accordingly.
- "Both" group is small (n=27) and statistically fragile; report directionally only.
- Travel burden's mechanical movement must be disclosed, not hidden, wherever the
  figure/table appears.
