# Roadmap 18 meses — Portfolio bitter-pills

**Janela**: 2026-04-18 → 2027-10-18
**Baseline de ranking**: ver README de cada paper + ranking consolidado abaixo.

---

## Premissas de capacidade

| Item | Valor |
|---|---|
| Capacidade research | ~25 h/semana (conservador; considera teaching + adm) |
| Semanas úteis em 18 meses | ~65 (descontando férias/feriados/viagens) |
| Horas totais research | ~1.625 h |
| Co-autores ativos | Furquim (Papers 1, 2, 3); Galletta+Vacchini (Paper 4); eventualmente Szerman/Decarolis (Papers 13, 14) |
| Restrição crítica | Paper 13 (top-5 bet) exige co-autor health economist **ou** Szerman. Abordar nos primeiros 3 meses. |

---

## Princípios de alocação

1. **No máximo 2 sprints ativos simultâneos.** Single-author foco; multitasking derruba qualidade.
2. **Ship-before-build.** Papers quase-prontos (3, 1, 2) vão para submission antes de abrir frentes novas.
3. **Infra-papers primeiro.** Paper 15 Fase 1 (scheme classifier) habilita 9, 11, 14 — fazer cedo.
4. **Gate de kill é feature.** Paper morre cedo > paper ruim lançado.
5. **Top-5 exige co-autor.** Paper 13 e 14 com co-autor ou não são top-5.
6. **Papers 5, 7, 10, 12 ficam em hold.** Retomar em 2028 se houver espaço.

---

## Plano por quarto

### Q2 2026 (Abr-Jun) — Ship & Setup [semanas 1-11]

| Paper | Allocation | Ação | Entregável |
|---|---|---|---|
| 3 (Frequent Losers) | **40%** | Finalizar R1 response IJIO, submeter | Submission IJIO |
| 1 (Bitter Pills) | **20%** | Converge v6-jpub-short, escrever response-to-reviewers template | Submission JPubE |
| 2 (ME/EPP) | **15%** | Reframe para Econ Inquiry / JPubPolicy dado power issue | Submission |
| 13 (SCODES health) | **15%** | Descriptive Caminho A + outreach co-autor (Szerman/Finkelstein/Mahoney) | Memo interno; lista de co-autores contactados |
| 15 (Scheme Census) | **10%** | Planejar hand-coding de 500 sentenças; definir codebook | Codebook v1 |

**Milestone Q2**: 3 submissions enviadas. Paper 13 outreach em andamento. Paper 15 Fase 1 desenhada.

---

### Q3 2026 (Jul-Set) — Validate [semanas 12-22]

| Paper | Allocation | Ação | Gate |
|---|---|---|---|
| 13 (SCODES) | **45%** | Caminho B: balance test + first-stage F-stat. DATASUS SIM/SIH download via duckdb | **KILL GATE**: se balance falhar → reescopo. Se F < 10 → matar angle health, volta a procurement-only |
| 15 (Scheme) | **25%** | Hand-code 500 sentenças. LLM fine-tune. Validation Cohen's kappa. | **KILL GATE**: kappa < 0.5 → pivot para regex+structured |
| 8 (Narrow Wins) | **15%** | Caminho A baseline RD sobre Paper 4's winner-loser parquet (já existe) | Primeiros resultados RD |
| 4 (Beneath) | **10%** | Coordenar com Galletta. Avançar incumbency results | Progresso em paralelo |
| R&R 1, 2, 3 | **5%** | Responder revisões se chegarem | — |

**Milestone Q3**: Paper 13 first-stage validado (ou morto). Paper 15 classifier v1. Paper 8 pilot.

---

### Q4 2026 (Out-Dez) — Deepen [semanas 23-33]

| Paper | Allocation | Ação | Entregável |
|---|---|---|---|
| 13 (SCODES) | **50%** | Caminho C (reduced-form procurement). Construir welfare pipeline DATASUS link | Draft Caminho C; welfare table preliminar |
| 8 (Narrow Wins) | **20%** | Caminho A completo. Decidir se persegue Caminho B (AKM) — estrutural overlay | Draft Caminho A; decisão B |
| 15 (Scheme) | **15%** | Caminho B: signature extraction por scheme. Train supervisionado | Classifier aplicado a subset BEC-SP |
| 4 (Beneath) | **10%** | Continuar com Galletta — aproximar do submission | Draft avançado |
| R&R | **5%** | Manejo de revisões em andamento | — |

