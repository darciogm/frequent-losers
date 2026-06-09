# Diagnóstico paper18 — 2026-04-28 (mr-hospital, modo /co)

Sessão de leitura passiva sobre estado pós initial-commit. Sem mudanças em
código ou manuscrito ainda. Audita o que existe e propõe rota até deadline
2026-05-08.

---

## 1. Estado real

### O que existe

- **Manuscrito** (28 pp, compila): introduction → setting → data → method →
  results → discussion → conclusion → appendix. Inglês acadêmico maduro,
  estrutura JHE-compatível, 9 figuras + 4 tabelas.
- **Pipeline** 16 scripts (`00 → 16`) rodaram com sucesso. Inputs: SIH-RD
  2010-2024 (179.5M AIH), SIM 2010-2023, CNES habilitação alta-complexidade,
  IBGE pop 2015-2025, PIB municipal 2015-2023.
- **Embeddings** treinados:
  - `embeddings_node2vec.parquet` — bipartido M+H, 128-dim
  - `embeddings_munmun_proj.parquet` — projeção M-M via TF-IDF do bipartido
    (corte top-30 vizinhos por município, simetrização max). É o usado em
    todas as análises downstream.
- **Outcome**: `amenable_mortality.parquet` painel município-ano, lista
  Nolte-McKee/OECD com cap idade<75 (correto). 28% das mortes 2010-2023
  classificadas amenable (~5.4M óbitos).
- **Hospital_closures.parquet**: 3.518 CNES detectados como tendo deixado de
  reportar competência (`competen_last`, `closed_by_2023`). Sem filtro de
  exogeneidade (admin/fiscal vs demand-driven) ainda.

### O que está faltando

- Script de **event-study Callaway-Sant'Anna** sobre fechamentos. O paper
  promete (`§7.2 The Closure Event-Study Path Forward`) mas defere para
  "companion manuscript".
- Filtro de exogeneidade dos fechamentos. Os 3518 incluem qualquer CNES que
  parou de reportar — falência, descredenciamento, fusão administrativa,
  troca de CNPJ, queda de demanda, tudo junto. Filtro 50%+ de queda
  pré-fechamento mencionado no texto não foi implementado.
- **OSRM travel-time** como baseline (km haversine é straw man fraco em
  geografia amazônica). Mencionado no plano de pesquisa, não rodou.

---

## 2. O que mudou desde o setup do projeto

A tese inicial era "embedding bate km na predição de mortalidade evitável,
logo é uma medida superior de acesso". Os scripts 07 e 09 retornaram
**NO_GO_RECONSIDER**: $\Delta R^2$ de embedding sobre km é $-0.009$ (negativo,
embedding perde para km com mesmos controles).

O paper **se reposicionou de forma elegante** para sobreviver ao null:

- Abstract reformula a contribuição como "diagnóstico estruturado de
  divergência entre mapa e fluxo de pacientes", não predição.
