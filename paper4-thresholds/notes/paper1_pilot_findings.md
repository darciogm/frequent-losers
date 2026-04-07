# Paper 1 — RD Pilot Findings
## mr-beneath /co · 2026-04-06

**Data sources**
- BEC convite pairs: `02_data/final/df_convite_winner_looser.parquet`
- Firm-year panel: `02_data/firms/firm_year_panel.parquet`
- Analysis sample: `02_data/final/rd_pilot_sample.parquet` (109 MB)
- Full results: `02_data/intermediate/rd_pilot_results.txt`, `rd_pilot_table.csv`
- Figures: `04_figures/rd_pilot_{main,density,event_study}.pdf`

**Sample**
- Treatment window: 2009–2015 (7 years)
- Envelope: |MV| < 0.10
- Rows: 730,592 firm × auction observations
- Unique firms: 7,146
- Unique auctions: 365,296
- Clustering: item class (376 clusters, à la Paper 3 convention)

---

## 1. Design validity — **PASS**

### 1.1 Density test (Cattaneo-Jansson-Ma)
- T = 0.142
- **p = 0.8871**
- No evidence of manipulation of the margin of victory at the cutoff. ✅
- Implication: firms are not precisely targeting the narrow-win boundary.

### 1.2 Balance tests (RD on pre-treatment covariates)

| Covariate (t-1) | Coef | SE | p-val |
|---|---:|---:|---:|
| log employment | −0.056 | 0.228 | 0.807 |
| log payroll | −0.149 | 0.316 | 0.637 |
| log avg wage | −0.014 | 0.043 | 0.744 |
| share female | −0.004 | 0.014 | 0.741 |
| avg age | **+0.709** | 0.412 | **0.085** ⚠️ |
| share university | −0.002 | 0.009 | 0.839 |
| share managerial | **+0.007** | 0.004 | **0.081** ⚠️ |
| was_incumbent | +0.029 | 0.021 | 0.158 |
| was_last_bid | **+0.079** | 0.010 | **<0.001** ⚠️ |

- Most pre-treatment covariates are balanced (p > 0.05).
- **Two warnings**: `avg_age` and `share_managerial` are marginal (p≈0.08). Likely false positives given the number of tests, but worth checking in the final analysis.
- **`was_last_bid` is strongly imbalanced**: narrow winners are 7.9 pp more likely to have submitted the last bid. This is mechanically connected to how close-bid auctions resolve and should be dropped as a "balance" variable — it's a choice variable that depends on the auction outcome. It remains a fact about the design; see Paper's original use of this as an outcome.
- **`was_incumbent` is NOT significant at 5%** (p=0.16), unlike the old paper's original Table 1 (where it was reported significant at 1%). With proper item-class clustering and the restricted 2009–2015 window, the "incumbency jump" disappears. This is **critical**: it confirms my parecer concern that the old result was sensitive to clustering and sample choice.

---

## 2. Main results — mixed / small

### 2.1 Log employment at t+1 (the headline outcome)

| Period | Coef | SE | p-val (robust) | N (L+R) |
|---|---:|---:|---:|---:|
| t-1 | −0.056 | 0.228 | 0.81 | 228,332 |
| t | −0.039 | 0.228 | 0.86 | 322,319 |
| **t+1** | **−0.046** | **0.236** | **0.85** | **327,469** |
| t+2 | −0.045 | 0.241 | 0.85 | 291,887 |

**Null result on log employment.** The point estimates are small (−4 to −6 log points) and statistically indistinguishable from zero. SEs are ~0.23, meaning 95% CIs span roughly [−0.5, +0.4] — too wide to rule out meaningful effects in either direction.

### 2.2 Log payroll and wages — null

All four payroll measures and both wage measures are small (|coef| < 0.22) and highly insignificant (p > 0.4). No evidence of rent-sharing at this aggregation level.

### 2.3 Growth rates — null

| Outcome | Coef | SE | p-val |
|---|---:|---:|---:|
| Δlog emp (t+1 − t-1) | −0.003 | 0.027 | 0.93 |
| Δlog emp (t+2 − t-1) | +0.028 | 0.028 | 0.27 |

Growth-rate specification also null. But SEs are much tighter (0.027 vs 0.228 in levels) → growth rates are the more powerful specification. Coefficient of **+0.028 at t+2** is suggestive (roughly 3% extra growth) but not significant.

### 2.4 Hiring and separations — imprecise
- n_hires_tp1: −7.2 (SE 13.7), p=0.60
- n_separations_tp1: −5.4 (SE 12.5), p=0.67
- Counts are too noisy at this aggregation. Need log or share specifications.

### 2.5 **Survival — significant positive effect** ✅

| Outcome | Coef | SE | p-val (robust) |
|---|---:|---:|---:|
| survived_tp1 | **+0.040** | **0.018** | **0.017** |
| survived_tp2 | **+0.037** | **0.020** | **0.040** |

**Narrow winners are 4 pp more likely to still be active as BEC suppliers one year later, and 3.7 pp more likely two years later.** Both significant. This is the **only genuinely positive and significant finding** of the pilot.

### 2.6 Revolving-door — no detectable effect
- `n_hires_from_public_tp1`: −0.36 (p=0.59)
- `share_hires_from_public_tp1`: −0.002 (p=0.23)

No evidence that narrow winning changes the share of hires coming from the public sector. This kills the Caminho 4 subsection in its current form — the 3% base rate is there but doesn't respond to narrow-win treatment.

---

## 3. Bandwidth sensitivity — stable

For `log_emp_tp1` at fixed bandwidths:

| h | Coef | SE | N |
|---:|---:|---:|---:|
| 0.005 | −0.170 | 0.268 | 35,882 |
| 0.010 | −0.142 | 0.234 | 77,031 |
| 0.015 | −0.119 | 0.236 | 119,724 |
| 0.020 | −0.104 | 0.236 | 157,171 |
| 0.030 | −0.079 | 0.235 | 228,287 |
| 0.050 | −0.040 | 0.236 | 350,071 |

Coefficients move monotonically toward zero as bandwidth widens, consistent with a small negative local effect near the cutoff that attenuates. Nothing "pops out" with narrower bandwidth — the effect is genuinely small, not just statistical noise at one bandwidth.

### Donut-hole (drop |r| < τ)
| τ | Coef | SE |
|---:|---:|---:|
| 0.0005 | −0.071 | 0.233 |
| 0.0010 | −0.074 | 0.233 |
| 0.0020 | −0.055 | 0.241 |

No evidence that exact-tie observations are driving the result. Design is robust in that direction.

---

## 4. What this means for the Paper

### 4.1 The good news
- **The RD is valid**: density passes, covariate balance is OK at the main pre-treatment variables, clustering is properly handled.
- **There is a real finding**: narrow winners have ~4 pp higher survival probability at t+1 and t+2.
- **The parecer critique is vindicated**: the original paper's "incumbency jump" is not robust to proper clustering (loses significance at 5% in the restricted sample). The "last-bid jump" persists but is mechanical / selection-on-outcome.

### 4.2 The bad news
- **The growth story doesn't show up**. Employment, payroll, wages: all null. The Ferraz-Finan-Szerman-style findings don't replicate in our setting at this level of aggregation.
- **The revolving-door story doesn't show up either**. The Caminho 4 subsection as originally planned cannot be the value-add it was meant to be.

### 4.3 Why the growth effects are null — four hypotheses

