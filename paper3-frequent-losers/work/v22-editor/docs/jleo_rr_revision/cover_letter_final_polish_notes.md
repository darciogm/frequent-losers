# Cover-letter final polish notes (Step-15 checklist verification)

Date: 2026-06-04. Mode: READ-ONLY on the three letters; this notes file is the
only artifact created. No letter was edited.

Letters audited:
- **L1 (ACTIVE)** — `submission_jleo/cover_letter/cover_letter_jleo.md` (feeds the
  pandoc one-page PDF).
- **L2 (short/working)** — `submission_jleo/cover_letter/cover_letter_jleo_short.md`
  (Editorial Express text-field note, ~140 words).
- **L3 (clean variant)** — `submission_clean/cover_letter_JLEO_submission.md`.

Prior pass reviewed: `docs/jleo_rr_revision/94_COVER_LETTER_REPAIR_NOTES.md`
(Step-15 repair that retired the dead 193/131/83% numbers and inserted the
deflationary framing). This pass verifies the on-disk state against the Step-15
checklist.

---

## Per-letter verdict table

| # | Checklist item | L1 ACTIVE | L2 short | L3 clean |
|---|---|---|---|---|
| 1 | Exact organizational-framework statement (L1 verbatim; L2/L3 equivalent framing OK) | PASS (verbatim) | PASS (equiv) | PASS (equiv) |
| 2 | Exclusive submission to JLEO | PASS | PASS | PASS |
| 3 | Contribution = evidence allocation under costly observability | PASS | PASS | PASS |
| 4 | Validation target = adjudication-anchored exposure, not cartel membership | PASS | PASS | PASS |
| 5 | Frequent-loser screen audited, not sold | PASS | PASS | PASS |
| 6 | Price = scope, not damages/overcharge | PASS | N/A (price not mentioned) | N/A (price not mentioned) |
| 7 | Data/replication/confidentiality accurate (BEC exemption; CADE public; reproducible label) | PASS | PASS | PASS |
| 8 | ZERO forbidden literals/claims (raw AUC, 83%, 193, "131 of 193", cartel detector, "screen works", detects participation, overcharge/damages as claim, HUMAN_DECISION, platform-wide prospective deployment claim) | PASS | PASS | PASS |
| 9 | ACTIVE letter ≤1 page, PDF regenerated after .md edits | PASS | N/A | N/A |

---

## Item-by-item evidence

### Item 1 — organizational-framework statement
- **L1 (verbatim required):** present word-for-word — "Instead of proposing a
  standalone algorithmic cartel screen, the paper contributes an organizational
  framework for auditing the reach, boundaries, and apparent performance of cheap
  administrative screens within public procurement platforms before agencies open
  costly bid-level records." PASS.
- **L2 (equivalent):** "a framework for auditing how far cheap administrative
  records can order forensic priority before agencies open costly bid-level
  records." PASS.
- **L3 (equivalent):** identical equivalent sentence as L2, plus "In the BEC–CADE
  setting, the audit is deliberately deflationary…" PASS.

### Item 2 — exclusive JLEO submission
- L1: "submitted **exclusively** to JLEO; it is not under review at any other
  journal and has not been published elsewhere." PASS.
- L2: "exclusively to JLEO; it is not under review elsewhere." PASS.
- L3: "submitted exclusively to JLEO; it is not under review elsewhere and has not
  been published before." PASS.

### Item 3 — evidence allocation under costly observability
- L1: "a question of enforcement design under costly and incomplete observability
  …"; "an **evidence-allocation framing**". PASS.
- L2: "This is enforcement design and evidence allocation under costly
  observability — a law–economics–organization question." PASS.
- L3: "a question of enforcement design and evidence allocation under costly
  observability, at the intersection of law, economics, and organization." PASS.

### Item 4 — adjudication-anchored exposure, not membership
- L1: "Co-bidders linked to adjudicated cases are described as
  **adjudication-anchored exposure**, not as cartel members." PASS.
- L2: "reproducible, non-circular adjudication-anchored label"; "does not prove
  liability or estimate damages." PASS.
- L3: "We build the validation label by adjudication-anchored construction …
  non-circular and reproducible"; "does not claim to identify cartel members."
  PASS.

### Item 5 — screen audited, not sold
- L1: deflationary verdict "within comparable opportunity sets the residual
  ordering is marginal at best and not robust across designs." PASS.
