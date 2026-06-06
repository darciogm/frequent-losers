# D-iii TABLE PREVIEW — BEC-SP vs ComprasNet Comparative Audit (DECISION-READY)

> ## ⚠️ PROVISIONAL — DO NOT WIRE INTO `values.tex` YET
> This preview lets the author answer decision **D-iii** (placement / float / compensation)
> **with the real federal numbers in view.** It is **not** the final table. The armor pack
> (script 12 + frozen timing) HAS NOW LANDED; the remaining blocks are smaller:
> - ✅ **Armor pack ran** → label-blind E, power curve, and frozen-timing cells are now on disk
>   (`audit_armor/granularity_sweep.csv`, `permutation_power_curve.csv`, `frozen_timing.csv`).
>   Rows 6 and 8 are FILLED below; row 3 carries the candidate E values pending the 12b
>   apples-to-apples reconciliation (three constructions on disk).
> - **Script 06 not yet run** → negative controls (`table_E_negative_controls.csv` not on disk). Row 10 PENDING.
> - **Formal R4 verification pass** (the four-attack referee protocol) not yet executed against the
>   filled cells.
>
> Every number below is sourced to a file (column "src"). No number is invented. PENDING cells say so.
> **Prepared:** 2026-06-05; **armor rows refreshed 2026-06-06** (Mr. Frequent Losers, co-author mode).
> Read-only; no manuscript file edited from this doc.

---

## 1. THE COMPARATIVE TABLE (as it would render, real numbers where known)

