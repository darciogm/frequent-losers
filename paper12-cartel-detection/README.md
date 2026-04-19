# Paper 12 — Cartel Detection: Network-Based Screening with External Validation

**Status.** Semente. A pré-calibração (2026-04-18) coloca probabilidade top-5 em 3–8%; venue realista RAND / IJIO / AEJ:Micro.

---

## Pergunta central

Podemos detectar cartéis em procurement *antes* de investigação formal pela CADE, usando a combinação de (i) redes de cobidding, (ii) fluxos de trabalhadores entre firmas, e (iii) screens estatísticos sobre bids? E qual o custo de bem-estar dos cartéis detectados — preço excessivo pago, dissuasão de entrada, deadweight loss?

Reformulação estrutural: *qual fração dos leilões brasileiros de procurement tem assinatura de cartel, e qual a elasticidade dessa prevalência a intensidade de enforcement (dawn raids, leniência)?*

---

## Identificação base

**Dois braços complementares, conectados via structural markup model.**

**Braço (a) — Detecção supervisionada com ground truth.**
- Training set: firmas e processos vinculados a casos CADE condenados (ground truth positiva) + casos TJSP APN licitação (ground truth positiva secundária) + matched controls (ground truth negativa).
- Features: (i) screens de bids (Imhof 2018, Harrington 2005 CV, bid rotation), (ii) network features (cobidding density, worker flow centrality), (iii) timing features, (iv) firma-level shell-firm scores.
- Modelo: XGBoost + Graph Attention Networks (comparação; Imhof-Viklund-Huber 2025 é estado-da-arte).

**Braço (b) — Validação causal via leniency / dawn raid shocks.**
- CADE publica datas de acordos de leniência e buscas-e-apreensões. São eventos exógenos de revelação.
- Event study: firmas da mesma cartel community (detectadas pelo classificador mas *não* diretamente investigadas) têm shift de comportamento pós-raid?
- Placebo: comunidades de tamanho/CNAE similar, não conectadas via cobidding/worker-flow.
- Se placebo é nulo e tratamento é significativo → validação externa do classificador.

**Braço (c) — Welfare structural.**
- Modelo de leilão com bidder heterogeneity (Asker 2010, Kawai-Nakabayashi 2022).
- Estimar markup contrafactual sem cartel para leilões classificados.
- Agregar fiscal cost anual de cartéis detectados.

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| `cade_cartel_processes.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `cade_ground_truth.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `firm_firm_cobidding_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `firm_firm_worker_flow_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `auction_screens_convite.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `auction_screens_pregao.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `df_{convite,pregao}_with_cartel_flags.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `Firms_final.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| Casos APN licitação TJSP | `paper6-procure/build/clean/court_case.parquet` (subset assunto licitação) | Pronto |
| Dawn raid / leniência dates CADE | — | **Precisa construir** (webscrape CADE) |

Infraestrutura de redes está **pré-construída** — pular direto para feature engineering.

---

## Caminhos possíveis

### Caminho A — Classificador + benchmarks (RAND / IJIO)
- Treinar XGBoost e GAT separadamente.
- Comparar com Imhof-Viklund-Huber (2025) baseline.
- Out-of-sample AUC, precision@k, recall em casos CADE held-out.
- Publicar classifier como contribuição metodológica.
- **Teto realista**: IJIO / RAND.

### Caminho B — Causal validation via leniency (AEJ:Micro / AER stretch)
- Raspar CADE para datas de dawn raid, leniência, TCC.
- Event study firmas-não-investigadas-mas-detectadas vs. placebo.
- Se causal identification for limpa, contribuição é **duas camadas**: (i) detection method, (ii) validation framework.
- **Precedente**: Chassang-Ortner (Ecta 2023) sobre equilibrium cartel detection theory. Kawai-Nakabayashi (AER 2022) empirical cartel detection + structural.
- **Teto realista**: AER se causal + structural bem executado.

### Caminho C — Welfare structural (AER / Ecta stretch)
- Modelo de leilão Kawai-Nakabayashi (2022) adaptado: bidders cartel vs. bidders honest.
- Estimar markup, deadweight loss, entry deterrence.
- Counterfactual: valor de aumentar detecção em X%.
- **Teto realista**: AER se estrutural for econometricamente defensável.
- **Risco**: referee estruturalista pede modelo mais completo (seleção de leilão por cartel, entry equilibrium).

