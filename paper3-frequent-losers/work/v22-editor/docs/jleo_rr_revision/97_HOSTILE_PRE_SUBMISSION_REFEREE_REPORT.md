# 97 — HOSTILE PRE-SUBMISSION REFEREE REPORT (consolidated)

**Date:** 2026-06-04 · **Reviewed object:** `submission_jleo/manuscript/GenicoloMartins_Azevedo_CheapSignals_CostlyProof_JLEO_Manuscript.pdf` (53→54 pp after quick fixes) + appendix (47 pp) + cover letter.
**Method:** 5 parallel hostile referees (validation §4; framing/JLEO fit; forensic numbers; §5–§7+appendices; references), synthesized by Mr. Frequent Losers. Full individual reports in session transcript; this document is the actionable consolidation.

---

## EXECUTIVE SUMMARY

The package is **clean on integrity** (numbers: ~190 checked, 0 fatal/major; references: 0 fabricated; hygiene: 0 artifacts) and **unusually honest** — every referee independently credited the front-paging of nulls. The exposure-asymmetry scope check and the case-grouped collapse were singled out as the strongest results. But the hostile read surfaced a coherent meta-critique with real teeth:

> **The audit is systematically tilted toward its own deflationary conclusion** (validation referee), and **the deflation lacks documented stakes** (framing referee). A paper whose thesis is "trust the audit, not the screen" must hold the audit to a higher standard than it currently meets — and must prove someone believed the screen in the first place.

**Calibration (framing referee):** P(desk reject) ≈ 0.45; P(R&R | refereed) ≈ 0.45. The fixes below move both numbers materially.

**Verdict: MAJOR-REVISION-EQUIVALENT — do NOT submit as-is.** The findings are tractable (most are reframing/reordering + 3 cheap computations), but submitting before addressing M1–M4 wastes the one shot at the editor.

---

## MAJOR CONCERNS (consolidated, deduplicated, priority order)

**M1 — Stakes: the audited screen has no documented user (framing F1; borderline fatal for a deflationary paper).**
The paper never shows that anyone uses an award-layer zero-win screen, so the deflation risks reading as "we built a strawman and knocked it down". *Partially repaired in this pass:* verified Fazekas & Kocsis (2020 BJPolS) + OECD (2022) now cited in §1 as the institutional cheap-red-flag lineage. *Remaining:* 3–5 sentences in §1/§2 making the stakes explicit (red-flag dashboards, single-bidding CRIs in EU/World Bank practice; the temptation under costly bid recovery), and the reframing sentence in M4.

**M2 — The audit is biased toward deflation in four specific places (validation F1–F4).**
(a) The exposure-only benchmark E_i partially encodes the label (LOO at firm level, not cell level) — "exposure is the better model" is partly mechanical; rest the deflation on within-stratum + permutation, and report a cell-level leakage check.
(b) Within-stratum 0.471 is not shown falsifiable — add a granularity sweep (COARSE→MEDIUM→STRICT) + a positive-control score the design CAN detect.
(c) p=0.127 is a non-rejection used as evidence of null — add a power curve for permutation designs B/C (injected residual effect sizes).
(d) Strict timing freezes the SCORE but not the LABEL (always-loser + cobidder status use full-window data), and the headline prec@500=0 is driven by definitionally unrankable entrants — run one label-frozen timing benchmark and lead with the rankable-incumbent AUC 0.471 (the fair, damning number) instead of the strawman zero.
*All four are additive computations on existing data (~1 day), not new analyses of new objects. They armor the audit; they do not change conclusions (the within-stratum chance result is corroborated by CEM, matching, negative controls, and the intensity sensitivity).*

**M3 — Coherence under the paper's own thesis (§5–§7 referee 5.1, 6.4, 7.2).**
(a) §5 sequencing invites a rehabilitation misread — lead with "the gaps vanish under opportunity adjustment", present raw SMDs as the thing that vanishes.
(b) §6.2 must bridge explicitly: exposure-triage is legitimate even WITHOUT a residual conduct signal (cobidders cluster where exposure is high — mechanically — and routing forensic attention there is still an evidence-allocation decision). The inserted caveat disclaims; it does not yet affirm the frontier's actual object.
(c) §7.1 gaming subsection is incoherent as written (auditing evasion of a non-signal) — cut to one paragraph reframed as the anti-static-cutoff institutional warning (bunching/threshold-gaming), or move to the supplement.