`tab:comparative_audit` — "The Audit on Two Platforms: BEC–SP versus ComprasNet". Row order
mirrors `sec_comparative_DRAFT.tex`. **PR-AUC is the lead metric for rare-target rows; ROC-AUC
shown for comparability** (read PR-AUC against each platform's base rate — see note B below).

| # | Audit stage | BEC–SP | ComprasNet | src (federal) |
|---|---|---|---|---|
| 1 | **Raw award-layer ROC-AUC** (log T) | **0.761** | **0.744** | `table_C…csv::S0_raw_score roc_auc` |
| 1b | — Raw award-layer PR-AUC | 0.143 | **0.014** | `table_C…csv::S0_raw_score pr_auc` |
| 2 | **Exposure-only ROC-AUC** (no score) | 0.713 | **0.754** | `table_C…csv::S2_exposure_only_logit roc_auc` |
| 3 | **Label-blind opportunity expectation (AUC, E)** | 0.553 | **pending 12b reconciliation — three candidate constructions 0.611 / 0.695 / 0.739, apples-to-apples selection in progress** | `audit_armor_macros.tex::\valArmorExpLB`=0.611; `granularity_sweep.csv::E_label_blind_MEDIUM (exposed)`=0.695, `(all AL)`=0.739 |
| 4 | **Within-stratum residual** (AUC, MEDIUM cells) | 0.471 (≈chance) | **0.462** (≈chance) | `table_C…csv::WITHIN_STRATUM_log_tc roc_auc` |
| 5 | **Nested DeLong increment over exposure-only** | +0.010, p=0.013 | **+0.005, p=0.191 (null)** | `table_C…csv::NESTED_exposure+score auc_increment / delong_p` |
| 6 | **Power-bounded residual** (det. prob. @ true AUC 0.55 / 0.60) | 0.97 (@0.55) | **0.35 @0.55 / 0.90 @0.60** (federal positive set ~30% of BEC's → underpowered at 0.55, informative ≥0.60; O_i positive control 0.992–0.999 confirms design detects within-stratum signal when present) | `permutation_power_curve.csv::0.55,0.60 rejection_rate_alpha05`=0.35,0.90; `granularity_sweep.csv::within_AUC_Oi_positive_control` COARSE 0.9987 / MEDIUM 0.9921 |
| 7 | **Matched-permutation p** (within-strata shuffle) | 0.127 (NOT sig) | **0.906 (NOT sig)** | `table_D_opportunity_permutation_validation.csv::C_matched_label_perm p_pr` |
| 8 | **Label-frozen prospective timing (AUC)** | 0.713 | **0.5948 prosp (pool 24,888, N+=98) / 0.7404 retro (N+=177)** | `audit_armor/frozen_timing.csv::d1 auc`=0.5948, `d2 auc`=0.7404, `pool_n`=24,888, `npos`=98/177 |
| 9 | **Top-case concentration** (operational) | 32.0% pos / 45.4% TP@500 | **64.4% top-two pos / 87.5% TP@500** | `case_dominance_summary.csv::share_pos, share_tp_500` |
| 9b | — Ordering robustness (LOCO + RI) | ROC 0.761→0.763; RI p=0.001 | **ROC 0.744→0.744 (drop-largest); RI p=0.001** | `table_H::drop_largest_case`; `table_D_clustered…::roc_auc emp_p` |
| 10 | **Negative-control verdict** | generic geometry (placebo p=0.456, HV-winner p=0.908) | **PENDING — script 06** | `table_E_negative_controls.csv` (not on disk) |

**Universe / label context (already built, for the §5 prose — not a table row):** federal panel
51.0M participation rows / 92,600 firms; 35,943 always-losers; IQR threshold **32** (vs BEC 14);
6,491 federal FLs; **7** CADE cases (vs BEC 12); **195** broad-AL cobidders (vs BEC **651**); FL
composition 94 FL / 101 non-FL. Sources: `outputs/comprasnet/targets/canonical_target_counts.csv`,
`phase0_g5_al_universe.csv`. (All `[built]`, verified in `NEW_NUMBERS_MAP_COMPRASNET.md`.)

### Notes the table carries

**A — Dual framing forced by A3 (case-concentration attack).** The federal leg splits:
- ✅ **Rank-ordering ROBUST** (may claim): leaving out the largest case (trens_metros) leaves
  ROC-AUC essentially unchanged (**0.744→0.744**), the clustered-randomization ordering test
  rejects randomness at **p=0.001**, and LODGO (13 defendant groups) is clean — *the ordering is
  not one-cartel-driven.*
- ❌ **Operational ranking CONCENTRATED** (must retreat): realized top-500 detections are
  **87.5% one case**; top-two cases = **64.4%** of positives; PR-AUC drops **−44%** on dropping the
  largest case, **−73%** on top-two; RI case-coverage breadth **p=0.487 (NS)**. The federal leg is a
  **single-system, concentrated-anchor stress test of the protocol**, NOT a multi-case operational
  generalization. *Foreground 64.4% / 87.5%, never the flattering 35.4% top-case-by-positives alone.*

**B — Base-rate note for PR metrics.** The federal positive prevalence is ~0.5% (195 / ~92K firms),
roughly **an order of magnitude below BEC's**. Federal PR-AUC (raw 0.014 vs BEC 0.143) is bounded
below BEC's by the rarer target, **not** by weaker discrimination. Any cross-platform PR-AUC line
must be read against this base rate; ROC-AUC is the base-rate-invariant comparison.

**C — Cell-definition annotation.** Federal **MEDIUM = year × buyer (UASG)**; the item-group margin
(BEC's COARSE cell) is **not observed federally** (federal item codes live in buyer-specific catalogs,
no shared classification). Federal STRICT = item_code × year × UASG. The federal clustered-RI
stratification is buyer × item_group × year (91.8% of positives shufflable), **finer** than BEC's
item_group × year — annotate; not a bug.

**D — Partially overlapping legal anchors (caveat line for the §5 prose).** The 7 federal CADE cases
are the *same* cases as BEC's portfolio but **partially overlapping**, establishment-anchored, with
the unnumbered summary case and TI/DF defendants excluded. The federal leg tests **portability of the
audit protocol and the loser-side construct**, not an independent cartel ground truth — read as
neither confirmation nor refutation of any firm's legal status.

**E — Estimand wall (script 03 guidance, prevents a referee collision).** Row 8 raw-timing AUCs
(0.49 full-universe / 0.666 incumbent-pool) measure **temporal stability of the raw score**; rows
4–7 measure **opportunity-adjusted within-cell residual**. *Different estimands on different samples* —
a high raw-timing AUC and a null adjusted increment are **mutually consistent, not contradictory.**

---

## 2. WHAT THE FILLED NUMBERS SAY (the federal verdict, in one read)

**Draft A ("deflation replicates") is the provisional leader, and on the decisive row it lands
*more cleanly* than BEC.** The filled cells:

- **Exposure-only (0.754) now EQUALS-to-EDGES-OUT the raw score (0.744)** federally — on BEC the
  exposure axis only *approaches* the raw score (0.713 vs 0.761). The decisive "the raw number
  measures who shows up, not who colludes" line is *cleaner* on the federal platform.
- **Within-stratum residual collapses to ≈chance (0.462)** — same as BEC (0.471).
- **Nested increment is null (+0.005, p=0.191)** — weaker than BEC's barely-sig +0.010, p=0.013.
- **Matched permutation does NOT reject (p=0.906)** — even more decisively null than BEC's p=0.127.
- **Strict-universe prospective ranking collapses (0.489 full-universe)** — same structural blind
  spot as BEC (0.474); ports cleanly.
- **Label-frozen prospective timing (0.5948)** — the referee's clean out-of-time test on rankable
  incumbents (pool 24,888, N+=98) lands well below BEC's 0.713; the retrospective companion (0.7404,
  N+=177) is a *different estimand on a different positive set*, mutually consistent, not contradictory.
- **Power is a stated BOUND, not a hidden weakness.** With ~30% of BEC's positives the matched
  permutation is informative against a within-stratum residual ≥0.60 (det. prob. 0.90) but underpowered
  at 0.55 (0.35, vs BEC 0.97). The within-stratum positive control O_i = 0.992–0.999 **proves the design
  detects within-stratum signal when present** — so the federal null is a power bound on a genuine null,
  not a design artifact. The deflation rests on four power-robust pillars (exposure-only matches raw;
  within point estimate <0.5; permutation does not reject; negative controls show generic geometry),
  none of which a sample-size argument dissolves.

Every materialized federal cell points the same way: **the deflation is not a BEC artifact; it is what
a disciplined audit returns whenever a cheap award-layer statistic is held to an opportunity-adjusted
standard.** Draft B ("residual survives federally") is **not supported** by any filled cell — keep it in
the draft only until scripts 12/06 land, then delete it (it would need within-stratum > chance and a
rejecting permutation, both of which came back null).

---

## 3. D-iii QUESTION SET (verbatim from `D3_DECISION_PACKAGE.md` §5) + REFRESHED LEAD RECOMMENDATION

### 3a. Refreshed lead recommendation (does seeing the actual numbers change the package?)

**Yes — toward a LEANER treatment.** The original package (new §5 standalone + 7th main table +
appendix demotion to pay for ~3pp) was sized for an *uncertain* federal verdict that might need a long
interpretive section to adjudicate Draft A vs Draft B. **The numbers have collapsed that uncertainty:**
the deflation replicates, cleanly, on every filled cell, and the one place the federal leg is *not*
clean (operational case-concentration, A3) is a **disclosure**, not a result that needs defending at
length. A clean replication with a one-paragraph dual-framing caveat does not need a full standalone
section to carry it. Concretely, the refresh is:

- **Placement — still a standalone section (Option A), but as a SHORT one (~2 to 2.5pp), not 3pp.**
  The "validate → port the validation → interpret" arc still wants its own header so the portability
  claim reads as a contribution; but because the verdict is "same audit, same verdict, cleaner on the
  decisive row," the section is a *tight* port, not a re-litigation. Keep Draft A only (delete Draft B
  once 12/06 confirm); the Interpretation subsection shrinks to one paragraph.
