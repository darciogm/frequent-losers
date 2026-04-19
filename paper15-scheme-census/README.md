# Paper 15 — The Scheme Census: Population-Level Measurement of Procurement Corruption

**Status.** Semente top-5. Pré-calibração (2026-04-18) coloca probabilidade top-5 em **12-18%**. Venue alvo: **QJE / AER (measurement paper)**.

**Tagline interna.** Primeiro censo populacional de corrupção em procurement público, com mecanismo identificado por scheme, validação causal via choques exógenos, e inferência estrutural sobre custo fiscal agregado.

---

## Pergunta central

Qual é a distribuição empírica de corrupção em procurement público brasileiro, desagregada por *scheme type* (fracionamento, sobrepreço, direcionamento, cartel, dispensa irregular, laranja/shell)? Qual o custo fiscal agregado, e qual a elasticidade dessa prevalência à intensidade de enforcement (waterbed)?

Olken-Pande (Annual Review 2012) declaram: *"measuring corruption at scale remains the defining challenge of this literature."* Treze anos depois — ainda nada population-level com mecanismo identificado. Este paper é a resposta.

---

## Reformulação estrutural (ângulo top-5)

Modelo latente de scheme assignment:

$$s_{ijt} = \arg\max_{s \in \mathcal{S}} \{ u_i(s, j, t) - c_s(\text{detect}_{jt}) \}$$

onde:
- $s_{ijt}$ = scheme efetivamente usado pela firma $i$ no leilão $j$ no tempo $t$.
- $\mathcal{S} = \{\emptyset, \text{fracion}, \text{sobrepreço}, \text{direcion}, \text{cartel}, \text{dispensa\_irreg}, \text{shell}\}$.
- $u_i$ = retorno financeiro por scheme.
- $c_s$ = custo esperado por scheme (depende de intensidade de monitoring observável).

**Identificação**: ver sentenças revela $(s, i, j, t)$ para subset. Treinar classifier $\hat{s}(j, t, \text{features})$ que *prediz* scheme a partir de assinatura observável em procurement data. Aplicar ao universo. Validar contra CADE shocks e close-election RDs.

**Welfare / fiscal cost**:

$$\text{Fiscal overpayment}_t = \sum_{j} \hat{\pi}(\hat{s}_j) \cdot (\text{price}_j - \text{counterfactual price}_j)$$

onde $\hat{\pi}(s)$ é markup estrutural por scheme, estimado via subamostra com price benchmark (CMED para saúde; SINAPI para obras; outros).

**Waterbed elasticity**: $\eta_{ss'} = \partial \log(\text{fração scheme}~s') / \partial \log(\text{enforcement}~s)$. Estimado via variação temporal + geográfica em enforcement intensity.

---

## Design em três camadas

### Camada (A) — LLM scheme classification sobre sentenças
- **Corpus**: 12.593 sentenças TJSP improbidade + 10k petições iniciais anonimizadas (com entity_map para re-identificação CNPJ).
- **Método**: fine-tune LLM (Llama-3.1-70B ou GPT-4o-class) com prompts estruturados para extrair: (i) scheme type(s) no caso, (ii) modalidade de procurement envolvida, (iii) firmas e oficials envolvidos, (iv) valor, (v) período.
- **Validação**: hand-coding por equipe (3 codifiers) em subamostra de 500 casos. Cohen's kappa > 0.7 é gate.
- **Precedente**: Dell-Feigenberg-Teshima + collab em LLM-para-economia. Paper 6 (Procure) já tem prompts parciais.

### Camada (B) — Signature extraction em procurement data
- Para cada scheme detectado em (A), calcular assinaturas em nível processo × firma × ano:
  - **Fracionamento**: McCrary density em torno de thresholds; contratos seriados abaixo de limiar.
  - **Sobrepreço**: gap preço pago vs. CMED/SINAPI/histórico.
  - **Direcionamento**: spec narrow + único licitante + CNPJ-especifíco wins.
  - **Cartel**: cobidding density, bid CV, rodízio de vencedores, Harrington/Imhof screens.
  - **Dispensa irregular**: frequência de dispensa vs. threshold regulatório; repetição fornecedor.
  - **Shell**: CNPJ age, shared address, partner socio-economic (laranja).
- Treinar classifier supervisionado: (judicially-revealed $s$) → (procurement signature $\hat{s}$).
- Modelos: XGBoost, GAT, text-based (edital content embeddings).

### Camada (C) — Population inference + causal validation
- Aplicar classifier treinado ao universo: BEC-SP (~4M contratos) + TCE-SP Audesp (~3.9M ajustes + milhões de bids e empenhos).
- **Validação causal 1 — CADE leniency**: firmas em mesma cartel community (classificada) mas não diretamente investigadas devem mostrar shift pós-raid. Placebo: comunidades não-conectadas.
- **Validação causal 2 — Close-election RD**: mudança de prefeito causa mudança em scheme mix se corrupção depende de ator específico. RD no margin de vitória eleitoral × scheme-fraction outcome.
- **Validação causal 3 — STF/CNJ rulings**: decisões institucionais que mudam threshold, regra de auditoria, ou poder de MP.

