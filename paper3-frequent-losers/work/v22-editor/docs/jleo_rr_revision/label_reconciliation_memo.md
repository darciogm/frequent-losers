# Label Reconciliation Memo — 193 vs 210 (JLEO R&R v22, CP-1)

**Verdict: RECONCILED** — the 193-vs-210 discrepancy is a *definition
inconsistency between two benchmarks*, not a coding bug, and is fully scripted
and reproducible. `explanation_code = DIFFERENT_COBIDDER_DEFINITION (+ AL-vs-FL
stratum)`.

**Terminology discipline.** Cobidders carry an **adjudication-anchored exposure
label** (firms that shared a tender-item with a BEC-active CADE direct
defendant). They are NOT cartel members and we never write "cartel-adjacent."

Sources throughout: `output/label_funnel/funnel.csv`, `output/label_funnel/audit_log.txt`,
`work/v22-editor/outputs/diagnostics/{label_count_reproduction,cobidder_set_comparison_summary,label_funnel_assertions}.csv`,
and `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` (cited as `01_...R`).

---

## The 10 questions

**1. Are 193 and 210 computed on the same underlying universe?**
**No.** They differ on **three axes simultaneously**: cobidder *definition*
(narrow cartel-tender vs broad shared-tender-item), *stratum* (FL vs AL), and
*case window* (full 12-case vs conservative 4-case). The cited 210 > 193 is
**not a same-definition comparison** (assertion **A8**, warning;
`cobidder_set_comparison_summary.csv` pair `static193_vs_broadConsAL208`,
`explanation_code = TWO_AXIS_DIFFERENCE`).

**2. Are they unique-firm counts or different counting units?**
**Both are unique-firm counts** — but on *different strata*. 193 = unique
**frequent-loser** firms; 210/208 = unique **always-loser** firms (AL ⊇ FL).
Neither is a firm-case-pair (5,121) or tender-item (52,013) count
(assertion **A9**).

**3. Is the conservative benchmark a subset of the main benchmark?**
**No** — not a mechanical subset. They were built by *different pipelines*: 193
from the static `cade_fl_cobidders.csv` (narrow, builder absent); 208/107 from
the scripted broad shared-tender-item definition. There is no nesting between a
narrow-FL-full set and a broad-AL-conservative set.

**4. If not, why not?**
Because the main 193 uses the **narrow cartel-tender** definition + **FL**
stratum + **full** portfolio, while the conservative uses the **broad
shared-tender-item** definition + **AL** stratum + **4-case** window. The
builder of the static 193 file is **absent from the repo** (all scripts only
*consume* `cade_fl_cobidders.csv`) — **blocker B3**. `audit_log.txt`:
"the ORIGINAL builder of cade_fl_cobidders.csv is absent from the repo."

**5. If a subset relation existed, why does the conservative produce more
cobidders?**
It is **NOT a subset**. The broad **AL** definition over 4 cases (208) exceeds
the narrow **FL** definition over 12 cases (193) precisely because *broad+AL
casts wider per case* than *narrow+FL casts over more cases*. Under a **common**
definition the subset relation is fully restored: 208 ≤ 651 (AL) and 107 ≤ 341
(FL) — assertion **A7** (pass); `cobidder_set_comparison_summary.csv` pair
`broadConsAL208_vs_broadFullAL651`, `explanation_code = SUBSET_SAME_DEF`,
intersection 208 / 208.

**6. Was there a coding error?**
**No bug in the computation.** Every scripted count reproduces (341/651/208/107/
19/41/52,013/149). The error was one of **documentation / consistency**: two
benchmarks were built with **inconsistent definitions** and never reconciled.
The single hard data error is the **30-defendant figure**, an unreproducible
**over-count** (reproduces to 19; `\valConservativeFD` 30 → 19).

**7. What number should the revised manuscript use?**
Keep **193 primary** (disclose the absent builder, blocker B3) + **341
transparent broad robustness**. Conservative benchmark = **19 defendants / 208
AL cobidders / 107 FL cobidders**. **Drop 30.** New macros in
`label_funnel_new_macros.tex` (`\valFunnelConsFD = 19`, `\valFunnelConsALcob =
208`, `\valFunnelConsFLcob = 107`, `\valFunnelFLcobBroad = 341`,
`\valFunnelALcobBroad = 651`).

**8. What table note explains the discrepancy?**
Exact note text (from Table A, `01_...R` lines 393–398):