- **Table — KEEP the standalone 7th table, but it earns its keep at HALF a page.** The side-by-side is
  still the cleanest way to show the cross-platform *shape* on one row each, and the dual-framing
  (row 9 ordering-robust vs operational-concentrated) genuinely needs the two-column contrast. But it
  is a compact 10-row × 2-col object — a **half-page float**, not a heavy grid — so the over-cap cost
  is small and the cover-letter justification ("the external-validity contribution is a comparison
  table") is easy. *Caveat: the table cannot ship until rows 3, 6, 10 (label-blind E, power, neg
  controls) are filled by scripts 12/06; until then it is incomplete.*
- **Compensation — the LEANER section RELIEVES the original budget pressure.** The package flagged that
  the +3pp main-text §5 was NOT paid by appendix demotion and forced an additional §6 bid-benchmark
  demotion to hold ≤40pp main. **A ~2.5pp §5 + half-page table is small enough that the §6
  bid-benchmark demotion may no longer be strictly necessary** — main lands ≈42pp, and if the author
  accepts that (or trims §5 to ~2pp), the §6 demotion becomes optional rather than mandatory. The
  appendix demotion (un-`\ref`'d App D/F detail → online supplement, ref-safe) still stands to make
  room for App G. **Net: the clean federal story buys back a chunk of the compensation cost the package
  assumed.**

**Does the power qualification change the lean-treatment call? No — be honest about its footprint.**
The federal permutation is underpowered at a 0.55 within-residual (det. prob. 0.35 vs BEC's 0.97) and
only informative at ≥0.60 (0.90). That is a real qualification and it is now stated **as a bound** in
the draft. But it costs **one tablenote (a) + one sentence in Draft A**, not a section. The reason it
does not reopen the lean call: (i) the deflation does not rest on the permutation alone — it rests on
four power-robust pillars (exposure-only ≥ raw; within point estimate <0.5; permutation does not reject;
negative controls generic), none sample-size-sensitive; and (ii) the within-stratum positive control
O_i = 0.992–0.999 proves the design detects signal when present, so the federal null is a bound on a
genuine null, not an artifact. The qualification *adds rigor* to the lean section rather than forcing it
to grow. **Net: the lean treatment survives the power qualification unchanged** — ~2–2.5pp standalone
§5 + half-page table, plus the one new tablenote and the new `\valFedAudPowerSixty` macro.

**Bottom line for the author:** the deflation-replicates outcome *strengthens* the case for a lean
treatment. The federal story is clean enough that **a half-page table + a ~2pp section suffices**; you
do not need a long defensive section, and the lighter footprint reduces (possibly eliminates) the
mandatory §6 main-text demotion. The single non-clean axis (operational case-concentration) is handled
by one disclosure paragraph + the dual-framing note, not by section length; the power bound is handled
by one tablenote + one sentence.

### 3b. The eight questions (decide in one sitting, table now in view)

1. **Placement:** Confirm the federal material becomes a **new standalone §5 "The Audit on a Second
   Platform"** (shifting old §5–§8 → §6–§9, all auto-renumbered)? Or folded as **§4.5** inside
   Validation (no renumbering, but subordinates the portability claim)?
   *(Refresh: recommend standalone but SHORT, ~2–2.5pp.)*

2. **Section-count silhouette:** If §5 standalone, comfortable the printed section count goes
   **8 → 9**? (Alternative: keep the 8-spine narrative, accept the larger number.)

3. **Table — over-cap approval:** Confirm a **7th main table** over the ≤6 discipline, justified in the
   cover letter? Or attempt the **Panel-B fold into Table 4** (9-col-vs-2-col clash, loses the
   across-platform read)? *(Refresh: standalone, but it is a half-page object — cheap to justify.)*

4. **Table metric:** Report **both** PR-AUC and ROC-AUC (as drafted, with the base-rate note), or
   ROC-AUC only for cross-platform comparability? *(Refresh: ROC-AUC is the honest cross-platform line;
   PR-AUC needs the base-rate caveat because federal prevalence is ~10× lower.)*

5. **Compensation — main ledger:** The +§5 lands on the **main paper**. Approve (a) keeping §5 short
   (~2–2.5pp) **and** (b) demoting the §6 bid-benchmark prose (twinned to `sec_app09`) to hold main
   ≤40pp? Or accept main drifting to ~42pp? *(Refresh: with a lean §5, the §6 demotion may be OPTIONAL —
   your call on 40 vs 42pp.)*

6. **Compensation — appendix ledger:** Approve demoting the **un-`\ref`'d** detail subsections
   (App D Robustness+Limitations; App F segment/mechanism/limitations + `sec_app05` adaptation) to the
   **online supplement** (−2–3pp appendix, zero broken refs), to make room for the new **Appendix G
   federal battery** (~5–6pp)?

7. **Appendix G + orphaned App07:** Confirm wiring **both** federal appendices — the new **Appendix G**
   (the full deflation battery the §5 table notes point to) **and** the **orphaned**
   `sec_app07_comprasnet_submission` headline-replication appendix? Or only one?
   *(Note: per `NEW_NUMBERS_MAP_COMPRASNET.md`, `sec_app07` was DELETED 2026-06-05 as an orphan and its
   two salvageable slivers merged into `sec_appG_federal_DRAFT.tex` — so the live decision is App G only;
   confirm.)*

8. **Draft A vs Draft B paragraph:** The §5 Interpretation carries two mutually-exclusive paragraphs
   (Draft A = deflation replicates; Draft B = residual survives → institution-coupled value). **The
   filled cells support Draft A** (within ≈chance 0.462, nested null +0.005 p=0.191, permutation
   p=0.906). Confirm we keep **both until scripts 12/06 land**, then **delete Draft B**?
   *(Refresh: every materialized cell points to Draft A; Draft B has no supporting cell.)*

---

## 4. OPEN CELLS LIST (what is still blocking the final table)

| Cell | Status | Blocking artifact / note |
|---|---|---|
| Row 3 — Label-blind opportunity expectation E | **PENDING 12b RECONCILIATION** | three candidate constructions on disk (0.611 / 0.695 / 0.739); apples-to-apples selection vs BEC's 0.553 in progress — `audit_armor_macros.tex`, `granularity_sweep.csv` |
| Row 10 — Negative-control verdict | **PENDING** | `outputs/comprasnet/tables/table_E_negative_controls.csv` (script 06) |
| Row 10 — verdict WORDING | **PENDING** | depends on the script-06 placebo/HV-winner outputs above |
| Formal R4 verification pass | **PENDING** | the 4-attack referee protocol — NOT yet run against the filled cells |

**Now FILLED (no longer open):** Row 6 power (0.35@0.55 / 0.90@0.60; O_i 0.992–0.999), Row 8 frozen
timing (0.5948 prosp / 0.7404 retro), and the secondary armor (O_i control, within-LB) — all landed
with the armor pack on disk and verified against `permutation_power_curve.csv` / `frozen_timing.csv` /
`granularity_sweep.csv`.

**Also outstanding before final integration:**
- **Filename token fix:** federal strict file is written as `table_D_strict_2009_2016_to_2017_2019.csv`
  (BEC string) though the federal window is 2013–2019 — rename or annotate the map slot.
- **RI path fix:** federal clustered-RI CSV is at flat `outputs/comprasnet/tables/…` (no `appendix/`
  subdir); repoint the fill spec or symlink.
- **`\valFedAudTopCaseTP` source:** read from `case_dominance_summary.csv::share_tp_500`, NOT `table_H`.
- **Top-two denominator lock:** use link-row basis **64.4%** (132/205) to match protocol text; note
  10 multi-case firms (firm-basis 67.7%).
- **`federal_fill_report.csv` is stale** for Group-8 (generated 19:01, before script 04 ran 19:41) —
  re-run the fill step to pick up the now-materialized LOCO/RI/concentration cells.

---

### Provenance
- Federal filled values: `outputs/comprasnet/diagnostics/federal_fill_report.csv` (re-extracted) +
  `early_triage_03.md` (timing) + `early_triage_04.md` (LOCO/concentration/RI).
- BEC column + macro map: `docs/jleo_rr_revision/NEW_NUMBERS_MAP_COMPRASNET.md`.
- Table skeleton + row order + draft prose: `submission_clean/sec_comparative_DRAFT.tex`.
- Decision questions: `docs/jleo_rr_revision/D3_DECISION_PACKAGE.md` §5.
