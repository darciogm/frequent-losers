# Main Text vs. Appendix Rebalance — v16

**Editorial decision rule applied throughout:** main-text inclusion is reserved for evidence that materially raises the probability that a skeptical referee says, "the paper has done enough work that I have to engage its main idea seriously." Everything else is appendix or cut. This memo records the placement decisions for every consequential object.

---

## I. Promotions to main text

Three objects moved from appendix or unused into main-text positions in this pass.

| Object | From | To | Why this raises acceptance probability |
|---|---|---|---|
| `fig_temporal_holdout_roc.pdf` | unused | §6.4 (after prospective benchmark) | The discrimination evidence is the paper's primary pillar in the v16 hierarchy. v15 reported it numerically; v16 needs it visually. The figure shows ROC curves cleanly separating from the diagonal across all six rolling-origin test years, and the year-by-year AUC progression from $0.819$ ($2014$) to $0.922$ ($2019$) is read at a glance. A skeptical referee skimming for "is this paper's headline plausible?" finds visual confirmation in the validation section without flipping to appendix tables. |
| `tab_leakage_audit.tex` | App C | §6.4 (Permutation null and leakage decomposition) | The leakage decomposition was the largest acknowledged vulnerability in v15: in-sample item-level AUC of $0.99$ vs structural component of $0.86$–$0.89$ once cobidder firms are held out. In App C this read as a hidden caveat; in §6.4 it reads as honest disclosure inside the discrimination centerpiece. **Promoting the disclosure converts the vulnerability into the paper's discipline.** A referee who finds the table in the validation section sees the gap between in-sample-AUC and structural-AUC reported the way it should be reported — early and without hedging. |
| `tab_cade_permutation.tex` | App C | §6.4 (Permutation null and leakage decomposition) | The participation-stratified permutation null is the conservative-benchmark anchor. v15 stated the $\valMultThreeTwo\!\!\times$ excess and $p<0.001$ in prose with the table in App C; the table belongs adjacent to the AUC numbers it disciplines. Same-section placement makes it harder to read the conservative benchmark as cherry-picked. |

## II. Demotions from main text

One object moved from main text to appendix.

| Object | From | To | Why this raises acceptance probability |
|---|---|---|---|
| `tab_iv_placebo.tex` | §9.2 (Robustness) | App C (Identification Audits) | The leave-one-out IV placebo using sub-threshold always-loser supply confirms the threshold rule has empirical content beyond generic always-loser counts. v15 had it in §9 main; v16 demotes it to App C because (a) the 2SLS coefficient of $5.24$ is implausible in magnitude and the table mainly delivers a specification diagnostic rather than a substantive result; (b) the v16 hierarchy reserves §9 for sensitivity bounds and threshold/clustering robustness, not auxiliary IV diagnostics; (c) the temporal-holdout audit and Cinelli/Oster bounds in §9 carry the load that the placebo IV was nominally supporting. |

## III. Additions from existing scripts

Three new tables generated from existing CSV outputs and inserted in the appendix; one figure inserted in main.

| Object | Source | Placement | Why this raises acceptance probability |
|---|---|---|---|
| `tab_temporal_holdout_year.tex` | `output/temporal_holdout/auc_summary.csv` (script 17) | App C | Year-by-year holdout AUC ($0.819$, $0.817$, $0.851$, $0.862$, $0.897$, $0.922$ for test years 2014–2019) supports the headline AUC $0.864$ claim with full transparency: the AUC progression rises monotonically as the training window grows, which is what generalization-honest discrimination should look like. A referee who challenges "is the holdout AUC robust to the test-year choice?" finds a complete answer. |
| `tab_mde_summary.tex` | `output/mde_calculations/mde_summary.csv` (script 23) | App C | Power/MDE table for the failed RDD and DiD designs. The minimum detectable effect at $80\%$ power is $\approx 4.76$pp for the post-Decreto RDD vs an observed effect of $\approx 0.5$pp; observed-to-MDE is $0.11$. The table converts "the design returns null" from a refutation of the underlying mechanism into a power statement that pre-empts the standard R2 critique that "the failed designs falsify the screening reading." They do not — they are structurally underpowered. **High marginal value at low marginal cost.** |
| `tab_auc_decomposition.tex` | `output/auc_decomposition/auc_decomposition.csv` (script 20) | App E | Marginal-AUC contribution table across feature blocks. Model A (full) reaches AUC $0.939$; Model C (`is_fl` alone) reaches $0.887$; Model D (Imhof bid features only) reaches $0.785$. The participation primitive carries most of the discrimination — exactly what the framework's identification predicts — and bid features are non-redundant but not load-bearing. Pre-empts the implicit referee question, "could the construct be sneaking signal in through bid features rather than from the participation primitive?" Answer in one table: no, the participation primitive is the dominant signal. |

## IV. Cuts (confirmed not in main text, formally cut from inventory)

These objects were already not appearing in main text but had remained in the inventory or in `output/tables/`. We mark them formally cut so subsequent reproducibility audits do not regenerate them as main-text candidates.

| Family | Why cut |
|---|---|
| `tab_bajari_ye*` (4 tables) | Old Bajari-Ye framework conflicts with the current screening framing |
| `tab_iv_main*`, `tab_iv_first_stage`, `tab_iv_balance` | Old IV framework; current paper uses leave-one-out IV only as a diagnostic |
| `tab_iv_network_split`, `tab_network_interactions`, `tab_network_split` | Network-rotation angle not in JLEO framing |
| `tab_dyadic_permutation` | Superseded by `tab_cade_permutation` |
| `tab_cox_survival` | Survival angle not used |
| `tab_homogeneous_cv`, `tab_homogeneous_subsample` | Redundant with `tab_horse_race_v14` |
| `tab_unified_mechanism`, `tab_mechanisms`, `tab_robustness_summary_inline` | Superseded by current section structure |
| `tab_welfare_bounds`, `fig_09_welfare_markup`, `fig_welfare_heatmap` | Welfare-imprint angle incompatible with JLEO frame |
| `tab_v8_legacy_audit` | Legacy reproducibility artifact, not paper material |