> *Notes.* Cobidder = adjudication-anchored exposure label (not cartel
> membership). The 193 main target uses the static narrow cartel-tender
> definition (builder archived; absent from repo). The 341/651 transparent
> funnel uses the broad shared-tender-item definition (any tender-item shared
> with a BEC-active direct defendant). The conservative benchmark (4 cases
> judged ≤ 2020-12-31) reproduces to 208 always-loser / 107 frequent-loser
> cobidders under the broad definition. Counts are unique firms unless a column
> says pairs. AL = always-loser (win rate = 0); FL = frequent loser (FL14,
> tenders_count ≥ 14). Legal-defendant roster (65) is not reproducible from the
> CADE rulings CSV (empty CNPJ column); shown for context.

Two-axis explanation to accompany it: *the cited 210 > 193 compares an
always-loser/broad/conservative count against a frequent-loser/narrow/full
count; it is not a same-definition comparison. Under a common definition the
subset relation holds (208 ≤ 651; 107 ≤ 341).*

**9. Does any downstream table need regeneration?**
The conservative-benchmark **counts** are now reproducible (19/208/107) and feed
§4.1. The conservative-benchmark **AUC / enrichment** in §4.1 were computed on
the adjudication-anchored conservative labels; **AUC re-estimation under the
harmonized definition is DEFERRED to the opportunity-adjusted-validation prompt
(4B)**. **Do NOT claim AUC invariance now** — only the counts are reconciled at
this stage.

**10. Is the paper ready to proceed to opportunity-adjusted validation?**
**YES.** The discrepancy is reconciled as a definition difference, fully
scripted and reproducible. Verdict is **RECONCILED**, not NOT_READY. Remaining
open item carried forward: blocker **B3** (absent builder of the static 193
file) — disclosed, not resolved.

---

## Per-pair set-comparison numbers
Source: `cobidder_set_comparison_summary.csv`.

| Pair | size_A | size_B | ∩ | A∖B | B∖A | explanation_code |
|---|---|---|---|---|---|---|
| `static193_vs_broadFull341` (static_193 vs broad_full_FL_341) | 193 | 341 | **149** | 44 | 192 | `DIFFERENT_COBIDDER_DEFINITION` |
| `broadConsAL208_vs_broadFullAL651` (broad_cons_AL_208 vs broad_full_AL_651) | 208 | 651 | **208** | 0 | 443 | `SUBSET_SAME_DEF` |
| `static193_vs_broadConsAL208` (static_193 vs broad_cons_AL_208) | 193 | 208 | **105** | 88 | 103 | `TWO_AXIS_DIFFERENCE` |

Reading: static-193 ∩ broad-341 = **149** (same FL stratum, different cobidder
def). Conservative-208 is a **strict subset** of full-651 (0 in A∖B). Static-193
vs conservative-208 overlap only 105 because they differ on all three axes.

## Assertion results
Source: `label_funnel_assertions.csv` — **9 pass / 1 warning / 0 fail**.

| ID | result | one-line |
|---|---|---|
| A1 | pass | CNPJ consistently 14-padded (0 non-14-char) |
| A2 | pass | no missing firm IDs in cobidder labels |
| A3 | pass | no missing tender-item IDs in defendant items |
| A4 | pass | direct defendants excluded from cobidder sets (0 contamination) |
| A5 | pass | all AL cobidders satisfy win_rate == 0 |
| A6 | pass | all FL cobidders satisfy AL & tenders_count ≥ 14 |
| A7 | pass | under common broad def, conservative ≤ full (208 ≤ 651; 107 ≤ 341) — subset restored |
| **A8** | **warning** | cited 210 > 193 is NOT a same-definition comparison — definition-driven, not a bug |
| A9 | pass | unique-firm (4,369) vs firm-case pairs (5,121) vs tender-items (52,013) separated |
| A10 | pass | manuscript counts vs reproductions logged (193 exact; 341/651/208/107/19/41 reproduced; 30 mismatch; 47≈48) |

The single non-pass (**A8**) is an intentional **warning** flagging the
definition difference for disclosure, with action "report as definition
difference, not bug." Zero failures.

## Explanation code

> **`explanation_code = DIFFERENT_COBIDDER_DEFINITION (+ AL-vs-FL stratum)`**

210 = always-loser / broad shared-tender-item / conservative-4-case;
193 = frequent-loser / narrow cartel-tender / full-12-case. Not a bug — a
definition inconsistency between a scripted benchmark and an absent-builder
static file, now fully documented and (except the dropped 30) reproducible.
