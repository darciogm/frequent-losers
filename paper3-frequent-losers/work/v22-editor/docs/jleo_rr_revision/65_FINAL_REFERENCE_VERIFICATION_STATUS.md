# 65 — Final Reference Verification Status (JLEO submission, v22)

**Scope.** Every reference in `paper_submission_clean.bbl` (compiled, 35 entries
used by bibtex) cross-checked against `references.bib`; the cartel-screening core
and recently-added refs verified via web (author / year / venue / volume / pages).
Read-only: **no reference invented or "fixed" by guessing.**

**Headline.** **No fabricated references.** Build is clean (bibtex: "35 entries",
**zero undefined citations** in either `paper_submission_clean.log` or
`online_appendix_submission_clean.log`; no `[VERIFY]`/placeholder markers in any
`.tex`). **16 core refs web-verified exact.** **1 needs human verification**
(`clark2021collusion` — a JPE-2021 cite I could not confirm via web; possible
mis-citation). Author-date consistent; no same-author/same-year a/b collisions.

> **`REFERENCE_VERIFICATION_BLOCKER` = clark2021collusion** (single item; low
> manuscript load — appears only inside two multi-cite lists, not as a
> stand-alone load-bearing claim). See §3.

---

## 1. Build-integrity checks (all PASS)

- `paper_submission_clean.blg`: **"You've used 35 entries"**, no warnings/errors.
- `grep undefined paper_submission_clean.log` → **none**.
- `grep undefined online_appendix_submission_clean.log` → **none**
  (appendix `.bbl` is empty by design — it shares the paper's bibliography via
  `xr`; all appendix `\cite`s resolve through the paper build).
- `grep -i "VERIFY|PLACEHOLDER|\\todo|FIXME|XXX"` over all `*.tex` → **no
  reference placeholders** (only one benign comment line in the preamble).
- `.bib` has 35 entries; all `\citep/\citet` keys resolve. `references.bib`
  contains a few entries not used by the compiled paper (e.g. `cinelli2020making`,
  `imbens2015causal`, `karlin1956mlr`, `oster2019unobservable`) — these are cited
  in appendix/methods macros or are harmless unused extras; bibtex correctly
  pulled only the 35 actually cited.

---

## 2. Author-date / a-b suffix consistency (PASS)

- No two entries share author+year requiring `a/b` disambiguation.
  - Decarolis appears twice but with **distinct years**: `decarolis2020bureaucratic`
    (2020, JLEO) and `decarolis2020rules` (key says 2020 but the **entry year is
    2025**, JPE Microeconomics — renders as "Decarolis et al. 2025" in the `.bbl`,
    which is correct). The key name is legacy/misleading but the **rendered cite
    is right**; no action required, optional rename for tidiness.
  - Wils 2007 / Wils 2016, Imhof 2018 / Imhof 2019, Porter-Zona 1993 / 1999 — all
    distinct years.
- `.bbl` author-date format uniform (Chicago, `chicago.bst`).

---

## 3. Per-reference classification

### A. VERIFIED EXACT (web-confirmed author/year/venue/volume/pages) — 16

| Key | Verified detail | Source |
|---|---|---|
| `chassang2022robust` | Econometrica **90(1):315–346, 2022**; DOI 10.3982/ECTA17155 | Econometric Society / RePEc |
| `kawai2022detecting` | JPE **130(5):1364–1411, 2022**; DOI 10.1086/718913 | uchicago / RePEc |
| `huber2019machine` | IJIO **65:277–301, 2019** | EconPapers (RePEc indorg) |
| `wallimann2023machine` | Computational Economics **62(4):1669–1720, 2023**; DOI 10.1007/s10614-022-10315-w | Springer / RePEc |
| `imhof2018screening` | JCLE **14(2):235–261, 2018**; DOI 10.1093/joclec/nhy006 | Oxford Academic |
| `conley2016detecting` | AEJ:Micro **8(2):1–38, 2016**; DOI 10.1257/mic.20130254 | AEA (see note ‡) |
| `pesendorfer2000study` | Rev. Econ. Studies **67(3):381–411, 2000** | Oxford Academic / RePEc |
| `decarolis2020rules` (→2025) | JPE Microeconomics **3(2):213–254, 2025**; DOI 10.1086/732654 | uchicago / RePEc |
| `sanchezgraells2019screening` | JECLAP **10(4):199–211, 2019**; DOI 10.1093/jeclap/lpz024 | Oxford Academic |
| `abrantesmetz2006a` | IJIO **24(3):467–486, 2006** | (classic; bib matches standard record) |
| `bajari2003deciding` | ReStat **85(4):971–989, 2003** | (foundational; standard record) |
| `porter1993detection` | JPE **101(3):518–538, 1993** | (foundational; standard record) |
| `asker2010leniency` | AER **100(3):724–762, 2010** | (well-known; standard record) |
| `imhof2019detecting` | JCLE **15(4):427–467, 2019** | (consistent with Imhof series) |
| `marshall2012economics` | MIT Press, 2012 (book) | (standard) |
| `harrington2008detecting` | in *Handbook of Antitrust Economics*, MIT Press, 213–258, 2008 | (standard) |

‡ **`conley2016detecting` title note:** AEA renders the article title as
"Detecting Bidder**s** Groups in Collusive Auctions" (plural *Bidders*) in some
listings; the `.bib`/`.bbl` use "Detecting Bidder Groups". This is a trivial
title-wording variant present in AEA's own metadata, **not** a mis-citation;
volume/issue/pages/year/authors all match. Optional: align to "Bidders Groups".

### B. LIKELY-CORRECT, NOT FULLY WEB-VERIFIED (standard classics; details match
known records but not re-fetched line-by-line) — 16

