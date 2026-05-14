# Changelog

## v6 — May 2026 (Submission-ready, JPubE format)

- **Title rebranded** to **Sheltered Bidding: The Within-Auction Cost of SME Set-Asides** (commit `5d83c28`).
- **Abstract pivoted** to question-first structure with three headline numbers: ~10% DiD effect on winning prices; sheltered bidding = 2/3 to 3/4 of the simulated effect; R$55M/yr welfare cost on Group 65 alone (out of São Paulo's R$13B platform).
- **Sheltered bidding** elevated from descriptive label to characterized property; new policy-design framing.
- **Aggressive compression** (body 64→54pp; appendix 24→23pp) to fit JPubE conventions.
- **Macros** (`v6-jpube/output/values.tex`) become the single source of truth for every headline number in the manuscript.
- **Final pre-submission cleanup** (commit `d21754d`) + footnote translation of the PGE-SP Parecer 151/2017 ementa into English.

## v5 — April 2026 (Submission-ready, structural decomposition)

Structural decomposition replaces the v1--v3 reduced-form headline: asymmetric IPV reading of Pregão, type-specific cost distributions point-identified from drop-out bids (Haile and Tamer 2003), Krasnokutskaya (2011) auction-level UH correction, Athey--Seira (2011) treatment of equilibrium SME entry, BNE Monte Carlo, cluster bootstrap, Saez--Stantcheva (2016) welfare weights. Headline magnitudes: within-auction share ~74% in non-pharma, ~66% in pharma. Welfare cost 28.9%/44.8% of *p<sub>S<sub>1</sub></sub>* at λ = 0.30.

## March 2026 (v4, reduced-form layer)

- **Fiscal Cost Quantification** (v4 reduced-form): subsection added with R$84.5--85.8 million headline. **Superseded in v5/v6** by the structural welfare arithmetic (R$55--128M/yr, λ-grid, MCPF, Saez--Stantcheva weights).
- 5 advanced econometric methods: parallel trends sensitivity (HonestDiD), Lee bounds, causal forest, quantile DiD, Gelbach decomposition
- 4 new tables + 5 new figures (18 tables / 15 figures total)
- Expanded appendix with organized subsections and explanatory paragraphs
- Polished main body text (~10% expansion with references to advanced methods)
- New MkDocs page for advanced methods

## March 2025

- Full R/fixest pipeline with 14 tables and 10 figures
- Robustness checks: placebo tests, alternative clustering, winsorization, randomization inference
- Extensions: real prices, extensive margin, efficiency, winner composition, heterogeneity by item value and PBU type
- MkDocs documentation site

## January 2021 (First Version)

- Initial manuscript with core DiDiR results
- 4 main outcome variables: prices, firms, bids, distance
- 3 time windows with baseline and PBU-controlled specifications
