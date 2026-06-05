# Decision Package D-iii — Federal Section Placement + Float Budget

**Paper:** *Frequent Losers in Public Procurement* — JLEO R&R, v22.
**Decision owner:** author (Darcio). **Prepared:** 2026-06-05. Read-only diagnostic; no manuscript file was edited.
**Scope:** where the new federal comparative section goes, whether its side-by-side table earns a 7th main float, and how to pay for the +3pp.

---

## 0. Verified current inventory (ground truth, not the stale CLAUDE.md belief)

Source: grep over `submission_clean/sec0*submission.tex` + `\input` order in `paper_submission_clean.tex` + last build logs.

| Quantity | Verified value | Evidence |
|---|---|---|
| Main tables | **6** (balanced `\begin/\end{table}` = 6/6) | `tab:populations_submission`, `tab:label_funnel_submission`, `tab:opportunity_adjusted_validation`, `tab:timing_case_holdout`, `tab:bid_layer_performance`, `tab:cost_recall_frontier` |
| Main figures | **3** (not 2 — CLAUDE.md belief is stale) | `fig:coarsening_submission`, `fig:observed_vs_expected_contact`, `fig:cost_recall_frontier` |
| Main-text length | **40 pp** (`paper_submission_clean.pdf`); 54 pp in the `paper_jleo_submission` variant with full frontmatter | `Output written on … (40 pages)` / `(54 pages)` |
| Online appendix length | **34 pp** (`online_appendix_submission_clean`) / 49 pp (jleo variant) | build logs |
| Main sections | **8**: §1 Intro, §2 Costly Proof/Observable Awards, §3 Award-Layer Triage, §4 Validating the Loser-Side Ranking, §5 Economic Content & Ordinary-Loser Alternatives, §6 Award→Bid Forensics, §7 Scope/Limits/Price, §8 Conclusion | `\section{}` grep |
| **Table-4 = opportunity-adjusted validation** | `tab:opportunity_adjusted_validation` in `sec04_validation_submission.tex` — the named target for the "Panel B fold" option | confirmed: 9-col body `p{3.6cm}lccccccl`, 10 design rows |

**Float budget headroom:** discipline cap is ≤6 main tables / ≤3 main figures. We are at **6/3 — both caps are already saturated.** Any new main float is over-cap and needs explicit justification or a compensating demotion.

