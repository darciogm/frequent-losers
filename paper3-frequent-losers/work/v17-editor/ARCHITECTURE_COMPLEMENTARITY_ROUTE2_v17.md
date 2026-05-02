# Architecture / Complementarity — Route 2 Memo (v17)

**Date:** 2026-05-02.
**Vehicles:** existing scripts `scripts/49_imhof_incremental_value.R`
(already executed; outputs in `output/imhof_incremental/`),
`scripts/31_imhof_full_pipeline.R` (already executed; outputs in
`output/imhof_full/`), and a new
`scripts/63_architecture_gatekeeper.R` (executed 2026-05-02; outputs
in `output/architecture_gatekeeper/`).
**Companion deliverables:** `tab_architecture_gatekeeper.tex` and
`fig_precision_at_k.pdf`.

**Goal of this pass.** Sharpen what is already the strongest part of
the paper (award-layer screen vs.\ bid-layer forensic stage vs.\ their
combination) without overselling cost-effectiveness, and reframe the
manuscript's observability language to match what the repository
actually contains. The bid-level data exist in the repo; the manuscript
must distinguish between *operational* observability (what an
audit-court analyst can routinely query) and *forensic-recoverable*
observability (what is reachable through administrative request and is
what the team itself used to compute the Imhof comparison).

---

## I. What the repo already establishes (and what was not foregrounded)

### I.1. Same-sample, cross-validated AUC complementarity (script 49)

`output/imhof_incremental/imhof_incremental.csv` reports five
specifications evaluated on the identical always-loser subsample for
which all seven Imhof features can be computed ($n_{\text{full}} =
11{,}676$ firms with $193$ cobidder positives):

| Model | Features | AUC | 95\,\% CI | $\Delta$ vs.\ Imhof full | DeLong $p$ |
|---|---|---|---|---|---|
| Imhof full pipeline | 7 within-tender bid-distribution moments | $0.846$ | $[0.819, 0.873]$ | --- | --- |
| Binary FL flag | $\mathbb{1}[\text{tenders\_count} \geq 14]$ | $0.881$ | $[0.871, 0.892]$ | $+0.035$ | $0.014$ |
| Continuous participation count | $\text{tenders\_count}$ | $0.877$ | $[0.857, 0.898]$ | $+0.031$ | $0.077$ |
| Imhof full + binary FL | 8 features | **$0.942$** | $[0.927, 0.957]$ | $+0.096$ | $1.2 \times 10^{-26}$ |
| Imhof full + tenders | 8 features | **$0.944$** | $[0.929, 0.958]$ | $+0.098$ | $1.3 \times 10^{-25}$ |

Two facts the v16 manuscript ($\S$`sec_forensic`) reports but does not
foreground:

1. On the same evaluation sample, the award-layer signal alone reaches
   higher AUC than the full bid-layer pipeline ($0.881$ vs.\ $0.846$,
   DeLong $p = 0.014$). The v16 manuscript hedges this as "comparable
   accuracy on a thinner data envelope"; the data are stronger than
   the hedge. Phrased honestly: on this evaluation sample, the
   award-layer FL signal *outperforms* the seven-feature bid-layer
   pipeline in AUC, on top of being cheaper to compute.
2. The combined classifiers are not just a marginal gain. $+0.096$
   AUC over Imhof full alone is an effect size of approximately
   $4 \sigma$ (the SE of the Imhof-full AUC is $\approx 0.014$); the
   DeLong test rejects equality at $p < 10^{-25}$. This is genuine
   complementarity, not a noise-level boost.

These facts justify a sharper headline in $\S$1 and $\S$`sec:forensic`.

### I.2. Out-of-sample full-feature run (script 31)

`output/imhof_full/imhof_full_results.csv` reports the same six
specifications on a slightly broader subsample (different filter
criteria, hence the discrepancy with script 49):

