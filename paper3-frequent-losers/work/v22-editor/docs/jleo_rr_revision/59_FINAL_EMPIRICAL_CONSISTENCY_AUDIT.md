# 59 — Final Empirical Consistency Audit

**Paper:** *Cheap Signals, Costly Proof…* (JLEO R&R, v22). **Auditor mode:** read-only, grep-verified.
**Method:** grep the key numbers across `sec0*.tex` + `sec_app*.tex` + `values.tex`, and the rendered text (`pdftotext` of paper + appendix). Confirm the manuscript and online appendix agree.

Legend: ✅ CONSISTENT across main / appendix / values.tex.

---

## A. Sample counts

| Quantity | Macro | Value | Main PDF | Appendix PDF | values.tex | Verdict |
|----------|-------|-------|----------|--------------|-----------|---------|
| BEC price sample | `\valSampleN` | 1,654,401 | ✓ | ✓ (l.28) | l.21 | ✅ |
| BEC universe (pre-restriction) | `\valSampleNfull` | 1,654,447 | ✓ | ✓ (l.27) | l.23 | ✅ |
| Always-losers | `\valAlwaysLosers` | 16,843 | ✓ | ✓ (l.33, 56) | l.9 | ✅ |
| Frequent losers | `\valFL` | 2,735 | ✓ | ✓ (l.39, 63) | l.11 | ✅ |
| IQR threshold | `\valThreshold` | 14 | ✓ | ✓ | l.15 | ✅ |
| Always-loser cobidders (target) | `\valCobidders` | 193 | ✓ (l.288, 498) | ✓ (l.90, 149) | l.17 | ✅ |
| Direct CADE defendants (BEC-active) | `\valDirectCADE` | 47 | ✓ (l.276, 365) | ✓ | l.19 | ✅ |
| Year span | `\valYearStart/End` | 2009–2019 | ✓ | ✓ | l.25/27 | ✅ |

## B. Labels (defendants vs cobidders)

| Claim | Location | Verdict |
|-------|----------|---------|
| Direct defendants = legal anchors; cobidders = exposure | sec02 T1 note; sec04; sec_app02 | ✅ |
| Cobidder def = always-loser sharing ≥1 tender-item with a direct defendant | sec04 l.287–288 ("yielding 193 always-loser cobidders"); appendix l.90 | ✅ |
| Direct defendants excluded from cobidder pool (separate categories) | T1 note "categories separate legal membership from screening exposure"; sec_app01 | ✅ |
| Cobidder ≠ legal membership | sec04 l.289 "not legal membership or a latent truth about agreement" | ✅ |

**Cobidder denominator nuance (reconciled, not an inconsistency):**
- **193** = static narrow-definition target row count (`\valFunnelStaticTarget`=193, `\valCobidders`=193) — T1, T2, appendix.
- **191** = positives that are *scorable* inside the 16,843-firm always-loser validation pool ("191/16,843", sec04 l.852; appendix). Two of 193 not in the scored frame.
- **190** = positives inside the 16,772-firm bid-benchmark pool (T5 note) — firms lacking complete Imhof features dropped.
- **broad funnel:** 341 FL / 651 AL cobidders (`\valFunnelFLcobBroad`/`\valFunnelALcobBroad`); 4-case conservative 107/208.
All three denominators (193/191/190) are explicitly defined in their table/figure notes and follow a clean subset logic. ✅ CONSISTENT.

## C. Scores

| Object | Location | Verdict |
|--------|----------|---------|
| W_i (win count), T_i (tender count), always-loser = {W_i=0} | sec_app02 l.33; sec03 | ✅ |
| Score s_i = log(1+T_i) | sec03; appendix framework | ✅ |
| FL14 = T_i ≥ 14 binary (`\geq`) | sec03; `\valThreshold`=14 | ✅ |
| Continuous log(tc) dominates FL14 binary | DeLong Z=−4.38, p=1.2e-05 (`\valDeLongZ`/`\valDeLongP` l.47/49) | ✅ |

## D. Validation

| Quantity | Macro | Value | Main | Appendix | Verdict |
|----------|-------|-------|------|----------|---------|
| Exposure-only AUC | `\valExpOnlyAUC` | 0.946 | ✓ (l.629, 732) | ✓ (l.578, 636) | ✅ |
| Within-stratum AUC (log_tc) | `\valExpWithinAUC` | 0.771 | ✓ (l.639, 752) | ✓ (l.633, 640) | ✅ |
| Within-stratum AUC (FL14) | `\valExpWithinFLAUC` | 0.771 (0.7709) | ✓ | ✓ | ✅ |
| Nested AUC increment | `\valExpIncrement` | +0.042 (0.0415) | ✓ (l.636, 772) | ✓ (l.632, 638) | ✅ |
| Nested DeLong p | `\valExpDeLongP` | 2.1×10⁻⁶ | ✓ (l.636) | ✓ (l.633) | ✅ |
| Within-stratum cobidder Δ | `\valExpMatchedDelta` | 0.083 | ✓ (l.641) | ✓ | ✅ |
| Raw (in-sample) AUC | — | 0.939 | ✓ (l.639) | ✓ | ✅ |
| Direct-defendant scope AUC | `\valAUCdirectCADE`/`\valAUCdirectStd` | 0.491 / 0.49 | ✓ (l.738=0.476, l.1185=0.49, l.1216 "0.49, close to random") | ✓ (l.756 worst 0.497) | ✅ |
| Positives / pool | — | 191 / 16,843 | ✓ (l.852) | ✓ | ✅ |

