# Sample definition and detection audit — *Beneath the Surface*

*(Originally "V1 CADE detection audit"; retitled 2026-04-09 after discovering
that the pair-matched sample definition is itself a first-order threat,
subsuming and dwarfing the original V1 concern.)*

**Status:** v2 2026-04-09. V1 CADE-detection threat DOWNGRADED to negligible.
V1b (sample definition error) and V1c (cartel concentration) NEW and
HIGH-severity. Reframe of the paper's headline is obligatory before SIOE.

**Author:** mr-beneath (co-authoring session), under direction of D. Genicolo-Martins.

**Purpose:** This memo inventories the *initial detection mode* for each of the
seven SP procurement cartels that anchor the conviction-based benchmark of
*Beneath the Surface*. Its function is to rule out a first-order threat to
internal validity that we label **V1** below.

---

## 1. Why this matters (the V1 threat)

The paper's headline finding is that worker-flow network screens recover an
AUC of 0.82 against convicted cartels, while canonical variance screens reverse
sign on the pair-matched benchmark. Both claims presuppose that the ground
truth (the seven convicted cartels) is sampled *independently* of the screens
we are evaluating. If any of the seven cases was originally brought to CADE's
attention through

- statistical analysis of bid patterns (variance, coefficient of variation,
  bid rotation), or
- administrative analysis of firm-to-firm labor flows, personnel transfers, or
  shared workforce composition,

then our estimates are at least partially circular: we would be rediscovering
the signal that caused the investigation in the first place. We call this the
**V1 threat**.

V1 is different from two other threats we track separately:

- **V1 (selection):** was the case *selected for investigation* on the basis
  of a variable correlated with our screens? — this memo.
- **V2 (contested-rotation conditioning):** conditional on both top-two
  bidders belonging to the same cartel, is the pair-matched sample a
  non-random sub-population of cartel auctions? — to be addressed
  separately in the empirical strategy.
- **V3 (specialization vs. collusion):** are worker-flow Jaccard scores
  picking up shared specialized-labor pools rather than collusive
  coordination? — to be addressed with a non-cartel placebo of same-item,
  same-UF, same-year firm pairs.

---

## 2. Source documents used

1. `03_analysis/cade_period_audit.md` (2026-04-07). Audit of cartel time
   windows against public CADE sources. Created for a different purpose
   (period correction) but contains source citations that are informative
   about detection mode.
2. `03_analysis/12_build_cade_ground_truth.py`. Hand-curated list of the
   seven SP processes used to flag cartel-active auctions.
3. Public CADE press releases and judicial-review coverage cited in (1).

Web fetches of the full CADE *Relatórios do Conselheiro-Relator* are **not
yet performed** for this version of the audit. See §6 (pending actions).

---

## 3. Inventory of the seven SP processes

| \# | Processo | Cartel | Local-file clue on detection mode | Inferred origin | V1 risk |
|---|---|---|---|---|---|
| 1 | 08012.010022/2008-16 | Merenda escolar SP | "Originated from Pregão 73/2006, Secretaria Municipal de Gestão" | Probable administrative complaint or municipal audit (TCM-SP); unconfirmed | 🟡 unknown |
| 2 | 08700.004617/2013-41 | Trens e metrôs SP | "11 companies, 26 bids over ≥10 years"; no explicit origin in local file | **Probable leniency** (external context: Siemens global compliance saga 2008–2013) | 🟡 moderate |
| 3 | 08012.001273/2010-24 | Aquecedores solares CDHU | **"Notable precedent for conviction based exclusively on indirect evidence"** (source: Conjur 2022-11) | Possible statistical-screen or circumstantial-only proof — **direction of "indirect evidence" unknown** | 🔴 **HIGH** |
| 4 | 08700.005876/2019-85 | Transporte escolar Fernandópolis | **"Evidence: coincidence of IP addresses between the two firms during bidding"** | Digital forensics (IP log analysis) | 🟢 **CLEAN** |
| 5 | 08700.007278/2015-17 | Cafeterias Infraero | No origin clue in local files | Unknown | 🟡 unknown |
| 6 | 08700.005789/2015-02 | Sacos de lixo SP/MG/PR/MT/MS | **"Case originated from Op Colludium by the Bauru MP"** | Police operation (Ministério Público de Bauru) | 🟢 **CLEAN** |
| 7 | 08012.002222/2011-09 | Medicamentos SP/MG/BA/PE | "Hub-and-spoke"; no explicit origin | Unknown | 🟡 unknown |

