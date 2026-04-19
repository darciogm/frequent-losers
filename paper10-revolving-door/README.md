# Paper 10 — Revolving Door: Bureaucrat-to-Firm Mobility and Procurement Rents

**Status.** Semente. A pré-calibração (2026-04-18) coloca probabilidade top-5 em 3–8%; venue realista JPubE / AEJ:Applied.

---

## Pergunta central

Contratar um ex-servidor público que atuou em procurement (pregoeiro, membro de comissão de licitação, fiscal de contrato) aumenta a probabilidade de uma firma ganhar contratos públicos? Qual fração do *excess return* da firma é capturada pelo trabalhador via rent-sharing, e qual fração permanece na firma?

Reformulação estrutural: *qual é a elasticidade do acesso a contratos públicos ao capital humano político-conectado, e como esse prêmio se dissipa com o tempo de afastamento do servidor?*

---

## Identificação base

**Dois designs complementares**, rodados em paralelo para triangular:

**Design (a) — Event-study firma-nível.**
- $T_{it} = 1$ se firma $i$ contrata ex-servidor de procurement em ano $t$.
- Dynamic DiD com controles staggered-TE-robust (Callaway-Sant'Anna 2021; Sun-Abraham 2021).
- Outcome: contratos ganhos, valor total, entrada em novos PBUs, preço relativo à estimativa.
- Comparação com matched-DiD sobre firmas com hiring trajectory similar (não-servidor).

**Design (b) — IV por regra de aposentadoria.**
- Pregoeiro elegível à aposentadoria (Lei 8.112 / estatuto SP) → aumenta propensão a migrar para setor privado.
- Variável de elegibilidade é função exógena de idade + tempo de serviço + regra vigente na data.
- First-stage: elegibilidade → saída do serviço público → hiring por firma.
- Outcome: contratos da firma em 1-5 anos pós-hiring.
- Análogo metodológico: Card-Maestas-Purcell ou Rossin-Slater-Uniat (regras de eligibility como IV para aposentadoria).

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| Pregoeiros + RAIS match | `paper1-bitter-pills/datasets/pregoeiros/` | Pronto |
| `firm_firm_worker_flow_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `revolving_door/` | `paper4-thresholds/02_data/firms/` | Pronto |
| `Firms_final.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `rais_bec_linked.parquet` | `paper3-frequent-losers/data/processed/` | Pronto |
| BEC-SP bid-level + winner/loser | `paper4-thresholds/02_data/` | Pronto |
| TCE-SP Audesp (municipal revolving) | `paper6-procure/build/clean/` | Pronto |
| TSE electoral data | `bitter-pills/data/raw/tse-electoral/` | Pronto |
| RAIS identificada | externo | Parcial |

---

## Caminhos possíveis

### Caminho A — Baseline event study (JPubE)
- Hiring de ex-pregoeiro como evento; firma-year panel.
- Outcomes: contratos, valor, PBU-level penetration.
- Controles: firma FE, CNAE × ano FE.
- Heterogeneidade: senioridade do servidor, tempo desde saída do serviço público, overlap temporal com procurement ativo do PBU de origem.

### Caminho B — IV por regra de aposentadoria (AEJ:Applied)
- Exige mapear regras estatutárias SP (APRS/IAMSPE) + INSS federal.
- First-stage: elegibilidade prediz transição servidor→privado.
- 2SLS: hiring induzido pela elegibilidade → outcome firma.
- **Vantagem**: exogeneidade forte se regra de eligibility for nítida.
- **Risco**: mudanças de regra (EC 103/2019 reforma previdenciária) criam quebras — usar como DiD adicional.

### Caminho C — Rent-sharing decomposition (ReStat / AEJ:Applied)
- Matching trabalhador-firma nivel RAIS.
- Salário do ex-servidor ante vs. pós-migração vs. trabalhadores similares.
- Quanto do contrato-won-premium vai para o trabalhador vs. permanece na firma?
- Precedente: Card-Cardoso-Heining-Kline (JLE 2018) rent-sharing AKM framework.

### Caminho D — Network diffusion (top-5 stretch)
- Servidor que migra carrega informação privada sobre procurement (preferências, padrões de ítem, janelas de aviso).
- Firma contratante passa a conectar-se (via cobidding) com firmas "irmãs" já estabelecidas.
- Usa `firm_firm_worker_flow_edges` + `firm_firm_cobidding_edges`.
- Mede contagion de comportamento procurement pós-hiring.
- **Novo**: ninguém fez information-diffusion procurement network empiricamente.
- **Teto realista**: QJE se limpo.

### Caminho E — Comparação federal vs. municipal
- Municipal: turnover político alto (Toral 2024) → revolving door mais rápido.
- Federal/estadual: servidor estável → revolving door mais lento mas com posições mais altas.
- Heterogeneidade de policy-relevance.

### Caminho F — Structural auction model with connected bidder
- Modelo de leilão onde bidder conectado tem signal mais informativo sobre reserva/demanda.
- Estima o valor do capital humano político-conectado.
- Counterfactual: cooling-off period obrigatório (vedação de contratação de ex-servidores por X anos).

---

## Gargalo principal

**Akcigit-Baslandze-Lotti (Econometrica 2023) fresquíssimo.** Esse paper estabeleceu revolving door político-firma como tema top-5. Nosso risco: referee lê "Brazilian version of ABL" e rejeita.

**Antídoto de framing.** ABL estuda *políticos* (eleitos) → firmas. Nós estudamos *burocratas* (concursados, pregoeiros, fiscais) → firmas. A distinção é crítica:
- Políticos têm mandato finito; burocratas têm carreira estável.
- Mecanismo de conexão diferente (político = influência; burocrata = informação operacional).
- Implicações de policy diferentes (cooling-off vs. election-to-lobby restrictions).

Esse framing precisa estar nítido desde a primeira página.

---

## Precedentes a bater

| Referência | Venue | Nosso diferencial |
|---|---|---|
| Akcigit-Baslandze-Lotti (2023) | Ecta | Burocrata ≠ político; procurement ≠ innovation |
| Shi (2022) | — | Congressional staffer US ≠ Brazilian bureaucrat |
| Cingano-Pinotti (2013) | JEEA | Itália / conexão passiva; nós temos active-channel |
| Best-Hjort-Szakonyi (2023) | QJE | "Individuals in bureaucracy" mas não mobility |
| Dal Bó-Rossi (2007) | — | Rent-sharing political connection US |

---

## Decisão inicial

**Passo 1.** Análise descritiva: frequência de transições pregoeiro → setor privado, tempo médio, distribuição de destinos. Saber se o fenômeno é grande o suficiente para sustentar o paper.
**Passo 2.** Rodar Caminho A com matched-DiD. Se magnitude fraca → matar paper.
**Passo 3.** Se Caminho A significativo, construir IV do Caminho B. Checar first-stage.
**Passo 4.** Se ambos ok, adicionar Caminho C (rent-sharing) — top-5 demanda decomposition.
**Passo 5.** Caminho D (network diffusion) só após C validado, como extensão.

**Quick-kill gate**: Passo 1-2 em 1 mês. Se descritivo mostrar frequência <1% das firmas → matar.

---

## Memo honesto

Este paper é **fortemente conectado ao Paper 8** (Narrow Wins). Revolving door é um dos mecanismos que explicaria por que close-bid wins têm efeitos persistentes. **Avaliar fusão**: um paper-mãe "Winners, Workers, and Political Connections" que incorpora Caminho B/C do Paper 8 + Caminhos A/C do Paper 10. Isso sobe teto para QJE.

Contra: se fundidos, trabalho é 2x + risco de referee exigir descritivos mais rigorosos em cada pilar.