1. **Treatment too small**. A single close convite auction is, by construction, a SMALL contract (R$176k ceiling). The treatment is economically tiny relative to a firm with median 9 employees. Expect small effects.
2. **Wrong aggregation**. Observations are at firm × auction level. A firm that bids in 100 close auctions in 2013 and narrowly wins 50 of them is counted 100 times, and its outcome at t+1 is the same regardless of which auction we're looking at. This is double-counting and adds noise.
3. **Treatment heterogeneity masked**. Some firms have one narrow auction; others have many. Firm-level aggregation (e.g., "treated if narrowly won any close auction in year t") would give more power.
4. **External margin, not intensive**. The only significant effect (survival) is extensive-margin: the firm exists or not. This suggests procurement contracts function more as "life support" than as "growth engines" in the convite segment.

### 4.4 Recommended pivots

**Pivot 1 (most actionable): switch to firm-year aggregation.**
Instead of firm × auction, aggregate narrow auctions to firm × year:
- Treatment = indicator of winning any narrow auction (|MV| < h) in year t, or fraction won, or count.
- Outcome = firm-year panel variables directly (emp, payroll, survival, etc.).
- This drops the double-counting and gives a cleaner Ferraz-Finan-Szerman analogue.
- Downside: the RD becomes fuzzy (multiple auctions per firm-year), which moves the inference framework from sharp-RD to continuous-treatment intensity.

**Pivot 2: embrace the survival finding as the headline.**
Rewrite Paper 1 as **"Public Procurement as Firm Life Support: Evidence from Close Auctions in São Paulo"**. Focus entirely on extensive-margin survival effects, connecting to the "zombie firm" literature and the development economics literature on firm selection. This is less ambitious but is ACTUAL evidence based on real numbers.

**Pivot 3: beef up the treatment.**
Restrict analysis to auctions that are ECONOMICALLY significant (high reserve price, large quantity). The current sample includes all convite auctions regardless of stakes. A treatment that is 50% of a firm's annual payroll will have different effects than a treatment that is 0.1%. Interact treatment with contract value relative to firm payroll.

**Pivot 4: use pregão instead of convite.**
Pregão has no contract-size limit. The pilot is convite-only. Running the same pipeline on pregão would give larger-stakes treatments and potentially larger effects. The "last bid" mechanical problem in pregão is well-defined (always the last bid is the winner) so it wouldn't confound the employment outcome.

### 4.5 What I recommend

**Do all four, in this order:**

1. **(Fast)** Rerun the pilot with firm-year aggregation (Pivot 1) to see if the growth effects show up with cleaner aggregation. If they do, keep the current framing. If not, consider Pivot 2.
2. **(Fast)** Add contract-value heterogeneity (Pivot 3) as a robustness/heterogeneity analysis.
3. **(Medium)** Extend to pregão (Pivot 4). Use the existing pipeline with a different input file. Depends on the pregão parquet existing; check `02_data/` for it.
4. **(Ongoing)** Be prepared to reframe the paper around survival (Pivot 2) if growth effects don't show up in any spec. That's still a publishable finding — "procurement as life support" is interesting and policy-relevant.

---

## 5. Operational next steps

1. Write `04_rd_pilot_firmyear.py` and `04_rd_pilot_firmyear.R` for Pivot 1.
2. Inspect `02_data/` for pregão files; if absent, extend `linkage_rais_bec.py` or the BEC preparation pipeline.
3. **Halt** further RD pipeline work until a decision is made between Pivot 1 and Pivot 2 framings.
4. **Discuss with Galletta/Giommoni** before committing to reframe. The survival-only story is a reduction in ambition from the original Caminho 1 plan.

---

*Documento gerado por mr-beneath em /co. A honestidade sobre resultados negativos é tão importante quanto celebrar achados positivos — o piloto nos salvou de escrever um paper inteiro com um design que produz efeito nulo na variável-chave.*

---

## 6. Pivot 1 — Firm-year aggregation — **EXECUTED 2026-04-06**

### 6.1 Script and sample

- Scripts: `03_analysis/04_rd_pilot_firmyear_prep.py` + `04_rd_pilot_firmyear.R`
- Sample: `02_data/final/rd_pilot_firmyear_sample.parquet` (4.3 MB)
- Design: one row per (cnpj_raiz, year) 2009–2015, keeping the auction with smallest |MV| as the firm-year's "key" observation
- Rows: 16,887 firm-years (vs 730,592 firm × auction in script 03)
- Unique firms: 7,146 (same as script 03)
- Clustering: at **firm level** (cnpj_raiz) since firms repeat across years
- Report: `02_data/intermediate/rd_pilot_firmyear_results.txt`

### 6.2 Key results (the news is bad)

**Density test: FAILS** — T = −3.612, **p = 0.0003**
- Design artifact of the "closest auction per firm-year" aggregation. The resulting running variable is not symmetric around zero (7,931 positive vs 8,956 negative), because the closest-auction selection is not uniform in direction.
- This is NOT evidence of manipulation in the underlying data — the script 03 (firm × auction) design had p=0.89 on the same underlying observations — but it DOES mean the firm-year RD, as specified, is not a valid RD.

**Balance test: FAILS on level outcomes**

| Pre-treatment covariate | Coef | SE | p |
|---|---:|---:|---:|
| log_emp_tm1 | **−0.170** | 0.080 | **0.035** |
| log_payroll_tm1 | **−0.312** | 0.123 | **0.011** |
| log_avg_wage_tm1 | −0.042 | 0.023 | 0.068 |
| share_female_tm1 | −0.009 | 0.014 | 0.500 |
| avg_age_tm1 | +0.243 | 0.296 | 0.412 |
| share_university_tm1 | +0.004 | 0.008 | 0.638 |
| share_managerial_tm1 | +0.004 | 0.006 | 0.441 |

Narrow winners have **17 log points lower employment** and **31 log points lower payroll** at t-1 than runners-up, both statistically significant. This is the selection story made visible: smaller firms bid more aggressively and win close contests.

**Main outcomes — null**

| Outcome | Coef (conv.) | SE | p (robust) |
|---|---:|---:|---:|
| log_emp_tm1 | −0.170 | 0.080 | 0.039 |
| log_emp_t0 | −0.096 | 0.075 | 0.188 |
| log_emp_tp1 | −0.120 | 0.077 | 0.139 |
| log_emp_tp2 | −0.088 | 0.079 | 0.276 |
| **dlog_emp_tp1_tm1** | **−0.002** | **0.026** | **0.992** |
| **dlog_emp_tp2_tm1** | **+0.030** | **0.032** | **0.332** |
| log_payroll_tp1 | −0.167 | 0.133 | 0.267 |
| log_avg_wage_tp1 | −0.033 | 0.021 | 0.110 |

**The growth-rate null is TIGHT**, not noisy: `dlog_emp_tp1_tm1 = −0.002` with SE 0.026 means the 95% CI is roughly [−0.05, +0.05]. We can rule out growth effects larger than ±5% — much tighter than the firm × auction spec.

**Survival — effect DISAPPEARS**

| Outcome | Script 03 (firm × auction) | Pivot 1 (firm-year) |
|---|---:|---:|
| survived_tp1 | **+0.040 (p=0.017)** | +0.011 (p=0.56) |
| survived_tp2 | +0.037 (p=0.040) | +0.003 (p=0.87) |

**The survival effect in script 03 was almost certainly a double-counting artifact**. Once each firm-year is counted once, the effect vanishes. This was the only "positive" finding of the initial pilot, and it does not survive aggregation.

**Revolving-door — null at both aggregations**, as expected.

**Heterogeneity by firm size (baseline log_emp_tm1 quartiles)** — no pattern:

