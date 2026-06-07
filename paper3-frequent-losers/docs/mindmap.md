---
paper: frequent-losers
---

# Mind Map

Interactive overview of the paper's logical structure. Click and drag to explore.

!!! note "See also the [paper DAG](dag.md)"
    The canonical argument diagram is the [paper DAG](dag.md); this mind map is a
    companion overview reconciled to the current *"Cheap Signals, Costly Proof"*
    framing (v25). All numbers below are the canonical honest figures under the
    reproducible, non-circular label.

```mermaid
mindmap
  root((Cheap Signals,<br/>Costly Proof:<br/>Reach and Limits of<br/>Award-Layer Screening))
    **Institutional Setting**
      Two observability layers
        Award layer cheap and routine
        Bid layer costly forensic-recoverable
      BEC Platform
        Sao Paulo state
        2009-2019
      1.65M analysis tender-items
      41K unique firms
      Modalities Convite and Pregao
      Lei 14.133/2021
        Consolidates pregao default
    **Frequent-Loser Construct**
      Always-losers
        win rate = 0%
        16,843 firms
      IQR threshold
        median + 1.5 x IQR ~ 14
      2,735 FL firms
        Treatment: tender has >= 1 FL
      Primitive
        log(1+tenders_count)
        Binary flag is its coarsening
    **Validation Target**
      Cobidders adjudication-anchored
        651 always-loser cobidders
        341 FL / 310 non-FL (flag not used)
      NOT direct defendants
        Loser-side scope by design
    **Decomposition (the contribution)**
      Raw award-layer score
        ROC 0.761 / PR-AUC 0.143
      Mostly opportunity not conduct
        Label-blind opportunity 0.553
        Within-stratum AUC 0.471 ~ chance
        Fragile increment +0.010 p=0.013 not robust
      Armor battery anchor-agnostic
        Positive control 0.953
        Perm power 0.97 @ 0.55
        Label-frozen timing 0.713
      Direct-CADE binary AUC ~ 0.49
        Predicted null = scope signature
    **Two positive modeled objects**
      Over-crediting bias (LEAD, main body §4)
        Size-bias gap signs only
        Up in CV(T), down in base rate
        CV(T) pre-bid-file sufficient statistic
        Magnitude synthetic surface not fitted curve
      Enforcer stopping rule (modest, App. B)
        Cost-benefit MB=MC tangency
        No fixed cutoff = consequence
    **Division of labor between layers**
      Award ranks where to look
      Bid evaluates what is found
      Bid benchmark
        Bid RF 0.717 / award 0.760
        Combined PR 0.188 random-CV
        but 0.103 case-grouped (conditional)
      Cost-recall frontier
        K1=2000: firms -88% bid-rows -33%
        K1=1000 beats K1=2000 no optimal cutoff
    **Price (scope, descriptive)**
      Broad +0.064 selection into high-price cells
      Sign reversal
        Overlap-cell ATT -0.097
        Q4 only positive +0.041
      Direct-CADE price effect null
      Mechanism not identified, not damages
    **Limits (reach and limits map)**
      Retrospective among incumbents
        Strict timing ~ 0.68 in training pool
        Full-universe ROC ~ 0.474 below chance
      Single-case concentration
        One case ~ 32% of positives
        Leave-largest-out PR-AUC -37%
    **Second Platform (federal ComprasNet, §5)**
      Same audit re-run, deflation replicates
        Exp-only 0.754 >= raw 0.744
        Within-stratum 0.462 ~ chance
        Label-blind opportunity 0.611
      Partially overlapping legal anchors
        Provisional, not Confirmed
```