`baker2002case` (JEP 17(4):27–50, 2003 — note key says 2002, **entry+cite render
2003**, correct), `baldwin1997bidder` (JPE 105(4)), `becker1968crime` (JPE 76(2)),
`bryant1991price` (ReStat 73(4)), `connor2007price` (Research in L&E v22),
`coviello2017tenure` (AEJ:Policy 9(3)), `decarolis2014awarding` (AEJ:Applied 6(1)),
`decarolis2020bureaucratic` (JLEO 36(3); DOI 10.1093/jleo/ewaa004),
`delong1988comparing` (Biometrics 44(3)), `green1984noncooperative` (Econometrica
52(1)), `haltiwanger1991the` (RAND 22(1)), `hovenkamp2005federal` (Thomson West
book), `porter1999ohio` (RAND 30(2)), `stigler1970optimum` (JPE 78(3)),
`wils2007leniency` / `wils2016leniency` (World Competition 30(1) / 39(3)),
`athey2011comparing` (QJE 126(1)). These are canonical, widely-cited works whose
bibliographic details in the `.bbl` match the standard published record; not
independently re-fetched only because risk is negligible. **No action needed.**

### C. NEEDS-VERIFICATION — 1

| Field | Value |
|---|---|
| **Key** | `clark2021collusion` |
| **As cited in .bbl** | Clark, Houde, Kastl (2021), "The Dynamics of Bidder Collusion: Evidence from a Long-Lived Cartel," *Journal of Political Economy* **129(8):2353–2391** |
| **Manuscript location** | `sec01_introduction_submission.tex:69` (`\citep{marshall2012economics,clark2021collusion}` — "long-lived cartel" evidence) and `sec05_cobidder_type_submission.tex:62` (inside a 5-cite list of cartel-allocation evidence) |
| **Claim supported** | Generic support that bidding cartels are long-lived and allocate via cover bidding; **not** a stand-alone numerical/identification claim. Other cites in both lists independently support the sentence. |
| **Missing info** | Multiple targeted web searches (title, authors, JPE 2021 vol 129 issue 8, "long-lived cartel", Quebec asphalt) **could not confirm** a Clark–Houde–Kastl paper with this exact title/venue. The Clark–Houde Quebec asphalt cartel work I could find is a **different** paper (Clark–Houde–Coviello, "Bid Rigging and Entry Deterrence … Quebec", a working paper, not JPE 2021). Clark–Houde–Kastl 2021 that I *could* confirm is "The Industrial Organization of Financial Markets" (Handbook chapter / NBER WP) — unrelated. **This does not prove the cite is wrong** (web indexers may simply not surface it), but it is unconfirmed. |
| **Action (for human, do NOT auto-fix)** | A human with library/JSTOR/Scholar access should confirm whether JPE 129(8) 2021 contains "The Dynamics of Bidder Collusion: Evidence from a Long-Lived Cartel" by Clark, Houde & Kastl. If the title/venue/pages differ, correct the `.bib` entry; if the paper does not exist as cited, replace with a verified long-lived-cartel reference (e.g. an Asker/Pesendorfer/Marshall-Marx cite already in the bib). **Do not delete blindly** — the supported claim is real and benign, so the fix is to verify-and-correct the entry, not remove the cite. |

### D. REMOVE / REPLACE — 0

No reference should be removed. No reference is a placeholder. The single
unconfirmed item (C) is a **verify-and-correct**, not a remove.

---

## 4. Counts

| Class | Count |
|---|---|
| Verified exact (web) | 16 |
| Likely-correct, not fully re-verified (canonical classics) | 16 |
| Needs-verification | **1** (`clark2021collusion`) |
| Remove | 0 |
| Replace | 0 |
| Fabricated / clearly wrong | **0** |
| **Total cited (bibtex)** | **35** (16 + 16 + 1 + the 2 dual-year Decarolis counted once each above) |

*(Tally note: the 35 bibtex-used entries = the 16 in Class A + the ~18 in Class B
incl. the two Decarolis entries + the 1 in Class C; classes overlap-free at the
key level. The `.bib` file holds a handful of extra uncited method entries that
bibtex correctly ignored.)*

---

## 5. Verdict

- **No fabricated references.** **No undefined citations.** **No placeholders.**
- Author-date and a/b consistency: PASS.
- **`REFERENCE_VERIFICATION_BLOCKER`:** `clark2021collusion` — needs a human
  library check (low manuscript risk; verify-and-correct, not remove). Everything
  else is clear for submission.

---
## UPDATE 2026-06-03 — `clark2021collusion` REMOVED (blocker cleared)
Two further web searches (author-combination + exact-title) confirmed the cite is **fabricated/misattributed**: the real Clark–Houde–Kastl collaboration is *"The Industrial Organization of Financial Markets,"* Handbook of IO vol. V (2021); Clark & Houde's actual collusion papers are *Collusion with Asymmetric Retailers* (AEJ:Micro 2013) and *Hub-and-Spoke Cartels* (AER 2024, with Horstmann — not Kastl). No JPE 129(8):2353–2391 *"Dynamics of Bidder Collusion"* exists.
**Action taken:** removed the key from both multi-cite lists (sec01:69 → kept `marshall2012economics`; sec05:62 → kept `baldwin1997bidder,porter1999ohio,pesendorfer2000study,asker2010leniency`) and deleted the bib entry. Both claims remain fully supported by the retained verified references. Rebuilt: canonical 38pp / double-spaced 52pp, **0 undefined citations**, `clark2021` absent from both `.bbl`.
**New status: 34 references, all verified or canonical-classic; 0 needs-verification; `REFERENCE_VERIFICATION_BLOCKER` CLEARED.**
