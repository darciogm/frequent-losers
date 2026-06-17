# Design memo — "The Price of a Mastectomy"

**Working title.** *The Price of a Mastectomy: Administrative Reimbursement and the
Choice of Cancer Surgery in Brazil's Unified Health System.*

**Status.** Pre-project design memo (reconnaissance complete, 2026-06-17). Not part of
paper18. Born from the DATASUS data-estate scan; see memory
`paper-ideas-datasus-portfolio`.

**One-sentence claim.** When SUS sharply corrected the under-pricing of breast-conserving
surgery in January 2013, revenue-dependent (private) hospitals shifted ~26 percentage
points of breast-cancer surgery away from mastectomy toward conservation — three times the
shift in budget-funded public hospitals — revealing that administrative prices had been
steering women toward more invasive surgery.

---

## 1. Question and contribution

Do administrative prices distort the *kind* of surgery cancer patients receive, and does
that distortion operate through provider financial incentives? We answer with the largest
public health system in the Global South, exploiting a sharp, plausibly exogenous federal
reprice of oncologic surgery.

Contribution, three layers of altitude:
1. **Empirical:** first causal evidence that fee schedules reshape cancer-surgery choice in
   a single-payer developing-country system; magnitude and welfare bite quantified.
2. **Mechanism:** the response is concentrated in revenue-dependent hospitals, isolating
   the financial channel from clinical-guideline diffusion.
3. **Policy:** under-pricing a less-invasive procedure can push patients toward
   over-treatment — a previously undocumented cost of frozen administrative tables.

Lineage: Dafny (2005) on hospital upcoding to repriced DRGs; Clemens & Gottlieb (2014) on
physician supply response to fees; Gruber & Owings (1996) on financial incentives and
C-section. New setting, new margin (the *invasiveness* of cancer surgery), new welfare
question.

## 2. Setting: the January 2013 federal oncology reprice

The federal SIGTAP table is largely frozen (avg ~10 yr without readjustment), making it a
flat baseline. In January–February 2013 a federal readjustment sharply raised prices for a
coherent block of oncologic procedures (10 procedures with persistent >30% jumps in our
scan; oncology cluster). The flagship is breast-cancer surgery (SIGTAP family 041612):

| Code | Procedure | Pre-2013 | Post-2013 | Jump |
|------|-----------|---------:|----------:|-----:|
| 0416120059 | Segmentectomy/quadrantectomy (breast-conserving) | R$207 | R$2,320 | **11×** |
| 0416120040 | Resection of non-palpable lesion | R$570 | R$1,822 | 3.2× |
| 0416120024 | Radical mastectomy + axillary lymphadenectomy | R$970 | R$2,963 | 3.0× |
| 0416120032 | Simple mastectomy | R$630 | R$2,462 | 3.9× |

These four are clinically substitutable management options for breast cancer — the surgeon
has discretion at the margin, which is what makes a coding/treatment-choice response
possible. The reprice is a discrete step at the portaria competence month (verified flat
pre, flat post; volume continuous, ruling out code redefinition).

## 3. Identification

**Source of variation.** *Not* "oncology vs rest" (confounded — see §4). The engine is the
**within-area differential reprice**: within breast-cancer surgery, the four procedures rose
by different multiples (3×–11×). Treatment dose = Δlog(federal price) by procedure. The
control margin is the relative price of one coding choice versus its substitutes.

**Estimating equations (layered).**

(a) *Coding-choice / composition (Dafny).* Hospital–month share of breast-cancer surgeries
in variant *k* regressed on the post-2013 indicator × Δlog-price of *k*, with hospital and
month fixed effects. Prediction: composition tilts toward the procedures whose price rose
most, relative to clinical fundamentals.

(b) *Cross-bucket recoding (pure upcoding).* Migration of breast surgeries from
non-oncologic codes (family 0408, general surgery) into oncologic codes (0416) after the
reprice — same operation, better-paid label. The cleanest upcoding test (no clinical-choice
story).

(c) *Supply/volume (Clemens-Gottlieb).* Procedure-level volume on Δprice. (Already visible:
quadrantectomy volume ~5× within 2013.)

**The identifying lever — ownership heterogeneity DiD.** The decisive specification
interacts the reprice with hospital ownership (public = NAT_JUR 1xxx, budget-funded;
private = 2xxx/3xxx, AIH-revenue-dependent):

```
share_quadrant_{h,t} = β·(Post_t × Private_h) + γ·Post_t + δ_h + θ_t + X_{h,t} + ε
```

β identifies the *excess* coding shift in revenue-sensitive hospitals. This is what
separates the financial channel from clinical-guideline diffusion (§4).

## 4. Identifying assumptions and threats (with defenses)

- **Parallel pre-trends.** Verified: median VAL_TOT and code shares are flat through all of
  2012, then step in 2013. Event-study around the competence month is the formal check.
- **⚠️ Lei 12.732/2012 ("60-day cancer law", effective ~May 2013 — cite to verify).** A
  simultaneous treatment-timing mandate. *Defense:* it affects all oncologic codes equally,
  so the within-area differential and the ownership interaction net it out; it cannot
  generate a price-graded or ownership-graded coding shift.