- L2: "the audit is deliberately deflationary — within comparable opportunity sets
  the residual ordering is marginal at best and not robust across designs." PASS.
- L3: "The verdict is honest: within comparable opportunity sets the residual
  ordering net of opportunity is marginal at best and not robust across designs."
  PASS.

### Item 6 — price = scope, not damages/overcharge
- L1: "price differences are treated as **scope evidence**, not as overcharge or
  damages." PASS.
- L2/L3: price/overcharge not discussed; the damages boundary is stated as a
  negation only ("does not prove liability or estimate damages" / "cannot
  establish agreement, liability, or damages"). No price-as-damages claim. N/A
  for the affirmative scope phrasing, no violation.

### Item 7 — data/replication/confidentiality accurate
- All three: CADE rulings public; BEC microdata administrative and confidential,
  cannot be redistributed; JLEO proprietary-data exemption to be requested;
  analysis code + derived/anonymized firm-level frames + output-to-script map
  provided. L1 and L3 cite the sample size 1,654,401 tender-items (consistent with
  the manuscript). Label builder described as reproducible/non-circular in all
  three. PASS.

### Item 8 — forbidden-literal/claim scan (all three letters)
Manual read of the full on-disk text of each letter:

| Forbidden item | L1 | L2 | L3 |
|---|---|---|---|
| Raw AUC numbers (0.946 / 0.7715 / 0.924 …) | absent | absent | absent |
| 83% | absent | absent | absent |
| 193 | absent | absent | absent |
| "131 of 193" | absent | absent | absent |
| "cartel detector" | absent | absent | absent |
| "screen works" | absent | absent | absent |
| "detects cartel participation" | absent | absent | absent |
| overcharge/damages **as a claim** | only negated ("not as overcharge or damages") | only negated ("not … estimate damages") | only negated ("cannot establish … damages"; "does not claim to … estimate damages") |
| HUMAN_DECISION markers | absent | absent | absent |
| platform-wide prospective deployment **claim** | only negated ("not as platform-wide prospective deployment") | absent | only negated ("not as platform-wide prospective deployment") |

All remaining hits are mandated negations/boundary disclaimers required by the
reframing rules. Unjustified hits: 0. PASS for all three.

### Item 9 — ACTIVE letter length + PDF freshness
- **PDF exists** at
  `submission_jleo/cover_letter/GenicoloMartins_Azevedo_CheapSignals_CostlyProof_JLEO_CoverLetter.pdf`.
- **Length:** rendered PDF is **1 page**. PASS.
- **Freshness:** PDF mtime `Jun 4 18:48` is **newer** than the source .md mtime
  `Jun 4 18:32` (the short note is `17:53`). The distinctive new phrase "Instead
  of proposing a standalone algorithmic cartel screen" **is present in the
  rendered PDF text** (read via the PDF reader), and the PDF body matches the
  current .md (deflationary paragraph, non-circular label, recovery-footprint
  accounting, "not as platform-wide prospective deployment"). No forbidden
  literals (83% / 193 / 131 of / cartel detector / cartel-adjacency) appear in the
  PDF. **The PDF was regenerated after the .md edits.** PASS.

  Note for lead: pdftotext via Bash was sandbox-denied; verification was done by
  reading the PDF directly through the file reader, which surfaced full body text.
  Confirmation is therefore visual-text-level, not a byte diff, but the
  distinctive phrase and the full deflationary contribution block are
  unambiguously present.

---

## FAIL log

None. No FAIL items across the three letters.

---

## Overall verdict

**COVER_LETTER_PASS.**

All three letters satisfy the Step-15 checklist. The ACTIVE letter carries the
verbatim organizational-framework statement, is one page, and its PDF was
regenerated after the .md edits (newer mtime + distinctive phrase present in
rendered text). The short and clean variants carry equivalent framing and the
same deflationary, non-circular, exemption-and-replication content. No forbidden
literals or claims appear in any letter; all damages/overcharge/platform-wide
mentions are mandated negations.

No author-pending items were resolved here (fee/waiver, funding, conflicts,
reviewers, legal involvement, preprint remain HUMAN_DECISION items per
`94_COVER_LETTER_REPAIR_NOTES.md` and are out of scope for this verification
pass).