### Caminho D — Worker-flow as identification (ângulo genuinamente novo)
- Hipótese: cartéis se coordenam parcialmente via mobilidade de empregados chave (engenheiros orçamentistas, gerentes comerciais).
- Detectar picos de transferência entre firmas co-licitantes ANTES de leilões coletivos.
- **Precedente**: Arcidiacono et al. sobre coordination via labor markets. Nada específico para cartéis.
- **Contribuição nova**: primeiro evidência de que worker flow é predictor ex-ante de cartel.
- **Teto realista**: QJE se identificação causal for limpa.

### Caminho E — Policy counterfactual
- Usando classifier treinado + modelo structural: que fração dos leilões brasileiros cairia se CADE tivesse recursos 2x / 5x?
- Welfare policy paper ao estilo Dell-Feigenberg-Teshima.
- **Teto realista**: AEJ:Policy / JPubE.

### Caminho F — International transfer
- Transfer learning: classifier treinado em Brasil, aplicado em Chile (ChileCompra), México (CompraNet).
- Ground truth cross-country: Cofece, FNE.
- External validity.
- Custo: 1-2 anos + co-autores internacionais.

---

## Gargalo principal

**Kawai-Nakabayashi (AER 2022) já é o benchmark.** Eles fizeram detection + structural validation no Japão. Nosso risco: referee vê "Brazilian extension of KN22."

**ML-pesado é bandeira vermelha em econ top-5.** Referee pode rejeitar com "this is a computer science paper."

**Antídoto de framing.** Tornar **welfare aggregate** o coração, ML apenas ferramenta instrumental. Paper do tipo:
> "First population-level estimate of procurement cartel prevalence in Brazil, with aggregate fiscal cost of R$ X billion/year and deadweight loss Y% of contract value. Identification combines judicial ground truth, network features, and exogenous leniency shocks."

Isso é paper econômico. Não "a novel GAT architecture."

---

## Precedentes a bater

| Referência | Venue | Nosso diferencial |
|---|---|---|
| Kawai-Nakabayashi (2022) | AER | Network + worker flow; escala Brasil; leniency causal |
| Conley-Decarolis (2016) | — | Population-level; structural markup |
| Imhof-Viklund-Huber (2025) | — | Causal validation via leniency; not just detection |
| Harrington (2008) screens | — | Beyond moment-based; network features |
| Asker (2010) | AER | Endogenous selection; universal not single market |
| Chassang-Ortner (2023) | Ecta | Empirical implementation; structural-reduced triangle |

---

## Decisão inicial

**Passo 1.** Scrape CADE para construir dataset de datas de raid/leniência/TCC. 2-3 semanas.
**Passo 2.** Treinar classifier baseline do Caminho A com ground truth já existente. 1 mês.
**Passo 3.** Checar performance out-of-sample. Se AUC < 0.7, melhorar features ou re-rotular.
**Passo 4.** Rodar Caminho B validation. Se placebo falha, **paper morre** (classifier não é causal).
**Passo 5.** Se B passa, começar Caminho C structural.
**Passo 6.** Avaliar Caminho D worker-flow como ângulo de diferenciação vs. KN22.

**Milestone gating**: Passo 4 é o gate crítico. Se placebo nulo, framing AER cai; re-target IJIO.

---

## Memo honesto

Este paper é **ferramenta-plataforma** para os outros papers:
- Paper 9 (judge-IV) usa scheme classifier deste paper.
- Paper 11 (threshold reform) usa classifier para captured/clean heterogeneity.
- Paper 13 (SCODES, se existir) usa classifier para identificar captured drugs.

Valor estratégico alto mesmo se o paper final sair em IJIO. **Não subordinar timing a top-5 pitch** — entregar classifier validado é pré-requisito da agenda inteira.

**Alternativa radical**: fazer paper "platform-style" explicitamente — "We release a validated cartel detection classifier + benchmark dataset for future corruption research." Pode virar Journal of Econometrics / Econ ML paper com alto citation count.

**Conexão com Paper 6 (Procure)**: Paper 6 usa LLM para classificar *schemes* em sentenças (texto jurídico). Paper 12 usa ML para classificar *cartéis* em dados de licitação (dados numéricos + rede). Os dois podem ser fundidos em paper-mãe ou mantidos separados — decidir com orientador.