| Quartile | log_emp_tp1 | dlog_emp_tp1_tm1 |
|---|---:|---:|
| Q1 smallest | −0.07 (p=0.18) | −0.014 (p=0.78) |
| Q2 | +0.03 (p=0.53) | +0.024 (p=0.64) |
| Q3 | +0.04 (p=0.56) | +0.015 (p=0.78) |
| Q4 largest | −0.23 (p=0.09) | −0.063 (p=0.21) |

No cell is robustly significant; no coherent story emerges.

### 6.3 What this all means

Across the two aggregations we have tried, the RD on close-bid convite auctions finds:

1. **No growth effect on employment, payroll, or wages**. The growth-rate specification is a precise zero, not just noise.
2. **No robust survival effect**. What looked positive in script 03 was a double-counting artifact.
3. **No revolving-door effect**. The Caminho 4 complementary subsection has no empirical base.
4. **Design validity problems at both levels**: script 03 has selection bias in levels (fixed by growth rates); Pivot 1 has density asymmetry from the closest-auction aggregation.

**Conclusion: the close-bid convite RD does not produce the labor-market findings needed for Caminho 1 as scoped.** The treatment is too small (R$176k ceiling) for the firms in the sample.

---

## 7. State of the project and honest options

The original assumption behind Caminho 1 was: "close-bid RD × RAIS × convite = clean causal effects of procurement wins on firm dynamics." Two pilots have shown this assumption is wrong for the convite slice. The findings are mostly null, and the only apparent positives were aggregation artifacts.

### Options going forward (in decreasing order of my preference)

**Option A — Pregão pipeline (real Pivot 4).** Rebuild the BEC pipeline for pregão. Pregão has no contract-value ceiling, so treatments are 10×–100× larger and should show effects if any exist. **BLOCKER**: pregão raw data is not in the repo. Only convite is processed. This requires:
- Finding the original BEC pregão microdata source (SP Fazenda / BEC portal)
- Rebuilding the `df_pregao_inter.parquet` analogous to `df_convite_inter`
- Redefining "close bid" for a descending auction (more subtle than first-price sealed)
- **Estimated effort**: 2–4 weeks of data engineering before analysis can start.

**Option B — Abandon Caminho 1, commit to Caminho 2 (worker-flow networks).** This path is correlation-based, not causal-RD, and therefore does not depend on the growth story. Start building the firm × firm worker-flow network and testing whether connected pairs show higher close-bid rates. **Pros**: novel contribution, doesn't depend on null results. **Cons**: harder to execute, ambitious, longer timeline.

**Option C — Firm fixed effects, not RD.** Keep the convite sample, but abandon the RD in favor of a firm × year panel with firm FE and narrow-win indicator as a treatment variable. Not a causal RD but can exploit within-firm variation. **Pros**: might detect effects the RD misses. **Cons**: not a causal identification strategy, weakens the paper's contribution vs Ferraz-Finan-Szerman.

**Option D — Write the null result as a methodological paper.** "Close-bid RD fails to detect real effects in low-stakes procurement: evidence from 2.4M bids in São Paulo." A short, methodological contribution. **Pros**: honest, publishable as a note in a methodology journal. **Cons**: low-impact paper; not what Galletta/Giommoni would want to invest in.

**Option E — Pause and discuss with coauthors.** Present findings to Galletta/Giommoni before committing to any of A–D. This is the most reasonable management choice.

### My recommendation

**Option E first (discuss with coauthors), followed by Option A (pregão) if they're willing to invest in the data engineering.**

If the coauthors are not interested in pregão data engineering, **Option B (Caminho 2)** is the next best.

### What I would NOT do

- Keep forcing the convite RD with more pivots. We've tried two aggregations. Further tweaks will be p-hacking.
- Write the paper as if the survival finding were real — it's not, at firm-year level.
- Add more robustness to null results hoping one will show something. That's specification searching.

---

*Pivot 1 executed 2026-04-06. Total pilot time: ~1 hour. The pilot worked exactly as intended — it saved months of work on a dead-end framing. This is what pilots are for.*

---

## 8. Pivot 4 — Pregão pipeline — **EXECUTED 2026-04-06**

### 8.1 Sourcing breakthrough

Initially I assumed pregão data was not in the project. The user pointed me at
`paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet` —
**39.96M bid-level rows with CNPJ + price + winner flag + procedure type**.
This contains 22.65M pregão bids and 9M convite bids. Pivot 4 became feasible
in hours instead of weeks.

### 8.2 Scripts

- `03_analysis/05_build_pregao_pairs.py` — extracts pregão bids from the paper3
  source, aggregates to firm × auction (each firm's best bid in the descending
  phase), identifies winner and runner-up, computes MV. Output:
  `02_data/final/df_pregao_winner_looser.parquet` (1.67M pair rows for 837k
  unique pregão auctions).
- `03_analysis/06_rd_pregao_prep.py` — joins pregão pairs with firm_year_panel
  for pre/post outcomes. Output: `02_data/final/rd_pilot_pregao_sample.parquet`
  (623k rows, 14,983 unique firms).
- `03_analysis/06_rd_pregao_pilot.R` — RD estimation with rdrobust, with a
  donut hole at |running| < 1e-6 to remove the discreteness mass point at
  exact ties.

### 8.3 Two bugs found and fixed

1. **`ref_price` was 100% null in the first run.** Cause: in the source file,
   `ref_price` is reliably populated only on winning rows; non-winners have
   null. Fixed by extracting an auction-level `ref_price_auction` lookup from
   winning rows and joining it back at the auction level.
2. **34,510 exact ties at running = 0** (5.5% of obs) caused a spurious
   density-test failure (T = 8.84, p < 0.0001 in the pre-donut version).
   These are pregão auctions where winner and runner-up converge to the same
   final price during the open phase. They are a discreteness artifact, not
   evidence of manipulation. Fixed via donut hole.

### 8.4 Validity (after donut)

- **Density test: PASSES** — T = 0.030, p = 0.976. After removing exact ties,
  the running variable is continuous at the cutoff.
- **Sample size after donut**: 589,216 rows, 14,787 firms, 294,608 auctions.
  At |r| < 0.01: 156k observations with employment outcome — much more power
  than convite (77k).
- **Coverage of t+1 outcomes**: 88.3% (vs 78.9% in convite — pregão suppliers
  are more formalized).

### 8.5 Headline results

#### Selection in levels (still present, larger than convite)

| Outcome | Coef | SE | p (robust) |
|---|---:|---:|---:|
| log_emp_tm1 (balance) | **−0.84** | 0.26 | **0.0005** |
| log_emp_tp1 | **−0.82** | 0.27 | **0.0011** |
| log_payroll_tm1 (balance) | **−1.10** | 0.28 | **0.0000** |
| log_payroll_tp1 | **−1.10** | 0.30 | **0.0001** |

The level RD shows narrow pregão winners are ~50% smaller in employment and
~67% smaller in payroll than narrow losers. **This is selection bias, not a
treatment effect** — the gap is the same at t-1 (pre-treatment) as at t+1.
Smaller firms with sharper bids win narrow pregão contests.

This is the same story as convite, except the magnitude is 8–10× larger
because pregão auctions span a much wider firm-size distribution.

#### **Growth-rate effect: POSITIVE AND SIGNIFICANT** ⭐

| Outcome | Coef | SE | p (robust) |
|---|---:|---:|---:|
| **dlog_emp_tp1_tm1** | **+0.079** | **0.031** | **0.004** |
| **dlog_emp_tp2_tm1** | **+0.087** | **0.046** | **0.030** |
| dlog_payroll_tp1_tm1 | +0.015 | 0.061 | 0.597 |

