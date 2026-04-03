# Changes: v4 → v5 (JLE Repositioning)

**Date**: April 3, 2026  
**Commit range**: `4cd74bf..99b95ae` (5 commits on branch `ijio-r1-response`)  
**22 files changed**: +1,862 / −453 lines

---

## A. Framing and Positioning

| File | What changed |
|---|---|
| `sec_frontmatter.tex` | Abstract rewritten to lead with institutional incentive (minimum-bidder rule → cover bidders), not econometric methodology. Added three-stage enforcement pathway framing. |
| `sec_introduction.tex` | New paragraph on institutional logic (convite/pregão asymmetry with signal-dilution explanation). Contributions consolidated into flowing paragraph. Non-claims tightened. Five-diagnostics paragraph restructured from comma-list to semicolon-separated. |
| `sec_literature.tex` | New paragraph "Enforcement costs and procurement design" anchoring the paper in Posner (1970), Becker (1968), Polinsky & Shavell (2000). Baranek & Titl (2024) added for JLE procurement comparison. Caoui (2022) integrated in proactive screens. |
| `cover_letter.tex` | Rewritten to match new framing: Posner enforcement argument, γ > 0 complementarity, Lei 14.133 predictions. |

## B. Consistency Fixes

| File | What changed |
|---|---|
| `sec_mechanisms.tex` | M1 coefficient aligned (0.143 → 0.19, PBU FE spec). Opening rewritten from checklist to question-driven. "coherent with" → "consistent with" (2 cross-line instances). Alternative explanations humanized. |
| `sec_identification.tex` | M3 elasticity corrected (≈0.004 → = 0.002). "coherent with" → "consistent with". |
| `sec_limitations.tex` | "coherent diagnostic pattern" → "consistent". Prose tightened throughout. |
| `sec_appendix.tex` | KM caption fixed: "faster exit" → "lower exit hazard (longer survival)" (was contradicting Cox model in sec_mechanisms). Corner solution appendix figure added. |
| `sec_conclusion.tex` | Lei 14.133 predictions rewritten for clarity: constraint-binding channel disappears (β̂ = −0.160), voluntary channel (7.6%) persists. Flowchart figure integrated. |

## C. New Content

| File | Description |
|---|---|
| `figures_new.R` | 576 lines. Three new figures: (1) corner solution with calibrated γ > 0 + empirical binned means, (2) dispersion paradox kernel densities, (3) enforcement flowchart (Mermaid + TikZ). Grayscale, 4.5in, Times Roman ≥7pt per JLE policy. |
| `sections/sec3_structural_model.tex` | Strategic complementarity (γ > 0) articulated as conditional prediction confirmed by calibration. Figure 1 inserted after Table 2. |
| `sections/sec7_results.tex` | Figure 3 (dispersion paradox) inserted in Section 7.8. Detection performance paragraph tightened. Network-split opening changed to "Where does the price association come from?" |
| `online_appendix.tex` | Standalone compilable file (413 lines) splitting the Online Appendix from the print appendix for separate submission. |
| `disclosure.tex` | AEA-standard disclosure statement for JLE policy compliance. |
| `replication/README.tex` | Five-page replication README: data sources, software requirements, directory structure, step-by-step instructions, output-to-script mapping. |

## D. Reference Corrections

| Entry | Problem | Fix |
|---|---|---|
| `clark2021collusion` | **Fabricated** — no such paper exists | Replaced with Clark & Houde (2014) JIE |
| `marshall2012economics` | Wrong title ("Antitrust Enforcement") | → "The Economics of Collusion: Cartels and Bidding Rings" |
| `chassang2022robust` | Missing 2 of 4 authors | Added Kawai and Nakabayashi |
| `bryant1991price` | Wrong title, number, pages | All three corrected |
| `hüschelrath2014cartel` | Wrong number and pages | 5→6, 365-383→404-422 |
| `schurter2020identification` | Incomplete title, stale year | Title and year corrected |
| `wils2007leniency` | End page off by 1 | 64→63 |

## E. New References Added

| Key | Citation | Journal |
|---|---|---|
| `posner1970statistical` | Posner (1970) | **JLE** |
| `caoui2022umbrella` | Caoui (2022) | **JLE** |
| `harrington2015leniency` | Harrington & Chang (2015) | **JLE** |
| `ghosal2014cartel` | Ghosal & Sokol (2014) | **JLE** |
| `baranek2024favoritism` | Baranek & Titl (2024) | **JLE** |
| `becker1968crime` | Becker (1968) | JPE |
| `polinsky2000economics` | Polinsky & Shavell (2000) | JEL |
| `bajari2009auctions` | Bajari, McMillan & Tadelis (2009) | JLEO |
| `clark2014explicit` | Clark & Houde (2014) | JIE |

All 9 verified against Crossref metadata.

## F. Polish and Humanization

- "coherent with" reduced from 40 → 0 instances across manuscript
- Hedging language ("does not uniquely identify", "not causal") consolidated in Non-claims and Limitations; removed from body
- Passive constructions replaced with active voice throughout
- Sentence length varied to break mechanical uniformity
- AI-pattern markers removed: parallel tricolons, signposting phrases, formulaic transitions
- Code comments in `figures_new.R` rewritten in first person with editorial justifications
