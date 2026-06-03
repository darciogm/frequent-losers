# §S-G — Sequential Gatekeeping and the Cost-Recall Frontier (moved-out granular tables)

Granular diagnostics moved out of submitted Appendix G
(`submission_clean/sec_app06_forensic_sequence_submission.tex`, G-TRIM pass) to
keep the appendix at its referee-essential core (cost-denominator definitions,
the compact K1 cost-recall slice, and the case-holdout contrast). Numbers
unchanged; this is a relocation, not a re-estimation. The headline values from
each moved table are retained in the appendix prose. Source CSV paths are
relative to `work/v22-editor/outputs/`.

## Moved tables

- **Random and award-only baselines, queue depth k=500 (all K1, with 95%
  bands).** Random recall (mean over draws of a K1-sized random pool, 95%
  band), award-survivor recall (positives captured inside the award-ranked
  survivor pool before any bid rerank), and sequential recall (top-k=500 after
  bid reranking). Appendix prose retains the headlines: random recall rises
  0.029 (K1=500) to 0.140 (K1=3000); award-survivor recall 0.779 at K1=2000 and
  1.000 at K1=3000; sequential 3-12x above the random floor.
  - Source: `tables/appendix/table_G_random_and_award_only_baselines.csv`
  - Also: `tables/appendix/table_G_full_cost_recall_frontier.csv`

- **Selected (Pareto-efficient) operating points, sequential award->bid,
  k=500, with use-case labels.** K1, bid rows opened, TP, recall, precision,
  use case. Appendix prose retains the K1=500 / K1=1000 / K1=3000 endpoints and
  the K1=2000 reference point.
  - Source: `tables/appendix/table_G_operating_points.csv`

## Retained in appendix (for reference)

- Cost-denominator definitions (D1-D8) — `diagnostics/full_observability_costs.csv`,
  `tables/appendix/table_G_cost_denominator_definitions.csv`
- Compact cost-recall slice (sequential award->bid, k=500) —
  `tables/appendix/table_G_full_cost_recall_frontier.csv`
- Case-holdout recall (leave-largest-case-out) —
  `tables/appendix/table_G_case_holdout_cost_recall.csv`