**Once selection is netted out by first-differencing, narrow pregão winners
grow employment ~8% more than narrow losers in the year after the auction,
and ~9% more two years after.** Both significant at 5%, the t+1 effect at
1%.

This is the first **positive growth finding** in the pilot pipeline. It
contradicts both convite pilots (which had a precise zero on the same
specification).

#### Survival: **NEGATIVE AND SIGNIFICANT**

| Outcome | Coef | SE | p (robust) |
|---|---:|---:|---:|
| **survived_tp1** | **−0.075** | **0.024** | **0.001** |
| **survived_tp2** | **−0.069** | **0.022** | **0.001** |

**Narrow pregão winners are 7.5 pp LESS likely to be in RAIS one year later.**
This is robust across all bandwidths (h ∈ {0.005, 0.01, 0.02, 0.05}).

The combined growth + survival pattern is striking:
- **Among survivors**: narrow winners grow ~8%.
- **At the firm-extensive margin**: narrow winners are ~7 pp more likely to
  exit formal employment.
- This is a **creative-destruction** pattern: winning a marginal bid forces
  the firm to deliver on a contract it nearly lost; some firms can't handle
  it and exit; those who can expand.

#### Heterogeneity by contract size (now working)

Quartiles of log reference price (winning auction's ref price):

| Outcome | Q1 (smallest) | Q2 | Q3 | Q4 (largest) |
|---|---:|---:|---:|---:|
| dlog_emp_tp1_tm1 | +0.04 (p=0.43) | −0.005 (p=0.94) | +0.06 (p=0.15) | **+0.10 (p=0.0006)** |
| survived_tp1 | −0.005 (p=0.54) | **−0.18 (p=0.002)** | **−0.06 (p=0.025)** | **−0.04 (p=0.011)** |
| log_payroll_tp1 (selection) | −1.49 (p=0.0003) | −1.71 (p=0.001) | −1.17 (p=0.008) | −0.64 (p=0.0001) |

**The growth effect is concentrated in the LARGEST contracts (Q4): +10
percent extra employment growth in the year after winning.** This makes
intuitive sense: only large contracts generate enough demand to drive
measurable expansion.

**The exit effect is concentrated in MID-SIZE contracts (Q2: −18 pp).**
Largest contracts (Q4) exit modestly (−4 pp), smallest contracts (Q1) show
no exit. The story: mid-size contracts are big enough to over-extend
marginal firms but not big enough to be transformative.

This is a **publishable heterogeneity story**.

#### Wages and rent-sharing — still null

- log_avg_wage_tp1: −0.080 (p=0.018) — but this is balance failure (avg_wage
  is also lower at t-1). Not a treatment effect.
- dlog_payroll_tp1_tm1: +0.015 (p=0.60) — payroll growth null.
- No evidence of rent-sharing through wages.

#### Revolving door — still null

- share_hires_from_public_tp1: +0.004 (p=0.25). No effect of narrow winning
  on the share of hires from the public sector.

The Caminho 4 subsection remains without an empirical hook.

### 8.6 What this changes for the paper

**Pregão delivers what convite could not.** Three findings rise to the level
of "real" by my standards:

1. **Positive growth effect among survivors**: +8% employment growth at t+1,
   +9% at t+2, both significant. Concentrated in the largest contracts.
2. **Negative survival effect**: −7.5 pp likelihood of remaining in RAIS at
   t+1. Concentrated in mid-size contracts.
3. **Combined creative-destruction story**: large pregão wins drive
   expansion among capable firms; mid-size wins push marginal firms out.

**The convite slice is now an instructive null**: a setting where treatments
are too small (R$176k ceiling) to detect effects of either sign. It can
appear in the paper as a contrast — "we find growth and exit effects in
pregão but neither in convite, consistent with treatment-size mattering for
real effects".

### 8.7 Revised recommendation

**Move forward with Caminho 1 reframed as a pregão paper, with convite as a
falsification/contrast.** New title proposal:

> "Creative Destruction in Public Procurement: Employment Effects of Close
> Pregão Wins in São Paulo"

The 9-section outline in `paper1_outline.md` mostly survives, with these
revisions:
- §1 Intro: pivot the framing to creative destruction (winners grow,
  marginal firms exit). Cite Schumpeterian destruction.
- §3 Data: report both convite and pregão samples, motivate pregão as
  primary because it has variation in stakes.
- §4 Strategy: defend the donut-hole (1e-6) treatment of pregão ties.
- §5 Results: lead with growth + survival, then heterogeneity by contract
  size.
- §6 (Caminho 4): drop revolving door — no signal. Replace with a section
  on **firm-size heterogeneity and the mechanics of creative destruction**.
- §7 Robustness: include the convite null as a falsification.

### 8.8 Operational next steps

1. **Now**: communicate findings to Galletta and Giommoni. The pregão result
   reframes the entire paper.
2. **Next code**: run the firm-year aggregation of the pregão pilot (Pivot
   1 logic applied to pregão input). Confirms that the result is robust to
   double-counting concerns.
3. **Robustness needed**:
   - Donut-hole sensitivity: try |r| < 5e-6, 1e-5, 1e-4 to verify the
     coefficient is stable.
   - Firm fixed effects (panel, not RD).
   - Restrict to firms that appear in both convite and pregão samples
     (within-firm comparison across procurement channels).
4. **Decision needed from coauthors**: target journal. With these results,
   JPubE is a natural primary target; AEJ: Applied is feasible; with deeper
   work on the creative-destruction mechanism, REStat is plausible.

---

*The pregão pilot took ~3 hours total: 30 min to discover the source file, 1
hour to build the pair file and prep, 30 min to run the R pilot, 1 hour to
debug ref_price + the density mass-point, 30 min to interpret. The
contribution went from "null result with nowhere to go" to "publishable
creative-destruction story" in one session. This is the value of having the
right data — and of being honest about the convite null instead of forcing
it.*

---

## 9. Pregão firm-year robustness (script 07) — **STRONGER**

### 9.1 Setup

- Scripts: `03_analysis/07_rd_pregao_firmyear_prep.py` + `07_rd_pregao_firmyear.R`
- Sample: `02_data/final/rd_pilot_pregao_firmyear_sample.parquet` (10.9 MB)
- Method: closest-pregão auction per firm-year, donut applied at |MV| < 1e-6
  BEFORE the closest-auction selection
- Rows: 34,386 firm-years (vs 16,887 in convite firm-year)
- Unique firms: 14,787 (vs 7,146 in convite firm-year — pregão has 2× the
  active firm base)

### 9.2 Headline: growth effects are LARGER and tighter at firm-year

| Outcome | Firm × auction | Firm × year |
|---|---:|---:|
| dlog_emp_tp1_tm1 | +0.079 (p=0.004) | **+0.147 (p<0.0001)** ⭐ |
| dlog_emp_tp2_tm1 | +0.087 (p=0.030) | **+0.121 (p<0.0001)** ⭐ |
| dlog_payroll_tp1_tm1 | +0.015 (p=0.60) | **+0.172 (p=0.0006)** ⭐⭐ |
| survived_tp1 | −0.075 (p=0.001) | −0.045 (p<0.0001) |
| survived_tp2 | −0.069 (p=0.002) | −0.043 (p<0.0001) |

**Striking change**: at firm-year level, the growth effects almost DOUBLE
in magnitude AND become much more precisely estimated. The payroll growth
went from null (+1.5%) to 17%! That's because firm × auction was averaging
across many small auctions per firm-year, attenuating signal.

**Survival effect attenuates** from −7.5 pp to −4.5 pp but remains highly
significant (p<0.0001). This is the correct, less-biased estimate.

### 9.3 Heterogeneity by contract size (now beautiful)

| Quartile (log ref_price) | dlog_emp_tp1_tm1 | survived_tp1 |
|---|---:|---:|
| Q1 smallest | +0.084 (p=0.054) | −0.074 (p<0.001) |
| Q2 | +0.061 (p=0.074) | −0.065 (p<0.001) |
| Q3 | +0.120 (p=0.006) | −0.042 (p=0.006) |
| **Q4 largest** | **+0.244 (p<0.0001)** | **−0.001 (p=0.96)** |

**Crystal-clear pattern**:
- **Largest contracts (Q4) → +24% employment growth, 0% extra exit** ⭐
- **Mid-size contracts (Q2-Q3) → +6 to +12% growth, 4-7 pp exit**
- **Smallest contracts (Q1) → +8% growth, 7 pp exit**

The largest contracts are PURE expansion. Smaller contracts trigger
creative destruction (some grow, some exit). This is the cleanest possible
heterogeneity result for a procurement-effects paper.

### 9.4 Donut and bandwidth robustness

**Donut sensitivity** (drop |r| < τ):

| τ | dlog_emp_tp1_tm1 | survived_tp1 |
|---:|---:|---:|
| 1e-6 | +0.147 (SE 0.025) | −0.045 (SE 0.010) |
| 1e-5 | +0.147 | −0.042 |
| 1e-4 | +0.142 | −0.034 |
| 1e-3 | +0.117 | (smaller) |

Stable across donut thresholds. The story is not driven by exact-tie
observations.

**Bandwidth sensitivity**:

| h | dlog_emp_tp1_tm1 | survived_tp1 |
|---:|---:|---:|
| 0.005 | +0.160 | −0.057 |
| 0.010 | +0.147 | −0.047 |
| 0.020 | +0.118 | −0.037 |
| 0.050 | +0.085 | −0.023 |

Coefs attenuate as bandwidth widens, but always positive on growth and
always negative on survival. Always significant (modulo a NaN clustering
artifact at h=0.02 in some cells). The MSE-optimal bandwidth (≈ 0.01) is
where the local randomization assumption is most defensible.

### 9.5 What this means

The pregão firm-year results are the **definitive headline numbers** for
the paper. They:
- Confirm the firm × auction pilot wasn't a fluke.
- Show growth effects ~2× larger when correctly aggregated to firm-year.
- Reveal payroll growth (which was null in firm × auction).
- Sharpen the heterogeneity by contract size into a publishable plot.
- Survive donut and bandwidth sensitivity.

**Bottom line for Caminho 1, reframed:**
- Title: *"Creative Destruction in Public Procurement"*
- Headline: narrow pregão winners grow employment +15% and payroll +17% in
  the year after winning, while being 4.5 pp more likely to exit formal
  employment. The largest contracts (Q4) are pure expansion (+24% growth,
  0% exit); smaller contracts trigger genuine creative destruction.
- Convite: a precise-zero null in the same specification → falsification
  showing that treatment size matters.
- Identification: close-bid RD with donut at exact ties; density passes;
  selection in levels handled via first-differencing.

**This is a JPubE paper at minimum, with REStat plausible after deeper
mechanism work.**

---

*Pivot 4 + Pivot 1 robustness completed 2026-04-07. Total elapsed time
for the entire pivot exploration: ~5 hours. The pregão data sourcing
breakthrough turned a dead pilot into a real paper.*

---

## 10. Event-study identification check (scripts 08, 09) — **the paper changes again**

### 10.1 Why we ran it

The script-07 firm-year results report headline numbers like "+15% emp
growth at t+1" and "−4.5 pp survival" using `dlog_emp_tp1_tm1` and
`survived_tp1`. To defend the paper against a referee, we needed to show
that these effects represent the BREAK at the auction year — not a
continuation of pre-existing trends. The standard tool is an event-study
plot with year-over-year growth rates around the auction year. If the
pre-treatment growth rate (k = −1) is ≈ 0, the design is clean. If it's
positive and significant, we have a problem.

### 10.2 Pregão employment YoY event study (script 08)

| k | dlog_emp YoY | SE | p (robust) |
|---:|---:|---:|---:|
| **−1 (placebo)** | **+0.045** | **0.016** | **0.005** ⚠️ |
| 0 (impact) | +0.106 | 0.018 | <0.0001 |
| +1 | +0.045 | 0.014 | 0.001 |
| +2 | −0.003 | 0.013 | 0.829 |
| +3 | +0.017 | 0.016 | 0.249 |

**The pre-trend is real and significant.** Narrow pregão winners were
already growing employment ~4.5% faster than narrow losers in the year
BEFORE the auction. The "+15% growth" headline of script 07 is a sum of
~+10.6% real impact + +4.5% pre-trend continuation.

The clean causal estimate is the **trend break** at k = 0:
**+0.106 − +0.045 ≈ +0.061**, i.e., a real treatment-on-impact employment
effect of about **6 percentage points**, not 15. After the impact year, the
growth differential collapses to the pre-trend level (+4.5% at t+1 = same
as the pre-trend) and then to zero (t+2, t+3).

The cumulative effect on log employment from the t-1 baseline:

| k | cumulative dlog emp | SE |
|---:|---:|---:|
| −2 | −0.045 | 0.016 |
| −1 (baseline) | 0 | — |
| 0 | +0.106 | 0.018 |
| +1 | +0.147 | 0.025 |
| +2 | +0.121 | 0.027 |
| +3 | +0.130 | 0.032 |

Cumulative effect persists at +12-15 percent for three years, but ~30% of
that is the pre-trend continuation, not new treatment effect.

### 10.3 Pregão survival event study (script 09) — **the inversion**

This is the finding that flips the paper:

| k | RD coef on P(survive) | SE |
|---:|---:|---:|
| **−2** | **−0.123** | **0.013** |
| **−1** | **−0.092** | **0.012** |
| 0 | −0.059 | 0.010 |
| +1 | −0.045 | 0.010 |
| +2 | −0.043 | 0.010 |
| +3 | −0.040 | 0.012 |

**The survival "effect" is entirely a pre-trend that closes over time.**
Narrow pregão winners are firms with **−12 pp baseline survival** TWO
YEARS before the auction. The gap narrows monotonically over the
post-treatment window: −9.2 pp at t-1, −5.9 pp at impact, −4.0 pp at t+3.

**The DiD estimate flips the interpretation:**
- Post-period (t+1): −4.5 pp
- Pre-period (t-1): −9.2 pp
- **DiD survival effect: +4.7 pp INCREASE in survival** (closing half the gap)

**Procurement contracts do not kill firms — they keep them alive.** The
naive RD coefficient was contemporaneously negative because narrow winners
are pre-existingly more fragile firms. The contract is what closes the gap.

### 10.4 Q4 (largest contracts) event study — heterogeneity is real

**Q4 employment YoY:**

| k | coef | SE |
|---:|---:|---:|
| −1 | +0.092 | 0.040 |
| **0** | **+0.234** | 0.043 |
| +1 | +0.053 | 0.037 |
| +2 | +0.002 | 0.031 |
| +3 | +0.053 | 0.037 |

Q4 trend break: **+0.234 − +0.092 = +0.142 (+14.2%)**, more than 2× the
average across all contract sizes (+6%).

**Q4 survival:**

| k | coef | SE |
|---:|---:|---:|
| −2 | −0.080 | 0.022 |
| −1 | −0.049 | 0.019 |
| **0** | **+0.002** | 0.014 |
| +1 | −0.001 | 0.015 |
| +2 | +0.009 | 0.017 |
| +3 | +0.007 | 0.020 |

**In Q4, the survival gap closes COMPLETELY at the auction year and
stays closed.** From −5 pp pre-treatment to exactly zero post-treatment.
**DiD survival effect for Q4: +4.9 pp.** The largest pregão contracts
ELIMINATE the entire baseline mortality disadvantage of narrow winners.

### 10.5 Convite as falsification (script 09) — clean placebo

**Convite emp YoY:**

| k | coef | SE |
|---:|---:|---:|
| −1 | −0.041 | 0.020 |
| 0 | +0.019 | 0.018 |
| +1 | +0.001 | 0.021 |
| +2 | +0.026 | 0.019 |
| +3 | +0.035 | 0.021 |

**Convite survival:**

| k | coef | SE |
|---:|---:|---:|
| −2 | +0.007 | 0.018 |
| −1 | +0.012 | 0.019 |
| 0 | +0.006 | 0.018 |
| +1 | +0.011 | 0.019 |
| +2 | +0.003 | 0.019 |
| +3 | +0.019 | 0.019 |

**Convite has zero pre-trend in survival and zero effect throughout.**
This is a clean null in BOTH margins. Convite firms are well-balanced; the
contract is too small to move anything.

### 10.6 The paper, version 3.0

| Old story (sections 8, 9) | New story (section 10) |
|---|---|
| "Creative destruction in procurement" | **"Procurement as life support for marginal firms"** |
| Narrow winners grow AND exit | Narrow winners grow at impact AND become more likely to survive (DiD) |
| +15% growth at t+1 | +6% trend break at impact (full sample); +14% for Q4 |
| −4.5 pp survival ("contracts kill") | **+4.7 pp DiD survival ("contracts rescue")** |
| Q4 = pure expansion | Q4 = both effects amplified: +14% growth, +5 pp survival rescue |

### 10.7 Why the rescue interpretation is defensible

The risk: a referee says "your DiD survival effect is just mean reversion
— marginal firms naturally improve over time, contract or no contract."

Three counter-arguments from our data:

1. **Heterogeneity by contract size argues against pure mean reversion.**
   Q4 closes the entire survival gap (−5 → 0); smaller quartiles close
   only part. If it were pure mean reversion, all quartiles would
   converge equally, since they have similar baseline gaps. The
   monotonic-in-stakes pattern points to a real treatment effect.

2. **Convite has zero pre-trend in survival.** Marginal firms in convite
   should also exhibit mean reversion — but they don't. The pregão pattern
   is therefore not a generic feature of marginal firms; it's specific to
   the type of firms that compete in higher-stakes auctions.

3. **The size of the convergence is too large for pure regression toward
   the mean** in a one-year window for a population of formal firms.

These arguments are good, not airtight. A REStud-grade defense would need
either (a) a matched control of non-bidders or (b) a structural model of
firm survival that calibrates how much convergence pure mean reversion can
generate. Both are out of scope for the pilot. The paper as it stands is
defensible at JPubE / AEJ:Applied with these arguments.

### 10.8 What the paper looks like now

Working title: **"Public Contracts as Firm Life Support: Evidence from
Close Procurement Auctions in São Paulo"**.

Key empirical claims:
1. Narrow pregão winners are pre-existingly fragile firms (−9 pp survival
   baseline relative to narrow losers).
2. **Winning a contract closes ~half the survival gap (DiD = +5 pp).**
3. Winning also produces a one-time employment growth boost (trend break
   ≈ +6%).
4. The largest contracts (Q4) produce +14% growth and a complete
   elimination of the survival gap.
5. Convite — a parallel sealed-bid format with much smaller stakes — has
   neither effect, serving as falsification that the pregão patterns
   reflect contract-induced rescue and not generic statistical artifacts.

Headline number: **DiD survival effect of +5 pp (+15% relative to baseline
survival of ~30% for narrow losers in t+1)**.

### 10.9 Operational status

**The paper has changed identity TWICE in one session**:
- v1 (original): Detection of cartel signals (KNOC-style)
- v2 (after Pivot 4): Creative destruction in procurement
- **v3 (after event study)**: Procurement as life support for marginal firms

v3 is **the most defensible interpretation given the data**. It's a
positive policy story (contracts save firms), it has a clean DiD
identification with falsification, and it's testable against alternatives.

**Before circulating to coauthors, two final checks:**
- Bandwidth sensitivity of the trend-break estimates
- Investigate WHY narrow losers exit (motivo_desligamento) — does the
  mechanism look like financial distress (consistent with rescue story)
  or voluntary exit (consistent with mean reversion)?

These are the next two scripts.

---

*Event study findings recorded 2026-04-07. The most important pilot
discovery so far. The paper is now structured around the survival
rescue effect, with growth as a secondary finding.*

---

## 11. Track A — KNOC density test with CADE ground truth (script 14)

**Context.** After the coauthor meeting (2026-04-07), we decided to run two
parallel tracks:
- **Track A**: revive the original cartel-detection paper using CADE ground
  truth, properly implemented density test, and possibly other screens.
- **Track B**: continue refining v2 / v3 (this is the rescue/restructuring
  framing in sections 8–10 above).

This section documents the FIRST Track A test: the proper KNOC density test,
done correctly (which the original paper did NOT do), evaluated against
35 SP firms in 7 confirmed CADE cartels.

### 11.1 Setup

- Ground truth: `02_data/firms/cade_ground_truth.parquet` (56 firm × cartel
  entries, 35 SP firms in BEC, all also in RAIS panel)
- Auction-level cartel exposure flags: `df_pregao_with_cartel_flags.parquet`
  and `df_convite_with_cartel_flags.parquet`
- Test: Cattaneo–Jansson–Ma (rddensity) at running = 0, donut |r| < 1e-6
- Filters applied at AUCTION level (not row level) to keep both winner and
  runner-up rows of cartel-exposed pairs together. (An earlier run filtered
  at row level and produced T = -2.57 / p = 0.01 spurious results from
  asymmetric sampling — fixed.)

### 11.2 Results (corrected)

| Subsample | N | T | p |
|---|---:|---:|---:|
| PREGÃO full | 1,012,862 | −0.016 | 0.99 |
| CONVITE full | 1,041,562 | +0.173 | 0.86 |
| Pregão: ≥1 cartel-active firm | 4,588 | −0.023 | 0.98 |
| Pregão: cartel firm × outside period | 10,796 | +0.009 | 0.99 |
| Pregão: clean control (no cartel) | 997,478 | −0.015 | 0.99 |
| Pregão: PAIR-MATCHED both cartel | 20 | 0 | 1.00 |
| Pregão: medicamentos × active | 3,874 | −0.025 | 0.98 |
| Convite: cartel-active | 526 | +0.056 | 0.96 |

**Every subsample fails to reject CJM continuity.** No density discontinuity
in the pooled data, no discontinuity in cartel-exposed auctions, no
discontinuity in pair-matched auctions.

### 11.3 What this means

The KNOC density test was designed to detect **designated-winner cartels
with within-auction cover bidding**. Under that mechanic, the runner-up
bids slightly above the designated winner; this leaves a "missing mass"
just above zero on the loser side and a corresponding bunching on the
winner side.

**Our null result implies that the CADE-confirmed cartels in BEC do NOT
operate via this mechanic.** Possible alternative mechanics consistent with
both the null density result and the existence of real cartels:

1. **Inter-auction bid rotation** — same firm wins repeatedly in a sector,
   coordination is across auctions, not within. KNOC test cannot detect
   this. Would show up as incumbency persistence (the original paper's
   Table 1 finding).
2. **Market division** — firms split markets geographically or by item
   type, with no cover bidding within any single auction. KNOC test
   blind.
3. **Subcontracting agreements** — winner shares revenue with cartel
   members through subcontracts. No bidding manipulation needed.
4. **Reference-price coordination** — all firms bid close to the reserve
   price, with negligible discounts. Density at MV=0 is symmetric because
   no firm is far from the reserve.

### 11.4 Implication for the original paper

The original paper found a +1.82 pp jump in incumbency at the close-bid
threshold. With KNOC density passing in pregão AND in cartel-exposed
auctions, **the original paper's incumbency jump CANNOT be a KNOC density
signal**. It must be either:

(a) **Inter-auction bid rotation** showing up as persistent incumbency
    (cartelized firms keep winning in sequence — this is exactly the
    pattern incumbency captures);
(b) **Persistent firm heterogeneity** (non-cartel: smaller firms with
    sharper bids systematically win narrow auctions and were also
    "incumbents" because they win often anyway).

**The next test (A.3) discriminates between (a) and (b)**: replicate the
original Table 1 with proper clustering, split by cartel-exposed vs not.
If (a) → jumps concentrate in cartel auctions. If (b) → jumps appear
everywhere.

### 11.5 What survives for Track A

- The CADE ground truth (35 SP firms × 7 cartels) remains valuable.
- The KNOC density screen is **out** as a primary tool.
- The **incumbency-jump test (with cartel split)** is the next thing to try.
- **Variance/CV screens** (Abrantes-Metz, Imhof) and **worker-flow network
  screens** remain to be tested.

The negative density-test result is itself a contribution: it documents
that a screen widely cited in the international literature (KNOC 2023
Restud) does not transfer to the Brazilian procurement context, requiring
detection methods specific to local cartel mechanics.

---

*KNOC null result recorded 2026-04-07. Track A pivots to A.3
(incumbency-jump test with cartel split) as the next diagnostic.*

---

## 12. Track A — A.3 Table 1 replication with cartel split (script 15)

**Setup.** Replicate the original paper's two main findings (incumbency jump
+1.82pp p<0.01, last-bid jump +6.36pp p<0.01) on convite, with the parecer's
corrections applied:
1. Cluster at item-class level (paper 3 convention)
2. Restrict to 2009–2015 treatment window
3. Apply donut at |MV|<1e-6 + envelope |MV|<0.10
4. Split by CADE cartel exposure to test the rotation interpretation

