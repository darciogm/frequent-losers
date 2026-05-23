# Author Checklist for Final Submission

*Paper:* **Cheap Signals, Costly Proof: Award-Layer Evidence Triage in Cartel Enforcement** — JLEO submission, v18-editor line. Last updated 2026-05-23.

## Deliverables

- [x] `paper_submission_JLEO_final.pdf` — **39 pp** (body ≈ 36 pp, references pp 37–39).
- [x] `online_appendix_submission_JLEO_final.pdf` — **21 pp** (Appendices A–G; D.3 = Volume-Matched Within-FL Profile).
- [x] `cover_letter_JLEO_submission.md`.
- [x] Stale `*_clean_final.pdf` (May 19) removed; `*_clean.pdf` retained as build artifacts. No ambiguous versions in the folder.

## Compilation / integrity (verified)

- [x] Both PDFs compile clean via the `xr` cross-document sequence (`pdflatex appendix → main → appendix → main`); existing `.bbl` reused (no new citations).
- [x] Zero undefined references, zero undefined citations, zero multiply-defined labels.
- [x] `pdftotext` validation searches return **0 hits** in both PDFs for: `V19 | TODO | VERIFY | Appendix Appendix | mechanism is operative | identifies the mechanism | damages estimate | ?? | §??`.
- [x] All appendix cross-references resolve (B, D, D.2, D.3, D.4, D.6, E.2, E.3); §5 → Appendix D.3 resolves.

## Lexical discipline (verified)

- [x] No unbounded use of detect/identify/proof/membership/cover-bidder/damages/overcharge/markup/welfare/causal/outperforms/dominates/mechanism. Every occurrence is bounded/negative/necessary ("not a generic cartel-membership detector", "does not identify the mechanism", "proof-producing", "not an outperformance claim", "not a damages calculation").
- [x] Abstract: "validation audits" (not "exposure audits"); "opportunity-set exposure" (not "procurement overlap"); retains "legal proof", "forensic priority, not cartel membership", "83%", "131 of 193"; no AUC, no price magnitudes, no R\$ figures.

## Structure / scope (verified)

- [x] §4 = validation architecture; the Three-Classifier Timing Battery, Universe-Anchored Scope Matrix, and full sham/price-under-sham detail are in Appendix D (D.2/D.4/D.6). Main-text `Validation Architecture` threat table retained.
- [x] §7 = scope/limits; monetary scope (R\$ range) and the full sign-reversal decomposition table moved to Appendix E (E.2/E.3); one bounded sentence in the body. Price framed as scope evidence, not damages.
- [x] §5 carries the volume-matched cobidder result (structural distinctness survives matching on `tenders_count`, SMD 0.49→0.00); bid-conduct stated as single-channel with dispersion (AN-041) and timing (AN-042) as documented nulls. Full matched-difference table in Appendix D.3. Macros `\valVM*` added to `values.tex`.
- [x] Appendix D.2 retains the honest statement that no standalone product-by-buyer-by-year-by-modality matched recomputation of the cobidder AUC exists in the executable audit trail.

## Cover letter (verified)

- [x] Emphasizes evidence allocation under incomplete observability, award-layer triage before bid-layer forensics, BEC + CADE, validation target = adjudication-anchored cobidders (not membership), 83% / 131 of 193, JLEO fit.
- [x] Does **not** mention monetary price-side scope, AUCs, cover-bidder identification, or damages.
- [x] ComprasNet replication removed (held for revision); external-validity paragraph states only that promotion beyond a single-source reading needs a non-BEC panel.

## Paper site (synced + deployed)

- [x] AN pages, hypotheses, findings reconciled to the "descriptive scope evidence, not mechanism identification" framing.
- [x] H5 (cobidder-profile-distinct) = **Partial (strongly supported)**, structural scope; AN-021/AN-032 re-labelled scope limits; AN-041 (volume-matched) and AN-042 (timing null) added; indexes regenerated.
- [x] Deployed and verified live (HTTP 200; H5 shows "Partial (strongly supported)"): `darciogm.github.io/research/working-papers/`, `…/research/frequent-losers/`, and standalone `darciogm.github.io/frequent-losers/`.

## Reproducibility (verified)

- [x] Participation-sham seed in `scripts/25_sham_fl_permutation.R`: `set.seed(20260430)`.
- [x] Volume-matched audits seeded: `scripts/74_volume_matched_cobidder_audit.R` and `scripts/75_volume_matched_timing_audit.R`: `set.seed(20260523)`.
- [x] Every numeric claim bound to a `\valXxx` macro in `values.tex`.

## Author actions before submission (to do)

- [ ] **Read-through** of `paper_submission_JLEO_final.pdf` and the appendix end-to-end.
- [ ] Confirm comfort with the body landing at 39 pp (one page above the 30–35 target). To approach 35 would require compressing §4–§7 or trimming references — not done, as both touch protected content.
- [ ] Confirm the H5 framing (structural distinctness *strongly supported*; bid-conduct single-channel; mechanism reading explicitly not asserted) reads as intended in §5.
- [ ] Decide whether to fold the ComprasNet contingency appendix into the submission or keep it for the revision (currently absent from the v18 line).
- [ ] Final author sign-off on author order, affiliations, acknowledgements, and JEL codes in the front matter.
