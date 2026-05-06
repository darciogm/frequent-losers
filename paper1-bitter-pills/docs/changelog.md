# Changelog

## v8 sourcing-reframe (2026-05-06)

- **Reframe — Sanctions without Markups.** Question pivoted to "When mandates secure compliance, what efficiency does the state forgo?" Title changed from "Bitter Pills: Judicial Enforcement..." to "Sanctions without Markups: Sourcing as the Margin of Bureaucratic Inefficiency." Format: JPubE Short paper, 4,925 body words, 35pp.
- **Headline result swap.** Old: "Under-the-gun premium is 23–30%." New: **selection-corrected Manski-Lee bounds [15.9%, 21.1%]**, plus the conceptual finding that **within firm-buyer-item the markup is zero** (β̂ = 0.035, SE 0.041). The cost surfaces as sourcing (modal winner differs in 70.2% of item-buyer pairs) and demand fragmentation (admin orders 3.3× larger), not as within-firm pricing.
- **Identification discipline.** Added Manski-Lee monotone bounds on admin-channel selection; wild cluster bootstrap on preferred FE (999 Rademacher replicates); BJS event study with Rambachan-Roth honest-sensitivity overlay; never-litigated placebo (returns zero).
- **Welfare bound.** Replaced v7's stacked \$16–88M with a single Lee-range bound: **\$27.8M/yr on \$300M of annual litigated spending in São Paulo** (Lee range \$23.9M–\$31.7M).
- **Conceptual contribution.** First within-firm-buyer-item evidence on the price impact of one-sided accountability; identifies sourcing under fragmentation as the empirical signature of accountability-induced inefficiency. Engages Bandiera-Prat-Valletti (2009) passive waste, Lin & Wang (2025) demand aggregation in health, and Coviello-Mariniello-Spagnolo (2018) timeline-extension contrast.
- **Manuscript.** Five-paragraph intro in flowing prose (no `\paragraph` captions); abstract at 183 PDF words (close to 180 cap target, well under JPubE Short 250 cap); 4 keywords (public procurement, health litigation, accountability, sourcing) on a single line.
- **Site.** Landing page and paper page updated to v8 narrative; results pages and replication page unchanged (still describe v4-pipeline-derived numbers, scheduled for separate sync).

## v7-r2round1 (SUPERSEDED 2026-05-04)

- Three-channel cascade rewrite (refeere R2 round 1). Identified post-treatment-bias risk in the cascade; admin-channel selection wedge unbounded; within-firm coefficient sign mismatch with abstract framing. Frozen as audit baseline; v8 supersedes.

## v7 (2026-02-28)

- **UTG Extended Outcomes:** Reference prices, quantities, bidder participation, and tender success added to Under the Gun analysis (24 new regressions).
- **Litigated vs Ordinary:** All 8 urgent purchase outcomes replicated for litigated-only comparison (32 new regressions).
- **Figures:** Two new coefficient plots (UTG all outcomes, litigated-only).
- **Manuscript:** Expanded Results section with UTG subsections and litigated-only section.
- **Replication Package:** New script 16_v7_extensions.R, updated run_all.sh and README.

## v6 (2026-02-26)

- Initial public version with replication package, MkDocs website, and complete v4 analysis pipeline.
