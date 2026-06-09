# JHE Base-Papers Positioning — Summary (2026-06-09)

Small, strategic repositioning so a JHE editor sees the paper's lineage at once:
base = JHE hospital-closure/access/mortality literature (Buchmueller et al. 2006,
Avdic 2016); Dias & Fontes (2024) = Brazilian psychiatric-reform context, not base.
No new literature-review section; net +1 page.

## References already present (kept, re-used)

- `avdic2016` — Avdic (2016), JHE 48, 44–60. Now framed as a base paper, not a list item.
- `wang2020hrr` — Wang et al. (2020), Annals of GIS — HRR boundary evaluation (flow-market).
- `diasFontes2024` — Dias & Fontes (2024), AEJ:EP 16(3), 257–289 — repositioned as CONTEXT.
- `doyle2011` — Doyle (2011), AEJ:Applied 3(3), 221–243 — already used (discussion, cross-sectional caution).
- US closure cluster: `carroll2019, joynt2015, gujralBasu2019, lindrooth2018`.

## References added (all web-verified before insertion; no fabrication)

- `buchmueller2006` — Buchmueller, Jacobson & Wold (2006), **JHE 25(4), 740–761**,
  doi 10.1016/j.jhealeco.2005.10.006. VERIFIED via PubMed (PMID 16356570), RePEc/IDEAS,
  NBER (w10700). **Main JHE base paper.** Cited in introduction.tex and discussion.tex.
- `petek2022` — Petek, Nathan (2022), **JHE 86, art. 102688**,
  doi 10.1016/j.jhealeco.2022.102688. VERIFIED via PubMed (PMID 36215932), RePEc,
  author site. Secondary support (hospital entry/exit). Cited once in introduction.tex.
- `wennberg1973` — Wennberg & Gittelsohn (1973), **Science 182(4117), 1102–1108**,
  doi 10.1126/science.182.4117.1102. VERIFIED via PubMed (PMID 4750608), NASA/ADS,
  Dartmouth Digital Commons. Canonical flow-market/HRR foundation, complements Wang (2020).
  Cited once in introduction.tex.

## References checked but NOT added

- A separate formal "Dartmouth Atlas" report citation — not needed. The Dartmouth
  Atlas is named in prose, and `wennberg1973` (its methodological origin) plus
  `wang2020hrr` cover the flow-market lineage cleanly. Adding a third would be padding.

## Paragraphs modified

- **introduction.tex** — closure paragraph rewritten: leads with "JHE literature
  that reads hospital closures as access shocks" (Buchmueller + Avdic as base),
  adds Petek (entry/exit), and the "move the access margin upstream" point + the
  setting's sign-flip (closing a referral provider can *reduce* measured travel).
  New compact flow-market paragraph (Wennberg → Wang) with the "flows for a
  different purpose: causal exposure + post-closure displacement" framing and one
  scoped "to my knowledge" novelty sentence. Deinstitutionalization paragraph:
  "Closest is Dias & Fontes" → "context paper"; "two halves converge…" softened to
  "Read together, the two papers separate two margins of the reform…".
- **discussion.tex** — Buchmueller added to the closure-literature anchor cite.

## Final base-paper positioning sentence (introduction)

> "The paper speaks first to the JHE literature that reads hospital closures as
> access shocks. Buchmueller, Jacobson, and Wold (2006) ask how closures move
> access and mortality through distance to the nearest hospital, and Avdic (2016)
> traces the mortality consequences of the longer trips that emergency-hospital
> consolidation forces… I move the access margin upstream—before asking whether
> distance to care affects outcomes, I ask whether distance identifies the exposed
> population at all when patients cross borders for referral."

## Originality (stated positively, no novelty assertion)

The contribution is carried by the *positive* framing rather than any qualified-
novelty claim: prior flow-market work delineates hospital markets; this paper uses
pre-closure flows for causal provider-loss exposure and post-closure flows for
displacement. The "to my knowledge … has not been used together" sentence was
removed per author request; no "to my knowledge" or "first ever" language remains.

## Build status

- `latexmk main.tex` → exit 0, **0 undefined citations, 0 `??`**, **30 pp**.
- All three new entries appear in References (`main.bbl`): buchmueller2006, petek2022,
  wennberg1973. No duplicate bib keys. Appendix unaffected (no new appendix cites).