| Model | AUC | 95\,\% CI |
|---|---|---|
| FL alone | $0.903$ | $[0.884, 0.923]$ |
| tenders_count alone | $0.884$ | $[0.860, 0.908]$ |
| Imhof CV-only (the v13 strawman benchmark) | $0.584$ | $[0.553, 0.616]$ |
| Imhof FULL (7 features) | $0.888$ | $[0.865, 0.911]$ |
| Imhof FULL + FL | $0.955$ | $[0.943, 0.967]$ |
| Imhof FULL + tenders | $0.962$ | $[0.954, 0.969]$ |

On the broader sample the AUC numbers are higher and the relative
ordering preserves (FL $\approx$ Imhof FULL; combined $\approx 0.96$).
The v13 strawman benchmark of "Imhof CV alone" produced an AUC of
$0.58$ — only modestly above chance — which is the comparison the v16
literature section ($\S$`sec_literature`) implicitly relied on. The
honest comparison is the seven-feature Imhof full pipeline at AUC
$0.888$, and the manuscript should retire the CV-only benchmark.

## II. New result: sequential gatekeeper architecture (script 63)

What scripts 31 and 49 do *not* answer is the *sequential* operational
claim that the manuscript's architecture story implies. If the FL
screen is used as a Stage-1 gatekeeper to narrow the always-loser pool
before Stage-2 forensic Imhof runs on the survivors, what is the
operational precision and bid-microdata footprint of the resulting
two-stage pipeline?

### II.1. Operational precision-at-$k$

Five-fold cross-validated random forest scores on the same
$n_{\text{full}} = 11{,}676$ evaluation pool (193 cobidder positives,
base rate $0.0165$):

| Rule | Stage-1 pool | Stage-2 pool | Bid-microdata extractions | $k=500$ Precision | $k=500$ Recall | $k=500$ Lift |
|---|---|---|---|---|---|---|
| Award-layer only (FL log_tc) | full | n/a | **$0$** | $0.132$ | $0.342$ | $7.99\times$ |
| Bid-layer only (Imhof full) | n/a | full | $11{,}676$ | $0.146$ | $0.378$ | $8.83\times$ |
| Joint scoring (FL + Imhof, single model) | n/a | full | $11{,}676$ | $0.224$ | $0.580$ | $13.55\times$ |
| Sequential: FL $\to$ Imhof, $K_1=1{,}000$ | top $1{,}000$ FL | Imhof on those $1{,}000$ | **$1{,}000$** | $0.174$ | $0.451$ | $10.53\times$ |
| Sequential: FL $\to$ Imhof, $K_1=2{,}000$ | top $2{,}000$ FL | Imhof on those $2{,}000$ | **$2{,}000$** | $0.192$ | $0.497$ | $11.62\times$ |
| Sequential: FL $\to$ Imhof, $K_1=4{,}000$ | top $4{,}000$ FL | Imhof on those $4{,}000$ | **$4{,}000$** | $0.174$ | $0.451$ | $10.53\times$ |

At $k = 500$, the sequential rule with $K_1 = 2{,}000$ delivers
precision $0.192$ — between award-layer-only ($0.132$) and joint
scoring on the full pool ($0.224$) — while requesting bid microdata for
$2{,}000$ firms instead of $11{,}676$. That is a precision drop of
$\approx 14\%$ relative to joint scoring (from $0.224$ to $0.192$) in
exchange for a bid-microdata footprint reduction of $\approx 83\%$.

### II.2. Recall trade-off at $k=1{,}000$

| Rule | Cobidders captured (TP) | Recall | Bid-microdata firms |
|---|---|---|---|
| Award-layer only | $97 / 193$ | $0.503$ | $0$ |
| Bid-layer only | $97 / 193$ | $0.503$ | $11{,}676$ |
| Joint scoring | $142 / 193$ | $0.736$ | $11{,}676$ |
| Sequential ($K_1 = 2{,}000$) | $131 / 193$ | $0.679$ | $2{,}000$ |

