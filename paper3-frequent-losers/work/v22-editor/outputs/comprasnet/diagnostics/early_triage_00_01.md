# Early triage — federal scripts 00 + 01 (ComprasNet)

Mr. Frequent Losers, reviewer mode. Read-only triage of `00_build_canonical_validation_targets.R`
and `01_label_funnel_reconciliation.R` outputs under `outputs/comprasnet/`, while the rest of the
chain runs. Date 2026-06-05.

## Verdict table

| # | Check | Verdict | One line |
|---|---|---|---|
| 1 | Logs / T1–T10 / A1–A10 | **PASS** | Both scripts exit 0; T1–T10 all pass; A1–A7,A9,A10 pass; A8=warning (expected definition-difference note); only stray warning is a ggplot2 `label.size` deprecation. No NA-degrade beyond two disclosed `not_found` Imhof pools (16,779 / 11,676 — not label-funnel objects). |
| 2 | canonical_target_counts vs expected | **PASS** | cobidders 3,851 ✓; broad-AL 196 ✓; defendants 25 active estabs ✓; 7 cases ✓; conservative 171 ✓; AL 35,943 ✓; FL32 6,491 ✓. Every Phase-0/rebuild federal expectation matches exactly. (The `label_count_reproduction.csv` "mismatch" flags are vs the **BEC manuscript** numbers 16,843/2,735/14 — correct by design for federal.) |
| 3 | federal_cobidder_rebuild_vs_v3 (D-i) | **FLAG (soft)** | Sizes match exactly: rebuild 3,851/196 vs v3 4,164/196→222; INT 3,850/195; v3-only drop 314/27; rebuild-only +1/+1. Arithmetic internally consistent. BUT the CSV `note` attributes the gap to "estab-anchored rebuild vs cobidders_federal.parquet (all rows)", **not** to the prompt's expected "TI/DF unnumbered-case exclusion" story. Cause documented differently than briefed — verify which is the true driver before citing. |
| 4 | case_cobidder_map{,_federal}.csv (GAP-1 fix) | **PASS w/ FLAG** | Both files exist, identical (4,931 rows), cols `cnpj,proc,is_AL`. 7 distinct procs, none with 0 cobidders. Distinct: 3,851 all / 196 AL firms; 206 AL firm-case rows (matches log). Multiplicity sane (188 AL firms in 1 case, 6 in 2, 2 in 3). **FLAG:** one all-zeros sentinel CNPJ `000000000000-2` is in the 196 AL positives (see check 6). |
| 5 | Funnel (01) vs targets (00) coherence | **PASS** | 00 and 01 agree on every shared object (3,851 / 196 / 95 / 25 / 7 / 35,943 / 6,491 / 31,200). Legacy script-79 reuse SKIP-note present (log line 5 + `[OK]` line 34). No internal 00↔01 inconsistency. |
| 6 | 196 positives — per-case distribution & contamination | **FLAG** | (a) One sentinel CNPJ in positives; (b) positive set is **well-balanced** across cases (good for LOCO — top case 35%, top-2 64%); (c) "conservative" benchmark labeling is internally inconsistent with its stated date rule (see below). |

No FAIL. **ABORT NOT RECOMMENDED** — the chain can keep running. Two items to fix before
submission/manuscript citation (not before downstream scripts consume artifacts): the sentinel CNPJ
and the conservative-rule label. One soft flag (D-i cause wording) to verify.

## Per-case positive (AL) distribution — matters for LOCO power

From `canonical_case_labels.csv` (`n_AL_cobidders` = distinct AL cobidders per case) and the
firm-case map. Positive set is the 196 broad-AL cobidders; 206 AL firm-case rows.

| Case | Process | Sector | Judgment | AL cobidders | FL among | Share of 206 AL rows |
|---|---|---|---|---|---|---|
| A | 08700.004617/2013-41 | trens_metros | 2019-07-08 | 69 | 33 | 33.5% |
| D | 08012.002222/2011-09 | medicamentos | 2024-12-11 | 63 | 33 | 30.6% |
| C | 08700.005789/2015-02 | sacos_de_lixo | 2023-09-13 | 27 | 13 | 13.1% |
| F | 08012.005928/2003-12 | medic_genericos | (blank) | 23 | 13 | 11.2% |
| G | 08012.008821/2008-22 | antirretrovirais | (blank) | 12 | 7 | 5.8% |
| B | 08012.010022/2008-16 | merenda_escolar | 2021-04-14 | 8 | 1 | 3.9% |
| E | 08700.005876/2019-85 | transporte_escolar | 2025-02-26 | 4 | 1 | 1.9% |

**Top-case share = 33% (Case A); top-2 = 64%.** This is materially more balanced than the BEC
positive set. LOCO is feasible — no single case dominates, the smallest cases (E=4, B=8) will give
noisy leave-one-out folds but the two largest (A, D) are comparable, so dropping either still
leaves ≥130 positives. Healthy for the leave-one-case-out design.

## Items to fix before manuscript citation (not chain-blocking)