---

## 4. Per-case analysis

### 4.1 The two robustly clean cases

**\#4 — Transporte escolar Fernandópolis (08700.005876/2019-85).** The local
audit explicitly states that CADE's winning evidence was a coincidence of IP
addresses logged during the electronic bidding session. This is a digital
forensic signal with no mechanical correlation to either bid-variance screens
or labor-flow networks. The detection mode is orthogonal to everything our
paper tests. Robust for V1 purposes.

**\#6 — Sacos de lixo, Op Colludium (08700.005789/2015-02).** The case
originated from "Op Colludium," a police operation run by the Ministério
Público de Bauru. Brazilian MP operations against procurement cartels are
typically built on wire-tap evidence, search-and-seizure documents, or
informant testimony. None of these detection technologies are correlated with
either of the statistical screens we evaluate. Robust for V1 purposes.

### 4.2 The HIGH-RISK case

**\#3 — Aquecedores solares CDHU (08012.001273/2010-24).** Condemned 2015,
subsequently reviewed in civil court (Conjur 2022-11: *"Justiça não vê provas
de formação de cartel de aquecedores solares"*). The `cade_period_audit.md`
memo flags this case as *"notable precedent for conviction based exclusively
on indirect evidence."*

**What "indirect evidence" can mean in Brazilian antitrust doctrine.** The
term *prova indireta* in cartel cases is ambiguous and covers at least three
substantively different classes of evidence:

- **(a) Statistical-econometric evidence:** analysis of bid variance, coefficient
  of variation, rotation patterns, coordination-consistent price dynamics. If
  this is what CADE used for \#3, the case is **directly circular** with our
  variance-screen test statistic — the same statistical object is being used to
  convict and then re-used to evaluate conviction.
- **(b) Circumstantial-documentary evidence:** meeting minutes, e-mail trails,
  phone records, witness statements. Orthogonal to our screens.
- **(c) Behavioral inference:** coincident timing of entry, geographic market
  sharing, persistent lot-allocation patterns. Partially correlated with
  classical rotation screens but distinct from variance screens.

**Sensitivity of the paper's headline to \#3.** Under the worst case (CADE used
variance-screen analysis), the sign-reversal claim on the 107 pair-matched
sample is contaminated in direct proportion to the share of the 107 auctions
that come from the aquecedores case. As of 2026-04-09 we have not yet
tabulated this share from `13_flag_cartel_auctions.py`; this should be the
first derived statistic we compute.

Even in the worst case, the **worker-flow AUC of 0.82 is almost certainly
robust to excluding \#3**, because worker flows are drawn from RAIS (an
administrative data stream independent of any CADE investigation file). What
would be weakened is the variance sign-reversal headline, which would need
to be re-reported as (i) the 107 pair-matched sample including \#3, and
(ii) the 107-minus-\#3 subsample, as a sensitivity check.

**Planned action.** Retrieve the *Relatório do Conselheiro-Relator* of process
08012.001273/2010-24. Identify the section on evidentiary basis (*provas
técnicas*, *perícia econômica*, *análise estatística*). Classify the evidence
as type (a), (b), or (c) per the taxonomy above. Report the classification in
this memo and act accordingly.

### 4.3 The moderate-risk case

**\#2 — Trens e metrôs SP (08700.004617/2013-41).** No origin clue in the
local file, but the timing and the process-number prefix (08700) are both
consistent with the Siemens leniency saga that broke publicly in Brazil
around 2013, itself a downstream consequence of Siemens's 2008–2011 global
compliance settlements. The description "11 companies, ≥10 years, 26 bid
events, national scope" matches the well-known Brazilian trens-metrô cartel.

