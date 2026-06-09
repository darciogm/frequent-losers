# Reframing Implementation Summary

Date: 2026-06-08

## Files modified

- `01_manuscript/main.tex`
- `01_manuscript/introduction.tex`
- `01_manuscript/setting.tex`
- `01_manuscript/method.tex`
- `01_manuscript/results.tex`
- `01_manuscript/discussion.tex`
- `01_manuscript/conclusion.tex`
- `01_manuscript/tables/tab_mortality_null.tex`
- `01_manuscript/tables/tab_seed_att_distribution.tex`
- `01_manuscript/tables/table_dias_fontes_comparison.tex`
- `03_analysis/08_map_divergence.py`
- `03_analysis/D5_make_mortality_results.R`
- `03_analysis/47b_seed_att_distribution.R`
- `04_figures/fig_firststage_travel.pdf`
- `04_figures/fig_es_mortality.pdf`
- `04_figures/fig_es_icsap_pretrend.pdf`
- `04_figures/fig_seed_att_distribution.pdf`
- `01_manuscript/main.pdf`

## Sections rewritten

- Title and abstract.
- Introduction, now opening with the general exposure-measurement problem in hospital closures.
- Institutional-setting opening, now framed around provider loss and closure-specific catchments.
- Exposure section, with an explicit estimand paragraph.
- Results headings and interpretation for first stage and mortality.
- Discussion opening, now framed as mortality bounds among flow-exposed municipalities.
- Conclusion, now returning to the general measurement lesson and then the Brazil application.

## Title selected

`Who Is Exposed When a Hospital Closes? Patient Flows and Psychiatric Deinstitutionalization in Brazil`

## Abstract before/after

Before: opened with the psychiatric deinstitutionalization controversy and mortality warnings.

After: opens with the hospital-closure exposure problem, introduces patient-flow exposure, then applies the design to psychiatric hospital closures in Brazil. Mortality is stated as a bounded acute-mortality result, and the Dias and Fontes comparison is framed as complementarity with CAPS rollout evidence.

## Dias and Fontes positioning

Dias and Fontes (2024) are cited directly in:

- `01_manuscript/introduction.tex`
- `01_manuscript/setting.tex`
- `01_manuscript/discussion.tex`
- `01_manuscript/references.bib`

The paper now states that Dias and Fontes study CAPS rollout/community-care expansion, while this paper studies provider loss from psychiatric hospital closures and the measurement of exposure to that loss.

## Conceptual comparison table

Added `01_manuscript/tables/table_dias_fontes_comparison.tex`, titled "How this paper differs from Dias and Fontes (2024)." The table compares treatment, exposure unit, main margin, and contribution/estimand.

This table is a conceptual manuscript table, not an empirical generated result. It was added as LaTeX and referenced in the introduction.

## Phrase audit

The active manuscript and scripts were searched for:

- `Closure Without Catastrophe`
- `catastrophe`
- `feared outcome`
- `the answer is no`
- `Brazil ran this experiment`
- `did not harm`
- `harmless`
- `the mortality effects of Brazil's psychiatric reform`
- `first evidence`
- `first mortality evidence`
- `deinstitutionalization did not`
- `launder a pre-trend`
- `which rule is right`
- `no local substitute`
- `embedding-driven treatment rule`
- `Critics of psychiatric`
- `kill patients`
- `global policy`
- `globally contested`
- `What the null means`
- `Headline`

No active matches remained after excluding archived files.

## Scripts run

- `Rscript 03_analysis/D5_make_mortality_results.R`
- `Rscript 03_analysis/47b_seed_att_distribution.R --force`
- `pdflatex -interaction=nonstopmode main && bibtex main && pdflatex -interaction=nonstopmode main && pdflatex -interaction=nonstopmode main` from `01_manuscript/`

## Build status

Build completed successfully. Output:

- `01_manuscript/main.pdf`

Final log checks found no LaTeX errors, undefined control sequences, undefined citations, or undefined references.

Non-fatal warnings observed:

- Several `!h` float specifiers changed to `!ht`.
- Underfull hbox warnings in narrow table columns.
- Duplicate destination warning for `page.1`.
- One text page containing only floats.

## R warnings

`D5_make_mortality_results.R` completed but reported `fixest` warnings that some VCOV matrices were not positive semi-definite and were fixed. It also noted fixed-effect singletons removed in some specifications.

`47b_seed_att_distribution.R --force` completed successfully after retraining 20 seeds and regenerated the seed-sensitivity table and figure.

## Remaining issues

- The conceptual Dias and Fontes comparison table is manually written LaTeX because it summarizes design positioning rather than generated empirical quantities.
- No new empirical estimates were introduced for this reframing task beyond regenerating existing table/figure outputs for consistency.
- The broader revision package still contains generated appendix material on data caveats and sensitivity checks from prior work; this reframing did not re-estimate those components.