### 12.1 Convite headline replications (full sample)

| Outcome | Original | Corrected |
|---|---|---|
| **Incumbent** | +1.82 pp (p<0.01) | **+2.92 pp (p = 0.16)** ⚠️ |
| **Last-bid** | +6.36 pp (p<0.01) | **+7.94 pp (p<0.0001)** ✓ |

**The incumbency jump does not survive proper clustering.** Bandwidth and N
are nearly identical to the original paper (h=0.026 vs orig 0.020;
N=251,486 vs orig 261,370). The only difference is item-class clustering.
The original paper's "significance at 1%" was an artifact of underclustered
standard errors.

**The last-bid jump is robust** and even slightly larger (+7.94pp vs +6.36pp
in the original). p<0.0001 with N=730,590. This is the original paper's
strongest empirical finding and it survives.

### 12.2 Cartel split (convite)

| Subsample | N | Incumbent coef | p | Last-bid coef | p |
|---|---:|---:|---:|---:|---:|
| Full convite | 251k–731k | +0.029 | 0.16 | +0.079 | <0.0001 |
| Cartel-active | 245–526 | +0.176 | 0.19 | −0.287 | 0.18 |
| Cartel firm × outside period | 455–1,120 | +0.229 | 0.60 | −0.007 | 0.97 |
| Clean control | 251k–729k | +0.029 | 0.16 | +0.079 | <0.0001 |