**M4 — Contribution architecture (framing F2/F3).**
"Transferable audit framework" is asserted, not demonstrated; and the intro under-engages JLEO-core enforcement-design theory (optimal audit/inspection allocation; standards of proof; Decarolis et al. 2020 JLEO as organizational anchor, not just a procurement cite). Restructure the contribution paragraph: Contribution 1 = the ORGANIZATIONAL result (the award→bid recovery decision as a sequential cost-recall problem; the frontier is the object), Contribution 2 = the audit protocol (downgraded from "framework"). Adopt the referee's quotable principle: *"validating any administrative screen against adjudicated cases without adjusting for procurement opportunity systematically over-credits it."*

**M5 — §6.1 benchmark strawman exposure (§5–§7 referee 6.1).**
The "comparable discrimination" claim rests on an untuned 7-moment RF. Don't add models; reframe so the objection strengthens the thesis: a stronger bid model would RAISE the bid ceiling, increasing the value of triage-then-open sequencing. One paragraph in §6.1 main text (App E.6 already gestures at it).

**M6 — Length (framing F7).**
49pp double-spaced body for this payload reads padded. Target 35–38pp: fold §2.1 into §1 (the award-vs-bid cost point is made 4×), compress §7 to one section, trim appendix duplication (App E.5 restates §6.1 verbatim; lift column in Table E.1 is cherry-pickable — cut), one frontier figure not two.

## MINOR CONCERNS (fixed in this pass ✔ / pending ○)

✔ DeLong (1988) cited at first use (was used-but-uncited).
✔ green1984/haltiwanger1991 removed from the screen-gaming cite (mis-anchored).
✔ Fazekas & Kocsis (2020) verified (BJPolS 50(1):155–164, DOI 10.1017/S0007123417000461) and added to §1.
✔ 16,731 vs 16,772 pool sizes bridged explicitly (App E.7 candidate-pools paragraph).
✔ 341↔651 bridge: already present in §5 opening (referee missed it; no edit needed).
○ Defendant win-rate trio (0.261/0.086/14.9%) carries `% src: v13 legacy` — regenerate from current pipeline for full traceability (numbers corroborated, provenance only).
○ Web-verify 5 bibliographic details (oecd2022 report no./DOI; decarolis2020rules vol/pages; imhof2019; sanchezgraells2019; wallimann2023 vol/pages).
○ 6 dangling .bib entries (cinelli2020, imbens2015, karlin1956, oster2019, green1984, haltiwanger1991) — harmless; clean at leisure.
○ Tie-handling convention for AUC with 25% score-zero ties — one sentence.
○ ρ=+0.99 / ρ=−0.25 pairing: keep inseparable (currently good); Table E.1 lift column cut per M6.
○ Per-case RI clustering + few-clusters acknowledgment (ties into M2d/M3).

## POSITIVE ASPECTS (uncontested across referees)
Non-circular 651 label with composition disclosure; scope-check asymmetry (binary 0.49 on defendants — clean confirmed prediction); case-grouped collapse honestly reported (combined < award-only); negative controls given destructive weight; denominator-honest frontier with the K1=1000>2000 anomaly reported as evidence against optima; numbers forensically clean; zero overclaim residue; cover letter COVER_LETTER_PASS.

## ACTION PLAN (priority-ordered, for Darcio's decision)
1. **M4 reframe** (contribution paragraph + quotable principle + org-lit sentences) — prose only, highest leverage on P(desk).
2. **M1 stakes** (3–5 sentences, Fazekas/OECD already in) — prose only.
3. **M2 armor pack** — 4 cheap computations on existing data: cell-level E_i leakage check; granularity sweep + positive control; permutation power curve; label-frozen timing run. ~1 day compute+writing. *Requires waiving "no new analyses" for audit-of-the-audit purposes — author call.*
4. **M3 coherence** — §5 reorder; §6.2 bridge paragraph; §7.1 cut/reframe — prose only.
5. **M5 strawman judo** — one paragraph §6.1.
6. **M6 compression** — fold §2.1, trim §7 + appendix duplication; target 35–38pp.
7. Minor ○ items.

