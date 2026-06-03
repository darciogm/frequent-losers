# Timing information sets for the frequent-loser screen

**Purpose.** A JLEO referee asks whether the loser-side ranking *works under
honest timing*: can a regulator who froze the score *before* the evaluation
window have ranked the firms that later turn out to be adjudicated cobidders,
**without** peeking at future participation, future wins, a future-tuned
threshold, or future CADE adjudications? This file enumerates the candidate
information sets, states precisely what each can and cannot claim, and labels
which leak future information.

**Hard data constraint — `DAY_LEVEL_TIMING_UNAVAILABLE`.** The CADE files carry
only *judgment* dates (`data_julgamento`, mostly 2015–2025), **no conduct
dates**. We therefore cannot align the screen to the calendar moment a cartel
was operating. All timing below is **year-level** (BEC participation year =
`SUBSTR(numerodaoc,12,4)`), never day-level. Any claim that requires knowing
*when an agency could legally have acted* is out of reach.

**Ground truth.** Positives = 193 adjudicated **cobidders** (`cade_fl_cobidders`,
keyed on `códigofornecedor`; note `firm_cnpj` collapses two empty-CNPJ rows, so
the códigofornecedor key is authoritative and gives 193). Direct CADE
**defendants** = 46 distinct firms (`cade_bec_crossmatch`, keyed on
`firm_cnpj`), after excluding the miscoded firm `09474700000192` ("NEW HOPE")
that appears in *both* files. Defendants and cobidders are disjoint by
construction after that exclusion.

---

## The information sets

| Set | Score input | Zero-win (always-loser) input | Threshold input | Label input | Leaks future? | What it can claim | What it CANNOT claim |
|---|---|---|---|---|---|---|---|
| **A — Full-sample retrospective** | 2009–2019 losses | 2009–2019 wins | full-sample (≈13.5) | 2009–2019 cobidders | **Yes** (everything ex post) | Upper-bound *diagnostic* discrimination of the construct | Any prospective / deployment claim |
| **B — Relaxed temporal holdout** | pre-window (2009–2016) losses | **FULL-period** wins | train-window | cobidders | **Yes** (zero-win status uses future wins) | Sensitivity check only; isolates score-timing while *holding label-of-loser fixed* | That zero-win status was knowable at score date |
| **C — Strict** | train-window losses | train-window wins | **train-window** threshold | cobidders (assigned later) | **No** for score/zero-win/threshold; label is later-adjudicated (see G) | Honest *prospective-score* discrimination of later-adjudicated cobidders | Real-time legal observability |
| **D — Rankable strict** | C, restricted to T_i_train > 0 | C | C | C | No (same as C) | Discrimination *among firms the regulator can actually rank* (had prior losing) | Anything about entrants (T_i_train = 0) |
| **E — Entrant / new-firm** | T_i_train = 0 & T_i_test > 0 | — | — | cobidders | n/a | Documents the *coverage hole*: firms with no training history cannot be ranked by prior losing | That the screen catches new firms |
| **F — Adjudication-observable-at-time** | as C | as C | as C | only labels whose `data_julgamento` ≤ score date | **Largely infeasible** | (in principle) real-time legal knowledge | Infeasible: judgments are 2015–2025, *after* the 2009–2016 score date, so essentially **no** label is observable at freeze time |
| **G — Prospective-score / retrospective-label** | train-window losses | train-window wins | train-window | cobidders adjudicated *later* and back-assigned | **No** in the screening sense (the *realistic* design) | The deployable design: score frozen ex ante, evaluated against labels that history later revealed | "The agency knew the CADE labels at screening date" |

---

## Detailed statements

**A — Full-sample retrospective (upper-bound diagnostic).**
Score, zero-win status, and threshold all computed on 2009–2019; cobidder labels
also 2009–2019. This is the number that appears in the headline construct-validity
tables. It answers "does the construct, with full hindsight, separate cobidders
from non-cobidders?" It is **not** a timing claim and must never be reported as
one.

**B — Relaxed temporal holdout (LEAKS — label as such).**
Score and threshold come from the training window, but *always-loser status* is
computed on the full 2009–2019 record. This leaks future wins: a firm that wins
in 2018 would not be "always-loser" but B treats it correctly only ex post. B is
useful **only** as a sensitivity decomposition (how much of the strict drop is
score-timing vs zero-win-timing). Reported with the leak flagged.

**C — Strict (clean on score, zero-win, threshold).**
Everything that goes into the *ranking* is frozen on 2009–2016: losses, wins
(hence always-loser status), and the median+1.5·IQR threshold (=7, vs the
full-sample 13.5). The only "future" element is that the *labels* were
adjudicated later — which is intrinsic to any screen validated against
eventually-revealed ground truth (see G). C is the honest prospective-score
design. This reproduces script 53's strict pool (n=21,819, npos=193).

**D — Rankable strict.**
C restricted to firms with positive training participation (T_i_train > 0).
Firms with T_i_train = 0 carry score log1p(0)=0 and are unrankable ties at the
bottom; including them inflates the apparent pool and dilutes top-k metrics. D
reports performance *among the firms a regulator could actually order*.

**E — Entrant / new-firm (the coverage hole).**
Firms that did not participate in 2009–2016 but did in 2017–2019. By
construction they have score 0 and cannot be ranked by prior losing. If a
material share of test-window positives are entrants, the prospective screen has
a **structural blind spot**: it cannot flag firms it never saw lose. Reported as
entrant share among positives and among false negatives.

**F — Adjudication-observable-at-time (largely infeasible — document why).**
A truly real-time screen could only use CADE labels whose judgment date precedes
the screening date. With a 2009–2016 freeze and judgments in 2015–2025, almost
no label qualifies (and `DAY_LEVEL_TIMING_UNAVAILABLE` means we cannot even align
within a year). F is therefore **not estimable** here; we document the reason
rather than fabricate a near-empty evaluation.

**G — Prospective-score / retrospective-label (the realistic design).**
Score is frozen ex ante (as C); labels are whatever later adjudication revealed,
back-assigned to the frozen ranking. This is what "validating a screen against
ground truth that history later supplied" means, and it is the design that
supports a *measured* deployment claim — **not** a claim of real-time legal
knowledge. The allowed claim is "a score the agency could have computed in 2016
ranks firms later adjudicated as cobidders above chance"; the forbidden claim is
"the agency would have known the CADE outcome at screening date."

---

## Bottom line for the manuscript

- Report **A** as the diagnostic upper bound, explicitly labeled.
- Lead the timing section on **C/D/G** (strict prospective score, rankable pool,
  retrospective label) — the honest deployable design.
- Report **B** only as a leak-flagged decomposition.
- Report **E** to disclose the entrant coverage hole.
- State that **F** is infeasible given judgment-only dates, and that all timing
  is year-level (`DAY_LEVEL_TIMING_UNAVAILABLE`).
- Never claim real-time detection or ex-ante cartel identification.