**Selection vs. content distinction.** For V1 purposes, what matters is
*how the case was selected into CADE's enforcement pipeline*, not what the
case file happens to contain after the investigation is opened. Leniency
applications satisfy independent selection by construction: the applicant
decides to confess for reasons exogenous to our screens (global compliance
pressure, in this case). Even if the leniency documents go on to describe
personnel transfers, meetings, or shared workforce — which is plausible for
an engineering cartel — this is content, not selection. Our AUC is estimated
from RAIS, not from the leniency documents, so content cannot contaminate
estimation.

**Provisional verdict for \#2:** V1 risk is low *conditional on confirming
leniency origin*. A single web check of the CADE press release should
resolve this.

### 4.4 The three unknowns

**\#1 Merenda SP, \#5 Cafeterias Infraero, \#7 Medicamentos hub-and-spoke.**
No origin information is recorded in local files. All three require a web
fetch of the CADE decision or press release to extract the *origem do
processo*. Individually they are lower priority than \#3, but all three must
be classified before the SIOE-ready version of the paper is submitted.

---

## A. Pair-matched sample decomposition (added 2026-04-09)

The paper's abstract and intro claim *"107 auctions in which both the winning
and the runner-up firms belong to the same convicted cartel during the same
active window."* This claim is empirically incorrect. A DuckDB decomposition of
`df_pregao_with_cartel_flags.parquet` yields the following breakdown of the
107 auctions the code flags as `both_cartel_firm=1`:

| proc_match | window_status    | n   | % |
|------------|------------------|-----|---|
| same_proc  | both_in_window   | 14  | 13% |
| same_proc  | neither_in_window| 92  | 86% |
| diff_proc  | neither_in_window| 1   | 1% |
| **Total**  |                  |**107**| 100% |