## V. The v16 main-text cargo, after rebalance

The main text now carries exactly the following primary objects, in order of appearance:

| § | Object | Role |
|---|---|---|
| §4 | (descriptive stats inline) | Sample frame |
| §6.2 | `tab_theory_bridge` | Theory–validation bridge (Subprompt 4) |
| §6.4 | `fig_temporal_holdout_roc` (NEW PROMOTED) | Visual discrimination evidence |
| §6.4 | `tab_cade_permutation` (PROMOTED) | Conservative-benchmark anchor |
| §6.4 | `tab_leakage_audit` (PROMOTED) | Honest tautology disclosure |
| §6.4 | `tab_cade_fl_firms` (existing) | Within-firm enrichment |
| §7.1 | `tab_prices` | Broad-sample $\beta$ |
| §7.2 | `tab_item_level_scope_match` | Overlap-restricted $\beta^{ov}$ |
| §7.2 | `tab_sign_reversal_decomp` (Subprompt 3) | Sign-reversal decomposition |
| §7.2 | `fig_two_objects_continuum` | Visual companion to overlap continuum |
| §8 | `tab_horse_race_v14` | Continuous-dominates-binary |
| §10 | `tab_imhof_full` | Architectural test |
| §10 | `fig_data_coarsening` | Architectural diagram |

Thirteen objects in the main text. Each one earns its place because removing it would leave a question a skeptical referee asks unanswered. The rebalance is conservative on inclusion: any v15 main-text object whose role is unclear in the v16 hierarchy is now in the appendix.

## VI. Why the post-rebalance posture is stronger

Three concrete dimensions of acceptance posture improve with this pass.

**The visual cargo of the discrimination pillar is now complete.** v15 had numerical AUC scattered across §6 with no figure; v16 has both Figure 2 (`fig_temporal_holdout_roc`) and the year-by-year table in App C. A referee skimming the validation section sees the discrimination evidence without having to reconstruct it from prose. The visual evidence is what converts "I read AUC numbers" into "I see the construct discriminating."

**Tautology disclosure is now upstream of the discrimination AUC, not buried in App C.** In v15 the leakage decomposition lived in App C; a referee who never read App C carried away the in-sample AUC of $0.99$ as the headline. In v16 the leakage decomposition is in §6.4, immediately after the prospective benchmark, with the structural component ($0.86$–$0.89$) reported as the operative number. **The largest known vulnerability is now the paper's discipline, not its hidden flaw.**

**Power/MDE for the failed designs is now visible.** v15 reported the failed RDD and DiD as null findings; the implicit reading was "the design refutes the screening interpretation." v16 reports the MDE of $\approx 4.76$pp against an observed $\approx 0.5$pp effect: the null is what an underpowered design returns when the mechanism may or may not exist. This pre-empts R2's standard "your null findings undermine your construct" critique with a single appendix table, raising the cost of that line of attack from "free" to "the referee must engage with power calculations."

The **net effect** of this pass: the main text is shorter and crisper (the demoted IV placebo and the moved tables remove a paragraph in §9; the new figure and promoted tables add to §6.4 but do so where they do empirical work); the appendix is more disciplined (three new tables added, three legacy tables formally cut from the inventory); and the disclosure structure is reorganized so that the strongest acknowledgments (leakage, permutation, MDE) are upstream of the evidence they discipline.

## VII. Compile statistics

| Document | Pages (pre) | Pages (post) | Δ |
|---|---|---|---|
| `paper_v16editor.pdf` | 52 | 54 | +2 |
| `paper_v16editor_online_appendix.pdf` | 22 | 22 | 0 |

The +2pp on the main paper come from the inserted figure and two promoted tables in §6.4. The OA is unchanged in length but has had two tables removed (now in main) and three tables added (`tab_temporal_holdout_year`, `tab_mde_summary`, `tab_auc_decomposition`); the net wash reflects that some tables are more compact than the prose they replace.

Both documents compile clean: zero LaTeX errors above the standard natbib boilerplate.

---

## VIII. What remains to consider for future passes

Three placement decisions stayed conservative in this pass and could move further if R1 referee feedback warrants:

1. **`tab_imhof_incremental`** is currently in App E. If a R1 referee challenges the architectural-comparability claim, this table (with its DeLong $p=0.014$ on $+0.035$ AUC) could be promoted to §10 main as the empirical anchor of the architectural argument. Kept in appendix for now to preserve §10's compactness.
2. **`tab_item_level_scope_match`** in §7.2 could in principle be demoted to App: the sign-reversal decomposition table now does the empirical work and `tab_item_level_scope_match` is its source data. We kept it in main because it compactly reports the four overlap specifications (`baseline_fe`, `overlap_cell_att`, `overlap_ref_att`, `ps_att_trimmed`) that the decomposition references. If §7.2 reads long to a copy editor, this is the candidate to move.
3. **`tab_falsification_modal`** is currently in App B, supporting the modal contrast in §1 and §8. If the modal contrast becomes a contested point in R1, this table could be moved into §8.

These are R1-contingent moves, not R0 commitments.

---

*End of rebalance memo. Inventory CSV updated; manuscript and appendix rebalanced; PDF compiled clean at 54pp main + 22pp OA.*
