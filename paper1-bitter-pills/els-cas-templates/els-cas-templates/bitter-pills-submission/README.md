# Bitter Pills to Swallow --- Elsevier CAS submission package

JPubE Short Paper submission package for
**"Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"**
(Darcio Genicolo-Martins & Paulo Furquim de Azevedo, Insper),
typeset with Elsevier's **CAS single-column** class (`cas-sc`).

This is the canonical submission variant, intended for upload to
Elsevier's Editorial Manager for JPubE. The class file and supporting
files are bundled so the package compiles out of the box with
`pdflatex + bibtex` on any TeX Live 2023+ distribution.

---

## Layout

```
bitter-pills-submission/
├── submission.tex              # main manuscript (cas-sc) --> 12 pp
├── OnlineAppendix.tex          # supplementary material    --> 20 pp
├── Appendix.tex                # sourced by OnlineAppendix.tex
├── Introduction.tex
├── InstitutionalBackground.tex
├── DataAndSample.tex
├── EmpiricalStrategy.tex
├── Results.tex
├── Conclusion.tex
├── References.bib
│
├── cas-sc.cls                  # Elsevier CAS single-column class (bundled)
├── cas-common.sty              # CAS support package        (bundled)
├── cas-model2-names.bst        # CAS author-year BibTeX     (bundled)
│
├── thumbnails/                 # cas-sc email/social icons
├── tables/                     # 19 LaTeX tables
└── figures/                    # 16 PDF figures
```

---

## How to compile

On Overleaf: upload as a project and set `submission.tex` as the main
document.

On a local TeX Live 2023+ install (recommended):

```bash
# Online Appendix first (generates .aux that *could* be used by xr)
pdflatex OnlineAppendix.tex
bibtex   OnlineAppendix
pdflatex OnlineAppendix.tex
pdflatex OnlineAppendix.tex

# Main submission
pdflatex submission.tex
bibtex   submission
pdflatex submission.tex
pdflatex submission.tex
```

Expected output:

| File                 | Pages | Notes                                          |
|----------------------|-------|------------------------------------------------|
| `submission.pdf`     | 12    | title + abstract + highlights + body + refs   |
| `OnlineAppendix.pdf` | 20    | supplementary tables and figures              |

Both PDFs compile with zero undefined-reference or multiply-defined
warnings.

---

## Adaptations from the `elsarticle` draft

The main manuscript was originally written for the legacy `elsarticle`
class. For Elsevier's newer CAS workflow a handful of preamble
conversions were applied; the body prose is **identical** to the
`elsarticle` version:

| `elsarticle` construct                   | `cas-sc` equivalent                   |
|------------------------------------------|---------------------------------------|
| `\begin{frontmatter} ... \end{frontmatter}` | `\maketitle` (with mark-before-author) |
| `\title{...}` + `\tnoteref{t1}`          | `\title[mode=title]{...}` + `\tnotemark[1]` |
| `\author[INSPER]{...}\ead{...}`          | `\author[1]{...}\ead{...}\affiliation[1]{...}` |
| `\cortext[cor1]{...}`                    | `\cormark[1]` + `\cortext[1]{...}`     |
| `\begin{keyword} ... \JEL ...`           | `\begin{keywords} ... \end{keywords}` + prose JEL line |
| `\bibliographystyle{elsarticle-harv}`    | `\bibliographystyle{cas-model2-names}` |
| (no highlights)                          | `\begin{highlights} ... \end{highlights}` (5 bullet points added) |
| (no credit taxonomy)                     | `\credit{...}` (CRediT statement per author, `\printcredits`) |

A small `expl3` compatibility patch is included at the top of
`submission.tex` and `OnlineAppendix.tex` to alias
`\vbox_unpack_clear:N` (removed from LaTeX3 in 2023) to
`\box_unpack_drop:N`, so the CAS class's `\maketitle` code keeps
working on modern TeX Live. Drop this block once you upgrade to a
CAS version that no longer uses the removed primitive.

---

## Cross-reference handling

The body text refers to three objects that live only in the Online
Appendix: `tab:placebo` (A.7), `tab:het_competition` (A.15), and
`fig:event_study` (A.15). To keep each PDF independently compilable
without `xr-hyper` (which produces noisy *multiply-defined citation*
warnings when it imports `\bibcite` entries), those three refs are
**hardcoded as `Table~A.7`, `Table~A.15`, `Figure~A.15`** in the prose.
If the Online Appendix is reordered, update the three hardcoded numbers
in `EmpiricalStrategy.tex` and `Results.tex`.

Conversely, the appendix refers to `Section~2 of the main text` and
`Table~A.3` (rendered as hardcoded strings) instead of via `\ref`, so
OA compiles standalone without undefined-reference warnings.

---

## Word / exhibit budget (JPubE Short Paper)

| Metric                           | Value | Limit | Slack   |
|----------------------------------|-------|-------|---------|
| Body words (excl. refs)          | 4,947 | 6,000 | 1,053   |
| Abstract                         | 119   | 150   | 31      |
| Highlights (bullet count)        | 5     | --    | --      |
| Exhibits in body                 | 5     | 5     | 0       |
| Typeset pages (cas-sc, single)   | 12    | ~15   | 3       |

**Body exhibits (5):** Table 1 (purchase-type matrix, inline in
InstitutionalBackground); Table 2 (`tab_neg_prices`); Table 3
(`tab_underthegun`); Table 4 (`tab_supplier_fe`); Figure 1
(`fig_08_coefplot`).

The CAS single-column layout is roughly half the page-count of the
elsarticle double-spaced review version (55 pp → 12 pp), giving a
comfortable margin against the JPubE page cap.

---

## Editorial Manager upload

| EM slot                                | File                    |
|----------------------------------------|-------------------------|
| Main manuscript file                   | `submission.pdf`        |
| Supplementary material --- appendix    | `OnlineAppendix.pdf`    |
| Source files (zipped, optional)        | the whole archive       |
| Highlights (separate upload field)     | copy from `\begin{highlights}` in `submission.tex` |
| CRediT taxonomy                        | taken automatically by EM from `\credit{}` lines |

---

*Last updated: 2026-04-17.*
