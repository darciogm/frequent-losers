# 09 — SUBPROMPT 3 LOG: Sections 1–3 front-end revision (JLEO R&R v22)

Date: 2026-06-02. Agent: mr-frequent-losers (Co-Author mode). Branch: **`v22`**.

## Branch decision
Prompt allowed "be on the revision branch created earlier, **or** create `rr_jleo_sections_1_3`."
**Stayed on `v22`** — it *is* the revision branch (Subprompts 1–2 committed here: `b619e4b`, `c2b00cc`, `3924d60`).
Creating a sub-branch would fragment the R&R history and break the docs' "all work on branch v22" invariant. Paper3 working tree was **clean** at start (the 381 dirty files in `git status` are all paper1/paper2/paper18 — confirmed via `git status --porcelain`). No uncommitted paper3 user work at risk.

## Manuscript source (from 00_REPO_AUDIT §B)
- Master: `submission_clean/paper_submission_clean.tex` (elsarticle, natbib/bibtex, `\input{values.tex}`).
- Abstract: `sec_frontmatter_submission.tex`. §1 `sec01_…`, §2 `sec02_…`, §3 `sec03_…`.
- Fig 1 source: `submission_clean/make_submission_figures.R` (R/ggplot, cairo_pdf) → `output/figures/fig_data_coarsening.pdf`.

## Starting observation (mr-frequent assessment)
The v20-seeded front end was **already substantially JLEO-reframed** (intro foregrounds enforcement design; `T_i`/`W_i` already defined in §3.1; Fig caption already says "information-cost diagram, not a detector horse race"; "adjudication-anchored exposure" already in §2.3/§3). Subprompt 3 is therefore a **surgical polish + JLEO-compliance pass**, not a rewrite. Edits are tagged `% CO-AUTHOR EDIT:` per project rule 6.

## Verified macros (no invention)
`\valCobidders`=193, `\valGateFootprintPct`=83\%, `\valGateSeqKTwoKOneTPIn`=131, `\valDirectCADE`=47, `\valBECfirms`=41,444, `\valAlwaysLosers`=16,843, `\valFL`=2,735, `\valThreshold`=14, `\valThresholdStat`=13.5, `\valFLrateAL`=16.2\%, `\valSampleN`=1,654,401, `\valYearStart`=2009, `\valYearEnd`=2019, `\valLeiPregao`=10.520/2002, `\valConservativeCobidders`=210 (RETIRE-pending), `\valConservativeFD`=30 (DROP→19 per U2).

## U2 framing (locked, from 05_BLOCKERS)
Keep **193** as headline primary cobidder target; **341** transparent script-79 funnel = reproducible robustness target; disclose absent builder + definitional inconsistency; **drop 30→19** conservative defendants. Do NOT assert "results materially unchanged" until a core AUC is re-run under the 341 label (front-end uses forward-looking language only).

---

## FAN-OUT EXECUTION (4 disjoint file-streams, parallel subagents)
- Stream A: `sec_frontmatter` (abstract) + `sec01` (intro) + new `abstract_alternatives.md`.
- Stream B: `sec02` (setting/layers + Table 1 + Fig 1 caption/alt text).
- Stream C: `sec03` (triage + Table 2 threat map).
- Stream D: `make_submission_figures.R` Fig 1 relabel + regen.

### Files read (pre-fan-out)
- All 8 setup docs (00–08), `output_manifest.txt`.
- `sec_frontmatter_submission.tex`, `sec01_…`, `sec02_…`, `sec03_…`, `make_submission_figures.R`, `values.tex` (macro grep).

### Files edited
- `submission_clean/sec_frontmatter_submission.tex` — abstract rewritten (187→**137 words**, ≤150 ✓).
- `submission_clean/sec01_introduction_submission.tex` — terminology + skeptic-objection sentence + TODO.
- `submission_clean/sec02_setting_layers_submission.tex` — §2.2 T_i/Pregão footnote, cost-wedge TODO, Fig 1 caption + alt text, §2.3 title + terminology + funnel TODO, Table 1 → 4 columns (added Legal interpretation).
- `submission_clean/sec03_award_layer_screen_submission.tex` — §3.1 Pregão/T_i clause, §3.2 auditable-implementation wording, Table 2 → 6-column 10-row validation-threat map, §3.3 forward-looking prose + TODOs.
- `submission_clean/make_submission_figures.R` — Figure 1 relabel (5 strings) + regen of `output/figures/fig_data_coarsening.pdf`.
- NEW `docs/jleo_rr_revision/abstract_alternatives.md` (Versions A/B/C, word counts).