**Milestone Q4**: Paper 13 resultados iniciais de procurement response + welfare preliminar. Paper 8 draft v1. Paper 15 classifier aplicável.

---

### Q1 2027 (Jan-Mar) — Draft [semanas 34-44]

| Paper | Allocation | Ação | Entregável |
|---|---|---|---|
| 13 (SCODES) | **50%** | Caminho E (welfare mortalidade). Caminho G (STF 2024 DiD). Escrever v1 draft | **Draft v1 completo** (~40 pp) |
| 8 (Narrow Wins) | **20%** | Se Caminho B decidido, rodar AKM. Se não, finalizar como AEJ:Applied. Draft final | **Draft submit-ready** |
| 4 (Beneath) | **15%** | Finalizar com Galletta. Submit prep | **Submission** |
| 15 (Scheme) | **10%** | Caminho C: population inference. CADE leniency scrape | Dataset populacional |
| R&R | **5%** | — | — |

**Milestone Q1 2027**: Paper 13 v1 draft em circulação interna. Paper 8 submetido. Paper 4 submetido.

---

### Q2 2027 (Abr-Jun) — Circulate & Submit [semanas 45-55]

| Paper | Allocation | Ação | Entregável |
|---|---|---|---|
| 13 (SCODES) | **35%** | Seminar tour (NBER SI, LACEA, SBE, USP). Refinar baseado em feedback | Apresentações externas; v2 draft |
| 13 (SCODES) | **15%** | **NBER WP circulation** | NBER WP número oficial |
| 14 (Double-IV) | **20%** | **IF co-autor confirmado**: kickoff com power calc (Caminho A+B) | Decisão go/no-go Paper 14 |
| 15 (Scheme) | **15%** | Caminho D1 (CADE event study). Caminho D2 (close-elections RD validation) | Validation results |
| 8 (Narrow Wins) | **10%** | R&R esperado em 4-6 meses | Response letter |
| R&R outros | **5%** | — | — |

**Milestone Q2 2027**: Paper 13 circulado via NBER, feedback recebido. Paper 14 decisão tomada. Paper 15 validation causal avançando.

---

### Q3 2027 (Jul-Set) — Submit top-5 [semanas 56-65]

| Paper | Allocation | Ação | Entregável |
|---|---|---|---|
| 13 (SCODES) | **40%** | Incorporar feedback seminar. **Submit QJE ou AER** (waterfall top-5) | **Submission top-5** |
| 14 (Double-IV) | **25%** | Caminho C (reduced-form 2SLS) se Passo 1 passou; primeiro resultado | Draft early |
| 15 (Scheme) | **15%** | Caminho E (structural welfare) início | Markup estimation draft |
| Papers 1, 2, 4, 8 R&R | **15%** | Manejo | Response letters |
| 3 (IJIO) | **5%** | Aceite final esperado | **Publicado** |

**Milestone Q3 2027 (fim de roadmap)**: Paper 13 em QJE/AER. Paper 3 publicado. Papers 1, 2, 4, 8 em R&R / publicação. Paper 14 ativo. Paper 15 Fase 2 madura.

---

## Gating diagram (dependências)

