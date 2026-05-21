# Hypotheses

Testable predictions for *Cheap Signals, Costly Proof: Award-Layer Triage
for Cartel Enforcement* (Genicolo-Martins & Furquim de Azevedo). Each
hypothesis lives in its own file and is referenced project-internally
by `H:<slug>`.

Hypotheses are organized into thematic clusters aligned with the paper's
sections.

## How to read a hypothesis page

Each page follows the same structure — *the design → what's known → what's
left*:

- **Title + lede:** the `H:<slug>` title, then a plain-words statement of the
  claim.
- **Evidence-strength callout:** an at-a-glance verdict (Very strong / Strong /
  Moderate / Weak / Not yet tested) plus a one-line status.
- **Theory:** the theoretical motivation, with references.
- **Prediction:** the precise directional claim.
- **Competing prediction:** what a non-strategic explanation predicts instead —
  the alternative the test has to rule out.
- **Case evidence:** anecdotal grounding from CADE decisions and case
  documents.
- **Empirical test:** the concrete specification — outcome, variation,
  specification, fixed effects.
- **Data requirements and limitations:** datasets needed and threats to
  identification.
- **Evidence:** a table of the project's analyses bearing on the hypothesis —
  `Analysis` (AN-ID, linked) · `Bearing` (Supports / Against / Mixed / Pending)
  · `Key takeaway`. Click the analysis ID for the full design and results.
- **Open tests:** forward-looking only — analyses not yet run, or not yet
  stubbed.

The **scorecard** below rolls up the current status of every hypothesis
against the analyses (`AN-NNN`) that bear on it.

---

## Cluster A: Award-layer triage performance

Maps to paper §3 (Main Results — flag construction and triage).

- *(to be added)* `H:frequent-loser-flag-triages` — Adjudicated cartel
  cobidders concentrate among repeat losers; a flag built on award-layer
  participation alone recovers two-thirds of them while cutting the
  bid-microdata pool by ~80%.

## Cluster B: Out-of-sample validity

Maps to paper §4 (Temporal holdout).

- *(to be added)* `H:prospective-discrimination` — A screen trained on
  2009–2016 participation prospectively flags 2017–2019 adjudicated
  cobidders at rates above the natural-base prevalence.

## Cluster C: Mechanism

Maps to paper §5 (Separating-equilibrium motivation).

- *(to be added)* `H:separating-equilibrium` — In a competitive market,
  loser-side participation reveals firm type; cartel members have
  systematically different participation profiles than competitive
  losers.

## Cluster D: Comparison with bid-microdata pipelines

Maps to paper §6 (Imhof–Wallimann comparison).

- *(to be added)* `H:complementary-to-iw` — Award-layer signals match
  the discriminative power of the Imhof–Wallimann seven-feature
  bid-distribution pipeline on the same data and add non-redundant
  signal in combination.

---

## Scorecard

No hypothesis pages exist yet. Once you scaffold the first `H:<slug>.md`,
return here and fill in the scorecard row. Status runs **Not yet tested**
→ **Not confirmed** / **Mixed** / **Partial** → **Confirmed**.

| # | Prediction | Intuition | Evidence | Status |
|---|-----------|-----------|----------|--------|
| H1 | *(scaffold first hypothesis to populate)* | — | — | **Not yet tested** |
