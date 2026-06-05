# 98 — MINOR CLOSEOUT REPORT (doc 97 ○ items)

**Date:** 2026-06-05 · **Owner of edits:** lead (this agent owns no `.tex`/`.bib`; deliverables are findings + proposed text).
**Scope:** the four pending ○ minors from `97_HOSTILE_PRE_SUBMISSION_REFEREE_REPORT.md`:
(1) web-verify 5 bib details; (2) dangling `.bib` entries; (3) tie-handling sentence; (4) few-clusters acknowledgment; plus (5) OECD overstatement check.

---

## TASK 1 — Bibliographic verification (5 entries)

All five entries are **cited in the manuscript** (grep confirmed: `imhof2019detecting` in sec01/sec02/sec06; `wallimann2023machine` in sec01/sec02/sec06; `oecd2022datascreening` in sec01; `sanchezgraells2019screening` in sec01; `decarolis2020rules` in sec02). None are dangling. All five verified against external sources below.

| Key | Field-by-field check | Verdict |
|---|---|---|
| **oecd2022datascreening** | Title "Data Screening Tools for Competition Investigations" ✓; year 2022 ✓; series "OECD Roundtables on Competition Policy Papers" ✓; **number 284 ✓** (RePEc handle `oec/dafaac/284-en`); DOI **10.1787/4c5bbb9d-en ✓** (matches OECD iLibrary URL slug); publisher OECD Publishing, Paris ✓ | **VERIFIED-AS-IS** |
| **decarolis2020rules** | Authors Decarolis, Fisman, Pinotti, Vannutelli ✓; title "Rules, Discretion, and Corruption in Procurement: Evidence from Italian Government Contracting" ✓; journal *Journal of Political Economy Microeconomics* ✓; **vol 3, no 2, pp 213–254, year 2025 ✓**; DOI **10.1086/732654 ✓** | **VERIFIED-AS-IS** |
| **imhof2019detecting** | Author Imhof (solo) ✓; title "Detecting Bid-Rigging Cartels with Descriptive Statistics" ✓; journal *Journal of Competition Law & Economics* ✓; **vol 15, no 4, pp 427–467, 2019 ✓**; DOI 10.1093/joclec/nhz019 (not in bib) | **VERIFIED-AS-IS** (optional: add `doi={10.1093/joclec/nhz019}`) |
| **sanchezgraells2019screening** | Author Sánchez Graells ✓; title "'Screening for Cartels' in Public Procurement: Cheating at Solitaire to Sell Fool's Gold?" ✓; journal *Journal of European Competition Law & Practice* ✓; **vol 10, no 4, pp 199–211, 2019 ✓**; DOI **10.1093/jeclap/lpz024 ✓** | **VERIFIED-AS-IS** |
| **wallimann2023machine** | Authors Wallimann, Imhof, Huber ✓; title "A Machine Learning Approach for Flagging Incomplete Bid-Rigging Cartels" ✓; journal *Computational Economics* ✓; **vol 62, no 4, pp 1669–1720, 2023 ✓**; DOI **10.1007/s10614-022-10315-w ✓** | **VERIFIED-AS-IS** |

**Net: 0 corrections required.** The only optional improvement is adding the verified DOI to `imhof2019detecting` (every other JCLE/JECLAP/Computational-Economics entry in the file carries a DOI, so this is a consistency nicety, not an error):

```bibtex
@article{imhof2019detecting,
  title={Detecting Bid-Rigging Cartels with Descriptive Statistics},
  author={Imhof, David},
  journal={Journal of Competition Law \& Economics},
  volume={15},
  number={4},
  pages={427--467},
  year={2019},
  doi={10.1093/joclec/nhz019}
}
```

Sources: OECD iLibrary (`oecd-ilibrary.org/.../4c5bbb9d-en`) + RePEc `ideas.repec.org/p/oec/dafaac/284-en.html`; UChicago `journals.uchicago.edu/doi/10.1086/732654`; OUP `academic.oup.com/jcle/article-abstract/15/4/427/5730310`; OUP `academic.oup.com/jeclap/article-abstract/10/4/199/5537135`; Springer `link.springer.com/article/10.1007/s10614-022-10315-w` + RePEc `ideas.repec.org/a/kap/compec/v62y2023i4d10.1007_s10614-022-10315-w.html`.

---

## TASK 2 — Dangling `.bib` entries

Grepped all `*.tex` in `submission_clean/` for `\cite*{...}` containing each key.

| Key | Cited in manuscript? | Recommendation |
|---|---|---|
| **delong1988comparing** | **YES** — `sec04_validation_submission.tex:171` (`\citealp{delong1988comparing}`) | Keep. The doc-97 ○ ("confirm now cited") is **CONFIRMED CITED**. |
| cinelli2020making | No | Delete or retain-with-comment (see below) |
| imbens2015causal | No | Delete or retain-with-comment |
| karlin1956mlr | No | Delete or retain-with-comment |
| oster2019unobservable | No | Delete or retain-with-comment |
| green1984noncooperative | No (re-anchored out per doc-97 ✔) | Delete or retain-with-comment |
| haltiwanger1991the | No (re-anchored out per doc-97 ✔) | Delete or retain-with-comment |

