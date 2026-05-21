# Findings — Cheap Signals, Costly Proof

This page is the curated index of *what we have learned* from the project's
own analyses. Each finding is a **claim about the world** — the kind of
statement that would go in the paper — and it may rest on several
`AN-NNN` analyses, cited in its Sources footer. The detail, design, and
caveats behind each number live on those analysis pages; this page is the
synthesis.

This page is the **directory of conclusions**. Use [`docs/analyses/`](../analyses/index.md)
to look up the per-result design, raw numbers, and full result tables;
use this page to scan what we believe and at what confidence.

---

## How to read the confidence tags

A traffic-light convention runs across both scales: 🟢 = strongest
confidence, 🟡 = middle, 🔴 = weakest. The *meaning* of each color
depends on whether the claim is empirical or interpretive.

**Empirical findings** — the color reflects the *source* of confidence,
not the size of the effect:

- 🟢 **Replicated** — the finding appears in multiple independent samples
  or studies that agree in direction and rough magnitude.
- 🟡 **Single source** — one solid study, or one of our own runs, with
  no independent replication yet.
- 🔴 **Provisional** — one descriptive cut that is parser-dependent,
  sensitive to sample definition, or flagged with a known caveat. Read
  the qualifier before quoting.

**Interpretations** — parallel scheme:

- 🟢 **Strong** — multiple converging lines of evidence; alternatives
  have been considered and rejected.
- 🟡 **Plausible** — consistent with the evidence but other readings
  remain open.
- 🔴 **Speculative** — suggested by the data but unverified; flagged
  for follow-up rather than relied on.

For *Cheap Signals, Costly Proof*, the natural 🟢 promotion criterion is
replication on a non-BEC-SP procurement panel (e.g. ComprasNet federal,
or another state's e-procurement system). Until that exists, findings
here rest on the project's own BEC 2009–2019 runs and start at 🟡.

---

## Findings overview

No findings have been written yet. As the paper's headline claims
stabilize, write each as a `<claim-slug>.md` under `docs/findings/` and
list it here under a thematic block. Suggested initial blocks for this
paper:

**Award-layer triage performance** *(empirical)*

- *(to be added)* The frequent-loser flag reduces the bid-microdata pool
  by 83% while retaining 131 of 193 adjudicated cobidders — headline
  triage claim.
- *(to be added)* The flag matches the Imhof–Wallimann seven-feature
  bid-distribution pipeline on the same data while adding non-redundant
  signal in combination.

**Out-of-sample validity** *(empirical)*

- *(to be added)* A 2009–2016-trained screen prospectively flags
  adjudicated cobidders in 2017–2019 — discrimination is out-of-sample,
  not in-sample fit.

**Mechanism / interpretation** *(interpretive)*

- *(to be added)* A simple separating-equilibrium argument motivates
  endogenous loser-side participation as the ranking primitive.

---

## Open items for this page

- **No findings exist yet.** The first concrete write-up to attempt is
  the triage headline (83% pool reduction, two-thirds of cobidders
  recovered), as that is the abstract's lead.
- **The 🟢 promotion path is replication on a non-BEC dataset.** None of
  the planned analyses provides that on its own; that is a separate
  data-acquisition decision.
- **Document the screen-vs-adjudicate scope distinction** in a finding,
  so reviewers do not over-read the flag as a cartel-membership claim.