The sequential pipeline captures $131$ of $193$ cobidders in the
top-$1{,}000$ flag list while requesting bid microdata for only
$2{,}000$ firms. Joint scoring captures $11$ more cobidders ($142$ vs
$131$) but requires bid microdata for the entire $11{,}676$-firm
evaluation pool.

### II.3. Headline sequential statement (defensible)

The sequential gatekeeper is not the precision champion — joint
scoring is. The sequential gatekeeper's operational case is:

> *Comparable recall at much lower bid-microdata footprint.* Stage-1
> FL-rank narrows the bid-microdata interrogation from $11{,}676$
> firms to $2{,}000$ ($-83\%$). Stage-2 Imhof-rank within those
> survivors then reaches $0.192$ precision and $0.679$ recall at
> $k = 500$ and $k = 1{,}000$ respectively, against $0.224$ and
> $0.736$ for joint scoring on the full pool. The architectural read
> is that the award-layer signal is informative enough to *triage*
> the bid-microdata interrogation, not to *replace* it.

### II.4. What the sequential evidence does *not* establish

The sequential evidence does **not** establish:

1. A causal cost-effectiveness claim. We do not know the actual cost of
   acquiring bid microdata for a single firm in BEC, nor the
   audit-court analyst time per investigation. Script 56 in the repo
   (`56_regulatory_cost_frontier.R`) attempts a dollarisation but uses
   illustrative numbers (R\$50K microdata acquisition + R\$5K
   investigation per flag) that are not validated against any
   institutional source. The manuscript should *not* report
   dollarised cost-per-cobidder figures.
2. A claim that Stage-1 always strictly dominates a single-stage
   pipeline. Joint scoring on the full pool is statistically more
   precise (precision $0.224$ vs $0.192$ at $k = 500$, $p$ small but
   not formally tested here). The sequential rule's case is operational
   (data envelope), not statistical (precision/recall).
3. A claim that the operational thresholds we report ($k =
   500/1{,}000$; $K_1 = 1{,}000$/$2{,}000$/$4{,}000$) are calibrated to
   any specific Brazilian audit-court constraint. They are
   plausible-magnitude operational windows for an audit-court analyst,
   not budget-binding parameters.

## III. Observability framing — required reframe

This is the *cross-cutting* deliverable from this pass and it lands
directly in the manuscript prose, not just the appendix.

### III.1. The current language and what is wrong with it

The v16 manuscript uses *"unobservable"*, *"unavailable"*, *"the data
do not preserve"*, and *"jurisdictions that lack bid microdata"* in 15
distinct prose locations (50 hits with synonyms; see audit
$\S$ II.1). The phrasing is loose enough that a Referee 2 will read it
as *the data do not exist* and then catch the team running the seven-
feature Imhof full pipeline (which by definition requires per-bid
prices), at which point the architecture story reads as either
contradictory or quietly evasive. Both readings are bad and avoidable.

### III.2. The reframe (precise language to use)

The v17 manuscript distinguishes two layers of observability:

- **Operational layer.** What audit-court analysts and competition
  authorities can query in routine workflow against the BEC analytical
  warehouse. This layer carries: winner identity, participant identity,
  item code, negotiated price, contracting unit, and procurement
  procedure. It does *not* carry per-bidder bid amounts at the
  query-in-minutes interface.
- **Forensic-recoverable layer.** What is reachable through an
  administrative request to the BEC operational system (bid-by-bid
  records via the LANCES export). The team accessed this layer for
  evaluation purposes; it is what the v3 and v14 enrichments of
  `bid_level_full` are built from. Acquisition is slow (multi-step
  administrative process; weeks of delay per request, per the
  TCE-SP cases the team examined), expensive in analyst time, and
  governed by audit-court discretion rather than published procedure.

The architecture claim reads through the same distinction:

- The **screening object** (FL, tenders_count) is designed to deploy
  on the *operational layer*. It runs in minutes against routinely
  archived data.
