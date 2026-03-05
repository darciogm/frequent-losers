# Contributions and Testable Predictions

## Paper 3 v2: Frequent Losers as Cover Bidders in Public Procurement

---

## 1. Four Contributions

### Contribution 1: Firm-Level Screening Marker
We propose **frequent losers** (FL)—firms that systematically participate in and lose public procurement tenders—as a novel firm-level screening marker for cover bidding in cartel arrangements. Unlike existing bid-level screens (Bajari & Ye, 2003; Imhof, 2019), the FL marker operates at the firm level: a single classification flags all tenders in which the firm participates. This makes the screen operationally simpler for competition authorities.

### Contribution 2: Regime 1 vs. Regime 2 Test
We empirically distinguish between two cover-bidding regimes:
- **Regime 1 (Complementary Cover Bidding):** FL firms submit non-competitive bids to satisfy minimum-bidder requirements. Their bids are deliberately high, increasing within-FL bid dispersion.
- **Regime 2 (Coordinated Cover Bidding):** FL firms submit bids calibrated to create an illusion of competition. Bids cluster near the winning price, *reducing* within-FL bid dispersion.

We test this by comparing bid price dispersion among FL vs. non-FL participants. If β(dispersion_FL) > β(dispersion_non-FL), we are in Regime 1; if the sign reverses, Regime 2.

### Contribution 3: Causal Identification
We provide causal estimates of the cover-bidding markup using two identification strategies:
1. **Callaway & Sant'Anna (2021) staggered DiD:** exploiting the first entry of FL firms into item-PBU markets as a treatment event, with never-treated markets as controls.
2. **Bajari-Ye exchangeability and conditional independence tests** applied separately to FL and non-FL bid residuals, providing direct statistical evidence of coordinated bidding.

We also validate externally against CADE (Brazilian Competition Authority) cartel convictions from 2009–2019.

### Contribution 4: Developing-Country Application
We apply these methods to the BEC (Bolsa Eletrônica de Compras) platform of São Paulo State, covering 4.5 million tender-items and 40 million bids (2009–2019). This is among the largest empirical analyses of bid rigging in a developing country, where institutional features—mandatory minimum bidder requirements, electronic auction formats—create specific incentives for cover bidding.

---

## 2. Formal Model: Cover Bidding Equilibrium

### Setup
Consider a procurement auction for item $g$ at purchasing body $k$ in period $t$. Let:
- $n$ = number of genuine (non-cartel) bidders
- $m$ = number of cover bidders (FL firms)
- $v$ = common value of the contract
- $r$ = reference price (reservation price)

### Regime 1: Complementary Cover Bidding
FL firms submit bids $b_j^{FL} = r + \epsilon_j$ where $\epsilon_j > 0$ is drawn to exceed the reference price. The designated winner bids $b^* = v + \delta$ where $\delta$ is the cartel markup.

**Predictions under Regime 1:**
- P1: FL-present tenders have higher winning prices (β > 0 on `losers`)
- P2: FL bids exhibit HIGH dispersion (drawn independently above reference)
- P3: More FL participants → larger markup (complementary effect)

### Regime 2: Coordinated Cover Bidding
FL firms submit bids $b_j^{FL} = b^* + \eta_j$ where $\eta_j$ is small and positive, calibrated to create an illusion of competition around the winning bid.

**Predictions under Regime 2:**
- P4: FL bids exhibit LOW dispersion (clustered near winning bid)
- P5: Non-FL bid residuals are conditionally independent (genuine competition)
- P6: FL bid residuals violate exchangeability (coordinated submission)

---

## 3. Mapping Predictions to Empirical Tests

| Prediction | Description | Test | Script | Table/Figure |
|---|---|---|---|---|
| P1 | FL → higher prices | Main regression: `lneg_price ~ losers \| FE` | `06_main_regressions.R` | Table 2 |
| P2 | FL → more firms/bids | Main regression: `ln_firms ~ losers \| FE` | `06_main_regressions.R` | Tables 3-4 |
| P3 | Regime test: dispersion | `dispersion_fl ~ cover_tender \| FE` vs `dispersion_nonfl` | `06_main_regressions.R` | Table 5 |
| P4 | Cover bid spread | Distribution of (FL bid - winner) / winner | `04_cover_bid_flags.R` | Figure 4 |
| P5 | Bajari-Ye: non-FL independence | KS test + pairwise correlation on non-FL residuals | `05_bajari_ye_test.R` | Table 6 |
| P6 | Bajari-Ye: FL violation | KS test + pairwise correlation on FL residuals | `05_bajari_ye_test.R` | Table 6 |
| -- | Causal ID: staggered DiD | C&S att_gt() on market-level panel | `08_did_callaway_santanna.R` | Table 8, Figure 6 |
| -- | External validation | CADE cartel match rates | `03_data_diagnostics.R` | Table 1 |
| -- | Mechanism M1: displacement | `log(n_genuine+1) ~ cover_tender \| FE` | `07_mechanism_tests.R` | Table 7 |
| -- | Mechanism M2: reference calibration | `bid_to_ref ~ cover_tender \| FE` | `07_mechanism_tests.R` | Table 7 |
| -- | Mechanism M3: reverse causality | `cover_tender ~ log_price_lag \| market_id_f + year_f` | `07_mechanism_tests.R` | Table 7 |
| -- | ML comparison | AUC-ROC: Imhof vs FL vs regime screens | `10_ml_screens.py` | Figure 8, Table 10 |
| -- | Welfare | Back-of-envelope: `(exp(β)-1) × Σ(price \| cover=1)` | `11_welfare.R` | Table 11 |
