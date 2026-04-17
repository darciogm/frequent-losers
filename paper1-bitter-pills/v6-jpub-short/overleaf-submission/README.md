# Bitter Pills to Swallow — Overleaf submission package

JPubE Short Paper submission package for
**"Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"**
by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (Insper).

This archive is self-contained: every figure and table referenced by the
manuscript is included, all `\input{...}` and `\includegraphics{...}` paths
are relative to the project root, and the package compiles with a standard
`pdflatex + bibtex` toolchain on Overleaf (default compiler).

---

## File layout

```
overleaf-submission/
├── submission.tex             # main manuscript (body + refs, 27 pp)
├── OnlineAppendix.tex         # supplementary material (25 pp)
├── Appendix.tex               # sourced by OnlineAppendix.tex
├── Introduction.tex
├── InstitutionalBackground.tex
├── DataAndSample.tex
├── EmpiricalStrategy.tex
├── Results.tex
├── Conclusion.tex
├── References.bib
├── OnlineAppendix.aux         # pre-compiled label map (for xr)
├── tables/                    # 19 regression/descriptive tables
│   ├── tab_balance.tex
│   ├── tab_desc_stats.tex
│   ├── tab_neg_prices.tex
│   ├── tab_underthegun.tex
│   ├── tab_placebo.tex
│   ├── tab_supplier_fe.tex
│   └── ... (13 more)
├── figures/                   # 16 figures (pdf)
│   ├── fig_08_coefplot.pdf          # in body
│   ├── fig_event_study_honest.pdf   # in appendix (§A.5, honest DiD)
│   └── ... (14 maps + densities)
└── README.md (this file)
```

---

## How to build on Overleaf

The submission PDF uses `xr-hyper` to cross-reference labels defined in
the Online Appendix (three refs: `tab:placebo` → A.7,
`tab:het_competition` → A.15, `fig:event_study` → A.15). A pre-compiled
`OnlineAppendix.aux` is included in the archive so the submission
compiles correctly on the first pass.

**Recommended workflow on Overleaf:**

1. Upload the archive to a new Overleaf project (Menu ▸ New Project ▸
   Upload Project).
2. In *Menu ▸ Settings*, confirm that the **Compiler** is `pdfLaTeX` and
   the **Main document** is `submission.tex` (default) or
   `OnlineAppendix.tex` depending on which you want to compile.
3. If you edit the appendix (adds/removes tables or figures), the label
   numbering may shift. Recompile `OnlineAppendix.tex` first, then
   switch the main document back to `submission.tex` and recompile.
   Overleaf caches the `.aux` automatically within a project.

**Expected output:**

| Main document          | Output                              | Size     |
|------------------------|-------------------------------------|----------|
| `submission.tex`       | submission.pdf (27 pp, body + refs) | ~400 KB  |
| `OnlineAppendix.tex`   | OnlineAppendix.pdf (25 pp, supp.)   | ~4.2 MB  |

Both PDFs should match the versions included in this archive bit-for-bit
given the same TeX Live distribution.

---

## What to upload to Editorial Manager

JPubE's submission system expects separate files for the manuscript and
supplementary material. The recommended mapping is:

| EM slot                        | File                 |
|--------------------------------|----------------------|
| Main manuscript file           | `submission.pdf`     |
| Supplementary material         | `OnlineAppendix.pdf` |
| Source files (zipped, optional) | the whole archive    |

---

## Word / exhibit budget (JPubE Short Paper)

| Metric                         | Value | Limit       | Slack   |
|--------------------------------|-------|-------------|---------|
| Body words (excl. refs)        | 4,797 | 6,000       | 1,203   |
| Body + References              | 5,384 | 6,000*      | 616     |
| Abstract                       | 119   | 150         | 31      |
| Exhibits in body               | 5     | 5           | 0       |

\* JPubE's exact rule on whether the 6,000-word cap includes the
reference list varies across editions; this package respects the
stricter interpretation (body + refs ≤ 6,000) and stays within it.

**Exhibits in the body (5 total):**

1. Table 1 — Purchase Types: Institutional Characteristics (in
   `InstitutionalBackground.tex`, inline).
2. Table 2 — Negotiated Prices (`tables/tab_neg_prices.tex`).
3. Table 3 — Under the Gun: Admin vs. Litigated
   (`tables/tab_underthegun.tex`).
4. Table 4 — Demand vs. Supply Decomposition: Supplier FE
   (`tables/tab_supplier_fe.tex`).
5. Figure 1 — Coefficient Estimates, Preferred Specification
   (`figures/fig_08_coefplot.pdf`).

---

## Provenance & git history

This package was assembled from the working repo at
`bitter-pills/paper1-bitter-pills/v6-jpub-short/`. The manuscript source
lives under `manuscript/paper/`, tables under `v4/pub/tables/` and
`v6-jpub-short/output/tables/`, figures under `v4/pub/figures/` and
`v6-jpub-short/output/figures/`.

Recent commits relevant to this submission:

- `refs(bitter-pills): remove 12 orphan cites, fix 2 miscites, add 3 method refs`
- `feat(bitter-pills): R2 response — mediation reframe + body/appendix rebalance`
- `feat(bitter-pills): honest DiD event study — BJS + CS + HonestDiD sensitivity`
- `build(bitter-pills): submission.tex — JPubE Short Paper body-only compile`

---

## Troubleshooting

**Refs showing as `??` in submission.pdf.**
The `OnlineAppendix.aux` is missing or stale. In Overleaf: compile
`OnlineAppendix.tex` as the main document once, then switch back to
`submission.tex` and recompile.

**Missing fonts or packages.**
Submission uses `elsarticle` with `lmodern`, `natbib`, `hyperref`,
`booktabs`, `threeparttable`, `xr-hyper`, `tikz`, `caption`. All are
standard on Overleaf's TeX Live 2024+ image.

**"Undefined control sequence `\cites`".**
The `\cites` macro is defined in the preamble of each main TeX file
(line ~50). It is a convenience wrapper around `\citeauthor +
\citeyear`. Do not remove the definition.

---

*Last updated: 2026-04-17.*
