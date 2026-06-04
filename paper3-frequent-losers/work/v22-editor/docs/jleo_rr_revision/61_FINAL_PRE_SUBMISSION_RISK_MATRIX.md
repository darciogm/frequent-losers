# 61 — FINAL PRE-SUBMISSION RISK MATRIX

**Paper:** *Cheap Signals, Costly Proof* — Genicolo-Martins & de Azevedo. JLEO R&R, branch `v22`. **Date:** 2026-06-03.
**Mode:** hostile-Referee-2; realistic, not promotional. **Grounding:** docs 44, 45, 52, 55, 04, 02, 62; sec01/sec08/frontmatter.

Severity: **low / med / high / fatal**.

> ## TOP-LINE: **NO FATAL RISKS.** Posture = GO WITH MINOR REPAIRS.
> The two genuine **Highs** are *retrospective power* (R12) and *single-case dominance* (R5) — both are the paper's own "reach and limits" thesis, disclosed and front-paged, not concealed identification failures. They cap the paper's ceiling (this is a bounded, honest result, not a strong detector) but do not sink it. The only hard *blockers* are formatting (double-spacing + margins) and human declarations, all trivial/external.

---

| # | Risk | Severity | Evidence in main | Evidence in appendix | Remaining vulnerability | Likely referee sentence | Best response | Pre-submission action | Status |
|---|------|----------|------------------|----------------------|-------------------------|-------------------------|---------------|-----------------------|--------|
| 1 | Mechanical exposure not fully solved — pooled power is opportunity | high→med | §4.2 Table 3; within-stratum 0.7715 vs exposure-only 0.946 (+0.042, DeLong p≈2e-6) | App C.1 control-function | Residual is only +0.04; exposure-only alone already 0.946 — "the construct is mostly arithmetic" | Conceded and converted to contribution: we *decompose* and report the bounded residual; direction + significance, not magnitude | None (done); keep "+0.04 beyond exposure" wording, never "0.92 is exposure-free" | defended |
| 2 | Label target weak — 193 cobidders is what, exactly? | med | §4.1 Table 2; §5 profile | App A.2 funnel; App D.1 | Target is a constructed exposure footprint, not a validated cartel set | "Your positive class is an artifact of your own builder" | Adjudication-anchored exposure, explicitly not membership; §5 gives it economic content beyond high-volume losing | None (done) | defended |
| 3 | 193-vs-210 confusion / reconciliation | med | §4.1 Table 2 (funnel) | App A.2 | Builder absent (B3); main 193→341 broad def does NOT reproduce | "These numbers don't reconcile / aren't reproducible" | Definition difference not bug; conservative 208/107/19 reproduces; `79_label_funnel.R` is the transparent path; B3 disclosed | None (done); ensure cover letter/replication restate B3 | defended |
| 4 | Timing too retrospective — score uses post-investigation participation | **high** | §4.3 Table 4; strict 2009-16→2017-19 | App C.2 | Strict-timing power modest; **sequential strict-timing BLOCKED** (bid features not time-limitable); script 77 FAIL | "The screen is retrospective; it can't be deployed prospectively" | This is the thesis: "discriminating power is largely retrospective and incumbent-specific" (sec01/sec08); disclosed as a reach limit, not hidden | None (done); do NOT let any "prospective" claim creep back | disclosed (on-thesis) |
| 5 | Case dominance — one cartel does the work | **high** | §4.3 leave-one-case-out | App C.3; App B survival | Leave-largest-case-out recall 0.48→0.34; one case ≈55% of positives | "Delete the big case and you have nothing" | Reported as a limit; "map of reach and limits" absorbs it; LOCO is part of the decomposition method | None (done); keep LOCO inline | disclosed (on-thesis) |
| 6 | Direct-defendant null overinterpreted as "scope, not failure" | med | §4 Table 4 scope row; §5; §8 | App C | A referee may read 0.49 as "the screen just fails" | "AUC≈0.5 means it doesn't work" | Front-paged as a *scope result*: a loser-side screen should miss win-heavy direct defendants (D4); the asymmetry is the design | None (done) | defended |
| 7 | Profile is descriptive-only | med | §5 | App D.1 standardized diffs | No causal/structural content; just standardized differences | "§5 is descriptive padding" | Explicitly descriptive economic-content para; volume-matched; no causal claim made | None (done) | defended |
| 8 | Binary FL14 threshold arbitrary / gameable | med | §3.2; §7.2 bunching | App E (deployment) | median+1.5·IQR is administrative, not structural | "Why 14? Arbitrary cutoff" | FL14 = administrative operationalization, explicitly not legal/structural; continuous rank is the object; refreshed queues/top-k/bunching (ratio 1.06) | None (done) | defended |
| 9 | Global zero-win definition too blunt | med | §3 | App A.2 | Firm-level zero-win ignores market-level persistence | "A firm losing everywhere ≠ losing in one market" | Acknowledge; market-conditional variant offered; `>` vs `≥` cut documented | confirm §3 acknowledgment present | minor (verify) |
| 10 | Bid-benchmark opacity | med | §6.1 Table 5 | App E.1 (features/learner/CV/missingness/holdout) | Imhof RF benchmark spec must be fully documented; leakage-sensitive | "Your benchmark is a strawman / leaks" | Documented benchmark audit; 0.888 vs 0.921, joint 0.962; sold as complementarity not dominance; leakage conceded | confirm App E.1 spec table complete | defended |
| 11 | Bid-feature support loss | med | §6.1 | App E.1 | Bid features unavailable for many firms → support shrinks; combo AUC leakage-sensitive | "The 0.962 combo is on a thin, leaky support" | Disclosed leakage-sensitivity; report support; complementarity claim survives even discounted | confirm support/leakage caveat inline | defended |
| 12 | Cost-recall is cost-proxy based, not real cost | high→med | §6.2 Table 6, Fig 3 | App E.2/E.3 | Denominators (firm/tender-item/bid-row) are proxies for recovery cost | "Your 'cost' isn't a cost; it's a count" | Denominator-honest by design: firm 88% vs bid-row 33% reduction *is* the transparency point; frontier not optimum; beats random 3–12× | None (done) | defended |
| 13 | Price sign reversal | med | §7 | App F.1 | +0.064 broad → −0.097 overlap; could read as confused | "Your price result flips sign — what is it?" | Scope-only; the reversal *is* selection evidence (overlap-cell), not a markup; no damages/overcharge/causal language | None (done) | defended |
| 14 | Theory / exit margin overformalized-or-weak | med | — (modest main use) | App B (Assumption B1, Prop B1, Cor B1, λ_C>λ_G, survival) | MLR ranking is a maintained-condition justification, not identification; exit censored at 2019 | "The theory is decorative" OR "the survival claim is post hoc" | Presented as maintained-condition ranking + exit-margin sketch + survival audit (cobidders persist longer); not a structural estimate | None (done) | defended |
| 15 | Appendix too long | med→low | — | 31pp / 11 tables / 2 figures (A–F) | 31pp > 25–30 target; still long for an article | "This appendix is a second paper" | Compressed 55→31pp; 18 grids moved to online supplement; each fatal threat keeps an inline anchor | None (done); online supplement payload is a packaging step | acceptable |
| 16 | Replication / data confidentiality | med | endmatter | — | BEC microdata not redistributable; B3 builder absent | "Can't replicate" | Full package (README/SCRIPT_ORDER/OUTPUTS_MAP/MANIFEST + supplement); proprietary-data exemption; funnel reproduces label | confirm online-supplement payload assembled before upload | acceptable |
| 17 | JLEO style / admin noncompliance | high | — | — | Double-spacing 1.48 (not 2.0); margins 28–30mm (<1.25in) | "Returned for formatting" (desk) | Both are one-line LaTeX changes + recompile; content unaffected | **BUILD double-spaced + ≥1.25in margin review PDF** | **OPEN (blocker)** |
| 18 | Cover-letter overclaims | low | — | — | Cover letter could oversell | "Letter promises more than the paper delivers" | Letter is discipline-honored: no AUC, forensic-priority/scope language, contributions qualitative (doc 62) | confirm final letter matches v22 abstract (142–146w) | controlled |
| 19 | Contribution not organizational enough | med | §1 ¶6, §6, §8 | — | Empirical spine (§4 decomposition) reads IO; org content shares billing with method+map | "This is an IO screening paper, not L&E-of-Organization" | Division-of-labor is load-bearing (survives deleting AUCs); §6 is the affirmative org payoff; cover letter leads sequencing | confirm cover letter leads with sequencing/division-of-labor | controlled (see doc 60) |
| 20 | Legal language too strong | low | throughout | App A/F | Risk of "membership/proof/damages" creep | "You're claiming liability you can't prove" | Claims scan 0 critical; all risky terms negated; "liability remains in richer record"; price = scope | re-run claims scanner on final build | defended |

