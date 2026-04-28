# Research plan — 11 dias até deadline (28 abr → 8 mai 2026)

## Objetivo

Submeter ao ETH/UZH Workshop in AI & Applied Economics um paper que (i)
construa embeddings de municípios a partir do grafo paciente→hospital do
SIH/DATASUS, (ii) mostre que embedding-distance prevê mortalidade evitável
melhor que distância em km, e (iii) demonstre, via choque de fechamento
hospitalar, que o canal é causal.

## Cronograma

### Dia 1 (28 abr) — Setup + parsing DATASUS

- [ ] `environment.yml` resolve sem conflitos (`mamba env create`).
- [ ] Script `01_parse_datasus_sih.py`: baixar AIH-RD 2015–2022, .dbc → parquet.
      Schema mínimo: `mun_res`, `mun_hosp`, `cnes_hosp`, `procedimento`, `dt_internacao`, `dt_alta`, `morreu`.
- [ ] Script `02_parse_datasus_sim.py`: baixar SIM 2015–2022, .dbc → parquet.
      Schema mínimo: `mun_res`, `idade`, `sexo`, `causabas` (CID-10), `dt_obito`.
- [ ] Sanity log: total internações/ano, total óbitos/ano. Bater com TabNet.

### Dia 2 — CNES + outcome

- [ ] Script `03_parse_cnes_panel.py`: estabelecimento × ano, leitos por tipo,
      data de abertura/fechamento. Identificar hospitais com `motivo_desativacao`
      administrativo/fiscal vs. demanda.
- [ ] Script `04_build_amenable_mortality.R`: aplicar lista Nolte–McKee (CID-10)
      ao SIM, agregar por município-ano, calcular taxa por 100k <75 anos.
      Cross-validar contra OECD avoidable mortality framework.

### Dia 3 — Grafo bipartido + embeddings

- [ ] Script `05_build_bipartite_graph.py`: edge list `(mun_res, cnes_hosp, ano)`,
      peso = nº internações. Validar contagens vs script 01.
- [ ] Script `06_train_node2vec.py`: random walks ponderadas + SkipGram sobre
      grafo bipartido (snapshot pooled 2015–2022 e por ano).
      Hyperparâmetros baseline: dim=128, walk_length=20, num_walks=10, p=1, q=1.
      Salvar embeddings de **municípios** (descartar hospital embeddings ou guardar para análise descritiva).

### Dia 4 — Validação e descritivos

- [ ] Script `07_evaluate_distance_matrix.py`: matriz N×N de distâncias
      embedding entre municípios. Comparar com:
      - distância centroide-centroide IBGE (km)
      - tempo de deslocamento OSRM (se viável)
      - co-pertencimento a CIR (Comissões Intergestores Regionais — fronteira de saúde)
- [ ] Script `08_validate_clusters.R`: rodar KMeans sobre embeddings,
      comparar com regiões CIR/RIPSA via NMI / ARI. Esperado: alta concordância
      em capitais e regiões metropolitanas; divergência reveladora em fronteiras.
- [ ] Smoke test: t-SNE 2D, colorir por UF e por região de saúde.

### Dia 5 — Cross-section: mortality ~ isolation

- [ ] Construir índice `embedding_isolation_i = E[||emb_i - emb_j||]` para j em
      top-3 hospitais de referência regional (definidos por volume).
- [ ] Script `09_panel_regressions.R`: 5570 munis × 8 anos, FE UF×ano +
      controles (pop, PIB pc, urbanização, ESF cobertura, leitos/1000).
      Outcome: log(taxa Nolte–McKee). Cluster ao nível município.
- [ ] Comparar coef `embedding_isolation` vs coef `km_distance_to_hub`.
      Rodar horse-race com ambos.

### Dia 6 — Identificação causal: fechamentos

- [ ] Script `10_closure_event_study.R`: identificar ~50–200 fechamentos de
      hospital exógenos (motivo administrativo/fiscal, **não** decisão de
      demanda local). Para cada fechamento, montar painel município-tratado
      com t=fechamento centrado.
