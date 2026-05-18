# V17 Hedge Note

**Date:** 2026-05-02.
**Purpose:** Open a v17 working environment for the Route 2 substantive
revision push, while preserving v16 intact as a recoverable hedge.

---

## What was preserved as v16

The full v16 manuscript package remains intact and unmodified at:

```
work/v16-editor/
├── paper_v16editor.tex                         ← master, main paper
├── paper_v16editor_online_appendix.tex         ← master, online appendix
├── paper_v16editor.pdf                         ← compiled main (572 KB)
├── paper_v16editor_online_appendix.pdf         ← compiled OA (447 KB)
├── sec_*_v16.tex   (15 section files)          ← all section content
├── tables → ../v15-editor/tables               (symlink)
├── images → ../v15-editor/images               (symlink)
├── output → ../v13/output                      (symlink)
├── values.tex → ../v13/values.tex              (symlink)
├── values_adversarial.tex → ../v13/values_adversarial.tex (symlink)
├── references.bib → ../v13/references.bib      (symlink)
└── *.md memos                                  ← all v16-era memos in place
    (V16_HEDGE_NOTE, ARGUMENT_SPINE_REBUILD, JLEO_REFRAME_FINAL,
     SIGN_REVERSAL_DECOMPOSITION, THEORY_VALIDATION_BRIDGE,
     MAIN_TEXT_APPENDIX_REBALANCE, REPRODUCIBILITY_LINKING_MEMO,
     RR_ACCEPTANCE_DIAGNOSIS, RR_MINOR_FEASIBILITY_MEMO,
     RESULTS_INVENTORY_ACCEPTANCE_PUSH)
```

v16 was the post-Subprompt-8 acceptance-push state. It compiles cleanly; do
not edit any file under `work/v16-editor/` while operating in v17.

## What was created as v17

A parallel working environment at:

```
work/v17-editor/
├── paper_v17editor.tex                          ← copy of v16 master, inputs rewired
├── paper_v17editor_online_appendix.tex          ← copy of v16 master, inputs rewired
├── sec_*_v17.tex   (15 section files)           ← byte-identical clones of sec_*_v16.tex
├── values.tex                  → ../v13/values.tex
├── values_adversarial.tex      → ../v13/values_adversarial.tex
├── references.bib              → ../v13/references.bib
├── output                      → ../v13/output
├── tables                      → ../v15-editor/tables
├── images                      → ../v15-editor/images
├── V17_HEDGE_NOTE.md           (this file)
├── ROUTE2_FEASIBILITY_AUDIT_v17.md
└── ROUTE2_REPO_INVENTORY_v17.csv
```

The masters were rewired with `sed -i 's/_v16}/_v17}/g; s/v16editor/v17editor/g'`,
which retargets every `\input{sec_*_v16}` to `\input{sec_*_v17}` and the
`\externaldocument{...}` cross-reference between main and OA.

No section content was edited at clone time. The 15 `sec_*_v17.tex` files are
byte-identical to their `sec_*_v16.tex` counterparts (verified for
`sec_introduction_v*.tex` via md5sum; the same `cp` operation was applied to
all sections).

## Compile verification

v17 has not yet been compiled. Subprompt 1 explicitly forbids manuscript
edits. The clone is for inspection and structural setup only. The first v17
compile happens after Route 2 edits begin (Subprompt 2 onward).

## Shared dependencies

Same source-of-truth pattern as v15→v16:

| Resource                        | Source of truth                | Read by                      |
|---------------------------------|--------------------------------|------------------------------|
| `values.tex`                    | `work/v13/values.tex`          | v13, v15, v16, v17           |
| `values_adversarial.tex`        | `work/v13/values_adversarial.tex` | v13, v15, v16, v17        |
| `references.bib`                | `work/v13/references.bib`      | v13, v15, v16, v17           |
| `output/figures/*.pdf`          | `work/v13/output/figures/`     | v13, v15, v16, v17           |
| `output/tables/tab_*.tex`       | `work/v13/output/tables/`      | v13, v15, v16, v17           |
| `images/`                       | `work/v15-editor/images/`      | v15, v16, v17                |
| `tables/tab_conditional_*.tex`  | `work/v15-editor/tables/`      | v15, v16, v17                |
| `tables/tab_mccrary.tex`        | `work/v15-editor/tables/`      | v15, v16, v17                |

### Compatibility caveats (for v17)

1. **Forward propagation.** Any v17 edit to `values.tex`, `references.bib`,
   `tables/`, or `output/figures/` propagates to v13, v15, and v16
   automatically. This is the intended behavior for the source-of-truth
   pipeline. **Before editing any shared resource in v17, decide whether
   the change should also flow into the older versions; if not, follow
   the divergence rule below.**

2. **Divergence rule (when v17 needs a different table/figure than v16).**
   Save the v17 variant under a new filename (e.g., `tab_imhof_full_v17.tex`)
   and update only the v17 `\input{}` paths. Never rename the v16 variant.
   Document each divergence under "v17 divergences" below.

3. **Building both at once.** The `xr` package cross-references between main
   and OA require the OA `.aux` to exist before the main paper compiles for
   the first time. Standard sequence: pdflatex OA, bibtex OA, pdflatex OA;
   then pdflatex main, bibtex main, pdflatex main, pdflatex main; then
   pdflatex OA final.

4. **Deploy site separation.** `darciogm.github.io/research/frequent-losers/`
   currently points at the v15 build (per `feedback_deploy_paper3.md`). v17
   is for offline revision; do not deploy v17 PDFs until the JLEO submission
   package is final.

## v17 divergences from v16

(none yet at clone time — v17 sections are byte-identical to v16)

## What v17 will be used for

The Route 2 substantive revision push works in v17. v16 remains as a
recoverable hedge in case Route 2 introduces regressions or interpretive
overreach that proves indefensible; v16 can be built and deployed
independently at any time.

The Route 2 push is gated by the feasibility audit in
`ROUTE2_FEASIBILITY_AUDIT_v17.md` (this directory). Subprompt 1 produces the
audit only; Subprompts 2+ execute the substantive edits, conditional on the
audit's recommendation.

---

*End of V17 hedge note. v17 environment is ready for the feasibility audit
and, conditional on its recommendation, for substantive Route 2 editing.*