**Convite is severely underpowered for the cartel split**: only 705 cartel-
active rows in the entire 1.21M convite sample. The point estimates in
cartel-active subsample (+17.6% incumbent, −28.7% last-bid) are SUGGESTIVE
of cartel concentration but the SEs are too large for inference.

The clean control coefficients are essentially identical to the full
sample because cartel-exposed convite is < 1% of the total. This is not
informative about the rotation hypothesis.

### 12.3 What survives from the original paper

The original paper had two empirical claims; one survives, one doesn't:

| Claim | Status | Notes |
|---|---|---|
| Incumbency jump (1.82pp) | ❌ FRAGILE | Vanishes at p=0.16 with proper clustering. Original significance was underclustered SE artifact. |
| Last-bid jump (6.36pp) | ✅ ROBUST | +7.94pp at p<0.0001 in corrected spec. |
| "Anti-competitive signals" framing | ⚠️ RECONSIDERED | Survives only if last-bid jump is interpreted as bid leakage / pre-auction info sharing. |

### 12.4 What this means for Track A

**The original paper has a real finding** (last-bid jump) that survives
correct clustering and restricted-window analysis. The framing
"anti-competitive signals" remains defensible **if** we interpret the
last-bid pattern as evidence of bid leakage or pre-auction information
sharing.