- §6.7 admite o null abertamente ("The descriptive observation is
  unambiguous: the embedding does not predict amenable mortality").
- §7.1 defende o null como artefato de SIM under-reporting + cross-border
  death recording, com teste empírico via R99 (correlação $\isokm$ × R99
  $= +0.089$, R99 reduz $R^2$ em $-0.042$ — bem maior que o efeito de $\isokm$).
- §7.2 promete event-study causal como sequência natural.

Isso é uma **boa salvaguarda retórica**. Mas para JHE/AEJ:Applied, descritivo
+ promessa de causalidade posterior é referee-killer. Para o workshop ETH/UZH
(deadline 8 mai), a posição é defensável.

---

## 3. Por que o embedding empata com km — diagnóstico

**Achado-chave do log 06b**: top-10 vizinhos cosine de São Paulo são todos
SP-state (3518xx, 3534xx, 35xxxx). Top-10 de Manaus são todos AM (130xxx).
Pearson(emb, km) = 0.299; Spearman = 0.209.

**Interpretação**: o embedding está reproduzindo majoritariamente UF
homophily — pacientes ficam dentro do estado. Como os modelos de regressão
têm UF FE em $M_0$, $\isoemb$ adiciona quase nada que UF FE já não absorva.
$1 - \rho^2 = 91\%$ da variância "ortogonal a km" é, em parte, ortogonal a
**km mas não a UF**.

Isso explica o $\Delta R^2 \approx 0$. Não é falha de hyperparams (dim=128,
walks=10×20 são razoáveis para 5588 nós e ~500k arestas). É um problema de
**fonte de variação**: o embedding está pegando o que UF FE já controla.

**Subachado**: a TF-IDF na projeção M-M penaliza hubs (HC-USP, INCOR), mas
não penaliza a "co-presença em um hospital qualquer da mesma UF" — que é o
que produz o pattern within-UF.

---

## 4. Vias de salvamento — em ordem decrescente de viabilidade nos 10 dias

### Via A — **Reposicionar para o workshop como descritivo + diagnóstico** (já feito 80%)

O paper como está é **submissivel ao ETH/UZH AI&Econ workshop** (deadline 8 mai).
O workshop é interdisciplinar, valoriza ML como measurement tool. A
contribuição "embedding como diagnóstico de calibração regional do SUS" é
crível e tem 4 figuras decentes (mapa divergence, t-SNE/UMAP, side-by-side,
R99 hypothesis).

Pendências para Via A (~2-3 dias):

1. **Soften title** — "Beyond the Kilometer" implica predição superior, e o
   paper entrega null. Sugestão: *"Mapping the Map: A Patient-Flow Embedding
   Diagnostic of Brazil's SUS Hospital Network Calibration"* ou
   *"Beyond the Kilometer: A Network-Based Diagnostic of SUS Regionalization
   Calibration"*.
2. **Robustez do embedding**: rodar 5 seeds de node2vec e reportar variação
   nos vizinhos top-10 e na correlação Pearson(emb,km). Tabela apêndice.
   Sem isso referee pergunta na hora.
3. **Substituir em figuras quaisquer claims preditivos remanescentes** por
   claims diagnósticos. Não vi claim explícito problemático no texto, mas
   conferir captions.
4. **Ler §1 introduction.tex** com olho de revisor e checar que a "promise"
   está calibrada.
5. **Verificar bibliografia** — `references.bib` ainda não foi auditado contra
   `mr-hospital` ref protocol (existência, DOI, claim correto).

### Via B — **Adicionar evento descritivo de fechamentos (sem CS)** (~3-4 dias)

Um histograma + scatter:
- Para cada fechamento exógeno (definido como CNES que era hub local — top-3
  por internações no município — e parou em ano $t$), calcular
  $\Delta\isoemb_m$ e $\Delta\isokm_m$ no ano seguinte.
- Reportar: distribuição de $\Delta\isoemb / \Delta\isokm$. Se embedding
  tem variação independente em fechamentos, a razão tem variância grande
  (≠ 1).
- Não exige CS21, não promete identificação. É uma figura adicional que
  fortalece a tese diagnóstica e prova que o embedding tem informação
  além de km **localmente** (em choque), mesmo que cross-section flatlinhe.

Acrescenta ao paper sem mudar a arquitetura. Recomendado **se Via A fechar
em 2 dias**.

### Via C — **Causal CS21 sobre fechamentos** (~7-9 dias, alto risco)

O paper já tem `hospital_closures.parquet`. Implementar:
- Script `17_filter_exogenous_closures.py`: filtrar CNES com queda <50% nos 12
  meses pré-fechamento, descartar fusões (CNPJ raiz idêntico em CNES novo),
  manter só hospitais com leitos > X.
- Script `18_event_study_csa.R`: `did::att_gt` com mortalidade amenable
  município-ano como outcome, fechamento como tratamento, FE
  município+ano. Reportar event-study plot pré 5 anos, pós 5 anos.

Risco real:
- Fechamentos **não são exógenos**. Hospital com mortalidade alta fecha
  porque MS retira credenciamento; hospital de pequena cidade em declínio
  fecha porque a cidade declinou. Sinal pré-tratamento provavelmente
  estará lá.
- ~350 fechamentos exógenos é um $N$ pequeno para CS21. Power vai estar no
  limite, sobretudo com cluster por UF.
- 7-9 dias é **otimista**. Realisticamente 10-14 dias com Iteração honesta.
  Não cabe pré-deadline.

**Recomendação**: NÃO tentar Via C antes de 8 mai. Fica como roadmap pós-
workshop.

---

## 5. Plano sugerido até 8 mai

```
2026-04-28 (hoje) — diagnóstico (este doc) + leitura intro
2026-04-29        — Via A passos 1-4 (title, robustez, captions, intro)
2026-04-30        — Via A passo 5 (audit refs)
2026-05-01        — Via B se Via A fechou; senão polish Via A
2026-05-02        — Via B continua / pausa para mr-hospital /rev parecer
2026-05-03        — implementar feedback do parecer
2026-05-04        — compilar PDF final, gerar 1-pager, abstract corrigido
2026-05-05        — replication package (README, environment.yml, run_pipeline.sh)
2026-05-06        — buffer
2026-05-07        — submission
```

---

## 6. Decisões a tomar com o autor

1. **Title softening — sim/não**? Sugestão acima. Risco: se título mudar, o
   abstract precisa de leve retoque para não promissionar predição.
2. **Via B (eventos descritivos sem CS) — vale o investimento de 3-4 dias**?
   Acho que sim porque endereça a crítica natural de referee — "se o
   embedding nunca prediz nada além de km, qual a razão de ser?" — sem
   exigir identificação completa.
3. **Embedding stability — quantos seeds**? Mínimo 3 para apêndice,
   recomendado 5. Cada seed roda em ~25s no DarcioWork (ver log 06b
   peak_RSS 0.85GB), portanto trivial.
4. **Cross-CID outcome split**? Outra defesa do null seria mostrar que
   condições com forte canal de acesso (AMI 30-day, sepse, complicações
   obstétricas) respondem ao $\isoemb$, mesmo que mortalidade amenable
   agregada não. Isso muda o paper mas pode ser **a salvação substantiva**
   se o autor topar 1-2 dias adicionais. Marcar como "Via D opcional".

---

## 7. Notas de detalhe (para discussão)

- **R99 hypothesis test (script 15)** já está implementado e bem feito. A
  correlação +0.089 / +0.063 é modesta mas o efeito no $R^2$ é grande
  ($+0.042$). Boa peça de defesa.
- **Período de pooling**: data.tex usa 2015-2022 mas script 09 usa 2010-2023
  (mortalidade) e 2015-2022 (embedding). Inconsistência menor que pode
  virar pergunta de referee. Verificar e padronizar.
- **População**: 5565 munis no panel cross-section, 5588 totais. Os 23 que
  ficaram fora são munis sem internações em SIH-RD ou sem PIB. Documentar
  no apêndice.
- **TF-IDF na projeção 06b**: idf=log(N_M / df_h). Hospital que recebe de 1
  município tem idf=log(5588) = 8.6; hospital que recebe de todo mundo tem
  idf~0. Penalização forte de hubs. Essa escolha é defensável mas
  intencionalmente reduz a contribuição do hub no embedding — pode ser
  **parte do motivo** do null cross-section. Sensitivity: rodar com idf
  desligado e checar.
