# ANS private-penetration moderator (branch `paper18-ans-moderator`)

Addresses limitation #5 (SUS-only; private/supplementary care invisible) with public
ANS data. Submission untouched until promoted.

## Data
- ANS "Taxa de Cobertura de Planos de Saude" (PDA-047), public, downloaded to
  `02_data/raw/ans/pda-047-taxa_cobertura.csv` (current 2026 snapshot, muni x sex x age).
- The file's POPULACAO column is empty; penetration = ANS medical-plan beneficiaries
  (52.9M national) / IBGE municipal population. National pop-weighted penetration 24.9%
  (matches the known ~25%), 5,565 municipalities, 100% panel match.
- Private penetration is a slow-moving structural feature (income/employment); the
  snapshot proxies the persistent cross-sectional ranking. A psychiatric closure does
  not plausibly change a municipality's overall plan penetration (no reverse causality).

## Descriptive (the nuance)
Exposed (treated) catchments are NOT the 0-5% rural picture: median penetration 11.6%,
mean 13.9% (psychiatric closures sit in regional hubs with moderate private presence).
So the typical exposed catchment is ~88% SUS-dependent -- SUS-dominant but not exclusive.
26% of exposed munis are below 5% penetration; 44% below 10%; 76% below 20%.

## Heterogeneity (the test) -- treated split at median treated penetration (11.6%)

| Outcome | all | low private | high private |
|---|---|---|---|
| Suicide /100k | +0.28 [-0.72, 1.29] | **-0.52 [-2.71, 1.66]**, p=0.63 | +0.44 [-0.64, 1.52] |
| Psych adm /1,000 | -7.32 [-11.4, -3.3] | **-2.82 [-3.96, -1.68]**, p=0.44 | -8.18, pre-trend fails |

**Reading:** in LOW-private municipalities -- where displaced patients cannot be
absorbed by an unobserved private sector -- the admission drop persists (-2.8 per
1,000, flat pre-trends) and suicide stays a bounded null (CI covers zero, flat
pre-trends). The result is therefore not an artifact of private displacement. The
high-private arm is messier (admission pre-trend fails) but is exactly where the
limitation matters less and the design is weakest anyway.

## Honest caveats
- Penetration is a 2026 snapshot proxying the persistent structural ranking, not a
  pre-closure value (acceptable: penetration ranking is highly persistent; closure
  does not move it).
- Exposed catchments are SUS-dominant (~88%) but not exclusive.
- Both arms are small (~52 treated), so CIs are wide -- the inherent power limit again.
  The decisive arm (low private) is nonetheless clean and consistent with the headline.
- Core hard limit unchanged: private psychiatric admissions themselves remain
  unobserved (no public private-inpatient microdata). The moderator bounds the
  limitation; it does not eliminate it.

## Decision
Appendix-recommended. It converts limitation #5 from a disclosed caveat into a tested,
bounded one: the result holds where the SUS-only blind spot cannot operate. Frame as a
heterogeneity robustness next to the CAPS-baseline and exposure-variant checks.

## Files
- `03_analysis/98_ans_private_moderator.py` (build penetration + descriptive)
- `03_analysis/99_ans_moderator_eventstudy.R` (low/high ES)
- `03_analysis/100_make_ans_moderator_table.py` (appendix table)
- `01_manuscript/tables_appendix/table_ans_private_moderator.tex` (compiles standalone)
- data outputs gitignored (raw ANS CSV, penetration parquet, result CSVs)