### Camada (D) — Structural welfare
- Markup por scheme $\hat{\pi}(s)$ estimado via auxiliary regressions em subamostras com price benchmark.
- Fiscal overpayment agregado: R$ X bilhões/ano.
- Waterbed elasticities $\eta_{ss'}$ via painel.
- Counterfactuals de policy:
  - Dobrar recursos MP → quanto corrupção cai? Qual scheme substitui?
  - Novo threshold (Lei 14.133) → reallocation direction?
  - Mandatory transparency → qual margem é afetada?

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| 12.593 sentenças TJSP | `paper6-procure/build/clean/court_sentenca.parquet` | Pronto |
| 10k petições iniciais anonimizadas + entity_map | `$DATA_DIR/TJSP/improbidade_documentos/` | Pronto |
| LLM extraction cache parcial | `paper6-procure/build/analysis/peticao_extract.json` | Parcial |
| Regex scheme flags | `paper6-procure/build/analysis/peticao_regex.json` | Pronto |
| TCE-SP Audesp universe | `paper6-procure/build/clean/{licitacao,contract,empenho,despesa,bid,firm}.parquet` | Pronto |
| BEC-SP bid-level | `paper4-thresholds/02_data/` | Pronto |
| `cade_cartel_processes.parquet` + `cade_ground_truth.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `firm_firm_{cobidding,worker_flow}_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `auction_screens_{convite,pregao}.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `link_court_procurement.csv` | `paper6-procure/build/analysis/` | Pronto |
| Sanctions CEIS/CNEP/CEPIM | `paper6-procure` Dropbox `data/sanctions/` | Pronto |
| Price benchmarks CMED/SINAPI | dados públicos | A baixar |
| Dawn raid / leniência CADE | CADE portal | A construir |
| Close-elections TSE | `bitter-pills/data/raw/tse-electoral/` | Pronto |

---

## Caminhos possíveis

### Caminho A — LLM fine-tuning + validation (Paper 6 extension)
- Expandir Paper 6's prompts.
- Hand-code 500 sentenças; train/validate classifier.
- Saída: scheme-labelled corpus de 12.5k + 10k.
- **Gate**: Cohen's kappa ≥ 0.7 em validation. Se < 0.5, rewrite prompts.
- **Publicação intermediária possível**: paper metodológico em Journal of Econometrics ou JoE Online, descrevendo LLM pipeline para legal corpus extraction.

### Caminho B — Signature extraction (plataforma para outros papers)
- Por scheme: definir e calcular assinatura observacional.
- Dataset final: `(process_id, features, $\hat{s}$ predicted)` para universo.
- **Valor colateral**: Paper 11 (threshold reform) e Paper 14 (endogenous corruption) usam este output como input. Este paper é plataforma.

### Caminho C — Descriptive population census (pré-publicação)
- Estatísticas descritivas: fração de processos por scheme, por modalidade, por ano, por município.
- Mapa: onde é cada scheme mais prevalente.
- Trends: scheme mix evoluindo com Lei 14.133, STF decisions, electoral cycles.
- **Publicação**: possível Brookings / NBER WP antes de top-5 submission, para estabelecer priority.

### Caminho D — Causal validation (caminho crítico)
- **D1 — CADE leniency shock event study**: pós-raid, firmas em mesma cartel-community (classifier-predicted, não-investigadas) têm shift de comportamento? Placebo: tamanho/CNAE-matched communities não-conectadas.
- **D2 — Close-election RD**: mudança de prefeito via RD → scheme mix muda em município? Identifica se corrupção é ator-específica ou institucional.
- **D3 — Institutional shocks**: STF 2016 (Lava Jato doctrines), Lei 14.133 (2021), operações específicas.

### Caminho E — Structural welfare (elevador top-5)
- Per-scheme markup estimation com price benchmarks.
- Aggregate fiscal overpayment.
- Waterbed elasticities.
- Counterfactual policy experiments.
- **Precedente**: Kawai-Nakabayashi (AER 2022) tem isso para cartel. Nós ampliamos para todo scheme type.

### Caminho F — Spatial / network heterogeneity
- Corrupção se propaga via rede: firmas adjacentes em network têm correlated scheme choice.
- Spatial Durbin model para spillovers.
- Novelty: primeira map da "geografia da corrupção" com mecanismo.

### Caminho G — Multi-reality extension
- Classifier treinado em SP → aplicar em outros estados com scraping TCE.
- External validity em Brasil.
- Eventualmente: transfer learning para Chile, México, Argentina.

---

## Precedentes a bater

| Referência | Venue / Ano | Nosso diferencial |
|---|---|---|
| Olken-Pande | Annual Review 2012 | Nós *resolvemos* a challenge que eles articularam |
| Olken | QJE 2007 | Village-level ≠ population-level; nós amplificamos |
| Fisman-Wei | QJE 2009 | Missing imports = 1 scheme; nós temos 6 schemes |
| Kawai-Nakabayashi | AER 2022 | Só cartel; nós fazemos scheme menu completo |
| Ferraz-Finan | QJE 2008, 2011 | CGU audit = revelação amostral; nós temos universo |
| Colonnelli-Prem | JFE 2022 | Firm outcomes pós-revelação; nós temos pre-revelação prediction |
| Dell-Feigenberg-Teshima etc. | - | LLM-para-econ metodologia é aceita |
| Aaltio et al. (2025) | IJIO | Single-market cartel ≠ population schemes |
| Imhof-Viklund-Huber (2025) | WP | GNN cartel only; nós mais schemes + causal |
| Palguta-Pertold | AEJ:Applied 2017 | Fracionamento Czech ≠ population + mechanism |

---

## Gargalo principal

**Três obstáculos:**

1. **"Isto é ML, não economia"** — Referee 1 do AER. Antídoto: welfare structural no centro, ML é ferramenta. Abstract focado em *R$ X bilhões de overpayment + $\eta$ waterbed*, não em "novel classifier architecture."

2. **Classifier validity** — Se scheme assignment $\hat{s}$ não é causal-valid, welfare calculus desaba. Causal validation (Caminho D) é *absolutamente* crítica. Não é opcional.

3. **Replicabilidade LLM** — Top-5 exige package replicável. LLM fine-tuning precisa ser documentado com exactness (seed, prompt version, temperature=0, versão do modelo). Open-weights (Llama) preferível a API-only (GPT) para replicação perene.

---

## Decisão inicial

**Fase 1 — Metodologia (6 meses):**
- Passo 1. Hand-coding de 500 sentenças. Define codebook.
- Passo 2. LLM fine-tuning. Validate vs. hand-coding.
- Passo 3. Publicar Brookings / NBER WP com Camada A + B + descriptive C.

**Fase 2 — Causal validation (6-12 meses):**
- Passo 4. Scrape CADE dawn raids + leniência.
- Passo 5. Caminho D1 event study.
- Passo 6. Caminho D2 close-election RD.
- Passo 7. Caminho D3 institutional shocks.

**Fase 3 — Estrutural (6-12 meses):**
- Passo 8. Price benchmarks CMED / SINAPI.
- Passo 9. Structural markup estimation por scheme.
- Passo 10. Waterbed + counterfactuals.

**Fase 4 — Submission (6 meses):**
- Passo 11. Draft final.
- Passo 12. Pre-submission at NBER WP, Brookings, CEPR.
- Passo 13. Submit QJE → AER → Ecta waterfall.

**Timeline realista**: 24-36 meses. É um paper de carreira, não quick-win.

---

## Co-autoria estratégica

Este paper se beneficia de:
- (a) LLM / computational social science expertise (ex.: Melissa Dell, Ash/Chen, Gentzkow/Shapiro/Taddy) — legitima metodologia.
- (b) IO empirical / welfare estructuralista (Decarolis, Ryan) — legitima markup estimation.
- (c) Brazilian data insider (Ferraz, Szerman) — bridge.

**Recomendação**: começar single-author até Passo 3 (descriptive census). Quando resultados iniciais existirem, buscar co-autor (a) primeiro, depois (b). Passos 1-3 são demonstração de viabilidade.

---

## Memo honesto

Este paper é **ferramenta-plataforma central** do portfólio:
- Paper 9 (judge IV) usa scheme classification como outcome refinado.
- Paper 11 (threshold reform) usa classifier para captured/clean heterogeneity.
- Paper 12 (cartel detection) é um *sub-caso* deste (só cartel scheme).
- Paper 14 (endogenous corruption) usa classifier como outcome estrutural.

**Decisão estratégica**: este paper pode ser (i) *feito antes* dos demais, habilitando-os; (ii) *feito depois*, consolidando-os num single paper; ou (iii) *nunca feito individualmente*, desmembrado nos outros.

**Recomendação**: fazer **Caminhos A + B + C** (fase 1) cedo, como pré-requisito do portfólio. **Caminhos D + E** (fases 2-3) só se houver compromisso de 2-3 anos de trabalho focado.

**Risco de canibalização**: se Paper 11 e Paper 14 já publicam usando outputs deste paper, o "census paper" em si pode parecer redundante. Alternativa: Paper 15 é o *paper-mãe* que incorpora partes de 11, 12, 14 num único top-5 submission, os outros viram working papers de cada componente.

Este é o **paper de maior alavancagem mas também maior compromisso de tempo** do portfólio.
