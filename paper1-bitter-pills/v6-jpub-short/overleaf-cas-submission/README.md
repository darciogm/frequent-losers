# Bitter Pills --- Overleaf + Elsevier CAS submission package

Overleaf-ready archive for **"Bitter Pills: The Enforcement
Costs of Health Litigation"** (Darcio Genicolo-Martins & Paulo Furquim
de Azevedo, Insper), typeset with the modern **Elsevier CAS
single-column** class (`cas-sc`).

This is the preferred submission variant: it follows Elsevier's
2024+ recommendation for JPubE, comes with highlights and CRediT
statements pre-wired, and uploads to Overleaf as a single `.zip`
with no manual configuration.

---

## Upload workflow (Overleaf)

1. Zip this directory (or use `bitter-pills_overleaf-cas_2026-04-17.zip`
   supplied one level up).
2. In Overleaf: *Menu ▸ New Project ▸ Upload Project* → select the zip.
3. In *Menu ▸ Settings*: set **Compiler** = `pdfLaTeX` (default),
   **Main document** = `submission.tex`.
4. Click *Recompile*. Expected output: **12-page** `submission.pdf`.
5. To build the supplementary material, change **Main document** to
   `OnlineAppendix.tex` and recompile. Expected output: **20-page**
   `OnlineAppendix.pdf`.

The `.cls`, `.sty`, `.bst`, and `thumbnails/` files are bundled so no
Overleaf-side package installation is needed.

---

## Layout

```
overleaf-cas-submission/
├── submission.tex              # main manuscript (cas-sc) → 12 pp
├── OnlineAppendix.tex          # supplementary material    → 20 pp
├── Appendix.tex                # sourced by OnlineAppendix.tex
├── Introduction.tex
├── InstitutionalBackground.tex
├── DataAndSample.tex
├── EmpiricalStrategy.tex
├── Results.tex
├── Conclusion.tex
├── References.bib
│
├── cas-sc.cls                  # Elsevier CAS single-column class
├── cas-common.sty              # CAS support package
├── cas-model2-names.bst        # CAS author-year BibTeX style
├── thumbnails/                 # cas-sc email/social icons (6 jpeg)
│
├── tables/                     # 19 LaTeX tables
│   ├── tab_neg_prices.tex             (body)
│   ├── tab_underthegun.tex            (body)
│   ├── tab_supplier_fe.tex            (body)
│   ├── tab_placebo.tex                (appendix A.7)
│   ├── tab_balance, tab_desc_stats,
│   │   tab_firms, tab_quantities,
│   │   tab_success, tab_ref_prices    (appendix A.0)
│   ├── tab_rob_{ref_prices,neg_prices,
│   │   firms,success,utg}             (appendix A.1-A.2)
│   └── tab_het_{sus,period,
│       competition,pbu}               (appendix A.6)
│
├── figures/                    # 16 PDF figures
│   ├── fig_08_coefplot.pdf            (body, Figure 1)
│   ├── fig_event_study_honest.pdf     (appendix §A.5)
│   └── 14 more (maps, densities)
│
├── submission.pdf              # reference output
├── OnlineAppendix.pdf          # reference output
└── README.md                   # this file
```

---

## What's in the submission

**Body (12 pp, 4,947 words):**
1. Introduction
2. Institutional Background (includes Table 1: purchase-type matrix)
3. Data and Sample
4. Empirical Strategy (references honest-DiD event study in appendix)
5. Results:
   - §5.1 Enforcement Costs on Negotiated Prices (**Table 2**)
   - §5.2 Competition and Tender Success
   - §5.3 The "Under the Gun" Effect (**Table 3**)
   - §5.4 Falsification (prose, results in appendix Table A.7)
   - §5.5 Demand vs. Supply Decomposition (**Table 4**, supplier FE)
   - §5.6 Where the Cost Bites Hardest (prose, competition het)
   - §5.7 Summary of Effects (**Figure 1**, coefficient plot)
6. Conclusion

**Highlights (5 bullets)** — rendered as a bulleted list on the title
page by cas-sc; EM extracts them automatically.

**CRediT authorship** — `\credit{...}` per author. `\printcredits`
produces the CRediT section at the end of the body.

**Online Appendix (20 pp)** — descriptives, balance, secondary outcome
tables (A.0), winsorization robustness (A.1), UTG progressive controls
(A.2), distributional evidence (A.3), admin geography (A.4), honest-DiD
event study (A.5, **Figure A.15**), heterogeneity (A.6).

---

## JPubE fit

| Metric                           | Value | Limit | Slack   |
|----------------------------------|-------|-------|---------|
| Body words (excl. refs)          | 4,947 | 6,000 | 1,053   |
| Abstract                         | 119   | 150   | 31      |
| Exhibits in body                 | 5     | 5     | 0       |
| Typeset pages (cas-sc)           | 12    | ~15   | 3       |

---

## Known quirks

1. **`expl3` compatibility patch** at the top of `submission.tex` and
   `OnlineAppendix.tex`. cas-sc.cls (2021) calls
   `\vbox_unpack_clear:N`, which LaTeX3 removed in 2023. Six lines
   of patch alias it to `\box_unpack_drop:N`. Drop this patch if a
   future CAS release uses the new primitive name natively.

2. **Hardcoded appendix refs.** The three body→appendix
   cross-references (`tab:placebo` → A.7, `tab:het_competition` →
   A.15, `fig:event_study` → A.15) are written as literal
   `Table~A.7` etc. in the prose. `xr-hyper` was tried but it
   triggered natbib "multiply defined citation" warnings. If the
   appendix is reordered, update the three hardcoded numbers in
   `EmpiricalStrategy.tex` and `Results.tex`.

3. **OA standalone refs.** `OnlineAppendix.pdf` prose refers to
   `Section 2 of the main text` and `Table 2 of the main text` as
   literal strings, so OA compiles without undefined-reference
   warnings. Update if the section order of the main text changes.

4. **Label type mismatch fix.** The Purchase Types matrix in
   `InstitutionalBackground.tex` used `\label{fig:purchase_types}`
   inside `\begin{table}` originally; pdf prose then read "Figure 1"
   for a table. Fixed to `\label{tab:purchase_types}`.

---

## Editorial Manager upload checklist

| EM slot                                | File / source                                 |
|----------------------------------------|-----------------------------------------------|
| Main manuscript file                   | `submission.pdf`                              |
| Supplementary material                 | `OnlineAppendix.pdf`                          |
| LaTeX source (zipped)                  | this archive                                  |
| Highlights (separate EM field)         | copy from `\begin{highlights}` in submission.tex |
| CRediT taxonomy                        | auto-extracted by EM from `\credit{}` lines  |
| Cover letter                           | supply separately                             |
| Conflict of interest declaration       | supply separately                             |

---

## Alternative: elsarticle (legacy)

If a reviewer or editor prefers the double-spaced review format rather
than CAS, use the parallel
`v6-jpub-short/overleaf-submission/` archive, which runs the same
content through `elsarticle` and produces a 27-page
`submission.pdf`. CAS is recommended.

---

*Last updated: 2026-04-17.*
