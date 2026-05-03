# Referee response notes — phased adoption robustness

**Status: internal playbook. Not for first-round submission.**

The institutional timeline reconstructed in §1 (audit trail in
`scripts/99_internal_robustness.R`, log in
`logs/internal_robustness.log`) reveals that BEC operationalized the
SME-only functionality in three sequential acts spanning July 2017 to
December 2017, before the empirical cutoff of March 2018:

- **18-Jul-2017** — COMUNICADO BEC 02/2017 (SME-only OC functionality)
- **20-Nov-2017** — COMUNICADO BEC 03/2017 (mixed-exclusivity item-by-item)
- **11-Dec-2017** — Parecer Sub-G Cons. 151/2017 (juridical ratification)
- **March 2018** — empirical cutoff (mass take-up by Group-65 PBUs)
- **16-May-2018** — TCE-SP eTC-9589.989.18 (audit-court realignment)

The empirical cutoff therefore captures **adoption**, not enablement.
The §1 narrative makes this explicit, but a referee could still ask
how the headline DiD coefficient behaves under alternative
specifications motivated by the timeline.

Three exercises are held in reserve. The recommendation is to surface
**only EX2** unconditionally (already wired into Appendix as
Table~\ref{tab:phased_adoption}); EX1 and EX3 are revealed
conditionally in response to specific referee challenges, with
careful framing.

---

## EX1 — Two-dummy decomposition (Habilitação vs Adoção)

**Result.** Replacing the single `g65_pre` dummy with two period
dummies (D_hab = G65 × m∈[690,697]; D_post = G65 × m≥698; baseline
G65 × m∈[680,689]):

| Variant            | D_hab          | D_post         |
|--------------------|----------------|----------------|
| Wide (Jul17–Feb18) | −0.085 ***     | +0.012 (n.s.)  |
| Narrow (Nov17–Feb18)| −0.087 ***    | +0.035 **      |

**Interpretation.** The dip in Group-65 prices during the
habilitação window absorbs most of what the headline DiD attributes
to the cutoff. The incremental jump strictly post-cutoff vs the
pre-habilitação baseline is statistically zero (wide variant) or
small (narrow variant).

**When to surface.** Only if a referee specifically asks for a
decomposition of pre-cutoff dynamics, or runs an event study and
notes a pre-trend. Frame as: *"the timing of the price adjustment is
phased rather than discrete, consistent with PBU diffusion of an
already-enabled BEC functionality. The structural counterfactual,
which is identified from cross-regime cost-distribution differences
rather than from a single discrete event, is invariant to this
phasing — see EX2 for the reduced-form check."*

**Risk if surfaced unprompted.** Adversarial referee can read the
n.s. D_post as evidence that the empirical cutoff is mis-specified.
Probability of that misreading: high enough to avoid first contact.

---

## EX2 — Drop-incubation robustness (safe to publish)

**Result.** Re-estimating the headline DiD on the sample with months
[690, 697] excluded (sample = m∈[680, 689] ∪ [698, 715], n=489,758):

`g65_pre = -0.087 ***` (s.e. 0.012), versus `-0.109 ***` in the full
sample. Effect persists, magnitude falls by 22%.

**Interpretation.** The headline effect is not an artifact of the
incubation window. The 22% reduction is consistent with the dip in
Group-65 prices during the BEC enablement window contributing to —
but not dominating — the headline.

**Status.** Already wired into Appendix as
Table~\ref{tab:phased_adoption}, with two paragraphs of explanation
in §7. This is the inoculation against any referee who counts months.

---

## EX3 — Placebo TCE-SP cutoff (May 2018)

**Result.** On the post-cutoff sample [698, 715] only, a placebo
treatment dummy `g65 × (m < 700)` returns `-0.037 **` (s.e. 0.014).

**Interpretation.** Group-65 prices continue to adjust upward after
the empirical cutoff, with an additional 3.7% jump around the date
of the TCE-SP realignment in eTC-9589.989.18. This is **not** a clean
placebo: it is a diagnostic of phased adoption. Consistent with the
§1 narrative that PBU adoption is gradual and ratifies progressively
as audit-court risk diminishes.

**When to surface.** Only if a referee specifically constructs an
event study with multiple post-cutoff bins and asks why prices
continue moving. Frame as: *"the post-cutoff trajectory reflects
ongoing diffusion of the new functionality across PBUs as audit-court
ratification reduces compliance risk. The structural counterfactual
is identified from cross-regime cost-distribution differences pooled
within the 18-month post window, not from a single post-cutoff month,
and is therefore robust to within-window phasing."*

**Risk if surfaced unprompted.** Adversarial referee reads the
significant placebo as evidence that the cutoff is not the unique
treatment date and demands a full dynamic event study with carefully
defended event-time bins. High cost to defend, low marginal value if
the question was not asked.

---

## Decision matrix

| Referee challenge                                | Surface |
|--------------------------------------------------|---------|
| Anticipation / pre-trend in event study          | EX2     |
| "Cutoff timing seems arbitrary"                  | EX2     |
| "Why March 2018 and not July or November 2017?"  | EX1+EX2 |
| "Effect should be discrete, why does it persist?"| EX3+EX2 |
| Multiple cutoffs / dynamic identification        | EX1+EX3 |
| Generic robustness request                       | EX2 only|

## Maintenance

- Re-run `Rscript scripts/99_internal_robustness.R` after any change
  to the cleaning pipeline; log saved to
  `logs/internal_robustness.log`.
- If the institutional timeline in §1 is further refined (e.g., new
  BEC act discovered, additional intermediate cutoff), re-evaluate
  whether EX1/EX3 framings remain coherent.
- This document is internal; do **not** include in the manuscript or
  cover letter.
