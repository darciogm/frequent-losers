# Bibliography — pending audit and verification

**Status:** Working document. Entries here are either (i) planned but not yet
cited, or (ii) cited but unverified. Items are promoted into `biblio.bib`
**only** after author/year/venue verification, and only when the manuscript
actually cites them. Unused entries are not added to production
`biblio.bib`.

Origin: this list was previously kept as a `% TODO-BIB:` comment block at
the end of `01_manuscript/paper_beneath/introduction.tex`. It was moved here
2026-04-09 to keep the `.tex` file clean of planning metadata.

---

## DONE — verified and added to biblio.bib 2026-04-09

| Key | Reference | Status |
|---|---|---|
| `wachs2019network` | Wachs, J. & Kertész, J. (2019). "A network approach to cartel detection in public auction markets." *Scientific Reports* 9: 10818. DOI: 10.1038/s41598-019-47198-1. | ✅ verified via web search + Nature link; cited in §2 |
| `huber2019machine` | Huber, M. & Imhof, D. (2019). "Machine learning with screens for detecting bid-rigging cartels." *International Journal of Industrial Organization* 65: 277–301. DOI: 10.1016/j.ijindorg.2019.04.002. | ✅ verified via web search + ScienceDirect / RePEc; cited in §2 |
| `signor2020detection` | Signor, R., Love, P. E. D., Belarmino, A. T. N., & Olatunji, O. A. (2020). "Detection of Collusive Tenders in Infrastructure Projects: Learning from Operation Car Wash." *Journal of Construction Engineering and Management* 146(1): 05019015. DOI: 10.1061/(ASCE)CO.1943-7862.0001737. | ✅ verified via web search + Semantic Scholar (ASCE page blocks direct fetch); cited in §2 |

---

## PENDING — planned for use but not yet verified, not yet added

Each of these items was planned as part of the paper's theoretical and
methodological framing. Before adding to `biblio.bib`, verify author list,
year, venue, and volume/pages against the publisher record, and confirm
that at least one `.tex` file actually cites the entry.

### Density test (for §methodology and §results)

- **cattaneo2018manipulation** — Cattaneo, Jansson & Ma — local polynomial
  density estimators and a manipulation test used for RD running-variable
  diagnostics. Likely target: Cattaneo, M. D., Jansson, M., & Ma, X.
  (2020). "Simple local polynomial density estimators." *Journal of the
  American Statistical Association* 115(531): 1449–1455. **Action:**
  verify title/year and cite explicitly when §methodology revises the
  density test discussion.

### Detection literature extensions

- **chassang2022ortner** — Chassang & Ortner — missing trader tests / 
  regulating collusion. Likely targets include Ortner, J. & Chassang, S.
  (2018). "Regulating Collusion." *Annual Review of Economics*, or
  Chassang, S., Kawai, K., Nakabayashi, J., & Ortner, J. (2022/2024).
  "Robust Screens for Non-Competitive Bidding in Procurement Auctions."
  *Econometrica*. **Action:** pick the right paper based on which claim
  the manuscript actually needs — "robust screens" is the more relevant
  one for this paper's detection framing.
- **clark2018houde** — Clark, Coviello, Gauthier, Shneyerov on retail
  gasoline collusion. Uncertain this exact co-authorship exists; a
  well-known paper is Clark, R., Horstmann, I., & Houde, J.-F. Search for
  and verify the intended reference before citing.
- **baltrunaite2020** — Baltrunaite, A. — political connections in
  procurement. Possible target: Baltrunaite, A. (2020). "Political
  Contributions and Public Procurement: Evidence from Lithuania." *Journal
  of the European Economic Association* 18(2): 541–582. Verify.
- **harrington2008** — Harrington, J. E. Jr. — optimal cartel enforcement
  / detection of cartels. Likely target: Harrington, J. E. (2008).
  "Detecting Cartels." Chapter in *Handbook of Antitrust Economics*, ed.
  Paolo Buccirossi, MIT Press. Verify chapter page range.
- **miller2009** — Miller, N. H. — strategic leniency and cartel
  enforcement. Target: Miller, N. H. (2009). "Strategic Leniency and
  Cartel Enforcement." *American Economic Review* 99(3): 750–768. Verify
  volume/pages.

### Adjacent literatures

- **jager2023heining** — Jäger, Heining, Kline — worker flow literature.
  Uncertain this exact three-author paper exists. Known papers in this
  space include Jäger, S. (2016) "How Substitutable Are Workers? Evidence
  from Worker Deaths," and Kline, P., Saggio, R., & Sølvsten, M. on AKM
  estimators. **Action:** identify the intended paper before citing, and
  consider whether the claim is better served by a different worker-flow
  reference.
- **morselli2009** — Morselli, C. — covert networks. Likely target:
  Morselli, C. (2009). *Inside Criminal Networks*. Springer (book).
  Verify chapter if citing a specific chapter; otherwise cite the book
  as `@book`.

---

## Guardrails

- **Never add an entry to `biblio.bib` without web-verification of author
  list, year, venue, and (for articles) volume/pages.** The mr-beneath
  persona rule on references is absolute.
- **Never cite an entry that is not in `biblio.bib`.** BibTeX will emit
  `?` marks that referees notice immediately.
- **Delete entries from `biblio.bib` that are never cited in any `.tex`
  file** (the current production `.bib` has 22 unused legacy entries
  from a pre-pivot draft — this cleanup is pending and should be done
  before the SIOE submission).

## Revision log

- **2026-04-09** — created by migrating the TODO-BIB comment block out of
  `introduction.tex`. Three entries verified and added to `biblio.bib`
  (`wachs2019network`, `huber2019machine`, `signor2020detection`) and
  cited in the new §2 literature paragraph. Eight entries remain pending.