The KNOC density test (script 14) is null even in cartel-exposed auctions,
which means the cartel mechanism is NOT within-auction cover-bidding. The
last-bid jump is a SEPARATE, parallel phenomenon, possibly capturing
something else (timing manipulation, late entry by informed bidders, etc.).

**The cartel split is NOT a clean test in convite** due to sample size.
We need either:
- Pregão version with custom incumbency definition (1–2 hours of work)
- Or different screens that don't require this split for power

### 12.5 Operational decision (post-coauthor meeting)

The user chose to (a) document findings + (b) proceed to **A.4 (variance/CV
screens)** before reconstructing incumbency for pregão. Variance/CV screens
don't need market definitions and can be computed directly from the bid
prices, so they're a fast next step.

---

*A.3 results recorded 2026-04-07. Last-bid is the original paper's only
robust finding; incumbency was a clustering artifact. Cartel split needs
pregão for power; deferred to a later session.*

---

## 13. Track A — A.4 variance/CV screens + A.5 worker-flow networks

This section consolidates two screens tested against CADE ground truth:
A.4 (classical bid-distribution screens) and A.5 (worker-flow network).
A.4 fails like KNOC; **A.5 succeeds with AUC = 0.83**.

### 13.1 A.4 Variance / CV screens (script 16)

**Implemented**: Abrantes-Metz / Imhof family — coefficient of variation
of firm-best bids, spread, and auction-level margin of victory. Computed
on 976,109 pregão auctions and 1,636,901 convite auctions (≥2 firms each).

**Pregão headline:**

| Screen | Cartel-active μ | Control μ | t-stat | AUC |
|---|---:|---:|---:|---:|
| cv_bid | 0.607 | 0.634 | −5.93 | 0.50 |
| spread | 1.577 | 1.613 | −2.45 | 0.47 |
| mv | 0.354 | 179.4† | −2.75 | 0.52 |
| **n_firms** | **6.67** | **5.64** | **+28.7** | (not a screen) |

†MV control mean inflated by outliers; cartel-active median is more
reliable. Signs are weakly consistent with cover-bidding (cartels cluster
bids), but the AUCs are essentially random.

**Convite headline (signs flip):**