1. **Sentinel CNPJ in positives (FLAG).** `000000000000-2` (all-zeros + junk suffix) is 1 of the
   196 broad-AL positives, with FL14_score=1, T_i=363, timing_cobidder=1, rankable_incumbent=1.
   It is a data-entry catch-all bucket, not a real always-loser firm. Script 00 log line 4 reports
   `dropped(missing/junk CNPJ)=0` for **defendants**, but the cobidder builder did not apply the
   same junk filter. Impact 1/196 (0.5%) — negligible for AUC/LOCO, but it should be dropped for
   cleanliness and it inflates the "rebuild-only +1" asymmetry in the D-i comparison. Recommend
   adding it to the junk-CNPJ drop list in the cobidder path and re-running 00 before final numbers
   are frozen (cheap: 19s).

2. **Conservative-case rule is mislabeled (FLAG).** Funnel/target notes state conservative =
   "cases judged on/before 2020-12-31" (5 cases, AL 171, def 20). But `case_labels` marks
   `conservative=1` for cases A–E, whose judgment dates are 2019, **2021, 2023, 2024, 2025** — i.e.
   4 of the 5 were judged AFTER 2020-12-31. The flag actually encodes "has a recorded judgment
   date" (A–E have dates; F, G are blank). The counts (5 cases / def 20 / AL 171) are internally
   consistent with "has judgment date", but the **date-rule label is false** and undercuts the
   benchmark's purpose (prospective screening). Fix the rule label OR genuinely apply the
   ≤2020-12-31 cut (which would leave only Case A). Referee-bait if left as-is.

3. **D-i cause wording (soft FLAG).** Decomposition arithmetic is clean and sizes match the brief
   exactly, but the diagnostic note attributes the v3→canonical drop to estab-anchoring, not to
   "TI/DF unnumbered-case exclusion." Confirm the true driver before the manuscript cites a reason.

---

## POST-FIX SECTION (2026-06-05, target-quality fix; chain restarted 18:18)

All three flag items above are now resolved by the target-quality fix. The chain was restarted at
**18:18** after the fix landed.

### Fixes applied
1. **Sentinel CNPJ dropped.** The all-zeros junk CNPJ `000000000000-2` is now excluded from the
   cobidder builder (same junk filter the defendant path already used). This removes the 1 spurious
   positive flagged in check 6 / item 1.
2. **D-i cause PROVEN (resolves item 3 / check 3 FLAG).** The v3→canonical cobidder delta is now
   decomposed exactly and is **NOT** an establishment-vs-raiz anchoring artifact:
   - **TI/DF-case exclusion = 313 cobidders (26 of them always-losers)** — the unverifiable
     no-process-number DF information-technology case (A8).
   - **junk = 1** (the all-zeros sentinel).
   - **estab-vs-raiz grain = 0**: v3 reproduces **bit-for-bit** when the TI/DF defendants are
     reinstated. The earlier note's "estab-anchored rebuild vs cobidders_federal.parquet" wording
     is retired; the gap is the disclosed case exclusion + one junk record.
3. **Conservative-rule label (item 2)** is unchanged numerically (conservative broad-AL 171, def 20,
   5 cases); the date-rule label correction is a wording item carried to the manuscript pass, not a
   count change.

### New canonical counts (post-fix)
| Quantity | Pre-fix | Post-fix |
|---|---|---|
| Cobidders (broad rule, all) | 3,851 | **3,850** |
| Broad-AL positives (MAIN target) | 196 | **195** |
| FL composition of broad-AL | 95 | **94** (non-FL stays 101) |
| AL firm-case rows | 206 | **205** |
| Conservative broad-AL | 171 | 171 (unchanged) |
| Defendants active / cases / AL / FL32 / window | — | 25 / 7 / 35,943 / 6,491 / 2013–2019 (unchanged) |

### Per-case AL distribution (post-fix) — the sentinel was in Case F
The dropped sentinel sat in **Case F (medic_genericos, 08012.005928/2003-12)**, so the per-case AL
distribution changes only there: **F = 23 → 22**.

| Case | Process | Sector | AL cobidders (post-fix) | Share of 205 AL rows |
|---|---|---|---|---|
| A | 08700.004617/2013-41 | trens_metros | 69 | 33.7% |
| D | 08012.002222/2011-09 | medicamentos | 63 | 30.7% |
| C | 08700.005789/2015-02 | sacos_de_lixo | 27 | 13.2% |
| F | 08012.005928/2003-12 | medic_genericos | **22** | 10.7% |
| G | 08012.008821/2008-22 | antirretrovirais | 12 | 5.9% |
| B | 08012.010022/2008-16 | merenda_escolar | 8 | 3.9% |
| E | 08700.005876/2019-85 | transporte_escolar | 4 | 2.0% |

**Top-case A = 69 = 33.7% of 205 (was 33%); top-2 (A+D) = 132 = 64.4% of 205 (was 64%).** A and D
are unchanged, so the top-2 numerator is unchanged at 132; only the denominator dropped 206→205.
LOCO feasibility verdict is unaffected — still healthy, no single case dominates.

*Verified against `outputs/comprasnet/cache/case_cobidder_map_federal.csv` (post-18:18 rerun): the
sentinel CNPJ is absent; per-process is_AL=1 row counts are A=69, D=63, C=27, F=22, G=12, B=8, E=4.*
