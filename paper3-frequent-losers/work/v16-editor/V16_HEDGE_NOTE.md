# V16 Hedge Note

**Date:** 2026-05-02.
**Purpose:** Create a v16 working environment for the next JLEO revision push, while preserving v15 as a recoverable hedge.

---

## What was preserved as v15

The full v15 manuscript package remains intact and unmodified at:

```
work/v15-editor/
├── paper_v15editor.tex                  ← master, main paper
├── paper_v15editor_online_appendix.tex  ← master, online appendix
├── paper_v15editor_highlights.tex       ← highlights bullet doc
├── paper_v15editor.pdf                  ← compiled main (47 pp)
├── paper_v15editor_online_appendix.pdf  ← compiled OA (22 pp)
├── sec_frontmatter_v15.tex
├── sec_introduction_v15.tex
├── sec_literature_v15.tex
├── sec_institutional_v15.tex
├── sec4_data_v15.tex
├── sec5_emp_v15.tex
├── sec_cade_v15.tex
├── sec_results_v15.tex
├── sec_mechanisms_v15.tex
├── sec_robustness_v15.tex
├── sec_forensic_v15.tex
├── sec_limitations_v15.tex
├── sec_conclusion_v15.tex
├── sec_endmatter_v15.tex
├── sec_appendix_v15.tex
├── tables/                              ← v15-specific tables (mccrary, conditional_descstats)
├── images/
└── *.md memos                           ← all v15-era memos preserved in place
```

v15 was verified to compile cleanly **after** v16 creation: `paper_v15editor.pdf` builds at 47 pages with zero LaTeX warnings (above the standard `natbib`/`hyperref Token` boilerplate that the existing infrastructure suppresses).

## What was created as v16

A parallel working environment at:

```
work/v16-editor/
├── paper_v16editor.tex                          ← copy of v15 master, inputs rewired
├── paper_v16editor_online_appendix.tex          ← copy of v15 master, inputs rewired
├── sec_*_v16.tex   (15 section files)           ← copies of all sec_*v15.tex with v16 names
├── values.tex                  → ../v13/values.tex          (symlink, shared)
├── values_adversarial.tex      → ../v13/values_adversarial.tex (symlink, shared)
├── references.bib              → ../v13/references.bib       (symlink, shared)
├── output                      → ../v13/output               (symlink, shared)
├── tables                      → ../v15-editor/tables        (symlink, shared)
├── images                      → ../v15-editor/images        (symlink, shared)
├── paper_v16editor.pdf                                       (compiled, 47 pp)
├── paper_v16editor_online_appendix.pdf                       (compiled, 22 pp)
└── V16_HEDGE_NOTE.md           (this file)
```

The master files were copied and rewired with `sed -i 's/_v15}/_v16}/g; s/v15editor/v16editor/g'`, which:
- Updates every `\input{sec_*_v15}` to `\input{sec_*_v16}`.
- Updates `\externaldocument{paper_v15editor_online_appendix}` to `\externaldocument{paper_v16editor_online_appendix}` and the symmetric reference in the OA master.

No section content was edited beyond the rename. The 15 section files in `work/v16-editor/sec_*_v16.tex` are byte-identical to their `_v15.tex` counterparts at the moment of v16 creation.

## Compile verification

| Document          | Pages | LaTeX warnings | Build path |
|-------------------|-------|----------------|------------|
| `paper_v15editor.pdf` (v15 main)        | 47    | 0 (post-natbib/hyperref filters) | `pdflatex × 3 + bibtex × 1`            |
| `paper_v15editor_online_appendix.pdf`   | 22    | 0              | `pdflatex × 2 + bibtex × 1 + pdflatex × 2` |
| `paper_v16editor.pdf` (v16 main)        | 47    | 0              | OA-first then main: `pdflatex OA → bibtex OA → pdflatex OA → pdflatex main → bibtex main → pdflatex main × 2 → pdflatex OA` |
| `paper_v16editor_online_appendix.pdf`   | 22    | 0              | (same combined sequence) |

Both versions compile **byte-equivalent** rendered content (524 KB each for the main PDF). The 6 KB difference between v15 and v16 main PDFs comes from PDF metadata (filename embedded in /CreationDate-adjacent fields) and aux-derived ordering, not content.

## Shared dependencies

The following are **shared via symlink** between v15 and v16 to prevent drift:

| Resource                       | Source of truth                | Read by                |
|--------------------------------|--------------------------------|------------------------|
| `values.tex`                   | `work/v13/values.tex`          | both v15 and v16       |
| `values_adversarial.tex`       | `work/v13/values_adversarial.tex` | both                |
| `references.bib`               | `work/v13/references.bib`      | both                   |
| `output/figures/*.pdf`         | `work/v13/output/figures/`     | both                   |
| `output/tables/tab_*.tex`      | `work/v13/output/tables/`      | both                   |
| `images/`                      | `work/v15-editor/images/`      | both (v16 reuses v15 cover) |
| `tables/tab_conditional_descstats.tex` | `work/v15-editor/tables/` | both              |
| `tables/tab_mccrary.tex`       | `work/v15-editor/tables/`      | both                   |

### Compatibility caveats

1. **Backward compatibility for v15:** any change in v16 to the shared `values.tex`, `references.bib`, table fragments, or figure PDFs will propagate automatically into v15. **If the v16 push edits any shared resource, v15 may render with the new content.** This is the intended behavior for `values.tex` and `references.bib` (the source-of-truth pipeline) but may matter if v16 introduces tables or figures with the same filenames as v15.

2. **If v16 needs to diverge a table or figure file, version-safe rules:**
   - Save the v16 variant under a new filename (e.g., `tab_imhof_full_v16.tex`) and update only the v16 `\input{}` paths.
   - Do **not** rename the v15 variant.
   - Document the divergence in this file under "v16 divergences" (currently empty).

3. **Building both at once:** the `xr` package cross-references between main and OA require the OA `.aux` to exist before the main paper compiles for the first time. The standard sequence (OA pdflatex+bibtex+pdflatex, then main pdflatex+bibtex+pdflatex+pdflatex, then OA pdflatex final) settles all references in both documents. Either v15 or v16 can be built independently using this sequence.

4. **No conflict with the published deploy site:** `darciogm.github.io/research/frequent-losers/paper.pdf` is currently the v15 build. v16 builds locally but is not yet deployed; only deploy v16 PDFs once the JLEO revision push has finished.

## v16 divergences from v15

(none yet — v16 was just created and is byte-identical to v15 in all section content)

## What v16 will be used for

The next JLEO revision push works in v16. v15 remains as a recoverable hedge in case the v16 changes prove counterproductive or introduce regressions; v15 can be built and deployed independently at any time.

---

*End of V16 hedge note. v16 environment is ready for substantive editing.*