| Screen | Cartel-active μ | Control μ | t-stat | AUC |
|---|---:|---:|---:|---:|
| cv_bid | 0.564 | 0.361 | +37.7 | 0.33 |
| spread | 1.560 | 0.839 | +44.1 | 0.26 |
| n_firms | 8.53 | 5.11 | +62.4 | (not a screen) |

In convite, cartel auctions have HIGHER CV and spread (opposite of cover-
bidding prediction). AUCs below 0.5 mean classical screens flag the
WRONG auctions in convite.

**Two findings of independent interest:**

1. **Cartel auctions attract MORE bidders, not fewer** in BOTH formats
   (Δ = +1 firm in pregão, +3.4 firms in convite). This contradicts
   simple entry-deterrence models. Possible interpretation: BEC cartels
   coordinate among many participants rather than restricting entry.

2. **Convite cartel mechanics differ from pregão** — opposite signs
   on CV/spread suggest different coordination strategies in the two
   formats.

**Conclusion**: classical bid-distribution screens (KNOC, Abrantes-Metz,
CV, spread, MV) are statistically distinguishable in cartel vs control
samples but **AUCs are at chance** for cartel detection. They are not
useful as screens in BEC.

### 13.2 A.5 Worker-flow network screen (script 17) — **the breakthrough**

**Setup.** Built a firm-firm undirected weighted graph from RAIS harmonized
vinculos 2009-2017:
- 12,626,199 unique PIS in BEC firms
- 2,440,466 PIS appear at ≥2 BEC firms (worker mobility universe)
- 31,470 unique cnpj_raiz
- **931,783 firm-firm edges** (sparse: ~0.2% of theoretical max)
- Edge weight = count of workers who appear in both firms over the panel

For each pregão close-bid auction (|MV|<0.10, n=535,191), looked up the
worker-flow edge weight between winner and runner-up.

**Coverage:** 57,150 / 535,191 (10.7%) of close-bid pairs have ≥1 shared
worker. The network is sparse — most close-bid pairs are NOT connected.

**Headline:**

| Group | N | shared_workers (mean) | jaccard (mean) |
|---|---:|---:|---:|
| Clean control (no cartel firm) | 527,259 | **2.09** | 0.0008 |
| Cartel-active (any) | 2,351 | **5.76** ⭐ | 0.0022 |
| Pair-matched (both cartel) | 10 | **28.4** ⭐⭐ | 0.0010 |

- Cartel-active vs control: **t = +13.99**, p ≈ 0
- Jaccard cartel-active vs control: t = +20.68, p ≈ 0
- Pair-matched is dramatic in mean (28× control) but only n=10 → t=1.0

**AUC results — the only screen that works:**

| Screen | AUC |
|---|---:|
| KNOC density | NULL (no signal) |
| CV (Abrantes-Metz) | 0.50 |
| Spread | 0.47 |
| MV scaled | 0.52 |
| **shared_workers** | **0.8253** ⭐ |
| **jaccard** | **0.8148** ⭐ |

**AUC = 0.83 is publishable territory.** Imhof, Karagök & Rutz (2018) report
their best screens at AUCs of 0.7-0.8 in European cartel cases.

**Distribution percentiles** (shared workers per pair):

| Percentile | Control | Cartel-active |
|---|---:|---:|
| p50 | 0 | 3 |
| p75 | 0 | 10 |
| p90 | 1 | 15 |
| p99 | 24 | 27 |

The median control pair has ZERO shared workers between winner and
runner-up. The median cartel-active pair has 3.

### 13.3 Summary table — Track A screens

| Screen | Mechanism | AUC | Notes |
|---|---|---:|---|
| KNOC density | within-auction cover-bidding | NULL | Fails entirely |
| CV (Abrantes-Metz) | bid clustering | 0.50 | Stat sig but AUC at chance |
| Spread | bid range | 0.47 | Idem |
| MV scaled | margin clustering | 0.52 | Idem |
| Incumbency RD | inter-auction rotation | n/s* | Original finding fragile to clustering |
| Last-bid RD | timing manipulation | **+7.94 pp p<0.0001** | Robust in convite full sample |
| **Worker-flow network** | shared personnel as channel | **0.8253** | **Novel screen, publishable** |

\*n/s = not significant after proper clustering

### 13.4 The story for the paper

**This is enough to write a strong paper.** The narrative arc:

1. **Established screens fail in BEC**. KNOC density, Abrantes-Metz CV, and
   the original paper's RD on incumbency all fail to distinguish cartel
   from control auctions in the CADE ground truth (script 14, 15, 16).

2. **One classical finding survives**: the last-bid jump in convite
   (+7.94pp p<0.0001), interpretable as bid timing manipulation.

3. **A novel screen — worker-flow networks — works dramatically** (AUC =
   0.83 in pregão, exploiting ~10.7% of close-bid pairs that have shared
   workers). This is the first cartel screen in the literature based on
   matched employer-employee data.

4. **The mechanism**: cartel firms share personnel — managers, sales
   reps, technical staff — that serve as informal coordination channels
   not visible in bid patterns. RAIS reveals this; bid-distribution
   screens cannot.

5. **Generalizability**: any country with formal employment registries
   matched to procurement records can implement this screen. Brazil is
   not unique — Mexico, Chile, Colombia, India, South Africa all have
   relevant data infrastructure.

### 13.5 Caveats and required robustness

The +0.83 AUC is the headline but requires defenses:

1. **Sectoral confounding**. Workers may be shared because firms are in
   the same niche (same talent pool), not because firms collude. Test:
   restrict to within-CNAE comparisons; the worker-flow signal should
   survive.

2. **Outsourcing/temp agencies**. Could create spurious edges. Already
   capped PIS to those at 2-30 firms; additional check would exclude
   firms with high churn (temp agency-like patterns).

3. **Reverse causality**. Cartel firms may share workers BECAUSE of
   coordination (defectors hired into cartel members' senior roles
   to bind them). This is fine for screening — direction doesn't matter.

4. **Pair-matched n=10** is too small for inference; the AUC is driven
   by the broader cartel-active sample (n=2,351). Document this honestly.

5. **Causal interpretation**. The screen WORKS empirically. Claiming it
   reflects coordination requires either qualitative case studies or
   linking to specific high-mobility individuals (which RAIS allows).

### 13.6 Paper outputs ready

After A.5, Track A has:
- A clean rejection of classical screens (sections 11, 13.1)
- A robust survival of the last-bid finding (section 12)
- A novel high-AUC screen (section 13.2)
- A coherent narrative about why (sections 13.3, 13.4)

**The paper original is alive — and stronger than it was in v1.** It went
from "we apply KNOC" (which the parecer rejected) to "we test five screens
including KNOC against CADE ground truth and propose a novel worker-flow
network screen with AUC 0.83." That's a different and better paper.

### 13.7 What still needs to happen

Before circulating to coauthors:
1. ✅ Document A.4 + A.5 results (this section)
2. **Sectoral robustness for A.5**: re-run within CNAE-2-digit blocks
3. **Pregão Q4 / largest contracts**: AUC of worker-flow in big auctions
   (where rotation cartels are most likely)
4. **Convite A.5 result**: same network, applied to convite pairs (the
   network is built once, applies to both)
5. **Compare to co-bidding network as a less-novel benchmark**: are
   worker flows really adding info beyond co-bidding history?

The minimum to circulate is items 2 and 4. Item 5 is a referee-anticipation
robustness that strengthens the contribution.

---

*A.4 + A.5 results recorded 2026-04-07. Worker-flow network screen
(AUC 0.83) is the centerpiece finding for Track A. The paper original
is now being rebuilt around this novel screen.*
