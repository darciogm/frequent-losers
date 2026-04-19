# Paper 11 — Threshold Reform: Lei 14.133 and Corruption Reallocation

**Status.** Semente. A pré-calibração (2026-04-18) coloca probabilidade top-5 em 3–6%; venue realista JPubE / AEJ:Applied.

---

## Pergunta central

Quando o threshold de dispensa de licitação é elevado pela Lei 14.133/2021 (dispensa R$8k → R$50k; convite R$15k → R$100k), a corrupção *desaparece* (porque há menos incentivo para fracionar sob o novo threshold alto), ou *se redistribui* para o novo threshold (waterbed)? E o efeito é homogêneo, ou depende de quão capturado era o município antes da reforma?

Reformulação estrutural: *qual é a elasticidade da distribuição de valores de contrato ao threshold regulatório, e essa elasticidade revela preferência por evasão (corrupção) ou por conveniência administrativa (waste passivo)?*

---

## Identificação base

**Staggered DiD + bunching.** Três camadas:

1. **Bunching (Saez 2010 AEJ:Policy; Kleven 2016 ARE)**: density discontinuity em contract value em torno de thresholds antigo (R$8k, R$15k) e novo (R$50k, R$100k). Pré vs. post reforma.

2. **Staggered DiD**: municípios adotam a Lei 14.133 em datas distintas entre 2021-2023 (escolha via decreto municipal). Adoção escalonada é tratamento. Usar Callaway-Sant'Anna (2021) / de Chaisemartin-D'Haultfœuille (2020) / Borusyak-Jaravel-Spiess (2024).

3. **Heterogeneidade por captured-vs-clean**: usar classificador de scheme do Paper 12 (ou proxy: municípios com sentença de improbidade/fracionamento pré-2021) para identificar "municípios capturados". Predição: capturados mostram *redistribuição* de bunching (movimento do threshold antigo para o novo); limpos mostram *desaparecimento*.

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| `licitacao.parquet` | `paper6-procure/build/clean/` | Pronto |
| `contract.parquet` | `paper6-procure/build/clean/` | Pronto |
| `empenho.parquet` | `paper6-procure/build/clean/` | Pronto |
| `despesa/despesa-YYYY.parquet` (2008-2025) | `paper6-procure/build/clean/` | Pronto |
| `court_case.parquet` + link | `paper6-procure/build/analysis/` | Pronto |
| Scheme classifier (Paper 12) | — | **Dependente** |
| Datas municipais adoção Lei 14.133 | — | **Precisa construir** |
| IBGE municipality shapefiles | `paper6-procure/references/` | Pronto |

---

## Caminhos possíveis

### Caminho A — Pure bunching descritivo (viability check)
- Aplicar Cattaneo-Jansson-Ma (2020) density test em distribuição de contract value.
- Pré-reforma: teste bunching no R$8k/15k.
- Post-reforma: teste bunching no R$50k/100k + em R$8k/15k (persistência?).
- Se bunching pré-reforma é fraco (magnitude irrisória), paper morre.
- Paper comparável: Palguta-Pertold (AEJ:Applied 2017) em dados Czech.

### Caminho B — Staggered DiD de adoção (JPubE)
- Mapear, município por município, data do primeiro edital sob Lei 14.133.
- DiD staggered: treatment = dummy "município já migrou".
- Outcome primário: share de contratos em dispensa, share abaixo de thresholds antigos/novos.
- Outcome secundário: preço relativo, competição (número de bidders), firma vencedora (shell-firm score).
- **Risco**: adoção pode ser endógena (municípios "bons" adotam primeiro). Precisa validar via balance sobre observáveis pré-reforma.

### Caminho C — Reallocation via captured vs. clean (AEJ:Applied, talvez ReStat)
- Heterogeneidade é o coração do paper.
- Hipótese testável: $\beta_{capt} \neq \beta_{clean}$ em bunching do novo threshold.
- Usa scheme classifier do Paper 12 como medida de captura ex-ante.
- **Teto realista**: AEJ:Applied se heterogeneidade for limpa.

### Caminho D — Structural welfare model (top-5 stretch)
- Modelar escolha do município entre thresholds: trade-off entre efficiency (licitar sobra tempo) e rent (fracionar para capturar).
- Reform shifts incentive.
- Estimar função de utilidade do gestor captured vs. honest usando reform como variation.
- **Precedente**: Kleven-Waseem (QJE 2013) notching/bunching estrutural.
- **Teto realista**: QJE se estrutural + welfare convincente. 8-12% prob.

### Caminho E — Spillovers regionais
- Prefeitos aprendem com vizinhos. Adoção early em município X → adoção mais rápida em Y vizinho?
- Spatial DiD.
- Útil como mechanism section, não paper stand-alone.

### Caminho F — Interação com reforma STF 2024 (novo ângulo)
- Em setembro/2024 STF limitou dever de compra forçada. Sinergia com Paper 13 (SCODES).
- Se dispensa forçada por SCODES diminui pós-STF, bunching em thresholds de dispensa muda?
- Interação procurement law reform × health law reform — dois shifts simultâneos.

---

## Gargalo principal

**Bunching é commodity methodology**. Referee top-5 pensa: "aplicação de método conhecido a mais uma reforma." Antídoto: (i) heterogeneidade via captured/clean é a contribuição nova, (ii) waterbed claim precisa ser provado causalmente (Caminho D estrutural).

**Waterbed claim é difícil**. Precisamos separar:
- Aumento de bunching no threshold novo (mecânico — mais itens cabem no novo threshold alto);
- vs. *reallocation* de corrupção para o novo threshold (mudança de escolha comportamental).

Isso exige counterfactual estrutural. Sem isso, referee cético vence.

---

## Precedentes a bater

| Referência | Venue | Nosso diferencial |
|---|---|---|
| Palguta-Pertold (2017) | AEJ:Applied | Reforma de threshold (vs. só observação); Brazilian scale |
| Coviello-Mariniello (2014) | JPubE | Lei 14.133 > Italian publicity threshold em escala e clareza |
| Carril (2021) | — | Welfare de scrutiny above thresholds, nós com reform |
| Caires-Peralta-Mendes (2023) | — | Fracionamento PT; nós com dois thresholds + captured heterog |
| Kleven-Waseem (2013) | QJE | Framework estrutural notching |

---

## Decisão inicial

**Passo 1.** Descritivo: distribuição de contract value 2018-2020 (pré) vs. 2022-2024 (post). Se bunching visual não aparece, paper morre.
**Passo 2.** Construir variável de adoção municipal da Lei 14.133 (webscraping de diários oficiais municipais ou via Audesp). Trabalho de 2-4 semanas.
**Passo 3.** Rodar Caminho A + B.
**Passo 4.** Esperar Paper 12 (scheme classifier) para habilitar Caminho C.
**Passo 5.** Avaliar Caminho D estrutural com co-autor public finance (bunching experts).

**Dependency crítica**: Caminho C exige Paper 12 maduro. Sem isso, teto realista cai para JPubE.

---

## Memo honesto

Este paper tem **co-dependência com Paper 12** (scheme classifier é o elevador do teto). Sem Paper 12, vira "reforma + bunching + DiD" — sólido mas field journal.

A **Lei 14.133 é o maior experimento de threshold procurement do mundo** em volume. Vale a pena fazer mesmo que só em JPubE — a pergunta de policy é first-order e a Brazil está ativamente discutindo implementação. Valor de utilidade ex-post alto.

Se Paper 13 (SCODES) avançar, considerar fusão parcial via Caminho F — interação de duas reformas simultâneas é genuinamente novo.
