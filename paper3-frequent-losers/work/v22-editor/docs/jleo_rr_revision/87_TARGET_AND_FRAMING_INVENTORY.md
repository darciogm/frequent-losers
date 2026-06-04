# 87 — TARGET AND FRAMING INVENTORY (JLEO final optimization)

**Date:** 2026-06-04 · Compiled from 3 parallel inventory agents (manuscript LaTeX, analysis
scripts, prior audit docs). Full agent outputs in session transcript; this file records the
decision-relevant locations.

---

## 1. The fatal archived-target language (must be removed/rewritten — Step 6)

| File | Line(s) | Content |
|---|---|---|
| `sec04_validation_submission.tex` | 51–55 | "The main validation target is the $\valCobidders$ … We disclose one replication caveat … that target's original builder is archived and is not [reproduced]" |
| `sec04_validation_submission.tex` | 84–97 | Table rows "Main target — static narrow … primary"; "(narrow cartel-tender definition) has an archived builder" |
| `sec_app02_data_labels_submission.tex` | 95–98, 113–114, 150–154, 164–170, 180–181 | "(\texttt{cade\_fl\_cobidders.csv}, frequent-loser only, narrow cartel-tender restriction); its original builder is archived and is not reproduced by the current scripts, which is the one replication [caveat]" + "the $210$/$108$ figures in earlier drafts" |
| `sec02_setting_layers_submission.tex` | 162, 204 | "$\valCobidders$ always-loser cobidders" (main target citation) |

## 2. Macros holding target counts (values.tex + inline preamble)

| Macro | Value | Status under repair |
|---|---|---|
| `\valCobidders` | 193 | REBIND → 651 (broad AL main) or replace by `\valMainCobidders` |
| `\valArchNPos` (preamble paper_*.tex:146) | 193 | regenerate from new pipeline |
| `\valFunnelStaticTarget` | 193 | internal-only; remove from submitted prose |
| `\valBidPosRetained` | 193 | regenerate (Target F) |
| `\valExpNpos` / `\valProfCob` | 191 | regenerate (exposed positives under new label) |
| `\valCostNpos` | 190 | regenerate (Target F in cost pool) |
| `\valConservativeCobidders` / `\valFunnelConsALcob` | 208 | keep (already broad-def AL, same def as new main — now definition-consistent) |
| `\valConservativeFL` / `\valFunnelConsFLcob` | 107 | demote to composition descriptive |
| `\valConservativeFD` / `\valFunnelConsFD` | 19 | keep |
| `\valFunnelALcobBroad` | 651 | PROMOTE to main target count |
| `\valFunnelFLcobBroad` | 341 | composition descriptive (FL share of positives) |
| `\valArchTPThouSeqK` / `\valGateSeqKTwoKOneTPIn` | 131 | regenerate (cost-recall under new label) |

## 3. Framing terms flagged (Steps 9–15)

- "legal membership anchors": `sec01:63`, `sec02:151` → replace with "legal anchors" / "adjudicated defendants".
- "operationally useful": `sec01:92` → replace with disciplined incumbent-triage phrasing.
- "cartel adjacency": `sec_app02:129` → replace with "adjudication-anchored exposure".
- "deployable screen": `sec06:90`; "the deployable FL-binary score": `sec_app03:321` → discipline.
- "dominates for every agency": `sec_app06:215`; "classifier dominates": `sec_app07:340` → soften where about our results (contextual "dominated by two modalities" sec02:69 is fine).
- Imhof–Wallimann benchmark language: present, mostly disciplined; verify "inspired by"-style qualifier in §6.
- Negated/boundary uses of damages/overcharge/proof: present and GOOD (keep one per section, cut repeats).
- Subprompt headers in `values.tex` comments (1148, 1184, 1205, 1375, 1388, 1411, 1433, 1455, 1478) — internal comments, not rendered; acceptable but clean if convenient.
- Hygiene: no TODO/FIXME/Claude in compiled text; "Appendix Appendix" not found; "blocked" usages are intentional boundary statements.

## 4. Script label-consumption map (agent 2, full table in transcript)

ALL downstream analysis scripts read the static `cade_fl_cobidders.csv` as the positive label:
`02` (opportunity-adjusted; emits `firm_opportunity_adjusted_frame.csv` consumed by `05`/`06`),
`03` (timing), `04` (case holdout/LOCO), `05`/`06` (profile/robustness via frame),
`07` (bid-feature audit counts), `08`/`09` (bid RF benchmark), `10` (cost-recall frontier),
`11` (survival appendix). Universe everywhere = 16,843 always-losers; defendants excluded;
FL14 enters only as score/stratum. **Switching the label = switching the cobidder source in
each script (one-line edit) + re-run in dependency order 02 → {03,04,11} → {05,06} → 07 → {08,09} → 10.**

## 5. Prior-audit verdicts bearing on this repair (agent 3)

- B3 (absent builder) OPEN for replication package; mitigated in-manuscript by disclosure — the exact disclosure this prompt orders removed-and-replaced by a reproducible target.
- U2 user decision (2026-06-02) was "(c) DISCLOSE + ROBUSTNESS — keep 193 primary". **This prompt supersedes U2**: the disclosure path is judged fatal by hostile-referee standard; decision rule Case 2 applies.
- The static 193 file is FL-only (all rows `is_FL=True`) → validating FL14 against it is label-conditioning-on-the-screen. This is the circularity being eliminated; the earlier "no circularity" assessments only checked that *current* scripts don't use FL in the label formula, not that the archived builder didn't condition on FL (it did).
- GO_WITH_MINOR_REPAIRS (doc 68/71) predates this repair; verdict must be re-issued after regeneration (doc 91).
- No doc 84 exists; highest prior doc = 71 + named memos.