- **Clinical-guideline shift toward conservation.** Breast-conserving surgery is the
  recommended direction. *Defense (already in the data):* guideline diffusion predicts
  *public/academic* hospitals leading; we observe the **opposite** — private hospitals shift
  3× faster. The ownership gradient has the wrong sign for the guideline story and the right
  sign for the financial one.
- **Case-mix/severity.** Were 2012 private patients genuinely sicker (justifying more
  mastectomy)? *Defense:* hospital FE + severity controls (age, ICD detail, comorbidity
  proxies, in-hospital death); the abrupt one-year shift coincident with the price step is
  hard to attribute to gradual case-mix change.
- **Relabeling vs real over-treatment.** Private volume nearly doubled 2012→2014, so it is
  not pure relabeling. *Test:* decompose total-volume growth (supply/60-day law) from
  within-patient composition (treatment choice); the welfare claim rests on the composition
  margin.

## 5. Data (all already held)

- **SIH-RD** (`02_data/raw/sih_rd/`, AIH-level, 2008–2025): PROC_REA, VAL_TOT/VAL_SH/VAL_SP,
  DIAG_PRINC, CNES, NAT_JUR (ownership), competence year/month, MUNIC_MOV/RES, MORTE.
- **SIGTAP** historical monthly tables (download per competence for exact federal price path;
  current snapshot already parsed).
- **CNES**: hospital ownership, type, beds (cross-check NAT_JUR).
- **SIM**: municipal breast-cancer mortality (ecological only — SIH has no patient ID for
  individual survival linkage; honest limitation).

## 6. Outcomes and the welfare question

Coding composition → procedure volume → invasiveness (mastectomy vs conserving rate) →
reimbursement captured → (ecological) cancer mortality. The headline welfare question:
*were women receiving disfiguring mastectomies instead of breast-conserving surgery because
conservation was under-priced?* If the ownership-graded shift survives severity controls,
the answer is plausibly yes — a striking, citable result.

## 7. Preliminary evidence (this session's probes, raw)

Breast-cancer surgery composition, % of family 041612, by ownership × year:

| Ownership | Year | n | Radical mast. | Quadrantectomy | mean VAL_TOT |
|-----------|------|--:|--------------:|---------------:|-------------:|
| Private | 2012 | 8,671 | 58.9 | 9.5 | 862 |
| Private | 2013 | 14,466 | 38.2 | 35.8 | 2,382 |
| Private | 2014 | 16,039 | 33.5 | 39.3 | 2,417 |
| Public  | 2012 | 4,556 | 51.5 | 23.2 | 720 |
| Public  | 2013 | 4,849 | 54.1 | 26.6 | 2,472 |
| Public  | 2014 | 5,278 | 44.7 | 35.7 | 2,528 |

Private quadrantectomy share +26pp (2012→2013) vs public +3pp; private dropped radical
mastectomy 58.9→33.5% once conserving surgery was paid. Descriptive, uncontrolled — the
formal DiD, severity controls, and relabeling decomposition are the actual paper.

## 8. Falsification / what would kill it

- Ownership gradient vanishes with hospital FE + severity → guideline/case-mix story, not
  price; Dafny angle dies (Clemens-Gottlieb volume result may survive, weaker).
- Placebo: frozen-price surgical families (no 2013 jump) should show no composition break.
- Donut/period placebo around a fake 2011 or 2015 reprice date → null expected.

## 9. Target journals and framing

If the ownership-graded coding/treatment shift holds with controls and the welfare
interpretation (price-induced mastectomy) survives: swing at **top-5** (AER/QJE) on the
welfare hook. Solid fallback: **AEJ:Economic Policy / Journal of Public Economics / RAND**.
Frame as provider response to administrative prices with a treatment-invasiveness welfare
margin, not as "Brazil descriptive."

## 10. Timeline and relationship to paper18

This is a *new* project competing for time with paper18 (ETH/UZH deadline 2026-05-08). Order
of operations once greenlit: (1) build AIH-level breast-surgery panel 2008–2016 with
severity + ownership + hospital FE; (2) formal event-study + ownership DiD; (3) relabeling
decomposition; (4) placebos; (5) cross-bucket recoding; (6) extend to the full 2013 oncology
cluster (cervical, bladder, leukemia) for external validity. Steps 1–2 are ~1–2 weeks; a
credible JMP-grade draft is a one-quarter project.

## 11. References

Verified this session:
- Dafny, L. S. (2005). "How Do Hospitals Respond to Price Changes?" *American Economic
  Review* 95(5): 1525–1547.
- Clemens, J. & Gottlieb, J. D. (2014). "Do Physicians' Financial Incentives Affect Medical
  Treatment and Patient Health?" *American Economic Review* 104(4): 1320–1349.

To verify before citing (⚠️ do not assert until checked):
- Gruber, J. & Owings, M. (1996). Physician financial incentives and cesarean delivery —
  believed *RAND Journal of Economics* 27, but confirm.
- Lei nº 12.732/2012 (60-day cancer-treatment law) — confirm number and effective date.
- Einav, Finkelstein & Mahoney on long-term-care-hospital upcoding — confirm venue/year.
- The exact 2013 SIGTAP portaria number and competence month of the oncology reprice.