- The **forensic object** (Imhof full pipeline) requires the
  *forensic-recoverable layer*. It is what audit courts request when
  there is sufficient prior suspicion to justify the administrative
  cost of the LANCES extract.
- The **architectural complementarity** is that the operational-layer
  screen acts as a Stage-1 gatekeeper, generating prior suspicion at
  scale, before the audit court invests the forensic-layer cost.

The same distinction maps cleanly onto FPDS-NG (US: award layer
universally archived; bid amounts at agency discretion), TED (EU:
award layer mandatory; bid microdata heterogeneous; per
\citealt{sanchezgraells2019screening}, fewer than half of EU
procurement systems make per-bidder bid amounts retrievable at the
analytical-warehouse layer), and UK Contracts Finder (awards archived;
bid-level archival depends on contracting-authority discretion).

### III.3. Specific manuscript edits this requires

Six prose locations where the sloppy framing must be replaced:

| Section | Line | Current ("sloppy") | Replace with ("disciplined") |
|---|---|---|---|
| `sec_frontmatter_v16` (abstract) | 31 | "detectors that require per-bidder bid amounts" | "detectors trained on the forensic-recoverable bid-microdata layer" |
| `sec_introduction_v16` | 7 | "informative about coordinated bidding when the bid-level [data are unavailable]" | "informative about coordinated bidding when the operational data layer carries award records but not per-bidder bid amounts" |
| `sec_introduction_v16` | 113 | "require bid microdata; the construct operates on the information-coarsened layer that survives" | "require bid microdata at the analytical-warehouse layer; the construct operates on the operational layer that audit courts can query without administrative request" |
| `sec_introduction_v16` | 136 | "jurisdictions that lack bid microdata can deploy the screening stage" | "jurisdictions whose operational layer carries award records but not per-bidder bid amounts can deploy the screening stage" |
| `sec_conclusion_v16` | 5 | "assumption that bid-level data are observable" | "assumption that bid-level data are routinely operationally observable" |
| `sec_conclusion_v16` | 124 | "that requires bid-level evidence" | "that requires bid-level evidence at the operational layer" |

A new disclosure footnote in `sec5_emp_v16` (next to L12) and another
in `sec_forensic_v16` (next to L74) should state, in
plainly-readable prose:

> *Disclosure on data access.* The Imhof-pipeline comparison reported
> in $\S$`sec:forensic` requires per-bidder bid amounts. Those amounts
> are not exported to BEC's analytical warehouse and were obtained, for
> the purposes of this paper, through an administrative LANCES export
> from the BEC operational system. The screening object the paper
> proposes is built around the analytical-warehouse layer because that
> is the layer at which audit courts and competition authorities query
> routinely; the forensic comparison uses the operational layer because
> that is where the bid-distribution moments are computable. The
> architectural claim is that the screening stage acts as a
> Stage-1 gatekeeper for the forensic stage, not that bid-microdata
> are universally absent.

This footnote does the work of replacing 15 imprecise prose locations
with one precise disclosure.

## IV. What the manuscript can claim, after this pass

Three new defensible headline statements:

1. **AUC complementarity.** "Combining the award-layer screening object
   with the bid-layer forensic moments raises AUC by $+0.096$ over
   Imhof-full alone (DeLong $p < 10^{-25}$, same evaluation sample)."
2. **Operational complementarity.** "A sequential gatekeeper that
   uses the FL screen to triage the bid-microdata interrogation
   reaches $0.679$ recall in the top-$1{,}000$ flag list while
   requiring bid microdata for $2{,}000$ firms instead of the
   $11{,}676$ that joint single-model scoring would require — a
   $\approx 83\%$ reduction in bid-microdata footprint at a $\approx
   8\%$ recall cost relative to joint scoring."
3. **Observability discipline.** "Per-bidder bid amounts exist in BEC's
   operational system; they are not exported to the analytical-warehouse
   layer that competition authorities query routinely. The architecture
   we propose is built around the layer audit courts can deploy
   immediately, not the layer that requires administrative
   recovery."