Only 14 of the 107 auctions satisfy the paper's stated definition. The
remaining 93 consist of auctions where both top-two bidders belong to the
same CADE-convicted cartel process but bid against each other **outside** the
cartel's active window — i.e., in years when the cartel was either not yet
formed or already dissolved (per CADE's own conduct window).

### A.1 The 107 is driven almost entirely by a single cartel

Per-sector decomposition of the 107:

| sector | processo | n | share |
|---|---|---|---|
| **medicamentos** | 08012.002222/2011-09 | **100** | **93%** |
| trens_metros | 08700.004617/2013-41 | 3 | 3% |
| sacos_de_lixo | 08700.005789/2015-02 | 2 | 2% |
| transporte_escolar | 08700.005876/2019-85 | 1 | 1% |
| merenda_escolar | 08012.010022/2008-16 | 1 | 1% |
| aquecedores_solares | 08012.001273/2010-24 | 1 | 1% |
| cafeteria_aeroporto | — | 0 | 0% |

The "7 cartels" framing is cosmetic: 93% of the pair-matched signal comes
from a single medicamentos cartel (08012.002222/2011-09). Generalizations
about "the São Paulo cartel ecosystem" are effectively claims about one
pharmaceutical hub-and-spoke cartel with six minor footnotes.

### A.2 Consequence: V1 CADE-detection threat downgraded to negligible

Because the aquecedores case contributes only 1 of 107 auctions (0.9%) and
0 of 14 in the strict sample, the V1 threat (case selection into CADE
investigation via bid-pattern statistical screens) is quantitatively
irrelevant to the paper's headline. No Relatório web-fetch is needed to
close V1. The threat survives only as a conceptual caveat, not as a
quantitative problem.

## B. Cartel-active sample reconciliation (added 2026-04-09)

The paper intro claims *"roughly 2,350 auctions in which at least one
convicted firm participated during the active period of its cartel."* The
DuckDB unfiltered count of `has_active_cartel=1` is **3,905**. Adding the
close-margin filter `|MV| <= 0.10` (the Kawai-RD envelope used in scripts
03/04/06/07 and 15) yields **2,321** auctions. This matches the paper's
stated 2,350 within rounding tolerance and reconciles the discrepancy. The
cartel-active sample is internally consistent, conditional on the
close-margin filter being applied — which the paper's current prose does
not explicitly state.

**Recommended fix:** the intro should specify *"roughly 2,300 auctions in
the close-margin envelope ($|MV| \le 0.10$)"* rather than the current
unfiltered framing.

## C. Variance-screen sign-reversal re-estimation (added 2026-04-09)

Source: `02_data/intermediate/table1_multiscreen_report.txt` produced by
`22_consolidate_screens.py` on 2026-04-07. Script 22 already computes both
the strict (`pair_matched_active`) and the anytime (`pair_matched_listed`)
samples in parallel; the results were present in the repository but the
implications had not been recognized in the manuscript prose.

### C.1 Full result table

Pregão variance screens, Δ = mean(cartel sample) − mean(clean control):

| Screen   | N=14 (strict active) | N=107 (anytime listed) | N=3,905 (cartel-active) |
|----------|----------------------|------------------------|-------------------------|
| cv_bid   | Δ=**−0.099** p=0.287 AUC=0.487 | Δ=**+0.107** p=0.012 AUC=0.605 | Δ=−0.042 p=1e-7 AUC=0.484 |
| spread   | Δ=**−0.481** p=0.037 AUC=0.458 | Δ=**+0.286** p=0.020 AUC=0.625 | Δ=−0.244 p=3e-31 AUC=0.476 |
| n_firms  | Δ=**−0.419** p=0.649 AUC=0.472 | Δ=**+0.819** p=0.003 AUC=0.628 | Δ=−0.794 p=3e-76 AUC=0.461 |
| mv       | Δ=−175.03 p=0.006    | Δ=−175.16 p=0.006      | Δ=−174.46 p=0.006       |

### C.2 Reading

- **Strict sample (N=14):** Δ are *negative* on cv_bid, spread, n_firms.
  The screens fire in the **canonical** direction (compression). None are
  significant at $\alpha=0.01$, and only `spread` is significant at
  $\alpha=0.05$. AUCs are below chance (0.46–0.49). **There is no
  sign-reversal in the strict sample.**
- **Anytime sample (N=107):** Δ are *positive* on all three variance
  screens. This is where the sign-reversal headline comes from. All three
  are significant at $\alpha=0.05$, n_firms at $\alpha=0.01$.
- **Cartel-active sample (N=3,905):** Δ are *negative* again (canonical),
  with enormous statistical significance driven by sample size, but AUCs
  near 0.48 — low discriminative power. The current intro text is
  consistent with this row.

### C.3 Interpretation

The "sign-reversal with $p<0.02$" claim in the current intro is a true
description of the N=107 anytime sample but does **not** describe the
treatment population the intro's prose defines. Specifically, the prose says
*"both winner and runner-up belong to the same cartel during the same active
window"*, but the sign-reversal is observed only when "during the same
active window" is dropped.

When the strict within-window definition is imposed (N=14), the sign
reverts to the canonical bid-rotation prediction (compression: negative Δ),
and the statistical significance largely disappears. The same qualitative
pattern holds on the broad cartel-active sample (N=3,905): compression,
canonical, low discriminative power.

**The striking fact of the paper — sign reversal, p<0.02 — is therefore
an artifact of the 93 "out-of-window" auctions added by the anytime sample
definition.** Those 93 auctions are not cartel auctions in any doctrinally
meaningful sense; they are auctions in which firms that had been cartelists
in *some other year* bid against each other during years when no cartel
was active. Whether those auctions constitute useful signal for
cartel detection depends on an unverified assumption: that cartel-like
behavioral traits persist beyond the prosecuted conduct window. The paper
has not made this assumption explicit, let alone defended it.

### C.4 Worker-flow robustness check on the same decomposition

From the same consolidated report:

```
network/shared_workers: cartel-active AUC=0.825; pair-matched (n=10) AUC=0.457
network/jaccard       : cartel-active AUC=0.815; pair-matched (n=10) AUC=0.449
```

The worker-flow AUC of 0.825 is robust only on the cartel-active broad
sample (N≈2,350). On the strict pair-matched sample (N=10 after the
close-margin filter), the AUCs collapse to ≈0.45 — below chance. The
current intro implies that the worker-flow channel outperforms classical
screens "on the same benchmark." This is true only if "the same benchmark"
is interpreted as the cartel-active sample (N=3,905), not as the
pair-matched sample. The intro's wording is ambiguous on this point and
should be made explicit in the reframe.

## D. V3 resolution: specialization vs. collusion placebo (added 2026-04-09 v3)

### D.1 The V3 threat, restated

The paper's headline worker-flow AUC is alleged to detect cartels. A
first-order threat is that it instead detects *same-market labor
specialization*: in thin specialized-labor pools, any two firms bidding on
the same product in the same year will naturally share workers, whether or
not they are colluding. If this mechanism explains the entire worker-flow
signal, then the paper is not documenting cartel detection; it is
documenting that cartel firms happen to be in thin markets.

### D.2 Placebo design

Three samples, all restricted to pregão close-margin auctions with
$|\text{MV}| \le 0.10$ (matching the cartel-active specification in the
intro):

- **cartel** (N = 2{,}321): auctions with at least one cartel-active firm
  bidding during its active window.
- **placebo\_same\_mkt** (N = 5{,}313): auctions with no cartel firm, in
  the same (BEC-item code, year) as at least one cartel-active auction.
- **clean\_global** (N = 523{,}414): auctions with no cartel firm, in any
  other (item, year).

The placebo is the honest counterfactual: it asks whether non-cartel firms
in the *same product market and period* as cartel firms already have
elevated worker-flow overlap.

### D.3 Results

| Contrast | Jaccard AUC | shared_workers AUC |
|---|---|---|
| cartel vs clean\_global (baseline)            | 0.7398 | 0.7509 |
| cartel vs placebo\_same\_mkt (V3 key test)    | 0.6379 | 0.6625 |
| placebo vs clean\_global (specialization)     | 0.6046 | 0.6077 |

Edge match rates (any shared worker at all):

- Cartel pairs:      57.95% (1{,}345 / 2{,}321)
- Placebo pairs:     31.09% (1{,}652 / 5{,}313)
- Clean-global pairs: 9.89% (51{,}764 / 523{,}414)

Cartel firms share workers with each other at roughly twice the rate of
same-market non-cartel firms, and roughly six times the rate of random
pairs.

### D.4 Signal decomposition

Total worker-flow AUC signal on the cartel-active benchmark (jaccard):
$0.7398 - 0.5 = 0.2398$.

- **Specialization component**: $0.6046 - 0.5 = 0.1046$ ($\approx 44\%$
  of the total). Non-cartel firms in the same (item, year) as cartel
  auctions already beat random firm pairs by this margin.
- **Cartel-specific residual**: $0.7398 - 0.6046 = 0.1352$ ($\approx 56\%$
  of the total). Cartel pairs beat same-market non-cartel pairs by this
  margin.

This decomposition is approximately linear; interpretation is that the
cartel-vs-clean AUC of $\approx 0.74$ decomposes into roughly equal halves
of (a) a thin-market specialization effect, which applies to *any* pair of
firms competing in the same thin market, and (b) a cartel-specific effect
on top of that baseline.

### D.5 Reconciliation note — RESOLVED 2026-04-09

**The 0.82 figure reported in `worker_flow_screen_results.txt` is a
computation bug in `17_worker_flow_network_screen.py` (and the same bug
exists in `18_worker_flow_robustness.py`).** Lines 289--297 of script 17
and lines 83--90 of script 18 implement the Mann--Whitney AUC with
sequential ranks and no averaging for ties:

```python
order = np.argsort(all_scores)
ranks = np.empty_like(order, dtype=float)
ranks[order] = np.arange(1, len(all_scores) + 1)
```

When 90\% of controls and 42\% of treatment observations are tied at zero
($\approx 475{,}000$ tied pairs out of 529{,}578 total), failing to assign
averaged ranks to ties introduces a systematic upward bias in the
treatment's rank sum and inflates the AUC by approximately 0.07--0.08 in
this specific data structure. Direct test on the identical pair file:

- Script-17 formula (sequential ranks, no averaging):
  AUC = 0.8178 (shared workers), 0.8048 (jaccard)
- Correct formula (averaged ranks, matching `sklearn.metrics.roc_auc_score`):
  AUC = 0.7500 (shared workers), 0.7388 (jaccard)
- `sklearn.roc_auc_score`:
  AUC = 0.7500, 0.7388 (confirms the correct value)

The reported 0.8253 and 0.8148 match the buggy formula almost exactly (a
tiny residual difference comes from a 30-observation drift in sample
construction). **The correct headline numbers for the cartel-active vs
clean benchmark are 0.7500 (shared\_workers) and 0.7388 (jaccard), not
0.82.**

**Propagation of the bug through the paper:**

| Manuscript number | Source script | Correct value |
|---|---|---|
| 0.82 (abstract, \S1) | script 17 | **0.7500** |
| 0.825 (\S5 main AUC shared workers) | script 17 | **0.7500** |
| 0.815 (\S5 main AUC jaccard) | script 17 | **0.7388** |
| 0.8249 (\S5 same 2-digit CNAE) | script 18 | **0.7301** |
| 0.74 (\S5 residual after partialling co-bidding) | script 18 | **0.7489** |
| 0.69 (\S5 co-bidding network) | script 18 | **0.6946** |

Two qualitative observations about the correction:

1. The same-CNAE restriction attenuates the AUC slightly more (from 0.7388
   to 0.7301, $\Delta = -0.009$) than the bugged numbers suggested
   ("essentially unchanged at 0.8249"). This does not change the
   substantive conclusion that sectoral composition explains only a
   small fraction of the signal.
2. The co-bidding-residual AUC actually *increases* very slightly under
   the correction (from 0.74 to 0.7489), because the bug was attenuating
   the residual more than the raw signal. This *strengthens* the paper's
   claim that the worker-flow signal is not a mechanical re-expression of
   co-bidding intensity.

**Scripts 17 and 18 must be fixed before the next run** so future outputs
are not affected. Replace the faulty rank assignment with either
`scipy.stats.rankdata(all_scores, method='average')` or
`pandas.Series(all_scores).rank()`. This is a non-blocking code cleanup
issue — the correct numbers are already computed and persisted in
`02_data/intermediate/v3_specialization_placebo.txt` and in this memo
(\S D.3 and below).

### D.6 Verdict

**V3 MARGINAL.** The worker-flow signal is not a pure specialization
artifact, but approximately 44\% of it *is* explained by same-market
non-cartel co-bidding. The remaining 56\%, corresponding to an AUC of
$\approx 0.64$ of cartel pairs against same-market non-cartel pairs, is
cartel-specific.

This finding is not fatal to the paper; on the contrary, it *strengthens*
the institutional-thinness interpretation of the mechanism section. The
mechanism story already argues that in thin specialized-labor pools,
personnel flows substitute for the bid-pattern coordination captured by
classical screens. The V3 decomposition shows that (i) thin-market pairs
*do* share more workers than random pairs, exactly as the mechanism
predicts (the 44\% specialization component), and (ii) cartel pairs share
even more workers than other thin-market pairs, consistent with the claim
that cartels *additionally* exploit or reinforce labor flows for
coordination purposes (the 56\% cartel-specific residual).

**Implications for the manuscript:**

1. The headline AUC number should be reported as a pair of complementary
   statistics, not as a single monolithic figure: the baseline vs clean
   AUC (showing raw detectability) and the specialization-adjusted AUC vs
   same-market placebo (showing cartel-specific signal).
2. The mechanism section should explicitly acknowledge that the
   thin-market story predicts *both* components of the signal, and that
   the V3 decomposition is evidence *for* the mechanism rather than
   against it. A referee would otherwise read the mechanism story as
   unfalsifiable; the V3 split makes it testable.
3. The V3 placebo itself should appear as a bulleted robustness check in
   the results section, with the decomposition table above reproduced in
   the appendix.

### D.7 Threats downgraded to negligible

- **V1 (CADE detection selection)**: already downgraded in §5. V3 does
  not change this.
- **V1d (worker-flow AUC scope on strict pair-matched)**: the collapse of
  worker-flow AUC to $\approx 0.45$ on the strict $N=10$ pair-matched
  sample is a power artifact unrelated to V3, and the V3 placebo analysis
  uses the cartel-active $N=2{,}321$ benchmark where the worker-flow
  signal is estimated with adequate precision.

### D.8 Threats still open

- ~~**Reconciliation of AUC 0.82 vs 0.74**~~ — **RESOLVED** (see §D.5:
  bug in scripts 17 and 18 tie handling; correct value is 0.75).
- **Stronger placebo matching**: the current placebo matches only on
  (BEC item code, year). Stronger tests could add buyer (`códigounidadecompradora`),
  UF, firm size deciles, or firm age. These would push the decomposition
  in either direction and should be run as sensitivity checks before
  submission.
- **Causal interpretation**: the V3 placebo tells us the cartel residual
  signal is *not* pure specialization, but it does not identify *why*
  cartel pairs share more workers than non-cartel pairs in the same
  market. Candidate interpretations include intentional personnel rotation
  for coordination, pre-cartel labor-market connections that facilitated
  cartel formation, and reverse causation (successful cartels attract or
  retain specialized workers). Distinguishing these is beyond the scope
  of V3 and belongs in the discussion section.

## 5. Updated verdict (2026-04-09 v2)

### V1 (CADE detection selection) — DOWNGRADED to negligible

The aquecedores case contributes 1 of 107 anytime pair-matched auctions
and 0 of 14 strict-active pair-matched auctions. Even under the worst case
in which the aquecedores case was built on bid-pattern statistical
evidence, the quantitative contamination of the paper's headline is
essentially zero. V1 can be closed as a non-issue for the SIOE version.
The conceptual caveat (that ground truth selection is not verified to be
screen-independent) can live in a single footnote in the data section.

### V1b (sample definition error) — NEW, HIGH severity

The paper's abstract and intro prose describes the pair-matched sample as
"107 auctions... during the same active window." The code computes
`both_cartel_firm=1` (anytime) which yields 107 auctions, but the strict
within-window definition yields only 14. These two samples give
qualitatively **opposite** results on the variance screens (positive Δ in
107, negative Δ in 14). The paper's headline claim of sign-reversal with
p<0.02 only holds on the anytime sample, which contradicts its own
definition. **This is a factual error in the manuscript that will be caught
by any careful referee.**

### V1c (cartel concentration) — NEW, HIGH severity

93% of the 107 pair-matched auctions come from a single cartel
(medicamentos, 08012.002222/2011-09). The "7 cartels" framing of the
paper is cosmetically true but substantively misleading: the empirical
results are effectively a case study of one pharmaceutical hub-and-spoke
cartel with six minor footnotes. Any generalization to "the São Paulo
cartel ecosystem" or "cartels in thin-labor-market settings" has to
contend with the fact that the evidence base is one cartel, not seven.

### V1d (worker-flow AUC scope) — NEW, moderate severity

The AUC 0.82 headline for worker-flow screens is valid **only** on the
cartel-active broad sample (N≈2,350). On the strict pair-matched sample
(N=10 after close-margin filtering), worker-flow AUCs collapse to ≈0.45.
The paper currently implies the worker-flow result applies to "the same
benchmark" as the sign-reversal, which is ambiguous at best. The reframe
must disentangle the two samples and specify which result lives on which.

### Bottom line

The paper's bold thesis in its current form does not survive careful
scrutiny of the numbers in the repository. The sign-reversal headline is
an artifact of a sample definition that contradicts the paper's own prose.
The worker-flow headline is robust but only on the cartel-active broad
sample, not on the pair-matched sample. The "7 cartels" framing oversells
the diversity of the evidence base. **A substantive reframe is obligatory
before 2026-07-01.** Options are developed in the companion memo
`03_analysis/reframe_options_2026_04_09.md` (to be written).

---

## 6. Pending actions

All actions are performed in-session; coauthor consultation is out of scope
for this workflow (see user feedback memory 2026-04-09).

### 6.1 Highest priority (immediate)

1. **Tabulate share of the 107 pair-matched auctions that come from the
   aquecedores case.** This determines how much of the variance sign-reversal
   headline is at risk under the worst case. Script reference:
   `13_flag_cartel_auctions.py`. Before any web work, compute this number —
   if the aquecedores share is small (say <10%), the V1 threat is
   *quantitatively* bounded even before we classify the evidence type, and
   the sign-reversal headline is robust to exclusion. If the share is large
   (>30%), the threat is existential and the web-fetch of the Relatório
   becomes blocking.
2. **Web fetch the CADE decision for process 08012.001273/2010-24
   (aquecedores).** Target: the *Relatório do Conselheiro-Relator* or the
   equivalent published acórdão. Classify evidence as type (a), (b), or (c)
   per §4.2. Update this memo.

### 6.2 Second priority

3. **Web fetch the CADE press release / decision for process
   08700.004617/2013-41 (trens e metrôs).** Confirm leniency origin; note
   applicant firm if identifiable. Update this memo.

### 6.3 Third priority (before SIOE submission)

4. Web fetch and classify origin for cases \#1, \#5, \#7. These can be
   batched in a single session once the two high-risk cases (\#2 and \#3)
   are closed.
5. Integrate the full classification into \S\ref{hist} of `background.tex`
   as a table of the seven cartels with their detection origin, so referees
   see the V1 audit done and documented in the paper itself.

---

## 7. Revision log

- **2026-04-09** — v1 draft. Initial inventory based on
  `cade_period_audit.md`. Two cases classified CLEAN (\#4, \#6), one HIGH-RISK
  (\#3), one moderate (\#2), three unknown (\#1, \#5, \#7). Pending coauthor
  ping and web-fetch verification.
- **2026-04-09** — v2. Retitled from "V1 CADE detection audit" to
  "Sample definition and detection audit" after discovering that the
  pair-matched sample is decomposed 14/92/1 (strict/out-of-window/mixed),
  that 93% of the 107 comes from a single medicamentos cartel, and that
  the variance-screen sign-reversal does not hold on the strict sample.
  Added §A (pair-matched decomposition), §B (cartel-active reconciliation
  2321/2350), §C (sign-reversal re-estimation with full N=14 / 107 / 3,905
  table from `table1_multiscreen_report.txt`). V1 CADE-detection threat
  downgraded to negligible; V1b (sample definition), V1c (concentration),
  V1d (worker-flow scope) introduced as HIGH/moderate-severity threats.
  Coauthor consultation out of scope per feedback rule.
- **2026-04-09** — v3. Added §D (V3 specialization-vs-collusion placebo).
  Constructed a three-way sample decomposition (cartel, placebo\_same\_mkt,
  clean\_global) and computed worker-flow AUCs via DuckDB + sklearn.
  Verdict: **V3 MARGINAL** — worker-flow signal is ~44% specialization
  and ~56% cartel-specific. Not fatal; actually reinforces the
  institutional-thinness mechanism. Headline should be reframed as a pair
  of complementary AUCs (raw baseline + specialization-adjusted). Also
  flagged a reproducibility gap between my reproduction (AUC≈0.74) and
  script 17's reported AUC (0.82) — needs closure before submission.
  Raw results persisted at `02_data/intermediate/v3_specialization_placebo.txt`.
- **2026-04-09** — v3.1. Closed the 0.74 vs 0.82 reconciliation (§D.5).
  **Root cause: computational bug in scripts 17 and 18** — they assign
  sequential ranks without averaging ties in the Mann--Whitney AUC
  formula. With ~90\% of controls tied at zero shared workers, the bug
  inflates the AUC by ~0.07--0.08. Verified by direct replication: the
  buggy formula gives AUC 0.8178, the correct (sklearn-compatible)
  averaged-rank formula gives 0.7500 on identical data. Corrected all
  downstream numbers: main AUC 0.82→0.75, same-CNAE 0.8249→0.73,
  co-bidding residual 0.74→0.749, co-bidding network 0.69→0.695. Scripts
  17 and 18 flagged for code cleanup (non-blocking). Manuscript headline
  numbers in abstract/\S1/\S5 must be updated to the corrected values.