**Two federal drafts already on disk (neither `\input` anywhere):**
- `sec_comparative_DRAFT.tex` — the ~3pp main-text section ("The Audit on a Second Platform", `\label{sec:comparative}`), 5 subsections + 1 side-by-side table (`tab:comparative_audit`, 8 audit rows × 2 platforms), all numbers `\valTODO` placeholders pending the federal run chain.
- `sec_appG_federal_DRAFT.tex` — proposed Appendix G "Federal Audit Battery" (`\label{app:federal_audit_submission}`), the full federal deflation battery the comparative section's table notes point to.
- Pre-existing `sec_app07_comprasnet_submission.tex` (`\label{app:comprasnet_submission}`) — the headline-replication appendix; **currently orphaned** (not `\input`, not `\ref`'d from main text). App G is its companion (the audit battery vs. the what-survives replication).

---

## 1. PLACEMENT — Option A (new §5) vs Option B (§4.5 inside validation)

### Renumbering cost (measured, not estimated)
All main-text cross-refs use **symbolic** `\ref{sec:...}` labels, so LaTeX renumbers automatically — **zero manual `\ref`/`\label` edits** under either option. The cost is reader-facing number churn, not edit churn. Affected symbolic refs if a section is inserted at the §4/§5 boundary:

| Ref target | # uses in main text | Number shifts under Option A? |
|---|---|---|
| `\ref{sec:validation}` (§4) | 5 | no (stays §4) |
| `\ref{sec:cobidder_type}` (§5) | 3 | yes → §6 |
| `\ref{sec:screening_forensics}` (§6) | 5 | yes → §7 |
| `\ref{sec:price_scope_conclusion}` (§7) | 1 | yes → §8 |
| `\ref{sec:conclusion}` (§8) | — | yes → §9 |
| validation sub-refs (`_timing`,`_exposure`,`_direct`,`_label_funnel`) | 11 | no (all inside §4) |

Option A shifts **the printed numbers of §5–§8 (and ~9 cross-refs resolve to the new numbers automatically)**. Option B shifts **nothing** (federal section becomes §4.5; §5–§8 unchanged).

### Option A — new §5 "The Audit on a Second Platform" (after §4, shifting §5→§6 … §8→§9)
- **Narrative flow:** §4 ends by explicitly promising the cross-platform test ("the same audit, run on another platform, would show where … a cheap screen retains residual value there" — `sec04` line 235-237). A standalone §5 *pays off that promise immediately*, before the paper pivots to economic content (§5-old) and forensics (§6-old). Clean "validate → port the validation → then interpret" arc.
- **JLEO-reader impression:** a top-tier methods reader reads a free-standing "second platform" section as a **portability claim with its own standing** — signals the contribution is the *audit-as-method*, which is exactly the paper's defensible product. Strong for a referee who pushed for external validity.
- **Cost:** §5–§8 renumber (auto); the paper visibly grows a section (8→9), which slightly dilutes the "compressed, disciplined" silhouette JLEO compression prizes.

### Option B — §4.5 inside §4 (validation), no renumbering
- **Narrative flow:** the federal audit is literally "the same audit, re-run", so nesting it as the final subsection of the validation section is logically tight — it reads as the last move of the validation battery rather than a new theme.
- **JLEO-reader impression:** a subsection reads as **a robustness/portability check subordinate to the BEC validation**, not as an independent contribution. This *undersells* portability — and §4 is already the paper's longest, most float-dense section (3 tables + 1 figure across the label funnel, opportunity adjustment, and timing). Adding a 3pp federal block + a 2-platform table makes §4 ~9-10pp and four-to-five floats deep, which is the section a referee already finds heaviest.
- **Cost:** zero renumbering; but it buries the cross-platform result and overloads the single heaviest section.

### ▶ RECOMMENDATION — **Option A (new §5)**
The section's own framing ("tests portability of the *method*", "does double duty", `sec:comparative`) is a standalone claim, and §4 explicitly sets it up as a separate move. A subsection fold would subordinate a portability contribution to a robustness check and overload the already-heaviest section. The renumbering cost is purely automatic (symbolic refs) and the 8→9 section count is a fair price for foregrounding the paper's most referee-salient external-validity result. **Rename note:** if the author wants to hold the 8-section silhouette, place it as the *new §5* but title the old §5 "Economic Content" sequence so the spine still reads validate→port→interpret→forensics.

---

## 2. TABLE — Option (i) 7th main table vs Option (ii) fold as Panel B of Table 4

The federal side-by-side is `tab:comparative_audit`: **8 audit-stage rows × 2 platform columns** (BEC-SP, ComprasNet), p{5.4cm}cc layout. The 8 rows are: raw AUC, label-blind opportunity AUC, within-stratum residual, power-bounded detection prob @ true AUC 0.55, matched-permutation p, label-frozen prospective timing AUC, top-case positive share, negative-control verdict.

### Option (i) — standalone 7th main table (over the ≤6 cap)
Sketch (as drafted, ready to `\input`):

```
Table 7. The Audit on Two Platforms: BEC-SP versus ComprasNet
------------------------------------------------------------------
Audit stage                                    | BEC-SP | ComprasNet
Raw award-layer ROC-AUC                        |  ...   |   ...
Label-blind opportunity expectation (AUC)      |  ...   |   ...
Within-stratum residual (AUC, MEDIUM cells)    |  ...   |   ...
Power-bounded residual (det. prob @ AUC 0.55)  |  ...   |   ...
Matched-permutation p (within-strata shuffle)  |  ...   |   ...
Label-frozen prospective timing (AUC)          |  ...   |   ...
Top-case concentration (share of positives)    |  ...   |   ...
Negative-control verdict                       |  ...   |   ...
------------------------------------------------------------------
```
- **Pros:** the comparison *is* the section's payload; a dedicated float lets the reader read the audit's *shape* (does each discipline move the federal verdict the way it moves BEC) at a glance. Self-contained, referee-legible, mirrors the BEC audit table style.
- **Cons:** 7th main table breaks the ≤6 discipline; needs explicit justification in the cover letter ("the cross-platform contribution is a table-shaped object").

### Option (ii) — fold as **Panel B of `tab:opportunity_adjusted_validation`** (Table 4)
Table 4 is currently a **9-column** opportunity-adjusted grid (Design | Score | N | Pos. | ROC-AUC | PR-AUC | Prec@500 | Rec@500 | CI/p) with 10 BEC rows. Fold sketch:

```
Table 4. Opportunity-Adjusted Validation of the Award-Layer Ranking
Panel A. BEC-SP  [existing 10 rows, 9 columns, UNCHANGED]
  Design                | Score | N | Pos | ROC | PR | P@500 | R@500 | CI/p
  Raw score ...         |  ...  |...|...|...|...|...|...|...
  ... (10 rows) ...
Panel B. ComprasNet (federal portability)   <-- NEW
  Audit stage           | (federal value)   [2-col shape, NOT 9-col]
  Raw award-layer AUC   |  ...
  ... (8 rows) ...
```
- **The structural mismatch is the problem.** Panel A is a 9-column, firm-counted, per-design grid; the federal side-by-side is a 2-column (stage | value) audit-shape object whose *point is the BEC-vs-federal contrast on each stage*. Folding it into Panel B either (a) forces the 8 federal rows into the 9-column Panel-A skeleton (most columns blank/N-A → ugly, and it loses the side-by-side contrast that is the whole point, because BEC would be Panel A and federal Panel B, so the reader can no longer read a stage *across* platforms on one line), or (b) keeps the 2-col shape inside a panel of a 9-col table (column-count clash → adjustbox fights, visually broken).
- **Verdict on overload:** the fold **breaks the comparison's core affordance** (read each audit stage across both platforms on one row) and **column-clashes** with the host table. It overloads Table 4 both visually and semantically.

### ▶ RECOMMENDATION — **Option (i): standalone 7th main table**
The side-by-side genuinely needs its own float to be referee-legible: its payload is the *cross-platform shape* of the audit (each stage read across BEC vs. ComprasNet on one row), which the 9-column firm-level grid of Table 4 cannot host without losing the contrast and column-clashing. Justify the 7th table in the cover letter as "the external-validity contribution is inherently a comparison table; PR-AUC remains the lead metric per the rare-target convention." The +1 main table is paid for by the appendix demotion below, keeping the *paper's* float discipline credible.

---

## 3. LENGTH COMPENSATION — App D profile detail + App F adaptation detail → online supplement

**Locations (verified in the appendix `\input` order of `online_appendix_jleo_submission.tex`):**
- **App D = `sec_app08_profile_submission.tex`** — "Economic Profile and Robustness: Construction and Diagnostics" (`app:profile_submission`). **187 lines.** Subsections: Comparison Groups & Profile Variables (39 ln), Standardized Differences + SMD table (81 ln, contains `tab:profile_smd_submission`), Robustness (38 ln), Limitations (11 ln).
- **App F = `sec_app04_scope_submission.tex` (130 ln) + `sec_app05_adaptive_deployment_submission.tex` (32 ln)** — "Price Scope and Adaptive Use" (`app:scope_adaptation_submission`) + "Instability of a Published Cutoff Under Strategic Response" (`app:strategic_adaptation_submission`). The **adaptation detail** specifically = the 32-line `sec_app05` block + the segment/mechanism subsections of `sec_app04` (`app:scope_segment_submission`, `app:scope_mechanism_submission`, `app:scope_limits_submission`).

**Key correction for the author:** App D and App F are **already in the online appendix PDF, not in the 40pp main paper.** So "demote to online supplement" relieves the **appendix** page mass (currently 34pp), *not* the main 40pp. The +3pp from the new §5 lands on the **main paper** and is **not** offset by appendix demotion. The two budgets are separate ledgers:

- **Main-paper ledger:** 40pp + ~3pp new §5 ≈ **43pp main** — still inside the 30-38pp *target band's* tolerance only if the section runs lean; **this is the real budget pressure and it is NOT paid by appendix demotion.** To hold ≤ ~40pp main, the new §5 must be trimmed to ~2.5pp OR a comparably-sized main-text block must be demoted (candidates: the §6 bid-benchmark prose already has an appendix twin `sec_app09_bid_benchmark_submission`; or tighten §7 scope prose whose detail already lives in App F).
- **Appendix ledger:** demoting App D's Robustness+Limitations (49 ln ≈ ~1pp) and App F's adaptation/segment/mechanism detail (~80 ln ≈ ~1.5-2pp) to a *deeper online supplement* nets **-2 to -3pp off the appendix**, which is cosmetic relief for the appendix but creates room there for the new **Appendix G federal battery** (`sec_appG_federal_DRAFT`, 305 ln ≈ ~5-6pp) so the appendix doesn't balloon.

**Demotion feasibility (cross-ref audit):** safe. Main text `\ref`s only the *top-level* anchors `app:profile_submission` (1 use, sec05) and `app:scope_adaptation_submission` + `app:strategic_adaptation_submission` (sec07). The **sub-block labels proposed for demotion** (`app:profile_robustness_submission`, `app:profile_limits_submission`, `app:scope_segment_submission`, `app:scope_mechanism_submission`, `app:scope_limits_submission`) are **referenced from NOWHERE in the main text** — demoting them breaks no `\ref`. Keep the top-level App D/App F shells (with their main-text-anchored intro subsections) in the appendix; move only the un-referenced detail subsections to the online supplement.

### ▶ RECOMMENDATION — **Demote, but fix the ledger framing**
Demote the un-`\ref`'d detail blocks (App D Robustness+Limitations; App F segment/mechanism/limitations + the `sec_app05` adaptation block) to the online supplement: -2 to -3pp **on the appendix**, zero broken refs. **But:** this does NOT pay for the +3pp main-text §5 — that pressure is real and separate. To hold the main paper at ~40pp, trim §5 to ~2.5pp **and** demote one already-twinned main-text block (the §6 bid-benchmark prose is the cleanest candidate — it has an appendix twin). **Net budget:** main ≈ 40-43pp (needs the §5-trim + one main demotion to stay ≤40); appendix ≈ 34 - 2.5 (App D/F demote) + 5.5 (new App G) ≈ **37pp** appendix.

---

## 4. RECOMMENDATION SUMMARY (one line each)

| Choice | Recommendation | One-line rationale |
|---|---|---|
| **Placement** | **Option A — new §5** | §4 explicitly promises the cross-platform test; a standalone section pays it off and foregrounds portability as a contribution rather than burying it as a §4.5 robustness check that overloads the heaviest section. |
| **Table** | **Option (i) — standalone 7th main table** | The payload is the cross-platform *shape* read across both columns per row; the 9-column firm-level Table 4 cannot host this without column-clash and loss of the contrast — justify the 7th float in the cover letter. |
| **Compensation** | **Demote un-`\ref`'d App D/F detail → online supplement (-2-3pp appendix) AND trim §5 to ~2.5pp + demote §6 bid-benchmark prose (twinned) to hold main ≤40pp** | Appendix demotion is ref-safe but relieves the *appendix* ledger, not the main paper; the main +3pp must be paid in the main ledger separately. |

---

## 5. EXACT QUESTION SET FOR THE AUTHOR (verbatim for the lead to present)

1. **Placement:** Confirm the federal comparative material becomes **a new standalone §5 "The Audit on a Second Platform"** (shifting old §5-§8 → §6-§9, all auto-renumbered)? Or do you prefer it folded as **§4.5** inside Validation (no renumbering, but subordinates the portability claim)?

2. **Section-count silhouette:** If §5 standalone, are you comfortable the printed main-text section count goes **8 → 9**? (Alternative: keep the 8-spine narrative but accept the larger number.)

3. **Table — over-cap approval:** Confirm a **7th main table** (`tab:comparative_audit`, the BEC-vs-ComprasNet side-by-side) over the ≤6 discipline, justified in the cover letter? Or do you want me to attempt the **Panel-B fold into Table 4** despite the 9-col-vs-2-col structural clash and loss of the across-platform read?

4. **Table metric:** The draft notes say "PR-AUC is the lead metric for rare-target rows; ROC-AUC shown for comparability." Confirm the 2-platform table reports **both** (as drafted), or ROC-AUC only for cross-platform comparability?

5. **Compensation — main ledger:** The +3pp §5 lands on the **main paper** and is **not** offset by appendix demotion. To hold the main paper ≤ ~40pp, approve (a) trimming §5 to ~2.5pp, **and** (b) demoting the §6 bid-benchmark prose (which already has appendix twin `sec_app09`) to the appendix? Or do you accept the main paper drifting to ~43pp?

6. **Compensation — appendix ledger:** Approve demoting the **un-`\ref`'d** detail subsections — App D Robustness+Limitations (`app:profile_robustness_submission`, `app:profile_limits_submission`) and App F segment/mechanism/limitations + the `sec_app05` adaptation block — to the **online supplement** (-2-3pp appendix, zero broken refs), to make room for the new **Appendix G federal battery** (`sec_appG_federal_DRAFT`, ~5-6pp)?

7. **Appendix G + orphaned App07:** Confirm wiring **both** federal appendices: the **new Appendix G** (`app:federal_audit_submission`, the full deflation battery the §5 table notes point to) **and** the currently-**orphaned** `sec_app07_comprasnet_submission` (`app:comprasnet_submission`, the headline-replication appendix)? Or only one of the two?

8. **Draft A vs Draft B paragraph:** The §5 "Interpretation" subsection carries two mutually-exclusive paragraphs (Draft A = federal residual also vanishes / deflation replicates; Draft B = residual survives federally → institution-coupled value). This is resolved by the federal run-chain numbers — confirm we keep **both in the draft** until Phase 1/2 numbers land, then delete one?
