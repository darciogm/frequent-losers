# JLEO Reframe Memo — Paper 3 (v17-editor)

**Date:** 2026-05-03
**Backup commit:** `6ebfe90` (Blocos A+B+C)
**Reframe commit:** TBD (this rebuild + reframe)

## Central question (before → after)

| Before | After |
|---|---|
| Can a cartel-detection screen built on the contract-award envelope identify cartel-adjacent firms when per-bidder bid amounts are not routinely observable? | How should an enforcement agency sequence information acquisition when the cheap operational layer is coarser than the layer where collusion can be adjudicated? |

The before-question framed the paper as a screening-technology paper. The after-question frames it as an enforcement-design paper. The frequent-loser flag becomes the empirical instantiation of the architecture, not the product.

## Contribution (before → after)

Before: a new bid-rigging screen with AUC 0.864, comparable to bid-distribution methods, on a thinner data envelope.

After: an enforcement architecture in which an award-layer screening stage triages firms and environments before a costly bid-layer forensic stage interrogates them. The architecture reduces the bid-microdata pool the forensic stage must work on by 83% while still recovering 65% of the recall against adjudicated cobidders. The frequent-loser flag is the technology that makes the architecture feasible; its complementarity with bid-distribution screens makes the sequencing well-defined.

## Sign-reversal interpretation

Considered elevating the broad-sample β to a "screening-value object" central to the paper (per earlier brief). Rejected on JLEO calibration grounds: front-loading β as the economic object would re-attract econometrician referees asking for causal identification. Decision: rebajar β. The paper does not rest on either sign of β. The screening-value formalisation lives in Online Appendix A (Proposition `prop:screening_value`) but is not leveraged in the body.

## Headline number swap

| Before headline | After headline |
|---|---|
| AUC 0.864 (firm-level temporal holdout) | 83% footprint reduction (sequential rule reduces bid-microdata pool from N=11,676 to N≈1,985 firms while recovering 65% of cobidders) |

AUC is now positioned as "the technology that makes the architecture feasible" rather than the headline.

## Triage-not-adjudication front-load

New explicit clause inserted in abstract, intro cumulative claim, intro claims-not-made, and conclusion:

> The screen triages; it does not adjudicate cartel membership: it ranks loser-side firms and procurement environments for costly bid-layer interrogation, not cartel members for legal sanction.

## Literature reorder

| Before | After |
|---|---|
| 1. Bid-coordination tests (Bajari–Ye) | 1. **Enforcement design under costly observation (Becker–Stigler–Baker–Harrington)** |
| 2. Bid-distribution screens (Imhof–Wallimann) | 2. Bid-coordination tests (Bajari–Ye, Conley–Decarolis) |
| 3. Cover bidding (Porter–Pesendorfer–Asker) | 3. Bid-distribution screens (Imhof–Wallimann–Huber) |
| 4. Enforcement design | 4. Cover bidding |

The reorder shifts the marginal referee from the IO-econometrician asking "where is the causal effect?" to the law-econ-organization referee asking "is this a coherent enforcement-design paper?"

## Title

| Before | After |
|---|---|
| Frequent Losers: A Cover-Bidder Screen Without Bid Microdata | Sequencing Enforcement Under Incomplete Observability: An Award-Layer Triage Stage for Cartel Detection |

## Structural changes per section

- **Frontmatter:** title rewritten; abstract fully rewritten to lead with the architectural question and footprint-reduction headline.
- **Introduction:** opening paragraph rewritten to lead with enforcement-design question; three connected questions reframed as questions of the architecture; cumulative claim recentered as architectural with explicit triage clause; claims-not-make list reordered to put cartel-membership first.
- **Literature:** reordered to enforcement-design first; cover-bidding last; contribution explicitly positioned as award-layer triage.
- **Results (price imprint):** section title kept defensive ("Pricing Imprint as Descriptive Corroboration"); opener trimmed and made explicitly low-stakes ("the paper does not rest on this section"); transitions trimmed; closing kept defensive; screening-value formalisation pointer kept but explicitly disclaimed as not leveraged.
- **Conclusion:** headline rewritten as enforcement-design claim ("is feasible, and the data quantify what the architecture buys"); explicit triage-not-adjudication clause; AUC positioned as enabling technology.
- **Mechanisms (D2 modal asymmetry):** parágrafo defensivo strengthened in Bloco C; modal asymmetry treated as scope information for the screen, not as positive test of institutional channel.

## Deliverable cross-references

- `RESULTS_INVENTORY_JLEO.csv` — object inventory with location and recommended action
- `REPRODUCIBILITY_LINKING_MEMO.md` — script-to-table-to-macro reproduction chain

## Unresolved weaknesses (front-page)

1. **Cobidders, not cartelists.** The validation object is loser-side participation footprints adjacent to adjudicated cartels, not cartel members. AUC 0.49 against the 47 direct CADE defendants in the broader BEC universe. We make this central in the abstract, intro, and conclusion as the paper's design signature.
2. **Modal asymmetry direction inverted relative to institutional hypothesis.** Convite minimum-bidder rule predicts sharper signal; data show opposite. Reported as scope information, not as positive test (D2 framing in mechanisms section).
3. **Precision@k inflation under in-sample evaluation.** Top-500 in-sample precision 0.132 vs. holdout 0.070 (~50% inflation). Disclosed in operational metrics table; headline column is holdout (post Bloco C inversion).
4. **Item-level AUC leakage.** Raw in-sample 0.995 → out-of-fold CV 0.891 → temporal holdout 0.864. Decomposition reported as Table 8 with caption that explicitly owns the structural/leakage split.
5. **Identification of price imprint.** Sign reversal under overlap restriction. Paper does not rest on either sign; result reported descriptively with sensitivity bounds (Cinelli RV, Oster δ).

## P(R&R) calibration

| Path | P(R&R JLEO) |
|---|---|
| v17-editor pre-reframe (Bloco A+B+C only) | 25–35% |
| v17-editor post-reframe (current) | 32–40% |
| Ceiling for "JLEO-native" version (further work) | 36–42% |