Note: the 0.476 at PDF l.738 is a single year-origin / bin cell in the timing panel, not the headline; headline direct-defendant scope is 0.49 (`\valAUCdirectStd`), stated "close to random." No conflict.

## E. Bid benchmark

| Quantity | Value | Main (T5 / §6) | Appendix | Verdict |
|----------|-------|----------------|----------|---------|
| Imhof bid RF | 0.888 | ✓ (l.1372, 1458) | ✓ (l.1141) | ✅ |
| FL14 award screen | 0.921 | ✓ (l.1372, 1446) | ✓ (l.1141) | ✅ |
| Combined award+bid | 0.962 | ✓ (l.1374, 1470) | ✓ (l.1142) | ✅ |
| Evaluation pool | 16,772 firms / 190 positives | ✓ (T5 note l.2018) | ✓ | ✅ |
| Same-support requirement | both layers on shared pool | ✓ (T5 note) | ✓ (l.1295) | ✅ |
| Leakage / case clustering | increment +0.151 pooled → +0.064 case-grouped; case clustering not feature–target overlap | ✓ (l.1383, 1388) | ✓ (l.1148) | ✅ |

**Two-sample note (documented design, not an inconsistency):** The headline 0.888/0.921/0.962 is the N=16,772-firm benchmark sample. `values.tex` also carries `\valAUCImhofFull`=0.846 / `\valAUCImhofPlusFL`=0.942 / `\valAUCImhofPlusTC`=0.944 — the *legacy N=11,676 same-sample* macros, and `\valAUCimhofPlusTC`=0.962 for the headline sample. The 0.846/0.942/0.944 set is the generated-but-not-headline cross-sample (per MEMORY "Two Imhof horse-race samples"); the rendered manuscript uses 0.888/0.921/0.962 consistently. No conflicting numbers appear in the PDFs. ✅ CONSISTENT.

## F. Cost-recall

| Quantity | Value | Main (T6 / §6) | Appendix | Verdict |
|----------|-------|----------------|----------|---------|
| K1 grid | {500, 1,000, 2,000, 3,000, 5,000} | ✓ (l.1573) | ✓ (l.1452) | ✅ |
| Firm reduction at K1=2,000 | 88% | ✓ (l.1566, 1570) | ✓ (l.1362) | ✅ |
| Bid-row reduction at K1=2,000 | 33% | ✓ (l.1566, 1570) | ✓ (l.1362) | ✅ |
| Opens ~67% of bid rows | yes | ✓ (l.1568) | ✓ (l.1362) | ✅ |
| K1=2,000 NOT universal optimum | yes | ✓ "one operating point, not a calibrated optimum" (l.1576); "frontier, not a cutoff" | ✓ (l.1511, 1513) | ✅ |
| Recall non-monotone (peak K1≈3,000) | 0.34/0.44/0.48/0.52/0.42 | ✓ (l.1573) | ✓ (l.1444) | ✅ |

## G. Price (scope, not damages)

| Quantity | Value | Location | Verdict |
|----------|-------|----------|---------|
| Broad item-level coef | +0.064 (p=0.003) | sec07 (PDF l.2119); appendix sec_app04 | ✅ |
| Overlap-cell ATT | −0.097 (p<0.001 / p<1e-9) | sec07 (l.2120, 2128); appendix | ✅ |
| PS-trimmed | −0.307 | sec07 (l.2120) | ✅ |
| High-value tail (Q4) | +0.041 (p=0.045) | sec07 (l.2131) | ✅ |
| Direct-CADE overlap | null −0.061 (p=0.45) | sec07 (l.2132) | ✅ |
| No damages/overcharge claim | explicit negation | sec07; sec_app04 | ✅ |

---

## Result

**Inconsistencies found: 0** (target 0).

All sample counts, labels, scores, validation metrics, bid-benchmark numbers, cost-recall figures, and price coefficients agree between the main manuscript, the online appendix, and `values.tex`. The three multi-denominator situations that could read as conflicts — the **193/191/190** cobidder counts, the **two Imhof benchmark samples** (16,772-firm headline vs 11,676 legacy), and the **single-cell 0.476 vs headline 0.49** direct-defendant scope — are all explicitly defined subset/sample relationships disclosed in the relevant table/figure notes, not contradictions. No conflicting values surface in the rendered PDFs.

**Headline verdict: 0 inconsistencies.**
