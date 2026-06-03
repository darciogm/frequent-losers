# Cost-wedge memo (Subprompt 10, JLEO R&R v22)

Supports the institutional claim that the bid layer is costlier than the award layer — **measured as a processing/recovery footprint, not as monetary agency cost.**

## 1. Routinely observable in the award layer
Participant identity, winner identity, item code, negotiated price, procuring unit, year, modality — i.e. who appeared, who won, what was bought, where a firm repeatedly participated without winning. Computable from a routine administrative query; no case-specific recovery.

## 2. Must be recovered from LANCES for the bid layer
Per-bidder submitted offers, timestamps, and bid-revision sequences inside each tender-item. Within-tender bid moments (CV, skewness, kurtosis, spread, second-low ratio) require the **full set of bids in a tender-item**, not just the focal firm's bids — so recovering bid features for a firm means opening every tender-item that firm participated in, in full.

## 3. Why bid recovery at research scale does not eliminate agency cost
We computed bid features once for a research dataset; that does not make per-case recovery free for an agency. The relevant agency cost is the **footprint that must be opened**: firms, tender-items, bid rows, and buyer-item-year cells. The recovery, linkage, cleaning, and within-tender construction scale with that footprint.

## 4. Measured cost denominators available in the data
- **firms_opened** (survivor pool size K1).
- **survivor firm-tender-item rows** (firm_tender_map).
- **opened tender-items** = unique tender-items across the survivor pool (the recovery unit).
- **opened bid rows, full-tender** = total bids inside opened tender-items (imhof_tender_features.n_bids / bid_level_with_prices) — the realistic processing footprint.
- **survivor bid rows only** (lower bound).
- **buyer × item-group × year cells**, **unique buyers**, **unique item-groups** implicated.

## 5. Cost denominators NOT available
- LANCES export units (assumed 1 tender-item = 1 export; stated as an assumption, not observed).
- Legal/subpoena-style access requests (not observed in BEC).
- Monetary cost (reais) of recovery (not observed).

## 6/7/8. Analyst-hour proxies
Used ONLY as an **illustrative processing-burden proxy in the appendix**, never as a measured agency cost: `analyst_hours = α·opened_tender_items + β·opened_bid_rows/1000`, with low/medium/high (α,β) in a parameter block. No agency time data exist, so no measured-hour claim is made. If the proxy adds nothing beyond the raw footprint denominators, it is omitted.

## 9. How the main text SHOULD describe the cost wedge
- "Bid-layer recovery is costlier at scale because it requires extraction, linkage, cleaning, and construction of within-tender moments from the full tender-item record."
- "We measure the recovery footprint using firms, tender-items, bid rows, and buyer-item-year cells."
- "The firm-level reduction (one minus survivor pool over the full pool) overstates the saving, because survivors are high-participation firms whose tender-items account for a disproportionate share of bid rows; the tender-item and bid-row reductions are the honest processing-footprint measures."
- "Analyst-hour figures are illustrative proxies, not measured agency costs."

## 10. How the main text should NOT describe it
Forbidden unless directly supported: "prohibitive", "impossible", "subpoena cost" (no subpoenas observed), "measured analyst hours", "the agency would save X reais", "legal proof cost". Only **data-processing footprint** is measured.
