# 64 — Final Style & Legal-Citation Audit (JLEO submission, v22)

**Scope.** Read-only audit of legal citations, CADE references, and law-and-economics
language in `work/v22-editor/submission_clean/`. No edits made; findings only.

**Headline.** Statutes are *substantively* consistent but have **one cosmetic
format inconsistency** (year written `/93` for Lei 8.666 vs 4-digit years for the
others). CADE language is disciplined and accurate — defendants are called
"adjudicated"/"legal anchors", never "legally guilty" outside the adjudication
context. No unsupported legal conclusions found. **One `HUMAN_LEGAL_STYLE_REVIEW_REQUIRED`
flag** raised, on the Bluebook-equivalent formatting of Brazilian statutes (a
style judgment, not a factual error).

---

## 1. Brazilian statutes — occurrences and consistency

Grep of all `*.tex` in `submission_clean/`. Statutes appear only in
`sec02_setting_layers_submission.tex` (prose) and `values.tex` (macros).

| Statute | Topic | Occurrences | Form used | Consistent? |
|---|---|---|---|---|
| **Lei 12.529/2011** | Competition law (CADE infraction basis for bid rigging) | sec02:25 (`Lei~$12.529/2011$`) | 4-digit year | OK (single occurrence; full year) |
| **Lei 8.666/1993** | Procurement / *Convite* sealed-bid + 3-bidder quorum | sec02:70 (`Lei~$8.666/93$`); values.tex:568 (`\valLeiOriginal = 8.666/93`) | **2-digit year `/93`** | Internally consistent (both `/93`), but **diverges in style** from the 4-digit form used for 12.529 and 10.520 |
| **Lei 10.520/2002** | *Pregão* electronic reverse auction | sec02 via `\valLeiPregao`; values.tex:570 (`\valLeiPregao = 10.520/2002`) | 4-digit year | OK |
| Decreto 9.412/2018 | (value-cap update; macro `\valDecreto`) | values.tex:567 | 4-digit year | OK (not a "Lei"; consistent) |

**Finding L-1 (cosmetic, low severity).** Lei 8.666 is cited as `8.666/93`
(two-digit year) while Lei 12.529 and Lei 10.520 use four-digit years
(`/2011`, `/2002`). For a clean submission the three statutes should use a single
year convention — recommend **`8.666/1993`** to match. This is a one-character
display change in `sec02:70` and `values.tex:568` (`\valLeiOriginal`). **Not
fixed here** (read-only mandate); flagged for the author.

**Finding L-2 (good).** Each statute is paired with an accurate substantive
description: 12.529/2011 = "Brazilian competition law treats bid rigging as an
infraction"; 8.666/93 = "*Convite*, a sealed-bid invitation procedure ... with a
statutory three-bidder quorum and a low value cap"; 10.520/2002 = "*Pregão*, a
reverse electronic auction ... with no minimum-bidder rule." All three match the
real content of the statutes. No statute is mis-attributed.

---

## 2. CADE references — consistency and accuracy

`CADE` appears across 18 `.tex` files (heaviest in `sec_app07_comprasnet`,
`values.tex` macros, `sec04_validation`, `sec_app02_data_labels`). Spot-checked
the load-bearing occurrences in sec02, sec04, sec_app02, sec_app03.

- **Defined once, used consistently.** sec_app02/sec02 define the case portfolio
  as **12 adjudicated procurement-cartel cases / 65 firm-defendants**; this same
  pair (12, 65) recurs identically in sec04:43, sec04:84 (Table), sec02:143,
  sec_app02:70/76. **Consistent.**
- **Adjudication language is accurate and disciplined.** Defendants are termed
  "adjudicated cartel defendants", "legal membership anchors", "legal anchors
  from adjudicated procurement-cartel cases" (sec_app02:149). The cobidder label
  is explicitly an **"adjudication-anchored exposure label", not membership**
  (sec_app02:99–102, sec02:164) — i.e. the paper does **not** assert that a
  cobidder is itself a cartelist. This honors the project rule
  ("never `detects cartelists`/`proves`").
- **No "legally guilty" overreach.** Grep for `guilty|convicted|conviction`
  returns **zero** hits in the manuscript `.tex`. The strongest legal word used
  is "adjudicated", which is accurate for completed CADE rulings.
- **"Final decisions span 2015–2025" is internally consistent.** sec02:145 says
  "Final decisions span 2015–2025"; sec_app03:341 independently says CADE
  "judgment dates (2015–2025)"; sec_app02:109–116 says judgment dates observed
  for "9 of 12" cases. The span statement, the judgment-date range, and the
  case-table dating are mutually consistent. **No contradiction.**
- **Disclosed data limit is stated, not hidden.** The text repeatedly notes that
  CADE files carry **judgment dates only** (conduct-onset unavailable), which is
  why the sequential strict-timing test is reported as FAIL. This is an honest
  legal-data caveat, correctly placed.

---

## 3. Law-and-economics terminology — precision check

- "infraction" (for bid rigging under 12.529/2011) — correct register.
- "adjudication / adjudicated / adjudication-anchored" — used precisely and
  consistently to mean *completed administrative ruling*, never broadened to
  imply criminal guilt.
- "legal predicates", "legal membership anchors", "legally limited",
  "legally anchored" — used coherently and do not overclaim.
- Forbidden-language grep (`proves`, `detects cartelist(s)`, `outperform`) on the
  manuscript `.tex` returns **no** prohibited usage; the two `improves` hits
  (sec06:108, sec_app07:152) are about a score/metric, not a legal claim.

**No unsupported legal conclusions identified.** The paper consistently frames
the screen as flagging/prioritizing exposure to adjudicated anchors, and
explicitly disclaims that a flag implies cartel membership or guilt.

---

## 4. Bluebook-equivalent formatting feasibility for Brazilian statutes

JLEO uses Chicago author-date for the bibliography; Brazilian primary legislation
is **not** a bibliographic reference entry here (the statutes are cited inline in
prose, not in the `.bbl`). There is therefore no Chicago/Bluebook reference-list
entry required for Lei 8.666 / 10.520 / 12.529, and none is missing.

The only open style question is the **inline display convention** for the statute
number+year. The current mixed convention (`8.666/93` vs `12.529/2011`) is a
house-style choice. Brazilian statutory citation does not have a single
journal-mandated English form, and JLEO does not prescribe one.

> **`HUMAN_LEGAL_STYLE_REVIEW_REQUIRED`** — A human should confirm the preferred
> inline statute format and harmonize the year convention (recommended:
> `Lei 8.666/1993`, `Lei 10.520/2002`, `Lei 12.529/2011` — all four-digit).
> This is a presentation choice, not a factual or substantive legal error; the
> statute numbers and substantive descriptions are all correct.

---

## 5. Summary

| Item | Verdict |
|---|---|
| Lei 8.666 cited consistently | Internally yes (`/93` twice); **format diverges** from peers (L-1) |
| Lei 10.520 cited consistently | Yes (4-digit, via `\valLeiPregao`) |
| Lei 12.529 cited consistently | Yes (4-digit) |
| Statute substance correct | Yes (L-2) |
| CADE references consistent (12 cases / 65 defendants) | Yes |
| "Final decisions span 2015–2025" consistent with case table | Yes |
| Defendants not called "legally guilty" beyond adjudication | Confirmed (no `guilty/convicted`) |
| "Adjudicated" used accurately | Yes |
| Unsupported legal conclusions | None found |
| Forbidden cartel-detection language | None found |
| Human flag | **1** — `HUMAN_LEGAL_STYLE_REVIEW_REQUIRED` (year-format harmonization, cosmetic) |