- [ ] Estimar Δ embedding-distance ao novo hub e Δ mortalidade Nolte–McKee.
- [ ] DiD via Callaway-Sant'Anna (`did` package R). Pre-trends.

### Dia 7 — Robustez

- [ ] Script `11_robustness.R`:
      - Variação de hyperparam node2vec (dim ∈ {32,64,128,256}, walk ∈ {10,20,40}, q ∈ {0.5,1,2}).
      - Placebo temporal: embeddings 2010–2014 (período pre) prevê mortality 2015 (no power).
      - Negative control: sortear edges aleatoriamente preservando degree distribution.
      - Subsample por região (Norte vs Sudeste — heterogeneidade esperada).
- [ ] Robustness ao Nolte–McKee: refazer com **OECD avoidable mortality**.

### Dia 8 — GraphSAGE (se sobrar tempo) + interpretabilidade

- [ ] Script opcional `06b_train_graphsage.py`: GraphSAGE com features de nó
      município (pop, PIB pc, urbanização). Comparar AUC de prever fluxo de
      pacientes 1-hop. Reportar.
- [ ] **Interpretabilidade**: top-5 municípios mais isolados em cada UF —
      caracterizar (renda, distância km, ESF, IDH). Storytelling.

### Dia 9 — Tabelas + figuras

- [ ] Script `12_make_figures.py`:
      - Mapa Brasil colorido por embedding_isolation (vs km_isolation lado a lado).
      - t-SNE 2D com pontos municípios, color = região.
      - Event-study chart (closure → mortality).
      - ROC: prever municípios "alta mortalidade" via embedding vs km.
- [ ] Script `13_make_tables.R`: tabela 1 (descritivos), 2 (cross-section
      regressions), 3 (event study), 4 (robustez).

### Dia 10 — Escrever paper

- [ ] Setup `01_manuscript/` (LaTeX, classe `article` + biblatex).
- [ ] Estrutura: 1 Intro · 2 Data · 3 Network embeddings · 4 Cross-sectional results · 5 Causal: closures · 6 Robustness · 7 Discussion.
- [ ] Reaproveitar tom de redação dos papers anteriores.
- [ ] Target: 25 páginas + apêndice.

### Dia 11 (8 mai) — Polish + submeter

- [ ] Compilar PDF final, conferir números, referências.
- [ ] Submeter via portal do workshop.

## Decisões pendentes

1. **Coautoria**: sole-authored por padrão até decisão. Reabrir se rumar para
   journal full-paper (potencial coautor com bg em health economics).
2. **Stack GNN**: node2vec via gensim (ou node2vec pip). GraphSAGE só se
   sobrar tempo dia 8.
3. **Snapshot pooled vs temporal**: começar pooled 2015–2022; testar painel
   por ano se cross-section for fraca.
4. **CNES closure source**: filtrar por `motivo_desativacao` no CNES (heurística);
   alternativa robusta — TCU/CGU notícias de fechamento por motivo financeiro.

## Riscos

- **DBC parsing**: `pyreaddbc` pode falhar em arquivos grandes. Mitigação: usar
  `read.dbc` em R como fallback (`library(read.dbc)` ou via `microdatasus` package).
- **Volume internações**: ~80M linhas. Cabe em DuckDB out-of-core; chunkar
  download por UF×ano.
- **Endogeneidade do fechamento**: hospital fecha por demanda decrescente,
  não por motivo administrativo. Mitigação: filtro estrito + heterogeneidade
  por motivo de fechamento.
- **Mortality counts noisy** em municípios pequenos (<10k hab): excluir ou
  usar Empirical Bayes shrinkage.

## Critério de "go / no-go" para submissão

- **Cross-section**: coef embedding_isolation com signal econômico (>5%
  mortalidade por 1 SD isolation), p<0.01, robusto a controles. → GO.
- **Causal**: event study com pre-trend limpo e effect significativo. → GO.
- Se cross-section sólido mas event study ruidoso: submeter como
  **measurement paper** com closures como motivating evidence apenas.
- Se cross-section também fraco: submeter ao próximo workshop (Dez 2026)
  com paper17 ou outra rota.
