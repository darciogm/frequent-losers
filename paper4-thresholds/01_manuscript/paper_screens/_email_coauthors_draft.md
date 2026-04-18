# Draft email to Galletta + Giommoni

**To:** sergio.galletta@gess.ethz.ch, t.giommoni@uva.nl
**From:** darciogm1@insper.edu.br
**Subject:** Paper 4 pivot — stronger version, would like your read before SIOE

---

Dear Sergio, Tommaso,

Quick update on Paper 4. The contagion version we had been developing took a hit this week: robustness checks (Bartik shift-share IV, conditional-on-hiring placebo, Borusyak-Jaravel-Spiess imputation) all attenuate or eliminate the headline effect. The +5--6 pp win-rate effect is an upper bound that bundles capacity transfer with a hiring-decision selection margin. The conditional-on-hiring version drops to +1.7 pp (marginal). The price null is not informative (CI admits overcharges up to +13 log points). I was about to write to you to suggest reframing it as a descriptive paper.

Before doing that, I ran a horse race on three alternative directions and found one that is substantially stronger than what we had. I'm attaching the design draft.

**The pivot.** Instead of causal claims about what happens to firms that absorb ex-cartel workers, the paper proposes **two orthogonal fingerprints for detecting bid-rigging cartels** in procurement data, combining:

1. **Labor-network proximity** (cosine similarity of pre-conduct CBO × municipality employment vectors)
2. **Product-market overlap** (log count of items both firms bid on)

**Headline numbers** (all computed on our existing CADE × BEC × RAIS linkage with 6 convicted cartels, 34 BEC-active cartel firms, 95 within-cartel pairs, 27k non-cartel pair sample):

- Single-feature AUC: 0.70 (labor), 0.71 (overlap)
- Logistic composite leave-one-CADE-cartel-out AUC: **0.91**
- Composite generalizes cleanly to the three largest cartels (medicamentos, merenda escolar, trens metros) with per-fold AUCs of 0.83--0.86
- Composite does *not* generalize to aquecedores solares (short cartel, 1-year conduct period) — boundary condition we frame as an operating envelope rather than a failure
- Auxiliary item-level test: CADE-cartel items show winner+runner-up temporal closure of 97% vs 29% for non-cartel items, equivalent to a two-firm effective market

**Why this is a real paper, not a retreat.** The novelty is that the detection literature (Porter-Zona, Bajari-Ye, Kawai-Nakabayashi) has focused on bid-distribution signals. We propose structural firm-level fingerprints that are orthogonal to those and perform at the top end of what is publishable at RAND. The composite requires no bid values beyond participant identities, so it is immediately deployable by competition authorities on any procurement platform linked to matched employer-employee data.

**What I'd like from you.** A 30-minute read of the attached draft (21 pages without results, 29 with). Specifically:

1. Does the framing (two fingerprints, boundary condition, orthogonality argument) land for you as a RAND-quality contribution?
2. Is there anything in the design that makes you uncomfortable — especially the small cartel count and the aquecedores solares failure mode?
3. Are you OK if I prepare this for SIOE 2026 (INSEAD, July 13--15) as the Paper 4 submission, in place of the contagion version?

Happy to set up a call next week if easier than email. I will keep developing robustness checks and scripts 57+ in parallel so there's nothing you are waiting on.

The contagion draft (paper_contagion/) will be archived as `_archive/v11-contagion-abandoned` if you agree. All the infrastructure — CADE × BEC × RAIS linkage, worker flow tracking, mover characterization — is directly reused in the screens paper.

Best,
Darcio

---

**Attachments:**
- `paper_screens/main.pdf` (29 pp, design draft + preliminary results)
- `paper_screens/_research_log.md` *(optional: internal log of horse race results, if they want to see the decision process)*
