# Paper 8 — Narrow Wins: Close-Bid RDD + Matched Employer-Employee

**Status.** Semente. A pré-calibração (2026-04-18) coloca probabilidade top-5 em 8–12% sem overlay estrutural; venue realista AEJ:Applied / ReStat.

---

## Pergunta central

Qual é o efeito causal de ganhar um contrato público sobre (i) crescimento da firma, (ii) salários e composição da força de trabalho, (iii) divisão de rent entre firma-trabalhadores-donos, e (iv) mobilidade de trabalhadores entre vencedores e perdedores?

Reformulação estrutural (caminho top-5): *quem captura o rent gerado pelo contrato público — a firma, o incumbente, ou o novo hire — e essa divisão varia com a estrutura competitiva do leilão?*

---

## Identificação base

- **Sharp RD** em margem de vitória (MV = bid_winner − bid_runner_up) em BEC-SP Convite e Pregão Eletrônico.
- Cutoff MV = 0; firmas com MV pequeno positivo vs. negativo são comparáveis em expectativa.
- Clustering por item × ano.
- Continuity-based RDD (Calonico-Cattaneo-Titiunik 2014 Ecta; Cattaneo-Jansson-Ma 2020 JASA).

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| `df_convite_winner_looser.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `df_pregao_winner_looser.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `Firms_final.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `firm_year_panel.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `rais_bec_linked.parquet` | `paper3-frequent-losers/data/processed/` (verif) | Pronto |
| RAIS identificada 2002-2022 | local / externo | Parcial |
| `new_hires/`, `revolving_door/` | `paper4-thresholds/02_data/firms/` | Pronto |

Pipeline base de RD (rdrobust + reghdfe) já escrito em `paper4-thresholds/03_analysis/Dario_Vacchini/code/`.

---

## Caminhos possíveis

### Caminho A — Reduced-form extensão do Paper 4 (baseline AEJ:Applied)
- RD local linear em MV → outcomes firma-ano: emprego, massa salarial, produtividade, sobrevivência.
- Janela 1, 3, 5 anos pós-contrato.
- Heterogeneidade por valor do contrato, tipo de item, modalidade.
- **Risco**: Ferraz-Finan-Szerman (JPE 2016) já fez isso com matching + ComprasNet. O que sobra de incremental: (i) RD é identificação mais limpa, (ii) BEC-SP é bens comuns de baixo valor (complementar ao federal), (iii) tamanho amostral maior.
- **Teto realista**: AEJ:Applied.

### Caminho B — Worker-level AKM rent decomposition (estiramento para top-5)
- Estimar AKM firm FE para firmas BEC 2002-2022 usando RAIS.
- Pre/post RD: *como muda o firm FE após ganhar contrato?* Isso mede rent-sharing induzido pelo contrato.
- Decompor: (i) incumbent wage gain, (ii) new hires (better match quality?), (iii) separation rate.
- **Análogo metodológico direto**: Kline-Petkova-Williams-Zidar (QJE 2019) "Who Profits from Patents?" — RD em patent scoring + AKM.
- **Contribuição nova**: KPWZ usa patentes (inovação); nós usamos rent público (demanda) — mecanismos diferentes, policy-relevantes em contextos distintos.
- **Teto realista**: QJE se bem executado.

### Caminho C — Revolving door como mediator (link com Paper 10)
- Usa close-bid RD como first-stage → firma vence → firma contrata ex-pregoeiro com maior propensão.
- Mediation analysis: que fração do efeito firma-nível passa via human capital político-conectado?
- **Análogo**: Akcigit-Baslandze-Lotti (Ecta 2023) política-firma mobility na Itália.
- **Teto realista**: ReStat/JPubE. Top-5 se integrado ao Caminho B.

### Caminho D — Structural overlay (caminho top-5 ambicioso)
- Modelo Krasnokutskaya-Seim: RD identifica a distribuição de custos das firmas no leilão.
- Combinar com AKM para decompor: quanto do rent vai para firma (profit) vs. worker (wage).
- Counterfactuals de policy: reserva de preço, número de participantes.
- **Teto realista**: AER se co-autor estruturalista forte. 12-18% prob.
- **Exigência**: co-autor com publicação em AER/Econometrica em IO empírica.

### Caminho E — Multi-country validation
- Replicar desenho em 2º país com procurement + LEED data (Portugal BASE, Itália, Chile ChileCompra).
- External validity garantida.
- Custo: 2+ anos adicionais, co-autor(a) internacional.

---

## Gargalo principal

**Ferraz-Finan-Szerman (JPE 2016) bloqueou o "first to link procurement+RAIS" em Brasil.** Sem diferenciador estrutural (Caminho B ou D), o paper parece "nice extension of FFS" — que é morte no top-5.

Desbloquear exige:
1. Estrutural (KPWZ-style AKM ou Krasnokutskaya-Seim); ou
2. Mechanism novo não coberto por FFS (revolving door, cartel-formation); ou
3. Multi-country validation.

---

## Precedentes a bater

| Referência | Venue | Como superar |
|---|---|---|
| Ferraz-Finan-Szerman (2016) | JPE | Identificação (RD > matching), mechanism (AKM decomp) |
| Kline-Petkova-Williams-Zidar (2019) | QJE | Demanda pública ≠ innovation shock; replica framework |
| Akcigit-Baslandze-Lotti (2023) | Ecta | Revolving door procurement ≠ political mobility |
| Colonnelli-Prem (2022) | JFE | Close-bid RD ≠ audit shock |
| Carril-Gonzalez-Lira-Walker (AER fc.) | AER | Estrutural ≠ redução forma ; mercado emergente |

---

## Decisão inicial

**Passo 1.** Rodar pipeline do Caminho A sobre dados já prontos (~2-3 semanas).
**Passo 2.** Se resultados significativos e balance test passar, decidir entre B (AKM) ou C (revolving door) ou ambos.
**Passo 3.** Avaliar com orientador/co-autor se vale investir 6-12 meses adicionais no Caminho D estrutural.

Nunca partir para D sem A+B validados.

---

## Memo honesto

O paper 4 (Beneath the Surface) já está fazendo RD em incumbência. Este paper 8 é a extensão natural para outcomes firma-trabalhador. **Pode ser absorvido como "Paper 4b" ou rodado em paralelo como paper separado.** Vale discutir com Galletta/Vacchini se a estratégia é (i) um paper só com escopo maior ou (ii) dois papers irmãos.