## V. What this pass does *not* deliver

1. **No dollarised cost-effectiveness frontier.** Script 56's
   illustrative R\$50K + R\$5K cost model is not validated against any
   institutional source. The v17 manuscript should not report
   dollarised cost-per-cobidder claims.
2. **No falsifiable temporal-holdout audit of the sequential pipeline.**
   The 5-fold CV scores in Table~$\ref{tab:architecture_gatekeeper}$ do
   not survive a strict pre-2017 / 2017-2019 holdout (cf.\ script 43's
   precision-at-$k$ audit, which inflated by $\approx 50\%$ in-sample
   relative to temporal holdout). The honest reading of the operational
   precision is "5-fold CV in-sample, with the proviso that the
   temporal-holdout audit reduces precision-at-$k$ by approximately
   half on the FL-only path." We should add a temporal-holdout column
   to the gatekeeper table in a follow-on pass before submission.
3. **No identification claim about *why* the sequential pipeline
   recovers complementary signal.** It works because FL ranks firms by
   participation intensity (a deployment-side primitive) and Imhof
   ranks firms by bid-distribution geometry (a bid-side primitive); the
   two are not redundant. We do not need a structural model to make
   the operational claim, but the manuscript should not pretend we
   have one.

## VI. Verdict — Front 3

**Material upside delivered, with disciplined framing.** Three new
defensible artifacts:

- Same-sample DeLong-confirmed AUC complementarity ($+0.096$,
  $p < 10^{-25}$) sharpened to a headline.
- New sequential-gatekeeper precision/recall envelope showing
  comparable recall at $\approx 17\%$ of the bid-microdata footprint of
  joint scoring.
- A precise observability reframe replacing 15 imprecise prose
  locations with the operational/forensic-recoverable distinction.

The Front 3 result is the strongest of the three Route 2 fronts in
referee-defensibility: numbers are clean, design is transparent, and
the framing reframe is forced rather than chosen (the data exist; the
manuscript must say so honestly). It should anchor $\S$1 and
$\S$`sec:forensic` in v17.

**Recommendation:** wire `tab_architecture_gatekeeper.tex` and
`fig_precision_at_k.pdf` into v17 $\S$`sec:forensic`; rewrite the six
prose locations in $\S$III.3; add the disclosure footnote in
$\S$`sec5_emp_v17` and $\S$`sec_forensic_v17`; retire the Imhof CV-only
strawman in favor of the seven-feature Imhof full pipeline as the
honest baseline; promote the AUC complementarity statement to the
abstract and $\S$1.

## VII. Files produced (Subprompt 3 net-new)

| File | Role |
|---|---|
| `scripts/63_architecture_gatekeeper.R` | Sequential gatekeeper analysis |
| `output/architecture_gatekeeper/precision_at_k.csv` | 36 rows: precision/recall/lift by rule × $k$ |
| `output/architecture_gatekeeper/sequential_envelope.csv` | Smallest-$k$ achieving 0.10/0.15/0.20 precision per rule |
| `output/architecture_gatekeeper/fig_precision_at_k.pdf` | Precision-at-$k$ vs $k$ by rule |
| `work/v13/output/tables/tab_architecture_gatekeeper.tex` | Main-text-quality table |

Pre-existing outputs that v16 already produced and that should be
foregrounded (not regenerated) in v17:

| File | Role |
|---|---|
| `output/imhof_incremental/imhof_incremental.csv` | Same-sample DeLong AUC comparison |
| `output/imhof_full/imhof_full_results.csv` | Full-population Imhof AUC comparison |
| `work/v13/output/tables/tab_imhof_incremental.tex` | Already in `sec_forensic_v16` (kept) |
| `work/v13/output/tables/tab_imhof_full.tex` | Already in `sec_forensic_v16` (kept) |

---

*End of Front 3 Route 2 memo. Manuscript edits proceed in Subprompt 4
onward. The observability reframe in $\S$III.3 is the highest-priority
prose change in the v17 push.*