### Exact sections edited
Abstract; §1 Introduction (contribution + skeptic objection + terminology); §2 intro roadmap; §2.2 (T_i footnote, cost wedge, Fig 1); §2.3 (title, terminology, funnel TODO); Table 1; §3.1; §3.2; §3.3; Table 2.

### Claims removed / softened (sections 1–3)
- Abstract: "ranks loser-side **cartel-adjacency risk**" → "ranks priority among zero-win firms … target is **adjudication-anchored exposure**, not cartel membership."
- Abstract: single "83%" pool-reduction headline → "concentrates the bid-microdata pool" (percentage demoted to parenthetical; survives later cost-recall revision).
- §1: "loser-side **adjacency** target" → "**adjudication-anchored loser-side exposure** target"; "the adjacency target economic content" → "the **exposure** target"; added canonical skeptic objection ("high-volume zero-win firms may simply have more opportunities to meet CADE defendants") with forward-looking (not-resolved) framing.
- §2 roadmap + §2.3 target sentence + Table 1 cobidder row: "**cartel-adjacent** loser-side firms" → "always-loser cobidders" / "adjudication-anchored exposure"; subsection retitled "CADE Anchors and **Adjudication-Anchored Exposure Labels**".
- §3 prose: Table 2 reframed as a **pre-analysis validation-threat map** (no results), explicitly "not a results table."
- **Net:** zero affirmative forbidden terms (scanner critical=0). No existing affirmative claim was strengthened.

### TODOs inserted (LaTeX comments only; invisible in PDF)
- `sec_frontmatter:27` `TODO_JLEO_RR_REVALIDATE_NUMBER` (gatekeeper footprint/recall/cobidder-target after cost frontier).
- `sec01:128` `TODO_JLEO_RR_REVALIDATE_NUMBER` (same).
- `sec02` `TODO_JLEO_RR_COST_FRONTIER` (cost wedge to be substantiated by later prompt) + `TODO_JLEO_RR_LABEL_FUNNEL` (12/65/47/193 reconciliation; 193 primary + 341 robustness; 30→19).
- `sec03:75` `TODO_JLEO_RR_COST_FRONTIER` (K1 grid); `sec03:115` `TODO_JLEO_RR_OPPORTUNITY_TABLE` (§4.2 answers the exposure threat).
- (TODO comments reworded to drop digit literals so they stop tripping `scan_numbers`.)

### Commands run
- `git status --porcelain` (paper3 tree clean); macro grep on `values.tex`.
- `make diagnostics` (claims/numbers/refs/alt-text + metrics test 22/22 PASS).
- `Rscript make_submission_figures.R` (Fig 1 regen — exit 0, cairo_pdf OK, PDF 29,990 B, new mtime).
- Compile: appendix `pdflatex`; paper `pdflatex → bibtex → pdflatex ×3`.

### Build result
**PASS.** `paper_submission_clean.pdf` = **43 pages** (was 42; expanded Table 2 added one). **0 LaTeX errors, 0 undefined refs/citations, 0 overfull hboxes** (the one 38pt Table-2 overfull from `item×buyer×year×modality` was fixed by rewording the cell). Figure 1 → p9; Table 1 (4-col) → p11; Table 2 (threat map) → p15. `pdftotext` confirms **Alt text** and the Table 2 caption render in the PDF.

### Scanner state (post-edit, `make diagnostics`)
- claims: 83 hits, **critical=0**, high=27 (all in §7 price — untouched here), 23 negated/disclaimer. No affirmative flips.
- numbers: 68 hits, 8 hardcoded(check) — back to baseline; the only sec 1–3 hardcoded literal is the pre-existing `65` (CADE firm-defendants, sec02:166) covered by the LABEL_FUNNEL TODO.
- alt-text: 2 figs, **1 missing** = Figure 2 (temporal holdout, §4) — out of scope for Subprompt 3 (Step 7 covers Fig 1 only); flagged for the later compliance prompt.
- refs: 0 used-but-missing, 1 defined-but-uncited (pre-existing minor).

### Unresolved issues (carried forward)
1. **Fig 1 still shows two AUCs (0.888 / 0.903)** side-by-side while the caption says "not a horse race" — minor tension. Left intact (real, macro-consistent values; removing them is an empirical-presentation call beyond this front-end prompt). Flag for Prompt 7/8.
2. **Table 1 / §2.3 counts (12/65/47/193)** not yet reconciled — gated on Subprompt 4A label funnel (TODO in place; tablenote says "counts will be reconciled").
3. **Figure 2 alt text** + Bluebook cites + double-spacing = later JLEO compliance prompt (12).
4. Gatekeeper 83%/131/193 carry REVALIDATE TODOs pending the cost-recall frontier (Prompt 8).
