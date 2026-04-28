# Paper 18 — Hospital Deserts (paper18-hospital-deserts)

## Identidade

- **Título de trabalho**: "Beyond the Kilometer: Network-Revealed Access to
  Healthcare and Avoidable Mortality in Brazil"
- **Autor**: Darcio Genicolo-Martins (sole-authored — sem decisão de coautoria
  por enquanto; reabrir se rumar para JHE/JPubE com horizonte 2026Q3+)
- **Submission target**: ETH/UZH Workshop in AI & Applied Economics, Set 11–12 2026
- **Deadline**: 8 maio 2026
- **Alvo journal**: JHE, AEJ:Applied (cf. `ideas-workshop-aiecon-2026.md` na raiz do monorepo)

## Convenções deste projeto

- **Pipeline numerado**: scripts em `03_analysis/` numerados `01_*.py`,
  `02_*.R`, etc., reproduzíveis em ordem por `run_pipeline.sh`.
- **DuckDB para parquet** (regra global do monorepo). DATASUS .dbc → .parquet
  como first move, depois tudo via DuckDB out-of-core.
- **Memória**: 16 GiB budget, 12 threads, 2–4 workers (regras `~/.claude/CLAUDE.md`).
- **Embeddings**: salvos como `.parquet` ou `.npy` em `02_data/intermediate/`.
- **Sem AI markers** em commits, código, docs (regra global).
- **Comentários humanizados**: terse, só onde o WHY não é óbvio.
- **Cache / rerun**: scripts pesados devem detectar output existente e pular,
  com flag `--force` para rerun.

## Diferenciações de paper17 (não confundir)

- **Nó**: município (não firma). Universo fechado de ~5570 nós.
- **Grafo**: paciente → hospital → município de residência (bipartido reduzido
  para projeção município-município por co-paciência em hospital).
- **Outcome**: mortalidade evitável (SIM, lista Nolte–McKee), painel
  município-ano. Não é classificação binária como cartel.
- **Identificação causal**: choque de fechamento hospitalar (CNES) — paper17
  não tem ID causal forte por design (é detection paper).

## Pipeline alvo (rascunho)

```
01_parse_datasus_sih.py        # DBC → parquet, painel internação 2015-2022
02_parse_datasus_sim.py        # DBC → parquet, óbitos com CID-10
03_parse_cnes_panel.py         # CNES estabelecimento × ano, leitos, status
04_build_amenable_mortality.R  # CID-10 → Nolte–McKee → taxa município-ano
05_build_bipartite_graph.py    # (município, hospital, ano), peso=internações
06_train_node2vec.py           # static embedding município-município
07_evaluate_distance_matrix.py # ||emb_i - emb_j|| vs km, vs hospital ref
08_validate_clusters.R         # bate com regiões CIR/RIPSA?
09_panel_regressions.R         # FE UF×ano, mortality ~ embedding_isolation
10_closure_event_study.R       # DiD em fechamentos CNES
11_robustness.R                # GraphSAGE com features, walk hyperparams
12_make_figures.py             # mapas, t-SNE, ROC
13_make_tables.R               # main + robustness
```

## Stack recomendado

- **Python 3.11**: `pyreaddbc` (ler .dbc DATASUS), `duckdb`, `polars`,
  `pyg` (PyTorch Geometric), `gensim`, `networkx`, `geopandas`, `matplotlib`,
  `scikit-learn`, `tqdm`, `psutil`.
- **R 4.4**: `data.table`, `fixest`, `did` (Callaway-Sant'Anna), `kableExtra`,
  `sf`.
- **GPU**: indisponível. Treinar com CPU em 12 threads — node2vec sobre
  ~5570 nós é trivial.

## Universo do grafo (a probar no dia 1)

- **N nós-município**: 5570 (esperado).
- **N nós-hospital**: ~6000–7000 ativos (CNES).
- **N edges (município, hospital, ano)**: estimado 5–10M (sparse).
- **N internações totais 2015–2022**: ~80–100M (cabe folgado em DuckDB).

## Outcome principal — Amenable Mortality (Nolte–McKee)

Lista canônica de CIDs onde mortalidade pode ser evitada por intervenção
médica oportuna (idade < 75). Inclui: doenças isquêmicas tratadas, AVC,
sepse, complicações obstétricas, apêndice perfurado, etc. Será calculado
em `04_build_amenable_mortality.R` como taxa por 100k habitantes.

## Identificação causal — fechamentos hospitalares

CNES histórico permite identificar hospitais que **deixaram de operar** entre
2015 e 2022. Para cada fechamento exógeno (motivo administrativo/fiscal, não
demanda decrescente — filtrar via heurística), criar evento por município
afetado (município que perdeu seu hospital de referência). Estimar:

1. Δ embedding-distance ao novo hub mais próximo.
2. Δ taxa de mortalidade evitável.
3. Razão (2)/(1) como coeficiente "marginal mortality cost of network distance".

## Métricas alvo

- **Descritivo**: correlação embedding-distance × km × tempo de deslocamento real.
- **Cross-section**: regressão mortality ~ embedding_isolation, FE UF×ano + controles.
- **Causal (event study)**: DiD com Callaway-Sant'Anna em fechamentos.
- **Bench**: comparar capacidade preditiva (R² out-of-sample) de embedding vs km.

## Política de commits

- Commits pequenos, focados.
- Nunca incluir Claude/AI co-author lines.
- Mensagens em português ou inglês, consistente com convenção do monorepo.