```
┌─ Q2 2026 ─┐    ┌─ Q3 ─┐    ┌─ Q4 ─┐    ┌─ Q1 2027 ─┐    ┌─ Q2 ─┐    ┌─ Q3 ─┐
│ Ship 3     │──→│ Validate │──→│ Deepen │──→│ Draft     │──→│ Circulate │──→│ Submit │
│ Ship 1     │   │ 13 (GATE)│    │ 13     │    │ 13 v1     │    │ 13 NBER   │    │ 13 QJE  │
│ Ship 2     │   │ 15 (GATE)│    │ 8      │    │ 8 final   │    │ 14 start  │    │ 14 draft│
│ Co-autor   │   │ 8 pilot  │    │ 15 ext │    │ 4 submit  │    │ 15 valid  │    │ 15 v1   │
│ 13 search  │   │ 4 paral. │    │ 4 avanç│    │ 15 pop    │    │ R&Rs      │    │ R&Rs    │
└────────────┘   └──────────┘    └────────┘    └───────────┘    └───────────┘    └─────────┘

Dependências:
  Paper 9 ← Paper 13 (validação judge-IV compartilhada)
  Paper 11 ← Paper 15 (classifier para heterogeneidade)
  Paper 14 ← Paper 8 + Paper 9 (2 IVs validados)
  Paper 15 → enabler de 9, 11, 12, 14

Hold (2028+):
  Paper 5  (draft, sem pergunta)
  Paper 7  (já submetido IEEE)
  Paper 10 (revolving door, 2028 se paper 8 bem-sucedido)
  Paper 12 (cartel, 2028 se paper 15 maduro)
```

---

## Regras de kill/pivot

| Trigger | Ação | Fallback |
|---|---|---|
| Paper 13 balance test falha | Reescopo para subamostra comarcas multi-juiz | Continua com N menor |
| Paper 13 first-stage F < 10 | Mata angle health | Volta 100% para paper 1 JPubE |
| Paper 15 Cohen's kappa < 0.5 | Pivot para regex + structured extraction | Classifier mais fraco mas doable |
| Paper 8 AKM gap não significativo | Submit baseline como AEJ:Applied; não chase QJE | AEJ:Applied OK |
| Paper 14 co-autor não-encontrado em 6 meses | Defer indefinidamente | Paper 8 absorve parte |
| Paper 3 IJIO rejeitado em 2ª rodada | Cascade para RAND | RAND é aceitável |
| Paper 1 JPubE rejeitado | Cascade para JHE / Economic Inquiry | JHE OK |
| Capacidade cai 50% (saúde, adm, etc.) | Manter só 3 ativos: 13, 3-final, 1-final | Pausar 8, 15 |

---

## Riscos transversais e mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Co-autor paper 13 não fecha | Média | Alto | Abordar 3 em paralelo (Szerman, Finkelstein-pipeline, Decarolis); decisão em 3 meses |
| DATASUS API rate-limit trava welfare | Média | Médio | Pré-processar em batches duckdb em março; pedir bulk download via LAI |
| STF 2024 decisão sofre revisão | Baixa | Alto | Monitorar via PGR/STF news; contingency = sem Caminho G do paper 13 |
| Paper 4 Galletta desacelera | Média | Médio | Re-scope paper 8 como spin-off independente |
| Referee AER pede 2-country validation em paper 13 | Alta (se chegar a R&R) | Alto | Preemptivo: incluir Paper 13 em SSRN / presentations para atrair colaboração com outro estado |
| LLM vendor API price aumenta | Média | Baixo | Pivot para Llama open-weights local (paper 15) |
| RAIS identificada não disponível em window | Baixa | Alto | Paper 8, 10 reescopadas; paper 13 não depende |

---

## Conformidade com teto de RAM (CLAUDE.md global)

Todos os scripts pesados (RAIS, BEC, Audesp, SIM/SIH) rodam em **duckdb single-process** sobre parquet, threads=12, memory_limit=14GB, temp_directory='/tmp/duckdb_spill'. Regras do `~/.claude/CLAUDE.md` respeitadas.

Multi-process workers apenas para: (i) signature extraction paper 15 (8 workers × 4GB CNAE-stratified), (ii) LLM inference paper 15 (2 workers paralelos, GPU-less = 4GB RAM cada). Sem self-joins polars; DuckDB default.

---

## Checkpoint mensal

No primeiro dia útil de cada mês, revisar:
1. Alocação % real vs. planejada (tracker simples em markdown)
2. Milestones atrasados (flag amarelo se +2 semanas; vermelho se +4)
3. Ajustar Q seguinte se desvio material
4. Atualizar este arquivo com revisões

Próximo checkpoint: **2026-05-01**.
