# S7 — Manuscript outline (framework rewrite)

Outline completo do manuscript reescrito sob a frame **"framework
metodológico para identificação causal de choques de acesso à saúde via
patient-flow network embeddings"**. Application: fechamentos hospitalares
no Brasil 2010-2024.

Decisões de escopo já fechadas (sessão de 2026-04-28):
- Submissão dual track: AI+Econ workshop (~ago 2026) → JHE working paper (~set 2026)
- Framework-of-2-elements (decision gate): patient-flow embedding + causal
  forest heterogeneity. R2 (counterfactual perturbation) entra como
  apêndice/robustness, R4 (TGN) e R5 (DML) descartados.
- Reframe principal: **"we propose a framework"** (não "we estimate an
  effect"). Empirical é validation case.

---

## Title (fechado 2026-04-28)

> **Who Is Exposed? Patient-Flow Embeddings, Hospital Closures, and the
> Care-Substitution Channel**

Justificativa: pergunta-título (Athey-style) telegrafa o problema
metodológico que o paper resolve — quem é tratado quando um hospital
fecha? "Care-Substitution Channel" sinaliza o achado substantivo
distinguindo de geographic-substitution (Avdic 2016, Carroll 2019).

---

## Estrutura proposta — ~38-45pp para JHE, com versão extended-abstract de
~10pp para o workshop AI+Econ

### §1 Introduction (4-5 pp)

Estrutura em 5 movimentos, cada parágrafo com função explícita.

**§1.1 — The motivating problem**
Healthcare access measurement relies on geographic proximity (km, OSRM
travel-time). But patients traverse the hospital network through referrals,
informal flows, and modes that road geography ignores (river, air,
specialty referrals). Observation: ~half of Brazilian municipalities have
embedding-revealed access that materially diverges from km-based access.
This matters for any causal study of access shocks.

**§1.2 — The methodological gap**
Existing closure studies (Avdic 2016 JHE, Carroll 2019, Joynt-Maddox)
define "exposed" municipalities by geographic proximity to the closing
hospital. This implicitly assumes geographic distance proxies actual
care-seeking behavior. We show this assumption fails empirically: 196
municipality-closure pairs in our sample are km-exposed but the embedding
reveals zero patient flow to the closing hospital (false positives), and
97 are embedding-exposed despite having other geographically-closer
hospitals (false negatives that km-based identification misses).

**§1.3 — The framework**
We propose a methodological framework for causal identification of
healthcare access shocks that integrates:
1. **Patient-flow embedding as exposure definer**: a node2vec embedding of
   the bipartite municipality-hospital graph identifies which municipalities
   actually depend on a given hospital (E1), independent of geographic
   distance (E2 placebo).
2. **NLP-documented exogeneity**: zero-shot LLM classification (Claude
   Sonnet 4.6) of closure motives via Receita Federal CNPJ status + web
   sources documents the exogeneity of each closure event, addressing
   the demand-driven exit confounder that filtering on admission-decline
   ratios cannot rule out.
3. **Causal forest heterogeneity**: ML-driven attribution of effect
   heterogeneity to pre-treatment municipality characteristics
   (Athey-Wager 2019).
4. **Counterfactual graph perturbation** (apêndice): re-estimating the
   embedding with the closed hospital removed quantifies topological
   perturbation as continuous treatment intensity, validating the binary
   exposure definition.

**§1.4 — Application + headline finding**
We apply the framework to all SUS hospital closures in Brazil
2010-2024 (60 exogenous closures after multi-stage filtering and NLP
documentation). Main finding: a **two-channel substitution effect**:
- Channel A — General hospital closures: travel burden rises +2.9 km
  (Avdic-Carroll canonical pattern), N=24 (under-powered, exploratory)
- Channel B — Specialized hospital closures (n=105 treated munis): travel
  burden falls −7.1 km because patients stop seeking specialized care,
  and ICSAP rate rises +1.5 per 1,000 (preventable hospitalizations),
  reflecting care-substitution rather than commute-substitution.

The patient-flow embedding identifies channel B with magnitude 50%
greater than km-based exposure (placebo E2). NLP-documented mechanism is
predominantly Reforma Psiquiátrica + SUS-induced insolvency (administrative
motive, n=30, ATT travel −5.2 km, ICSAP +0.83).

**§1.5 — Contribution and roadmap**
We make four contributions:
- *Methodological*: a framework that is replicable for any large-N
  hospital closure context worldwide where SIH-equivalent admission data
  exists (ICD/DRG payer claims).
- *Substantive*: documentation of the care-substitution channel, distinct
  from geographic-substitution, and the magnitude by which km-based
  exposure misclassifies it.
- *Empirical*: ATT estimates for travel burden and ICSAP under multiple
  identification strategies (Sun-Abraham staggered DiD, Causal Forest ATE).
- *Replication infrastructure*: open-source pipeline (~33 scripts), plus
  CNPJ + LLM classification cache for reproducibility.

---

### §2 Institutional setting (2 pp — keep brief)

**§2.1 — SUS regionalization architecture**
- 5,570 municipalities, 438 Health Regions (CIR), 27 UFs
- Hub-and-spoke financing via PAB-fixo + procedure-specific reimbursements
  (FAEC, MAC)
- Regionalization is *prescribed* but not *enforced*: patients are free to
  cross municipal boundaries. Cross-border flows are the empirical opening
  for the embedding to outperform km-based proxies.

**§2.2 — Reforma Psiquiátrica (Lei 10.216/2001)**
- Critical for understanding the closure sample: 84% of our specialized-
  closure exposures are psychiatric hospitals being deinstitutionalized
- Federal de-accreditation policy + frozen SUS daily reimbursement values
  drove insolvency at the institutional level
- The closures are exogenous to local healthcare demand because the
  policy is national, not municipal

**§2.3 — Hospital closure events 2010-2024**
- Primary administrative source: CNES (Cadastro Nacional de
  Estabelecimentos de Saúde)
- 3,518 raw "closures" detected (CNES that stopped reporting); after
  filtering for hospital-grade facilities, ≥30 SUS beds, ≥100 AIH/year,
  and non-demand-driven exit, we identify 60 exogenous closures
- NLP classification documents motive: 30 administrative (Reforma Psiq +
  descredenciamento), 11 falência (CNPJ baixada), 10 fiscal (CNPJ inapta)

---

### §3 Data (3-4 pp)

**§3.1 — SIH-RD (Sistema de Informações Hospitalares — Reduzido)**
- Universe: 179.5M public hospital admissions (AIH), 2010-2024
- Bipartite graph: 5,588 municipalities × ~7,000 active SUS hospitals
- ~496k weighted edges (CNES, codmun_residente, year, n_internacoes)
- Outcome variables: travel burden (weighted km from residence to hospital
  used), ICSAP rate (Portaria MS 221/2008), AMI in-hospital mortality
  (recipient-side, contornando SIM cross-border)

**§3.2 — SIM (Sistema de Informação sobre Mortalidade)**
- 18.7M deaths 2010-2023; amenable mortality (Nolte-McKee/OECD 2019) +
  cause-specific (AMI, stroke, sepsis, maternal, perinatal)
- *Honest disclosure*: cross-section regressions on SIM-residency outcomes
  yield null (11/11 specs); attributed to under-reporting + cross-border
  recording. Apêndice C documents this with R99-fraction tests.

**§3.3 — CNES + cnes_lt (leitos)**
- Establishment × month panel
- Bed counts (QT_SUS) for closure-filter porte criterion
- CNPJ field for Receita Federal lookup → CNPJ classification
  (BAIXADA/INAPTA/ATIVA → exogeneity priors)

**§3.4 — Auxiliary**
- IBGE municipality population estimates 2015-2025
- IBGE municipality GDP 2010-2023
- IBGE municipality centroids (lat/lon) for haversine distance computation

**§3.5 — NLP / web sources**
- BrasilAPI for CNPJ → razão social, situação cadastral
- WebSearch (Anthropic Claude Code tool) for Q1+Q2 queries per CNES
- Claude Haiku 4.5 for v1 classification, Claude Sonnet 4.6 for v2 with
  web snippets
- Cache: SQLite for idempotência

---

### §4 Framework methodology (10-12 pp — DENSO)

Esta é a §-centro do paper. Cada subsection introduz um elemento do
framework com definition + estimation algorithm + identification
assumptions.

**§4.1 — Patient-flow embedding (E1)**
- Bipartite graph G = (M ∪ H, E) com M=municípios, H=hospitais, peso w_mh
  = #internações
- TF-IDF normalized projection A_MM = D_row^{-1} A · diag(idf) · ...
- node2vec random walks sobre A_MM symmetrized + top-K thresholded
- Hyperparams: dim=128, walk_length=20, num_walks=10, p=q=1, window=10,
  epochs=5, seed=42
- *Stability robustness* (apêndice): 5-seed stability, Pearson(emb_dist,
  km_dist)=0.30, Spearman=0.21
- Exposure definition E1: município m é tratado se share_mh ≥ 0.05
  (5% das AIH de m vão para h fechado no ano pré-fechamento)

**§4.2 — Comparison exposure (E2 placebo)**
- E2: município m é km-exposto se hospital h fechado está entre top-3
  vizinhos km-haversine
- Crucial: o paper é sobre **identificar quando E1 e E2 divergem**
- Em nossa amostra: 97 munis E1-only, 196 E2-only, 44 ambos, 5,309
  controles puros (universo 5,565 munis com embedding + centroide)

**§4.3 — Closure exogeneity via NLP**
- Filter F1-F5 estatístico: 60 sobreviventes
- Classification:
  - v1 (Haiku, metadata-only, n=90 with F5_recovery_candidates also)
  - v2 (Sonnet + web snippets, anti-hallucination protocol)
- Output: motivo ∈ {administrativo, fiscal, falência, fusão, demanda,
  pandemia, outros, unknown} + confidence 1-5 + evidence_flags +
  reasoning + URLs
- Filter F6: motivo ∈ {admin, fiscal, falência} → 51 closures NLP-
  documented as exogenous
- Pattern emergente: insolvência por congelamento de tabela SUS é o
  mecanismo dominante (não demanda local) → reforço de exogeneidade

**§4.4 — Staggered DiD (Sun-Abraham 2021 / Callaway-Sant'Anna 2021)**
- y_it = ∑_{e ≠ -1} δ_e · 1{rel_t == e} + α_i + γ_t + ε_it
- Cohort-specific ATT(g,t) aggregated
- Cluster-robust SE no nível município
- Pre 5 anos, post 5 anos
- Pandemia 2020-2021 incluída (pandemic gap robustness mostra resultados
  idênticos sem)

**§4.5 — Causal Forest heterogeneity (Athey-Wager 2019)**
- Cross-section first-difference: Y_m = mean(2018-23) - mean(2010-15)
- Treatment W_m = E1 ever-treated em [2012, 2018] cohort
- Features X: iso_emb, iso_km, divergence_z, log_pop, log_pib,
  R99_fraction, UF dummies
- num.trees = 4000, honesty = TRUE, seed 42
- Output: ATE + variable importance + CATE plots + Best Linear Projection

**§4.6 — Counterfactual graph perturbation** (apêndice metodológico)
- Para cada (h_fechou, year_pre): re-treinar embedding sem h
- Métrica: Jaccard(top-K vizinhos baseline, top-K vizinhos perturbed)
- Noise floor via 4 seeds baseline; signal = intra_baseline_jacc -
  vs_perturbed_jacc
- *Achado honesto*: 8.2% das (m,h) pairs significantes (z > 1.96), mas
  thresholding marca >98% dos munis como tratados → método valida o
  conceito mas é difuso para definir tratamento; mantém-se como auxiliar.

---

### §5 Results (6-8 pp)

**§5.1 — Cross-section divergence diagnostic (1 pp)**
Tabla regional + mapa divergence (Figure 1: divergence map Brasil)
- Mapa de divergence em 5,565 munis
- North negative (rio/ar > km mente positivamente)
- NE/sertão positive (km mente negativamente)
- South calibrated (benchmark)
- Cross-section R² regressions (apêndice C, Table C.1): 11 specs null →
  serve to motivate the causal turn

**§5.2 — Two-channel substitution effect (Main results, 2 pp)**

Tabela principal 1 (Sun-Abraham F5_main, 60 closures × 2 outcomes × 2
exposures):
| Outcome × Exposure | E1 (embedding) | E2 (km, placebo) |
|---|---|---|
| Travel burden (km) | **−5.84*** (1.72) | −3.63*** (0.69) |
| ICSAP per 1k | +0.77 (0.60) | −0.40 (0.48) |

Event-study plots (Figure 2): travel × E1, travel × E2, ICSAP × E1,
ICSAP × E2. Pre-trends limpos em E1; E2 com pre-trend ICSAP negativo
(placebo invalidation).

Heterogeneity por tipo (apêndice): tp_unid=05 (geral) → travel +2.9,
tp_unid=07 (especializado) → travel −7.1, ICSAP +1.5.

**§5.3 — NLP-documented robustness (1 pp)**

Tabela 2 (F6_v2, 51 NLP-documented closures):
| Outcome × Exposure | E1 | E2 placebo |
|---|---|---|
| Travel burden (km) | **−4.31*** (1.34) | −3.92*** (0.72) |
| ICSAP per 1k | **+1.18** (0.60)* | +0.41 (0.41) |

Convergência F5 → F6_v2: ATTs mantêm direção e magnitude, validando
exogeneidade. ICSAP fortalece em F6_v2 (+1.18 vs +0.77) — quando
restringimos para closures NLP-documentadas como administrativas.

**§5.4 — Heterogeneity by closure motive (1 pp)**

Figure 3 (event-study by motive — admin, falência, fiscal):
- Administrativo (n=30): driver dominante, Travel −5.24***, ICSAP +0.83
- Falência (n=11): null em ambos → mecanismo só opera quando hospital
  era functional, não residual
- Fiscal (n=10): underpowered

**§5.5 — ML heterogeneity attribution (1 pp)**

Figure 4 (Causal Forest CATE plots):
- ATE travel: −2.98 (SE 1.82) — direção consistente, magnitude
  underestimated por causa do first-difference cross-section
- Variable importance: log_pib (38%), divergence (16%), log_pop (13%),
  iso_km (10%), iso_emb (8%)
- CATE highest em munis com high divergence_z + low log_pib (poor
  miscalibrated areas)

**§5.6 — Embedding stability + perturbation validation** (1 pp, apêndice)
- 5-seed stability: Pearson within-seed 0.95+
- Perturbation: 8.2% pairs significantly perturbed; method validates
  topological signal; not granular enough for binary exposure
  redefinition

---

### §6 Robustness (3-4 pp — bateria S6)

**§6.1 — Alt thresholds θ_emb ∈ {0.01, 0.05, 0.10, 0.25}**
**§6.2 — Sun-Abraham vs Callaway-Sant'Anna vs Borusyak-Jaravel-Spiess**
**§6.3 — Excluir capitais**
**§6.4 — Excluir Norte/Nordeste**
**§6.5 — Pop_min ∈ {10k, 20k, 50k}**
**§6.6 — Pandemic gap excluded vs included** (já feito no piloto)
**§6.7 — Counterfactual perturbation as alt exposure** (R2)

Each as a one-paragraph subsection with single line in Tabela A.X
(apêndice).

---

### §7 Discussion (3 pp)

**§7.1 — Why the cross-section is uninformative**
Substantive interpretation of the 11/11 cross-section nulls (R99 +
cross-border + UF-collinearity). Honest narration. Motivation for the
within-municipality CS21 / staggered SA approach.

**§7.2 — Care-substitution mechanism**
The two-channel finding: general closures drive geographic substitution
(canonical Avdic), specialized closures drive care substitution. Theory:
specialized care has lower elasticity of substitution to geographic
proximity but higher elasticity to channel availability. Patients with
psychiatric or oncologic needs, when their tertiary referral hospital
closes, do not commute farther — they exit care entirely (presenting
later as ICSAP).

**§7.3 — Generalizability of the framework**
Framework is replicable for any context where:
- Bipartite patient-hospital data exists (ICD / DRG / payer claims)
- Closure or shock events with quasi-experimental nature
- Heterogeneity-of-mechanism is suspected

Examples in literature where this could be applied: US Medicare hospital
closures (2000-2020 panel), UK NHS specialist trust reorganizations,
French regional hospital network reforms.

**§7.4 — Limitations**
- N=60 closures: borderline power for fine heterogeneity (canal A com
  n=24 tratados em F5)
- SIH only: SUS-billed flows; private flows missing in high-private-
  penetration states
- Approximação município-a-município nas distâncias (em vez de
  hospital coords reais — limitação dataset CNES)
- LLM classification: 38/90 ainda unknown; web sources não cobrem
  CNES sem CNPJ válido (16 cases)

**§7.5 — Policy implications** (curtas, contidas)
- SUS regionalization formal hierarchy é heterogeneously aligned com
  fluxos reais
- Recomendação metodológica: estudos de access-to-care no SUS devem
  usar exposure embedding-based, não km
- Contraindicação: km não é suficiente para identificar municípios
  afetados por fechamentos de especialidade

---

### §8 Conclusion (1 pp)

Closure recap em 4 frases: (1) framework proposto; (2) two-channel
finding em closures brasileiros; (3) NLP+CausalForest as integral
pieces; (4) reproduzibilidade e generalizabilidade.

---

### Appendices (~10-15 pp)

**Apêndice A — Data construction details**
Pipeline numerado, scripts, hyperparams.

**Apêndice B — Closure filter detail (F1-F6)**
Tabela de N sobreviventes por filtro.

**Apêndice C — Cross-section diagnostic**
- 11 specs null tabulated (amenable, 5 cause-specific SIM, 5
  alternative outcomes from SIH-RD)
- R99 hypothesis test (script 15)
- divergence map + tabela regional + UF ranking
- t-SNE/UMAP embeddings vs region

**Apêndice D — NLP classification protocol**
- Prompts (system + user) full text
- Cohen κ validation (15-sample human-in-the-loop) — pendente
- Distribuição de motivos por tp_unid + status
- Web-source URLs (~150 documents linked)

**Apêndice E — Counterfactual perturbation method**
- Algorithm
- Noise baseline procedure
- Distribution + threshold sensitivity
- Limitations + descartado como exposure-definer principal

**Apêndice F — Causal Forest details**
- Hyperparams
- Best Linear Projection full output
- Variable importance ranking complete
- CATE plots por feature

**Apêndice G — Robustness battery**
- Alt thresholds, regions, pop_min, alt staggered DiD estimators

**Apêndice H — Replication notes**
- Stack: Python 3.11 + R 4.5
- Pipeline numerado scripts/00→33
- environment.yml frozen
- Cache locations
- ANTHROPIC_API_KEY required for re-classification (cached otherwise)

---

## Como o outline serve aos dois tracks

**AI+Econ workshop (extended abstract, ~10pp)**:
- Compress §1 + §4 + §5 (4-5pp main text)
- 1 figura central (event-study main + heterogeneity by motive)
- Apêndice mínimo (data + framework algorithms)
- Audience-fit: "framework integrating ML measurement + causal
  identification" — exactly the workshop sweet spot

**JHE (full paper, 38-45pp)**:
- Estrutura completa acima
- Heavy method section (§4 ~ 10-12pp)
- Heavy robustness (§6 + apêndices)
- Audience-fit: causal identification with ML auxiliaries + clear
  policy lens

---

## Próximos passos pós-outline (S7 → S6 → S8)

1. **S6 robustness battery completa** (próxima sessão de código). Roda
   §6.1-§6.6 em paralelo. ~1-2 dias.
2. **S8 audit references**. Toda referência verificável via DOI +
   anti-hallucination protocol. ~1 dia.
3. **S7.b drafting**. Após S6 + S8, escrever cada subsection em ordem.
   Começa por §1 (intro) que é a venda do paper. Cada draft passa por
   revisão `/rev` antes de finalizar.
4. **S9 self-review**. Após draft completo, parecer mr-hospital sob
   modo /rev.
5. **S10 replication package + submissões**.

---

## Decisões pendentes que outline expõe e o autor precisa fechar

1. **Title final** — entre as 3 opções listadas, qual?
2. **Workshop específico** — AI+Econ workshop generic ou ETH/UZH? (we
   abandoned ETH/UZH 8-mai deadline, so re-evaluate)
3. **Coautoria** — current sole-authored. Bring Galletta/Giommoni? Ou
   reach out para um health-econ specialist (e.g., Avdic, Carroll) para
   collab no JHE track?
4. **Apresentação de R2 perturbation** — apêndice E "validated but
   discarded" ou cortar completamente?
5. **§7.5 policy implications** — qual densidade? Mínimo (1 parágrafo)
   vs expandido (4 parágrafos)?