## VERDICT

**HOLD_FOR_REVISION (major-revision-equivalent, tractable).** Integrity verdicts: NUMBERS_CLEAN · REFERENCES_NO_FABRICATION · HYGIENE_CLEAN · VISUAL_PASS · COVER_LETTER_PASS. Substance verdicts: §4 CREDIBLE WITH REPAIRS · §5/§6 KEEP WITH REPAIRS · §7.1 RESTRUCTURE/CUT · framing P(desk)≈0.45 as-is.
Estimated effort to convert: prose items (1,2,4,5,6) ≈ 1–2 days; computation pack (3) ≈ 1 day. Post-repair calibration: P(desk) → ~0.25–0.30; P(R&R | refereed) → ~0.55–0.60.

---

## ACTION PLAN EXECUTION ADDENDUM (2026-06-04, same day)

**Status: ALL ITEMS EXECUTED** (M2 computations authorized by author via "executa o Action Plan").

| Item | Execution |
|---|---|
| M1 stakes | sec01: Fazekas/OECD institutional-red-flag lineage + counterfactual-practice sentences |
| M2 armor pack | scripts 12/12b (`outputs/diagnostics/audit_armor/`): exposure tiers (O_i 0.905 / plug 0.985 / firm-LOO 0.855 / **label-blind 0.553**); granularity sweep 0.508/0.493/0.600 + **positive control O_i 0.953** (falsifiability proven); permutation power **0.97 @ within-AUC 0.55** (size 0.05 — non-rejection bounds residual < ~0.55); label-frozen timing pool 13,051, prospective **0.713** (231 pos), retrospective 0.718; defendant roles regenerated (14.9%/0.261; cobidder WR ≡ 0 by construction — dead 0.086 removed from prose). Integrated: §4.2 re-tiered (no more "exposure is the better model" — tiers + entanglement statement), §4.3 label-frozen variant, §4.4 fix, App C "Audit of the audit" subsection, \valArmor* macros |
| M3a §5 | re-sequenced: vanish leads; raw SMDs = "what adjustment removes"; winner-null sentence added; closing contradiction removed |
| M3b §6.2 | positive bridge paragraph (exposure-triage coherent absent conduct residual; frontier prices the policy; §4 forecloses the certification reading) |
| M3c §7.1 | gaming reframed as instability-of-published-cutoff (option b); App F.6 intro reframed as institutional-design exercise; one paragraph in main |
| M4 | contributions reordered (C1 organizational result; C2 audit protocol, "framework" downgraded; C3 reach/limits map); quotable principle in abstract+intro+conclusion; Becker–Stigler margin + Decarolis 2020 JLEO engagement |
| M5 | strawman judo in §6.1 main text (stronger bid model ⇒ stronger sequencing argument) |
| M6 | §2.1 folded into §1 (sec02 −18.5%); §7 compressed; App E dedup (headline-number restatements → pointers; Lift column cut; boilerplate −2); joint-ceiling labels |
| Minors | DeLong cited; green/haltiwanger re-anchored; Fazekas verified+added; 16,731/16,772 bridged; 341↔651 verified present; defendant-trio provenance regenerated |

**Note on the armor findings (honest update to the report's own M2):** the leakage audit
confirmed the validation referee's F1 beyond expectation — genuine label-blind opportunity
ranks the label at only 0.553, so the earlier "exposure is the better model" framing was
itself partially mechanical and has been removed. The deflationary verdict is unchanged but
re-grounded: the decisive evidence is the anchor-agnostic battery (negative controls,
powered permutation, label-frozen timing), and the §4 prose now says exactly that.

**Build after execution:** 4/4 docs 0 errors / 0 undefined; paper 54 pp + appendix 49 pp
(JLEO pair); abstract 133 words; package + PDFs refreshed.

**Post-repair calibration (updated):** P(desk) ≈ 0.25; P(R&R | refereed) ≈ 0.55–0.60.
**Remaining before upload:** author read of the revised §1/§4/§5/§6/§7 narrative
(substantial prose changed today) + author declarations. The paper is now at
**READY_FOR_AUTHOR_FINAL_READ**.