---

## Severity tally
- **fatal: 0**
- **high (residual, on-thesis): 2** — #4 retrospective power, #5 single-case dominance. These are disclosed thesis elements; they cap the ceiling, not the floor.
- **high (blocker, mechanical): 1** — #17 formatting build (trivial).
- **med: ~12** (all conceded + bounded + defended).
- **low/controlled: ~4.**

## Pre-submission action list (only the open items)
1. **#17 — build a double-spaced (≥1.66, ideally `\doublespacing`/2.0) + ≥1.25in (31.75mm all sides) review PDF.** Hard blocker for a clean upload.
2. **#16 — assemble the online-supplement payload** (manifested dirs exist; populate files).
3. **Human declarations (doc 62):** exclusivity, $100 fee/waiver eligibility, corresponding-author email, COI, funding, data-use permission, preprint, suggested reviewers. All external.
4. **#9, #10, #11, #18, #19, #20 — verification (not rework):** confirm acknowledgments/benchmark-spec/support-caveat/cover-letter-lead present in the final build; re-run claims + number scanners.

## Net
No fatal risk → **GO WITH MINOR REPAIRS**. The repairs are formatting + packaging + human sign-offs, not content. The honest ceiling is set by #4 and #5: this is a *bounded, honest reach map*, and it should be submitted as one — not as a strong screen.
