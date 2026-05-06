# The Paper

## Sanctions without Markups: Sourcing as the Margin of Bureaucratic Inefficiency

**Authors:** Darcio Genicolo-Martins and Paulo Furquim de Azevedo
**Affiliation:** Insper Institute of Education and Research, Sao Paulo, Brazil
**Version:** May 2026 (JPubE Short paper, v8 sourcing-reframe)

!!! abstract "Download"
    The latest PDF lives at `v8-sourcing-reframe/manuscript/paper/main.pdf` in the repository.

---

## Question

When mandates secure compliance, what efficiency does the state forgo? In Brazil, courts compel state governments to purchase specific medications when patients win right-to-health lawsuits. Compliance is enforced through personal fines, civil liability, and asset seizure on procurement officials who fail to deliver---but no analogous penalty attaches to officials who deliver at high prices. The result, in São Paulo alone, is roughly **\$300M of pharmaceutical purchases per year subject to a one-sided accountability regime**.

Two theoretical predictions about how this regime distorts procurement diverge:

- **Standard accountability models** (Prendergast, 2007) predict suppliers extract delivery-risk premia from sanctioned officials.
- **Passive-waste accounts** (Bandiera, Prat & Valletti, 2009) predict the buyer's sourcing pattern shifts.

The two are observationally equivalent in cross-buyer data. We resolve the horse-race with a within firm-buyer-item test.

---

## Contributions

1. **Conceptual: which margin cedes under one-sided accountability.** The cross-buyer literature cannot separate within-firm pricing from equilibrium supplier selection. Holding the supplier–buyer match fixed, the within firm-buyer-item triple isolates sourcing under fragmentation as the empirical signature of accountability-induced inefficiency. The headline finding is the *absence* of a within-firm markup in deep markets, not its presence.

2. **Timeline compression as a procurement-cost driver.** Whereas Coviello, Mariniello & Spagnolo (2018) document timeline *extension* as a procurement cost driver, we identify timeline *compression* under sanctions as an alternative channel, with the cost concentrated where demand aggregation matters most.

3. **Engaging recent demand-aggregation evidence.** The finding directly engages JPubE work on group purchasing in health (Lin & Wang, 2025), which identifies the same demand-aggregation lever we find compromised by court mandates.

---

## Headline Findings

| Object | Estimate |
|--------|----------|
| Selection-corrected "under-the-gun" gap (Manski-Lee bounds) | **[15.9%, 21.1%]** |
| Within firm-buyer-item Admin coefficient | β̂ = 0.035, SE = 0.041 (NULL) |
| Sourcing shift: modal winner differs across regimes | **70.2%** of item-buyer pairs |
| Demand fragmentation: admin orders larger than litigated | **~3.3×** |
| Bounded annual welfare cost | **\$27.8M** on \$300M of litigated spending |
| Placebo on never-litigated items | economically and statistically zero |

The deep-market within-firm null is the central finding; a thin-market sanction premium reappears on subsamples where the incumbent has fewer alternatives, consistent with delivery-risk pricing exactly where the literature predicts it should bite.

---

## Institutional Background

Brazil's universal public health system (SUS) provides free access to pharmaceuticals listed in official formularies. When patients cannot obtain medications through regular channels, they may file lawsuits compelling the government to purchase and deliver specific drugs. These court orders create a distinct procurement channel---**litigated purchases**---that operates under tight judicial deadlines and personal liability for procurement officials.

The São Paulo state government conducts pharmaceutical procurement through its electronic platform (BEC), which records all transactions at the bid level. Within urgent demand, two channels coexist:

- **Litigated purchases:** Procurement compelled by court orders. Failure to deliver triggers personal fines, civil liability, and asset seizure on the procurement officer.
- **Administrative urgent purchases:** Procurement authorized by the SES/SP scientific committee. Same compressed timelines, same small quantities, same diverted budget, same auction procedures on BEC. **Failure to deliver under this channel triggers nothing.**

To our knowledge, no other Brazilian state operates a comparable dual channel for urgent pharmaceutical demand. This institutional asset is what allows the under-the-gun (UTG) contrast to identify the sanction channel net of urgency.

---

## Identification Asset

The selection-corrected UTG gap is identified within urgent pharmaceutical demand by:

1. **Manski-Lee monotone bounds** on selection into the administrative channel (the SES/SP scientific committee admits items that would have been cheaper under any regime; the Lee bound corrects for this wedge).
2. **Within firm-buyer-item triples** observed under both regimes (1,206 triples, 4,573 observations) — same firm, same item, same buyer, both regimes — that hold the supplier–buyer match fixed and isolate the price channel.
3. **Wild cluster bootstrap** on the preferred-FE Admin coefficient (999 Rademacher replicates).
4. **Borusyak-Jaravel-Spiess event study** with **Rambachan-Roth honest-sensitivity** overlay (Appendix).
5. **Placebo** on items never subject to litigation: the urgency premium exists only inside the litigation pool.

---

## Data and Sample

The analysis uses bid-level data from the **Bolsa Eletrônica de Compras** (BEC), São Paulo state, covering all pharmaceutical procurement transactions by SES/SP from January 2009 through December 2019.

| Feature | Description |
|---------|-------------|
| **Source** | BEC, São Paulo state (mandatory for common goods since 2007) |
| **Coverage** | All bids for pharmaceutical purchases (Group 65) |
| **Period** | January 2009 -- December 2019 |
| **Observations** | 479,330 purchase-offer-item observations |
| **Unit of observation** | Firm × item × procurement event |
| **Key outcomes** | Negotiated price, reference price, quantity, number of bidders, tender success |
| **Treatment contrasts** | Litigated vs Ordinary; **Litigated vs Administrative (UTG)** |

---

## Software and Estimation

- **Primary analysis:** R 4.5 with `fixest` (`feols`, `setFixest_nthreads`), `did`, `csdid` (BJS event study), manual Rademacher wild cluster bootstrap, manual Manski-Lee bound computation.
- **DuckDB** for parquet I/O on BEC and joined data.
- **`HonestDiD`-style** sensitivity bound implemented manually (the package was blocked by `CVXR`/`clarabel` system deps in this environment).
- **Macro discipline:** every numerical claim, table input, and figure path resolves through `values.tex`, regenerated by the producing R script. No hardcoded numerals in the manuscript.

---

## Policy Lever

**The policy lever is demand aggregation, not contract design.** Two reforms address the two channels we identify:

- **Demand side:** Expanding the administrative-request mechanism eliminates within-urgent sanction exposure for the admissible share. Because the within-firm pricing component is zero, the gain is realized through demand aggregation; the binding parameter is committee capacity, not legal reform.
- **Supply side:** Framework agreements for repeat-purchase commodity-like medications address fragmentation directly by allowing aggregation across urgent and ordinary requests. We do not attach a recovery point estimate to the supply-side channel.

**Delivery is guaranteed; sourcing efficiency is the bill.**