**Recommendation: DELETE the six uncited entries.** Reasons:
- The bib header explicitly states its contract: *"Contains only entries cited in the main paper or online appendix."* Six uncited entries silently violate that invariant, and a referee who diffs the bib against `\cite` keys will notice.
- With `\bibliography` + a `.bbl` driver, uncited entries are harmless to the PDF (they don't print), so the *only* downside of deleting is reversibility — and all six are trivially recoverable from git history if a future revision needs them.
- `green1984`/`haltiwanger1991` were deliberately *removed from prose* in this pass (doc-97 ✔ "re-anchored"), so their bib entries are now genuinely orphaned, not "reserved".

If the lead prefers zero risk of breaking a future draft, the fallback is to retain them with an explicit marker so the contract violation is intentional and auditable:
```bibtex
% uncited, retained for potential reviewer-requested robustness (sensitivity/MLR/causal-inference lineage)
```
My call: **delete** — the bib contract and a clean `\cite`↔entry bijection are worth more than the marginal convenience, given git recoverability.

---

## TASK 3 — Tie-handling sentence (Table 4 notes / App C)

**How ties are actually handled (verified in code):** `scripts/analysis/03_timing_case_holdout_validation.R` computes AUC via the local helper `roc_auc()` in `scripts/utils/metrics_triage.R` (lines 53–61). That helper is the Mann–Whitney / Wilcoxon rank-sum estimator with **`rank(s, ties.method = "average")`** (midrank):

```r
r <- rank(s, ties.method = "average")
(sum(r[y == 1L]) - n1 * (n1 + 1) / 2) / (n1 * n0)
```

This assigns tied (score, label) pairs exactly **0.5** — the standard rank-based convention. The strict-timing full-candidate sample carries a large mass tied at score zero (entrants with no pre-window losing history; the script logs `tie_at_zero_share` ≈ 0.25 of firms via `mean(s == 0)`). Under midrank, every tied loser/non-loser pair contributes 0.5, so the reported AUC is the convention-neutral expected value (not the optimistic "ties resolved in the model's favor" upper bound nor the pessimistic lower bound).

**Proposed sentence (drop into Table 4 notes; alternatively App C):**

> Roughly a quarter of firms in the full strict-timing candidate sample are tied at the floor score of zero (entrants with no pre-window losing history and therefore no rankable signal). AUC is computed with the rank-based (Mann–Whitney) estimator under the midrank convention, which assigns every tied score–label pair a credit of exactly 0.5; the reported figures are therefore the convention-neutral expected AUC, neither the tie-favorable upper bound nor the tie-adverse lower bound.

---

## TASK 4 — Few-clusters acknowledgment (§4.3 or App C)

**Proposed 2 sentences:**

> The case-composition inference rests on a small number of adjudicated cartels—twelve matched CADE cases, of which six are informative for the case-grouped collapse—so the effective number of clusters at the natural unit of treatment (the case) is small. We therefore report randomization inference clustered at the finer item-group × year level, which is more conservative on standard-error inflation but does not manufacture case-level independence: under the honest few-effective-clusters reading, the permutation p = 0.001 and the coverage p = 0.103 should be interpreted as directionally informative rather than as exact size-controlled tests, and we lean on the corroborating anchor-agnostic battery (negative controls, powered permutation, label-frozen timing) rather than on any single clustered p-value.

(If §4.3 already states the 12/6 case counts and the item-group × year RI design, the lead can trim the first clause to avoid repetition and keep only the "honest few-effective-clusters reading" sentence.)

---

## TASK 5 — OECD overstatement check

**Text in `sec01_introduction_submission.tex:51–60`:** describes corruption-risk indicators (single bidding, repeat-participation anomalies) "computed from contract-award data across entire procurement systems and used by multilateral institutions and audit bodies precisely because bid-level records are costly to recover," citing `{fazekas2020uncovering, oecd2022datascreening}`.

**What the OECD 2022 document actually is:** the background/secretariat note for the OECD Competition Committee Working Party No. 3 roundtable (28 Nov 2022) on data-screening tools for competition investigations — a survey of how competition authorities use behavioural and structural screens (including procurement/bid-rigging screens) computed from administrative data.

**Verdict: NO overstatement, with one nuance to keep clean.**
- The cite supports the proposition that *data screening from administrative records is in institutional use by competition/enforcement bodies* — that is precisely the document's subject. ✓
- The specific phrase "**single bidding and repeat-participation anomalies**" is the *Fazekas & Kocsis (2020)* corruption-risk-indicator lineage, not the OECD note's framing; the OECD note is broader (it catalogues screening tools generally, not those two named CRIs). The current sentence cites both works *together* for the umbrella claim, which is defensible because the umbrella claim ("cheap administrative red flags are in institutional use") is jointly supported. No edit required.
- Minor caution if the lead ever tightens the sentence: do **not** attribute the "single-bidding CRI" specifically to OECD (2022); that named indicator is Fazekas-lineage / World-Bank-and-EU practice. The current joint-cite avoids this trap.

---

## SUMMARY OF DELIVERABLES FOR THE LEAD

1. **Bib (Task 1):** 5/5 VERIFIED-AS-IS, 0 corrections. Optional: add `doi={10.1093/joclec/nhz019}` to `imhof2019detecting` for consistency.
2. **Dangling bib (Task 2):** `delong1988comparing` confirmed CITED. Six uncited (cinelli2020, imbens2015, karlin1956, oster2019, green1984, haltiwanger1991) → **recommend DELETE** (bib header promises cite-only; git-recoverable). Fallback comment provided if retention preferred.
3. **Tie sentence (Task 3):** drafted; midrank/0.5-credit convention verified in `metrics_triage.R`.
4. **Few-clusters sentence (Task 4):** drafted (12 cases / 6 informative; item-group × year RI finer than case; honest reading of p=0.001 / coverage p=0.103).
5. **OECD (Task 5):** no overstatement; one phrasing caution noted.
